extends Node
const CATALOG = preload("res://simulation/cab_voice_catalog.gd")
var voice: AudioStreamPlayer3D
var remaining := 0.0
var cooldown := 0.0
var personality := 0
var quiet := false

func _ready() -> void:
	name = "CabDialogue"
	voice = AudioStreamPlayer3D.new()
	voice.stream = preload("res://simulation/audio/aurora.ogg")
	voice.max_distance = 22
	voice.unit_size = 10
	voice.volume_db = -3
	voice.pitch_scale = [1.0,0.97,1.03][personality]
	add_child(voice)

func say(person: Node3D, topic: String) -> void:
	if cooldown>0 and topic not in ["welcome","arrival"]: return
	voice.stop()
	if quiet and topic=="arrival": return
	var key := topic+"_"+str(personality)
	if not CATALOG.LINES.has(key): return
	var line: Dictionary = CATALOG.LINES[key]
	person.set_meta("cab_reply","Aurora: "+str(line.text))
	if person.has_method("_notify"): person._notify("Aurora: "+str(line.text))
	if person.get("controlled")==true and person.party.voices_enabled:
		voice.play(float(line.start))
		remaining = float(line.duration)/voice.pitch_scale
	cooldown = 1.0
	if topic=="quiet": quiet = true
	elif topic=="welcome": quiet = false

func _process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	remaining -= delta
	if remaining<=0 and voice.playing: voice.stop()

func _exit_tree() -> void:
	voice.stop()
	voice.stream = null
