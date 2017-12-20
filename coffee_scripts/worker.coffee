###
  Contiene el código a ser ejecutado en el Web Worker. No es servido como un
  archivo estático porque se le debe agregar las funciones map o reduce del
  investigador.

  Realiza las llamadas a `map` o `reduce` teniendo en cuenta de no hacer un
  uso *intensivo* de los recursos del cliente.

  Se comunica con `proc.js` para avisar cuando ya ha terminado, o para que este
  le diga cuando pausarse o resumirse.
###

HOST_CONFIG = {host: "tesis.codingways.com", port: "3002"}
HOST_URL = "http://"+HOST_CONFIG.host+":"+HOST_CONFIG.port
importScripts(HOST_URL+"/socket.io/socket.io.js")

WORK_URL = HOST_URL+"/work"
DATA_URL = HOST_URL+"/data"
SOCKET_URL = HOST_URL

cola = id = slice = fn = reducing = socket = null

# Aqui guarda los resultados la funcion `map`
# Deben tener una estructura de Array[Array[2], Array[2], ...]
result = []

get_data = ->
  # Send message to processor 'ready to process'
  socket.emit 'ready'

process_response = (data) ->
  prepare_data data
  cola.wake()

prepare_data = (data) ->
  fn = slice = null
  cola.setData data.data
  reducing = data.reducing
  id = data.task_id
  if reducing
    fn = eval(data.ireduce)
  else
    fn = eval(data.imap)
    slice = data.slice_id

prepare_result = ->
  ###
  Before sending result to server, transform it to `reduce` structure
  ###
  res = {}
  result.forEach (element) =>
    if element.length isnt 2
      console.error "Result with bad format", result
      return

    val = element.pop()
    key = element.pop()
    res[key] = [] unless res.hasOwnProperty key
    res[key].push val
  result = res

send_result = () ->
  prepare_result()
  socket.emit 'work_results',
    task_id: id
    slice_id: slice
    result: result
    reducing: reducing

# General Porpouse functions
self.log = (msg, others...) ->
  console.log "[Worker] #{msg}", others...

self.error = (msg) ->
  console.error "[Worker] #{msg}"

self.emit = (key, val) ->
  # Used in map for inserting a result.
  if typeof key isnt "string"
    throw new Error("key expected a String but #{typeof key} received")
  if val is undefined
    throw new Error("val can't be undefined")
  result.push [key, val]

class Cola
  ###
  Executes `map` and `reduce` functions. Sleep some time between executions.
  ###

  constructor: () ->
    @i = 0
    @_data = null
    @_keys = null
    @executing = false
    @sleeping = true
    @_tout = null

  _process: () ->
    ###
    Process an element from @_data and then wait a time window before processing next
    ###
    if @executing or @sleeping
      return

    @executing = true
    if @i < @_keys.length
      fn @_keys[@i], @_data[@_keys[@i]]
      @i++

    else  # processing finished
      @_sendResult()

    # Time window between each execution
    if not @sleeping
      @_tout = setTimeout(=>
        @_process()
      , 50)
    @executing = false

  _sendResult: () ->
    @sleep()

    send_result()

  setData: (data) ->
    result = []
    @i = 0
    @_data = data
    @_keys = Object.keys data

  wake: () ->
    return if not @sleeping
    @sleeping = false
    @_process()

  sleep: () ->
    clearTimeout @_tout
    @sleeping = true

cola = new Cola()

# Create connection to server through WebSockets
socket = io.connect SOCKET_URL,
  transports: [ 'websocket' ]

# When connected, request initial data
socket.on 'connect', ->
  get_data()

# When finish message received from server, query processor to finish
socket.on 'finish', ->
  postMessage
    type: "no_more"

# When new_work message received from server, process data
socket.on 'new_work', (data) ->
  process_response(data)

# Manage message received from processor
onmessage = (evnt) ->
  msg = evnt.data
  switch msg.type
    when "pause" # Used in mobile to pause processing
      cola.sleep()

    when "resume" # Used in mobile to resume processing
      cola.wake()


