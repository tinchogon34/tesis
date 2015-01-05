mongoose = require("mongoose")
Worker = mongoose.model("Worker")

#GET - Return all workers in the DB
exports.findAllWorkers = (req, res) ->
  Worker.find (err, workers) ->
    res.send 500, err.message  if err
    console.log "GET /workers"
    res.status(200).jsonp workers
    return

  return


#GET - Return a Worker with specified ID
exports.findById = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    return res.send(500, err.message)  if err
    console.log "GET /worker/" + req.params.id
    res.status(200).jsonp worker
    return

  return


#POST - Insert a new Worker in the DB
exports.addWorker = (req, res) ->
  console.log "POST"
  console.log req.body
  worker = new Worker(
    title: req.body.title
    year: req.body.year
    country: req.body.country
    poster: req.body.poster
    seasons: req.body.seasons
    genre: req.body.genre
    summary: req.body.summary
  )
  worker.save (err, worker) ->
    return res.send(500, err.message)  if err
    res.status(200).jsonp worker
    return

  return


#PUT - Update a register already exists
exports.updateWorker = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    worker.title = req.body.petId
    worker.year = req.body.year
    worker.country = req.body.country
    worker.poster = req.body.poster
    worker.seasons = req.body.seasons
    worker.genre = req.body.genre
    worker.summary = req.body.summary
    worker.save (err) ->
      return res.send(500, err.message)  if err
      res.status(200).jsonp worker
      return

    return

  return


#DELETE - Delete a Worker with specified ID
exports.deleteWorker = (req, res) ->
  Worker.findById req.params.id, (err, worker) ->
    worker.remove (err) ->
      return res.send(500, err.message)  if err
      res.status 200
      return

    return

  return