extends Node3D
## A compact world-space health bar for nearby residents.
var actor: CharacterBody3D
var viewer: Node3D
var fill: MeshInstance3D
var caption: Label3D
var fill_material: StandardMaterial3D
var shown_health := -1

func _ready() -> void:
	var background := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,0.1)
	background.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("182129")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	background.material_override = material
	add_child(background)
	fill = MeshInstance3D.new()
	var inner := QuadMesh.new()
	inner.size = Vector2(0.94,0.055)
	fill.mesh = inner
	fill.position.z = 0.005
	fill_material = material.duplicate()
	fill.material_override = fill_material
	add_child(fill)
	caption = Label3D.new()
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.font_size = 24
	caption.pixel_size = 0.004
	caption.outline_size = 7
	caption.position.y = -0.16
	add_child(caption)

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(viewer):
		return
	visible = global_position.distance_to(viewer.global_position) < (24 if actor.health < 100 else 12)
	position.y = 0.7 if actor.dead else 2.1
	var fraction := clampf(actor.health/100.0,0,1)
	if shown_health != actor.health:
		shown_health = actor.health
		fill.mesh.size = Vector2(maxf(0.001,0.94*fraction),0.055)
		fill.visible = fraction > 0
	fill_material.albedo_color = Color("ee6a66") if fraction < 0.3 else (Color("eac56d") if fraction < 0.6 else Color("6cdfa1"))
	caption.text = "Waking…" if actor.waking else ("DEAD · waking soon" if actor.dead else "%d / 100" % actor.health)
