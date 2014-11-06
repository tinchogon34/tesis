express = require 'express.io'
bodyParser = require 'body-parser'
compression = require 'compression'
morgan  = require 'morgan'
serveStatic = require 'serve-static'
assert = require 'assert'
fs = require 'fs'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
_ = require("underscore")

app = express()
trusted_hosts = ['http://localhost:3000']
db_url = 'mongodb://127.0.0.1:27017/tesis'
WORKER_JS = fs.readFileSync 'worker.js', 'utf8'
db = null

# Connect to DB
MongoClient.connect db_url, (err, connection) ->
    assert.ifError err
    assert.ok connection
    db = connection

allowCrossDomain = (req, res, next) ->
    res.header 'Access-Control-Allow-Origin', trusted_hosts
    res.header 'Access-Control-Allow-Methods', 'GET, POST'
    res.header 'Access-Control-Allow-Headers', 'Content-Type'
    next()

# SET MIDDLEWARE
app.use serveStatic __dirname + '/public'
app.use morgan 'default'
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true
app.use compression()
app.use allowCrossDomain

shuffle = (h) ->
    keys = Object.keys(h)
    size = keys.length
    for i in [0..size-1] # For each key
        randomKeyI = keys[i]
        j = Math.floor(Math.random() * size) # Pick random key
        randomKeyJ = keys[j]
        [h[randomKeyI], h[randomKeyJ]] = [h[randomKeyJ], h[randomKeyI]] # Do swap
    return h

get_slices = (data, size) ->
    # { "0" : 1, "1" : 1, "2" : 2, "3" : 3 }
    # { "0": {"status": "created", "data": {"0" : 1, "1" : 1, "2" : 2 }}, 1: {"status":"created","data":{"3" : 3}} }

    hash = {}
    keysLength = Object.keys(data).length
    hash[i] = {"status":"created", "data": {}} for i in [0..Math.floor(keysLength%size)]
    i = 0
    contador = 0
    
    for key, value of data
        hash[i].data[key] = value
        contador++
        i++ if (contador) % size == 0        
    
    return shuffle(hash)

get_work_or_data = (callback) ->
    db.collection 'workers', (err, collection) ->
        return callback {task_id: 0} if err
        assert.ok collection
       
        collection.find({"status": {$ne: "reduce_pending"}}).toArray((err, items) ->
            if !items.length or err
                console.log "Workers empty"
                return callback {task_id: 0} # No more works

            work = items[Math.floor(Math.random()*items.length)] # Random pick one work
            # NEED TO LOCK IT, no more than one request with same slice
            size = Object.keys(work.slices).length

            if work.status != 'reduce_pending' and work.received_count == size
                console.log "Entre al received"
                collection.update {_id: work._id}, {$set: {status: 'reduce_pending'}}, (err, count) ->
                    return callback {task_id: 0} if err
                    assert.equal 1, count
                    
                return get_work_or_data callback

            else if work.current_slice == size-1
                return get_work_or_data callback                    

            collection.findAndModify {_id: work._id}, [], {$inc: {current_slice: 1}}, {new: true}, (err, work) ->
                return callback {task_id: 0} if err
                assert.ok work
                
                ### {"0": 1, "1": 1, "2": 2} => [["0",1],["1",1],["2",2]] ###
                ### PROC.JS COMPATIBILITY, REMOVE THIS! ###
                arr = []
                for key, value of work.slices[work.current_slice].data
                    arr.push [key, value]
                #############################################################

                doc =
                    task_id: work._id
                    slice_id: work.current_slice
                    data: arr
                    worker: work.worker_code + ";" + worker_js

                            
                return callback doc

        )

getWork = (task_id=null, callback) ->
  ###
  Busca en la DB un `task` con _id igual a `slice_id ` o si este es null,
  lo busca aleatoriamente. Luego llama a la funcion callback con task como 
  argumento
  ###
  coll = db.collection 'workers'
  if task_id isnt null
    coll.findOne {_id: new ObjectID task_id}, (err, item) ->
      if err
        console.error err
        return
      callback item
    return

  # Elije uno aleatoriamente.
  coll.find({"status": {$ne: "reduce_pending"}}).count (err, _n) ->
    coll.find({"status": {$ne: "reduce_pending"}}).limit(1).skip(
      _.random(_n - 1)).nextObject(
        (err, item) ->
          if err
            console.error err
            return
          callback item
      )

###
Define HTTP method
###
app.get '/work', (req, res) ->
  # Response only if CORS json request from known hosts

  #if (req.accepts 'json' != 'undefined') and req.headers.origin in trusted_hosts
  #    console.log "Work OK!"

  getWork null, (work) ->
    if work is null
      return res.json
        task_id: 0

    res.json 
      task_id: work._id
      code: work.imap + ";" + WORKER_JS

app.get '/data', (req, res) ->
  # Devuelve en JSON datos (slice_id, data) para ser procesados en el cliente.

  task_id = req.param "task_id"
  console.log "GET /data con task_id=#{task_id}"
  if not task_id
    res.status 400
    return res.send "task_id required"

  getWork task_id, (work) ->
    if work is null
      res.status 400
      return res.send "Work not found"

    _slice_id = _.sample work.available_slices
    return res.json 
      slice_id: _slice_id 
      data: work.slices[_slice_id]

app.post '/data', (req, res) ->
  ### 
  ( ͡° ͜ʖ ͡°)
  Postea resultados de los datos ya procesador. Devuelve mas datos para
  que el cliente siga *laburanding* Haters gonna hate ;).
  ###

  console.log "Posting to /data"
  if undefined in [req.body.task_id, req.body.slice_id, req.body.result]
    res.status 400
    return res.send "get your shit together"

  slice_id = req.param "slice_id"
  update = {}
  update["map_results.#{slice_id}"] = req.param "result"
  
  coll = db.collection 'workers'
  coll.update {
    _id: new ObjectID req.param "task_id"}, {
      $push: update
    }, (err) ->
      if err isnt null
        console.error "Failed to update:", err

  getWork req.param("task_id"), (work) ->
    _slice_id = _.sample work.available_slices
    return res.json 
      slice_id: _slice_id 
      data: work.slices[_slice_id]

app.post '/form', (req, res) ->
  # Investigator post a new JOBS to distribute.
  console.log(req.body)
  data = JSON.parse req.body.data.replace(/'/g,"\"")
  map = req.body.map
  reduce = req.body.reduce
    
  # DO CHECKS
  
  doc =
    data: data
    worker_code: "investigador_map = " + map
    reduce: reduce
    map_results: {}
    reduce_results: {}
    slices: get_slices(data, 3)
    current_slice: -1
    status: 'created'
    received_count: 0
    send_count: 0

  db.collection 'workers', (err, collection) ->
    assert.ifError err
    collection.insert doc, {w: 1}, (err, result) ->
      assert.ifError err
      assert.ok result
    
    res.send "Thx for submitting a job"
        
app.post '/log', (req, res) ->
  # logging from proc.js
  console.log req.body.message
  res.send 200

console.log "listening to localhost:3000"
app.listen '3000'