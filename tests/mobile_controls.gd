extends SceneTree
var failed:=false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1");seed(12345);call_deferred("run")
func check(value:bool,message:String):
	if not value:failed=true;push_error(message)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);game.economy.enabled=false
	var touch:Node
	for node in game.get_children():
		if node.get_script()==preload("res://phone/mobile_controls.gd"):touch=node
	check(touch!=null,"Local touch bridge is part of the real city")
	check(not touch.enabled,"Desktop/native tests do not get phone overlays")
	touch.enable_phone()
	touch.apply_state({"x":0.35,"y":0,"b":[]})
	check(Input.get_vector("walk_left","walk_right","walk_forward","walk_back").x>0.2,"Small thumb movements use the analog stick rather than a desktop half-stick dead zone")
	touch.release()
	root.content_scale_size=Vector2i(390,844);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_IGNORE
	for i in range(10):await process_frame
	var p=game.player
	var start:Vector3=p.position
	touch.apply_state({"x":0,"y":-1,"b":["CROSS"]})
	for i in range(30):await physics_frame
	check(p.position.distance_to(start)>1,"Phone stick and run move the real character")
	touch.release()
	check(not Input.is_action_pressed("walk_forward") and not Input.is_action_pressed("sprint"),"Releasing local touches stops all owned actions")
	touch.apply_state({"x":.8,"y":0,"b":["R2"]})
	check(Input.get_action_strength("turn_right")>.7 and Input.is_action_pressed("accelerate"),"Steering and accelerator work simultaneously")
	touch.apply_state({"x":.8,"y":0,"b":[]})
	check(Input.get_action_strength("turn_right")>.7 and not Input.is_action_pressed("accelerate"),"Lifting the accelerator preserves the other finger's steering")
	touch.link.remote.command({"action":"phone"});touch._process(.1)
	check(not Input.is_action_pressed("turn_right"),"Opening a menu releases vehicle inputs")
	touch.apply_state({"x":1,"y":-1,"b":["R2"]})
	check(not Input.is_action_pressed("accelerate"),"Menus cannot leak touch actions into vehicles")
	for viewport in [Vector2i(390,844),Vector2i(844,390),Vector2i(360,740)]:
		root.content_scale_size=viewport
		for i in range(12):await process_frame
		var phone=game.phone
		check(phone.panel.scale==Vector2.ONE,"Phone menus retain normal text size in both orientations")
		check(phone.panel.size.x<=viewport.x-20 and phone.panel.size.y<=viewport.y-20,"Phone menu stays inside the usable display")
		check(phone.apps.home.get_child(0).size.y>=44,"Phone app targets remain at least 44 pixels tall")
	game.phone.panel.hide();touch._process(.1)
	game.conversation.panel.show();game.conversation._process(0)
	check(game.conversation.panel.size.x<=root.content_scale_size.x-20,"Conversation replies also fit a narrow phone")
	game.conversation.panel.hide()
	var yaw:float=p.yaw
	var drag:=InputEventScreenDrag.new();drag.relative=Vector2(30,0);touch._unhandled_input(drag)
	check(p.yaw<yaw,"Dragging the unobstructed game screen rotates the camera")
	touch.apply_state({"x":-1,"y":0,"b":["L2"]});touch._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not Input.is_action_pressed("reverse") and not Input.is_action_pressed("turn_left"),"Backgrounding clears held pedals and movement")
	game.queue_free();await process_frame
	if not failed:print("MOBILE_CONTROLS_OK: real movement, multitouch action ownership, normal-size responsive menus, camera drag and focus cleanup")
	quit(1 if failed else 0)
