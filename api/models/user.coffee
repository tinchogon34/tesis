exports = module.exports = (app, mongoose) ->
	userSchema = new mongoose.Schema({
    name: String
    lastname: String
		username: String
		password_hash: String
	},
		minimize: false
	)

	mongoose.model 'User', userSchema