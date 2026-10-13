extends Control
## Four quarter-circle wedges, drawn and hit-tested from the same angles.
var party: Node
var highlight := 0
var center := Vector2.ZERO
var radius := 185.0
var text_font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	text_font = ThemeDB.fallback_font
	hide()

func _process(_delta: float) -> void:
	if not visible:
		return
	center = get_viewport_rect().size/2
	radius = minf(185,minf(get_viewport_rect().size.x,get_viewport_rect().size.y)*0.30)
	queue_redraw()

func sector_at(point: Vector2) -> int:
	var offset := point-center
	if offset.length() < 36 or offset.length() > radius:
		return -1
	return int(floor(wrapf(offset.angle()+PI/2,0,TAU)/(PI/2)))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var index := sector_at(event.position)
		if index >= 0:
			highlight = index
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var index := sector_at(event.position)
		if index >= 0:
			party.choose(index)
		accept_event()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("character_wheel"):
		party.toggle_wheel()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
			party.choose(event.physical_keycode-KEY_1)
		elif event.physical_keycode in [KEY_ESCAPE,KEY_G]:
			hide()
		elif event.physical_keycode == KEY_ENTER:
			party.choose(highlight)
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:
		var direction := Vector2(Input.get_joy_axis(event.device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(event.device,JOY_AXIS_RIGHT_Y))
		if direction.length() > 0.3:
			highlight = sector_at(center+direction.normalized()*radius*0.7)
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			party.choose(highlight)
		elif event.button_index == JOY_BUTTON_B:
			hide()
		get_viewport().set_input_as_handled()

func label(text: String, point: Vector2, font_size: int, colour := Color.WHITE) -> void:
	draw_string(text_font,point-Vector2(text_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,colour)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,get_viewport_rect().size),Color(0.025,0.045,0.065,0.87))
	label("CHOOSE YOUR CHARACTER",center-Vector2(0,radius+48),26)
	for i in range(4):
		var start := -PI/2+i*PI/2
		var points := PackedVector2Array([center])
		for j in range(25):
			points.append(center+Vector2.from_angle(start+j*PI/48)*radius)
		var colour: Color = party.PROFILES[i].colour
		draw_colored_polygon(points,colour.darkened(0.18 if i == highlight else 0.70))
		draw_polyline(points,Color(0.9,0.94,0.98,0.65),2)
		var location := center+Vector2.from_angle(start+PI/4)*radius*0.6
		label(party.PROFILES[i].name,location,22)
		label("%d · %d health" % [i+1,party.members[i].health],location+Vector2(0,28),14)
	draw_circle(center,36,Color("132431"))
	label("C",center+Vector2(0,9),26)
	label("Click a wedge or press 1–4 · Enter confirms · C / Esc closes",center+Vector2(0,radius+38),16)
