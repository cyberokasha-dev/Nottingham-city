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
    if not await traffic.claim_car(p):
        push_error("Street car claim must enter its physical vehicle")
        quit(1)
        return
    for frame in range(180):
        await physics_frame
        if p.driving and not p.transitioning: break
    if not p.driving or not item.taken or item.node.visible or game.fleet.size()!=7:
        push_error("Claim creates one drivable car and removes its AI duplicate")
        quit(1)
        return
    for frame in range(15): await physics_frame
    p.try_exit()
    for frame in range(180):
        await physics_frame
        if not p.transitioning: break
    await create_timer(0.1).timeout
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false): audio.stop()
    game.queue_free()
    await process_frame
    print("STREET_CAR_OK: physical entry and no AI duplicate")
    quit()
