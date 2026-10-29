extends SceneTree
const C=preload("res://vehicles/coachwork.gd")
const W=preload("res://town/world_layout.gd")
var failed:=false
func _initialize():
 OS.set_environment("NOTTINGHAM_TEST","1");seed(3911);call_deferred("run")
func check(ok:bool,why:String):
 if not ok:failed=true;push_error(why)
func run():
 # Shared mesh data must not share moving doors or seat parents.
 for type in ["aurora","robovan"]:
  var builder=load("res://vehicles/"+type+"_model.gd")
  var a:Node3D=builder.make(1);var b:Node3D=builder.make(2);root.add_child(a);root.add_child(b)
  var meshes:Array=a.get_children().filter(func(n):return n is MeshInstance3D and n!=a.get_meta("marker"))
  var twins:Array=b.get_children().filter(func(n):return n is MeshInstance3D and n!=b.get_meta("marker"))
  check(not meshes.is_empty() and meshes.size()==twins.size(),"Both variants build a complete body")
  for i in range(meshes.size()):check(meshes[i].mesh==twins[i].mesh,"Fleet members share immutable body meshes")
  var triangles:=0;var directions:Dictionary={}
  for mesh in a.find_children("*","MeshInstance3D",true,false):
   if mesh==a.get_meta("marker"):continue
   for surface in range(mesh.mesh.get_surface_count()):
    var arrays:Array=mesh.mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX];var vertices=arrays[Mesh.ARRAY_VERTEX]
    triangles+=int((indices.size() if indices!=null and indices.size()>0 else vertices.size())/3)
    for normal in arrays[Mesh.ARRAY_NORMAL]:directions[Vector3i(roundi(normal.x*12),roundi(normal.y*12),roundi(normal.z*12))]=true
  print("BODYWORK_BUDGET ",type," triangles=",triangles," normals=",directions.size()," nodes=",a.find_children("*","Node",true,false).size())
  check(triangles<16000 and directions.size()>60,"Curved surfaces retain varied normals within the near-vehicle triangle budget")
  check(a.find_children("*","Node",true,false).size()<100,"Merged panels keep each detailed vehicle below 100 scene nodes")
  var door:Node3D=a.get_meta("doors")[0];var other:Node3D=b.get_meta("doors")[0];var pose:Transform3D=other.transform
  door.position.z-=1;check(other.transform==pose and door!=other,"Moving one door does not alter another fleet vehicle")
  a.free();b.free()
 var game=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate();root.add_child(game);game.economy.enabled=false
 for node in [game]+game.find_children("*","Node",true,false):node.set_process(false);node.set_physics_process(false)
 var service=game.cabs;var rules=game.city.traffic
 for item in rules.cars:item.node.position=Vector3(6000,0,6000)
 for bus in game.city.transport.buses:bus.position=Vector3(6000,0,6000)
 for person in game.population.residents+game.party.members:person.global_position=Vector3(6000,0,6000)
 rules.clock=0
 await physics_frame;await physics_frame
 check(service.cars.size()==18 and service.cars.filter(func(car):return car.kind=="Robovan").size()==10,"Six added vans preserve all eight Auroras")
 for car in service.cars:
  var start:Transform3D=car.node.transform
  var path:PackedVector3Array=service._pickup_path(car,car.node.position+car.node.basis.z*50)
  check(not path.is_empty(),"Every rank space has a connected pickup route")
  car.path=path;car.index=0;car.speed=0;car.state="returning"
  for frame in range(150):service._advance_route(car,.05)
  check(car.node.position.distance_to(start.origin)>5,"Every vehicle can leave its rank with the other seventeen parked")
  car.node.transform=start;car.speed=0;car.state="idle";rules.track_vehicle(car.node)
 var rig:Node3D=preload("res://vehicles/vehicle_factory.gd").make("cybercab");game.town.add_child(rig)
 var body:VehicleBody3D=rig.get_node("Body");body.park()
 check(body.get_meta("graphics").get_meta("body_style")=="curved_fastback","Driveable and booked Auroras use the same refined model")
 for wheel in body.get_children():
  if wheel is VehicleWheel3D:check(wheel.get_child_count()>0,"Physical Aurora wheels retain their actual suspension and visible mesh")
 rig.queue_free();game.queue_free();await process_frame
 check(C.parts.is_empty() and C.materials.is_empty(),"Leaving the city releases shared bodywork resources")
 if not failed:print("VEHICLE_BODYWORK_OK: curved shared meshes, triangle/node limits, independent doors, eighteen rank departures, physical Aurora consistency and resource cleanup")
 quit(1 if failed else 0)
