mongoose = require("mongoose")

module.exports = (conn) ->
  module = {}
  TaskResult = conn.model("TaskResult")

  #GET - Devuelve el hash con resultados del task con el ID del task especificado
  module.getTaskResult = (req, res) ->
    TaskResult.findOne task: req.params.task, (err, task_result) ->
      return res.status(500).json { message: err.message } if err
      return res.send 404 unless task_result # 404 si no existe el task
      # Unauthorized si no es el propietario del task
      return res.status(401).json { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task_result.user)
      res.status(200).json task_result.result
      return
    return

  #DELETE - Borra un task result con el ID especificado
  module.deleteTaskResult = (req, res) ->
    TaskResult.findById req.params.id, (err, task_result) ->
      return res.status(500).json { message: err.message } if err
      return res.send 404 unless task_result # 404 si no existe el task_result
      # Unauthorized si no es el propietario del task result
      return res.status(401).json { message: "Not your task result"} unless mongoose.Types.ObjectId(req.user._id).equals(task_result.user)
      task_result.remove (err) ->
        return res.status(500).json { message: err.message } if err
        res.send 200
        return
      return
    return

  return module
