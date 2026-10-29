extends SceneTree
var failed := false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1")
	call_deferred("run")
func check(value: bool, message: String) -> bool:
	if not value:
		failed = true
		push_error(message)
	return value
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game)
	game.economy.enabled=false
	game.cabs.set_physics_process(false)
	game.cabs.npc_clock=-100000
	game.city.traffic.set_process(false)
	game.get_node("StreetEvents").set_physics_process(false)
	for bus in game.city.transport.buses: bus.set_physics_process(false)
	for person in game.population.residents: person.set_physics_process(false)
	var p=game.player
	p.set_physics_process(false)
	var cabs=game.cabs
	var economy=game.economy
	check(game.city.districts.size()==6 and cabs.ranks.size()==6 and cabs.cars.size()==18,"Six mapped districts each retain three Aurora / Robovan rank spaces")
	var numbers={}
	var styles={}
	for house in game.city.houses:
		check(not numbers.has(house.house_number),"House numbers remain globally unique")
		numbers[house.house_number]=true
		styles[house.architecture]=true
		check(house.neighbourhood!="" and house.address.contains(house.street),"Every house belongs to the atlas and its named street")
		check(house.entrance().distance_to(house.global_position)<9,"Style changes retain accessible entrances")
	check(styles.size()>=6,"Districts use distinct building silhouettes")
	for index in range(cabs.cars.size()):
		var car: Dictionary=cabs.cars[index]
		var district: Dictionary=game.city.districts[index%6]
		check(car.node.position.distance_to(district.rank+Vector3(sin(district.heading),0,cos(district.heading))*floori(index/6.0)*16+(Vector3(cos(district.heading),0,-sin(district.heading)) if car.kind=="Robovan" else Vector3.ZERO))<.1,"Each district starts with separated pickup vehicles at its rank")
		p.global_position=car.node.to_global(Vector3(2.05,.05,0))
		var trip: Dictionary=cabs.walk_up(p,index)
		check(not trip.is_empty() and trip.car==index and trip.state=="waiting","Walk-up reservation keeps the chosen parked cab")
		check(car.node.get_meta("marker").visible,"Walk-up booking reveals its own green PIN circle")
		check(cabs.cancel(p),"An unpaid walk-up can be cancelled without a fare")
	var map=game.city_map
	for expanded in [false,true]:
		map.expanded=expanded
		map.zoom=2
		p.yaw=1.1
		var world:=Vector3(-34,-5.02,25)
		check(map.world_point(map.point(world)).distance_to(world)<.01,"Zoomed and rotating maps preserve clicked world coordinates")
	map.open(true)
	var rank: Dictionary=game.city.districts[1]
	var location: Dictionary=map.location_at(map.point(rank.rank))
	check(location.name.contains("Aurora Rank"),"Ranks are searchable and selectable destinations")
	var selected_house=game.city.houses[0]
	check(map.location_at(map.point(selected_house.global_position)).name==selected_house.address,"Clicking a building footprint selects its actual numbered front-door address")
	map.close()
	p.global_position=Vector3(47.7,-5.02,35)
	game.phone.service_picker.select(1)
	game.phone.hail()
	var key: String=economy.key_for(p)
	check(game.phone.apps.page=="book" and not cabs.bookings.has(key),"Hail opens the four ticket choices without ordering or charging silently")
	game.phone.apps._choose_booking("Aurora");game.phone.apps._book_ticket("single")
	check(cabs.bookings.has(key) and cabs.bookings[key].get("flat_fare",false),"Cab ticket calls a vehicle to the player at a fixed displayed fare")
	game.phone.hail()
	check(cabs.bookings.size()==1,"Opening Book again never duplicates or charges a booking")
	cabs.cancel(p)
	game.phone.panel.hide()
	# Three cars must start through the SAME green, without unsafe turn conflicts.
	var rules=preload("res://town/traffic.gd").new()
	var convoy: Array[Node3D]=[]
	for z in [-125.0,-132.0,-139.0]:
		var car:=Node3D.new()
		root.add_child(car)
		car.position=Vector3(42.8,-5.02,z)
		car.set_meta("traffic_straight",true)
		rules.autonomous_nodes.append(car)
		convoy.append(car)
	rules.clock=0
	check(rules.allowed_travel(convoy[1].position,Vector3.BACK,.5,2.3,convoy[1])>0,"A straight follower starts while its leader is still in the junction")
	convoy[0].set_meta("traffic_straight",false)
	check(rules.allowed_travel(convoy[1].position,Vector3.BACK,.5,2.3,convoy[1])==0,"An uncertain or turning vehicle retains exclusive junction clearance")
	convoy[0].set_meta("traffic_straight",true)
	for tick in range(75):
		rules.clock=tick*.05
		for car in convoy: car.position.z+=rules.allowed_travel(car.position,Vector3.BACK,.5,2.3,car)
	check(convoy[2].position.z> -120,"All three queued cars clear on the first green")
	for car in convoy: car.free()
	rules.autonomous_nodes.clear()
	var edge_a := Node3D.new()
	var edge_b := Node3D.new()
	root.add_child(edge_a)
	root.add_child(edge_b)
	edge_a.position = Vector3(157,-5.02,-122.8)
	edge_a.rotation.y = PI/2
	edge_b.position = Vector3(-157,-5.02,-117.2)
	edge_b.rotation.y = -PI/2
	rules.autonomous_nodes.append_array([edge_a,edge_b])
	var edge_item := {"node":edge_a,"vertical":false,"lane":0,"direction":1.0,"offset":-2.8}
	check(rules.wrap_distance(edge_item,158)== -157,"Opposing cars at opposite city edges cannot deadlock each other's separate lanes")
	edge_b.position.z = -122.8
	check(rules.wrap_distance(edge_item,158)==157,"A genuinely occupied destination lane still prevents an overlapping wrap")
	edge_a.free()
	edge_b.free()
	rules.free()
	var merge_from := Vector3(45.5,-5.02,30)
	var merge_path: PackedVector3Array = cabs.path_between(merge_from,Vector3(147.7,-5.02,-90),Vector3.BACK)
	var first: Vector3 = (merge_path[1]-merge_path[0]).normalized()
	check(merge_path[0].distance_to(merge_from)<.01 and first.dot(Vector3.BACK)>.95,"A curb departure starts forward, rather than rotating sideways into traffic")
	var returning: Dictionary = cabs.cars[0]
	var parked_pose: Transform3D = returning.node.global_transform
	returning.path = merge_path
	returning.index = 1
	returning.state = "returning"
	var blocker := Node3D.new()
	game.add_child(blocker)
	blocker.position = merge_from+Vector3(0,0,2)
	game.city.traffic.autonomous_nodes.append(blocker)
	cabs._return_to_rank(returning,.1)
	check(returning.node.global_transform==parked_pose,"A yielding curb cab must not turn sideways while stationary")
	game.city.traffic.autonomous_nodes.erase(blocker)
	blocker.free()
	returning.state = "idle"
	for bus in game.city.transport.buses:
		check(bus.manifest.size()>=8 and bus.manifest.size()<=12,"Every bus starts with real paid passengers")
		var seats={}
		for record in bus.manifest:
			check(not seats.has(record.seat) and record.seat!=19,"Passengers have unique seats and leave the player seat free")
			seats[record.seat]=true
			check(economy.cash(record.person)==14800,"Starting passengers pay the £2 fare")
		check(bus.cabin.get_child_count()<=12,"Full cabins use shared-material batches")
	var bus=game.city.transport.buses[0]
	bus.arrive(1)
	bus.model.animate_doors(1)
	p.global_position=bus.entrance()
	var balance: int=economy.cash(p)
	check(bus.board(p) and economy.cash(p)==balance-200 and p.visual.visible,"Player boards visibly and pays once")
	bus.advance(1)
	check(bus.state=="dwell" and bus.model.door_fraction>.9 and bus.rider_board_clock<3,"Bus holds doors open while the player walks in")
	bus.advance(2.1)
	check(bus.rider_board_clock==3 and p.current_clip=="seated","Player sits before the bus can depart")
	check(bus.leave(p) and p.riding_bus==null and p.visual.visible,"Player can leave safely at an open stop")
	game.process_mode=Node.PROCESS_MODE_DISABLED
	for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
		audio.stop();audio.stream=null
	game.queue_free()
	await process_frame
	if not failed: print("DISTRICT_TRANSPORT_OK: city atlas, varied homes, six ranks, walk-up and hail, rotating map, same-green queues, full paid buses and visible boarding")
	quit(1 if failed else 0)
