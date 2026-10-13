"""Prepare the CC0 Quaternius humanoid and selected animations without Blender.

Usage: python tools/prepare_human.py /path/to/character.glb /path/to/UAL1_Standard.glb
Requires numpy. Source URLs, licenses and checksums are in player/models/SOURCES.md.
"""
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import numpy as np


def read_glb(path):
    data = Path(path).read_bytes()
    size = struct.unpack_from('<I', data, 12)[0]
    document = json.loads(data[20:20 + size])
    return document, bytearray(data[28 + size:]), hashlib.sha256(data).hexdigest()


def values(document, binary, index):
    accessor = document['accessors'][index]
    view = document['bufferViews'][accessor['bufferView']]
    dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5121: 'u1'}[accessor['componentType']]
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
    offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', np.dtype(dtype).itemsize * width)
    return np.ndarray((accessor['count'], width), dtype=dtype, buffer=binary,
                      offset=offset, strides=(stride, np.dtype(dtype).itemsize)).copy()


def quat_mul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([aw*bx + ax*bw + ay*bz - az*by,
                     aw*by - ax*bz + ay*bw + az*bx,
                     aw*bz + ax*by - ay*bx + az*bw,
                     aw*bw - ax*bx - ay*by - az*bz])


def build(model_path, animation_path, output):
    doc, binary, model_hash = read_glb(model_path)
    source, source_binary, animation_hash = read_glb(animation_path)

    def append(array, kind, component=5126, bounds=False):
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2', 5121: 'u1'}[component]
        array = np.asarray(array, dtype=dtype)
        binary.extend(b'\0' * (-len(binary) % 4))
        offset = len(binary)
        binary.extend(array.tobytes())
        view = len(doc['bufferViews'])
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': array.nbytes})
        accessor = {'bufferView': view, 'componentType': component,
                    'count': len(array), 'type': kind}
        if bounds:
            accessor['min'] = array.min(axis=0).tolist()
            accessor['max'] = array.max(axis=0).tolist()
        index = len(doc['accessors'])
        doc['accessors'].append(accessor)
        return index

    # Color fitted garments on the existing smooth, skinned human topology.
    # Hands and fingers retain skin color; shoes, eyes and hair have separate colors.
    female = "female" in str(model_path).lower()
    skin = [0.34, 0.16, 0.075, 1]
    shirt = [0.025, 0.19, 0.48, 1]
    trousers = [0.025, 0.035, 0.055, 1]
    shoes = [0.055, 0.065, 0.075, 1]
    doc['materials'] = [{'name': 'Human clothing and skin', 'doubleSided': False,
        'pbrMetallicRoughness': {'baseColorFactor': [1, 1, 1, 1],
                               'metallicFactor': 0, 'roughnessFactor': 0.88}}]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            positions = values(doc, binary, primitive['attributes']['POSITION'])
            colors = np.tile(skin, (len(positions), 1))
            if mesh['name'] in ['Face', 'Eyebrows']:
                colors[:] = [0.018, 0.012, 0.009, 1]
            elif mesh['name'] in ['Face.001', 'Eyes']:
                colors[:] = [0.82, 0.84, 0.80, 1]
            else:
                y = positions[:, 1]
                joints = values(doc, binary, primitive['attributes']['JOINTS_0'])
                weights = values(doc, binary, primitive['attributes']['WEIGHTS_0'])
                primary = joints[np.arange(len(joints)), weights.argmax(axis=1)]
                names = [doc['nodes'][doc['skins'][0]['joints'][i]]['name'] for i in primary]
                hands = np.array([n.startswith(('hand_', 'index_', 'middle_', 'pinky_', 'ring_', 'thumb_')) for n in names])
                arms = np.array([n.startswith(('upperarm_', 'lowerarm_', 'clavicle_')) for n in names])
                colors[((y >= 0.96) & (y < 1.60) | arms) & ~hands] = shirt
                colors[(y >= 0.14) & (y < 0.96)] = trousers
                colors[y < 0.14] = shoes
            primitive['material'] = 0
            primitive['attributes']['COLOR_0'] = append(colors, 'VEC4')

    # Short rounded hair, weighted to the actual head bone.
    hair_positions, hair_normals, hair_indices = [], [], []
    rows, columns = 8, 24
    for row in range(rows + 1):
        phi = (row / rows) * math.pi * 0.54
        for column in range(columns + 1):
            theta = column / columns * math.tau
            x = math.sin(phi) * math.cos(theta)
            y = math.cos(phi)
            z = math.sin(phi) * math.sin(theta)
            hair_positions.append([x * 0.091, (1.714 if female else 1.757) + y * 0.063, -0.006 + z * 0.079])
            normal = np.array([x / 0.091, y / 0.063, z / 0.079])
            hair_normals.append((normal / np.linalg.norm(normal)).tolist())
    for row in range(rows):
        for column in range(columns):
            a = row * (columns + 1) + column
            b = a + columns + 1
            hair_indices.extend([a, a + 1, b, a + 1, b + 1, b])
    head_node = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == 'Head')
    head_joint = doc['skins'][0]['joints'].index(head_node)
    count = len(hair_positions)
    hair = {'name': 'Short hair', 'primitives': [{'attributes': {
        'POSITION': append(hair_positions, 'VEC3', bounds=True),
        'NORMAL': append(hair_normals, 'VEC3'),
        'COLOR_0': append([[0.018, 0.012, 0.009, 1]] * count, 'VEC4'),
        'JOINTS_0': append([[head_joint, 0, 0, 0]] * count, 'VEC4', 5123),
        'WEIGHTS_0': append([[1, 0, 0, 0]] * count, 'VEC4')},
        'indices': append(np.array(hair_indices).reshape(-1, 1), 'SCALAR', 5123),
        'material': 0}]}
    mesh_index = len(doc['meshes'])
    doc['meshes'].append(hair)
    node_index = len(doc['nodes'])
    doc['nodes'].append({'name': 'Hair', 'mesh': mesh_index, 'skin': 0})
    doc['nodes'][doc['scenes'][0]['nodes'][0]]['children'].append(node_index)

    def add_shoe(name, center, radii, joint_name, color):
        positions, normals, indices = [], [], []
        rows, columns = 10, 24
        for row in range(rows + 1):
            phi = row / rows * math.pi
            for column in range(columns + 1):
                theta = column / columns * math.tau
                unit = np.array([math.sin(phi) * math.cos(theta), math.cos(phi),
                                 math.sin(phi) * math.sin(theta)])
                positions.append((unit * radii + center).tolist())
                normal = unit / radii
                normals.append((normal / np.linalg.norm(normal)).tolist())
        for row in range(rows):
            for column in range(columns):
                a = row * (columns + 1) + column
                b = a + columns + 1
                indices.extend([a, a+1, b, a+1, b+1, b])
        node = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == joint_name)
        joint = doc['skins'][0]['joints'].index(node)
        count = len(positions)
        mesh = {'name': name, 'primitives': [{'attributes': {
            'POSITION': append(positions, 'VEC3', bounds=True),
            'NORMAL': append(normals, 'VEC3'),
            'COLOR_0': append([color] * count, 'VEC4'),
            'JOINTS_0': append([[joint, 0, 0, 0]] * count, 'VEC4', 5123),
            'WEIGHTS_0': append([[1, 0, 0, 0]] * count, 'VEC4')},
            'indices': append(np.array(indices).reshape(-1, 1), 'SCALAR', 5123), 'material': 0}]}
        mesh_index = len(doc['meshes'])
        doc['meshes'].append(mesh)
        node_index = len(doc['nodes'])
        doc['nodes'].append({'name': name, 'mesh': mesh_index, 'skin': 0})
        doc['nodes'][doc['scenes'][0]['nodes'][0]]['children'].append(node_index)

    # Eye whites come from the authored face topology; add small skinned pupils.
    for x in [-0.029, 0.029]:
        add_shoe('Pupil', np.array([x, 1.656 if female else 1.705, 0.077 if female else 0.082]),
                 np.array([0.007, 0.009, 0.005]), 'Head', [0.025, 0.035, 0.028, 1])
    if female:
        add_shoe('Tied hair', np.array([0, 1.66, -0.098]),
                 np.array([0.047, 0.103, 0.045]), 'Head', [0.018, 0.012, 0.009, 1])

    for side, x in [('l', 0.131), ('r', -0.131)]:
        add_shoe('Sneaker_' + side, np.array([x, 0.048, -0.009]),
                 np.array([0.069, 0.064, 0.16]), 'foot_' + side, [0.027, 0.035, 0.05, 1])
        add_shoe('Sole_' + side, np.array([x, 0.012, -0.009]),
                 np.array([0.071, 0.018, 0.163]), 'foot_' + side, [0.65, 0.7, 0.75, 1])

    target_nodes = {n.get('name'): i for i, n in enumerate(doc['nodes'])}
    clips = {'Idle_Loop': 'idle', 'Walk_Loop': 'walk', 'Sprint_Loop': 'run',
             'Jump_Start': 'jump_start', 'Jump_Loop': 'jump_air', 'Jump_Land': 'land',
             'Sitting_Enter': 'enter', 'Sitting_Exit': 'exit', 'Driving_Loop': 'seated', 'Sitting_Idle_Loop': 'sit',
             'Idle_Talking_Loop': 'talk', 'Punch_Jab': 'punch',
             'Punch_Cross': 'heavy_punch', 'Hit_Chest': 'hit', 'Death01': 'death'}
    doc['animations'] = []
    for animation in source['animations']:
        if animation['name'] not in clips:
            continue
        new = {'name': clips[animation['name']], 'channels': [], 'samplers': []}
        for channel in animation['channels']:
            original_node = source['nodes'][channel['target']['node']]
            name = original_node.get('name')
            if name not in target_nodes:
                continue
            target_node = doc['nodes'][target_nodes[name]]
            path = channel['target']['path']
            # Keep the model's bone lengths; use only pelvis bob and joint rotations.
            if path == 'scale' or (path == 'translation' and name != 'pelvis'):
                continue
            sampler = animation['samplers'][channel['sampler']]
            times = values(source, source_binary, sampler['input'])
            poses = values(source, source_binary, sampler['output'])
            if path == 'rotation':
                source_rest = np.array(original_node.get('rotation', [0, 0, 0, 1]))
                target_rest = np.array(target_node.get('rotation', [0, 0, 0, 1]))
                correction = quat_mul(target_rest, source_rest * [-1, -1, -1, 1])
                poses = np.array([quat_mul(correction, pose) for pose in poses])
                poses /= np.linalg.norm(poses, axis=1, keepdims=True)
            elif path == 'translation':
                delta = poses - np.array(original_node.get('translation', [0, 0, 0]))
                # Root is rotated -90 degrees: local Z is world height.
                delta[:, :2] = 0
                if animation['name'].startswith('Jump'):
                    delta[:, 2] = np.clip(delta[:, 2], -0.07, 0.07)
                poses = np.array(target_node.get('translation', [0, 0, 0])) + delta
            new['channels'].append({'sampler': len(new['samplers']),
                                    'target': {'node': target_nodes[name], 'path': path}})
            new['samplers'].append({'input': append(times, 'SCALAR', bounds=True),
                                    'output': append(poses, 'VEC4' if path == 'rotation' else 'VEC3'),
                                    'interpolation': sampler.get('interpolation', 'LINEAR')})
        doc['animations'].append(new)
    binary.extend(b'\0' * (-len(binary) % 4))
    doc['buffers'] = [{'byteLength': len(binary)}]
    doc['asset']['extras'] = {'model': 'Quaternius Universal Base Characters (CC0)',
        'animations': 'Quaternius Universal Animation Library (CC0)',
        'source_model_sha256': model_hash, 'source_animations_sha256': animation_hash}
    json_chunk = json.dumps(doc, separators=(',', ':')).encode()
    json_chunk += b' ' * (-len(json_chunk) % 4)
    output = Path(output)
    output.write_bytes(struct.pack('<III', 0x46546C67, 2, 28 + len(json_chunk) + len(binary)) +
        struct.pack('<II', len(json_chunk), 0x4E4F534A) + json_chunk +
        struct.pack('<II', len(binary), 0x004E4942) + binary)
    print(output, output.stat().st_size, 'bytes', 'clips:', list(clips.values()))
    print('Source hashes:', model_hash, animation_hash)


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2], Path(__file__).resolve().parents[1] / 'player/models/human.glb')
