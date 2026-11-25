"""Straighten the hover bike's handlebars (world/vehicles/hoverbike/): each side's
grip turns rigidly to a mirror-symmetric pose and the bar between the stem and the grip
bends smoothly to meet it. The model is one solid mesh, so the parts are picked by position.
usage: straighten_handlebars.py in.glb out.glb [debug=0] [sweep_deg=0] [droop_deg=8]
debug=1 lifts the picked vertices instead (to see what moves)."""
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
DEBUG = len(sys.argv) > 3 and sys.argv[3] == "1"
SWEEP = np.radians(float(sys.argv[4])) if len(sys.argv) > 4 else 0.0
DROOP = np.radians(float(sys.argv[5])) if len(sys.argv) > 5 else np.radians(8)
d, j, n, B, pr, acc = load(src)
B = bytearray(B)
pa, na = pr["attributes"]["POSITION"], pr["attributes"]["NORMAL"]
pos = acc(pa, np.float32, 3).astype(np.float64)
nrm = acc(na, np.float32, 3).astype(np.float64)
idx = acc(pr["indices"], np.uint32, 1)
used = np.zeros(len(pos), bool); used[idx] = True

def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def rot_between(u, v):
    u = u / np.linalg.norm(u); v = v / np.linalg.norm(v)
    ax = np.cross(u, v); s = np.linalg.norm(ax); c = np.dot(u, v)
    if s < 1e-9: return np.zeros(3), 0.0
    return ax / s, np.arctan2(s, c)

def rodrigues(axis, ang):
    K = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
    return np.eye(3) + np.sin(ang) * K + (1 - np.cos(ang)) * K @ K

x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
az = np.abs(z)
# The bar assembly: above the body, beside the stem, behind the fairing's front.
w_box = smooth(-0.36, -0.32, x) * (1 - smooth(0.04, 0.08, x)) * smooth(0.11, 0.17, y)
fairing = (x < -0.13) & (az < 0.27) & (y < 0.232)
w_lat = smooth(0.10, 0.30, az)
w = w_box * w_lat * ~fairing

# Measured grips -> symmetric target.
cents, axes = {}, {}
for s in (1, -1):
    m = used & (z * s > 0.34) & (y > 0.15) & (x > -0.32) & (x < 0.08)
    p = pos[m]; c = p.mean(0)
    _, _, vt = np.linalg.svd(p - c); a = vt[0] * np.sign(vt[0][2] * s)   # outward
    cents[s], axes[s] = c, a
cx = (cents[1][0] + cents[-1][0]) / 2; cy = (cents[1][1] + cents[-1][1]) / 2
cz = (abs(cents[1][2]) + abs(cents[-1][2])) / 2
new = pos.copy(); nn = nrm.copy()
for s in (1, -1):
    tgt_c = np.array([cx, cy, cz * s])
    tgt_a = np.array([np.sin(SWEEP), -np.sin(DROOP), s * np.cos(SWEEP) * np.cos(DROOP)])
    axis, ang = rot_between(axes[s], tgt_a)
    print("side %+d: turn %.1f deg, move %s" % (s, np.degrees(ang), np.round(tgt_c - cents[s], 3)))
    side = (z * s > 0) & (w > 0)
    ws = w[side]
    for k in np.unique(np.round(ws, 3)):
        sel = np.where(side)[0][np.round(ws, 3) == k]
        R = rodrigues(axis, ang * k)
        new[sel] = (pos[sel] - cents[s]) @ R.T + cents[s] + (tgt_c - cents[s]) * k
        nn[sel] = nrm[sel] @ R.T
if DEBUG:
    new = pos.copy(); new[:, 1] += w * 0.5
pa_ = j["accessors"][pa]; bv = j["bufferViews"][pa_["bufferView"]]
off = bv.get("byteOffset", 0) + pa_.get("byteOffset", 0)
B[off:off + new.size * 4] = new.astype(np.float32).tobytes()
pa_["min"] = new.min(0).tolist(); pa_["max"] = new.max(0).tolist()
na_ = j["accessors"][na]; bv = j["bufferViews"][na_["bufferView"]]
off = bv.get("byteOffset", 0) + na_.get("byteOffset", 0)
B[off:off + nn.size * 4] = nn.astype(np.float32).tobytes()
js = json.dumps(j, separators=(",", ":")).encode(); js += b" " * ((4 - len(js) % 4) % 4)
body = struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(B), 0x004E4942) + bytes(B)
open(out, "wb").write(struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body)
print("moved verts", int((w > 0).sum()))
