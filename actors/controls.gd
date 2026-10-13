extends CanvasLayer
## Keyboard, touch and standardized gamepad actions use the same InputMap.
var status: Label
var player: Node3D
static func bind() -> void:
	var keys := {"punch": KEY_F,"heavy_punch": KEY_R,"guard": KEY_Q,"cancel_action": KEY_G,"look_modifier": KEY_Z,"sprint": KEY_SHIFT}
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
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20,-108)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	status = Label.new()
	status.add_theme_font_size_override("font_size",16)
	rows.add_child(status)
	var row := HBoxContainer.new()
	rows.add_child(row)
	var layout := [["△ E · Use","interact",Color("7ee0b1")],["□ F · Punch","punch",Color("eda5df")],["✕ Space · Jump","jump",Color("8bbaff")],["○ G · Stand / Wake","cancel_action",Color("f59a98")],["L1 Q · Guard","guard",Color.WHITE],["R1 R · Heavy","heavy_punch",Color.WHITE]]
	for item in layout:
		var button := Button.new()
		button.text = item[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_color_override("font_color",item[2])
		button.button_down.connect(func(): Input.action_press(item[1]))
		button.button_up.connect(func(): Input.action_release(item[1]))
		row.add_child(button)
	var hint := Label.new()
	hint.text = "WASD / left stick: move   Shift / L3: run   L2 Z: focus   R2 V: punch   right stick / right mouse: look"
	hint.add_theme_font_size_override("font_size",13)
	rows.add_child(hint)

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		status.text = "NOTTINGHAM CITY  ·  Health %d / 100  ·  %s" % [player.health,player.resting.capitalize() if player.resting != "" else ("Guarding" if player.guarding else "Free roam")]
