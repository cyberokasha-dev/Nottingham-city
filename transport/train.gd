extends Node3D
const MAX_SPEED:=100.0 # 360 km/h; acceleration and braking distance determine actual speed.
const ACCEL:=9.0
const DECEL:=6.0
const STATION_DWELL:=30.0 # compact circle services keep platform waits short
var auto_leave:=false
var manager:Node3D
var route:Dictionary
var direction:=1
var lane:=-3.5
var distance:=0.0
var speed:=0.0
var state:="dwell"
var dwell:=20.0
var stop_index:=0
var initial_stop:=0
var next_stop:=1
var bell:=false
var rider:CharacterBody3D
var rider_board_clock:=14.0
var boarding_seconds:=14.0
var rider_start:=Vector3.ZERO
var boarding_path:PackedVector3Array=PackedVector3Array()
var model:Node3D
var door_fraction:=1.0
var stops_completed:=0
var peak_speed:=0.0
var public_manifest:Array[Dictionary]=[]
var service_id:=""
var rider_commission:Dictionary={}
func _ready() -> void:
	add_to_group("city_trains")
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	service_id=route.number+"/"+str(lane)+"/"+str(initial_stop)
	if route.get("loop",false):
		stop_index=initial_stop;next_stop=posmod(stop_index+direction,route.stops.size());distance=route.lengths[stop_index]
	elif direction<0: stop_index=route.stops.size()-1; next_stop=stop_index-1; distance=route.length
	_update_position()
	add_child(preload("res://simulation/service_audio.gd").new())
	# Passenger identity and fares exist independently of streamed visual models.
	for i in range(8):
		var key:="rail/"+service_id+"/"+str(i)
		var passenger:=Node.new()
		manager.game.economy.register(passenger,key,20000)
		var funded:bool=manager.game.economy.charge(passenger,400,"Rail "+route.number+" fare")
		public_manifest.append({"key":key,"variant":i+int(lane>0)*12,"funded":funded})
		passenger.free()

func ensure_model() -> void:
	if is_instance_valid(model): return
	model=preload("res://transport/train_model.gd").make(route.color)
	add_child(model)
	preload("res://transport/vehicle_motion.gd").setup(self,model)
	var label:=preload("res://transport/geometry.gd").label(model,route.number+" • "+str(route.stations[next_stop])+"\nCITY RAIL • £4",Vector3(0,4.5,20),22)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	model.set_meta("display",label)
	for i in range(public_manifest.size()):
		if not public_manifest[i].funded: continue
		var person:=preload("res://transport/crowd_person.gd").new(); person.variant=public_manifest[i].variant
		model.add_child(person); person.position=Vector3(-.65 if i%2==0 else .65,.22,[-24.0,-19.0,-14.0,-5.0][int(i/2.0)])
		person.scale=Vector3(.9,.94,.9); person.set_seated(true)
		person.set_meta("account_id",public_manifest[i].key)

func release_model() -> void:
	if is_instance_valid(rider) or not is_instance_valid(model): return
	model.free(); model=null

func travel_yaw() -> float:
	var tangent:Vector3=manager.sample(route,distance).direction*direction
	return atan2(tangent.x,tangent.z)
func _physics_process(delta:float) -> void:
	advance(delta)
func _process(_delta:float) -> void:
	if is_instance_valid(model):preload("res://transport/vehicle_motion.gd").render(self,model)
func advance(delta:float) -> void:
	if is_instance_valid(rider):
		rider_board_clock=minf(boarding_seconds,rider_board_clock+delta)
		if rider_board_clock<boarding_seconds-.5:
			rider.global_position=rider_position(); rider.visual.play("walk")
		else: rider.visual.mount(model,Vector3(.62,.48,22),PI)
	if state=="dwell":
		speed=0; dwell-=delta; door_fraction=move_toward(door_fraction,1,delta*1.5)
		if auto_leave and door_fraction>=.9 and is_instance_valid(rider) and rider_board_clock>=boarding_seconds:
			auto_leave=false
			leave(rider)
		if dwell<=0 and rider_board_clock>=boarding_seconds: state="closing"
	elif state=="closing":
		door_fraction=move_toward(door_fraction,0,delta*1.5)
		if door_fraction<=0: state="moving"
	else:
		var remaining:float=(float(route.lengths[next_stop])-distance)*direction
		if route.get("loop",false): remaining=fposmod(remaining,float(route.length))
		else: remaining=absf(remaining)
		var target:=minf(MAX_SPEED,sqrt(maxf(0,2*DECEL*maxf(0,remaining-.05))))
		if is_instance_valid(manager.game.services):target*=manager.game.services.throttle(self)
		speed=move_toward(speed,target,(ACCEL if target>speed else DECEL*1.5)*delta)
		var travel:=minf(speed*delta,remaining)
		distance+=travel*direction
		if route.get("loop",false): distance=fposmod(distance,float(route.length))
		peak_speed=maxf(peak_speed,speed)
		_update_position()
		if remaining-travel<.06:
			distance=route.lengths[next_stop]; stop_index=next_stop; stops_completed+=1
			if not route.get("loop",false) and (stop_index==0 or stop_index==route.stops.size()-1): direction=-direction
			next_stop=posmod(stop_index+direction,route.stops.size()); state="dwell"; dwell=STATION_DWELL; speed=0
			# A rider who pressed stop steps down onto the platform as soon as the doors are open.
			auto_leave=bell and is_instance_valid(rider); bell=false
			_update_position()
			_station_fares()
			if is_instance_valid(model): model.get_meta("display").text=route.number+" • "+str(route.stations[next_stop])+"\nCITY RAIL • £4"
	if is_instance_valid(model):
		for door in model.get_meta("doors"): door.position.z=22+door_fraction*1.6
	get_node("ServiceAudio").set_motion(speed/6,"electric")
	if is_instance_valid(rider): rider.global_position=rider_position()
func _update_position() -> void:
	var sample:Dictionary=manager.sample(route,distance)
	var tangent:Vector3=sample.direction
	global_position=sample.point+Vector3(tangent.z,0,-tangent.x)*lane
	rotation.y=atan2(tangent.x,tangent.z)
	preload("res://transport/vehicle_motion.gd").warp_if_needed(self,model)
func entrance() -> Vector3:
	var station:Dictionary=route.stops[stop_index]
	return station.point+Basis(Vector3.UP,float(station.heading))*Vector3(signf(lane)*24,0,0)
func is_board_near(person: Node3D) -> bool:
	return person.global_position.distance_to(entrance())<5 or (is_instance_valid(model) and person.global_position.distance_to(model.to_global(Vector3(signf(lane)*2,.6,22)))<4)
func seat_position() -> Vector3: return model.to_global(Vector3(.62,.48,22))
func rider_position() -> Vector3:
	if rider_board_clock>=boarding_seconds-.5: return seat_position()
	var phase:=clampf(rider_board_clock/maxf(.1,boarding_seconds-.5),0,.999)*float(boarding_path.size()-1)
	var index:=mini(floori(phase),boarding_path.size()-2)
	return boarding_path[index].lerp(boarding_path[index+1],fposmod(phase,1))
func board(person:CharacterBody3D) -> bool:
	if state!="dwell" or door_fraction<.9 or is_instance_valid(rider) or not is_board_near(person): return false
	if is_instance_valid(person.riding_bus) or is_instance_valid(person.riding_service) or person.dead or person.driving or person.transitioning or person.resting!="" or is_instance_valid(person.active_house): return false
	var covered: bool=manager.game.economy.has_day_pass(person)
	if not manager.game.economy.charge_transport(person,400,"Train","Rail "+route.number+" fare"):
		person._notify("Train fare £4 — not enough money"); return false
	ensure_model()
	manager.ensure_station(route.stops[stop_index],route)
	var station:Dictionary=route.stops[stop_index]
	var basis:=Basis(Vector3.UP,float(station.heading))
	var side:=signf(lane)
	boarding_path=PackedVector3Array([person.global_position,station.point+basis*Vector3(side*24,0,0),station.point+basis*Vector3(side*8,float(route.height),0),station.point+basis*Vector3(side*7,float(route.height),22),model.to_global(Vector3(side*2,.6,22)),seat_position()])
	if person.global_position.y>station.deck.y-2: boarding_path=PackedVector3Array([person.global_position,model.to_global(Vector3(side*2,.6,22)),seat_position()])
	var length:=0.0
	for i in range(1,boarding_path.size()): length+=boarding_path[i-1].distance_to(boarding_path[i])
	boarding_seconds=clampf(length/4,3,20)
	if is_instance_valid(manager.game.services):rider_commission=manager.game.services.capture_fare(self,400,manager.game.economy.key_for(person))
	rider=person; rider_board_clock=0; rider_start=person.global_position; auto_leave=false; dwell=minf(dwell,boarding_seconds+8)
	person.riding_bus=self; person.collider.set_deferred("disabled",true); person.velocity=Vector3.ZERO
	person._notify(route.number+" • "+str(route.stations[next_stop])+(" • City pass accepted" if covered else " • £4 paid")+" • E to leave at a station")
	get_node("ServiceAudio").effect("door")
	return true
func leave(person:CharacterBody3D) -> bool:
	if rider!=person: return false
	if state!="dwell" or speed>.05 or rider_board_clock<boarding_seconds: bell=true; person._notify("Next station: "+str(route.stations[next_stop])); return false
	person.visual.dismount(person); person.riding_bus=null; rider=null
	if is_instance_valid(manager.game.services):manager.game.services.settle_trip(rider_commission)
	rider_commission={}
	var station:Dictionary=route.stops[stop_index]
	person.global_position=station.deck+Basis(Vector3.UP,float(station.heading))*Vector3(signf(lane)*7,.1,22)
	person.collider.set_deferred("disabled",false)
	person._notify("Follow the level station exit to your neighbourhood or nearby bus and Aurora connection.")
	person.velocity=Vector3.ZERO; person.invulnerability=1
	return true

func _station_fares() -> void:
	# Existing passenger accounts pay for new actual rail journeys; no fare is invented.
	for i in range(3):
		var key:String=public_manifest[(stops_completed+i)%public_manifest.size()].key
		if manager.game.economy.charge_key(key,400,"Rail "+route.number+" passenger trip") and is_instance_valid(manager.game.services):
			manager.game.services.settle_trip(manager.game.services.capture_fare(self,400,key))
