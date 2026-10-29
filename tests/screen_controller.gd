extends SceneTree
var failed:=false
func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST","1"); call_deferred("run")
func check(value: bool, reason: String) -> void:
	if not value: failed=true; push_error(reason)
func aim(menu: RefCounted, control: Control) -> void:
	menu.screen_point=(control.get_global_transform_with_canvas()*(control.size*.5))/root.get_visible_rect().size
func run() -> void:
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate(); root.add_child(game)
	game.economy.enabled=false; game.cabs.set_physics_process(false); game.helicopters.set_physics_process(false)
	for person in game.party.members+game.population.residents: person.set_physics_process(false)
	var link: Node
	var hud: Node
	for child in game.get_children():
		if child.get_script()==null: continue
		if child.get_script().resource_path=="res://phone/phone_link.gd": link=child
		if child.get_script().resource_path=="res://actors/city_hud.gd": hud=child
	for i in range(4): await process_frame
	var menu=link.remote
	link._on_message([JSON.stringify({"t":"link","up":true})])
	menu.set_screen(true)
	check(menu.context()=="screen" and game.get_meta("controller_screen_mode",false),"Screen selection blocks movement and displays a game-side pointer")
	aim(menu,hud.shortcuts.get_child(0)); menu.confirm()
	check(game.phone.panel.visible,"A screen-pointer click activates the real HUD Phone button")
	for i in range(3): await process_frame
	game.phone.open_app("destinations")
	for i in range(3):await process_frame
	var search:LineEdit=game.phone.apps.search
	aim(menu,search); menu.confirm()
	check(menu.context()=="text","Selecting the app search opens only that field's controller keyboard")
	var serial:int=menu.text_serial
	menu.command({"action":"text_input","id":serial-1,"value":"Wrong stale input"})
	check(search.text=="","Stale keyboard submissions cannot change a different field")
	menu.command({"action":"text_input","id":serial,"value":"Station"})
	check(search.text=="Station" and menu.context()=="screen","Text goes to the selected game field and returns to its pointer")
	check(game.phone.apps.results.get_child_count()<=8,"Address search creates a bounded result list")
	for i in range(3):await process_frame
	var result:Button=game.phone.apps.results.get_child(0)
	aim(menu,result);menu.confirm()
	check(game.phone.apps.page=="book" and game.phone.selected_location.name.contains("Station"),"Selecting a visible search result chooses its real map destination")
	game.phone.open_app("account")
	for i in range(3):await process_frame
	menu.scroll_screen(180)
	for i in range(3):await process_frame
	aim(menu,game.phone.apps.account_code);menu.confirm()
	check(menu.context()=="text" and menu.state().entry.secret and menu.state().entry.value=="","Private code entry is masked on the controller link")
	menu.command({"action":"back"});menu.command({"action":"play"})
	# A confirm held across closing a menu must not become sprint or vehicle handbrake.
	menu.command({"action":"phone"}); menu.focus_id=""; menu.focus_menu()
	link.apply_state({"x":0,"y":0,"b":["CROSS"]})
	menu.command({"action":"play"}); link._apply_actions()
	check(not Input.is_action_pressed("sprint") and not Input.is_action_pressed("handbrake"),"Menu confirmation cannot leak into play")
	link.apply_state({"x":0,"y":0,"b":[]}); link.apply_state({"x":0,"y":-1,"b":["CROSS"]})
	check(Input.is_action_pressed("walk_forward") and Input.is_action_pressed("sprint"),"Fresh controls resume normal gameplay after release")
	var before: Vector3=game.player.global_position
	game.player.set_physics_process(true)
	for i in range(18):
		link.apply_state({"x":0,"y":-1,"b":[]})
		await physics_frame
	check(game.player.global_position.distance_to(before)>.3,"The character actually moves again after menu selection")
	game.player.set_physics_process(false)
	link._release_all(); game.helicopters.cancel(game.player)
	# Direct pointer access to the minimap and scroll controls is game-side only.
	menu.set_screen(true); menu.screen_point=(game.city_map.get_global_transform_with_canvas()*(game.city_map.size*.5))/root.get_visible_rect().size; menu.confirm()
	check(game.city_map.expanded,"Pointer can open the real minimap")
	menu.move_screen(Vector2(-4,4)); check(menu.screen_point.x>=0 and menu.screen_point.y<=1,"Cursor stays inside every viewport size")
	menu.command({"action":"back"}); check(not menu.screen_mode and game.city_map.expanded,"Pointer mode can be exited while keeping the current game screen")
	menu.command({"action":"back"})
	menu.set_screen(true); game.phone.panel.show(); menu.command({"action":"play"})
	check(menu.context()=="play" and not game.phone.panel.visible,"Return to play closes both cursor mode and its underlying game menu")
	menu.set_screen(true); link.connected=true; link._process(1.1)
	check(not menu.screen_mode and not game.get_meta("controller_screen_mode",true),"Lost signal releases the screen cursor instead of trapping the player")
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false): audio.stop();audio.stream=null
	game.queue_free(); await process_frame
	if not failed: print("SCREEN_CONTROLLER_OK: actual HUD selection, bounded address search, private text entry, map, input release and playable recovery")
	quit(1 if failed else 0)
