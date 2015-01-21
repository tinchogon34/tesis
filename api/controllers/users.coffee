mongoose = require("mongoose")
bcrypt = require('bcrypt')
jwt = require 'jsonwebtoken'
User = mongoose.model("User")
SECRET = '0239f0j3924ufm28j4y9f23842yf3984'

#GET - Devuelve un token con el user logeado
exports.loginWithCredentials = (req, res) ->
  User.findOne {username: req.body.username}, (err, user) ->
    return res.send(500, err.message) if err
    if user
      if bcrypt.compareSync(req.body.password, user.password_hash)
        token = jwt.sign user, SECRET, { expiresInMinutes: 60*5 }
        return res.status(200).jsonp {token: token}
    return res.send(401, 'Wrong user or password')
  return