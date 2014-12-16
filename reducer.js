(function() {
  var DB_URL, MAPPED, MongoClient, REDUCING, assert, mode, process, reducing, sleep, _;

  MongoClient = require('mongodb').MongoClient;

  sleep = require('sleep');

  assert = require('assert');

  _ = require("underscore");

  DB_URL = 'mongodb://127.0.0.1:27017/tesis';

  MAPPED = "this.available_slices.length > 1";

  REDUCING = "this.available_slices.length === 0 && this.reduce_results !== {}";

  mode = function(array) {
    /*
      Devuelve la moda de un arreglo de cadenas.
    */
    var el, maxCount, maxEl, modeMap, _arr, _i, _len;
    if (array.length === 0) return null;
    _arr = [];
    array.forEach(function(item) {
      return _arr.push(JSON.stringify(item));
    });
    array = _arr;
    modeMap = {};
    maxEl = array[0];
    maxCount = 1;
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      el = array[_i];
      if (modeMap[el] === void 0) {
        modeMap[el] = 1;
      } else {
        modeMap[el]++;
      }
      if (modeMap[el] > maxCount) {
        maxEl = el;
        maxCount = modeMap[el];
      }
    }
    return JSON.parse(maxEl);
  };

  process = function(task, coll) {
    /*
      Prepara task para ser reducido.
    
      Debe buscar la moda de los resultados de map para cada slice, el cual se lo
      considera correcto. Luego une los resultados de los slices y los agrega en
      `reduce_data`. Finalmente saca de `available_slices` los ya procesado.
    */
    var k, key, reduce_data, res, results, sid, vals, _data, _i, _len, _real_result, _reduce_data, _unavailable_sids, _update, _used_maps_results;
    results = task.map_results;
    _real_result = {};
    for (sid in results) {
      res = results[sid];
      if (res.length >= 5) _real_result[sid] = mode(res);
    }
    _unavailable_sids = (function() {
      var _i, _len, _ref, _results;
      _ref = Object.keys(_real_result);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        sid = _ref[_i];
        _results.push(parseInt(sid));
      }
      return _results;
    })();
    _data = {};
    for (sid in _real_result) {
      reduce_data = _real_result[sid];
      for (key in reduce_data) {
        vals = reduce_data[key];
        if (!_data.hasOwnProperty(key)) _data[key] = [];
        _data[key].push.apply(_data[key], vals);
      }
    }
    _reduce_data = {};
    for (k in _data) {
      vals = _data[k];
      _reduce_data["reduce_data." + k] = {
        $each: vals
      };
    }
    _used_maps_results = {};
    for (_i = 0, _len = _unavailable_sids.length; _i < _len; _i++) {
      sid = _unavailable_sids[_i];
      _used_maps_results["map_results." + sid] = "";
    }
    _update = {
      $unset: _used_maps_results,
      $push: _reduce_data,
      $pull: {
        available_slices: {
          $in: _unavailable_sids
        }
      }
    };
    return coll.update({
      _id: task._id
    }, _update, function(err, count, status) {
      if (err !== null) {
        return console.error("ERROR: " + err);
      } else {
        if (count !== 1) {
          console.error("WARNING: It should update 1 record but " + count + " where          updated");
        }
        return console.log("INFO: " + status);
      }
    });
  };

  reducing = function(task, coll) {
    /*
      Busca en los resultados de *reduce* los correctos. Ademas, Verifica si se 
      termino la tarea. De ser asi, debe ser movido a otra colleccion.
    */
    var key, res, results, _i, _len, _real_result, _ref, _ref2, _unset, _update;
    results = {};
    _real_result = {};
    _unset = {};
    _ref = task.reduce_results;
    for (key in _ref) {
      res = _ref[key];
      if (res.length >= 5) {
        _real_result[key] = mode(res);
        results["results." + key] = _real_result[key];
      }
    }
    _ref2 = Object.keys(_real_result);
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      key = _ref2[_i];
      _unset["reduce_results." + key] = "";
    }
    _update = {
      $unset: _unset,
      $set: results
    };
    if (_.difference(Object.keys(task.reduce_results), Object.keys(_real_result)).length === 0) {
      console.log("termino");
    }
    return coll.update({
      _id: task._id
    }, _update, function(err, count, status) {
      if (err !== null) return console.error("ERROR: " + err);
      return console.log("INFO: Termino de reducir " + status);
    });
  };

  MongoClient.connect(DB_URL, function(err, conn) {
    var coll;
    if (err !== null) return console.log(err);
    console.log("Connected to DB.");
    coll = conn.collection("workers");
    coll.find({
      $where: MAPPED
    }).nextObject(function(err, task) {
      if (err !== null) return console.log(err);
      if (task === null) return;
      console.log("Ha terminado de la fase *map* el task_id: ", task._id);
      return process(task, coll);
    });
    return coll.find({
      $where: REDUCING
    }).nextObject(function(err, task) {
      if (err !== null) return console.log(err);
      if (task === null) return;
      console.log("Esta siendo reducida el task_id: ", task._id);
      return reducing(task, coll);
    });
  });

}).call(this);
