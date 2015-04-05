###
proc.coffee Es el archivo que se distribuye al cliente que ejecuta el worker.
Se encarga de pedir el *worker* y luego iterar en lo siguiente: traer datos,
ejecutar, enviar resultados.

Es el intermediador entre el Web Worker (hilo que se ejecuta en el cliente) y el
servidor de Tareas.

Solo se pide un Worker, que puede ser para mapear o reducir. Luego datos. Si se
termina, termina todo.
###


WORK_URL = "http://127.0.0.1:3000/work"
DATA_URL = "http://127.0.0.1:3000/data"


class ProcWorker
  # Encapsula los detalles del Web Worker.

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
          _recv = JSON.parse(msg.args)
          @_task.next _recv

        when "ready"
          @_ready = true

        else
          console.error "Unhandled msg #{msg}"

  feed: (data) ->
    if not @_ready or @_task.isPaused()
      setTimeout(() =>
        @feed(data)
      , 100)
      return

    @worker.postMessage
      type: "start"
      args: data

  isReady: () ->
    # esta listo para recibir ser datos?
    @_ready

class Task
  # Se encarga de la comunicación con el servidor de tareas.

  constructor: () ->
    @id = null
    @reducing = null
    @_worker = null
    @_slice = null # current slice_id
    @_data = null # data related with slice
    @_result = null
    @_paused = false

  init: () ->
    @_paused = false
    return if @_worker
    $.getJSON(WORK_URL).done((json, textStatus, jqXHR) =>
      if json.task_id is 0
        @_finish()
        return

      try
        @id = json.task_id
        @reducing = json.reducing
        @_worker = new ProcWorker json.code, @
        @get_data()

      catch err
        console.error err.message
        throw new Error "Failed to create Worker"

    ).fail (jqXHR, textStatus, errorThrown) ->
      console.error jqXHR
      throw new Error "Cannot grab Task"

  pause: () ->
    @_paused = true

  isPaused: () ->
    # esta listo para recibir ser datos?
    @_paused

  _finish: () ->
    ###
    Termino de procesar. Agrdece y cerra todo.
    ###
    if @_worker
      @_worker.worker.terminate()
    console.log "Gracias por procesar. Ya no tenemos nada mas que hacer ;)"

  get_data: (callback=->) ->
    # Trae datos del server y se los entrega al worker para que trabaje

    $.getJSON(DATA_URL, {
      task_id: @id
      reducing: @reducing
    }).done((json, textStatus, jqXHR) =>
      @_prepare_data json
      @_worker.feed @_data

    ).fail (jqXHR, textStatus, errorThrown) ->
      console.error "Cannot grab data from server"

  next: (data) ->
    # POSTea `data` al servir, pide mas datos y alimenta al worker.

    @_prepare_result data
    @_send_result()

  _prepare_data: (json) ->
    if json.status and json.status is "finished"
      @_finish()

    @_slice = json.slice_id if not @reducing
    @_data = json.data

  _prepare_result: (result) ->
    ###
    Antes de enviarlo al server hay que dejar el `result` preparar para
    aplicarle el `reduce`
    ###

    @_result = {}
    result.forEach (element) =>
      if element.length isnt 2
        console.error "Result mal formado en el worker", result
        return

      val = element.pop()
      key = element.pop()
      @_result[key] = [] unless @_result.hasOwnProperty key
      @_result[key].push val

  _send_result: () ->
    $.ajax(DATA_URL,
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

    ).fail (jqXHR, textStatus, errorThrown) =>
      if @reducing
         return @_finish()
      console.error "Cannot POST result to server #{textStatus}"
      console.error jqXHR


# Start working!
t = new Task()
console.log "comienza proc.js"

if /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
  do inactivityTime = ->
    timeout = null
    start = ->
      t.init()

    resetTimer = ->
      clearTimeout(timeout)
      t.pause()
      timeout = setTimeout(start, 30*1000)

    window.onload = resetTimer
    window.addEventListener('touchstart', resetTimer, false);
    window.addEventListener('touchmove', resetTimer, false);
    window.addEventListener('touchend', resetTimer, false);
else
  t.init()
