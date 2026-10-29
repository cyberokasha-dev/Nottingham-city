extends RefCounted
# Explicit fixtures for the legacy vehicle-physics tests. Production starts with an empty depot.
static func install(game:Node3D) -> void:
 for item in [["cybercab",Vector3(0,-4.5,34)],["sports",Vector3(-7,-4.46,34)],["suv",Vector3(7,-4.46,34)],["van",Vector3(14,-4.46,34)],["tow",Vector3(-14,-4.52,55)],["trailer",Vector3(0,-4.52,58)]]:
  var rig=preload("res://vehicles/vehicle_factory.gd").make(item[0]);rig.position=item[1];game.town.add_child(rig)
  var body:VehicleBody3D=rig.get_node("Body");body.set_meta("test_rental",true);game.fleet.append(body);game._label_vehicle(body)
 game.city_map.fleet=game.fleet
 game._settle_parked_fleet()
