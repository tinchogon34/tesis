mongoose = require("mongoose")
bcrypt = require('bcrypt')
jwt = require 'jsonwebtoken'
SECRET = '0239f0j3924ufm28j4y9f23842yf3984' # secreto con el que se genera el token

module.exports = (conn) ->
  module = {}
  User = conn.model("User")

  #GET - Devuelve un token con el user logeado
  module.loginWithCredentials = (req, res) ->
    User.findOne {username: req.body.username}, (err, user) ->
      return res.status(500).json { message: err.message } if err
      if user # Si encontro un usuario con ese username
        if bcrypt.compareSync(req.body.password, user.password_hash) # Si las passwords coinciden
          token = jwt.sign user, SECRET, { expiresInMinutes: 60*5 } # Genero token
          return res.status(200).json { token: token }
      return res.status(401).json { message: 'Wrong user or password' }
    return

  #POST - Inserta un nuevo user en la DB
  module.register = (req, res) ->
    User.findOne {username: req.body.username}, (err, user) ->
      return res.status(500).json { message: err.message } if err
      if user
        return res.status(400).json { message: "Username already in use" }
      user = new User(
        username: req.body.username
        password_hash: bcrypt.hashSync(req.body.password, 10)
        name: req.body.name
        lastname: req.body.lastname
      )
      user.save (err, user) ->
        return res.status(500).json { message: err.message } if err
        res.status(200).json user
        return

  #GET - Devuelve el user logeado
  module.getLoggedUser = (req, res) ->
    res.status(200).json req.user
    return

  return module
