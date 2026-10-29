extends Node
# Private-code recovery and optimistic cloud saves. No privileged server credential is shipped.
const CONFIG=preload("res://simulation/account_config.gd")
const SESSION_PATH="user://nottingham-account-session.json"
var game:Node3D
var session:Dictionary={}
var status_text:="Saved on this device • cloud setup pending"
var request:HTTPRequest
var busy:=false
var clock:=0.0
var last_saved_revision:=-1
var pending_action:=""
var pending_save_revision:=-1
var pending_code:=""
var writer:=""
var conflict:=false
var conflict_code:=""
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 request=HTTPRequest.new();request.timeout=20;add_child(request);request.request_completed.connect(_completed)
 if FileAccess.file_exists(SESSION_PATH):
  var data=JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
  if data is Dictionary:session=data
 writer=str(session.get("writer",Crypto.new().generate_random_bytes(16).hex_encode()))
 session.writer=writer
 _pair_identity()
 if CONFIG.URL=="" or OS.has_environment("NOTTINGHAM_TEST"):return
 status_text="City account ready • connect in Account to save online"
 if session.has("access_token"):
  status_text="Restoring your city account connection";_send("claim",{"writer":writer})
func _pair_identity() -> void:
 if OS.has_feature("web"):
  JavaScriptBridge.eval("if(window.NottCityPhone&&window.NottCityPhone.setAccount)window.NottCityPhone.setAccount("+JSON.stringify(game.services.access_code())+")")
func _save_session() -> void:
 var file:=FileAccess.open(SESSION_PATH,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(session))
func connect_account() -> bool:
 if CONFIG.URL=="":status_text="Saved locally • dedicated cloud project setup is pending";return false
 if session.has("access_token"):return _send("save",{"state":_snapshot(),"revision":int(session.get("revision",0)),"writer":writer,"pair_code":_pair_code()})
 pending_code=game.services.access_code()
 return _send("create",{"code":pending_code,"state":_snapshot(),"writer":writer})
func sign_in(code:String,take_over:=false) -> bool:
 if CONFIG.URL=="":status_text="Shared storage is not connected yet. This device's save is safe.";return false
 if game.player.driving or game.player.riding_bus!=null or game.player.riding_service!=null or game.player.transitioning or game.services.aboard.has(game.player.get_instance_id()):
  status_text="Park and leave your vehicle before changing city accounts.";return false
 pending_code=game.services.normal_code(code)
 if pending_code.length()!=16:status_text="Enter your sixteen-character private city code.";return false
 return _send("login",{"code":pending_code,"writer":writer,"take_over":take_over})
func resume_here() -> bool:
 pending_code=conflict_code if conflict_code!="" else game.services.access_code()
 return _send("login",{"code":pending_code,"writer":writer,"take_over":true})
func _snapshot() -> Dictionary:
 var data:Dictionary=game.economy.data.duplicate(true)
 if data.has("city_identity"):data.city_identity.erase("code")
 for pass_record in data.get("travel_passes",{}).values():pass_record.erase("code")
 for receipt in data.get("receipts",{}).values():receipt.erase("pass_code")
 return data
func _pair_code() -> String:
 if not OS.has_feature("web"):return ""
 var code=JavaScriptBridge.eval("window.NottCityPhone?window.NottCityPhone.code:''")
 return str(code) if code!=null else ""
func _send(action:String,body:Dictionary) -> bool:
 if busy or CONFIG.URL=="":return false
 if action not in ["refresh","login","create"] and float(session.get("expires",0))<Time.get_unix_time_from_system()+30 and session.has("refresh_token"):
  return _send("refresh",{"refresh_token":session.refresh_token})
 body.action=action
 var headers:=PackedStringArray(["Content-Type: application/json","apikey: "+CONFIG.PUBLISHABLE_KEY])
 if session.has("access_token"):headers.append("Authorization: Bearer "+str(session.access_token))
 var error:=request.request(CONFIG.URL+"/functions/v1/city-account",headers,HTTPClient.METHOD_POST,JSON.stringify(body))
 if error!=OK:status_text="Connection unavailable • your local save is retained";return false
 busy=true;pending_action=action
 if action in ["save","create"]:pending_save_revision=int(game.economy.data.get("save_revision",0))
 status_text="Signing into your city account…" if action in ["login","create"] else "Saving city account…"
 return true
func _completed(result:int,http_code:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
 busy=false
 var value=JSON.parse_string(body.get_string_from_utf8())
 if result!=HTTPRequest.RESULT_SUCCESS or not value is Dictionary:
  status_text="Offline • your local save is retained. Retry when connected.";return
 if http_code>=400:
  status_text=str(value.get("error","Account connection failed"))
  if http_code==409:
   conflict_code=pending_code if pending_action in ["login","create"] else game.services.access_code()
   conflict=true
   # Stop simulation before it creates local purchases that cannot be saved to the active account.
   get_tree().paused=true;game.phone.process_mode=Node.PROCESS_MODE_ALWAYS;game.phone.open_app("account")
  return
 if value.has("access_token"):
  session.access_token=value.access_token;session.refresh_token=value.refresh_token
  session.expires=Time.get_unix_time_from_system()+int(value.expires_in)
 var previous_cloud_revision:int=session.get("revision",0)
 if value.has("revision"):session.revision=int(value.revision)
 _save_session()
 if pending_action=="login" or (pending_action=="create" and not value.get("created",false)):
  if not value.has("state") or not value.state is Dictionary:status_text="No account save was returned";return
  var restored:Dictionary=value.state
  if not restored.has("city_identity"):restored.city_identity={}
  restored.city_identity.code=pending_code
  var backup:=FileAccess.open("user://nottingham-before-account-load.json",FileAccess.WRITE)
  if backup:backup.store_string(JSON.stringify(game.economy.data))
  game.economy.data=restored;game.economy.save_pending=true;game.economy.flush_save()
  conflict=false;get_tree().paused=false
  get_tree().reload_current_scene();return
 if pending_action=="claim" and value.has("state"):
  # A newer remote revision must be loaded deliberately; never overwrite it with an older local save.
  if int(value.revision)>previous_cloud_revision:
   pending_code=game.services.access_code();pending_action="login"
   _completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(value).to_utf8_buffer());return
 if pending_action in ["save","create"]:last_saved_revision=pending_save_revision
 status_text="City account connected • private code ready" if pending_action in ["refresh","claim"] else "City account saved online • same code on your other devices"
 _pair_identity()
func _process(delta:float) -> void:
 if CONFIG.URL=="" or OS.has_environment("NOTTINGHAM_TEST") or busy or conflict:return
 clock+=delta
 if clock<15:return
 clock=0
 if not session.has("access_token"):return
 var revision:int=game.economy.data.get("save_revision",0)
 if revision!=last_saved_revision:connect_account()
 else:_send("heartbeat",{"writer":writer,"pair_code":_pair_code()})
