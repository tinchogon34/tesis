exec = require('child_process').exec

console.log "compiling coffees"
exec './compile_coffees.sh', (error, stdout, stderr) ->
  console.log "cleaning db"
  exec 'node init_db.js -c -r 0', (error, stdout, stderr) ->
    console.log "init api started"
    exec 'cd api && node init_api_db.js', (error, stdout, stderr) ->
      console.log "api started on port 8080"
      exec 'cd api && node app.js', (error, stdout, stderr) ->
        return
      setTimeout(->
        console.log "running example"
        exec 'cd examples/contador && node app.js', (error, stdout, stderr) ->
          console.log "server started on port 3000"
          exec 'node app.js', (error, stdout, stderr) ->
            return
          console.log "reducer started"
          exec 'node reducer.js', (error, stdout, stderr) ->
            return
          console.log "client started on port 8000"
          exec 'cd client && ./start.sh', (error, stdout, stderr) ->
            return
      ,5000)