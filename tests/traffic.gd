extends SceneTree

func _initialize() -> void:
    call_deferred("check_traffic")

func check_traffic() -> void:
    var traffic = preload("res://town/traffic.gd").new()
    root.add_child(traffic)
    traffic.set_process(false)
    if not check(traffic.cars.size() == 48, "Detailed traffic fleet"): return
    if not check(traffic.signals.size() == 64, "Four approaches at each of sixteen signalised distributor junctions"): return
    if not check(traffic.lamp_materials.size() == 6, "Lamp materials shared"): return
    for item in traffic.cars:
        if not check(is_equal_approx(item.node.position.y, traffic.LEVEL), "Cars start on the road"): return
        if not check(item.offset * item.direction > 0 if item.vertical else item.offset * item.direction < 0, "UK left-hand lanes"): return
    for phase in [0.0,4.0,4.25,4.5,8.5,8.99]:
        traffic.clock = phase
        traffic._update_lamps()
        if not check(not (traffic._green(true) and traffic._green(false)), "No conflicting green lights"): return
        for junction_signal in traffic.signals:
            if not check(junction_signal.lamps.size() == 3): return
            for lamp in junction_signal.lamps:
                if not check(lamp.is_inside_tree(), "Signals owned by scene"): return
                if not check(lamp.material_override in traffic.lamp_materials): return
    # A red light must stop a car at the line even when one frame spans it.
    var car = traffic.cars[1]
    for other in traffic.cars:
        if other != car:
            other.taken = true
            other.node.hide()
    car.direction = 1.0
    car.distance = -160.0
    car.node.position = traffic.lane_position(car,car.distance)
    traffic.clock = 0.0
    traffic._process(2.0)
    if not check(is_equal_approx(car.distance, -152.0), "Stop twelve metres before crossing"): return
    traffic._process(0.1)
    if not check(is_equal_approx(car.distance, -152.0), "Wait while red"): return
    traffic.clock = 4.5
    traffic._process(0.1)
    if not check(car.distance > -152.0, "Move when green"): return
    car.distance = -145.0
    car.node.position = traffic.lane_position(car,car.distance)
    traffic.clock = 0.0
    traffic._process(0.1)
    if not check(car.distance > -145.0, "Clear junction when already past stop line"): return
    car.distance = 156.9
    car.node.position = traffic.lane_position(car,car.distance)
    traffic.clock = 4.5
    traffic._process(0.1)
    if not check(is_equal_approx(car.distance, -157.0), "Wrap road boundary"): return
    # Unsignalised crossings must still reserve the full junction, including buses.
    var rules = preload("res://town/traffic.gd").new()
    var crossing_car = Node3D.new()
    root.add_child(crossing_car)
    crossing_car.position = Vector3(88,rules.LEVEL,82.8)
    crossing_car.rotation.y = -PI/2
    rules.autonomous_nodes.append(crossing_car)
    if not check(not rules._has_signal_at(80,80), "Give-way scenario uses a junction without lights"): return
    for phase in [0.0,4.5,8.99]:
        rules.clock = phase
        if not check(rules.allowed_travel(Vector3(68,rules.LEVEL,77.2),Vector3.RIGHT,1,5.2,null)==0,"Turning buses wait outside an occupied give-way junction at every phase"): return
    crossing_car.position.x = 100
    rules.clock = 0
    if not check(rules.allowed_travel(Vector3(68,rules.LEVEL,77.2),Vector3.RIGHT,1,5.2,null)>0,"An empty give-way junction needs no green light"): return
    crossing_car.position.x = 88
    if not check(rules.allowed_travel(Vector3(72,rules.LEVEL,77.2),Vector3.RIGHT,.1,2.3,null)>0,"A committed vehicle clears instead of stopping inside the crossing"): return
    crossing_car.free()
    rules.free()
    traffic.queue_free()
    await process_frame
    print("TRAFFIC_OK: original fleet, owned signals, phases, stop lines, restart and cleanup")
    quit()

func check(condition: bool, reason := "Traffic rule check") -> bool:
    if not condition:
        push_error(reason)
        quit(1)
    return condition
