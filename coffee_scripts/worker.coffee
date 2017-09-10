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
  # Le avisa al servidor que esta listo para recibir datos
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
  Antes de enviarlo al server hay que dejar el `result` preparar para
  aplicarle el `reduce`
  ###
  res = {}
  result.forEach (element) =>
    if element.length isnt 2
      console.error "Result mal formado en el worker", result
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
  # Es usada en el map para insertar un resultado.
  if typeof key isnt "string"
    throw new Error("Key debe ser un String pero es #{typeof key}")
  if val is undefined
    throw new Error("val no debe ser undefined")
  #self.log "emit con #{key} #{val}"
  result.push [key, val]

class Cola
  ###
  Realizar las llamadas a `map` o `reduce`. Se duerme `this.sleeping` ms y
  continua trabajando.
  ###

  constructor: () ->
    #self.log "Creando Cola"
    @i = 0
    @_data = null
    @_keys = null
    @executing = false
    @sleeping = true
    @_tout = null

  _process: () ->
    ###
    Procesa un elemento de @_data y se espera una ventana de tiempo para
    seguir ejecutando la siguiente
    ###
    #self.log "@_process #{@executing} #{@sleeping}"
    if @executing or @sleeping
      return

    @executing = true
    if @i < @_keys.length
      #self.log "ejecutando map con #{@_keys[@i]} y #{@_data[@_keys[@i]]}"
      fn @_keys[@i], @_data[@_keys[@i]]
      @i++

    else  # termino de procesar.
      #self.log "termino de procesar"
      @_sendResult()

    # Hay una ventana de tiempo entre cada llamada map.
    if not @sleeping
      @_tout = setTimeout(=>
        #self.log "desde el timeout"
        @_process()
      , 50)
    @executing = false

  _sendResult: () ->
    #self.log "_sendResult"
    @sleep()
    #self.log "_sendResult con ", result

    send_result()

  setData: (data) ->
    #self.log "setData"
    result = []
    @i = 0
    @_data = data
    @_keys = Object.keys data

  wake: () ->
    #self.log "wake"
    return if not @sleeping
    @sleeping = false
    @_process()

  sleep: () ->
    #self.log "sleep"
    clearTimeout @_tout
    @sleeping = true

cola = new Cola()

# Crea una conexion por WebSockets al servidor
socket = io.connect SOCKET_URL,
  transports: [ 'websocket' ]

# Cuando me conecto por primera vez, pido datos
socket.on 'connect', ->
  get_data()

# Cuando recibo un mensaje finish del servidor, le aviso a proc.js que este
# worker ya termino
socket.on 'finish', ->
  postMessage
    type: "no_more"

# Cuando recibo un mensaje new_work del servidor, proceso los datos
socket.on 'new_work', (data) ->
  process_response(data)

# Maneja los mensajes enviados desde proc.js al worker
onmessage = (evnt) ->
  # Comunicación con `proc.js`.
  msg = evnt.data
  switch msg.type
    when "pause" # Usado para pausar el trabajo del worker en mobile
      #self.log "Pause received"
      cola.sleep()

    when "resume" # Usado para resumir el trabajo del worker en mobile
      #self.log "Resuming received"
      cola.wake()
