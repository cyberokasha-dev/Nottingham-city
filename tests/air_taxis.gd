extends SceneTree
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1")
 seed(5678)
 call_deferred("run")
func check(value: bool, message: String) -> void:
 if not value: failed=true; push_error(message)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 root.add_child(game)
 game.economy.enabled=false
 game.process_mode=Node.PROCESS_MODE_DISABLED
 var air=game.helicopters
 var road=game.cabs
 var p=game.player
 var e=game.economy
 check(air.cars.size()==8 and road.cars.size()==18,"Eight air taxis serve the core and every station entrance with eighteen road vehicles")
 for pad in air.pads: check(air.clear_ground(pad.point),"Every helipad is clear of houses, roads and playgrounds")
 var car=air.cars[0]
 p.global_position=car.node.position+Vector3(-3,0,0)
 check(game.phone.try_open_near(p),"E at a parked helicopter opens its booking form")
 var key:String=e.key_for(p)
 check(air.bookings.has(key) and air.bookings[key].car==0 and game.phone.service_picker.selected==0,"Walk-up reserves the exact numbered aircraft")
 var trip:Dictionary=air.bookings[key]
 check(road.book(p).is_empty(),"A player cannot reserve a road cab and a helicopter together")
 var destination={"name":"Carlton address","point":Vector3(147.7,-5.02,110)}
 check(air.choose_destination(p,destination),"The existing city atlas supplies flight destinations")
 var wallet:int=e.cash(p)
 var treasury:int=e.data.council
 var fare:int=trip.fare
 check(air.board_near(p),"Either side of the aircraft permits paid boarding without a PIN or circle")
 check(e.cash(p)==wallet-fare and not air.board_near(p),"Boarding charges once and rejects duplicate requests")
 var peak:=-100.0
 var boarded:=false
 var landed:=false
 for frame in range(3000):
  air._physics_process(.05)
  air._process(.05)
  peak=maxf(peak,car.node.position.y)
  if p.visual.mounted:
   boarded=true
   check(p.visual.get_parent()==car.model,"Visible passenger stays attached to the flight cabin")
  if not air.bookings.has(key): landed=true; break
 check(boarded and landed and peak>16.5 and peak<25.1,"A real flight climbs above buildings, crosses the city and lands")
 check(e.cash(p)==wallet-fare and int(e.data.council)==treasury+fare,"Completed flight settles one pound-denominated fare")
 check(p.riding_service==null and p.visual.get_parent()==p,"Landing restores the walking character")
 check(air.clear_ground(car.node.position) and air.landing_free(car.node.position,0),"Arrival uses a clear reserved landing, away from traffic")
 # Destination-later boarding and exact refund.
 p.global_position=car.node.position+Vector3(0,0,3)
 trip=air.walk_up(p,0)
 wallet=e.cash(p)
 check(not trip.is_empty() and air.board_near(p),"A parked helicopter can be booked without a destination")
 for i in range(65): air._physics_process(.05)
 check(trip.state=="awaiting_destination" and car.node.position.y<0,"No destination means parked, never a surprise flight")
 check(air.leave_waiting(p) and e.cash(p)==wallet,"Leaving an unused flight refunds the full boarding payment")
 # Remote pickup flies to the caller, no traffic query is needed.
 p.global_position=Vector3(28,-5.02,40)
 trip=air.book(p,destination,"Flight tester")
 check(not trip.is_empty(),"Remote booking assigns a helicopter and landing point")
 if not trip.is_empty():
  var assigned=air.cars[int(trip.car)]
  for i in range(3000):
   air._physics_process(.05)
   if trip.state=="waiting": break
  check(trip.state=="waiting" and assigned.node.position.distance_to(trip.pickup_curb)<.1,"Remote aircraft lands at the marked pickup")
  p.global_position=assigned.node.position+Vector3(20,0,0)
  check(not air.board_near(p),"Remote boarding cannot teleport someone across the city")
  p.global_position=assigned.node.position+Vector3(3,0,0)
  check(air.board_near(p),"Arrived helicopter can be boarded near its body")
  for i in range(65): air._physics_process(.05)
  check(air.skip_journey(p) and not air.bookings.has(key),"Skipping settles the existing flight without a second fare")
 # Road cab uses the same simpler interaction, including the opposite side.
 p.global_position=road.cars[0].node.position+Vector3(-3,0,0)
 trip=road.walk_up(p,0)
 check(not trip.is_empty() and road.board_near(p),"Road cab boarding also works without the green ring or code")
 for i in range(65): road._physics_process(.05)
 check(road.leave_waiting(p),"Simplified road boarding retains unused-ride refunds")
 # Air separation and visible public passengers remain active with no player ride.
 var first=air.cars[2]
 var second=air.cars[3]
 var first_pose: Transform3D=first.node.transform
 var second_pose: Transform3D=second.node.transform
 first.node.position=Vector3(0,30,0)
 second.node.position=Vector3(5,30,0)
 check(not air._air_clear(first.node.position,first),"Aircraft yield before overlapping another aircraft")
 second.node.position.y=34
 check(air._air_clear(first.node.position,first),"Separate cruise heights allow traffic to cross safely")
 first.node.transform=first_pose
 second.node.transform=second_pose
 air._npc_flight()
 air._npc_flight()
 var public_count:=0
 for aircraft in air.cars:
  if aircraft.state=="npc":
   public_count+=1
   check(aircraft.npc_people.size()==2 and aircraft.npc_people[0].seated,"Public flights carry visible seated fare-paying passengers")
 check(public_count==2,"Multiple autonomous public flights can operate together")
 for i in range(1800): air._physics_process(.05)
 for aircraft in air.cars: check(aircraft.state!="npc","Concurrent public flights complete and release their aircraft")
 for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false): audio.stop(); audio.stream=null
 game.queue_free()
 await process_frame
 if not failed: print("AIR_TAXIS_OK: eight low-flying autonomous helicopters, safe actual flights, map destinations, visible seats, remote and walk-up booking, one fare, refunds and simple E boarding")
 quit(1 if failed else 0)
