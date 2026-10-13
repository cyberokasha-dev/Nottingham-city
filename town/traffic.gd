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
				var pole := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.09
				mesh.bottom_radius = 0.09
				mesh.height = 3.8
				pole.mesh = mesh
				pole.position = Vector3(x+(-8.2 if vertical else 8.2),LEVEL+1.9,z+(8.2 if vertical else -8.2))
				add_child(pole)
				var housing := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.48,1.2,0.4)
				housing.mesh = box
				housing.position = pole.position+Vector3(0,1.5,0)
				add_child(housing)
				var lamps: Array[MeshInstance3D] = []
				for i in range(3):
					var lamp := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radius = 0.16
					sphere.height = 0.32
					lamp.mesh = sphere
					lamp.position = housing.position+Vector3(0,0.38-i*0.38,0.25)
					add_child(lamp)
					lamps.append(lamp)
				signals.append({"vertical":vertical,"lamps":lamps})
	for i in range(36):
		var vertical := i%2==0
		var lane: int = int(i/2.0)%6 if vertical else int(i/2.0)%5
		var direction := 1.0 if i%4<2 else -1.0
		var offset := (2.8 if vertical else -2.8)*direction
		var car := Node3D.new()
		var shell := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.75,0.75,3.7)
		shell.mesh = box
		shell.position.y = 0.72
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color("254e83"),Color("c8cbd0"),Color("ad3434"),Color("242a30"),Color("d9a73d"),Color("537d68")][i%6]
		shell.material_override = material
		car.add_child(shell)
		var roof := MeshInstance3D.new()
		var roof_mesh := BoxMesh.new()
		roof_mesh.size = Vector3(1.45,0.45,1.85)
		roof.mesh = roof_mesh
		roof.position.y = 1.25
		car.add_child(roof)
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
		# Clamp at the stop line even on a long frame. Cars already inside clear it.
		if not green and crossing>=12.0:
			travel = minf(travel,crossing-12.0)
		distance += direction*travel
		if distance>157.0:
			distance = -157.0
		elif distance< -157.0:
			distance = 157.0
		item.distance = distance
		var node: Node3D = item.node
		if vertical:
			node.position = Vector3(ROAD_X[item.lane]+item.offset,LEVEL,distance)
			node.rotation.y = 0.0 if direction>0 else PI
		else:
			node.position = Vector3(distance,LEVEL,ROAD_Z[item.lane]+item.offset)
			node.rotation.y = PI/2.0 if direction>0 else -PI/2.0

func _green(vertical: bool) -> bool:
	if vertical:
		return clock<10.0
	return clock>=12.0 and clock<22.0

func _update_lamps() -> void:
	var phase := 0 if clock<10.0 else (1 if clock<12.0 else (2 if clock<22.0 else 3))
	if phase == last_lamp_phase:
		return
	last_lamp_phase = phase
	for junction_signal in signals:
		var vertical: bool = junction_signal.vertical
		var green := _green(vertical)
		var amber := (clock>=10.0 and clock<12.0) if vertical else (clock>=22.0)
		var material_indices := [0 if not green and not amber else 1,2 if amber else 3,4 if green else 5]
		for i in range(3):
			junction_signal.lamps[i].material_override = lamp_materials[material_indices[i]]
