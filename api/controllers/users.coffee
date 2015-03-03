mongoose = require("mongoose")
bcrypt = require('bcrypt')
jwt = require 'jsonwebtoken'
User = mongoose.model("User")
SECRET = '0239f0j3924ufm28j4y9f23842yf3984' # secreto con el que se genera el token

#GET - Devuelve un token con el user logeado
exports.loginWithCredentials = (req, res) ->
  User.findOne {username: req.body.username}, (err, user) ->
    return res.status(500).jsonp { message: err.message } if err
    if user # Si encontro un usuario con ese username
      if bcrypt.compareSync(req.body.password, user.password_hash) # Si las passwords coinciden
        token = jwt.sign user, SECRET, { expiresInMinutes: 60*5 } # Genero token
        return res.status(200).jsonp { token: token }
    return res.status(401).jsonp { message: 'Wrong user or password' }
  return