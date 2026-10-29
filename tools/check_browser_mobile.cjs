const {chromium,devices}=require('playwright'),http=require('http'),fs=require('fs'),path=require('path'),assert=require('node:assert/strict');
const base=path.resolve(__dirname,'../build/web');
const server=http.createServer((req,res)=>{let file=path.join(base,new URL(req.url,'http://localhost').pathname);if(file.endsWith('/'))file+='index.html';try{res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':file.endsWith('.wasm')?'application/wasm':file.endsWith('.html')?'text/html':'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.writeHead(404);res.end();}});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({...(process.env.CHROME_BIN?{executablePath:process.env.CHROME_BIN}:{}),headless:true,args:['--no-sandbox','--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({...devices['Pixel 7'],viewport:{width:390,height:844},deviceScaleFactor:2});
  const page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.text().includes('SCRIPT ERROR'))errors.push(m.text())});
  await page.goto('http://127.0.0.1:'+server.address().port+'/',{timeout:120000});
  await page.waitForFunction(()=>window.NottCityTouch?.lastUI?.viewport[0]===390,null,{timeout:120000});
  const ui=()=>page.evaluate(()=>window.NottCityTouch.lastUI);
  const cdp=await context.newCDPSession(page),touch=async(type,touchPoints)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints});
  async function layout(width,height){
   const centre=await page.evaluate(()=>document.elementFromPoint(innerWidth/2,innerHeight/2)?.tagName);assert.equal(centre,'CANVAS','the centre of the game stays unobstructed');
   for(const selector of ['.touch-stick','.touch-actions button:not([hidden])','.touch-top button']){
    for(const box of await page.locator(selector).evaluateAll(els=>els.map(el=>{const r=el.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}}))){
     assert(box.x>=0&&box.y>=0&&box.x+box.w<=width+1&&box.y+box.h<=height+1,'all touch targets fit the display');
     assert(box.w>=44&&box.h>=44,'all touch targets are at least 44 CSS pixels');
    }
   }
  }
  await layout(390,844);
  const stick=await page.locator('.touch-stick').boundingBox(),run=await page.locator('.touch-actions [data-control=CROSS]').boundingBox();
  const finger={id:1,x:stick.x+stick.width/2,y:stick.y+stick.height/2},sprint={id:2,x:run.x+run.width/2,y:run.y+run.height/2};
  const before=(await ui()).position;
  await touch('touchStart',[finger]);await touch('touchStart',[finger,sprint]);finger.y-=stick.width*.28;await touch('touchMove',[finger,sprint]);
  await page.waitForFunction(before=>Math.hypot(...window.NottCityTouch.lastUI.position.map((v,i)=>v-before[i]))>.8,before,{timeout:15000});
  await touch('touchEnd',[sprint]);await touch('touchEnd',[]);
  assert.equal(await page.locator('.touch-knob').evaluate(el=>el.style.transform),'translate(0px, 0px)','the finger release recentres the stick');
  assert.equal(await page.locator('#city-touch .held').count(),0,'all released buttons are neutral');
  await page.waitForFunction(()=>window.NottCityTouch.lastUI.speed<.05,null,{timeout:10000});
  const stopped=(await ui()).position;await page.waitForTimeout(400);assert(Math.hypot(...(await ui()).position.map((v,i)=>v-stopped[i]))<.2,'lifting the fingers stops walking');
  const yaw=(await ui()).yaw;
  await touch('touchStart',[{id:3,x:260,y:420}]);await touch('touchMove',[{id:3,x:220,y:425}]);await touch('touchEnd',[]);
  await page.waitForFunction(yaw=>Math.abs(window.NottCityTouch.lastUI.yaw-yaw)>.03,yaw,{timeout:10000});
  if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-portrait.png'});
  await page.getByRole('button',{name:'Open city phone',exact:true}).tap();await page.waitForFunction(()=>window.NottCityTouch.lastUI.page==='home');await page.waitForTimeout(150);
  await page.touchscreen.tap(80,154);await page.waitForFunction(()=>window.NottCityTouch.lastUI.page==='book');await page.waitForTimeout(200);
  if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-book-choices.png'});
  await page.touchscreen.tap(110,160);await page.waitForFunction(()=>window.NottCityTouch.lastUI.page==='book_ticket');await page.waitForTimeout(200);
  if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-book-tickets.png'});
  await page.touchscreen.tap(195,190);await page.waitForFunction(()=>window.NottCityTouch.lastUI.ride.startsWith('aurora:'),null,{timeout:15000});
  if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-booking.png'});
  // A successful two-tap booking closes the phone and returns to play.
  await page.waitForFunction(()=>window.NottCityTouch.lastUI.context==='play');
  await page.setViewportSize({width:844,height:390});await page.waitForFunction(()=>window.NottCityTouch.lastUI.viewport[0]===844);await layout(844,390);
  if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-landscape.png'});
  await page.getByRole('button',{name:'Open city phone',exact:true}).tap();await page.waitForFunction(()=>window.NottCityTouch.lastUI.page==='home');await page.waitForTimeout(200);
  // Scroll the landscape phone page with a real finger and reach the last app row.
  await touch('touchStart',[{id:4,x:480,y:280}]);await touch('touchMove',[{id:4,x:480,y:160}]);await touch('touchMove',[{id:4,x:480,y:115}]);await touch('touchEnd',[]);await page.waitForTimeout(400);
  if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-phone-landscape.png'});
  await page.touchscreen.tap(795,50);await page.waitForFunction(()=>window.NottCityTouch.lastUI.context==='play');
  await page.getByRole('button',{name:'Open city map',exact:true}).tap();await page.waitForFunction(()=>window.NottCityTouch.lastUI.context==='map');await page.waitForTimeout(200);
  await page.touchscreen.tap(430,150);if(process.env.CAPTURE_DIR)await page.screenshot({path:process.env.CAPTURE_DIR+'/mobile-map.png'});
  await page.touchscreen.tap(790,44);await page.waitForFunction(()=>window.NottCityTouch.lastUI.context==='play');
  await page.setViewportSize({width:360,height:740});await page.waitForFunction(()=>window.NottCityTouch.lastUI.viewport[0]===360);await layout(360,740);
  assert.deepEqual(errors,[]);
  await context.close();
  // A small desktop window does not accidentally acquire mobile controls.
  const desktop=await browser.newContext({viewport:{width:390,height:740}}),desktopPage=await desktop.newPage();
  await desktopPage.goto('http://127.0.0.1:'+server.address().port+'/',{timeout:120000});await desktopPage.getByRole('button',{name:'Phone controller',exact:true}).waitFor({timeout:120000});
  assert.equal(await desktopPage.locator('#city-touch').count(),0);await desktop.close();
  console.log('REAL_GODOT_MOBILE_OK: multitouch walking, camera drag, service plus single-ticket Aurora booking, responsive portrait/landscape and HiDPI menus, scroll, map and desktop isolation');
 }finally{await browser.close();server.close();}
})().catch(error=>{console.error(error);server.close();process.exitCode=1});
