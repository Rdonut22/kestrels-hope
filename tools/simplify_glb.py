"""Simplify a single-mesh GLB with meshoptimizer, keeping its UVs, material
and textures (and, with normals=1, its normals).
usage: simplify_glb.py in.glb out.glb target_tris [error] [textures=1] [uv_weight=1]
       [lock_borders=1] [normals=0] [sloppy=0]
sloppy=1 ignores the mesh's topology (pieces merge freely): only for distant
versions and shadows, where that can't be seen."""
import json, struct, sys
import numpy as np
import meshoptimizer as mo

src, out, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
err = float(sys.argv[4]) if len(sys.argv) > 4 else 0.02
keep_tex = (sys.argv[5] != "0") if len(sys.argv) > 5 else True
UV_W = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
LOCK = (sys.argv[7] != "0") if len(sys.argv) > 7 else True
NORMALS = (sys.argv[8] != "0") if len(sys.argv) > 8 else False
SLOPPY = (sys.argv[9] != "0") if len(sys.argv) > 9 else False
import os
NAME = os.path.splitext(os.path.basename(out))[0]
d = open(src, "rb").read()
n = struct.unpack("<I", d[12:16])[0]
j = json.loads(d[20:20 + n])
bin0 = 20 + n + 8
binlen = struct.unpack("<I", d[20 + n:24 + n])[0]
B = d[bin0:bin0 + binlen]

def acc(i, dt, comps):
    a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(B, dt, a["count"] * comps, off).reshape(a["count"], comps) if comps > 1 else np.frombuffer(B, dt, a["count"], off)

pr = j["meshes"][0]["primitives"][0]
pos = acc(pr["attributes"]["POSITION"], np.float32, 3).copy()
uv = acc(pr["attributes"]["TEXCOORD_0"], np.float32, 2).copy()
nrm = acc(pr["attributes"]["NORMAL"], np.float32, 3).copy() if NORMALS else None
idx = acc(pr["indices"], np.uint32, 1).copy()
dst = np.zeros(idx.size, np.uint32)
# UVs count towards the error (so texture mapping isn't smeared), and the
# UV islands' borders stay put (the islands aren't welded: unlocked borders
# would open cracks).
w = np.array([UV_W, UV_W], np.float32)
opts = mo.SIMPLIFY_LOCK_BORDER if LOCK else 0
# (The package's Python binding declares this call's arguments wrongly:
# call the C function directly.)
import ctypes as C
from meshoptimizer import simplifier as _ms
fn = _ms.lib.meshopt_simplifyWithAttributes
P = C.POINTER
fn.argtypes = [P(C.c_uint), P(C.c_uint), C.c_size_t, P(C.c_float), C.c_size_t, C.c_size_t, P(C.c_float), C.c_size_t,
	P(C.c_float), C.c_size_t, P(C.c_ubyte), C.c_size_t, C.c_float, C.c_uint, P(C.c_float)]
fn.restype = C.c_size_t
# With normals, they count towards the error too (hard edges stay hard).
attrs = np.hstack([uv, nrm * 0.5]) if NORMALS else uv
if NORMALS:
    w = np.array([UV_W, UV_W, 1.0, 1.0, 1.0], np.float32)
uvc = np.ascontiguousarray(attrs, np.float32)
na = uvc.shape[1]
cnt = fn(dst.ctypes.data_as(P(C.c_uint)), idx.ctypes.data_as(P(C.c_uint)), idx.size, pos.ctypes.data_as(P(C.c_float)), len(pos), 12,
	uvc.ctypes.data_as(P(C.c_float)), na * 4, w.ctypes.data_as(P(C.c_float)), na, P(C.c_ubyte)(), target * 3, err, opts, P(C.c_float)())
if SLOPPY:
    sl = _ms.lib.meshopt_simplifySloppy
    sl.argtypes = [P(C.c_uint), P(C.c_uint), C.c_size_t, P(C.c_float), C.c_size_t, C.c_size_t, C.c_size_t, C.c_float, P(C.c_float)]
    sl.restype = C.c_size_t
    cnt = sl(dst.ctypes.data_as(P(C.c_uint)), idx.ctypes.data_as(P(C.c_uint)), idx.size, pos.ctypes.data_as(P(C.c_float)), len(pos), 12,
        target * 3, err, P(C.c_float)())
dst = dst[:cnt]
used, remap = np.unique(dst, return_inverse=True)
pos2, uv2, idx2 = pos[used], uv[used], remap.astype(np.uint32)
print("tris", idx.size // 3, "->", idx2.size // 3, "verts", len(pos), "->", len(pos2))

# Rebuild the binary: indices, positions, uvs, then the images.
chunks, views = [], []
def add(data, target=None):
    off = sum(len(c) for c in chunks)
    chunks.append(data + b"\0" * ((4 - len(data) % 4) % 4))
    v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target: v["target"] = target
    views.append(v)
    return len(views) - 1
vi = add(idx2.tobytes(), 34963); vp = add(pos2.tobytes(), 34962); vu = add(uv2.tobytes(), 34962)
if NORMALS:
    n2 = nrm[used]
    n2 = (n2 / np.maximum(np.linalg.norm(n2, axis=1, keepdims=True), 1e-8)).astype(np.float32)
    vn = add(n2.tobytes(), 34962)
accs = [
    {"bufferView": vi, "componentType": 5125, "count": int(idx2.size), "type": "SCALAR"},
    {"bufferView": vp, "componentType": 5126, "count": len(pos2), "type": "VEC3", "min": pos2.min(0).tolist(), "max": pos2.max(0).tolist()},
    {"bufferView": vu, "componentType": 5126, "count": len(uv2), "type": "VEC2"},
]
attributes = {"POSITION": 1, "TEXCOORD_0": 2}
if NORMALS:
    accs.append({"bufferView": vn, "componentType": 5126, "count": len(n2), "type": "VEC3"})
    attributes["NORMAL"] = 3
images = []
if keep_tex:
    for im in j["images"]:
        bv = j["bufferViews"][im["bufferView"]]
        images.append({"bufferView": add(B[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]), "mimeType": im["mimeType"]})
g = {"asset": {"version": "2.0", "generator": "simplify_glb.py"}, "scene": 0, "scenes": [{"nodes": [0]}],
     "nodes": [{"name": NAME, "mesh": 0}],
     "meshes": [{"primitives": [{"attributes": attributes, "indices": 0, "mode": 4, "material": 0}]}],
     "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": sum(len(c) for c in chunks)}]}
if keep_tex:
    g["materials"] = j["materials"]; g["textures"] = j["textures"]; g["images"] = images
    if "samplers" in j:
        g["samplers"] = j["samplers"]
else:
    g["materials"] = [{"pbrMetallicRoughness": {"baseColorFactor": [0.5, 0.5, 0.5, 1]}}]
js = json.dumps(g).encode(); js += b" " * ((4 - len(js) % 4) % 4)
binb = b"".join(chunks)
with open(out, "wb") as f:
    f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb)))
    f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
    f.write(struct.pack("<II", len(binb), 0x004E4942)); f.write(binb)
