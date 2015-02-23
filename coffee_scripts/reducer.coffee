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

DB_URL = 'mongodb://127.0.0.1:27017/tesis'
MAPPED = "this.available_slices.length > 0 && this.enabled_to_process"
REDUCING = "this.available_slices.length === 0 && this.enabled_to_process"
LOCK_PATH = "/var/tmp/.tesis.lock"

# flags
flag_mapper =  true
flag_reducer = true

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


MongoClient.connect DB_URL, (err, conn) ->
  assert.ifError err
  console.log "Conección exitosa a la BD."

  # close connection when SIGINTerrupted
  process.on 'SIGINT', (err) ->
    conn.close()
    fs.unlink LOCK_PATH
    console.log "Goodbye ;)"
    process.exit 0

  caller(conn)


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


mapping = (task, coll) ->
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
    if res.length >= 5
      _real_result[sid] = mode res

  if Object.keys(_real_result).length is 0
    return

  console.log("mapeando el taks #{task._id}."
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
  coll.update {_id: task._id}, _update, (err, count, status) ->
    assert.ifError err
    assert.strictEqual count, 1, "updated record #{count} != 1"


reducing = (task, coll, conn) ->
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
  coll.update {_id: task._id}, _update, (err, count, status) ->
    assert.ifError err
    assert.strictEqual count, 1, "updated record #{count} != 1"

  if _.difference(
    Object.keys(task.reduce_results),
    Object.keys(_real_result)).length is 0
    console.log "termino completamen el task #{task._id}"

    task_results = conn.collection "task_results"
    task_result =
      result: _real_result
      user: task.user
    task_results.insert [task_result], (err, result) ->
      assert.ifError err

      coll.remove {_id: task._id}, (err, count) ->
        assert.ifError err


proccesor = (conn) ->
  ###
  Reduce o mapea las task de la bd, seteando correctamente los flags.
  ###

  coll = conn.collection "tasks"
  # Preparar las task para que ejecuten el reduce
  if flag_mapper
    flag_mapper =  false
    coll.find({$where: MAPPED}).each (err, task) ->
      assert.ifError err
      if task is null
        flag_mapper = true
        return

      mapping task, coll

  if flag_reducer
    flag_reducer = false
    # Procesar task que estan siendo reducidas.
    coll.find({$where: REDUCING}).each (err, task) ->
      assert.ifError err
      if task is null
        flag_reducer = true
        return

      reducing task, coll, conn


caller = (conn) ->
  ###
  Verifica que todas las tareas de `proccesor` terminen. Si lo estan, lo
  ejecuta de vuelta, si no se duerme.
  ###

  flags = flag_mapper or flag_reducer
  if flags
    proccesor(conn)
  setTimeout(caller, 3000, conn)
