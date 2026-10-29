extends RefCounted
# Driver jobs use the ordinary paid passenger bookings and visible boarding paths.
var services:Node
var clock:=0.0
func ready_vehicle(vehicle:Node3D) -> bool:
 var op:Dictionary=services.operator_for(vehicle)
 return not op.is_empty() and op.kind in ["Aurora","Robovan","Helicopter"] and op.get("council_job",false) and op.get("phase","")=="active"
func service_for(kind:String) -> Node3D:
 return services.game.cabs if kind in ["Aurora","Robovan"] else services.game.helicopters
func trip_for(op:Dictionary) -> Dictionary:
 if op.is_empty() or op.kind not in ["Aurora","Robovan","Helicopter"]:return {}
 var car:Dictionary=services._service_car(op)
 if car.is_empty():return {}
 return service_for(op.kind).bookings.get(car.booking,{})
func assigned(vehicle:Node3D,trip:Dictionary) -> void:
 if not ready_vehicle(vehicle):return
 var op:Dictionary=services.operator_for(vehicle)
 op.customer_key=services.game.economy.key_for(trip.person)
 var owner:Node=op.get("person")
 if is_instance_valid(owner):
  owner._notify("New booking • "+str(trip.passenger_name)+" → "+str(trip.destination.get("name","destination after boarding"))+" • "+services.game.economy.pounds(trip.fare))
  if owner==services.game.player:services.game.city_map.set_waypoint({"name":"Pick up "+str(trip.passenger_name),"point":trip.pickup_curb})
func completed(vehicle:Node3D,amount:int) -> void:
 var op:Dictionary=services.operator_for(vehicle)
 if op.is_empty():return
 op.erase("customer_key");op.demand_wait=0.0
 var person:Node=op.get("person")
 if is_instance_valid(person):person._notify("Trip complete • your share "+services.game.economy.pounds(amount-int(amount*30/100))+" • council "+services.game.economy.pounds(int(amount*30/100)))
func eligible(person:Node) -> bool:
 var game=services.game
 var key:String=game.economy.key_for(person)
 return not person.dead and not person.has_meta("service_counter") and person.resting=="" and person.current_house==null and not person.house_transition and not person.in_conversation and person.combat_time<=0 and person.riding_service==null and not person.get_meta("cab_waiting",false) and not game.cabs.bookings.has(key) and not game.helicopters.bookings.has(key)
func request(op:Dictionary,passenger:Node3D,destination:Dictionary) -> bool:
 if op.is_empty() or op.kind not in ["Aurora","Robovan","Helicopter"] or op.get("phase","")!="active" or not destination.has("point"):return false
 var car:Dictionary=services._service_car(op)
 if car.is_empty() or car.state!="idle" or car.booking!="":return false
 var service:=service_for(op.kind)
 var name:String=str(passenger.get("person_name")) if passenger.get("person_name")!=null else str(passenger.profile.name)
 var trip:Dictionary=service.book(passenger,destination,name,service.cars.find(car))
 if trip.is_empty():return false
 passenger.set_meta("cab_waiting",true);passenger.set_meta("waiting_service",op.kind)
 return true
func tick(delta:float) -> void:
 clock+=delta
 if clock<.5:return
 var step:=clock;clock=0
 var game=services.game
 for op in services.operators.values():
  if not ready_vehicle(op.vehicle):continue
  var car:Dictionary=services._service_car(op)
  if car.state!="idle" or car.booking!="":continue
  op.demand_wait=float(op.get("demand_wait",0))+step
  if op.demand_wait<3:continue
  op.demand_wait=0.0
  var people:Array=game.population.residents.duplicate()
  people.sort_custom(func(a,b):return a.global_position.distance_squared_to(car.node.global_position)<b.global_position.distance_squared_to(car.node.global_position))
  for person in people:
   if not eligible(person) or Time.get_ticks_msec()-int(person.get_meta("last_work_trip",-100000))<30000:continue
   var destinations:Array=[{"name":person.home.address,"point":person.home.entrance()},{"name":"Council Office","point":game.economy.office}]
   for location in game.economy.locations:
    if not str(location.name).begins_with("House ") and person.global_position.distance_to(location.point)>80:destinations.append(location)
    if destinations.size()>=6:break
   var booked:=false
   for destination in destinations:
    if person.global_position.distance_to(destination.point)<60:continue
    if request(op,person,destination):booked=true;break
   if booked:person.set_meta("last_work_trip",Time.get_ticks_msec());break
func description(op:Dictionary) -> String:
 var trip:=trip_for(op)
 if trip.is_empty():return "Waiting for passenger bookings"
 var car:Dictionary=services._service_car(op)
 var action:String="Pick up" if car.state in ["pickup","waiting"] else ("Boarding" if car.state=="boarding" else "Take passenger to")
 return action+" • "+str(trip.passenger_name)+"\nDestination: "+str(trip.destination.get("name","chosen after boarding"))+"\nFare "+services.game.economy.pounds(trip.fare)+" • your share "+services.game.economy.pounds(int(trip.fare)-int(int(trip.fare)*30/100))
func markers(person:Node) -> Array:
 var op:Dictionary=services.contract_for(person)
 if op.is_empty() or op.kind not in ["Aurora","Robovan","Helicopter"]:return []
 var car:Dictionary=services._service_car(op)
 if car.is_empty():return []
 var result:Array=[{"name":str(car.cab_id)+" • work vehicle","point":car.node.global_position,"icon":"D"}]
 var trip:=trip_for(op)
 if not trip.is_empty():
  if car.state in ["pickup","waiting","boarding"]:result.append({"name":"Pick up "+str(trip.passenger_name),"point":trip.pickup_curb,"icon":"P"})
  if trip.destination.has("point"):result.append({"name":str(trip.destination.name),"point":trip.destination.point,"icon":"F"})
 return result
