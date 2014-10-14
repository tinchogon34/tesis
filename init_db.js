/*
 * Script for initialization the Database.
 */
// sample object
a = {
	"data" : {
		"0" : 1,
		"1" : 1,
		"2" : 2,
		"3" : 3
	},
	"worker_code" : "investigador_map = function (k, v) {\r\n  log(\"inv in\");\r\n  var ms = 1000;\r\n  var started = new Date().getTime();\r\n  while((new Date().getTime() - started) < ms) {\r\n  }\r\n  emit(\"llave\", v*v);\r\n  log(\"inv in out\");\r\n};      ",
	"reduce" : "function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  return total;\r\n};      ",
	"map_results" : {
		
	},
	"reduce_results" : {
		
	},
	"slices" : {
		"0" : {
			"status" : "created",
			"data" : {
				"0" : 1,
				"1" : 1,
				"2" : 2
			}
		},
		"1" : {
			"status" : "created",
			"data" : {
				"3" : 3
			}
		}
	},
	"current_slice" : 0,
	"status" : "created",
	"received_count" : 0,
	"send_count" : 0
};

// imports
var MongoClient = require('mongodb').MongoClient,
	assert = require('assert'),
	_ = require("underscore");

// Use connect method to connect to the Server
var url = 'mongodb://localhost:27017/tesis';
MongoClient.connect(url, function(err, conn) {
	assert.equal(null, err);
	console.log("Connected correctly to server");
	workers = conn.collection("workers");

	var arr = [];
	for(i = 0; i < 10; i++)
		arr.push(_.clone(a))

	workers.insert(arr, function (err, result) {
		assert.equal(err, null);
		console.log("Inserted elements: ", result.length);
		conn.close();
	});
});


/*
form
{"0": 1,"1": 1,"2": 2,"3": 3}

function (k, v) {
  log("inv in");
  var ms = 1000;
  var started = new Date().getTime();
  while((new Date().getTime() - started) < ms) {}
  emit("llave", v*v);
  log("inv in out");
};   

function (k, vals) {
  var total = vals.reduce(function(a, b) {
    return parseInt(a) + parseInt(b);
  });
  return total;
};
*/