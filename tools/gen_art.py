#!/usr/bin/env python3
"""Generates the placeholder pixel art in assets/sprites/ and assets/icons/.

Every sprite is drawn on the field's pixel grid: one sprite pixel = one wheat
cell (Game.CELL screen pixels). Keep that rule when making real art and it'll
all match. Overwrite any PNG (same name, same frame layout) to replace it.

Frame strips (frames side by side, equal width):
  greeblet/spinner/tracer/glowie.png  2 frames (walk)
  cow.png                             2 frames (walk)
  overlord.png                        3 frames (idle, talk 1, talk 2)

Usage: python3 tools/gen_art.py   (needs Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"
ICO = ROOT / "assets" / "icons"

PAL = {
    ".": (0, 0, 0, 0),
    "k": (16, 14, 24, 255),
    "g": (126, 224, 112, 255), "G": (64, 150, 78, 255),
    "e": (10, 10, 16, 255), "E": (230, 250, 255, 255),
    "p": (176, 118, 236, 255), "P": (110, 64, 168, 255),
    "b": (104, 176, 255, 255), "B": (52, 102, 196, 255),
    "y": (255, 242, 150, 255), "Y": (222, 178, 70, 255),
    "w": (236, 232, 224, 255), "W": (170, 170, 182, 255),
    "d": (92, 94, 108, 255), "D": (56, 56, 68, 255),
    "r": (222, 72, 62, 255), "R": (140, 36, 40, 255),
    "o": (255, 150, 50, 255),
    "c": (130, 255, 228, 255), "C": (60, 170, 160, 255),
    "s": (196, 202, 216, 255), "S": (130, 136, 152, 255),
    "m": (246, 160, 176, 255),
    "h": (232, 192, 92, 255), "H": (166, 124, 50, 255),
    "n": (122, 84, 52, 255), "N": (78, 52, 34, 255),
    "j": (40, 40, 50, 255),
    "v": (40, 40, 52, 255),
}
K = PAL["k"]


def grid(rows):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row.ljust(w, ".")):
            img.putpixel((x, y), PAL[ch])
    return img


def outline(img):
    """Adds a 1px dark outline around the sprite (grows it by 2)."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    src = out.copy()
    for y in range(h + 2):
        for x in range(w + 2):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w + 2 and 0 <= ny < h + 2 and src.getpixel((nx, ny))[3] > 0:
                        out.putpixel((x, y), K)
                        break
    return out


def strip(name, frames, folder=SPR, line=True):
    imgs = [outline(grid(f)) if line else grid(f) for f in frames]
    w = max(i.size[0] for i in imgs)
    h = max(i.size[1] for i in imgs)
    out = Image.new("RGBA", (w * len(imgs), h), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        out.paste(im, (i * w + (w - im.size[0]) // 2, h - im.size[1]))
    out.save(folder / f"{name}.png")
    return out


def recolor(rows, mapping):
    return ["".join(mapping.get(c, c) for c in r) for r in rows]


ALIEN_TOP = [
    ".ggggg.",
    "ggggggg",
    "geegeeg",
    "gEegEeg",
    "ggggggg",
    ".gGGGg.",
    "..ggg..",
    ".gGgGg.",
    "g.ggg.g",
]
LEGS_A = ["..g.g..", ".g...g."]
LEGS_B = ["..g.g..", "..g.g.."]


def aliens():
    strip("greeblet", [ALIEN_TOP + LEGS_A, ALIEN_TOP + LEGS_B])
    sp = ["...y...", "...p..."] + recolor(ALIEN_TOP, {"g": "p", "G": "P"})
    strip("spinner", [sp + recolor(LEGS_A, {"g": "p"}), sp + recolor(LEGS_B, {"g": "p"})])
    tr = recolor(ALIEN_TOP, {"g": "b", "G": "B"})
    tr = [r + ("n" if i in (4, 5, 6, 7) else ".") for i, r in enumerate(tr)]
    tr[3] = tr[3][:-1] + "y"
    strip("tracer", [tr + recolor([l + "." for l in LEGS_A], {"g": "b"}), tr + recolor([l + "." for l in LEGS_B], {"g": "b"})])
    gl = [
        "..yyy..",
        ".yyyyy.",
        "yyyyyyy",
        "yeeyeey",
        "yEeyEey",
        "yyyyyyy",
        "yyYYYyy",
        ".yyyyy.",
        "..yyy..",
    ]
    strip("glowie", [gl + [".y...y."], gl + ["y.....y"]])


def cow():
    body = [
        "...........ww.",
        ".wwkkwwwwwwwwww",
        "wwkkkwwwwwkwwwm",
        "wwwwwwwkkkwwwmm",
        ".wwwwwwkkwwww..",
    ]
    a = body + [".ww.w...ww.w..", ".ww.w...ww.w.."]
    b = body + ["..ww.w...ww.w.", "..ww.w...ww.w."]
    strip("cow", [a, b])


def saucer():
    strip("saucer", [[
        "......ccc......",
        ".....cEccc.....",
        "...sssssssss...",
        ".sSsysSsysSsys.",
        "sssssssssssssss",
        ".SSSSSSSSSSSSS.",
        "...SS.....SS...",
    ]])


def overlord():
    head = [
        "......SSSSSSSS......",
        "....SssssssssssS....",
        "...sssssssssssssss..",
        "..ssssssssssssssss..",
        ".sssssssssssssssss..",
        ".ssseeeesssseeeesss.",
        ".sseeEeeessseeEeess.",
        ".sseeeeesssseeeeess.",
        "..sseeeessssseeeess.",
        "...sssssssssssssss..",
        "....sssssssssss.....",
    ]
    body = [
        "......sssssss.......",
        "........sss.........",
        "....pppppppppppp....",
        "...ppppPyYPPpppppp..",
        "..pppppPPPPPppppppp.",
        "..ppppppPPPPppppppp.",
        "..ppp.ppppppppp.ppp.",
        "..ss..ppppppppp..ss.",
        "......ppppppppp.....",
        "......PP.....PP.....",
        "......ss.....ss.....",
        ".....sss.....sss....",
    ]
    m0 = [".....sssskkssss....."]
    m1 = [".....ssskkkksss....."]
    m2 = [".....sssskkkss......"]
    strip("overlord", [head + m0 + body, head + m1 + body, head + m2 + body])


def cursor():
    open_hand = [
        "g...g...g.",
        "g...g...g.",
        "gg..g..gg.",
        ".g..g..g..",
        ".gggggggg.",
        ".ggggggggg",
        ".gggggggg.",
        "..gggggg..",
        "..GGGGGG..",
        "..GGGGGG..",
    ]
    fist = [
        "..........",
        "..........",
        "..g.g.g...",
        ".gggggggg.",
        ".ggggggggg",
        ".gggggggg.",
        ".gggggggg.",
        "..gggggg..",
        "..GGGGGG..",
        "..GGGGGG..",
    ]
    strip("cursor_hand", [open_hand])
    strip("cursor_fist", [fist])


def slot_machine():
    strip("slot", [[
        "........ccccc.........",
        ".......cEcccccc.......",
        "....ssssssssssssss....",
        "..sSsysSsysSsysSsys...",
        ".ssssssssssssssssssss.",
        "..SSSSSSSSSSSSSSSSSS..",
        "...rrrrrrrrrrrrrrrr...",
        "...ryyyyyyyyyyyyyyr...",
        "...ryrrrrrrrrrrrryr...",
        "...ryrwwwwwwwwwwryr.d.",
        "...ryrwjwwjwwjwwryr.r.",
        "...ryrwjwwjwwjwwryr.d.",
        "...ryrwwwwwwwwwwryr.d.",
        "...ryrrrrrrrrrrrryrdd.",
        "...ryyyyyyyyyyyyyyr...",
        "...rrrrrrrrrrrrrrrr...",
        "...RrrrrrrrrrrrrrrR...",
        "...RrrrryyyyyyrrrrR...",
        "...RrrrryjjjjyrrrrR...",
        "...RrrrryyyyyyrrrrR...",
        "...RrrrrrrrrrrrrrrR...",
        "...RRRRRRRRRRRRRRRR...",
        "...DDDDDDDDDDDDDDDD...",
    ]])


def harvester():
    strip("harvester", [[
        "...............dd...........",
        "..........vvvvvdd...........",
        "..........vccccvd...........",
        "..........vccccvrrrrrrrr....",
        "...rrrrrrrrrrrrrrrrrrrrrrr..",
        "HHHrrrrrrrrrrrrrrrrrrrrrrrr.",
        "HhhRrrrrrrrrrrrrrrrrrrrrrrr.",
        "HhhRrrRRRRrrrrrrrrrRRRRrrrr.",
        "HhhRrRjjjjRrrrrrrrRjjjjRrrr.",
        "HHHRRjjddjjRRRRRRjjddjjRRR..",
        "....jjdddjj......jjdddjj....",
        ".....jjdjj........jjdjj.....",
        "......jjj..........jjj......",
    ]])


def barn():
    strip("barn", [[
        ".......RRRR.......",
        ".....RRrrrrRR.....",
        "...RRrrrrrrrrRR...",
        ".RRrrrrrwwrrrrrRR.",
        "RrrrrrrrwwrrrrrrrR",
        ".rrrrrrrrrrrrrrrr.",
        ".rrwwwwwwwwwwwwrr.",
        ".rrwrwrrrrrrwrwrr.",
        ".rrwwrrrrrrrrwwrr.",
        ".rrwrwrrrrrrwrwrr.",
        ".rrwwwwwwwwwwwwrr.",
        ".rrwnnnnnnnnnnwrr.",
        ".rrwnNnnnnnnNnwrr.",
        ".rrwnnNnnnnNnnwrr.",
        ".rrwnnnNnnNnnnwrr.",
    ]])


def farmer():
    strip("farmer", [[
        "..HHHHH..",
        ".HhhhhhH.",
        "HHHHHHHHH",
        "..wwwww..",
        "..weweww.",
        "..wwwww..",
        "..bbbbb..",
        ".bbbybbb.",
        ".bbbbbbb.",
        "w.bbbbb.w",
        "..bb.bb..",
        "..nn.nn..",
    ]])


# ------------------------------------------------------------------ icons

def new():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def from_sprite(name, frame_w=None):
    src = Image.open(SPR / f"{name}.png")
    if frame_w:
        src = src.crop((0, 0, frame_w, src.size[1]))
    bbox = src.getbbox()
    src = src.crop(bbox)
    w, h = src.size
    s = min(1.0, 16 / max(w, h))
    if s < 1.0:
        src = src.resize((max(1, int(w * s)), max(1, int(h * s))), Image.NEAREST)
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    img.paste(src, ((16 - src.size[0]) // 2, (16 - src.size[1]) // 2), src)
    return img


def icons():
    c = PAL
    out = {}
    for n in ("greeblet", "spinner", "tracer", "glowie"):
        out[n] = from_sprite(n, Image.open(SPR / f"{n}.png").size[0] // 2)
    out["saucer"] = from_sprite("saucer")
    out["cow"] = from_sprite("cow", Image.open(SPR / "cow.png").size[0] // 2)
    out["harvest"] = from_sprite("harvester")

    img, d = new()  # big hand
    d.rectangle((3, 6, 12, 14), fill=c["g"], outline=K)
    for x in (3, 7, 11):
        d.rectangle((x, 1, x + 2, 7), fill=c["g"], outline=K)
    out["hand"] = img
    img, d = new()  # boots / speed
    d.rectangle((5, 3, 10, 11), fill=c["b"], outline=K)
    d.rectangle((5, 10, 14, 14), fill=c["b"], outline=K)
    for y in (5, 8, 12):
        d.line((0, y, 3, y), fill=c["c"])
    out["boots"] = img
    img, d = new()  # fertilizer bag
    d.polygon([(3, 4), (12, 4), (14, 15), (1, 15)], fill=c["n"], outline=K)
    d.rectangle((4, 2, 11, 4), fill=c["N"], outline=K)
    d.rectangle((5, 8, 10, 12), fill=c["h"])
    out["fertilizer"] = img
    img, d = new()  # geometry: compass + circle
    d.ellipse((2, 4, 14, 15), outline=c["c"])
    d.line((8, 1, 4, 13), fill=c["s"], width=2)
    d.line((8, 1, 12, 13), fill=c["s"], width=2)
    d.rectangle((7, 0, 9, 2), fill=c["y"])
    out["geometry"] = img
    img, d = new()  # tourists: camera
    d.rectangle((1, 5, 14, 14), fill=c["D"], outline=K)
    d.rectangle((3, 3, 7, 5), fill=c["D"], outline=K)
    d.ellipse((5, 7, 11, 13), fill=c["b"], outline=K)
    d.point((12, 7), fill=c["y"])
    out["tourists"] = img
    img, d = new()  # antenna
    d.line((8, 4, 8, 15), fill=c["s"], width=2)
    d.line((3, 15, 8, 9), fill=c["S"])
    d.line((13, 15, 8, 9), fill=c["S"])
    d.ellipse((6, 1, 10, 5), fill=c["r"], outline=K)
    d.arc((1, -2, 15, 10), 200, 340, fill=c["c"])
    out["antenna"] = img
    img, d = new()  # magnet
    d.arc((2, 2, 14, 14), 0, 180, fill=c["r"], width=4)
    d.rectangle((2, 3, 5, 8), fill=c["r"])
    d.rectangle((11, 3, 14, 8), fill=c["r"])
    d.rectangle((2, 1, 5, 3), fill=c["s"])
    d.rectangle((11, 1, 14, 3), fill=c["s"])
    out["magnet"] = img
    img, d = new()  # combo: lightning
    d.polygon([(9, 0), (3, 9), (7, 9), (5, 15), (13, 6), (8, 6), (11, 0)], fill=c["y"], outline=K)
    out["combo"] = img
    img, d = new()  # memory: clock
    d.ellipse((1, 1, 14, 14), fill=c["w"], outline=K)
    d.line((8, 8, 8, 3), fill=K)
    d.line((8, 8, 11, 10), fill=K)
    out["memory"] = img
    img, d = new()  # golden wheat
    d.line((8, 15, 8, 4), fill=c["H"])
    for y in (3, 6, 9):
        d.ellipse((5, y, 8, y + 3), fill=c["y"], outline=c["Y"])
        d.ellipse((8, y, 11, y + 3), fill=c["y"], outline=c["Y"])
    d.ellipse((7, 0, 9, 3), fill=c["y"])
    out["golden"] = img
    img, d = new()  # signal booster: radio waves
    d.ellipse((6, 6, 10, 10), fill=c["c"])
    for r in (4, 7):
        d.arc((8 - r, 8 - r, 8 + r, 8 + r), 300, 60, fill=c["c"])
        d.arc((8 - r, 8 - r, 8 + r, 8 + r), 120, 240, fill=c["c"])
    out["signal"] = img
    img, d = new()  # seed money: coin
    d.ellipse((2, 2, 13, 13), fill=c["Y"], outline=K)
    d.ellipse((4, 4, 11, 11), fill=c["y"])
    d.line((8, 5, 8, 10), fill=c["H"])
    out["coin"] = img
    img, d = new()  # lucky: clover-ish four dots
    for (x, y) in ((4, 1), (8, 5), (4, 9), (0, 5)):
        d.ellipse((x + 2, y, x + 7, y + 5), fill=c["g"], outline=K)
    d.line((8, 10, 11, 15), fill=c["G"])
    out["lucky"] = img
    img, d = new()  # crew: three tiny aliens
    for x in (1, 6, 11):
        d.ellipse((x, 4, x + 4, 8), fill=c["g"], outline=K)
        d.rectangle((x + 1, 9, x + 3, 13), fill=c["g"])
    out["crew"] = img

    # Slot reel symbols.
    out["sym_ufo"] = out["saucer"]
    img, d = new()
    d.ellipse((2, 1, 13, 12), fill=c["g"], outline=K)
    d.ellipse((3, 5, 7, 9), fill=c["e"])
    d.ellipse((8, 5, 12, 9), fill=c["e"])
    d.rectangle((6, 12, 9, 15), fill=c["G"])
    out["sym_alien"] = img
    img, d = new()
    d.rectangle((3, 3, 12, 13), fill=c["w"], outline=K)
    d.rectangle((4, 10, 11, 13), fill=c["m"])
    d.rectangle((5, 5, 6, 6), fill=K)
    d.rectangle((9, 5, 10, 6), fill=K)
    d.rectangle((1, 1, 3, 3), fill=c["W"])
    d.rectangle((12, 1, 14, 3), fill=c["W"])
    d.rectangle((7, 4, 9, 7), fill=K)
    out["sym_cow"] = img
    out["sym_wheat"] = out["golden"].copy()
    img, d = new()
    d.rectangle((0, 0, 15, 15), fill=c["H"])
    d.ellipse((2, 2, 13, 13), fill=c["Y"], outline=c["c"])
    d.ellipse((5, 5, 10, 10), fill=c["H"], outline=c["c"])
    out["sym_circle"] = img
    img, d = new()
    pts = []
    import math
    for i in range(10):
        r = 7.5 if i % 2 == 0 else 3.2
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((7.5 + r * math.cos(a), 8 + r * math.sin(a)))
    d.polygon(pts, fill=c["y"], outline=c["o"])
    out["sym_star"] = img
    for k, v in out.items():
        v.save(ICO / f"{k}.png")


def app_icon():
    img = Image.new("RGBA", (32, 32), PAL["H"])
    d = ImageDraw.Draw(img)
    for y in range(0, 32, 2):
        d.line((0, y, 31, y), fill=PAL["h"])
    d.ellipse((4, 4, 27, 27), fill=(40, 52, 70, 255), outline=PAL["c"])
    d.ellipse((10, 10, 21, 21), fill=PAL["H"], outline=PAL["c"])
    s = Image.open(SPR / "saucer.png")
    img.paste(s, (8, 1), s)
    img.save(SPR / "icon.png")


if __name__ == "__main__":
    SPR.mkdir(parents=True, exist_ok=True)
    ICO.mkdir(parents=True, exist_ok=True)
    aliens()
    cow()
    saucer()
    overlord()
    cursor()
    slot_machine()
    harvester()
    barn()
    farmer()
    icons()
    app_icon()
    print("done")
