express = require 'express'
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


getWork = (task_id=null, callback) ->
  ###
  Busca en la DB un `task` con _id igual a `slice_id ` o si este es null,
  lo busca aleatoriamente. Luego llama a la funcion callback con task como
  argumento
  ###
  coll = db.collection 'tasks'
  if task_id isnt null
    coll.findOne {_id: new ObjectID task_id}, (err, item) ->
      assert.ifError err
      callback item
    return

  console.log "elijiendo una task aleatoriamente"
  ###
  Elije uno aleatoriamente.
  Si hay un Task listo para reducir tiene mayor prioridad.
  ###
  coll.find({$where: "this.available_slices.length === 0 && this.enabled_to_process"}).count (err, _n) ->
    assert.ifError err
    if _n isnt 0
      coll.find({$where: "this.available_slices.length === 0 && this.enabled_to_process"}).limit(1).skip(_.random(_n - 1)).nextObject((err, item) ->
        assert.ifError err
        callback item, true
      )
    else
      coll.find({$where: "this.available_slices.length > 0 && this.enabled_to_process"}).count (err, _n) ->
        assert.ifError err
        if _n is 0
          return callback null
        coll.find({$where: "this.available_slices.length > 0 && this.enabled_to_process"}).limit(1).skip(_.random(_n - 1)).nextObject((err, item) ->
          assert.ifError err
          callback item, false
        )


sendData = (work, reducing, res) ->
  ###
  Busca en el work datos y los envia al cliente.
  ###
  if work is null
    return res.status(400).send "Work not found"

  if reducing
    _data = _.sample(_.pairs(work.reduce_data))
    data = {}
    data[_data[0]] = _data[1]

    return res.json
      data: data

  else
    if work.available_slices.length is 0
      return res.json
        status: "finished"

    _slice_id = _.sample work.available_slices
    return res.json
      slice_id: _slice_id
      data: work.slices[_slice_id]

###
Define HTTP method
###
app.get '/work', (req, res) ->
  getWork null, (work, reducing) ->
    if work is null
      return res.json
        task_id: 0

    if reducing
      res.json
        task_id: work._id
        reducing: reducing
        code: work.ireduce + WORKER_JS

    else
      res.json
        task_id: work._id
        reducing: reducing
        code: work.imap + WORKER_JS


app.get '/data', (req, res) ->
  ###
   Devuelve en JSON datos para ser procesados en el cliente.
  ###

  if undefined in [req.query.reducing, req.query.task_id]
    return res.status(400).send "Missing argument(s)"

  task_id = req.query.task_id
  reducing = req.query.reducing is "true"
  console.log "GET /data con #{reducing} task_id=#{task_id}"

  getWork task_id, (work) ->
    console.log "work fetched! reducing? #{reducing}"
    sendData(work, reducing, res)


app.post '/data', (req, res) ->
  ###
  Almacena los resultados de los datos ya procesados. Devuelve mas datos para
  que el cliente siga con la siguiente tarea.
  ###

  if undefined in [req.body.task_id, req.body.result, req.body.reducing]
    return res.status(400).send "Missing argument(s)"

  reducing = req.body.reducing
  task_id = req.body.task_id

  # Prepara el obj para actulizar a DB
  if reducing
    console.log "Store results ", req.body.result
    update = {}
    for key, value of req.body.result
      update["reduce_results.#{key}"] = value

  else
    if req.body.slice_id is undefined
      return res.status(400).send "Missing argument(s)"

    slice_id = req.body.slice_id
    update = {}
    update["map_results.#{slice_id}"] = req.body.result

  # Realiza la llamada a la DB
  coll = db.collection 'tasks'
  coll.update {
    _id: new ObjectID(task_id)},
    {$push: update},
    (err) ->
      if err isnt null
        console.error "Failed to update:", err

  # Devuelve mas datos
  getWork task_id, (work) ->
    sendData(work, reducing, res)

console.log "listening to localhost:3000"
app.listen '3000'
