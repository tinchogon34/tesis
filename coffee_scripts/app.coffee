express = require('express')
http = require('http')
app = express()
server = http.createServer(app)
io = require('socket.io').listen(server)
redis = require('socket.io-redis')
bodyParser = require 'body-parser'
compression = require 'compression'
morgan  = require 'morgan'
serveStatic = require 'serve-static'
assert = require 'assert'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
_ = require("underscore")
cors = require('cors')
cluster = require('cluster')
numCPUs = require('os').cpus().length
io.adapter(redis({ host: 'localhost', port: 6379 }))

db_url = 'mongodb://127.0.0.1:27017/tesis'
db = null
whitelist = [
  'http://192.168.0.111:8000',
  'http://localhost:8000',
  'http://tesis.office:8000'
]
corsOptions =
  origin: (origin, callback) ->
    originIsWhitelisted = whitelist.indexOf(origin) != -1
    callback null, originIsWhitelisted
    return
  credentials: true

workers = ->
  # SET MIDDLEWARE
  app.use cors(corsOptions)
  app.use(express.static(__dirname + '/public'));
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

  sendData = (work, reducing, req) ->
    ###
    Busca en el work datos y los envia al cliente.
    ###
    if work is null
      return req.io.emit 'finish'

    if reducing
      _data = _.sample(_.pairs(work.reduce_data))
      data = {}
      data[_data[0]] = _data[1]

      return req.io.emit 'new_work',
        task_id: work._id
        ireduce: work.ireduce
        data: data
        reducing: true

    else
      _slice_id = _.sample work.available_slices
      return req.io.emit 'new_work',
        task_id: work._id
        imap: work.imap
        slice_id: _slice_id
        data: work.slices[_slice_id]
        reducing: false

  io.on 'connection', (client) ->
    console.log('Client connected...')

    client.on 'ready', ->
      getWork (work, reducing) ->
        sendData(work, reducing, client)

    client.on 'work_results', (data) ->
      #if undefined in [req.body.task_id, req.body.result, req.body.reducing]
      #  return res.status(400).send "Missing argument(s)"

      reducing = data.reducing
      task_id = data.task_id

      # Prepara el obj para actulizar a DB
      if reducing
        console.log "Store results ", data.result
        update = {}
        for key, value of data.result
          update["reduce_results.#{key}"] = value

      else
        #if req.body.slice_id is undefined
        #  return res.status(400).send "Missing argument(s)"

        slice_id = data.slice_id
        update = {}
        update["map_results.#{slice_id}"] = data.result

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
        sendData(work, reducing, client)

  server.listen(3000)
  console.log "listening to localhost:3000"

if cluster.isMaster
  # Connect to DB
  MongoClient.connect db_url, (err, connection) ->
    assert.ifError err
    assert.ok connection
    db = connection
    cluster.fork() for [0...numCPUs]
else
  workers()
