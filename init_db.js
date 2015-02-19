"use strict";
/*
 * Script for initialization the Database.
 * USAGE: node init_db.js [OPTION1] [OPTION2]... arg1 arg2...
 * The following options are supported:
 *   -r, --records <ARG1>  New Records Quantity
 *   -t, --type <ARG1>     Object Type
 *   -c, --clean           Clean DB
*/

// Manejo de argumentos
var stdio = require('stdio');
var options = stdio.getopt({
    'records': {key: 'r', description: 'New Records Quantity', args: 1},
    'type': {key: 't', description: 'Object Type', args: 1},
    'clean': {key: "c", description: "Clean DB"}
});

/* Funciones map y result de ejemplo */
var MAP = "investigador_map = function (k, v) {\r\n  self.log(\"inv in\"); self.emit(\"llave\", v*v);\r\n  self.log(\"inv in out\");\r\n};";
var REDUCE = "investigador_reduce = function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  self.emit(k, total);\r\n};";

// clien: ireduce = function (k, vals) {var total = vals.reduce(function(a, b) {return parseInt(a) + parseInt(b);});  return total;};

// sample object
var initial_object = {
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
    ],
    enabled_to_process: true
};

var mapped_object = {
    available_slices: [0,  1],
    data: {"0": 1, "1": 1, "2": 2, "3": 3 },
    imap: MAP,
    ireduce: REDUCE,
    map_results: {
        "0" : [
            {llave: [1, 1, 4]}, {llave: [1, 1, 4]}, {llave: [1, 1, 4]}, {llave: [1, 1, 4]},
            {llave: [1, 1, 4]}
        ], 
        "1" : [
            {llave: [9]}, {llave: [9]}, {llave: [9]}, {llave: [9]}, {llave: [9]}
        ]
    },
    reduce_data: {},
    reduce_results: {},
    result: {},
    slices: [{"0": 1, "1": 1, "2": 2 }, {"3": 3 }],
    enabled_to_process: true
};

/* Objecto ya reducido. Listo para ser procesado y finalizado */
var reduced_object = {
    available_slices: [],
    data: {"0": 1, "1": 1, "2": 2, "3": 3 },
    imap: MAP,
    ireduce: REDUCE,
    map_results: {},
    reduce_data: {
        "llave" : [
            1,
            1,
            4,
            9
        ]
    },
    reduce_results: {
        "llave" : [
            [15], [15], [15], [15], [15], [15]
        ]
    },
    result: {},
    slices: [{"0": 1, "1": 1, "2": 2 }, {"3": 3 }],
    enabled_to_process: true
};

// imports
var MongoClient = require('mongodb').MongoClient,
    assert = require('assert'),
    _ = require("underscore"),
    RECORDS = options.records || 10,
    url = 'mongodb://localhost:27017/tesis',
    obj = null;

switch(options.type) {
    case "mapped":
        obj = mapped_object;
        break;
    case "reduced":
        obj = reduced_object;
        break;
    default:
    obj = initial_object;
}

// Connect and add records
MongoClient.connect(url, function(err, conn) {
    assert.equal(null, err);
    console.log("Connected correctly to server");
    var workers = conn.collection("workers"),
        arr = [];
    if (options.clean) {
      workers.remove({}, function(err, result) {
        assert.equal(err, null);
        console.log("DB Cleaned");
      });
    }
    for(var i = 0; i < RECORDS; i++)
        arr.push(_.clone(obj));

    workers.insert(arr, function (err, result) {
        assert.equal(err, null);
        console.log("Inserted elements: ", result.length);
        conn.close();
    });
});