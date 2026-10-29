extends RefCounted
# Reusable curved panels. Meshes/materials are shared across the service fleet.
const G=preload("res://transport/geometry.gd")
static var materials:Dictionary={}
static var parts:Dictionary={}
static func material(color:Color,metal:=0.0,roughness:=.32,glow:=false) -> StandardMaterial3D:
 var key:=str(color)+"/"+str(metal)+"/"+str(roughness)+"/"+str(glow)
 if not materials.has(key):
  var mat:=G.material(color,metal,glow);mat.roughness=roughness
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED;materials[key]=mat
 return materials[key]
static func part(parent:Node3D,key:String,build:Callable) -> void:
 if not parts.has(key):
  var source:=Node3D.new();build.call(source);G.merge(source)
  var entries:Array=[]
  for child in source.get_children():
   if child is MeshInstance3D:entries.append({"mesh":child.mesh,"material":child.material_override,"transform":child.transform})
  source.free();parts[key]=entries
 for entry in parts[key]:
  var child:=MeshInstance3D.new();child.mesh=entry.mesh;child.material_override=entry.material
  child.transform=entry.transform;child.visibility_range_end=150;parent.add_child(child)
static func _mesh(parent:Node3D,tool:SurfaceTool,mat:Material) -> void:
 tool.index();tool.generate_normals()
 var node:=MeshInstance3D.new();node.mesh=tool.commit();node.material_override=mat;parent.add_child(node)
static func _triangle(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
 tool.set_smooth_group(0)
 for point in [a,b,c]:tool.add_vertex(point)
# Each section is (longitudinal position, half width, underside, crown).
# Cubic profiles and 28-point rounded cross sections replace eight-corner boxes.
static func loft(parent:Node3D,sections:Array,mat:Material,steps:=3,power:=.48) -> void:
 var profile:Array[Vector4]=[]
 for i in range(sections.size()-1):
  var a:Vector4=sections[maxi(0,i-1)];var b:Vector4=sections[i];var c:Vector4=sections[i+1];var d:Vector4=sections[mini(sections.size()-1,i+2)]
  for j in range(steps):
   var t:=j/float(steps)
   var value:Vector4=(b*2+(-a+c)*t+(a*2-b*5+c*4-d)*t*t+(-a+b*3-c*3+d)*t*t*t)*.5
   value.x=lerpf(b.x,c.x,t);value.y=maxf(.01,value.y);value.w=maxf(value.z+.01,value.w);profile.append(value)
 profile.append(sections[-1])
 var rings:Array[PackedVector3Array]=[]
 for row in profile:
  var ring:=PackedVector3Array()
  for j in range(28):
   var angle:=j*TAU/28
   ring.append(Vector3(signf(cos(angle))*pow(absf(cos(angle)),power)*row.y,lerpf(row.z,row.w,(signf(sin(angle))*pow(absf(sin(angle)),power)+1)*.5),row.x))
  rings.append(ring)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(rings.size()-1):
  for j in range(28):
   var k:=(j+1)%28
   _triangle(tool,rings[i][j],rings[i+1][j],rings[i][k]);_triangle(tool,rings[i][k],rings[i+1][j],rings[i+1][k])
 for end in [0,rings.size()-1]:
  var row:Vector4=profile[end];var middle:=Vector3(0,(row.z+row.w)*.5,row.x)
  for j in range(28):
   if end==0:_triangle(tool,middle,rings[end][j],rings[end][(j+1)%28])
   else:_triangle(tool,middle,rings[end][(j+1)%28],rings[end][j])
 _mesh(parent,tool,mat)
# Convex side skin: (z, x, bottom, top), preserving an actual opening when the door moves.
static func panel(parent:Node3D,side:float,sections:Array,mat:Material,bow:=.035) -> void:
 var rows:Array[PackedVector3Array]=[]
 for i in range(sections.size()-1):
  var a:Vector4=sections[i];var b:Vector4=sections[i+1]
  for sample in range(3):
   var row:Vector4=a.lerp(b,sample/3.0);var points:=PackedVector3Array()
   for v in range(7):
    var t:=v/6.0;points.append(Vector3(side*(row.y+sin(PI*t)*bow),lerpf(row.z,row.w,t),row.x))
   rows.append(points)
 var last:Vector4=sections[-1];var edge:=PackedVector3Array()
 for v in range(7):
  var t:=v/6.0;edge.append(Vector3(side*(last.y+sin(PI*t)*bow),lerpf(last.z,last.w,t),last.x))
 rows.append(edge)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(rows.size()-1):
  for j in range(6):
   if side>0:
    _triangle(tool,rows[i][j],rows[i][j+1],rows[i+1][j]);_triangle(tool,rows[i][j+1],rows[i+1][j+1],rows[i+1][j])
   else:
    _triangle(tool,rows[i][j],rows[i+1][j],rows[i][j+1]);_triangle(tool,rows[i][j+1],rows[i+1][j],rows[i+1][j+1])
 _mesh(parent,tool,mat)
static func window(parent:Node3D,corners:Array[Vector3],mat:Material,bow:=.035) -> void:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var points:Array[PackedVector3Array]=[]
 for y in range(7):
  var row:=PackedVector3Array();var v:=y/6.0
  for x in range(13):
   var u:=x/12.0
   var point:Vector3=corners[0].lerp(corners[1],u).lerp(corners[3].lerp(corners[2],u),v)
   point.z+=sin(u*PI)*sin(v*PI)*bow;row.append(point)
  points.append(row)
 for y in range(6):
  for x in range(12):
   _triangle(tool,points[y][x],points[y+1][x],points[y][x+1]);_triangle(tool,points[y][x+1],points[y+1][x],points[y+1][x+1])
 _mesh(parent,tool,mat)
static func cylinder(parent:Node3D,a:Vector3,b:Vector3,radius:float,mat:Material,segments:=12) -> void:
 var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=a.distance_to(b);mesh.radial_segments=segments;mesh.rings=0
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=(a+b)*.5;node.quaternion=Quaternion(Vector3.UP,(b-a).normalized());node.material_override=mat;parent.add_child(node)
static func line(parent:Node3D,points:Array[Vector3],radius:float,mat:Material) -> void:
 for i in range(1,points.size()):cylinder(parent,points[i-1],points[i],radius,mat,8)

static func seat(parent:Node3D,at:Vector3,leather:Material,trim:Material) -> void:
 G.sphere(parent,at,Vector3(.63,.17,.71),leather)
 G.sphere(parent,at+Vector3(0,.37,-.32),Vector3(.62,.79,.17),leather)
 G.sphere(parent,at+Vector3(0,.73,-.38),Vector3(.36,.23,.15),leather)
 for side in [-1.0,1.0]:
  cylinder(parent,at+Vector3(side*.28,.08,-.33),at+Vector3(side*.28,.08,.25),.04,leather)
  G.box(parent,at+Vector3(side*.31,.26,-.07),Vector3(.06,.065,.4),trim)
 cylinder(parent,at+Vector3(0,-.17,-.1),at+Vector3(0,-.06,-.1),.07,trim)
static func wheel(parent:Node3D,side:float,position:Vector3,radius:float,gold:bool) -> Node3D:
 var pivot:=Node3D.new();pivot.position=position;parent.add_child(pivot)
 var key:="wheel/"+str(side)+"/"+str(radius)+"/"+str(gold)
 part(pivot,key,func(root):
  var rubber:=material(Color("141a20"),.02,.84);var disc:=material(Color("cfb47b") if gold else Color("c3cdd0"),.7,.25);var dark:=material(Color("35444a"),.4,.3)
  cylinder(root,Vector3(-.12,0,0),Vector3(.12,0,0),radius,rubber,32)
  cylinder(root,Vector3(side*.125,0,0),Vector3(side*.15,0,0),radius*.83,disc,32)
  cylinder(root,Vector3(side*.155,0,0),Vector3(side*.168,0,0),radius*.105,dark,16)
  var holes:=SurfaceTool.new();holes.begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(8):
   var a:=i*TAU/8;var center:=Vector3(side*.157,sin(a)*radius*.66,cos(a)*radius*.66)
   for j in range(6):
    var start:=j*TAU/6;var finish:=(j+1)*TAU/6
    _triangle(holes,center,center+Vector3(0,sin(start)*.009,cos(start)*.018),center+Vector3(0,sin(finish)*.009,cos(finish)*.018))
  _mesh(root,holes,dark))
 return pivot
static func clear() -> void:
 parts.clear();materials.clear()
