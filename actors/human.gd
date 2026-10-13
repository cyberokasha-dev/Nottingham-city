extends Node3D
## Shared rig, wardrobe and animation layer for the player and residents.
var animator: AnimationPlayer
var clip := ""
var model: Node3D
var wardrobe: ShaderMaterial
var flash_time := 0.0

func setup(variant := 0, female := false, identity := "human") -> void:
	model = load("res://player/models/muhammad.glb" if identity == "muhammad" else ("res://player/models/human_female.glb" if female else "res://player/models/human.glb")).instantiate()
	model.rotation.y = PI
	add_child(model)
	animator = model.get_node("AnimationPlayer")
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
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = material
	var height := 0.97 + (variant % 4) * 0.025
	model.scale = Vector3(0.97 + (variant % 3) * 0.035,height,1.0)
	if animator.has_animation("fold_arms"):
		animator.get_animation("fold_arms").loop_mode = Animation.LOOP_LINEAR
	play("idle")

func play(animation: String, blend := 0.16) -> void:
	if clip != animation or not animator.is_playing():
		clip = animation
		animator.speed_scale = 1.0
		animator.play(animation,blend)

func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*10))

func impact() -> void:
	flash_time = 0.22

func _process(delta: float) -> void:
	flash_time = maxf(0,flash_time-delta)
	if is_instance_valid(wardrobe):
		wardrobe.set_shader_parameter("impact",flash_time/0.22)
