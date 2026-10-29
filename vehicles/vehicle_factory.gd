extends RefCounted

static func make(kind: String) -> Node3D:
	if kind=="bus":return _rental_bus()
	if kind in ["tow", "trailer"]:
		var path := "res://vehicles/tow_truck.tscn" if kind == "tow" else "res://vehicles/trailer_truck.tscn"
		var truck: Node3D = load(path).instantiate()
		truck.name = "TowTruck" if kind == "tow" else "TrailerTruck"
		var truck_body: VehicleBody3D = truck.get_node("Body")
		truck_body.display_name = "Tow truck" if kind == "tow" else "Articulated truck"
		truck_body.set_meta("driver_seat",Vector3(0.35,0.06,0.5))
		truck_body.set_meta("driver_scale",0.82)
		_refine_truck(truck_body)
		for camera in truck.find_children("*","Camera3D",true,false):camera.current=false
		truck_body.get_node("AudioListener3D").current=false
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
	body.set_meta("driver_seat",{"cybercab":Vector3(0.4,-0.19,-0.35),"sports":Vector3(0.35,-0.4,-0.15),"suv":Vector3(0.35,-0.15,-0.15),"van":Vector3(0.35,0.05,0.15)}[kind])
	body.set_meta("driver_scale",{"cybercab":0.9,"sports":0.75,"suv":0.80,"van":0.82}[kind])
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
	wheel.damping_compression = 5.0
	wheel.damping_relaxation = 5.5
	for child in wheel.get_children():
		child.free()

static func _build_cybercab(body:VehicleBody3D) -> void:
	var visual:=preload("res://vehicles/aurora_model.gd").make(0)
	visual.position.y=-.45;body.add_child(visual);body.set_meta("graphics",visual)
	for label in visual.find_children("*","Label3D",true,false):label.hide()
	var pivots:Array=visual.get_meta("wheels")
	for i in range(4):
		var source:Node3D=pivots[i];var wheel:VehicleWheel3D=body.get_node("Wheel"+str(i+1))
		_setup_wheel(wheel,source.position+Vector3(0,-.45,0),.35,source.position.z>0)
		visual.remove_child(source);wheel.add_child(source);source.position=Vector3.ZERO
	body.get_node("CollisionShape3D").shape.size=Vector3(1.9,1.5,4.3)
	body.get_node("CollisionShape3D").position.y=.5


static func _build_kenney(body: VehicleBody3D, kind: String) -> void:
	var color: Color = {"sports":Color("a82e42"),"suv":Color("2e587c"),"van":Color("dce2e1")}[kind]
	var visual := preload("res://vehicles/road_car.gd").make(kind,color)
	var pivots: Array = visual.get_meta("wheels")
	for i in range(4):
		var source: Node3D = pivots[i]
		var wheel: VehicleWheel3D = body.get_node("Wheel"+str(i+1))
		_setup_wheel(wheel,source.position-Vector3(0,0.65,0),0.37,source.position.z>0)
		visual.remove_child(source)
		wheel.add_child(source)
		source.position = Vector3.ZERO
	visual.position.y = -0.65
	body.add_child(visual)
	if kind=="suv" or kind=="van":
		body.get_node("CollisionShape3D").shape.size.y = 1.4 if kind=="suv" else 1.7
		body.mass = 1200.0 if kind=="suv" else 1400.0
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
static func traffic_visual(kind:String,color:Color) -> Node3D:
	if kind!="cybercab":return preload("res://vehicles/road_car.gd").make(kind,color)
	var visual:=preload("res://vehicles/aurora_model.gd").make(0)
	visual.name="Detailed_cybercab";visual.set_meta("vehicle_kind",kind)
	for label in visual.find_children("*","Label3D",true,false):label.hide()
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

static func _rental_bus() -> Node3D:
	var rig:=make("van")
	var body:VehicleBody3D=rig.get_node("Body")
	for child in body.get_children():
		if child.has_meta("vehicle_kind"):child.free()
	body.display_name="Rented city bus";body.mass=8000;body.engine_force_value=25000;body.brake_force=45000
	body.get_node("CollisionShape3D").shape=BoxShape3D.new();body.get_node("CollisionShape3D").shape.size=Vector3(2.5,3.8,10.2)
	body.get_node("CollisionShape3D").position=Vector3(0,1.35,0)
	for i in range(4):
		var wheel:VehicleWheel3D=body.get_node("Wheel"+str(i+1))
		for child in wheel.get_children():child.free()
		_setup_wheel(wheel,Vector3(1.05 if i<2 else -1.05,-.1,3.5 if i%2==0 else -3.5),.5,i%2==0)
		_cylinder(wheel,Vector3.ZERO,.5,.22,_material(Color("17202a")))
		_cylinder(wheel,Vector3(signf(wheel.position.x)*.12,0,0),.26,.02,_material(Color("b4c0c6"),.7))
	# Load at runtime: the existing bus visual also uses this factory's geometry helpers.
	var model=load("res://transport/bus_model.gd").new();model.route_number="RENT";model.livery=Color("3d8c85");model.position.y=-.65
	body.add_child(model)
	for wheel in model.wheels:wheel.hide() # The physical wheels below already provide the animated tyres.
	body.set_meta("entry_point",Vector3(-1.5,0,3.8));body.set_meta("driver_seat",Vector3(-.55,-.1,3.9));body.set_meta("driver_scale",.88)
	body.get_node("InteriorCameraPosition").position=Vector3(-.55,1.1,3.8)
	body.get_node("CameraBase/Camera3D").min_distance=9;body.get_node("CameraBase/Camera3D").max_distance=12
	return rig
