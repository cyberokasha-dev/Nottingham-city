extends RefCounted
# Original curved road cars. Rounded lofted panels, glazed cabin and real wheel pivots.
const G = preload("res://transport/geometry.gd")
static var wheel_meshes: Dictionary = {}
static func make(kind: String, color: Color) -> Node3D:
	var car := Node3D.new()
	car.set_meta("vehicle_kind",kind)
	var body := Node3D.new()
	car.add_child(body)
	var paint := G.material(color,0.55)
	var trim := G.material(Color("151e27"),0.15)
	var glass := G.material(Color("1c3448"),0.6)
	var rubber := G.material(Color("13171b"))
	var alloy := G.material(Color("b1bac3"),0.85)
	var headlights := G.material(Color("dcf3ff"),0,true)
	var tail_lights := G.material(Color("e82d43"),0,true)
	var height := 1.65 if kind=="suv" else (1.95 if kind=="van" else 1.3)
	loft(body,[[-2.3,0.68,0.35,0.58],[-2.15,0.9,0.3,0.77],[-1.6,0.96,0.3,0.84],[-0.6,0.98,0.32,0.89],[0.8,0.98,0.32,0.85],[1.7,0.93,0.32,0.7],[2.15,0.82,0.36,0.6],[2.3,0.62,0.4,0.52]],paint)
	loft(body,[[-1.6,0.74,0.76,0.8],[-1.05,0.81,0.81,height-0.08],[-0.5,0.82,0.83,height],[0.4,0.8,0.8,height-0.02],[1.15,0.72,0.75,0.82]],glass)
	# Body-coloured roof edge, window pillars, door seams and mirrors.
	for side in [-1.0,1.0]:
		for z in [-0.6,0.65]:
			G.tube(body,Vector3(side*0.83,0.83,z),Vector3(side*0.79,height-0.03,z),0.025,trim)
			G.tube(body,Vector3(side*0.984,0.38,z),Vector3(side*0.984,0.83,z),0.008,trim)
			G.box(body,Vector3(side*0.989,0.72,z-0.15),Vector3(0.025,0.025,0.18),alloy)
		G.sphere(body,Vector3(side*1.05,0.98,0.7),Vector3(0.24,0.13,0.3),paint)
		G.box(body,Vector3(side*0.65,0.59,2.16),Vector3(0.43,0.065,0.06),headlights)
		G.box(body,Vector3(side*0.63,0.68,-2.18),Vector3(0.45,0.065,0.06),tail_lights)
	G.box(body,Vector3(0,0.46,2.25),Vector3(1.3,0.09,0.05),trim)
	G.box(body,Vector3(0,0.45,-2.3),Vector3(0.43,0.13,0.035),G.material(Color("eed36a")))
	G.merge(body)
	var wheels: Array[Node3D] = []
	for side in [-1.0,1.0]:
		for z in [-1.48,1.43]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side*0.94,0.37,z)
			car.add_child(wheel)
			if not wheel_meshes.has(side):
				for radius in [0.37,0.25]:
					var mesh := MeshInstance3D.new()
					var cylinder := CylinderMesh.new()
					cylinder.top_radius = radius
					cylinder.bottom_radius = radius
					cylinder.height = 0.23 if radius>0.3 else 0.245
					cylinder.radial_segments = 16
					mesh.mesh = cylinder
					mesh.rotation.z = PI/2
					mesh.material_override = rubber if radius>0.3 else alloy
					wheel.add_child(mesh)
				for spoke in range(5):
					var a: float = spoke*TAU/5
					G.tube(wheel,Vector3(side*0.13,0,0),Vector3(side*0.13,sin(a)*0.23,cos(a)*0.23),0.025,trim)
				wheel_meshes[side]=G.colored_mesh(wheel)
				for child in wheel.get_children(): child.free()
			var wheel_visual:=MeshInstance3D.new()
			wheel_visual.mesh=wheel_meshes[side]
			wheel_visual.visibility_range_end=150
			wheel.add_child(wheel_visual)
			wheels.append(wheel)
	car.set_meta("wheels",wheels)
	return car

static func loft(parent: Node3D, slices: Array, mat: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for slice in slices:
		var ring := PackedVector3Array()
		for j in range(24):
			var angle := TAU*j/24
			var x := signf(cos(angle))*pow(absf(cos(angle)),0.35)*float(slice[1])
			var y := (signf(sin(angle))*pow(absf(sin(angle)),0.45)+1)*0.5
			ring.append(Vector3(x,lerpf(slice[2],slice[3],y),slice[0]))
		rings.append(ring)
	for i in range(rings.size()-1):
		for j in range(24):
			var next := (j+1)%24
			for p in [rings[i][j],rings[i+1][j],rings[i][next],rings[i][next],rings[i+1][j],rings[i+1][next]]:
				tool.set_smooth_group(0)
				tool.add_vertex(p)
	for end in [0,rings.size()-1]:
		var middle := Vector3(0,(float(slices[end][2])+float(slices[end][3]))/2,float(slices[end][0]))
		for j in range(24):
			for p in [middle,rings[end][j],rings[end][(j+1)%24]]:
				tool.add_vertex(p)
	tool.index()
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material: Material = mat.duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	parent.add_child(mesh)
