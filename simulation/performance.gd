extends Node
# Graphics quality changes rendering cost, never traffic rules or financial simulation.
var mode := 0
var show_fps := false
var clock := 0.0
var resolution_clock := 0.0
var warmup := 3.0
var overlay: Label
const TITLES := ["Smooth • lighter graphics","Balanced","Sharp • more detail"]
func _ready() -> void:
	name = "Performance"
	var config := ConfigFile.new()
	if not OS.has_environment("NOTTINGHAM_TEST") and config.load("user://city-performance.cfg")==OK:
		mode = clampi(int(config.get_value("graphics","mode",0)),0,2)
		show_fps = bool(config.get_value("graphics","fps",false))
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	overlay = Label.new()
	overlay.position = Vector2(20,65)
	overlay.add_theme_font_size_override("font_size",16)
	layer.add_child(overlay)
	apply(mode,false)
func apply(value: int, persist := true) -> void:
	mode = clampi(value,0,2)
	warmup=3.0
	resolution_clock=0.0
	get_viewport().scaling_3d_scale = [0.75,1.0,1.0][mode]
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][mode]
	if persist: _save()
func set_fps(value: bool) -> void:
	show_fps=value
	_save()
func _save() -> void:
	if OS.has_environment("NOTTINGHAM_TEST"): return
	var config := ConfigFile.new()
	config.set_value("graphics","mode",mode)
	config.set_value("graphics","fps",show_fps)
	config.save("user://city-performance.cfg")
func adjust_resolution(fps: float) -> void:
	if mode!=0 or fps<=0: return
	var scale: float=get_viewport().scaling_3d_scale
	if fps<28: scale=maxf(.55,scale-.05)
	elif fps>48: scale=minf(.75,scale+.025)
	get_viewport().scaling_3d_scale=scale

func _process(delta: float) -> void:
	warmup=maxf(0,warmup-delta)
	resolution_clock+=delta
	if warmup<=0 and resolution_clock>=1.5:
		resolution_clock=0
		adjust_resolution(Engine.get_frames_per_second())
	clock+=delta
	if clock<0.5: return
	clock=0
	overlay.visible=show_fps
	if show_fps: overlay.text="%d FPS • %s • %d%% 3D" % [Engine.get_frames_per_second(),["Smooth","Balanced","Sharp"][mode],roundi(get_viewport().scaling_3d_scale*100)]
