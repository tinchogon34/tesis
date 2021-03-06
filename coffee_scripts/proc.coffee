###
proc.coffee Es el archivo que se distribuye al cliente que ejecuta el worker.
Se encarga de pedir el *worker* y luego iterar en lo siguiente: traer datos,
ejecutar, enviar resultados.

Es el intermediador entre el Web Worker (hilo que se ejecuta en el cliente) y el
servidor de Tareas.
###

HOST_CONFIG = {host: "tesis.codingways.com", port: "3002"}
HOST_URL = "http://"+HOST_CONFIG.host+":"+HOST_CONFIG.port
# Por defecto el maximo de workers es la cantidad de procesadores
DEFAULT_WORKERS = 1
MIN_WORKERS_NUM = 0
MAX_WORKERS_NUM = 1
WORKERS = []
# Tiempo muerto de espera en mobile para empezar a procesar
MOBILE_IDLE_SECONDS = 10
WORKER_CODE_URL = HOST_URL+"/worker.js"

worker_code = null
current_workers_num = 0

# Obtengo parametros desde la página que incluye este script
worker_script = document.getElementById("processor")

slider_enabled = worker_script.getAttribute("data-slider") and worker_script.getAttribute("data-slider").toLowerCase() == "true"

config_default_workers = worker_script.getAttribute("data-default-workers") and switch worker_script.getAttribute("data-default-workers")
  when "low" then 1
  when "medium" then (navigator.hardwareConcurrency && Math.ceil(navigator.hardwareConcurrency/2)) or 1
  when "max" then navigator.hardwareConcurrency or 1
  else parseFloat(worker_script.getAttribute("data-default-workers"))

config_min_workers = worker_script.getAttribute("data-min-workers") and switch worker_script.getAttribute("data-min-workers")
  when "low" then 1
  when "medium" then (navigator.hardwareConcurrency && Math.ceil(navigator.hardwareConcurrency/2)) or 1
  when "max" then navigator.hardwareConcurrency or 1
  else parseFloat(worker_script.getAttribute("data-min-workers"))

config_max_workers = worker_script.getAttribute("data-max-workers") and switch worker_script.getAttribute("data-max-workers")
  when "low" then 1
  when "medium" then (navigator.hardwareConcurrency && Math.ceil(navigator.hardwareConcurrency/2)) or 1
  when "max" then navigator.hardwareConcurrency or 1
  else parseFloat(worker_script.getAttribute("data-max-workers"))

#default_workers = if worker_script.getAttribute("data-default-workers") == "max" then navigator.hardwareConcurrency or 1 else parseFloat(worker_script.getAttribute("data-default-workers"))
#min_workers = if worker_script.getAttribute("data-min-workers") == "max" then navigator.hardwareConcurrency or 0 else parseFloat(worker_script.getAttribute("data-min-workers"))
#max_workers = if worker_script.getAttribute("data-max-workers") == "max" then navigator.hardwareConcurrency or 1 else parseFloat(worker_script.getAttribute("data-max-workers"))

# Si hay algun parametro, reemplazo los valores por defecto
if not isNaN(config_default_workers)
  DEFAULT_WORKERS = config_default_workers

if not isNaN(config_min_workers)
  MIN_WORKERS_NUM = config_min_workers

if not isNaN(config_max_workers)
  MAX_WORKERS_NUM = config_max_workers

# Función utilitaria para hacer llamadas AJAX con método GET
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
    @worker = new Worker window.URL.createObjectURL new Blob [worker_code],
      type: "text/javascript"

    # Proceso los mensajes que el worker le manda a este script
    @worker.onmessage = (evnt) =>
      data = evnt.data
      switch data.type
        # Cuando no hay mas tareas termino el worker
        when "no_more"
          WORKERS.splice WORKERS.indexOf(self), 1
          @worker.terminate()
          # Si esta el slider habilitado, lo actualizo
          if slider_enabled
            slider = document.getElementsByName("workers-range")[0]
            slider.value = WORKERS.length
            slider.nextSibling.innerHTML = WORKERS.length

  postMessage: (msg) ->
    @worker.postMessage msg

  terminate: ->
    @worker.terminate()

# Funcion para mantener la consistencia entre el slider y los workers corriendo
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

# Resume worker execution
resume = ->
  for worker in WORKERS
    worker.postMessage
      type: "resume"

# Pause worker execution
pause = ->
  for worker in WORKERS
    worker.postMessage
      type: "pause"

# Request worker code through AJAX and create as many workers as configured
init = ->
  return resume() if worker_code isnt null
  callAjax WORKER_CODE_URL, (res) ->
    worker_code = res

    for i in [0...DEFAULT_WORKERS]
      WORKERS.push(new ProcWorker)

    if slider_enabled
      createSlider()

# Start working!
if typeof(Worker) isnt "undefined"
  console.log '%Starting proc.js', 'background: #222; color: #bada55;font-size:40px;'
  # If mobile then wait iddle before start
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
    init()
else
  console.error "Your browser doesn't support WebWorkers :("
