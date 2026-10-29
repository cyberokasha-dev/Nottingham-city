extends Node3D
const W=preload("res://town/world_layout.gd")
const G=preload("res://transport/geometry.gd")
var game: Node3D
var lines:Array[Dictionary]=[]
var trains:Array[Node3D]=[]
var stations:Array[Dictionary]=[]
var stream_clock:=.2
func _ready() -> void:
	for definition in W.rail_lines():
		var line:Dictionary=definition.duplicate(true)
		line.stops=[]
		var curve:Curve3D=line.curve
		line.path=curve.get_baked_points(); line.path_lengths=[0.0]
		for i in range(1,line.path.size()):
			line.path_lengths.append(float(line.path_lengths[-1])+line.path[i-1].distance_to(line.path[i]))
		for i in range(0,line.path.size()-1,3):
			game.city.regions.add_rail(line.path[i],line.path[mini(i+3,line.path.size()-1)])
		line.length=float(line.path_lengths[-1]); line.lengths=[]
		for i in range(line.points.size()):
			var p:Vector2=line.points[i]
			var point:=Vector3(p.x,W.LEVEL+float(line.height),p.y)
			var offset:float=curve.get_closest_offset(point)
			if i==0: offset=0
			if not line.get("loop",false) and i==line.points.size()-1: offset=line.length
			line.lengths.append(offset)
			var a:Vector3=curve.sample_baked(maxf(0,offset-1))
			var b:Vector3=curve.sample_baked(minf(line.length,offset+1))
			var tangent:Vector3=(b-a).normalized()
			var station={"name":str(line.stations[i])+" Station","point":Vector3(p.x,W.LEVEL,p.y),"deck":point,"heading":atan2(tangent.x,tangent.z),"distance":offset,"route":line.number}
			station.pavement=station.point+Basis(Vector3.UP,float(station.heading))*Vector3(24,0,0)
			station.ramps={}
			for ramp_side in [1,-1]:
				var plan:=_plan_access(station,ramp_side)
				if not plan.is_empty(): station.ramps[ramp_side]=plan
			# A flat bay inside the ring connects the platform to the nearest distributor.
			if station.ramps.has(1):
				station.bay=station.ramps[1].points[RAMP_BAY]
				station.pavement=station.bay
			line.stops.append(station); stations.append(station)
			game.economy.locations.append({"name":line.number+" • "+station.name,"point":station.pavement})
			station.visual=null
			station.height=line.height
			station.color=line.color
		lines.append(line)
		for service in range(4):
			var direction:=1 if service<2 else -1
			var train:=preload("res://transport/train.gd").new()
			train.manager=self; train.route=line; train.direction=direction; train.lane=-3.5 if direction==1 else 3.5
			train.initial_stop=(service%2)*3
			add_child(train); trains.append(train)
const RAMP_WIDTH:=4.0
const RAMP_BAY:=2
# Compatibility with the cab bay API: these are short flat access paths, never elevated ramps.
func _plan_access(station:Dictionary, side:int) -> Dictionary:
	var normal:=Vector3(station.point.x,0,station.point.z).normalized()
	normal.y=0;normal=normal.normalized()
	var bay:Vector3=station.point-normal*32
	var foot:Vector3=game.cabs.curb(bay)
	# End beside the road rather than on a running traffic lane.
	var toward:Vector3=(bay-foot).normalized()
	foot+=toward*5.5
	var first:Vector3=station.point-normal*8
	var second:Vector3=station.point-normal*24
	if side<0:
		var tangent:=Vector3(-normal.z,0,normal.x)
		first=station.point+normal*8
		second=station.point+normal*24+tangent*55
	return {"points":PackedVector3Array([first,second,bay,foot]),"side":side}
# Resolve a station bay so the Aurora can follow its level access path.
func bay_for(point: Vector3) -> Dictionary:
	for station in stations:
		if station.has("bay") and station.bay.distance_to(point)<1.5: return station
	return {}
# Ground approach from the distributor road to the station bay and back.
func ramp_up(station: Dictionary) -> PackedVector3Array:
	var points:PackedVector3Array=station.ramps[1].points
	var path:=PackedVector3Array()
	for i in range(points.size()-1,RAMP_BAY-1,-1): path.append(points[i])
	return path
func ramp_foot(station: Dictionary) -> Vector3:
	var points:PackedVector3Array=station.ramps[1].points
	return points[points.size()-1]
func at_bay(point: Vector3) -> Dictionary:
	for station in stations:
		if station.has("bay") and station.bay.distance_to(point)<7.0: return station
	return {}
# Road vehicles must remain clear of the ground-level station tracks.
func track_zone(point: Vector3) -> bool:
	for station in stations:
		if point.distance_squared_to(station.point)>100.0*100.0: continue
		var local:Vector3=Basis(Vector3.UP,float(station.heading)).inverse()*(point-station.point)
		if absf(local.x)<5.8 and absf(local.z)<60.0: return true
	return false
func sample(line: Dictionary,distance: float) -> Dictionary:
	var curve:Curve3D=line.curve
	var d:=fposmod(distance,float(line.length)) if line.get("loop",false) else clampf(distance,0,float(line.length))
	var before:=fposmod(d-.5,float(line.length)) if line.get("loop",false) else maxf(0,d-.5)
	var after:=fposmod(d+.5,float(line.length)) if line.get("loop",false) else minf(float(line.length),d+.5)
	return {"point":curve.sample_baked(d,true),"direction":(curve.sample_baked(after,true)-curve.sample_baked(before,true)).normalized()}
func nearest_train(person: Node3D) -> Node3D:
	for train in trains:
		if train.state=="dwell" and not is_instance_valid(train.rider) and train.is_board_near(person): return train
	return null
func stop_hint(person: Node3D) -> String:
	for station in stations:
		if person.global_position.distance_to(station.pavement)<12 or person.global_position.distance_to(station.point-Basis(Vector3.UP,float(station.heading))*Vector3(24,0,0))<12:
			return station.route+" • "+station.name+" • E at the entrance to board an arrived train • £4"
	return ""
func ensure_station(station: Dictionary,line: Dictionary) -> void:
	if is_instance_valid(station.get("visual")): return
	_build_station(station,line)

func _process(delta: float) -> void:
	stream_clock+=delta
	if stream_clock<.15: return
	stream_clock=0
	var point:Vector3=game.player.global_position
	var built:=false
	for station in stations:
		var distance:float=station.point.distance_squared_to(point)
		if distance>290*290 and is_instance_valid(station.get("visual")):
			station.visual.queue_free(); station.visual=null
		elif distance<220*220 and not is_instance_valid(station.get("visual")) and not built:
			ensure_station(station,station); built=true
	for train in trains:
		var distance:float=train.global_position.distance_squared_to(point)
		if distance>330*330: train.release_model()
		elif distance<240*240 and not is_instance_valid(train.model) and not built:
			train.ensure_model(); built=true

func _build_station(station: Dictionary,line: Dictionary) -> void:
	var node:=Node3D.new(); node.position=station.point; node.rotation.y=station.heading
	add_child(node)
	station.visual=node
	var height:float=line.height
	var concrete:=G.material(Color("a9b5b8"))
	var paint:=G.material(line.color,.25)
	var roof:=G.material(Color("344f60"),.4)
	# Ground-level ballast and platforms sit on the existing city ground.
	_solid(node,Vector3(0,height-.3,0),Vector3(13,.6,100))
	for side in [-1,1]:
		G.box(node,Vector3(side*7,height-.2,0),Vector3(3,.4,90),concrete)
		_solid(node,Vector3(side*7,height-.2,0),Vector3(3,.4,90))
		G.box(node,Vector3(side*5.6,height+.015,0),Vector3(.16,.03,90),paint)
		G.box(node,Vector3(side*7,height+4.2,0),Vector3(4,.25,92),roof)
		for z in [-36,-12,12,36]: G.tube(node,Vector3(side*8,height,z),Vector3(side*8,height+4.2,z),.09,roof)
	for side in [-1,1]:
		_build_ramp(station,node,side)
		var exit:=G.label(node,"EXIT • LEVEL ACCESS",Vector3(side*7,height+.05,0),28)
		exit.rotation.x=-PI/2
	for side in [-1,1]:
		var sign:=G.label(node,station.name+" • "+str(station.route)+"\nE: board arrived train • £4",Vector3(side*24,2.5,0),27)
		sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	G.merge(node)
func _build_ramp(station: Dictionary,parent: Node3D,side: int) -> void:
	if not station.ramps.has(side): return
	var points:PackedVector3Array=station.ramps[side].points
	var concrete:=G.material(Color("a9b5b8"))
	var paint:=G.material(station.color,.25)
	var access:=Node3D.new()
	access.top_level=true
	parent.add_child(access)
	for i in range(points.size()-1):
		var a:=points[i]; var b:=points[i+1]
		var length:=a.distance_to(b)
		var basis:=Basis.looking_at((b-a).normalized(),Vector3.UP)
		var segment:=Node3D.new()
		segment.transform=Transform3D(basis,(a+b)/2.0-basis.y*.25)
		access.add_child(segment)
		G.box(segment,Vector3.ZERO,Vector3(RAMP_WIDTH,.5,length+.5),concrete)
		_solid(segment,Vector3.ZERO,Vector3(RAMP_WIDTH,.5,length+.5))
		for edge in [-1,1]:
			G.box(segment,Vector3(edge*(RAMP_WIDTH/2-.1),.7,0),Vector3(.2,1.0,length),paint)
			_solid(segment,Vector3(edge*(RAMP_WIDTH/2-.1),.7,0),Vector3(.2,1.0,length))
	var ramp_mesh:=G.colored_mesh(access)
	for part in access.find_children("*","MeshInstance3D",true,false): part.free()
	var visual:=MeshInstance3D.new(); visual.mesh=ramp_mesh; access.add_child(visual)
	if station.has("bay") and side==1:
		var bay:=G.label(access,"AURORA STATION BAY\nCars stop here • level platform access",station.bay+Vector3(0,2.6,0),24)
		bay.billboard=BaseMaterial3D.BILLBOARD_ENABLED
func _solid(parent:Node3D,point:Vector3,size:Vector3) -> void:
	var body:=StaticBody3D.new(); var shape:=CollisionShape3D.new(); var box:=BoxShape3D.new()
	box.size=size; shape.shape=box; body.position=point; body.add_child(shape); parent.add_child(body)
