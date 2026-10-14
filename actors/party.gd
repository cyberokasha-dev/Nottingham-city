extends Node
## Four independently persistent player bodies; control and the camera move together.
const PROFILES := [
	{"name":"Muhammad", "voice":"northern_english_male", "voice_pitch":1.02, "variant":0, "female":false, "model":"muhammad", "colour":Color("43c4d1")},
	{"name":"Aisha", "voice":"cori", "voice_pitch":1.03, "variant":1, "female":true, "model":"human", "colour":Color("d890bd")},
	{"name":"Musa", "voice":"northern_english_male", "voice_pitch":0.96, "variant":3, "female":false, "model":"human", "colour":Color("75be9f")},
	{"name":"Jade", "voice":"cori", "voice_pitch":0.97, "variant":8, "female":true, "model":"human", "colour":Color("ad9fe6")}
]
var game: Node3D
var members: Array[CharacterBody3D] = []
var selected := 0
var wheel: Control
var switching := false
var voices_enabled := true

func _ready() -> void:
	var spawns := [Vector3(3,-5,38),Vector3(-72.3,-4.98,-52.3),Vector3(87.7,-4.98,23.7),Vector3(-32.3,-4.98,87.7)]
	for i in range(4):
		var character := preload("res://player/player.gd").new()
		character.name = "Player" if i == 0 else PROFILES[i].name
		character.profile = PROFILES[i]
		character.controlled = i == 0
		character.party = self
		character.use_home_position = true
		character.home_position = spawns[i]
		game.town.add_child(character)
		members.append(character)
	game.player = members[0]
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	wheel = preload("res://actors/character_wheel.gd").new()
	wheel.party = self
	layer.add_child(wheel)

func toggle_wheel() -> void:
	if is_instance_valid(game.phone) and game.phone.panel.visible:
		return
	if switching or game.player.transitioning or game.player.dead or is_instance_valid(game.player.riding_service) or is_instance_valid(game.player.riding_bus) or is_instance_valid(game.player.park_activity):
		game.player._notify("Wait until you are ready before changing character.")
		return
	if game.conversation.active:
		game.conversation.finish()
	wheel.visible = not wheel.visible
	if wheel.visible:
		wheel.highlight = selected
		wheel.queue_redraw()

func can_control(index: int) -> bool:
	return index >= 0 and index < members.size() and not members[index].dead and not members[index].transitioning

func choose(index: int) -> bool:
	if switching or not can_control(index):
		return false
	wheel.hide()
	if index == selected:
		return true
	var previous: CharacterBody3D = members[selected]
	if previous.dead or previous.transitioning or is_instance_valid(previous.riding_service) or is_instance_valid(previous.riding_bus) or is_instance_valid(previous.park_activity):
		return false
	if previous.driving:
		if not previous.try_exit():
			previous._notify("Stop in an open place before switching character.")
			return false
		switching = true
		_finish_car_switch(previous,index)
		return true
	_switch_now(index)
	return true

func _finish_car_switch(previous: CharacterBody3D,index: int) -> void:
	while previous.transitioning:
		await get_tree().physics_frame
	_switch_now(index)
	switching = false

func _switch_now(index: int) -> void:
	var previous: CharacterBody3D = members[selected]
	previous.controlled = false
	previous.hud.hide()
	previous.controls.hide()
	previous.velocity = Vector3.ZERO
	previous.dialogue.stop()
	if is_instance_valid(previous.active_house):
		previous.active_house.set_inside(false)
	selected = index
	var current: CharacterBody3D = members[index]
	game.player = current
	current.controlled = true
	current.hud.show()
	current.controls.show()
	current.camera.make_current()
	if is_instance_valid(current.active_house):
		current.active_house.set_inside(true)
	game.population.player = current
	game.city_map.player = current
	for resident in game.population.residents:
		resident.dialogue.viewer = current
		resident.vitals.viewer = current
	current.dialogue.event("switch")
	current._notify("Now playing as " + current.profile.name)
