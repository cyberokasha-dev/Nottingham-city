// No city credential or privileged key is ever returned or stored in a snapshot.
export const normalizeCode = value => String(value || '').toUpperCase().replace(/[\s-]/g, '');
export function cleanSnapshot(input) {
 if (!input || input.version !== 1 || !input.accounts || typeof input.accounts !== 'object' || Array.isArray(input.accounts)) throw new Error('Invalid city save');
 const out = structuredClone(input);
 if (out.city_identity) delete out.city_identity.code;
 for(const pass of Object.values(out.travel_passes||{}))delete pass.code;
 for(const receipt of Object.values(out.receipts||{}))delete receipt.pass_code;
 if (JSON.stringify(out).length > 480000) throw new Error('City save exceeds its size limit');
 for (const a of Object.values(out.accounts)) if (!a || !Number.isSafeInteger(a.balance) || a.balance < 0) throw new Error('Invalid wallet');
 return out;
}
export async function accountEmail(code) {
 const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(code));
 return `city-${Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2, '0')).join('')}@accounts.invalid`;
}
export function createHandler({url, serviceKey, anonKey, fetcher = fetch, now = () => Date.now()}) {
 const headers = {'apikey':serviceKey,'Authorization':`Bearer ${serviceKey}`,'Content-Type':'application/json'};
 const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Cache-Control':'no-store'};
 const reply = (value,status=200) => new Response(JSON.stringify(value), {status,headers:{...cors,'Content-Type':'application/json'}});
 async function api(path, opts={}) {
  const response=await fetcher(url+path,{...opts,headers:{...headers,...opts.headers}});
  const text=await response.text();let result;try{result=JSON.parse(text)}catch{result={}}
  return {ok:response.ok,status:response.status,value:result};
 }
 function session(d) {return {access_token:d.access_token,refresh_token:d.refresh_token,expires_in:d.expires_in};}
 return async req => {
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return reply({error:'POST required'},405);
  if(!url||!serviceKey)return reply({error:'Account service is not configured'},503);
  try {
   const raw=await req.text();if(raw.length>500000)return reply({error:'Request too large'},413);
   const body=JSON.parse(raw);const action=String(body.action||'');
   let token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');let auth;
   if(['create','login','controller'].includes(action)) {
    const code=normalizeCode(body.code);if(!/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{16}$/.test(code))return reply({error:'Use the sixteen-character private city code'},400);
    const email=await accountEmail(code);
    if(action==='create') {
     const created=await api('/auth/v1/admin/users',{method:'POST',body:JSON.stringify({email,password:code,email_confirm:true,app_metadata:{app:'nottingham-city'}})});
     if(!created.ok && created.status!==422)return reply({error:'Account could not be created. Try again later.'},503);
    }
    const signed=await api('/auth/v1/token?grant_type=password',{method:'POST',headers:{apikey:anonKey||serviceKey},body:JSON.stringify({email,password:code})});
    if(!signed.ok)return reply({error:'City code not recognised, or too many sign-in attempts'},401);
    token=signed.value.access_token;auth=signed.value;
   } else if(action==='refresh') {
    const refreshed=await api('/auth/v1/token?grant_type=refresh_token',{method:'POST',headers:{apikey:anonKey||serviceKey},body:JSON.stringify({refresh_token:body.refresh_token})});
    return refreshed.ok ? reply(session(refreshed.value)) : reply({error:'Sign in with your city code again'},401);
   }
   if(!token)return reply({error:'Sign in first'},401);
   const user=await api('/auth/v1/user',{headers:{Authorization:`Bearer ${token}`}});
   if(!user.ok||!user.value.id||user.value.app_metadata?.app!=='nottingham-city')return reply({error:'Invalid city session'},401);
   const id=user.value.id;const resource='/rest/v1/city_accounts?id=eq.'+encodeURIComponent(id);
   let stored=await api(resource+'&select=*');if(!stored.ok)return reply({error:'Account storage is unavailable'},503);
   let row=stored.value[0];let createdAccount=false;
   if(!row && action==='create') {
    const state=cleanSnapshot(body.state);
    const created=await api('/rest/v1/city_accounts',{method:'POST',headers:{Prefer:'resolution=ignore-duplicates,return=representation'},body:JSON.stringify({id,state,revision:1})});
    if(!created.ok)return reply({error:'Could not save the new account'},503);
    stored=await api(resource+'&select=*');row=stored.value[0];createdAccount=created.value.length===1;
   }
   if(!row)return reply({error:'This account has no city save yet'},404);
   if(action==='controller')return reply({pair_code:Date.parse(row.lease_until)>now()?row.current_peer:null});
   if(['login','create','claim'].includes(action)) {
    const writer=String(body.writer||'');if(!/^[a-zA-Z0-9-]{16,64}$/.test(writer))return reply({error:'Invalid game session'},400);
    if(row.writer && row.writer!==writer && Date.parse(row.lease_until)>now() && body.take_over!==true)return reply({error:'Your city account is active in another game. Close it, or choose Resume here.',busy:true},409);
    // Compare the row revision AND old writer lease, so concurrent logins cannot both acquire it.
    const filter=resource+'&revision=eq.'+row.revision+'&writer=eq.'+encodeURIComponent(row.writer||'');
    const updated=await api(filter,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({writer,lease_until:new Date(now()+90000).toISOString(),current_peer:''})});
    if(!updated.ok||updated.value.length!==1)return reply({error:'Account changed on another device. Try signing in again.'},409);
    return reply({...(auth?session(auth):{}),state:row.state,revision:row.revision,created:createdAccount});
   }
   const writer=String(body.writer||'');
   if(row.writer!==writer || Date.parse(row.lease_until)<=now())return reply({error:'Account is active elsewhere. Resume it here to continue saving.',busy:true},409);
   const guard=resource+'&writer=eq.'+encodeURIComponent(writer)+'&revision=eq.'+row.revision;
   if(action==='save') {
    if(body.revision!==row.revision)return reply({error:'A newer account save exists. Reload it before continuing.',conflict:true},409);
    const state=cleanSnapshot(body.state);
    const updated=await api(guard,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({state,revision:row.revision+1,lease_until:new Date(now()+90000).toISOString(),current_peer:/^[A-Z2-9]{6}$/.test(body.pair_code)?body.pair_code:''})});
    if(!updated.ok||updated.value.length!==1)return reply({error:'Account changed on another device',conflict:true},409);
    return reply({revision:row.revision+1});
   }
   if(action==='heartbeat') {
    const updated=await api(guard,{method:'PATCH',headers:{Prefer:'return=representation'},body:JSON.stringify({lease_until:new Date(now()+90000).toISOString(),current_peer:/^[A-Z2-9]{6}$/.test(body.pair_code)?body.pair_code:''})});
    return updated.ok&&updated.value.length===1?reply({ok:true}):reply({error:'Session changed'},409);
   }
   if(action==='release') {
    await api(guard,{method:'PATCH',body:JSON.stringify({writer:'',lease_until:'1970-01-01T00:00:00Z',current_peer:''})});return reply({ok:true});
   }
   return reply({error:'Unknown account action'},400);
  }catch(error){return reply({error:['Invalid city save','City save exceeds its size limit','Invalid wallet'].includes(error.message)?error.message:'Account request failed'},400)}
 };
}
