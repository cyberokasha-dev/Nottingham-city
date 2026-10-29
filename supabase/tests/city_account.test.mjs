import test from 'node:test';
import assert from 'node:assert/strict';
import {createHandler,cleanSnapshot,accountEmail} from '../functions/city-account/handler.mjs';
const code='ABCDEFGHJKLMNPQR',other='STUVWXYZ23456789';
const writer='browser-session-1111',second='browser-session-2222';
const state={version:1,accounts:{'player/Muhammad':{balance:150000}},city_identity:{code,created:123},vehicle_rentals:{},travel_passes:{player:{code,expires:10000}},receipts:{player:{amount:0,pass_code:code}}};
function fixture(){
 let clock=Date.parse('2026-10-15T12:00:00Z');const users=new Map(),tokens=new Map(),rows=new Map(),calls=[];
 const response=(v,status=200)=>new Response(JSON.stringify(v),{status});
 async function fetcher(url,options={}){
  const u=new URL(url),method=options.method||'GET',body=options.body?JSON.parse(options.body):{};calls.push({path:u.pathname,method,headers:options.headers});
  if(u.pathname==='/auth/v1/admin/users'){
   if(users.has(body.email))return response({error:'exists'},422);
   const user={id:'user-'+(users.size+1),email:body.email,password:body.password,app_metadata:body.app_metadata};users.set(body.email,user);return response({id:user.id});
  }
  if(u.pathname==='/auth/v1/token'){
   const user=u.searchParams.get('grant_type')==='refresh_token'?tokens.get(body.refresh_token):users.get(body.email);
   if(!user||('password'in body&&body.password!==user.password))return response({error:'invalid'},401);
   const token='access-'+user.id,refresh='refresh-'+user.id;tokens.set(token,user);tokens.set(refresh,user);return response({access_token:token,refresh_token:refresh,expires_in:3600});
  }
  if(u.pathname==='/auth/v1/user'){
   const user=tokens.get(options.headers.Authorization.replace('Bearer ',''));return user?response({id:user.id,app_metadata:user.app_metadata}):response({},401);
  }
  assert.equal(options.headers.apikey,'server-only-key');
  if(u.pathname==='/rest/v1/city_accounts'){
   if(method==='POST'){if(rows.has(body.id))return response([]);rows.set(body.id,{writer:'',lease_until:'1970-01-01T00:00:00Z',current_peer:'',...structuredClone(body)});return response([body]);}
   const id=u.searchParams.get('id')?.slice(3),row=rows.get(id);
   if(method==='GET')return response(row?[structuredClone(row)]:[]);
   if(!row)return response([]);
   for(const key of ['revision','writer'])if(u.searchParams.has(key)&&String(row[key])!==u.searchParams.get(key).slice(3))return response([]);
   Object.assign(row,structuredClone(body));return response([structuredClone(row)]);
  }
  throw new Error('Unexpected request '+url);
 }
 const handler=createHandler({url:'https://game.example',serviceKey:'server-only-key',anonKey:'public-key',fetcher,now:()=>clock});
 async function request(body,token){const result=await handler(new Request('https://edge.example',{method:'POST',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:JSON.stringify(body)}));return {status:result.status,body:await result.json()};}
 return {request,rows,calls,users,advance(ms){clock+=ms}};
}
test('private code is removed and wallets are validated before storing',()=>{
 assert(!cleanSnapshot(state).city_identity.code);assert(!JSON.stringify(cleanSnapshot(state)).includes(code));assert.equal(state.city_identity.code,code);
 assert.throws(()=>cleanSnapshot({...state,accounts:{a:{balance:-1}}}),/Invalid wallet/);
 assert.throws(()=>cleanSnapshot({...state,accounts:{a:{balance:1.3}}}),/Invalid wallet/);
 assert.throws(()=>cleanSnapshot({...state,huge:'x'.repeat(480001)}),/size limit/);
});
test('account create, save, recovery, account isolation and controller scope',async()=>{
 const f=fixture(),created=await f.request({action:'create',code:code.toLowerCase(),writer,state});
 assert.equal(created.status,200);assert(created.body.created);assert(!created.body.state.city_identity.code);assert(!JSON.stringify(created.body).includes('server-only-key'));
 const token=created.body.access_token;
 const changed=structuredClone(state);changed.accounts['player/Muhammad'].balance=90000;changed.vehicle_rentals.car={expires:999};changed.travel_passes.day={expires:123};
 const saved=await f.request({action:'save',writer,revision:1,state:changed,pair_code:'ABC234'},token);assert.equal(saved.body.revision,2);
 const controller=await f.request({action:'controller',code});assert.deepEqual(controller.body,{pair_code:'ABC234'});assert(!controller.body.state&&!controller.body.access_token);
 const recovery=await f.request({action:'login',code,writer});assert.equal(recovery.body.state.accounts['player/Muhammad'].balance,90000);assert(recovery.body.state.vehicle_rentals.car);assert.equal(recovery.body.revision,2);
 const another=await f.request({action:'create',code:other,writer,state});assert.equal(another.status,200);assert.equal(another.body.state.accounts['player/Muhammad'].balance,150000);
 await f.request({action:'save',writer,revision:1,state:{...state,accounts:{private:{balance:7}}}},another.body.access_token);
 assert.equal(f.rows.get('user-1').state.accounts['player/Muhammad'].balance,90000);
 assert.equal((await f.request({action:'save',writer,revision:2,state})).status,401);
 assert.equal((await f.request({action:'login',code:'ABCDEFGHJKLMNPQS',writer})).status,401);
 assert.equal((await f.request({action:'refresh',refresh_token:created.body.refresh_token})).status,200);
 const repeat=await f.request({action:'create',code,writer,state});assert.equal(repeat.body.created,false);assert.equal(repeat.body.state.accounts['player/Muhammad'].balance,90000,'create never overwrites an existing account');
 assert.match(await accountEmail(code),/^city-[a-f0-9]{64}@accounts.invalid$/);
});
test('single writer, explicit takeover, stale revision rejection and expiry',async()=>{
 const f=fixture(),a=await f.request({action:'create',code,writer,state}),token=a.body.access_token;
 assert.equal((await f.request({action:'login',code,writer:second})).status,409);
 assert.equal((await f.request({action:'login',code,writer:second,take_over:true})).status,200);
 assert.equal((await f.request({action:'save',writer,revision:1,state},token)).status,409);
 assert.equal((await f.request({action:'save',writer:second,revision:1,state},token)).status,200);
 assert.equal((await f.request({action:'save',writer:second,revision:1,state},token)).status,409);
 f.advance(90001);
 assert.equal((await f.request({action:'heartbeat',writer:second},token)).status,409);
 assert.deepEqual((await f.request({action:'controller',code})).body,{pair_code:null});
 assert.equal((await f.request({action:'claim',writer},token)).status,200);
 assert.equal((await f.request({action:'release',writer},token)).status,200);
 assert.equal(f.rows.get('user-1').writer,'');
});
test('concurrent logins and saves cannot both win the same revision',async()=>{
 const f=fixture(),a=await f.request({action:'create',code,writer,state}),token=a.body.access_token;f.advance(90001);
 const claims=await Promise.all([f.request({action:'login',code,writer:second}),f.request({action:'login',code,writer:'browser-session-3333'})]);assert.deepEqual(claims.map(r=>r.status).sort(),[200,409]);
 const active=f.rows.get('user-1').writer;
 const saves=await Promise.all([f.request({action:'save',writer:active,revision:1,state},token),f.request({action:'save',writer:active,revision:1,state},token)]);assert.deepEqual(saves.map(r=>r.status).sort(),[200,409]);assert.equal(f.rows.get('user-1').revision,2);
});
