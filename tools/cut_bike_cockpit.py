"""Remove the bike's own grips, hand controls and stem display (the separate
part models take their places). usage: cut.py in.glb out.glb [show=keep|cut]"""
import sys, struct, json
import numpy as np

def load(src):
    d = open(src, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n]); bin0 = 20 + n + 8
    binlen = struct.unpack("<I", d[20 + n:24 + n])[0]; B = d[bin0:bin0 + binlen]
    def acc(i, dt, c):
        a = j["accessors"][i]; bv = j["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        r = np.frombuffer(B, dt, a["count"] * c, off)
        return r.reshape(a["count"], c) if c > 1 else r
    pr = j["meshes"][0]["primitives"][0]
    return d, j, n, B, pr, acc
src, out = sys.argv[1], sys.argv[2]
SHOW = sys.argv[3] if len(sys.argv) > 3 else "keep"
d, j, n, B, pr, acc = load(src)
B = bytearray(B)
pos = acc(pr["attributes"]["POSITION"], np.float32, 3)
ia = j["accessors"][pr["indices"]]
idx = acc(pr["indices"], np.uint32, 1).reshape(-1, 3)
x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]; az = np.abs(z)
bar = (y > 0.15) & (x > -0.32) & (x < 0.08)
grips = bar & (az > 0.235)
display = (x > -0.105) & (x < -0.02) & (az < 0.122) & (y > 0.255)
gone = grips | display
tri_gone = gone[idx].all(1)
keep = idx[~tri_gone] if SHOW == "keep" else idx[tri_gone]
print("removed tris", int(tri_gone.sum()), "of", len(idx))
flat = keep.astype(np.uint32).ravel()
bv = j["bufferViews"][ia["bufferView"]]
off = bv.get("byteOffset", 0) + ia.get("byteOffset", 0)
B[off:off + flat.size * 4] = flat.tobytes()
ia["count"] = int(flat.size)
js = json.dumps(j, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(B), 0x004E4942) + bytes(B)
open(out, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)
