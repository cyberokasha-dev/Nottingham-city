extends Node3D
# Swept contacts also detect fast kinematic cars between simulation updates.
var game: Node3D
var previous := {}
var clock := 0.0
var social_clock := 0.0
var foot_clock := 0.0
var sound: Node3D

func _ready() -> void:
	name = "StreetEvents"
	sound = preload("res://simulation/service_audio.gd").new()
	add_child(sound)

func _physics_process(delta: float) -> void:
	clock+=delta
	foot_clock+=delta
	var player: CharacterBody3D = game.player
	if foot_clock>0.42 and player.is_on_floor() and player.velocity.length()>1 and not _unavailable(player):
		foot_clock = 0
		sound.global_position = player.global_position
		sound.effect("step")
	if clock<0.05: return
	var step := clock
	clock = 0
	var people: Array = game.population.residents.duplicate()
	people.append_array(game.party.members)
	var alive := {}
	for vehicle in game.city.traffic.vehicle_nodes():
		if not is_instance_valid(vehicle): continue
		var id: int = vehicle.get_instance_id()
		alive[id] = true
		var position: Vector3 = vehicle.global_position
		var start: Vector3 = previous.get(id,position)
		previous[id] = position
		var travel := position-start
		var speed := travel.length()/step
		if speed<2 or speed>45: continue # Ignore deliberate skip/teleport.
		var forward: Vector3 = vehicle.global_basis.z.normalized()
		var half_length := 5.2 if vehicle.get("route")!=null else 2.2
		for person in people:
			if _unavailable(person): continue
			var a := start-forward*half_length
			var b := position+forward*half_length
			var nearest := Geometry3D.get_closest_point_to_segment(person.global_position,a,b)
			if nearest.distance_to(person.global_position)<1.18:
				person.receive_vehicle_hit(travel.normalized(),speed)
	for id in previous.keys():
		if not alive.has(id): previous.erase(id)
	social_clock+=step
	if social_clock>18:
		social_clock = 0
		_social()

func _unavailable(person: Node) -> bool:
	return not is_instance_valid(person) or person.get("dead")==true or person.get("driving")==true or person.get("resting")!="" or is_instance_valid(person.get("riding_service")) or is_instance_valid(person.get("riding_bus")) or is_instance_valid(person.get("active_house")) or is_instance_valid(person.get("current_house")) or person.get_meta("road_fall",0.0)>0

func _social() -> void:
	for person in game.population.residents:
		if _unavailable(person) or person.activity_remaining>0 or person.in_conversation or person.combat_time>0 or person.get_meta("cab_waiting",false) or game.city.traffic.in_carriageway(person.global_position): continue
		for friend in game.population.residents:
			if friend==person or friend.activity_remaining>0 or _unavailable(friend) or friend.in_conversation or friend.combat_time>0 or friend.get_meta("cab_waiting",false): continue
			if person.global_position.distance_to(friend.global_position)>3.5: continue
			person.begin_conversation(friend)
			# Occasional harmless pavement disagreement, followed by normal routines.
			if randf()<0.18:
				person.say("Mind where you're going, please!",4)
				friend.say("Sorry about that. Busy day!",4)
			return
