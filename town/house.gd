extends Node3D

var address := "Home"
var brick_color := Color("b46f4c")
var roof: Node3D
var front: Node3D
var door: Node3D
var interior: Node3D
var occupied := false
var rest_users := {}

func _ready() -> void:
	add_to_group("enterable_houses")
	var brick := _material(brick_color)
	var stone := _material(Color("eee5d2"))
	var slate := _material(Color("34404b"))
	var glass := _material(Color("456a83"), 0.3)
	var floor_material := _material(Color("b69369"))
	_box(self,Vector3(0,0,0),Vector3(10,0.12,12),floor_material,true)
	_box(self,Vector3(-5,1.7,0),Vector3(0.25,3.4,12),brick,true)
	_box(self,Vector3(5,1.7,0),Vector3(0.25,3.4,12),brick,true)
	_box(self,Vector3(0,1.7,-6),Vector3(10,3.4,0.25),brick,true)
	front = Node3D.new()
	add_child(front)
	_box(front,Vector3(-2.95,1.7,6),Vector3(4.1,3.4,0.25),brick,true)
	_box(front,Vector3(2.95,1.7,6),Vector3(4.1,3.4,0.25),brick,true)
	_box(front,Vector3(0,2.95,6),Vector3(1.8,0.9,0.25),brick,true)
	_box(front,Vector3(-0.96,1.3,6.15),Vector3(0.12,2.6,0.12),stone)
	_box(front,Vector3(0.96,1.3,6.15),Vector3(0.12,2.6,0.12),stone)
	_box(front,Vector3(0,2.62,6.15),Vector3(2.04,0.12,0.12),stone)
	for x in [-3.0,3.0]:
		_box(front,Vector3(x,1.8,6.15),Vector3(2.1,1.65,0.12),stone)
		_box(front,Vector3(x,1.8,6.23),Vector3(1.87,1.40,0.045),glass)
		_box(front,Vector3(x,1.8,6.27),Vector3(0.075,1.4,0.025),stone)
		_box(front,Vector3(x,1.8,6.27),Vector3(1.9,0.075,0.025),stone)
		_box(front,Vector3(x,0.97,6.24),Vector3(2.25,0.10,0.28),stone)
	for side in [-1.0,1.0]:
		for z in [-2.5,2.5]:
			_box(self,Vector3(side*5.15,1.8,z),Vector3(0.10,1.65,2.1),stone)
			_box(self,Vector3(side*5.23,1.8,z),Vector3(0.04,1.42,1.86),glass)
	roof = Node3D.new()
	add_child(roof)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(-5.5,3.45,-6.5),Vector3(-5.5,3.45,6.5),Vector3(0,5.5,-6.5),Vector3(0,5.5,6.5),Vector3(5.5,3.45,-6.5),Vector3(5.5,3.45,6.5)]
	for index in [0,1,2,1,3,2,2,3,4,3,5,4,0,2,4,1,5,3]:
		surface.add_vertex(p[index])
	surface.generate_normals()
	var roof_mesh := MeshInstance3D.new()
	roof_mesh.mesh = surface.commit()
	var roof_mat := slate.duplicate()
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof_mesh.material_override = roof_mat
	roof.add_child(roof_mesh)
	_box(roof,Vector3(2.5,4.7,-2),Vector3(0.7,2.0,0.7),brick)
	_box(roof,Vector3(2.5,5.72,-2),Vector3(0.9,0.13,0.9),stone)
	_box(roof,Vector3(0,2.8,7.0),Vector3(2.8,0.16,1.8),slate)
	door = Node3D.new()
	door.position = Vector3(-0.88,0,6.02)
	add_child(door)
	_box(door,Vector3(0.88,1.25,0),Vector3(1.75,2.5,0.13),_material(Color("274943")),true)
	_box(door,Vector3(1.56,1.1,0.10),Vector3(0.08,0.10,0.09),_material(Color("c5a66b")))
	_box(door,Vector3(0.88,1.9,0.09),Vector3(1.25,0.60,0.05),glass)
	var number := Label3D.new()
	number.text = address
	number.font_size = 26
	number.pixel_size = 0.008
	number.position = Vector3(0,2.77,7.12)
	add_child(number)
	# Interiors are instantiated only when needed; every house has its own entrance.
	for mesh in find_children("*","MeshInstance3D",true,false):
		mesh.visibility_range_end = 190.0

func entrance() -> Vector3:
	return to_global(Vector3(0,0.14,7.8))

func inside_point() -> Vector3:
	return to_global(Vector3(0,0.14,3.8))

func set_inside(active: bool) -> void:
	occupied = active
	if active and not is_instance_valid(interior):
		_build_interior()
	if is_instance_valid(interior):
		interior.visible = active
	roof.visible = not active
	# Cutaway front keeps the third-person camera outside the room readable.
	for child in front.get_children():
		if child is MeshInstance3D:
			child.visible = not active

func open_door(opened: bool) -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(door,"rotation:y",-PI/2 if opened else 0.0,0.25)
	await tween.finished

func _build_interior() -> void:
	interior = Node3D.new()
	add_child(interior)
	var cream := _material(Color("f1eadb"))
	var wood := _material(Color("755538"))
	var blue := _material(Color("305a73"))
	var white := _material(Color("d7dad6"))
	var dark := _material(Color("222933"))
	_box(interior,Vector3(0,0.075,0),Vector3(9.6,0.03,11.6),_material(Color("735d45")))
	for x in range(-4,5):
		_box(interior,Vector3(x+0.5,0.092,0),Vector3(0.018,0.002,11.6),_material(Color("51432f")))
	_box(interior,Vector3(-4.79,1.6,0),Vector3(0.03,3.2,11.7),cream)
	_box(interior,Vector3(4.79,1.6,0),Vector3(0.03,3.2,11.7),cream)
	_box(interior,Vector3(0,1.6,-5.78),Vector3(9.6,3.2,0.03),cream)
	# Living area, kitchen and sleeping area with clear walkways.
	_box(interior,Vector3(-2.9,0.43,0.6),Vector3(2.7,0.60,1.0),blue,true)
	_box(interior,Vector3(-2.9,0.87,0.17),Vector3(2.7,0.65,0.18),blue,true)
	for x in [-4.15,-1.65]:
		_box(interior,Vector3(x,0.70,0.6),Vector3(0.20,0.60,1.0),blue)
	for x in [-3.75,-2.9,-2.05]:
		_box(interior,Vector3(x,0.77,0.6),Vector3(0.80,0.10,0.78),_material(Color("3e718d")))
	_box(interior,Vector3(-2.9,0.12,2.2),Vector3(3.1,0.03,3.0),_material(Color("c47d5b")))
	_box(interior,Vector3(-2.9,0.35,2.0),Vector3(1.8,0.48,0.75),wood,true)
	_box(interior,Vector3(-2.9,1.4,-5.68),Vector3(2.0,1.1,0.07),dark)
	_box(interior,Vector3(3.65,0.60,-0.9),Vector3(1.65,1.1,3.7),white,true)
	_box(interior,Vector3(3.65,1.18,-0.9),Vector3(1.75,0.08,3.8),wood)
	_box(interior,Vector3(3.7,1.22,-0.9),Vector3(0.95,0.03,0.65),_material(Color("7e8d93")))
	_box(interior,Vector3(3.8,1.1,-4.5),Vector3(1.25,2.0,1.3),white,true)
	_box(interior,Vector3(-1.7,0.44,-3.8),Vector3(2.4,0.63,2.9),wood,true)
	_box(interior,Vector3(-1.7,0.83,-3.8),Vector3(2.35,0.20,2.85),_material(Color("748b9b")))
	_box(interior,Vector3(-1.7,0.99,-4.8),Vector3(1.7,0.18,0.55),white)
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.8,0)
	light.light_color = Color("fff0d8")
	light.light_energy = 0.45
	light.omni_range = 10.0
	interior.add_child(light)

func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.metallic = metallic
	return material

func _box(parent: Node3D,pos: Vector3,size: Vector3,material: Material,solid := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = pos
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

# Approach positions have clearance beside the furniture, not on its collider.
func rest_approach(action: String) -> Vector3:
	return to_global(Vector3(0,0.14,-3.8) if action == "sleep" else Vector3(-1.0,0.14,1.15))

func rest_pose(action: String) -> Vector3:
	return to_global(Vector3(-1.7,1.05,-2.65) if action == "sleep" else Vector3(-2.9,0.30,0.91))

func claim_rest(action: String, actor: Node3D) -> bool:
	if action not in ["sit","sleep"]:
		return false
	if is_instance_valid(rest_users.get(action)):
		return false
	rest_users[action] = actor
	if not is_instance_valid(interior):
		_build_interior()
		interior.visible = occupied
	return true

func release_rest(action: String, actor: Node3D) -> void:
	if rest_users.get(action) == actor:
		rest_users.erase(action)
