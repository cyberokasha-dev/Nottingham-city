(function () {
  'use strict';
  if (window.NottCityTouch) return;
  // Desktop touchscreens and resized laptop windows keep their usual controls.
  const phone = navigator.maxTouchPoints > 0 && /Android.*Mobile|iPhone|iPod|Windows Phone/i.test(navigator.userAgent);
  const api = window.NottCityTouch = { enabled: phone, callback: null, lastUI: null };
  if (!phone) return;
  const style = document.createElement('style');
  style.textContent = `
    #city-touch {position:fixed;inset:0;z-index:99990;pointer-events:none;font:600 12px system-ui,sans-serif;color:white;--edge:12px;--stick:118px;--key:48px;--gap:8px;--safe-left:env(safe-area-inset-left,0px);--safe-top:env(safe-area-inset-top,0px);--safe-right:env(safe-area-inset-right,0px);--safe-bottom:env(safe-area-inset-bottom,0px);--bottom:calc(env(safe-area-inset-bottom) + 14px)}
    #city-touch *{box-sizing:border-box;-webkit-tap-highlight-color:transparent;user-select:none}
    #city-touch button,#city-touch .touch-stick{pointer-events:auto;touch-action:none;color:#f4faff;border:1px solid #b4d8e36b;background:#0c1e32a8;box-shadow:0 2px 8px #0003}
    #city-touch button{min-height:44px;min-width:44px;border-radius:14px;font:600 12px system-ui;padding:8px;display:grid;place-content:center;line-height:1.1}
    #city-touch button.held{background:#397fabbf;border-color:#fff}
    #city-touch .touch-top{position:absolute;left:calc(env(safe-area-inset-left) + var(--edge));right:calc(env(safe-area-inset-right) + var(--edge));top:calc(env(safe-area-inset-top) + 10px);display:flex;gap:6px;justify-content:flex-end}
    #city-touch .touch-stick{position:absolute;left:calc(env(safe-area-inset-left) + var(--edge));bottom:var(--bottom);width:var(--stick);height:var(--stick);border-radius:50%;background:#142b3e50}
    #city-touch .touch-stick:after{content:attr(data-label);position:absolute;inset:auto 0 12px;text-align:center;font-size:10px;pointer-events:none;opacity:.8}
    #city-touch .touch-knob{position:absolute;width:44px;height:44px;left:50%;top:50%;margin:-22px;border:1px solid #d6edffc2;border-radius:50%;background:#86bddd59;pointer-events:none}
    #city-touch .touch-wheel{position:absolute;inset:12%;width:76%;height:76%;pointer-events:none;transform-origin:center;transition:transform 50ms linear;color:#cae8ff}
    #city-touch .touch-actions{position:absolute;right:calc(env(safe-area-inset-right) + var(--edge));bottom:var(--bottom);display:grid;grid-template-columns:repeat(2,var(--key));gap:var(--gap)}
    #city-touch .touch-actions button{width:var(--key);height:var(--key);border-radius:50%}
    #city-touch .touch-actions b{font-size:19px;font-weight:500}#city-touch .touch-actions small{font-size:9px;display:block;margin-top:2px}
    #city-touch .touch-back{position:absolute;right:calc(env(safe-area-inset-right) + 12px);bottom:var(--bottom)}
    #city-touch [hidden]{display:none!important}
    #city-touch .touch-extra{position:absolute;right:calc(env(safe-area-inset-right) + var(--edge));bottom:calc(var(--bottom) + 174px);display:flex;gap:6px}
    @media(orientation:landscape){#city-touch{--stick:112px;--key:44px;--gap:6px;--bottom:calc(env(safe-area-inset-bottom) + 10px)}#city-touch .touch-top{left:auto}#city-touch .touch-extra{bottom:calc(var(--bottom) + 152px)}}
    @media(min-width:410px) and (orientation:portrait){#city-touch{--stick:132px;--key:50px}}
    @media(max-height:350px) and (orientation:landscape){#city-touch{--stick:96px;--key:44px;--gap:4px}#city-touch .touch-extra{bottom:calc(var(--bottom) + 144px)}}
  `;
  document.head.appendChild(style);
  const root = document.createElement('div'); root.id = 'city-touch'; root.setAttribute('aria-label','Phone game controls');
  const top = document.createElement('nav');top.className='touch-top';root.appendChild(top);
  const actions = document.createElement('div');actions.className='touch-actions';root.appendChild(actions);
  const extra=document.createElement('div');extra.className='touch-extra';root.appendChild(extra);
  const stick = document.createElement('div');stick.className='touch-stick';stick.dataset.label='MOVE';stick.setAttribute('role','group');stick.setAttribute('aria-label','Move character');
  const knob=document.createElement('div');knob.className='touch-knob';stick.appendChild(knob);
  const wheel=document.createElementNS('http://www.w3.org/2000/svg','svg');wheel.setAttribute('viewBox','0 0 100 100');wheel.classList.add('touch-wheel');wheel.innerHTML='<circle cx="50" cy="50" r="43" fill="none" stroke="currentColor" stroke-width="7"/><path d="M10 45 L90 45 M50 47 L50 92" stroke="currentColor" stroke-width="6"/><circle cx="50" cy="50" r="12" fill="currentColor"/>';wheel.hidden=true;stick.appendChild(wheel);root.appendChild(stick);
  const held=new Map();let pid=null,x=0,y=0,context='play',driving=false;
  function emit(data){api.callback?.(JSON.stringify(data));}
  function state(){emit({t:'state',x,y,b:[...new Set(held.values())]});}
  function renderStick(){knob.style.transform=`translate(${x*stick.clientWidth*.28}px,${y*stick.clientWidth*.28}px)`;wheel.style.transform=`rotate(${x*135}deg)`;}
  function reset(){pid=null;x=y=0;held.clear();root.querySelectorAll('.held').forEach(b=>b.classList.remove('held'));renderStick();state();}
  function command(action){reset();emit({t:'command',action});}
  function button(parent,label,aria,action){const b=document.createElement('button');b.type='button';b.textContent=label;b.setAttribute('aria-label',aria);b.dataset.command=action;b.onclick=()=>command(action);parent.appendChild(b);return b;}
  button(top,'Phone','Open city phone','phone');button(top,'Map','Open city map','map');button(top,'People','Choose character','characters');button(top,'Camera','Change camera','camera');
  const full=button(top,'Full','Toggle fullscreen','');full.onclick=async()=>{reset();try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen();}catch{}};
  const back=button(root,'Back','Close menu or go back','back');back.className='touch-back';back.hidden=true;
  function control(label,symbol,name){const b=document.createElement('button');b.innerHTML='<b>'+symbol+'</b><small>'+label+'</small>';b.setAttribute('aria-label',label);b.dataset.control=name;actions.appendChild(b);
    b.onpointerdown=e=>{if(context!=='play')return;e.preventDefault();held.set(e.pointerId,b.dataset.control);b.classList.add('held');b.setPointerCapture(e.pointerId);state();};
    const end=e=>{if(!held.has(e.pointerId))return;held.delete(e.pointerId);b.classList.remove('held');state();};b.onpointerup=b.onpointercancel=b.onlostpointercapture=end;return b;}
  const interact=control('Enter / use','△','TRIANGLE'),jump=control('Jump','□','SQUARE'),punch=control('Punch','○','CIRCLE'),run=control('Run','×','CROSS'),brake=control('Brake','↓','L2'),gas=control('Accelerate','↑','R2');
  button(extra,'Guard','Guard','');const guard=extra.lastChild;guard.removeAttribute('data-command');guard.onpointerdown=e=>{e.preventDefault();held.set(e.pointerId,'L1');guard.setPointerCapture(e.pointerId);state();};guard.onclick=null;const guardUp=e=>{held.delete(e.pointerId);state();};guard.onpointerup=guard.onpointercancel=guard.onlostpointercapture=guardUp;
  button(extra,'Heavy','Heavy punch','');const heavy=extra.lastChild;heavy.removeAttribute('data-command');heavy.onpointerdown=e=>{e.preventDefault();held.set(e.pointerId,'R1');heavy.setPointerCapture(e.pointerId);state();};heavy.onclick=null;heavy.onpointerup=heavy.onpointercancel=heavy.onlostpointercapture=guardUp;
  function move(e){const r=stick.getBoundingClientRect(),max=r.width*.28;let dx=(e.clientX-r.x-r.width/2)/max,dy=(e.clientY-r.y-r.height/2)/max;const length=Math.max(1,Math.hypot(dx,dy));x=dx/length;y=dy/length;renderStick();state();}
  stick.onpointerdown=e=>{if(pid!==null||context!=='play')return;e.preventDefault();pid=e.pointerId;stick.setPointerCapture(pid);move(e);};stick.onpointermove=e=>{if(pid===e.pointerId)move(e);};
  const endStick=e=>{if(e.pointerId!==pid)return;pid=null;x=y=0;renderStick();state();};stick.onpointerup=stick.onpointercancel=stick.onlostpointercapture=endStick;
  function resize(){reset();const css=getComputedStyle(root);emit({t:'resize',width:innerWidth,height:innerHeight,safe:['left','top','right','bottom'].map(side=>parseFloat(css.getPropertyValue('--safe-'+side))||0)});}
  api.setCallback=fn=>{api.callback=fn;resize();};
  api.update=json=>{const d=JSON.parse(json);api.lastUI=d;const next=d.context||'play',drive=d.mode==='Driving',key=next+'|'+drive;if(api.renderKey===key)return;api.renderKey=key;reset();context=next;driving=drive;
    const play=context==='play';stick.hidden=actions.hidden=!play;extra.hidden=!play||driving;top.hidden=!play;back.hidden=play||context==='phone'||context==='map';
    gas.hidden=brake.hidden=!driving;jump.hidden=punch.hidden=driving;wheel.style.display=driving?'block':'none';knob.hidden=driving;stick.dataset.label=driving?'STEER':'MOVE';stick.setAttribute('aria-label',driving?'Steer vehicle':'Move character');
    run.querySelector('small').textContent=driving?'Handbrake':'Run';interact.querySelector('small').textContent=driving?'Exit':'Enter / use';
    // Pairing belongs to the companion-controller page; local play needs no code.
    const pair=window.NottCityPhone?.ui;if(pair){pair.btn.hidden=true;if(pair.panel.style.display!=='none')pair.panel.style.display='none';}
  };
  root.addEventListener('contextmenu',e=>e.preventDefault());
  addEventListener('resize',resize);addEventListener('blur',reset);addEventListener('pagehide',reset);document.addEventListener('visibilitychange',()=>{if(document.hidden)reset();});
  setInterval(()=>{if(pid!==null||held.size)state();},100);
  document.body.appendChild(root);
})();
