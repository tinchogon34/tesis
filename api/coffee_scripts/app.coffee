express = require 'express'
#https = require('https')
bodyParser = require 'body-parser'
morgan  = require 'morgan'
assert = require 'assert'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
_ = require "underscore"
methodOverride = require 'method-override'
mongoose = require 'mongoose'
jwt = require 'jsonwebtoken'
expressjwt = require 'express-jwt'
fs = require 'fs'
cors = require('cors')

app = express()
db_url = 'mongodb://localhost:27017/tesis'
meteor = 'mongodb://localhost:3001/meteor'
db = null
SECRET = '0239f0j3924ufm28j4y9f23842yf3984'
#options =
#  key: fs.readFileSync('../ssl/server.key')
#  cert: fs.readFileSync('../ssl/server.crt')


# Connect to DB
#mongoose.connect db_url, (err, connection) ->
#  assert.ifError err

mongoose.Promise = global.Promise;

conn      = mongoose.createConnection(db_url)
conn2     = mongoose.createConnection(meteor)

#Import models and controllers
taskModel = require('./models/task')(app, mongoose, conn)
userModel = require('./models/user')(app, mongoose, conn)
taskResultModel = require('./models/task_result')(app, mongoose, conn)
coreLogModel = require('./models/core_logs')(app, mongoose, conn2)
tasksController = require('./controllers/tasks')(conn, conn2)
taskResultsController = require('./controllers/taskResults')(conn)
usersController = require('./controllers/users')(conn)

# SET MIDDLEWARE
app.use morgan 'combined'
app.use bodyParser.json({limit: '50mb'})
app.use bodyParser.urlencoded extended: true
app.use cors()
app.use '/api', expressjwt({secret: SECRET})
app.use (err, req, res, next) ->
  res.status(401).json { message: 'You must login first' } if err.constructor.name == 'UnauthorizedError'

#httpsServer = https.createServer(options, app)

#API Routes
app.get '/api/v1/dummy', (req, res) ->
  res.send 200

app.post '/api/v1/tasks/:id/addData', tasksController.addData
app.post '/api/v1/tasks/:id/enable', tasksController.enableToProcess
app.get '/api/v1/tasks/:id', tasksController.findById
app.delete '/api/v1/tasks/:id', tasksController.deleteTask
app.post '/api/v1/tasks', tasksController.addTask
app.get '/api/v1/tasks', tasksController.listTasks

app.get '/api/v1/task_results/:task', taskResultsController.getTaskResult
app.delete '/api/v1/task_results/:id', taskResultsController.deleteTaskResult

app.post '/login', usersController.loginWithCredentials
app.post '/register', usersController.register
app.get '/api/v1/users/logged', usersController.getLoggedUser

#httpsServer.listen '3003'
app.listen '3003'
