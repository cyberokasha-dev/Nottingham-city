extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():OS.set_environment("NOTTINGHAM_TEST","1");seed(1048);call_deferred("run")
func check(value:bool,why:String):
 if not value:failed=true;push_error(why)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
 game.process_mode=Node.PROCESS_MODE_DISABLED
 var p=game.player;var e=game.economy;var s=game.services;var apps=game.phone.apps;var wallet:Dictionary=e.account_for(p);var key:String=e.key_for(p)
 check(apps.book_grid.get_child_count()==4,"Book has exactly four large transport choices")
 check(apps.sheets.jobs.find_children("*","Button",true,false).size()==2,"Jobs has only Driving and Council jobs")
 check(apps.driver_grid.get_child_count()==4,"Driving has four choices and no courier/rental option")
 for kind in ["Aurora","Robovan","Helicopter","Train"]:
  p.position=Vector3(8,W.LEVEL,37);wallet.balance=0
  check(not s.simple.book(p,kind,"single") and e.cash(p)==0,"Insufficient money rejects "+kind+" without starting a booking")
  wallet.balance=10000;var cash:int=e.cash(p)
  check(s.simple.book(p,kind,"single"),"Single "+kind+" can be requested without any pickup/destination form")
  check(e.cash(p)==cash,"Single fare is collected only on actual boarding")
  if kind!="Train":
   var service=game.helicopters if kind=="Helicopter" else game.cabs
   var trip:Dictionary=service.bookings[key]
   check(trip.get("flat_fare",false) and trip.destination.has("point") and int(trip.fare)==int(s.simple.FARES[kind]),"A useful autonomous journey has the exact displayed flat fare")
   check(not s.simple.book(p,kind,"single") and e.cash(p)==cash,"Repeated request cannot charge or create a second ride")
   var car:Dictionary=service.cars[int(trip.car)]
   car.node.position=trip.pickup_curb;car.state="waiting";trip.state="waiting"
   p.position=car.node.position+Vector3(2.5,0,0)
   check(service.board_near(p),"Single ticket enters the actual "+kind)
   var paid:int=e.cash(p)
   check(paid==cash-int(s.simple.FARES[kind]),"Only the displayed fare is deducted")
   check(not service.board_near(p) and e.cash(p)==paid,"Double boarding cannot take a second fare")
   check(service.choose_destination(p,trip.destination) and e.cash(p)==paid,"A map destination cannot increase a single-ticket fare")
   for i in range(40):service._physics_process(.1)
   check(service.skip_journey(p) and e.cash(p)==paid,"Completing the autonomous ride never charges again")
  else:check(game.city_map.destination_active,"Train request marks the nearest station")
 # A day pass is paid once and can immediately book the chosen vehicle.
 wallet.balance=2500
 check(s.simple.book(p,"Robovan","day") and e.cash(p)==0 and e.has_day_pass(p),"Day pass pays once and calls the requested Robovan")
 game.cabs.cancel(p)
 check(s.simple.book(p,"Helicopter","day") and e.cash(p)==0,"An existing day pass makes the next booking without another payment")
 game.helicopters.cancel(p);e.data.travel_passes.erase(key)
 # Stand beside each actual free vehicle, start the job, and enter its driver seat at £0.
 for kind in ["Aurora","Robovan","Helicopter","Bus","Train"]:
  var vehicles:Array=s._public_vehicles(kind)
  if kind in ["Aurora","Robovan"]:vehicles=vehicles.filter(func(vehicle):return vehicle.get_meta("service_kind","")==kind)
  var vehicle:Node3D=vehicles[0]
  for other in s._public_vehicles(kind):
   if s.operators.has(other.get_instance_id()):s.operators.erase(other.get_instance_id())
  if kind in ["Bus","Train"]:
   vehicle.state="dwell";vehicle.speed=0;vehicle.dwell=30
   if kind=="Train":vehicle.ensure_model();vehicle.door_fraction=1
   else:vehicle.model.animate_doors(1)
   p.position=vehicle.entrance()
  else:
   var service=game.helicopters if kind=="Helicopter" else game.cabs
   for car in service.cars:
    if car.node==vehicle:car.state="idle";car.speed=0;car.booking=""
   p.position=vehicle.position+Vector3(2.5,0,0)
   if kind in ["Aurora","Robovan"]:
    check(s.simple.nearby(p,"Robovan" if kind=="Aurora" else "Aurora")!=vehicle,"A driver job never takes a vehicle from the wrong fleet")
  wallet.balance=0;apps._choose_driver_job(kind);apps._request_work()
  check(s.aboard.has(p.get_instance_id()) and p.get_meta("service_driving",false),"Start and enter takes the nearby "+kind+" driver's seat")
  check(e.cash(p)==0 and s.rental(p,kind).is_empty() and not e.data.receipts.has(key),kind+" work never requires rent or creates a passenger fare")
  check(s.leave_driver(p),"Parked worker leaves normally")
  check(s.stop_job(p),"Free shift can be ended")
  if kind=="Train":check(s.simple.transit_kind(p)=="Train","Standing beside the train chooses train work")
 game.queue_free();await process_frame
 if not failed:print("SIMPLE_BOOKING_OK: four choices, two ticket types, exact flat fares, no duplicate charges, reusable day pass and zero-balance walk-up jobs on every vehicle")
 quit(1 if failed else 0)
