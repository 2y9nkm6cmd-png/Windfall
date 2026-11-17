"""Windfall plant drawings, the redraw of 16 November 2026: the root group.

The twenty kinds in this file: carrot, parsnip, celeriac, beetroot,
mangelwurzel, radish, turnip, swede, kohlrabi, salsify, scorzonera,
potatoes, leek, onion, shallot, garlic, spring onion, chives, wild garlic
and the Bristol onion.

WHY THIS FILE EXISTS
William found the strawberry leaf drawn wrong, and a spot check found the
same kinds of fault all over: the leaf on the whole plant was a stock leaf,
not the plant's own; flower colours changed between the close-up and the
plant; flowers were built from a few stock shapes (a potato had a
tomato's star); leaf shapes were rough. Every plant now has a written
description (Design/Plants/descriptions/<kind>.json) with a "must_show"
list for each drawing. This file redraws every drawing of the twenty
kinds so that each one shows those points, checked against photographs.

HOW IT WORKS (see redraw/__init__.py for the tables)
  LEAFX, BLOOMX    the close-up leaf and flower of each kind, using the new
                   shapes below.
  STAGE            nearly every life stage drawn by hand here, because the
                   templates in plants_all.py could not show things like a
                   swede's neck, a carrot's "bird's nest" or a garlic scape's loop.
  LEAF_DRAW, BLOOM_DRAW   the new close-up shapes, all named roots_...
  COLOURS          one new colour, roots_violet, for salsify (from its
                   description's palette_wish).
Colours come only from each description's palette, as the brief asks.

THE MAIN NEW SHAPES, IN PLAIN WORDS
  rblade(a, x, y, ang, L, hw, ...)  draws any leaf or petal. You give it a
      function hw(u, side) that says how wide the leaf is at each point
      along it (u = 0 at the base, 1 at the tip). Every other leaf shape
      here is just a different hw. edge() takes a bit off that width to
      make teeth ("round", "saw") or a wavy edge.
  leaf_lyrate     radish, turnip, swede: a big rounded end lobe and small
      lobes spaced down the lower part, each lobe a half-ellipse added
      to a narrow "wing" along the midrib.
  leaf_beet       beetroot and mangel: an oval wavy leaf with a thick
      coloured midrib, coloured side veins, puckering and a shine.
  leaf_pinnate + leaflet()   parsnip (broad lobed leaflets), celeriac
      (wedge-based three-lobed leaflets), potato (big oval leaflets with
      small ones between).
  leaf_carrot     a leaf cut two or three times into small pointed
      segments, triangular in outline, with a sheath at its foot. On the
      whole plant it is drawn more simply (carrot_small), because the
      fine segments turn into a dark blot when small.
  tube_leaf, flat_leaf   onion-family leaves: a hollow round tube (with a
      snipped end showing it is hollow) or a flat strap folded along a keel.
  fl_allium + allium_flower   every onion-family head: dots on a ball
      (the same "sphere" maths as before), each one drawn as a star, cup
      or bell facing outwards, with stamens and the papery spathe.
  fl_cross        four-petalled crosses of the cabbage family, with the
      buds above or below the open flowers as each kind has them.
  fl_potato       the potato's flat five-pointed star and its yellow cone.
  fl_beetspike, fl_celeriac, fl_umbel, fl_ligulate   beet spikes,
      celeriac's small umbels, carrot and parsnip umbels, salsify and
      scorzonera heads.
  For the life stages: put() draws the kind's own close-up leaf small
  (with Art.place), so the leaves on the plant match the close-up;
  taproot(), globe(), bulb() draw roots and bulbs; umbel_head(), nest(),
  raceme(), spike(), head_side(), mini_head() draw flowers and seed heads
  as they look on the whole plant.

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


def pal(slug, part, default):
    """A colour from the kind's description (its "palette")."""
    return _pa().palette(slug).get(part, default)


def edge(u, n, depth, kind="round", side=1, u0=0.06, u1=0.97):
    """How far in from the smooth outline the edge is at u (0 at the base of
    the blade, 1 at its tip): n teeth along the length, depth deep.
    "round" gives blunt rounded teeth, "wave" only a wavy edge, "saw" sharp."""
    if not n or u < u0 or u > u1:
        return 0.0
    s = (u * n + (0 if side > 0 else 0.5)) % 1
    nk = {"round": abs(math.cos(math.pi * s)) ** 2.4, "wave": 0.5 + 0.5 * math.cos(2 * math.pi * s),
          "saw": (1 - s) ** 1.6}[kind]
    return depth * nk * max(0.0, min(1.0, (u - u0) / 0.06, (u1 - u) / 0.06))


def rblade(a, x, y, ang, L, hw, fill, lw=1.15, midc="line", midw=0.8, mida=0.55, shade=0.1, n=160, veins=(), veinc=None, vw=0.5):
    """A leaf, leaflet or petal of any outline. hw(u, side) is its half
    width at u (0 at the base, 1 at the tip) on one side (1 or -1).
    veins: (u0, u1, side, reach) for each side vein: from the midrib at u0
    out to u1, reaching that share of the way to the edge."""
    t = T(x, y, ang)
    us = [i / n for i in range(n + 1)]
    top = [t(L * u, hw(u, 1)) for u in us]
    bot = [t(L * u, -hw(u, -1)) for u in us]
    a.shape(path(top + bot[::-1]), fill, lw)
    if shade:
        a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=shade)
    if midw:
        a.line(opath([t(L * u, 0) for u in (0.0, 0.3, 0.6, 0.92)]), midw, mida, midc)
    for u0, u1, side, k in veins:
        w1 = hw(u1, side) * k * side
        a.line(f"M{P(t(L * u0, 0))} Q{P(t(L * (u0 + (u1 - u0) * 0.4), w1 * 0.6))} {P(t(L * u1, w1))}", vw, 0.38, veinc or midc)
    return t


def hairs(a, pts, side=1, k=1.0):
    """Small bristles standing out from a line of points (radish, turnip stalks)."""
    for i in range(1, len(pts) - 1, 2):
        (x0, y0), (x1, y1) = pts[i - 1], pts[i + 1]
        ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
        for sd in (1, -1):
            e = T(*pts[i], ang + sd * 58)(2.4 * k)
            a.line(f"M{P(pts[i])} L{P(e)}", 0.55, 0.75)   # faint (under 0.8), so Art.place leaves them out when small


# ======================================================== close-up leaves
def leaf_lyrate(a, sp):
    """A lyre-shaped leaf: a big rounded end lobe and small lobes spaced
    out down the lower part (radish, turnip, swede)."""
    fill = sp["fill"]; LT = sp.get("len", 100); pf = sp.get("petiole", 0.14)
    t = T(*BASE, ANG); A = t(LT * pf); L = LT * (1 - pf)
    sc = sp.get("stalkc", fill)
    a.ribbon(BASE, t(LT * pf * 0.5, 1.2), A, 3.4, 2.8, sc, lw=0.9)
    t0 = sp.get("t0", 0.45); Wt = sp.get("Wt", 20); wing = sp.get("wing", 1.3)
    lobes = sp.get("lobes", [])
    nt = sp.get("teeth", 26); td = sp.get("td", 1.5)

    def hw(u, side):
        w = wing * (1 - 0.4 * u) + 1.0 * (1 - min(1, u / 0.08))
        v = (u - t0) / (1 - t0)
        e = (v - 0.45) / 0.55
        if abs(e) < 1:
            w = max(w, Wt * math.sqrt(1 - e * e) ** 0.9)
        for uc, du, s, sd in lobes:
            if sd in (0, side) and abs(u - uc) < du:
                g = (u - uc) / du
                w = max(w, s * math.sqrt(1 - g * g) * (1 - 0.25 * g))
        if w > wing + 1.2:
            w -= edge(u, nt, td, sp.get("tk", "round"), side, 0.02, 0.985)
        return max(0.5, w)
    veins = [(max(0.0, uc - du * 0.5), uc + du * 0.1, sd if sd else s_, 0.75) for uc, du, s, sd in lobes for s_ in ((1, -1) if sd == 0 else (sd,))]
    veins += [(t0 + (1 - t0) * k, t0 + (1 - t0) * (k + 0.2), s_, 0.8) for k in (0.0, 0.2, 0.4, 0.58) for s_ in (1, -1)]
    tt = rblade(a, A[0], A[1], ANG, L, hw, fill, midc=sp.get("midc", "line"), midw=1.3, mida=0.4, veins=veins)
    if sp.get("hairs"):   # stiff bristles on the stalk, the midrib and the lower edge
        hairs(a, [t(LT * pf * u) for u in [i / 8 for i in range(9)]])
        hairs(a, [tt(L * u * 0.8, 0) for u in [i / 12 for i in range(13)]], k=0.7)
        for u in [0.08 + 0.05 * i for i in range(int((t0 - 0.06) / 0.05))]:   # on the lobes' edges
            for s_ in (1, -1):
                w = hw(u, s_)
                if w > wing + 1.5:
                    p0 = tt(L * u, s_ * w); e = tt(L * u + 0.6, s_ * (w + 1.8))
                    a.line(f"M{P(p0)} L{P(e)}", 0.5, 0.75)
    return a


def oval_hw(W, tipk=0.62, basek=0.75, wave=0, waven=9, teeth=0, td=1.4, run=0.0):
    """Half width of a simple oval leaf: W wide, blunt (tipk small) or
    pointed (tipk near 1) at the tip. wave gives a wavy edge, teeth blunt teeth.
    run: the blade runs a little way down the stalk."""
    def hw(u, side):
        w = W / 2 * math.sin(math.pi * min(1.0, u) ** basek) ** tipk
        if run:
            w = max(w, run * (1 - u / 0.12)) if u < 0.12 else w
        if wave:
            w += wave * math.sin(2 * math.pi * u * waven + (0 if side > 0 else 1.7)) * math.sin(math.pi * u)
        if teeth:
            w -= edge(u, teeth, td, "round", side, 0.1, 0.96)
        return max(0.4, w)
    return hw


def leaf_beet(a, sp):
    """Beetroot and mangel: one oval untoothed wavy leaf on a fleshy stalk,
    the midrib and side veins the colour of the stalk, glossy and puckered."""
    fill = sp["fill"]; sc = sp.get("stalkc", fill); vc = sp.get("veinc", "line")
    LT = 100; pf = sp.get("petiole", 0.34); t = T(*BASE, ANG); A = t(LT * pf); L = LT * (1 - pf) - 2
    a.ribbon(BASE, t(LT * pf * 0.5, 1.0), A, 5.0, 3.8, sc, lw=0.9)
    hw = oval_hw(sp.get("W", 40), tipk=0.55, basek=0.8, wave=1.0, waven=6)
    veins = [(0.06 + 0.12 * k, 0.24 + 0.13 * k, s_, 0.84) for k in range(6) for s_ in (1, -1)]
    tt = rblade(a, A[0], A[1], ANG, L, hw, fill, midw=0, veins=veins, veinc=vc, vw=0.9)
    a.ribbon(A, tt(L * 0.4, 0), tt(L * 0.9), 3.6, 0.7, sc, lw=0.6)   # the thick midrib
    for k in range(5):   # the blade puckered up between the side veins
        u = 0.2 + 0.13 * k
        for s_ in (1, -1):
            w = hw(u + 0.05, s_) * 0.5 * s_
            a.line(f"M{P(tt(L * u, w * 0.6))} Q{P(tt(L * (u + 0.05), w * 1.15))} {P(tt(L * (u + 0.1), w * 0.7))}", 0.45, 0.3)
    a.line(opath([tt(L * u, hw(u, -1) * -0.62) for u in (0.3, 0.45, 0.6)]), 1.2, 0.5, "white")   # the gloss
    return a


def leaf_simple(a, sp):
    """An oval or lance leaf on a stalk, drawn from settings: kohlrabi,
    scorzonera, wild garlic."""
    fill = sp["fill"]; LT = sp.get("len", 100); pf = sp.get("petiole", 0.3); t = T(*BASE, ANG); A = t(LT * pf)
    L = LT * (1 - pf)
    if sp.get("winged"):   # scorzonera: the blade narrows into a winged stalk
        pf = 0.04; A = t(LT * pf); L = LT * (1 - pf)
    else:
        a.ribbon(BASE, t(LT * pf * 0.5, 1.2), A, sp.get("sw", 2.6), sp.get("sw", 2.6) * 0.8, sp.get("stalkc", fill), lw=0.9)
        if sp.get("twist"):   # wild garlic: the stalk turns half a turn, so the paler underside faces up
            for u in (0.45, 0.62):
                a.line(f"M{P(t(LT * pf * u, -1.4))} Q{P(t(LT * pf * (u + 0.04), 0))} {P(t(LT * pf * (u + 0.08), 1.4))}", 0.5, 0.6)
    hw = oval_hw(sp.get("W", 34), sp.get("tipk", 0.7), sp.get("basek", 0.8), sp.get("wave", 0), sp.get("waven", 7),
                 sp.get("teeth", 0), sp.get("td", 1.4))
    if sp.get("winged"):   # narrowing into a winged stalk that widens again into a clasping foot
        base = hw
        k0 = 0.3   # the stalk part: a narrow wing each side, flaring into a clasping foot

        def hw(u, side):
            if u < k0:
                return 1.5 + 3.4 * max(0.0, 1 - u / 0.05) ** 1.5 + 0.8 * max(0.0, (u - k0 * 0.6) / (k0 * 0.4)) ** 2
            v = (u - k0) / (1 - k0)
            return max(2.3 * max(0.0, 1 - v / 0.3), base(v * 0.92 + 0.08, side))
    if sp.get("parallel"):   # wild garlic: fine veins running from base to tip, curving with the edge
        tt = rblade(a, A[0], A[1], ANG, L, hw, fill, midw=1.1, mida=0.45)
        for k in (0.3, 0.55, 0.8):
            for s_ in (1, -1):
                a.line(opath([tt(L * u, hw(u, s_) * k * s_) for u in [0.03 + 0.94 * i / 14 for i in range(15)]]), 0.4, 0.3)
        return a
    nv = sp.get("veins", 6)
    veins = [(0.06 + 0.8 * k / nv, 0.2 + 0.78 * k / nv, s_, 0.8) for k in range(nv) for s_ in (1, -1)]
    if sp.get("near"):   # scorzonera: faint veins running along the leaf
        rblade(a, A[0], A[1], ANG, L, hw, fill, midc="white" if sp.get("palemid") else "line", midw=1.2, mida=0.6)
        tt = T(*A, ANG)
        for k in (0.4, 0.72):
            for s_ in (1, -1):
                a.line(opath([tt(L * u, hw(u, s_) * k * s_) for u in [0.08 + 0.84 * i / 12 for i in range(13)]]), 0.4, 0.3)
        return a
    tt = rblade(a, A[0], A[1], ANG, L, hw, fill, midc="white" if sp.get("palemid") else "line", midw=1.4 if sp.get("palemid") else 0.9,
                mida=0.7 if sp.get("palemid") else 0.55, veins=veins)
    if sp.get("stalklobe"):   # kohlrabi: a small lobe or two on the stalk below the blade
        for u, s_ in ((0.62, 1), (0.78, -1)):
            p = t(LT * pf * u)
            rblade(a, p[0], p[1], ANG + s_ * 70, 7, oval_hw(4.6, 0.6), fill, lw=0.9, midw=0, shade=0)
    return a


def leaf_grass(a, sp):
    """Salsify: a long narrow grass-like leaf, widest at its clasping base,
    tapering steadily to a long fine curling point, with parallel veins."""
    fill = sp["fill"]
    for p0, c, p1, W, fold in (((43, 90), (30, 58), (14, 24), 8.0, False), ((45, 90), (50, 44), (84, 8), 10.0, True)):
        q = Quad(p0, c, p1); n = 70; Lp, Rp, mid = [], [], []
        for i in range(n + 1):
            u = i / n; x, y = q.pt(u); g = math.radians(q.ang(u) + 90)
            w = W / 2 * (1 - u) ** 1.1   # widest at the base, tapering steadily all the way to a long fine point
            Lp.append((x + w * math.cos(g), y + w * math.sin(g))); Rp.append((x - w * math.cos(g), y - w * math.sin(g))); mid.append((x, y, math.cos(g), math.sin(g), w))
        a.shape(path(Lp + Rp[::-1]), fill, 1.1)
        a.shape(path(Lp + [(m[0], m[1]) for m in mid[::-1]]), "shade", 0, fa=0.14 if fold else 0.1)
        for o in (0.45, -0.45):
            a.line(opath([(m[0] + o * m[4] * m[2], m[1] + o * m[4] * m[3]) for m in mid[2:-8:3]]), 0.4, 0.3)
        a.line(opath([(m[0], m[1]) for m in mid[1:-10:3]]), 0.9, 0.6, "white")   # the pale keel
    a.shape("M37,95 Q36,88 40,84 L49,84 Q52,88 51,95 Q44,97 37,95 Z", "pale", 0.9)   # the broad base, clasping the crown
    a.line("M40,85 Q44,90 43,95 M48,85 Q47,90 48,95", 0.5, 0.4)
    return a


def tube_leaf(a, p0, c, p1, W, fill, cut=None, groove=False, tipk=0.25):
    """A hollow round leaf (onion, chives): a tube that tapers only near its
    tip to a point. With cut (0 to 1) it is snipped off there and the cut
    end shows it is hollow: a ring with a dark hole. groove: half round,
    with a groove along the upper side (Bristol onion); its cut end is a
    half moon, hollow too."""
    q = Quad(p0, c, p1); n = 60; end = cut or 1.0
    Lp, Rp, mid = [], [], []
    for i in range(n + 1):
        u = end * i / n; x, y = q.pt(u); g = math.radians(q.ang(u) + 90)
        w = W / 2 * (1 if (u < 1 - tipk or cut) else max(0.0, 1 - max(0.0, (u - 1 + tipk) / tipk) ** 1.6) ** 0.9)
        Lp.append((x + w * math.cos(g), y + w * math.sin(g))); Rp.append((x - w * math.cos(g), y - w * math.sin(g))); mid.append((x, y, math.cos(g), math.sin(g), w))
    a.shape(path(Lp + Rp[::-1]), fill, min(1.1, 0.3 + W * 0.22))
    if W >= 2.5:   # rounded like a tube: a band of shadow down one side, a shine down the other
        a.shape(path(Lp + [(m[0] + 0.15 * m[4] * m[2], m[1] + 0.15 * m[4] * m[3]) for m in mid[::-1]]), "shade", 0, fa=0.14)
        a.shape(path(Lp + [(m[0] + 0.62 * m[4] * m[2], m[1] + 0.62 * m[4] * m[3]) for m in mid[::-1]]), "shade", 0, fa=0.14)
        a.line(opath([(m[0] - 0.52 * m[4] * m[2], m[1] - 0.52 * m[4] * m[3]) for m in mid[2:-8:3]]), max(0.5, W * 0.13), 0.55, "white")
    if groove and W >= 2.5:   # the groove along the upper side
        a.line(opath([(m[0] - 0.1 * m[4] * m[2], m[1] - 0.1 * m[4] * m[3]) for m in mid[2:-5:2]]), 0.7, 0.9)
    if cut:
        x, y, nx, ny, w = mid[-1]; ang = math.degrees(math.atan2(ny, nx))
        tt = T(x, y, ang)
        if groove:   # half round: the cut end is a half moon, hollow
            outer = [tt(w * math.cos(h), w * 0.5 * math.sin(h)) for h in [math.pi * i / 16 for i in range(17)]]
            a.shape(path(outer + [tt(-w * 0.6, -w * 0.12), tt(0, w * 0.12), tt(w * 0.6, -w * 0.12)]), fill, 0.8)
            a.shape(path([tt(w * 0.6 * math.cos(h), w * 0.3 * math.sin(h) + w * 0.1) for h in [math.pi * i / 12 for i in range(13)]]), "dark", 0, fa=0.75)
        else:
            a.oval(x, y, w * 1.05, w * 0.55, ang, fill, 0.8)
            a.shape(path([tt(w * 0.68 * math.cos(h), w * 0.34 * math.sin(h)) for h in [2 * math.pi * i / 24 for i in range(24)]]), "dark", 0, fa=0.75)
    return q


def leaf_tube(a, sp):
    """Onion, shallot, spring onion, chives, Bristol onion: hollow leaves.
    Each kind shows its own difference: how many, how thick, and what
    they rise from (sp "base"): an onion's golden neck, a shallot's coppery
    one, a spring onion's long white shank, a chive clump's thin sheaths,
    the Bristol onion's half-round grooved leaves. One leaf is snipped
    to show it is hollow."""
    fill = sp["fill"]; W = sp.get("W", 8); g = sp.get("groove"); base = sp.get("base", "neck")
    foot = (44, 93)
    if base == "shank":   # spring onion: a straight white shank, the leaves from its top
        top = (46, 62)
        ends = [((top[0] - 2, top[1]), (30, 40), (18, 12)), ((top[0] + 2, top[1]), (56, 34), (80, 10)), ((top[0], top[1]), (46, 36), (48, 8))]
    else:
        top = foot
        ends = sp.get("ends") or [((42, 92), (30, 60), (16, 24)), ((45, 92), (50, 52), (80, 14))]
    for p0, c, p1 in ends:
        tube_leaf(a, p0, c, p1, W, fill, groove=g, tipk=sp.get("tipk", 0.32))
    cp = sp.get("cutleaf", ((47, 92), (56, 80), (66, 62)))
    if base == "shank":
        cp = ((top[0] + 1, top[1]), (60, 56), (70, 48))
    tube_leaf(a, cp[0], cp[1], cp[2], W, fill, cut=1.0, groove=g)
    if base == "shank":
        a.ribbon((46, 93), (46, 78), top, W * 1.7, W * 1.45, "white", lw=0.9)
        a.shape(f"M{f(46 - W * 0.72)},{f(top[1] + 6)} L{f(46 + W * 0.72)},{f(top[1] + 6)} L{f(46 + W * 0.7)},{f(top[1])} L{f(46 - W * 0.7)},{f(top[1])} Z", "pale", 0)
        white_roots(a, 46, 93, 5, 4, 100)
    elif base in ("amber", "rust"):   # the neck of the bulb the leaves come from
        a.shape(f"M{f(foot[0] - W * 1.1)},{f(foot[1] + 2)} Q{f(foot[0] - W * 1.2)},{f(foot[1] - 4)} {f(foot[0] - W * 0.7)},{f(foot[1] - 8)} "
                f"L{f(foot[0] + W * 0.9)},{f(foot[1] - 8)} Q{f(foot[0] + W * 1.4)},{f(foot[1] - 4)} {f(foot[0] + W * 1.3)},{f(foot[1] + 2)} Z", base, 0.9)
        for o in (-0.5, 0.2, 0.8):
            a.line(f"M{f(foot[0] + o * W)},{f(foot[1] - 7.5)} L{f(foot[0] + o * W * 1.2)},{f(foot[1] + 1.5)}", 0.5, 0.4)
    elif base == "sheath":
        a.ribbon((foot[0] + 1, 94), (foot[0] + 1.5, 90), (foot[0] + 2, 86), W * 3.2, W * 2.6, "pale", lw=0.8)
    return a


def flat_leaf(a, p0, c, p1, W, fill, prof="strap", tipk=0.3, lw=1.1):
    """A flat strap folded a little along a keel (leek, garlic): one half
    darker, the keel line down the middle, fine parallel veins."""
    q = Quad(p0, c, p1); n = 60; Lp, Rp, mid = [], [], []
    for i in range(n + 1):
        u = i / n; x, y = q.pt(u); g = math.radians(q.ang(u) + 90)
        if prof == "taper":   # garlic: tapering gradually to a long point
            w = W / 2 * max(0.0, min(1, (1 - u) / 0.75)) ** 0.8
        else:                 # leek: parallel-sided, then a blunt point
            w = W / 2 * (1 if u < 1 - tipk else max(0.0, 1 - max(0.0, (u - 1 + tipk) / tipk) ** 1.5) ** 0.8)
        Lp.append((x + w * math.cos(g), y + w * math.sin(g))); Rp.append((x - w * math.cos(g), y - w * math.sin(g))); mid.append((x, y, math.cos(g), math.sin(g), w))
    a.shape(path(Lp + Rp[::-1]), fill, lw)
    a.shape(path(Lp + [(m[0], m[1]) for m in mid[::-1]]), "shade", 0, fa=0.2 if lw > 1 else 0.1)   # the far half of the V, in shadow
    for o in (0.5, -0.4, -0.75):
        a.line(opath([(m[0] + o * m[4] * m[2], m[1] + o * m[4] * m[3]) for m in mid[2:-4:3]]), 0.35, 0.28)
    a.line(opath([(m[0], m[1]) for m in mid[1:-3:3]]), 0.9, 0.85)   # the keel
    return q


def leaf_flat(a, sp):
    """Leek and garlic: flat solid leaves folded along a keel, two-ranked,
    from a white sheath."""
    fill = sp["fill"]; W = sp.get("W", 13); prof = sp.get("prof", "strap")
    if sp.get("garlic"):
        a.ribbon((44, 94), (45, 85), (46, 72), 7.5, 6.5, "pale", lw=0.9)    # the false stem of wrapped sheaths
        flat_leaf(a, (45, 80), (28, 58), (12, 28), W * 0.8, fill, prof)
        flat_leaf(a, (46, 72), (58, 44), (84, 8), W, fill, prof)
        a.line("M42,88 Q45,85 48,88 M42.5,79 Q45.5,76 48.5,79", 0.6, 0.5)
        return a
    flat_leaf(a, (42, 76), (22, 52), (10, 30), W * 0.92, fill, tipk=0.25)   # the tip arching over
    flat_leaf(a, (48, 74), (56, 36), (86, 10), W, fill)
    a.ribbon((44, 94), (44.6, 84), (45.4, 70), W * 1.25, W * 1.1, "white", lw=0.9)   # the white shank
    a.line(f"M{f(45.4 - W * 0.55)},71 Q45.4,74 {f(45.4 + W * 0.55)},71", 0.7, 0.5)
    a.shape(f"M{f(45.4 - W * 0.55)},71 L{f(45.4 + W * 0.55)},71 L{f(45 + W * 0.58)},77 Q45,80 {f(45 - W * 0.6)},77 Z", "pale", 0)   # pale green where the leaves part
    a.line("M41,90 L41.3,80 M48,90 L47.8,80", 0.4, 0.3)
    return a


def leaflet_hw(kind, L, W):
    """The outline of one leaflet of a pinnate leaf."""
    if kind == "parsnip":    # broad oval, cut into lobes at the base, blunt teeth all round
        def hw(u, side):
            w = W / 2 * math.sin(math.pi * u ** 0.8) ** 0.6
            w *= 1 - 0.5 * math.exp(-((u - 0.34) / 0.07) ** 2)
            return max(0.4, w - edge(u, 9, 1.4, "round", side, 0.08, 0.96))
    elif kind == "parsnip_end":   # the end leaflet: three-lobed
        def hw(u, side):
            w = W / 2 * math.sin(math.pi * u ** 0.85) ** 0.6
            w *= 1 - 0.6 * math.exp(-((u - 0.5) / 0.08) ** 2) - 0.35 * math.exp(-((u - 0.26) / 0.06) ** 2)
            return max(0.4, w - edge(u, 10, 1.4, "round", side, 0.08, 0.96))
    elif kind == "celeriac":   # a wedge at the base, three lobes, toothed on the outer half only
        def hw(u, side):
            wedge = 0.78 * u / 0.42 if u < 0.46 else 0
            g = (u - 0.52) / 0.18; side_l = math.sqrt(1 - g * g) if abs(g) < 1 else 0
            g = (u - 0.83) / 0.17; cen = 0.56 * math.sqrt(1 - g * g) if abs(g) < 1 else 0
            w = W / 2 * max(wedge, side_l, cen, 0.08)
            return max(0.4, w - (edge(u, 11, 1.4, "saw", side, 0.46, 0.97) if u > 0.46 else 0))
    else:   # potato: oval, pointed, untoothed, the base rounded
        def hw(u, side):
            return max(0.3, W / 2 * math.sin(math.pi * u ** 0.66) ** 0.8 * (1 + 0.04 * math.sin(u * 30)))
    return hw


def leaflet(a, x, y, ang, L, W, fill, kind, lw=1.0, veins=4):
    hw = leaflet_hw(kind, L, W)
    vs = [(0.08 + 0.7 * k / veins, 0.25 + 0.7 * k / veins, s_, 0.78) for k in range(veins) for s_ in (1, -1)]
    if kind == "celeriac":
        vs = [(0.12, 0.56, s_, 0.8) for s_ in (1, -1)] + [(0.3, 0.7, s_, 0.5) for s_ in (1, -1)]
    tt = rblade(a, x, y, ang, L, hw, fill, lw=lw, veins=vs, midw=0.7)
    if kind == "potato":   # the blade wrinkled between the pressed-in veins
        for k in range(3):
            u = 0.28 + 0.2 * k
            for s_ in (1, -1):
                w = hw(u, s_) * s_
                a.line(f"M{P(tt(L * u, w * 0.3))} Q{P(tt(L * (u + 0.06), w * 0.62))} {P(tt(L * (u + 0.03), w * 0.85))}", 0.4, 0.28)
    return tt


def leaf_pinnate(a, sp):
    """A once-pinnate leaf: pairs of leaflets along one stalk and one at
    the end (parsnip, celeriac, potato). sheath: the stalk widens at its foot."""
    fill = sp["fill"]; kind = sp["leaflet"]; pairs = sp.get("pairs", 3)
    t = T(*BASE, ANG); LT = sp.get("len", 98); endu = sp.get("end", 0.72)
    q = Quad(BASE, t(LT * endu * 0.5, sp.get("bend", -3)), t(LT * endu))
    a.ribbon(q.p0, q.c, q.p1, 2.4, 1.3, sp.get("stalkc", fill), lw=0.85)
    if sp.get("sheath"):
        a.ribbon(BASE, t(4), t(10), 6.0, 2.4, sp.get("stalkc", fill), lw=0.85)
    us = sp.get("us") or [0.36 + 0.56 * i / max(1, pairs - 1) for i in range(pairs)]
    ll, lW = sp.get("ll", 24), sp.get("lW", 0.62)
    for i, u in enumerate(us):
        x, y = q.pt(u); g = q.ang(u); s = 1 - sp.get("shrink", 0.15) * i / max(1, len(us) - 1)
        for sd in (1, -1):
            if sp.get("stalklets"):
                e = T(x, y, g + sd * sp.get("spread", 56))(2.6)
                a.line(f"M{P((x, y))} L{P(e)}", 0.9, 0.85); x_, y_ = e
            else:
                x_, y_ = x, y
            leaflet(a, x_, y_, g + sd * sp.get("spread", 56), ll * s, ll * s * lW, fill, kind)
    if sp.get("small"):   # potato: pairs of small leaflets on the stalk between the big pairs
        for i in range(len(us) - 1):
            v = us[i] + (us[i + 1] - us[i]) * 0.55; x2, y2 = q.pt(v)
            for sd in (1, -1):
                leaflet(a, x2, y2, q.ang(v) + sd * 84, ll * 0.4, ll * 0.4 * 0.62, fill, kind, lw=0.8, veins=0)
    if sp.get("groove"):   # parsnip: a groove down the long stalk
        a.line(opath([(q.pt(u)[0] + 0.3, q.pt(u)[1] + 0.3) for u in (0.04, 0.15, 0.27, 0.38)]), 0.5, 0.6)
    ex, ey = q.pt(1)
    tl = ll * sp.get("termk", 1.15)
    leaflet(a, ex, ey, q.ang(1), tl, tl * sp.get("termW", lW), fill, sp.get("endkind", kind), veins=5)
    return a


def leaf_carrot(a, sp):
    """Carrot: one leaf on a long stalk with a sheathing foot, cut two or
    three times into many small narrow segments, triangular in outline."""
    fill = sp["fill"]; t = T(*BASE, ANG)
    q = Quad(BASE, t(52, -3), t(97))
    a.ribbon(q.p0, q.c, q.p1, 2.0, 0.7, fill, lw=0.8)
    a.ribbon(BASE, t(4), t(11), 6.2, 2.2, fill, lw=0.8)   # the sheath wrapping the crown
    n = 5
    for i in range(n):
        u = 0.34 + 0.56 * i / (n - 1); x, y = q.pt(u); g = q.ang(u); L = 34 * (1.0 - 0.78 * (u - 0.34) / 0.56)
        for sg in (1, -1):
            pa = g + sg * 50; tq = T(x, y, pa)
            a.line(f"M{f(x)},{f(y)} Q{P(tq(L * 0.5, -sg * 1.2))} {P(tq(L))}", 0.6, 0.75)
            m = max(2, int(L / 6))
            for j in range(m):
                v = 0.2 + 0.7 * j / max(1, m - 1); px, py = tq(L * v, -sg * 1.2 * 4 * v * (1 - v)); l = L * 0.36 * (1.15 - v * 0.75)
                for sg2 in (1, -1):
                    seg(a, px, py, pa + sg2 * 46, l, fill)
            e = tq(L); seg(a, e[0], e[1], pa, L * 0.22, fill)
    e = q.pt(1); seg(a, e[0], e[1], q.ang(1), 8, fill)
    return a


def seg(a, x, y, ang, l, fill, lw=0.45):
    """One small division of a carrot leaf: cut again into narrow pointed lobes."""
    t = T(x, y, ang)
    if l < 3.2:
        a.leaf(x, y, ang, max(1.6, l), 0.26, fill, lw=lw, detail=False); return
    a.line(f"M{P(t(0))} L{P(t(l * 0.9))}", 0.4, 0.7)
    for k, v in enumerate((0.3, 0.6)):
        for s_ in (1, -1):
            p = t(l * v); a.leaf(p[0], p[1], ang + s_ * 42, l * 0.46 * (1.1 - v * 0.5), 0.28, fill, lw=lw, detail=False)
    p = t(l * 0.82); a.leaf(p[0], p[1], ang, l * 0.4, 0.28, fill, lw=lw, detail=False)


def leaf_wildgarlic(a, sp):
    return leaf_simple(a, dict(sp, parallel=True, twist=True, petiole=0.3, W=sp.get("W", 22), tipk=0.95, basek=0.9, sw=2.2))


# ======================================================= close-up flowers
CX, CY = 50, 44
GOLD = 2.39996


def umbellet(a, e, fc, rr, outer_dir=None, rim=False, n=8, dots="unripe", lw=0.38, small=2.2):
    """One small umbel: tiny five-petalled flowers on short spokes. With rim,
    the flowers on the outer side have their outer petals larger (carrot)."""
    for j in sorted(range(n), key=lambda j: math.sin(j * 0.9)):
        th = j * 360 / (n - 1) + 5
        p = (e[0] + rr * math.cos(math.radians(th)), e[1] - 3 + rr * 0.32 * math.sin(math.radians(th)))
        if j == n - 1:
            p = (e[0], e[1] - 3)
        a.line(f"M{P(e)} L{P(p)}", 0.4, 0.5)
        big = rim and outer_dir is not None and math.cos(math.radians(th) - outer_dir) > 0.3
        if big:   # an outer flower: two small petals in, three bigger ones out
            for k in range(5):
                g = math.degrees(outer_dir) + 180 + 72 * k + 36
                big_p = math.cos(math.radians(g) - outer_dir) > -0.2
                a.leaf(p[0], p[1], g, small * (2.3 if big_p else 0.9), 0.62 if big_p else 0.7, fc, lw=lw, skew=0.6, detail=False)
        else:
            a.flower(p[0], p[1], small, 5, fc, None, 0.8, start=-90 + th, lw=lw)
        a.dot(p[0], p[1], 0.45, dots)


def fl_umbel(a, sp):
    """A compound umbel: spokes from one point, each ending in a small umbel.
    bracts="fork": carrot's long thread-like forked bracts beneath; rim:
    carrot's outer flowers with enlarged outer petals; cen: carrot's dark
    middle flower. Parsnip: none of these, all petals the same."""
    fc = sp["fc"]; hub = (50, 72); c = (50, 40); R = sp.get("R", 34); k = 0.22
    a.ribbon((52, 98), (52, 86), hub, 2.8, 2.4, "leaf", lw=0.9)
    if sp.get("bracts") == "fork":
        for ang in (-172, -150, -122, -58, -30, -8, 160, 20):
            q = Quad(hub, T(*hub, ang)(9), T(*hub, ang + (8 if math.cos(math.radians(ang)) < 0 else -8))(19))
            a.line(q.d(), 0.6, 0.85)
            for u, off in ((0.45, 30), (0.62, -28), (0.78, 24)):
                x, y = q.pt(u); g = q.ang(u)
                a.line(f"M{f(x)},{f(y)} L{P(T(x, y, g + off)(5.5 * (1.1 - u)))}", 0.5, 0.8)
    n = sp.get("rays", 11)
    us = [(i * 360 / n + 10) for i in range(n)] + ["c"]

    def place(ang):
        if ang == "c":
            return c, 0.6
        r = math.radians(ang); return (c[0] + R * math.cos(r), c[1] + R * k * math.sin(r)), math.sin(r)
    for ang in sorted(us, key=lambda g: place(g)[1]):
        e, z = place(ang)
        a.line(f"M{P(hub)} Q{f((hub[0] + e[0]) / 2)},{f((hub[1] + e[1]) / 2 + 4)} {P(e)}", 0.7, 0.75)
        od = None if ang == "c" else math.atan2(math.sin(math.radians(ang)) * 0.6, math.cos(math.radians(ang)))
        umbellet(a, e, fc, 7.2 * (0.9 + 0.12 * z), od, rim=sp.get("rim"), dots=sp.get("dots", "unripe"))
    if sp.get("dark"):   # carrot: one dark red-purple flower at the very middle
        a.flower(c[0], c[1] - 4, 2.6, 5, sp["dark"], None, 0.8, lw=0.5)
        a.dot(c[0], c[1] - 4, 0.8, "plum")
    return a


def fl_celeriac(a, sp):
    """Celeriac: small loose umbels of tiny greenish-white flowers on very
    short stalks, set opposite the leaves along the stem, no bracts."""
    fc = sp["fc"]
    q = Quad((30, 98), (42, 62), (58, 28))
    a.ribbon(q.p0, q.c, q.p1, 3.0, 1.8, "leaf", lw=0.9)
    for u in (0.2, 0.4, 0.6, 0.8):   # the grooves on the stem
        x, y = q.pt(u); a.line(f"M{f(x - 0.4)},{f(y - 3)} L{f(x - 0.2)},{f(y + 3)}", 0.4, 0.4)
    for u, sd, s in ((0.42, 1, 1.0), (0.72, -1, 0.85)):
        x, y = q.pt(u)
        # the leaf at this node (its stalk and the foot of a leaflet)...
        e = T(x, y, -90 - sd * 62)(15 * s)
        a.ribbon((x, y), T(x, y, -90 - sd * 70)(8 * s), e, 2.2, 1.4, "deep", lw=0.8)
        leaflet(a, e[0], e[1], -90 - sd * 52, 16 * s, 14 * s, "deep", "celeriac", lw=0.9, veins=2)
        # ...and opposite it, a small umbel on a very short stalk
        h = T(x, y, -90 + sd * 48)(5 * s)
        a.line(f"M{f(x)},{f(y)} L{P(h)}", 1.1, 0.85)
        sub_umbel(a, h, -90 + sd * 30, 15 * s, fc, sp.get("cen", "pear"))
    sub_umbel(a, q.p1, -88, 15, fc, sp.get("cen", "pear"))
    return a


def sub_umbel(a, hub, ang, R, fc, cen, spokes=7):
    """A small loose umbel of unequal spokes, each with a few tiny flowers."""
    for j in range(spokes):
        g = ang - 70 + 140 * j / (spokes - 1); L = R * (0.55 + 0.45 * abs(math.sin(j * 1.7)))
        e = T(*hub, g)(L); a.line(f"M{P(hub)} L{P(e)}", 0.5, 0.8)
        for m in range(4):
            p = T(*e, g - 60 + 40 * m)(2.2)
            a.flower(p[0], p[1], 1.5, 5, fc, None, 0.8, start=g + m * 20, lw=0.32)
            a.dot(p[0], p[1], 0.4, cen)


def fl_beetspike(a, sp):
    """Beet and mangel: tiny green flowers with no petals, two to four
    together in tight clusters spaced along a slender spike, a small leafy
    bract under each cluster. Each flower is five green segments curved in
    over the middle, with small yellowish stamens."""
    q = Quad((44, 98), (40, 50), (60, 6))
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.0, "leaf", lw=0.8)
    sub = Quad(q.pt(0.36), (24, 52), (14, 28))
    a.ribbon(sub.p0, sub.c, sub.p1, 1.5, 0.8, "leaf", lw=0.7)
    for qq, us, s0 in ((q, [0.3, 0.42, 0.53, 0.63, 0.72, 0.8, 0.87, 0.93, 0.98], 1.0), (sub, [0.25, 0.45, 0.63, 0.8, 0.94], 0.8)):
        for i, u in enumerate(us):
            x, y = qq.pt(u); g = qq.ang(u); sd = 1 if i % 2 else -1; s = s0 * (1 - 0.45 * i / len(us))
            if u < (0.6 if qq is q else 0.5):   # a small leafy bract, under the lower clusters only
                blade_simple(a, x, y, g + sd * 50, 9 * s, 3.4 * s, "leaf")
            for m, (dx, dy) in enumerate(((0, 0), (-1, -0.9), (1, -0.8), (0.1, -1.7))[: 3 if i % 3 else 4]):
                px, py = T(x, y, g - sd * 90)(3.0 * s); px += dx * 2.6 * s; py += dy * 2.6 * s
                beetflower(a, px, py, 2.3 * s, sp.get("cen", "pear"))
    return a


def blade_simple(a, x, y, ang, L, W, fill, lw=0.7):
    a.leaf(x, y, ang, L, W / L, fill, lw=lw, detail=False)


def beetflower(a, x, y, r, cen):
    a.oval(x, y + r * 0.3, r, r * 0.8, 0, "unripe", 0.55)
    for k in range(5):   # the five segments curving in
        e = T(x, y, -90 + 72 * k)(r * 0.85)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.4, 0.55)
    a.dot(x, y - r * 0.1, max(0.35, r * 0.28), cen)


def crossflower(a, x, y, R, fc, k=0.62, start=-45, veins=None, sepals="up", face=0, cen="unripe"):
    """One four-petalled cross, seen a little from the side (k squashes it).
    sepals "up": narrow sepals held close against the petal claws; "out":
    spreading out to the sides."""
    LFW = _lfw(); M = LFW.tilt(y, k)
    if sepals == "out":   # spreading out sideways, showing between the petals
        for g in (start + 45, start + 225):
            blade_simple(a, x, y, g, R * 0.78, R * 0.16, "unripe", 0.6)
    LFW.ring_of_petals(a, 4, R, R * 0.66, fc, "claw", cx=x, cy=y, k=k, start=start, lw=0.8)
    if veins:   # fine darker veins running out along each petal
        for i in range(4):
            t = T(x, y, start + 90 * i)
            for o in (-0.25, 0, 0.25):
                a.line(opath([M(t(R * u, o * R * 0.6 * u)) for u in (0.36, 0.62, 0.88)]), 0.4, 0.75, veins)
    LFW.stamens(a, x, y, 0.8, R * 0.3, 6, "sun", M, lw=0.4)
    a.oval(x, y - R * 0.05, R * 0.06, R * 0.14, 0, cen, 0.5)
    if sepals == "up":   # narrow upright sepals held close round the petal claws, seen under the flower
        b = (x, y + R * 0.78)
        for o in (-1, 1, 0):
            g = -90 + o * 9 + face * 0.3
            a.leaf(b[0] + o * R * 0.1, b[1], g, R * 0.62, 0.17, "unripe", lw=0.6, detail=False)
    return M


def crossbud(a, x, y, L, ang, col="unripe"):
    a.leaf(x, y, ang, L, 0.42, col, lw=0.7, detail=False)
    a.line(f"M{P(T(x, y, ang)(L * 0.2))} L{P(T(x, y, ang)(L * 0.9))}", 0.4, 0.5)


def fl_cross(a, sp):
    """Radish, turnip, swede, kohlrabi: four-petalled crosses at the top of a
    stem. mode "spike": a loose lengthening spike, young pods below (radish);
    "flat": the open flowers in a flat-topped cluster above the buds
    (turnip); "level": the buds level with or above the open flowers
    (swede, kohlrabi)."""
    fc = sp["fc"]; mode = sp.get("mode", "level"); top = (51, 50)
    a.ribbon((50, 98), (51, 76), top, 2.8, 2.2, "leaf", lw=0.9)
    budc = sp.get("budc", "unripe")
    buds = []
    if mode == "spike":
        a.line(f"M{P(top)} Q52,34 54,16", 1.3, 0.85)
        buds = [(54, 15, -84, 5), (51.5, 20, -125, 5), (56.5, 22, -50, 5)]
        for (x0, y0), sd in (((51, 72), -1), ((51, 84), 1)):   # young fat pods lower down, waisted between the seeds, with a beak
            fat_pod(a, x0, y0, sd, 1.6, sp.get("podc", "unripe"))
        flowers = [(30, 52, 16, -1), (72, 44, 16, 1), (49, 31, 13, 0)]
    elif mode == "flat":   # the open flowers held above a knot of buds in the middle
        flowers = [(26, 38, 15, -1), (74, 38, 15, 1), (37, 26, 14, -1), (63, 26, 14, 1)]
        buds = [(50, 40, -90, 6), (45.5, 42, -125, 5.5), (54.5, 42, -55, 5.5), (47, 46, -110, 5.5), (53, 46, -70, 5.5), (50, 46, -90, 5.5)]
    else:
        a.line(f"M{P(top)} L51,22", 1.2, 0.85)
        flowers = [(27, 52, 16, -1), (74, 50, 16, 1), (36, 37, 13, -1), (65, 36, 13, 1)]
        buds = [(51, 18, -90, 6), (47, 22, -118, 5.5), (55.5, 21, -62, 5.5), (46, 28, -140, 5.5), (56, 27, -40, 5.5), (51, 25, -90, 5.5)]
    for x, y, g, L in buds:
        a.line(f"M{f(51)},{f(max(y + 4, 22) if mode != 'flat' else top[1])} L{f(x)},{f(y)}", 0.6, 0.8)
    for x, y, R, sd in sorted(flowers, key=lambda q: q[1]):
        a.line(f"M{P(top)} Q{f((top[0] + x) / 2)},{f(max(top[1], y) + 3)} {f(x)},{f(y + R * 0.3)}", 0.9, 0.85)
    if mode != "flat":
        for x, y, g, L in buds:
            crossbud(a, x, y, L, g, budc)
    for x, y, R, sd in sorted(flowers, key=lambda q: q[1]):
        crossflower(a, x, y, R, fc, k=0.74, veins=sp.get("veins"), sepals=sp.get("sepals", "up"), face=sd * 10, start=-45 + sd * 12)
    if mode == "flat":
        for x, y, g, L in buds:
            crossbud(a, x, y, L, g, budc)
    return a


def fat_pod(a, x0, y0, sd, s, col):
    """A radish pod: fat, pointed, waisted between the seeds, with a long beak."""
    b = (x0 + sd * 2.4 * s, y0 - 1.2 * s)
    a.line(f"M{f(x0)},{f(y0)} L{P(b)}", 0.7, 0.85)
    g = -90 + sd * 42
    for j in range(3):
        p = T(*b, g)(2.0 * s + 2.6 * s * j); a.oval(p[0], p[1], 1.6 * s, 1.35 * s, g, col, 0.6)
    e0 = T(*b, g)(8.6 * s); e = T(*b, g)(11.4 * s)
    a.line(f"M{P(e0)} L{P(e)}", 0.7, 0.85)


def fl_ligulate(a, sp):
    """A head of strap-shaped florets only, no disc (salsify, scorzonera).
    bracts "star": salsify's long narrow green bracts reaching well beyond
    the florets; "cup": scorzonera's overlapping bracts, shorter than them."""
    LFW = _lfw(); fc = sp["fc"]; c = (50, 40); R = sp.get("R", 26); k = 0.55; M = LFW.tilt(c[1], k)
    star = sp.get("bracts", "star") == "star"
    if star:   # the stalk swollen into a club just below the head
        a.ribbon((52, 98), (51, 72), (50, c[1] + 10), 2.6, 6.4, "sage", lw=0.9)
    else:
        a.ribbon((52, 98), (51, 72), (50, c[1] + 18), 2.6, 3.0, "leaf", lw=0.9)
        for row in range(3):   # the overlapping bracts of the cup
            for j in range(6 - row):
                x = c[0] - 8 + 16 * (j + 0.5 * (row % 2)) / (5 - row); y = c[1] + 21 - row * 3.0
                LFW.blade(a, x, y, -90 + (x - c[0]) * 2.2, 10, 4.4, "leaf", "ovate", veins=0, petal=True, lw=0.6)
    n = sp.get("rays", 20)
    if star:   # the bracts behind
        for i in range(8):
            g = i * 45 + 22
            if math.sin(math.radians(g)) < 0.2:
                LFW.blade(a, c[0], c[1], g, R * 1.75, R * 0.13, "leaf", "lance", veins=0, M=M, lw=0.7, petal=True)
    for r, (sc, col) in enumerate(((1.0, fc), (0.72, fc), (0.45, sp.get("inner", fc)))):
        LFW.ring_of_petals(a, n - r * 5, R * sc, R * sc * 0.2, col, "ray", cx=c[0], cy=c[1], k=k, start=-90 + r * 7, tip="teeth", lw=0.6)
    a.oval(c[0], c[1], R * 0.14, R * 0.14 * k, 0, sp.get("inner", fc), 0.6)
    for j in range(9):   # the anther tubes standing up in the middle
        th = j * GOLD; rr = R * 0.2 * math.sqrt((j + 0.5) / 9)
        x, y = c[0] + rr * math.cos(th), c[1] + rr * math.sin(th) * k
        a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y - 2.4)}", 0.9, 0.9, sp.get("anth", "dark"))
        if j % 2 == 0:
            a.dot(x, y - 2.6, 0.55, "sun")   # pollen on the anther tubes
    if star:   # the bracts in front, reaching past the florets
        for i in range(8):
            g = i * 45 + 22
            if math.sin(math.radians(g)) >= 0.2:
                LFW.blade(a, c[0], c[1], g, R * 1.75, R * 0.13, "leaf", "lance", veins=0, M=M, lw=0.7, petal=True)
    return a


def fl_potato(a, sp):
    """Potato: five petals joined into a flat five-pointed star, a cone of
    bright yellow anthers in the middle with the green style at its tip."""
    fc = sp["fc"]; cen = sp.get("cen", "sun")
    stem = Quad((40, 98), (36, 70), (44, 62))
    a.ribbon(stem.p0, stem.c, stem.p1, 2.6, 2.2, "leaf", lw=0.9)
    for e, g in (((47, 46), -60), ((76, 70), -10)):
        a.line(f"M44,62 Q{f((44 + e[0]) / 2 + 2)},{f((62 + e[1]) / 2 + 3)} {P(e)}", 1.0, 0.85)
    a.line("M44,62 Q58,62 78,50", 0.9, 0.85)
    for x, y, g in ((78, 50, -20), (82, 46, -50)):
        a.leaf(x, y, g, 7, 0.5, "pale", lw=0.7, detail=False)
    potato_flower(a, 78, 74, 11, fc, cen, k=0.7, rot=20)
    potato_flower(a, 47, 42, 24, fc, cen, k=0.8, rot=0)
    return a


def potato_flower(a, x, y, R, fc, cen, k=0.84, rot=0):
    LFW = _lfw(); M = LFW.tilt(y, k)
    for i in range(5):   # the small pointed sepals, showing between the points
        g = -90 + rot + 72 * i + 36
        LFW.blade(a, x, y, g, R * 0.5, R * 0.16, "leaf", "lance", veins=0, M=M, lw=0.6, petal=True)
    pts = []
    for j in range(100):
        th = 2 * math.pi * j / 100; g = math.degrees(th) - (-90 + rot)
        ph = ((g % 72) + 72) % 72 / 72   # 0 at a point, 0.5 half-way between two
        r = R * (0.74 + 0.26 * (abs(ph - 0.5) * 2) ** 2.6)
        pts.append(M((x + r * math.cos(th), y + r * math.sin(th))))
    a.shape(path(pts), fc, 0.9)
    a.shape(path(pts[:50] + [M((x, y))]), "shade", 0, fa=0.06)
    for i in range(5):   # the midrib of each lobe out to its point, and a fold between
        g = -90 + rot + 72 * i; t = T(x, y, g)
        a.line(opath([M(t(R * u)) for u in (0.2, 0.6, 0.97)]), 0.6, 0.45)
        t2 = T(x, y, g + 36)
        a.line(opath([M(t2(R * u)) for u in (0.3, 0.6, 0.8)]), 0.4, 0.25)
    w = R * 0.21; h = R * 0.48   # the anthers, pressed together into a pointed cone
    a.shape(f"M{f(x - w)},{f(y + R * 0.06)} Q{f(x - w * 0.8)},{f(y - h * 0.5)} {f(x)},{f(y - h)} Q{f(x + w * 0.8)},{f(y - h * 0.5)} {f(x + w)},{f(y + R * 0.06)} Q{f(x)},{f(y + R * 0.14)} {f(x - w)},{f(y + R * 0.06)} Z", cen, 0.7)
    for o in (-0.45, 0.1, 0.6):
        a.line(f"M{f(x + o * w)},{f(y + R * 0.09)} L{f(x)},{f(y - h * 0.94)}", 0.4, 0.5)
    a.line(f"M{f(x)},{f(y - R * 0.44)} L{f(x)},{f(y - R * 0.56)}", max(0.6, R * 0.05), 0.95, "unripe")   # the style poking out
    a.dot(x, y - R * 0.58, max(0.4, R * 0.04), "unripe")


def sphere(n, seed=0.5):
    pts = []
    for i in range(n):
        z = 1 - 2 * (i + seed) / n; r = math.sqrt(max(0, 1 - z * z)); th = i * GOLD
        pts.append((r * math.cos(th), r * math.sin(th), z))
    return pts


def allium_flower(a, x, y, dx, dy, z, s, kind, fc, mid=None, anth="pear", stamens=False, lw=0.4):
    """One small flower of an onion head at x,y, facing out along dx,dy
    (z: how much it faces us). kind "star" (open, flat), "cup" or "bell"."""
    g = math.degrees(math.atan2(dy, dx)); side = math.sqrt(max(0.0, 1 - z * z))
    if kind == "bell":   # chives, Bristol onion: small upright bells of pointed tepals, seen from the side
        g = math.degrees(math.atan2(dy - 1.1, dx)); L = s * 1.45
        if stamens:
            for off in (-8, 8):
                e = T(x, y, g + off)(L * 1.3); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.3, 0.6); a.dot(e[0], e[1], 0.42, anth)
        for off in (-13, 13, 0):
            a.leaf(x, y, g + off, L, 0.3, fc, lw=lw, skew=0.5, detail=False)
            if mid:
                e0 = T(x, y, g + off)(L * 0.2); e1 = T(x, y, g + off)(L * 0.86)
                a.line(f"M{P(e0)} L{P(e1)}", 0.45, 0.9, mid)
        return
    if z > 0.5:   # seen from the front
        b = {"star": 0.4, "cup": 0.56, "bell": 0.5}[kind]; r = s * (1.0 if kind != "bell" else 0.75)
        if stamens and kind == "star":
            for k in range(6):
                e = T(x, y, g + 30 + 60 * k)(r * 1.25); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.3, 0.6); a.dot(e[0], e[1], 0.45, anth)
        a.flower(x, y, r, 6, fc, None, b, start=g, lw=lw)
        if mid:
            for k in range(6):
                e = T(x, y, g + 60 * k)(r * 0.72); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.35, 0.85, mid)
        if kind != "star":
            a.dot(x, y, max(0.45, r * 0.22), "shade" if kind == "bell" else (mid or "plum"))
        if stamens and kind == "cup":
            for k in range(3):
                e = T(x, y, g + 120 * k + 20)(r * 0.5); a.dot(e[0], e[1], 0.5, anth)
        if kind == "star":
            a.dot(x, y, max(0.4, s * 0.16), "unripe")
        return
    L = s * (1.5 if kind == "bell" else 1.25) * (0.5 + 0.5 * side)
    b = {"bell": 0.34, "cup": 0.5, "star": 0.3}[kind]
    if stamens:
        for off in (-12, 0, 12):
            e = T(x, y, g + off)(L * 1.4); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.3, 0.6); a.dot(e[0], e[1], 0.45, anth)
    for off in ((-28, 28, 0) if kind != "bell" else (-12, 12, 0)):
        a.leaf(x, y, g + off, L, b, fc, lw=lw, skew=0.55, detail=False)
        if mid:
            e0 = T(x, y, g + off)(L * 0.25); e1 = T(x, y, g + off)(L * 0.8)
            a.line(f"M{P(e0)} L{P(e1)}", 0.35, 0.85, mid)


def allium_spathe(a, sp, hb):
    """The papery spathe at the foot of an onion head."""
    sp_ = sp.get("spathe"); LFW = _lfw()
    if sp_ == "beak":   # split, staying on one side, drawn out into a long papery beak
        b0 = (hb[0] + 2, hb[1])
        if sp.get("shape") == "loose":   # garlic: a papery sheath wrapping the foot of the head, split, drawn out into a thin beak
            x0, y0 = hb[0], hb[1]
            a.shape(f"M{f(x0 - 5)},{f(y0 + 6)} Q{f(x0 - 6)},{f(y0)} {f(x0 - 3)},{f(y0 - 5)} L{f(x0 + 3)},{f(y0 - 5)} "
                    f"Q{f(x0 + 10)},{f(y0 - 14)} {f(x0 + 30)},{f(y0 - 40)} Q{f(x0 + 12)},{f(y0 - 10)} {f(x0 + 6)},{f(y0 + 1)} Q{f(x0 + 5)},{f(y0 + 5)} {f(x0 + 4)},{f(y0 + 6)} Z", "white", 0.8)
            for o in (-2.5, 0.5, 3.5):   # the fine papery veins
                a.line(f"M{f(x0 + o)},{f(y0 + 5)} Q{f(x0 + o + 1)},{f(y0 - 2)} {f(x0 + o * 0.6 + 2)},{f(y0 - 4)}", 0.4, 0.5, "straw")
            a.line(f"M{f(x0 + 4)},{f(y0 - 4)} Q{f(x0 + 12)},{f(y0 - 13)} {f(x0 + 27)},{f(y0 - 37)}", 0.4, 0.55, "straw")
        else:   # leek: falling from under the head, its long beak hanging
            a.shape(f"M{f(b0[0] - 3)},{f(b0[1] - 2)} Q{f(b0[0] + 10)},{f(b0[1] - 2)} {f(b0[0] + 12)},{f(b0[1] + 8)} Q{f(b0[0] + 16)},{f(b0[1] + 20)} {f(b0[0] + 24)},{f(b0[1] + 30)} Q{f(b0[0] + 9)},{f(b0[1] + 16)} {f(b0[0] + 2)},{f(b0[1] + 8)} Q{f(b0[0] - 2)},{f(b0[1] + 4)} {f(b0[0] - 3)},{f(b0[1] - 2)} Z", "straw", 0.8)
            a.line(f"M{f(b0[0] + 2)},{f(b0[1] + 1)} Q{f(b0[0] + 11)},{f(b0[1] + 8)} {f(b0[0] + 22)},{f(b0[1] + 28)}", 0.4, 0.4)
    elif sp_ in ("back", "fall"):
        for sg in (-1, 1):
            g = 90 + sg * (40 if sp_ == "back" else 20); L = 10 if sp_ == "back" else 14
            LFW.blade(a, hb[0] + sg * 1.5, hb[1] - 1, g, L, L * 0.45, sp.get("spathec", "straw"), "lance", veins=0, petal=True, lw=0.7)


def fl_allium(a, sp):
    """A round head of many small flowers on stalks from one point: leek,
    onion, spring onion, chives, garlic, Bristol onion, wild garlic.
    shape "ball", "egg" (dense, the flowers too close to see their stalks)
    or "loose" (flowers on long stalks spreading up and out); flower "star",
    "cup" or "bell"; spathe "beak" (a long papery beak), "back" (short lobes
    folded back) or "fall" (split and falling); bulbils: garlic's small
    bulbils among the flowers; topc: the lowest buds still this colour (Bristol onion)."""
    fc = sp["fc"]; R = sp.get("R", 28); c = sp.get("c", (50, 40)); shape = sp.get("shape", "ball")
    kind = sp.get("flower", "star"); n = sp.get("n", 70); mid = sp.get("mid"); st = sp.get("stamens", False)
    ry = R * (sp.get("egg", 1.22) if shape == "egg" else 1.0)
    loose = shape == "loose"
    stemtop = (c[0], c[1] + (ry * 0.78 if not loose else R * 0.25))
    a.ribbon((51, 98), (51, 76), stemtop, sp.get("sw", 3.0), sp.get("sw", 3.0) * 0.86, sp.get("stemc", "leaf"), lw=0.9)
    s0 = sp.get("s", 4.5)
    hb = stemtop if loose else (c[0], c[1] + ry * 0.86)   # the foot of the head, where the spathe is
    if loose:
        allium_spathe(a, sp, hb)
        pts = [(x, -abs(y) * 0.8 - 0.2, z) for x, y, z in sphere(n)]
        bul = sp.get("bulbils")
        for x, y, z in sorted(pts, key=lambda p: p[2]):
            e = (c[0] + x * R, c[1] + y * R)
            a.line(f"M{P(stemtop)} Q{f((stemtop[0] + e[0]) / 2)},{f((stemtop[1] + e[1]) / 2 + 2)} {P(e)}", 0.45, 0.75)
        if bul:   # garlic: a tight cluster of purplish-green bulbils at the foot of the flower stalks
            for j in range(11):
                th = j * GOLD; rr = 7 * math.sqrt((j + 0.5) / 11)
                x, y = stemtop[0] + rr * math.cos(th), stemtop[1] - 3 + rr * 0.6 * math.sin(th)
                a.oval(x, y, 2.6, 3.2, (x - c[0]) * 3, bul, 0.7)
                a.line(f"M{f(x - 0.8)},{f(y - 1)} Q{f(x)},{f(y - 2.6)} {f(x + 0.4)},{f(y - 3.4)}", 0.5, 0.45, "plum")
        for x, y, z in sorted(pts, key=lambda p: p[2]):
            e = (c[0] + x * R, c[1] + y * R)
            allium_flower(a, e[0], e[1], x, y - 0.6, max(z, 0.3 * z + 0.45), s0 * (0.8 + 0.2 * (z + 1) / 2), kind, fc, mid, sp.get("anth", "pear"), st)
        return a
    a.shape(path([(c[0] + R * 0.9 * math.cos(h), c[1] + ry * 0.9 * math.sin(h)) for h in [2 * math.pi * i / 60 for i in range(60)]]),
            sp.get("bodyc", fc), 0.6)
    a.shape(path([(c[0] + R * 0.9 * math.cos(h), c[1] + ry * 0.9 * math.sin(h)) for h in [math.pi * (-0.1 + 1.1 * i / 30) for i in range(31)]] + [(c[0] - R * 0.2, c[1])]), "shade", 0, fa=0.1)
    for x, y, z in sorted(sphere(n), key=lambda p: p[2]):
        if z < -0.15:
            continue
        e = (c[0] + x * R, c[1] + y * ry)
        s = s0 * (0.8 + 0.2 * (z + 1) / 2)
        if sp.get("topc") and y > 0.5:   # still in bud at the foot of the head
            a.oval(e[0], e[1], s * 0.45, s * 0.58, 0, sp["topc"], 0.45); continue
        allium_flower(a, e[0], e[1], x, y, z, s, kind, fc, mid, sp.get("anth", "pear"), st and z < 0.75, sp.get("lw", 0.4))
    allium_spathe(a, sp, hb)
    return a


BLOOM_DRAW = {"roots_umbel": fl_umbel, "roots_celeriac": fl_celeriac, "roots_beetspike": fl_beetspike, "roots_cross": fl_cross,
              "roots_ligulate": fl_ligulate, "roots_potato": fl_potato, "roots_allium": fl_allium}

BLOOMX = {
    "carrot": dict(kind="roots_umbel", fc="white", bracts="fork", rim=True, dark="beet"),
    "parsnip": dict(kind="roots_umbel", fc="sun", rays=10, dots="amber"),
    "celeriac": dict(kind="roots_celeriac", fc="white"),
    "beetroot": dict(kind="roots_beetspike"),
    "mangelwurzel": dict(kind="roots_beetspike"),
    "radish": dict(kind="roots_cross", mode="spike", veins="plum", sepals="up"),
    "turnip": dict(kind="roots_cross", mode="flat", sepals="out"),
    "swede": dict(kind="roots_cross", mode="level", sepals="up"),
    "kohlrabi": dict(kind="roots_cross", mode="level", sepals="up"),
    "salsify": dict(kind="roots_ligulate", bracts="star", inner="plum", anth="dark", R=27),
    "scorzonera": dict(kind="roots_ligulate", bracts="cup", anth="amber", R=28),
    "potatoes": dict(kind="roots_potato"),
    "leek": dict(kind="roots_allium", fc="roots_lilacpale", flower="cup", stamens=True, spathe="beak", n=120, s=4.4, anth="plum", sw=3.4,
                 mid="plum", R=30, c=(48, 40)),
    "onion": dict(kind="roots_allium", fc="white", flower="star", stamens=True, spathe="back", mid="unripe", n=95, s=4.4, R=27,
                  bodyc="pale"),
    "spring-onion": dict(kind="roots_allium", fc="white", flower="star", stamens=True, spathe="back", n=80, s=4.4, R=25, bodyc="pale"),
    "chives": dict(kind="roots_allium", fc="mauve", flower="bell", spathe="back", spathec="lilac", mid="plum", n=90, s=5.6, R=21,
                   shape="egg", egg=1.1, sw=2.4, c=(50, 42)),
    "garlic": dict(kind="roots_allium", fc="pink", flower="star", shape="loose", spathe="beak", n=16, s=5.0, R=24, bulbils="unripe",
                   sw=2.6, c=(46, 42), mid="mauve"),
    "bristol-onion": dict(kind="roots_allium", fc="beet", flower="bell", stamens=True, anth="plum", spathe="back", n=130, s=3.4, R=17,
                          shape="egg", topc="unripe", sw=2.2, lw=0.35),
    "wild-garlic": dict(kind="roots_allium", fc="white", flower="star", shape="loose", spathe="fall", spathec="white", n=16, s=7.5,
                        stamens=True, anth="primrose", R=26, c=(50, 42)),
    "shallot": None,
}


# ===================================================== life-stage pieces
_OWN = {}
DRYC = ("leaf", "deep", "sage", "pale", "unripe", "beet", "white", "berry", "plum")


def own(slug):
    if slug not in _OWN:
        _OWN[slug] = _lfw().own_leaf(slug)
    return _OWN[slug]


def carrot_small(a, x, y, ang, L, fill="deep"):
    """A carrot leaf as it is drawn on the whole plant: long stalk, pairs of
    divisions, triangular outline, as the close-up. Each division is cut
    again into narrow pointed lobes (seg), as in the close-up but with
    fewer, so it stays feathery and does not turn into a dark blot."""
    t = T(x, y, ang)
    q = a.stem(t(0), t(L * 0.5, L * 0.04), t(L), 0.7)
    for i in range(4):
        u = 0.36 + 0.56 * i / 3; px, py = q.pt(u); g = q.ang(u); l = L * 0.34 * (1.2 - u * 0.95)
        for sd in (1, -1):
            seg(a, px, py, g + sd * 50, l, fill, lw=0.18)
    ex, ey = q.pt(1); seg(a, ex, ey, q.ang(1), L * 0.16, fill, lw=0.18)


def potato_small(a, x, y, ang, L, fill="deep"):
    """A potato leaf as it is drawn on the whole plant: two pairs of large
    broad oval pointed leaflets and a big end leaflet, a pair of small
    leaflets between them. The close-up's wrinkles are too fine to keep."""
    t = T(x, y, ang)
    q = a.stem(t(0), t(L * 0.5, L * 0.04), t(L * 0.7), 0.8)
    for u, l in ((0.45, 0.36), (0.85, 0.34)):
        px, py = q.pt(u); g = q.ang(u)
        for sd in (1, -1):
            a.leaf(px, py, g + sd * 55, L * l, 0.62, fill, lw=0.6, skew=0.4, vein=True)
    px, py = q.pt(0.66); g = q.ang(0.66)
    for sd in (1, -1):   # the small leaflets between
        a.leaf(px, py, g + sd * 85, L * 0.13, 0.6, fill, lw=0.5, detail=False)
    ex, ey = q.pt(1); a.leaf(ex, ey, q.ang(1), L * 0.42, 0.62, fill, lw=0.6, skew=0.4, vein=True)


def beet_small(a, x, y, ang, L, fill, sc, vc):
    """A beet leaf as it is drawn on the whole plant: the stalk and midrib
    thick and clearly the stalk colour (red in beetroot), an oval wavy blade."""
    t = T(x, y, ang)
    a.leaf(*t(L * 0.36), ang, L * 0.66, 0.5, fill, lw=0.65, skew=0.52, detail=False)
    a.ribbon(t(0), t(L * 0.2, 0.3), t(L * 0.38), max(1.8, L * 0.075), max(1.4, L * 0.06), sc, lw=0.5)
    a.ribbon(t(L * 0.36), t(L * 0.6), t(L * 0.9), max(1.3, L * 0.05), 0.4, sc, lw=0)
    for u in (0.5, 0.64, 0.78):   # side veins
        for sd in (1, -1):
            a.line(f"M{P(t(L * u))} L{P(t(L * (u + 0.1), sd * L * 0.13 * (1.1 - u)))}", 0.6, 0.9, vc)


def put(a, slug, x, y, ang, L, fills=None, detail=None, lw=None, dry=False):
    """The kind's own close-up leaf drawn L long at x,y, pointing along ang."""
    if slug == "carrot":   # see carrot_small
        return carrot_small(a, x, y, ang, L, "straw" if dry else (fills or {}).get("deep", "deep"))
    if slug in ("beetroot", "mangelwurzel"):   # see beet_small
        red = slug == "beetroot"
        return beet_small(a, x, y, ang, L, "straw" if dry else (fills or {}).get(pal(slug, "leaf", "deep"), pal(slug, "leaf", "deep")),
                          "straw" if dry else ("beet" if red else "pale"), "beet" if red and not dry else "pale")
    if slug == "potatoes":   # see potato_small
        return potato_small(a, x, y, ang, L, "straw" if dry else (fills or {}).get("deep", "deep"))
    src, f0 = own(slug)
    if dry:
        fills = {c: "straw" for c in DRYC}
    if lw is None:
        lw = 0.55 if slug in ("parsnip", "celeriac", "potatoes") else (0.65 if L < 30 else 0.8)
    a.place(src, x, y, ang, L / 92, lw=lw, detail=(L >= 24) if detail is None else detail, fills=fills)


def tuft(a, slug, x, y, leaves, **kw):
    """Several of the kind's own leaves from one point: (angle, length) each."""
    for ang, L in leaves:
        put(a, slug, x, y, ang, L, **kw)


def soil(a, y, marks=True):
    a.ground(y, marks=marks)


def below(a, y0=40):
    """The flecks of soil under the line, for a picture that is mostly underground."""
    for dx, dy, w in [(-30, 6, 4), (27, 10, 3), (-24, 40, 3), (28, 36, 4)]:
        a.line(f"M{50 + dx},{y0 + dy} L{50 + dx + w},{y0 + dy}", 0.9, 0.55, "soil")


def bez(p0, c1, c2, p1, t):
    u = 1 - t
    return (u ** 3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t ** 3 * p1[0],
            u ** 3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t ** 3 * p1[1])


def taproot(a, x, y, w, L, fill, s1=0.9, k1=0.45, s2=0.3, k2=0.82, rings=4, rootlets=0, crown=None, tail=5, broken=None):
    """A long tapering root hanging from x,y (its shoulders), w wide and L
    long. s1,k1 and s2,k2 shape its sides (broad shoulders: small k1).
    rings: faint rings across it; rootlets: fine side roots; crown "sunken":
    the hollow at the top that the leaves rise from (parsnip); broken:
    the root snapped near its foot, showing the flesh colour."""
    h = w / 2
    R = ((x + h, y + 1), (x + h * s1, y + L * k1), (x + h * s2, y + L * k2), (x, y + L))
    Lf = ((x - h, y + 1), (x - h * s1, y + L * k1), (x - h * s2, y + L * k2), (x, y + L))
    end = 1.0 if not broken else broken
    rs = [bez(*R, t * end) for t in [i / 30 for i in range(31)]]; ls = [bez(*Lf, t * end) for t in [i / 30 for i in range(31)]]
    top = f"M{f(x - h)},{f(y + 1)} C{f(x - h)},{f(y - w * 0.3)} {f(x + h)},{f(y - w * 0.3)} {f(x + h)},{f(y + 1)} "
    if tail and not broken:
        a.line(f"M{f(x)},{f(y + L - 1)} Q{f(x + 1)},{f(y + L + tail * 0.6)} {f(x + 0.4)},{f(y + L + tail)}", 0.7, 0.8, fill if fill not in ("white", "seed", "pale") else "line")
    a.shape(top + " L" + " L".join(P(p) for p in rs[1:]) + " L" + " L".join(P(p) for p in ls[::-1][:-1]) + " Z", fill)
    a.shape("M" + " L".join(P(p) for p in rs) + " " + " L".join(P((x + (p[0] - x) * 0.1, p[1])) for p in rs[::-1]) + " Z", "shade", 0, fa=0.12)
    if broken:   # the snapped end: the flesh inside
        e1, e0 = rs[-1], ls[-1]; mx, my = (e0[0] + e1[0]) / 2, (e0[1] + e1[1]) / 2
        pass
    for k in range(rings):
        u = 0.14 + 0.7 * (k + 0.5) / rings
        pl, pr = bez(*Lf, u), bez(*R, u); sd = -1 if k % 2 else 1
        a0_, a1_ = (pl, pr) if sd > 0 else (pr, pl)
        e = (a0_[0] + (a1_[0] - a0_[0]) * 0.55, a0_[1] + 1.2)
        a.line(f"M{P(a0_)} Q{f((a0_[0] + e[0]) / 2)},{f(e[1] + 0.6)} {P(e)}", 0.6, 0.45)
    for k in range(rootlets):
        u = 0.25 + 0.65 * k / max(1, rootlets - 1); sd = 1 if k % 2 else -1
        p = bez(*(R if sd > 0 else Lf), u)
        a.line(f"M{P(p)} q{f(sd * 2.2)},{f(0.6)} {f(sd * 4.2)},{f(2.4)}", 0.5, 0.75, "soil")
    if crown == "sunken":
        a.shape(f"M{f(x - h * 0.55)},{f(y - w * 0.12)} Q{f(x)},{f(y + w * 0.1)} {f(x + h * 0.55)},{f(y - w * 0.12)} Q{f(x)},{f(y - w * 0.26)} {f(x - h * 0.55)},{f(y - w * 0.12)} Z", "shade", 0.6, fa=0.18)
    return rs, ls


broken_c = "white"


def globe(a, x, cy, rx, ry, fill, top=None, soil_y=None, p=2.0, taper=0.0, knob=0.0, flat=0.0, tail=8, tailc=None, lw=1.15):
    """A round root (beetroot, turnip, swede) or barrel (mangel). top: the
    colour of the part above soil_y. p above 2 squares it off into a
    barrel; taper narrows its foot; knob makes it knobbly; flat flattens
    its top."""
    pts = []
    for i in range(80):
        th = 2 * math.pi * i / 80; c, s_ = math.cos(th), math.sin(th)
        r = 1 / ((abs(c) ** p + abs(s_) ** p) ** (1 / p))
        r *= 1 + knob * (0.6 * math.sin(7 * th + 1) + 0.4 * math.sin(11 * th))
        xx = rx * r * c * (1 - taper * max(0.0, s_)); yy = ry * r * s_ * (1 - flat * max(0.0, -s_))
        pts.append((x + xx, cy + yy))
    if tail:
        bot = max(pts, key=lambda q: q[1])
        a.line(f"M{f(x)},{f(bot[1] - 1)} Q{f(x + 1.4)},{f(bot[1] + tail * 0.5)} {f(x + 0.3)},{f(bot[1] + tail)}", 0.8, 0.85, tailc or ("line" if fill in ("white", "seed", "pale", "pear") else fill))
    a.shape(path(pts), fill, lw)
    if top and soil_y is not None:   # the part that grew in the light
        up = [q for q in pts if q[1] < soil_y]
        if up:
            # walk the outline round from where it crosses the soil line on one side to the other
            idx = [i for i, q in enumerate(pts) if q[1] < soil_y]
            start = next(i for i in idx if pts[(i - 1) % 80][1] >= soil_y)
            seq = []
            j = start
            while pts[j % 80][1] < soil_y:
                seq.append(pts[j % 80]); j += 1
            a.shape(path(seq + [(seq[-1][0], soil_y + 1.5), (x, soil_y + 3), (seq[0][0], soil_y + 1.5)]), top, 0)
            a.shape(path(pts), None, lw)
    a.shape(path(pts[60:] + pts[:20] + [(x + rx * 0.2, cy)]), "shade", 0, fa=0.1)
    a.line(f"M{f(x - rx * 0.62)},{f(cy - ry * 0.3)} Q{f(x - rx * 0.75)},{f(cy + ry * 0.1)} {f(x - rx * 0.6)},{f(cy + ry * 0.45)}", 0.6, 0.35)
    return pts


def round_seeds(a, x, y, col, r=5.5, ridged=False):
    """A few small round seeds, drawn large."""
    for dx, dy, k in ((-9, 2, 1.0), (7, -3, 1.1), (2, 9, 0.9)):
        rr = r * k
        a.polar(x + dx, y + dy, lambda h: 1 + 0.04 * math.cos(3 * h), rr, rr * 0.92, dx * 4, col)
        if ridged:
            for o in (-0.45, 0, 0.45):
                a.line(f"M{f(x + dx + o * rr - rr * 0.2)},{f(y + dy - rr * 0.8)} Q{f(x + dx + o * rr * 1.2)},{f(y + dy)} {f(x + dx + o * rr - rr * 0.1)},{f(y + dy + rr * 0.8)}", 0.6, 0.5)
        else:
            a.line(f"M{f(x + dx - rr * 0.5)},{f(y + dy - rr * 0.3)} Q{f(x + dx - rr * 0.2)},{f(y + dy - rr * 0.7)} {f(x + dx + rr * 0.3)},{f(y + dy - rr * 0.6)}", 0.6, 0.4, "white" if col == "dark" else "line")


def seed_art(fn):
    def draw():
        a = Art(); a.ground(40, marks=False); below(a); fn(a, 50, 63); return a
    return draw


def cotyledons(a, x, y, kind, col, L=11, h=12, w=1.3):
    """Seed leaves on a short stem: kind "kidney" (cabbage family, notched at
    the tip), "strap" (beet, carrot), "oval", "grass"."""
    a.ribbon((x, y), (x - 0.6, y - h * 0.5), (x, y - h), 1.5, 1.2, col if kind != "kidney" else "pale", lw=0.8)
    top = (x, y - h)
    for sd in (-1, 1):
        g = -90 + sd * 72
        if kind == "kidney":
            e = T(*top, g)(3.2); a.line(f"M{P(top)} L{P(e)}", 0.9, 0.85)
            c = T(*e, g)(L * 0.5)
            a.polar(c[0], c[1], lambda th: (1 - 0.32 * math.exp(-((th) / 0.32) ** 2)) * (1 - 0.25 * math.exp(-((abs(th) - math.pi) / 0.5) ** 2)),
                    L * 0.48, L * 0.58, g, col)
        elif kind == "strap":   # long and very narrow, grass-like
            e = T(*top, -90 + sd * 62)(L * 1.5); m = T(*top, -90 + sd * 50)(L * 0.75)
            a.ribbon(top, m, e, w, 0.35, col, lw=0.8)
        else:
            a.leaf(top[0], top[1], -90 + sd * 66, L, 0.4, col)
    return top


# ---------------------------------------------- foot and colour bands on a root
def foot(a, pts, y0, col):
    """Paints the part of a root outline below y0 in another colour (a radish's white tip)."""
    low = [q for q in pts if q[1] > y0]
    if len(low) > 3:
        low.sort(key=lambda q: math.atan2(q[1] - y0, q[0] - sum(p[0] for p in pts) / len(pts)))
        a.shape(path(low), col, 0)


def grass(a, x, y, ends, col, w=3.0, curl=True):
    """Grass-like leaves from one point, each tapering to a fine point."""
    for ex, ey in ends:
        c = ((x + ex) / 2 + (ex - x) * 0.15, (y + ey) / 2 + 2)
        a.ribbon((x, y), c, (ex, ey), w, 0.3, col, lw=0.9)


# ------------------------------------------------------------------ carrot
def carrot_seed(a, x, y):
    """A carrot fruit-half: a small oval, ridged, with rows of hooked
    bristles along the ridges on its face."""
    t = T(x, y, -18)
    a.oval(x, y, 13, 7.5, -18, "seed")
    for o in (-4.2, -1.4, 1.4, 4.2):   # the ridges
        L = 10.5 * math.sqrt(max(0.0, 1 - (o / 7.6) ** 2))
        a.line(f"M{P(t(-L, o))} Q{P(t(0, o * 1.15))} {P(t(L, o))}", 0.6, 0.55)
        if abs(o) > 2:   # a row of bristles along the ridge
            for k in range(7):
                v = -L * 0.85 + 1.7 * L * k / 6; p = t(v, o * (1 + 0.15 * (1 - (v / L) ** 2)))
                e = t(v + 0.6, o * 1.02 + (2.8 if o > 0 else -2.8)); a.line(f"M{P(p)} L{P(e)}", 0.65, 0.9)
                a.line(f"M{P(e)} l{f(-0.5)},{f(0.4 if o > 0 else -0.4)}", 0.4, 0.8)


def carrot_seedling():
    a = Art(); soil(a, 72); a.line("M50,72 Q51.5,79 50,86", 0.9, 0.85, "soil")
    cotyledons(a, 50, 72, "strap", "pale", L=11, h=14)
    e = (51, 45); a.line(f"M50,58 Q51.5,52 {P(e)}", 0.8)   # the first true leaf, already finely cut
    for g in (-150, -90, -30):
        seg(a, e[0], e[1], g, 8, "deep")
    return a


CARROT_TUFT = [(-140, 27), (-118, 31), (-98, 33), (-80, 33), (-62, 31), (-40, 27)]


def carrot_young():
    a = Art(); soil(a, 72)
    tuft(a, "carrot", 50, 69, [(g, L * 0.8) for g, L in CARROT_TUFT[1:-1]])
    taproot(a, 50, 69, 6.5, 24, "carrot", rings=0, tail=4)
    return a


def carrot_crop():
    a = Art(); soil(a, 45)
    tuft(a, "carrot", 50, 43, CARROT_TUFT)
    taproot(a, 50, 44, 18, 47, "carrot", rings=4, rootlets=6, tail=5)
    return a


# ----------------------------------------------------------------- parsnip
def parsnip_seed(a, x, y):
    """A flat oval papery disc with a narrow pale wing all round and thin
    dark oil lines running lengthwise down its face."""
    a.oval(x, y, 12.5, 15.5, 12, "white")          # the papery wing all round
    a.oval(x, y, 9.6, 12.6, 12, "straw", 0.8)      # the seed in the middle
    t = T(x, y, 12 + 90)
    for o in (-4.8, -1.6, 1.6, 4.8):   # the oil lines, running from end to end
        L = 11.4 * math.sqrt(max(0.0, 1 - (o / 9.4) ** 2))
        a.line(f"M{P(t(-L, o))} Q{P(t(0, o * 1.06))} {P(t(L, o))}", 0.7, 0.9, "dark")


def parsnip_seedling():
    a = Art(); soil(a, 72); a.line("M50,72 Q51.5,79 50,86", 0.9, 0.85, "soil")
    cotyledons(a, 50, 72, "strap", "pale", L=13, h=13, w=2.2)
    a.line("M50,59 Q52,52 52,46", 0.8)
    leaflet(a, 52, 46, -86, 13, 12, "leaf", "parsnip_end", lw=0.8, veins=2)   # the first true leaf: one broad lobed leaflet
    return a


PARSNIP_TUFT = [(-136, 32), (-110, 40), (-84, 42), (-58, 36)]


def parsnip_young():
    a = Art(); soil(a, 72)
    tuft(a, "parsnip", 50, 70, [(g, L * 0.8) for g, L in PARSNIP_TUFT])
    taproot(a, 50, 70, 8, 20, "white", s1=0.8, k1=0.3, s2=0.25, k2=0.7, rings=0, tail=4)
    return a


def parsnip_crop():
    a = Art(); soil(a, 45)
    tuft(a, "parsnip", 50, 41, [(g, L * 0.8) for g, L in PARSNIP_TUFT])
    taproot(a, 50, 44, 24, 47, "white", s1=0.72, k1=0.22, s2=0.18, k2=0.62, rings=4, rootlets=6, crown="sunken", tail=5)
    return a


# ---------------------------------------------------------------- celeriac
def celeriac_seed(a, x, y):
    round_seeds(a, x, y, "bark", r=4.6, ridged=True)


def celeriac_seedling():
    a = Art(); soil(a, 72); a.roots(50, 72, 3, 10, 50)
    cotyledons(a, 50, 72, "oval", "pale", L=8, h=8)
    a.line("M50,64 Q51,58 52,52", 0.8)
    leaflet(a, 52, 52, -84, 10, 10, "deep", "celeriac", lw=0.8, veins=0)
    return a


CEL_TUFT = [(-148, 32), (-118, 38), (-90, 42), (-62, 38), (-32, 32)]


def celeriac_young():
    a = Art(); soil(a, 72); a.roots(50, 76, 6, 9, 120)
    tuft(a, "celeriac", 50, 69, [(g, L * 0.72) for g, L in CEL_TUFT])
    globe(a, 50, 72, 6, 4.6, "seed", tail=0)
    return a


def celeriac_crop():
    a = Art(); soil(a, 56)
    for k in range(9):   # the dense tangle of roots underneath
        x0 = 50 + (k - 4) * 3.2; g = 90 + (k - 4) * 15
        e = T(x0, 66, g)(16 + 6 * (k % 3)); m = T(x0, 66, g + (12 if k % 2 else -12))(9)
        a.line(f"M{f(x0)},66 Q{P(m)} {P(e)}", 0.8, 0.8, "soil")
        a.line(f"M{P(m)} l{f(-3 if k % 2 else 3)},{f(5)}", 0.6, 0.65, "soil")
    tuft(a, "celeriac", 50, 44, [(g, L * 0.86) for g, L in CEL_TUFT])
    globe(a, 50, 56, 17, 13, "seed", knob=0.03, flat=0.15, tail=0)
    for dx, dy in ((-12, -5), (11, -6), (-6, -9.5), (6, -10), (14, 1), (-15, 2)):   # scars on the shoulders where old leaves fell
        a.shape(f"M{f(50 + dx - 2.4)},{f(56 + dy)} q2.4,2 4.8,0 q-2.4,1 -4.8,0 Z", "bark", 0.7)
    for dx in (-5, 0, 5):   # stalk bases on top
        a.ribbon((50 + dx * 0.6, 46), (50 + dx * 0.8, 44), (50 + dx, 41), 2.6, 2.2, "deep", lw=0.8)
    return a


# --------------------------------------------------------- beet and mangel
def beet_seedling(stem):
    def draw():
        a = Art(); soil(a, 72)
        for dx, h, L, lean in ((-7, 10, 9, -6), (6, 14, 11, 5), (0.5, 8, 8, 0)):
            x = 50 + dx * 0.4
            a.roots(x, 72, 2, 8, 30)
            a.ribbon((x, 72), (x + lean * 0.3, 72 - h * 0.5), (50 + dx, 72 - h), 1.3, 1.1, stem, lw=0.7)
            for sd in (-1, 1):
                a.leaf(50 + dx, 72 - h, -90 + sd * 62 + lean * 2, L * 1.25, 0.14, "pale", lw=0.8)
        return a
    return draw


def beet_young(slug, root, rx, ry):
    def draw():
        a = Art(); soil(a, 72)
        lv = [(-138, 24), (-112, 28), (-88, 30), (-64, 28), (-40, 24)]
        tuft(a, slug, 50, 68, lv)
        sc = "pale" if slug == "mangelwurzel" else "beet"
        for g, L in lv:   # the thick fleshy stalks
            e = T(50, 68, g)(L * 0.36); a.ribbon((50, 68), T(50, 68, g)(L * 0.18), e, 2.6, 1.8, sc, lw=0.7)
        globe(a, 50, 70, rx, ry, root, tail=7)
        return a
    return draw


def beetroot_crop():
    a = Art(); soil(a, 62)
    tuft(a, "beetroot", 50, 50, [(-150, 32), (-126, 38), (-104, 42), (-80, 42), (-56, 38), (-32, 32)])
    globe(a, 50, 60, 13.5, 13, "beet", tail=24, taper=0.08)
    return a


def mangel_crop():
    a = Art(); soil(a, 77)
    tuft(a, "mangelwurzel", 50, 44, [(-154, 30), (-128, 34), (-104, 37), (-76, 37), (-52, 34), (-26, 30)])
    pts = globe(a, 50, 65, 16, 21, "seed", top="rust", soil_y=77, p=2.7, taper=0.3, tail=12, tailc="line")
    return a


# ------------------------------------------------- radish, turnip, swede, kohlrabi
def crucifer_seedling(cot, true_leaf):
    def draw():
        a = Art(); soil(a, 72); a.roots(50, 72, 3, 11, 44)
        top = cotyledons(a, 50, 72, "kidney", cot, L=11, h=10)
        if true_leaf:   # the first true leaf: oval, rough and toothed
            a.line(f"M{P(top)} L{f(top[0] + 0.6)},{f(top[1] - 5)}", 0.8)
            a.leaf(top[0] + 0.6, top[1] - 5, -84, 10, 0.4, true_leaf, lw=0.8, edge="scallop")
        return a
    return draw


def radish_young():
    a = Art(); soil(a, 72)
    tuft(a, "radish", 50, 71, [(-162, 22), (-130, 25), (-104, 26), (-78, 26), (-50, 25), (-18, 22)])
    globe(a, 50, 72.5, 4.2, 3.8, "berry", tail=5, tailc="line")
    return a


def radish_crop():
    a = Art(); soil(a, 48)
    tuft(a, "radish", 50, 46, [(-160, 26), (-132, 30), (-106, 33), (-80, 33), (-52, 30), (-22, 26)])
    pts = globe(a, 50, 55, 10, 9.6, "berry", tail=0)
    foot(a, pts, 61.5, "white")
    a.shape(path(pts), None, 1.15)
    a.line("M50,64.4 Q51.6,72 50.4,80 Q49.6,85 50.6,89", 0.8, 0.85)   # the thin white tail root
    return a


def turnip_young():
    a = Art(); soil(a, 72)
    tuft(a, "turnip", 50, 69, [(-140, 26), (-114, 30), (-90, 32), (-66, 30), (-40, 26)])
    globe(a, 50, 71.5, 6, 4.8, "white", tail=6)
    return a


def turnip_crop():
    a = Art(); soil(a, 62)
    tuft(a, "turnip", 50, 50, [(-150, 32), (-126, 37), (-102, 40), (-78, 40), (-54, 37), (-30, 32)])
    globe(a, 50, 62, 17, 13.5, "white", top="plum", soil_y=62, flat=0.18, tail=16)
    return a


def swede_young():
    a = Art(); soil(a, 72)
    tuft(a, "swede", 50, 66, [(-140, 26), (-114, 30), (-90, 32), (-66, 30), (-40, 26)])
    a.ribbon((50, 70), (50, 68), (50, 65.5), 3.4, 2.8, "plum", lw=0.8)
    globe(a, 50, 72, 7, 5.6, "pear", top="plum", soil_y=72, tail=6)
    return a


def swede_crop():
    a = Art(); soil(a, 66)
    tuft(a, "swede", 50, 37, [(-152, 27), (-126, 30), (-102, 31.5), (-78, 31.5), (-54, 30), (-28, 27)])
    a.ribbon((50, 52), (50, 45), (50, 37), 10, 7, "plum", lw=1.0)   # the neck, ringed with leaf scars
    for y in (49, 45.5, 42, 39):
        a.line(f"M{f(50 - (4.6 - (52 - y) * 0.12))},{f(y)} Q50,{f(y + 1.6)} {f(50 + (4.6 - (52 - y) * 0.12))},{f(y)}", 0.6, 0.65)
    a.roots(50, 80, 3, 9, 120)
    globe(a, 50, 66, 18.5, 15, "pear", top="plum", soil_y=66, tail=14)
    return a


def kohlrabi_young():
    a = Art(); soil(a, 82); a.roots(50, 83, 4, 7, 100)
    a.ribbon((50, 83), (50, 80), (50, 77), 2.4, 2.4, "unripe", lw=0.8)
    for g, L in ((-150, 24), (-118, 30), (-90, 32), (-62, 30), (-30, 24)):
        put(a, "kohlrabi", 50 + math.cos(math.radians(g)) * 3, 74 + math.sin(math.radians(g)) * 2.4, g, L)
    a.oval(50, 74, 5, 4, 0, "unripe", 0.9)
    return a


def kohlrabi_crop():
    a = Art(); soil(a, 86); a.roots(50, 87, 5, 9, 110)
    a.ribbon((50, 87), (50, 85), (50, 82), 3.4, 3.2, "unripe", lw=0.9)   # the short stem under the ball
    c = (50, 68); R = 15
    for g, L in ((-168, 30), (-140, 38), (-112, 42), (-90, 44), (-68, 42), (-40, 38), (-12, 30)):
        st = (c[0] + R * 0.8 * math.cos(math.radians(g)), c[1] + R * 0.8 * math.sin(math.radians(g)))
        put(a, "kohlrabi", st[0], st[1], g * 0.85 - 13, L)
    a.polar(c[0], c[1], lambda h: 1 + 0.02 * math.cos(3 * h), R, R * 0.95, 0, "unripe")
    for g in (-150, -110, -70, -30):   # the stalk bases on the ball
        b = (c[0] + R * 0.8 * math.cos(math.radians(g)), c[1] + R * 0.8 * math.sin(math.radians(g)))
        a.oval(b[0], b[1], 1.5, 1.2, g, "sage", 0.6)
    for dx, dy in ((-9, 6), (7, 8), (-1, 11), (11, 1), (-12, -2)):   # crescent scars where lower leaves fell
        a.line(f"M{f(c[0] + dx - 1.8)},{f(c[1] + dy)} q1.8,1.4 3.6,0", 0.7, 0.65)
    return a


# --------------------------------------------------- salsify and scorzonera
def beaked_seed(body, pappus):
    def draw(a, x, y):
        t = T(x - 4, y + 6, -24)
        a.ribbon(t(-20), t(-6, 0.6), t(8), 2.6, 4.0, body, lw=0.9)       # the ribbed seed
        for o in (-0.8, 0.6):
            a.line(f"M{P(t(-17, o))} L{P(t(6, o * 1.4))}", 0.45, 0.5)
        a.line(f"M{P(t(8))} L{P(t(24))}", 0.8, 0.85)                        # the long beak
        c = t(24)
        for k in range(9):   # the feathery parachute
            g = -24 - 70 + 140 * k / 8; e = T(*c, g)(13)
            a.line(f"M{P(c)} L{P(e)}", 0.6, 0.95, pappus)
            for v in (0.4, 0.7):
                m = T(*c, g)(13 * v)
                for sd in (-1, 1):
                    a.line(f"M{P(m)} L{P(T(*m, g + sd * 40)(2))}", 0.45, 0.9, pappus)
    return draw


def plain_seed(body, pappus):
    """Scorzonera: a slim ribbed seed with NO beak: the feathery parachute
    sits straight on its top."""
    def draw(a, x, y):
        t = T(x - 6, y + 8, -30)
        a.ribbon(t(-14), t(-2, 0.6), t(12), 2.6, 3.6, body, lw=0.9)
        for o in (-0.8, 0.6):
            a.line(f"M{P(t(-11, o))} L{P(t(10, o * 1.3))}", 0.45, 0.5)
        c = t(12.5)
        for k in range(11):
            g = -30 - 75 + 150 * k / 10; e = T(*c, g)(15)
            a.line(f"M{P(c)} L{P(e)}", 0.6, 0.95, pappus)
            for v in (0.35, 0.6, 0.85):
                m = T(*c, g)(15 * v)
                for sd in (-1, 1):
                    a.line(f"M{P(m)} L{P(T(*m, g + sd * 40)(2))}", 0.45, 0.9, pappus)
    return draw


def grass_seedling(true_leaf=None):
    def draw():
        a = Art(); soil(a, 72); a.roots(50, 72, 2, 12, 30)
        grass(a, 50, 72, [(40, 46), (58, 44)], "sage" if not true_leaf else "pale", w=2.2)
        if true_leaf:
            a.leaf(50, 72, -88, 20, 0.2, true_leaf, lw=0.9)
        return a
    return draw


SALSIFY_ENDS = [(26, 34), (36, 22), (47, 16), (58, 18), (68, 26), (76, 40)]


def salsify_young():
    a = Art(); soil(a, 72)
    grass(a, 50, 71, [(x, y + 26) for x, y in SALSIFY_ENDS[1:-1]], "sage", w=2.6)
    taproot(a, 50, 71, 4, 16, "seed", rings=0, tail=3)
    return a


def salsify_crop():
    a = Art(); soil(a, 38)
    a.ribbon((50, 40), (50, 37), (50, 33), 4.4, 3.6, "pale", lw=0.8)
    grass(a, 50, 36, [(x * 0.9 + 5, y * 0.75 - 9) for x, y in SALSIFY_ENDS], "sage", w=3.0)
    taproot(a, 50, 39, 7, 53, "seed", s1=0.95, k1=0.5, s2=0.45, k2=0.86, rings=5, rootlets=14, tail=4)
    return a


SCORZ = [(-150, 26), (-124, 32), (-100, 36), (-78, 36), (-54, 32), (-30, 26)]


def scorzonera_young():
    a = Art(); soil(a, 72)
    tuft(a, "scorzonera", 50, 70, [(g, L * 0.8) for g, L in SCORZ[1:-1]])
    taproot(a, 50, 70, 4, 16, "dark", rings=0, tail=3)
    return a


def scorzonera_crop():
    global broken_c
    a = Art(); soil(a, 38)
    tuft(a, "scorzonera", 50, 36, [(g, L * 0.84) for g, L in SCORZ])
    broken_c = "white"
    rs, ls = taproot(a, 50, 38, 8, 52, "dark", s1=1.0, k1=0.5, s2=0.85, k2=0.9, rings=0, rootlets=4, broken=0.66)
    # the root snapped as it was lifted: the broken-off lower piece below, both ends showing the white flesh
    yb = rs[-1][1]; wb = abs(rs[-1][0] - ls[-1][0])
    a.shape(f"M{f(50 - wb / 2 + 0.4)},{f(yb + 4)} L{f(50 + wb / 2 - 0.2)},{f(yb + 4)} Q{f(50 + wb * 0.45)},{f(yb + 13)} {f(50.6)},{f(yb + 17)} Q{f(50 - wb * 0.4)},{f(yb + 13)} {f(50 - wb / 2 + 0.4)},{f(yb + 4)} Z", "dark")
    a.oval(50.1, yb + 4, wb / 2 - 0.3, 1.6, 0, "white", 0.8)
    a.oval(50, yb, wb / 2, 1.8, 0, "white", 0.9)
    return a


LEAF_DRAW = {"roots_lyrate": leaf_lyrate, "roots_beet": leaf_beet, "roots_simple": leaf_simple, "roots_grass": leaf_grass,
             "roots_tube": leaf_tube, "roots_flat": leaf_flat, "roots_pinnate": leaf_pinnate, "roots_carrot": leaf_carrot,
             "roots_wildgarlic": leaf_wildgarlic}

LEAFX = {
    "carrot": dict(kind="roots_carrot", fill="deep"),
    "parsnip": dict(kind="roots_pinnate", fill="leaf", leaflet="parsnip", endkind="parsnip_end", pairs=3, ll=19, lW=0.72,
                    termk=1.25, termW=0.86, sheath=True, end=0.8, us=[0.44, 0.64, 0.84], spread=60, groove=True),
    "celeriac": dict(kind="roots_pinnate", fill="deep", leaflet="celeriac", pairs=3, ll=19, lW=0.9, termk=1.22, termW=0.92,
                     sheath=True, end=0.78, us=[0.44, 0.64, 0.84], stalklets=True, spread=60),
    "potatoes": dict(kind="roots_pinnate", fill="deep", leaflet="potato", pairs=3, ll=22, lW=0.6, termk=1.15, end=0.76,
                     us=[0.26, 0.55, 0.84], small=True, stalklets=True, spread=56, shrink=0.05),
    "beetroot": dict(kind="roots_beet", fill="deep", stalkc="beet", veinc="beet", W=40),
    "mangelwurzel": dict(kind="roots_beet", fill="leaf", stalkc="pale", veinc="white", W=42, petiole=0.3),
    # radish: a short round end lobe and small lobes spaced well apart down a long stalk, fine blunt teeth
    "radish": dict(kind="roots_lyrate", fill="leaf", Wt=14, t0=0.52, petiole=0.2, hairs=True, wing=0.7, teeth=30, td=1.2,
                   lobes=[(0.07, 0.03, 3.6, 1), (0.13, 0.03, 3.4, -1), (0.22, 0.035, 5, 1), (0.29, 0.035, 5, -1), (0.36, 0.04, 6.5, 1),
                          (0.42, 0.04, 6.5, -1)]),
    # turnip: a long, large end lobe with big side lobes crowded up under it, coarse wavy teeth
    "turnip": dict(kind="roots_lyrate", fill="leaf", Wt=19, t0=0.43, petiole=0.1, hairs=True, wing=1.0, teeth=16, td=2.2,
                   lobes=[(0.08, 0.045, 6, 1), (0.1, 0.045, 5.6, -1), (0.18, 0.05, 9.5, 1), (0.2, 0.05, 9, -1), (0.28, 0.05, 12.5, 1), (0.29, 0.05, 12, -1)]),
    "swede": dict(kind="roots_lyrate", fill="sage", Wt=18, t0=0.5, petiole=0.12, wing=1.1, teeth=20, td=1.4,
                  lobes=[(0.07, 0.04, 6, 1), (0.088, 0.04, 5.7, -1), (0.19, 0.05, 9.5, 1), (0.208, 0.05, 9.0, -1), (0.32, 0.055, 12.5, 1), (0.338, 0.055, 11.9, -1)],
                  midc="white"),
    "kohlrabi": dict(kind="roots_simple", fill="sage", petiole=0.44, W=36, tipk=0.55, basek=0.9, wave=0.7, waven=6, teeth=11, td=1.6,
                     palemid=True, stalklobe=True, sw=2.2),
    "scorzonera": dict(kind="roots_simple", fill="leaf", winged=True, W=25, tipk=1.1, basek=1.0, wave=0.7, waven=5, near=True, palemid=True),
    "salsify": dict(kind="roots_grass", fill="sage"),
    "wild-garlic": dict(kind="roots_wildgarlic", fill="leaf", W=22),
    # onion: two or three thick tubes from the golden neck of the bulb
    "onion": dict(kind="roots_tube", fill="sage", W=9, base="amber"),
    # shallot: more, thinner tubes from a coppery neck
    "shallot": dict(kind="roots_tube", fill="sage", W=5, base="rust", tipk=0.4,
                    ends=[((42, 88), (30, 60), (14, 30)), ((43, 88), (36, 50), (34, 12)), ((45, 88), (54, 50), (64, 10)), ((46, 88), (60, 60), (86, 30))],
                    cutleaf=((45, 88), (54, 76), (70, 66))),
    # spring onion: a long straight white shank, a few tubes from its top
    "spring-onion": dict(kind="roots_tube", fill="leaf", W=6, base="shank"),
    # chives: many very fine tubes with fine points
    "chives": dict(kind="roots_tube", fill="deep", W=3.2, base="sheath", tipk=0.5,
                   ends=[((43, 92), (32, 60), (18, 22)), ((44, 92), (38, 52), (34, 10)), ((45, 92), (46, 50), (50, 6)), ((46, 92), (54, 50), (66, 10)),
                         ((47, 92), (62, 58), (84, 22)), ((44, 92), (30, 72), (12, 50))],
                   cutleaf=((46, 92), (54, 80), (66, 70))),
    # Bristol onion: a few thin half-round leaves, grooved along the upper side, the cut end a half moon
    "bristol-onion": dict(kind="roots_tube", fill="sage", W=5, groove=True, base="sheath", tipk=0.45,
                          ends=[((43, 92), (26, 66), (14, 34)), ((45, 92), (52, 50), (76, 8))], cutleaf=((46, 92), (56, 80), (68, 66))),
    "leek": dict(kind="roots_flat", fill="sage", W=14),
    "garlic": dict(kind="roots_flat", fill="sage", W=10, prof="taper", garlic=True),
}



# ======================================================== year 2: in flower and gone to seed
def ridges(a, q, n=2):
    for o in [(-0.5 + k / (n - 1)) * 0.9 for k in range(n)] if n > 1 else [0]:
        a.line(opath([(q.pt(u)[0] + o, q.pt(u)[1]) for u in (0.04, 0.3, 0.6, 0.9)]), 0.4, 0.4)


def umbel_head(a, x, y, R, fc, bracts=False, dots="unripe", n=8, seeds=None):
    """A compound umbel from the side: spokes from one point up to a flat
    top of small umbels. bracts: carrot's forked threads beneath. seeds:
    "disc" for parsnip's flat round winged seeds."""
    if bracts:
        for g in (150, 118, 62, 30):
            e = T(x, y, g)(R * 0.5); m = T(x, y, g)(R * 0.28)
            a.line(f"M{f(x)},{f(y)} L{P(e)} M{P(m)} L{P(T(*m, g + (26 if g > 90 else -26))(R * 0.2))}", 0.45, 0.8)
    tips = []
    for k in range(n):
        u = k / (n - 1) - 0.5
        e = (x + u * 2 * R, y - R * 0.5 + (u * 2) ** 2 * R * 0.12)
        a.line(f"M{f(x)},{f(y)} Q{f(x + u * R * 0.9)},{f(y - R * 0.3)} {P(e)}", 0.55, 0.85)
        tips.append(e)
    for e in sorted(tips, key=lambda q: -abs(q[0] - x)):
        if seeds == "disc":
            for j, (dx, dy) in enumerate(((-1.2, -1.4), (1.2, -1.6), (0, -2.6))):
                a.oval(e[0] + dx * R / 10, e[1] + dy * R / 10, R * 0.12, R * 0.1, dx * 20, fc, 0.5)
            continue
        for dx in (-0.16, 0, 0.16):   # the short spokes of the small umbel
            a.line(f"M{f(e[0])},{f(e[1] + R * 0.06)} L{f(e[0] + dx * R)},{f(e[1] - R * 0.04)}", 0.35, 0.6)
        a.shape(f"M{f(e[0] - R * 0.25)},{f(e[1])} Q{f(e[0])},{f(e[1] - R * 0.34)} {f(e[0] + R * 0.25)},{f(e[1])} Q{f(e[0])},{f(e[1] + R * 0.05)} {f(e[0] - R * 0.25)},{f(e[1])} Z", fc, 0.55)
        for dx in (-0.12, 0, 0.12):
            a.dot(e[0] + dx * R, e[1] - R * 0.1 - (0.04 if dx == 0 else 0) * R, max(0.3, R * 0.03), dots)


def nest(a, x, y, R, col="bark"):
    """Carrot gone to seed: the spokes curled inwards and up into a hollow
    brown 'bird's nest', each spoke a dark curved line ending in a knot of
    small bristly fruits round the rim."""
    h = R * 0.78
    a.shape(f"M{f(x)},{f(y)} C{f(x - R * 0.75)},{f(y - h * 0.1)} {f(x - R * 0.85)},{f(y - h * 0.7)} {f(x - R * 0.58)},{f(y - h * 0.92)} "
            f"Q{f(x)},{f(y - h * 1.04)} {f(x + R * 0.58)},{f(y - h * 0.92)} C{f(x + R * 0.85)},{f(y - h * 0.7)} {f(x + R * 0.75)},{f(y - h * 0.1)} {f(x)},{f(y)} Z", col, 0.7, fa=0.6)
    a.oval(x, y - h * 0.9, R * 0.5, R * 0.14, 0, "dark", 0.6)   # the dark hollow in the middle
    for o in (-0.62, -0.36, -0.1, 0.16, 0.42, 0.66):   # the curled spokes, each bending in at the top
        tip = (x + o * R * 0.8, y - h * 0.92 + abs(o) * R * 0.06)
        a.line(f"M{f(x)},{f(y)} C{f(x + o * R * 1.4)},{f(y - h * 0.15)} {f(x + o * R * 1.5)},{f(y - h * 0.75)} {P(tip)}", 0.8, 0.95, "bark")
        r = max(0.9, R * 0.11)   # the bristly brown fruits on its end
        for k in range(7):
            g = -90 + (k - 3) * 30
            a.line(f"M{P(tip)} L{P(T(*tip, g)(r * 1.9))}", 0.45, 1.0, "dark")
        a.dot(tip[0], tip[1] - r * 0.2, r, "bark")


def tall_umbel(slug, stage, fc, heads, leafL=16):
    """Carrot, parsnip or celeriac in its second year: a tall branched,
    ridged stem with smaller leaves, heads at the branch tips (heads(a,
    x, y, R) draws one)."""
    seed = stage == "seedhead"; sc = "straw" if seed else "leaf"
    a = Art(); soil(a, 88)
    tuft(a, slug, 50, 87, [(-166, 22), (-14, 22), (-140, 20), (-40, 20)], dry=seed)
    br = [((0.42, 0), (26, 44)), ((0.58, 0), (75, 37))]
    q = a.ribbon((50, 88), (52, 58), (50, 30), 3.2, 1.8, sc, lw=0.9); ridges(a, q)
    qs = []
    for (u, _), e in br:
        x, y = q.pt(u); qs.append(a.stem((x, y), ((x + e[0]) / 2, y - 4), e, 1.0))
    for u, sd in ((0.26, 1), (0.36, -1), (0.52, 1)):   # the smaller, more finely cut leaves on the stem
        x, y = q.pt(u); put(a, slug, x, y, -90 + sd * 62, leafL * (1.1 - u), dry=seed)
    heads(a, 50, 30, 15)
    for qq in qs:
        heads(a, qq.p1[0], qq.p1[1], 10)
    return a


def carrot_tall(stage):
    if stage == "seedhead":
        return lambda: tall_umbel("carrot", stage, "straw", lambda a, x, y, R: nest(a, x, y - 1, R * 1.0))
    return lambda: tall_umbel("carrot", stage, "white", lambda a, x, y, R: umbel_head(a, x, y, R, "white", bracts=True, dots="unripe"))


def parsnip_tall(stage):
    if stage == "seedhead":
        return lambda: tall_umbel("parsnip", stage, "straw", lambda a, x, y, R: umbel_head(a, x, y, R, "straw", seeds="disc"), 20)
    return lambda: tall_umbel("parsnip", stage, pal("parsnip", "flower", "sun"),
                              lambda a, x, y, R: umbel_head(a, x, y, R, pal("parsnip", "flower", "sun"), dots="amber"), 20)


def celeriac_tall(stage):
    """Celeriac: many small umbels on very short stalks along the stems,
    opposite the leaves, as well as at the tips."""
    seed = stage == "seedhead"

    def little(a, x, y, R):
        col = "bark" if seed else "white"
        for j, g in enumerate(range(-150, -20, 22)):   # unequal short spokes, each with a little knot of flowers or seeds
            e = T(x, y, g)(R * 0.55 * (0.75 + 0.5 * (j % 2))); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.5, 0.85)
            for dx, dy in ((0, -0.9), (-0.9, 0.4), (0.9, 0.4)):
                a.oval(e[0] + dx, e[1] + dy, 1.05, 1.0, 0, col, 0.45)
            if not seed:
                a.dot(*e, 0.4, "pear")

    def draw():
        a = tall_umbel("celeriac", stage, "white", lambda a, x, y, R: little(a, x, y, R * 1.25), 18)
        return a

    def draw2():
        a = draw()
        # the small umbels sitting along the stems at the leaf joints
        for x, y in ((53, 62), (39, 50), (63, 46)):
            little(a, x, y, 12)
        return a
    return draw2


def spike(a, p0, c, p1, col, seed=False, n=9, s=1.0):
    """A long slender spike of tight clusters (beet), a small leaf under each."""
    q = a.stem(p0, c, p1, 0.8 if not seed else 0.9, col="line" if not seed else "bark", la=0.85 if not seed else 1.0)
    if seed:
        s *= 1.2
    for i in range(n):
        u = 0.12 + 0.86 * i / (n - 1); x, y = q.pt(u); g = q.ang(u); sd = 1 if i % 2 else -1
        if not seed and u < 0.8:
            a.leaf(x, y, g + sd * 55, 3.4 * s, 0.4, "leaf", lw=0.5, detail=False)
        for dx, dy in ((0, 0), (0.9, -0.6), (-0.8, -0.7)):
            a.oval(x + dx * s - sd * 0.8, y + dy * s, 0.95 * s, 0.85 * s, 0, col, 0.45)
        if seed:
            a.dot(x - sd * 0.8, y - 0.3, 0.35, "dark")
    return q


def beet_tall(slug, stage):
    """Beetroot or mangel in its second year: a tall leafy stem with long
    slender spikes of small green clusters, or dry brown ones in seed."""
    def draw():
        seed = stage == "seedhead"; col = "bark" if seed else "unripe"; sc = "straw" if seed else "leaf"
        a = Art(); soil(a, 88)
        tuft(a, slug, 50, 87, [(-164, 24), (-16, 24), (-138, 22), (-42, 22)], dry=seed)
        q = a.ribbon((50, 88), (51, 60), (50, 22), 3.2, 1.6, sc, lw=0.9); ridges(a, q)
        for u, sd in ((0.2, 1), (0.3, -1), (0.4, 1)):
            x, y = q.pt(u); put(a, slug, x, y, -90 + sd * 58, 17 * (1.1 - u), dry=seed)
        for u, sd, c, e in ((0.45, -1, (30, 22), (12, 34)), (0.52, 1, (72, 18), (89, 30)), (0.62, -1, (34, 8), (20, 16)), (0.7, 1, (66, 6), (80, 12))):
            x, y = q.pt(u); spike(a, (x, y), c, e, col, seed, n=8)   # long slender spikes, arching over
        spike(a, q.pt(0.8), (52, 8), (58, 4), col, seed, n=7)
        return a
    return draw


def clasp_leaf(a, x, y, ang, L, fill, sd):
    """An upper stem leaf of the cabbage family: undivided, its base
    clasping the stem with two rounded ears."""
    a.leaf(x, y, ang, L, 0.34, fill, lw=0.7)
    for o in (-1, 1):   # the two rounded ears, wrapped round the stem in front of it
        a.polar(x + o * 1.6, y + 0.4, lambda h: 1, 2.0, 1.5, o * 20, fill, 0.6, shade=False)


def raceme(a, x, y, fc, mode, seed=False, pods="slim", s=1.0, podc="unripe"):
    """The top of one flowering branch of the cabbage family."""
    if seed:   # pods along the top of the stem
        for k in range(5):
            py = y + 3 + k * 3.6 * s; sd = 1 if k % 2 else -1
            if pods == "fat":   # radish: fat, pointed, waisted between the seeds, with a beak
                fat_pod(a, x, py, sd, 0.7, podc)
            else:   # slender, upright, beaked
                b = T(x, py, -90 + sd * 50)(2.2)
                a.line(f"M{f(x)},{f(py)} L{P(b)}", 0.6, 0.85)
                a.ribbon(b, (b[0] + sd * 0.6, b[1] - 4), (b[0] + sd * 0.8, b[1] - 9 * s), 1.4, 0.9, podc, lw=0.55)
                a.line(f"M{f(b[0] + sd * 0.8)},{f(b[1] - 9 * s)} l0,-2", 0.5, 0.85)
        return
    r = 2.6 * s
    if mode == "spike":   # radish: flowers spaced along a loose spike, young pods lower down
        for k, (dx, dy) in enumerate(((-2.6, 2), (2.6, -2.6), (-2.2, -7))):
            a.line(f"M{f(x)},{f(y + dy + 1)} L{f(x + dx)},{f(y + dy)}", 0.5, 0.85)
            a.flower(x + dx, y + dy, r, 4, fc, "sun", 0.74, start=-45 + k * 10, lw=0.5)
        a.oval(x, y - 10, 0.9, 1.4, 0, "unripe", 0.5)
        a.line(f"M{f(x)},{f(y + 2)} L{f(x)},{f(y + 15)}", 0.9, 0.85)
        for k in range(3):   # fat green pods forming lower down the spike
            fat_pod(a, x, y + 6 + k * 4, 1 if k % 2 else -1, 0.62, podc)
        return
    buds = [(x, y - 5.2), (x - 1.2, y - 4), (x + 1.2, y - 4.2)] if mode == "level" else [(x - 1, y + 1.6), (x + 1, y + 1.8)]
    for bx, by in buds:
        a.oval(bx, by, 0.9, 1.3, 0, "unripe", 0.45)
    pts = [(x - 2.8, y - 0.4), (x + 2.8, y - 0.8), (x, y - 1.8)] if mode == "flat" else [(x - 3, y + 0.4), (x + 3, y)]
    for k, (px, py) in enumerate(pts):
        a.flower(px, py, r, 4, fc, "sun", 0.74, start=-45 + k * 12, lw=0.5)
    if mode != "flat":
        for k in (0, 1):   # pods already forming lower down
            sd = 1 if k else -1; py = y + 6 + k * 3.5
            b = (x + sd * 1.8, py - 0.6); a.line(f"M{f(x)},{f(py)} L{P(b)}", 0.5, 0.85)
            a.ribbon(b, (b[0] + sd * 0.5, b[1] - 3), (b[0] + sd * 0.7, b[1] - 6.5), 1.2, 0.8, podc, lw=0.5)


def crucifer_tall(slug, stage, fc, mode, pods="slim", stemc="leaf", base=None, clasp=True, podc="unripe"):
    """Radish, turnip, swede, kohlrabi flowering: a branched leafy stem, the
    upper leaves clasping it, racemes of small crosses at the tips; in
    seed, pods along the stems."""
    def draw():
        seed = stage == "seedhead"; sc = "straw" if seed else stemc; lc = pal(slug, "leaf", "leaf"); fc_ = pal(slug, "flower", fc)
        a = Art(); soil(a, 88)
        if base:
            by = base(a, seed)
        else:
            tuft(a, slug, 50, 87, [(-164, 24), (-16, 24), (-140, 22), (-40, 22)], dry=seed)
            by = 88
        q = a.ribbon((50, by), (51, by - (by - 26) * 0.5), (50, 26), 3.0, 1.6, sc, lw=0.9)
        tips = [(50, 22)]
        for u, sd, e in ((0.4, -1, (24, 40)), (0.5, 1, (77, 36)), (0.66, -1, (34, 26))):
            x, y = q.pt(u); qq = a.ribbon((x, y), (x + sd * 6, y - 5), e, 1.6, 1.0, sc, lw=0.7)
            tips.append(e)
            if clasp:
                m = qq.pt(0.45); clasp_leaf(a, m[0], m[1], -90 - sd * 50, 9, "straw" if seed else lc, sd)
        for u, sd in ((0.2, 1), (0.3, -1)):
            x, y = q.pt(u)
            if clasp:
                clasp_leaf(a, x, y, -90 + sd * 55, 13, "straw" if seed else lc, sd)
            else:
                put(a, slug, x, y, -90 + sd * 55, 16, dry=seed)
        for x, y in tips:
            raceme(a, x, y, fc_, mode, seed, pods, s=1.25, podc="straw" if seed else podc)
        return a
    return draw


def kohlrabi_base(a, seed):
    a.roots(50, 89, 4, 7, 100)
    a.ribbon((50, 89), (50, 87), (50, 85), 3.0, 3.0, "unripe", lw=0.8)
    for g, L in ((-160, 20), (-20, 20)):
        put(a, "kohlrabi", 50 + 10 * math.cos(math.radians(g)), 76 + 8 * math.sin(math.radians(g)), g, L, dry=seed)
    a.polar(50, 76, lambda h: 1, 11, 10, 0, "straw" if seed else "unripe")
    for dx, dy in ((-6, 4), (5, 5), (8, -3), (-8, -3)):
        a.line(f"M{f(50 + dx - 1.4)},{f(76 + dy)} q1.4,1.1 2.8,0", 0.6, 0.65)
    return 67


def head_side(a, x, y, r, fc, bracts="star", seed=False, inner=None):
    """A small head of strap-shaped florets (salsify, scorzonera) on its stalk."""
    if seed:   # the clock: a ball of feathery parachutes on long beaks
        a.line(f"M{f(x)},{f(y + 1)} L{f(x)},{f(y - r * 0.2)}", 0.6, 0.85)
        for k in range(25):
            g = -90 + (k - 12) * 12.5; e = T(x, y - r * 0.9, g)(r * 1.6); b = T(x, y - r * 0.9, g)(r * 0.6)
            a.line(f"M{P(T(x, y - r * 0.9, g)(r * 0.15))} L{P(b)}", 0.35, 0.5)
            a.line(f"M{P(b)} L{P(e)}", 0.5, 0.9, "seed")
            for sd in (-1, 1):
                a.line(f"M{P(e)} L{P(T(*e, g + sd * 42)(r * 0.32))}", 0.4, 0.9, "seed")
        for g in (150, 120, 60, 30) if bracts == "star" else ():   # the bracts turned down below
            a.leaf(x, y, g, r * 1.4, 0.14, "straw", lw=0.5, detail=False)
        return
    if bracts == "star":
        for g in (-170, -140, -40, -10, -110, -70):
            a.leaf(x, y - r * 0.3, g, r * 1.8, 0.1, "leaf", lw=0.5, detail=False)
    else:
        a.oval(x, y + r * 0.2, r * 0.42, r * 0.5, 0, "leaf", 0.6)
    for k in range(9):
        g = -90 + (k - 4) * 22
        a.leaf(x, y - r * 0.3, g, r * (1.05 - 0.06 * abs(k - 4)), 0.22, fc, lw=0.5, detail=False)
    a.oval(x, y - r * 0.35, r * 0.34, r * 0.16, 0, inner or fc, 0.5)


def composite_tall(slug, stage, fc0, bracts, grassy, inner=None):
    def draw():
        fc = pal(slug, "flower", fc0)
        seed = stage == "seedhead"; sc = "straw" if seed else ("sage" if grassy else "leaf"); lc = "straw" if seed else pal(slug, "leaf", "leaf")
        a = Art(); soil(a, 88)
        if grassy:
            grass(a, 50, 87, [(28, 72), (72, 70)], lc, w=2.6)
        else:
            tuft(a, slug, 50, 87, [(-164, 24), (-16, 24), (-138, 22), (-42, 22)], dry=seed)
        q = a.ribbon((50, 88), (51, 60), (50, 28), 2.8, 1.6, sc, lw=0.9)
        heads = [(50, 26)]
        for u, sd, e in ((0.5, -1, (30, 36)), (0.62, 1, (70, 30))):
            x, y = q.pt(u); a.stem((x, y), (x + sd * 6, y - 8), e, 1.0); heads.append(e)
        for u, sd in (((0.1, 1), (0.24, -1), (0.4, 1)) if grassy else ((0.18, 1), (0.3, -1), (0.42, 1))):   # leaves clasping the stem, one at a time
            x, y = q.pt(u)
            if grassy:   # long grass-like leaves, one at each joint, their broad bases clasping, arching out
                L = 22 * (1.05 - u)
                e = (x + sd * L * 0.8, y - L * 0.25); a.ribbon((x, y), (x + sd * L * 0.3, y - L * 0.6), e, 2.6, 0.3, lc, lw=0.8)
                a.ribbon((x, y + 2.4), (x, y), (x, y - 2.4), 3.6, 3.0, "pale" if not seed else "straw", lw=0.6)
            else:
                put(a, slug, x, y, -90 + sd * 56, 18 * (1.1 - u), dry=seed)
        for x, y in heads:
            if bracts == "star" and not seed:   # salsify: the stalk swells into a club under the head
                a.ribbon((x, y + 7), (x, y + 3), (x, y), 1.2, 2.8, sc, lw=0.7)
            head_side(a, x, y, 7 if bracts == "star" else 6, fc, bracts, seed, inner)
        return a
    return draw



# ================================================================= potato
def potato_tuber(a, x, y, rx, ry, rot=0, col="straw", eyes=True, old=False):
    if old:   # the old seed tuber: shrivelled, dark and wrinkled
        a.polar(x, y, lambda h: 1 + 0.1 * math.cos(5 * h) + 0.07 * math.sin(9 * h), rx, ry, rot, "bark")
        for k in range(4):
            yy = y - ry * 0.55 + k * ry * 0.36
            a.line(f"M{f(x - rx * 0.7)},{f(yy)} q{f(rx * 0.35)},{f(-ry * 0.25)} {f(rx * 0.7)},0 t{f(rx * 0.7)},0", 0.55, 0.6)
        return
    a.polar(x, y, lambda h: 1 + 0.04 * math.cos(3 * h + 1), rx, ry, rot, col)
    if eyes:   # shallow eyes
        for dx, dy in ((-0.5, -0.3), (0.35, 0.25), (0.05, -0.55), (0.6, -0.2)):
            a.line(f"M{f(x + dx * rx - 1)},{f(y + dy * ry)} q1,-0.8 2,0", 0.55, 0.55)


def potato_seedtuber():
    a = Art(); a.ground(38, marks=False); below(a, 40)
    potato_tuber(a, 50, 66, 18, 12.5, -8)
    for dx, dy, g, c in ((-8, -11, -100, "plum"), (3, -12.5, -80, "plum"), (12, -8, -50, "unripe")):   # short stubby sprouts, chitted in the light
        b = (50 + dx, 66 + dy)
        e = T(*b, g)(5.5)
        a.ribbon(b, T(*b, g)(3), e, 3.2, 2.4, c, lw=0.8, round_tip=True)
        for sd in (-1, 1):
            a.dot(*T(*T(*b, g)(3.2), g + sd * 90)(1.4), 0.45, "white" if c == "plum" else "pale")
    return a


def potato_shoot(a, x, y, H, lean, leaves, fills=None, dry=False, droop=0):
    """One leafy potato stem: its own pinnate leaves set alternately up it."""
    q = a.ribbon((x, y), (x + lean * 0.05, y - H * 0.75), (x + lean, y - H), 2.2, 1.4, "straw" if dry else "leaf", lw=0.8)
    for k in range(leaves):
        u = 0.25 + 0.72 * k / max(1, leaves - 1); px, py = q.pt(u); sd = 1 if k % 2 else -1
        put(a, "potatoes", px, py, -90 + sd * (62 + droop) + lean * 0.6, 29 * (1.05 - 0.4 * u), fills=fills, dry=dry)
    return q


def potato_young():
    a = Art(); soil(a, 84)
    a.shape("M24,84 Q34,70 50,69 Q66,70 76,84 Z", "soil", 0.8, fa=0.55)   # the soil drawn up round the stems (earthed up)
    for dx in (-8, 8, 0):
        potato_shoot(a, 50 + dx * 0.4, 72, 30 if dx else 38, dx * 1.2, 3)
    a.shape("M28,84 Q36,73 50,72 Q64,73 72,84", None, 0.9, col="soil")
    return a


def potato_in_flower():
    a = Art(); soil(a, 88)
    shoots = [(-6, 30, -24), (6, 30, 24), (-3, 46, -16), (3, 44, 16), (0, 54, 3)]   # angled stems arching out into a sprawling bush   # angled stems sprawling out into a bush
    tops = []
    for dx, H, lean in shoots:
        q = potato_shoot(a, 50 + dx * 0.5, 88, H, lean, 3)
        tops.append(q.pt(1))
    for (x, y), sd in zip(tops[2:], (-1, 1, 1)):   # clusters of star flowers on long stalks held above the leaves
        e = (x + sd * 4, y - 9); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 1)},{f(y - 6)} {P(e)}", 0.9, 0.85)
        for k, (ox, oy) in enumerate(((-3.4, -1), (3.2, -1.6), (0, -4), (-1.4, 2.4))):
            fx, fy = e[0] + ox, e[1] + oy
            a.line(f"M{P(e)} L{f(fx)},{f(fy)}", 0.5, 0.8)
            if k == 3:
                a.oval(fx, fy, 0.9, 1.3, 0, "pale", 0.5); continue
            a.flower(fx, fy, 2.9, 5, "white", None, 0.95, start=-90 + k * 12, lw=0.5)
            a.shape(f"M{f(fx - 0.8)},{f(fy + 0.3)} L{f(fx)},{f(fy - 1.5)} L{f(fx + 0.8)},{f(fy + 0.3)} Z", "sun", 0.4)
    return a


def potato_crop():
    a = Art(); soil(a, 46)
    for dx, H, lean in ((-8, 28, -20), (8, 26, 20), (0, 32, 2)):   # the haulm yellowing and dying back
        potato_shoot(a, 50 + dx * 0.4, 46, H, lean, 3, fills={"deep": "pear"}, droop=24)
    for dx in (-3.2, 0, 3.2):   # the stems running down under the soil to the old seed tuber
        a.ribbon((50 + dx * 0.4, 46), (50 + dx * 0.5, 50), (50 + dx * 0.6, 54), 2.0, 1.8, "pale", lw=0.7)
    for dx, dy, rx, ry, g in ((-23, 70, 9, 6.5, -10), (21, 66, 8.5, 6, 12), (-6, 84, 9.5, 7, 5), (16, 85, 7.5, 5.4, -18), (-28, 88, 6, 4.4, 20)):
        sx, sy = 50 + (2 if dx > 0 else -2), 60
        d = f"M{f(sx)},{f(sy)} Q{f(50 + dx * 0.6)},{f(sy + (dy - sy) * 0.3)} {f(50 + dx)},{f(dy - ry)}"
        a.line(d, 1.6, 0.6); a.line(d, 0.9, 1.0, "white")   # the white stolons
        potato_tuber(a, 50 + dx, dy, rx, ry, g)
    a.roots(50, 62, 5, 7, 120)
    potato_tuber(a, 50, 58, 7.5, 5, old=True)   # the old seed tuber, shrivelled, dark and wrinkled
    return a


# ================================================================ alliums
def white_roots(a, x, y, n=6, L=8, spread=120):
    """A tuft of white roots, outlined so they show on the pale card."""
    for k in range(n):
        u = k / (n - 1) - 0.5 if n > 1 else 0
        g = 90 + u * spread; e = T(x, y, g)(L * (1 - 0.3 * abs(u) * 2)); m = T(x, y, g + (12 if u > 0 else -12))(L * 0.5)
        d = f"M{f(x)},{f(y)} Q{P(m)} {P(e)}"
        a.line(d, 1.5, 0.7); a.line(d, 0.8, 1.0, "white")


def bulb(a, x, y, w, h, fill, neck=2.4, tear=False, lines=True, plate=True):
    """An onion-type bulb standing on its root plate at x,y: w wide, h tall,
    narrowing to a neck. tear: a teardrop, widest low down (shallot)."""
    hw = w / 2; sh = 0.45 if tear else 0.62
    d = (f"M{f(x - neck / 2)},{f(y - h)} C{f(x - neck / 2)},{f(y - h * (0.78 if not tear else 0.7))} {f(x - hw)},{f(y - h * sh)} {f(x - hw)},{f(y - h * (sh - 0.25))} "
         f"C{f(x - hw)},{f(y - h * 0.04)} {f(x - hw * 0.4)},{f(y)} {f(x)},{f(y)} C{f(x + hw * 0.4)},{f(y)} {f(x + hw)},{f(y - h * 0.04)} {f(x + hw)},{f(y - h * (sh - 0.25))} "
         f"C{f(x + hw)},{f(y - h * sh)} {f(x + neck / 2)},{f(y - h * (0.78 if not tear else 0.7))} {f(x + neck / 2)},{f(y - h)} Z")
    a.shape(d, fill)
    a.shape(f"M{f(x + neck / 2)},{f(y - h)} C{f(x + neck / 2)},{f(y - h * 0.78)} {f(x + hw)},{f(y - h * sh)} {f(x + hw)},{f(y - h * (sh - 0.25))} "
            f"C{f(x + hw)},{f(y - h * 0.04)} {f(x + hw * 0.4)},{f(y)} {f(x)},{f(y)} C{f(x + hw * 0.5)},{f(y - h * 0.3)} {f(x + hw * 0.4)},{f(y - h * 0.6)} {f(x + neck / 2)},{f(y - h)} Z", "shade", 0, fa=0.1)
    if lines:   # the lines of the papery skin
        for o in (-0.55, 0.5):
            a.line(f"M{f(x)},{f(y - h * 0.95)} Q{f(x + o * hw * 1.3)},{f(y - h * 0.45)} {f(x + o * hw * 0.5)},{f(y - 0.6)}", 0.55, 0.4)
    if plate:
        a.shape(f"M{f(x - hw * 0.4)},{f(y - 0.6)} L{f(x + hw * 0.4)},{f(y - 0.6)} L{f(x + hw * 0.3)},{f(y + 1)} L{f(x - hw * 0.3)},{f(y + 1)} Z", "bark", 0.6)


def hairpin(a, x, y, h, col, seedc="dark"):
    """An onion-family seedling: one thin seed leaf bent double like a
    hairpin, the black seed case still on its tip."""
    d = f"M{f(x)},{f(y)} C{f(x)},{f(y - h)} {f(x + 0.5)},{f(y - h * 1.3)} {f(x + 4)},{f(y - h * 1.3)} C{f(x + 8)},{f(y - h * 1.3)} {f(x + 7.4)},{f(y - h * 0.8)} {f(x + 6.8)},{f(y - h * 0.62)}"
    a.line(d, 2.0, 0.9); a.line(d, 1.0, 1.0, col)
    a.oval(x + 6.9, y - h * 0.58, 1.6, 2.0, 10, seedc, 0.5)


def onion_seed(a, x, y):
    """A leek or onion seed: black, angular, wrinkled, flat on one face and
    curved on the other, like a little crescent with corners."""
    pts = [(-12, 3), (-9, -5), (-3, -9.5), (5, -9), (11, -4), (12.5, 3), (7, 8), (2, 5.5), (-4, 8.5)]
    a.shape(path([(x + px, y + py) for px, py in pts]), "dark", 1.15)
    for d in ("M-8,-2 L-3,-6 L3,-6.5", "M-6,3 L0,-1 L7,0", "M2,5 L6,1 L10,-2", "M-9,0 L-5,4"):   # the wrinkles and facets
        nums = [float(v) for v in d.replace("M", "").replace("L", " ").replace(",", " ").split()]
        q = [(x + nums[i], y + nums[i + 1]) for i in range(0, len(nums), 2)]
        a.line(opath(q), 0.6, 0.6, "bark")


def allium_seedling(col, n=1):
    def draw():
        a = Art(); soil(a, 72)
        spots = [(40, 24, "pin"), (58, 30, "up")] if n == 1 else [(34, 20, "pin"), (46, 28, "up"), (55, 24, "pin"), (64, 32, "up")]
        for x, h, kind in spots:
            a.line(f"M{f(x)},72 Q{f(x + 1)},78 {f(x)},{f(84)}", 0.8, 0.85, "soil")
            if kind == "pin":
                hairpin(a, x, 72, h, col)
            else:   # a little later: straightened, the seed case lifted on its tip
                d = f"M{f(x)},72 Q{f(x - 1)},{f(72 - h * 0.5)} {f(x + 1)},{f(72 - h)}"
                a.line(d, 2.2, 0.9); a.line(d, 1.1, 1.0, col)
                a.oval(x + 1.3, 72 - h - 1, 1.6, 2.0, 15, "dark", 0.5)
        return a
    return draw


def swollen_stem(a, x, y, top, col, w=2.6, bulge=2.4, at=0.35):
    """A hollow onion flower stem, swollen like a long balloon below the middle."""
    n = 30; Lp, Rp = [], []
    for i in range(n + 1):
        u = i / n; yy = y + (top - y) * u
        ww = (w + bulge * math.exp(-((u - at) / 0.17) ** 2)) * (1 - 0.3 * u) / 2
        Lp.append((x - ww, yy)); Rp.append((x + ww, yy))
    a.shape(path(Lp + Rp[::-1]), col, 0.9)
    a.shape(path(Rp + [(x + 0.2, p[1]) for p in Rp[::-1]]), "shade", 0, fa=0.12)


def mini_head(a, x, y, R, fc, seed=False, egg=False, n=26, kind="star", topc=None, stamens=False, bodyc=None, seedc="straw"):
    """An onion head as it looks on the whole plant."""
    ry = R * (1.25 if egg else 1.0)
    if seed:   # dried: papery capsules, black seeds showing
        a.oval(x, y, R, ry, 0, seedc, 0.9)
        for j in range(n):
            rr = 0.82 * math.sqrt((j + 0.5) / n); th = j * GOLD
            px, py = x + R * rr * math.cos(th), y + ry * rr * math.sin(th)
            a.oval(px, py, R * 0.13, R * 0.13, 0, "seed", 0.4)
            if j % 2 == 0:
                a.dot(px, py, max(0.35, R * 0.06), "dark")
        return
    a.oval(x, y, R, ry, 0, bodyc or fc, 0.9)
    for j in range(n):
        rr = 0.86 * math.sqrt((j + 0.5) / n); th = j * GOLD
        px, py = x + R * rr * math.cos(th), y + ry * rr * math.sin(th)
        if topc and py > y + ry * 0.45:
            a.dot(px, py, max(0.4, R * 0.1), topc); continue
        if kind == "bell":
            a.leaf(px, py + R * 0.08, -90 + rr * math.cos(th) * 50, R * 0.26, 0.42, fc, lw=0.35, detail=False)
        else:
            a.flower(px, py, max(1.0, R * 0.17), 6, fc, None, 0.45 if kind == "star" else 0.55, start=j * 23, lw=0.35)
            a.dot(px, py, max(0.3, R * 0.04), "unripe" if fc != "unripe" else "pale")
    if stamens:
        for k in range(14):
            g = k * 360 / 14; e = (x + R * 1.12 * math.cos(math.radians(g)), y + ry * 1.12 * math.sin(math.radians(g)))
            a.dot(*e, 0.4, "plum" if fc in ("lilac", "beet", "roots_lilacpale") else "pear")


def tubes(a, x, y, ends, col, w=2.2, flop=None):
    """Hollow round leaves from one point (onion, chives)."""
    for ex, ey in ends:
        c = ((x + ex) / 2 + (ex - x) * 0.1, (y + ey) / 2 + abs(ex - x) * 0.25)
        tube_leaf(a, (x, y), c, (ex, ey), w, col, tipk=0.2)


# ---------------------------------------------------------------------- leek
def leek_young():
    a = Art(); soil(a, 74); white_roots(a, 50, 84, 5, 7, 100)
    for e, c, w in (((34, 34), (45, 50), 3.4), ((67, 36), (55, 52), 3.4), ((48, 24), (49, 46), 3.2)):
        flat_leaf(a, (50, 64), c, e, w, "sage", tipk=0.2)
    a.ribbon((50, 84), (50, 73), (50, 62), 3.6, 3.2, "white", lw=0.9)   # pencil thick
    return a


def leek_crop():
    a = Art(); soil(a, 62)
    white_roots(a, 50, 89, 9, 8, 150)
    for e, c, w in (((12, 34), (36, 40), 7.5), ((88, 34), (64, 40), 7.5), ((24, 12), (42, 30), 7.5), ((78, 12), (58, 30), 7.5), ((50, 4), (50.5, 26), 7)):
        flat_leaf(a, (50, 50), c, e, w, "sage", tipk=0.18)
    q = a.ribbon((50, 89), (50, 70), (50, 47), 12.5, 10, "white", lw=1.1)   # the long white shank, a little swollen at its foot
    a.shape("M45,52 L55,52 L55.2,58 Q50,60.5 44.8,58 Z", "pale", 0)          # pale green where the leaves part
    a.line("M44.6,58.5 Q50,61 55.4,58.5", 0.6, 0.45)
    a.line("M46.4,62 L46.4,86 M53.6,62 L53.4,86", 0.5, 0.3)
    a.shape("M43.4,84 Q50,80 56.6,84 L56.3,89 L43.7,89 Z", "white", 0)       # the swollen foot
    a.line("M43.6,89.5 L56.4,89.5", 1.6, 0.85, "bark")                        # the flat base the roots come from
    return a


def leek_tall(seed):
    def draw():
        lc = "straw" if seed else "sage"
        a = Art(); soil(a, 88, marks=False)
        for e, c in (((18, 64), (38, 60)), ((82, 66), (62, 60)), ((30, 50), (42, 62)), ((70, 52), (58, 62))):
            flat_leaf(a, (50, 84), c, e, 4.6, lc, tipk=0.22)
        a.ribbon((50, 88), (50.5, 60), (50, 32), 4.0, 3.2, lc, lw=1.0)   # one stout, solid, round stem
        mini_head(a, 50, 21, 13, pal("leek", "flower", "lilac"), seed=seed, n=34, kind="cup", stamens=not seed)
        return a
    return draw


# --------------------------------------------------------------------- onion
def onion_set():
    a = Art(); a.ground(38, marks=False); below(a, 40)
    bulb(a, 50, 80, 24, 30, "amber", neck=2.0)
    for dx in (-3, -1, 1, 3):   # dry stubs of old roots
        a.line(f"M{50 + dx * 0.8},81 l{dx * 0.3},2", 0.6, 0.7, "bark")
    return a


def onion_young(fill="sage"):
    def draw():
        a = Art(); soil(a, 72); white_roots(a, 50, 75, 6, 7, 120)
        tubes(a, 50, 66, [(40, 30), (47, 22), (56, 24), (62, 34)], fill, w=2.4)
        bulb(a, 50, 75, 9, 10, pal("onion", "root", "amber") if fill == "sage" else "white", neck=3.0, lines=False)
        return a
    return draw


def onion_crop():
    a = Art(); soil(a, 60)
    white_roots(a, 50, 73, 9, 10, 150)
    tubes(a, 50, 46, [(14, 60), (86, 62)], "straw", w=2.6)            # leaves yellowing...
    tube_leaf(a, (50, 46), (60, 26), (84, 50), 2.6, "pear", tipk=0.2)   # ...and fallen over at the neck
    tube_leaf(a, (50, 46), (42, 28), (18, 46), 2.6, "sage", tipk=0.2)
    bulb(a, 50, 73, 34, 28, "amber", neck=4.0)
    a.line("M48,46 L52,46", 1.0, 0.7, "bark")
    return a


def onion_tall(slug, seed, fc, body, leafc):
    def draw():
        a = Art(); soil(a, 88, marks=False)
        lc = "straw" if seed else leafc
        tubes(a, 50, 86, [(26, 62), (36, 52), (66, 54), (76, 64)], lc, w=2.2)
        swollen_stem(a, 50, 88, 30, "straw" if seed else leafc)
        mini_head(a, 50, 21, 11, fc, seed=seed, n=30, bodyc=body, stamens=not seed)
        if not seed:   # the papery spathe folded back under the head
            for sd in (-1, 1):
                a.leaf(50 + sd * 1.5, 31, 90 + sd * 45, 6, 0.4, "straw", lw=0.6, detail=False)
        return a
    return draw


# ------------------------------------------------------------------- shallot
def shallot_set():
    a = Art(); a.ground(38, marks=False); below(a, 40)
    bulb(a, 50, 82, 20, 34, "rust", neck=2.0, tear=True)
    return a


def shallot_young():
    a = Art(); soil(a, 72); white_roots(a, 50, 77, 6, 7, 120)
    tubes(a, 47, 64, [(34, 30), (42, 24)], "sage", w=2.0)
    tubes(a, 53, 64, [(58, 22), (66, 30)], "sage", w=2.0)
    bulb(a, 46.5, 77, 8, 13, "rust", neck=2.0, tear=True)    # already splitting into two
    bulb(a, 53.5, 77, 8, 13, "rust", neck=2.0, tear=True)
    return a


def shallot_crop():
    a = Art(); soil(a, 64)
    white_roots(a, 50, 76, 9, 9, 150)
    for x, e, c in ((40, (14, 56), "straw"), (60, (86, 58), "straw"), (44, (24, 34), "pear"), (56, (78, 36), "sage"), (50, (52, 24), "sage")):
        tube_leaf(a, (x, 50), ((x + e[0]) / 2, min(50, e[1]) - 8), e, 1.9, c, tipk=0.2)
    for x, h, s_ in ((36, 22, 0.85), (64, 22, 0.85), (43, 26, 1.0), (57, 26, 1.0), (50, 28, 1.0)):   # several teardrop bulbs on one base
        bulb(a, x, 76, 13 * s_, h, "rust", neck=1.8, tear=True, plate=False)
    a.shape("M40,75.4 L60,75.4 L58,77.4 L42,77.4 Z", "bark", 0.6)
    return a


# -------------------------------------------------------------------- garlic
def garlic_clove():
    a = Art(); a.ground(38, marks=False); below(a, 40)
    d = "M40,82 C38,70 42,56 52,46 C54,44 56,43 57,42 C58,50 62,62 61,74 C60.6,80 58,82 56,82 Z"   # curved back, flatter inner face, pointed tip
    a.shape(d, "white")
    a.shape("M57,42 C58,50 62,62 61,74 C60.6,80 58,82 56,82 C57,72 56,58 57,42 Z", "shade", 0, fa=0.1)
    a.line("M44,78 C43,68 47,56 54,46", 0.5, 0.35); a.line("M50,80 C50,70 52,58 56,46", 0.45, 0.3)
    a.line("M41,73 C41,66 45,58 50,51", 0.8, 0.45, "pink")   # a faint flush on the papery skin
    a.shape("M41,81.4 L57,81.4 L56,84 L42,84 Z", "bark", 0.7)  # the flat root plate
    return a


def garlic_plant(a, H, leaves, seed=False, lc="sage", lower=None, by=88):
    """The false stem of wrapped sheaths with flat leaves in two ranks, from by.
    lower: the colour of the two lowest leaves (brown as the bulb ripens)."""
    stem_top = (50, by - H)
    for k in sorted(range(leaves), key=lambda k: -k if lower else k):   # dead lower leaves drawn last, in front
        u = 0.15 + 0.85 * k / max(1, leaves - 1); y = by - H * u; sd = 1 if k % 2 else -1
        c = lower if (lower and k < 2) else ("straw" if (lower and k == 2) else lc)
        e = (50 + sd * (30 - 10 * u), y - 20 - 6 * u)
        if c == lower and lower:   # dead leaves, brown, hanging down limp
            e = (50 + sd * (30 - 8 * u), y + 3)
            flat_leaf(a, (50, y), (50 + sd * 14, y - 12), e, 5.6, c, prof="taper", lw=0.8)
        else:
            flat_leaf(a, (50, y), (50 + sd * 6, y - 14), e, 3.6, c, prof="taper", lw=1.1 if c == lc else 0.8)
    a.ribbon((50, by), (50, by - H * 0.5), stem_top, 4.2, 3.0, "pale" if not seed else "straw", lw=0.9)
    return stem_top


def garlic_young():
    a = Art(); soil(a, 88); white_roots(a, 50, 89, 6, 6, 120)
    garlic_plant(a, 26, 5)
    return a


def garlic_crop():
    a = Art(); soil(a, 62)
    white_roots(a, 50, 80, 9, 9, 150)
    q = garlic_plant(a, 30, 5, lower="bark", by=61)   # the lower leaves brown and dead, the upper ones still green
    c = (50, 70)
    a.polar(c[0], c[1], lambda h: 1 + 0.06 * abs(math.cos(3 * h)), 13, 10.5, 0, "white")   # the bulb in white papery skin
    for o in (-8, -3.5, 1.5, 6.5):   # the cloves showing through as bulges
        a.line(f"M{f(50 + o * 0.4)},{f(c[1] - 9)} Q{f(50 + o * 1.4)},{f(c[1])} {f(50 + o * 1.0)},{f(c[1] + 9.5)}", 0.6, 0.45)
    for o in (-6, 4):   # purple streaks
        a.line(f"M{f(50 + o * 0.5)},{f(c[1] - 6)} Q{f(50 + o * 1.3)},{f(c[1])} {f(50 + o * 1.0)},{f(c[1] + 6)}", 0.9, 0.55, "plum")
    a.shape("M45,79.6 L55,79.6 L54,81 L46,81 Z", "bark", 0.6)
    return a


def garlic_tall(seed):
    def draw():
        a = Art(); soil(a, 88); white_roots(a, 50, 89, 5, 5, 100)
        top = garlic_plant(a, 26 if not seed else 30, 5, seed=seed, lc="straw" if seed else "sage")
        x, y = top
        if seed:   # the scape stands straight once the bulbils ripen; dry head, the spathe split
            a.line(f"M{f(x)},{f(y)} Q{f(x + 1)},{f(26)} {f(x + 4)},{f(19)}", 1.6, 0.9, "straw")
            hx, hy = x + 5, 14
            for sd in (-1, 1):   # the papery spathe, split
                a.leaf(hx + sd * 1.5, hy + 4, 90 + sd * 40, 9, 0.3, "white", lw=0.6, detail=False)
            for j in range(11):   # a dry cluster of small bulbils like tiny cloves
                th = j * GOLD; rr = 5.2 * math.sqrt((j + 0.5) / 11)
                bx, by = hx + rr * math.cos(th), hy + rr * math.sin(th) * 0.85
                a.oval(bx, by, 2.2, 2.7, j * 30, "bark", 0.55)
                a.line(f"M{f(bx - 0.8)},{f(by - 1.2)} q0.8,-0.8 1.6,0", 0.4, 0.5, "white")
            return a
        # the scape loops once before it straightens, then ends in a long beaked spathe
        a.line(f"M{f(x)},{f(y)} C{f(x)},{f(y - 12)} {f(x + 13)},{f(y - 17)} {f(x + 11)},{f(y - 24)} C{f(x + 9)},{f(y - 31)} {f(x - 2)},{f(y - 27)} {f(x + 2)},{f(y - 22)} "
               f"C{f(x + 5)},{f(y - 17)} {f(x + 2)},{f(y - 34)} {f(x + 1)},{f(y - 37)}", 1.5, 0.9)
        h = (x + 1, y - 37)
        a.shape(f"M{f(h[0] - 2.2)},{f(h[1])} Q{f(h[0] - 2.4)},{f(h[1] - 5)} {f(h[0])},{f(h[1] - 8)} Q{f(h[0] + 3)},{f(h[1] - 14)} {f(h[0] + 2)},{f(h[1] - 22)} Q{f(h[0] + 1.6)},{f(h[1] - 10)} {f(h[0] + 2.4)},{f(h[1] - 5)} Q{f(h[0] + 2)},{f(h[1])} {f(h[0] - 2.2)},{f(h[1])} Z", "pale", 0.8)
        return a
    return draw


# -------------------------------------------------------------- spring onion
def spring_young():
    a = Art(); soil(a, 72)
    for x, h in ((26, 26), (42, 32), (58, 30), (74, 27)):   # a row of thin upright plants
        white_roots(a, x, 75, 4, 5, 90)
        tubes(a, x, 66, [(x - 6, 72 - h - 4), (x - 1, 72 - h - 10), (x + 5, 72 - h - 6)], "leaf", w=1.7)
        a.ribbon((x, 75), (x, 70), (x, 65), 2.4, 2.0, "white", lw=0.8)
    return a


def spring_crop():
    a = Art(); soil(a, 92, marks=False)
    for dx, g in ((-7, -8), (7, 8), (0, 0)):   # a bunch of several pulled together
        x = 50 + dx
        white_roots(a, x, 86, 6, 6, 120)
        tubes(a, x + g * 0.15, 50, [(x + g * 1.4 - 10, 10), (x + g * 1.4, 4), (x + g * 1.4 + 9, 12)], "leaf", w=2.4)
        a.ribbon((x, 86), (x + g * 0.05, 70), (x + g * 0.15, 50), 5.4, 4.2, "white", lw=0.9)   # the straight white shank...
        a.shape(f"M{f(x - 3.1)},{f(84)} Q{f(x)},{f(80)} {f(x + 3.1)},{f(84)} L{f(x + 2.8)},{f(86.4)} L{f(x - 2.8)},{f(86.4)} Z", "white", 0.8)   # ...only a little swollen at its foot
        a.shape(f"M{f(x - 2.4 + g * 0.12)},{f(56)} L{f(x + 2.4 + g * 0.12)},{f(56)} L{f(x + 2.2 + g * 0.15)},{f(50)} L{f(x - 2.2 + g * 0.15)},{f(50)} Z", "pale", 0)
    a.ribbon((43, 66), (50, 67.5), (57, 66), 2.2, 2.2, "straw", lw=0.8)   # tied with a band
    return a


# -------------------------------------------------------------------- chives
CHIVE_ENDS = [(30, 46), (35, 38), (40, 32), (45, 28), (50, 26), (55, 28), (60, 31), (65, 37), (70, 45)]


def chives_clump(a, y, scale, ends=CHIVE_ENDS, cut=(), col="deep"):
    for k, (ex, ey) in enumerate(ends):
        ex = 50 + (ex - 50) * scale; ey = y - (y - ey) * scale
        if k not in cut:
            tube_leaf(a, (50 + (k - 4) * 0.5, y), ((50 + ex) / 2, (y + ey) / 2 + 3 * scale), (ex, ey), 1.5, col, tipk=0.25)
    for k in cut:   # cut short and growing again: flat cut tops in front, a fresh tip pushing up beside each
        ex, ey = ends[k]; ex = 50 + (ex - 50) * scale * 0.9; ey = y - (y - ey) * scale
        m = (50 + (ex - 50) * 0.42, y - (y - ey) * 0.38)
        b = (50 + (k - 4) * 0.9, y)
        tube_leaf(a, b, ((b[0] + m[0]) / 2, (y + m[1]) / 2), m, 2.2, col, cut=1.0)
        n = (m[0] + 2.2, m[1] - 7)
        tube_leaf(a, (b[0] + 1.2, y), ((b[0] + n[0]) / 2 + 1, (y + n[1]) / 2), n, 1.4, "leaf", tipk=0.3)


def chives_young():
    a = Art(); soil(a, 80); white_roots(a, 50, 81, 5, 6, 100)
    chives_clump(a, 80, 0.55)
    return a


def chives_crop():
    a = Art(); soil(a, 86); white_roots(a, 50, 87, 7, 6, 140)
    chives_clump(a, 86, 1.0, CHIVE_ENDS + [(26, 58), (74, 56), (42, 20), (58, 22)], cut=(1, 4, 7))
    return a


def chives_tall(seed):
    def draw():
        a = Art(); soil(a, 86); white_roots(a, 50, 87, 7, 6, 140)
        chives_clump(a, 86, 1.0, CHIVE_ENDS + [(26, 58), (74, 56)], col="straw" if seed else "deep")
        for x, y in ((38, 30), (60, 24), (49, 20)):   # pompoms at about leaf height on slender stems
            a.stem((50 + (x - 50) * 0.2, 86), (50 + (x - 50) * 0.5, 60), (x, y + 5), 0.9)
            if seed:
                mini_head(a, x, y, 5.2, "straw", seed=True, egg=True, n=12)
            else:
                mini_head(a, x, y, 5.6, "mauve", egg=True, n=14, kind="bell", bodyc="mauve")
                a.leaf(x + 1, y + 6, 70, 4, 0.4, "lilac", lw=0.5, detail=False)   # the papery spathe
        return a
    return draw


def chives_dormant():
    a = Art(); soil(a, 66)
    for dx, g in ((-14, -150), (-6, -120), (4, -64), (13, -28), (-1, -95)):   # a few dead straw leaves
        e = T(50 + dx * 0.3, 66, g)(16 + abs(dx) * 0.3); d = f"M{f(50 + dx * 0.3)},66 Q{f(50 + dx)},{f(60)} {P(e)}"
        a.line(d, 2.0, 0.6); a.line(d, 1.2, 1.0, "straw")
    for x, h in ((42, 11), (48, 13), (54, 12), (59, 10)):   # the clump of small bulbs at the soil
        white_roots(a, x, 76, 4, 5, 90)
        bulb(a, x, 76, 5, h, "white", neck=1.6, lines=False, plate=False)
    return a


# --------------------------------------------------------------- wild garlic
def wg_set():
    a = Art(); a.ground(38, marks=False); below(a, 40)
    white_roots(a, 50, 84, 6, 7, 110)
    bulb(a, 50, 84, 11, 34, "white", neck=2.4, tear=True, plate=False)   # narrow, longer than wide
    return a


def wg_young():
    a = Art(); soil(a, 76)
    for x, h, g in ((34, 18, -4), (52, 26, 3), (68, 15, 6)):   # pointed leaves pushing up, rolled at first
        a.ribbon((x, 76), (x + g * 0.3, 76 - h * 0.5), (x + g, 76 - h), 4.0, 0.4, "leaf", lw=0.9)
        a.line(f"M{f(x + 0.6)},{f(75)} Q{f(x + g * 0.3 + 0.7)},{f(76 - h * 0.5)} {f(x + g * 0.9 + 0.3)},{f(76 - h * 0.9)}", 0.5, 0.4)
    put(a, "wild-garlic", 58, 76, -62, 26)   # one already opening
    return a


def wg_plant(a, x, y, leaves, s=1.0, fills=None, dry=False):
    for g, L in leaves:
        put(a, "wild-garlic", x, y, g, L * s, fills=fills, dry=dry)


WG_CARPET = [(29, 88, [(-126, 34), (-76, 32)]), (71, 88, [(-106, 32), (-54, 34)]), (50, 88, [(-116, 36), (-64, 38), (-92, 32)])]


def wg_crop():
    a = Art(); soil(a, 88)
    for x, y, lv in WG_CARPET:
        wg_plant(a, x, y, lv)
    for x, y, g in ((14, 88, -64), (86, 88, -116)):
        put(a, "wild-garlic", x, y, g, 24)
    return a


def wg_tall(seed):
    def draw():
        a = Art(); soil(a, 88)
        for x, y, lv in WG_CARPET:
            if seed:   # the leaves yellowing and collapsing
                lv = [(g + (-24 if g < -90 else 24), L * 0.78) for g, L in lv]
            wg_plant(a, x, y, lv, 0.9, fills={"leaf": "pear"} if seed else None)
        for x, top in ((42, 36), (60, 42)):   # leafless three-angled stems, about as tall as the leaves
            a.ribbon((x, 88), (x + 1, 60), (x, top), 2.0, 1.6, "pear" if seed else "leaf", lw=0.8)
            a.line(f"M{f(x + 0.3)},86 L{f(x + 0.2)},{f(top + 2)}", 0.4, 0.4)
            for k in range(7):
                g = -90 + (k - 3) * 28; e = T(x, top, g)(8 + 2.5 * (k % 2))
                a.line(f"M{f(x)},{f(top)} L{P(e)}", 0.5, 0.8)
                if seed:   # green three-lobed capsules
                    for j in range(3):
                        p = T(*e, j * 120 - 90)(1.0); a.oval(p[0], p[1], 1.25, 1.25, 0, "unripe", 0.5)
                else:
                    a.flower(e[0], e[1], 3.6, 6, "white", None, 0.34, start=g, lw=0.45)
                    a.dot(e[0], e[1], 0.5, "pear")
        return a
    return draw


def wg_dormant():
    a = Art(); soil(a, 56)
    for x, y, g, c in ((24, 55, 10, "bark"), (38, 54.5, -15, "amber"), (61, 55, 170, "bark"), (75, 54.6, -170, "rust")):   # leaf litter on the surface
        a.leaf(x, y, g, 9, 0.36, c, lw=0.6, detail=False)
    for x, y in ((38, 76), (56, 80), (68, 74)):   # the narrow white bulbs resting below
        white_roots(a, x, y, 4, 5, 90)
        bulb(a, x, y, 5, 14, "white", neck=1.4, tear=True, plate=False, lines=False)
    return a


# ------------------------------------------------------------ Bristol onion
def bo_set():
    a = Art(); a.ground(38, marks=False); below(a, 40)
    bulb(a, 50, 80, 20, 24, "bark", neck=2.0)
    for dx, s_ in ((-12, 1), (11, 0.85)):   # small offset bulblets at its base
        bulb(a, 50 + dx, 81, 6 * s_, 8 * s_, "seed", neck=1.0, lines=False, plate=False)
    return a


def bo_leaves(a, y, col, n=4, H=30):
    ends = [(30, y - H * 0.7), (40, y - H), (60, y - H * 0.95), (70, y - H * 0.6)][:n]
    for ex, ey in ends:
        tube_leaf(a, (50, y), ((50 + ex) / 2, (y + ey) / 2 + 3), (ex, ey), 1.4, col, tipk=0.3, groove=True)


def bo_young():
    a = Art(); soil(a, 70); white_roots(a, 50, 80, 5, 5, 100)
    a.ribbon((50, 80), (50, 74), (50, 68), 1.8, 1.8, "pale", lw=0.7)
    bo_leaves(a, 70, "sage", H=32)
    bulb(a, 50, 80, 7, 8, "bark", neck=1.6, lines=False)
    return a


def bo_tall(seed):
    def draw():
        a = Art(); soil(a, 86)
        for ex, ey, cx, cy in ((26, 85, 36, 70), (34, 82, 42, 66), (70, 84, 60, 68), (63, 86, 56, 72)):   # the leaves withered by flowering time: limp, yellow-brown, lying over
            tube_leaf(a, (50, 86), (cx, cy), (ex, ey), 1.8, "straw" if (ex + ey) % 2 else "bark", tipk=0.4)
        a.ribbon((50, 86), (50.5, 56), (50, 26), 1.8 if seed else 1.6, 1.4 if seed else 1.3, "straw" if seed else "leaf", lw=0.55 if seed else 0.8)
        if seed:
            mini_head(a, 50, 19, 6.2, "bark", seed=True, egg=True, n=18, seedc="bark")
        else:
            mini_head(a, 50, 19, 6.4, "beet", egg=True, n=24, kind="bell", topc="unripe", stamens=True)
        return a
    return draw


def bo_dormant():
    a = Art(); soil(a, 70); white_roots(a, 50, 80, 5, 5, 100)
    bo_leaves(a, 70, "sage", H=16)   # a few thin grey-green leaves at ground level through winter
    bulb(a, 50, 80, 7, 8, "bark", neck=1.6, lines=False)
    return a


STAGE = {
    "carrot": {"seed": seed_art(carrot_seed), "seedling": carrot_seedling, "young": carrot_young, "crop": carrot_crop, "flower": carrot_tall("flower"),
               "seedhead": carrot_tall("seedhead")},
    "parsnip": {"seed": seed_art(parsnip_seed), "seedling": parsnip_seedling, "young": parsnip_young, "crop": parsnip_crop,
                "flower": parsnip_tall("flower"), "seedhead": parsnip_tall("seedhead")},
    "celeriac": {"seed": seed_art(celeriac_seed), "seedling": celeriac_seedling, "young": celeriac_young, "crop": celeriac_crop,
                 "flower": celeriac_tall("flower"), "seedhead": celeriac_tall("seedhead")},
    "beetroot": {"seedling": beet_seedling("beet"), "young": beet_young("beetroot", "beet", 5.5, 5), "crop": beetroot_crop,
                 "flower": beet_tall("beetroot", "flower"), "seedhead": beet_tall("beetroot", "seedhead")},
    "mangelwurzel": {"seedling": beet_seedling("berry"), "young": beet_young("mangelwurzel", "rust", 6, 6.5), "crop": mangel_crop,
                     "flower": beet_tall("mangelwurzel", "flower"), "seedhead": beet_tall("mangelwurzel", "seedhead")},
    "radish": {"seed": seed_art(lambda a, x, y: round_seeds(a, x, y, "bark", r=5.4)), "seedling": crucifer_seedling("leaf", "leaf"),
               "young": radish_young, "crop": radish_crop, "flower": crucifer_tall("radish", "flower", "white", "spike", "fat", clasp=False),
               "seedhead": crucifer_tall("radish", "seedhead", "white", "spike", "fat", clasp=False)},
    "turnip": {"seed": seed_art(lambda a, x, y: round_seeds(a, x, y, "dark", r=4.2)), "seedling": crucifer_seedling("leaf", "leaf"),
               "young": turnip_young, "crop": turnip_crop, "flower": crucifer_tall("turnip", "flower", "sun", "flat"),
               "seedhead": crucifer_tall("turnip", "seedhead", "sun", "flat")},
    "swede": {"seed": seed_art(lambda a, x, y: round_seeds(a, x, y, "dark", r=4.2)), "seedling": crucifer_seedling("sage", "sage"),
              "young": swede_young, "crop": swede_crop, "flower": crucifer_tall("swede", "flower", "primrose", "level", stemc="sage"),
              "seedhead": crucifer_tall("swede", "seedhead", "primrose", "level", stemc="sage")},
    "kohlrabi": {"seed": seed_art(lambda a, x, y: round_seeds(a, x, y, "dark", r=4.2)), "seedling": crucifer_seedling("sage", None),
                 "young": kohlrabi_young, "crop": kohlrabi_crop,
                 "flower": crucifer_tall("kohlrabi", "flower", "primrose", "level", stemc="sage", base=kohlrabi_base),
                 "seedhead": crucifer_tall("kohlrabi", "seedhead", "primrose", "level", stemc="sage", base=kohlrabi_base)},
    "salsify": {"seed": seed_art(beaked_seed("bark", "straw")), "seedling": grass_seedling(), "young": salsify_young, "crop": salsify_crop,
                "flower": composite_tall("salsify", "flower", "roots_violet", "star", True, "plum"),
                "seedhead": composite_tall("salsify", "seedhead", "roots_violet", "star", True)},
    "scorzonera": {"seed": seed_art(plain_seed("straw", "seed")), "seedling": grass_seedling("leaf"), "young": scorzonera_young,
                   "crop": scorzonera_crop, "flower": composite_tall("scorzonera", "flower", "sun", "cup", False),
                   "seedhead": composite_tall("scorzonera", "seedhead", "sun", "cup", False)},
}

STAGE.update({
    "potatoes": {"tuber": potato_seedtuber, "young": potato_young, "flower": potato_in_flower, "crop": potato_crop},
    "leek": {"seed": seed_art(onion_seed), "young": leek_young, "crop": leek_crop, "flower": leek_tall(False), "seedhead": leek_tall(True)},
    "onion": {"set": onion_set, "young": onion_young(), "crop": onion_crop, "flower": onion_tall("onion", False, "white", "pale", "sage"),
              "seedhead": onion_tall("onion", True, "white", "pale", "sage")},
    "shallot": {"set": shallot_set, "young": shallot_young, "crop": shallot_crop},
    "garlic": {"clove": garlic_clove, "young": garlic_young, "crop": garlic_crop, "flower": ("In flower", garlic_tall(False)),
               "seedhead": garlic_tall(True)},
    "spring-onion": {"seed": seed_art(onion_seed), "seedling": allium_seedling("leaf"), "young": spring_young, "crop": spring_crop,
                     "flower": onion_tall("spring-onion", False, "white", "pale", "leaf"),
                     "seedhead": onion_tall("spring-onion", True, "white", "pale", "leaf")},
    "chives": {"seed": seed_art(onion_seed), "seedling": allium_seedling("deep", n=4), "young": chives_young, "crop": chives_crop,
               "flower": chives_tall(False), "seedhead": chives_tall(True), "dormant": chives_dormant},
    "wild-garlic": {"set": wg_set, "young": wg_young, "crop": wg_crop, "flower": wg_tall(False), "seedhead": wg_tall(True), "dormant": wg_dormant},
    "bristol-onion": {"set": bo_set, "young": bo_young, "flower": bo_tall(False), "seedhead": bo_tall(True), "dormant": bo_dormant},
})

COLOURS = {
    "roots_violet": ("#8A5A9E", "#9C74B4"),      # salsify's dull violet-purple (its description's palette_wish)
    "roots_yellow": ("#F5D22E", "#E6C42C"),      # a clear golden yellow: parsnip, turnip, scorzonera ("sun" read ochre-orange)
    "roots_lilacpale": ("#E4D6EE", "#A897C2"),   # leek flowers: pale pink-lilac, as in the photographs
}
