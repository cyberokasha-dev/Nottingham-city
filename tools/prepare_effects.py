"""Generate original, deterministic city sound effects; no third-party recordings."""
from pathlib import Path
import math, random, struct, wave
OUT=Path(__file__).resolve().parents[1]/'simulation/audio'
OUT.mkdir(exist_ok=True)
RATE=22050
for name,duration in [('engine',2),('electric',2),('bus',2),('punch',.23),('whoosh',.18),('kick',.26),('door',.7),('goal',.7)]:
 rng=random.Random(13)
 frames=bytearray()
 smooth=0
 for i in range(int(RATE*duration)):
  t=i/RATE; noise=rng.uniform(-1,1); smooth=.91*smooth+.09*noise
  if name in ('engine','electric','bus'):
   freq={'engine':52,'electric':180,'bus':38}[name]
   v=(.28*math.sin(2*math.pi*freq*t)+.13*math.sin(4*math.pi*freq*t)+.07*math.sin(6*math.pi*freq*t)+.12*smooth)
   if name=='electric': v*=.5
  elif name=='goal':
   freq=[523.25,659.25,783.99][min(2,int(t/.23))]; v=.3*math.sin(2*math.pi*freq*t)*min(1,t*60)*max(0,1-t/duration)
  elif name=='door': v=.4*smooth*math.sin(math.pi*t/duration)+.1*math.sin(2*math.pi*700*t)*math.exp(-t*24)
  else:
   freq=85 if name=='kick' else 125
   v=(.6*math.sin(2*math.pi*freq*t)+.5*noise)*math.exp(-t*(23 if name!='whoosh' else 14))*min(1,t*700)
  frames.extend(struct.pack('<h',int(max(-1,min(1,v))*23000)))
 with wave.open(str(OUT/(name+'.wav')),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(frames)
