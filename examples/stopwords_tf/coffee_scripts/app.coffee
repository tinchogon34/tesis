# sed -e 's/[^[:alpha:]]/ /g' anillos | tr '\n' " " |  tr -s " " | tr " " '\n'| tr 'A-Z' 'a-z' | sort | uniq -c | sort -nr | nl | head -n 50

LineByLineReader = require 'line-by-line'
fs = require 'fs'
request = require 'request'
assert = require 'assert'

# Para que no importe que el certificado https no sea firmado
#process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

login_url = 'http://localhost:3003/login'
tasks_url = 'http://localhost:3003/api/v1/tasks'
task_results_url = 'http://localhost:3003/api/v1/task_results'
file = './anillos'
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
    var removeStopWords = function(text) {
        var x;
        var y;
        var word;
        var stop_word;
        var regex_str;
        var regex;
        var cleansed_string = text.valueOf();
        var stop_words = new Array(
            "a",
            "acá",
            "ahí",
            "ajena",
            "ajeno",
            "ajenas",
            "ajenos",
            "al",
            "algo",
            "algún",
            "alguna",
            "alguno",
            "algunas",
            "algunos",
            "allá",
            "allí",
            "ambos",
            "ante",
            "antes",
            "aquel",
            "aquella",
            "aquello",
            "aquellas",
            "aquellos",
            "aquí",
            "arriba",
            "así",
            "atrás",
            "aun",
            "aunque",
            "bajo",
            "bastante",
            "bien",
            "cabe",
            "cada",
            "casi",
            "cierto",
            "cierta",
            "ciertas",
            "ciertos",
            "como",
            "con",
            "conmigo",
            "conseguimos",
            "conseguir",
            "consigo",
            "consigue",
            "consiguen",
            "consigues",
            "contigo",
            "contra",
            "cual",
            "cuales",
            "cualquier",
            "cualquiera",
            "cualquieras",
            "cuan",
            "cuando",
            "cuanto",
            "cuenta",
            "cuentas",
            "de",
            "dejar",
            "del",
            "demás",
            "demasiada",
            "demasiado",
            "demasiadas",
            "demasiados",
            "dentro",
            "desde",
            "donde",
            "dos",
            "el",
            "él",
            "ella",
            "ello",
            "ellas",
            "ellos",
            "empleáis",
            "emplean",
            "emplear",
            "empleas",
            "empleo",
            "en",
            "encima",
            "entonces",
            "entre",
            "era",
            "eras",
            "eramos",
            "eran",
            "eres",
            "es",
            "esa",
            "ese",
            "eso",
            "esas",
            "esos",
            "esta",
            "estas",
            "estaba",
            "estabas",
            "estado",
            "estáis",
            "estamos",
            "están",
            "estar",
            "este",
            "esto",
            "estos",
            "estoy",
            "etc",
            "fin",
            "fue",
            "fueron",
            "fui",
            "fuimos",
            "gueno",
            "ha",
            "había",
            "habían",
            "habías",
            "hace",
            "haces",
            "hacéis",
            "hacemos",
            "hacen",
            "hacer",
            "hacia",
            "hago",
            "hasta",
            "incluso",
            "intenta",
            "intentas",
            "intentáis",
            "intentamos",
            "intentan",
            "intentar",
            "intento",
            "ir",
            "jamás",
            "junto",
            "juntos",
            "la",
            "lo",
            "las",
            "los",
            "largo",
            "más",
            "me",
            "menos",
            "mi",
            "mis",
            "mía",
            "mías",
            "mientras",
            "mío",
            "míos",
            "misma",
            "mismo",
            "mismas",
            "mismos",
            "modo",
            "mucha",
            "muchas",
            "muchísima",
            "muchísimo",
            "muchísimas",
            "muchísimos",
            "mucho",
            "muchos",
            "muy",
            "nada",
            "ni",
            "ningún",
            "ninguna",
            "ninguno",
            "ningunas",
            "ningunos",
            "no",
            "nos",
            "nosotras",
            "nosotros",
            "nuestra",
            "nuestro",
            "nuestras",
            "nuestros",
            "nunca",
            "o",
            "os",
            "otra",
            "otro",
            "otras",
            "otros",
            "para",
            "parecer",
            "pero",
            "poca",
            "poco",
            "pocas",
            "pocos",
            "podéis",
            "podemos",
            "poder",
            "podría",
            "podrías",
            "podríais",
            "podríamos",
            "podrían",
            "por",
            "por qué",
            "porque",
            "primero",
            "puede",
            "pueden",
            "puedo",
            "pues",
            "que",
            "qué",
            "querer",
            "quién",
            "quiénes",
            "quienesquiera",
            "quienquiera",
            "quizá",
            "quizás",
            "sabe",
            "sabes",
            "saben",
            "sabéis",
            "sabemos",
            "saber",
            "se",
            "según",
            "ser",
            "si",
            "sí",
            "siempre",
            "siendo",
            "sin",
            "sino",
            "so",
            "sobre",
            "sois",
            "solamente",
            "solo",
            "sólo",
            "somos",
            "soy",
            "sr",
            "sra",
            "sres",
            "sta",
            "su",
            "sus",
            "suya",
            "suyo",
            "suyas",
            "suyos",
            "tal",
            "tales",
            "también",
            "tampoco",
            "tan",
            "tanta",
            "tanto",
            "tantas",
            "tantos",
            "te",
            "tenéis",
            "tenemos",
            "tener",
            "tengo",
            "ti",
            "tiempo",
            "tiene",
            "tienen",
            "toda",
            "todo",
            "todas",
            "todos",
            "tomar",
            "trabaja",
            "trabajo",
            "trabajáis",
            "trabajamos",
            "trabajan",
            "trabajar",
            "trabajas",
            "tras",
            "tú",
            "tu",
            "tus",
            "tuya",
            "tuyo",
            "tuyas",
            "tuyos",
            "último",
            "ultimo",
            "un",
            "una",
            "uno",
            "unas",
            "unos",
            "usa",
            "usas",
            "usáis",
            "usamos",
            "usan",
            "usar",
            "uso",
            "usted",
            "ustedes",
            "va",
            "van",
            "vais",
            "valor",
            "vamos",
            "varias",
            "varios",
            "vaya",
            "verdadera",
            "vosotras",
            "vosotros",
            "voy",
            "vuestra",
            "vuestro",
            "vuestras",
            "vuestros",
            "y",
            "ya",
            "yo"
        );

        cleansed_string = cleansed_string.toLowerCase();
        cleansed_string = cleansed_string.replace(/\\n/g, " ");
        cleansed_string = cleansed_string.replace(/[^ 0-9a-z\\u00E0-\\u00FC]/g," ");
        cleansed_string = cleansed_string.replace(/\\s\\s+/g, " ");
        cleansed_string = cleansed_string.replace(/^\\s+|\\s+$/g, "");

        words = cleansed_string.split(" ");

        if(words.length == 1 && words[0] == ""){
          return "";
        }
        
        for(x=0; x < stop_words.length; x++) {
            stop_word = stop_words[x];
            regex = new RegExp("(\\\\s+"+stop_word+"\\\\s+|^"+stop_word+"\\\\s+|\\\\s+"+stop_word+"$)","ig");
            cleansed_string = cleansed_string.replace(regex, " ");
        }

        cleansed_string = cleansed_string.replace(/\\s\\s+/g, " ");
        cleansed_string = cleansed_string.replace(/^\\s+|\\s+$/g, "");
        
        return cleansed_string;
    };
    var count = function(arr){
      return arr.reduce(function(m,e){
        m[e] = (+m[e]||0)+1;
        return m;
        },{});
    };
    self.log("inv in");
    words = removeStopWords(v).split(" ");
    countRes = count(words);
    for(k in countRes){
      self.emit(k,countRes[k]);
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
  slices = get_slices(data, 500)
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
  if (index+1) == (numLines+1)
    if Object.keys(hash).length > 0
      send_data hash, true
    else
      enable_to_process()
  else if (index+1) % 500 == 0  # Si ya lei 500 lineas...
    lr.pause() # Pauso la lectura del archivo
    send_data hash
    hash = {} # Limpio el hash para los proximos 500
  index++

fs.createReadStream(file).on('data', (chunk) ->
  i = -1;
  while (i = chunk.indexOf(10, i + 1)) > -1
    numLines++
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
