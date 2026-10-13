extends CharacterBody3D

const WALK_SPEED := 2.4
const RUN_SPEED := 5.5
const INTERACT_DISTANCE := 4.0
const EXIT_SPEED := 1.0

var vehicle: VehicleBody3D
var driving := false
var transitioning := false
var camera: Camera3D
var pivot: Node3D
var visual: Node3D
var collider: CollisionShape3D
var prompt: Label
var yaw := 0.0
var pitch := -0.25
var message := ""
var message_time := 0.0
var animator: AnimationPlayer
var current_clip := ""
var was_grounded := false
var landing_time := 0.0
var camera_blend: Camera3D

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
	var model := preload("res://player/models/human.glb").instantiate()
	# glTF character faces +Z; movement and the chase camera use -Z.
	model.rotation.y = PI
	visual.add_child(model)
	animator = model.get_node("AnimationPlayer")
	for clip in ["idle", "walk", "run", "jump_air", "seated"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play_clip("idle")
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
	camera.fov = 60.0
	arm.add_child(camera)
	camera.make_current()
	camera_blend = Camera3D.new()
	camera_blend.set_as_top_level(true)
	camera_blend.near = 0.1
	add_child(camera_blend)
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

func _play_clip(clip: String, blend := 0.16) -> void:
	if current_clip != clip:
		current_clip = clip
		animator.speed_scale = 1.0
		animator.play(clip, blend)

func _unhandled_input(event: InputEvent) -> void:
	if not driving and not transitioning and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.0, 0.3)

func _physics_process(delta: float) -> void:
	message_time = maxf(0.0, message_time - delta)
	if transitioning:
		prompt.text = "Getting into the vehicle…" if not driving else "Getting out…"
		return
	if Input.is_action_just_pressed("interact"):
		if driving:
			try_exit()
		else:
			try_enter()
	if transitioning:
		return
	if driving:
		global_position = vehicle.global_position
		prompt.text = "DRIVING — E: get out (stop first)\nArrows/W/S: drive · Space: brake · C: camera · Esc: menu"
	else:
		pivot.rotation.x = lerpf(pivot.rotation.x, pitch, 1.0 - exp(-12.0 * delta))
		pivot.rotation.y = lerp_angle(pivot.rotation.y, yaw, 1.0 - exp(-12.0 * delta))
		var input := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
		var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		velocity.x = move_toward(velocity.x, direction.x * speed, 16.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 16.0 * delta)
		var jumped := false
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = 6.0
			jumped = true
		move_and_slide()
		landing_time = maxf(landing_time - delta, 0.0)
		if is_on_floor() and not was_grounded:
			landing_time = 0.2
		was_grounded = is_on_floor()
		if direction.length_squared() > 0.01:
			visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 12.0 * delta)
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		if jumped:
			_play_clip("jump_start", 0.08)
		elif not is_on_floor():
			if current_clip != "jump_start" or animator.current_animation_position > 0.18:
				_play_clip("jump_air", 0.12)
		elif landing_time > 0.0:
			_play_clip("land", 0.08)
		elif horizontal_speed > 0.15:
			var running := horizontal_speed > WALK_SPEED + 0.3
			_play_clip("run" if running else "walk")
			animator.speed_scale = clampf(horizontal_speed / (RUN_SPEED if running else WALK_SPEED), 0.65, 1.2)
		else:
			_play_clip("idle")
		prompt.text = "ON FOOT — WASD: walk · Shift: run · Space: jump\nHold right mouse and drag: look · Esc: menu"
		if global_position.distance_to(vehicle.global_position) <= INTERACT_DISTANCE:
			prompt.text += "\nE: enter vehicle"
		if global_position.y < -20:
			global_position = vehicle.global_position + Vector3(3, 2, 0)
			velocity = Vector3.ZERO
	if message_time > 0:
		prompt.text += "\n" + message

func try_enter() -> bool:
	if transitioning or driving:
		return false
	if global_position.distance_to(vehicle.global_position) > INTERACT_DISTANCE:
		return false
	if vehicle.linear_velocity.length() > EXIT_SPEED:
		_notify("Wait for the vehicle to stop.")
		return false
	var side := _clear_side_position()
	if side.is_empty():
		_notify("Move to an open side of the vehicle.")
		return false
	transitioning = true
	_begin_enter(side.position)
	return true

func _clear_side_position() -> Dictionary:
	# Check both sides; require ground and enough room for the whole character.
	var nearest := signf((global_position - vehicle.global_position).dot(vehicle.global_basis.x))
	if is_zero_approx(nearest):
		nearest = 1.0
	for side in [nearest, -nearest]:
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
		return {"position": feet}
	return {}

func _begin_enter(door_position: Vector3) -> void:
	velocity = Vector3.ZERO
	vehicle.park()
	collider.disabled = true
	_play_clip("walk", 0.12)
	var toward := vehicle.global_position - door_position
	var facing := atan2(-toward.x, -toward.z)
	var approach := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	approach.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	approach.tween_property(self, "global_position", door_position, 0.35)
	approach.tween_property(visual, "rotation:y", visual.rotation.y + wrapf(facing - visual.rotation.y, -PI, PI), 0.35)
	await approach.finished
	_play_clip("enter", 0.12)
	var target: Vector3 = door_position.lerp(vehicle.global_position, 0.42)
	target.y = door_position.y
	var sit := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sit.tween_property(self, "global_position", target, 0.55)
	await sit.finished
	visual.hide()
	_play_clip("seated")
	await _blend_camera(vehicle.get_node("CameraBase/Camera3D"))
	driving = true
	vehicle.set_driver_active(true)
	get_parent().get_node("Spedometer").show()
	transitioning = false

func try_exit() -> bool:
	if transitioning or not driving:
		return false
	if vehicle.linear_velocity.length() > EXIT_SPEED:
		_notify("Stop the vehicle before getting out.")
		return false
	var side := _clear_side_position()
	if side.is_empty():
		_notify("No safe space beside the vehicle. Move to an open road.")
		return false
	transitioning = true
	_begin_exit(side.position)
	return true

func _begin_exit(feet: Vector3) -> void:
	vehicle.park()
	global_position = feet
	velocity = Vector3.ZERO
	visual.show()
	var outward := feet - vehicle.global_position
	visual.rotation.y = atan2(-outward.x, -outward.z)
	_play_clip("exit", 0.08)
	await _blend_camera(camera)
	await get_tree().create_timer(0.35, false, true).timeout
	collider.disabled = false
	driving = false
	was_grounded = true
	landing_time = 0.0
	_play_clip("idle")
	get_parent().get_node("Spedometer").hide()
	transitioning = false

func _blend_camera(target: Camera3D) -> void:
	var previous := get_viewport().get_camera_3d()
	camera_blend.global_transform = previous.global_transform
	camera_blend.fov = previous.fov
	camera_blend.make_current()
	var blend := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	blend.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	blend.tween_property(camera_blend, "global_transform", target.global_transform, 0.3)
	blend.tween_property(camera_blend, "fov", target.fov, 0.3)
	await blend.finished
	target.make_current()

func _notify(text: String) -> void:
	message = text
	message_time = 3.0
