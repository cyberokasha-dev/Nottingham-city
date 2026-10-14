extends Camera3D
@export var min_distance := 2.0
@export var max_distance := 4.0
@export var angle_v_adjust := 0.0
@export var height := 1.5
var camera_type := 0
var orbit := 0.0
var manual_time := 0.0
var base_fov := 65.0
var initialized := false

enum CameraType { EXTERIOR, INTERIOR, TOP_DOWN, MAX }
func _ready() -> void:
	base_fov = fov
	set_as_top_level(true)

func _input(event: InputEvent) -> void:
	if not current or bool(get_parent().get_parent().get_meta("controls_blocked",false)): return
	if event.is_action_pressed("cycle_camera"): cycle_view()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		orbit -= event.relative.x*0.005
		manual_time = 1.6

func cycle_view() -> void:
	camera_type = (camera_type+1)%CameraType.MAX
	initialized = false

func update_camera() -> void:
	initialized = false

func _physics_process(delta: float) -> void:
	if not current: return
	manual_time = maxf(0,manual_time-delta)
	if manual_time<=0: orbit = lerp_angle(orbit,0,1-exp(-3*delta))
	var body: Node3D = get_parent().get_parent()
	var target := body.global_position+Vector3.UP*0.9
	var desired: Vector3
	if camera_type==CameraType.INTERIOR:
		global_transform = body.get_node("InteriorCameraPosition").global_transform
		# Car meshes face +Z, Camera3D faces -Z.
		rotate_y(PI)
		return
	elif camera_type==CameraType.TOP_DOWN:
		desired = target+Vector3(0,20,0.01)
	else:
		var back := -body.global_basis.z.normalized().rotated(Vector3.UP,orbit)
		desired = target+back*max_distance+Vector3.UP*height
		var ray := PhysicsRayQueryParameters3D.create(target,desired,1)
		ray.exclude = [body.get_rid()] if body is CollisionObject3D else []
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): desired = hit.position+(target-hit.position).normalized()*0.3
	global_position = global_position.lerp(desired,1-exp(-7*delta)) if initialized else desired
	look_at(target,Vector3.UP)
	initialized = true
	var speed: float = body.linear_velocity.length() if body is RigidBody3D else 0.0
	fov = lerpf(fov,clampf(base_fov+speed*0.35,base_fov,82),1-exp(-3*delta))
