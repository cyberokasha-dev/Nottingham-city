extends SceneTree

func _initialize() -> void:
    call_deferred("check_traffic")

func check_traffic() -> void:
    var traffic = preload("res://town/traffic.gd").new()
    root.add_child(traffic)
    traffic.set_process(false)
    assert(traffic.cars.size() == 48, "Detailed traffic fleet")
    assert(traffic.signals.size() == 120, "Four signal approaches at every junction")
    assert(traffic.lamp_materials.size() == 6, "Lamp materials shared")
    for item in traffic.cars:
        assert(is_equal_approx(item.node.position.y, traffic.LEVEL), "Cars start on the road")
        assert(item.offset * item.direction > 0 if item.vertical else item.offset * item.direction < 0, "UK left-hand lanes")
    for phase in [0.0, 10.0, 12.0, 22.0, 23.9]:
        traffic.clock = phase
        traffic._update_lamps()
        assert(not (traffic._green(true) and traffic._green(false)), "No conflicting green lights")
        for junction_signal in traffic.signals:
            assert(junction_signal.lamps.size() == 3)
            for lamp in junction_signal.lamps:
                assert(lamp.is_inside_tree(), "Signals owned by scene")
                assert(lamp.material_override in traffic.lamp_materials)
    # A red light must stop a car at the line even when one frame spans it.
    var car = traffic.cars[1]
    for other in traffic.cars:
        if other != car:
            other.lane = -1
    car.direction = 1.0
    car.distance = -160.0
    traffic.clock = 0.0
    traffic._process(2.0)
    assert(is_equal_approx(car.distance, -152.0), "Stop twelve metres before crossing")
    traffic._process(0.1)
    assert(is_equal_approx(car.distance, -152.0), "Wait while red")
    traffic.clock = 12.0
    traffic._process(0.1)
    assert(car.distance > -152.0, "Move when green")
    car.distance = -145.0
    traffic.clock = 0.0
    traffic._process(0.1)
    assert(car.distance > -145.0, "Clear junction when already past stop line")
    car.distance = 156.9
    traffic.clock = 12.0
    traffic._process(0.1)
    assert(is_equal_approx(car.distance, -157.0), "Wrap road boundary")
    traffic.queue_free()
    await process_frame
    print("TRAFFIC_OK: original fleet, owned signals, phases, stop lines, restart and cleanup")
    quit()
