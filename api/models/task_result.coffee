exports = module.exports = (app, mongoose) ->
	taskResultSchema = new mongoose.Schema({
		result: mongoose.Schema.Types.Mixed
		user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
	},
		minimize: false
	)

	mongoose.model 'TaskResult', taskResultSchema