exports = module.exports = (app, mongoose) ->
	workerSchema = new mongoose.Schema(
		data: mongoose.Schema.Types.Mixed
		imap: String
		ireduce: String
		map_results: mongoose.Schema.Types.Mixed
		reduce_data: mongoose.Schema.Types.Mixed
		reduce_results: mongoose.Schema.Types.Mixed
		result: mongoose.Schema.Types.Mixed
		available_slices: [Number]
		slices: [mongoose.Schema.Types.Mixed]
		user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
	)

	mongoose.model 'Worker', workerSchema