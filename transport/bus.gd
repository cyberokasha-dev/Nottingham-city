extends Node3D
const G = preload("res://transport/geometry.gd")
var manager: Node3D
var route: Dictionary
var distance := 0.0
var speed := 0.0
var dwell := 0.0
var state := "moving"
var model: Node3D
var stop_index := -1
var next_stop := 0
var passengers := 0
var rider: CharacterBody3D
var bell := false
var rider_commission:Dictionary={}
var services_completed := 0
var passenger_visuals: Array[Node3D] = []
var collider: AnimatableBody3D
var manifest: Array[Dictionary] = []
var dwell_elapsed := 0.0
var boarding_clock := 0.0
var next_departure := 0.0
var step_clock := 0.0
var rider_board_clock := 3.0
var rider_start := Vector3.ZERO
var cabin: Node3D
var passenger_transfers := 0
var loading: Label3D
var robotics_service_after:=45.0
var robotics_service_interval:=300.0
var robotics_service_bay:=-1
var robotics_service_clock:=0.0
var robotics_service_index:=0
var robotics_service_path:PackedVector3Array=PackedVector3Array()
var robotics_outbound_path:PackedVector3Array=PackedVector3Array()

func _ready() -> void:
	add_to_group("city_buses")
	model = preload("res://transport/bus_model.gd").new()
	model.route_number = route.number
	model.livery = route.color
	model.london = route.london
	add_child(model)
	model.destination.text = route.number+"  "+{"60":"GEDLING","61":"MAPPERLEY","44":"CARLTON","C1":"PARKS CIRCULAR"}[route.number]
	model.destination.font_size = 25
	model.destination.pixel_size = 0.0055
	collider = AnimatableBody3D.new()
	collider.sync_to_physics = false
	collider.collision_layer = 2
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5,4.2,10.2)
	shape.shape = box
	shape.position.y = 2.3
	collider.add_child(shape)
	add_child(collider)
	passengers = 0
	loading = G.label(model,"£2 • PUBLIC SERVICE",Vector3(0,2.2,5.17),17)
	loading.pixel_size = 0.004
	cabin = Node3D.new()
	cabin.name = "CabinPassengers"
	add_child(cabin)
	add_child(preload("res://simulation/service_audio.gd").new())
	_update_position()
	find_next_stop()
	preload("res://transport/vehicle_motion.gd").setup(self,model)

func _begin_robotics_service() -> bool:
	var cabs=manager.economy.game.cabs
	if not is_instance_valid(cabs):return false
	var bay_index:int=cabs._free_robotics_bay()
	if bay_index<0:
		robotics_service_after=manager.elapsed+30.0
		return false
	var bay_point:Vector3=cabs.robotics_bays[bay_index].point
	var path:PackedVector3Array=cabs._robotics_path_to_bay(global_position,bay_point,global_basis.z)
	if path.is_empty():
		robotics_service_after=manager.elapsed+30.0
		return false
	if path[0].distance_to(global_position)>.05:path.insert(0,global_position)
	cabs.robotics_bays[bay_index]["vehicle"]=self
	robotics_service_bay=bay_index
	robotics_outbound_path=path.duplicate()
	robotics_service_path=path
	robotics_service_index=0;robotics_service_clock=0.0;speed=0.0
	show();collider.get_child(0).set_deferred("disabled",false)
	state="robot_service_travel"
	loading.text="ROBOTICS • EN ROUTE"
	return true

func _release_robotics_service_bay() -> void:
	var cabs=manager.economy.game.cabs
	if is_instance_valid(cabs) and robotics_service_bay>=0 and robotics_service_bay<cabs.robotics_bays.size() and cabs.robotics_bays[robotics_service_bay].get("vehicle")==self:
		cabs.robotics_bays[robotics_service_bay]["vehicle"]=null
	robotics_service_bay=-1

func _advance_robotics_service(delta:float) -> void:
	var cabs=manager.economy.game.cabs
	if not is_instance_valid(cabs):
		_release_robotics_service_bay();state="moving";return
	if state=="robot_service_charge":
		speed=0.0;robotics_service_clock+=delta
		if robotics_service_clock>=22.0:
			var reverse:=PackedVector3Array([global_position])
			for i in range(robotics_outbound_path.size()-2,-1,-1):
				if reverse[-1].distance_to(robotics_outbound_path[i])>.05:reverse.append(robotics_outbound_path[i])
			robotics_service_path=reverse;robotics_service_index=0;state="robot_service_return"
			loading.text="ROBOTICS • RETURNING TO ROUTE"
		return
	if robotics_service_path.is_empty() or robotics_service_index>=robotics_service_path.size():
		if state=="robot_service_travel":
			if robotics_service_bay>=0 and robotics_service_bay<cabs.robotics_bays.size() and cabs.robotics_bays[robotics_service_bay].get("vehicle")==self:
				global_position=cabs.robotics_bays[robotics_service_bay].point
				robotics_service_clock=0.0;speed=0.0;state="robot_service_charge"
				loading.text="ROBOTICS • CHARGING"
			else:
				_release_robotics_service_bay();state="moving";robotics_service_after=manager.elapsed+30.0
		elif state=="robot_service_return":
			_release_robotics_service_bay()
			state="moving";speed=0.0;robotics_service_index=0
			robotics_service_path=PackedVector3Array();robotics_outbound_path=PackedVector3Array()
			robotics_service_after=manager.elapsed+robotics_service_interval
			loading.text="£2 • PUBLIC SERVICE"
		return
	var mover:Dictionary={"node":self,"path":robotics_service_path,"index":robotics_service_index,"speed":speed,"half_length":6.5,"body_size":Vector3(2.5,4.2,10.2),"fast":false}
	cabs._advance_route(mover,delta)
	robotics_service_index=int(mover.index);speed=float(mover.speed)

func find_next_stop() -> void:
	next_stop = 0
	for i in range(route.stops.size()):
		if float(route.stops[i].distance) > distance+1:
			next_stop = i
			break

func _physics_process(delta: float) -> void:
	advance(delta)

func _process(_delta:float) -> void:
	preload("res://transport/vehicle_motion.gd").render(self,model)

func advance(delta: float) -> void:
	if is_instance_valid(rider):
		rider_board_clock = minf(3.0,rider_board_clock+delta)
		var motion: Vector3=rider_position()-rider.global_position
		rider.global_position = rider_position()
		rider._play_clip("walk" if rider_board_clock<2.0 else "seated")
		if rider_board_clock>=2: rider.visual.fit_rider(false)
		if rider_board_clock>=3:
			rider.visual.mount(model,Vector3(0.70,0.43,1.8))
		elif rider_board_clock<2:
			rider.visual.face(motion,1)
		else:
			rider.visual.global_rotation.y=rotation.y+PI
	get_node("ServiceAudio").set_motion(speed,"bus" if visible else "silent")
	if state in ["robot_service_travel","robot_service_charge","robot_service_return"]:
		_advance_robotics_service(delta)
		return
	if state=="depot":
		speed = 0
		if manager.elapsed>=next_departure:
			if manager.elapsed>=robotics_service_after and not is_instance_valid(rider) and _begin_robotics_service():return
			show()
			collider.get_child(0).set_deferred("disabled",false)
			state = "moving"
		return
	if state == "dwell":
		speed = 0
		dwell -= delta
		dwell_elapsed += delta
		boarding_clock += delta
		if boarding_clock>=1.2 and model.door_fraction>=0.9:
			boarding_clock = 0
			manager.board_next(self)
		model.animate_doors(move_toward(model.door_fraction,1.0,delta*1.6))
		if dwell <= 0 and rider_board_clock>=3 and passenger_transfers==0:
			state = "closing"
	elif state == "closing":
		speed = 0
		model.animate_doors(move_toward(model.door_fraction,0,delta*1.6))
		if model.door_fraction <= 0:
			if stop_index==0 and manager.timetable_enabled and (not is_instance_valid(manager.economy) or not manager.economy.game.services.manual(self)) and not (is_instance_valid(manager.economy) and manager.economy.game.services.aboard.values().any(func(ride):return ride.vehicle==self)):
				next_departure = manager.reserve_departure(route.number)
				state = "depot"
				hide()
				collider.get_child(0).set_deferred("disabled",true)
			else:
				state = "moving"
	else:
		var remaining: float = fposmod(float(route.stops[next_stop].distance)-distance,float(route.length))
		var direction := global_basis.z.normalized()
		var straight := true
		for look in [3.0,9.0,18.0,27.0]:
			if direction.dot(manager.sample(route,distance+look).direction)<0.97: straight=false
		set_meta("traffic_straight",straight)
		var horizon:=maxf(8,speed*speed/7+2)
		var gap:float=manager.traffic.allowed_travel(global_position,direction,horizon,6.5,self)
		# Brake smoothly, then clamp precisely to the stop. Never skip on a long frame.
		var target_speed := minf(18.0 if straight else 8.0,sqrt(maxf(0,remaining)*4.0))
		if gap<horizon-.01:target_speed=minf(target_speed,sqrt(7*maxf(0,gap-.15)))
		if is_instance_valid(manager.economy) and is_instance_valid(manager.economy.game.services):target_speed*=manager.economy.game.services.throttle(self)
		speed = move_toward(speed,target_speed,delta*2.2)
		var allowed:float=manager.traffic.allowed_travel(global_position,direction,speed*delta,6.5,self)
		var travel := minf(speed*delta,allowed)
		travel = minf(travel,remaining)
		if allowed < speed*delta:
			speed = travel/maxf(delta,0.001)
		distance = fposmod(distance+travel,float(route.length))
		model.roll(travel)
		_update_position()
		if remaining-travel <= 0.04:
			arrive(next_stop)
	if is_instance_valid(rider):
		rider.global_position = rider_position()

func _update_position() -> void:
	var sample: Dictionary = manager.sample(route,distance)
	global_position = sample.position
	rotation.y = atan2(sample.direction.x,sample.direction.z)
	preload("res://transport/vehicle_motion.gd").warp_if_needed(self,model)
	manager.traffic.track_vehicle(self)

func arrive(index: int) -> void:
	stop_index = index
	next_stop = (index+1)%route.stops.size()
	state = "dwell"
	dwell = 12.0
	get_node("ServiceAudio").effect("door")
	dwell_elapsed = 0
	boarding_clock = 0
	var terminal: String = {"60":"GEDLING","61":"MAPPERLEY","44":"CARLTON","C1":"PARKS"}[route.number] if index<route.stops.size()/2 else "VICTORIA CENTRE"
	model.destination.text = route.number+"  "+terminal+"\nNext: "+str(route.stops[next_stop].name).left(23)
	model.destination.font_size = 18
	speed = 0
	services_completed += 1
	bell = false
	manager.exchange(self,route.stops[index])
	if index==0 and is_instance_valid(rider):
		model.animate_doors(1)
		leave(rider)

func entrance() -> Vector3:
	return to_global(Vector3(1.7,0,3.5))

func seat_position() -> Vector3:
	return model.to_global(Vector3(0.70,0.43,1.8))

func board(person: CharacterBody3D) -> bool:
	if state != "dwell" or model.door_fraction < 0.9 or is_instance_valid(rider) or person.global_position.distance_to(entrance()) > 4.0 or dwell_elapsed>56:
		return false
	if person.get("riding_service")!=null or person.riding_bus!=null or person.dead or person.driving or person.transitioning or person.resting != "" or is_instance_valid(person.active_house):
		return false
	if manager.economy==null:
		person._notify("Bus payment system is not ready. Please wait.")
		return false
	if not manager.economy.charge_transport(person,200,"Bus","Bus "+route.number+" fare"):
		person._notify("Bus fare £2.00 — not enough money")
		return false
	rider = person
	if is_instance_valid(manager.economy.game.services) and not manager.economy.has_day_pass(person):rider_commission=manager.economy.game.services.capture_fare(self,200,manager.economy.key_for(person))
	loading.text = "%d/20 ABOARD • £2" % (manifest.size()+1)
	person.riding_bus = self
	person.velocity = Vector3.ZERO
	person.collider.set_deferred("disabled",true)
	person.visual.show()
	rider_start = person.global_position
	rider_board_clock = 0
	dwell = minf(60-dwell_elapsed,maxf(dwell,3.5))
	person.foot_arm.add_excluded_object(collider.get_rid())
	person._notify("Route "+route.number+" • "+route.name+" • £2 fare paid — E: request stop · U: Quran on/off")
	if is_instance_valid(manager.recitation): manager.recitation.update_rider()
	return true

func leave(person: CharacterBody3D) -> bool:
	if person != rider or state != "dwell" or model.door_fraction < 0.9 or rider_board_clock<3:
		bell = true
		return false
	person.visual.dismount(person)
	person.global_position = route.stops[stop_index].pavement+Vector3(0,0.1,0)
	person.velocity = Vector3.ZERO
	person.riding_bus = null
	person.visual.visible = true
	person._play_clip("idle")
	person.foot_arm.remove_excluded_object(collider.get_rid())
	person.collider.set_deferred("disabled",false)
	person.invulnerability = 1.0
	rider = null
	if is_instance_valid(manager.economy.game.services):manager.economy.game.services.settle_trip(rider_commission)
	rider_commission={}
	loading.text = "%d/20 ABOARD • £2" % manifest.size()
	if is_instance_valid(manager.recitation): manager.recitation.update_rider()
	return true

func rider_position() -> Vector3:
	if rider_board_clock>=3: return seat_position()
	var door := entrance()+Vector3(0,0.6,0)
	var aisle := to_global(Vector3(0.15,0.6,3.1))
	if rider_board_clock<1: return rider_start.lerp(door,rider_board_clock)
	if rider_board_clock<2: return door.lerp(aisle,rider_board_clock-1)
	return aisle.lerp(seat_position(),rider_board_clock-2)

func npc_seat(index: int) -> Vector3:
	var row := int(index/2.0)%5
	var deck := 1.95 if index<10 else 0.0
	return Vector3(-0.75 if index%2==0 else 0.70,0.13+deck,-3.4+row*1.3)

func free_seat() -> int:
	for index in range(19): # Seat 19 stays available for the playable character.
		var used := false
		for record in manifest:
			if int(record.get("seat",record.person.get_meta("bus_seat",-1)))==index: used=true; break
		if not used: return index
	return -1

func boarding_path(index: int) -> Array[Vector3]:
	var seat := npc_seat(index)
	var points: Array[Vector3] = [Vector3(1.7,0.05,3.5),Vector3(1.28,0.6,3.5),Vector3(0.15,0.6,3.5)]
	if index<10:
		points.append(Vector3(0.0,0.6,-4.1))
		points.append(Vector3(-0.75,0.6,-4.1))
		for step in range(1,10): points.append(Vector3(-0.75,0.6+step*1.95/9.0,-4.1+step*0.18))
		points.append(Vector3(0,2.55,-2.48))
	points.append(Vector3(0,0.6+(1.95 if index<10 else 0.0),seat.z))
	points.append(seat)
	return points

func transfer_duration(a: Vector3,b: Vector3) -> float:
	return maxf(0.12,a.distance_to(b)/2.4)

func rebuild_cabin() -> void:
	if not is_instance_valid(cabin): return
	for child in cabin.get_children(): child.free()
	var groups := {}
	for record in manifest:
		var person: Node3D = record.person
		if person.get_parent()!=self or person.walking: continue
		for mesh in person.find_children("*","MeshInstance3D",true,false):
			var material: Material = mesh.material_override
			var key: int = material.get_instance_id()
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":material}
			for surface in range(mesh.mesh.get_surface_count()):
				groups[key].tool.append_from(mesh.mesh,surface,global_transform.affine_inverse()*mesh.global_transform)
		person.hide()
	for group in groups.values():
		var mesh := MeshInstance3D.new()
		mesh.mesh = group.tool.commit()
		mesh.material_override = group.material
		mesh.visibility_range_end = 65
		cabin.add_child(mesh)
	loading.text = "%d/20 ABOARD • £2" % (manifest.size()+int(is_instance_valid(rider)))
