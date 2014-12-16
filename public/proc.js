
/*
proc.coffee Es el archivo que se distribuye al cliente que ejecuta el worker.
Se encarga de pedir el *worker* y luego iterar en lo siguiente: traer datos,
ejecutar, enviar resultados.

Es el intermediador entre el Worker (hilo que se ejecuta en el cliente) y el
servidor de Tareas.

Solo se pide un Worker y luego datos.
*/

(function() {
  var DATA_URL, LOG_URL, POST_URL, Task, WORK_URL, data, get_work_interval, get_work_running, intervalId, process_response, sleep_time, slice_id, t, task_id, tiempo_de_ejecucion, toggle_pause, wait_for_new_tasks, worker_code, _Worker;

  POST_URL = "http://127.0.0.1:3000/data";

  LOG_URL = "http://127.0.0.1:3000/log";

  WORK_URL = "http://127.0.0.1:3000/work";

  DATA_URL = "http://127.0.0.1:3000/data";

  tiempo_de_ejecucion = 5000;

  sleep_time = 2500;

  task_id = null;

  slice_id = null;

  worker_code = null;

  data = null;

  get_work_interval = null;

  get_work_running = false;

  intervalId = null;

  _Worker = (function() {

    function _Worker(code, task) {
      /*
           Construye el worker y lo prepara para que empieze a ejecutarlo.
      */
      var _this = this;
      this._ready = false;
      this._pause_id = null;
      this._task = task;
      this.worker = new Worker(window.URL.createObjectURL(new Blob([code], {
        type: "text/javascript"
      })));
      this.worker.onmessage = function(evnt) {
        var msg, _recv;
        msg = evnt.data;
        switch (msg.type) {
          case "send_result":
            console.log(msg.args);
            _recv = JSON.parse(msg.args);
            console.log("Recibi un send_result con", _recv);
            return _this._task.next(_recv);
          case "ready":
            console.log("Recibi ready");
            return _this._ready = true;
          default:
            return console.log("Unhandled msg " + msg);
        }
      };
      console.log("Web worker construido.");
    }

    _Worker.prototype.feed = function(data) {
      var _this = this;
      if (!this._ready) {
        setTimeout(function() {
          return _this.feed(data);
        }, 100);
        return;
      }
      return this.worker.postMessage({
        type: "start",
        args: data
      });
    };

    _Worker.prototype.isReady = function() {
      return this._ready;
    };

    return _Worker;

  })();

  Task = (function() {

    function Task() {
      this.id = null;
      this.reducing = null;
      this._worker = null;
      this._slice = null;
      this._data = null;
      this._result = null;
    }

    Task.prototype.init = function() {
      var _this = this;
      return $.getJSON(WORK_URL).done(function(json, textStatus, jqXHR) {
        if (json.task_id === 0) {
          console.log("Nada que hacer");
          return;
        }
        try {
          console.log("init Task for " + (json.reducing ? "Reducing" : "mapping"));
          _this.id = json.task_id;
          _this.reducing = json.reducing;
          _this._worker = new _Worker(json.code, _this);
          return _this.get_data();
        } catch (err) {
          console.error(err.message);
          throw new Error("Failed to create Worker");
        }
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.error(jqXHR);
        throw new Error("Cannot grab Task");
      });
    };

    Task.prototype.get_data = function(callback) {
      var _this = this;
      if (callback == null) callback = function() {};
      return $.getJSON(DATA_URL, {
        task_id: this.id,
        reducing: this.reducing
      }).done(function(json, textStatus, jqXHR) {
        console.log("GET /data trajo", json);
        _this._prepare_data(json);
        return _this._worker.feed(_this._data);
      }).fail(function(jqXHR, textStatus, errorThrown) {
        return console.error("Cannot grab data from server");
      });
    };

    Task.prototype.next = function(data) {
      console.log("next con ", data);
      this._prepare_result(data);
      return this._send_result();
    };

    Task.prototype._prepare_data = function(json) {
      if (!this.reducing) this._slice = json.slice_id;
      this._data = json.data;
      return console.log("_prepare_data", this.id, this._slice, this._data);
    };

    Task.prototype._prepare_result = function(result) {
      /*
          Antes de enviarlo al server hay que dejar el `result` preparar para 
          aplicarle el `reduce`
      */
      var _this = this;
      console.log("pre result", result);
      this._result = {};
      return result.forEach(function(element) {
        var key, val;
        if (element.length !== 2) {
          console.error("Result mal formado en el worker", result);
          return;
        }
        val = element.pop();
        key = element.pop();
        if (!_this._result.hasOwnProperty(key)) _this._result[key] = [];
        _this._result[key].push(val);
        return console.log("pre resulting...", _this._result);
      });
    };

    Task.prototype._send_result = function() {
      var _this = this;
      console.log("sending result " + this.id + ", " + this._slice, this._result);
      return $.ajax(POST_URL, {
        data: JSON.stringify({
          task_id: this.id,
          slice_id: this._slice,
          result: this._result,
          reducing: this.reducing
        }),
        contentType: "application/json",
        dataType: "json",
        type: "post"
      }).done(function(json, textStatus, jqXHR) {
        _this._prepare_data(json);
        return _this._worker.feed(_this._data);
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.error("Cannot POST result to server " + textStatus);
        return console.error(jqXHR);
      });
    };

    return Task;

  })();

  process_response = function(json) {
    try {
      if (json.task_id === 0) {
        if (typeof worker !== "undefined" && worker !== null) worker.terminate();
        task_id = null;
        if (!get_work_running) wait_for_new_tasks();
        return;
      }
      clearInterval(get_work_interval);
      get_work_running = false;
      data = json.data;
      slice_id = json.slice_id;
      if (task_id !== json.task_id) {
        if (worker !== null) worker.terminate();
        task_id = json.task_id;
        worker_code = json.worker;
        create_worker();
      }
      return start_worker();
    } catch (err) {
      throw new Error("FATAL: " + err.message);
    }
  };

  toggle_pause = function() {
    clearInterval(intervalId);
    worker.postMessage({
      type: "pause",
      sleep_time: sleep_time
    });
    console.log("pause" + " send");
    intervalId = setInterval(toggle_pause, tiempo_de_ejecucion);
  };

  wait_for_new_tasks = function() {
    get_work_running = true;
    console.log("<a style='color:red'>Esperando nuevos trabajos...</a>");
    get_work_interval = setInterval("get_work()", 5000);
  };

  t = new Task();

  console.log("comienza proc.js");

  t.init();

}).call(this);
