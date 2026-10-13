extends RefCounted
## Resolve a single timed melee strike: reach, facing, wall occlusion, then damage.
static func strike(attacker: CharacterBody3D, direction: Vector3, damage: int) -> int:
	var hits := 0
	for target in attacker.get_tree().get_nodes_in_group("people"):
		if target == attacker or target.dead or not target.has_method("receive_hit"):
			continue
		var offset: Vector3 = target.global_position-attacker.global_position
		if offset.length() > 1.9 or absf(offset.y) > 1.0:
			continue
		offset.y = 0
		if offset.length() > 0.01 and offset.normalized().dot(direction) < 0.45:
			continue
		var ray := PhysicsRayQueryParameters3D.create(attacker.global_position+Vector3.UP,target.global_position+Vector3.UP)
		ray.exclude = [attacker.get_rid(),target.get_rid()]
		if not attacker.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		target.receive_hit(attacker,damage)
		hits += 1
	return hits
