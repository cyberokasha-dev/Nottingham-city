extends RefCounted
# Physics owns the vehicle; the cabin and its occupants share its rendered pose.
static func setup(body:Node3D,visual:Node3D) -> void:
 body.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
 visual.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
 visual.set_as_top_level(true)
 visual.global_transform=body.global_transform
 body.get_global_transform_interpolated()
 body.reset_physics_interpolation()
static func render(body:Node3D,visual:Node3D) -> void:
 # Explicit warps (spawn, collection, skip trip) must never streak across town.
 if visual.global_position.distance_to(body.global_position)>12:
  body.reset_physics_interpolation()
 visual.global_transform=body.get_global_transform_interpolated()
static func warp_if_needed(body:Node3D,visual:Node3D) -> void:
 if is_instance_valid(visual) and visual.global_position.distance_to(body.global_position)>12:
  body.reset_physics_interpolation()
  visual.global_transform=body.global_transform
static func speed(current:float,target:float,delta:float,acceleration:float,braking:float) -> float:
 return move_toward(current,target,(acceleration if target>current else braking)*delta)
static func rounded_path(points:PackedVector3Array,radius:float) -> PackedVector3Array:
 var result:=PackedVector3Array([points[0]])
 for i in range(1,points.size()-1):
  var before:Vector3=points[i]-points[i-1];var after:Vector3=points[i+1]-points[i]
  if before.length()<.1 or after.length()<.1:continue
  var reach:=minf(radius,minf(before.length(),after.length())*.35)
  var entry:=points[i]-before.normalized()*reach;var end:=points[i]+after.normalized()*reach
  result.append(entry)
  for step in range(1,13):
   var t:=step/12.0
   result.append((1-t)*(1-t)*entry+2*(1-t)*t*points[i]+t*t*end)
 result.append(points[-1])
 return result
