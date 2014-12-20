###
proc.coffee Es el archivo que se distribuye al cliente que ejecuta el worker.
Se encarga de pedir el *worker* y luego iterar en lo siguiente: traer datos,
ejecutar, enviar resultados.

Es el intermediador entre el Worker (hilo que se ejecuta en el cliente) y el
servidor de Tareas.

Solo se pide un Worker y luego datos.
###

# TODO: Varios de estas definiciones no sirven. Borrarlas.
sleep_time = undefined
slice_id = undefined
start_worker = undefined
task_id = undefined
tiempo_de_ejecucion = undefined
worker = undefined
worker_code = undefined

POST_URL = "http://127.0.0.1:3000/data"
LOG_URL = "http://127.0.0.1:3000/log"
WORK_URL = "http://127.0.0.1:3000/work"
DATA_URL = "http://127.0.0.1:3000/data"
tiempo_de_ejecucion = 5000
sleep_time = 2500
worker = null
task_id = null
slice_id = null
worker_code = null
data = null
get_work_interval = null
get_work_running = false
blob = null
intervalId = null 
pause = true


class _Worker
  # Encapsula los detalles del Worker.
  
  constructor: (code, task) ->
    ###
     Construye el worker y lo prepara para que empieze a ejecutarlo.
    ###

    @_ready = false
    @_pause_id = null
    @_task = task
    @worker = new Worker window.URL.createObjectURL new Blob [code],
      type: "text/javascript"
    
    @worker.onmessage = (evnt) =>
      msg = evnt.data
      switch msg.type
        when "send_result"
          console.log  msg.args
          _recv = JSON.parse(msg.args)
          console.log "Recibi un send_result con", _recv
          @_task.next _recv

        when "ready"
          console.log "Recibi ready"
          @_ready = true
        
        else
          console.log "Unhandled msg #{msg}"
    console.log "Web worker construido."

  feed: (data) ->
    if not @_ready
      setTimeout(() =>
        @feed(data)
      , 100)
      return

    @worker.postMessage
      type: "start"
      args: data

  isReady: () ->
    # esta lista para recibir ser datos?
    @_ready

class Task
  # Se encarga de la comunicaciÃ³n con el servidor de tareas.

  constructor: () ->
    @id = null
    @reducing = null
    @_worker = null
    @_slice = null # current slice_id
    @_data = null # data related with slice
    @_result = null

  init: () ->
    $.getJSON(WORK_URL).done((json, textStatus, jqXHR) =>
      if json.task_id is 0
        console.log "Nada que hacer"
        return

      try
        console.log "init Task for " + if json.reducing then "Reducing" else "mapping"
        @id = json.task_id
        @reducing = json.reducing
        @_worker = new _Worker json.code, @
        @get_data()

      catch err
        console.error err.message
        throw new Error "Failed to create Worker"

    ).fail (jqXHR, textStatus, errorThrown) ->
      console.error jqXHR
      throw new Error "Cannot grab Task"

  get_data: (callback=->) ->
    # Trae datos del server y se los entrega al worker para que trabaje
    $.getJSON(DATA_URL, {
        task_id: @id
        reducing: @reducing
      }).done((json, textStatus, jqXHR) =>
        console.log "GET /data trajo", json
        @_prepare_data json
        @_worker.feed @_data

      ).fail (jqXHR, textStatus, errorThrown) ->
        console.error "Cannot grab data from server"

  next: (data) ->
    # POSTea `data` al servir, pide mas datos y alimenta al worker.
    console.log "next con ", data
    @_prepare_result data
    @_send_result()

  _prepare_data: (json) ->
    @_slice = json.slice_id if not @reducing
    @_data = json.data
    # TODO: delete next line
    console.log "_prepare_data", @id, @_slice, @_data

  _prepare_result: (result) ->
    ###
    Antes de enviarlo al server hay que dejar el `result` preparar para 
    aplicarle el `reduce`
    ###
    console.log "pre result", result
    @_result = {}
    result.forEach (element) =>  
      if element.length isnt 2
        console.error "Result mal formado en el worker", result
        return

      val = element.pop()
      key = element.pop()
      @_result[key] = [] unless @_result.hasOwnProperty key
      @_result[key].push val
      console.log "pre resulting...", @_result

  _send_result: () ->
    console.log "sending result #{@id}, #{@_slice}", @_result
    $.ajax(POST_URL,
      data: JSON.stringify
        task_id: @id
        slice_id: @_slice
        result: @_result
        reducing: @reducing
      contentType: "application/json"
      dataType: "json"
      type: "post"

    ).done((json, textStatus, jqXHR) =>
      @_prepare_data json
      @_worker.feed @_data

    ).fail (jqXHR, textStatus, errorThrown) ->
      console.error "Cannot POST result to server #{textStatus}"
      console.error jqXHR


# remove?
process_response = (json) ->
  try
    if json.task_id is 0
      worker.terminate()  if worker?
      task_id = null
      wait_for_new_tasks()  unless get_work_running
      return
  
    clearInterval get_work_interval
    get_work_running = false
    data = json.data
    slice_id = json.slice_id
  
    if task_id isnt json.task_id
      worker.terminate()  if worker isnt null
      task_id = json.task_id
      worker_code = json.worker
      create_worker()
    start_worker()
  
  catch err
    throw new Error "FATAL: #{err.message}"

toggle_pause = ->
  clearInterval intervalId
  worker.postMessage
    type: "pause"
    sleep_time: sleep_time

  console.log "pause" + " send"
  intervalId = setInterval(toggle_pause, tiempo_de_ejecucion)
  return

wait_for_new_tasks = ->
  get_work_running = true
  console.log "<a style='color:red'>Esperando nuevos trabajos...</a>"
  get_work_interval = setInterval("get_work()", 5000)
  return


# Start working!
t = new Task()
console.log "comienza proc.js"
t.init()