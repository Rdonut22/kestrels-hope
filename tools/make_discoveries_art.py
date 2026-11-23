#!/usr/bin/env python3
"""Builds the Discoveries UI art (ui/discoveries/art/*.png) from the approved
design: the supplied "Kestrel's Hope Discoveries Individual Assets" pack
(its REFERENCE_original_mockup.png at 1608 x 978, and the transparent glyph
exports).

The pack's pieces are cut from one flattened mockup, so the placeholder text
("Make Something to Eat", "Repair Meki", button labels...) is baked into the
backgrounds. This script cuts each piece from the reference at its exact
position, paints the placeholder text and widgets out (OpenCV inpainting or
copies of clean background next to it) and saves:

  panel_plate.png     the whole panel, empty: frame, header (emblem,
                      DISCOVERIES, red slashes), nav frame, dividers, footer
                      keys (E Track / Untrack, ESC Close, the F key cap)
  nav_button.png / nav_button_selected.png, count_plate.png
  row_selected.png    the glowing selected-row plate
  row_rule.png, header_rule.png, detail_rule.png  (transparent lines)
  button_filled.png / button_outline.png / tag_outline.png  (no text)
  required_banner_task.png / required_banner_mission.png
  hud_badge_task.png / hud_badge_mission.png
  glyph_*.png         the pack's transparent diamonds, emblem and labels
  discoveries/images/make_something_to_eat.png  the detail picture

Mission (green) variants are the amber art recoloured, as the mockup only
shows Tasks. Positions of everything are in ui/discoveries/discoveries_panel.gd
(mockup pixels).

  python3 tools/make_discoveries_art.py <unzipped asset pack dir>
Needs numpy, pillow and opencv-python-headless.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui", "discoveries", "art")
os.makedirs(OUT, exist_ok=True)

R = np.array(Image.open(os.path.join(SRC, "REFERENCE_original_mockup.png")).convert("RGB"))
GREEN_HUE = 50.0   # OpenCV hue (0-180) of #79B85A
AMBER_HUE = 19.0


def save(name, arr, mode="RGB"):
    Image.fromarray(arr.astype(np.uint8), mode).save(os.path.join(OUT, name + ".png"))
    print(name, arr.shape[1], "x", arr.shape[0])


def crop(x0, y0, x1, y1, img=None):
    img = R if img is None else img
    return img[y0:y1, x0:x1].copy()


def lum(a):
    return a[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], np.float32)


def bright_mask(a, rect, thresh=28, grow=3):
    """Pixels in rect (x0, y0, x1, y1, crop coords) clearly brighter than the
    local background: text, glyphs, outlines."""
    x0, y0, x1, y1 = rect
    m = np.zeros(a.shape[:2], np.uint8)
    region = lum(a[y0:y1, x0:x1])
    bg = cv2.medianBlur(region.astype(np.uint8), 31).astype(np.float32)
    m[y0:y1, x0:x1] = ((region - bg) > thresh).astype(np.uint8) * 255
    if grow:
        m = cv2.dilate(m, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
    return m


def dark_mask(a, rect, thresh=40, grow=2):
    """Dark text on a light plate."""
    x0, y0, x1, y1 = rect
    m = np.zeros(a.shape[:2], np.uint8)
    region = lum(a[y0:y1, x0:x1])
    bg = np.percentile(region, 70)
    m[y0:y1, x0:x1] = ((bg - region) > thresh).astype(np.uint8) * 255
    if grow:
        m = cv2.dilate(m, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
    return m


def rect_mask(a, rect):
    x0, y0, x1, y1 = rect
    m = np.zeros(a.shape[:2], np.uint8)
    m[y0:y1, x0:x1] = 255
    return m


def inpaint(a, mask, radius=5):
    return cv2.inpaint(a, mask, radius, cv2.INPAINT_TELEA)


def recolor(a, hue):
    """Rotate the saturated (amber/red) parts to another hue; greys stay."""
    rgb = a[..., :3]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV).astype(np.float32)
    sat = hsv[..., 1] / 255.0
    w = np.clip((sat - 0.15) / 0.25, 0, 1)
    hsv[..., 0] = hsv[..., 0] * (1 - w) + hue * w
    out = cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2RGB)
    if a.shape[2] == 4:
        out = np.dstack([out, a[..., 3]])
    return out


def extract(a, bg=None, gain=2.2, color=None):
    """A bright line or outline on the dark background -> RGBA with alpha
    from how much brighter than the background each pixel is."""
    L = lum(a)
    if bg is None:
        bg = np.median(L)
    # A margin above the background so its grain stays fully clear.
    alpha = np.clip((L - bg - 10.0) * gain, 0, 255)
    rgb = a[..., :3].astype(np.float32)
    if color is not None:
        rgb = np.broadcast_to(np.array(color, np.float32), rgb.shape)
    else:
        # Un-premultiply roughly so edges keep their colour.
        k = np.clip(alpha / 255.0, 0.05, 1)[..., None]
        base = np.median(a[..., :3].reshape(-1, 3), axis=0)
        rgb = np.clip((rgb - base * (1 - k)) / k, 0, 255)
    return np.dstack([rgb, alpha]).astype(np.uint8)


def smooth_fill(a, rect):
    """Keep a filled rect's grain but replace its low frequencies with a
    smooth blend of its surroundings (no banding from copied blocks)."""
    x0, y0, x1, y1 = rect
    f = 8
    small = cv2.resize(a, (a.shape[1] // f, a.shape[0] // f), interpolation=cv2.INTER_AREA)
    m = np.zeros(small.shape[:2], np.uint8)
    m[y0 // f + 1:y1 // f, x0 // f + 1:x1 // f] = 255
    target = cv2.resize(cv2.inpaint(small, m, 6, cv2.INPAINT_TELEA), (a.shape[1], a.shape[0]), interpolation=cv2.INTER_CUBIC)
    region = a[y0:y1, x0:x1].astype(np.float32)
    lf = cv2.GaussianBlur(region, (0, 0), 18)
    out = region - lf + target[y0:y1, x0:x1].astype(np.float32)
    a[y0:y1, x0:x1] = np.clip(out, 0, 255).astype(np.uint8)


def feather_edges(a, rect, w=5):
    """Blend a filled rect's border into what's around it."""
    x0, y0, x1, y1 = rect
    m = np.zeros(a.shape[:2], np.uint8)
    m[max(0, y0 - w):y1 + w, max(0, x0 - w):x1 + w] = 255
    m[y0 + w:y1 - w, x0 + w:x1 - w] = 0
    return inpaint(a, m, w + 2)


def smooth_interior(a, rect, sigma=14):
    """Blur away inpainting smudges inside a plate, keeping its gradient."""
    x0, y0, x1, y1 = rect
    region = a[y0:y1, x0:x1].astype(np.float32)
    blurred = cv2.GaussianBlur(region, (0, 0), sigma)
    # A little of the original grain back.
    grain = region - cv2.GaussianBlur(region, (0, 0), 2)
    a[y0:y1, x0:x1] = np.clip(blurred + grain * 0.35, 0, 255).astype(np.uint8)


def shape_alpha(a, thresh, close=3):
    """RGBA: opaque inside the plate's bright outline (and the outline
    itself), clear outside it. The flattened mockup has its own background
    round every plate; this leaves just the plate."""
    L = lum(a)
    edge = (L > thresh).astype(np.uint8)
    edge = cv2.morphologyEx(edge, cv2.MORPH_CLOSE, np.ones((close, close), np.uint8))
    h, w = edge.shape
    # Flood the outside from the image border; everything not reached is
    # the plate.
    outside = np.zeros((h + 2, w + 2), np.uint8)
    canvas = edge.copy()
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if canvas[seed[1], seed[0]] == 0:
            cv2.floodFill(canvas, outside, seed, 2)
    inside = (canvas != 2).astype(np.float32)
    alpha = cv2.GaussianBlur(inside, (0, 0), 0.8)
    return np.dstack([a[..., :3], (alpha * 255).astype(np.uint8)])


def polygon_alpha(a, pts, grow=2):
    """RGBA: opaque inside a polygon (the plate's measured outline, grown a
    little for its glow), clear outside."""
    m = np.zeros(a.shape[:2], np.uint8)
    cv2.fillPoly(m, [np.array(pts, np.int32)], 255)
    if grow:
        m = cv2.dilate(m, np.ones((grow * 2 + 1, grow * 2 + 1), np.uint8))
    alpha = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 0.9)
    return np.dstack([a[..., :3], alpha.astype(np.uint8)])


def copy_block(a, dst, src_xy):
    """Copy a block of `a` (crop coords) onto dst rect (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = dst
    sx, sy = src_xy
    a[y0:y1, x0:x1] = a[sy:sy + (y1 - y0), sx:sx + (x1 - x0)]


def tile_rows(a, dst, src_y0, src_y1):
    """Fill dst rect by stacking copies of rows src_y0..src_y1 (same columns)."""
    x0, y0, x1, y1 = dst
    h = src_y1 - src_y0
    y = y0
    while y < y1:
        n = min(h, y1 - y)
        a[y:y + n, x0:x1] = a[src_y0:src_y0 + n, x0:x1]
        y += n


# ------------------------------------------------------------------ panel
# The whole panel (01_panel_outer_frame clips its right edge: cut wider,
# mockup 56,166 - 1562,872), emptied.
PX, PY = 56, 166
P = crop(56, 166, 1562, 872)
def pr(x0, y0, x1, y1):  # mockup rect -> panel crop rect
    return (x0 - PX, y0 - PY, x1 - PX, y1 - PY)

# Nav buttons: rows of the empty nav frame further down.
x0, y0, x1, y1 = pr(74, 276, 342, 432)
tile_rows(P, (x0, y0, x1, y1), 600 - PY, 760 - PY)
# Centre: TASKS header and the three rows -> the empty space under them.
x0, y0, x1, y1 = pr(346, 262, 890, 600)
tile_rows(P, (x0, y0, x1, y1), 606 - PY, 790 - PY)
smooth_fill(P, (x0, y0, x1, y1))
P = feather_edges(P, (x0, y0, x1, y1))
# Right: picture, title, tag, description, steps, banner -> centre's empty
# space, copied across (the background is the same dark grain).
x0, y0, x1, y1 = pr(905, 268, 1541, 800)  # the divider is at x 897-898
src = P[606 - PY:790 - PY, 346 - PX:873 - PX]
h, w = src.shape[:2]
y = y0
while y < y1:
    x = x0
    n = min(h, y1 - y)
    flip = False
    while x < x1:
        m = min(w, x1 - x)
        blk = src[:n, ::-1] if flip else src[:n]
        P[y:y + n, x:x + m] = blk[:, :m]
        x += m
        flip = not flip
    y += n
smooth_fill(P, (x0, y0, x1, y1))
P = feather_edges(P, (x0, y0, x1, y1))
# Footer: "View on Map" goes (the F key cap stays for "HUD Focus").
x0, y0, x1, y1 = pr(318, 806, 436, 848)
copy_block(P, (x0, y0, x1, y1), (pr(470, 0, 0, 0)[0], y0))
# Its outline (measured on the mockup): 24 px chamfers.
outline = [(61, 194), (85, 170), (1534, 170), (1558, 194), (1558, 846), (1536, 868), (83, 868), (61, 846)]
save("panel_plate", polygon_alpha(P, [(x - PX, y - PY) for x, y in outline]), "RGBA")

# ------------------------------------------------------------------ nav
for name, rect in [("nav_button", (80, 282, 331, 352)), ("nav_button_selected", (77, 354, 335, 423))]:
    a = crop(*rect)
    hgt, wid = a.shape[:2]
    m = bright_mask(a, (12, 10, wid - 12, hgt - 10), thresh=24, grow=4)
    # The count plate is light: take it out too.
    m |= rect_mask(a, (190, 14, 232, hgt - 14))
    a = inpaint(a, m, 6)
    smooth_interior(a, (12, 12, wid - 12, hgt - 12))
    save(name, a)

# The pack's 11/12 count crops are ~7 px off the plate: cut it here.
cp = crop(280, 305, 314, 334)
cp = inpaint(cp, dark_mask(cp, (5, 3, 29, 26), thresh=50, grow=2), 4)
save("count_plate", cp)

# ------------------------------------------------------------------ rows
a = crop(351, 328, 885, 417)
hgt, wid = a.shape[:2]
m = bright_mask(a, (12, 10, wid - 12, hgt - 10), thresh=22, grow=4)
m |= rect_mask(a, (420, 22, 522, 64))  # the TRACKED button
a = inpaint(a, m, 7)
smooth_interior(a, (12, 12, wid - 12, hgt - 12), 18)
save("row_selected", a)

save("row_rule", extract(crop(356, 424, 882, 431)), "RGBA")
save("header_rule", extract(crop(356, 308, 882, 316)), "RGBA")
save("detail_rule", extract(crop(916, 559, 1530, 567)), "RGBA")

# ------------------------------------------------------------------ buttons
a = crop(776, 354, 866, 388)  # TRACKED: amber, dark text
a = inpaint(a, dark_mask(a, (8, 6, 82, 28), thresh=60, grow=2), 4)
save("button_filled_task", a)
save("button_filled_mission", recolor(a, GREEN_HUE))
a = crop(777, 447, 872, 482)  # TRACK: outline
a = inpaint(a, bright_mask(a, (10, 8, 85, 27), thresh=30, grow=2), 4)
save("button_outline", extract(a, gain=2.0), "RGBA")
a = crop(1446, 450, 1531, 486)  # TASK tag: amber outline
a = inpaint(a, bright_mask(a, (10, 8, 75, 28), thresh=30, grow=2), 4)
tag = extract(a, gain=2.0)
save("tag_outline_task", tag, "RGBA")
save("tag_outline_mission", recolor(tag, GREEN_HUE), "RGBA")

# ------------------------------------------------------------------ required
a = crop(916, 746, 1533, 796)
save("required_banner_task", a)
save("required_banner_mission", recolor(a, GREEN_HUE))

# ------------------------------------------------------------------ HUD badge
a = crop(1240, 80, 1585, 139)
hgt, wid = a.shape[:2]
a = inpaint(a, bright_mask(a, (30, 10, wid - 48, hgt - 10), thresh=26, grow=4), 6)
smooth_interior(a, (30, 12, wid - 50, hgt - 12), 10)
# The badge's outline (mockup 1240,80 crop): pointed ends.
badge = polygon_alpha(a, [(28, 4), (314, 4), (342, 20), (342, 33), (316, 53), (30, 53), (6, 33), (6, 20)])
save("hud_badge_task", badge, "RGBA")
save("hud_badge_mission", recolor(badge, GREEN_HUE), "RGBA")

# ------------------------------------------------------------------ glyphs
def glyph(src_name, out_name):
    g = np.array(Image.open(os.path.join(SRC, src_name)).convert("RGBA"))
    save(out_name, g, "RGBA")
    return g

glyph("02_header_compass_emblem.png", "glyph_emblem")
glyph("07_nav_mission_green_diamond.png", "glyph_mission_emblem")
glyph("08_nav_task_amber_diamond.png", "glyph_task_diamond")
# Labels cut tight from the reference (the pack's TASKS export carries a
# stripe of the button's glow).
save("glyph_label_missions", extract(crop(150, 302, 240, 334), gain=1.6), "RGBA")
save("glyph_label_tasks", extract(crop(150, 372, 222, 404), gain=1.6), "RGBA")
# The pack's 17/18 diamonds keep a dark halo from their masking: cut them
# again from the same spots with clean alpha.
# (Centred on the mockup's diamonds at (391, 372) and (391, 465); the
# pack's 18 crop also cuts the bottom off.)
amber = extract(crop(371, 352, 411, 392), gain=2.0, color=(247, 169, 43))
save("glyph_diamond_amber", amber, "RGBA")
save("glyph_diamond_ivory", extract(crop(371, 445, 411, 485), gain=2.0, color=(240, 232, 218)), "RGBA")
save("glyph_diamond_green", recolor(amber, GREEN_HUE), "RGBA")
# The pack's 30_detail_diamond and 47_hud_persistent_diamond are clipped:
# cut from the reference instead.
big = extract(crop(923, 442, 980, 496), gain=1.6)
save("glyph_detail_diamond_amber", big, "RGBA")
save("glyph_detail_diamond_green", recolor(big, GREEN_HUE), "RGBA")
# Untracked detail diamond: the amber one in ivory.
iv = big.copy()
iv[..., :3] = np.array([233, 222, 203], np.uint8)
save("glyph_detail_diamond_ivory", iv, "RGBA")
save("glyph_badge_diamond", extract(crop(1271, 92, 1307, 126), gain=1.8, color=(240, 232, 218)), "RGBA")

# ------------------------------------------------------------------ picture
save("../../../discoveries/images/make_something_to_eat", crop(916, 277, 1530, 437))
print("done ->", os.path.normpath(OUT))
