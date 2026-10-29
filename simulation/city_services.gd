extends Node
# Rentals, work contracts and the city credential share the existing pounds ledger.
const W=preload("res://town/world_layout.gd")
const CATALOG := {
 "sports":{"name":"Sports sedan","kind":"sports","hour":3000,"week":18000},
 "suv":{"name":"Family SUV","kind":"suv","hour":3500,"week":21000},
 "van":{"name":"City van","kind":"van","hour":2500,"week":15000},
 "tow":{"name":"Tow truck","kind":"tow","hour":4500,"week":27000},
 "trailer":{"name":"Articulated truck","kind":"trailer","hour":6000,"week":36000},
 "car":{"name":"Aurora • private use","kind":"cybercab","hour":4000,"week":24000},
 "Robovan":{"name":"Robovan • private use","kind":"service","hour":5000,"week":30000},
 "bus_private":{"name":"City bus • private use","kind":"bus","hour":6000,"week":36000},
 "Bus":{"name":"Public bus work rental","kind":"service","hour":6000,"week":36000},
 "Aurora":{"name":"Aurora work rental","kind":"service","hour":4000,"week":24000},
 "Helicopter":{"name":"Helicopter work rental","kind":"service","hour":10000,"week":60000},
 "Train":{"name":"City Circle train work rental","kind":"service","hour":9000,"week":54000}}
const TERMS={"hour":3600,"week":604800}
var game:Node3D
var spawned:Dictionary={}
var operators:Dictionary={}
var operators_by_account:Dictionary={}
var aboard:Dictionary={}
var dispatch:RefCounted
var work:RefCounted
var simple:RefCounted
var private_hire:RefCounted
var clock:=0.0
var ticket_vehicle:Node3D
var ticket_serial:=0
func _ready() -> void:
 name="CityServices"
 ensure_data()
 _assign_counters()
 work=preload("res://simulation/work_dispatch.gd").new();work.services=self
 private_hire=preload("res://simulation/private_rentals.gd").new();private_hire.services=self
 dispatch=preload("res://simulation/driver_dispatch.gd").new();dispatch.services=self
 simple=preload("res://simulation/simple_transport.gd").new();simple.services=self
 _restore_jobs();private_hire.restore()
 game.economy.save();game.economy.flush_save()
func ensure_data() -> void:
 var d:Dictionary=game.economy.data
 for key in ["vehicle_rentals","transport_work","operator_payments"]:
  if not d.has(key):d[key]={}
 if not d.has("city_identity"):
  var alphabet="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  var bytes=Crypto.new().generate_random_bytes(16)
  var code=""
  for byte in bytes:code+=alphabet[int(byte)%alphabet.length()]
  d.city_identity={"code":code,"created":Time.get_unix_time_from_system()}
 for pass_record in d.get("travel_passes",{}).values():pass_record.code=d.city_identity.code
 if not d.has("next_contract"):d.next_contract=1
func access_code() -> String:return str(game.economy.data.city_identity.code)
func normal_code(value:String) -> String:return value.to_upper().replace("-","").replace(" ","").strip_edges()
func code_matches(value:String) -> bool:return normal_code(value)==access_code()
func rental(person:Node,kind:String) -> Dictionary:
 var key:String=game.economy.key_for(person)
 var lease:Dictionary=_work_lease(key,kind)
 return lease if float(lease.get("expires",0))>Time.get_unix_time_from_system() else {}
func physical_kind(kind:String) -> String:
 if kind in ["Bus","bus_private"]:return "bus"
 if kind in ["Aurora","car"]:return "cybercab"
 return str(CATALOG[kind].kind)
func rent_vehicle(person:Node,kind:String,term:String,delivery:=false) -> bool:
 if not CATALOG.has(kind) or not TERMS.has(term):return false
 if not rental(person,kind).is_empty():
  game.economy.last_error="This rental is already active. No extra payment taken.";return false
 var key:String=game.economy.key_for(person)
 if key=="":return false
 var slot:=Vector3.ZERO
 if CATALOG[kind].kind!="service" and (not delivery or kind!="car"):
  slot=_free_slot(kind)
  if slot==Vector3.ZERO:game.economy.last_error="The depot bays are occupied. Return a vehicle before renting another.";return false
 if not game.economy.charge(person,int(CATALOG[kind][term]),CATALOG[kind].name+" • "+term+" rental"):return false
 if not game.economy.data.vehicle_rentals.has(key):game.economy.data.vehicle_rentals[key]={}
 var lease={"id":int(game.economy.data.next_contract),"kind":kind,"term":term,"expires":Time.get_unix_time_from_system()+int(TERMS[term]),"owner":key}
 game.economy.data.next_contract=int(game.economy.data.next_contract)+1
 game.economy.data.vehicle_rentals[key][kind]=lease
 if CATALOG[kind].kind!="service" and not delivery:_spawn(lease,slot)
 game.economy.save();game.economy.flush_save()
 return true
func _free_slot(kind:String) -> Vector3:
 for p in [Vector3(-20,W.LEVEL+.65,30),Vector3(0,W.LEVEL+.65,30),Vector3(20,W.LEVEL+.65,30),Vector3(-2,W.LEVEL+.65,65),Vector3(17,W.LEVEL+.65,65)]:
  if kind=="trailer" and p.z>40:continue # Long rigs collect away from the council-office doorway.
  var free:=true
  for body in game.fleet:if is_instance_valid(body) and body.global_position.distance_to(p)<13:free=false
  if free:return p
 return Vector3.ZERO
func _spawn(lease:Dictionary,slot:Vector3) -> void:
 var rig=preload("res://vehicles/vehicle_factory.gd").make(physical_kind(lease.kind))
 rig.position=slot;game.town.add_child(rig)
 var body:VehicleBody3D=rig.get_node("Body")
 body.set_meta("rental_owner",lease.owner);body.set_meta("rental_kind",lease.kind);body.set_meta("rental_id",lease.id)
 game.fleet.append(body);game._label_vehicle(body)
 spawned[str(lease.id)]={"rig":rig,"body":body,"lease":lease}
 body.park()
 game.city_map.fleet=game.fleet
func collect_rental(person:Node,kind:String) -> bool:
 var lease:=rental(person,kind)
 if private_hire.show_vehicle(person,kind):return true
 if lease.is_empty() or kind in ["Helicopter","Train","Robovan"]:return false
 var op:=contract_for(person)
 if not op.is_empty() and op.kind in ["Bus","Aurora"] and ((kind in ["Bus","bus_private"] and op.kind=="Bus") or (kind in ["Aurora","car"] and op.kind=="Aurora")):
  game.city_map.set_waypoint({"name":"Your "+str(op.kind),"point":op.vehicle.global_position});return true
 if spawned.has(str(lease.id)):
  var body:Node3D=spawned[str(lease.id)].body
  game.city_map.set_waypoint({"name":"Your "+str(CATALOG[kind].name),"point":body.global_position});return true
 var slot:=_free_slot(kind)
 if slot==Vector3.ZERO:return false
 _spawn(lease,slot);return true
func can_drive(person:Node,body:Node3D) -> bool:
 if body.get_meta("test_rental",false):return true
 var owner:String=body.get_meta("rental_owner","")
 var kind:String=body.get_meta("rental_kind","")
 return owner==game.economy.key_for(person) and not rental(person,kind).is_empty()
func return_rental(person:Node,kind:String) -> bool:
 var lease:=rental(person,kind)
 if lease.is_empty():game.economy.last_error="No active rental.";return false
 if not private_hire.release(person,kind):return false
 var id:=str(lease.id)
 if spawned.has(id):
  var body:VehicleBody3D=spawned[id].body
  if body.driver_active or body.linear_velocity.length()>.5:
   game.economy.last_error="Stop and leave the vehicle before ending its rental.";return false
 var op:=contract_for(person)
 if not op.is_empty() and not op.get("council_job",false):
  var work_lease:=_work_lease(op.owner,str(op.get("lease_kind",op.kind)))
  if str(work_lease.get("id",""))==id and not stop_job(person):return false
 if spawned.has(id):
  game.fleet.erase(spawned[id].body);spawned[id].rig.queue_free();spawned.erase(id)
 lease.expires=0;game.economy.save();game.economy.flush_save();return true
func nearest_meeting(person:Node,kind:String) -> Dictionary:
 var best:Dictionary={};var gap:=INF
 var list:Array=game.city.transport.stops if kind=="Bus" else (game.rail.stations if kind=="Train" else (game.cabs.ranks if kind in ["Aurora","Robovan"] else game.helicopters.pads))
 for place in list:
  var point:Vector3=place.pavement if place.has("pavement") else (place.rank if place.has("rank") else place.point)
  var d:float=person.global_position.distance_to(point)
  if d<gap:gap=d;best={"name":place.name,"point":point,"distance":d,"place":place}
 return best
func start_job(person:CharacterBody3D,kind:String) -> bool:
 return work.request(person,kind)
func assign_operator(person:Node,kind:String,vehicle:Node3D) -> Dictionary:
 var key:String=game.economy.key_for(person)
 var contract={"owner":key,"kind":kind,"vehicle":vehicle,"person":person,"phase":"active","council_job":kind in ["Bus","Train","Aurora","Robovan","Helicopter"],"autonomous":true,"earnings":0,"trips":0,"id":int(game.economy.data.next_contract)}
 game.economy.data.next_contract=int(game.economy.data.next_contract)+1
 operators[vehicle.get_instance_id()]=contract;operators_by_account[key]=contract
 _save_work(contract)
 return contract
func contract_for(person:Node) -> Dictionary:return operators_by_account.get(game.economy.key_for(person),{})
func stop_job(person:Node,kind:="") -> bool:
 var contract:=contract_for(person)
 if contract.is_empty():
  return work.pending.erase(game.economy.key_for(person))
 if kind!="" and contract.kind!=kind:return false
 if aboard.has(person.get_instance_id()) and not leave_driver(person):return false
 work.cancel(contract)
 operators.erase(contract.vehicle.get_instance_id());operators_by_account.erase(contract.owner)
 game.economy.data.transport_work.erase(contract.owner);game.economy.save();return true
func operator_for(vehicle:Node3D) -> Dictionary:
 var record:Dictionary=operators.get(vehicle.get_instance_id(),{})
 if record.is_empty():return {}
 if record.get("council_job",false):return record
 if record.kind in ["Bus","Train","Aurora","Robovan","Helicopter"]:return record
 var lease:=_work_lease(record.owner,str(record.get("lease_kind",record.kind)))
 return record if float(lease.get("expires",0))>Time.get_unix_time_from_system() else {}
func capture_fare(vehicle:Node3D,amount:int,payer:String) -> Dictionary:
 var op:=operator_for(vehicle)
 if op.is_empty() or op.owner==payer or (str(op.owner).begins_with("player/") and payer.begins_with("player/")) or amount<=0:return {}
 var id:int=game.economy.data.next_contract;game.economy.data.next_contract=id+1
 return {"id":str(id),"operator":op.owner,"amount":amount,"kind":op.kind,"vehicle":vehicle.get_instance_id()}
func settle_trip(receipt:Dictionary) -> bool:
 if receipt.is_empty() or int(receipt.id)<=int(game.economy.data.get("operator_payment_floor",0)) or game.economy.data.operator_payments.has(str(receipt.id)):return false
 var owner:String=receipt.operator
 if not game.economy.data.accounts.has(owner):return false
 var gross:int=receipt.amount
 var council_share:int=int(gross*30/100)
 var wage:=gross-council_share
 if gross<=0 or int(game.economy.data.council)<wage:return false
 game.economy.data.operator_payments[str(receipt.id)]=true
 if game.economy.data.operator_payments.size()>4096:
  var oldest:=int(game.economy.data.operator_payments.keys()[0])
  game.economy.data.operator_payment_floor=maxi(oldest,int(game.economy.data.get("operator_payment_floor",0)))
  game.economy.data.operator_payments.erase(str(oldest))
 game.economy.data.council=int(game.economy.data.council)-wage
 game.economy.data.accounts[owner].balance=int(game.economy.data.accounts[owner].balance)+wage
 game.economy.record(owner,wage,str(receipt.kind)+" trip • 70% operator share",-wage)
 var contract:Dictionary=operators_by_account.get(owner,{})
 if not contract.is_empty():
  contract.earnings=int(contract.earnings)+wage;contract.trips=int(contract.trips)+1
  _save_work(contract)
 game.economy.save();game.economy.flush_save();return true
func manual(vehicle:Node3D) -> bool:
 var op:=operator_for(vehicle)
 return not op.is_empty() and not op.autonomous and aboard.values().any(func(r):return r.vehicle==vehicle)
func throttle(vehicle:Node3D) -> float:
 if not manual(vehicle):return 1.0
 if game.phone.panel.visible or game.city_map.expanded or game.get_meta("controller_screen_mode",false):return 0.0
 if Input.is_action_pressed("reverse") or Input.is_action_pressed("handbrake"):return 0.0
 return maxf(Input.get_action_strength("accelerate"),Input.get_action_strength("walk_forward"))
func set_autonomous(person:Node,value:bool) -> bool:
 var contract:=contract_for(person)
 if contract.is_empty():return false
 if contract.kind=="Courier" or contract.get("phase","") in ["delivering","ready"]:game.economy.last_error="Enter the arrived work vehicle first.";return false
 if not value and not aboard.has(person.get_instance_id()):game.economy.last_error="Enter your assigned driver cab before selecting manual driving.";return false
 contract.autonomous=value;_save_work(contract);game.economy.save();return true
func board_driver(person:CharacterBody3D) -> bool:
 var op:=contract_for(person)
 if op.is_empty() and work.pending.has(game.economy.key_for(person)):return work.take_next(person)
 if not op.is_empty() and op.kind in ["Aurora","Robovan","Helicopter"]:return _board_service_driver(person,op)
 if op.is_empty() or op.kind not in ["Bus","Train"]:return false
 var vehicle:Node3D=op.vehicle
 if vehicle.speed>.1 or vehicle.state!="dwell":game.economy.last_error="Wait at the stop for your assigned vehicle.";return false
 var entry:Vector3=vehicle.entrance() if op.kind=="Bus" else vehicle.entrance()
 if entry_distance(person,vehicle,op.kind)>6:return false
 if person.driving or person.riding_bus!=null or person.riding_service!=null or person.transitioning:return false
 if op.kind=="Train":vehicle.ensure_model()
 aboard[person.get_instance_id()]={"person":person,"vehicle":vehicle,"kind":op.kind}
 person.set_meta("service_driving",true);person.collider.set_deferred("disabled",true);person.velocity=Vector3.ZERO
 person.visual.mount(vehicle.model,Vector3(-.6,.35,4.05) if op.kind=="Bus" else Vector3(-.55,.48,29),PI)
 op.autonomous=false;return true
func leave_driver(person:CharacterBody3D) -> bool:
 if not aboard.has(person.get_instance_id()):return false
 var ride:Dictionary=aboard[person.get_instance_id()];var vehicle:Node3D=ride.vehicle
 if ride.kind in ["Aurora","Robovan","Helicopter"]:return _leave_service_driver(person,ride)
 if vehicle.speed>.1 or vehicle.state!="dwell":game.economy.last_error="Stop at a station before leaving the driver cab.";return false
 person.visual.dismount(person);person.global_position=vehicle.entrance()+Vector3(0,.15,0)
 person.set_meta("service_driving",false);person.collider.set_deferred("disabled",false);person.velocity=Vector3.ZERO
 aboard.erase(person.get_instance_id());set_autonomous(person,true);return true
func driver_tick(person:CharacterBody3D) -> bool:
 if not aboard.has(person.get_instance_id()):return false
 var ride:Dictionary=aboard[person.get_instance_id()];var op:=contract_for(person)
 if ride.kind in ["Aurora","Robovan","Helicopter"]:return _service_driver_tick(person,ride,op)
 person.global_position=ride.vehicle.model.to_global(Vector3(-.6,.35,4.05) if ride.kind=="Bus" else Vector3(-.55,.48,29))
 var waiting:bool=ride.vehicle.state=="dwell"
 var timing:String="Depart in %ds" % ceili(maxf(0,ride.vehicle.dwell)) if waiting else "Time to move • W / R2"
 person.prompt.text=ride.kind+" DRIVER • "+("SELF-DRIVE" if op.autonomous else "MANUAL")+"\n"+timing+" • P: Jobs / self-drive • E: leave at a stop"
 if ride.get("last_state","")=="dwell" and not waiting:person._notify("Time to move. Use W / R2 or turn on self-drive.")
 ride.last_state=ride.vehicle.state
 if Input.is_action_just_pressed("interact") and not game.phone.panel.visible:leave_driver(person)
 return true
func open_tickets(vehicle:Node3D) -> void:
 ticket_vehicle=vehicle;ticket_serial+=1;game.phone.open_app("passes")
func board_with_ticket(person:CharacterBody3D,kind:String) -> bool:
 if not is_instance_valid(ticket_vehicle):return false
 if kind!="single" and not game.economy.buy_travel_pass(person,kind):return false
 var vehicle:=ticket_vehicle
 ticket_vehicle=null
 var boarded:bool=vehicle.board(person)
 if not boarded:ticket_vehicle=vehicle;game.economy.last_error="Wait for the arrived train and stand at its entrance. Your pass remains saved."
 return boarded
func _assign_counters() -> void:
 var sites:Array=W.place_sites().filter(func(site):return site.get("staffed",true)).duplicate(true)
 sites.insert(0,{"id":"council","name":"Council Office","point":game.economy.office,"kind":"council"})
 for i in range(mini(sites.size(),game.population.residents.size())):
  var person:CharacterBody3D=game.population.residents[game.population.residents.size()-1-i]
  person.set_meta("service_counter",sites[i].id)
  person.set_meta("counter_point",sites[i].point+Vector3(0,0,18) if sites[i].id!="council" else sites[i].point)
  person.set_meta("counter_name",sites[i].name)
  person.global_position=person.get_meta("counter_point")
  person.dialogue.ambient_enabled=false
  person.stop_activity();person.state="idle";person.wait_time=100000
func _physics_process(delta:float) -> void:
 work.tick(delta);private_hire.tick(delta);dispatch.tick(delta)
func _process(delta:float) -> void:
 clock+=delta
 if clock<1:return
 clock=0
 for person in game.population.residents:
  if person.has_meta("service_counter") and not person.dead and person.combat_time<=0 and not person.in_conversation and person.riding_service==null and not person.get_meta("cab_waiting",false):
   person.global_position=person.get_meta("counter_point");person.velocity=Vector3.ZERO;person.wait_time=100000
 for op in operators.values().duplicate():
  if operator_for(op.vehicle).is_empty():
   var person=game.party.members.filter(func(p):return game.economy.key_for(p)==op.owner)
   if not person.is_empty():stop_job(person[0])
 for id in spawned.keys():
  var r:Dictionary=spawned[id]
  if float(r.lease.expires)>Time.get_unix_time_from_system() or r.body.driver_active:continue
  game.fleet.erase(r.body);r.rig.queue_free();spawned.erase(id)

func _service_car(op:Dictionary) -> Dictionary:
 var service=game.cabs if op.kind in ["Aurora","Robovan"] else game.helicopters
 for car in service.cars:
  if car.node==op.vehicle:return car
 return {}
func _board_service_driver(person:CharacterBody3D,op:Dictionary) -> bool:
 var car:=_service_car(op)
 if op.get("phase","")=="delivering":game.economy.last_error="Your work vehicle is still coming.";return false
 if car.is_empty() or absf(float(car.speed))>.1 or person.global_position.distance_to(car.node.position)>5:
  game.economy.last_error="Meet your stopped assigned vehicle to enter its driver seat.";return false
 if person.driving or person.riding_bus!=null or person.riding_service!=null or person.transitioning:return false
 var model:Node3D=car.node.get_meta("graphics") if op.kind in ["Aurora","Robovan"] else car.model
 var anchor:Vector3=model.get_meta("driver_seat",Vector3(-.4,.26,-.35)) if op.kind in ["Aurora","Robovan"] else Vector3(-.4,.39,-.45)
 person.visual.mount(model,anchor,PI,op.kind in ["Aurora","Robovan"])
 person.collider.set_deferred("disabled",true);person.velocity=Vector3.ZERO
 person.set_meta("service_driving",true)
 aboard[person.get_instance_id()]={"person":person,"vehicle":car.node,"kind":op.kind,"car":car,"model":model}
 op.autonomous=false;op.phase="active"
 if car.state=="job_ready":car.state="idle";car.idle_clock=0.0
 _save_work(op);game.economy.save()
 if op.kind in ["Aurora","Robovan"]:model.get_meta("manual_controls").position.x=anchor.x;model.get_meta("manual_controls").show()
 return true
func _leave_service_driver(person:CharacterBody3D,ride:Dictionary) -> bool:
 var car:Dictionary=ride.car
 if absf(float(car.speed))>.1 or car.state not in ["idle","waiting","awaiting_destination"] or car.node.position.y>W.LEVEL+2:
  game.economy.last_error="Park safely on the ground before leaving the driver seat.";return false
 person.visual.dismount(person);person.global_position=car.node.position+car.node.global_basis.x*-3+Vector3(0,.15,0)
 person.collider.set_deferred("disabled",false);person.set_meta("service_driving",false)
 aboard.erase(person.get_instance_id());set_autonomous(person,true)
 if ride.kind in ["Aurora","Robovan"]:ride.model.get_meta("manual_controls").hide()
 return true
func _service_driver_tick(person:CharacterBody3D,ride:Dictionary,op:Dictionary) -> bool:
 var car:Dictionary=ride.car
 if ride.kind in ["Aurora","Robovan"]:ride.model.get_meta("manual_controls").visible=not op.autonomous
 if ride.kind in ["Aurora","Robovan"] and car.state=="idle" and not op.autonomous:
  game.cabs._manual_step(car,{"person":person,"destination":{"point":car.home_slot}},get_physics_process_delta_time())
 person.global_position=person.visual.global_position
 person.prompt.text=ride.kind+" DRIVER • "+("SELF-DRIVE" if op.autonomous else "MANUAL")+"\n"+dispatch.description(op)+"\nW/R2: "+("fly marked route" if ride.kind=="Helicopter" else "accelerate")+" • S/L2: brake • P: shift / self-drive • E: leave when parked"

 if Input.is_action_just_pressed("interact") and not game.phone.panel.visible:leave_driver(person)
 return true
func route_for_driver(person:Node) -> PackedVector3Array:
 var op:=contract_for(person)
 if op.is_empty():return PackedVector3Array()
 if op.kind=="Courier":
  if Time.get_ticks_msec()-int(op.get("route_at",0))>500 or not op.has("map_route"):
   op.map_route=game.cabs.path_between(op.vehicle.global_position,op.target.point,op.vehicle.global_basis.z);op.route_at=Time.get_ticks_msec()
  return op.map_route
 if op.kind in ["Aurora","Robovan","Helicopter"]:
  var car:=_service_car(op)
  if car.is_empty():return PackedVector3Array()
  return PackedVector3Array([car.node.position])+car.path.slice(int(car.index))
 var vehicle:Node3D=op.vehicle
 return route_for_vehicle(vehicle,op.kind)
func route_for_vehicle(vehicle:Node3D,kind:String) -> PackedVector3Array:
 var path:=PackedVector3Array([vehicle.position])
 if kind=="Bus":
  var remaining:=fposmod(float(vehicle.route.stops[vehicle.next_stop].distance)-vehicle.distance,float(vehicle.route.length))
  for step in range(1,ceili(remaining/10)+1):path.append(game.city.transport.sample(vehicle.route,vehicle.distance+minf(step*10,remaining)).position)
 else:
  var remaining:=fposmod((float(vehicle.route.lengths[vehicle.next_stop])-vehicle.distance)*vehicle.direction,float(vehicle.route.length))
  for step in range(1,ceili(remaining/10)+1):path.append(game.rail.sample(vehicle.route,fposmod(vehicle.distance+minf(step*10,remaining)*vehicle.direction,float(vehicle.route.length))).point)
 return path

func _public_vehicles(kind:String) -> Array:
 if kind=="Courier":return []
 if kind=="Bus":return game.city.transport.buses
 if kind=="Train":return game.rail.trains
 var fleet:Array=game.cabs.cars if kind in ["Aurora","Robovan"] else game.helicopters.cars
 return fleet.map(func(car):return car.node)
func _save_work(contract:Dictionary) -> void:
 var record={"kind":contract.kind,"phase":contract.get("phase","active"),"lease_kind":contract.get("lease_kind",contract.kind),"council_job":contract.get("council_job",false),"autonomous":contract.autonomous,"earnings":contract.earnings,"trips":contract.trips,"vehicle_index":_public_vehicles(contract.kind).find(contract.vehicle),"id":contract.id}
 if contract.has("target"):
  var p:Vector3=contract.target.point
  record.target={"name":contract.target.name,"point":[p.x,p.y,p.z]}
 game.economy.data.transport_work[contract.owner]=record
func _restore_jobs() -> void:
 for owner in game.economy.data.transport_work.keys():
  var data:Dictionary=game.economy.data.transport_work[owner]
  var kind:String=data.kind
  var lease:=_work_lease(owner,str(data.get("lease_kind",kind)))
  if kind not in ["Bus","Train","Aurora","Robovan","Helicopter"] and float(lease.get("expires",0))<=Time.get_unix_time_from_system():continue
  var members:Array=game.party.members.filter(func(p):return game.economy.key_for(p)==owner)
  if members.is_empty():continue
  var person:Node=members[0]
  var vehicle:Node3D
  if kind=="Courier":
   if not collect_rental(person,lease.kind):continue
   vehicle=spawned[str(lease.id)].body
  else:
   var vehicles:=_public_vehicles(kind)
   var index:=int(data.get("vehicle_index",-1))
   if index<0 or index>=vehicles.size() or operators.has(vehicles[index].get_instance_id()):continue
   vehicle=vehicles[index]
  var contract={"owner":owner,"kind":kind,"vehicle":vehicle,"person":person,"phase":"active","council_job":kind in ["Bus","Train","Aurora","Robovan","Helicopter"],"autonomous":true,"earnings":int(data.earnings),"trips":int(data.trips),"id":int(data.get("id",0))}
  operators[vehicle.get_instance_id()]=contract;operators_by_account[owner]=contract
  if kind=="Courier":
   contract.lease_kind=lease.kind;contract.phase=data.get("phase","pickup");contract.autonomous=false
   var target:Dictionary=data.get("target",{"name":"Collect delivery • Rental Depot","point":[0,W.LEVEL,47]})
   contract.target={"name":target.name,"point":Vector3(target.point[0],target.point[1],target.point[2])}
   if contract.phase=="delivery":work.parcel(contract)
  elif kind in ["Aurora","Robovan","Helicopter"] and data.get("phase","") in ["delivering","ready","active"]:
   _restore_delivery.call_deferred(person,contract)
func _restore_delivery(person:Node,contract:Dictionary) -> void:
 if not is_instance_valid(person):return
 var current:=contract_for(person)
 if current.is_empty() or current.vehicle!=contract.vehicle or current.id!=contract.id:return
 var earnings:int=contract.earnings;var trips:int=contract.trips;var id:int=contract.id
 operators.erase(contract.vehicle.get_instance_id());operators_by_account.erase(contract.owner)
 if work.request(person,contract.kind):
  var op:=contract_for(person);op.earnings=earnings;op.trips=trips;op.id=id;_save_work(op)
func _work_lease(owner:String,kind:String) -> Dictionary:
 var leases:Dictionary=game.economy.data.vehicle_rentals.get(owner,{})
 var lease:Dictionary=leases.get(kind,{})
 var aliases={"Bus":"bus_private","bus_private":"Bus","Aurora":"car","car":"Aurora"}
 if float(lease.get("expires",0))<=Time.get_unix_time_from_system() and aliases.has(kind):lease=leases.get(aliases[kind],{})
 return lease
func open_display(person:Node3D) -> bool:
 var nearest:Node3D;var gap:=4.0
 for model in get_tree().get_nodes_in_group("rental_displays"):
  var d:float=person.global_position.distance_to(model.global_position)
  if d<gap:gap=d;nearest=model
 if nearest==null:return false
 game.phone.apps.selected_vehicle=nearest.get_meta("rental_kind");game.phone.open_app("rental");return true
func counter_actions(id:String) -> Array:
 match id:
  "sales":return [["Rent a vehicle","vehicles"]]
  "council":return [["Council homes","homes"],["Council jobs","council_jobs"],["Council accounts","council"]]
  "market","market_east":return [["Work at this shop","shop_job"]]
  "race":return [["Find the race start","race_start"]]
 return []
func use_counter(id:String,action:String) -> void:
 if action=="race_start":game.city_map.set_waypoint({"name":"Race start • checkpoint 1","point":Vector3(-341,W.LEVEL,340)});return
 game.phone.apps.shop_site=id;game.phone.open_app(action)

# An explicit confirmed job is the only door interaction that enters a driver seat.
# Otherwise this consumes the nearest public-vehicle interaction, including fare failures.
func entry_distance(person:Node3D,vehicle:Node3D,kind:String) -> float:
 var distance:float=person.global_position.distance_to(vehicle.entrance())
 if kind=="Train" and is_instance_valid(vehicle.model):
  distance=minf(distance,person.global_position.distance_to(vehicle.model.to_global(Vector3(signf(vehicle.lane)*2,.6,22))))
 return distance
func door_interact(person:CharacterBody3D) -> bool:
 var nearest:Node3D;var kind:="";var index:=-1;var gap:=5.0
 for bus in game.city.transport.buses:
  if bus.state!="dwell":continue
  var d:float=person.global_position.distance_to(bus.entrance())
  if d<gap:gap=d;nearest=bus;kind="Bus"
 for train in game.rail.trains:
  if train.state!="dwell":continue
  var d:float=entry_distance(person,train,"Train")
  if d<gap:gap=d;nearest=train;kind="Train"
 for entry in [[game.cabs,"Aurora"],[game.helicopters,"Helicopter"]]:
  for i in range(entry[0].cars.size()):
   var car:Dictionary=entry[0].cars[i]
   if car.state not in ["idle","waiting","job_ready","rental_ready"]:continue
   var d:float=person.global_position.distance_to(car.node.global_position)
   if d<gap:gap=d;nearest=car.node;kind=car.get("kind",entry[1]);index=i
 if nearest==null:return false
 var op:=contract_for(person)
 if (not op.is_empty() and op.vehicle==nearest) or work.candidate(person)==nearest:
  if board_driver(person):return true
  person._notify(game.economy.last_error);return true
 if not op.is_empty() or work.pending.has(game.economy.key_for(person)):
  person._notify("Your FREE work vehicle is marked on the map. Use Jobs to enter its driver seat.");return true
 if kind in ["Bus","Train"]:
  if not nearest.board(person):person._notify("Not enough money for the fare." if game.economy.cash(person)<(200 if kind=="Bus" else 400) and not game.economy.has_day_pass(person) else "Wait beside the open passenger door.")
  return true
 var service=game.cabs if kind in ["Aurora","Robovan"] else game.helicopters
 var car:Dictionary=service.cars[index]
 var rental_kind:String="Robovan" if kind=="Robovan" else ("car" if kind=="Aurora" else "Helicopter")
 if car.node.has_meta("private_owner"):
  if car.node.get_meta("private_owner")!=game.economy.key_for(person):person._notify("This vehicle is privately rented.");return true
  if private_hire.board(person,rental_kind):return true
 elif car.state=="idle":
  if service.walk_up(person,index).is_empty():person._notify(game.economy.last_error);return true
 if not service.board_near(person):person._notify(game.economy.last_error if game.economy.last_error!="" else "This vehicle is reserved for another passenger.")
 return true
