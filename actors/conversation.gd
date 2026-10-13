extends CanvasLayer
const DATA = preload("res://actors/dialogue_data.gd")
var game: Node3D
var target: CharacterBody3D
var player: CharacterBody3D
var context := ""
var active := false
var ready_for_reply := false
var serial := 0
var panel: PanelContainer
var subtitle: Label
var choices: VBoxContainer
var last_effect := ""

func _ready() -> void:
	layer = 8
	panel = PanelContainer.new()
	panel.position = Vector2(22,240)
	panel.custom_minimum_size = Vector2(510,170)
	add_child(panel)
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	subtitle = Label.new()
	subtitle.custom_minimum_size = Vector2(490,85)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size",19)
	rows.add_child(subtitle)
	choices = VBoxContainer.new()
	rows.add_child(choices)
	panel.hide()

func context_for(person: CharacterBody3D) -> String:
	if person.combat_time > 0 or person.opponent == game.player:
		return "hostile"
	if person.health < 50 or game.player.health < 50:
		return "injured"
	if is_instance_valid(game.player.active_house):
		return "house"
	if person.relationship >= 2:
		return "friend"
	for body in game.fleet:
		if game.player.global_position.distance_to(body.global_position) < 13:
			return "car"
	for place in game.population.places:
		if "park" in place.name and game.player.global_position.distance_to(place.point) < 30:
			return "park"
	return "street"

func start(person: CharacterBody3D) -> bool:
	if active or game.player.dead or person.dead or person.resting != "" or person.house_transition:
		return false
	player = game.player
	target = person
	context = context_for(person)
	active = true
	ready_for_reply = false
	serial += 1
	person.in_conversation = true
	person.bubble.hide()
	player.prompt.text = "Talking to " + person.person_name + " — listen, then choose a reply."
	person.velocity = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.folded_arms = false
	person.visual.face(player.global_position-person.global_position,1)
	player.visual.face(person.global_position-player.global_position,1)
	person.visual.play("talk")
	player._play_clip("talk")
	panel.show()
	_clear_choices()
	_opening(serial)
	return true

func _opening(session: int) -> void:
	var scene: Dictionary = DATA.SCENES[context]
	await _say(player,scene.openers[player.profile.name],session)
	if not valid(session):
		return
	await _say(target,scene.npc[target.variant%scene.npc.size()],session)
	if not valid(session):
		return
	ready_for_reply = true
	for i in range(scene.options.size()):
		var button := Button.new()
		button.text = "%d · %s" % [i+1,scene.options[i].label]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(choose.bind(i))
		choices.add_child(button)
	var leave := Button.new()
	leave.text = "G / Esc · End conversation"
	leave.focus_mode = Control.FOCUS_NONE
	leave.pressed.connect(finish)
	choices.add_child(leave)

func _say(actor: CharacterBody3D,key: String,session: int) -> void:
	if not valid(session):
		return
	var name: String = actor.profile.name if actor == player else actor.person_name
	subtitle.text = name+": "+actor.dialogue.text_for(key)
	if actor == target:
		target.say(actor.dialogue.text_for(key),7)
	actor.dialogue.speak(key,true)
	var duration: float = actor.dialogue.duration_for(key)
	await get_tree().create_timer(duration+0.2,false,true).timeout

func valid(session: int) -> bool:
	return active and player == game.player and serial == session and is_instance_valid(target) and not target.dead and not player.dead

func choose(index: int) -> bool:
	if not active or not ready_for_reply or index < 0 or index >= DATA.SCENES[context].options.size():
		return false
	ready_for_reply = false
	_clear_choices()
	_reply(index,serial)
	return true

func _reply(index: int,session: int) -> void:
	var option: Dictionary = DATA.SCENES[context].options[index]
	await _say(player,option.player[player.profile.name],session)
	if not valid(session):
		return
	apply_effect(option.effect)
	await _say(target,option.npc,session)
	if valid(session):
		finish()

func apply_effect(effect: String) -> void:
	last_effect = effect
	match effect:
		"peace":
			target.combat_time = 0
			target.opponent = null
			target.attack_delay = -1
			target.relationship = mini(3,target.relationship+1)
		"friend", "follow":
			target.relationship = mini(3,target.relationship+1)
			if effect == "follow":
				target.follow_actor = player
				target.follow_time = 20
		"directions":
			game.city_map.destination = game.population.places[2].point
			game.city_map.destination_active = true
			player._notify("East park marked in blue on the map.")
		"threat":
			target.relationship = maxi(-3,target.relationship-2)
			target.opponent = player
			target.combat_time = 8
		"avoid":
			target.relationship = maxi(-3,target.relationship-1)
			target.combat_time = 0
			target.opponent = null
			target.destination_name = "a quieter street"
			target.route = PackedVector3Array([target.global_position+(target.global_position-player.global_position).normalized()*8])

func finish() -> void:
	serial += 1
	active = false
	ready_for_reply = false
	panel.hide()
	if is_instance_valid(target):
		target.in_conversation = false
		target.bubble.show()
		target.state = "fight" if target.combat_time > 0 else ("walk" if last_effect == "avoid" else "idle")
		target.wait_time = 3
		target.dialogue.stop()
	if is_instance_valid(player):
		player.dialogue.stop()
		if not player.dead and player.resting == "":
			player._play_clip("idle")
	last_effect = ""

func _clear_choices() -> void:
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()

func _process(_delta: float) -> void:
	if active and (not is_instance_valid(target) or player.dead or target.dead or player != game.player or player.global_position.distance_to(target.global_position) > 6):
		finish()

func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:
			choose(event.physical_keycode-KEY_1)
		elif event.physical_keycode in [KEY_G,KEY_ESCAPE]:
			finish()
		get_viewport().set_input_as_handled()
