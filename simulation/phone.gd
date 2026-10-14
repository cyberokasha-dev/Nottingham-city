extends CanvasLayer
var game: Node3D
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

func _ready() -> void:
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(25,55)
	panel.custom_minimum_size = Vector2(560,560)
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
	title.text = "CITY PHONE • P"
	title.add_theme_font_size_override("font_size",23)
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func(): panel.hide(); _release_focus())
	header.add_child(close)
	summary = _label(rows,"")
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(550,380)
	rows.add_child(tabs)
	var cab := _tab(tabs,"Aurora")
	_label(cab,"Your cab number and name identify your reserved Aurora.")
	passenger_name = LineEdit.new()
	passenger_name.placeholder_text = "Passenger name (shown on your cab)"
	passenger_name.max_length = 28
	passenger_name.text = game.player.profile.name
	name_owner = game.player.profile.name
	cab.add_child(passenger_name)
	search = LineEdit.new()
	search.placeholder_text = "Find house number, street, stop or park"
	search.text_changed.connect(func(_text): _locations())
	cab.add_child(search)
	destinations = OptionButton.new()
	destinations.item_selected.connect(func(index):
		selected_location = filtered[index-1].duplicate() if index>0 else {}
		_quote())
	cab.add_child(destinations)
	cab_status = _label(cab,"")
	_button(cab,"Choose destination on map • N",func():
		panel.hide()
		game.city_map.open(true))
	book_button = _button(cab,"Book pickup • destination optional",func():
		if passenger_name.text.strip_edges()=="":
			show_message("Enter your passenger name so you can identify your cab.")
			return
		var booking: Dictionary = game.cabs.book(game.player,selected_location,passenger_name.text)
		show_message("Pickup accepted. Your numbered cab will wait at the green boarding circle." if not booking.is_empty() else game.economy.last_error)
		update_display())
	confirm_button = _button(cab,"Confirm selected destination and fare",func():
		show_message("Destination confirmed. Your Aurora will leave once the doors are closed." if game.cabs.choose_destination(game.player,selected_location) else game.economy.last_error)
		update_display())
	pin = LineEdit.new()
	pin.placeholder_text = "Enter your two-digit code at the cab door"
	pin.max_length = 2
	pin.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	cab.add_child(pin)
	unlock_button = _button(cab,"Unlock and board Aurora",func():
		show_message("Door unlocked • fare paid • walk in, then choose a destination if needed" if game.cabs.unlock(game.player,pin.text) else "Check your PIN and stand in your cab’s green boarding circle. Three errors lock it for 10 seconds.")
		update_display())
	_button(cab,"Leave parked cab before choosing destination • refund",func():
		show_message("Unused journey refunded" if game.cabs.leave_waiting(game.player) else "This option is available while your cab waits for a destination."))
	_button(cab,"Cancel unstarted booking",func(): show_message("Booking cancelled" if game.cabs.cancel(game.player) else "No cancellable booking"))
	_button(cab,"Skip journey • keep the same fare",func():
		show_message("Arrived at your destination" if game.cabs.skip_journey(game.player) else "Board with your code and wait for the doors to close first."))
	conversation = _label(cab,"Talk to your Aurora during a journey:")
	var topics := HBoxContainer.new()
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
			game.city_map.destination = game.economy.houses[selected_house].entrance()
			game.city_map.destination_active = true)
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
	council.custom_minimum_size = Vector2(530,320)
	finance.add_child(council)
	_label(finance,"Public accounts • admin controls will be added later")
	var quality := CheckButton.new()
	quality.text = "Shadows (slower) • off for Chromebook performance"
	quality.toggled.connect(func(value):
		for light in game.city.find_children("*","DirectionalLight3D",true,false):
			light.shadow_enabled = value)
	rows.add_child(quality)
	var sound := CheckButton.new()
	sound.text = "City sound on"
	sound.button_pressed = not AudioServer.is_bus_mute(0)
	sound.toggled.connect(func(value): AudioServer.set_bus_mute(0,not value))
	rows.add_child(sound)
	message = _label(rows,"Local save • autonomous council services • pounds sterling")
	_locations()
	_offers()
	panel.hide()
	var open := Button.new()
	open.text = "P • Phone / Aurora / Money"
	open.position = Vector2(215,20)
	open.pressed.connect(toggle)
	add_child(open)
	var camera_button := Button.new()
	camera_button.text = "B • Change camera"
	camera_button.position = Vector2(495,20)
	camera_button.focus_mode = Control.FOCUS_NONE
	camera_button.pressed.connect(func(): game.player.cycle_view())
	add_child(camera_button)
	var map_button := Button.new()
	map_button.text = "N • Map"
	map_button.position = Vector2(680,20)
	map_button.pressed.connect(func(): game.city_map.open())
	add_child(map_button)

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

func toggle() -> void:
	panel.visible = not panel.visible
	game.player.hud.visible = not panel.visible and not game.city_map.expanded
	game.player.controls.visible = not panel.visible and not game.city_map.expanded
	if panel.visible:
		_offers()
		update_display()

func _locations() -> void:
	filtered.clear()
	destinations.clear()
	destinations.add_item("Choose later • wait in the cab")
	for location in game.economy.locations:
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
	tabs.current_tab = 0
	_quote()
	show_message("Selected: "+str(location.name)+". Book a pickup or confirm this destination for your waiting cab.")

func _quote() -> void:
	cab_status.text = "Choose a destination now, or after boarding. £3 boarding payment; remaining fare when you choose."
	if selected_location.has("point"):
		cab_status.text = str(selected_location.name)+" • quoted fare "+game.economy.pounds(game.cabs.quote(game.player,selected_location.point))

func _navigate(point: Vector3) -> void:
	game.city_map.destination = point
	game.city_map.destination_active = true
	panel.hide()
	_release_focus()

func update_display() -> void:
	if name_owner!=game.player.profile.name:
		name_owner = game.player.profile.name
		passenger_name.text = name_owner
	var account: Dictionary = game.economy.account_for(game.player)
	summary.text = "%s • %s • Day %d %02d:00\nJob: %s • House: %s • Arrears: %s • Loan: %s" % [game.player.profile.name,game.economy.pounds(int(account.balance)),game.economy.day()+1,game.economy.hour(),account.job if account.job!="" else "Unemployed",str(account.house),game.economy.pounds(int(account.arrears)),game.economy.pounds(int(account.loan))]
	var key: String = game.economy.key_for(game.player)
	var active: bool = game.cabs.bookings.has(key)
	passenger_name.editable = not active
	if active: passenger_name.text = game.cabs.bookings[key].passenger_name
	var authorised: bool = active and game.cabs.bookings[key].state in ["boarding","riding","awaiting_destination"]
	pin.visible = active and not authorised
	unlock_button.visible = pin.visible
	book_button.visible = not active
	confirm_button.visible = active and game.cabs.bookings[key].state!="riding"
	if active:
		var trip: Dictionary = game.cabs.bookings[key]
		var cab_id: String = game.cabs.cars[int(trip.car)].cab_id if int(trip.car)>=0 else "Dispatch queue"
		cab_status.text = "%s • %s • %s\nFare %s • %s" % [cab_id,trip.passenger_name,trip.state,game.economy.pounds(int(trip.fare)),str(trip.destination.get("name","Destination not chosen • cab will wait"))]
		if not authorised: cab_status.text += "\nYour two-digit PIN: "+str(trip.pin)
		if trip.state=="waiting": cab_status.text += "\nStand in the GREEN circle beside "+cab_id+" to enter your code."
		if trip.state=="awaiting_destination": cab_status.text += "\nParked safely. Choose a destination in the list or on the map, then confirm."
		if selected_location.has("point") and trip.state!="riding":
			cab_status.text += "\nSelected: "+str(selected_location.name)+" • "+game.economy.pounds(game.cabs.quote(game.player,selected_location.point))
	else:
		_quote()
		var notice: String = game.cabs.last_notice.get(key,"")
		if notice!="": cab_status.text += "\n"+notice
	conversation.text = str(game.player.get_meta("cab_reply","Talk to Aurora: traffic, local places, travel help, or quiet mode."))
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

func _process(delta: float) -> void:
	var available := get_viewport().get_visible_rect().size
	var factor := minf(1,minf((available.x-35)/580.0,(available.y-75)/maxf(panel.size.y,560)))
	panel.scale = Vector2.ONE*maxf(0.4,factor)
	game.player.hud.visible = not panel.visible and not game.city_map.expanded
	game.player.controls.visible = not panel.visible and not game.city_map.expanded
	if game.player.driving and is_instance_valid(game.player.vehicle):
		game.player.vehicle.set_meta("controls_blocked",panel.visible or game.city_map.expanded)
	refresh_clock += delta
	if panel.visible and refresh_clock>0.5:
		refresh_clock = 0
		update_display()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_P:
		toggle()
		get_viewport().set_input_as_handled()

func visit_house(house: Node3D) -> void:
	selected_house = int(house.house_number)
	_offers()
	panel.show()
	tabs.current_tab = 1
	show_message(house.address+" • £400/month. Confirm only if you want to rent this home.")

func _release_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus): focus.release_focus()
