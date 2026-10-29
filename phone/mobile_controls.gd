extends Node
## Local phone play uses the existing actions and menus without a second device.
const LINK = preload("res://phone/phone_link.gd")
var game: Node
var link: Node
var enabled := false
var bridge: JavaScriptObject
var callback: JavaScriptObject
var pressed := {}
var clock := 0.0
var idle := 0.0
var context := "play"

func _ready() -> void:
	if not OS.has_feature("web"): return
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://phone/mobile_controls.js"),true)
	bridge=JavaScriptBridge.get_interface("NottCityTouch")
	if bridge==null: return
	enabled=bool(bridge.enabled)
	if not enabled: return
	enable_phone()
	callback=JavaScriptBridge.create_callback(_message)
	bridge.setCallback(callback)
	_publish()

func enable_phone() -> void:
	enabled=true
	game.set_meta("phone_touch",true)
	# Walking actions were created with a desktop default of 0.5. A short thumb
	# movement should start walking rather than losing half the stick's travel.
	for action in ["walk_left","walk_right","walk_forward","walk_back"]:
		InputMap.action_set_deadzone(action,LINK.STICK_DEADZONE)

func _message(args: Array) -> void:
	if not enabled or args.is_empty(): return
	var data=JSON.parse_string(str(args[0]))
	if not data is Dictionary: return
	match str(data.get("t","")):
		"state": apply_state(data)
		"command":
			release()
			link.remote.command(data)
			_publish()
		"resize":
			var width:=clampi(int(data.get("width",390)),240,2400)
			var height:=clampi(int(data.get("height",844)),240,2400)
			var safe:Array=data.get("safe",[0,0,0,0])
			if safe.size()==4:game.set_meta("phone_safe",Vector4(float(safe[0]),float(safe[1]),float(safe[2]),float(safe[3])))
			get_tree().root.content_scale_size=Vector2i(width,height)
			get_tree().root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
			_publish()
		"look": link._apply_look(Vector2(float(data.get("x",0)),float(data.get("y",0))))

func apply_state(data: Dictionary) -> void:
	idle=0
	if not enabled or link.remote.context()!="play": release(); return
	var v:=Vector2(clampf(float(data.get("x",0)),-1,1),clampf(float(data.get("y",0)),-1,1)).limit_length()
	if v.length()<LINK.STICK_DEADZONE: v=Vector2.ZERO
	var strengths:={"walk_left":maxf(0,-v.x),"walk_right":maxf(0,v.x),"walk_forward":maxf(0,-v.y),"walk_back":maxf(0,v.y),"turn_left":maxf(0,-v.x),"turn_right":maxf(0,v.x)}
	# Steering alone never accelerates a vehicle: each pedal has its own finger.
	for button in data.get("b",[]):
		for action in LINK.BUTTON_ACTIONS.get(str(button),[]): strengths[action]=1.0
	for action in LINK.MANAGED_ACTIONS:
		var strength:float=strengths.get(action,0)
		if strength>0: Input.action_press(action,strength); pressed[action]=true
		elif pressed.has(action): Input.action_release(action); pressed.erase(action)

func release() -> void:
	for action in pressed: Input.action_release(action)
	pressed.clear()

func _unhandled_input(event: InputEvent) -> void:
	if enabled and event is InputEventScreenDrag and link.remote.context()=="play":
		link._apply_look(event.relative)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: release()

func _process(delta: float) -> void:
	if not enabled: return
	idle+=delta
	if idle>1: release()
	var next:String=link.remote.context()
	if next!=context: release(); context=next; _publish()
	clock+=delta
	if clock>=0.1: clock=0; _publish()

func _publish() -> void:
	if bridge==null: return
	var data:Dictionary=link.remote.state()
	var p=game.player
	data.position=[p.position.x,p.position.z]
	data.viewport=[get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]
	data.yaw=p.yaw
	data.speed=Vector2(p.velocity.x,p.velocity.z).length()
	data.page=game.phone.apps.page if game.phone.panel.visible else ""
	data.prompt=p.prompt.text
	data.wallet=game.economy.pounds(game.economy.cash(p))
	data.health=p.health
	bridge.update(JSON.stringify(data))

func _exit_tree() -> void:
	release()
