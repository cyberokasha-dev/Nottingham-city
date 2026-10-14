extends Control
# North-up atlas and a rotating player-centred radar share one world projection.
const ATLAS = preload("res://town/districts.gd")
var game: Node3D
var player: Node3D
var city: Node3D
var fleet: Array[VehicleBody3D] = []
var destination := Vector3.ZERO
var destination_active := false
var selected_place: Dictionary = {}
var expanded := false
var selecting := false
var refresh := 0.0
var zoom := 1.0
var center := Vector2(0,10)
var map_rect := Rect2(14,45,222,178)
var close_button: Button
var walk_button: Button
var cab_button: Button
var plus_button: Button
var minus_button: Button
var walking_route := PackedVector3Array()
var route_clock := 0.0
var show_homes := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	close_button = _button("Close • N",close)
	walk_button = _button("Walk to waypoint",func(): close())
	cab_button = _button("Use as Aurora destination",func():
		if selected_place.is_empty(): return
		close()
		game.phone.select_location(selected_place))
	plus_button = _button("+",func(): zoom = minf(3,zoom*1.3); queue_redraw())
	minus_button = _button("−",func(): zoom = maxf(1,zoom/1.3); _bound_center(); queue_redraw())
	_layout()

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button

func _layout() -> void:
	var viewport := get_viewport_rect().size
	size = Vector2(minf(viewport.x-40,900),minf(viewport.y-90,700)) if expanded else Vector2(250,260)
	position = (viewport-size)*0.5 if expanded else (Vector2(20,maxf(70,viewport.y-size.y-20)) if viewport.x>=900 else Vector2(viewport.x-size.x-20,70))
	map_rect = Rect2(14,45,size.x-28,size.y-(145 if expanded else 82))
	for button in [close_button,plus_button,minus_button]: button.visible = expanded
	close_button.position = Vector2(size.x-130,7)
	plus_button.position = Vector2(size.x-175,7)
	minus_button.position = Vector2(size.x-215,7)
	walk_button.visible = expanded and destination_active
	cab_button.visible = walk_button.visible
	walk_button.position = Vector2(14,size.y-42)
	cab_button.position = Vector2(185,size.y-42)

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
	route_clock+=delta
	if destination_active and route_clock>1 and is_instance_valid(game) and is_instance_valid(game.population):
		route_clock = 0
		var graph: AStar3D = game.population.streets
		walking_route = graph.get_point_path(graph.get_closest_point(player.global_position),graph.get_closest_point(destination))
		walking_route.insert(0,player.global_position)
		walking_route.append(destination)
	if refresh>0.08:
		queue_redraw()
		refresh = 0

func _heading() -> float:
	if not is_instance_valid(player): return 0
	if player.get("driving")==true and is_instance_valid(player.vehicle): return player.vehicle.rotation.y+PI
	if is_instance_valid(player.get("riding_service")):
		return player.riding_service.cars[int(player.get_meta("cab_car"))].node.rotation.y+PI
	if is_instance_valid(player.get("riding_bus")): return player.riding_bus.rotation.y+PI
	return player.yaw

func _view_center() -> Vector2:
	return center if expanded or not is_instance_valid(player) else Vector2(player.global_position.x,player.global_position.z)

func _span() -> float:
	return 340.0/zoom if expanded else 112.0

func point(pos: Vector3) -> Vector2:
	var offset := Vector2(pos.x,pos.z)-_view_center()
	if not expanded: offset = offset.rotated(_heading())
	return map_rect.get_center()+offset/_span()*map_rect.size

func world_point(screen: Vector2) -> Vector3:
	var offset := (screen-map_rect.get_center())/map_rect.size*_span()
	if not expanded: offset = offset.rotated(-_heading())
	var world := _view_center()+offset
	return Vector3(world.x,city.traffic.LEVEL,world.y)

func _bound_center() -> void:
	var half := 170.0/zoom
	center.x = clampf(center.x,-170+half,170-half)
	center.y = clampf(center.y,-160+half,180-half)

func location_at(screen: Vector2) -> Dictionary:
	var world := world_point(screen)
	for house in city.houses:
		var local: Vector3 = house.to_local(world)
		if absf(local.x)<=5.3 and absf(local.z)<=6.3:
			return {"name":house.address,"point":house.entrance()}
	var nearest: Dictionary = {"name":ATLAS.street_at(world)+" • map waypoint","point":world}
	var gap := 8.0/zoom
	if is_instance_valid(game):
		for location in game.economy.locations:
			var distance: float = world.distance_to(location.point)
			if distance<gap:
				gap = distance
				nearest = location.duplicate()
	return nearest

func set_waypoint(location: Dictionary) -> void:
	selected_place = location.duplicate()
	destination = location.point
	destination_active = true
	route_clock = 2
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and expanded and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		center-=event.relative/map_rect.size*_span()
		_bound_center()
		queue_redraw()
		accept_event()
	if event is InputEventMouseButton and event.pressed:
		if expanded and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),1,3)
			_bound_center()
			queue_redraw()
			accept_event()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not expanded: open()
			elif map_rect.has_point(event.position) and is_instance_valid(game):
				var location := location_at(event.position)
				set_waypoint(location)
				if selecting:
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

func _line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	# Clip each segment so roads and routes never paint over the map's controls.
	var delta := to-from
	var start := 0.0
	var finish := 1.0
	var p := [-delta.x,delta.x,-delta.y,delta.y]
	var q := [from.x-map_rect.position.x,map_rect.end.x-from.x,from.y-map_rect.position.y,map_rect.end.y-from.y]
	for i in range(4):
		if absf(p[i])<0.001:
			if q[i]<0: return
		else:
			var t: float = q[i]/p[i]
			if p[i]<0: start=maxf(start,t)
			else: finish=minf(finish,t)
	if start<=finish: draw_line(from+delta*start,from+delta*finish,color,width,true)

func _world_rect(bounds: Rect2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for corner in [bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]:
		polygon.append(point(Vector3(corner.x,0,corner.y)))
	var clip := PackedVector2Array([map_rect.position,Vector2(map_rect.end.x,map_rect.position.y),map_rect.end,Vector2(map_rect.position.x,map_rect.end.y)])
	for result in Geometry2D.intersect_polygons(polygon,clip):
		if result.size()>=3 and Geometry2D.triangulate_polygon(result).size()>=3: draw_colored_polygon(result,color)

func _place(world: Vector3, text: String, color: Color, icon := "") -> void:
	var p := point(world)
	if not map_rect.grow(-6).has_point(p): return
	draw_circle(p,6 if expanded else 4,color)
	if icon!="" and expanded: _caption(p+Vector2(-3,4),icon,Color("182026"),10)
	if expanded and text!="":
		_caption(Vector2(clampf(p.x+8,map_rect.position.x+5,map_rect.end.x-125),p.y-7),text,color,11)

func _route(path: PackedVector3Array, color: Color, width := 3.0) -> void:
	for i in range(1,path.size()): _line(point(path[i-1]),point(path[i]),color,width)

func _draw() -> void:
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var district: Dictionary = ATLAS.at(player.global_position) if is_instance_valid(player) else ATLAS.definitions()[0]
	_caption(Vector2(14,24),"NOTTINGHAM • CITY MAP" if expanded else str(district.name).to_upper(),Color("eff1ef"),14)
	if not is_instance_valid(city): return
	draw_rect(map_rect,Color("293035"))
	for area in city.districts:
		_world_rect(area.bounds,Color("30383b") if city.districts.find(area)%2==0 else Color("343b3d"))
	for park in city.parks: _world_rect(Rect2(Vector2(park.position.x-17,park.position.z-15),Vector2(34,30)),Color("506650"))
	for house in city.houses:
		_world_rect(Rect2(Vector2(house.position.x-5,house.position.z-6),Vector2(10,12)),Color("687071"))
	for x in city.ROAD_X+[-160.0,160.0]:
		_line(point(Vector3(x,0,-156)),point(Vector3(x,0,176)),Color("c0c3c0"),9 if expanded else 13)
		_line(point(Vector3(x,0,-156)),point(Vector3(x,0,176)),Color("646c6e"),6 if expanded else 9)
	for z in city.ROAD_Z+[-150.0,170.0]:
		_line(point(Vector3(-166,0,z)),point(Vector3(166,0,z)),Color("c0c3c0"),9 if expanded else 13)
		_line(point(Vector3(-166,0,z)),point(Vector3(166,0,z)),Color("646c6e"),6 if expanded else 9)
	if expanded:
		for area in city.districts:
			var p := point(area.center)
			if map_rect.grow(-50).has_point(p): _caption(p-Vector2(35,0),str(area.name).to_upper(),Color("a9b1b1"),13)
		for i in range(city.ROAD_Z.size()):
			var p := point(Vector3(-153,0,city.ROAD_Z[i]))
			if map_rect.has_point(p): _caption(p+Vector2(0,-8),ATLAS.STREET_Z[i],Color("d0d4d2"),11)
		for i in range(city.ROAD_X.size()):
			var p := point(Vector3(city.ROAD_X[i],0,155))
			if map_rect.grow(-8).has_point(p):
				draw_set_transform(p+Vector2(-8,-4),-PI/2)
				_caption(Vector2.ZERO,ATLAS.STREET_X[i],Color("cbd0ce"),10)
				draw_set_transform(Vector2.ZERO)
		if zoom>1.3:
			for house in city.houses:
				var p := point(house.global_position)
				if map_rect.grow(-8).has_point(p): _caption(p-Vector2(4,0),str(house.house_number),Color("e2e4de"),10)
	if destination_active: _route(walking_route,Color("8cd4e5"),2)
	for park in city.parks: _place(park.global_position,str(park.park_name) if expanded and zoom>1.3 else "",Color("92bd8b"),"P")
	if is_instance_valid(game) and is_instance_valid(game.economy):
		_place(game.economy.office,"Council",Color("e6dac0"),"C")
		for area in city.districts: _place(area.rank,str(area.name)+" rank" if expanded and zoom>1.3 else "",Color("d6b76b"),"A")
		var account: Dictionary = game.economy.account_for(player)
		if game.economy.houses.has(int(account.house)): _place(game.economy.houses[int(account.house)].entrance(),"Home",Color("e6e5d9"),"H")
		if expanded:
			for stop in city.transport.stops:
				var p := point(stop.pavement)
				if map_rect.has_point(p): draw_circle(p,2,Color("86b5cd"))
		if is_instance_valid(game.cabs):
			_route(game.cabs.remaining_route(player),Color("d2a0f0"),4)
			var key: String = game.economy.key_for(player)
			if game.cabs.bookings.has(key):
				var trip: Dictionary = game.cabs.bookings[key]
				if int(trip.car)>=0:
					var car: Dictionary = game.cabs.cars[int(trip.car)]
					_place(car.node.global_position,car.cab_id,Color("ffdb7b"),"A")
				if trip.destination.has("point"): _place(trip.destination.point,"Ride destination",Color("dcb3f5"))
				if trip.state in ["approaching","waiting"] and trip.has("pickup_curb"): _place(trip.pickup_curb,"Pickup",Color("70e6a5"))
	if destination_active: _place(destination,"Waypoint",Color("a8ddec"),"+")
	if is_instance_valid(player):
		var p := point(player.global_position)
		var heading := _heading() if expanded else 0.0
		var direction := Vector2(-sin(heading),-cos(heading))
		var side := Vector2(-direction.y,direction.x)
		if map_rect.grow(-8).has_point(p):
			draw_colored_polygon(PackedVector2Array([p,p+direction*25+side*13,p+direction*25-side*13]),Color(1,1,1,0.08))
			draw_colored_polygon(PackedVector2Array([p+direction*8,p-direction*5+side*5,p-direction*2,p-direction*5-side*5]),Color.WHITE)
	if expanded:
		_caption(Vector2(14,size.y-82),"A  Aurora rank     B  Bus stops     C  Council     H  Home     Purple  Cab route",Color("c9cecc"),12)
		_caption(Vector2(14,size.y-60),str(selected_place.get("name","Click a place • scroll to zoom • right-drag to pan • north is up")),Color("f0e6c8"),12)
	else:
		_caption(Vector2(14,size.y-12),ATLAS.street_at(player.global_position)+" • N: map",Color("c4cecc"),11)
	_caption(map_rect.position+Vector2(5,14),"N" if expanded else "↑",Color.WHITE,13)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.065,0.96)
	style.set_corner_radius_all(9)
	return style
