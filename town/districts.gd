extends RefCounted
# A complete atlas for the compact fictional city; all systems use these same bounds.
const STREET_X := ["Alfreton Road","Mansfield Road","Milton Street","Queen Street","Woodborough Road","Westdale Lane"]
const STREET_Z := ["Mapperley Plains","Forest Road","Parliament Street","Upper Parliament Street","Carlton Road"]
static func definitions() -> Array[Dictionary]:
	return [
		{"id":"centre","name":"City Centre","bounds":Rect2(-170,-150,340,330),"center":Vector3(20,-5.02,106),"styles":["townhouse","victorian"],"brick":Color("ab715d"),"roof":Color("454c59"),"rank":Vector3(45.5,-5.02,30),"heading":0.0},
		{"id":"forest","name":"Forest Fields","bounds":Rect2(-550,-540,380,390),"center":Vector3(-280,-5.02,-310),"styles":["terrace","victorian"],"brick":Color("a45d49"),"roof":Color("3d4852"),"rank":Vector3(-314.5,-5.02,-340),"heading":0.0},
		{"id":"mapperley","name":"Mapperley","bounds":Rect2(-170,-600,420,450),"center":Vector3(160,-5.02,-320),"styles":["villa","semi"],"brick":Color("d3b99a"),"roof":Color("75634e"),"rank":Vector3(145.5,-5.02,-340),"heading":0.0},
		{"id":"gedling","name":"Gedling","bounds":Rect2(170,-360,430,510),"center":Vector3(330,-5.02,-25),"styles":["cottage","semi"],"brick":Color("c69775"),"roof":Color("6c5448"),"rank":Vector3(325.5,-5.02,190),"heading":0.0},
		{"id":"lenton","name":"Lenton","bounds":Rect2(-600,150,600,400),"center":Vector3(-230,-5.02,330),"styles":["terrace","townhouse"],"brick":Color("b17c62"),"roof":Color("4c5261"),"rank":Vector3(-314.5,-5.02,290),"heading":0.0},
		{"id":"carlton","name":"Carlton","bounds":Rect2(0,150,600,450),"center":Vector3(290,-5.02,320),"styles":["modern","villa"],"brick":Color("ded6c3"),"roof":Color("525f69"),"rank":Vector3(325.5,-5.02,350),"heading":0.0}
	]
static func at(point: Vector3) -> Dictionary:
	var nearest: Dictionary=definitions()[0]
	var gap:=INF
	for district in definitions():
		var distance: float=district.center.distance_squared_to(point)
		if distance<gap: gap=distance; nearest=district
	return nearest
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
