extends Node3D
# Quiet spatial loops and short original effects; no network or speech service.
var engine: AudioStreamPlayer3D
var effect_player: AudioStreamPlayer3D
var last_kind := ""
var range_clock := 1.0
var in_range := false
static var loops: Dictionary = {}
static var effects: Dictionary = {}

func _ready() -> void:
	name = "ServiceAudio"
	engine = AudioStreamPlayer3D.new()
	engine.max_distance = 38
	engine.unit_size = 7
	engine.volume_db = -18
	add_child(engine)
	effect_player = AudioStreamPlayer3D.new()
	effect_player.max_distance = 30
	effect_player.unit_size = 6
	effect_player.volume_db = -8
	add_child(effect_player)

func _process(delta: float) -> void:
	range_clock += delta
	if range_clock>0.3:
		range_clock = 0
		var camera := get_viewport().get_camera_3d()
		in_range = is_instance_valid(camera) and camera.global_position.distance_squared_to(global_position)<1600
		if not in_range: engine.stop()

func set_motion(speed: float, kind := "engine") -> void:
	if not in_range or kind=="silent" or speed<0.15:
		engine.stop()
		return
	if last_kind!=kind:
		engine.stop()
		if not loops.has(kind):
			var stream: AudioStreamWAV = load("res://simulation/audio/"+kind+".wav").duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = int(stream.get_length()*stream.mix_rate)
			loops[kind] = stream
		engine.stream = loops[kind]
		last_kind = kind
	engine.pitch_scale = clampf(0.7+speed/14.0,0.7,1.8)
	engine.volume_db = -22 if kind=="electric" else -18
	if not engine.playing: engine.play()

func effect(kind: String) -> void:
	if not effects.has(kind): effects[kind] = load("res://simulation/audio/"+kind+".wav")
	effect_player.stream = effects[kind]
	effect_player.play()

func _exit_tree() -> void:
	if is_instance_valid(engine):
		engine.stop()
		engine.stream = null
	if is_instance_valid(effect_player):
		effect_player.stop()
		effect_player.stream = null
