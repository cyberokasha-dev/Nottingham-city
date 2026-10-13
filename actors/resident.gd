extends CharacterBody3D
## Autonomous residents share the player's rig, furniture slots and melee rules.
var person_name := "Resident"
var variant := 1
var female := false
var manager: Node3D
var home: Node3D
var current_house: Node3D
var visual: Node3D
var collider: CollisionShape3D
var bubble: Label3D
var state := "idle"
var resting := ""
var destination_name := "courtyard"
var route := PackedVector3Array()
var wait_time := 1.0
var speech_time := 0.0
var action_time := 0.0
var health := 100
var guarding := false
var driving := false
var opponent: CharacterBody3D
var combat_time := 0.0
var attack_delay := -1.0
var travel_count := 0
var conversations := 0
var stuck_time := 0.0
var last_position := Vector3.ZERO
var wants_home := false
var house_transition := false
var jump_time := 0.0
var dead := false
var waking := false
var invulnerability := 0.0
var hit_push := Vector3.ZERO
var hurt_time := 0.0
var dialogue: Node3D
var vitals: Node3D
var reply_delay := 0.0
var reply_key := ""
var reply_partner: CharacterBody3D

func _ready() -> void:
	add_to_group("people")
	add_to_group("residents")
	collider = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)
	visual = preload("res://actors/human.gd").new()
	add_child(visual)
	visual.setup(variant,female)
	dialogue = preload("res://actors/speech.gd").new()
	dialogue.actor = self
	dialogue.voice_set = "alba" if female else "joe"
	dialogue.variant = variant
	dialogue.viewer = manager.player
	add_child(dialogue)
	vitals = preload("res://actors/vitals.gd").new()
	vitals.actor = self
	vitals.viewer = manager.player
	add_child(vitals)
	bubble = Label3D.new()
	bubble.position.y = 2.7
	bubble.font_size = 28
	bubble.pixel_size = 0.005
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.outline_size = 8
	bubble.visibility_range_end = 28
	add_child(bubble)
	last_position = global_position
	wait_time = 2 + variant * 0.17

func say(text: String, duration := 4.0) -> void:
	bubble.text = person_name + "\n" + text
	speech_time = duration

func talk_to(person: CharacterBody3D, delay := 0.0) -> void:
	if dead or resting != "" or house_transition or combat_time > 0:
		return
	state = "talk"
	wait_time = 6.0+delay
	velocity = Vector3.ZERO
	visual.face(person.global_position-global_position,1)
	visual.play("talk")
	conversations += 1
	var keys := ["greeting","park","home","day"]
	var key: String = keys[(travel_count+variant)%keys.size()]
	if delay > 0:
		reply_delay = delay
		reply_key = key
		reply_partner = person
	else:
		say(dialogue.text_for(key),5)
		dialogue.speak(key)

func begin_conversation(friend: CharacterBody3D) -> void:
	if dead or friend.dead or state == "talk" or friend.state == "talk":
		return
	talk_to(friend)
	friend.talk_to(self,3.4)

func _physics_process(delta: float) -> void:
	speech_time = maxf(0,speech_time-delta)
	if speech_time <= 0:
		bubble.text = person_name if global_position.distance_to(manager.player.global_position) < 8 else ""
	action_time = maxf(0,action_time-delta)
	jump_time = maxf(0,jump_time-delta)
	invulnerability = maxf(0,invulnerability-delta)
	if dead:
		wait_time -= delta
		velocity.x = 0
		velocity.z = 0
		_gravity(delta)
		if wait_time <= 1.5 and not waking:
			waking = true
			visual.animator.play_backwards("death",0.1)
			visual.animator.speed_scale = visual.animator.get_animation("death").length/1.5
		if wait_time <= 0:
			revive()
		return
	if hurt_time > 0:
		hurt_time = maxf(0,hurt_time-delta)
		velocity.x = hit_push.x*hurt_time/0.28
		velocity.z = hit_push.z*hurt_time/0.28
		_gravity(delta)
		return
	if reply_delay > 0:
		reply_delay -= delta
		if reply_delay <= 0 and is_instance_valid(reply_partner) and global_position.distance_to(reply_partner.global_position) < 5:
			say(dialogue.text_for(reply_key),5)
			dialogue.speak(reply_key)
			reply_key = ""
	if house_transition:
		return
	if resting != "":
		wait_time -= delta
		if wait_time <= 0:
			stand_up()
		return
	if attack_delay >= 0:
		attack_delay -= delta
		if attack_delay < 0:
			preload("res://actors/combat.gd").strike(self,-visual.global_basis.z,12)
	if action_time > 0:
		return
	if combat_time > 0 and is_instance_valid(opponent):
		combat_time -= delta
		var toward: Vector3 = opponent.global_position-global_position
		visual.face(toward,delta)
		guarding = fmod(combat_time,2.6) > 1.3
		if toward.length() > 10 or opponent.driving or opponent.resting != "" or opponent.dead:
			combat_time = 0
			opponent = null
		elif toward.length() < 1.7:
			velocity = Vector3.ZERO
			if guarding:
				visual.play("heavy_punch")
				visual.animator.seek(0.14,true)
				visual.animator.pause()
			else:
				visual.play("punch",0.06)
				action_time = 0.9
				attack_delay = 0.18
		else:
			_move(toward.normalized(),delta,2.3)
		return
	guarding = false
	if state in ["idle","talk"]:
		wait_time -= delta
		velocity.x = 0
		velocity.z = 0
		if state == "idle":
			visual.play("idle")
		_gravity(delta)
		if wait_time <= 0:
			if is_instance_valid(current_house):
				_leave_home()
			else:
				manager.next_destination(self)
		return
	if route.is_empty():
		_arrive()
		return
	var toward := route[0]-global_position
	toward.y = 0
	if toward.length() < 0.55:
		route.remove_at(0)
		stuck_time = 0
		return
	_move(toward.normalized(),delta,3.2 if variant % 5 == 0 else 1.4 + (variant % 3)*0.13)
	if global_position.distance_to(last_position) < 0.001:
		stuck_time += delta
	else:
		stuck_time = maxf(0,stuck_time-delta)
	last_position = global_position
	if stuck_time > 2:
		# Try a short sidestep; don't teleport through homes or cars.
		try_jump()
		var side := Vector3(-toward.z,0,toward.x).normalized()
		route.insert(0,global_position+side*1.4)
		stuck_time = 0
	if global_position.y < -20:
		global_position = manager.spawn_point(variant)
		route.clear()

func _gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20*delta
	elif jump_time <= 0:
		velocity.y = 0
	move_and_slide()

func _move(direction: Vector3,delta: float,speed: float) -> void:
	velocity.x = direction.x*speed
	velocity.z = direction.z*speed
	_gravity(delta)
	visual.face(direction,delta)
	visual.play("jump_air" if jump_time > 0 else ("run" if speed > 2.8 else "walk"))
	visual.animator.speed_scale = clampf(speed/(5.5 if speed > 2.8 else 2.4),0.5,1.2)

func go_to(path: PackedVector3Array, place: String) -> void:
	route = path
	destination_name = place
	state = "walk"

func _arrive() -> void:
	travel_count += 1
	state = "idle"
	wait_time = 4+variant%5
	if wants_home and global_position.distance_to(home.entrance()) < 2:
		_enter_home()
	else:
		for friend in get_tree().get_nodes_in_group("residents"):
			if friend != self and not friend.dead and friend.resting == "" and friend.current_house == current_house and friend.combat_time <= 0 and global_position.distance_to(friend.global_position) < 3:
				begin_conversation(friend)
				break

func try_rest(action: String) -> bool:
	if dead or not is_instance_valid(current_house) or resting != "" or not current_house.claim_rest(action,self):
		return false
	resting = action
	global_position = current_house.rest_pose(action)
	collider.disabled = true
	velocity = Vector3.ZERO
	visual.rotation = Vector3(PI/2,current_house.rotation.y+PI,0) if action == "sleep" else Vector3(0,current_house.rotation.y+PI,0)
	visual.play("idle" if action == "sleep" else "sit",0.0 if action == "sleep" else 0.16)
	if action == "sleep":
		visual.animator.seek(0.1,true)
		visual.animator.pause()
	wait_time = 12 if action == "sleep" else 8
	say("Taking a rest.")
	dialogue.speak("rest")
	return true

func stand_up() -> void:
	if resting == "":
		return
	current_house.release_rest(resting,self)
	global_position = current_house.rest_approach(resting)
	visual.rotation = Vector3(0,current_house.rotation.y,0)
	collider.disabled = false
	resting = ""
	visual.play("idle")
	state = "idle"
	wait_time = 3

func _enter_home() -> void:
	house_transition = true
	velocity = Vector3.ZERO
	collider.disabled = true
	await home.open_door(true)
	visual.play("walk")
	visual.rotation.y = home.rotation.y
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self,"global_position",home.inside_point(),0.8)
	await tween.finished
	await home.open_door(false)
	current_house = home
	house_transition = false
	collider.disabled = false
	if not try_rest("sleep" if travel_count % 2 == 0 else "sit"):
		state = "idle"
		wait_time = 5

func _leave_home() -> void:
	house_transition = true
	collider.disabled = true
	visual.play("walk")
	var approach := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	approach.tween_property(self,"global_position",current_house.inside_point(),0.5)
	await approach.finished
	await current_house.open_door(true)
	visual.rotation.y = current_house.rotation.y+PI
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self,"global_position",current_house.entrance(),0.8)
	await tween.finished
	await current_house.open_door(false)
	current_house = null
	wants_home = false
	house_transition = false
	collider.disabled = false
	manager.next_destination(self)

func receive_hit(attacker: CharacterBody3D, damage: int) -> void:
	if dead or invulnerability > 0 or resting != "" or house_transition:
		return
	var toward: Vector3 = (attacker.global_position-global_position).normalized()
	if guarding and (-visual.global_basis.z).dot(toward) > 0.35:
		say("Blocked!",1.0)
		dialogue.speak("blocked")
		return
	health = maxi(0,health-damage)
	visual.impact()
	hit_push = -toward*2.8
	hurt_time = 0.28
	guarding = false
	reply_delay = 0
	dialogue.speak("hurt")
	opponent = attacker
	combat_time = 8
	state = "fight"
	attack_delay = -1
	velocity = Vector3.ZERO
	visual.play("hit",0.05)
	action_time = 0.55
	say("Hey! Stop that.")
	if health == 0:
		die()

func try_jump() -> bool:
	if dead or not is_on_floor() or resting != "" or house_transition or action_time > 0:
		return false
	velocity.y = 5.0
	jump_time = 0.5
	visual.play("jump_start",0.05)
	return true

func die() -> void:
	if dead:
		return
	dead = true
	waking = false
	health = 0
	state = "dead"
	wait_time = 7
	combat_time = 0
	attack_delay = -1
	action_time = 0
	hurt_time = 0
	guarding = false
	opponent = null
	reply_delay = 0
	velocity = Vector3.ZERO
	visual.play("death",0.08)
	say("DEAD — waking shortly.",7)

func revive() -> void:
	dead = false
	waking = false
	health = 100
	invulnerability = 2
	state = "idle"
	wait_time = 4
	velocity = Vector3.ZERO
	visual.play("idle",0.2)
	say("I'm awake. Let's start again.")
	dialogue.speak("awake")
