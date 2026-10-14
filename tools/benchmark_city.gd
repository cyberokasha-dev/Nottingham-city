extends SceneTree
# Run: godot --headless --path . --fixed-fps 60 --script res://tools/benchmark_city.gd
# Omit --headless to include GPU/render cost. Keep resolution, camera and hardware
# identical between revisions; timings are measurements, not CI pass thresholds.
var frames: Array[float] = []
var cpu: Array[float] = []
var physics: Array[float] = []
var draw_calls: Array[float] = []
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1")
	seed(12345)
	call_deferred("run")
func run():
	var startup_started := Time.get_ticks_usec()
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	var startup_sync_ms := (Time.get_ticks_usec()-startup_started)/1000.0
	var startup_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	game.economy.enabled=false
	await process_frame
	var first_frame_ms := (Time.get_ticks_usec()-startup_started)/1000.0
	for i in range(30): await process_frame
	var previous=Time.get_ticks_usec()
	for i in range(180):
		await process_frame
		var current=Time.get_ticks_usec()
		frames.append((current-previous)/1000.0)
		previous=current
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	frames.sort();cpu.sort();physics.sort();draw_calls.sort()
	print("CITY_BENCH ",JSON.stringify({"startup_sync_ms":startup_sync_ms,"first_frame_ms":first_frame_ms,"startup_nodes":startup_nodes,"physics_hz":Engine.physics_ticks_per_second,"frame_ms_median":frames[90],"frame_ms_p95":frames[171],"cpu_ms_median":cpu[90],"physics_ms_median":physics[90],"draw_calls":draw_calls[90],"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}))
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop(); audio.stream=null
	game.queue_free()
	await process_frame
	quit()
