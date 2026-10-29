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
	check(get_node_count()<10000,"Startup scene stays below ten thousand nodes with the full city population")
	check(game.city.houses.filter(func(h):return h.exterior_built).is_empty(),"Full house facades are not built all at once")
	var house=game.city.houses[0]
	var entrance: Vector3=house.entrance()
	house.ensure_detail()
	house.update_detail(true)
	check(house.exterior_built and not house.shell.visible and house.entrance()==entrance,"Detailed exteriors retain the exact address and doorway")
	house.update_detail(false)
	check(house.shell.visible,"Distant houses use the lightweight shell after detail has been visited")
	house.set_inside(true)
	check(not house.shell.visible and house.interior.visible and not house.roof.visible,"Entering a distant house restores furniture and the cutaway immediately")
	for mesh in house.front.get_children():
		if mesh is MeshInstance3D: check(not mesh.visible,"Interior cutaway survives detail scheduling")
	house.update_detail(false)
	for mesh in house.front.get_children():
		if mesh is MeshInstance3D: check(not mesh.visible,"Occupied houses keep their cutaway during distance updates")
	house.set_inside(false)
	var built_before: int=game.city.houses.filter(func(h):return h.exterior_built).size()
	game.city._process(.3)
	var built_after: int=game.city.houses.filter(func(h):return h.exterior_built).size()
	check(built_after>=built_before and built_after<=built_before+1,"House detail scheduling builds at most one facade per frame")
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
	var fleet_count:int=traffic.vehicle_nodes().size()
	var added:=Node3D.new()
	game.add_child(added)
	added.position=Vector3(20,traffic.LEVEL,100)
	traffic.autonomous_nodes.append(added)
	check(added in traffic.nearby_vehicles(added.position,1),"New traffic becomes queryable immediately")
	traffic.autonomous_nodes.erase(added)
	added.free()
	check(traffic.vehicle_nodes().size()==fleet_count,"Index membership remains correct after adding and removing a vehicle")
	var atlas_builds: int=game.city_map.atlas_builds
	for i in range(30):
		game.player.yaw+=.02
		game.city_map._process(.1)
	check(atlas_builds==1 and game.city_map.atlas_builds==1,"Moving radar reuses its static atlas")
	game.performance.apply(0,false)
	check(root.scaling_3d_scale==.75 and root.msaa_3d==Viewport.MSAA_DISABLED,"Smooth lowers 3D rendering cost without reducing UI resolution")
	for i in range(10): game.performance.adjust_resolution(18)
	check(is_equal_approx(root.scaling_3d_scale,.55),"Smooth reduces pixel cost on sustained slow frames with a fixed lower bound")
	for i in range(10): game.performance.adjust_resolution(60)
	check(is_equal_approx(root.scaling_3d_scale,.75),"Smooth restores full preset resolution when frame-rate headroom returns")
	game.performance.apply(2,false)
	game.performance.adjust_resolution(10)
	check(root.scaling_3d_scale==1 and root.msaa_3d==Viewport.MSAA_4X,"Higher detail remains available")
	game.performance.apply(0,false)
	var commuter=game.city.transport.buses[0].manifest[0].person
	check(commuter.find_children("*","MeshInstance3D",true,false).size()==1,"A seated commuter uses one immutable shared mesh")
	var twin=preload("res://transport/crowd_person.gd").new()
	twin.variant=commuter.variant+12
	game.add_child(twin)
	twin.set_seated(true)
	check(twin.still.mesh==commuter.still.mesh,"Matching crowd appearances share seated mesh resources")
	var seated_mesh: Mesh=commuter.still.mesh
	check(not commuter.is_processing(),"Seated passengers do not run idle animation callbacks")
	commuter.walking=true
	check(commuter.is_processing() and is_instance_valid(commuter.rig),"Walking enables articulated limbs and animation on demand")
	commuter.walking=false
	check(not commuter.is_processing() and not is_instance_valid(commuter.rig) and commuter.still.mesh==seated_mesh,"Finishing a walk releases the rig and reuses the exact seated pose")
	twin.free()
	print("PERF_QUERY_COUNTS indexed=",optimized_candidates," full=",brute_candidates)
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop();audio.stream=null
	game.queue_free()
	await process_frame
	check(preload("res://transport/crowd_person.gd").templates.is_empty() and preload("res://vehicles/road_car.gd").wheel_meshes.is_empty(),"Leaving the city releases shared mesh templates")
	check(preload("res://simulation/service_audio.gd").loops.is_empty(),"Leaving the city releases cached audio streams before engine shutdown")
	if not failed: print("PERFORMANCE_BUDGET_OK: indexed/reference equivalence, membership, cached atlas, rendering presets, staged facades, shared crowd meshes and on-demand animation")
	quit(1 if failed else 0)
