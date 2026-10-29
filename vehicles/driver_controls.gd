extends RefCounted
# The rim and spokes share a rotating shaft; the dashboard stays still.
const G=preload("res://transport/geometry.gd")
static func make(model:Node3D,position:Vector3) -> Node3D:
 var controls:=Node3D.new();controls.position=position;model.add_child(controls)
 var shaft:=Node3D.new();shaft.rotation.x=1.0;controls.add_child(shaft)
 var wheel:=Node3D.new();shaft.add_child(wheel)
 var dark:=G.material(Color("17232c"),.3)
 var mesh:=MeshInstance3D.new();var ring:=TorusMesh.new()
 ring.inner_radius=.14;ring.outer_radius=.18;ring.rings=16;ring.ring_segments=8
 mesh.mesh=ring;mesh.material_override=dark;wheel.add_child(mesh)
 for angle in [0.0,TAU/3,TAU*2/3]:G.tube(wheel,Vector3.ZERO,Vector3(sin(angle)*.15,0,cos(angle)*.15),.018,dark)
 G.sphere(wheel,Vector3.ZERO,Vector3(.09,.04,.09),dark);G.merge(wheel)
 model.set_meta("steering_wheel",wheel);model.set_meta("manual_controls",controls)
 controls.hide();return controls
static func update(model:Node3D,steer:float,delta:float) -> void:
 var wheel:Node3D=model.get_meta("steering_wheel",null)
 if not is_instance_valid(wheel):return
 wheel.rotation.y=move_toward(wheel.rotation.y,-steer*2.35,delta*9)
