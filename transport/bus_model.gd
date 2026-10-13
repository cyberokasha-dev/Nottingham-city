extends Node3D
const G = preload("res://transport/geometry.gd")
const F = preload("res://vehicles/vehicle_factory.gd")
var london := false
var livery := Color("64c7e7")
var doors: Array[Node3D] = []
var wheels: Array[Node3D] = []
var door_fraction := 0.0
var destination: Label3D
var route_number := "60"

func _ready() -> void:
	var paint := G.material(livery,0.25)
	var white := G.material(Color("eceee7"),0.15)
	var rubber := G.material(Color("101820"))
	var glass := G.material(Color(0.13,0.25,0.31,0.46),0.25)
	var steel := G.material(Color("b7c1ca"),0.75)
	var yellow := G.material(Color("eac64c"),0.2)
	var seats := G.material(Color("385f81") if not london else Color("8a3448"))
	var parts := Node3D.new()
	add_child(parts)
	# Tapered nose, rounded shoulders and roof rather than a rectangular bus block.
	F._profile(parts,[[-5.1,1.02,0.5,3.88,4.08],[-4.8,1.27,0.45,4.02,4.28],[-4.55,1.28,0.45,4.04,4.32]],paint)
	F._profile(parts,[[4.5,1.28,0.45,3.98,4.22],[4.86,1.19,0.52,3.86,4.09],[5.08,0.96,0.65,3.65,3.88]],paint)
	G.box(parts,Vector3(0,0.52,0),Vector3(2.48,0.16,9.5),rubber)
	G.box(parts,Vector3(0,2.25,0),Vector3(2.5,0.12,9.1),white)
	F._profile(parts,[[-4.6,1.24,3.92,4.12,4.28],[-4.25,1.25,4.05,4.22,4.4],[4.25,1.25,4.05,4.22,4.4],[4.6,1.24,3.92,4.12,4.28]],paint)
	# Side panels leave genuine lower-deck door gaps on the pavement side.
	for side in [-1.0,1.0]:
		for deck in [0.0,1.95]:
			for z in [-3.9,-2.55,-1.2,0.15,1.5,2.85,4.0]:
				var doorway: bool = side>0 and deck==0 and (z==2.85 or z==4.0 or z==-1.2 or (london and z==-3.9))
				if not doorway:
					G.box(parts,Vector3(side*1.245,0.99+deck,z),Vector3(0.075,0.76,1.28),paint if deck==0 or london else white)
					G.box(parts,Vector3(side*1.255,1.72+deck,z),Vector3(0.055,0.77,1.23),glass)
					G.tube(parts,Vector3(side*1.27,1.3+deck,z-0.65),Vector3(side*1.27,2.15+deck,z-0.65),0.035,rubber)
		# Slim waist and upper trim echo modern Nottingham and London double-decks.
		G.box(parts,Vector3(side*1.28,2.35,0),Vector3(0.04,0.22,8.9),paint)
		G.box(parts,Vector3(side*1.29,3.99,0),Vector3(0.035,0.08,8.8),rubber)
		for z in [-3.05,3.0]:
			var wheel := Node3D.new()
			wheel.position = Vector3(side*1.12,0.52,z)
			add_child(wheel)
			F._cylinder(wheel,Vector3.ZERO,0.53,0.32,rubber)
			F._cylinder(wheel,Vector3(side*0.18,0,0),0.31,0.025,steel)
			for spoke in range(6):
				var a: float = spoke*TAU/6
				G.sphere(wheel,Vector3(side*0.2,sin(a)*0.2,cos(a)*0.2),Vector3(0.035,0.055,0.055),rubber)
			G.merge(wheel)
			wheels.append(wheel)
		# Mirrors have stems, not floating cubes.
		G.tube(parts,Vector3(side*1.1,2.35,4.5),Vector3(side*1.6,2.3,4.65),0.035,rubber)
		G.sphere(parts,Vector3(side*1.6,2.2,4.65),Vector3(0.14,0.38,0.22),rubber)
	for patch in [[2.52,0.64],[4.32,0.36]]:
		G.box(parts,Vector3(1.245,0.99,patch[0]),Vector3(0.075,0.76,patch[1]),paint)
		G.box(parts,Vector3(1.255,1.72,patch[0]),Vector3(0.055,0.77,patch[1]),glass)
	# Front and rear glass, LED destination panel, separate headlights and plate.
	G.box(parts,Vector3(0,1.65,5.105),Vector3(1.91,1.2,0.035),glass)
	G.box(parts,Vector3(0,3.37,5.105),Vector3(1.95,1.05,0.035),glass)
	G.box(parts,Vector3(0,2.62,5.115),Vector3(2.0,0.39,0.04),rubber)
	destination = G.label(self,route_number+"  City Centre",Vector3(0,2.62,5.14),28)
	destination.modulate = Color("ffdc83")
	G.box(parts,Vector3(0,0.65,5.15),Vector3(0.47,0.15,0.03),G.material(Color("f0f0df")))
	G.box(parts,Vector3(0,0.7,-5.12),Vector3(0.47,0.15,0.03),yellow)
	for side in [-1.0,1.0]:
		G.sphere(parts,Vector3(side*0.82,0.88,5.15),Vector3(0.33,0.15,0.08),G.material(Color("e5f7ff"),0,true))
		G.box(parts,Vector3(side*1.05,1.1,-5.13),Vector3(0.12,0.48,0.045),G.material(Color("e82e31"),0,true))
	for deck in [0.0,1.95]:
		for z in [-3.4,-2.1,-0.8,0.5,1.8]:
			for x in [-0.75,0.7]:
				G.box(parts,Vector3(x,0.92+deck,z),Vector3(0.67,0.12,0.62),seats)
				G.box(parts,Vector3(x,1.23+deck,z-0.29),Vector3(0.67,0.63,0.1),seats)
				G.tube(parts,Vector3(x,0.62+deck,z),Vector3(x,0.9+deck,z),0.04,steel)
	# Rear staircase and interior grab poles.
	for i in range(9):
		G.box(parts,Vector3(-0.75,0.6+i*0.2,-4.1+i*0.18),Vector3(0.7,0.12,0.22),rubber)
	for z in [-3.5,0.0,3.5]:
		G.tube(parts,Vector3(0.15,0.6,z),Vector3(0.15,2.15,z),0.026,yellow)
	G.merge(parts)
	for center in ([3.5,-1.2,-3.9] if london else [3.5,-1.2]):
		for half in [-1.0,1.0]:
			var door := Node3D.new()
			door.position = Vector3(1.29,0,center+half*0.32)
			door.set_meta("closed_z",door.position.z)
			door.set_meta("slide",half)
			add_child(door)
			G.box(door,Vector3(0,1.32,0),Vector3(0.045,1.65,0.61),glass)
			for edge in [-0.31,0.31]:
				G.tube(door,Vector3(0,0.5,edge),Vector3(0,2.15,edge),0.025,rubber)
			G.merge(door)
			doors.append(door)
	var brand := G.label(self,"CITYLINK" if london else "NOTTINGHAM • CITY",Vector3(-1.305,2.37,0),24)
	brand.rotation.y = -PI/2
	var side_number := G.label(self,route_number,Vector3(1.31,2.5,3.4),28)
	side_number.rotation.y = PI/2

func animate_doors(value: float) -> void:
	door_fraction = clampf(value,0,1)
	for door in doors:
		door.position.z = float(door.get_meta("closed_z"))+float(door.get_meta("slide"))*door_fraction*0.56
		door.position.x = 1.29+sin(door_fraction*PI/2)*0.12

func roll(distance: float) -> void:
	for wheel in wheels:
		wheel.rotation.x += distance/0.53
