###
  Debe ser ejecutado en segundo plano. Es un servicio que busca tareas que
  para cambiarlas de estado. Estos cambios suceden cuando
  1) Termino la fase de map y debe empezar la de reduce.
  2) Durante la fase reduce. Adicionalmente detecta cuando termina y mueve la
  tarea a otra Colección.

###
# dependencias
MongoClient = require('mongodb').MongoClient
assert = require 'assert'
_ = require "underscore"
fs = require "fs"
cluster = require('cluster')

DB_URL = 'mongodb://127.0.0.1:27017/tesis'
METEOR_URL = 'mongodb://127.0.0.1:3001/meteor'
REDUCING_QUERY = {$where: "this.available_slices.length === 0 && this.enabled_to_process && !this.finished"}
MAPPING_QUERY = {$where: "this.available_slices.length > 0 && this.enabled_to_process && !this.finished"}
LOCK_PATH = "/var/tmp/.tesis.lock"

worker = ->
  # check if there is an other process
  try
    fs.openSync LOCK_PATH, "r"
    console.log "Ya existe un proceso corriendo el `reducer`."
    console.log "Si esta seguro que no es asi, $ rm #{LOCK_PATH}"
    process.exit -1

  catch Error
    # Doesnt exists? OK (y)
    fd = fs.openSync LOCK_PATH, "w"
    fs.writeSync fd, "foobar"
    fs.closeSync fd

  MongoClient.connect DB_URL, {}, (err, conn) ->
    assert.ifError err
    console.log "Conección exitosa a la DB."

    MongoClient.connect METEOR_URL, {}, (err, conn2) ->
      assert.ifError err
      console.log "Conección exitosa a la DB."

      # close connection when SIGINTerrupted
      process.on 'SIGINT', (err) ->
        conn.close()
        conn2.close()
        fs.unlink LOCK_PATH
        process.exit 0

      processor(conn, conn2)

  mode = (array) ->
    ###
    Devuelve la moda de un arreglo de cadenas.
    ###

    assert.notStrictEqual array.length, 0
    # transformo los obj en str y luego calculo su moda. Ese es el correcto
    _arr = []
    array.forEach (item) ->
      _arr.push JSON.stringify item
    array = _arr

    modeMap = {}
    maxEl = array[0]
    maxCount = 1
    for el in array
      if modeMap[el] is undefined
        modeMap[el] = 1
      else
        modeMap[el]++
      if modeMap[el] > maxCount
        maxEl = el
        maxCount = modeMap[el]

    JSON.parse maxEl

  mapping = (task, coll, conn, conn2) ->
    ###
    Prepara task para ser reducido.

    Debe buscar la moda de los resultados de map para cada slice, el cual se lo
    considera correcto. Luego une los resultados de los slices y los agrega en
    `reduce_data`. Finalmente saca de `available_slices` los ya procesado.
    ###

    results = task.map_results
    _real_result = {} # sid => result

    # Obtengo la moda de los `maps_results` que tengan mas de 5 valores.
    for sid, res of results
      if res.length >= 5 and parseInt(sid) in task.available_slices
        _real_result[sid] = mode res

    if Object.keys(_real_result).length is 0
      return

    console.log("mapeando el task #{task._id}."
      "Available_slices=#{task.available_slices.length}")

    # Busco los sids a eliminar de `available_slices`.
    _unavailable_sids = (parseInt sid for sid in Object.keys _real_result)

    # Uno los `map_results` que tengan la misma llave.
    _data = {}
    for sid, reduce_data of _real_result
      for key, vals of reduce_data
        _data[key] = [] unless _data.hasOwnProperty key
        _data[key].push.apply _data[key], vals

    # Preparo los datos para ser reducidos.
    _reduce_data = {}
    for k, vals of _data
      _reduce_data["reduce_data.#{k}"] =
        $each: vals

    # Elimino los `maps_result` ya procesados
    _used_maps_results = {}
    for sid in _unavailable_sids
      _used_maps_results["map_results.#{sid}"] = ""

    # Preparo la consulta
    _update =
      $unset: _used_maps_results
      $push: _reduce_data
      $pull: {
        available_slices: {$in: _unavailable_sids}
      }

    # Ejecuto la consulta
    logs = conn2.collection "Tasks"

    coll.findOneAndUpdate {_id: task._id}, _update, {returnOriginal: false}, (err, doc) ->
      assert.ifError err
      task = doc.value
      map_results = {}
      reduce_data = {}
      for k,v of task.map_results
        map_results[k] = v.length
      for k,v of task.reduce_data
        reduce_data[k] = v.length
      logs.updateOne {task: task._id}, {$set: {available_slices: task.available_slices,map_results: map_results, reduce_data: reduce_data}}, (err) ->
        assert.ifError err

  reducing = (task, coll, conn, conn2) ->
    ###
    Busca en los resultados de *reduce* los correctos. Ademas, Verifica si se
    termino la tarea. De ser asi, es movido a `task_results`.
    ###

    results = {}
    _real_result = {}
    _unset = {}

    for key, res of task.reduce_results
      if res.length >= 5
        _real_result[key] = mode res
        results["results.#{key}"] = _real_result[key]

    if Object.keys(results).length is 0
      return

    console.log "Esta siendo reducida el task_id: #{task._id}"

    for key in Object.keys _real_result
      _unset["reduce_results.#{key}"] = ""

    # Preparo la consulta
    _update =
      $unset: _unset
      $set: results

    # Ejecuto la consulta
    logs = conn2.collection "Tasks"

    coll.findOneAndUpdate {_id: task._id}, _update, {returnOriginal: false}, (err, doc) ->
      assert.ifError err
      task = doc.value

      logs.updateOne {task: task._id}, _update, (err) ->
        assert.ifError err
        if _.difference(
          Object.keys(task.reduce_results),
          Object.keys(_real_result)).length is 0
          console.log "Terminó completamente el task #{task._id}"

          task_results = conn.collection "task_results"
          task_result =
            result: _real_result
            user: task.user
            task: task._id
          task_results.insertOne task_result, (err, result) ->
            assert.ifError err

            coll.updateOne {_id: task._id}, {$set: {finished: true}}, (err, result) ->
              assert.ifError err
              assert.strictEqual result.result.n, 1, "updated record #{result.result.n} != 1"
              logs.updateOne {task: task._id}, {$set: {finished: true}}, (err) ->
                assert.ifError err

  processor = (conn, conn2) ->
    ###
    Reduce o mapea las task de la db, si no hay pendientes se duerme
    ###

    tasks_collection = conn.collection "tasks"

    tasks_collection.find(MAPPING_QUERY).count (err, _n) ->
      assert.ifError err
      if _n isnt 0
        tasks_collection.find(MAPPING_QUERY).each (err, task) ->
          assert.ifError err
          if task
            mapping task, tasks_collection, conn, conn2

    tasks_collection.find(REDUCING_QUERY).count (err, _n) ->
      assert.ifError err
      if _n isnt 0
        tasks_collection.find(REDUCING_QUERY).each (err, task) ->
          assert.ifError err
          if task
            reducing task, tasks_collection, conn, conn2

    setTimeout(processor, 10000, conn, conn2)

# Si estoy en el proceso padre
if cluster.isMaster
  cluster.fork() # Creo proceso hijo
  cluster.on 'exit', (worker) ->
    console.log "Murió un Worker :("
    fs.unlink LOCK_PATH
    cluster.fork() # Si muere un proceso por algun motivo, creo otro
else
  worker() # Si soy un proceso hijo ejecuto la funcion workers
