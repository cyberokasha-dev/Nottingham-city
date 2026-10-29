extends SceneTree
var failed := false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1")
 seed(123)
 call_deferred("run")
func check(value: bool, message: String):
 if not value: failed=true; push_error(message)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
 root.add_child(game)
 game.economy.enabled=false
 game.cabs.set_physics_process(false)
 game.cabs.set_process(false)
 game.city.traffic.set_process(false)
 game.get_node("StreetEvents").set_physics_process(false)
 for person in game.population.residents+game.party.members: person.set_physics_process(false)
 for bus in game.city.transport.buses: bus.set_physics_process(false)
 var looks={}
 for actor in game.party.members:
  check(actor.dialogue.voice_set==("cori" if actor.profile.female else "northern_english_male"),"Playable voices must match their character, with British banks")
  looks[str(actor.visual.base_scale)+str(actor.visual.wardrobe.get_shader_parameter("shirt_tone"))]=true
 check(looks.size()==4,"All four protagonists have different clothes and proportions")
 var quiet:=0
 var busy:=0
 for person in game.population.residents:
  if not person.dialogue.ambient_enabled: quiet+=1
  if person.activity_remaining>0 or person.has_meta("service_counter"): busy+=1
  check(person.dialogue.voice_set==("cori" if person.female else "northern_english_male"),"Residents use their assigned male/female British voice")
 check(quiet>=game.population.residents.size()*3/4 and busy>=8,"Most residents stay quiet and residents have activities or staffed counter jobs at startup")
 var player=game.player
 check(not player.dialogue.speak("blocked",true),"Blocking is an impact sound, never the spoken word blocked")
 var resident=game.population.residents[3]
 resident.stop_activity()
 check(resident.start_activity("phone") and resident.visual.activity=="phone" and resident.visual.held_prop.visible,"Phone routine has an actual held phone")
 resident.talk_to(player)
 check(resident.activity_remaining==0,"Interaction interrupts a daily activity")
 var car=game.cabs.cars[0]
 player.global_position=car.node.to_global(Vector3(2.05,.05,0))
 var trip=game.cabs.walk_up(player,0)
 check(not trip.is_empty(),"Test can reserve a parked Aurora")
 player.global_position=game.cabs.boarding_point(player)
 check(game.cabs.unlock(player,trip.pin),"Correct code starts paid boarding")
 game.cabs._physics_process(3.1)
 var graphics=car.node.get_meta("graphics")
 check(player.visual.mounted and player.visual.get_parent()==graphics,"Visible passenger belongs to the rendered cabin")
 check(not player.animator.is_playing(),"A settled seated pose cannot loop legs through the floor")
 var local_pose: Transform3D=player.visual.transform
 graphics.position+=Vector3(2,0,3)
 graphics.rotation.y+=0.7
 check(player.visual.transform==local_pose,"Movement and turning preserve the passenger's exact seat transform")
 for bone in ["foot_l","foot_r"]:
  var skeleton=player.visual.skeleton
  var foot: Vector3=graphics.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
  check(foot.y>0.28 and absf(foot.x)<0.83 and absf(foot.z)<1.4,"Aurora feet stay above the floor and inside the cabin")
 check(game.cabs.leave_waiting(player) and player.visual.get_parent()==player and not player.visual.mounted,"Getting out restores the walking body and proportions")
 var bus=game.city.transport.buses[0]
 bus.distance=bus.route.stops[1].distance
 bus._update_position()
 bus.arrive(1)
 bus.model.animate_doors(1)
 player.global_position=bus.entrance()
 check(bus.board(player),"Player boards through the open door")
 bus.advance(3.1)
 check(player.visual.get_parent()==bus.model and player.visual.mounted,"Seated bus player remains attached to the cabin")
 for bone in ["foot_l","foot_r"]:
  var skeleton=player.visual.skeleton
  var foot: Vector3=bus.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
  check(foot.y>0.60 and absf(foot.x)<1.2 and absf(foot.z)<4.7,"Player feet stay above the bus floor and inside the body")
 check(bus.leave(player) and player.visual.get_parent()==player,"Leaving a bus restores the walking body")
 var stop: Dictionary=bus.route.stops[bus.stop_index]
 var before: int=bus.manifest.size()
 check(game.city.transport.board_next(bus),"A queued fare-paying commuter starts boarding")
 check(bus.manifest.size()==before+1 and bus.passenger_transfers>0,"A boarding seat is reserved while the person walks")
 var commuter=bus.manifest[-1].person
 check(commuter.visible and commuter.walking and commuter.get_parent()!=bus,"Boarding stays visible rather than teleporting into a seat")
 var path: Array[Vector3]=bus.boarding_path(0)
 check(path.size()>12,"Upper-deck route includes the rear staircase")
 bus.dwell=0
 bus.advance(.1)
 check(bus.state=="dwell" and bus.speed==0,"Departure waits for every passenger transfer")
 for i in range(18*Engine.physics_ticks_per_second):
  if bus.passenger_transfers==0: break
  await physics_frame
 check(bus.passenger_transfers==0 and commuter.get_parent()==bus and commuter.seated,"Passenger reaches a reserved seat through the aisle")
 for audio in game.find_children("*","AudioStreamPlayer3D",true,false)+game.find_children("*","AudioStreamPlayer",true,false): audio.stop(); audio.stream=null
 game.queue_free()
 await process_frame
 if not failed: print("CHARACTER_QUALITY_OK: distinct British voices, quiet residents, routines, attached occupants, contained feet and visible boarding")
 quit(1 if failed else 0)
