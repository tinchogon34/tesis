LineByLineReader = require 'line-by-line'
fs = require 'fs'
file = './text'
lr = new LineByLineReader(file)
word_count = 0
numLines = 0
index = 0

countWords = (text) ->
  return 0 if text == ''
  text = text.replace(/^\s+|\s+$/g, "")
  text = text.replace(/[\'";:,.?¿\-!¡\n\r\t\f]+/g, "")
  return text.split(" ").length

lr.pause()
lr.on 'line', (line)->
  word_count += countWords(line)
  console.log word_count + " palabras" if index == numLines
  index++

fs.createReadStream(file).on('data', (chunk) ->
  numLines += chunk.toString('utf8').split(/\r\n|[\n\r\u0085\u2028\u2029]/g).length - 1
  return).on('end', ->
    lr.resume()
)