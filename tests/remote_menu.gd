extends SceneTree
var failed:=false
func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST","1")
	call_deferred("run")
func check(value:bool,message:String) -> void:
	if not value: failed=true; push_error(message)
func run() -> void:
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled=false
	game.cabs.set_physics_process(false)
	game.helicopters.set_physics_process(false)
	game.get_node("StreetEvents").set_physics_process(false)
	for member in game.party.members: member.set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var link:Node
	for child in game.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://phone/phone_link.gd": link=child
	var menu=link.remote
	check(not menu.state().has("rows") and not menu.state().has("map"),"Controller receives no game menus or duplicate atlas")
	link._on_message([JSON.stringify({"t":"link","up":true})])
	link._on_message([JSON.stringify({"t":"cmd","seq":1,"action":"phone"})])
	check(game.phone.panel.visible,"Paired command opens phone on game screen")
	check(not game.phone.passenger_name.visible and not game.phone.service_picker.visible,"No name or service form is required")
	check(game.phone.apps.page=="home" and menu.focus_id==str(game.phone.apps.default_button.get_instance_id()),"Phone opens its app grid with Book selected")
	menu.navigate("down")
	check(game.phone.apps.home.get_child(3).has_focus(),"Down moves one row on the three-column app grid")
	menu.navigate("up");menu.confirm()
	check(game.phone.apps.page=="book" and menu.focus_id==str(game.phone.apps.book_grid.get_child(0).get_instance_id()),"Book focuses the first of four large transport choices")
	menu.confirm()
	check(game.phone.apps.page=="book_ticket","Choosing a vehicle opens only single/day tickets")
	link.apply_state({"x":0,"y":0,"b":["CROSS"]})
	var key:String=game.economy.key_for(game.player)
	check(game.cabs.bookings.has(key),"Cross confirms a single Cybercab ticket and dispatches it")
	check(game.cabs.bookings[key].passenger_name==game.player.profile.name,"Booking uses active character's name")
	link.apply_state({"x":0,"y":0,"b":[]})
	check(not Input.is_action_pressed("sprint") and not Input.is_action_pressed("punch"),"Confirmation cannot move or attack")
	if game.cabs.bookings.has(key):
		var trip:Dictionary=game.cabs.bookings[key]
		var car:Dictionary=game.cabs.cars[int(trip.car)]
		car.node.position=trip.pickup_curb
		car.state="waiting";trip.state="waiting"
		game.player.position=game.cabs.boarding_point(game.player)
		var balance:int=game.economy.cash(game.player)
		game.economy.account_for(game.player).balance=0
		check(not game.cabs.board_near(game.player),"Quick booking retains sufficient-fare check")
		game.economy.account_for(game.player).balance=balance
		trip=game.cabs.book(game.player)
		car=game.cabs.cars[int(trip.car)]
		car.node.position=trip.pickup_curb
		car.state="waiting";trip.state="waiting"
		game.player.position=game.cabs.boarding_point(game.player)
		check(game.cabs.board_near(game.player),"Quick booking boards nearby and charges once")
		for i in range(35):game.cabs._physics_process(.1)
		check(game.cabs.leave_waiting(game.player),"Unused ride can still be refunded")
	# Tabs, dropdowns, map selection and character changes operate on the game screen.
	game.phone.apps.open("book")
	for app in ["rents","jobs","wallet","passes"]:
		menu.select_tab(1)
		check(game.phone.apps.page==app,"Shoulder selects phone app "+app)
	game.phone.panel.hide()
	game.city_map.open(true)
	game.city_map._layout()
	var uv:Vector2=(game.city_map.point(game.economy.office)-game.city_map.map_rect.position)/game.city_map.map_rect.size
	menu.map_cursor=uv
	menu.confirm()
	check(game.phone.panel.visible and game.phone.selected_location.name=="Council Office","Map confirm selects an actual destination for booking")
	menu.command({"action":"play"})
	menu.command({"action":"characters"})
	menu.navigate("right");menu.navigate("right");menu.confirm()
	check(game.player.profile.name=="Musa" and not game.party.wheel.visible,"Direction and confirm switch character")
	for i in range(3):await process_frame
	var hud:Node
	for child in game.get_children():
		if child.get_script()!=null and child.get_script().resource_path=="res://actors/city_hud.gd":hud=child
	check(hud!=null,"Unified city HUD exists")
	if hud!=null:
		hud._process(.3)
		check(hud.health.position.x==20 and hud.health.position.y>root.size.y-60,"Health sits at bottom left under the minimap")
		check(hud.wallet.position.x>root.size.x/2,"Pounds are at the top right")
		check(hud.character_buttons[0].position.x>root.size.x/2,"Character display is at bottom right")
	link.apply_state({"x":0,"y":-1,"b":["R2"]})
	link._process(1.1)
	check(not Input.is_action_pressed("accelerate"),"Signal timeout releases driving")
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):audio.stop();audio.stream=null
	await create_timer(.2).timeout
	game.queue_free();await process_frame
	if not failed:print("REMOTE_MENU_OK: screen-only menus, direct booking, native navigation, map, character and HUD placement")
	quit(1 if failed else 0)
