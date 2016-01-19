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
meteorurl = 'mongodb://127.0.0.1:3001/meteor'

db = null
db2 = null
whitelist = [
  'http://codingways.com',
  'http://10.0.0.69:8000',
  'http://localhost:8000'
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
  app.use morgan 'combined'
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

  sendData = (work, reducing, client) ->
    ###
    Busca en el work datos y los envia al cliente.
    ###
    if work is null
      return client.emit 'finish'

    if reducing
      _data = _.sample(_.pairs(work.reduce_data))
      data = {}
      data[_data[0]] = _data[1]

      return client.emit 'new_work',
        task_id: work._id
        ireduce: work.ireduce
        data: data
        reducing: true

    else
      _slice_id = _.sample work.available_slices
      return client.emit 'new_work',
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
      logs = db2.collection 'Tasks'
      coll.findAndModify {
        _id: new ObjectID(task_id)},
        [['_id',1]],
        {$push: update},
        {new: true},
        (err, task) ->
          if err isnt null
            console.error "Failed to update:", err
          else
            map_results = {}
            for k,v of task.map_results
              map_results[k] = v.length

            logs.update {
              task: new ObjectID(task_id)},
              {$set: {map_results: map_results, reduce_results: task.reduce_results, reducing: reducing} },
              (err) ->
                if err isnt null
                  console.error "Failed to update:", err

      # Devuelve mas datos
      getWork (work, reducing) ->
        sendData(work, reducing, client)

  # Connect to DB
  MongoClient.connect db_url, (err, connection) ->
    assert.ifError err
    assert.ok connection
    db = connection

    # Connect to DB
    MongoClient.connect meteorurl, (err, connection) ->
      assert.ifError err
      assert.ok connection
      db2 = connection

      server.listen(3002)
      console.log "listening to 192.168.1.2:3002"

if cluster.isMaster
  cluster.fork() for [0...numCPUs]
  cluster.on 'exit', (worker) ->
    console.log "Worker died :("
    cluster.fork()
else
  workers()
