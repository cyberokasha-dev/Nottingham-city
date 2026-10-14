extends Node3D
## Pre-rendered neural speech works offline and in the single-threaded browser build.
const LINES := {
	"hello":"Hello! How are you?",
	"greeting":"Good morning! Lovely day for a walk.",
	"park":"Have you visited the park? It's a nice place to relax.",
	"home":"I'll stop at home after this. See you around!",
	"day":"I'm doing well, thank you. What a lovely day!",
	"hurt":"Ow! Hey, stop that!",
	"blocked":"Blocked! Let's keep this friendly.",
	"rest":"I'm taking a little rest.",
	"awake":"I'm awake. Let's start again.",
	"bye":"Take care. I'll see you later!"
}
var actor: CharacterBody3D
const SCENE_LINES = preload("res://actors/dialogue_data.gd")
var viewer: Node3D
var voice_set := "alba"
var remaining := 0.0
var catalog := {}
var variant := 0
var voice: AudioStreamPlayer
var cooldown := 0.0
var last_line := ""
var spoken_lines := 0
static var active_speakers := 0
var owns_slot := false
var muted := false

func _ready() -> void:
	voice = AudioStreamPlayer.new()
	voice.pitch_scale = float(actor.profile.voice_pitch) if "profile" in actor and actor.profile.has("voice_pitch") else 0.96+(variant%3)*0.025
	add_child(voice)
	voice.finished.connect(_release_slot)
	catalog = preload("res://actors/voices/catalog.gd").BANKS[voice_set]
	voice.stream = load("res://actors/voices/"+voice_set+".ogg")
	set_process(false)

static func text_for(key: String) -> String:
	return LINES.get(key,SCENE_LINES.LINES.get(key,""))

func speak(key: String, priority := false) -> bool:
	if (key not in LINES and key not in SCENE_LINES.LINES) or muted or (actor.dead and key != "awake"):
		return false
	if is_instance_valid(viewer) and actor.global_position.distance_to(viewer.global_position) > 18:
		return false
	if not priority and (cooldown > 0 or active_speakers >= 2):
		return false
	if priority:
		voice.stop()
		_release_slot()
	if voice.stream == null or key not in catalog:
		return false
	var segment: Dictionary = catalog[key]
	var distance := actor.global_position.distance_to(viewer.global_position) if is_instance_valid(viewer) else 0.0
	# Camera-independent distance attenuation is consistent with WebAudio sample playback.
	voice.volume_db = lerpf(-2,-20,clampf(distance/18.0,0,1))
	set_process(true)
	voice.play(float(segment.start))
	remaining = float(segment.duration)/voice.pitch_scale
	active_speakers += 1
	owns_slot = true
	spoken_lines += 1
	last_line = key
	cooldown = maxf(1.0,remaining+0.5)
	return true

func _process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	if owns_slot:
		remaining -= delta
		if remaining <= 0:
			voice.stop()
			_release_slot()
	if is_instance_valid(actor) and actor.dead and voice.playing:
		voice.stop()
		_release_slot()
	if cooldown<=0 and not owns_slot: set_process(false)

func _release_slot() -> void:
	if owns_slot:
		active_speakers = maxi(0,active_speakers-1)
		owns_slot = false

func _exit_tree() -> void:
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
	_release_slot()

func stop() -> void:
	voice.stop()
	_release_slot()

func duration_for(key: String) -> float:
	return float(catalog.get(key,{"duration":2.0}).duration)/voice.pitch_scale

func event(event_name: String) -> void:
	if "profile" in actor:
		speak("event_"+actor.profile.name.to_lower()+"_"+event_name,true)
