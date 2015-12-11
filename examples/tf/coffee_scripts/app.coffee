LineByLineReader = require 'line-by-line'
fs = require 'fs'
request = require 'request'
assert = require 'assert'

# Para que no importe que el certificado https no sea firmado
#process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

login_url = 'http://localhost:8080/login'
tasks_url = 'http://localhost:8080/api/v1/tasks'
task_results_url = 'http://localhost:8080/api/v1/task_results'
file = './text'
lr = new LineByLineReader(file)
index = 0
hash = {}
numLines = 0
# Guarda el token que se devuelve cuando se logea con las credenciales
# correctas, luego es el que se utiliza para hacer los requests
token = null
createdTask = null
#slices_count = 0

# El task con la estructura basica, funcion map y reduce solamente
newTask =
  imap: 'function (k, v) {
    var count = function(arr){
      return arr.reduce(function(m,e){
        e = e.toLowerCase();
        m[e] = (+m[e]||0)+1;
        return m;
        },{});
    };
    self.log("inv in");
    words = v.replace(/\\s\\s+/g, " ").replace(/^\\s+|\\s+$/g, "").replace(/[.,]/g,"").split(" ");
    countRes = count(words);
    for(k in countRes){
      self.emit(k,(countRes[k]));
    }
    self.log("inv in out");};'
  ireduce: 'function (k, vals) {
    var conc = vals.reduce(function(a, b) {
      return a + b;});
    self.emit(k, conc);};'

# Credenciales de un investigador ejemplo que esta en el seed (init_api_db.js)
loginCredentials =
  username: 'investigador'
  password: 'investigador'

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
  slices = get_slices(data, 100)
  #available_slices = []

  # Armo un array de slices disponibles con la cantidad de elementos que tengo
  # en slices
  #available_slices[i] = (i+slices_count) for i in [0...slices.length]

  # Incremento la cantidad de slices que he enviado para poder ir armando
  # el arreglo de available_slices correctamente y no empezar siempre del
  # indice 0
  #slices_count += slices.length

  # Armo del objeto que voy a postear a la db con los nuevos datos del task
  json =
    #available_slices: available_slices
    slices: slices

  # Agrego los datos al task
  request.post(tasks_url+'/'+createdTask._id+'/addData',
    {json: json},
    (error, response, updatedTask) ->
      assert.ifError error
      assert.equal response.statusCode, 200 # Si todo salio bien

      if enable # Si ya se leyo la ultima linea
        enable_to_process() # Habilito para procesar
      else
        lr.resume() # Sino resumo la lectura del archivo
  ).auth null, null, true, token

# Habilito el task para que sea procesado
enable_to_process = ->
  request.post(tasks_url+'/'+createdTask._id+'/enable',
    {json: true},
    (error, response, updatedTask) ->
      assert.ifError error
      assert.equal response.statusCode, 200
  ).auth null, null, true, token

lr.pause()
lr.on 'line', (line)->
  hash[index] = line if !!line # { 0: linea1, 1: linea2, .....}
  if (index+1) % 100 == 0  # Si ya lei 100 lineas...
    lr.pause() # Pauso la lectura del archivo
    if index == numLines
      send_data hash, true # Mando los datos
    else
      send_data hash
    hash = {} # Limpio el hash para los proximos 100
  else if (index+1) == numLines
    if Object.keys(hash).length > 0
      send_data hash, true
    else
      enable_to_process()
  index++

fs.createReadStream(file).on('data', (chunk) ->
  numLines += chunk.toString('utf8').split(/\r\n|[\n\r\u0085\u2028\u2029]/g).length - 1
  return).on('end', ->
    # Me logeo con las credenciales
    request.post login_url, { json: loginCredentials }, (error, response, body) ->
      assert.ifError error
      assert.equal response.statusCode, 200 # Si todo salio bien
      token = body.token # Guardo el bearer token que se me devolvio

      # Creo el task definido anteriormente
      request.post(tasks_url, {json: newTask}, (error, response, task) ->
        assert.ifError error
        assert.equal response.statusCode, 200 # Si todo salio bien

        createdTask = task # Guardo el task creado
        lr.resume()
      ).auth null, null, true, token
)
