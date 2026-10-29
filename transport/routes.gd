extends RefCounted
# Shorter district circuits use the shared distributors, with stops away from junctions.
static func definitions() -> Array[Dictionary]:
	return [
		{"number":"60","name":"Victoria Centre • Gedling","color":Color("62bfdf"),"london":false,
		"points":[Vector2(-320,240),Vector2(440,240),Vector2(440,-240),Vector2(-320,-240)],
		"express_stops":[[Vector2(-230,240),Vector2.RIGHT,"Victoria Centre"],[Vector2(380,240),Vector2.RIGHT,"Gedling connection"],[Vector2(440,-20),Vector2.UP,"Gedling"],[Vector2(220,-240),Vector2.LEFT,"Shops and retail quarter"],[Vector2(-320,-180),Vector2.DOWN,"Council Motor Quarter link"]]},
		{"number":"61","name":"Mapperley • Forest Fields","color":Color("8cd4e9"),"london":false,
		"points":[Vector2(-440,-440),Vector2(320,-440),Vector2(320,-120),Vector2(-440,-120)],
		"express_stops":[[Vector2(0,-440),Vector2.RIGHT,"Robotics Plaza • EV service interchange"],[Vector2(220,-440),Vector2.RIGHT,"Mapperley"],[Vector2(320,-330),Vector2.DOWN,"Mapperley Gardens"],[Vector2(-230,-120),Vector2.LEFT,"Central Supermarket"],[Vector2(-440,-330),Vector2.UP,"Forest Fields"]]},
		{"number":"44","name":"Carlton • City Centre","color":Color("bf384b"),"london":false,
		"points":[Vector2(-140,140),Vector2(440,140),Vector2(440,440),Vector2(-140,440)],
		"express_stops":[[Vector2(0,140),Vector2.RIGHT,"Council vehicle sales"],[Vector2(230,140),Vector2.RIGHT,"Carlton Road"],[Vector2(440,340),Vector2.DOWN,"Carlton Station link"],[Vector2(230,440),Vector2.LEFT,"Carlton Supermarket"],[Vector2(0,440),Vector2.LEFT,"Central Station link"]]},
		{"number":"C1","name":"Lenton • Racing Ground • Parks","color":Color("c72234"),"london":true,
		"points":[Vector2(-440,140),Vector2(140,140),Vector2(140,440),Vector2(-440,440)],
		"express_stops":[[Vector2(-230,140),Vector2.RIGHT,"Lenton shops"],[Vector2(0,140),Vector2.RIGHT,"Council Motor Quarter"],[Vector2(140,340),Vector2.DOWN,"Community Gardens"],[Vector2(-230,440),Vector2.LEFT,"Riverside Park"],[Vector2(-440,340),Vector2.UP,"Council Racing Ground"]]}
	]
