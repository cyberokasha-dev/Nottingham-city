extends CharacterBody3D

const WALK_SPEED := 2.4
const RUN_SPEED := 5.5
const INTERACT_DISTANCE := 4.0
const EXIT_SPEED := 1.0

var vehicle: VehicleBody3D
var home_position := Vector3.ZERO
var use_home_position := false
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
var active_house: Node3D
var entering_house := false
var resting := ""
var health := 100
var guarding := false
var action_time := 0.0
var strike_pending := false
var strike_delay := 0.0
var strike_damage := 18
var recovery_time := 0.0
var rest_stand := Vector3.ZERO
var rest_tween: Tween

func _ready() -> void:
	for action in {"walk_forward": KEY_W, "walk_back": KEY_S, "walk_left": KEY_A, "walk_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key := InputEventKey.new()
			key.physical_keycode = {"walk_forward": KEY_W, "walk_back": KEY_S, "walk_left": KEY_A, "walk_right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "interact": KEY_E}[action]
			InputMap.action_add_event(action, key)
	preload("res://actors/controls.gd").bind()
	add_to_group("people")
	collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	visual = preload("res://actors/human.gd").new()
	add_child(visual)
	visual.setup(0)
	animator = visual.animator
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
	var controls := preload("res://actors/controls.gd").new()
	controls.player = self
	add_child(controls)
	if use_home_position:
		global_position = home_position
	elif is_instance_valid(vehicle):
		vehicle.set_driver_active(false)
		global_position = vehicle.global_position + Vector3(3, 1, 0)
		home_position = global_position

func _play_clip(clip: String, blend := 0.16) -> void:
	if current_clip != clip or not animator.is_playing():
		current_clip = clip
		animator.speed_scale = 1.0
		animator.play(clip, blend)

func _unhandled_input(event: InputEvent) -> void:
	if not driving and not transitioning and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.15, -0.75) if is_instance_valid(active_house) else clampf(pitch - event.relative.y * 0.005, -1.0, 0.3)

func _physics_process(delta: float) -> void:
	message_time = maxf(0.0, message_time - delta)
	if not driving and not transitioning:
		var devices := Input.get_connected_joypads()
		if not devices.is_empty():
			var look := Vector2(Input.get_joy_axis(devices[0],JOY_AXIS_RIGHT_X),Input.get_joy_axis(devices[0],JOY_AXIS_RIGHT_Y))
			if look.length() > 0.18:
				yaw -= look.x * delta * 2.2
				pitch = clampf(pitch-look.y*delta*1.5,-1.15,-0.75) if is_instance_valid(active_house) else clampf(pitch-look.y*delta*1.5,-1.0,0.3)
	action_time = maxf(0,action_time-delta)
	var recovering := recovery_time > 0
	recovery_time = maxf(0,recovery_time-delta)
	if recovering and recovery_time <= 0:
		health = 100
		_play_clip("idle")
		_notify("Recovered — take a rest or block the next punch.")
	if strike_pending:
		strike_delay -= delta
		if strike_delay <= 0:
			strike_pending = false
			preload("res://actors/combat.gd").strike(self,-visual.global_basis.z,strike_damage)
	if resting != "":
		pivot.rotation = Vector3(pitch,yaw,0)
		prompt.text = ("Sleeping — ○ G / △ E: wake up" if resting == "sleep" else "Sitting — ○ G / △ E: stand up")
		if resting == "sleep":
			health = mini(100,health+1)
			visual.position.y = sin(Time.get_ticks_msec()*0.0018)*0.008
		if Input.is_action_just_pressed("cancel_action") or Input.is_action_just_pressed("interact"):
			stand_up()
		return
	if recovery_time > 0:
		prompt.text = "Recovering…"
		return
	if transitioning:
		prompt.text = "Opening the house…" if entering_house else ("Getting into the vehicle…" if not driving else "Getting out…")
		return
	if Input.is_action_just_pressed("interact"):
		if driving:
			try_exit()
		else:
			var furniture := nearest_furniture()
			var person := nearest_person()
			var house := nearest_house()
			if furniture != "":
				try_rest(furniture)
			elif is_instance_valid(person):
				person.talk_to(self)
			elif is_instance_valid(house):
				try_house(house)
			else:
				try_enter()
	if transitioning:
		return
	if driving:
		global_position = vehicle.global_position
		prompt.text = vehicle.display_name + " — △ E: get out (stop first)\nWASD / left stick: drive · R2: accelerate · L2: reverse · ✕ Space: brake · C / R3: camera"
	else:
		pivot.rotation.x = lerpf(pivot.rotation.x, pitch, 1.0 - exp(-12.0 * delta))
		pivot.rotation.y = lerp_angle(pivot.rotation.y, yaw, 1.0 - exp(-12.0 * delta))
		guarding = Input.is_action_pressed("guard") and action_time <= 0
		if Input.is_action_just_pressed("punch"):
			try_punch(false)
		elif Input.is_action_just_pressed("heavy_punch"):
			try_punch(true)
		var input := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
		var direction := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)
		var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
		if action_time > 0 or guarding:
			speed = 0.5
			visual.rotation.y = yaw
		if Input.is_action_pressed("look_modifier"):
			speed *= 0.5
		velocity.x = move_toward(velocity.x, direction.x * speed, 16.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 16.0 * delta)
		var jumped := false
		if not is_on_floor():
			velocity.y -= 20.0 * delta
		elif Input.is_action_just_pressed("jump") and action_time <= 0 and not guarding:
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
		if action_time > 0:
			pass
		elif guarding:
			_play_clip("heavy_punch",0.08)
			animator.seek(0.14,true)
			animator.pause()
		elif jumped:
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
		prompt.text = "ON FOOT — WASD: walk · Shift: run · Space: jump\nHold right mouse and drag: look"
		var house := nearest_house()
		vehicle = nearest_vehicle() if not is_instance_valid(active_house) else null
		var furniture := nearest_furniture()
		var person := nearest_person()
		if furniture != "":
			prompt.text += "\n△ E: " + ("sleep in bed" if furniture == "sleep" else "sit on sofa")
		elif is_instance_valid(person):
			prompt.text += "\n△ E: talk to " + person.person_name
		elif is_instance_valid(house):
			prompt.text += "\n△ E: " + ("leave " if house==active_house else "enter ") + house.address
		elif is_instance_valid(vehicle):
			prompt.text += "\nE: enter " + vehicle.display_name
		else:
			prompt.text += "\n" + (active_house.address + " · walk to the front door to leave" if is_instance_valid(active_house) else "Walk to a vehicle or a house door · map: top right")
		if global_position.y < -20:
			global_position = home_position + Vector3.UP
			velocity = Vector3.ZERO
	if message_time > 0:
		prompt.text += "\n" + message

func try_enter() -> bool:
	if transitioning or driving or resting != "" or action_time > 0 or is_instance_valid(active_house):
		return false
	vehicle = nearest_vehicle()
	if not is_instance_valid(vehicle):
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

func nearest_vehicle() -> VehicleBody3D:
	var closest: VehicleBody3D = null
	var distance := INTERACT_DISTANCE
	for candidate in get_tree().get_nodes_in_group("driveable_vehicles"):
		var candidate_distance := global_position.distance_to(candidate.global_position)
		if candidate_distance < distance:
			var eye := global_position + Vector3.UP
			var target: Vector3 = candidate.global_position + Vector3.UP * 0.4
			var ray := PhysicsRayQueryParameters3D.create(eye, target)
			ray.exclude = [get_rid(), candidate.get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and not candidate.get_parent().is_ancestor_of(hit.collider):
				continue
			closest = candidate
			distance = candidate_distance
	return closest

func nearest_house() -> Node3D:
	if is_instance_valid(active_house):
		if global_position.distance_to(active_house.inside_point()) < 2.7:
			return active_house
		return null
	var closest: Node3D = null
	var distance := 2.7
	for house in get_tree().get_nodes_in_group("enterable_houses"):
		var d := global_position.distance_to(house.entrance())
		if d < distance:
			closest = house
			distance = d
	return closest

func try_house(house: Node3D) -> bool:
	if transitioning or driving or resting != "" or action_time > 0 or house != nearest_house():
		return false
	transitioning = true
	entering_house = true
	_house_transition(house,house!=active_house)
	return true

func _house_transition(house: Node3D,entering: bool) -> void:
	velocity = Vector3.ZERO
	collider.disabled = true
	await house.open_door(true)
	if entering:
		active_house = house
		house.set_inside(true)
		yaw = house.rotation.y
		pitch = -0.9
		pivot.get_child(0).collision_mask = 0
		pivot.get_child(0).spring_length = 6.0
	else:
		yaw = house.rotation.y + PI
	_play_clip("walk")
	# Align with the open doorway before crossing the wall line.
	var approach := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	approach.tween_property(self,"global_position",house.entrance() if entering else house.inside_point(),0.22)
	await approach.finished
	var travel := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	travel.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(self,"global_position",house.inside_point() if entering else house.entrance(),0.55)
	travel.tween_property(pivot,"rotation:x",pitch if entering else -0.25,0.55)
	travel.tween_property(pivot,"rotation:y",pivot.rotation.y+wrapf(yaw-pivot.rotation.y,-PI,PI),0.55)
	travel.tween_property(visual,"rotation:y",visual.rotation.y+wrapf(yaw-visual.rotation.y,-PI,PI),0.55)
	await travel.finished
	await house.open_door(false)
	if not entering:
		house.set_inside(false)
		active_house = null
		pitch = -0.25
		pivot.get_child(0).collision_mask = 1
		pivot.get_child(0).spring_length = 5.0
	collider.disabled = false
	velocity = Vector3.ZERO
	was_grounded = true
	landing_time = 0.0
	_play_clip("idle")
	transitioning = false
	entering_house = false

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
	get_parent().get_node("Spedometer").car_body = vehicle
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

func nearest_furniture() -> String:
	if not is_instance_valid(active_house):
		return ""
	for action in ["sit","sleep"]:
		if global_position.distance_to(active_house.rest_approach(action)) < 1.8:
			return action
	return ""

func try_rest(action: String) -> bool:
	if transitioning or driving or resting != "" or action_time > 0 or not is_instance_valid(active_house):
		return false
	if action != nearest_furniture() or not active_house.claim_rest(action,self):
		_notify("This place is occupied.")
		return false
	resting = action
	velocity = Vector3.ZERO
	collider.disabled = true
	rest_stand = active_house.rest_approach(action)
	_play_clip("enter",0.1)
	rest_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	rest_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rest_tween.tween_property(self,"global_position",active_house.rest_pose(action),0.5)
	var target_rotation := Vector3(PI/2,active_house.rotation.y+PI,0) if action == "sleep" else Vector3(0,active_house.rotation.y+PI,0)
	rest_tween.tween_property(visual,"rotation",target_rotation,0.5)
	rest_tween.finished.connect(func():
		_play_clip("idle" if action == "sleep" else "sit",0.0 if action == "sleep" else 0.16)
		if action == "sleep":
			animator.seek(0.1,true)
			animator.pause())
	return true

func stand_up() -> bool:
	if resting == "":
		return false
	if is_instance_valid(rest_tween):
		rest_tween.kill()
	active_house.release_rest(resting,self)
	global_position = rest_stand
	visual.rotation = Vector3(0,active_house.rotation.y,0)
	visual.position = Vector3.ZERO
	velocity = Vector3.ZERO
	collider.disabled = false
	resting = ""
	_play_clip("idle",0.2)
	return true

func nearest_person() -> CharacterBody3D:
	var nearest: CharacterBody3D = null
	var distance := 2.4
	for person in get_tree().get_nodes_in_group("residents"):
		var d := global_position.distance_to(person.global_position)
		if d < distance and person.current_house == active_house and person.resting == "":
			nearest = person
			distance = d
	return nearest

func try_punch(heavy := false) -> bool:
	if driving or transitioning or resting != "" or action_time > 0 or recovery_time > 0 or not is_on_floor():
		return false
	guarding = false
	visual.rotation.y = yaw
	_play_clip("heavy_punch" if heavy else "punch",0.05)
	action_time = 0.85 if heavy else 0.55
	strike_delay = 0.3 if heavy else 0.18
	strike_damage = 30 if heavy else 18
	strike_pending = true
	return true

func receive_hit(attacker: CharacterBody3D, damage: int) -> void:
	if driving or transitioning or resting != "" or recovery_time > 0:
		return
	var toward: Vector3 = (attacker.global_position-global_position).normalized()
	if guarding and (-visual.global_basis.z).dot(toward) > 0.35:
		_notify("Blocked")
		return
	health = maxi(0,health-damage)
	strike_pending = false
	_play_clip("hit",0.06)
	action_time = 0.5
	if health == 0:
		recovery_time = 3.0
		_notify("Recovering…")
