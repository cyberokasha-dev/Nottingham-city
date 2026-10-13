extends SceneTree

func _initialize():
    call_deferred("check_world")

func check_world():
    var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    for i in range(150):
        await physics_frame
    if not check(game.has_node("TruckTown/Player") or is_instance_valid(game.player), "Launch directly into the world"):
        return
    var player = game.player
    var fleet = game.fleet
    if not check(fleet.size() == 6 and get_nodes_in_group("driveable_vehicles").size() == 6, "Six enterable vehicles coexist"):
        return
    if not check(not player.driving and player.camera.current and player.visual.visible and player.is_on_floor(), "Spawn standing on foot with the human visible"):
        return
    if not check(not game.town.get_node("Back").visible, "No car selection menu"):
        return
    var skeleton = player.visual.find_child("Skeleton3D", true, false)
    if not check(skeleton.find_bone("hand_l") >= 0 and skeleton.find_bone("index_03_r") >= 0, "Articulated hands and fingers"):
        return
    var before = player.global_position
    Input.action_press("walk_forward")
    for i in range(35):
        await physics_frame
    Input.action_release("walk_forward")
    if not check(player.global_position.distance_to(before) > 0.5, "Human walks"):
        return
    Input.action_press("jump")
    await physics_frame
    await physics_frame
    Input.action_release("jump")
    if not check(player.velocity.y > 0, "Human jumps"):
        return
    player.global_position = Vector3(35,-5,40)
    if not check(not player.try_enter(), "Cannot remotely enter a vehicle"):
        return
    for vehicle in fleet:
        player.global_position = vehicle.global_position + Vector3(2.5,0,0)
        player.velocity = Vector3.ZERO
        if not check(player.nearest_vehicle() == vehicle, "Select nearest: " + vehicle.display_name):
            return
        if not check(player.try_enter(), "Enter: " + vehicle.display_name):
            return
        if not check(not player.try_enter() and not player.try_exit(), "Repeated E cannot interrupt entry"):
            return
        await finish_transition(player)
        if not check(player.driving and vehicle.driver_active and player.collider.disabled and not player.visual.visible, "Entry finishes: " + vehicle.display_name):
            return
        if not check(game.town.get_node("Spedometer").car_body == vehicle, "Speedometer follows active vehicle"):
            return
        var parked_positions = {}
        for other in fleet:
            if other != vehicle:
                parked_positions[other] = other.global_position
        Input.action_press("accelerate")
        for i in range(70):
            await physics_frame
        Input.action_release("accelerate")
        if not check(vehicle.linear_velocity.length() > 1.0, "Drive: " + vehicle.display_name):
            return
        for other in parked_positions:
            if not check(other.global_position.distance_to(parked_positions[other]) < 0.05 and other.engine_force == 0, "Unoccupied vehicles remain parked"):
                return
        if not check(not player.try_exit(), "Block moving exit"):
            return
        Input.action_press("jump")
        for i in range(300):
            await physics_frame
        Input.action_release("jump")
        if not check(player.try_exit(), "Exit: " + vehicle.display_name):
            return
        await finish_transition(player)
        for i in range(30):
            await physics_frame
        if not check(not player.driving and not player.transitioning and player.visual.visible and player.camera.current and not vehicle.driver_active and vehicle.freeze and player.is_on_floor(), "Exit restores walking and parks: " + vehicle.display_name):
            return
    for audio in game.find_children("*", "AudioStreamPlayer3D", true, false):
        audio.stop()
    await create_timer(0.1).timeout
    game.queue_free()
    await process_frame
    print("SMOKE_OK: direct on-foot start, six nearby vehicles, nearest selection, independent driving and safe transitions")
    call_deferred("quit")

func finish_transition(player):
    for i in range(360):
        await physics_frame
        if not player.transitioning:
            break

func check(condition: bool, description: String) -> bool:
    if not condition:
        push_error(description)
        quit(1)
        return false
    return true
