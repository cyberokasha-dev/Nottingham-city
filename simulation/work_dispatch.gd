extends RefCounted
# Work dispatch runs separately from passenger bookings. Only a free vehicle is reserved.
const W=preload("res://town/world_layout.gd")
var services:Node
var pending:Dictionary={}
var clock:=0.0
func message(text:String) -> bool:
 services.game.economy.last_error=text
 return false
func meeting(person:Node3D,kind:String) -> Dictionary:
 if kind!="Bus":return services.nearest_meeting(person,kind)
 var best:Dictionary={};var gap:=INF
 for route in services.game.city.transport.routes:
  for i in range(route.stops.size()):
   var stop:Dictionary=route.stops[i]
   var distance:float=person.global_position.distance_to(stop.pavement)
   if distance<gap:
    gap=distance;best={"name":str(route.number)+" • "+str(stop.name),"point":stop.pavement,"distance":distance,"place":stop,"route":route.number,"stop_index":i}
 return best
func on_foot(person:Node) -> bool:
 return not person.dead and person.resting=="" and not person.driving and person.riding_bus==null and person.riding_service==null and not person.transitioning and not person.get_meta("service_driving",false)
func request(person:CharacterBody3D,kind:String,term:="hour") -> bool:
 if kind not in ["Bus","Train","Aurora","Robovan","Helicopter"]:return false
 var game=services.game;var key:String=game.economy.key_for(person)
 var current:Dictionary=services.contract_for(person)
 if not current.is_empty():
  if current.kind==kind:return true
  return message("End your current shift before choosing another vehicle.")
 if not on_foot(person):return message("Leave your current vehicle before requesting a work vehicle.")
 # A queued passenger pickup must not turn a driver into a paying passenger.
 for service in [game.cabs,game.helicopters]:
  if service.bookings.has(key) and not service.cancel(person):return message("Leave your current ride before starting work.")
 if services.simple.claim_near(person,kind):
  pending.erase(key)
  game.economy.last_error="Work vehicle ready. Start and enter for free.";return true
 if kind in ["Bus","Train"]:
  var place:=meeting(person,kind)
  if place.is_empty():return message("No stop is available.")
  pending[key]={"person":person,"kind":kind,"term":term,"meeting":place}
  game.city_map.set_waypoint(place)
  game.economy.last_error="Shift reserved • "+str(place.name)+". Follow the map, then enter the next arrived "+kind.to_lower()+" with Triangle / E. Starting work is free."
  return true
 var service=game.cabs if kind in ["Aurora","Robovan"] else game.helicopters
 var selected:Dictionary={};var selected_path:=PackedVector3Array();var pickup:=Vector3.ZERO;var gap:=INF
 for i in range(service.cars.size()):
  var car:Dictionary=service.cars[i]
  if kind in ["Aurora","Robovan"] and car.kind!=kind:continue
  if car.state!="idle" or services.operators.has(car.node.get_instance_id()) or car.node.has_meta("private_owner"):continue
  var path:=PackedVector3Array();var target:=Vector3.ZERO
  if kind in ["Aurora","Robovan"]:
   target=game.cabs.curb(person.global_position);path=game.cabs._pickup_path(car,target)
   if path.is_empty():continue
  else:
   var landing:Dictionary=service.landing_for(person.global_position,i)
   if landing.is_empty():continue
   target=landing.point
  var distance:float=car.node.position.distance_to(target)
  if distance<gap:gap=distance;selected=car;selected_path=path;pickup=target
 if selected.is_empty():return message("All work vehicles are busy. No payment taken. Try again shortly.")
 pending.erase(key)
 var op:Dictionary=services.assign_operator(person,kind,selected.node)
 op.council_job=true;op.phase="delivering";op.person=person;op.pickup=pickup;op.progress=Time.get_ticks_msec()
 if kind in ["Aurora","Robovan"]:
  selected.state="job_pickup";selected.path=selected_path;selected.index=0;selected.speed=0.0
  game.cabs._branding(selected,person.profile.name+" • WORK VEHICLE")
 else:service._set_flight(selected,pickup,"job_pickup");service._label(selected,"WORK • "+person.profile.name)
 services._save_work(op);game.economy.save();game.economy.flush_save()
 game.city_map.set_waypoint({"name":"Your "+kind+" • "+str(selected.cab_id),"point":pickup})
 game.economy.last_error=str(selected.cab_id)+" is coming to you. Follow the vehicle on the map; press E beside it when parked."
 return true
func candidate(person:Node) -> Node3D:
 var wait:Dictionary=pending.get(services.game.economy.key_for(person),{})
 if wait.is_empty() or person.global_position.distance_to(wait.meeting.point)>(50 if wait.kind=="Train" else 20):return null
 var list:Array=services.game.city.transport.buses if wait.kind=="Bus" else services.game.rail.trains
 for vehicle in list:
  if vehicle.state!="dwell" or absf(float(vehicle.speed))>.1 or services.operators.has(vehicle.get_instance_id()):continue
  if wait.kind=="Bus" and (vehicle.route.number!=wait.meeting.route or vehicle.stop_index!=int(wait.meeting.stop_index)):continue
  if vehicle.entrance().distance_to(wait.meeting.point)>45:continue
  if services.entry_distance(person,vehicle,wait.kind)<=6:return vehicle
 return null
func take_next(person:CharacterBody3D) -> bool:
 if not on_foot(person):return false
 var key:String=services.game.economy.key_for(person)
 var wait:Dictionary=pending.get(key,{})
 var vehicle:=candidate(person)
 if wait.is_empty() or vehicle==null:return message("Wait at this stop, then press Triangle / E at the arrived vehicle door to drive.")
 var op:Dictionary=services.assign_operator(person,wait.kind,vehicle);op.council_job=true;services._save_work(op);pending.erase(key)
 if not services.board_driver(person):return message("Vehicle assigned. Stand at its entrance to enter the driver cab.")
 services.game.economy.last_error="Shift started • you earn 70% of paid fares; council keeps 30%."
 return true
func arrived(car:Dictionary,kind:String) -> void:
 var op:Dictionary=services.operator_for(car.node)
 if op.is_empty():return
 op.phase="ready";car.state="job_ready";car.speed=0.0
 if kind in ["Aurora","Robovan"]:
  services.game.cabs._park_at_curb(car);services.game.cabs._doors(car,1)
  services.game.cabs._branding(car,"WORK VEHICLE • PRESS E")
 else:services.game.helicopters._label(car,"WORK VEHICLE • PRESS E")
 services._save_work(op);services.game.economy.save()
 if is_instance_valid(op.get("person")):op.person._notify(str(car.cab_id)+" has arrived. Press E beside it to enter the driver seat.")
func cancel(op:Dictionary) -> void:
 if op.kind=="Courier":
  if is_instance_valid(op.get("parcel")):op.parcel.queue_free()
  return
 if op.kind not in ["Aurora","Robovan","Helicopter"] or op.get("phase","") not in ["delivering","ready"]:return
 var car:Dictionary=services._service_car(op)
 if car.is_empty():return
 if op.kind in ["Aurora","Robovan"]:
  car.path=services.game.cabs.path_between(car.node.position,car.home_slot,car.node.global_basis.z);car.index=0
  car.state="returning" if not car.path.is_empty() else "idle"
  services.game.cabs._doors(car,0);services.game.cabs._branding(car,"AVAILABLE")
 else:services.game.helicopters._set_flight(car,car.home,"returning")
func tick(delta:float) -> void:
 clock+=delta
 if clock<.015:return
 var step:=clock;clock=0
 for op in services.operators.values():
  if op.kind not in ["Aurora","Robovan"] or op.get("phase","")!="delivering":continue
  var car:Dictionary=services._service_car(op)
  if car.is_empty():continue
  if int(car.index)>=car.path.size():arrived(car,op.kind);continue
  var travel:float=services.game.cabs._advance_route(car,step,op.get("person"))
  if travel>.01:op.progress=Time.get_ticks_msec()
  elif Time.get_ticks_msec()-int(op.get("progress",0))>40000:
   var path:PackedVector3Array=services.game.cabs.path_between(car.node.position,op.pickup,car.node.global_basis.z)
   if not path.is_empty():car.path=path;car.index=0
   op.progress=Time.get_ticks_msec()
func status(person:Node,kind:String) -> String:
 var op:Dictionary=services.contract_for(person)
 if not op.is_empty() and op.kind==kind:
  if kind=="Courier":return courier_status(op)
  var text:=str(op.get("phase","active"))
  if kind in ["Aurora","Robovan","Helicopter"]:
   var car:Dictionary=services._service_car(op)
   if not car.is_empty():text=str(car.cab_id)+" • "+text
  if op.get("phase","")=="active" and kind in ["Aurora","Robovan","Helicopter"]:text+="\n"+services.dispatch.description(op)
  return text+"\n"+str(op.trips)+" paid trips • earned "+services.game.economy.pounds(op.earnings)
 var wait:Dictionary=pending.get(services.game.economy.key_for(person),{})
 if not wait.is_empty() and wait.kind==kind:return "Confirmed at "+str(wait.meeting.name)+"\nTriangle / E at the next arrived "+kind.to_lower()+" enters the driver seat."
 return {"Aurora":"Your work Aurora comes to you.","Robovan":"Your work Robovan comes to you.","Helicopter":"Your work helicopter lands at a clear spot nearby.","Bus":"Start this job; follow the marked stop and enter the next bus.","Train":"Start this job; follow the marked station and enter the next train.","Courier":"Rent any road vehicle and carry supermarket deliveries."}.get(kind,"")
func start_courier(person:CharacterBody3D,kind:String,term:="hour") -> bool:
 if kind not in ["sports","suv","van","tow","trailer"]:return false
 if not services.contract_for(person).is_empty():return message("End your current shift first.")
 if not on_foot(person) and not (person.driving and services.can_drive(person,person.vehicle)):return message("Leave your passenger vehicle before starting work.")
 if services.rental(person,kind).is_empty() and not services.rent_vehicle(person,kind,term):return false
 if not services.collect_rental(person,kind):return message("Free a depot bay to collect your rental.")
 var lease:Dictionary=services.rental(person,kind);var body:Node3D=services.spawned[str(lease.id)].body
 var op:Dictionary=services.assign_operator(person,"Courier",body)
 op.lease_kind=kind;op.phase="pickup";op.autonomous=false;op.target={"name":"Collect supermarket delivery • Rental Depot","point":Vector3(0,W.LEVEL,47)}
 services._save_work(op);services.game.economy.save();services.game.economy.flush_save()
 services.game.city_map.set_waypoint(op.target)
 services.game.economy.last_error="Delivery work ready. Drive your rental to the depot marker, stop and press E."
 return true
func courier_status(op:Dictionary) -> String:
 return ("Collect at depot" if op.phase=="pickup" else str(op.target.name))+"\nStop your rented vehicle at the marker and press E.\n"+str(op.trips)+" deliveries • earned "+services.game.economy.pounds(op.earnings)
func parcel(op:Dictionary) -> void:
 if is_instance_valid(op.get("parcel")):return
 var box:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.5,.35,.4);box.mesh=mesh
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color("ae8553");box.material_override=mat
 op.vehicle.add_child(box);box.position=Vector3(0,.8,-.5);op.parcel=box
func courier_interact(person:Node) -> bool:
 var op:Dictionary=services.contract_for(person)
 if op.is_empty() or op.kind!="Courier" or not person.driving or person.vehicle!=op.vehicle:return false
 if op.vehicle.linear_velocity.length()>1.2 or person.global_position.distance_to(op.target.point)>14 or op.vehicle.global_position.distance_to(op.target.point)>14:return false
 var game=services.game
 if services.operator_for(op.vehicle).is_empty():return message("This work rental has expired. Renew it before taking deliveries.")
 if op.phase=="pickup":
  var markets=W.place_sites().filter(func(site):return site.kind=="market")
  var site:Dictionary=markets[int(op.trips)%markets.size()]
  op.target={"name":"Deliver to "+str(site.name),"point":site.point+Vector3(0,0,18)};op.phase="delivery";parcel(op)
  person._notify("Parcel loaded. Deliver to "+str(site.name)+" • £20 trip, your share £14.")
 else:
  if int(game.economy.data.business)<2000:person._notify("The shop cannot pay for this delivery yet.");return true
  var receipt:Dictionary=services.capture_fare(op.vehicle,2000,"business/deliveries")
  game.economy.data.business=int(game.economy.data.business)-2000;game.economy.data.council=int(game.economy.data.council)+2000
  game.economy.record("business/deliveries",-2000,"Supermarket delivery",2000)
  # Reset the completed task before the atomic settlement flush, preventing reload/replay payouts.
  op.phase="pickup";op.target={"name":"Collect supermarket delivery • Rental Depot","point":Vector3(0,W.LEVEL,47)}
  if is_instance_valid(op.get("parcel")):op.parcel.queue_free();op.erase("parcel")
  services._save_work(op);services.settle_trip(receipt)
  person._notify("Delivery paid • £14 to you, £6 to the council.")
 op.erase("map_route")
 services._save_work(op);game.economy.save();game.economy.flush_save();game.city_map.set_waypoint(op.target)
 return true
