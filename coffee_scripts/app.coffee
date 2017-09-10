#### REQUIRES #######
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
#####################

MONGO_DB_URL = 'mongodb://127.0.0.1:27017/tesis'
METEOR_DB_URL = 'mongodb://127.0.0.1:3001/meteor'
REDIS_DB_CONFIG = { host: 'localhost', port: 6379 }
REDUCING_QUERY = {$where: "this.available_slices.length === 0 && this.enabled_to_process && !this.finished"}
MAPPING_QUERY = {$where: "this.available_slices.length > 0 && this.enabled_to_process && !this.finished"}
LISTEN_PORT = 3002

# DB Redis para Mantener la conexion de los WebSockets a través de los
# diferentes procesos del cluster
io.adapter(redis(REDIS_DB_CONFIG))

# Listado de hosts que pueden hacer CORS
WHITELIST = [
  'http://localhost:8000',
  'http://192.168.0.5:8000'
]

mongo_db = null
meteor_db = null

# Habilito efectivamente a los hosts de WHITELIST a hacer CORS
corsOptions =
  origin: (origin, callback) ->
    originIsWhitelisted = WHITELIST.indexOf(origin) != -1
    callback null, originIsWhitelisted
    return
  credentials: true

workers = ->
  # Configuro el Middleware
  app.use cors(corsOptions)
  app.use(express.static(__dirname + '/public'));
  app.use morgan 'combined'
  app.use bodyParser.json()
  app.use bodyParser.urlencoded extended: true
  app.use compression()

  getWork = (callback) ->
    tasks_collection = mongo_db.collection 'tasks'
    ###
    Elije uno aleatoriamente.
    Si hay un Task listo para reducir tiene mayor prioridad.
    ###
    tasks_collection.find(REDUCING_QUERY).count (err, _n) ->
      assert.ifError err
      if _n isnt 0
        console.log "Elijiendo una task aleatoriamente para reducir"
        tasks_collection.find(REDUCING_QUERY).limit(1).skip(_.random(_n - 1)).nextObject((err, task) ->
          assert.ifError err
          callback task, true
        )
      else
        tasks_collection.find(MAPPING_QUERY).count (err, _n) ->
          assert.ifError err
          if _n is 0
            console.log "No hay mas tasks :)"
            return callback null
          console.log "Elijiendo una task aleatoriamente para mapear"
          tasks_collection.find(MAPPING_QUERY).limit(1).skip(_.random(_n - 1)).nextObject((err, task) ->
            assert.ifError err
            callback task, false
          )

  sendData = (work, reducing, client) ->
    ###
    Busca en el work datos y los envia al cliente.
    ###

    # Si no hay mas trabajos le mando al cliente un 'finish'
    if work is null
      return client.emit 'finish'

    # Si estoy reduciendo
    if reducing
      _data = _.sample(_.pairs(work.reduce_data)) # {"llave": [1,2,3,4,5]} => [["llave",[1,2,3,4,5]]]
      data = {}
      data[_data[0]] = _data[1]

      # Le mando un mensaje 'new_work' al cliente con los datos a reducir
      return client.emit 'new_work',
        task_id: work._id
        ireduce: work.ireduce
        data: data
        reducing: true

    else
      _slice_id = _.sample work.available_slices # Elijo un slice disponible al azar

      # Le mando un mensaje 'new_work' al cliente con los datos a mapear
      return client.emit 'new_work',
        task_id: work._id
        imap: work.imap
        slice_id: _slice_id
        data: work.slices[_slice_id]
        reducing: false

  io.on 'connection', (client) ->
    console.log('Cliente conectado...')

    # Cuando el cliente emite un 'ready' le mando datos
    client.on 'ready', ->
      getWork (work, reducing) ->
        sendData(work, reducing, client)

    # Cuando el cliente emite un 'work_results' guardo los datos y le mando
    # datos nuevos
    client.on 'work_results', (data) ->
      reducing = data.reducing
      task_id = data.task_id

      # Prepara el obj para actualizar la DB
      # Si esta siendo reducido guardo en reduce_results
      if reducing
        update = {}
        for key, value of data.result
          update["reduce_results.#{key}"] = value
      # Si esta siendo mapeado guardo en map_results
      else
        slice_id = data.slice_id
        update = {}
        update["map_results.#{slice_id}"] = data.result

      # Realiza la llamada a la DB
      tasks_collection = mongo_db.collection 'tasks'
      meteor_tasks_collection = meteor_db.collection 'Tasks'

      tasks_collection.findOneAndUpdate {
        _id: new ObjectID(task_id)},
        {$push: update},
        {returnOriginal: false},
        (err, doc) ->
          if not err and doc.value
            task = doc.value
            # Preparo los datos para actualizar la DB de Meteor

            map_results = {}
            reduce_results = {}
            for k,v of task.map_results
              map_results[k] = v.length
            for k,v of task.reduce_results
              reduce_results[k] = v

            meteor_tasks_collection.findOneAndUpdate {
              task: new ObjectID(task_id)},
              {$set: {map_results: map_results, reduce_results: reduce_results, reducing: reducing} },
              (err) ->
                if err isnt null
                  console.error "Fallo al actualizar:", err

      # Devuelve mas datos
      getWork (work, reducing) ->
        sendData(work, reducing, client)

  # Me conecto a la DB de Mongo y guardo la conexion para futuros usos
  MongoClient.connect MONGO_DB_URL, {}, (err, connection) ->
    assert.ifError err
    assert.ok connection
    mongo_db = connection

    # Me conecto a la DB de Meteor y guardo la conexion para futuros usos
    MongoClient.connect METEOR_DB_URL, {}, (err, connection) ->
      assert.ifError err
      assert.ok connection
      meteor_db = connection

      server.listen(LISTEN_PORT)
      console.log "Escuchando en 0.0.0.0:"+LISTEN_PORT.toString()

# Si estoy en el proceso padre
if cluster.isMaster
  cluster.fork() for [0...numCPUs] # Creo tantos procesos hijos como CPUs
  cluster.on 'exit', (worker) ->
    console.log "Murió un Worker :("
    cluster.fork() # Si muere un proceso por algun motivo, creo otro
else
  workers() # Si soy un proceso hijo ejecuto la funcion workers
