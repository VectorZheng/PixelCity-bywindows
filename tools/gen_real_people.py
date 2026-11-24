"""Procedurally generate the "写实市民" (realistic citizens) cast.

No image model is involved: each figure is drawn limb by limb as pixel art with
realistic adult proportions (about 7.5 heads tall), an 8-frame side-view walk
cycle and everyday Shenzhen clothing chosen from the resident's profile in
scripts/profiles.gd (station staff uniform, gym kit, office shirt...).

Output, compatible with the anime sheets used by scripts/city.gd:
  assets/people-real/real-walk-{0..4}.png   8 frames x 4 characters each,
  cell 54x72 (drawn at 2 px per scene pixel), feet at y=68, hips at y=38.

Run from the project root:  python tools/gen_real_people.py
"""
from math import cos, sin, radians, pi
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
CELL_W, CELL_H, FRAMES = 54, 72, 8
FEET_Y, HIP_Y = 68, 38            # hip ratio 38/72 = 0.53 (city.gd REAL_HIP)
THIGH, SHIN = 15, 14
CX = 25                            # hip x inside the cell (figure faces right)

SKIN = [(238, 200, 170), (228, 186, 152), (214, 170, 136), (203, 158, 124)]
HAIR = {"black": (34, 30, 34), "dark": (58, 42, 36), "brown": (104, 70, 48), "grey": (128, 124, 122)}

def C(hex_):
    return tuple(int(hex_[i:i + 2], 16) for i in (0, 2, 4))

# One look per resident id (matches DATA order in scripts/profiles.gd).
LOOKS = [
    dict(hair="short", hc="black", skin=0, top="hoodie", tc=C("8d939b"), legs="pants", lc=C("3b5476"), shoes=C("e9e9e4"), bag="backpack", bagc=C("2f5d9a")),          # 大学生
    dict(hair="short", hc="black", skin=1, top="tee", tc=C("4a78a8"), legs="pants", lc=C("b49d7a"), shoes=C("3b3b40"), glasses=True, bag="backpack", bagc=C("2b2b30")), # 程序员
    dict(hair="bob", hc="dark", skin=0, top="blouse", tc=C("eeeae2"), legs="skirt", lc=C("2f3036"), shoes=C("2b2426"), bag="handbag", bagc=C("8a5a3c")),                # 会计
    dict(hair="bun", hc="dark", skin=1, top="cardigan", tc=C("d8c6a6"), legs="wide", lc=C("6b6f63"), shoes=C("f0ece4"), bag="tote", bagc=C("e6dcc6")),                  # 插画师
    dict(hair="short", hc="black", skin=2, top="polo", tc=C("2f4a3c"), legs="pants", lc=C("6c7078"), shoes=C("2c2c30"), glasses=True, lanyard=C("2b7fd0")),             # 硬件工程师
    dict(hair="ponytail", hc="black", skin=0, top="shirt", tc=C("dfe9f2"), legs="pants", lc=C("2e3a56"), shoes=C("3a2c2a"), bag="handbag", bagc=C("2d2d33")),           # 产品经理
    dict(hair="bob", hc="brown", skin=0, top="jacket", tc=C("5c7fa6"), legs="pants", lc=C("2e2f37"), shoes=C("e8e6e0"), camera=True),                                   # 摄影研究生
    dict(hair="messy", hc="black", skin=1, top="tee", tc=C("26262b"), legs="cargo", lc=C("6f6a52"), shoes=C("ecebe6"), headphones=True),                                # 游戏策划
    dict(hair="neat", hc="black", skin=1, top="vest", tc=C("2b3550"), inner=C("f2f2ee"), legs="pants", lc=C("252935"), shoes=C("1f1d22"), tie=C("a33a3a")),             # 银行柜员
    dict(hair="ponytail", hc="dark", skin=2, top="tee", tc=C("f1eee6"), apron=C("7a5136"), legs="pants", lc=C("2d2c31"), shoes=C("3a2f2b")),                             # 咖啡店店长
    dict(hair="neat", hc="black", skin=0, top="suit", tc=C("27304a"), inner=C("eef0f2"), legs="pants", lc=C("27304a"), shoes=C("1b1a1f"), bag="briefcase", bagc=C("3a2a22")), # 律所助理
    dict(hair="long", hc="black", skin=0, top="turtleneck", tc=C("1f1f24"), legs="skirt_long", lc=C("cfc4ae"), shoes=C("2a2627")),                                     # 设计师
    dict(hair="buzz", hc="black", skin=3, top="tee", tc=C("c8463e"), legs="shorts", lc=C("1f2026"), shoes=C("f2f2f2"), socks=True),                                     # 健身教练
    dict(hair="long", hc="brown", skin=0, top="blouse", tc=C("e6b3bd"), legs="pants", lc=C("ecebe6"), shoes=C("c9a58a"), bag="handbag", bagc=C("f0e6d8")),             # 市场专员
    dict(hair="neat", hc="black", skin=2, top="uniform", tc=C("2f4f86"), inner=C("d8e8f6"), legs="pants", lc=C("2a3658"), shoes=C("1c1c22"), cap=C("2f4f86"), badge=C("00a2e2")), # 站务员
    dict(hair="ponytail", hc="dark", skin=1, top="polo", tc=C("2f9a6a"), legs="pants", lc=C("26262c"), shoes=C("2c2c30")),                                              # 便利店店员
    dict(hair="short", hc="dark", skin=2, top="jacket", tc=C("6d7076"), legs="pants", lc=C("3c4e6e"), shoes=C("4a3a2e"), bag="sling", bagc=C("2a2a2e")),                # 采购
    dict(hair="short", hc="black", skin=1, top="shirt", tc=C("bcd6ee"), legs="pants", lc=C("2b2f3a"), shoes=C("1f1e22"), badge=C("00a2e2")),                           # 调度实习生
    dict(hair="grey", hc="grey", skin=2, top="jacket", tc=C("7b5d4a"), legs="pants", lc=C("4b4b52"), shoes=C("2a2522")),                                                # spare
    dict(hair="long", hc="dark", skin=1, top="tee", tc=C("f2d66b"), legs="pants", lc=C("3a4a6a"), shoes=C("ecebe6")),                                                    # spare
]

def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)

def limb(d, a, b, width, colour):
    d.line([a, b], fill=colour, width=width)
    r = width / 2 - 0.5
    for p in (a, b):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=colour)

def leg(d, hip, thigh_deg, knee_deg, colour, shoe, look, near):
    t = radians(thigh_deg)
    knee = (hip[0] + sin(t) * THIGH, hip[1] + cos(t) * THIGH)
    s = radians(thigh_deg - knee_deg)
    ankle = (knee[0] + sin(s) * SHIN, knee[1] + cos(s) * SHIN)
    upper = colour
    lower = look["skin_c"] if look["legs"] == "shorts" else colour
    if look["legs"] in ("skirt", "skirt_long"):
        upper = lower = look["skin_c"] if look["legs"] == "skirt" else colour
    w = 6 if look["legs"] in ("wide", "cargo") else 5
    limb(d, hip, knee, w, upper)
    limb(d, knee, ankle, w - 1, lower)
    if look.get("socks"):
        limb(d, (ankle[0] + (knee[0] - ankle[0]) * 0.18, ankle[1] + (knee[1] - ankle[1]) * 0.18), ankle, 4, (238, 238, 236))
    # Shoe: a short wedge pointing forward, flat when on the ground.
    toe = (ankle[0] + 5, ankle[1] + 1.5)
    d.polygon([(ankle[0] - 2.5, ankle[1] - 1.5), (ankle[0] + 1.5, ankle[1] - 1.5), (toe[0], toe[1] - 1), (toe[0], toe[1] + 1), (ankle[0] - 2.5, ankle[1] + 1.5)], fill=shoe)
    return ankle

def arm(d, shoulder, deg, elbow_deg, colour, skin, look):
    a = radians(deg)
    elbow = (shoulder[0] + sin(a) * 10, shoulder[1] + cos(a) * 10)
    b = radians(deg + elbow_deg)
    hand = (elbow[0] + sin(b) * 9, elbow[1] + cos(b) * 9)
    sleeve_short = look["top"] in ("tee", "polo")
    limb(d, shoulder, elbow, 4, colour)
    limb(d, elbow, hand, 4 if not sleeve_short else 3, skin if sleeve_short else colour)
    d.ellipse([hand[0] - 1.5, hand[1] - 1.5, hand[0] + 1.5, hand[1] + 1.5], fill=skin)
    return hand

def head(d, cx, top, look):
    skin, hair = look["skin_c"], HAIR[look["hc"]]
    style = look["hair"]
    # Long hair falls behind the neck first.
    if style == "long":
        d.rectangle([cx - 5, top + 4, cx - 1, top + 17], fill=hair)
    d.ellipse([cx - 4.5, top, cx + 4.5, top + 9.5], fill=skin)            # skull/face
    d.rectangle([cx - 1, top + 9, cx + 1.5, top + 11], fill=shade(skin, 0.9))  # neck
    d.point([(cx + 5, top + 5)], fill=skin)                                   # nose
    d.point([(cx + 2.5, top + 4)], fill=(36, 30, 34))                         # eye
    d.point([(cx + 3, top + 7.5)], fill=shade(skin, 0.75))                    # mouth
    if style in ("short", "neat", "messy", "grey"):
        d.chord([cx - 4.8, top - 0.8, cx + 4.6, top + 7], 180, 360, fill=hair)
        d.rectangle([cx - 4.8, top + 2, cx - 1.5, top + 6], fill=hair)
        if style == "messy":
            d.point([(cx - 2, top - 1.5), (cx + 1, top - 1.5), (cx + 3, top - 1)], fill=hair)
    elif style == "buzz":
        d.chord([cx - 4.6, top - 0.2, cx + 4.4, top + 5], 180, 360, fill=shade(hair, 1.4))
    elif style in ("bob", "long", "ponytail", "bun"):
        d.chord([cx - 5, top - 1, cx + 4.8, top + 7.5], 180, 360, fill=hair)
        d.rectangle([cx - 5, top + 2, cx - 1, top + (9 if style == "bob" else 6)], fill=hair)
        if style == "ponytail":
            d.polygon([(cx - 5, top + 2), (cx - 8, top + 4), (cx - 7.5, top + 10), (cx - 5, top + 6)], fill=hair)
        if style == "bun":
            d.ellipse([cx - 7, top - 1.5, cx - 2.5, top + 3], fill=hair)
    if look.get("glasses"):
        d.rectangle([cx + 1.5, top + 3.5, cx + 4.5, top + 4.5], fill=(40, 40, 46))
    if look.get("cap"):
        d.chord([cx - 4.8, top - 1.5, cx + 4.8, top + 5], 180, 360, fill=look["cap"])
        d.rectangle([cx + 2, top + 1.5, cx + 7, top + 2.5], fill=shade(look["cap"], 0.7))
    if look.get("headphones"):
        d.arc([cx - 5.5, top + 7, cx + 3.5, top + 14], 20, 200, fill=(30, 30, 34), width=1)

def torso(d, cx, shoulder_y, hip_y, look, phase):
    c = look["tc"]
    top = look["top"]
    back, front = cx - 4.5, cx + 4.5
    pts = [(back, shoulder_y), (front - 0.5, shoulder_y), (front + 0.5, shoulder_y + 6), (front, hip_y - 1), (back + 0.5, hip_y - 1)]
    if top in ("hoodie", "jacket", "suit", "uniform", "cardigan"):
        pts = [(back - 0.5, shoulder_y), (front, shoulder_y), (front + 1, shoulder_y + 6), (front + 0.8, hip_y + 2), (back, hip_y + 2)]
    d.polygon(pts, fill=c)
    d.rectangle([back, shoulder_y + 1, back + 1.5, hip_y - 1], fill=shade(c, 0.78))           # back shading
    if look.get("inner"):
        d.polygon([(front - 2, shoulder_y), (front, shoulder_y), (front + 0.5, shoulder_y + 6)], fill=look["inner"])
    if look.get("tie"):
        d.line([(front - 0.5, shoulder_y + 1), (front, shoulder_y + 9)], fill=look["tie"], width=1)
    if top == "hoodie":
        d.polygon([(back - 1, shoulder_y - 1), (back + 3, shoulder_y - 3), (back + 3, shoulder_y + 2)], fill=shade(c, 0.9))
    if look.get("apron"):
        d.rectangle([front - 2, shoulder_y + 5, front + 1.5, hip_y + 7], fill=look["apron"])
    if look.get("lanyard"):
        d.line([(cx + 1, shoulder_y), (front, shoulder_y + 8)], fill=look["lanyard"], width=1)
        d.rectangle([front - 1, shoulder_y + 8, front + 1, shoulder_y + 11], fill=(240, 240, 240))
    if look.get("badge"):
        d.rectangle([front - 2, shoulder_y + 4, front, shoulder_y + 6], fill=look["badge"])
    if look.get("camera"):
        d.line([(back + 1, shoulder_y), (front, hip_y - 4)], fill=(30, 30, 30), width=1)
        d.rectangle([front - 1, hip_y - 6, front + 2.5, hip_y - 3], fill=(28, 28, 30))
    # Belt line / hem.
    d.line([(back + 0.5, hip_y - 1), (front, hip_y - 1)], fill=shade(c, 0.7), width=1)

def lower_garment(d, cx, hip_y, look):
    if look["legs"] == "skirt":
        d.polygon([(cx - 5, hip_y - 2), (cx + 4.5, hip_y - 2), (cx + 6.5, hip_y + 10), (cx - 6.5, hip_y + 10)], fill=look["lc"])
    if look["legs"] == "skirt_long":
        d.polygon([(cx - 5, hip_y - 2), (cx + 4.5, hip_y - 2), (cx + 8, hip_y + 22), (cx - 8, hip_y + 22)], fill=look["lc"])
    if look["legs"] == "shorts":
        d.polygon([(cx - 5, hip_y - 2), (cx + 4.5, hip_y - 2), (cx + 5.5, hip_y + 8), (cx - 5.5, hip_y + 8)], fill=look["lc"])

def bag(d, cx, shoulder_y, hip_y, look, hand_far):
    kind, c = look.get("bag"), look.get("bagc", (40, 40, 40))
    if kind == "backpack":
        d.rounded_rectangle([cx - 10, shoulder_y + 1, cx - 3.5, hip_y - 2], radius=2, fill=c)
        d.line([(cx - 4, shoulder_y + 1), (cx + 2, shoulder_y + 7)], fill=shade(c, 0.7), width=1)
    elif kind == "sling":
        d.line([(cx - 3, shoulder_y), (cx + 4, hip_y - 6)], fill=c, width=1)
        d.rectangle([cx - 7, hip_y - 6, cx - 3, hip_y - 2], fill=c)
    elif kind in ("handbag", "tote", "briefcase"):
        x, y = hand_far
        if kind == "tote":
            d.rectangle([x - 3, y, x + 3, y + 7], fill=c)
            d.line([(x - 2, y), (x, y - 3), (x + 2, y)], fill=shade(c, 0.6), width=1)
        elif kind == "briefcase":
            d.rectangle([x - 4, y + 1, x + 4, y + 6], fill=c)
        else:
            d.rounded_rectangle([x - 3, y, x + 3, y + 5], radius=1, fill=c)

def outline(img):
    """1px selective outline: transparent pixels next to the figure take a dark
    version of their neighbour's colour, which reads cleaner than flat black."""
    a = np.asarray(img).astype(np.int32)
    alpha = a[..., 3] > 0
    out = a.copy()
    h, w = alpha.shape
    for y in range(h):
        for x in range(w):
            if alpha[y, x]: continue
            best = None
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and alpha[yy, xx]:
                    c = a[yy, xx, :3]
                    if best is None or c.sum() < best.sum(): best = c
            if best is not None:
                out[y, x, :3] = (best * 0.35 + np.array([20, 18, 26]) * 0.65).astype(np.int32)
                out[y, x, 3] = 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")

def frame(look, f, stand=False):
    """One walk frame, or (stand=True) upright with both feet together."""
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = 2 * pi * f / FRAMES
    amp = 17.0
    thigh_a, thigh_b = amp * cos(p), -amp * cos(p)
    knee_a = 6 + 34 * max(0.0, -sin(p))      # leg A bends while swinging forward
    knee_b = 6 + 34 * max(0.0, sin(p))
    bob = -1.2 * (1 - abs(cos(p)))           # body rises when the legs pass
    if stand:
        p = pi / 2
        thigh_a, thigh_b, knee_a, knee_b, bob = 1.5, -1.5, 3.0, 3.0, 0.0
    hip = (CX, HIP_Y + bob)
    shoulder_y = hip[1] - 21
    head_top = shoulder_y - 12
    skin = look["skin_c"]
    # Far side first (darker), then torso, then near side.
    arm(d, (CX - 0.5, shoulder_y + 2), -0.8 * thigh_b, -14, shade(look["tc"], 0.72), shade(skin, 0.85), look)
    leg(d, (hip[0] - 0.5, hip[1]), thigh_b, knee_b, shade(look["lc"], 0.72), shade(look["shoes"], 0.75), look, False)
    if look.get("bag") == "backpack": bag(d, CX, shoulder_y, hip[1], look, None)
    leg(d, hip, thigh_a, knee_a, look["lc"], look["shoes"], look, True)
    lower_garment(d, CX, hip[1], look)
    torso(d, CX, shoulder_y, hip[1], look, p)
    if look.get("bag") == "sling": bag(d, CX, shoulder_y, hip[1], look, None)
    head(d, CX + 0.5, head_top, look)
    hand = arm(d, (CX + 0.5, shoulder_y + 2), -0.8 * thigh_a, -16, look["tc"], skin, look)
    if look.get("bag") in ("handbag", "tote", "briefcase"): bag(d, CX, shoulder_y, hip[1], look, hand)
    return outline(img)

def build():
    out = ROOT / "assets" / "people-real"
    out.mkdir(parents=True, exist_ok=True)
    for sheet in range(5):
        img = Image.new("RGBA", (CELL_W * FRAMES, CELL_H * 4), (0, 0, 0, 0))
        for row in range(4):
            look = dict(LOOKS[sheet * 4 + row])
            look["skin_c"] = SKIN[look["skin"]]
            for f in range(FRAMES):
                img.paste(frame(look, f), (f * CELL_W, row * CELL_H))
        img.save(out / f"real-walk-{sheet}.png", optimize=True)
        print("wrote", out / f"real-walk-{sheet}.png")
        # Standing pose sheet: one column, same rows and cell size.
        stand = Image.new("RGBA", (CELL_W, CELL_H * 4), (0, 0, 0, 0))
        for row in range(4):
            look = dict(LOOKS[sheet * 4 + row])
            look["skin_c"] = SKIN[look["skin"]]
            stand.paste(frame(look, 0, stand=True), (0, row * CELL_H))
        stand.save(out / f"real-stand-{sheet}.png", optimize=True)

if __name__ == "__main__":
    build()
