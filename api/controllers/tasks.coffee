mongoose = require("mongoose")
Sandbox = require("sandbox")
Task = mongoose.model("Task")

#GET - Devuelve un task con el ID especificado
exports.findById = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).jsonp { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    res.status(200).jsonp task
    return
  return

#POST - Inserta un nuevo task en la DB
exports.addTask = (req, res) ->
  imap = "investigador_map = " + req.body.imap
  ireduce = "investigador_reduce = " + req.body.ireduce
  try
    throw new Error if req.body.imap.indexOf("importScript") >= 0 or req.body.imap.indexOf("XMLHttpRequest") >= 0
    throw new Error if req.body.ireduce.indexOf("importScript") >= 0 or req.body.ireduce.indexOf("XMLHttpRequest") >= 0
    s = new Sandbox()
    s.run imap+';'+ireduce, (output) ->
      isValid = output.result.indexOf("Error") < 0
      if not isValid
        return res.status(400).jsonp { message: "Map and/or reduce function invalid" }
      task = new Task(
        #data: req.body.data
        imap: "investigador_map = " + req.body.imap
        ireduce: "investigador_reduce = " + req.body.ireduce
        available_slices: req.body.available_slices or []
        slices: req.body.slices or []
        user: req.user._id
        enabled_to_process: false
      )
      task.save (err, task) ->
        return res.status(500).jsonp { message: err.message } if err
        res.status(200).jsonp task
        return
  catch err
    return res.status(400).jsonp { message: "Map and/or reduce function invalid" }
  return

#DELETE - Borra un task con el ID especificado
exports.deleteTask = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).jsonp { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    task.remove (err) ->
      return res.status(500).jsonp { message: err.message } if err
      res.send 200
      return
    return
  return

#POST - Agrega datos al task con el ID especificado
exports.addData = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).jsonp { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    #task.data = task.data || {}
    #for attrname of req.body.data
    #  task.data[attrname] = req.body.data[attrname]
    task.available_slices = task.available_slices.concat req.body.available_slices
    task.slices = task.slices.concat req.body.slices
    task.save (err) ->
      return res.status(500).jsonp { message: err.message } if err
      res.status(200).jsonp task
      return
    return
  return

#POST - Actualiza el task con el ID especificado para que pueda ser procesado
exports.enableToProcess = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).jsonp { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    task.enabled_to_process = true
    task.save (err) ->
      return res.status(500).jsonp { message: err.message } if err
      res.status(200).jsonp task
      return
    return
  return
