#!/usr/bin/env python3
"""Windfall plant disease diagrams: what each common disease looks like on the plant.

Asked for by William on 15 November 2026: "Include diagrams of the diseases
too." Each diagram shows the part of the plant where the disease is seen
(a leaf, a fruit, a stem, a root) with its tell-tale marks.

Run it from the top of the repository:

    python3 Tools/design/plant_diseases.py Design/Diseases

It writes Design/Diseases/light and /dark (disease-<name>.svg) and a sheet
of them all. The words that go with each are in Windfall/PlantDiseases.json.

⚠️ Every diagram is Claude's, drawn from memory on 15 November 2026. None
has been checked against a photograph or a reference book.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapely.geometry import Point
from wildlife_kit import Art, P, LW, turn, curve, ell, blob, poly, limb, band, paint, figure, stroke, spots

DRAW = {}


def draws(slug):
    def keep(fn):
        DRAW[slug] = fn; return fn
    return keep


def leaf(a, colour="leaf", pts=None, veins=True, stalk=True, patches=()):
    """One broad leaf, tip to the upper right. Returns its outline."""
    pts = pts or [(18, 82), (20, 56), (34, 32), (56, 18), (84, 14), (82, 40), (68, 64), (44, 80)]
    if stalk:
        stroke(a, [(8, 94), (14, 88), (20, 80)], 1.6, smooth=False)
    sil = figure(a, [blob(pts, 8)], colour, patches, close=0)
    if veins:
        stroke(a, [(20, 80), (48, 50), (82, 16)], 0.9, 0.6)
        for u, d in ((0.25, 14), (0.45, 16), (0.65, 14)):
            x, y = 20 + 62 * u, 80 - 64 * u
            stroke(a, [(x, y), (x + d, y + d * 0.2)], 0.5, 0.4, smooth=False)
            stroke(a, [(x, y), (x - d * 0.2, y - d)], 0.5, 0.4, smooth=False)
    return sil


def scatter(sil, n, seed=1, inset=3):
    """n places inside an outline. The same seed always gives the same places."""
    import random
    rnd = random.Random(seed * 7919); x0, y0, x1, y1 = sil.bounds; out = []; inner = sil.buffer(-inset); tries = 0
    while len(out) < n and tries < n * 40:
        tries += 1
        x, y = rnd.uniform(x0, x1), rnd.uniform(y0, y1)
        if inner.contains(Point(x, y)) and all((x - q[0]) ** 2 + (y - q[1]) ** 2 > 9 for q in out):
            out.append((x, y))
    return out


def fruit(a, colour="red", cx=50, cy=54, r=27, stalk=True, dimple=True):
    if stalk:
        stroke(a, [(cx, cy - r + 3), (cx + 2, cy - r - 8), (cx + 6, cy - r - 13)], 1.8)
    sil = figure(a, [blob([(cx, cy - r + 3), (cx + r * 0.8, cy - r * 0.86), (cx + r, cy), (cx + r * 0.7, cy + r * 0.86), (cx, cy + r * 0.94), (cx - r * 0.7, cy + r * 0.86), (cx - r, cy), (cx - r * 0.8, cy - r * 0.86)], 8)], colour, close=0)
    if dimple:
        stroke(a, [(cx - 5, cy - r + 5), (cx, cy - r + 8), (cx + 5, cy - r + 5)], 0.7, 0.6)
    return sil


@draws("rust")
def rust():
    a = Art(); sil = leaf(a, "leaf", patches=[(ell(46, 52, 16, 12, -40), "pear")])
    for i, (x, y) in enumerate(scatter(sil, 26, 2)):
        a.dot(x, y, 1.5 + (i % 3) * 0.3, "orange"); a.dot(x, y, 0.6, "rust")
    return a


@draws("powdery-mildew")
def powdery_mildew():
    a = Art(); sil = leaf(a, "deep")
    for i, (x, y) in enumerate(scatter(sil, 9, 4, 6)):
        paint(a, ell(x, y, 6 + (i % 3), 4.6 + (i % 2), i * 40).intersection(sil), "white", fa=0.85)
    for x, y in scatter(sil, 40, 7, 2):
        a.dot(x, y, 0.5, "white")
    paint(a, sil, None, LW)
    return a


@draws("downy-mildew")
def downy_mildew():
    a = Art(); sil = leaf(a, "leaf")
    for i, (x, y) in enumerate(scatter(sil, 7, 5, 7)):   # yellow patches with straight edges, between the veins
        t = turn(x, y, 30 + i * 25)
        paint(a, poly(t(-5, -4), t(5, -4.6), t(5.6, 4), t(-4.6, 4.4)).intersection(sil), "primrose")
        for d in (-2, 0, 2):
            a.dot(*t(d, d * 0.4), 0.7, "grey")
    paint(a, sil, None, LW)
    return a


@draws("blight")
def blight():
    a = Art(); sil = leaf(a, "leaf")
    for (x, y, r) in ((66, 30, 11), (36, 62, 9), (76, 20, 6)):   # dark blotches spreading in from the edge, each with a pale rim
        paint(a, ell(x, y, r + 2.4, r * 0.8 + 2.4, -30).intersection(sil), "pear")
        paint(a, ell(x, y, r, r * 0.8, -30).intersection(sil), "brown")
        paint(a, ell(x + 1, y + 1, r * 0.5, r * 0.4, -30).intersection(sil), "dark")
    paint(a, sil, None, LW)
    return a


@draws("apple-scab")
def apple_scab():
    a = Art(); sil = fruit(a, "unripe")
    for i, (x, y) in enumerate(scatter(sil, 9, 3, 6)):
        paint(a, ell(x, y, 3.6 + (i % 3), 3 + (i % 2), i * 30).intersection(sil), "dark")
        paint(a, ell(x, y, 1.6, 1.3).intersection(sil), "bark")
    stroke(a, [(58, 60), (62, 66), (60, 72), (64, 77)], 0.9, 0.9, col="ink", smooth=False)   # a crack
    return a


@draws("canker")
def canker():
    a = Art()
    figure(a, [limb([(8, 78), (40, 60), (92, 30)], 16, 11)], "bark", close=0)
    figure(a, [limb([(46, 56), (60, 30), (62, 12)], 6, 3)], "bark", close=0)
    wound = ell(52, 54, 13, 7.4, -28)
    paint(a, wound, "brown", 0.9)                                                             # sunken, dead bark in rings
    paint(a, ell(52, 54, 9.4, 5, -28), "dark", 0.6)
    paint(a, ell(52, 54, 5.6, 2.8, -28), "seed", 0.6)
    for x, y in ((24, 70), (30, 62), (76, 44), (82, 34)):
        stroke(a, [(x, y), (x + 5, y - 2.6)], 0.5, 0.5, smooth=False)
    return a


@draws("brown-rot")
def brown_rot():
    a = Art(); sil = fruit(a, "red")
    paint(a, ell(58, 60, 22, 20).intersection(sil), "brown")
    for r in (6, 11, 16):                                                                      # cream pustules in rings
        for k in range(int(r * 1.3)):
            th = 2 * math.pi * k / int(r * 1.3)
            p = (58 + r * math.cos(th), 60 + r * math.sin(th))
            if sil.buffer(-1.5).contains(Point(p)):
                a.dot(p[0], p[1], 1.0, "cream")
    paint(a, sil, None, LW)
    return a


@draws("grey-mould")
def grey_mould():
    a = Art()
    for ang in (-150, -120, -90, -60, -30):
        t = turn(50, 26, ang); paint(a, blob([t(0, -3), t(12, 0), t(0, 3)], 5), "deep", 0.8)
    berry = blob([(50, 24), (70, 28), (76, 46), (64, 72), (50, 86), (36, 72), (24, 46), (30, 28)], 8)
    sil = figure(a, [berry], "red", close=0)
    for x, y in scatter(sil, 14, 6, 4):
        a.dot(x, y, 0.6, "primrose")
    fuzz = blob([(40, 50), (58, 44), (72, 52), (66, 70), (50, 84), (40, 72)], 8).intersection(sil)
    paint(a, fuzz, "grey", fa=0.92)
    for x, y in scatter(fuzz, 30, 9, 0.5):
        stroke(a, [(x, y), (x + 1.4, y - 2.6)], 0.5, 0.7, col="slate", smooth=False)
    paint(a, sil, None, LW)
    return a


@draws("black-spot")
def black_spot():
    a = Art()
    pts = [(18, 82), (20, 58), (32, 36), (54, 20), (84, 14), (80, 40), (68, 62), (44, 80)]
    sil = leaf(a, "leaf", pts, patches=[(ell(40, 60, 22, 16, -40), "primrose")])
    for i, (x, y) in enumerate(scatter(sil, 8, 8, 6)):
        g = ell(x, y, 4 + (i % 2), 3.6, i * 30)
        paint(a, g.buffer(1.2).intersection(sil), "primrose"); paint(a, g.intersection(sil), "ink")
        for k in range(8):
            stroke(a, [(x, y), turn(x, y, k * 45)(5.6)], 0.4, 0.8, col="ink", smooth=False)   # the fringed edge
    paint(a, sil, None, LW)
    return a


@draws("club-root")
def club_root():
    a = Art()
    stroke(a, [(8, 34), (92, 34)], 0.9, 0.6, col="soil", smooth=False)
    for dx, ang in ((-16, -130), (-6, -110), (6, -70), (16, -50)):
        t = turn(50 + dx * 0.3, 32, ang); paint(a, blob([t(0, -4), t(14, -7), t(24, 0), t(14, 7), t(0, 4)], 6), "sage", 0.9)
    figure(a, [limb([(50, 32), (50, 44)], 7, 8)], "pale", close=0)
    club = blob([(42, 42), (58, 42), (66, 54), (60, 68), (64, 80), (52, 90), (44, 78), (34, 70), (36, 54)], 8)
    figure(a, [club, ell(30, 62, 7, 5, 20), ell(70, 70, 8, 5.4, -30)], "seed", close=1.5)   # roots swollen into knobs
    for pts in ([(40, 60), (46, 66), (44, 74)], [(56, 54), (60, 60)], [(52, 78), (54, 84)]):
        stroke(a, pts, 0.6, 0.5)
    for x, y, ang in ((30, 66, 120), (70, 74, 60), (52, 90, 90)):
        stroke(a, [(x, y), turn(x, y, ang)(7)], 0.7, 0.8, col="soil", smooth=False)
    return a


@draws("leaf-curl")
def leaf_curl():
    a = Art()
    stroke(a, [(8, 94), (14, 88), (20, 80)], 1.6, smooth=False)
    pts = [(18, 82), (26, 66), (22, 52), (34, 44), (36, 28), (52, 28), (62, 14), (84, 14), (74, 30), (80, 44), (64, 50), (62, 66), (46, 68), (40, 82)]
    sil = figure(a, [blob(pts, 8)], "leaf", close=0)
    for x, y, r in ((36, 54, 9), (52, 40, 10), (66, 28, 8), (50, 60, 7)):   # red, puckered blisters
        paint(a, ell(x, y, r, r * 0.8, -30).intersection(sil), "red"); paint(a, ell(x - 1.4, y - 1.4, r * 0.5, r * 0.36, -30).intersection(sil), "pink")
    stroke(a, [(20, 80), (48, 50), (82, 16)], 0.9, 0.6)
    paint(a, sil, None, LW)
    return a


@draws("chocolate-spot")
def chocolate_spot():
    a = Art(); sil = leaf(a, "sage", [(18, 82), (16, 56), (30, 30), (56, 16), (82, 18), (86, 44), (70, 68), (44, 84)])
    for i, (x, y) in enumerate(scatter(sil, 22, 5, 4)):
        a.dot(x, y, 1.6 + (i % 4) * 0.5, "bark"); a.dot(x, y, 0.6, "dark")
    return a


@draws("damping-off")
def damping_off():
    a = Art()
    figure(a, [poly((10, 70), (90, 70), (84, 92), (16, 92))], "bark", close=1.5)
    paint(a, poly((8, 64), (92, 64), (92, 71), (8, 71)), "soil", LW)
    for x in (26, 74):                                                                         # two healthy seedlings
        stroke(a, [(x, 64), (x + 1, 40)], 1.6, col="deep", smooth=False)
        for s in (1, -1):
            paint(a, ell(x + 1 + s * 6, 37, 6, 3.4, s * -20), "leaf", 0.8)
    stroke(a, [(48, 64), (50, 58), (62, 54), (72, 57)], 1.6, col="deep")                       # one fallen over, pinched at the soil
    paint(a, ell(50, 62, 2.2, 3), "dark")
    for s, (x, y) in ((1, (78, 60)), (-1, (72, 52))):
        paint(a, ell(x, y, 6, 3.2, 30 * s), "pear", 0.8)
    for x, y in ((42, 66), (46, 68), (54, 66.6), (58, 68)):
        a.dot(x, y, 0.8, "white")
    return a


@draws("honey-fungus")
def honey_fungus():
    a = Art()
    figure(a, [poly((34, 4), (66, 4), (72, 70), (28, 70))], "bark", close=0)
    paint(a, poly((40, 34), (58, 30), (62, 70), (38, 70)), "cream", 0.8)                       # white sheet under the lifted bark
    stroke(a, [(8, 70), (92, 70)], 0.9, 0.6, col="soil", smooth=False)
    for pts in ([(30, 72), (20, 82), (8, 84)], [(56, 72), (70, 84), (90, 82)], [(44, 72), (46, 90)]):   # black bootlaces in the soil
        stroke(a, pts, 1.3, 0.95, col="ink")
    for x, y, r in ((22, 58, 8), (34, 62, 6), (74, 58, 8.6), (84, 63, 5.6)):                   # honey-coloured toadstools at the foot
        stroke(a, [(x, y), (x + 1, 70)], 2.2, col="cream", smooth=False)
        figure(a, [blob([(x - r, y), (x - r * 0.6, y - r * 0.7), (x, y - r * 0.9), (x + r * 0.6, y - r * 0.7), (x + r, y), (x, y + 1.6)], 6)], "amber", close=0, lw=0.9)
        a.dot(x, y - r * 0.5, 1.0, "bark")
    return a


@draws("sooty-mould")
def sooty_mould():
    a = Art(); sil = leaf(a, "deep")
    paint(a, blob([(26, 74), (30, 50), (46, 34), (66, 24), (76, 30), (60, 52), (44, 70)], 8).intersection(sil), "ink", fa=0.82)
    for x, y in scatter(sil, 30, 3, 2):
        a.dot(x, y, 0.7, "ink")
    for x, y in ((70, 40), (74, 48), (64, 58)):                                                # the sap-suckers whose honeydew it grows on
        paint(a, ell(x, y, 1.8, 1.3), "unripe", 0.5)
    paint(a, sil, None, LW)
    return a


@draws("blossom-end-rot")
def blossom_end_rot():
    a = Art()
    for ang in (-150, -120, -90, -60, -30):
        t = turn(50, 28, ang); paint(a, blob([t(0, -2.4), t(11, 0), t(0, 2.4)], 5), "deep", 0.8)
    sil = fruit(a, "red", 50, 54, 27, stalk=False, dimple=False)
    paint(a, ell(50, 80, 17, 9).intersection(sil), "dark")                                    # a dark, sunken, leathery patch at the base
    paint(a, ell(50, 80, 20, 11.4).difference(ell(50, 80, 17, 9)).intersection(sil), "bark")
    paint(a, sil, None, LW)
    return a


@draws("coral-spot")
def coral_spot():
    a = Art()
    figure(a, [limb([(8, 80), (50, 52), (92, 22)], 9, 6)], "bark", close=0)
    figure(a, [limb([(50, 52), (62, 28), (70, 10)], 5, 2.6)], "dark", close=0)                # a dead side shoot
    for i in range(22):
        x = 14 + (i * 37) % 70; y = 80 - (x - 8) * 0.69 + ((i * 7) % 7) - 3
        a.dot(x, y, 1.3, "skin"); a.dot(x, y, 0.5, "orange")
    for x, y in ((54, 44), (58, 36), (63, 26), (66, 18)):
        a.dot(x, y, 1.3, "skin"); a.dot(x, y, 0.5, "orange")
    return a


@draws("white-rot")
def white_rot():
    a = Art()
    for dx, top in ((-8, 8), (0, 4), (8, 10)):
        figure(a, [limb([(50 + dx * 0.3, 44), (50 + dx, 26), (50 + dx * 2.2, top)], 4, 1.6)], "pear" if dx else "leaf", close=0, lw=0.9)   # yellowing leaves
    bulb = blob([(50, 40), (66, 48), (72, 64), (62, 80), (50, 84), (38, 80), (28, 64), (34, 48)], 8)
    sil = figure(a, [bulb], "straw", close=0)
    for x in (42, 50, 58):
        stroke(a, [(x, 44), (x + (x - 50) * 0.7, 80)], 0.5, 0.4)
    fluff = ell(50, 82, 20, 9).intersection(sil.buffer(4))
    paint(a, fluff, "white", 0.9)                                                             # white fluff round the base
    for x, y in scatter(fluff, 10, 2, 1.5):
        a.dot(x, y, 0.8, "ink")                                                               # with tiny black dots in it
    for x, ang in ((42, 110), (50, 90), (58, 70)):
        stroke(a, [(x, 88), turn(x, 88, ang)(7)], 0.7, 0.8, col="soil", smooth=False)
    return a


@draws("mosaic-virus")
def mosaic_virus():
    a = Art(); sil = leaf(a, "deep", veins=False)
    for i, (x, y) in enumerate(scatter(sil, 16, 7, 4)):
        t = turn(x, y, i * 50)
        paint(a, blob([t(-5, -2), t(0, -4.6), t(5, -1), t(3, 4), t(-3, 3.6)], 4).intersection(sil), "primrose" if i % 2 else "leaf")
    stroke(a, [(20, 80), (48, 50), (82, 16)], 0.9, 0.6)
    paint(a, sil, None, LW)
    return a


@draws("fireblight")
def fireblight():
    a = Art()
    stroke(a, [(10, 92), (30, 70), (48, 52)], 2.6, col="bark")
    stroke(a, [(48, 52), (60, 38), (70, 30), (78, 32), (80, 40)], 2.2, col="dark")            # the shoot tip bent over like a crook
    for x, y, ang, colour in ((24, 76, -150, "leaf"), (34, 66, 20, "leaf"), (50, 50, -140, "brown"), (58, 40, 10, "brown"), (68, 30, -120, "brown"), (80, 40, 70, "dark")):
        t = turn(x, y, ang)
        figure(a, [blob([t(0, 0), t(8, -5), t(17, 0), t(8, 5)], 6)], colour, close=0, lw=0.9)
        stroke(a, [t(1, 0), t(15, 0)], 0.5, 0.5, smooth=False)
    return a


def sheet(mode, names, cell=150, cols=7):
    bg, card, ink, soft = [("#F8F1E5", "#FFFCF6", "#15271D", "#3A5549"), ("#0C1C14", "#142414", "#F1EADB", "#A7B5A5")][mode]
    pad, lab = 12, 26
    rows = math.ceil(len(names) / cols); Wd = pad + cols * (cell + pad); H = pad + rows * (cell + lab + pad)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{H}" viewBox="0 0 {Wd} {H}">', f'<rect width="{Wd}" height="{H}" fill="{bg}"/>']
    for i, slug in enumerate(names):
        x = pad + (i % cols) * (cell + pad); y = pad + (i // cols) * (cell + lab + pad)
        out.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="14" fill="{card}"/>')
        out.append(f'<g transform="translate({x},{y}) scale({cell / 100})" stroke-linecap="round" stroke-linejoin="round">{DRAW[slug]().body(mode)}</g>')
        out.append(f'<text x="{x + cell / 2}" y="{y + cell + 16}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="12" fill="{ink}">{slug}</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out_diseases"
    for mode, look in enumerate(("light", "dark")):
        os.makedirs(os.path.join(out, look), exist_ok=True)
        for slug, fn in DRAW.items():
            with open(os.path.join(out, look, f"disease-{slug}.svg"), "w", encoding="utf-8") as fh:
                fh.write(fn().svg(mode))
        with open(os.path.join(out, f"sheet-{look}.svg"), "w", encoding="utf-8") as fh:
            fh.write(sheet(mode, list(DRAW)))
    print(len(DRAW), "disease diagrams, each in light and dark, written to", out)
