extends Node3D
# Low-cost sculpted pedestrians: shared static geometry, articulated legs and arms.
const G = preload("res://transport/geometry.gd")
var variant := 0
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []
var phase := 0.0
var walking := false:
	set(value):
		walking=value
		set_process(value)
		_show_static()
var knees: Array[Node3D] = []
var seated := false
static var palette: Dictionary = {}

static func paint(color: Color) -> Material:
	if not palette.has(color): palette[color] = G.material(color)
	return palette[color]

static var templates: Dictionary = {}
var rig: Node3D
var still: MeshInstance3D

func _ready() -> void:
	var key:=variant%12
	if not templates.has(key):
		var source:=_build_rig()
		var standing:=G.colored_mesh(source)
		_pose(true)
		var sitting:=G.colored_mesh(source)
		_pose(false)
		for node in source.find_children("*","",true,false): node.owner=source
		var scene:=PackedScene.new()
		scene.pack(source)
		templates[key]={"standing":standing,"sitting":sitting,"rig":scene}
		source.free()
		legs.clear(); knees.clear(); arms.clear()
	still=MeshInstance3D.new()
	still.visibility_range_end=45
	add_child(still)
	_show_static()
	set_process(walking)

func _show_static() -> void:
	if not is_instance_valid(still): return
	still.mesh=templates[variant%12].sitting if seated else templates[variant%12].standing
	still.material_override=still.mesh.surface_get_material(0)
	still.visible=not walking
	if walking:
		if not is_instance_valid(rig):
			rig=templates[variant%12].rig.instantiate()
			add_child(rig)
			for i in range(2):
				legs.append(rig.get_node("Leg"+str(i)))
				knees.append(legs[-1].get_node("Knee"))
				arms.append(rig.get_node("Arm"+str(i)))
		_pose(seated)
	elif is_instance_valid(rig):
		rig.free(); rig=null
		legs.clear(); knees.clear(); arms.clear()

func _build_rig() -> Node3D:
	var rig := Node3D.new()
	var skin := paint([Color("824e33"),Color("cf9b75"),Color("e0b795"),Color("533522")][variant%4])
	var shirt := paint([Color("317b99"),Color("9c5066"),Color("ccae55"),Color("5b8c68"),Color("e8ded0"),Color("555a91")][variant%6])
	var pants := paint(Color("293444"))
	var hair := paint(Color("262019"))
	var torso := Node3D.new()
	rig.add_child(torso)
	G.sphere(torso,Vector3(0,1.16,0),Vector3(0.42+float(variant%4)*0.025,0.65,0.29),shirt)
	G.tube(torso,Vector3(0,1.38,0),Vector3(0,1.52,0),0.075,skin)
	G.sphere(torso,Vector3(0,1.65,0),Vector3(0.25,0.32,0.25),skin)
	G.sphere(torso,Vector3(0,1.76,-0.015),Vector3(0.265,0.16,0.25),hair)
	# Readable faces and different hair silhouettes remain in the same material batches.
	var eyes := paint(Color("e8ded0"))
	for side in [-1.0,1.0]:
		G.sphere(torso,Vector3(side*0.052,1.67,0.111),Vector3(0.05,0.027,0.016),eyes)
		G.sphere(torso,Vector3(side*0.052,1.67,0.122),Vector3(0.021,0.024,0.011),hair)
		G.sphere(torso,Vector3(side*0.127,1.65,0),Vector3(0.04,0.075,0.04),skin)
	G.sphere(torso,Vector3(0,1.63,0.128),Vector3(0.04,0.055,0.048),skin)
	if variant%3==0: G.sphere(torso,Vector3(0,1.73,-0.12),Vector3(0.13,0.13,0.13),hair)
	if variant%4==1: G.sphere(torso,Vector3(0,1.79,0),Vector3(0.26,0.10,0.25),shirt)
	G.merge(torso)
	for side in [-1.0,1.0]:
		var leg := Node3D.new()
		leg.name = "Leg"+str(legs.size())
		leg.position = Vector3(side*0.12,0.93,0)
		rig.add_child(leg)
		G.tube(leg,Vector3.ZERO,Vector3(0,-0.42,0),0.09,pants)
		var knee := Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(0,-0.42,0)
		leg.add_child(knee)
		G.tube(knee,Vector3.ZERO,Vector3(0,-0.38,0),0.066,pants)
		G.sphere(knee,Vector3(0,-0.42,0.06),Vector3(0.15,0.13,0.28),hair)
		G.merge(knee)
		knees.append(knee)
		G.merge(leg)
		legs.append(leg)
		var arm := Node3D.new()
		arm.name = "Arm"+str(arms.size())
		arm.position = Vector3(side*0.25,1.37,0)
		rig.add_child(arm)
		G.tube(arm,Vector3.ZERO,Vector3(side*0.025,-0.29,0),0.065,shirt)
		G.tube(arm,Vector3(side*0.025,-0.29,0),Vector3(side*0.04,-0.53,0.02),0.05,skin)
		G.sphere(arm,Vector3(side*0.04,-0.56,0.02),Vector3(0.1,0.13,0.09),skin)
		G.merge(arm)
		arms.append(arm)

	return rig

func _process(delta: float) -> void:
	if not walking:
		return
	phase += delta*6
	for i in range(2):
		legs[i].rotation.x = sin(phase+i*PI)*0.4
		arms[i].rotation.x = -sin(phase+i*PI)*0.3

func set_seated(value: bool) -> void:
	seated = value
	_show_static()
	_pose(value)

func _pose(value: bool) -> void:
	for i in range(legs.size()):
		legs[i].rotation.x = -PI/2 if value else 0.0
		knees[i].rotation.x = PI/2 if value else 0.0
		knees[i].scale.y = 0.85 if value else 1.0
	for arm in arms: arm.rotation.x = -0.35 if value else 0.0
