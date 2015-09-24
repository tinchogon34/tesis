expressio = require 'express.io'
morgan  = require 'morgan'
compression = require 'compression'
MongoClient = require('mongodb').MongoClient
ObjectID = require('mongodb').ObjectID
serveStatic = require 'serve-static'

app = expressio()
app.http().io()

app.engine 'html', require('ejs').renderFile

app.use '/public', serveStatic __dirname + '/public'
app.use morgan 'default'
app.use compression()

app.get '/', (req, res) ->
  return res.render("index.html")

app.get '/test', (req, res) ->
  return res.render("test.html")

app.io.route 'my event', (req) ->
  req.io.emit 'my response',
    data: req.data.data

app.io.route 'my broadcast event', (req) ->
  app.io.broadcast 'my response',
    data: req.data.data

app.io.route 'connect', (req) ->
  req.io.emit 'my response',
    data: 'Connected'

app.io.route 'disconnect', (req) ->
  console.log 'Client disconnected'

app.listen(8080)
