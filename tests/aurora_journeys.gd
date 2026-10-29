extends SceneTree
var failed := false
func _initialize() -> void:
	OS.set_environment("NOTTINGHAM_TEST","1")
	call_deferred("run")
func check(value: bool, reason: String) -> bool:
	if not value:
		push_error(reason)
		failed = true
	return value
func run() -> void:
	var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled = false
	game.cabs.set_physics_process(false)
	game.cabs.npc_clock = -100000
	game.get_node("StreetEvents").set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var p = game.player
	p.set_physics_process(false)
	var cabs = game.cabs
	var economy = game.economy
	var numbers := {}
	for car in cabs.cars:
		check(not numbers.has(car.cab_id),"Cab registration numbers must be unique")
		numbers[car.cab_id] = true
		check(car.label.text.contains(car.cab_id) and car.label.text.contains("ROBOVAN SELF DRIVE" if car.kind=="Robovan" else "AURORA SELF DRIVE"),"Fixed overhead identity")
	check(game.phone.selected_location.is_empty() and game.phone.destinations.selected==0,"Phone must not silently select a destination")
	p.global_position = Vector3(47.7,-4.98,35)
	var balance: int = economy.cash(p)
	var trip: Dictionary = cabs.book(p,{},"Amelia Test")
	check(not trip.is_empty() and trip.destination.is_empty(),"Named pickup-only booking")
	var car: Dictionary = cabs.cars[int(trip.car)]
	car.node.global_position = trip.pickup_curb
	car.state = "waiting"
	trip.state = "waiting"
	car.node.get_meta("marker").show()
	p.global_position = car.node.global_position+Vector3(0,0,3.8)
	check(not cabs.unlock(p,trip.pin) and economy.cash(p)==balance,"Only the green door circle accepts boarding")
	p.global_position = cabs.boarding_point(p)
	check(cabs.unlock(p,trip.pin),"Correct code at reserved cab door")
	check(economy.cash(p)==balance-300 and p.visual.visible,"Boarding takes £3 once and retains the visible person")
	check(not car.node.get_meta("marker").visible,"Boarding marker disappears after successful code")
	cabs._physics_process(.7)
	check(absf(car.node.get_meta("doors")[1].rotation.z)>0.5,"Butterfly door opens before passenger enters")
	check(cabs.rider_position(p).distance_to(cabs.seat_position(p))>0.5,"Passenger walks through the door rather than teleporting immediately to seat")
	for i in range(25): cabs._physics_process(.1)
	var parked: Vector3 = car.node.global_position
	for i in range(30): cabs._physics_process(.1)
	check(trip.state=="awaiting_destination" and car.node.global_position==parked,"Pickup-only cab remains parked until a destination is chosen")
	game.phone.update_display()
	check(not game.phone.pin.visible and not game.phone.unlock_button.visible and not game.phone.cab_status.text.contains("PIN:"),"Code prompt disappears after authentication")
	check(car.label.text==car.cab_id+"\nAURORA SELF DRIVE","Camera changes cannot restore stale boarding text")
	check(car.node.get_meta("displays")[0].text.contains("Amelia Test"),"Reserved passenger name appears on cab body display")
	var destination := {"name":"Gedling","point":Vector3(147.7,-4.98,-90)}
	var held: int = economy.data.receipts[economy.key_for(p)].amount
	var cash_before: int = economy.cash(p)
	economy.account_for(p).balance = 0
	check(not cabs.choose_destination(p,destination) and trip.state=="awaiting_destination" and economy.data.receipts[economy.key_for(p)].amount==held,"Unaffordable destination never starts or charges an extra fare")
	economy.account_for(p).balance = cash_before
	check(cabs.choose_destination(p,destination) and trip.state=="riding","Choosing destination after entry starts the confirmed road route")
	check(balance-economy.cash(p)==int(trip.fare),"Late destination takes only the remaining fare")
	check(not cabs.unlock(p,trip.pin) and not cabs.choose_destination(p,destination),"PIN and destination cannot be replayed to debit twice")
	check(cabs.remaining_route(p).size()>1,"Map receives actual remaining lane route")
	check(cabs.skip_journey(p) and not economy.data.receipts.has(economy.key_for(p)),"Chosen journey completes its single receipt")
	var map = game.city_map
	map.open(true)
	var world := Vector3(82,-5.02,44)
	check(map.world_point(map.point(world)).distance_to(world)<0.01,"Map screen/world mapping preserves clicked coordinates")
	check(map.location_at(map.point(economy.office)).name=="Council Office","Map pins resolve registered places")
	map.close()
	trip = cabs.book(p,{},"Refund Test")
	car = cabs.cars[int(trip.car)]
	car.state = "waiting"
	trip.state = "waiting"
	p.global_position = cabs.boarding_point(p)
	var refund_balance: int = economy.cash(p)
	cabs.unlock(p,trip.pin)
	for i in range(31): cabs._physics_process(.1)
	check(cabs.leave_waiting(p) and economy.cash(p)==refund_balance and p.riding_service==null,"Leaving unused destination-later cab refunds payment and restores walking")
	p.invulnerability = 0
	p.global_position = Vector3(160,-5.02,164)
	var test_vehicle := Node3D.new()
	game.add_child(test_vehicle)
	test_vehicle.position = Vector3(160,-5.02,160)
	game.city.traffic.autonomous_nodes.append(test_vehicle)
	var events = game.get_node("StreetEvents")
	events._physics_process(.2)
	test_vehicle.position.z+=1.6
	events._physics_process(.2)
	check(p.get_meta("road_fall",0)>0 and p.visual.clip=="death" and p.get_node("RoadImpactAudio").effect_player.playing,"Vehicle impact knocks down player with an audible effect")
	for i in range(35): preload("res://simulation/road_impact.gd").tick(p,.1)
	check(p.get_meta("road_fall",1)==0 and not p.dead and p.health>0,"Knocked-down player gets up and remains playable")
	var resident = game.population.residents[0]
	resident.invulnerability = 0
	resident.dead = false
	resident.receive_vehicle_hit(Vector3.RIGHT,7)
	check(resident.get_meta("road_fall",0)>0,"Vehicle impact also knocks down NPC residents")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop()
		audio.stream = null
	game.queue_free()
	await process_frame
	if not failed: print("AURORA_JOURNEYS_OK: unique named cabs, marker PIN, visible boarding, optional destination, one fare, refund, route map and impact recovery")
	quit(1 if failed else 0)
