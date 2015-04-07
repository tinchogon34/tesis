request = require 'request'
assert = require 'assert'

#process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

login_url = 'http://localhost:8080/login'
dummy_url = 'http://localhost:8080/api/v1/dummy'
tasks_url = 'http://localhost:8080/api/v1/tasks'
task_results_url = 'http://localhost:8080/api/v1/task_results'
fake_token = 'faketoken'

newTask =
  imap: "function (k, v) {\r\n  self.log(\"inv in\"); self.emit(\"llave\", v*v);\r\n  self.log(\"inv in out\");\r\n};"
  ireduce: "function (k, vals) {\r\n  var total = vals.reduce(function(a, b) {\r\n    return parseInt(a) + parseInt(b);\r\n  });\r\n  self.emit(k, total);\r\n};"
  available_slices: [0, 1]
  slices: [
        {
            0: 1
            1: 1
            2: 2
        }
        {
            3: 3
        }
    ]

fakeLoginCredentials =
  username: 'fake_test'
  password: 'fake_test'

loginCredentials =
  username: 'test'
  password: 'test'

#Test fakeCredentials should not return token
request.post login_url, { json: fakeLoginCredentials }, (error, response, body) ->
  assert.ifError error
  assert.equal response.statusCode, 401

#Test realCredentials should return token
request.post login_url, { json: loginCredentials }, (error, response, body) ->
  assert.ifError error
  assert.equal response.statusCode, 200
  token = body.token

  #Test fake_token should not login
  request.get(dummy_url, (error, response, body) ->
    assert.ifError error
    assert.equal response.statusCode, 401).auth null, null, true, fake_token

  #Test realtoken should login
  request.get(dummy_url, (error, response, body) ->
    assert.ifError error
    assert.equal response.statusCode, 200).auth null, null, true, token

  #Test tasks controller addtask
  request.post(tasks_url, {json: newTask}, (error, response, createdTask) ->
    assert.ifError error
    assert.equal response.statusCode, 200

    #Test tasks controller findById
    request.get(tasks_url+'/'+createdTask._id, {json: true}, (error, response, taskFound) ->
      assert.ifError error
      assert.equal response.statusCode, 200

      #Test task_results controller getResult
      request.get(task_results_url+'/'+taskFound._id, (error, response, taskResult) ->
        assert.ifError error
        assert.equal response.statusCode, 404
      ).auth null, null, true, token

      #Test tasks controller enableToProcess
      request.post(tasks_url+'/'+taskFound._id+'/enable', {json: true}, (error, response, taskEnabled) ->
        assert.ifError error
        assert.equal response.statusCode, 200

        #Test tasks controller deletetask
        request.del(tasks_url+'/'+taskEnabled._id, (error, response, body) ->
          assert.ifError error
          assert.equal response.statusCode, 200
        ).auth null, null, true, token
      ).auth null, null, true, token
    ).auth null, null, true, token
  ).auth null, null, true, token