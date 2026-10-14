extends Node3D
# Six driverless Aurora cars share a road graph and a FIFO booking queue.
const F = preload("res://vehicles/vehicle_factory.gd")
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

func _ready() -> void:
	for ix in range(game.city.ROAD_X.size()):
		for iz in range(game.city.ROAD_Z.size()):
			var id := ix*10+iz
			graph.add_point(id,Vector3(game.city.ROAD_X[ix],game.city.traffic.LEVEL,game.city.ROAD_Z[iz]))
			if ix>0:
				graph.connect_points(id,id-10)
			if iz>0:
				graph.connect_points(id,id-1)
	for i in range(6):
		var model := F.traffic_visual("cybercab",Color("b99b58"))
		model.name = "Aurora"+str(i+1)
		add_child(model)
		model.position = Vector3(45.5,game.city.traffic.LEVEL,30+i*7)
		var label := preload("res://transport/geometry.gd").label(model,"AURORA • "+str(i+1)+"\nAUTONOMOUS",Vector3(0,1.75,0),22)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var doors: Array[Node3D] = []
		var G = preload("res://transport/geometry.gd")
		for side in [-1.0,1.0]:
			var door := Node3D.new()
			door.position = Vector3(side*0.78,1.05,0.7)
			door.set_meta("side",side)
			model.add_child(door)
			G.box(door,Vector3(side*0.05,-0.43,-0.7),Vector3(0.06,0.34,1.55),G.material(Color("b99b58"),0.65))
			G.box(door,Vector3(0,-0.1,-0.7),Vector3(0.045,0.35,1.3),G.material(Color("21384a"),0.5))
			G.merge(door)
			doors.append(door)
		model.set_meta("doors",doors)
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
		box.size = Vector3(1.8,1.5,4.3)
		shape.shape = box
		shape.position.y = 0.9
		body.add_child(shape)
		model.add_child(body)
		cars.append({"node":model,"booking":"","state":"idle","path":PackedVector3Array(),"index":0,"speed":0.0,"label":label})

func curb(point: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var gap := INF
	for x in game.city.ROAD_X:
		var p := Vector3(float(x),game.city.traffic.LEVEL,clampf(point.z,-140,155))
		if p.distance_squared_to(point)<gap:
			gap = p.distance_squared_to(point)
			best = p
	for z in game.city.ROAD_Z:
		var p := Vector3(clampf(point.x,-155,155),game.city.traffic.LEVEL,float(z))
		if p.distance_squared_to(point)<gap:
			gap = p.distance_squared_to(point)
			best = p
	return best

func path_between(from: Vector3, destination: Vector3) -> PackedVector3Array:
	var start := curb(from)
	var finish := curb(destination)
	if start.distance_to(finish)<0.1:
		return PackedVector3Array([Vector3(from.x,game.city.traffic.LEVEL,from.z)])
	if absf(start.x-finish.x)<0.1 or absf(start.z-finish.z)<0.1:
		var direction := (finish-start).normalized()
		var left := Vector3(direction.z,0,-direction.x)*2.8
		return PackedVector3Array([start+left,finish+left])
	var raw := PackedVector3Array([start])
	var route := graph.get_point_path(graph.get_closest_point(start),graph.get_closest_point(finish))
	for p in route:
		if raw[-1].distance_to(p)>0.1:
			raw.append(p)
	if raw[-1].distance_to(finish)>0.1:
		raw.append(finish)
	# Orthogonal lead-ins avoid driving diagonally across houses to a junction.
	var centers := PackedVector3Array()
	for i in range(raw.size()):
		if i>0 and absf(raw[i].x-raw[i-1].x)>0.01 and absf(raw[i].z-raw[i-1].z)>0.01:
			centers.append(Vector3(raw[i].x,start.y,raw[i-1].z))
		centers.append(raw[i])
	var path := PackedVector3Array()
	for i in range(centers.size()-1):
		var direction := (centers[i+1]-centers[i]).normalized()
		var left := Vector3(direction.z,0,-direction.x)*2.8
		var a := centers[i]+left
		var b := centers[i+1]+left
		if path.is_empty():
			path.append(a)
		path.append(b)
	if path.is_empty():
		path.append(start+Vector3(2.8,0,0))
	return path

func quote(person: Node3D, destination: Vector3) -> int:
	var path := path_between(person.global_position,destination)
	var length := 0.0
	for i in range(1,path.size()):
		length += path[i-1].distance_to(path[i])
	return 300+int(ceil(length*3.0))

func book(person: Node3D, destination: Dictionary) -> Dictionary:
	var key: String = economy.key_for(person)
	_reconcile(person)
	if key=="":
		economy.last_error = "Your city account is not ready yet"
		return {}
	if person.get("driving")==true or is_instance_valid(person.get("riding_bus")) or is_instance_valid(person.get("riding_service")):
		economy.last_error = "Leave your current vehicle with E before booking another journey"
		return {}
	if bookings.has(key):
		economy.last_error = "You have an active Aurora booking. Check its status below, or cancel it and rebook."
		return {}
	if person.get("dead")==true or person.get("transitioning")==true or person.get("resting")!="" or is_instance_valid(person.get("active_house")) or is_instance_valid(person.get("current_house")):
		economy.last_error = "Stand outside, awake and on foot to meet your cab"
		return {}
	var fare := quote(person,destination.point)
	if economy.cash(person)<fare:
		economy.last_error = "Not enough money for this journey"
		return {}
	last_notice.erase(key)
	serial += 1
	var trip := {"id":serial,"person":person,"destination":destination.duplicate(),"pickup":person.global_position,"fare":fare,"pin":"%02d" % randi_range(0,99),"state":"queued","car":-1,"wait":0.0,"attempts":0,"locked_until":0.0,"created":elapsed,"last_progress":elapsed,"retries":0}
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
		for i in range(cars.size()):
			if cars[i].state=="idle" and (trip.person.get("controlled")!=null or i>=2):
				var gap: float = cars[i].node.global_position.distance_to(trip.pickup)
				if gap<nearest:
					nearest = gap
					selected = i
		if selected<0:
			return
		var car: Dictionary = cars[selected]
		car.booking = key
		car.state = "pickup"
		car.path = path_between(car.node.global_position,trip.pickup)
		car.index = 0
		trip.car = selected
		trip.state = "approaching"
		trip.last_progress = elapsed
		car.label.text = "AURORA • ON THE WAY"
		trip.pickup_curb = car.path[-1]
		var approach: Vector3 = (car.path[-1]-car.path[-2]).normalized() if car.path.size()>1 else car.node.global_basis.z
		trip.pickup_wait = trip.pickup_curb+Vector3(approach.z,0,-approach.x)*4.7

func unlock(person: Node3D, pin: String) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key):
		return false
	var trip: Dictionary = bookings[key]
	if trip.state!="waiting" or person.global_position.distance_to(trip.pickup_curb)>4 or elapsed<float(trip.locked_until):
		return false
	if pin!=trip.pin:
		trip.attempts = int(trip.attempts)+1
		if int(trip.attempts)>=3:
			trip.locked_until = elapsed+10
			trip.attempts = 0
		return false
	if not economy.hold_fare(person,int(trip.fare)):
		cancel(person)
		return false
	var car: Dictionary = cars[int(trip.car)]
	trip.state = "riding"
	car.state = "boarding"
	car.board_clock = 0.0
	trip.state = "boarding"
	car.path = path_between(car.node.global_position,trip.destination.point)
	car.index = 0
	person.riding_service = self
	person.set_meta("cab_car",int(trip.car))
	person.set_meta("cab_camera_mode",0)
	car.node.get_node("ServiceAudio").effect("door")
	person.set_meta("cab_reply","")
	car.node.get_node("CabDialogue").say(person,"welcome")
	person.visual.hide()
	person.collider.set_deferred("disabled",true)
	person.velocity = Vector3.ZERO
	return true

func cancel(person: Node3D) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or bookings[key].state in ["riding","boarding"]:
		return false
	var trip: Dictionary = bookings[key]
	if int(trip.car)>=0:
		var car: Dictionary = cars[int(trip.car)]
		if car.state in ["waiting","pickup"]:
			car.node.position += car.node.global_basis.x*2.7
		cars[int(trip.car)].state = "idle"
		cars[int(trip.car)].booking = ""
		cars[int(trip.car)].speed = 0.0
		cars[int(trip.car)].label.text = "AURORA • AVAILABLE"
	bookings.erase(key)
	person.set_meta("cab_waiting",false)
	return true

func seat_position(person: Node3D) -> Vector3:
	return cars[int(person.get_meta("cab_car"))].node.to_global(Vector3(0.4,0.8,-0.4))

func _physics_process(delta: float) -> void:
	update_clock += delta
	if update_clock<0.05:
		return
	delta = update_clock
	update_clock = 0
	elapsed += delta
	for key in bookings.keys():
		var trip: Dictionary = bookings[key]
		if not is_instance_valid(trip.person):
			_release_orphan(key)
		elif trip.state=="queued" and elapsed-float(trip.created)>120:
			_expire(trip,"All Auroras are busy. No fare taken. Please rebook.")
	_dispatch()
	for car in cars:
		if car.state in ["idle","waiting","boarding"]:
			car.node.get_node("ServiceAudio").set_motion(0,"electric")
		if car.state=="idle":
			_doors(car,0.0)
			continue
		if not bookings.has(car.booking):
			car.state = "idle"
			car.booking = ""
			continue
		var trip: Dictionary = bookings[car.booking]
		var person: Node3D = trip.person
		if car.state=="boarding":
			car.board_clock = float(car.board_clock)+delta
			_doors(car,clampf(float(car.board_clock),0,1) if float(car.board_clock)<2 else maxf(0,3.0-float(car.board_clock)))
			person.global_position = seat_position(person)
			if float(car.board_clock)>=3:
				car.state = "dropoff"
				trip.state = "riding"
			continue
		if car.state=="waiting":
			trip.wait = float(trip.wait)+delta
			if person.get_meta("cab_waiting",false) and person.global_position.distance_to(trip.pickup_curb)<4:
				unlock(person,trip.pin)
			elif float(trip.wait)>90:
				_expire(trip,"Pickup expired. No fare taken. Please book again when you are ready.")
			continue
		var path: PackedVector3Array = car.path
		if int(car.index)>=path.size():
			if car.state=="pickup":
				car.state = "waiting"
				trip.state = "waiting"
				car.label.text = "AURORA • ARRIVED\nEnter booking PIN"
			else:
				_finish(car,trip)
			continue
		var target: Vector3 = path[int(car.index)]
		var offset: Vector3 = target-car.node.global_position
		if offset.length()<0.15:
			car.index = int(car.index)+1
			continue
		var direction := offset.normalized()
		var travel: float = minf(10.0*delta,offset.length())
		travel = game.city.traffic.allowed_travel(car.node.global_position,direction,travel,2.5,car.node,person)
		car.speed = travel/maxf(delta,0.001)
		if travel>0.02:
			trip.last_progress = elapsed
		elif elapsed-float(trip.last_progress)>40 and car.state=="pickup":
			_expire(trip,"Your pickup road is blocked. No fare taken. Move to a clear pavement and rebook.")
			continue
		if car.state=="pickup" and elapsed-float(trip.created)>180:
			_expire(trip,"Aurora could not reach your pickup. No fare taken. Please rebook.")
			continue
		car.node.get_node("ServiceAudio").set_motion(float(car.speed),"electric")
		car.node.global_position += direction*travel
		car.node.rotation.y = lerp_angle(car.node.rotation.y,atan2(direction.x,direction.z),minf(1,delta*6))
		for wheel in car.node.get_meta("wheels"):
			wheel.rotation.x += travel/0.36
		if trip.state=="riding":
			person.global_position = seat_position(person)
	npc_clock += delta
	if npc_clock>=12:
		npc_clock = 0
		_npc_book()

func _finish(car: Dictionary, trip: Dictionary) -> void:
	var person: Node3D = trip.person
	economy.complete_fare(person)
	car.node.get_node("CabDialogue").say(person,"arrival")
	person.riding_service = null
	person.set_meta("cab_waiting",false)
	car.node.global_position += car.node.global_basis.x*2.7
	person.global_position = car.node.global_position+car.node.global_basis.x*3.5+Vector3(0,0.15,0)
	person.visual.show()
	person.collider.set_deferred("disabled",false)
	person.velocity = Vector3.ZERO
	car.state = "idle"
	car.speed = 0.0
	_doors(car,0)
	car.booking = ""
	car.label.text = "AURORA • AVAILABLE"
	bookings.erase(economy.key_for(person))

func _npc_book() -> void:
	for person in game.population.residents:
		if person.dead or person.resting!="" or person.current_house!=null or person.combat_time>0 or person.house_transition or person.riding_service!=null:
			continue
		if elapsed-float(person.get_meta("last_cab_booking",-1000))<180 or bookings.has(economy.key_for(person)):
			continue
		var destination := {"name":person.home.address,"point":person.home.entrance()} if economy.hour()>=18 else {"name":"Council office","point":economy.office}
		if person.global_position.distance_to(destination.point)<35:
			continue
		var trip := book(person,destination)
		if not trip.is_empty():
			person.set_meta("cab_waiting",true)
		return

func _doors(car: Dictionary, open: float) -> void:
	for door in car.node.get_meta("doors",[]):
		door.rotation.z = float(door.get_meta("side"))*open*1.15

func is_pickup_near(person: Node3D) -> bool:
	var key: String = economy.key_for(person)
	return bookings.has(key) and bookings[key].state=="waiting" and person.global_position.distance_to(bookings[key].pickup_curb)<5

# Repair stale references rather than trapping a player behind an obsolete booking.
func _reconcile(person: Node3D) -> void:
	var key: String = economy.key_for(person)
	if person.get("riding_service")==self and not bookings.has(key):
		person.riding_service = null
		person.visual.show()
		person.collider.set_deferred("disabled",false)
	if not bookings.has(key): return
	var trip: Dictionary = bookings[key]
	var index := int(trip.car)
	if trip.state!="queued" and (index<0 or index>=cars.size() or cars[index].booking!=key):
		_release_orphan(key)
		if person.get("riding_service")==self:
			person.riding_service = null
			person.visual.show()
			person.collider.set_deferred("disabled",false)

func _release_orphan(key: String) -> void:
	if economy.data.receipts.has(key) and economy.data.accounts.has(key):
		var refund := int(economy.data.receipts[key].amount)
		economy.data.accounts[key].balance = int(economy.data.accounts[key].balance)+refund
		economy.data.receipts.erase(key)
		economy.record(key,refund,"Unavailable Aurora trip refunded")
		economy.save()
	for car in cars:
		if car.booking==key:
			car.booking = ""
			car.state = "idle"
			car.speed = 0.0
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
	var destination_path := path_between(car.node.global_position,trip.destination.point)
	var end := destination_path[-1]
	if destination_path.size()>1:
		var forward := (end-destination_path[-2]).normalized()
		car.node.rotation.y = atan2(forward.x,forward.z)
	# Use a clear curb space so skipping cannot place the cab inside another car.
	var left: Vector3 = car.node.global_basis.x
	end += left*2.7
	for step in range(10):
		var clear := true
		for other in game.city.traffic.vehicle_nodes():
			if other!=car.node and other.visible and other.global_position.distance_to(end)<8:
				clear = false
		if clear: break
		end += car.node.global_basis.z*7.0
	car.node.global_position = end-left*2.7
	_finish(car,trip)
	return true

func talk(person: Node3D, topic: String) -> bool:
	var key: String = economy.key_for(person)
	if not bookings.has(key) or bookings[key].state not in ["boarding","riding"]:
		person.set_meta("cab_reply","Board your Aurora to have a conversation.")
		return false
	cars[int(bookings[key].car)].node.get_node("CabDialogue").say(person,topic)
	return true
