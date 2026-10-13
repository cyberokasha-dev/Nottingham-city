extends Node3D
const G = preload("res://transport/geometry.gd")
var park_name := "Forest Recreation Ground"
var activities: Array[Dictionary] = []
var ball: RigidBody3D
var scoreboard: Label3D
var goals := 0
var score_delay := 0.0
var swings: Array[Node3D] = []
var phase := 0.0
var user: CharacterBody3D
var active_kind := ""
var active_index := -1
var activity_time := 0.0
var run_time := 0.0
var run_checkpoint := -1
var best_run := 0.0
var runner: CharacterBody3D
var checkpoints: Array[Vector3] = []
var run_rings: Array[MeshInstance3D] = []
var user_start := Vector3.ZERO
var heal_accumulator := 0.0

func _ready() -> void:
	add_to_group("city_activities")
	var grass := G.material(Color("6f9856"))
	var chalk := G.material(Color("f2f0d3"))
	var steel := G.material(Color("57786a"),0.5)
	var wood := G.material(Color("976d43"))
	var blue := G.material(Color("3c94b8"),0.3)
	var yellow := G.material(Color("f1c74b"),0.25)
	var parts := Node3D.new()
	add_child(parts)
	G.box(parts,Vector3(0,0.02,0),Vector3(28,0.04,32),grass)
	# Marked small-sided football pitch with physical posts and mesh netting.
	for x in [-10.0,4.0]:
		G.box(parts,Vector3(x,0.055,-5),Vector3(0.09,0.015,16),chalk)
	for z in [-13.0,3.0,-5.0]:
		G.box(parts,Vector3(-3,0.055,z),Vector3(14,0.015,0.09),chalk)
	for z in [-13.0,3.0]:
		for x in [-5.5,-0.5]:
			G.tube(parts,Vector3(x,0,z),Vector3(x,2.1,z),0.065,chalk)
			_solid(Vector3(x,1.05,z),Vector3(0.13,2.1,0.13))
		G.tube(parts,Vector3(-5.5,2.1,z),Vector3(-0.5,2.1,z),0.065,chalk)
		_solid(Vector3(-3,2.1,z),Vector3(5,0.13,0.13))
		var back: float = z+(-1.0 if z<0 else 1.0)
		for x in range(11):
			G.tube(parts,Vector3(-5.5+x*0.5,0,back),Vector3(-5.5+x*0.5,2.1,back),0.009,chalk)
		for y in range(5):
			G.tube(parts,Vector3(-5.5,y*0.5,back),Vector3(-0.5,y*0.5,back),0.009,chalk)
		_solid(Vector3(-3,1.0,back),Vector3(5,2,0.08))
	ball = RigidBody3D.new()
	ball.name = "Football"
	ball.mass = 0.43
	ball.continuous_cd = true
	ball.physics_material_override = PhysicsMaterial.new()
	ball.physics_material_override.bounce = 0.6
	ball.physics_material_override.friction = 0.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.23
	shape.shape = sphere
	ball.add_child(shape)
	G.sphere(ball,Vector3.ZERO,Vector3.ONE*0.46,chalk)
	var black := G.material(Color("263139"))
	for side in [-1.0,1.0]:
		G.sphere(ball,Vector3(side*0.212,0,0),Vector3(0.035,0.14,0.14),black)
		G.sphere(ball,Vector3(0,side*0.212,0),Vector3(0.14,0.035,0.14),black)
		G.sphere(ball,Vector3(0,0,side*0.212),Vector3(0.14,0.14,0.035),black)
	G.merge(ball)
	add_child(ball)
	reset_ball()
	scoreboard = G.label(self,park_name+"\nFOOTBALL · 0 goals",Vector3(0,3.0,-14.7),32)
	scoreboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Tubular A-frame swings with separate pivot, chains and seat.
	for z in [5.5,10.5]:
		G.tube(parts,Vector3(5,0,z),Vector3(7,3.4,z),0.08,steel)
		G.tube(parts,Vector3(9,0,z),Vector3(7,3.4,z),0.08,steel)
	G.tube(parts,Vector3(7,3.4,5.5),Vector3(7,3.4,10.5),0.09,steel)
	for z in [7.0,9.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(7,3.35,z)
		add_child(pivot)
		for side in [-1.0,1.0]:
			G.tube(pivot,Vector3(0,0,side*0.32),Vector3(0,-2.5,side*0.32),0.016,steel)
		G.box(pivot,Vector3(0,-2.5,0),Vector3(0.48,0.10,0.8),blue)
		G.merge(pivot)
		swings.append(pivot)
		activities.append({"kind":"swing","point":Vector3(7,0,z),"title":"ride swing","index":swings.size()-1})
	# Sloped metal slide, ladder rungs, rails and a safe landing mat.
	var top := Vector3(-8,2.2,10)
	var bottom := Vector3(-3,0.25,10)
	var slide := G.box(parts,(top+bottom)*0.5,Vector3(top.distance_to(bottom),0.10,0.9),blue)
	slide.rotation.z = atan2(bottom.y-top.y,bottom.x-top.x)
	for side in [-0.48,0.48]:
		G.tube(parts,top+Vector3(0,0.25,side),bottom+Vector3(0,0.25,side),0.06,yellow)
		G.tube(parts,Vector3(-9.5,0,10+side),top+Vector3(0,0.2,side),0.05,steel)
	for i in range(7):
		G.tube(parts,Vector3(-9.5+i*0.22,i*0.32,9.55),Vector3(-9.5+i*0.22,i*0.32,10.45),0.035,steel)
	G.box(parts,Vector3(-3,0.04,10),Vector3(3,0.08,2),G.material(Color("c78e60")))
	activities.append({"kind":"slide","point":Vector3(-9.5,0,10),"title":"climb and slide","index":0})
	# Real seats, backs, curved armrests and legs; useful as a healing rest.
	for z in [-5.0,8.0]:
		G.box(parts,Vector3(12,0.58,z),Vector3(0.6,0.12,2.2),wood)
		G.box(parts,Vector3(12.25,1.0,z),Vector3(0.12,0.8,2.2),wood)
		for end in [-0.85,0.85]:
			G.tube(parts,Vector3(12,0,z+end),Vector3(12,0.6,z+end),0.055,steel)
			G.tube(parts,Vector3(11.7,0.9,z+end),Vector3(12.25,0.9,z+end),0.035,steel)
		activities.append({"kind":"bench","point":Vector3(11,0,z),"title":"rest on bench","index":0})
	checkpoints = [Vector3(-12,0,-14.5),Vector3(12,0,-14.5),Vector3(12,0,14),Vector3(-12,0,14)]
	for point in checkpoints:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.55
		mesh.outer_radius = 0.68
		mesh.rings = 16
		mesh.ring_segments = 8
		ring.mesh = mesh
		ring.position = point+Vector3(0,0.09,0)
		ring.material_override = yellow
		add_child(ring)
		run_rings.append(ring)
	activities.append({"kind":"run","point":checkpoints[0],"title":"start timed park lap","index":0})
	G.label(self,"PARK LAP\nE to start • run through gold rings",checkpoints[0]+Vector3(0,1.8,0),21).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	G.merge(parts)

func _solid(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = pos
	body.add_child(shape)
	add_child(body)

func reset_ball() -> void:
	ball.position = Vector3(-3,0.6,-5)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO

func nearest(person: Node3D) -> Dictionary:
	if person.global_position.distance_to(ball.global_position)<2.0:
		return {"kind":"football","title":"kick football","index":0,"point":ball.position}
	var best := {}
	var distance := 2.0
	for item in activities:
		var gap: float = person.global_position.distance_to(to_global(item.point))
		if gap<distance:
			distance = gap
			best = item
	return best

func use(person: CharacterBody3D) -> bool:
	var item := nearest(person)
	if item.is_empty() or person.dead or person.driving or person.transitioning or person.resting!="" or is_instance_valid(user):
		return false
	if item.kind=="football":
		var direction := ball.global_position-person.global_position
		direction.y = 0
		if direction.length()<0.01:
			direction = Vector3.FORWARD
		ball.apply_central_impulse(direction.normalized()*4.8+Vector3.UP*1.5)
		person._notify("Football kicked — aim between the posts")
		return true
	if item.kind=="run":
		runner = person
		run_checkpoint = 1
		run_time = 0
		person._notify("Park lap started — follow the gold rings clockwise")
		return true
	user = person
	user_start = person.global_position
	person.park_activity = self
	person.velocity = Vector3.ZERO
	person.collider.set_deferred("disabled",true)
	active_kind = item.kind
	active_index = item.index
	activity_time = 0
	heal_accumulator = 0
	person._play_clip("seated")
	person._notify("G / E to finish")
	return true

func release(person: CharacterBody3D) -> void:
	if person != user:
		return
	person.global_position = to_global(Vector3(-2,0.2,10)) if active_kind=="slide" else user_start+Vector3(0,0.1,0)
	person.visual.rotation = Vector3.ZERO
	person.velocity = Vector3.ZERO
	person.collider.set_deferred("disabled",false)
	person.park_activity = null
	person._play_clip("idle")
	user = null
	active_kind = ""

func tick_user(person: CharacterBody3D, delta: float) -> void:
	activity_time += delta
	person.pivot.rotation = Vector3(person.pitch,person.yaw,0)
	person.prompt.text = park_name+" • "+active_kind.capitalize()+"\nE / G: finish"
	if Input.is_action_just_pressed("cancel_action") or Input.is_action_just_pressed("interact"):
		release(person)
		return
	if active_kind=="swing":
		person.global_position = swings[active_index].to_global(Vector3(0,-2.4,0))
		person.visual.rotation.z = swings[active_index].rotation.z
	elif active_kind=="slide":
		var t := clampf((activity_time-1.0)/2.0,0,1)
		person.global_position = to_global(Vector3(-8,2.3,10).lerp(Vector3(-3,0.4,10),t))
		if activity_time>3.1:
			release(person)
	elif active_kind=="bench":
		var local_seat := to_local(user_start)
		person.global_position = to_global(Vector3(11.95,0.08,local_seat.z))
		person.visual.rotation.y = PI/2
		heal_accumulator += delta*2.0
		if heal_accumulator>=1:
			person.health = mini(100,person.health+int(heal_accumulator))
			heal_accumulator -= int(heal_accumulator)

func _physics_process(delta: float) -> void:
	phase += delta
	for i in range(swings.size()):
		swings[i].rotation.z = sin(phase*1.8+i)* (0.48 if active_kind=="swing" and active_index==i else 0.08)
	score_delay = maxf(0,score_delay-delta)
	if score_delay<=0 and absf(ball.position.x+3)<2.5 and ball.position.y<2.1 and (ball.position.z< -13 or ball.position.z>3):
		goals += 1
		scoreboard.text = park_name+"\nGOAL! • "+str(goals)+" scored"
		score_delay = 2.0
		reset_ball()
	if ball.position.y< -5 or ball.position.length()>40:
		reset_ball()
	if is_instance_valid(runner) and run_checkpoint>=0:
		run_time += delta
		if runner.global_position.distance_to(to_global(checkpoints[run_checkpoint]))<1.8:
			run_checkpoint = (run_checkpoint+1)%checkpoints.size()
			if run_checkpoint==1:
				best_run = run_time if best_run==0 else minf(best_run,run_time)
				runner._notify("Lap finished: %.1fs • best %.1fs" % [run_time,best_run])
				scoreboard.text = park_name+"\nPARK LAP • best %.1fs" % best_run
				run_checkpoint = -1
				runner = null
