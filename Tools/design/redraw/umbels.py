"""Windfall plant drawings, the redraw of 16 November 2026: the umbel group.

The thirteen kinds in this file: dill, fennel, coriander, parsley, chervil,
anise, lovage, celery, wild angelica, hogweed (the carrot family), and
three plants with flat or frothy heads that were drawn with the same
stock umbel before: yarrow, common valerian and meadowsweet.

WHY THIS FILE EXISTS
William found the strawberry leaf drawn wrong, and a spot check found the
same kinds of fault all over: the leaf on the whole plant was a stock leaf,
not the plant's own; flower colours changed between the close-up and the
plant; flowers were built from a few stock shapes; leaf shapes were rough.
In this group every carrot-family plant had the same "fern" or "compound"
leaf and the same seven-spoked umbel, so dill, lovage and hogweed looked
alike, and yarrow, valerian and meadowsweet wore an umbel they do not have.
Every plant now has a written description
(Design/Plants/descriptions/<kind>.json) with a "must_show" list for each
drawing. This file redraws every drawing of the thirteen kinds to show
those points, checked against photographs.

HOW IT WORKS (see redraw/__init__.py for the tables)
  LEAFX, BLOOMX    which close-up leaf and flower shape each kind uses, and
                   its settings.
  STAGE            every life stage of every kind, drawn here by hand,
                   because the templates in plants_all.py cannot show
                   things like a dill leaf's sheath, an angelica's pouch,
                   celery's bunch of stalks or valerian's opposite leaves.
  LEAF_DRAW, BLOOM_DRAW   the new close-up shapes, all named umbels_...
  COLOURS          one new colour, umbels_cream, for meadowsweet's creamy
                   flowers (from its description's palette_wish).
Colours come only from each description's palette.

THE MAIN IDEA: ONE LEAF FUNCTION FOR EACH KIND, USED AT ANY SIZE
Each kind's leaf is ONE function, for example leaf_dill(a, x, y, ang, L,
fill, small). The close-up calls it large (L about 98, from the bottom
left corner); the life stages call it small, with small=True, which keeps
the same shape but leaves out detail too fine to see (fewer teeth, fewer
leaflets). So the leaf on the whole plant is always the plant's own leaf.

THE NEW SHAPES, IN PLAIN WORDS
  fan_leaflet()   a leaflet drawn round the point where it joins its stalk,
      like a fan: two straight untoothed sides (the wedge base), and an
      outer edge with lobes and teeth. r(angle) says how far the edge is
      from the joining point in each direction. Used for coriander,
      parsley, celery, lovage, anise and hogweed, whose leaflets are all
      wedge- or fan-shaped and toothed only on their outer edges.
      Lovage's leaflets are long diamonds instead (see wedge()), drawn
      with rblade() below. Anise has three leaf functions, because its
      leaves change shape up the stem: anise_basal (round, toothed),
      anise_middle (three wedge leaflets) and anise_upper (threads).
  oval_leaflet()  an oval or lance-shaped leaflet with teeth all round
      (angelica, meadowsweet, valerian), drawn with rblade(): you give it
      the half width at each point along its length.
  thread()        a thread-fine leaf segment drawn as a dark line with a
      thinner line of leaf colour on top, so it looks outlined like every
      other leaf. Dill and fennel leaves are made of hundreds of these.
  umbel_close()   a compound umbel close up: rays from one point, each
      ending in a small umbel of tiny flowers. The flowers can be dots
      (dill, fennel, parsley, lovage: their petals are rolled in), small
      five-petalled stars (chervil, anise, celery, angelica) or "ragged"
      (coriander, hogweed: the outer flowers have big outer petals).
      Bracts and bracteoles (the small leaves under the umbels) are drawn
      as each kind has them, or not at all.
  umbel_side()    the same umbel on the whole plant, seen from the side,
      in flower or in seed.
  rnd(i)          a number that looks random but is always the same for
      the same i, so uneven teeth and thread angles never change between runs.
  yarrow, valerian and meadowsweet have flowers of their own:
      fl_yarrow (a flat plate of tiny daisies), fl_valerian (a dome of
      tiny tubes with stamens sticking out) and fl_meadowsweet (a frothy
      spray of five-petalled flowers with long stamens).

Things Claude chose that William should check are in the results file
for this group (kind, drawing, verdict, note).
"""
import math
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10


# ================================================================ helpers
def _lfw():
    import leaves_flowers
    return leaves_flowers


def _pa():
    import plants_all
    return plants_all


def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


BASE = (20, 92)   # where a close-up leaf's stalk starts (as in leaves_flowers.py)
ANG = -52         # and the way it points
GOLD = 2.39996


def pal(slug, part, default):
    """A colour from the kind's description (its "palette")."""
    return _pa().palette(slug).get(part, default)


def rnd(i, seed=0.0):
    """A number between 0 and 1 that looks random but is always the same
    for the same i: so the drawings come out the same every time."""
    v = math.sin(i * 12.9898 + seed * 78.233) * 43758.5453
    return v - math.floor(v)


# How wide a leaflet is along its length (u = 0 at its base, 1 at its tip),
# as a share of its widest. Copied from leaves_flowers.py so this file does
# not have to import it at the top.
PROF = {
    "ovate":    lambda u: math.sin(math.pi * u ** 0.72) ** 0.9,
    "elliptic": lambda u: math.sin(math.pi * u) ** 0.8,
    "lance":    lambda u: math.sin(math.pi * u ** 0.62) ** 1.1,
    "narrow":   lambda u: math.sin(math.pi * u ** 0.75) ** 0.75,
}


def nick(s, kind):
    """The cut in the edge across one tooth: s runs from 0 (the end nearer
    the stalk) to 1 (the end nearer the tip). 1 is the bottom of a nick,
    0 the point of a tooth."""
    if kind == "saw":    # sharp teeth leaning to the tip
        return (1 - s) ** 1.6
    if kind == "double":   # a big tooth with a small one on its back
        return (1 - s) ** 1.3 + (0.4 * (1 - (s - 0.5) / 0.5) ** 1.3 if s >= 0.5 else 0)
    if kind == "round":    # blunt rounded teeth
        return abs(math.cos(math.pi * s)) ** 2.4
    return 0.5 + 0.5 * math.cos(2 * math.pi * s)   # "wave"


def edge(u, n, depth, kind="saw", side=1, u0=0.06, u1=0.97, irr=0.0, seed=0.0):
    """How far in from the smooth outline the edge is at u: n teeth along
    the length, depth deep (grid squares). irr makes the teeth uneven."""
    if not n or u < u0 or u > u1:
        return 0.0
    v = (u - u0) / (u1 - u0) * n + (0 if side > 0 else 0.5)
    k = int(v); s = v % 1
    d = depth * (1 + irr * (rnd(k * 2 + (side > 0), seed) - 0.5) * 1.6)
    return d * nick(s, kind) * max(0.0, min(1.0, (u - u0) / 0.05, (u1 - u) / 0.05))


def rblade(a, x, y, ang, L, hw, fill, lw=1.15, midc="line", midw=0.8, mida=0.55, shade=0.1, n=140, veins=(), vw=0.5):
    """A leaf, leaflet or petal of any outline. hw(u, side) is its half
    width at u (0 at the base, 1 at the tip) on one side (1 or -1).
    veins: (u0, u1, reach) for each pair of side veins: from the midrib at
    u0 out to u1, reaching that share of the way to the edge."""
    t = T(x, y, ang)
    us = [i / n for i in range(n + 1)]
    top = [t(L * u, hw(u, 1)) for u in us]
    bot = [t(L * u, -hw(u, -1)) for u in us]
    a.shape(path(top + bot[::-1]), fill, lw)
    if shade:
        a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=shade)
    if midw:
        a.line(opath([t(L * u, 0) for u in (0.0, 0.3, 0.6, 0.9)]), midw, mida, midc)
    for u0, u1, k in veins:
        for sd in (1, -1):
            w1 = hw(u1, sd) * k * sd
            a.line(f"M{P(t(L * u0, 0))} Q{P(t(L * (u0 + (u1 - u0) * 0.35), w1 * 0.55))} {P(t(L * u1, w1))}", vw, 0.36, midc)
    return t


def oval_leaflet(a, x, y, ang, L, W, fill, prof="ovate", teeth=0, td=1.2, tk="saw", irr=0.0, lop=0.0, seed=0.0,
                 lw=1.0, veins=4, shade=0.1, run=0.0, lobes3=0.0):
    """An oval or lance-shaped leaflet with teeth all round.
    lop: one side of the base cut back (angelica's lopsided side leaflets).
    run: the base runs along the stalk a little (valerian).
    lobes3: two side lobes near the base (meadowsweet's end leaflet)."""
    pr = PROF[prof]

    def hw(u, side):
        w = W / 2 * pr(u)
        if run:
            w = max(w, W / 2 * run * max(0.0, 1 - u / 0.12))
        if lop and side < 0:
            w *= 1 - lop * max(0.0, 1 - u / 0.45) ** 1.5
        if lobes3:   # two deep notches turn it into three lobes
            w *= 1 - lobes3 * math.exp(-((u - 0.5) / 0.07) ** 2)
            w *= 1 + lobes3 * 0.35 * math.exp(-((u - 0.34) / 0.12) ** 2)
        return max(0.25, w - edge(u, teeth, td, tk, side, 0.08, 0.96, irr, seed))
    vs = [(0.05 + 0.75 * k / max(1, veins), 0.22 + 0.72 * k / max(1, veins), 0.8) for k in range(veins)] if veins else ()
    return rblade(a, x, y, ang, L, hw, fill, lw=lw, veins=vs, midw=0.7 if L > 10 else 0, shade=shade if L > 6 else 0, vw=0.45)


def ray_ellipse(th, cx, ax, ay):
    """How far from the point (0, 0) a line going out at angle th meets an
    ellipse centred at (cx, 0) with half-widths ax and ay."""
    c, s = math.cos(th), math.sin(th)
    A = (c / ax) ** 2 + (s / ay) ** 2; B = -2 * cx * c / ax ** 2; C = (cx / ax) ** 2 - 1
    d = B * B - 4 * A * C
    return (-B + math.sqrt(max(0.0, d))) / (2 * A)


def fan_leaflet(a, x, y, ang, L, fill, S=50, cx=0.52, ax=0.5, ay=0.5, lobes=3, sinus=0.3, notchw=0.5,
                teeth=3, td=1.4, tk="saw", irr=0.0, seed=0.0, lw=1.0, veins=True, shade=0.1, keep=1.0, n=150,
                lobespan=0.72, hairs=0):
    """A wedge- or fan-shaped leaflet, drawn round the point x,y where it
    joins its stalk, pointing along ang.
      S        the angle (degrees) each straight, untoothed side of the
               wedge makes with the middle line. Over 90 the leaf wraps
               round behind its stalk: a kidney or heart-shaped leaf.
      cx,ax,ay the basic outline is an ellipse, its centre cx along the
               middle line, half-widths ax and ay (all shares of L).
      lobes    how many lobes; sinus how deep the notches between them are
               (a share of the length there), notchw how wide (1 = wide V).
      teeth    teeth on each side of each lobe, td deep (grid squares),
               tk their kind ("saw", "round", "double"); irr makes them
               uneven; keep: teeth only on that outer share of each lobe.
    The teeth lean towards each lobe's tip, and fade out at the bottom of
    the notches and on the wedge sides, which are smooth."""
    t = T(x, y, ang); Sr = math.radians(S)
    span = Sr * lobespan
    centres = [0.0] if lobes == 1 else [-span + 2 * span * k / (lobes - 1) for k in range(lobes)]
    gap = (2 * span / (lobes - 1)) if lobes > 1 else 2 * Sr
    sins = [(centres[k] + centres[k + 1]) / 2 for k in range(lobes - 1)]

    def r_of(th):
        r = L * ray_ellipse(th, cx, ax, ay)
        for sn in sins:
            d = abs(th - sn) / (gap * 0.5 * notchw)
            if d < 1:
                r *= 1 - sinus * (1 - d) ** 1.4
        # which lobe this angle belongs to, and how far from its tip
        k = min(range(lobes), key=lambda j: abs(th - centres[j]))
        dd = th - centres[k]
        lim = (gap / 2) if lobes > 1 else Sr
        if k == 0 and dd < 0:
            lim = Sr - abs(centres[0]) if lobes > 1 else Sr
        if k == lobes - 1 and dd > 0:
            lim = Sr - abs(centres[-1]) if lobes > 1 else Sr
        v = min(1.0, abs(dd) / max(lim, 1e-6))
        if teeth and v < 0.98:
            if v > 1 - keep or keep >= 1:
                m = teeth
                pos = v * m
                ti = int(pos); s = 1 - (pos % 1)
                dep = td * (1 + irr * (rnd(ti * 7 + k * 3 + (dd > 0), seed) - 0.5) * 1.6)
                fade = min(1.0, (1 - v) / 0.12, v / 0.04 if v < 0.04 else 1.0)
                if keep < 1:
                    fade *= min(1.0, (v - (1 - keep)) / 0.1)
                r -= dep * nick(s, tk) * max(0.0, fade)
        return max(0.3, r)
    ths = [-Sr + 2 * Sr * i / n for i in range(n + 1)]
    pts = [t(r_of(h) * math.cos(h), r_of(h) * math.sin(h)) for h in ths]
    a.shape(path([t(0, 0)] + pts), fill, lw)
    if shade:
        half = [p for h, p in zip(ths, pts) if h >= 0]
        a.shape(path([t(0, 0)] + half), "shade", 0, fa=shade)
    if veins:
        for c in centres:
            r = r_of(c) * 0.8
            a.line(f"M{P(t(0, 0))} Q{P(t(r * 0.5 * math.cos(c * 0.8), r * 0.5 * math.sin(c * 0.8)))} {P(t(r * math.cos(c), r * math.sin(c)))}",
                   0.55 if L > 14 else 0.45, 0.45)
            if L > 22 and veins == "full":   # side veins off each lobe's main vein, leaning forward
                for u in (0.4, 0.65):
                    b = (r * u * math.cos(c), r * u * math.sin(c))
                    for sg in (1, -1):
                        e = (b[0] + r * 0.2 * math.cos(c + sg * 0.6), b[1] + r * 0.2 * math.sin(c + sg * 0.6))
                        a.line(f"M{P(t(*b))} L{P(t(*e))}", 0.4, 0.3)
    if hairs:   # hogweed: short stiff hairs, drawn as tiny flecks on the blade
        for j in range(hairs):
            h = -Sr * 0.9 + 1.8 * Sr * rnd(j, seed + 3)
            rr = r_of(h) * (0.25 + 0.6 * rnd(j, seed + 5))
            p = t(rr * math.cos(h), rr * math.sin(h))
            a.line(f"M{P(p)} l0.5,-0.6", 0.35, 0.35)
    return r_of


def thread(a, pts, fill, w=1.15, core=0.5, la=0.85):
    """One thread-fine leaf segment along the points: a dark line with a
    thinner line of the leaf colour on top, so it reads as an outlined leaf.
    la: how strong the dark line is (weaker on the whole plant, where the
    threads are so close together that full-strength lines turn them dark)."""
    d = opath(pts)
    a.line(d, w, la)
    a.line(d, core, 1.0, fill)


def curve(p0, c, p1, n=6):
    q = Quad(p0, c, p1)
    return [q.pt(i / n) for i in range(n + 1)]


def sheath(a, x, y, ang, L, W, fill, margin="white", lw=0.9):
    """The broad sheath at the foot of a leaf stalk that wraps the stem,
    pointing along ang from x,y. margin: the colour of its papery edges."""
    t = T(x, y, ang)
    pts = [t(L * u, W / 2 * (1 - 0.72 * u ** 1.3)) for u in [i / 12 for i in range(13)]]
    pts += [t(L * u, -W / 2 * (1 - 0.72 * u ** 1.3)) for u in [i / 12 for i in range(12, -1, -1)]]
    a.shape(path(pts), fill, lw)
    if margin:
        for sd in (1, -1):
            a.line(opath([t(L * u, sd * W / 2 * (1 - 0.72 * u ** 1.3) * 0.8) for u in (0.04, 0.35, 0.7, 0.92)]), max(0.5, W * 0.1), 0.95, margin)
    for o in (-0.18, 0.18):
        a.line(opath([t(L * u, o * W * (1 - 0.6 * u)) for u in (0.1, 0.5, 0.9)]), 0.4, 0.35)


def stem_stub(a, x, y, ang, L, W, fill, hollow=True, ridges=2):
    """A short piece of stem, cut off at its far end, for the close-ups to
    show how the leaf sits on it. hollow: the cut end shows it is hollow."""
    t = T(x, y, ang)
    q = a.ribbon(t(0), t(L * 0.5), t(L), W, W * 0.92, fill, lw=1.0)
    for o in [(-0.5 + k / max(1, ridges - 1)) * 0.5 * W for k in range(ridges)] if ridges > 1 else []:
        a.line(opath([t(L * u, o) for u in (0.05, 0.5, 0.95)]), 0.4, 0.35)
    e = t(L)
    a.oval(e[0], e[1], W * 0.46, W * 0.22, ang + 90, fill, 0.8)
    if hollow:
        a.oval(e[0], e[1], W * 0.28, W * 0.12, ang + 90, "white", 0.5)
    return q


# ================================================================ leaves
# Each leaf: leaf_<kind>(a, x, y, ang, L, fill, small=False). The close-up
# calls it from BASE along ANG with L about 98; the life stages call it
# small. Everything is measured as a share of L, so it scales.

def feather(a, x, y, ang, L, fill, small, style):
    """Dill and fennel: a leaf cut three or four times into threads.
    style "dill": a flat triangular feather, short threads in one plane,
    neatly in pairs. style "fennel": a soft plume of longer hair-like
    threads in loose tufts going every way."""
    fen = style == "fennel"
    t = T(x, y, ang)
    w, core = (1.1, 0.48) if not small else (0.85, 0.42)
    if fen:
        w, core = (0.95, 0.4) if not small else (0.72, 0.36)   # fennel's threads are hair-fine
    la = 0.85 if not small else (0.62 if fill != "straw" else 0.5)
    _th = thread

    def thread_(a, pts, fill, w, core):
        _th(a, pts, fill, w, core, la)
    q = Quad(t(0), t(L * 0.5, -L * 0.03), t(L))
    thread_(a, [q.pt(i / 10) for i in range(11)], fill, w * 1.35, core * 1.5)
    pairs = (6 if not small else 4) if not fen else (5 if not small else 3)
    for i in range(pairs):
        u = 0.18 + 0.74 * i / (pairs - 1)
        for sd in (1, -1):
            uu = u + (0.03 if sd > 0 else 0)          # the pairs a little alternate
            px, py = q.pt(uu); g = q.ang(uu)
            jit = (rnd(i * 2 + (sd > 0), 1.3) - 0.5) * (30 if fen else 6)
            pa = g + sd * (48 + jit)
            L1 = L * 0.38 * (1.08 - 0.85 * (u - 0.18) / 0.74)
            tq = T(px, py, pa)
            mid = tq(L1 * 0.5, -sd * L1 * 0.05)
            axis = curve((px, py), mid, tq(L1), 5)
            thread_(a, axis, fill, w, core)
            qa = Quad((px, py), mid, axis[-1])
            m = ((3 if not small else 2) if L1 > L * 0.12 else 1) if not fen else ((3 if not small else 2) if L1 > L * 0.12 else 1)
            for j in range(m):
                v = 0.3 + 0.5 * j / max(1, m - 1) if m > 1 else 0.5
                sx, sy = qa.pt(v); gs = qa.ang(v)
                for sd2 in (1, -1):
                    jj = rnd(i * 31 + j * 7 + sd2 * 3 + sd, 2.1) - 0.5
                    L2 = L1 * (0.42 if not fen else 0.5) * (1.1 - 0.55 * v)
                    if fen:   # long hair-like threads spraying every way, much longer than dill's
                        nt = 2
                        for k in range(nt):
                            off = sd2 * (22 + 40 * k) + jj * 40
                            lt = L1 * 0.62 * (1.1 - 0.5 * v) * (0.8 + 0.4 * rnd(i * 13 + j * 5 + k + sd2, 5.5))
                            e = T(sx, sy, gs + off)(lt)
                            thread_(a, [(sx, sy), T(sx, sy, gs + off - sd2 * 9)(lt * 0.5), e], fill, w, core)
                        continue
                    ga = gs + sd2 * (42 + jj * 8)
                    t2 = T(sx, sy, ga); e2 = t2(L2)
                    thread_(a, [(sx, sy), t2(L2 * 0.5, jj * 0.6), e2], fill, w, core)
                    if not small:   # the last, finest division: a pair of short threads
                        bx, by = t2(L2 * 0.5)
                        for sd3 in (1, -1):
                            thread_(a, [(bx, by), T(bx, by, ga + sd3 * 38)(L2 * 0.45)], fill, w, core)
            e = axis[-1]
            for off in ((-26, 26) if not fen else (-34, 0, 34)):
                thread_(a, [e, T(*e, pa + off)(L1 * (0.22 if not fen else 0.3))], fill, w, core)
    e = q.pt(1)
    for off in (-30, 0, 30):
        thread_(a, [e, T(*e, q.ang(1) + off)(L * 0.07)], fill, w, core)


def leaf_dill(a, x, y, ang, L, fill, small=False):
    feather(a, x, y, ang, L, fill, small, "dill")


def leaf_fennel(a, x, y, ang, L, fill, small=False):
    feather(a, x, y, ang, L, fill, small, "fennel")


def close_thread(a, sp):
    """Dill or fennel close up: the stem piece, the sheath with its papery
    edges wrapping it, and the leaf."""
    fill = sp["fill"]; fen = sp.get("style") == "fennel"
    stem_stub(a, 24, 100, -100, 30, 5.4, "sage" if fill == "sage" else fill, ridges=3)
    t = T(*BASE, ANG)
    L0 = 18 if fen else 11   # fennel's sheath is long
    feather(a, *t(L0 - 2), ANG, 96 - L0, fill, False, sp.get("style", "dill"))
    sheath(a, BASE[0] - 1, BASE[1] + 1, ANG, L0 + 1, 7.5 if fen else 6.5, fill, margin="white")
    return a


# ---- wedge-leaflet leaves: coriander, parsley, celery, lovage

def leaflets_on(a, q, us, side_ang, lsize, draw, end=None, alt=0.0):
    """Pairs of leaflets along the curve q at the places us; draw(a, x, y,
    ang, L, i) draws one; end: the size of the one at the tip (None: none)."""
    for i, u in enumerate(us):
        for sd in (1, -1):
            uu = min(0.99, u + (alt if sd > 0 else 0))
            x, y = q.pt(uu); g = q.ang(uu)
            draw(a, x, y, g + sd * side_ang, lsize[i], i, sd)
    if end:
        x, y = q.pt(1)
        draw(a, x, y, q.ang(1), end, -1, 0)


def leaf_coriander(a, x, y, ang, L, fill, small=False):
    """A lower leaf: once pinnate, a pair or two of round fan-shaped
    leaflets with blunt rounded lobes and teeth on their outer edges, the
    end leaflet the largest and three-lobed, on a long thin stalk."""
    t = T(x, y, ang)
    q = Quad(t(0), t(L * 0.3, -L * 0.03), t(L * 0.62))
    a.ribbon(q.p0, q.c, q.p1, L * 0.022 + 0.6, L * 0.014 + 0.4, fill, lw=0.8 if not small else 0.6)
    lw = 1.0 if not small else 0.6
    teeth = 3 if not small else 0

    def one(a, px, py, g, l, i, sd):
        if i == -1:   # the end leaflet: big, three-lobed
            fan_leaflet(a, px, py, g, l, fill, S=62, cx=0.5, ax=0.52, ay=0.62, lobes=3, sinus=0.34, notchw=0.55,
                        teeth=teeth, td=1.6, tk="round", lw=lw, veins=not small, seed=1)
        else:
            e = T(px, py, g)(l * 0.12)   # a short stalklet
            a.line(f"M{f(px)},{f(py)} L{P(e)}", lw * 0.8, 0.85)
            fan_leaflet(a, e[0], e[1], g, l, fill, S=64, cx=0.5, ax=0.52, ay=0.6, lobes=3, sinus=0.2, notchw=0.45,
                        teeth=teeth, td=1.5, tk="round", lw=lw, veins=not small, seed=i + sd)
    leaflets_on(a, q, [0.5, 0.86], 64, [L * 0.27, L * 0.3], one, end=L * 0.38)
    return a


def wedge(a, x, y, ang, l, fill, small, lw, kind, seed=0):
    """One wedge-shaped leaflet of parsley, celery or lovage."""
    if kind == "parsley":   # deeply three-lobed, two or three sharp teeth on each lobe
        fan_leaflet(a, x, y, ang, l, fill, S=40, cx=0.55, ax=0.47, ay=0.58, lobes=3, sinus=0.4, notchw=0.62,
                    teeth=2 if not small else 0, td=1.4, tk="saw", lw=lw, veins=not small, seed=seed, keep=0.7, lobespan=0.78)
    elif kind == "celery":   # broad, deeply three-lobed, coarse teeth on the outer edges
        fan_leaflet(a, x, y, ang, l, fill, S=46, cx=0.55, ax=0.47, ay=0.62, lobes=3, sinus=0.42, notchw=0.7,
                    teeth=3 if not small else 1, td=1.6, tk="saw", irr=0.5, lw=lw, veins="full" if not small else False, seed=seed, keep=0.7, lobespan=0.8)
    else:   # lovage: a long diamond with a smooth wedge base, shallowly lobed, coarse teeth on the upper half only
        W = l * (0.62 if not small else 0.74)

        def hw(u, side):
            w = W / 2 * (min(1.0, u / 0.46) ** 1.05 if u < 0.46 else ((1 - u) / 0.54) ** 0.8)
            if not small:
                w *= 1 - 0.28 * math.exp(-((u - 0.6) / 0.045) ** 2)          # the notch that makes a side lobe
            return max(0.3, w - edge(u, 4 if not small else 2, 1.5 if not small else 1.3, "saw", side, 0.5, 0.95, 0.7, seed))
        vs = [(0.1, 0.42, 0.85), (0.3, 0.62, 0.8), (0.5, 0.8, 0.7)] if not small else ()
        rblade(a, x, y, ang, l, hw, fill, lw=lw, veins=vs, midw=0.6 if not small else 0, shade=0.1 if not small else 0, vw=0.45)


def leaf_parsley(a, x, y, ang, L, fill, small=False):
    """Flat-leaved parsley: a long grooved stalk (about half the leaf),
    then a triangular blade cut twice: each division carries wedge-shaped,
    three-lobed leaflets with sharp teeth on their outer edges. Small (on
    the whole plant) each division is drawn as one wedge leaflet, so the
    flat leaflets stay separate and do not turn into a curly mass."""
    t = T(x, y, ang); lw = 0.95 if not small else 0.55
    q = Quad(t(0), t(L * 0.5, -L * 0.03), t(L * 0.84))
    a.ribbon(q.p0, q.c, q.p1, L * 0.03 + 0.6, L * 0.012 + 0.4, fill, lw=0.85 if not small else 0.6)
    if L > 20:   # the groove along the stalk
        a.line(opath([q.pt(u) for u in (0.04, 0.25, 0.5)]), 0.45 if not small else 0.35, 0.5)

    def division(a, px, py, g, l, i, sd):
        tq = T(px, py, g); e = tq(l * 0.5)
        a.line(f"M{f(px)},{f(py)} Q{P(tq(l * 0.25, -sd * l * 0.03))} {P(e)}", lw * 0.85, 0.85)
        if small:
            wedge(a, *e, g, l * 0.62, fill, small, lw, "parsley", seed=i)
            return
        m = tq(l * 0.24)
        for s2 in (1, -1):
            wedge(a, *m, g + s2 * 62, l * 0.36, fill, small, lw, "parsley", seed=i * 3 + s2)
        wedge(a, *e, g, l * 0.5, fill, small, lw, "parsley", seed=i)
    leaflets_on(a, q, [0.62, 0.82], 58, [L * 0.4, L * 0.3], division)
    e = q.pt(1)
    for s2 in (1, -1):
        wedge(a, *e, q.ang(1) + s2 * 52, L * 0.15, fill, small, lw, "parsley", seed=40 + s2)
    wedge(a, *e, q.ang(1), L * 0.19, fill, small, lw, "parsley", seed=41)
    return a


def leaf_celery(a, x, y, ang, L, fill, small=False, stalkc="pale"):
    """Celery: a long, thick, fleshy stalk with ribs, then a once-pinnate
    blade of two or three pairs of broad wedge-shaped, deeply three-lobed
    leaflets and one at the end, toothed on their outer edges only."""
    t = T(x, y, ang); lw = 1.0 if not small else 0.55
    sl = 0.5   # the stalk is half the leaf
    W0 = L * 0.075 + 0.6
    a.ribbon(t(0), t(L * sl * 0.5, -L * 0.01), t(L * sl), W0, W0 * 0.62, stalkc, lw=0.95 if not small else 0.6)
    if L > 14:   # the ribs down the outer side of the stalk
        for o in (-0.28, 0, 0.28):
            a.line(opath([t(L * u, o * W0 * (1 - 0.4 * u / sl)) for u in (0.02, sl * 0.4, sl * 0.8, sl * 0.98)]), 0.5 if not small else 0.35, 0.45)
    q = Quad(t(L * sl), t(L * 0.68, -L * 0.02), t(L * 0.8))
    a.ribbon(q.p0, q.c, q.p1, W0 * 0.5, W0 * 0.25, fill, lw=0.8 if not small else 0.55)

    def one(a, px, py, g, l, i, sd):
        if i == -1:
            wedge(a, px, py, g, l, fill, small, lw, "celery", seed=9)
        else:
            e = T(px, py, g)(l * 0.08)
            a.line(f"M{f(px)},{f(py)} L{P(e)}", lw * 0.8, 0.85)
            wedge(a, e[0], e[1], g, l, fill, small, lw, "celery", seed=i * 2 + sd)
    leaflets_on(a, q, [0.0, 0.55], 58, [L * 0.26, L * 0.24], one, end=L * 0.28)
    return a


def leaf_lovage(a, x, y, ang, L, fill, small=False):
    """Lovage: a stout stalk with a broad sheath, the blade cut twice into
    big glossy wedge-shaped leaflets, coarsely toothed on the upper half
    only, in threes."""
    t = T(x, y, ang); lw = 1.0 if not small else 0.55
    q = Quad(t(0), t(L * 0.4, -L * 0.03), t(L * 0.74))
    W0 = L * 0.04 + 0.6
    a.ribbon(q.p0, q.c, q.p1, W0, W0 * 0.45, fill, lw=0.9 if not small else 0.6)

    def division(a, px, py, g, l, i, sd):
        # a stalk with a pair of leaflets part way along and one at its end
        tq = T(px, py, g); e = tq(l * 0.46); m = tq(l * 0.24, -sd * l * 0.02)
        a.line(f"M{f(px)},{f(py)} Q{P(tq(l * 0.22, -sd * l * 0.03))} {P(e)}", lw * 0.9, 0.85)
        for s2 in (1, -1):
            wedge(a, *m, g + s2 * 58, l * 0.5, fill, small, lw, "lovage", seed=i * 4 + s2 + sd)
        wedge(a, *e, g, l * 0.6, fill, small, lw, "lovage", seed=i * 4 + sd)
    leaflets_on(a, q, [0.36, 0.72] if not small else [0.52, 0.78], 52 if not small else 60,
                [L * 0.5, L * 0.4] if not small else [L * 0.36, L * 0.3], division)   # small: a longer bare stalk
    e = q.pt(1); m = q.pt(0.9)
    for s2 in (1, -1):
        wedge(a, *m, q.ang(0.9) + s2 * 54, L * 0.2, fill, small, lw, "lovage", seed=30 + s2)
    wedge(a, *e, q.ang(1), L * 0.26, fill, small, lw, "lovage", seed=33)
    if not small:   # the shine of a glossy leaf: a soft pale stroke on a few leaflets
        pass
    return a


# ---- chervil: lacy, cut two or three times, blunt lobes

def cut_leaflet(a, x, y, ang, l, fill, lw, small, seed=0):
    """A small chervil leaflet, cut deeply along both sides into narrow
    lobes with blunt tips, like a tiny fern frond."""
    n = 3 if not small else 2

    def hw(u, side):
        w = l * 0.36 * math.sin(math.pi * u ** 0.75) ** 0.8
        cut = 0.86 * max(0.0, min(1.0, (0.86 - u) / 0.16))   # cut nearly to the midrib: narrow blunt lobes
        ph = 2 * math.pi * (u * n + (0.25 if side > 0 else 0.5))
        return max(0.25, w * (1 - cut * (0.5 + 0.5 * math.cos(ph)) ** 1.2))
    rblade(a, x, y, ang, l, hw, fill, lw=lw, midw=0.45 if not small else 0, mida=0.4, shade=0.08 if not small else 0, n=90)


def leaf_chervil(a, x, y, ang, L, fill, small=False):
    """Chervil: fern-like and triangular, cut two or three times; the small
    leaflets cut again into narrow blunt lobes. Bright pale green."""
    t = T(x, y, ang); lw = 0.75 if not small else 0.4
    q = Quad(t(0), t(L * 0.45, -L * 0.03), t(L * 0.93))
    a.ribbon(q.p0, q.c, q.p1, L * 0.02 + 0.5, 0.5, fill, lw=0.8 if not small else 0.55)
    pairs = 4 if not small else 3
    for i in range(pairs):
        u = 0.38 + 0.5 * i / (pairs - 1)
        for sd in (1, -1):
            uu = u + (0.03 if sd > 0 else 0); px, py = q.pt(uu); g = q.ang(uu)
            l1 = L * 0.36 * (1.1 - 0.75 * (u - 0.38) / 0.5)
            pa = g + sd * 54; tq = T(px, py, pa)
            a.line(f"M{f(px)},{f(py)} Q{P(tq(l1 * 0.5, -sd * l1 * 0.05))} {P(tq(l1 * 0.9))}", lw * 0.8, 0.85)
            m = 3 if (not small and l1 > L * 0.2) else 2
            for j in range(m):
                v = 0.25 + 0.55 * j / max(1, m - 1); bx, by = tq(l1 * v, -sd * l1 * 0.04)
                for s2 in (1, -1):
                    cut_leaflet(a, bx, by, pa + s2 * 50, l1 * (0.34 if not small else 0.44) * (1.1 - 0.5 * v), fill, lw, small, seed=i * 9 + j * 2 + s2)
            cut_leaflet(a, *tq(l1 * 0.88), pa, l1 * 0.3, fill, lw, small, seed=i * 9 + 7)
    cut_leaflet(a, *q.pt(1), q.ang(1), L * 0.13, fill, lw, small, seed=99)
    return a


# ---- anise: a round toothed leaf at the foot, finely cut leaves above

def anise_basal(a, x, y, ang, L, fill, small=False):
    """Anise's basal leaf: round to kidney-shaped with a heart-shaped base,
    shallowly lobed and coarsely toothed all round, on a long stalk."""
    t = T(x, y, ang); lw = 1.0 if not small else 0.6
    st = 0.5
    a.ribbon(t(0), t(L * st * 0.5, -L * 0.01), t(L * st), L * 0.02 + 0.5, L * 0.014 + 0.4, fill, lw=0.85 if not small else 0.6)
    # S=168: the blade wraps round behind the stalk, giving the heart-shaped base
    fan_leaflet(a, *t(L * st), ang, L * (1 - st), fill, S=168, cx=0.36, ax=0.52, ay=0.58, lobes=7, sinus=0.12, notchw=0.4,
                teeth=2 if not small else 1, td=3.2 if not small else 1.2, tk="saw", irr=0.4, lw=lw, veins=not small, lobespan=0.8, seed=2)
    return a


def anise_upper(a, x, y, ang, L, fill, small=False):
    """Anise's upper stem leaves: on a short sheath, cut two or three times
    into narrow line-like segments."""
    t = T(x, y, ang); lw = 0.8 if not small else 0.5
    w, core = (1.0, 0.45) if not small else (0.7, 0.3)
    q = Quad(t(0), t(L * 0.4, -L * 0.04), t(L * 0.8))
    thread(a, [q.pt(i / 6) for i in range(7)], fill, w * 1.2, core * 1.4)
    for u, l in ((0.35, 0.42), (0.65, 0.34), (1.0, 0.3)):
        px, py = q.pt(u); g = q.ang(u)
        for off in ((-40, 0, 40) if u == 1.0 else (-50, 50)):
            e = T(px, py, g + off)(L * l)
            thread(a, [(px, py), T(px, py, g + off * 0.9)(L * l * 0.5), e], fill, w, core)
            if not small:
                for v in (0.45, 0.75):
                    b = T(px, py, g + off * 0.95)(L * l * v)
                    for s2 in (1, -1):
                        thread(a, [b, T(*b, g + off + s2 * 32)(L * l * 0.32)], fill, w, core)
    return a


def anise_middle(a, x, y, ang, L, fill, small=False):
    """Anise's middle stem leaves: three to five wedge-shaped leaflets,
    toothed on their outer edge."""
    t = T(x, y, ang); lw = 0.9 if not small else 0.55
    e = t(L * 0.45)
    a.line(f"M{P(t(0))} L{P(e)}", lw, 0.85)
    for off, k in ((-58, 0.5), (58, 0.5), (0, 0.6)):
        fan_leaflet(a, *e, ang + off, L * k, fill, S=34, cx=0.55, ax=0.47, ay=0.6, lobes=1, sinus=0,
                    teeth=3 if not small else 1, td=1.2, tk="saw", lw=lw, veins=not small, keep=0.6, seed=off)
    return a


def leaf_anise(a, x, y, ang, L, fill, small=False):
    anise_basal(a, x, y, ang, L, fill, small)


def close_anise(a, sp):
    """Anise close up: the round basal leaf, and beside it a piece of the
    flowering stem with a middle leaf of three wedge leaflets and an upper
    leaf cut into narrow segments: the change of shape up the stem."""
    fill = sp["fill"]
    q = a.ribbon((13, 99), (10, 56), (22, 6), 2.6, 1.6, fill, lw=0.85)
    anise_basal(a, 24, 97, -34, 86, fill)
    x, y = q.pt(0.5); sheath(a, x, y, -64, 5, 3.6, fill, margin=None, lw=0.7)
    anise_middle(a, x, y, -58, 30, fill)
    x, y = q.pt(0.8); sheath(a, x, y, -30, 5, 3.2, fill, margin=None, lw=0.7)
    anise_upper(a, x, y, -26, 27, fill)
    return a


# ---- wild angelica: oval toothed leaflets, a pouch at the stalk's foot

def leaf_angelica(a, x, y, ang, L, fill, small=False, pouch=False, pouchc="plum"):
    """Wild angelica: cut two or three times into oval pointed leaflets,
    finely and sharply toothed all round, the side ones lopsided at the
    base. pouch: the inflated purplish sheath of an upper leaf."""
    t = T(x, y, ang); lw = 0.95 if not small else 0.55
    q = Quad(t(0), t(L * 0.45, -L * 0.03), t(L * 0.78))
    a.ribbon(q.p0, q.c, q.p1, L * 0.028 + 0.5, L * 0.012 + 0.4, fill, lw=0.85 if not small else 0.6)
    if not small:   # the channel along the top of the stalk
        a.line(opath([q.pt(u) for u in (0.03, 0.15, 0.3)]), 0.45, 0.45)
    teeth = 9 if not small else 0
    td = 0.9

    def lf(px, py, g, l, w, sd, seed):
        oval_leaflet(a, px, py, g, l, l * w, fill, "ovate", teeth=teeth, td=td, tk="saw", lop=0.35 if sd else 0, seed=seed,
                     lw=lw, veins=4 if not small else 0)

    def division(a, px, py, g, l, i, sd):
        tq = T(px, py, g); e = tq(l * 0.48)
        a.line(f"M{f(px)},{f(py)} Q{P(tq(l * 0.24, -sd * l * 0.03))} {P(e)}", lw * 0.85, 0.85)
        m = tq(l * 0.2)
        for s2 in (1, -1):
            lf(*m, g + s2 * 64, l * 0.44, 0.46, s2, i * 7 + s2)
        lf(*e, g, l * 0.56, 0.44, 0, i * 7)
    leaflets_on(a, q, [0.36, 0.72], 54, [L * 0.5, L * 0.4], division)
    e = q.pt(1)
    for s2 in (1, -1):
        lf(*q.pt(0.92), q.ang(0.92) + s2 * 56, L * 0.2, 0.46, s2, 50 + s2)
    lf(*e, q.ang(1), L * 0.26, 0.42, 0, 53)
    if pouch:
        inflated(a, x, y, ang, L * 0.2, L * 0.11, pouchc, lw=0.95 if not small else 0.6)
    return a


def inflated(a, x, y, ang, L, W, col, lw=0.95):
    """An inflated pouch-like sheath (angelica): wide where it wraps the
    stem, swollen, then narrowing into the leaf stalk. Green, flushed
    purple towards its foot, with a few faint veins along it."""
    t = T(x, y, ang)
    hw = lambda u: W / 2 * (0.62 + 0.38 * math.sin(math.pi * min(1.0, u * 1.3))) * (1 - u ** 2.2) + 0.5
    us = [i / 24 for i in range(25)]
    top = [t(L * u, hw(u)) for u in us]
    bot = [t(L * u, -hw(u)) for u in us]
    a.shape(path(top + bot[::-1]), "leaf", lw)
    lo = [u for u in us if u <= 0.5]
    a.shape(path([t(L * u, hw(u)) for u in lo] + [t(L * u, -hw(u)) for u in lo[::-1]]), col, 0, fa=0.42)   # the purple flush
    a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.1)
    for o in (-0.45, 0, 0.45):
        a.line(opath([t(L * u, o * hw(u)) for u in (0.05, 0.4, 0.75, 0.95)]), 0.4, 0.35)


def close_angelica(a, sp):
    """Wild angelica close up: an upper stem leaf with its inflated pouch
    wrapping a piece of the purplish stem."""
    fill = sp["fill"]
    stem_stub(a, 18, 100, -96, 30, 5.6, "plum", ridges=2)
    a.oval(17.2, 84, 2.4, 6, -6, "white", 0, la=0)   # the pale bloom on the stem
    t = T(*BASE, ANG)
    leaf_angelica(a, *t(22), ANG, 78, fill)
    inflated(a, 17.5, 97, -62, 30, 16, "plum")   # the pouch wraps the stem and runs up into the stalk
    return a


# ---- hogweed: once pinnate, big broad lobed leaflets

def leaf_hogweed(a, x, y, ang, L, fill, small=False):
    """Hogweed: once pinnate, a pair or two of big broad leaflets cut into
    pointed lobes, coarsely and unevenly toothed all round, the lowest
    pair on stalks; rough and hairy, with a sheath that wraps the stem."""
    t = T(x, y, ang); lw = 1.0 if not small else 0.55
    q = Quad(t(0), t(L * 0.4, -L * 0.02), t(L * 0.6))
    W0 = L * 0.035 + 0.6
    a.ribbon(q.p0, q.c, q.p1, W0, W0 * 0.6, fill, lw=0.9 if not small else 0.6)
    if not small:   # stiff hairs on the stalk
        for i in range(10):
            u = 0.06 + 0.08 * i; px, py = q.pt(u); g = q.ang(u)
            for sd in (1, -1):
                e = T(px, py, g + sd * 125)(1.5); a.line(f"M{f(px)},{f(py)} L{P(e)}", 0.4, 0.75)
    hairs = 26 if not small else 0
    teeth = 4 if not small else 2

    def one(a, px, py, g, l, i, sd):
        if i == -1:   # the end leaflet, three-lobed
            fan_leaflet(a, px, py, g, l, fill, S=80, cx=0.48, ax=0.52, ay=0.6, lobes=3, sinus=0.5, notchw=0.75,
                        teeth=teeth, td=2.6, tk="saw", irr=0.8, seed=7, lw=lw, veins="full" if not small else False, hairs=hairs)
            return
        if i == 0:   # the lowest pair on stalks
            e = T(px, py, g)(l * 0.2); a.line(f"M{f(px)},{f(py)} L{P(e)}", lw, 0.85); px, py = e
        fan_leaflet(a, px, py, g, l, fill, S=72, cx=0.5, ax=0.52, ay=0.55, lobes=3, sinus=0.38, notchw=0.7,
                    teeth=teeth, td=2.4, tk="saw", irr=0.8, seed=i * 3 + sd, lw=lw, veins="full" if not small else False, hairs=hairs // 2)
    leaflets_on(a, q, [0.42, 0.85], 60, [L * 0.34, L * 0.3], one, end=L * 0.42)
    return a


def close_hogweed(a, sp):
    fill = sp["fill"]
    stem_stub(a, 22, 100, -94, 24, 6.0, fill, ridges=3)
    for i in range(7):   # the downward hairs on the stem
        y = 97 - i * 3.0
        a.line(f"M{f(18.6 + 0.05 * i)},{f(y)} l-1.4,1.2 M{f(25 - 0.05 * i)},{f(y - 1)} l1.4,1.2", 0.4, 0.75)
    t = T(*BASE, ANG)
    leaf_hogweed(a, *t(10), ANG, 88, fill)
    sheath(a, BASE[0] - 1, BASE[1] + 2, ANG, 13, 9, fill, margin=None)
    return a


# ---- yarrow: long, narrow, finely feathery

def leaf_yarrow(a, x, y, ang, L, fill, small=False):
    """Yarrow: a long narrow strap of a leaf with ONE midrib, cut two or
    three times into very many fine pointed segments on both sides, some
    standing up out of the flat, so it looks soft and feathery."""
    t = T(x, y, ang)
    lw = 0.5 if not small else 0.42
    q = Quad(t(0), t(L * 0.5, -L * 0.03), t(L))
    thread(a, [q.pt(u) for u in (0.0, 0.25, 0.5, 0.75, 1.0)], fill, 1.25 if not small else 0.95, 0.6 if not small else 0.45)
    n = 22 if not small else 11
    W = L * (0.15 if not small else 0.12)
    for i in range(n):
        u = 0.14 + 0.84 * i / (n - 1)
        for sd in (1, -1):
            uu = min(1, u + (0.4 / n if sd > 0 else 0))
            px, py = q.pt(uu); g = q.ang(uu)
            l = W * math.sin(math.pi * min(1, (uu - 0.1) / 0.94)) ** 0.5 * (0.85 + 0.3 * rnd(i * 2 + sd, 4))
            pa = g + sd * (58 + 25 * (rnd(i * 5 + sd, 6) - 0.5))
            tq = T(px, py, pa)
            if small:   # each division a short comb of fine points
                a.leaf(px, py, pa, l, 0.16, fill, lw=lw, detail=False, skew=0.35)
                b = tq(l * 0.5); a.leaf(b[0], b[1], pa + sd * 40, l * 0.45, 0.2, fill, lw=lw, detail=False, skew=0.35)
                continue
            a.line(f"M{f(px)},{f(py)} L{P(tq(l * 0.9))}", 0.4, 0.8)
            for v in (0.25, 0.5, 0.72):
                b = tq(l * v)
                for s2 in (1, -1):
                    a.leaf(b[0], b[1], pa + s2 * 44, l * 0.4 * (1.1 - 0.4 * v), 0.17, fill, lw=lw, detail=False, skew=0.35)
            a.leaf(*tq(l * 0.88), pa, l * 0.32, 0.17, fill, lw=lw, detail=False, skew=0.35)
    return a


# ---- common valerian: once pinnate, many narrow lance leaflets

def leaf_valerian(a, x, y, ang, L, fill, small=False):
    """Common valerian: once pinnate with many narrow lance-shaped
    leaflets, stalkless, their bases running a little along the midrib,
    with a few uneven coarse teeth or none; the end leaflet like the rest."""
    t = T(x, y, ang); lw = 0.9 if not small else 0.55
    q = Quad(t(0), t(L * 0.5, -L * 0.02), t(L * 0.84))
    a.ribbon(q.p0, q.c, q.p1, L * 0.022 + 0.5, L * 0.01 + 0.4, fill, lw=0.85 if not small else 0.55)
    pairs = 6 if not small else 4
    for i in range(pairs):
        u = 0.3 + 0.66 * i / (pairs - 1)
        for sd in (1, -1):
            px, py = q.pt(u); g = q.ang(u)
            l = L * 0.24 * (1.0 - 0.25 * (u - 0.3) / 0.66)
            nt = 0 if (small or rnd(i * 2 + sd, 8) < 0.3) else 2   # a few coarse teeth, or none
            oval_leaflet(a, px, py, g + sd * (60 - 14 * u), l, l * 0.3, fill, "lance", teeth=nt, td=0.7,
                         tk="saw", irr=0.6, seed=i * 2 + sd, lw=lw, veins=0, run=0.2 if not small else 0)
    e = q.pt(1)
    oval_leaflet(a, e[0], e[1], q.ang(1), L * 0.2, L * 0.2 * 0.3, fill, "lance", teeth=2 if not small else 0, td=0.7,
                 tk="saw", irr=0.7, seed=31, lw=lw, veins=0)
    return a


# ---- meadowsweet: big doubly toothed leaflets, tiny ones between

def leaf_meadowsweet(a, x, y, ang, L, fill, small=False, stalkc="rust"):
    """Meadowsweet: pinnate, two to four pairs of big oval leaflets with
    sharp double teeth and deep veins, tiny leaflets between the pairs,
    and a bigger end leaflet cut into three to five lobes. Reddish stalk
    with leafy toothed stipules at its foot. One leaflet turned to show
    the pale underside."""
    t = T(x, y, ang); lw = 0.95 if not small else 0.55
    q = Quad(t(0), t(L * 0.42, -L * 0.03), t(L * 0.66))
    a.ribbon(q.p0, q.c, q.p1, L * 0.024 + 0.5, L * 0.012 + 0.4, stalkc, lw=0.85 if not small else 0.55)
    if not small:   # the stipules: two small toothed ears at the foot
        for sd in (1, -1):
            oval_leaflet(a, *t(L * 0.02), ang + sd * 70, L * 0.1, L * 0.06, fill, "ovate", teeth=3, td=0.8, lw=0.75, veins=0)
    teeth = 6 if not small else 2
    us = [0.22, 0.56, 0.9]
    for i, u in enumerate(us):
        px, py = q.pt(u); g = q.ang(u)
        l = L * 0.24 * (1 - 0.12 * i)
        for sd in (1, -1):
            under = (not small) and i == 0 and sd > 0
            oval_leaflet(a, px, py, g + sd * 56, l, l * 0.52, "pale" if under else fill, "ovate", teeth=teeth, td=1.3 if not small else 0.8,
                         tk="double" if not small else "saw", seed=i * 3 + sd, lw=lw, veins=5 if not small else 0, shade=0.06 if under else 0.1)
        if i < len(us) - 1:   # the tiny leaflets between the pairs
            m = q.pt(u + (us[i + 1] - u) * 0.5); gm = q.ang(u + (us[i + 1] - u) * 0.5)
            for sd in (1, -1):
                tl = L * 0.045 if not small else max(2.0, L * 0.07)   # kept big enough to see on the whole plant
                oval_leaflet(a, m[0], m[1], gm + sd * 62, tl, tl * 0.66, fill, "ovate", teeth=0, lw=lw * 0.8, veins=0, shade=0)
    e = q.pt(1)
    oval_leaflet(a, e[0], e[1], q.ang(1), L * 0.32, L * 0.32 * 0.78, fill, "ovate", teeth=teeth + 2, td=1.3 if not small else 0.8,
                 tk="double" if not small else "saw", seed=40, lw=lw, veins=5 if not small else 0, lobes3=0.62)
    return a


# ================================================================ close-up flowers
CX, CY = 50, 44


def notched_petal(a, x, y, ang, L, W, fill, lw=0.4, M=None):
    """A petal that widens to two rounded lobes with a notch between them
    at its tip (hogweed, and coriander's big outer petals), drawn from its
    base at x,y along ang."""
    t = T(x, y, ang); mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    rl = W * 0.27; cxl = L - rl * 1.05
    top = [(L * 0.72 * u, (W / 2 - rl * 0.1) * math.sin(math.pi / 2 * u) ** 0.9) for u in [i / 8 for i in range(9)]]
    arc = [(cxl + rl * math.cos(h), W / 2 - rl + rl * math.sin(h)) for h in [math.radians(90 - 200 * i / 10) for i in range(11)]]
    side = top + arc + [(L * 0.86, 0)]
    pts = side + [(px, -py) for px, py in side[::-1]]
    a.shape(path([mp(p) for p in pts]), fill, lw)


def floret(a, x, y, r, fc, style, cen="unripe", outer=None, lw=0.36, alt=None):
    """One tiny flower of an umbel, r across.
      "dot":    petals rolled in, so it is a small ball (dill, fennel, parsley)
      "star":   five tiny spreading petals (chervil, anise, celery, angelica)
      "ragged": like "star", but if outer (an angle, radians) is given it is
                an outer flower: the petals facing outwards much bigger and
                notched (coriander, hogweed)."""
    if style == "dot":
        a.oval(x, y, r * 0.62, r * 0.56, 0, fc, lw)
        a.dot(x - r * 0.15, y - r * 0.15, max(0.25, r * 0.16), "white" if fc not in ("white", "pale") else "unripe")
        return
    if style == "ragged" and outer is not None:
        od = math.degrees(outer)
        for k in range(5):
            g = od + 180 + 72 * k + 36
            big = math.cos(math.radians(g) - outer) > 0.2
            if big:
                notched_petal(a, x, y, g, r * 1.55, r * 1.25, fc, lw)
            else:
                a.leaf(x, y, g, r * 0.6, 0.6, fc, lw=lw, skew=0.6, detail=False)
        a.dot(x, y, max(0.3, r * 0.2), cen)
        return
    a.flower(x, y, r * 0.75, 5, fc, None, 0.8, start=-90 + (x * 37) % 72, lw=lw)
    a.dot(x, y, max(0.3, r * 0.2), cen)


def umbellet_close(a, e, fc, style, rr, n=10, cen="unripe", outer=None, rim=False, fr=2.4, pink=None, seed=0.0, pinkn=3):
    """A small umbel at the end of a ray, close up: short rays out to a
    little dome of tiny flowers. rim: this umbel is on the outside of the
    big umbel, so its outer flowers are the ragged ones."""
    pts = []
    m = n - 3
    for j in range(m):   # a ring of flowers, seen at a slant
        th = 2 * math.pi * j / m + seed
        pts.append(((e[0] + rr * math.cos(th), e[1] - rr * 0.55 + rr * 0.42 * math.sin(th)), th))
    for j in range(3):   # and a few in the middle, a little higher
        th = 2 * math.pi * j / 3 + seed + 0.5
        pts.append(((e[0] + rr * 0.35 * math.cos(th), e[1] - rr * 0.7 + rr * 0.15 * math.sin(th)), None))
    pts.sort(key=lambda q: q[0][1])
    for p, th in pts:
        a.line(f"M{P(e)} L{P(p)}", 0.35, 0.5)
    for k, (p, th) in enumerate(pts):
        ou = None
        if rim and th is not None and outer is not None and math.cos(th - outer) > 0.35:
            ou = outer
        col = pink if (pink and (k + int(seed * 3)) % pinkn == 0) else fc
        floret(a, p[0], p[1], fr * (1.0 if ou is None else 0.95), col, style, cen, ou)


def umbel_close(a, sp):
    """A compound umbel close up, seen a little from the side: rays from
    one point, each ending in a small umbel. Settings (sp):
      rays     how many rays (an outer ring; with many, an inner ring too)
      R        how wide; dome: 0 flat-topped, up to 1 rounded
      style    the flowers: "dot", "star" or "ragged" (see floret)
      uneven   the rays of different lengths (dill)
      bracts   under the big umbel: None, "small" (one to three small),
               "down" (narrow, turned down, papery edges)
      bracteoles  under each small umbel: None, "thin", "down",
               "oneside" (on one side, turned down: chervil), "bristle"
      stalk    "long" (on its own stalk) or "short" (sitting close
               opposite a leaf: chervil, celery)
      pink     a second flower colour mixed in (angelica's pink flush)"""
    fc = sp["fc"]; style = sp.get("style", "star"); n = sp.get("rays", 10); R = sp.get("R", 33)
    dome = sp.get("dome", 0.0); k = sp.get("k", 0.34); cen = sp.get("dotc", "unripe")   # k: how much of the top we see (small: seen edge-on, flat)
    short = sp.get("stalk") == "short"
    hub = (50, 72) if not short else sp.get("hub", (46, 70))
    c = (hub[0], hub[1] - sp.get("rayh", 34 if not short else 30))   # rayh: how long the rays are
    if short:   # the stem with a leaf, the umbel on a short stalk opposite it
        q = a.ribbon((70, 100), (66, 86), (60, 76), 3.2, 2.8, "leaf", lw=0.95)
        a.ribbon((60, 76), (66, 66), (80, 52), 2.8, 2.2, "leaf", lw=0.95)
        lf = sp.get("leaf")
        if lf:
            lf(a, 60, 77, 18, 32, _pa().palette(sp.get("slug", "")).get("leaf", "leaf"), True)
        a.ribbon((60, 76.5), (55, 74.5), hub, 2.0, 1.6, "leaf", lw=0.85)
    else:
        a.ribbon((52, 99), (52, 86), hub, 2.8, 2.4, sp.get("stemc", "leaf"), lw=0.9)
    if sp.get("bracts") == "small":
        for g in (150, 30):
            a.leaf(*hub, g, 7, 0.16, "leaf", lw=0.6, detail=False)
    elif sp.get("bracts") == "down":
        for g in (165, 135, 105, 75, 45, 15):
            e = T(*hub, g)(9.5)
            a.leaf(*hub, g, 10, 0.15, "leaf", lw=0.6, detail=False)
            a.line(f"M{P(T(*hub, g)(2))} L{P(T(*hub, g)(8.5))}", 0.5, 0.9, "white")
    # where the rays end: an outer ring, an inner ring if there are many, and the middle
    ends = []
    no = n if n <= 9 else round(n * 0.62); ni = n - no if n > 9 else 0
    for i in range(no):
        g = i * 360 / no + 12
        ends.append((g, 1.0 * (1 - sp.get("uneven", 0) * rnd(i, 2.2)), True))
    for i in range(ni):
        g = i * 360 / max(1, ni) + 40
        ends.append((g, 0.52 * (1 - sp.get("uneven", 0) * 0.6 * rnd(i, 3.3)), False))
    if n >= 4:
        ends.append((90, 0.0, False))

    def place(g, rf):
        r = math.radians(g)
        x = c[0] + R * rf * math.cos(r); y = c[1] + R * rf * k * math.sin(r)
        y -= dome * R * 0.42 * (1 - rf * rf)
        return (x, y), math.sin(r) * rf
    for g, rf, rim in sorted(ends, key=lambda q: place(q[0], q[1])[1]):
        e, z = place(g, rf)
        a.line(f"M{P(hub)} Q{f((hub[0] + e[0]) / 2)},{f((hub[1] + e[1]) / 2 + 4)} {P(e)}", 0.7, 0.75)
        if sp.get("bracteoles"):
            bt = sp["bracteoles"]; od = math.radians(g)
            gs = {"thin": (110, 90, 70, 130, 50), "down": (120, 90, 60), "bristle": (125, 105, 75, 55),
                  "oneside": tuple(90 + 50 * math.cos(od) + o for o in (-18, 0, 18))}[bt]
            for gg in gs:
                L_ = {"thin": 3.6, "down": 4.2, "bristle": 3.4, "oneside": 4.6}[bt]
                if bt == "oneside":
                    a.leaf(e[0], e[1], gg, L_, 0.22, "leaf", lw=0.4, detail=False)
                else:
                    a.line(f"M{P(e)} L{P(T(*e, gg)(L_))}", 0.4, 0.8)
        od = math.atan2(math.sin(math.radians(g)) * 0.6, math.cos(math.radians(g)))
        rr = sp.get("rr", 6.6) * (0.9 + 0.12 * z)
        umbellet_close(a, e, fc, style, rr, n=sp.get("fl", 11), cen=cen, outer=od if rf > 0 else None, rim=rim and style == "ragged",
                       fr=sp.get("fr", 2.4), pink=sp.get("pink"), seed=g * 0.01, pinkn=sp.get("pinkn", 3))
    return a


def ray_petal(a, x, y, ang, L, W, fill, lw=0.45, M=None):
    """A broad ray of a yarrow head: short and rounded, with three small
    teeth across its end."""
    t = T(x, y, ang); mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    us = [i / 8 for i in range(9)]
    hw = lambda u: W / 2 * math.sin(math.pi / 2 * min(1, u / 0.6)) ** 0.6
    top = [mp((L * 0.92 * u, hw(u))) for u in us]
    bot = [mp((L * 0.92 * u, -hw(u))) for u in us]
    tip = [mp((L, W * 0.3)), mp((L * 0.93, W * 0.15)), mp((L * 1.0, 0)), mp((L * 0.93, -W * 0.15)), mp((L, -W * 0.3))]
    a.shape(path(top + tip + bot[::-1]), fill, lw)


def yarrow_head(a, x, y, r, fc, cen, k=0.72, lw=0.45, bracts=False):
    """One tiny yarrow head, seen from above at a slant: about five broad
    rays round a small disc of cream florets."""
    M = lambda p: (p[0], y + (p[1] - y) * k)
    if bracts:   # the green bracts with brown papery edges, seen under a head at the rim
        a.oval(x, y + r * 0.45, r * 0.42, r * 0.45, 0, "leaf", lw)
        a.line(f"M{f(x - r * 0.4)},{f(y + r * 0.45)} Q{f(x)},{f(y + r * 0.62)} {f(x + r * 0.4)},{f(y + r * 0.45)}", 0.5, 0.9, "bark")
    for j in range(5):
        ray_petal(a, x, y, -90 + 72 * j + (x * 11) % 30, r, r * 0.95, fc, lw, M)
    a.oval(x, y, r * 0.36, r * 0.36 * k, 0, cen, lw)
    for j in range(5):
        e = (x + r * 0.2 * math.cos(j * GOLD), y + r * 0.2 * k * math.sin(j * GOLD)); a.dot(e[0], e[1], max(0.25, r * 0.06), "amber")


def corymb_tree(a, start, heads, top_y, lw=0.6, depth=0):
    """Yarrow's branching: the stalks fork again and again at different
    heights, so that all the heads end up level in a flat top (a corymb),
    not on rays from one point as an umbel's are. heads: the points the
    branches must reach (sorted left to right)."""
    if len(heads) <= 3:
        fy = min(h[1] for h in heads) + 3.5
        fork = (sum(h[0] for h in heads) / len(heads), max(start[1] - 2, fy))
        a.line(f"M{P(start)} L{P(fork)}", lw, 0.85)
        for h in heads:
            a.line(f"M{P(fork)} L{f(h[0])},{f(h[1] + 1)}", lw * 0.8, 0.85)
        return
    k = 3 if len(heads) >= 9 else 2
    size = len(heads) / k
    for g in range(k):
        grp = heads[int(round(g * size)):int(round((g + 1) * size))]
        if not grp:
            continue
        f_ = (0.32, 0.55, 0.42)[g % 3] if depth == 0 else (0.4, 0.62, 0.5)[g % 3]   # each branch leaves at its own height
        gx = sum(h[0] for h in grp) / len(grp)
        fork = (start[0] + (gx - start[0]) * 0.75, start[1] + (top_y - start[1]) * f_)
        a.line(f"M{P(start)} Q{f(start[0] + (gx - start[0]) * 0.2)},{f(start[1] - 2)} {P(fork)}", lw, 0.85)
        corymb_tree(a, fork, grp, top_y, lw * 0.85, depth + 1)


def fl_yarrow(a, sp):
    """Yarrow: dozens of tiny daisy heads packed into a flat-topped
    cluster, on stalks that branch at several heights (a corymb)."""
    fc = sp["fc"]; cen = sp.get("cen", "straw")
    a.ribbon((50, 99), (50, 90), (50, 82), 3.0, 2.6, "leaf", lw=0.95)
    heads = []
    for i in range(34):   # spread over a flat plate seen a little from above
        rr = math.sqrt((i + 0.5) / 34); th = i * GOLD + 0.4
        heads.append((50 + 36 * rr * math.cos(th), 34 + 10 * rr * math.sin(th)))
    corymb_tree(a, (50, 82), sorted(heads), 30, lw=0.75)
    for x, y in sorted(heads, key=lambda q: q[1]):
        yarrow_head(a, x, y, 4.6, fc, cen, bracts=y > 41)
    return a


def valerian_flower(a, x, y, r, fc, ang=-90, lw=0.4, anth="primrose"):
    """One tiny valerian flower: a short tube opening into five spreading
    lobes, three stamens standing out beyond them."""
    t = T(x, y, ang)
    base = t(-r * 0.9)
    a.ribbon(base, t(-r * 0.45), t(-r * 0.05), r * 0.38, r * 0.5, fc, lw=lw)
    M = lambda p: (p[0], y + (p[1] - y) * 0.7)
    for j in range(5):
        a.leaf(x, y, -90 + 72 * j + 20, r * (0.85 if j else 0.95), 0.62, fc, lw=lw, skew=0.55, detail=False)
    a.dot(x, y, max(0.3, r * 0.14), "white")
    for j, g in enumerate((ang - 30, ang, ang + 30)):
        e = T(x, y, g)(r * 1.45)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.35, 0.75)
        a.dot(e[0], e[1], max(0.35, r * 0.15), anth)


def fl_valerian(a, sp):
    """Common valerian: tiny pale pink tubular flowers in a rounded,
    branched head. The branches come off the stem in opposite pairs (as
    the leaves do), each ending in a small crowded cluster; together the
    clusters make a dome."""
    fc = sp["fc"]
    q = a.ribbon((50, 99), (50, 70), (50, 40), 3.0, 1.8, "leaf", lw=0.95)
    ends = [(50, 30)]
    for y0, dx, h in ((80, 30, 34), (66, 22, 26), (54, 13, 18)):
        with a.on(STEM):
            for sd in (1, -1):
                e = (50 + sd * dx, y0 - h)
                a.line(f"M50,{f(y0)} Q{f(50 + sd * dx * 0.5)},{f(y0 - 4)} {P(e)}", 0.8, 0.85)
                ends.append(e)
        for sd in (1, -1):   # a pair of small leaves where each pair of branches leaves the stem
            a.leaf(50, y0, -90 + sd * 70, 6, 0.25, "leaf", lw=0.6, detail=False)
    a.line("M50,40 L50,30", 0.8, 0.85)
    fl = []
    for k, e in enumerate(ends):
        for i in range(7):
            rr = 7.5 * math.sqrt((i + 0.5) / 7); th = i * GOLD + k
            fl.append((e[0] + rr * math.cos(th) * 1.15, e[1] + rr * math.sin(th) * 0.8, i, e))
    for x, y, i, e in fl:
        a.line(f"M{P(e)} L{f(x)},{f(y)}", 0.4, 0.6)
    for x, y, i, e in sorted(fl, key=lambda q: q[1]):
        ang = -90 + (x - 50) * 1.3
        if i == 6:   # a bud
            a.oval(x, y, 1.8, 2.4, (x - 50) * 1.3, fc, 0.45)
            continue
        valerian_flower(a, x, y, 4.0, fc, ang)
    return a


def meadowsweet_flower(a, x, y, r, fc, cen, lw=0.45, k=0.82, n=5, stam=18):
    """One meadowsweet flower: five round creamy petals, and a ring of long
    stamens standing out well past them (the fuzzy, frothy look)."""
    M = lambda p: (p[0], y + (p[1] - y) * k)
    rot = (x * 13 + y * 7) % 72
    for j in range(stam):   # the stamens first, so the petals lie over their feet
        g = j * 360 / stam + rot / 2; e = M(T(x, y, g)(r * (1.4 + 0.18 * (j % 2))))
        a.line(f"M{P(M(T(x, y, g)(r * 0.3)))} L{P(e)}", 0.3, 0.7)
        a.dot(e[0], e[1], max(0.3, r * 0.07), cen)
    for j in range(n):
        g = -90 + 360 * j / n + rot
        t = T(x, y, g)
        pts = [M(t(r * 0.52 + r * 0.46 * math.cos(h), r * 0.46 * math.sin(h))) for h in [2 * math.pi * i / 24 for i in range(24)]]
        a.shape(path(pts), fc, lw)
    for j in range(10):   # the inner stamens over the petals
        g = j * 36 + rot; e = M(T(x, y, g)(r * 0.62))
        a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.3, 0.7)
        a.dot(e[0], e[1], max(0.3, r * 0.06), cen)
    a.oval(x, y, r * 0.2, r * 0.2 * k, 0, "unripe", 0.35)


def fl_meadowsweet(a, sp):
    """Meadowsweet: small creamy flowers in a frothy, irregular branched
    spray, the side branches leaving the stem at different heights and
    rising above its top. A few open flowers are drawn large enough to
    show their five petals and long stamens; buds and small flowers
    round them make the froth."""
    fc = sp["fc"]; cen = sp.get("cen", "primrose"); stc = sp.get("stemc", "rust")
    a.ribbon((54, 99), (52, 76), (50, 44), 3.0, 1.6, stc, lw=0.95)
    br = [((52.6, 82), (20, 46)), ((52.0, 72), (80, 40)), ((51.2, 62), (30, 24)), ((50.6, 54), (70, 20)), ((50, 44), (50, 30))]
    small, big = [], []
    for j, (b0, e) in enumerate(br):
        q = Quad(b0, ((b0[0] + e[0]) / 2, b0[1] - 8), e)
        a.line(q.d(), 0.85, 0.85)
        for v in (0.55, 0.78):   # little side twigs along each branch
            px, py = q.pt(v); sd = 1 if j % 2 else -1
            tw = (px + sd * 5, py - 6); a.line(f"M{f(px)},{f(py)} L{P(tw)}", 0.5, 0.85)
            for i in range(4):
                th = i * GOLD + j; small.append((tw[0] + 3.2 * math.cos(th), tw[1] + 2.4 * math.sin(th), tw))
        big.append(e)
        for i in range(5):
            th = i * GOLD + j * 2; small.append((e[0] + 6 * math.cos(th), e[1] + 4.5 * math.sin(th), e))
    for x, y, e in small:
        a.line(f"M{P(e)} L{f(x)},{f(y)}", 0.35, 0.6)
    for i, (x, y, e) in enumerate(sorted(small, key=lambda q: q[1])):
        if i % 2:
            a.oval(x, y, 1.7, 1.6, 0, fc, 0.45)   # a round bud
        else:
            meadowsweet_flower(a, x, y, 2.6, fc, cen, stam=10)
    for x, y in sorted(big, key=lambda q: q[1]):   # the open flowers, large enough to see
        meadowsweet_flower(a, x, y, 6.2, fc, cen)
    return a


BLOOM_DRAW = {"umbels_umbel": umbel_close, "umbels_yarrow": fl_yarrow, "umbels_valerian": fl_valerian,
              "umbels_meadowsweet": fl_meadowsweet}

BLOOMX = {
    "dill": dict(kind="umbels_umbel", style="dot", rays=16, R=36, uneven=0.3, rr=5.6, fl=10, fr=2.2),
    "fennel": dict(kind="umbels_umbel", style="dot", rays=13, R=32, rr=5.8, fl=10, fr=2.2, dome=0.15),
    "coriander": dict(kind="umbels_umbel", style="ragged", rays=4, R=26, rr=8.0, fl=9, fr=3.0, bracteoles="oneside"),
    "parsley": dict(kind="umbels_umbel", style="dot", rays=11, R=32, rr=5.8, fl=11, fr=2.0, bracts="small", bracteoles="thin"),
    "chervil": dict(kind="umbels_umbel", style="star", rays=5, R=22, rr=6.4, fl=9, fr=2.5, stalk="short", bracteoles="oneside", slug="chervil",
                    leaf=lambda a, x, y, g, L, c, sm: leaf_chervil(a, x, y, g, L, c, sm)),
    "anise": dict(kind="umbels_umbel", style="star", rays=10, R=31, rr=5.8, fl=10, fr=2.3),
    "lovage": dict(kind="umbels_umbel", style="dot", rays=14, R=33, rr=5.6, fl=11, fr=2.1, dome=0.3, bracts="down", bracteoles="down"),
    "celery": dict(kind="umbels_umbel", style="star", rays=5, R=16, rr=5.8, fl=9, fr=2.4, stalk="short", slug="celery", hub=(54, 73), rayh=17,
                   leaf=lambda a, x, y, g, L, c, sm: leaf_celery(a, x, y, g, L, c, sm, stalkc="leaf")),
    "wild-angelica": dict(kind="umbels_umbel", style="star", rays=18, R=35, rr=6.0, fl=12, fr=2.5, dome=0.8, pink="pink", pinkn=2, bracteoles="bristle", stemc="plum"),
    "hogweed": dict(kind="umbels_umbel", style="ragged", rays=13, R=36, rr=6.4, fl=11, fr=2.3, bracteoles="bristle", k=0.2),
    "yarrow": dict(kind="umbels_yarrow"),
    "common-valerian": dict(kind="umbels_valerian"),
    "meadowsweet": dict(kind="umbels_meadowsweet"),
}


# ================================================================ close-up leaf entry points
def close_leaf(fn, stalk_stub=None):
    """Makes a LEAF_DRAW function from a leaf function: draws it large from
    the bottom-left corner of the close-up."""
    def draw(a, sp):
        fn(a, *BASE, ANG, sp.get("L", 96), sp["fill"])
        return a
    return draw


def close_valerian(a, sp):
    """Valerian close up: the leaf on a piece of stem, with the foot of the
    leaf opposite it, because valerian's leaves are in opposite pairs."""
    stem_stub(a, 20, 100, -92, 30, 4.6, sp["fill"], ridges=2)
    a.ribbon(BASE, (13, 88), (2, 84), 2.6, 2.0, sp["fill"], lw=0.85)   # the opposite leaf, running out of the picture
    leaf_valerian(a, *BASE, ANG, 96, sp["fill"])
    return a


def close_celery(a, sp):
    leaf_celery(a, *BASE, ANG, 98, sp["fill"], stalkc=sp.get("stalkc", "pale"))
    return a


def close_meadowsweet(a, sp):
    leaf_meadowsweet(a, *BASE, ANG, 98, sp["fill"], stalkc=sp.get("stalkc", "rust"))
    return a


COLOURS = {
    # meadowsweet's creamy white (its description's palette_wish, #F5EDCF), and a
    # softer cream for the dark card
    "umbels_cream": ("#F5EDCF", "#E6D9AF"),
    # dill's and fennel's bright greenish yellow: the stock "sun" was amber
    # beside the photographs (independent check, 17 November 2026)
    "umbels_yellow": ("#E4D93C", "#D9CE3E"),
}

LEAF_DRAW = {
    "umbels_thread": close_thread,
    "umbels_coriander": close_leaf(leaf_coriander),
    "umbels_parsley": close_leaf(leaf_parsley),
    "umbels_celery": close_celery,
    "umbels_lovage": close_leaf(leaf_lovage),
    "umbels_chervil": close_leaf(leaf_chervil),
    "umbels_anise": close_anise,
    "umbels_angelica": close_angelica,
    "umbels_hogweed": close_hogweed,
    "umbels_yarrow": close_leaf(leaf_yarrow),
    "umbels_valerian": close_valerian,
    "umbels_meadowsweet": close_meadowsweet,
}

LEAFX = {
    "dill": dict(kind="umbels_thread", style="dill"),
    "fennel": dict(kind="umbels_thread", style="fennel"),
    "coriander": dict(kind="umbels_coriander"),
    "parsley": dict(kind="umbels_parsley"),
    "celery": dict(kind="umbels_celery", stalkc="pale"),
    "lovage": dict(kind="umbels_lovage"),
    "chervil": dict(kind="umbels_chervil"),
    "anise": dict(kind="umbels_anise"),
    "wild-angelica": dict(kind="umbels_angelica"),
    "hogweed": dict(kind="umbels_hogweed"),
    "yarrow": dict(kind="umbels_yarrow"),
    "common-valerian": dict(kind="umbels_valerian"),
    "meadowsweet": dict(kind="umbels_meadowsweet", stalkc="rust"),
}


# ================================================================ life stages: shared pieces
DOTC = {"umbels_yellow": "unripe", "sun": "amber", "pear": "unripe", "white": "unripe", "pale": "unripe", "pink": "beet", "umbels_cream": "primrose"}


def soil(a, y=88, marks=True):
    a.ground(y, marks=marks)


def below(a, y0=40):
    """Soil flecks under the line, for the seed pictures."""
    for dx, dy, w in [(-30, 6, 4), (27, 10, 3), (-22, 40, 3), (30, 36, 4)]:
        a.line(f"M{50 + dx},{y0 + dy} L{50 + dx + w},{y0 + dy}", 0.9, 0.55, "soil")


def seed_stage(fn):
    def draw():
        a = Art(); a.ground(40, marks=False); below(a); fn(a, 50, 64); return a
    return draw


def stalk(a, p0, c, p1, w0, w1, col, ridges=0, lw=0.9):
    """A stem as a band that narrows upwards. ridges: faint lines along it."""
    q = a.ribbon(p0, c, p1, w0, w1, col, lw=lw)
    if ridges:
        for k in range(ridges):
            o = (k - (ridges - 1) / 2) / max(1, ridges) * 0.8
            pts = []
            for u in (0.03, 0.3, 0.6, 0.9):
                x, y = q.pt(u); g = math.radians(q.ang(u) + 90); w = (w0 + (w1 - w0) * u) / 2
                pts.append((x + o * w * math.cos(g), y + o * w * math.sin(g)))
            a.line(opath(pts), 0.4, 0.4)
    return q


def node_sheath(a, x, y, ang, L, W, fill, margin=None):
    """A leaf's sheath where it wraps the stem, on the whole plant."""
    with a.on(LEAF):
        sheath(a, x, y, ang, L, W, fill, margin=margin, lw=0.6)


def hairs_on(a, q, n=8, k=1.2, down=True):
    """Short stiff hairs along a stem (hogweed's point downwards)."""
    for i in range(n):
        u = 0.08 + 0.84 * i / max(1, n - 1); x, y = q.pt(u); g = q.ang(u)
        for sd in (1, -1):
            e = T(x, y, g + sd * (115 if down else 65))(k)
            a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.35, 0.7)


# ---- seeds, drawn large for the "seed" stage
def seed_winged(a, x, y, ang, L, W, body, wing="white", ribs=3, wingk=0.24, vittae=0):
    """A flat seed with a pale wing round it (dill, lovage, angelica,
    hogweed). vittae: hogweed's dark club-shaped lines from the top."""
    a.oval(x, y, L / 2, W / 2, ang, wing, 0.9)
    a.oval(x, y, L / 2 * (1 - wingk * 0.6), W / 2 * (1 - wingk), ang, body, 0.8)
    t = T(x, y, ang)
    for k in range(ribs):
        o = (k - (ribs - 1) / 2) * W * (1 - wingk) / (ribs + 0.6)
        a.line(f"M{P(t(-L * 0.36, o * 0.7))} Q{P(t(0, o * 1.05))} {P(t(L * 0.36, o * 0.7))}", 0.6, 0.5)
    for k in range(vittae):
        o = (k - (vittae - 1) / 2) * W * 0.18
        a.ribbon(t(L * 0.4, o), t(L * 0.2, o), t(L * 0.02, o * 1.2), 0.6, 1.6, "dark", lw=0)
    a.dot(*t(L * 0.5), 0.7, "bark")


def seed_ribbed(a, x, y, ang, L, W, body, ribc="white", ribs=5, beak=0.0, hairs=False, crown=False):
    """An oblong or egg-shaped seed with ribs along it (fennel, parsley,
    anise, celery). beak: a point at the tip (chervil); hairs: downy
    (anise); crown: a small crown of sepal teeth at the top (coriander)."""
    t = T(x, y, ang)
    a.oval(x, y, L / 2, W / 2, ang, body, 0.9)
    for k in range(ribs):
        o = (k - (ribs - 1) / 2) / ((ribs - 1) / 2 + 0.6) * W * 0.5
        sq = math.sqrt(max(0.05, 1 - (o / (W * 0.5)) ** 2))
        a.line(f"M{P(t(-L * 0.42 * sq, o))} Q{P(t(0, o * 1.08))} {P(t(L * 0.42 * sq, o))}", 0.9 if ribc == "white" else 0.6,
               1.0 if ribc == "white" else 0.5, ribc)
    if beak:
        a.ribbon(t(L * 0.45), t(L * (0.5 + beak * 0.5)), t(L * (0.5 + beak)), W * 0.3, W * 0.06, body, lw=0.8)
    if hairs:
        for k in range(16):
            h = 2 * math.pi * k / 16; p = t(L / 2 * math.cos(h), W / 2 * math.sin(h)); e = t(L / 2 * 1.13 * math.cos(h), W / 2 * 1.22 * math.sin(h))
            a.line(f"M{P(p)} L{P(e)}", 0.4, 0.7)
    if crown:
        tip = t(L * 0.5)
        for g in (-40, -15, 15, 40):
            a.line(f"M{P(tip)} L{P(T(*tip, ang + g)(L * 0.09))}", 0.6, 0.85)
    a.dot(*t(-L * 0.5), 0.6, "bark")


def seed_ball(a, x, y, r, body):
    """Coriander: a hard round ball, two halves joined, with fine wavy ribs
    and a small crown of sepal teeth at the top."""
    a.oval(x, y, r, r, 0, body, 0.95)
    for o in (-0.7, -0.35, 0, 0.35, 0.7):
        pts = [(x + o * r * math.sqrt(1 - v * v) + 0.25 * math.sin(v * 9) * r * 0.06, y + v * r * 0.95) for v in [i / 8 - 1 + 0.06 for i in range(0, 16)]]
        a.line(opath(pts), 0.45, 0.45)
    for g in (-125, -105, -75, -55):
        p = T(x, y, g)(r * 0.95); a.line(f"M{P(p)} L{P(T(*p, g)(r * 0.28))}", 0.6, 0.85)
    a.oval(x, y - r * 0.95, r * 0.14, r * 0.08, 0, "bark", 0.5)


def seed_parachute(a, x, y, body):
    """Valerian: a small flat seed with a feathery white parachute."""
    a.oval(x, y + 9, 3.6, 7.5, 0, body, 0.9)
    a.line(f"M{f(x)},{f(y + 4)} L{f(x)},{f(y + 14)}", 0.5, 0.45)
    top = (x, y + 1.6)
    for k in range(11):   # white feathery rays: drawn like dill's threads, but white
        g = -90 + (k - 5) * 15; e = T(*top, g)(19 - abs(k - 5) * 0.9)
        for v in (0.35, 0.55, 0.75, 0.92):   # the feathery side hairs
            b = T(*top, g)((19 - abs(k - 5) * 0.9) * v)
            for sd in (1, -1):
                thread(a, [b, T(*b, g + sd * 35)(2.4)], "white", 0.8, 0.45, la=0.45)
        thread(a, [top, e], "white", 1.2, 0.65, la=0.5)


def twist_ball(a, x, y, r, body, lw=0.8):
    """Meadowsweet's fruit: five to ten small seeds twisted together into a
    tight spiral ball. The outline bulges once for each seed; curved lines
    spiral in from each bulge to the middle."""
    n = 7
    a.polar(x, y, lambda h: 1 + 0.12 * math.cos(n * h), r, r, 0, body, lw)
    if r > 3:
        for k in range(n):
            g = 2 * math.pi * k / n + math.pi / n
            pts = [(x + r * (1 - v) * 0.95 * math.cos(g + 1.3 * v), y + r * (1 - v) * 0.95 * math.sin(g + 1.3 * v)) for v in (0.0, 0.3, 0.6, 0.9)]
            a.line(opath(pts), 0.5 if r > 6 else 0.4, 0.6)
    else:
        for k in range(3):
            g = 2 * math.pi * k / 3
            a.line(f"M{f(x)},{f(y)} Q{f(x + r * 0.6 * math.cos(g))},{f(y + r * 0.6 * math.sin(g))} {f(x + r * 0.9 * math.cos(g + 1.0))},{f(y + r * 0.9 * math.sin(g + 1.0))}", 0.35, 0.6)


def seed_spiral(a, x, y, body):
    """Meadowsweet's seed stage: two twisted seed balls, one with a single
    curved seed come loose beside it."""
    twist_ball(a, x - 5, y + 6, 11, body)
    twist_ball(a, x + 13, y - 1, 7.5, body)
    a.shape(f"M{f(x + 13)},{f(y + 16)} q4,-5 9,-2 q-3,1 -9,4 Z", body, 0.8)   # one seed, curved like a comma


# ---- seedlings
G = 72


def seedling_base(a, cot, col="pale", h=13, L=14):
    """The seed leaves on a short stem. cot: "needle" (dill, fennel: long
    and very narrow), "strap" (long and narrow), "oblong", "oval", "round"."""
    soil(a, G); a.roots(50, G, 3, 11, 50)
    sw = 2.0 if cot == "needle" else 1.5
    a.ribbon((50, G), (49.4, G - h * 0.5), (50, G - h), sw, sw * 0.8, "pale", lw=0.85)
    top = (50, G - h)
    b, LL = {"needle": (0.1, L * 1.5), "strap": (0.12, L * 1.15), "oblong": (0.22, L * 0.85), "oval": (0.36, L * 0.75),
             "round": (0.5, L * 0.55)}[cot]
    with a.on(LEAF):
        for sd in (-1, 1):
            a.leaf(*top, -90 + sd * (74 if cot != "round" else 66), LL, b, col, lw=0.95 if b < 0.2 else 1.0, detail=b >= 0.2)
    return top


def seedling(cot, first, h=13, L=14):
    """first(a, x, y): draws the first true leaf from the top of the stem."""
    def draw():
        a = Art(); top = seedling_base(a, cot, h=h, L=L)
        with a.on(LEAF):
            first(a, *top)
        return a
    return draw


# ---- umbels on the whole plant
def umbel_side(a, x, y, R, fc, style="star", rays=7, dome=0.0, uneven=0.0, bracts=None, pink=None, seed=None, seedc="straw",
               curl=0.0, keep=1.0, rayc="line", flat=0.0, capk=1.0):
    """A compound umbel on the whole plant, seen from the side: rays from
    one point up to a flat or domed top of small umbels.
      style  "dot" (small balls), "star" (small white flowers), "ragged"
             (with big outer petals on the outermost small umbels)
      seed   draw seeds instead of flowers: "flat" (winged discs), "rib"
             (oblong ribbed), "ball" (coriander), "egg" (small), "long"
             (chervil's long beaked seeds)
      keep   the share of small umbels still carrying seed (old heads)
      curl   the rays bending in as they stiffen in seed"""
    tips = []
    with a.on(BLOOM - 0.5):
        if bracts == "down":
            for g in (150, 120, 60, 30):
                a.line(f"M{f(x)},{f(y)} L{P(T(x, y, g)(R * 0.32))}", 0.5, 0.85)
        elif bracts == "small":
            for g in (150, 30):
                a.line(f"M{f(x)},{f(y)} L{P(T(x, y, g)(R * 0.22))}", 0.5, 0.85)
        for k in range(rays):
            u = k / (rays - 1) - 0.5 if rays > 1 else 0
            rf = 1 - uneven * rnd(k, 7.7)
            ex = x + u * 2 * R * (1 - curl * 0.35)
            ey = y - R * (0.62 + flat * 0.1) * rf - dome * R * 0.6 * (1 - (2 * u) ** 2) + (2 * u) ** 2 * R * (0.12 + dome * 0.15 - flat * 0.1)
            a.line(f"M{f(x)},{f(y)} Q{f(x + u * R * (0.9 - curl * 0.6))},{f(y - R * 0.3)} {f(ex)},{f(ey)}", 0.5, 0.85, rayc)
            tips.append((ex, ey, u))
    w = max(2.0, R * 2 / max(4, rays) * 0.78) * capk
    dc = DOTC.get(fc, "unripe")
    with a.on(BLOOM):
        for i, (ex, ey, u) in enumerate(sorted(tips, key=lambda q: -abs(q[2]))):
            if seed:
                if rnd(i, 4.4) > keep:
                    for g in (-120, -90, -60):
                        a.line(f"M{f(ex)},{f(ey)} L{P(T(ex, ey, g)(w * 0.6))}", 0.35, 0.7, rayc)
                    continue
                seeds_at(a, ex, ey, w, seed, seedc)
                continue
            for g in (-130, -90, -50):
                a.line(f"M{f(ex)},{f(ey)} L{P(T(ex, ey, g)(w * 0.5))}", 0.35, 0.6)
            col = pink if (pink and i % 3 == 1) else fc
            hcap = w * 0.95
            cap = [(ex + w * math.cos(h), ey - w * 0.25 - hcap * math.sin(h)) for h in [math.pi * i / 14 for i in range(15)]]
            cap += [(ex - w * math.cos(h) * 0.98, ey - w * 0.25 + w * 0.22 * math.sin(h)) for h in [math.pi * i / 6 for i in range(1, 6)]]
            a.shape(path(cap), col, 0.5)
            if style == "ragged" and abs(u) > 0.3:   # the big outer petals sticking out on the outside
                sd = 1 if u > 0 else -1
                for g in (-28, 18):
                    p0 = (ex + sd * w * 0.7, ey - w * 0.45)
                    notched_petal(a, *p0, (0 if sd > 0 else 180) + sd * g, w * 1.05, w * 0.85, col, 0.4)
            for j, (dx, dy) in enumerate(((-0.5, 0.35), (0, 0.4), (0.5, 0.35), (-0.25, 0.75), (0.25, 0.75))):
                a.dot(ex + dx * w, ey - w * 0.25 - hcap * dy, max(0.3, w * (0.14 if style == "dot" else 0.1)), dc)


def seeds_at(a, ex, ey, w, kind, col):
    """The seeds at the end of one ray of an umbel gone to seed."""
    w *= 1.3
    if kind == "long":   # chervil: long narrow beaked seeds in pairs, spread in a V
        for g in (-116, -64):
            t = T(ex, ey, g)
            a.oval(*t(w * 0.8), w * 0.8, w * 0.22, g, col, 0.4)
            a.line(f"M{P(t(w * 1.55))} L{P(t(w * 2.0))}", 0.45, 0.85)   # the short beak
        return
    if kind == "ball":   # coriander: round balls
        for dx, dy in ((-0.45, -0.5), (0.45, -0.5), (0, -1.1)):
            a.oval(ex + dx * w, ey + dy * w, w * 0.46, w * 0.46, 0, col, 0.45)
        return
    if kind == "flat":   # flat winged discs in pairs
        for dx, g in ((-0.42, -14), (0.42, 14)):
            a.oval(ex + dx * w, ey - w * 0.55, w * 0.42, w * 0.6, g, col, 0.45)
            a.line(f"M{f(ex + dx * w)},{f(ey - w * 0.9)} L{f(ex + dx * w)},{f(ey - w * 0.2)}", 0.35, 0.4)
        return
    if kind == "rib":   # fennel: oblong ribbed seeds, upright in pairs
        for dx, g in ((-0.36, -10), (0.36, 10)):
            a.oval(ex + dx * w, ey - w * 0.6, w * 0.3, w * 0.62, g, col, 0.4)
            a.line(f"M{f(ex + dx * w)},{f(ey - w * 1.1)} L{f(ex + dx * w)},{f(ey - w * 0.15)}", 0.35, 0.5, "white")
        return
    # "egg": small egg-shaped seeds
    for dx, dy in ((-0.4, -0.4), (0.4, -0.45), (0, -0.95)):
        a.oval(ex + dx * w, ey + dy * w, w * 0.3, w * 0.4, dx * 30, col, 0.45)


GREENS = {"leaf": "straw", "deep": "straw", "sage": "straw", "pale": "straw", "unripe": "bark", "pear": "straw",
          "mauve": "straw", "plum": "bark", "rust": "bark", "pink": "straw", "white": "white"}


def wither(a, i0=0, i1=None):
    """Turns every mark drawn between i0 and i1 (all, if left out) dead:
    green fills become straw or brown, and dark green outlines dark brown.
    Used for everything gone to seed and for dead winter stems, so no
    green is left on a dead plant. (Added after the independent check:
    stems and rays had stayed green in the seed heads.)"""
    i1 = len(a.items) if i1 is None else i1
    for i in range(i0, i1):
        it = a.items[i]
        if it[0] == "dot":
            _, x, y, r, fill = it
            a.items[i] = ("dot", x, y, r, GREENS.get(fill, fill))
        else:
            _, d, fill, lw, la, col, fa = it
            if fill in GREENS:
                fill = GREENS[fill]
            if col == "line":
                col = "dark"
            a.items[i] = ("path", d, fill, lw, la, col, fa)


def plant_group(fn, dry=False):
    """Wraps a drawing so that stems go behind leaves, and leaves behind
    flowers, however they were drawn. dry: the whole plant has gone to
    seed, so it is withered (see wither) once drawn."""
    def draw():
        a = Art()
        with a.group():
            fn(a)
        if dry:
            wither(a)
        return a
    return draw


def leaves_on(a, q, nodes, fn, fill, sheathc=None, margin=None, opp=False, sw=2.4):
    """Leaves up a stem: nodes is a list of (u, side, L, lean): where along
    the stem, which side, how long, and how far from upright (degrees).
    sheathc: draw a sheath at each node. opp: in opposite pairs."""
    for u, sd, L, lean in nodes:
        x, y = q.pt(u); g0 = q.ang(u)
        for s2 in ((1, -1) if opp else (sd,)):
            g = g0 + s2 * lean
            with a.on(LEAF):
                fn(a, x, y, g, L, fill, True)
                if sheathc:
                    sheath(a, x, y, g, max(2.6, L * 0.14), sw, sheathc, margin=margin, lw=0.55)


def crown(a, fn, x, y, leaves, fill, sheathc=None, margin=None):
    """Leaves rising from one crown on the ground: (angle, length) each."""
    with a.on(LEAF):
        for g, L in leaves:
            fn(a, x, y, g, L, fill, True)
        if sheathc:
            for g, L in leaves:
                sheath(a, x, y, g, max(3, L * 0.12), 3.0, sheathc, margin=margin, lw=0.55)


def dead_stem(a, x, y, H, lean=0.0, w=2.6, col="bark", broken=False):
    """A dead, hollow stem left standing in winter."""
    top = (x + lean, y - H)
    w = max(w, 3.2)   # thinner than this and the outline hides the brown
    q = stalk(a, (x, y), (x + lean * 0.3, y - H * 0.5), top, w, w * 0.75, col, ridges=1, lw=0.65)
    if broken:   # snapped: the hollow end
        a.oval(top[0], top[1], w * 0.32, w * 0.16, 0, "dark", 0.5)
    return q


# ---------------------------------------------------------------- dill
def dill_seed(a, x, y):
    seed_winged(a, x - 6, y + 2, -20, 26, 17, pal("dill", "fruit", "seed"), "white", ribs=3, wingk=0.26)
    seed_winged(a, x + 12, y - 5, 30, 20, 13, pal("dill", "fruit", "seed"), "white", ribs=3, wingk=0.26)


def threads_first(fill, fen=False):
    """The first true leaf of dill or fennel: already cut into threads,
    drawn with strokes heavy enough to read on a phone. Fennel's threads
    are longer and fewer, dill's shorter and forked."""
    def first(a, x, y):
        e = (x + 0.8, y - 10)
        thread(a, [(x, y), (x + 0.2, y - 5), e], fill, 1.7, 0.85)
        if fen:
            for g in (-160, -128, -100, -76, -46, -18):
                thread(a, [e, T(*e, g + 6)(7), T(*e, g)(15)], fill, 1.4, 0.68)
            return
        for g in (-150, -115, -90, -65, -30):
            m = T(*e, g)(7); thread(a, [e, m], fill, 1.4, 0.68)
            for o in (-28, 28):
                thread(a, [m, T(*m, g + o)(5.5)], fill, 1.3, 0.62)
    return first


def dill_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("dill", "leaf", "sage"); sc = "straw" if dry else "sage"
        soil(a, 88)
        H = {"young": 46, "crop": 72, "flower": 76, "seedhead": 76}[stage]
        q = stalk(a, (50, 88), (51.5, 88 - H * 0.5), (50, 88 - H), 2.2 if stage == "young" else 2.6, 1.1, sc, ridges=2)
        if stage == "young":
            nodes = [(0.1, 1, 30, 52), (0.32, -1, 27, 50), (0.55, 1, 22, 44), (0.78, -1, 15, 36)]
        else:
            nodes = [(0.07, 1, 32, 56), (0.22, -1, 30, 54), (0.38, 1, 26, 50), (0.54, -1, 21, 46), (0.7, 1, 16, 40)]
            if stage == "crop":
                nodes += [(0.86, -1, 12, 32)]
        leaves_on(a, q, nodes, leaf_dill, lc, sheathc=lc, margin="white" if not dry else None, sw=2.2)
        if stage in ("flower", "seedhead"):
            fc = pal("dill", "flower", "sun")
            kw = dict(style="dot", uneven=0.25) if not dry else dict(seed="flat", seedc=pal("dill", "fruit", "seed"), rayc="line")
            for u, sd, R in ((0.62, -1, 9.5), (0.78, 1, 8)):
                x, y = q.pt(u); e = (x + sd * 15, y - 13)
                a.stem((x, y), (x + sd * 6, y - 2), e, 0.9)
                umbel_side(a, *e, R, fc, rays=7, **kw)
            umbel_side(a, *q.pt(1), 16, fc, rays=11, **kw)
        else:
            x, y = q.pt(1)
            with a.on(LEAF):
                leaf_dill(a, x, y, -90, 10, lc, True)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- fennel
def fennel_seed(a, x, y):
    c = pal("fennel", "fruit", "seed")
    seed_ribbed(a, x - 7, y + 1, -70, 30, 11, c, ribc="white", ribs=5)
    seed_ribbed(a, x + 9, y + 2, -100, 28, 10.5, c, ribc="white", ribs=5)


def fennel_plant(stage):
    def fn(a):
        dry = stage in ("seedhead", "dormant")
        lc = "straw" if dry else pal("fennel", "leaf", "sage"); sc = ("bark" if stage == "dormant" else "straw") if dry else "sage"
        soil(a, 88)
        if stage == "young":   # a clump of plumes from the ground, broad sheaths at their feet
            crown(a, leaf_fennel, 50, 87, [(-140, 38), (-40, 38), (-108, 46), (-72, 46)], lc, sheathc=lc, margin="white")
            return
        if stage == "dormant":
            i0 = len(a.items)
            for dx, H, lean, br in ((-9, 62, -4, False), (4, 70, 3, False), (14, 44, 6, True), (-2, 36, -2, True)):
                q = dead_stem(a, 50 + dx, 88, H, lean, 3.2, broken=br)
                if not br:
                    umbel_side(a, *q.pt(1), 9, "straw", rays=7, seed="rib", seedc="bark", keep=0.45, curl=0.3, rayc="line")
            wither(a, i0)
            crown(a, leaf_fennel, 50, 87, [(-140, 10), (-40, 10), (-100, 12), (-70, 11)], pal("fennel", "leaf", "sage"))
            return
        stems = [(-8, 62 if stage == "crop" else 64, -12), (8, 58 if stage == "crop" else 60, 12), (0, 68 if stage == "crop" else 72, 0)]
        qs = []
        for dx, H, lean in stems:
            q = stalk(a, (50 + dx * 0.3, 88), (50 + dx * 0.5 + lean * 0.2, 88 - H * 0.5), (50 + dx + lean, 88 - H), 2.6, 1.2, sc, ridges=2)
            qs.append((q, lean))
            nodes = [(0.18, 1, 30, 54), (0.38, -1, 26, 52), (0.58, 1, 21, 48)]
            if stage == "crop":
                nodes += [(0.78, -1, 17, 40), (0.92, 1, 12, 30)]
            nodes = [(u, sd if lean <= 0 else -sd, L, lg) for u, sd, L, lg in nodes]
            leaves_on(a, q, nodes, leaf_fennel, lc, sheathc=lc, margin="white" if not dry else None, sw=2.6)
        crown(a, leaf_fennel, 50, 87, [(-158, 26), (-22, 26), (-138, 30), (-42, 30)], lc, sheathc=lc, margin="white" if not dry else None)
        if stage in ("flower", "seedhead"):
            fc = pal("fennel", "flower", "sun")
            kw = dict(style="dot") if not dry else dict(seed="rib", seedc=pal("fennel", "fruit", "seed"))
            for q, lean in qs:
                x, y = q.pt(0.8); sd = 1 if lean >= 0 else -1
                if lean == 0:
                    sd = -1
                e = (x + sd * 11, y - 9)
                a.stem((x, y), (x + sd * 5, y - 2), e, 0.9)
                umbel_side(a, *e, 7, fc, rays=7, **kw)
                umbel_side(a, *q.pt(1), 9.5, fc, rays=8, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- coriander
def coriander_seed(a, x, y):
    c = pal("coriander", "fruit", "straw")
    for dx, dy, r in ((-10, 4, 9), (8, -4, 10), (6, 13, 7.5)):
        seed_ball(a, x + dx, y + dy, r, c)


def round_first(kind, fill):
    """A first true leaf on a short stalk: rounded and lobed, toothed."""
    def first(a, x, y):
        e = (x + 1, y - 7)
        a.line(f"M{f(x)},{f(y)} Q{f(x - 0.4)},{f(y - 4)} {P(e)}", 0.8, 0.85)
        if kind == "coriander":
            fan_leaflet(a, *e, -92, 11, fill, S=80, cx=0.48, ax=0.52, ay=0.6, lobes=3, sinus=0.2, teeth=2, td=0.9, tk="round", lw=0.8, veins=True)
        elif kind == "kidney":   # anise, meadowsweet: round, toothed all round
            fan_leaflet(a, *e, -90, 10, fill, S=140, cx=0.44, ax=0.52, ay=0.6, lobes=5, sinus=0.06, teeth=2, td=0.8, tk="saw", lw=0.8, veins=True, lobespan=0.62)
        elif kind == "hogweed":   # rounded, lobed, hairy
            fan_leaflet(a, *e, -90, 12, fill, S=130, cx=0.44, ax=0.52, ay=0.62, lobes=5, sinus=0.3, notchw=0.6, teeth=1, td=1.0, tk="saw",
                        lw=0.8, veins=True, lobespan=0.7, hairs=8)
        else:   # three-lobed and toothed: parsley, celery, lovage, angelica
            fan_leaflet(a, *e, -90, 11, fill, S=62, cx=0.5, ax=0.5, ay=0.6, lobes=3, sinus=0.4, notchw=0.7, teeth=2, td=0.9, tk="saw", lw=0.8, veins=True)
    return first


def coriander_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("coriander", "leaf", "leaf")
        soil(a, 88)
        if stage in ("young", "crop"):
            big = stage == "crop"
            ls = [(-160, 26), (-20, 26), (-135, 31), (-45, 31), (-110, 34), (-70, 34), (-90, 30)] if big else \
                 [(-150, 20), (-30, 20), (-118, 24), (-62, 24), (-90, 22)]
            crown(a, leaf_coriander, 50, 87, ls, lc)
            return
        crown(a, leaf_coriander, 50, 87, [(-165, 18), (-15, 18), (-140, 20)], lc)
        q = stalk(a, (50, 88), (50.5, 58), (51, 20), 2.0, 1.1, "straw" if dry else "leaf", ridges=1)
        fine = lambda a_, x, y, g, L, c, sm: anise_upper(a_, x, y, g, L, c, True)
        leaves_on(a, q, [(0.2, -1, 20, 52), (0.36, 1, 18, 50), (0.52, -1, 16, 46), (0.7, 1, 13, 40), (0.84, -1, 10, 34)], fine, lc)
        fc = pal("coriander", "flower", "white")
        kw = dict(style="ragged", rays=4, capk=0.85) if not dry else dict(seed="ball", seedc=pal("coriander", "fruit", "straw"), rays=4, capk=0.85)
        heads = [(0.5, 1, (70, 34)), (0.66, -1, (31, 30)), (0.8, 1, (64, 22))]
        for u, sd, e in heads:
            x, y = q.pt(u); a.stem((x, y), ((x + e[0]) / 2, y - 6), e, 0.8)
            umbel_side(a, *e, 5.5, fc, **kw)
        umbel_side(a, *q.pt(1), 6, fc, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- parsley
def parsley_seed(a, x, y):
    c = pal("parsley", "fruit", "bark")
    for dx, dy, g in ((-9, 2, -60), (6, -4, -110), (4, 11, -20)):
        seed_ribbed(a, x + dx, y + dy, g, 17, 11, c, ribc="white", ribs=5)


def parsley_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("parsley", "leaf", "deep")
        soil(a, 88)
        if stage == "young":
            crown(a, leaf_parsley, 50, 87, [(-128, 38), (-52, 38), (-104, 44), (-76, 44)], lc)
            return
        if stage == "crop":
            crown(a, leaf_parsley, 50, 87, [(-152, 44), (-28, 44), (-126, 54), (-54, 54), (-104, 60), (-76, 60), (-90, 52)], lc)
            return
        crown(a, leaf_parsley, 50, 87, [(-160, 26), (-20, 26), (-135, 30), (-45, 30)], lc)
        q = stalk(a, (50, 88), (51.5, 58), (50, 26), 2.8, 1.4, "straw" if dry else "leaf", ridges=2)
        leaves_on(a, q, [(0.3, -1, 16, 52), (0.55, 1, 13, 46)], leaf_parsley, lc)
        fc = pal("parsley", "flower", "pear")
        kw = dict(style="dot", bracts="small") if not dry else dict(seed="egg", seedc=pal("parsley", "fruit", "bark"))
        for u, sd in ((0.55, -1), (0.72, 1)):
            x, y = q.pt(u); e = (x + sd * 19, y - 14)
            a.stem((x, y), (x + sd * 8, y - 3), e, 0.9)
            umbel_side(a, *e, 9.5, fc, rays=7, **kw)
        umbel_side(a, *q.pt(1), 12.5, fc, rays=9, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- chervil
def chervil_seed(a, x, y):
    c = pal("chervil", "fruit", "dark")
    seed_ribbed(a, x - 6, y + 2, -76, 34, 7, c, ribc="line", ribs=1, beak=0.22)
    seed_ribbed(a, x + 7, y + 3, -100, 32, 7, c, ribc="line", ribs=1, beak=0.22)


def chervil_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("chervil", "leaf", "leaf")
        soil(a, 88)
        if stage in ("young", "crop"):
            ls = [(-150, 24), (-30, 24), (-118, 28), (-62, 28), (-90, 26)] if stage == "young" else \
                 [(-165, 30), (-15, 30), (-140, 36), (-40, 36), (-115, 40), (-65, 40), (-90, 38)]
            crown(a, leaf_chervil, 50, 87, ls, lc)
            return
        # in flower: under 60 cm, so the plant stops well short of the top of the picture
        crown(a, leaf_chervil, 50, 87, [(-160, 24), (-20, 24), (-138, 26), (-42, 26)], lc)
        q = stalk(a, (50, 88), (51, 66), (49, 40), 2.0, 1.2, "straw" if dry else "leaf", ridges=1)
        b1 = a.stem(q.pt(0.42), (38, 60), (28, 50), 1.0)
        b2 = a.stem(q.pt(0.6), (62, 56), (72, 46), 1.0)
        fc = pal("chervil", "flower", "white")
        kw = dict(style="star", rays=4) if not dry else dict(seed="long", seedc=pal("chervil", "fruit", "dark"), rays=4)
        # small umbels on very short stalks at the leaf joints, each opposite a leaf;
        # the stems end in leaves, not in umbels held up clear of the plant
        for qq, u, sd in ((q, 0.42, 1), (q, 0.6, -1), (q, 0.82, 1), (b1, 0.55, -1), (b2, 0.55, 1)):
            x, y = qq.pt(u)
            with a.on(LEAF):
                leaf_chervil(a, x, y, -90 + sd * 62, 14, lc, True)
            umbel_side(a, x - sd * 2.0, y - 1.5, 5, fc, **kw)
        with a.on(LEAF):
            for qq, g in ((q, -90), (b1, -140), (b2, -40)):
                leaf_chervil(a, *qq.pt(1), g, 11, lc, True)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- anise
def anise_seed(a, x, y):
    c = pal("anise", "fruit", "seed")
    seed_ribbed(a, x - 7, y + 2, -65, 20, 13, c, ribc="line", ribs=5, hairs=True)
    seed_ribbed(a, x + 9, y - 2, -105, 19, 12.5, c, ribc="line", ribs=5, hairs=True)


def anise_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("anise", "leaf", "leaf")
        soil(a, 88)
        if stage == "young":
            crown(a, anise_basal, 50, 87, [(-160, 24), (-20, 24), (-130, 26), (-50, 26)], lc)
            q = stalk(a, (50, 88), (50.5, 74), (51, 56), 1.8, 1.2, "leaf", ridges=0)
            leaves_on(a, q, [(0.55, -1, 13, 50), (0.85, 1, 11, 40)], anise_upper, lc)
            leaves_on(a, q, [(0.25, 1, 14, 58)], anise_middle, lc)
            return
        crown(a, anise_basal, 50, 87, [(-165, 22), (-15, 22), (-140, 24)], lc)
        q = stalk(a, (50, 88), (51, 60), (50, 26), 2.2, 1.2, "straw" if dry else "leaf", ridges=1)
        leaves_on(a, q, [(0.15, 1, 16, 58)], anise_middle, lc)
        leaves_on(a, q, [(0.38, -1, 15, 52), (0.6, 1, 12, 46), (0.78, -1, 9, 40)], anise_upper, lc)
        fc = pal("anise", "flower", "white")
        kw = dict(style="star") if not dry else dict(seed="egg", seedc=pal("anise", "fruit", "seed"))
        for u, sd in ((0.6, 1), (0.78, -1)):
            x, y = q.pt(u); e = (x + sd * 17, y - 12)
            a.stem((x, y), (x + sd * 7, y - 3), e, 0.8)
            umbel_side(a, *e, 8.5, fc, rays=8, **kw)
        umbel_side(a, *q.pt(1), 11, fc, rays=9, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- lovage
def lovage_seed(a, x, y):
    c = pal("lovage", "fruit", "bark")
    for dx, dy, g in ((-8, 2, -66), (9, 0, -112)):   # oblong (about 2 to 1), the ribs edged with narrow pale wings
        a.oval(x + dx, y + dy, 16, 8, g, "straw", 0.9)
        seed_ribbed(a, x + dx, y + dy, g, 29, 13, c, ribc="white", ribs=5)


def lovage_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("lovage", "leaf", "deep")
        soil(a, 88)
        if stage == "dormant":   # dead stems, and red shoots pushing up at the crown in late winter
            i0 = len(a.items)
            dead_stem(a, 44, 88, 30, -3, 3.2, broken=True); dead_stem(a, 55, 88, 22, 2, 3.0, broken=True)
            wither(a, i0)
            a.polar(50, 90, lambda h: 1 + 0.06 * math.cos(5 * h), 9, 3.4, 0, "bark", 0.8)
            with a.on(LEAF):
                for dx, hh, g in ((-5, 13, -104), (0, 17, -88), (5, 12, -72)):
                    a.ribbon((50 + dx, 88), (50 + dx * 1.1, 88 - hh * 0.5), T(50 + dx, 88, g)(hh), 3.4, 1.2, "rust", lw=0.75, round_tip=True)
                    e = T(50 + dx, 88, g)(hh)
                    for o in (-34, 30):   # the first leaflets unfolding, crumpled and red-bronze
                        a.leaf(*e, g + o, 5, 0.5, "rust", lw=0.65, detail=False)
            return
        if stage in ("young", "crop"):
            ls = [(-140, 50), (-40, 50), (-92, 58)] if stage == "young" else \
                 [(-162, 50), (-18, 50), (-128, 60), (-52, 60), (-90, 66)]
            crown(a, leaf_lovage, 50, 87, ls, lc, sheathc=lc)
            return
        crown(a, leaf_lovage, 50, 87, [(-165, 32), (-15, 32), (-140, 34), (-40, 34)], lc, sheathc=lc)
        sc = "straw" if dry else "leaf"
        q = stalk(a, (50, 88), (52, 50), (50, 14), 4.2, 2.2, sc, ridges=3)
        leaves_on(a, q, [(0.36, -1, 25, 56), (0.58, 1, 19, 50)], leaf_lovage, lc, sheathc=lc, sw=3.4)
        fc = pal("lovage", "flower", "pear")
        kw = dict(style="dot", bracts="down", dome=0.5) if not dry else dict(seed="flat", seedc=pal("lovage", "fruit", "bark"), dome=0.4)
        for u, sd in ((0.62, -1), (0.76, 1)):
            x, y = q.pt(u); e = (x + sd * 21, y - 13)
            a.stem((x, y), (x + sd * 9, y - 3), e, 1.1)
            umbel_side(a, *e, 9.5, fc, rays=8, **kw)
        umbel_side(a, *q.pt(1), 12.5, fc, rays=10, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- celery
def celery_seed(a, x, y):
    c = pal("celery", "fruit", "bark")
    for dx, dy, g in ((-11, 3, -60), (0, -5, -100), (10, 4, -30), (-2, 10, -80), (12, -7, -120)):
        seed_ribbed(a, x + dx, y + dy, g, 9.5, 7.5, c, ribc="white", ribs=3)


def celery_plant(stage):
    def fn(a):
        dry = stage == "seedhead"
        lc = "straw" if dry else pal("celery", "leaf", "leaf")
        soil(a, 88)
        cel = lambda a_, x, y, g, L, c, sm: leaf_celery(a_, x, y, g, L, c, sm, stalkc="straw" if dry else "pale")
        if stage == "young":
            crown(a, cel, 50, 87, [(-128, 40), (-52, 40), (-108, 46), (-72, 46), (-90, 44)], lc)
            return
        if stage == "crop":   # a tight upright bunch of thick pale stalks, the leaves only at the top
            crown(a, cel, 50, 87, [(-112, 70), (-68, 70), (-104, 76), (-76, 76), (-97, 80), (-83, 80), (-90, 78)], lc)
            a.polar(50, 86.5, lambda h: 1, 7.5, 2.2, 0, "pale", 0.8)
            return
        crown(a, cel, 50, 87, [(-150, 34), (-30, 34), (-120, 36), (-60, 36)], lc)
        q = stalk(a, (50, 88), (51, 58), (50, 24), 2.8, 1.4, "straw" if dry else "leaf", ridges=2)
        b1 = a.stem(q.pt(0.5), (40, 50), (30, 38), 1.0); b2 = a.stem(q.pt(0.7), (60, 44), (70, 34), 1.0)
        fc = pal("celery", "flower", "pale")
        kw = dict(style="star", rays=5) if not dry else dict(seed="egg", seedc=pal("celery", "fruit", "bark"), rays=5)
        small_leaf = lambda a_, x, y, g, L, c, sm: leaf_celery(a_, x, y, g, L, c, True, stalkc=c)
        for qq, u, sd in ((q, 0.5, 1), (q, 0.7, -1), (b1, 0.55, -1), (b2, 0.55, 1)):
            x, y = qq.pt(u)
            with a.on(LEAF):
                small_leaf(a, x, y, -90 + sd * 60, 15, lc, True)
            umbel_side(a, x - sd * 2.5, y - 3, 6, fc, **kw)   # small umbels close to the leaves, on short stalks
        for qq in (q, b1, b2):
            umbel_side(a, *qq.pt(1), 7, fc, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- wild angelica
def angelica_seed(a, x, y):
    c = pal("wild-angelica", "fruit", "straw")
    seed_winged(a, x - 7, y + 2, -70, 26, 20, c, "white", ribs=3, wingk=0.36)
    seed_winged(a, x + 10, y - 2, -112, 24, 18, c, "white", ribs=3, wingk=0.36)


def angelica_plant(stage):
    def fn(a):
        dry = stage in ("seedhead", "dormant")
        lc = "straw" if dry else pal("wild-angelica", "leaf", "leaf")
        soil(a, 88)
        if stage == "young":
            crown(a, leaf_angelica, 50, 87, [(-142, 50), (-38, 50), (-92, 60)], lc)
            return
        if stage == "dormant":   # dead hollow stems, nothing green, old heads with a few seeds
            i0 = len(a.items)
            for dx, H, lean in ((-6, 72, -5), (7, 60, 5)):
                q = dead_stem(a, 50 + dx, 88, H, lean, 3.4)
                umbel_side(a, *q.pt(1), 15 if H > 65 else 12, "straw", rays=9, seed="flat", seedc="straw", keep=0.45, dome=0.5, curl=0.2)
            dead_stem(a, 44, 88, 18, -6, 2.8, broken=True)
            wither(a, i0)
            return
        crown(a, leaf_angelica, 50, 87, [(-162, 30), (-18, 30), (-135, 34), (-45, 34)], lc)
        sc = "plum"
        q = stalk(a, (50, 88), (52, 54), (50, 24), 4.0, 2.0, sc, ridges=0)
        for u in (0.12, 0.4, 0.7):   # the whitish bloom on the stem
            x, y = q.pt(u); a.line(f"M{f(x - 0.6)},{f(y + 3)} L{f(x - 0.7)},{f(y - 4)}", 0.9, 0.5, "white")
        for u, sd, L in ((0.34, -1, 25), (0.56, 1, 19)):
            x, y = q.pt(u); g = -90 + sd * 50
            with a.on(LEAF):
                leaf_angelica(a, *T(x, y, g)(5), g, L, lc, True)
                inflated(a, x, y, g, 8, 5, "plum", lw=0.6)   # the inflated pouch
        fc = pal("wild-angelica", "flower", "white")
        kw = dict(style="star", dome=0.9, pink="pink", capk=1.3) if not dry else dict(seed="flat", seedc=pal("wild-angelica", "fruit", "straw"), dome=0.7)
        for u, sd in ((0.6, -1), (0.74, 1)):
            x, y = q.pt(u); e = (x + sd * 21, y - 12)
            stalk(a, (x, y), (x + sd * 9, y - 3), e, 1.6, 1.0, sc)
            umbel_side(a, *e, 10, fc, rays=9, **kw)
            with a.on(LEAF):
                inflated(a, x, y, -90 + sd * 40, 6.5, 4.2, "plum", lw=0.55)
        umbel_side(a, *q.pt(1), 13, fc, rays=11, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- hogweed
def hogweed_seed(a, x, y):
    c = pal("hogweed", "fruit", "straw")
    seed_winged(a, x - 8, y + 2, -80, 28, 24, c, "white", ribs=0, wingk=0.14, vittae=3)
    seed_winged(a, x + 11, y - 2, -100, 25, 21, c, "white", ribs=0, wingk=0.14, vittae=2)


def hogweed_plant(stage):
    def fn(a):
        dry = stage in ("seedhead", "dormant")
        lc = "straw" if dry else pal("hogweed", "leaf", "leaf")
        soil(a, 88)
        if stage == "young":
            crown(a, leaf_hogweed, 50, 87, [(-150, 36), (-30, 36), (-118, 44), (-62, 44), (-90, 40)], lc, sheathc=lc)
            return
        if stage == "dormant":
            i0 = len(a.items)
            for dx, H, lean in ((-5, 74, -4), (8, 58, 6)):
                q = dead_stem(a, 50 + dx, 88, H, lean, 4.0)
                umbel_side(a, *q.pt(1), 13 if H > 65 else 10, "straw", rays=9, seed="flat", seedc="straw", keep=0.55, curl=0.15)
            wither(a, i0)
            crown(a, leaf_hogweed, 50, 87, [(-160, 16), (-25, 14)], pal("hogweed", "leaf", "leaf"))
            return
        crown(a, leaf_hogweed, 50, 87, [(-160, 30), (-20, 30), (-132, 34), (-48, 34)], lc, sheathc=lc)
        sc = "straw" if dry else "leaf"
        q = stalk(a, (50, 88), (52, 52), (50, 18), 4.6, 2.6, sc, ridges=3)
        hairs_on(a, q, 12, 1.5)
        leaves_on(a, q, [(0.35, 1, 18, 56)], leaf_hogweed, lc, sheathc=lc, sw=4.4)
        fc = pal("hogweed", "flower", "white")
        kw = dict(style="ragged", flat=1.0, capk=1.6) if not dry else dict(seed="flat", seedc=pal("hogweed", "fruit", "straw"), flat=1.0, capk=1.3)
        x, y = q.pt(0.62); e = (x - 22, y - 14)
        b = stalk(a, (x, y), (x - 9, y - 3), e, 2.0, 1.4, sc); hairs_on(a, b, 4, 1.1)
        umbel_side(a, *e, 10.5, fc, rays=7, **kw)
        umbel_side(a, *q.pt(1), 17, fc, rays=11, **kw)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- yarrow
def yarrow_seed(a, x, y):
    c = pal("yarrow", "fruit", "bark")
    for dx, dy, g in ((-10, 3, -70), (2, -5, -100), (11, 4, -40), (-1, 10, -15)):
        a.oval(x + dx, y + dy, 6.5, 2.6, g, c, 0.9)
        a.oval(x + dx, y + dy, 5.0, 1.1, g, "straw", 0, la=0)   # the pale flat margin
    a.dot(x - 10, y + 3, 0.5, "dark")


def corymb_side(a, x, y, R, fc, cen, dry=False):
    """Yarrow's flat-topped cluster from the side: stalks branching at
    several heights up to a flat top of many tiny white heads with cream
    middles (or, dry, small brown heads)."""
    top = y - R * 1.5
    heads = [(x + (k / 10 - 0.5) * 2 * R, top - (1 - ((k / 10 - 0.5) * 2) ** 2) * R * 0.08) for k in range(11)]
    with a.on(BLOOM - 0.5):
        corymb_tree(a, (x, y), heads, top, lw=0.55)
    with a.on(BLOOM):
        hr = max(1.3, R * 0.15)
        for i, (px, py) in enumerate(heads):
            for dy in ((0.0,) if i % 2 else (0.0, -1.0)):
                qy = py + dy * hr * 1.1
                if dry:
                    a.oval(px, qy - hr * 0.5, hr * 0.95, hr * 0.62, 0, pal("yarrow", "fruit", "bark"), 0.4)
                    a.dot(px, qy - hr * 0.6, hr * 0.28, "dark")
                else:
                    a.oval(px, qy - hr * 0.5, hr * 1.05, hr * 0.7, 0, fc, 0.4)
                    a.dot(px, qy - hr * 0.6, hr * 0.38, cen)


def yarrow_plant(stage):
    def fn(a):
        lc = pal("yarrow", "leaf", "deep")
        soil(a, 88)
        if stage == "young":
            crown(a, leaf_yarrow, 50, 87, [(-150, 30), (-30, 30), (-124, 38), (-56, 38), (-104, 42), (-78, 42)], lc)
            return
        if stage == "dormant":   # green feathery leaves stay; dead brown stems with flat heads
            i0 = len(a.items)
            for dx, H, lean in ((-7, 56, -5), (8, 50, 5)):
                q = dead_stem(a, 50 + dx, 88, H, lean, 1.8)
                corymb_side(a, *q.pt(0.85), 9, "straw", "straw", dry=True)
            wither(a, i0)
            crown(a, leaf_yarrow, 50, 87, [(-160, 20), (-20, 20), (-130, 24), (-50, 24), (-95, 22)], lc)
            return
        dry = stage == "seedhead"
        sc = "straw" if dry else "leaf"; flc = "straw" if dry else lc
        crown(a, leaf_yarrow, 50, 87, [(-162, 22), (-18, 22), (-138, 26), (-42, 26)], flc)
        for dx, H, lean in ((-10, 60, -8), (10, 56, 8), (0, 68, 0)):
            q = stalk(a, (50 + dx * 0.3, 88), (50 + dx * 0.6, 88 - H * 0.5), (50 + dx + lean, 88 - H), 1.9, 1.3, sc)
            leaves_on(a, q, [(0.25, 1, 11, 50), (0.45, -1, 10, 46), (0.65, 1, 8, 40)], leaf_yarrow, flc)
            corymb_side(a, *q.pt(0.8), 12, pal("yarrow", "flower", "white"), pal("yarrow", "centre", "straw"), dry=dry)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- common valerian
def valerian_seed(a, x, y):
    seed_parachute(a, x - 9, y - 2, pal("common-valerian", "fruit", "straw"))
    seed_parachute(a, x + 11, y + 1, pal("common-valerian", "fruit", "straw"))


def little_cluster(a, x, y, r, fc, seed=False):
    """One rounded cluster of valerian flowers on the whole plant: a small
    pink dome with a few tiny five-lobed flowers and stamens on it; in
    seed, a white fluffy ball of feathery parachutes."""
    if seed:
        for k in range(11):
            g = -175 + k * 17; e = T(x, y + r * 0.3, g)(r * 1.3)
            thread(a, [(x, y + r * 0.3), e], "white", 0.95, 0.5, la=0.5)
        a.dot(x, y + r * 0.3, max(0.4, r * 0.2), pal("common-valerian", "fruit", "straw"))
        return
    dm = [(x + r * math.cos(h), y - r * 0.85 * math.sin(h)) for h in [math.pi * i / 12 for i in range(13)]]
    dm += [(x - r * math.cos(h), y + r * 0.25 * math.sin(h)) for h in [math.pi * i / 6 for i in range(1, 6)]]
    a.shape(path(dm), fc, 0.5)
    for dx, dy in ((-0.45, -0.3), (0.45, -0.3), (0, -0.6)):
        a.flower(x + dx * r, y + dy * r, max(1.0, r * 0.32), 5, fc, None, 0.7, lw=0.35)
        a.dot(x + dx * r, y + dy * r, 0.3, "white")
    for g in (-120, -90, -60):
        p0 = T(x, y - r * 0.5, g)(r * 0.5); a.line(f"M{P(p0)} L{P(T(*p0, g)(r * 0.35))}", 0.3, 0.7)


def cyme_side(a, x, y, R, fc, seed=False):
    """Valerian's head on the whole plant: the stem branches in opposite
    pairs at two levels, every branch ending in a small rounded cluster,
    the clusters together making a loose dome."""
    tips = [(x, y - R * 1.1, 1.0)]
    with a.on(BLOOM - 0.5):
        a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y - R * 1.05)}", 0.7, 0.85)
        for v, dx, h, k in ((0.0, 0.95, 0.75, 0.8), (0.45, 0.55, 0.95, 0.85)):
            b0 = (x, y - R * v)
            for sd in (1, -1):
                e = (x + sd * dx * R, y - R * h)
                a.line(f"M{P(b0)} Q{f(x + sd * dx * R * 0.5)},{f(b0[1] - R * 0.1)} {P(e)}", 0.6, 0.85)
                tips.append((e[0], e[1], k))
    with a.on(BLOOM):
        for tx, ty, k in sorted(tips, key=lambda q: q[1]):
            little_cluster(a, tx, ty, R * 0.36 * k, fc, seed)


def valerian_plant(stage):
    def fn(a):
        lc = pal("common-valerian", "leaf", "leaf")
        soil(a, 88)
        if stage == "young":
            crown(a, leaf_valerian, 50, 87, [(-155, 30), (-25, 30), (-125, 36), (-55, 36), (-90, 38)], lc)
            return
        if stage == "dormant":   # a small low rosette, dead stems
            i0 = len(a.items)
            dead_stem(a, 46, 88, 46, -4, 2.4, broken=True); dead_stem(a, 55, 88, 34, 4, 2.2, broken=True)
            wither(a, i0)
            crown(a, leaf_valerian, 50, 87, [(-170, 22), (-10, 22), (-145, 20), (-35, 20)], lc)
            return
        dry = stage == "seedhead"
        flc = "straw" if dry else lc
        crown(a, leaf_valerian, 50, 87, [(-160, 22), (-20, 22), (-135, 24), (-45, 24)], flc)
        q = stalk(a, (50, 88), (51, 54), (50, 22), 2.8, 1.6, "straw" if dry else "leaf", ridges=2)
        leaves_on(a, q, [(0.28, 1, 20, 62), (0.52, 1, 16, 58), (0.74, 1, 11, 52)], leaf_valerian, flc, opp=True)
        fc = pal("common-valerian", "flower", "pink")
        for u, sd in ((0.85, -1), (0.85, 1)):
            x, y = q.pt(u); e = (x + sd * 12, y - 8)
            a.stem((x, y), (x + sd * 5, y - 2), e, 0.8)
            cyme_side(a, *e, 8, fc, seed=dry)
        cyme_side(a, *q.pt(0.88), 13, fc, seed=dry)
    return plant_group(fn, dry=stage == "seedhead")


# ---------------------------------------------------------------- meadowsweet
def meadowsweet_seed(a, x, y):
    seed_spiral(a, x, y - 6, pal("meadowsweet", "fruit", "bark"))


def spray_side(a, x, y, R, fc, seed=False):
    """Meadowsweet's head on the whole plant: an irregular branched
    panicle, taller than wide. Side branches leave the stem at several
    heights, the upper ones rising above its top, and carry little clumps
    of creamy flowers all along them, so it reads as froth, not as an
    umbel. In seed, the clumps are small twisted brown seed balls."""
    br = [(0.0, -0.9, 0.75), (0.2, 0.85, 0.9), (0.42, -0.65, 1.3), (0.6, 0.55, 1.45), (0.78, -0.25, 1.6), (0.9, 0.3, 1.7)]
    clumps = []
    with a.on(BLOOM - 0.5):
        a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y - R * 1.45)}", 0.75, 0.85)
        clumps.append((x, y - R * 1.5, 1.0))
        for v, dx, h in br:
            b0 = (x, y - R * 1.45 * v); e = (x + dx * R, y - h * R)
            q = Quad(b0, (x + dx * R * 0.5, b0[1] - R * 0.15), e)
            a.line(q.d(), 0.5, 0.85)
            clumps += [(*q.pt(0.55), 0.7), (*e, 1.0)]
    with a.on(BLOOM):
        for cx, cy, k in sorted(clumps, key=lambda q: q[1]):
            n = 5 if k > 0.8 else 3
            for i in range(n):
                th = i * GOLD + cx; rr = R * 0.17 * k * math.sqrt((i + 0.5) / n)
                px, py = cx + rr * math.cos(th) * 1.3, cy + rr * math.sin(th)
                if seed:
                    twist_ball(a, px, py, max(1.0, R * 0.09), pal("meadowsweet", "fruit", "bark"), 0.4)
                else:
                    a.oval(px, py, R * 0.095, R * 0.095, 0, fc, 0.4)
                    a.dot(px, py, max(0.25, R * 0.022), pal("meadowsweet", "centre", "primrose"))
            if not seed and k > 0.8:   # the stamen fuzz round each clump
                for i in range(5):
                    g = i * 72 + cx * 10; p0 = T(cx, cy, g)(R * 0.2)
                    a.line(f"M{P(p0)} L{P(T(cx, cy, g)(R * 0.3))}", 0.3, 0.6)


def meadowsweet_plant(stage):
    def fn(a):
        lc = pal("meadowsweet", "leaf", "deep")
        soil(a, 88)
        ms = lambda c: (lambda a_, x, y, g, L, cc, sm: leaf_meadowsweet(a_, x, y, g, L, cc, sm, stalkc=c))
        if stage == "young":
            crown(a, ms("rust"), 50, 87, [(-150, 32), (-30, 32), (-120, 38), (-60, 38), (-90, 36)], lc)
            return
        if stage == "dormant":   # nothing green: dead brown stems only
            for dx, H, lean, br in ((-6, 64, -5, False), (6, 52, 4, False), (0, 24, 1, True)):
                q = dead_stem(a, 50 + dx, 88, H, lean, 2.4, broken=br)
                if not br:
                    spray_side(a, *q.pt(1), 9, "straw", seed=True)
            wither(a)
            return
        dry = stage == "seedhead"
        flc = "straw" if dry else lc; sc = "straw" if dry else "rust"
        crown(a, ms(sc), 50, 87, [(-160, 26), (-20, 26), (-135, 30), (-45, 30)], flc)
        for dx, H, lean in ((-10, 50, -12), (10, 46, 12), (0, 58, 0)):
            q = stalk(a, (50 + dx * 0.3, 88), (50 + dx * 0.6, 88 - H * 0.5), (50 + dx + lean, 88 - H), 2.6, 1.6, sc)
            sd = 1 if lean >= 0 else -1
            leaves_on(a, q, [(0.2, sd, 18, 56), (0.42, -sd, 15, 52), (0.64, sd, 12, 48), (0.84, -sd, 9, 42)], ms(sc), flc)
            spray_side(a, *q.pt(1), 10 if H < 55 else 12, pal("meadowsweet", "flower", "umbels_cream"), seed=dry)
    return plant_group(fn, dry=stage == "seedhead")


# ================================================================ the stages, kind by kind
def _first_thread(slug):
    return lambda a, x, y: threads_first(pal(slug, "leaf", "sage"), slug == "fennel")(a, x, y)   # the colour looked up when drawn, not at import


STAGE = {
    "dill": {"seed": seed_stage(dill_seed), "seedling": seedling("needle", _first_thread("dill"), L=18, h=16),
             "young": dill_plant("young"), "crop": dill_plant("crop"), "flower": dill_plant("flower"), "seedhead": dill_plant("seedhead")},
    "fennel": {"seed": seed_stage(fennel_seed), "seedling": seedling("needle", _first_thread("fennel"), L=18, h=16),
               "young": fennel_plant("young"), "crop": fennel_plant("crop"), "flower": fennel_plant("flower"),
               "seedhead": fennel_plant("seedhead"), "dormant": fennel_plant("dormant")},
    "coriander": {"seed": seed_stage(coriander_seed), "seedling": seedling("strap", round_first("coriander", "leaf"), L=15),
                  "young": coriander_plant("young"), "crop": coriander_plant("crop"), "flower": coriander_plant("flower"),
                  "seedhead": coriander_plant("seedhead")},
    "parsley": {"seed": seed_stage(parsley_seed), "seedling": seedling("oblong", round_first("three", "deep"), L=13),
                "young": parsley_plant("young"), "crop": parsley_plant("crop"), "flower": parsley_plant("flower"),
                "seedhead": parsley_plant("seedhead")},
    "chervil": {"seed": seed_stage(chervil_seed), "seedling": seedling("strap", lambda a, x, y: leaf_chervil(a, x, y, -88, 15, "leaf", True), L=13),
                "young": chervil_plant("young"), "crop": chervil_plant("crop"), "flower": chervil_plant("flower"),
                "seedhead": chervil_plant("seedhead")},
    "anise": {"seed": seed_stage(anise_seed), "seedling": seedling("oblong", round_first("kidney", "leaf"), L=13),
              "young": anise_plant("young"), "flower": anise_plant("flower"), "seedhead": anise_plant("seedhead")},
    "lovage": {"seed": seed_stage(lovage_seed), "seedling": seedling("strap", round_first("three", "deep"), L=15),
               "young": lovage_plant("young"), "crop": lovage_plant("crop"), "flower": lovage_plant("flower"),
               "seedhead": lovage_plant("seedhead"), "dormant": lovage_plant("dormant")},
    "celery": {"seed": seed_stage(celery_seed), "seedling": seedling("oval", round_first("three", "leaf"), L=10, h=9),
               "young": celery_plant("young"), "crop": celery_plant("crop"), "flower": celery_plant("flower"),
               "seedhead": celery_plant("seedhead")},
    "wild-angelica": {"seed": seed_stage(angelica_seed), "seedling": seedling("strap", round_first("three", "leaf"), L=15),
                      "young": angelica_plant("young"), "flower": angelica_plant("flower"), "seedhead": angelica_plant("seedhead"),
                      "dormant": angelica_plant("dormant")},
    "hogweed": {"seed": seed_stage(hogweed_seed), "seedling": seedling("oval", round_first("hogweed", "leaf"), L=15),
                "young": hogweed_plant("young"), "flower": hogweed_plant("flower"), "seedhead": hogweed_plant("seedhead"),
                "dormant": hogweed_plant("dormant")},
    "yarrow": {"seed": seed_stage(yarrow_seed), "seedling": seedling("round", lambda a, x, y: leaf_yarrow(a, x, y, -88, 14, "deep", True), L=12, h=8),
               "young": yarrow_plant("young"), "flower": yarrow_plant("flower"), "seedhead": yarrow_plant("seedhead"),
               "dormant": yarrow_plant("dormant")},
    "common-valerian": {"seed": seed_stage(valerian_seed),
                        "seedling": seedling("round", lambda a, x, y: (a.line(f"M{f(x)},{f(y)} L{f(x + 0.5)},{f(y - 6)}", 0.8, 0.85),
                                                                       a.leaf(x + 0.5, y - 6, -88, 10, 0.4, "leaf")), L=12, h=9),
                        "young": valerian_plant("young"), "flower": valerian_plant("flower"), "seedhead": valerian_plant("seedhead"),
                        "dormant": valerian_plant("dormant")},
    "meadowsweet": {"seed": seed_stage(meadowsweet_seed), "seedling": seedling("round", round_first("kidney", "deep"), L=12, h=9),
                    "young": meadowsweet_plant("young"), "flower": meadowsweet_plant("flower"), "seedhead": meadowsweet_plant("seedhead"),
                    "dormant": meadowsweet_plant("dormant")},
}
