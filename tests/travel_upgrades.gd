extends SceneTree
var failed:=false
func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST","1"); seed(72015); call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failed=true; push_error(message)
func run() -> void:
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); game.process_mode=Node.PROCESS_MODE_DISABLED; game.economy.enabled=false
	var p=game.player; var e=game.economy; var cabs=game.cabs; var air=game.helicopters
	var key: String=e.key_for(p)
	check(game.city.infill.sites.size()>50 and game.city.outer_parks.size()>6,"Green spaces gain streamed gardens, shops, woodland and additional playable parks")
	for site in game.city.infill.sites:
		check(not air.clear_ground(site.point),"New landmarks are protected landing exclusions even when unloaded")
	for i in range(300):
		var point:=Vector3((i*173)%2800-1400,-5,(i*619)%2800-1400)
		var clear:bool=preload("res://town/world_layout.gd").place_clear(point,9)
		for site in game.city.infill.sites:
			if Vector2(point.x-site.point.x,point.z-site.point.z).length()<float(site.radius)+9: clear=false; break
		check(game.city.infill.landing_clear(point)==clear,"Local landing queries agree with the full city atlas")
	for pad in air.pads: check(air.clear_ground(pad.point),"Existing helicopter stations remain unobstructed")
	var train_model:=preload("res://transport/train_model.gd").make(Color("eeb053"))
	var body_extent:=0.0
	for part in train_model.get_children():
		if not part is MeshInstance3D or part.material_override.albedo_color!=Color("e8eff1"): continue
		var arrays: Array=part.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for index in arrays[Mesh.ARRAY_INDEX]: body_extent=maxf(body_extent,absf(vertices[index].z))
	check(body_extent>32.8,"The rendered train indices include the nose and body shell, not only window pillars")
	train_model.free()
	# A purchased pass is written and reloaded from a separate file, never the player's ordinary save.
	e.save_path="user://travel-upgrades-test.json"
	var balance: int=e.cash(p); var council: int=e.data.council
	OS.unset_environment("NOTTINGHAM_TEST"); e.enabled=true
	check(e.buy_day_pass(p),"A funded character can buy a 24-hour ticket")
	OS.set_environment("NOTTINGHAM_TEST","1"); e.enabled=false
	var code: String=e.day_pass(p).code
	check(e.cash(p)==balance-2500 and int(e.data.council)==council+2500,"The £25 purchase is charged exactly once")
	check(not e.buy_day_pass(p) and e.cash(p)==balance-2500,"An active ticket cannot be purchased twice")
	var reloaded=preload("res://simulation/economy.gd").new(); reloaded.save_path=e.save_path; reloaded.load_saved_data()
	check(reloaded.has_day_pass(p) and reloaded.day_pass(p).code==code and reloaded.pass_seconds_left(p)>86390,"The same code and real-time expiry survive a fresh save load")
	check(not reloaded.validate_pass_code(game.party.members[1],code),"A different character cannot spend another person's pass")
	reloaded.free(); DirAccess.remove_absolute(e.save_path)
	e.account_for(p).balance=0
	var car: Dictionary=cabs.cars[0]
	p.global_position=car.node.position+Vector3(3,0,0)
	var trip: Dictionary=cabs.walk_up(p,0)
	check(not trip.is_empty() and cabs.board_near(p),"A valid pass boards Aurora with no cash")
	for i in range(35): cabs._physics_process(.1)
	check(cabs.choose_destination(p,{"name":"Mapperley","point":game.cabs.ranks[2].rank}),"Destination-later pricing keeps pass coverage")
	check(e.cash(p)==0 and int(e.data.receipts[key].amount)==0 and e.data.receipts[key].pass_code==code,"The journey holds a zero fare linked to the code")
	check(cabs.set_manual(p,true) and cabs.is_manual(p),"Booked Aurora can be driven by its passenger")
	game.phone.panel.hide()
	car.node.position=Vector3(137.2,-5.02,-300); car.node.rotation.y=PI
	game.city.traffic.autonomous_nodes.clear(); game.city.traffic.autonomous_nodes.append(car.node); game.city.traffic.cars.clear(); game.city.traffic.pedestrians.clear(); game.city.traffic.invalidate_spatial()
	Input.action_press("accelerate")
	var start: Vector3=car.node.position
	for i in range(30): cabs._physics_process(.05)
	Input.action_release("accelerate")
	check(car.node.position.distance_to(start)>1 and p.visual.mounted,"Manual throttle moves the actual cab with its passenger attached")
	check(cabs.set_manual(p,false) and not cabs.is_manual(p) and car.path.size()>1,"Self-drive rebuilds a road route from the manual position")
	check(cabs.set_manual(p,true) and cabs.set_fast(p,true),"The same journey can switch back to player driving and faster speed")
	check(cabs.skip_journey(p) and not car.manual and not car.fast and not p.get_meta("service_driving",true),"Finishing releases a default autonomous cab with no remaining driver input")
	check(e.cash(p)==0 and not e.data.receipts.has(key),"Manual and automatic switches never create another fare")
	# Short consecutive route segments cannot introduce a dead frame at each point.
	car.node.position=Vector3(322.8,-5.02,300); car.node.rotation.y=0
	car.path=PackedVector3Array(); car.index=0; car.speed=10; car.fast=false; car.state="dropoff"
	for i in range(1,31): car.path.append(car.node.position+Vector3(0,0,i*.2))
	for i in range(4):
		var moved: float=cabs._advance_route(car,.05)
		check(moved>.3,"Dense route points retain continuous movement instead of discarding a whole update")
	# All three services recognise the same pass; an expired pass returns to ordinary fares.
	var aircraft: Dictionary=air.cars[0]
	p.global_position=aircraft.node.position+Vector3(3,0,0)
	trip=air.walk_up(p,0)
	check(not trip.is_empty() and air.board_near(p),"The same saved code boards a helicopter without cash")
	for i in range(65): air._physics_process(.05)
	check(air.set_fast(p,true) and aircraft.fast and air.set_high_flight(p,true),"Flight speed and height are independent choices")
	check(air.choose_destination(p,{"name":"Lenton Station","point":game.rail.stations[1].point}),"Pass-funded helicopter can choose a real destination")
	var peak_flight_speed:=0.0
	for i in range(500):
		air._physics_process(.05); peak_flight_speed=maxf(peak_flight_speed,float(aircraft.speed))
	check(peak_flight_speed>30,"The faster flight button increases the actual cruise speed")
	check(air.skip_journey(p) and not aircraft.fast,"Helicopter arrival settles the pass once and resets speed")
	var train=game.rail.trains[0]; p.global_position=train.entrance()
	check(train.board(p) and e.cash(p)==0,"The same pass boards a train without another charge")
	train.rider_board_clock=train.boarding_seconds; check(train.leave(p),"Pass passenger can leave a stationary train")
	e.data.travel_passes[key].expires=Time.get_unix_time_from_system()-1
	check(not e.has_day_pass(p) and not e.can_pay_fare(p,300,"Aurora") and not e.charge_transport(p,400,"Train","Train fare"),"Expired 24-hour codes never provide free new journeys")
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false): audio.stop(); audio.stream=null
	game.queue_free(); await process_frame
	if not failed: print("TRAVEL_UPGRADES_OK: streamed city infill, saved 24-hour pass across three services, manual/self-drive switches, speed controls and continuous route movement")
	quit(1 if failed else 0)
