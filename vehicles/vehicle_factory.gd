extends RefCounted

static func make(kind: String) -> Node3D:
	if kind in ["tow", "trailer"]:
		var path := "res://vehicles/tow_truck.tscn" if kind == "tow" else "res://vehicles/trailer_truck.tscn"
		var truck: Node3D = load(path).instantiate()
		truck.name = "TowTruck" if kind == "tow" else "TrailerTruck"
		var truck_body: VehicleBody3D = truck.get_node("Body")
		truck_body.display_name = "Tow truck" if kind == "tow" else "Articulated truck"
		_refine_truck(truck_body)
		return truck
	var car: Node3D = preload("res://vehicles/car_base.tscn").instantiate()
	car.name = kind.capitalize()
	var body: VehicleBody3D = car.get_node("Body")
	body.position = Vector3.ZERO
	body.mass = 900.0
	body.engine_force_value = 3800.0
	body.brake_force = 5500.0
	body.center_of_mass = Vector3(0, -0.2, 0)
	body.get_node("Body").free()
	body.get_node("BlobShadow").hide()
	body.get_node("CPUParticles3D").hide()
	body.get_node("AudioListener3D").current = false
	var camera: Camera3D = body.get_node("CameraBase/Camera3D")
	camera.current = false
	camera.min_distance = 5.5
	camera.max_distance = 7.5
	camera.height = 2.5
	camera.fov = 65.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 1.0, 4.2)
	body.get_node("CollisionShape3D").shape = shape
	body.get_node("CollisionShape3D").position = Vector3(0, 0.43, 0)
	body.get_node("InteriorCameraPosition").position = Vector3(-0.38, 0.88, 0.30)
	body.get_node("TopDownCameraPosition").position = Vector3(0, 16, 0)
	if kind == "cybercab":
		body.display_name = "Aurora"
		body.electric = true
		_build_cybercab(body)
	else:
		body.display_name = {"sports": "Sports sedan", "suv": "Luxury SUV", "van": "City van"}[kind]
		_build_kenney(body, kind)
	return car

static func _material(color: Color, metal := 0.0, roughness := 0.5, glow := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = roughness
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.5
	return material

static func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

static func _cylinder(parent: Node3D, pos: Vector3, radius: float, width: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 40
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.rotation.z = PI / 2.0
	mesh.position = pos
	parent.add_child(mesh)
	return mesh

static func _profile(parent: Node3D, slices: Array, material: Material) -> void:
	# Thin profile panels need both faces visible at cabin/roof seams.
	material = material.duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rings: Array[PackedVector3Array] = []
	for s in slices:
		var z: float = s[0]
		var w: float = s[1]
		var low: float = s[2]
		var shoulder: float = s[3]
		var top: float = s[4]
		rings.append(PackedVector3Array([Vector3(-w * 0.82, low, z), Vector3(-w, low + 0.07, z),
			Vector3(-w, shoulder, z), Vector3(-w * 0.83, top, z), Vector3(w * 0.83, top, z),
			Vector3(w, shoulder, z), Vector3(w, low + 0.07, z), Vector3(w * 0.82, low, z)]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rings.size() - 1):
		for i in range(8):
			var j := (i + 1) % 8
			for point in [rings[row][i], rings[row][j], rings[row + 1][i], rings[row][j], rings[row + 1][j], rings[row + 1][i]]:
				surface.add_vertex(point)
	for end in [0, rings.size() - 1]:
		var center := Vector3.ZERO
		for point in rings[end]:
			center += point / 8.0
		for i in range(8):
			var next := (i + 1) % 8
			var points := [center, rings[end][next], rings[end][i]] if end == 0 else [center, rings[end][i], rings[end][next]]
			for point in points:
				surface.add_vertex(point)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	parent.add_child(mesh)

static func _setup_wheel(wheel: VehicleWheel3D, pos: Vector3, radius: float, front: bool) -> void:
	wheel.position = pos
	wheel.wheel_radius = radius
	wheel.use_as_steering = front
	wheel.use_as_traction = true
	wheel.wheel_friction_slip = 2.8
	wheel.wheel_roll_influence = 0.15
	wheel.wheel_rest_length = 0.18
	wheel.suspension_travel = 0.20
	wheel.suspension_stiffness = 45.0
	wheel.suspension_max_force = 12000.0
	wheel.damping_compression = 4.5
	wheel.damping_relaxation = 5.0
	for child in wheel.get_children():
		child.free()

static func _build_cybercab(body: VehicleBody3D) -> void:
	var gold := _material(Color("b99b58"), 0.72, 0.28)
	var trim := _material(Color("181c23"), 0.15, 0.4)
	var glass := _material(Color("243445"), 0.65, 0.15)
	var light := _material(Color("d2f4ff"), 0.0, 0.2, true)
	var red := _material(Color("ff3838"), 0.0, 0.3, true)
	_profile(body, [[-2.22,0.75,0.04,0.39,0.46], [-1.70,0.93,0.01,0.51,0.63],
		[-0.80,0.98,0.01,0.52,0.63], [0.75,0.98,0.01,0.52,0.62],
		[1.55,0.92,0.05,0.44,0.52], [2.20,0.74,0.09,0.28,0.34]], gold)
	_profile(body, [[-1.39,0.71,0.58,0.60,0.62], [-0.53,0.76,0.59,1.06,1.12],
		[0.18,0.75,0.58,1.03,1.09], [1.03,0.72,0.57,0.59,0.61]], glass)
	_box(body, Vector3(0,0.02,0), Vector3(1.86,0.10,3.95), trim)
	_box(body, Vector3(0,0.26,2.21), Vector3(1.40,0.055,0.045), light)
	_box(body, Vector3(0,0.39,-2.23), Vector3(1.44,0.06,0.045), red)
	_box(body, Vector3(0,0.15,2.19), Vector3(1.36,0.07,0.05), trim)
	_box(body, Vector3(0,0.19,-2.25), Vector3(0.37,0.15,0.02), _material(Color("dce0d5")))
	for side in [-1.0,1.0]:
		_box(body, Vector3(side*0.988,0.39,-0.05), Vector3(0.018,0.30,1.66), gold)
		_box(body, Vector3(side*0.999,0.40,-0.40), Vector3(0.02,0.025,0.22), trim)
		_box(body, Vector3(side*0.984,0.12,0), Vector3(0.025,0.035,2.10), trim)
	var tire := _material(Color("101113"), 0, 0.9)
	for i in range(4):
		var side := 1.0 if i < 2 else -1.0
		var front := i % 2 == 0
		var wheel: VehicleWheel3D = body.get_node("Wheel" + str(i+1))
		_setup_wheel(wheel, Vector3(side*0.95,-0.08,1.43 if front else -1.42),0.36,front)
		_cylinder(wheel,Vector3.ZERO,0.36,0.25,tire)
		_cylinder(wheel,Vector3(side*0.135,0,0),0.295,0.018,gold)
		_cylinder(wheel,Vector3(side*0.148,0,0),0.075,0.02,trim)
	for x in [-0.40,0.40]:
		_box(body, Vector3(x,0.36,-0.35),Vector3(0.55,0.14,0.52),trim)
		var seat := _box(body,Vector3(x,0.64,-0.62),Vector3(0.55,0.63,0.16),trim)
		seat.rotation.x = -0.12
	_box(body,Vector3(0,0.66,0.57),Vector3(1.46,0.14,0.24),trim)
	_box(body,Vector3(0,0.77,0.44),Vector3(0.47,0.26,0.025),_material(Color("548399"),0,0.4,true))
	var headlamp := SpotLight3D.new()
	headlamp.position = Vector3(0,0.38,2.0)
	headlamp.rotation.y = PI
	headlamp.spot_range = 12.0
	headlamp.spot_angle = 40.0
	headlamp.light_energy = 1.5
	headlamp.light_color = Color("d2f4ff")
	body.add_child(headlamp)

static func _build_kenney(body: VehicleBody3D, kind: String) -> void:
	var path: String = {"sports":"res://vehicles/models/sedan-sports.glb", "suv":"res://vehicles/models/suv-luxury.glb", "van":"res://vehicles/models/van.glb"}[kind]
	var model: Node3D = load(path).instantiate()
	var scale_factor := 1.55
	model.scale = Vector3.ONE * scale_factor
	model.position.y = -0.465
	body.add_child(model)
	var names := ["wheel-front-left","wheel-back-left","wheel-front-right","wheel-back-right"]
	for i in range(4):
		var source: MeshInstance3D = model.get_node(names[i])
		var origin: Vector3 = source.position * scale_factor + model.position
		var side := 1.0 if i < 2 else -1.0
		var position := Vector3(side*0.72,origin.y,origin.z)
		var wheel: VehicleWheel3D = body.get_node("Wheel"+str(i+1))
		_setup_wheel(wheel, position, 0.465, i % 2 == 0)
		source.owner = null
		model.remove_child(source)
		wheel.add_child(source)
		source.position = origin-position
		source.scale = Vector3.ONE * scale_factor
	var lamp := _material(Color("d5edff"),0,0.25,true)
	var tail := _material(Color("d72f3f"),0,0.3,true)
	for side in [-1.0,1.0]:
		_box(body,Vector3(side*0.61,0.14,1.64),Vector3(0.29,0.10,0.035),lamp)
		_box(body,Vector3(side*0.6,0.17,-1.70),Vector3(0.22,0.13,0.035),tail)
	_box(body,Vector3(0,0.04,1.65),Vector3(0.7,0.11,0.035),_material(Color("26313b")))
	if kind == "suv":
		body.get_node("CollisionShape3D").shape.size.y = 1.4
		body.get_node("CollisionShape3D").position.y = 0.56
		body.mass = 1200.0
		body.engine_force_value = 4500.0
	if kind == "van":
		body.get_node("CollisionShape3D").shape.size.y = 1.65
		body.get_node("CollisionShape3D").position.y = 0.66
		body.mass = 1400.0
		body.engine_force_value = 4500.0

static func _refine_truck(body: VehicleBody3D) -> void:
	var metal := _material(Color(1,1,1),0.25,0.35)
	metal.vertex_color_use_as_albedo = true
	body.get_node("Body").material_override = metal
	for child in body.get_children():
		if child is VehicleWheel3D:
			_cylinder(child,Vector3(signf(child.position.x)*0.04,0,0),child.wheel_radius*0.55,0.03,_material(Color("c2c9d1"),0.75,0.25))
	for x in [-0.33,0.33]:
		_box(body,Vector3(x,0.45,1.31),Vector3(0.16,0.06,0.025),_material(Color("e0f7ff"),0,0.3,true))

# Reuse the actual fleet geometry without adding duplicate physics, cameras or audio.
static func traffic_visual(kind: String, color: Color) -> Node3D:
	var rig := make(kind)
	var body: VehicleBody3D = rig.get_node("Body")
	var visual := Node3D.new()
	visual.name = "Detailed_"+kind
	visual.set_meta("vehicle_kind",kind)
	var wheels: Array[Node3D] = []
	for child in body.get_children():
		if child is VehicleWheel3D:
			var wheel := Node3D.new()
			wheel.transform = child.transform
			visual.add_child(wheel)
			_copy_meshes(child,wheel,Transform3D.IDENTITY,kind,color)
			wheels.append(wheel)
		elif child is MeshInstance3D or (child is Node3D and child.name not in ["CameraBase","BlobShadow","InteriorCameraPosition","TopDownCameraPosition","AudioListener3D","CPUParticles3D"]):
			_copy_meshes(child,visual,child.transform,kind,color)
	visual.set_meta("wheels",wheels)
	# Physical car bodies sit above wheel contact, rather than at asphalt level.
	for child in visual.get_children():
		child.position.y += 0.45 if kind == "cybercab" else 0.9
	rig.free()
	return visual

static func _copy_meshes(source: Node, target: Node3D, transform: Transform3D, kind: String, color: Color) -> void:
	if source is MeshInstance3D and source.visible:
		var mesh := MeshInstance3D.new()
		mesh.mesh = source.mesh
		mesh.transform = transform
		mesh.material_override = source.material_override
		if kind != "cybercab" and "wheel" not in str(source.name) and source.material_override==null:
			var paint := ShaderMaterial.new()
			paint.shader = preload("res://vehicles/traffic_paint.gdshader")
			paint.set_shader_parameter("colormap",preload("res://vehicles/models/Textures/colormap.png"))
			paint.set_shader_parameter("paint",color)
			mesh.material_override = paint
		mesh.visibility_range_end = 140.0
		target.add_child(mesh)
	for child in source.get_children():
		if child is Node3D:
			_copy_meshes(child,target,transform*child.transform,kind,color)
