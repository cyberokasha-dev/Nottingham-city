extends Node3D

const GROUND_Y := -5.12
const ROAD_X := [-140.0,-80.0,-40.0,40.0,80.0,140.0]
const ROAD_Z := [-120.0,-60.0,16.0,80.0,140.0]
var houses: Array[Node3D] = []
var batches := {}
var grass: StandardMaterial3D
var asphalt: StandardMaterial3D
var pavement: StandardMaterial3D
var paint: StandardMaterial3D

func _ready() -> void:
	grass = _material(Color("648959"))
	asphalt = _material(Color("35414b"))
	pavement = _material(Color("aeb7b5"))
	paint = _material(Color("eee9d5"))
	_environment()
	_ground()
	_roads()
	_neighbourhoods()
	_finish_batches()
	var traffic := preload("res://town/traffic.gd").new()
	traffic.name = "UKTraffic"
	add_child(traffic)

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("699dcc")
	sky_material.sky_horizon_color = Color("d3e3ef")
	sky_material.ground_horizon_color = Color("d3e3ef")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff2dc")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

func _ground() -> void:
	_stamp(Vector3(0,GROUND_Y-0.15,10),Vector3(1200,0.3,1200),grass)
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1200,0.3,1200)
	collision.shape = shape
	ground.position = Vector3(0,GROUND_Y-0.15,10)
	ground.add_child(collision)
	add_child(ground)

func _roads() -> void:
	for x in ROAD_X:
		_stamp(Vector3(x,GROUND_Y+0.01,10),Vector3(12,0.02,320),asphalt)
		for z in range(-145,165,9):
			if _near_crossing(z,ROAD_Z):
				continue
			_stamp(Vector3(x,GROUND_Y+0.025,z),Vector3(0.12,0.015,3.5),paint)
		for i in range(ROAD_Z.size()-1):
			var length: float = ROAD_Z[i+1]-ROAD_Z[i]-16.0
			for side in [-1.0,1.0]:
				_stamp(Vector3(x+side*7.5,GROUND_Y+0.025,(ROAD_Z[i]+ROAD_Z[i+1])/2),Vector3(3,0.04,length),pavement)
	for z in ROAD_Z:
		_stamp(Vector3(0,GROUND_Y+0.011,z),Vector3(320,0.022,12),asphalt)
		for x in range(-155,160,9):
			if _near_crossing(x,ROAD_X):
				continue
			_stamp(Vector3(x,GROUND_Y+0.027,z),Vector3(3.5,0.015,0.12),paint)
		for i in range(ROAD_X.size()-1):
			var length: float = ROAD_X[i+1]-ROAD_X[i]-16.0
			for side in [-1.0,1.0]:
				_stamp(Vector3((ROAD_X[i]+ROAD_X[i+1])/2,GROUND_Y+0.025,z+side*7.5),Vector3(length,0.04,3),pavement)
	for x in ROAD_X:
		for z in ROAD_Z:
			# Stop/give-way markings keep intersections visibly distinct from through lanes.
			for side in [-1.0,1.0]:
				_stamp(Vector3(x+side*3,GROUND_Y+0.04,z+side*8),Vector3(4,0.012,0.20),paint)
			if z == 16.0:
				for i in range(-4,5):
					_stamp(Vector3(x+i*1.15,GROUND_Y+0.04,z+12),Vector3(0.6,0.012,3.6),paint)
			_street_sign(Vector3(x+8.4,GROUND_Y,z+8.4),ROAD_X.find(x),ROAD_Z.find(z))

func _near_crossing(value: float,crossings: Array) -> bool:
	for cross in crossings:
		if absf(value-cross)<9.0:
			return true
	return false

func _neighbourhoods() -> void:
	var colors := [Color("b57659"),Color("c4976f"),Color("9b6b58"),Color("dad1bc")]
	var number := 1
	for ix in range(ROAD_X.size()-1):
		for iz in range(ROAD_Z.size()-1):
			var cx: float = (ROAD_X[ix]+ROAD_X[ix+1])/2
			var cz: float = (ROAD_Z[iz]+ROAD_Z[iz+1])/2
			if ix == 2 and iz == 2:
				continue # Existing vehicle courtyard and its access to College Road.
			if (ix == 0 and iz == 1) or (ix == 4 and iz == 2):
				_park(Vector3(cx,GROUND_Y,cz))
				continue
			var width: float = ROAD_X[ix+1]-ROAD_X[ix]
			var offset := width*0.15 if width<=40.0 else width*0.22
			for row in [0,1]:
				for side in [-1.0,1.0]:
					var house := preload("res://town/house.gd").new()
					house.name = "House"+str(number)
					house.address = str(number)+" · "+["Northgate","Elm Street","College Road","City Avenue"][iz]
					house.brick_color = colors[(number-1)%colors.size()]
					house.position = Vector3(cx+side*offset,GROUND_Y+0.065,ROAD_Z[iz]+19 if row==0 else ROAD_Z[iz+1]-19)
					house.rotation.y = PI if row==0 else 0.0
					add_child(house)
					houses.append(house)
					var door_point: Vector3 = house.entrance()
					var path_z: float = (door_point.z+(ROAD_Z[iz] if row==0 else ROAD_Z[iz+1]))/2
					_stamp(Vector3(house.position.x,GROUND_Y+0.03,path_z),Vector3(2.6,0.04,10),pavement)
					number += 1

func _park(center: Vector3) -> void:
	var park_grass := _material(Color("789c64"))
	_stamp(center+Vector3(0,0.015,0),Vector3(28,0.03,32),park_grass)
	_stamp(center+Vector3(0,0.03,0),Vector3(3,0.03,32),pavement)
	for x in [-9.0,9.0]:
		for z in [-11.0,0.0,11.0]:
			_tree(center+Vector3(x,0,z))
		_stamp(center+Vector3(x,0.48,5),Vector3(2.0,0.20,0.55),_material(Color("775a3c")))
		_stamp(center+Vector3(x,0.83,4.8),Vector3(2.0,0.6,0.12),_material(Color("775a3c")))

func _tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.17
	cylinder.bottom_radius = 0.25
	cylinder.height = 2.4
	cylinder.radial_segments = 8
	trunk.mesh = cylinder
	trunk.material_override = _material(Color("705340"))
	trunk.position = pos+Vector3(0,1.2,0)
	add_child(trunk)
	var leaves := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.0
	sphere.radial_segments = 12
	sphere.rings = 6
	leaves.mesh = sphere
	leaves.material_override = _material(Color("43704e"))
	leaves.position = pos+Vector3(0,3.4,0)
	add_child(leaves)

func _street_sign(pos: Vector3,ix: int,iz: int) -> void:
	var metal := _material(Color("505e66"))
	_stamp(pos+Vector3(0,1.4,0),Vector3(0.10,2.8,0.10),metal)
	var label := Label3D.new()
	label.text = ["Castle Road","Market Street","Trent Avenue","Abbey Road","Station Street","Park Road"][ix]+"\n"+["Northgate","Elm Street","College Road","City Avenue","Southgate"][iz]
	label.font_size = 24
	label.pixel_size = 0.009
	label.position = pos+Vector3(0,2.6,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("dae5eb")
	add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _stamp(pos: Vector3,size: Vector3,material: Material) -> void:
	var key := material.get_instance_id()
	if not batches.has(key):
		batches[key] = {"material":material,"transforms":[]}
	batches[key].transforms.append(Transform3D(Basis.IDENTITY.scaled(size),pos))

func _finish_batches() -> void:
	for data in batches.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = BoxMesh.new()
		multi.mesh.size = Vector3.ONE
		multi.instance_count = data.transforms.size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i,data.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = data.material
		add_child(instance)
	batches.clear()
