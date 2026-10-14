extends Node3D
# Lightweight UK left-hand traffic. Ambient cars are visual only and never claim road physics.
const ROAD_X := [-140.0,-80.0,-40.0,40.0,80.0,140.0]
const ROAD_Z := [-120.0,-60.0,16.0,80.0,140.0]
const LEVEL := -5.02
const CYCLE := 9.0
const GREEN_SECONDS := 4.0
const HALF_CYCLE := 4.5
var clock := 0.0
var cars: Array[Dictionary] = []
var signals: Array[Dictionary] = []
var lamp_materials: Array[StandardMaterial3D] = []
var last_lamp_phase := -1
var transport: Node3D
var step_accumulator := 0.0
var pedestrians: Array[Node] = []
var autonomous_nodes: Array[Node3D] = []
var crowd_refresh := 0.0

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
					mesh.radial_segments = 8
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
						sphere.radial_segments = 8
						sphere.rings = 4
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
		car.add_child(preload("res://simulation/service_audio.gd").new())
		cars.append({"node":car,"vertical":vertical,"lane":lane,"direction":direction,"offset":offset,"distance":fposmod(i*23.7,310.0)-155.0,"kind":kind,"speed":7.0+float(i%5)*1.4})
	for item in cars:
		for attempt in range(100):
			var position := lane_position(item,float(item.distance))
			var clear := true
			for crossing in (ROAD_Z if item.vertical else ROAD_X):
				if absf(float(item.distance)-float(crossing))<14: clear=false
			for other in cars:
				if other==item: break
				if position.distance_to(lane_position(other,float(other.distance)))<6.2: clear=false
			if clear: break
			item.distance = fposmod(float(item.distance)+7.0+155.0,310.0)-155.0
		item.node.position = lane_position(item,float(item.distance))
	_process(0.0)

func _process(delta: float) -> void:
	step_accumulator += delta
	if delta>0 and step_accumulator<0.05:
		return
	delta = step_accumulator
	step_accumulator = 0.0
	crowd_refresh -= delta
	if crowd_refresh<=0:
		pedestrians = get_tree().get_nodes_in_group("people")
		crowd_refresh = 0.5
	clock = fposmod(clock+delta,CYCLE)
	_update_lamps()
	for item in cars:
		if item.get("taken",false):
			continue
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
		var heading := Vector3(0,0,direction) if vertical else Vector3(direction,0,0)
		travel = minf(travel,allowed_travel(item.node.position,heading,travel,2.3,item.node))
		# Clamp at the stop line even on a long frame. Cars already inside clear it.
		if not green and crossing>=11.99:
			travel = minf(travel,maxf(0,crossing-12.0))
		item.node.get_node("ServiceAudio").set_motion(travel/maxf(delta,0.001),"electric" if item.kind=="cybercab" else "engine")
		distance += direction*travel
		if distance>157.0 or distance< -157.0:
			var wrapped := -157.0 if distance>157.0 else 157.0
			var clear := true
			for other in vehicle_nodes():
				if other!=item.node and other.visible and other.global_position.distance_to(lane_position(item,wrapped))<9:
					clear = false
			distance = wrapped if clear else clampf(distance,-157,157)
		item.distance = distance
		for wheel in item.node.get_meta("wheels",[]):
			wheel.rotation.x += travel/0.42*direction
		var node: Node3D = item.node
		if vertical:
			node.position = Vector3(ROAD_X[item.lane]+item.offset,LEVEL,distance)
			node.rotation.y = 0.0 if direction>0 else PI
		else:
			node.position = Vector3(distance,LEVEL,ROAD_Z[item.lane]+item.offset)
			node.rotation.y = PI/2.0 if direction>0 else -PI/2.0

func _green(vertical: bool) -> bool:
	return clock<GREEN_SECONDS if vertical else (clock>=HALF_CYCLE and clock<HALF_CYCLE+GREEN_SECONDS)

func _update_lamps() -> void:
	var phase := 0
	for boundary in [4.0,4.25,4.5,8.5,8.75]:
		if clock>=boundary:
			phase += 1
	if phase == last_lamp_phase:
		return
	last_lamp_phase = phase
	for junction_signal in signals:
		var vertical: bool = junction_signal.vertical
		var green := _green(vertical)
		var amber := (clock>=4.0 and clock<4.25) if vertical else (clock>=8.5 and clock<8.75)
		var red_amber := clock>=8.75 if vertical else (clock>=4.25 and clock<4.5)
		var indices := [0 if not green and not amber else 1,2 if amber or red_amber else 3,4 if green else 5]
		for i in range(3):
			junction_signal.lamps[i].material_override = lamp_materials[indices[i]]

func _following_gap(item: Dictionary) -> float:
	var gap := 10000.0
	for other in cars:
		if other.get("taken",false) or other==item or other.vertical!=item.vertical or other.lane!=item.lane or other.direction!=item.direction:
			continue
		var ahead: float = fposmod((other.distance-item.distance)*item.direction,314.0)
		gap = minf(gap,maxf(0,ahead-6.0))
	if is_instance_valid(transport):
		var direction := Vector3(0,0,item.direction) if item.vertical else Vector3(item.direction,0,0)
		for bus in transport.buses:
			if not bus.visible:
				continue
			var offset: Vector3 = bus.global_position-item.node.global_position
			var ahead := offset.dot(direction)
			var lateral := (offset-direction*ahead).length()
			if ahead>0 and lateral<2.5 and bus.global_basis.z.dot(direction)>0.8:
				gap = minf(gap,maxf(0,ahead-9.0))
	for cab in autonomous_nodes:
		var heading := Vector3(0,0,item.direction) if item.vertical else Vector3(item.direction,0,0)
		var offset: Vector3 = cab.global_position-item.node.global_position
		var ahead := offset.dot(heading)
		if ahead>0 and (offset-heading*ahead).length()<2.5 and cab.global_basis.z.dot(heading)>0.7:
			gap = minf(gap,maxf(0,ahead-6.0))
	var heading := Vector3(0,0,item.direction) if item.vertical else Vector3(item.direction,0,0)
	gap = minf(gap,_pedestrian_gap(item.node.global_position,heading,4.5))
	return gap

# Shared traffic rule query for routed buses. Signal approaches and lane queues
# are checked before movement; a vehicle inside the junction is allowed to clear.
func allowed_travel(pos: Vector3, direction: Vector3, requested: float, half_length: float, ignore: Node3D, ignored_person: Node3D = null) -> float:
	var travel := requested
	var vertical := absf(direction.z)>0.95
	var horizontal := absf(direction.x)>0.95
	if vertical or horizontal:
		var axis := direction.z if vertical else direction.x
		var distance := pos.z if vertical else pos.x
		for crossing in (ROAD_Z if vertical else ROAD_X):
			var ahead: float = (float(crossing)-distance)*signf(axis)
			if ahead>=11.99:
				var junction := Vector3(pos.x if vertical else float(crossing),LEVEL,float(crossing) if vertical else pos.z)
				# Use road centres, not the offset lane coordinate.
				if vertical:
					for x in ROAD_X:
						if absf(pos.x-x)<6: junction.x=x; break
				else:
					for z in ROAD_Z:
						if absf(pos.z-z)<6: junction.z=z; break
				if not _green(vertical) or _junction_busy(junction,direction,ignore):
					travel = minf(travel,maxf(0,ahead-12.0))
	var obstacles := vehicle_nodes()
	for other in obstacles:
		if other == ignore or not other.visible:
			continue
		if absf(other.global_position.y-pos.y)>3: continue
		var offset: Vector3 = other.global_position-pos
		if offset.length()>half_length+requested+10: continue
		var other_length := 5.2 if other.is_in_group("city_buses") else 2.3
		var other_width := 1.3 if other.is_in_group("city_buses") else 1.0
		var forward := other.global_basis.z.normalized()
		var right := Vector3(direction.z,0,-direction.x)
		var other_right := Vector3(forward.z,0,-forward.x)
		# Swept oriented rectangles. This also sees cross traffic and turning buses.
		var entry := -INF
		var exit := INF
		for axis in [direction,right,forward,other_right]:
			var radius: float = absf(direction.dot(axis))*half_length+absf(right.dot(axis))*1.0+absf(forward.dot(axis))*other_length+absf(other_right.dot(axis))*other_width+0.45
			var center: float = offset.dot(axis)
			var motion: float = direction.dot(axis)
			if absf(motion)<0.001:
				if absf(center)>radius:
					exit = -INF
					break
			else:
				var a := (center-radius)/motion
				var b := (center+radius)/motion
				entry = maxf(entry,minf(a,b))
				exit = minf(exit,maxf(a,b))
		if entry<=exit and exit>=0:
			if entry>=0:
				travel = minf(travel,maxf(0,entry-0.15))
			elif offset.dot(direction)>0.1:
				# Existing overlap: only allow the vehicle moving out, never deeper in.
				travel = 0.0
	return minf(travel,_pedestrian_gap(pos,direction,half_length+1.2,ignored_person))

func _pedestrian_gap(pos: Vector3, direction: Vector3, clearance: float, ignored_person: Node3D = null) -> float:
	var gap := 10000.0
	if not is_inside_tree():
		return gap
	for person in pedestrians:
		if not is_instance_valid(person) or person==ignored_person:
			continue
		if person.driving or person.resting!="" or not person.visible:
			continue
		if is_instance_valid(person.get("riding_bus")) or is_instance_valid(person.get("riding_service")):
			continue
		var offset: Vector3 = person.global_position-pos
		var ahead := offset.dot(direction)
		if ahead>0 and (offset-direction*ahead).length()<1.6:
			gap = minf(gap,maxf(0,ahead-clearance))
	return gap

func nearest_car(person: Node3D) -> Dictionary:
	for item in cars:
		if not item.get("taken",false) and person.global_position.distance_to(item.node.global_position)<4.0:
			return item
	return {}

func claim_car(person: CharacterBody3D) -> bool:
	var item := nearest_car(person)
	if item.is_empty():
		return false
	item.taken = true
	var pose: Transform3D = item.node.global_transform
	item.node.hide()
	item.node.get_node("ServiceAudio").engine.stop()
	for collider in item.node.find_children("*","CollisionShape3D",true,false):
		collider.set_deferred("disabled",true)
	var rig := preload("res://vehicles/vehicle_factory.gd").make(item.kind)
	rig.transform = pose
	rig.position.y += 0.65
	var game: Node3D = person.party.game
	game.town.add_child(rig)
	var body: VehicleBody3D = rig.get_node("Body")
	body.park()
	game.fleet.append(body)
	await get_tree().physics_frame
	return person.try_enter()

func lane_position(item: Dictionary, distance: float) -> Vector3:
	return Vector3(ROAD_X[maxi(0,int(item.lane))]+item.offset,LEVEL,distance) if item.vertical else Vector3(distance,LEVEL,ROAD_Z[maxi(0,int(item.lane))]+item.offset)

func vehicle_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for item in cars:
		if not item.get("taken",false): nodes.append(item.node)
	for node in autonomous_nodes:
		if is_instance_valid(node): nodes.append(node)
	if is_instance_valid(transport): nodes.append_array(transport.buses)
	if is_inside_tree():
		for body in get_tree().get_nodes_in_group("driveable_vehicles"):
			if is_instance_valid(body): nodes.append(body)
	return nodes

func _junction_busy(center: Vector3, _heading: Vector3, ignore: Node3D) -> bool:
	# A vehicle commits when its centre passes the twelve-metre stop line.
	# Keep the whole box exclusive until it clears. Right-turning buses can
	# otherwise trap an opposing car halfway through their swept turn.
	for node in vehicle_nodes():
		if node==ignore or not node.visible: continue
		if absf(node.global_position.x-center.x)<11.9 and absf(node.global_position.z-center.z)<11.9:
			return true
	return false

func pavement_point(point: Vector3) -> Vector3:
	var safe := point
	for x in ROAD_X:
		if absf(point.x-x)<6.4: safe.x=x+(7.7 if point.x>=x else -7.7)
	for z in ROAD_Z:
		if absf(point.z-z)<6.4: safe.z=z+(7.7 if point.z>=z else -7.7)
	return safe

func pedestrian_may_enter(point: Vector3, movement: Vector3) -> bool:
	# People already crossing always finish; new crossings yield before the curb.
	for vertical in [true,false]:
		for road in (ROAD_X if vertical else ROAD_Z):
			var offset: float = (point.x if vertical else point.z)-float(road)
			var across: float = movement.x if vertical else movement.z
			if absf(offset)>6.0 and absf(offset)<8.0 and offset*across<0 and absf(across)>0.35 and _green(vertical):
				return false
	return true

func in_carriageway(point: Vector3) -> bool:
	for x in ROAD_X:
		if absf(point.x-x)<6: return true
	for z in ROAD_Z:
		if absf(point.z-z)<6: return true
	return false

func space_clear(pos: Vector3, direction: Vector3, ignore: Node3D) -> bool:
	var right := Vector3(direction.z,0,-direction.x)
	for other in vehicle_nodes():
		if other==ignore or not other.visible or absf(other.global_position.y-pos.y)>3: continue
		var offset: Vector3 = other.global_position-pos
		if offset.length()>12: continue
		var forward := other.global_basis.z.normalized()
		var side := Vector3(forward.z,0,-forward.x)
		var length := 5.2 if other.is_in_group("city_buses") else 2.3
		var width := 1.3 if other.is_in_group("city_buses") else 1.0
		var separated := false
		for axis in [direction,right,forward,side]:
			var radius: float = absf(direction.dot(axis))*2.3+absf(right.dot(axis))*1.0+absf(forward.dot(axis))*length+absf(side.dot(axis))*width+0.3
			if absf(offset.dot(axis))>radius: separated=true; break
		if not separated: return false
	return true
