// Generated by CoffeeScript 1.4.0

/*
  Contiene el código a ser ejecutado en el Web Worker. No es servido como un
  archivo estático porque se le debe agregar las funciones map o reduce del
  investigador.

  Realiza las llamadas a `map` o `reduce` teniendo en cuenta de no hacer un 
  uso *intensivo* de los recursos del cliente.

  Se comunica con `proc.js` para recibir los datos y enviarle los resultados.
*/


(function() {
  var Cola, cola, result,
    __slice = [].slice;

  result = [];

  self.log = function() {
    var msg, others;
    msg = arguments[0], others = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return console.log.apply(console, ["[Worker] " + msg].concat(__slice.call(others)));
  };

  self.error = function(msg) {
    return console.error("[Worker] " + msg);
  };

  self.emit = function(key, val) {
    self.log("emit con " + key + " " + val);
    return result.push([key, val]);
  };

  Cola = (function() {
    /*
      Realizar las llamadas a `map` o `reduce`. Se duerme `this.sleeping` ms y 
      continua trabajando.
    */

    function Cola() {
      this.i = 0;
      this._data = null;
      this._keys = null;
      this.executing = false;
      this.sleeping = true;
      this._tout = null;
      if (self.investigador_map !== void 0) {
        this.fn = self.investigador_map;
        log("El Web Worker será utilizado para *map*");
      } else if (self.investigador_reduce !== void 0) {
        this.fn = self.investigador_reduce;
        log("El Web Worker será utilizado para *reduce*");
      } else {
        error("No se encontro la funcion *map* ni *reduce*");
      }
    }

    Cola.prototype._process = function() {
      /*
          Procesa un elemento de @_data y se espera una ventana de tiempo para
          seguir ejecutando la siguiente
      */

      var _this = this;
      if (this.executing || this.sleeping) {
        return;
      }
      self.log("@_process " + this.executing + " " + this.sleeping);
      this.executing = true;
      if (this.i < this._keys.length) {
        self.log("ejecutando map con " + this._keys[this.i] + " y " + this._data[this._keys[this.i]]);
        this.fn(this._keys[this.i], this._data[this._keys[this.i]]);
        this.i++;
      } else {
        self.log("termino de procesar");
        this._sendResult();
      }
      if (!this.sleeping) {
        this._tout = setTimeout(function() {
          self.log("desde el timeout");
          return _this._process();
        }, 50);
      }
      return this.executing = false;
    };

    Cola.prototype._initData = function() {
      log("init data");
      this._keys = null;
      this._data = null;
      return this.i = 0;
    };

    Cola.prototype._sendResult = function() {
      var _result;
      this.sleep();
      _result = [];
      result.forEach(function(item) {
        return _result.push(item.slice());
      });
      self.log("_sendResult", result);
      return postMessage({
        type: "send_result",
        args: JSON.stringify(result)
      });
    };

    Cola.prototype.setData = function(data) {
      result = [];
      this.i = 0;
      this._data = data;
      return this._keys = Object.keys(data);
    };

    Cola.prototype.wake = function() {
      self.log("wake");
      if (!this.sleeping) {
        return;
      }
      this.sleeping = false;
      return this._process();
    };

    Cola.prototype.sleep = function() {
      self.log("sleep");
      clearTimeout(this._tout);
      return this.sleeping = true;
    };

    return Cola;

  })();

  cola = new Cola();

  this.onmessage = function(evnt) {
    var msg;
    msg = evnt.data;
    switch (msg.type) {
      case "start":
        if (!msg.args) {
          self.error("Datos invalidos:", msg.args);
          return;
        }
        self.log("start", msg.args);
        cola.setData(msg.args);
        return cola.wake();
      case "pause":
        self.log("pause recv");
        return cola.sleep();
      case "resume":
        self.log("resumign recv");
        return cola.wake();
    }
  };

  this.postMessage({
    type: "ready"
  });

}).call(this);
