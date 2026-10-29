extends Node3D

const LOT_Y := -5.12
const FACTORY = preload("res://vehicles/vehicle_factory.gd")
var town: Node3D
var fleet: Array[VehicleBody3D] = []
var player: CharacterBody3D
var city: Node3D
var population: Node3D
var party: Node
var city_map: Control
var conversation: CanvasLayer
var economy: Node
var cabs: Node3D
var phone: CanvasLayer
var bus_recitation: CanvasLayer
var rail: Node3D
var helicopters: Node3D
var performance: Node
var services:Node
var city_account:Node

func _ready() -> void:
	# Transport opts into interpolation; the streamed city and ordinary actors
	# retain their own animation/tween timing.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	performance = preload("res://simulation/performance.gd").new()
	add_child(performance)
	town = Node3D.new()
	town.name = "CityWorld"
	add_child(town)
	city = preload("res://town/city.gd").new()
	city.name = "City"
	town.add_child(city)
	var speedometer := Button.new()
	speedometer.name = "Spedometer"
	speedometer.set_script(preload("res://spedometer.gd"))
	speedometer.position = Vector2(20,20)
	speedometer.custom_minimum_size = Vector2(170,38)
	speedometer.pressed.connect(speedometer._on_spedometer_pressed)
	town.add_child(speedometer)
	speedometer.hide()
	_build_courtyard()

	party = preload("res://actors/party.gd").new()
	party.game = self
	add_child(party)
	population = preload("res://actors/population.gd").new()
	population.city = city
	population.player = player
	town.add_child(population)
	var map_layer := CanvasLayer.new()
	map_layer.layer = 18
	town.add_child(map_layer)
	var map := preload("res://town/city_map.gd").new()
	city_map = map
	map.game = self
	map.player = player
	map.city = city
	map.fleet = fleet
	map_layer.add_child(map)
	conversation = preload("res://actors/conversation.gd").new()
	conversation.game = self
	add_child(conversation)
	economy = preload("res://simulation/economy.gd").new()
	economy.game = self
	add_child(economy)
	city.transport.economy = economy
	city.transport.seed_services()
	cabs = preload("res://simulation/cabs.gd").new()
	cabs.game = self
	cabs.economy = economy
	add_child(cabs)
	helicopters = preload("res://simulation/helicopters.gd").new()
	helicopters.game = self
	helicopters.economy = economy
	add_child(helicopters)
	rail=preload("res://transport/rail.gd").new()
	rail.game=self
	add_child(rail)
	services=preload("res://simulation/city_services.gd").new()
	services.game=self
	add_child(services)
	phone = preload("res://simulation/phone.gd").new()
	phone.game = self
	add_child(phone)
	var events := preload("res://simulation/street_events.gd").new()
	events.game = self
	add_child(events)
	bus_recitation = preload("res://transport/bus_recitation.gd").new()
	bus_recitation.game = self
	add_child(bus_recitation)
	city.transport.recitation = bus_recitation
	_settle_parked_fleet()
	city.traffic.invalidate_spatial()
	var controller_link=preload("res://phone/phone_link.gd").new()
	add_child(controller_link)
	var touch=preload("res://phone/mobile_controls.gd").new()
	touch.game=self;touch.link=controller_link;add_child(touch)
	city_account=preload("res://simulation/city_account.gd").new();city_account.game=self;add_child(city_account)
	var city_hud=preload("res://actors/city_hud.gd").new()
	city_hud.game=self
	add_child(city_hud)

func _settle_parked_fleet() -> void:
	for i in range(120):
		await get_tree().physics_frame
	for body in fleet:
		if not body.driver_active and (not player.transitioning or player.vehicle != body):
			body.park()

func _build_courtyard() -> void:
	var tarmac := StandardMaterial3D.new()
	tarmac.albedo_color = Color("35434b")
	tarmac.roughness = 0.95
	var surface := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(62,0.22,50)
	surface.mesh = mesh
	surface.material_override = tarmac
	surface.position = Vector3(0,LOT_Y-0.08,46)
	town.add_child(surface)
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	ground.add_child(collision)
	surface.add_child(ground)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("e4e4d2")
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for z in [34,55]:
		for x in [-17.5,-10.5,-3.5,3.5,10.5,17.5]:
			_marking(Vector3(x,LOT_Y+0.045,z),Vector3(0.075,0.015,7.5 if z==34 else 13.0),paint)
	_marking(Vector3(0,LOT_Y+0.045,30),Vector3(35,0.015,0.075),paint)
	var sign := Label3D.new()
	sign.text = "NOTTINGHAM CITY\nCOUNCIL RENTAL DEPOT"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position = Vector3(-19,LOT_Y+2.7,25)
	town.add_child(sign)
	for x in [-29,29]:
		for z in [28,64]:
			var light := OmniLight3D.new()
			light.position = Vector3(x,LOT_Y+4,z)
			light.omni_range = 10.0
			light.light_energy = 0.5
			town.add_child(light)

func _marking(pos: Vector3,size: Vector3,material: Material) -> void:
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	line.mesh = box
	line.material_override = material
	line.position = pos
	town.add_child(line)

func _label_vehicle(body: VehicleBody3D) -> void:
	var label := Label3D.new()
	label.text = body.display_name.replace(" — ","\n")
	label.font_size = 28
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0,2.7,0)
	label.no_depth_test = false
	body.add_child(label)

func _exit_tree() -> void:
	# Stop all voices together before draining the native audio thread once.
	for audio in find_children("*","AudioStreamPlayer3D",true,false)+find_children("*","AudioStreamPlayer",true,false):
		audio.stop()
		audio.stream=null
	# Godot 4.4 retires stopped WAV playbacks during a subsequent audio mix.
	# Fast headless exits can otherwise finish the driver before that deletion.
	if not OS.has_feature("web"):
		var drain_ms:=clampi(ceili(AudioServer.get_time_to_next_mix()*1000)+40,40,100)
		OS.delay_msec(drain_ms)
	# Shared render/audio resources belong to this city session, not engine shutdown.
	preload("res://transport/crowd_person.gd").templates.clear()
	preload("res://transport/crowd_person.gd").palette.clear()
	preload("res://vehicles/road_car.gd").wheel_meshes.clear()
	preload("res://vehicles/coachwork.gd").clear()
	preload("res://town/house.gd").shell_materials.clear()
	preload("res://town/house.gd").shell_roof=null
	preload("res://town/house.gd").shell_box=null
	preload("res://town/house.gd").shell_batches.clear()
	preload("res://town/house.gd").batch_material=null
	preload("res://transport/geometry.gd").vertex_material=null
	preload("res://town/world_layout.gd").rail_definitions.clear()
	preload("res://town/world_layout.gd").roads.clear()
	preload("res://town/world_layout.gd").pad_cache.clear()
	preload("res://town/world_layout.gd").station_pad_cache.clear()
	preload("res://simulation/service_audio.gd").loops.clear()
	preload("res://simulation/service_audio.gd").effects.clear()
