extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
	OS.set_environment("NOTTINGHAM_TEST","1");seed(1492);call_deferred("run")
func check(ok:bool,message:String):
	if not ok:failed=true;push_error(message)
func frames(count:int):
	for i in range(count):await physics_frame
func body_at(point:Vector3) -> CharacterBody3D:
	var body:=CharacterBody3D.new();body.position=point
	var collider:=CollisionShape3D.new();var shape:=CapsuleShape3D.new()
	shape.radius=.3;shape.height=1.8;collider.shape=shape;collider.position.y=.9
	body.add_child(collider);root.add_child(body);return body
func door_hit(gate:Node3D) -> bool:
	var a:Vector3=gate.to_global(Vector3(0,1,-1));var b:Vector3=gate.to_global(Vector3(0,1,1))
	var query:=PhysicsRayQueryParameters3D.create(a,b,1)
	var hit:=gate.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider is AnimatableBody3D and gate.leaves.has(hit.collider)
func run():
	var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
	# Pause simulation callbacks, keeping the real city collision bodies active.
	for node in [game]+game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
	var p=game.player;var places=game.city.places
	var site:Dictionary=places.sites.filter(func(s):return s.kind=="robotics")[0]
	check(not is_instance_valid(site.node),"The distant plaza is absent at city startup")
	check(game.population.residents.all(func(person):return person.get_meta("service_counter","")!="robotics"),"The automatic first-phase plaza does not reassign another resident as a counter worker")
	check(game.economy.locations.any(func(l):return l.name==site.name and l.point==site.entry),"Map and travel select the public entrance rather than a closed gate or workshop bay")
	game.city_map.open()
	check(game.city_map.location_at(game.city_map.point(site.entry)).name==site.name,"Selecting the entrance marker on the actual map resolves Robotics Plaza")
	game.city_map.close()
	for corner in [Vector3(-75,0,-55),Vector3(75,0,55),Vector3(-75,0,55),Vector3(75,0,-55)]:
		check(W.contains(site.point+corner) and W.road_clear(site.point+corner,10) and W.rail_clear(site.point+corner,32),"The surface plaza does not cover roads or railway")
	for house in game.city.houses:check(W.place_clear(house.position,15),"Existing rental homes remain outside the plaza and approaches")
	p.global_position=site.entry;places._process(.21)
	var plaza=site.node
	check(is_instance_valid(plaza) and plaza.gates.size()==2,"Approaching creates both real automatic surface entrances")
	check(plaza.details.all(func(d):return not is_instance_valid(d.node)),"Landscape and reserved bays are deferred, rather than all constructed at entry")
	var gate=plaza.gates[0]
	await frames(3)
	check(door_hit(gate),"A closed glass gate physically blocks the doorway")
	# Walk the real player in from the street, without teleporting through the gate.
	p.global_position=gate.global_position+Vector3(0,0,-10)
	for i in range(150):
		await physics_frame
		p.velocity=Vector3(0,-2,7);p.move_and_slide()
	check(p.global_position.z>gate.global_position.z+6,"An ordinary walking player triggers and passes through the automatic gate")
	check(absf(p.global_position.y-game.city.GROUND_Y)<.2 and p.is_on_floor(),"Entry stays on the existing ground with no shaft, lift, platform or fall")
	# Standing in the doorway holds it open longer than the usual close timer.
	p.global_position=gate.global_position
	await frames(360)
	check(gate.openness>.99 and not door_hit(gate),"The doors stay open while a person occupies the doorway")
	var second:=body_at(gate.global_position+Vector3(2,0,2))
	await frames(3);p.global_position=site.entry
	await frames(240)
	check(gate.openness>.99,"A second person keeps the gate open when the first leaves")
	second.queue_free();await frames(270)
	check(gate.openness<.01 and door_hit(gate),"An empty gate closes with solid panels, even after an occupant is freed")
	# Public vehicles use animatable static colliders, unlike walking characters.
	var vehicle:=AnimatableBody3D.new();vehicle.collision_layer=2;vehicle.sync_to_physics=false
	vehicle.position=gate.global_position+Vector3(0,0,-4)
	var vehicle_shape:=CollisionShape3D.new();var vehicle_box:=BoxShape3D.new();vehicle_box.size=Vector3(2,2,4)
	vehicle_shape.shape=vehicle_box;vehicle_shape.position.y=1;vehicle.add_child(vehicle_shape);root.add_child(vehicle)
	await frames(45)
	check(gate.openness>.99 and gate.occupants.has(vehicle.get_instance_id()),"The real animatable collider type used by buses and driverless cars also opens the gate")
	vehicle.queue_free();await frames(270)
	p.global_position=gate.global_position+Vector3(0,0,4)
	await frames(45)
	check(gate.openness>.99,"The interior approach opens the same gate for exit")
	p.global_position=site.entry
	await frames(170)
	var closing:float=gate.openness
	check(closing>0 and closing<1,"The gate closes gradually rather than snapping shut")
	p.global_position=gate.global_position+Vector3(0,0,-4)
	await frames(12)
	check(gate.openness>closing,"An arriving person reverses a closing gate")
	var south=plaza.gates[1]
	p.global_position=south.to_global(Vector3(0,0,-4));await frames(45)
	check(south.openness>.99,"The rotated south entrance also opens from its outside approach")
	p.global_position=plaza.to_global(plaza.DIRECTORY+Vector3(0,0,-1.5))
	check(not plaza.nearest(p).is_empty() and p.nearest_city_activity()==plaza,"The directory works through the shared E / Triangle interaction")
	plaza.use(p)
	p.global_position=site.point
	for i in range(20):plaza._process(.2);await process_frame
	var loaded:int=plaza.details.filter(func(d):return is_instance_valid(d.node)).size()
	check(loaded>3 and plaza.find_children("*","Node",true,false).size()<260,"Nearby landscape and future bays use bounded batches")
	p.global_position=site.point+Vector3(0,0,-160)
	plaza._process(.2);await process_frame;await process_frame
	check(plaza.details.all(func(d):return not is_instance_valid(d.node)),"Details unload when the visitor walks away inside the site's streaming range")
	p.global_position=Vector3(3,-5,38);places._process(.21)
	await process_frame;await process_frame
	check(not is_instance_valid(site.node) and not is_instance_valid(plaza),"Leaving the district removes the plaza, sensors and details")
	# Revisit and exercise neighbourhood streaming under the existing city budget.
	p.global_position=site.entry
	for i in range(180):
		game.city._process(.2);game.city.regions._process(.2);places._process(.2)
		await process_frame
	check(is_instance_valid(site.node) and get_node_count()<7200,"A return visit streams back within the normal whole-city scene budget")
	print("PLAZA_METRICS loaded_details=",loaded," nodes=",get_node_count()," homes=",game.city.houses.size())
	game.queue_free();await process_frame
	if not failed:print("ROBOTICS_PLAZA_OK: surface access, shared directory, physical automatic gates, multi-person safety, smooth reversal and bounded streaming")
	quit(1 if failed else 0)
