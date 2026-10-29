const {chromium}=require('playwright'),http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert');
const base=path.resolve(__dirname,'../build/web');
const server=http.createServer((req,res)=>{let p=path.join(base,new URL(req.url,'http://x').pathname);if(p.endsWith('/'))p+='index.html';try{res.setHeader('Content-Type',p.endsWith('.js')?'text/javascript':p.endsWith('.wasm')?'application/wasm':p.endsWith('.html')?'text/html':'application/octet-stream');res.end(fs.readFileSync(p));}catch{res.writeHead(404);res.end();}});
const stub=`window.received=[];window.sequence=0;window.hostPeers={};window.Peer=class{constructor(id){this.events={};window.hostPeers[id]=this;setTimeout(()=>{this.events.open?.(id);if(id.includes('account-'))return;const c={open:true,events:{},on(k,f){this.events[k]=f},send(d){window.received.push(d)},close(){}};window.fakeConn=c;this.events.connection(c);setTimeout(()=>{c.events.open();setInterval(()=>c.events.data({t:'s',x:0,y:0,b:[],cc:0}),200)},30)},30)}on(k,f){this.events[k]=f}destroy(){}reconnect(){}};`;
(async()=>{await new Promise(r=>server.listen(0,'127.0.0.1',r));const b=await chromium.launch({...(process.env.CHROME_BIN?{executablePath:process.env.CHROME_BIN}:{}),args:['--no-sandbox','--enable-unsafe-swiftshader'],headless:true});try{const page=await b.newPage({viewport:{width:1100,height:720}}),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.text().includes('SCRIPT ERROR'))errors.push(m.text())});
await page.route('**/peerjs.min.js',r=>r.fulfill({contentType:'text/javascript',body:stub}));await page.route('**/qrcode.js',r=>r.fulfill({contentType:'text/javascript',body:'window.qrcode=()=>({addData(){},make(){},createDataURL(){return ""}})'}));
await page.goto('http://127.0.0.1:'+server.address().port+'/',{timeout:120000});await page.getByRole('button',{name:'Phone controller',exact:true}).waitFor({timeout:120000});await page.waitForTimeout(1500);if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/hud.png'});await page.getByRole('button',{name:'Phone controller',exact:true}).click();
await page.waitForFunction(()=>window.received?.some(d=>d.t==='ui'),{timeout:30000});
async function command(action,value){await page.evaluate(({action,value})=>window.fakeConn.events.data({t:'cmd',seq:++window.sequence,action,value}),{action,value});}
await command('phone');await page.waitForFunction(()=>window.received.some(d=>d.t==='ui'&&d.context==='phone'));await page.waitForTimeout(500);if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/phone.png'});
// Four large service choices, then a single/day ticket, using real game controls.
await command('confirm');await command('nav','down');await command('confirm');await command('confirm');
await page.waitForFunction(()=>window.received.some(d=>d.ride?.startsWith('helicopter:')));
async function cancelRide(){await command('play');await command('phone');await command('confirm');await command('confirm');await command('nav','down');await command('confirm');await page.waitForFunction(()=>window.received.filter(d=>d.t==='ui').at(-1)?.ride==='');}
await cancelRide();
await command('play');await command('phone');await command('confirm');await command('nav','right');await command('confirm');await command('confirm');
await page.waitForFunction(()=>window.received.filter(d=>d.t==='ui').at(-1)?.ride.startsWith('robovan:'));
if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/robovan-booking.png'});
await cancelRide();await command('play');
await command('screen');await page.waitForFunction(()=>window.received.filter(d=>d.t==='ui').at(-1)?.context==='screen');if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/cursor.png'});
// Move the game cursor to the HUD Phone shortcut, then select its actual button.
await page.evaluate(()=>window.fakeConn.events.data({t:'cmd',seq:++window.sequence,action:'pointer_move',x:.23,y:.25}));await page.evaluate(()=>window.fakeConn.events.data({t:'cmd',seq:++window.sequence,action:'pointer_move',x:0,y:.14}));await command('confirm');await page.waitForFunction(()=>window.received.filter(d=>d.t==='ui').at(-1)?.surface==='phone');
await command('phone');await command('phone');await command('back');
await command('characters');await page.waitForFunction(()=>window.received.some(d=>d.context==='characters'));if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/characters.png'});await command('nav','right');await command('nav','right');await command('confirm');await page.waitForFunction(()=>window.received.some(d=>d.character==='Musa'));
// Buy through the game screen, then reload immediately while IndexedDB may still be syncing.
await command('phone');await command('nav','down');await command('nav','right');await command('confirm');await command('confirm');
await page.waitForFunction(()=>{const d=JSON.parse(localStorage.getItem('nottingham-city-financial-checkpoint-v1')||'null');return d?.travel_passes?.['player/Musa']});
const purchase=await page.evaluate(()=>JSON.parse(localStorage.getItem('nottingham-city-financial-checkpoint-v1'))),ticket=purchase.travel_passes['player/Musa'];
assert(ticket.expires>Date.now()/1000+86000);assert(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{16}$/.test(ticket.code));assert.equal(ticket.code,purchase.city_identity.code);assert.equal(purchase.accounts['player/Musa'].balance,147500);
if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/pass.png'});
await page.reload({timeout:120000});await page.getByRole('button',{name:'Phone controller',exact:true}).waitFor({timeout:120000});await page.getByRole('button',{name:'Phone controller',exact:true}).click();await page.waitForFunction(()=>window.received?.some(d=>d.t==='ui'));
await command('characters');await command('nav','right');await command('nav','right');await command('confirm');await page.waitForFunction(()=>window.received.some(d=>d.character==='Musa'));await command('phone');await page.waitForTimeout(1000);if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/pass-reloaded.png'});
await page.waitForFunction(async code=>{const request=indexedDB.open('/userfs');const db=await new Promise((resolve,reject)=>{request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)});if(!db.objectStoreNames.contains('FILE_DATA')){db.close();return false}const rows=await new Promise((resolve,reject)=>{const r=db.transaction('FILE_DATA','readonly').objectStore('FILE_DATA').getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});db.close();return rows.some(row=>{if(!row.contents)return false;try{const d=JSON.parse(new TextDecoder().decode(row.contents));return d.travel_passes?.['player/Musa']?.code===code&&d.accounts?.['player/Musa']?.balance===147500}catch{return false}})},ticket.code,{timeout:30000});
await command('play');await command('map');await page.waitForFunction(()=>window.received.some(d=>d.context==='map'));if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/map.png'});// Rent through the same visible app grid, with immediate durable balance and lease checks.
await command('play');await command('phone');await command('nav','right');await command('confirm');await command('confirm');
for(let i=0;i<4;i++)await command('nav','down');await command('confirm');
await page.waitForTimeout(300);if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/rental.png'});
// The first button pays for one hour directly; a second term/confirm form is gone.
await command('confirm');
await page.waitForFunction(()=>{const d=JSON.parse(localStorage.getItem('nottingham-city-financial-checkpoint-v1'));return d.vehicle_rentals?.['player/Musa']?.sports&&d.accounts['player/Musa'].balance===144500});
await command('play');await command('phone');await command('nav','right');await command('nav','right');await command('confirm');
await page.waitForTimeout(300);if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/jobs.png'});
// Jobs > Driving > Cybercab > Call work vehicle; starting remains completely free.
await command('confirm');await command('confirm');await command('confirm');
await page.waitForFunction(()=>{const d=JSON.parse(localStorage.getItem('nottingham-city-financial-checkpoint-v1'));const work=d.transport_work?.['player/Musa'];return work?.kind==='Aurora'&&['delivering','ready','active'].includes(work.phase)&&work.council_job===true&&d.accounts['player/Musa'].balance===144500});
await page.waitForFunction(()=>window.received.filter(d=>d.t==='ui').at(-1)?.context==='play');
if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/work-vehicle-coming.png'});
// Renting a private Aurora is a separate two-action flow and never replaces the public job.
await command('play');await command('phone');await command('nav','right');await command('confirm');await command('confirm');await command('confirm');await command('confirm');
await page.waitForFunction(()=>{const d=JSON.parse(localStorage.getItem('nottingham-city-financial-checkpoint-v1'));return d.private_deliveries?.['player/Musa/car']?.kind==='car'&&d.vehicle_rentals?.['player/Musa']?.car&&d.transport_work?.['player/Musa']?.council_job&&d.accounts['player/Musa'].balance===140500});
if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/private-rental-coming.png'});
// Knowing the public account peer ID does not authorise a controller: challenge proof is required.
const pairing=await page.evaluate(async()=>{
 const saved=JSON.parse(localStorage.getItem('nottingham-city-financial-checkpoint-v1')),code=saved.city_identity.code;
 const hex=b=>Array.from(new Uint8Array(b),n=>n.toString(16).padStart(2,'0')).join('');
 const id='nottcity-account-'+hex(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(code)));
 for(let i=0;i<100&&!window.hostPeers[id];i++)await new Promise(r=>setTimeout(r,20));
 const peer=window.hostPeers[id];if(!peer)throw new Error('No private-code controller peer');
 function connection(){return {open:true,events:{},sent:[],on(k,f){this.events[k]=f},send(d){this.sent.push(d)},close(){this.open=false;this.events.close?.()}}}
 const bad=connection();peer.events.connection(bad);bad.events.open();bad.events.data({t:'cmd',seq:999999,action:'play'});
 await bad.events.data({t:'proof',proof:'0'.repeat(64)});await new Promise(r=>setTimeout(r,20));
 const rejected=!bad.open&&!bad.sent.some(d=>d.t==='ready')&&bad.sent.some(d=>d.t==='denied');
 window.fakeConn.events.close();const good=connection();peer.events.connection(good);good.events.open();
 const nonce=good.sent.find(d=>d.t==='challenge').nonce;
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(code),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 await good.events.data({t:'proof',proof:hex(await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(nonce)))});
 await new Promise(r=>setTimeout(r,20));
 const accepted=good.sent.some(d=>d.t==='ready');window.fakeConn=good;window.received=good.sent;window.sequence=0;
 setInterval(()=>good.events.data({t:'s',x:0,y:0,b:[],cc:0}),200);
 return {rejected,accepted,privateInURL:location.href.includes(code),privateInPairing:window.NottCityPhone.ui.panel.textContent.includes(code)};
});
assert(pairing.rejected&&pairing.accepted&&!pairing.privateInURL&&!pairing.privateInPairing);
await command('play');await command('phone');await page.waitForFunction(()=>window.received.some(d=>d.context==='phone'));
assert.deepEqual(errors,[]);console.log('REAL_GODOT_BROWSER_OK: icon phone, four service choices and single/day tickets, map, characters, durable paid pass and rental, masked account code, authenticated private-code pairing and rejected unauthorised input');
}finally{await b.close();server.close();}})().catch(e=>{console.error(e);process.exitCode=1;server.close()});
