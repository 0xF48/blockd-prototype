require './style.scss'
{render,h,Component} = require 'preact'
cn = require 'classnames'
_ = require 'lodash'
DIM = 30
DIM2 = 60
UPAD = 2
log = console.log.bind(console)
io = require 'socket.io-client'

GRID_DIR = [
	[0,-1]
	[-1,0]
	[0,1]
	[1,0]
]

msToTime = (duration)->
	milliseconds = parseInt((duration%1000)/100)
	seconds = parseInt((duration/1000)%60)
	minutes = parseInt((duration/(1000*60))%60)
	hours = parseInt((duration/(1000*60*60))%24)

	hours = if (hours < 10) then "0" + hours else hours;
	minutes = if (minutes < 10) then "0" + minutes else minutes;
	seconds = if (seconds < 10) then "0" + seconds else seconds;
	
	return hours + ":" + minutes + ":" + seconds;
    

intersects = (ax1,ay1,ax2,ay2,bx1,by1,bx2,by2)->
	if ax2 < bx1 || ax1 > bx2 || ay2 < by1 || ay1 > by2
		return false
	else
		return true

rgba = (rgb,a,l)=>
	a = a || 1
	l = l || 0
	r = Math.floor(rgb[0]+(255-rgb[0])*l) 
	g = Math.floor(rgb[1]+(255-rgb[1])*l)
	b = Math.floor(rgb[2]+(255-rgb[2])*l)
	return "rgba(#{r},#{g},#{b},#{a})"

lineToPoly = (ctx,x,y,l,r)->
	for i in [0...l]
		a = -Math.PI/2+Math.PI*2/l*i
		if i == 0
			ctx.moveTo(x+Math.cos(a)*r,y+Math.sin(a)*r)
		else
			ctx.lineTo(x+Math.cos(a)*r,y+Math.sin(a)*r)


class Game
	constructor: (el)->
		if !state.game
			throw new Error 'state game is undefined'
		
		@el = el
		@ctx = @el.getContext('2d')
		@sizeX = state.game.sizeX
		@sizeY = state.game.sizeY
		@resize()

		window.addEventListener 'resize',@resize
		window.addEventListener 'keydown',@onKeyDown
		window.addEventListener 'keyup',@onKeyUp
		window.addEventListener 'mousemove',@onMouseMove
		window.addEventListener 'click',@onClick


		@updateGrid()
		
		
		@stamp = 0
		@viewX = 0
		@viewY = 0
		@unitX = 0
		@unitY = 0
		@mouseX = 0
		@mouseY = 0
		@panX = 0
		@panY = 0
		@state = 
			panX: 0
			panY: 0

		@resource_color = [255,255,255]
		@placeholder_unit_color = [255,255,255]
		@placeholder_unit_ok = false
		@placeholder_unit = 
			w: 0
			h: 0
			x: 0
			y: 0
			type: 0
			dice: 0

		@tick()

	resize: =>
		
		@width = @el.clientWidth
		@height = @el.clientHeight
		@el.width = @width
		@el.height = @height
		@ctx.width = @width
		@ctx.height = @height

	onMouseMove: (e)=>
		@mouseX = (e.clientX - (@width / 2-( DIM2 * @sizeX / 2 )) - @viewX)
		@mouseY = (e.clientY - (@height / 2-( DIM2 * @sizeY / 2 )) - @viewY)
		@unitX = _.clamp(Math.floor(@mouseX/DIM2),0,@sizeX-1)
		@unitY = _.clamp(Math.floor(@mouseY/DIM2),0,@sizeY-1)

		if @mouseX > @sizeX*DIM2 || @mouseX < 0 || @mouseY > @sizeY*DIM2 || @mouseY < 0
			@mouse_in_bounds = false
		else
			@mouse_in_bounds = true
	
	onClick: ()=>
		if @selected_unit_move && @selected_unit_type?
			selectUnitType(@selected_unit,@selected_unit_type)
			@selected_unit_type = null
			@selected_unit = null
			@selected_unit_move = null
			return		

		if state.game.turn_player.id != state.player.id
			@selected_unit_type = null
			@selected_unit = null
			@selected_unit_move = null
			return


		updateView()
		if !@mouse_in_bounds
			return


		if @selected_unit_move || @selected_unit
			@resolveMoveUnitClick()
		else 
			@resolvePlaceUnitClick()

		if !@selected_unit_move
			@selected_unit_type = null

		


	resolvePlaceUnitClick: ->
		if @placeholder_unit_ok
			placeUnit(@placeholder_unit.x,@placeholder_unit.y)

		if state.place_type
			placeUnit(@placeholder_unit.x,@placeholder_unit.y)

	resolveMoveUnitClick: ->
		if !@selected_unit?.actions
			@selected_unit = null
			return
		if !@selected_unit_move && @selected_unit
			@selected_unit_move = true
			return

		if !@selected_unit_move || !@selected_unit
			return


		






		if @selected_unit_move && @selected_unit && @selected_enemy_unit
			attackUnit(@selected_unit,@selected_enemy_unit)
			@selected_enemy_unit = null
			@selected_unit_move = false
			@selected_unit = null
			return


		ok = false
		if @selected_unit.x <= @unitX < (@selected_unit.x+@selected_unit.w)
			if @unitY == (@selected_unit.y+@selected_unit.h) || @unitY == @selected_unit.y-1
				ok = yes
		
		if @selected_unit.y <= @unitY < (@selected_unit.y+@selected_unit.h)
			if @unitX == (@selected_unit.x+@selected_unit.w) || @unitX == @selected_unit.x-1
				ok = yes			




		if ok
			moveUnit(@selected_unit,@unitX,@unitY)
		
		@selected_unit = null
		@selected_unit_move = false

		# if @selected_unit && @selected_unit.player_id == state.player.id
		# 	@selected_unit_move = true

	kill: ()->
		window.removeEventListener 'resize',@resize
		window.removeEventListener 'keydown',@onKeyDown
		window.removeEventListener 'keyup',@onKeyUp
		window.removeEventListener 'mousemove',@onMouseMove
		window.removeEventListener 'click',@onClick
		@stopped = true

	onKeyDown: (e)=>

		if e.code == 'Escape'
			@selected_unit_type = null
			@selected_unit = null
			@selected_unit_move = false


		if e.code == 'Space'
			if @selected_unit_type?
				selectUnitType(@selected_unit,@selected_unit_type)
				@selected_unit_move = false
				@selected_unit = null
				@selected_unit_type = null
				
			else
				endTurn()
		else if e.code == 'Digit1'
			if @selected_unit_move
				@selected_unit_type = 0
			state.selected_type = 0
			updateView()
			return
		else if e.code == 'Digit2'
			if @selected_unit_move
				@selected_unit_type = 1
			state.selected_type = 1
			updateView()
			return
		else if e.code == 'Digit3'
			if @selected_unit_move
				@selected_unit_type = 2
			state.selected_type = 2
			updateView()
			return
		else if e.code == 'Digit4'
			if @selected_unit_move
				@selected_unit_type = 3
			state.selected_type = 3
			updateView()
			return
		else
			@selected_unit_type = null



		

		if e.code == 'ArrowUp' && @state.panY == 0
			@pan(0,1)
		if e.code == 'ArrowDown'  && @state.panY == 0
			@pan(0,-1)
		if e.code == 'ArrowRight'  && @state.panX == 0
			@pan(-1,0)
		if e.code == 'ArrowLeft' && @state.panX == 0
			@pan(1,0)

		updateView()
	
	onKeyUp: (e)=>
		if e.code == 'ShiftLeft'
			updateView
				place_unit: false
		if e.code == 'ArrowUp' || e.code == 'ArrowDown'
			@state.panY = 0
		if e.code == 'ArrowRight' || e.code == 'ArrowLeft'
			@state.panX = 0
	

	transform: ()->
		@viewX += @panX
		@viewY += @panY

		
		
		diff_w = DIM2*@sizeX - @width
		if diff_w > 0
			@viewX = _.clamp(@viewX,-diff_w/2 - DIM2,diff_w/2 + DIM2)
		else
			@viewX = 0
		
		diff_h = DIM2*@sizeY - @height
		if diff_h > 0
			@viewY = _.clamp(@viewY,-diff_h/2 - DIM2,diff_h/2 + DIM2)
		else
			@viewY = 0


		# @viewX = _.clamp ((DIM2*@w/2))

		@ctx.setTransform(1,0, 0, 1,@width/2-(DIM2*@sizeX/2)+@viewX,@height/2-(DIM2*@sizeY/2)+@viewY)
	
	clear: ()->
		@ctx.clearRect(0,0, @width, @height)

	pan: (x,y)->
		@state.panX += x * 8
		@state.panY += y * 8

	tickPan: ()->
		@panX += 0.2 * (@state.panX - @panX)
		@panY += 0.2 * (@state.panY - @panY)

	tick: ()=>
		if @stopped
			return
		@clear()
		@tickPan()
		@transform()
		@render()
		@ctx.setTransform(1,0, 0, 1,0,0)
		@drawTypeSelect(state.selected_type,20,20,10)


		requestAnimationFrame(@tick)

	drawUnitType: (x,y,w,h,type,color)->
		for rx in [0...w]
			for ry in [0...h]
				px = x + rx*DIM2
				py = y + ry*DIM2
				# log px,py
				@ctx.beginPath()
				@ctx.fillStyle = color
				r = DIM2/6
				if type == 4
					@ctx.arc(px,py,r,0,Math.PI*2)
				else if type == 0
					@ctx.arc(px,py,r,0,Math.PI*2)
				else if type == 1
					lineToPoly(@ctx,px,py,3,r)
				else if type == 2
					@ctx.rect(px-r,py-r,r*2,r*2)
				else if type == 3
					lineToPoly(@ctx,px,py,6,r)

				@ctx.closePath()
				@ctx.fill()




	drawUnitDice: (unit,color,color2)->
		x = unit.x*DIM2+DIM2/2
		y = unit.y*DIM2+DIM2/2
		dice = unit.dice
		actions = unit.actions
		
		@ctx.fillStyle = color
		dx = 0
		dy = 0
		gx = 0
		gy = 0


		if unit.actions
			@ctx.strokeStyle = color2
			@ctx.lineWidth = 2
			@ctx.beginPath()
			@ctx.arc( x,y,DIM2/2.7,Math.PI/4,Math.PI/4+Math.PI/2*unit.actions)
			@ctx.stroke()


		for i in [0...dice]
			ang = Math.PI/4 + Math.PI*2/8 * i

			ox = Math.cos(ang) * DIM2/2.7
			oy = Math.sin(ang) * DIM2/2.7 


			@ctx.beginPath()
			

			@ctx.arc( x+ox,y+oy,4,0,Math.PI*2)
			@ctx.closePath()
			@ctx.fill()


	

	mouseXY: (m_x,m_y)->
		x = m_x + @viewX
		y = m_y + @viewY



	updateGrid: ()->
	
		@grid = []
		for x in [0...@sizeX]
			for y in [0...@sizeY]
				@grid[x] = @grid[x] || []
				@grid[x][y] = -1

		
		for unit in state.game.units
			for x in [0...unit.w]
				for y in [0...unit.h]				
					@grid[unit.x+x][unit.y+y] = unit


	drawPipe: (x,y,x2,y2,color,width,ox,oy)->
		ox = ox || 0
		oy = oy || 0
		@ctx.strokeStyle = color
		@ctx.lineWidth = width
		@ctx.lineCap = 'round'
		@ctx.lineJoin = 'round'
		@ctx.beginPath()
		a = Math.atan2(y2 - y, x2 - x)
		a2 = a + Math.PI


		@ctx.moveTo  x*DIM2 + DIM2/2 + Math.cos(a)*DIM2/2.5+ox, y*DIM2 + DIM2/2 + Math.sin(a)*DIM2/2.5+oy
		@ctx.lineTo x2*DIM2 + DIM2/2 + Math.cos(a2)*DIM2/2.5+ox,y2*DIM2 + DIM2/2 + Math.sin(a2)*DIM2/2.5+oy
		@ctx.closePath()
		@ctx.stroke()
	
	getNeighbors: (unit,cb)->
		for y in [0...unit.h]
			# left neigh
			if @grid[unit.x-1] && @grid[unit.x-1][unit.y+y]? && @grid[unit.x-1][unit.y+y] != -1
				cb(unit.x,unit.y+y,unit.x-1,unit.y+y,@grid[unit.x-1][unit.y+y],unit)

			# right neih
			if @grid[unit.x+unit.w] && @grid[unit.x+unit.w][unit.y+y] && @grid[unit.x+unit.w][unit.y+y] != -1
				cb(unit.x+unit.w-1,unit.y+y,unit.x+unit.w,unit.y+y,@grid[unit.x+unit.w][unit.y+y],unit)
		

		for x in [0...unit.w]
			# top neigh
			if @grid[unit.x+x] && @grid[unit.x+x][unit.y-1]? && @grid[unit.x+x][unit.y-1] != -1
				cb(unit.x+x,unit.y,unit.x+x,unit.y-1,@grid[unit.x+x][unit.y-1],unit)

			# bot neih
			if @grid[unit.x+x] && @grid[unit.x+x][unit.y+unit.h]? && @grid[unit.x+x][unit.y+unit.h] != -1
				cb(unit.x+x,unit.y+unit.h-1,unit.x+x,unit.y+unit.h,@grid[unit.x+x][unit.y+unit.h],unit)

	


	drawTypeSelect: (type,px,py,r)->
		@ctx.beginPath()
		
	

		for i in [0..2]
			@ctx.fillStyle = 'rgba(255,255,255,0.6)'
			@ctx.beginPath()
			pad = i * r * 4
			if i == 0
				@ctx.arc(px,py+pad,r,0,Math.PI*2)
			else if i == 1
				lineToPoly(@ctx,px,py+pad,3,r)
			else if i == 2
				@ctx.rect(px-r,py-r+pad,r*2,r*2)
			else if i == 3
				lineToPoly(@ctx,px,py+pad,6,r)
			@ctx.closePath()
			@ctx.fill()
			
			if i == type
				@ctx.fillStyle = 'rgba(255,255,255,0.2)'
				@ctx.fillRect(px-r-r/2,py-r+pad-r/2,r*3,r*3)
				
				


	onNeighborUnit: (x,y,x2,y2,n,unit)=>
		if (n.type == 4 && unit.type != 4)
			if unit.linked_unit_id != n.id
				if !unit.player
					color = @resource_color
				else
					color = unit.player.color

				@drawPipe(x,y,x2,y2,rgba(color,0.3,0.4),8)





	drawPipes: ()->
		for unit in state.game.units
			if unit.linked_unit_id
				n = state.game.units_map[unit.linked_unit_id]
				if n
					if unit.link_adjacent
						if unit.y == n.y
							ox = 0
							oy = 5
						else
							ox = 5
							oy = 0
						@drawPipe(n.x,n.y,unit.x,unit.y,rgba(unit.player.color,0.9,0.4),4,ox,oy)
						@drawPipe(n.x,n.y,unit.x,unit.y,rgba(unit.player.color,0.9,0.4),4,ox*-1,oy*-1)					
					else
						@drawPipe(n.x,n.y,unit.x,unit.y,rgba(unit.player.color,0.2,0.4),4)

			@getNeighbors(unit,@onNeighborUnit)

	
	drawMoveRect: (x,y,w,h,color,opac)->
		@ctx.lineWidth = 2
		@ctx.strokeStyle = rgba(color || @resource_color,opac,0.5)
		@ctx.fillStyle = rgba(color || @resource_color,opac/2,0.5)
		@ctx.beginPath()
		@ctx.rect(x*DIM2,y*DIM2, DIM2*w,DIM2*h)
		@ctx.closePath()
		@ctx.fill()
		@ctx.stroke()

	drawUnitOutlineHints: ()->
		@selected_enemy_unit = null
		if @selected_unit && @selected_unit_move && @selected_unit.actions && state.game.turn_player.id == state.player.id


			unit = @selected_unit

			# MOVEMENT POSITIONS
			draw_left = true
			draw_right = true
			for y in [0...unit.h]
				n1 = @grid[unit.x-1]?[unit.y+y]
				n2 = @grid[unit.x+unit.w]?[unit.y+y]
				if !n1
					draw_left = false
				else
					if n1 != -1 && (unit.player_id != n1.player_id || !unit.dice)
						draw_left = false

						
				if !n2
					draw_right = false
				else
					if n2 != -1 && (unit.player_id != n2.player_id || !unit.dice)
						draw_right = false




		
			if draw_left
				if @unitX == unit.x-1 && (unit.y <= @unitY < unit.y+unit.h)
					opac = 1
				else
					opac = 0.2
				@drawMoveRect(unit.x-1,unit.y,1,unit.h,unit.player.color,opac)
			
			if draw_right
				if @unitX == unit.x+unit.w && (unit.y <= @unitY < unit.y+unit.h)
					opac = 1
				else
					opac = 0.2
				@drawMoveRect(unit.x+unit.w,unit.y,1,unit.h,unit.player.color,opac)

			draw_top = true
			draw_bot = true
			for x in [0...unit.w]
				n1 = @grid[unit.x+x]?[unit.y-1]
				n2 = @grid[unit.x+x]?[unit.y+unit.h]
				if !n1
					draw_top = false
				else
					if n1 != -1 && (unit.player_id != n1.player_id || !unit.dice)
						draw_top = false

						
				if !n2
					draw_bot = false
				else
					if n2 != -1 && (unit.player_id != n2.player_id || !unit.dice)
						draw_bot = false


		
			if draw_top
				if @unitY == unit.y-1 && (unit.x <= @unitX < unit.x+unit.w)
					opac = 1
				else
					opac = 0.2
				@drawMoveRect(unit.x,unit.y-1,unit.w,1,unit.player.color,opac)
			
			if draw_bot
				if @unitY == unit.y+unit.h && (unit.x <= @unitX < unit.x+unit.w)
					opac = 1
				else
					opac = 0.2
				@drawMoveRect(unit.x,unit.y+unit.h,unit.w,1,unit.player.color,opac)



			# ATTACK TARGETS
			
			
			@getNeighbors unit,(x,y,x2,y2,n,unit)=>
				if unit.type == 2 || !unit.dice
					return
				if n.player && n.player.id != unit.player.id && (unit.player.team_id != unit.player.team_id || unit.player.team_id == n.player.team_id == 0)
					if (n.x <= @unitX < n.x+n.w) && (n.y <= @unitY < n.y+n.h)
						@selected_enemy_unit = n
						opac = 1
					else
						opac = 0.4
					@drawMoveRect(n.x,n.y,n.w,n.h,n.player.color,opac)









			return


		if @grid[@unitX][@unitY] != -1 && @grid[@unitX][@unitY]? && @grid[@unitX][@unitY].player_id == state.player.id
			@selected_unit = @grid[@unitX][@unitY]
			return
		else
			@selected_unit = null


		

	drawUnitPlaceholder: ()->
		@placeholder_unit_ok = false


		if state.game.turn_player.id != state.player.id
			return

		if !(state.selected_type?) || @selected_unit || !@mouse_in_bounds
			return





		for unit in state.player.home_units
			if intersects(@unitX,@unitY,@unitX,@unitY,unit.x-1,unit.y-1,unit.x+1,unit.y+1) && @unitX >= 0 && @unitY >= 0 && @unitX <= @sizeX && @unitY <= @sizeY
				ok = true
				for x in [@unitX...@unitX+1]
					for y in [@unitY...@unitY+1]
						if !@grid[x] || @grid[x][y] != -1
							ok = false
					
				if !ok
					@ctx.fillStyle = '#FF0000'
					@ctx.fillRect((@unitX)*DIM2+UPAD,(@unitY)*DIM2+UPAD, DIM2-UPAD*2,DIM2-UPAD*2)
					return

				@placeholder_unit_ok = true
				@placeholder_unit.x = @unitX
				@placeholder_unit.y = @unitY
				@placeholder_unit.w = 1
				@placeholder_unit.h = 1
				@placeholder_unit.type = state.selected_type
				@drawUnit(@placeholder_unit,@placeholder_unit_color,0.2)
			

	drawUnit: (unit,color,opacity)->
	       
		if unit == @selected_unit && unit.player_id == state.player.id && @mouse_in_bounds && unit.actions
			@ctx.strokeStyle = rgba(color,1,@selected_unit_move && 0.1 || 0.5)
			@ctx.lineWidth = 2
			@ctx.beginPath()
			@ctx.rect(unit.x*DIM2,unit.y*DIM2, unit.w*DIM2,unit.h*DIM2)
			@ctx.closePath()
			@ctx.stroke()

		@ctx.fillStyle = rgba(color,opacity || 0.5)
		@ctx.fillRect(unit.x*DIM2+UPAD,unit.y*DIM2+UPAD, unit.w*DIM2-UPAD*2,unit.h*DIM2-UPAD*2)
		if @selected_unit_move && @selected_unit && unit.id == @selected_unit.id && @selected_unit_type?
			@drawUnitType(unit.x*DIM2+DIM2/2,unit.y*DIM2+DIM2/2,unit.w,unit.h,@selected_unit_type,rgba(color,1,1))
		else
			@drawUnitType(unit.x*DIM2+DIM2/2,unit.y*DIM2+DIM2/2,unit.w,unit.h,unit.type,rgba(color,1,opacity || 0.5))
		if unit.type != 4
			@drawUnitDice(unit,rgba(color,1,opacity || 0.5),rgba(color,0.5,0.2))
		
		# home radius
		if unit.type == 3
			@ctx.fillStyle = rgba(color,0.1)
			hx = _.clamp unit.x - 1,0,@sizeX
			hy = _.clamp unit.y - 1,0,@sizeY
			hr = _.clamp unit.x + unit.w + 1,0,@sizeX
			ht = _.clamp unit.y + unit.h + 1,0,@sizeY
			@ctx.fillRect((hx)*DIM2,(hy)*DIM2, (hr-hx)*DIM2,(ht-hy)*DIM2)

	drawUnits: ()->
		for unit in state.game.units
			@drawUnit(unit,unit.player && unit.player.color || @resource_color)


	drawGrid: ()->
		for x in [0...@sizeX]
			for y in [0...@sizeY]
				if (x % 2 == 0 && y%2 != 0) || (x % 2 != 0 && y%2 == 0)
					@ctx.fillStyle = '#202020'
					@ctx.fillRect(x*DIM2, y*DIM2, DIM2, DIM2)

				

	kill: ->
		window.removeEventListener 'resize',@resize
		log 'kill game'
	



	render: ()->
		if !state.game
			return

		if state.game.stamp != @stamp
			@stamp = state.game.stamp
			@updateGrid()
		@drawGrid()
		@drawUnitOutlineHints()
		@drawUnitPlaceholder()
		@drawUnits()
		@drawPipes()
		
		if !@mouse_in_bounds
			return





class Player
	constructor: (props)->
		@color = props.color


class Unit
	constructor: (props)->
		@player = props.player
		@type = props.type
		@w = props.w
		@h = props.h
		@x = props.x
		@y = props.y






class NewGameView
	render: ->
		op = _.findIndex(@props.game.players,id:@props.player.id) == 0
		
		h 'div',
			className: 'lobby center'
			h 'h1',
				className: 'game-id'
				@props.game.id
			h 'p',
				className: 'sub'
				'waiting for players to join lobby...'
			h 'div',
				className: 'join-lobby-wrapper'
				@props.game.players.map (player,i)=>
					h 'div',
						className: 'player'
						h 'span',
							className: 'tag'
							i+'.'
						h 'span',
							className: 'tag'
							'#'
						if op then h 'input',
							onChange: (e)=>
								sock.emit 'game_set',
									player_team: [player.id,e.target.value]
							className: 'input-team-id'
							type: 'number'
							value: player.team_id
						else h 'span',
							className: 'player-team'
							player.team_id	

						h 'span',
							className: 'name'
							style: 
								color: rgba(player.color)
							player.name || player.id
			
			op && h 'div',
				className: cn 'btn join-btn'
				onClick: ->
					sock.emit 'game_start',''
				'start'

class EndGameView
	render: ->
		h 'div',
			className: 'lobby center'
			h 'h1',
				className: 'game-id'
				'game over #: '+@props.game.id

			h 'div',
				className: 'end-stats'
				h 'div',{},h('span',{},'total turns'),@props.game.stats.total_turns
				h 'div',{},h('span',{},'total time'),msToTime(@props.game.stats.total_time)
				h 'div',{},h('span',{},'alive'),@props.game.stats.alive_players.map (player,i)=>
					player.name+','
				h 'div',{},h('span',{},'dead'),@props.game.stats.dead_players.map (player,i)=>
					player.name+','
					




			h 'div',
				className: cn 'btn'
				onClick: leaveGame
				'leave'





class JoinView extends Component
	constructor: (props)->
		super(props)
		@state = 
			game_id: null
			type: 1
			sizeX: 8
			sizeY: 8
			resource_factor: 1
			unit_factor: 1

	render: ->
		h 'div',
			className: 'lobby center'
			h 'h1',
				className: 'title'
				'blockd'
			h 'p',
				className: 'sub'
				'this is a prototype.'
			h 'div',
				className: 'join-lobby-wrapper'
				h 'input',
					type: 'text'
					placeholder: 'game id'
					value: @state.game_id
					onInput: (e)=>
						@setState
							game_id: e.target.value
						
				h 'div',
					className: 'btn join-btn'
					onClick: =>
						joinGame(@state.game_id)
					'join'
			h 'br'
			h 'br'
			h 'span',{},'type (1-3)'
			h 'input',
				type: 'number'
				placeholder: 'type (1-3)'
				value: @state.type
				onInput: (e)=>
					@setState
						type: e.target.value
			
			h 'span',{},'sizeX (8 - 100)'
			h 'input',
				type: 'number'
				placeholder: 'sizeX (8 - 100)'
				value: @state.sizeX
				onInput: (e)=>
					@setState
						sizeX: e.target.value
			h 'span',{},'sizeY (8 - 100)'
			h 'input',
				type: 'number'
				placeholder: 'sizeY (8 - 100)'
				value: @state.sizeY
				onInput: (e)=>
					@setState
						sizeY: e.target.value
					
			h 'span',{},'resource_factor (0 - 10)'
			h 'input',
				type: 'number'
				placeholder: 'resource_factor (0 - 10)'
				value: @state.resource_factor
				onInput: (e)=>
					@setState
						resource_factor: e.target.value
			h 'span',{},'unit_factor (0 - 10)'
			h 'input',
				type: 'number'
				placeholder: 'unit_factor (0 - 10)'
				value: @state.unit_factor
				onInput: (e)=>
					@setState
						unit_factor: e.target.value
					

			h 'div',
				className: 'btn join-btn'
				onClick: =>
					createGame(@state)
				'create new game'




class View extends Component
	constructor: (props)->
		super(props)
		@state = {}

	componentDidMount: ()->
		
		if @_canvas && !window.game
			window.game = new Game(@_canvas)

	componentDidUpdate: ()->

		if !@_canvas && window.game
			window.game.kill()
			window.game = null
		else if @_canvas && !window.game
			log 'NEW GAME'		
			window.game = new Game(@_canvas)


	render: ->


		types = [0...3].map (i)->


		if !@props.game
			content = h JoinView, @props
		else if @props.game && !@props.game.started
			content = h NewGameView, @props
		else if @props.game && @props.game.ended
			content = h EndGameView, @props
		else
			content = h 'div',
				className: 'ui center'
				h 'canvas',
					ref: (e)=>
						@_canvas = e
					id: 'game_canvas'
			
				h 'div',
					className: 'game-stats'
					h 'div',{},h('span',{},'game id'),@props.game.id
					h 'div',{style:color:rgba(@props.player.color)},h('span',{},'player'),@props.player.name
					h 'div',{},h('span',{},'turn'),@props.game.total_turns
					h 'div',{},h('span',{},'players'),@props.game.players.length
					h 'div',{},h('span',{},'time'),msToTime(Date.now() - @props.game.start_time)
					h 'br',{}
					h 'div',{},h('span',{},'turn time left'),msToTime(@props.game.turn_end_time - Date.now())
					@props.game.turn_player && h 'div',{style:color:rgba(@props.game.turn_player.color)},h('span',{},'current turn player'),@props.game.turn_player.name
					window.game && !window.game.selected_unit_type? && @props.game.turn_player?.id == @props.player.id && h 'div',{},'its your turn! press space to end.'
				window.game && window.game.selected_unit_type? && h 'div',{className: 'alert center'},'press space or click to confirm unit selection type.'


		h 'div',
			className: 'wrapper'
			content
			@props.game && h 'div',
				className: 'btn leave-btn'
				onClick: ->
					leaveGame()
				'exit'


moveUnit = (unit,x,y,split,split_x,split_y)->
	sock.emit 'game_put',
		move_unit:
			id: unit.id
			x: x
			y: y

selectUnitType = (u,type)->
	sock.emit 'game_put',
		unit_type:
			id: u.id
			type: type


attackUnit = (u,n)->
	sock.emit 'game_put',
		attack_unit:
			u_id: u.id
			n_id: n.id


placeUnit = (x,y)->

	sock.emit 'game_put',
		place_unit:
			x: x
			y: y
			type: state.selected_type
	
	updateView
		place_unit: false
		

setType = (id)->
	updateView
		selected_type: id

leaveGame = ->
	sock.emit 'leave',''
		

endTurn = ->
	sock.emit 'game_put',
		end_turn: yes


createGame = (opt)->
	sock.emit 'create',opt

joinGame = (id)->
	sock.emit 'join',id



game = null
window.game = null
view = null

state = 
	game_over: false
	selected_type: 0
	game: null

window.state = state

updateView = (new_state)->
	state = Object.assign {},state,new_state
	window.state = state
	view = render(h(View,state),window.document.body,view)


sock = io('http://69.138.151.79:3330')




sock.on 'err', (msg)->
	console.error msg

sock.on 'state', (state)->
	if state.game
		state.game.players_map = {}
		state.game.units_map = {}
		state.player.home_units = []
	
		state.game.turn_player = state.game.players[state.game.turn_player_i]

		for player in state.game.players
			state.game.players_map[player.id] = player
		for u in state.game.units
			state.game.units_map[u.id] = u
			if u.type == 3 && u.player_id == state.player.id
				state.player.home_units.push u
			u.player = state.game.players_map[u.player_id]
	updateView state




setInterval ->
	updateView({})
,1000


updateView()



# joinGame('dev')


