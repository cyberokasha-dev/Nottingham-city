extends SceneTree
func _initialize():
    OS.set_environment("NOTTINGHAM_TEST","1")
    call_deferred("run")
func run():
    var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    game.economy.enabled=false
    game.cabs.npc_clock=-100000
    var traffic=game.city.traffic
    traffic.set_process(false)
    var p=game.player
    for frame in range(150): await physics_frame
    var item: Dictionary=traffic.cars[0]
    p.global_position=item.node.global_position+Vector3(2.7,0.2,0)
    p.velocity=Vector3.ZERO
    if await traffic.claim_car(p) or p.driving or item.get("taken",false) or not item.node.visible:
        push_error("Street traffic cannot be taken without a council rental")
        quit(1);return
    game.phone.panel.hide()
    if not game.services.rent_vehicle(p,"car","hour"):
        push_error("Player can rent a private Aurora at the depot")
        quit(1);return
    var body:VehicleBody3D=game.fleet[0]
    p.global_position=body.global_position+Vector3(2.5,0,0);p.velocity=Vector3.ZERO
    if not p.try_enter():
        push_error("The paid Aurora rental can be entered")
        quit(1);return
    for frame in range(180):
        await physics_frame
        if p.driving and not p.transitioning:break
    if not p.driving or not item.node.visible or game.fleet.size()!=1:
        push_error("Renting creates one vehicle while street traffic stays intact")
        quit(1);return
    for frame in range(15): await physics_frame
    p.try_exit()
    for frame in range(180):
        await physics_frame
        if not p.transitioning: break
    game.process_mode = Node.PROCESS_MODE_DISABLED
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
        audio.stop()
        audio.stream = null
    await create_timer(0.2).timeout
    game.queue_free()
    await process_frame
    print("STREET_CAR_OK: paid physical entry, rental ownership and intact public traffic")
    call_deferred("quit")
