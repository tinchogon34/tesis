exports = module.exports = (app, mongoose) ->
	userSchema = new mongoose.Schema(
		username: String
		password: String
	)

	mongoose.model 'User', userSchema