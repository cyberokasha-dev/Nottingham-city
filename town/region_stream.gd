extends Node3D
# Only metadata exists for distant tiles. Visual batches are created under a frame budget.
const W=preload("res://town/world_layout.gd")
const TILE:=128.0
var city: Node3D
var records: Dictionary={}
var decorations: Dictionary={}
var active: Dictionary={}
var wanted: Dictionary={}
var queue: Array[Vector2i]=[]
var clock:=.5
var built_this_frame:=0
var last_point:=Vector3.ZERO
var ahead_point:=Vector3.ZERO
const RADIUS:=1
var materials: Array[Material]=[]
func _ready() -> void:
	materials=[preload("res://transport/geometry.gd").material(Color("35414b")),preload("res://transport/geometry.gd").material(Color("aeb7b5")),preload("res://transport/geometry.gd").material(Color("eee9d5")),preload("res://transport/geometry.gd").material(Color("8a9497")),preload("res://transport/geometry.gd").material(Color("424950"))]
	# A single coarse draw keeps long roads continuous on the horizon.
	# Pavements, paint and rail structures remain streamed region detail.
	var coarse:=MultiMesh.new(); coarse.transform_format=MultiMesh.TRANSFORM_3D
	var box:=BoxMesh.new(); box.size=Vector3.ONE; coarse.mesh=box
	coarse.instance_count=W.road_segments().size()
	for i in range(W.road_segments().size()):
		var segment:Dictionary=W.road_segments()[i]
		var a:Vector2=segment.a; var b:Vector2=segment.b
		var tangent:Vector2=(b-a).normalized(); var center:Vector2=(a+b)*.5
		var basis:=Basis(Vector3.UP,atan2(tangent.x,tangent.y))*Basis.from_scale(Vector3(12,.02,a.distance_to(b)))
		coarse.set_instance_transform(i,Transform3D(basis,Vector3(center.x,W.LEVEL-.13,center.y)))
	var horizon:=MultiMeshInstance3D.new(); horizon.multimesh=coarse; horizon.material_override=materials[0]; add_child(horizon)
	for segment in W.road_segments():
		var a:Vector2=segment.a; var b:Vector2=segment.b
		if maxf(absf(a.x),absf(b.x))<=160 and minf(a.y,b.y)>=-150 and maxf(a.y,b.y)<=170: continue
		var length:=a.distance_to(b); var count:=ceili(length/64)
		var tangent:Vector2=(b-a).normalized()
		var right:=Vector2(tangent.y,-tangent.x)
		var basis:=Basis(Vector3.UP,atan2(tangent.x,tangent.y))
		for i in range(count):
			var middle:Vector2=a.lerp(b,(float(i)+.5)/count)
			var point:=Vector3(middle.x,W.LEVEL-.09,middle.y)
			stamp(point,Vector3(12,.04,length/count+.1),0,basis)
			for side in [-1,1]: stamp(point+Vector3(right.x*side*7.5,.02,right.y*side*7.5),Vector3(3,.06,length/count+.1),1,basis)
			for offset in [-24.0,-8.0,8.0,24.0]:
				stamp(point+Vector3(tangent.x*offset,.035,tangent.y*offset),Vector3(.12,.012,4),2,basis)
func stamp(pos: Vector3, size: Vector3, material_index: int, basis := Basis.IDENTITY) -> void:
	var key:=Vector2i(floori(pos.x/TILE),floori(pos.z/TILE))
	if not records.has(key): records[key]=[]
	records[key].append({"transform":Transform3D(basis*Basis.from_scale(size),pos),"material":material_index})
func add_decoration(point: Vector3, kind: int, heading: float, solid := Vector3.ZERO) -> void:
	var key:=Vector2i(floori(point.x/TILE),floori(point.z/TILE))
	if not records.has(key): records[key]=[]
	if not decorations.has(key): decorations[key]=[]
	decorations[key].append({"transform":Transform3D(Basis(Vector3.UP,heading),point),"kind":kind,"solid":solid})

func add_rail(a: Vector3,b: Vector3) -> void:
	var length:=a.distance_to(b)
	var heading:=atan2((b-a).x,(b-a).z)
	var basis:=Basis(Vector3.UP,heading)
	var pieces:=ceili(length/50)
	for i in range(pieces):
		var middle:=a.lerp(b,(float(i)+.5)/pieces)
		stamp(middle-Vector3(0,.3,0),Vector3(13,.6,length/pieces+.2),3,basis)
		for side in [-4.2,-2.8,2.8,4.2]: stamp(middle+basis*Vector3(side,.05,0),Vector3(.12,.16,length/pieces+.2),4,basis)

func refresh_at(point: Vector3) -> void:
	wanted.clear(); queue.clear()
	# Look ahead along the direction of travel so roads, pavements and rail supports are ready before they are seen.
	var motion:=Vector3(point.x-last_point.x,0,point.z-last_point.z)
	last_point=point
	ahead_point=point+(motion/.15*3.0).limit_length(360.0) if motion.length()<80.0 else point
	for centre in [point,ahead_point]:
		var cell:=Vector2i(floori(centre.x/TILE),floori(centre.z/TILE))
		for x in range(cell.x-RADIUS,cell.x+RADIUS+1):
			for z in range(cell.y-RADIUS,cell.y+RADIUS+1):
				var key:=Vector2i(x,z)
				if not records.has(key) or wanted.has(key): continue
				wanted[key]=true
				if not active.has(key): queue.append(key)
	queue.sort_custom(func(a,b):return (Vector2(a)+Vector2(.5,.5)).distance_squared_to(Vector2(point.x,point.z)/TILE)<(Vector2(b)+Vector2(.5,.5)).distance_squared_to(Vector2(point.x,point.z)/TILE))
	for key in active.keys():
		if not wanted.has(key): active[key].queue_free(); active.erase(key)
func _process(delta: float) -> void:
	clock+=delta; built_this_frame=0
	if clock>.15:
		clock=0
		var game:=city.get_parent().get_parent()
		if is_instance_valid(game.player): refresh_at(game.player.global_position)
	var start:=Time.get_ticks_usec()
	while not queue.is_empty() and built_this_frame<2 and Time.get_ticks_usec()-start<2000:
		build(queue.pop_front()); built_this_frame+=1
func build(key: Vector2i) -> void:
	if active.has(key): return
	var tile:=Node3D.new(); add_child(tile); active[key]=tile
	for mat_index in range(materials.size()):
		var transforms: Array=[]
		for record in records[key]:
			if record.material==mat_index: transforms.append(record.transform)
		if transforms.is_empty(): continue
		var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
		var box:=BoxMesh.new(); box.size=Vector3.ONE; multi.mesh=box
		multi.instance_count=transforms.size()
		for i in range(transforms.size()): multi.set_instance_transform(i,transforms[i])
		var visual:=MultiMeshInstance3D.new(); visual.multimesh=multi; visual.material_override=materials[mat_index]
		tile.add_child(visual)

	# Each repeated landscape or frontage is one shared mesh, batched within the nearby tile.
	for kind in range(4):
		var props:Array=decorations.get(key,[]).filter(func(prop):return prop.kind==kind)
		if props.is_empty(): continue
		var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
		multi.mesh=city.infill.meshes[kind]; multi.instance_count=props.size()
		for i in range(props.size()): multi.set_instance_transform(i,props[i].transform)
		var instance:=MultiMeshInstance3D.new(); instance.multimesh=multi; instance.material_override=city.infill.material
		tile.add_child(instance)
		if kind==0:
			var body:=StaticBody3D.new(); tile.add_child(body)
			for prop in props:
				var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new(); box.size=prop.solid; shape.shape=box
				shape.transform=prop.transform; shape.position.y+=prop.solid.y*.5; body.add_child(shape)
