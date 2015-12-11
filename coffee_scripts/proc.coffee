###
proc.coffee Es el archivo que se distribuye al cliente que ejecuta el worker.
Se encarga de pedir el *worker* y luego iterar en lo siguiente: traer datos,
ejecutar, enviar resultados.

Es el intermediador entre el Web Worker (hilo que se ejecuta en el cliente) y el
servidor de Tareas.

Solo se pide un Worker, que puede ser para mapear o reducir. Luego datos. Si se
termina, termina todo.
###

MAX_WORKERS_NUM = navigator.hardwareConcurrency || 1
DEFAULT_WORKERS = MAX_WORKERS_NUM
MIN_WORKERS_NUM = 0
WORKERS = []
MOBILE_IDLE_SECONDS = 10
WORKER_CODE = null
WORKER_CODE_URL = "http://10.0.0.120:3000/worker.js"

current_workers_num = 0
worker_script = document.getElementById("processor")
slider_enabled = worker_script.getAttribute("data-slider").toLowerCase() == "true"
default_workers = parseFloat(worker_script.getAttribute("data-default-workers"))
min_workers = parseFloat(worker_script.getAttribute("data-min-workers"))
max_workers = parseFloat(worker_script.getAttribute("data-max-workers"))

if not isNaN(default_workers)
  DEFAULT_WORKERS = default_workers

if not isNaN(min_workers)
  MIN_WORKERS_NUM = min_workers

if not isNaN(max_workers)
  MAX_WORKERS_NUM = max_workers

callAjax = (url, callback) ->
  xmlhttp = undefined
  # compatible with IE7+, Firefox, Chrome, Opera, Safari
  xmlhttp = new XMLHttpRequest

  xmlhttp.onreadystatechange = ->
    if xmlhttp.readyState == 4 and xmlhttp.status == 200
      callback xmlhttp.responseText
    return

  xmlhttp.open 'GET', url, true
  xmlhttp.send()
  return

class ProcWorker
  # Encapsula los detalles del Web Worker.

  constructor: ->
    ###
     Construye el worker y lo prepara para que empieze a ejecutarlo.
    ###
    @worker = new Worker window.URL.createObjectURL new Blob [WORKER_CODE],
      type: "text/javascript"

    @worker.onmessage = (evnt) =>
      data = evnt.data
      switch data.type
        when "no_more"
          WORKERS.splice WORKERS.indexOf(self), 1
          @worker.terminate()
          if slider_enabled
            slider = document.getElementsByName("workers-range")[0]
            slider.value = WORKERS.length
            slider.nextSibling.innerHTML = WORKERS.length

  postMessage: (msg) ->
    @worker.postMessage msg

  terminate: ->
    @worker.terminate()

refreshWorkers = ->
  return if current_workers_num == WORKERS.length
  difference = Math.abs(current_workers_num - WORKERS.length)
  if current_workers_num > WORKERS.length
    for i in [0...difference]
      WORKERS.push(new ProcWorker)
  else
    for i in [0...difference]
      rand = Math.floor(Math.random() * WORKERS.length)
      WORKERS[rand].terminate()
      WORKERS.splice(rand, 1)

###
Crea el div flotante para que el usuario pueda manejar la cantidad de workers que quiere aportar
###
createSlider = ->
  outer_div = document.createElement("div")
  outer_div.setAttribute("style", "position: absolute;  width: 100px;  right: 40px;  bottom: 20px;")
  label = document.createElement("label")
  label.setAttribute("for","workers-range")
  label.innerHTML = WORKERS.length
  input = document.createElement("input")
  outer_div.appendChild(input)
  outer_div.appendChild(label)
  input.type = "range"
  input.setAttribute("name","workers-range")
  input.className = "workers-range"
  input.setAttribute("min",MIN_WORKERS_NUM)
  input.setAttribute("max",MAX_WORKERS_NUM)
  input.setAttribute("step",1)
  input.setAttribute("value",WORKERS.length)
  document.body.appendChild(outer_div)
  input.addEventListener "change", ->
     current_workers_num = parseInt(this.value)
     label.innerHTML = this.value
     refreshWorkers()

resume = ->
  for worker in WORKERS
    worker.postMessage
      type: "resume"

init = ->
  return resume() if WORKER_CODE isnt null
  callAjax WORKER_CODE_URL, (res) ->
    WORKER_CODE = res

    for i in [0...DEFAULT_WORKERS]
      WORKERS.push(new ProcWorker)

    if slider_enabled
      createSlider()

pause = ->
  for worker in WORKERS
    worker.postMessage
      type: "pause"

# Start working!
if typeof(Worker) isnt "undefined"
  console.log '%cComienza proc.js', 'background: #222; color: #bada55;font-size:40px;'
  init()
  if /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    do inactivityTime = ->
      timeout = null

      resetTimer = ->
        clearTimeout(timeout)
        pause()
        timeout = setTimeout(init, MOBILE_IDLE_SECONDS*1000)

      window.onload = resetTimer
      window.addEventListener('touchstart', resetTimer, false);
      window.addEventListener('touchmove', resetTimer, false);
      window.addEventListener('touchend', resetTimer, false);
else
  console.error "Su navegador no soporta WebWorkers :("
