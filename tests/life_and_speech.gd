extends SceneTree
func _initialize() -> void:
    OS.set_environment("NOTTINGHAM_TEST","1")
    call_deferred("check_actions")

func check_actions() -> void:
    var game = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    game.economy.enabled = false
    game.economy.enforce_tenancy = false
    game.cabs.npc_clock = -100000
    game.city.transport.timetable_enabled = false
    for i in range(150):
        await physics_frame
    var player = game.player
    var resident = game.population.residents[0]
    for person in game.population.residents:
        person.set_physics_process(false)
    player.global_position = Vector3(22,-4.98,45)
    player.velocity = Vector3.ZERO
    resident.global_position = Vector3(24,-4.98,45)
    resident.current_house = null
    resident.combat_time = 0
    resident.state = "idle"
    resident.wait_time = 20
    resident.set_physics_process(true)
    for i in range(20):
        await physics_frame
    Input.action_press("interact")
    for i in range(3):
        await physics_frame
    Input.action_release("interact")
    if not check(player.dialogue.last_line == "street_muhammad_open" and player.dialogue.voice.playing, "Interaction starts audible player greeting"):
        return
    for i in range(520):
        await physics_frame
    if not check(game.conversation.active and resident.dialogue.spoken_lines > 0 and resident.dialogue.voice.playing, "Resident gives a timed spoken reply"):
        return
    game.conversation.finish()
    resident.dialogue.muted = true
    var before_spoken = resident.dialogue.spoken_lines
    if not check(not resident.dialogue.speak("hello",true) and before_spoken == resident.dialogue.spoken_lines, "Voice mute prevents playback requests"):
        return
    resident.dialogue.muted = false
    resident.health = 35
    resident.guarding = false
    resident.invulnerability = 0
    resident.receive_hit(player,18)
    await process_frame
    await process_frame
    if not check(resident.health == 17 and resident.hurt_time > 0 and resident.visual.flash_time > 0 and resident.vitals.caption.text == "17 / 100" and resident.vitals.fill.mesh.size.x < 0.2, "NPC damage has health, recoil, flash and visible health bar"):
        return
    resident.receive_hit(player,30)
    if not check(resident.dead and resident.health == 0 and resident.attack_delay < 0 and resident.visual.clip == "death", "Zero health cancels combat and plays death fall"):
        return
    resident.receive_hit(player,30)
    resident.talk_to(player)
    if not check(resident.dead and resident.health == 0 and not resident.try_rest("sleep"), "Dead resident cannot fight, talk or use furniture"):
        return
    for i in range(350):
        await physics_frame
    var skeleton = resident.visual.find_child("Skeleton3D",true,false)
    var head_world = skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head"))
    if not check(resident.health == 0 and resident.dead and not resident.vitals.fill.visible and head_world.origin.y-resident.global_position.y < 0.8, "Resident stays at zero with body fallen on ground"):
        return
    for i in range(650):
        await physics_frame
    if not check(not resident.dead and not resident.waking and resident.health == 100 and resident.visual.clip == "idle", "Resident wakes with health and idle animation restored"):
        return
    resident.set_physics_process(false)
    player.health = 12
    player.guarding = false
    player.invulnerability = 0
    player.receive_hit(resident,18)
    if not check(player.dead and player.health == 0 and not player.try_punch() and not player.try_enter(), "Player zero health locks combat and car entry"):
        return
    var fallen_at = player.global_position
    Input.action_press("walk_forward")
    Input.action_press("jump")
    for i in range(500):
        await physics_frame
    Input.action_release("walk_forward")
    Input.action_release("jump")
    if not check(player.dead and player.health == 0 and player.global_position.distance_to(fallen_at) < 0.2, "Dead player stays down with movement disabled"):
        return
    for i in range(110):
        await physics_frame
    if not check(player.dead and player.waking and player.health == 0, "Player rises before health is restored"):
        return
    for i in range(150):
        await physics_frame
    if not check(not player.dead and not player.waking and player.health == 100 and player.camera.current, "Player wakes with control, camera and health restored"):
        return
    player.receive_hit(resident,18)
    if not check(player.health == 100, "Brief wake protection prevents immediate repeated death"):
        return
    player.active_house = game.city.houses[3]
    player.active_house.set_inside(true)
    player.global_position = player.active_house.rest_approach("sleep")
    player.health = 40
    player.action_time = 0
    if not check(player.try_rest("sleep"), "Sleep remains usable after waking"):
        return
    for i in range(120):
        await physics_frame
    if not check(player.health >= 47 and player.health <= 49, "Sleep restores health at eight points per second"):
        return
    player.stand_up()
    for sound in game.find_children("*","AudioStreamPlayer",true,false):
        sound.stop()
    for sound in game.find_children("*","AudioStreamPlayer3D",true,false):
        sound.stop()
    await create_timer(0.1).timeout
    game.queue_free()
    await process_frame
    print("LIFE_SPEECH_OK: visible damage, real fall and waking, immunity, voice turns, mute and healing")
    call_deferred("quit")

func check(condition: bool, description: String) -> bool:
    if not condition:
        push_error(description)
        quit(1)
        return false
    return true
