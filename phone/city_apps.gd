extends RefCounted
# A phone home screen with bounded lists and short, focused tasks.
var phone:CanvasLayer
var game:Node3D
var page:="home"
var history:Array[String]=[]
var host:VBoxContainer
var home:GridContainer
var sheets:Dictionary={}
var title:Label
var back_button:Button
var status:Label
var default_button:Button
var search:LineEdit
var results:VBoxContainer
var selected_vehicle:="car"
var selected_term:="hour"
var selected_home:=0
var rental_status:Label
var work_status:Label
var wallet_status:Label
var account_status:Label
var account_code:LineEdit
var copy_button:Button
var ticket_status:Label
var ticket_buttons:Array[Button]=[]
var refresh_clock:=0.0
var selected_job:="Bus"
var privacy_revealed:=false
var destination_button:Button
var rent_buttons:Array[Button]=[]
var collect_button:Button
var house_pay:Button
var house_visit:Button
var return_button:Button
var work_primary:Button
var work_secondary:Button
var work_end:Button
var shop_site:="market"
var book_grid:GridContainer
var driver_grid:GridContainer
var booking_kind:="Aurora"
var booking_title:Label
var booking_single:Button
var booking_day:Button
var booking_status:Label
var transit_job:Button
func build(rows:VBoxContainer,header:HBoxContainer) -> void:
 phone.panel.custom_minimum_size=Vector2(410,560)
 phone.tabs.custom_minimum_size=Vector2(378,370)
 phone.council.custom_minimum_size=Vector2(300,250)
 phone.tabs.get_tab_bar().hide()
 title=header.get_child(0);title.add_theme_font_size_override("font_size",26)
 back_button=Button.new();back_button.text="<";back_button.tooltip_text="Back to phone apps";back_button.pressed.connect(back)
 header.add_child(back_button);header.move_child(back_button,0)
 host=VBoxContainer.new();rows.add_child(host);rows.move_child(host,2)
 home=GridContainer.new();home.columns=3;home.add_theme_constant_override("h_separation",8);home.add_theme_constant_override("v_separation",10);host.add_child(home)
 for item in [["Book","book","318bb3"],["Rents","rents","b27744"],["Jobs","jobs","4e966c"],["Wallet","wallet","6c72ae"],["Passes","passes","a77c38"],["Map","map","438c89"],["Council","council","68778f"],["Settings","settings","5e6874"],["Account","account","7b60a6"]]:
  var b:=_button(home,item[0],func():open(item[1]))
  b.custom_minimum_size=Vector2(114,100);b.add_theme_font_size_override("font_size",19)
  b.text="\n\n"+item[0]
  var glyph:=TextureRect.new();glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;glyph.texture=_icon(item[1]);glyph.position=Vector2(42,12);glyph.size=Vector2(30,30);glyph.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;b.add_child(glyph)
  var skin:=StyleBoxFlat.new();skin.bg_color=Color(item[2]).darkened(.32);skin.set_corner_radius_all(13);skin.set_border_width_all(1);skin.border_color=Color(item[2]).lightened(.2)
  b.add_theme_stylebox_override("normal",skin)
  b.set_meta("phone_app",item[1]);b.set_meta("phone_grid",3)
  if item[1]=="book":default_button=b
 status=_label(host,"One city account • council rentals • pounds sterling")
 _build_book();_build_destinations();_build_rents();_build_jobs();_build_wallet();_build_passes();_build_account()
 for control in phone.panel.find_children("*","Control",true,false):
  if control is Button:
   control.custom_minimum_size.y=maxf(48,control.custom_minimum_size.y);control.add_theme_font_size_override("font_size",20)
  elif control is LineEdit:
   control.custom_minimum_size.y=48;control.add_theme_font_size_override("font_size",20)
 phone.summary.add_theme_font_size_override("font_size",20);phone.message.add_theme_font_size_override("font_size",20)
 # Legacy travel widgets stay hidden; Book uses the four service tiles above.
 phone.search.hide();phone.destinations.hide();phone.pass_status.hide();phone.pass_button.hide();phone.pass_code.hide()
 for n in phone.book_button.get_parent().get_children():
  if n is Button and (str(n.text).begins_with("Check pass") or str(n.text).begins_with("Choose on map")):n.hide()
 open("home",false)
func _button(parent:Node,text:String,callback:Callable) -> Button:
 var b:=Button.new();b.text=text;b.custom_minimum_size.y=52;b.clip_text=true;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size",20);b.pressed.connect(callback);parent.add_child(b);return b
func _label(parent:Node,text:String) -> Label:
 var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",20);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(label);return label
func _sheet(name:String) -> VBoxContainer:
 var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size=Vector2(378,370);host.add_child(scroll)
 var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_theme_constant_override("separation",8);scroll.add_child(box);sheets[name]=scroll;return box
func _build_book() -> void:
 var box:=_sheet("book")
 book_grid=GridContainer.new();book_grid.columns=2;book_grid.add_theme_constant_override("h_separation",8);book_grid.add_theme_constant_override("v_separation",8);box.add_child(book_grid)
 for kind in ["Aurora","Robovan","Helicopter","Train"]:
  var id:String=kind
  var b:=_button(book_grid,"Cybercab" if kind=="Aurora" else kind,func():_choose_booking(id))
  b.custom_minimum_size=Vector2(130,110);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.add_theme_font_size_override("font_size",23);b.set_meta("phone_grid",2)
 var ticket:=_sheet("book_ticket")
 booking_title=_label(ticket,"")
 booking_single=_button(ticket,"",func():_book_ticket("single"))
 booking_day=_button(ticket,"Day pass • £25",func():_book_ticket("day"))
 for button in [booking_single,booking_day]:button.custom_minimum_size.y=68
 var status_box:=_sheet("ride_status")
 booking_status=_label(status_box,"")
 _button(status_box,"Enter arrived vehicle",func():
  if phone.ride_service().board_near(game.player):phone.panel.hide();phone._release_focus()
  else:phone.show_message(game.economy.last_error))
 _button(status_box,"Cancel booking",func():
  phone.show_message("Booking cancelled" if phone.ride_service().cancel(game.player) else "Leave your current vehicle before making another booking.");open("book",false))
func _choose_booking(kind:String) -> void:
 booking_kind=kind
 var key:String=game.economy.key_for(game.player)
 if game.cabs.bookings.has(key) or game.helicopters.bookings.has(key):open("ride_status");return
 open("book_ticket")
func _book_ticket(ticket:String) -> void:
 if game.services.simple.book(game.player,booking_kind,ticket):
  phone.panel.hide();phone._release_focus();game.player._notify(game.services.simple.notice)
 else:phone.show_message(game.economy.last_error)
 update()
func _build_destinations() -> void:
 var box:=_sheet("destinations")
 _button(box,"Choose a place on the city map",func():phone.panel.hide();game.city_map.open(true))
 search=LineEdit.new();search.placeholder_text="House number, street or place";search.max_length=80;search.text_changed.connect(func(_text):_search_places());box.add_child(search)
 _button(box,"Choose destination after boarding",func():phone.selected_location={};open("book"))
 results=VBoxContainer.new();box.add_child(results);_search_places()
func _search_places() -> void:
 for child in results.get_children():child.free()
 var query:=search.text.strip_edges().to_lower();var count:=0
 for location in game.economy.locations:
  if query=="" and str(location.name).begins_with("House "):continue
  if query!="" and not str(location.name).to_lower().contains(query):continue
  var selected:Dictionary=location.duplicate()
  _button(results,location.name,func():phone.selected_location=selected;open("book");phone.show_message("Destination: "+str(selected.name)))
  count+=1
  if count>=8:break
 if count==0:_label(results,"No matching address. Try the house number or use the map.")
func _build_rents() -> void:
 var box:=_sheet("rents")
 _label(box,"All vehicles and homes are council rentals.")
 _button(box,"Vehicles • short or long term",func():open("vehicles"))
 _button(box,"Homes • rent or visit",func():open("homes"))
 var vehicles:=_sheet("vehicles")
 _label(vehicles,"Private rentals only. Choose a vehicle, then its duration. Aurora, Robovan, bus and helicopter come to you.")
 for kind in ["car","bus_private","Helicopter","Robovan","sports","suv","van","tow","trailer"]:
  var id:String=kind
  _button(vehicles,vehicle_name(kind),func():selected_vehicle=id;open("rental"))
 var rental:=_sheet("rental")
 rental_status=_label(rental,"")
 rent_buttons.append(_button(rental,"",func():_rent("hour")))
 rent_buttons.append(_button(rental,"",func():_rent("week")))
 collect_button=_button(rental,"Find / enter my vehicle",_collect)
 return_button=_button(rental,"Return vehicle / end rental",func():phone.show_message("Rental ended" if game.services.return_rental(game.player,selected_vehicle) else game.economy.last_error);update())
 var homes:=_sheet("homes")
 _label(homes,"Search a house number or street. Rent remotely, then visit its door.")
 var find:=LineEdit.new();find.placeholder_text="Find a home";find.max_length=80;homes.add_child(find)
 var list:=VBoxContainer.new();homes.add_child(list)
 var refresh:=func(_text):
  for child in list.get_children():child.free()
  var count:=0
  for number in game.economy.houses:
   var house:Node3D=game.economy.houses[number];var record:Dictionary=game.economy.house_record(number)
   if record.tenant!="" and record.tenant!=game.economy.key_for(game.player):continue
   if find.text!="" and not house.address.to_lower().contains(find.text.to_lower()):continue
   var id:int=number
   _button(list,house.address+"\n"+("Your rented home" if record.tenant!="" else game.economy.pounds(record.rent)+" / game month"),func():selected_home=id;open("home_rental"))
   count+=1
   if count==8:break
 find.text_changed.connect(refresh);homes.set_meta("refresh",refresh)
 var detail:=_sheet("home_rental")
 _label(detail,"Confirm with your signed-in city wallet. The price is shown before payment.")
 var name:=_label(detail,"");detail.set_meta("house_label",name)
 house_pay=_button(detail,"Rent • £400 / month",func():phone.show_message("House rented and saved" if game.economy.rent(game.player,selected_home) else game.economy.last_error);update())
 house_visit=_button(detail,"Visit this house",func():
  if game.economy.houses.has(selected_home):phone._navigate(game.economy.houses[selected_home].entrance()))
func vehicle_name(kind:String) -> String:
 return {"car":"Aurora","Robovan":"Robovan","bus_private":"City bus","Helicopter":"Helicopter","Train":"City Circle train"}.get(kind,str(game.services.CATALOG[kind].name))
func _rent(term:String) -> void:
 selected_term=term
 if game.services.private_hire.request(game.player,selected_vehicle,term):
  phone.show_message(game.economy.last_error if selected_vehicle in ["car","Robovan","bus_private","Helicopter"] else "Rental paid. Your vehicle is waiting at the depot.")
 else:phone.show_message(game.economy.last_error)
 update()
func _collect() -> void:
 var private:Dictionary=game.services.private_hire.record_for(game.player,selected_vehicle)
 if not private.is_empty():
  if private.car.state=="rental_ready" and (game.player.vehicle_distance(private.car.node) if selected_vehicle=="bus_private" else game.player.global_position.distance_to(private.car.node.global_position))<4.5:
   if game.services.private_hire.board(game.player,selected_vehicle):phone.panel.hide();phone._release_focus()
   else:phone.show_message(game.economy.last_error)
  else:game.services.private_hire.show_vehicle(game.player,selected_vehicle);phone.panel.hide();phone._release_focus()
  return
 var lease:Dictionary=game.services.rental(game.player,selected_vehicle)
 if game.services.collect_rental(game.player,selected_vehicle):
  var record:Dictionary=game.services.spawned.get(str(lease.get("id","")),{})
  phone.panel.hide();phone._release_focus()
  if not record.is_empty() and game.player.global_position.distance_to(record.body.global_position)<4:game.player.try_enter()
  return
 phone.show_message("Choose a rental duration first.")
func _build_jobs() -> void:
 var box:=_sheet("jobs")
 _button(box,"Driving",func():open("driving_jobs")).custom_minimum_size.y=86
 _button(box,"Council jobs",func():open("council_jobs")).custom_minimum_size.y=86
 work_status=_label(box,"")
 var drivers:=_sheet("driving_jobs")
 _label(drivers,"Free to start • You earn 70%, council earns 30%.")
 driver_grid=GridContainer.new();driver_grid.columns=2;driver_grid.add_theme_constant_override("h_separation",8);driver_grid.add_theme_constant_override("v_separation",8);drivers.add_child(driver_grid)
 for kind in ["Aurora","Robovan","Helicopter","Transit"]:
  var id:String=kind
  var b:=_button(driver_grid,{"Aurora":"Cybercab","Transit":"Bus / train"}.get(kind,kind),func():_choose_driver_job(game.services.simple.transit_kind(game.player) if id=="Transit" else id))
  b.custom_minimum_size=Vector2(130,100);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.set_meta("phone_grid",2)
  if kind=="Transit":transit_job=b
 var job:=_sheet("transport_job")
 var description:=_label(job,"");job.set_meta("job_label",description)
 work_primary=_button(job,"",_request_work)
 work_secondary=_button(job,"Show meeting point",_find_work)
 work_end=_button(job,"End shift",func():phone.show_message("Shift ended" if game.services.stop_job(game.player) else game.economy.last_error);update())
 var council_jobs:=_sheet("council_jobs")
 _label(council_jobs,"Apply at the council office. Complete the marked work to earn wages.")
 for role in ["Cleaner","Rent officer","Transport technician"]:
  var chosen:String=role
  _button(council_jobs,"Apply • "+role,func():phone.show_message("Application accepted. Work is marked on the map." if game.economy.apply_job(game.player,chosen) else game.economy.last_error);_show_assignment())
 var shop:=_sheet("shop_job")
 _label(shop,"Supermarket work • apply here, then work at this shop's counter to earn wages.")
 _button(shop,"Apply for shop work",func():phone.show_message("Application accepted. Work at this shop to earn wages." if game.economy.apply_shop_job(game.player,shop_site) else game.economy.last_error);_show_assignment())
func _choose_driver_job(kind:String) -> void:
 selected_job=kind
 open("transport_job")
func _show_assignment() -> void:
 var task:Dictionary=game.economy.assignment(game.player)
 if not task.is_empty():game.city_map.set_waypoint(task)
func _request_work() -> void:
 var s=game.services;var p=game.player;var op:Dictionary=s.contract_for(p)
 if not op.is_empty():
  if op.kind!=selected_job:phone.show_message("End your current shift first.");return
  if selected_job=="Courier":_find_work();return
  if s.aboard.has(p.get_instance_id()):
   phone.show_message("Self-drive on" if s.set_autonomous(p,not op.autonomous) and op.autonomous else ("Driver controls active" if not op.autonomous else game.economy.last_error))
  elif s.board_driver(p):phone.panel.hide();phone._release_focus()
  else:phone.show_message(game.economy.last_error)
 elif s.work.pending.has(game.economy.key_for(p)) and s.work.pending[game.economy.key_for(p)].kind==selected_job:
  var taken:bool=s.work.take_next(p)
  phone.show_message(game.economy.last_error)
  if taken:phone.panel.hide();phone._release_focus()
 else:
  if s.start_job(p,selected_job):
   var record:Dictionary=s.contract_for(p)
   if (not record.is_empty() and record.get("phase","")!="delivering") or s.work.candidate(p)!=null:s.board_driver(p)
   phone.panel.hide();phone._release_focus();p._notify(game.economy.last_error)
  else:phone.show_message(game.economy.last_error)
 update()
func _find_work() -> void:
 var s=game.services;var p=game.player;var op:Dictionary=s.contract_for(p)
 var place:Dictionary={}
 if not op.is_empty() and op.kind==selected_job:
  place=op.target if op.kind=="Courier" else {"name":"Your "+str(op.kind),"point":op.vehicle.global_position}
 else:
  place=s.work.meeting(p,selected_job)
 if not place.is_empty():game.city_map.set_waypoint(place);phone.panel.hide();phone._release_focus()
func _update_job() -> void:
 var s=game.services;var p=game.player;var op:Dictionary=s.contract_for(p)
 var wait:Dictionary=s.work.pending.get(game.economy.key_for(p),{})
 var active:bool=not op.is_empty() and op.kind==selected_job
 var waiting:bool=not wait.is_empty() and wait.kind==selected_job
 var description:String=s.work.status(p,selected_job)
 var price:="Council vehicle • no rental fee" if selected_job!="Courier" else "Use your rented road vehicle"
 sheets.transport_job.get_child(0).get_meta("job_label").text=selected_job+" work\n"+description+"\n"+("Council 30% • You 70%" if active else price)
 work_primary.disabled=false;work_secondary.hide();work_end.visible=not op.is_empty() or waiting
 work_end.text="Cancel request" if waiting else "End shift"
 work_secondary.text="Show vehicle / meeting point"
 if active:
  if selected_job=="Courier":work_primary.text="Show delivery route";work_secondary.hide()
  elif op.get("phase","")=="delivering":work_primary.text="Vehicle is coming";work_primary.disabled=true
  elif s.aboard.has(p.get_instance_id()):work_primary.text="Drive myself" if op.autonomous else "Use self-drive"
  else:work_primary.text="Enter my driver seat"
 elif not op.is_empty():work_primary.text="End your current shift first";work_primary.disabled=true
 elif waiting:
  var arrived:bool=s.work.candidate(p)!=null
  work_primary.text=("Enter next "+selected_job.to_lower()+" as driver") if arrived else "Waiting for arrived "+selected_job.to_lower()
  work_primary.disabled=not arrived
 elif selected_job in ["Aurora","Robovan","Helicopter"]:work_primary.text="Start and enter • FREE" if s.simple.nearby(p,selected_job)!=null else "Call work vehicle • FREE"
 elif selected_job=="Courier":work_primary.text="Choose a rented road vehicle";work_secondary.hide()
 else:work_primary.text="Start and enter • FREE" if s.simple.nearby(p,selected_job)!=null else "Start at nearest stop • FREE"
func _build_wallet() -> void:
 var box:=_sheet("wallet")
 wallet_status=_label(box,"")
func _build_passes() -> void:
 var box:=_sheet("passes")
 ticket_status=_label(box,"")
 ticket_buttons.append(_button(box,"One journey • £4",func():_buy_ticket("single")))
 ticket_buttons.append(_button(box,"Day pass • 24 real hours • £25",func():_buy_ticket("day")))
 ticket_buttons.append(_button(box,"Month pass • 30 real days • £120",func():_buy_ticket("month")))
 _button(box,"Board with my active pass",func():_buy_ticket("active"))
func _buy_ticket(kind:String) -> void:
 if is_instance_valid(game.services.ticket_vehicle):
  var allowed:bool=game.services.board_with_ticket(game.player,kind)
  if allowed:phone.panel.hide();phone._release_focus()
  else:phone.show_message(game.economy.last_error)
 elif kind in ["day","month"]:
  phone.show_message("Pass paid and saved to your city account" if game.economy.buy_travel_pass(game.player,kind) else game.economy.last_error)
 else:phone.show_message("Walk to a train entrance to buy its single-journey ticket.")
 update()
func _build_account() -> void:
 var box:=_sheet("account")
 account_status=_label(box,"Your city code connects this save, wallet, rentals and passes. Keep it private.")
 _button(box,"Show / hide my private city code",func():privacy_revealed=not privacy_revealed;update())
 account_code=LineEdit.new();account_code.placeholder_text="Enter your existing city code";account_code.secret=true;account_code.max_length=40;box.add_child(account_code)
 _button(box,"Load my account on this device",func():
  if is_instance_valid(game.city_account):game.city_account.sign_in(account_code.text)
  else:phone.show_message("Shared account storage is not connected yet. Your current city save remains on this device."))
 _button(box,"Resume this account here",func():
  if is_instance_valid(game.city_account):game.city_account.resume_here())
 _button(box,"Save my account online",func():
  if is_instance_valid(game.city_account):game.city_account.connect_account()
  else:phone.show_message("Shared account storage is not connected yet. Your current city save remains on this device."))
func _show_legacy(label:String) -> void:
 home.hide();status.hide()
 for sheet in sheets.values():sheet.hide()
 phone.tabs.show();title.text=label;back_button.show()
func open(name:String,remember:=true) -> void:
 if name=="map":phone.panel.hide();game.city_map.open();return
 if page!=name:phone.message.text=""
 if remember and page!=name:history.append(page)
 page=name;phone.panel.show();home.visible=name=="home";status.visible=name=="home";phone.message.visible=name!="home"
 for key in sheets:sheets[key].visible=key==name
 phone.tabs.visible=name in ["council","settings"]
 if name=="book":phone.tabs.current_tab=0
 elif name=="council":phone.tabs.current_tab=3
 elif name=="settings":phone.tabs.current_tab=4
 title.text={"home":"CITY PHONE","book":"Book","book_ticket":"Choose ticket","ride_status":"Your ride","driving_jobs":"Driving","rents":"Council rentals","vehicles":"Vehicle rentals","rental":"Rental details","homes":"Homes to rent","home_rental":"Your home","jobs":"Jobs","transport_job":"Transport work","wallet":"Wallet","passes":"Travel passes","account":"City account","destinations":"Choose destination","council":"Council","settings":"Settings","council_jobs":"Council jobs","shop_job":"Supermarket work"}.get(name,"City phone")
 back_button.visible=name!="home"
 if name=="homes":sheets.homes.get_child(0).get_meta("refresh").call("")
 update()
func back() -> bool:
 if page=="home":phone.panel.hide();return false
 open(history.pop_back() if not history.is_empty() else "home",false);return true
func preferred() -> Control:
 if page=="home":return default_button
 if sheets.has(page):
  for b in sheets[page].find_children("*","Button",true,false):
   if b.is_visible_in_tree() and not b.disabled:return b
 return back_button
func update() -> void:
 if rental_status==null:return
 var p=game.player;var e=game.economy
 booking_title.text=("Cybercab" if booking_kind=="Aurora" else booking_kind)+(" • nearest station" if booking_kind=="Train" else " • comes to you")
 booking_single.text="Single ticket • included" if e.has_day_pass(p) else "Single ticket • "+e.pounds(game.services.simple.FARES[booking_kind])
 booking_day.text="Use my day pass" if e.has_day_pass(p) else "Day pass • £25"
 booking_status.text=phone.cab_status.text
 transit_job.text="Bus / Train\n"+game.services.simple.transit_kind(p)+" driver"
 book_grid.columns=4 if phone.panel.size.x>680 else 2
 driver_grid.columns=book_grid.columns
 for grid in [book_grid,driver_grid]:
  for button in grid.get_children():button.set_meta("phone_grid",grid.columns)
 phone.service_picker.hide();phone.passenger_name.hide()
 phone.search.hide();phone.destinations.hide();phone.pass_status.hide();phone.pass_button.hide();phone.pass_code.hide()
 var item:Dictionary=game.services.CATALOG[selected_vehicle]
 var lease:Dictionary=game.services.rental(p,selected_vehicle)
 rental_status.text=vehicle_name(selected_vehicle)+"\nWallet: "+e.pounds(e.cash(p))+("\nRental active • %d minutes left" % maxi(0,int((float(lease.expires)-Time.get_unix_time_from_system())/60)) if not lease.is_empty() else "\nChoose duration. The price is paid once.")
 rent_buttons[0].text="Rent 1 hour • "+e.pounds(item.hour)
 rent_buttons[1].text="Rent 7 days • "+e.pounds(item.week)
 for b in rent_buttons:b.visible=lease.is_empty()
 collect_button.visible=not lease.is_empty()
 rental_status.text+="\n"+game.services.private_hire.status(p,selected_vehicle)
 return_button.visible=not lease.is_empty()
 if e.houses.has(selected_home):
  var record:Dictionary=e.house_record(selected_home)
  house_pay.visible=record.tenant=="";house_pay.text="Rent this home • "+e.pounds(record.rent)+" / month"
  sheets.home_rental.get_child(0).get_meta("house_label").text=e.houses[selected_home].address+"\n"+e.pounds(record.rent)+" / game month\n"+("Your rented home" if record.tenant==e.key_for(p) else ("Available" if record.tenant=="" else "Already rented"))
 var contract:Dictionary=game.services.contract_for(p)
 work_status.text="No transport shift active" if contract.is_empty() else str(contract.kind)+" • "+("Self-drive" if contract.autonomous else "Manual")+"\n"+str(contract.trips)+" paid trips • earned "+e.pounds(contract.earnings)
 _update_job()
 wallet_status.text=p.profile.name+"\nWallet: "+e.pounds(e.cash(p))+"\nOverdue rent: "+e.pounds(e.account_for(p).arrears)+"\nRecent transactions:\n"
 var ledger:Array=e.data.ledger.filter(func(row):return row.account==e.key_for(p))
 for row in ledger.slice(maxi(0,ledger.size()-8)):wallet_status.text+=str(row.reason)+"  "+e.pounds(row.pence)+"\n"
 ticket_status.text=("Train tickets • choose before boarding\n" if is_instance_valid(game.services.ticket_vehicle) else "Buses • trains • Aurora • Robovan • helicopters\n")+("Active pass • %d hours left" % ceili(e.pass_seconds_left(p)/3600.0) if e.has_day_pass(p) else "Choose a single journey, day pass or month pass. Payment is checked before entry.")
 ticket_buttons[0].visible=is_instance_valid(game.services.ticket_vehicle)
 ticket_buttons[1].disabled=e.has_day_pass(p)
 ticket_buttons[2].disabled=e.has_day_pass(p) and e.day_pass(p).get("term","day")=="month"
 account_status.text=""+(game.services.access_code() if privacy_revealed else "City code hidden")+"\nKeep private. Enable Phone controller to pair with this code.\n"+(game.city_account.status_text if is_instance_valid(game.city_account) else "Saved on this device • cloud setup pending")

func _icon(name:String) -> Texture2D:
 # Import once so release Web builds do not rasterize SVG strings at runtime.
 return {
  "book":preload("res://phone/icons/book.svg"),
  "rents":preload("res://phone/icons/rents.svg"),
  "jobs":preload("res://phone/icons/jobs.svg"),
  "wallet":preload("res://phone/icons/wallet.svg"),
  "passes":preload("res://phone/icons/passes.svg"),
  "map":preload("res://phone/icons/map.svg"),
  "council":preload("res://phone/icons/council.svg"),
  "settings":preload("res://phone/icons/settings.svg"),
  "account":preload("res://phone/icons/account.svg"),
 }.get(name)
