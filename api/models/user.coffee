exports = module.exports = (app, mongoose, conn) ->
	userSchema = new mongoose.Schema({
    name: String
    lastname: String
		username: String
		password_hash: String
	},
		minimize: false
	)

	conn.model 'User', userSchema
