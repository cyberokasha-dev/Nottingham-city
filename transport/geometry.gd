extends RefCounted
# Original reusable geometry. Static parts are merged by material before display.
static func material(color: Color, metal := 0.0, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.35 if metal>0 else 0.72
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		m.emission_enabled = true
		m.emission = color
	return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	parent.add_child(n)
	return n

static func tube(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	n.mesh = mesh
	n.position = (a+b)*0.5
	n.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	n.material_override = mat
	parent.add_child(n)
	return n

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	n.mesh = mesh
	n.position = pos
	n.scale = size
	n.material_override = mat
	parent.add_child(n)
	return n

static func label(parent: Node3D, text: String, pos: Vector3, size := 26) -> Label3D:
	var n := Label3D.new()
	n.text = text
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.008
	n.outline_size = 2
	n.visibility_range_end = 65.0
	parent.add_child(n)
	return n

static func merge(parent: Node3D) -> void:
	var groups := {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.material_override
			var key: int = mat.get_instance_id() if mat else 0
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":mat}
			for i in range(child.mesh.get_surface_count()):
				groups[key].tool.append_from(child.mesh,i,child.transform)
			for attached in child.get_children():
				attached.reparent(parent,true)
			child.free()
	for group in groups.values():
		var n := MeshInstance3D.new()
		n.mesh = group.tool.commit()
		n.material_override = group.material
		n.visibility_range_end = 150.0
		parent.add_child(n)

# Bake immutable parts into a single vertex-coloured draw surface.
# Used for shared crowd poses and wheel geometry; moving pivots stay separate.
static var vertex_material: StandardMaterial3D
static func colored_mesh(root: Node3D) -> ArrayMesh:
	var tool:=SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in root.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D=child.transform
		var parent: Node3D=child.get_parent()
		while parent!=root:
			transform=parent.transform*transform
			parent=parent.get_parent()
		var color: Color=child.material_override.albedo_color
		var normal_basis:=transform.basis.inverse().transposed()
		for surface in range(child.mesh.get_surface_count()):
			var arrays: Array=child.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			for index in (indices if not indices.is_empty() else range(vertices.size())):
				tool.set_color(color)
				tool.set_normal((normal_basis*normals[index]).normalized())
				tool.add_vertex(transform*vertices[index])
	if not vertex_material:
		vertex_material=StandardMaterial3D.new()
		vertex_material.vertex_color_use_as_albedo=true
		vertex_material.roughness=.8
	tool.set_material(vertex_material)
	tool.index()
	return tool.commit()
