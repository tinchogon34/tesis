mongoose = require("mongoose")
Worker = mongoose.model("Worker")

#GET - Return all workers in the DB
#exports.findAllWorkers = (req, res) ->
#  Worker.find (err, workers) ->
#    res.send 500, err.message if err
#    res.status(200).jsonp workers
#    return
#  return

#GET - Return a Worker with specified ID
exports.findById = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.send(500, err.message)  if err
    res.status(200).jsonp worker
    return
  return

#POST - Insert a new Worker in the DB
exports.addWorker = (req, res) ->
  worker = new Worker(
    data: req.body.data
    imap: "investigador_map = " + req.body.imap
    ireduce: "investigador_reduce = " + req.body.ireduce
    available_slices: req.body.available_slices
    slices: req.body.slices
  )
  worker.save (err, worker) ->
    return res.send(500, err.message) if err
    res.status(200).jsonp worker
    return
  return

#PUT - Update a register already exists
exports.updateWorker = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    worker.data = req.body.data if req.body.data
    worker.imap = "investigador_map = " + req.body.imap if req.body.imap
    worker.ireduce = "investigador_reduce = " + req.body.ireduce if req.body.ireduce
    worker.available_slices = req.body.available_slices if req.body.available_slices
    worker.slices = req.body.slices if req.body.slices
    worker.save (err) ->
      return res.send(500, err.message) if err
      res.status(200).jsonp worker
      return
    return
  return

#DELETE - Delete a Worker with specified ID
exports.deleteWorker = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.send(500, err.message) if err
    worker.remove (err) ->
      return res.send(500, err.message) if err
      res.status 200
      return
    return
  return

#POST - Add data to existing Worker with specified ID
exports.addData = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    worker.data.concat req.params.data
    worker.available_slices.concat req.params.available_slices
    worker.slices.concat req.params.slices
    worker.save (err) ->
      return res.send(500, err.message) if err
      res.status(200).jsonp worker
      return
    return
  return