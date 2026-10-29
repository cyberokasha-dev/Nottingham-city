"""Tailor the existing CC0 male/female rigs, retaining skin weights and every clip.
Run after prepare_human.py. Already-refined inputs are left unchanged.
"""
import json
import struct
from pathlib import Path
import numpy as np
from prepare_human import read_glb, values

ROOT = Path(__file__).resolve().parents[1]
for name in ['human', 'human_female']:
    path = ROOT / 'player/models' / (name+'.glb')
    doc, binary, _ = read_glb(path)
    if doc['asset'].get('extras', {}).get('city_tailored'): continue
    bind = values(doc,binary,doc['skins'][0]['inverseBindMatrices'])
    centres = {doc['nodes'][n]['name']:np.linalg.inv(bind[i].reshape(4,4,order='F'))[:3,3] for i,n in enumerate(doc['skins'][0]['joints'])}
    def append(data):
        data = np.asarray(data,dtype='<f4')
        binary.extend(b'\0'*(-len(binary)%4)); offset=len(binary); binary.extend(data.tobytes())
        view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':data.nbytes})
        index=len(doc['accessors']);doc['accessors'].append({'bufferView':view,'componentType':5126,'count':len(data),'type':'VEC3','min':data.min(0).tolist(),'max':data.max(0).tolist()})
        return index
    for mesh in doc['meshes']:
        if mesh['name'].startswith(('Face','Eyes','Eyebrows','Pupil','Short hair','Tied hair','Sneaker','Sole')): continue
        for p in mesh['primitives']:
            pos=values(doc,binary,p['attributes']['POSITION'])
            joints=values(doc,binary,p['attributes']['JOINTS_0']);weights=values(doc,binary,p['attributes']['WEIGHTS_0'])
            names=np.array([doc['nodes'][doc['skins'][0]['joints'][int(j)]]['name'] for j in joints[np.arange(len(pos)),weights.argmax(1)]])
            for side in ['l','r']:
                for bone,end,factor in [('upperarm_','lowerarm_',.72),('lowerarm_','hand_',.84),('thigh_','calf_',.9)]:
                    bone+=side;end+=side;mask=names==bone
                    axis=centres[end]-centres[bone];axis/=np.linalg.norm(axis)
                    offset=pos[mask]-centres[bone];axial=(offset@axis)[:,None]*axis
                    pos[mask]=centres[bone]+axial+(offset-axial)*factor
            torso=(pos[:,1]>.98)&(pos[:,1]<1.54)&(abs(pos[:,0])<.23)
            pos[torso,0]*=.9;pos[torso,2]*=.86
            indices=values(doc,binary,p['indices']).astype(int).reshape(-1,3)
            triangles=pos[indices];faces=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]);normals=np.zeros_like(pos)
            for c in range(3):np.add.at(normals,indices[:,c],faces)
            normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-9)
            old=values(doc,binary,p['attributes']['NORMAL'])
            if np.mean(np.sum(normals*old,axis=1))<0:normals*=-1
            p['attributes']['POSITION']=append(pos);p['attributes']['NORMAL']=append(normals)
    doc['asset'].setdefault('extras',{})['city_tailored']=True
    binary.extend(b'\0'*(-len(binary)%4));doc['buffers']=[{'byteLength':len(binary)}]
    encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
    print(name,'tailored',path.stat().st_size)
