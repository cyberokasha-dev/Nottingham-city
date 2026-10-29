extends Control
# North-up atlas and a rotating player-centred radar share one world projection.
const W=preload("res://town/world_layout.gd")
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
var center := Vector2.ZERO
var map_rect := Rect2(14,45,222,178)
var close_button: Button
var walk_button: Button
var cab_button: Button
var plus_button: Button
var minus_button: Button
var walking_route := PackedVector3Array()
var route_clock := 0.0
var show_homes := true
var atlas_texture: ImageTexture
var atlas_builds := 0
var controller_cursor := Vector2(-1,-1)
var last_layout := Vector3(-1,-1,-1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	close_button = _button("Close • N",close)
	walk_button = _button("Walk to waypoint",func(): close())
	cab_button = _button("Use as road ride destination",func():
		if selected_place.is_empty(): return
		close()
		game.phone.select_location(selected_place))
	plus_button = _button("+",func(): zoom = minf(16,zoom*1.3); queue_redraw())
	minus_button = _button("−",func(): zoom = maxf(1,zoom/1.3); _bound_center(); queue_redraw())
	_build_atlas()
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
	var mobile:bool=is_instance_valid(game) and game.get_meta("phone_touch",false)
	var layout_key := Vector3(viewport.x,viewport.y,float(expanded)+(2 if mobile else 0))
	if last_layout==layout_key:
		walk_button.visible=expanded and destination_active
		cab_button.visible=walk_button.visible
		return
	last_layout=layout_key
	size = Vector2(minf(viewport.x-40,900),minf(viewport.y-90,700)) if expanded else Vector2(250,220)
	position = (viewport-size)*0.5 if expanded else Vector2(20,maxf(70,viewport.y-size.y-70))
	if mobile:
		var safe:Vector4=game.get_meta("phone_safe",Vector4.ZERO)
		size=Vector2(viewport.x-24-safe.x-safe.z,viewport.y-28-safe.y-safe.w) if expanded else Vector2(144,130)
		position=Vector2(12+safe.x,14+safe.y) if expanded else Vector2(12+safe.x,132+safe.y)
	map_rect = Rect2(14,45,size.x-28,size.y-(145 if expanded else 82))
	if mobile and not expanded: map_rect=Rect2(8,25,size.x-16,size.y-49)
	for button in [close_button,plus_button,minus_button]: button.visible = expanded
	close_button.position = Vector2(size.x-130,7)
	plus_button.position = Vector2(size.x-175,7)
	minus_button.position = Vector2(size.x-215,7)
	walk_button.visible = expanded and destination_active
	cab_button.visible = walk_button.visible
	walk_button.position = Vector2(14,size.y-42)
	cab_button.position = Vector2(185,size.y-42)
	if mobile and expanded:
		map_rect=Rect2(10,60,size.x-20,size.y-190)
		close_button.text="Close";close_button.position=Vector2(size.x-80,8);close_button.size=Vector2(70,44)
		plus_button.position=Vector2(size.x-130,8);plus_button.size=Vector2(44,44)
		minus_button.position=Vector2(size.x-180,8);minus_button.size=Vector2(44,44)
		walk_button.position=Vector2(10,size.y-112);walk_button.size=Vector2(size.x-20,48)
		cab_button.text="Ride to waypoint";cab_button.position=Vector2(10,size.y-58);cab_button.size=Vector2(size.x-20,48)

func open(pick_destination := false) -> void:
	expanded = true
	controller_cursor=Vector2(0.5,0.5)
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
	if destination_active and route_clock>1 and not _has_vehicle_route() and is_instance_valid(game) and is_instance_valid(game.population):
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
	return (W.LIMIT*2)/zoom if expanded else 112.0

func point(pos: Vector3) -> Vector2:
	var offset := Vector2(pos.x,pos.z)-_view_center()
	if not expanded: offset = offset.rotated(_heading())
	return map_rect.get_center()+offset/_span()*minf(map_rect.size.x,map_rect.size.y)

func world_point(screen: Vector2) -> Vector3:
	var offset := (screen-map_rect.get_center())/minf(map_rect.size.x,map_rect.size.y)*_span()
	if not expanded: offset = offset.rotated(-_heading())
	var world := _view_center()+offset
	return Vector3(world.x,city.traffic.LEVEL,world.y)

func _bound_center() -> void:
	var half:=map_rect.size/minf(map_rect.size.x,map_rect.size.y)*(W.LIMIT/zoom)
	var extent:=Vector2(maxf(0,W.LIMIT-half.x),maxf(0,W.LIMIT-half.y))
	center=center.clamp(-extent,extent)

func location_at(screen: Vector2) -> Dictionary:
	var world := world_point(screen)
	if not W.contains(world):
		var bounded:=Vector2(world.x,world.z).limit_length(W.LIMIT-12)
		world=Vector3(bounded.x,city.traffic.LEVEL,bounded.y)
	for house in city.houses:
		var local: Vector3 = house.to_local(world)
		if absf(local.x)<=5.3 and absf(local.z)<=6.3:
			return {"name":house.address,"point":house.entrance()}
	var nearest: Dictionary = {"name":ATLAS.street_at(world)+" • map waypoint","point":world}
	var gap := maxf(8,30.0/zoom)
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
		center-=event.relative/minf(map_rect.size.x,map_rect.size.y)*_span()
		_bound_center()
		queue_redraw()
		accept_event()
	if event is InputEventMouseButton and event.pressed:
		if expanded and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.8),1,16)
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

func _atlas_rect(image: Image, bounds: Rect2, color: Color) -> void:
	var a := (bounds.position+Vector2(W.LIMIT,W.LIMIT))/(W.LIMIT*2)*1024
	var b := bounds.size/(W.LIMIT*2)*1024
	image.fill_rect(Rect2i(Vector2i(a),Vector2i(b)).intersection(Rect2i(0,0,1024,1024)),color)

func _build_atlas() -> void:
	# Bake static roads, buildings and districts once; radar frames only sample this texture.
	var image := Image.create(1024,1024,false,Image.FORMAT_RGB8)
	image.fill(Color("293035"))
	for area in city.districts:
		_atlas_rect(image,area.bounds,Color("30383b") if city.districts.find(area)%2==0 else Color("343b3d"))
	for park in city.parks: _atlas_rect(image,Rect2(Vector2(park.position.x-17,park.position.z-15),Vector2(34,30)),Color("506650"))
	for site in city.outer_parks: _atlas_rect(image,Rect2(Vector2(site.point.x-25,site.point.z-25),Vector2(50,50)),Color("506650"))
	for site in city.infill.sites:
		_atlas_rect(image,Rect2(Vector2(site.point.x-20,site.point.z-20),Vector2(40,40)),Color("898573") if site.use=="shops" else Color("435d49"))
	for house in city.houses: _atlas_rect(image,Rect2(Vector2(house.position.x-5,house.position.z-6),Vector2(10,12)),Color("687071"))
	for site in W.place_sites():
		var size:Vector2=site.get("footprint",Vector2(48,40))
		_atlas_rect(image,Rect2(Vector2(site.point.x,site.point.z)-size*.5,size),Color("4b7e83") if site.kind=="robotics" else Color("82765e"))
		if site.kind=="robotics":
			_atlas_rect(image,Rect2(Vector2(site.point.x-4,site.point.z-85),Vector2(8,190)),Color("8fa5a3"))
	for color in [Color("c0c3c0"),Color("646c6e")]:
		var width := 11.0 if color==Color("c0c3c0") else 8.0
		for segment in W.road_segments():
			var a:Vector2=segment.a; var b:Vector2=segment.b
			_atlas_rect(image,Rect2(Vector2(minf(a.x,b.x)-width/2,minf(a.y,b.y)-width/2),Vector2(absf(a.x-b.x)+width,absf(a.y-b.y)+width)),color)
	for route in city.transport.routes: _bake_line(image,route.path+PackedVector3Array([route.path[0]]),route.color.darkened(.35),0)
	for line in W.rail_lines(): _bake_line(image,line.path,line.color,1)
	# Clip the urban atlas to its circular footprint, using row spans rather than a per-pixel loop.
	for row in range(1024):
		var dy:float=(row-512.0)/512.0
		var half:=floori(sqrt(maxf(0,1-dy*dy))*512)
		image.fill_rect(Rect2i(0,row,512-half,1),Color("293035"))
		image.fill_rect(Rect2i(512+half,row,512-half,1),Color("293035"))
	atlas_texture = ImageTexture.create_from_image(image)
	atlas_builds+=1

func _draw_atlas() -> void:
	var quad := PackedVector2Array([map_rect.position,Vector2(map_rect.end.x,map_rect.position.y),map_rect.end,Vector2(map_rect.position.x,map_rect.end.y)])
	var uv := PackedVector2Array()
	for corner in quad:
		var world := world_point(corner)
		uv.append((Vector2(world.x,world.z)+Vector2(W.LIMIT,W.LIMIT))/(W.LIMIT*2))
	draw_polygon(quad,PackedColorArray([Color.WHITE,Color.WHITE,Color.WHITE,Color.WHITE]),uv,atlas_texture)

func _place(world: Vector3, text: String, color: Color, icon := "") -> void:
	var p := point(world)
	if not map_rect.grow(-6).has_point(p): return
	draw_circle(p,6 if expanded else 4,color)
	if icon!="" and expanded: _caption(p+Vector2(-3,4),icon,Color("182026"),10)
	if expanded and text!="" and (not game.get_meta("phone_touch",false) or zoom>2.2 or text in ["Pickup","Ride destination","Landing / pickup","Flight destination"]):
		_caption(Vector2(clampf(p.x+8,map_rect.position.x+5,map_rect.end.x-125),p.y-7),text,color,11)

func _route(path: PackedVector3Array, color: Color, width := 3.0) -> void:
	for i in range(1,path.size()): _line(point(path[i-1]),point(path[i]),color,width)

func _draw() -> void:
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var district: Dictionary = ATLAS.at(player.global_position) if is_instance_valid(player) else ATLAS.definitions()[0]
	_caption(Vector2(14,24),"NOTTINGHAM • CITY MAP" if expanded else str(district.name).to_upper(),Color("eff1ef"),14)
	if not is_instance_valid(city): return
	draw_rect(map_rect,Color("293035"))
	if atlas_texture!=null: _draw_atlas()
	if expanded:
		for area in city.districts:
			var p := point(area.center)
			if map_rect.grow(-50).has_point(p) and (not game.get_meta("phone_touch",false) or zoom>2.2): _caption(p-Vector2(35,0),str(area.name).to_upper(),Color("a9b1b1"),13)
		if zoom>3:
			for i in range(city.CORE_Z.size()):
				var p := point(Vector3(-153,0,city.CORE_Z[i]))
				if map_rect.has_point(p): _caption(p+Vector2(0,-8),ATLAS.STREET_Z[i],Color("d0d4d2"),11)
			for i in range(city.CORE_X.size()):
				var p := point(Vector3(city.CORE_X[i],0,155))
				if map_rect.grow(-8).has_point(p):
					draw_set_transform(p+Vector2(-8,-4),-PI/2)
					_caption(Vector2.ZERO,ATLAS.STREET_X[i],Color("cbd0ce"),10)
					draw_set_transform(Vector2.ZERO)
		if zoom>5:
			for house in city.houses:
				var p := point(house.global_position)
				if map_rect.grow(-8).has_point(p): _caption(p-Vector2(4,0),str(house.house_number),Color("e2e4de"),10)
	if is_instance_valid(game) and is_instance_valid(game.rail):
		var seen:Dictionary={}
		for station in game.rail.stations:
			if seen.has(station.name): continue
			seen[station.name]=true
			_place(station.pavement,station.name if expanded else "",Color("e9c280"),"T")
		if is_instance_valid(player.riding_bus) and player.riding_bus.is_in_group("city_trains"):
			_place(player.riding_bus.global_position,player.riding_bus.route.number,Color("ffe6a4"),"T")
	for site in W.place_sites(): _place(site.get("entry",site.point),site.name if expanded and (zoom>1.3 or site.kind!="sales") else "",Color("dfc999"),site.icon)
	if is_instance_valid(game.services):
		for marker in game.services.dispatch.markers(player):_place(marker.point,str(marker.name),Color("6adebd"),str(marker.icon))
		for rental in game.services.private_hire.records.values():
			if rental.person==player:_place(rental.car.node.global_position,str(rental.car.cab_id),Color("f1cb71"),"R")
	for park in city.parks: _place(park.global_position,str(park.park_name) if expanded and zoom>1.3 else "",Color("92bd8b"),"P")
	for site in city.outer_parks: _place(site.point,str(site.name) if expanded and zoom>2 else "",Color("92bd8b"),"P")
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
			var key: String = game.economy.key_for(player)
			if game.cabs.bookings.has(key):
				var trip: Dictionary = game.cabs.bookings[key]
				if int(trip.car)>=0:
					var car: Dictionary = game.cabs.cars[int(trip.car)]
					_place(car.node.global_position,car.cab_id,Color("ffdb7b"),"V" if car.get("kind","")=="Robovan" else "A")
				if trip.destination.has("point"): _place(trip.destination.point,"Ride destination",Color("dcb3f5"))
				if trip.state in ["approaching","waiting"] and trip.has("pickup_curb"): _place(trip.pickup_curb,"Pickup",Color("70e6a5"))
	if is_instance_valid(game) and is_instance_valid(game.helicopters):
		for i in range(game.helicopters.pads.size()):
			var pad:Dictionary=game.helicopters.pads[i]
			if expanded and zoom<3 and pad.point.length()<300 and i>0: continue
			_place(pad.point,str(pad.name) if expanded and zoom>3 else "",Color("71d6f2"),"H")
		var flight_key: String=game.economy.key_for(player)
		if game.helicopters.bookings.has(flight_key):
			var trip: Dictionary=game.helicopters.bookings[flight_key]
			var helicopter: Dictionary=game.helicopters.cars[int(trip.car)]
			_place(helicopter.node.position,helicopter.cab_id,Color("71d6f2"),"H")
			if trip.state in ["approaching","waiting"]: _place(trip.pickup_curb,"Landing / pickup",Color("70e6a5"))
			if trip.destination.has("point"): _place(trip.destination.point,"Flight destination",Color("71d6f2"))
	_route(navigation_path(),Color("81e4ce"),4 if expanded else 3)
	if destination_active and not _has_vehicle_route(): _place(destination,"Waypoint",Color("a8ddec"),"+")
	if is_instance_valid(player):
		var p := point(player.global_position)
		var heading := _heading() if expanded else 0.0
		var direction := Vector2(-sin(heading),-cos(heading))
		var side := Vector2(-direction.y,direction.x)
		if map_rect.grow(-8).has_point(p):
			draw_colored_polygon(PackedVector2Array([p,p+direction*25+side*13,p+direction*25-side*13]),Color(1,1,1,0.08))
			draw_colored_polygon(PackedVector2Array([p+direction*8,p-direction*5+side*5,p-direction*2,p-direction*5-side*5]),Color.WHITE)
	if expanded and controller_cursor.x>=0 and not game.get_meta("phone_touch",false):
		var cross:=map_rect.position+controller_cursor*map_rect.size
		draw_line(cross-Vector2(12,0),cross+Vector2(12,0),Color.WHITE,2)
		draw_line(cross-Vector2(0,12),cross+Vector2(0,12),Color.WHITE,2)
		_caption(Vector2(14,42),"Stick / arrows: cursor   × / Enter: choose   L1/R1: zoom   Circle: back",Color.WHITE,12)
	if expanded:
		_caption(Vector2(14,size.y-134 if game.get_meta("phone_touch",false) else size.y-82),"A Cabs  V Robovan  T Rail  H Helipad" if game.get_meta("phone_touch",false) else "A Aurora   V Robovan   B Bus stops   T Rail   H Helipad / Home   Gold: City Circle",Color("c9cecc"),12)
		if not game.get_meta("phone_touch",false):_caption(Vector2(14,size.y-60),str(selected_place.get("name","Click a place • scroll to zoom • right-drag to pan • north is up")),Color("f0e6c8"),12)
		else:_caption(Vector2(14,42),str(selected_place.get("name","Tap a place • + / − zoom")),Color("f0e6c8"),12)
	else:
		_caption(Vector2(14,size.y-12),"Tap to open map" if game.get_meta("phone_touch",false) else ATLAS.street_at(player.global_position)+" • N: map",Color("c4cecc"),11)
	_caption(map_rect.position+Vector2(5,14),"N" if expanded else "↑",Color.WHITE,13)

func _has_vehicle_route() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.services):return false
	var key:String=game.economy.key_for(player)
	return not game.services.contract_for(player).is_empty() or game.cabs.bookings.has(key) or game.helicopters.bookings.has(key) or is_instance_valid(player.riding_bus) or not game.services.private_hire.route_for(player).is_empty()

func navigation_path() -> PackedVector3Array:
	if not is_instance_valid(game) or not is_instance_valid(game.services):return walking_route
	var work:PackedVector3Array=game.services.route_for_driver(player)
	if not work.is_empty():return work
	var cab:PackedVector3Array=game.cabs.remaining_route(player)
	if not cab.is_empty():return cab
	var air:PackedVector3Array=game.helicopters.remaining_route(player)
	if not air.is_empty():return air
	if is_instance_valid(player.riding_bus):
		return game.services.route_for_vehicle(player.riding_bus,"Train" if player.riding_bus.is_in_group("city_trains") else "Bus")
	var rental:PackedVector3Array=game.services.private_hire.route_for(player)
	if not rental.is_empty():return rental
	return walking_route if not _has_vehicle_route() else PackedVector3Array()

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.065,0.96)
	style.set_corner_radius_all(9)
	return style

func _bake_line(image: Image,path:PackedVector3Array,color:Color,width:int) -> void:
	for i in range(1,path.size()):
		var a:Vector2=(Vector2(path[i-1].x,path[i-1].z)+Vector2(W.LIMIT,W.LIMIT))/(W.LIMIT*2)*1024
		var b:Vector2=(Vector2(path[i].x,path[i].z)+Vector2(W.LIMIT,W.LIMIT))/(W.LIMIT*2)*1024
		var steps:=maxi(1,ceili(maxf(absf(b.x-a.x),absf(b.y-a.y))))
		for step in range(steps+1):
			var p:=a.lerp(b,float(step)/steps)
			for x in range(-width,width+1):
				for y in range(-width,width+1):
					var px:=roundi(p.x)+x; var py:=roundi(p.y)+y
					if px>=0 and px<1024 and py>=0 and py<1024: image.set_pixel(px,py,color)
