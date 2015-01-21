exports = module.exports = (app, mongoose) ->
	userSchema = new mongoose.Schema(
		username: String
		password_hash: String
	)

	mongoose.model 'User', userSchema