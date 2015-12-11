#!/bin/bash

#API Coffees
rm api/app.js api/test.js api/models/*.js  api/controllers/*.js
coffee -o api/ api/coffee_scripts/app.coffee
coffee -o api/ api/coffee_scripts/test.coffee
coffee -o api/models/ -c api/models/*.coffee
coffee -o api/controllers/ -c api/controllers/*.coffee

#CORE coffees
rm app.js reducer.js public/worker.js launch.js public/proc.js
coffee -o . coffee_scripts/app.coffee
coffee -o . coffee_scripts/reducer.coffee
coffee -o public/ coffee_scripts/worker.coffee
coffee -o . coffee_scripts/launch.coffee
coffee -o public/ coffee_scripts/proc.coffee

#VISUALIZER coffees
rm visualizer/app.js
coffee -o visualizer/ visualizer/coffee_scripts/app.coffee

#EXAMPLES coffees
rm examples/contador/app.js examples/contador/testwordcount.js
coffee -o examples/contador/ examples/contador/coffee_scripts/app.coffee
coffee -o examples/contador/ examples/contador/coffee_scripts/testwordcount.coffee

rm examples/primos/app.js
coffee -o examples/primos/ examples/primos/coffee_scripts/app.coffee

rm examples/eng_stopwords/app.js
coffee -o examples/eng_stopwords/ examples/eng_stopwords/coffee_scripts/app.coffee

rm examples/tf/app.js
coffee -o examples/tf/ examples/tf/coffee_scripts/app.coffee

rm examples/stopwords_tf/app.js
coffee -o examples/stopwords_tf/ examples/stopwords_tf/coffee_scripts/app.coffee
