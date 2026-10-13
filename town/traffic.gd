extends Node3D
# Lightweight UK left-hand traffic. Ambient cars are visual only and never claim road physics.
const ROAD_X := [-140.0,-80.0,-40.0,40.0,80.0,140.0]
const ROAD_Z := [-120.0,-60.0,16.0,80.0,140.0]
const LEVEL := -5.02
const CYCLE := 24.0
var clock := 0.0
var cars: Array[Dictionary] = []
var signals: Array[Dictionary] = []
var lamp_materials: Array[StandardMaterial3D] = []
var last_lamp_phase := -1
var transport: Node3D

func _ready() -> void:
	# Share the six lamp materials instead of allocating 180 materials every frame.
	for color in [Color.RED,Color("391616"),Color.YELLOW,Color("39341b"),Color.GREEN,Color("18311c")]:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
		lamp_materials.append(material)
	for x in ROAD_X:
		for z in ROAD_Z:
			for vertical in [true,false]:
				for direction in [-1.0,1.0]:
					var head := Node3D.new()
					head.position = Vector3(x+8.2*direction,LEVEL,z-10.0*direction) if vertical else Vector3(x-10.0*direction,LEVEL,z-8.2*direction)
					head.rotation.y = (PI if direction>0 else 0.0) if vertical else (-PI/2 if direction>0 else PI/2)
					add_child(head)
					var pole := MeshInstance3D.new()
					var mesh := CylinderMesh.new()
					mesh.top_radius = 0.09
					mesh.bottom_radius = 0.09
					mesh.height = 3.8
					pole.mesh = mesh
					pole.position.y = 1.9
					head.add_child(pole)
					var housing := MeshInstance3D.new()
					var box := BoxMesh.new()
					box.size = Vector3(0.48,1.2,0.4)
					housing.mesh = box
					housing.position.y = 3.4
					housing.material_override = lamp_materials[1]
					head.add_child(housing)
					var lamps: Array[MeshInstance3D] = []
					for i in range(3):
						var lamp := MeshInstance3D.new()
						var sphere := SphereMesh.new()
						sphere.radius = 0.16
						sphere.height = 0.32
						lamp.mesh = sphere
						lamp.position = Vector3(0,3.78-i*0.38,0.25)
						head.add_child(lamp)
						lamps.append(lamp)
					signals.append({"vertical":vertical,"lamps":lamps})
	for i in range(48):
		var vertical := i%2==0
		var lane: int = int(i/4.0)%(6 if vertical else 5)
		var direction := 1.0 if i%4<2 else -1.0
		var offset := (2.8 if vertical else -2.8)*direction
		var kind: String = ["sports","suv","sports","van","cybercab","sports"][i%6]
		var color: Color = [Color("294c86"),Color("ebeee9"),Color("b9333b"),Color("30373c"),Color("b99b58"),Color("3e8067"),Color("7e5192"),Color("aaaeb6")][i%8]
		var car := preload("res://vehicles/vehicle_factory.gd").traffic_visual(kind,color)
		var collision_body := AnimatableBody3D.new()
		collision_body.sync_to_physics = false
		collision_body.collision_layer = 2
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.8,1.5,4.3)
		collider.shape = shape
		collider.position.y = 0.9
		collision_body.add_child(collider)
		car.add_child(collision_body)
		add_child(car)
		cars.append({"node":car,"vertical":vertical,"lane":lane,"direction":direction,"offset":offset,"distance":fposmod(i*23.7,310.0)-155.0,"speed":7.0+float(i%5)*1.4})
	_process(0.0)

func _process(delta: float) -> void:
	clock = fposmod(clock+delta,CYCLE)
	_update_lamps()
	for item in cars:
		var vertical: bool = item.vertical
		var direction: float = item.direction
		var distance: float = item.distance
		var speed: float = item.speed
		var crossing: float = 10000.0
		var roads: Array = ROAD_Z if vertical else ROAD_X
		for road in roads:
			var ahead: float = (float(road)-distance)*direction
			if ahead>0.0 and ahead<crossing:
				crossing = ahead
		var green := _green(vertical)
		var travel := speed*delta
		travel = minf(travel,_following_gap(item))
		# Clamp at the stop line even on a long frame. Cars already inside clear it.
		if not green and crossing>=11.99:
			travel = minf(travel,crossing-12.0)
		distance += direction*travel
		if distance>157.0:
			distance = -157.0
		elif distance< -157.0:
			distance = 157.0
		item.distance = distance
		for wheel in item.node.get_meta("wheels",[]):
			wheel.rotation.x += travel/0.42
		var node: Node3D = item.node
		if vertical:
			node.position = Vector3(ROAD_X[item.lane]+item.offset,LEVEL,distance)
			node.rotation.y = 0.0 if direction>0 else PI
		else:
			node.position = Vector3(distance,LEVEL,ROAD_Z[item.lane]+item.offset)
			node.rotation.y = PI/2.0 if direction>0 else -PI/2.0

func _green(vertical: bool) -> bool:
	return clock<9.0 if vertical else (clock>=12.0 and clock<21.0)

func _update_lamps() -> void:
	var phase := 0
	for boundary in [9.0,10.0,11.0,12.0,21.0,22.0,23.0]:
		if clock>=boundary:
			phase += 1
	if phase == last_lamp_phase:
		return
	last_lamp_phase = phase
	for junction_signal in signals:
		var vertical: bool = junction_signal.vertical
		var green := _green(vertical)
		var amber := (clock>=9.0 and clock<10.0) if vertical else (clock>=21.0 and clock<22.0)
		var red_amber := clock>=23.0 if vertical else (clock>=11.0 and clock<12.0)
		var indices := [0 if not green and not amber else 1,2 if amber or red_amber else 3,4 if green else 5]
		for i in range(3):
			junction_signal.lamps[i].material_override = lamp_materials[indices[i]]

func _following_gap(item: Dictionary) -> float:
	var gap := 10000.0
	for other in cars:
		if other==item or other.vertical!=item.vertical or other.lane!=item.lane or other.direction!=item.direction:
			continue
		var ahead: float = fposmod((other.distance-item.distance)*item.direction,314.0)
		gap = minf(gap,maxf(0,ahead-6.0))
	if is_instance_valid(transport):
		var direction := Vector3(0,0,item.direction) if item.vertical else Vector3(item.direction,0,0)
		for bus in transport.buses:
			var offset: Vector3 = bus.global_position-item.node.global_position
			var ahead := offset.dot(direction)
			var lateral := (offset-direction*ahead).length()
			if ahead>0 and lateral<2.5 and bus.global_basis.z.dot(direction)>0.8:
				gap = minf(gap,maxf(0,ahead-9.0))
	var heading := Vector3(0,0,item.direction) if item.vertical else Vector3(item.direction,0,0)
	gap = minf(gap,_pedestrian_gap(item.node.global_position,heading,4.5))
	return gap

# Shared traffic rule query for routed buses. Signal approaches and lane queues
# are checked before movement; a vehicle inside the junction is allowed to clear.
func allowed_travel(pos: Vector3, direction: Vector3, requested: float, half_length: float, ignore: Node3D) -> float:
	var travel := requested
	var vertical := absf(direction.z)>0.95
	var horizontal := absf(direction.x)>0.95
	if vertical or horizontal:
		var axis := direction.z if vertical else direction.x
		var distance := pos.z if vertical else pos.x
		for crossing in (ROAD_Z if vertical else ROAD_X):
			var ahead: float = (float(crossing)-distance)*signf(axis)
			if ahead>=11.99 and not _green(vertical):
				travel = minf(travel,maxf(0,ahead-12.0))
	var obstacles: Array[Node3D] = []
	for item in cars:
		obstacles.append(item.node)
	if is_instance_valid(transport):
		obstacles.append_array(transport.buses)
	for other in obstacles:
		if other == ignore:
			continue
		var offset: Vector3 = other.global_position-pos
		var ahead := offset.dot(direction)
		var lateral := (offset-direction*ahead).length()
		if ahead>0 and lateral<2.6 and other.global_basis.z.dot(direction)>0.7:
			var other_length := 5.2 if other.is_in_group("city_buses") else 2.3
			travel = minf(travel,maxf(0,ahead-half_length-other_length-1.8))
	return minf(travel,_pedestrian_gap(pos,direction,half_length+1.2))

func _pedestrian_gap(pos: Vector3, direction: Vector3, clearance: float) -> float:
	var gap := 10000.0
	if not is_inside_tree():
		return gap
	for person in get_tree().get_nodes_in_group("people"):
		if person.driving or person.resting!="" or not person.visible:
			continue
		if person.get("riding_bus")!=null:
			continue
		var offset: Vector3 = person.global_position-pos
		var ahead := offset.dot(direction)
		if ahead>0 and (offset-direction*ahead).length()<1.6:
			gap = minf(gap,maxf(0,ahead-clearance))
	return gap
