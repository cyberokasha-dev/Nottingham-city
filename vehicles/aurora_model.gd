extends RefCounted
# Original open cabin: doors are moving geometry, rather than panels over a sealed car.
const G = preload("res://transport/geometry.gd")
static func make(number: int) -> Node3D:
	var model := Node3D.new()
	var gold := G.material(Color("c6aa69"),0.75)
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	var dark := G.material(Color("17232c"),0.35)
	var glass := G.material(Color(0.25,0.46,0.57,0.24),0.2)
	var light := G.material(Color("d4f6ff"),0.0,true)
	G.box(model,Vector3(0,0.43,0),Vector3(1.72,0.18,3.9),dark)
	# Rounded nose, tail and low sills leave a real passenger opening on each side.
	_shell(model,[[0.72,0.81,0.48,0.94],[1.38,0.94,0.46,0.88],[1.96,0.83,0.5,0.74],[2.08,0.67,0.54,0.66]],gold)
	_shell(model,[[-2.06,0.68,0.5,0.77],[-1.78,0.91,0.46,0.92],[-1.05,0.82,0.48,1.02]],gold)
	_shell(model,[[-1.25,0.65,1.46,1.53],[-0.9,0.81,1.49,1.59],[0.4,0.81,1.49,1.59],[0.65,0.68,1.46,1.53]],gold)
	var front := G.box(model,Vector3(0,1.18,0.92),Vector3(1.55,0.78,0.035),glass)
	front.rotation.x = -0.48
	var rear := G.box(model,Vector3(0,1.2,-1.17),Vector3(1.55,0.7,0.035),glass)
	rear.rotation.x = 0.4
	for side in [-1.0,1.0]:
		G.box(model,Vector3(side*0.85,0.48,0),Vector3(0.12,0.2,2.6),gold)
		G.tube(model,Vector3(side*0.78,0.75,1.15),Vector3(side*0.78,1.52,0.55),0.045,gold)
		G.tube(model,Vector3(side*0.78,0.75,-1.5),Vector3(side*0.78,1.52,-1),0.045,gold)
		# Two independent passenger seats, no steering wheel or driver.
		G.box(model,Vector3(side*0.4,0.62,-0.35),Vector3(0.62,0.18,0.72),dark)
		var back := G.box(model,Vector3(side*0.4,0.98,-0.72),Vector3(0.63,0.7,0.16),dark)
		back.rotation.x = -0.13
		G.box(model,Vector3(side*0.4,1.36,-0.78),Vector3(0.38,0.2,0.15),dark)
	G.box(model,Vector3(0,0.84,2.01),Vector3(1.48,0.045,0.04),light)
	G.box(model,Vector3(0,0.85,-2.01),Vector3(1.48,0.04,0.04),G.material(Color("ff504a"),0,true))
	G.merge(model)
	var wheels: Array[Node3D] = []
	var doors: Array[Node3D] = []
	var displays: Array[Label3D] = []
	for side in [-1.0,1.0]:
		for z in [-1.34,1.35]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side*0.87,0.36,z)
			model.add_child(wheel)
			G.tube(wheel,Vector3(-0.12,0,0),Vector3(0.12,0,0),0.35,dark)
			G.tube(wheel,Vector3(side*0.13,0,0),Vector3(side*0.15,0,0),0.25,gold)
			wheels.append(wheel)
		var door := Node3D.new()
		door.position = Vector3(side*0.8,1.49,0.25)
		door.set_meta("side",side)
		model.add_child(door)
		G.box(door,Vector3(side*0.03,-0.75,-0.4),Vector3(0.08,0.47,1.7),gold)
		G.box(door,Vector3(side*0.03,-0.28,-0.4),Vector3(0.04,0.49,1.65),glass)
		G.tube(door,Vector3(0,0,0.43),Vector3(0,-0.95,0.43),0.03,gold)
		G.merge(door)
		var brand := G.label(door,"AURORA SELF DRIVE",Vector3(side*0.08,-0.69,-0.4),15)
		brand.rotation.y = side*PI/2
		brand.pixel_size = 0.005
		var display := G.label(door,"AR-%03d • AVAILABLE" % number,Vector3(side*0.09,-0.87,-0.4),14)
		display.rotation.y = side*PI/2
		display.pixel_size = 0.0045
		displays.append(display)
		doors.append(door)
	var label := G.label(model,"AR-%03d\nAURORA SELF DRIVE" % number,Vector3(0,2.05,0),21)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.65
	ring.rings = 20
	ring.ring_segments = 8
	marker.mesh = ring
	marker.material_override = G.material(Color("19bb48"),0,true)
	marker.position = Vector3(2.05,0.04,0)
	marker.scale.y = 0.08
	marker.visible = false
	model.add_child(marker)
	model.set_meta("wheels",wheels)
	model.set_meta("doors",doors)
	model.set_meta("displays",displays)
	model.set_meta("label",label)
	model.set_meta("marker",marker)
	return model

static func _shell(parent: Node3D, sections: Array, material: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for section in sections:
		var z: float = section[0]
		var w: float = section[1]
		var bottom: float = section[2]
		var top: float = section[3]
		var bevel := minf(0.08,(top-bottom)*0.3)
		rings.append(PackedVector3Array([Vector3(-w*0.82,bottom,z),Vector3(-w,bottom+bevel,z),Vector3(-w,top-bevel,z),Vector3(-w*0.83,top,z),Vector3(w*0.83,top,z),Vector3(w,top-bevel,z),Vector3(w,bottom+bevel,z),Vector3(w*0.82,bottom,z)]))
	for i in range(rings.size()-1):
		for j in range(8):
			var k := (j+1)%8
			for vertex in [rings[i][j],rings[i][k],rings[i+1][j],rings[i][k],rings[i+1][k],rings[i+1][j]]: tool.add_vertex(vertex)
	for end in [0,rings.size()-1]:
		var center := Vector3(0,(float(sections[end][2])+float(sections[end][3]))*0.5,sections[end][0])
		for j in range(8):
			tool.add_vertex(center)
			tool.add_vertex(rings[end][(j+1)%8 if end==0 else j])
			tool.add_vertex(rings[end][j if end==0 else (j+1)%8])
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	mesh.material_override = material
	var shell := Node3D.new()
	parent.add_child(shell)
	shell.add_child(mesh)
