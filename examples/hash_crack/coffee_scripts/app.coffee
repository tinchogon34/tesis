#fs = require 'fs'
request = require 'request'
assert = require 'assert'

process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"

#keyFile =  fs.readFileSync('./ssl/api.key')
#certFile = fs.readFileSync('./ssl/api.crt')

login_url = 'https://localhost:8080/login'
workers_url = 'https://localhost:8080/api/v1/workers'
worker_results_url = 'https://localhost:8080/api/v1/worker_results'

digits = "abcdefghijklmnñopqrstuvwxyz1234567890".split('')

arr = []
pick = (n, got, pos, from) ->
	if got.length == n
		arr.push got.join('')
		return

	i = pos
	while i < from.length
	  got.push from[i]
	  pick(n, got, i, from)
	  got.pop()
	  i++

	return arr

i = 1
words = []
while i <= 8
	words = words.concat pick(i,[],0,digits)
	i++