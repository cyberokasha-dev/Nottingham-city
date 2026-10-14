extends Node3D
## Sidewalk graph and routines; destination data is reusable by future transport.
var city: Node3D
var player: CharacterBody3D
var residents: Array[CharacterBody3D] = []
var streets := AStar3D.new()
var places := []

func _ready() -> void:
	for xi in range(city.ROAD_X.size()):
		for zi in range(city.ROAD_Z.size()):
			var id := xi*10+zi
			streets.add_point(id,Vector3(city.ROAD_X[xi]+7.7,city.GROUND_Y+0.14,city.ROAD_Z[zi]+7.7))
			if xi > 0:
				streets.connect_points(id,(xi-1)*10+zi)
			if zi > 0:
				streets.connect_points(id,id-1)
	places = [
		{"name":"courtyard", "point":Vector3(23,city.GROUND_Y+0.14,23)},
		{"name":"west park", "point":Vector3(-132.3,city.GROUND_Y+0.14,-52.3)},
		{"name":"east park", "point":Vector3(87.7,city.GROUND_Y+0.14,23.7)},
		{"name":"north shops", "point":Vector3(47.7,city.GROUND_Y+0.14,-112.3)},
		{"name":"south neighbourhood", "point":Vector3(-32.3,city.GROUND_Y+0.14,147.7)}
	]
	var names := ["Safiya","Idris","Sara","Adam","Fatima","Yusuf","Nia","Omar","Lena","Noah","Amina","Luca","Grace","Isaac","Amira","Daniel","Mariam","Theo","Zain","Rose","Bilal","Ruby","Ethan","Hana","Tariq","Eva","Samuel","Layla","Khalid","Freya","Ibrahim","Will"]
	for i in range(names.size()):
		var resident := preload("res://actors/resident.gd").new()
		resident.name = names[i]
		resident.person_name = names[i]
		resident.variant = i+1
		resident.female = i%2==0
		resident.manager = self
		resident.home = city.houses[(i*5)%city.houses.size()]
		resident.position = spawn_point(i)
		add_child(resident)
		residents.append(resident)
	# Two neighbours visibly chatting beside the starting courtyard.
	residents[0].begin_conversation(residents[1])

func spawn_point(index: int) -> Vector3:
	if index < 4:
		return Vector3(21 + (index%2)*1.7,city.GROUND_Y+0.14,35+(index/2)*4)
	return Vector3(city.ROAD_X[(index/2)%city.ROAD_X.size()]+7.7,city.GROUND_Y+0.14,city.ROAD_Z[index%city.ROAD_Z.size()]+7.7)

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
