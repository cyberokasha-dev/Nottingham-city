extends CanvasLayer
## Keyboard, touch and standardized gamepad actions use the same InputMap.
var status: Label
var health_bar: ProgressBar
var health_style: StyleBoxFlat
var injury_overlay: ColorRect
var player: Node3D
var voice_toggle: CheckButton
static func bind() -> void:
	if InputMap.has_action("character_wheel"):
		return
	var keys := {"punch": KEY_F,"heavy_punch": KEY_R,"guard": KEY_Q,"cancel_action": KEY_G,"character_wheel": KEY_C,"fold_arms": KEY_H,"look_modifier": KEY_Z,"sprint": KEY_SHIFT}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action,0.2)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	var trigger_key := InputEventKey.new()
	trigger_key.physical_keycode = KEY_V
	InputMap.action_add_event("punch",trigger_key)
	# Vehicle triggers remain acceleration/reverse; face buttons keep one meaning.
	for action in ["accelerate","reverse","cycle_camera"]:
		for existing in InputMap.action_get_events(action):
			if existing is InputEventJoypadButton:
				InputMap.action_erase_event(action,existing)
	for existing in InputMap.action_get_events("cycle_camera"):
		if existing is InputEventKey and existing.physical_keycode == KEY_C:
			InputMap.action_erase_event("cycle_camera",existing)
	var camera_key := InputEventKey.new()
	camera_key.physical_keycode = KEY_B
	InputMap.action_add_event("cycle_camera",camera_key)
	var wheel_button := InputEventJoypadButton.new()
	wheel_button.button_index = JOY_BUTTON_DPAD_DOWN
	InputMap.action_add_event("character_wheel",wheel_button)
	var camera_button := InputEventJoypadButton.new()
	camera_button.button_index = JOY_BUTTON_RIGHT_STICK
	InputMap.action_add_event("cycle_camera",camera_button)
	var buttons := {"interact": JOY_BUTTON_Y,"punch": JOY_BUTTON_X,"jump": JOY_BUTTON_A,"cancel_action": JOY_BUTTON_B,"guard": JOY_BUTTON_LEFT_SHOULDER,"heavy_punch": JOY_BUTTON_RIGHT_SHOULDER,"sprint": JOY_BUTTON_LEFT_STICK}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action,event)
	for action in {"walk_left": [JOY_AXIS_LEFT_X,-1.0],"walk_right": [JOY_AXIS_LEFT_X,1.0],"walk_forward": [JOY_AXIS_LEFT_Y,-1.0],"walk_back": [JOY_AXIS_LEFT_Y,1.0],"look_modifier": [JOY_AXIS_TRIGGER_LEFT,1.0],"punch": [JOY_AXIS_TRIGGER_RIGHT,1.0]}:
		var values: Array = {"walk_left": [JOY_AXIS_LEFT_X,-1.0],"walk_right": [JOY_AXIS_LEFT_X,1.0],"walk_forward": [JOY_AXIS_LEFT_Y,-1.0],"walk_back": [JOY_AXIS_LEFT_Y,1.0],"look_modifier": [JOY_AXIS_TRIGGER_LEFT,1.0],"punch": [JOY_AXIS_TRIGGER_RIGHT,1.0]}[action]
		var event := InputEventJoypadMotion.new()
		event.axis = values[0]
		event.axis_value = values[1]
		InputMap.action_add_event(action,event)

func _ready() -> void:
	injury_overlay = ColorRect.new()
	injury_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	injury_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	injury_overlay.color = Color(0.65,0.03,0.03,0)
	add_child(injury_overlay)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20,-166)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	status = Label.new()
	status.add_theme_font_size_override("font_size",16)
	rows.add_child(status)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(200,16)
	health_style = StyleBoxFlat.new()
	health_style.bg_color = Color("6cdfa1")
	health_style.set_corner_radius_all(4)
	health_bar.add_theme_stylebox_override("fill",health_style)
	health_bar.max_value = 100
	health_bar.show_percentage = true
	rows.add_child(health_bar)
	var row := HBoxContainer.new()
	rows.add_child(row)
	var layout := [["△ E · Use","interact",Color("7ee0b1")],["□ F · Punch","punch",Color("eda5df")],["✕ Space · Jump","jump",Color("8bbaff")],["○ G · Stand / Wake","cancel_action",Color("f59a98")],["L1 Q · Guard","guard",Color.WHITE],["R1 R · Heavy","heavy_punch",Color.WHITE],["H · Fold arms","fold_arms",Color.WHITE]]
	for item in layout:
		var button := Button.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color",item[2])
		button.button_down.connect(func(): Input.action_press(item[1]))
		button.button_up.connect(func(): Input.action_release(item[1]))
		row.add_child(button)
	var character_button := Button.new()
	character_button.text = "C · Characters"
	character_button.focus_mode = Control.FOCUS_NONE
	character_button.pressed.connect(player.party.toggle_wheel)
	row.add_child(character_button)
	var hint := Label.new()
	hint.text = "WASD / left stick: move   Shift / L3: run   L2 Z: focus   R2 V: punch   right stick / right mouse: look · C: characters · H: fold arms"
	hint.add_theme_font_size_override("font_size",13)
	rows.add_child(hint)
	var sound := CheckButton.new()
	voice_toggle = sound
	sound.text = "Voices on · click the game once to enable browser sound"
	sound.button_pressed = true
	sound.focus_mode = Control.FOCUS_NONE
	sound.toggled.connect(func(enabled):
		if is_instance_valid(player.party):
			player.party.voices_enabled = enabled
		for person in get_tree().get_nodes_in_group("people"):
			person.dialogue.muted = not enabled
			if not enabled:
				person.dialogue.voice.stop()
				person.dialogue._release_slot())
	rows.add_child(sound)

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		if is_instance_valid(player.party):
			voice_toggle.set_pressed_no_signal(player.party.voices_enabled)
		var state: String = "Waking up" if player.waking else ("DEAD" if player.dead else (player.resting.capitalize() if player.resting != "" else ("Guarding" if player.guarding else "Free roam")))
		if is_instance_valid(player.party) and player.party.game.conversation.active:
			state = "Talking"
		status.text = "%s  ·  Health %d / 100  ·  %s" % [player.profile.name,player.health,state]
		health_bar.value = player.health
		health_style.bg_color = Color("ee6a66") if player.health < 30 else (Color("eac56d") if player.health < 60 else Color("6cdfa1"))
		injury_overlay.color.a = 0.22 if player.dead else (0.12*player.hurt_time/0.28)
