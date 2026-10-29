extends Node3D
# Named civic plots are streamed independently of homes and the resident simulation.
const W=preload("res://town/world_layout.gd")
const G=preload("res://transport/geometry.gd")
var city:Node3D
var sites:Array[Dictionary]=[]
var clock:=0.0
var gate:=0
var lap_started:=-1.0
var best_lap:=INF
func _ready() -> void:
	sites=W.place_sites().duplicate(true)
	for site in sites: site.node=null
func _process(delta:float) -> void:
	clock+=delta
	if clock<.2: return
	clock=0
	var game:=city.get_parent().get_parent()
	if not is_instance_valid(game.player): return
	var p:Vector3=game.player.global_position
	var built:=false
	for site in sites:
		var distance:=p.distance_squared_to(site.point)
		if distance<190*190 and not is_instance_valid(site.node) and not built:
			_build(site);built=true
		elif distance>270*270 and is_instance_valid(site.node):
			site.node.queue_free();site.node=null
	# A driveable timed circuit: cross the start and then all eight checkpoints in order.
	if not game.player.driving:
		gate=0;lap_started=-1;return
	var target:=Vector3(-380,W.LEVEL,340)+_race_point(gate)
	if p.distance_to(target)>12: return
	if gate==0:
		if lap_started>=0:
			var seconds:=Time.get_ticks_msec()/1000.0-lap_started
			best_lap=minf(best_lap,seconds)
			game.player._notify("Circuit lap %.1f s • best %.1f s" % [seconds,best_lap])
		else: game.player._notify("Racing circuit • follow the numbered checkpoints")
		lap_started=Time.get_ticks_msec()/1000.0
	gate=(gate+1)%8
func _race_point(index:int) -> Vector3:
	var angle:=float(index)*TAU/8
	return Vector3(cos(angle)*39,0,sin(angle)*69)
func _build(site:Dictionary) -> void:
	if site.kind=="robotics":
		var plaza:=preload("res://town/robotics_plaza.gd").new()
		plaza.name=site.id;plaza.position=site.point;plaza.game=city.get_parent().get_parent()
		add_child(plaza);site.node=plaza
		return
	var node:=Node3D.new();node.name=site.id;node.position=site.point
	add_child(node);site.node=node
	var paving:=G.material(Color("a3aaa1"));var paint:=G.material(Color("e8e3cc"))
	if site.kind=="race":
		var tarmac:=G.material(Color("343d44"))
		var red:=G.material(Color("b8423d"))
		for i in range(64):
			var a:=Vector3(cos(i*TAU/64)*39,.02,sin(i*TAU/64)*69)
			var b:=Vector3(cos((i+1)*TAU/64)*39,.02,sin((i+1)*TAU/64)*69)
			var road:=G.box(node,(a+b)*.5,Vector3(9,.04,a.distance_to(b)+.4),tarmac)
			road.rotation.y=atan2((b-a).x,(b-a).z)
			for scale_factor in [.86,1.14]:
				var kerb:=G.box(node,(a+b)*.5*scale_factor+Vector3(0,.04,0),Vector3(.5,.12,a.distance_to(b)*scale_factor+.2),paint if i%2==0 else red)
				kerb.rotation.y=road.rotation.y
		for i in range(8):
			var marker:=G.label(node,str(i+1),_race_point(i)+Vector3(0,.08,0),42)
			marker.rotation.x=-PI/2
		G.label(node,"COUNCIL RACING GROUND\nDrive through checkpoint 1 to start a timed lap",Vector3(-12,3,-9),25)
	else:
		var size:=Vector3(54,.06,42) if site.kind=="sales" else Vector3(48,.06,40)
		G.box(node,Vector3(0,-.06,0),size,paving)
		if site.kind=="reserved":
			G.box(node,Vector3(0,.025,0),Vector3(27,.03,22),G.material(Color("a4936e")))
			G.label(node,site.name+"\nReserved retail site",Vector3(0,2,4),26)
		elif site.kind=="sales":
			var bus:=preload("res://transport/bus_model.gd").new()
			bus.route_number="RENT";bus.livery=Color("348a86");node.add_child(bus);bus.position=Vector3(-20,0,3)
			_rental_display(bus,"bus_private",Vector3(2.5,4.2,10.2),Vector3(0,2.3,0),"City bus")
			var aurora:=preload("res://vehicles/aurora_model.gd").make(0)
			node.add_child(aurora);aurora.position=Vector3(0,0,3)
			_rental_display(aurora,"car",Vector3(1.9,1.65,4.3),Vector3(0,.95,0),"Aurora")
			var helicopter:=preload("res://vehicles/helicopter_model.gd").make(0)
			node.add_child(helicopter);helicopter.position=Vector3(20,0,3)
			_rental_display(helicopter,"Helicopter",Vector3(1.9,1.7,3.6),Vector3(0,1.15,0),"Helicopter")
			G.label(node,"COUNCIL VEHICLE RENTALS\nCars • Buses • Helicopters\nPhone: Rents or Jobs",Vector3(0,4,14),30)
		else:
			var brick:=G.material(Color("ae8970"));var glass:=G.material(Color("426c78"))
			G.box(node,Vector3(0,2.8,-4),Vector3(28,5.6,16),brick)
			G.box(node,Vector3(0,5.8,-4),Vector3(29,.4,17),G.material(Color("43525e")))
			for x in [-10,-5,5,10]: G.box(node,Vector3(x,2,4.1),Vector3(4,2.9,.1),glass)
			G.box(node,Vector3(0,1.5,4.1),Vector3(2.8,3,.1),glass)
			G.label(node,site.name.to_upper(),Vector3(0,4.8,4.2),32)
			var body:=StaticBody3D.new();node.add_child(body)
			var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(28,5.6,16)
			collision.shape=box;collision.position=Vector3(0,2.8,-4);body.add_child(collision)
		for x in [-18,-10,0,10,18]: G.box(node,Vector3(x,.015,14),Vector3(.12,.025,7),paint)
	G.merge(node)

func _rental_display(model:Node3D,kind:String,size:Vector3,centre:Vector3,title:String) -> void:
	model.add_to_group("rental_displays");model.set_meta("rental_kind",kind)
	var body:=StaticBody3D.new();body.name="SolidRentalDisplay";body.collision_layer=2;model.add_child(body)
	var collision:=CollisionShape3D.new();collision.name="CollisionShape3D"
	var box:=BoxShape3D.new();box.size=size;collision.shape=box;collision.position=centre;body.add_child(collision)
	var sign:=G.label(model,title+" • E to rent",Vector3(0,size.y+1,0),28)
	sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.visibility_range_end=45
