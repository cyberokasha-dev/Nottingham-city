extends Control
# The cursor is drawn in the game. The phone only supplies relative movement.
var remote: RefCounted
var background:StyleBoxFlat
func _ready() -> void:
	background=StyleBoxFlat.new(); background.bg_color=Color(.03,.09,.14,.94); background.set_corner_radius_all(6)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(_delta: float) -> void:
	visible=remote.screen_mode and remote.context()=="screen"
	if visible: queue_redraw()
func _draw() -> void:
	var p: Vector2=remote.screen_point*get_viewport_rect().size
	var arrow:=PackedVector2Array([p,p+Vector2(0,23),p+Vector2(6,17),p+Vector2(12,28),p+Vector2(17,25),p+Vector2(11,15),p+Vector2(21,15),p])
	draw_colored_polygon(arrow,Color.WHITE); draw_polyline(arrow,Color("123044"),2,true)
	var caption:="SCREEN CURSOR   Cross: select   Circle: back   Stick / touchpad: move" if get_viewport_rect().size.x>=900 else "CURSOR   Cross: select   Circle: back"
	var font:=ThemeDB.fallback_font
	var extent:=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
	var origin:=Vector2((get_viewport_rect().size.x-extent.x)*.5,32)
	draw_style_box(background,Rect2(origin-Vector2(12,20),extent+Vector2(24,14)))
	draw_string(font,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)