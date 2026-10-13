extends Node3D

# Ambient left-hand traffic; lightweight visual vehicles, not physical traffic.
const ROAD_X = [-140.0, -80.0, -40.0, 40.0, 80.0, 140.0]
const ROAD_Z = [-120.0, -60.0, 16.0, 80.0, 140.0]
const ROAD_LEVEL: float = -5.02
var elapsed: float = 0.0
var vehicles: Array[Node3D] = []
var directions: Array[float] = []
var vertical_lanes: Array[bool] = []
var lane_indices: Array[int] = []
var distances: Array[float] = []
var signals: Array[MeshInstance3D] = []
var signal_vertical: Array[bool] = []
var signal_color_index: Array[int] = []

func _ready() -> void:
	for x in ROAD_X:
		for z in ROAD_Z:
			for vertical in [true, false]:
				var pole: MeshInstance3D = _box(Vector3(0.14, 3.8, 0.14), Color("555b60"))
				pole.position = Vector3(float(x) + (-8.2 if vertical else 8.2), ROAD_LEVEL + 1.9, float(z) + (8.2 if vertical else -8.2))
				for lamp_index in range(3):
					var lamp: MeshInstance3D = _box(Vector3(0.35, 0.32, 0.22), Color("222222"))
					lamp.position = Vector3(0.0, 1.0 - float(lamp_index) * 0.38, 0.2)
					pole.add_child(lamp)
					signals.append(lamp)
					signal_vertical.append(vertical)
					signal_color_index.append(lamp_index)
	for i in range(36):
		var vertical: bool = i % 2 == 0
		var direction: float = 1.0 if i % 4 < 2 else -1.0
		var vehicle: Node3D = Node3D.new()
		var palette: Array[Color] = [Color("254e83"), Color("c8cbd0"), Color("ad3434"), Color("242a30"), Color("d9a73d"), Color("537d68")]
		var shell: MeshInstance3D = _box(Vector3(1.75, 0.75, 3.7), palette[i % palette.size()])
		shell.position.y = 0.72
		vehicle.add_child(shell)
		var roof: MeshInstance3D = _box(Vector3(1.45, 0.45, 1.85), Color("252c35"))
		roof.position.y = 1.25
		vehicle.add_child(roof)
		add_child(vehicle)
		vehicles.append(vehicle)
		vertical_lanes.append(vertical)
		directions.append(direction)
		lane_indices.append((i / 2) % (ROAD_X.size() if vertical else ROAD_Z.size()))
		distances.append(fposmod(float(i) * 23.7, 310.0) - 155.0)
	_update_signals()

func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	return instance

func _is_green(vertical: bool) -> bool:
	var phase: float = fposmod(elapsed, 24.0)
	return phase < 10.0 if vertical else (phase >= 12.0 and phase < 22.0)

func _update_signals() -> void:
	for i in range(signals.size()):
		var green: bool = _is_green(signal_vertical[i])
		var phase: float = fposmod(elapsed, 24.0)
		var amber: bool = (phase >= 10.0 and phase < 12.0) if signal_vertical[i] else phase >= 22.0
		var lit: bool = (signal_color_index[i] == 0 and not green and not amber) or (signal_color_index[i] == 1 and amber) or (signal_color_index[i] == 2 and green)
		var colors: Array[Color] = [Color.RED, Color.YELLOW, Color.GREEN]
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = colors[signal_color_index[i]] if lit else Color("252525")
		signals[i].material_override = material

func _process(delta: float) -> void:
	elapsed += delta
	_update_signals()
	for i in range(vehicles.size()):
		var vertical: bool = vertical_lanes[i]
		var direction: float = directions[i]
		var distance: float = distances[i]
		var nearest: float = 10000.0
		if vertical:
			for crossing in ROAD_Z:
				var ahead: float = (float(crossing) - distance) * direction
				if ahead >= 0.0 and ahead < nearest:
					nearest = ahead
		else:
			for crossing in ROAD_X:
				var ahead: float = (float(crossing) - distance) * direction
				if ahead >= 0.0 and ahead < nearest:
					nearest = ahead
		var speed: float = 7.0 + float(i % 5) * 1.4
		if not _is_green(vertical) and nearest < 12.0:
			speed = 0.0
		distance += direction * speed * delta
		if distance > 157.0:
			distance = -157.0
		if distance < -157.0:
			distance = 157.0
		distances[i] = distance
		var lane: int = lane_indices[i]
		var offset: float = -2.8 if direction > 0.0 else 2.8
		if vertical:
			vehicles[i].position = Vector3(float(ROAD_X[lane]) + offset, ROAD_LEVEL, distance)
			vehicles[i].rotation.y = 0.0 if direction > 0.0 else PI
		else:
			vehicles[i].position = Vector3(distance, ROAD_LEVEL, float(ROAD_Z[lane]) + offset)
			vehicles[i].rotation.y = PI / 2.0 if direction > 0.0 else -PI / 2.0
