extends CanvasLayer
## One consistent HUD, with positions shared across resolutions.
var game: Node
var root: Control
var wallet: Label
var health: ProgressBar
var life: Label
var character_buttons: Array[Button]=[]
var shortcuts: HBoxContainer
var clock:=0.0
var mobile_styled:=false

func _ready() -> void:
	layer=19
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	wallet=Label.new()
	wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	wallet.add_theme_font_size_override("font_size",24)
	wallet.add_theme_color_override("font_shadow_color",Color.BLACK)
	wallet.add_theme_constant_override("shadow_offset_x",2)
	wallet.add_theme_constant_override("shadow_offset_y",2)
	root.add_child(wallet)
	health=ProgressBar.new()
	health.show_percentage=false
	health.max_value=100
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("59c88d")
	style.set_corner_radius_all(4)
	health.add_theme_stylebox_override("fill",style)
	root.add_child(health)
	life=Label.new()
	life.add_theme_font_size_override("font_size",13)
	root.add_child(life)
	for i in range(game.party.PROFILES.size()):
		var b:=Button.new()
		b.text=game.party.PROFILES[i].name
		b.tooltip_text="Choose "+b.text
		b.add_theme_font_size_override("font_size",13)
		b.focus_mode=Control.FOCUS_NONE
		b.pressed.connect(func():
			game.party.toggle_wheel()
			if game.party.wheel.visible: game.party.wheel.highlight=i)
		root.add_child(b)
		character_buttons.append(b)
	shortcuts=HBoxContainer.new()
	root.add_child(shortcuts)
	for item in [["P  Phone","phone"],["N  Map","map"],["C  Characters","characters"]]:
		var b:=Button.new()
		b.text=item[0]
		b.focus_mode=Control.FOCUS_NONE
		b.pressed.connect(func():
			if item[1]=="phone": game.phone.toggle()
			elif item[1]=="map": game.city_map.open()
			else: game.party.toggle_wheel())
		shortcuts.add_child(b)

func _process(delta: float) -> void:
	var size:=get_viewport().get_visible_rect().size
	root.visible=not game.phone.panel.visible and not game.city_map.expanded and not game.party.wheel.visible
	var mobile:bool=game.get_meta("phone_touch",false)
	wallet.position=Vector2(size.x-280,20)
	wallet.size=Vector2(260,65)
	game.town.get_node("Spedometer").position=Vector2(size.x-200,100)
	health.position=Vector2(20,size.y-36)
	health.size=Vector2(250,9)
	life.position=Vector2(20,size.y-59)
	for i in range(character_buttons.size()):
		character_buttons[i].position=Vector2(size.x-300+i*70,size.y-55)
		character_buttons[i].size=Vector2(68,34)
		character_buttons[i].modulate=Color.WHITE if i==game.party.selected else Color("8c9ca8")
	shortcuts.position=Vector2(size.x-320,size.y-100)
	var p=game.player
	p.prompt.position=Vector2(285,maxf(80,size.y-120)) if size.x>=900 else Vector2(20,75)
	p.prompt.size=Vector2(maxf(280,size.x-600),65)
	p.prompt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if mobile:
		# Touch controls occupy only the bottom corners and the top-right edge.
		var safe:Vector4=game.get_meta("phone_safe",Vector4.ZERO)
		if not mobile_styled:
			mobile_styled=true
			wallet.add_theme_font_size_override("font_size",16)
		wallet.position=Vector2(12+safe.x,62+safe.y);wallet.size=Vector2(170,40);wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		health.position=Vector2(12+safe.x,112+safe.y);health.size=Vector2(120,7)
		life.position=Vector2(12+safe.x,91+safe.y)
		shortcuts.hide()
		for button in character_buttons: button.hide()
		if not p.prompt.has_meta("phone_style"):
			p.prompt.set_meta("phone_style",true)
			p.prompt.add_theme_font_size_override("font_size",14)
			p.prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
		p.prompt.position=Vector2(12,270) if size.y>size.x else Vector2(170,66)
		p.prompt.size=Vector2(minf(260,size.x-24),64)
		p.prompt.clip_text=true
		if p.prompt.text.begins_with("ON FOOT"):
			var lines:PackedStringArray=p.prompt.text.split("\n")
			lines.remove_at(0)
			if not lines.is_empty() and lines[0].begins_with("Walk to a vehicle"):lines.remove_at(0)
			p.prompt.text="\n".join(lines)
		p.prompt.text=p.prompt.text.replace("△ E:","△").replace("E:","△").replace("P:","Phone:").replace("B:","Camera:")
		game.town.get_node("Spedometer").position=Vector2(12,74)
	clock+=delta
	if clock<0.25: return
	clock=0
	wallet.text=game.economy.pounds(game.economy.cash(p))+("" if mobile else "\n"+str(p.profile.name))
	health.value=p.health
	life.text="HEALTH  %d / 100" % p.health
