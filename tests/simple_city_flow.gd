extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(1048);call_deferred("run")
func check(ok:bool,why:String):
 if not ok:failed=true;push_error(why)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game)
 game.process_mode=Node.PROCESS_MODE_DISABLED;game.economy.enabled=false
 var s=game.services;var e=game.economy;var p=game.player;var wallet:Dictionary=e.account_for(p)
 check(game.city.houses.size()==41 and W.LIMIT==740,"Only 41 default homes, keeping the full city footprint")
 check(game.city.parks.size()>=2 and game.rail.trains.size()==4 and game.city.transport.buses.size()==8,"Public transport and parks remain in place")
 var link:Node
 for child in game.get_children():
  if child.get_script()!=null and child.get_script().resource_path=="res://phone/phone_link.gd":link=child
 var rental_buttons=game.phone.apps.sheets.rental.find_children("*","Button",true,false)
 check(rental_buttons.all(func(b):return not b.text.to_lower().contains("work")),"Rents contains no job or work buttons")
 # Door boarding defaults to passenger, charging one single fare automatically.
 for kind in ["Bus","Train"]:
  var v:Node3D=game.city.transport.buses[0] if kind=="Bus" else game.rail.trains[0]
  v.state="dwell";v.speed=0;v.dwell=30
  if kind=="Bus":v.stop_index=1;v.distance=v.route.stops[1].distance;v._update_position();v.model.animate_doors(1)
  else:v.ensure_model();v.door_fraction=1
  p.global_position=v.entrance();wallet.balance=0;game.phone.panel.hide()
  check(s.door_interact(p) and p.riding_bus==null and not game.phone.panel.visible,"Door rejects unpaid "+kind+" entry without opening a form")
  var fare:=200 if kind=="Bus" else 400;wallet.balance=fare
  if kind=="Bus":
   p.process_mode=Node.PROCESS_MODE_ALWAYS
   await physics_frame;await physics_frame
   p.global_position=v.entrance();p.velocity=Vector3.ZERO
   link.apply_state({"x":0,"y":0,"b":["TRIANGLE"]})
   await physics_frame;await process_frame
   link.apply_state({"x":0,"y":0,"b":[]});p.process_mode=Node.PROCESS_MODE_INHERIT
   check(p.riding_bus==v and e.cash(p)==0 and not s.aboard.has(p.get_instance_id()),"The controller Triangle input reaches actual passenger boarding and pays once")
  else:check(s.door_interact(p) and p.riding_bus==v and e.cash(p)==0 and not s.aboard.has(p.get_instance_id()),"Door boards a train passenger and pays the single fare once")
  v.rider_board_clock=30;v.leave(p);p.riding_bus=null
  wallet.balance=10000;check(e.buy_travel_pass(p,"day"),"Buy the day pass once")
  p.global_position=v.entrance();var cash:int=e.cash(p)
  check(s.door_interact(p) and p.riding_bus==v and e.cash(p)==cash,"Door automatically accepts a valid pass")
  v.rider_board_clock=30;v.leave(p);p.riding_bus=null;e.data.travel_passes.erase(e.key_for(p))
 print("SIMPLE_STAGE private deliveries")
 for item in game.city.traffic.cars:item.node.position=Vector3(6000,0,6000)
 for person in game.population.residents:person.global_position=Vector3(6000,0,6000)
 for person in game.party.members:
  if person!=p:person.global_position=Vector3(6000,0,6000)
 for kind in ["car","Robovan","Helicopter","bus_private"]:
  print("SIMPLE_PRIVATE ",kind)
  p.global_position=Vector3(8,W.LEVEL,37);wallet.balance=1000000
  var cash:int=e.cash(p)
  check(s.private_hire.request(p,kind,"hour"),"Private "+kind+" delivery can be ordered")
  var r:Dictionary=s.private_hire.record_for(p,kind)
  check(not r.is_empty() and s.contract_for(p).is_empty() and e.cash(p)==cash-int(s.CATALOG[kind].hour),"Rent pays once and never starts a job")
  if r.is_empty():continue
  var car:Dictionary=r.car;var initial:Vector3=car.node.global_position
  for i in range(15000):
   s.private_hire.tick(.1)
   if kind=="Helicopter":game.helicopters._physics_process(.1)
   check(initial.distance_to(car.node.global_position)<4.1,"Private hire moves continuously to the player")
   initial=car.node.global_position
   if r.phase=="ready":break
  print("SIMPLE_ARRIVAL ",kind," phase=",r.phase," gap=",car.node.global_position.distance_to(p.global_position))
  check(r.phase=="ready" and car.node.global_position.distance_to(p.global_position)<80,"Private "+kind+" arrives at a nearby safe pickup")
  check(not s.private_hire.route_for(p).size(),"Completed delivery removes its approach route")
  cash=e.cash(p);check(s.private_hire.request(p,kind,"hour") and e.cash(p)==cash,"Repeated rental cannot charge twice")
  if kind=="bus_private":
   p.global_position=car.node.to_global(car.node.get_meta("entry_point")+Vector3(-.5,0,0))
   check(p.global_position.distance_to(car.node.global_position)>4 and p.vehicle_distance(car.node)<1 and p.nearest_vehicle()==car.node,"Private bus can be selected at its actual front door, not only beside its centre")
  if kind!="bus_private":
   p.global_position=car.node.global_position+Vector3(3,0,0);wallet.balance=0
   check(s.door_interact(p) and p.riding_service!=null and e.cash(p)==0,"Renter boards the reserved vehicle without a second charge")
   var service=game.cabs if kind in ["car","Robovan"] else game.helicopters
   for i in range(40):service._physics_process(.1)
   check(service.leave_waiting(p),"Unused private journey exits normally")
   s.private_hire.tick(.1)
  check(s.return_rental(p,kind),"Private rental returns without affecting public work")
  await process_frame
 print("SIMPLE_STAGE any-stop job")
 var bus:Node3D=game.city.transport.buses[0];var stop:Dictionary=bus.route.stops[2]
 p.global_position=stop.pavement;wallet.balance=0
 check(s.work.request(p,"Bus") and s.contract_for(p).is_empty(),"Bus job confirms at a non-terminal stop without renting")
 bus.stop_index=2;bus.distance=stop.distance;bus._update_position();bus.state="dwell";bus.dwell=12;bus.speed=0;bus.model.animate_doors(1)
 p.global_position=bus.entrance()
 check(s.door_interact(p) and s.aboard.has(p.get_instance_id()) and p.riding_bus==null,"Only an explicitly confirmed job takes the driver seat")
 var op:Dictionary=s.contract_for(p)
 check(op.get("council_job",false) and e.cash(p)==0,"Council provides the job bus free")
 s.driver_tick(p);check(p.prompt.text.contains("Depart in 12s"),"Driver sees the stop countdown")
 check(s.set_autonomous(p,true) and s.aboard.has(p.get_instance_id()),"Self-drive keeps the worker aboard and the contract earning")
 var npc=game.population.residents[0];e.account_for(npc).balance=1000
 var before:int=e.cash(p);var treasury:int=e.data.council
 check(e.hold_fare(npc,1000,"Bus"),"Public passenger pays the actual fare")
 e.complete_fare(npc,bus)
 check(e.cash(p)==before+700 and e.data.council==treasury+300,"Self-drive still pays the operator 70% and the public council 30%")
 bus.state="moving";s.driver_tick(p);check(p.prompt.text.contains("Time to move"),"Departure prompt changes when the countdown ends")
 bus.state="dwell";bus.speed=0;s.leave_driver(p);s.stop_job(p)
 game.queue_free();await process_frame
 if not failed:print("SIMPLE_CITY_FLOW_OK: automatic passenger fares/passes, separate private delivery, any-stop free council jobs, countdowns, autonomous wages, sparse full-size city")
 quit(1 if failed else 0)
