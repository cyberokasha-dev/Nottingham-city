extends CharacterBody3D

const WALK_SPEED := 4.0
const RUN_SPEED := 7.0
const INTERACT_DISTANCE := 4.0
const EXIT_SPEED := 1.0

var vehicle: VehicleBody3D
var driving := false
var camera: Camera3D
var pivot: Node3D
var visual: Node3D
var collider: CollisionShape3D
var prompt: Label
var yaw := 0.0
var pitch := -0.25
var message := ""
var message_time := 0.0
var walk_time := 0.0
var legs: Array[Node3D] = []

func _ready() -> void:
	for action in {"walk_forward": KEY_W, "walk_back": KEY_S, "walk_left": KEY_A, "walk_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = {"walk_forward": KEY_W, "walk_back": KEY_S, "walk_left": KEY_A, "walk_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E}[action]
			InputMap.action_add_event(action, key)
	collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	_add_mesh(visual, Vector3(0, 1.15, 0), Vector3(0.6, 0.65, 0.35), Color(0.1, 0.35, 0.8))
	_add_mesh(visual, Vector3(0, 1.65, 0), Vector3(0.38, 0.38, 0.38), Color(0.55, 0.32, 0.18))
	for x in [-0.16, 0.16]:
		var leg := Node3D.new()
		leg.position = Vector3(x, 0.85, 0)
		visual.add_child(leg)
		_add_mesh(leg, Vector3(0, -0.4, 0), Vector3(0.22, 0.8, 0.25), Color(0.08, 0.1, 0.15))
		legs.append(leg)
	pivot = Node3D.new()
	pivot.position.y = 1.4
	add_child(pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = 5.0
	arm.margin = 0.2
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.near = 0.1
	arm.add_child(camera)
	camera.make_current()
	var hud := CanvasLayer.new()
	add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(20, 70)
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(prompt)
	vehicle.set_driver_active(false)
	global_position = vehicle.global_position + Vector3(3, 1, 0)

func _add_mesh(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)

func _unhandled_input(event: InputEvent) -> void:
	if not driving and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.0, 0.3)

func _physics_process(delta: float) -> void:
	message_time = maxf(0.0, message_time - delta)
	if Input.is_action_just_pressed("interact"):
		if driving:
			try_exit()
		else:
			try_enter()
	if driving:
		global_position = vehicle.global_position
		prompt.text = "DRIVING — E: get out (stop first)\nArrows/W/S: drive · Space: brake · C: camera · Esc: menu"
	else:
		pivot.rotation = Vector3(pitch, yaw, 0)
		var input := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
		var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = 6.0
		move_and_slide()
		if direction.length_squared() > 0.01:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 12.0 * delta)
			walk_time += delta * speed * 2.0
		for i in range(legs.size()):
			legs[i].rotation.x = sin(walk_time + i * PI) * 0.5 if direction.length_squared() > 0.01 else 0.0
		prompt.text = "ON FOOT — WASD: walk · Shift: run · Space: jump\nHold right mouse and drag: look · Esc: menu"
		if global_position.distance_to(vehicle.global_position) <= INTERACT_DISTANCE:
			prompt.text += "\nE: enter vehicle"
		if global_position.y < -20:
			global_position = vehicle.global_position + Vector3(3, 2, 0)
			velocity = Vector3.ZERO
	if message_time > 0:
		prompt.text += "\n" + message

func try_enter() -> bool:
	if global_position.distance_to(vehicle.global_position) > INTERACT_DISTANCE:
		return false
	if vehicle.linear_velocity.length() > EXIT_SPEED:
		_notify("Wait for the vehicle to stop.")
		return false
	driving = true
	velocity = Vector3.ZERO
	collider.disabled = true
	visual.hide()
	vehicle.set_driver_active(true)
	vehicle.get_node("CameraBase/Camera3D").make_current()
	get_parent().get_node("Spedometer").show()
	return true

func try_exit() -> bool:
	if vehicle.linear_velocity.length() > EXIT_SPEED:
		_notify("Stop the vehicle before getting out.")
		return false
	# Check both sides; require ground and enough room for the whole character.
	for side in [1.0, -1.0]:
		var candidate: Vector3 = vehicle.global_position + vehicle.global_basis.x.normalized() * side * 2.5
		var ray := PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 3, candidate + Vector3.DOWN * 5)
		ray.exclude = [vehicle.get_rid(), get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < 0.65:
			continue
		var feet: Vector3 = hit.position + Vector3.UP * 0.1
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 0.9)
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			continue
		driving = false
		vehicle.park()
		global_position = feet
		velocity = Vector3.ZERO
		collider.disabled = false
		visual.show()
		camera.make_current()
		get_parent().get_node("Spedometer").hide()
		return true
	_notify("No safe space beside the vehicle. Move to an open road.")
	return false

func _notify(text: String) -> void:
	message = text
	message_time = 3.0
