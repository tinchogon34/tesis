mongoose = require("mongoose")
WorkerResult = mongoose.model("WorkerResult")

#GET - Devuelve el hash con resultados del worker con el ID especificado
exports.getResult = (req, res) ->
  WorkerResult.findById req.params.id, (err, worker_result) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.status(401).jsonp { message: "Not your worker"} unless req.user._id.equals(worker_result.user_id)
    res.status(200).jsonp worker_result.result
    return
  return
