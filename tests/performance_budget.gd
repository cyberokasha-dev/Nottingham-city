extends SceneTree
var failed := false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1")
	seed(2468)
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed=true
		push_error(message)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.process_mode=Node.PROCESS_MODE_DISABLED
	game.economy.enabled=false
	var traffic=game.city.traffic
	check(Engine.physics_ticks_per_second==60,"Default physics uses a bounded 60 Hz budget")
	var optimized_candidates:=0
	var brute_candidates:=0
	for i in range(400):
		var position:=Vector3(randf_range(-155,155),traffic.LEVEL,randf_range(-140,155))
		var direction: Vector3=[Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD][i%4]
		traffic.clock=fmod(float(i)*.37,traffic.CYCLE)
		traffic.spatial_enabled=true
		var before: int=traffic.candidate_checks
		var fast: float=traffic.allowed_travel(position,direction,2.0,2.3,null)
		optimized_candidates+=traffic.candidate_checks-before
		traffic.spatial_enabled=false
		before=traffic.candidate_checks
		var reference: float=traffic.allowed_travel(position,direction,2.0,2.3,null)
		brute_candidates+=traffic.candidate_checks-before
		check(absf(fast-reference)<.0001,"Indexed clearance must match the full scan across the whole city")
	traffic.spatial_enabled=true
	check(optimized_candidates<brute_candidates/3,"Local queries inspect substantially fewer candidates")
	var car: Node3D=game.cabs.cars[0].node
	var previous: Vector3=car.global_position
	car.global_position=Vector3(-101,traffic.LEVEL,-91)
	traffic.track_vehicle(car)
	check(car in traffic.nearby_vehicles(car.global_position,1),"Same-frame cab movement updates its cell")
	car.global_position=previous
	traffic.track_vehicle(car)
	var added:=Node3D.new()
	game.add_child(added)
	added.position=Vector3(20,traffic.LEVEL,100)
	traffic.autonomous_nodes.append(added)
	check(added in traffic.nearby_vehicles(added.position,1),"New traffic becomes queryable immediately")
	traffic.autonomous_nodes.erase(added)
	added.free()
	check(traffic.vehicle_nodes().size()==78,"Index membership remains correct after adding and removing a vehicle")
	var atlas_builds: int=game.city_map.atlas_builds
	for i in range(30):
		game.player.yaw+=.02
		game.city_map._process(.1)
	check(atlas_builds==1 and game.city_map.atlas_builds==1,"Moving radar reuses its static atlas")
	game.performance.apply(0,false)
	check(root.scaling_3d_scale==.75 and root.msaa_3d==Viewport.MSAA_DISABLED,"Smooth lowers 3D rendering cost without reducing UI resolution")
	game.performance.apply(2,false)
	check(root.scaling_3d_scale==1 and root.msaa_3d==Viewport.MSAA_4X,"Higher detail remains available")
	game.performance.apply(0,false)
	var commuter=game.city.transport.buses[0].manifest[0].person
	check(not commuter.is_processing(),"Seated passengers do not run idle animation callbacks")
	commuter.walking=true
	check(commuter.is_processing(),"Walking enables passenger animation on demand")
	commuter.walking=false
	check(not commuter.is_processing(),"Finishing a walk releases the animation work")
	print("PERF_QUERY_COUNTS indexed=",optimized_candidates," full=",brute_candidates)
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop();audio.stream=null
	game.queue_free()
	await process_frame
	if not failed: print("PERFORMANCE_BUDGET_OK: indexed/reference equivalence, membership, cached atlas, rendering presets and on-demand animation")
	quit(1 if failed else 0)
