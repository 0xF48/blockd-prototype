PORT = 3330
log = console.log.bind console
require 'colors'
express = require 'express'


uuid = ->
	text = ""
	possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	for i in [0...8]
		text += possible.charAt(Math.floor(Math.random() * possible.length))

	return text


bodyParser = require 'body-parser'
_ = require 'lodash'
path = require 'path'
fs = require 'fs'
sharedsession = require("express-socket.io-session")
randomColor = require('random-color')
Color = require 'color'

app = express()

session = require("express-session")
    secret: "fuck-cats",
    resave: true,
    saveUninitialized: true








class Cooldown
	constructor: (@max_time)->
		@t = null
		@beta = 1
		@time_left = null
	
	reset: (time,max_time)->
		if max_time
			@max_time = max_time
		@t = time + @max_time
		@beta = 1
		@time_left = @max_time

	ok: ()->
		@beta == 0

	setMax: (@max_time)->
		return
		
	tick: (time)->
		if @beta == @time_left <= 0
			return

		if !@t
			return @reset(time)
	
		if time >= @t
			@beta = 0
			@time_left = 0
		else
			@time_left = @t - time
			@beta = @time_left/@max_time

	



_time = Date.now()



tick = ()->
	_time = Date.now()
	for game in games
		game.tick()
	


GRID_DIR = [
	[0,-1]
	[-1,0]
	[0,1]
	[1,0]
]

ringLoop = (x,y,radius,cb)->
	rx = x + radius
	ry = y + radius
	for i in [0...4]
		for j in [0...radius*2]
			if !cb(rx,ry)
				return false
			rx += GRID_DIR[i][0]
			ry += GRID_DIR[i][1]
	return true

squareLoop = (x,y,radius,cb)->
	if !cb(x,y)
		return false
	for i in [1..radius]
		if !ringLoop(x,y,i,cb)
			return false

intersects = (ax1,ay1,ax2,ay2,bx1,by1,bx2,by2)->
	if ax2 < bx1 || ax1 > bx2 || ay2 < by1 || ay1 > by2
		return false
	else
		return true




class Game
	constructor: (opt)->
		@id = opt.id || uuid()
		@sizeX = opt.sizeX
		@sizeY = opt.sizeY
		
		
		@grid = @makeGrid(@sizeX,@sizeY)
		@units_buffer = []
		@start_time = 0
		@total_turns = 1
		@type = opt.type


		@units = []
		@units_map = {}
		@stamp = 0
		@players = []
		@dead_players = []
		@alive_players = []
		@turn_player = null
		@map_type = opt.map_type || 1
		switch @map_type
			when 1 then @mapType1()
			when 2 then @mapType2()
			when 3 then @mapType3()

		@started = false
		@ended = false

		log "created a new game size:[#{@sizeX},#{@sizeY}] id:#{@id} type:#{@map_type}".cyan

	setUnitType: (unit_id,type,player)->

		type = _.clamp(Number(type),0,2)
		unit = @units_map[unit_id]
		if !unit
			throw new Error 'bad unit'
		if unit.player != player
			throw new Error 'bad player'
		# if !unit.actions
		# 	throw new Error 'cant move'

		# dice_needed = 1
		# if type == 3
		# 	dice_needed = 4

		# if unit.dice < dice_needed
		# 	throw new Error 'not enough dice'

		# unit.dice -= dice_needed
		unit.type = type
		if unit.linked_unit
			unit.linked_unit.linked_unit = null
			unit.linked_unit = null
		unit.actions = 0
		@needs_update = true


	removeUnit: (unit)->
		@units.splice @units.indexOf(unit),1
		delete @units_map[unit.id]
		@needs_update = true

		for x in [unit.x...unit.x+unit.w]
			for y in [unit.y...unit.y+unit.h]
				@grid[x][y] = -1


	addUnit: (unit)->
		@units_map[unit.id] = unit
		@units.push unit
		unit.grid = this
		@needs_update = true

		for x in [unit.x...unit.x+unit.w]
			for y in [unit.y...unit.y+unit.h]
				if @grid[x][y] != -1
					log x,y,@grid[x][y].id
					throw new Error 'update grid failed!!'
				@grid[x][y] = unit

		# # link energy units created adjacent to each other, but only once
		# if unit.type == 0 && !unit.linked_unit
		# 	@getNeighbors unit,(n)->
		# 		if n.type == 0 && n.player == unit.player && !n.linked_unit
		# 			return unit.linkUnit(n)


	updateGrid: ->
		@grid = @makeGrid(@sizeX,@sizeY)
		for unit in @units
			unit.link_adjacent = false
			for x in [unit.x...unit.x+unit.w]
				for y in [unit.y...unit.y+unit.h]
					if @grid[x][y] != -1
						log x,y,@grid[x][y].id
						throw new Error 'update grid failed!!'
					@grid[x][y] = unit

		for unit in @units
			if unit.link_adjacent
				continue
			for dir in GRID_DIR
				n = @grid[unit.x+dir[0]]?[unit.y+dir[1]]
				if n && n != -1
					if n.linked_unit == unit
						unit.link_adjacent = true
						n.link_adjacent = true
						break

	attackPlayerUnit: (u_id,n_id)->
		u = @units_map[u_id]
		n = @units_map[n_id]
		if !u || !n
			throw new Error 'cant attack, bad unit'

		if !u.player || !n.player || u.player == n.player
			throw new Error 'cant attack, bad player'

		if !n.neighbors_map[u_id] || !u.neighbors_map[n_id]
			throw new Error 'cant attack, not neighbors'

		u.attack(n)

	




	movePlayerUnit: (state,player)->
		id = state.id
		x = Number(state.x)
		y = Number(state.y)
		
		
		unit = @units_map[id]
		if unit.player != player
			throw new Errpr 'cant move unit, bad player'
		if !unit.actions
			throw new Error 'cant move unit, no action points'


		if x < unit.x
			x = unit.x - 1
			y = unit.y
		
		if x >= unit.x+unit.w
			x = unit.x + 1
			y = unit.y

		if y < unit.y
			x = unit.x
			y = unit.y - 1
		
		if y >= unit.y+unit.h
			x = unit.x
			y = unit.y + 1

	
		

		for ux in [0...unit.w]
			for uy in [0...unit.h]
				if @grid[x+ux]?[y+uy] != -1 && @grid[x+ux][y+uy] != unit
					if @grid[x+ux][y+uy] && @grid[x+ux][y+uy].player == unit.player
						@needs_update = true
						return unit.moveDice(@grid[x+ux][y+uy])

					else
						throw new Error 'cant move unit, taken'
	

		for ux in [0...unit.w]
			for uy in [0...unit.h]
				@grid[unit.x+ux][unit.y+uy] = -1
		
		for ux in [0...unit.w]
			for uy in [0...unit.h]
				@grid[x+ux][y+uy] = unit

		unit.setPos(x,y)
		unit.actions = 0
		
		
		@needs_update = true



	placePlayerUnit: (place_unit,player)->
		place_unit.type = _.clamp(Number(place_unit.type),0,3)
		place_unit.x = Number(place_unit.x)
		place_unit.y = Number(place_unit.y)

		if place_unit.x < 0 || place_unit.x > @sizeX
			throw new Error 'cant place unit, bounds'
		if place_unit.y < 0 || place_unit.y > @sizeY
			throw new Error 'cant place unit, bounds'

	

		
		h_count = 0
		h_dice = 0
		h_units = []
			
		for u in player.units
			if u.type == 3 && Math.abs(u.x - place_unit.x) < 2 && Math.abs(u.y - place_unit.y) < 2
				h_count++
				h_dice += u.dice
				h_units.push u

		need_dice = 0
		if place_unit.type == 3
			need_dice = 4
		else
			need_dice = 1



		if !h_count
			throw new Error 'cant place unit, home unit bounds'		


		if h_dice < need_dice
			throw new Error 'cant place unit, home unit not enough dice'


		if @grid[place_unit.x]?[place_unit.y] != -1
			throw new Error 'cant place unit, taken'

		
	

		for u in h_units
			if u.dice >= need_dice
				u.dice -= need_dice
				need_dice = 0
			else 
				u.dice = 0
				need_dice -= u.dice 

		unit = new Unit
			dice: h_count - 1
			type: place_unit.type
			x: place_unit.x
			y: place_unit.y
			player: player


		player.addUnit(unit)
		

	getNeighbors: (unit,cb)->
		for y in [0...unit.h]
			# left neigh
			if @grid[unit.x-1] && @grid[unit.x-1][unit.y+y]? && @grid[unit.x-1][unit.y+y] != -1
				cb(@grid[unit.x-1][unit.y+y])

			# right neih
			if @grid[unit.x+unit.w] && @grid[unit.x+unit.w][unit.y+y] && @grid[unit.x+unit.w][unit.y+y] != -1
				cb(@grid[unit.x+unit.w][unit.y+y])
		

		for x in [0...unit.w]
			# top neigh
			if @grid[unit.x+x] && @grid[unit.x+x][unit.y-1]? && @grid[unit.x+x][unit.y-1] != -1
				cb(@grid[unit.x+x][unit.y-1])

			# bot neih
			if @grid[unit.x+x] && @grid[unit.x+x][unit.y+unit.h]? && @grid[unit.x+x][unit.y+unit.h] != -1
				cb(@grid[unit.x+x][unit.y+unit.h])

	calculateUnitNeighbors: ()=>
		for unit in @units
			unit.resetNeighbors()
			@getNeighbors unit,(n)->
				unit.addNeighbor(n)



	tick: ()=>
		if @ended && @needs_update
			@needs_update = false
			@emitState()
			return



		for player in @players
			player.tick()

		if @needs_update
			@needs_update = false
			@emitUpdate()

	

	nextTurn: ()->
		@total_turns++
		@turn_index++
		if @turn_index >= @alive_players.length
			@turn_index = 0
		@needs_update = true
		@alive_players[@turn_index].startTurn()



	emitUpdate: ()->
		@calculateUnitNeighbors()
		@updateGrid()
		@serializeUnits()
		@emitState()	
	

	getState: ()->
		players: @players.map (player)->
			player.getState()
		turn_player_i: @players.indexOf(@turn_player)
		max_players: @max_players
		map_type: @map_type
		sizeY: @sizeY
		sizeX: @sizeX
		id: @id
		stamp: @stamp
		ended: @ended
		started: @started
		total_turns: @total_turns
		turn_end_time: @turn_end_time
		start_time: @start_time
		units: @units_buffer
		stats: @getStats()


	getStats: ()->
		if !@ended
			return null
		
		total_time: @end_time - @start_time
		total_turns: @total_turns / @players.length
		alive_players: @alive_players.map (player)->
			player.getState()
		dead_players: @dead_players.map (player)->
			player.getState()
		


	emitStats: ()->
		for player in @player
			player.instance.emit 'game_stats',

	killPlayer: (player)->
		# @players.splice(@players.indexOf(player),1)
		player.dead = true
		@alive_players.splice(@alive_players.indexOf(player),1)
		@dead_players.push player
		for unit in player.units
			@removeUnit(unit)
		# player.game = null
		if @alive_players.length == 1 && !@ended
			@end()
		else 
			t = null
			for player in @players
				if t == null
					t = player.team_id
				if player.team != t
					t = null
					break

			if t != null
				@end()

		@needs_update = true


	removePlayer: (player)->
		@players.splice(@players.indexOf(player),1)
		player.game = null
		player.reset()
		player.emitState()
		if @players.length == 0
			removeGame(@)
		@needs_update = true
	
	addPlayer: (player)->
		if @started
			throw new Error 'game already started'
		if @players.length == @max_players
			throw new Error 'game has reached max players'
		if @players.indexOf(player) >= 0
			throw new Error 'you are already in this game'
		if player.game
			throw new Error 'you are already in a game'
		@players.push player
		
		player.game = this
		# @start()
		@emitState()

		

	

	serializeUnits: ()->
		@stamp = _time
		@units_buffer = []
		for u,i in @units
			@units_buffer[i] = u.getState()
		

	findFreeHomeUnitSpot: (x,y)->
		# log 'FINDFREE HOME UNTI SPOT',x,y
		radius = @sizeY > @sizeX && Math.floor(@sizeY/2) || Math.floor(@sizeX/2)
		taken = 0
		pcx = null
		pcy = null

		spot = @findFreeSpot x,y,3,3,radius,(fx,fy,cx,cy)=>
			if @grid[cx+1]?[cy+1] != -1
				return false
			# log 'compare',fx,fy
			if cx != pcx || cy != pcy
				taken = 0
			pcx = cx
			pcy = cy

			# do not intersect with other home units.
			if @grid[fx] && @grid[fx][fy]? && @grid[fx][fy].type == 3
				# log 'false (type == 3)'
				return false

			# free spot, we are good
			if @grid[fx]? && @grid[fx][fy] == -1
				# log 'true (free)'
				return true
			


			taken++
			if taken == 4
				taken = 0
				# log 'false (taken max)'
				return false

			# log 'true (base)'
			return true

		log 'found home unit spot',spot
		if spot[0] != null && spot[0] != null
			spot[0] += 1
			spot[1] += 1
		
		return spot

			



	findFreeSpot: (x,y,w,h,radius,compare)->
		found_x = null
		found_y = null
		squareLoop x,y,radius,(fx,fy)->
			ok = true
			for c in [0...w]
				for r in [0...h]
					if !compare(fx+c,fy+r,fx,fy)
						ok = false
						found_x = null
						found_y = null
						return true

			if ok
				found_x = fx
				found_y = fy
				return false

		log 'found free spot',found_x,found_y

		return [found_x,found_y]

	


	emitUnits: ->
		for unit in @units
			@emit 'units',unit.getJson()

	setTurn: (player)->
		player.startTurn()

	pickRandomPlayer: ->
		@alive_players[Math.floor(Math.random()*@alive_players.length)]
	


	start: ()->
		log 'start game',@id
		@start_time = _time

		@alive_players = @players.slice()



		if @map_type == 1
			@SpawnMapType1()

		first_turn_player = @pickRandomPlayer()
		first_turn_player.startTurn()

		@started = true
		@needs_update = true

	end: ()->
		log 'END GAME'
		@ended = true
		@end_time = _time
		for player in @players
			player.reset()
		@needs_update = true
		@units = []
		@grid = []


	makeGrid: (w,h)->
		grid = []
		for x in [0...w]
			grid[x] = []
			for y in [0...h]
				grid[x][y] = -1
				

		return grid

	emitState: ()->
		for player in @players
			player.emitState()


	compareEmpty: (fx,fy,cx,cy)=>
		# free spot, we are good
		if @grid[fx]? && @grid[fx][fy] == -1
			return true
		return false



	mapType1: ()->
		my = Math.floor(@sizeY/2)
		mx = Math.floor(@sizeX/2)

		l = (@sizeX*@sizeY)/12
		for i in [0...l]
			r_x = Math.floor(Math.random()*@sizeX)
			r_y = Math.floor(Math.random()*@sizeY)
			r_w = Math.floor(1+Math.random()*1.5)
			r_h = Math.floor(1+Math.random()*1.5)
			spot = @findFreeSpot(r_x,r_y,r_w,r_h,2,@compareEmpty)
			if spot[0]? && spot[1]?
				resource = new ResourceUnit
					x: spot[0]
					y: spot[1]
					w: r_w
					h: r_h
				@addUnit(resource)



	SpawnMapType1: ()->
		total_units = @sizeX*@sizeY/2
		for player,i in @alive_players
			for [0...total_units/@alive_players.length]
				h_unit = new Unit
					type: Math.floor(0+Math.random()*3)
					dice: Math.floor(0+Math.random()*8)
					actions: 1
					w: 1
					h: 1
					player: player
				h_x = Math.floor(Math.random()*@sizeX)
				h_y = Math.floor(Math.random()*@sizeY)
				pos = @findFreeSpot(h_x,h_y,1,1,4,@compareEmpty)
				if pos[0]? && pos[1]?
					h_unit.setPos(pos[0],pos[1])
					player.addUnit(h_unit)
				else
					console.log pos,'failed to spawn unit'
			






class Unit
	constructor: (opt)->
		@id = uuid()
		@w = 1
		@h = 1
		@x = opt.x
		@y = opt.y
		@next_x = @x
		@next_y = @y
		@type = opt.type #  0:resource,  1:attack,  2:def,  3:home, 4: resource
		@link_adjacent = false
		@dice = opt.dice || 0
		@actions = opt.actions || 0
		@max_actions = 4
		@max_dice = 8
		@linked_unit = opt.linked_unit
		@player = opt.player || null
		@neighbors_map = {}
		@neighbors = []
		

	resetNeighbors: ->
		# @neighbor_ids = []
		@neighbors = []
		@neighbors_map = {}

	addNeighbor: (unit)->
		if !@neighbors_map[unit.id]
			# @neighbor_ids.push unit.id
			@neighbors.push unit
			@neighbors_map[unit.id] = unit

	moveDice: (unit)->
		if !@dice
			throw new Error 'cant move dice, no dice.'

		rem = (unit.dice + @dice) - unit.max_dice
		if rem > 0
			@dice = rem
			unit.dice = unit.max_dice
		else
			unit.dice += @dice
			@dice = 0
		@actions--

	unlink: ()->
		if @linked_unit
			@linked_unit.linked_unit = null
		@linked_unit = null

	link: (unit)->
		if unit == @linked_unit
			throw new Error 'cant link, same unit is already linked.'
		if @linked_unit
			@linked_unit.unlink()
		unit.unlink()
		if @actions == 0 || unit.actions == 0
			throw new Error 'cant link, not enough action points.'
		if unit.type != @.type
			throw new Error 'cant link, types not the same.'


		@actions -= 1
		@linked_unit = unit
		@linked_unit.actions -= 1
		@linked_unit.linked_unit = @




	refillDice: ()->
		@dice += 1
	
	equalizeDice: (unit)->
		while @dice && @dice > unit.dice && unit.dice < unit.max_dice
			unit.dice += 1
			@dice -= 1
			
	addOneDice: (ret)->
		if @dice == @max_dice
			if !ret && @linked_unit && @link_adjacent
				@linked_unit.addOneDice(true)
			else
				return false
		else
			@dice++
			return true
	removeOneDice: (ret)->
		if @dice > 0
			@dice -= 1
			return true
		else if !ret && @linked_unit && @link_adjacent
			return @linked_unit.removeOneDice(true)
		else
			return false

	giveDice: (unit)->

		while @removeOneDice()
			if !unit.addOneDice()
				@addOneDice()
				return
		

	getState: =>
		x: @x
		y: @y
		w: @w
		h: @h
		next_x: @next_x
		next_y: @next_y
		type: @type
		dice: @dice
		id: @id
		linked_unit_id: @linked_unit && @linked_unit.id
		link_adjacent: @link_adjacent
		actions: @actions
		player_id: @player && @player.id

	setPos: (@x,@y)->
		@next_x = @x
		@next_y = @y

	movePos: (x,y)->
		@next_x = x
		@next_y = y		

	# each dice has 6 sides, roll the dice based on how many dice unit has.
	_roll: ()->
		total = 0
		for i in [0...@dice]
			total += 1+Math.floor(Math.random()*6)
		return total

	# public roll method, roll depends on unit type.
	roll: (attacker)->

		if !attacker && @type == 2
			v = @_roll()*3
		else if attacker && @type == 1
			v = @_roll()*2
		else
			v = @_roll()

		
		if @linked_unit && @link_adjacent
			v += @linked_unit._roll()
		
		return v		

	attack: (unit)->
		if !@actions
			throw new Error 'cant attack, !can_move'
		
		if @type == 2
			throw new Error 'defensive units cant attack other units.'
		
		if @dice == 0
			throw new Error 'empties cant attack'


		vA = unit.roll(false)
		vB = @roll(true)
		if @linked_unit && @link_adjacent
			vB += @linked_unit._roll()

		
		log 'roll attacker:',vB,' - defender:',vA
		if vB > vA
			if unit.linked_unit
				unit.linked_unit.dice = 0
			unit.dice = @dice-1
			@dice = 0
			unit.player.units.splice(unit.player.units.indexOf(unit),1)
			unit.player = @player
			unit.unlink()
			@player.units.push unit
		else
			@dice = 0
	
		@grid.needs_update = true
			
		


class ResourceUnit extends Unit
	constructor: (opt)->
		super(opt)
		@type = 4




DECK = [
	[1,1]
	[1,1]
	[1,2]
	[2,1]
]

class Player
	constructor: (opt)->
		@name = opt.name || 'Player '+(players.length+1)
		@instance = opt.instance
		@id = @instance.id
		@cards = []
		@max_cards = 3
		@units = []
		@team_id = 0
		@turn_time = 120000

		@color = randomColor(0.7,0.99).values.rgb
		
	

		
		players.push @
		players_map[@id] = @

		@bindSocket(opt.socket)
		@turn_cooldown = new Cooldown(@turn_time)



	tickTurnDice: ()->
		# generate
		for unit in @units
			if unit.actions < unit.max_actions
				unit.actions += 1

			if unit.type == 0
				unit.addOneDice()
			
			
		# 	for n in unit.neighbors
		# 		if n.type == 4 
		# 			unit.addOneDice()

		# # resupply
		# for unit in @units
		# 	if unit.type == 0
		# 		for n in unit.neighbors
		# 			if (n.type == 1 || n.type == 2 || n.type == 3) && n.player == unit.player
		# 				unit.giveDice(n)

		# @equalizeUnits()

	# equalizeUnits: ()->
	# 	# equalize
	# 	for unit in @units
	# 		if unit.type == 0

	# 			if unit.linked_unit
	# 				if unit.dice > unit.linked_unit.dice
						
	# 					unit.equalizeDice(unit.linked_unit)

	# 			for n in unit.neighbors
	# 				if unit.type == n.type && n.player == unit.player
	# 					if unit.dice > n.dice
							
	# 						unit.equalizeDice(n)
						


	reset: ()->
		@units = []
		


	die: ()->
		@game.killPlayer(@)


	removeUnit: (unit)->
		@units.splice(@units.indexOf(unit),1)
		unit.player = null
		@game.removeUnit unit
		if unit.type == 3
			@die()

	addUnit: (unit)->
		@units.push unit
		unit.player = this
		@game.addUnit unit
	tick: ()->

		@turn_cooldown.tick(_time)
		
		if @turn_cooldown.beta == 0 && @turn_active
			@endTurn()
		
	

	

	startTurn: ()->

		
		@game.turn_player = this
		@game.turn_index = @game.players.indexOf(@)
		@turn_active = true

		@turn_end_time = _time + @turn_time
		@game.turn_end_time = @turn_end_time
		@turn_cooldown.reset(_time)

	endTurn: ()->
		if @ended
			return
		@turn_active = false
		@tickTurnDice()

		@game.nextTurn()

	joinGame: (id)=>
		if !games_map[id]
			return @instance.emitErr('game does not exist')
		else
			try 
				games_map[id].addPlayer(@)
			catch e
				@instance.emitErr(e.message)
				@instance.emitState()

	createGame: (state)=>
		game = createGame new Game
			sizeX: _.clamp(Number(state.sizeX),8,100)
			sizeY: _.clamp(Number(state.sizeY),8,100)
			type: _.clamp(Number(state.type),1,3)
		game.addPlayer(@)


	gameStart: =>
		if @game.started
			return @instance.emitErr('game is already started? :<')
		@game.start()

	# set game settings
	gameSet: (state)=>
		if state.player_team && state.player_team[0]? && state.player_team[1]?
			if !@game
				return @instance.emitErr('you are not in a game? :<')
			if @game.players[0] != @
				return @instance.emitErr('you are not the game creator? :<')
			player = players_map[state.player_team[0]]
			if !player
				return @instance.emitErr('player not found. :<')
			else if player.game != @game
				return @instance.emitErr('player not in your game. :<')
			team_id = _.clamp Number(state.player_team[1]),0,4
			player.team_id = team_id
			@game.emitState()
	


		# x = place_unit(place_unit.x)


		# 	if state.place_unit.x

		# 	if state.place_unit.y

		# 		state.place_unit.card && state.place_unit.type


		# log 'GAME PUT'



	gamePut: (state)=>
		if !@turn_active
			throw new Error 'not your turn :<'

		

		if state.unit_type
			@game.setUnitType(state.unit_type.id,state.unit_type.type,@)

		else if state.attack_unit
			@game.attackPlayerUnit(state.attack_unit.u_id,state.attack_unit.n_id)
		else if state.move_unit
			@game.movePlayerUnit(state.move_unit,@)

		else if state.place_unit
			
			@game.placePlayerUnit(state.place_unit,@)

		if state.end_turn
			@endTurn()


	catchEvent: (fn)=>
		return (state)=>
			try
				fn(state)
			catch e
				@instance.emitErr(e.message)

	bindSocket: (s)->
		@socket = s
		s.on 'create',@catchEvent(@createGame)
		s.on 'join',@catchEvent(@joinGame)
		s.on 'game_set',@catchEvent(@gameSet)
		s.on 'game_start',@catchEvent(@gameStart)
		s.on 'game_put',@catchEvent(@gamePut)
		s.on 'leave',=>
			if @game
				@game.removePlayer(@)


	emitState: ()->
		@instance.emitState()

	getState: ()->
		id: @id
		name: @name
		cards: @cards
		team_id: @team_id
		color: @color
		turn_end_time: @turn_end_time
		


class Instance
	constructor: (socket)->
		log 'new instance'
		@id = uuid()
		@socket = socket
		@session = @socket.handshake.session
		@session.instance_id = @id
		@session.save()
		@player = new Player
			instance: @
			socket: @socket
			name: null
	
	getState: ()->
		player: @player.getState()
		game: @player.game && @player.game.getState()


	emitState: ()->
		@socket.emit 'state',@getState()

	emitErr: (msg)->
		@socket.emit 'err',msg
	
	reconnect: (@socket)->
		log 'reconnect instance'
		@player.bindSocket(@socket)


		








instances_map = []
instances = []
players = []
players_map = {}
games_map = {}
games = []


removeGame = (game)->
	delete games_map[game.id]
	games.splice(games.indexOf(game),1)

createGame = (game)->
	games_map[game.id] = game
	games.push game
	return game


createGame new Game
	sizeX: 8
	sizeY: 8
	id: 'dev'



printStats = ->
	log games.length+" games | "+players.length+" players | "+instances.length+" instances"







setInterval printStats,60000




















app
.set 'view engine','pug'
.set 'views','./client-views'
.use('/static', express.static './client-static')
.use bodyParser.json()
.use bodyParser.urlencoded extended:no
.use(session)


http = require('http').Server(app)
io = require('socket.io')(http)


io.use sharedsession session,
    autoSave:true








app.get '/', (req,res)->
	res.render 'index'





# global 404 view
app.get '*', (req,res,next)->
	res.status(404).send ':v'


# global error view
.use (err, req, res, next)->
	if err.message.match('duplicate key error index')
		return res.json
			error: 'oops, duplicate found'
	res.json
		error: err.message
	throw err

io.on 'connection', (socket)->
	inst_id = socket.handshake.session.instance_id
	inst = instances_map[inst_id]

	if inst
		inst.reconnect(socket)
	else
		inst = new Instance socket
	instances_map[inst.id] = inst
	instances.push inst

	

http.listen PORT,()->
	log '-- blokd -- '.cyan
	log ('port: '+PORT).bold



setInterval tick,33