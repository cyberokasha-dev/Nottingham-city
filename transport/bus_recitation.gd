extends CanvasLayer
# One listener-owned player: never attach Quran audio to buses in the street.
const TRACKS := [
	[103,"Al-Asr"],[104,"Al-Humazah"],[105,"Al-Fil"],[106,"Quraysh"],
	[107,"Al-Maun"],[108,"Al-Kawthar"],[109,"Al-Kafirun"],[110,"An-Nasr"],
	[111,"Al-Masad"],[112,"Al-Ikhlas"],[113,"Al-Falaq"],[114,"An-Nas"]
]
var game: Node3D
var audio: AudioStreamPlayer
var panel: PanelContainer
var title: Label
var toggle: CheckButton
var current_bus: Node3D
var track_index := 0
var enabled := true
var positions: Dictionary = {}
var streams: Dictionary = {}

func _ready() -> void:
	layer = 15
	enabled = bool(game.economy.data.get("bus_quran_enabled",true))
	audio = AudioStreamPlayer.new()
	audio.name = "OnboardRecitation"
	audio.volume_db = -9
	audio.max_polyphony = 1
	audio.finished.connect(_next_track)
	add_child(audio)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10252e")
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel",style)
	panel.custom_minimum_size = Vector2(280,100)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	title = Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 260
	rows.add_child(title)
	toggle = CheckButton.new()
	toggle.text = "On-board Quran • U"
	toggle.button_pressed = enabled
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(set_enabled)
	rows.add_child(toggle)
	var next := Button.new()
	next.text = "Next surah"
	next.focus_mode = Control.FOCUS_NONE
	next.pressed.connect(_next_track)
	rows.add_child(next)
	panel.hide()

func set_enabled(value: bool) -> void:
	if enabled==value: return
	enabled = value
	game.economy.data.bus_quran_enabled = value
	game.economy.save()
	toggle.set_pressed_no_signal(value)
	if not enabled:
		if audio.playing and is_instance_valid(current_bus):
			positions[current_bus.get_instance_id()] = {"track":track_index,"seconds":audio.get_playback_position()}
		audio.stop()
	else:
		_start_track()
	_update_title()

func update_rider() -> void:
	var rider: Node3D = game.player
	var bus: Node3D = rider.get("riding_bus") if is_instance_valid(rider) else null
	if not is_instance_valid(bus) or bus.rider!=rider or not bus.visible or not rider.controlled:
		bus = null
	if bus!=current_bus:
		if is_instance_valid(current_bus):
			var old: Dictionary = positions.get(current_bus.get_instance_id(),{})
			positions[current_bus.get_instance_id()] = {"track":track_index,"seconds":audio.get_playback_position() if audio.playing else float(old.get("seconds",0))}
		audio.stop()
		audio.stream = null
		current_bus = bus
		if is_instance_valid(current_bus):
			var saved: Dictionary = positions.get(current_bus.get_instance_id(),{})
			track_index = int(saved.get("track",current_bus.get_meta("quran_seed",0)))%TRACKS.size()
			_start_track()
	panel.visible = is_instance_valid(current_bus)
	_update_title()

func _start_track() -> void:
	audio.stop()
	if not enabled or not is_instance_valid(current_bus): return
	var path := "res://transport/recitations/%03d.ogg" % int(TRACKS[track_index][0])
	if not streams.has(path): streams[path] = load(path)
	audio.stream = streams[path]
	var saved: Dictionary = positions.get(current_bus.get_instance_id(),{})
	var second := float(saved.get("seconds",0)) if int(saved.get("track",-1))==track_index else 0.0
	audio.play(second)

func _next_track() -> void:
	if not is_instance_valid(current_bus): return
	audio.stop()
	track_index = (track_index+1)%TRACKS.size()
	positions[current_bus.get_instance_id()] = {"track":track_index,"seconds":0.0}
	_start_track()
	_update_title()

func _update_title() -> void:
	if is_instance_valid(current_bus):
		title.text = "BUS %s • Sheikh Sudais\n%d · %s%s" % [current_bus.route.number,int(TRACKS[track_index][0]),TRACKS[track_index][1]," • off" if not enabled else ""]

func _process(_delta: float) -> void:
	panel.position = Vector2(maxf(20,get_viewport().get_visible_rect().size.x-310),255)
	update_rider()

func _unhandled_key_input(event: InputEvent) -> void:
	if panel.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_U:
		if is_instance_valid(game.phone) and game.phone.panel.visible: return
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
