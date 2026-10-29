extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1");seed(1492);call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failed=true;push_error(message)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(game);game.economy.enabled=false;game.process_mode=Node.PROCESS_MODE_DISABLED
	var city=game.city;var rail=game.rail;var p=game.player
	check(W.LIMIT<800 and W.contains(Vector3(700,0,0)) and not W.contains(Vector3(700,0,700)),"The playable footprint is a medium circle, not the former long square")
	check(game.fleet.is_empty(),"The starter courtyard is now a paid rental depot with no free cars")
	check(game.cabs.cars.size()==18 and city.transport.buses.size()==8,"Three Aurora / Robovan road vehicles per district and eight buses serve the compact streets")
	game.city_map.open()
	var east:Vector2=game.city_map.point(Vector3(100,W.LEVEL,0))-game.city_map.point(Vector3(0,W.LEVEL,0))
	var south:Vector2=game.city_map.point(Vector3(0,W.LEVEL,100))-game.city_map.point(Vector3(0,W.LEVEL,0))
	check(absf(east.length()-south.length())<.01,"The atlas preserves equal world distances so the circular city appears round")
	game.city_map.close()
	var ids:Dictionary={}
	for car in game.cabs.cars:
		check(not ids.has(car.cab_id),"Every additional Aurora retains a unique visible identifier")
		ids[car.cab_id]=true
	for house in city.houses:check(W.contains(house.position) and W.place_clear(house.position,14),"Homes fit inside the compact city and leave civic sites clear")
	for site in W.place_sites():
		check(game.economy.locations.any(func(l):return l.name==site.name),"Every civic site is selectable in phone bookings and on the map")
		check(not game.helicopters.clear_ground(site.point),"Reserved civic plots and the race circuit cannot become landing sites")
	check(city.places.sites.filter(func(s):return is_instance_valid(s.node)).is_empty(),"Civic buildings are deferred until approached")
	for line in rail.lines:
		check(line.loop and line.height==0 and line.path[0].distance_to(line.path[-1])<.01,"The railway is a closed loop on the ground")
		for point in line.path:
			check(absf(point.y-W.LEVEL)<.001 and W.road_clear(point,20),"Ground rail has no elevated spans or uncontrolled road crossings")
			check(not W.rail_clear(point,9),"Every arc, including the closing arc, is protected from helicopter landings")
		for i in range(1,line.path.size()):check(line.path[i].distance_to(line.path[i-1])<7,"The train path remains smoothly sampled")
	# A whole circuit crosses the wrap in both directions, with ordered stops and no teleport at the seam.
	var before:int=total_money(game.economy)
	var identities:Dictionary={}
	for train in rail.trains:
		check(not identities.has(train.service_id),"Circle train manifests use distinct service identities")
		identities[train.service_id]=true
		var count:=0;var last:int=train.stop_index
		for tick in range(15000):
			if train.state=="dwell":train.dwell=0
			var start:Vector3=train.position
			train.advance(.1)
			check(train.position.distance_to(start)<=train.MAX_SPEED*.1+.1,"Train motion stays continuous through the closed-ring seam")
			if train.stop_index!=last:
				check(train.stop_index==posmod(last+train.direction,6),"Each direction visits its next actual station")
				last=train.stop_index;count+=1
				if count==7:break
		check(count==7,"Each train completes more than one complete circle")
	check(total_money(game.economy)==before,"Actual commuter rail fares transfer money without minting or losing it")
	# Existing saves may rent a home retired by compaction. Transfer it without reusing its retired number.
	var key:String=game.economy.key_for(p);var account:Dictionary=game.economy.account_for(p)
	account.house=9000;account.due=37;account.arrears=250
	game.economy.data.houses.RetiredHome={"number":9000,"tenant":key,"rent":41000}
	var cash:int=account.balance
	game.economy.reconcile_housing()
	check(account.house>0 and account.house!=9000 and game.economy.houses.has(int(account.house)),"A retired rental transfers into an available existing home")
	check(account.balance==cash and account.due==37 and account.arrears==250 and game.economy.house_record(account.house).rent==41000,"Relocation preserves money, due date, arrears and agreed rent")
	check(game.economy.data.houses.RetiredHome.number==9000 and game.economy.data.houses.RetiredHome.tenant=="","Retired house numbers stay in the save and are never allocated again")
	# Approach the racing ground: it is built under the site budget and records an ordered timed lap.
	p.driving=true
	for i in range(9):
		p.global_position=Vector3(-380,W.LEVEL,340)+city.places._race_point(i%8)
		city.places._process(.21)
	check(city.places.best_lap<INF,"The driveable circuit records a lap only after every numbered checkpoint")
	p.driving=false;p.global_position=Vector3(20,-4.98,44)
	for i in range(200):city._process(.2);city.regions._process(.2);city.places._process(.2);rail._process(.2);await process_frame
	check(get_node_count()<7200 and city.houses.filter(func(h):return h.stream_active).size()<100,"The loaded motor quarter stays within the scene budget instead of loading every district")
	print("COMPACT_METRICS homes=",city.houses.size()," active_homes=",city.houses.filter(func(h):return h.stream_active).size()," nodes=",get_node_count()," infill=",city.infill.sites.size()," parks=",city.outer_parks.size())
	game.queue_free();await process_frame
	if not failed:print("COMPACT_CITY_OK: circular atlas, paid rental depot, larger cab fleet, reserved civic plots, ground circle rail, complete laps, preserved tenants and bounded streaming")
	quit(1 if failed else 0)

func total_money(e:Node) -> int:
	var amount:int=e.data.council
	for account in e.data.accounts.values():amount+=int(account.balance)
	return amount
