extends SceneTree
func _initialize():
    OS.set_environment("NOTTINGHAM_TEST","1")
    call_deferred("run")
func check(value: bool, reason: String) -> bool:
    if not value:
        push_error(reason)
        quit(1)
    return value
func run():
    var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
    root.add_child(game)
    var e=game.economy
    e.enabled=false
    game.cabs.npc_clock=-100000
    for bus in game.city.transport.buses: bus.set_physics_process(false)
    game.city.traffic.set_process(false)
    for item in game.city.traffic.cars: item.node.hide()
    game.city.traffic.autonomous_nodes.clear()
    game.city.traffic.cars.clear()
    game.city.traffic.pedestrians.clear()
    game.city.traffic.transport=null
    var p=game.player
    p.set_physics_process(false)
    var account: Dictionary=e.account_for(p)
    var ids={}
    for house in game.city.houses:
        if not check(house.house_number>0 and not ids.has(house.house_number),"Globally unique council house numbers"): return
        ids[house.house_number]=true
    var available=0
    for id in e.houses:
        if e.house_record(id).tenant=="":
            available=id
            break
    var house=e.houses[available]
    if not check(not e.can_access(p,house),"Unrented council home is locked"): return
    account.balance=39999
    if not check(not e.rent(p,available),"Cannot rent without full first month"): return
    account.balance=150000
    var treasury: int=e.data.council
    if not check(e.rent(p,available) and int(account.balance)==110000 and int(e.data.council)==treasury+40000,"Rent transfers exact pence into council treasury"): return
    if not check(e.can_access(p,house) and not e.rent(game.party.members[1],available),"Tenant access and double-rental prevention"): return
    e.data.seconds=30*300.0
    account.balance=0
    e.process_rents()
    if not check(int(account.arrears)==40000,"Insufficient monthly rent creates arrears"): return
    account.balance=50000
    if not check(e.pay_rent(p) and int(account.arrears)==0 and int(account.balance)==10000,"Arrears payment is exact and clears debt"): return
    p.global_position=e.office
    if not check(e.apply_job(p,"Cleaner"),"Player applies for work at council office"): return
    if not check(e.perform_work(p,20) and not e.perform_work(p,20),"Work pays once per game day"): return
    if not check(e.loan(p,50000) and int(account.loan)==50000 and not e.loan(p,50000),"Council loans are funded and prevent stacking"): return
    if not check(e.repay(p,10000) and int(account.loan)==40000,"Loan repayment reduces debt"): return
    # A rent officer can collect affordable arrears and log unpaid visits.
    var tenant=game.population.residents[1]
    var tenant_account: Dictionary=e.account_for(tenant)
    tenant_account.arrears=40000
    tenant_account.balance=50000
    e.data.seconds=float(e.data.seconds)+300
    account.job="Rent officer"
    p.global_position=e.assignment(p).point
    if not check(e.perform_work(p,20) and int(tenant_account.arrears)==0 and e.data.notices[-1].paid,"Rent officer visits a house and collects affordable arrears"): return
    tenant_account.arrears=40000
    tenant_account.balance=0
    e.data.seconds=float(e.data.seconds)+300
    p.global_position=e.assignment(p).point
    if not check(e.perform_work(p,20) and int(tenant_account.arrears)==40000 and not e.data.notices[-1].paid,"Unpaid rent visit preserves arrears without inventing money"): return
    account.balance=200000
    var network=game.city.transport
    var bus=network.buses[0]
    bus.arrive(1)
    bus.model.animate_doors(1)
    p.global_position=bus.entrance()
    var balance: int=account.balance
    if not check(bus.board(p) and int(account.balance)==balance-200,"Player pays £2 bus fare"): return
    if not check(not bus.board(p),"Duplicate boarding cannot charge again"): return
    bus.leave(p)
    if not check(network.board_next(bus) and bus.manifest.size()==1,"An actual queued commuter pays and boards"): return
    if not check(network.reserve_departure("TEST")==network.elapsed and network.reserve_departure("TEST")==network.elapsed+90,"City terminus departures are separated by 90 seconds"): return
    await create_timer(1.5).timeout
    var commuter=bus.manifest[0].person
    if not check(commuter.get_parent()==bus,"Commuter physically follows the bus after boarding"): return
    bus.arrive(bus.manifest[0].destination)
    if not check(bus.manifest.is_empty() and commuter.get_parent()==network,"Commuter alights at booked stop"): return
    var cabs=game.cabs
    cabs.set_physics_process(false)
    p.global_position=Vector3(42.8,game.city.traffic.LEVEL,30)
    var destination={"name":"Test house","point":Vector3(87.7,game.city.traffic.LEVEL,-25)}
    var trip: Dictionary=cabs.book(p,destination)
    if not check(not trip.is_empty() and trip.pin.length()==4,"Phone booking assigns a four-digit PIN"): return
    for frame in range(2400):
        game.city.traffic.clock=fposmod(frame*0.1,24)
        cabs._physics_process(0.1)
        if trip.state=="waiting": break
    if not check(trip.state=="waiting","Aurora reaches the pickup along roads"): return
    p.global_position=trip.pickup_curb+Vector3(1,0,0)
    balance=account.balance
    if not check(not cabs.unlock(p,"wrong") and int(account.balance)==balance,"Wrong boarding PIN cannot charge or unlock"): return
    if not check(cabs.unlock(p,trip.pin) and int(account.balance)==balance-int(trip.fare),"Correct PIN charges the quoted fare once"): return
    if not check(not cabs.unlock(p,trip.pin),"PIN cannot be reused for duplicate fare"): return
    for frame in range(3600):
        game.city.traffic.clock=fposmod(frame*0.1,24)
        cabs._physics_process(0.1)
        if not cabs.bookings.has(e.key_for(p)): break
    if not check(p.riding_service==null and not cabs.bookings.has(e.key_for(p)) and p.visual.visible,"Aurora completes the destination and releases the rider"): return
    for audio in game.find_children("*","AudioStreamPlayer3D",true,false): audio.stop()
    game.queue_free()
    await process_frame
    print("ECONOMY_SERVICES_OK: rent, wages, arrears, loans, paid boarding, timetable, PIN and complete autonomous journey")
    quit()
