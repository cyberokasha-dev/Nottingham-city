extends SceneTree
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(910);call_deferred("run")
func check(ok:bool,why:String):
 if not ok:failed=true;push_error(why)
func length_of(path:PackedVector3Array) -> float:
 var distance:=0.0
 for i in range(1,path.size()):distance+=path[i-1].distance_to(path[i])
 return distance
func run():
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
 for node in [game]+game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
 var cab=game.cabs;var air=game.helicopters;var s=game.services;var p=game.player;var rules=game.city.traffic
 for item in rules.cars:item.node.position=Vector3(6000,0,6000)
 for person in game.population.residents+game.party.members:
  if person!=p:person.global_position=Vector3(6000,0,6000)
 for bus in game.city.transport.buses:bus.position=Vector3(6000,0,6000)
 for i in range(1,cab.cars.size()):cab.cars[i].node.position=Vector3(6000,0,6000);cab.cars[i].state="unavailable"
 await physics_frame;await physics_frame
 # Reproduce the actual standing bug: seek() on an inactive AnimationPlayer.
 var car:Dictionary=cab.cars[0];var graphics:Node3D=car.node.get_meta("graphics")
 for actor in game.party.members:
  actor.visual.play("idle");actor.animator.advance(.1);actor.animator.active=false
  actor.visual.mount(graphics,Vector3(-.4,.26,-.35),PI,true)
  var sk:Skeleton3D=actor.visual.skeleton
  var hip:Vector3=sk.get_bone_global_pose(sk.find_bone("thigh_l")).origin
  var knee:Vector3=sk.get_bone_global_pose(sk.find_bone("calf_l")).origin
  check(actor.animator.active and absf(hip.y-knee.y)<.1 and (hip-knee).length()>.35,"Culled "+actor.profile.name+" enters a genuinely seated pose with horizontal thighs")
  var head:Vector3=graphics.to_local(sk.global_transform*sk.get_bone_global_pose(sk.find_bone("Head")).origin)
  check(head.y<1.51,"Seated head fits below the Aurora roof: "+actor.profile.name)
  actor.visual.dismount(actor)
 # Short, unobstructed destinations must not require an unnecessary city loop.
 var start:=Vector3(-22,W.LEVEL,-128);var target:=Vector3(22,W.LEVEL,-128)
 var short:PackedVector3Array=cab.path_between(start,target,Vector3.RIGHT)
 check(not short.is_empty() and length_of(short)<55,"A clear 44 m local destination uses a short approach")
 var back:PackedVector3Array=cab.path_between(Vector3(20,W.LEVEL,-122.8),Vector3(-20,W.LEVEL,-122.8),Vector3.RIGHT)
 check(not back.is_empty() and length_of(back)<150,"Turning round uses a nearby curved U-turn rather than a neighbourhood loop")
 # Only the actual booked journey is shown, even when an old waypoint exists.
 p.global_position=car.node.position+Vector3(3,0,0)
 var trip:Dictionary=cab.walk_up(p,0)
 check(not trip.is_empty() and cab.board_near(p),"Seat and route checks use ordinary paid boarding")
 for i in range(65):cab._physics_process(.05)
 check(cab.choose_destination(p,{"name":"Customer destination","point":Vector3(147.7,W.LEVEL,-90)}),"A real ride accepts a destination")
 game.city_map.walking_route=PackedVector3Array([Vector3(-700,0,-700),Vector3(700,0,700)])
 game.city_map.set_waypoint({"name":"Old walking waypoint","point":Vector3(650,W.LEVEL,0)})
 check(game.city_map.navigation_path()==cab.remaining_route(p),"Map selects the active ride, with no long walking-route overlay")
 var seat_before:Transform3D=p.visual.transform
 check(cab.set_manual(p,true) and p.visual.transform==seat_before,"Taking the wheel keeps the passenger in the same seat")
 car.node.position=Vector3(210,W.LEVEL,-210);car.node.rotation.y=PI/2
 check(W.road_distance(car.node.position)>9 and cab.set_manual(p,false),"Self-drive can resume from clear ground away from a main road")
 cab.skip_journey(p)
 # Three conflicting approaches reserve the junction in arrival order.
 var centre:=Vector3(-80,W.LEVEL,-60)
 var nodes:Array[Node3D]=[]
 for i in range(3):
  var node:=Node3D.new();game.add_child(node);nodes.append(node);rules.autonomous_nodes.append(node)
 nodes[0].position=centre+Vector3(2.8,0,-12.1);nodes[0].rotation.y=0
 nodes[1].position=centre+Vector3(-12.1,0,-2.8);nodes[1].rotation.y=PI/2
 nodes[2].position=centre+Vector3(-2.8,0,12.1);nodes[2].rotation.y=PI
 rules.invalidate_spatial()
 var first:float=rules.allowed_travel(nodes[0].position,Vector3.BACK,.5,2.3,nodes[0])
 var second:float=rules.allowed_travel(nodes[1].position,Vector3.RIGHT,.5,2.3,nodes[1])
 var third:float=rules.allowed_travel(nodes[2].position,Vector3.FORWARD,.5,2.3,nodes[2])
 check(first>.4 and second<.11 and third<.11,"One conflicting vehicle proceeds while the other two yield")
 nodes[0].position=centre+Vector3(2.8,0,35);rules.track_vehicle(nodes[0])
 check(rules.allowed_travel(nodes[1].position,Vector3.RIGHT,.5,2.3,nodes[1])>.4,"Second vehicle is released after the first clears")
 nodes[1].position=centre+Vector3(35,0,-2.8);rules.track_vehicle(nodes[1])
 check(rules.allowed_travel(nodes[2].position,Vector3.FORWARD,.5,2.3,nodes[2])>.4,"Third vehicle is released next, with no mutual waiting")
 # Low frame intervals must move traffic every frame, with no 20 Hz dead ticks.
 var ambient:Dictionary=rules.cars[0]
 for item in rules.cars:
  if item!=ambient:item.taken=true
 ambient.distance=-95;ambient.node.position=rules.lane_position(ambient,ambient.distance);ambient.motion_speed=5
 rules.clock=0;var before:float=ambient.distance
 for i in range(5):
  rules._process(.01)
  check(absf(ambient.distance-before)>0,"Ambient cars move at every rendered frame")
  before=ambient.distance
 # Flight acceleration stays bounded throughout climb, cruise and descent.
 for craft in air.cars:
  if craft!=air.cars[0]:craft.node.position=Vector3(6000,0,6000);craft.landing=craft.node.position
 var helicopter:Dictionary=air.cars[0];helicopter.speed=0
 air._set_flight(helicopter,air.pads[2].point,"returning")
 check(helicopter.path.size()>20,"Helicopter flight rounds its climb and descent corners")
 var previous_speed:=0.0;var moved:=false
 for i in range(5000):
  var previous:Vector3=helicopter.node.position
  air._physics_process(1.0/60)
  if helicopter.state=="idle":break
  check(absf(float(helicopter.speed)-previous_speed)<.13,"Flight speed ramps without sudden vertical/cruise jumps")
  if previous.distance_to(helicopter.node.position)>.001:moved=true
  previous_speed=helicopter.speed
 check(moved and helicopter.state=="idle","Smoothed flight still reaches its actual landing")
 air._set_flight(helicopter,helicopter.node.position,"returning");air._physics_process(.8)
 check(helicopter.state=="idle","A zero-distance flight releases immediately rather than hanging")
 var train=game.rail.trains[0];var last:Vector3=game.rail.sample(train.route,10).direction
 for i in range(1,1000):
  var sample:Dictionary=game.rail.sample(train.route,10+i*.25)
  check(last.dot(sample.direction)>.999,"Fast rail follows a continuous tangent instead of polygon corners")
  last=sample.direction
 check(ProjectSettings.get_setting("physics/common/physics_interpolation",false),"Vehicle display interpolates between physics ticks")
 game.queue_free();await process_frame
 if not failed:print("TRANSPORT_MOTION_OK: culled characters sit, contained heads, short clear routes, curved U-turns, off-road self-drive handover, one active map route, fair junction release, per-frame cars, bounded flight acceleration and smooth rail curves")
 quit(1 if failed else 0)
