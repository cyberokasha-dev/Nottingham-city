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

func _ready() -> void:
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
	var lineup := [
		["cybercab",Vector3(0,LOT_Y+0.62,34)],
		["sports",Vector3(-7,LOT_Y+0.66,34)],
		["suv",Vector3(7,LOT_Y+0.66,34)],
		["van",Vector3(14,LOT_Y+0.66,34)],
		["tow",Vector3(-14,LOT_Y+0.60,55)],
		["trailer",Vector3(0,LOT_Y+0.60,58)]
	]
	for item in lineup:
		var rig: Node3D = FACTORY.make(item[0])
		rig.position = item[1]
		town.add_child(rig)
		var body: VehicleBody3D = rig.get_node("Body")
		fleet.append(body)
		_label_vehicle(body)
	party = preload("res://actors/party.gd").new()
	party.game = self
	add_child(party)
	population = preload("res://actors/population.gd").new()
	population.city = city
	population.player = player
	town.add_child(population)
	var map_layer := CanvasLayer.new()
	town.add_child(map_layer)
	var map := preload("res://town/city_map.gd").new()
	city_map = map
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
	cabs = preload("res://simulation/cabs.gd").new()
	cabs.game = self
	cabs.economy = economy
	add_child(cabs)
	phone = preload("res://simulation/phone.gd").new()
	phone.game = self
	add_child(phone)
	bus_recitation = preload("res://transport/bus_recitation.gd").new()
	bus_recitation.game = self
	add_child(bus_recitation)
	city.transport.recitation = bus_recitation
	_settle_parked_fleet()

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
	mesh.size = Vector3(48,0.22,48)
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
	sign.text = "NOTTINGHAM CITY\nVEHICLE COURTYARD"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position = Vector3(-19,LOT_Y+2.7,25)
	town.add_child(sign)
	for x in [-22,22]:
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
