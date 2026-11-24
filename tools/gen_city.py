"""Procedural pixel-art Shenzhen: skyline, bay, waterfront and street surface.

Replaces the old cut-out workflow (build_layers.py / build_masks.py cropped and
patched an AI painting, purple sky included). Everything above the station is
now drawn here at 1 texel = 1 scene pixel, with a small fixed palette, so the
preview can show it crisp (nearest sampling) and relight it in real time.

Outputs (2172 x 724, scene coordinates):
  assets/layers/city-base.png     surface colours by day; sky pixels transparent
  assets/layers/city-masks.png    R sky  G water  B haze depth  A foliage (sway)
  assets/layers/city-windows.png  R window class (40 office, 80 home, 120 beacon)
                                  G/B 16-bit window id (one switch per window)
                                  A 255 = facade joins the evening light show

Layout after the street was narrowed (far side moved down 14 px):
  y 0-362 sky and skyline (buildings stand on the far shore at y 362)
  y 362-382 bay water, 382-388 sea wall, 388-446 green belt with trees + lamps
  y 446-481 far pavement and kerb, 481-535 road (median 500-510)
  y 535-556 near pavement, 556-564 station roof slab; below 564 the station
  (drawn by scripts/station.gd) is copied unchanged from the previous base.

Landmarks (stylised silhouettes, not survey-accurate): Ping An Finance Centre
(clearly the tallest), China Resources "Spring Bamboo" tower, KK100, Diwang
(Shun Hing Square), SEG Plaza, the Shenzhen Stock Exchange with its floating
podium, Tencent Seafront Towers and the Civic Centre roof. The background
mass stays lower (tops y 228-305) so every landmark stands out.

Run from the project root:  python tools/gen_city.py
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
W, H = 2172, 724
SHORE = 362
SURFACE_END = 564
rng = np.random.default_rng(20261120)

img = np.zeros((H, W, 4), np.uint8)
sky = np.ones((H, W), np.float32)
water = np.zeros((H, W), np.float32)
depth = np.zeros((H, W), np.float32)
foliage = np.zeros((H, W), np.float32)
win_class = np.zeros((H, W), np.uint8)
win_id = np.zeros((H, W), np.uint16)
show = np.zeros((H, W), np.uint8)
next_id = [1]

OFFICE, HOME, BEACON = 40, 80, 120


def C(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32)


def shade(c, k):
    return np.clip(np.asarray(c, np.float32) * k, 0, 255)


def put(x0, y0, x1, y1, color, d=None, opaque=True):
    """Fill [x0,x1) x [y0,y1) with colour; marks it solid (not sky)."""
    x0, x1 = max(0, int(x0)), min(W, int(x1))
    y0, y1 = max(0, int(y0)), min(H, int(y1))
    if x0 >= x1 or y0 >= y1:
        return
    img[y0:y1, x0:x1, :3] = np.asarray(color, np.float32).astype(np.uint8)
    img[y0:y1, x0:x1, 3] = 255
    if opaque:
        sky[y0:y1, x0:x1] = 0
        win_class[y0:y1, x0:x1] = 0
        show[y0:y1, x0:x1] = 0
    if d is not None:
        depth[y0:y1, x0:x1] = d


def px(x, y, color, d=None):
    put(x, y, x + 1, y + 1, color, d)


def window(x0, y0, x1, y1, color, cls, d, lightshow=False):
    put(x0, y0, x1, y1, color, d)
    x0, x1 = max(0, int(x0)), min(W, int(x1))
    y0, y1 = max(0, int(y0)), min(H, int(y1))
    if x0 >= x1 or y0 >= y1:
        return
    win_class[y0:y1, x0:x1] = cls
    win_id[y0:y1, x0:x1] = next_id[0] % 65535 + 1
    if lightshow:
        show[y0:y1, x0:x1] = 255
    next_id[0] += 1


def beacon(x, y, d):
    window(x, y, x + 1, y + 1, C("8a2a22"), BEACON, d)


# ---------------------------------------------------------------- buildings
def block(x0, x1, top, body, d, side=0.78, outline=0.62, base=SHORE):
    """A box with a darker right side face and a 1 px roof line."""
    w = x1 - x0
    put(x0, top, x1, base, body, d)
    face = max(2, w // 5)
    put(x1 - face, top, x1, base, shade(body, side), d)
    put(x0, top, x1, top + 1, shade(body, 1.12), d)
    put(x0, top, x0 + 1, base, shade(body, 1.08), d)
    put(x1 - 1, top, x1, base, shade(body, outline), d)
    return face


def office_glass(x0, x1, top, d, glass="4f7591", frame="9fb3bf", floor=3, lightshow=False, base=SHORE):
    glass_c, frame_c = C(glass), C(frame)
    face = block(x0, x1, top, frame_c, d, base=base)
    for y in range(top + 2, base - 2, floor):
        for x in range(x0 + 1, x1 - 1, 3):
            g = glass_c if x < x1 - face else shade(glass_c, 0.8)
            # Sky reflection: upper floors slightly lighter.
            k = 1.0 + 0.12 * (1 - (y - top) / max(1, base - top))
            window(x, y, min(x + 2, x1 - 1), y + floor - 1, shade(g, k), OFFICE, d, lightshow)


def office_ribbon(x0, x1, top, d, body="b9bbb4", glass="3c5162", base=SHORE):
    face = block(x0, x1, top, C(body), d, base=base)
    for y in range(top + 3, base - 2, 4):
        for x in range(x0 + 2, x1 - 2, 4):
            g = C(glass) if x < x1 - face else shade(C(glass), 0.8)
            window(x, y, min(x + 3, x1 - 2), y + 2, g, OFFICE, d)


def residential(x0, x1, top, d, body, base=SHORE, tanks=True):
    body = C(body)
    face = block(x0, x1, top, body, d, base=base)
    rail = shade(body, 1.18)
    for y in range(top + 3, base - 2, 4):
        put(x0 + 1, y + 2, x1 - 1, y + 3, shade(body, 0.9), d)  # slab line
        for x in range(x0 + 2, x1 - 2, 4):
            g = C("3a4650") if x < x1 - face else C("2f3a43")
            window(x, y, min(x + 2, x1 - 2), y + 2, g, HOME, d)
            if (x // 4 + y // 4) % 5 == 0:
                px(min(x + 2, x1 - 3), y + 1, shade(body, 0.82), d)  # AC unit (grey, not white)
        if (y // 4) % 2 == 0:
            put(x0 + 1, y + 2, x1 - face, y + 3, rail, d)      # balcony rail
    if tanks:
        put(x0 + 3, top - 3, x0 + 7, top, C("9aa0a0"), d)
        put(x1 - face - 6, top - 2, x1 - face - 2, top, C("8c8f8a"), d)


def walkup(x0, x1, top, d, body):
    """Six/seven-floor 1980s Shenzhen walk-ups (like Yuanling): tiles, grilles."""
    body = C(body)
    face = block(x0, x1, top, body, d)
    for y in range(top + 2, SHORE - 2, 4):
        for x in range(x0 + 2, x1 - 2, 5):
            window(x, y, min(x + 3, x1 - 2), y + 2, C("37424b"), HOME, d)
            px(x, y + 2, C("7f8b8e"), d)  # window grille ledge
    put(x0, top - 2, x1, top, shade(body, 0.85), d)
    for x in range(x0 + 4, x1 - 4, 11):  # rooftop clutter: tanks, sheds, plants
        put(x, top - 4, x + 3, top - 2, C("9aa0a0"), d)
        px(x + 6, top - 3, C("4f7a45"), d)


# ---------------------------------------------------------------- landmarks
def ping_an(cx, top=72, d=0.33):
    """平安金融中心: the tallest tower by far, a slim tapering shaft with eight
    stainless-steel ribs (bright corner piers), stepped crown and short spire."""
    steel, steel_dark, glass = C("d3d9dc"), C("8f989d"), C("5a7b92")
    body_top = top + 30
    for y in range(body_top, SHORE):
        t = (y - body_top) / (SHORE - body_top)
        half = int(round(12 + 9 * t ** 1.3))
        put(cx - half, y, cx + half, y + 1, steel, d)
        put(cx + half - max(3, half // 3), y, cx + half, y + 1, shade(steel, 0.74), d)
        if (y - top) % 4 != 0:
            for x in range(cx - half + 2, cx + half - 2):
                if (x - cx) % 6 == 0:
                    continue                      # mid-face rib
                g = glass if x < cx + half - half // 3 else shade(glass, 0.78)
                window(x, y, x + 1, y + 1, shade(g, 1.06), OFFICE, d, lightshow=True)
        # Corner piers: two bright columns per edge, the tower's signature.
        put(cx - half, y, cx - half + 2, y + 1, C("eef2f3"), d)
        put(cx + half - 2, y, cx + half, y + 1, steel_dark, d)
        put(cx - 1, y, cx + 1, y + 1, shade(steel, 1.06), d)
    for y in range(body_top, SHORE, 4):
        for x in range(cx - 22, cx + 22, 3):
            sel = win_class[y:y + 4, x:x + 3] == OFFICE
            win_id[y:y + 4, x:x + 3][sel] = next_id[0] % 65535 + 1
            next_id[0] += 1
    # Stepped crown narrowing to the spire.
    steps = [(12, 9), (10, 8), (8, 6), (5, 5), (3, 4)]
    y0 = body_top
    for i, (hw, h) in enumerate(steps):
        y0 -= h
        put(cx - hw, y0, cx + hw, y0 + h, shade(steel, 1.06 - i * 0.03), d)
        put(cx + hw - max(2, hw // 3), y0, cx + hw, y0 + h, shade(steel, 0.76), d)
        put(cx - hw, y0, cx - hw + 1, y0 + h, C("f4f6f6"), d)
    put(cx - 1, y0 - 14, cx + 1, y0, C("dfe4e6"), d)
    put(cx, y0 - 22, cx + 1, y0 - 14, C("dfe4e6"), d)
    beacon(cx, y0 - 23, d)
    beacon(cx - 11, body_top - 6, d)
    beacon(cx + 10, body_top - 6, d)


def stock_exchange(cx, top=250, d=0.3):
    """深圳证券交易所: a square glass tower whose podium floats in mid-air on
    giant cantilevers, with open sky underneath."""
    office_glass(cx - 15, cx + 15, top, d, glass="4e6f84", frame="b4bec4", floor=3)
    lift_top, lift_bot = 300, 309
    put(cx - 34, lift_top, cx + 34, lift_bot, C("c8ced0"), d)          # floating podium
    put(cx - 34, lift_bot - 1, cx + 34, lift_bot, C("7e878b"), d)
    for x in range(cx - 32, cx + 32, 3):
        window(x, lift_top + 3, x + 2, lift_top + 6, C("4a6678"), OFFICE, d)
    # Sky shows through below the podium on both sides of the core.
    for x0, x1 in ((cx - 34, cx - 15), (cx + 15, cx + 34)):
        img[lift_bot:330, x0:x1, 3] = 0
        sky[lift_bot:330, x0:x1] = 1
        win_class[lift_bot:330, x0:x1] = 0
    beacon(cx, top - 1, d)


def spring_bamboo(cx, top=124, d=0.38):
    white, rib = C("e3e5e0"), C("c3c7c4")
    for y in range(top, SHORE):
        if y < top + 78:
            half = int(round(21 * np.sqrt((y - top) / 78.0)))
        else:
            half = 21
        if half < 1:
            continue
        for x in range(cx - half, cx + half):
            col = white if (x - cx) % 2 == 0 else rib
            if x >= cx + half - half // 3:
                col = shade(col, 0.8)
            if (x - cx) % 2 and (y - top) % 4 and y > top + 6:
                window(x, y, x + 1, y + 1, shade(C("49647a"), 1.0 if x < cx + half - half // 3 else 0.8), OFFICE, d, lightshow=True)
            else:
                put(x, y, x + 1, y + 1, col, d)
    for y in range(top + 6, SHORE, 4):
        for x in range(cx - 21, cx + 21, 4):
            sel = win_class[y:y + 4, x:x + 4] == OFFICE
            win_id[y:y + 4, x:x + 4][sel] = next_id[0] % 65535 + 1
            next_id[0] += 1
    beacon(cx, top - 1, d)


def kk100(cx, top=138, d=0.36):
    glass, frame = C("5e7d95"), C("aab8c0")
    for y in range(top, SHORE):
        if y < top + 20:
            half = int(round(18 * np.sqrt((y - top) / 20.0)))
        else:
            half = 18
        if half < 1:
            continue
        put(cx - half, y, cx + half, y + 1, frame, d)
        put(cx + half - 6, y, cx + half, y + 1, shade(frame, 0.78), d)
    # Arched crown: a dark open lantern under the curved roof.
    put(cx - 12, top + 8, cx + 12, top + 18, C("2c3a46"), d)
    office_glass(cx - 17, cx + 17, top + 22, d, glass="5e7d95", frame="aab8c0", floor=3, lightshow=True)
    put(cx - 18, top + 20, cx + 18, top + 22, shade(frame, 1.1), d)
    beacon(cx, top - 1, d)


def diwang(cx, top=160, d=0.42):
    office_glass(cx - 16, cx + 12, top, d, glass="4f8b86", frame="a5c2bc", floor=3, lightshow=True)
    # Rounded core tower on the east side, a little taller.
    for y in range(top - 10, SHORE):
        k = 1.0 if y > top - 4 else 0.0
        put(cx + 12, y, cx + 20, y + 1, C("8fb1aa") if (y // 3) % 2 else C("7aa098"), d)
        put(cx + 18, y, cx + 20, y + 1, C("5f7f79"), d)
    # Twin masts.
    for mx in (cx - 9, cx + 5):
        put(mx, top - 26, mx + 1, top, C("c6d4d0"), d)
        beacon(mx, top - 27, d)
    put(cx - 12, top - 4, cx + 9, top, C("9dbab4"), d)


def seg_plaza(cx, top=184, d=0.4):
    office_glass(cx - 16, cx + 16, top, d, glass="587080", frame="b2bcc2", floor=3)
    # Chamfered octagon corners.
    img[top:top + 2, cx - 16:cx - 14, 3] = 0
    sky[top:top + 2, cx - 16:cx - 14] = 1
    img[top:top + 2, cx + 14:cx + 16, 3] = 0
    sky[top:top + 2, cx + 14:cx + 16] = 1
    for mx in (cx - 7, cx + 6):
        put(mx, top - 30, mx + 2, top, C("d4d8d8"), d)
        put(mx, top - 18, mx + 2, top - 17, C("c03a2e"), d)
        beacon(mx, top - 31, d)


def tencent(cx, d=0.4):
    office_glass(cx - 22, cx + 2, 208, d, glass="3f6a8f", frame="98aec0", floor=3)
    office_glass(cx + 8, cx + 28, 238, d, glass="3f6a8f", frame="98aec0", floor=3)
    for y in (252, 290, 326):  # the three "links" between the towers
        put(cx + 2, y, cx + 8, y + 8, C("b8c6cf"), d)
        for x in range(cx + 3, cx + 8, 2):
            window(x, y + 2, x + 1, y + 6, C("47708f"), OFFICE, d)
    beacon(cx - 10, 207, d)
    beacon(cx + 18, 237, d)


def civic_centre(x0, x1, d=0.12):
    # Colonnaded hall under the famous wing-shaped roof (大鹏展翅).
    put(x0 + 10, 334, x1 - 10, SHORE, C("aeb4b4"), d)
    for x in range(x0 + 12, x1 - 12, 6):
        put(x, 338, x + 2, SHORE, C("d8dcda"), d)
        window(x + 2, 338, x + 6, SHORE - 2, C("3c4c58"), OFFICE, d)
    mid = (x0 + x1) / 2
    for x in range(x0, x1):
        t = (x - mid) / ((x1 - x0) / 2)
        y = 330 - 10 * np.cos(t * np.pi / 2) ** 2 + 5 * abs(t) ** 3
        y = int(round(y))
        put(x, y, x + 1, y + 3, C("e6e9e6"), d)
        put(x, y + 3, x + 1, y + 5, C("8f9897"), d)
    # Central red-and-yellow drum (the hall under the roof's middle).
    put(mid - 10, 322, mid + 10, 334, C("c9a24a"), d)
    put(mid - 10, 322, mid + 10, 324, C("b2453a"), d)


# ---------------------------------------------------------------- layout
def hills():
    xs = np.arange(W)
    ridge = 318 + 12 * np.sin(xs / 210.0) + 7 * np.sin(xs / 77.0 + 1.3) + 4 * np.sin(xs / 31.0)
    for x in xs:
        put(x, int(ridge[x]), x + 1, SHORE, C("7f9a92"), 0.9)
        put(x, int(ridge[x]), x + 1, int(ridge[x]) + 1, C("93ada4"), 0.9)


def far_towers():
    x = -10
    while x < W:
        w = int(rng.integers(16, 34))
        top = int(rng.integers(228, 305))
        kind = rng.random()
        if kind < 0.45:
            office_glass(x, x + w, top, 0.62, glass=rng.choice(["5d7f96", "6a8a96", "577a8c"]), frame="aebcc4")
        elif kind < 0.8:
            residential(x, x + w, top, 0.62, rng.choice(["d6cdb8", "cfd3cf", "d9c7a8", "c7ccc4"]))
        else:
            office_ribbon(x, x + w, top, 0.62)
        x += w + int(rng.integers(2, 16))


LANDMARK_SPANS = [(560, 632), (752, 806), (918, 962), (1080, 1140), (1180, 1260), (1316, 1362), (1448, 1494)]


def near_layer():
    """Offices and homes interleaved in front, kept low around the landmarks."""
    x = -6
    i = 0
    while x < W:
        w = int(rng.integers(22, 46))
        near_mark = any(a - 10 < x + w and x < b + 10 for a, b in LANDMARK_SPANS)
        r = rng.random()
        if near_mark or r < 0.35:
            walkup(x, x + w + 14, int(rng.integers(326, 340)), 0.06,
                   rng.choice(["c99b76", "d8c3a0", "bfc4bd", "d2b48c", "c6b39a"]))
            x += w + 14
        elif r < 0.65:
            residential(x, x + w, int(rng.integers(262, 312)), 0.14,
                        rng.choice(["e2dccb", "d7d9d2", "e0cfae", "cdd5d3"]))
            x += w
        else:
            office_glass(x, x + w, int(rng.integers(255, 305)), 0.16,
                         glass=rng.choice(["4c7088", "56808e", "4a6a7c"]), frame="a9b8c0")
            x += w
        x += int(rng.integers(1, 7))
        i += 1


def bay_and_promenade():
    # Far shore: a strip of trees and sea wall at the foot of the city.
    put(0, SHORE - 3, W, SHORE, C("4d6a58"), 0.2)
    for x in range(0, W, 3):
        if rng.random() < 0.5:
            px(x, SHORE - 4, C("557560"), 0.2)
    # Bay water (reflections drawn live by the shader).
    for y in range(SHORE, 382):
        t = (y - SHORE) / 20
        put(0, y, W, y + 1, shade(C("3f7385"), 1.0 - 0.15 * t), 0.0)
        water[y] = 1.0
    # Lake edge: the stone embankment, railing, reeds and ducks are live art
    # in scripts/park.gd, drawn over this water band.
    put(0, 382, W, 412, C("7a9a72"), 0.0)
    # Green belt.
    put(0, 388, W, 446, C("5f8f4f"), 0.0)
    noise = rng.random((58, W))
    g = img[388:446, :, :3].astype(np.float32)
    g[noise < 0.12] *= 0.82
    g[noise > 0.93] *= 1.12
    img[388:446, :, :3] = np.clip(g, 0, 255).astype(np.uint8)
    put(0, 436, W, 446, C("47763e"), 0.0)   # clipped hedge
    for x in range(0, W, 4):
        px(x + (x // 4) % 2, 436, C("6c9c56"), 0.0)
    lamps = [28, 236, 390, 549, 749, 918, 1139, 1296, 1470, 1651, 1839, 2013, 2157]
    # Trees between lamps: banyans (榕树) and the odd royal palm.
    courts = [(940, 1130), (1140, 1550)]   # basketball court, then the park lawn
    for i in range(len(lamps) - 1):
        a, b = lamps[i], lamps[i + 1]
        for k in range(2):
            cx = int(a + (b - a) * (0.3 + 0.4 * k) + rng.integers(-8, 8))
            if any(lo - 20 < cx < hi + 20 for lo, hi in courts):
                continue
            if rng.random() < 0.7:
                banyan(cx, int(rng.integers(11, 17)))
            else:
                palm(cx)
    for x in lamps:
        put(x, 418, x + 1, 446, C("4b5358"), 0.0)
        put(x - 3, 417, x + 4, 418, C("4b5358"), 0.0)
        put(x - 3, 418, x + 4, 420, C("e8e4c8"), 0.0)
    # Far pavement, tiles and the yellow tactile strip.
    put(0, 446, W, 478, C("b2ada2"), 0.0)
    for y in range(446, 478, 8):
        put(0, y, W, y + 1, C("a19c91"), 0.0)
    for y in range(446, 478, 8):
        for x in range((y // 8 % 2) * 8, W, 16):
            put(x, y, x + 1, y + 8, C("a7a297"), 0.0)
    put(0, 466, W, 468, C("c9a845"), 0.0)
    for x in range(0, W, 3):
        px(x, 466, C("b39535"), 0.0)
    put(0, 478, W, 479, C("cfcdc4"), 0.0)
    put(0, 479, W, 481, C("77756f"), 0.0)


def banyan(cx, r):
    put(cx - 1, 414, cx + 2, 446, C("5b4a3a"), 0.0)
    put(cx - 3, 440, cx + 4, 446, C("54463a"), 0.0)
    cy = 402
    yy, xx = np.mgrid[cy - r - 2:cy + r + 2, cx - r - 6:cx + r + 6]
    blob = ((xx - cx) / (r + 5.0)) ** 2 + ((yy - cy) / (r * 0.75)) ** 2
    bump = 0.12 * np.sin(xx * 1.7) * np.cos(yy * 1.3)
    inside = blob + bump < 1.0
    for y, x in zip(yy[inside], xx[inside]):
        if not (0 <= x < W):
            continue
        rel = ((x - cx) / (r + 5.0), (y - cy) / (r * 0.75))
        light = -rel[0] * 0.4 - rel[1] * 0.6 + rng.random() * 0.3
        col = C("2f5f39") if light < -0.1 else (C("3f7542") if light < 0.35 else C("5f9450"))
        put(x, y, x + 1, y + 1, col, 0.0)
        foliage[y, x] = 1.0


def palm(cx):
    for y in range(392, 446):
        bend = int(round(2.5 * np.sin((446 - y) / 54 * 1.4)))
        put(cx + bend, y, cx + bend + 2, y + 1, C("8a7a64") if y % 3 else C("74664f"), 0.0)
    top = (cx + 2, 392)
    for ang in np.linspace(-2.8, -0.3, 6):
        for s in range(1, 15):
            x = int(round(top[0] + np.cos(ang) * s))
            y = int(round(top[1] + np.sin(ang) * s * 0.55 + (s * s) * 0.04))
            put(x, y, x + 1, y + 1, C("3e7a43") if s % 4 else C("5f9a52"), 0.0)
            foliage[y, x] = 1.0
        for s in range(1, 15):
            ang2 = np.pi - ang
            x = int(round(top[0] + np.cos(ang2) * s))
            y = int(round(top[1] + np.sin(ang) * s * 0.55 + (s * s) * 0.04))
            put(x, y, x + 1, y + 1, C("3e7a43") if s % 4 else C("5f9a52"), 0.0)
            foliage[y, x] = 1.0


def road_and_near_side():
    asphalt = C("4a4f55")
    put(0, 481, W, 535, asphalt, 0.0)
    n = rng.random((54, W))
    a = img[481:535, :, :3].astype(np.float32)
    a[n < 0.05] *= 0.88
    a[n > 0.96] *= 1.12
    img[481:535, :, :3] = np.clip(a, 0, 255).astype(np.uint8)
    for y in (494, 527):   # worn wheel tracks
        put(0, y, W, y + 2, shade(asphalt, 0.93), 0.0)
    put(0, 500, W, 510, C("6b6e6c"), 0.0)   # median under the barrier
    put(0, 535, W, 537, C("77756f"), 0.0)
    put(0, 537, W, 538, C("cfcdc4"), 0.0)
    put(0, 538, W, 556, C("b7b0a3"), 0.0)
    for y in range(538, 556, 6):
        put(0, y, W, y + 1, C("a59f93"), 0.0)
    for y in range(538, 556, 6):
        for x in range((y // 6 % 2) * 6, W, 12):
            put(x, y, x + 1, y + 6, C("aaa498"), 0.0)
    put(0, 548, W, 550, C("c9a845"), 0.0)
    put(0, 556, W, SURFACE_END, C("7d8589"), 0.0)
    put(0, 556, W, 557, C("aeb6b8"), 0.0)


def despeckle(top=0, bottom=SHORE):
    """Round 8: no lone bright texel above the waterline. A pixel brighter than
    all eight neighbours by > 40 (a facade sliver squeezed between a window
    and a shore-tree dot, a 1-px roof glint) reads as a floating white speck
    once scaled 2.6x; it takes the median colour of its neighbours instead.
    Intended highlights are runs/blocks (corner piers are 2 px wide) and are
    never isolated, so they are untouched."""
    rgb = img[top:bottom, :, :3].astype(np.int32)
    lum = rgb.mean(axis=2)
    # Compare with opaque neighbours only (sky is drawn live); a roof-corner
    # glint touching the sky still counts. Beacons are deliberate red lights.
    opaque = img[top:bottom, :, 3] > 0
    lum_n = np.where(opaque, lum, -1.0)
    h, w = lum.shape
    pad = np.pad(lum_n, 1, mode="edge")
    neigh = np.stack([pad[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
                      for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx])
    pad_o = np.pad(opaque, 1, mode="edge")
    n_opaque = sum(pad_o[1 + dy:1 + dy + h, 1 + dx:1 + dx + w].astype(int)
                   for dy in (-1, 0, 1) for dx in (-1, 0, 1) if dy or dx)
    lone = (lum - neigh.max(axis=0) > 40) & opaque & (n_opaque >= 3) & (win_class[top:bottom] != BEACON)
    lone[[0, -1], :] = False
    lone[:, [0, -1]] = False
    for y, x in zip(*np.nonzero(lone)):
        block = rgb[y - 1:y + 2, x - 1:x + 2].reshape(-1, 3)
        keep = np.delete(opaque[y - 1:y + 2, x - 1:x + 2].reshape(-1), 4)
        ring = np.delete(block, 4, axis=0)[keep]
        img[top + y, x, :3] = np.median(ring, axis=0).astype(np.uint8)
    return int(lone.sum())


def build():
    hills()
    far_towers()
    tencent(596)
    spring_bamboo(780)
    seg_plaza(940)
    ping_an(1110)
    stock_exchange(1222)
    kk100(1340)
    diwang(1470)
    near_layer()
    civic_centre(1000, 1230)
    bay_and_promenade()
    road_and_near_side()
    print(f"despeckled {despeckle()} lone bright texels")
    # The station below the slab is drawn by scripts/station.gd; keep the old
    # rows so anything peeking through stays identical.
    old = ROOT / "assets/layers/city-base.png"
    if old.exists():
        prev = np.asarray(Image.open(old).convert("RGBA"))
        if prev.shape == img.shape and prev[SURFACE_END:].any():
            img[SURFACE_END:] = prev[SURFACE_END:]
    else:
        img[SURFACE_END:] = (24, 32, 40, 255)
    sky[SURFACE_END - 200:] = np.where(img[SURFACE_END - 200:, :, 3] > 0, 0, sky[SURFACE_END - 200:])
    sky[SURFACE_END:] = 0
    img[sky > 0.5, 3] = 0
    out = ROOT / "assets/layers"
    Image.fromarray(img, "RGBA").save(out / "city-base.png", optimize=True)
    masks = np.stack([sky, water, depth, foliage], axis=2)
    Image.fromarray((masks * 255 + 0.5).astype(np.uint8), "RGBA").save(out / "city-masks.png", optimize=True)
    win = np.stack([win_class, (win_id >> 8).astype(np.uint8), (win_id & 255).astype(np.uint8), show], axis=2)
    Image.fromarray(win, "RGBA").save(out / "city-windows.png", optimize=True)
    colours = len(np.unique(img[:SURFACE_END].reshape(-1, 4)[:, :3], axis=0))
    print(f"windows {next_id[0] - 1}  beacons {(win_class == BEACON).sum()}  light-show px {(show > 0).sum()}")
    print(f"sky {sky[:SURFACE_END].mean():.1%}  surface colours {colours}")


def ascii_preview():
    ramp = {0: "#", 1: "S"}
    for y in range(40, SURFACE_END, 10):
        row = ""
        for x in range(0, W, 14):
            c = sky[y:y + 10, x:x + 14].mean()
            wc = win_class[y:y + 10, x:x + 14]
            if c > 0.5: ch = " "
            elif (wc == BEACON).any(): ch = "*"
            elif (show[y:y + 10, x:x + 14] > 0).mean() > 0.3: ch = "L"
            elif (wc == OFFICE).mean() > 0.25: ch = "o"
            elif (wc == HOME).mean() > 0.15: ch = "h"
            elif water[y:y + 10, x:x + 14].mean() > 0.5: ch = "~"
            elif foliage[y:y + 10, x:x + 14].mean() > 0.3: ch = "f"
            else: ch = "#"
            row += ch
        print(f"{y:3d} {row}")


if __name__ == "__main__":
    build()
    ascii_preview()
