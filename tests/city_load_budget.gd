extends SceneTree
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1"); seed(12345); call_deferred("run")
func check(value:bool,message:String):
 if not value: failed=true; push_error(message)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 root.add_child(game);game.economy.enabled=false
 for i in range(240):await process_frame
 check(get_node_count()<7200,"The loaded starting neighbourhood, not just empty startup, stays within its scene budget")
 check(game.population.residents.size()==16 and game.city.traffic.cars.size()==24,"The reduced population and traffic budgets are enforced")
 check(game.city.transport.buses.size()==8 and game.helicopters.cars.size()==8 and game.cabs.cars.size()==18,"All districts retain two road vehicles, with ten six-seat Robovans")
 check(game.cabs.cars.filter(func(car):return car.kind=="Robovan").size()==10,"Ten Robovans are available after adding six more")
 for car in game.city.traffic.cars:
  check(car.node.position.distance_to(game.city.traffic.lane_position(car,car.distance))<.01,"Every actual car position agrees with its routed lane after repeated simulation updates")
 var p=game.player
 var saved:Vector3=p.global_position
 for house in game.city.houses:
  p.global_position=house.entrance()
  check(p.nearest_house()==house,"Local address lookup can find every door, including unloaded districts")
 p.global_position=saved
 var resident=game.population.residents[8]
 resident.set_physics_process(false);resident.stop_activity();resident.state="walk";resident.wait_time=0;resident.combat_time=0
 resident.global_position=Vector3(1000,-4.98,1000);resident.route=PackedVector3Array([Vector3(1010,-4.98,1000)])
 var before:=int(resident.virtual_updates)
 var start:Vector3=resident.global_position
 for i in range(60):resident._physics_process(1.0/60)
 check(resident.virtual_updates-before>=3 and resident.virtual_updates-before<=4,"Distant residents use four coarse steps rather than sixty full physics updates")
 check(resident.global_position.distance_to(start)>1,"Coarse simulation still advances a real walking journey")
 p.global_position=resident.global_position+Vector3(0,0,10)
 resident._physics_process(1.0/60)
 await process_frame
 check(not resident.far_simulated and not resident.collider.disabled,"Approaching restores normal interactive collision and movement")
 p.global_position=saved
 check(game.player.controls.help_widgets.all(func(widget):return not widget.visible),"Long touch/keyboard help starts collapsed while status remains visible")
 game.queue_free();await process_frame
 if not failed:print("CITY_LOAD_BUDGET_OK: loaded scene budget, reduced fleets, actual lane positions, all address lookups and distant-to-near resident simulation")
 quit(1 if failed else 0)
