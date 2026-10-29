extends CanvasLayer
## Keyboard, touch and standardized gamepad actions use the same InputMap.
var panel: PanelContainer
var status: Label
var health_bar: ProgressBar
var health_style: StyleBoxFlat
var injury_overlay: ColorRect
var player: Node3D
var voice_toggle: CheckButton
var action_buttons: Array[Button] = []
var last_control_mode := ""
var expanded:=false
var help_widgets:Array[Control]=[]
static func bind() -> void:
	if InputMap.has_action("character_wheel"):
		return
	var keys := {"punch": KEY_V,"heavy_punch": KEY_R,"guard": KEY_Q,"cancel_action": KEY_G,"character_wheel": KEY_C,"fold_arms": KEY_H,"look_modifier": KEY_Z,"sprint": KEY_SHIFT,"handbrake": KEY_SPACE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action,0.2)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action,event)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_F
	InputMap.action_add_event("interact",interact_key)
	var mouse_punch := InputEventMouseButton.new()
	mouse_punch.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("punch",mouse_punch)
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
	var buttons := {"interact": JOY_BUTTON_Y,"jump": JOY_BUTTON_X,"punch": JOY_BUTTON_B,"guard": JOY_BUTTON_LEFT_SHOULDER,"heavy_punch": JOY_BUTTON_RIGHT_SHOULDER,"sprint": JOY_BUTTON_A,"handbrake": JOY_BUTTON_A}
	for action in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action,event)
	for action in {"walk_left": [JOY_AXIS_LEFT_X,-1.0],"walk_right": [JOY_AXIS_LEFT_X,1.0],"walk_forward": [JOY_AXIS_LEFT_Y,-1.0],"walk_back": [JOY_AXIS_LEFT_Y,1.0],"look_modifier": [JOY_AXIS_TRIGGER_LEFT,1.0],"accelerate": [JOY_AXIS_TRIGGER_RIGHT,1.0],"reverse": [JOY_AXIS_TRIGGER_LEFT,1.0]}:
		var values: Array = {"walk_left": [JOY_AXIS_LEFT_X,-1.0],"walk_right": [JOY_AXIS_LEFT_X,1.0],"walk_forward": [JOY_AXIS_LEFT_Y,-1.0],"walk_back": [JOY_AXIS_LEFT_Y,1.0],"look_modifier": [JOY_AXIS_TRIGGER_LEFT,1.0],"accelerate": [JOY_AXIS_TRIGGER_RIGHT,1.0],"reverse": [JOY_AXIS_TRIGGER_LEFT,1.0]}[action]
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
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
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
	var row := HFlowContainer.new()
	rows.add_child(row)
	help_widgets.append(row)
	var layout := [["△ / E · Interact","interact",Color("7ee0b1")],["□ / Space · Jump","jump",Color("8bbaff")],["○ / Mouse · Punch","punch",Color("eda5df")],["× / Shift · Run","sprint",Color.WHITE],["L1 / Q · Guard","guard",Color.WHITE],["R1 / R · Heavy","heavy_punch",Color.WHITE],["H · Fold arms","fold_arms",Color.WHITE]]
	for item in layout:
		var button := Button.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color",item[2])
		button.set_meta("control_action",item[1])
		button.button_down.connect(func(): Input.action_press(String(button.get_meta("control_action"))))
		button.button_up.connect(func(): Input.action_release(String(button.get_meta("control_action"))))
		action_buttons.append(button)
		row.add_child(button)
	var character_button := Button.new()
	character_button.text = "C · Characters"
	character_button.focus_mode = Control.FOCUS_NONE
	character_button.pressed.connect(player.party.toggle_wheel)
	row.add_child(character_button)
	var hint := Label.new()
	hint.text = "GTA-style: △ / E / F interact or enter/exit · □ / Space jump · ○ / left mouse punch · × / Shift run · L1 guard · R1 heavy · right mouse look · B camera"
	hint.add_theme_font_size_override("font_size",13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	help_widgets.append(hint)
	var sound := CheckButton.new()
	voice_toggle = sound
	sound.text = "Voices on · click the game once to enable browser sound"
	sound.button_pressed = true
	sound.focus_mode = Control.FOCUS_NONE
	sound.toggled.connect(func(enabled):
		if is_instance_valid(player.party):
			player.party.voices_enabled = enabled
			if not enabled and is_instance_valid(player.party.game.cabs):
				for car in player.party.game.cabs.cars:
					car.node.get_node("CabDialogue").voice.stop()
		for person in get_tree().get_nodes_in_group("people"):
			person.dialogue.muted = not enabled
			if not enabled:
				person.dialogue.voice.stop()
				person.dialogue._release_slot())
	rows.add_child(sound)
	help_widgets.append(sound)
	for widget in help_widgets: widget.hide()
	var toggle:=Button.new(); toggle.text="Controls"; toggle.focus_mode=Control.FOCUS_NONE
	rows.add_child(toggle)
	toggle.pressed.connect(func():
		expanded=not expanded
		for widget in help_widgets: widget.visible=expanded
		panel.size=Vector2.ZERO
		toggle.text="Hide controls" if expanded else "Controls")

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.controlled: return
	var control_mode := "driving" if player.driving else "foot"
	if control_mode != last_control_mode:
		last_control_mode = control_mode
		var labels := [[ "△ / E / F · Exit vehicle", "interact" ], [ "R2 / W · Accelerate", "accelerate" ], [ "L2 / S · Brake / reverse", "reverse" ], [ "× / Space · Handbrake", "handbrake" ], [ "B / R3 · Camera", "cycle_camera" ], [ "L1 · Guard", "guard" ], [ "R1 · Heavy", "heavy_punch" ]] if player.driving else [[ "△ / E / F · Interact", "interact" ], [ "□ / Space · Jump", "jump" ], [ "○ / Mouse · Punch", "punch" ], [ "× / Shift · Run", "sprint" ], [ "L1 / Q · Guard", "guard" ], [ "R1 / R · Heavy", "heavy_punch" ], [ "H · Fold arms", "fold_arms" ]]
		for i in range(mini(action_buttons.size(), labels.size())):
			action_buttons[i].text = labels[i][0]
			action_buttons[i].set_meta("control_action", labels[i][1])
	var viewport := get_viewport().get_visible_rect().size
	var left := 290.0 if viewport.x>=900 else 20.0
	panel.size.x = maxf(440,viewport.x-left-20) if expanded else 240
	panel.position = Vector2(290,viewport.y-panel.size.y-160)
	panel.visible=expanded
	status.hide()
	health_bar.hide()
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
