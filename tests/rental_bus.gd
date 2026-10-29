extends SceneTree
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");call_deferred("run")
func check(ok:bool,message:String):
 if not ok:failed=true;push_error(message)
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
 game.cabs.npc_clock=-100000;game.city.traffic.set_process(false)
 var p=game.player;var s=game.services
 check(s.rent_vehicle(p,"bus_private","hour"),"A funded character can collect a private bus")
 check(p.camera.current,"Renting never changes the player's camera")
 var body:VehicleBody3D=game.fleet[0]
 for i in range(140):await physics_frame
 p.global_position=body.global_position+Vector3(2.6,0,0);p.velocity=Vector3.ZERO
 check(p.try_enter(),"The rented bus can be entered at its door")
 for i in range(200):
  await physics_frame
  if p.driving and not p.transitioning:break
 check(p.driving and p.visual.mounted,"The bus driver sits in the actual cabin")
 var pose:Transform3D=p.visual.transform
 Input.action_press("accelerate")
 for i in range(90):await physics_frame
 Input.action_release("accelerate")
 check(body.linear_velocity.length()>1 and p.visual.transform==pose,"The rented bus drives with its rider attached")
 for bone in ["foot_l","foot_r"]:
  var skeleton=p.visual.skeleton
  var foot:Vector3=body.to_local(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
  check(foot.y>-.1 and absf(foot.x)<1.25 and absf(foot.z)<4.9,"The seated driver's feet stay inside the bus")
 check(not s.return_rental(p,"bus_private"),"A moving occupied bus cannot be returned")
 body.linear_velocity=Vector3.ZERO;body.angular_velocity=Vector3.ZERO
 check(p.try_exit(),"A stopped bus has a safe exit")
 for i in range(200):
  await physics_frame
  if not p.transitioning:break
 check(not p.driving and p.camera.current,"Leaving the bus restores walking and camera")
 game.queue_free();await process_frame
 if not failed:print("RENTAL_BUS_OK: paid bus, stable player camera, visible driver, contained feet, physical driving and safe exit")
 quit(1 if failed else 0)
