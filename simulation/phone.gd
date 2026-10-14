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

func _ready() -> void:
	layer = 20
	panel = PanelContainer.new()
	panel.position = Vector2(25,55)
	panel.custom_minimum_size = Vector2(560,590)
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
	close.pressed.connect(func(): panel.hide())
	header.add_child(close)
	summary = _label(rows,"")
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(550,380)
	rows.add_child(tabs)
	var cab := _tab(tabs,"Aurora")
	_label(cab,"Driverless travel • quoted fare • private boarding PIN")
	search = LineEdit.new()
	search.placeholder_text = "Find house number, street, stop or park"
	search.text_changed.connect(func(_text): _locations())
	cab.add_child(search)
	destinations = OptionButton.new()
	destinations.item_selected.connect(func(_i): _quote())
	cab.add_child(destinations)
	cab_status = _label(cab,"")
	_button(cab,"Book pickup at my location",func():
		if filtered.is_empty(): return
		var booking: Dictionary = game.cabs.book(game.player,filtered[destinations.selected])
		show_message("Booking accepted. Meet Aurora at the safe road pickup shown on the map." if not booking.is_empty() else game.economy.last_error)
		update_display())
	pin = LineEdit.new()
	pin.placeholder_text = "Enter your four-digit code at the cab door"
	pin.max_length = 4
	cab.add_child(pin)
	_button(cab,"Unlock and board Aurora",func():
		show_message("Door unlocked • fare paid • journey starting" if game.cabs.unlock(game.player,pin.text) else "Check your PIN and stand beside your arrived cab. Three errors lock it for 10 seconds.")
		update_display())
	_button(cab,"Cancel unstarted booking",func(): show_message("Booking cancelled" if game.cabs.cancel(game.player) else "No cancellable booking"))
	var housing := _tab(tabs,"Housing")
	_label(housing,"Council homes • first month paid when renting • £400/month\nOne tenancy per person. Door entry requires your tenancy.")
	properties = OptionButton.new()
	housing.add_child(properties)
	_button(housing,"Rent selected home",func():
		if offers.is_empty(): return
		var number: int = offers[properties.selected]
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
	message = _label(rows,"Local save • autonomous council services • pounds sterling")
	_locations()
	_offers()
	panel.hide()
	var open := Button.new()
	open.text = "P • Phone / Aurora / Money"
	open.position = Vector2(215,20)
	open.pressed.connect(toggle)
	add_child(open)

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = title
	tabs.add_child(tab)
	return tab

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func show_message(text: String) -> void:
	message.text = text
	update_display()

func toggle() -> void:
	panel.visible = not panel.visible
	game.player.hud.visible = not panel.visible
	game.player.controls.visible = not panel.visible
	if panel.visible:
		_offers()
		update_display()

func _locations() -> void:
	filtered.clear()
	destinations.clear()
	for location in game.economy.locations:
		if search.text.strip_edges()=="" or location.name.to_lower().contains(search.text.to_lower()):
			filtered.append(location)
			destinations.add_item(location.name)
	_quote()

func _offers() -> void:
	offers.clear()
	properties.clear()
	for number in game.economy.houses:
		if str(game.economy.house_record(number).tenant)=="":
			offers.append(number)
			properties.add_item("House "+str(number)+" • "+game.economy.houses[number].street+" • £400/month")

func _quote() -> void:
	if not filtered.is_empty():
		cab_status.text = "Quote: "+game.economy.pounds(game.cabs.quote(game.player,filtered[maxi(0,destinations.selected)].point))

func _navigate(point: Vector3) -> void:
	game.city_map.destination = point
	game.city_map.destination_active = true
	panel.hide()

func update_display() -> void:
	var account: Dictionary = game.economy.account_for(game.player)
	summary.text = "%s • %s • Day %d %02d:00\nJob: %s • House: %s • Arrears: %s • Loan: %s" % [game.player.profile.name,game.economy.pounds(int(account.balance)),game.economy.day()+1,game.economy.hour(),account.job if account.job!="" else "Unemployed",str(account.house),game.economy.pounds(int(account.arrears)),game.economy.pounds(int(account.loan))]
	var key: String = game.economy.key_for(game.player)
	if game.cabs.bookings.has(key):
		var trip: Dictionary = game.cabs.bookings[key]
		cab_status.text = "Aurora %s • %s\nFare %s • Your PIN: %s" % [str(int(trip.car)+1) if int(trip.car)>=0 else "queue",trip.state,game.economy.pounds(int(trip.fare)),trip.pin]
		if trip.has("pickup_curb") and trip.state!="riding":
			game.city_map.destination = trip.pickup_curb
			game.city_map.destination_active = true
	else:
		_quote()
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
	game.player.hud.visible = not panel.visible
	game.player.controls.visible = not panel.visible
	refresh_clock += delta
	if panel.visible and refresh_clock>0.5:
		refresh_clock = 0
		update_display()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_P:
		toggle()
		get_viewport().set_input_as_handled()
