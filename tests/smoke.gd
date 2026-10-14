extends SceneTree

func _initialize():
    OS.set_environment("NOTTINGHAM_TEST","1")
    call_deferred("check_world")

func check_world():
    var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    game.economy.enabled = false
    game.economy.enforce_tenancy = false
    game.cabs.npc_clock = -100000
    game.city.transport.economy = null
    for i in range(150):
        await physics_frame
    if not check(game.has_node("TruckTown/Player") or is_instance_valid(game.player), "Launch directly into the world"):
        return
    var player = game.player
    var fleet = game.fleet
    var resident_starts = {}
    for resident in game.population.residents:
        resident_starts[resident] = resident.global_position
    if not check(game.population.residents.size() == 32 and get_nodes_in_group("people").size() == 36, "Thirty-two rigged autonomous neighbours"):
        return
    if not check(game.population.residents[0].conversations > 0 and game.population.residents[1].conversations > 0, "Neighbours stop and talk together"):
        return
    if not check(InputMap.action_get_events("interact").size() >= 2 and InputMap.has_action("guard"), "Keyboard and gamepad actions coexist"):
        return
    if not check(fleet.size() == 6 and get_nodes_in_group("driveable_vehicles").size() == 6, "Six enterable vehicles coexist"):
        return
    if not check(not player.driving and player.camera.current and player.visual.visible and player.is_on_floor(), "Spawn standing on foot with the human visible"):
        return
    if not check(not game.town.has_node("Back"), "No car selection menu"):
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
    if not check(game.city.houses.size() == 68 and get_nodes_in_group("enterable_houses").size() == 68, "Every residential door has a house"):
        return
    for house in [game.city.houses[0],game.city.houses[17],game.city.houses[67]]:
        player.global_position = house.entrance()
        player.velocity = Vector3.ZERO
        if not check(player.nearest_house() == house and player.try_house(house), "Enter " + house.address):
            return
        if not check(not player.try_house(house), "Repeated interaction does not interrupt door transition"):
            return
        await finish_transition(player)
        for i in range(20):
            await physics_frame
        if not check(player.active_house == house and house.occupied and not house.roof.visible and is_instance_valid(house.interior) and player.is_on_floor(), "House interior is reachable and furnished"):
            return
        for action in ["sit","sleep"]:
            player.global_position = house.rest_approach(action)
            player.velocity = Vector3.ZERO
            if not check(player.try_rest(action) and player.resting == action and player.collider.disabled, "Use house furniture: " + action):
                return
            if not check(not house.claim_rest(action,game.population.residents[0]) and not player.try_punch(), "Furniture occupancy and resting prevent overlapping actions"):
                return
            for i in range(15):
                await physics_frame
            if not check(player.stand_up() and player.resting == "" and not player.collider.disabled, "Stand or wake restores control"):
                return
            for i in range(20):
                await physics_frame
            if not check(player.is_on_floor(), "Safe standing position beside furniture"):
                return
        if not check(not player.try_enter(), "Cannot enter a parked car from inside a house"):
            return
        var wall_ray = PhysicsRayQueryParameters3D.create(house.to_global(Vector3(0,1,0)),house.to_global(Vector3(7,1,0)))
        var wall_hit = game.town.get_world_3d().direct_space_state.intersect_ray(wall_ray)
        if not check(not wall_hit.is_empty() and house.is_ancestor_of(wall_hit.collider), "House walls stop the player"):
            return
        var before_inside = player.global_position
        player.yaw = house.rotation.y
        Input.action_press("walk_forward")
        for i in range(60):
            await physics_frame
        Input.action_release("walk_forward")
        if not check(player.global_position.distance_to(before_inside) > 1.0, "Walk around inside the house"):
            return
        player.global_position = house.inside_point()
        player.velocity = Vector3.ZERO
        if not check(player.try_house(house), "Leave through the door"):
            return
        await finish_transition(player)
        for i in range(20):
            await physics_frame
        if not check(not is_instance_valid(player.active_house) and not house.occupied and house.roof.visible and not player.collider.disabled and player.is_on_floor(), "Exit restores exterior camera and collisions"):
            return
    var moving_residents = 0
    for resident in resident_starts:
        if resident.global_position.distance_to(resident_starts[resident]) > 2:
            moving_residents += 1
    if not check(moving_residents >= 8, "Residents move independently along their routines"):
        return
    # Isolate one resident for repeatable real strike timing and guard tests.
    var target = game.population.residents[0]
    for resident in game.population.residents:
        resident.set_physics_process(false)
    target.current_house = null
    target.resting = ""
    target.house_transition = false
    target.state = "idle"
    target.health = 100
    target.guarding = false
    player.global_position = Vector3(22,-4.98,45)
    player.velocity = Vector3.ZERO
    player.yaw = 0
    for i in range(20):
        await physics_frame
    target.global_position = player.global_position + Vector3(0,0,-1.3)
    if not check(player.try_punch() and not player.try_punch(), "Punch starts with cooldown"):
        return
    for i in range(30):
        await physics_frame
    if not check(target.health == 82, "Timed punch deals damage once inside reach"):
        return
    for i in range(60):
        await physics_frame
    target.health = 100
    target.guarding = true
    target.visual.rotation.y = PI
    player.try_punch(true)
    for i in range(110):
        await physics_frame
    if not check(target.health == 100, "Facing guard blocks heavy punch"):
        return
    target.guarding = false
    target.global_position += Vector3(0,0,-4)
    player.try_punch()
    for i in range(80):
        await physics_frame
    if not check(target.health == 100, "Punch cannot hit a distant resident"):
        return
    target.global_position = player.global_position+Vector3(0,0,-1)
    player.guarding = true
    player.visual.rotation.y = 0
    var health_before = player.health
    player.receive_hit(target,18)
    if not check(player.health == health_before, "Player can block an incoming punch"):
        return
    player.guarding = false
    player.receive_hit(target,18)
    if not check(player.health == health_before-18, "Incoming hit affects player health"):
        return
    # A physical wall blocks a strike even when both people are within reach.
    var barrier = StaticBody3D.new()
    var barrier_shape = CollisionShape3D.new()
    var barrier_box = BoxShape3D.new()
    barrier_box.size = Vector3(3,3,0.1)
    barrier_shape.shape = barrier_box
    barrier.add_child(barrier_shape)
    barrier.position = player.global_position+Vector3(0,1,-0.5)
    game.town.add_child(barrier)
    target.health = 100
    await physics_frame
    preload("res://actors/combat.gd").strike(player,Vector3.FORWARD,18)
    if not check(target.health == 100, "Walls block short range strikes"):
        return
    barrier.queue_free()
    await physics_frame
    target.opponent = player
    target.combat_time = 5
    target.action_time = 0
    target.state = "fight"
    target.set_physics_process(true)
    var before_counter = player.health
    for i in range(360):
        await physics_frame
    if not check(player.health < before_counter, "Resident defends itself with an animated counter punch"):
        return
    target.set_physics_process(false)
    target.combat_time = 0
    target.attack_delay = -1
    target.current_house = game.city.houses[3]
    if not check(target.try_rest("sleep") and target.resting == "sleep", "Residents share bed actions"):
        return
    target.stand_up()
    if not check(target.resting == "" and not target.collider.disabled, "Residents wake and resume control"):
        return
    target.current_house = null
    target.combat_time = 0
    target.action_time = 0
    target.attack_delay = -1
    target.opponent = null
    target.wants_home = true
    target.travel_count = 3
    target.global_position = target.home.entrance()
    target.set_physics_process(true)
    target._arrive()
    for i in range(200):
        await physics_frame
    if not check(target.current_house == target.home and target.resting == "sleep", "Resident enters home and chooses bed from routine"):
        return
    for i in range(2100):
        await physics_frame
    if not check(target.current_house == null and target.resting == "" and not target.house_transition and not target.collider.disabled and target.state == "walk", "Resident wakes, exits home and walks to next place"):
        return
    for x in game.city.ROAD_X:
        for z in game.city.ROAD_Z:
            var ray = PhysicsRayQueryParameters3D.create(Vector3(x,10,z),Vector3(x,-20,z))
            ray.collision_mask = 1 # Terrain and buildings; moving transport uses layer 2.
            var hit = game.town.get_world_3d().direct_space_state.intersect_ray(ray)
            if not check(not hit.is_empty() and absf(hit.position.y-game.LOT_Y) < 0.02, "All 30 road junctions have level ground"):
                return
    for audio in game.find_children("*", "AudioStreamPlayer3D", true, false):
        audio.stop()
    await create_timer(0.1).timeout
    game.queue_free()
    await process_frame
    print("SMOKE_OK: city, fleet, houses, residents, dialogue, timed combat, guard, furniture and gamepad mappings")
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
