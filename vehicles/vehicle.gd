extends VehicleBody3D

const STEER_SPEED = 1.5
const STEER_LIMIT = 0.4
const BRAKE_STRENGTH = 2.0

@export var engine_force_value := 40.0
@export var brake_force := 30.0
@export var display_name := "Vehicle"
@export var electric := false

var previous_speed := linear_velocity.length()
var _steer_target := 0.0
var driver_active := false
var upright_time := 0.0

@onready var desired_engine_pitch: float = $EngineSound.pitch_scale

func _ready() -> void:
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON
	add_to_group("driveable_vehicles")
	get_tree().call_group("city_traffic","invalidate_spatial")
	set_driver_active(false)
	add_child(preload("res://simulation/service_audio.gd").new())

func _physics_process(delta: float):
	get_node("ServiceAudio").set_motion(linear_velocity.length(),"electric" if electric else "engine")
	if not driver_active or bool(get_meta("controls_blocked",false)):
		engine_force = 0.0
		brake = brake_force
		steering = move_toward(steering, 0.0, STEER_SPEED * delta)
		previous_speed = linear_velocity.length()
		return
	# Limit suspension/impact spikes and recover an overturned stationary vehicle.
	if linear_velocity.length()>28.0:
		linear_velocity = linear_velocity.limit_length(28.0)
	if angular_velocity.length()>2.4:
		angular_velocity = angular_velocity.limit_length(2.4)
	upright_time = upright_time+delta if global_basis.y.y<0.3 and linear_velocity.length()<2 else 0.0
	if upright_time>2.5:
		global_rotation = Vector3(0,global_rotation.y,0)
		global_position.y = -4.35
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		upright_time = 0
	brake = 0.0
	var previous_force:=engine_force
	var fwd_mps := (linear_velocity * transform.basis).x

	_steer_target = Input.get_axis(&"turn_right", &"turn_left")
	_steer_target *= STEER_LIMIT

	# Engine sound simulation (not realistic, as this car script has no notion of gear or engine RPM).
	desired_engine_pitch = clampf(0.8+linear_velocity.length()/13.0,0.8,2.2)
	# Change pitch smoothly to avoid abrupt change on collision.
	$EngineSound.pitch_scale = lerpf($EngineSound.pitch_scale, desired_engine_pitch, 0.2)
	$EngineSound.volume_db = -60

	if abs(linear_velocity.length() - previous_speed) > 1.0:
		# Sudden velocity change, likely due to a collision. Play an impact sound to give audible feedback,
		# and vibrate for haptic feedback.
		$ImpactSound.play()
		Input.vibrate_handheld(100)
		for joypad in Input.get_connected_joypads():
			Input.start_joy_vibration(joypad, 0.0, 0.5, 0.1)

	# Automatically accelerate when using touch controls (reversing overrides acceleration).
	if Input.is_action_pressed(&"accelerate"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		var speed := linear_velocity.length()
		if speed < 5.0 and not is_zero_approx(speed):
			engine_force = clampf(engine_force_value * 5.0 / speed, 0.0, engine_force_value * 2.5)
		else:
			engine_force = engine_force_value

		# Respect analog trigger pressure and the on-screen R2 throttle button.
		engine_force *= Input.get_action_strength(&"accelerate")
	else:
		engine_force = 0.0

	if Input.is_action_pressed(&"reverse"):
		# Increase engine force at low speeds to make the initial reversing faster.
		var speed := linear_velocity.length()
		if speed < 5.0 and not is_zero_approx(speed):
			engine_force = -clampf(engine_force_value * BRAKE_STRENGTH * 5.0 / speed, 0.0, engine_force_value * 2.5)
		else:
			engine_force = -engine_force_value * BRAKE_STRENGTH

		# Apply analog brake factor for more subtle braking if not fully holding down the trigger.
		engine_force *= Input.get_action_strength(&"reverse")

	steering = move_toward(steering, _steer_target, STEER_SPEED * delta)
	if has_meta("graphics"):preload("res://vehicles/driver_controls.gd").update(get_meta("graphics"),-steering/STEER_LIMIT,delta)
	engine_force=move_toward(previous_force,engine_force,engine_force_value*3.5*delta)
	if Input.is_action_pressed("jump") or Input.is_action_pressed("handbrake"):
		engine_force = 0.0
		brake = brake_force

	previous_speed = linear_velocity.length()

func set_driver_active(active: bool) -> void:
	driver_active = active
	if has_meta("graphics"):
		get_meta("graphics").get_meta("manual_controls").visible=active
		if not active:preload("res://vehicles/driver_controls.gd").update(get_meta("graphics"),0,1)
	$CameraBase/Camera3D.set_process_input(active)
	$AudioListener3D.current = active
	$CPUParticles3D.emitting = active and not electric
	if active:
		for body in get_parent().find_children("*", "RigidBody3D", true, false):
			body.freeze = false
		if not electric:
			$EngineSound.play()
	else:
		engine_force = 0.0
		brake = brake_force
		$EngineSound.stop()

func park() -> void:
	set_driver_active(false)
	# Hold the whole parked rig, including trailers and tow chains, until re-entry.
	for body in get_parent().find_children("*", "RigidBody3D", true, false):
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
