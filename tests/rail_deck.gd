extends SceneTree
# People must be able to stand on the ground-level track bed and platform without falling through.
var failed:=false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1")
	Engine.physics_ticks_per_second=30
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed=true
		push_error(message)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled=false
	var p=game.player
	var station:Dictionary=game.rail.stations[0]
	p.global_position=station.point+Vector3(0,float(station.height)+8,60)
	game.city.regions.refresh_at(p.global_position)
	for i in range(60):
		game.city.regions._process(.2)
		game.rail._process(.2)
		await physics_frame
	# Track bed 60 m along the line from the station, then the platform itself.
	var basis:=Basis(Vector3.UP,float(station.heading))
	var spots:=[basis*Vector3(0,0,20),basis*Vector3(0,0,60),basis*Vector3(7,0,10)]
	for spot in spots:
		p.global_position=station.point+spot+Vector3(0,float(station.height)+1.5,0)
		p.velocity=Vector3.ZERO
		for i in range(45): await physics_frame
		check(p.global_position.y>station.point.y+float(station.height)-.5,"Player stands on the ground-level track bed at "+str(spot)+" y="+str(p.global_position.y))
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop();audio.stream=null
	await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	if not failed: print("RAIL_DECK_OK: ground-level bed and platform are solid")
	call_deferred("quit",1 if failed else 0)
