extends RefCounted
# A short knockdown and get-up sequence without falsely killing a healthy character.
static func hit(person: CharacterBody3D, direction: Vector3, speed: float) -> void:
	if person.dead or person.invulnerability>0 or person.get_meta("road_fall",0.0)>0: return
	person.set_meta("road_fall",3.2)
	person.set_meta("road_getting_up",false)
	person.health = maxi(1,person.health-clampi(int(speed*1.5),4,35))
	person.action_time = 3.2
	person.hurt_time = 0
	person.guarding = false
	person.velocity = direction*minf(speed*0.45,5.0)+Vector3.UP*1.1
	person.visual.impact()
	person.visual.play("death",0.06)
	if person.get("combat_time")!=null:
		person.combat_time = 0
		person.opponent = null
	if not person.has_node("RoadImpactAudio"):
		var audio := preload("res://simulation/service_audio.gd").new()
		person.add_child(audio)
		audio.name = "RoadImpactAudio"
	person.get_node("RoadImpactAudio").effect("impact")
	if person.has_method("_notify"): person._notify("Knocked down • getting back up")
	else: person.say("Watch out!",3)

static func tick(person: CharacterBody3D, delta: float) -> bool:
	var remaining := float(person.get_meta("road_fall",0.0))
	if remaining<=0: return false
	remaining = maxf(0,remaining-delta)
	person.set_meta("road_fall",remaining)
	person.velocity.x = move_toward(person.velocity.x,0,delta*4)
	person.velocity.z = move_toward(person.velocity.z,0,delta*4)
	if not person.is_on_floor(): person.velocity.y-=20*delta
	person.move_and_slide()
	if remaining<1.2 and not person.get_meta("road_getting_up",false):
		person.set_meta("road_getting_up",true)
		person.visual.animator.play_backwards("death",0.1)
		person.visual.animator.speed_scale = person.visual.animator.get_animation("death").length/1.2
	if remaining<=0:
		person.visual.animator.speed_scale = 1
		person.visual.play("idle",0.1)
		if person.get("current_clip")!=null: person.current_clip = "idle"
		person.action_time = 0
		person.invulnerability = 2
		person.velocity = Vector3.ZERO
	return true
