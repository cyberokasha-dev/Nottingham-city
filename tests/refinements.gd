extends SceneTree
func _initialize() -> void:
    OS.set_environment("NOTTINGHAM_TEST","1")
    call_deferred("run")
func check(value: bool, reason: String) -> bool:
    if not value:
        push_error(reason)
        quit(1)
    return value
func run() -> void:
    var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    game.economy.enabled=false
    game.cabs.npc_clock=-100000
    var p=game.player
    var cabs=game.cabs
    var traffic=game.city.traffic
    var network=game.city.transport
    p.set_physics_process(false)
    cabs.set_physics_process(false)
    traffic.set_process(false)
    for bus in network.buses: bus.set_physics_process(false)
    for stop in network.stops:
        var vertical=absf(stop.direction.z)>0.9
        for crossing in (traffic.ROAD_Z if vertical else traffic.ROAD_X):
            var gap=absf((stop.position.z if vertical else stop.position.x)-crossing)
            if not check(gap>=18,"Every bus stop and full bus stays outside ALL junctions"): return
    # Oriented blocking must see cross traffic and a real parked player vehicle.
    var obstacle=Node3D.new()
    obstacle.position=Vector3(0,traffic.LEVEL,0)
    obstacle.rotation.y=PI/2
    root.add_child(obstacle)
    var rules=preload("res://town/traffic.gd").new()
    rules.autonomous_nodes.append(obstacle)
    var gap=rules.allowed_travel(Vector3(0,traffic.LEVEL,-12),Vector3.BACK,20,2.3,null)
    if not check(gap<9 and gap>0,"Crossing vehicles block before overlapping, regardless of heading"): return
    rules.free()
    obstacle.free()
    # NPC bookings cannot consume the two reserved player cars.
    for person in game.population.residents:
        person.set_physics_process(false)
        person.resting=""
        person.current_house=null
        person.global_position=Vector3(87.7,traffic.LEVEL,-20)
        cabs.book(person,{"name":"Park","point":Vector3(-132,traffic.LEVEL,30)})
    if not check(cabs.cars[0].state=="idle" and cabs.cars[1].state=="idle","Player fleet capacity remains available despite a full NPC queue"): return
    p.global_position=Vector3(42.8,traffic.LEVEL,30)
    var balance=game.economy.cash(p)
    var trip=cabs.book(p,{"name":"Gedling test","point":Vector3(147.7,traffic.LEVEL,-30)})
    if not check(not trip.is_empty() and trip.car<2 and trip.pin.length()==2,"Player receives a reserved Aurora and a two-digit PIN"): return
    if not check(cabs.book(p,{"name":"Duplicate","point":Vector3.ZERO}).is_empty(),"Duplicate booking is refused with an active cancellable trip"): return
    if not check(cabs.cancel(p),"Approaching player trip can always be cancelled"): return
    # Corrupted/stale car assignment cannot permanently block a new request.
    cabs.bookings[game.economy.key_for(p)]={"state":"approaching","car":99}
    trip=cabs.book(p,{"name":"Recovery","point":Vector3(147.7,traffic.LEVEL,-30)})
    if not check(not trip.is_empty(),"Stale car assignment is repaired before rebooking"): return
    var car=cabs.cars[trip.car]
    car.node.global_position=trip.pickup_curb
    car.state="waiting"
    trip.state="waiting"
    p.global_position=trip.pickup_curb+Vector3(1,0,0)
    trip.pin="07"
    if not check(cabs.unlock(p,"07") and game.economy.cash(p)==balance-trip.fare,"Leading-zero two-digit code unlocks and takes one fare"): return
    if not check(not cabs.skip_journey(p),"Skip is locked until the boarding doors close"): return
    for i in range(31): cabs._physics_process(.1)
    var treasury=game.economy.data.council
    if not check(cabs.talk(p,"area") and str(p.get_meta("cab_reply","")).begins_with("Aurora:"),"Aurora provides an authored British-voiced scenario reply"): return
    if not check(cabs.skip_journey(p) and not cabs.skip_journey(p),"Skip releases the rider once and cannot be repeated"): return
    if not check(p.riding_service==null and p.visual.visible and game.economy.cash(p)==balance-trip.fare and game.economy.data.council==treasury+trip.fare,"Skipping completes one receipt with no extra debit"): return
    trip=cabs.book(p,{"name":"Timeout","point":Vector3(87.7,traffic.LEVEL,30)})
    cabs.elapsed+=181
    cabs._physics_process(.1)
    if not check(not cabs.bookings.has(game.economy.key_for(p)),"Unreachable pickup expires and frees the booking"): return
    # Close/chase/wide foot camera and rear-follow vehicle camera.
    p.cycle_view()
    p._update_follow(.1)
    if not check(p.camera_mode==1 and is_equal_approx(p.foot_arm.spring_length,2.7),"Camera button changes the walking view"): return
    var body=game.fleet[0]
    var camera=body.get_node("CameraBase/Camera3D")
    camera.make_current()
    camera.camera_type=0
    for angle in [0.0,PI/2,PI]:
        body.rotation.y=angle
        camera.initialized=false
        camera._physics_process(.1)
        if not check((camera.global_position-body.global_position).dot(body.global_basis.z)<-3,"Chase camera follows behind the turned car"): return
    game.process_mode=Node.PROCESS_MODE_DISABLED
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
        audio.stop()
        audio.stream=null
    await create_timer(.2).timeout
    game.queue_free()
    await process_frame
    print("REFINEMENTS_OK: safe stops, cross-traffic gaps, player cab capacity, stale recovery, two-digit PIN, skip, British scenarios and rear camera")
    call_deferred("quit")
