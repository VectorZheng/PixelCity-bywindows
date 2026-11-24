"""Generate vehicle sprites for the Shenzhen street.

  assets/vehicles/taxi-blue.png        su7-yellow.png repainted Shenzhen e-taxi sky blue
  assets/vehicles/car-white.png        private-car variants (same canvas / alignment)
  assets/vehicles/car-black.png
  assets/vehicles/car-silver.png
  assets/vehicles/delivery-scooter.png pixel-art e-scooter riders, 2 rows x 4 frames,
                                       cell 64x52 (2 px per scene pixel), wheels touch y=50
                                       row 0 = 美团 (yellow), row 1 = 饿了么 (blue)
  assets/vehicles/vehicles.json        file / canvas / source-rect / cell metadata

Recolour: only the yellow body paint (hue 30-62 deg, saturation > 0.3, value > 0.12,
outside the two wheel disks so the yellow brake calipers stay) is replaced. Shading is
carried by luminance relative to the body median: darker -> base colour scaled down,
brighter -> blended toward the variant's highlight colour. Low-saturation edge pixels
(saturation 0.15-0.3) are blended softly. Alpha is untouched.

Run from the project root:  python tools/gen_vehicles.py
"""
import json
import sys
sys.dont_write_bytecode = True
from math import cos, sin, radians
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_real_people import C, shade, limb, outline, SKIN

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "vehicles"
SRC = ROOT / "assets" / "su7-yellow.png"
CAR_RECT = [33, 49, 2106, 654]          # x, y, w, h of the car inside the canvas
WHEELS = [(450, 530), (1750, 530)]      # wheel centres (px) in su7-yellow.png
WHEEL_R = 150

# name: (base colour, highlight colour, shading contrast)
PAINTS = {
    "taxi-blue": (C("2E9FE6"), C("e8f6ff"), 1.0),
    "car-white": (C("eceef0"), C("ffffff"), 0.55),
    "car-black": (C("212328"), C("a8b0bc"), 1.0),
    "car-silver": (C("b4b8be"), C("f2f4f7"), 0.8),
}


def hsv(rgb):
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def paint_mask(arr):
    rgb, a = arr[..., :3] / 255.0, arr[..., 3]
    h, s, v = hsv(rgb)
    hue_ok = (h > 30) & (h < 62) & (v > 0.12) & (a > 0)
    yy, xx = np.mgrid[0:arr.shape[0], 0:arr.shape[1]]
    for cx, cy in WHEELS:
        hue_ok &= (xx - cx) ** 2 + (yy - cy) ** 2 > WHEEL_R ** 2
    w = np.clip((s - 0.15) / 0.15, 0, 1) * hue_ok
    return w, s, h


def recolour(arr, base, hi, contrast, w):
    rgb = arr[..., :3].astype(np.float64) / 255.0
    L = rgb @ np.array([0.299, 0.587, 0.114])
    core = w >= 1
    lmed = np.percentile(L[core], 75)          # reference = typical lit panel
    lmax = np.percentile(L[core], 99.5)
    k = L / lmed
    base_f = np.array(base) / 255.0
    hi_f = np.array(hi) / 255.0
    dark = 1 - (1 - np.minimum(k, 1)) * contrast
    t = np.clip((k - 1) / max(lmax / lmed - 1, 1e-6), 0, 1)[..., None] ** 2   # only true highlights brighten
    new = np.where((k <= 1)[..., None], base_f * dark[..., None], base_f + (hi_f - base_f) * t * 0.85)
    out = rgb * (1 - w[..., None]) + new * w[..., None]
    res = arr.copy()
    res[..., :3] = np.clip(np.round(out * 255), 0, 255).astype(np.uint8)
    return res


def hue_hist(arr, title):
    rgb, a = arr[..., :3] / 255.0, arr[..., 3]
    h, s, v = hsv(rgb)
    sel = (a > 0) & (s > 0.15) & (v > 0.12)
    hist, _ = np.histogram(h[sel], bins=12, range=(0, 360))
    tot = max(1, sel.sum())
    print(f"  {title:18s} sat>0.15 px={sel.sum():7d} | " + " ".join(f"{i*30:3d}:{100*n/tot:4.1f}%" for i, n in enumerate(hist)))


def build_cars():
    src = np.asarray(Image.open(SRC).convert("RGBA"))
    w, s, h = paint_mask(src)
    opaque = (src[..., 3] > 0).sum()
    stats = {"opaque_px": int(opaque), "recoloured_px": int((w > 0).sum()),
             "fully_recoloured_px": int((w >= 1).sum())}
    stats["fraction"] = round(stats["recoloured_px"] / opaque, 4)
    print(f"recolour mask: {stats['recoloured_px']} / {opaque} opaque px = {100*stats['fraction']:.1f}% "
          f"({stats['fully_recoloured_px']} at full weight)")
    hue_hist(src, "su7-yellow (src)")
    for name, (base, hi, contrast) in PAINTS.items():
        res = recolour(src, base, hi, contrast, w)
        Image.fromarray(res, "RGBA").save(OUT / f"{name}.png", optimize=True)
        hue_hist(res, name)
        assert (res[..., 3] == src[..., 3]).all()
    return stats


# ---------------------------------------------------------------- scooter
SC_W, SC_H, SC_FRAMES = 64, 52, 4
BRANDS = [("meituan", C("FFD100")), ("eleme", C("0A8CFF"))]


def wheel(d, cx, cy, ang):
    d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=C("26262b"))
    d.ellipse([cx - 3.5, cy - 3.5, cx + 3.5, cy + 3.5], fill=C("8c9098"))
    d.ellipse([cx - 1.5, cy - 1.5, cx + 1.5, cy + 1.5], fill=C("4a4d55"))
    for k in (0, 120, 240):  # three spokes, rotating with the frame
        a = radians(ang + k)
        d.point([(round(cx + cos(a) * 2.6), round(cy + sin(a) * 2.6))], fill=C("d8dade"))


def scooter_frame(colour, f):
    img = Image.new("RGBA", (SC_W, SC_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bob = (0, 1, 0, 0)[f]
    ang = f * 30
    body, trim = C("4a5262"), C("8a93a3")
    skin = SKIN[2]
    pants, shoe = C("2a2b30"), C("1e1e22")
    box_c = colour
    # Wheels (cy=43, radius 6 -> fill bottom y=49, outline pixel at y=50).
    wheel(d, 13, 43, ang)
    wheel(d, 51, 43, ang)
    # Rear body / swing arm over the rear wheel, floorboard, leg shield, stem.
    d.polygon([(5, 32), (26, 31), (28, 37), (22, 40), (8, 39), (4, 36)], fill=body)
    d.rectangle([7, 34, 25, 35], fill=trim)
    d.rectangle([20, 39, 42, 42], fill=shade(body, 0.85))                 # floorboard
    d.polygon([(38, 42), (43, 42), (47, 22), (43, 21)], fill=body)          # leg shield
    d.line([(46, 21), (51, 43)], fill=C("6c7280"), width=2)                 # front fork
    d.polygon([(44, 21), (49, 20), (50, 25), (46, 27)], fill=shade(body, 1.15))  # headlight cowl
    d.rectangle([49, 22, 50, 24], fill=C("fff4c0"))                         # headlight
    d.rectangle([3, 31, 5, 33], fill=C("d23c3c"))                           # tail light
    d.line([(44, 18 + bob * 0), (47, 19)], fill=C("2a2a2e"), width=2)       # handlebar grip
    d.rectangle([12, 28, 27, 31], fill=C("2a2a30"))                         # seat
    # Rear rack + insulated food box.
    d.rectangle([2, 30, 15, 31], fill=C("3a3c42"))
    d.rectangle([1, 11, 16, 29], fill=box_c)
    d.rectangle([1, 11, 16, 13], fill=shade(box_c, 0.78))                  # lid
    d.rectangle([1, 27, 16, 29], fill=shade(box_c, 0.82))                  # base seam
    d.rectangle([4, 17, 12, 22], fill=C("f6f6f2") if colour[2] > 200 else C("2a2a2e"))  # logo patch
    d.rectangle([14, 14, 15, 26], fill=shade(box_c, 0.86))                 # side shading
    # Rider.
    hip = (22, 27 + bob)
    knee = (33, 27 + bob)
    foot = (35 + (f % 2) * 0.5, 38)
    sh = (25, 14 + bob)
    limb(d, hip, knee, 6, pants)                                            # thigh
    limb(d, knee, foot, 5, pants)                                           # shin
    d.polygon([(foot[0] - 2, foot[1] - 1), (foot[0] + 4, foot[1]), (foot[0] + 4, foot[1] + 2), (foot[0] - 2, foot[1] + 2)], fill=shoe)
    d.polygon([(hip[0] - 4, hip[1] + 1), (hip[0] + 4, hip[1] + 2), (sh[0] + 5, sh[1]), (sh[0] - 4, sh[1] - 1)], fill=colour)  # torso
    d.rectangle([hip[0] - 3, sh[1] + 8, sh[0] + 3, sh[1] + 9], fill=C("c9ccd2"))           # reflective band
    d.line([(hip[0] - 3, hip[1] - 1), (hip[0] + 3, hip[1])], fill=shade(colour, 0.7), width=1)  # hem
    # Head + helmet.
    hx, ht = sh[0] + 2, sh[1] - 11
    d.ellipse([hx - 4.5, ht, hx + 4.5, ht + 9.5], fill=skin)
    d.rectangle([hx - 1, ht + 9, hx + 1.5, ht + 11], fill=shade(skin, 0.9))
    d.point([(hx + 5, ht + 5)], fill=skin)
    d.chord([hx - 5.8, ht - 2.2, hx + 5.4, ht + 8.5], 160, 380, fill=colour)
    d.rectangle([hx - 5.6, ht + 2, hx - 2, ht + 6.5], fill=colour)
    d.rectangle([hx + 1.5, ht + 2.5, hx + 5.5, ht + 4.5], fill=C("2a3038"))
    d.line([(hx - 4, ht - 1), (hx + 2, ht - 1.5)], fill=shade(colour, 1.12), width=1)
    # Arm to the handlebar.
    elbow = (34, 20 + bob)
    limb(d, (sh[0] + 1, sh[1] + 2), elbow, 4, shade(colour, 0.92))
    limb(d, elbow, (44, 18), 4, shade(colour, 0.92))
    d.ellipse([43, 16.5, 46, 19.5], fill=C("2a2a2e"))                       # glove on grip
    return outline(img)


def build_scooter():
    sheet = Image.new("RGBA", (SC_W * SC_FRAMES, SC_H * len(BRANDS)), (0, 0, 0, 0))
    frames = {}
    for row, (_, col) in enumerate(BRANDS):
        for f in range(SC_FRAMES):
            fr = scooter_frame(col, f)
            frames[(row, f)] = fr
            sheet.paste(fr, (f * SC_W, row * SC_H))
    sheet.save(OUT / "delivery-scooter.png", optimize=True)
    return frames


RAMP = " .:-=+*#%@"


def ascii_img(img):
    px = img.load()
    lines = []
    for y in range(img.size[1]):
        s = ""
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            s += " " if a == 0 else RAMP[1 + min(8, int((0.299 * r + 0.587 * g + 0.114 * b) / 255 * 9))]
        lines.append(s.rstrip())
    return "\n".join(lines)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    stats = build_cars()
    frames = build_scooter()
    sw, sh_ = Image.open(SRC).size
    meta = {
        "scale_note": "cars share su7-yellow.png canvas/alignment; scooter drawn at 2 px per scene pixel",
        "recolour_stats": stats,
        "files": [],
    }
    for name, (base, _, _) in PAINTS.items():
        meta["files"].append({
            "file": f"assets/vehicles/{name}.png", "kind": "taxi" if name.startswith("taxi") else "car",
            "canvas": [sw, sh_], "source_rect": CAR_RECT, "faces": "right",
            "base_colour": "#%02X%02X%02X" % base, "derived_from": "assets/su7-yellow.png",
        })
    meta["files"].append({
        "file": "assets/vehicles/delivery-scooter.png", "kind": "delivery_scooter",
        "canvas": [SC_W * SC_FRAMES, SC_H * len(BRANDS)], "faces": "right",
        "cell": [SC_W, SC_H], "frames": SC_FRAMES, "rows": [b for b, _ in BRANDS],
        "wheel_ground_y": 50, "px_per_scene_px": 2,
        "source_rect": [0, 0, SC_W * SC_FRAMES, SC_H * len(BRANDS)],
    })
    (OUT / "vehicles.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    if "--ascii" in sys.argv:
        for row in range(len(BRANDS)):
            print(f"--- scooter row {row} ({BRANDS[row][0]}) frame 0")
            print(ascii_img(frames[(row, 0)]))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
