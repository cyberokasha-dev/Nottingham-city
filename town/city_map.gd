extends Control

var player: Node3D
var city: Node3D
var fleet: Array[VehicleBody3D] = []
var refresh := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(220,220)
	position = Vector2(maxf(20,get_viewport_rect().size.x-240),20)

func _process(delta: float) -> void:
	position = Vector2(maxf(20,get_viewport_rect().size.x-240),20)
	refresh += delta
	if refresh > 0.1:
		queue_redraw()
		refresh = 0.0

func point(pos: Vector3) -> Vector2:
	return Vector2((pos.x+170)/340*200+10,(pos.z+150)/340*200+10)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.05,0.1,0.14,0.86))
	if not is_instance_valid(city):
		return
	for x in city.ROAD_X:
		draw_line(point(Vector3(x,0,-150)),point(Vector3(x,0,170)),Color("a0afbb"),4)
	for z in city.ROAD_Z:
		draw_line(point(Vector3(-160,0,z)),point(Vector3(160,0,z)),Color("a0afbb"),4)
	for house in city.houses:
		draw_rect(Rect2(point(house.global_position)-Vector2(2,3),Vector2(4,6)),Color("cf9778"))
	for vehicle in fleet:
		draw_circle(point(vehicle.global_position),2.2,Color("dfe8f0"))
	for resident in get_tree().get_nodes_in_group("residents"):
		draw_circle(point(resident.global_position),1.8,Color("7ae1ba"))
	if is_instance_valid(player):
		var pos := point(player.global_position)
		draw_circle(pos,4,Color("ffdd75"))
		var direction := Vector2(-sin(player.yaw),-cos(player.yaw))
		if player.driving and is_instance_valid(player.vehicle):
			direction = Vector2(player.vehicle.global_basis.z.x,player.vehicle.global_basis.z.z).normalized()
		draw_line(pos,pos+direction*9,Color("ffdd75"),2)
