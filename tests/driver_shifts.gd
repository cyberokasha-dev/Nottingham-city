extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
var game:Node3D
var s:Node
var e:Node
var p:CharacterBody3D
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(806);call_deferred("run")
func check(ok:bool,why:String):
 if not ok:failed=true;push_error(why)
func money() -> int:
 var result:int=e.data.council+e.data.business
 for a in e.data.accounts.values():result+=int(a.balance)
 for r in e.data.receipts.values():result+=int(r.amount)
 return result
func start_from_phone(kind:String) -> bool:
 game.phone.open_app("jobs")
 var apps=game.phone.apps
 apps.sheets.jobs.get_child(0).get_child(0).pressed.emit()
 check(apps.page=="driving_jobs","Jobs opens its driving-only choices")
 apps._choose_driver_job(kind)
 check(s.contract_for(p).is_empty(),"Choosing work shows its free Start action before reserving a vehicle")
 apps.work_primary.pressed.emit()
 if game.phone.panel.visible:print("SHIFT_START_FAILURE ",kind," ",game.economy.last_error," ",game.phone.message.text," button=",apps.work_primary.text)
 return not game.phone.panel.visible and (not s.contract_for(p).is_empty() or s.work.pending.has(e.key_for(p)))
func tick(kind:String,delta:float,passenger:Node=null):
 game.city.traffic.clock=fposmod(game.city.traffic.clock+delta,game.city.traffic.CYCLE)
 s.work.tick(delta)
 var service:Node=game.cabs if kind in ["Aurora","Robovan"] else game.helicopters
 service._physics_process(delta);service._process(delta)
 if is_instance_valid(passenger) and passenger.get_meta("cab_waiting",false):passenger._physics_process(delta)
 s.driver_tick(p)
 await physics_frame
func air_or_cab(kind:String,passenger:Node):
 print("SHIFT_STAGE ",kind)
 var service:Node=game.cabs if kind in ["Aurora","Robovan"] else game.helicopters
 # A short, unobstructed real road/pad fixture, using ordinary dispatch and movement.
 var car:Dictionary=service.cars.filter(func(item):return item.get("kind","Helicopter")==kind)[0]
 if kind in ["Aurora","Robovan"]:
  car.node.position=Vector3(-25,W.LEVEL,-125.5);car.node.rotation.y=PI/2;car.home_slot=car.node.position
  p.global_position=Vector3(-9,W.LEVEL,-128)
 else:p.global_position=car.node.position+Vector3(16,0,0)
 var start_cash:int=e.cash(p);var treasury:int=e.data.council
 check(start_from_phone(kind) and e.cash(p)==start_cash and e.data.council==treasury,kind+" starts directly from Jobs at £0 with no charge")
 var op:Dictionary=s.contract_for(p)
 if op.is_empty():return
 car=s._service_car(op)
 check(not s.board_driver(p),kind+" cannot be entered before arriving")
 for frame in range(16000):
  await tick(kind,.1)
  if op.phase=="ready":break
 check(op.phase=="ready" and car.node.position.distance_to(p.global_position)<65,kind+" is delivered continuously to the worker")
 if op.phase!="ready":return
 p.global_position=car.node.position+Vector3(3,0,0)
 check(s.door_interact(p) and s.manual(car.node) and p.riding_service==null,kind+" door enters driver seat without passenger fare")
 await physics_frame;await physics_frame
 var last_id:=-1
 for journey in range(2):
  var pickup:Vector3=Vector3(0,W.LEVEL,-128) if kind in ["Aurora","Robovan"] else service.pads[1].point+Vector3(9,0,0)
  var target:Vector3=Vector3(25 if journey==0 else -25,W.LEVEL,-128) if kind in ["Aurora","Robovan"] else service.pads[2+journey].point
  passenger.global_position=pickup;passenger.velocity=Vector3.ZERO;passenger.resting="";passenger.current_house=null
  passenger.in_conversation=false;passenger.combat_time=0;passenger.dead=false;passenger.far_simulated=false
  passenger.collider.set_deferred("disabled",false);e.account_for(passenger).balance=100000
  await physics_frame;await physics_frame
  check(s.dispatch.request(op,passenger,{"name":"Customer destination "+str(journey+1),"point":target}),kind+" accepts a real customer's booking on the assigned work vehicle")
  var trip:Dictionary=s.dispatch.trip_for(op)
  if trip.is_empty():break
  check(trip.id!=last_id and trip.person==passenger and service.cars[trip.car].node==op.vehicle,kind+" customer is attached to the worker's vehicle")
  last_id=trip.id
  check(s.dispatch.description(op).contains(passenger.person_name) and s.dispatch.markers(p).size()==3 and s.route_for_driver(p).size()>0,kind+" shows customer, pickup, destination and route")
  var fare:int=trip.fare;var before:int=e.cash(p);var council:int=e.data.council;var customer_cash:int=e.cash(passenger);var all_money:=money()
  # First trip uses driver power. Aurora steering is checked by its existing driving suite;
  # switch to self-drive after initial movement so the real road route completes safely.
  if journey==0:Input.action_press("accelerate")
  else:check(s.set_autonomous(p,true),kind+" can resume self-drive with the worker aboard")
  var previous:Vector3=car.node.position;var moved:=false;var seated:=false;var paid:=false
  for frame in range(22000):
   await tick(kind,.05,passenger)
   var travel:float=previous.distance_to(car.node.position)
   if travel>.005:moved=true
   check(travel<5.1,kind+" follows a continuous trip")
   previous=car.node.position
   if journey==0 and kind in ["Aurora","Robovan"] and moved:
    Input.action_release("accelerate");s.set_autonomous(p,true)
   if passenger.riding_service==service and car.state=="dropoff":
    seated=true
    check(s.aboard.has(p.get_instance_id()) and p.global_position.distance_to(service.seat_position(passenger))>.65,kind+" driver and visible passenger occupy separate seats")
   if not service.bookings.has(e.key_for(passenger)):
    paid=int(op.trips)==journey+1;break
  Input.action_release("accelerate")
  print("SHIFT_TRIP ",kind," ",journey," moved=",moved," seated=",seated," paid=",paid," state=",car.state," at=",car.node.position," passenger=",passenger.global_position)
  check(moved and seated and paid,kind+" performs pickup, visible boarding, travel and completed dropoff")
  check(e.cash(passenger)==customer_cash-fare and e.cash(p)==before+fare-int(fare*30/100) and e.data.council==council+int(fare*30/100) and money()==all_money,kind+" pays exactly 70% worker / 30% council from the actual customer fare")
  var earned:int=e.cash(p);e.complete_fare(passenger,car.node)
  check(e.cash(p)==earned,kind+" completion cannot pay twice")
  if not paid:break
  # A stopped vehicle stays available for the next customer instead of returning to a rank.
  s.dispatch.tick(1)
  check(car.state=="idle" and s.aboard.has(p.get_instance_id()),kind+" stays on shift after a customer leaves")
 if car.state=="idle":
  passenger.remove_meta("last_work_trip")
  s.dispatch.tick(3)
  var next:Dictionary=s.dispatch.trip_for(op)
  check(not next.is_empty() and next.person==passenger and next.id!=last_id,kind+" automatically receives the next real customer request")
  if not next.is_empty():service.cancel(next.person)
  check(not passenger.get_meta("cab_waiting",false),kind+" cancelled demand leaves its customer able to book again")
 if car.state=="idle":
  check(s.leave_driver(p) and s.stop_job(p),kind+" ends without a rental or exit fee")
 else:
  failed=true;return
 car.state="unavailable";car.node.position=Vector3(6000,0,6000);car.landing=car.node.position
 passenger.global_position=Vector3(6000,0,6000)
func public_route(kind:String):
 print("SHIFT_STAGE ",kind)
 var vehicles:Array=game.city.transport.buses if kind=="Bus" else game.rail.trains
 var vehicle:Node3D=vehicles[0]
 var point:Vector3=vehicle.route.stops[2].pavement if kind=="Bus" else vehicle.route.stops[2].point
 p.global_position=point+Vector3(65,0,0);e.account_for(p).balance=0
 var treasury:int=e.data.council
 check(start_from_phone(kind) and s.contract_for(p).is_empty() and e.cash(p)==0 and e.data.council==treasury,kind+" application is free and persists away from the stop")
 var wait:Dictionary=s.work.pending.get(e.key_for(p),{})
 if wait.is_empty():return
 # Place only the initial fixture at the requested stop; subsequent travel is real.
 if kind=="Bus":
  for item in vehicles:
   if item.route.number==wait.meeting.route:vehicle=item;break
  vehicle.stop_index=wait.meeting.stop_index;vehicle.distance=vehicle.route.stops[vehicle.stop_index].distance;vehicle.find_next_stop()
 else:
  vehicle.stop_index=vehicle.route.stops.find(wait.meeting.place);vehicle.distance=vehicle.route.lengths[vehicle.stop_index];vehicle.next_stop=posmod(vehicle.stop_index+vehicle.direction,vehicle.route.stops.size())
 vehicle._update_position();vehicle.show();vehicle.state="dwell";vehicle.speed=0;vehicle.dwell=12
 if kind=="Bus":vehicle.model.animate_doors(1)
 else:vehicle.ensure_model()
 p.global_position=vehicle.entrance()
 check(s.door_interact(p) and s.aboard.has(p.get_instance_id()) and e.cash(p)==0,kind+" takes the actual arrived vehicle without charging the worker")
 var op:Dictionary=s.contract_for(p)
 if op.is_empty():return
 s.driver_tick(p);check(p.prompt.text.contains("Depart in 12s"),kind+" shows its departure countdown")
 check(s.set_autonomous(p,true),kind+" self-drive works with the worker aboard")
 var initial:Vector3=vehicle.position;var stops:int=vehicle.services_completed if kind=="Bus" else vehicle.stops_completed
 var passenger:Node3D
 if kind=="Bus":
  for stop in game.city.transport.stops:
   for person in stop.waiting:
    if e.key_for(person)=="":e.register(person,str(person.get_meta("commuter_id")),15000)
  check(game.city.transport.board_next(vehicle),"A real bus queue pays and boards during the shift")
  var record:Dictionary=vehicle.manifest[-1];passenger=record.person
  check(not record.get("commission",{}).is_empty(),"The newly paid bus passenger is credited to this worker")
 var balance:int=e.cash(p);var council:int=e.data.council;var all_money:=money();var reached:=false
 for frame in range(20000):
  game.city.traffic.clock=fposmod(game.city.traffic.clock+.1,game.city.traffic.CYCLE)
  game.city.transport.elapsed+=.1
  vehicle.advance(.1);s.driver_tick(p)
  await physics_frame
  if int(op.trips)>0 and vehicle.state=="dwell":reached=true;break
 print("SHIFT_ROUTE ",kind," reached=",reached," trips=",op.trips," earned=",op.earnings," state=",vehicle.state)
 check(reached and vehicle.position.distance_to(initial)>50 and (vehicle.services_completed if kind=="Bus" else vehicle.stops_completed)>stops,kind+" completes actual route travel and pays for public passengers")
 check(s.aboard.has(p.get_instance_id()) and op.autonomous and e.cash(p)>balance and money()==all_money,kind+" keeps the worker aboard, earning conserved money in self-drive")
 if kind=="Train":check(e.cash(p)==balance+840 and e.data.council==council+360,"Three paid rail fares split exactly 70/30")
 check(s.leave_driver(p) and s.stop_job(p),kind+" ends safely at the next stop")
 vehicle.position=Vector3(6000,0,6000)
func run():
 game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game)
 game.economy.enabled=false
 # Pause scripts, keeping collision bodies in the world for actual walking/boarding.
 for node in [game]+game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
 s=game.services;e=game.economy;p=game.player
 e.account_for(p).balance=0;game.cabs.npc_clock=-100000
 for item in game.city.traffic.cars:item.node.position=Vector3(6000,0,6000)
 for person in game.population.residents+game.party.members:
  if person!=p:person.global_position=Vector3(6000,0,6000)
 for bus in game.city.transport.buses:bus.position=Vector3(6000,0,6000)
 var npc:Node
 for person in game.population.residents:
  if not person.has_meta("service_counter"):npc=person;break
 for service in [game.cabs,game.helicopters]:
  for i in range(1,service.cars.size()):
   service.cars[i].state="unavailable";service.cars[i].node.position=Vector3(6000,0,6000);service.cars[i].landing=Vector3(6000,0,6000)
 await physics_frame;await physics_frame
 await air_or_cab("Aurora",npc)
 var van:Dictionary=game.cabs.cars.filter(func(item):return item.kind=="Robovan")[0];van.state="idle"
 if not failed:await air_or_cab("Robovan",npc)
 if not failed:await air_or_cab("Helicopter",npc)
 if not failed:await public_route("Bus")
 if not failed:await public_route("Train")
 game.queue_free();await process_frame
 if not failed:print("DRIVER_SHIFTS_OK: five free jobs at £0, delivered work vehicles, two real NPC journeys per Aurora/Robovan/heli, pickup/dropoff routes, distinct seats, next bookings, bus queue fares, full bus/rail routes, autonomous wages and exact conserved 70/30 payments")
 quit(1 if failed else 0)
