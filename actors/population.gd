extends Node3D
## Sidewalk graph and routines; destination data is reusable by future transport.
var city: Node3D
var player: CharacterBody3D
var residents: Array[CharacterBody3D] = []
var streets := AStar3D.new()
var places := []

func _ready() -> void:
	var layout=preload("res://town/world_layout.gd")
	for xi in range(city.ROAD_X.size()):
		for zi in range(city.ROAD_Z.size()):
			var center:=Vector3(city.ROAD_X[xi],city.GROUND_Y,city.ROAD_Z[zi])
			if not layout.on_road(center): continue
			var id:int=xi*city.ROAD_Z.size()+zi
			streets.add_point(id,center+Vector3(7.7,.14,7.7))
			if xi>0:
				var previous:int=(xi-1)*city.ROAD_Z.size()+zi
				if streets.has_point(previous) and layout.connected(center,Vector3(city.ROAD_X[xi-1],center.y,center.z)): streets.connect_points(id,previous)
			if zi>0:
				var previous:int=id-1
				if streets.has_point(previous) and layout.connected(center,Vector3(center.x,center.y,city.ROAD_Z[zi-1])): streets.connect_points(id,previous)
	var road_ids:=streets.get_point_ids()
	var anchors:Dictionary={}
	for house in city.houses:
		if not house.get_meta("outer_home",false):continue
		var entrance:Vector3=house.entrance()
		var forward:=1.0 if absf(house.rotation.y)<.1 else -1.0
		var access:=Vector3(entrance.x,city.GROUND_Y+.14,house.position.z+forward*8.7)
		var best:=INF; var road_x:=0.0
		for segment in layout.road_segments():
			if segment.a.x!=segment.b.x or access.z<minf(segment.a.y,segment.b.y) or access.z>maxf(segment.a.y,segment.b.y): continue
			if absf(segment.a.x-access.x)<best: best=absf(segment.a.x-access.x); road_x=segment.a.x
		var key:=Vector2(road_x,access.z)
		if not anchors.has(key):
			var anchor_id:int=100000+anchors.size()
			var anchor:=Vector3(road_x+7.7,access.y,access.z)
			streets.add_point(anchor_id,anchor); anchors[key]=anchor_id
			var closest:=-1; best=INF
			for id in road_ids:
				var point:=streets.get_point_position(id)
				if absf(point.x-anchor.x)>.1: continue
				var distance:=point.distance_squared_to(anchor)
				if distance<best: best=distance; closest=id
			if closest>=0: streets.connect_points(anchor_id,closest)
		var access_id:int=200000+int(house.house_number)*2
		streets.add_point(access_id,access); streets.add_point(access_id+1,entrance)
		streets.connect_points(access_id,int(anchors[key])); streets.connect_points(access_id,access_id+1)
	places = [
		{"name":"courtyard", "point":Vector3(23,city.GROUND_Y+0.14,23)},
		{"name":"west park", "point":Vector3(-132.3,city.GROUND_Y+0.14,-52.3)},
		{"name":"east park", "point":Vector3(87.7,city.GROUND_Y+0.14,23.7)},
		{"name":"north shops", "point":Vector3(47.7,city.GROUND_Y+0.14,-112.3)},
		{"name":"south neighbourhood", "point":Vector3(-32.3,city.GROUND_Y+0.14,147.7)}
	]
	var names := ["Safiya","Idris","Sara","Adam","Fatima","Yusuf","Nia","Omar","Lena","Noah","Amina","Luca","Grace","Isaac","Amira","Daniel","Mariam","Theo","Zain","Rose","Bilal","Ruby","Ethan","Hana","Tariq","Eva","Samuel","Layla","Khalid","Freya","Ibrahim","Will"]
	names=names.slice(0,8)+names.slice(16,24)
	for i in range(names.size()):
		var resident := preload("res://actors/resident.gd").new()
		resident.name = names[i]
		resident.person_name = names[i]
		resident.variant = i+1
		resident.female = names[i] in ["Safiya","Sara","Fatima","Nia","Lena","Amina","Grace","Amira","Mariam","Rose","Ruby","Hana","Eva","Layla","Freya"]
		resident.manager = self
		resident.home = city.houses[(i*5)%city.houses.size()]
		resident.position = spawn_point(i)
		add_child(resident)
		residents.append(resident)
	# Staggered daily activities keep some residents occupied instead of all walking.
	for i in range(2,14): residents[i].start_activity(["phone","stretch","look","work","rest"][i%5])
	# Two neighbours visibly chatting beside the starting courtyard.
	residents[0].begin_conversation(residents[1])

func spawn_point(index: int) -> Vector3:
	if index>=8:
		var home:Node3D=city.houses[(index*5)%city.houses.size()]
		return home.entrance()
	if index < 4:
		return Vector3(21 + (index%2)*1.7,city.GROUND_Y+0.14,35+(index/2)*4)
	return Vector3(city.CORE_X[(index/2)%city.CORE_X.size()]+7.7,city.GROUND_Y+0.14,city.CORE_Z[index%city.CORE_Z.size()]+7.7)

func next_destination(resident: CharacterBody3D) -> void:
	var game: Node3D = get_parent().get_parent()
	if is_instance_valid(game.economy):
		var account: Dictionary = game.economy.account_for(resident)
		if game.economy.hour()>=8 and game.economy.hour()<18 and int(account.last_wage)<game.economy.day():
			var task: Dictionary = game.economy.assignment(resident)
			if not task.is_empty():
				resident.wants_home = false
				var path := streets.get_point_path(streets.get_closest_point(resident.global_position),streets.get_closest_point(task.point))
				path.append(task.point)
				resident.go_to(path,task.name)
				return
	resident.wants_home = resident.travel_count > 0 and resident.travel_count % 3 == 0
	if is_instance_valid(game.economy) and int(game.economy.account_for(resident).house)==0:
		resident.wants_home = false
	var place: Dictionary = places[(resident.variant+resident.travel_count)%places.size()]
	var target: Vector3 = resident.home.entrance() if resident.wants_home else place.point
	var route := streets.get_point_path(streets.get_closest_point(resident.global_position),streets.get_closest_point(target))
	route.append(target)
	resident.go_to(route,resident.home.address if resident.wants_home else place.name)
