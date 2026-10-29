extends SceneTree
# Live populated-city journey: the cab climbs the Central station ramp and stops beside the platform.
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1")
	Engine.physics_ticks_per_second=30
	call_deferred("run")
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled=false
	game.player.set_physics_process(false)
	var p=game.player
	var rail=game.rail
	var station:Dictionary=rail.stations[1]
	p.global_position=Vector3(47.7,-4.98,35)
	var trip=game.cabs.book(p,{"name":station.name,"point":station.bay})
	var boarded=false
	var done=false
	var safe=true
	var top:float=-INF
	var car:Dictionary={}
	for frame in range(9000):
		await physics_frame
		car=game.cabs.cars[trip.car]
		top=maxf(top,car.node.global_position.y)
		if rail.track_zone(car.node.global_position): safe=false
		if trip.state=="waiting" and not boarded:
			p.global_position=game.cabs.boarding_point(p)
			boarded=game.cabs.unlock(p,trip.pin)
		if boarded and p.riding_service==null:
			done=true
			break
		if not game.cabs.bookings.has(game.economy.key_for(p)): break
	var ok:bool=done and safe and top<station.point.y+.3 and car.node.global_position.distance_to(station.bay)<.6 and absf(p.global_position.y-station.point.y)<.4 and not rail.track_zone(p.global_position)
	print("STATION_JOURNEY boarded=",boarded," done=",done," safe=",safe," top=",top," car=",car.node.global_position," player=",p.global_position)
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop();audio.stream=null
	await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	if ok: print("STATION_JOURNEY_OK: live cab used the level station approach, stopped beside the platform off the track, passenger at the level entrance")
	call_deferred("quit",0 if ok else 1)
