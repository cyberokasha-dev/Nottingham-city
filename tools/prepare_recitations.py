"""Reproduce the bundled Sudais surahs from their credited MP3Quran sources.
Requires ffmpeg; source hashes are pinned in transport/recitations/sources.json.
"""
import hashlib,json,pathlib,subprocess,tempfile,urllib.request
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'transport/recitations'
with tempfile.TemporaryDirectory() as task:
    for record in json.loads((out/'sources.json').read_text()):
        with urllib.request.urlopen(record['source'],timeout=60) as response:
            data=response.read()
        if hashlib.sha256(data).hexdigest()!=record['source_sha256']:
            raise ValueError(f"Source changed for surah {record['surah']}; review it before updating")
        raw=pathlib.Path(task)/'source.mp3'
        raw.write_bytes(data)
        subprocess.run(['ffmpeg','-v','error','-y','-i',str(raw),'-c:a','libvorbis','-q:a','2',str(out/record['file'])],check=True)
        print(record['surah'],record['name'])
