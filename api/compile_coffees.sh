#!/bin/bash

coffee -o . coffee_scripts/app.coffee
coffee -o . coffee_scripts/test.coffee
coffee -o models/ -c models/*.coffee
coffee -o controllers/ -c controllers/*.coffee
