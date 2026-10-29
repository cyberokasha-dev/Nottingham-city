extends SceneTree

func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST", "1")
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled = false
	for frame in range(30):
		await physics_frame
	var link: Node = null
	for child in game.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == "res://phone/phone_link.gd":
			link = child
	if link == null:
		fail("The game must create the phone link")
		return
	link.apply_state({"t": "s", "x": 0.0, "y": -1.0, "b": ["CROSS", "R2"], "lx": 0.0, "ly": 0.0, "cc": 0})
	await physics_frame
	if not Input.is_action_pressed("walk_forward") or not Input.is_action_pressed("accelerate"):
		fail("Stick forward must press walk_forward and accelerate")
		return
	if not Input.is_action_pressed("sprint") or not Input.is_action_pressed("handbrake"):
		fail("CROSS must press sprint and handbrake")
		return
	link.apply_state({"t": "s", "x": -0.8, "y": 0.0, "b": ["SQUARE"], "lx": 0.0, "ly": 0.0, "cc": 0})
	await physics_frame
	if Input.is_action_pressed("walk_forward") or Input.is_action_pressed("sprint"):
		fail("Released controls must release their actions")
		return
	if not Input.is_action_pressed("walk_left") or not Input.is_action_pressed("turn_left") or not Input.is_action_pressed("jump"):
		fail("Stick left and SQUARE must press walk_left, turn_left and jump")
		return
	var p = game.player
	var before: float = p.yaw
	link._apply_look(Vector2(100, 0))
	if is_equal_approx(before, p.yaw):
		fail("Camera swipe must turn the player's camera")
		return
	link._release_all()
	for action in link.MANAGED_ACTIONS:
		if Input.is_action_pressed(action):
			fail("Releasing the link must release " + action)
			return
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*", "AudioStreamPlayer3D", true, false) + game.find_children("*", "AudioStreamPlayer", true, false):
		audio.stop()
		audio.stream = null
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	print("PHONE_LINK_OK: sticks, buttons, look and release")
	quit(0)
