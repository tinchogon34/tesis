mongoose = require("mongoose")
TaskResult = mongoose.model("TaskResult")

#GET - Devuelve el hash con resultados del task con el ID del task especificado
exports.getTaskResult = (req, res) ->
  TaskResult.findOne task: req.params.task, (err, task_result) ->
    return res.status(500).json { message: err.message } if err
    return res.send 404 unless task_result # 404 si no existe el task
    # Unauthorized si no es el propietario del task
    return res.status(401).json { message: "Not your task"} unless mongoose.Types.ObjectId(req.user._id).equals(task_result.user)
    res.status(200).json task_result.result
    return
  return
