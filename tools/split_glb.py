"""Split a single-mesh GLB into named pieces (for parts that move on their
own: a lever, a switch, a twist grip). The pieces share the material and
textures and keep the original coordinates, so they line up as before.

usage: split_glb.py in.glb out.glb "Name:condition" ["Name:condition" ...]

Each condition is a numpy expression on the vertex coordinates x, y, z
(e.g. "x<0.12 & y>0.15"). A triangle goes to the first piece whose condition
all three of its corners meet; the rest form the piece "Body". Each piece is
a separate node and mesh named after it."""
import json, struct, sys, os
import numpy as np

src, out, specs = sys.argv[1], sys.argv[2], sys.argv[3:]
d = open(src, "rb").read()
n = struct.unpack("<I", d[12:16])[0]
j = json.loads(d[20:20 + n])
B = d[28 + n:28 + n + struct.unpack("<I", d[20 + n:24 + n])[0]]


def acc(i, dt, comps):
    a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]
    off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    r = np.frombuffer(B, dt, a["count"] * comps, off)
    return r.reshape(a["count"], comps) if comps > 1 else r


pr = j["meshes"][0]["primitives"][0]
attrs = {k: acc(v, np.float32, {"POSITION": 3, "NORMAL": 3, "TEXCOORD_0": 2}[k]) for k, v in pr["attributes"].items()}
tris = acc(pr["indices"], np.uint32, 1).reshape(-1, 3)
pos = attrs["POSITION"]
env = {"x": pos[:, 0], "y": pos[:, 1], "z": pos[:, 2], "np": np}
left = np.ones(len(tris), bool)
pieces = []
for s in specs:
    name, cond = s.split(":", 1)
    inside = np.asarray(eval(cond, {"__builtins__": {}}, env), bool)
    take = left & inside[tris].all(1)
    pieces.append((name, tris[take]))
    left &= ~take
pieces.append(("Body", tris[left]))

chunks, views, accs, meshes, nodes = [], [], [], [], []


def add(data, target=None):
    off = sum(len(c) for c in chunks)
    chunks.append(data + b"\0" * ((4 - len(data) % 4) % 4))
    v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target:
        v["target"] = target
    views.append(v)
    return len(views) - 1


for name, t in pieces:
    used, remap = np.unique(t, return_inverse=True)
    idx = remap.astype(np.uint32).ravel()
    prim = {"indices": len(accs), "mode": 4, "material": pr.get("material", 0), "attributes": {}}
    accs.append({"bufferView": add(idx.tobytes(), 34963), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"})
    for k, a in attrs.items():
        v = np.ascontiguousarray(a[used])
        e = {"bufferView": add(v.tobytes(), 34962), "componentType": 5126, "count": len(v), "type": "VEC3" if v.shape[1] == 3 else "VEC2"}
        if k == "POSITION":
            e["min"] = v.min(0).tolist(); e["max"] = v.max(0).tolist()
        prim["attributes"][k] = len(accs)
        accs.append(e)
    meshes.append({"name": name, "primitives": [prim]})
    nodes.append({"name": name, "mesh": len(meshes) - 1})
    print(name, "tris", len(t))

images = []
for im in j.get("images", []):
    bv = j["bufferViews"][im["bufferView"]]
    o = bv.get("byteOffset", 0)
    images.append({k: v for k, v in im.items() if k != "bufferView"} | {"bufferView": add(B[o:o + bv["byteLength"]])})
g = {"asset": {"version": "2.0", "generator": "split_glb.py"}, "scene": 0,
     "scenes": [{"nodes": list(range(len(nodes)))}], "nodes": nodes, "meshes": meshes,
     "accessors": accs, "bufferViews": views, "buffers": [{"byteLength": sum(len(c) for c in chunks)}]}
for k in ("materials", "textures", "samplers", "extensionsUsed", "extensionsRequired"):
    if k in j:
        g[k] = j[k]
if images:
    g["images"] = images
js = json.dumps(g, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
binb = b"".join(chunks)
body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(binb), 0x004E4942) + binb
open(out, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)
