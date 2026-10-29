extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(1047);call_deferred("run")
func check(ok:bool,why:String):
 if not ok:failed=true;push_error(why)
func total(e:Node) -> int:
 var sum:int=e.data.council+e.data.business
 for a in e.data.accounts.values():sum+=int(a.balance)
 return sum
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game)
 game.economy.enabled=false;game.process_mode=Node.PROCESS_MODE_DISABLED
 var s=game.services;var e=game.economy;var p=game.player;var apps=game.phone.apps
 e.account_for(p).balance=1000000
 print("EASY_STAGE phone")
 check(apps.home.get_child(0).get_theme_font_size("font_size")>=19,"Phone icons use readable type")
 apps.selected_vehicle="sports";apps.open("rental");apps.update()
 check(apps.rent_buttons[0].text.contains("£30") and apps.rent_buttons[1].text.contains("£180"),"Prices appear on direct payment buttons")
 var before:int=e.cash(p);apps.rent_buttons[0].pressed.emit()
 check(e.cash(p)==before-3000 and game.fleet.size()==1,"One click rents the shown vehicle at its exact price")
 check(not apps.rent_buttons[0].visible and apps.collect_button.visible,"Active lease hides repeat payment and offers collection")
 s.return_rental(p,"sports");await process_frame
 print("EASY_STAGE displays")
 var places=game.city.get_node("CityPlaces") if game.city.has_node("CityPlaces") else null
 if places==null:
  for child in game.city.get_children():
   if child.get_script()==load("res://town/city_places.gd"):places=child
 check(places!=null,"Civic places exist")
 if places!=null:
  for site in places.sites:
   if site.id=="sales" and not is_instance_valid(site.node):places._build(site)
 var models=get_nodes_in_group("rental_displays")
 check(models.size()==3,"Bus, Aurora and helicopter displays are interactable")
 for model in models:
  var body=model.get_node("SolidRentalDisplay");body.process_mode=Node.PROCESS_MODE_ALWAYS
 await physics_frame;await physics_frame
 for model in models:
  var body=model.get_node("SolidRentalDisplay");var collision=body.get_node("CollisionShape3D")
  var centre:Vector3=collision.global_position
  var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(centre+Vector3(0,8,0),centre,2))
  check(not hit.is_empty() and hit.collider==body,"Rental display blocks the player: "+str(model.get_meta("rental_kind")))
  p.global_position=model.global_position+Vector3(3,0,0)
  check(s.open_display(p) and apps.selected_vehicle==model.get_meta("rental_kind"),"E opens the exact displayed vehicle rental")
 game.phone.panel.hide()
 # Isolate route movement from unrelated demand. Drive real routes, without teleporting arrivals.
 for car in game.city.traffic.cars:car.node.position=Vector3(6000,0,6000)
 for person in game.population.residents:person.global_position=Vector3(6000,0,6000)
 for person in game.party.members:
  if person!=p:person.global_position=Vector3(6000,0,6000)
 for kind in ["Aurora","Helicopter"]:
  print("EASY_STAGE delivery ",kind)
  p.global_position=Vector3(8,W.LEVEL,37)
  before=e.cash(p)
  check(s.work.request(p,kind),kind+" work can be called from the player")
  var op:Dictionary=s.contract_for(p)
  check(not op.is_empty(),kind+" has an actual assigned vehicle")
  if op.is_empty():continue
  var car:Dictionary=s._service_car(op);var previous:Vector3=car.node.position
  check(op.phase=="delivering" and not s.board_driver(p),"Vehicle must arrive before boarding")
  for i in range(12000):
   if kind=="Aurora":s.work.tick(.1)
   else:game.helicopters._physics_process(.1)
   var distance:float=previous.distance_to(car.node.position)
   check(distance<4.1,"Work vehicle follows a continuous journey")
   previous=car.node.position
   if op.phase=="ready":break
  check(op.phase=="ready" and car.state=="job_ready",kind+" arrives and remains reserved for its operator")
  check(s.work.request(p,kind) and e.cash(p)==before,"Council work starts without rental fees and repeat requests never assign twice")
  p.global_position=car.node.position+Vector3(3,0,0)
  check(s.board_driver(p) and s.manual(car.node),"The arrived "+kind+" has an enterable driver seat")
  check(s.leave_driver(p),"The operator can leave the stopped vehicle")
  s.stop_job(p);game.phone.panel.hide()
 print("EASY_STAGE bus request")
 p.global_position=Vector3(500,W.LEVEL,0);before=e.cash(p)
 check(s.work.request(p,"Bus") and s.contract_for(p).is_empty() and e.cash(p)==before,"A bus application remains pending while the worker follows directions to the stop")
 var here:Dictionary=s.work.meeting(p,"Bus");p.global_position=here.point
 check(s.work.request(p,"Bus"),"Any nearby bus stop can start the shift")
 var wait:Dictionary=s.work.pending[e.key_for(p)];p.global_position=wait.meeting.point
 check(not s.work.take_next(p) and e.cash(p)==before,"No fee when no bus has arrived at the entrance")
 var bus:Node3D
 for candidate in game.city.transport.buses:
  if candidate.route.number==wait.meeting.route:bus=candidate;break
 check(bus!=null,"Requested route has a real bus")
 if bus!=null:
  bus.stop_index=wait.meeting.stop_index;bus.distance=bus.route.stops[bus.stop_index].distance;bus._update_position();bus.state="dwell";bus.speed=0
  var manifest:int=bus.manifest.size();p.global_position=bus.entrance()
  check(s.work.take_next(p) and s.contract_for(p).vehicle==bus,"Player takes the actual arrived bus")
  check(e.cash(p)==before and bus.manifest.size()==manifest,"Council bus has no rental fee and preserves its public passengers")
  check(s.leave_driver(p) and s.stop_job(p),"Bus returns to the public route after shift")
 print("EASY_STAGE train request")
 p.global_position=s.work.meeting(p,"Train").point;before=e.cash(p)
 check(s.work.request(p,"Train") and s.contract_for(p).is_empty() and e.cash(p)==before,"Train request also defers assignment and payment until arrival")
 var train_wait:Dictionary=s.work.pending[e.key_for(p)]
 var train:Node3D=game.rail.trains[0]
 var station_index:int=train.route.stops.find(train_wait.meeting.place)
 check(station_index>=0,"Train work meeting names a real station")
 if station_index>=0:
  train.stop_index=station_index;train.distance=train.route.lengths[station_index];train.state="dwell";train.speed=0;train._update_position()
  p.global_position=train.entrance()
  check(s.work.take_next(p) and s.contract_for(p).vehicle==train and e.cash(p)==before,"Take the actual arrived train from its station entrance")
  check(s.leave_driver(p) and s.stop_job(p),"Train leaves the shift safely")
 print("EASY_STAGE courier")
 for kind in ["sports","suv","van","tow","trailer"]:
  print("EASY_COURIER ",kind)
  p.global_position=Vector3(0,W.LEVEL,47)
  check(s.rent_vehicle(p,kind,"hour"),"Can rent "+kind)
  before=e.cash(p)
  check(s.work.start_courier(p,kind) and e.cash(p)==before,"Existing "+kind+" rental starts work without a second fee")
  var op:Dictionary=s.contract_for(p)
  if op.is_empty():continue
  p.driving=true;p.vehicle=op.vehicle;op.vehicle.global_position=op.target.point;p.global_position=op.target.point;op.vehicle.linear_velocity=Vector3.ZERO
  check(s.work.courier_interact(p) and op.phase=="delivery","Collect a parcel at the depot")
  op.vehicle.global_position=op.target.point;p.global_position=op.target.point
  var money:=total(e);var treasury:int=e.data.council
  check(s.work.courier_interact(p) and e.cash(p)==before+1400 and e.data.council==treasury+600 and total(e)==money,"Actual delivery conserves money and pays operator 70%, council 30%")
  check(not s.work.courier_interact(p) and e.cash(p)==before+1400,"Repeating delivery interaction never pays twice")
  p.driving=false;p.vehicle=null
  if kind=="trailer":
   check(s.return_rental(p,kind) and s.contract_for(p).is_empty(),"Returning the rental ends its delivery work before removing the physical vehicle")
  else:s.stop_job(p);s.return_rental(p,kind)
  await process_frame
 print("EASY_STAGE counters")
 check(s.counter_actions("sales")==[["Rent a vehicle","vehicles"]],"Rental counter only handles rentals")
 check(s.counter_actions("market")==[["Work at this shop","shop_job"]] and s.counter_actions("gun_north").is_empty(),"Shop and reserved counters stay in scope")
 p.global_position=Vector3.ZERO
 check(not e.apply_shop_job(p,"market"),"Shop jobs require the correct workplace")
 for site in W.place_sites():
  if site.id=="market":p.global_position=site.point+Vector3(0,0,18)
 check(e.apply_shop_job(p,"market") and e.assignment(p).point==p.global_position,"Shop work is performed at its own supermarket")
 game.queue_free();await process_frame
 if not failed:print("EASY_RENTALS_JOBS_OK: direct prices, readable phone, solid displays, real vehicle deliveries, arrived-bus takeover, all road rentals earn conserved 70/30 delivery fees, focused workers")
 quit(1 if failed else 0)
