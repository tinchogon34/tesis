exports = module.exports = (app, mongoose, conn) ->
	coreLogsSchema = new mongoose.Schema({
    task:
      type: mongoose.Schema.Types.ObjectId
      ref: 'Task'
    reducing: Boolean
    enabled_to_process: Boolean
		map_results: { type: mongoose.Schema.Types.Mixed, default: {} }
		reduce_data: { type: mongoose.Schema.Types.Mixed, default: {} }
		reduce_results: { type: mongoose.Schema.Types.Mixed, default: {} }
		results: { type: mongoose.Schema.Types.Mixed, default: {} }
		available_slices: { type: [Number], default: [] }
		slices: Number
	},
		minimize: false
	)

	conn.model 'CoreLog', coreLogsSchema, 'Tasks'
