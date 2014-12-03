MongoClient = require('mongodb').MongoClient
sleep = require 'sleep'
assert = require 'assert'

DB_URL = 'mongodb://127.0.0.1:27017/tesis'
WHERE_COND = "this.available_slices.length > 1 && this.status != 'reduced'"


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
  Debe buscar la moda de los resultados de map para cada slice, el cual se lo
  considera correcto. Luego une los resultados de los slices y los agrega en
  `reduce_data`. Finalmente saca de `available_slices` los ya procesado. 

  No llama a reduce, pues primero es necesario procesar todos los maps.
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


# Start here!
console.log "Conecting to DB..."
MongoClient.connect DB_URL, (err, conn) ->
  if err isnt null
    console.log err
    return
  console.log "Connected to DB"

  coll = conn.collection "workers"
  coll.find({$where: WHERE_COND}).nextObject (err, task) ->
    if err isnt null
      console.log "Error: ", err
      return
    if task is null
      return
    
    console.log "Procesando...", task._id
    process task, coll
    console.log "Finishing proccessing task ", task._id
    conn.close()