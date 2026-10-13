extends RefCounted
# Real service identities and principal places, compressed onto the game's road grid.
# City Link is a fictional local connector using a London-inspired red double-decker.
static func definitions() -> Array[Dictionary]:
	return [
		{"number":"60","name":"Gedling via Mapperley","color":Color("62bfdf"),"london":false,
		"points":[Vector2(40,80),Vector2(40,-60),Vector2(80,-60),Vector2(80,-120),Vector2(140,-120),Vector2(140,80)],
		"stops":["Queen Street • City Centre","Woodborough Road","Mapperley Shops","Westdale Lane","Gedling • Harviston Avenue","Victoria Centre connection"]},
		{"number":"61","name":"Calverton via Mapperley","color":Color("8cd4e9"),"london":false,
		"points":[Vector2(-40,16),Vector2(-40,-120),Vector2(140,-120),Vector2(140,-60),Vector2(40,-60),Vector2(40,16)],
		"stops":["Parliament Street","Mapperley Plains","Calverton • St Wilfrids Square","Gedling Country Park","Mapperley Shops","Victoria Centre connection"]},
		{"number":"44","name":"Gedling via Netherfield","color":Color("bf384b"),"london":false,
		"points":[Vector2(80,140),Vector2(80,16),Vector2(140,16),Vector2(140,-60),Vector2(-40,-60),Vector2(-40,140)],
		"stops":["City Centre","Colwick","Netherfield","Gedling","Westdale Lane East","Parliament Street connection"]},
		{"number":"C1","name":"City Link • Parks circular","color":Color("c72234"),"london":true,
		"points":[Vector2(-140,80),Vector2(-140,-60),Vector2(-80,-60),Vector2(-80,16),Vector2(80,16),Vector2(80,80)],
		"stops":["Forest Recreation Ground","Arboretum","Mansfield Road","Victoria Centre","Market Square connection","City Centre • Parks"]}
	]
