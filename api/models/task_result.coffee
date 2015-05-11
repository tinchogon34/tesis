exports = module.exports = (app, mongoose) ->
	taskResultSchema = new mongoose.Schema({
    result: mongoose.Schema.Types.Mixed
    task:
      type: mongoose.Schema.Types.ObjectId
      ref: 'Task'
    user:
      type: mongoose.Schema.Types.ObjectId
      ref: 'User'
    }, minimize: false)

	mongoose.model 'TaskResult', taskResultSchema, 'task_results'