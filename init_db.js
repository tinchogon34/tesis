(function() {
  var MAP, MongoClient, RECORDS, REDUCE, assert, initial_object, mapped_object, obj, options, reduced_object, stdio, url, _;

  stdio = require("stdio");

  options = stdio.getopt({
    records: {
      key: "r",
      description: "New Records Quantity",
      args: 1
    },
    type: {
      key: "t",
      description: "Object Type",
      args: 1
    }
  });

  MAP = "investigador_map = function (k, v) {\r\n  self.log(\"inv in\");\r\n  var ms = 1000;\r\n  var started = new Date().getTime();\r\n  while((new Date().getTime() - started) < ms) {\r\n  }\r\n  self.emit(\"llave\", v*v);\r\n  self.log(\"inv in out\");\r\n};";

  REDUCE = "investigador_reduce = function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  self.emit(k, total);\r\n};";

  initial_object = {
    data: {
      0: 1,
      1: 1,
      2: 2,
      3: 3
    },
    imap: MAP,
    ireduce: REDUCE,
    map_results: {},
    reduce_data: {},
    reduce_results: {},
    result: {},
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
    available_slices: [0, 1],
    data: {
      0: 1,
      1: 1,
      2: 2,
      3: 3
    },
    imap: MAP,
    ireduce: REDUCE,
    map_results: {
      0: [
        {
          llave: [1, 1, 4]
        }, {
          llave: [1, 1, 4]
        }, {
          llave: [1, 1, 4]
        }, {
          llave: [1, 1, 4]
        }, {
          llave: [1, 1, 4]
        }
      ],
      1: [
        {
          llave: [9]
        }, {
          llave: [9]
        }, {
          llave: [9]
        }, {
          llave: [9]
        }, {
          llave: [9]
        }
      ]
    },
    reduce_data: {},
    reduce_results: {},
    result: {},
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

  reduced_object = {
    available_slices: [],
    data: {
      0: 1,
      1: 1,
      2: 2,
      3: 3
    },
    imap: MAP,
    ireduce: REDUCE,
    map_results: {},
    reduce_data: {
      llave: [1, 1, 4, 9]
    },
    reduce_results: {
      llave: [[15], [15], [15], [15], [15], [15]]
    },
    result: {},
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

  MongoClient = require("mongodb").MongoClient;

  assert = require("assert");

  _ = require("underscore");

  RECORDS = options.records || 10;

  url = "mongodb://localhost:27017/tesis";

  obj = null;

  switch (options.type) {
    case "mapped":
      obj = mapped_object;
      break;
    case "reduced":
      obj = reduced_object;
      break;
    default:
      obj = initial_object;
  }

  MongoClient.connect(url, function(err, conn) {
    var arr, i, workers;
    assert.equal(null, err);
    console.log("Connected correctly to server");
    workers = conn.collection("workers");
    arr = [];
    i = 0;
    while (i < RECORDS) {
      arr.push(_.clone(obj));
      i++;
    }
    workers.insert(arr, function(err, result) {
      assert.equal(err, null);
      console.log("Inserted elements: ", result.length);
      conn.close();
    });
  });

}).call(this);
