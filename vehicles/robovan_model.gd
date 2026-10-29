extends RefCounted
# Original streamliner shuttle: curved end caps, continuous crown, skirted wheels and inset doors.
const G=preload("res://transport/geometry.gd")
const C=preload("res://vehicles/coachwork.gd")
static func make(number:int) -> Node3D:
 var model:=Node3D.new();model.name="RobovanStreamliner"
 var silver:=C.material(Color("b9c4c5"),.7,.3)
 var trim:=C.material(Color("17232a"),.12,.45)
 var leather:=C.material(Color("a8b5b1"),0,.76)
 var glass:=C.material(Color(.1,.2,.23,.39),.22,.12)
 var polished:=C.material(Color("d5e0df"),.72,.23)
 var white:=C.material(Color("b9ddd9"),0,.3,true)
 var red:=C.material(Color("e96a5a"),0,.3,true)
 C.part(model,"robovan/body-v2",func(body):
  C.loft(body,[Vector4(-3,.51,.28,.52),Vector4(-2.65,1.02,.22,.58),Vector4(-1.9,1.1,.2,.53),Vector4(1.9,1.1,.2,.53),Vector4(2.65,1.02,.22,.58),Vector4(3,.51,.28,.52)],trim)
  # The bowed front and rear flow into the roof instead of ending as vertical boxes.
  C.loft(body,[Vector4(2.04,1.07,.51,2.26),Vector4(2.22,1.04,.45,2.2),Vector4(2.49,.96,.4,2.04),Vector4(2.84,.77,.37,1.64),Vector4(3.03,.48,.43,1.17),Vector4(3.08,.21,.56,.92)],silver,3,.58)
  C.loft(body,[Vector4(-3.08,.21,.56,.92),Vector4(-3.03,.48,.43,1.17),Vector4(-2.84,.77,.37,1.64),Vector4(-2.49,.96,.4,2.04),Vector4(-2.24,1.04,.45,2.2),Vector4(-2.05,1.07,.51,2.26)],silver,3,.58)
  C.loft(body,[Vector4(-2.51,.78,2.02,2.11),Vector4(-1.9,1.02,2.25,2.38),Vector4(-1,1.06,2.31,2.45),Vector4(1,1.06,2.31,2.45),Vector4(1.9,1.02,2.25,2.38),Vector4(2.51,.78,2.02,2.11)],silver,3,.55)
  C.loft(body,[Vector4(-1.65,.67,2.402,2.419),Vector4(-.8,.82,2.438,2.451),Vector4(.8,.82,2.438,2.451),Vector4(1.65,.67,2.402,2.419)],trim)
  # Small inset corner windows and full side glazing reveal the actual seated riders.
  for side in [-1.0,1.0]:
   for span in [[-1.98,-1.38],[1.46,2.02]]:
    C.panel(body,side,[Vector4(span[0],1.079,1.22,2.05),Vector4((span[0]+span[1])*.5,1.085,1.18,2.17),Vector4(span[1],1.079,1.2,2.08)],glass,.008)
    C.panel(body,side,[Vector4(span[0],1.065,.5,1.22),Vector4(span[1],1.075,.5,1.2)],silver,.018)
   for z in [-2.04,2.04]:C.cylinder(body,Vector3(side*1.07,1.18,z),Vector3(side*1.01,2.23,z),.03,silver)
   for z in [-1.93,1.93]:
    # Fairings enclose the top of each wheel; tyres still roll below the sill.
    C.panel(body,side,[Vector4(z-.61,.98,.48,.7),Vector4(z-.4,1.12,.46,.84),Vector4(z+.4,1.12,.46,.84),Vector4(z+.61,.98,.48,.7)],silver,.02)
   for row in range(4):
    var y:=.91+row*.07
    C.line(body,[Vector3(side*1.09,y,-2.3),Vector3(side*1.105,y,-1.4)],.012,polished)
    C.line(body,[Vector3(side*1.105,y,1.47),Vector3(side*1.09,y,2.3)],.012,polished)
   G.sphere(body,Vector3(side*1.09,1.23,1.72),Vector3(.08,.06,.13),trim)
   for z in [1.2,-.2,-1.6]:C.seat(body,Vector3(side*.55,.72,z),leather,trim)
   # Fine trim defines the arch-shaped passenger doorway.
   C.line(body,[Vector3(side*1.11,.52,-1.12),Vector3(side*1.11,1.91,-1.02),Vector3(side*1.08,2.17,-.83),Vector3(side*1.08,2.22,.94),Vector3(side*1.11,1.94,1.18),Vector3(side*1.11,.52,1.34)],.018,white)
  for row in range(4):
   var y:=.91+row*.065
   C.line(body,[Vector3(-.7,y,2.92),Vector3(-.42,y,3.055),Vector3(0,y,3.09),Vector3(.42,y,3.055),Vector3(.7,y,2.92)],.015,white)
   C.line(body,[Vector3(-.7,y,-2.92),Vector3(-.42,y,-3.055),Vector3(0,y,-3.09),Vector3(.42,y,-3.055),Vector3(.7,y,-2.92)],.013,red)
  G.box(body,Vector3(0,1.12,2.02),Vector3(1.7,.12,.17),trim)
  G.box(body,Vector3(0,1.3,1.97),Vector3(.57,.24,.026),C.material(Color("284b50"),.1,.3,true)))
 var wheels:Array[Node3D]=[];var doors:Array[Node3D]=[];var displays:Array[Label3D]=[]
 for side in [-1.0,1.0]:
  for z in [-1.91,1.91]:wheels.append(C.wheel(model,side,Vector3(side*1.02,.4,z),.39,false))
  var door:=Node3D.new();door.position=Vector3(side*1.08,1.35,.2);door.set_meta("side",side);door.set_meta("slide_origin",door.position);model.add_child(door)
  C.part(door,"robovan/door-v2/"+str(side),func(leaf):
   C.panel(leaf,side,[Vector4(-1.3,.0,-.86,-.25),Vector4(-1.12,.035,-.88,-.22),Vector4(1.1,.035,-.88,-.22),Vector4(1.24,0,-.82,-.28)],silver,.016)
   C.panel(leaf,side,[Vector4(-1.29,.012,-.25,.48),Vector4(-1.04,.022,-.22,.77),Vector4(.88,.022,-.22,.77),Vector4(1.23,.012,-.28,.5)],glass,.005)
   C.line(leaf,[Vector3(side*.025,-.24,-1.29),Vector3(side*.025,.48,-1.29),Vector3(side*.025,.77,-1.04),Vector3(side*.025,.77,.88),Vector3(side*.025,.5,1.23),Vector3(side*.025,-.28,1.23)],.018,trim)
   for row in range(4):C.cylinder(leaf,Vector3(side*.06,-.44+row*.07,-1.27),Vector3(side*.06,-.44+row*.07,1.22),.011,polished)
   G.box(leaf,Vector3(side*.065,-.16,.93),Vector3(.014,.025,.19),trim))
  var brand:=G.label(door,"AURORA ROBOVAN",Vector3(side*.075,-.66,0),15);brand.rotation.y=side*PI/2;brand.pixel_size=.0045
  var display:=G.label(model,"RV-%03d • AVAILABLE"%number,Vector3(side*1.125,1.95,.1),15);display.rotation.y=side*PI/2;display.pixel_size=.005
  doors.append(door);displays.append(display)
 var label:=G.label(model,"RV-%03d\nROBOVAN SELF DRIVE"%number,Vector3(0,2.85,0),21);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 var plate:=G.label(model,"RV %03d"%number,Vector3(0,.72,-3.105),13);plate.rotation.y=PI;plate.pixel_size=.004
 var marker:=preload("res://vehicles/aurora_model.gd")._marker(model,Vector3(2.3,.04,.55))
 preload("res://vehicles/driver_controls.gd").make(model,Vector3(.55,1.2,1.98))
 model.set_meta("passenger_seat",Vector3(.55,.36,1.2));model.set_meta("driver_seat",Vector3(-.55,.36,1.2))
 model.set_meta("boarding_door",Vector3(1.35,.4,.55));model.set_meta("boarding_point",Vector3(2.3,.05,.55))
 model.set_meta("wheels",wheels);model.set_meta("doors",doors);model.set_meta("displays",displays);model.set_meta("label",label);model.set_meta("marker",marker)
 model.set_meta("seat_count",6);model.set_meta("body_style","curved_streamliner");return model
