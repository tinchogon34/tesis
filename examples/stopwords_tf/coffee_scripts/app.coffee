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
    var removeStopWords = function(text) {
        var x;
        var y;
        var word;
        var stop_word;
        var regex_str;
        var regex;
        var cleansed_string = text.valueOf();
        var stop_words = new Array(
            "a\'s",
            "able",
            "about",
            "above",
            "according",
            "accordingly",
            "across",
            "actually",
            "after",
            "afterwards",
            "again",
            "against",
            "ain\'t",
            "all",
            "allow",
            "allows",
            "almost",
            "alone",
            "along",
            "already",
            "also",
            "although",
            "always",
            "am",
            "among",
            "amongst",
            "an",
            "and",
            "another",
            "any",
            "anybody",
            "anyhow",
            "anyone",
            "anything",
            "anyway",
            "anyways",
            "anywhere",
            "apart",
            "appear",
            "appreciate",
            "appropriate",
            "are",
            "aren\'t",
            "around",
            "as",
            "aside",
            "ask",
            "asking",
            "associated",
            "at",
            "available",
            "away",
            "awfully",
            "be",
            "became",
            "because",
            "become",
            "becomes",
            "becoming",
            "been",
            "before",
            "beforehand",
            "behind",
            "being",
            "believe",
            "below",
            "beside",
            "besides",
            "best",
            "better",
            "between",
            "beyond",
            "both",
            "brief",
            "but",
            "by",
            "c\'mon",
            "c\'s",
            "came",
            "can",
            "can\'t",
            "cannot",
            "cant",
            "cause",
            "causes",
            "certain",
            "certainly",
            "changes",
            "clearly",
            "co",
            "com",
            "come",
            "comes",
            "concerning",
            "consequently",
            "consider",
            "considering",
            "contain",
            "containing",
            "contains",
            "corresponding",
            "could",
            "couldn\'t",
            "course",
            "currently",
            "definitely",
            "described",
            "despite",
            "did",
            "didn\'t",
            "different",
            "do",
            "does",
            "doesn\'t",
            "doing",
            "don\'t",
            "done",
            "down",
            "downwards",
            "during",
            "each",
            "edu",
            "eg",
            "eight",
            "either",
            "else",
            "elsewhere",
            "enough",
            "entirely",
            "especially",
            "et",
            "etc",
            "even",
            "ever",
            "every",
            "everybody",
            "everyone",
            "everything",
            "everywhere",
            "ex",
            "exactly",
            "example",
            "except",
            "far",
            "few",
            "fifth",
            "first",
            "five",
            "followed",
            "following",
            "follows",
            "for",
            "former",
            "formerly",
            "forth",
            "four",
            "from",
            "further",
            "furthermore",
            "get",
            "gets",
            "getting",
            "given",
            "gives",
            "go",
            "goes",
            "going",
            "gone",
            "got",
            "gotten",
            "greetings",
            "had",
            "hadn\'t",
            "happens",
            "hardly",
            "has",
            "hasn\'t",
            "have",
            "haven\'t",
            "having",
            "he",
            "he\'s",
            "hello",
            "help",
            "hence",
            "her",
            "here",
            "here\'s",
            "hereafter",
            "hereby",
            "herein",
            "hereupon",
            "hers",
            "herself",
            "hi",
            "him",
            "himself",
            "his",
            "hither",
            "hopefully",
            "how",
            "howbeit",
            "however",
            "i\'d",
            "i\'ll",
            "i\'m",
            "i\'ve",
            "ie",
            "if",
            "ignored",
            "immediate",
            "in",
            "inasmuch",
            "inc",
            "indeed",
            "indicate",
            "indicated",
            "indicates",
            "inner",
            "insofar",
            "instead",
            "into",
            "inward",
            "is",
            "isn\'t",
            "it",
            "it\'d",
            "it\'ll",
            "it\'s",
            "its",
            "itself",
            "just",
            "keep",
            "keeps",
            "kept",
            "know",
            "knows",
            "known",
            "last",
            "lately",
            "later",
            "latter",
            "latterly",
            "least",
            "less",
            "lest",
            "let",
            "let\'s",
            "like",
            "liked",
            "likely",
            "little",
            "look",
            "looking",
            "looks",
            "ltd",
            "mainly",
            "many",
            "may",
            "maybe",
            "me",
            "mean",
            "meanwhile",
            "merely",
            "might",
            "more",
            "moreover",
            "most",
            "mostly",
            "much",
            "must",
            "my",
            "myself",
            "name",
            "namely",
            "nd",
            "near",
            "nearly",
            "necessary",
            "need",
            "needs",
            "neither",
            "never",
            "nevertheless",
            "new",
            "next",
            "nine",
            "no",
            "nobody",
            "non",
            "none",
            "noone",
            "nor",
            "normally",
            "not",
            "nothing",
            "novel",
            "now",
            "nowhere",
            "obviously",
            "of",
            "off",
            "often",
            "oh",
            "ok",
            "okay",
            "old",
            "on",
            "once",
            "one",
            "ones",
            "only",
            "onto",
            "or",
            "other",
            "others",
            "otherwise",
            "ought",
            "our",
            "ours",
            "ourselves",
            "out",
            "outside",
            "over",
            "overall",
            "own",
            "particular",
            "particularly",
            "per",
            "perhaps",
            "placed",
            "please",
            "plus",
            "possible",
            "presumably",
            "probably",
            "provides",
            "que",
            "quite",
            "qv",
            "rather",
            "rd",
            "re",
            "really",
            "reasonably",
            "regarding",
            "regardless",
            "regards",
            "relatively",
            "respectively",
            "right",
            "said",
            "same",
            "saw",
            "say",
            "saying",
            "says",
            "second",
            "secondly",
            "see",
            "seeing",
            "seem",
            "seemed",
            "seeming",
            "seems",
            "seen",
            "self",
            "selves",
            "sensible",
            "sent",
            "serious",
            "seriously",
            "seven",
            "several",
            "shall",
            "she",
            "should",
            "shouldn\'t",
            "since",
            "six",
            "so",
            "some",
            "somebody",
            "somehow",
            "someone",
            "something",
            "sometime",
            "sometimes",
            "somewhat",
            "somewhere",
            "soon",
            "sorry",
            "specified",
            "specify",
            "specifying",
            "still",
            "sub",
            "such",
            "sup",
            "sure",
            "t\'s",
            "take",
            "taken",
            "tell",
            "tends",
            "th",
            "than",
            "thank",
            "thanks",
            "thanx",
            "that",
            "that\'s",
            "thats",
            "the",
            "their",
            "theirs",
            "them",
            "themselves",
            "then",
            "thence",
            "there",
            "there\'s",
            "thereafter",
            "thereby",
            "therefore",
            "therein",
            "theres",
            "thereupon",
            "these",
            "they",
            "they\'d",
            "they\'ll",
            "they\'re",
            "they\'ve",
            "think",
            "third",
            "this",
            "thorough",
            "thoroughly",
            "those",
            "though",
            "three",
            "through",
            "throughout",
            "thru",
            "thus",
            "to",
            "together",
            "too",
            "took",
            "toward",
            "towards",
            "tried",
            "tries",
            "truly",
            "try",
            "trying",
            "twice",
            "two",
            "un",
            "under",
            "unfortunately",
            "unless",
            "unlikely",
            "until",
            "unto",
            "up",
            "upon",
            "us",
            "use",
            "used",
            "useful",
            "uses",
            "using",
            "usually",
            "value",
            "various",
            "very",
            "via",
            "viz",
            "vs",
            "want",
            "wants",
            "was",
            "wasn\'t",
            "way",
            "we",
            "we\'d",
            "we\'ll",
            "we\'re",
            "we\'ve",
            "welcome",
            "well",
            "went",
            "were",
            "weren\'t",
            "what",
            "what\'s",
            "whatever",
            "when",
            "whence",
            "whenever",
            "where",
            "where\'s",
            "whereafter",
            "whereas",
            "whereby",
            "wherein",
            "whereupon",
            "wherever",
            "whether",
            "which",
            "while",
            "whither",
            "who",
            "who\'s",
            "whoever",
            "whole",
            "whom",
            "whose",
            "why",
            "will",
            "willing",
            "wish",
            "with",
            "within",
            "without",
            "won\'t",
            "wonder",
            "would",
            "would",
            "wouldn\'t",
            "yes",
            "yet",
            "you",
            "you\'d",
            "you\'ll",
            "you\'re",
            "you\'ve",
            "your",
            "yours",
            "yourself",
            "yourselves",
            "zero"
        );

        words = cleansed_string.split(" ");

        if(words.length == 1 && words[0] == ""){
          return "";
        }
        for(x=0; x < words.length; x++) {
            word = words[x].replace(/[.,]/g,"").toLowerCase();
            for(y=0; y < stop_words.length; y++) {
                stop_word = stop_words[y];
                if(word == stop_word) {
                    regex = new RegExp("\\\\b"+stop_word+"\\\\b","ig");
                    cleansed_string = cleansed_string.replace(regex, "");
                }
            }
        }
        cleansed_string = cleansed_string.replace(/\\s\\s+/g, " ");
        cleansed_string = cleansed_string.replace(/^\\s+|\\s+$/g, "");

        return cleansed_string;
    };
    var count = function(arr){
      return arr.reduce(function(m,e){
        e = e.toLowerCase();
        m[e] = (+m[e]||0)+1;
        return m;
        },{});
    };
    self.log("inv in");
    words = removeStopWords(v.replace(/\\s\\s+/g, " ").replace(/^\\s+|\\s+$/g, "").replace(/[.,]/g,"")).split(" ");
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
  if (index+1) % 500 == 0  # Si ya lei 100 lineas...
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
