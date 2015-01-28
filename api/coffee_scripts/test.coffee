fs = require 'fs'
request = require 'request'
assert = require 'assert'

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

keyFile =  fs.readFileSync('./ssl/api.key')
certFile = fs.readFileSync('./ssl/api.crt')

login_url = 'https://localhost:8080/login'
dummy_url = 'https://localhost:8080/api/v1/dummy'
fake_token = 'faketoken'

defaultOptions =
	json: true	
	agentOptions:
		cert: certFile
		key: keyFile
		securityOptions: 'SSL_OP_NO_SSLv3'

request.defaults defaultOptions

loginCredentials =
	username: 'test'
	password: 'test'

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




