extends Node3D
const G = preload("res://transport/geometry.gd")
var traffic: Node3D
var economy: Node
var recitation: CanvasLayer
var timetable_enabled := true
var elapsed := 0.0
var departures := {}
var queue_clock := 0.0
var routes: Array[Dictionary] = []
var buses: Array[Node3D] = []
var stops: Array[Dictionary] = []
var guide: PanelContainer
var stop_refresh := 0.0
var seeded := false

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
			bus.set_meta("quran_seed",buses.size())
			add_child(bus)
			buses.append(bus)
	for bus in buses:
		for attempt in range(120):
			var clear := true
			for x in traffic.ROAD_X:
				for z in traffic.ROAD_Z:
					if absf(bus.position.x-x)<14 and absf(bus.position.z-z)<14: clear=false
			for other in buses:
				if other==bus: break
				if bus.global_position.distance_to(other.global_position)<14: clear=false
			for item in traffic.cars:
				if bus.global_position.distance_to(item.node.global_position)<10: clear=false
			if clear: break
			bus.distance = fposmod(bus.distance+11.0,float(bus.route.length))
			bus._update_position()
		bus.find_next_stop()
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
	# Split every long street at ALL grid crossings. A stop must fit between
	# junctions, not merely halfway between two distant route waypoints.
	var stop_sites: Array[Dictionary] = []
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		var direction := (b-a).normalized()
		var cuts: Array[Vector2] = [a,b]
		for cross in (traffic.ROAD_Z if absf(direction.y)>0.9 else traffic.ROAD_X):
			var p := Vector2(a.x,cross) if absf(direction.y)>0.9 else Vector2(cross,a.y)
			if (p-a).dot(direction)>1 and (b-p).dot(direction)>1: cuts.append(p)
		cuts.sort_custom(func(x,y): return (x-a).length_squared()<(y-a).length_squared())
		for j in range(cuts.size()-1):
			if cuts[j].distance_to(cuts[j+1])<36: continue
			stop_sites.append({"middle":(cuts[j]+cuts[j+1])*0.5,"direction":direction,"name":definition.stops[i]+(" • local stop "+str(j+1) if j>0 else "")})
	for site in stop_sites:
		var direction: Vector2 = site.direction
		var left := Vector2(direction.y,-direction.x)
		var middle: Vector2 = site.middle
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
		var stop := {"name":site.name,"distance":along,"position":road_point,
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
	for i in range(4+stops.size()%3):
		var person := preload("res://transport/crowd_person.gd").new()
		person.variant = stops.size()+i
		person.set_meta("commuter_id","commuter/"+str(stops.size())+"/"+str(i))
		person.position = stop.pavement+stop.direction*(float(i)-0.5)*0.9
		person.rotation.y = shelter.rotation.y-PI/2
		add_child(person)
		stop.waiting.append(person)

func reserve_departure(number: String) -> float:
	var departure: float = maxf(elapsed,float(departures.get(number,0)))
	departures[number] = departure+90.0
	return departure

func exchange(bus: Node3D, stop: Dictionary) -> void:
	for record in bus.manifest.duplicate():
		if int(record.destination)!=bus.stop_index and bus.stop_index!=0: continue
		var person: Node3D=record.person
		person.show()
		person.walking=false
		person.set_meta("ready_at",elapsed+45)
		var exit_path: Array[Vector3]=bus.boarding_path(int(record.seat))
		exit_path.reverse()
		# Exit at the middle door so arriving passengers do not cross the front queue.
		exit_path.resize(exit_path.size()-3)
		exit_path.append(Vector3(0,0.6,-1.2))
		exit_path.append(Vector3(1.7,0.05,-1.2))
		var destination: Vector3=stop.pavement+stop.direction*float(stop.waiting.size())*0.8
		_transfer(bus,person,exit_path,destination,false)
		stop.waiting.append(person)
		bus.manifest.erase(record)
	bus.passengers=bus.manifest.size()
	bus.rebuild_cabin()

func board_next(bus: Node3D) -> bool:
	if economy==null or bus.stop_index<0 or bus.manifest.size()>=19 or bus.dwell_elapsed>=43: return false
	var stop: Dictionary=bus.route.stops[bus.stop_index]
	for person in stop.waiting.duplicate():
		if not is_instance_valid(person) or not person.visible or person.walking or elapsed<float(person.get_meta("ready_at",0)): continue
		var seat_index: int=bus.free_seat()
		if seat_index<0: return false
		if economy.key_for(person)=="": economy.register(person,str(person.get_meta("commuter_id")),15000)
		if not economy.charge(person,200,"Bus "+bus.route.number+" fare"):
			person.set_meta("ready_at",elapsed+60)
			continue
		stop.waiting.erase(person)
		person.walking=true
		person.set_meta("bus_seat",seat_index)
		var ride_stops:=mini(bus.route.stops.size()-1,3+int(person.variant)%5)
		bus.manifest.append({"person":person,"seat":seat_index,"destination":(bus.stop_index+ride_stops)%bus.route.stops.size()})
		bus.passengers=bus.manifest.size()
		_transfer(bus,person,bus.boarding_path(seat_index),Vector3.ZERO,true)
		bus.dwell=minf(60.0-bus.dwell_elapsed,maxf(bus.dwell,2.0))
		return true
	return false

func _transfer(bus: Node3D, person: Node3D, points: Array[Vector3], pavement: Vector3, entering: bool) -> void:
	bus.passenger_transfers+=1
	var walk:=create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	walk.tween_interval(0.7) # Doors open before anyone crosses the threshold.
	var previous: Vector3=bus.to_local(person.global_position)
	for index in range(points.size()):
		var point: Vector3=points[index]
		if entering and index==points.size()-1:
			walk.tween_callback(func(): person.walking=false; person.set_seated(true))
		if not entering and index==2:
			walk.tween_callback(func(): person.set_seated(false); person.walking=true)
		var duration: float=bus.transfer_duration(previous,point)
		var direction: Vector3=point-previous
		if direction.length_squared()>0.01:
			var facing: float=bus.rotation.y+atan2(direction.x,direction.z)
			walk.tween_property(person,"rotation:y",facing,minf(0.15,duration))
		walk.tween_property(person,"global_position",bus.to_global(point),duration)
		previous=point
	if not entering: walk.tween_property(person,"global_position",pavement,previous.distance_to(bus.to_local(pavement))/2.4)
	walk.tween_callback(func():
		if not is_instance_valid(person) or not is_instance_valid(bus): return
		if entering:
			person.reparent(bus)
			person.position=bus.npc_seat(int(person.get_meta("bus_seat")))
			person.rotation=Vector3.ZERO
			person.scale=Vector3(0.92,0.94,0.92)
			person.walking=false
			person.set_seated(true)
		else:
			person.reparent(self)
			person.scale=Vector3.ONE
			person.walking=false
		bus.passenger_transfers=maxi(0,bus.passenger_transfers-1)
		bus.rebuild_cabin())

func seed_services() -> void:
	if seeded or economy==null: return
	seeded = true
	var saving: bool = economy.enabled
	economy.enabled = false # One save after the initial paid passenger manifest is assembled.
	for i in range(buses.size()):
		var bus: Node3D = buses[i]
		for seat in range(12+i%7):
			var person := preload("res://transport/crowd_person.gd").new()
			person.variant = i*19+seat
			bus.add_child(person)
			economy.register(person,"commuter/onboard/"+str(i)+"/"+str(seat),15000)
			if not economy.charge(person,200,"Bus "+bus.route.number+" fare"):
				person.free()
				continue
			person.set_meta("bus_seat",seat)
			person.position = bus.npc_seat(seat)
			person.scale = Vector3(0.92,0.94,0.92)
			person.set_seated(true)
			bus.manifest.append({"person":person,"seat":seat,"destination":(bus.next_stop+2+seat%5)%bus.route.stops.size()})
		bus.passengers = bus.manifest.size()
		bus.rebuild_cabin()
	economy.enabled = saving
	economy.save()

func _process(delta: float) -> void:
	elapsed += delta
	queue_clock += delta
	if queue_clock<2:
		return
	queue_clock = 0
	for stop in stops:
		for i in range(stop.waiting.size()):
			var person: Node3D = stop.waiting[i]
			if person.walking:
				continue
			var target: Vector3 = stop.pavement+stop.direction*(float(i)*0.85)
			person.position = target
			person.rotation.y = atan2(-stop.direction.z,stop.direction.x)

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
