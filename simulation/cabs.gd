extends Node3D
# Aurora cars and Robovans share dispatch, traffic, ranks and one booking per customer.
const F = preload("res://vehicles/vehicle_factory.gd")
const ROBOTICS_ROAD_ENTRY := Vector3(-60.0,-5.02,-437.2)
const ROBOTICS_ENTRY := Vector3(-40.0,-5.02,-422.0)
var game: Node3D
var economy: Node
var graph := AStar3D.new()
var cars: Array[Dictionary] = []
var bookings: Dictionary = {}
var serial := 0
var update_clock := 0.0
var npc_clock := 0.0
var elapsed := 0.0
var last_notice := {}
var ranks: Array[Dictionary] = []
var robotics_bays: Array[Dictionary] = []

func _ready() -> void:
	_build_lane_graph()
	ranks = game.city.districts.duplicate(true)
	_build_ranks()
	# Four separated full-size bays align with the physical pads inside Robotics Plaza.
	for x in [9.0,19.0,29.0,39.0]:
		robotics_bays.append({"point":Vector3(x,-5.02,-321.0),"vehicle":null})
	for i in range(ranks.size()*2+6):
		var model := Node3D.new()
		var kind:="Robovan" if i>=12 or i in [6,8,9,11] else "Aurora"
		model.name = kind+str(i+1)
		model.set_meta("service_kind",kind)
		model.set_meta("traffic_half_length",3.15 if kind=="Robovan" else 2.3)
		model.set_meta("traffic_half_width",1.16 if kind=="Robovan" else 1.0)
		add_child(model)
		var rank_index:=i%ranks.size()
		var rank: Dictionary = ranks[rank_index]
		model.rotation.y = float(rank.heading)
		var forward:=Vector3(sin(float(rank.heading)),0,cos(float(rank.heading)))
		model.position = rank.rank+forward*floori(float(i)/ranks.size())*16.0
		if kind=="Robovan":model.position+=Vector3(forward.z,0,-forward.x)
		var graphics:Node3D = preload("res://vehicles/robovan_model.gd").make(i+1) if kind=="Robovan" else preload("res://vehicles/aurora_model.gd").make(i+1)
		model.add_child(graphics)
		preload("res://transport/vehicle_motion.gd").setup(model,graphics)
		for property in ["wheels","doors","displays","label","marker"]:
			model.set_meta(property,graphics.get_meta(property))
		model.set_meta("graphics",graphics)
		var label: Label3D = graphics.get_meta("label")
		game.city.traffic.autonomous_nodes.append(model)
		model.add_child(preload("res://simulation/service_audio.gd").new())
		var conversation := preload("res://simulation/cab_dialogue.gd").new()
		conversation.personality = i%3
		model.add_child(conversation)
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.collision_layer = 2
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.3,2.3,6.2) if kind=="Robovan" else Vector3(1.8,1.5,4.3)
		shape.shape = box
		shape.position.y = 1.35 if kind=="Robovan" else .9
		body.add_child(shape)
		model.add_child(body)
		cars.append({"node":model,"booking":"","state":"idle","path":PackedVector3Array(),"index":0,"speed":0.0,"label":label,"kind":kind,"cab_id":("RV-%03d" if kind=="Robovan" else "AR-%03d") % (i+1),"half_length":3.15 if kind=="Robovan" else 2.5,"body_size":box.size,"rank":rank_index,"home_slot":model.position,"idle_clock":0.0,"fast":false,"manual":false,"service_after":70.0+float(i)*45.0,"service_clock":0.0,"service_bay":-1})

func _free_robotics_bay() -> int:
	for i in range(robotics_bays.size()):
		if not is_instance_valid(robotics_bays[i].get("vehicle")):
			return i
	return -1

func _robotics_inner_points(bay_point:Vector3) -> PackedVector3Array:
	# A shared one-way aisle enters the south gate and skirts the demonstration court.
	return PackedVector3Array([
		ROBOTICS_ENTRY,
		Vector3(-32.0,-5.02,-418.0),
		Vector3(-22.0,-5.02,-412.0),
		Vector3(-15.0,-5.02,-405.0),
		Vector3(-15.0,-5.02,-396.0),
		Vector3(-25.0,-5.02,-382.0),
		Vector3(-30.0,-5.02,-365.0),
		Vector3(-30.0,-5.02,-350.0),
		Vector3(-20.0,-5.02,-340.0),
		Vector3(-5.0,-5.02,-330.0),
		bay_point
	])

func _robotics_path_to_bay(from:Vector3,bay_point:Vector3,facing:Vector3=Vector3.ZERO) -> PackedVector3Array:
	# Join the lane graph at the real road edge, then follow the short access spur to the gate.
	# The gate itself sits 15 m inside the road edge, so it is not a graph destination.
	var path:=_road_path(from,ROBOTICS_ROAD_ENTRY,facing)
	if path.is_empty():return PackedVector3Array()
	if path[-1].distance_to(ROBOTICS_ROAD_ENTRY)>5.0:return PackedVector3Array()
	if path[-1].distance_to(ROBOTICS_ROAD_ENTRY)>.05:path.append(ROBOTICS_ROAD_ENTRY)
	if path[-1].distance_to(ROBOTICS_ENTRY)>.05:path.append(ROBOTICS_ENTRY)
	var inside:=_robotics_inner_points(bay_point)
	for i in range(1,inside.size()):path.append(inside[i])
	return path

func _release_robotics_bay(car:Dictionary) -> void:
	var index:=int(car.get("service_bay",-1))
	if index>=0 and index<robotics_bays.size() and robotics_bays[index].get("vehicle")==car.node:
		robotics_bays[index]["vehicle"]=null
	car.service_bay=-1

func curb(point: Vector3) -> Vector3:
	var best:=Vector3.ZERO; var gap:=INF
	var p:=Vector2(point.x,point.z)
	for segment in preload("res://town/world_layout.gd").road_segments():
		var nearest:=Geometry2D.get_closest_point_to_segment(p,segment.a,segment.b)
		var distance:=nearest.distance_squared_to(p)
		if distance<gap:
			gap=distance; best=Vector3(nearest.x,game.city.traffic.LEVEL,nearest.y)
	return best

const DIRECTIONS := [Vector3(0,0,1),Vector3(1,0,0),Vector3(0,0,-1),Vector3(-1,0,0)]
const TURN_RADIUS := 10.0

func _lane_id(ix: int, iz: int, heading: int, outgoing: bool) -> int:
	return (ix*game.city.ROAD_Z.size()+iz)*8+heading*2+int(outgoing)

func _build_lane_graph() -> void:
	graph.clear()
	var layout=preload("res://town/world_layout.gd")
	for ix in range(game.city.ROAD_X.size()):
		for iz in range(game.city.ROAD_Z.size()):
			var center:=Vector3(game.city.ROAD_X[ix],game.city.traffic.LEVEL,game.city.ROAD_Z[iz])
			for heading in range(4):
				var direction:Vector3=DIRECTIONS[heading]
				var left:=Vector3(direction.z,0,-direction.x)*2.8
				for outgoing in [false,true]:
					var road_point:Vector3=center+direction*TURN_RADIUS*(1 if outgoing else -1)
					if layout.on_road(road_point): graph.add_point(_lane_id(ix,iz,heading,outgoing),road_point+left)
	for ix in range(game.city.ROAD_X.size()):
		for iz in range(game.city.ROAD_Z.size()):
			var center:=Vector3(game.city.ROAD_X[ix],game.city.traffic.LEVEL,game.city.ROAD_Z[iz])
			for heading in range(4):
				var entry:=_lane_id(ix,iz,heading,false)
				if graph.has_point(entry):
					for next_heading in range(4):
						var exit:=_lane_id(ix,iz,next_heading,true)
						if graph.has_point(exit): graph.connect_points(entry,exit,false)
				var nx:=ix+int(DIRECTIONS[heading].x); var nz:=iz+int(DIRECTIONS[heading].z)
				if nx<0 or nx>=game.city.ROAD_X.size() or nz<0 or nz>=game.city.ROAD_Z.size(): continue
				var exit:=_lane_id(ix,iz,heading,true)
				var neighbor:=_lane_id(nx,nz,heading,false)
				var next_center:=Vector3(game.city.ROAD_X[nx],center.y,game.city.ROAD_Z[nz])
				if graph.has_point(exit) and graph.has_point(neighbor) and layout.connected(center,next_center): graph.connect_points(exit,neighbor,false)

func _road_anchor(point: Vector3, facing := Vector3.ZERO) -> Dictionary:
	var center := curb(point)
	var vertical: bool = preload("res://town/world_layout.gd").on_road(center+Vector3(0,0,1)) and preload("res://town/world_layout.gd").on_road(center-Vector3(0,0,1))
	var side: float = point.x-center.x if vertical else center.z-point.z
	var heading := (0 if side>=0 else 2) if vertical else (1 if side>=0 else 3)
	if facing.length()>0.5:
		var best := -INF
		for h in range(4):
			if (h%2==0)!=vertical: continue
			var dot: float = DIRECTIONS[h].dot(facing)
			if dot>best:
				best = dot
				heading = h
	var direction: Vector3 = DIRECTIONS[heading]
	var left := Vector3(direction.z,0,-direction.x)
	return {"center":center,"heading":heading,"direction":direction,"point":center+left*2.8}

func _safe_destination(point: Vector3) -> Dictionary:
	var anchor := _road_anchor(point)
	var vertical: bool = int(anchor.heading)%2==0
	var crossings: Array = game.city.ROAD_Z if vertical else game.city.ROAD_X
	var coordinate: float = anchor.center.z if vertical else anchor.center.x
	var closest := INF
	var selected := coordinate
	for i in range(crossings.size()-1):
		var candidate := clampf(coordinate,float(crossings[i])+18,float(crossings[i+1])-18)
		if absf(candidate-coordinate)<closest:
			closest = absf(candidate-coordinate)
			selected = candidate
	if vertical:
		anchor.center.z = selected
		anchor.point.z = selected
	else:
		anchor.center.x = selected
		anchor.point.x = selected
	return anchor

# Station bays use a protected flat approach from the distributor road, separate from the rail corridor.
func path_between(from: Vector3, destination: Vector3, facing := Vector3.ZERO) -> PackedVector3Array:
	var rail = game.get("rail")
	if rail==null: return _road_path(from,destination,facing)
	var station: Dictionary = rail.bay_for(destination)
	var leaving: Dictionary = rail.at_bay(from)
	var origin := from
	var prefix := PackedVector3Array()
	if not leaving.is_empty() and leaving.has("bay"):
		var down: PackedVector3Array = rail.ramp_up(leaving)
		for i in range(down.size()-1,-1,-1): prefix.append(down[i])
		prefix.append(rail.ramp_foot(leaving))
		origin = rail.ramp_foot(leaving)
		facing = Vector3.ZERO
	if station.is_empty():
		var road := _road_path(origin,destination,facing)
		if road.is_empty(): return road
		return prefix+road if not prefix.is_empty() else road
	var foot: Vector3 = rail.ramp_foot(station)
	var approach := _road_path(origin,foot,facing)
	if approach.is_empty(): return approach
	var up: PackedVector3Array = rail.ramp_up(station)
	return prefix+approach+up

func _road_path(from: Vector3, destination: Vector3, facing := Vector3.ZERO) -> PackedVector3Array:
	# Clear short local approaches do not need a whole block-long lane loop.
	var direct:=_direct_drive_path(from,destination,facing)
	if not direct.is_empty():return direct
	var start := _road_anchor(from,facing)
	var prefix := PackedVector3Array()
	var lateral: float = (start.point-from).cross(start.direction).length()
	if facing.length()>0.5 and lateral>0.3 and lateral<4.5:
		# Leave a curb in a forward S-curve, never by rotating sideways into traffic.
		var room := 8.0
		for crossing in (game.city.ROAD_Z if int(start.heading)%2==0 else game.city.ROAD_X):
			var coordinate: float = from.z if int(start.heading)%2==0 else from.x
			var ahead: float = (float(crossing)-coordinate)*(start.direction.z if int(start.heading)%2==0 else start.direction.x)
			if ahead>0: room=minf(room,maxf(0,ahead-10.5))
		room = maxf(2.0,room)
		start.point+=start.direction*room
		var a: Vector3 = from+start.direction*room*0.45
		var b: Vector3 = start.point-start.direction*room*0.45
		prefix.append(from)
		for step in range(1,13):
			var t := step/12.0
			prefix.append(pow(1-t,3)*from+3*pow(1-t,2)*t*a+3*(1-t)*t*t*b+t*t*t*start.point)
	var finish := _safe_destination(destination)
	var direction: Vector3 = start.direction
	var offset: Vector3 = finish.point-start.point
	if int(start.heading)==int(finish.heading) and offset.cross(direction).length()<0.1 and offset.dot(direction)>=-0.1:
		return prefix+PackedVector3Array([start.point,finish.point])
	var entry := -1
	var exit := -1
	var entry_gap := INF
	var exit_gap := INF
	for id in graph.get_point_ids():
		var h := int(id/2)%4
		var position := graph.get_point_position(id)
		if id%2==0 and h==int(start.heading):
			var delta: Vector3 = position-start.point
			var ahead := delta.dot(start.direction)
			if delta.cross(start.direction).length()<0.1 and ahead>=-0.1 and ahead<entry_gap:
				entry = id
				entry_gap = ahead
		if id%2==1 and h==int(finish.heading):
			var delta: Vector3 = finish.point-position
			var ahead := delta.dot(finish.direction)
			if delta.cross(finish.direction).length()<0.1 and ahead>=-0.1 and ahead<exit_gap:
				exit = id
				exit_gap = ahead
	# When a car is already inside a junction, join its outgoing lane first.
	if entry<0:
		for id in graph.get_point_ids():
			if id%2==1 and int(id/2)%4==int(start.heading):
				var delta: Vector3 = graph.get_point_position(id)-start.point
				if delta.cross(direction).length()<0.1 and delta.dot(direction)>=-0.1 and delta.length()<entry_gap:
					entry = id
					entry_gap = delta.length()
	if entry<0 or exit<0:
		return PackedVector3Array() # Dispatcher reports an unavailable road, never cuts across homes.
	var ids := graph.get_id_path(entry,exit)
	if ids.is_empty(): return PackedVector3Array()
	var path := prefix+PackedVector3Array([start.point])
	for i in range(ids.size()):
		var point := graph.get_point_position(ids[i])
		if i>0 and ids[i-1]%2==0 and ids[i]%2==1 and int(ids[i-1]/8)==int(ids[i]/8):
			var old_direction: Vector3 = DIRECTIONS[int(ids[i-1]/2)%4]
			var new_direction: Vector3 = DIRECTIONS[int(ids[i]/2)%4]
			if old_direction.dot(new_direction)<0.5:
				var previous := path[-1]
				if old_direction.dot(new_direction)<-.9:
					# A compact U-turn stays inside the junction instead of touring
					# the neighbourhood just to reach the other side of the road.
					var a:=previous+old_direction*6
					var b:=point-new_direction*6
					for step in range(1,17):
						var t:=step/16.0
						path.append(pow(1-t,3)*previous+3*pow(1-t,2)*t*a+3*(1-t)*t*t*b+t*t*t*point)
					continue
				var control := previous+old_direction*TURN_RADIUS
				control += Vector3(new_direction.z,0,-new_direction.x)*2.8
				# Intersect the entry/exit lane tangents to keep the arc on asphalt.
				control = Vector3(point.x,point.y,previous.z) if absf(old_direction.x)>0.9 else Vector3(previous.x,point.y,point.z)
				for step in range(1,9):
					var t := step/8.0
					path.append((1-t)*(1-t)*previous+2*(1-t)*t*control+t*t*point)
				continue
		if path[-1].distance_to(point)>0.05: path.append(point)
	if path[-1].distance_to(finish.point)>0.05: path.append(finish.point)
	return path

func _static_gap(from:Vector3,direction:Vector3,requested:float,size:=Vector3(1.8,1.35,4.2)) -> float:
	if requested<=.0001:return requested
	var query:=PhysicsShapeQueryParameters3D.new()
	if not has_meta("drive_shapes"):set_meta("drive_shapes",{})
	var shapes:Dictionary=get_meta("drive_shapes")
	if not shapes.has(size):
		var shape:=BoxShape3D.new();shape.size=size;shapes[size]=shape
	query.shape=shapes[size]
	query.transform=Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.z)),from+Vector3(0,size.y*.5+.2,0))
	query.motion=direction*requested;query.collision_mask=1
	var safe:=get_world_3d().direct_space_state.cast_motion(query)
	return requested*float(safe[0])

func _direct_drive_path(from:Vector3,destination:Vector3,facing:Vector3) -> PackedVector3Array:
	var offset:=destination-from;offset.y=0
	if offset.length()>90 or offset.length()<1:return PackedVector3Array()
	var direction:=offset.normalized()
	if facing.length()>.5 and facing.dot(direction)<.3:return PackedVector3Array()
	var a:=from+(facing.normalized() if facing.length()>.5 else direction)*minf(6,offset.length()*.25)
	var b:=destination-direction*minf(6,offset.length()*.25)
	var path:=PackedVector3Array([from])
	for step in range(1,13):
		var t:=step/12.0
		var point:=pow(1-t,3)*from+3*pow(1-t,2)*t*a+3*(1-t)*t*t*b+t*t*t*destination
		var segment:Vector3=point-path[-1]
		if _static_gap(path[-1],segment.normalized(),segment.length())<segment.length()-.01:return PackedVector3Array()
		path.append(point)
	return path

func quote(person: Node3D, destination: Vector3) -> int:
	var path := path_between(person.global_position,destination)
	var length := 0.0
	for i in range(1,path.size()):
		length += path[i-1].distance_to(path[i])
	return 300+int(ceil(length*3.0))

func book(person: Node3D, destination: Dictionary = {}, passenger_name: String = "", preferred_car := -1, vehicle_kind := "Aurora", single_ticket := false) -> Dictionary:
	var key: String = economy.key_for(person)
	_reconcile(person)
	if key=="":
		economy.last_error = "Your city account is not ready yet"
		return {}
	if person.get_meta("service_driving",false) or person.get("driving")==true or is_instance_valid(person.get("riding_bus")) or is_instance_valid(person.get("riding_service")):
		economy.last_error = "Leave your current vehicle with E before booking another journey"
		return {}
	if is_instance_valid(game.helicopters) and game.helicopters.bookings.has(key):
		economy.last_error="Finish or cancel your helicopter booking first."
		return {}
	if bookings.has(key):
		economy.last_error = "You have an active Aurora / Robovan booking. Check its status below, or cancel it and rebook."
		return {}
	if person.get("dead")==true or person.get("transitioning")==true or person.get("resting")!="" or is_instance_valid(person.get("active_house")) or is_instance_valid(person.get("current_house")):
		economy.last_error = "Stand outside, awake and on foot to meet your vehicle"
		return {}
	if preferred_car>=0 and preferred_car<cars.size():vehicle_kind=cars[preferred_car].kind
	if vehicle_kind not in ["Aurora","Robovan"]:return {}
	var fare := 300 if single_ticket else (quote(person,destination.point) if destination.has("point") else 300)
	passenger_name = passenger_name.strip_edges().replace("\n"," ").replace("\r"," ").left(28)
	if passenger_name=="":
		passenger_name = str(person.profile.name) if person.get("profile")!=null else str(person.get("person_name"))
	if not economy.can_pay_fare(person,fare,vehicle_kind):
		economy.last_error = "Not enough money for this journey"
		return {}
	last_notice.erase(key)
	serial += 1
	var trip := {"id":serial,"person":person,"kind":vehicle_kind,"passenger_name":passenger_name,"preferred_car":preferred_car,"destination":destination.duplicate(),"pickup":person.global_position,"fare":fare,"flat_fare":single_ticket,"pin":"%02d" % randi_range(0,99),"state":"queued","car":-1,"wait":0.0,"attempts":0,"locked_until":0.0,"created":elapsed,"last_progress":elapsed,"retries":0}
	bookings[key] = trip
	person.set_meta("last_cab_booking",elapsed)
	_dispatch()
	return trip

func _dispatch() -> void:
	var keys := bookings.keys()
	keys.sort_custom(func(a,b): return a.begins_with("player/") and not b.begins_with("player/"))
	for key in keys:
		var trip: Dictionary = bookings[key]
		if trip.state!="queued":
			continue
		var selected := -1
		var nearest := INF
		var selected_path := PackedVector3Array()
		for i in range(cars.size()):
			if cars[i].kind!=trip.get("kind","Aurora"):continue
			if cars[i].node.has_meta("private_owner") and cars[i].node.get_meta("private_owner")!=key:continue
			if cars[i].state in ["idle","returning"] and (trip.person.get("controlled")!=null or i>=2 or (is_instance_valid(game.services) and not game.services.operator_for(cars[i].node).is_empty())):
				if int(trip.get("preferred_car",-1))>=0 and i!=int(trip.preferred_car): continue
				var candidate := PackedVector3Array([cars[i].node.global_position]) if int(trip.get("preferred_car",-1))==i and trip.person.global_position.distance_to(cars[i].node.global_position)<4.6 else _pickup_path(cars[i],trip.pickup,trip.get("flat_fare",false))
				if candidate.is_empty(): continue
				var cost: float = cars[i].node.global_position.distance_to(candidate[0])
				for j in range(1,candidate.size()): cost+=candidate[j-1].distance_to(candidate[j])
				if is_instance_valid(game.services) and game.services.dispatch.ready_vehicle(cars[i].node):cost-=100000
				if cost<nearest:
					nearest = cost
					selected = i
					selected_path = candidate
		if selected<0:
			continue
		var car: Dictionary = cars[selected]
		car.booking = key
		car.fast = false
		car.manual = false
		car.state = "pickup"
		trip.pickup_timeout=clampf((_path_fare(selected_path)-300)/24.0+90.0,180.0,900.0)
		car.path = selected_path
		car.index = 0
		trip.car = selected
		trip.state = "approaching"
		trip.last_progress = elapsed
		_branding(car,trip.passenger_name+" • PICKUP")
		trip.pickup_curb = car.path[-1]
		var approach: Vector3 = (car.path[-1]-car.path[-2]).normalized() if car.path.size()>1 else car.node.global_basis.z
		trip.pickup_wait = trip.pickup_curb+Vector3(approach.z,0,-approach.x)*4.7
		if selected_path.size()==1 or (int(trip.get("preferred_car",-1))>=0 and trip.person.global_position.distance_to(car.node.global_position)<4.6):
			car.state = "waiting"
			trip.state = "waiting"
			car.node.get_meta("marker").show()
		if is_instance_valid(game.services):game.services.dispatch.assigned(car.node,trip)

func unlock(person: Node3D, pin: String, near_vehicle := false) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key):
		return false
	var trip: Dictionary = bookings[key]
	if trip.state!="waiting" or (person.global_position.distance_to(cars[int(trip.car)].node.global_position)>4.6 if near_vehicle else person.global_position.distance_to(boarding_point(person))>1.35) or elapsed<float(trip.locked_until):
		return false
	if pin!=trip.pin:
		trip.attempts = int(trip.attempts)+1
		if int(trip.attempts)>=3:
			trip.locked_until = elapsed+10
			trip.attempts = 0
		return false
	var car: Dictionary = cars[int(trip.car)]
	var journey_path := path_between(car.node.global_position,trip.destination.point,car.node.global_basis.z) if trip.destination.has("point") else PackedVector3Array()
	if trip.destination.has("point") and journey_path.is_empty():
		economy.last_error = "This destination has no reachable road entrance. Choose another destination."
		return false
	if not economy.hold_fare(person,int(trip.fare),trip.get("kind","Aurora")):
		cancel(person)
		return false
	car.state = "boarding"
	car.board_clock = 0.0
	car.board_start = person.global_position
	car.board_side = -1.0 if car.node.to_local(person.global_position).x<0 else 1.0
	_branding(car,trip.passenger_name+" • ON BOARD")
	car.node.get_meta("marker").hide()
	trip.state = "boarding"
	car.path = journey_path
	car.index = 0
	if person.has_method("stop_activity"): person.stop_activity()
	person.riding_service = self
	person.set_meta("cab_car",int(trip.car))
	person.set_meta("cab_camera_mode",0)
	car.node.get_node("ServiceAudio").effect("door")
	person.set_meta("cab_reply","")
	car.node.get_node("CabDialogue").say(person,"welcome")
	person.visual.show()
	person.collider.set_deferred("disabled",true)
	person.velocity = Vector3.ZERO
	return true

func cancel(person: Node3D) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or bookings[key].state in ["riding","boarding","awaiting_destination"]:
		return false
	var trip: Dictionary = bookings[key]
	if int(trip.car)>=0:
		var car: Dictionary = cars[int(trip.car)]
		if car.state in ["waiting","pickup"]:
			_park_at_curb(car)
		cars[int(trip.car)].state = "idle"
		cars[int(trip.car)].booking = ""
		cars[int(trip.car)].speed = 0.0
		_branding(car,"AVAILABLE")
		car.node.get_meta("marker").hide()
	bookings.erase(key)
	person.set_meta("cab_waiting",false)
	return true

func boarding_point(person: Node3D) -> Vector3:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or int(bookings[key].car)<0: return person.global_position
	var car:Dictionary=cars[int(bookings[key].car)]
	return car.node.to_global(car.node.get_meta("graphics").get_meta("boarding_point",Vector3(2.05,.05,0)))

func leave_waiting(person: Node3D) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or bookings[key].state!="awaiting_destination": return false
	var car: Dictionary = cars[int(bookings[key].car)]
	person.visual.dismount(person)
	person.riding_service = null
	person.global_position = boarding_point(person)
	person.visual.show()
	person.collider.set_deferred("disabled",false)
	_pose(person,"idle",car)
	_release_orphan(key) # Refund the held boarding payment for an unused journey.
	return true

func _passenger_side(_car:Dictionary) -> float:
	# Taking the wheel must not slide the occupant across the cabin.
	return .4

func seat_position(person: Node3D) -> Vector3:
	var model: Node3D = cars[int(person.get_meta("cab_car"))].node.get_meta("graphics")
	return model.to_global(model.get_meta("passenger_seat",Vector3(.4,.26,-.35)))

func rider_position(person: Node3D) -> Vector3:
	var car: Dictionary = cars[int(person.get_meta("cab_car"))]
	if car.state!="boarding": return seat_position(person)
	var t := float(car.board_clock)
	var opening:Vector3=car.node.get_meta("graphics").get_meta("boarding_door",Vector3(1.05,.3,0))
	opening.x*=float(car.get("board_side",1.0))
	var door:Vector3=car.node.to_global(opening)
	if t<0.6: return car.board_start
	if t<1.4: return car.board_start.lerp(door,(t-0.6)/0.8)
	return door.lerp(seat_position(person),clampf((t-1.4)/0.8,0,1))

func _pose(person: Node3D, clip: String, car: Dictionary) -> void:
	if clip=="seated":
		var model:Node3D=car.node.get_meta("graphics")
		person.visual.mount(model,model.get_meta("passenger_seat",Vector3(.4,.26,-.35)),PI,true)
	elif person.visual.mounted:
		person.visual.dismount(person)
	if person.has_method("_play_clip"): person._play_clip(clip)
	else: person.visual.play(clip)
	if not person.visual.mounted:
		if clip=="walk": person.visual.face(car.node.global_position-person.global_position,1)
		else: person.visual.global_rotation.y = car.node.global_rotation.y+PI

func _branding(car: Dictionary, text: String) -> void:
	for display in car.node.get_meta("displays",[]):
		display.text = car.cab_id+" • "+text

func choose_destination(person: Node3D, destination: Dictionary) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or not destination.has("point"):
		economy.last_error = "Choose a place on the map or in the destination list."
		return false
	var trip: Dictionary = bookings[key]
	if trip.state=="riding":
		economy.last_error = "This journey is already moving to your confirmed destination."
		return false
	var start: Vector3 = trip.pickup
	var facing := Vector3.ZERO
	if trip.state in ["boarding","awaiting_destination"]:
		start = cars[int(trip.car)].node.global_position
		facing = cars[int(trip.car)].node.global_basis.z
	var path := path_between(start,destination.point,facing)
	if path.is_empty() or start.distance_to(destination.point)<8:
		economy.last_error = "Choose a reachable destination at least 8 metres away."
		return false
	var fare:int=int(trip.fare) if trip.get("flat_fare",false) else (quote(person,destination.point) if trip.state not in ["boarding","awaiting_destination"] else _path_fare(path))
	if trip.state in ["boarding","awaiting_destination"]:
		if not economy.resize_fare(person,fare): return false
	elif not economy.can_pay_fare(person,fare,trip.get("kind","Aurora")):
		economy.last_error = "Not enough money for this journey."
		return false
	trip.destination = destination.duplicate()
	trip.fare = fare
	if trip.state in ["boarding","awaiting_destination"]:
		var car: Dictionary = cars[int(trip.car)]
		car.path = path
		car.index = 0
		if trip.state=="awaiting_destination":
			car.state = "dropoff"
			trip.state = "riding"
	return true

func _path_fare(path: PackedVector3Array) -> int:
	var length := 0.0
	for i in range(1,path.size()): length+=path[i-1].distance_to(path[i])
	return 300+int(ceil(length*3))

func remaining_route(person: Node3D) -> PackedVector3Array:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or int(bookings[key].car)<0: return PackedVector3Array()
	var car: Dictionary = cars[int(bookings[key].car)]
	if car.state not in ["pickup","dropoff"]: return PackedVector3Array()
	var path := PackedVector3Array([car.node.global_position])
	for i in range(int(car.index),car.path.size()): path.append(car.path[i])
	return path

func _process(delta: float) -> void:
	for car in cars:
		var graphics: Node3D = car.node.get_meta("graphics")
		preload("res://transport/vehicle_motion.gd").render(car.node,graphics)
		preload("res://vehicles/driver_controls.gd").update(graphics,float(car.get("steer_input",0)) if car.manual or (is_instance_valid(game.services) and game.services.manual(car.node)) else 0.0,delta)

func _physics_process(delta: float) -> void:
	update_clock += delta
	delta = update_clock
	update_clock = 0
	elapsed += delta
	for key in bookings.keys():
		var trip: Dictionary = bookings[key]
		if not is_instance_valid(trip.person):
			_release_orphan(key)
		elif trip.state=="queued" and elapsed-float(trip.created)>120:
			_expire(trip,"All vehicles in this fleet are busy. No fare taken. Please rebook.")
	_dispatch()
	for car in cars:
		if car.state in ["job_pickup","job_ready","rental_pickup","rental_ready"]:continue
		if car.state in ["idle","waiting","boarding","awaiting_destination"]:
			car.node.get_node("ServiceAudio").set_motion(0,"electric")
		if car.state=="idle":
			_doors(car,0.0)
			car.idle_clock = float(car.idle_clock)+delta
			if float(car.get("service_after",INF))<=elapsed and not car.node.has_meta("private_owner") and (not is_instance_valid(game.services) or (not game.services.manual(car.node) and not game.services.dispatch.ready_vehicle(car.node))):
				var scheduled_bay_index:=_free_robotics_bay()
				if scheduled_bay_index>=0:
					var bay_point:Vector3=robotics_bays[scheduled_bay_index].point
					var service_path:=_robotics_path_to_bay(car.node.global_position,bay_point,car.node.global_basis.z)
					if not service_path.is_empty():
						robotics_bays[scheduled_bay_index]["vehicle"]=car.node
						car.service_bay=scheduled_bay_index
						car.path=service_path;car.index=0;car.speed=0.0;car.service_clock=0.0;car.state="robot_service_travel"
						_branding(car,"ROBOTICS • EN ROUTE")
						continue
					car.service_after=elapsed+25.0
			if float(car.idle_clock)>8 and car.node.global_position.distance_to(car.home_slot)>9 and (not is_instance_valid(game.services) or (not game.services.manual(car.node) and not game.services.dispatch.ready_vehicle(car.node))):
				var home_path := path_between(car.node.global_position,car.home_slot,car.node.global_basis.z)
				if not home_path.is_empty():
					car.path = home_path
					car.index = 0
					car.state = "returning"
					_branding(car,"AVAILABLE • "+str(ranks[int(car.rank)].name))
			continue
		if car.state=="returning":
			_return_to_rank(car,delta)
			continue
		if car.state in ["robot_service_travel","robot_service_exit","robot_service_return"]:
			if car.path.is_empty() or int(car.index)>=car.path.size():
				if car.state=="robot_service_travel":
					var travel_bay_index:=int(car.get("service_bay",-1))
					if travel_bay_index<0 or travel_bay_index>=robotics_bays.size() or robotics_bays[travel_bay_index].get("vehicle")!=car.node:
						_release_robotics_bay(car);car.state="idle";car.service_after=elapsed+30.0
					else:
						car.node.global_position=robotics_bays[travel_bay_index].point
						car.speed=0.0;car.service_clock=0.0;car.state="robot_service_charge"
						car.node.get_node("ServiceAudio").set_motion(0,"electric")
						_branding(car,"ROBOTICS • CHARGING")
				elif car.state=="robot_service_exit":
					var home_path:=_road_path(ROBOTICS_ENTRY,car.home_slot,Vector3(0,0,-1))
					if not home_path.is_empty():
						car.path=home_path;car.index=0;car.state="robot_service_return"
						_branding(car,"ROBOTICS • RETURNING TO RANK")
					else:
						_release_robotics_bay(car);car.state="idle";car.service_after=elapsed+35.0
				else:
					_release_robotics_bay(car);car.state="idle";car.speed=0.0;car.idle_clock=0.0
					car.path=PackedVector3Array();car.index=0
					car.service_after=elapsed+900.0+float(int(car.get("rank",0))%4)*30.0
					_branding(car,"AVAILABLE • CHARGED")
			else:
				_advance_route(car,delta)
			continue
		if car.state=="robot_service_charge":
			car.speed=0.0;car.service_clock=float(car.service_clock)+delta
			if float(car.service_clock)>=22.0:
				var charge_bay_index:=int(car.get("service_bay",-1))
				if charge_bay_index<0 or charge_bay_index>=robotics_bays.size():
					_release_robotics_bay(car);car.state="idle";car.service_after=elapsed+30.0
				else:
					var inside:=_robotics_inner_points(robotics_bays[charge_bay_index].point)
					var exit_path:=PackedVector3Array([car.node.global_position])
					for i in range(inside.size()-2,-1,-1):
						if exit_path[-1].distance_to(inside[i])>.05:exit_path.append(inside[i])
					car.path=exit_path;car.index=0;car.state="robot_service_exit"
					_branding(car,"ROBOTICS • LEAVING CHARGER")
			continue
		if not bookings.has(car.booking):
			car.state = "idle"
			car.booking = ""
			continue
		var trip: Dictionary = bookings[car.booking]
		var person: Node3D = trip.person
		if car.state=="pickup" and elapsed-float(trip.created)>float(trip.get("pickup_timeout",180)):
			_expire(trip,"Your vehicle could not reach your pickup. No fare taken. Please rebook.")
			continue
		if car.state=="boarding":
			car.board_clock = float(car.board_clock)+delta
			_doors(car,clampf(float(car.board_clock),0,1) if float(car.board_clock)<2 else maxf(0,3.0-float(car.board_clock)))
			person.global_position = rider_position(person)
			_pose(person,"walk" if float(car.board_clock)<2.2 else "seated",car)
			if float(car.board_clock)>=3:
				car.state = "dropoff" if trip.destination.has("point") else "awaiting_destination"
				trip.state = "riding" if trip.destination.has("point") else "awaiting_destination"
			continue
		if car.state=="awaiting_destination":
			_pose(person,"seated",car)
			continue
		if car.state=="waiting":
			trip.wait = float(trip.wait)+delta
			if person.get_meta("cab_waiting",false) and person.global_position.distance_to(boarding_point(person))<1.35:
				unlock(person,trip.pin)
			elif float(trip.wait)>90:
				_expire(trip,"Pickup expired. No fare taken. Please book again when you are ready.")
			continue
		var path: PackedVector3Array = car.path
		var operator_manual:bool=is_instance_valid(game.services) and game.services.manual(car.node)
		var at_end:bool=int(car.index)>=path.size() or (not path.is_empty() and car.node.global_position.distance_to(path[-1])<.6 and absf(float(car.speed))<.25)
		if not car.manual and not operator_manual and at_end:
			if car.state=="pickup":
				# Wait at a clear curb space, leaving the running lane open during PIN entry.
				_park_at_curb(car)
				trip.pickup_curb = car.node.global_position
				car.state = "waiting"
				trip.state = "waiting"
				car.node.get_meta("marker").show()
				_branding(car,trip.passenger_name+" • PICKUP")
			else:
				_finish(car,trip)
			continue
		var travel := _manual_step(car,trip,delta) if car.manual or operator_manual else _advance_route(car,delta,person)
		if travel>0.002: trip.last_progress = elapsed
		elif elapsed-float(trip.last_progress)>40 and car.state=="pickup":
			_expire(trip,"Your pickup road is blocked. No fare taken. Move to a clear pavement and rebook.")
			continue
		if operator_manual and car.state=="pickup" and car.node.position.distance_to(car.path[-1])<6 and absf(float(car.speed))<2:
			_park_at_curb(car);trip.pickup_curb=car.node.position;car.state="waiting";trip.state="waiting";car.node.get_meta("marker").show()
		if (car.manual or operator_manual) and car.state=="dropoff" and trip.destination.has("point"):
			var end: Vector3=car.path[-1]
			if car.node.global_position.distance_to(end)<6 and absf(float(car.speed))<2:
				_finish(car,trip)
				continue
		if trip.state=="riding":
			person.global_position = seat_position(person)
			_pose(person,"seated",car)
	npc_clock += delta
	if npc_clock>=12:
		npc_clock = 0
		_npc_book()

func _finish(car: Dictionary, trip: Dictionary) -> void:
	var person: Node3D = trip.person
	var paid:int=economy.data.receipts.get(economy.key_for(person),{}).get("amount",0)
	economy.complete_fare(person,car.node)
	if is_instance_valid(game.services):game.services.dispatch.completed(car.node,paid)
	car.node.get_node("CabDialogue").say(person,"arrival")
	person.visual.dismount(person)
	person.riding_service = null
	person.set_meta("cab_waiting",false)
	_park_at_curb(car)
	person.global_position = car.node.global_position+car.node.global_basis.x*3.5+Vector3(0,0.15,0)
	if is_instance_valid(game.get("rail")) and not game.rail.at_bay(car.node.global_position).is_empty():
		person.global_position = car.node.global_position+car.node.global_basis.z*4.8+Vector3(0,0.3,0)
	person.visual.show()
	person.collider.set_deferred("disabled",false)
	person.velocity = Vector3.ZERO
	car.state = "idle"
	car.manual = false
	car.fast = false
	person.set_meta("service_driving",false)
	car.node.get_meta("graphics").get_meta("manual_controls").hide()
	car.idle_clock = 0.0
	car.speed = 0.0
	_doors(car,0)
	car.booking = ""
	_branding(car,"AVAILABLE")
	car.node.get_meta("marker").hide()
	_pose(person,"idle",car)
	bookings.erase(economy.key_for(person))

func _npc_book() -> void:
	for person in game.population.residents:
		if person.has_meta("service_counter"):continue
		if person.dead or person.resting!="" or person.current_house!=null or person.combat_time>0 or person.house_transition or person.riding_service!=null:
			continue
		if elapsed-float(person.get_meta("last_cab_booking",-1000))<180 or bookings.has(economy.key_for(person)):
			continue
		var destination := {"name":person.home.address,"point":person.home.entrance()} if economy.hour()>=18 else {"name":"Council office","point":economy.office}
		if person.global_position.distance_to(destination.point)<35:
			continue
		var trip := book(person,destination,"",-1,"Robovan" if randi_range(0,3)==0 else "Aurora")
		if not trip.is_empty():
			person.set_meta("cab_waiting",true)
		return

func _doors(car: Dictionary, open: float) -> void:
	for door in car.node.get_meta("doors",[]):
		if door.has_meta("slide_origin"):
			door.position=door.get_meta("slide_origin")+Vector3(float(door.get_meta("side"))*.1*open,0,-1.45*open)
		else:door.rotation.z = float(door.get_meta("side"))*open*1.15

func is_pickup_near(person: Node3D) -> bool:
	var key: String = economy.key_for(person)
	return bookings.has(key) and bookings[key].state=="waiting" and int(bookings[key].car)>=0 and person.global_position.distance_to(cars[int(bookings[key].car)].node.position)<4.6

# Repair stale references rather than trapping a player behind an obsolete booking.
func _reconcile(person: Node3D) -> void:
	var key: String = economy.key_for(person)
	if person.get("riding_service")==self and not bookings.has(key):
		person.visual.dismount(person)
		person.riding_service = null
		person.set_meta("service_driving",false)
		person.visual.show()
		person.collider.set_deferred("disabled",false)
	if not bookings.has(key): return
	var trip: Dictionary = bookings[key]
	var index := int(trip.car)
	if trip.state!="queued" and (index<0 or index>=cars.size() or cars[index].booking!=key):
		_release_orphan(key)
		if person.get("riding_service")==self:
			person.visual.dismount(person)
			person.riding_service = null
			person.visual.show()
			person.collider.set_deferred("disabled",false)

func _release_orphan(key: String) -> void:
	if economy.data.receipts.has(key) and economy.data.accounts.has(key):
		var refund := int(economy.data.receipts[key].amount)
		economy.data.accounts[key].balance = int(economy.data.accounts[key].balance)+refund
		economy.data.receipts.erase(key)
		economy.record(key,refund,"Unavailable road trip refunded")
		economy.save()
	for car in cars:
		if car.booking==key:
			car.manual=false
			car.fast=false
			car.node.get_meta("graphics").get_meta("manual_controls").hide()
			car.booking = ""
			car.state = "idle"
			car.speed = 0.0
			_branding(car,"AVAILABLE")
			car.node.get_meta("marker").hide()
	bookings.erase(key)

func _expire(trip: Dictionary, text: String) -> void:
	var person: Node3D = trip.person
	last_notice[economy.key_for(person)] = text
	cancel(person)
	if person.has_method("_notify"): person._notify(text)

func skip_journey(person: Node3D) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or bookings[key].state!="riding": return false
	var trip: Dictionary = bookings[key]
	var car: Dictionary = cars[int(trip.car)]
	# Finish the existing receipt once; time skipping never creates a second fare.
	var destination_path := path_between(car.node.global_position,trip.destination.point,car.node.global_basis.z)
	if destination_path.is_empty(): return false
	var end := destination_path[-1]
	if destination_path.size()>1:
		var forward := (end-destination_path[-2]).normalized()
		car.node.rotation.y = atan2(forward.x,forward.z)
	car.node.global_position = end
	game.city.traffic.track_vehicle(car.node)
	_finish(car,trip)
	return true

func talk(person: Node3D, topic: String) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or bookings[key].state not in ["boarding","riding","awaiting_destination"]:
		person.set_meta("cab_reply","Board your Aurora to have a conversation.")
		return false
	cars[int(bookings[key].car)].node.get_node("CabDialogue").say(person,topic)
	return true

func _park_at_curb(car:Dictionary) -> void:
	var point:=_parking_point(car,car.node.global_position,car.node.global_basis.z)
	car.node.global_position=point
	if not is_instance_valid(game.get("rail")) or game.rail.at_bay(point).is_empty():
		var anchor:=_road_anchor(point,car.node.global_basis.z)
		car.node.rotation.y=atan2(anchor.direction.x,anchor.direction.z)
	game.city.traffic.track_vehicle(car.node)

func _parking_point(car:Dictionary,point:Vector3,facing:Vector3) -> Vector3:
	if is_instance_valid(game.get("rail")) and not game.rail.at_bay(point).is_empty(): return point # stays in the station bay
	var anchor := _road_anchor(point,facing)
	var direction: Vector3 = anchor.direction
	var left := Vector3(direction.z,0,-direction.x)
	var base: Vector3 = anchor.center+left*(6.5 if car.get("kind","")=="Robovan" else 5.5)
	for step in [0,-1,1,-2,2,-3,3,-4,4,-5,5,-6,6,-8,8,-10,10,-14,14,-21,21,-28,28,-35,35,-42,42]:
		var candidate: Vector3 = base+direction*float(step)
		if not preload("res://town/world_layout.gd").contains(candidate): continue
		var junction := false
		for x in game.city.ROAD_X:
			for z in game.city.ROAD_Z:
				if absf(candidate.x-x)<12 and absf(candidate.z-z)<12: junction=true
		if junction: continue
		if car.get("kind","")=="Robovan" and (not game.city.traffic.space_clear(candidate-direction*1.5,direction,car.node) or not game.city.traffic.space_clear(candidate+direction*1.5,direction,car.node)):continue
		if game.city.traffic.space_clear(candidate,direction,car.node):
			return candidate

	return point

func _build_ranks() -> void:
	var G = preload("res://transport/geometry.gd")
	for rank in ranks:
		var stand := Node3D.new()
		stand.name = "AuroraRank_"+str(rank.id)
		stand.position = rank.rank
		stand.rotation.y = float(rank.heading)
		add_child(stand)
		var gold := G.material(Color("c6aa69"),0.5)
		var dark := G.material(Color("24323c"))
		G.tube(stand,Vector3(2.1,0,4.7),Vector3(2.1,2.8,4.7),0.055,dark)
		G.box(stand,Vector3(2.1,2.65,4.7),Vector3(0.8,0.65,0.1),gold)
		var sign := G.label(stand,"AURORA / ROBOVAN • "+str(rank.name)+"\nE: walk-up cab · K: request pickup",Vector3(2.1,3.2,4.7),20)
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		for slot in range(1):
			for side in [-1.0,1.0]: G.box(stand,Vector3(side*1.05,0.015,slot*7),Vector3(0.06,0.02,5.6),gold)
			G.box(stand,Vector3(0,0.015,slot*7-2.8),Vector3(2.1,0.02,0.06),gold)
		G.merge(stand)

func nearest_available(person: Node3D) -> int:
	var selected := -1
	var gap := 4.0
	for i in range(cars.size()):
		if cars[i].state!="idle" or (person.get("controlled")==null and i<2): continue
		var distance: float = person.global_position.distance_to(cars[i].node.global_position)
		if distance<gap:
			gap = distance
			selected = i
	return selected

func walk_up(person: Node3D, index: int) -> Dictionary:
	if index<0 or index>=cars.size() or cars[index].state!="idle" or person.global_position.distance_to(cars[index].node.global_position)>4:
		economy.last_error = "Walk to an available parked Aurora or Robovan first."
		return {}
	return book(person,{},"",index)

func _return_to_rank(car: Dictionary, delta: float) -> void:
	if int(car.index)>=car.path.size():
		_park_at_curb(car)
		car.state = "idle"
		car.idle_clock = 0.0
		car.speed = 0.0
		car.node.get_node("ServiceAudio").set_motion(0,"electric")
		_branding(car,"AVAILABLE • "+str(ranks[int(car.rank)].name))
		return
	_advance_route(car,delta)

func _pickup_path(car: Dictionary, pickup: Vector3, allow_nearby_bay := false) -> PackedVector3Array:
	var from: Vector3 = car.node.global_position
	var facing: Vector3 = car.node.global_basis.z
	# A cab already safely parked beside the caller is the pickup bay.
	# Sending a long van around the block can trap it behind other parked cars.
	if allow_nearby_bay and car.state=="idle" and from.distance_to(pickup)<=18 and _parking_point(car,from,facing).distance_to(from)<.15:
		return PackedVector3Array([from])
	if is_instance_valid(game.get("rail")) and not game.rail.at_bay(from).is_empty(): return path_between(from,pickup,facing)
	var anchor := _road_anchor(from,facing)
	var target_anchor := _road_anchor(pickup,facing)
	var direction: Vector3 = anchor.direction
	var offset: Vector3 = target_anchor.point-anchor.point
	if car.state=="idle" and offset.cross(direction).length()<0.1 and offset.dot(direction)>=-3 and offset.dot(direction)<12:
		var left := Vector3(direction.z,0,-direction.x)
		for step in [0,-1,1,-2,2,-3,3,-4,4]:
			var target: Vector3 = target_anchor.center+left*(6.5 if car.get("kind","")=="Robovan" else 5.5)+direction*float(step)
			if (target-from).dot(direction)<-0.05 or target.distance_to(pickup)>6: continue
			if game.city.traffic.space_clear(target,direction,car.node): return PackedVector3Array([from,target])
	var path:=path_between(from,pickup,facing)
	return _curb_approach(car,path) if car.get("kind","")=="Robovan" else path

# Reserve a clear curb bay before arriving, then drive the final approach.
func _curb_approach(car:Dictionary,path:PackedVector3Array) -> PackedVector3Array:
	if path.size()<2:return path
	var forward:Vector3=(path[-1]-path[-2]).normalized()
	var target:=_parking_point(car,path[-1],forward)
	if target.distance_to(path[-1])<.15:return path
	var cut:=path.size()-1;var remaining:=12.0
	while cut>0 and remaining>path[cut].distance_to(path[cut-1]):
		remaining-=path[cut].distance_to(path[cut-1]);cut-=1
	var start:Vector3=path[cut].move_toward(path[cut-1],remaining) if cut>0 else path[0]
	var result:=path.slice(0,cut);result.append(start)
	var gap:=start.distance_to(target)
	var a:=start+forward*minf(6,gap*.4);var b:=target-forward*minf(4,gap*.3)
	for i in range(1,17):
		var t:=i/16.0
		result.append(pow(1-t,3)*start+3*pow(1-t,2)*t*a+3*(1-t)*t*t*b+t*t*t*target)
	return result

func board_near(person: Node3D) -> bool:
	var key: String=economy.key_for(person)
	if not bookings.has(key) or int(bookings[key].car)<0: return false
	return unlock(person,str(bookings[key].pin),true)

# Keep distance left over at a route point, rather than throwing away a simulation step.
func _advance_route(car: Dictionary, delta: float, person: Node3D = null) -> float:
	var half:float=car.get("half_length",2.5)
	var limit := 21.0 if car.fast else 14.0
	if is_instance_valid(game.services):limit*=game.services.throttle(car.node)
	if car.state=="returning": limit = 12.0
	var position: Vector3=car.node.global_position
	var remaining := 0.0
	var previous := position
	var forward := Vector3.ZERO
	for i in range(int(car.index),car.path.size()):
		var offset: Vector3=car.path[i]-previous
		if offset.length()>.02:
			if forward==Vector3.ZERO: forward=offset.normalized()
			elif forward.dot(offset.normalized())<.97:
				limit=minf(limit,sqrt(6.5*6.5+14*maxf(0,remaining-3)))
			remaining+=offset.length()
		previous=car.path[i]
		if remaining>100: break
	limit=minf(limit,sqrt(14*remaining))
	if forward!=Vector3.ZERO:
		car.node.set_meta("traffic_straight",game.city.traffic.path_is_straight(car.path,int(car.index),position,forward))
		var horizon := maxf(7,float(car.speed)*float(car.speed)/14+2)
		var gap: float=minf(_static_gap(position,forward,horizon,car.get("body_size",Vector3(1.8,1.35,4.2))),game.city.traffic.allowed_travel(position,forward,horizon,half,car.node,person))
		if gap<horizon-.01: limit=minf(limit,sqrt(14*maxf(0,gap-.12)))
	car.speed=move_toward(maxf(0,float(car.speed)),limit,(5.0 if limit>float(car.speed) else 7.0)*delta)
	var budget: float=float(car.speed)*delta
	var travelled := 0.0
	for step in range(20):
		if int(car.index)>=car.path.size(): break
		var offset: Vector3=car.path[int(car.index)]-car.node.global_position
		if offset.length()<.015:
			car.index=int(car.index)+1
			continue
		if budget<.00001: break
		var direction:=offset.normalized()
		var requested:=minf(budget,offset.length())
		var clear:=_static_gap(car.node.global_position,direction,requested,car.get("body_size",Vector3(1.8,1.35,4.2)))
		var travel: float=game.city.traffic.allowed_travel(car.node.global_position,direction,clear,half,car.node,person)
		car.node.global_position+=direction*travel
		if travel>.0001: car.node.rotation.y=atan2(direction.x,direction.z)
		travelled+=travel; budget-=travel
		if travel<requested-.001: car.speed=travel/maxf(.001,delta); break
		if offset.length()-travel<.015: car.index=int(car.index)+1
	_motion_effects(car,travelled)
	return travelled

func _motion_effects(car: Dictionary, travel: float) -> void:
	game.city.traffic.track_vehicle(car.node)
	car.node.get_node("ServiceAudio").set_motion(absf(float(car.speed)),"electric")
	for wheel in car.node.get_meta("wheels",[]): wheel.rotation.x+=travel/.36

func set_fast(person: Node3D, enabled: bool) -> bool:
	var key: String=economy.key_for(person)
	if not bookings.has(key) or bookings[key].state not in ["boarding","awaiting_destination","riding"]: return false
	cars[int(bookings[key].car)].fast=enabled
	return true

func is_manual(person: Node3D) -> bool:
	var key: String=economy.key_for(person)
	return bookings.has(key) and int(bookings[key].car)>=0 and cars[int(bookings[key].car)].manual

func set_manual(person: Node3D, enabled: bool) -> bool:
	var key: String=economy.key_for(person)
	if person.get("controlled")!=true or not bookings.has(key) or person.riding_service!=self: return false
	var trip: Dictionary=bookings[key]
	if trip.state!="riding":
		economy.last_error="Choose your destination and finish boarding before taking the wheel."
		return false
	var car: Dictionary=cars[int(trip.car)]
	if enabled==bool(car.manual): return true
	if not enabled:
		var path:=path_between(car.node.global_position,trip.destination.point,car.node.global_basis.z)
		if path.is_empty():
			economy.last_error="Return to a connected road before switching to self-drive."
			return false
		car.path=path; car.index=0; car.speed=maxf(0,float(car.speed))
	car.manual=enabled
	car.node.get_meta("graphics").get_meta("manual_controls").position.x=float(car.node.get_meta("graphics").get_meta("passenger_seat",Vector3(.4,.26,-.35)).x)
	car.node.get_meta("graphics").get_meta("manual_controls").visible=enabled
	person.set_meta("service_driving",enabled)
	_branding(car,trip.passenger_name+(" • PLAYER DRIVING" if enabled else " • SELF DRIVE"))
	_pose(person,"seated",car)
	return true

func _manual_step(car: Dictionary, trip: Dictionary, delta: float) -> float:
	var blocked: bool=game.phone.panel.visible or game.city_map.expanded or game.party.wheel.visible or game.get_meta("controller_screen_mode",false)
	var throttle := Input.get_action_strength("accelerate") if not blocked else 0.0
	var brake := Input.get_action_strength("reverse") if not blocked else 0.0
	var steer := Input.get_axis("turn_left","turn_right") if not blocked else 0.0
	car.steer_input=steer
	var target := throttle*(24.0 if car.fast else 17.0)
	if brake>.1 and float(car.speed)<.2: target=-brake*5
	elif brake>.1: target=0
	car.speed=move_toward(float(car.speed),target,(12 if brake>.1 or blocked else (5 if throttle>.1 else 3))*delta)
	var heading: float=car.node.rotation.y-steer*clampf(float(car.speed)/6,-1,1)*delta*1.4
	var direction:=Vector3(sin(heading),0,cos(heading))*signf(float(car.speed))
	var requested:=absf(float(car.speed))*delta
	var position: Vector3=car.node.global_position
	var proposed: Vector3=position+direction*requested
	# Free driving uses physical obstacles, with no invisible road/rail boundary.
	var query:=PhysicsShapeQueryParameters3D.new()
	if not car.node.has_meta("manual_shape"):
		var shape:=BoxShape3D.new(); shape.size=car.get("body_size",Vector3(1.8,1.4,4.2))
		car.node.set_meta("manual_shape",shape)
	query.shape=car.node.get_meta("manual_shape")
	query.transform=Transform3D(Basis(Vector3.UP,heading),position+Vector3(0,float(query.shape.size.y)*.5+.2,0))
	query.motion=direction*requested; query.collision_mask=1
	var safe: PackedFloat32Array=car.node.get_world_3d().direct_space_state.cast_motion(query)
	var travel: float=game.city.traffic.allowed_travel(position,direction,requested*float(safe[0]),float(car.get("half_length",2.5)),car.node,trip.person)
	if travel<requested-.001: car.speed=0
	car.node.rotation.y=heading
	car.node.global_position+=direction*travel
	if elapsed-float(car.get("map_route_clock",-10))>1:
		car.map_route_clock=elapsed
		var route_target:Vector3=car.path[-1] if car.state=="pickup" else trip.destination.point
		var route:=path_between(car.node.global_position,route_target,car.node.global_basis.z)
		if not route.is_empty(): car.path=route; car.index=0
	# Follow the actual ground or station ramp instead of floating at the previous elevation.
	var ray:=PhysicsRayQueryParameters3D.create(car.node.global_position+Vector3(0,2,0),car.node.global_position-Vector3(0,4,0),1)
	var hit: Dictionary=car.node.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): car.node.global_position.y=hit.position.y+.1
	_motion_effects(car,travel*signf(float(car.speed)))
	return travel
