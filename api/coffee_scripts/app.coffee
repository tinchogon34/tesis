express = require 'express.io'
bodyParser = require 'body-parser'
morgan  = require 'morgan'
assert = require 'assert'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
_ = require("underscore")
methodOverride = require 'method-override'
mongoose = require 'mongoose'

app = express()
db_url = 'mongodb://localhost/tesis'
db = null

# Connect to DB
mongoose.connect db_url, (err, connection) ->
	assert.ifError err

#Import models and controllers
models = require('./models/worker')(app, mongoose)
workersController = require('./controllers/workers')

# SET MIDDLEWARE
app.use morgan 'default'
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true

#API Routes
#app.get '/api/v1/workers', workersController.findAllWorkers
app.post '/api/v1/workers', workersController.addWorker
app.get '/api/v1/workers/:id', workersController.findById
app.put '/api/v1/workers/:id', workersController.updateWorker
app.delete '/api/v1/workers/:id', workersController.deleteWorker

app.post '/api/v1/workers/:id/addData', workersController.addData

app.listen '8080'