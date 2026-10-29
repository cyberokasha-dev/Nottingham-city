extends Node3D
# Surface-only civic space. Small static batches form the ground and perimeter;
# only nearby landscape/dock/workshop details are created, one per update.
const G=preload("res://transport/geometry.gd")
const GATE=preload("res://town/plaza_gate.gd")
const DETAIL_RADIUS:=62.0
const DETAIL_RELEASE:=82.0
const DIRECTORY:=Vector3(-9,0,-43)
var game:Node3D
var gates:Array[Node3D]=[]
var details:Array[Dictionary]=[]
var clock:=0.0
var floor_material:Material
var chalk:Material
var dark:Material
var mint:Material
var leaf:Material
var soil:Material
var wood:Material

func _ready() -> void:
	add_to_group("city_activities")
	floor_material=G.material(Color("b7c7c7"))
	chalk=G.material(Color("e9e8d9"),.15);dark=G.material(Color("344f5c"),.35)
	mint=G.material(Color("56bcae"));leaf=G.material(Color("52816a"))
	soil=G.material(Color("59665b"));wood=G.material(Color("a77c55"))
	_build_outline()
	for z in [-55.0,55.0]:
		var gate:=GATE.new();gate.position.z=z
		if z>0:gate.rotation.y=PI
		add_child(gate);gates.append(gate)
	_sign(self,"FUTURE WORKS\nROBOTICS PLAZA",Vector3(0,6.8,-55),48,PI,.018)
	_sign(self,"ROBOTICS PLAZA",Vector3(0,6.2,55),36,0,.018)
	_directory()
	# Empty robot docks are reserved, with no background robot simulation yet.
	details=[
		{"kind":"dock","point":Vector3(-43,0,-19),"title":"ROBOT 01 • DOCK","robot":true},
		{"kind":"dock","point":Vector3(-43,0,9),"title":"ROBOT 02 • DOCK"},
		{"kind":"workshop","point":Vector3(39,0,29),"title":"WORKSHOP • FUTURE PHASE"},
		{"kind":"court","point":Vector3(19,0,-15),"title":"DEMONSTRATION COURT"},
		{"kind":"garden","point":Vector3(-57,0,-39),"title":""},
		{"kind":"garden","point":Vector3(55,0,-38),"title":""},
		{"kind":"garden","point":Vector3(58,0,-5),"title":""},
		{"kind":"garden","point":Vector3(-56,0,39),"title":""},
		{"kind":"seating","point":Vector3(-23,0,35),"title":""},
		{"kind":"seating","point":Vector3(29,0,-42),"title":""}
	]
	for detail in details:detail.node=null

func _build_outline() -> void:
	var parts:=Node3D.new();parts.name="PlazaSurface";add_child(parts)
	# The ordinary city ground remains the walkable surface: no platform, shaft or steps.
	# Adjacent paving regions share one height instead of overlapping thin planes.
	for x in [-40.0,40.0]:
		for z in [-29.0,29.0]:G.box(parts,Vector3(x,-.09,z),Vector3(70,.02,52),floor_material)
		G.box(parts,Vector3(x,-.09,0),Vector3(70,.02,6),chalk)
	G.box(parts,Vector3(0,-.09,10),Vector3(10,.02,190),chalk)
	for x in [-6.0,6.0]:G.box(parts,Vector3(x,-.06,10),Vector3(.22,.018,190),mint)
	for x in [-72.0,72.0]:
		_rail(parts,Vector3(x,0,-55),Vector3(x,0,55))
		_solid(parts,Vector3(x,.68,0),Vector3(.18,1.36,110))
	for z in [-55.0,55.0]:
		for side in [-1.0,1.0]:
			_rail(parts,Vector3(side*8,0,z),Vector3(side*72,0,z))
			_solid(parts,Vector3(side*40,.68,z),Vector3(64,1.36,.18))
	G.merge(parts)

func _rail(parent:Node3D,a:Vector3,b:Vector3) -> void:
	G.tube(parent,a+Vector3.UP*1.28,b+Vector3.UP*1.28,.055,dark)
	G.tube(parent,a+Vector3.UP*.45,b+Vector3.UP*.45,.035,dark)
	var sections:=ceili(a.distance_to(b)/8)
	for i in range(sections+1):
		var p:=a.lerp(b,float(i)/sections)
		G.tube(parent,p,p+Vector3.UP*1.28,.065,dark)

func _sign(parent:Node3D,text:String,point:Vector3,size:int,angle:=0.0,pixels:=.012) -> Label3D:
	var label:=G.label(parent,text,point,size)
	label.rotation.y=angle;label.pixel_size=pixels;label.visibility_range_end=95
	return label

func _directory() -> void:
	var parts:=Node3D.new();parts.position=DIRECTORY;parts.name="PlazaDirectory";add_child(parts)
	G.box(parts,Vector3(0,1.1,0),Vector3(2,2.2,.35),dark)
	G.box(parts,Vector3(0,1.3,-.2),Vector3(1.8,1.55,.04),mint)
	_sign(parts,"PLAZA GUIDE\nE / △ to read",Vector3(0,2.7,-.25),24,PI,.01)
	_solid(parts,Vector3(0,1.1,0),Vector3(2,2.2,.4));G.merge(parts)

func nearest(person:Node3D) -> Dictionary:
	if to_local(person.global_position).distance_to(DIRECTORY+Vector3(0,0,-1.5))<3:
		return {"title":"read Robotics Plaza information"}
	return {}

func use(person:Node3D) -> void:
	if nearest(person).is_empty():return
	person._notify("Robotics Plaza • open demonstration court, two reserved robot docks, seating gardens. Vehicle and machinery workshop coming in a later phase.")

func _process(delta:float) -> void:
	clock+=delta
	if clock<.16 or not is_instance_valid(game) or not is_instance_valid(game.player):return
	clock=0
	var point:=to_local(game.player.global_position)
	var built:=false
	for detail in details:
		var distance:float=Vector2(point.x-detail.point.x,point.z-detail.point.z).length_squared()
		if distance>DETAIL_RELEASE*DETAIL_RELEASE and is_instance_valid(detail.node):
			detail.node.queue_free();detail.node=null
		elif distance<DETAIL_RADIUS*DETAIL_RADIUS and not is_instance_valid(detail.node) and not built:
			_build_detail(detail);built=true

func _build_detail(detail:Dictionary) -> void:
	var node:=Node3D.new();node.position=detail.point;node.name=detail.kind;add_child(node);detail.node=node
	var parts:=Node3D.new();node.add_child(parts)
	match detail.kind:
		"dock":_dock(parts)
		"workshop":_workshop(parts)
		"court":_court(parts)
		"garden":_garden(parts)
		"seating":_seating(parts)
	if not detail.title.is_empty():
		var sign_point:=Vector3(0,.12,9) if detail.kind=="dock" else Vector3(0,.12,16)
		var label:=_sign(node,detail.title,sign_point,32,0,.014)
		label.rotation.x=-PI/2
	G.merge(parts)
	if detail.kind=="dock" and bool(detail.get("robot",false)):
		var robot_scene := load("res://town/vbot.glb") as PackedScene
		if robot_scene == null:
			push_error("V-Bot model could not be loaded: res://town/vbot.glb")
		else:
			var robot := robot_scene.instantiate() as Node3D
			robot.name="VBotModel"
			robot.position=Vector3(0,0.15,0.5)
			robot.scale=Vector3.ONE*1.25
			node.add_child(robot)


func _disc(parent:Node3D,point:Vector3,radius:float,height:float,material:Material) -> void:
	var visual:=MeshInstance3D.new();var mesh:=CylinderMesh.new()
	mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=40
	visual.mesh=mesh;visual.material_override=material;visual.position=point;parent.add_child(visual)

func _ring(parent:Node3D,point:Vector3,radius:float,width:float,material:Material) -> void:
	var visual:=MeshInstance3D.new();var mesh:=TorusMesh.new()
	mesh.inner_radius=radius-width;mesh.outer_radius=radius;mesh.rings=48;mesh.ring_segments=6
	visual.mesh=mesh;visual.material_override=material;visual.position=point;visual.scale.y=.15;parent.add_child(visual)

func _dock(parts:Node3D) -> void:
	_disc(parts,Vector3(0,-.045,0),7.5,.025,dark)
	_ring(parts,Vector3(0,.01,0),6.8,.25,mint)
	for x in [-3.0,3.0]:
		G.tube(parts,Vector3(x,0,-4),Vector3(x,2.6,-4),.12,chalk)
	G.tube(parts,Vector3(-3,2.6,-4),Vector3(3,2.6,-4),.12,chalk)
	G.box(parts,Vector3(0,1,-4.2),Vector3(1.2,2,.65),dark)
	G.box(parts,Vector3(0,1.4,-3.85),Vector3(.75,.6,.05),mint)
	_solid(parts,Vector3(0,1,-4.2),Vector3(1.2,2,.65))
	for x in [-1.7,1.7]:G.box(parts,Vector3(x,0,0),Vector3(.1,.025,3),chalk)

func _workshop(parts:Node3D) -> void:
	G.box(parts,Vector3(0,-.045,0),Vector3(46,.03,32),dark)
	for x in [-22.0,22.0]:G.box(parts,Vector3(x,-.018,0),Vector3(.18,.025,31),mint)
	for z in [-15.0,15.0]:G.box(parts,Vector3(0,-.018,z),Vector3(44,.025,.18),mint)
	for x in [-14.0,0.0,14.0]:
		for side in [-1.0,1.0]:G.box(parts,Vector3(x+side*5,.01,0),Vector3(.1,.025,20),chalk)
		G.box(parts,Vector3(x,.01,-10),Vector3(10,.025,.1),chalk)
	_sign(parts,"VEHICLE & MACHINERY WORKSHOP\nReserved for a later phase",Vector3(0,2.2,15.8),30,0,.017)
	for x in [-22.0,22.0]:
		G.tube(parts,Vector3(x,0,15),Vector3(x,3,15),.1,chalk)

func _court(parts:Node3D) -> void:
	_disc(parts,Vector3(0,-.045,0),21,.025,G.material(Color("88aeb1")))
	for radius in [20.0,16.0,5.0]:_ring(parts,Vector3(0,.01,0),radius,.25,chalk)
	# An offset sculptural helix leaves the central promenade and court walkable.
	for strand in range(2):
		for i in range(24):
			var a:=float(i)*TAU/24+strand*PI;var b:=float(i+1)*TAU/24+strand*PI
			G.tube(parts,Vector3(cos(a)*1.3,i*.19,sin(a)*1.3),Vector3(cos(b)*1.3,(i+1)*.19,sin(b)*1.3),.12,chalk if strand==0 else mint)
	_disc(parts,Vector3(0,.15,0),2,.3,dark)
	_round_solid(parts,Vector3(0,2.2,0),1.6,4.4)

func _garden(parts:Node3D) -> void:
	_disc(parts,Vector3(0,.25,0),7,.5,chalk)
	_disc(parts,Vector3(0,.51,0),6.65,.025,soil)
	_round_solid(parts,Vector3(0,.25,0),7,.5)
	for i in range(5):
		var angle:=float(i)*TAU/5
		var p:=Vector3(cos(angle)*3.4,.5,sin(angle)*3.4)
		G.tube(parts,p,p+Vector3(0,3.4,0),.18,wood)
		G.sphere(parts,p+Vector3(0,4,0),Vector3(3.6,4.3,3.4),leaf)
	for i in range(9):
		var angle:=float(i)*TAU/9
		G.sphere(parts,Vector3(cos(angle)*5.5,.95,sin(angle)*5.5),Vector3(1.4,.9,1.4),mint)

func _seating(parts:Node3D) -> void:
	# Two slender curved canopy ribs shade proper seats without enclosing the plaza.
	for z in [-2.5,2.5]:
		var last:=Vector3(-6,0,z)
		for i in range(1,13):
			var a:=PI-float(i)*PI/12
			var p:=Vector3(cos(a)*6,sin(a)*4.8,z)
			G.tube(parts,last,p,.13,dark);last=p
	for z in [-2.3,-1.2,0,1.2,2.3]:G.tube(parts,Vector3(-3,4.1,z),Vector3(3,4.1,z),.1,chalk)
	for x in [-3.0,3.0]:
		G.box(parts,Vector3(x,.55,0),Vector3(3,.13,.75),wood)
		G.box(parts,Vector3(x,1,.34),Vector3(3,.8,.12),wood)
		for end in [-1.15,1.15]:G.tube(parts,Vector3(x+end,0,0),Vector3(x+end,.5,0),.06,dark)
		_solid(parts,Vector3(x,.65,.1),Vector3(3,1.2,.85))

func _solid(parent:Node3D,point:Vector3,size:Vector3) -> void:
	var body:=StaticBody3D.new();parent.add_child(body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new()
	shape.size=size;collision.shape=shape;collision.position=point;body.add_child(collision)

func _round_solid(parent:Node3D,point:Vector3,radius:float,height:float) -> void:
	var body:=StaticBody3D.new();parent.add_child(body)
	var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new()
	shape.radius=radius;shape.height=height;collision.shape=shape;collision.position=point;body.add_child(collision)
