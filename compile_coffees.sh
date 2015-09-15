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

#EXAMPLES coffees
rm examples/hash_crack/app.js examples/contador/app.js examples/contador/testwordcount.js
coffee -o examples/hash_crack/ examples/hash_crack/coffee_scripts/app.coffee
coffee -o examples/contador/ examples/contador/coffee_scripts/app.coffee
coffee -o examples/contador/ examples/contador/coffee_scripts/testwordcount.coffee
