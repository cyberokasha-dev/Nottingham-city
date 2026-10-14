extends SceneTree
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1")
 Engine.physics_ticks_per_second=30
 call_deferred("run")
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 root.add_child(game)
 game.economy.enabled=false
 game.player.set_physics_process(false)
 var p=game.player
 p.global_position=Vector3(47.7,-4.98,35)
 var trip=game.cabs.book(p,{"name":"Gedling","point":Vector3(147.7,-4.98,-90)})
 var boarded=false
 var completed=false
 var start_cash=game.economy.cash(p)
 for frame in range(5400):
  await physics_frame
  if trip.state=="waiting" and not boarded:
   p.global_position=trip.pickup_curb+Vector3(1.5,0,0)
   boarded=game.cabs.unlock(p,trip.pin)
  if boarded and p.riding_service==null:
   completed=true
   break
  if frame%900==0: print("LIVE_FLOW ",frame," trip ",trip.state," car ",game.cabs.cars[trip.car].node.position," idx ",game.cabs.cars[trip.car].index)
  if not game.cabs.bookings.has(game.economy.key_for(p)):break
 var correct_fare=boarded and start_cash-game.economy.cash(p)==int(trip.fare) and not game.economy.data.receipts.has(game.economy.key_for(p))
 completed=completed and correct_fare
 print("LIVE_FLOW_RESULT boarded=",boarded," completed=",completed," fare=",start_cash-game.economy.cash(p))
 if not completed:
  var car=game.cabs.cars[trip.car]
  print("FAILED_ROUTE ",car.path," index ",car.index)
  for other in game.city.traffic.vehicle_nodes():
   if other!=car.node and other.global_position.distance_to(car.node.position)<17: print("BLOCKER ",other.name," ",other.global_position," dir ",other.global_basis.z)
  for person in game.city.traffic.pedestrians:
   if person.global_position.distance_to(car.node.position)<10: print("PED ",person.name," ",person.global_position)
 game.process_mode=Node.PROCESS_MODE_DISABLED
 for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false):
  audio.stop();audio.stream=null
 await create_timer(.2).timeout
 game.queue_free()
 await process_frame
 if completed: print("LIVE_SERVICE_FLOW_OK: full populated-city pickup, PIN boarding and road journey with NPC service and one completed fare")
 call_deferred("quit",0 if completed else 1)
