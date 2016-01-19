exports = module.exports = (app, mongoose, conn) ->
	taskResultSchema = new mongoose.Schema({
    result: mongoose.Schema.Types.Mixed
    task:
      type: mongoose.Schema.Types.ObjectId
      ref: 'Task'
    user:
      type: mongoose.Schema.Types.ObjectId
      ref: 'User'
    }, minimize: false)

	conn.model 'TaskResult', taskResultSchema, 'task_results'
