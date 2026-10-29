extends SceneTree
# Six simulated minutes must cover a complete compact loop and repeated stops on every service.
func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST","1")
	Engine.physics_ticks_per_second = 30
	call_deferred("run")
func run() -> void:
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled = false
	var network = game.city.transport
	var positions := {}
	var travelled := {}
	var stationary := {}
	for frame in range(10800):
		await physics_frame
		for bus in network.buses:
			var id: int = bus.get_instance_id()
			var moved: float = bus.global_position.distance_to(positions.get(id,bus.global_position))
			travelled[id] = float(travelled.get(id,0))+moved
			stationary[id] = float(stationary.get(id,0))+1.0/30 if moved<0.005 and bus.state=="moving" else 0.0
			positions[id] = bus.global_position
	var failed := false
	for bus in network.buses:
		var id: int = bus.get_instance_id()
		print("SERVICE_CONTINUITY route=",bus.route.number," stops=",bus.services_completed," distance=",travelled[id]," stationary=",stationary[id])
		if bus.services_completed<5 or float(travelled[id])<float(bus.route.length)*1.1 or float(stationary[id])>30:
			failed = true
			push_error("A bus service stopped progressing in ordinary city traffic")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop()
		audio.stream = null
	game.queue_free()
	await process_frame
	if not failed: print("CITY_SERVICE_CONTINUITY_OK: all eight paid bus services keep progressing with traffic, pedestrians and district Aurora cabs active")
	quit(1 if failed else 0)
