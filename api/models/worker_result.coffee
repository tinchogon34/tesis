exports = module.exports = (app, mongoose) ->
	workerResultSchema = new mongoose.Schema({
		result: mongoose.Schema.Types.Mixed
		user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
	},
		minimize: false
	)

	mongoose.model 'WorkerResult', workerResultSchema