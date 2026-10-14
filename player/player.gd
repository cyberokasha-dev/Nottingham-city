extends CharacterBody3D

const WALK_SPEED := 2.4
const RUN_SPEED := 5.5
const INTERACT_DISTANCE := 4.0
const EXIT_SPEED := 1.0

var vehicle: VehicleBody3D
var home_position := Vector3.ZERO
var use_home_position := false
var riding_service: Node3D
var riding_bus: Node3D
var park_activity: Node3D
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
var dead := false
var waking := false
var invulnerability := 0.0
var hit_push := Vector3.ZERO
var hurt_time := 0.0
var sleep_healing := 0.0
var dialogue: Node3D
var profile := {"name":"Muhammad", "variant":0, "female":false, "model":"muhammad"}
var controlled := true
var party: Node
var hud: CanvasLayer
var controls: CanvasLayer
var folded_arms := false
var camera_mode := 0
var camera_manual := 0.0
var follow_yaw := 0.0
var foot_arm: SpringArm3D

func _ready() -> void:
	collision_mask = 3
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
	visual.setup(profile.variant,profile.female,profile.model)
	dialogue = preload("res://actors/speech.gd").new()
	dialogue.actor = self
	dialogue.voice_set = profile.get("voice","cori" if profile.female else "northern_english_male")
	dialogue.ambient_enabled = false
	add_child(dialogue)
	add_child(preload("res://simulation/service_audio.gd").new())
	animator = visual.animator
	_play_clip("idle")
	pivot = Node3D.new()
	pivot.position.y = 1.4
	add_child(pivot)
	var arm := SpringArm3D.new()
	foot_arm = arm
	arm.spring_length = 5.0
	arm.margin = 0.2
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.near = 0.1
	camera.fov = 60.0
	arm.add_child(camera)
	if controlled:
		camera.make_current()
	camera_blend = Camera3D.new()
	camera_blend.set_as_top_level(true)
	camera_blend.near = 0.1
	add_child(camera_blend)
	hud = CanvasLayer.new()
	add_child(hud)
	prompt = Label.new()
	prompt.position = Vector2(20, 70)
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(prompt)
	controls = preload("res://actors/controls.gd").new()
	controls.player = self
	add_child(controls)
	hud.visible = controlled
	controls.visible = controlled
	if use_home_position:
		global_position = home_position
	elif is_instance_valid(vehicle):
		vehicle.set_driver_active(false)
		global_position = vehicle.global_position + Vector3(3, 1, 0)
		home_position = global_position

func _play_clip(clip: String, blend := 0.16) -> void:
	current_clip=clip
	visual.play(clip,blend)

func _unhandled_input(event: InputEvent) -> void:
	if not controlled or (is_instance_valid(party) and party.wheel.visible):
		return
	if not driving and not transitioning and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_manual = 1.6
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -1.15, -0.75) if is_instance_valid(active_house) else clampf(pitch - event.relative.y * 0.005, -1.0, 0.3)

func receive_vehicle_hit(direction: Vector3, speed: float) -> void:
	preload("res://simulation/road_impact.gd").hit(self,direction,speed)

func _physics_process(delta: float) -> void:
	if preload("res://simulation/road_impact.gd").tick(self,delta): return
	message_time = maxf(0.0, message_time - delta)
	camera_manual = maxf(0,camera_manual-delta)
	if controlled and Input.is_action_just_pressed("cycle_camera") and not driving and not _phone_open():
		cycle_view()
	if controlled and not transitioning and not driving:
		_update_follow(delta)
	if controlled and not driving and not transitioning and not (is_instance_valid(party) and party.wheel.visible):
		var devices := Input.get_connected_joypads()
		if not devices.is_empty():
			var look := Vector2(Input.get_joy_axis(devices[0],JOY_AXIS_RIGHT_X),Input.get_joy_axis(devices[0],JOY_AXIS_RIGHT_Y))
			if look.length() > 0.18:
				camera_manual = 1.6
				yaw -= look.x * delta * 2.2
				pitch = clampf(pitch-look.y*delta*1.5,-1.15,-0.75) if is_instance_valid(active_house) else clampf(pitch-look.y*delta*1.5,-1.0,0.3)
	if is_instance_valid(riding_service):
		global_position = riding_service.rider_position(self)
		pivot.rotation = Vector3(pitch,yaw,0)
		prompt.text = "AURORA • P: choose destination / talk · B: camera\nJ: skip a confirmed journey"
		if controlled and not _phone_open() and Input.is_physical_key_pressed(KEY_J):
			riding_service.skip_journey(self)
		return
	if is_instance_valid(riding_bus):
		global_position = riding_bus.rider_position()
		pivot.rotation = Vector3(pitch,yaw,0)
		prompt.text = "BUS %s • %s\n%s" % [riding_bus.route.number,riding_bus.route.name,"E: get off" if riding_bus.state=="dwell" else ("Stop requested" if riding_bus.bell else "E: request next stop")]
		if controlled and Input.is_action_just_pressed("interact"):
			riding_bus.leave(self)
		return
	if is_instance_valid(park_activity):
		park_activity.tick_user(self,delta)
		return
	action_time = maxf(0,action_time-delta)
	invulnerability = maxf(0,invulnerability-delta)
	if dead:
		recovery_time = maxf(0,recovery_time-delta)
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 20*delta
		move_and_slide()
		if recovery_time <= 1.5 and not waking:
			waking = true
			animator.play_backwards("death",0.1)
			animator.speed_scale = animator.get_animation("death").length/1.5
		if recovery_time <= 0:
			revive()
		prompt.text = "Waking up…" if waking else "DEAD — waking in %d seconds" % ceili(recovery_time)
		return
	if hurt_time > 0:
		hurt_time = maxf(0,hurt_time-delta)
		velocity.x = hit_push.x*hurt_time/0.28
		velocity.z = hit_push.z*hurt_time/0.28
		if not is_on_floor():
			velocity.y -= 20*delta
		move_and_slide()
		prompt.text = "Hit! Health %d / 100" % health
		return
	if not controlled:
		if resting == "":
			velocity.x = 0
			velocity.z = 0
			if not is_on_floor():
				velocity.y -= 20*delta
			move_and_slide()
			_play_clip("idle")
		return
	if is_instance_valid(party) and party.wheel.visible:
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 20*delta
		move_and_slide()
		return
	if is_instance_valid(party) and party.game.conversation.active:
		velocity = Vector3.ZERO
		return
	if animator.has_animation("fold_arms") and Input.is_action_just_pressed("fold_arms") and not driving and not transitioning and resting == "" and action_time <= 0:
		folded_arms = not folded_arms
		if folded_arms:
			dialogue.event("fold")
		_notify("Arms folded — H to relax" if folded_arms else "Arms relaxed")
	if is_instance_valid(party.game.phone) and (party.game.phone.panel.visible or party.game.city_map.expanded):
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor():
			velocity.y -= 20*delta
		move_and_slide()
		return
	if strike_pending:
		strike_delay -= delta
		if strike_delay <= 0:
			strike_pending = false
			preload("res://actors/combat.gd").strike(self,-visual.global_basis.z,strike_damage)
	if resting != "":
		pivot.rotation = Vector3(pitch,yaw,0)
		prompt.text = ("Sleeping — ○ G / △ E: wake up" if resting == "sleep" else "Sitting — ○ G / △ E: stand up")
		if resting == "sleep":
			sleep_healing += delta*8
			if sleep_healing >= 1:
				health = mini(100,health+int(sleep_healing))
				sleep_healing -= int(sleep_healing)
			visual.position.y = sin(Time.get_ticks_msec()*0.0018)*0.008
		if Input.is_action_just_pressed("cancel_action") or Input.is_action_just_pressed("interact"):
			stand_up()
		return
	if transitioning:
		prompt.text = "Opening the house…" if entering_house else ("Getting into the vehicle…" if not driving else "Getting out…")
		return
	if Input.is_action_just_pressed("interact"):
		if driving:
			try_exit()
		else:
			if is_instance_valid(party.game.cabs) and party.game.cabs.is_pickup_near(self):
				party.game.phone.panel.show()
				party.game.phone.tabs.current_tab = 0
				party.game.phone.update_display()
				party.game.phone.pin.grab_focus()
				return
			var parked_cab: int = party.game.cabs.nearest_available(self)
			if parked_cab>=0:
				var booking: Dictionary = party.game.cabs.walk_up(self,parked_cab)
				party.game.phone.panel.show()
				party.game.phone.tabs.current_tab = 0
				party.game.phone.show_message("Cab reserved. Stand in its green circle and enter your code." if not booking.is_empty() else party.game.economy.last_error)
				return
			var furniture := nearest_furniture()
			var person := nearest_person()
			var house := nearest_house()
			var city_target := nearest_city_activity()
			if is_instance_valid(city_target):
				if city_target.is_in_group("city_buses"):
					city_target.board(self)
				else:
					city_target.use(self)
			elif furniture != "":
				try_rest(furniture)
			elif is_instance_valid(person):
				party.game.conversation.start(person)
			elif is_instance_valid(house):
				try_house(house)
			else:
				if not try_enter():
					party.game.city.traffic.claim_car(self)
	if transitioning or is_instance_valid(riding_bus) or is_instance_valid(park_activity):
		return
	if driving:
		global_position = vehicle.global_position
		prompt.text = vehicle.display_name + " — E: get out (stop first)\nWASD: drive · Space: brake · B: camera"
	else:
		pivot.rotation.x = lerpf(pivot.rotation.x, pitch, 1.0 - exp(-12.0 * delta))
		pivot.rotation.y = lerp_angle(pivot.rotation.y, yaw, 1.0 - exp(-12.0 * delta))
		guarding = Input.is_action_pressed("guard") and action_time <= 0
		if Input.is_action_just_pressed("punch"):
			try_punch(false)
		elif Input.is_action_just_pressed("heavy_punch"):
			try_punch(true)
		var input := Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back")
		if input.length()<0.01: follow_yaw = yaw
		if input.length() > 0.01:
			folded_arms = false
		var direction := Basis(Vector3.UP, follow_yaw if camera_manual<=0 else yaw) * Vector3(input.x, 0, input.y)
		if input.length()>0.1 and camera_manual>0: follow_yaw = yaw
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
			_play_clip("fold_arms" if folded_arms else "idle")
		prompt.text = "ON FOOT — WASD: walk · Shift: run · Space: jump\nHold right mouse and drag: look · B: camera"
		var house := nearest_house()
		vehicle = nearest_vehicle() if not is_instance_valid(active_house) else null
		var furniture := nearest_furniture()
		var person := nearest_person()
		var city_target := nearest_city_activity()
		if is_instance_valid(party.game.cabs) and party.game.cabs.is_pickup_near(self):
			prompt.text += "\nE: enter your Aurora boarding code"
		elif party.game.cabs.nearest_available(self)>=0:
			prompt.text += "\nE: reserve this parked Aurora · K: request a pickup"
		elif is_instance_valid(city_target):
			prompt.text += "\nE: " + ("board route "+city_target.route.number if city_target.is_in_group("city_buses") else city_target.nearest(self).title)
		elif furniture != "":
			prompt.text += "\n△ E: " + ("sleep in bed" if furniture == "sleep" else "sit on sofa")
		elif is_instance_valid(person):
			prompt.text += "\n△ E: talk to " + person.person_name
		elif is_instance_valid(house):
			prompt.text += "\n△ E: " + ("leave " if house==active_house else "enter ") + house.address
		elif not party.game.city.traffic.nearest_car(self).is_empty():
			prompt.text += "\nE: stop and enter street car"
		elif is_instance_valid(vehicle):
			prompt.text += "\nE: enter " + vehicle.display_name
		else:
			prompt.text += "\n" + (active_house.address + " · walk to the front door to leave" if is_instance_valid(active_house) else "Walk to a vehicle or a house door · map: top right")
		if global_position.y < -20:
			global_position = home_position + Vector3.UP
			velocity = Vector3.ZERO
	if is_instance_valid(party) and not driving:
		var stop_text: String = party.game.city.transport.stop_hint(self)
		if stop_text!="":
			prompt.text += "\n"+stop_text
	if is_instance_valid(party.game.economy):
		prompt.text += "\n"+party.game.economy.pounds(party.game.economy.cash(self))+" • P: Phone / Cab / Housing / Jobs"
	if message_time > 0:
		prompt.text += "\n" + message

func try_enter() -> bool:
	if dead or transitioning or driving or resting != "" or action_time > 0 or is_instance_valid(active_house):
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
	if house!=active_house and is_instance_valid(party.game.economy) and not party.game.economy.can_access(self,house):
		party.game.phone.visit_house(house)
		_notify("Council home "+str(house.house_number)+" • view rent and confirm at this door")
		return false
	if dead or transitioning or driving or resting != "" or action_time > 0 or house != nearest_house():
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
	dialogue.event("enter_house" if entering else "exit_house")

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
	visual.mount(vehicle,vehicle.get_meta("driver_seat",Vector3(0.35,-0.15,0)),PI,true)
	visual.model.scale=visual.base_scale*float(vehicle.get_meta("driver_scale",0.8))
	visual.show()
	_play_clip("seated")
	await _blend_camera(vehicle.get_node("CameraBase/Camera3D"))
	driving = true
	dialogue.event("enter_car")
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
	visual.dismount(self)
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
	dialogue.event("exit_car")
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
	if dead or transitioning or driving or resting != "" or action_time > 0 or not is_instance_valid(active_house):
		return false
	if action != nearest_furniture() or not active_house.claim_rest(action,self):
		_notify("This place is occupied.")
		return false
	resting = action
	dialogue.event("sleep" if action == "sleep" else "sit")
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
	dialogue.event("wake")
	_play_clip("idle",0.2)
	return true

func nearest_person() -> CharacterBody3D:
	var nearest: CharacterBody3D = null
	var distance := 2.4
	for person in get_tree().get_nodes_in_group("residents"):
		var d := global_position.distance_to(person.global_position)
		if d < distance and person.current_house == active_house and person.resting == "" and not person.dead:
			nearest = person
			distance = d
	return nearest

func try_punch(heavy := false) -> bool:
	if dead or driving or transitioning or resting != "" or action_time > 0 or recovery_time > 0 or not is_on_floor():
		return false
	guarding = false
	folded_arms = false
	visual.rotation.y = yaw
	_play_clip("heavy_punch" if heavy else "punch",0.05)
	get_node("ServiceAudio").effect("whoosh")
	action_time = 0.85 if heavy else 0.55
	strike_delay = 0.3 if heavy else 0.18
	strike_damage = 30 if heavy else 18
	strike_pending = true
	return true

func receive_hit(attacker: CharacterBody3D, damage: int) -> void:
	if is_instance_valid(riding_bus) or is_instance_valid(park_activity) or dead or driving or transitioning or resting != "" or invulnerability > 0:
		return
	var toward: Vector3 = (attacker.global_position-global_position).normalized()
	if guarding and (-visual.global_basis.z).dot(toward) > 0.35:
		get_node("ServiceAudio").effect("punch")
		return
	health = maxi(0,health-damage)
	visual.impact()
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device,0.25,0.65,0.18)
	hit_push = -toward * 2.8
	hurt_time = 0.28
	guarding = false
	get_node("ServiceAudio").effect("punch")
	strike_pending = false
	_play_clip("hit",0.06)
	action_time = 0.5
	if health == 0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	waking = false
	health = 0
	recovery_time = 6
	strike_pending = false
	hurt_time = 0
	guarding = false
	action_time = 0
	velocity = Vector3.ZERO
	visual.rotation.x = 0
	_play_clip("death",0.08)
	_notify("You died. You will wake up shortly.")

func revive() -> void:
	dead = false
	waking = false
	health = 100
	recovery_time = 0
	invulnerability = 2
	velocity = Vector3.ZERO
	visual.rotation.x = 0
	_play_clip("idle",0.2)
	if global_position.y < -20:
		global_position = home_position
	dialogue.event("wake")
	_notify("Awake — health restored.")

func nearest_city_activity() -> Node3D:
	if is_instance_valid(active_house) or not is_instance_valid(party):
		return null
	var bus: Node3D = party.game.city.transport.nearest_bus(self)
	if is_instance_valid(bus):
		return bus
	for park in get_tree().get_nodes_in_group("city_activities"):
		if not park.nearest(self).is_empty():
			return park
	return null

func _phone_open() -> bool:
	return is_instance_valid(party) and is_instance_valid(party.game.phone) and (party.game.phone.panel.visible or party.game.city_map.expanded)

func cycle_view() -> void:
	if driving and is_instance_valid(vehicle):
		vehicle.get_node("CameraBase/Camera3D").cycle_view()
		return
	camera_mode = (camera_mode+1)%3
	_notify(["Camera: chase","Camera: close","Camera: wide"][camera_mode])

func _update_follow(delta: float) -> void:
	var transport: Node3D
	if is_instance_valid(riding_bus): transport = riding_bus
	elif is_instance_valid(riding_service):
		var index := int(get_meta("cab_car",-1))
		if index>=0: transport = riding_service.cars[index].node
	if is_instance_valid(transport):
		if camera_manual<=0:
			yaw = lerp_angle(yaw,transport.rotation.y+PI,1-exp(-3*delta))
		var length := 14.0 if transport.is_in_group("city_buses") else 7.5
		foot_arm.spring_length = length if camera_mode==0 else (0.0 if camera_mode==1 else length+6)
		pivot.position.y = 1.0 if camera_mode==1 else 1.7
		foot_arm.collision_mask = 1 # exclude the service's own vehicle collider
	else:
		foot_arm.collision_mask = 3
		pivot.position.y = 1.4
		if not is_instance_valid(active_house):
			foot_arm.spring_length = [5.0,2.7,8.0][camera_mode]
			if camera_manual<=0 and Vector2(velocity.x,velocity.z).length()>0.3:
				yaw = lerp_angle(yaw,visual.rotation.y,1-exp(-3*delta))
