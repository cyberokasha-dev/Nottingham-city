extends Control
# Clean navigation: places and the assigned cab, without pedestrian or traffic clutter.
var game: Node3D
var player: Node3D
var city: Node3D
var fleet: Array[VehicleBody3D] = []
var destination := Vector3.ZERO
var destination_active := false
var expanded := false
var selecting := false
var refresh := 0.0
var map_rect := Rect2(12,35,226,200)
var close_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	close_button = Button.new()
	close_button.text = "Close map • N"
	close_button.pressed.connect(close)
	add_child(close_button)
	_layout()

func _layout() -> void:
	var viewport := get_viewport_rect().size
	size = Vector2(minf(viewport.x-40,780),minf(viewport.y-90,630)) if expanded else Vector2(250,260)
	position = (viewport-size)*0.5 if expanded else (Vector2(20,maxf(70,viewport.y-size.y-20)) if viewport.x>=900 else Vector2(viewport.x-size.x-20,70))
	map_rect = Rect2(14,45,size.x-28,size.y-82)
	close_button.visible = expanded
	close_button.position = Vector2(size.x-160,8)

func open(pick_destination := false) -> void:
	expanded = true
	selecting = pick_destination
	if is_instance_valid(game) and is_instance_valid(game.phone): game.phone.panel.hide()
	_layout()
	queue_redraw()

func close() -> void:
	expanded = false
	selecting = false
	_layout()
	queue_redraw()

func _process(delta: float) -> void:
	_layout()
	refresh += delta
	if refresh>0.08:
		queue_redraw()
		refresh = 0

func point(pos: Vector3) -> Vector2:
	return map_rect.position+Vector2((pos.x+170)/340,(pos.z+150)/340)*map_rect.size

func world_point(screen: Vector2) -> Vector3:
	var fraction := (screen-map_rect.position)/map_rect.size
	return Vector3(fraction.x*340-170,city.traffic.LEVEL,fraction.y*340-150)

func location_at(screen: Vector2) -> Dictionary:
	var world := world_point(screen)
	var nearest: Dictionary = {"name":"Map pin (%d, %d)" % [int(world.x),int(world.z)],"point":world}
	var gap := 11.0
	if is_instance_valid(game):
		for location in game.economy.locations:
			var distance: float = world.distance_to(location.point)
			if distance<gap:
				gap = distance
				nearest = location.duplicate()
	return nearest

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not expanded:
			open()
		elif map_rect.has_point(event.position) and is_instance_valid(game):
			var location := location_at(event.position)
			destination = location.point
			destination_active = true
			close()
			game.phone.select_location(location)
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_N:
		if expanded: close()
		else: open()
		get_viewport().set_input_as_handled()

func _caption(at: Vector2, text: String, color: Color, font_size := 12) -> void:
	draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _place(world: Vector3, text: String, color: Color) -> void:
	var p := point(world)
	draw_circle(p,4,color)
	if expanded: _caption(p+Vector2(6,-5),text,color)

func _draw() -> void:
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	_caption(Vector2(14,24),"NOTTINGHAM • "+("CHOOSE A DESTINATION" if expanded else "N: OPEN MAP"),Color.WHITE,14)
	if not is_instance_valid(city): return
	draw_rect(map_rect,Color("17252b"))
	for park in city.parks:
		draw_rect(Rect2(point(park.global_position)-Vector2(8,9),Vector2(16,18)),Color("365d49"))
	for x in city.ROAD_X:
		draw_line(point(Vector3(x,0,-145)),point(Vector3(x,0,165)),Color("66767b"),7 if expanded else 4)
	for z in city.ROAD_Z:
		draw_line(point(Vector3(-160,0,z)),point(Vector3(160,0,z)),Color("66767b"),7 if expanded else 4)
	for park in city.parks: _place(park.global_position,str(park.park_name),Color("86cfa3"))
	if is_instance_valid(game) and is_instance_valid(game.economy):
		_place(game.economy.office,"Council office",Color("e7d9ac"))
		var account: Dictionary = game.economy.account_for(player)
		if game.economy.houses.has(int(account.house)):
			_place(game.economy.houses[int(account.house)].entrance(),"Home",Color("d9eaff"))
		if expanded:
			for stop in city.transport.stops: draw_circle(point(stop.pavement),2,Color("b3b9c2"))
		if is_instance_valid(game.cabs):
			var route: PackedVector3Array = game.cabs.remaining_route(player)
			if route.size()>1:
				var line := PackedVector2Array()
				for p in route: line.append(point(p))
				draw_polyline(line,Color("dfb8ff"),3,true)
			var key: String = game.economy.key_for(player)
			if game.cabs.bookings.has(key):
				var trip: Dictionary = game.cabs.bookings[key]
				if int(trip.car)>=0:
					var car: Dictionary = game.cabs.cars[int(trip.car)]
					_place(car.node.global_position,car.cab_id,Color("ffdc77"))
				if trip.destination.has("point"): _place(trip.destination.point,str(trip.destination.name),Color("e6baff"))
				if trip.state in ["approaching","waiting"] and trip.has("pickup_curb"):
					_place(trip.pickup_curb,"Pickup",Color("62ffa4"))
	if destination_active: _place(destination,"Selected place",Color("62baff"))
	if is_instance_valid(player):
		var p := point(player.global_position)
		var heading: float = player.yaw
		if is_instance_valid(player.riding_service):
			heading = player.riding_service.cars[int(player.get_meta("cab_car"))].node.rotation.y+PI
		var direction := Vector2(-sin(heading),-cos(heading))
		var side := Vector2(-direction.y,direction.x)
		draw_colored_polygon(PackedVector2Array([p+direction*8,p-direction*5+side*5,p-direction*2,p-direction*5-side*5]),Color.WHITE)
	_caption(Vector2(14,size.y-12),"Click a place to select • purple line: cab route" if expanded else "Places • assigned cab • route",Color("bfcdd4"),12)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.065,0.08,0.96)
	style.set_corner_radius_all(10)
	return style
