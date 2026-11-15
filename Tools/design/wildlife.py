#!/usr/bin/env python3
"""Windfall wildlife drawings: one drawing for each KIND of animal.

A kind is a group you would know by sight (bumblebee, hoverfly, tit, newt).
The list of kinds is in Tools/data/wildlife_kinds.py. Every animal in the
wildlife reference belongs to one kind and is shown with that kind's
drawing, in the same way that every tomato variety shares the tomato's.

Run it from the top of the repository:

    python3 Tools/design/wildlife.py Design/Wildlife

It writes Design/Wildlife/light and /dark: one SVG for each kind, named
wild-<kind>.svg, and one for each animal that has a drawing of its own,
named wild-sp-<scientific-name>.svg (those are drawn in wildlife_species.py
and wildlife_species2.py). It also writes a sheet of the kinds in each
look, for checking by eye, and species-drawings.json, the list of which
animals have their own drawing.
Tools/design/build_design_assets.py then copies them into the app.

⚠️ Every drawing here is Claude's, made on 15 November 2026 from memory of
what each animal looks like. They are pictures of a KIND, not portraits of
a species: the bumblebee is drawn as a buff-tailed, the tit as a blue tit.
William has not checked them.
"""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data"))
from shapely.geometry import Polygon
from shapely.ops import unary_union
from wildlife_kit import (Art, P, LW, turn, curve, ell, blob, poly, limb, mirror, band, paint, figure, stroke, eye, spots, polys)
from wildlife_kinds import KINDS

DRAW = {}      # kind's slug -> the function that draws it
SPECIES = {}   # scientific name -> the function that draws that one animal (wildlife_species.py and wildlife_species2.py)


def sp(*names):
    """Marks a function as the drawing of one animal, or of a few that look alike."""
    def keep(fn):
        for n in names:
            SPECIES[n] = fn
        return fn
    return keep


# An animal can have MORE THAN ONE picture: a bird overhead as well as
# perched, a female as well as a male, a caterpillar and a chrysalis as
# well as the butterfly. The first picture is the one in SPECIES. The
# others are kept here, each under a short key that says what it shows.
# One of William's own species may not be in the UK list at all: "Andrena spp."
# is a whole genus, and Myrmica sabuleti has too few records. For a few genera
# one animal's drawing can stand for all of them: any Myrmica is a red ant.
GENUS_IS = {}     # genus -> the scientific name of the animal whose drawing stands for the genus
VIEWS = {}        # scientific name -> {key: the function that draws that view}, in the order they are shown
MAIN_SHOWS = {}   # scientific name -> the key for what its FIRST picture shows ("male", "flight"), where that needs saying
VIEW_NAMES = {"adult": "Adult", "male": "Male", "female": "Female", "juvenile": "Young bird", "summer": "In summer", "winter": "In winter", "perched": "Perched",
              "flight": "In flight", "upperside": "Wings open", "underside": "Wings closed", "eggs": "Eggs", "spawn": "Spawn", "tadpole": "Tadpole",
              "caterpillar": "Caterpillar", "chrysalis": "Chrysalis", "cocoon": "Cocoon", "larva": "Larva", "pupa": "Pupa", "nymph": "Nymph"}


def view(key, *names, main=None):
    """Marks a function as ANOTHER picture of an animal: `@view("female",
    "Turdus merula")`. `main` says what the animal's first picture shows,
    so the two can be told apart: `main="male"`."""
    assert key in VIEW_NAMES, key
    def keep(fn):
        for n in names:
            VIEWS.setdefault(n, {})[key] = fn
            if main:
                MAIN_SHOWS[n] = main
        return fn
    return keep


def slug_of(scientific):
    """'Bombus terrestris' becomes 'bombus-terrestris', for a file name."""
    return "".join(c if c.isalnum() else "-" for c in scientific.lower()).strip("-")


def draws(slug):
    def keep(fn):
        DRAW[slug] = fn; return fn
    return keep


# =====================================================================
# INSECTS SEEN FROM ABOVE, HEAD AT THE TOP
# =====================================================================

def wing_shape(x, y, ang, L, B, pinch=0.45):
    """A wing: narrow where it joins the body at x,y, round at the tip.
    ang is the way it points (90 is straight back, 0 is out to the right)."""
    t = turn(x, y, ang); pts = []
    for k in range(40):
        th = 2 * math.pi * k / 40
        u = (1 + math.cos(th)) / 2
        pts.append(t(L * u, B * math.sin(th) * (pinch + (1 - pinch) * u ** 0.7)))
    return Polygon(pts).buffer(0)


def six_legs(a, cx, ty, half, depth, L, lw=1.0, angles=(-40, 6, 46), col="line"):
    """Three pairs of legs from the middle part of the body. Each leg has
    three parts: a stout thigh, a shin and a thin foot."""
    for side in (1, -1):
        for dy, ang in zip((-depth * 0.5, 0, depth * 0.5), angles):
            b = (cx + side * half * 0.75, ty + dy)
            a1, a2, a3 = math.radians(ang - 22), math.radians(ang + 20), math.radians(ang + 50)
            k = (b[0] + side * L * 0.46 * math.cos(a1), b[1] + L * 0.46 * math.sin(a1))
            e = (k[0] + side * L * 0.44 * math.cos(a2), k[1] + L * 0.44 * math.sin(a2))
            t = (e[0] + side * L * 0.2 * math.cos(a3), e[1] + L * 0.2 * math.sin(a3))
            stroke(a, [b, k], lw * 1.55, smooth=False, col=col)
            stroke(a, [k, e], lw, smooth=False, col=col)
            stroke(a, [e, t], lw * 0.7, smooth=False, col=col)


def feelers(a, cx, y, half, length, spread, elbow=0, lw=0.9, club=0):
    for side in (1, -1):
        b = (cx + side * half * 0.5, y)
        e = (cx + side * spread, y - length)
        if elbow:
            m = (cx + side * (spread + elbow), y - length * 0.45)
            stroke(a, [b, m, e], lw, smooth=False)
        else:
            m = (cx + side * spread * 0.75, y - length * 0.6)
            stroke(a, [b, m, e], lw)
        if club:
            a.dot(e[0], e[1], club, "line")


def insect(a, cx=50, top=None, head=(4.4, 3.8, "black"), th=(6.5, 7.0, "black"), ab=(8.5, 14, "yellow"),
           bands=(), th_bands=(), wings=(), legs=12, leg_lw=1.0, leg_angles=(-40, 6, 46), ant=(8, 6, 0),
           eyes=None, waist=0.0, tip=0.0, fuzz=0.0, overlap=1.6, club=0):
    """A bee, wasp or fly, built from three parts: head, thorax (where the
    legs and wings join) and abdomen.
      head, th, ab   each is (half-width, half-length, colour)
      bands          stripes across the abdomen: (from, to, colour), -1 is its front and 1 its tip
      wings          each is (how far down the thorax, sweep, length, breadth, colour, strength)
                     sweep 0 lies straight back along the body and 90 sticks straight out
      waist          a gap between thorax and abdomen (a wasp's)
      tip            how pointed the abdomen is
      fuzz           a ragged, furry edge"""
    hrx, hry, hc = head; trx, try_, tc = th; arx, ary, ac = ab
    total = 2 * hry + 2 * try_ + 2 * ary - 2 * overlap + waist
    top = (50 - total / 2) if top is None else top
    hy = top + hry; ty = hy + hry + try_ - overlap; ay = ty + try_ + ary - overlap + waist
    for dy, sweep, L, B, colour, fa in wings:
        for side in (1, -1):
            ang = 90 - side * sweep
            w = wing_shape(cx + side * trx * 0.5, ty + dy, ang, L, B)
            paint(a, w, colour, 0.8, fa=fa)
            t = turn(cx + side * trx * 0.5, ty + dy, ang)
            stroke(a, [t(L * 0.08), t(L * 0.5, -side * B * 0.12), t(L * 0.9, -side * B * 0.05)], 0.45, 0.4)
            stroke(a, [t(L * 0.4, -side * B * 0.1), t(L * 0.8, side * B * 0.45)], 0.45, 0.4)
            stroke(a, [t(L * 0.22, side * B * 0.1), t(L * 0.55, side * B * 0.55)], 0.4, 0.35)
            stroke(a, [t(L * 0.62, -side * B * 0.32), t(L * 0.66, side * B * 0.3)], 0.4, 0.35)
    if legs:   # after the wings, so the legs show on top of them
        six_legs(a, cx, ty, trx, try_, legs, leg_lw, leg_angles)

    def furry(cx_, cy_, rx, ry):
        if not fuzz:
            return ell(cx_, cy_, rx, ry)
        return Polygon([(cx_ + rx * (1 + fuzz * math.cos(24 * t)) * math.cos(t), cy_ + ry * (1 + fuzz * math.cos(24 * t)) * math.sin(t))
                        for t in [2 * math.pi * k / 144 for k in range(144)]])
    if tip:
        body = blob([(cx, ay - ary), (cx + arx * 0.86, ay - ary * 0.55), (cx + arx, ay - ary * 0.05), (cx + arx * 0.62, ay + ary * 0.58),
                     (cx, ay + ary * (1 + tip)), (cx - arx * 0.62, ay + ary * 0.58), (cx - arx, ay - ary * 0.05), (cx - arx * 0.86, ay - ary * 0.55)])
    else:
        body = furry(cx, ay, arx, ary)
    if waist:
        stroke(a, [(cx, ty + try_ - 1), (cx, ay - ary + 1)], 1.6, smooth=False)
    figure(a, [body], ac, [(band(cx, ay, arx, ary * (1 + tip), v1, v2), c) for v1, v2, c in bands], close=0)
    for v in (-0.45, -0.05, 0.35, 0.7):
        w = arx * math.sqrt(max(0.0, 1 - v * v)) * (0.96 if not tip else 0.8)
        stroke(a, [(cx - w, ay + v * ary), (cx, ay + v * ary + ary * 0.07), (cx + w, ay + v * ary)], 0.45, 0.3)
    figure(a, [furry(cx, ty, trx, try_)], tc, [(band(cx, ty, trx, try_, v1, v2), c) for v1, v2, c in th_bands], close=0)
    if fuzz:      # a furry insect: short pale hairs lying back along the thorax and abdomen
        for ox, oy, rx, ry, rows in ((cx, ty, trx, try_, 3), (cx, ay, arx, ary, 5)):
            for r in range(rows):
                v = -0.62 + 1.24 * (r + 0.5) / rows
                n = 5 if r % 2 else 4
                for k in range(n):
                    u = -0.72 + 1.44 * (k + 0.5) / n
                    x = ox + u * rx * math.sqrt(1 - v * v); y = oy + v * ry
                    stroke(a, [(x, y - 0.8), (x + u * 0.5, y + 1.0)], 0.4, 0.42, col="cream", smooth=False)
    figure(a, [ell(cx, hy, hrx, hry)], hc, close=0)
    if eyes:
        for side in (1, -1):
            paint(a, ell(cx + side * hrx * 0.62, hy - hry * 0.05, hrx * 0.42, hry * 0.72, side * 12), eyes, 0.6)
    if ant:
        feelers(a, cx, hy - hry * 0.7, hrx, ant[0], ant[1], ant[2], club=club)
    return hy, ty, ay


@draws("bumblebee")
def bumblebee():
    a = Art()
    insect(a, head=(4.6, 3.8, "black"), th=(9.5, 8.5, "black"), ab=(11.5, 13.5, "black"), fuzz=0.045,
           th_bands=[(-1, -0.25, "yellow")], bands=[(-0.62, -0.12, "yellow"), (0.5, 1.1, "cream")],
           wings=[(-1, 52, 25, 6.2, "wing", 0.85), (2.5, 30, 17, 4.6, "wing", 0.85)], legs=12, leg_lw=1.3, ant=(7, 7, 1.5))
    return a


@draws("honeybee")
def honeybee():
    a = Art()
    insect(a, head=(4.2, 3.6, "brown"), th=(6.6, 6.8, "tan"), ab=(7.4, 14.5, "amber"), fuzz=0.035, tip=0.12,
           bands=[(-0.55, -0.38, "black"), (-0.08, 0.12, "black"), (0.38, 0.6, "black"), (0.82, 1.3, "black")],
           wings=[(-1, 40, 25, 5.6, "wing", 0.85), (2, 24, 17, 4.2, "wing", 0.85)], legs=11, leg_lw=1.1, ant=(7, 6, 1.5), eyes="black")
    return a


@draws("solitary-bee")
def solitary_bee():
    a = Art()
    insect(a, head=(4.6, 3.9, "black"), th=(7.4, 7.2, "rust"), ab=(8.2, 13, "orange"), fuzz=0.05,
           bands=[(-0.2, -0.08, "rust"), (0.25, 0.37, "rust"), (0.66, 0.78, "rust")],
           wings=[(-1, 46, 24, 5.6, "wing", 0.85), (2, 28, 16, 4.2, "wing", 0.85)], legs=11, leg_lw=1.1, ant=(8, 7, 1.5))
    return a


@draws("wasp")
def wasp():
    a = Art()
    insect(a, head=(4.6, 3.8, "black"), th=(6.2, 7.2, "black"), ab=(7.2, 15, "yellow"), tip=0.22, waist=1.6,
           th_bands=[(-1, -0.72, "yellow")],
           bands=[(-1, -0.72, "black"), (-0.42, -0.24, "black"), (0.06, 0.24, "black"), (0.52, 0.68, "black"), (0.92, 1.05, "black")],
           wings=[(-1, 34, 28, 4.6, "wing", 0.85), (2, 20, 18, 3.4, "wing", 0.85)], legs=13, leg_lw=1.0, ant=(10, 7, 2), eyes="black")
    return a


@draws("ant")
def ant():
    a = Art()
    cx = 50
    six_legs(a, cx, 47, 3.6, 7, 17, 1.1, angles=(-48, 4, 52))
    figure(a, [ell(cx, 72, 8.2, 11.5)], "black", close=0)
    for v in (-0.2, 0.3):
        stroke(a, [(cx - 7.6, 72 + v * 11.5), (cx, 73.5 + v * 11.5), (cx + 7.6, 72 + v * 11.5)], 0.5, 0.35, col="cream")
    figure(a, [ell(cx, 59, 2.1, 2.6)], "black", close=0)
    figure(a, [ell(cx, 42, 4.6, 6), ell(cx, 51, 3.4, 5)], "black", close=1.6)
    figure(a, [blob([(cx, 21), (cx + 6, 24), (cx + 6.8, 31), (cx + 3.6, 36.5), (cx - 3.6, 36.5), (cx - 6.8, 31), (cx - 6, 24)])], "black", close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 2.2, 21.5), (cx + s * 3, 17.5), (cx + s * 0.6, 16)], 1.0, smooth=False)
        stroke(a, [(cx + s * 4.5, 25), (cx + s * 12.5, 22), (cx + s * 15, 12.5)], 1.0, smooth=False)
        a.dot(cx + s * 4.4, 28, 0.9, "cream")
    return a


@draws("sawfly")
def sawfly():
    a = Art()
    insect(a, head=(4.6, 3.6, "black"), th=(6.6, 7, "black"), ab=(6.8, 15.5, "orange"), overlap=2.6,
           th_bands=[(0.45, 1, "orange")], bands=[(0.86, 1.2, "black")],
           wings=[(-1, 36, 28, 5.6, "buff", 0.8), (2, 22, 18, 4.2, "buff", 0.8)], legs=12, ant=(9, 6.5, 0), club=0.9)
    return a


@draws("parasitic-wasp")
def parasitic_wasp():
    a = Art()
    cx = 50
    hy, ty, ay = insect(a, top=17, head=(3.6, 3.2, "black"), th=(4.6, 7.2, "black"), ab=(3.6, 15.5, "rust"), tip=0.2, waist=3.4,
                        bands=[(-1, -0.72, "black"), (0.7, 1.2, "black")],
                        wings=[(-1.5, 40, 25, 4.2, "wing", 0.85), (1.5, 24, 16, 3.2, "wing", 0.85)], legs=15, leg_lw=0.9,
                        leg_angles=(-42, 10, 58), ant=None)
    stroke(a, [(cx, ay + 17.5), (cx + 0.6, ay + 26), (cx + 2.2, ay + 33)], 0.9)          # the egg-layer
    for s in (1, -1):
        stroke(a, [(cx + s * 1.6, hy - 2.4), (cx + s * 8, hy - 9), (cx + s * 17, hy - 9.5), (cx + s * 23, hy - 4)], 0.9)
    return a


@draws("hoverfly")
def hoverfly():
    a = Art()
    insect(a, head=(5.6, 4.2, "brown"), th=(6.4, 6.8, "dark"), ab=(6.6, 15, "orange"), eyes="rust",
           bands=[(-1, -0.8, "black"), (-0.5, -0.38, "black"), (-0.3, -0.24, "black"), (0.08, 0.2, "black"), (0.28, 0.34, "black"),
                  (0.62, 0.74, "black"), (0.9, 1.1, "black")],
           wings=[(-0.5, 44, 29, 6.2, "wing", 0.85)], legs=10, leg_lw=0.9, ant=(2.6, 2.2, 0))
    return a


@draws("bee-fly")
def bee_fly():
    a = Art()
    cx = 50
    six_legs(a, cx, 47, 6, 6, 20, 0.8, angles=(-30, 22, 62))
    for side in (1, -1):
        w = wing_shape(cx + side * 4, 43, 90 - side * 58, 33, 7.4)
        paint(a, w, "wing", 0.8, fa=0.85)
        t = turn(cx + side * 4, 43, 90 - side * 58)
        front = Polygon([t(0, 0), t(33, 0), t(33, -side * 9), t(0, -side * 9)])
        paint(a, front.intersection(w), "brown", fa=0.8)
        paint(a, w, None, 0.8)
    body = Polygon([(cx + 11 * (1 + 0.05 * math.cos(26 * t)) * math.cos(t), 54 + 14 * (1 + 0.05 * math.cos(26 * t)) * math.sin(t))
                    for t in [2 * math.pi * k / 156 for k in range(156)]])
    figure(a, [body], "tan", [(band(cx, 54, 11, 14, 0.25, 1.2), "brown")], close=0)
    figure(a, [ell(cx, 37.5, 4.6, 3.8)], "brown", close=0)
    for side in (1, -1):
        paint(a, ell(cx + side * 3, 37.2, 1.9, 2.7, side * 12), "ink", 0.5)
    stroke(a, [(cx, 34), (cx, 15)], 1.1, smooth=False)       # the long tongue
    return a


@draws("cranefly")
def cranefly():
    a = Art()
    cx = 50
    for side in (1, -1):
        for b, k, e in [((2.6, 33), (17, 20), (35, 9)), ((3, 36), (22, 37), (43, 50)), ((2.6, 39), (15, 55), (33, 88))]:
            stroke(a, [(cx + side * b[0], b[1]), (cx + side * k[0], k[1]), (cx + side * e[0], e[1])], 0.8, smooth=False)
        w = wing_shape(cx + side * 2.4, 34, 90 - side * 62, 37, 4.6, 0.35)
        paint(a, w, "wing", 0.8, fa=0.85)
        t = turn(cx + side * 2.4, 34, 90 - side * 62)
        stroke(a, [t(3), t(34, -side * 0.8)], 0.45, 0.4, smooth=False)
        stroke(a, [t(16, 0), t(31, side * 2.6)], 0.45, 0.4, smooth=False)
    figure(a, [limb([(cx, 40), (cx, 76)], 4.2, 2.4)], "tan", close=0)
    for y in (48, 55, 62, 69):
        stroke(a, [(cx - 1.9, y), (cx + 1.9, y)], 0.5, 0.4, smooth=False)
    figure(a, [ell(cx, 35.5, 4, 5.4)], "brown", close=0)
    figure(a, [ell(cx, 27.6, 2.8, 2.6)], "brown", close=0)
    feelers(a, cx, 26, 2.6, 6, 5, 0, 0.7)
    return a


@draws("fly")
def fly():
    a = Art()
    hy, ty, ay = insect(a, head=(6, 4.4, "grey"), th=(7.6, 7.6, "slate"), ab=(7.8, 11.5, "slate"), eyes="rust",
                        bands=[(-0.3, -0.18, "black"), (0.24, 0.36, "black"), (0.7, 1.1, "black")],
                        wings=[(0, 30, 29, 6.6, "wing", 0.85)], legs=12, leg_lw=1.1, ant=(2.4, 2, 0))
    for dx in (-3.4, 0, 3.4):
        stroke(a, [(50 + dx, ty - 5.6), (50 + dx, ty + 5.6)], 0.9, 0.5, smooth=False)
    return a


# ----- beetles and bugs, also from above -----

def beetle(a, cx=50, top=None, head=(4, 3.2, "black"), pro=(7, 5, "black"), ely=(11, 19, "red"), marks=(), mark_col="black",
           legs=12, leg_lw=1.2, ant=(8, 9, 0), snout=0.0, square=0.0, club=0, shine=True, leg_angles=(-42, 8, 50)):
    """A beetle: head, a shield behind it (the pronotum) and the two hard
    wing cases (elytra) that meet in a line down the back.
      marks   spots on the wing cases: (across, down, size), across and down from -1 to 1
      square  how square the shoulders are (0 is an oval)
      snout   a weevil's long nose"""
    hrx, hry, hc = head; prx, pry, pc = pro; erx, ery, ec = ely
    total = 2 * hry + 2 * pry + 2 * ery - 3.4 + snout
    top = (50 - total / 2) if top is None else top
    hy = top + snout + hry; py = hy + hry + pry - 1.6; ey = py + pry + ery - 1.8
    if legs:
        six_legs(a, cx, py + pry * 0.9, max(prx, erx * 0.8), ery * 0.75, legs, leg_lw, leg_angles)
    if square:
        s = square
        cases = blob([(cx, ey - ery), (cx + erx * (0.62 + 0.3 * s), ey - ery * (0.92 - 0.06 * s)), (cx + erx, ey - ery * 0.4), (cx + erx * 0.94, ey + ery * 0.3),
                      (cx + erx * 0.55, ey + ery * 0.86), (cx, ey + ery), (cx - erx * 0.55, ey + ery * 0.86), (cx - erx * 0.94, ey + ery * 0.3),
                      (cx - erx, ey - ery * 0.4), (cx - erx * (0.62 + 0.3 * s), ey - ery * (0.92 - 0.06 * s))])
    else:
        cases = ell(cx, ey, erx, ery)
    sil = figure(a, [cases], ec, [(ell(cx + x * erx, ey + y * ery, r, r, n=20), mark_col) for x, y, r in marks], close=0)
    stroke(a, [(cx, ey - ery + 1.2), (cx, ey + ery - 0.6)], 0.8, 0.6, smooth=False)
    if shine:
        stroke(a, [(cx - erx * 0.55, ey - ery * 0.55), (cx - erx * 0.68, ey - ery * 0.1), (cx - erx * 0.6, ey + ery * 0.3)], 0.9, 0.5, col="white")
    figure(a, [ell(cx, py, prx, pry)], pc, close=0)
    if snout:
        figure(a, [limb([(cx, hy), (cx, hy - hry - snout)], 2.6, 1.8)], hc, close=0)
    figure(a, [ell(cx, hy, hrx, hry)], hc, close=0)
    if ant:
        ybase = hy - hry * 0.5 - snout * 0.6
        feelers(a, cx, ybase, hrx if not snout else 1.6, ant[0], ant[1], ant[2], club=club)
    return hy, py, ey


@draws("ladybird")
def ladybird():
    a = Art()
    hy, py, ey = beetle(a, head=(4.2, 2.8, "black"), pro=(8.6, 4.6, "black"), ely=(17, 18.5, "red"),
                        marks=[(0, -0.74, 3.1), (-0.52, -0.3, 2.9), (0.52, -0.3, 2.9), (-0.66, 0.26, 2.7), (0.66, 0.26, 2.7), (-0.3, 0.66, 2.5), (0.3, 0.66, 2.5)],
                        legs=9, leg_lw=1.1, ant=(3, 5, 0), club=0.8)
    for s in (1, -1):
        paint(a, ell(50 + s * 5.6, py - 0.4, 2.1, 2.5), "cream")
    return a


@draws("ground-beetle")
def ground_beetle():
    a = Art()
    hy, py, ey = beetle(a, head=(4.4, 4, "black"), pro=(7.6, 6.2, "black"), ely=(10.5, 20, "plum"), square=0.6,
                        legs=15, leg_lw=1.3, ant=(12, 12, 0), leg_angles=(-48, 12, 58))
    for dx in (-6.6, -3.3, 3.3, 6.6):
        stroke(a, [(50 + dx, ey - 15), (50 + dx * 0.96, ey), (50 + dx * 0.6, ey + 15)], 0.5, 0.35)
    for s in (1, -1):
        stroke(a, [(50 + s * 2, hy - 3.4), (50 + s * 3.4, hy - 6.4), (50 + s * 0.8, hy - 6.6)], 1.0, smooth=False)
    return a


@draws("flower-beetle")
def flower_beetle():
    a = Art()
    hy, py, ey = beetle(a, head=(3.8, 3.4, "rust"), pro=(4.8, 4.2, "rust"), ely=(6.2, 20, "orange"), square=0.8,
                        legs=14, leg_lw=1.0, ant=(14, 13, 0), leg_angles=(-46, 10, 58), shine=False)
    paint(a, band(50, ey, 6.2, 20, 0.72, 1.2).intersection(blob([(50, ey - 20), (56.2, ey - 8), (55.8, ey + 6), (53.4, ey + 17.2), (50, ey + 20),
                                                                 (46.6, ey + 17.2), (44.2, ey + 6), (43.8, ey - 8)])), "black")
    stroke(a, [(50, ey - 18.8), (50, ey + 19.4)], 0.8, 0.6, smooth=False)
    return a


@draws("longhorn")
def longhorn():
    a = Art()
    hy, py, ey = beetle(a, top=20, head=(4, 3.4, "black"), pro=(5, 4.4, "black"), ely=(7.6, 21, "yellow"), square=0.9,
                        marks=[(-0.5, -0.62, 2.9), (0.5, -0.62, 2.9)], legs=15, leg_lw=1.1, ant=None, shine=False, leg_angles=(-46, 10, 60))
    cases = blob([(50, ey - 21), (57.4, ey - 9), (57, ey + 6), (54.2, ey + 18), (50, ey + 21), (45.8, ey + 18), (43, ey + 6), (42.6, ey - 9)])
    for v1, v2 in [(-0.18, 0.08), (0.36, 0.58), (0.84, 1.2)]:
        paint(a, band(50, ey, 7.6, 21, v1, v2).intersection(cases), "black")
    stroke(a, [(50, ey - 19.6), (50, ey + 20.4)], 0.8, 0.6, smooth=False)
    paint(a, cases, None, LW)
    for s in (1, -1):   # the long horns: its feelers, swept out and back
        stroke(a, [(50 + s * 2.4, hy - 2.4), (50 + s * 12, hy - 8.5), (50 + s * 23, hy + 2), (50 + s * 27.5, hy + 22), (50 + s * 26, hy + 40)], 1.1)
    return a


@draws("chafer")
def chafer():
    a = Art()
    hy, py, ey = beetle(a, head=(4.8, 3.6, "black"), pro=(10.5, 6.6, "marrow"), ely=(13.5, 17.5, "green"), square=0.85,
                        legs=13, leg_lw=1.5, ant=(4, 7.5, 0), club=1.5)
    for x, y, w in [(-0.5, -0.1, 3.4), (0.46, 0.18, 3), (-0.38, 0.5, 2.4), (0.5, -0.36, 2.2)]:
        stroke(a, [(50 + x * 13.5 - w / 2, ey + y * 17.5), (50 + x * 13.5 + w / 2, ey + y * 17.5 + 0.5)], 0.9, 0.75, col="cream", smooth=False)
    paint(a, poly((46.4, py + 6), (53.6, py + 6), (50, py + 11.5)), "marrow", 0.7)
    return a


@draws("leaf-beetle")
def leaf_beetle():
    a = Art()
    hy, py, ey = beetle(a, head=(4.2, 3, "marrow"), pro=(8.4, 4.8, "marrow"), ely=(13, 17.5, "green"), legs=11, leg_lw=1.2, ant=(8.5, 10, 0))
    for dx in (-8, -4, 4, 8):
        for k in range(6):
            y = ey - 12 + k * 5
            if abs(dx) < 6 or abs(y - ey) < 11:
                a.dot(50 + dx * (1 - 0.012 * abs(y - ey)), y, 0.5, "marrow")
    return a


@draws("weevil")
def weevil():
    a = Art()
    hy, py, ey = beetle(a, head=(3.8, 3.4, "brown"), pro=(6.6, 5.4, "brown"), ely=(11, 16.5, "tan"), snout=10,
                        legs=12, leg_lw=1.3, ant=None)
    for dx in (-7, -3.5, 3.5, 7):
        stroke(a, [(50 + dx, ey - 12.5), (50 + dx * 0.95, ey), (50 + dx * 0.6, ey + 12.5)], 0.5, 0.4)
    spots(a, ell(50, ey, 11, 16.5), [(44, ey - 7), (56.5, ey - 3), (46, ey + 5), (54, ey + 8), (51.5, ey - 9)], 1.5, "brown", 0.7)
    for s in (1, -1):   # elbowed feelers half-way down the snout
        stroke(a, [(50 + s * 1, hy - 8), (50 + s * 6.5, hy - 12.5), (50 + s * 10.5, hy - 6.5)], 0.9, smooth=False)
        a.dot(50 + s * 10.5, hy - 6.5, 1.0, "line")
    return a


@draws("beetle")
def other_beetle():
    a = Art()
    hy, py, ey = beetle(a, head=(4.4, 3.6, "black"), pro=(8, 5.6, "black"), ely=(10.5, 18.5, "bark"), square=0.7,
                        legs=13, leg_lw=1.3, ant=(9, 10, 0))
    for dx in (-6.4, -3.2, 3.2, 6.4):
        stroke(a, [(50 + dx, ey - 14), (50 + dx * 0.96, ey), (50 + dx * 0.62, ey + 14)], 0.5, 0.35)
    return a


@draws("shield-bug")
def shield_bug():
    a = Art()
    cx = 50
    six_legs(a, cx, 45, 12, 10, 15, 1.1, angles=(-44, 6, 48))
    body = blob([(cx, 24), (cx + 6, 27), (cx + 18.5, 36), (cx + 15.5, 46), (cx + 14, 62), (cx + 8, 76), (cx, 80),
                 (cx - 8, 76), (cx - 14, 62), (cx - 15.5, 46), (cx - 18.5, 36), (cx - 6, 27)], 8)
    wingtips = ell(cx, 72, 9, 10)
    sil = figure(a, [body], "green", [(wingtips, "bark")], close=0)
    paint(a, poly((cx - 9.5, 41), (cx + 9.5, 41), (cx, 63)), "leaf", 0.8)                     # the triangle in the middle of its back
    stroke(a, [(cx - 16.5, 40), (cx, 41.5), (cx + 16.5, 40)], 0.7, 0.6)
    for s in (1, -1):
        stroke(a, [(cx + s * 9.5, 41), (cx + s * 13.6, 62)], 0.6, 0.5, smooth=False)
        stroke(a, [(cx + s * 3, 63), (cx + s * 9.6, 74)], 0.6, 0.5, smooth=False)
        for k in range(5):
            a.dot(cx + s * (14.6 - k * 0.5), 48 + k * 4, 0.55, "cream")
        stroke(a, [(cx + s * 2.6, 25), (cx + s * 7, 17), (cx + s * 13, 13), (cx + s * 16, 6.5)], 0.9)
        eye(a, cx + s * 5.2, 27.4, 0.9, False)
    return a


@draws("aphid")
def aphid():
    a = Art()
    cx = 50
    six_legs(a, cx, 44, 8, 9, 21, 0.9, angles=(-46, 4, 44))
    for s in (1, -1):
        stroke(a, [(cx + s * 5.5, 69), (cx + s * 9, 83)], 1.6, smooth=False)                    # the two little tubes at the back
        stroke(a, [(cx + s * 2.4, 27), (cx + s * 12, 22), (cx + s * 22, 33), (cx + s * 26, 50)], 0.8)
    body = blob([(cx, 25), (cx + 5.5, 28), (cx + 9, 40), (cx + 14.5, 56), (cx + 12, 71), (cx, 79), (cx - 12, 71), (cx - 14.5, 56), (cx - 9, 40), (cx - 5.5, 28)])
    figure(a, [body], "unripe", close=0)
    for y, w in [(46, 9), (53, 12), (60, 12.6), (67, 10.6)]:
        stroke(a, [(cx - w, y), (cx, y + 1.6), (cx + w, y)], 0.5, 0.35)
    stroke(a, [(cx, 79), (cx, 83)], 1.4, smooth=False)
    for s in (1, -1):
        eye(a, cx + s * 4.2, 29.5, 1.1, False)
    return a


@draws("hopper")
def hopper():
    a = Art()
    cx = 50
    six_legs(a, cx, 44, 9, 10, 12, 1.1, angles=(-36, 14, 62))
    body = blob([(cx, 22), (cx + 8, 25.5), (cx + 11.5, 36), (cx + 11, 52), (cx + 6.5, 70), (cx, 80), (cx - 6.5, 70), (cx - 11, 52), (cx - 11.5, 36), (cx - 8, 25.5)])
    sil = figure(a, [body], "tan", [(band(cx, 50, 12, 30, -0.36, -0.14), "cream"), (band(cx, 50, 12, 30, 0.2, 0.42), "cream"),
                                    (band(cx, 50, 12, 30, -0.14, 0.2), "brown"), (band(cx, 50, 12, 30, 0.42, 1.1), "brown")], close=0)
    stroke(a, [(cx, 37), (cx, 79)], 0.7, 0.6, smooth=False)
    stroke(a, [(cx - 10.8, 34), (cx, 37.5), (cx + 10.8, 34)], 0.7, 0.6)
    stroke(a, [(cx - 8.6, 27.5), (cx, 29.5), (cx + 8.6, 27.5)], 0.6, 0.5)
    for s in (1, -1):
        eye(a, cx + s * 8.4, 28.6, 1.2, False)
    return a


@draws("bug")
def plant_bug():
    a = Art()
    cx = 50
    six_legs(a, cx, 44, 7, 10, 16, 0.9, angles=(-44, 8, 54))
    body = blob([(cx, 21), (cx + 3.6, 23), (cx + 8.5, 33), (cx + 10.5, 48), (cx + 9, 66), (cx + 5, 78), (cx, 81), (cx - 5, 78), (cx - 9, 66), (cx - 10.5, 48), (cx - 8.5, 33), (cx - 3.6, 23)])
    figure(a, [body], "olive", [(ell(cx, 76, 7, 8), "bark"), (band(cx, 50, 12, 30, -1, -0.84), "brown")], close=0)
    paint(a, poly((cx - 4.6, 35), (cx + 4.6, 35), (cx, 43.5)), "yellow", 0.7)
    stroke(a, [(cx - 8.8, 34), (cx, 35.6), (cx + 8.8, 34)], 0.7, 0.6)
    for s in (1, -1):
        stroke(a, [(cx + s * 4.6, 35.4), (cx + s * 0.4, 62), (cx + s * 8.8, 67)], 0.6, 0.55, smooth=False)
        paint(a, poly((cx + s * 9.6, 60), (cx + s * 8.2, 68.4), (cx + s * 4.2, 65)), "orange")
        stroke(a, [(cx + s * 2, 23), (cx + s * 9, 13), (cx + s * 15, 11), (cx + s * 22, 17)], 0.8)
        eye(a, cx + s * 3.8, 24.6, 0.9, False)
    return a


@draws("gall-maker")
def gall_maker():
    a = Art()
    # an oak leaf, seen from below, with the galls a tiny wasp has made it grow
    lobes = [(50, 12), (57, 17), (62, 15), (66, 24), (72, 26), (71, 37), (78, 42), (74, 52), (79, 60), (72, 68), (71, 78), (62, 80), (56, 88),
             (50, 86), (44, 88), (38, 80), (29, 78), (28, 68), (21, 60), (26, 52), (22, 42), (29, 37), (28, 26), (34, 24), (38, 15), (43, 17)]
    leaf = figure(a, [blob(lobes, 6)], "leaf", close=0)
    stroke(a, [(50, 14), (50, 95)], 1.0, 0.6, smooth=False)
    for y, dx in [(28, 15), (42, 21), (56, 21), (70, 15)]:
        for s in (1, -1):
            stroke(a, [(50, y + 5), (50 + s * dx, y - 3)], 0.55, 0.4, smooth=False)
    for x, y, r in [(38, 33, 3.6), (60, 30, 3.2), (33, 49, 3.4), (64, 47, 3.8), (41, 62, 3.6), (59, 64, 3.3), (44, 46, 2.6), (56, 76, 2.8)]:
        figure(a, [ell(x, y, r, r * 0.92)], "amber", [(ell(x, y, r * 0.42, r * 0.4), "rust")], close=0, lw=0.8)
    figure(a, [ell(70, 20, 6.4, 6.2)], "primrose", [(ell(73, 22, 5, 5), "pink")], close=0)   # a cherry gall
    return a


# =====================================================================
# BUTTERFLIES AND MOTHS
# =====================================================================

@draws("butterfly")
def butterfly():
    a = Art()
    fore = blob([(52, 45), (58, 30), (72, 18), (88, 15), (91, 24), (84, 38), (72, 47), (56, 50)], 8)
    hind = blob([(52, 49), (66, 47), (80, 50), (85, 62), (79, 75), (67, 79), (58, 72), (53, 60)], 8)
    for side, flip in ((1, False), (-1, True)):
        for w, spot_at in ((hind, [(74, 62)]), (fore, [(80, 25)])):
            g = mirror(w) if flip else w
            sil = figure(a, [g], "orange", [(g.difference(g.buffer(-2.6)), "brown")], close=0)
            for x, y in spot_at:
                x = 100 - x if flip else x
                paint(a, ell(x, y, 4.4, 4.4, n=24).intersection(sil), "ink")
                paint(a, ell(x, y, 2.9, 2.9, n=24).intersection(sil), "blue")
                a.dot(x - 0.8, y - 0.8, 0.8, "white")
        for x, y, r in [(64, 31, 2.6), (70, 40, 2.2), (63, 58, 2.0)]:
            x = 100 - x if flip else x
            a.dot(x, y, r, "brown")
    figure(a, [ell(50, 55, 2.5, 14)], "brown", close=0)
    figure(a, [ell(50, 39, 2.9, 3)], "brown", close=0)
    for s in (1, -1):
        stroke(a, [(50 + s * 1.2, 36.5), (50 + s * 6, 24), (50 + s * 11, 15)], 0.8)
        a.dot(50 + s * 11, 15, 1.1, "line")
    return a


@draws("moth")
def moth():
    a = Art()
    hind = blob([(50, 60), (62, 62), (70, 72), (64, 81), (54, 80), (50, 74)], 8)
    fore = blob([(50.4, 27), (57, 28), (68, 44), (79, 68), (76, 76), (64, 77), (53, 68), (50.4, 52)], 8)
    for flip in (False, True):
        g = mirror(hind) if flip else hind
        figure(a, [g], "yellow", [(g.difference(g.buffer(-3)), "brown")], close=0)
    for flip in (False, True):
        g = mirror(fore) if flip else fore
        m = (lambda x: 100 - x) if flip else (lambda x: x)
        sil = figure(a, [g], "tan", [(g.difference(g.buffer(-2.2)), "bark")], close=0)
        stroke(a, [(m(54), 46), (m(60), 44), (m(66), 47)], 0.6, 0.5)
        stroke(a, [(m(54), 58), (m(62), 55), (m(70), 60), (m(74), 59)], 0.6, 0.5)
        paint(a, ell(m(61), 50.5, 2.6, 1.8, -20 if not flip else 20), "brown", 0.5)
        paint(a, ell(m(58), 41, 1.1, 1.1), "cream", 0.4)
    figure(a, [ell(50, 32, 5.6, 6.4)], "bark", close=0)
    figure(a, [ell(50, 24.6, 3.6, 2.8)], "bark", close=0)
    for s in (1, -1):
        stroke(a, [(50 + s * 2, 23), (50 + s * 9, 16), (50 + s * 19, 14)], 0.8)
        eye(a, 50 + s * 2.8, 24, 0.8, False)
    return a


@draws("micro-moth")
def micro_moth():
    a = Art()
    body = blob([(50, 26), (54.5, 28), (58.5, 44), (59.5, 62), (56.5, 76), (52, 80), (50, 77), (48, 80), (43.5, 76), (40.5, 62), (41.5, 44), (45.5, 28)], 8)
    sil = figure(a, [body], "buff", [(band(50, 53, 12, 27, 0.05, 0.42), "tan"), (band(50, 53, 12, 27, 0.72, 1.2), "tan")], close=0)
    stroke(a, [(50, 34), (50, 77)], 0.7, 0.55, smooth=False)
    for y in (71, 74, 77):
        for s in (1, -1):
            stroke(a, [(50 + s * 2, y + 2), (50 + s * 7, y - 1)], 0.4, 0.35, smooth=False)
    spots(a, sil, [(45.5, 48), (54.5, 48)], 1.3, "brown")
    for s_, pts in [(1, [(56, 34), (63, 30), (67, 24)]), (1, [(58.6, 46), (66, 47), (70, 53)]), (1, [(59, 62), (65, 68), (67, 76)])]:
        for side in (1, -1):
            stroke(a, [(50 + side * (x - 50), y) for x, y in pts], 0.8, smooth=False)
    figure(a, [ell(50, 25.6, 3.6, 3)], "tan", close=0)
    stroke(a, [(50, 23), (50, 18.5)], 1.4, smooth=False)                                       # the snout
    for s in (1, -1):
        stroke(a, [(50 + s * 2, 24), (50 + s * 9, 20), (50 + s * 15, 30), (50 + s * 17, 46)], 0.7)
        eye(a, 50 + s * 3, 25.6, 0.8, False)
    return a


# =====================================================================
# OTHER INSECTS
# =====================================================================

def dragon(a, damsel):
    cx = 50
    if damsel:
        wings = [(34, 66, 30, 3.6), (37, 50, 28, 3.4)]; top, w0, w1, colour, length = 26, 3.0, 2.2, "blue", 54
    else:
        wings = [(33, 96, 37, 6.2), (38.5, 82, 35, 7.4)]; top, w0, w1, colour, length = 22, 6.4, 3.2, "blue", 54
    for y, sweep, L, B in wings:
        for side in (1, -1):
            w = wing_shape(cx + side * 2.4, y, 90 - side * sweep, L, B, 0.5)
            paint(a, w, "wing", 0.8, fa=0.8)
            t = turn(cx + side * 2.4, y, 90 - side * sweep)
            stroke(a, [t(2), t(L - 2, -side * B * 0.25)], 0.45, 0.4, smooth=False)
            stroke(a, [t(L * 0.3, 0), t(L * 0.85, side * B * 0.5)], 0.45, 0.4, smooth=False)
            paint(a, Polygon([t(L * 0.8, -side * B * 0.5), t(L * 0.9, -side * B * 0.46), t(L * 0.9, -side * B * 0.86), t(L * 0.8, -side * B * 0.9)]).intersection(w), "brown")
    tail = limb([(cx, 42), (cx, 42 + length * 0.5), (cx, 42 + length * 0.86)], w0, w1)
    marks = [(band(cx, 42 + length * 0.43, 6, length * 0.43, v, v + 0.07), "black") for v in (-0.62, -0.3, 0.02, 0.34, 0.62)]
    if damsel:
        marks.append((band(cx, 42 + length * 0.43, 6, length * 0.43, 0.62, 0.84), "black"))
    figure(a, [tail], colour, marks, close=0)
    figure(a, [ell(cx, 36, 4.6 if not damsel else 3.2, 7 if not damsel else 6)], "black" if damsel else "olive",
           [(band(cx, 36, 3, 7, -1, 1).intersection(ell(cx - 1.6, 36, 0.7, 5)), "blue"), (ell(cx + 1.6, 36, 0.7, 5), "blue")] if damsel else [], close=0)
    if damsel:
        figure(a, [ell(cx, top + 2, 5.4, 2.4)], "black", close=0)
        for s in (1, -1):
            paint(a, ell(cx + s * 4.3, top + 2, 2, 2), "blue", 0.6)
    else:
        figure(a, [ell(cx, top + 3.4, 5.4, 4.2)], "olive", close=0)
        for s in (1, -1):
            paint(a, ell(cx + s * 2.6, top + 2.6, 2.8, 3.4, s * 20), "green", 0.6)
    return a


@draws("dragonfly")
def dragonfly():
    return dragon(Art(), False)


@draws("damselfly")
def damselfly():
    return dragon(Art(), True)


def jumper(a, cricket):
    """A grasshopper or a bush-cricket, from the side, facing right."""
    colour = "leaf" if cricket else "olive"
    stroke(a, [(60, 60), (63, 70), (67, 76)], 1.1, smooth=False)                              # the far legs
    stroke(a, [(52, 62), (51, 72), (55, 78)], 1.1, smooth=False)
    body = blob([(24, 57), (36, 50), (56, 46), (70, 46), (72, 58), (62, 64), (44, 66), (30, 63)], 8)
    head = blob([(69, 41), (76, 39.5), (80.5, 45), (80.5, 55), (76.5, 61), (70, 60)], 8)
    if cricket:
        figure(a, [limb([(27, 60), (17, 60), (9, 53)], 3.4, 1.0)], "bark", close=0)           # her sword-shaped egg-layer
    figure(a, [body, head], colour, [(blob([(26, 56), (40, 49), (58, 45.5), (62, 50), (44, 55), (30, 60)]), "deep" if cricket else "tan")], close=1.4)
    stroke(a, [(69.5, 42), (67.6, 51), (70, 60)], 0.7, 0.55)
    stroke(a, [(59, 46), (56.4, 54), (59.4, 63)], 0.7, 0.55)
    if cricket:
        spots(a, body, [(34, 61), (40, 62), (47, 61), (53, 60), (38, 57), (50, 57)], 0.5, "deep")
    figure(a, [limb([(51, 59), (40, 44), (29, 31)], 7.2, 2.6)], colour, close=0)             # the big jumping leg
    stroke(a, [(48, 55), (33, 36)], 0.6, 0.45, smooth=False)
    stroke(a, [(29, 31), (25, 52), (22, 74), (27, 77)], 1.2, smooth=False)
    stroke(a, [(64, 62), (69, 72), (74, 77)], 1.2, smooth=False)
    stroke(a, [(56, 64), (57, 74), (62, 79)], 1.2, smooth=False)
    eye(a, 76.6, 45.4, 1.5, True)
    if cricket:
        stroke(a, [(76, 40), (66, 22), (44, 12), (18, 16)], 0.7)
        stroke(a, [(77, 40), (72, 20), (54, 7), (30, 6)], 0.7)
    else:
        stroke(a, [(77, 40.4), (82, 31), (88, 25)], 1.0)
        stroke(a, [(76, 40), (79, 29), (83, 22)], 1.0)
    return a


@draws("grasshopper")
def grasshopper():
    return jumper(Art(), False)


@draws("cricket")
def cricket():
    return jumper(Art(), True)


@draws("earwig")
def earwig():
    a = Art()
    cx = 50
    six_legs(a, cx, 34, 4.4, 7, 11, 1.0, angles=(-38, 8, 50))
    for s in (1, -1):   # the pincers
        stroke(a, [(cx + s * 2.6, 76), (cx + s * 6, 82), (cx + s * 4.6, 90), (cx + s * 0.8, 93)], 1.5)
    tail = blob([(cx, 40), (cx + 5.2, 44), (cx + 6.4, 58), (cx + 5, 72), (cx + 3, 78), (cx - 3, 78), (cx - 5, 72), (cx - 6.4, 58), (cx - 5.2, 44)])
    figure(a, [tail], "rust", close=0)
    for y in (48, 54, 60, 66, 72):
        w = 6 if y < 68 else 4.6
        stroke(a, [(cx - w, y), (cx, y + 1), (cx + w, y)], 0.55, 0.45)
    figure(a, [blob([(cx - 5, 31), (cx + 5, 31), (cx + 5.6, 44), (cx, 46), (cx - 5.6, 44)], 6)], "tan", close=0)   # short wing cases
    stroke(a, [(cx, 31.5), (cx, 45.5)], 0.6, 0.5, smooth=False)
    figure(a, [ell(cx, 27.5, 5.2, 3.8)], "bark", close=0)
    figure(a, [ell(cx, 20.6, 4.2, 4)], "rust", close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 2, 17.6), (cx + s * 8, 11), (cx + s * 17, 9), (cx + s * 24, 13)], 0.8)
        eye(a, cx + s * 3.3, 20, 0.8, False)
    return a


@draws("lacewing")
def lacewing():
    a = Art()
    cx = 50
    figure(a, [limb([(cx, 26), (cx, 62)], 3.6, 2.2)], "leaf", close=0)
    for s in (1, -1):
        for sweep, L, B in [(15, 54, 8.6), (7, 47, 6.4)]:
            w = wing_shape(cx + s * 1.5, 29, 90 - s * sweep, L, B, 0.4)
            paint(a, w, "wing", 0.8, fa=0.62)
            t = turn(cx + s * 1.5, 29, 90 - s * sweep)
            stroke(a, [t(2), t(L - 2, -s * B * 0.2)], 0.4, 0.4, smooth=False)
            stroke(a, [t(4, s * B * 0.1), t(L - 5, s * B * 0.55)], 0.4, 0.4, smooth=False)
            for k in range(1, 9):
                u = k / 9
                stroke(a, [t(L * u, -s * B * 0.55 * math.sin(math.pi * u) ** 0.6), t(L * u + 1.6, s * B * 0.62 * math.sin(math.pi * u) ** 0.6)], 0.35, 0.35, smooth=False)
    six_legs(a, cx, 30, 2.6, 5, 15, 0.8, angles=(-44, 2, 46))
    figure(a, [limb([(cx, 26), (cx, 34)], 3.8, 3.4)], "leaf", close=0)
    figure(a, [ell(cx, 22.6, 3.6, 3)], "leaf", close=0)
    for s in (1, -1):
        a.dot(cx + s * 3, 22.2, 1.3, "amber")
        stroke(a, [(cx + s * 1.2, 20.2), (cx + s * 7, 10), (cx + s * 16, 5), (cx + s * 25, 8)], 0.7)
    return a


@draws("riverfly")
def riverfly():
    a = Art()
    # a mayfly from the side, facing right, wings held upright
    for dy, ex in [(-3.5, 6), (0, 2), (3.5, 8)]:
        stroke(a, [(28, 68), (16, 70 + dy * 2), (ex, 66 + dy * 4.5)], 0.7)                   # three long tails
    figure(a, [limb([(70, 60), (56, 62), (40, 66), (28, 68)], 5.6, 2.2)], "primrose", close=0)
    for x in (36, 42, 48, 54):
        stroke(a, [(x, 62.6 + (56 - x) * 0.09), (x + 0.8, 67.4 + (56 - x) * 0.05)], 0.5, 0.45, smooth=False)
    big = blob([(63, 56), (56, 34), (57, 13), (64, 9), (76, 22), (79, 42), (71, 57)], 8)
    small = blob([(58, 58), (47, 49), (44, 39), (50, 37), (58, 46)], 8)
    paint(a, small, "wing", 0.8, fa=0.8)
    paint(a, big, "wing", 0.8, fa=0.8)
    for x0, x1, y1 in [(64, 60, 14), (66, 66, 12), (68, 73, 20), (69, 77, 32)]:
        stroke(a, [(x0, 55), (x1, y1)], 0.4, 0.4, smooth=False)
    for y in (22, 30, 38, 46):
        stroke(a, [(57.5, y + 1), (76 + (y - 22) * 0.1, y + 3)], 0.35, 0.35, smooth=False)
    figure(a, [ell(68, 60, 7, 4.4, -8)], "tan", close=0)
    figure(a, [ell(77.5, 57.5, 3.4, 3.1)], "tan", close=0)
    eye(a, 78.6, 56.8, 1.5, True)
    stroke(a, [(72, 62), (82, 66), (90, 60), (95, 61)], 0.8, smooth=False)                    # long front legs, held out
    stroke(a, [(69, 63.5), (71, 72), (76, 76)], 0.8, smooth=False)
    stroke(a, [(64, 64), (62, 73), (66, 78)], 0.8, smooth=False)
    return a


@draws("other-insect")
def other_insect():
    a = Art()
    # a springtail: small, wingless, with stout feelers
    cx = 50
    six_legs(a, cx, 44, 6.4, 8, 12, 1.0, angles=(-40, 6, 48))
    body = blob([(cx, 33), (cx + 6.6, 36), (cx + 9.4, 50), (cx + 8, 66), (cx + 3.6, 76), (cx - 3.6, 76), (cx - 8, 66), (cx - 9.4, 50), (cx - 6.6, 36)])
    figure(a, [body], "slate", [(band(cx, 55, 12, 22, v, v + 0.1), "grey") for v in (-0.62, -0.3, 0.02, 0.34, 0.66)], close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 1.4, 76), (cx + s * 4.6, 84)], 1.2, smooth=False)                 # the fork it springs with
    figure(a, [ell(cx, 28, 5.6, 5.2)], "slate", close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 3, 24.6), (cx + s * 8, 17), (cx + s * 14.5, 14.5), (cx + s * 18, 19.5)], 1.5)
        eye(a, cx + s * 3.6, 27.4, 1.0, False)
    return a


# =====================================================================
# SPIDERS AND OTHER MINIBEASTS
# =====================================================================

@draws("spider")
def spider():
    a = Art()
    cx = 50
    for s in (1, -1):
        for b, k, e in [((3.6, 34), (15, 17), (27, 9)), ((4.6, 36.5), (24, 28), (39, 31)), ((4.6, 39.5), (25, 46), (38, 61)), ((3.6, 42), (15, 60), (22, 82))]:
            pts = [(cx + s * b[0], b[1]), (cx + s * k[0], k[1]), (cx + s * e[0], e[1])]
            stroke(a, pts, 1.7, smooth=False, col="brown")
            mx, my = (pts[1][0] + pts[2][0]) / 2, (pts[1][1] + pts[2][1]) / 2
            stroke(a, [((pts[1][0] + mx) / 2, (pts[1][1] + my) / 2), (mx, my)], 1.7, col="cream", smooth=False, la=0.9)
        stroke(a, [(cx + s * 1.8, 30), (cx + s * 3, 24.6)], 1.6, smooth=False, col="brown")     # palps
    abdomen = blob([(cx, 43), (cx + 9.5, 47), (cx + 13, 58), (cx + 10, 70), (cx, 76), (cx - 10, 70), (cx - 13, 58), (cx - 9.5, 47)])
    sil = figure(a, [abdomen], "tan", [(abdomen.difference(abdomen.buffer(-2.4)), "brown")], close=0)
    for x, y, r in [(cx, 49.5, 1.5), (cx, 54, 1.5), (cx, 58.5, 1.5), (cx, 63, 1.3), (cx - 4.4, 54, 1.4), (cx + 4.4, 54, 1.4), (cx, 67.5, 1.1)]:
        a.dot(x, y, r, "cream")
    figure(a, [ell(cx, 37, 6.4, 7)], "brown", close=0)
    for dx in (-2.4, -0.8, 0.8, 2.4):
        a.dot(cx + dx, 31.6, 0.6, "ink")
    return a


@draws("woodlouse")
def woodlouse():
    a = Art()
    cx = 50
    for s in (1, -1):
        for k in range(7):
            y = 36 + k * 5.4
            stroke(a, [(cx + s * 12, y), (cx + s * 19.5, y + 2.6)], 1.0, smooth=False)
        stroke(a, [(cx + s * 3, 24.5), (cx + s * 10, 16), (cx + s * 19, 14.5)], 1.1, smooth=False)
        stroke(a, [(cx + s * 2.6, 78), (cx + s * 4.6, 84)], 1.3, smooth=False)
    body = blob([(cx, 21), (cx + 8.5, 24), (cx + 15, 36), (cx + 16.5, 52), (cx + 13.5, 68), (cx + 6, 78), (cx, 80), (cx - 6, 78), (cx - 13.5, 68), (cx - 16.5, 52), (cx - 15, 36), (cx - 8.5, 24)])
    sil = figure(a, [body], "slate", [(body.difference(body.buffer(-2.2)), "grey")], close=0)
    for k, y in enumerate([30, 36.5, 43, 49.5, 56, 62.5, 68, 72.5, 76]):
        w = math.sqrt(max(0, 1 - ((y - 50.5) / 30) ** 2)) * 16.5
        stroke(a, [(cx - w, y), (cx, y + 2.2), (cx + w, y)], 0.6, 0.55)
    spots(a, sil, [(cx - 6, 40), (cx + 6, 46), (cx - 5, 53), (cx + 5, 59), (cx - 4, 65)], 1.5, "grey", 0.8)
    for s in (1, -1):
        eye(a, cx + s * 5.4, 25.6, 0.9, False)
    return a


def along(pts, n=60):
    """Points along a smooth line with the direction at each: [(x, y, angle)]."""
    c = curve(pts, 16); out = []
    step = max(1, len(c) // n)
    for i in range(0, len(c) - 1, step):
        (x0, y0), (x1, y1) = c[i], c[min(i + step, len(c) - 1)]
        out.append((x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0))))
    return out


@draws("centipede")
def centipede():
    a = Art()
    line = [(80, 20), (62, 24), (48, 36), (52, 52), (60, 64), (48, 78), (26, 82)]
    pts = along(line, 21)
    for i, (x, y, ang) in enumerate(pts[1:]):
        for s in (1, -1):
            t = turn(x, y, ang + s * 90)
            stroke(a, [t(1.5), t(6.2, -1.2), t(9.4, 1.2)], 0.9, smooth=False)
    x, y, ang = pts[-1]
    for s in (1, -1):
        stroke(a, [(x, y), turn(x, y, ang + s * 16)(13)], 0.9, smooth=False)                   # the long last legs
    figure(a, [limb(line, 6.4, 5)], "rust", close=0)
    for x, y, ang in pts[1:]:
        t = turn(x, y, ang + 90)
        stroke(a, [t(-2.9), t(2.9)], 0.55, 0.5, smooth=False)
    figure(a, [ell(82, 19.6, 4.4, 4, -12)], "orange", close=0)
    stroke(a, [(84.5, 17), (90, 9), (97, 8)], 0.9)
    stroke(a, [(85.4, 20), (92, 17), (97, 21)], 0.9)
    eye(a, 83.4, 18.4, 0.8, False)
    return a


# =====================================================================
# SLUGS, SNAILS AND WORMS
# =====================================================================

@draws("earthworm")
def earthworm():
    a = Art()
    line = [(14, 62), (28, 46), (44, 52), (54, 66), (70, 64), (86, 46)]
    figure(a, [limb(line, 5.4, 6.4)], "skin", close=0)
    c = curve(line, 16)
    saddle = limb(c[52:63], 7.6, 7.6, smooth=False)
    figure(a, [saddle], "tan", close=0, lw=0.9)                                               # the saddle, nearer the head end
    for i in range(3, len(c) - 2, 3):
        if 50 <= i <= 64:
            continue
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)) + 90)
        w = 3.0 - 0.6 * i / len(c)
        stroke(a, [t(-w), t(w)], 0.45, 0.4, smooth=False)
    return a


@draws("slug")
def slug():
    a = Art()
    body = blob([(10, 66), (24, 58), (44, 51), (62, 49), (76, 52), (87, 58), (90, 65), (84, 69), (60, 70), (34, 70), (16, 69.5)], 8)
    mantle = blob([(52, 50), (66, 47.5), (78, 52), (79, 60), (66, 63), (53, 59)], 8)
    for bx, by, ex, ey_ in [(86, 58, 93, 47), (83.5, 56.5, 88, 45.5)]:
        stroke(a, [(bx, by), (ex, ey_)], 1.4, smooth=False)
        a.dot(ex, ey_, 1.3, "line")
    stroke(a, [(89, 64), (95, 63)], 1.2, smooth=False)
    sil = figure(a, [body], "tan", [(band(50, 69, 50, 4, 0, 1.2), "buff")], close=0)
    figure(a, [mantle], "bark", close=0, lw=0.9)
    spots(a, sil, [(20, 63), (28, 60), (36, 62), (44, 57), (30, 66), (46, 64), (40, 53.5)], 1.3, "brown")
    spots(a, mantle, [(60, 53), (68, 56), (73, 53), (64, 59)], 1.2, "brown")
    a.dot(75.5, 58, 1.0, "ink")                                                                # its breathing hole
    stroke(a, [(8, 71.5), (92, 71.5)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("snail")
def snail():
    a = Art()
    body = blob([(16, 70), (30, 66), (56, 65), (72, 62), (80, 53), (86, 52), (88, 58), (84, 68), (74, 72), (40, 73), (20, 73)], 8)
    for bx, by, ex, ey_ in [(84, 53, 91, 40), (81, 54, 84, 41)]:
        stroke(a, [(bx, by), (ex, ey_)], 1.4, smooth=False)
        a.dot(ex, ey_, 1.4, "line")
    figure(a, [body], "buff", close=0)
    shell = ell(46, 45, 23, 22, -8)
    sil = figure(a, [shell], "yellow", close=0)
    spiral = []
    for k in range(0, 150):
        th = math.radians(k * 6.2 - 50); r = 21.6 * (1 - k / 150) ** 1.25
        spiral.append((45.5 + r * math.cos(th) * 1.02 - (1 - k / 150) * 0, 45.5 + r * math.sin(th)))
    stroke(a, spiral[8:], 1.0, 0.8, smooth=False)
    stroke(a, [(q[0] * 0.86 + 45.5 * 0.14, q[1] * 0.86 + 45.5 * 0.14) for q in spiral[10:58]], 2.0, 0.6, col="brown", smooth=False)
    stroke(a, [(8, 74.5), (92, 74.5)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("worm")
def worm():
    a = Art()
    # a land flatworm: flat, shiny, with a stripe and a spade-shaped head
    line = [(16, 34), (30, 28), (44, 38), (50, 54), (62, 64), (78, 60), (86, 68)]
    figure(a, [limb(line, 4.2, 8.6), ell(86.6, 68.6, 5.4, 4.6, 40)], "buff", [(limb(line, 1.6, 3.4), "pink")], close=1.2)
    stroke(a, [(q[0] - 0.9, q[1] - 0.9) for q in curve(line, 10)[6:-6]], 0.6, 0.6, col="white")
    return a


# =====================================================================
# BIRDS, FROM THE SIDE, FACING RIGHT
# =====================================================================

def bird(a, bx=44, by=56, bl=19, bd=12.5, tilt=-22, hr=8.4, hdx=0.0, hdy=0.0, neck=None,
         bill=(6.5, 3.0, "cone", "dark"), tail=(19, 6.5, "square"), tail_ang=None, tail_col=None,
         legs=(11, "dark"), leg_at=(-3, 5), feet="perch",
         back="brown", belly="cream", cap=None, cheek=None, bib=None, breast=None, wing=None, wingbars=(), nape=None,
         rump=None, eyeline=False, eyebrow=None, streaks=False, face=None, collar=None, wing_len=1.0, eye_r=1.3, extra=()):
    """A bird built from an oval body, a round head, a tail and a bill.
      bx, by, bl, bd   where the body is, its half-length and half-depth
      tilt             how it leans: 0 is level, more negative is more upright
      bill             (length, depth, shape, colour). Shapes: cone, fine, dagger, hook, duck, curve
      tail             (length, width, shape). Shapes: square, fork, point, fan
      feet             perch (on a twig), stand (on the ground), swim (on water) or none
      back, belly...   the colours of each part. A part left as None takes the colour around it."""
    t = turn(bx, by, tilt)
    body = ell(bx, by, bl, bd, tilt)
    front = t(bl * 0.72, -bd * 0.35)
    hx, hy = front[0] + hr * 0.25 + hdx, front[1] - hr * 0.62 + hdy
    head = ell(hx, hy, hr, hr * 0.94)
    rear = t(-bl * 0.84, -bd * 0.06)
    ta = (tilt + 180 - 14) if tail_ang is None else tail_ang
    tl, tw, tk = tail
    tt = turn(rear[0], rear[1], ta)
    if tk == "fork":
        tail_g = poly(tt(-3, -tw * 0.42), tt(tl, -tw * 0.62), tt(tl * 0.56, 0), tt(tl, tw * 0.62), tt(-3, tw * 0.42))
    elif tk == "point":
        tail_g = poly(tt(-3, -tw * 0.5), tt(tl * 0.6, -tw * 0.34), tt(tl, 0), tt(tl * 0.6, tw * 0.34), tt(-3, tw * 0.5))
    elif tk == "fan":
        tail_g = poly(tt(-3, -tw * 0.36), tt(tl, -tw * 0.7), tt(tl * 1.06, 0), tt(tl, tw * 0.7), tt(-3, tw * 0.36))
    else:
        tail_g = poly(tt(-3, -tw * 0.46), tt(tl, -tw * 0.5), tt(tl, tw * 0.5), tt(-3, tw * 0.46))
    # legs and feet go behind the body
    lx = [bx + leg_at[0], bx + leg_at[1]]
    ground = by + bd * 0.75 + legs[0]
    if feet in ("perch", "stand"):
        for i, x in enumerate(lx):
            top = (x, by + bd * 0.6)
            foot = (x + 1.2, ground)
            stroke(a, [top, foot], 1.3, col=legs[1], smooth=False)
            stroke(a, [(foot[0] - 2.4, foot[1] + 0.2), foot, (foot[0] + 3.4, foot[1] + 0.2)], 1.2, col=legs[1], smooth=False)
        if feet == "perch":
            figure(a, [limb([(lx[0] - 24, ground + 4.4), (lx[0], ground + 2.2), (lx[1] + 24, ground + 3.4)], 3.4, 2.6)], "bark", close=0, lw=0.9)
    # the bill, behind the head
    bl_, bdp, bk, bc = bill
    b0 = (hx + hr * 0.78, hy + hr * 0.12)
    if bk == "hook":
        bill_g = blob([(b0[0] - 2, b0[1] - bdp * 0.6), (b0[0] + bl_ * 0.6, b0[1] - bdp * 0.5), (b0[0] + bl_, b0[1] + bdp * 0.25), (b0[0] + bl_ * 0.8, b0[1] + bdp * 0.9),
                       (b0[0] + bl_ * 0.5, b0[1] + bdp * 0.42), (b0[0] - 2, b0[1] + bdp * 0.5)], 6)
    elif bk == "duck":
        bill_g = blob([(b0[0] - 2, b0[1] - bdp * 0.5), (b0[0] + bl_ * 0.6, b0[1] - bdp * 0.3), (b0[0] + bl_, b0[1] + bdp * 0.1), (b0[0] + bl_ * 0.92, b0[1] + bdp * 0.6), (b0[0] - 2, b0[1] + bdp * 0.6)], 6)
    elif bk == "curve":
        bill_g = limb([(b0[0] - 2, b0[1]), (b0[0] + bl_ * 0.5, b0[1] + 0.6), (b0[0] + bl_, b0[1] + bl_ * 0.26)], bdp, 0.7)
    else:
        drop = {"cone": 0.3, "fine": 0.2, "dagger": 0.25}[bk]
        bill_g = poly((b0[0] - 2.4, b0[1] - bdp * 0.55), (b0[0] + bl_, b0[1] + bdp * drop), (b0[0] - 2.4, b0[1] + bdp * 0.6))
    figure(a, [bill_g], bc, close=0, lw=0.9)
    if bk in ("dagger", "duck", "cone") and bl_ > 5:
        stroke(a, [(b0[0] - 1, b0[1] + bdp * 0.1), (b0[0] + bl_ * 0.82, b0[1] + bdp * (0.25 if bk != "duck" else 0.2))], 0.45, 0.5, smooth=False)
    parts = [body, head, tail_g]
    if neck:
        parts.append(limb([front, *neck, (hx - hr * 0.2, hy + hr * 0.3)], bd * 0.95, hr * 1.2))
    patches = []
    patches.append((tail_g.buffer(0.2), tail_col or wing or back))
    under = ell(t(bl * 0.12, bd * 0.62)[0], t(bl * 0.12, bd * 0.62)[1], bl * 1.02, bd * 0.72, tilt + 6)
    if neck:
        under = unary_union([under, limb([t(bl * 0.6, bd * 0.3), *[(q[0] + 2.6, q[1] + 1) for q in neck], (hx + 1, hy + hr * 0.8)], bd * 0.7, hr * 0.7)])
    patches.append((unary_union([under, ell(hx + hr * 0.3, hy + hr * 0.75, hr * 0.8, hr * 0.6)]), belly))
    if breast:
        patches.append((ell(t(bl * 0.6, bd * 0.3)[0], t(bl * 0.6, bd * 0.3)[1], bl * 0.6, bd * 0.86, tilt - 35).intersection(under.buffer(2)), breast))
    if rump:
        patches.append((ell(rear[0] + 2, rear[1] + 2, bl * 0.36, bd * 0.6, tilt), rump))
    if nape:
        patches.append((ell(hx - hr * 0.75, hy + hr * 0.25, hr * 0.5, hr * 0.8), nape))
    if cap:
        patches.append((head.intersection(poly((hx - hr * 1.3, hy - hr * 1.3), (hx + hr * 1.3, hy - hr * 1.3), (hx + hr * 1.3, hy - hr * 0.22), (hx - hr * 1.3, hy + hr * 0.1))), cap))
    if collar:
        patches.append((ell(hx - hr * 0.2, hy + hr * 0.98, hr * 1.1, hr * 0.24, -14), collar))
    if cheek:
        patches.append((ell(hx + hr * 0.1, hy + hr * 0.3, hr * 0.72, hr * 0.5), cheek))
    if face:
        patches.append((ell(hx + hr * 0.52, hy + hr * 0.12, hr * 0.56, hr * 0.74), face))
    if bib:
        patches.append((ell(hx + hr * 0.42, hy + hr * 0.92, hr * 0.56, hr * 0.5), bib))
    patches.extend(extra)
    sil = figure(a, parts, back, patches, close=1.6)
    if streaks:
        for i in range(9):
            p = t(bl * (0.72 - (i % 5) * 0.2), bd * (0.2 + (i // 5) * 0.34 + (i % 2) * 0.08))
            if sil.contains(Polygon([(p[0] - 0.3, p[1] - 0.3), (p[0] + 0.3, p[1] - 0.3), (p[0], p[1] + 0.3)])):
                stroke(a, [p, (p[0] - 0.9, p[1] + 2)], 0.7, 0.6, col=streaks if isinstance(streaks, str) else "brown", smooth=False)
    # the folded wing
    wc = wing or back
    w = blob([t(bl * 0.5, -bd * 0.56), t(bl * 0.1, -bd * 0.78), t(-bl * 0.5, -bd * 0.5), t(-bl * (0.84 + 0.5 * (wing_len - 1)), -bd * 0.02 * wing_len - (wing_len - 1) * 3),
              t(-bl * 0.42, bd * 0.24), t(bl * 0.2, bd * 0.2), t(bl * 0.52, -bd * 0.1)], 8)
    wsil = figure(a, [w.intersection(sil.buffer(3 + (wing_len - 1) * 14))], wc, [(band(t(-bl * 0.1, -bd * 0.2)[0], t(-bl * 0.1, -bd * 0.2)[1], bd, bl, v1, v2, tilt + 90), c) for v1, v2, c in wingbars],
                  close=0, lw=0.9)
    stroke(a, [t(bl * 0.2, bd * 0.02), t(-bl * 0.3, bd * 0.06), t(-bl * 0.72, -bd * 0.02)], 0.5, 0.45)
    if eyebrow:
        stroke(a, [(hx - hr * 0.5, hy - hr * 0.34), (hx + hr * 0.2, hy - hr * 0.52), (hx + hr * 0.75, hy - hr * 0.3)], 1.3, 0.95, col=eyebrow)
    if eyeline:
        stroke(a, [(hx - hr * 0.86, hy - hr * 0.04), (hx + hr * 0.3, hy - hr * 0.14), (hx + hr * 0.88, hy + hr * 0.05)], 1.2, 0.95, col="ink" if eyeline is True else eyeline)
    eye(a, hx + hr * 0.36, hy - hr * 0.16, eye_r)
    if feet == "swim":
        y = by + bd * 0.56
        figure(a, [blob([(bx - bl - 16, y), (bx - bl * 0.4, y - 1.3), (bx + bl * 0.5, y + 0.8), (bx + bl + 16, y - 0.6), (bx + bl + 12, y + 6), (bx, y + 7.6), (bx - bl - 12, y + 6)], 8)],
               "water", close=0, lw=0, shade=False)
        stroke(a, [(bx - bl - 16, y), (bx - bl * 0.4, y - 1.3), (bx + bl * 0.5, y + 0.8), (bx + bl + 16, y - 0.6)], 0.9, 0.7, col="slate")
        stroke(a, [(bx - bl - 6, y + 4.4), (bx - bl + 6, y + 3.6)], 0.7, 0.5, col="slate", smooth=False)
        stroke(a, [(bx + bl - 2, y + 4.6), (bx + bl + 9, y + 3.8)], 0.7, 0.5, col="slate", smooth=False)
    elif feet == "stand":
        stroke(a, [(lx[0] - 22, ground + 1.4), (lx[1] + 24, ground + 1.4)], 0.8, 0.5, col="soil", smooth=False)
    return sil, (hx, hy), t


@draws("tit")
def tit():
    a = Art()
    bird(a, bl=16.5, bd=12.5, hr=8.6, bill=(4.2, 2.6, "cone", "dark"), tail=(17, 5.6, "square"), back="deep", belly="yellow",
         cap="steel", cheek="white", bib="ink", wing="steel", wingbars=[(-0.1, 0.02, "white")], eyeline=True, legs=(10, "slate"))
    return a


@draws("finch")
def finch():
    a = Art()
    bird(a, bl=17.5, bd=12.5, hr=8.6, bill=(6.2, 5.2, "cone", "buff"), tail=(17, 6, "fork"), back="tan", belly="cream", breast="buff",
         cap="ink", cheek="white", face="red", wing="black", wingbars=[(-0.35, 0.1, "yellow")], legs=(10, "skin"))
    return a


@draws("thrush")
def thrush():
    a = Art()
    bird(a, bl=17, bd=13.5, tilt=-34, hr=8.8, bill=(5.6, 2.2, "fine", "dark"), tail=(16, 5.8, "square"), back="brown", belly="cream",
         breast="orange", face="orange", legs=(13, "brown"))
    return a


@draws("warbler")
def warbler():
    a = Art()
    bird(a, bl=18.5, bd=10.5, tilt=-12, hr=7.6, bill=(6, 1.8, "fine", "dark"), tail=(18, 5, "square"), back="olive", belly="primrose",
         eyebrow="primrose", eyeline="brown", legs=(10, "dark"))
    return a


@draws("crow")
def crow():
    a = Art()
    bird(a, bx=44, by=52, bl=23, bd=13.5, tilt=-20, hr=9.6, bill=(11, 5, "cone", "black"), tail=(21, 9, "square"), back="black", belly="black",
         wing="black", legs=(15, "slate"), feet="stand", leg_at=(-2, 7))
    return a


@draws("pigeon")
def pigeon():
    a = Art()
    bird(a, bx=44, by=54, bl=23, bd=14.5, tilt=-20, hr=7.4, bill=(5, 2.4, "fine", "amber"), tail=(18, 9, "square"), tail_col="slate", back="grey", belly="grey",
         breast="pink", collar="white", wing="grey", wingbars=[(-0.62, -0.5, "white")], legs=(11, "red"), feet="stand", leg_at=(-2, 7), eye_r=1.1)
    return a


@draws("woodpecker")
def woodpecker():
    a = Art()
    figure(a, [poly((74, 4), (92, 4), (90, 96), (72, 96))], "bark", close=0, lw=0.9)
    for y0, y1, x in [(10, 26, 79), (34, 50, 85), (58, 80, 80), (20, 30, 87), (70, 90, 87)]:
        stroke(a, [(x, y0), (x + 0.8, (y0 + y1) / 2), (x - 0.4, y1)], 0.6, 0.45)
    stroke(a, [(56, 70), (66, 74), (73, 70)], 1.3, col="slate", smooth=False)
    stroke(a, [(55, 60), (66, 62), (73, 58)], 1.3, col="slate", smooth=False)
    sil, (hx, hy), t = bird(a, bx=52, by=52, bl=19, bd=10.5, tilt=-72, hr=7.6, hdx=1, hdy=1, bill=(9, 3, "dagger", "slate"), tail=(18, 6, "point"), tail_ang=112,
                            back="black", belly="cream", cheek="white", nape="red", wing="black", wingbars=[(-0.5, -0.24, "white"), (0.3, 0.38, "white"), (0.56, 0.64, "white")],
                            feet="none", extra=[(ell(40, 73, 5.4, 6.6), "red")])
    return a


@draws("swallow")
def swallow():
    a = Art()
    stroke(a, [(4, 75.6), (96, 73.4)], 1.1, 0.8, col="slate", smooth=False)                    # a wire to sit on
    bird(a, bx=47, by=56, bl=17.5, bd=10, tilt=-30, hr=7.2, bill=(3.6, 1.8, "fine", "dark"), tail=(34, 7, "fork"), tail_ang=140, back="steel", belly="cream",
         face="rust", bib="rust", wing="steel", wing_len=1.75, legs=(7.5, "dark"), feet="none", leg_at=(-1, 4))
    for x in (46, 51):
        stroke(a, [(x, 67), (x + 0.6, 74.4)], 1.2, col="dark", smooth=False)
    return a


@draws("owl")
def owl():
    a = Art()
    # from the front, sitting upright on a branch
    figure(a, [limb([(8, 83), (50, 80), (92, 84)], 5, 3.6)], "bark", close=0, lw=0.9)
    body = blob([(50, 20), (66, 24), (72, 40), (70, 62), (62, 78), (50, 82), (38, 78), (30, 62), (28, 40), (34, 24)], 8)
    sil = figure(a, [body], "tan", [(ell(50, 62, 14, 20), "buff")], close=0)
    for s in (1, -1):
        figure(a, [blob([(50 + s * 14, 44), (50 + s * 21.5, 50), (50 + s * 21, 66), (50 + s * 15, 77), (50 + s * 12.6, 60)], 8)], "brown", close=0, lw=0.9)
    for i, (x, y) in enumerate([(44, 52), (50, 54), (56, 52), (41, 60), (47, 62), (53, 62), (59, 60), (44, 69), (50, 71), (56, 69)]):
        stroke(a, [(x, y), (x, y + 3.4)], 0.9, 0.7, col="brown", smooth=False)
    for s in (1, -1):
        figure(a, [ell(50 + s * 8.4, 35, 9.4, 10)], "buff", close=0, lw=0.9)                   # the two dishes of its face
        a.dot(50 + s * 7.4, 35, 3.6, "ink"); a.dot(50 + s * 6.4, 33.8, 1.0, "white")
        for dx in (-4, 0, 4):
            stroke(a, [(50 + s * 9 + dx - 1.6, 83.4), (50 + s * 9 + dx, 79.4)], 1.3, col="amber", smooth=False)
    paint(a, poly((47.8, 38.5), (52.2, 38.5), (50, 45)), "amber", 0.8)
    return a


@draws("raptor")
def raptor():
    a = Art()
    bird(a, bx=47, by=50, bl=21, bd=11.5, tilt=-66, hr=7.6, hdx=-1.5, hdy=1.5, bill=(5.6, 4.6, "hook", "slate"), tail=(22, 8, "square"), tail_ang=104, tail_col="tan",
         back="brown", belly="buff", wing="brown", streaks="rust", legs=(8, "yellow"), leg_at=(1, 6), eye_r=1.4,
         extra=[(ell(64.4, 22.6, 1.9, 1.6), "yellow")])
    return a


@draws("gamebird")
def gamebird():
    a = Art()
    bird(a, bx=52, by=56, bl=20, bd=12, tilt=-8, hr=6.4, hdx=2, hdy=-8, neck=[(70, 46)], bill=(4.4, 3, "cone", "buff"), tail=(36, 6.5, "point"), tail_ang=186,
         tail_col="tan", back="rust", belly="rust", cap="marrow", face="red", collar="white", wing="tan", legs=(12, "slate"), feet="stand", leg_at=(-2, 6), eye_r=1.0,
         extra=[(ell(72, 38, 6, 6), "marrow")])
    return a


@draws("duck")
def duck():
    a = Art()
    bird(a, bx=46, by=58, bl=25, bd=11.5, tilt=-3, hr=7.4, hdx=4, hdy=-9, neck=[(70, 46)], bill=(9, 3.6, "duck", "yellow"), tail=(8, 7, "fan"), tail_ang=200,
         tail_col="white", back="grey", belly="grey", breast="bark", collar="white", rump="black", wing="grey", wingbars=[(0.2, 0.42, "steel")], feet="swim", eye_r=1.1,
         extra=[(ell(75.5, 37, 9, 8.6), "marrow")])
    return a


@draws("coot")
def coot():
    a = Art()
    sil, (hx, hy), t = bird(a, bx=46, by=58, bl=23, bd=12.5, tilt=-5, hr=7.4, hdx=3, hdy=-6, neck=[(68, 48)], bill=(6, 3.4, "cone", "white"), tail=(6, 8, "fan"), tail_ang=196,
                            back="black", belly="black", wing="black", feet="swim", eye_r=1.0)
    paint(a, blob([(hx + 4.4, hy - 5), (hx + 7.6, hy - 2.4), (hx + 7, hy + 1), (hx + 4, hy + 0.4)], 6), "white", 0.8)   # the white shield above its bill
    a.dot(hx + 2.8, hy - 1.4, 1.2, "red")
    return a


@draws("heron")
def heron():
    a = Art()
    stroke(a, [(45, 56), (44, 90)], 1.4, col="olive", smooth=False)
    stroke(a, [(50, 56), (52, 90)], 1.4, col="olive", smooth=False)
    for x in (44, 52):
        stroke(a, [(x - 4, 90.6), (x, 90), (x + 5, 90.8)], 1.2, col="olive", smooth=False)
    sil, (hx, hy), t = bird(a, bx=44, by=46, bl=17, bd=9.5, tilt=-28, hr=5.6, hdx=3, hdy=-17, neck=[(62, 34), (56, 24)], bill=(17, 3.4, "dagger", "yellow"),
                            tail=(9, 6, "square"), tail_col="grey", back="grey", belly="white", wing="grey", wingbars=[(-0.8, -0.56, "black")], feet="none", eye_r=1.0, eyeline=True)
    stroke(a, [(hx - 3, hy - 1.4), (hx - 10, hy + 1), (hx - 15, hy + 5)], 1.2, col="ink")       # the plume at the back of its head
    stroke(a, [(18, 91.6), (78, 91.6)], 0.8, 0.5, col="slate", smooth=False)
    return a


@draws("wader")
def wader():
    a = Art()
    bird(a, bx=44, by=48, bl=19, bd=10.5, tilt=-10, hr=6.6, hdx=1, hdy=-3, bill=(17, 2.4, "dagger", "orange"), tail=(9, 6, "square"), back="tan", belly="white",
         wing="brown", streaks="brown", legs=(22, "orange"), feet="stand", leg_at=(-1, 5), eye_r=1.1)
    return a


@draws("seabird")
def seabird():
    a = Art()
    bird(a, bx=44, by=50, bl=23, bd=12, tilt=-12, hr=8, hdx=0, hdy=-1, bill=(10, 4.2, "hook", "yellow"), tail=(11, 7, "square"), tail_col="white", back="white", belly="white",
         wing="grey", wing_len=1.3, legs=(15, "pink"), feet="stand", leg_at=(-1, 6), eye_r=1.1,
         extra=[(ell(13, 49, 8, 4, -14), "black")])
    a.dot(72.5, 37.4, 0.9, "red")
    return a


@draws("bird")
def other_bird():
    a = Art()
    bird(a, bl=18, bd=11.5, tilt=-18, hr=7.8, bill=(6.5, 2.4, "fine", "dark"), tail=(20, 5.6, "square"), back="tan", belly="cream", wing="bark",
         wingbars=[(-0.2, -0.08, "cream")], eyebrow="cream", streaks="brown", legs=(11, "skin"))
    return a


# =====================================================================
# MAMMALS
# =====================================================================

@draws("hedgehog")
def hedgehog():
    a = Art()
    for x in (38, 62):
        figure(a, [limb([(x, 68), (x + 1, 75)], 5, 4.4)], "tan", close=0, lw=0.9)
    dome = []
    for k in range(0, 41):
        th = math.pi * (1 + k / 40)
        r = 1.0 + (0.07 if k % 2 else 0)
        dome.append((46 + 29 * r * math.cos(th), 68 + 27 * r * math.sin(th)))
    spines = Polygon(dome + [(75, 68), (60, 73), (30, 73), (17, 68)]).buffer(0)
    face = blob([(64, 52), (76, 56), (88, 66), (89.5, 69.5), (84, 72.5), (70, 73), (62, 70)], 8)
    figure(a, [face], "tan", close=0)
    sil = figure(a, [spines], "bark", close=0)
    for i in range(34):
        x = 23 + (i * 37) % 47; y = 47 + (i * 23) % 22
        if sil.contains(Polygon([(x, y), (x + 2.6, y - 3.4), (x + 0.4, y + 0.4)])):
            stroke(a, [(x, y), (x + 2.4, y - 3.2)], 0.7, 0.7, col="cream" if i % 3 else "brown", smooth=False)
    figure(a, [ell(69, 57.5, 3.4, 3.8)], "tan", close=0, lw=0.9)
    eye(a, 77.4, 62, 1.4)
    a.dot(89.4, 69, 1.7, "ink")
    stroke(a, [(10, 77.4), (92, 77.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("small-mammal")
def small_mammal():
    a = Art()
    figure(a, [limb([(27, 63), (13, 68), (8, 56), (15, 45), (25, 41)], 3.2, 1.4)], "skin", close=0, lw=0.9)   # the long tail
    for x in (40, 60):
        figure(a, [limb([(x, 68), (x + 2, 74), (x + 6, 75)], 4, 3)], "skin", close=0, lw=0.8)
    body = ell(44, 60, 21, 12.5, 4)
    head = blob([(58, 50), (70, 49), (82, 57), (89, 63.6), (84, 68), (70, 70), (60, 68)], 8)
    figure(a, [ell(66.5, 46.6, 6.4, 7)], "tan", [(ell(67, 47, 4, 4.6), "skin")], close=0)
    sil = figure(a, [body, head], "tan", [(ell(50, 71, 30, 6.4), "cream")], close=2.4)
    eye(a, 76.6, 57.6, 1.7)
    a.dot(89, 63.8, 1.4, "skin")
    for dy in (-3.4, 0, 3.4):
        stroke(a, [(85, 64), (95, 62 + dy * 1.4)], 0.4, 0.5, smooth=False)
    stroke(a, [(10, 76.6), (92, 76.6)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("squirrel")
def squirrel():
    a = Art()
    tail = limb([(38, 76), (22, 70), (16, 50), (24, 30), (40, 19), (51, 27)], 11, 17)
    figure(a, [tail], "grey", close=0)
    for x, y, dx, dy in [(22, 62, -3, -3), (20, 50, -3, -2.4), (24, 38, -2.6, -3), (32, 27, -1, -3.6), (42, 24, 2, -3.4), (29, 68, -2, 3), (27, 46, 3, -2), (36, 33, 3, 0.6)]:
        stroke(a, [(x, y), (x + dx, y + dy)], 0.7, 0.6, col="white", smooth=False)
    body = blob([(46, 48), (58, 44), (66, 54), (66, 70), (58, 80), (42, 80), (38, 66)], 8)
    head = blob([(54, 32), (64, 28), (74, 33), (79, 40.6), (72, 46), (60, 46)], 8)
    for x, y in [(61, 25), (67, 26)]:
        figure(a, [blob([(x - 2.6, y + 5), (x, y - 4), (x + 2.8, y + 5)], 6)], "grey", close=0, lw=0.9)
    sil = figure(a, [body, head, limb([(46, 72), (60, 79), (68, 80)], 7, 5)], "grey", [(ell(62, 62, 6.4, 15), "white"), (ell(72, 44, 6, 3), "white")], close=2.2)
    figure(a, [limb([(56, 54), (66, 58), (71, 54)], 4, 3)], "grey", close=0, lw=0.9)           # an arm, holding a nut
    figure(a, [ell(73.4, 51.6, 3, 3.6, 20)], "bark", close=0, lw=0.8)
    eye(a, 69.4, 35.6, 1.7)
    a.dot(79, 40.6, 1.2, "ink")
    stroke(a, [(18, 81.4), (88, 81.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("rabbit")
def rabbit():
    a = Art()
    for x, y, ang in [(63, 22, -8), (69.5, 23, 12)]:
        figure(a, [ell(x, y, 3.4, 12.5, ang)], "tan", [(ell(x + 0.4, y + 1, 1.5, 9, ang), "skin")], close=0)
    figure(a, [ell(22, 66, 5.4, 5.2)], "white", close=0)
    body = blob([(26, 62), (36, 48), (52, 46), (64, 56), (66, 70), (58, 78), (34, 78), (26, 72)], 8)
    head = blob([(58, 38), (68, 33), (78, 38), (82, 46), (76, 52), (64, 52)], 8)
    sil = figure(a, [body, head, limb([(34, 76), (48, 79), (56, 79)], 6, 5), limb([(60, 64), (63, 76), (68, 79)], 5, 4)], "tan", [(ell(62, 70, 5, 9), "cream")], close=2.4)
    stroke(a, [(38, 64), (46, 58), (54, 64), (52, 74)], 0.7, 0.5)
    eye(a, 72.6, 41, 1.8)
    a.dot(82, 45.4, 1.3, "skin")
    for dy in (-2.4, 1, 4):
        stroke(a, [(79.6, 47.6), (89, 46 + dy)], 0.4, 0.5, smooth=False)
    stroke(a, [(12, 80.6), (88, 80.6)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("bat")
def bat():
    a = Art()
    for s in (1, -1):
        m = (lambda x: 50 + s * (x - 50))
        wing = Polygon([(m(53), 40), (m(64), 30), (m(80), 27), (m(95), 36)] + curve([(m(95), 36), (m(88), 44), (m(86), 54)], 6) + curve([(m(86), 54), (m(78), 50), (m(72), 60)], 6)
                       + curve([(m(72), 60), (m(64), 56), (m(58), 68)], 6) + [(m(52.5), 60)]).buffer(0)
        figure(a, [wing], "bark", close=0)
        for ex, ey_ in [(95, 36), (86, 54), (72, 60)]:
            stroke(a, [(m(64), 30), (m(ex), ey_)], 0.6, 0.6, smooth=False)                     # its fingers
        stroke(a, [(m(53), 41), (m(64), 30)], 1.2, smooth=False)
    for s in (1, -1):
        figure(a, [blob([(50 + s * 2, 33), (50 + s * 6.5, 22), (50 + s * 7.4, 33)], 6)], "brown", [(blob([(50 + s * 3.4, 32), (50 + s * 6, 25.6), (50 + s * 6.4, 32)], 6), "skin")], close=0, lw=0.9)
    body = Polygon([(50 + 6.6 * (1 + 0.05 * math.cos(20 * t)) * math.cos(t), 50 + 13 * (1 + 0.05 * math.cos(20 * t)) * math.sin(t)) for t in [2 * math.pi * k / 120 for k in range(120)]])
    figure(a, [body], "brown", close=0)
    figure(a, [ell(50, 35.6, 5.4, 5)], "brown", close=0)
    for s in (1, -1):
        eye(a, 50 + s * 2.2, 35, 0.9, False)
        stroke(a, [(50 + s * 2, 62), (50 + s * 3, 68)], 1.0, smooth=False)
    a.dot(50, 38.4, 0.9, "skin")
    return a


def four_legs(a, xs, top, foot, w, colour, sock=None, far=False, hoof=None):
    """Two of an animal's legs seen from the side, with their joints. The one
    further back is a HIND leg: a broad thigh, then a hock that points
    backwards. The other is a FRONT leg: straight, with a knee halfway. Each
    ends in a paw, or a hoof if a hoof colour is given. A leg too short to
    show its joints (a badger's) is a stump with a paw.
      sock   a colour for the lower leg (a fox's black legs)
      far    the pair on the animal's far side, drawn flat without shading"""
    L = foot - top
    for i, x in enumerate(sorted(xs)):
        paw = ell(x + w * 0.4, foot - w * 0.28, w * 0.8, w * 0.36)
        if L < w * 3.4:
            g = [limb([(x, top), (x + 0.6, (top + foot) / 2), (x + 0.2, foot - w * 0.2)], w, w * 0.8), paw]
        elif i == 0:
            hock = (x - w * 0.75, top + L * 0.64)
            g = [limb([(x - w * 0.2, top), (x + w * 0.55, top + L * 0.36), hock], w * 1.7, w * 0.78), limb([hock, (x - w * 0.3, foot - w * 0.3)], w * 0.78, w * 0.66),
                 ell(x + w * 0.2, foot - w * 0.28, w * 0.8, w * 0.36)]
        else:
            knee = (x + w * 0.2, top + L * 0.5)
            g = [limb([(x, top), knee], w * 1.25, w * 0.8), limb([knee, (x - w * 0.05, foot - w * 0.3)], w * 0.8, w * 0.66), paw]
        patches = []
        if sock:
            patches.append((band(x, foot, 12, L, -0.42, 0.3), sock))
        if hoof:
            patches.append((band(x, foot, 12, L, -0.09, 0.3), hoof))
        figure(a, g, colour, patches, close=0.4, lw=0.9, shade=not far)


@draws("fox")
def fox():
    a = Art()
    four_legs(a, [34, 62], 56, 79, 4.4, "rust", far=True)
    tail = limb([(26, 52), (14, 56), (7, 66), (6, 74)], 7, 11)
    figure(a, [tail], "orange", [(ell(6.4, 75.6, 7, 7), "white")], close=0)
    body = ell(46, 51, 22, 9.5, -2)
    neck = limb([(62, 48), (70, 40)], 11, 9)
    head = blob([(66, 30), (75, 30), (82, 37), (92, 42.6), (84, 46), (72, 46), (65, 40)], 8)
    for x in (68, 74.5):
        figure(a, [poly((x - 3.4, 32), (x + 0.4, 19.5), (x + 3.6, 32))], "orange", [(poly((x - 1.4, 31), (x + 0.4, 24.5), (x + 1.8, 31)), "black")], close=0, lw=0.9)
    sil = figure(a, [body, neck, head], "orange", [(blob([(60, 46), (70, 44), (84, 43.6), (90, 44), (84, 47), (70, 50), (66, 60), (58, 60)], 8), "white")], close=2.2)
    four_legs(a, [38, 66], 56, 80, 4.6, "orange", "black")
    eye(a, 77.4, 36.6, 1.4)
    a.dot(92, 42.8, 1.5, "ink")
    stroke(a, [(10, 82.4), (90, 82.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("badger")
def badger():
    a = Art()
    four_legs(a, [32, 60], 60, 78, 6, "black", far=True)
    body = blob([(14, 62), (22, 48), (44, 42), (62, 46), (70, 56), (68, 68), (40, 71), (18, 70)], 8)
    head = blob([(62, 50), (72, 50), (84, 60), (92, 66), (88, 70.6), (74, 71), (64, 66)], 8)
    figure(a, [limb([(16, 62), (9, 66)], 6, 4)], "grey", close=0)
    figure(a, [ell(69, 50, 3.6, 3.6)], "black", [(ell(69, 49, 2.4, 1.6), "white")], close=0, lw=0.9)
    sil = figure(a, [body], "grey", [(ell(42, 70, 28, 5), "black")], close=0)
    hsil = figure(a, [head], "white", [(limb([(66, 51), (76, 59), (89, 66)], 4.4, 2.4), "black"), (limb([(64, 64), (74, 70), (84, 71.4)], 5, 3), "black")], close=0)
    four_legs(a, [36, 64], 60, 79, 6.4, "black")
    eye(a, 78.4, 60.6, 1.1, False)
    a.dot(77.9, 60.2, 0.4, "white")
    a.dot(91.6, 66.6, 1.6, "ink")
    for i in range(12):
        x = 22 + (i * 17) % 42; y = 49 + (i * 7) % 14
        stroke(a, [(x, y), (x - 2.4, y + 1.6)], 0.5, 0.5, col="white", smooth=False)
    stroke(a, [(8, 81.4), (92, 81.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("deer")
def deer():
    a = Art()
    four_legs(a, [35, 61], 52, 86, 3.8, "bark", far=True)
    body = ell(46, 47, 21, 10, -3)
    neck = limb([(60, 44), (67, 32), (70, 24)], 10, 6)
    head = blob([(66, 17), (72, 16), (78, 21), (85, 25.6), (80, 29), (70, 28), (66, 24)], 8)
    for x, ang in [(66.4, -28), (70.4, 6)]:
        figure(a, [ell(x - 1.6, 13, 2.2, 5, ang - 20)], "tan", close=0, lw=0.9)
    for s, x in ((0, 68), (1, 71)):                                                            # short antlers
        stroke(a, [(x, 16), (x - 1, 7), (x - 3, 2)], 1.3, col="bark")
        stroke(a, [(x - 0.8, 9), (x + 2.6, 5)], 1.2, col="bark", smooth=False)
    sil = figure(a, [body, neck, head, ell(26, 45, 4, 3.6)], "tan", [(ell(27, 47, 5, 6.6), "white"), (ell(46, 57, 20, 4), "buff")], close=2.2)
    four_legs(a, [39, 65], 52, 87, 4.2, "tan")
    eye(a, 74.4, 21, 1.3)
    a.dot(85, 25.8, 1.4, "ink")
    stroke(a, [(12, 89.4), (88, 89.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("seal")
def seal():
    a = Art()
    body = blob([(10, 66), (22, 56), (44, 52), (60, 50), (68, 40), (74, 31), (84, 30), (89, 38), (84, 46), (78, 56), (72, 70), (50, 74), (26, 73)], 8)
    figure(a, [blob([(12, 64), (4, 56), (7, 68), (3, 76), (14, 71)], 6)], "slate", close=0)   # tail flippers
    sil = figure(a, [body], "grey", [(blob([(30, 73), (50, 70), (70, 62), (80, 46), (86, 42), (84, 50), (74, 72), (50, 76)], 8), "cream")], close=0)
    spots(a, sil, [(30, 61), (38, 57), (46, 62), (54, 56), (40, 66), (62, 54), (24, 66), (58, 64), (68, 46)], 1.5, "slate")
    figure(a, [blob([(58, 66), (66, 72), (64, 81), (56, 78), (54, 70)], 6)], "slate", close=0, lw=0.9)
    eye(a, 81, 35.6, 1.6)
    a.dot(88.6, 38.6, 1.3, "ink")
    for dy in (-1.6, 1, 3.6):
        stroke(a, [(86, 40.6), (94, 41 + dy * 1.2)], 0.4, 0.5, smooth=False)
    stroke(a, [(4, 80.4), (94, 80.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


@draws("whale")
def whale():
    a = Art()
    body = blob([(10, 44), (24, 50), (44, 46), (62, 40), (78, 42), (88, 50), (94, 54.6), (86, 57), (74, 62), (54, 64), (36, 60), (22, 54)], 8)
    flukes = blob([(14, 47), (5, 36), (3, 44), (8, 50), (4, 60), (11, 56), (17, 51)], 6)
    fin = blob([(50, 44), (54, 28), (62, 41)], 6)
    figure(a, [blob([(64, 60), (60, 72), (70, 64)], 6)], "slate", close=0, lw=0.9)
    sil = figure(a, [body, flukes, fin], "slate", [(blob([(30, 58), (54, 60), (76, 55), (93, 54.6), (86, 58), (74, 63), (54, 66), (36, 62)], 8), "cream")], close=1.4)
    stroke(a, [(84, 53.4), (93, 54.4)], 0.6, 0.6, smooth=False)
    eye(a, 80, 50, 1.3)
    stroke(a, [(4, 78), (20, 76), (36, 78.6), (52, 76), (68, 78.6), (84, 76), (96, 78)], 0.9, 0.7, col="slate")
    return a


# =====================================================================
# AMPHIBIANS AND REPTILES
# =====================================================================

@draws("frog")
def frog():
    a = Art()
    body = blob([(22, 66), (30, 50), (46, 42), (62, 40), (76, 44), (86, 52), (84, 60), (70, 66), (54, 72), (34, 73)], 8)
    back_leg = blob([(24, 64), (34, 52), (46, 54), (50, 64), (44, 74), (30, 76)], 8)
    figure(a, [limb([(66, 62), (68, 74), (76, 77)], 4.4, 3.2)], "olive", close=0, lw=0.9)
    sil = figure(a, [body, ell(70, 40.6, 5.2, 4.6)], "olive", [(blob([(52, 70), (70, 62), (86, 54), (84, 61), (70, 67), (54, 73)], 8), "cream")], close=1.2)
    paint(a, blob([(60, 46), (68, 44.6), (72, 49), (64, 51)], 6).intersection(sil), "brown")    # the dark patch behind the eye
    spots(a, sil, [(36, 54), (44, 48), (52, 52), (42, 58)], 1.6, "deep")
    figure(a, [back_leg], "olive", close=0, lw=0.9)
    stroke(a, [(30, 76), (44, 78), (56, 76.6)], 2.6, col="olive")
    stroke(a, [(30, 76), (44, 78), (56, 76.6)], 0.01, col="line")
    stroke(a, [(36, 64), (42, 60), (46, 66)], 0.6, 0.5)
    a.dot(70.4, 41, 2.8, "amber"); a.dot(70.8, 41, 1.5, "ink")
    stroke(a, [(77, 53.4), (86, 53)], 0.6, 0.6, smooth=False)
    stroke(a, [(12, 79.4), (90, 79.4)], 0.8, 0.5, col="soil", smooth=False)
    return a


def four_feet(a, places, colour, L=11, lw=2.2, toes=True):
    """Splayed legs for an animal seen from above: (x, y, angle of the leg)."""
    for x, y, ang in places:
        t = turn(x, y, ang)
        knee = t(L * 0.55, -1.5 if ang > 0 else 1.5); foot = t(L)
        stroke(a, [(x, y), knee, foot], lw + 1.5, smooth=False)
        stroke(a, [(x, y), knee, foot], lw, col=colour, smooth=False, la=1)
        if toes:
            for d in (-34, 0, 34):
                stroke(a, [foot, turn(foot[0], foot[1], ang + d)(3.2)], 0.8, smooth=False)


@draws("newt")
def newt():
    a = Art()
    line = [(84, 24), (70, 30), (58, 42), (52, 56), (40, 66), (26, 68), (14, 78)]
    four_feet(a, [(66, 33, -40), (70, 36, 62), (50, 58, 142), (55, 60, 40)], "olive", 10)
    tail = limb([(52, 56), (40, 66), (26, 68), (14, 78)], 9, 1.6)
    figure(a, [limb(line[:4], 8.6, 9.6), tail, ell(85, 23.4, 6.2, 5, -22)], "olive", [(limb(line, 2.4, 1.0), "orange")], close=1.4)
    spots(a, limb(line, 9, 3), [(74, 26.5), (66, 35), (60, 37), (56, 47), (50, 52), (44, 61), (36, 68.4), (28, 66)], 1.25, "deep")
    eye(a, 87.6, 19.8, 1.0, False); eye(a, 89.4, 25, 1.0, False)
    return a


@draws("lizard")
def lizard():
    a = Art()
    line = [(84, 22), (72, 30), (62, 44), (58, 56), (46, 64), (30, 62), (18, 70), (10, 84)]
    four_feet(a, [(70, 31, -46), (73, 34, 56), (55, 57, 150), (60, 59, 46)], "tan", 12, 1.8)
    figure(a, [limb(line[:4], 7, 8), limb(line[3:], 7.4, 0.8), blob([(79, 24), (84, 16.5), (91, 14.6), (93, 20), (88, 26.6), (82, 28)], 6)], "tan",
           [(limb(line, 2.6, 0.6), "brown")], close=1.2)
    c = curve(line, 10)
    for i in range(8, len(c) - 14, 4):
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)) + 90)
        for d in (-2.5, 2.5):
            a.dot(*t(d), 0.55, "cream")
    eye(a, 87, 17.4, 0.9, False); eye(a, 90.6, 21.6, 0.9, False)
    return a


@draws("snake")
def snake():
    a = Art()
    line = [(78, 22), (64, 24), (46, 22), (30, 30), (26, 46), (40, 54), (60, 52), (74, 60), (74, 74), (58, 82), (38, 80), (22, 86)]
    figure(a, [limb(line, 7.4, 2.4), blob([(74, 18), (82, 15), (91, 18), (93, 22.6), (88, 26.4), (78, 26)], 6)], "tan", close=1.0)
    c = curve(line, 12)
    zig = []
    for i in range(4, len(c) - 6, 3):
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)) + 90)
        w = 2.2 * (1 - 0.6 * i / len(c))
        zig.append(t(w if (i // 3) % 2 else -w))
    stroke(a, zig, 1.9, 0.95, col="ink", smooth=False)
    stroke(a, [(80, 18.4), (84, 21), (80, 24)], 1.1, 0.9, col="ink", smooth=False)
    eye(a, 87.4, 19.4, 0.9, False)
    stroke(a, [(93, 22.6), (97, 22), (99, 20.4)], 0.5, smooth=False)
    stroke(a, [(97, 22), (99, 23.6)], 0.5, smooth=False)
    return a


# =====================================================================
# FISH, AND THE SEA AND SHORE
# =====================================================================

@draws("fish")
def fish():
    a = Art()
    body = blob([(16, 52), (30, 42), (50, 37), (70, 40), (84, 48), (89, 53), (84, 58), (70, 64), (50, 66), (30, 61)], 8)
    tail = blob([(18, 52), (6, 38), (4, 46), (9, 52), (4, 60), (6, 67)], 6)
    for g in (blob([(42, 39), (48, 27), (60, 30), (64, 39)], 6), blob([(40, 64), (44, 74), (52, 66)], 6), blob([(56, 65), (62, 74), (68, 64)], 6)):
        figure(a, [g], "orange", close=0, lw=0.9)
    figure(a, [tail], "orange", close=0)
    sil = figure(a, [body], "grey", [(blob([(16, 52), (30, 42), (50, 37), (70, 40), (84, 48), (60, 46), (36, 49)], 8), "olive"), (blob([(30, 60), (50, 62), (72, 60), (84, 57), (70, 64), (50, 66)], 8), "white")], close=0)
    for i in range(4):
        for j in range(3):
            x = 34 + i * 8 + j * 3; y = 48 + j * 5
            stroke(a, [(x, y - 2), (x + 1.6, y), (x, y + 2)], 0.45, 0.4)
    stroke(a, [(72, 42.6), (69, 52), (72, 62)], 0.8, 0.6)
    figure(a, [blob([(64, 54), (56, 58), (58, 62), (66, 58)], 6)], "orange", close=0, lw=0.8)
    eye(a, 79, 49.6, 1.9)
    stroke(a, [(86, 55), (89, 54)], 0.6, 0.6, smooth=False)
    return a


@draws("crab")
def crab():
    a = Art()
    cx = 50
    for s in (1, -1):
        for b, k, e in [((14, 52), (30, 50), (41, 60)), ((14, 57), (29, 62), (36, 76)), ((12, 62), (23, 73), (26, 87)), ((8, 65), (14, 80), (12, 91))]:
            pts = [(cx + s * b[0], b[1]), (cx + s * k[0], k[1]), (cx + s * e[0], e[1])]
            stroke(a, pts, 3.6, smooth=False)
            stroke(a, pts, 2.2, col="deep", smooth=False, la=1)
        arm = limb([(cx + s * 14, 44), (cx + s * 28, 38), (cx + s * 30, 26)], 5.6, 5)
        claw = blob([(cx + s * 26, 28), (cx + s * 33, 21), (cx + s * 31, 10), (cx + s * 25, 14), (cx + s * 23, 21)], 6)
        figure(a, [arm, claw], "deep", close=0.8)
        stroke(a, [(cx + s * 29.6, 24), (cx + s * 27, 13)], 0.7, 0.7, smooth=False)
    shell = blob([(cx, 36), (cx + 13, 36.6), (cx + 23, 44), (cx + 20, 58), (cx + 10, 67), (cx, 68.6), (cx - 10, 67), (cx - 20, 58), (cx - 23, 44), (cx - 13, 36.6)], 8)
    sil = figure(a, [shell], "deep", [(shell.difference(shell.buffer(-2)), "olive")], close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 5, 37), (cx + s * 6, 31.6)], 1.2, smooth=False)
        a.dot(cx + s * 6, 31, 1.5, "ink")
        stroke(a, [(cx + s * 4, 47), (cx + s * 10, 50), (cx + s * 8, 58)], 0.6, 0.45)
    stroke(a, [(cx - 5, 60), (cx, 62), (cx + 5, 60)], 0.6, 0.45)
    return a


@draws("sea-snail")
def sea_snail():
    a = Art()
    # a whelk-like shell: whorls stepping up to a point, the opening at the bottom
    shell = blob([(50, 8), (56, 18), (63, 28), (72, 42), (78, 58), (72, 76), (60, 88), (48, 91), (40, 84), (32, 66), (30, 50), (36, 34), (44, 20)], 8)
    sil = figure(a, [shell], "buff", [(blob([(52, 54), (66, 56), (70, 70), (62, 84), (50, 88), (46, 74)], 8), "skin")], close=0)
    for y0, y1, x0, x1 in [(20, 23, 44, 56), (30, 35, 38.5, 64), (43, 51, 32.5, 72.6)]:
        stroke(a, [(x0, y0 + 1), ((x0 + x1) / 2, y1 + 2), (x1, y0)], 0.9, 0.7)
    for i, (y, x0, x1) in enumerate([(26, 42, 59), (38, 36, 67), (58, 31, 50), (66, 32.6, 47), (74, 35.6, 46)]):
        stroke(a, [(x0, y), ((x0 + x1) / 2, y + 2.4), (x1, y - 0.6)], 0.5, 0.4, col="brown")
    paint(a, blob([(52, 54), (66, 56), (70, 70), (62, 84), (50, 88), (46, 74)], 8), None, 0.9)
    return a


@draws("sea-slug")
def sea_slug():
    a = Art()
    line = [(14, 62), (30, 54), (50, 52), (70, 56), (86, 64)]
    c = curve(line, 10)
    for i in range(4, len(c) - 6, 3):                                                          # the fingers along its back
        x, y = c[i]
        for dx, L in ((-1.4, 15), (1.6, 12)):
            tip = (x + dx * 2.4 - 3, y - L)
            stroke(a, [(x + dx, y - 2), (x + dx * 1.6 - 1.4, y - L * 0.6), tip], 2.8)
            stroke(a, [(x + dx, y - 2), (x + dx * 1.6 - 1.4, y - L * 0.6), tip], 1.7, col="white", la=1)
            a.dot(tip[0], tip[1], 1.5, "orange")
    figure(a, [limb(line, 9, 12), limb([(86, 64), (92, 69)], 8, 3)], "white", [(limb([(14, 66), (30, 58.6), (50, 57), (70, 61), (88, 69)], 4, 5), "blue")], close=1.0)
    for bx, by, ex, ey_ in [(80, 59, 85, 44), (84.6, 61, 92, 48), (88, 68, 97, 66), (87, 70, 95, 75)]:
        stroke(a, [(bx, by), (ex, ey_)], 2.6, smooth=False)
        stroke(a, [(bx, by), (ex, ey_)], 1.5, col="white", smooth=False, la=1)
    return a


@draws("bivalve")
def bivalve():
    a = Art()
    # a cockle or scallop: one fan-shaped shell with ribs
    pts = []
    for k in range(0, 41):
        th = math.radians(200 + k * 3.5)
        r = 32 * (1 + 0.035 * math.cos(k * math.pi))
        pts.append((50 + r * math.cos(th) * 1.08, 62 + r * math.sin(th) * -1.0 * -1))
    fan = Polygon([(41, 30), (59, 30)] + [(50 + 34 * math.cos(math.radians(aa)) * (1 + 0.03 * math.cos(math.radians(aa) * 15)), 38 + 46 * abs(math.sin(math.radians(aa))) * (1 + 0.03 * math.cos(math.radians(aa) * 15)))
                                           for aa in range(0, 181, 3)]).buffer(0)
    figure(a, [poly((36, 24), (64, 24), (61, 34), (39, 34))], "tan", close=0)
    sil = figure(a, [fan], "buff", [(fan.difference(fan.buffer(-3)), "pink"), (band(50, 60, 40, 24, -0.2, -0.06), "pink"), (band(50, 60, 40, 24, 0.3, 0.42), "pink")], close=0)
    for aa in range(12, 180, 12):
        r = math.radians(aa)
        stroke(a, [(50 + 5 * math.cos(r), 33 + 3 * math.sin(r)), (50 + 32.5 * math.cos(r), 38 + 44.4 * math.sin(r))], 0.6, 0.5, smooth=False)
    return a


@draws("cephalopod")
def cephalopod():
    a = Art()
    cx = 50
    arms = [[(40, 50), (22, 56), (12, 70), (20, 80)], [(43, 54), (30, 66), (30, 82), (40, 86)], [(47, 56), (44, 70), (50, 84), (46, 92)], [(53, 56), (58, 70), (54, 84), (62, 90)],
            [(57, 54), (70, 64), (72, 80), (64, 82)], [(60, 50), (78, 54), (88, 68), (82, 78)], [(38, 46), (22, 44), (10, 52), (8, 62)], [(62, 46), (78, 42), (90, 50), (93, 60)]]
    for arm in arms:
        figure(a, [limb(arm, 6.6, 1.6)], "orange", close=0)
        c = curve(arm, 6)
        for i in range(4, len(c) - 2, 3):
            a.dot(c[i][0], c[i][1] + 0.6, 0.55, "cream")
    head = blob([(cx, 10), (cx + 14, 16), (cx + 17, 32), (cx + 13, 46), (cx + 8, 54), (cx - 8, 54), (cx - 13, 46), (cx - 17, 32), (cx - 14, 16)], 8)
    sil = figure(a, [head], "orange", close=0)
    spots(a, sil, [(42, 20), (56, 18), (50, 28), (60, 30), (40, 32)], 1.7, "rust", 0.7)
    for s in (1, -1):
        a.dot(cx + s * 7.4, 44, 2.6, "cream"); paint(a, ell(cx + s * 7.4, 44, 2.2, 1.0), "ink")
    return a


@draws("starfish")
def starfish():
    a = Art()
    pts = []
    for k in range(180):
        th = 2 * math.pi * k / 180 - math.pi / 2
        r = 12 + 26 * abs(math.cos(2.5 * (th + math.pi / 2))) ** 2.4
        pts.append((50 + r * math.cos(th), 52 + r * math.sin(th)))
    star = Polygon(pts).buffer(1.6).buffer(-0.6)
    sil = figure(a, [star], "orange", close=0)
    for k in range(5):
        th = 2 * math.pi * k / 5 - math.pi / 2
        for r in (9, 15, 21, 27, 32):
            a.dot(50 + r * math.cos(th), 52 + r * math.sin(th), 0.95 - r * 0.012, "cream")
    a.dot(50, 52, 1.5, "cream")
    return a


@draws("anemone")
def anemone():
    a = Art()
    cx = 50
    for k in range(17):
        ang = -168 + k * 9.75
        t = turn(cx, 52, ang)
        L = 26 + (5 if k % 2 else 0)
        g = limb([t(8), t(L * 0.6, 2.4 * (1 if k % 2 else -1)), t(L)], 4.4, 1.8)
        figure(a, [g], "red" if k % 2 else "pink", close=0, lw=0.8, shade=False)
    column = blob([(cx - 15, 52), (cx - 16, 70), (cx - 21, 84), (cx + 21, 84), (cx + 16, 70), (cx + 15, 52), (cx, 46)], 8)
    sil = figure(a, [column], "red", [(band(cx, 84, 30, 6, -1, 1), "rust")], close=0)
    for x in (-9, -3, 3, 9):
        stroke(a, [(cx + x, 56), (cx + x * 1.2, 82)], 0.5, 0.35, smooth=False)
    for k in range(9):
        a.dot(cx - 12 + k * 3, 53.4 - 2 * math.sin(math.pi * k / 8), 1.0, "blue")
    stroke(a, [(14, 85.4), (86, 85.4)], 0.9, 0.6, col="slate", smooth=False)
    return a


@draws("jellyfish")
def jellyfish():
    a = Art()
    cx = 50
    for k in range(9):
        x = cx - 24 + k * 6
        stroke(a, [(x, 44), (x + 2 * math.sin(k), 58), (x - 2 * math.cos(k), 72), (x + 1.5 * math.sin(k * 2), 84 + (k % 3) * 3)], 0.7, 0.6, col="rust")
    for x, w in [(-9, 6), (0, 7), (9, 6)]:
        g = limb([(cx + x, 44), (cx + x * 1.3 + 2, 58), (cx + x * 1.2 - 2, 70), (cx + x * 1.5, 80)], w, 2.4)
        figure(a, [g], "cream", close=0, lw=0.8, fa=0.9)
    bell = blob([(cx - 30, 44), (cx - 27, 28), (cx - 14, 15), (cx, 12), (cx + 14, 15), (cx + 27, 28), (cx + 30, 44), (cx + 20, 47), (cx + 10, 44.6), (cx, 47), (cx - 10, 44.6), (cx - 20, 47)], 8)
    sil = figure(a, [bell], "cream", close=0)
    for k in range(8):                                                                         # the brown V marks of a compass jellyfish
        ang = -170 + k * 23
        t = turn(cx, 44, ang)
        tip = t(11); e1 = turn(cx, 44, ang - 7)(31); e2 = turn(cx, 44, ang + 7)(31)
        g = Polygon([tip, e1, turn(cx, 44, ang - 4)(31), turn(tip[0], tip[1], ang)(5), turn(cx, 44, ang + 4)(31), e2]).buffer(0)
        paint(a, g.intersection(sil), "rust", fa=0.85)
    paint(a, ell(cx, 14.5, 4.4, 2.4).intersection(sil), "rust", fa=0.85)
    paint(a, bell, None, LW)
    return a


@draws("sea-colony")
def sea_colony():
    a = Art()
    rock = blob([(8, 84), (14, 66), (30, 56), (52, 58), (72, 52), (88, 62), (93, 84)], 8)
    figure(a, [rock], "grey", close=0)
    sponge = blob([(14, 62), (18, 46), (30, 38), (42, 42), (48, 52), (46, 62), (30, 66)], 8)
    sil = figure(a, [sponge], "orange", close=0)
    for x, y in [(24, 48), (34, 46), (30, 56), (40, 54), (20, 57)]:
        paint(a, ell(x, y, 2, 1.7), "rust", 0.6)
    for x, y, s in [(62, 54, 1.0), (78, 58, 0.85), (68, 66, 0.7)]:                             # barnacles
        cone = poly((x - 9 * s, y + 6 * s), (x - 4 * s, y - 6 * s), (x + 4 * s, y - 6 * s), (x + 9 * s, y + 6 * s))
        figure(a, [cone], "cream", close=0.6)
        paint(a, ell(x, y - 5.4 * s, 3.4 * s, 1.6 * s), "slate", 0.7)
        for dx in (-5, -2, 2, 5):
            stroke(a, [(x + dx * 0.55 * s, y - 4.6 * s), (x + dx * 1.3 * s, y + 5.4 * s)], 0.5, 0.45, smooth=False)
    stroke(a, [(4, 85.4), (96, 85.4)], 0.9, 0.6, col="slate", smooth=False)
    return a


# =====================================================================
# Writing the pictures out
# =====================================================================

def sheet(mode, cell=150, cols=8):
    bg, card, ink, soft = [("#F8F1E5", "#FFFCF6", "#15271D", "#3A5549"), ("#0C1C14", "#142414", "#F1EADB", "#A7B5A5")][mode]
    pad, lab = 12, 34
    rows = math.ceil(len(KINDS) / cols)
    W = pad + cols * (cell + pad); H = pad + rows * (cell + lab + pad)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">', f'<rect width="{W}" height="{H}" fill="{bg}"/>']
    for i, (slug, name, group) in enumerate(KINDS):
        x = pad + (i % cols) * (cell + pad); y = pad + (i // cols) * (cell + lab + pad)
        out.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="14" fill="{card}"/>')
        if slug in DRAW:
            out.append(f'<g transform="translate({x},{y}) scale({cell / 100})" stroke-linecap="round" stroke-linejoin="round">{DRAW[slug]().body(mode)}</g>')
        short = name if len(name) <= 26 else name[:25] + "…"
        out.append(f'<text x="{x + cell / 2}" y="{y + cell + 15}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="11.5" fill="{ink}">{short.replace("&", "and")}</text>')
        out.append(f'<text x="{x + cell / 2}" y="{y + cell + 28}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="9.5" fill="{soft}">{slug}</text>')
    out.append("</svg>")
    return "\n".join(out)


def species_sheet(W, names, mode, cell=150, cols=8):
    bg, card, ink, soft = [("#F8F1E5", "#FFFCF6", "#15271D", "#3A5549"), ("#0C1C14", "#142414", "#F1EADB", "#A7B5A5")][mode]
    pad, lab = 12, 34
    rows = math.ceil(len(names) / cols)
    Wd = pad + cols * (cell + pad); H = pad + rows * (cell + lab + pad)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{Wd}" height="{H}" viewBox="0 0 {Wd} {H}">', f'<rect width="{Wd}" height="{H}" fill="{bg}"/>']
    for i, (label, sci) in enumerate(names):
        x = pad + (i % cols) * (cell + pad); y = pad + (i // cols) * (cell + lab + pad)
        out.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="14" fill="{card}"/>')
        out.append(f'<g transform="translate({x},{y}) scale({cell / 100})" stroke-linecap="round" stroke-linejoin="round">{W.SPECIES[sci]().body(mode)}</g>')
        short = label if len(label) <= 26 else label[:25] + "…"
        out.append(f'<text x="{x + cell / 2}" y="{y + cell + 15}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="11.5" fill="{ink}">{short.replace("&", "and")}</text>')
        out.append(f'<text x="{x + cell / 2}" y="{y + cell + 28}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-style="italic" font-size="9.5" fill="{soft}">{sci}</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    # This file is run as a program, but the species files import it by
    # name. Importing it by name here too means everyone shares one list.
    import wildlife as W
    import wildlife_species, wildlife_species2, wildlife_species3, wildlife_views
    out = sys.argv[1] if len(sys.argv) > 1 else "out_wildlife"
    missing = [slug for slug, _, _ in W.KINDS if slug not in W.DRAW]
    for mode, look in enumerate(("light", "dark")):
        os.makedirs(os.path.join(out, look), exist_ok=True)
        for old in os.listdir(os.path.join(out, look)):
            if old.startswith("wild-") and old.endswith(".svg"):
                os.remove(os.path.join(out, look, old))
        for slug, name, group in W.KINDS:
            if slug in W.DRAW:
                with open(os.path.join(out, look, f"wild-{slug}.svg"), "w", encoding="utf-8") as fh:
                    fh.write(W.DRAW[slug]().svg(mode))
        for sci, fn in W.SPECIES.items():
            with open(os.path.join(out, look, f"wild-sp-{W.slug_of(sci)}.svg"), "w", encoding="utf-8") as fh:
                fh.write(fn().svg(mode))
        for sci, views in W.VIEWS.items():      # an animal's other pictures: wild-sp-<animal>--<what it shows>
            for key, fn in views.items():
                with open(os.path.join(out, look, f"wild-sp-{W.slug_of(sci)}--{key}.svg"), "w", encoding="utf-8") as fh:
                    fh.write(fn().svg(mode))
        with open(os.path.join(out, f"sheet-{look}.svg"), "w", encoding="utf-8") as fh:
            fh.write(W.sheet(mode))
        if "sheets" in sys.argv[2:]:   # a large sheet of every single animal, for checking by eye: add the word "sheets" to ask for it
            names = [(sci, sci) for sci in W.SPECIES]
            with open(os.path.join(out, f"sheet-species-{look}.svg"), "w", encoding="utf-8") as fh:
                fh.write(species_sheet(W, names, mode))
    with open(os.path.join(out, "species-drawings.json"), "w", encoding="utf-8") as fh:
        lost = sorted(set(W.VIEWS) - set(W.SPECIES))
        assert not lost, f"these have other pictures but no first picture: {lost}"
        json.dump({"species": {sci: W.slug_of(sci) for sci in sorted(W.SPECIES)}, "kindsDrawnAs": getattr(W, "KIND_IS", {}),
                   "views": {sci: list(W.VIEWS[sci]) for sci in sorted(W.VIEWS)},
                   "mainShows": {sci: W.MAIN_SHOWS.get(sci, "adult") for sci in sorted(W.VIEWS)},
                   "viewNames": W.VIEW_NAMES, "genera": dict(sorted(W.GENUS_IS.items()))}, fh, indent=1, ensure_ascii=False)
    print(len(W.DRAW), "kinds and", len(W.SPECIES), "single animals drawn, with", sum(len(v) for v in W.VIEWS.values()), "other pictures of", len(W.VIEWS),
          "of them, each in light and dark, written to", out, "| kinds not drawn:", missing)
