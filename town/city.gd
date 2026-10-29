extends Node3D

const GROUND_Y := -5.12
const W=preload("res://town/world_layout.gd")
const ROAD_X = W.ROAD_X
const CORE_X = W.CORE_X
const ROAD_Z = W.ROAD_Z
const CORE_Z = W.CORE_Z
var infill: RefCounted
var regions: Node3D
var places: Node3D
const ATLAS = preload("res://town/districts.gd")
var districts: Array[Dictionary] = ATLAS.definitions()
var houses: Array[Node3D] = []
var batches := {}
var grass: StandardMaterial3D
var asphalt: StandardMaterial3D
var pavement: StandardMaterial3D
var paint: StandardMaterial3D
var traffic: Node3D
var transport: Node3D
var parks: Array[Node3D] = []
var house_cells:Dictionary={}
var retained_tenancies:Dictionary={}
var next_original_house:=1
var local_roads: Array[Dictionary] = []
var outer_parks:Array[Dictionary]=[{"name":"Riverside Park • Lenton","point":Vector3(-230,GROUND_Y,380),"node":null},{"name":"Meadows Playing Fields • Carlton","point":Vector3(380,GROUND_Y,330),"node":null}]

func _ready() -> void:
	grass = _material(Color("648959"))
	asphalt = _material(Color("35414b"))
	pavement = _material(Color("aeb7b5"))
	paint = _material(Color("eee9d5"))
	_environment()
	_ground()
	_roads()
	# Keep occupied homes exactly where they were, while avoiding construction of unused homes.
	if not OS.has_environment("NOTTINGHAM_TEST"):
		var saved=load("res://simulation/economy.gd").new();saved.load_saved_data()
		for key in saved.data.get("houses",{}):
			if str(saved.data.houses[key].get("tenant",""))!="":retained_tenancies[key]=true
		saved.free()
	_neighbourhoods()
	_outlying_homes()
	for house in houses:
		var key:=Vector2i(floori(house.position.x/64),floori(house.position.z/64))
		if not house_cells.has(key): house_cells[key]=[]
		house_cells[key].append(house)
	_finish_batches()
	regions=preload("res://town/region_stream.gd").new()
	regions.city=self
	add_child(regions)
	for road in local_roads: regions.stamp(road.point,road.size,road.material)
	infill=preload("res://town/city_infill.gd").new()
	infill.populate(self)
	places=preload("res://town/city_places.gd").new()
	places.city=self
	add_child(places)
	traffic = preload("res://town/traffic.gd").new()
	traffic.name = "UKTraffic"
	traffic.game = get_parent().get_parent()
	add_child(traffic)
	transport = preload("res://transport/network.gd").new()
	transport.traffic = traffic
	traffic.transport = transport
	add_child(transport)

func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("699dcc")
	sky_material.sky_horizon_color = Color("d3e3ef")
	sky_material.ground_horizon_color = Color("d3e3ef")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_color = Color("fff2dc")
	sun.light_energy = 0.75
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)

func _ground() -> void:
	var visual:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new();mesh.top_radius=W.LIMIT;mesh.bottom_radius=W.LIMIT;mesh.height=.3;mesh.radial_segments=96
	visual.mesh=mesh;visual.material_override=grass;visual.position=Vector3(0,GROUND_Y-.15,0);add_child(visual)
	var ground:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new()
	shape.radius=W.LIMIT;shape.height=.3;collision.shape=shape;ground.position=visual.position
	ground.add_child(collision);add_child(ground)

func _roads() -> void:
	# Continuous outer distributor connects all street ends around the playable city.
	for x in [-160.0,160.0]:
		_stamp(Vector3(x,GROUND_Y+0.011,10),Vector3(12,0.022,332),asphalt)
		_stamp(Vector3(x+signf(x)*7.5,GROUND_Y+0.025,10),Vector3(3,0.04,332),pavement)
		for z in range(-143,165,9):
			if not _near_crossing(z,CORE_Z): _stamp(Vector3(x,GROUND_Y+0.03,z),Vector3(0.12,0.012,3.5),paint)
	for z in [-150.0,170.0]:
		_stamp(Vector3(0,GROUND_Y+0.011,z),Vector3(332,0.022,12),asphalt)
		_stamp(Vector3(0,GROUND_Y+0.025,z+(-7.5 if z<0 else 7.5)),Vector3(332,0.04,3),pavement)
		for x in range(-153,160,9):
			if not _near_crossing(x,CORE_X): _stamp(Vector3(x,GROUND_Y+0.03,z),Vector3(3.5,0.012,0.12),paint)
	for x in CORE_X:
		_stamp(Vector3(x,GROUND_Y+0.01,10),Vector3(12,0.02,320),asphalt)
		for z in range(-145,165,9):
			if _near_crossing(z,CORE_Z):
				continue
			_stamp(Vector3(x,GROUND_Y+0.025,z),Vector3(0.12,0.015,3.5),paint)
		for i in range(CORE_Z.size()-1):
			var length: float = CORE_Z[i+1]-CORE_Z[i]-16.0
			for side in [-1.0,1.0]:
				_stamp(Vector3(x+side*7.5,GROUND_Y+0.025,(CORE_Z[i]+CORE_Z[i+1])/2),Vector3(3,0.04,length),pavement)
	for z in CORE_Z:
		_stamp(Vector3(0,GROUND_Y+0.011,z),Vector3(320,0.022,12),asphalt)
		for x in range(-155,160,9):
			if _near_crossing(x,CORE_X):
				continue
			_stamp(Vector3(x,GROUND_Y+0.027,z),Vector3(3.5,0.015,0.12),paint)
		for i in range(CORE_X.size()-1):
			var length: float = CORE_X[i+1]-CORE_X[i]-16.0
			for side in [-1.0,1.0]:
				_stamp(Vector3((CORE_X[i]+CORE_X[i+1])/2,GROUND_Y+0.025,z+side*7.5),Vector3(length,0.04,3),pavement)
	var curb := _material(Color("c8c9bf"))
	var yellow := _material(Color("cdbb68"))
	for x in CORE_X:
		for i in range(CORE_Z.size()-1):
			var length: float = CORE_Z[i+1]-CORE_Z[i]-15
			for side in [-1.0,1.0]:
				_stamp(Vector3(x+side*6.04,GROUND_Y+0.045,(CORE_Z[i]+CORE_Z[i+1])/2),Vector3(0.16,0.08,length),curb)
				for line in [5.35,5.62]:
					_stamp(Vector3(x+side*line,GROUND_Y+0.038,(CORE_Z[i]+CORE_Z[i+1])/2),Vector3(0.09,0.012,length),yellow)
	for z in CORE_Z:
		for i in range(CORE_X.size()-1):
			var length: float = CORE_X[i+1]-CORE_X[i]-15
			for side in [-1.0,1.0]:
				_stamp(Vector3((CORE_X[i]+CORE_X[i+1])/2,GROUND_Y+0.045,z+side*6.04),Vector3(length,0.08,0.16),curb)
				for line in [5.35,5.62]:
					_stamp(Vector3((CORE_X[i]+CORE_X[i+1])/2,GROUND_Y+0.038,z+side*line),Vector3(length,0.012,0.09),yellow)
	for x in CORE_X:
		for z in CORE_Z:
			for sx in [-1.0,1.0]:
				for sz in [-1.0,1.0]:
					_stamp(Vector3(x+sx*7.5,GROUND_Y+0.025,z+sz*7.5),Vector3(3,0.04,3),pavement)
			# Stop/give-way markings keep intersections visibly distinct from through lanes.
			for side in [-1.0,1.0]:
				_stamp(Vector3(x+side*2.8,GROUND_Y+0.04,z-side*12),Vector3(4.4,0.012,0.20),paint)
			for side in [-1.0,1.0]:
				_stamp(Vector3(x-side*12,GROUND_Y+0.04,z-side*2.8),Vector3(0.20,0.012,4.4),paint)
			if z == 16.0:
				for i in range(-4,5):
					_stamp(Vector3(x+i*1.15,GROUND_Y+0.04,z+12),Vector3(0.6,0.012,3.6),paint)
			_street_sign(Vector3(x+8.4,GROUND_Y,z+8.4),CORE_X.find(x),CORE_Z.find(z))

func _near_crossing(value: float,crossings: Array) -> bool:
	for cross in crossings:
		if absf(value-cross)<9.0:
			return true
	return false

func _neighbourhoods() -> void:
	var colors := [Color("b57659"),Color("c4976f"),Color("9b6b58"),Color("dad1bc")]
	var number := 1
	for ix in range(CORE_X.size()-1):
		for iz in range(CORE_Z.size()-1):
			var cx: float = (CORE_X[ix]+CORE_X[ix+1])/2
			var cz: float = (CORE_Z[iz]+CORE_Z[iz+1])/2
			if ix == 2 and iz in [2,3]:
				continue # Existing vehicle courtyard and its access to College Road.
			if (ix == 0 and iz == 1) or (ix == 4 and iz == 2):
				_park(Vector3(cx,GROUND_Y,cz))
				continue
			var width: float = CORE_X[ix+1]-CORE_X[ix]
			var offset := width*0.15 if width<=40.0 else width*0.22
			for row in [0,1]:
				for side in [-1.0,1.0]:
					var source_id:=number;number+=1
					if (source_id-1)%6!=0 and not retained_tenancies.has("House"+str(source_id)):continue
					var house := preload("res://town/house.gd").new()
					house.stream_managed = true
					house.name = "House"+str(source_id)
					var district: Dictionary = ATLAS.at(Vector3(cx,GROUND_Y,cz))
					house.address = str(source_id)+" · "+ATLAS.STREET_Z[iz if row==0 else iz+1]
					house.house_number = source_id
					house.neighbourhood = district.name
					house.architecture = district.styles[(source_id+row)%district.styles.size()]
					house.variant = source_id
					house.brick_color = district.brick.lightened(float(source_id%4)*0.035)
					house.roof_color = district.roof
					house.position = Vector3(cx+side*offset,GROUND_Y+0.065,CORE_Z[iz]+19 if row==0 else CORE_Z[iz+1]-19)
					house.rotation.y = PI if row==0 else 0.0
					add_child(house)
					houses.append(house)
					var door_point: Vector3 = house.entrance()
					var path_z: float = (door_point.z+(CORE_Z[iz] if row==0 else CORE_Z[iz+1]))/2
					_stamp(Vector3(house.position.x,GROUND_Y+0.03,path_z),Vector3(2.6,0.04,maxf(1,absf(door_point.z-(CORE_Z[iz] if row==0 else CORE_Z[iz+1]))-7)),pavement)


	next_original_house=number

func _park(center: Vector3) -> void:
	var park := preload("res://town/park.gd").new()
	park.park_name = "Forest Recreation Ground" if center.x<0 else "Arboretum Gardens"
	park.position = center
	add_child(park)
	parks.append(park)
	for x in [-12.0,12.0]:
		for z in [-10.0,12.0]:
			_tree(center+Vector3(x,0,z))

func _tree(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.17
	cylinder.bottom_radius = 0.25
	cylinder.height = 2.4
	cylinder.radial_segments = 8
	trunk.mesh = cylinder
	trunk.material_override = _material(Color("705340"))
	trunk.position = pos+Vector3(0,1.2,0)
	add_child(trunk)
	var leaves := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.0
	sphere.radial_segments = 12
	sphere.rings = 6
	leaves.mesh = sphere
	leaves.material_override = _material(Color("43704e"))
	leaves.position = pos+Vector3(0,3.4,0)
	add_child(leaves)

func _street_sign(pos: Vector3,ix: int,iz: int) -> void:
	var metal := _material(Color("505e66"))
	_stamp(pos+Vector3(0,1.4,0),Vector3(0.10,2.8,0.10),metal)
	var label := Label3D.new()
	label.text = ATLAS.STREET_X[ix]+"\n"+ATLAS.STREET_Z[iz]
	label.font_size = 24
	label.pixel_size = 0.009
	label.position = pos+Vector3(0,2.6,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("dae5eb")
	add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _stamp(pos: Vector3,size: Vector3,material: Material) -> void:
	var key := material.get_instance_id()
	if not batches.has(key):
		batches[key] = {"material":material,"transforms":[]}
	batches[key].transforms.append(Transform3D(Basis.IDENTITY.scaled(size),pos))

func _finish_batches() -> void:
	for data in batches.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = BoxMesh.new()
		multi.mesh.size = Vector3.ONE
		multi.instance_count = data.transforms.size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i,data.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = data.material
		add_child(instance)
	batches.clear()

var detail_queue: Array[Node3D] = []
var detail_clock := .3
func _process(delta: float) -> void:
	detail_clock+=delta
	if detail_clock>=.2:
		detail_clock=0
		var game:=get_parent().get_parent()
		if not is_instance_valid(game.player): return
		var point: Vector3=game.player.global_position
		for site in outer_parks:
			var distance:float=point.distance_squared_to(site.point)
			if distance<165*165 and not is_instance_valid(site.node):
				var park:=preload("res://town/park.gd").new()
				park.park_name=site.name; park.position=site.point; add_child(park); parks.append(park); site.node=park
			elif distance>230*230 and is_instance_valid(site.node) and not is_instance_valid(site.node.user):
				parks.erase(site.node); site.node.queue_free(); site.node=null
		detail_queue.clear()
		for house in houses:
			var distance:=house.global_position.distance_squared_to(point)
			if distance>250*250: house.deactivate()
			if distance<180*180 and not house.stream_active: detail_queue.append(house)
			elif house.stream_active:
				house.update_detail(distance<10000)
				if distance<10000 and not house.exterior_built: detail_queue.append(house)
		detail_queue.sort_custom(func(a,b):return a.global_position.distance_squared_to(point)<b.global_position.distance_squared_to(point))
	# Two nearest buildings per frame keep up with a moving player; each is cheap and nearest-first.
	for step in range(2):
		if detail_queue.is_empty(): break
		var house: Node3D=detail_queue.pop_front()
		if not house.stream_active: house.activate()
		else: house.ensure_detail()

func _outlying_homes() -> void:
	var number:=next_original_house
	for district in districts:
		if district.id=="centre": continue
		for offset in [-87.5,-37.5,12.5,62.5]:
			var z:float=district.center.z+offset
			for section in range(12):
				var x:float=district.center.x-99+section*18
				var middle:=Vector3(x,GROUND_Y,z)
				if not W.place_clear(middle,10) or not W.rail_clear(middle,20): continue
				local_roads.append({"point":middle+Vector3(0,.025,0),"size":Vector3(18,.04,5),"material":0})
				for side in [-1,1]: local_roads.append({"point":middle+Vector3(0,.03,side*3.5),"size":Vector3(18,.06,2),"material":1})
		var district_homes:=0
		for row in range(7):
			for column in range(8):
				var point: Vector3=district.center+Vector3((column-3.5)*23,0,(row-3)*25)
				point.y=GROUND_Y+.065
				if not W.contains(point) or not W.place_clear(point,15) or not W.road_clear(point,13) or not W.rail_clear(point,45): continue
				var space_clear:=true
				for pad in W.helipads():
					if Vector2(point.x,point.z).distance_to(pad)<24: space_clear=false
				for site in outer_parks:
					if absf(point.x-site.point.x)<35 and absf(point.z-site.point.z)<35: space_clear=false
				if not space_clear: continue
				var bus_clear:=true
				for line in [-440.0,440.0]:
					if absf(point.x-line)<24: bus_clear=false
				for line in [-440.0,440.0]:
					if absf(point.z-line)<24: bus_clear=false
				if not bus_clear: continue
				var source_id:=number;number+=1
				if district_homes>=6 and not retained_tenancies.has("House"+str(source_id)):continue
				district_homes+=1
				var house:=preload("res://town/house.gd").new();house.set_meta("outer_home",true)
				house.stream_managed=true
				house.name="House"+str(source_id); house.house_number=source_id; house.variant=source_id
				house.neighbourhood=district.name
				house.architecture=district.styles[source_id%district.styles.size()]
				house.brick_color=district.brick.lightened(float(source_id%4)*.035); house.roof_color=district.roof
				house.address=str(source_id)+" · "+str(district.name)+" "+("Gardens" if row%2==0 else "Close")
				house.position=point; house.rotation.y=PI if row%2==0 else 0.0
				var door_point:Vector3=point+Vector3(0,0,-10 if row%2==0 else 10)
				local_roads.append({"point":Vector3(door_point.x,GROUND_Y+.035,door_point.z),"size":Vector3(2.5,.04,5),"material":1})
				add_child(house); houses.append(house)

func nearby_houses(point:Vector3) -> Array:
	var found:Array=[]
	for x in range(floori((point.x-11)/64),floori((point.x+11)/64)+1):
		for z in range(floori((point.z-11)/64),floori((point.z+11)/64)+1):
			found.append_array(house_cells.get(Vector2i(x,z),[]))
	return found
