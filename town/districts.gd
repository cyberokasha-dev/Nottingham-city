extends RefCounted
# A complete atlas for the compact fictional city; all systems use these same bounds.
const STREET_X := ["Alfreton Road","Mansfield Road","Milton Street","Queen Street","Woodborough Road","Westdale Lane"]
const STREET_Z := ["Mapperley Plains","Forest Road","Parliament Street","Upper Parliament Street","Carlton Road"]
static func definitions() -> Array[Dictionary]:
	return [
		{"id":"centre","name":"City Centre","bounds":Rect2(-40,16,120,164),"center":Vector3(20,-5.02,106),"styles":["townhouse","victorian"],"brick":Color("ab715d"),"roof":Color("454c59"),"rank":Vector3(45.5,-5.02,30),"heading":0.0},
		{"id":"forest","name":"Forest Fields","bounds":Rect2(-170,-150,130,166),"center":Vector3(-105,-5.02,-96),"styles":["terrace","victorian"],"brick":Color("a45d49"),"roof":Color("3d4852"),"rank":Vector3(-134.5,-5.02,-90),"heading":0.0},
		{"id":"mapperley","name":"Mapperley","bounds":Rect2(-40,-150,120,166),"center":Vector3(20,-5.02,-96),"styles":["villa","semi"],"brick":Color("d3b99a"),"roof":Color("75634e"),"rank":Vector3(45.5,-5.02,-90),"heading":0.0},
		{"id":"gedling","name":"Gedling","bounds":Rect2(80,-150,90,166),"center":Vector3(112,-5.02,-96),"styles":["cottage","semi"],"brick":Color("c69775"),"roof":Color("6c5448"),"rank":Vector3(134.5,-5.02,-90),"heading":PI},
		{"id":"lenton","name":"Lenton","bounds":Rect2(-170,16,130,164),"center":Vector3(-105,-5.02,110),"styles":["terrace","townhouse"],"brick":Color("b17c62"),"roof":Color("4c5261"),"rank":Vector3(-85.5,-5.02,110),"heading":PI},
		{"id":"carlton","name":"Carlton","bounds":Rect2(80,16,90,164),"center":Vector3(112,-5.02,110),"styles":["modern","villa"],"brick":Color("ded6c3"),"roof":Color("525f69"),"rank":Vector3(145.5,-5.02,110),"heading":0.0}
	]
static func at(point: Vector3) -> Dictionary:
	for district in definitions():
		if district.bounds.has_point(Vector2(point.x,point.z)): return district
	return definitions()[0]
static func street_at(point: Vector3) -> String:
	var closest := INF
	var name := "Outer Ring Road"
	var xs := [-140.0,-80.0,-40.0,40.0,80.0,140.0]
	var zs := [-120.0,-60.0,16.0,80.0,140.0]
	for i in range(xs.size()):
		if absf(point.x-xs[i])<closest:
			closest = absf(point.x-xs[i])
			name = STREET_X[i]
	for i in range(zs.size()):
		if absf(point.z-zs[i])<closest:
			closest = absf(point.z-zs[i])
			name = STREET_Z[i]
	return name
