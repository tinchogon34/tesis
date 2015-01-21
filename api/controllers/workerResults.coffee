mongoose = require("mongoose")
WorkerResult = mongoose.model("WorkerResult")

#GET - Devuelve el hash con resultados del worker con el ID especificado
exports.getResult = (req, res) ->
  WorkerResult.findById req.params.id, (err, worker_result) ->
    return res.send(500, err.message) if err
    res.status(200).jsonp worker_result.result
    return
  return
