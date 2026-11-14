"""Draws the diagrams for Windfall's fungus key, in colour, on a 100 by 100 grid.

    python3 fungus_diagrams.py Design/Icons

writes fungus-<name>.svg for each. Keep fungus_kit.py beside this file.
Every drawing is Claude's own diagram of a feature. None is traced from
a photograph or a book.
"""
import math, os, sys
from fungus_kit import Art, C, LINE, SHADE, f, pts_d, smooth_d, rot, ellipse_pts

D = {}


def new(name):
    D[name] = Art(); return D[name]


def shroom(a, cx=50, gy=86, yb=42, w=31, h=23, shape="dome", fill="brown", depth=8, ufill="gill", kind="gills",
           st=10.0, sb=13.0, bend=0.0, base_dx=0.0, bulb=0.0, umbo=0.0, n=9, thick=0.7, stem_fill="stem", rim=1.6, uline=SHADE):
    """A whole mushroom seen a little from below: underside, stem, then the cap on top."""
    a.underside(cx, yb, w * 0.97, depth, ufill, kind, n, st, uline, thick)
    at = a.stem((cx, yb), (cx + base_dx, gy), st, sb, bend, stem_fill, bulb)
    on = a.cap(cx, yb, w, h, shape, fill, rim, umbo)
    return at, on


# ====================================================== the ten forms

a = new("form-gills"); a.ground(86)
shroom(a, w=36, h=26, yb=44, fill="chestnut", depth=10, n=10, st=11, sb=14)

a = new("form-pores"); a.ground(87)
shroom(a, yb=40, w=34, h=22, shape="bun", fill="brown", depth=10, ufill="pore", kind="pores", st=14, sb=20, bulb=3, gy=87)

a = new("form-spines"); a.ground(87)
cx, yb, w = 48, 40, 32
a.underside(cx, yb, w * 0.97, 5, "cream", "none")
for row, (r, L) in enumerate(((0.35, 5.5), (1.0, 6.0))):
    for k in range(15 if row else 12):
        u = -0.92 + 1.84 * (k + 0.5) / (15 if row else 12)
        x, y = cx + u * w, yb + 5 * (1 - u * u) * r
        if abs(x - 53) > 5.5 or row == 0:
            a.poly([(x - 1.1, y), (x + 1.1, y), (x + 0.15, y + L)], "cream", sw=0.9)
a.stem((53, yb), (55, 87), 11, 14, 1.5, "cream")
a.cap(cx, yb, w, 15, "flat", "apricot", 1.6)
a.curve([(26, 34), (36, 31), (48, 33)], stroke=SHADE, sw=0.8, so=0.25)

a = new("form-ridges"); a.ground(88, grass=False)
rimL, rimR = (15, 30), (85, 30)
body = [rimL, (27, 44), (39, 60), (44, 76), (45, 86), (55, 86), (56, 76), (61, 60), (73, 44), rimR]
a.path(smooth_d(body) + " Z", "yolk")
for sx in (-1, 1):
    for x0, x1, yy in [(24, 6, 80), (16, 3.5, 78), (9, 1.5, 76)]:
        a.curve([(50 + sx * x0, 36), (50 + sx * (x0 * 0.55 + x1 * 0.45), 54), (50 + sx * x1, yy)], stroke="rust", sw=1.2, so=0.75)
    a.curve([(50 + sx * 20, 37), (50 + sx * 15.5, 45), (50 + sx * 12.5, 55)], stroke="rust", sw=1.0, so=0.7)
    a.curve([(50 + sx * 30, 35), (50 + sx * 24, 42)], stroke="rust", sw=1.0, so=0.7)
a.line(50, 40, 50, 82, stroke="rust", sw=1.1, so=0.7)
top = [(15, 30), (24, 24), (33, 27), (42, 22), (52, 26), (62, 21), (72, 26), (80, 23), (85, 30), (76, 35), (64, 38), (50, 39), (36, 38), (24, 35)]
a.blob(top, "#F7D768")
a.blob([(38, 29), (50, 27), (62, 29), (58, 33), (50, 34), (42, 33)], SHADE, stroke=None, fo=0.16)
a.shade([(61, 60), (73, 44), (85, 30), (76, 35), (66, 40), (58, 62), (56, 86), (55, 86)], 0.14)


def shelf(a, x, y, L, T, fill="tan", under="cream", zones=(), lobes=0):
    """One bracket standing out from a trunk at x: the top surface and a pale underside."""
    top = [(x, y), (x + L * 0.3, y - T * 0.22), (x + L * 0.68, y - T * 0.08), (x + L, y + T * 0.42)]
    if lobes:
        top = [(x, y)] + [(x + L * t, y - T * 0.2 + T * 0.62 * t * t + (T * 0.09 if i % 2 else -T * 0.05)) for i, t in enumerate([0.18, 0.36, 0.54, 0.72, 0.88])] + [(x + L, y + T * 0.42)]
    bot = [(x + L, y + T * 0.42), (x + L * 0.7, y + T * 0.86), (x + L * 0.35, y + T * 1.0), (x, y + T * 0.95)]
    a.path(smooth_d(top + bot[1:]) + " Z", under)
    mid = [(x + L, y + T * 0.42), (x + L * 0.72, y + T * 0.5), (x + L * 0.36, y + T * 0.56), (x, y + T * 0.5)]
    a.path(smooth_d(top + mid[1:]) + " Z", fill)
    for zf, col in zones:
        zl = [(x, y + T * 0.5 * zf), (x + L * 0.36 * 1, y - T * 0.2 + T * 0.76 * zf), (x + L * (0.66 + 0.2 * zf), y + T * (0.0 + 0.46 * zf))]
        a.curve(zl, stroke=col, sw=1.5, so=0.8)
    a.shade([(x + L * 0.5, y + T * 0.7), (x + L * 0.96, y + T * 0.47), (x + L * 0.7, y + T * 0.84), (x + L * 0.35, y + T * 0.97), (x + 1.5, y + T * 0.92), (x + 1.5, y + T * 0.8)], 0.12, of=under)


a = new("form-bracket"); a.trunk(6, 26)
shelf(a, 26, 16, 50, 22, "tan", zones=((0.5, "chestnut"),))
shelf(a, 26, 52, 66, 28, "tan", zones=((0.5, "chestnut"),))

a = new("form-ball"); a.ground(84)
ball = [(50, 34), (66, 38), (76, 52), (76, 66), (66, 79), (50, 83), (34, 79), (24, 66), (24, 52), (34, 38)]
a.blob(ball, "cream")
a.shade([(58, 36), (70, 42), (77, 56), (75, 70), (64, 80), (52, 83), (62, 74), (68, 60), (66, 46)], 0.14)
for x, y in [(38, 46), (46, 42), (55, 44), (33, 56), (42, 54), (50, 52), (59, 55), (38, 65), (47, 63), (56, 66), (64, 62), (44, 73), (53, 75)]:
    a.dot(x, y, 1.0, "tan"); a.dot(x, y, 1.0, SHADE, 0.25)
a.shine([(33, 50), (36, 44), (42, 40)], 0.6, 2)

a = new("form-cup")
a.twig([(4, 80), (30, 76), (62, 80), (96, 74)], 9)
for mx in (14, 36, 78):
    a.blob([(mx - 7, 76), (mx - 3, 71), (mx + 3, 72), (mx + 7, 76), (mx + 2, 79), (mx - 4, 79)], "moss", sw=1.0)
a.path("M23,36 C24,56 38,70 47,70 L46,77 L54,77 L53,70 C62,70 76,56 77,36 Z", "#F2D3C4")
a.shade([(60, 66), (72, 52), (77, 36), (70, 36), (66, 52), (56, 66), (53, 70)], 0.14)
a.oval(50, 36, 27, 10, "scarlet")
a.path(pts_d(ellipse_pts(50, 37.5, 21, 6.5, 0, 24, 0, 180)), "deepred", stroke=None, fo=0.45)
a.shine([(30, 34), (38, 30), (48, 28.5)], 0.45, 1.6)

a = new("form-club"); a.ground(87, grass=False)
a.tubes([([(50, 88), (50, 70), (50, 52), (50, 30), (50, 12)], 6.5),
         ([(50, 74), (40, 62), (33, 46), (31, 24)], 5.6), ([(50, 74), (60, 62), (67, 46), (69, 24)], 5.6),
         ([(38, 58), (26, 52), (18, 40), (15, 30)], 5.0), ([(62, 58), (74, 52), (82, 40), (85, 30)], 5.0),
         ([(34, 48), (25, 38), (23, 22)], 4.6), ([(66, 48), (75, 38), (77, 22)], 4.6),
         ([(50, 44), (43, 30), (41, 16)], 4.8), ([(50, 44), (57, 30), (59, 18)], 4.8),
         ([(50, 88), (50, 76)], 10)], "coral")

a = new("form-jelly")
a.twig([(3, 78), (32, 73), (64, 76), (97, 70)], 10)
brain = [(18, 72), (16, 58), (24, 46), (34, 44), (38, 33), (50, 28), (60, 34), (68, 31), (78, 40), (78, 52), (86, 60), (84, 71), (66, 75), (40, 74)]
a.blob(brain, "jelly")
a.shade([(66, 33), (78, 40), (78, 52), (86, 60), (84, 71), (66, 75), (74, 62), (70, 48)], 0.13)
for fold in ([(24, 62), (30, 54), (40, 56), (44, 64)], [(38, 42), (46, 40), (50, 48), (44, 52)], [(54, 60), (60, 52), (70, 54), (72, 62)],
             [(56, 36), (62, 40), (60, 46)], [(30, 68), (40, 68), (48, 71)]):
    a.curve(fold, stroke="rust", sw=1.2, so=0.75)
a.shine([(24, 54), (28, 48), (34, 47)], 0.6, 1.8); a.shine([(42, 34), (48, 31)], 0.6, 1.8)

# ====================================================== spore prints

def spore(name, col):
    a = new(name)
    sq = rot([(16, 16), (84, 16), (84, 84), (16, 84)], -4, 50, 50)
    a.poly(sq, "paper", sw=0)
    a.poly(rot([(50, 16), (84, 16), (84, 84), (50, 84)], -4, 50, 50), "paperdark", sw=0)
    for k in range(26):
        ang = math.radians(360 * k / 26 + 2)
        r0 = 7 if k % 2 == 0 else 13
        a.line(50 + r0 * math.cos(ang), 50 + r0 * math.sin(ang), 50 + 29 * math.cos(ang), 50 + 29 * math.sin(ang), stroke=col, sw=1.75)
    a.poly(sq, None, sw=1.5)

spore("spore-white", "#F2ECDD"); spore("spore-pink", "#E08E8A"); spore("spore-brown", "#A9602C"); spore("spore-black", "#2F2623")

# ====================================================== the stem

a = new("stem-volva"); a.soil_cut(66, depth=28)
a.underside(50, 28, 30, 7, "white", "gills", 9, 9)
at = a.stem((50, 28), (50, 82), 9, 11, 0, "white", bulb=3)
a.volva(50, 86, 22, 22, "white")
a.ring(at, 0.22, 2.3, 9, "white")
a.cap(50, 28, 31, 19, "dome", "pale_olive")

a = new("stem-ring"); a.ground(87)
at, on = shroom(a, yb=38, w=33, h=23, fill="tan", depth=8, gy=87, st=10, sb=13)
a.ring(at, 0.3, 2.5, 11, "cream")

a = new("stem-plain"); a.ground(87)
shroom(a, yb=38, w=33, h=23, fill="tan", depth=8, gy=87, st=10, sb=13)


def oyster(a, x, y, L, T, fill="slate"):
    """A shell-shaped cap fixed to wood at x, with gills running back to the join."""
    top = [(x, y), (x + L * 0.3, y - T * 0.5), (x + L * 0.75, y - T * 0.38), (x + L, y + T * 0.2)]
    bot = [(x + L, y + T * 0.2), (x + L * 0.72, y + T * 0.8), (x + L * 0.34, y + T * 1.0), (x, y + T * 0.72)]
    a.path(smooth_d(top + bot[1:]) + " Z", "cream")
    for k in range(5):
        t = (k + 0.6) / 5.4
        ex = x + L * (1 - t * 0.98); ey = y + T * (0.2 + 0.8 * math.sin(t * math.pi * 0.62)) - 1.2
        a.curve([(x + 2, y + T * 0.5), ((x + ex) / 2, (y + T * 0.5 + ey) / 2 + 1), (ex, ey)], sw=0.75)
    mid = [(x + L, y + T * 0.2), (x + L * 0.7, y + T * 0.2), (x + L * 0.32, y + T * 0.26), (x, y + T * 0.3)]
    a.path(smooth_d(top + mid[1:]) + " Z", fill)
    a.shine([(x + L * 0.22, y - T * 0.26), (x + L * 0.42, y - T * 0.34), (x + L * 0.6, y - T * 0.26)], 0.4, 1.5)

a = new("stem-side"); a.trunk(6, 26)
oyster(a, 26, 24, 56, 26); oyster(a, 26, 62, 68, 28)

a = new("veil-cobweb"); a.ground(87)
a.underside(50, 46, 27, 5, "gillbrown", "gills", 7, 12)
at = a.stem((50, 46), (50, 87), 12, 15, 0, "stem", bulb=3)
for sx in (-1, 1):
    web = [(50 + sx * 26, 47), (50 + sx * 16, 49), (50 + sx * 6, 50), (50 + sx * 6.4, 67), (50 + sx * 15, 58)]
    a.poly(web, "white", stroke=None, fo=0.45)
    for k in range(4):
        t = k / 3
        a.line(50 + sx * (25 - 15 * t), 48 + 1.5 * t, 50 + sx * 6.2, 66 - 13 * t, sw=0.5)
a.path("M43.6,66 L56.4,66 L56.6,71 L43.4,71 Z", "rust", sw=0)
a.cap(50, 46, 28, 25, "bun", "violet", 1.4)

a = new("stem-scabers"); a.ground(88)
a.underside(50, 30, 27, 6, "#D8CDB0", "pores", 9, 12)
at = a.stem((50, 30), (51, 88), 12, 17, 1.5, "white")
for k in range(22):
    t = 0.16 + 0.78 * ((k * 0.618) % 1); u = ((k * 0.377) % 1) * 1.5 - 0.75
    x, y, w = at(t)
    a.oval(x + u * w, y, 1.3, 0.9, "black", sw=0, ang=30)
a.cap(50, 30, 28, 18, "bun", "orange", 1.4)

a = new("stem-net"); a.ground(88)
a.underside(50, 38, 31, 7, "#EFE6C4", "pores", 9, 14)
at = a.stem((50, 38), (50, 88), 15, 22, 0, "cream", bulb=4.5)
for k in range(9):
    t0 = 0.04 + k * 0.09
    for sx in (-1, 1):
        p = []
        for j in range(7):
            tt = t0 + j * 0.035; x, y, w = at(min(tt, 0.98)); p.append((x + sx * w * (-0.92 + 1.84 * j / 6), y))
        if t0 + 0.21 < 0.9:
            a.curve(p, stroke="brown", sw=0.8, so=0.85)
a.cap(50, 38, 32, 21, "bun", "brown", 1.5)

# ====================================================== the cap

a = new("cap-scaly"); a.ground(91)
a.underside(50, 32, 36, 6, "white", "gills", 11, 5)
at = a.stem((50, 32), (50, 90), 4.6, 6.4, 0, "cream", bulb=3.2)
for k in range(11):
    x, y, w = at(0.3 + k * 0.058)
    a.path(f"M{f(x - w)},{f(y)} L{f(x - w * 0.3)},{f(y + 1.6)} L{f(x + w * 0.3)},{f(y)} L{f(x + w)},{f(y + 1.6)}", None, stroke="brown", sw=0.9, so=0.9)
a.ring(at, 0.15, 2.3, 4.5, "cream", wavy=False)
on = a.cap(50, 32, 37, 13, "flat", "cream", 1.5, umbo=0.42)
for u, v in [(-0.8, 0.5), (-0.62, 0.75), (-0.66, 0.35), (-0.44, 0.9), (-0.46, 0.55), (-0.3, 0.74), (-0.26, 0.4), (-0.1, 0.62),
             (0.1, 0.62), (0.26, 0.4), (0.3, 0.74), (0.46, 0.55), (0.44, 0.9), (0.66, 0.35), (0.62, 0.75), (0.8, 0.5), (0, 0.36), (-0.52, 0.16), (0.52, 0.16)]:
    x, y = on(u, v)
    a.path(f"M{f(x - 2.2)},{f(y + 0.9)} Q{f(x)},{f(y - 1.8)} {f(x + 2.2)},{f(y + 0.9)} Z", "brown", sw=0.6)
x, y = on(0, 1)
a.blob([(x - 6, y + 3.4), (x - 3, y + 0.3), (x, y - 0.2), (x + 3, y + 0.3), (x + 6, y + 3.4), (x, y + 4.4)], "chestnut", sw=0.8)

a = new("cap-slimy"); a.ground(88)
a.underside(50, 40, 32, 8, "pore", "pores", 9, 12)
at = a.stem((50, 40), (50, 88), 12, 15, 0, "cream")
a.ring(at, 0.24, 1.9, 5, "#D9C9E0")
on = a.cap(50, 40, 33, 22, "bun", "chestnut", 1.6)
a.shine([on(-0.7, 0.6), on(-0.52, 0.82), on(-0.25, 0.93)], 0.75, 2.6)
a.shine([on(0.1, 0.9), on(0.3, 0.85)], 0.55, 1.8)
a.shine([on(-0.78, 0.25), on(-0.74, 0.4)], 0.6, 1.6)
for x, y, r in [(19, 47, 2.2), (79, 49, 2.6), (30, 52, 1.6)]:
    a.drop(x, y, r, "#FFFFFF", 0.9); a.o[-1] = a.o[-1].replace('fill="#FFFFFF"', 'fill="#FFFFFF" fill-opacity="0.75"')

a = new("cap-inky"); a.ground(90)
a.stem((50, 50), (50, 90), 8, 10, 0, "white", bulb=1)
bell = [(37, 62), (36, 44), (39, 26), (45, 13), (50, 10), (55, 13), (61, 26), (64, 44), (63, 62)]
a.path(smooth_d(bell) + " L60,58 L57,63 L53,58 L50,64 L46,58 L43,63 L40,58 Z", "white")
a.path("M36.6,52 L63.4,52 L63,62 L60,58 L57,63 L53,58 L50,64 L46,58 L43,63 L40,58 L37,62 Z", "ink", sw=0)
a.path("M36.5,46 L63.5,46 L63.4,52 L36.6,52 Z", "ink", stroke=None, fo=0.4)
a.blob([(44, 15), (50, 10.5), (56, 15), (55, 21), (50, 22.5), (45, 21)], "tan", sw=0.8)
for x, y, d in [(41, 30, -1), (48, 28, 1), (56, 31, 1), (39, 39, -1), (46, 37, -1), (53, 38, 1), (60, 40, 1), (42, 46, -1), (50, 45, 1), (58, 47, 1)]:
    a.path(f"M{x},{y} q{2 * d},3 {0.5 * d},5.5 q{-2.6 * d},-1 {-0.5 * d},-5.5 Z", "cream", sw=0.7)
a.path(smooth_d(bell), None, sw=1.5)
for x, y, r in [(40, 70, 2.0), (59, 73, 2.3), (46, 79, 1.5), (63, 82, 1.3)]:
    a.drop(x, y, r, "ink", 0)
a.shade([(57, 16), (61, 26), (64, 44), (63.5, 46), (58, 46), (58, 28)], 0.1)

a = new("small-bonnet")
a.log(76, 94, 4, 96)
for mx in (16, 40, 66):
    a.blob([(mx - 9, 76.5), (mx - 4, 72), (mx + 3, 73), (mx + 9, 76.5), (mx + 3, 79), (mx - 4, 79)], "moss", sw=1.0)
for cx, top, h, w, base, bend in [(30, 34, 14, 10.5, 30, -4), (52, 18, 17, 12.5, 50, 3), (72, 40, 12, 9, 70, 4)]:
    a.tube([(cx, top), (cx + bend, (top + 76) / 2), (base, 76)], 1.7, "#E7DCC6", 1.0)
    a.underside(cx, top, w * 0.95, 2.2, "gill", "none")
    on = a.cap(cx, top, w, h, "bell", "grey", 1.2, shine=False)
    for u in (-0.72, -0.48, -0.24, 0, 0.24, 0.48, 0.72):
        p0, p1 = on(u, 0.08), on(u * 0.55, 0.78)
        a.line(p0[0], p0[1], p1[0], p1[1], stroke=SHADE, sw=0.6, so=0.4)
    x, y = on(0, 1); a.blob([(x - 3, y + 2.6), (x, y + 0.2), (x + 3, y + 2.6), (x, y + 3.6)], "brown", stroke=None, fo=0.5)

a = new("tuft-wood")
a.path("M14,97 L20,70 L80,70 L86,97 Z", "bark")
for x, y0, y1 in [(28, 78, 94), (42, 80, 96), (60, 79, 95), (73, 82, 96)]:
    a.curve([(x, y0), (x + 1, (y0 + y1) / 2), (x - 0.6, y1)], stroke="barkdark", sw=1.2)
a.oval(50, 70, 30, 6.5, "wood")
a.oval(50, 70, 18, 3.6, None, sw=0.7, so=0.5); a.oval(50, 70, 8, 1.5, None, sw=0.7, so=0.5)
for cx, top, w, h, bx in [(24, 44, 11, 9, 42), (76, 46, 11, 9, 58), (36, 26, 13, 11, 46), (64, 28, 13, 11, 54), (50, 38, 15, 12, 50)]:
    a.tube([(cx, top), ((cx + bx) / 2 + (cx - 50) * 0.12, (top + 69) / 2), (bx, 69)], 3.6, "#EFD9A0", 1.1)
    a.underside(cx, top, w * 0.95, 3.2, "sulphur", "gills", 4, 3.6)
    a.cap(cx, top, w, h, "dome", "honey", 1.3)
    a.dot(cx, top - h * 0.86, 1.6, "chestnut", 0.6)

# ====================================================== the flesh

def stub(a, cx, cy, L, r, ang, fill="white", face=None):
    """A piece of stem lying on its side: a cylinder with one cut face showing."""
    rect = rot([(cx - L / 2, cy - r), (cx + L / 2, cy - r), (cx + L / 2, cy + r), (cx - L / 2, cy + r)], ang, cx, cy)
    a.poly(rect, fill)
    sh = rot([(cx - L / 2, cy + r * 0.3), (cx + L / 2, cy + r * 0.3), (cx + L / 2, cy + r), (cx - L / 2, cy + r)], ang, cx, cy)
    a.shade(sh, 0.13)
    return rot([(cx - L / 2, cy), (cx + L / 2, cy)], ang, cx, cy)

a = new("flesh-snap")
l, r = stub(a, 27, 44, 36, 9, 14)
a.oval(r[0], r[1], 3.4, 9, "flesh", ang=14)
l2, r2 = stub(a, 74, 60, 34, 9, 20)
a.oval(l2[0], l2[1], 3.4, 9, "flesh", ang=20)
for x, y, s in [(49, 49, 1.8), (53, 56, 1.4), (47, 58, 1.1), (55, 47, 1.0), (51, 64, 1.5), (45, 67, 0.9), (57, 68, 1.1)]:
    a.poly(rot([(x - s, y - s * 0.7), (x + s * 0.8, y - s), (x + s, y + s * 0.6), (x - s * 0.6, y + s)], x * 7, x, y), "flesh", sw=0.8)
for (x, y), ang in ((r, 14), (l2, 20)):
    for dy in (-4, 0, 4):
        p = rot([(x, y + dy)], ang, x, y)[0]; a.dot(p[0], p[1], 0.6, SHADE, 0.35)
a.cap(9.5, 40, 5, 20, "dome", "red", 0.6, tilt=-76, shine=False)

a = new("flesh-fibrous")
stub(a, 22, 42, 30, 9, 10); stub(a, 80, 62, 30, 9, 28)
for k in range(7):
    t = k / 6
    y0 = 36 + 17 * t; y1 = 46 + 17 * t
    a.curve([(36.5 - 1.2 * (k % 2), y0), (46 + 3 * math.sin(k), y0 + 6 + (k % 3)), (56 - 2 * math.cos(k), y1 - 3), (66 + 1.5 * (k % 2), y1 + 2)], stroke=LINE, sw=2.6)
    a.curve([(36.5 - 1.2 * (k % 2), y0), (46 + 3 * math.sin(k), y0 + 6 + (k % 3)), (56 - 2 * math.cos(k), y1 - 3), (66 + 1.5 * (k % 2), y1 + 2)], stroke="white", sw=1.2)

a = new("milk-drop")
a.underside(48, 34, 38, 22, "cream", "gills", 11, 9, thick=0.8)
a.stem((48, 34), (46, 66), 9, 10, -1, "cream")
a.path("M40.5,62 L51.5,62 L51,68 L41,68 Z", "flesh", sw=1.0)
a.cap(48, 34, 39, 20, "flat", "orange", 2.0)
a.line(62, 40, 80, 46, stroke=LINE, sw=1.4)
for x, y, r in [(64, 44, 2.6), (71, 47.5, 3.0), (78, 49, 2.3)]:
    a.drop(x, y + 2, r, "white", 1.0)
a.drop(72, 66, 3.4, "white", 1.1); a.drop(66, 80, 2.4, "white", 1.0)

a = new("gills-waxy"); a.ground(87)
a.underside(50, 46, 26, 11, "#F5DC8E", "none")
for sx in (-1, 1):
    for u in (0.3, 0.62, 0.9):
        x1 = 50 + sx * u * 26; y1 = 46 + 11 * (1 - u * u) - 0.4
        a.line(50 + sx * (4 + u * 4), 48 + 3 * (1 - u), x1, y1, stroke="orange", sw=2.6)
a.stem((50, 46), (51, 87), 7.5, 8.5, 1, "yolk")
on = a.cap(50, 46, 27, 24, "cone", "scarlet", 1.6)
a.shine([on(-0.55, 0.5), on(-0.4, 0.74), on(-0.2, 0.9)], 0.7, 2.4)

# ====================================================== gills meeting the stem: a mushroom cut in half

def section(name, kind):
    """A mushroom cut in half from top to bottom: the flesh of cap and stem, with a gill hanging
    on each side. Only the way the gill meets the stem changes from one drawing to the next."""
    a = new(name)
    funnel = kind == "decurrent"
    rim = 30 if funnel else 50
    if funnel:
        top = [(8, 30), (18, 24), (34, 30), (50, 38), (66, 30), (82, 24), (92, 30)]
        st = 46
    else:
        top = [(8, 50), (12, 34), (28, 19), (50, 13), (72, 19), (88, 34), (92, 50)]
        st = 34
    def gill(sx):
        X = lambda x: 50 + sx * (50 - x)
        e = {"free": [(8, rim), (20, 62), (31, 62), (36, 50), (37, 38.5)],
             "attached": [(8, rim), (20, 62), (33, 64), (42, 59)],
             "notched": [(8, rim), (20, 63), (31, 64), (37, 58), (38.5, 47), (42, 45.5)],
             "decurrent": [(8, rim), (19, 43), (31, 56), (39, 70), (42, 84)]}[kind]
        e = [(X(x), y) for x, y in e]
        close = [] if kind == "free" else [(X(42), st)]
        a.path(smooth_d(e) + " L" + " L".join(f"{f(x)},{f(y)}" for x, y in close + [(X(8), rim)]) + " Z", "#E4C48E", sw=1.5)
        if kind == "free":
            a.path(f"M{f(X(37))},38.5 L{f(X(8))},{rim}", None, sw=1.5)
    gill(1); gill(-1)
    body = smooth_d(top) + f" L58,{st} L58,92 L42,92 L42,{st} Z"
    a.path(body, "flesh", sw=1.5)
    a.shade([(53, st + 2), (58, st), (58, 92), (53, 92)], 0.1)
    band = [(x + (0 if 8 < x < 92 else (3 if x < 50 else -3)), y + (6 if 8 < x < 92 else 0)) for x, y in top]
    a.path(smooth_d(top) + " L" + " L".join(f"{f(x)},{f(y)}" for x, y in band[::-1]) + " Z", "brown", sw=1.5)
    a.shine([(top[1][0] + 3, top[1][1] + 1), (top[2][0] + 1, top[2][1] + 2.6), (top[3][0] - 8, top[3][1] + 2.8)], 0.4, 1.4)
    a.path(body, None, sw=1.5)

section("gills-free", "free"); section("gills-attached", "attached"); section("gills-notched", "notched"); section("gills-decurrent", "decurrent")

# ====================================================== brackets, seen from underneath

def fan(name, kind):
    a = new(name)
    a.path("M4,5 L96,5 L96,22 L4,22 Z", "bark", sw=0)
    a.line(4, 22, 96, 22)
    for x in (16, 38, 60, 82):
        a.line(x, 8, x + 8, 9, stroke="barkdark", sw=1.2); a.line(x - 6, 15, x + 3, 16, stroke="barkdark", sw=1.2)
    half = ellipse_pts(50, 22, 41, 64, 0, 40, 0, 180)
    if kind == "smooth":
        half = [(x + 2.2 * math.sin(i * 1.1), y + 1.6 * math.sin(i * 0.9)) for i, (x, y) in enumerate(half)]
    a.poly(half, {"pores": "#F4E8C4", "gills": "cream", "smooth": "#E9B46A"}[kind])
    inner = ellipse_pts(50, 22, 36, 58, 0, 40, 0, 180)
    if kind == "pores":
        for j in range(9):
            y = 28 + j * 6.2
            half_w = 37 * math.sqrt(max(0, 1 - ((y - 22) / 60) ** 2))
            n = int(half_w * 2 / 9)
            for k in range(n + 1):
                x = 50 - half_w + 4 + (half_w * 2 - 8) * (k / max(1, n))
                if j % 2 == 0 or 0 < k:
                    a.dot(x - (4.5 * (half_w * 2 - 8) / max(1, n) / 9 if j % 2 else 0), y, 1.15, LINE)
    elif kind == "gills":
        for k in range(11):
            ang = math.radians(10 + 160 * k / 10)
            a.line(50 + 6 * math.cos(ang), 24 + 4 * math.sin(ang), 50 + 37 * math.cos(ang), 22 + 58 * math.sin(ang), sw=0.75)
        a.oval(50, 23, 5, 3.4, "gill", sw=0.9)
    else:
        for pts in ([(26, 34), (40, 40), (60, 40), (74, 34)], [(32, 52), (44, 57), (58, 57), (68, 52)], [(40, 68), (50, 71), (60, 68)]):
            a.curve(pts, stroke=SHADE, sw=1.0, so=0.3)
        a.shine([(22, 30), (28, 44), (38, 58)], 0.35, 2)
    a.shade(ellipse_pts(50, 22, 39.5, 62.5, 0, 16, 2, 78) + ellipse_pts(50, 22, 31, 54, 0, 16, 2, 78)[::-1], 0.12, of={"pores": "#F4E8C4", "gills": "cream", "smooth": "#E9B46A"}[kind])

fan("under-pores", "pores"); fan("under-gills", "gills"); fan("under-smooth", "smooth")

a = new("bracket-tiers"); a.trunk(6, 24)
for y, L, T in [(12, 52, 24), (48, 68, 30)]:
    shelf(a, 24, y, L, T, "orange", "sulphur", zones=((0.6, "yolk"),), lobes=1)

a = new("bracket-scaly"); a.trunk(6, 24)
a.tube([(24, 74), (30, 70), (36, 62)], 8, "black", 1.2)
fanp = [(34, 64), (26, 46), (32, 26), (50, 14), (72, 16), (88, 30), (92, 48), (84, 62), (64, 70), (46, 70)]
a.blob(fanp, "buff")
a.shade([(72, 16), (88, 30), (92, 48), (84, 62), (64, 70), (74, 56), (80, 40)], 0.12)
for r, n in ((14, 4), (25, 6), (36, 8), (47, 9)):
    for k in range(n):
        ang = math.radians(-78 + 96 * (k + 0.5) / n)
        x, y = 36 + r * math.cos(ang) * 1.15, 64 + r * math.sin(ang) * 1.02
        if 26 < x < 90 and 16 < y < 68:
            a.path(f"M{f(x - 2.8)},{f(y + 1.4)} Q{f(x)},{f(y - 3)} {f(x + 2.8)},{f(y + 1.4)} Q{f(x)},{f(y + 0.2)} {f(x - 2.8)},{f(y + 1.4)} Z", "brown", sw=0.6)

a = new("bracket-rosette"); a.ground(88, 8, 92)
a.path("M36,5 L64,5 L66,40 L76,88 L24,88 L34,40 Z", "bark", sw=1.5)
a.line(46, 12, 46, 34, stroke="barkdark", sw=1.5); a.line(55, 20, 55, 40, stroke="barkdark", sw=1.5)
def frond(a, bx, by, ang, L, W, fill):
    p = rot([(bx, by - 1.5), (bx + L * 0.42, by - W * 0.2), (bx + L * 0.76, by - W * 0.5), (bx + L * 0.98, by - W * 0.34), (bx + L * 1.04, by),
             (bx + L * 0.98, by + W * 0.34), (bx + L * 0.76, by + W * 0.5), (bx + L * 0.42, by + W * 0.2), (bx, by + 1.5)], ang, bx, by)
    a.path(smooth_d(p, True), fill, sw=1.2)
    e = rot([(bx + L * 0.78, by - W * 0.34), (bx + L * 0.92, by), (bx + L * 0.78, by + W * 0.34)], ang, bx, by)
    a.curve(e, stroke="cream", sw=1.4, so=0.9)
for ang, L, W, col in [(-150, 44, 26, "grey"), (-30, 44, 26, "grey"), (-120, 52, 28, "tan"), (-60, 52, 28, "tan"), (-90, 56, 28, "grey"),
                       (-172, 36, 22, "tan"), (-8, 36, 22, "tan"), (-136, 32, 22, "buff"), (-44, 32, 22, "buff"), (-105, 28, 20, "tan"), (-75, 28, 20, "buff")]:
    frond(a, 50, 90, ang, L, W, col)

a = new("bracket-zoned")
a.log(78, 95, 5, 95, end=False)
def zoned(a, cx, by, R, squash=0.86):
    for i, col in enumerate(["cream", "chestnut", "slate", "tan", "brown"]):
        r = R * (1 - i * 0.2)
        a.poly(ellipse_pts(cx, by, r, r * squash, 0, 30, 180, 360), col, sw=1.5 if i == 0 else 0.7)
    a.shade(ellipse_pts(cx, by, R - 1.6, (R - 1.6) * squash, 0, 14, 296, 360) + [(cx + R * 0.4, by)], 0.14)
zoned(a, 24, 79, 20); zoned(a, 78, 79, 19); zoned(a, 51, 79, 34)

a = new("bracket-hoof"); a.trunk(6, 24)
hoof = [(24, 22), (40, 28), (56, 42), (66, 58), (70, 74), (24, 74)]
a.path(smooth_d(hoof[:-1]) + " L24,74 Z", "grey")
for i in range(3):
    t = 0.3 + i * 0.24
    band = [(24, 22 + 52 * t), (24 + 22 * t + 6, 26 + 50 * t), (24 + 44 * t + 4, 40 + 36 * t + 2), (24 + 46 * t + 4, 74)]
    a.curve(band[:3] + [(band[3][0] + 1, 73)], sw=0.7)
a.path("M24,74 L70,74 L66,80 L24,80 Z", "buff", sw=1.3)
a.shade([(48, 34), (56, 42), (66, 58), (70, 74), (60, 74), (56, 56)], 0.14, of="grey")

# ====================================================== balls

a = new("ball-puff"); a.ground(88)
pear = [(50, 30), (64, 33), (73, 44), (73, 56), (64, 66), (59, 76), (58, 87), (42, 87), (41, 76), (36, 66), (27, 56), (27, 44), (36, 33)]
a.blob(pear, "cream")
a.shade([(60, 31), (70, 40), (74, 52), (66, 65), (60, 76), (58, 87), (52, 87), (54, 74), (62, 60), (66, 46)], 0.14)
for x, y in [(38, 42), (46, 38), (56, 40), (64, 46), (34, 52), (42, 50), (51, 48), (60, 54), (39, 60), (48, 58), (57, 63), (46, 68), (53, 72), (48, 80)]:
    a.poly([(x - 1.1, y + 0.9), (x, y - 1.3), (x + 1.1, y + 0.9)], "tan", sw=0.6)
a.oval(50, 30.5, 4.2, 1.8, "black", sw=0.9)
for x, y, r, o in [(50, 23, 1.5, 0.7), (45, 18, 1.2, 0.6), (55, 17, 1.3, 0.6), (50, 12, 1.1, 0.5), (41, 11, 0.9, 0.4), (58, 9, 1.0, 0.4), (47, 6, 0.8, 0.3), (63, 14, 0.8, 0.3), (37, 17, 0.8, 0.3)]:
    a.dot(x, y, r, "rust", o)

a = new("ball-earth"); a.ground(87)
a.blob([(30, 42), (46, 44), (54, 58), (52, 74), (40, 84), (22, 84), (10, 74), (8, 58), (16, 46)], "#D8B25A")
for x, y in [(18, 54), (28, 50), (40, 56), (14, 66), (26, 64), (38, 68), (20, 76), (32, 78), (44, 76)]:
    a.poly([(x - 2.4, y), (x - 0.6, y - 2.2), (x + 2.2, y - 0.8), (x + 1.6, y + 1.8), (x - 1.2, y + 2)], "brown", sw=0.6, fo=0.55)
half = ellipse_pts(68, 62, 24, 23, 0, 40)
a.poly(half, "#EFDDA8")
a.poly(ellipse_pts(68, 62, 19.5, 18.5, 0, 40), "purple", sw=1.0)
for pts in ([(56, 56), (62, 60), (60, 68)], [(70, 50), (74, 58), (70, 64), (76, 72)], [(64, 72), (70, 74)], [(78, 54), (82, 62)]):
    a.curve(pts, stroke="#D9C9D9", sw=0.9, so=0.7)

a = new("ball-star"); a.ground(92, grass=False)
for k in range(7):
    a0 = -90 + 360 * k / 7
    p0 = (50 + 13 * math.cos(math.radians(a0 - 22)), 62 + 7.5 * math.sin(math.radians(a0 - 22)))
    p1 = (50 + 13 * math.cos(math.radians(a0 + 22)), 62 + 7.5 * math.sin(math.radians(a0 + 22)))
    tip = (50 + 44 * math.cos(math.radians(a0)), 64 + 25 * math.sin(math.radians(a0)))
    m0 = (50 + 30 * math.cos(math.radians(a0 - 13)), 63 + 17 * math.sin(math.radians(a0 - 13)))
    m1 = (50 + 30 * math.cos(math.radians(a0 + 13)), 63 + 17 * math.sin(math.radians(a0 + 13)))
    a.path(f"M{f(p0[0])},{f(p0[1])} Q{f(m0[0])},{f(m0[1])} {f(tip[0])},{f(tip[1])} Q{f(m1[0])},{f(m1[1])} {f(p1[0])},{f(p1[1])} Z", "tan")
    a.line((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, 50 + 34 * math.cos(math.radians(a0)), 64 + 19 * math.sin(math.radians(a0)), stroke=SHADE, sw=0.7, so=0.3)
a.oval(50, 62, 17, 9, "buff")
a.blob([(50, 28), (62, 32), (68, 44), (64, 56), (50, 60), (36, 56), (32, 44), (38, 32)], "#D9D0BC")
a.shade([(58, 30), (66, 38), (68, 48), (62, 57), (52, 60), (60, 50), (62, 40)], 0.15)
a.path("M45,31 L50,22 L55,31 Z", "#D9D0BC", sw=1.2); a.dot(50, 23.5, 1.3, "black")
for x, y, r, o in [(50, 16, 1.3, 0.6), (45, 11, 1.0, 0.5), (55, 10, 1.1, 0.5), (50, 6, 0.9, 0.35)]:
    a.dot(x, y, r, "rust", o)

# ====================================================== cups

a = new("cup-ear")
a.twig([(18, 97), (22, 70), (20, 40), (25, 4)], 14)
a.oval(22, 55, 1.8, 3, "barkdark", sw=0)
def ear(a, x, y, s, flip=1):
    X = lambda px: x + flip * px * s
    p = [(X(0), y), (X(6), y - 16 * s), (X(24), y - 22 * s), (X(40), y - 12 * s), (X(46), y + 6 * s), (X(36), y + 20 * s), (X(20), y + 22 * s), (X(6), y + 12 * s)]
    a.blob(p, "ear")
    q = [(X(8), y + 2 * s), (X(12), y - 10 * s), (X(24), y - 14 * s), (X(35), y - 7 * s), (X(38), y + 5 * s), (X(31), y + 14 * s), (X(20), y + 15 * s), (X(11), y + 9 * s)]
    a.blob(q, "#C98A6A", sw=0)
    a.curve([(X(10), y + 6 * s), (X(16), y - 5 * s), (X(26), y - 6 * s), (X(30), y + 2 * s), (X(25), y + 9 * s)], sw=0.8)
    a.curve([(X(17), y + 5 * s), (X(21), y), (X(24), y + 3 * s)], sw=0.8)
    a.shine([(X(8), y - 12 * s), (X(16), y - 17.5 * s), (X(26), y - 17.5 * s)], 0.4, 1.6)
ear(a, 30, 32, 1.2); ear(a, 30, 76, 0.85)

a = new("cup-nest")
for pts in ([(4, 86), (22, 80), (30, 86), (14, 93)], [(28, 90), (50, 84), (62, 91), (40, 96)], [(60, 86), (84, 81), (96, 88), (74, 94)]):
    a.poly(pts, "wood", sw=1.1); a.line(pts[0][0] + 4, pts[0][1] + 1, pts[2][0] - 5, pts[2][1] - 1, stroke="barkdark", sw=0.8, so=0.7)
def nest(a, cx, ty, w, h, eggs=True):
    a.path(f"M{f(cx - w)},{f(ty)} C{f(cx - w * 0.86)},{f(ty + h * 0.6)} {f(cx - w * 0.5)},{f(ty + h)} {f(cx - w * 0.3)},{f(ty + h)} "
           f"L{f(cx + w * 0.3)},{f(ty + h)} C{f(cx + w * 0.5)},{f(ty + h)} {f(cx + w * 0.86)},{f(ty + h * 0.6)} {f(cx + w)},{f(ty)} Z", "tan")
    for k in range(7):
        x = cx - w * 0.72 + w * 1.44 * k / 6
        a.line(x, ty + h * 0.34, cx + (x - cx) * 0.55, ty + h * 0.9, stroke="brown", sw=0.9, so=0.8)
    a.shade([(cx + w * 0.3, ty + h * 0.3), (cx + w, ty), (cx + w * 0.86, ty + h * 0.55), (cx + w * 0.4, ty + h), (cx + w * 0.1, ty + h)], 0.13)
    a.oval(cx, ty, w, w * 0.34, "#8C7A66" if eggs else "#EFE3C6")
    if eggs:
        for dx, dy in [(-0.42, 0.02), (0.02, -0.08), (0.44, 0.03), (-0.2, 0.14), (0.24, 0.14)]:
            a.oval(cx + dx * w, ty + dy * w, w * 0.2, w * 0.1, "#DAD6CC", sw=0.9)
nest(a, 76, 56, 15, 28, eggs=False); nest(a, 40, 40, 26, 46)

# ====================================================== clubs

a = new("club-antler")
a.log(78, 95, 4, 96)
def snuff(a, bx, h, lean, fork=True):
    top = (bx + lean, 78 - h); mid = (bx + lean * 0.4, 78 - h * 0.5)
    parts = [([(bx, 79), mid, (bx + lean * 0.8, 78 - h * 0.8), top], 5.4)]
    if fork:
        parts += [([(bx + lean * 0.6, 78 - h * 0.6), (bx + lean * 0.6 + 8, 78 - h * 0.78), (bx + lean + 12, 78 - h * 0.96)], 4.8),
                  ([(bx + lean * 0.6, 78 - h * 0.6), (bx + lean * 0.5 - 7, 78 - h * 0.76), (bx + lean * 0.4 - 11, 78 - h * 0.9)], 4.6)]
    a.tubes(parts, "#F3F0E8")
    a.tube([(bx, 79), (bx + lean * 0.2, 78 - h * 0.25), (bx + lean * 0.42, 78 - h * 0.52)], 5.4, "black", 0)
snuff(a, 26, 52, -3); snuff(a, 70, 60, 3); snuff(a, 48, 30, 1, False)

a = new("club-simple"); a.ground(88)
a.tubes([([(50, 87), (50, 60), (51, 20)], 9), ([(36, 87), (33, 66), (26, 40)], 8), ([(64, 87), (67, 66), (74, 44)], 8),
         ([(24, 87), (20, 74), (14, 60)], 6.5), ([(76, 87), (80, 74), (86, 62)], 6.5)], "yolk")
for pts in ([(47, 62), (47.4, 40), (48.4, 26)], [(32, 68), (29, 54), (26, 46)], [(63, 68), (66, 56), (70, 49)]):
    a.shine(pts, 0.4, 1.3)

# ====================================================== odder shapes

a = new("odd-stinkhorn"); a.ground(86)
at = a.stem((50, 30), (50, 82), 12, 14, 0, "white")
for k in range(9):
    t = 0.2 + 0.62 * ((k * 0.618) % 1); u = ((k * 0.41) % 1) * 1.3 - 0.65
    x, y, w = at(t); a.oval(x + u * w, y, 1.1, 1.7, SHADE, sw=0, fo=0.3)
a.blob([(30, 88), (30, 76), (39, 68), (46, 75), (50, 70), (54, 75), (61, 68), (70, 76), (70, 88), (50, 92)], "white")
a.shade([(61, 69), (70, 76), (70, 88), (56, 91), (62, 80)], 0.12)
head = [(37, 40), (36, 26), (42, 13), (50, 9), (58, 13), (64, 26), (63, 40), (50, 43)]
a.blob(head, "olive")
a.shade([(56, 12), (63, 24), (63, 39), (53, 43), (57, 30)], 0.2)
a.oval(50, 10.5, 4, 2, "white", sw=1.0)
a.shine([(41, 30), (42, 21), (46, 15)], 0.5, 1.6)
for x, y in [(78, 22), (20, 30), (82, 46)]:
    a.oval(x, y, 2.2, 1.5, LINE, sw=0)
    a.oval(x - 2.2, y - 2.2, 2.0, 1.1, "white", sw=0.6, ang=35); a.oval(x + 2.2, y - 2.2, 2.0, 1.1, "white", sw=0.6, ang=-35)

a = new("odd-cage"); a.ground(87)
a.blob([(30, 89), (30, 80), (39, 74), (46, 79), (54, 79), (61, 74), (70, 80), (70, 89), (50, 93)], "white")
a.oval(50, 45, 34, 36, "scarlet")
a.shade(ellipse_pts(50, 45, 32.5, 34.5, 0, 18, -60, 70) + [(66, 62), (72, 46), (66, 28)], 0.16)
for hx, hy, r in [(50, 22, 7.5), (31, 31, 7.5), (69, 31, 7.5), (23, 50, 7), (50, 44, 8.5), (77, 50, 7), (35, 65, 7.5), (65, 65, 7.5), (50, 72, 5.5)]:
    hexp = [(hx + (r + 1.6) * math.cos(math.radians(30 + 60 * k)), hy + (r + 1.6) * 1.05 * math.sin(math.radians(30 + 60 * k))) for k in range(6)]
    a.poly(hexp, "#5A1A16", sw=1.0)
a.shine([(24, 36), (30, 22), (42, 13)], 0.45, 1.8)

a = new("odd-morel"); a.ground(88)
a.stem((50, 50), (50, 88), 14, 17, 0, "cream", bulb=1.5)
capm = [(50, 8), (62, 14), (69, 28), (70, 42), (64, 54), (50, 58), (36, 54), (30, 42), (31, 28), (38, 14)]
a.blob(capm, "honey")
import random
rng = random.Random(7)
for row in range(6):
    y = 15 + row * 7.2
    half = 17.5 * math.sqrt(max(0, 1 - ((y - 34) / 26) ** 2))
    n = max(1, int(half * 2 / 7.4))
    for k in range(n):
        x = 50 - half + (half * 2) * (k + 0.5) / n + (2.2 if row % 2 else -1.2)
        if abs(x - 50) < half - 1.5:
            r = 2.9 + rng.random() * 0.6
            pit = [(x - r, y - r * 0.5), (x - r * 0.3, y - r * 1.1), (x + r * 0.8, y - r * 0.8), (x + r, y + r * 0.4), (x + r * 0.2, y + r * 1.1), (x - r * 0.8, y + r * 0.7)]
            a.blob(pit, "chestnut", sw=0.7)
a.shade([(58, 11), (68, 26), (70, 42), (64, 54), (52, 58), (62, 46), (64, 30)], 0.13)

a = new("odd-saddle"); a.ground(88)
at = a.stem((50, 44), (50, 88), 13, 17, 0, "white")
for dx in (-4.4, -1.4, 1.6, 4.6):
    a.curve([(50 + dx, 48), (50 + dx * 1.15 + 0.4, 66), (50 + dx * 1.3, 86)], stroke=SHADE, sw=0.9, so=0.35)
for x, y in [(47, 60), (53, 72), (46, 78)]:
    a.oval(x, y, 1.1, 3.0, SHADE, sw=0, fo=0.35)
sad = [(50, 30), (40, 16), (26, 14), (16, 24), (18, 40), (30, 50), (42, 48), (50, 42), (58, 48), (70, 50), (82, 40), (84, 24), (74, 14), (60, 16)]
a.blob(sad, "buff")
a.shade([(62, 17), (74, 14), (84, 24), (82, 40), (70, 50), (60, 48), (72, 38), (74, 26)], 0.14)
a.curve([(50, 31), (44, 22), (34, 20), (26, 26), (26, 38)], stroke=SHADE, sw=0.9, so=0.35)
a.curve([(50, 31), (56, 22), (66, 20), (74, 26), (74, 38)], stroke=SHADE, sw=0.9, so=0.35)
a.curve([(50, 30), (50, 42)], sw=1.2)
a.shine([(22, 26), (27, 19), (35, 18)], 0.45, 1.6)

D["form-other"] = D["odd-stinkhorn"]

NAMES = {
    "form-gills": "Cap and stem with gills", "form-pores": "Cap and stem with pores", "form-spines": "Spines under the cap",
    "form-ridges": "Funnel with blunt ridges", "form-bracket": "Bracket on wood", "form-ball": "Ball", "form-cup": "Cup",
    "form-club": "Coral or club", "form-jelly": "Jelly", "form-other": "Odder shapes",
    "spore-white": "White spore print", "spore-pink": "Pink spore print", "spore-brown": "Brown spore print", "spore-black": "Black spore print",
    "stem-volva": "Bag at the base, with a ring", "stem-ring": "Ring, no bag", "stem-plain": "No ring, no bag", "stem-side": "No stem, on wood",
    "veil-cobweb": "Cobweb veil", "stem-scabers": "Rough flecks on the stem", "stem-net": "Net on a swollen stem",
    "cap-scaly": "Tall scaly parasol", "cap-slimy": "Slimy cap", "cap-inky": "Cap turning to ink", "small-bonnet": "Small bell on a thin stem",
    "tuft-wood": "Clump on wood", "flesh-snap": "Snaps like chalk", "flesh-fibrous": "Tears into fibres", "milk-drop": "Milk from cut gills",
    "gills-free": "Gills free of the stem", "gills-attached": "Gills joined to the stem", "gills-notched": "Gills notched at the stem",
    "gills-decurrent": "Gills running down the stem", "gills-waxy": "Thick, well-spaced gills",
    "under-pores": "Pores underneath", "under-gills": "Gills underneath", "under-smooth": "Smooth underneath",
    "bracket-tiers": "Thick shelves in tiers", "bracket-scaly": "Scaly fan with a short stem", "bracket-rosette": "Rosette of fronds",
    "bracket-zoned": "Thin and banded", "bracket-hoof": "Woody hoof", "ball-puff": "Puffball", "ball-earth": "Earthball, whole and cut",
    "ball-star": "Earthstar", "cup-ear": "Jelly ear", "cup-nest": "Bird's nest", "club-antler": "Candlesnuff", "club-simple": "Clubs and spindles",
    "odd-stinkhorn": "Stinkhorn", "odd-cage": "Red cage", "odd-morel": "Morel", "odd-saddle": "Saddle",
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out"
    os.makedirs(out, exist_ok=True)
    assert set(D) == set(NAMES), set(D) ^ set(NAMES)
    for name, art in D.items():
        with open(os.path.join(out, f"fungus-{name}.svg"), "w", encoding="utf-8") as fh:
            fh.write(art.svg())
    print(len(D), "diagrams written to", out)
