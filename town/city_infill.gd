extends RefCounted
# Only an atlas of sites is kept here. Nearby geometry is instanced by RegionStream.
const G=preload("res://transport/geometry.gd")
const W=preload("res://town/world_layout.gd")
var city: Node3D
var sites:Array[Dictionary]=[]
var site_cells:Dictionary={}
var meshes:Array[Mesh]=[]
var material:Material

func populate(owner_city: Node3D) -> void:
	city=owner_city
	# Four reusable vertex-coloured meshes, rather than hundreds of individual objects.
	for kind in range(4): meshes.append(_prototype(kind))
	material=G.vertex_material
	for proposal in [Vector3(-220,0,-380),Vector3(230,0,-380),Vector3(-240,0,40),Vector3(230,0,40),Vector3(0,0,350),Vector3(0,0,530),Vector3(-530,0,0),Vector3(530,0,0),Vector3(0,0,-530)]:
		proposal.y=-5.12
		if not _clear(proposal,27): continue
		var district:Dictionary=city.ATLAS.at(proposal)
		var name: String=str(district.name)+" "+["Community Park","Play Gardens","Recreation Ground"][city.outer_parks.size()%3]
		city.outer_parks.append({"name":name,"point":proposal,"node":null})
		_add(proposal,2,0,27,"park")
	# Mixed-use frontages break up the empty distributor roads; no new junctions or bus stops.
	var serial:=0
	for segment in W.road_segments():
		var a:Vector2=segment.a; var b:Vector2=segment.b
		if a.distance_to(b)<250: continue
		var tangent:Vector2=(b-a).normalized(); var normal:=Vector2(tangent.y,-tangent.x)
		var count:=floori(a.distance_to(b)/100)
		for i in range(1,count):
			var middle:Vector2=a.lerp(b,float(i)/count)
			for side in [-1,1]:
				var p:=Vector3(middle.x+normal.x*side*39,-5.12,middle.y+normal.y*side*39)
				if absf(p.x)<190 and absf(p.z)<190: continue
				if not _clear(p,23): continue
				var kind:=serial%3
				_add(p,kind,atan2(-normal.x*side,-normal.y*side),23,["shops","courtyard","garden"][kind])
				serial+=1
	# Interior fields become groves and walking gardens without extending the housing simulation.
	for x in range(-590,620,90):
		for z in range(-590,620,90):
			var p:=Vector3(x,-5.12,z)
			if abs(x)<200 and abs(z)<200: continue
			if not _clear(p,24): continue
			_add(p,3,float((x+z)%7),24,"woodland")

func _clear(point: Vector3, radius: float) -> bool:
	if not W.contains(point) or not W.place_clear(point,radius) or not W.road_clear(point,radius+10) or not W.rail_clear(point,radius+32): return false
	if absf(point.x)<190 and absf(point.z)<190: return false
	for house in city.houses:
		if Vector2(point.x-house.position.x,point.z-house.position.z).length()<radius+15: return false
	for pad in W.helipads():
		if Vector2(point.x,point.z).distance_to(pad)<radius+22: return false
	for park in city.outer_parks:
		if point.distance_to(park.point)<radius+32: return false
	for site in sites:
		if point.distance_to(site.point)<radius+float(site.radius)+6: return false
	# Reserve the complete station access/ramp area, including unloaded stations.
	for station in W.stations():
		if point.distance_to(station.point)<radius+60: return false
	return true

func _add(point: Vector3, kind: int, heading: float, radius: float, use: String) -> void:
	var site:Dictionary={"point":point,"kind":kind,"heading":heading,"radius":radius,"use":use}
	sites.append(site)
	var cell:=Vector2i(floori(point.x/64),floori(point.z/64))
	if not site_cells.has(cell): site_cells[cell]=[]
	site_cells[cell].append(site)
	var solid:=Vector3(18,5.5,10) if kind==0 else Vector3.ZERO
	city.regions.add_decoration(point,kind,heading,solid)

func landing_clear(point: Vector3) -> bool:
	if not W.place_clear(point,9): return false
	# The largest site exclusion is 36 metres. Query its local cells, even when
	# those tiles are unloaded, rather than scanning the whole city per candidate.
	for x in range(floori((point.x-36)/64),floori((point.x+36)/64)+1):
		for z in range(floori((point.z-36)/64),floori((point.z+36)/64)+1):
			for site in site_cells.get(Vector2i(x,z),[]):
				if Vector2(point.x-site.point.x,point.z-site.point.z).length()<float(site.radius)+9: return false
	return true

func _tree(root: Node3D, p: Vector3, size:=1.0) -> void:
	G.tube(root,p,p+Vector3(0,3.5*size,0),.28*size,G.material(Color("735840")))
	G.sphere(root,p+Vector3(0,4.4*size,0),Vector3(4.7,5.4,4.4)*size,G.material(Color("3d7450")))
	G.sphere(root,p+Vector3(1,5*size,0),Vector3(3.4,4.1,3.6)*size,G.material(Color("639455")))

func _bench(root: Node3D, point: Vector3) -> void:
	var wood:=G.material(Color("9f7652")); var steel:=G.material(Color("3b5257"))
	G.box(root,point+Vector3(0,.58,0),Vector3(2.4,.14,.65),wood)
	G.box(root,point+Vector3(0,1,.29),Vector3(2.4,.8,.12),wood)
	for x in [-.85,.85]: G.tube(root,point+Vector3(x,0,0),point+Vector3(x,.6,0),.06,steel)

func _prototype(kind: int) -> Mesh:
	var root:=Node3D.new()
	var paving:=G.material(Color("c0b79e")); var chalk:=G.material(Color("eee8cf"))
	var green:=G.material(Color("568353")); var brick:=G.material(Color("bb8a69"))
	if kind==0:
		G.box(root,Vector3(0,.02,0),Vector3(38,.05,32),paving)
		# Brick shopfront, sloping roof, glazed display bays and striped awning.
		G.box(root,Vector3(0,2.75,0),Vector3(18,5.5,10),brick)
		for side in [-1,1]:
			var roof:=G.box(root,Vector3(0,6,side*2.7),Vector3(19,.3,5.8),G.material(Color("465560")))
			roof.rotation.x=side*.32
		for x in [-6.0,0.0,6.0]:
			G.box(root,Vector3(x,1.75,5.05),Vector3(4.7,2.6,.12),G.material(Color("3c6675")))
			G.box(root,Vector3(x,3.4,5.4),Vector3(5.2,.22,2),G.material(Color("506e59")))
			G.box(root,Vector3(x,4.3,5.08),Vector3(3,.8,.12),chalk)
			for stripe in range(7): G.box(root,Vector3(x-2.1+stripe*.7,3.55,5.5),Vector3(.3,.07,1.9),chalk)
		for x in [-14.0,14.0]: _tree(root,Vector3(x,0,-8),.8); _bench(root,Vector3(x,0,6))
	elif kind==1:
		G.box(root,Vector3(0,.02,0),Vector3(38,.05,32),paving)
		# Open-sided market pavilion, planting beds and usable pedestrian space.
		var roof:=G.material(Color("408d93"))
		G.sphere(root,Vector3(0,3.5,0),Vector3(11,1.4,11),roof)
		for x in [-4.0,4.0]:
			for z in [-4.0,4.0]: G.tube(root,Vector3(x,0,z),Vector3(x,3.4,z),.13,brick)
		for x in [-13.0,13.0]:
			_tree(root,Vector3(x,0,-8)); _bench(root,Vector3(x,0,8))
			G.box(root,Vector3(x,.3,0),Vector3(3,.6,4),brick)
			G.sphere(root,Vector3(x,.9,0),Vector3(3,1.2,4),green)
	else:
		G.box(root,Vector3(0,.015,0),Vector3(45,.03,45),green)
		for z in [-19.0,19.0]:
			for x in [-19.0,0.0,19.0]: _tree(root,Vector3(x,0,z),1.0+float(int(x+z)%3)*.08)
		for x in [-19.0,19.0]: _tree(root,Vector3(x,0,0),1.15)
		if kind==2:
			# Park perimeter and access paths leave the centre for streamed playable equipment.
			for x in [-17.0,17.0]: G.box(root,Vector3(x,.05,0),Vector3(2,.06,36),paving)
			for z in [-17.0,17.0]: G.box(root,Vector3(0,.05,z),Vector3(36,.06,2),paving)
		else:
			for x in [-7.0,7.0]:
				var walk:=G.box(root,Vector3(x,.05,0),Vector3(2,.06,42),paving); walk.rotation.y=.32
			_bench(root,Vector3(0,0,3)); _bench(root,Vector3(0,0,-8))
	var mesh:=G.colored_mesh(root); root.free(); return mesh
