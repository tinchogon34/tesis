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
trusted_hosts = ['*']
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

# remove?
shuffle = (h) ->
    keys = Object.keys(h)
    size = keys.length
    for i in [0..size-1] # For each key
        randomKeyI = keys[i]
        j = Math.floor(Math.random() * size) # Pick random key
        randomKeyJ = keys[j]
        [h[randomKeyI], h[randomKeyJ]] = [h[randomKeyJ], h[randomKeyI]] # Do swap
    return h

# remove?
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
  
  console.log "elijiendo una task aleatoriamente"
  # Elije uno aleatoriamente.
  coll.find({$where: "this.available_slices.length > 1"}).count (err, _n) ->
    coll.find({$where: "this.available_slices.length > 1"}).limit(1).skip(
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

# remove?
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