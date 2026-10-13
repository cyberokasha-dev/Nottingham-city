extends SceneTree

func _initialize():
    call_deferred("check_demo")

func check_demo():
    var menu = load("res://car_select/car_select.tscn").instantiate()
    root.add_child(menu)
    await process_frame
    for choice in ["_on_mini_van_pressed", "_on_tow_truck_pressed", "_on_trailer_truck_pressed"]:
        menu.call(choice)
        for i in range(120):
            await physics_frame
        if not is_instance_valid(menu.town):
            push_error("Vehicle did not load: " + choice)
            quit(1)
            return
        var player = menu.town.get_node("Player")
        var vehicle = player.vehicle
        if not check(not player.driving and player.camera.current, "Spawn on foot with walking camera"):
            return
        if not check(player.is_on_floor(), "Character settles on town ground: " + choice):
            return
        var skeleton = player.visual.find_child("Skeleton3D", true, false)
        if not check(skeleton.get_bone_count() >= 65 and skeleton.find_bone("hand_l") >= 0 and skeleton.find_bone("index_03_r") >= 0, "Human has articulated hands and fingers"):
            return
        for clip in ["idle", "walk", "run", "jump_start", "jump_air", "land", "enter", "exit"]:
            if not check(player.animator.has_animation(clip), "Imported motion: " + clip):
                return
        var before = player.global_position
        Input.action_press("walk_forward")
        Input.action_press("accelerate")
        for i in range(35):
            await physics_frame
        Input.action_release("walk_forward")
        Input.action_release("accelerate")
        if not check(player.global_position.distance_to(before) > 0.5, "W walks"):
            return
        if not check(vehicle.engine_force == 0.0, "Parked car ignores throttle"):
            return
        Input.action_press("jump")
        await physics_frame
        await physics_frame
        Input.action_release("jump")
        if not check(player.velocity.y > 0, "Space jumps"):
            return
        player.global_position = vehicle.global_position + Vector3(15, 0, 0)
        if not check(not player.try_enter(), "Cannot enter distant car"):
            return
        player.global_position = vehicle.global_position + Vector3(2, 0, 0)
        if not check(player.try_enter(), "Enter nearby car"):
            return
        if not check(not player.try_enter() and not player.try_exit(), "Repeated interaction is ignored during entry"):
            return
        if not check(player.transitioning and not vehicle.driver_active, "Entry locks controls before seating"):
            return
        for i in range(300):
            await physics_frame
            if not player.transitioning:
                break
        if not check(player.driving and player.collider.disabled and not player.visual.visible and vehicle.driver_active, "Driving state owns controls"):
            return
        Input.action_press("accelerate")
        for i in range(45):
            await physics_frame
        Input.action_release("accelerate")
        if not check(vehicle.linear_velocity.length() > 1.0, "Occupied car accelerates"):
            return
        if not check(not player.try_exit(), "Cannot exit moving car"):
            return
        Input.action_press("jump")
        for i in range(240):
            await physics_frame
        Input.action_release("jump")
        if not check(player.try_exit(), "Exit safely beside stopped car"):
            return
        for i in range(180):
            await physics_frame
            if not player.transitioning:
                break
        if not check(not player.driving and not player.collider.disabled and player.visual.visible and player.camera.current and not vehicle.driver_active, "Exit restores walking and parks car"):
            return
        for i in range(30):
            await physics_frame
        if not check(player.is_on_floor(), "Exit places character on ground"):
            return
        if not check(player.try_enter(), "Re-enter car after exit"):
            return
        for i in range(300):
            await physics_frame
            if not player.transitioning:
                break
        if not check(player.driving and not player.transitioning, "Re-entry finishes and restores driving"):
            return
        for audio in menu.town.find_children("*", "AudioStreamPlayer3D", true, false):
            audio.stop()
        await create_timer(0.1).timeout
        menu._on_back_pressed()
        menu.town = null
        await process_frame
    menu.queue_free()
    await process_frame
    print("SMOKE_OK: all three vehicles support walking, jumping, entering, driving, safe exiting and re-entry")
    call_deferred("quit")

func check(condition: bool, description: String) -> bool:
    if not condition:
        push_error(description)
        quit(1)
        return false
    return true
