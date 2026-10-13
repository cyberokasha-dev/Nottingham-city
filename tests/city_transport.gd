extends SceneTree
var failed := false
func _initialize() -> void:
    call_deferred("run_checks")
func check(value: bool, text: String) -> bool:
    if not value:
        failed = true
        push_error(text)
        quit(1)
    return value
func run_checks() -> void:
    var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    for i in range(5):
        await physics_frame
    var network = game.city.transport
    var traffic = game.city.traffic
    traffic.set_process(false)
    for bus in network.buses:
        bus.set_physics_process(false)
    if not check(network.routes.size()==4 and network.buses.size()==12 and network.stops.size()==24,"Four routes, twelve buses and 24 shelters"):
        return
    for car in traffic.cars:
        if not check(car.node.has_meta("vehicle_kind") and car.node.get_meta("wheels").size()==4,"Detailed fleet models and four rotating wheels replace boxes"):
            return
    for route in network.routes:
        for i in range(route.path.size()):
            var p: Vector3 = route.path[i]
            var on_road := false
            for x in traffic.ROAD_X:
                on_road = on_road or absf(p.x-x)<5.8
            for z in traffic.ROAD_Z:
                on_road = on_road or absf(p.z-z)<5.8
            if not check(on_road,"Every sampled bus turn remains on a road"):
                return
        for stop in route.stops:
            var sample: Dictionary = network.sample(route,stop.distance)
            if not check(sample.position.distance_to(stop.position)<0.05,"Stops lie precisely on their continuous route"):
                return
            if not check(stop.waiting.size()==2 and stop.pavement.distance_to(stop.position)>4.0,"Waiting passengers stand on the pavement"):
                return
    var bus = network.buses[0]
    # Isolate the bus to test rules without a queue obscuring red-light behaviour.
    var fake_traffic = Node3D.new()
    fake_traffic.set_script(preload("res://town/traffic.gd"))
    fake_traffic.clock = 12.0
    var allowed: float = fake_traffic.allowed_travel(Vector3(42.8,traffic.LEVEL,-140),Vector3.BACK,100.0,6.5,bus)
    if not check(is_equal_approx(allowed,8.0),"Bus clamps at red light before junction"):
        return
    fake_traffic.clock = 0
    if not check(fake_traffic.allowed_travel(Vector3(42.8,traffic.LEVEL,-140),Vector3.BACK,100,6.5,bus)==100,"Bus can advance on green"):
        return
    fake_traffic.free()
    bus.distance = bus.route.stops[0].distance
    bus._update_position()
    bus.arrive(0)
    bus.advance(0.7)
    var person = game.player
    person.global_position = bus.entrance()
    if not check(bus.model.door_fraction>=0.9 and bus.board(person),"Doors open at a stop and player boards"):
        return
    bus.dwell = 0
    bus.advance(0.1)
    var before: float = bus.distance
    bus.advance(0.2)
    if not check(bus.distance==before and bus.model.door_fraction>0,"Bus remains stationary while doors close"):
        return
    bus.advance(1.0)
    if not check(bus.model.door_fraction==0 and bus.state=="moving","Door interlock releases only when closed"):
        return
    bus.state = "moving"
    if not check(not bus.leave(person) and bus.bell and is_instance_valid(person.riding_bus),"Cannot get off while moving; bell requests stop"):
        return
    bus.arrive(1)
    bus.advance(0.8)
    if not check(bus.leave(person) and not is_instance_valid(person.riding_bus) and person.visual.visible,"Player alights to pavement at next stop"):
        return
    var park = game.city.parks[0]
    person.global_position = park.ball.global_position+Vector3(0,0,-1)
    if not check(park.use(person),"Football can be kicked"):
        return
    if not check(park.ball.linear_velocity.length()>0,"Kick drives physical ball"):
        return
    park.ball.position = Vector3(-3,0.6,3.2)
    park._physics_process(0.02)
    if not check(park.goals==1,"Goal detection scores and resets ball"):
        return
    person.global_position = park.to_global(Vector3(7,0,7))
    if not check(park.use(person) and person.park_activity==park,"Swing is usable"):
        return
    park.tick_user(person,0.1)
    if not check(person.global_position.distance_to(park.swings[0].to_global(Vector3(0,-2.4,0)))<0.01,"Rider follows swinging seat"):
        return
    park.release(person)
    person.global_position = park.to_global(Vector3(-9.5,0,10))
    if not check(park.use(person),"Slide can be used"):
        return
    park.tick_user(person,3.2)
    if not check(not is_instance_valid(person.park_activity),"Slide returns player control at landing"):
        return
    person.global_position = park.to_global(park.checkpoints[0])
    park.use(person)
    for index in [1,2,3,0]:
        person.global_position = park.to_global(park.checkpoints[index])
        park._physics_process(1.0)
    if not check(park.best_run>0 and park.run_checkpoint==-1,"Complete a timed park lap"):
        return
    # Complete a whole service cycle against real signal phases with no queue.
    var rule_only = Node3D.new()
    rule_only.set_script(preload("res://town/traffic.gd"))
    var original_traffic = network.traffic
    network.traffic = rule_only
    var completed_before: int = bus.services_completed
    for frame in range(12000):
        rule_only.clock = fposmod(float(frame)/30.0,24.0)
        bus.advance(1.0/30.0)
        if bus.services_completed>=completed_before+7:
            break
    network.traffic = original_traffic
    rule_only.free()
    if not check(bus.services_completed>=completed_before+7,"Bus repeatedly completes stops and a whole route loop"):
        return
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false):
        audio.stop()
    game.queue_free()
    await process_frame
    print("CITY_TRANSPORT_OK: detailed cars, routes, curved turns, signals, doors, boarding, parks and cleanup")
    quit()
