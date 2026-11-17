"""Windfall plant drawings, the redraw of 16 November 2026: the FLOWERS group.

William, this file holds every change to the drawings of 22 flowers: foxglove,
salvia, common evening-primrose, wallflower, yellow-rattle, selfheal, sweet
William, field poppy, Californian poppy, borage, Russian comfrey, lungwort,
cowslip, geum, viola, aubrieta, scarlet flax (linum), marsh-mallow, perforate
St John's-wort, lady's bedstraw, rock sea-lavender and candy cane sorrel.
Each drawing was checked, point by point, against the plant's written
description (Design/Plants/descriptions/<kind>.json, its "must_show" lists)
and photographs of the real plant.

What was wrong before: these plants were built from the shared templates, so
most whole plants were a cone of one stock leaf (a foxglove spire of round
scalloped leaves, a salvia like a green barrel), the leaf on the plant was
not the close-up leaf, and the flowers came from a few stock shapes (a
cowslip, a lungwort and a comfrey all had the same bell; a sweet William was
a cluster of plain five-petalled stars; selfheal's flower was a tuft).

What this file does, in four parts.

1. LEAVES. LEAVES near the top has one function for each kind (lf_foxglove,
   lf_geum and so on). Each draws one leaf, stalk and all, at any size: the
   close-up draws it about 92 squares long, and every whole-plant drawing
   draws the SAME function small (leaf()), so the two can never disagree
   again. The setting d says how much to draw: 2 everything, 1 the midrib
   and a few veins, 0 the outline only (for tiny leaves).
   - blade() draws a simple blade from a "profile" (prof(): how wide the leaf
     is along its length) with teeth (cut_teeth(): sharp, rounded or blunt,
     only where they really are, as on aubrieta's tip), a wavy edge, pressed-in
     veins ("pucker", "quilt"), bristles round the edge ("hairs"), pale specks
     of soft hair ("felt"), pale blotches (lungwort) or clear dots
     (St John's-wort), a paler underside, a coloured midrib (evening
     primrose's pink one) and more.
   - simple_leaf() adds the stalk; with "wing" the blade runs down the stalk
     as a narrow green band to its foot (foxglove, borage, cowslip).
   - New shapes of leaf: lf_geum (lyre-shaped: a big round lobed end leaflet
     and small uneven ones down the stalk), lf_viola (with its finger-lobed
     stipules), lf_marshmallow (shallowly three-lobed, velvety, veins
     spreading like a hand), lf_poppy (cut almost to the midrib into toothed,
     bristly lobes), lf_calpoppy (finely cut into narrow blunt segments) and
     lf_oxalis (three thread-like leaflets, each notched at its tip).
   - Three close-ups show more than one leaf, because the description asks
     for it: cl_pair (a pair on a piece of stem: sweet William's joined round
     a swollen joint, St John's-wort's with the two raised lines down the
     stem), cl_sprig (flax's small leaves up a thin stem) and cl_whorls
     (lady's bedstraw's rings of ten needle leaves, edges rolled under).

2. FLOWERS (close-ups). Each kind has its own fl_... function, built from a
   few parts: petal() (any petal: notched like an evening primrose's, pinked
   like a sweet William's, wavy like a poppy's), sepal(), ring() (petals round
   a middle, the back ones first), burst() (a spray of stamens), and some
   whole small flowers used again at plant size: glove() (a foxglove bell
   with its jutting, spotted lower lip), lip2() (a two-lipped flower with a
   hood: salvia, selfheal), cross4() (four petals in a cross: wallflower,
   aubrieta), pink5() (sweet William), star5() (borage), comfrey_bell(),
   funnel5() (lungwort), cowslip_flower() and rattle_flower().

3. LIFE STAGES. Every stage of every kind is drawn here (the STAGE table),
   from a few helpers: rosette() (leaves fanning from the ground; with
   "flat" a rosette lying flat, as foxglove and evening primrose make in
   their first year), shoot() and leafy() (stems and the kind's own leaves up
   them, singly or in crossing pairs), bushy() (wallflower), runners()
   (selfheal's creeping stems), whorl() (bedstraw), stone() (the rock
   aubrieta spills over), grass() (yellow-rattle grows in a meadow),
   seedling() (two seed leaves of the right shape, then the first true
   leaves, drawn about twice life size so a seedling reads in the app, each
   kind with its own seed-leaf shape), first_leaf() (a seedling's first leaf
   with its teeth made big enough to see), and capsule() and pod() for the
   fruits. Seed heads are drawn dry: brown or straw stems, not green. Each kind's seeds have
   their own small drawing (foxglove's dust, yellow-rattle's winged discs,
   geum's hooked tails). Candy cane sorrel's first stage is relabelled
   "Bulb", as it starts from a small pointed bulb.

4. COLOURS. Seven new ones: six asked for in the descriptions
   ("palette_wish"): flowers_violet (salvia), flowers_selfheal,
   flowers_orangered (wallflower 'Fire King'), flowers_scarlet (field poppy),
   flowers_blue (borage) and flowers_purple (aubrieta); and flowers_russet,
   the dull reddish brown of evening primrose seed. Each has a lighter value
   for dark mode. After the independent check of 17 November, geum and
   scarlet flax use flowers_scarlet and viola flowers_selfheal (violet-blue),
   as their photographs and descriptions ask; their descriptions say so.

Only this file and the 22 descriptions were changed. Nothing here is drawn at
random, so the drawings come out the same every time.
"""
import json, math, os
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10

GOLD = 2.39996
BASE = (20, 92)    # where a close-up leaf's stalk starts (as in leaves_flowers.py)
ANG = -52          # and the way a close-up leaf points
G = 72             # the soil line in a seedling drawing
CX, CY = 50, 44    # the middle of a close-up flower

COLOURS = {
    "flowers_violet":    ("#5A3FA8", "#8E78D6"),   # salvia: deep violet-blue
    "flowers_selfheal":  ("#6B55B5", "#9583D6"),   # selfheal: blue-violet
    "flowers_orangered": ("#E0532B", "#E8704C"),   # wallflower 'Fire King': orange-red
    "flowers_scarlet":   ("#E2302A", "#EA5A50"),   # field poppy: bright scarlet
    "flowers_blue":      ("#3D6FD1", "#6F93E2"),   # borage: strong clear blue
    "flowers_purple":    ("#8A4FB8", "#AA80D2"),   # aubrieta: rich purple-violet
    "flowers_russet":    ("#8E5238", "#A2664A"),   # evening primrose seed: dull reddish brown
}

HERE = os.path.dirname(os.path.abspath(__file__))
_PAL = {}


def pal(kind, part, default):
    """A colour from the kind's description ("palette"), by name. Read here
    directly, so this file need not import plants_all at the top."""
    if kind not in _PAL:
        p = os.path.join(HERE, "..", "..", "..", "Design", "Plants", "descriptions", f"{kind}.json")
        try:
            with open(p, encoding="utf-8") as fh:
                _PAL[kind] = json.load(fh).get("palette", {})
        except (OSError, ValueError):
            _PAL[kind] = {}
    from plant_kit import COLOURS as KC
    v = _PAL[kind].get(part)
    return v if (v in KC or v in COLOURS) else default


def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


def tilt(cy, k):
    """Squashes a drawing up and down about cy: a flat flower seen at a slant."""
    return lambda p: (p[0], cy + (p[1] - cy) * k)


def halton(i, b):
    """An evenly spread number between 0 and 1: the i-th of a sequence that
    fills the gaps left by the ones before (so dots look scattered, not in rows)."""
    f_, r = 1.0, 0.0
    i += 1
    while i:
        f_ /= b; r += f_ * (i % b); i //= b
    return r


def lerp(p, q, u):
    return (p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u)


# ============================================================ leaf outlines
def prof(umax=0.5, base="round", tip="point", bp=None, tp=None):
    """A leaf's width along its length (u: 0 at the base, 1 at the tip), as a
    share of its widest. umax: where it is widest. base: "wedge", "round" or
    "taper" (a long narrow wedge). tip: "point", "round", "blunt" or "acum".
    bp and tp make the base and tip fuller (small numbers) or thinner (big)."""
    def fn(u):
        if u <= 0 or u >= 1:
            return 0.0
        if u <= umax:
            v = u / umax
            if base == "wedge":
                return v ** (bp or 1.0)
            if base == "taper":
                return v ** (bp or 1.7)
            return math.sin(math.pi / 2 * v) ** (bp or 0.55)
        v = (u - umax) / (1 - umax)
        if tip == "round":
            return (1 - v ** (tp or 2.2)) ** 0.5
        if tip == "blunt":
            return (1 - v ** (tp or 3.0)) ** 0.42
        if tip == "acum":
            return math.cos(math.pi / 2 * v) ** 0.75 * (1 - v) ** (tp or 0.9)
        return math.cos(math.pi / 2 * v) ** (tp or 0.95)
    return fn


# The nick across one tooth: s runs 0 to 1 along the tooth (towards the leaf
# tip). 1 is the bottom of a nick, 0 the point of a tooth.
NICK = {
    "saw":   lambda s: (1 - s) ** 1.6,                        # sharp, forward-pointing
    "round": lambda s: abs(math.cos(math.pi * s)) ** 2.4,     # rounded (scalloped)
    "blunt": lambda s: abs(math.cos(math.pi * s)) ** 1.4,     # coarse and rather blunt
}


def half_edge(L, W, pf, back=0.0, n=120):
    """The upper edge of a leaf laid along x from its base (0,0) to its tip
    (L,0). back: a heart-shaped base, its lobes reaching back past the stalk
    by that share of the length."""
    pts = []
    for i in range(n + 1):
        u = i / n; x = L * u
        if back and u < 0.4:
            x -= back * L * math.sin(math.pi * u / 0.4)
        pts.append((x, pf(u) * W / 2))
    return pts


def cut_teeth(pts, n, depth, tk="saw", tfrom=0.06, tto=1.0, wave=0.0, nw=0, irr=0.0):
    """Cuts teeth into an edge: each point moves in towards the midrib by up
    to depth grid squares, n teeth between tfrom and tto (shares of the
    edge's length). wave: a gentle wave of nw bends as well. irr makes the
    teeth uneven in depth (a cowslip's crinkled edge)."""
    seg = [math.dist(p, q) for p, q in zip(pts, pts[1:])]
    tot = sum(seg) or 1; s = [0.0]
    for d in seg:
        s.append(s[-1] + d / tot)
    out = []
    for i, (x, y) in enumerate(pts):
        p0 = pts[max(0, i - 1)]; p1 = pts[min(len(pts) - 1, i + 1)]
        tx, ty = p1[0] - p0[0], p1[1] - p0[1]; m = math.hypot(tx, ty) or 1
        sg = 1 if y >= 0 else -1
        nx, ny = sg * ty / m, -sg * tx / m        # points in, towards the midrib
        d = 0.0
        fade = max(0.0, min(1.0, (1 - s[i]) / 0.05, s[i] / 0.04))
        if n and tfrom < s[i] < tto:
            v = (s[i] - tfrom) / (tto - tfrom); q = (v * n) % 1; k = int(v * n)
            d += depth * (1 + irr * math.sin(k * 2.3 + 1)) * NICK[tk](q) * min(1.0, v * n / 0.6, (1 - v) * n / 0.4 + 0.3) * fade
        if wave:
            d += wave * (0.5 + 0.5 * math.sin(2 * math.pi * s[i] * nw)) * fade
        out.append((x + nx * d, y + ny * d))
    return out


def width_at(pts, x):
    """The half width of an edge at distance x along the midrib."""
    best = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if (x0 - x) * (x1 - x) <= 0 and x1 != x0:
            best = max(best, abs(y0 + (y1 - y0) * (x - x0) / (x1 - x0)))
    return best


def blade(a, x, y, ang, L, W, fill, pf, back=0.0, teeth=0, td=0.0, tk="saw", tfrom=0.06, tto=1.0, wave=0.0, nw=0,
          irr=0.0, veins=5, vang=0.16, quilt=False, pucker=False, hairs=0, felt=0, spots=None, spotn=16, spotr=1.4,
          under=None, midc="line", midw=0.8, mida=0.55, lw=1.1, shade=0.1, d=2, bend=0.0, gloss=False, fold=False, vfrom=0.0):
    """One leaf blade from x,y (where the stalk joins) along ang, L long and W
    wide. d is how much to draw: 2 everything (a close-up), 1 the midrib and
    a few veins (a leaf on a whole plant), 0 the outline only (a tiny leaf).
    teeth/td/tk: the teeth; wave/nw: a wavy edge; quilt: the fine net of
    pressed-in veins; pucker: the blade bulging between them; hairs: a fringe
    of bristles; felt: pale specks of soft hair; spots: pale blotches (lungwort)
    or clear dots (St John's-wort); under: the paler underside showing along
    one edge; midc/midw: a coloured or broad midrib; fold: the blade folded
    a little along the midrib (one half darker)."""
    t = T(x, y, ang)

    def mp(p):
        px, py = p
        return t(px, py + (bend * L * 4 * (px / L) * (1 - px / L) if L else 0))

    top = half_edge(L, W, pf, back, n=120 if d == 2 else 40)
    if teeth or wave:
        top = cut_teeth(top, teeth, td, tk, tfrom, tto, wave, nw, irr)
    bot = [(px, -py) for px, py in top]
    a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), fill, lw)
    if under and d >= 1:   # the paler underside, seen where the lower edge turns up a little
        i0 = int(len(bot) * max(0.25, vfrom + 0.1)); i1 = int(len(bot) * 0.8)
        inner = [(px, py * (1 - 0.22 * math.sin(math.pi * (i - i0) / (i1 - i0)))) for i, (px, py) in enumerate(bot) if i0 <= i <= i1]
        a.shape(path([mp(p) for p in bot[i0:i1 + 1]] + [mp(p) for p in inner[::-1]]), under, 0)
        if d == 2:
            a.line(opath([mp(p) for p in inner[2:-2]]), 0.45, 0.45)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((p[0], 0)) for p in top[::-1]]), "shade", 0, fa=shade + (0.06 if fold else 0))
    if gloss and d >= 1:
        a.line(opath([mp((L * u, width_at(top, L * u) * 0.5)) for u in (0.25, 0.38, 0.52, 0.64)]), 1.2 if d == 2 else 0.7, 0.4, "white")
    if spots and d >= 1:
        for j in range(spotn):
            u = vfrom + (1 - vfrom) * (0.1 + 0.8 * halton(j, 2)); v = (halton(j, 3) - 0.5) * 1.7
            p = mp((L * u, width_at(top, L * u) * v))
            r = spotr * (0.7 + 0.5 * ((j * 0.29) % 1))
            a.oval(p[0], p[1], r, r * 0.8, j * 40, spots, 0, la=0)
    if felt and d >= 1:
        for k in range(felt):
            u = vfrom + (1 - vfrom) * (0.08 + 0.84 * halton(k, 2)); v = (halton(k, 3) - 0.5) * 1.7
            p = mp((L * u, width_at(top, L * u) * v))
            a.dot(p[0], p[1], 0.32 if d == 2 else 0.22, "white")
    if d == 0:
        return top
    if midw:
        a.line(opath([mp((L * u, 0)) for u in (0.0, 0.3, 0.6, 0.93)]), midw if d == 2 else (min(midw, 0.6) if midc == "line" else midw * 0.6), mida if midc == "line" else 0.9, midc)
    nv = veins if d == 2 else min(veins, 3)
    ends = []
    for k in range(nv):
        u1 = vfrom + (1 - vfrom) * (0.16 + 0.7 * (k + 0.5) / nv)
        u0 = max(0.02 + vfrom, u1 - vang * (1 - vfrom))
        for sd in (1, -1):
            w1 = sd * width_at(top, L * u1) * 0.82
            p0, c, p1 = mp((L * u0, 0)), mp((L * (u0 + vang * 0.4), w1 * 0.55)), mp((L * u1, w1))
            a.line(f"M{P(p0)} Q{P(c)} {P(p1)}", (0.6 if pucker else 0.5) if d == 2 else 0.4, (0.5 if pucker else 0.36) if d == 2 else 0.3)
            if pucker and d == 2:   # the blade bulging up between the pressed-in veins: a light line beside each
                q0, qc, q1 = mp((L * (u0 + 0.03), sd * 0.8)), mp((L * (u0 + vang * 0.4 + 0.04), w1 * 0.5)), mp((L * (u1 + 0.03), w1 * 0.9))
                a.line(f"M{P(q0)} Q{P(qc)} {P(q1)}", 0.8, 0.22, "white")
            ends.append((u0, u1, w1))
    if quilt and d == 2:   # the fine net of veins between the side veins
        for u0, u1, w1 in ends:
            for v in (0.3, 0.55, 0.8):
                pa = (L * (u0 + (u1 - u0) * v + vang * 0.15), w1 * v * 0.85)
                pb = (L * (u0 + (u1 - u0) * v + 0.7 / max(1, nv) * 0.9), w1 * v * 0.7)
                a.line(f"M{P(mp(pa))} L{P(mp(pb))}", 0.38, 0.26)
    if hairs and d == 2:   # a fringe of stiff hairs round the edge
        for side, sg in ((top, 1), (bot, -1)):
            step = max(2, len(side) // hairs)
            for i in range(max(4, int(len(side) * vfrom)), len(side) - 3, step):
                (x0, y0), (x1, y1) = side[i - 1], side[i + 1]
                tx, ty = x1 - x0, y1 - y0; m = math.hypot(tx, ty) or 1
                nx, ny = -ty / m * sg, tx / m * sg
                px, py = side[i]
                a.line(f"M{P(mp((px, py)))} L{P(mp((px - nx * 1.5 + tx / m * 0.8, py - ny * 1.5 + ty / m * 0.8)))}", 0.4, 0.55)
    return top


def stalk(a, p0, c, p1, w0=2.4, w1=1.8, fill="leaf", lw=0.9):
    return a.ribbon(p0, c, p1, w0, w1, fill, lw=lw)


def lwid(d):
    """The outline width for a leaf drawn at detail d."""
    return (0.6, 0.8, 1.1)[d]


# ============================================================ each kind's leaf
# Each function draws one leaf of its kind, stalk and all, from x,y (the foot
# of the stalk) along ang, L long overall. d is the detail (see blade). The
# close-up draws it about 92 long; the whole-plant drawings draw the SAME
# function small, so the two can never disagree.

def simple_leaf(a, x, y, ang, L, fill, d, petiole=0.2, wing=0.0, W=0.4, stalkc=None, sw=None, chan=False, pf=None, **kw):
    """A simple leaf on a stalk. petiole: the stalk's share of the length.
    wing: a winged stalk, the blade running down it as a narrow green band
    (its half width as a share of the blade's width) all the way to the foot.
    chan: a groove down the stalk (comfrey). Everything else goes to blade."""
    t = T(x, y, ang)
    if wing and petiole > 0.01:   # one outline from the foot of the stalk to the tip
        p = petiole; bp = pf

        def wpf(u):
            if u < p:
                return wing * (0.45 + 0.55 * (u / p) ** 1.4) * min(1, u / 0.02 + 0.4)
            v = (u - p) / (1 - p)
            w0 = wing * (1 - v) ** 1.5   # the wing fading out up the blade
            return w0 + bp(v) * (1 - w0)
        blade(a, x, y, ang, L, L * (1 - p) * W, fill, wpf, lw=lwid(d), d=d, vfrom=p, **kw)
        return
    Lb = L * (1 - petiole)
    if petiole > 0.01:
        A = t(L * petiole)
        w0 = sw or max(0.8, L * 0.026); w1 = w0 * 0.78
        with a.on(STEM if d < 2 else a.layer):
            a.ribbon((x, y), t(L * petiole * 0.5, L * 0.006), A, w0, w1, stalkc or fill, lw=lwid(d) * 0.85)
        if chan and d >= 1:
            a.line(opath([t(L * petiole * u) for u in (0.08, 0.5, 0.95)]), 0.5, 0.45)
    else:
        A = (x, y)
    blade(a, A[0], A[1], ang, Lb, Lb * W, fill, pf, lw=lwid(d), d=d, **kw)


def lf_foxglove(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.3, wing=0.2, W=0.42, pf=prof(0.42, "round", "point", bp=0.95, tp=1.55),
                teeth=26, td=L * 0.009, tk="round", tfrom=0.34, veins=7, vang=0.2, quilt=True, pucker=True, under="pale",
                hairs=36, midc="pale", midw=1.4)


def lf_salvia(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.14, W=0.36, pf=prof(0.26, "round", "blunt", bp=0.3, tp=1.8),
                back=0.05, teeth=20, td=L * 0.012, tk="round", tfrom=0.05, veins=7, vang=0.15, quilt=True, pucker=True,
                under="pale", hairs=24)


def lf_primrose(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.1, W=0.25, pf=prof(0.42, "taper", "point", bp=1.3, tp=1.0),
                teeth=6, td=L * 0.01, tk="saw", tfrom=0.2, tto=0.85, wave=L * 0.006, nw=4, veins=7, vang=0.2,
                midc="pink" if fill in ("leaf", "deep", "pale") else "bark", midw=2.0)


def lf_wallflower(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.05, W=0.17, pf=prof(0.55, "taper", "point", bp=1.4, tp=0.9),
                veins=0, felt=40, midw=1.0)


def lf_rattle(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.0, W=0.26, pf=prof(0.22, "round", "point", bp=0.4, tp=1.2),
                teeth=11, td=L * 0.03, tk="saw", tfrom=0.04, veins=4, vang=0.18, pucker=True)


def lf_selfheal(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.32, W=0.52, pf=prof(0.4, "round", "blunt", bp=0.6, tp=2.2),
                wave=L * 0.008, nw=3, veins=4, vang=0.2, pucker=True, hairs=14)


def lf_sweetwilliam(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.0, W=0.2, pf=prof(0.32, "round", "point", bp=0.5, tp=1.25),
                veins=0, midw=1.0, gloss=True)
    if d >= 1:   # the faint parallel veins
        t = T(x, y, ang)
        for o in (0.3, -0.3):
            a.line(opath([t(L * u, o * L * 0.2 / 2 * prof(0.32, "round", "point", bp=0.5, tp=1.25)(u)) for u in (0.1, 0.35, 0.6, 0.8)]), 0.4, 0.3)


def lf_borage(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.24, wing=0.16, W=0.42, pf=prof(0.42, "round", "blunt", bp=1.0, tp=2.0),
                wave=L * 0.014, nw=5, veins=6, vang=0.2, quilt=True, pucker=True, hairs=40, felt=60)


def lf_comfrey(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.3, W=0.4, pf=prof(0.36, "round", "point", bp=0.6, tp=1.1), chan=True,
                sw=max(1.0, L * 0.034), wave=L * 0.008, nw=4, veins=7, vang=0.2, quilt=True, pucker=True, hairs=40, felt=30)


def lf_lungwort(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.42, W=0.56, pf=prof(0.3, "round", "point", bp=0.32, tp=1.0), back=0.05,
                veins=4, vang=0.22, hairs=26, spots="pale", spotn=36 if d == 2 else 9, spotr=L * (0.019 if d == 2 else 0.036))


def lf_cowslip(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.34, wing=0.22, W=0.5, pf=prof(0.5, "round", "round", bp=0.45, tp=2.4),
                teeth=10, td=L * 0.013, tk="round", tfrom=0.4, irr=0.6, wave=L * 0.006, nw=6, veins=6, vang=0.22,
                quilt=True, pucker=True, under="pale")


def lf_aubrieta(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.06, W=0.34, pf=prof(0.74, "taper", "round", bp=1.5, tp=2.2),
                teeth=3, td=L * 0.035, tk="saw", tfrom=0.62, tto=0.93, veins=0, felt=70, midw=0.9)


def lf_linum(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.0, W=0.13, pf=prof(0.35, "round", "point", bp=0.6, tp=1.1), veins=0, midw=0.7)


def lf_sjw(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.0, W=0.36, pf=prof(0.42, "round", "blunt", bp=0.4, tp=2.4), veins=3,
                vang=0.24, spots="white", spotn=40 if d == 2 else 0, spotr=max(0.45, L * 0.018))


def lf_sealavender(a, x, y, ang, L, fill, d):
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.34, wing=0.1, W=0.4, pf=prof(0.7, "taper", "round", bp=1.3, tp=2.0),
                veins=0, midw=1.0, gloss=True)
    if d >= 1:   # a fainter vein each side of the midrib, from the base
        t = T(x, y, ang); Lb = L * 0.66; o = L * 0.34
        pf = prof(0.7, "taper", "round", bp=1.3, tp=2.0)
        for sg in (1, -1):
            a.line(opath([t(o + Lb * u, sg * Lb * 0.4 / 2 * pf(u) * 0.5) for u in (0.05, 0.3, 0.55, 0.75)]), 0.4, 0.3)


def lf_geum(a, x, y, ang, L, fill, d):
    """A lyre-shaped leaf: a big round, shallowly lobed, scalloped end leaflet
    and pairs of small uneven leaflets down the hairy stalk, big and tiny ones
    taking turns."""
    t = T(x, y, ang)
    R = L * 0.25; c0 = L * 0.62           # the end leaflet's size, and where it joins
    with a.on(STEM if d < 2 else a.layer):
        a.ribbon((x, y), t(c0 * 0.5, L * 0.008), t(c0), max(0.8, L * 0.024), max(0.6, L * 0.018), fill, lw=lwid(d) * 0.85)
    if d >= 2:
        for k in range(14):   # hairs on the stalk
            p = t(c0 * (0.08 + 0.06 * k), 0); sg = 1 if k % 2 else -1
            a.line(f"M{P(p)} L{P(T(*p, ang + sg * 60)(1.6))}", 0.4, 0.5)
    for u, s in ((0.14, 0.5), (0.24, 0.25), (0.34, 0.75), (0.43, 0.3), (0.52, 1.0)):
        p = t(c0 * u / 0.6)
        for sg in (1, -1):
            l = L * 0.13 * s * (1.06 if sg > 0 else 0.9)
            if l < 1.6:
                continue
            blade(a, p[0], p[1], ang + sg * (64 - 10 * s), l, l * 0.7, fill, prof(0.45, "round", "round", bp=0.5),
                  teeth=3 if l > 5 else 0, td=l * 0.08, tk="round", veins=2 if l > 6 else 0, lw=lwid(d) * 0.85, d=min(d, 1), midw=0.4)
    lobes = 5
    g = lambda h: (0.92 + 0.08 * abs(math.cos(lobes * h / 2)) ** 0.6) * (1 - 0.55 * math.exp(-((abs(h) - math.pi) / 0.42) ** 2))
    teeth = 26 if d else 0
    tdp = max(0.6, R * 0.05) if d else 0

    def gg(h):
        q = ((h + math.pi) * teeth / (2 * math.pi)) % 1 if teeth else 0
        return g(h) * (1 - (tdp / R) * abs(math.cos(math.pi * q)) ** 2.4 if teeth else 1)
    off = R * gg(math.pi)
    cen = t(c0 + off)
    pts = [T(*cen, ang)(R * gg(h) * math.cos(h), R * gg(h) * math.sin(h) * 1.04) for h in [-math.pi + 2 * math.pi * i / 260 for i in range(261)]]
    a.shape(path(pts), fill, lwid(d))
    a.shape(path(pts[130:] + [t(c0)]), "shade", 0, fa=0.1)
    if d >= 1:
        for k in range(lobes):   # the main veins spreading like a hand from the base
            h = -math.pi * 0.8 + 1.6 * math.pi * k / (lobes - 1)
            e = T(*cen, ang)(R * 0.86 * gg(h) * math.cos(h), R * 0.86 * gg(h) * math.sin(h))
            a.line(f"M{P(t(c0))} Q{P(lerp(t(c0), e, 0.5))} {P(e)}", 0.5 if d == 2 else 0.4, 0.42)
            if d == 2:
                for v in (0.45, 0.7):
                    b = lerp(t(c0), e, v); va = math.degrees(math.atan2(e[1] - t(c0)[1], e[0] - t(c0)[0]))
                    for sg in (1, -1):
                        a.line(f"M{P(b)} L{P(T(*b, va + sg * 42)(R * 0.2))}", 0.38, 0.26)


def lf_viola(a, x, y, ang, L, fill, d):
    """An oval scalloped leaf on a stalk, with a pair of large leafy stipules
    at the foot of the stalk, each cut into finger-like lobes, the middle
    lobe the biggest and leaf-like."""
    t = T(x, y, ang)
    simple_leaf(a, x, y, ang, L, fill, d, petiole=0.38, W=0.58, pf=prof(0.36, "round", "blunt", bp=0.4, tp=1.4), back=0.02,
                teeth=9, td=L * 0.018, tk="round", veins=4, vang=0.2, gloss=True)
    if L < 7:
        return
    s = t(L * 0.03)
    for sg in (1, -1):
        base = ang + sg * 38; tq = T(*s, base)
        lp = 0.24 * L
        blade(a, s[0], s[1], base, lp, lp * 0.36, fill, prof(0.45, "round", "point"), veins=0, lw=lwid(d) * 0.8, d=min(d, 1), midw=0.4)
        for u, off, k in ((0.25, 1, 0.45), (0.45, -1, 0.42), (0.6, 1, 0.38), (0.35, -1, 0.3)):
            p = tq(lp * u)
            blade(a, p[0], p[1], base + off * sg * 46, lp * k, lp * k * 0.24, fill, prof(0.4, "round", "point"), veins=0, lw=lwid(d) * 0.7, d=0, shade=0.06)


def lf_marshmallow(a, x, y, ang, L, fill, d):
    """Oval to triangular, shallowly three-lobed (sometimes five), with
    irregular blunt teeth, three to five veins spreading from the base,
    velvety, often a little folded along the middle."""
    if d < 2:   # small on a whole plant: the lobes are too shallow to see, so a toothed triangular oval
        simple_leaf(a, x, y, ang, L, fill, d, petiole=0.2, W=0.72, pf=prof(0.3, "round", "point", bp=0.45, tp=1.1),
                    teeth=7, td=L * 0.025, tk="blunt", veins=2, vang=0.25, shade=0.14)
        return
    t = T(x, y, ang); pf_ = 0.18
    with a.on(STEM if d < 2 else a.layer):
        a.ribbon((x, y), t(L * pf_ * 0.5, L * 0.005), t(L * pf_), max(0.8, L * 0.024), max(0.6, L * 0.019), fill, lw=lwid(d) * 0.85)
    Lb = L * (1 - pf_); A = t(L * pf_)
    n = 220 if d == 2 else 80; teeth = 30 if d == 2 else (14 if d else 0)
    def rad(h):   # h: 0 the tip, +-pi the base
        tri = 0.42 + 0.58 * math.cos(h / 2) ** 0.8 + 0.22 * math.exp(-(h / 0.28) ** 2)   # broad below, drawn out to a point
        lob = 1 + 0.16 * math.exp(-((abs(h) - 1.35) / 0.32) ** 2)    # a shallow side lobe each side
        lob *= 1 - 0.1 * math.exp(-((abs(h) - 0.85) / 0.22) ** 2)    # the dip between side lobe and tip
        base = 1 - 0.45 * math.exp(-((abs(h) - math.pi) / 0.6) ** 2)
        q = ((h + math.pi) * teeth / (2 * math.pi)) % 1 if teeth else 0
        tooth = 1 - (0.05 + 0.025 * math.sin(int((h + math.pi) * teeth / (2 * math.pi)) * 2.1)) * abs(math.cos(math.pi * q)) ** 1.4 if teeth else 1
        return tri * lob * base * tooth
    R = Lb * 0.55; off = R * rad(math.pi)
    cen = T(*A, ang)(off)
    loc = lambda h, k=1.0: T(*cen, ang)(R * 1.0 * rad(h) * math.cos(h) * k, R * 0.82 * rad(h) * math.sin(h) * k)
    pts = [loc(-math.pi + 2 * math.pi * i / n) for i in range(n + 1)]
    a.shape(path(pts), fill, lwid(d))
    a.shape(path(pts[n // 2:] + [A]), "shade", 0, fa=0.17 if d == 2 else 0.1)   # folded a little: one half darker
    if d >= 1:
        for h in (0.0, 1.35, -1.35, 2.3, -2.3):
            e = loc(h, 0.86)
            a.line(f"M{P(A)} Q{P(lerp(A, e, 0.5))} {P(e)}", 0.55 if d == 2 else 0.4, 0.45)
            if d == 2 and abs(h) < 2:
                for v in (0.4, 0.65):
                    b = lerp(A, e, v); va = math.degrees(math.atan2(e[1] - A[1], e[0] - A[0]))
                    for sg in (1, -1):
                        a.line(f"M{P(b)} L{P(T(*b, va + sg * 40)(R * 0.16))}", 0.38, 0.26)
    if d == 2:   # velvet: fine pale specks all over
        for k in range(110):
            h = -math.pi * 0.9 + 1.8 * math.pi * ((k * 0.618) % 1); r_ = 0.15 + 0.75 * ((k * 0.37) % 1)
            p = loc(h, r_); a.dot(p[0], p[1], 0.3, "white")


def lf_poppy(a, x, y, ang, L, fill, d):
    """Cut almost to the midrib into narrow lobes, each with a few coarse sharp
    bristle-tipped teeth, the end lobe longer and pointed; bristly."""
    t = T(x, y, ang); pf_ = 0.16
    with a.on(STEM if d < 2 else a.layer):
        a.ribbon((x, y), t(L * pf_ * 0.5, 0), t(L * pf_), max(0.8, L * 0.024), max(0.7, L * 0.02), fill, lw=lwid(d) * 0.85)
    Lb = L * (1 - pf_); o = L * pf_
    # the leaf outline: a narrow wing along the midrib with lobes off it, built as one edge each side
    lobes = [(0.08, 0.42), (0.26, 0.62), (0.45, 0.7), (0.63, 0.6), (0.79, 0.42)]
    def edge(side):
        pts = [(0, 0)]
        for i, (u, s) in enumerate(lobes):
            u = u + (0.04 if side < 0 else 0)
            ln = Lb * 0.3 * s; wb = Lb * 0.04 * (0.6 + s * 0.5)   # lobe length, half width at its base
            la = math.radians(52)
            base0 = Lb * u - wb; base1 = Lb * u + wb
            wing = Lb * 0.025
            pts.append((base0, side * wing))
            tipx = Lb * u + ln * math.cos(la); tipy = side * (wing + ln * math.sin(la))
            nt = 3 if d else 0
            for k in range(1, 7):   # the lower edge of the lobe, with a tooth or two
                v = k / 7; px = base0 + (tipx - base0) * v; py = side * wing + (tipy - side * wing) * v
                if nt and k in (3, 5):
                    px -= Lb * 0.028; py += side * Lb * 0.016
                pts.append((px, py))
            pts.append((tipx, tipy))
            for k in range(1, 7):   # the upper edge back down
                v = k / 7; px = tipx + (base1 - tipx) * v; py = tipy + (side * wing - tipy) * v
                if nt and k in (2, 4):
                    px += Lb * 0.03; py += side * Lb * 0.012
                pts.append((px, py))
        # the end lobe
        pts.append((Lb * 0.88, side * Lb * 0.03))
        if d:
            pts.append((Lb * 0.9, side * Lb * 0.05)); pts.append((Lb * 0.92, side * Lb * 0.025))
        pts.append((Lb, 0))
        return pts
    up, dn = edge(1), edge(-1)
    a.shape(path([t(o + px, py) for px, py in up] + [t(o + px, py) for px, py in dn[::-1]]), fill, lwid(d))
    a.shape(path([t(o + px, py) for px, py in up] + [t(o + Lb, 0), t(o, 0)]), "shade", 0, fa=0.1)
    if d >= 1:
        a.line(opath([t(o + Lb * u, 0) for u in (0, 0.5, 0.95)]), 0.7 if d == 2 else 0.45, 0.55)
        for u, s in lobes:
            for side in (1, -1):
                uu = u + (0.04 if side < 0 else 0); ln = Lb * 0.3 * s * 0.8
                a.line(f"M{P(t(o + Lb * uu, 0))} L{P(t(o + Lb * uu + ln * math.cos(math.radians(52)), side * ln * math.sin(math.radians(52))))}", 0.45, 0.4)
    if d == 2:   # bristles along the edge
        for px, py in (up + dn)[3::4]:
            sg = 1 if py >= 0 else -1
            a.line(f"M{P(t(o + px, py))} L{P(t(o + px + 0.8, py + sg * 1.6))}", 0.4, 0.55)


def lf_calpoppy(a, x, y, ang, L, fill, d):
    """Finely cut two or three times into many narrow, smooth, blunt
    segments, the whole leaf a balanced triangle on a long thin stalk:
    feathery, blue-grey."""
    t = T(x, y, ang); st = 0.34                    # the stalk's share of the length
    q = Quad((x, y), t(L * 0.6, L * 0.015), t(L))
    with a.on(STEM if d < 2 else a.layer):
        a.ribbon(q.p0, q.c, q.p1, max(0.6, L * 0.016), max(0.4, L * 0.007), fill, lw=lwid(d) * 0.75)
    sw = max(0.7, L * 0.017)   # a segment's width
    segp = prof(0.3, "round", "blunt", bp=0.4, tp=3)

    def seg(px, py, a_, l):
        if d < 2 or l < 4:
            e = T(px, py, a_)(l)
            w = max(0.8, sw * 1.25)
            a.line(f"M{f(px)},{f(py)} L{P(e)}", w, 0.8, "line")
            a.line(f"M{f(px)},{f(py)} L{P(e)}", w * 0.6, 1.0, fill)
            return
        blade(a, px, py, a_, l, sw, fill, segp, veins=0, midw=0, lw=0.5, d=0, shade=0)

    def branch(p, pa, l1, depth):
        """One division: a thin axis with forked narrow segments down it."""
        tq = T(*p, pa)
        if d == 2:
            a.line(f"M{P(p)} L{P(tq(l1 * 0.7))}", max(0.45, L * 0.006), 0.8)
        else:   # small: the axis in the leaf's own colour, so the leaf reads blue-grey, not dark
            a.line(f"M{P(p)} L{P(tq(l1 * 0.7))}", 0.9, 0.6, "line"); a.line(f"M{P(p)} L{P(tq(l1 * 0.7))}", 0.5, 1.0, fill)
        n = 3 if depth else 2
        for j in range(n):
            v = 0.25 + 0.5 * j / max(1, n - 1); b = tq(l1 * v); lk = l1 * (0.42 - 0.12 * v)
            for sg2 in (1, -1):
                a2 = pa + sg2 * 42
                if depth and d == 2 and lk > 7:   # cut once more: a short stalk forking into two or three
                    c = T(*b, a2)(lk * 0.35)
                    a.line(f"M{P(b)} L{P(c)}", 0.4, 0.75)
                    seg(*c, a2 - 20, lk * 0.62); seg(*c, a2 + 18, lk * 0.55)
                else:
                    seg(*b, a2, lk)
        c = tq(l1 * 0.7)
        for off, k in ((-24, 0.3), (0, 0.38), (24, 0.3)):
            seg(*c, pa + off, l1 * k)

    us = (0.4, 0.52, 0.64, 0.75, 0.85)
    for i, u in enumerate(us):
        p = q.pt(u); qa = q.ang(u); l1 = L * 0.34 * (1 - 0.72 * (u - us[0]) / (1 - us[0]))
        for sg in (1, -1):
            branch(p, qa + sg * 58, l1, i < 3)
    e = q.pt(1)
    for off in (-30, 0, 30):
        seg(*e, q.ang(1) + off, L * 0.08)


def lf_bedstraw(a, x, y, ang, L, fill, d):
    """At plant scale: one narrow needle (the whorls are drawn by whorl())."""
    blade(a, x, y, ang, L, L * 0.1, fill, prof(0.45, "round", "point", bp=0.5, tp=0.9), veins=0, midw=0, lw=lwid(d) * 0.8, d=0, shade=0)


def lf_oxalis(a, x, y, ang, L, fill, d):
    """Three very narrow leaflets from the top of a thin stalk, each notched
    in two at the tip and folded along its midrib."""
    t = T(x, y, ang); top = t(L * 0.6)
    with a.on(STEM if d < 2 else a.layer):
        a.line(f"M{f(x)},{f(y)} Q{P(t(L * 0.3, L * 0.01))} {P(top)}", max(0.7, L * 0.016), 0.85)
    for off in (-58, 58, 0):
        l = L * 0.42; w = l * 0.14; tq = T(*top, ang + off)
        pf_ = prof(0.75, "taper", "round", bp=1.1, tp=2)
        up = [(l * i / 40, pf_(i / 40) * w / 2) for i in range(41)]
        nk = l * 0.07   # the notch at the tip
        up = [(px - (nk * (1 - abs(py) / (w / 2 + 1e-9) * 0) if i == 40 else 0), py) for i, (px, py) in enumerate(up)]
        ptsu = [tq(px, py) for px, py in up[:-1]] + [tq(l, w * 0.28), tq(l - nk, 0)]
        ptsd = [tq(l, -w * 0.28)] + [tq(px, -py) for px, py in up[:-1][::-1]]
        a.shape(path(ptsu + ptsd), fill, lwid(d) * 0.85)
        a.shape(path([tq(px, py) for px, py in up[:-1]] + [tq(l - nk, 0), tq(0, 0)]), "shade", 0, fa=0.16)   # folded: one half darker
        if d >= 1:
            a.line(opath([tq(l * u, 0) for u in (0.05, 0.5, 0.88)]), 0.4, 0.45)


LEAVES = {"foxglove": lf_foxglove, "salvia": lf_salvia, "common-evening-primrose": lf_primrose, "wallflower": lf_wallflower,
          "yellow-rattle": lf_rattle, "selfheal": lf_selfheal, "sweet-william": lf_sweetwilliam, "poppy": lf_poppy,
          "california-poppy": lf_calpoppy, "borage": lf_borage, "russian-comfrey": lf_comfrey, "lungwort": lf_lungwort,
          "native-cowslip": lf_cowslip, "geum": lf_geum, "viola": lf_viola, "aubrieta": lf_aubrieta, "linum": lf_linum,
          "marshmallow": lf_marshmallow, "perforate-st-john-s-wort": lf_sjw, "lady-s-bedstraw": lf_bedstraw,
          "rock-sea-lavender": lf_sealavender, "candy-cane-sorrel": lf_oxalis}


def leaf(a, kind, x, y, ang, L, fill=None, d=None):
    """The kind's own leaf on a whole-plant drawing, L long, on the leaf layer."""
    fill = fill or pal(kind, "leaf", "leaf")
    if d is None:
        d = 1 if L >= 13 else 0
    with a.on(LEAF):
        LEAVES[kind](a, x, y, ang, L, fill, d)


# ============================================================ close-up leaves
def cl_leaf(a, sp):
    """The close-up: the kind's own leaf, drawn large."""
    LEAVES[sp["who"]](a, BASE[0], BASE[1], ANG, sp.get("len", 92), sp["fill"], 2)
    return a


def cl_pair(a, sp):
    """A short piece of stem with a pair of leaves (sweet William: their bases
    joined round a swollen joint; St John's-wort: two thin raised lines down
    the stem; yellow-rattle)."""
    who = sp["who"]; fill = sp["fill"]
    q = Quad((50, 99), (51, 60), (49, 6))
    a.ribbon(q.p0, q.c, q.p1, sp.get("sw", 2.6), sp.get("sw", 2.6) * 0.8, sp.get("stemc", "leaf"), lw=0.9)
    if sp.get("lines"):
        for o in (-0.5, 0.5):
            a.line(opath([(x + o, y) for x, y in [q.pt(u) for u in (0.05, 0.3, 0.55, 0.8)]]), 0.4, 0.5)
    for u, L, spread in sp["nodes"]:
        x, y = q.pt(u)
        if sp.get("joint"):
            a.oval(x, y, 2.4, 1.7, 0, sp.get("stemc", "leaf"), 0.8)
        for sg in (1, -1):
            LEAVES[who](a, x + sg * 0.6, y, -90 + sg * spread, L * (1 if sg > 0 else 0.92), fill, 2)
    e = q.pt(1)
    for sg in (1, -1):
        LEAVES[who](a, e[0], e[1], -90 + sg * 20, sp.get("tip", 10), fill, 1)
    return a


def cl_sprig(a, sp):
    """A thin stem with its small leaves set singly: scarlet flax."""
    who = sp["who"]; fill = sp["fill"]
    q = Quad((44, 99), (50, 56), (60, 4))
    a.ribbon(q.p0, q.c, q.p1, 1.8, 1.1, sp.get("stemc", fill), lw=0.8)
    n = sp.get("n", 9)
    for i in range(n):
        u = 0.08 + 0.86 * i / (n - 1); x, y = q.pt(u); sg = 1 if i % 2 else -1
        LEAVES[who](a, x, y, q.ang(u) + sg * 36, sp.get("L", 30) * (1 - 0.3 * u), fill, 2)
    return a


def cl_whorls(a, sp):
    """Lady's bedstraw: rings of 8 to 12 needle-like leaves round a thin
    four-angled stem, evenly spaced, the edges rolled under, each with a
    tiny sharp point."""
    fill = sp["fill"]
    a.ribbon((49, 99), (50, 55), (51, 4), 1.6, 1.1, "leaf", lw=0.7)
    a.line("M49.6,96 L50.4,52 L51.3,6", 0.35, 0.45)   # one of the four angles
    for y, s in ((84, 1.0), (56, 0.88), (30, 0.74)):
        M = tilt(y, 0.4); n = 10
        for k in sorted(range(n), key=lambda k: math.sin(k * 2 * math.pi / n + 0.3)):
            ang = k * 360 / n + 17; L = 23 * s * (0.9 + 0.1 * math.cos(k * 1.7))
            t = T(50.4, y, ang)
            top = [(L * i / 30, prof(0.4, "round", "point", bp=0.5, tp=0.8)(i / 30) * 1.4 * s) for i in range(31)]
            pts = [M(t(*p)) for p in top] + [M(t(L + 1.2, 0))] + [M(t(px, -py)) for px, py in top[::-1]]
            a.shape(path(pts), fill, 0.7)
            # the edges rolled under: a darker band along each side, and the line where it turns
            a.shape(path([M(t(*p)) for p in top] + [M(t(px, py * 0.35)) for px, py in top[::-1]]), "shade", 0, fa=0.22)
            a.line(opath([M(t(L * u, 1.4 * s * 0.4)) for u in (0.12, 0.5, 0.86)]), 0.45, 0.75)
    for y in (70, 43):   # small side shoots in the joints
        for sg in (1, -1):
            e = (50 + sg * 6, y - 5)
            a.line(f"M50.4,{y + 1} Q{f(50 + sg * 3)},{f(y - 1)} {P(e)}", 0.6, 0.8)
            for k in range(5):
                a.line(f"M{P(e)} L{P(T(*e, -90 + sg * 20 + (k - 2) * 34)(3.4))}", 0.7, 0.9, fill)
    a.oval(51, 8, 1.6, 1.3, 0, "leaf", 0.6)
    return a


LEAF_DRAW = {"flowers_leaf": cl_leaf, "flowers_pair": cl_pair, "flowers_sprig": cl_sprig, "flowers_whorls": cl_whorls}

LEAFX = {k: dict(kind="flowers_leaf", who=k) for k in LEAVES}
LEAFX.update({
    "sweet-william": dict(kind="flowers_pair", who="sweet-william", joint=True, nodes=[(0.42, 46, 50)], tip=20, stemc="leaf"),
    "perforate-st-john-s-wort": dict(kind="flowers_pair", who="perforate-st-john-s-wort", lines=True, sw=2.0,
                                     nodes=[(0.18, 30, 62), (0.62, 26, 56)], tip=12, stemc="leaf"),
    "linum": dict(kind="flowers_sprig", who="linum", n=9, L=30, stemc="leaf"),
    "lady-s-bedstraw": dict(kind="flowers_whorls"),
})


# ============================================================ flower parts
def petal(a, x, y, ang, L, W, fill, pf, M=None, notch=0.0, pinked=0, lw=0.8, shade=0.08, lines=1, n=40, end=0.97, wav=0.0, la=0.85):
    """One petal from x,y along ang, L long and W wide. notch: a shallow notch
    in the outer end (evening primrose, marshmallow), as a share of L.
    pinked: that many small teeth across the outer end (sweet William).
    wav: a soft wave in the edge. lines: faint lines from the base (0, 1 or 3).
    M squashes the petal for a flower seen at a slant (see tilt)."""
    t = T(x, y, ang); mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    us = [end * i / n for i in range(n + 1)]
    wv = lambda u: 1 + wav * math.sin(u * 19)
    top = [(L * u, pf(u) * W / 2 * wv(u)) for u in us]
    bot = [(L * u, -pf(u) * W / 2 * wv(u + 0.4)) for u in us]
    tipw = top[-1][1]
    tip = []
    if pinked:
        for k in range(1, 2 * pinked):
            v = 1 - 2 * k / (2 * pinked)
            tip.append((L * (end + (0.05 if k % 2 else -0.02)), tipw * v))
    elif notch:
        tip = [(L * end + L * 0.02, tipw * 0.5), (L * (end - notch), 0), (L * end + L * 0.02, -tipw * 0.5)]
    elif end < 1:
        tip = [(L * (end + (1 - end) * 0.6), tipw * 0.5), (L, 0), (L * (end + (1 - end) * 0.6), -tipw * 0.5)]
    pts = top + tip + bot[::-1]
    a.shape(path([mp(p) for p in pts]), fill, lw, la)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((L * end, 0)), mp((0, 0))]), "shade", 0, fa=shade)
    if lines:
        for o in ([0] if lines == 1 else [-0.45, 0, 0.45]):
            q = [mp((L * u, o * pf(u) * W / 2 * 0.8)) for u in (0.1, 0.4, 0.7)]
            a.line(f"M{P(q[0])} Q{P(q[1])} {P(q[2])}", 0.45, 0.28)
    return mp


def sepal(a, x, y, ang, L, W, fill="leaf", M=None, lw=0.7, hairs=0):
    """A narrow pointed sepal or bract."""
    mp = petal(a, x, y, ang, L, W, fill, prof(0.3, "round", "point", bp=0.6, tp=1.1), M=M, lw=lw, shade=0.06, lines=0, end=1.0)
    for k in range(hairs):
        u = 0.2 + 0.6 * k / max(1, hairs - 1); sg = 1 if k % 2 else -1
        p = mp((L * u, sg * W * 0.3)); e = mp((L * u + 1.0, sg * W * 0.3 + sg * 1.6))
        a.line(f"M{P(p)} L{P(e)}", 0.35, 0.6)


def ring(a, n, R, W, fill, pf, cx=CX, cy=CY, k=0.86, start=-90, **kw):
    """n petals round a centre, the ones at the back drawn first."""
    M = tilt(cy, k)
    for i in sorted(range(n), key=lambda i: math.sin(math.radians(start + 360 * i / n))):
        ang = start + 360 * i / n
        petal(a, cx, cy, ang, R, W, fill, pf, M=M, shade=0.06 + (0.05 if math.sin(math.radians(ang)) > 0.3 else 0), **kw)
    return M


def burst(a, cx, cy, n, r0, r1, anth="sun", M=None, lw=0.4, ar=0.7, seed=0):
    """Many long stamens spraying out from the middle, each with an anther."""
    for k in range(n):
        ang = k * GOLD * 57.3 + seed; rr = r1 * (0.6 + 0.4 * ((k * 0.618) % 1))
        p0 = T(cx, cy, ang)(r0); p1 = T(cx, cy, ang)(rr)
        if M:
            p0, p1 = M(p0), M(p1)
        a.line(f"M{P(p0)} L{P(p1)}", lw, 0.6)
        a.oval(p1[0], p1[1], ar, ar * 0.75, ang, anth, 0.35)


def stem_q(a, p0, c, p1, w0=2.6, w1=1.6, fill="leaf", lw=0.9):
    return a.ribbon(p0, c, p1, w0, w1, fill, lw=lw)


def hairs_along(a, q, u0, u1, n, L=1.6, ang=60):
    """Stiff hairs standing out from a stalk."""
    for k in range(n):
        u = u0 + (u1 - u0) * k / max(1, n - 1); p = q.pt(u); sg = 1 if k % 2 else -1
        a.line(f"M{P(p)} L{P(T(*p, q.ang(u) + sg * ang)(L))}", 0.4, 0.55)


ROUND = prof(0.55, "wedge", "round", bp=0.9, tp=2.0)     # a broad petal narrowing to its base
FAN = prof(0.75, "wedge", "round", bp=0.8, tp=1.6)       # widest near the outer end
WIDE = prof(0.6, "wedge", "blunt", bp=0.7, tp=2.6)       # broad, the end cut almost straight across


# ---- foxglove
def glove(a, x, y, ang, L, W, fc, inside="pink", spot="dark", face=1.0, lw=0.85):
    """One foxglove bell from x,y (where it hangs from) along ang. The tube
    widens to a slanting mouth with a short upper lip and a longer lower lip
    that juts out; inside, on the floor of the tube and the lower lip, dark
    spots each ringed with white. face: how much of the mouth is seen."""
    t = T(x, y, ang)
    hw = lambda u: W / 2 * (0.32 + 0.68 * u ** 0.9)
    us = [i / 24 for i in range(25)]
    up = [t(L * u, -hw(u)) for u in us]                      # the upper side of the tube
    lo = [t(L * u, hw(u) * (1 + 0.08 * math.sin(math.pi * u))) for u in us]
    lip = [t(L + L * 0.16 * math.sin(math.pi * v) ** 0.8 + L * 0.06 * v, hw(1) * (1 - 1.1 * v) + W * 0.1) for v in [i / 10 for i in range(11)]]
    a.shape(path(up + [t(L * 1.03, -hw(1) * 1.05)] + lip[::-1][:1] + lo[::-1]), fc, lw)
    a.shape(path(up + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    for o in (0.35, -0.3):   # faint lines down the tube
        a.line(opath([t(L * u, hw(u) * o) for u in (0.15, 0.5, 0.85)]), 0.4, 0.3)
    # the open mouth, seen at a slant: paler inside
    mc = t(L * 1.0, W * 0.02); mr = (L * 0.1 * face + 1.2, hw(1) * 0.95)
    a.polar(mc[0], mc[1], lambda h: 1, mr[0], mr[1], ang, inside, 0.6, shade=False)
    a.shape(path([T(*mc, ang)(mr[0] * math.cos(h), mr[1] * math.sin(h)) for h in [-math.pi / 2 + math.pi * i / 16 for i in range(17)]][::-1] + [mc]), "shade", 0, fa=0.18)
    # the lower lip jutting out, pale inside, with the spots
    # the lower lip: a broad rounded lobe jutting well out beyond the mouth, its
    # pale upper face spotted dark, each spot ringed with white
    lobe = [t(L * 0.96 + L * 0.3 * math.sin(math.pi * v / 2) ** 0.8, hw(1) * (1.1 - 1.0 * v) + W * 0.05 * math.sin(math.pi * v))
            for v in [i / 14 for i in range(15)]]
    back = [t(L * 0.98 + L * 0.24 * math.sin(math.pi * v / 2) ** 0.9, hw(1) * (0.95 - 0.95 * v) - W * 0.02) for v in [i / 14 for i in range(15)]]
    a.shape(path([t(L * 0.92, hw(1) * 1.12)] + lobe + back[::-1]), fc, lw * 0.85)
    face_ = [t(L * 1.0 + L * 0.22 * math.sin(math.pi * v / 2) ** 0.8, hw(1) * (0.92 - 0.8 * v)) for v in [i / 12 for i in range(13)]]
    a.shape(path(back[1:-1] + face_[::-1][1:-1]), inside, 0)
    if spot:
        for u, o, r in ((1.0, 0.55, 1.0), (1.06, 0.3, 0.95), (1.12, 0.62, 0.8), (1.14, 0.18, 0.8), (0.99, 0.18, 0.8), (1.2, 0.42, 0.7)):
            p = t(L * u, hw(1) * o)
            a.dot(p[0], p[1], r * 1.6 * W / 16, "white"); a.dot(p[0], p[1], r * 0.95 * W / 16, spot)
    # five small pointed green sepals at the top
    for off in (-40, 0, 40):
        sepal(a, x, y, ang + 180 + off, W * 0.42, W * 0.16, "leaf", lw=0.6)


def fl_foxglove(a, sp):
    """A piece of the spike: open bells hanging all to one side, the lowest
    biggest, tight green buds at the top."""
    fc = sp["fc"]; cen = sp.get("cen", "dark")
    q = Quad((30, 99), (24, 50), (36, 4))
    stem_q(a, q.p0, q.c, q.p1, 3.0, 1.6)
    hairs_along(a, q, 0.05, 0.95, 26, 1.2, 70)
    for u, s in ((0.95, 0.42), (0.88, 0.5), (0.8, 0.62)):   # the buds: green, then flushed
        x, y = q.pt(u); e = (x + 4 * s, y + 1.5)
        a.line(f"M{f(x)},{f(y)} Q{f(x + 2)},{f(y - 1)} {P(e)}", 0.8, 0.85)
        petal(a, e[0], e[1], 60, 10 * s + 3, 6 * s + 1, fc if u < 0.85 else "unripe", prof(0.6, "round", "round"), lw=0.7, lines=0)
        sepal(a, e[0], e[1], 60, 6 * s, 2.4 * s, lw=0.55)
    for u, s, ang in ((0.78, 0.58, 48), (0.6, 0.74, 52), (0.4, 0.88, 56)):
        x, y = q.pt(u); e = (x + 5 * s, y - 1)
        a.line(f"M{f(x)},{f(y)} Q{f(x + 3 * s)},{f(y - 3)} {P(e)}", 1.0, 0.85)
        sepal(a, x + 0.8, y + 1, 95, 6 * s, 2.0 * s, lw=0.55)   # the bract under each bell
        glove(a, e[0], e[1] + 0.5, ang, 34 * s, 19 * s, fc, "pink", cen, face=1.0)
    return a


# ---- salvia
def lip2(a, x, y, ang, s, fc, calc="plum", hood=1.0, lip=1.0, lw=0.6, spot=None):
    """A small two-lipped flower from the side, its tube along ang (pointing
    out to one side): a calyx, the tube, a curved hood above and a broad
    three-lobed lower lip below."""
    t = T(x, y, ang); up = -1 if math.cos(math.radians(ang)) >= 0 else 1
    petal(a, x, y, ang, 6.5 * s, 3.6 * s, calc, prof(0.6, "round", "point"), lw=lw, lines=0, end=1.0)   # the calyx
    a.ribbon(t(3 * s), t(6 * s, up * 0.3 * s), t(9 * s, up * 0.8 * s), 1.8 * s, 2.4 * s, fc, lw=lw)
    e = t(8.6 * s, up * 0.6 * s)
    # the hood: a curved, narrow upper lip arching up and over
    hq = Quad(e, T(*e, ang + up * 30)(6 * s * hood), T(*e, ang + up * 8)(11 * s * hood))
    a.ribbon(hq.p0, hq.c, hq.p1, 2.8 * s, 1.0 * s, fc, lw=lw, round_tip=True)
    # the lower lip: three lobes, spreading down and out
    lb = T(*e, ang - up * 44)
    c = lb(4.5 * s * lip)
    a.polar(c[0], c[1], lambda h: 1 + 0.18 * math.cos(3 * h), 3.6 * s * lip, 2.8 * s * lip, ang - up * 44, fc, lw)
    if spot:
        a.dot(c[0], c[1], 0.6 * s, spot)


def fl_salvia(a, sp):
    """One narrow upright spike: whorls of small violet hooded flowers
    stacked close together, each whorl over a pair of purple-tinted bracts,
    buds in purple calyces at the top."""
    fc = sp["fc"]; br = sp.get("br", "plum")
    q = Quad((50, 99), (51, 56), (49, 4))
    stem_q(a, q.p0, q.c, q.p1, 2.4, 1.2)
    for sg in (1, -1):   # a pair of leaves at the foot, stalkless
        lf_salvia(a, 50, 90, -90 + sg * 62, 26, "sage", 1)
    for j, y in enumerate((74, 64, 55, 47, 40, 33)):
        s = 1.25 - 0.06 * j; x = q.pt((99 - y) / 95)[0]
        for sd in (-1, 1):   # the bracts
            sepal(a, x, y + 1.5, 90 + sd * 70, 6 * s, 3.6 * s, br, lw=0.55)
        for sd in (-1, 1):
            lip2(a, x + sd * 1.2, y, -90 + sd * 62, s, fc, br)
            if j % 2 == 0:
                lip2(a, x + sd * 0.6, y - 1.5, -90 + sd * 30, s * 0.85, fc, br)
    for j, y in enumerate((27, 22, 17, 13, 9)):   # the buds
        x = q.pt((99 - y) / 95)[0]; s = 1 - j * 0.12
        for sd in (-1, 1):
            petal(a, x, y, -90 + sd * 34, 5 * s, 2.8 * s, br, prof(0.5, "round", "point"), lw=0.55, lines=0, end=1.0)
    return a


# ---- evening primrose
def fl_primrose(a, sp):
    """Four broad petals, each wider than long with a shallow notch, so the
    flower looks almost square; eight stamens and an X-shaped stigma; the
    sepals folded right back down the long slender tube."""
    fc = sp["fc"]; c = (42, 38); k = 0.9; R = 25
    q = Quad((78, 99), (76, 56), (74, 4))
    stem_q(a, q.p0, q.c, q.p1, 3.0, 1.8)
    hairs_along(a, q, 0.05, 0.9, 20, 1.3, 60)
    # a young pod pressed to the stem lower down, and a leaf
    lf_primrose(a, 76, 84, -150, 26, "leaf", 1)
    a.ribbon((77, 80), (79, 74), (79.5, 66), 2.8, 1.6, "unripe", lw=0.7, round_tip=True)
    # buds at the top: long, slender, pointed, the yellow just showing
    for x0, y0, ang, s in ((74, 14, -78, 1.0), (74, 18, -112, 0.8)):
        e = T(x0, y0, ang)(5 * s)
        a.ribbon((x0, y0), T(x0, y0, ang)(3), e, 2.4 * s, 3.0 * s, "unripe", lw=0.7)
        petal(a, e[0], e[1], ang, 12 * s, 5 * s, "leaf", prof(0.35, "round", "point", tp=1.2), lw=0.7, lines=0, end=1.0)
        a.line(opath([T(*e, ang)(u * 12 * s, 0.4) for u in (0.1, 0.5, 0.85)]), 0.9, 0.9, fc)
    # the long tube from the leaf joint to the flower
    j = q.pt(0.42)
    a.ribbon(j, (j[0] - 6, j[1] - 10), (c[0] + 3, c[1] + 10), 2.0, 2.8, "unripe", lw=0.7)
    for ang_ in (112, 64, 96, 80):   # the four long sepals folded right back, hanging down beside the tube
        sepal(a, c[0] + 2, c[1] + 6, ang_, 34, 3.4, "leaf", lw=0.65)
    M = tilt(c[1], k)
    for i, ang in enumerate((-135, -45, 135, 45)):
        petal(a, c[0], c[1], ang, R, R * 1.18, fc, WIDE, M=M, notch=0.07, lines=3, shade=0.05 + 0.04 * (ang > 0))
    burst(a, c[0], c[1], 8, 1.0, R * 0.38, "sun", M, lw=0.5, ar=1.1)
    for ang in (-45, 45, 135, 225):   # the stigma's four arms, in an X
        e = M(T(*c, ang)(R * 0.3)); a.line(f"M{P(c)} L{P(e)}", 1.6, 0.9, "line"); a.line(f"M{P(c)} L{P(e)}", 0.9, 1.0, "primrose")
    a.dot(c[0], c[1], 1.2, "primrose")
    return a


# ---- wallflower
def cross4(a, x, y, r, fc, M=None, start=-45, veins="rust", cen="pear", lw=0.7):
    """A flat four-petalled flower face on: four broad rounded petals in a
    cross, dark veins, a small greenish middle with the stamen tips."""
    M = M or tilt(y, 0.88)
    for i in sorted(range(4), key=lambda i: math.sin(math.radians(start + 90 * i))):
        ang = start + 90 * i
        mp = petal(a, x, y, ang, r, r * 0.98, fc, ROUND, M=M, lw=lw, lines=0, shade=0.05)
        if veins and r > 5:
            for o in (-0.25, 0, 0.25):
                a.line(opath([mp((r * u, o * r * u * 0.9)) for u in (0.3, 0.55, 0.85)]), 0.45, 0.7, veins)
    a.oval(x, y, r * 0.16, r * 0.14, 0, cen, 0.5)
    for k in range(4):
        e = M(T(x, y, start + 45 + 90 * k)(r * 0.12)); a.dot(e[0], e[1], max(0.35, r * 0.04), "sun")


def side4(a, x, y, ang, s, fc, calc="leaf"):
    """A four-petalled flower from the side: the sepals pressed into a tube,
    the petals spreading flat from its top."""
    t = T(x, y, ang)
    petal(a, x, y, ang, 8 * s, 3.4 * s, calc, prof(0.7, "round", "round"), lw=0.6, lines=0)
    e = t(7.6 * s)
    for off in (-74, 74, -40, 40):
        petal(a, e[0], e[1], ang + off, 8 * s, 6.5 * s, fc, ROUND, lw=0.6, lines=0, shade=0.05 + 0.05 * (off > 0))


def fl_wallflower(a, sp):
    """A dense cluster at the top of a stem: open four-petalled flowers facing
    up and out, buds above, the cluster lengthening downwards."""
    fc = sp["fc"]
    q = Quad((52, 99), (50, 70), (50, 30))
    stem_q(a, q.p0, q.c, q.p1, 3.0, 2.2)
    for u, sg in ((0.12, 1), (0.22, -1), (0.3, 1)):
        x, y = q.pt(u); lf_wallflower(a, x, y, -90 + sg * 48, 30, "deep", 1)
    for x, y, ang in ((50, 31, -90), (44, 40, -130), (57, 41, -50)):   # flower stalks
        a.line(f"M50,48 Q{f((50 + x) / 2)},{f(y + 4)} {f(x)},{f(y)}", 0.9, 0.85)
    for x, y, ang, s in ((42, 14, -100, 0.75), (55, 12, -76, 0.7), (49, 8, -90, 0.6), (36, 22, -130, 0.7), (63, 20, -52, 0.75)):
        a.line(f"M50,32 Q{f((50 + x) / 2)},{f((32 + y) / 2 + 3)} {f(x)},{f(y)}", 0.8, 0.85)
        petal(a, x, y, ang, 8 * s, 3.8 * s, "leaf", prof(0.6, "round", "round"), lw=0.6, lines=0)
        petal(a, *T(x, y, ang)(5 * s), ang, 5 * s, 3.4 * s, fc, prof(0.4, "round", "round"), lw=0.55, lines=0)
    a.line("M50,54 Q44,56 40,55", 0.9, 0.85)   # the lowest flowers, on short stalks: the spike lengthens downwards
    side4(a, 40, 55, -152, 1.25, fc)
    a.line("M50,58 Q56,60 61,59", 0.9, 0.85)
    side4(a, 61, 59, -28, 1.2, fc)
    for x, y, r, st in ((33, 36, 15, -40), (66, 37, 15, -50), (50, 28, 14, -45)):
        cross4(a, x, y, r, fc, tilt(y, 0.82), st)
    return a


# ---- yellow-rattle
def rattle_flower(a, x, y, ang, s, fc, calc="pale", tooth="plum"):
    """Yellow-rattle from the side: a big flat inflated calyx, almost round,
    with a yellow tube poking out of it, ending in a hood (with two tiny
    violet teeth at its tip) over a small lower lip."""
    t = T(x, y, ang); up = -1 if math.cos(math.radians(ang)) >= 0 else 1
    c = t(7 * s)
    a.polar(c[0], c[1], lambda h: 1 - 0.1 * math.exp(-((abs(h) - math.pi) / 0.4) ** 2) - 0.12 * math.exp(-(h / 0.35) ** 2), 7.5 * s, 6.8 * s, ang, calc, 0.7)
    for o in (-0.5, 0, 0.5):   # its net of veins
        a.line(opath([T(*c, ang)(7 * s * v, 6 * s * o * math.sin(math.pi * (v + 1) / 2)) for v in (-0.8, -0.3, 0.2, 0.7)]), 0.4, 0.4)
    tq = Quad(t(10 * s, up * 0.5 * s), t(16 * s, up * 2.8 * s), t(20 * s, up * 5 * s))
    a.ribbon(tq.p0, tq.c, tq.p1, 4.4 * s, 5.6 * s, fc, lw=0.7)
    h = tq.p1
    hq = Quad(h, T(*h, ang + up * 40)(4 * s), T(*h, ang + up * 5)(7.5 * s))
    a.ribbon(hq.p0, hq.c, hq.p1, 5.6 * s, 2.6 * s, fc, lw=0.7, round_tip=True)   # the hood, flattened side to side
    for k in (-0.5, 0.5):
        p = T(*hq.p1, ang + up * 5)(0.6 * s, k * 1.4 * s); a.dot(p[0], p[1], 0.6 * s, tooth)
    petal(a, *tq.pt(0.9), ang - up * 38, 5 * s, 3.8 * s, fc, prof(0.5, "round", "round"), lw=0.6, lines=0)   # the lower lip


def toothed_bract(a, x, y, ang, L, fill, lw=0.7):
    """A triangular bract with long sharp teeth."""
    blade(a, x, y, ang, L, L * 0.6, fill, prof(0.18, "round", "point", bp=0.35, tp=1.1), teeth=5, td=L * 0.12, tk="saw",
          veins=0, midw=0.4, lw=lw, d=1)


def fl_rattle(a, sp):
    """The top of a stem: a dense leafy spike, the flowers in pairs, one in
    the joint of each of a pair of opposite toothed bracts, the lower pairs
    open, buds in their calyces above."""
    fc = sp["fc"]; tooth = sp.get("cen", "plum")
    q = Quad((50, 99), (50, 56), (50, 4))
    stem_q(a, q.p0, q.c, q.p1, 2.4, 1.4)
    for k in range(9):   # the black streaks on the stem
        p = q.pt(0.06 + k * 0.1); a.line(f"M{P(p)} l0.3,2", 0.7, 0.9, "dark")
    for sg in (1, -1):
        lf_rattle(a, *q.pt(0.05), -90 + sg * 70, 24, "deep", 1)
    for u, s_, open_ in ((0.2, 0.86, True), (0.42, 0.8, True), (0.62, 0.62, False), (0.78, 0.5, False), (0.9, 0.4, False)):
        x, y = q.pt(u)
        for sg in (1, -1):
            if open_:
                rattle_flower(a, x + sg * 1, y - 1, -90 + sg * 70, s_, fc, "unripe", tooth)
            else:
                a.polar(*T(x, y, -90 + sg * 52)(4.4 * s_ + 1), lambda h: 1, 4.4 * s_ + 1, 3.8 * s_ + 0.8, -90 + sg * 52, "unripe", 0.6)
                a.line(f"M{P(T(x, y, -90 + sg * 52)(2))} L{P(T(x, y, -90 + sg * 52)(8 * s_ + 1.6))}", 0.4, 0.4)
        for sg in (1, -1):
            toothed_bract(a, x, y + 1, -90 + sg * 86, 15 * s_, "deep")
    e = q.pt(1)
    for sg in (1, -1):
        toothed_bract(a, e[0], e[1], -90 + sg * 30, 6, "deep", 0.6)
    return a


# ---- selfheal
def fl_selfheal(a, sp):
    """A dense, squarish, oblong head: tiers of broad, rounded, pointed,
    purple-edged bracts, a ring of hooded blue-violet flowers sticking out
    sideways near the top, and a pair of stalkless leaves right under it."""
    fc = sp["fc"]; br = sp.get("cen", "plum")
    a.ribbon((50, 99), (49, 80), (50, 66), 2.8, 2.4, "leaf", lw=0.9)
    for sg in (1, -1):   # the pair of stalkless leaves under the head
        blade(a, 50, 70, -90 + sg * 76, 26, 12, "leaf", prof(0.4, "round", "blunt", bp=0.6, tp=2.2), veins=3, pucker=True, d=2, lw=0.9)
    x0, x1, yb, yt = 37, 63, 68, 24
    a.shape(path([(x0, yb), (x0 + 1, yt + 4), (50, yt), (x1 - 1, yt + 4), (x1, yb), (50, yb + 3)]), br, 0.9)
    rows = 6
    for r in range(rows):   # bracts and calyces in tiers, bottom to top
        y = yb - 2 - r * (yb - yt - 4) / rows
        for j in range(4):
            x = x0 + 3 + j * (x1 - x0 - 6) / 3 + (2.6 if r % 2 else -0.6)
            petal(a, x, y + 2, -90, 9, 9, "sage", prof(0.4, "round", "point", bp=0.5, tp=0.9), lw=0.6, lines=0, shade=0.05)
            a.line(opath([T(x, y + 2, -90)(9 * u, 4.0 * prof(0.4, "round", "point", bp=0.5, tp=0.9)(u)) for u in (0.3, 0.55, 0.8, 0.98)]), 1.5, 0.9, br)
            a.line(opath([T(x, y + 2, -90)(9 * u, -4.0 * prof(0.4, "round", "point", bp=0.5, tp=0.9)(u)) for u in (0.3, 0.55, 0.8, 0.98)]), 1.5, 0.9, br)
            for h in (-2, 0, 2):   # hairs
                a.line(f"M{f(x + h)},{f(y - 3)} l{f(h * 0.3)},-1.4", 0.35, 0.5)
            if r >= 1:
                petal(a, x - 1, y - 4, -100, 4.6, 3.0, br, prof(0.5, "round", "point"), lw=0.5, lines=0)   # a calyx
    for sd in (-1, 1):   # the open flowers, sticking out sideways
        for yy, s in ((44, 1.05), (36, 0.95)):
            lip2(a, 50 + sd * 9, yy, -90 + sd * 78, s * 1.3, fc, br, hood=1.1, lip=1.2)
    lip2(a, 52, 33, -70, 1.1, fc, br, hood=1.1, lip=1.1)
    return a


# ---- sweet William
def pink5(a, x, y, r, fc, eye="beet", edge="white", start=-90, M=None, lw=0.45):
    """One small sweet William flower face on: five broad petals with pinked
    (toothed) outer edges, a darker ring round the eye and a pale rim."""
    M = M or tilt(y, 0.9)
    for i in sorted(range(5), key=lambda i: math.sin(math.radians(start + 72 * i))):
        ang = start + 72 * i
        petal(a, x, y, ang, r, r * 1.05, fc, FAN, M=M, pinked=4 if r > 4 else 3, lw=lw, lines=0, shade=0.04)
        if edge and r > 3.5:
            a.line(opath([M(T(x, y, ang)(r * 0.93, r * 0.45 * v)) for v in (-0.9, -0.3, 0.3, 0.9)]), 0.6, 0.8, edge)
    a.oval(x, y, r * 0.42, r * 0.38 * 0.9, 0, eye, 0.4)
    a.oval(x, y, r * 0.18, r * 0.16, 0, fc if eye != fc else "white", 0.3)
    for k in (-1, 1):   # two curled white styles
        a.line(f"M{f(x)},{f(y)} q{f(k * r * 0.2)},{f(-r * 0.3)} {f(k * r * 0.1)},{f(-r * 0.45)}", 0.5, 0.9, "white")


def fl_sweetwilliam(a, sp):
    """A dense flat-topped head of many small flowers, seen from a little
    above, with green thread-like bracts poking out between them."""
    fc = sp["fc"]; eye = sp.get("cen", "beet")
    a.ribbon((50, 99), (50, 80), (50, 62), 3.0, 2.6, "leaf", lw=0.9)
    a.oval(50, 82, 2.6, 1.8, 0, "leaf", 0.8)
    for sg in (1, -1):
        lf_sweetwilliam(a, 50 + sg * 0.6, 82, -90 + sg * 70, 26, "deep", 1)
    c = (50, 42); Rx, Ry = 36, 17
    for k in range(9):   # the short stalks up from the stem
        e = (c[0] + Rx * 0.7 * math.cos(k * 0.7), c[1] + Ry * 0.4 * math.sin(k * 0.7))
        a.line(f"M50,62 Q{f((50 + e[0]) / 2)},{f(57)} {P(e)}", 0.6, 0.7)
    spots = [(c[0], c[1])] + [(c[0] + Rx * 0.5 * math.cos(math.radians(g)), c[1] + Ry * 0.5 * math.sin(math.radians(g))) for g in range(15, 375, 60)]
    spots += [(c[0] + Rx * 0.92 * math.cos(math.radians(g)), c[1] + Ry * 0.92 * math.sin(math.radians(g))) for g in range(0, 360, 36)]
    for x, y in sorted(spots, key=lambda p: p[1]):
        for kk in range(2):   # the bracts' long thread-like points
            e = T(x, y, -40 + kk * 80 + x * 2)(8.5)
            a.line(f"M{f(x)},{f(y + 1)} L{P(e)}", 0.9, 0.85, "line"); a.line(f"M{f(x)},{f(y + 1)} L{P(e)}", 0.45, 1.0, "leaf")
        pink5(a, x, y, 9.0 - 1.6 * abs(y - c[1]) / Ry, fc, eye, None, start=-90 + x * 5, M=tilt(y, 0.74))
    return a


# ---- field poppy
def fl_poppy(a, sp):
    """A bowl of four broad crumpled scarlet petals seen from a little above:
    two smaller inner ones at the back, two big outer ones in front, a black
    blotch at the foot of each; in the middle the green seed box with its
    dark rayed lid, ringed by a mass of dark stamens. Beside it, a hairy bud
    hanging down."""
    fc = sp["fc"]; blot = sp.get("blotch", "dark"); c = (48, 44)
    q = Quad((52, 99), (52, 76), (c[0] + 1, c[1] + 14))
    stem_q(a, q.p0, q.c, q.p1, 2.4, 2.0)
    hairs_along(a, q, 0.05, 0.9, 16, 1.8, 70)
    bq = Quad((56, 96), (82, 80), (80, 66))     # the bud's stalk, bent over at the top
    a.line(f"M{P(bq.p0)} Q{P(bq.c)} {P(bq.p1)} Q79,60 76,64", 1.4, 0.85)
    hairs_along(a, bq, 0.1, 0.95, 10, 1.6, 70)
    a.polar(75, 70, lambda h: 1, 4.6, 6.4, -12, "leaf", 0.8)   # the bud, hanging, in its two hairy sepals
    a.line("M73.6,64.5 Q75,70 74.8,76", 0.5, 0.5)
    for k in range(10):
        p = T(75, 70, k * 36)(5.2); a.line(f"M{P(p)} L{P(T(75, 70, k * 36)(6.8))}", 0.4, 0.55)
    M = tilt(c[1], 0.7)
    wrin = lambda mp, L, W: [a.line(opath([mp((L * u, o * W * 0.4 * math.sin(math.pi * u) + 0.6 * math.sin(u * 14))) for u in (0.2, 0.45, 0.7, 0.9)]), 0.45, 0.3) for o in (-0.6, 0, 0.6)]
    for ang, L, W in ((-140, 30, 36), (-40, 30, 36)):     # inner petals, behind
        mp = petal(a, c[0], c[1], ang, L, W, fc, ROUND, M=M, lw=0.9, lines=0, wav=0.03, shade=0.14)
        wrin(mp, L, W)
        b = mp((L * 0.3, 0)); a.oval(b[0], b[1], 4.2, 3.0, ang, blot, 0)
    # the stamens and seed box
    for k in range(40):
        ang = k * 9 + 4; rr = 8 + 3 * (k % 3) / 2
        e = M(T(*c, ang)(rr)); s0 = M(T(*c, ang)(3))
        a.line(f"M{P(s0)} L{P(e)}", 0.45, 0.65); a.dot(e[0], e[1], 0.85, "dark")
    a.oval(c[0], c[1] - 2, 5, 5.4, 0, "unripe", 0.9)   # the seed box
    a.oval(c[0], c[1] - 6.6, 5.4, 2.0, 0, "pale", 0.7)   # its flat lid
    for j in range(10):
        e = T(c[0], c[1] - 6.6, j * 36)(5.0); a.line(f"M{f(c[0])},{f(c[1] - 6.6)} L{f(e[0])},{f(c[1] - 6.6 + (e[1] - c[1] + 6.6) * 0.36)}", 0.6, 0.9, "dark")
    for ang, L, W in ((150, 34, 44), (30, 34, 44)):      # outer petals, in front
        mp = petal(a, c[0], c[1] + 6, ang + 0, L, W, fc, ROUND, M=tilt(c[1] + 6, 0.62), lw=0.9, lines=0, wav=0.03, shade=0.06)
        wrin(mp, L, W)
        b = mp((L * 0.3, -W * 0.08)); a.oval(b[0], b[1], 4.6, 2.6, ang * 0.3, blot, 0)   # the black blotch at its base
    return a


# ---- Californian poppy
def fl_calpoppy(a, sp):
    """A silky cup of four broad fan-shaped petals, deeper orange at the
    base, full of orange-yellow stamens, sitting on a flat pinkish rim at
    the top of a bare stalk. Beside it, a bud in its pointed cap."""
    fc = sp["fc"]; base = (48, 66)
    a.ribbon((50, 99), (50, 84), (base[0], base[1] + 4), 2.2, 2.0, "sage", lw=0.85)
    a.ribbon((54, 99), (72, 78), (74, 52), 1.8, 1.6, "sage", lw=0.85)
    a.ribbon((74, 54), (74, 50), (74, 47), 3.0, 3.6, "sage", lw=0.7)
    petal(a, 74, 47, -90, 18, 7, "pale", prof(0.3, "round", "point", tp=0.8), lw=0.8, lines=1, end=1.0)   # the cap over the bud
    a.oval(base[0], base[1] + 3, 7.5, 2.4, 0, "pink", 0.8)    # the flat rim
    for ang, L, W, sh in ((-118, 34, 36, 0.14), (-62, 34, 36, 0.14)):
        mp = petal(a, base[0], base[1], ang, L, W, fc, FAN, lw=0.9, lines=3, shade=sh)
        a.shape(path([mp((L * u, W * 0.3 * v)) for u, v in ((0.0, 0), (0.38, 0.9), (0.42, 0), (0.38, -0.9))]), "amber", 0, fa=0.8)
    for k in range(26):   # the stamens
        ang = -160 + 140 * k / 25; e = T(base[0], base[1] - 4, ang)(9 + 2 * (k % 3))
        a.line(f"M{f(base[0])},{f(base[1] - 3)} L{P(e)}", 0.45, 0.6); a.oval(e[0], e[1], 0.6, 1.4, ang + 90, "amber", 0.3)
    a.line(f"M{f(base[0])},{f(base[1] - 2)} L{f(base[0] + 1)},{f(base[1] - 18)}", 1.0, 0.85)
    for ang, L, W in ((-158, 30, 32), (-22, 30, 32)):
        mp = petal(a, base[0], base[1], ang, L, W, fc, FAN, lw=0.9, lines=3, shade=0.06)
        a.shape(path([mp((L * u, W * 0.3 * v)) for u, v in ((0.0, 0), (0.36, 0.9), (0.4, 0), (0.36, -0.9))]), "amber", 0, fa=0.8)
    return a


# ---- borage
def star5(a, x, y, r, fc, cen="dark", M=None, start=-90, sep=True, lw=0.6):
    """A borage flower face on: five pointed triangular petals spread flat,
    bristly green sepals between them, a cone of near-black anthers with a
    ring of white scales at its foot."""
    M = M or tilt(y, 0.92)
    if sep:
        for i in range(5):
            sepal(a, x, y, start + 36 + 72 * i, r * 0.72, r * 0.2, "leaf", M=M, lw=lw * 0.8, hairs=4 if r > 8 else 0)
    tri = prof(0.42, "wedge", "point", bp=0.7, tp=0.9)
    for i in sorted(range(5), key=lambda i: math.sin(math.radians(start + 72 * i))):
        ang = start + 72 * i
        petal(a, x, y, ang, r, r * 0.72, fc, tri, M=M, lw=lw, lines=1, end=1.0)
    for i in range(5):
        e = M(T(x, y, start + 36 + 72 * i)(r * 0.17)); a.oval(e[0], e[1], r * 0.09 + 0.3, r * 0.07 + 0.25, 0, "white", 0.4)
    for i in range(5):   # the cone of anthers, standing out towards you
        petal(a, x, y, start + 72 * i + 10, r * 0.32, r * 0.14, cen, prof(0.4, "round", "point"), M=M, lw=0.4, lines=0, end=1.0, shade=0)
    a.dot(x, y, max(0.4, r * 0.05), "pale")


def fl_borage(a, sp):
    """A drooping cluster at the top of a bristly stem: one flower facing you,
    one hanging face down seen from the side, and pink buds."""
    fc = sp["fc"]; cen = sp.get("cen", "dark")
    q = Quad((30, 99), (28, 40), (54, 16))
    stem_q(a, q.p0, q.c, q.p1, 3.0, 1.6)
    hairs_along(a, q, 0.05, 0.98, 30, 1.6, 65)
    for (x, y), c in (((52, 24), "pink"), ((60, 18), "pink"), ((57, 26), "mauve")):   # buds
        a.line(f"M{P(q.p1)} L{f(x)},{f(y)}", 0.8, 0.85)
        a.polar(x, y + 2, lambda h: 1, 2.4, 3.0, 0, c, 0.6)
        for off in (-30, 30):
            sepal(a, x, y, 90 + off, 5, 1.8, "leaf", lw=0.5, hairs=2)
    s0 = q.pt(0.82)
    a.line(f"M{P(s0)} Q{f(s0[0] + 2)},{f(s0[1] + 14)} 44,58", 1.0, 0.85)   # the stalk of the front flower, nodding
    star5(a, 44, 66, 22, fc, cen, tilt(66, 0.9), start=-80)
    s1 = q.pt(0.95)
    a.line(f"M{P(s1)} Q76,16 78,34", 0.9, 0.85)                          # a flower hanging face down
    t = T(78, 34, 90)
    for off in (-34, 34, -14, 14):
        petal(a, *t(4), 90 + off * 2.4, 14, 9, fc, prof(0.42, "wedge", "point", bp=0.7, tp=0.9), lw=0.6, lines=1, end=1.0)
    for off in (-24, 24):
        sepal(a, 78, 34, 90 + off, 8, 2.4, "leaf", lw=0.55, hairs=3)
    a.shape(path([t(4, -2.4), t(15, -0.4), t(15, 0.4), t(4, 2.4)]), cen, 0.6)
    return a


# ---- Russian comfrey
def comfrey_bell(a, x, y, ang, L, W, fc, lw=0.7):
    """A hanging tubular bell with five short teeth turned back at its mouth."""
    t = T(x, y, ang)
    hw = lambda u: W / 2 * (0.55 + 0.45 * u ** 1.2)
    up = [t(L * u, hw(u)) for u in [i / 16 for i in range(17)]]
    dn = [t(L * u, -hw(u)) for u in [i / 16 for i in range(17)]]
    rim = [t(L + 1.6 * abs(math.sin(math.pi * v * 2.5)) ** 0.8, hw(1) * (1 - 2 * v) * 1.12) for v in [i / 20 for i in range(21)]]
    a.shape(path(up + rim + dn[::-1]), fc, lw)
    a.shape(path(up + [t(L * u / 16, 0) for u in range(16, -1, -1)]), "shade", 0, fa=0.12)
    a.line(opath([t(L * u, 0) for u in (0.2, 0.6, 0.9)]), 0.4, 0.3)
    for off in (-30, 0, 30):
        sepal(a, x, y, ang + off, L * 0.4, W * 0.24, "leaf", lw=0.5)


def fl_comfrey(a, sp):
    """A curled one-sided cluster that unrolls as the flowers open: hanging
    tubular bells, violet-mauve when open, pink in bud at the curled tip."""
    fc = sp["fc"]
    q = Quad((26, 99), (22, 44), (52, 26))
    stem_q(a, q.p0, q.c, q.p1, 3.2, 2.0)
    hairs_along(a, q, 0.05, 0.98, 26, 1.6, 65)
    # the cluster: an arch that curls over at the end
    pts = []
    for i in range(41):
        u = i / 40; th = math.radians(-160 + 300 * u ** 1.15); r = 30 * (1 - 0.78 * u)
        pts.append((52 + 6 + r * math.cos(th) * 0.95 + 0, 26 + 8 + r * math.sin(th) * 0.7))
    pts = [(52, 26)] + pts[3:]
    a.line(opath(pts), 1.4, 0.85)
    for j, i in enumerate(range(4, 40, 4)):
        x, y = pts[i]; s = 1 - 0.07 * j
        if j < 6:
            comfrey_bell(a, x, y + 1, 92 - j * 8, 17 * s, 8.4 * s, fc if j < 4 else "pink")
        else:
            a.polar(x, y + 2.4, lambda h: 1, 2.0 * s + 0.5, 3.2 * s, -j * 30, "pink", 0.6)
            sepal(a, x, y, -60 - j * 40, 4, 1.4, "leaf", lw=0.5)
    return a



# ---- lungwort
def funnel5(a, x, y, ang, s, fc, calc="leaf", face=0.6, lw=0.6):
    """A small funnel flower from the side: a five-angled hairy calyx, the
    narrow tube, and five rounded lobes opening at the mouth. face: how much
    the open mouth turns towards you."""
    t = T(x, y, ang)
    petal(a, x, y, ang, 8 * s, 3.6 * s, calc, prof(0.7, "round", "round", tp=4), lw=lw, lines=0)
    for o in (-0.8, 0.8):
        a.line(opath([t(8 * s * u, o * s) for u in (0.15, 0.6, 0.95)]), 0.35, 0.5)
    a.ribbon(t(6 * s), t(9 * s), t(12 * s), 2.2 * s, 3.4 * s, fc, lw=lw)
    c = t(13 * s)
    a.polar(c[0], c[1], lambda h: 1 + 0.12 * math.cos(5 * h), 3.2 * s * (0.45 + face), 4.4 * s, ang, fc, lw)
    a.oval(c[0], c[1], 0.9 * s * (0.4 + face), 1.1 * s, ang, "white", 0.4)


def fl_lungwort(a, sp):
    """A loose cluster at the top of a short leafy stem: small funnel flowers,
    pink when they open, turning violet then blue, on the same plant."""
    fc = sp["fc"]
    a.ribbon((48, 99), (46, 74), (50, 50), 2.6, 2.0, "leaf", lw=0.9)
    for sg in (1, -1):   # stem leaves, stalkless and half clasping
        blade(a, 47.6, 80, -90 + sg * 58, 22, 11, pal("lungwort", "leaf", "deep"), prof(0.35, "round", "point", bp=0.4), veins=3,
              spots="pale", spotn=8, spotr=1.0, d=2, lw=0.9)
    hub = (50, 50)
    for ang, L, col, s, face in ((-150, 18, "pink", 1.15, 0.5), (-112, 22, "mauve", 1.2, 0.9), (-68, 22, fc, 1.25, 1.0),
                                 (-30, 18, fc, 1.15, 0.6), (-90, 12, "pink", 0.9, 0.3), (-130, 30, "pink", 0.8, 0.2), (-50, 30, fc, 0.8, 0.2)):
        e = T(*hub, ang)(L * 0.55)
        a.line(f"M{P(hub)} Q{P(T(*hub, ang + 10)(L * 0.3))} {P(e)}", 0.8, 0.85)
        funnel5(a, e[0], e[1], ang + 20 * (1 if ang > -90 else -1), s * 1.7, col, "leaf", face)
    return a


# ---- cowslip
def cowslip_flower(a, x, y, ang, s, fc, calc="pale", spot="carrot", open_=0.5):
    """A cowslip flower hanging from x,y: a large pale green inflated calyx
    with five short teeth, and the deep yellow cup of the flower at its mouth,
    the lobes cupped (not flat), an orange spot at the foot of each."""
    t = T(x, y, ang)
    hw = lambda u: 4.2 * s * (0.35 + 0.65 * math.sin(math.pi * min(1, 0.25 + u * 0.75)) ** 0.6)
    us = [i / 20 for i in range(21)]
    up = [t(12 * s * u, hw(u)) for u in us]; dn = [t(12 * s * u, -hw(u)) for u in us]
    a.shape(path(up + [t(12.8 * s, 0)] + dn[::-1]), calc, 0.7)
    for o in (-0.5, 0, 0.5):
        a.line(opath([t(12 * s * u, hw(u) * o) for u in (0.1, 0.5, 0.95)]), 0.4, 0.4)
    a.polar(*t(14 * s), lambda h: 1 + 0.1 * math.cos(5 * h), 2.6 * s + open_ * 2.4 * s, 5.4 * s, ang, fc, 0.7)
    a.shape(path([T(*t(14 * s), ang)(-(2.6 * s + open_ * 2.4 * s) * math.cos(h), 5.4 * s * math.sin(h)) for h in [-math.pi / 2 + math.pi * i / 12 for i in range(13)]]), "shade", 0, fa=0.12)
    if open_ > 0.4:
        for k in range(5):
            p = T(*t(14.6 * s), ang)(0, (k - 2) * 1.8 * s); a.dot(p[0], p[1], 0.55 * s, spot)


def fl_cowslip(a, sp):
    """A drooping one-sided cluster at the top of a leafless downy stalk."""
    fc = sp["fc"]; spot = sp.get("cen", "carrot")
    q = Quad((40, 99), (40, 56), (48, 30))
    stem_q(a, q.p0, q.c, q.p1, 2.8, 2.2)
    hairs_along(a, q, 0.05, 0.98, 24, 1.0, 70)
    hub = q.p1
    for ang, L, s, op in ((-150, 9, 0.95, 0.3), (-110, 9, 0.95, 0.4), (-68, 9, 1.0, 0.6), (-25, 11, 1.1, 0.9), (10, 12, 1.15, 1.0),
                          (45, 12, 1.15, 1.0), (75, 10, 1.1, 0.8), (115, 8, 1.0, 0.5)):
        e = T(*hub, ang)(L)
        a.line(f"M{P(hub)} Q{P(T(*hub, ang - 15)(L * 0.6))} {P(e)}", 0.8, 0.85)
        hang = 70 if math.cos(math.radians(ang)) > -0.2 else 110
        cowslip_flower(a, e[0], e[1], hang - 20 * math.cos(math.radians(ang)) + 10, s * 1.45, fc, "pale", spot, op)
    return a


# ---- geum
def fl_geum(a, sp):
    """A semi-double scarlet bowl: two or three rows of rounded, slightly wavy
    petals round a green-yellow dome ringed by many yellow stamens; green
    pointed sepals behind, with tiny extra ones between; a round bud."""
    fc = sp["fc"]; cen = sp.get("cen", "primrose"); c = (46, 40); k = 0.78
    q = Quad((54, 99), (56, 70), (c[0] + 2, c[1] + 10))
    a.line(f"M{P(q.p0)} Q{P(q.c)} {P(q.p1)}", 1.5, 0.85)
    hairs_along(a, q, 0.05, 0.9, 16, 1.2, 70)
    a.line("M55,80 Q72,68 76,58", 1.2, 0.85)
    a.oval(77, 54, 4.6, 4.8, 0, "leaf", 0.8)   # the round bud
    for off in (-50, -10, 30, 70, 110):
        sepal(a, 77, 54, off - 90, 6, 2.6, "leaf", lw=0.55)
    a.line("M74.4,52 Q77,50 79.6,52", 0.9, 0.9, fc)
    M = tilt(c[1], k)
    for i in range(5):
        sepal(a, *c, -54 + 72 * i, 30, 7, "leaf", M=M, lw=0.7)
        sepal(a, *c, -18 + 72 * i, 18, 3, "leaf", M=M, lw=0.5)
    for r, n, st, sh in ((30, 6, -90, 0.08), (25, 6, -60, 0.1), (19, 5, -78, 0.12)):
        ring(a, n, r, r * 0.95, fc, ROUND, cx=c[0], cy=c[1], k=k, start=st, wav=0.035, lines=3, lw=0.8)
    burst(a, c[0], c[1], 40, 2.0, 12.5, "sun", M, lw=0.5, ar=0.95)
    a.oval(c[0], c[1] - 0.6, 6.4, 5.4, 0, cen, 0.8)
    for j in range(16):
        rr = 5.2 * math.sqrt((j + 0.5) / 16); a.dot(c[0] + rr * math.cos(j * GOLD), c[1] - 0.6 + rr * 0.8 * math.sin(j * GOLD), 0.45, "unripe")
    return a


# ---- viola
def fl_viola(a, sp):
    """A pansy seen face on, held out sideways on a stalk bent like a hook:
    two upper petals overlapping, one to each side, one broad lower petal with
    a short spur behind; dark lines running in to a small yellow eye."""
    fc = sp["fc"]; lip = sp.get("lipc", fc); c = (46, 44)
    a.line("M72,99 Q86,60 87,22 Q87,8 78,12 Q72,15 66,22", 1.6, 0.85)      # the stalk, bent over like a hook
    petal(a, 74, 16, -38, 10, 4.2, fc, prof(0.45, "round", "round", tp=3), lw=0.75, lines=0)   # the short spur poking back
    for off in (-40, 0, 40):
        sepal(a, 70, 19, 150 + off, 10, 2.8, "leaf", lw=0.6)
    for ang in (-118, -62):
        petal(a, c[0], c[1], ang, 30, 30, fc, ROUND, lw=0.9, lines=0, shade=0.14, wav=0.02)
    for ang in (170, 10):
        petal(a, c[0], c[1], ang, 27, 25, fc, ROUND, lw=0.9, lines=0, shade=0.06, wav=0.02)
    petal(a, c[0], c[1] - 1, 90, 31, 38, lip, ROUND, lw=0.9, lines=0, shade=0.06, wav=0.02)
    for ang, spread in ((90, (-26, -13, 0, 13, 26)), (170, (-10, 0, 10)), (10, (-10, 0, 10))):
        for o in spread:
            e = T(c[0], c[1], ang + o)(12 if o else 15)
            a.line(f"M{f(c[0])},{f(c[1])} Q{P(T(*c, ang + o * 0.6)(6))} {P(e)}", 0.8, 0.9, "dark")
    a.oval(c[0], c[1] + 1.5, 3.4, 2.4, 0, sp.get("cen", "sun"), 0.6)
    a.dot(c[0], c[1] + 1.2, 0.9, "unripe")
    return a


# ---- aubrieta
def fl_aubrieta(a, sp):
    """A loose cluster of flat four-petalled flowers on short stalks, one seen
    from the side to show the narrow sepals pressed into a tube."""
    fc = sp["fc"]; cen = sp.get("cen", "primrose")
    a.ribbon((48, 99), (48, 80), (50, 64), 2.4, 2.0, "sage", lw=0.85)
    for sg, L in ((1, 26), (-1, 22)):
        lf_aubrieta(a, 48.4, 90, -90 + sg * 60, L, pal("aubrieta", "leaf", "sage"), 2)
    for x, y in ((30, 36), (66, 34), (50, 22), (74, 60)):
        a.line(f"M50,64 Q{f((50 + x) / 2)},{f((64 + y) / 2 + 4)} {f(x)},{f(y)}", 0.9, 0.85)
    side4(a, 74, 60, -20, 1.2, fc, "sage")
    for x, y, r, st in ((30, 36, 15, -40), (66, 34, 16, -50), (50, 22, 13, -45)):
        cross4(a, x, y, r, fc, tilt(y, 0.86), st, veins="plum", cen=cen)
    return a


# ---- scarlet flax
def fl_linum(a, sp):
    """An open satiny saucer of five broad petals, wider at their ends and
    overlapping, a small dark eye with five pale stamens; a bud on the next
    thin stalk."""
    fc = sp["fc"]; cen = sp.get("cen", "dark"); c = (46, 42)
    a.line(f"M52,99 Q54,70 {f(c[0] + 2)},{f(c[1] + 8)}", 1.4, 0.85)
    a.line("M53,84 Q66,70 74,62", 1.1, 0.85)
    petal(a, 74, 62, -54, 11, 5.6, fc, prof(0.35, "round", "point", tp=1.1), lw=0.7, lines=1, end=1.0)
    for off in (-24, 24):
        sepal(a, 74, 62, -54 + off, 6, 2.0, "leaf", lw=0.5)
    M = tilt(c[1], 0.86)
    for i in range(5):
        sepal(a, *c, -54 + 72 * i, 12, 3, "leaf", M=M, lw=0.5)
    ring(a, 5, 30, 34, fc, FAN, cx=c[0], cy=c[1], k=0.86, start=-90, lines=3, lw=0.85)   # broad petals, overlapping
    a.oval(c[0], c[1], 6.0, 5.0, 0, cen, 0.6)
    for i in range(5):
        e = M(T(*c, -90 + 72 * i + 36)(5.6)); a.line(f"M{P(c)} L{P(e)}", 0.6, 0.9, "white"); a.dot(e[0], e[1], 0.8, "white")
    return a


# ---- marshmallow
def fl_marshmallow(a, sp):
    """A shallow saucer of five broad pale pink petals, slightly notched at
    the outer edge, round a short column of joined stamens with purplish-red
    anthers. Behind, a side flower shows the velvety calyx and the ring of
    narrow extra lobes (the epicalyx) beneath it."""
    fc = sp["fc"]; anth = sp.get("cen", "beet"); c = (44, 42)
    a.ribbon((58, 99), (60, 70), (62, 30), 3.0, 2.4, "sage", lw=0.85)
    lf_marshmallow(a, 60, 74, -20, 30, pal("marshmallow", "leaf", "sage"), 1)
    a.line(f"M61,52 Q52,52 {f(c[0] + 3)},{f(c[1] + 6)}", 1.0, 0.85)
    # the side flower, showing the calyx and epicalyx
    a.line("M62,36 Q70,34 74,30", 1.0, 0.85)
    for off in (-60, -30, 0, 30, 60):
        sepal(a, 74, 30, 140 + off, 6, 1.6, "sage", lw=0.5)
    petal(a, 74, 30, -40, 8, 8, "sage", prof(0.5, "round", "point"), lw=0.6, lines=0, end=1.0)
    for off in (-34, 34, 0):
        petal(a, *T(74, 30, -40)(4), -40 + off, 12, 9, fc, FAN, lw=0.6, lines=1, notch=0.08)
    M = tilt(c[1], 0.86)
    for i in range(5):
        sepal(a, *c, -54 + 72 * i, 16, 6, "sage", M=M, lw=0.55)
    ring(a, 5, 29, 27, fc, FAN, cx=c[0], cy=c[1], k=0.86, start=-90, notch=0.06, lines=3, lw=0.85)
    a.oval(c[0], c[1], 3.4, 3.0, 0, "white", 0.6)
    a.ribbon((c[0], c[1] + 1), (c[0], c[1] - 3), (c[0], c[1] - 7), 2.4, 2.0, "pink", lw=0.6)   # the stamen column
    for k in range(14):
        rr = 3.0 * math.sqrt((k + 0.5) / 14); a.oval(c[0] + rr * math.cos(k * GOLD), c[1] - 8 + rr * 0.6 * math.sin(k * GOLD), 0.9, 0.7, 0, anth, 0.35)
    return a


# ---- St John's-wort
def fl_sjw(a, sp):
    """A flat five-petalled star, the petals oval and a little lopsided (like
    a pinwheel) with tiny black dots along their edges; a fluffy burst of many
    long stamens in three bundles round three styles."""
    fc = sp["fc"]; c = (46, 44)
    a.ribbon((52, 99), (52, 76), (c[0] + 2, c[1] + 6), 2.4, 2.0, "leaf", lw=0.85)
    for (x, y) in ((76, 26), (70, 16)):
        a.line(f"M52,66 Q{f(x - 6)},{f(y + 14)} {f(x)},{f(y)}", 0.9, 0.85)
        a.polar(x, y - 2, lambda h: 1, 2.4, 3.4, 20, fc, 0.6)
        for off in (-30, 30):
            sepal(a, x, y, -70 + off, 4.4, 1.6, "leaf", lw=0.5)
    M = tilt(c[1], 0.88)
    for i in range(5):
        sepal(a, *c, -54 + 72 * i, 12, 3, "leaf", M=M, lw=0.5)
    lop = prof(0.6, "wedge", "round", bp=0.9, tp=1.8)
    for i in sorted(range(5), key=lambda i: math.sin(math.radians(-90 + 72 * i))):
        ang = -90 + 72 * i
        mp = petal(a, *c, ang + 10, 29, 12.5, fc, lop, M=M, lw=0.85, lines=3, shade=0.06)
        for u in (0.55, 0.68, 0.8, 0.9):   # black dots along one edge
            p = mp((29 * u, -6.25 * lop(u) * 0.86)); a.dot(p[0], p[1], 0.55, "dark")
    for b in range(3):   # three bundles of stamens
        base = b * 120 - 60
        for k in range(16):
            ang = base + (k - 7.5) * 6; L = 13 + 5 * ((k * 0.618) % 1)
            e = M(T(*c, ang)(L)); s0 = M(T(*c, base)(2))
            a.line(f"M{P(s0)} L{P(e)}", 0.4, 0.55); a.dot(e[0], e[1], 0.65, "sun")
    for ang in (-90, 30, 150):
        e = M(T(*c, ang)(6)); a.line(f"M{P(c)} L{P(e)}", 0.8, 0.85, "rust")
    a.oval(c[0], c[1], 2.4, 2.2, 0, "unripe", 0.6)
    return a


# ---- lady's bedstraw
def star4(a, x, y, r, fc, lw=0.35, start=0):
    """A tiny four-pointed star."""
    for i in range(4):
        a.leaf(x, y, start + 90 * i, r, 0.42, fc, lw=lw, skew=0.45, detail=False)


def fl_bedstraw(a, sp):
    """Hundreds of tiny four-pointed yellow stars packed into dense, branched,
    frothy clusters at the top of the stem, with a whorl of needle leaves
    below."""
    fc = sp["fc"]; lc = pal("lady-s-bedstraw", "leaf", "deep")
    q = Quad((50, 99), (50, 70), (50, 30))
    stem_q(a, q.p0, q.c, q.p1, 1.8, 1.3)
    for y, s in ((90, 1.0),):
        for k in range(10):
            ang = k * 36 + 10; e = T(50, y, ang)(16 * s)
            M = tilt(y, 0.4)
            a.line(f"M50,{y} L{P(M(e))}", 1.8, 0.85, "line"); a.line(f"M50,{y} L{P(M(e))}", 1.0, 1.0, lc)
    branches = [((50, 62), (26, 40)), ((50, 62), (74, 40)), ((50, 50), (34, 28)), ((50, 50), (66, 28)), ((50, 36), (44, 18)),
                ((50, 36), (57, 16)), ((50, 72), (20, 58)), ((50, 72), (80, 58))]
    for p0, p1 in branches:
        a.line(f"M{P(p0)} Q{f((p0[0] + p1[0]) / 2)},{f(p0[1] - 2)} {P(p1)}", 0.8, 0.85)
    a.line("M50,40 L50,22", 0.9, 0.85)
    pts = []
    for p0, p1 in branches + [((50, 40), (50, 22))]:
        for j in range(22):
            v = 0.45 + 0.55 * ((j * 0.618) % 1); ang = j * GOLD * 57.3
            base = lerp(p0, p1, v); rr = 3 + 5 * ((j * 0.37) % 1)
            pts.append((base[0] + rr * math.cos(math.radians(ang)), base[1] + rr * 0.8 * math.sin(math.radians(ang))))
    for k, (x, y) in enumerate(sorted(pts, key=lambda p: p[1])):
        if k % 5 == 0:
            a.oval(x, y, 1.0, 1.0, 0, "primrose", 0.4)   # a bud
        else:
            star4(a, x, y, 2.6, fc, start=k * 23)
    return a


# ---- rock sea-lavender
def fl_sealavender(a, sp):
    """Part of a wiry zig-zag flowering stem: short dense spikes along the
    upper side of the branches, each flower a tiny five-petalled pale violet
    face sitting in a small funnel-shaped papery calyx, with papery bracts."""
    fc = sp["fc"]
    zz = [(40, 99), (44, 76), (40, 58), (46, 40), (42, 24), (48, 8)]
    a.line(opath(zz), 1.5, 0.85)
    sp_ = [((44, 76), (74, 64)), ((40, 58), (14, 46)), ((46, 40), (76, 30)), ((42, 24), (18, 14)), ((46, 12), (62, 4))]
    for p0, p1 in sp_:
        a.line(f"M{P(p0)} L{P(p1)}", 1.1, 0.85)
        ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0])); n = int(math.dist(p0, p1) / 4.2)
        up = -90
        for j in range(1, n + 1):
            b = lerp(p0, p1, j / (n + 0.4)); s = 1 - 0.25 * j / n
            sepal(a, b[0], b[1], ang + 150, 3.2 * s, 2.0 * s, "straw", lw=0.45)   # a papery bract
            for o in (-6, 8):
                fa = up + o + (ang - (0 if p1[0] > p0[0] else 180)) * 0.3
                tq = T(*b, fa)
                petal(a, b[0], b[1], fa, 5.6 * s, 3.0 * s, "white", prof(0.8, "taper", "round", bp=1.2), lw=0.45, lines=0)
                e = tq(5.6 * s)
                for i in range(5):
                    a.leaf(e[0], e[1], i * 72 + o * 3, 2.4 * s, 0.85, fc, lw=0.35, skew=0.55, detail=False)
                a.dot(e[0], e[1], 0.35, "plum")
    return a


# ---- candy cane sorrel
def fl_oxalis(a, sp):
    """One flower open flat: five white petals overlapping like a furled
    umbrella opened out, a yellow throat, and the crimson edge on the back
    of each petal showing where it overlaps the next. Beside it, a closed
    bud twisted into a red and white spiral, like a candy cane."""
    fc = sp["fc"]; edge = sp.get("edge", "berry"); cen = sp.get("cen", "primrose"); c = (42, 42)
    a.line(f"M50,99 Q52,70 {f(c[0] + 2)},{f(c[1] + 6)}", 1.2, 0.85)
    for off in (-30, 30):
        sepal(a, c[0] + 2, c[1] + 6, 90 + off, 6, 1.8, "leaf", lw=0.5)
    # the closed bud: a twisted spindle with red stripes spiralling round it
    a.line("M54,99 Q66,70 72,46", 1.1, 0.85)
    bq = T(72, 46, -76); L = 26
    hw = lambda u: 3.8 * math.sin(math.pi * min(1, u * 1.0)) ** 0.7 * (1 - 0.4 * u)
    pts = [bq(L * u, hw(u)) for u in [i / 20 for i in range(21)]] + [bq(L * u, -hw(u)) for u in [i / 20 for i in range(20, -1, -1)]]
    a.shape(path(pts), "white", 0.8)
    for k in range(5):
        u0 = 0.06 + k * 0.19
        band = [bq(L * (u0 + 0.13 * v), hw(u0 + 0.13 * v) * (1 - 2 * v)) for v in [i / 8 for i in range(9)]]
        band2 = [bq(L * (u0 + 0.06 + 0.13 * v), hw(u0 + 0.06 + 0.13 * v) * (1 - 2 * v)) for v in [i / 8 for i in range(8, -1, -1)]]
        a.shape(path(band + band2), edge, 0)
    for off in (-24, 24):
        sepal(a, 72, 46, -76 + off, 6, 1.8, "leaf", lw=0.5)
    M = tilt(c[1], 0.9)
    pp = prof(0.62, "wedge", "round", bp=0.9, tp=1.8)
    for i in range(5):
        ang = -90 + 72 * i
        mp = petal(a, *c, ang, 27, 22, fc, pp, M=M, lw=0.85, lines=1, shade=0.06)
        # the red edge from the back, showing along the overlapped side
        a.line(opath([mp((27 * u, 11 * pp(u) * 0.92)) for u in (0.4, 0.55, 0.7, 0.85, 0.95)]), 1.6, 0.9, edge)
    a.oval(c[0], c[1], 6.4, 5.6, 0, cen, 0)
    a.oval(c[0], c[1], 2.4, 2.0, 0, "sun", 0.5)
    for i in range(5):
        e = M(T(*c, -54 + 72 * i)(3)); a.dot(e[0], e[1], 0.6, "unripe")
    return a


BLOOM_DRAW = {"flowers_foxglove": fl_foxglove, "flowers_salvia": fl_salvia, "flowers_primrose": fl_primrose,
              "flowers_wallflower": fl_wallflower, "flowers_rattle": fl_rattle, "flowers_selfheal": fl_selfheal,
              "flowers_sweetwilliam": fl_sweetwilliam, "flowers_poppy": fl_poppy, "flowers_calpoppy": fl_calpoppy,
              "flowers_borage": fl_borage, "flowers_comfrey": fl_comfrey, "flowers_lungwort": fl_lungwort,
              "flowers_cowslip": fl_cowslip, "flowers_geum": fl_geum, "flowers_viola": fl_viola, "flowers_aubrieta": fl_aubrieta,
              "flowers_linum": fl_linum, "flowers_marshmallow": fl_marshmallow, "flowers_sjw": fl_sjw,
              "flowers_bedstraw": fl_bedstraw, "flowers_sealavender": fl_sealavender, "flowers_oxalis": fl_oxalis}
BLOOMX = {"foxglove": dict(kind="flowers_foxglove"), "salvia": dict(kind="flowers_salvia"),
          "common-evening-primrose": dict(kind="flowers_primrose"), "wallflower": dict(kind="flowers_wallflower"),
          "yellow-rattle": dict(kind="flowers_rattle"), "selfheal": dict(kind="flowers_selfheal"),
          "sweet-william": dict(kind="flowers_sweetwilliam"), "poppy": dict(kind="flowers_poppy"),
          "california-poppy": dict(kind="flowers_calpoppy"), "borage": dict(kind="flowers_borage"),
          "russian-comfrey": dict(kind="flowers_comfrey"), "lungwort": dict(kind="flowers_lungwort"),
          "native-cowslip": dict(kind="flowers_cowslip"), "geum": dict(kind="flowers_geum"), "viola": dict(kind="flowers_viola"),
          "aubrieta": dict(kind="flowers_aubrieta"), "linum": dict(kind="flowers_linum"), "marshmallow": dict(kind="flowers_marshmallow"),
          "perforate-st-john-s-wort": dict(kind="flowers_sjw"), "lady-s-bedstraw": dict(kind="flowers_bedstraw"),
          "rock-sea-lavender": dict(kind="flowers_sealavender"), "candy-cane-sorrel": dict(kind="flowers_oxalis", edge="berry")}


# ============================================================ life stages: helpers
def soil(y=88):
    a = Art(); a.ground(y); return a


def sown(seed_fn):
    """The 'seed' stage: seeds drawn large under the soil line (as plants.sown)."""
    return S10.sown(seed_fn)


def shoot(a, x0, y0, x1, y1, bow=0.0, w0=2.0, w1=1.0, col="leaf", lw=0.75):
    """A stem from x0,y0 to x1,y1, bowed to one side by bow."""
    return a.ribbon((x0, y0), ((x0 + x1) / 2 + bow, (y0 + y1) / 2), (x1, y1), w0, w1, col, lw=lw)


def leafy(a, kind, q, us, L, opp=False, spread=55, shrink=0.4, fill=None, start=1, d=None, tip=False):
    """The kind's own leaves along stem q at the points us (0 the foot, 1 the
    tip): set singly, first one side then the other, or in opposite pairs,
    every other pair turned to face you (shorter, pointing more up)."""
    for i, u in enumerate(us):
        x, y = q.pt(u); ang = q.ang(u); l = L * (1 - shrink * u)
        if opp:
            if i % 2:
                leaf(a, kind, x, y, ang - spread * 0.45, l * 0.75, fill, d); leaf(a, kind, x, y, ang + spread * 0.45, l * 0.75, fill, d)
            else:
                leaf(a, kind, x, y, ang - spread, l, fill, d); leaf(a, kind, x, y, ang + spread, l, fill, d)
        else:
            sd = start if i % 2 else -start
            leaf(a, kind, x, y, ang + sd * spread, l, fill, d)
    if tip:
        x, y = q.pt(1)
        for o in (-18, 18):
            leaf(a, kind, x, y, q.ang(1) + o, L * 0.35, fill, 0)


ROS = [-174, -6, -156, -24, -136, -44, -116, -64, -100, -80, -90]


def rosette(a, kind, x=50, y=88, n=9, L=30, fill=None, flat=0.0, d=None, skip=()):
    """Leaves fanning out from one point on the ground, the outer ones first.
    flat: a rosette lying flat on the soil, seen from the side, so its inner
    leaves are seen end on (shorter) and all lie low."""
    angs = [g for g in ROS if g not in skip][:n] if n < 11 else ROS
    for g in angs:
        k = abs(g + 90) / 90
        if flat:
            ang = -90 + (g + 90) * (1 + flat * 0.25) if abs(g + 90) < 80 else g
            ang = max(-178, min(-2, ang))
            l = L * ((1 - flat) + flat * (0.45 + 0.55 * k ** 0.6))
        else:
            ang = g; l = L * (0.72 + 0.28 * (1 - k))
        leaf(a, kind, x + (g + 90) * 0.02, y, ang, l, fill, d)


def grass(a, xs, y=88, h=34, col="unripe"):
    """Blades of meadow grass round a plant that grows in grass."""
    with a.on(STEM):
        for i, x in enumerate(xs):
            hh = h * (0.7 + 0.3 * math.sin(i * 2.3 + 1)); lean = 6 * math.sin(i * 1.7)
            a.ribbon((x, y), (x + lean * 0.3, y - hh * 0.5), (x + lean, y - hh), 1.8, 0.3, col, lw=0.6)


def seedling(kind, cot, true=(), h=13, stemc="pale", tleaf=None, s=2.1, spread=74):
    """A seedling, drawn larger than life (s) so that it reads in the app:
    soil, roots, a short stem and two seed leaves, then the first true
    leaves. cot: (shape, length, width): shape "oval", "round", "strap",
    "split" (each seed leaf split in two at its tip) or "kidney".
    true: [(angle, length)] of the kind's own leaves, from the stem top."""
    a = Art(); a.ground(G); a.roots(50, G, 3, 9 * s, 50)
    h *= s; top = (50, G - h)
    with a.group():
        a.ribbon((50, G), (49.4, G - h * 0.5), top, 1.3 * s, 1.0 * s, stemc, lw=0.75)
        shape, L, W = cot; L *= s; W *= s
        for sg in (1, -1):
            ang = -90 + sg * (spread if shape != "strap" else min(spread, 66))
            st = T(*top, ang)(1.4 * s)
            with a.on(LEAF):
                a.line(f"M{P(top)} L{P(st)}", 0.9, 0.85)
                if shape == "round":
                    blade(a, *st, ang, L, W, "pale", prof(0.5, "round", "round", bp=0.5, tp=2.0), veins=0, midw=0.5, lw=0.85, d=1)
                elif shape == "kidney":
                    blade(a, *st, ang, L, W, "pale", prof(0.55, "round", "round", bp=0.4, tp=2.4), back=0.08, veins=0, midw=0.5, lw=0.85, d=1)
                elif shape == "strap":
                    blade(a, *st, ang, L, W, "pale", prof(0.5, "round", "round", bp=0.4, tp=4), veins=0, midw=0, lw=0.8, d=1)
                elif shape == "split":
                    for o in (-7, 7):
                        blade(a, *st, ang + o, L, W, "pale", prof(0.5, "round", "round", bp=0.4, tp=4), veins=0, midw=0, lw=0.75, d=0)
                else:
                    blade(a, *st, ang, L, W, "pale", prof(0.45, "round", "point", bp=0.5, tp=1.4), veins=0, midw=0.5, lw=0.85, d=1)
        for ang, L in true:
            (tleaf or (lambda a_, x, y, g, l: leaf(a_, kind, x, y, g, l, None, 1)))(a, top[0], top[1], ang, L * s)
    return a


def first_leaf(fill, pf, W, petiole=0.3, teeth=0, td=0.0, tk="round", wave=0.0, nw=0, pucker=False, felt=0):
    """A seedling's first true leaf, drawn with its teeth and wrinkles made
    big enough to see at seedling size."""
    def draw(a, x, y, g, l):
        with a.on(LEAF):
            simple_leaf(a, x, y, g, l, fill, 1, petiole=petiole, W=W, pf=pf, teeth=teeth, td=td, tk=tk, wave=wave, nw=nw,
                        veins=3, vang=0.22, pucker=pucker, felt=felt)
    return draw


def capsule(a, x, y, ang, L, W, fill="seed", split=0, lw=0.6, beak=0.0):
    """An egg-shaped or long pointed fruit from x,y along ang. split: that many
    teeth opened at the tip. beak: a short point left by the style."""
    t = T(x, y, ang)
    pf_ = prof(0.4, "round", "point", bp=0.6, tp=1.0)
    pts = [t(L * i / 20, pf_(i / 20) * W / 2) for i in range(21)] + [t(L * i / 20, -pf_(i / 20) * W / 2) for i in range(20, -1, -1)]
    a.shape(path(pts), fill, lw)
    a.shape(path(pts[:21] + [t(0, 0)]), "shade", 0, fa=0.12)
    if split:
        e = t(L)
        for k in range(split):
            o = (k - (split - 1) / 2) * 28
            a.line(f"M{P(t(L * 0.86))} L{P(T(*e, ang + o)(L * 0.18))}", 0.7, 0.85)
    if beak:
        a.line(f"M{P(t(L))} L{P(t(L * (1 + beak)))}", 0.6, 0.85)


def pod(a, x, y, ang, L, w, fill="unripe", lw=0.55, split=0, ribs=1):
    """A long narrow pod from x,y along ang."""
    e = T(x, y, ang)(L); m = T(x, y, ang)(L * 0.5, L * 0.03)
    a.ribbon((x, y), m, e, w, w * 0.55, fill, lw=lw, round_tip=True)
    if ribs and L > 6:
        a.line(opath([T(x, y, ang)(L * u, 0) for u in (0.08, 0.5, 0.9)]), 0.35, 0.4)
    if split:   # the tip split open into curling teeth
        for o in (-38, -13, 13, 38)[:split]:
            a.line(f"M{P(T(x, y, ang)(L * 0.86))} Q{P(T(*e, ang + o)(L * 0.12))} {P(T(*e, ang + o * 1.6)(L * 0.24))}", 0.65, 0.9)


# ============================================================ seeds
def seeds_at(a, x, y, pts, fn):
    for i, (dx, dy, r) in enumerate(pts):
        fn(a, x + dx, y + dy, r, i)


THREE = [(-9, 2, -20), (8, -4, 30), (1, 9, 75)]
MANY = [(-12, 0, 10), (-5, -5, 60), (3, -6, -20), (10, -2, 40), (13, 5, 100), (5, 4, 15), (-4, 6, 80), (-11, 8, -40), (-2, -1, 130),
        (8, 10, 70), (-16, -6, 0), (17, -4, 50), (0, 13, 30), (-8, 13, 110)]


def seed_oval(a, x, y, ang, L, W, fill, lw=0.8, rib=0, line=True, gloss=False):
    a.oval(x, y, L / 2, W / 2, ang, fill, lw)
    t = T(x, y, ang)
    if line:
        a.line(f"M{P(t(-L * 0.3, -W * 0.18))} Q{P(t(0, -W * 0.34))} {P(t(L * 0.3, -W * 0.18))}", 0.5, 0.35)
    for k in range(rib):
        o = (k - (rib - 1) / 2) * W / (rib + 0.5)
        a.line(opath([t(-L * 0.38, o * 0.8), t(0, o), t(L * 0.38, o * 0.8)]), 0.4, 0.45)
    if gloss:
        a.line(f"M{P(t(-L * 0.2, -W * 0.22))} L{P(t(L * 0.1, -W * 0.26))}", 0.7, 0.6, "white")


# ============================================================ foxglove
def mini_glove(a, x, y, ang, L, W, fc, spot="dark", lw=0.55):
    """A foxglove bell at plant scale: a tube widening to the mouth, the lower
    lip jutting out, one or two dark spots showing inside."""
    t = T(x, y, ang)
    pts = [t(0, -W * 0.16), t(L * 0.95, -W * 0.5), t(L * 1.02, -W * 0.3), t(L * 1.0, W * 0.1), t(L * 1.18, W * 0.52), t(L * 0.9, W * 0.55), t(0, W * 0.16)]
    a.shape(f"M{P(pts[0])} Q{P(t(L * 0.5, -W * 0.4))} {P(pts[1])} L{P(pts[2])} L{P(pts[3])} Q{P(t(L * 1.2, W * 0.3))} {P(pts[4])} Q{P(t(L * 0.6, W * 0.6))} {P(pts[6])} Z", fc, lw)
    a.shape(f"M{P(pts[0])} Q{P(t(L * 0.5, -W * 0.4))} {P(pts[1])} L{P(t(L * 0.9, 0))} L{P(t(0, 0))} Z", "shade", 0, fa=0.12)
    a.oval(*t(L * 0.98, W * 0.05), max(0.5, L * 0.07), W * 0.3, ang, "pink", 0.4)
    if spot and L > 3.5:
        p = t(L * 1.04, W * 0.3); a.dot(p[0], p[1], max(0.35, W * 0.09), spot)


def foxglove_seed(a, x, y):
    """Thousands of seeds, tiny, oblong and brown, like dust."""
    for k in range(34):
        rr = 15 * math.sqrt((k + 0.5) / 34); th = k * GOLD
        a.oval(x + rr * math.cos(th) * 1.25, y + rr * math.sin(th) * 0.75, 1.6, 0.95, k * 47, "bark", 0.25)


def foxglove_stages():
    k = "foxglove"; fc = pal(k, "flower", "mauve"); cen = pal(k, "centre", "dark"); lc = pal(k, "leaf", "sage")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=11, L=36, flat=0.6)
        return a

    def plant(a, seed=False):
        rosette(a, k, n=7, L=27, flat=0.5, fill="straw" if seed else None)
        q = shoot(a, 50, 88, 51, 5, 0.6, 2.8, 1.2, "bark" if seed else "leaf")
        leafy(a, k, q, (0.07, 0.14, 0.21, 0.28, 0.35), 19, spread=50, shrink=1.4, fill="bark" if seed else None)
        return q

    def flower():
        a = soil()
        with a.group():
            q = plant(a)
            with a.on(BLOOM):
                n = 13
                for j in range(n):   # a one-sided spike: the bells all hang to the right
                    u = 0.36 + 0.58 * j / (n - 1); x, y = q.pt(u); s = 1.25 - 0.6 * j / n
                    if j >= n - 4:     # tight green buds at the top
                        e = (x + 1.6, y + 0.4); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.5, 0.85)
                        a.oval(e[0] + 0.6, e[1] + 1.2, 1.2 * s + 0.4, 1.6 * s + 0.5, -20, "unripe" if j > n - 3 else fc, 0.5)
                        continue
                    e = (x + 1.8 + 1.6 * (j % 2), y + 0.2)
                    a.line(f"M{f(x)},{f(y)} Q{f(x + 1.6)},{f(y - 0.8)} {P(e)}", 0.6, 0.85)
                    mini_glove(a, e[0], e[1], 58 - 10 * (j % 2), 9.5 * s, 5.6 * s, fc, cen)
        return a

    def seedhead():
        a = soil()
        with a.group():
            q = plant(a, seed=True)
            with a.on(BLOOM):
                for j in range(16):   # upright pointed capsules up the old spike, split at the tip
                    u = 0.36 + 0.6 * j / 15; x, y = q.pt(u); sd = 1 if j % 2 else -1
                    s = 1 - 0.35 * j / 12
                    capsule(a, x + sd * 0.8, y, -90 + sd * 30, 6.4 * s, 4.2 * s, "bark", split=2, lw=0.5)
                    e = T(x + sd * 0.8, y, -90 + sd * 30)(6.4 * s)   # the two halves gaping at the tip
                    for o in (-40, 40):
                        a.line(f"M{P(e)} L{P(T(*e, -90 + sd * 30 + o)(1.6))}", 0.7, 0.9, "dark")
                    for o in (-30, 30):
                        a.leaf(x + sd * 0.8, y, 90 + sd * 34 + o, 1.6, 0.4, "straw", lw=0.35, detail=False)
        return a

    return {"seed": sown(foxglove_seed),
            "seedling": lambda: seedling(k, ("round", 5, 4.2), ((-168, 12), (-12, 12), (-120, 9)), h=4, spread=80,
                                         tleaf=first_leaf(lc, prof(0.45, "round", "blunt", bp=0.5, tp=1.6), 0.6, 0.25, teeth=6, td=0.5, felt=12)),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ salvia
def salvia_seed(a, x, y):
    """Small, smooth, round-oval dark brown seeds."""
    seeds_at(a, x, y, THREE + [(-2, -6, 60)], lambda a, x, y, r, i: seed_oval(a, x, y, r, 9, 6.4, "dark", gloss=True))


def whorl_spike(a, q, u0, u1, n, s, fc, br="plum", dry=False, buds=3):
    """Whorls of small two-lipped flowers stacked up the top of stem q, each
    over a pair of tinted bracts; buds at the tip. dry: brown papery calyces."""
    with a.on(BLOOM):
        for j in range(n):
            u = u0 + (u1 - u0) * j / max(1, n - 1); x, y = q.pt(u); ang = q.ang(u)
            kk = 1 - 0.3 * j / n
            if dry:
                for sd in (-1, 1):
                    a.leaf(x, y, ang + sd * 52, 2.8 * s * kk, 0.5, "bark", lw=0.35, detail=False)
                continue
            if j >= n - buds:
                for sd in (-1, 1):
                    a.leaf(x, y, ang + sd * 30, 2.2 * s * kk, 0.5, br, lw=0.4, detail=False)
                continue
            for sd in (-1, 1):
                a.leaf(x, y + 0.3, ang + 180 - sd * 110, 1.8 * s, 0.5, br, lw=0.4, detail=False)
                t = T(x, y, ang + sd * 62)
                a.leaf(x, y, ang + sd * 62, 2.0 * s * kk, 0.45, br, lw=0.4, detail=False)
                e = t(1.6 * s * kk)
                a.leaf(e[0], e[1], ang + sd * 30, 2.6 * s * kk, 0.45, fc, lw=0.4, detail=False)    # the hood
                a.leaf(e[0], e[1], ang + sd * 95, 2.3 * s * kk, 0.7, fc, lw=0.4, detail=False)    # the lower lip


def salvia_stages():
    k = "salvia"; fc = pal(k, "flower", "plum"); lc = pal(k, "leaf", "sage")
    stems = [(-14, 0.8, -7), (-7, 0.93, -3), (0, 1.0, 0), (7, 0.95, 3), (14, 0.82, 7), (-3, 0.86, -1.5), (4, 0.88, 1.6)]

    def clump(a, H, n=7, leaves=3, brown=False, cut=False):
        qs = []
        for dx, hh, lean in stems[:n]:
            top = 88 - H * hh
            q = shoot(a, 50 + dx * 0.4, 88, 50 + dx * 1.6 + lean, top, 0, 1.8, 1.0, "straw" if brown else "leaf")
            qs.append(q)
            if leaves:
                leafy(a, k, q, [0.08 + 0.17 * i for i in range(leaves)], 15, opp=True, spread=58, shrink=0.5,
                      fill="straw" if brown else None)
        return qs

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=5, L=18)
            for dx, hh in ((-12, 30), (12, 32), (0, 40)):   # square stems starting to rise, the leaves in crossing pairs
                q = shoot(a, 50 + dx * 0.3, 88, 50 + dx, 88 - hh, 0, 2.0, 1.4)
                leafy(a, k, q, (0.3, 0.62, 0.9), 15, opp=True, spread=62, shrink=0.35)
        return a

    def flower():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=17)
            qs = clump(a, 72)
            for q in qs:
                whorl_spike(a, q, 0.42, 1.0, 9, 1.3, fc, "plum")
        return a

    def seedhead():
        a = soil()
        with a.group():
            rosette(a, k, n=5, L=14)
            qs = clump(a, 68, leaves=2)
            for q in qs:
                whorl_spike(a, q, 0.42, 1.0, 9, 1.3, fc, dry=True)
        return a

    def dormant():
        a = soil()
        with a.group():
            for dx, hh in ((-10, 9), (-4, 12), (3, 11), (9, 8)):   # old stems cut back
                a.ribbon((50 + dx, 88), (50 + dx, 88 - hh / 2), (50 + dx * 1.1, 88 - hh), 1.8, 1.6, "bark", lw=0.7)
                a.line(f"M{f(50 + dx * 1.1 - 1)},{f(88 - hh)} l2,-0.5", 0.7, 0.8)
            rosette(a, k, n=9, L=14)
        return a

    return {"seed": sown(salvia_seed),
            "seedling": lambda: seedling(k, ("round", 5.4, 4.6), ((-124, 10), (-56, 10)), h=10,
                                         tleaf=first_leaf(lc, prof(0.35, "round", "blunt", bp=0.4, tp=1.8), 0.5, 0.18, teeth=7, td=0.6, pucker=True)),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ evening primrose
def primrose_seed(a, x, y):
    """Tiny angular, irregular reddish-brown seeds."""
    for i, (dx, dy, r) in enumerate(MANY[:11]):
        pts = [T(x + dx * 1.1, y + dy * 1.1, r + j * 72 + (j * 23 % 30))(2.6 + 0.8 * ((j * 7 + i) % 3) / 2) for j in range(5)]
        a.shape(path(pts), "flowers_russet", 0.6)


def mini_cross(a, x, y, r, fc, ang=-90, k=0.7, lw=0.45, cen="sun", wd=1.0):
    """A four-petalled flower at plant scale, facing up and out. wd: the
    petals' width (below 1 leaves a gap between them, so the cross shows)."""
    M = tilt(y, k)
    for i in range(4):
        petal(a, x, y, -45 + 90 * i, r, r * wd, fc, ROUND, M=M, lw=lw, lines=0, shade=0.05)
    a.dot(x, y, max(0.4, r * 0.18), cen)


def primrose_stages():
    k = "common-evening-primrose"; fc = pal(k, "flower", "primrose")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=11, L=30, flat=0.65)
        return a

    def plant(a, seed=False):
        rosette(a, k, n=7, L=22, flat=0.6, fill="seed" if seed else None)
        q = shoot(a, 50, 88, 51, 6, 0.5, 2.8, 1.4, "bark" if seed else "leaf")
        us = [0.06 + 0.06 * i for i in range(10)]
        leafy(a, k, q, us, 19, spread=44, shrink=0.8, fill="seed" if seed else None)
        return q

    def flower():
        a = soil()
        with a.group():
            q = plant(a)
            with a.on(BLOOM):
                for j, u in enumerate((0.64, 0.7, 0.76)):   # young pods pressed to the stem below the flowers
                    for sd in (-1, 1):
                        x, y = q.pt(u - 0.02 * sd); pod(a, x + sd * 0.8, y, -90 + sd * 8, 7, 1.6, "unripe")
                for u, sd, s in ((0.8, -1, 1.0), (0.84, 1, 1.0), (0.91, -1, 0.85), (0.94, 1, 0.75)):
                    x, y = q.pt(u); e = (x + sd * 9, y - 5)
                    a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 2)},{f(y - 5)} {P(e)}", 0.9, 0.85)   # the long tube
                    mini_cross(a, e[0], e[1], 8.0 * s, fc, k=0.75)
                for o in (-14, 0, 14):   # buds at the top
                    e = q.pt(1); a.leaf(e[0], e[1], -90 + o, 5, 0.3, "unripe", lw=0.45, detail=False)
        return a

    def seedhead():
        a = soil()
        with a.group():
            q = plant(a, True)
            with a.on(BLOOM):
                for j in range(12):   # long narrow upright pods pressed to the stem, split into four at the tips
                    u = 0.52 + 0.44 * j / 11; x, y = q.pt(u); sd = 1 if j % 2 else -1
                    pod(a, x + sd * 1.0, y + 4, -90 + sd * 10, 12 - 3 * j / 11, 2.4, "bark", split=4)
        return a

    return {"seed": sown(primrose_seed),
            "seedling": lambda: seedling(k, ("round", 5, 3.8), ((-166, 12), (-14, 12), (-118, 9)), h=4, spread=80),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ wallflower
def wallflower_seed(a, x, y):
    """Flat, oval, light brown seeds, a narrow rim round each."""
    def one(a, x, y, r, i):
        a.oval(x, y, 6.2, 4.6, r, "seed", 0.8); a.oval(x, y, 4.8, 3.3, r, None, 0.4, la=0.4)
    seeds_at(a, x, y, THREE, one)


def bushy(a, kind, n=6, H=50, w=1.0, fill=None, leafL=13, dense=10, col="leaf", woody=True, upto=1.0):
    """A bushy plant: stems branching from a woody base, leaves crowded up them."""
    qs = []
    base = [(-18, 0.72, -14), (18, 0.74, 14), (-9, 0.9, -6), (9, 0.92, 6), (0, 1.0, 0), (-26, 0.55, -20), (26, 0.56, 20)][:n]
    for dx, hh, lean in base:
        x0 = 50 + dx * 0.25 * w
        q = shoot(a, x0, 88, 50 + dx * w + lean * 0.3, 88 - H * hh, lean * 0.15, 2.2, 1.1, col)
        qs.append(q)
        if woody:
            a.ribbon((x0, 88), (x0 + dx * 0.04, 84), q.pt(0.12), 2.6, 2.2, "bark", lw=0.6)
        leafy(a, kind, q, [0.12 + (upto - 0.14) * i / (dense - 1) for i in range(dense)], leafL, spread=42, shrink=0.35, fill=fill)
    return qs


def wallflower_stages():
    k = "wallflower"; fc = pal(k, "flower", "carrot")

    def young():
        a = soil()
        with a.group():
            bushy(a, k, n=5, H=40, w=0.9, leafL=15, dense=9)
        return a

    def flower():
        a = soil()
        with a.group():
            qs = bushy(a, k, n=7, H=48, w=0.95, leafL=16, dense=10)
            with a.on(BLOOM):
                for i, q in enumerate(qs):   # a crowded short spike at every stem tip: open crosses below, buds above
                    e = q.pt(1); ang = q.ang(1)
                    for o, l, r in ((-62, 3.4, 4.4), (62, 3.4, 4.4), (0, 4.6, 4.0)):
                        p = T(*e, ang + o)(l)
                        a.line(f"M{P(e)} L{P(p)}", 0.5, 0.85)
                        mini_cross(a, p[0], p[1], r, fc, k=0.8, cen="pear", wd=0.82)
                    for o in (-14, 14):
                        p = T(*e, ang + o)(8.4); a.oval(p[0], p[1], 1.0, 1.6, ang + 90 + o, fc, 0.45)
        return a

    def seedhead():
        a = soil()
        with a.group():
            qs = bushy(a, k, n=7, H=32, w=0.95, leafL=11, dense=6, upto=0.7)
            with a.on(BLOOM):
                for q in qs:   # each stem tip lengthened into a bare stalk lined with long, thin, upright pods held close
                    e = q.pt(1); ang = q.ang(1)
                    sq = shoot(a, *e, *T(*e, ang)(26), 0, 1.0, 0.6, "straw")
                    for j in range(6):
                        p = sq.pt(0.04 + 0.16 * j); sd = 1 if j % 2 else -1
                        b = T(*p, ang + sd * 40)(0.9)
                        a.line(f"M{P(p)} L{P(b)}", 0.5, 0.85)
                        pod(a, *b, ang + sd * 4, 19 - 1.8 * j, 1.0, "seed" if j < 4 else "unripe", lw=0.4, ribs=0)
        return a

    return {"seed": sown(wallflower_seed),
            "seedling": lambda: seedling(k, ("round", 5.4, 4.4), ((-110, 11), (-70, 11)), h=11),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ yellow-rattle
def rattle_seed(a, x, y):
    """Flat round brown seeds, each with a papery wing all round."""
    def one(a, x, y, r, i):
        a.oval(x, y, 7.4, 6.8, r, "straw", 0.7); a.oval(x, y, 4.6, 4.2, r, "bark", 0.7)
        a.line(f"M{f(x - 2)},{f(y - 1.4)} Q{f(x)},{f(y - 2.6)} {f(x + 2)},{f(y - 1.4)}", 0.5, 0.35)
    seeds_at(a, x, y, THREE, one)


def rattle_stages():
    k = "yellow-rattle"; fc = pal(k, "flower", "sun"); tooth = pal(k, "centre", "plum"); lc = pal(k, "leaf", "deep")
    GR = [14, 20, 27, 33, 40, 61, 67, 74, 80, 86]

    def stems(a, H, n=2, fill=None, col="leaf"):
        qs = []
        for dx, hh, lean in ((0, 1.0, 1), (-10, 0.8, -6), (11, 0.74, 7))[:n]:
            q = shoot(a, 50 + dx * 0.4, 88, 50 + dx + lean, 88 - H * hh, 0, 1.8, 1.0, col)
            for kk in range(int(H * hh / 6)):   # black streaks on the stem
                p = q.pt(0.08 + kk * 6 / (H * hh)); a.line(f"M{P(p)} l0.2,1.2", 0.5, 0.9, "dark")
            qs.append(q)
        return qs

    def young():
        a = soil()
        with a.group():
            grass(a, GR, h=26)
            q, = stems(a, 38, 1)
            leafy(a, k, q, (0.1, 0.32, 0.54, 0.76), 15, opp=True, spread=56, shrink=0.35, tip=True)
        return a

    def flower(seed=False):
        a = soil()
        with a.group():
            grass(a, GR, h=36, col="straw" if seed else "unripe")
            qs = stems(a, 64, 3, col="bark" if seed else "leaf")
            for q in qs:
                leafy(a, k, q, (0.08, 0.22, 0.36), 14, opp=True, spread=58, shrink=0.4, fill="straw" if seed else None)
                with a.on(BLOOM):
                    for j in range(6):   # a dense leafy spike, the flowers in pairs in opposite bracts
                        u = 0.48 + 0.1 * j; x, y = q.pt(u); s = 1.2 - 0.1 * j
                        for sd in (-1, 1):
                            a.leaf(x, y + 0.6, -90 + sd * 80, 4.2 * s, 0.5, "straw" if seed else lc, lw=0.45, detail=False, edge="saw")
                        for sd in (-1, 1):
                            c = (x + sd * 2.4 * s, y - 1.0)
                            if seed:   # the flat round papery purse
                                a.oval(*c, 2.6 * s, 2.5 * s, 0, "straw", 0.5); a.dot(c[0], c[1], 0.9 * s, "bark")
                            elif j < 3:
                                a.oval(*c, 2.3 * s, 2.1 * s, 0, "unripe", 0.5)
                                tq = T(*c, -90 + sd * 40); e = tq(4.4 * s)
                                a.ribbon(tq(1.0 * s), tq(2.8 * s), e, 1.8 * s, 2.2 * s, fc, lw=0.4)
                                a.leaf(e[0], e[1], -90 + sd * 10, 2.2 * s, 0.6, fc, lw=0.35, detail=False)
                                a.dot(*T(*e, -90 + sd * 10)(2.0 * s), 0.35, tooth)
                            else:
                                a.oval(*c, 1.6 * s, 1.5 * s, 0, "unripe", 0.45)
        return a

    return {"seed": sown(rattle_seed),
            "seedling": lambda: seedling(k, ("oval", 7, 3), ((-122, 9), (-58, 9)), h=10,
                                         tleaf=first_leaf(pal(k, "leaf", "deep"), prof(0.3, "round", "point", bp=0.4, tp=1.2), 0.42, 0.0, teeth=4, td=0.9, tk="saw")),
            "young": young, "flower": flower, "seedhead": lambda: flower(True)}


# ============================================================ selfheal
def selfheal_seed(a, x, y):
    """Small oval brown seeds, faintly lined."""
    seeds_at(a, x, y, THREE, lambda a, x, y, r, i: seed_oval(a, x, y, r, 9, 6, "bark", rib=3, line=False))


def runners(a, y=88, col="leaf", spans=((-40, -6), (4, 40))):
    """Creeping stems lying along the soil, rooting at their joints."""
    qs = []
    for x0, x1 in spans:
        q = a.ribbon((50 + x0 * 0.1, y - 0.6), (50 + (x0 + x1) / 2, y - 2.4), (50 + x1, y - 0.8), 1.7, 1.2, col, lw=0.6)
        qs.append(q)
        for u in (0.4, 0.8):
            p = q.pt(u); a.roots(p[0], y, 2, 3.5, 40, lw=0.6)
    return qs


def head_square(a, x, y, w, h, fc, br="plum", dry=False, lw=0.45):
    """A dense squarish oblong head at plant scale: tiers of bracts, a ring of
    flowers sticking out sideways."""
    with a.on(BLOOM):
        a.shape(path([(x - w / 2, y), (x - w / 2 + 0.3, y - h + 1), (x, y - h), (x + w / 2 - 0.3, y - h + 1), (x + w / 2, y)]), "dark" if dry else br, lw)
        for r in range(4):   # the tiers of bracts (dry: the closed calyces, a little paler, like the scales of a cone)
            yy = y - 0.6 - r * (h - 1.2) / 4
            a.line(f"M{f(x - w / 2 + 0.2)},{f(yy)} Q{f(x - w / 4)},{f(yy - 1.4)} {f(x)},{f(yy)} Q{f(x + w / 4)},{f(yy - 1.4)} {f(x + w / 2 - 0.2)},{f(yy)}", 0.6 if dry else 0.8, 0.5 if dry else 0.9, "bark" if dry else br)
        if not dry:
            for sd in (-1, 1):
                for yy in (y - h * 0.62, y - h * 0.4):
                    p = (x + sd * w * 0.48, yy)
                    a.leaf(p[0], p[1], -90 + sd * 70, w * 0.55, 0.42, fc, lw=0.4, detail=False)
                    a.leaf(p[0], p[1], 90 - sd * 60 + (180 if sd < 0 else 0), w * 0.42, 0.6, fc, lw=0.4, detail=False)


def selfheal_stages():
    k = "selfheal"; fc = pal(k, "flower", "lilac"); br = pal(k, "centre", "plum")

    def mat(a, n=1.0, fill=None):
        qs = runners(a)
        for q in qs:   # pairs of leaves rising from the creeping stems
            for u in (0.25, 0.55, 0.85):
                p = q.pt(u)
                for sd in (-1, 1):
                    leaf(a, k, p[0], p[1] - 0.6, -90 + sd * 48, 12 * n, fill if (fill and u != 0.55) else None)
        leaf(a, k, 50, 87.5, -120, 13 * n, fill); leaf(a, k, 50, 87.5, -60, 13 * n, fill)

    def young():
        a = soil()
        with a.group():
            mat(a, 1.05)
        return a

    def heads(a, dry=False):
        for x, hh, lean in ((50, 30, 0), (35, 22, -4), (66, 24, 4), (25, 14, -3)):
            q = shoot(a, x, 87.5, x + lean, 88 - hh, 0, 1.6, 1.3, "straw" if dry else "leaf")
            leafy(a, k, q, (0.35,), 11, opp=True, spread=62, shrink=0, fill="straw" if dry else None)
            e = q.pt(0.97)
            for sd in (-1, 1):   # the pair of stalkless leaves right under the head
                leaf(a, k, e[0], e[1], -90 + sd * 72, 8, "straw" if dry else None, 0)
            head_square(a, e[0], e[1] - 0.4, 6.4, 9 if hh > 20 else 7, fc, br, dry)

    def flower():
        a = soil()
        with a.group():
            mat(a, 0.9); heads(a)
        return a

    def seedhead():
        a = soil()
        with a.group():
            mat(a, 0.85); heads(a, True)
        return a

    def dormant():
        a = soil()
        with a.group():
            mat(a, 0.8, fill="plum")
        return a

    return {"seed": sown(selfheal_seed),
            "seedling": lambda: seedling(k, ("round", 5.6, 5.0), ((-128, 10), (-52, 10)), h=8),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ sweet William
def sweetwilliam_seed(a, x, y):
    """Flat black seeds, oval to round, slightly rough."""
    def one(a, x, y, r, i):
        a.oval(x, y, 5.6, 4.6, r, "dark", 0.8)
        for j in range(5):
            p = T(x, y, r + j * 70)(2.2 * ((j * 0.618) % 1) + 0.6); a.dot(p[0], p[1], 0.35, "bark")
    seeds_at(a, x, y, THREE + [(-1, -7, 10)], one)


def flat_head(a, x, y, w, fc, eye="beet", dry=False):
    """A dense, slightly domed head of small flowers at plant scale, sitting
    straight on the top of the stem, w across. dry: a head of brown calyx
    tubes, the narrow capsules opening at their tips."""
    h = w * 0.36
    with a.on(BLOOM):
        dome = [(x - w / 2, y)] + [(x + w / 2 * math.cos(math.pi * (1 - i / 20)), y - h * math.sin(math.pi * i / 20)) for i in range(21)] + [(x, y + 1.2)]
        a.shape(path(dome), "bark" if dry else fc, 0.6)
        pts = []
        for r in range(3):   # three rows of flowers, the back row highest
            yy = y - h * (0.85 - r * 0.32); n = 3 + r; ww = w * (0.32 + 0.06 * r)
            for i in range(n):
                pts.append((x - ww + 2 * ww * (i + 0.5) / n + (r % 2) * 0.6, yy))
        for px, py in pts:
            if dry:
                a.ribbon((px, py + 1.6), (px, py), (px, py - 2.4), 1.6, 1.1, "bark", lw=0.4)
                a.line(f"M{f(px - 0.5)},{f(py - 2.4)} l0.5,-1 l0.5,1", 0.35, 0.85)
            else:
                pink5(a, px, py, w * 0.17, fc, eye, None, start=-90 + px * 7, M=tilt(py, 0.62), lw=0.35)


def sweetwilliam_stages():
    k = "sweet-william"; fc = pal(k, "flower", "berry"); eye = pal(k, "centre", "beet")

    def tuft(a, n=7, L=17):
        for dx in (-4, 0, 4):
            q = shoot(a, 50 + dx, 88, 50 + dx * 2, 82, 0, 1.6, 1.4)
            leafy(a, k, q, (0.4,), L, opp=True, spread=70, shrink=0)
        rosette(a, k, n=n, L=L)

    def young():
        a = soil()
        with a.group():
            tuft(a, 9, 20)
        return a

    def plant(a, dry=False):
        tuft(a, 7, 15)
        col = "bark" if dry else "leaf"
        for dx, hh, lean in ((-12, 0.78, -12), (12, 0.86, 12), (0, 1.0, 0)):
            q = shoot(a, 50 + dx * 0.4, 88, 50 + dx + lean, 88 - 62 * hh, 0, 2.0, 1.6, col)
            for u in (0.18, 0.4, 0.62):   # the swollen joints
                p = q.pt(u)
                with a.on(LEAF):
                    a.oval(p[0], p[1], 1.4, 0.9, 0, col, 0.5)
            leafy(a, k, q, (0.18, 0.4, 0.62), 13, opp=True, spread=48, shrink=0.4, fill="straw" if dry else None)
            e = q.pt(1)
            flat_head(a, e[0], e[1] + 0.6, 21, fc, eye, dry)

    def flower():
        a = soil()
        with a.group():
            plant(a)
        return a

    def seedhead():
        a = soil()
        with a.group():
            plant(a, True)
        return a

    return {"seed": sown(sweetwilliam_seed),
            "seedling": lambda: seedling(k, ("oval", 6.6, 2.6), ((-108, 11), (-72, 11)), h=9),
            "young": young, "flower": flower, "seedhead": seedhead}



# ============================================================ field poppy
def poppy_seed(a, x, y):
    """Tiny kidney-shaped dark grey seeds with a fine net pattern."""
    for i, (dx, dy, r) in enumerate(MANY[:10]):
        cx, cy = x + dx * 1.2, y + dy * 1.1; t = T(cx, cy, r)
        a.shape(f"M{P(t(-3, 0))} Q{P(t(-3, -3))} {P(t(0, -2.6))} Q{P(t(3, -3))} {P(t(3, 0))} Q{P(t(2.4, 2.6))} {P(t(0, 1.2))} Q{P(t(-2.4, 2.6))} {P(t(-3, 0))} Z", "dark", 0.6)
        a.line(f"M{P(t(-1.6, -1.6))} L{P(t(1.6, 0.6))} M{P(t(1.4, -1.8))} L{P(t(-1.2, 0.8))}", 0.35, 0.4, "white")


def mini_poppy(a, x, y, r, fc, blot="dark", lw=0.5):
    """A poppy at plant scale, facing up: a shallow bowl of four broad petals,
    the dark middle showing."""
    M = tilt(y, 0.55)
    for ang in (-140, -40):
        petal(a, x, y, ang, r, r * 1.2, fc, ROUND, M=M, lw=lw, lines=0, shade=0.12)
    a.oval(x, y - 0.4, r * 0.32, r * 0.18, 0, blot, 0.4)
    a.oval(x, y - 0.8, r * 0.14, r * 0.1, 0, "unripe", 0.35)
    for ang in (160, 20):
        petal(a, x, y + 0.6, ang, r * 1.05, r * 1.25, fc, ROUND, M=tilt(y + 0.6, 0.5), lw=lw, lines=0, shade=0.05)


def poppy_stages():
    k = "poppy"; fc = pal(k, "flower", "berry"); blot = pal(k, "centre", "dark")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=34, d=0)
        return a

    def plant(a, H, dry=False):
        """A branched stem: long thin hairy flower stalks leave it at different
        heights, one from each upper joint, with a cut leaf at each."""
        rosette(a, k, n=7, L=22, fill="straw" if dry else None, d=0)
        col = "straw" if dry else "leaf"
        q0 = shoot(a, 50, 88, 51, 88 - H, 0.5, 2.2, 1.0, col)
        hairs_along(a, q0, 0.3, 0.95, 12, 1.0, 70)
        leafy(a, k, q0, (0.22, 0.4, 0.58), 15, spread=50, shrink=0.4, fill="straw" if dry else None, d=0)
        tops = [q0]
        for u, sd, dx, top in ((0.28, -1, 22, 0.78), (0.44, 1, 20, 0.9), (0.6, -1, 10, 0.66)):
            p0 = q0.pt(u); x1 = p0[0] + sd * dx; y1 = 88 - H * top
            q = a.ribbon(p0, (p0[0] + sd * dx * 0.5, (p0[1] + y1) / 2), (x1, y1), 1.1, 0.8, col, lw=0.55)
            hairs_along(a, q, 0.1, 0.9, 7, 1.0, 70)
            tops.append(q)
        return tops

    def flower():
        a = soil()
        with a.group():
            tops = plant(a, 74)
            with a.on(BLOOM):
                for q in tops[:3]:
                    e = q.pt(1); mini_poppy(a, e[0], e[1] - 2.6, 8.4, fc, blot)
                q = tops[3]; e = q.pt(1)   # a hairy bud hanging down on its bent-over stalk
                hook = (e[0] - 3.4, e[1] + 1)
                a.line(f"M{P(e)} Q{f(e[0] - 2.6)},{f(e[1] - 3)} {P(hook)}", 0.6, 0.85)
                a.oval(hook[0], hook[1] + 2.8, 2.1, 2.9, 8, "leaf", 0.5)
                for j in range(6):
                    p = T(hook[0], hook[1] + 2.8, j * 60)(2.6); a.line(f"M{P(p)} L{P(T(hook[0], hook[1] + 2.8, j * 60)(3.5))}", 0.35, 0.55)
        return a

    def seedhead():
        a = soil()
        with a.group():
            tops = plant(a, 70, dry=True)
            with a.on(BLOOM):
                for q in tops:
                    e = q.pt(1)
                    a.oval(e[0], e[1] - 3.2, 3.0, 3.6, 0, "seed", 0.6)            # the round capsule
                    a.oval(e[0], e[1] - 6.6, 3.2, 1.0, 0, "bark", 0.5)            # its flat lid
                    for j in range(5):
                        a.line(f"M{f(e[0])},{f(e[1] - 6.6)} L{f(e[0] + (j - 2) * 1.3)},{f(e[1] - 6.6 + 0.6 * (1 - abs(j - 2) / 2))}", 0.35, 0.8)
                    for j in range(4):   # the ring of holes under the lid
                        a.dot(e[0] - 1.8 + j * 1.2, e[1] - 5.4, 0.3, "dark")
        return a

    return {"seed": sown(poppy_seed),
            "seedling": lambda: seedling(k, ("strap", 9, 1.7), ((-100, 9),), h=3, spread=70,
                                         tleaf=first_leaf(pal(k, "leaf", "leaf"), prof(0.7, "taper", "round", bp=1.2, tp=2.0), 0.5, 0.25,
                                                          teeth=3, td=1.2, tk="blunt")),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ Californian poppy
def calpoppy_seed(a, x, y):
    """Small round grey-brown seeds, finely netted."""
    def one(a, x, y, r, i):
        a.oval(x, y, 3.6, 3.4, 0, "bark", 0.7)
        a.line(f"M{f(x - 2)},{f(y - 0.8)} L{f(x + 2)},{f(y - 0.8)} M{f(x - 2)},{f(y + 1)} L{f(x + 2)},{f(y + 1)} M{f(x - 0.6)},{f(y - 2.6)} L{f(x - 0.6)},{f(y + 2.6)}", 0.3, 0.4)
    seeds_at(a, x, y, [(-10, 0, 0), (-2, -6, 0), (7, -2, 0), (2, 6, 0), (11, 6, 0), (-8, 8, 0)], one)


def calpoppy_stages():
    k = "california-poppy"; fc = pal(k, "flower", "carrot"); fill = pal(k, "leaf", "sage")

    def mound(a, n=11, L=26, fill_=None):
        rosette(a, k, n=n, L=L, fill=fill_)
        for g in (-150, -30):
            leaf(a, k, 50, 88, g, L * 0.9, fill_)

    def young():
        a = soil()
        with a.group():
            mound(a, 11, 26)
        return a

    def flower():
        a = soil()
        with a.group():
            mound(a, 11, 30)
            with a.on(BLOOM):
                for x, y, ang, r in ((32, 44, -14, 6.4), (52, 34, 0, 7.0), (70, 46, 12, 6.0)):   # cups on bare stalks
                    a.line(f"M50,86 Q{f((50 + x) / 2)},{f(y + 18)} {f(x)},{f(y + 3)}", 0.8, 0.85, "line")
                    a.oval(x, y + 2.6, 2.0, 0.8, 0, "pink", 0.4)
                    for o, l in ((-24, 1.0), (24, 1.0), (0, 1.08)):
                        petal(a, x, y + 2.4, -90 + ang + o, r * l, r * 1.0, fc, FAN, lw=0.5, lines=0, shade=0.08)
                a.line("M52,86 Q60,66 62,56", 0.7, 0.85)   # a bud in its pointed cap
                a.leaf(62, 56, -84, 6, 0.36, "pale", lw=0.45, detail=False)
        return a

    def seedhead():
        a = soil()
        with a.group():
            mound(a, 9, 26, "sage")
            with a.on(BLOOM):
                for ang, st, L in ((-118, 24, 20), (-100, 30, 24), (-82, 28, 24), (-64, 22, 20)):   # long thin ribbed pods on bare stalks
                    e = T(50, 86, ang)(st)
                    with a.on(STEM):
                        a.line(f"M50,86 L{P(e)}", 0.8, 0.85)
                    pod(a, e[0], e[1], ang, L, 1.8, "straw", ribs=0)
                    for o in (-0.35, 0.35):
                        a.line(opath([T(*e, ang)(L * u, o) for u in (0.1, 0.5, 0.88)]), 0.35, 0.5)
        return a

    return {"seed": sown(calpoppy_seed),
            "seedling": lambda: seedling(k, ("split", 9, 1.4), ((-90, 10),), h=8, spread=62),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ borage
def borage_seed(a, x, y):
    """Oblong, ridged and wrinkled dark seeds, a pale collar at one end."""
    def one(a, x, y, r, i):
        seed_oval(a, x, y, r, 11, 5.6, "dark", rib=3, line=False)
        e = T(x, y, r)(-5); a.oval(e[0], e[1], 1.6, 2.4, r, "straw", 0.6)
    seeds_at(a, x, y, THREE, one)


def nod_star(a, x, y, r, fc, cen="dark", lw=0.45):
    """A borage flower at plant scale, hanging face down, seen from the side:
    the pointed blue petals spread out and down, the black cone of anthers
    pointing at the ground."""
    for off in (-62, 62, -24, 24):
        a.leaf(x, y, 90 + off, r, 0.42, fc, lw=lw, skew=0.42, detail=False)
    a.leaf(x, y, 270, r * 0.4, 0.5, "leaf", lw=lw, detail=False)
    a.leaf(x, y, 90, r * 0.62, 0.36, cen, lw=lw, detail=False)


def mini_star(a, x, y, r, fc, ang=90, cen="dark", lw=0.45):
    """A borage flower at plant scale, hanging face down or out."""
    M = tilt(y, 0.6 if abs(ang - 90) < 30 else 0.85)
    for i in range(5):
        a.leaf(x, y, ang - 90 + 72 * i - 90, r, 0.42, fc, lw=lw, skew=0.4, detail=False)
    a.dot(x, y, max(0.5, r * 0.22), cen)


def borage_stages():
    k = "borage"; fc = pal(k, "flower", "blue"); cen = pal(k, "centre", "dark")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=30)
        return a

    def plant(a, dry=False):
        """A coarse, branched, leafy plant: a thick bristly main stem with
        branches from its upper joints, leaves all the way up, every branch
        ending in an arching tip that bends the flower cluster down."""
        lf = "straw" if dry else None; sc = "straw" if dry else "leaf"
        rosette(a, k, n=5, L=24, fill=lf)
        q = shoot(a, 50, 88, 51, 30, 0.6, 3.4, 2.0, sc)
        hairs_along(a, q, 0.05, 0.95, 20, 1.3, 65)
        leafy(a, k, q, (0.12, 0.26, 0.4, 0.55), 20, spread=56, shrink=0.5, fill=lf)
        tips = [q]
        for u, sd, dx, hh in ((0.36, -1, 22, 34), (0.42, 1, 22, 36), (0.58, -1, 14, 26), (0.64, 1, 15, 24)):
            b = q.pt(u); e = (b[0] + sd * dx, b[1] - hh)
            bq = a.ribbon(b, (b[0] + sd * dx * 0.3, b[1] - hh * 0.6), e, 2.2, 1.3, sc, lw=0.7)
            hairs_along(a, bq, 0.1, 0.9, 8, 1.1, 65)
            leafy(a, k, bq, (0.4, 0.75), 13, spread=50, shrink=0.3, fill=lf)
            tips.append(bq)
        return tips

    def cluster(a, q, dry=False):
        """The arching tip of a branch, bent over, with its hanging flowers."""
        e = q.pt(1); ang = q.ang(1); sd = 1 if math.cos(math.radians(ang)) >= 0 else -1
        hook = (e[0] + sd * 5, e[1] + 1)
        a.line(f"M{P(e)} Q{f(e[0] + sd * 3)},{f(e[1] - 3)} {P(hook)}", 0.9, 0.85)
        for j, (dx, dy) in enumerate(((-3, 3), (2, 5), (6, 3), (0, 9), (5, 9))):
            h = (hook[0] + sd * dx, hook[1] + dy)
            a.line(f"M{P(hook)} Q{f(hook[0] + sd * dx * 0.5)},{f(hook[1])} {f(h[0])},{f(h[1] - 1.5)}", 0.5, 0.85)
            if dry:   # the calyx closed up over the seeds, bristly, hanging
                capsule(a, h[0], h[1] - 1.5, 90, 5.2, 3.6, "unripe", lw=0.45)
                for o in (-1, 1):
                    a.line(f"M{f(h[0] + o * 1.6)},{f(h[1] + 1)} l{f(o * 1.2)},0.5", 0.35, 0.6)
                a.dot(h[0], h[1] + 3.2, 0.75, "dark")
            elif j in (1, 3):
                a.oval(h[0], h[1], 1.4, 1.9, 0, "pink", 0.45)   # pink buds
            else:
                nod_star(a, h[0], h[1], 4.6, fc, cen)

    def flower():
        a = soil()
        with a.group():
            tips = plant(a)
            with a.on(BLOOM):
                for q in tips:
                    cluster(a, q)
        return a

    def seedhead():
        a = soil()
        with a.group():
            tips = plant(a, True)
            with a.on(BLOOM):
                for q in tips:
                    cluster(a, q, True)
        return a

    return {"seed": sown(borage_seed),
            "seedling": lambda: seedling(k, ("oval", 9.5, 7), ((-96, 10),), h=7, spread=80,
                                         tleaf=first_leaf(pal(k, "leaf", "deep"), prof(0.45, "round", "blunt", bp=0.5, tp=1.6), 0.55, 0.2, felt=18)),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ Russian comfrey
def comfrey_stages():
    k = "russian-comfrey"; fc = pal(k, "flower", "mauve")

    def crown(a):
        with a.on(STEM):
            a.polar(50, 89.5, lambda h: 1 + 0.08 * math.cos(5 * h), 7, 3, 0, "dark", 0.8)

    def young():
        a = soil()
        with a.group():
            crown(a); rosette(a, k, n=9, L=34)
        return a

    def crop():
        a = soil()
        with a.group():
            crown(a); rosette(a, k, n=11, L=44)
            for g in (-140, -40):
                leaf(a, k, 50, 88, g, 42)
        return a

    def flower():
        a = soil()
        with a.group():
            crown(a); rosette(a, k, n=9, L=30)
            for dx, hh, lean in ((-9, 0.84, -10), (8, 1.0, 9)):
                # a stout, hairy, leafy stem, branching in its upper part
                q = shoot(a, 50 + dx * 0.3, 88, 50 + dx + lean, 88 - 66 * hh, 0, 3.4, 2.2)
                hairs_along(a, q, 0.2, 0.95, 12, 1.4, 60)
                leafy(a, k, q, (0.35, 0.5, 0.64), 17, spread=48, shrink=0.4)
                tips = [q]
                for u, sg in ((0.74, -1), (0.84, 1)):
                    b = q.pt(u); e = (b[0] + sg * 11, b[1] - 9)
                    bq = a.ribbon(b, (b[0] + sg * 4, b[1] - 6), e, 1.8, 1.2, "leaf", lw=0.6)
                    leaf(a, k, *bq.pt(0.4), -90 + sg * 60, 9)
                    tips.append(bq)
                with a.on(BLOOM):   # each branch ends in a curled one-sided cluster of hanging bells
                    for t_ in tips:
                        e = t_.pt(1); sd = 1 if t_.ang(1) > -90 else -1
                        cq = Quad(e, (e[0] + sd * 8, e[1] - 6), (e[0] + sd * 12, e[1] + 1))
                        a.line(f"M{P(cq.p0)} Q{P(cq.c)} {P(cq.p1)} q{f(sd * 0.6)},2.4 {f(-sd * 2)},2", 1.0, 0.85)
                        for j, u in enumerate((0.2, 0.45, 0.68, 0.9)):
                            p = cq.pt(u)
                            if j < 3:
                                comfrey_bell(a, p[0], p[1] + 0.4, 90 - sd * 12, 8.0, 4.4, fc if j < 2 else "pink", lw=0.5)
                            else:
                                a.oval(p[0], p[1] + 1.6, 1.4, 2.0, 0, "pink", 0.45)
        return a

    def dormant():
        a = soil()
        with a.group():
            crown(a)
            for g, L in ((-110, 7), (-75, 6)):   # perhaps a few small new leaves in a mild spell
                leaf(a, k, 50, 87, g, L)
        return a

    return {"young": young, "crop": crop, "flower": flower, "dormant": dormant}


# ============================================================ lungwort
def lungwort_stages():
    k = "lungwort"; fc = pal(k, "flower", "blue")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=32)
        return a

    def flower():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=22)
            for dx, hh, lean in ((-8, 30, -8), (6, 36, 6), (16, 26, 14)):
                q = shoot(a, 50 + dx * 0.4, 88, 50 + dx + lean, 88 - hh, 0, 1.8, 1.4)
                leafy(a, k, q, (0.35, 0.6), 11, spread=48, shrink=0.2, d=0)
                e = q.pt(1)
                with a.on(BLOOM):
                    for j, (o, col) in enumerate(((-60, "pink"), (-20, fc), (25, "mauve"), (60, fc), (0, "pink"))):
                        p = T(*e, -90 + o)(4 + (j % 2))
                        a.line(f"M{P(e)} L{P(p)}", 0.45, 0.85)
                        funnel5(a, p[0], p[1], -90 + o * 1.3, 0.58, col, "leaf", 0.7, lw=0.4)
        return a

    def dormant():
        a = soil()
        with a.group():
            for g, L in ((-160, 18), (-20, 16)):   # a few spotted leaves left lying
                leaf(a, k, 50, 88, g, L)
            for dx, hh in ((-2, 9), (3, 11)):   # new flower shoots, pink-tipped
                q = shoot(a, 50 + dx, 88, 50 + dx * 1.6, 88 - hh, 0, 1.6, 1.3)
                e = q.pt(1); a.oval(e[0], e[1] - 1.2, 1.6, 2.2, 0, "pink", 0.45)
                leaf(a, k, *q.pt(0.5), -90 + dx * 14, 6, None, 0)
        return a

    return {"young": young, "flower": flower, "dormant": dormant}


# ============================================================ cowslip
def cowslip_seed(a, x, y):
    """Small dark brown angular, warty seeds."""
    for i, (dx, dy, r) in enumerate(MANY[:9]):
        pts = [T(x + dx * 1.2, y + dy * 1.1, r + j * 90 + (j * 17 % 25))(3.0 + 0.8 * ((j + i) % 2)) for j in range(4)]
        a.shape(path(pts), "dark", 0.6)
        a.dot(x + dx * 1.2, y + dy * 1.1, 0.45, "bark")


def cowslip_stages():
    k = "native-cowslip"; fc = pal(k, "flower", "sun"); spot = pal(k, "centre", "carrot")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=28, flat=0.4)
        return a

    def scapes(a, dry=False):
        for x1, H, lean in ((44, 52, -6), (56, 58, 5), (64, 44, 12)):
            q = shoot(a, 50 + (x1 - 50) * 0.2, 88, x1 + lean, 88 - H, 0, 1.8, 1.4, "straw" if dry else "leaf")
            hairs_along(a, q, 0.1, 0.9, 8, 0.9, 70)
            e = q.pt(1)
            with a.on(BLOOM):
                for j, o in enumerate((-40, -10, 20, 50, 80, 5)):
                    if dry:   # upright clusters of papery, inflated calyces, straw-brown
                        p = T(*e, -90 + o * 0.7)(3.0)
                        a.line(f"M{P(e)} L{P(p)}", 0.5, 0.85)
                        capsule(a, p[0], p[1], -90 + o * 0.7, 8.4, 5.0, "seed", lw=0.5)
                        a.line(opath([T(*p, -90 + o * 0.7)(8.4 * u, 0) for u in (0.15, 0.55, 0.9)]), 0.35, 0.45)
                    else:     # a drooping one-sided cluster
                        p = T(*e, o)(3.2)
                        a.line(f"M{P(e)} L{P(p)}", 0.5, 0.85)
                        cowslip_flower(a, p[0], p[1], 76 + o * 0.15, 0.62, fc, "pale", spot, 0.6 if j % 2 else 0.9)

    def flower():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=26, flat=0.4); scapes(a)
        return a

    def seedhead():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=22, flat=0.4); scapes(a, True)
        return a

    def dormant():
        a = soil()
        with a.group():
            rosette(a, k, n=5, L=16, flat=0.5)
        return a

    return {"seed": sown(cowslip_seed),
            "seedling": lambda: seedling(k, ("round", 4, 3.6), ((-160, 11), (-20, 11), (-112, 9)), h=4, spread=82,
                                         tleaf=first_leaf(pal(k, "leaf", "leaf"), prof(0.68, "taper", "round", bp=1.2, tp=2.2), 0.62, 0.15, pucker=True, wave=0.4, nw=4)),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ geum
def geum_seed(a, x, y):
    """Small flat brown seeds, each with a long bristly tail hooked at the end."""
    for dx, dy, r in ((-10, 4, -60), (2, 6, -80), (12, 2, -110)):
        cx, cy = x + dx, y + dy
        a.oval(cx, cy, 2.6, 3.6, r + 90, "bark", 0.7)
        t = T(cx, cy, r); e = t(16)
        a.line(f"M{P(t(3))} Q{P(t(9, 1.4))} {P(e)} q{f(2 * math.cos(math.radians(r + 90)))},{f(2 * math.sin(math.radians(r + 90)))} {f(0.6)},{f(2.6)}", 0.8, 0.85)
        for u in (0.4, 0.6, 0.8):
            p = t(16 * u); a.line(f"M{P(p)} L{P(T(*p, r + 50)(1.4))}", 0.35, 0.55)


def geum_stages():
    k = "geum"; fc = pal(k, "flower", "berry"); cen = pal(k, "centre", "primrose")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=40, skip=(-136, -44))
        return a

    def wiry(a, dry=False):
        """A thin wiry stem that forks loosely, and forks again: each fork
        ends in a flower (or a bud)."""
        tops = []
        q0 = shoot(a, 50, 88, 49, 54, 0.6, 1.4, 1.0, "leaf", lw=0.6)
        leafy(a, k, q0, (0.45,), 9, spread=50, d=0)
        forks = [((49, 54), (36, 38), [(28, 24), (40, 22)]), ((49, 54), (62, 40), [(58, 16), (76, 30)])]
        for p0, b, ends in forks:
            a.ribbon(p0, ((p0[0] + b[0]) / 2, (p0[1] + b[1]) / 2 + 1), b, 1.0, 0.8, "leaf", lw=0.5)
            leaf(a, k, b[0], b[1], -90 + (b[0] - 50) * 4, 6, None, 0)   # a small stem leaf at the fork
            for x1, y1 in ends:
                q = a.ribbon(b, ((b[0] + x1) / 2 + 1, (b[1] + y1) / 2 + 1.5), (x1, y1), 0.8, 0.6, "leaf", lw=0.5)
                hairs_along(a, q, 0.15, 0.9, 5, 0.8, 70)
                tops.append(q)
        return tops

    def flower():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=32, skip=(-136, -44))
            tops = wiry(a)
            with a.on(BLOOM):
                for j, q in enumerate(tops):
                    e = q.pt(1)
                    if j == 1:
                        a.oval(e[0], e[1], 2.2, 2.3, 0, "leaf", 0.5); continue   # a round bud
                    M = tilt(e[1], 0.6)
                    for r_, st in ((8.4, -90), (6.6, -60)):
                        for i in range(6):
                            petal(a, e[0], e[1], st + 60 * i, r_, r_ * 0.95, fc, ROUND, M=M, lw=0.4, lines=0, shade=0.06)
                    a.oval(e[0], e[1], 2.2, 1.4, 0, cen, 0.4)
        return a

    def seedhead():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=30, skip=(-136, -44))
            tops = wiry(a, True)
            with a.on(BLOOM):
                for q in tops:   # compact round bristly burrs of hooked seeds, reddish brown
                    e = q.pt(1); c = (e[0], e[1] - 2.6)
                    for j in range(18):
                        p = T(*c, j * 20)(4.0)
                        a.line(f"M{P(c)} L{P(p)} l{f(0.6 * math.cos(math.radians(j * 20 + 90)))},{f(0.6 * math.sin(math.radians(j * 20 + 90)))}", 0.5, 0.85, "rust")
                    a.oval(c[0], c[1], 2.9, 2.9, 0, "rust", 0.5)
                    for j in range(7):
                        p = T(*c, j * 51)(1.6); a.dot(p[0], p[1], 0.4, "bark")
        return a

    def dormant():
        a = soil()
        with a.group():
            for i, g in enumerate(ROS[:7]):
                leaf(a, k, 50, 88, g, 30 * (0.75 + 0.25 * (1 - abs(g + 90) / 90)), "rust" if i % 3 == 0 else None)
        return a

    return {"seed": sown(geum_seed),
            "seedling": lambda: seedling(k, ("round", 4.8, 4.2), ((-112, 10), (-68, 8)), h=7,
                                         tleaf=lambda a, x, y, g, l: round_leaf(a, x, y, g, l, pal(k, "leaf", "leaf"))),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


def round_leaf(a, x, y, g, l, fill):
    """A seedling's first leaf: rounded and scalloped, on a long stalk."""
    with a.on(LEAF):
        simple_leaf(a, x, y, g, l, fill, 1, petiole=0.45, W=0.95, pf=prof(0.5, "round", "round", bp=0.4, tp=2.0), back=0.06,
                    teeth=7, td=l * 0.03, tk="round", veins=0, midw=0.4)


# ============================================================ viola
def viola_seed(a, x, y):
    """Small, oval, smooth, glossy tan seeds."""
    seeds_at(a, x, y, THREE + [(-2, -7, 120)], lambda a, x, y, r, i: seed_oval(a, x, y, r, 8, 5, "seed", gloss=True))


def mini_pansy(a, x, y, r, fc, lip=None, lw=0.45):
    """A pansy face at plant scale."""
    for ang in (-120, -60):
        a.leaf(x, y, ang, r, 0.8, fc, lw=lw, skew=0.5, detail=False)
    for ang in (165, 15):
        a.leaf(x, y, ang, r * 0.9, 0.8, fc, lw=lw, skew=0.5, detail=False)
    a.leaf(x, y, 90, r * 1.05, 0.95, lip or fc, lw=lw, skew=0.5, detail=False)
    for o in (-20, 0, 20):
        e = T(x, y, 90 + o)(r * 0.45); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.4, 0.9, "dark")
    a.dot(x, y + 0.3, max(0.4, r * 0.14), "sun")


def viola_stages():
    k = "viola"; fc = pal(k, "flower", "lilac")

    def tuft(a, L=17, n=7):
        for dx, hh, lean in ((-14, 8, -14), (12, 9, 13), (-5, 13, -4), (5, 12, 5), (0, 9, 0), (-20, 5, -16), (20, 5, 16))[:n]:
            q = shoot(a, 50 + dx * 0.2, 88, 50 + dx + lean, 88 - hh, 0, 1.4, 1.0)
            leafy(a, k, q, (0.4, 0.95), L, spread=50, shrink=0.2)

    def young():
        a = soil()
        with a.group():
            tuft(a, 18)
        return a

    def flower():
        a = soil()
        with a.group():
            tuft(a, 17, 7)
            with a.on(BLOOM):
                for x, y, sd in ((30, 44, -1), (52, 36, 1), (72, 48, 1)):   # held up on long stalks bent over like a hook
                    hx, hy = x + sd * 5, y - 8
                    a.line(f"M50,84 Q{f((50 + hx) / 2)},{f(y + 14)} {f(hx)},{f(hy)} Q{f(hx)},{f(hy - 4)} {f(x + sd * 2)},{f(y - 4)}", 0.7, 0.85)
                    mini_pansy(a, x, y, 7.2, fc, None)
        return a

    def seedhead():
        a = soil()
        with a.group():
            tuft(a, 15)
            with a.on(BLOOM):
                for j, (x, y) in enumerate(((32, 56), (50, 48), (68, 58))):
                    a.line(f"M50,84 Q{f((50 + x) / 2)},{f(y + 12)} {f(x)},{f(y + 4)}", 0.7, 0.85)
                    if j == 1:   # split into three boat-shaped valves
                        for o in (-40, 0, 40):
                            a.leaf(x, y + 3, -90 + o, 6, 0.45, "straw", lw=0.5, detail=False)
                            p = T(x, y + 3, -90 + o)(3.4); a.dot(p[0], p[1], 0.5, "seed")
                    else:
                        capsule(a, x, y + 4, -90, 6.4, 4.4, "unripe", lw=0.5)
                        a.line(f"M{f(x)},{f(y + 2)} L{f(x)},{f(y - 1.6)}", 0.35, 0.5)
        return a

    def dormant():
        a = soil()
        with a.group():
            tuft(a, 12, 4)
        return a

    return {"seed": sown(viola_seed),
            "seedling": lambda: seedling(k, ("round", 5.2, 4.6), ((-116, 9), (-64, 8)), h=8,
                                         tleaf=lambda a, x, y, g, l: round_leaf(a, x, y, g, l, pal(k, "leaf", "leaf"))),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}



# ============================================================ aubrieta
def stone(a, x0, x1, y, h):
    """A rock or the top of a low wall, for a plant to spill over."""
    with a.on(STEM):
        a.shape(f"M{f(x0)},{f(y)} Q{f(x0 + 1)},{f(y - h)} {f(x0 + (x1 - x0) * 0.4)},{f(y - h * 1.05)} Q{f(x1 - 2)},{f(y - h)} {f(x1)},{f(y - h * 0.4)} L{f(x1)},{f(y)} Z", "straw", 0.9)
        a.line(f"M{f(x0 + 4)},{f(y - h * 0.5)} q4,-1 7,1", 0.6, 0.4)


def aub_mat(a, k, fill=None, cover=1.0, y=88, x0=14, x1=66, h=13):
    """The mat: small rosettes of spoon-shaped leaves crowded over the ground
    and spilling down over the stone on the right."""
    spots = []
    with a.on(STEM):   # the cushion itself, under its leaves
        pts = [(x0 - 2, y)] + [(x0 + (x1 + 2 - x0) * (j / 20), y - h * math.sin(math.pi * min(1, j / 20 * 1.1)) ** 0.7) for j in range(21)] + [(x1 + 2, y)]
        a.shape(path(pts), fill or k and pal(k, "leaf", "sage"), 0.7)
        a.shape(path(pts), "shade", 0, fa=0.12)
    for j in range(15):
        u = j / 14; x = x0 + (x1 - x0) * u
        yy = y - h * math.sin(math.pi * min(1, u * 1.15)) ** 0.7 + 1
        spots.append((x, yy))
        if 0.15 < u < 0.85:
            spots.append((x + 1.5, yy + h * 0.45))
    for j in range(5):   # trailing down the face of the stone
        spots.append((70 + j * 3.2, 70 + j * 3.4))
    for i, (x, yy) in enumerate(spots):
        for g in (-150, -30, -110, -70, -90):
            leaf(a, k, x, yy, g + (i % 3 - 1) * 10, 6.4 * cover, fill, 0)


def aubrieta_stages():
    k = "aubrieta"; fc = pal(k, "flower", "mauve")

    def young():
        a = soil()
        with a.group():
            stone(a, 66, 94, 88, 20)
            aub_mat(a, k, cover=0.95, x1=58, h=10)
        return a

    def flower():
        a = soil()
        with a.group():
            stone(a, 66, 94, 88, 20)
            aub_mat(a, k)
            with a.on(BLOOM):
                pts = [(16 + j * 4.3, 82 - 11 * math.sin(math.pi * min(1, j / 13 * 1.1)) ** 0.7 - 2 * ((j * 7) % 3)) for j in range(14)]
                pts += [(70 + j * 3.4, 66 + j * 3.6) for j in range(5)] + [(30, 72), (44, 70), (56, 73), (38, 66)]
                for j, (x, y) in enumerate(pts):
                    cross4(a, x, y - 2, 4.0, fc, tilt(y - 2, 0.8), -45 + j * 17, veins=None, cen="primrose", lw=0.45)
        return a

    def seedhead():
        a = soil()
        with a.group():
            stone(a, 66, 94, 88, 20)
            aub_mat(a, k)
            with a.on(BLOOM):
                for j in range(9):   # small upright hairy pods with a beak
                    x = 20 + j * 5.4; y = 78 - 8 * math.sin(math.pi * j / 8)
                    a.line(f"M{f(x)},{f(y + 2)} L{f(x + 0.6)},{f(y - 3)}", 0.5, 0.85)
                    capsule(a, x + 0.6, y - 3, -86 + (j % 3 - 1) * 8, 6, 2.6, "straw", beak=0.3, lw=0.45)
        return a

    def dormant():
        a = soil()
        with a.group():
            stone(a, 66, 94, 88, 20)
            aub_mat(a, k, cover=0.9, h=11)
        return a

    return {"young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ scarlet flax
def linum_seed(a, x, y):
    """Flat, oval, glossy brown seeds, pointed at one end."""
    def one(a, x, y, r, i):
        t = T(x, y, r)
        a.shape(f"M{P(t(-5, 0))} Q{P(t(-4.6, -3.4))} {P(t(0, -3.2))} Q{P(t(4, -2.6))} {P(t(6, 0))} Q{P(t(4, 2.6))} {P(t(0, 3.2))} Q{P(t(-4.6, 3.4))} {P(t(-5, 0))} Z", "bark", 0.8)
        a.line(f"M{P(t(-2.6, -1.6))} L{P(t(1.4, -1.8))}", 0.7, 0.6, "white")
    seeds_at(a, x, y, THREE, one)


def linum_seedling(k):
    """Two small oval, bluish seed leaves, then narrow pointed true leaves up a
    thin stem."""
    a = seedling(k, ("oval", 5, 3.2), (), h=6)
    top = G - 6 * 2.1
    with a.group():
        q = a.ribbon((50, top), (50.4, top - 8), (50, top - 18), 1.4, 1.0, "leaf", lw=0.6)
        leafy(a, k, q, (0.25, 0.45, 0.62, 0.78), 11, spread=34, shrink=0.2, d=1, tip=True)
    return a


def linum_stages():
    k = "linum"; fc = pal(k, "flower", "berry"); cen = pal(k, "centre", "dark")

    def stems(a, H, n=5, flowers=None, caps=False):
        for j, (dx, hh, lean) in enumerate(((-18, 0.74, -20), (2, 1.0, 2), (17, 0.84, 20), (-6, 0.9, -9))[:n]):
            q = shoot(a, 50 + dx * 0.2, 88, 50 + dx + lean, 88 - H * hh, 0, 1.2, 0.7, lw=0.55)
            leafy(a, k, q, [0.08 + 0.07 * i for i in range(9)], 8, spread=34, shrink=0.3, d=0)
            if flowers or caps:   # branching near the top, a flower at each tip
                e = q.pt(0.66)
                for o, l in ((-44, 14), (36, 15)):
                    t = T(*e, -90 + o)(l)
                    with a.on(STEM):
                        a.line(f"M{P(e)} Q{P(T(*e, -90 + o * 0.5)(l * 0.6))} {P(t)}", 0.55, 0.85)
                with a.on(BLOOM):
                    for p in (q.pt(1), T(*e, -134)(14), T(*e, -54)(15)):
                        if caps:
                            capsule(a, p[0], p[1], -90, 3.8, 3.2, "straw", beak=0.25, lw=0.45)
                        else:
                            M = tilt(p[1] - 2, 0.6)
                            for i in range(5):
                                petal(a, p[0], p[1] - 2, -90 + 72 * i, 6.0, 6.4, fc, FAN, M=M, lw=0.4, lines=0, shade=0.06)
                            a.dot(p[0], p[1] - 2, 1.2, cen)

    def young():
        a = soil()
        with a.group():
            stems(a, 40, 4)
        return a

    def flower():
        a = soil()
        with a.group():
            stems(a, 72, 4, flowers=True)
        return a

    def seedhead():
        a = soil()
        with a.group():
            stems(a, 68, 4, caps=True)
        return a

    return {"seed": sown(linum_seed),
            "seedling": lambda: linum_seedling(k),
            "young": young, "flower": flower, "seedhead": seedhead}


# ============================================================ marshmallow
def marshmallow_seed(a, x, y):
    """Small kidney-shaped brown seeds."""
    def one(a, x, y, r, i):
        t = T(x, y, r)
        a.shape(f"M{P(t(-4, 0))} Q{P(t(-4, -4))} {P(t(0, -3.6))} Q{P(t(4, -4))} {P(t(4, 0))} Q{P(t(3.4, 3.6))} {P(t(0, 1.4))} Q{P(t(-3.4, 3.6))} {P(t(-4, 0))} Z", "bark", 0.8)
    seeds_at(a, x, y, THREE + [(-1, -8, 200)], one)


def cheese(a, x, y, r, fill="seed"):
    """A marshmallow fruit: a flat round ring of segments like a small cheese,
    in its calyx."""
    for o in (-40, 0, 40):
        a.leaf(x, y + 0.6, 90 + o, r * 1.2, 0.4, "straw" if fill != "unripe" else "sage", lw=0.4, detail=False)
    a.oval(x, y, r, r * 0.55, 0, fill, 0.45)
    for k in range(7):
        a.line(f"M{f(x)},{f(y)} L{f(x + r * math.cos(k * 0.45 + 0.2) * 0.95)},{f(y - r * 0.5 * math.sin(k * 0.45 + 0.2))}", 0.35, 0.5)


def marshmallow_stages():
    k = "marshmallow"; fc = pal(k, "flower", "pink"); anth = pal(k, "centre", "beet"); lc = pal(k, "leaf", "sage")

    def stems(a, H, n=3, dry=False, fl=None):
        qs = []
        for dx, hh, lean in ((-8, 0.86, -10), (0, 1.0, 0), (9, 0.92, 9))[:n]:
            q = shoot(a, 50 + dx * 0.3, 88, 50 + dx + lean, 88 - H * hh, 0, 2.4, 1.2, "straw" if dry else "sage")
            leafy(a, k, q, [0.1 + 0.12 * i for i in range(7)], 13, spread=50, shrink=0.55, fill="straw" if dry else None)
            qs.append(q)
            if fl:
                with a.on(BLOOM):
                    for j, u in enumerate((0.55, 0.66, 0.77, 0.88, 1.0)):
                        x, y = q.pt(u); sd = -1 if j % 2 else 1
                        fl(a, x + sd * 2.6, y - 1.2, sd, j)
        return qs

    def young():
        a = soil()
        with a.group():
            stems(a, 44)
        return a

    def flower():
        def fl(a, x, y, sd, j):
            M = tilt(y, 0.75)
            for i in range(5):
                petal(a, x, y, -90 + 72 * i + j * 13, 4.4, 4.2, fc, FAN, M=M, lw=0.4, lines=0, shade=0.05)
            a.dot(x, y, 0.8, anth)
            if j % 2:
                p = (x + sd * 3.4, y + 1.6); a.oval(p[0], p[1], 1.2, 1.5, 0, lc, 0.4)
        a = soil()
        with a.group():
            stems(a, 78, fl=fl)
        return a

    def seedhead():
        a = soil()
        with a.group():
            stems(a, 74, dry=True, fl=lambda a, x, y, sd, j: cheese(a, x, y, 2.2, "seed"))
        return a

    def dormant():
        a = soil()
        with a.group():
            for dx, hh, lean in ((-8, 44, -6), (0, 56, 0), (8, 48, 6)):   # brown dead stems
                q = shoot(a, 50 + dx * 0.3, 88, 50 + dx + lean, 88 - hh, 0, 2.0, 1.1, "straw")
                for u in (0.3, 0.5, 0.7):
                    p = q.pt(u); a.line(f"M{P(p)} l{f(2.4 if u != 0.5 else -2.4)},-1.6", 0.6, 0.8)
        return a

    return {"seed": sown(marshmallow_seed),
            "seedling": lambda: seedling(k, ("kidney", 5.6, 6), ((-100, 9),), h=9,
                                         tleaf=lambda a, x, y, g, l: round_leaf(a, x, y, g, l, lc)),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ St John's-wort
def sjw_seed(a, x, y):
    """Tiny cylindrical dark brown seeds, finely pitted."""
    for i, (dx, dy, r) in enumerate(MANY[:9]):
        cx, cy = x + dx * 1.2, y + dy * 1.1
        t = T(cx, cy, r)
        a.shape(path([t(-2.4, -1.0), t(2.4, -1.0), t(2.9, 0), t(2.4, 1.0), t(-2.4, 1.0), t(-2.9, 0)]), "dark", 0.6)   # a little cylinder
        for j in (-1, 0, 1):
            p = t(j * 1.5, -0.2); a.dot(p[0], p[1], 0.3, "bark")


def sjw_stages():
    k = "perforate-st-john-s-wort"; fc = pal(k, "flower", "sun"); fr = pal(k, "fruit", "rust")

    def stems(a, H, n=3, top=None, col="leaf", fill=None):
        for dx, hh, lean in ((-10, 0.86, -9), (0, 1.0, 0), (10, 0.9, 9))[:n]:
            # with a flower head the stem ends where it branches, so nothing rises above the head
            q = shoot(a, 50 + dx * 0.3, 88, 50 + dx + lean, 88 - H * hh * (0.8 if top else 1.0), 0, 1.8, 1.0, col)
            leafy(a, k, q, [0.08 + 0.12 * i for i in range(7)] if top else [0.08 + 0.1 * i for i in range(8)], 8.4,
                  opp=True, spread=60, shrink=0.4, fill=fill, d=0)
            if top:   # branching at the top into a broad, flat-topped cluster
                e = q.pt(1)
                forks = {(-6, -5): ((-13, -8), (-7, -11)), (0, -6): ((0, -12),), (6, -5): ((7, -11), (13, -8))}
                ends = []
                with a.on(STEM):
                    for (bx, by), outs in forks.items():
                        b = (e[0] + bx, e[1] + by)
                        a.line(f"M{P(e)} L{P(b)}", 0.6, 0.85)
                        for ox, oy in outs:
                            p = (e[0] + ox, e[1] + oy); a.line(f"M{P(b)} L{P(p)}", 0.45, 0.85); ends.append((p, ox * 4))
                with a.on(BLOOM):
                    for p, o in ends:
                        top(a, p[0], p[1], o)

    def young():
        a = soil()
        with a.group():
            stems(a, 42)
        return a

    def flower():
        def fl(a, x, y, o):
            M = tilt(y, 0.7)
            for i in range(5):
                petal(a, x, y, -90 + 72 * i + o, 5.0, 3.0, fc, FAN, M=M, lw=0.4, lines=0, shade=0.05)
            burst(a, x, y, 8, 0.3, 3.4, "sun", M, lw=0.3, ar=0.4)
        a = soil()
        with a.group():
            stems(a, 72, top=fl)
        return a

    def seedhead():
        a = soil()
        with a.group():
            stems(a, 70, top=lambda a, x, y, o: capsule(a, x, y, -90 + o * 0.3, 4.2, 2.6, fr, beak=0.2, lw=0.45),
                  col="bark", fill="straw")
        return a

    def dormant():
        a = soil()
        with a.group():
            for dx, hh in ((-6, 46), (2, 54), (8, 40)):   # old brown stems
                a.ribbon((50 + dx, 88), (50 + dx, 88 - hh / 2), (50 + dx * 1.3, 88 - hh), 1.4, 1.0, "bark", lw=0.6)
            for x0, x1 in ((-26, -4), (4, 26)):   # low reddish leafy shoots and runners
                q = shoot(a, 50 + x0 * 0.2, 87.5, 50 + x1, 84, -2, 1.2, 1.0, "rust")
                leafy(a, k, q, (0.3, 0.6, 0.9), 6, opp=True, spread=60, shrink=0, d=0, fill="rust")
            q = shoot(a, 50, 88, 50, 78, 0, 1.2, 1.0, "rust")
            leafy(a, k, q, (0.4, 0.9), 7, opp=True, spread=58, shrink=0, d=0)
        return a

    return {"seed": sown(sjw_seed),
            "seedling": lambda: seedling(k, ("oval", 4.4, 3.0), ((-128, 8), (-52, 8)), h=10),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ lady's bedstraw
def bedstraw_seed(a, x, y):
    """Tiny, smooth, round nutlets in pairs, turning black."""
    for dx, dy, r in THREE:
        t = T(x + dx, y + dy, r)
        for o in (-1, 1):
            a.oval(*t(o * 2.7), 2.8, 2.8, 0, "dark", 0.7)


def whorl(a, x, y, n, L, fill, k=0.4, lw=0.5):
    """A ring of needle-like leaves round the stem, seen from the side."""
    with a.on(LEAF):
        M = tilt(y, k)
        for i in sorted(range(n), key=lambda i: math.sin(i * 2 * math.pi / n + 0.3)):
            e = M(T(x, y, i * 360 / n + 17)(L))
            a.line(f"M{f(x)},{f(y)} L{P(e)}", 1.5, 0.85, "line"); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.75, 1.0, fill)


def bedstraw_stages():
    k = "lady-s-bedstraw"; fc = pal(k, "flower", "sun"); lc = pal(k, "leaf", "deep"); fr = pal(k, "fruit", "dark")

    def stems(a, H, n=5, plume=None, col="leaf", fill=None):
        for dx, hh, lean in ((-16, 0.75, -18), (0, 1.0, 0), (15, 0.82, 16), (-6, 0.9, -7), (6, 0.94, 7))[:n]:
            q = shoot(a, 50 + dx * 0.3, 88, 50 + dx + lean, 88 - H * hh, lean * 0.1, 1.2, 0.8, col, lw=0.55)
            m = int(H * hh / 12)
            for j in range(m):
                u = 0.1 + 0.85 * j / m * (0.55 if plume else 1.0); x, y = q.pt(u)
                whorl(a, x, y, 10, 4.6 * (1 - 0.3 * u), fill or lc)
            if plume:
                with a.on(BLOOM):
                    plume(a, q)

    def young():
        a = soil()
        with a.group():
            stems(a, 40, 4)
        return a

    def froth(a, q, col=None, dots=False):
        """Loose, branched sprays at the top of a stem: short side branches that
        fork into twigs, each twig ending in a few tiny four-pointed stars (or,
        gone to seed, in tiny dark paired fruits)."""
        lc_ = "dark" if dots else "line"
        for j in range(9):
            u = 0.55 + 0.45 * j / 8; x, y = q.pt(u); sd = 1 if j % 2 else -1; w = 8 * (1.1 - 0.7 * (u - 0.55) / 0.45)
            e = (x + sd * w, y - 3)
            a.line(f"M{f(x)},{f(y)} Q{f(x + sd * w * 0.5)},{f(y - 0.6)} {P(e)}", 0.4, 0.85, lc_)
            for t_, (ox, oy) in enumerate(((sd * 3, -3.4), (sd * 3.6, 0.6), (-sd * 0.6, -3.6))):
                b = lerp((x, y), e, 0.55 if t_ == 2 else 1.0); tip = (b[0] + ox, b[1] + oy)
                a.line(f"M{P(b)} L{P(tip)}", 0.3, 0.85, lc_)
                for kk, (dx, dy) in enumerate(((0, 0), (1.3, 0.9), (-1.2, 0.8), (0.4, -1.3))):
                    px, py = tip[0] + dx, tip[1] + dy
                    if dots:
                        a.dot(px - 0.35, py, 0.4, col); a.dot(px + 0.35, py, 0.4, col)
                    else:
                        star4(a, px, py, 1.25, col, lw=0.25, start=j * 20 + kk * 30)
        e = q.pt(1)
        for kk, (dx, dy) in enumerate(((0, -1), (1.3, 0), (-1.3, 0.2))):
            if dots:
                a.dot(e[0] + dx, e[1] + dy, 0.4, col)
            else:
                star4(a, e[0] + dx, e[1] + dy, 1.25, col, lw=0.25, start=kk * 25)

    def flower():
        a = soil()
        with a.group():
            stems(a, 74, plume=lambda a, q: froth(a, q, fc))
        return a

    def seedhead():
        a = soil()
        with a.group():
            stems(a, 70, plume=lambda a, q: froth(a, q, fr, True), col="dark", fill="bark")
        return a

    def dormant():
        a = soil()
        with a.group():
            for dx, hh in ((-6, 40), (3, 48), (9, 34)):   # old dark stems
                a.ribbon((50 + dx, 88), (50 + dx, 88 - hh / 2), (50 + dx * 1.3, 88 - hh), 1.0, 0.7, "dark", lw=0.5)
            for x0, x1 in ((-30, -4), (4, 30)):   # low creeping shoots at the base
                q = shoot(a, 50 + x0 * 0.1, 87.5, 50 + x1, 85, -1.5, 1.0, 0.8, "leaf", lw=0.5)
                for u in (0.35, 0.7, 1.0):
                    p = q.pt(u); whorl(a, p[0], p[1] - 0.6, 8, 3.2, lc)
        return a

    return {"seed": sown(bedstraw_seed),
            "seedling": lambda: bedstraw_seedling(k, lc),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


def bedstraw_seedling(k, lc):
    a = seedling(k, ("oval", 5, 3.2), (), h=8)
    top = G - 8 * 2.1
    with a.group():   # the first whorl of narrow leaves above the seed leaves
        a.ribbon((50, top), (50, top - 4), (50, top - 9), 1.6, 1.2, "leaf", lw=0.6)
        whorl(a, 50, top - 8, 8, 9, lc, k=0.5, lw=0.7)
    return a


# ============================================================ rock sea-lavender
def sealavender_seed(a, x, y):
    """Small narrow brown seeds, one still in its papery funnel calyx."""
    for dx, dy, r in ((-9, 2, -20), (8, -3, 30)):
        seed_oval(a, x + dx, y + dy, r, 8.4, 3.0, "bark", line=False)
    t = T(x + 2, y + 9, -70)
    a.shape(path([t(-5, -1.2), t(4, -4.2), t(5, 0), t(4, 4.2), t(-5, 1.2)]), "white", 0.6)
    a.line(f"M{P(t(-4, 0))} L{P(t(4, 0))}", 0.4, 0.4)


def sealav_stems(a, H, fc, dry=False):
    """The wiry zig-zag branched flowering stems with their one-sided spikes."""
    col = "straw" if dry else "leaf"
    for dx, hh, lean in ((-10, 0.82, -16), (0, 1.0, -2), (9, 0.9, 12), (16, 0.7, 22)):
        x0, y0 = 50 + dx * 0.25, 87
        top = (50 + dx + lean, 88 - H * hh)
        pts = [(x0, y0)]
        for j in range(1, 6):
            u = j / 5; pts.append((x0 + (top[0] - x0) * u + (1.6 if j % 2 else -1.6), y0 + (top[1] - y0) * u))
        with a.on(STEM):
            a.line(opath(pts), 0.9, 0.85, "line")
            a.line(opath(pts), 0.45, 1.0, col)
        with a.on(BLOOM):
            for j in range(2, 6):   # longer, denser one-sided spikes along the upper side of each branch
                p0 = pts[j]; sd = 1 if j % 2 else -1; L = 13 * (1 - 0.1 * j)
                p1 = (p0[0] + sd * L, p0[1] - L * 0.42)
                a.line(f"M{P(p0)} L{P(p1)}", 0.5, 0.85, "bark" if dry else "line")
                for v in (0.3, 0.46, 0.62, 0.78, 0.94):
                    q_ = lerp(p0, p1, v)
                    a.leaf(q_[0], q_[1], -90 + sd * 10, 2.4, 0.6, "straw" if dry else "white", lw=0.3, detail=False)
                    if not dry:
                        a.oval(q_[0] + sd * 0.4, q_[1] - 2.5, 1.4, 1.1, 0, fc, 0.3)


def sealavender_stages():
    k = "rock-sea-lavender"; fc = pal(k, "flower", "lilac")

    def young():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=22)
        return a

    def flower():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=18); sealav_stems(a, 64, fc)
        return a

    def seedhead():
        a = soil()
        with a.group():
            rosette(a, k, n=7, L=16); sealav_stems(a, 60, fc, True)
        return a

    def dormant():
        a = soil()
        with a.group():
            rosette(a, k, n=9, L=18)
            for dx, hh in ((-6, 30), (4, 36)):   # old dry stems
                pts = [(50 + dx * 0.3, 87)] + [(50 + dx + (1.4 if j % 2 else -1.4), 87 - hh * j / 4) for j in range(1, 5)]
                a.line(opath(pts), 0.6, 0.8, "bark")
                for p in pts[2:]:
                    a.line(f"M{P(p)} l{f(3 if dx > 0 else -3)},-1.6", 0.5, 0.8, "bark")
        return a

    return {"seed": sown(sealavender_seed),
            "seedling": lambda: seedling(k, ("oval", 5, 3.0), ((-140, 10), (-40, 10)), h=4, spread=78),
            "young": young, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ candy cane sorrel
def oxbulb(a, x, y, s=1.0, shoot_=False):
    """A tiny pointed brown bulb, its papery tunic drawn out to a point."""
    a.shape(f"M{f(x)},{f(y - 9 * s)} C{f(x + 2 * s)},{f(y - 6 * s)} {f(x + 5 * s)},{f(y - 1 * s)} {f(x + 4.6 * s)},{f(y + 2.4 * s)} "
            f"C{f(x + 4 * s)},{f(y + 5 * s)} {f(x - 4 * s)},{f(y + 5 * s)} {f(x - 4.6 * s)},{f(y + 2.4 * s)} "
            f"C{f(x - 5 * s)},{f(y - 1 * s)} {f(x - 2 * s)},{f(y - 6 * s)} {f(x)},{f(y - 9 * s)} Z", "bark", 0.8)
    a.line(f"M{f(x)},{f(y - 8.4 * s)} C{f(x - 2 * s)},{f(y - 4 * s)} {f(x - 2.6 * s)},{f(y)} {f(x - 1.4 * s)},{f(y + 3.8 * s)}", 0.5, 0.4)
    a.roots(x, y + 4.2 * s, 4, 4 * s, 90, lw=0.6)


def oxalis_stages():
    k = "candy-cane-sorrel"; fc = pal(k, "flower", "white"); cen = pal(k, "centre", "primrose"); edge = "berry"

    def bulbs(a, y=94, s=0.6):
        for dx in (-8, 7):
            oxbulb(a, 50 + dx, y, s)

    def tuft(a, H=18, n=5):
        for dx, hh, lean in ((-8, 0.8, -9), (8, 0.85, 9), (-2, 1.0, -2), (3, 0.92, 4), (0, 0.7, 0))[:n]:
            leaf(a, k, 50 + dx * 0.4, 88, -90 + lean * 2.6, H * hh * 1.25, None, 1)   # each leaf: three leaflets on a thin stalk

    def set_():
        a = Art(); a.ground(40, marks=False)
        for dx, dy, w in [(-30, 46, 4), (27, 50, 3), (-24, 80, 3), (28, 76, 4)]:
            a.line(f"M{50 + dx},{dy} L{50 + dx + w},{dy}", 0.9, 0.55, "soil")
        oxbulb(a, 50, 64, 2.2)
        return a

    def young():
        a = soil()
        with a.group():
            tuft(a, 30); bulbs(a)
        return a

    def flower():
        a = soil()
        with a.group():
            tuft(a, 30); bulbs(a)
            with a.on(BLOOM):
                for x, y in ((36, 50), (60, 44)):   # open flowers on slender stalks
                    a.line(f"M50,86 Q{f((50 + x) / 2)},{f(y + 16)} {f(x)},{f(y + 3)}", 0.6, 0.85)
                    M = tilt(y, 0.55)
                    for i in range(5):
                        mp = petal(a, x, y, -90 + 72 * i + 10, 7, 5.6, fc, FAN, M=M, lw=0.45, lines=0, shade=0.06)
                        a.line(opath([mp((7 * u, 2.6 * FAN(u))) for u in (0.5, 0.75, 0.95)]), 0.7, 0.9, edge)
                    a.oval(x, y, 1.6, 1.0, 0, cen, 0.35)
                for x, y, ang in ((48, 42, -84), (70, 56, -60)):   # red and white spiral buds
                    a.line(f"M50,86 Q{f((50 + x) / 2)},{f(y + 16)} {f(x)},{f(y + 2)}", 0.6, 0.85)
                    t = T(x, y + 2, ang)
                    a.shape(path([t(0, 0), t(3, -1.4), t(8, -0.6), t(10, 0), t(8, 0.6), t(3, 1.4)]), "white", 0.45)
                    for u in (0.25, 0.5, 0.75):
                        a.line(f"M{P(t(10 * u - 0.8, -1.2))} L{P(t(10 * u + 0.8, 1.2))}", 0.7, 0.9, edge)
        return a

    def dormant():
        a = soil()
        with a.group():
            bulbs(a, 95, 0.7)
        return a

    return {"set": ("Bulb", set_), "young": young, "flower": flower, "dormant": dormant}


STAGE = {"foxglove": foxglove_stages(), "salvia": salvia_stages(), "common-evening-primrose": primrose_stages(),
         "wallflower": wallflower_stages(), "yellow-rattle": rattle_stages(), "selfheal": selfheal_stages(),
         "sweet-william": sweetwilliam_stages(), "poppy": poppy_stages(), "california-poppy": calpoppy_stages(),
         "borage": borage_stages(), "russian-comfrey": comfrey_stages(), "lungwort": lungwort_stages(),
         "native-cowslip": cowslip_stages(), "geum": geum_stages(), "viola": viola_stages(), "aubrieta": aubrieta_stages(),
         "linum": linum_stages(), "marshmallow": marshmallow_stages(), "perforate-st-john-s-wort": sjw_stages(),
         "lady-s-bedstraw": bedstraw_stages(), "rock-sea-lavender": sealavender_stages(), "candy-cane-sorrel": oxalis_stages()}
