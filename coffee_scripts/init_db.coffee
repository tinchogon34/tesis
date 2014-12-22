#
# * Script for initialization the Database.
# * USAGE: node init_db.js [OPTION1] [OPTION2]... arg1 arg2...
# * The following options are supported:
# *   -r, --records <ARG1>  New Records Quantity
# *   -t, --type <ARG1>     Object Type
# *   -c, --clean           Clean DB


# Manejo de argumentos
stdio = require("stdio")
options = stdio.getopt(
  records:
    key: "r"
    description: "New Records Quantity"
    args: 1

  type:
    key: "t"
    description: "Object Type"
    args: 1

  clean:
    key: "c"
    description: "Clean DB"
)

# Funciones map y result de ejemplo 
MAP = "investigador_map = function (k, v) {\r\n  self.log(\"inv in\");\r\n  var ms = 1000;\r\n  var started = new Date().getTime();\r\n  while((new Date().getTime() - started) < ms) {\r\n  }\r\n  self.emit(\"llave\", v*v);\r\n  self.log(\"inv in out\");\r\n};"
REDUCE = "investigador_reduce = function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  self.emit(k, total);\r\n};"

# clien: ireduce = function (k, vals) {var total = vals.reduce(function(a, b) {return parseInt(a) + parseInt(b);});  return total;};

# sample object
initial_object =  
  # Datos originales provistos por el investigador.
  data:
    0: 1
    1: 1
    2: 2
    3: 3

  imap: MAP
  ireduce: REDUCE
  
  # Resultados de map
  map_results: {
    # slice_id => Object() 
  }
  
  # Resultados de Map procesados para ser utilizados por el reduce
  reduce_data: {
    # key => [vals] 
  }  
    
  # Resultados del reduce. Resultado final?
  reduce_results: {}
  result: {
    # resultado final  
  }
  
  
  
  # slices cuyos map_results no han sido reducidos
  available_slices: [
    0
    1
  ]
  slices: [
    {
      0: 1
      1: 1
      2: 2
    }
    {
      3: 3
    }
  ]

mapped_object =
  available_slices: [
    0
    1
  ]
  data:
    0: 1
    1: 1
    2: 2
    3: 3

  imap: MAP
  ireduce: REDUCE
  map_results:
    0: [
      {
        llave: [
          1
          1
          4
        ]
      }
      {
        llave: [
          1
          1
          4
        ]
      }
      {
        llave: [
          1
          1
          4
        ]
      }
      {
        llave: [
          1
          1
          4
        ]
      }
      {
        llave: [
          1
          1
          4
        ]
      }
    ]
    1: [
      {
        llave: [9]
      }
      {
        llave: [9]
      }
      {
        llave: [9]
      }
      {
        llave: [9]
      }
      {
        llave: [9]
      }
    ]

  reduce_data: {}
  reduce_results: {}
  result: {}
  slices: [
    {
      0: 1
      1: 1
      2: 2
    }
    {
      3: 3
    }
  ]

# Objecto ya reducido. Listo para ser procesado y finalizado 
reduced_object =
  available_slices: []
  data:
    0: 1
    1: 1
    2: 2
    3: 3

  imap: MAP
  ireduce: REDUCE
  map_results: {}
  reduce_data:
    llave: [
      1
      1
      4
      9
    ]

  reduce_results:
    llave: [
      [15]
      [15]
      [15]
      [15]
      [15]
      [15]
    ]

  result: {}
  slices: [
    {
      0: 1
      1: 1
      2: 2
    }
    {
      3: 3
    }
  ]


# imports
MongoClient = require("mongodb").MongoClient
assert = require("assert")
_ = require("underscore")
RECORDS = options.records or 10
url = "mongodb://localhost:27017/tesis"
obj = null
switch options.type
  when "mapped"
    obj = mapped_object
  when "reduced"
    obj = reduced_object
  else
    obj = initial_object

# Connect and add records
MongoClient.connect url, (err, conn) ->
  assert.equal null, err
  console.log "Connected correctly to server"
  workers = conn.collection("workers")
  if options.clean
    workers.remove {}, (err, result) ->
      assert.equal err, null
      console.log "DB Cleaned"
      return
  arr = []
  i = 0

  while i < RECORDS
    arr.push _.clone(obj)
    i++
  workers.insert arr, (err, result) ->
    assert.equal err, null
    console.log "Inserted elements: ", result.length
    conn.close()
    return

  return