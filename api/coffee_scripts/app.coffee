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

models = require('./models/worker')(app, mongoose)


# SET MIDDLEWARE
app.use morgan 'default'
app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true

app.listen '8080'