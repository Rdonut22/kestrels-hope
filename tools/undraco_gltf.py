"""Draco-compressed .gltf + .bin -> plain .glb (textures kept as they are).
usage: undraco.py in.gltf out.glb"""
import json, struct, sys, os
import numpy as np, DracoPy
src, out = sys.argv[1], sys.argv[2]
j = json.load(open(src))
B = open(os.path.join(os.path.dirname(src), j["buffers"][0]["uri"]), "rb").read()
def view(i):
    v = j["bufferViews"][i]; o = v.get("byteOffset", 0); return B[o:o + v["byteLength"]]
pr = j["meshes"][0]["primitives"][0]
ext = pr["extensions"]["KHR_draco_mesh_compression"]
m = DracoPy.decode(view(ext["bufferView"]))
pos = np.asarray(m.points, np.float32).reshape(-1, 3)
nrm = np.asarray(m.normals, np.float32).reshape(-1, 3)
uv = np.asarray(m.tex_coord, np.float32).reshape(-1, 2)
idx = np.asarray(m.faces, np.uint32).ravel()
print(os.path.basename(src), "verts", len(pos), len(nrm), len(uv), "tris", idx.size // 3)
chunks, views = [], []
def add(data, target=None):
    off = sum(len(c) for c in chunks)
    chunks.append(data + b"\0" * ((4 - len(data) % 4) % 4))
    v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target: v["target"] = target
    views.append(v); return len(views) - 1
acc = [
    {"bufferView": add(idx.tobytes(), 34963), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"},
    {"bufferView": add(pos.tobytes(), 34962), "componentType": 5126, "count": len(pos), "type": "VEC3", "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
    {"bufferView": add(nrm.tobytes(), 34962), "componentType": 5126, "count": len(nrm), "type": "VEC3"},
    {"bufferView": add(uv.tobytes(), 34962), "componentType": 5126, "count": len(uv), "type": "VEC2"},
]
imgs = []
for im in j["images"]:
    imgs.append({"name": im["name"], "mimeType": im["mimeType"], "bufferView": add(view(im["bufferView"]))})
pr2 = {"attributes": {"POSITION": 1, "NORMAL": 2, "TEXCOORD_0": 3}, "indices": 0, "material": 0, "mode": 4}
name = os.path.splitext(os.path.basename(out))[0]
g = {"asset": {"version": "2.0"}, "accessors": acc, "bufferViews": views, "buffers": [{"byteLength": sum(len(c) for c in chunks)}],
     "images": imgs, "samplers": j["samplers"], "textures": j["textures"], "materials": j["materials"],
     "meshes": [{"name": name, "primitives": [pr2]}], "nodes": [{"name": name, "mesh": 0}], "scenes": [{"nodes": [0]}], "scene": 0,
     "extensionsUsed": ["EXT_texture_webp"], "extensionsRequired": ["EXT_texture_webp"]}
js = json.dumps(g, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
bin_ = b"".join(chunks)
body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(bin_), 0x004E4942) + bin_
open(out, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)
