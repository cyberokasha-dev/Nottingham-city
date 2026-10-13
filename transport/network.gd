extends Node3D
const G = preload("res://transport/geometry.gd")
var traffic: Node3D
var routes: Array[Dictionary] = []
var buses: Array[Node3D] = []
var stops: Array[Dictionary] = []
var guide: PanelContainer
var stop_refresh := 0.0

func _ready() -> void:
	for definition in preload("res://transport/routes.gd").definitions():
		var route := build_route(definition)
		routes.append(route)
		for stop in route.stops:
			_build_stop(stop,route)
		for i in range(3):
			var bus := preload("res://transport/bus.gd").new()
			bus.manager = self
			bus.route = route
			bus.distance = float(route.length)*i/3.0
			add_child(bus)
			buses.append(bus)
	_build_guide()

func build_route(definition: Dictionary) -> Dictionary:
	var route := definition.duplicate(true)
	var points: Array = route.points
	var path := PackedVector3Array()
	for i in range(points.size()):
		var a: Vector2 = points[(i+points.size()-1)%points.size()]
		var b: Vector2 = points[i]
		var c: Vector2 = points[(i+1)%points.size()]
		var incoming := (b-a).normalized()
		var outgoing := (c-b).normalized()
		var left_in := Vector2(incoming.y,-incoming.x)*2.8
		var left_out := Vector2(outgoing.y,-outgoing.x)*2.8
		var start := b-incoming*10.0+left_in
		var end := b+outgoing*10.0+left_out
		var control := b+left_in+left_out
		for step in range(13):
			var t := step/12.0
			var p := (1-t)*(1-t)*start+2*(1-t)*t*control+t*t*end
			path.append(Vector3(p.x,traffic.LEVEL,p.y))
	var lengths: Array[float] = [0.0]
	for i in range(1,path.size()):
		lengths.append(lengths[-1]+path[i-1].distance_to(path[i]))
	var total: float = lengths[-1]+path[-1].distance_to(path[0])
	route.path = path
	route.lengths = lengths
	route.length = total
	route.stops = []
	# Stops lie halfway along each straight, outside junctions, on the left pavement.
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var direction := (b-a).normalized()
		var left := Vector2(direction.y,-direction.x)
		var middle := (a+b)*0.5
		var road_point := Vector3(middle.x+left.x*2.8,traffic.LEVEL,middle.y+left.y*2.8)
		var best := INF
		var along := 0.0
		for j in range(path.size()):
			var k := (j+1)%path.size()
			var nearest := Geometry3D.get_closest_point_to_segment(road_point,path[j],path[k])
			var gap := nearest.distance_squared_to(road_point)
			if gap < best:
				best = gap
				along = lengths[j]+path[j].distance_to(nearest)
		var stop := {"name":definition.stops[i],"distance":along,"position":road_point,
			"pavement":Vector3(middle.x+left.x*7.7,traffic.LEVEL,middle.y+left.y*7.7),"direction":Vector3(direction.x,0,direction.y),"route":route.number,"waiting":[],"label":null}
		route.stops.append(stop)
	route.stops.sort_custom(func(a,b): return a.distance<b.distance)
	return route

func sample(route: Dictionary, distance: float) -> Dictionary:
	var d := fposmod(distance,float(route.length))
	var lengths: Array = route.lengths
	var path: PackedVector3Array = route.path
	var i := lengths.bsearch(d,false)-1
	i = clampi(i,0,path.size()-1)
	var next := (i+1)%path.size()
	var length := path[i].distance_to(path[next])
	var t := clampf((d-float(lengths[i]))/maxf(length,0.001),0,1)
	return {"position":path[i].lerp(path[next],t),"direction":(path[next]-path[i]).normalized()}

func _build_stop(stop: Dictionary, route: Dictionary) -> void:
	stops.append(stop)
	var shelter := Node3D.new()
	shelter.position = stop.pavement
	shelter.rotation.y = atan2(stop.direction.x,stop.direction.z)
	add_child(shelter)
	var steel := G.material(Color("425363"),0.65)
	var glass := G.material(Color(0.55,0.8,0.84,0.3),0.1)
	var paint := G.material(route.color)
	for z in [-1.8,1.8]:
		G.tube(shelter,Vector3(0.6,0,z),Vector3(0.6,2.6,z),0.045,steel)
	G.box(shelter,Vector3(0.63,1.4,0),Vector3(0.055,1.9,3.6),glass)
	G.box(shelter,Vector3(0,2.65,0),Vector3(1.8,0.12,4.1),steel)
	G.box(shelter,Vector3(0.2,0.55,0),Vector3(0.45,0.12,2.5),steel)
	G.tube(shelter,Vector3(-0.8,0,2.2),Vector3(-0.8,3.3,2.2),0.04,steel)
	G.box(shelter,Vector3(-0.8,2.95,2.2),Vector3(0.15,0.75,0.6),paint)
	var number := G.label(shelter,route.number,Vector3(-0.91,3.0,2.2),34)
	number.rotation.y = -PI/2
	var label := G.label(shelter,stop.name+"\n"+route.number+"  "+route.name,Vector3(0.56,2.1,0),22)
	label.rotation.y = -PI/2
	stop.label = label
	G.merge(shelter)
	var marking := G.label(self,"BUS\nSTOP",stop.position+Vector3(0,0.04,0),42)
	marking.rotation = Vector3(-PI/2,atan2(stop.direction.x,stop.direction.z),0)
	marking.modulate = Color("f3d96c")
	for i in range(2):
		var person := preload("res://transport/crowd_person.gd").new()
		person.variant = stops.size()+i
		person.position = stop.pavement+stop.direction*(float(i)-0.5)*0.9
		person.rotation.y = shelter.rotation.y-PI/2
		add_child(person)
		stop.waiting.append(person)

func exchange(bus: Node3D, stop: Dictionary) -> void:
	var alighting := preload("res://transport/crowd_person.gd").new()
	alighting.variant = bus.services_completed+3
	add_child(alighting)
	alighting.global_position = bus.entrance()
	alighting.walking = true
	var exit_path := create_tween()
	exit_path.tween_property(alighting,"global_position",stop.pavement+stop.direction*5,4.0)
	exit_path.tween_callback(alighting.queue_free)
	var boarded := 0
	for person in stop.waiting:
		if not person.visible:
			person.position = stop.pavement+stop.direction*float(boarded)
		person.show()
		person.walking = true
		var walk := create_tween()
		walk.tween_interval(1.1+boarded*0.5)
		walk.tween_property(person,"global_position",bus.entrance(),2.0)
		walk.tween_callback(func(): person.hide(); person.walking=false)
		boarded += 1
	bus.passengers = clampi(bus.passengers+boarded-1,0,40)
	for i in range(bus.passenger_visuals.size()):
		bus.passenger_visuals[i].visible = i<bus.passengers

func nearest_bus(person: Node3D) -> Node3D:
	for bus in buses:
		if bus.state=="dwell" and bus.model.door_fraction>=0.9 and not is_instance_valid(bus.rider) and person.global_position.distance_to(bus.entrance())<4.0:
			return bus
	return null

func stop_hint(person: Node3D) -> String:
	for stop in stops:
		if person.global_position.distance_to(stop.pavement)<5.0:
			var seconds := INF
			for bus in buses:
				if bus.route.number == stop.route:
					seconds = minf(seconds,fposmod(float(stop.distance)-bus.distance,float(bus.route.length))/8.0)
			return "%s • Route %s • next bus ~%ds · M: route guide" % [stop.name,stop.route,ceili(seconds)]
	return ""

func _build_guide() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	guide = PanelContainer.new()
	guide.position = Vector2(35,90)
	guide.custom_minimum_size = Vector2(650,350)
	layer.add_child(guide)
	var rows := VBoxContainer.new()
	guide.add_child(rows)
	var title := Label.new()
	title.text = "NOTTINGHAM • BUS GUIDE     M to close"
	title.add_theme_font_size_override("font_size",23)
	rows.add_child(title)
	for route in routes:
		var line := Label.new()
		line.text = route.number+"  "+route.name+"\n    "+" → ".join(route.stops.map(func(s): return s.name))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 630
		line.add_theme_color_override("font_color",route.color)
		rows.add_child(line)
	var help := Label.new()
	help.text = "Wait at a shelter. E by an open front door: board.\nE while travelling: request stop. E at an open stop: get off.\nRoads and route loops are compressed game interpretations.\nC1 is a fictional connector with London-inspired buses."
	rows.add_child(help)
	guide.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
		guide.visible = not guide.visible
