LineByLineReader = require 'line-by-line'
fs = require 'fs'
request = require 'request'
assert = require 'assert'

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

#keyFile =  fs.readFileSync('./ssl/api.key')
#certFile = fs.readFileSync('./ssl/api.crt')

login_url = 'https://localhost:8080/login'
workers_url = 'https://localhost:8080/api/v1/workers'
worker_results_url = 'https://localhost:8080/api/v1/worker_results'
file = './text'
lr = new LineByLineReader(file)
index = 0
hash = {}
token = null
createdWorker = null
lr.pause()
lr.on 'line', (line)->
	hash[index] = line
	if (index+1) % 40 == 0
		lr.pause()
		console.log index
		send_data hash, token, createdWorker
		hash = {}
	index++
#digits = "abcdefghijklmnñopqrstuvwxyz".split('')

newWorker =
	imap: "function (k, v) {var countWords = function(s){ s = s.replace(/(^\s*)|(\s*$)/gi,\"\");s = s.replace(/[ ]{2,}/gi,\" \");s = s.replace(/\n /,\"\n\");return s.split(' ').length;};self.log('inv in');self.emit('llave', countWords(v));self.log('inv in out');};"
	ireduce: "function (k, vals) { var total = vals.reduce(function(a, b) {return parseInt(a) + parseInt(b);});self.emit(k, total);};"

loginCredentials =
	username: 'investigador'
	password: 'investigador'

request.post login_url, { json: loginCredentials }, (error, response, body) ->
	assert.ifError error
	assert.equal response.statusCode, 200
	token = body.token

	request.post(workers_url, {json: newWorker}, (error, response, worker) ->
		assert.ifError error
		assert.equal response.statusCode, 200

		createdWorker = worker
		lr.resume()
	).auth null, null, true, token

get_slices = (data, size) ->
	# {0: ..., 1: ...., 2: ..., 3: ...., 4: ....}
	# [{0: ..., 1: ...}, {2: ..., 3: ....}, {4: ....}]

	arr = []
	keysLength = Object.keys(data).length

	arr[i] = {} for i in [0...Math.ceil(keysLength/size)]
	i = 0
	contador = 0    
	for key, value of data
		arr[i][key] = value
		contador++
		i++ if (contador) % size == 0
	return arr

send_data = (data, token, worker) ->

	slices = get_slices(data, 10)
	available_slices = []
	available_slices[i] = i for i in [0...slices.length]
	
	json = 
		data: data
		available_slices: available_slices
		slices: slices

	request.post(workers_url+'/'+worker._id+'/addData', {json: json}, (error, response, updatedWorker) ->
		assert.ifError error
		assert.equal response.statusCode, 200

		lr.resume()
	).auth null, null, true, token