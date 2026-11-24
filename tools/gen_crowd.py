"""Procedurally generate the background crowd (路人) for the Shenzhen street.

Reuses the limb/head/torso/outline helpers of tools/gen_real_people.py and adds
crowd-only options: track-suit stripes, helmets, coffee cup / phone in hand,
laptop messenger bags, big school backpacks, food-delivery bags, a hunched
slow gait for elderly walkers.

Output (same layout as real-walk-*.png, figure faces RIGHT):
  assets/people-real/crowd-walk-{0..3}.png  8 frames x 4 characters, cell 54x72,
  feet at y=68, hips at y=38 (2 px per scene pixel)
  assets/people-real/crowd.json             [{sheet,row,kind,desc}] x 16

Run from the project root:  python tools/gen_crowd.py   (--ascii to preview)
"""
import json
import sys
sys.dont_write_bytecode = True
from math import cos, sin, radians, pi
from pathlib import Path
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_real_people as G
from gen_real_people import (C, shade, limb, leg, arm, head, torso, lower_garment, bag,
                             outline, SKIN, CELL_W, CELL_H, FRAMES, HIP_Y, THIGH, SHIN, CX)

ROOT = Path(__file__).resolve().parents[1]
WHITE = C("f4f4f2")
ROYAL = C("2350c0")
MEITUAN = C("FFD100")

# kind, desc, look.  Extra keys understood here (besides gen_real_people's):
#   sleeve=colour   long sleeves in another colour (track jacket)
#   pant_stripe=colour  side stripe along the legs
#   zip=True        front zip line + coloured collar (collar=colour)
#   pencil=True     straight knee-length skirt (use legs="skirt")
#   hold="coffee"|"phone"   near hand raised holding a cup / phone
#   bag="laptop"|"bigpack"|"foodbag"
#   helmet=colour   rider helmet with dark visor
#   reflect=True    reflective band across jacket
#   amp / hunch     stride amplitude / forward head offset (elderly)
CROWD = [
    ("commuter", "白衬衫男白领，深色西裤，蓝色工牌挂绳，黑双肩包",
     dict(hair="short", hc="black", skin=1, top="shirt", tc=C("f2f3f1"), legs="pants", lc=C("272c38"), shoes=C("201d20"),
          lanyard=C("2b7fd0"), bag="backpack", bagc=C("26272c"))),
    ("commuter", "浅蓝衬衫女白领，深灰铅笔裙，长发，手拿咖啡",
     dict(hair="long", hc="dark", skin=0, top="shirt", tc=C("cfe2f4"), legs="skirt", pencil=True, lc=C("3a3c44"), shoes=C("231e22"),
          hold="coffee", lanyard=C("d23c3c"))),
    ("commuter", "藏青西装男，白衬衫，戴眼镜，斜挎电脑包",
     dict(hair="neat", hc="black", skin=2, top="suit", tc=C("26304c"), inner=C("eef0f2"), legs="pants", lc=C("232838"), shoes=C("1b1a1f"),
          glasses=True, bag="laptop", bagc=C("5a5c63"))),
    ("commuter", "深灰西装外套女，白内搭黑裤，马尾，边走边看手机",
     dict(hair="ponytail", hc="black", skin=1, top="suit", tc=C("4a4d55"), inner=C("f4f4f2"), legs="pants", lc=C("1f2026"), shoes=C("2a2224"),
          hold="phone")),
    ("commuter", "浅蓝衬衫男，炭灰裤，电脑包，手拿咖啡",
     dict(hair="messy", hc="dark", skin=0, top="shirt", tc=C("b9d4ee"), legs="pants", lc=C("3a3d45"), shoes=C("3a2c26"),
          hold="coffee", bag="laptop", bagc=C("4a3a2c"))),
    ("commuter", "白衬衫女，黑色铅笔裙，短发波波头，工牌，手提包",
     dict(hair="bob", hc="black", skin=0, top="blouse", tc=C("f2f1ec"), legs="skirt", pencil=True, lc=C("1e1e24"), shoes=C("1e1a1c"),
          badge=C("00a2e2"), bag="handbag", bagc=C("6a4630"))),
    ("commuter", "浅蓝衬衫男程序员，戴眼镜，灰双肩包，看手机",
     dict(hair="short", hc="black", skin=2, top="shirt", tc=C("c6dcf0"), legs="pants", lc=C("2e3442"), shoes=C("e6e6e2"),
          glasses=True, lanyard=C("2b7fd0"), bag="backpack", bagc=C("7a7e86"), hold="phone")),
    ("commuter", "黑西装外套女，浅蓝内搭，盘发，斜挎电脑包",
     dict(hair="bun", hc="dark", skin=1, top="suit", tc=C("1f2128"), inner=C("cfe2f4"), legs="pants", lc=C("24262e"), shoes=C("201c1e"),
          bag="laptop", bagc=C("8a6a52"))),
    ("student", "深圳校服男生，白色拉链运动上衣宝蓝袖，蓝运动裤白边，大书包",
     dict(hair="short", hc="black", skin=1, top="jacket", tc=WHITE, sleeve=ROYAL, zip=True, collar=ROYAL, legs="pants", lc=ROYAL,
          pant_stripe=WHITE, shoes=C("f6f6f4"), bag="bigpack", bagc=C("1f2a44"))),
    ("student", "深圳校服女生，马尾，白蓝校服运动套装，大书包",
     dict(hair="ponytail", hc="black", skin=0, top="jacket", tc=WHITE, sleeve=ROYAL, zip=True, collar=ROYAL, legs="pants", lc=ROYAL,
          pant_stripe=WHITE, shoes=C("f6f6f4"), bag="bigpack", bagc=C("d98aa0"))),
    ("student", "深圳校服男生，短发，白蓝校服，灰色大书包，看手机",
     dict(hair="messy", hc="black", skin=2, top="jacket", tc=WHITE, sleeve=ROYAL, zip=True, collar=ROYAL, legs="pants", lc=ROYAL,
          pant_stripe=WHITE, shoes=C("f6f6f4"), bag="bigpack", bagc=C("6c7078"), hold="phone")),
    ("student", "深圳校服女生，马尾，白蓝校服，藏青大书包",
     dict(hair="ponytail", hc="dark", skin=1, top="jacket", tc=WHITE, sleeve=ROYAL, zip=True, collar=ROYAL, legs="pants", lc=ROYAL,
          pant_stripe=WHITE, shoes=C("f6f6f4"), bag="bigpack", bagc=C("2c3e6e"))),
    ("night", "美团外卖骑手（步行），黄色外套和头盔，反光条，提保温外卖袋",
     dict(hair="short", hc="black", skin=3, top="jacket", tc=MEITUAN, reflect=True, helmet=MEITUAN, legs="pants", lc=C("2a2b30"),
          shoes=C("2a2a2e"), bag="foodbag", bagc=MEITUAN)),
    ("night", "夜班工人，深色连帽卫衣，深色裤子，斜挎包",
     dict(hair="short", hc="black", skin=2, top="hoodie", tc=C("2c2f37"), legs="pants", lc=C("3a3c42"), shoes=C("4a4a50"),
          bag="sling", bagc=C("1c1c20"), headphones=True)),
    ("other", "白发老人，微驼背慢步，咖色夹克灰裤",
     dict(hair="grey", hc="grey", skin=3, top="jacket", tc=C("8a7660"), legs="pants", lc=C("5a5a60"), shoes=C("2a2522"),
          amp=10.5, hunch=2)),
    ("other", "运动装路人，珊瑚色速干T恤，黑色运动短裤，白跑鞋",
     dict(hair="ponytail", hc="brown", skin=1, top="tee", tc=C("f0705a"), legs="shorts", lc=C("1f2026"), shoes=C("f2f2f2"), socks=True)),
]


def joints(hip, thigh_deg, knee_deg):
    t = radians(thigh_deg)
    knee = (hip[0] + sin(t) * THIGH, hip[1] + cos(t) * THIGH)
    s = radians(thigh_deg - knee_deg)
    return knee, (knee[0] + sin(s) * SHIN, knee[1] + cos(s) * SHIN)


def leg2(d, hip, thigh_deg, knee_deg, colour, shoe, look, near):
    ankle = leg(d, hip, thigh_deg, knee_deg, colour, shoe, look, near)
    if look.get("pant_stripe"):
        knee, ankle = joints(hip, thigh_deg, knee_deg)
        sc = look["pant_stripe"] if near else shade(look["pant_stripe"], 0.78)
        d.line([(hip[0], hip[1] + 1), knee, (ankle[0], ankle[1] - 2)], fill=sc, width=1)
    return ankle


def arm2(d, shoulder, deg, elbow_deg, colour, skin, look):
    return arm(d, shoulder, deg, elbow_deg, colour, skin, look)


def big_pack(d, cx, sy, hy, c):
    d.rounded_rectangle([cx - 13, sy, cx - 3.5, hy + 1], radius=3, fill=c)
    d.rectangle([cx - 13, sy + 9, cx - 11.5, hy - 1], fill=shade(c, 0.72))       # side pocket
    d.line([(cx - 10, sy - 1), (cx - 7, sy - 1)], fill=shade(c, 0.6), width=1)   # top handle
    d.line([(cx - 12, sy + 6), (cx - 5, sy + 6)], fill=shade(c, 1.25), width=1)  # zip seam


def crowd_torso_extras(d, cx, sy, hy, look):
    c = look["tc"]
    front = cx + 4.5
    if look.get("zip"):
        d.line([(front - 0.5, sy + 2), (front, hy + 1)], fill=shade(c, 0.72), width=1)
        d.rectangle([cx - 2, sy - 1, cx + 3.5, sy], fill=look.get("collar", shade(c, 0.8)))
        d.rectangle([cx - 4, hy, front, hy + 1.5], fill=look.get("collar", shade(c, 0.8)))   # cuffed hem
    if look.get("reflect"):
        d.rectangle([cx - 4.5, sy + 10, front + 0.5, sy + 11], fill=C("c9ccd2"))
    if look.get("hunch"):
        d.ellipse([cx - 6.5, sy - 1.5, cx + 1, sy + 6], fill=c)                       # rounded upper back
        d.rectangle([cx - 6, sy + 2, cx - 4.5, sy + 6], fill=shade(c, 0.78))


def helmet(d, cx, top, c):
    d.chord([cx - 5.8, top - 2.2, cx + 5.4, top + 8.5], 160, 380, fill=c)
    d.rectangle([cx - 5.6, top + 2, cx - 2, top + 6.5], fill=c)
    d.rectangle([cx + 1.5, top + 2.5, cx + 5.5, top + 4.5], fill=C("2a3038"))           # visor
    d.line([(cx - 4, top - 1), (cx + 2, top - 1.5)], fill=shade(c, 1.12), width=1)       # shell highlight
    d.line([(cx + 0.5, top + 8), (cx + 2.5, top + 10)], fill=C("2a2a2e"), width=1)       # chin strap


def held(d, look, hand):
    x, y = hand
    if look.get("hold") == "coffee":
        d.rectangle([x - 1, y - 5, x + 2, y + 1], fill=C("f4f1ea"))
        d.rectangle([x - 1, y - 3, x + 2, y - 1], fill=C("8a5a38"))   # cardboard sleeve
        d.rectangle([x - 1.5, y - 6, x + 2.5, y - 5.5], fill=C("3a2e2a"))  # lid
    elif look.get("hold") == "phone":
        d.rectangle([x - 0.5, y - 4, x + 1.5, y], fill=C("1c1e24"))
        d.point([(x + 1, y - 3)], fill=C("8fb8e0"))
    d.ellipse([x - 1.5, y - 1, x + 1.5, y + 2], fill=look["skin_c"])


def crowd_bag(d, cx, sy, hy, look, hand, phase):
    kind, c = look.get("bag"), look.get("bagc", (40, 40, 40))
    if kind == "laptop":
        sway = 0.8 * sin(phase)
        d.line([(cx + 2, sy), (cx - 2 + sway, hy - 4)], fill=shade(c, 0.7), width=1)
        d.rectangle([cx - 8 + sway, hy - 4, cx + 3 + sway, hy + 3], fill=c)
        d.line([(cx - 8 + sway, hy - 3), (cx + 3 + sway, hy - 3)], fill=shade(c, 0.72), width=1)  # flap
    elif kind == "foodbag":
        x, y = hand
        d.line([(x - 2, y), (x, y - 1), (x + 2, y)], fill=C("3a3a3a"), width=1)
        d.rectangle([x - 5, y + 1, x + 5, y + 10], fill=shade(c, 0.94))
        d.rectangle([x - 5, y + 1, x + 5, y + 2], fill=C("2a2a2e"))                # zip top
        d.rectangle([x - 5, y + 9, x + 5, y + 10], fill=shade(c, 0.7))             # base seam
        d.rectangle([x - 2, y + 4, x + 2, y + 6], fill=C("2a2a2e"))                # logo patch


def frame(look, f, stand=False):
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = 2 * pi * f / FRAMES
    amp = look.get("amp", 17.0)
    hunch = look.get("hunch", 0)
    thigh_a, thigh_b = amp * cos(p), -amp * cos(p)
    k = amp / 17.0
    knee_a = 6 + 34 * k * max(0.0, -sin(p))
    knee_b = 6 + 34 * k * max(0.0, sin(p))
    bob = -1.2 * k * (1 - abs(cos(p)))
    if stand:
        # Upright, feet together: used on the escalator and in queues.
        p = pi / 2
        thigh_a, thigh_b, knee_a, knee_b, bob = 1.5, -1.5, 3.0, 3.0, 0.0
    hip = (CX, HIP_Y + bob)
    shoulder_y = hip[1] - 21 + hunch * 0.5
    head_top = shoulder_y - 12 + hunch * 0.5
    skin = look["skin_c"]
    sleeve = look.get("sleeve", look["tc"])
    swing = 0.8 if not hunch else 0.5
    far_hand = arm2(d, (CX - 0.5, shoulder_y + 2), -swing * thigh_b, -14, shade(sleeve, 0.72), shade(skin, 0.85), look)
    leg2(d, (hip[0] - 0.5, hip[1]), thigh_b, knee_b, shade(look["lc"], 0.72), shade(look["shoes"], 0.75), look, False)
    if look.get("bag") == "backpack": bag(d, CX, shoulder_y, hip[1], look, None)
    if look.get("bag") == "bigpack": big_pack(d, CX, shoulder_y, hip[1], look["bagc"])
    leg2(d, hip, thigh_a, knee_a, look["lc"], look["shoes"], look, True)
    if look.get("pencil"):
        d.polygon([(CX - 5, hip[1] - 2), (CX + 4.5, hip[1] - 2), (CX + 5, hip[1] + 11), (CX - 5, hip[1] + 11)], fill=look["lc"])
        d.line([(CX + 1, hip[1] + 7), (CX + 1, hip[1] + 11)], fill=shade(look["lc"], 0.7), width=1)  # back slit
    else:
        lower_garment(d, CX, hip[1], look)
    torso(d, CX, shoulder_y, hip[1], look, p)
    crowd_torso_extras(d, CX, shoulder_y, hip[1], look)
    if look.get("bag") == "sling": bag(d, CX, shoulder_y, hip[1], look, None)
    if look.get("bag") == "laptop": crowd_bag(d, CX, shoulder_y, hip[1], look, None, p)
    head(d, CX + 0.5 + hunch, head_top, look)
    if look.get("helmet"): helmet(d, CX + 0.5 + hunch, head_top, look["helmet"])
    shoulder = (CX + 0.5, shoulder_y + 2)
    if look.get("hold") == "coffee":
        hand = arm2(d, shoulder, 6 - 0.15 * thigh_a, 82, sleeve, skin, look)
        held(d, look, hand)
    elif look.get("hold") == "phone":
        hand = arm2(d, shoulder, 4, 128, sleeve, skin, look)
        held(d, look, hand)
    else:
        hand = arm2(d, shoulder, -swing * thigh_a, -16, sleeve, skin, look)
    if look.get("bag") in ("handbag", "tote", "briefcase"): bag(d, CX, shoulder_y, hip[1], look, hand)
    if look.get("bag") == "foodbag": crowd_bag(d, CX, shoulder_y, hip[1], look, hand, p)
    return outline(img)


RAMP = " .:-=+*#%@"


def ascii_cell(img, scale=1):
    a = img.convert("RGBA")
    w, h = a.size
    px = a.load()
    rows = []
    for y in range(0, h, scale):
        s = ""
        for x in range(0, w, scale):
            r, g, b, al = px[x, y]
            if al == 0: s += " "; continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            s += RAMP[1 + min(8, int(lum * 9))]
        rows.append(s.rstrip())
    while rows and not rows[0]: rows.pop(0)
    return "\n".join(rows)


def build(show=()):
    out = ROOT / "assets" / "people-real"
    out.mkdir(parents=True, exist_ok=True)
    meta = []
    for sheet in range(4):
        img = Image.new("RGBA", (CELL_W * FRAMES, CELL_H * 4), (0, 0, 0, 0))
        for row in range(4):
            i = sheet * 4 + row
            kind, desc, base = CROWD[i]
            look = dict(base)
            look["skin_c"] = SKIN[look["skin"]]
            for f in range(FRAMES):
                fr = frame(look, f)
                img.paste(fr, (f * CELL_W, row * CELL_H))
                if i in show and f in (0, 2):
                    print(f"--- #{i} {kind} {desc} frame {f}")
                    print(ascii_cell(fr))
            meta.append({"sheet": sheet, "row": row, "kind": kind, "desc": desc})
        img.save(out / f"crowd-walk-{sheet}.png", optimize=True)
        stand = Image.new("RGBA", (CELL_W, CELL_H * 4), (0, 0, 0, 0))
        for row in range(4):
            look = dict(CROWD[sheet * 4 + row][2])
            look["skin_c"] = SKIN[look["skin"]]
            stand.paste(frame(look, 0, stand=True), (0, row * CELL_H))
        stand.save(out / f"crowd-stand-{sheet}.png", optimize=True)
        print("wrote", out / f"crowd-walk-{sheet}.png")
    (out / "crowd.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8")
    print("wrote", out / "crowd.json")


if __name__ == "__main__":
    show = [int(a) for a in sys.argv[1:] if a.isdigit()]
    build(show)
