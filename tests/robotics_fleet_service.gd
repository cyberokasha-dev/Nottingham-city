extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1");seed(1801);call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failed=true;push_error(message)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
	# Keep the real scene geometry but stop background simulation while inspecting service configuration.
	for node in [game]+game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	await process_frame;await physics_frame
	check(game.cabs.robotics_bays.size()==4,"The robotics service hall reserves four independent charging bays")
	check(game.cabs.cars.size()==18,"The entire Aurora/Robovan service fleet exists")
	check(game.cabs.cars.all(func(car):return car.has("service_after") and car.has("service_bay")),"Every Aurora/Robovan has a staggered autonomous service schedule")
	check(game.city.transport.buses.size()==8 and game.city.transport.buses.all(func(bus):return bus.has_method("_begin_robotics_service") and bus.robotics_service_interval>=300.0),"All eight buses receive terminal-layover service schedules")
	check(game.city.traffic.cars.size()==24 and game.city.traffic.cars.all(func(item):return item.has("service_after") and item.has("robotics_service_state")),"All 24 ambient self-driving road cars receive service cycles")
	var bay:Dictionary=game.cabs.robotics_bays[0]
	var path:PackedVector3Array=game.cabs._robotics_path_to_bay(game.cabs.cars[0].node.global_position,bay.point,game.cabs.cars[0].node.global_basis.z)
	check(not path.is_empty() and path[-1].distance_to(bay.point)<.1,"An autonomous road vehicle has a route from the road grid through the plaza gate to a charging bay")
	var robotics_site:Dictionary=game.city.places.sites.filter(func(site):return str(site.kind)=="robotics")[0]
	game.city.places._build(robotics_site)
	var plaza:Node3D=robotics_site.node
	var workshop_detail:Dictionary=plaza.details.filter(func(detail):return str(detail.kind)=="workshop")[0]
	plaza._build_detail(workshop_detail)
	var bay_labels=workshop_detail.node.find_children("*","Label3D",true,false).filter(func(label):return str(label.text).begins_with("BAY "))
	check(bay_labels.size()==4,"The finished physical workshop displays four individual autonomous-EV charging bays")
	var hub_air_pad:Dictionary=game.helicopters.pads.filter(func(p):return str(p.name)=="Robotics Plaza • Fleet Helipad")[0] if game.helicopters.pads.any(func(p):return str(p.name)=="Robotics Plaza • Fleet Helipad") else {}
	var service_stand:Dictionary=game.helicopters.pads.filter(func(p):return str(p.name)=="Robotics Plaza • Autonomous Service Stand")[0] if game.helicopters.pads.any(func(p):return str(p.name)=="Robotics Plaza • Autonomous Service Stand") else {}
	check(not hub_air_pad.is_empty() and not service_stand.is_empty(),"The hub has a fleet berth and a separate visiting-helicopter service stand")
	check(game.helicopters.cars.all(func(car):return car.has("service_after") and car.has("service_interval")),"Every Skylink helicopter has a staggered Robotics Plaza visit schedule")
	var route:Dictionary=game.city.transport.routes.filter(func(r):return str(r.number)=="61")[0]
	check(route.stops.any(func(stop):return str(stop.name).contains("Robotics Plaza")),"Route 61 stops at the Robotics Plaza interchange")
	check(W.place_clear(service_stand.point,9) and W.road_clear(service_stand.point,12) and W.rail_clear(service_stand.point,30),"The visiting aircraft stand stays clear of roads, rail and the reserved plaza footprint")
	game.queue_free();await process_frame
	if not failed:print("ROBOTICS_FLEET_SERVICE_OK: four EV bays, all Aurora/Robovan and bus schedules, accessible bay route, helicopter service stand, all helicopter schedules and Route 61 interchange")
	quit(1 if failed else 0)
