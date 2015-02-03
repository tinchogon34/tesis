lineReader = require 'line-reader'
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

	request.post(workers_url, {json: newWorker}, (error, response, createdWorker) ->
		assert.ifError error
		assert.equal response.statusCode, 200

		index = 0
		hash = {}
		lineReader.eachLine file, (line, last) ->
		  	hash[index] = line
	  		if (index+1) % 800 == 0
	  			console.log index
	  			console.log Object.keys(hash).length
	  			a.i = {}
		  		send_data hash, token, createdWorker
		  		hash = {}
		  	index++
		  	return
	).auth null, null, true, token	

get_slices = (data, size) ->
	# { "0" : 1, "1" : 1, "2" : 2, "3" : 3 }
	# { "0": { "0" : 1, "1" : 1, "2" : 2 }, 1: {"3" : 3} }
	hash = {}
	keysLength = Object.keys(data).length
	hash[i] = {} for i in [0..Math.floor(keysLength/size)]
	i = 0
	contador = 0    
	for key, value of data
		#hash[i] ||= {}
		hash[i][key] ||= {}
		hash[i][key] = value
		contador++
		i++ if (contador) % size == 0
	return hash

send_data = (data, token, worker) ->
	slices = get_slices(data, 40)
	available_slices = Object.keys(slices)
	console.log available_slices.length
	a.i = {}
	
#	json = 
#		data: data
#		available_slices: available_slices
#		slices: slices
#	request.post(workers_url+'/'+worker._id+'/addData', {json: json}, (error, response, updatedWorker) ->
#		assert.ifError error
#		assert.equal response.statusCode, 200
#	).auth null, null, true, token



#request.post login_url, { json: loginCredentials }, (error, response, body) ->
#	assert.ifError error
#	assert.equal response.statusCode, 200
#	token = body.token
#
#	request.post(workers_url, {json: newWorker}, (error, response, createdWorker) ->
#		assert.ifError error
#		assert.equal response.statusCode, 200
		#pick(i,[],0,digits)
#
#		send_data(1, token, 2, createdWorker)
#	).auth null, null, true, token

#i = 1
#words = []
#while i <= 8
#	words = words.concat pick(i,[],0,digits)
#	i++