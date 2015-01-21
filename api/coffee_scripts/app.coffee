express = require 'express.io'
bodyParser = require 'body-parser'
morgan  = require 'morgan'
assert = require 'assert'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
_ = require("underscore")
methodOverride = require 'method-override'
mongoose = require 'mongoose'
jwt = require 'jsonwebtoken'
expressjwt = require 'express-jwt'
app = express()
db_url = 'mongodb://localhost/tesis'
db = null
SECRET = '0239f0j3924ufm28j4y9f23842yf3984'

# Connect to DB
mongoose.connect db_url, (err, connection) ->
	assert.ifError err

#Import models and controllers
models = require('./models/worker')(app, mongoose)
workersController = require('./controllers/workers')
workerResultsController = require('./controllers/workerResults')
usersController = require('./controllers/users')

# SET MIDDLEWARE
app.use morgan 'default'
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true
app.use '/api', expressjwt({secret: SECRET})

#API Routes
app.post '/api/v1/workers', workersController.addWorker
app.get '/api/v1/workers/:id', workersController.findById
app.delete '/api/v1/workers/:id', workersController.deleteWorker

app.get '/api/v1/worker_results/:id/result', workerResultsController.getResult

app.post '/login', usersController.loginWithCredentials

app.listen '8080'