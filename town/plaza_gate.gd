extends Node3D
# A physical sliding gate. Its approach sensor holds both leaves open for any
# moving body, including people, vehicles and the robots added in a later phase.
const G=preload("res://transport/geometry.gd")
const HOLD_SECONDS:=2.5
var leaves:Array[AnimatableBody3D]=[]
var sensor:Area3D
var occupants:Dictionary={}
var openness:=0.0
var hold:=0.0
var status:Label3D
var motor:AudioStreamPlayer3D

func _ready() -> void:
	var white:=G.material(Color("d7e5e0"),.35)
	var steel:=G.material(Color("304d58"),.6)
	var aqua:=G.material(Color("70dfcb"),.1,true)
	var glass:=G.material(Color(.22,.55,.61,.48),.15)
	var frame:=Node3D.new();add_child(frame)
	for side in [-1.0,1.0]:
		# Splayed supports and a shallow arched crown leave the sky open.
		G.tube(frame,Vector3(side*6.8,0,0),Vector3(side*5,4.4,0),.25,white)
		G.tube(frame,Vector3(side*5,4.4,0),Vector3(side*3.7,5.2,0),.25,white)
		G.box(frame,Vector3(side*4.35,2.15,0),Vector3(.3,4.3,.65),steel)
		G.box(frame,Vector3(side*4.35,2.7,-.36),Vector3(.12,2.4,.04),aqua)
		_solid(frame,Vector3(side*4.55,2,0),Vector3(.5,4,.75))
		G.tube(frame,Vector3(side*4.8,1.3,0),Vector3(side*8.1,1.3,0),.055,steel)
		G.tube(frame,Vector3(side*4.8,.45,0),Vector3(side*8.1,.45,0),.035,steel)
		_solid(frame,Vector3(side*6.45,.7,0),Vector3(3.3,1.4,.18))
	G.tube(frame,Vector3(-3.7,5.2,0),Vector3(3.7,5.2,0),.25,white)
	G.merge(frame)
	for side in [-1.0,1.0]:
		var leaf:=AnimatableBody3D.new();leaf.name="LeftLeaf" if side<0 else "RightLeaf"
		leaf.sync_to_physics=false;leaf.collision_layer=1;leaf.collision_mask=0
		add_child(leaf);leaves.append(leaf)
		G.box(leaf,Vector3(0,1.9,0),Vector3(3.97,3.8,.14),glass)
		for x in [-1.95,1.95]:G.box(leaf,Vector3(x,1.9,0),Vector3(.1,3.8,.22),white)
		for y in [.12,1.25,3.72]:G.box(leaf,Vector3(0,y,0),Vector3(4,.1,.22),white)
		G.box(leaf,Vector3(0,2.6,-.09),Vector3(3.5,.08,.035),aqua)
		var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new()
		shape.size=Vector3(4,3.8,.24);collision.shape=shape;collision.position.y=1.9;leaf.add_child(collision)
		G.merge(leaf)
	_move_leaves()
	sensor=Area3D.new();sensor.name="ApproachSensor";sensor.collision_layer=0;sensor.collision_mask=3
	var trigger:=CollisionShape3D.new();var volume:=BoxShape3D.new()
	volume.size=Vector3(9,4.5,12);trigger.shape=volume;trigger.position.y=2
	sensor.add_child(trigger);add_child(sensor)
	sensor.body_entered.connect(_arrive);sensor.body_exited.connect(_leave)
	status=G.label(self,"AUTOMATIC GATE",Vector3(0,4.55,-.4),28)
	status.rotation.y=PI;status.pixel_size=.012;status.visibility_range_end=48
	motor=AudioStreamPlayer3D.new();motor.stream=preload("res://simulation/audio/door.wav")
	motor.volume_db=-16;motor.max_distance=24;motor.unit_size=4;add_child(motor)

func _solid(parent:Node3D,point:Vector3,size:Vector3) -> void:
	var body:=StaticBody3D.new();parent.add_child(body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=size;collision.shape=shape;collision.position=point;body.add_child(collision)

func _arrive(body:Node3D) -> void:
	# Driverless vehicle colliders are AnimatableBody3D (a StaticBody3D subtype).
	# Layer 2 admits those vehicles while ignoring the ground and our own leaves.
	if body is PhysicsBody3D and (not body is StaticBody3D or (body.collision_layer & 2)!=0):
		occupants[body.get_instance_id()]=weakref(body)
		if hold==0:motor.play()
		hold=HOLD_SECONDS
		set_physics_process(true)

func _leave(body:Node3D) -> void:
	occupants.erase(body.get_instance_id())

func _physics_process(delta:float) -> void:
	for id in occupants.keys():
		var body=occupants[id].get_ref()
		if not is_instance_valid(body) or not body.is_inside_tree():occupants.erase(id)
	if not occupants.is_empty():hold=HOLD_SECONDS
	else:hold=maxf(0,hold-delta)
	var target:=1.0 if hold>0 else 0.0
	var previous:=openness
	if target==0 and previous==1:motor.play()
	openness=move_toward(openness,target,delta*(2.1 if target>openness else .7))
	if openness!=previous:
		_move_leaves()
		status.text="WELCOME • WALK THROUGH" if target>0 else "AUTOMATIC GATE"
	if openness==0 and hold==0:set_physics_process(false)

func _move_leaves() -> void:
	for i in range(leaves.size()):leaves[i].position.x=(-1.0 if i==0 else 1.0)*(2+openness*4.15)
