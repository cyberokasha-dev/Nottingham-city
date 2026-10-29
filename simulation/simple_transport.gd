extends RefCounted
## The public phone flow: one service, one ticket. Work never purchases a rental.
const FARES={"Aurora":300,"Robovan":300,"Helicopter":500,"Train":400}
var services:Node
var notice:=""
func destination(person:Node3D) -> Dictionary:
 var map=services.game.city_map
 if map.destination_active and person.global_position.distance_to(map.destination)>20:
  return {"name":str(map.selected_place.get("name","Map waypoint")),"point":map.destination}
 # No form is required. A nearby district hub supplies a useful default journey.
 var choices:Array=services.game.city.districts.filter(func(area):return person.global_position.distance_to(area.rank)>100)
 choices.sort_custom(func(a,b):return person.global_position.distance_squared_to(a.rank)<person.global_position.distance_squared_to(b.rank))
 if choices.is_empty():return {}
 return {"name":str(choices[0].name)+" transport hub","point":choices[0].rank}
func book(person:CharacterBody3D,kind:String,ticket:String) -> bool:
 notice=""
 if not FARES.has(kind) or ticket not in ["single","day"]:return false
 var game=services.game;var e=game.economy;var key:String=e.key_for(person)
 if not services.contract_for(person).is_empty() or services.work.pending.has(key):
  e.last_error="You have a driving job. Use Jobs to enter your free work vehicle.";return false
 var ride=game.helicopters if kind=="Helicopter" else game.cabs
 if game.cabs.bookings.has(key) or game.helicopters.bookings.has(key):
  e.last_error="Your vehicle is already coming. Its number and location are on the map.";return false
 if person.driving or person.get_meta("service_driving",false) or person.riding_service!=null or person.riding_bus!=null:
  e.last_error="You are already aboard. Leave this vehicle before calling another.";return false
 var price:int=0 if e.has_day_pass(person) else (2500 if ticket=="day" else int(FARES[kind]))
 if e.cash(person)<price:e.last_error="Not enough money. You need "+e.pounds(price)+".";return false
 if kind=="Train":
  var station:Dictionary=services.nearest_meeting(person,"Train")
  if station.is_empty():e.last_error="No station is available.";return false
  if ticket=="day" and not e.has_day_pass(person) and not e.buy_day_pass(person):return false
  game.city_map.set_waypoint(station)
  notice="Go to "+str(station.name)+". Tap △ / E at the arrived train. "+("Day pass accepted." if e.has_day_pass(person) else "Single ticket £4, paid once on boarding.")
  for train in game.rail.trains:
   if train.is_board_near(person) and train.state=="dwell":
    if train.board(person):notice="Train boarded.";return true
  return true
 var target:=destination(person)
 var trip:Dictionary=game.cabs.book(person,target,person.profile.name,-1,kind,true) if kind in ["Aurora","Robovan"] else game.helicopters.book(person,target,person.profile.name,-1,true)
 if trip.is_empty():return false
 if ticket=="day" and not e.has_day_pass(person) and not e.buy_day_pass(person):ride.cancel(person);return false
 notice=("Cybercab" if kind=="Aurora" else kind)+" is coming directly to you. Tap △ / E beside it to enter."
 if int(trip.car)>=0 and ride.cars[int(trip.car)].state=="waiting":notice="Your "+("Cybercab" if kind=="Aurora" else kind)+" is ready nearby. Tap △ / E beside it to enter."
 if int(trip.car)>=0 and ride.cars[int(trip.car)].state=="waiting" and person.global_position.distance_to(ride.cars[int(trip.car)].node.position)<4.6:
  if ride.board_near(person):notice="Boarding your "+kind+"."
 return true
func nearby(person:Node3D,kind:String) -> Node3D:
 var nearest:Node3D;var gap:=5.0
 for vehicle in services._public_vehicles(kind):
  if kind in ["Aurora","Robovan"] and vehicle.get_meta("service_kind","")!=kind:continue
  var op:Dictionary=services.operator_for(vehicle)
  if (not op.is_empty() and op.owner!=services.game.economy.key_for(person)) or vehicle.has_meta("private_owner"):continue
  var distance:float=services.entry_distance(person,vehicle,kind) if kind in ["Bus","Train"] else person.global_position.distance_to(vehicle.position)
  if distance>=gap:continue
  if kind in ["Bus","Train"]:
   if vehicle.state!="dwell" or absf(float(vehicle.speed))>.1:continue
  else:
   var service=services.game.helicopters if kind=="Helicopter" else services.game.cabs
   var car:Dictionary={}
   for item in service.cars:
    if item.node==vehicle:car=item;break
   if car.is_empty() or car.state!="idle" or absf(float(car.speed))>.1:continue
  nearest=vehicle;gap=distance
 return nearest
func claim_near(person:CharacterBody3D,kind:String) -> bool:
 var vehicle:=nearby(person,kind)
 if vehicle==null:return false
 var op:Dictionary=services.assign_operator(person,kind,vehicle)
 op.council_job=true;op.person=person
 if kind in ["Aurora","Robovan","Helicopter"]:
  op.phase="ready"
  var car:Dictionary=services._service_car(op);car.state="job_ready";car.speed=0
 services._save_work(op);services.game.economy.save();services.game.economy.flush_save()
 return true
func transit_kind(person:Node3D) -> String:
 # One public-transport choice, using the bus or train beside the player.
 var op:Dictionary=services.contract_for(person)
 if not op.is_empty() and op.kind in ["Bus","Train"]:return op.kind
 var wait:Dictionary=services.work.pending.get(services.game.economy.key_for(person),{})
 if not wait.is_empty() and wait.kind in ["Bus","Train"]:return wait.kind
 if nearby(person,"Train")!=null:return "Train"
 if nearby(person,"Bus")!=null:return "Bus"
 var train:Dictionary=services.work.meeting(person,"Train")
 var bus:Dictionary=services.work.meeting(person,"Bus")
 return "Bus" if not bus.is_empty() and (train.is_empty() or float(bus.distance)<float(train.distance)) else "Train"
