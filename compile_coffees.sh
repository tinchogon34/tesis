#!/bin/bash

#API Coffees
coffee -o api/ api/coffee_scripts/app.coffee
coffee -o api/ api/coffee_scripts/test.coffee
coffee -o api/models/ -c api/models/*.coffee
coffee -o api/controllers/ -c api/controllers/*.coffee

#CORE coffees
coffee -o . coffee_scripts/app.coffee
coffee -o . coffee_scripts/reducer.coffee
coffee -o . coffee_scripts/worker.coffee
coffee -o public/ coffee_scripts/proc.coffee

#EXAMPLES coffees
coffee -o examples/hash_crack/ examples/hash_crack/coffee_scripts/app.coffee
coffee -o examples/contador/ examples/contador/coffee_scripts/app.coffee
