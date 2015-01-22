exports = module.exports = (app, mongoose) ->
	workerResultSchema = new mongoose.Schema(
		result: mongoose.Schema.Types.Mixed
		user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
		worker: { type: mongoose.Schema.Types.ObjectId, ref: 'Worker' }
	)

	mongoose.model 'WorkerResult', workerResultSchema