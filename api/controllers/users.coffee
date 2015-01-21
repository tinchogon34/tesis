mongoose = require("mongoose")
bcrypt = require('bcrypt')
User = mongoose.model("User")
SECRET = '0239f0j3924ufm28j4y9f23842yf3984'

#GET - Devuelve un token con el user logeado
exports.loginWithCredentials = (req, res) ->
  User.find {username: req.body.username, password: bcrypt.hashSync(req.body.password,10)}, (err, user) ->
    return res.send(500, err.message) if err
    return res.send(401, 'Wrong user or password') unless user.length
    token = jwt.sign user, SECRET, { expiresInMinutes: 60*5 }
    res.status(200).jsonp {token: token}
    return
  return