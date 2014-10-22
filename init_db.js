/*
 * Script for initialization the Database.
 * Usage: node init_db.js <new_records>
 */
// sample object
a = {
    data: {
        0: 1,
        1: 1,
        2: 2,
        3: 3
    },
    imap: "investigador_map = function (k, v) {\r\n  log(\"inv in\");\r\n  var ms = 1000;\r\n  var started = new Date().getTime();\r\n  while((new Date().getTime() - started) < ms) {\r\n  }\r\n  emit(\"llave\", v*v);\r\n  log(\"inv in out\");\r\n};      ",
    reduce: "function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  return total;\r\n};      ",
    map_results: {
        /* slice_id => Object() */
    },
    reduce_results: {

    },
    available_slices: [0, 1],  // slices cuyos map_results no han sido reducidos
    slices: [
        {
            0: 1,
            1: 1,
            2: 2
        }, {
            3: 3
        }
    ],
    current_slice: 0,
    status: "created",
    received_count: 0,
    send_count: 0
};

// imports
var MongoClient = require('mongodb').MongoClient,
    assert = require('assert'),
    _ = require("underscore"),
    RECORDS = process.argv[2] || 10,
    url = 'mongodb://localhost:27017/tesis';

// Connect and add records
MongoClient.connect(url, function(err, conn) {
    assert.equal(null, err);
    console.log("Connected correctly to server");
    workers = conn.collection("workers");

    var arr = [];
    for(i = 0; i < RECORDS; i++)
        arr.push(_.clone(a));

    workers.insert(arr, function (err, result) {
        assert.equal(err, null);
        console.log("Inserted elements: ", result.length);
        conn.close();
    });
});
