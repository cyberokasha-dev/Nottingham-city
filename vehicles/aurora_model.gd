extends RefCounted
# Original Cybercab-inspired fastback with a continuous roof and genuine door openings.
const G=preload("res://transport/geometry.gd")
const C=preload("res://vehicles/coachwork.gd")
static func make(number:int) -> Node3D:
 var model:=Node3D.new();model.name="AuroraFastback"
 var gold:=C.material(Color("bca36b"),.68,.29)
 var dark:=C.material(Color("17232c"),.22,.35)
 var leather:=C.material(Color("b5ad98"),0,.74)
 var glass:=C.material(Color(.12,.23,.28,.34),.22,.13)
 var white:=C.material(Color("d9f4fa"),0,.2,true)
 var red:=C.material(Color("e65149"),0,.25,true)
 C.part(model,"aurora/body-v2",func(body):
  C.loft(body,[Vector4(-2.12,.56,.31,.44),Vector4(-1.75,.85,.25,.44),Vector4(0,.88,.24,.42),Vector4(1.65,.84,.28,.46),Vector4(2.1,.57,.35,.46)],dark)
  C.loft(body,[Vector4(.72,.8,.42,.91),Vector4(1.13,.9,.43,.93),Vector4(1.67,.87,.43,.81),Vector4(2.06,.68,.49,.69),Vector4(2.13,.52,.53,.64)],gold)
  C.loft(body,[Vector4(-2.13,.56,.47,.76),Vector4(-1.89,.86,.42,.94),Vector4(-1.45,.93,.42,1.1),Vector4(-1.03,.83,.43,1.12)],gold)
  C.loft(body,[Vector4(-1.38,.58,1.35,1.4),Vector4(-.96,.75,1.5,1.6),Vector4(-.4,.79,1.56,1.66),Vector4(.24,.77,1.54,1.64),Vector4(.65,.65,1.43,1.51)],gold)
  C.window(body,[Vector3(-.77,.9,1.08),Vector3(.77,.9,1.08),Vector3(.66,1.52,.56),Vector3(-.66,1.52,.56)],glass,.055)
  C.window(body,[Vector3(-.77,1.02,-1.33),Vector3(.77,1.02,-1.33),Vector3(.67,1.51,-.98),Vector3(-.67,1.51,-.98)],glass,-.035)
  for side in [-1.0,1.0]:
   C.line(body,[Vector3(side*.81,.87,1.08),Vector3(side*.75,1.29,.79),Vector3(side*.66,1.53,.52)],.033,gold)
   C.line(body,[Vector3(side*.83,.83,-1.45),Vector3(side*.79,1.25,-1.2),Vector3(side*.65,1.53,-.96)],.042,gold)
   C.cylinder(body,Vector3(side*.85,.44,-1.03),Vector3(side*.85,.44,.72),.055,gold)
   C.seat(body,Vector3(side*.4,.62,-.35),leather,dark)
   # Recessed wheel arches and compact side cameras replace exposed buggy-style rails.
   for z in [-1.34,1.35]:
    var arch:Array[Vector3]=[]
    for i in range(13):
     var a:=i*PI/12;arch.append(Vector3(side*.935,.35+sin(a)*.43,z+cos(a)*.43))
    C.line(body,arch,.027,dark)
   G.sphere(body,Vector3(side*.88,1.04,.65),Vector3(.11,.085,.18),dark)
   G.sphere(body,Vector3(side*.935,1.045,.65),Vector3(.012,.034,.055),glass)
  C.line(body,[Vector3(-.71,.67,2.01),Vector3(-.58,.65,2.1),Vector3(0,.625,2.135),Vector3(.58,.65,2.1),Vector3(.71,.67,2.01)],.024,white)
  C.line(body,[Vector3(-.75,.8,-2.02),Vector3(-.56,.78,-2.12),Vector3(0,.745,-2.15),Vector3(.56,.78,-2.12),Vector3(.75,.8,-2.02)],.022,red)
  C.loft(body,[Vector4(-2.08,.58,.37,.44),Vector4(-1.95,.71,.33,.41)],dark)
  G.box(body,Vector3(0,1.0,.59),Vector3(1.34,.11,.2),dark)
  var screen:=G.box(body,Vector3(0,1.12,.57),Vector3(.52,.24,.025),C.material(Color("284e56"),.15,.25,true));screen.rotation.x=-.16
  for i in range(3):G.box(body,Vector3(-.13+i*.12,1.12,.548),Vector3(.07,.012,.005),white)
  G.box(body,Vector3(0,.84,-.32),Vector3(.08,.13,.42),dark))
 var wheels:Array[Node3D]=[];var doors:Array[Node3D]=[];var displays:Array[Label3D]=[]
 for side in [-1.0,1.0]:
  for z in [-1.34,1.35]:wheels.append(C.wheel(model,side,Vector3(side*.87,.36,z),.35,true))
  var door:=Node3D.new();door.position=Vector3(side*.8,1.49,.25);door.set_meta("side",side);model.add_child(door)
  C.part(door,"aurora/door-v2/"+str(side),func(leaf):
   C.panel(leaf,side,[Vector4(-1.28,.035,-.91,-.54),Vector4(-1.02,.08,-1.02,-.52),Vector4(.31,.08,-1.02,-.54),Vector4(.53,.01,-.91,-.55)],gold,.025)
   C.panel(leaf,side,[Vector4(-1.25,.025,-.54,-.19),Vector4(-.98,.035,-.52,.03),Vector4(.18,.035,-.54,.02),Vector4(.49,.01,-.55,-.32)],glass,.01)
   C.line(leaf,[Vector3(side*.03,-.54,-1.25),Vector3(side*.035,-.19,-1.25),Vector3(side*.035,.03,-.98),Vector3(side*.035,.02,.18),Vector3(side*.01,-.32,.49),Vector3(side*.01,-.55,.49)],.018,dark)
   C.cylinder(leaf,Vector3(side*.06,-.51,-1.22),Vector3(side*.06,-.51,.45),.015,dark)
   G.box(leaf,Vector3(side*.11,-.64,-.81),Vector3(.015,.02,.18),dark))
  var brand:=G.label(door,"AURORA SELF DRIVE",Vector3(side*.115,-.76,-.4),13);brand.rotation.y=side*PI/2;brand.pixel_size=.0045
  var display:=G.label(door,"AR-%03d • AVAILABLE"%number,Vector3(side*.12,-.93,-.4),12);display.rotation.y=side*PI/2;display.pixel_size=.0045
  displays.append(display);doors.append(door)
 var plate:=G.label(model,"AR %03d"%number,Vector3(0,.64,-2.16),14);plate.rotation.y=PI;plate.pixel_size=.004
 var label:=G.label(model,"AR-%03d\nAURORA SELF DRIVE"%number,Vector3(0,2.05,0),21);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 var marker:=_marker(model,Vector3(2.05,.04,0))
 preload("res://vehicles/driver_controls.gd").make(model,Vector3(.4,1.0,.38))
 model.set_meta("wheels",wheels);model.set_meta("doors",doors);model.set_meta("displays",displays);model.set_meta("label",label);model.set_meta("marker",marker)
 model.set_meta("body_style","curved_fastback");return model
static func _marker(model:Node3D,position:Vector3) -> MeshInstance3D:
 var marker:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.48;ring.outer_radius=.65;ring.rings=20;ring.ring_segments=8
 marker.mesh=ring;marker.material_override=C.material(Color("19bb48"),0,.5,true);marker.position=position;marker.scale.y=.08;marker.hide();model.add_child(marker);return marker
# Kept for older procedural callers; new bodywork uses the shared curved loft.
static func _shell(parent:Node3D,sections:Array,mat:Material) -> void:
 var profile:Array=[]
 for s in sections:profile.append(Vector4(s[0],s[1],s[2],s[3]))
 C.loft(parent,profile,mat)
