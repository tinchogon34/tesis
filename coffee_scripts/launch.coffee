spawn = require('child_process').spawn
fs = require 'fs'
api = core = reducer = client = meteor = null
API_PORT = 3003
SERVER_PORT = 3002
CLIENT_PORT = 8000

console.log "Compilando coffees"
compile_coffees = spawn './compile_coffees.sh'
compile_coffees.on 'exit', (code) ->
  console.log "Iniciando Servidor Meteor"
  spawn 'meteor', ['reset'], {cwd: 'viewer'}
  setTimeout(->
    meteor = spawn 'meteor', [], {cwd: 'viewer'}
    setTimeout(->
      console.log "Limpiando DB"
      init_db = spawn 'node', ['init_db.js', '-c', '-r', '0']
      init_db.on 'exit', (code) ->
        console.log "Inicializando API DB"
        init_api_db = spawn 'node', ['init_api_db.js'], {cwd: 'api'}
        init_api_db.on 'exit', (code) ->
          console.log "API iniciada y escuchando en puerto " + API_PORT.toString()
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
            console.log "Corriendo ejemplo"
            example = spawn 'node', ['app.js'], {cwd: 'examples/contador'}
            example.on 'exit', (code) ->
              console.log "Server iniciado y escuchando en puerto " + SERVER_PORT.toString()
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
                console.log "Server se cerró con código: " + code

              console.log "Reducer iniciado"
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
                  console.log "Reducer se cerró con código: " + code

                console.log "Cliente iniciado y escuchando en puerto " + CLIENT_PORT.toString()
                fs.truncate 'logs/client.log', 0, ->
                  return
                fs.truncate 'logs/client.error.log', 0, ->
                  return
                client = spawn './start.sh', [], {cwd: 'client'}
                client.stdout.on 'data', (data) ->
                  fs.appendFile 'logs/client.log', data, null
                client.on 'exit', (code) ->
                  console.log "Cliente se cerró con código: " + code
                client.stderr.on 'data', (data) ->
                  fs.appendFile 'logs/client.error.log', data, null
          ,5000)
    ,20000)
  ,10000)
process.stdin.resume()
process.on 'SIGINT', ->
  api.kill() if api
  core.kill() if core
  reducer.kill() if reducer
  client.kill() if client
  meteor.kill() if meteor
  process.exit()
