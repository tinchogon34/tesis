#fs = require 'fs'
request = require 'request'
assert = require 'assert'

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

#keyFile =  fs.readFileSync('./ssl/api.key')
#certFile = fs.readFileSync('./ssl/api.crt')

login_url = 'https://localhost:8080/login'
dummy_url = 'https://localhost:8080/api/v1/dummy'
workers_url = 'https://localhost:8080/api/v1/workers'
worker_results_url = 'https://localhost:8080/api/v1/worker_results'
fake_token = 'faketoken'

newWorker =
	data:
		0: 1
		1: 1
		2: 2
		3: 3
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

	#Test workers controller addWorker
	request.post(workers_url, {json: newWorker}, (error, response, createdWorker) ->
		assert.ifError error
		assert.equal response.statusCode, 200

		#Test workers controller findById
		request.get(workers_url+'/'+createdWorker._id, {json: true}, (error, response, workerFound) ->
			assert.ifError error
			assert.equal response.statusCode, 200

			#Test worker_results controller getResult
			request.get(worker_results_url+'/'+workerFound._id, (error, response, workerResult) ->
				assert.ifError error
				assert.equal response.statusCode, 404
			).auth null, null, true, token

			#Test workers controller enableToProcess
			request.post(workers_url+'/'+workerFound._id+'/enable', {json: true}, (error, response, workerEnabled) ->
				assert.ifError error
				assert.equal response.statusCode, 200

				#Test workers controller deleteWorker
				request.del(workers_url+'/'+workerEnabled._id, (error, response, body) ->
					assert.ifError error
					assert.equal response.statusCode, 200
				).auth null, null, true, token
			).auth null, null, true, token
		).auth null, null, true, token		
	).auth null, null, true, token