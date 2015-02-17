mongoose = require("mongoose")
WorkerResult = mongoose.model("WorkerResult")

#GET - Devuelve el hash con resultados del worker con el ID especificado
exports.getResult = (req, res) ->
  WorkerResult.findOne {worker: mongoose.Types.ObjectId(req.params.id) },
  (err, worker_result) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless worker_result # 404 si no existe el worker
    # Unauthorized si no es el propietario del worker
    return res.status(401).jsonp { message: "Not your worker"} unless mongoose.Types.ObjectId(req.user._id).equals(worker_result.user)
    res.status(200).jsonp worker_result.result
    return
  return
