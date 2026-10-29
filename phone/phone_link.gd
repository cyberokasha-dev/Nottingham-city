extends Node
## Phone controller link (browser build).
## Press the "Phone controller" button (top-left of the page) to get a QR code and a
## pairing code. The phone page connects through PeerJS (WebRTC) and sends stick, button and
## camera-swipe state, which is turned into the game's normal InputMap actions.

const STICK_DEADZONE := 0.12
const LOOK_SENSITIVITY := 0.0045
const SIGNAL_TIMEOUT := 1.0
const BUTTON_ACTIONS := {
	"TRIANGLE": ["interact"],
	"SQUARE": ["jump"],
	"CIRCLE": ["punch"],
	"CROSS": ["sprint", "handbrake"],
	"L1": ["guard"],
	"R1": ["heavy_punch"],
	"L2": ["reverse"],
	"R2": ["accelerate"],
}
const MANAGED_ACTIONS := [
	"walk_forward", "walk_back", "walk_left", "walk_right", "turn_left", "turn_right",
	"accelerate", "reverse", "interact", "jump", "punch", "sprint", "handbrake", "guard", "heavy_punch",
]

var connected := false
var stick := Vector2.ZERO
var held_buttons: Array = []
var look := Vector2.ZERO
var camera_taps := 0
var since_packet := 0.0
var pressed_now := {}
var bridge: JavaScriptObject
var callback: JavaScriptObject
var player_cache: Node
var remote: RefCounted
var ui_clock := 0.0
var last_ui := ""
var atlas_sent := false
var last_command := -1
var previous_buttons: Array = []
var navigation_clock := 0.0
var neutral_required:=false
var last_context:="play"

func _ready() -> void:
	remote = preload("res://phone/remote_menu.gd").new()
	remote.game = get_parent()
	var cursor_layer:=CanvasLayer.new(); cursor_layer.layer=40; add_child(cursor_layer)
	var cursor:=preload("res://phone/screen_cursor.gd").new(); cursor.remote=remote; cursor_layer.add_child(cursor)
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(HOST_JS, true)
	bridge = JavaScriptBridge.get_interface("NottCityPhone")
	if bridge == null:
		push_warning("Phone controller: could not start the pairing script.")
		set_process(false)
		return
	callback = JavaScriptBridge.create_callback(_on_message)
	bridge.setCallback(callback)

func _input(event: InputEvent) -> void:
	if remote==null or remote.context()=="play": return
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A: remote.confirm()
			JOY_BUTTON_B: remote.command({"action":"back"})
			JOY_BUTTON_LEFT_SHOULDER: remote.select_tab(-1)
			JOY_BUTTON_RIGHT_SHOULDER: remote.select_tab(1)
			JOY_BUTTON_DPAD_UP: remote.navigate("up")
			JOY_BUTTON_DPAD_DOWN: remote.navigate("down")
			JOY_BUTTON_DPAD_LEFT: remote.navigate("left")
			JOY_BUTTON_DPAD_RIGHT: remote.navigate("right")
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y] and absf(event.axis_value)>.55:
		if navigation_clock<=0:
			remote.navigate(("right" if event.axis_value>0 else "left") if event.axis==JOY_AXIS_LEFT_X else ("down" if event.axis_value>0 else "up"))
			navigation_clock=.18
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if remote.context()=="text":
			if event.physical_keycode==KEY_ENTER:
				remote.command({"action":"text_input","id":remote.text_serial,"value":remote._entry().text})
			elif event.physical_keycode==KEY_ESCAPE: remote.command({"action":"back"})
			else: return
			get_viewport().set_input_as_handled(); return
		match event.physical_keycode:
			KEY_UP: remote.navigate("up")
			KEY_DOWN: remote.navigate("down")
			KEY_LEFT: remote.navigate("left")
			KEY_RIGHT: remote.navigate("right")
			KEY_ENTER: remote.confirm()
			KEY_ESCAPE: remote.command({"action":"back"})
			_: return
		get_viewport().set_input_as_handled()

func _on_message(args: Array) -> void:
	if args.is_empty():
		return
	var data = JSON.parse_string(str(args[0]))
	if typeof(data) != TYPE_DICTIONARY:
		return
	match str(data.get("t", "")):
		"link":
			connected = bool(data.get("up", false))
			last_ui = ""
			atlas_sent = false
			last_command = -1
			if not connected:
				_release_all()
		"s":
			apply_state(data)
		"cmd":
			var sequence := int(data.get("seq",-1))
			if not connected or sequence<=last_command: return
			last_command = sequence
			remote.command(data)
			ui_clock = 0.25
			_apply_actions()

func apply_state(data: Dictionary) -> void:
	since_packet = 0.0
	connected = true
	stick = Vector2(clampf(float(data.get("x", 0.0)), -1.0, 1.0), clampf(float(data.get("y", 0.0)), -1.0, 1.0))
	held_buttons = data.get("b", []) if typeof(data.get("b", [])) == TYPE_ARRAY else []
	if remote.context()!="play":
		for button in held_buttons:
			if button in previous_buttons: continue
			if button=="CROSS": remote.confirm()
			elif button=="CIRCLE": remote.command({"action":"back"})
			elif button in ["L1","R1"]: remote.select_tab(-1 if button=="L1" else 1)
	if neutral_required and stick.length()<STICK_DEADZONE and held_buttons.is_empty(): neutral_required=false
	previous_buttons=held_buttons.duplicate()
	look += Vector2(float(data.get("lx", 0.0)), float(data.get("ly", 0.0)))
	var taps := int(data.get("cc", camera_taps))
	if taps != camera_taps:
		camera_taps = taps
		remote.command({"action":"camera"})
	_apply_actions()

func _strengths() -> Dictionary:
	var s := {}
	if neutral_required: return s
	if remote != null and remote.context() != "play": return s
	var sx := stick.x if absf(stick.x) > STICK_DEADZONE else 0.0
	var sy := stick.y if absf(stick.y) > STICK_DEADZONE else 0.0
	s["walk_left"] = maxf(0.0, -sx)
	s["walk_right"] = maxf(0.0, sx)
	s["walk_forward"] = maxf(0.0, -sy)
	s["walk_back"] = maxf(0.0, sy)
	s["turn_left"] = maxf(0.0, -sx)
	s["turn_right"] = maxf(0.0, sx)
	s["accelerate"] = maxf(0.0, -sy)
	s["reverse"] = maxf(0.0, sy)
	for button in held_buttons:
		for action in BUTTON_ACTIONS.get(str(button), []):
			s[action] = 1.0
	return s

func _apply_actions() -> void:
	var current: String=remote.context() if remote!=null else "play"
	if current!=last_context:
		if current=="play" or last_context=="play": neutral_required=true
		last_context=current
	var s := _strengths()
	for action in MANAGED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var strength: float = s.get(action, 0.0)
		if strength > 0.0:
			Input.action_press(action, strength)
			pressed_now[action] = true
		elif pressed_now.has(action):
			Input.action_release(action)
			pressed_now.erase(action)

func _tap_action(action: String) -> void:
	if InputMap.has_action(action):
		Input.action_press(action)
		get_tree().create_timer(0.08).timeout.connect(func(): Input.action_release(action))

func _release_all() -> void:
	stick = Vector2.ZERO
	held_buttons = []
	look = Vector2.ZERO
	previous_buttons=[]
	neutral_required=false
	if remote!=null: remote.set_screen(false)
	_apply_actions()

func _process(delta: float) -> void:
	navigation_clock=maxf(0,navigation_clock-delta)
	if not connected:
		return
	since_packet += delta
	if since_packet > SIGNAL_TIMEOUT:
		_release_all()
		connected = false
		return
	if remote.context()!="play":
		_apply_actions()
		if remote.context()=="screen" and stick.length()>.12:
			remote.move_screen(stick*delta*.65)
		elif navigation_clock<=0 and stick.length()>0.5:
			remote.navigate(("right" if stick.x>0 else "left") if absf(stick.x)>absf(stick.y) else ("down" if stick.y>0 else "up"))
			navigation_clock=0.2
	ui_clock += delta
	if ui_clock >= 0.25:
		ui_clock = 0.0
		_publish_ui()
	if look != Vector2.ZERO:
		_apply_look(look)
		look = Vector2.ZERO

func _publish_ui() -> void:
	if bridge == null: return
	if remote.context() in ["phone","conversation"]: remote.focus_menu()
	var data: Dictionary = remote.state()
	var encoded := JSON.stringify(data)
	if encoded != last_ui:
		last_ui = encoded
		bridge.sendUI(encoded)

func _find_player() -> Node:
	if is_instance_valid(player_cache) and player_cache.get("controlled") == true:
		return player_cache
	player_cache = null
	for node in get_tree().get_nodes_in_group("people"):
		var script: Script = node.get_script()
		if script != null and script.resource_path == "res://player/player.gd" and node.get("controlled") == true:
			player_cache = node
			break
	return player_cache

func _apply_look(amount: Vector2) -> void:
	var p = _find_player()
	if remote.context()=="screen":
		var viewport_size:=get_viewport().get_visible_rect().size
		remote.move_screen(amount/viewport_size)
		return
	if p == null or p.transitioning or remote.context() != "play":
		return
	if p.driving:
		var camera = get_viewport().get_camera_3d()
		if camera != null and camera.get("orbit") != null:
			camera.orbit -= amount.x * LOOK_SENSITIVITY
			camera.manual_time = 1.6
		return
	p.camera_manual = 1.6
	p.yaw -= amount.x * LOOK_SENSITIVITY
	var new_pitch: float = p.pitch - amount.y * LOOK_SENSITIVITY
	p.pitch = clampf(new_pitch, -1.15, -0.75) if is_instance_valid(p.active_house) else clampf(new_pitch, -1.0, 0.3)

const HOST_JS := """
(function(){
if(window.NottCityPhone)return;
var CONTROLLER_URL='https://cyberokasha-dev.github.io/nottingham-city-phone-controller/';
var PEER_SRC='https://cdn.jsdelivr.net/npm/peerjs@1.5.4/dist/peerjs.min.js';
var QR_SRC='https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.js';
var ALPHABET='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
var api={cb:null,code:'',peer:null,conn:null,started:false,ui:{}};
window.NottCityPhone=api;
api.setCallback=function(fn){api.cb=fn;};
api.sendUI=function(json){if(api.conn&&api.conn.open){try{api.conn.send(JSON.parse(json));}catch(e){}}};
function emit(obj){if(api.cb){try{api.cb(JSON.stringify(obj));}catch(e){}}}
function makeCode(){var s='';var a=new Uint32Array(6);crypto.getRandomValues(a);for(var i=0;i<6;i++){s+=ALPHABET.charAt(a[i]%ALPHABET.length);}return s;}
function loadScript(src){return new Promise(function(ok,fail){var s=document.createElement('script');s.src=src;s.onload=ok;s.onerror=function(){fail(new Error('Could not load '+src));};document.head.appendChild(s);});}
function setStatus(text,good){if(api.ui.status){api.ui.status.textContent=text;api.ui.status.style.color=good?'#6cdfa1':'#ffd37a';}if(api.ui.btn){api.ui.btn.textContent=good?'Phone connected':'Phone controller';}}
function drawQr(){
 var url=CONTROLLER_URL+'?v=4&code='+api.code;
 api.ui.code.textContent=api.code;
 api.ui.url.textContent=CONTROLLER_URL;
 try{var qr=qrcode(0,'M');qr.addData(url);qr.make();api.ui.qr.src=qr.createDataURL(6,3);api.ui.qr.style.display='block';}catch(e){api.ui.qr.style.display='none';}
}
function attach(conn,alreadyOpen){
 if(api.conn&&api.conn!==conn&&api.conn.open){var reject=function(){try{conn.send({t:'busy'});}catch(e){}setTimeout(function(){conn.close();},100);};if(alreadyOpen)reject();else conn.on('open',reject);return;}
 api.conn=conn;
 function ready(){
  if(api.conn!==conn)return;
  conn.send({t:'ready',version:4});
  api.ui.panel.style.display='none';
  var canvas=document.querySelector('canvas');if(canvas)canvas.focus();
  setStatus('Phone connected. You can play!',true);
  emit({t:'link',up:true});
 }
 conn.on('data',function(d){if(api.conn===conn&&d&&(d.t==='s'||d.t==='cmd'))emit(d);});
 var gone=function(){if(api.conn===conn){api.conn=null;setStatus('Phone disconnected. Waiting for a phone...',false);emit({t:'link',up:false});}};
 conn.on('close',gone);conn.on('error',gone);
 if(alreadyOpen)ready();else conn.on('open',ready);
}
// A private account code is never displayed in the pairing panel or put into a QR URL.
var accountCode='',accountPeer=null,accountGeneration=0;
function hex(bytes){return Array.from(new Uint8Array(bytes),function(b){return b.toString(16).padStart(2,'0');}).join('');}
function accountConnection(conn,code){
 var accepted=false,nonce=hex(crypto.getRandomValues(new Uint8Array(24)));
 var timeout=setTimeout(function(){if(!accepted)conn.close();},10000);
 conn.on('close',function(){clearTimeout(timeout);});
 conn.on('open',function(){conn.send({t:'challenge',nonce:nonce});});
 conn.on('data',async function(d){
  if(accepted||!d||d.t!=='proof'||typeof d.proof!=='string'||!/^[a-f0-9]{64}$/.test(d.proof))return;
  try{
   var key=await crypto.subtle.importKey('raw',new TextEncoder().encode(code),{name:'HMAC',hash:'SHA-256'},false,['verify']);
   var bytes=new Uint8Array(d.proof.match(/../g).map(function(h){return parseInt(h,16);}));
   var ok=await crypto.subtle.verify('HMAC',key,bytes,new TextEncoder().encode(nonce));
   if(!ok){conn.send({t:'denied'});conn.close();clearTimeout(timeout);return;}
   if(accepted)return;accepted=true;clearTimeout(timeout);attach(conn,true);
  }catch(e){conn.close();clearTimeout(timeout);}
 });
}
async function startAccountPeer(){
 if(!accountCode||!api.peer||typeof Peer==='undefined'||accountPeer||!crypto.subtle)return;
 var code=accountCode,generation=++accountGeneration;
 try{
  var digest=hex(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(code)));
  if(generation!==accountGeneration||code!==accountCode)return;
  var peer=new Peer('nottcity-account-'+digest,{debug:0});accountPeer=peer;
  peer.on('connection',function(conn){accountConnection(conn,code);});
  peer.on('disconnected',function(){try{peer.reconnect();}catch(e){}});
  peer.on('error',function(){/* Temporary QR pairing remains available if another game owns the alias. */});
 }catch(e){}
}
api.setAccount=function(value){
 var next=String(value||'').toUpperCase().replace(/[ -]/g,'');
 if(!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{16}$/.test(next)||next===accountCode)return;
 accountCode=next;accountGeneration++;
 if(accountPeer){try{accountPeer.destroy();}catch(e){}accountPeer=null;}
 startAccountPeer();
};
function startPeer(tries){
 api.code=makeCode();
 setStatus('Connecting to the pairing service...',false);
 var peer=new Peer('nottcity-'+api.code,{debug:0});
 api.peer=peer;
 peer.on('open',function(){drawQr();setStatus('Waiting for your phone...',false);startAccountPeer();});
 peer.on('connection',attach);
 peer.on('disconnected',function(){try{peer.reconnect();}catch(e){}});
 peer.on('error',function(err){
  if(err&&err.type==='unavailable-id'&&tries<5){try{peer.destroy();}catch(e){}startPeer(tries+1);return;}
  setStatus('Pairing service problem: '+(err&&err.type?err.type:'unknown')+'. Close this and try again.',false);
 });
}
api.start=function(){
 if(api.started)return;
 api.started=true;
 setStatus('Loading...',false);
 loadScript(PEER_SRC).then(function(){return loadScript(QR_SRC);}).then(function(){startPeer(0);}).catch(function(e){api.started=false;setStatus('Could not load the pairing tools. Check your internet connection.',false);});
};
function el(tag,css,text){var e=document.createElement(tag);if(css)e.style.cssText=css;if(text)e.textContent=text;return e;}
function build(){
 var btn=el('button','position:fixed;left:14px;top:14px;z-index:99999;padding:10px 14px;border-radius:999px;border:1px solid #2f6f8f;background:#071321;color:#fff;font:600 14px system-ui,sans-serif;cursor:pointer;opacity:.92','Phone controller');
 var panel=el('div','position:fixed;left:14px;top:64px;z-index:99999;width:260px;padding:16px;border-radius:16px;background:#071321;color:#fff;font:14px system-ui,sans-serif;border:1px solid #2f6f8f;display:none;text-align:center');
 var title=el('div','font-weight:700;margin-bottom:8px','Use your phone as the controller');
 var qr=el('img','width:200px;height:200px;margin:0 auto 8px;background:#fff;border-radius:8px;display:none');
 var scan=el('div','opacity:.8;font-size:12px','Scan with your phone camera, or open:');
 var url=el('div','font-size:11px;word-break:break-all;margin:2px 0 8px;opacity:.8');
 var lab=el('div','font-size:12px;opacity:.8','Pairing code');
 var code=el('div','font:700 32px ui-monospace,monospace;letter-spacing:6px;margin:2px 0 8px;color:#70bdff','------');
 var status=el('div','font-size:13px;min-height:34px','');
 var close=el('button','margin-top:8px;padding:6px 14px;border-radius:8px;border:1px solid #2f6f8f;background:transparent;color:#fff;cursor:pointer','Close');
 [title,qr,scan,url,lab,code,status,close].forEach(function(n){panel.appendChild(n);});
 document.body.appendChild(panel);document.body.appendChild(btn);
 api.ui={btn:btn,panel:panel,qr:qr,code:code,url:url,status:status};
 var focusGame=function(){var c=document.querySelector('canvas');if(c)c.focus();};
 btn.onclick=function(){var open=panel.style.display==='none';panel.style.display=open?'block':'none';if(open){api.start();}else{focusGame();}};
 close.onclick=function(){panel.style.display='none';focusGame();};
}
if(document.body){build();}else{window.addEventListener('DOMContentLoaded',build);}
})();
"""
