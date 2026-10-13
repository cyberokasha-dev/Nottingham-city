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
var services_completed := 0
var passenger_visuals: Array[Node3D] = []
var collider: AnimatableBody3D

func _ready() -> void:
	add_to_group("city_buses")
	model = preload("res://transport/bus_model.gd").new()
	model.route_number = route.number
	model.livery = route.color
	model.london = route.london
	add_child(model)
	model.destination.text = route.number+"  "+{"60":"GEDLING","61":"CALVERTON","44":"GEDLING","C1":"PARKS CIRCULAR"}[route.number]
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
	var driver := preload("res://transport/crowd_person.gd").new()
	driver.variant = 4
	driver.position = Vector3(-0.65,0.45,3.8)
	driver.scale = Vector3(0.85,0.76,0.85)
	add_child(driver)
	# Low-cost upper-deck passengers stay with the bus as it turns.
	for i in range(4):
		var human := preload("res://transport/crowd_person.gd").new()
		human.variant = i+int(distance)
		human.position = Vector3(-0.72 if i%2==0 else 0.72,2.05,-2.1+floorf(i/2.0)*1.3)
		human.scale = Vector3(0.85,0.72,0.85)
		add_child(human)
		passenger_visuals.append(human)
	passengers = 2
	_update_position()
	for i in range(route.stops.size()):
		if float(route.stops[i].distance) > distance+1:
			next_stop = i
			break

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if state == "dwell":
		speed = 0
		dwell -= delta
		model.animate_doors(move_toward(model.door_fraction,1.0,delta*1.6))
		if dwell <= 0:
			state = "closing"
	elif state == "closing":
		speed = 0
		model.animate_doors(move_toward(model.door_fraction,0,delta*1.6))
		if model.door_fraction <= 0:
			state = "moving"
	else:
		var remaining: float = fposmod(float(route.stops[next_stop].distance)-distance,float(route.length))
		var direction := global_basis.z.normalized()
		var allowed: float = manager.traffic.allowed_travel(global_position,direction,10.0*delta,6.5,self)
		# Brake smoothly, then clamp precisely to the stop. Never skip on a long frame.
		var target_speed := minf(10.0,sqrt(maxf(0,remaining)*3.0))
		speed = move_toward(speed,target_speed,delta*2.2)
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
		rider.global_position = seat_position()

func _update_position() -> void:
	var sample: Dictionary = manager.sample(route,distance)
	global_position = sample.position
	rotation.y = atan2(sample.direction.x,sample.direction.z)

func arrive(index: int) -> void:
	stop_index = index
	next_stop = (index+1)%route.stops.size()
	state = "dwell"
	dwell = 7.0
	speed = 0
	services_completed += 1
	bell = false
	manager.exchange(self,route.stops[index])

func entrance() -> Vector3:
	return to_global(Vector3(1.7,0,3.5))

func seat_position() -> Vector3:
	return to_global(Vector3(0.68,2.9,0.5))

func board(person: CharacterBody3D) -> bool:
	if state != "dwell" or model.door_fraction < 0.9 or is_instance_valid(rider) or person.global_position.distance_to(entrance()) > 4.0:
		return false
	if person.dead or person.driving or person.transitioning or person.resting != "" or is_instance_valid(person.active_house):
		return false
	rider = person
	person.riding_bus = self
	person.velocity = Vector3.ZERO
	person.collider.set_deferred("disabled",true)
	person.visual.visible = false
	person.global_position = seat_position()
	person._notify("Route "+route.number+" • "+route.name+" — E to request next stop")
	return true

func leave(person: CharacterBody3D) -> bool:
	if person != rider or state != "dwell" or model.door_fraction < 0.9:
		bell = true
		return false
	person.global_position = route.stops[stop_index].pavement+Vector3(0,0.1,0)
	person.velocity = Vector3.ZERO
	person.riding_bus = null
	person.visual.visible = true
	person.collider.set_deferred("disabled",false)
	person.invulnerability = 1.0
	rider = null
	return true
