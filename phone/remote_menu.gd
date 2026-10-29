extends RefCounted
## A paired phone operates the same visible controls and their existing validations.
## No scene paths or arbitrary method names are accepted from the network.
var game: Node
var controls := {}
var atlas := ""
var focus_id := ""
var last_context := ""
var map_cursor := Vector2(0.5,0.5)
var screen_mode:=false
var screen_point:=Vector2(.5,.5)
var dropdown: WeakRef
var text_entry: WeakRef
var text_serial:=0

func _dropdown() -> OptionButton:
	var node=dropdown.get_ref() if dropdown!=null else null
	return node if is_instance_valid(node) and node.is_visible_in_tree() and node.get_popup().visible else null

func _entry() -> LineEdit:
	var node=text_entry.get_ref() if text_entry!=null else null
	return node if is_instance_valid(node) and node.is_visible_in_tree() and node.editable else null

func context() -> String:
	if _entry()!=null: return "text"
	if _dropdown()!=null: return "list"
	if screen_mode: return "screen"
	return surface_context()

func surface_context() -> String:
	if game.phone.panel.visible: return "phone"
	if game.city_map.expanded: return "map"
	if game.party.wheel.visible: return "characters"
	if game.conversation.active: return "conversation"
	return "play"

func snapshot() -> Dictionary:
	controls.clear()
	var p = game.player
	var mode := "On foot"
	if p.driving or p.get_meta("service_driving",false): mode = "Driving"
	elif is_instance_valid(p.riding_service): mode = "Helicopter" if p.riding_service == game.helicopters else str(game.cabs.cars[int(p.get_meta("cab_car",0))].get("kind","Aurora"))+" passenger"
	elif is_instance_valid(p.riding_bus): mode = "Train passenger" if p.riding_bus.is_in_group("city_trains") else "Bus passenger"
	var result := {"t":"ui", "version":2, "context":context(), "mode":mode, "character":str(p.profile.name), "prompt":str(p.prompt.text), "rows":[]}
	match result.context:
		"phone":
			_collect(game.phone.panel,result.rows)
		"characters":
			for i in range(game.party.PROFILES.size()):
				result.rows.append({"kind":"character","id":i,"text":game.party.PROFILES[i].name,"selected":i==game.party.selected,"disabled":not game.party.can_control(i)})
		"map":
			var map = game.city_map
			if atlas == "" and map.atlas_texture != null:
				atlas = "data:image/png;base64,"+Marshalls.raw_to_base64(map.atlas_texture.get_image().save_png_to_buffer())
			result.map = {"center":[map.center.x,map.center.y],"zoom":map.zoom,"player":[p.position.x,p.position.z],"selected":str(map.selected_place.get("name","Tap a place to select it")),"destination":[map.destination.x,map.destination.z] if map.destination_active else [],"route":[],"markers":[]}
			var path: PackedVector3Array = game.helicopters.remaining_route(p) if p.riding_service == game.helicopters else game.cabs.remaining_route(p)
			if path.is_empty(): path = map.walking_route
			for point in path: result.map.route.append([point.x,point.z])
			for location in game.economy.locations:
				if not str(location.name).begins_with("House "):
					result.map.markers.append([location.point.x,location.point.z,str(location.name)])
			_collect(map,result.rows)
		"conversation":
			_collect(game.conversation.panel,result.rows)
		"play":
			if game.bus_recitation.panel.visible: _collect(game.bus_recitation.panel,result.rows)
			_collect(p.controls.panel,result.rows)
	return result

# Only controller status crosses the link; every menu remains on the game screen.
func state() -> Dictionary:
	var p = game.player
	var ride:=""
	var key:String=game.economy.key_for(p)
	for service in [game.helicopters,game.cabs]:
		if service.bookings.has(key): ride=("helicopter:" if service==game.helicopters else str(service.bookings[key].get("kind","Aurora")).to_lower()+":")+str(service.bookings[key].state)
	var result: Dictionary={"t":"ui","version":4,"context":context(),"surface":surface_context(),"screen":screen_mode,"mode":"Driving" if p.driving or p.get_meta("service_driving",false) else "On foot","character":str(p.profile.name),"ride":ride}
	if _entry()!=null:
		var entry:=_entry()
		result.entry={"id":text_serial,"label":entry.placeholder_text,"value":"" if entry.secret else entry.text,"secret":entry.secret,"max":entry.max_length if entry.max_length>0 else 256}
	return result

func _items() -> Array:
	var rows: Array = []
	controls.clear()
	if surface_context()=="phone": _collect(game.phone.panel,rows)
	elif surface_context()=="conversation": _collect(game.conversation.panel,rows)
	var result: Array = []
	for item in rows:
		if item.kind in ["button","toggle","select","tabs","text"] and not item.get("disabled",false): result.append(item)
	return result

func focus_menu() -> void:
	if context() in ["screen","text","list"]: return
	var items := _items()
	if items.is_empty(): return
	if surface_context()=="phone" and focus_id==str(game.phone.cancel_button.get_instance_id()) and game.phone.unlock_button.visible and not game.phone.unlock_button.disabled:
		focus_id=str(game.phone.unlock_button.get_instance_id())
	if context()!=last_context or focus_id=="" or not items.any(func(item):return str(item.id)==focus_id):
		focus_id=""; last_context=context()
		if context()=="phone":
			for node in [game.phone.preferred_focus(),game.phone.unlock_button,game.phone.confirm_button,game.phone.cancel_button,game.phone.book_button]:
				if is_instance_valid(node) and node.is_visible_in_tree() and not node.disabled:
					focus_id=str(node.get_instance_id()); break
	if focus_id=="" or not controls.has(focus_id): focus_id=str(items[0].id)
	_focus()

func _focus() -> void:
	if not controls.has(focus_id): return
	var node = controls[focus_id].get_ref()
	if not is_instance_valid(node) or not node is Control: return
	node.focus_mode=Control.FOCUS_ALL
	var outline := StyleBoxFlat.new()
	outline.bg_color=Color(0.2,0.6,0.9,0.12)
	outline.border_color=Color("71d6ff")
	outline.set_border_width_all(3)
	outline.set_corner_radius_all(5)
	node.add_theme_stylebox_override("focus",outline)
	node.grab_focus()
	var parent = node.get_parent()
	while parent!=null:
		if parent is ScrollContainer: parent.ensure_control_visible(node)
		parent=parent.get_parent()

func navigate(direction: String) -> void:
	if _entry()!=null: return
	if _dropdown()!=null:
		_move_option(-1 if direction in ["left","up"] else 1)
		return
	if screen_mode:
		var delta: Vector2={"up":Vector2(0,-.035),"down":Vector2(0,.035),"left":Vector2(-.035,0),"right":Vector2(.035,0)}.get(direction,Vector2.ZERO)
		move_screen(delta)
		return
	focus_menu()
	if context()=="characters":
		game.party.wheel.highlight=posmod(game.party.wheel.highlight+(1 if direction in ["down","right"] else -1),4)
		game.party.wheel.queue_redraw()
		return
	if context()=="map":
		var delta := {"up":Vector2(0,-0.06),"down":Vector2(0,0.06),"left":Vector2(-0.06,0),"right":Vector2(0.06,0)}
		var change:Vector2=delta.get(direction,Vector2.ZERO)
		var target:=map_cursor+change
		if target.x<0.04 or target.x>0.96 or target.y<0.04 or target.y>0.96:
			game.city_map.center+=change*game.city_map._span()
			game.city_map._bound_center()
		map_cursor=target.clamp(Vector2(0.04,0.04),Vector2(0.96,0.96))
		game.city_map.controller_cursor=map_cursor
		game.city_map.queue_redraw()
		return
	var items := _items()
	if items.is_empty(): return
	var index := 0
	for i in range(items.size()):
		if str(items[i].id)==focus_id: index=i
	var item: Dictionary=items[index]
	var node=controls[focus_id].get_ref() if controls.has(focus_id) else null
	if is_instance_valid(node) and node.get_meta("phone_grid",0)>0:
		var siblings:Array=node.get_parent().get_children().filter(func(n):return n is Button and n.is_visible_in_tree() and not n.disabled)
		var offset:int=int(node.get_meta("phone_grid")) if direction in ["up","down"] else 1
		var target:int=posmod(siblings.find(node)+offset*(1 if direction in ["down","right"] else -1),siblings.size())
		focus_id=str(siblings[target].get_instance_id())
	elif direction in ["left","right"] and item.kind in ["select","tabs"]:
		var target:=int(item.value)+(1 if direction=="right" else -1)
		if target>=0 and target<item.options.size(): _control({"id":item.id,"value":target})
	else:
		index=posmod(index+(1 if direction in ["down","right"] else -1),items.size())
		focus_id=str(items[index].id)
	_focus()

func confirm() -> void:
	if _entry()!=null: return
	if _dropdown()!=null:
		var option:=_dropdown()
		var index:=option.get_popup().get_focused_item()
		option.get_popup().hide(); dropdown=null
		if index>=0 and not option.is_item_disabled(index) and not option.is_item_separator(index):
			option.select(index); option.item_selected.emit(index)
		focus_menu()
		return
	if screen_mode: click_screen(); return
	if context()=="characters":
		game.party.choose(game.party.wheel.highlight)
	elif context()=="map":
		command({"action":"map_pick","x":map_cursor.x,"y":map_cursor.y})
		if game.city_map.expanded:
			game.city_map.close(); game.phone.select_location(game.city_map.selected_place)
		focus_id=""
		focus_menu()
	else:
		focus_menu()
		var node=controls[focus_id].get_ref() if controls.has(focus_id) else null
		if node is OptionButton: open_options(node)
		elif node is LineEdit: open_text(node)
		else: _control({"id":focus_id})
		focus_menu()

func select_tab(offset: int) -> void:
	if _dropdown()!=null: _move_option(offset*10); return
	if _entry()!=null: return
	if screen_mode: scroll_screen(offset*120); return
	if context()=="map":
		game.city_map.zoom=clampf(game.city_map.zoom*(1.3 if offset>0 else 1/1.3),1,16)
		game.city_map._bound_center()
	elif context()=="phone":
		var pages:Array=["home","book","rents","jobs","wallet","passes","council","settings","account"]
		game.phone.apps.open(pages[posmod(maxi(0,pages.find(game.phone.apps.page))+offset,pages.size())])
		focus_id=""; focus_menu()

func _collect(node: Node, rows: Array) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	var id := str(node.get_instance_id())
	if node is TabContainer:
		var options := []
		for i in range(node.get_tab_count()): options.append({"text":node.get_tab_title(i),"disabled":node.is_tab_disabled(i)})
		if node.get_tab_bar().visible:
			controls[id] = weakref(node)
			rows.append({"id":id,"kind":"tabs","options":options,"value":node.current_tab})
		_collect(node.get_current_tab_control(),rows)
		return
	if node is OptionButton:
		var options := []
		for i in range(node.item_count): options.append({"text":node.get_item_text(i),"disabled":node.is_item_disabled(i)})
		controls[id] = weakref(node)
		rows.append({"id":id,"kind":"select","text":node.tooltip_text,"options":options,"value":node.selected,"disabled":node.disabled})
		return
	if node is LineEdit:
		controls[id] = weakref(node)
		rows.append({"id":id,"kind":"text","text":node.placeholder_text,"value":"" if node.secret else node.text,"max":node.max_length,"disabled":not node.editable})
		return
	if node is BaseButton:
		controls[id] = weakref(node)
		rows.append({"id":id,"kind":"toggle" if node.toggle_mode else "button","text":node.text,"value":node.button_pressed,"disabled":node.disabled})
		return
	if node is Label or node is RichTextLabel:
		if node.text != "": rows.append({"kind":"label","text":node.text})
		return
	for child in node.get_children(): _collect(child,rows)

func command(data: Dictionary) -> void:
	var action := str(data.get("action",""))
	if action=="screen": set_screen(not screen_mode); return
	if action=="play":
		set_screen(false)
		if game.phone.panel.visible: game.phone.toggle()
		game.city_map.close(); game.party.wheel.hide()
		if game.conversation.active: game.conversation.finish()
		return
	if action=="pointer_move":
		if screen_mode and context()=="screen": move_screen(Vector2(clampf(float(data.get("x",0)),-.25,.25),clampf(float(data.get("y",0)),-.25,.25)))
		return
	if action=="text_input":
		if _entry()!=null and int(data.get("id",-1))==text_serial:
			var field:=_entry(); field.text=str(data.get("value","")).left(field.max_length if field.max_length>0 else 256)
			field.text_changed.emit(field.text); text_entry=null; field.release_focus()
		return
	if action=="nav": navigate(str(data.get("value","down"))); return
	if action=="confirm": confirm(); return
	if action=="tab": select_tab(int(data.get("value",1))); return
	match action:
		"phone":
			close_submenus(); set_screen(false)
			game.city_map.close(); game.party.wheel.hide()
			game.phone.toggle()
			focus_id=""; focus_menu()
		"map":
			close_submenus(); set_screen(false); game.phone.panel.hide()
			game.party.wheel.hide()
			if game.city_map.expanded: game.city_map.close()
			else: game.city_map.open(); game.city_map.controller_cursor=map_cursor
		"characters":
			close_submenus(); set_screen(false)
			game.phone.panel.hide(); game.city_map.close()
			game.party.toggle_wheel()
		"character":
			if game.party.wheel.visible: game.party.choose(int(data.get("value",-1)))
		"back":
			if _entry()!=null: text_entry=null; return
			if _dropdown()!=null: close_submenus(); return
			if screen_mode: set_screen(false); return
			if game.phone.panel.visible: game.phone.back_app()
			elif game.city_map.expanded: game.city_map.close()
			elif game.party.wheel.visible: game.party.wheel.hide()
			elif game.conversation.active: game.conversation.finish()
		"camera":
			if game.player.driving and is_instance_valid(game.player.vehicle):
				var camera = game.get_viewport().get_camera_3d()
				if camera != null and camera.has_method("cycle_view"): camera.cycle_view()
			else: game.player.cycle_view()
		"hail": game.phone.hail()
		"skip":
			if is_instance_valid(game.player.riding_service): game.player.riding_service.skip_journey(game.player)
		"altitude": game.phone._toggle_altitude()
		"game_action":
			var name := str(data.get("value",""))
			if context() == "play" and name in ["fold_arms","cancel_action"]:
				Input.action_press(name)
				game.get_tree().create_timer(0.08).timeout.connect(func(): Input.action_release(name))
		"map_pick":
			if not game.city_map.expanded: return
			var map = game.city_map
			var uv := Vector2(clampf(float(data.get("x",0.5)),0,1),clampf(float(data.get("y",0.5)),0,1))
			var place: Dictionary = map.location_at(map.map_rect.position+map.map_rect.size*uv)
			map.set_waypoint(place)
			if map.selecting:
				map.close(); game.phone.select_location(place)
		"map_pan":
			if not game.city_map.expanded: return
			game.city_map.center -= Vector2(clampf(float(data.get("x",0)), -1,1),clampf(float(data.get("y",0)), -1,1))*game.city_map._span()
			game.city_map._bound_center()
		"control": _control(data)

func _control(data: Dictionary) -> void:
	var id := str(data.get("id",""))
	if not controls.has(id): return
	var node = controls[id].get_ref()
	if not is_instance_valid(node) or not node.is_visible_in_tree(): return
	if node is TabContainer:
		var index := int(data.get("value",node.current_tab if node is TabContainer else node.selected))
		if index>=0 and index<node.get_tab_count() and not node.is_tab_disabled(index): node.current_tab = index
	elif node is OptionButton:
		var index := int(data.get("value",node.current_tab if node is TabContainer else node.selected))
		if not node.disabled and index>=0 and index<node.item_count and not node.is_item_disabled(index):
			node.select(index); node.item_selected.emit(index)
	elif node is LineEdit:
		if node.editable:
			node.text = str(data.get("value","")).left(node.max_length if node.max_length>0 else 256)
			node.text_changed.emit(node.text)
	elif node is BaseButton and not node.disabled:
		if node.has_meta("control_action"):
			var name := str(node.get_meta("control_action"))
			Input.action_press(name)
			game.get_tree().create_timer(0.08).timeout.connect(func(): Input.action_release(name))
			return
		if node.toggle_mode: node.button_pressed = not node.button_pressed
		node.pressed.emit()


func open_options(option: OptionButton) -> void:
	if option.disabled or not option.is_visible_in_tree(): return
	dropdown=weakref(option)
	option.show_popup()
	option.get_popup().set_focused_item(maxi(0,option.selected))
	option.get_popup().scroll_to_item(maxi(0,option.selected))

func _move_option(amount: int) -> void:
	var option:=_dropdown()
	if option==null: return
	var popup:=option.get_popup()
	var index:=clampi(popup.get_focused_item()+amount,0,option.item_count-1)
	while index>=0 and index<option.item_count and (option.is_item_disabled(index) or option.is_item_separator(index)):
		index+=signi(amount)
	if index<0 or index>=option.item_count: return
	popup.set_focused_item(index); popup.scroll_to_item(index)

func open_text(field: LineEdit) -> void:
	if not field.editable or not field.is_visible_in_tree(): return
	text_entry=weakref(field); text_serial+=1; field.grab_focus()

func close_submenus() -> void:
	if _dropdown()!=null: _dropdown().get_popup().hide()
	dropdown=null; text_entry=null

func set_screen(enabled: bool) -> void:
	close_submenus()
	screen_mode=enabled
	game.set_meta("controller_screen_mode",enabled)

func move_screen(change: Vector2) -> void:
	screen_point=(screen_point+change).clamp(Vector2(.002,.002),Vector2(.998,.998))
	if game.party.wheel.visible:
		var index: int=game.party.wheel.sector_at(screen_point*game.get_viewport().get_visible_rect().size)
		if index>=0: game.party.wheel.highlight=index

func _hits(node: Control, point: Vector2) -> bool:
	if not node.is_visible_in_tree(): return false
	var local: Vector2=node.get_global_transform_with_canvas().affine_inverse()*point
	if not Rect2(Vector2.ZERO,node.size).has_point(local): return false
	var parent:=node.get_parent()
	while parent!=null:
		if parent is Control and parent.clip_contents:
			var inner: Vector2=parent.get_global_transform_with_canvas().affine_inverse()*point
			if not Rect2(Vector2.ZERO,parent.size).has_point(inner): return false
		parent=parent.get_parent()
	return true

func click_screen() -> void:
	var point: Vector2=screen_point*game.get_viewport().get_visible_rect().size
	if game.party.wheel.visible:
		var index: int=game.party.wheel.sector_at(point)
		if index>=0: game.party.choose(index)
		return
	controls.clear()
	var rows:Array=[]
	for layer in game.get_children():
		if layer is CanvasLayer: _collect(layer,rows)
	_collect(game.city_map,rows)
	var best: Control
	var priority:=-INF
	for i in range(rows.size()):
		var row: Dictionary=rows[i]
		if not row.has("id") or row.get("disabled",false) or not controls.has(str(row.id)): continue
		var node=controls[str(row.id)].get_ref()
		if not node is Control or not _hits(node,point): continue
		var layer:=0
		var parent=node.get_parent()
		while parent!=null:
			if parent is CanvasLayer: layer=parent.layer; break
			parent=parent.get_parent()
		var rank: float=layer*1000000+i
		if rank>priority: best=node; priority=rank
	if best is OptionButton: open_options(best)
	elif best is LineEdit: open_text(best)
	elif best is TabContainer:
		var tabs: TabBar=best.get_tab_bar()
		var local: Vector2=tabs.get_global_transform_with_canvas().affine_inverse()*point
		for i in range(tabs.tab_count):
			if tabs.get_tab_rect(i).has_point(local) and not tabs.is_tab_disabled(i): best.current_tab=i; break
	elif best!=null: _control({"id":str(best.get_instance_id())})
	elif _hits(game.city_map,point):
		var map=game.city_map
		if not map.expanded: map.open()
		else:
			var local: Vector2=map.get_global_transform_with_canvas().affine_inverse()*point
			if map.map_rect.has_point(local):
				map.set_waypoint(map.location_at(local))
				if map.selecting: map.close(); game.phone.select_location(map.selected_place)

func scroll_screen(amount: int) -> void:
	if game.phone.panel.visible:
		var scroll=game.phone.apps.sheets.get(game.phone.apps.page,game.phone.tabs.get_current_tab_control())
		if scroll is ScrollContainer: scroll.scroll_vertical+=amount
	elif game.city_map.expanded:
		game.city_map.zoom=clampf(game.city_map.zoom*(1.3 if amount<0 else 1/1.3),1,16)
		game.city_map._bound_center()
