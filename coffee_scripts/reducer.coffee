###
  Debe ser ejecutado en segundo plano. Es un servicio que busca tareas que
  para cambiarlas de estado. Estos cambios suceden cuando
  1) Termino la fase de map y debe empezar la de reduce.
  2) Durante la fase reduce. Adicionalmente detecta cuando termina y mueve la
  tarea a otra Colección.
###
# dependencias
MongoClient = require('mongodb').MongoClient
sleep = require 'sleep'
assert = require 'assert'
_ = require "underscore"


DB_URL = 'mongodb://127.0.0.1:27017/tesis'
MAPPED = "this.available_slices.length > 1 && this.enabled_to_process"
REDUCING = "this.available_slices.length === 0 && this.reduce_results !== {} && this.enabled_to_process"


mode = (array) ->
  ###
  Devuelve la moda de un arreglo de cadenas.
  ###
  if array.length == 0
    return null
  
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


process = (task, coll) ->
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
    if err isnt null
      console.error "ERROR: #{err}"
    else
      if count isnt 1
        console.error "WARNING: It should update 1 record but #{count} where
          updated"
      console.log "INFO: #{status}"


reducing = (task, coll, conn) ->
  ###
  Busca en los resultados de *reduce* los correctos. Ademas, Verifica si se 
  termino la tarea. De ser asi, debe ser movido a otra colleccion.
  ###
  results = {}
  _real_result = {}
  _unset = {}

  for key, res of task.reduce_results
    if res.length >= 5
      _real_result[key] = mode res
      results["results.#{key}"] = _real_result[key]

  for key in Object.keys _real_result
    _unset["reduce_results.#{key}"] = ""

  # Preparo la consulta
  _update = 
    $unset: _unset
    $set: results

  # Ejecuto la consulta
  coll.update {_id: task._id}, _update, (err, count, status) ->
    return console.error "ERROR: #{err}" if err isnt null
    console.log "INFO: Termino de reducir #{status}"

  if _.difference(Object.keys(task.reduce_results), Object.keys(_real_result)).length is 0
    console.log "termino"
    # TODO: mover el task a otra coleccion
    worker_results = conn.collection "worker_results"
    worker_result =
      result: results
      user: task.user
      worker: task._id
    worker_results.insert [worker_result], (err, result) ->
      assert.ifError err

MongoClient.connect DB_URL, (err, conn) ->
  return console.log(err) if err isnt null
  console.log "Conección exitosa a la BD."
  coll = conn.collection "workers"

  # Preparar las task para que ejecuten el reduce
  coll.find({$where: MAPPED}).each (err, task) ->
    return console.error(err) if err isnt null
    if task is null
      one = true 
      console.log "No hay tareas a mapear"
      return
    
    console.log "Ha terminado de la fase *map* el task_id: ", task._id
    process task, coll

  # Procesar task que estan siendo reducidas.  
  coll.find({$where: REDUCING}).each (err, task) ->
    return console.error(err) if err isnt null
    return two = true if task is null
    
    console.log "Esta siendo reducida el task_id: ", task._id
    reducing task, coll, conn

