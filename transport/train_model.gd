extends RefCounted
# Streamlined electric carriages; static meshes are shared after the first construction.
const G=preload("res://transport/geometry.gd")
static var shells: Dictionary={}
static func make(color: Color) -> Node3D:
	var model:=Node3D.new()
	var white:=G.material(Color("e8eff1"),.35)
	var trim:=G.material(Color("152d3c"),.45)
	var stripe:=G.material(color,.3)
	var glass:=G.material(Color(.13,.32,.42,.27),.1)
	var seats:=G.material(Color("315471"))
	var light:=G.material(Color("d9f5ff"),0,true)
	var metal:=G.material(Color("78888f"),.65)
	var key:=color.to_html()
	if shells.has(key):
		for part in shells[key]:
			var instance:=MeshInstance3D.new(); instance.mesh=part.mesh; instance.material_override=part.material
			instance.visibility_range_end=220; model.add_child(instance)
	else:
		for center in [-19.0,0.0,19.0]:
			G.box(model,Vector3(0,.48,center),Vector3(3.05,.22,17.6),trim)
			_loft(model,[[-8.8,1.42,.6,1.15],[-8.4,1.55,.6,1.15],[8.4,1.55,.6,1.15],[8.8,1.42,.6,1.15]],center,white)
			_loft(model,[[-8.8,1.42,2.95,3.5],[-8.4,1.55,2.95,3.55],[8.4,1.55,2.95,3.55],[8.8,1.42,2.95,3.5]],center,white)
			G.box(model,Vector3(0,3.6,center),Vector3(1.35,.16,12),trim)
			for side in [-1,1]:
				for z in [-7.0,-5.0,-3.0,-1.0,1.0,3.0,5.0,7.0]:
					if center==19 and z==3: continue # Keep a real sliding-door opening at z=22.
					G.box(model,Vector3(side*1.52,1.28,center+z),Vector3(.10,.36,1.98),stripe)
					G.box(model,Vector3(side*1.53,2.17,center+z),Vector3(.045,1.38,1.83),glass)
					G.box(model,Vector3(side*1.52,2.2,center+z+.94),Vector3(.09,1.6,.12),white)
				for z in [-5.0,0.0,5.0]:
					G.box(model,Vector3(side*.65,.82,center+z),Vector3(.65,.18,.8),seats)
					G.box(model,Vector3(side*.65,1.25,center+z-.45),Vector3(.65,.85,.14),seats)
			for bogie in [-5.8,5.8]:
				G.box(model,Vector3(0,.35,center+bogie),Vector3(2.3,.4,2.8),trim)
				for axle in [-.85,.85]:
					G.tube(model,Vector3(-1.3,.22,center+bogie+axle),Vector3(1.3,.22,center+bogie+axle),.15,metal)
					for side in [-1,1]:
						G.tube(model,Vector3(side*1.24,.28,center+bogie+axle),Vector3(side*1.46,.28,center+bogie+axle),.38,trim)
						G.tube(model,Vector3(side*1.47,.28,center+bogie+axle),Vector3(side*1.49,.28,center+bogie+axle),.24,metal)
		for side in [-1,1]:
			_loft(model,[[side*27.6,1.48,.62,3.5],[side*29.0,1.3,.65,3.05],[side*31.0,.9,.68,1.9],[side*33.0,.20,.75,1.04]],0,white)
			var screen:=G.box(model,Vector3(0,2.55,side*29.2),Vector3(2.2,1.0,.06),trim)
			screen.rotation.x=side*.63
			G.box(model,Vector3(0,1.12,side*31.6),Vector3(1.25,.08,.10),light)
			G.box(model,Vector3(0,.86,side*32.1),Vector3(1.05,.12,.14),stripe)
			for end in [-.57,.57]: G.sphere(model,Vector3(end,1.18,side*31.55),Vector3(.22,.16,.14),light)
		for z in [-9.5,9.5]:
			G.box(model,Vector3(0,1.8,z),Vector3(2.25,2.2,1.4),trim)
			for rib in [-.45,0.0,.45]: G.box(model,Vector3(0,1.8,z+rib),Vector3(2.4,2.35,.10),metal)
		G.box(model,Vector3(.62,.87,22),Vector3(.75,.18,.85),seats)
		G.box(model,Vector3(.62,1.3,21.55),Vector3(.75,.85,.14),seats)
		G.merge(model)
		shells[key]=[]
		for child in model.get_children():
			if child is MeshInstance3D:
				child.visibility_range_end=220
				shells[key].append({"mesh":child.mesh,"material":child.material_override})
	var doors:Array[Node3D]=[]
	for side in [-1,1]:
		var door:=Node3D.new(); door.position=Vector3(side*1.53,0,22); model.add_child(door)
		G.box(door,Vector3(0,1.1,0),Vector3(.10,.9,1.8),white)
		G.box(door,Vector3(0,2.2,0),Vector3(.05,1.35,1.8),glass)
		G.box(door,Vector3(0,1.35,0),Vector3(.12,.3,1.8),stripe)
		G.merge(door); doors.append(door)
		var badge:=G.label(model,"CITY RAIL • ELECTRIC",Vector3(side*1.60,2.9,0),16)
		badge.rotation.y=side*PI/2; badge.pixel_size=.012
	model.set_meta("doors",doors)
	return model

static func _loft(parent: Node3D, sections: Array, center: float, mat: Material) -> void:
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array[PackedVector3Array]=[]
	for section in sections:
		var z: float=section[0]+center; var width: float=section[1]
		var bottom: float=section[2]; var top: float=section[3]
		rings.append(PackedVector3Array([Vector3(-width*.82,bottom,z),Vector3(-width,bottom+.14,z),Vector3(-width,top-.23,z),Vector3(-width*.78,top,z),Vector3(width*.78,top,z),Vector3(width,top-.23,z),Vector3(width,bottom+.14,z),Vector3(width*.82,bottom,z)]))
	for i in range(rings.size()-1):
		for j in range(8):
			var k: int=(j+1)%8
			for v in [rings[i][j],rings[i+1][j],rings[i+1][k],rings[i][j],rings[i+1][k],rings[i][k]]: tool.add_vertex(v)
	tool.generate_normals(); tool.index()
	var mesh:=MeshInstance3D.new(); mesh.mesh=tool.commit(); mesh.material_override=mat
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED; parent.add_child(mesh)
