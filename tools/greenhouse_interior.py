#!/usr/bin/env python3
"""Opens up the ruined greenhouse's interior (world/models/greenhouse):

  * cuts a great round hole through the ceiling slab between the ground
    floor and the dome, so the ground floor looks straight up into the
    glass dome, and a stairwell notch through the slab along the inner wall
    where the new staircase climbs to the upper floor;
  * measures what the runtime interior (world/greenhouse.gd) builds on:
    the slab's underside and top round the cut (its stone rim), the inner
    arcade's piers where the cut leaves them (their coping), the inner
    wall along the staircase, the walkway ring, and the spots where the
    sun gets through missing dome glass and the hole (the light shafts);
  * writes them to world/models/greenhouse/interior.json.

Both the visual model and its collision copy are cut. Triangles that cross
the cut are clipped exactly against it (UVs interpolated), so the edge is
clean. Re-running is harmless (the cut region is already empty).

Coordinates: the model's own frame in metres (its mesh units x SCALE),
heights from its lowest point (Y0). world/greenhouse.gd uses the same frame.

  python3 tools/greenhouse_interior.py      (numpy)
"""
import json
import math
import os
import struct
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, "..", "world", "models", "greenhouse")
SCALE = 30.0
YAW = 0.35                 # the model's yaw in the scene (tools/build_scenes.gd)

# The cut: a round hole (radius R_HOLE) from just under the ceiling beams up
# through the slab, and the stairwell notch along the wall.
R_HOLE = 16.5
Y_CUT = 12.9               # the inner arcade's piers are capped here
Y_TOP = 18.8               # above the slab's top (~18.0)
R_WALL_CUT = 22.15         # the notch stops short of the wall's face
# The staircase: cantilevered steps along the inner wall from the ground
# floor (FLOOR_Y) to the upper floor, anticlockwise seen from above.
FLOOR_Y = 2.0
STAIR_TOP_Y = 18.05
STAIR_START = math.radians(205.0)
STAIR_STEPS = 67
STAIR_TREAD = 0.52         # along the arc at its middle
STAIR_WIDTH = 2.5
HEADROOM = 2.4
# The light shafts: the sun (world/day_night.gd's path) at whichever of
# these hours gets most light through the dome's missing glass.
SUN_HOURS = (8.0, 8.5, 9.0, 9.5, 10.0, 14.0, 14.5, 15.0, 15.5, 16.0)


# ------------------------------------------------------------------ glb io
def load_glb(path):
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    B = d[28 + n:]

    def acc(i, dt, comps):
        a = j["accessors"][i]
        bv = j["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        arr = np.frombuffer(B, dt, a["count"] * comps, off)
        return arr.reshape(a["count"], comps) if comps > 1 else arr

    pr = j["meshes"][0]["primitives"][0]
    pos = acc(pr["attributes"]["POSITION"], np.float32, 3).astype(np.float64)
    uv = acc(pr["attributes"]["TEXCOORD_0"], np.float32, 2).astype(np.float64)
    idx = acc(pr["indices"], np.uint32, 1).astype(np.int64)
    return j, B, pos, uv, idx


def save_glb(path, j, B, pos, uv, idx):
    """Write the mesh back with the same materials and images."""
    chunks, views = [], []

    def add(data, target=None):
        off = sum(len(c) for c in chunks)
        chunks.append(data + b"\0" * ((4 - len(data) % 4) % 4))
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        views.append(v)
        return len(views) - 1

    p32, u32, i32 = pos.astype(np.float32), uv.astype(np.float32), idx.astype(np.uint32)
    vi = add(i32.tobytes(), 34963)
    vp = add(p32.tobytes(), 34962)
    vu = add(u32.tobytes(), 34962)
    accs = [
        {"bufferView": vi, "componentType": 5125, "count": int(i32.size), "type": "SCALAR"},
        {"bufferView": vp, "componentType": 5126, "count": len(p32), "type": "VEC3", "min": p32.min(0).tolist(), "max": p32.max(0).tolist()},
        {"bufferView": vu, "componentType": 5126, "count": len(u32), "type": "VEC2"},
    ]
    images = []
    for im in j.get("images", []):
        bv = j["bufferViews"][im["bufferView"]]
        o = bv.get("byteOffset", 0)
        images.append({"bufferView": add(B[o:o + bv["byteLength"]]), "mimeType": im["mimeType"]})
    g = {k: j[k] for k in ("asset", "scene", "scenes", "nodes", "materials") if k in j}
    g["meshes"] = [{"primitives": [{"attributes": {"POSITION": 1, "TEXCOORD_0": 2}, "indices": 0, "mode": 4, "material": 0}]}]
    g["accessors"] = accs
    g["bufferViews"] = views
    g["buffers"] = [{"byteLength": sum(len(c) for c in chunks)}]
    if images:
        g["textures"] = j["textures"]
        g["images"] = images
    js = json.dumps(g).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    binb = b"".join(chunks)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(binb)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(binb), 0x004E4942))
        f.write(binb)


# ------------------------------------------------------------------ geometry
def raycast(P, tri, o, d):
    """Sorted distances along o + t d (t > 0) of every hit with the mesh."""
    v0, v1, v2 = P[tri[:, 0]], P[tri[:, 1]], P[tri[:, 2]]
    e1, e2 = v1 - v0, v2 - v0
    p = np.cross(d, e2)
    det = (e1 * p).sum(1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    s = o - v0
    u = (s * p).sum(1) * inv
    q = np.cross(s, e1)
    v = (q * d).sum(1) * inv
    t = (e2 * q).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-6)
    return np.sort(t[hit])


def stair_end():
    mid = R_WALL_CUT - 0.2 - STAIR_WIDTH * 0.5
    return STAIR_START + STAIR_STEPS * STAIR_TREAD / mid


def stair_height(theta):
    k = (theta - STAIR_START) / (stair_end() - STAIR_START)
    return FLOOR_Y + k * (STAIR_TOP_Y - FLOOR_Y)


def wrap(a):
    return (a + math.pi) % math.tau - math.pi


def regions(notch):
    """The removed regions as lists of half-space tests per triangle: each
    is (kind, args); a point is inside a region when it's inside all."""
    hole = [("r_lt", R_HOLE), ("y_gt", Y_CUT), ("y_lt", Y_TOP)]
    n0, n1 = notch
    wedge = [("ang_gt", n0), ("ang_lt", n1), ("r_lt", R_WALL_CUT), ("r_gt", R_HOLE - 0.5), ("y_gt", Y_CUT - 1.5), ("y_lt", Y_TOP)]
    return [hole, wedge]


def plane_for(kind, arg, centroid):
    """A plane (n, c) with inside where n.p - c > 0, for one triangle (the
    cylinder's tangent plane at the triangle's angle)."""
    ang = math.atan2(centroid[2], centroid[0])
    u = np.array([math.cos(ang), 0.0, math.sin(ang)])
    if kind == "r_lt":
        return -u, -arg
    if kind == "r_gt":
        return u, arg
    if kind == "y_gt":
        return np.array([0.0, 1.0, 0.0]), arg
    if kind == "y_lt":
        return np.array([0.0, -1.0, 0.0]), -arg
    if kind == "ang_gt":  # anticlockwise of angle arg (seen from +Y: x->z)
        return np.array([-math.sin(arg), 0.0, math.cos(arg)]), 0.0
    if kind == "ang_lt":
        return np.array([math.sin(arg), 0.0, -math.cos(arg)]), 0.0
    raise ValueError(kind)


def clip_poly(poly, n, c, keep_inside):
    """Sutherland-Hodgman: poly is a list of (pos, uv)."""
    out = []
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        da = float(np.dot(n, a[0]) - c)
        db = float(np.dot(n, b[0]) - c)
        ina = da > 0 if keep_inside else da <= 0
        inb = db > 0 if keep_inside else db <= 0
        if ina:
            out.append(a)
        if ina != inb:
            t = da / (da - db)
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def subtract(poly, planes):
    """The parts of a convex polygon outside a convex region (the
    intersection of the planes' insides)."""
    pieces = []
    rest = poly
    for n, c in planes:
        outside = clip_poly(rest, n, c, False)
        if len(outside) >= 3:
            pieces.append(outside)
        rest = clip_poly(rest, n, c, True)
        if len(rest) < 3:
            break
    return pieces


def cut(pos, uv, idx, notch):
    """Remove the hole and the notch from the mesh (in SCALE'd metres)."""
    tri = idx.reshape(-1, 3)
    P = pos
    cen = P[tri].mean(1)
    lo = P[tri].min(1)
    hi = P[tri].max(1)
    rmin = np.sqrt((P[tri][:, :, [0, 2]] ** 2).sum(2)).min(1)
    near = (hi[:, 1] > Y_CUT - 1.6) & (lo[:, 1] < Y_TOP) & (rmin < R_WALL_CUT + 0.1)
    keep = [tri[~near]]
    new_pos, new_uv, new_tri = [], [], []
    base = len(P)
    removed = 0
    regs = regions(notch)
    for t in tri[near]:
        polys = [[(P[k], uv[k]) for k in t]]
        c = P[t].mean(0)
        for reg in regs:
            planes = [plane_for(kind, arg, c) for kind, arg in reg]
            nxt = []
            for poly in polys:
                nxt.extend(subtract(poly, planes))
            polys = nxt
        if len(polys) == 1 and len(polys[0]) == 3 and all(np.allclose(polys[0][i][0], P[t[i]]) for i in range(3)):
            keep.append(t[None, :])
            continue
        removed += 1
        for poly in polys:
            ids = []
            for p, q in poly:
                new_pos.append(p)
                new_uv.append(q)
                ids.append(base + len(new_pos) - 1)
            for i in range(1, len(ids) - 1):
                new_tri.append([ids[0], ids[i], ids[i + 1]])
    tri2 = np.concatenate(keep + ([np.array(new_tri)] if new_tri else []))
    pos2 = np.concatenate([P, np.array(new_pos).reshape(-1, 3)]) if new_pos else P
    uv2 = np.concatenate([uv, np.array(new_uv).reshape(-1, 2)]) if new_uv else uv
    # Drop unused vertices.
    used, remap = np.unique(tri2.ravel(), return_inverse=True)
    print("  clipped/removed %d triangles -> %d triangles" % (removed, len(tri2)))
    return pos2[used], uv2[used], remap.astype(np.int64)


def dome_gaps(P, tri):
    """Holes in the dome's glass: directions from the dome's centre that
    reach the sky, grouped. Each: the gap's centre on the dome, its outward
    direction and its rough size (m)."""
    c = np.array([0.0, 20.0, 0.0])
    free = {}
    for ei, el in enumerate(range(18, 84, 3)):
        for ai, az in enumerate(range(0, 360, 4)):
            e, a = math.radians(el), math.radians(az)
            d = np.array([math.cos(e) * math.cos(a), math.sin(e), math.cos(e) * math.sin(a)])
            h = raycast(P, tri, c, d)
            free[(ei, ai)] = (len(h) == 0, d)
    # The dome's radius along a direction: from the blocked rays round it.
    def radius(ei, ai):
        rs = []
        for de in (-1, 0, 1):
            for da in (-1, 0, 1):
                k = (ei + de, (ai + da) % 90)
                if k in free and not free[k][0]:
                    rs.append(float(raycast(P, tri, c, free[k][1])[-1]))
        return float(np.median(rs)) if rs else 26.0
    seen, gaps = set(), []
    for k, (open_, _) in free.items():
        if not open_ or k in seen:
            continue
        stack, group = [k], []
        seen.add(k)
        while stack:
            ei, ai = stack.pop()
            group.append((ei, ai))
            for de, da in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (ei + de, (ai + da) % 90)
                if n in free and free[n][0] and n not in seen:
                    seen.add(n)
                    stack.append(n)
        dirs = np.array([free[g][1] for g in group])
        d = dirs.mean(0)
        d /= np.linalg.norm(d)
        mid = group[len(group) // 2]
        r = radius(*mid)
        size = math.sqrt(len(group)) * math.radians(3.5) * r
        p = c + d * (r - 0.4)
        gaps.append({"p": [round(float(x), 3) for x in p], "n": [round(float(x), 4) for x in d],
                     "size": round(min(size, 6.0), 2), "cells": len(group)})
    gaps.sort(key=lambda g: -g["cells"])
    return gaps


def sun_dir(hour):
    """Towards the sun at an hour (world/day_night.gd), in the model's frame."""
    a = (hour - 6.0) / 12.0 * math.pi
    w = np.array([math.cos(a), math.sin(a) * 0.9, 0.3])
    w /= np.linalg.norm(w)
    # The model is turned YAW about +Y in the scene: undo that.
    c, s = math.cos(YAW), math.sin(YAW)
    return np.array([c * w[0] - s * w[2], w[1], s * w[0] + c * w[2]])


# ------------------------------------------------------------------ main
def main():
    vis_path = os.path.join(DIR, "greenhouse.glb")
    col_path = os.path.join(DIR, "greenhouse_collision.glb")
    j, B, pos, uv, idx = load_glb(vis_path)
    P0 = pos * SCALE
    Y0 = float(P0[:, 1].min())
    P0[:, 1] -= Y0
    tri0 = idx.reshape(-1, 3)
    up = np.array([0.0, 1.0, 0.0])

    # The notch: from where the stair runs out of headroom under the slab
    # to its top step.
    end = stair_end()
    under_min = 99.0
    for k in range(48):
        a = STAIR_START + (end - STAIR_START) * k / 47
        for r in (R_WALL_CUT - 0.4, R_WALL_CUT - STAIR_WIDTH):
            h = raycast(P0, tri0, np.array([r * math.cos(a), FLOOR_Y + 0.5, r * math.sin(a)]), up)
            h = h[h + FLOOR_Y + 0.5 > 8.0]
            if len(h):
                under_min = min(under_min, float(h[0]) + FLOOR_Y + 0.5)
    k = (under_min - HEADROOM - FLOOR_Y) / (STAIR_TOP_Y - FLOOR_Y)
    notch = (STAIR_START + (end - STAIR_START) * k - math.radians(3.0), end + math.radians(1.5))
    print("slab underside over the stair %.2f; notch %.1f..%.1f deg" % (under_min, math.degrees(notch[0]), math.degrees(notch[1])))

    # Measurements on the uncut model.
    rim = []
    for k in range(360):
        a = math.tau * k / 360
        o = np.array([(R_HOLE + 0.05) * math.cos(a), Y_CUT - 0.05, (R_HOLE + 0.05) * math.sin(a)])
        h = raycast(P0, tri0, o, up) + Y_CUT - 0.05
        h = h[h < Y_TOP]
        rim.append([round(float(h[0]), 3), round(float(h[-1]), 3)] if len(h) else None)
    notch_edges = []
    for a in notch:
        row = []
        for r in np.linspace(R_HOLE, R_WALL_CUT, 14):
            o = np.array([r * math.cos(a), Y_CUT - 1.55, r * math.sin(a)])
            h = raycast(P0, tri0, o, up) + Y_CUT - 1.55
            h = h[h < Y_TOP]
            row.append([round(float(r), 3)] + ([round(float(h[0]), 3), round(float(h[-1]), 3)] if len(h) else [None, None]))
        notch_edges.append(row)
    coping = []
    for k in range(240):
        a = math.tau * k / 240
        d = np.array([math.cos(a), 0.0, math.sin(a)])
        h = raycast(P0, tri0, np.array([0.0, Y_CUT - 0.08, 0.0]), d)
        h = h[h < 10.0]
        coping.append([round(float(h[0]), 3), round(float(h[1]), 3)] if len(h) >= 2 else None)
    walkway = []
    for k in range(180):
        a = math.tau * k / 180
        d = np.array([math.cos(a), 0.0, math.sin(a)])
        h = raycast(P0, tri0, np.array([0.0, 18.6, 0.0]), d)
        h = h[h > R_HOLE]
        wall = float(h[0]) if len(h) else 23.0
        tops = []
        for r in np.linspace(R_HOLE, wall - 0.05, 5):
            o = np.array([r * math.cos(a), 16.0, r * math.sin(a)])
            hh = raycast(P0, tri0, o, up) + 16.0
            hh = hh[hh < 19.0]
            tops.append(round(float(hh[-1]), 3) if len(hh) else None)
        walkway.append([round(min(wall, 23.5), 3), tops])
    walls = []
    for k in range(60):
        a = STAIR_START + (end - STAIR_START) * k / 59
        d = np.array([math.cos(a), 0.0, math.sin(a)])
        for y in np.arange(FLOOR_Y + 0.3, 12.0, 1.5):
            h = raycast(P0, tri0, np.array([0.0, y, 0.0]), d)
            h = h[h > 18.0]
            if len(h):
                walls.append(float(h[0]))
    # The wall's face (a low percentile: the odd pier juts in).
    stair_wall = float(np.percentile(walls, 8)) if walls else 22.4
    print("inner wall along the stair: %.2f m (min %.2f)" % (stair_wall, min(walls) if walls else -1))

    # Cut both meshes.
    print("visual:")
    pv, uvv, iv = cut(P0, uv, idx, notch)
    print("collision:")
    jc, Bc, posc, uvc, idxc = load_glb(col_path)
    Pc = posc * SCALE
    Pc[:, 1] -= Y0
    pc, uvcc, ic = cut(Pc, uvc, idxc, notch)

    # Light shafts: where the sun reaches the ground floor through the hole
    # and the dome's missing glass (on the cut model).
    tric = iv.reshape(-1, 3)
    step = 1.0
    best = None
    for hour in SUN_HOURS:
        to_sun = sun_dir(hour)
        lit = {}
        for gx in np.arange(-R_HOLE - 4, R_HOLE + 4, step):
            for gz in np.arange(-R_HOLE - 4, R_HOLE + 4, step):
                rr = gx * gx + gz * gz
                if rr > 21.5 ** 2 or int(gx + gz) % 2:
                    continue
                # The ground floor under the hole, the walkway round it.
                if (R_HOLE - 0.5) ** 2 <= rr < (R_HOLE + 0.5) ** 2:
                    continue
                y = FLOOR_Y + 0.1 if rr < (R_HOLE - 0.5) ** 2 else 18.2
                if len(raycast(pv, tric, np.array([gx, y, gz]), to_sun)) == 0:
                    lit[(int(round(gx / step)), int(round(gz / step)))] = y
        print("  sun at %.1f h: %d lit" % (hour, len(lit)))
        if best is None or len(lit) > len(best[1]):
            best = (hour, lit, to_sun)
    SUN_HOUR, lit, to_sun = best
    # Fill the checkerboard's gaps back in for grouping.
    for (cx, cz), y in list(lit.items()):
        for nx, nz in ((cx + 1, cz), (cx, cz + 1)):
            if (nx + 1, nz) in lit or (nx, nz + 1) in lit:
                lit[(nx, nz)] = y
    # Group neighbouring lit cells into patches.
    seen, patches = set(), []
    for cell in lit:
        if cell in seen:
            continue
        stack, group = [cell], []
        seen.add(cell)
        while stack:
            cx, cz = stack.pop()
            group.append((cx, cz))
            for nx, nz in ((cx + 1, cz), (cx - 1, cz), (cx, cz + 1), (cx, cz - 1)):
                if (nx, nz) in lit and (nx, nz) not in seen:
                    seen.add((nx, nz))
                    stack.append((nx, nz))
        if len(group) >= 2:
            g = np.array(group, float) * step
            patches.append({"x": round(float(g[:, 0].mean()), 2), "z": round(float(g[:, 1].mean()), 2),
                            "y": lit[group[0]],
                            "radius": round(math.sqrt(len(group) * step * step / math.pi), 2), "cells": len(group)})
    patches.sort(key=lambda p: -p["cells"])
    print("lit patches:", len(patches), [p["cells"] for p in patches[:12]])

    save_glb(vis_path, j, B, (pv + [0, Y0, 0]) / SCALE, uvv, iv)
    save_glb(col_path, jc, Bc, (pc + [0, Y0, 0]) / SCALE, uvcc, ic)
    layout = {
        "scale": SCALE, "y0": round(Y0, 4), "floor_y": FLOOR_Y,
        "hole": {"radius": R_HOLE, "y_cut": Y_CUT, "rim": rim},
        "notch": {"from": round(notch[0], 5), "to": round(notch[1], 5), "edges": notch_edges, "r_wall": R_WALL_CUT},
        "coping": coping,
        "walkway": walkway,
        "stair": {"start": round(STAIR_START, 5), "end": round(end, 5), "steps": STAIR_STEPS,
                  "r_outer": round(min(R_WALL_CUT - 0.2, stair_wall - 0.3), 3), "width": STAIR_WIDTH,
                  "y0": FLOOR_Y, "y1": STAIR_TOP_Y},
        "sun": {"hour": SUN_HOUR, "dir": [round(float(x), 5) for x in to_sun]},
        "light": patches[:10],
        "gaps": dome_gaps(pv, iv.reshape(-1, 3))[:24],
    }
    with open(os.path.join(DIR, "interior.json"), "w") as f:
        json.dump(layout, f, indent=1)
    print("done")


if __name__ == "__main__":
    main()
