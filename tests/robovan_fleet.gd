extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(1910);call_deferred("run")
func check(ok:bool,why:String):
 if not ok:failed=true;push_error(why)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
 for node in [game]+game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
 var service=game.cabs;var e=game.economy;var p=game.player;var s=game.services;var rules=game.city.traffic
 var vans:Array=service.cars.filter(func(item):return item.kind=="Robovan")
 check(vans.size()==10 and service.cars.size()==18,"Ten Robovans join eight Auroras without increasing the resident population")
 var ids:Dictionary={}
 for van in vans:
  var model:Node3D=van.node.get_meta("graphics")
  check(not ids.has(van.cab_id) and van.cab_id.begins_with("RV-") and model.get_meta("label").text.contains(van.cab_id),"Robovans have unique visible matching fleet numbers")
  ids[van.cab_id]=true
  check(int(model.get_meta("seat_count"))==6 and van.body_size.z>5.8,"Six real seats and full-size solid collision belong to the shuttle")
  var door:Node3D=model.get_meta("doors")[0];var closed:Transform3D=door.transform
  service._doors(van,1);check(door.position.distance_to(closed.origin)>1.4 and door.rotation==Vector3.ZERO,"Doors slide clear of the entry instead of tilting through passengers")
  service._doors(van,0);check(door.transform==closed,"Sliding doors close to their exact original transform")
 for item in rules.cars:item.node.position=Vector3(6000,0,6000)
 for person in game.population.residents+game.party.members:
  if person!=p:person.global_position=Vector3(6000,0,6000)
 for bus in game.city.transport.buses:bus.position=Vector3(6000,0,6000)
 for item in service.cars:item.node.position=Vector3(6000,0,6000);item.state="unavailable"
 var van:Dictionary=vans[0];var model:Node3D=van.node.get_meta("graphics");var index:int=service.cars.find(van)
 van.node.position=Vector3(-25,W.LEVEL,-125.5);van.node.rotation.y=PI/2;van.state="idle";service.npc_clock=-100000
 p.global_position=Vector3(0,W.LEVEL,-128);e.account_for(p).balance=100000;game.phone.selected_location={}
 await physics_frame;await physics_frame
 # The actual service tile and Single ticket action deliver this fleet.
 var cash:int=e.cash(p)
 game.phone.open_app("book")
 game.phone.apps.book_grid.get_child(1).pressed.emit()
 game.phone.apps.booking_single.pressed.emit()
 var trip:Dictionary=service.bookings.get(e.key_for(p),{})
 check(not trip.is_empty() and trip.get("kind")=="Robovan" and trip.car==index and e.cash(p)==cash,"Robovan plus Single ticket reserves the fleet without charging before boarding")
 if trip.is_empty():game.queue_free();await process_frame;quit(1);return
 game.phone.panel.hide()
 var initial:Vector3=van.node.position
 for frame in range(5000):
  service._physics_process(.05)
  if trip.state=="waiting":break
 check(initial.distance_to(van.node.position)>8 and trip.state=="waiting","The booked van actually drives to its pickup")
 p.global_position=van.node.position+Vector3(3,0,0)
 check(s.door_interact(p) and p.riding_service==service and e.cash(p)==cash-300,"E at the van boards a paying passenger and holds one fare")
 check(service.choose_destination(p,{"name":"Local destination","point":Vector3(28,W.LEVEL,-128)}) and e.cash(p)==cash-300,"A map choice during boarding keeps the displayed single fare")
 for frame in range(65):service._physics_process(.05)
 for actor in game.party.members:
  actor.animator.active=false
  actor.visual.mount(model,model.get_meta("passenger_seat"),PI,true)
  var skeleton:Skeleton3D=actor.visual.skeleton
  var hip:Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("thigh_l")).origin
  var knee:Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("calf_l")).origin
  var head:Vector3=model.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin)
  check(absf(hip.y-knee.y)<.1 and head.y<2.25,"Every playable character is seated below the Robovan roof")
  if actor!=p:actor.visual.dismount(actor)
 var paid:int=trip.fare;var council:int=e.data.council
 check(game.city_map.navigation_path()==service.remaining_route(p),"The map displays the same route followed by the Robovan")
 var seat:Transform3D=p.visual.transform
 check(service.set_manual(p,true),"The Robovan supports Aurora's manual driving switch")
 Input.action_press("turn_right",.8);Input.action_press("accelerate")
 service._manual_step(van,trip,.1);service._process(.1)
 check(model.get_meta("steering_wheel").rotation.y<-.5,"The visible control wheel turns with actual driving input")
 Input.action_release("turn_right");Input.action_release("accelerate")
 check(service.set_manual(p,false) and p.visual.transform==seat,"Self-drive resumes without moving the passenger between seats")
 service._process(1)
 check(absf(model.get_meta("steering_wheel").rotation.y)<.01,"The in-cabin wheel recentres after manual control")
 for frame in range(5000):
  service._physics_process(.05)
  if not service.bookings.has(e.key_for(p)):break
 check(p.riding_service==null and e.cash(p)==cash-paid and e.data.council==council+paid,"The van completes the actual journey and settles its single fare once")
 var after:int=e.cash(p);e.complete_fare(p,van.node);check(e.cash(p)==after,"Repeat completion never charges again")
 # A busy Aurora queue must not prevent a Robovan dispatch behind it.
 van.state="idle";p.global_position=van.node.position+Vector3(3,0,0)
 var queued:Dictionary=service.book(p,{},"",-1,"Aurora")
 var other=game.party.members[1];other.global_position=p.global_position
 var ready:Dictionary=service.book(other,{},"",-1,"Robovan")
 check(queued.get("state")=="queued" and int(ready.get("car",-1))==index,"One unavailable fleet cannot block dispatch for another vehicle type")
 service.cancel(p);service.cancel(other)
 e.account_for(p).balance=10000;check(e.buy_day_pass(p),"City travel pass is available")
 e.account_for(p).balance=0;p.global_position=van.node.position+Vector3(3,0,0)
 check(not service.walk_up(p,index).is_empty() and service.board_near(p) and e.cash(p)==0,"Saved city pass covers walk-up Robovan entry at a zero balance")
 for frame in range(65):service._physics_process(.05)
 check(service.leave_waiting(p),"Destination-later passenger can leave the parked van normally")
 # A nearby parked van should wait for its caller, rather than circle past a blocked bay.
 var parked:Dictionary=service.cars.filter(func(item):return item.kind=="Aurora")[0]
 parked.node.position=Vector3(45.5,W.LEVEL,30);parked.node.rotation.y=0;parked.state="idle";rules.track_vehicle(parked.node)
 van.node.position=Vector3(46.5,W.LEVEL,46);van.node.rotation.y=0;van.state="idle";rules.track_vehicle(van.node)
 p.global_position=Vector3(47.7,W.LEVEL,35)
 await physics_frame;await physics_frame
 var before_pickup:Vector3=van.node.position
 check(s.simple.book(p,"Robovan","single"),"The simple phone flow can call a nearby van despite another parked car")
 trip=service.bookings.get(e.key_for(p),{})
 for frame in range(100):
  service._physics_process(.05)
  if trip.get("state")=="waiting" or not service.bookings.has(e.key_for(p)):break
 check(trip.get("state")=="waiting" and van.node.position.distance_to(before_pickup)<.1,"The nearby van becomes ready without an unnecessary loop or teleport")
 check(rules.space_clear(van.node.position,van.node.global_basis.z,van.node),"The pickup does not overlap the parked Aurora")
 p.global_position=service.boarding_point(p)
 check(s.door_interact(p) and p.riding_service==service and e.cash(p)==0,"A saved pass enters the actual nearby van with no extra payment")
 for frame in range(65):service._physics_process(.05)
 check(service.skip_journey(p) and not service.bookings.has(e.key_for(p)),"The simple booking departs and completes without a destination form")
 game.queue_free();await process_frame
 if not failed:print("ROBOVAN_FLEET_OK: bounded fleet, unique IDs, six seats, sliding doors, phone pickup, real travel, contained occupants, steering input, manual/self-drive handover, exact fares, independent dispatch queues and pass boarding")
 quit(1 if failed else 0)
