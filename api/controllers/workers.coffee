mongoose = require("mongoose")
Worker = mongoose.model("Worker")

#GET - Devuelve todos los Workers en la DB
#exports.findAllWorkers = (req, res) ->
#  Worker.find (err, workers) ->
#    res.send 500, err.message if err
#    res.status(200).jsonp workers
#    return
#  return

#GET - Devuelve un worker con el ID especificado
exports.findById = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless worker
    return res.status(401).jsonp { message: "Not your worker"} unless mongoose.Types.ObjectId(req.user._id).equals(worker.user)
    res.status(200).jsonp worker
    return
  return

#POST - Inserta un nuevo worker en la DB
exports.addWorker = (req, res) ->
  worker = new Worker(
    data: req.body.data
    imap: "investigador_map = " + req.body.imap
    ireduce: "investigador_reduce = " + req.body.ireduce
    available_slices: req.body.available_slices
    slices: req.body.slices
    user: req.user._id
    enabled_to_process: false
  )
  worker.save (err, worker) ->
    return res.status(500).jsonp { message: err.message } if err
    res.status(200).jsonp worker
    return
  return

#PUT - Actualiza un worker existente
#exports.updateWorker = (req, res) ->
#  Worker.findById req.params.id, (err, worker) ->
#    worker.data = req.body.data if req.body.data
#    worker.imap = "investigador_map = " + req.body.imap if req.body.imap
#    worker.ireduce = "investigador_reduce = " + req.body.ireduce if req.body.ireduce
#    worker.available_slices = req.body.available_slices if req.body.available_slices
#    worker.slices = req.body.slices if req.body.slices
#    worker.save (err) ->
#      return res.send(500, err.message) if err
#      res.status(200).jsonp worker
#      return
#    return
#  return

#DELETE - Borra un worker con el ID especificado
exports.deleteWorker = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.status(500).jsonp { message: err.message } if err
    return res.send 404 unless worker
    return res.status(401).jsonp { message: "Not your worker"} unless mongoose.Types.ObjectId(req.user._id).equals(worker.user)
    worker.remove (err) ->
      return res.status(500).jsonp { message: err.message } if err
      res.send 200
      return
    return
  return

#POST - Agrega datos al worker con el ID especificado
exports.addData = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.send(500, err.message) if err
    return res.send 404 unless worker
    worker.data = worker.data || {}
    for attrname of req.body.data
      worker.data[attrname] = req.body.data[attrname]
    worker.available_slices = worker.available_slices.concat req.body.available_slices
    worker.slices = worker.slices.concat req.body.slices
    worker.save (err) ->
      return res.send(500, err.message) if err
      res.status(200).jsonp worker
      return
    return
  return

#POST - Actualiza el worker con el ID especificado para que pueda ser procesado
exports.enableToProcess = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.send(500, err.message) if err
    return res.send 404 unless worker
    worker.enabled_to_process = true
    worker.save (err) ->
      return res.send(500, err.message) if err
      res.status(200).jsonp worker
      return
    return
  return
