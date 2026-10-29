extends RefCounted
# Private hire never creates a public work contract or carries public passengers.
const W=preload("res://town/world_layout.gd")
var services:Node
var records:Dictionary={}
var clock:=0.0
func record_for(person:Node,kind:String) -> Dictionary:
 return records.get(services.game.economy.key_for(person)+"/"+kind,{})
func covered(person:Node,kind:String) -> bool:
 var rental_kind:String={"Aurora":"car","Robovan":"Robovan","Helicopter":"Helicopter"}.get(kind,"")
 if rental_kind=="":return false
 var r:=record_for(person,rental_kind)
 if r.is_empty() or services.rental(person,rental_kind).is_empty():return false
 var key:String=services.game.economy.key_for(person)
 var service=services.game.cabs if kind in ["Aurora","Robovan"] else services.game.helicopters
 var trip:Dictionary=service.bookings.get(key,{})
 return str(person.get_meta("private_boarding",""))==r.lease_id or (not trip.is_empty() and int(trip.car)==int(r.index))
func request(person:CharacterBody3D,kind:String,term:String) -> bool:
 var game=services.game;var e=game.economy
 if kind not in ["car","Robovan","bus_private","Helicopter"]:return services.rent_vehicle(person,kind,term)
 if not services.work.on_foot(person):e.last_error="Stand outside on foot to receive your private rental.";return false
 var previous:=record_for(person,kind)
 if not previous.is_empty():show_vehicle(person,kind);e.last_error="Your rental is already active. No extra payment taken.";return true
 var car:Dictionary={};var index:=-1;var path:=PackedVector3Array();var pickup:=Vector3.ZERO;var gap:=INF
 if kind=="bus_private":
  var slot:Vector3=services._free_slot(kind)
  if slot==Vector3.ZERO:e.last_error="The delivery bays are busy. No payment taken.";return false
  pickup=game.cabs.curb(person.global_position)
  path=game.cabs.path_between(slot,pickup)
  if path.is_empty():e.last_error="Stand near a road for bus delivery. No payment taken.";return false
 else:
  var service=game.cabs if kind in ["car","Robovan"] else game.helicopters
  for i in range(service.cars.size()):
   var candidate:Dictionary=service.cars[i]
   if kind in ["car","Robovan"] and candidate.kind!=("Robovan" if kind=="Robovan" else "Aurora"):continue
   if candidate.state!="idle" or candidate.node.has_meta("private_owner") or not services.operator_for(candidate.node).is_empty():continue
   var target:=Vector3.ZERO;var candidate_path:=PackedVector3Array()
   if kind in ["car","Robovan"]:
    target=game.cabs.curb(person.global_position);candidate_path=game.cabs._pickup_path(candidate,target)
    if candidate_path.is_empty():continue
   else:
    var landing:Dictionary=game.helicopters.landing_for(person.global_position,i)
    if landing.is_empty() or landing.point.distance_to(person.global_position)>80:continue
    target=landing.point
   var distance:float=candidate.node.global_position.distance_to(target)
   if distance<gap:gap=distance;car=candidate;index=i;pickup=target;path=candidate_path
  if car.is_empty():e.last_error="No free vehicle or safe nearby pickup. Move to a clear roadside or helipad. No payment taken.";return false
 if services.rental(person,kind).is_empty() and not services.rent_vehicle(person,kind,term,true):return false
 var lease:Dictionary=services.rental(person,kind)
 if kind=="bus_private":
  if not services.spawned.has(str(lease.id)):
   var slot:Vector3=services._free_slot(kind)
   if slot==Vector3.ZERO:return false
   services._spawn(lease,slot)
  var body:Node3D=services.spawned[str(lease.id)].body
  # VehicleBody remains frozen during delivery, then resumes its normal driving physics.
  var raised:=PackedVector3Array()
  for point in path:raised.append(point+Vector3(0,.65,0))
  path=raised
  car={"node":body,"state":"rental_pickup","path":path,"index":0,"speed":0.0,"fast":false,"half_length":6.0,"cab_id":"PRIVATE BUS "+str(lease.id)}
 else:
  car.node.set_meta("private_owner",e.key_for(person));car.node.set_meta("private_kind",kind)
  if kind=="Helicopter":game.helicopters._set_flight(car,pickup,"rental_pickup")
  else:car.state="rental_pickup";car.path=path;car.index=0;car.speed=0.0;game.cabs._branding(car,person.profile.name+" • PRIVATE RENTAL")
 var record={"person":person,"owner":e.key_for(person),"kind":kind,"car":car,"index":index,"lease_id":str(lease.id),"phase":"delivering","pickup":pickup}
 records[e.key_for(person)+"/"+kind]=record
 if not e.data.has("private_deliveries"):e.data.private_deliveries={}
 e.data.private_deliveries[e.key_for(person)+"/"+kind]={"owner":e.key_for(person),"kind":kind}
 e.last_error=str(car.cab_id)+" is coming to the marked pickup near you."
 show_vehicle(person,kind);e.save();e.flush_save();return true
func arrived(car:Dictionary) -> void:
 for r in records.values():
  if r.car.node!=car.node:continue
  r.phase="ready";car.state="rental_ready";car.speed=0.0
  if r.kind in ["car","Robovan"]:services.game.cabs._park_at_curb(car);services.game.cabs._doors(car,1)
  if r.kind=="bus_private":car.node.park()
  if is_instance_valid(r.person):r.person._notify(str(car.cab_id)+" has arrived • Triangle / E to enter.")
  return
func tick(delta:float) -> void:
 clock+=delta
 if clock<.05:return
 var step:=clock;clock=0
 for key in records.keys():
  var r:Dictionary=records[key];var car:Dictionary=r.car
  if not is_instance_valid(car.node):records.erase(key);continue
  if services.rental(r.person,r.kind).is_empty():
   if (car.has("booking") and car.booking!="") or (r.kind=="bus_private" and car.node.driver_active):continue
   release(r.person,r.kind);continue
  if r.phase=="delivering" and r.kind!="Helicopter":
   services.game.cabs._advance_route(car,step,r.person)
   if int(car.index)>=car.path.size():arrived(car)
  elif r.kind!="bus_private" and car.state=="idle" and str(car.booking)=="":
   car.state="rental_ready";r.phase="ready"
func show_vehicle(person:Node,kind:String) -> bool:
 var r:=record_for(person,kind)
 if r.is_empty():return false
 services.game.city_map.set_waypoint({"name":str(r.car.cab_id)+" • your private rental","point":r.pickup if r.phase=="delivering" else r.car.node.global_position});return true
func board(person:CharacterBody3D,kind:String) -> bool:
 var r:=record_for(person,kind)
 if r.is_empty():return false
 var car:Dictionary=r.car
 if car.state!="rental_ready" or (person.vehicle_distance(car.node) if kind=="bus_private" else person.global_position.distance_to(car.node.global_position))>4.5:
  services.game.economy.last_error="Wait beside your parked rental.";return false
 if kind=="bus_private":return person.try_enter()
 var service=services.game.cabs if kind in ["car","Robovan"] else services.game.helicopters
 car.state="idle"
 person.set_meta("private_boarding",r.lease_id)
 var trip:Dictionary=service.book(person,{},"",r.index)
 if trip.is_empty():person.remove_meta("private_boarding");car.state="rental_ready";return false
 var boarded:bool=service.board_near(person);person.remove_meta("private_boarding")
 if not boarded:return false
 r.phase="in_use";return true
func release(person:Node,kind:String) -> bool:
 var r:=record_for(person,kind)
 if r.is_empty():return true
 var car:Dictionary=r.car
 if (car.has("booking") and car.booking!="") or (r.kind=="bus_private" and car.node.driver_active):
  services.game.economy.last_error="Finish the journey and leave your rental before returning it.";return false
 if kind!="bus_private":
  car.node.remove_meta("private_owner");car.node.remove_meta("private_kind")
  if kind=="Helicopter":services.game.helicopters._set_flight(car,car.home,"returning")
  else:
   car.path=services.game.cabs.path_between(car.node.position,car.home_slot,car.node.global_basis.z);car.index=0;car.state="returning"
 records.erase(services.game.economy.key_for(person)+"/"+kind)
 services.game.economy.data.get("private_deliveries",{}).erase(services.game.economy.key_for(person)+"/"+kind)
 return true
func restore() -> void:
 for saved in services.game.economy.data.get("private_deliveries",{}).values().duplicate():
  for person in services.game.party.members:
   if services.game.economy.key_for(person)==saved.owner and not services.rental(person,saved.kind).is_empty():request.call_deferred(person,saved.kind,"hour")
func route_for(person:Node) -> PackedVector3Array:
 for r in records.values():
  if r.person==person and r.phase=="delivering" and is_instance_valid(r.car.node):return PackedVector3Array([r.car.node.global_position])+r.car.path.slice(int(r.car.index))
 return PackedVector3Array()
func status(person:Node,kind:String) -> String:
 var r:=record_for(person,kind)
 if r.is_empty():return ""
 return str(r.car.cab_id)+" • "+("Coming to your pickup" if r.phase=="delivering" else ("Parked nearby • Triangle / E to enter" if r.phase=="ready" else "Private rental in use"))
