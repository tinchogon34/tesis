LineByLineReader = require 'line-by-line'
fs = require 'fs'
request = require 'request'
assert = require 'assert'

# Para que no importe que el certificado https no sea firmado
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

login_url = 'https://localhost:8080/login'
workers_url = 'https://localhost:8080/api/v1/workers'
worker_results_url = 'https://localhost:8080/api/v1/worker_results'
file = './text'
lr = new LineByLineReader(file)
index = 0
hash = {}

# Guarda el token que se devuelve cuando se logea con las credenciales
# correctas, luego es el que se utiliza para hacer los requests
token = null

createdWorker = null
slices_count = 0

lr.pause() # Pausa la lectura del archivo

lr.on 'line', (line)->
  hash[index] = line # { 0: linea1, 1: linea2, .....}
  if (index+1) % 100 == 0 # Si ya lei 100 lineas...
    lr.pause() # Pauso la lectura del archivo
    send_data hash # Mando los datos
    hash = {} # Limpio el hash para los proximos 100
  index++
lr.on 'end', -> # Si termine de leer el archivo
  if Object.keys(hash).length > 0 # Si quedaron datos en el hash
    send_data hash, true  # Los envio y despues habilito para procesar
  else
    enable_to_process() # Sino solo habilito para procesar

# El worker con la estructura basica, funcion map y reduce solamente
newWorker =
  imap: 'function (k, v) {
    var countWords = function(s){
    s = s.replace(/(^\s*)|(\s*$)/gi,"");
    s = s.replace(/[ ]{2,}/gi," ");
    s = s.replace(/\\n /,"\\n");
    return s.split(" ").length;};
    self.log("inv in");
    self.emit("llave", countWords(v));
    self.log("inv in out");};'
  ireduce: 'function (k, vals) {
    var total = vals.reduce(function(a, b) {
      return parseInt(a) + parseInt(b);});
    self.emit(k, total);};'

# Credenciales de un investigador ejemplo que esta en el seed (init_api_db.js)
loginCredentials =
  username: 'investigador'
  password: 'investigador'

# Me logeo con las credenciales
request.post login_url, { json: loginCredentials }, (error, response, body) ->
  assert.ifError error
  assert.equal response.statusCode, 200 # Si todo salio bien
  token = body.token # Guardo el bearer token que se me devolvio

  # Creo el worker definido anteriormente
  request.post(workers_url, {json: newWorker}, (error, response, worker) ->
    assert.ifError error
    assert.equal response.statusCode, 200 # Si todo salio bien

    createdWorker = worker # Guardo el worker creado
    lr.resume() # Resumo la lectura del archivo
  ).auth null, null, true, token

get_slices = (data, size) ->
  # {0: ..., 1: ...., 2: ..., 3: ...., 4: ....}
  # [{0: ..., 1: ...}, {2: ..., 3: ....}, {4: ....}]

  arr = []
  keysLength = Object.keys(data).length

  arr[i] = {} for i in [0...Math.ceil(keysLength/size)]
  i = 0
  contador = 0
  for key, value of data
    arr[i][key] = value
    contador++
    i++ if (contador) % size == 0
  return arr

send_data = (data, enable = false) ->
  # Divido los datos de un solo hash en un array de hashes de 50 elementos c/u
  slices = get_slices(data, 50)
  available_slices = []

  # Armo un array de slices disponibles con la cantidad de elementos que tengo
  # en slices
  available_slices[i] = (i+slices_count) for i in [0...slices.length]

  # Incremento la cantidad de slices que he enviado para poder ir armando
  # el arreglo de available_slices correctamente y no empezar siempre del
  # indice 0
  slices_count += slices.length
  
  # Armo del objeto que voy a postear a la db con los nuevos datos del worker
  json =
    data: data
    available_slices: available_slices
    slices: slices

  # Agrego los datos al worker
  request.post(workers_url+'/'+createdWorker._id+'/addData',
    {json: json},
    (error, response, updatedWorker) ->
      assert.ifError error
      assert.equal response.statusCode, 200 # Si todo salio bien

      if enable # Si ya se leyo la ultima linea
        enable_to_process() # Habilito para procesar
      else
        lr.resume() # Sino resumo la lectura del archivo
  ).auth null, null, true, token

# Habilito el worker para que sea procesado
enable_to_process = ->
  request.post(workers_url+'/'+createdWorker._id+'/enable',
    {json: true},
    (error, response, updatedWorker) ->
      assert.ifError error
      assert.equal response.statusCode, 200
  ).auth null, null, true, token