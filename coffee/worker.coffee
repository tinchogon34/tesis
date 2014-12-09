###
* funciones utilizada en investigador_map para agregar valores 

investigador_map = function (k, v) {
  log("inv in");
  var ms = 1000;
  var started = new Date().getTime();
  while((new Date().getTime() - started) < ms) {
  }
  emit("llave", v*v);
  log("inv in out");
};

investigador_reduce = function (k, vals) {
  var total = vals.reduce(function(a, b) {
    return parseInt(a) + parseInt(b);
  });
  return total;
};

investigador_map = (k, v) -> 
  log "imap con #{k}, #{v}"
  ms = 1000
  started = new Date().getTime()
  while((new Date().getTime() - started) < ms)
    ;
  
  emit "llave", v * v
  log "inv in out"
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
  Se encarga de realizar las llamadas a `map` cuidando de no utilizar
  el máximo de los recursos del cliente.
  ###   
  
  constructor: (@map) ->
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
    if @executing or @sleeping
      return
    self.log "@_process #{@executing} #{@sleeping}"
    
    @executing = true
    if @i < @_keys.length
      self.log "ejecutando map con #{@_keys[@i]} y #{@_data[@_keys[@i]]}"
      @map @_keys[@i], @_data[@_keys[@i]]
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

# TODO: mirotear si estamos con map o reduce
cola = new Cola(self.investigador_map)
@onmessage = (evnt) ->
  # Comunicación del `proc` a este worker.
  
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

@postMessage
  type: "ready"