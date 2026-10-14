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
    var e=game.economy
    var cabs=game.cabs
    var traffic=game.city.traffic
    var network=game.city.transport
    var music=game.bus_recitation
    p.set_physics_process(false)
    cabs.set_physics_process(false)
    traffic.set_process(false)
    for bus in network.buses: bus.set_physics_process(false)
    for service in network.buses:
        for x in traffic.ROAD_X:
            for z in traffic.ROAD_Z:
                if not check(absf(service.position.x-x)>=14 or absf(service.position.z-z)>=14,"Buses start outside committed junction boxes"): return
    # Every possible arrival phase in either direction gets green within five seconds.
    for vertical in [true,false]:
        for step in range(900):
            var time=step/100.0
            var delay=0.0
            while delay<5.02:
                traffic.clock=fposmod(time+delay,traffic.CYCLE)
                if not check(not (traffic._green(true) and traffic._green(false)),"Opposing greens never overlap"): return
                if traffic._green(vertical): break
                delay+=.01
            if not check(delay<=5.01,"Both directions receive green within five seconds at every phase"): return
    # Routes turning or returning along a street cannot make a reversing segment.
    var places=[Vector3(45.5,-5.02,30),Vector3(147.7,-5.02,-90),Vector3(-132.3,-5.02,-22),Vector3(-32.3,-5.02,110),Vector3(87.7,-5.02,48),Vector3(-18,-5.02,72)]
    for from in places:
        for to in places:
            var path=cabs.path_between(from,to)
            if not check(not path.is_empty(),"Directed road graph reaches every test destination"): return
            var previous=Vector3.ZERO
            for i in range(1,path.size()):
                var direction=(path[i]-path[i-1]).normalized()
                if direction.length()<.1: continue
                if not check(previous.dot(direction)>-.05,"Cab route has no lane-reversing or U-turn segment"): return
                previous=direction
                var on_road=false
                for x in traffic.ROAD_X: on_road=on_road or absf(path[i].x-x)<5.8
                for z in traffic.ROAD_Z: on_road=on_road or absf(path[i].z-z)<5.8
                if not check(on_road,"Cab turns stay on the road grid"): return
    # A right-turning bus must wait outside for opposing traffic, preventing the live deadlock.
    var opponent=Node3D.new()
    opponent.position=Vector3(88,traffic.LEVEL,82.8)
    opponent.rotation.y=-PI/2
    root.add_child(opponent)
    var rules=preload("res://town/traffic.gd").new()
    rules.clock=4.5
    rules.autonomous_nodes.append(opponent)
    if not check(rules.allowed_travel(Vector3(68,traffic.LEVEL,77.2),Vector3.RIGHT,1,5.2,null)==0,"A committed opposing vehicle holds a turning bus outside the junction"): return
    opponent.position.x=100
    if not check(rules.allowed_travel(Vector3(68,traffic.LEVEL,77.2),Vector3.RIGHT,1,5.2,null)>0,"Junction entry resumes when the opposing vehicle clears"): return
    opponent.free()
    rules.free()
    p.global_position=Vector3(47.7,traffic.LEVEL,35)
    var pickup=cabs.book(p,{"name":"Test","point":Vector3(147.7,traffic.LEVEL,-90)})
    if not check(not pickup.is_empty() and pickup.car<2,"Dispatch uses a nearby clear curb pickup instead of making a needless road loop"): return
    cabs.cancel(p)
    var parked=cabs.cars[0]
    var second=cabs.cars[2]
    second.node.global_position=parked.node.global_position
    cabs._park_at_curb(second)
    if not check(traffic.space_clear(second.node.position,second.node.global_basis.z,second.node),"Cabs sharing a destination choose distinct clear curb spaces"): return
    # Local player pays exactly once; insufficient money never sets ride state or starts audio.
    var bus=network.buses[0]
    bus.arrive(1)
    bus.model.animate_doors(1)
    p.global_position=bus.entrance()
    var account=e.account_for(p)
    account.balance=199
    var treasury=e.data.council
    if not check(not bus.board(p) and p.riding_bus==null and e.data.council==treasury and account.balance==199,"£1.99 cannot board a £2 bus or change the ledger"): return
    if not check(not music.audio.playing and music.audio.stream==null and not music.panel.visible,"Quran is silent while standing outside, including a failed boarding"): return
    account.balance=200
    if not check(bus.board(p) and account.balance==0 and e.data.council==treasury+200,"A £2 balance boards and transfers the exact fare"): return
    if not check(not bus.board(p) and account.balance==0,"Repeated boarding cannot double charge"): return
    if not check(music.audio.playing and music.audio.max_polyphony==1 and music.panel.visible,"Only one Quran stream starts after a successful player boarding"): return
    var first=music.track_index
    music._next_track()
    if not check(music.track_index==(first+1)%12 and music.audio.playing,"Next surah replaces the current stream rather than overlapping"): return
    music.set_enabled(false)
    if not check(not music.audio.playing,"Passenger can turn recitation off immediately"): return
    music.set_enabled(true)
    if not check(music.audio.playing,"Passenger can turn recitation on again"): return
    bus.rider_board_clock=3
    if not check(bus.leave(p) and not music.audio.playing and music.audio.stream==null and not music.panel.visible,"Leaving stops and releases the recitation immediately"): return
    # No free mode when payment backend is absent.
    var saved=network.economy
    network.economy=null
    p.global_position=bus.entrance()
    account.balance=1000
    if not check(not bus.board(p) and account.balance==1000,"Missing payment service refuses boarding rather than granting a free ride"): return
    network.economy=saved
    # Every bus has a different starting surah; all clips are complete local recordings.
    var seeds={}
    for service in network.buses: seeds[service.get_meta("quran_seed")]=true
    if not check(seeds.size()==12,"Twelve buses start with twelve different surahs"): return
    for track in music.TRACKS:
        var recording=load("res://transport/recitations/%03d.ogg" % track[0])
        if not check(recording is AudioStreamOggVorbis and recording.get_length()>10,"Each surah has a locally decodable full recording"): return
    game.process_mode=Node.PROCESS_MODE_DISABLED
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
        audio.stop()
        audio.stream=null
    await create_timer(.2).timeout
    game.queue_free()
    await process_frame
    print("TRAFFIC_AUDIO_OK: five-second reds, directed cab routes, strict fares, passenger-only Sudais, mute, track switching and silent exit")
    call_deferred("quit")
