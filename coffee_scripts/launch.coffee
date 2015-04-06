spawn = require('child_process').spawn
fs = require 'fs'
api = core = reducer = client = null

console.log "compiling coffees"
compile_coffees = spawn './compile_coffees.sh'
compile_coffees.on 'exit', (code) ->  
  console.log "cleaning db"
  init_db = spawn 'node', ['init_db.js', '-c', '-r', '0']
  init_db.on 'exit', (code) ->
    console.log "init api started"
    init_api_db = spawn 'node', ['init_api_db.js'], {cwd: 'api'}
    init_api_db.on 'exit', (code) ->
      console.log "api started on port 8080"
      api = spawn 'node', ['app.js'], {cwd: 'api'}
      fs.truncate 'logs/api.log', 0, ->
        return
      fs.truncate 'logs/api.error.log', 0, ->
        return
      api.stdout.on 'data', (data) ->
        fs.appendFile 'logs/api.log', data, null
      api.stderr.on 'data', (data) ->
        fs.appendFile 'logs/api.error.log', data, null
      setTimeout(->
        console.log "running example"
        example = spawn 'node', ['app.js'], {cwd: 'examples/contador'}
        example.on 'exit', (code) ->

          console.log "server started on port 3000"
          fs.truncate 'logs/core.log', 0, ->
            return
          fs.truncate 'logs/core.error.log', 0, ->
            return
          core = spawn 'node', ['app.js']
          core.stdout.on 'data', (data) ->
            fs.appendFile 'logs/core.log', data, null
          core.stderr.on 'data', (data) ->
            fs.appendFile 'logs/core.error.log', data, null
          core.on 'exit', (code) ->
            console.log "core exit with code: " + code

          console.log "reducer started"
          fs.truncate 'logs/reducer.log', 0, ->
            return
          fs.truncate 'logs/reducer.error.log', 0, ->
            return
          lock = spawn 'rm', ['.tesis.lock'], {cwd: '/var/tmp'}
          lock.on 'exit', (code) ->
            reducer = spawn 'node', ['reducer.js']
            reducer.stdout.on 'data', (data) ->
              fs.appendFile 'logs/reducer.log', data, null
            reducer.stderr.on 'data', (data) ->
              fs.appendFile 'logs/reducer.error.log', data, null
            reducer.on 'exit', (code) ->
              console.log "reducer exit with code: " + code

            console.log "client started on port 8000"
            fs.truncate 'logs/client.log', 0, ->
              return
            fs.truncate 'logs/client.error.log', 0, ->
              return
            client = spawn './start.sh', [], {cwd: 'client'}
            client.stdout.on 'data', (data) ->
              fs.appendFile 'logs/client.log', data, null
            client.on 'exit', (code) ->
              console.log "client exit: " + code 
            client.stderr.on 'data', (data) ->
              fs.appendFile 'logs/client.error.log', data, null
      ,5000)

process.stdin.resume()
process.on 'SIGINT', ->
  api.kill() if api
  core.kill() if core
  reducer.kill() if reducer
  client.kill() if client
  process.exit()
