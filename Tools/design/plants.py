"""Windfall plant drawings: the plants themselves, one function per life stage.

Run:  python3 plants.py OUT_FOLDER
It writes OUT_FOLDER/light and OUT_FOLDER/dark, one SVG per plant and stage,
named plant-<kind>-<stage>.svg.
"""
import math, os, sys
from plant_kit import Art, T, P, f, COLOURS

G = 72  # the usual height of the soil line when roots are shown


def sown(seed):
    """The 'seed' stage: the seed, drawn large, lying under the soil line."""
    def draw():
        a = Art(); a.ground(40, marks=False)
        for dx, dy, w in [(-30, 46, 4), (27, 50, 3), (-22, 80, 3), (30, 76, 4)]:
            a.line(f"M{50 + dx},{dy} L{50 + dx + w},{dy}", 0.9, 0.55, "soil")
        seed(a, 50, 63); return a
    return draw


# ------------------------------------------------------------------ carrot
def carrot_seed(a, x, y):
    a.oval(x, y, 13, 7.5, -18, "seed")
    t = T(x, y, -18)
    for o in (-3.4, 0, 3.4):
        a.line(f"M{P(t(-9, o))} Q{P(t(0, o * 1.25))} {P(t(9, o))}", 0.7, 0.55)
    for k in range(9):
        th = math.radians(200 + k * 17.5); e0 = t(13 * math.cos(th), 7.5 * math.sin(th)); e1 = t(15.5 * math.cos(th), 9.6 * math.sin(th))
        a.line(f"M{P(e0)} L{P(e1)}", 0.6, 0.6)
        th = math.radians(20 + k * 17.5); e0 = t(13 * math.cos(th), 7.5 * math.sin(th)); e1 = t(15.5 * math.cos(th), 9.6 * math.sin(th))
        a.line(f"M{P(e0)} L{P(e1)}", 0.6, 0.6)


def carrot_root(a, x, y, w, L, fill="carrot", rings=0):
    h = w / 2
    a.shape(f"M{f(x - h)},{f(y + 1)} C{f(x - h)},{f(y - w * 0.3)} {f(x + h)},{f(y - w * 0.3)} {f(x + h)},{f(y + 1)} "
            f"C{f(x + h * 0.9)},{f(y + L * 0.45)} {f(x + h * 0.3)},{f(y + L * 0.82)} {f(x)},{f(y + L)} "
            f"C{f(x - h * 0.3)},{f(y + L * 0.82)} {f(x - h * 0.9)},{f(y + L * 0.45)} {f(x - h)},{f(y + 1)} Z", fill)
    a.shape(f"M{f(x + h)},{f(y + 1)} C{f(x + h * 0.9)},{f(y + L * 0.45)} {f(x + h * 0.3)},{f(y + L * 0.82)} {f(x)},{f(y + L)} "
            f"C{f(x + h * 0.05)},{f(y + L * 0.6)} {f(x + h * 0.42)},{f(y + L * 0.3)} {f(x + h * 0.46)},{f(y + 1)} Z", "shade", 0, fa=0.12)
    for k in range(rings):
        u = 0.16 + 0.17 * k; ww = h * (1 - u * 0.95); side = -1 if k % 2 else 1
        x0 = x + side * ww * 0.95
        a.line(f"M{f(x0)},{f(y + L * u)} Q{f(x0 - side * ww * 0.5)},{f(y + L * u + 1.2)} {f(x0 - side * ww * 0.95)},{f(y + L * u + 0.4)}", 0.7, 0.5)


def carrot_seedling():
    a = Art(); a.ground(G)
    a.line(f"M50,{G} Q51.5,{G + 7} 50,{G + 14}", 0.9, 0.85, "soil")
    a.stem((50, G), (49, G - 9), (50, G - 16), 1.0)
    a.leaf(50, G - 16, -152, 16, 0.13, "pale"); a.leaf(50, G - 16, -28, 16, 0.13, "pale")
    a.fern(50, G - 16, -86, 13, pairs=3, size=0.36)
    return a


def carrot_young():
    a = Art(); a.ground(G)
    for ang, L, b in [(-132, 26, -0.12), (-52, 27, 0.12), (-106, 36, -0.06), (-76, 38, 0.06)]:
        a.fern(50, G - 1, ang, L, bend=b)
    carrot_root(a, 50, G, 5.5, 20)
    return a


def carrot_crop():
    a = Art(); a.ground(45)
    for ang, L, b in [(-146, 25, -0.14), (-36, 25, 0.14), (-120, 33, -0.08), (-62, 33, 0.08), (-91, 38, 0.02)]:
        a.fern(50, 43, ang, L, bend=b, pairs=7)
    carrot_root(a, 50, 45, 19, 49, rings=4)
    a.line("M50,94 Q51,96 50.4,98", 0.7, 0.8, "carrot")
    return a


def carrot_tall(fill, curl, leafc):
    a = Art(); a.ground(88, marks=False)
    for ang, L, b in [(-158, 22, -0.15), (-22, 22, 0.15), (-128, 20, -0.1)]:
        a.fern(50, 87, ang, L, bend=b, fill=leafc, pairs=5)
    q = a.stem((50, 88), (52, 58), (50, 32), 1.5)
    x, y = q.pt(0.42); a.stem((x, y), (36, 52), (27, 42), 1.1); a.umbel(27, 42, -100, 11, fill, 6, 120, curl=curl)
    x, y = q.pt(0.6); a.stem((x, y), (64, 44), (73, 36), 1.1); a.umbel(73, 36, -80, 11, fill, 6, 120, curl=curl)
    x, y = q.pt(0.3); a.fern(x, y, -30, 14, fill=leafc, pairs=4)
    a.umbel(50, 32, -90, 18, fill, 9, 130, curl=curl)
    return a


# -------------------------------------------------------------- broad bean
def bean_seed(a, x, y):
    a.polar(x, y, lambda th: 1 - 0.1 * math.cos(th + math.pi / 2) ** 3, 15, 11.5, 0, "seed")
    a.line(f"M{x - 6},{y - 10.8} Q{x},{y - 12.4} {x + 6},{y - 10.8}", 2.4, 0.9, "dark")
    a.line(f"M{x - 8},{y + 3} Q{x},{y + 6.5} {x + 8},{y + 3}", 0.7, 0.4)


def bean_seedling():
    a = Art(); a.ground(62)
    a.oval(50, 71, 7.5, 5.6, 0, "seed"); a.line("M46,68.6 Q50,67.6 54,68.6", 1.6, 0.9, "dark")
    a.roots(50, 76, 3, 13, 44)
    a.ribbon((50, 66), (49, 50), (50, 36), 2.6, 1.6, "leaf")
    a.compound(50, 50, -158, 16, pairs=1, b=0.55, fill="sage", end=False, size=0.62)
    a.compound(50, 40, -24, 17, pairs=1, b=0.55, fill="sage", end=False, size=0.62)
    a.leaf(50, 36, -100, 7, 0.5, "sage"); a.leaf(50, 36, -70, 6, 0.5, "sage")
    return a


def bean_plant(top=14, nodes=5, flowers=False, pods=None, stemc="leaf", leafc="sage", droop=0):
    a = Art(); a.ground(88, marks=False)
    q = a.ribbon((50, 88), (52, 52), (50, top), 3.4, 1.6, stemc)
    for i in range(nodes):
        u = 0.16 + 0.68 * i / (nodes - 1); x, y = q.pt(u); side = -1 if i % 2 else 1
        L = 25 * (1 - 0.32 * u)
        ang = (-28 + droop) if side > 0 else (-152 - droop)
        if pods and i < nodes - 1 and i > 0:
            if pods == "green":
                a.ribbon((x, y), (x - side * 6, y - 6), (x - side * 12, y - 17), 5.6, 4.8, "deep", round_tip=True)
            else:
                a.ribbon((x, y), (x - side * 9, y + 1), (x - side * 12, y + 13), 4.4, 3.8, "dark", round_tip=True)
        a.compound(x, y, ang, L, pairs=2, b=0.52, fill=leafc, end=False, size=0.42, bend=0.08 * side)
        if flowers and i > 0:
            for k, (dx, dy) in enumerate([(3.4, -1), (5.6, -5), (2.6, -6.4)]):
                fx, fy = x - side * dx, y + dy
                a.leaf(fx, fy, -90 - side * (35 + 18 * k), 6.2, 0.62, "white", lw=0.8)
                a.dot(fx - side * 1.9, fy - 2.3, 1.05, "dark")
    a.leaf(50, top, -112, 7, 0.5, leafc); a.leaf(50, top, -64, 7, 0.5, leafc)
    return a


# ------------------------------------------------------------------ tomato
def tomato_seed(a, x, y):
    a.polar(x, y, lambda th: 1 + 0.035 * math.cos(17 * th) - 0.1 * max(0, math.cos(th - 0.5)) ** 8, 12, 10.5, 0, "straw")
    a.oval(x - 1, y + 0.5, 6.5, 5.5, 0, None, 0.7, la=0.4)


def tomato_seedling():
    a = Art(); a.ground(G)
    a.roots(50, G, 3, 12, 50)
    a.stem((50, G), (49, G - 10), (50, G - 19), 1.3)
    a.leaf(50, G - 19, -160, 15, 0.2, "pale"); a.leaf(50, G - 19, -20, 15, 0.2, "pale")
    a.compound(50, G - 19, -84, 14, pairs=1, b=0.46, size=0.5)
    return a


def tomato_plant(top=36, n=4, stage="young"):
    a = Art(); a.ground(88, marks=False)
    q = a.ribbon((50, 88), (51.5, 60), (50, top), 3.0, 1.5, "leaf")
    for i in range(n):
        u = 0.2 + 0.66 * i / (n - 1); x, y = q.pt(u); side = -1 if i % 2 else 1
        ang = -14 if side > 0 else -166
        if stage != "young" and i in (1, 2):
            ex, ey = x - side * 13, y + (3 if stage == "crop" else -3)
            a.stem((x, y), (x - side * 7, y - 5), (ex, ey), 1.0)
            if stage == "flower":
                for k, (dx, dy) in enumerate([(0, 0), (-5, -5), (3, -7)]):
                    a.flower(ex + side * dx * -1, ey + dy, 4.6, 5, "sun", "amber", 0.36, start=-90 + 20 * k, cr=1.3, lw=0.7)
            else:
                ripe = i == 1
                for k, (dx, dy, r) in enumerate([(3, 4, 5.6), (-4, 9, 5.2), (5, 13.5, 4.6)]):
                    fx, fy = ex + side * dx * -1, ey + dy
                    a.oval(fx, fy, r, r * 0.92, 0, "berry" if (ripe or k == 0 and False) else ("amber" if k == 0 else "unripe"))
                    for s in range(5):
                        a.leaf(fx, fy - r * 0.86, -90 + (s - 2) * 42, 3.0, 0.4, "deep", lw=0.6)
        a.compound(x, y, ang, 25 * (1 - 0.22 * u), pairs=2, b=0.46, size=0.4, bend=0.1 * side, edge="saw")
    a.compound(50, top, -100, 11, pairs=1, b=0.46, size=0.5, edge="saw")
    a.leaf(50, top, -50, 7, 0.4)
    return a


# ----------------------------------------------------------------- lettuce
def lettuce_seed(a, x, y):
    t = T(x, y, -24)
    a.leaf(*t(-15), -24, 30, 0.2, "white", skew=0.42)
    for o in (-1.3, 0, 1.3):
        a.line(f"M{P(t(-9, o))} L{P(t(9, o * 0.7))}", 0.6, 0.45)


def lettuce_seedling():
    a = Art(); a.ground(G)
    a.roots(50, G, 3, 11, 46)
    a.stem((50, G), (50, G - 4), (50, G - 8), 1.2)
    a.leaf(50, G - 8, -168, 11, 0.6, "pale"); a.leaf(50, G - 8, -12, 11, 0.6, "pale")
    a.toothleaf(50, G - 8, -96, 15, 9.5, 7, "leaf", 0.05)
    a.toothleaf(50, G - 8, -62, 9, 6, 7, "leaf", 0.05)
    return a


def lettuce_young():
    a = Art(); a.ground(82, marks=False)
    for ang, L in [(-170, 21), (-10, 21), (-142, 27), (-38, 27), (-114, 31), (-66, 31), (-90, 24)]:
        a.toothleaf(50, 82, ang, L, L * 0.6, 9, "leaf" if L > 22 else "unripe", 0.05)
    return a


def lettuce_crop():
    a = Art(); a.ground(84, marks=False)
    for ang, L, W, c in [(-172, 34, 21, "deep"), (-8, 34, 21, "deep"), (-146, 38, 26, "leaf"), (-34, 38, 26, "leaf"),
                         (-118, 40, 27, "leaf"), (-62, 40, 27, "leaf")]:
        a.toothleaf(50, 84, ang, L, W, 11, c, 0.05)
    a.polar(50, 62, lambda th: 1 + 0.035 * math.cos(9 * th), 18.5, 19.5, 0, "unripe")
    a.line("M40,50 Q52,56 52,78", 0.8, 0.5); a.line("M62,52 Q50,60 48,80", 0.8, 0.5); a.line("M44,62 Q50,58 57,63", 0.7, 0.4)
    return a


def lettuce_tall(seed=False):
    lc = "straw" if seed else "leaf"
    a = Art(); a.ground(88, marks=False)
    for ang, L in [(-168, 20), (-12, 20), (-146, 17), (-34, 17)]:
        a.toothleaf(50, 88, ang, L, L * 0.5, 9, "straw" if seed else "deep", 0.05)
    q = a.ribbon((50, 88), (51, 56), (50, 22), 3.4, 1.2, lc)
    for i in range(6):
        u = 0.14 + 0.085 * i; x, y = q.pt(u); side = -1 if i % 2 else 1
        a.leaf(x, y, -90 + side * 52, 13 - i * 1.1, 0.42, lc, vein=True)
    for i, (u, dx, dy) in enumerate([(0.62, -15, -8), (0.7, 14, -9), (0.8, -11, -9), (0.88, 10, -8), (1, 0, -7)]):
        x, y = q.pt(u); ex, ey = x + dx, y + dy
        a.stem((x, y), (x + dx * 0.4, y + dy * 0.2), (ex, ey), 0.9)
        for k, (ox, oy) in enumerate([(0, 0), (-3.4 if dx <= 0 else 3.4, 3.6)]):
            if seed:
                for s in range(7):
                    e = T(ex + ox, ey + oy, -90 + (s - 3) * 24)(4.6)
                    a.line(f"M{f(ex + ox)},{f(ey + oy)} L{P(e)}", 0.6, 0.55)
                a.dot(ex + ox, ey + oy + 0.6, 1.0, "bark")
            else:
                a.flower(ex + ox, ey + oy, 3.3, 9, "primrose", "sun", 0.34, cr=0.9, lw=0.6)
    return a


# -------------------------------------------------------------------- leek
def leek_seed(a, x, y):
    a.shape(f"M{x - 11},{y + 2} L{x - 5},{y - 9} L{x + 7},{y - 8} L{x + 12},{y + 1} L{x + 4},{y + 9} L{x - 7},{y + 8} Z", "dark")
    a.line(f"M{x - 5},{y - 9} L{x - 1},{y} L{x + 12},{y + 1} M{x - 1},{y} L{x - 7},{y + 8}", 0.7, 0.9, "bark")


def leek_seedling():
    a = Art(); a.ground(G)
    a.line(f"M38,{G} Q39,{G + 6} 38,{G + 11}", 0.8, 0.85, "soil"); a.line(f"M62,{G} Q61,{G + 7} 62,{G + 13}", 0.8, 0.85, "soil")
    a.line(f"M38,{G} C38,{G - 16} 38,{G - 24} 42.5,{G - 24} C47,{G - 24} 45.6,{G - 15} 45,{G - 12}", 1.5)
    a.oval(45, G - 11, 1.7, 2.1, 10, "dark", 0.5)
    a.ribbon((62, G), (61, G - 16), (63, G - 30), 1.9, 0.5, "sage")
    a.oval(63.3, G - 31, 1.6, 2.0, 15, "dark", 0.5)
    return a


def leek_young():
    a = Art(); a.ground(74)
    a.roots(50, 82, 4, 8, 80)
    for e, c in [((33, 34), (44, 48)), ((67, 36), (56, 50)), ((51, 22), (50, 44))]:
        a.ribbon((50, 66), c, e, 3.2, 0.4, "sage")
    a.ribbon((50, 82), (50, 72), (50, 62), 3.6, 3.2, "white")
    return a


def leek_crop():
    a = Art(); a.ground(60)
    a.roots(50, 87, 6, 9, 130)
    for e, c in [((17, 26), (42, 44)), ((83, 26), (58, 44)), ((30, 10), (44, 34)), ((70, 10), (56, 34)), ((50, 5), (50.5, 30))]:
        a.ribbon((50, 52), c, e, 7.5, 0.5, "sage")
    a.ribbon((50, 87.5), (50, 70), (50, 48), 11.5, 9.5, "white")
    a.line("M45.2,52 Q50,55 54.8,52", 0.8, 0.5); a.line("M46.4,57 L46.6,84 M53.6,57 L53.4,84", 0.6, 0.3)
    return a


def leek_tall(seed=False):
    lc, hc = ("straw", "straw") if seed else ("sage", "lilac")
    a = Art(); a.ground(88, marks=False)
    for e, c in [((20, 66), (40, 62)), ((80, 68), (60, 62)), ((30, 52), (44, 64))]:
        a.ribbon((50, 87), c, e, 4.5, 0.5, lc)
    a.ribbon((50, 88), (51, 60), (50, 30), 3.4, 2.6, lc)
    a.oval(50, 20, 14, 14, 0, hc)
    import random; rnd = random.Random(7)
    for k in range(34):
        r = 12.2 * math.sqrt((k + 0.5) / 34); th = k * 2.39996
        x, y = 50 + r * math.cos(th), 20 + r * math.sin(th)
        if seed:
            a.dot(x, y, 0.95, "dark")
        else:
            a.flower(x, y, 1.9, 4, "white", None, 0.5, start=rnd.random() * 90, lw=0.45)
    return a


# --------------------------------------------------------------- courgette
def courgette_seed(a, x, y):
    t = T(x, y, -90)
    a.leaf(*t(-15), -90, 31, 0.56, "white", skew=0.4)
    a.leaf(*t(-12), -90, 25, 0.5, None, lw=0.6, skew=0.4)


def courgette_seedling():
    a = Art(); a.ground(G)
    a.roots(50, G, 3, 12, 56)
    a.ribbon((50, G), (49.5, G - 8), (50, G - 15), 2.8, 2.4, "pale")
    a.leaf(50, G - 15, -164, 23, 0.6, "leaf", vein=True); a.leaf(50, G - 15, -16, 23, 0.6, "leaf", vein=True)
    a.lobedleaf(50, G - 16, -90, 6.5)
    return a


def courgette_leaves(a, spots, crown=(50, 84)):
    for (x, y), R in spots:
        q = a.ribbon(crown, ((crown[0] + x) / 2 + (x - crown[0]) * 0.1, (crown[1] + y) / 2 + 2), (x, y), 2.2, 1.6, "pale")
    for (x, y), R in spots:
        ang = math.degrees(math.atan2(y - crown[1], x - crown[0]))
        a.lobedleaf(x, y, ang, R, teeth=3)


def courgette_young():
    a = Art(); a.ground(84, marks=False)
    courgette_leaves(a, [((27, 62), 13), ((73, 62), 13), ((50, 50), 15)])
    return a


def courgette_flower():
    a = Art(); a.ground(84, marks=False)
    courgette_leaves(a, [((22, 54), 13), ((78, 54), 13), ((50, 40), 15)])
    a.ribbon((50, 84), (54, 76), (57, 70), 2.4, 2.0, "pale")
    a.leaf(34, 78, -150, 11, 0.4, "primrose")
    a.flower(58, 66, 13.5, 5, "sun", "amber", 0.62, start=-90, cr=3.2)
    return a


def courgette_crop():
    a = Art(); a.ground(84, marks=False)
    courgette_leaves(a, [((24, 44), 13), ((76, 46), 13), ((50, 30), 15)])
    for p0, c, p1 in [((45, 81), (30, 74), (13, 78)), ((55, 81), (70, 72), (87, 76))]:
        a.ribbon(p0, c, p1, 7.6, 6.6, "marrow", round_tip=True)
        ang = math.degrees(math.atan2(p1[1] - c[1], p1[0] - c[0]))
        a.leaf(p1[0], p1[1], ang - 22, 6, 0.4, "primrose", lw=0.7); a.leaf(p1[0], p1[1], ang + 22, 6, 0.4, "primrose", lw=0.7)
    return a


# ------------------------------------------------------------------- apple
SPOTS = [(-20, -6), (-9, -15), (5, -17), (17, -9), (22, 3), (9, -3), (-4, -3), (-15, 7), (-1, 10), (12, 12), (-24, 2)]


def apple_maiden():
    a = Art(); a.ground(88, marks=False)
    a.ribbon((58, 88), (58, 66), (58, 44), 2.4, 2.4, "bark")
    q = a.stem((50, 88), (48.5, 54), (50, 20), 1.9)
    a.oval(50, 81, 2.1, 1.5, 0, "bark", 0.8)
    a.line("M49.4,58 Q54,56 58,58", 1.2, 0.9, "soil")
    for i in range(8):
        u = 0.36 + 0.08 * i; x, y = q.pt(u); side = -1 if i % 2 else 1
        a.leaf(x, y, -90 + side * 58, 10 - i * 0.3, 0.46, "leaf", vein=True, edge="saw")
    a.leaf(50, 20, -96, 7, 0.44, "leaf", edge="saw")
    return a


def fork(a, x, y, ang, L, depth, lw):
    e = T(x, y, ang)(L); m = T(x, y, ang + (6 if depth % 2 else -6))(L * 0.5)
    a.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)}", lw, 0.9)
    if depth:
        sp = [0, 24, 27, 30][depth]
        fork(a, e[0], e[1], ang - sp, L * 0.74, depth - 1, lw * 0.68)
        fork(a, e[0], e[1], ang + sp * 0.9, L * 0.7, depth - 1, lw * 0.68)


def apple_winter():
    a = Art(); a.ground(88, marks=False)
    fork(a, 50, 62, -122, 21, 3, 2.3); fork(a, 50, 60, -58, 21, 3, 2.3); fork(a, 50, 58, -90, 20, 2, 2.0)
    a.ribbon((50, 88), (49.4, 72), (50, 56), 6.4, 4.2, "bark")
    return a


def apple_tree(kind):
    a = Art(); a.ground(88, marks=False)
    a.line("M50,64 Q42,58 36,50", 2.0, 0.9); a.line("M50,62 Q58,56 63,49", 2.0, 0.9)
    a.ribbon((50, 88), (49.4, 74), (50, 58), 6.4, 4.4, "bark")
    a.polar(50, 36, lambda th: 1 + 0.055 * math.cos(7 * th) + 0.03 * math.sin(11 * th), 33, 27, 0, "leaf")
    for dx, dy in [(-12, -8), (14, 4), (2, 3), (-20, 12), (20, -14)]:
        a.line(f"M{50 + dx - 4},{36 + dy} Q{50 + dx},{36 + dy - 3.4} {50 + dx + 4},{36 + dy}", 0.8, 0.35)
    for i, (dx, dy) in enumerate(SPOTS):
        x, y = 50 + dx, 36 + dy
        if kind == "blossom":
            a.flower(x, y, 4.4, 5, "pink" if i % 3 else "white", "sun", 0.7, start=-90 + i * 23, cr=1.1, lw=0.6)
        elif kind == "set":
            if i % 5 != 4:
                a.oval(x, y, 2.5, 2.4, 0, "unripe", 0.8)
        else:
            if i % 5 != 4:
                a.line(f"M{f(x)},{f(y - 3.6)} L{f(x + 0.8)},{f(y - 6)}", 0.8)
                a.oval(x, y, 4.2, 3.9, 0, "berry" if i % 4 else "amber", 0.9)
    if kind == "blossom":
        a.leaf(74, 72, 60, 3.4, 0.6, "pink", lw=0.6); a.leaf(27, 78, 110, 3.4, 0.6, "pink", lw=0.6)
    if kind == "ripe":
        a.oval(73, 84.4, 4.2, 3.9, 0, "berry", 0.9); a.line("M73,80.8 L73.9,78.6", 0.8)
    return a


# -------------------------------------------------------------- strawberry
def trifoliate(a, crown, end, L=15, fill="leaf"):
    x, y = end; ang = math.degrees(math.atan2(y - crown[1], x - crown[0]))
    a.stem(crown, ((crown[0] + x) / 2, (crown[1] + y) / 2 + 3), end, 1.1)
    for off in (-72, 72, 0):
        a.toothleaf(x, y, ang + off, L, L * 0.86, 13, fill, 0.06, edge="saw")


def berry(a, x, y, s=1.0, fill="berry"):
    a.shape(f"M{f(x - 5.4 * s)},{f(y)} C{f(x - 6.4 * s)},{f(y + 6 * s)} {f(x - 2 * s)},{f(y + 12 * s)} {f(x)},{f(y + 13 * s)} "
            f"C{f(x + 2 * s)},{f(y + 12 * s)} {f(x + 6.4 * s)},{f(y + 6 * s)} {f(x + 5.4 * s)},{f(y)} "
            f"C{f(x + 3 * s)},{f(y - 2.4 * s)} {f(x - 3 * s)},{f(y - 2.4 * s)} {f(x - 5.4 * s)},{f(y)} Z", fill)
    for dx, dy in [(-2.4, 2.6), (2.2, 2.4), (0, 5.6), (-2, 8), (2.2, 7.6)]:
        a.dot(x + dx * s, y + dy * s, 0.5, "primrose")
    for k in range(5):
        a.leaf(x, y - 1.2 * s, -90 + (k - 2) * 44, 4.2 * s, 0.42, "deep", lw=0.6)


def strawberry_young():
    a = Art(); a.ground(84, marks=False)
    for e in [(30, 60), (70, 60), (50, 48)]:
        trifoliate(a, (50, 84), e)
    return a


def strawberry_flower():
    a = Art(); a.ground(84, marks=False)
    for e in [(26, 62), (74, 62), (50, 52)]:
        trifoliate(a, (50, 84), e, 14)
    for (x, y), c in [((38, 30), (40, 60)), ((63, 36), (60, 62))]:
        a.stem((50, 84), c, (x, y), 1.0)
        a.flower(x, y, 7, 5, "white", "sun", 0.78, cr=2.2)
    a.stem((63, 50), (66, 46), (70, 46), 0.8); a.oval(71.4, 46, 2.2, 2.0, 0, "unripe", 0.8)
    return a


def strawberry_crop():
    a = Art(); a.ground(86, marks=False)
    for e in [(30, 46), (70, 46), (50, 34)]:
        trifoliate(a, (50, 86), e, 14)
    for (x, y), c, s, fill in [((22, 62), (26, 54), 1.0, "berry"), ((79, 60), (74, 52), 0.95, "berry"), ((60, 68), (60, 62), 0.7, "white")]:
        a.stem((50, 86), c, (x, y - 1), 1.0)
        berry(a, x, y, s, fill)
    return a


def strawberry_runner():
    a = Art(); a.ground(84)
    for e in [(14, 66), (40, 66), (27, 54)]:
        trifoliate(a, (27, 84), e, 12)
    a.stem((28, 82), (50, 60), (70, 83), 1.0, col="berry"); a.stem((70, 83), (82, 72), (91, 77), 1.0, col="berry")
    a.roots(70, 84, 3, 6, 60)
    for e in [(63, 73), (77, 73)]:
        trifoliate(a, (70, 83), e, 6.5)
    return a


def strawberry_winter():
    a = Art(); a.ground(84, marks=False)
    for e, c in [((32, 76), "rust"), ((68, 76), "deep"), ((50, 68), "rust")]:
        trifoliate(a, (50, 84), e, 10, c)
    a.oval(50, 83, 4, 2.4, 0, "bark", 0.9)
    return a


# ---------------------------------------------------------------- snowdrop
def bulb(a, x, y, s=1.0, roots=True):
    if roots:
        a.roots(x, y + 8.6 * s, 5, 7 * s, 110)
    a.shape(f"M{f(x)},{f(y - 11 * s)} C{f(x + 3 * s)},{f(y - 9 * s)} {f(x + 7.4 * s)},{f(y - 3 * s)} {f(x + 7.4 * s)},{f(y + 2 * s)} "
            f"C{f(x + 7.4 * s)},{f(y + 7 * s)} {f(x + 3.4 * s)},{f(y + 9 * s)} {f(x)},{f(y + 9 * s)} "
            f"C{f(x - 3.4 * s)},{f(y + 9 * s)} {f(x - 7.4 * s)},{f(y + 7 * s)} {f(x - 7.4 * s)},{f(y + 2 * s)} "
            f"C{f(x - 7.4 * s)},{f(y - 3 * s)} {f(x - 3 * s)},{f(y - 9 * s)} {f(x)},{f(y - 11 * s)} Z", "seed")
    a.shape(f"M{f(x)},{f(y - 11 * s)} C{f(x + 3 * s)},{f(y - 9 * s)} {f(x + 7.4 * s)},{f(y - 3 * s)} {f(x + 7.4 * s)},{f(y + 2 * s)} "
            f"C{f(x + 7.4 * s)},{f(y + 7 * s)} {f(x + 3.4 * s)},{f(y + 9 * s)} {f(x)},{f(y + 9 * s)} "
            f"C{f(x + 3.4 * s)},{f(y + 6 * s)} {f(x + 4.6 * s)},{f(y - 1 * s)} {f(x)},{f(y - 11 * s)} Z", "shade", 0, fa=0.11)
    a.line(f"M{f(x)},{f(y - 10 * s)} C{f(x - 3.6 * s)},{f(y - 3 * s)} {f(x - 3 * s)},{f(y + 4 * s)} {f(x - 1.4 * s)},{f(y + 8.6 * s)}", 0.7, 0.4)
    a.line(f"M{f(x)},{f(y - 10 * s)} C{f(x + 3.6 * s)},{f(y - 3 * s)} {f(x + 3 * s)},{f(y + 4 * s)} {f(x + 1.4 * s)},{f(y + 8.6 * s)}", 0.7, 0.4)


def snowdrop_bulb():
    a = Art(); a.ground(38, marks=False)
    for dx, dy, w in [(-30, 46, 4), (27, 50, 3), (-24, 78, 3), (28, 74, 4)]:
        a.line(f"M{50 + dx},{dy} L{50 + dx + w},{dy}", 0.9, 0.55, "soil")
    bulb(a, 50, 62, 1.7); return a


def snowdrop_shoots():
    a = Art(); a.ground(64)
    a.ribbon((48.4, 70), (47.6, 60), (46.6, 49), 3.6, 0.8, "sage"); a.ribbon((51.6, 70), (52.4, 58), (53.6, 45), 3.6, 0.8, "sage")
    bulb(a, 50, 79, 0.85); return a


def snowdrop_flower():
    a = Art(); a.ground(66)
    a.ribbon((47.6, 72), (43, 48), (35, 26), 4.0, 0.9, "sage", round_tip=True)
    a.ribbon((52.4, 72), (55, 52), (62, 38), 4.0, 0.9, "sage", round_tip=True)
    a.stem((50, 72), (49, 34), (56, 17), 1.3); a.stem((56, 17), (61, 9), (66, 16), 1.1)
    a.leaf(56, 17, -62, 9, 0.24, "sage", lw=0.8)
    a.line("M66,16 L66,19", 1.0)
    a.leaf(66, 22, 90, 11, 0.62, "white"); a.line("M63.6,30.4 Q66,28.6 68.4,30.4", 1.6, 0.95, "deep")
    a.leaf(66, 21.5, 120, 19, 0.42, "white", skew=0.55); a.leaf(66, 21.5, 60, 19, 0.42, "white", skew=0.55)
    a.oval(66, 20.4, 2.2, 2.6, 0, "leaf", 0.9)
    bulb(a, 50, 81, 0.8); return a


def snowdrop_seed():
    a = Art(); a.ground(66)
    a.ribbon((47.6, 72), (36, 44), (17, 46), 4.2, 0.9, "sage", round_tip=True)
    a.ribbon((52.4, 72), (60, 44), (80, 40), 4.2, 0.9, "sage", round_tip=True)
    a.ribbon((50, 72), (49, 50), (44, 24), 3.6, 0.9, "sage", round_tip=True)
    a.stem((50.6, 72), (60, 40), (71, 60), 1.2)
    a.oval(72, 62.4, 3.6, 4.4, -20, "unripe")
    bulb(a, 50, 81, 0.8); return a


def snowdrop_dormant():
    a = Art(); a.ground(40)
    a.line("M46,40 Q40,36 33,39", 1.2, 0.8, "straw"); a.line("M52,40 Q58,37 64,39.4", 1.2, 0.8, "straw")
    bulb(a, 62, 68, 0.75, roots=False); bulb(a, 47, 64, 1.25); return a


# --------------------------------------------------------------- sunflower
def sunflower_seed(a, x, y):
    t = T(x, y, -100)
    a.leaf(*t(-15), -100, 31, 0.52, "dark", skew=0.42)
    for o, l0, l1 in [(-3.2, -6, 6), (0, -10, 11), (3.2, -6, 6)]:
        a.line(f"M{P(t(l0, o))} Q{P(t(0, o * 1.3))} {P(t(l1, o * 0.6))}", 1.0, 0.9, "white")


def sunflower_seedling():
    a = Art(); a.ground(G)
    a.roots(50, G, 3, 13, 50)
    a.ribbon((50, G), (49.4, G - 10), (50, G - 19), 2.6, 2.2, "pale")
    a.leaf(50, G - 19, -162, 17, 0.56, "leaf", vein=True); a.leaf(50, G - 19, -18, 17, 0.56, "leaf", vein=True)
    a.leaf(50, G - 19, -108, 8, 0.5, "leaf"); a.leaf(50, G - 19, -72, 8, 0.5, "leaf")
    return a


def sun_leaves(a, q, us, fill="leaf", hang=0, L=21):
    for i, u in enumerate(us):
        x, y = q.pt(u); side = -1 if i % 2 else 1
        ang = (-20 + hang) if side > 0 else (-160 - hang)
        e = T(x, y, ang)(5); a.line(f"M{f(x)},{f(y)} L{P(e)}", 1.0)
        a.leaf(e[0], e[1], ang + side * 8, L * (1 - 0.25 * u), 0.72, fill, vein=True, skew=0.36, edge="saw")


def sunflower_young():
    a = Art(); a.ground(88, marks=False)
    q = a.ribbon((50, 88), (51, 62), (50, 38), 3.4, 2.2, "leaf")
    sun_leaves(a, q, [0.22, 0.44, 0.66, 0.86])
    a.leaf(50, 38, -112, 9, 0.55, "leaf"); a.leaf(50, 38, -68, 9, 0.55, "leaf"); a.leaf(50, 38, -90, 6, 0.6, "unripe")
    return a


def sunflower_flower():
    a = Art(); a.ground(88, marks=False)
    q = a.ribbon((50, 88), (51.5, 62), (50, 38), 3.6, 2.6, "leaf")
    sun_leaves(a, q, [0.2, 0.42, 0.64], L=20)
    for k in range(18):
        a.leaf(50, 25, k * 20, 21, 0.2, "sun", lw=0.8, skew=0.6)
    for k in range(18):
        a.leaf(50, 25, 10 + k * 20, 18, 0.2, "amber", lw=0.7, skew=0.6)
    a.oval(50, 25, 9.5, 9.5, 0, "bark")
    for k in range(26):
        r = 8.0 * math.sqrt((k + 0.5) / 26); th = k * 2.39996
        a.dot(50 + r * math.cos(th), 25 + r * math.sin(th), 0.6, "dark")
    return a


def sunflower_seedhead():
    a = Art(); a.ground(88, marks=False)
    q = a.ribbon((50, 88), (50, 56), (52, 30), 3.6, 2.6, "straw")
    sun_leaves(a, q, [0.22, 0.46, 0.68], fill="straw", hang=58, L=18)
    a.ribbon((52, 30), (54, 20), (62, 22), 2.6, 2.4, "straw")
    for k in range(11):
        a.leaf(64, 30, -150 + k * 21, 14.5, 0.3, "sage", lw=0.7)
    a.oval(65, 32, 11.5, 10.5, 25, "dark")
    for k in range(30):
        r = 0.86 * math.sqrt((k + 0.5) / 30); th = k * 2.39996
        x, y = T(65, 32, 25)(11.5 * r * math.cos(th), 10.5 * r * math.sin(th))
        a.dot(x, y, 0.75, "straw")
    return a


# ------------------------------------------------------------ the full list
PLANTS = [
    ("carrot", "Carrot", [
        ("seed", "Seed", sown(carrot_seed)), ("seedling", "Seedling", carrot_seedling), ("young", "Young plant", carrot_young),
        ("crop", "Ready to pull", carrot_crop), ("flower", "In flower (year 2)", lambda: carrot_tall("white", 0, "leaf")),
        ("seedhead", "Gone to seed", lambda: carrot_tall("straw", 1, "straw"))]),
    ("broad-bean", "Broad bean", [
        ("seed", "Seed", sown(bean_seed)), ("seedling", "Seedling", bean_seedling), ("young", "Young plant", lambda: bean_plant(40, 4)),
        ("flower", "In flower", lambda: bean_plant(14, 5, flowers=True)), ("crop", "Pods to pick", lambda: bean_plant(14, 5, pods="green")),
        ("seedhead", "Dry pods for seed", lambda: bean_plant(14, 5, pods="dry", stemc="straw", leafc="straw", droop=50))]),
    ("tomato", "Tomato", [
        ("seed", "Seed", sown(tomato_seed)), ("seedling", "Seedling", tomato_seedling), ("young", "Young plant", lambda: tomato_plant(40, 4, "young")),
        ("flower", "In flower", lambda: tomato_plant(16, 5, "flower")), ("crop", "Fruiting", lambda: tomato_plant(16, 5, "crop"))]),
    ("lettuce", "Lettuce", [
        ("seed", "Seed", sown(lettuce_seed)), ("seedling", "Seedling", lettuce_seedling), ("young", "Young plant", lettuce_young),
        ("crop", "Ready to cut", lettuce_crop), ("flower", "Bolted, in flower", lambda: lettuce_tall(False)),
        ("seedhead", "Gone to seed", lambda: lettuce_tall(True))]),
    ("leek", "Leek", [
        ("seed", "Seed", sown(leek_seed)), ("seedling", "Seedling", leek_seedling), ("young", "Young plant", leek_young),
        ("crop", "Ready to lift", leek_crop), ("flower", "In flower (year 2)", lambda: leek_tall(False)),
        ("seedhead", "Gone to seed", lambda: leek_tall(True))]),
    ("courgette", "Courgette", [
        ("seed", "Seed", sown(courgette_seed)), ("seedling", "Seedling", courgette_seedling), ("young", "Young plant", courgette_young),
        ("flower", "In flower", courgette_flower), ("crop", "Fruiting", courgette_crop)]),
    ("sunflower", "Sunflower", [
        ("seed", "Seed", sown(sunflower_seed)), ("seedling", "Seedling", sunflower_seedling), ("young", "Young plant", sunflower_young),
        ("flower", "In flower", sunflower_flower), ("seedhead", "Gone to seed", sunflower_seedhead)]),
    ("strawberry", "Strawberry", [
        ("young", "Young plant", strawberry_young), ("flower", "In flower", strawberry_flower), ("crop", "Fruiting", strawberry_crop),
        ("runner", "Sending runners", strawberry_runner), ("dormant", "Winter", strawberry_winter)]),
    ("snowdrop", "Snowdrop", [
        ("bulb", "Bulb", snowdrop_bulb), ("shoots", "Shoots", snowdrop_shoots), ("flower", "In flower", snowdrop_flower),
        ("seedhead", "In seed", snowdrop_seed), ("dormant", "Dormant", snowdrop_dormant)]),
    ("apple", "Apple", [
        ("young", "Young tree", apple_maiden), ("dormant", "Winter", apple_winter), ("flower", "Blossom", lambda: apple_tree("blossom")),
        ("set", "Fruit set", lambda: apple_tree("set")), ("crop", "Ready to pick", lambda: apple_tree("ripe"))]),
]


def sheet(mode, cell=150, cols=6):
    bg, card, ink, soft = [("#F8F1E5", "#FFFCF6", "#15271D", "#3A5549"), ("#0C1C14", "#142414", "#F1EADB", "#A7B5A5")][mode]
    pad, lab, head = 14, 26, 30
    W = pad + cols * (cell + pad); rowh = head + cell + lab + 8
    H = pad + len(PLANTS) * rowh + pad
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
           f'<rect width="{W}" height="{H}" fill="{bg}"/>']
    for r, (slug, name, stages) in enumerate(PLANTS):
        y0 = pad + r * rowh
        out.append(f'<text x="{pad}" y="{y0 + 21}" font-family="Georgia, serif" font-size="20" fill="{ink}">{name}</text>')
        for c, (st, label, fn) in enumerate(stages):
            x = pad + c * (cell + pad); y = y0 + head
            out.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="14" fill="{card}"/>')
            out.append(f'<g transform="translate({x},{y}) scale({cell / 100})" stroke-linecap="round" stroke-linejoin="round">{fn().body(mode)}</g>')
            out.append(f'<text x="{x + cell / 2}" y="{y + cell + 17}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="12.5" fill="{soft}">{label}</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out"
    n = 0
    for mode, look in enumerate(("light", "dark")):
        os.makedirs(os.path.join(out, look), exist_ok=True)
        for slug, name, stages in PLANTS:
            for st, label, fn in stages:
                with open(os.path.join(out, look, f"plant-{slug}-{st}.svg"), "w", encoding="utf-8") as fh:
                    fh.write(fn().svg(mode)); n += 1
        with open(os.path.join(out, f"sheet-{look}.svg"), "w", encoding="utf-8") as fh:
            fh.write(sheet(mode))
    print(n // 2, "drawings, each in light and dark, written to", out)
