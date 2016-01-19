request = require 'request'
assert = require 'assert'

# Para que no importe que el certificado https no sea firmado
#process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

login_url = 'http://localhost:3003/login'
tasks_url = 'http://localhost:3003/api/v1/tasks'
task_results_url = 'http://localhost:3003/api/v1/task_results'

# Guarda el token que se devuelve cuando se logea con las credenciales
# correctas, luego es el que se utiliza para hacer los requests
token = null
createdTask = null
#slices_count = 0

# El task con la estructura basica, funcion map y reduce solamente
newTask =
  imap: 'function (k, v) {
    var SIEVEBITS = 17;
    var SIEVESIZE = 1<<SIEVEBITS;

    var getPrimes = function(start, end){
      var sieve = [];
      var primes = [];
      if(start <= 2 && 2 <= end){
        primes.push(2);
      }
      var oddprimes = [];
      for (var p = 3; p < 31622; p += 2) {
        var prime = true;
        for (var i = 3; i * i <= p; i += 2) {
          if (p % i == 0) {
            prime = false;
            break;
          }
        }
        if (prime) {
          oddprimes.push(p);
          if (start <= p && p <= end) {
            primes.push(p);
          }
        }
      }
      if (start < 31622) {
        start = 31622;
      }

      for (var base = start / 2; base <= end / 2; base += SIEVESIZE) {
        for(var index = 0;index<oddprimes.length;index++){
          var p = oddprimes[index];
          var offset = (2 * base + 1) % p;
          if (offset != 0) {
            if (offset & 1) {
              offset = (p - offset) >> 1;
            } else {
              offset = p - (offset >> 1);
            }
          }
          for (var j = offset; j < SIEVESIZE; j += p) {
            sieve[j] = 1;
          }
        }
        for (var i = 0; i < SIEVESIZE; i++) {
          var p = 2 * (base + i) + 1;
          if (!sieve[i] && p <= end) {
            primes.push(p);
          }
        }
      }
      return primes;
    };
    self.log("inv in");
    var primes = getPrimes(v[0],v[1]);
    self.emit("llave", primes);
    self.log("inv in out");};'
  ireduce: 'function (k, vals) {
    var primes = vals.reduce(function(a, b) {
      return a.concat(b);});
    self.emit(k, primes);};'

# Credenciales de un investigador ejemplo que esta en el seed (init_api_db.js)
loginCredentials =
  username: 'investigador'
  password: 'investigador'

global_min = 0
global_max = 1000000
range_size = 10000
slice_ranges = 10

hash = {}
min = global_min
index = 0

generate_data = ->
  loop
    if min > global_max
      break

    if (min+range_size-1) > global_max
      max = global_max
    else
      max = (min+range_size-1)

    hash[index] = [min, max]
    index++
    min += range_size

    if Object.keys(hash).length % slice_ranges == 0
      break

  send_data(hash, min > global_max)
  hash = {}

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
  #slices = get_slices(data, 100)
  #available_slices = []

  slices = [data]
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

      if enable
        enable_to_process() # Habilito para procesar
      else
        generate_data()

  ).auth null, null, true, token

# Habilito el task para que sea procesado
enable_to_process = ->
  request.post(tasks_url+'/'+createdTask._id+'/enable',
    {json: true},
    (error, response, updatedTask) ->
      assert.ifError error
      assert.equal response.statusCode, 200
  ).auth null, null, true, token

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

    generate_data()

  ).auth null, null, true, token
