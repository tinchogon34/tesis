exports = module.exports = (app, mongoose) ->
	taskResultSchema = new mongoose.Schema({
    result: mongoose.Schema.Types.Mixed
    task: mongoose.Schema.Types.ObjectId
    user:
      type: mongoose.Schema.Types.ObjectId
      ref: 'User'
    }, minimize: false)

	mongoose.model 'TaskResult', taskResultSchema, 'task_results'