/*
 * Script for initialization the Database.
 * Usage: node init_db.js <new_records>
 */
/* Funciones map y result de ejemplo */

MAP = "investigador_map = function (k, v) {\r\n  self.log(\"inv in\");\r\n  var ms = 1000;\r\n  var started = new Date().getTime();\r\n  while((new Date().getTime() - started) < ms) {\r\n  }\r\n  self.emit(\"llave\", v*v);\r\n  self.log(\"inv in out\");\r\n};";
REDUCE = "investigador_reduce = function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  self.emit(k, total);\r\n};";
// clien: ireduce = function (k, vals) {var total = vals.reduce(function(a, b) {return parseInt(a) + parseInt(b);});  return total;};

// sample object
initial_object = {
    // Datos originales provistos por el investigador.
    data: {
        0: 1,
        1: 1,
        2: 2,
        3: 3
    },
    imap: MAP,
    ireduce: REDUCE,

    // Resultados de map
    map_results: {
        /* slice_id => Object() */
    },

    // Resultados de Map procesados para ser utilizados por el reduce
    reduce_data: {
        /* key => [vals] */
    },
    
    // Resultados del reduce. Resultado final?
    reduce_results: {

    },

    // slices cuyos map_results no han sido reducidos
    available_slices: [0, 1],
    slices: [
        {
            0: 1,
            1: 1,
            2: 2
        }, {
            3: 3
        }
    ]
};

mapped_object = {
    available_slices: [0,  1],
    data: { "0" : 1, "1" : 1, "2" : 2, "3" : 3 },
    imap: MAP,
    ireduce: REDUCE,
    map_results: { "0" : [     {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] },  {   "llave" : [     1,  1,  4 ] } ], "1" : [    {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] }, {    "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] }, {    "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] }, {    "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] },  {   "llave" : [     9 ] } ] },
    reduce_data: {},
    reduce_results: {},
    slices: [  {  "0" : 1,  "1" : 1,  "2" : 2 },  {  "3" : 3 } ] 
}

// imports
var MongoClient = require('mongodb').MongoClient,
    assert = require('assert'),
    _ = require("underscore"),
    RECORDS = process.argv[2] || 10,
    obj = process.argv[3] === "mapped"? mapped_object: initial_object;
    url = 'mongodb://localhost:27017/tesis';

// Connect and add records
MongoClient.connect(url, function(err, conn) {
    assert.equal(null, err);
    console.log("Connected correctly to server");
    workers = conn.collection("workers");

    var arr = [];
    for(i = 0; i < RECORDS; i++)
        arr.push(_.clone(obj));

    workers.insert(arr, function (err, result) {
        assert.equal(err, null);
        console.log("Inserted elements: ", result.length);
        conn.close();
    });
});
