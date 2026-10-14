extends Node3D
## Shared rig, wardrobe and animation layer for the player and residents.
var animator: AnimationPlayer
var clip := ""
var model: Node3D
var wardrobe: ShaderMaterial
var flash_time := 0.0
var lod_clock := 0.0
var skeleton: Skeleton3D
var base_scale := Vector3.ONE
var mounted := false
var ride_anchor := Vector3.ZERO
var seat_fit := -1
var activity := ""
var held_prop: Node3D

func setup(variant := 0, female := false, identity := "human") -> void:
	model = load("res://player/models/muhammad.glb" if identity == "muhammad" else ("res://player/models/human_female.glb" if female else "res://player/models/human.glb")).instantiate()
	model.rotation.y = PI
	add_child(model)
	animator = model.get_node("AnimationPlayer")
	skeleton = model.find_child("Skeleton3D",true,false)
	for animation in ["idle", "walk", "run", "jump_air", "seated", "sit", "talk"]:
		animator.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	var skins := [Color("9b603e"),Color("ce9975"),Color("633b29"),Color("e8b994")]
	var shirts := [Color("2867b0"),Color("a54e5b"),Color("4a8270"),Color("c6a050"),Color("e3ddd0"),Color("655291")]
	var material := ShaderMaterial.new()
	wardrobe = material
	material.shader = preload("res://actors/muhammad.gdshader") if identity == "muhammad" else preload("res://actors/wardrobe.gdshader")
	if identity == "muhammad":
		material.set_shader_parameter("face_albedo",preload("res://actors/textures/muhammad-face.png"))
	material.set_shader_parameter("skin_tone",skins[variant % skins.size()])
	material.set_shader_parameter("shirt_tone",shirts[variant % shirts.size()])
	material.set_shader_parameter("hair_tone",Color("322019") if variant % 3 == 0 else Color("17151b"))
	material.set_shader_parameter("trouser_tone",[Color("25364a"),Color("756453"),Color("3d4143"),Color("333a2e"),Color("46354c")][variant%5])
	material.set_shader_parameter("shoe_tone",[Color("222b35"),Color("e3dfd4"),Color("6a4431")][variant%3])
	material.set_shader_parameter("sleeve_style",float(variant%2))
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = material
	var height := 0.91 + (variant % 6) * 0.027
	model.scale = Vector3(0.88 + (variant % 5) * 0.045,height,0.93+(variant%3)*0.035)
	if identity=="muhammad": model.scale=Vector3(0.97,0.99,1.0)
	base_scale = model.scale
	if identity!="muhammad": _features(variant,female)
	if animator.has_animation("fold_arms"):
		animator.get_animation("fold_arms").loop_mode = Animation.LOOP_LINEAR
	lod_clock = float(variant%9)*0.027
	wardrobe.set_shader_parameter("impact",0.0)
	play("idle")

func play(animation: String, blend := 0.16) -> void:
	if is_instance_valid(held_prop): held_prop.visible=false
	if animation=="seated":
		if clip!="seated":
			clip="seated"
			activity=""
			# One settled pose: a driving loop must not move passengers through the floor.
			animator.play("sit",0)
			animator.seek(0.2,true)
			animator.pause()
		return
	if clip != animation or not animator.is_playing():
		clip = animation
		activity=""
		seat_fit=-1
		animator.speed_scale = 1.0
		animator.play(animation,blend)

func mount(cabin: Node3D, anchor: Vector3, facing := PI, compact := false) -> void:
	if get_parent()!=cabin: reparent(cabin,false)
	mounted=true
	ride_anchor=anchor
	position=anchor
	rotation=Vector3(0,facing,0)
	model.scale=base_scale*(0.9 if compact else 1.0)
	play("seated",0)
	fit_rider(compact)

func fit_rider(compact: bool) -> void:
	var fit := int(compact)
	if seat_fit==fit: return
	seat_fit=fit
	var height := 0.14 if compact else 0.25
	var reach := 0.60 if compact else 0.65
	_aim("calf_l","foot_l",Vector3(0.18,height,reach))
	_aim("calf_r","foot_r",Vector3(-0.18,height,reach))

func dismount(actor: Node3D) -> void:
	if get_parent()!=actor: reparent(actor,false)
	mounted=false
	position=Vector3.ZERO
	rotation=Vector3.ZERO
	model.scale=base_scale
	clip=""
	play("idle",0)

func _features(variant: int, female: bool) -> void:
	const G = preload("res://transport/geometry.gd")
	var attachment := BoneAttachment3D.new()
	attachment.bone_name="Head"
	skeleton.add_child(attachment)
	var details := Node3D.new()
	attachment.add_child(details)
	var rest := model.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_rest(skeleton.find_bone("Head"))
	details.basis=rest.basis.inverse()
	var hair := G.material([Color("241b16"),Color("39291d"),Color("75645a"),Color("b29869")][variant%4])
	if variant%4==0:
		var frame := G.material(Color("34343c"),0.3)
		for side in [-1,1]:
			for y in [0.075,0.115]: G.tube(details,Vector3(side*0.01,y,0.091),Vector3(side*0.067,y,0.091),0.005,frame)
			for x in [side*0.01,side*0.067]: G.tube(details,Vector3(x,0.075,0.091),Vector3(x,0.115,0.091),0.005,frame)
		G.tube(details,Vector3(-0.01,0.095,0.093),Vector3(0.01,0.095,0.093),0.004,frame)
	if not female and variant%3==0:
		G.sphere(details,Vector3(0,0.01,0.065),Vector3(0.115,0.073,0.06),hair)
	if female and variant%3==1:
		G.sphere(details,Vector3(0,0.14,-0.085),Vector3(0.12,0.13,0.12),hair)
	if variant%5==2:
		G.sphere(details,Vector3(0,0.19,0),Vector3(0.195,0.09,0.18),hair)
	G.merge(details)

func start_activity(kind: String) -> void:
	play("idle",0)
	animator.seek(0.2,true)
	animator.pause()
	activity=kind
	if kind=="stretch":
		_aim("upperarm_l","lowerarm_l",Vector3(0.26,1.9,0))
		_aim("upperarm_r","lowerarm_r",Vector3(-0.26,1.9,0))
	elif kind=="phone":
		_aim("upperarm_r","lowerarm_r",Vector3(-0.22,1.13,0.16))
		_aim("lowerarm_r","hand_r",Vector3(-0.05,1.43,0.28))
	elif kind=="work":
		_aim("upperarm_r","lowerarm_r",Vector3(-0.25,1.12,0.2))
		_aim("lowerarm_r","hand_r",Vector3(-0.1,0.95,0.42))
	elif kind=="look":
		var head := skeleton.find_bone("Head")
		skeleton.set_bone_pose_rotation(head,skeleton.get_bone_pose_rotation(head)*Quaternion(Vector3.UP,0.4))

	if kind in ["phone","work"]:
		if not is_instance_valid(held_prop):
			const G = preload("res://transport/geometry.gd")
			var attachment := BoneAttachment3D.new()
			attachment.bone_name="hand_r"
			skeleton.add_child(attachment)
			held_prop=Node3D.new()
			attachment.add_child(held_prop)
			G.box(held_prop,Vector3(0,0.045,0),Vector3(0.075,0.14,0.015),G.material(Color("202a32")))
			G.box(held_prop,Vector3(0,0.045,0.009),Vector3(0.06,0.11,0.003),G.material(Color("88b3bf")))
			G.merge(held_prop)
		held_prop.visible=true

func _aim(bone_name: String, next_name: String, target: Vector3) -> void:
	var bone := skeleton.find_bone(bone_name)
	var next := skeleton.find_bone(next_name)
	var current := skeleton.global_transform*skeleton.get_bone_global_pose(bone)
	var end := skeleton.global_transform*skeleton.get_bone_global_pose(next).origin
	var from := (end-current.origin).normalized()
	var to := (model.to_global(target)-current.origin).normalized()
	var desired := Basis(Quaternion(from,to))*current.basis
	var parent := skeleton.get_bone_parent(bone)
	var base := skeleton.global_transform.basis*skeleton.get_bone_global_pose(parent).basis*skeleton.get_bone_rest(bone).basis
	skeleton.set_bone_pose_rotation(bone,(base.inverse()*desired).orthonormalized().get_rotation_quaternion())

func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*10))

func impact() -> void:
	flash_time = 0.22

func _process(delta: float) -> void:
	lod_clock += delta
	if lod_clock>0.25:
		lod_clock = 0
		var camera := get_viewport().get_camera_3d()
		if is_instance_valid(camera) and is_instance_valid(model):
			var near := global_position.distance_squared_to(camera.global_position)<5625
			model.visible = near
			animator.active = near and (global_position.distance_squared_to(camera.global_position)<100 or camera.is_position_in_frustum(global_position+Vector3.UP))
	if flash_time>0:
		flash_time = maxf(0,flash_time-delta)
		if is_instance_valid(wardrobe): wardrobe.set_shader_parameter("impact",flash_time/0.22)
