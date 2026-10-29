"""Fit the CC0 rig to Muhammad's photo references and add a selectable arms-folded pose.
Photo likeness uses an imagegen-created albedo, not an automatic biometric scan.
"""
import json,struct,sys,math
from pathlib import Path
import numpy as np
from scipy.spatial.transform import Rotation as Rotation
from prepare_human import read_glb,values,quat_mul
ROOT=Path(__file__).resolve().parents[1]
doc,binary,_=read_glb(ROOT/'player/models/human.glb')
def append(array,kind,component=5126):
 dtype={5126:'<f4',5123:'<u2'}[component];array=np.array(array,dtype=dtype)
 binary.extend(b'\0'*(-len(binary)%4));offset=len(binary);binary.extend(array.tobytes())
 view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':array.nbytes})
 index=len(doc['accessors']);a={'bufferView':view,'componentType':component,'count':len(array),'type':kind}
 if kind in ['SCALAR','VEC3']:a.update(min=array.min(0).tolist(),max=array.max(0).tolist())
 doc['accessors'].append(a);return index
# The head texture carries the eyes and eyebrows; remove template face overlays.
remove=[]
bind=values(doc,binary,doc['skins'][0]['inverseBindMatrices'])
bone_centres={doc['nodes'][node]['name']:np.linalg.inv(bind[i].reshape(4,4,order='F'))[:3,3] for i,node in enumerate(doc['skins'][0]['joints'])}
ends={"upperarm_l":"lowerarm_l","lowerarm_l":"hand_l","upperarm_r":"lowerarm_r","lowerarm_r":"hand_r","thigh_l":"calf_l","calf_l":"foot_l","thigh_r":"calf_r","calf_r":"foot_r"}
for i,node in enumerate(doc['nodes']):
 if 'mesh' not in node:continue
 mesh=doc['meshes'][node['mesh']]
 if mesh['name'] in ['Face','Pupil','Short hair']: remove.append(i);continue
 for primitive in mesh['primitives']:
  positions=values(doc,binary,primitive['attributes']['POSITION'])
  colours=values(doc,binary,primitive['attributes']['COLOR_0'])
  y=positions[:,1]
  if mesh['name'].startswith(('Sneaker','Sole')):
   colours[:]=[0.028,0.045,0.07,1] if mesh['name'].startswith('Sneaker') else [0.67,0.67,0.61,1]
  elif mesh['name']=='Short hair':
   positions[:,1]=1.77+(positions[:,1]-1.77)*0.75
  else:
   joints=values(doc,binary,primitive['attributes']['JOINTS_0'])
   weights=values(doc,binary,primitive['attributes']['WEIGHTS_0'])
   primary=joints[np.arange(len(joints)),weights.argmax(1)]
   names=np.array([doc['nodes'][doc['skins'][0]['joints'][int(i)]]['name'] for i in primary])
   colours[:]=[0.24,0.115,0.070,1]
   torso=(y>.98)&(y<1.54)&(abs(positions[:,0])<.23)
   colours[torso]=[0.045,0.40,0.46,1]
   pants=(y>=.14)&(y<=.98)
   colours[pants]=[0.64,0.46,0.29,1]
   colours[y<.14]=[0.028,0.045,0.07,1]
   for bone,end in ends.items():
    mask=names==bone
    axis=bone_centres[end]-bone_centres[bone];axis/=np.linalg.norm(axis)
    offsets=positions[mask]-bone_centres[bone]
    axial=offsets@axis
    radial=offsets-axial[:,None]*axis
    factor=.62 if bone.startswith(('upperarm','lowerarm')) else (.8 if bone.startswith('thigh') else 1.12)
    if bone.startswith(('thigh','calf')):
     radius=np.linalg.norm(radial,axis=1)
     desired=np.maximum(radius*factor,.066)
     radial*= (desired/np.maximum(radius,1e-6))[:,None]
     factor=1
    positions[mask]=bone_centres[bone]+axial[:,None]*axis+radial*factor
    if bone.startswith('upperarm'):
     sleeve_mask=mask.copy();sleeve_mask[mask]=axial<.125
     colours[sleeve_mask]=[0.045,0.40,0.46,1]
   positions[torso,0]*=.78
   positions[torso,2]*=.72
   front=torso&(positions[:,2]>.01)
   positions[front,2]=.105*np.sqrt(np.maximum(.1,1-(positions[front,0]/.19)**2))
  uv=np.column_stack([0.5+positions[:,0]*3.65,np.interp(positions[:,1],[1.595,1.635,1.665,1.70,1.76,1.815],[.95,.80,.66,.48,.24,.03])])
  colours[:,3]=0
  face=(positions[:,1]>1.59)&(positions[:,1]<1.818)
  colours[face,3]=np.clip((positions[face,2]-.015)/.04,0,1)
  indices=values(doc,binary,primitive['indices']).astype(int).reshape(-1,3)
  triangles=positions[indices]
  fn=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0])
  normals=np.zeros_like(positions)
  for corner in range(3):np.add.at(normals,indices[:,corner],fn)
  normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-9)
  old=values(doc,binary,primitive['attributes']['NORMAL'])
  if np.mean(np.sum(normals*old,axis=1))<0:normals*=-1
  primitive['attributes']['NORMAL']=append(normals,'VEC3')
  primitive['attributes']['TEXCOORD_0']=append(uv,'VEC2')
  rest_uv=np.column_stack([positions[:,0],positions[:,1]])
  primitive['attributes']['TEXCOORD_1']=append(rest_uv,'VEC2')
  primitive['attributes']['POSITION']=append(positions,'VEC3')
  primitive['attributes']['COLOR_0']=append(colours,'VEC4')
for i in remove:
 doc['nodes'][i].pop('mesh',None)
 doc['nodes'][i].pop('skin',None)
for node in doc['nodes']:
 if 'children' in node:node['children']=[i for i in node['children'] if i not in remove]
# Two-bone IK creates a relaxed standing idle and a separate crossed-arms action.
parents={child:i for i,node in enumerate(doc['nodes']) for child in node.get('children',[])}
by_name={n.get('name'):i for i,n in enumerate(doc['nodes'])}
rotations={i:np.array(n.get('rotation',[0,0,0,1])) for i,n in enumerate(doc['nodes'])}
translations={i:np.array(n.get('translation',[0,0,0])) for i,n in enumerate(doc['nodes'])}
def global_matrix(i):
 m=np.eye(4);m[:3,:3]=Rotation.from_quat(rotations[i]).as_matrix();m[:3,3]=translations[i]
 return global_matrix(parents[i])@m if i in parents else m
def align(bone,child,target):
 i=by_name[bone];j=by_name[child];current=global_matrix(i);child_m=global_matrix(j)
 a=child_m[:3,3]-current[:3,3];a/=np.linalg.norm(a)
 b=target-current[:3,3];b/=np.linalg.norm(b)
 cross=np.cross(a,b);dot=np.clip(a@b,-1,1)
 if np.linalg.norm(cross)<1e-7:return
 turn=Rotation.from_rotvec(cross/np.linalg.norm(cross)*math.acos(dot)).as_matrix()
 parent=global_matrix(parents[i])[:3,:3]
 rotations[i]=Rotation.from_matrix(np.linalg.inv(parent)@turn@current[:3,:3]).as_quat()
rest_rotations={i:q.copy() for i,q in rotations.items()}
def solve_arms(targets):
 global rotations
 rotations={i:q.copy() for i,q in rest_rotations.items()}
 for side,hand_target,pole in targets:
  shoulder=global_matrix(by_name['upperarm_'+side])[:3,3]
  elbow0=global_matrix(by_name['lowerarm_'+side])[:3,3]
  wrist0=global_matrix(by_name['hand_'+side])[:3,3]
  l1=np.linalg.norm(elbow0-shoulder);l2=np.linalg.norm(wrist0-elbow0)
  target=np.array(hand_target);v=target-shoulder;distance=np.linalg.norm(v);v/=distance
  distance=min(distance,l1+l2-.005);target=shoulder+v*distance
  along=(l1*l1-l2*l2+distance*distance)/(2*distance)
  normal=np.array(pole)-shoulder;normal-=v*(normal@v);normal/=np.linalg.norm(normal)
  elbow=shoulder+v*along+normal*math.sqrt(max(0,l1*l1-along*along))
  align('upperarm_'+side,'lowerarm_'+side,elbow)
  align('lowerarm_'+side,'hand_'+side,target)
 return {i:q.copy() for i,q in rotations.items()}
def pose_animation(name,pose):
 animation={'name':name,'channels':[],'samplers':[]}
 for i in doc['skins'][0]['joints']:
  q=pose[i]
  animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':i,'path':'rotation'}})
  animation['samplers'].append({'input':append([[0],[1],[2]],'SCALAR'),'output':append([q,q,q],'VEC4')})
 i=by_name['pelvis'];t=translations[i]
 animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':i,'path':'translation'}})
 animation['samplers'].append({'input':append([[0],[1],[2]],'SCALAR'),'output':append([t,t,t],'VEC3')})
 return animation
relaxed=solve_arms([('l',[.18,.985,.015],[.31,1.16,.12]),('r',[-.18,.985,.015],[-.31,1.16,.12])])
folded=solve_arms([('l',[-.13,1.36,.18],[.47,1.15,.12]),('r',[.11,1.40,.23],[-.47,1.19,.12])])
for i,q in folded.items():
 name=doc['nodes'][i].get('name','')
 if name.startswith(('index_','middle_','pinky_','ring_')) and not name.endswith('Leaf'):
  curl=.45 if '_01_' in name else (.75 if '_02_' in name else .35)
  folded[i]=(Rotation.from_quat(q)*Rotation.from_rotvec([curl,0,0])).as_quat()
doc['animations']=[a for a in doc['animations'] if a['name'] not in ['idle','fold_arms']]
doc['animations'] += [pose_animation('idle',relaxed),pose_animation('fold_arms',folded)]
binary.extend(b'\0'*(-len(binary)%4));doc['buffers']=[{'byteLength':len(binary)}]
encoded=json.dumps(doc,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4)
(ROOT/'player/models/muhammad.glb').write_bytes(struct.pack('<III',0x46546c67,2,28+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)
print('Muhammad model built: tailored clothes, slimmer torso, projected likeness and fold-arms action')
