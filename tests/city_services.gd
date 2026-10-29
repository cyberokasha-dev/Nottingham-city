extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(614);call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failed=true;push_error(message)
func total(e:Node) -> int:
 var result:int=e.data.council
 for a in e.data.accounts.values():result+=int(a.balance)
 for r in e.data.receipts.values():result+=int(r.amount)
 return result
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game)
 game.economy.enabled=false;game.process_mode=Node.PROCESS_MODE_DISABLED
 var s=game.services;var e=game.economy;var p=game.player
 var wallet:Dictionary=e.account_for(p)
 check(game.fleet.is_empty(),"Production has no free starter vehicles")
 check(s.access_code().length()==16 and s.code_matches(s.access_code().to_lower()),"One private code is generated and normalised")
 var code:String=s.access_code();s.ensure_data();check(code==s.access_code(),"Opening the account never changes its identity")
 check(game.phone.apps.page=="home" and game.phone.apps.home.get_child_count()==9,"The phone starts with nine focused apps")
 check(not game.phone.passenger_name.visible and not game.phone.service_picker.visible,"Booking has no large name/service form")
 var staff:=0
 for person in game.population.residents:
  if person.has_meta("service_counter"):staff+=1;check(not person.dialogue.ambient_enabled,"Counter workers do not add ambient chatter")
 check(staff==7 and game.population.residents.size()==16,"Every civic site has a worker without increasing population")
 var treasury:int=e.data.council;wallet.balance=2999
 check(not s.rent_vehicle(p,"sports","hour") and game.fleet.is_empty() and e.data.council==treasury,"Insufficient funds cannot create a vehicle")
 wallet.balance=150000
 check(s.rent_vehicle(p,"sports","hour") and game.fleet.size()==1 and e.cash(p)==147000 and e.data.council==treasury+3000,"A short rental transfers the exact displayed price")
 var body:VehicleBody3D=game.fleet[0]
 check(s.can_drive(p,body) and not s.can_drive(game.party.members[1],body),"Only the renter can drive the vehicle")
 check(not s.rent_vehicle(p,"sports","hour") and e.cash(p)==147000,"Repeated confirmation never charges twice")
 check(s.collect_rental(p,"sports") and game.fleet.size()==1 and e.cash(p)==147000,"Collecting the same lease cannot duplicate a car or charge")
 s.rental(p,"sports").expires=Time.get_unix_time_from_system()-1
 check(not s.can_drive(p,body),"An expired lease cannot be entered")
 s._process(1.1);check(game.fleet.is_empty(),"An expired unoccupied rental leaves its bay")
 await process_frame
 check(s.rent_vehicle(p,"bus_private","week"),"A private bus can be rented long term")
 var bus_body:VehicleBody3D=game.fleet[0]
 check(bus_body.display_name.contains("bus") and bus_body.get_node("CollisionShape3D").shape.size.z>10,"Private bus uses a bus cabin and full-size collision")
 check(not s.rental(p,"Bus").is_empty(),"A privately rented bus qualifies for paid bus work without a second lease")
 check(float(s.rental(p,"bus_private").expires)>Time.get_unix_time_from_system()+604000,"Long rentals use seven real days")
 check(s.return_rental(p,"bus_private") and game.fleet.is_empty(),"A stopped private rental can be returned")
 await process_frame
 # Tickets are sold at the actual train entrance and cannot bypass its balance check.
 var train=game.rail.trains[0];train.state="dwell";train.speed=0;train.dwell=30
 p.global_position=train.entrance();s.open_tickets(train);wallet.balance=399
 check(not s.board_with_ticket(p,"single") and train.rider==null and e.cash(p)==399,"A passenger without £4 cannot board")
 wallet.balance=150000;s.open_tickets(train)
 check(s.board_with_ticket(p,"single") and e.cash(p)==149600 and p.riding_bus==train,"The single ticket pays exactly once before entry")
 train.rider_board_clock=train.boarding_seconds;train.leave(p);p.riding_bus=null
 wallet.balance=150000
 check(e.buy_travel_pass(p,"day") and e.cash(p)==147500 and e.day_pass(p).code==code,"A day pass uses the same city code")
 check(not e.buy_travel_pass(p,"day") and e.cash(p)==147500,"Buying an already active pass cannot charge again")
 check(e.buy_travel_pass(p,"month") and e.cash(p)==135500 and e.pass_seconds_left(p)>2591900,"A month pass lasts thirty real days")
 wallet.balance=0;p.global_position=train.entrance();s.open_tickets(train)
 check(s.board_with_ticket(p,"active") and e.cash(p)==0,"An active pass boards without another payment")
 train.rider_board_clock=train.boarding_seconds;train.leave(p);p.riding_bus=null;game.phone.panel.hide()
 # Every transport job must be usable with an empty wallet and no rental lease.
 for car in game.city.traffic.cars:car.node.position=Vector3(6000,0,6000)
 for person in game.population.residents+game.party.members:
  if person!=p:person.global_position=Vector3(6000,0,6000)
 wallet.balance=0
 for kind in ["Bus","Aurora","Helicopter","Train"]:
  var before_start:int=e.cash(p)
  p.global_position=s.work.meeting(p,kind).point
  check(s.start_job(p,kind) and e.cash(p)==before_start and s.rental(p,kind).is_empty(),kind+" work starts free without a rental")
  if kind in ["Bus","Train"]:
   var wait:Dictionary=s.work.pending[e.key_for(p)]
   var available:Array=game.city.transport.buses if kind=="Bus" else game.rail.trains
   var arrived:Node3D=available[0]
   if kind=="Bus":
    for candidate in available:
     if candidate.route.number==wait.meeting.route:arrived=candidate;break
    arrived.stop_index=wait.meeting.stop_index;arrived.distance=arrived.route.stops[arrived.stop_index].distance
   else:
    arrived.stop_index=arrived.route.stops.find(wait.meeting.place);arrived.distance=arrived.route.lengths[arrived.stop_index]
   arrived._update_position();arrived.state="dwell";arrived.speed=0;arrived.dwell=30;p.global_position=arrived.entrance()
   check(s.board_driver(p),"Take the arrived "+kind+" for the free job")
   s.leave_driver(p)
  else:
   var assigned:Dictionary=s.contract_for(p);var incoming:Dictionary=s._service_car(assigned)
   for i in range(15000):
    if kind=="Aurora":s.work.tick(.1)
    else:game.helicopters._physics_process(.1)
    if assigned.phase=="ready":break
   check(assigned.phase=="ready","The work "+kind+" actually arrives")
  var op:Dictionary=s.contract_for(p);var vehicle:Node3D=op.vehicle
  if kind=="Bus":
   e.data.vehicle_rentals[e.key_for(p)]["bus_private"]={"id":999999,"kind":"bus_private","expires":Time.get_unix_time_from_system()+3600,"owner":e.key_for(p)}
   check(s.return_rental(p,"bus_private") and s.contract_for(p).vehicle==vehicle,"Returning a separate private lease cannot end a free council shift")
  check(not s.set_autonomous(p,false),"Remote manual takeover is blocked")
  check(not s.capture_fare(vehicle,200,e.key_for(p)).size() and s.capture_fare(vehicle,200,e.key_for(game.party.members[1])).is_empty(),"Own characters cannot farm transport wages")
  var npc=game.population.residents[0];var before:int=e.cash(p);var council:int=e.data.council;var money:=total(e)
  check(e.hold_fare(npc,1000,kind),"An actual public passenger can pay the fare")
  e.complete_fare(npc,vehicle)
  check(e.cash(p)==before+700 and e.data.council==council+300 and total(e)==money,"A completed "+kind+" trip pays operator 70% and council 30% without creating money")
  e.complete_fare(npc,vehicle)
  check(e.cash(p)==before+700,"Replaying completion cannot pay twice")
  if kind in ["Bus","Train"]:
   vehicle.state="dwell";vehicle.speed=0;vehicle.dwell=30
   if kind=="Bus":vehicle.stop_index=2;vehicle.distance=vehicle.route.stops[2].distance;vehicle.find_next_stop();vehicle._update_position()
   p.global_position=vehicle.entrance()
   check(s.board_driver(p) and s.manual(vehicle),"The "+kind+" operator enters the dedicated driver cab")
   check(s.throttle(vehicle)==0,"Manual service waits for power input")
   Input.action_press("accelerate");check(s.throttle(vehicle)==1,"Driver power operates the assigned service")
   var start:Vector3=vehicle.position;vehicle.state="moving"
   for i in range(20):vehicle.advance(.1)
   check(vehicle.position.distance_to(start)>1,"The "+kind+" actually moves under driver power")
   Input.action_release("accelerate")
   game.phone.panel.show();check(s.throttle(vehicle)==0,"Opening the phone safely releases manual service power");game.phone.panel.hide()
   check(not s.leave_driver(p),"A moving driver cannot step into the road or track")
   vehicle.state="dwell";vehicle.speed=0
   check(s.leave_driver(p) and op.autonomous and not p.get_meta("service_driving"),"The driver exits safely and the same service resumes autonomously")
  else:
   var car:Dictionary=s._service_car(op);car.speed=0;car.state="idle";p.global_position=car.node.position+Vector3(2,0,0)
   check(s.board_driver(p) and s.manual(vehicle),"The "+kind+" has a separate operator seat")
   check(s.set_autonomous(p,true) and s.throttle(vehicle)==1,"Autonomous "+kind+" work resumes on the same vehicle")
   check(s.leave_driver(p),"A parked "+kind+" operator can leave safely")
  var earnings:int=op.earnings
  s.operators.clear();s.operators_by_account.clear();s._restore_jobs()
  check(s.contract_for(p).earnings==earnings and s.contract_for(p).autonomous,"Saved work restores its earnings and resumes safely in self-drive")
  check(s.stop_job(p) and s.contract_for(p).is_empty(),"Ending a shift releases the assigned service")
 # Receipt IDs cannot be reused, including after a save/reload.
 p.global_position=s.work.meeting(p,"Train").point;s.start_job(p,"Train")
 var wait:Dictionary=s.work.pending[e.key_for(p)];var v:Node3D=game.rail.trains[0]
 v.stop_index=v.route.stops.find(wait.meeting.place);v.distance=v.route.lengths[v.stop_index];v._update_position();v.state="dwell";v.speed=0;p.global_position=v.entrance();s.board_driver(p);s.leave_driver(p)
 var receipt:Dictionary=s.capture_fare(v,200,"resident/test")
 check(s.settle_trip(receipt) and not s.settle_trip(receipt),"A stored operator receipt is settled only once")
 var snapshot:Dictionary=game.city_account._snapshot()
 check(not JSON.stringify(snapshot).contains(code) and snapshot.vehicle_rentals.size()>0 and snapshot.transport_work.size()>0,"Cloud snapshots retain rentals/jobs but strip the private credential")
 s.stop_job(p);game.queue_free();await process_frame
 if not failed:print("CITY_SERVICES_OK: empty rental depot, balance gates, ownership, expiry, single/day/month rail tickets, four free driver jobs, real movement, paid passenger receipts, 30/70 conservation, saved contracts and private snapshots")
 quit(1 if failed else 0)
