extends RefCounted
# Compact circular city; every transport and map system shares this atlas.
const LIMIT := 740.0
const RAIL_RADIUS := 660.0
const OUTER_ROAD := 440.0
const CORE_X := [-140.0,-80.0,-40.0,40.0,80.0,140.0]
const CORE_Z := [-120.0,-60.0,16.0,80.0,140.0]
const ROAD_X := [-440.0,-320.0,-140.0,-80.0,-40.0,40.0,80.0,140.0,320.0,440.0]
const ROAD_Z := [-440.0,-240.0,-120.0,-60.0,16.0,80.0,140.0,240.0,440.0]
const LEVEL := -5.02
static func contains(point: Vector3) -> bool:
	return is_finite(point.x) and is_finite(point.z) and Vector2(point.x,point.z).length()<=LIMIT
static var rail_definitions:Array[Dictionary]=[]
static func rail_lines() -> Array[Dictionary]:
	if not rail_definitions.is_empty(): return rail_definitions
	var points:Array[Vector2]=[]
	var curve:=Curve3D.new(); curve.bake_interval=5
	# Six tangent-matched arcs close the ring smoothly. Roads stay inside the rail corridor.
	for i in range(7):
		var angle:=PI/2+float(i%6)*TAU/6
		var p:=Vector2(cos(angle),sin(angle))*RAIL_RADIUS
		var handle:=Vector3(-sin(angle),0,cos(angle))*(4.0/3.0*tan(PI/12)*RAIL_RADIUS)
		curve.add_point(Vector3(p.x,LEVEL,p.y),-handle,handle)
		if i<6: points.append(p)
	rail_definitions=[{"number":"R1","name":"City Circle • all neighbourhoods","color":Color("eeb053"),"height":0.0,"loop":true,"stations":["Central","Lenton","Forest Fields","Mapperley","Gedling","Carlton"],"points":points,"chords":points+[points[0]],"curve":curve,"path":curve.get_baked_points()}]
	return rail_definitions

static func stations() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for line in rail_lines():
		for i in range(line.points.size()):
			var p:Vector2=line.points[i]
			result.append({"name":str(line.stations[i])+" Station","point":Vector3(p.x,LEVEL,p.y)})
	return result
static func road_clear(point: Vector3, clearance: float) -> bool:
	return not on_road(point,clearance)

static func rail_clear(point: Vector3, clearance := 32.0) -> bool:
	var p:=Vector2(point.x,point.z)
	for line in rail_lines():
		var near:=false
		for i in range(1,line.chords.size()):
			if Geometry2D.get_closest_point_to_segment(p,line.chords[i-1],line.chords[i]).distance_to(p)<clearance+100: near=true; break
		if not near: continue
		for i in range(1,line.path.size()):
			var a:=Vector2(line.path[i-1].x,line.path[i-1].z); var b:=Vector2(line.path[i].x,line.path[i].z)
			if p.x<minf(a.x,b.x)-clearance or p.x>maxf(a.x,b.x)+clearance or p.y<minf(a.y,b.y)-clearance or p.y>maxf(a.y,b.y)+clearance: continue
			if Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)<clearance: return false
	return true
static var pad_cache:Array[Vector2]=[]
static var station_pad_cache:Array[Vector2]=[]
static func helipads() -> Array[Vector2]:
	if not pad_cache.is_empty(): return pad_cache
	# Core and neighbourhood pads, plus one safe landing pad beside every station entrance.
	var sites:Array[Vector2]=[Vector2(-110,-90),Vector2(110,-90),Vector2(-220,-90),Vector2(220,-90),Vector2(110,-22),Vector2(-110,48),Vector2(-110,110),Vector2(110,110),Vector2(-220,110),Vector2(-380,-350)]
	sites.append_array(station_pads())
	pad_cache=sites
	return pad_cache

# A pad 40 m beside each station entrance, clear of the track, roads and station ramps.
static func station_pads() -> Array[Vector2]:
	if not station_pad_cache.is_empty(): return station_pad_cache
	var result:Array[Vector2]=[]
	var seen:Array[Vector2]=[]
	for line in rail_lines():
		var curve:Curve3D=line.curve
		var length:float=curve.get_baked_length()
		for i in range(line.points.size()):
			var p:Vector2=line.points[i]
			var shared:=false
			for existing in seen: if existing.distance_to(p)<5: shared=true
			if shared: continue
			seen.append(p)
			var offset:float=curve.get_closest_offset(Vector3(p.x,LEVEL+float(line.height),p.y))
			if i==0: offset=0.0
			if not line.get("loop",false) and i==line.points.size()-1: offset=length
			var a:Vector3=curve.sample_baked(maxf(0.0,offset-1.0))
			var b:Vector3=curve.sample_baked(minf(length,offset+1.0))
			var tangent:=Vector2(b.x-a.x,b.z-a.z).normalized()
			var normal:=Vector2(tangent.y,-tangent.x)
			var chosen:=p+normal*40.0
			var found:=false
			for lateral in [40.0,-40.0,52.0,-52.0]:
				for along in [0.0,30.0,-30.0,60.0,-60.0]:
					var candidate:Vector2=p+normal*lateral+tangent*along
					var point:=Vector3(candidate.x,LEVEL,candidate.y)
					if not found and contains(point) and road_clear(point,14) and rail_clear(point,32) and not core_edge(candidate):
						chosen=candidate
						found=true
			result.append(chosen)
	station_pad_cache=result
	return station_pad_cache

static func core_edge(p: Vector2) -> bool:
	if absf(absf(p.x)-160)<14 and p.y>=-158 and p.y<=178: return true
	return (absf(p.y+150)<14 or absf(p.y-170)<14) and absf(p.x)<168
static func road_distance(point: Vector3) -> float:
	var p:=Vector2(point.x,point.z)
	var best:=INF
	for segment in road_segments():
		best=minf(best,Geometry2D.get_closest_point_to_segment(p,segment.a,segment.b).distance_to(p))
	return best

static var roads: Array[Dictionary]=[]
static func road_segments() -> Array[Dictionary]:
	if not roads.is_empty(): return roads
	for x in CORE_X: roads.append({"a":Vector2(x,-150),"b":Vector2(x,170)})
	for z in CORE_Z: roads.append({"a":Vector2(-160,z),"b":Vector2(160,z)})
	for x in [-440.0,-320.0,320.0,440.0]: roads.append({"a":Vector2(x,-440),"b":Vector2(x,440)})
	for z in [-440.0,-240.0,240.0,440.0]: roads.append({"a":Vector2(-440,z),"b":Vector2(440,z)})
	for x in [-140.0,140.0]: roads.append({"a":Vector2(x,-440),"b":Vector2(x,440)})
	for z in [-120.0,140.0]: roads.append({"a":Vector2(-440,z),"b":Vector2(440,z)})
	return roads

static var place_definitions:Array[Dictionary]=[]
static func place_sites() -> Array[Dictionary]:
	if not place_definitions.is_empty(): return place_definitions
	place_definitions = [
		{"id":"sales","name":"Council Vehicle Rentals","point":Vector3(0,LEVEL,47),"radius":30.0,"icon":"V","kind":"sales"},
		{"id":"market","name":"Central Supermarket","point":Vector3(-230,LEVEL,-180),"radius":33.0,"icon":"S","kind":"market"},
		{"id":"market_east","name":"Carlton Supermarket","point":Vector3(235,LEVEL,340),"radius":32.0,"icon":"S","kind":"market"},
		{"id":"gun_east","name":"Gun Shop • reserved plot","point":Vector3(230,LEVEL,-180),"radius":26.0,"icon":"G","kind":"reserved"},
		{"id":"gun_west","name":"Lenton Gun Shop • reserved plot","point":Vector3(-245,LEVEL,190),"radius":25.0,"icon":"G","kind":"reserved"},
		{"id":"race","name":"Council Racing Ground","point":Vector3(-380,LEVEL,340),"radius":86.0,"icon":"R","kind":"race"},
		{"id":"robotics","name":"Robotics Plaza","point":Vector3(-15,LEVEL,-350),"entry":Vector3(-15,LEVEL,-425),"footprint":Vector2(150,110),"radius":94.0,"icon":"F","kind":"robotics","staffed":false}
	]

	return place_definitions

static func place_clear(point: Vector3, margin := 0.0) -> bool:
	for site in place_sites():
		var gap:=Vector2(point.x-site.point.x,point.z-site.point.z)
		if site.has("footprint"):
			var half:Vector2=site.footprint*.5
			if absf(gap.x)<half.x+margin and absf(gap.y)<half.y+margin: return false
			# Keep the two ground-level pedestrian approaches clear as well.
			if site.kind=="robotics" and absf(gap.x)<6+margin and gap.y>-85-margin and gap.y<105+margin: return false
		elif site.kind=="race":
			if absf(gap.x)<54+margin and absf(gap.y)<88+margin: return false
		elif gap.length()<float(site.radius)+margin: return false
	return true
static func on_road(point: Vector3, width := .1) -> bool:
	var p:=Vector2(point.x,point.z)
	for segment in road_segments():
		if Geometry2D.get_closest_point_to_segment(p,segment.a,segment.b).distance_to(p)<width: return true
	return false
static func connected(a: Vector3,b: Vector3) -> bool:
	var first:=Vector2(a.x,a.z); var last:=Vector2(b.x,b.z)
	for segment in road_segments():
		if Geometry2D.get_closest_point_to_segment(first,segment.a,segment.b).distance_to(first)>.1: continue
		if Geometry2D.get_closest_point_to_segment(last,segment.a,segment.b).distance_to(last)<.1: return true
	return false
