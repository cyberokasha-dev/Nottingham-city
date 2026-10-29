extends SceneTree
var failed:=false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1")
	seed(24680)
	call_deferred("run")
func check(value:bool,message:String) -> void:
	if not value: failed=true; push_error(message)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game); game.economy.enabled=false; game.process_mode=Node.PROCESS_MODE_DISABLED
	var city=game.city; var rail=game.rail; var p=game.player; var air=game.helicopters
	check(city.houses.size()>=35 and city.houses.size()<=50,"The full-size city uses a small set of numbered homes across six districts")
	check(city.houses.filter(func(h):return h.stream_active).is_empty(),"Distant homes are metadata at startup, not constructed geometry")
	check(city.regions.active.is_empty() and city.regions.records.size()>100,"Road and rail tiles are deferred until approached")
	var home=city.houses[-1]
	p.global_position=home.entrance()
	for i in range(20): city._process(.25)
	check(home.stream_active,"Approaching an outer district builds the nearby house")
	var number:int=home.house_number; var address:String=home.address
	p.global_position=Vector3.ZERO
	city._process(.25)
	check(not home.stream_active and home.house_number==number and home.address==address,"Leaving unloads house geometry without changing its address or rent identity")
	city.regions.refresh_at(Vector3(520,-5,300))
	city.regions._process(0)
	check(city.regions.built_this_frame<=3 and city.regions.active.size()<=60,"Tile loading obeys its frame and active-region budgets")
	var previous_keys:Array=city.regions.active.keys()
	city.regions.refresh_at(Vector3(-520,-5,-300))
	check(city.regions.active.is_empty(),"Distant road tiles unload when the player moves between districts")
	check(rail.trains.filter(func(t):return is_instance_valid(t.model)).is_empty(),"Far-away trains do not construct their carriage models at startup")
	check(rail.stations.filter(func(s):return is_instance_valid(s.get("visual"))).is_empty(),"Station geometry is streamed near the player")
	check(rail.lines.size()==1 and rail.trains.size()==4,"The ground-level circle runs four independent passenger trains")
	for line in rail.lines:
		for i in range(1,line.lengths.size()): check(float(line.lengths[i])-float(line.lengths[i-1])>600,"Stations are widely spaced, not clustered at short intervals")
		for i in range(1,line.path.size()): check(line.path[i].distance_to(line.path[i-1])<10,"Rail geometry follows a continuously sampled curve")
	for station in rail.stations:
		var distance:=INF
		for pad in air.pads: distance=minf(distance,station.point.distance_to(pad.point))
		check(distance<160,"Every rail station has a nearby separate helipad")
	for route in city.transport.routes:
		check(route.length>1500 and route.length<2600 and route.stops.size()==5,"Compact bus corridors have five surveyed stops per loop")
		for stop in route.stops:
			for x in city.ROAD_X:
				for z in city.ROAD_Z:
					if city.traffic._is_junction(Vector3(x,-5.02,z)): check(absf(stop.position.x-x)>18 or absf(stop.position.z-z)>18,"Bus stops are outside actual junction approaches")
	check(city.traffic.signals.size()==52,"Signals are limited to selected distributor junctions")
	var layout=preload("res://town/world_layout.gd")
	for origin in game.cabs.ranks:
		for destination in game.cabs.ranks:
			if origin.id==destination.id: continue
			var path:PackedVector3Array=game.cabs.path_between(origin.rank,destination.rank)
			check(not path.is_empty(),"Every district rank has a legal road connection to every other district")
			for point in path: check(layout.on_road(point,5.9),"Long Aurora routes never use an unbuilt road or cut through a housing plot")
	var train=rail.trains[0]
	var treasury:int=game.economy.data.council
	train.ensure_model(); train.release_model(); train.ensure_model()
	check(int(game.economy.data.council)==treasury,"Streaming a train model cannot create duplicate public fares")
	p.global_position=train.entrance()
	var wallet:int=game.economy.cash(p)
	check(train.board(p) and game.economy.cash(p)==wallet-400,"Train entrance charges the exact fare before boarding")
	check(not train.board(p),"Duplicate boarding cannot double-charge")
	for i in range(250): train.advance(.1)
	check(p.visual.mounted and p.visual.get_parent()==train.model,"Visible rider is seated in and attached to the train")
	check(not train.leave(p),"A train passenger cannot leave while it is moving")
	for i in range(1500):
		train.advance(.1)
		if train.stop_index==1 and train.state=="dwell": break
	check(train.stop_index==1 and train.peak_speed>60 and train.peak_speed<=train.MAX_SPEED+.01,"An actual long-distance trip accelerates past 216 km/h and brakes at the next station")
	check((train.leave(p) or p.riding_bus==null) and p.riding_bus==null and p.visual.get_parent()==p,"Arrival restores the character on the platform for a walk to the stairs")
	var car=air.cars[0]
	p.global_position=car.node.position+Vector3(3,0,0)
	var trip:Dictionary=air.walk_up(p,0)
	check(not trip.is_empty() and air.board_near(p),"Helicopter uses the same nearby simple boarding flow")
	for i in range(65): air._physics_process(.05)
	check(air.set_high_flight(p,true) and car.cruise>=66,"The passenger can opt into a higher flight")
	check(air.set_high_flight(p,false) and car.cruise<=30,"The passenger can restore the lower normal flight height")
	check(air.leave_waiting(p),"Unused parked flight can still be refunded")
	for pad in air.pads: check(air.clear_ground(pad.point),"All station and neighbourhood helipads have clear ground")
	for park in city.outer_parks: check(not air.clear_ground(park.point),"Unloaded playgrounds remain protected landing exclusions")
	p.global_position=car.node.position+Vector3(3,0,0)
	trip=air.walk_up(p,0)
	check(air.choose_destination(p,{"name":"Gedling Station","point":rail.stations[4].point}),"A long flight accepts a station destination")
	wallet=game.economy.cash(p); treasury=game.economy.data.council
	var fare:int=trip.fare
	check(air.board_near(p),"The new journey charges before takeoff")
	for i in range(65): air._physics_process(.05)
	var landing:Vector3=car.landing
	check(air.set_high_flight(p,true),"Height may be changed during an actual flight")
	for i in range(300):
		air._physics_process(.05)
		if car.node.position.y>59: break
	check(car.node.position.y>59 and car.landing==landing,"Optional higher flight reaches its height without changing its reserved landing")
	check(air.set_high_flight(p,false),"Normal height can be restored in flight")
	var returned_low:=false
	var key:String=game.economy.key_for(p)
	for i in range(4000):
		air._physics_process(.05)
		if car.node.position.y<26 and car.node.position.distance_to(landing)>100: returned_low=true
		if not air.bookings.has(key): break
	check(returned_low and not air.bookings.has(key) and car.node.position.distance_to(landing)<.1,"The aircraft descends to normal cruise and completes its original destination")
	check(game.economy.cash(p)==wallet-fare and int(game.economy.data.council)==treasury+fare,"Height changes neither charge again nor duplicate the council fare")
	for aircraft in air.cars: check(float(aircraft.normal_cruise)>=22 and float(aircraft.normal_cruise)<=30,"Default flights stay in the lower building-safe height range")
	game.queue_free(); await process_frame
	if not failed: print("MEDIUM_CITY_OK: compact streamed districts, short bus routes, ground-level circle rail, fares, passengers, station helipads and selectable flight height")
	quit(1 if failed else 0)
