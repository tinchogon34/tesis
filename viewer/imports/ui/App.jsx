import React, { Component, PropTypes } from 'react';
import { createContainer } from 'meteor/react-meteor-data';
 
import { Tasks } from '../api/tasks.js';
 
import BarChart from './BarChart.jsx';
 
// App component - represents the whole app
class App extends Component { 
  mapResultsData(task){
    if(!task.slices || !task.map_results) return []
		var res = []
		for(var i=0;i < task.slices;i++){
			res.push({xLabel: i, value: 0, finished: task.finished})
		}
		for(var k in task.map_results){
			if(res[k]){
				res[k].value = task.map_results[k]
			}
			else{
				res.push({xLabel: k, value: task.map_results[k], finished: task.finished})
			}

		}
		return res;
	}

	reduceDataData(task){
		if(!task.reduce_data) return []
		var res = []
		var data = _.sortBy(_.pairs(task.reduce_data),function(el){return -el[1]})
		for(var k in data){
			res.push({xLabel: data[k][0], value: data[k][1], finished: task.finished})
			if(res.length == 10){
				break
			}
		}
		return res;
	}

	reduceResultsData(task){
		if(!task.reduce_results) return []
		var res = []
		var data = _.sortBy(_.pairs(task.reduce_results),function(el){return -el[1].length})		
		for(var k in data){
			res.push({xLabel: data[k][0], value: data[k][1].length, finished: task.finished})
				if(res.length == 10){
					break
				}
		}
		return res;
	}

	resultsData(task){
		if(!task.results) return []
		var res = []
		var data = _.sortBy(_.pairs(task.results),function(el){return -el[1][0]})
		for(var k in data){
			res.push({xLabel: data[k][0], value: data[k][1][0], finished: task.finished})
			if(res.length == 10){
				break
			}
		}
		return res;
	}

  renderTasks() {
    return this.props.tasks.map((task) => {
			return (
				<div className="row" key={task._id.toString()}>
					<div className="col-md-12">
						<center>
							{task._id.toString()}
						</center>
						<div className="row">
						<div className="col-md-6">
							<center>
								<h3>Resultados del Map (Cliente)</h3>
								<BarChart data={this.mapResultsData(task)}/>
							</center>
						</div>
						<div className="col-md-6">
							<center>
								<h3>Resultados del Map Procesado</h3>
								<BarChart data={this.reduceDataData(task)}/>
							</center>
						</div>
					</div>
					<div className="row">
					<div className="col-md-6">
						<center>
							<h3>Resultados del Reduce (Cliente)</h3>
							<BarChart data={this.reduceResultsData(task)}/>
						</center>
					</div>
					<div className="col-md-6">
						<center>
							<h3>Resultados del Reduce Procesado</h3>
							<BarChart data={this.resultsData(task)}/>
						</center>
					</div>
				</div>
						<hr />
					</div>
				</div>
			);
		});
  }
 
  render() {
		return (
			<div>
				<div className="page-header">
					<center>
						<h1>
							<i className="fa fa-beer"></i> Tesis
              <small> Dashboard</small>
            </h1>
          </center>
        </div>
        <div className="container-fluid">
          {this.renderTasks()}
        </div>
      </div>
    );
  }
}

App.propTypes = {
  tasks: PropTypes.array.isRequired,
};
 
export default createContainer(() => {
  return {
    tasks: Tasks.find({}).fetch(),
  };
}, App);
