mongoose = require("mongoose")
Sandbox = require("sandbox")
Task = mongoose.model("Task")

#GET - Devuelve un task con el ID especificado
exports.findById = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).json { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).json { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    res.status(200).json task
    return
  return

#GET - Devuelve un listado de todos los task
exports.listTasks = (req, res) ->
  Task.find user: req.user._id, 'imap ireduce available_slices enabled_to_process finished', (err, tasks) ->
    return res.status(500).json { message: err.message } if err
    res.status(200).json tasks
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
        return res.status(400).json { message: "Map and/or reduce function invalid" }
      available_slices = []
      available_slices[i] = i for i in [0...req.body.slices.length]
      task = new Task(
        #data: req.body.data
        imap: "investigador_map = " + req.body.imap
        ireduce: "investigador_reduce = " + req.body.ireduce
        available_slices: available_slices
        slices: req.body.slices or []
        user: req.user._id
        enabled_to_process: false
        finished: false
      )
      task.save (err, task) ->
        return res.status(500).json { message: err.message } if err
        res.status(200).json task
        return
  catch err
    return res.status(400).json { message: "Map and/or reduce function invalid" }
  return

#DELETE - Borra un task con el ID especificado
exports.deleteTask = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).json { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).json { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    task.remove (err) ->
      return res.status(500).json { message: err.message } if err
      res.send 200
      return
    return
  return

#POST - Agrega datos al task con el ID especificado
exports.addData = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).json { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).json { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    #task.data = task.data || {}
    #for attrname of req.body.data
    #  task.data[attrname] = req.body.data[attrname]
    return res.status(422).json { message: "The task has already started"} if task.enabled_to_process
    return res.status(422).json { message: "The task has already finished"} if task.finished
    available_slices = []
    available_slices[i] = (i+task.slices.length) for i in [0...req.body.slices.length]
    task.available_slices = task.available_slices.concat available_slices
    task.slices = task.slices.concat req.body.slices
    task.save (err) ->
      return res.status(500).json { message: err.message } if err
      res.status(200).json task
      return
    return
  return

#POST - Actualiza el task con el ID especificado para que pueda ser procesado
exports.enableToProcess = (req, res) ->
  Task.findById req.params.id, (err, task) ->
    return res.status(500).json { message: err.message } if err
    return res.send 404 unless task # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).json { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task.user)
    task.enabled_to_process = true
    task.save (err) ->
      return res.status(500).json { message: err.message } if err
      res.status(200).json task
      return
    return
  return
