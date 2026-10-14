"""Original Aurora lines, synthesized with credited en_GB Alba Piper model."""
import json,pathlib,subprocess,sys,tempfile,wave
root=pathlib.Path(__file__).resolve().parents[1]
lines=json.loads((root/'simulation/cab_lines.json').read_text())
with tempfile.TemporaryDirectory() as task:
 temp=pathlib.Path(task)
 req=[{'text':v,'output_file':str(temp/(k+'.wav'))} for k,v in lines.items()]
 subprocess.run([sys.argv[1],'--model',sys.argv[2],'--length_scale','0.92','--json-input'],input='\n'.join(map(json.dumps,req))+'\n',text=True,check=True)
 frames=bytearray(); catalog={};rate=22050
 for k,v in lines.items():
  with wave.open(str(temp/(k+'.wav'))) as w:
   rate=w.getframerate(); data=w.readframes(w.getnframes())
  catalog[k]={'start':len(frames)/2/rate,'duration':len(data)/2/rate,'text':v}; frames.extend(data); frames.extend(bytes(rate))
 combined=temp/'cab.wav'
 with wave.open(str(combined),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(frames)
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(combined),'-c:a','libvorbis','-q:a','3',str(root/'simulation/audio/aurora.ogg')],check=True)
 (root/'simulation/cab_voice_catalog.gd').write_text('extends RefCounted\nconst LINES := '+json.dumps(catalog,indent=2)+'\n')
