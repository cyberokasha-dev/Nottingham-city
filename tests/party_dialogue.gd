extends SceneTree
func _initialize() -> void:
    OS.set_environment("NOTTINGHAM_TEST","1")
    call_deferred("check_party")
func check_party() -> void:
    var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    preload("res://tests/vehicle_fixtures.gd").install(game)
    game.economy.enabled = false
    game.economy.enforce_tenancy = false
    game.cabs.npc_clock = -100000
    game.city.transport.timetable_enabled = false
    for i in range(ticks(1.25)):
        await physics_frame
    var original = game.player
    if not check(game.party.members.size() == 4 and original.profile.name == "Muhammad" and original.animator.has_animation("fold_arms"), "Muhammad starts in a four-person playable party"):
        return
    var face_mesh = original.visual.find_child("Skeleton3D",true,false)
    if not check(face_mesh != null and original.visual.model.scene_file_path.ends_with("muhammad.glb"), "Personalized model keeps the articulated human rig"):
        return
    original.health = 67
    var original_position = original.global_position
    game.party.toggle_wheel()
    await process_frame
    await process_frame
    var wheel = game.party.wheel
    var reach: float = wheel.radius*0.55
    if not check(wheel.visible and wheel.sector_at(wheel.center+Vector2(reach,-reach)) == 0 and wheel.sector_at(wheel.center+Vector2(reach,reach)) == 1 and wheel.sector_at(wheel.center+Vector2(-reach,reach)) == 2 and wheel.sector_at(wheel.center+Vector2(-reach,-reach)) == 3 and wheel.sector_at(wheel.center+Vector2(wheel.radius+1,0)) == -1, "Four-wheel visible sectors match their click targets at the current HUD size"):
        return
    Input.action_press("walk_forward")
    for i in range(ticks(0.25)):
        await physics_frame
    Input.action_release("walk_forward")
    if not check(original.global_position.distance_to(original_position) < 0.05, "Wheel blocks movement behind the selection UI"):
        return
    for index in [1,2,3,0]:
        var before = game.party.members[index].global_position
        if not check(game.party.choose(index), "Each wheel character can be selected"):
            return
        if not check(game.player == game.party.members[index] and game.player.camera.current and game.population.player == game.player and game.city_map.player == game.player, "Control, camera, map and residents follow selected character"):
            return
        Input.action_press("walk_forward")
        for i in range(ticks(0.291667)):
            await physics_frame
        Input.action_release("walk_forward")
        if not check(game.player.global_position.distance_to(before) > 0.4, "All four characters can walk"):
            return
        Input.action_press("jump")
        for i in range(ticks(0.0166667)):
            await physics_frame
        Input.action_release("jump")
        if not check(game.player.velocity.y > 0, "All four characters can jump"):
            return
        for i in range(ticks(0.666667)):
            await physics_frame
    if not check(game.player.health == 67 and not game.party.wheel.visible, "Muhammad retains independent health across switches"):
        return
    Input.action_press("fold_arms")
    for i in range(ticks(0.333333)):
        await physics_frame
    Input.action_release("fold_arms")
    if not check(original.folded_arms and original.current_clip == "fold_arms", "H performs a deliberate arms-crossed action"):
        return
    Input.action_press("walk_forward")
    for i in range(ticks(0.166667)):
        await physics_frame
    Input.action_release("walk_forward")
    if not check(not original.folded_arms, "Walking restores a normal pose"):
        return
    # A car switch exits safely before handing over control.
    original.global_position = game.fleet[0].global_position+Vector3(2.5,0,0)
    original.velocity = Vector3.ZERO
    for i in range(ticks(0.25)):
        await physics_frame
    if not check(original.try_enter(), "Muhammad enters a vehicle"):
        return
    for i in range(ticks(2.5)):
        await physics_frame
        if not original.transitioning:
            break
    if not check(game.party.choose(1), "A stopped driver may change character"):
        return
    for i in range(ticks(2.5)):
        await physics_frame
        if not game.party.switching:
            break
    if not check(not original.driving and game.player.profile.name == "Aisha" and not game.fleet[0].driver_active and original.visual.visible, "Switching parks the car and restores the old actor on foot"):
        return
    game.party.choose(0)
    for person in game.population.residents:
        person.set_physics_process(false)
    var target = game.population.residents[0]
    original.global_position = Vector3(22,-4.98,45)
    original.health = 100
    target.global_position = Vector3(23.7,-4.98,45)
    target.health = 100
    target.current_house = null
    target.resting = ""
    target.combat_time = 0
    target.opponent = null
    var scene = game.conversation
    if not check(scene.context_for(target) == "street", "Street dialogue matches location"):
        return
    target.relationship = 2
    if not check(scene.context_for(target) == "friend", "An NPC remembers friendly replies"):
        return
    target.relationship = 0
    original.global_position = game.population.places[2].point
    if not check(scene.context_for(target) == "park", "Park dialogue matches location"):
        return
    original.global_position = game.fleet[1].global_position+Vector3(2,0,0)
    if not check(scene.context_for(target) == "car", "Vehicle dialogue matches location"):
        return
    original.active_house = game.city.houses[1]
    if not check(scene.context_for(target) == "house", "Home dialogue matches interior state"):
        return
    original.active_house = null
    original.global_position = Vector3(22,-4.98,45)
    target.health = 30
    if not check(scene.context_for(target) == "injured", "Injury dialogue matches health"):
        return
    target.health = 100
    target.opponent = original
    target.combat_time = 8
    if not check(scene.start(target) and scene.context == "hostile", "Fight can be interrupted by a conversation"):
        return
    for i in range(ticks(13.3333)):
        await physics_frame
        if scene.ready_for_reply:
            break
    if not check(scene.ready_for_reply and original.dialogue.last_line == "hostile_muhammad_open", "Muhammad uses his authored scene opening and gets a reply"):
        return
    if not check(scene.choose(0), "Player selects an apology"):
        return
    for i in range(ticks(14.1667)):
        await physics_frame
        if not scene.active:
            break
    if not check(not scene.active and target.combat_time == 0 and target.opponent == null and target.relationship == 1, "Apology changes the NPC relationship and ends the fight"):
        return
    game.party.choose(1)
    if not check(target.relationship == 0, "Aisha has a separate relationship from Muhammad"):
        return
    game.party.choose(0)
    if not check(target.relationship == 1, "NPC remembers Muhammad's apology after switching back"):
        return
    # Verify all per-character spoken branches exist in both bundled voice banks.
    var data = preload("res://actors/dialogue_data.gd")
    for context in data.SCENES.values():
        for name in ["Muhammad","Aisha","Musa","Jade"]:
            if not check(context.openers[name] in original.dialogue.catalog, "Each protagonist has a voiced context opening"):
                return
            for option in context.options:
                if not check(option.player[name] in original.dialogue.catalog and option.npc in target.dialogue.catalog, "Reply branches have corresponding audio"):
                    return
    scene.target = target
    scene.player = original
    scene.apply_effect("directions")
    if not check(game.city_map.destination_active, "Directions add a map destination"):
        return
    scene.apply_effect("follow")
    if not check(target.follow_actor == original and target.follow_time > 0, "Friendly invitation makes the NPC follow"):
        return
    scene.apply_effect("threat")
    if not check(target.combat_time > 0 and target.opponent == original, "Threatening reply changes NPC behaviour"):
        return
    game.process_mode=Node.PROCESS_MODE_DISABLED
    for sound in game.find_children("*","AudioStreamPlayer",true,false)+game.find_children("*","AudioStreamPlayer3D",true,false):
        sound.stop()
        sound.stream=null
    await create_timer(0.2).timeout
    game.queue_free()
    await process_frame
    print("PARTY_DIALOGUE_OK: personalized starter, four persistent characters, wheel, pose, car switching and consequential voiced scenes")
    call_deferred("quit")
func check(condition: bool,message: String) -> bool:
    if not condition:
        push_error(message)
        quit(1)
        return false
    return true

# Timed interactions retain the same duration when the physics tick rate changes.
func ticks(seconds: float) -> int:
    return maxi(2,roundi(seconds*Engine.physics_ticks_per_second))
