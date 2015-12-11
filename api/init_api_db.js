"use strict";

var bcrypt = require('bcrypt');

/*
 * Script for initialization the Database.
 * USAGE: node init_db.js [OPTION1] [OPTION2]... arg1 arg2...
 * The following options are supported:
 *   -r, --records <ARG1>  New Records Quantity
 *   -t, --type <ARG1>     Object Type
 *   -c, --clean           Clean DB
 */

// Manejo de argumentos
//var stdio = require('stdio');
//var options = stdio.getopt({
//   'records': {key: 'r', description: 'New Records Quantity', args: 1},
//    'type': {key: 't', description: 'Object Type', args: 1},
//    'clean': {key: "c", description: "Clean DB"}
//});

// sample object
var test = {
    username: "test",
    password_hash: bcrypt.hashSync("test",10),
    name: "Test",
    lastname: "Prueba"
};

var investigador = {
    username: "investigador",
    password_hash: bcrypt.hashSync("investigador",10),
    name: "Investigador",
    lastname: "Prueba"
};

// imports
var MongoClient = require('mongodb').MongoClient,
assert = require('assert'),
_ = require("underscore"),
url = 'mongodb://localhost:27017/tesis';

// Connect and add records
MongoClient.connect(url, function(err, conn) {
    assert.equal(null, err);
    console.log("Connected correctly to server");
    var users = conn.collection("users");
    users.remove({}, function (err, count){
        assert.equal(null, err);
        users.insert([test, investigador], function (err, result) {
            assert.equal(err, null);
            console.log("Inserted elements: ", result.length);
            conn.close();
        });
    });
});
