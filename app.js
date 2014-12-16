(function() {
  var MongoClient, ObjectID, WORKER_JS, allowCrossDomain, app, assert, bodyParser, compression, db, db_url, express, fs, getWork, get_slices, morgan, sendData, serveStatic, shuffle, trusted_hosts, _;

  express = require('express.io');

  bodyParser = require('body-parser');

  compression = require('compression');

  morgan = require('morgan');

  serveStatic = require('serve-static');

  assert = require('assert');

  fs = require('fs');

  MongoClient = require('mongodb').MongoClient;

  ObjectID = require('mongodb').ObjectID;

  _ = require("underscore");

  app = express();

  trusted_hosts = ['*'];

  db_url = 'mongodb://127.0.0.1:27017/tesis';

  WORKER_JS = fs.readFileSync('worker.js', 'utf8');

  db = null;

  MongoClient.connect(db_url, function(err, connection) {
    assert.ifError(err);
    assert.ok(connection);
    return db = connection;
  });

  allowCrossDomain = function(req, res, next) {
    res.header('Access-Control-Allow-Origin', trusted_hosts);
    res.header('Access-Control-Allow-Methods', 'GET, POST');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    return next();
  };

  app.use(serveStatic(__dirname + '/public'));

  app.use(morgan('default'));

  app.use(bodyParser.json());

  app.use(bodyParser.urlencoded({
    extended: true
  }));

  app.use(compression());

  app.use(allowCrossDomain);

  shuffle = function(h) {
    var i, j, keys, randomKeyI, randomKeyJ, size, _ref, _ref2;
    keys = Object.keys(h);
    size = keys.length;
    for (i = 0, _ref = size - 1; 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
      randomKeyI = keys[i];
      j = Math.floor(Math.random() * size);
      randomKeyJ = keys[j];
      _ref2 = [h[randomKeyJ], h[randomKeyI]], h[randomKeyI] = _ref2[0], h[randomKeyJ] = _ref2[1];
    }
    return h;
  };

  get_slices = function(data, size) {
    var contador, hash, i, key, keysLength, value, _ref;
    hash = {};
    keysLength = Object.keys(data).length;
    for (i = 0, _ref = Math.floor(keysLength % size); 0 <= _ref ? i <= _ref : i >= _ref; 0 <= _ref ? i++ : i--) {
      hash[i] = {
        "status": "created",
        "data": {}
      };
    }
    i = 0;
    contador = 0;
    for (key in data) {
      value = data[key];
      hash[i].data[key] = value;
      contador++;
      if (contador % size === 0) i++;
    }
    return shuffle(hash);
  };

  getWork = function(task_id, callback) {
    var coll;
    if (task_id == null) task_id = null;
    /*
      Busca en la DB un `task` con _id igual a `slice_id ` o si este es null,
      lo busca aleatoriamente. Luego llama a la funcion callback con task como 
      argumento
    */
    coll = db.collection('workers');
    if (task_id !== null) {
      coll.findOne({
        _id: new ObjectID(task_id)
      }, function(err, item) {
        if (err) {
          console.error(err);
          return;
        }
        return callback(item);
      });
      return;
    }
    console.log("elijiendo una task aleatoriamente");
    /*
      Elije uno aleatoriamente.
      Si hay un Task listo para reducir tiene mayor prioridad.
    */
    return coll.find({
      $where: "this.available_slices.length == 0"
    }).count(function(err, _n) {
      console.log("hay para reducir " + _n);
      if (_n !== 0) {
        return coll.find({
          $where: "this.available_slices.length == 0"
        }).limit(1).skip(_.random(_n - 1)).nextObject(function(err, item) {
          if (err) {
            console.error(err);
            return;
          }
          return callback(item, true);
        });
      } else {
        return coll.find({
          $where: "this.available_slices.length > 1"
        }).count(function(err, _n) {
          return coll.find({
            $where: "this.available_slices.length > 1"
          }).limit(1).skip(_.random(_n - 1)).nextObject(function(err, item) {
            if (err) {
              console.error(err);
              return;
            }
            return callback(item, false);
          });
        });
      }
    });
  };

  sendData = function(work, reducing, res) {
    /*
      Busca en el work datos y los envia al cliente.
    */
    var data, _data, _slice_id;
    if (work === null) return res.status(400).send("Work not found");
    if (reducing) {
      _data = _.sample(_.pairs(work.reduce_data));
      data = {};
      data[_data[0]] = _data[1];
      return res.json({
        data: data
      });
    } else {
      _slice_id = _.sample(work.available_slices);
      return res.json({
        slice_id: _slice_id,
        data: work.slices[_slice_id]
      });
    }
  };

  /*
  Define HTTP method
  */

  app.get('/work', function(req, res) {
    return getWork(null, function(work, reducing) {
      if (work === null) {
        return res.json({
          task_id: 0
        });
      }
      if (reducing) {
        return res.json({
          task_id: work._id,
          reducing: reducing,
          code: work.ireduce + WORKER_JS
        });
      } else {
        return res.json({
          task_id: work._id,
          reducing: reducing,
          code: work.imap + WORKER_JS
        });
      }
    });
  });

  app.get('/data', function(req, res) {
    /*
       Devuelve en JSON datos para ser procesados en el cliente.
    */
    var reducing, task_id;
    if (void 0 === req.param("reducing", req.param("task_id"))) {
      return res.status(400).send("Missing argument(s)");
    }
    task_id = req.param("task_id");
    reducing = req.param("reducing") === "true";
    console.log("GET /data con " + reducing + " task_id=" + task_id);
    return getWork(task_id, function(work) {
      console.log("work fetched! reducing? " + reducing);
      return sendData(work, reducing, res);
    });
  });

  app.post('/data', function(req, res) {
    /* 
    Almacena los resultados de los datos ya procesados. Devuelve mas datos para
    que el cliente siga con la siguiente tarea.
    */
    var coll, key, reducing, slice_id, task_id, update, value, _ref;
    console.log("Posting to /data", req.param("result"));
    if (void 0 === req.body.task_id || void 0 === req.body.result || void 0 === req.body.reducing) {
      return res.status(400).send("Missing argument(s)");
    }
    reducing = req.body.reducing;
    task_id = req.param("task_id");
    if (reducing) {
      console.log("Store results ", req.param("result"));
      update = {};
      _ref = req.param("result");
      for (key in _ref) {
        value = _ref[key];
        update["reduce_results." + key] = value;
      }
    } else {
      if (req.body.slice_id === void 0) {
        return res.status(400).send("Missing argument(s)");
      }
      slice_id = req.param("slice_id");
      update = {};
      update["map_results." + slice_id] = req.param("result");
    }
    coll = db.collection('workers');
    coll.update({
      _id: new ObjectID(task_id)
    }, {
      $push: update
    }, function(err) {
      if (err !== null) return console.error("Failed to update:", err);
    });
    return getWork(task_id, function(work) {
      return sendData(work, reducing, res);
    });
  });

  app.post('/form', function(req, res) {
    var data, doc, map, reduce;
    console.log(req.body);
    data = JSON.parse(req.body.data.replace(/'/g, "\""));
    map = req.body.map;
    reduce = req.body.reduce;
    doc = {
      data: data,
      worker_code: "investigador_map = " + map,
      reduce: reduce,
      map_results: {},
      reduce_results: {},
      slices: get_slices(data, 3),
      current_slice: -1,
      status: 'created',
      received_count: 0,
      send_count: 0
    };
    return db.collection('workers', function(err, collection) {
      assert.ifError(err);
      collection.insert(doc, {
        w: 1
      }, function(err, result) {
        assert.ifError(err);
        return assert.ok(result);
      });
      return res.send("Thx for submitting a job");
    });
  });

  console.log("listening to localhost:3000");

  app.listen('3000');

}).call(this);
