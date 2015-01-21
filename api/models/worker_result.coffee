exports = module.exports = (app, mongoose) ->
	workerResultSchema = new mongoose.Schema(
		result: mongoose.Schema.Types.Mixed
	)

	mongoose.model 'WorkerResult', workerResultSchema