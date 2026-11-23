#!/usr/bin/env python3
"""Builds the wrist terminal's home-screen art (ui/wrist_ui/art/*.png) from
the approved design: the supplied "Kestrel Terminal Home Exact Assets" pack
(its 00_full_design_reference.png, 1703 x 923, a close-up of the G-07).

The pack's crops have their text baked in, so (as for Discoveries, see
tools/make_discoveries_art.py) each piece is cut from the reference and the
text is painted out; the terminal draws its own text over them:

  screen_plate.png        the screen: amber frame, contour background,
                          header (USHIDA, FIELD TERMINAL G-07, slashes,
                          PWR 82% / LOCAL MODE), dividers; no tiles, no
                          footer text
  footer_home.png         the home footer exactly as designed
  tile.png / tile_selected.png   the module tiles, empty (outline, glow,
                          divider)
  icon_*.png              the six module icons, transparent

Layout: the reference region SRC (the screen inside the bezel) is scaled
by K to the terminal's 1280-wide UI and placed TOP px down (the UI is 1280 x
800; the screen region is a little wider than 16:10). Positions are in
ui/wrist_ui/terminal_ui.gd in reference pixels.

  python3 tools/make_terminal_art.py <unzipped asset pack dir>
Needs numpy, pillow and opencv-python-headless.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

SRC_DIR = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.environ.get("ART_OUT") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui", "wrist_ui", "art")
os.makedirs(OUT, exist_ok=True)

R = np.array(Image.open(os.path.join(SRC_DIR, "00_full_design_reference.png")).convert("RGB"))
SRC = (384, 196, 1289, 739)          # the screen in the reference
K = 1280.0 / (SRC[2] - SRC[0])       # reference px -> UI px
TOP = 16                             # UI px above the scaled screen

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



def to_ui(a, interp=cv2.INTER_AREA):
    """Scale a reference-pixel image to UI pixels."""
    h, w = a.shape[:2]
    return cv2.resize(a, (max(1, round(w * K)), max(1, round(h * K))), interpolation=interp)


def sx(x):
    return x - SRC[0]


def sy(y):
    return y - SRC[1]


# ------------------------------------------------------------------ screen
S = crop(*SRC)
GLASS = np.array([12, 10, 8], np.uint8)
# Outside the amber frame is the device's bezel in the photo: the display
# glass there instead (the frame's outline, measured, plus its glow).
FRAME = [(386, 252), (436, 201), (1206, 201), (1271, 252), (1285, 688), (1242, 733), (424, 733), (380, 690)]
inside = np.zeros(S.shape[:2], np.uint8)
cv2.fillPoly(inside, [np.array([(x - SRC[0], y - SRC[1]) for x, y in FRAME], np.int32)], 255)
inside = cv2.dilate(inside, np.ones((13, 13), np.uint8))
soft = cv2.GaussianBlur(inside.astype(np.float32) / 255.0, (0, 0), 3)[..., None]
S = (S * soft + GLASS * (1 - soft)).astype(np.uint8)
# The tiles' area: filled smooth (the tiles cover it).
grid = (sx(402), sy(296), sx(1262), sy(664))
S = inpaint(S, rect_mask(S, grid), 9)
smooth_fill(S, grid)
S = feather_edges(S, grid, 4)
# The footer's text row (the divider above it stays).
foot = (sx(402), sy(684), sx(1262), sy(722))
S = inpaint(S, rect_mask(S, foot), 7)
smooth_interior(S, foot, 16)
plate = np.zeros((800, 1280, 3), np.uint8)
ui = to_ui(S)
plate[TOP:TOP + ui.shape[0], :ui.shape[1]] = ui[:800 - TOP]
# Above and below the scaled screen: the screen's own darkest edge colour.
edge = np.median(S[:4].reshape(-1, 3), axis=0)
plate[:TOP] = edge
plate[TOP + ui.shape[0]:] = edge
save("screen_plate", plate)

# The home footer, exactly as designed (cut before the text was removed).
F = crop(400, 680, 1270, 724)
save("footer_home", to_ui(F))

# ------------------------------------------------------------------ tiles
def clean_tile(rect, divider_x, icon_rect, text_rect):
    a = crop(*rect)
    x0, y0 = rect[0], rect[1]
    m = bright_mask(a, (icon_rect[0] - x0, icon_rect[1] - y0, icon_rect[2] - x0, icon_rect[3] - y0), thresh=20, grow=4)
    m |= bright_mask(a, (text_rect[0] - x0, text_rect[1] - y0, text_rect[2] - x0, text_rect[3] - y0), thresh=20, grow=4)
    a = inpaint(a, m, 7)
    for r in (icon_rect, text_rect):
        smooth_interior(a, (r[0] - x0, r[1] - y0, r[2] - x0, r[3] - y0), 9)
    return a

# Selected: the MAP tile (outline 416..822 x 309..412, glow round it).
sel = clean_tile((404, 297, 834, 425), 552, (430, 318, 545, 404), (560, 318, 812, 404))
save("tile_selected", to_ui(sel))
# Not selected: the DISCOVERIES tile (837..1247 x 309..412).
nor = clean_tile((829, 301, 1256, 420), 969, (848, 316, 962, 405), (976, 316, 1240, 405))
save("tile", to_ui(nor))

# ------------------------------------------------------------------ icons
ICONS = {
    "map": (437, 316, 523, 386),
    "discoveries": (862, 322, 950, 396),
    "comms": (452, 446, 534, 512),
    "inventory": (868, 449, 948, 511),
    "arm": (446, 562, 534, 638),
    "scan": (864, 562, 952, 636),
}
for name, rect in ICONS.items():
    a = crop(*rect)
    # (The MAP icon sits on the selected tile's warm fill: a higher floor.)
    bg = np.median(lum(a)) + (22 if name == "map" else 0)
    save("icon_" + name, to_ui(extract(a, bg=bg, gain=2.4), cv2.INTER_CUBIC), "RGBA")
print("done ->", os.path.normpath(OUT))
