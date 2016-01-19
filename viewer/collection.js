Tasks = new Meteor.Collection("Tasks");

/*
Meteor.methods({
	"insertBeer": function(numBeers, date) {
		numBeers = parseInt(numBeers);

		check(numBeers, Number);
		check(date, Date);

		return Beers.insert({beers: numBeers, date: date});
	},

	"removeBeer": function(id) {
		check(id, String);
		return Beers.remove(id);
	}
})
*/
