###
  Contiene el código a ser ejecutado en el Web Worker. No es servido como un
  archivo estático porque se le debe agregar las funciones map o reduce del
  investigador.

  Realiza las llamadas a `map` o `reduce` teniendo en cuenta de no hacer un 
  uso *intensivo* de los recursos del cliente.

  Se comunica con `proc.js` para recibir los datos y enviarle los resultados.
####

# Aqui guarda los resultados la funcion `map`
# Deben tener una estructura de Array[Array[2], Array[2], ...]
result = []

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
    @reducing = false

    if self.investigador_map isnt undefined
      @fn = self.investigador_map
      log "El Web Worker será utilizado para *map*"
    else if self.investigador_reduce isnt undefined
      @fn = self.investigador_reduce
      @reducing = true
      log "El Web Worker será utilizado para *reduce*"
    else
      throw new Error("No se encontro la funcion *map* ni *reduce*")

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
      @fn @_keys[@i], @_data[@_keys[@i]]
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
    
    postMessage
      type: "send_result"
      args: JSON.stringify result
    
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

cola = new Cola()
@onmessage = (evnt) ->
  # Comunicación con `proc.js`.
  
  msg = evnt.data
  switch msg.type
    when "start"
      # En args tiene los datos. Es arr de arr [["0", 1], ...]
      if not msg.args
        self.error "Datos invalidos:", msg.args
        return

      self.log "start", msg.args
      cola.setData msg.args
      cola.wake()
    
    when "pause"
      self.log "pause recv"
      cola.sleep()

    when "resume"
      self.log "resumign recv"
      cola.wake()      

# Avisar que esta listo para ejecutar las tareas.
@postMessage
  type: "ready"