spawn = require('child_process').spawn

console.log "compiling coffees"
compile_coffees = spawn './compile_coffees.sh'
compile_coffees.on 'exit', (code) ->  
  console.log "cleaning db"
  init_db = spawn 'node', ['init_db.js', '-c', '-r 0']
  init_db.on 'exit', (code) ->
    console.log "init api started"
    init_api_db = spawn 'node', ['init_api_db.js'], {cwd: 'api'}
    init_api_db.on 'exit', (code) ->
      console.log "api started on port 8080"
      api = spawn 'node', ['app.js'], {cwd: 'api'}
      setTimeout(->
        console.log "running example"
        example = spawn 'node', ['app.js'], {cwd: 'examples/contador'}
        example.on 'exit', (code) ->
          console.log "server started on port 3000"
          core = spawn 'node', ['app.js']
          core.stderr.on 'data', (data) ->
            console.log "core error: " + data
          console.log "reducer started"
          reducer = spawn 'node', ['reducer.js']
          reducer.stderr.on 'data', (data) ->
            console.log "reducer error: " + data
          console.log "client started on port 8000"
          client = spawn './start.sh', [], {cwd: 'client'}
          client.stderr.on 'data', (data) ->
            console.log "client error: " + data
      ,5000)