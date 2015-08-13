derby = require 'derby'

app = module.exports = derby.createApp 'app', __filename

app.use require 'derby-router'
app.use require 'derby-debug'
app.serverUse module, 'derby-jade', coffee:true
app.serverUse module, 'derby-stylus'

app.loadViews __dirname + '/views'
app.loadStyles __dirname + '/styles'

app.post '/create_game', (page, model, params) ->
	model.add 'games', { 
		players: {}
		userIds: []
		tableCollums: [] # +1 when userAnswerCounts = 3
		userAnswerCounts: 0 # 3 and next round
		prices: []
	},->
		page.redirect '/'

app.get '/', (page, model) ->
	gamesQuery = model.query 'games', {} # get games from db
	userId = model.get '_session.userId' # current user
	model.subscribe gamesQuery, 'users.' + userId, ->
		model.ref '_page.games', gamesQuery
		model.ref '_page.user', 'users.' + userId

		page.render 'home'

app.get '/game/:gameId', (page, model, params) ->
	model.subscribe 'games.' + params.gameId, ->
		usersInGame = model.query 'users', 'games.' + params.gameId + 
		            '.userIds'
		userId = model.get '_session.userId'

		model.subscribe usersInGame, 'users' + userId, ->
			# для того что снизу
			model.ref '_page.user', 'users.' + userId # for prof
			model.ref '_page.game', 'games.' + params.gameId
			model.ref '_page.players', 'games.' + params.gameId + '.players'
			model.ref '_page.player', 'games.' + params.gameId +
								'.players.' + userId

			model.ref '_page.users', 'users'

			unless model.get '_page.player' # <-- ref для этого был сверху
					model.add '_page.players', { id: userId } # без этого при обновлении +1чел. добавляется в бд
					model.push '_page.game.userIds', userId # <--

			page.render 'game'

app.proto.setUserName = ->
	userId = @model.get '_session.userId'
	userName = @model.get '_page.userName'

	if userName?
		userName = userName.trim() # delete spaces
	if userName
		@model.set 'users.' + userId + '.userName', userName # set in db
		@model.del '_page.userName'
	else
		alert 'Name cannot be empty!'


app.proto.deleteGame = (gameId) ->
	@model.del 'games.' + gameId

###############
# Game.jade
###############

app.proto.startGame = (userId) -> 
	userName = @model.get '_page.users.' + userId + '.userName'
	@model.set '_page.players.' + userId, 
		userName: userName
		answer: []
		profits: []
		sumProfits: 0
		isReady: true
		prof: false

app.proto.nextRound = (answer) ->
	if !answer
		alert "field must be not empty"
		return

	@model.set '_page.userAnswer', ''

	userId = @model.get '_session.userId'
	userAnswerCounts = @model.get '_page.game.userAnswerCounts'

	userAnswerCounts++

	@model.push '_page.players.' + userId + '.answer', answer
	@model.set '_page.game.userAnswerCounts', userAnswerCounts

	userIds = @model.get '_page.game.userIds'
	players = @model.get '_page.game.players'

	if userAnswerCounts == 3
		@model.push '_page.game.tableCollums', 1
		@model.set '_page.game.userAnswerCounts', 0

		# set price
		answers = 0
		for player in userIds
			if players?[player].prof == false # prof = undefined
				answers += parseInt(players[player].answer[players[player].answer.length - 1])

		price = 45 - 0.2 * (answers)	
		@model.push '_page.game.prices', price

		# set profit and sumProfits
		for player in userIds
			if players?[player].prof == false
				profit = parseInt(players[player].answer[players[player].answer.length - 1]) *	(price - 5)
				@model.push '_page.players.' + player + '.profits', profit

			sumProfits = (@model.get '_page.players.' + player + '.sumProfits') + profit
			@model.set '_page.players.' + player + '.sumProfits', sumProfits

	console.log(@model.get '_page')

app.proto.profNextRound = ->
	userIds = @model.get '_page.game.userIds'
	players = @model.get '_page.game.players'
	tableCollums = @model.get '_page.game.tableCollums'

	for player in userIds
		if players?[player].prof == false
			if players[player].answer.length == tableCollums.length
				@model.push '_page.players.' + player + '.answer', 0

	@model.push '_page.game.tableCollums', 1
	@model.set '_page.game.userAnswerCounts', 0

	# set price
	answers = 0
	for player in userIds
		if players?[player].prof == false 
			answers += parseInt(players[player].answer[players[player].answer.length - 1])

	price = 45 - 0.2 * (answers)	
	@model.push '_page.game.prices', price

	# set profit and sumProfits
	for player in userIds
		if players?[player].prof == false
			profit = parseInt(players[player].answer[players[player].answer.length - 1]) *	(price - 5)
			@model.push '_page.players.' + player + '.profits', profit

		sumProfits = (@model.get '_page.players.' + player + '.sumProfits') + profit
		@model.set 

	console.log(@model.get '_page')