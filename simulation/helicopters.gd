extends Node3D
# Autonomous air taxis use separate cruise levels and reserve clear landing spaces.
const G=preload("res://transport/geometry.gd")
const BASE_FARE:=500
const W=preload("res://town/world_layout.gd")
var flight_serial:=0
var game: Node3D
var economy: Node
var cars:Array[Dictionary]=[]
var bookings:Dictionary={}
var pads:Array[Dictionary]=[]
var last_notice:Dictionary={}
var elapsed:=0.0
var npc_clock:=0.0
var serial:=0
func _ready() -> void:
 var sites=W.helipads()
 for i in range(sites.size()):
  var point:=Vector3(sites[i].x,-5.02,sites[i].y)
  var pad_name:=str(game.city.ATLAS.at(point).name)+" Helipad "+str(i+1)
  if sites[i]==Vector2(-106,-350):pad_name="Robotics Plaza • Fleet Helipad"
  elif sites[i]==Vector2(-106,-365):pad_name="Robotics Plaza • Autonomous Service Stand"
  var pad={"name":pad_name,"point":point}
  pads.append(pad)
  economy.locations.append(pad.duplicate())
  var stand:=Node3D.new()
  stand.position=point
  add_child(stand)
  G.box(stand,Vector3(0,-.06,0),Vector3(11,.08,11),G.material(Color("697f83")))
  var text:=G.label(stand,"H",Vector3(0,.015,0),85)
  text.rotation.x=-PI/2
  text.pixel_size=.045
  var sign:=G.label(stand,str(pad.name)+"\nE near helicopter • book / board",Vector3(0,.5,5.2),15)
  sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  if i not in [0,1,8,10,12,13,14,15]: continue
  var fleet_index:=cars.size()
  var node:=Node3D.new()
  node.name="Helicopter"+str(i+1)
  add_child(node)
  node.add_to_group("air_taxis")
  node.position=point
  var model:=preload("res://vehicles/helicopter_model.gd").make(fleet_index+1)
  node.add_child(model)
  preload("res://transport/vehicle_motion.gd").setup(node,model)
  var body:=AnimatableBody3D.new()
  body.sync_to_physics=false
  body.collision_layer=2
  var collision:=CollisionShape3D.new()
  var box:=BoxShape3D.new()
  box.size=Vector3(1.9,1.7,3.6)
  collision.shape=box
  collision.position.y=1.15
  body.add_child(collision)
  node.add_child(body)
  node.add_child(preload("res://simulation/service_audio.gd").new())
  cars.append({"node":node,"model":model,"cab_id":"HL-%03d" % (fleet_index+1),"booking":"","state":"idle","path":PackedVector3Array(),"index":0,"speed":0.0,"rotor_speed":0.0,"door":0.0,"clock":0.0,"home":point,"landing":point,"source":point,"cruise":22.0+float(fleet_index%3)*4,"normal_cruise":22.0+float(fleet_index%3)*4,"high_flight":false,"corridor":false,"npc_people":[],"fast":false,"service_after":70.0+float(fleet_index)*75.0,"service_interval":300.0+float(fleet_index%4)*30.0})
 # Allocate each commuter's starting wallet once, before any trip can earn a fare.
 for i in range(cars.size()):
  for side in [-1,1]:
   var person:=Node.new();economy.register(person,"air_commuter/"+str(i)+str(side),20000);person.free()
func _robotics_service_stand() -> Dictionary:
 for pad in pads:
  if str(pad.name)=="Robotics Plaza • Autonomous Service Stand": return pad
 return {}

func quote(person: Node3D, destination: Vector3) -> int:
 var key:String=economy.key_for(person)
 var origin:Vector3=bookings[key].pickup if bookings.has(key) else person.global_position
 return BASE_FARE+int(ceil(Vector2(origin.x,origin.z).distance_to(Vector2(destination.x,destination.z))*4))
func clear_ground(point: Vector3) -> bool:
 if game.city.infill!=null and not game.city.infill.landing_clear(point): return false
 if not W.contains(point) or not W.rail_clear(point,30): return false
 if not W.road_clear(point,12): return false
 if absf(absf(point.x)-160)<12 and point.z>=-156 and point.z<=176: return false
 if (absf(point.z+150)<12 or absf(point.z-170)<12) and absf(point.x)<166: return false
 for site in game.city.outer_parks:
  if absf(point.x-site.point.x)<24 and absf(point.z-site.point.z)<23: return false
 for house in game.city.houses:
  if Vector2(point.x,point.z).distance_to(Vector2(house.position.x,house.position.z))<12: return false
 for park in game.city.parks:
  if absf(point.x-park.position.x)<24 and absf(point.z-park.position.z)<23: return false
 if absf(point.x)<27 and point.z>20 and point.z<76: return false
 return point.distance_to(economy.office)>=13
func landing_free(point: Vector3, ignore := -1) -> bool:
 for i in range(cars.size()):
  if i==ignore: continue
  var car:Dictionary=cars[i]
  if point.distance_to(car.landing)<13: return false
  if car.node.position.y<5 and Vector2(point.x,point.z).distance_to(Vector2(car.node.position.x,car.node.position.z))<13: return false
 return true
func landing_for(point: Vector3, ignore := -1) -> Dictionary:
 var candidates:Array[Vector3]=[]
 for radius in [0.0,16.0,28.0,42.0,58.0]:
  for step in range(12 if radius>0 else 1):
   var angle:=float(step)*TAU/12
   candidates.append(Vector3(point.x+cos(angle)*radius,-5.02,point.z+sin(angle)*radius))
 for pad in pads: candidates.append(pad.point)
 var best:=INF
 var result:Dictionary={}
 for candidate in candidates:
  if not clear_ground(candidate) or not landing_free(candidate,ignore) or not _people_clear(candidate): continue
  var distance:=Vector2(point.x,point.z).distance_to(Vector2(candidate.x,candidate.z))
  if distance<best: best=distance; result={"point":candidate,"name":"Clear landing • "+str(game.city.ATLAS.at(candidate).name)}
 return result
func _people_clear(point: Vector3) -> bool:
 for person in game.party.members+game.population.residents:
  if is_instance_valid(person.get("riding_service")) or is_instance_valid(person.get("riding_bus")) or person.get("driving")==true: continue
  if Vector2(person.global_position.x,person.global_position.z).distance_to(Vector2(point.x,point.z))<8: return false
 return true
func _air_clear(point: Vector3, own: Dictionary) -> bool:
 for other in cars:
  if other.node==own.node: continue
  if absf(point.y-other.node.position.y)<3.3 and Vector2(point.x,point.z).distance_to(Vector2(other.node.position.x,other.node.position.z))<12: return false
 return true
func _valid_destination(point: Vector3) -> bool:
 if not W.contains(point):
  economy.last_error="Choose a location inside the city map."
  return false
 return true
func book(person: Node3D, destination: Dictionary={}, passenger_name: String="", preferred_car := -1, single_ticket := false) -> Dictionary:
 var key:String=economy.key_for(person)
 if person.get_meta("service_driving",false) or key=="" or bookings.has(key) or game.cabs.bookings.has(key) or is_instance_valid(person.get("riding_service")) or is_instance_valid(person.get("riding_bus")) or person.get("driving")==true:
  economy.last_error="Finish or cancel your current ride first."
  return {}
 if person.get("dead")==true or person.get("transitioning")==true or person.get("resting")!="" or is_instance_valid(person.get("active_house")):
  economy.last_error="Go outside, awake and on foot to meet your helicopter."
  return {}
 if destination.has("point") and not _valid_destination(destination.point): return {}
 var fare:int=BASE_FARE if single_ticket else (quote(person,destination.point) if destination.has("point") else BASE_FARE)
 if not economy.can_pay_fare(person,fare,"Helicopter"): economy.last_error="Not enough money for this flight."; return {}
 var selected:=-1
 var landing:Dictionary={}
 var score:=INF
 for i in range(cars.size()):
  var car:Dictionary=cars[i]
  if car.node.has_meta("private_owner") and car.node.get_meta("private_owner")!=key:continue
  if car.state!="idle" or (preferred_car>=0 and i!=preferred_car): continue
  var site:Dictionary={"point":car.node.position,"name":"Parked helicopter"} if person.global_position.distance_to(car.node.position)<4.6 else landing_for(person.global_position,i)
  if site.is_empty(): continue
  var cost:float=car.node.position.distance_to(site.point)+person.global_position.distance_to(site.point)*2
  if is_instance_valid(game.services) and game.services.dispatch.ready_vehicle(car.node):cost-=100000
  if cost<score: score=cost; selected=i; landing=site
 if selected<0: economy.last_error="No helicopter or clear landing space is available. Try again shortly."; return {}
 if passenger_name.strip_edges()=="": passenger_name=str(person.get("person_name")) if person.get("person_name")!=null else str(person.profile.name)
 serial+=1
 var trip={"id":serial,"person":person,"passenger_name":passenger_name.strip_edges().left(28),"destination":destination.duplicate(),"fare":fare,"flat_fare":single_ticket,"pickup":person.global_position,"pickup_curb":landing.point,"state":"approaching","car":selected,"created":elapsed,"wait":0.0}
 bookings[key]=trip
 last_notice.erase(key)
 var car:Dictionary=cars[selected]
 car.booking=key
 car.fast=false
 car.high_flight=false; car.cruise=car.normal_cruise
 car.landing=landing.point
 if car.node.position.distance_to(landing.point)<.2: car.state="waiting"; trip.state="waiting"
 else: _set_flight(car,landing.point,"pickup")
 trip.pickup_wait=landing.point+Vector3(9,0,0)
 _label(car,trip.passenger_name)
 if is_instance_valid(game.services):game.services.dispatch.assigned(car.node,trip)
 return trip
func _set_flight(car: Dictionary, target: Vector3, state: String) -> void:
 car.source=car.node.position
 car.corridor=false
 car.landing=target
 var height:float=-5.02+float(car.cruise)
 car.path=preload("res://transport/vehicle_motion.gd").rounded_path(PackedVector3Array([car.node.position,Vector3(car.node.position.x,height,car.node.position.z),Vector3(target.x,height,target.z),target]),8.0)
 car.index=0; car.clock=0.0; car.state=state
func board_near(person: Node3D) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key): return false
 var trip:Dictionary=bookings[key]
 var car:Dictionary=cars[int(trip.car)]
 if car.state!="waiting" or person.global_position.distance_to(car.node.position)>4.6: economy.last_error="Wait for landing and move beside your helicopter."; return false
 if not economy.hold_fare(person,int(trip.fare),"Helicopter"): return false
 trip.state="boarding"; car.state="boarding"; car.clock=0.0; car.board_start=person.global_position
 car.board_side=-1.0 if car.node.to_local(person.global_position).x<0 else 1.0
 person.riding_service=self
 person.set_meta("cab_car",int(trip.car))
 person.collider.set_deferred("disabled",true)
 person.velocity=Vector3.ZERO
 car.node.get_node("ServiceAudio").effect("door")
 return true
func boarding_point(person:Node3D) -> Vector3:
 var trip:Dictionary=bookings.get(economy.key_for(person),{})
 if trip.is_empty():return person.global_position
 return cars[int(trip.car)].node.to_global(Vector3(2.2,.05,-.45))
func unlock(person: Node3D, _pin := "") -> bool: return board_near(person)
func seat_position(person: Node3D) -> Vector3: return cars[int(person.get_meta("cab_car"))].model.to_global(Vector3(.46,.39,-.45))
func rider_position(person: Node3D) -> Vector3:
 var car:Dictionary=cars[int(person.get_meta("cab_car"))]
 if car.state!="boarding": return seat_position(person)
 var door:Vector3=car.node.to_global(Vector3(float(car.get("board_side",1.0))*1.2,.5,-.45))
 if car.clock<1: return car.board_start.lerp(door,car.clock)
 return door.lerp(seat_position(person),clampf((float(car.clock)-1)/1.4,0,1))
func choose_destination(person: Node3D, destination: Dictionary) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key) or not destination.has("point") or not _valid_destination(destination.point): return false
 var trip:Dictionary=bookings[key]
 var car:Dictionary=cars[int(trip.car)]
 if landing_for(destination.point,int(trip.car)).is_empty(): economy.last_error="No clear landing near this destination."; return false
 var fare:int=int(trip.fare) if trip.get("flat_fare",false) else quote(person,destination.point)
 if trip.state in ["boarding","awaiting_destination"]:
  if not economy.resize_fare(person,fare): return false
 elif trip.state not in ["approaching","waiting"]: return false
 elif not economy.can_pay_fare(person,fare,"Helicopter"): economy.last_error="Not enough money for this flight."; return false
 trip.destination=destination.duplicate(); trip.fare=fare
 if trip.state=="awaiting_destination": _depart(car,trip)
 return true
func _depart(car: Dictionary, trip: Dictionary) -> void:
 var target:Dictionary=landing_for(trip.destination.point,int(trip.car))
 if target.is_empty(): car.state="awaiting_destination"; trip.state="awaiting_destination"; economy.last_error="Landing area is busy. Choose another destination or leave for a refund."; return
 trip.dropoff=target.point; trip.state="riding"
 _set_flight(car,target.point,"dropoff")
func nearest_available(person: Node3D) -> int:
 var index:=-1
 var distance:=4.6
 for i in range(cars.size()):
  if cars[i].state!="idle": continue
  var gap:float=person.global_position.distance_to(cars[i].node.position)
  if gap<distance: distance=gap; index=i
 return index
func walk_up(person: Node3D, index: int) -> Dictionary:
 if index<0 or index>=cars.size() or person.global_position.distance_to(cars[index].node.position)>4.6: return {}
 return book(person,{},"",index)
func is_pickup_near(person: Node3D) -> bool:
 var key:String=economy.key_for(person)
 return bookings.has(key) and bookings[key].state=="waiting" and person.global_position.distance_to(cars[int(bookings[key].car)].node.position)<=4.6
func cancel(person: Node3D) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key) or bookings[key].state in ["boarding","riding","awaiting_destination"]: return false
 var car:Dictionary=cars[int(bookings[key].car)]
 bookings.erase(key); car.booking=""
 person.set_meta("cab_waiting",false);person.remove_meta("waiting_service")
 if car.node.position.y > -4.8: _set_flight(car,car.landing,"returning")
 else: car.state="idle"
 _label(car,"AVAILABLE")
 return true
func _restore(person: Node3D, car: Dictionary) -> void:
 person.visual.dismount(person); person.riding_service=null;person.set_meta("cab_waiting",false);person.remove_meta("waiting_service")
 person.global_position=car.node.to_global(Vector3(3,.1,0))
 person.collider.set_deferred("disabled",false); person.velocity=Vector3.ZERO; person.invulnerability=1
func leave_waiting(person: Node3D) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key) or bookings[key].state!="awaiting_destination": return false
 var car:Dictionary=cars[int(bookings[key].car)]
 _restore(person,car)
 if economy.data.receipts.has(key):
  var amount:int=economy.data.receipts[key].amount
  economy.account_for(person).balance+=amount
  economy.data.receipts.erase(key); economy.record(key,amount,"Unused helicopter flight refunded"); economy.save()
 bookings.erase(key); car.booking=""; car.state="idle"
 _label(car,"AVAILABLE")
 return true
func _finish(car: Dictionary) -> void:
 if car.booking!="" and bookings.has(car.booking):
  var trip:Dictionary=bookings[car.booking]
  var paid:int=economy.data.receipts.get(economy.key_for(trip.person),{}).get("amount",0)
  economy.complete_fare(trip.person,car.node); _restore(trip.person,car)
  if is_instance_valid(game.services):game.services.dispatch.completed(car.node,paid)
  last_notice[car.booking]="Landed near "+str(trip.destination.name)+". Follow the map for the final walk."
  if trip.person==game.player:game.city_map.set_waypoint(trip.destination)
  bookings.erase(car.booking)
 car.booking=""; car.state="idle"; car.speed=0; car.fast=false; car.high_flight=false; car.cruise=car.normal_cruise; car.corridor=false
 if is_instance_valid(game.services):
  for receipt in car.get("npc_commissions",[]):game.services.settle_trip(receipt)
 car.npc_commissions=[]
 for person in car.npc_people: person.free()
 car.npc_people=[]
 _label(car,"AVAILABLE")
func skip_journey(person: Node3D) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key) or bookings[key].state!="riding": return false
 var car:Dictionary=cars[int(bookings[key].car)]
 car.node.position=car.landing
 _finish(car)
 return true
func talk(_person: Node3D, _topic: String) -> bool: return false
func remaining_route(person: Node3D) -> PackedVector3Array:
 var path:=PackedVector3Array()
 var key:String=economy.key_for(person)
 if not bookings.has(key): return path
 var car:Dictionary=cars[int(bookings[key].car)]
 path.append(car.node.position)
 for i in range(int(car.index),car.path.size()): path.append(car.path[i])
 return path
func _label(car: Dictionary, text: String) -> void: car.model.get_meta("label").text=car.cab_id+" • SKYLINK\n"+text
func _physics_process(delta: float) -> void:
 elapsed+=delta
 for car in cars:
  var trip:Dictionary=bookings.get(car.booking,{})
  if not trip.is_empty() and not is_instance_valid(trip.person):
   var key: String=car.booking
   if economy.data.receipts.has(key):
    var amount: int=economy.data.receipts[key].amount
    if economy.data.accounts.has(key): economy.data.accounts[key].balance+=amount
    economy.data.receipts.erase(key); economy.save()
   bookings.erase(key); car.booking=""
   _set_flight(car,car.landing,"returning")
   continue
  if car.state=="robot_service_dwell":
   car.speed=0.0;car.clock=float(car.clock)+delta
   if car.clock>=20.0:
    _set_flight(car,car.home,"robot_service_return")
    _label(car,"ROBOTICS • RETURNING TO PAD")
   continue
  if car.state=="idle" and elapsed>=float(car.get("service_after",INF)) and car.booking=="" and not car.node.has_meta("private_owner") and (not is_instance_valid(game.services) or (not game.services.manual(car.node) and not game.services.dispatch.ready_vehicle(car.node))):
   var service_stand:=_robotics_service_stand()
   if not service_stand.is_empty() and car.home.distance_to(service_stand.point)>=20.0:
    _set_flight(car,service_stand.point,"robot_service")
    _label(car,"ROBOTICS • EN ROUTE")
    continue
   elif car.home.distance_to(service_stand.get("point",car.home))<20.0:
    car.service_after=elapsed+float(car.get("service_interval",300.0))
  if car.state=="waiting":
   trip.wait=float(trip.wait)+delta
   if trip.person.get_meta("cab_waiting",false) and trip.person.global_position.distance_to(car.node.position)<=4.6:board_near(trip.person)
   elif trip.wait>120: cancel(trip.person)
  elif car.state=="boarding":
   car.clock=float(car.clock)+delta
   trip.person.global_position=rider_position(trip.person)
   if car.clock<2: trip.person.visual.play("walk")
   else: trip.person.visual.mount(car.model,Vector3(.46,.39,-.45),PI)
   if car.clock>=3:
    if trip.destination.has("point"): _depart(car,trip)
    else: car.state="awaiting_destination"; trip.state="awaiting_destination"
  elif car.state in ["pickup","dropoff","returning","npc","job_pickup","rental_pickup","robot_service","robot_service_return"]:
   car.clock=float(car.clock)+delta
   if car.clock<.7: continue
   if not car.corridor:
    if not _corridor_free(car): car.speed=0; continue
    car.corridor=true
   while int(car.index)<car.path.size() and car.node.position.distance_to(car.path[int(car.index)])<.005:car.index=int(car.index)+1
   if int(car.index)>=car.path.size():
    if car.state=="pickup": car.state="waiting";car.speed=0.0; trip.state="waiting"
    elif car.state=="returning": car.state="idle"
    elif car.state=="robot_service":
     car.state="robot_service_dwell";car.speed=0.0;car.clock=0.0;car.corridor=false
     _label(car,"CONNECTED • CHARGING")
    elif car.state=="robot_service_return":
     car.state="idle";car.speed=0.0;car.corridor=false
     car.service_after=elapsed+float(car.get("service_interval",300.0))
     _label(car,"AVAILABLE • CHARGED")
    elif car.state=="job_pickup": game.services.work.arrived(car,"Helicopter")
    elif car.state=="rental_pickup": game.services.private_hire.arrived(car)
    else: _finish(car)
    continue
   var remaining:=0.0;var previous:Vector3=car.node.position;var direction:=Vector3.ZERO
   for i in range(int(car.index),car.path.size()):
    var segment:Vector3=car.path[i]-previous
    if direction==Vector3.ZERO and segment.length()>.01:direction=segment.normalized()
    remaining+=segment.length();previous=car.path[i]
   var limit:=minf(38.0 if car.fast else 26.0,7.0/maxf(.18,absf(direction.y)))
   limit=minf(limit,sqrt(14*remaining))
   if is_instance_valid(game.services):limit*=game.services.throttle(car.node)
   car.speed=preload("res://transport/vehicle_motion.gd").speed(float(car.speed),limit,delta,6,7)
   var budget:float=car.speed*delta
   for step in range(48):
    if int(car.index)>=car.path.size() or budget<.00001:break
    var offset:Vector3=car.path[int(car.index)]-car.node.position
    if offset.length()<.005:car.index=int(car.index)+1;continue
    var travel:=minf(budget,offset.length());var proposed:Vector3=car.node.position+offset.normalized()*travel
    if not _air_clear(proposed,car):car.speed=0;break
    car.node.position=proposed;budget-=travel
    if Vector2(offset.x,offset.z).length()>.01:car.node.rotation.y=lerp_angle(car.node.rotation.y,atan2(offset.x,offset.z),1-exp(-5*delta))
    if offset.length()<=travel+.005:car.index=int(car.index)+1
  else: car.speed=0
  if not trip.is_empty() and trip.state=="riding": trip.person.global_position=seat_position(trip.person)
 npc_clock+=delta
 if npc_clock>16 and not OS.has_environment("NOTTINGHAM_TEST"): npc_clock=0; _npc_flight()
func _process(delta: float) -> void:
 for car in cars:
  preload("res://transport/vehicle_motion.gd").render(car.node,car.model)
  var moving:bool=car.state in ["pickup","dropoff","returning","npc","job_pickup","rental_pickup","robot_service","robot_service_return"]
  car.rotor_speed=move_toward(float(car.rotor_speed),34.0 if moving else 0.0,delta*18)
  car.model.get_meta("rotor").rotation.y+=float(car.rotor_speed)*delta
  car.model.get_meta("tail_rotor").rotation.x+=float(car.rotor_speed)*delta*1.6
  car.door=move_toward(float(car.door),1.0 if car.state in ["waiting","boarding","awaiting_destination","job_ready","rental_ready"] else 0.0,delta*2)
  for door in car.model.get_meta("doors"): door.rotation.y=-float(door.get_meta("side"))*float(car.door)*1.2
  car.node.get_node("ServiceAudio").set_motion(10.0 if moving else 0.0,"helicopter")
func _npc_flight() -> void:
 var active:=0
 for car in cars:
  if car.state=="npc": active+=1
 if active>=4: return
 for i in range(cars.size()):
  var car:Dictionary=cars[i]
  if i<2 and (not is_instance_valid(game.services) or game.services.operator_for(car.node).is_empty()):continue
  if car.state!="idle" or car.node.has_meta("private_owner"): continue
  if is_instance_valid(game.services) and game.services.dispatch.ready_vehicle(car.node):continue
  var target:=landing_for(pads[(i+5)%pads.size()].point,i)
  if target.is_empty(): continue
  var people:Array=[]
  car.npc_commissions=[]
  for side in [-1,1]:
   if side<0 and is_instance_valid(game.services) and not game.services.operator_for(car.node).is_empty():continue # Left seat belongs to the work operator.
   var person:=preload("res://transport/crowd_person.gd").new()
   person.variant=i*2+int(side>0)
   car.model.add_child(person)
   person.position=Vector3(side*.46,.11,-.45)
   person.scale=Vector3(.92,.94,.92)
   person.set_seated(true)
   economy.register(person,"air_commuter/"+str(i)+str(side),20000)
   if not economy.charge(person,BASE_FARE,"Public helicopter fare"): person.free(); continue
   people.append(person)
   if is_instance_valid(game.services):car.npc_commissions.append(game.services.capture_fare(car.node,BASE_FARE,economy.key_for(person)))
  if people.is_empty(): return
  car.npc_people=people
  _set_flight(car,target.point,"npc"); _label(car,"PUBLIC FLIGHT")
  return

func _corridor_free(own: Dictionary) -> bool:
 var a:=Vector2(own.source.x,own.source.z)
 var b:=Vector2(own.landing.x,own.landing.z)
 for other in cars:
  if other.node==own.node or not other.get("corridor",false) or other.state not in ["pickup","dropoff","returning","npc","job_pickup","rental_pickup","robot_service","robot_service_return"]: continue
  if absf(float(own.cruise)-float(other.cruise))>3.3: continue
  var c:=Vector2(other.source.x,other.source.z)
  var d:=Vector2(other.landing.x,other.landing.z)
  if Geometry2D.segment_intersects_segment(a,b,c,d)!=null: return false
  for point in [a,b]:
   if Geometry2D.get_closest_point_to_segment(point,c,d).distance_to(point)<16: return false
  for point in [c,d]:
   if Geometry2D.get_closest_point_to_segment(point,a,b).distance_to(point)<16: return false
 return true

func set_high_flight(person: Node3D, enabled: bool) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key): return false
 var trip:Dictionary=bookings[key]
 var car:Dictionary=cars[int(trip.car)]
 if trip.state not in ["boarding","awaiting_destination","riding"]: return false
 car.high_flight=enabled
 car.cruise=(66.0+float(int(trip.car)%3)*4) if enabled else float(car.normal_cruise)
 if trip.state=="riding": _set_flight(car,car.landing,"dropoff")
 return true

func set_fast(person: Node3D, enabled: bool) -> bool:
 var key:String=economy.key_for(person)
 if not bookings.has(key) or bookings[key].state not in ["boarding","awaiting_destination","riding"]: return false
 cars[int(bookings[key].car)].fast=enabled
 return true
