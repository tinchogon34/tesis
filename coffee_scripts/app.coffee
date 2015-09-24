express = require 'express'
bodyParser = require 'body-parser'
compression = require 'compression'
morgan  = require 'morgan'
serveStatic = require 'serve-static'
assert = require 'assert'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
_ = require("underscore")
cors = require('cors')

app = express()
db_url = 'mongodb://127.0.0.1:27017/tesis'
db = null
whitelist = [
  'http://localhost:8000',
  'http://tesis.office:8000'
]
corsOptions = origin: (origin, callback) ->
  originIsWhitelisted = whitelist.indexOf(origin) != -1
  callback null, originIsWhitelisted
  return

# Connect to DB
MongoClient.connect db_url, (err, connection) ->
  assert.ifError err
  assert.ok connection
  db = connection

# SET MIDDLEWARE
app.use cors(corsOptions)
app.use serveStatic __dirname + '/public'
app.use morgan 'default'
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true
app.use compression()

getWork = (callback) ->
  coll = db.collection 'tasks'
  console.log "elijiendo una task aleatoriamente"
  ###
  Elije uno aleatoriamente.
  Si hay un Task listo para reducir tiene mayor prioridad.
  ###
  coll.find({$where: "this.available_slices.length === 0 && this.enabled_to_process && !this.finished"}).count (err, _n) ->
    assert.ifError err
    if _n isnt 0
      coll.find({$where: "this.available_slices.length === 0 && this.enabled_to_process && !this.finished"}).limit(1).skip(_.random(_n - 1)).nextObject((err, item) ->
        assert.ifError err
        callback item, true
      )
    else
      coll.find({$where: "this.available_slices.length > 0 && this.enabled_to_process && !this.finished"}).count (err, _n) ->
        assert.ifError err
        if _n is 0
          return callback null
        coll.find({$where: "this.available_slices.length > 0 && this.enabled_to_process && !this.finished"}).limit(1).skip(_.random(_n - 1)).nextObject((err, item) ->
          assert.ifError err
          callback item, false
        )


sendData = (work, reducing, res) ->
  ###
  Busca en el work datos y los envia al cliente.
  ###
  if work is null
    return res.json
      status: "no_more"

  if reducing
    _data = _.sample(_.pairs(work.reduce_data))
    data = {}
    data[_data[0]] = _data[1]

    return res.json
      task_id: work._id
      ireduce: work.ireduce
      data: data
      reducing: true

  else
    _slice_id = _.sample work.available_slices
    return res.json
      task_id: work._id
      imap: work.imap
      slice_id: _slice_id
      data: work.slices[_slice_id]
      reducing: false

###
Define HTTP method
###
app.get '/work', (req, res) ->
  getWork (work, reducing) ->
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
  getWork (work, reducing) ->
    sendData(work, reducing, res)

console.log "listening to localhost:3000"
app.listen '3000'
