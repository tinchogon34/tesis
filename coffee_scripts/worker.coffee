###
  Contiene el código a ser ejecutado en el Web Worker. No es servido como un
  archivo estático porque se le debe agregar las funciones map o reduce del
  investigador.

  Realiza las llamadas a `map` o `reduce` teniendo en cuenta de no hacer un
  uso *intensivo* de los recursos del cliente.

  Se comunica con `proc.js` para recibir los datos y enviarle los resultados.
####

importScripts("https://cdn.socket.io/socket.io-1.3.5.js")

WORK_URL = 'http://192.168.0.111:3000/work'
DATA_URL = 'http://192.168.0.111:3000/data'
SOCKET_URL = 'http://192.168.0.111:3000'

@cola = null

self.id = self.slice = self.fn = self.reducing = null
self.socket = io.connect(SOCKET_URL)
# Aqui guarda los resultados la funcion `map`
# Deben tener una estructura de Array[Array[2], Array[2], ...]
result = []

self.socket.on 'finish', ->
  postMessage
    type: "no_more"

self.socket.on 'new_work', (data) ->
  process_response(data)

get_data = ->
  # Trae datos del server y se los entrega al worker para que trabaje
  self.socket.emit 'ready'

process_response = (data) ->
  prepare_data data
  @cola.wake()

prepare_data = (data) ->
  self.fn = self.slice = null
  @cola.setData data.data
  self.reducing = data.reducing
  self.id = data.task_id
  if self.reducing
    self.fn = eval(data.ireduce)
  else
    self.fn = eval(data.imap)
    self.slice = data.slice_id

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
  self.socket.emit 'work_results',
    task_id: self.id
    slice_id: self.slice
    result: result
    reducing: self.reducing

# General Porpouse functions
self.log = (msg, others...) ->
  #console.log "[Worker] #{msg}", others...

self.error = (msg) ->
  console.error "[Worker] #{msg}"

self.emit = (key, val) ->
  # Es usada en el map para insertar un resultado.
  if typeof key isnt "string"
    throw new Error("Key debe ser un String pero es #{typeof key}")
  if val is undefined
    throw new Error("val no debe ser undefined")
  self.log "emit con #{key} #{val}"
  result.push [key, val]


class Cola
  ###
  Realizar las llamadas a `map` o `reduce`. Se duerme `this.sleeping` ms y
  continua trabajando.
  ###

  constructor: () ->
    self.log "Creando Cola"
    @i = 0
    @_data = null
    @_keys = null
    @executing = false # TODO: se usa?
    @sleeping = true
    @_tout = null

  _process: () ->
    ###
    Procesa un elemento de @_data y se espera una ventana de tiempo para
    seguir ejecutando la siguiente
    ###
    self.log "@_process #{@executing} #{@sleeping}"
    if @executing or @sleeping
      return

    @executing = true
    if @i < @_keys.length
      self.log "ejecutando map con #{@_keys[@i]} y #{@_data[@_keys[@i]]}"
      self.fn @_keys[@i], @_data[@_keys[@i]]
      @i++

    else  # termino de procesar.
      self.log "termino de procesar"
      @_sendResult()

    # Hay una ventana de tiempo entre cada llamada map.
    if not @sleeping
      @_tout = setTimeout(=>
        self.log "desde el timeout"
        @_process()
      , 50)
    @executing = false

  _sendResult: () ->
    self.log "_sendResult"
    @sleep()
    # TODO: Aparente esta de mas, borrarlo
    ###
    # create a copy
    _result = []
    result.forEach (item) ->
      _result.push item.slice()
    ###
    self.log "_sendResult con ", result

    send_result()

  setData: (data) ->
    self.log "setData"
    result = []
    @i = 0
    @_data = data
    @_keys = Object.keys data

  wake: () ->
    self.log "wake"
    return if not @sleeping
    @sleeping = false
    @_process()

  sleep: () ->
    self.log "sleep"
    clearTimeout @_tout
    @sleeping = true

@cola = new Cola()
get_data()
@onmessage = (evnt) ->
  # Comunicación con `proc.js`.
  msg = evnt.data
  switch msg.type
    when "pause"
      console.log "Pause"
      self.log "Pause received"
      cola.sleep()

    when "resume"
      self.log "Resuming received"
      cola.wake()
