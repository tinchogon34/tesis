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
  self.log "emit con #{key} #{val}"
  result.push [key, val]


class Cola
  ###
  Realizar las llamadas a `map` o `reduce`. Se duerme `this.sleeping` ms y 
  continua trabajando.
  ###   
  
  constructor: () ->
    @i = 0
    @_data = null
    @_keys = null
    @executing = false
    @sleeping = true
    @_tout = null
    if self.investigador_map isnt undefined
      @fn = self.investigador_map
      log "El Web Worker será utilizado para *map*"
    else if self.investigador_reduce isnt undefined
      @fn = self.investigador_reduce
      log "El Web Worker será utilizado para *reduce*"
    else
      error "No se encontro la funcion *map* ni *reduce*"

  _process: () ->
    ###
    Procesa un elemento de @_data y se espera una ventana de tiempo para
    seguir ejecutando la siguiente
    ###
    if @executing or @sleeping
      return
    self.log "@_process #{@executing} #{@sleeping}"
    
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

  _initData: () ->
    log "init data"
    @_keys = null
    @_data = null
    @i = 0

  _sendResult: () ->
    @sleep()
    # create a copy
    _result = []
    result.forEach (item) ->
      _result.push item.slice()

    self.log "_sendResult", result
    
    postMessage
      type: "send_result"
      args: JSON.stringify result
    #@_initData()      
    
  setData: (data) ->
    result = []
    @i = 0
    @_data = data
    @_keys = Object.keys data

  wake: () ->
    self.log "wake"
    if not @sleeping
      return
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