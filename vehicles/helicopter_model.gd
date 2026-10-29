extends RefCounted
# Original driverless "Aurora Sky" helicopter and helipad. Nothing is imported: every part is
# generated from simple shapes, in the same gold and dark livery as the Aurora cab.
# Local axes: +Z is forward, +X is the boarding side, the origin is on the ground between the skids.
const G = preload("res://transport/geometry.gd")
const ROTOR_RADIUS := 4.4

static func make(number: int) -> Node3D:
	var model := Node3D.new()
	var gold := G.material(Color("c6aa69"),0.75)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark := G.material(Color("17232c"),0.35)
	var glass := G.material(Color(0.25,0.46,0.57,0.26),0.2)
	var light := G.material(Color("d4f6ff"),0.0,true)
	var red := G.material(Color("ff504a"),0.0,true)
	var screen := G.material(Color("19bbb0"),0.0,true)
	# Skids and struts.
	for side in [-1.0,1.0]:
		G.tube(model,Vector3(side*1.15,0.12,-2.0),Vector3(side*1.15,0.12,2.1),0.06,dark)
		G.tube(model,Vector3(side*1.15,0.12,2.1),Vector3(side*1.15,0.4,2.45),0.06,dark)
		for z in [0.95,-0.7]:
			G.tube(model,Vector3(side*1.15,0.14,z),Vector3(side*0.88,0.78,z),0.05,dark)
	# Floor, lower hull and engine housing. The cabin above them is open glass so riders stay visible.
	G.box(model,Vector3(0,0.68,0.35),Vector3(1.7,0.1,2.5),dark)
	G.sphere(model,Vector3(0,0.66,0.25),Vector3(2.0,0.78,3.6),gold)
	G.sphere(model,Vector3(0,2.5,-0.45),Vector3(1.75,0.95,2.8),gold)
	G.sphere(model,Vector3(0,1.72,-1.05),Vector3(1.0,0.8,1.6),gold)
	# Frame pillars and roof rails around the glass bubble.
	for side in [-1.0,1.0]:
		G.tube(model,Vector3(side*0.82,0.85,1.5),Vector3(side*0.78,2.18,0.7),0.045,gold)
		G.tube(model,Vector3(side*0.9,0.85,-0.85),Vector3(side*0.86,2.2,-0.8),0.045,gold)
		G.tube(model,Vector3(side*0.78,2.18,0.7),Vector3(side*0.86,2.2,-0.8),0.04,gold)
		# Two independent passenger seats, no pilot seat and no controls to fly with.
		G.box(model,Vector3(side*0.46,0.88,-0.45),Vector3(0.62,0.16,0.7),dark)
		var back := G.box(model,Vector3(side*0.46,1.26,-0.85),Vector3(0.63,0.7,0.15),dark)
		back.rotation.x = -0.12
		G.box(model,Vector3(side*0.46,1.68,-0.89),Vector3(0.38,0.2,0.14),dark)
	G.sphere(model,Vector3(0,1.55,0.5),Vector3(2.0,1.7,3.2),glass)
	G.box(model,Vector3(0,1.18,1.45),Vector3(1.5,0.3,0.35),dark)
	G.box(model,Vector3(0,1.36,1.38),Vector3(0.9,0.02,0.2),screen)
	G.box(model,Vector3(0,0.9,2.02),Vector3(1.1,0.05,0.04),light)
	# Tail boom, fin and stabiliser.
	G.tube(model,Vector3(0,1.78,-1.4),Vector3(0,1.95,-5.6),0.17,gold)
	G.box(model,Vector3(0,2.5,-5.35),Vector3(0.1,1.3,0.95),gold)
	G.box(model,Vector3(0,2.02,-5.0),Vector3(1.7,0.07,0.5),gold)
	G.sphere(model,Vector3(0,3.15,-5.35),Vector3(0.18,0.18,0.18),red)
	G.sphere(model,Vector3(0.95,2.0,-5.0),Vector3(0.12,0.12,0.12),G.material(Color("19bb48"),0.0,true))
	G.sphere(model,Vector3(-0.95,2.0,-5.0),Vector3(0.12,0.12,0.12),red)
	# Mast and hub.
	G.tube(model,Vector3(0,3.0,-0.3),Vector3(0,3.35,-0.3),0.13,dark)
	G.sphere(model,Vector3(0,3.38,-0.3),Vector3(0.5,0.28,0.5),dark)
	G.merge(model)
	# Main rotor: four blades plus a faint disc that appears when it is turning fast.
	var rotor := Node3D.new()
	rotor.position = Vector3(0,3.5,-0.3)
	model.add_child(rotor)
	var blade := G.material(Color("20272d"),0.2)
	G.box(rotor,Vector3.ZERO,Vector3(ROTOR_RADIUS*2.0,0.045,0.3),blade)
	G.box(rotor,Vector3.ZERO,Vector3(0.3,0.045,ROTOR_RADIUS*2.0),blade)
	G.merge(rotor)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = ROTOR_RADIUS
	disc_mesh.bottom_radius = ROTOR_RADIUS
	disc_mesh.height = 0.01
	disc_mesh.radial_segments = 32
	disc.mesh = disc_mesh
	var disc_material := G.material(Color(0.85,0.93,1.0,0.0))
	disc.material_override = disc_material
	disc.position = Vector3(0,3.5,-0.3)
	disc.visible = false
	model.add_child(disc)
	# Tail rotor turns about the sideways axis.
	var tail := Node3D.new()
	tail.position = Vector3(0.24,2.2,-5.55)
	model.add_child(tail)
	G.box(tail,Vector3.ZERO,Vector3(0.04,1.5,0.12),blade)
	G.box(tail,Vector3.ZERO,Vector3(0.04,0.12,1.5),blade)
	G.merge(tail)
	# Doors swing outward from their front edge and carry a small identity display.
	var doors: Array[Node3D] = []
	var displays: Array[Label3D] = []
	for side in [-1.0,1.0]:
		var door := Node3D.new()
		door.position = Vector3(side*1.0,0.82,0.95)
		door.set_meta("side",side)
		model.add_child(door)
		G.box(door,Vector3(0,0.62,-0.75),Vector3(0.05,1.05,1.5),glass)
		G.box(door,Vector3(0,0.1,-0.75),Vector3(0.07,0.12,1.5),gold)
		G.box(door,Vector3(0,1.15,-0.75),Vector3(0.07,0.1,1.5),gold)
		G.box(door,Vector3(0,0.62,-1.48),Vector3(0.07,1.05,0.06),gold)
		G.merge(door)
		var brand := G.label(door,"AURORA SKY",Vector3(side*0.06,0.28,-0.75),14)
		brand.rotation.y = side*PI/2
		brand.pixel_size = 0.005
		var display := G.label(door,"AS-%03d • AVAILABLE" % number,Vector3(side*0.06,0.1,-0.75),12)
		display.rotation.y = side*PI/2
		display.pixel_size = 0.004
		displays.append(display)
		doors.append(door)
	var label := G.label(model,"AS-%03d\nAURORA SKY SELF FLY" % number,Vector3(0,4.5,-0.3),22)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 160.0
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.9
	ring.rings = 24
	ring.ring_segments = 8
	marker.mesh = ring
	marker.material_override = G.material(Color("19bb48"),0.0,true)
	marker.position = Vector3(3.0,0.04,0.2)
	marker.scale.y = 0.08
	marker.visible = false
	model.add_child(marker)
	model.set_meta("rotor",rotor)
	model.set_meta("tail_rotor",tail)
	model.set_meta("disc",disc)
	model.set_meta("doors",doors)
	model.set_meta("displays",displays)
	model.set_meta("label",label)
	model.set_meta("marker",marker)
	return model

# A round helipad: navy surface, gold ring, white H, edge lights and an information sign.
static func make_pad(title: String) -> Node3D:
	var pad := Node3D.new()
	var navy := G.material(Color("1d2b3a"),0.1)
	var gold := G.material(Color("c6aa69"),0.5)
	var white := G.material(Color("eef2f0"))
	var edge := G.material(Color("19bbb0"),0.0,true)
	var surface := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 5.4
	disc.bottom_radius = 5.4
	disc.height = 0.12
	disc.radial_segments = 40
	surface.mesh = disc
	surface.material_override = navy
	surface.position = Vector3(0,0.06,0)
	pad.add_child(surface)
	for i in range(32):
		var angle := TAU*float(i)/32.0
		var segment := G.box(pad,Vector3(cos(angle)*4.85,0.125,sin(angle)*4.85),Vector3(0.28,0.02,1.0),gold)
		segment.rotation.y = -angle
	for side in [-1.0,1.0]:
		G.box(pad,Vector3(side*0.95,0.13,0),Vector3(0.45,0.02,2.7),white)
	G.box(pad,Vector3(0,0.13,0),Vector3(1.45,0.02,0.45),white)
	for i in range(12):
		var angle := TAU*float(i)/12.0+0.13
		G.box(pad,Vector3(cos(angle)*5.15,0.14,sin(angle)*5.15),Vector3(0.22,0.06,0.22),edge)
	G.tube(pad,Vector3(6.0,0,0),Vector3(6.0,3.0,0),0.06,G.material(Color("17232c"),0.35))
	G.box(pad,Vector3(6.0,2.75,0),Vector3(0.8,0.65,0.1),gold)
	G.merge(pad)
	var sign := G.label(pad,title+"\nHELIPAD · E: walk-up flight",Vector3(6.0,3.45,0),20)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return pad
