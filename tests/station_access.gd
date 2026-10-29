extends SceneTree
var failed:=false
func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST","1")
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed=true
		push_error(message)
func run() -> void:
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled=false
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var rail=game.rail
	var cabs=game.cabs
	var air=game.helicopters
	var p=game.player
	for station in rail.stations:
		check(station.ramps.has(1) and station.ramps.has(-1),station.name+" has a level access path on both platforms")
		for side in station.ramps:
			var points:PackedVector3Array=station.ramps[side].points
			check(absf(points[0].y-(station.point.y+float(station.height)))<.01 and absf(points[points.size()-1].y-station.point.y)<.01,station.name+" ramp joins platform level to the ground")
			for i in range(1,points.size()):
				var run:=Vector2(points[i].x-points[i-1].x,points[i].z-points[i-1].z).length()
				check(absf(points[i].y-points[i-1].y)/maxf(run,.01)<.13,station.name+" ramp is gentle enough to walk or drive")
		check(station.has("bay") and not rail.track_zone(station.bay),station.name+" cab bay is outside the ground-level track corridor")
		var nearest:=INF
		for pad in air.pads: nearest=minf(nearest,pad.point.distance_to(station.point))
		check(nearest>=30 and nearest<=75,station.name+" has a helipad beside its entrance, "+str(nearest))
		check(rail.bay_for(station.bay)==station,"Bay is recognised as a station destination")
	for pad in air.pads: check(air.clear_ground(pad.point),"Station helipad ground is clear: "+pad.name)
	# A cab climbs to the Central bay and stops off the track.
	var station:Dictionary=rail.stations[1]
	p.global_position=Vector3(47.7,-4.98,35)
	var path:PackedVector3Array=cabs.path_between(Vector3(47.7,-5.02,35),station.bay,Vector3(0,0,1))
	check(path.size()>3 and path[path.size()-1].distance_to(station.bay)<.1,"Aurora route ends at the station bay")
	var top:=-INF
	for point in path:
		top=maxf(top,point.y)
		check(not rail.track_zone(point),"Aurora route never enters the track corridor")
	check(top>station.bay.y-.01 and absf(top-station.point.y)<.2,"Aurora stays at ground level")
	var back:PackedVector3Array=cabs.path_between(station.bay,Vector3(47.7,-5.02,35))
	check(back.size()>3 and absf(back[0].y-station.point.y)<.2 and back[1].y<=back[0].y+.01,"Leaving the bay stays at ground level")
	game.queue_free()
	await process_frame
	if not failed: print("STATION_ACCESS_OK: level access paths, cab bay clear of track, station helipads")
	quit(1 if failed else 0)
