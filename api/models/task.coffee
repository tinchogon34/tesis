exports = module.exports = (app, mongoose) ->
	taskSchema = new mongoose.Schema({
		#data: mongoose.Schema.Types.Mixed
		imap: String
		ireduce: String
		map_results: { type: mongoose.Schema.Types.Mixed, default: {} }
		reduce_data: { type: mongoose.Schema.Types.Mixed, default: {} }
		reduce_results: { type: mongoose.Schema.Types.Mixed, default: {} }
		available_slices: { type: [Number], default: [] }
		slices: { type: [mongoose.Schema.Types.Mixed], default: [] }
		user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }
		enabled_to_process: Boolean
	},
		minimize: false
	)

	mongoose.model 'Task', taskSchema