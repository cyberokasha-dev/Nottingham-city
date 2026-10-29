extends CanvasLayer
var game: Node3D
var apps:RefCounted
var panel: PanelContainer
var summary: Label
var cab_status: Label
var message: Label
var destinations: OptionButton
var search: LineEdit
var pin: LineEdit
var properties: OptionButton
var job_options: OptionButton
var council: RichTextLabel
var filtered: Array[Dictionary] = []
var offers: Array[int] = []
var refresh_clock := 0.0
var tabs: TabContainer
var conversation: Label
var rent_button: Button
var selected_house := 0
var name_owner := ""
var passenger_name: LineEdit
var selected_location: Dictionary = {}
var unlock_button: Button
var confirm_button: Button
var book_button: Button
var service_picker: OptionButton
var cancel_button: Button
var leave_button: Button
var skip_button: Button
var altitude_hud: Button
var altitude_button: Button
var speed_button: Button
var drive_button: Button
var speed_hud: Button
var drive_hud: Button
var pass_status: Label
var pass_button: Button
var pass_code: LineEdit
var mobile_scroll: ScrollContainer
var topics: HBoxContainer

func _ready() -> void:
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(25,55)
	panel.custom_minimum_size = Vector2(460,480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d28")
	style.set_corner_radius_all(12)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var header := HBoxContainer.new()
	rows.add_child(header)
	var title := Label.new()
	title.text = "CITY PHONE"
	title.add_theme_font_size_override("font_size",23)
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): panel.hide(); _release_focus())
	header.add_child(close)
	summary = _label(rows,"")
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(450,330)
	rows.add_child(tabs)
	var cab := _tab(tabs,"Travel")
	service_picker=OptionButton.new()
	service_picker.add_item("Helicopter • fly above traffic")
	service_picker.add_item("Aurora cab • road travel")
	service_picker.add_item("Robovan • electric shuttle")
	service_picker.item_selected.connect(func(_index): update_display())
	cab.add_child(service_picker)
	service_picker.hide()
	passenger_name=LineEdit.new()
	passenger_name.placeholder_text="Passenger name"
	passenger_name.text=game.player.profile.name
	passenger_name.max_length=28
	name_owner=game.player.profile.name
	cab.add_child(passenger_name)
	passenger_name.hide()
	search=LineEdit.new()
	search.placeholder_text="Find a house, street, stop or helipad"
	search.text_changed.connect(func(_text): _locations())
	cab.add_child(search)
	destinations=OptionButton.new()
	destinations.item_selected.connect(func(index):
		selected_location=filtered[index-1].duplicate() if index>0 else {}
		update_display())
	cab.add_child(destinations)
	_button(cab,"Choose on map • N",func(): panel.hide(); game.city_map.open(true))
	cab_status=_label(cab,"")
	book_button=_button(cab,"Call helicopter • pickup here",func():
		service_picker.select(0)
		request_ride())
	book_button.set_meta("quick_booking",true)
	book_button.set_meta("service",0)
	var aurora_call=_button(cab,"Call Aurora • pickup here",func():
		service_picker.select(1)
		request_ride())
	aurora_call.set_meta("quick_booking",true)
	aurora_call.set_meta("service",1)
	var van_call=_button(cab,"Call Robovan • pickup here",func():
		service_picker.select(2)
		request_ride())
	van_call.set_meta("quick_booking",true);van_call.set_meta("service",2)
	unlock_button=_button(cab,"Board and go",func():
		var ride=ride_service()
		if selected_location.has("point") and not ride.choose_destination(game.player,selected_location):
			show_message(game.economy.last_error); return
		if ride.board_near(game.player):
			panel.hide(); _release_focus()
		else: show_message(game.economy.last_error if game.economy.last_error!="" else "Wait for arrival and walk beside your assigned vehicle.")
		update_display())
	confirm_button=_button(cab,"Go to selected destination",func():
		if ride_service().choose_destination(game.player,selected_location): panel.hide(); _release_focus()
		else: show_message(game.economy.last_error)
		update_display())
	cancel_button=_button(cab,"Cancel pickup",func():
		show_message("Pickup cancelled" if ride_service().cancel(game.player) else "This ride cannot be cancelled now.")
		update_display())
	leave_button=_button(cab,"Leave parked vehicle • refund",func():
		show_message("Unused ride refunded" if ride_service().leave_waiting(game.player) else "Wait until the vehicle is parked.")
		update_display())
	skip_button=_button(cab,"Skip journey",func():
		show_message("Arrived" if ride_service().skip_journey(game.player) else "Wait until your journey starts.")
		update_display())
	altitude_button=_button(cab,"Fly higher",func():
		var key:String=game.economy.key_for(game.player)
		if not game.helicopters.bookings.has(key): return
		var trip:Dictionary=game.helicopters.bookings[key]
		var aircraft:Dictionary=game.helicopters.cars[int(trip.car)]
		game.helicopters.set_high_flight(game.player,not aircraft.high_flight)
		update_display())
	speed_button=_button(cab,"Travel faster",_toggle_speed)
	drive_button=_button(cab,"Drive myself",_toggle_driving)
	pass_status=_label(cab,"")
	pass_button=_button(cab,"Buy 24-hour pass • £25",func():
		show_message("Pass saved. Your code covers trains, Aurora, Robovan and helicopters for 24 real hours." if game.economy.buy_day_pass(game.player) else game.economy.last_error)
		update_display())
	pass_code=LineEdit.new()
	pass_code.placeholder_text="Your saved travel pass code"
	pass_code.max_length=6
	cab.add_child(pass_code)
	_button(cab,"Check pass code",func():
		show_message("Pass accepted • used automatically when boarding all three services." if game.economy.validate_pass_code(game.player,pass_code.text) else game.economy.last_error))
	pin=LineEdit.new()
	pin.hide()
	cab.add_child(pin)
	conversation=_label(cab,"")
	topics=HBoxContainer.new()
	cab.add_child(topics)
	for item in [["Traffic","traffic"],["Local places","area"],["Help","help"],["Quiet please","quiet"]]:
		_button(topics,item[0],func(): game.cabs.talk(game.player,item[1]))
	var housing := _tab(tabs,"Housing")
	_label(housing,"Council homes • £400/month • visit a front door to rent\nSelect a home to mark its entrance. Confirm rent when you arrive.")
	properties = OptionButton.new()
	housing.add_child(properties)
	properties.item_selected.connect(func(index):
		if index>=0 and index<offers.size():
			selected_house = offers[index]
			game.city_map.set_waypoint({"name":game.economy.houses[selected_house].address,"point":game.economy.houses[selected_house].entrance()}))
	_button(housing,"Visit selected home • show walking destination",func():
		if not offers.is_empty(): _navigate(game.economy.houses[offers[properties.selected]].entrance()))
	_button(housing,"Book Aurora to selected home",func():
		if offers.is_empty(): return
		var house: Node3D = game.economy.houses[offers[properties.selected]]
		var trip: Dictionary = game.cabs.book(game.player,{"name":house.address,"point":house.entrance()})
		tabs.current_tab = 0
		show_message("Aurora booked to "+house.address if not trip.is_empty() else game.economy.last_error))
	_button(housing,"Confirm £400 first month • at the front door",func():
		if offers.is_empty(): return
		var number: int = offers[properties.selected]
		if game.player.global_position.distance_to(game.economy.houses[number].entrance())>3:
			show_message("Visit this home's front door to confirm the tenancy. Use Visit selected home for directions.")
			return
		show_message("You now rent house "+str(number) if game.economy.rent(game.player,number) else game.economy.last_error)
		apps.history.clear();apps.open("home",false)
		_offers()
		update_display())
	_button(housing,"Pay overdue rent",func(): show_message("Rent arrears paid" if game.economy.pay_rent(game.player) else game.economy.last_error))
	_button(housing,"Navigate to my house",func():
		var account: Dictionary = game.economy.account_for(game.player)
		if game.economy.houses.has(int(account.house)):
			_navigate(game.economy.houses[int(account.house)].entrance()))
	var jobs := _tab(tabs,"Jobs & Money")
	_label(jobs,"Visit the council office to apply. Attend your assignment for\n20 seconds to earn one wage per game day. 1 game day = 5 minutes.")
	job_options = OptionButton.new()
	for job in game.economy.JOBS:
		job_options.add_item(job+" • "+game.economy.pounds(game.economy.JOBS[job])+" / game day")
	jobs.add_child(job_options)
	_button(jobs,"Apply for selected job",func():
		var job: String = game.economy.JOBS.keys()[job_options.selected]
		show_message("Job accepted: "+job if game.economy.apply_job(game.player,job) else game.economy.last_error))
	_button(jobs,"Navigate to my work assignment",func():
		var task: Dictionary = game.economy.assignment(game.player)
		_navigate(game.economy.office if task.is_empty() else task.point))
	_button(jobs,"Borrow £500 from council",func(): show_message("£500 loan paid into your wallet" if game.economy.loan(game.player,50000) else game.economy.last_error))
	_button(jobs,"Repay £100 of council loan",func(): show_message("Loan repayment accepted" if game.economy.repay(game.player,10000) else game.economy.last_error))
	var finance := _tab(tabs,"Council")
	council = RichTextLabel.new()
	council.custom_minimum_size = Vector2(430,250)
	finance.add_child(council)
	_label(finance,"Public accounts • admin controls will be added later")
	var settings := _tab(tabs,"Settings")
	_label(settings,"Display, audio and controls")
	var quality := CheckButton.new()
	quality.text = "Shadows (slower) • off for Chromebook performance"
	quality.toggled.connect(func(value):
		for light in game.city.find_children("*","DirectionalLight3D",true,false):
			light.shadow_enabled = value)
	settings.add_child(quality)
	var graphics := OptionButton.new()
	for preset_title in game.performance.TITLES: graphics.add_item(preset_title)
	graphics.select(game.performance.mode)
	graphics.item_selected.connect(func(index): game.performance.apply(index))
	settings.add_child(graphics)
	var fps := CheckButton.new()
	fps.text = "Show frame rate"
	fps.button_pressed = game.performance.show_fps
	fps.toggled.connect(func(value): game.performance.set_fps(value))
	settings.add_child(fps)
	var voices := CheckButton.new()
	voices.text="Character voices"
	voices.button_pressed=game.party.voices_enabled
	voices.toggled.connect(func(value): game.player.controls.voice_toggle.button_pressed=value)
	settings.add_child(voices)
	_label(settings,"Menus: stick / arrows to move • × / Enter to select
○ / Esc back • L1 / R1 change apps • B camera")
	var sound := CheckButton.new()
	sound.text = "City sound on"
	sound.button_pressed = not AudioServer.is_bus_mute(0)
	sound.toggled.connect(func(value): AudioServer.set_bus_mute(0,not value))
	settings.add_child(sound)
	message = _label(rows,"City account • council rentals • pounds sterling")
	_locations()
	_offers()
	apps=preload("res://phone/city_apps.gd").new()
	apps.phone=self;apps.game=game;apps.build(rows,header)
	panel.hide()
	var open := Button.new()
	open.text = "P • Phone / Aurora / Money"
	open.position = Vector2(215,20)
	open.pressed.connect(toggle)
	add_child(open)
	open.hide()
	var camera_button := Button.new()
	camera_button.text = "B • Change camera"
	camera_button.position = Vector2(495,20)
	camera_button.focus_mode = Control.FOCUS_NONE
	camera_button.pressed.connect(func(): game.player.cycle_view())
	add_child(camera_button)
	camera_button.hide()
	var map_button := Button.new()
	map_button.text = "N • Map"
	map_button.position = Vector2(680,20)
	map_button.pressed.connect(func(): game.city_map.open())
	add_child(map_button)
	map_button.hide()
	var hail_button := Button.new()
	hail_button.text = "K • Call a ride"
	hail_button.position = Vector2(780,20)
	hail_button.pressed.connect(hail)
	add_child(hail_button)
	hail_button.hide()
	altitude_hud=Button.new()
	altitude_hud.text="Fly higher"
	altitude_hud.position=Vector2(20,155)
	altitude_hud.focus_mode=Control.FOCUS_NONE
	altitude_hud.pressed.connect(_toggle_altitude)
	add_child(altitude_hud)
	speed_hud=Button.new(); speed_hud.focus_mode=Control.FOCUS_NONE
	speed_hud.pressed.connect(_toggle_speed); add_child(speed_hud)
	drive_hud=Button.new(); drive_hud.focus_mode=Control.FOCUS_NONE
	drive_hud.pressed.connect(_toggle_driving); add_child(drive_hud)
	altitude_hud.hide()

func ride_service() -> Node3D:
	var key: String=game.economy.key_for(game.player)
	for ride in [game.helicopters,game.cabs]:
		if ride.bookings.has(key): return ride
	return game.helicopters if service_picker.selected==0 else game.cabs

func request_ride() -> void:
	var service:=ride_service()
	var trip:Dictionary=game.cabs.book(game.player,selected_location,game.player.profile.name,-1,"Robovan" if service_picker.selected==2 else "Aurora") if service==game.cabs else service.book(game.player,selected_location,game.player.profile.name)
	show_message("Pickup requested. Your vehicle number and meeting point are below and on the map." if not trip.is_empty() else game.economy.last_error)
	update_display()

func hail() -> void:
	game.city_map.close();panel.show();apps.open("book");update_display()

func try_open_near(person: Node3D) -> bool:
	var key: String=game.economy.key_for(person)
	for ride in [game.helicopters,game.cabs]:
		if ride.is_pickup_near(person):
			service_picker.select(0 if ride==game.helicopters else 1)
			panel.show(); apps.open("book"); update_display()
			return true
	if game.helicopters.bookings.has(key) or game.cabs.bookings.has(key): return false
	var nearest: Node3D
	var index:=-1
	var distance:=INF
	for ride in [game.helicopters,game.cabs]:
		var candidate: int=ride.nearest_available(person)
		if candidate>=0:
			var gap: float=person.global_position.distance_to(ride.cars[candidate].node.global_position)
			if gap<distance: distance=gap; nearest=ride; index=candidate
	if index<0: return false
	var trip: Dictionary=nearest.walk_up(person,index)
	if trip.is_empty(): return false
	service_picker.select(0 if nearest==game.helicopters else 1)
	panel.show(); apps.open("book"); update_display()
	show_message("Vehicle reserved. Choose a destination or choose later, then Board and go.")
	return true

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var tab := VBoxContainer.new()
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(tab)
	return tab

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func show_message(text: String) -> void:
	message.text = text
	update_display()

func open_app(name:String) -> void:
	apps.open(name)
	update_display()

func back_app() -> bool:
	var opened:bool=apps.back()
	if not opened:_release_focus()
	return opened

func preferred_focus() -> Control:return apps.preferred()

func toggle() -> void:
	panel.visible = not panel.visible
	game.player.hud.visible = not panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	game.player.controls.visible = not panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	if panel.visible:
		apps.history.clear();apps.open("home",false)
		game.city_map.close()
		game.party.wheel.hide()
		_offers()
		update_display()
	else:_release_focus()

func _locations() -> void:
	filtered.clear()
	destinations.clear()
	destinations.add_item("Destination: choose later, or select below")
	var ordered: Array = []
	for location in game.economy.locations:
		if not str(location.name).begins_with("House "): ordered.append(location)
	for location in game.economy.locations:
		if str(location.name).begins_with("House "): ordered.append(location)
	for location in ordered:
		if search.text.strip_edges()=="" or location.name.to_lower().contains(search.text.to_lower()):
			filtered.append(location)
			destinations.add_item(location.name)
	selected_location = {}
	_quote()

func _offers() -> void:
	offers.clear()
	properties.clear()
	for number in game.economy.houses:
		if str(game.economy.house_record(number).tenant)=="":
			offers.append(number)
			properties.add_item("House "+str(number)+" • "+game.economy.houses[number].street+" • £400/month")
	if selected_house in offers: properties.select(offers.find(selected_house))

func select_location(location: Dictionary) -> void:
	selected_location = location.duplicate()
	panel.show()
	apps.open("book")
	_quote()
	show_message("Selected: "+str(location.name)+". Call a ride, or confirm it for your parked vehicle.")

func _quote() -> void:
	if game.economy.has_day_pass(game.player):
		cab_status.text="Choose your destination or choose later. Your saved pass is used automatically at boarding."
		return
	var base: int=500 if ride_service()==game.helicopters else 300
	cab_status.text="Choose a destination, or choose later after boarding. From "+game.economy.pounds(base)+"."
	if selected_location.has("point"):
		cab_status.text=str(selected_location.name)+" • "+game.economy.pounds(ride_service().quote(game.player,selected_location.point))

func _navigate(point: Vector3) -> void:
	game.city_map.set_waypoint({"name":preload("res://town/districts.gd").street_at(point),"point":point})
	panel.hide()
	_release_focus()

func update_display() -> void:
	if name_owner!=game.player.profile.name:
		name_owner = game.player.profile.name
		passenger_name.text = name_owner
	var account: Dictionary = game.economy.account_for(game.player)
	summary.text = "%s • %s" % [game.player.profile.name,game.economy.pounds(int(account.balance))]
	var seconds_left: int=game.economy.pass_seconds_left(game.player)
	pass_status.text="24-hour pass • trains / Aurora / Robovan / helicopters\nCode %s • %dh %02dm left • saved on this device" % [str(game.economy.day_pass(game.player).get("code","")),seconds_left/3600,(seconds_left%3600)/60] if seconds_left>0 else "24-hour city travel • unlimited trains, Aurora, Robovan and helicopters"
	pass_button.disabled=seconds_left>0
	pass_button.text="24-hour pass active" if seconds_left>0 else "Buy 24-hour pass • £25"
	pass_code.hide()
	if seconds_left>0 and name_owner!=str(pass_code.get_meta("owner","")):
		pass_code.text=str(game.economy.day_pass(game.player).code)
		pass_code.set_meta("owner",name_owner)
	var key: String=game.economy.key_for(game.player)
	var ride=ride_service()
	var active: bool=ride.bookings.has(key)
	service_picker.disabled=active
	if active: service_picker.select(0 if ride==game.helicopters else (2 if ride.bookings[key].get("kind","Aurora")=="Robovan" else 1))
	passenger_name.editable=not active
	pin.hide()
	book_button.visible=not active
	for node in book_button.get_parent().get_children():
		if node is Button and node.has_meta("quick_booking"):
			node.visible=not active
			var service=game.helicopters if int(node.get_meta("service"))==0 else game.cabs
			var amount:int=service.quote(game.player,selected_location.point) if selected_location.has("point") else (500 if service==game.helicopters else 300)
			node.text=("Call helicopter" if service==game.helicopters else ("Call Robovan" if int(node.get_meta("service"))==2 else "Call Aurora"))+" • "+("Pass included" if seconds_left>0 else game.economy.pounds(amount))
	unlock_button.hide(); confirm_button.hide(); cancel_button.hide(); leave_button.hide(); skip_button.hide()
	topics.hide(); conversation.hide(); altitude_button.hide(); speed_button.hide(); drive_button.hide()
	if active:
		var trip: Dictionary=ride.bookings[key]
		passenger_name.text=trip.passenger_name
		var number: String=ride.cars[int(trip.car)].cab_id if int(trip.car)>=0 else "Dispatching"
		cab_status.text="%s • %s\n%s • %s" % [number,str(trip.state).capitalize(),str(trip.destination.get("name","Choose destination later")),game.economy.pounds(int(trip.fare))]
		if seconds_left>0 or game.economy.data.receipts.get(key,{}).has("pass_code"):
			cab_status.text=number+" • "+str(trip.state).capitalize()+"\n"+str(trip.destination.get("name","Choose destination later"))+" • Pass included"
		speed_button.visible=trip.state in ["boarding","awaiting_destination","riding"]
		if int(trip.car)>=0:
			speed_button.text="Normal speed" if ride.cars[int(trip.car)].fast else "Travel faster"
		drive_button.visible=ride==game.cabs and trip.state=="riding"
		drive_button.text="Switch to self-drive" if game.cabs.is_manual(game.player) else "Drive myself"
		unlock_button.visible=trip.state=="waiting"
		unlock_button.disabled=not ride.is_pickup_near(game.player)
		confirm_button.visible=trip.state=="awaiting_destination"
		cancel_button.visible=trip.state in ["queued","approaching","waiting"]
		leave_button.visible=trip.state=="awaiting_destination"
		skip_button.visible=trip.state=="riding"
		if trip.state in ["waiting","approaching"]:
			cab_status.text+="\nWalk beside the assigned vehicle and press E. No code or circle required."
		if ride==game.helicopters and trip.state in ["boarding","awaiting_destination","riding"]:
			altitude_button.show()
			altitude_button.text="Return to normal height" if ride.cars[int(trip.car)].high_flight else "Fly higher"
		if ride==game.helicopters: cab_status.text+="\nHelicopters land at clear ground near the selected address."
		topics.visible=ride==game.cabs and trip.state=="riding"
		conversation.visible=topics.visible
	else:
		_quote()
		var notice: String=ride.last_notice.get(key,"")
		if notice!="": cab_status.text+="\n"+notice
	conversation.text=str(game.player.get_meta("cab_reply","Talk to your Aurora"))
	var text: String = "COUNCIL TREASURY: "+game.economy.pounds(int(game.economy.data.council))+"\n"
	text += "Cash in: "+game.economy.pounds(int(game.economy.data.get("cash_in",0)))+" • Cash out: "+game.economy.pounds(int(game.economy.data.get("cash_out",0)))+"\nRecent council cash movements:\n"
	var ledger: Array = game.economy.data.ledger
	for i in range(maxi(0,ledger.size()-8),ledger.size()):
		text += ledger[i].reason+"  "+game.economy.pounds(int(ledger[i].get("council_delta",0)))+"\n"
	text += "\nCITY RESIDENTS • JOBS & WEALTH\n"
	for person in game.population.residents:
		var resident: Dictionary = game.economy.account_for(person)
		text += person.person_name+" • "+resident.job+" • "+game.economy.pounds(int(resident.balance))+"\n"
	council.text = text

	if apps!=null:apps.update()

func _process(delta: float) -> void:
	altitude_hud.visible=game.player.riding_service==game.helicopters and not panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	if altitude_hud.visible:
		var flight_key:String=game.economy.key_for(game.player)
		if game.helicopters.bookings.has(flight_key):
			var aircraft:Dictionary=game.helicopters.cars[int(game.helicopters.bookings[flight_key].car)]
			altitude_hud.text="Normal flight height" if aircraft.high_flight else "Fly higher"
	var in_service: bool=is_instance_valid(game.player.riding_service)
	var clear_hud: bool=not panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	speed_hud.visible=in_service and clear_hud
	drive_hud.visible=game.player.riding_service==game.cabs and clear_hud
	var width: float=get_viewport().get_visible_rect().size.x
	speed_hud.position=Vector2(width-230,112); speed_hud.size=Vector2(210,36)
	drive_hud.position=Vector2(width-230,154); drive_hud.size=Vector2(210,36)
	altitude_hud.position=Vector2(width-230,154); altitude_hud.size=Vector2(210,36)
	if in_service:
		var ride=game.player.riding_service
		var index: int=game.player.get_meta("cab_car",-1)
		if index>=0:
			var vehicle: Dictionary=ride.cars[index]
			speed_hud.text=("Normal speed" if vehicle.fast else "Travel faster")+" • %d mph" % roundi(absf(float(vehicle.speed))*2.23694)
			drive_hud.text="Switch to self-drive" if game.cabs.is_manual(game.player) else "Drive myself"
	if game.get_meta("phone_touch",false):
		_mobile_layout()
	else:
		_desktop_layout()

	game.player.hud.visible = not panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	game.player.controls.visible = not panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	if game.player.driving and is_instance_valid(game.player.vehicle):
		game.player.vehicle.set_meta("controls_blocked",panel.visible or game.city_map.expanded or game.get_meta("controller_screen_mode",false))
	refresh_clock += delta
	if panel.visible and refresh_clock>0.5:
		refresh_clock = 0
		update_display()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_K:
		hail()
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_P:
		toggle()
		get_viewport().set_input_as_handled()

func visit_house(house: Node3D) -> void:
	selected_house = int(house.house_number)
	apps.selected_home=selected_house
	open_app("home_rental")
	show_message(house.address+" • £400/month. Confirm only if you want to rent this home.")

func _release_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()

func _toggle_altitude() -> void:
	var key:String=game.economy.key_for(game.player)
	if not game.helicopters.bookings.has(key): return
	var trip:Dictionary=game.helicopters.bookings[key]
	var aircraft:Dictionary=game.helicopters.cars[int(trip.car)]
	game.helicopters.set_high_flight(game.player,not aircraft.high_flight)
	update_display()

func _toggle_speed() -> void:
	var ride=ride_service()
	var key: String=game.economy.key_for(game.player)
	if not ride.bookings.has(key) or int(ride.bookings[key].car)<0: return
	var car: Dictionary=ride.cars[int(ride.bookings[key].car)]
	ride.set_fast(game.player,not car.fast)
	update_display()

func _toggle_driving() -> void:
	if not game.cabs.set_manual(game.player,not game.cabs.is_manual(game.player)):
		show_message(game.economy.last_error)
	else:
		panel.hide(); _release_focus()
	update_display()

func _desktop_layout() -> void:
	panel.size=panel.get_combined_minimum_size()
	var available := get_viewport().get_visible_rect().size
	var factor := minf(1,minf((available.x-40)/maxf(panel.size.x,410),(available.y-80)/maxf(panel.size.y,560)))
	panel.scale = Vector2.ONE*maxf(0.4,factor)
	panel.position=Vector2(available.x-panel.size.x*panel.scale.x-25,maxf(20,(available.y-panel.size.y*panel.scale.y)/2))

func _mobile_layout() -> void:
	var viewport:=get_viewport().get_visible_rect().size
	if mobile_scroll==null:
		# Keep a fixed-size header and scroll the page, instead of shrinking text.
		var rows=panel.get_child(0)
		mobile_scroll=ScrollContainer.new()
		mobile_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		mobile_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		var body:=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		mobile_scroll.add_child(body)
		var children:Array=[]
		for child in rows.get_children():
			if child!=rows.get_child(0) and child!=summary:children.append(child)
		for child in children:rows.remove_child(child);body.add_child(child)
		rows.add_child(mobile_scroll)
		panel.custom_minimum_size=Vector2.ZERO
		apps.home.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for child in apps.home.get_children():
			child.custom_minimum_size=Vector2(84,94);child.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var glyph=child.get_child(0)
			glyph.anchor_left=0.5;glyph.anchor_right=0.5;glyph.offset_left=-15;glyph.offset_right=15;glyph.offset_top=12;glyph.offset_bottom=42
		for scroll in apps.sheets.values():
			scroll.custom_minimum_size=Vector2.ZERO
			scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		for scroll in tabs.get_children():
			if scroll is ScrollContainer:
				scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		tabs.custom_minimum_size=Vector2.ZERO
		council.custom_minimum_size.x=0
		apps.title.add_theme_font_size_override("font_size",22)
		apps.title.clip_text=true;apps.title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var close=rows.get_child(0).get_child(2)
		close.text="×";close.add_theme_font_size_override("font_size",25)
		summary.add_theme_font_size_override("font_size",17)
		message.add_theme_font_size_override("font_size",16)
		for control in panel.find_children("*","Control",true,false):
			if control is OptionButton:control.fit_to_longest_item=false
			if control is Button:
				control.clip_text=true;control.custom_minimum_size.x=maxf(44,control.custom_minimum_size.x)
		for button in [speed_hud,drive_hud,altitude_hud]:button.add_theme_font_size_override("font_size",13)
	cab_status.text=cab_status.text.replace("press E","tap △").replace("E:","△")
	panel.scale=Vector2.ONE
	var safe:Vector4=game.get_meta("phone_safe",Vector4.ZERO)
	panel.position=Vector2(12+safe.x,14+safe.y)
	panel.size=Vector2(viewport.x-24-safe.x-safe.z,viewport.y-28-safe.y-safe.w)
	# Service extras remain reachable above the right thumb buttons.
	speed_hud.position=Vector2(viewport.x-170,66);speed_hud.size=Vector2(158,44)
	drive_hud.position=Vector2(viewport.x-170,116);drive_hud.size=Vector2(158,44)
	altitude_hud.position=Vector2(viewport.x-170,116);altitude_hud.size=Vector2(158,44)
