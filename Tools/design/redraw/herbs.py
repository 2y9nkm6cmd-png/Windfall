"""Windfall plant drawings, the redraw of 16 November 2026: the HERBS group.

William, this file holds every change to the drawings of 14 herbs: basil,
mint, lemon balm, oregano, tarragon, catnip, hyssop, lavender, rosemary,
sage, savory, wormwood, thyme and bay. Each drawing was checked against the
herb's written description (Design/Plants/descriptions/<kind>.json) and
photographs of the real plant.

What was wrong before: the herbs were built from a few shared templates, so
every leafy herb was a stacked cone of the same stock leaf, every shrubby
herb (hyssop, lavender, rosemary, savory) was the same fan of dark green
needles, thyme was a green half-moon, bay was a lollipop tree, and the
flowers were one stock "two-lipped" shape in the wrong colours.

So this file draws each herb's own parts, in four steps.

1. LEAVES (close-ups). Two new ways of drawing a leaf:
   - herbs_leaf: one leaf on its stalk. Its outline comes from a "profile"
     (how wide it is along its length: PROFS below), and can have a heart-
     shaped base ("back"), sharp or rounded teeth, a wavy edge, a pale rim,
     pressed-in veins that make the blade puckered ("pucker") or quilted
     ("quilt"), a fringe of fine hairs ("hairs"), a shine ("gloss"), a
     paler underside showing along one edge ("under") and an edge curling
     down ("cup"). Basil, mint, lemon balm, catnip, sage and bay use it.
   - herbs_sprig: a short shoot with its small leaves, for the herbs whose
     single leaf is too small or too narrow to make a picture on its own:
     rosemary, lavender, hyssop, savory, thyme, oregano and tarragon. Leaves
     can be in pairs or set singly, with tufts of young leaves in the joints,
     edges rolled under, a white underside, grey felt, or short stalks.
   - herbs_cut: a leaf cut two or three times into narrow blunt segments:
     wormwood.
   The life-stage drawings use the same leaves, drawn small (own() for the
   single leaves, and nleaf(), the same narrow leaf the sprigs are made of,
   for the rest), so the whole plant and the close-up cannot disagree.

2. FLOWERS (close-ups). Almost every herb here is in the mint family, whose
   flowers are "two-lipped": a tube that opens into an upper lip and a lower
   lip. lip_flower() below draws one from the side, and its settings say
   what kind of upper lip (broad, hooded, short), what kind of lower lip
   (hanging, three-lobed, cupped), where the stamens are and what the calyx
   (the green cup behind) is like. Each herb's close-up then arranges its
   flowers the way that herb carries them: tiers up a spike (basil, sage),
   a dense spike (mint, lavender, hyssop, catnip), a round head (thyme), a
   flat-topped head (oregano) or clusters in the leaf joints (lemon balm,
   rosemary, savory, bay). Wormwood's tiny nodding yellow balls have their
   own.

3. LIFE STAGES. Every stage of every herb is drawn by hand here (the STAGE
   table) from a few helpers: shoot(), clump() and bush() for the stems
   (bush() gives a shrub its brown woody base), pairs() and singles()
   to put leaves along them (pairs() turns every other pair to face you, so
   the pairs cross at right angles, as they do on the real plants), and the
   flower helpers at plant scale (mini_lip(), whorl_spike(), head_small(),
   flat_head()). The seeds and seedlings are drawn here too: basil's seed
   leaves with kidney(), wider than long.

4. COLOURS. Four new ones, asked for in the descriptions: herbs_violet
   (hyssop's deep violet-blue), herbs_lavender (lavender's violet-purple),
   herbs_salvia (sage's violet-lilac) and herbs_silver (wormwood's silvery
   leaves). Each has a light and a dark-mode value.

Everything that could not be put fully right is listed, with why, in the
results file that went with this work.
"""
import json, math, os
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10

GOLD = 2.39996
BASE = (20, 92)    # where a close-up leaf's stalk starts, as in leaves_flowers.py
ANG = -52          # the way a close-up leaf points

COLOURS = {
    "herbs_violet":   ("#5B4FB8", "#8379D6"),   # hyssop: deep violet-blue
    "herbs_lavender": ("#7D62B5", "#9C84D2"),   # lavender: violet-purple
    "herbs_salvia":   ("#9A86D6", "#8E7CCB"),   # sage: violet-lilac
    "herbs_silver":   ("#C9D0C2", "#8C978A"),   # wormwood: silvery grey-green
}

HERE = os.path.dirname(os.path.abspath(__file__))


def pal(kind):
    """The kind's colours from its description (read here directly, so this
    file need not import plants_all at the top)."""
    p = os.path.join(HERE, "..", "..", "..", "Design", "Plants", "descriptions", f"{kind}.json")
    with open(p, encoding="utf-8") as fh:
        return json.load(fh).get("palette", {})


def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


# ============================================================ leaf outlines
def prof(umax=0.5, base="round", tip="point", bp=None, tp=None):
    """A leaf's width along its length (u: 0 at the base, 1 at the tip), as a
    share of its widest. umax: where it is widest. base: "wedge" (straight
    sides narrowing to the stalk), "round" or "taper" (a long narrow wedge).
    tip: "point", "round", "blunt" or "acum" (drawn out into a fine point).
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


# One profile for each herb's leaf, named after the herb.
PROFS = {
    "basil":    prof(0.42, "wedge", "point", bp=1.15, tp=0.8),   # oval, the base running down into the stalk
    "mint":     prof(0.3, "round", "point", bp=0.5, tp=1.0),      # lance-shaped, widest near the rounded base
    "balm":     prof(0.3, "round", "point", bp=0.32, tp=0.72),    # broad oval, base almost cut straight across
    "catnip":   prof(0.24, "round", "point", bp=0.4, tp=1.05),    # triangular oval over a heart-shaped base
    "sage":     prof(0.45, "round", "blunt", bp=0.6, tp=2.6),     # oblong, sides almost parallel, tip rounded
    "bay":      prof(0.48, "wedge", "point", bp=1.05, tp=0.95),   # narrow oval, pointed at both ends
    "oregano":  prof(0.42, "round", "point", bp=0.45, tp=0.6),    # small broad oval, blunt point
    "strap":    prof(0.55, "round", "round", bp=0.5, tp=3.5),     # long narrow, blunt: rosemary, lavender
    "hyssop":   prof(0.42, "wedge", "point", bp=0.8, tp=1.0),     # narrow lance, pointed
    "savory":   prof(0.45, "wedge", "acum", bp=0.9, tp=0.8),      # narrow, sharply pointed
    "thyme":    prof(0.45, "round", "point", bp=0.6, tp=0.75),    # tiny narrow oval
    "tarragon": prof(0.35, "taper", "point", bp=0.7, tp=1.1),     # grass-like with a midrib
    "seg":      prof(0.4, "round", "round", bp=0.5, tp=2.0),      # a wormwood segment: narrow, blunt
}

# The nick across one tooth: s runs 0 to 1 along the tooth (towards the leaf
# tip). 1 is the bottom of a nick, 0 the point of a tooth.
NICK = {
    "saw":   lambda s: (1 - s) ** 1.6,                        # sharp, forward-pointing (mint)
    "round": lambda s: abs(math.cos(math.pi * s)) ** 2.4,     # rounded (lemon balm)
    "blunt": lambda s: abs(math.cos(math.pi * s)) ** 1.4,     # coarse and rather blunt (catnip)
    "tiny":  lambda s: abs(math.cos(math.pi * s)) ** 3.0,     # tiny rounded (sage)
}


def half_edge(L, W, pf, back=0.0, n=140):
    """The upper edge of a leaf laid along the x axis from its base (0,0) to
    its tip (L,0), as points. back: a heart-shaped base, its two lobes
    reaching back past the stalk by that share of the length."""
    pr = PROFS[pf]; pts = []
    for i in range(n + 1):
        u = i / n
        x = L * u
        if back and u < 0.4:
            x -= back * L * math.sin(math.pi * u / 0.4)
        pts.append((x, pr(u) * W / 2))
    return pts


def cut_teeth(pts, n, depth, tk="saw", tfrom=0.06, wave=0.0, nw=0):
    """Cuts teeth into an edge: moves each point in towards the midrib by up
    to depth grid squares, n teeth along it from tfrom (a share of the
    edge's length) to the tip. wave: a gentle wave of nw bends instead."""
    seg = [math.dist(p, q) for p, q in zip(pts, pts[1:])]
    tot = sum(seg) or 1; s = [0.0]
    for d in seg:
        s.append(s[-1] + d / tot)
    out = []
    for i, (x, y) in enumerate(pts):
        p0 = pts[max(0, i - 1)]; p1 = pts[min(len(pts) - 1, i + 1)]
        tx, ty = p1[0] - p0[0], p1[1] - p0[1]; m = math.hypot(tx, ty) or 1
        nx, ny = ty / m, -tx / m          # points in, towards the midrib
        d = 0.0
        fade = max(0.0, min(1.0, (1 - s[i]) / 0.05, s[i] / 0.04))
        if n and s[i] > tfrom:
            q = ((s[i] - tfrom) / (1 - tfrom) * n) % 1
            d += depth * NICK[tk](q) * min(1.0, (s[i] - tfrom) / 0.05) * fade
        if wave:
            d += wave * (0.5 + 0.5 * math.sin(2 * math.pi * s[i] * nw)) * fade
        out.append((x + nx * d, y + ny * d))
    return out


def width_at(pts, x):
    """The half width of an edge at distance x along the midrib."""
    best = 0.0
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if (x0 - x) * (x1 - x) <= 0 and x1 != x0:
            best = max(best, y0 + (y1 - y0) * (x - x0) / (x1 - x0))
    return best


def blade(a, x, y, ang, L, W, fill, pf="basil", back=0.0, teeth=0, td=0.0, tk="saw", tfrom=0.06,
          wave=0.0, nw=0, veins=5, vang=0.16, pucker=False, quilt=False, hairs=0, gloss=False,
          under=None, cup=False, rim=None, lw=1.1, midw=0.8, shade=0.1, bend=0.0, detail=True):
    """One leaf blade from x,y (where the stalk joins) along ang, L long and
    W wide, with its veins and surface. See the notes at the top of the file
    for what each setting does. bend arches the whole blade to one side."""
    t = T(x, y, ang)

    def mp(p):   # a point on the flat leaf -> a point on the grid (with the arch)
        px, py = p
        return t(px, py + bend * L * 4 * (px / L) * (1 - px / L) if L else py)

    top = half_edge(L, W, pf, back)
    if teeth or wave:
        top = cut_teeth(top, teeth, td, tk, tfrom, wave, nw)
    bot = [(px, -py) for px, py in top]
    a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), fill, lw)
    if under:   # the paler underside, seen as a strip along the lower edge
        inner = [(px, py + min(W * 0.07, -py * 0.3)) for px, py in bot]
        a.shape(path([mp(p) for p in bot] + [mp(p) for p in inner[::-1]]), under, 0)
        if detail:
            a.line(opath([mp(p) for p in inner[6:-6]]), 0.45, 0.45)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((p[0], 0)) for p in top[::-1]]), "shade", 0, fa=shade)
    if cup and detail:   # the edge curling down: a darker band just inside the lower edge
        band = [(px, py * 0.8) for px, py in bot]
        a.shape(path([mp(p) for p in bot[8:-6]] + [mp(p) for p in band[8:-6][::-1]]), "shade", 0, fa=0.13)
    if rim and detail:   # a thin pale line just inside the edge (bay)
        for side in (top, bot):
            a.line(opath([mp((px, py * 0.94)) for px, py in side[6:-4:2]]), 0.5, 0.75, rim)
    if gloss and detail:   # a soft light streak: a shiny leaf
        a.line(opath([mp((L * u, width_at(top, L * u) * 0.48)) for u in (0.2, 0.32, 0.44, 0.56)]), 1.4, 0.45, "white")
    if not detail:
        return top
    a.line(opath([mp((L * u, 0)) for u in (0.0, 0.3, 0.6, 0.93)]), midw, 0.55)
    ends = []
    for k in range(veins):
        u1 = 0.16 + 0.7 * (k + 0.5) / veins
        u0 = max(0.02, u1 - vang)
        for sd in (1, -1):
            w1 = sd * width_at(top, L * u1) * 0.82
            p0, c, p1 = mp((L * u0, 0)), mp((L * (u0 + vang * 0.4), w1 * 0.55)), mp((L * u1, w1))
            a.line(f"M{P(p0)} Q{P(c)} {P(p1)}", 0.62 if pucker else 0.5, 0.5 if pucker else 0.36)
            if pucker:   # the blade bulging up between the pressed-in veins: a light line beside each
                q0, qc, q1 = mp((L * (u0 + 0.03), sd * 0.8)), mp((L * (u0 + vang * 0.4 + 0.04), w1 * 0.5)), mp((L * (u1 + 0.03), w1 * 0.9))
                a.line(f"M{P(q0)} Q{P(qc)} {P(q1)}", 0.8, 0.22, "white")
            ends.append((u0, u1, w1, sd))
    if quilt:   # the fine net of veins between the side veins
        for u0, u1, w1, sd in ends:
            for v in (0.3, 0.55, 0.8):
                pa = (L * (u0 + (u1 - u0) * v + vang * 0.15), w1 * v * 0.85)
                pb = (L * (u0 + (u1 - u0) * v + 0.7 / veins * 0.9), w1 * v * 0.7)
                a.line(f"M{P(mp(pa))} L{P(mp(pb))}", 0.38, 0.26)
    if hairs:   # a fringe of fine hairs round the edge: a downy leaf
        for side in (top, bot):
            for i in range(4, len(side) - 3, max(2, len(side) // hairs)):
                (x0, y0), (x1, y1) = side[i - 1], side[i + 1]
                tx, ty = x1 - x0, y1 - y0; m = math.hypot(tx, ty) or 1
                sg = 1 if side is top else -1
                nx, ny = -ty / m * sg, tx / m * sg
                if side is bot:
                    nx, ny = -nx, -ny
                px, py = side[i]
                a.line(f"M{P(mp((px, py)))} L{P(mp((px + nx * 1.4 + tx / m * 0.6, py + ny * 1.4 + ty / m * 0.6)))}", 0.4, 0.55)
    return top


def stalk(a, p0, c, p1, w0=2.4, w1=1.8, fill="leaf", lw=0.9):
    return a.ribbon(p0, c, p1, w0, w1, fill, lw=lw)


BLADE_KEYS = ("pf", "back", "teeth", "td", "tk", "tfrom", "wave", "nw", "veins", "vang", "pucker", "quilt",
              "hairs", "gloss", "under", "cup", "rim", "bend")


def bkw(sp, **over):
    """The blade settings out of a close-up's settings."""
    d = {k: sp[k] for k in BLADE_KEYS if k in sp}
    d.update(over)
    return d


# ============================================================ close-up leaves
def leaf_herb(a, sp):
    """One simple leaf on its stalk (petiole: the stalk's share of the whole
    length; 0 for a leaf that sits right on the stem)."""
    pf_ = sp.get("petiole", 0.2); LT = sp.get("len", 98); L = LT * (1 - pf_)
    t = T(*BASE, ANG); A = t(LT * pf_)
    if pf_ > 0.02:
        stalk(a, BASE, t(LT * pf_ * 0.5, 1.0), A, sp.get("sw0", 2.6), sp.get("sw1", 1.9), sp.get("stalkc", sp["fill"]))
    blade(a, A[0], A[1], ANG, L, L * sp.get("W", 0.5), sp["fill"], lw=1.15, midw=0.95, **bkw(sp))
    return a


def nleaf(a, x, y, ang, L, W, fill, pf="strap", under=None, rolled=False, felt=False, gloss=False,
          mid=True, lw=0.8, stalkL=0.0, shade=0.08, hairs=0):
    """One small narrow leaf, for sprigs and whole plants. under: a white
    or pale underside showing along one edge; rolled: a line just inside the
    edge where it rolls under; felt: grey felt, shown as fine pale specks;
    stalkL: a short stalk first."""
    if stalkL:
        e = T(x, y, ang)(stalkL)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", max(0.5, lw * 0.9), 0.85)
        x, y = e
    t = T(x, y, ang)
    top = half_edge(L, W, pf, n=40)
    bot = [(px, -py) for px, py in top]
    a.shape(path([t(*p) for p in top] + [t(*p) for p in bot[::-1]]), fill, lw)
    if under:
        inner = [(px, py * 0.42) for px, py in bot]
        a.shape(path([t(*p) for p in bot] + [t(*p) for p in inner[::-1]]), under, 0)
    elif shade and L >= 6:
        a.shape(path([t(*p) for p in top] + [t(p[0], 0) for p in top[::-1]]), "shade", 0, fa=shade)
    if rolled and L >= 8:
        a.line(opath([t(px, py * 0.62) for px, py in top[5:-5:3]]), 0.4, 0.5)
    if gloss and L >= 8:
        a.line(opath([t(L * u, width_at(top, L * u) * 0.45) for u in (0.2, 0.4, 0.6)]), 0.8, 0.5, "white")
    if felt and L >= 6:
        for k in range(int(L / 2.2)):
            u = 0.12 + 0.76 * ((k * 0.618) % 1); v = ((k * 0.41) % 1 - 0.5) * 1.2
            p = t(L * u, width_at(top, L * u) * v)
            a.dot(p[0], p[1], 0.32, "white")
    if hairs and L >= 6:
        for k in range(hairs):
            u = 0.15 + 0.7 * k / max(1, hairs - 1)
            for sd in (1, -1):
                w = width_at(top, L * u) * sd
                a.line(f"M{P(t(L * u, w))} L{P(t(L * u + 0.5, w + sd * 1.0))}", 0.35, 0.55)
    if mid and L >= 7:
        a.line(opath([t(L * u, 0) for u in (0.05, 0.5, 0.88)]), 0.45, 0.45)
    return top


def tuft(a, x, y, ang, L, W, fill, pf="strap", **kw):
    """A tuft of young leaves in a leaf joint: three small leaves together."""
    for off, k in ((-22, 0.75), (22, 0.75), (0, 1.0)):
        nleaf(a, x, y, ang + off, L * k, W * k, fill, pf, mid=False, lw=0.6, shade=0, **kw)


def leaf_sprig(a, sp):
    """A short shoot with its small leaves, drawn large: for herbs whose single
    leaf is too small or narrow to make a picture on its own. alt: leaves set
    singly, not in pairs. tufts: young leaves in the joints."""
    q = Quad(sp.get("p0", (30, 97)), sp.get("c", (40, 54)), sp.get("p1", (68, 8)))
    a.ribbon(q.p0, q.c, q.p1, sp.get("sw", 2.4), 1.2, sp.get("stemc", "leaf"), lw=0.8)
    n = sp.get("n", 7); L0 = sp.get("nl", 26); W = sp.get("nw", 0.2); fill = sp["fill"]
    opts = dict(under=sp.get("under"), rolled=sp.get("rolled", False), felt=sp.get("felt", False),
                gloss=sp.get("gloss", False), hairs=sp.get("hairs", 0))
    for i in range(n):
        u = sp.get("u0", 0.1) + (sp.get("u1", 0.9) - sp.get("u0", 0.1)) * i / (n - 1)
        x, y = q.pt(u); ang = q.ang(u); L = L0 * (1 - sp.get("taper", 0.45) * u)
        sides = ((1,) if i % 2 else (-1,)) if sp.get("alt") else (1, -1)
        for sg in sides:
            spread = sp.get("spread", 50) + (8 if sp.get("alt") else 0)
            nleaf(a, x, y, ang + sg * spread, L, L * W, fill, sp.get("pf", "strap"), stalkL=sp.get("stalkL", 0) * L,
                  lw=sp.get("lw", 0.9), **opts)
            if sp.get("tufts") and i < n - 2:
                tuft(a, x, y, ang + sg * 20, L * 0.36, L * 0.36 * W * 1.2, fill, sp.get("pf", "strap"))
    e = q.pt(1)   # the shoot tip: a small bud of young leaves
    for off in (-14, 14):
        nleaf(a, e[0], e[1], q.ang(1) + off, L0 * 0.32, L0 * 0.32 * W * 1.1, fill, sp.get("pf", "strap"), mid=False, lw=0.7, shade=0)
    return a


def leaf_cut(a, sp):
    """Wormwood: a leaf cut almost to the midrib into lobes, and each lobe cut
    again into narrow, blunt, smooth-edged segments, on a long stalk."""
    fill = sp["fill"]; t = T(*BASE, ANG)
    q = Quad(BASE, t(48, -2), t(94))
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.0, fill, lw=0.8)
    segW = sp.get("segW", 3.4)

    def seg(x, y, ang, L):
        blade(a, x, y, ang, L, segW, fill, "seg", veins=0, lw=0.7, midw=0.0, shade=0.06, hairs=0)

    for i, u in enumerate((0.34, 0.5, 0.64, 0.77)):
        x, y = q.pt(u); ang = q.ang(u); L = 30 * (1.0 - 0.55 * (u - 0.34) / 0.43)
        for sd in (1, -1):
            pa = ang + sd * 50; tq = T(x, y, pa)
            a.line(f"M{f(x)},{f(y)} L{P(tq(L * 0.86))}", 1.2, 0.85, "line")
            a.ribbon((x, y), tq(L * 0.4, 0), tq(L * 0.86), 2.0, 1.2, fill, lw=0.6)
            for v, k in ((0.3, 0.6), (0.58, 0.5)) if L > 20 else ((0.45, 0.55),):
                p = tq(L * v)
                for sd2 in (1, -1):
                    seg(p[0], p[1], pa + sd2 * 48, L * k)
            seg(*tq(L * 0.84), pa, L * 0.44)
    e = q.pt(0.9)   # the end lobe, cut in three
    for off, k in ((-36, 0.8), (36, 0.8), (0, 1.0)):
        seg(e[0], e[1], q.ang(0.9) + off, 13 * k)
    # the fine silky hairs: a sheen of pale specks
    for k in range(40):
        u = 0.32 + 0.6 * ((k * 0.618) % 1); x, y = q.pt(u); ang = q.ang(u)
        p = T(x, y, ang + (60 if k % 2 else -60))(4 + (k * 7) % 14)
        a.dot(p[0], p[1], 0.35, "white")
    return a


LEAF_DRAW = {"herbs_leaf": leaf_herb, "herbs_sprig": leaf_sprig, "herbs_cut": leaf_cut}


# ============================================================ flowers
def calyx_shape(a, x, y, ang, L, cw, fill, kind="cup", lw=0.7, ribs=0):
    """The calyx: the green (or coloured) cup a flower sits in, from x,y along
    ang, L long and cw wide at its mouth. kind "cup": a short flared cup with
    small pointed teeth; "tube": long and narrow, ribbed; "two": two-lipped,
    a broad rounded upper lobe over small lower teeth (basil, sage)."""
    t = T(x, y, ang); w0 = cw * 0.26
    topedge = [(L * u, w0 + (cw / 2 - w0) * u ** 0.9) for u in (0, 0.25, 0.5, 0.75, 1.0)]
    if kind == "two":   # a broad rounded upper lobe, two small points below
        rim = [(L + cw * 0.3, cw * 0.55), (L + cw * 0.5, cw * 0.1), (L + cw * 0.05, -0.05 * cw),
               (L + cw * 0.28, -cw * 0.2), (L - cw * 0.02, -cw * 0.3), (L + cw * 0.26, -cw * 0.46)]
    else:               # three small pointed teeth seen from the side
        k = 0.36 if kind == "tube" else 0.3
        rim = [(L + cw * k, cw * 0.36), (L - cw * 0.03, cw * 0.18), (L + cw * k, 0.0),
               (L - cw * 0.03, -cw * 0.18), (L + cw * k, -cw * 0.36)]
    bot = [(px, -py) for px, py in topedge[::-1]]
    a.shape(path([t(*p) for p in topedge + rim + bot]), fill, lw)
    for k in range(ribs):
        o = (k + 1) / (ribs + 1) - 0.5
        a.line(opath([t(L * u, o * (w0 * 2 + (cw - w0 * 2) * u ** 0.9) * 0.9) for u in (0.08, 0.5, 0.92)]), 0.35, 0.4)


def lip_flower(a, x, y, ang, s, fc, calc="leaf", upper="short", lower="three", stam="out", spots=None,
               cal="cup", ribs=0, tube=1.0, anth=None, lipc=None, lw=0.65, hairs=False):
    """One two-lipped flower seen from the side, from x,y (where it joins the
    stem) along ang, s its size (1 is about 12 grid squares long).
      upper  "broad": a broad flat lip with four small lobes (basil)
             "hood":  an arching hood, notched at the tip (rosemary, sage)
             "short": a short, straight little lip (most mints)
      lower  "hang":  one narrow lobe hanging down (basil)
             "three": three lobes, the middle one the biggest
             "cup":   a broad, cupped, hanging middle lobe with a scalloped edge
      stam   "along": stamens lying along the lower lip and past it (basil)
             "arch":  long stamens arching up out of the hood (rosemary)
             "out":   stamens sticking straight out beyond the lips
             "long":  long, spreading well out (hyssop)
             "hidden": none to see
    spots: a colour for spots on the lower lip. cal and ribs: the calyx (see
    calyx_shape). lipc: a different colour for the lower lip."""
    up = -1 if math.cos(math.radians(ang)) >= 0 else 1
    t = T(x, y, ang)
    cL = (4.4 if cal == "tube" else 3.2) * s; cw = (2.2 if cal == "tube" else 2.6) * s
    m0 = cL * 0.5; M = m0 + 4.4 * s * tube           # the mouth of the tube
    a.ribbon(t(m0), t((m0 + M) / 2, -up * 0.2 * s), t(M), 1.1 * s, 2.1 * s, fc, lw=lw)
    mx, my = t(M)
    ld = ang - up * {"hang": 48, "three": 34, "cup": 50}[lower]
    if lower == "hang":
        blade(a, mx, my, ld, 5.0 * s, 2.3 * s, lipc or fc, "strap", veins=0, lw=lw, midw=0, shade=0.06)
    else:
        if lower == "three":   # a side lobe, sticking forward
            blade(a, mx, my, ang - up * 6, 2.6 * s, 2.2 * s, lipc or fc, "oregano", veins=0, lw=lw * 0.9, midw=0, shade=0.04)
        big = 4.6 * s if lower == "cup" else 4.2 * s
        blade(a, mx, my, ld, big, big * (0.95 if lower == "cup" else 0.82), lipc or fc, "balm",
              teeth=3 if (lower == "cup" and s > 0.7) else 0, td=0.5 * s, tk="round", veins=0, lw=lw, midw=0,
              shade=0.14 if lower == "cup" else 0.06)
        if lower == "three" and s > 0.7:   # the notch at the tip of the middle lobe
            a.line(f"M{P(T(mx, my, ld)(big * 0.78))} L{P(T(mx, my, ld)(big * 1.0))}", 0.4, 0.5)
    if spots:
        for k, (u, o) in enumerate(((0.45, -0.15), (0.62, 0.18), (0.75, -0.08), (0.55, 0.32), (0.85, 0.2))):
            if s < 0.6 and k > 2:
                break
            p = T(mx, my, ld)(4.0 * s * u, 4.0 * s * o)
            a.dot(p[0], p[1], max(0.3, 0.38 * s), spots)
    if stam == "along":
        for k, o in enumerate((-0.6, 0.2, 1.0)):
            e = T(mx, my, ld + up * 12)(6.4 * s + k * 0.4 * s, -up * o * s * 0.7)
            a.line(f"M{P(t(M - 1.0 * s, 0))} Q{P(T(mx, my, ld + up * 6)(3.0 * s, -up * o * s * 0.5))} {P(e)}", 0.45, 0.75)
            a.oval(e[0], e[1], 0.55 * s + 0.15, 0.4 * s + 0.15, ld, anth or "primrose", 0.35)
    if upper == "broad":
        ua = ang + up * 62
        fan_lip(a, mx, my, ua, 4.4 * s, 5.4 * s, fc, lw=lw)
    elif upper == "hood":
        ua = ang + up * 30
        blade(a, mx, my, ua, 6.4 * s, 2.8 * s, fc, "strap", veins=0, lw=lw, midw=0, shade=0.12, bend=-up * 0.07)
        e = T(mx, my, ua)(6.2 * s)
        a.line(f"M{P(e)} L{P(T(mx, my, ua)(5.3 * s))}", 0.4, 0.5)
    else:
        ua = ang + up * 46
        blade(a, mx, my, ua, 3.0 * s, 2.4 * s, fc, "oregano", veins=0, lw=lw, midw=0, shade=0.08)
    if stam == "arch":
        for k in (0, 1):
            e = T(mx, my, ua - up * (8 + 10 * k))(8.6 * s + k * s)
            c = T(mx, my, ua + up * 18)(5 * s)
            a.line(f"M{P(t(M - 0.8 * s, 0))} Q{P(c)} {P(e)}", 0.5, 0.8)
            a.oval(e[0], e[1], 0.6 * s + 0.15, 0.45 * s + 0.15, ang, anth or "plum", 0.35)
    elif stam in ("out", "long"):
        Ls = (7.6 if stam == "long" else 5.6) * s
        for k, off in enumerate((-12, -2, 8, 18) if stam == "long" else (-8, 6)):
            e = T(mx, my, ang + up * off)(Ls - k * 0.3 * s)
            a.line(f"M{P(t(M - 1.0 * s, 0))} L{P(e)}", 0.45, 0.8)
            a.oval(e[0], e[1], 0.5 * s + 0.15, 0.4 * s + 0.15, ang, anth or "plum", 0.3)
    calyx_shape(a, x, y, ang, cL, cw, calc, cal, lw=lw, ribs=ribs)
    if hairs and s > 0.6:   # a hairy calyx: fine hairs along its edges
        for u in (0.3, 0.55, 0.8):
            for sd in (1, -1):
                p = t(cL * u, sd * cw * (0.16 + 0.3 * u)); e = t(cL * u + 0.4, sd * cw * (0.16 + 0.3 * u) + sd * 1.2)
                a.line(f"M{P(p)} L{P(e)}", 0.35, 0.6)


def fan_lip(a, x, y, ang, L, W, fill, lobes=4, lw=0.65):
    """A broad lip that spreads like a fan from x,y along ang, its far edge
    cut into small rounded lobes (basil's upper lip)."""
    t = T(x, y, ang); pts = [(0, -W * 0.14)]
    for i in range(41):
        v = -1 + 2 * i / 40
        bump = 0.14 * L * abs(math.sin(math.pi * (v + 1) / 2 * lobes)) ** 0.6
        pts.append((L * (0.86 - 0.22 * v * v) + bump, v * W / 2))
    pts.append((0, W * 0.14))
    a.shape(path([t(*p) for p in pts]), fill, lw)
    a.shape(path([t(*p) for p in pts[:22]] + [t(0, 0)]), "shade", 0, fa=0.07)
    for v in (-0.5, 0, 0.5):   # faint lines running out to the lobes
        a.line(f"M{P(t(L * 0.15, v * W * 0.1))} L{P(t(L * 0.62, v * W * 0.36))}", 0.35, 0.3)


def bud_lip(a, x, y, ang, s, fc, calc="leaf"):
    """A two-lipped flower in bud: the calyx with the petals' tip showing."""
    t = T(x, y, ang)
    blade(a, *t(2.4 * s), ang, 3.6 * s, 2.0 * s, fc, "strap", veins=0, lw=0.55, midw=0, shade=0.06)
    calyx_shape(a, x, y, ang, 3.4 * s, 2.8 * s, calc, "cup", lw=0.6)


def bract_pair(a, x, y, L, W, fill, ang=0, droop=10):
    """A pair of small leaf-like bracts under a tier of flowers."""
    for sd in (1, -1):
        blade(a, x, y, (0 if sd > 0 else 180) + sd * droop + ang, L, W, fill, "basil", veins=0, lw=0.6, midw=0.4, shade=0.06)


def spike_stem(a, top=(50, 8), base=(50, 98), w0=2.6, w1=1.2, fill="leaf", bow=1.0):
    q = Quad(base, ((base[0] + top[0]) / 2 + bow, (base[1] + top[1]) / 2), top)
    a.ribbon(q.p0, q.c, q.p1, w0, w1, fill, lw=0.8)
    return q


def fl_basil(a, sp):
    """Basil: tiers of small white two-lipped flowers spaced up a spike, a
    pair of small bracts under each tier, buds packed at the tip."""
    fc = sp["fc"]; calc = sp.get("calc", "leaf")
    q = spike_stem(a, (50, 6), (50, 98), 3.0, 1.4)
    tiers = [(0.16, 2.0), (0.45, 1.7)]
    for i, (u, s) in enumerate(tiers):
        x, y = q.pt(u)
        bract_pair(a, x, y + 3, 6.5 * s, 3.4 * s, "leaf", droop=20)
        for sd in (-1, 1):   # one flower each side, held out with its upper lip raised, one behind
            lip_flower(a, x + sd * 0.6, y - 1.5, (0 if sd > 0 else 180) - sd * 58, s * 0.62, fc, calc, "broad", "hang", "along", cal="two")
        for sd in (-1, 1):
            lip_flower(a, x + sd * 1.0, y, (0 if sd > 0 else 180) - sd * 10, s, fc, calc, "broad", "hang", "along", cal="two")
    for j, u in enumerate((0.7, 0.8, 0.88, 0.95)):   # the top: buds in their calyces under small bracts
        x, y = q.pt(u); s = 1.3 - 0.22 * j
        bract_pair(a, x, y + 1.5, 6 * s, 3.4 * s, "leaf", droop=30)
        for sd in (-1, 1):
            bud_lip(a, x + sd * 0.6, y, -90 + sd * 50, s, fc, calc)
    a.oval(*q.pt(1), 1.6, 2.4, 0, "leaf", 0.6)
    return a


def funnel4(a, x, y, ang, s, fc, calc="leaf", stam=True, lw=0.55):
    """A tiny almost regular four-lobed funnel flower from the side (mint):
    a bell-shaped calyx with narrow teeth, a short tube, two of the four lobes
    flaring, and stamens sticking out."""
    t = T(x, y, ang)
    a.ribbon(t(0.8 * s), t(2.0 * s), t(3.2 * s), 1.0 * s, 1.9 * s, fc, lw=lw)
    m = t(3.1 * s)
    for off in (-40, 40):
        a.leaf(m[0], m[1], ang + off, 2.3 * s, 0.55, fc, lw=lw, detail=False)
    if stam:
        for off in (-9, 9):
            e = T(*m, ang + off)(3.4 * s)
            a.line(f"M{P(m)} L{P(e)}", 0.4, 0.8)
            a.dot(e[0], e[1], max(0.3, 0.34 * s), "plum")
    calyx_shape(a, x, y, ang, 1.3 * s, 1.2 * s, calc, "cup", lw=lw * 0.8)


def face4(a, x, y, r, fc, cen="plum", lw=0.5):
    """A tiny four-lobed flower seen face on, its stamens as dots."""
    a.flower(x, y, r, 4, fc, None, 0.85, start=-45 + (x * 7) % 30, lw=lw)
    for k in range(4):
        e = T(x, y, 45 + 90 * k)(r * 0.62); a.dot(e[0], e[1], max(0.28, r * 0.13), cen)


def ring(a, x, y, w, s, fc, calc="leaf", front=True, funnel=funnel4, mass=True):
    """One ring of tiny flowers round a stem at x,y, w its half width: a soft
    mass of the flowers behind, those on each side seen from the side, those
    in front face on."""
    if mass:
        a.oval(x, y, w * 0.62, 1.9 * s, 0, fc, 0.5)
    for sd in (-1, 1):   # the side flowers
        funnel(a, x + sd * w * 0.2, y - 0.3 * s, -90 + sd * 58, s * 0.9, fc, calc)
        funnel(a, x + sd * w * 0.3, y + 0.5 * s, -90 + sd * 96, s, fc, calc)
    if front:
        for dx in (-0.26, 0.26):
            face4(a, x + dx * w, y + 0.9 * s, 1.45 * s, fc)


def fl_mint(a, sp):
    """Mint: a slender, tapering spike of many crowded rings of tiny pale
    lilac flowers, their stamens sticking out, the lowest rings a little
    apart; a pair of the narrow toothed leaves below."""
    fc = sp["fc"]; lc = sp.get("lc", "leaf")
    q = spike_stem(a, (50, 6), (52, 98), 3.0, 1.2, bow=0.6)
    for sd in (-1, 1):
        blade(a, *q.pt(0.1), (0 if sd > 0 else 180) - sd * 30, 26, 10, lc, "mint", teeth=7, td=1.3, veins=4, lw=0.9, midw=0.7, pucker=True)
    n = 11
    for j in range(n):
        v = j / (n - 1); u = 0.3 + 0.64 * v ** 0.8 + (0.03 if j == 0 else 0)
        x, y = q.pt(u); sc = 2.1 - 1.0 * v; w = 11 - 6.5 * v
        ring(a, x, y, w, sc, fc, lc, front=v < 0.85)
    e = q.pt(1)
    for dx in (-1.2, 0, 1.2):
        a.oval(e[0] + dx, e[1] + 1 + abs(dx), 1.2, 1.6, 0, fc, 0.5)
    return a


def fl_balm(a, sp):
    """Lemon balm: small white two-lipped flowers in loose clusters in the
    joints of the upper leaves, half hidden among them; hairy calyces; buds
    pale yellow. No spike."""
    fc = sp["fc"]; lc = sp.get("lc", "leaf")
    q = spike_stem(a, (52, 4), (50, 98), 3.0, 1.6, bow=-1)
    for u, L, droop in ((0.14, 30, 16), (0.56, 22, 4)):   # two pairs of broad toothed leaves on stalks
        x, y = q.pt(u)
        for sd in (-1, 1):
            ang = (0 if sd > 0 else 180) + sd * droop
            e = T(x, y, ang)(6)
            stalk(a, (x, y), T(x, y, ang)(3, 0.5), e, 1.8, 1.4, lc)
            blade(a, e[0], e[1], ang, L, L * 0.76, lc, "balm", teeth=7, td=1.6, tk="round", veins=3, lw=0.9,
                  midw=0.7, pucker=True, hairs=8)
    for u, s0 in ((0.14, 2.3), (0.56, 1.9)):   # the flowers, in the joints just above each pair
        x, y = q.pt(u)
        for sd in (-1, 1):
            for j, (off, s) in enumerate(((-70, 0.85), (-36, 1.0), (-6, 0.9))):
                ang = (0 if sd > 0 else 180) + sd * off
                lip_flower(a, x + sd * 1.2, y - 2.0 - j * 0.8, ang, s0 * s, fc, lc, "short", "three", "hidden",
                           cal="two", hairs=True)
            bud_lip(a, x + sd * 1.0, y - 4.5, -90 + sd * 20, s0 * 0.75, "primrose", lc)
    for sd in (-1, 1):   # the young leaves at the tip
        blade(a, *q.pt(0.9), -90 + sd * 34, 11, 7, lc, "balm", veins=0, lw=0.8, midw=0.5)
    return a


def fl_catnip(a, sp):
    """Catnip: small white two-lipped flowers, the broad cupped lower lip
    dotted purple-pink, crowded in rings into a dense head at the stem top,
    the lowest ring a little apart; downy ribbed tube-shaped calyces."""
    fc = sp["fc"]; lc = sp.get("lc", "sage"); spot = sp.get("cen", "mauve")
    q = spike_stem(a, (50, 14), (51, 98), 3.2, 1.6, bow=-0.6)
    for sd in (-1, 1):   # a pair of the grey heart-shaped leaves below
        x, y = q.pt(0.12); ang = (0 if sd > 0 else 180) + sd * 14
        e = T(x, y, ang)(5); stalk(a, (x, y), T(x, y, ang)(2.5, 0.4), e, 1.8, 1.3, lc)
        blade(a, e[0], e[1], ang, 24, 17, lc, "catnip", back=0.1, teeth=8, td=1.5, tk="blunt", veins=3, lw=0.9, midw=0.6, hairs=10)
    rings = [(0.42, 2.3, 16), (0.62, 2.2, 13), (0.76, 2.0, 11), (0.88, 1.7, 8)]
    for j, (u, s, w) in reversed(list(enumerate(rings))):   # the top ring first, so the lower rings lie in front
        x, y = q.pt(u)
        for sd in (-1, 1):
            for off, k in ((-58, 0.85), (-16, 1.0)):
                lip_flower(a, x + sd * 1.0, y + 0.8, (0 if sd > 0 else 180) + sd * off, s * k, fc, lc, "short", "cup", "hidden",
                           spots=spot, cal="tube", ribs=2, hairs=True)
    e = q.pt(1)
    for sd in (-1, 0, 1):
        bud_lip(a, e[0] + sd * 1.4, e[1] + 1, -90 + sd * 26, 1.2, fc, lc)
    return a


def fl_oregano(a, sp):
    """Oregano: many tiny pink-purple flowers in dense short spikes, each
    flower against a dark red-purple bract, the spikes on stalks that branch
    in pairs from the stem, together making a loose, flat-topped head."""
    fc = sp["fc"]; br = sp.get("cen", "plum"); stc = sp.get("stemc", "plum"); lc = sp.get("lc", "deep")
    q0 = Quad((51, 98), (50, 80), (50, 62))
    a.ribbon(q0.p0, q0.c, q0.p1, 3.0, 2.4, stc, lw=0.8)
    q = Quad((50, 62), (50, 52), (50, 40))
    a.ribbon(q.p0, q.c, q.p1, 2.4, 2.0, stc, lw=0.8)
    for sd in (-1, 1):   # a pair of the small oval leaves under the head
        blade(a, *q0.pt(0.3), (0 if sd > 0 else 180) - sd * 22, 15, 10, lc, "oregano", veins=2, lw=0.8, midw=0.5, hairs=6)
    tips = []
    for u, dx, top in ((0.3, 34, 33), (0.62, 22, 27), (0.88, 11, 24)):   # pairs of side branches up to one level
        x, y = q.pt(u)
        for sd in (-1, 1):
            e = (50 + sd * dx, top)
            a.ribbon((x, y), (x + sd * dx * 0.75, y - 2), e, 1.6, 1.0, stc, lw=0.7)
            blade(a, x, y, -90 + sd * 64, 7, 4.6, lc, "oregano", veins=0, lw=0.7, midw=0.4)
            tips.append(e)
    e = q.pt(1); a.ribbon(e, (50, 30), (50, 21), 1.6, 1.1, stc, lw=0.7); tips.append((50, 21))
    for x, y in sorted(tips, key=lambda p: -p[1]):
        t = T(x, y, -90); g = 1.3
        for j in range(5):   # the overlapping bracts, packed into a short cone
            p = t(j * 2.4 * g)
            for sd in (-1, 1):
                a.leaf(p[0], p[1], -90 + sd * 54, (5.4 - j * 0.6) * g, 0.58, br, lw=0.6, detail=False)
        for j in range(4):   # the tiny flowers poking out between them
            p = t((1.2 + j * 2.4) * g); sd = 1 if (j + int(x)) % 2 else -1
            ang2 = -90 + sd * (66 - 8 * j)
            e2 = T(*p, ang2)(3.8 * g)
            a.ribbon(p, T(*p, ang2)(1.9 * g), e2, 1.0 * g, 1.6 * g, fc, lw=0.5)
            a.leaf(e2[0], e2[1], ang2 - sd * 36, 2.9 * g, 0.64, fc, lw=0.5, detail=False)
            a.leaf(e2[0], e2[1], ang2 + sd * 30, 2.6 * g, 0.6, fc, lw=0.5, detail=False)
            for o in (-6, 8):
                s2 = T(*e2, ang2 + o)(2.8 * g); a.line(f"M{P(e2)} L{P(s2)}", 0.35, 0.8); a.dot(s2[0], s2[1], 0.4, "plum")
    return a


def shoot_with(a, sp, q, us, L, W, fill, pf, spread=48, tufts=False, **kw):
    """Narrow leaves in pairs along a close-up shoot q."""
    for i, u in enumerate(us):
        x, y = q.pt(u); ang = q.ang(u); l = L * (1 - 0.3 * u)
        for sg in (1, -1):
            nleaf(a, x, y, ang + sg * spread, l, l * W, fill, pf, lw=0.85, **kw)
            if tufts:
                tuft(a, x, y, ang + sg * 18, l * 0.34, l * 0.34 * W * 1.2, fill, pf)


def fl_hyssop(a, sp):
    """Hyssop: deep violet-blue two-lipped flowers with long stamens sticking
    well out, in clusters in the upper leaf joints, together a dense spike,
    the flowers mostly turned to one side; narrow leaves right up to it."""
    fc = sp["fc"]; lc = sp.get("lc", "deep")
    q = spike_stem(a, (46, 6), (52, 98), 2.8, 1.3, bow=-3)
    shoot_with(a, sp, q, (0.08, 0.26), 26, 0.2, lc, "hyssop", spread=46, tufts=True)
    for j, u in enumerate((0.38, 0.5, 0.6, 0.69, 0.77, 0.84, 0.9)):   # clusters up the spike, all facing right
        x, y = q.pt(u); s = 1.75 - 0.08 * j
        nleaf(a, x, y, q.ang(u) - 70, 9 - j * 0.6, 2.0, lc, "hyssop", lw=0.7)
        for off, k in ((-40, 0.8), (-6, 1.0), (24, 0.85)):
            lip_flower(a, x + 0.8, y, off, s * k, fc, sp.get("calc", "plum"), "short", "three", "long", cal="tube", ribs=1)
    e = q.pt(1)
    for off in (-30, 10, 40):
        bud_lip(a, e[0], e[1] + 2, -90 + off, 1.1, fc, sp.get("calc", "plum"))
    return a


def fl_lavender(a, sp):
    """Lavender: rings of small violet-purple flowers in hairy, ribbed,
    grey-purple calyces, packed into a slender spike at the top of a long,
    bare, square stalk, the lowest ring a little apart."""
    fc = sp["fc"]; calc = sp.get("calc", "plum"); stc = sp.get("stemc", "sage")
    q = spike_stem(a, (50, 6), (52, 98), 2.6, 1.6, fill=stc, bow=0.5)
    a.line(opath([q.pt(u) for u in (0.0, 0.2, 0.4)]), 0.4, 0.4)   # the square stalk's edge
    rings = [0.46, 0.6, 0.67, 0.74, 0.8, 0.86, 0.91, 0.95]
    for j, u in reversed(list(enumerate(rings))):
        x, y = q.pt(u); s = 1.55 - 0.06 * j
        if j < len(rings) - 2:
            for off in (-30, 0, 30):   # small papery bracts under the ring
                a.leaf(x, y + 1.5, 90 + off, 3.4, 0.5, "seed", lw=0.5, detail=False)
            for sd in (-1, 1):
                for off, k in ((-70, 0.9), (-36, 1.0)):
                    lip_flower(a, x + sd * 0.8, y, (0 if sd > 0 else 180) + sd * off, s * k, fc, calc, "short", "three",
                               "hidden", cal="tube", ribs=2, hairs=True)
        else:   # buds at the tip: the calyces with the colour of the petals showing
            for sd in (-1, 1):
                bud_lip(a, x + sd * 0.6, y, -90 + sd * 34, s, fc, calc)
    return a


def fl_rosemary(a, sp):
    """Rosemary: pale blue two-lipped flowers, a hooded upper lip and a big
    hanging cupped lower lip spotted darker, two long stamens arching up out
    of the hood; a few together in the leaf joints among the needle leaves."""
    fc = sp["fc"]; lc = sp.get("lc", "marrow")
    q = Quad((30, 98), (38, 56), (66, 6))
    a.ribbon(q.p0, q.c, q.p1, 3.0, 1.4, "bark", lw=0.8)
    shoot_with(a, sp, q, even(9, 0.05, 0.94), 22, 0.12, lc, "strap", spread=40, under="white", rolled=True)
    for u, sd, s in ((0.3, 1, 2.3), (0.58, -1, 2.0)):
        x, y = q.pt(u)
        for off, k in ((-18, 1.0), (18, 0.85)):
            ang = (0 if sd > 0 else 180) + sd * off
            lip_flower(a, x, y, ang, s * k, fc, sp.get("calc", "leaf"), "hood", "cup", "arch", spots=sp.get("cen", "plum"),
                       cal="two", anth="plum")
    return a


def fl_sage(a, sp):
    """Sage: big violet two-lipped flowers with a helmet-shaped upper lip and
    a broad lower lip, in spaced rings up an upright spike, each in a purple
    tinged two-lipped calyx."""
    fc = sp["fc"]; calc = sp.get("calc", "plum")
    q = spike_stem(a, (50, 6), (51, 98), 3.0, 1.4, fill=sp.get("stemc", "sage"))
    for u, s in ((0.24, 2.4), (0.52, 2.15), (0.77, 1.8)):
        x, y = q.pt(u)
        for sd in (-1, 1):
            lip_flower(a, x + sd * 0.8, y, (0 if sd > 0 else 180) - sd * 18, s, fc, calc, "hood", "three", "hidden",
                       cal="two", lw=0.7)
        a.leaf(x, y + 1.2, 180, 4, 0.5, "sage", lw=0.5, detail=False); a.leaf(x, y + 1.2, 0, 4, 0.5, "sage", lw=0.5, detail=False)
    for j, u in enumerate((0.9, 0.96)):
        x, y = q.pt(u)
        for sd in (-1, 1):
            bud_lip(a, x + sd * 0.5, y, -90 + sd * 36, 1.3 - 0.2 * j, fc, calc)
    return a


def fl_savory(a, sp):
    """Winter savory: small white two-lipped flowers, the lower lip spotted
    purple, in small clusters in the joints of the upper leaves, making a
    loose leafy spike."""
    fc = sp["fc"]; lc = sp.get("lc", "deep")
    q = spike_stem(a, (52, 6), (48, 98), 2.6, 1.2, fill=sp.get("stemc", "bark"), bow=2)
    for j, u in enumerate((0.16, 0.42, 0.66, 0.86)):
        x, y = q.pt(u); s = 2.0 - 0.18 * j
        for sd in (-1, 1):
            nleaf(a, x, y, q.ang(u) + sd * 50, 20 - 3 * j, (20 - 3 * j) * 0.2, lc, "savory", lw=0.85, gloss=True)
            if j:
                for off, k in ((-46, 0.85), (-10, 1.0)):
                    lip_flower(a, x + sd * 0.8, y - 1, (0 if sd > 0 else 180) + sd * off, s * k, fc, sp.get("calc", "leaf"),
                               "short", "three", "out", spots=sp.get("cen", "mauve"), cal="cup")
    return a


def fl_thyme(a, sp):
    """Thyme: tiny pale pink-lilac two-lipped flowers in purple-tinged hairy
    calyces, packed into small rounded heads at the shoot tips."""
    fc = sp["fc"]; calc = sp.get("calc", "plum"); lc = sp.get("lc", "sage")
    for (p0, c, p1, R, n) in (((44, 98), (40, 70), (40, 40), 12, 1.0), ((48, 98), (60, 76), (70, 56), 9, 0.8)):
        q = Quad(p0, c, p1)
        a.ribbon(q.p0, q.c, q.p1, 1.8, 1.2, "bark", lw=0.7)
        shoot_with(a, sp, q, (0.15, 0.4, 0.64), 9, 0.36, lc, "thyme", spread=55, tufts=True, rolled=True)
        x, y = q.pt(1); y -= R * 0.55
        for j in range(int(14 * n)):   # flowers all round the head, those at the back first
            th = math.radians(-90 + (j * 137.5) % 360); r = R * (0.55 + 0.45 * ((j * 0.37) % 1))
            ang = math.degrees(th)
            lip_flower(a, x + math.cos(th) * R * 0.3, y + math.sin(th) * R * 0.3, ang, 1.15 * n, fc, calc, "short", "three",
                       "out", cal="cup", lw=0.5)
        for j in range(int(7 * n)):   # and those facing you, filling the middle of the head
            rr = R * 0.42 * math.sqrt((j + 0.5) / (7 * n)); th = j * GOLD
            px, py = x + rr * math.cos(th), y + rr * math.sin(th)
            a.leaf(px, py + 1.2, -90 + (j * 40) % 60 - 30, 3.6 * n, 0.6, fc, lw=0.5, detail=False)
            a.leaf(px, py + 1.2, 90 + (j * 40) % 60 - 30, 3.0 * n, 0.55, fc, lw=0.5, detail=False)
            a.dot(px, py + 1.2, 0.45, calc)
    return a


def fl_bay(a, sp):
    """Bay: small creamy yellow fluffy flowers, four small tepals round many
    stamens (the male plant), in small clusters close in the leaf joints,
    each cluster in a cup of rounded bud scales."""
    fc = sp["fc"]; lc = sp.get("lc", "marrow"); cen = sp.get("cen", "sun")
    q = Quad((34, 98), (42, 56), (60, 6))
    a.ribbon(q.p0, q.c, q.p1, 3.0, 1.8, "rust", lw=0.8)
    for u, sd, L in ((0.18, 1, 44), (0.5, -1, 38), (0.78, 1, 30)):
        x, y = q.pt(u)
        blade(a, x, y, q.ang(u) + sd * 52, L, L * 0.34, lc, "bay", wave=0.6, nw=4, veins=4, lw=0.9, midw=0.7, gloss=True,
              rim="pale")
    for u, sd in ((0.18, -1), (0.5, 1), (0.78, -1)):   # the clusters, on the side away from each leaf
        x, y = q.pt(u)
        hub = (x + sd * 3, y - 1)
        for k in range(3):
            a.oval(hub[0] - sd * 0.5 + (k - 1) * 1.6, hub[1] + 1.6, 1.6, 1.2, 0, "seed", 0.6)   # bud scales
        for k, (dx, dy) in enumerate(((0, -4), (sd * 6, -1), (sd * 4, 4), (-sd * 3, -7), (sd * 8, -7))):
            fx, fy = hub[0] + dx, hub[1] + dy
            a.line(f"M{P(hub)} L{f(fx)},{f(fy)}", 0.6, 0.8)
            a.flower(fx, fy, 3.2, 4, fc, None, 0.7, start=-45 + k * 20, lw=0.55)
            for m in range(10):   # the many stamens: fluffy
                e = T(fx, fy, m * 36 + k * 9)(1.2 + 1.6 * ((m * 0.618) % 1))
                a.line(f"M{f(fx)},{f(fy)} L{P(e)}", 0.35, 0.55)
                a.dot(e[0], e[1], 0.42, cen)
    return a


def fl_wormwood(a, sp):
    """Wormwood: many tiny round button-like heads with no petals, dull pale
    yellow, nodding on short stalks along the branches of a leafy spray, each
    in a cup of grey hairy bracts."""
    fc = sp["fc"]; lc = sp.get("lc", "herbs_silver")
    q = spike_stem(a, (48, 6), (52, 98), 2.8, 1.2, fill=lc, bow=-1)
    for u, sd, L in ((0.3, -1, 32), (0.5, 1, 28), (0.7, -1, 22)):   # side branches, a small narrow leaf at each joint
        x, y = q.pt(u)
        nleaf(a, x, y, -90 + sd * 64, 12, 2.4, lc, "seg", lw=0.7)
        br = Quad((x, y), (x + sd * L * 0.5, y - 6), (x + sd * L, y - 4))
        a.ribbon(br.p0, br.c, br.p1, 1.4, 0.8, lc, lw=0.6)
        for v in (0.35, 0.62, 0.9):
            hx, hy = br.pt(v); _head(a, hx, hy, 3.4 - v, fc)
    for v in (0.82, 0.9, 0.97):
        hx, hy = q.pt(v); _head(a, hx + (2 if v < 0.9 else -2), hy, 2.6, fc)
    return a


def _head(a, x, y, r, fc):
    """One nodding wormwood head on its short stalk: the grey bracts cupping
    the top, the yellow ball of tiny tube flowers hanging below."""
    a.line(f"M{f(x)},{f(y)} q0.8,1.6 0,{f(r * 1.2)}", 0.6, 0.85)
    cx, cy = x, y + r * 1.2 + r * 0.9
    a.oval(cx, cy, r, r * 0.92, 0, fc, 0.6)
    for k in range(7):
        rr = r * 0.6 * math.sqrt((k + 0.5) / 7); a.dot(cx + rr * math.cos(k * GOLD), cy + r * 0.2 + rr * 0.7 * math.sin(k * GOLD), 0.32, "amber")
    for off in (-50, -20, 20, 50):   # the grey hairy bracts over the top
        a.leaf(cx, cy - r * 0.95, 90 + off, r * 1.1, 0.5, "sage", lw=0.45, detail=False)


BLOOM_DRAW = {"herbs_basil": fl_basil, "herbs_mint": fl_mint, "herbs_balm": fl_balm, "herbs_catnip": fl_catnip,
              "herbs_oregano": fl_oregano, "herbs_hyssop": fl_hyssop, "herbs_lavender": fl_lavender,
              "herbs_rosemary": fl_rosemary, "herbs_sage": fl_sage, "herbs_savory": fl_savory, "herbs_thyme": fl_thyme,
              "herbs_bay": fl_bay, "herbs_wormwood": fl_wormwood}

LEAFX = {
    "sage": dict(kind="herbs_leaf", fill="sage", pf="sage", W=0.36, petiole=0.24, teeth=26, td=0.9, tk="tiny",
                 tfrom=0.04, veins=6, vang=0.16, pucker=True, quilt=True, hairs=20),
    "bay": dict(kind="herbs_leaf", fill="marrow", pf="bay", W=0.36, petiole=0.12, stalkc="rust", teeth=0, wave=0.9, nw=5,
                veins=7, vang=0.14, gloss=True, rim="pale"),
    "rosemary": dict(kind="herbs_sprig", fill="marrow", stemc="bark", n=9, nl=30, nw=0.11, pf="strap", under="white",
                     rolled=True, spread=42, taper=0.4, sw=2.8),
    "lavender": dict(kind="herbs_sprig", fill="sage", stemc="sage", n=7, nl=32, nw=0.11, pf="strap", felt=True,
                     rolled=True, tufts=True, spread=34, taper=0.42),
    "hyssop": dict(kind="herbs_sprig", fill="deep", stemc="leaf", n=7, nl=28, nw=0.2, pf="hyssop", tufts=True,
                   gloss=True, spread=46, taper=0.4),
    "savory": dict(kind="herbs_sprig", fill="deep", stemc="bark", n=7, nl=22, nw=0.2, pf="savory", tufts=True,
                   gloss=True, spread=46, taper=0.35),
    "thyme": dict(kind="herbs_sprig", fill="sage", stemc="bark", n=10, nl=11, nw=0.34, pf="thyme", tufts=True,
                  rolled=True, spread=52, taper=0.3, sw=1.6, p0=(36, 97), c=(44, 56), p1=(62, 10)),
    "tarragon": dict(kind="herbs_sprig", fill="deep", stemc="leaf", alt=True, n=8, nl=44, nw=0.1, pf="tarragon",
                     gloss=True, spread=26, taper=0.45, sw=2.2),
    "wormwood": dict(kind="herbs_cut", fill="herbs_silver", segW=2.7),
    "cat-nip": dict(kind="herbs_leaf", fill="sage", pf="catnip", back=0.18, W=0.76, petiole=0.24, teeth=11, td=2.4,
                    tk="blunt", tfrom=0.04, veins=5, vang=0.18, pucker=True, hairs=26, under="white"),
    "oregano": dict(kind="herbs_sprig", fill="deep", stemc="plum", n=6, nl=22, nw=0.64, pf="oregano", stalkL=0.16,
                    hairs=3, spread=58, taper=0.4, u0=0.08, u1=0.86),
    "lemon-balm": dict(kind="herbs_leaf", fill="leaf", pf="balm", W=0.8, petiole=0.28, teeth=10, td=2.6, tk="round",
                       tfrom=0.05, veins=5, vang=0.18, pucker=True, quilt=True, hairs=14),
    "mint": dict(kind="herbs_leaf", fill="leaf", pf="mint", W=0.38, petiole=0.0, teeth=13, td=2.2, tk="saw",
                 tfrom=0.05, veins=7, vang=0.14, pucker=True, quilt=True),
    "basil": dict(kind="herbs_leaf", fill="leaf", pf="basil", W=0.58, petiole=0.24, teeth=3, td=0.6, tk="round",
                  tfrom=0.5, wave=0.3, nw=3, veins=5, vang=0.2, pucker=True, gloss=True, cup=True),
}
BLOOMX = {
    "hyssop": dict(kind="herbs_hyssop", fc="herbs_violet", lc="deep", calc="plum"),
    "lavender": dict(kind="herbs_lavender", fc="herbs_lavender", calc="plum", stemc="sage"),
    "rosemary": dict(kind="herbs_rosemary", fc="blue", cen="plum", lc="marrow", calc="leaf"),
    "sage": dict(kind="herbs_sage", fc="herbs_salvia", calc="plum", stemc="sage"),
    "savory": dict(kind="herbs_savory", fc="white", cen="mauve", lc="deep", calc="leaf", stemc="bark"),
    "thyme": dict(kind="herbs_thyme", fc="pink", calc="plum", lc="sage"),
    "bay": dict(kind="herbs_bay", fc="primrose", cen="sun", lc="marrow"),
    "wormwood": dict(kind="herbs_wormwood", fc="primrose", lc="herbs_silver"),
    "tarragon": None,
    "cat-nip": dict(kind="herbs_catnip", fc="white", cen="mauve", lc="sage"),
    "oregano": dict(kind="herbs_oregano", fc="mauve", cen="plum", lc="deep", stemc="plum"),
    "lemon-balm": dict(kind="herbs_balm", fc="white", lc="leaf"),
    "mint": dict(kind="herbs_mint", fc="lilac", lc="leaf"),
    "basil": dict(kind="herbs_basil", fc="white", calc="leaf"),
}
KIND = {k: dict(leaf="own") for k in ("basil", "mint", "lemon-balm", "cat-nip", "sage", "bay")}


# ============================================================ life stages: helpers
_OWN = {}


def own(a, kind, x, y, ang, L, fill=None, detail=None, lw=None):
    """The kind's own close-up leaf (herbs_leaf), drawn L long at x,y pointing
    along ang. fill swaps its colour (a yellowing or frosted leaf)."""
    import leaves_flowers as LFW
    if kind not in _OWN:
        _OWN[kind] = LFW.own_leaf(kind)
    src, of = _OWN[kind]
    rec = {of: fill} if fill and fill != of else None
    with a.on(LEAF):
        a.place(src, x, y, ang, L / 92, lw=lw or (0.7 if L < 14 else 0.85), detail=(L >= 12) if detail is None else detail, fills=rec)


def own_draw(kind, fill=None):
    """A leaf-drawing function for pairs() and singles(): the kind's own leaf."""
    return lambda a, x, y, ang, L: own(a, kind, x, y, ang, L, fill)


def narrow_draw(fill, W=0.18, pf="strap", lw=0.55, **kw):
    """A leaf-drawing function for pairs() and singles(): a small narrow leaf."""
    def d(a, x, y, ang, L):
        with a.on(LEAF):
            nleaf(a, x, y, ang, L, L * W, fill, pf, lw=lw, **kw)
    return d


def stem(a, p0, c, p1, w0=2.0, w1=1.0, col="leaf", lw=0.75):
    """One stem, as a band that narrows towards its top."""
    return a.ribbon(p0, c, p1, w0, w1, col, lw=lw)


def shoot(a, x0, y0, top, lean, bow=0.0, w0=2.0, w1=1.0, col="leaf"):
    """A stem from x0,y0 up to height top, its tip lean to one side."""
    p1 = (x0 + lean, top)
    return stem(a, (x0, y0), (x0 + lean * 0.3 + bow, (y0 + top) / 2), p1, w0, w1, col)


def pairs(a, draw, q, us, L, spread=60, cross=True, shrink=0.3, tip=True, tipk=0.55, end=1.0):
    """Leaves in opposite pairs along stem q at the points us (0 the foot, 1
    the tip). With cross=True every other pair is turned to face you, its two
    leaves shorter and pointing more up and down: so each pair is seen at
    right angles to the one below, as on the real plant."""
    with a.on(LEAF):
        for i, u in enumerate(us):
            x, y = q.pt(u); ang = q.ang(u); l = L * (1 - shrink * u)
            if cross and i % 2:
                draw(a, x, y, ang - spread * 0.42, l * 0.74); draw(a, x, y, ang + spread * 0.42, l * 0.74)
            else:
                draw(a, x, y, ang - spread, l); draw(a, x, y, ang + spread, l)
        if tip:
            x, y = q.pt(end); ang = q.ang(end)
            draw(a, x, y, ang - 22, L * tipk); draw(a, x, y, ang + 22, L * tipk)


def singles(a, draw, q, us, L, spread=55, shrink=0.3, tip=True, start=1):
    """Leaves set singly along stem q, first one side then the other."""
    with a.on(LEAF):
        for i, u in enumerate(us):
            x, y = q.pt(u); ang = q.ang(u); sd = start if i % 2 else -start
            draw(a, x, y, ang + sd * spread, L * (1 - shrink * u))
        if tip:
            x, y = q.pt(1); draw(a, x, y, q.ang(1) + 6, L * 0.5)


def even(n, u0=0.18, u1=0.88):
    return [u0 + (u1 - u0) * i / max(1, n - 1) for i in range(n)]


def soil(a, y=88):
    a.ground(y)
    return a


def sown(seed_fn):
    """The 'seed' stage: seeds drawn large under the soil line (as plants.sown)."""
    return S10.sown(seed_fn)


def kidney(a, x, y, ang, w, h, fill, lw=0.8, squash=0.5):
    """A seed leaf on a short stalk from x,y along ang, h from the stalk to
    the far edge and w across. It is held flat and seen from a little above,
    so its width is drawn squashed (squash), and a small notch marks where
    the stalk joins: a kidney-shaped seed leaf, wider than long."""
    t = T(x, y, ang)
    a.line(f"M{f(x)},{f(y)} L{P(t(h * 0.22))}", 0.9, 0.85)
    c = t(h * 0.22 + h * 0.5)
    a.polar(c[0], c[1], lambda th: 1 - 0.2 * math.exp(-((th - math.pi) / 0.45) ** 2), h * 0.5, w * 0.5 * squash, ang, fill, lw)


def seedling_base(a):
    """Soil, roots and the seedling's stem: returns the top of the stem."""
    a.ground(S10.G); a.roots(50, S10.G, 3, 11, 50)
    return a


# ---- flowers at plant scale
def mini_lip(a, x, y, ang, s, fc, calc="leaf", spot=None):
    """A two-lipped flower at plant scale: a small tube and two lips."""
    with a.on(BLOOM):
        t = T(x, y, ang); up = -1 if math.cos(math.radians(ang)) >= 0 else 1
        e = t(2.4 * s)
        a.leaf(e[0], e[1], ang + up * 48, 3.0 * s, 0.6, fc, lw=0.5, detail=False)
        a.leaf(e[0], e[1], ang - up * 38, 3.0 * s, 0.55, fc, lw=0.5, detail=False)
        a.leaf(x, y, ang, 2.2 * s, 0.36, calc, lw=0.45, detail=False)
        if spot:
            p = T(*e, ang - up * 38)(1.7 * s); a.dot(p[0], p[1], 0.48, spot)


def whorl_spike(a, q, u0, u1, n, s, fc, calc="leaf", bract="leaf", spot=None, buds=2, spread=20, dry=False):
    """Tiers of small two-lipped flowers up the top of stem q (from u0 to
    u1), each tier a flower to each side over a pair of tiny bracts. dry: the
    tiers are left as brown papery calyces."""
    with a.on(BLOOM):
        for j in range(n):
            u = u0 + (u1 - u0) * j / max(1, n - 1); x, y = q.pt(u); ang = q.ang(u)
            k = 1 - 0.25 * j / max(1, n - 1)
            if j >= n - buds and not dry:   # buds at the tip
                for sd in (-1, 1):
                    a.leaf(x, y, ang + sd * 34, 2.6 * s * k, 0.42, calc, lw=0.5, detail=False)
                continue
            for sd in (-1, 1):
                a.leaf(x, y + 0.6, ang + 180 - sd * 100, 2.4 * s, 0.5, "straw" if dry else bract, lw=0.45, detail=False)
                if dry:
                    a.leaf(x, y, ang + sd * (90 - spread), 3.2 * s * k, 0.42, "seed", lw=0.55, detail=False)
                else:
                    mini_lip(a, x, y, ang + sd * (90 - spread), s * k, fc, calc, spot)
        if dry:
            e = q.pt(u1); a.leaf(e[0], e[1], q.ang(u1), 2.4 * s, 0.4, "seed", lw=0.5, detail=False)


# ============================================================ basil
def basil_seed(a, x, y):
    """Three small oval matt black seeds."""
    for dx, dy, r in ((-8, 1, -20), (7, -3, 25), (1, 9, 80)):
        a.oval(x + dx, y + dy, 7.4, 4.8, r, "dark", 1.0)
        a.line(f"M{P(T(x + dx, y + dy, r)(-3.6, -1.6))} Q{P(T(x + dx, y + dy, r)(0, -2.8))} {P(T(x + dx, y + dy, r)(3.6, -1.6))}", 0.5, 0.35)


def basil_stages():
    k = "basil"; fc = pal(k).get("flower", "white"); lc = pal(k).get("leaf", "leaf")
    L = own_draw(k)

    def seedling():
        a = seedling_base(Art()); G = S10.G
        q = stem(a, (50, G), (49.4, G - 9), (50, G - 17), 1.8, 1.4, "pale")
        with a.on(LEAF):
            kidney(a, 50, G - 17, -172, 15, 12, "pale", squash=0.62); kidney(a, 50, G - 17, -8, 15, 12, "pale", squash=0.62)
            own(a, k, 50, G - 17, -118, 12.5); own(a, k, 50, G - 17, -62, 12.5)
        return a

    def frame(a, h=1.0, side=True):
        """The main stem and, on a bigger plant, the branches from its lower joints."""
        qs = [shoot(a, 50, 88, 88 - 62 * h, 1, 1.0, 2.6, 1.3)]
        if side:
            m1 = qs[0].pt(0.22); m2 = qs[0].pt(0.42)
            qs.append(stem(a, m1, (m1[0] - 12, m1[1] - 6), (m1[0] - 23, m1[1] - 34 * h), 1.9, 1.0))
            qs.append(stem(a, m1, (m1[0] + 12, m1[1] - 6), (m1[0] + 23, m1[1] - 32 * h), 1.9, 1.0))
            qs.append(stem(a, m2, (m2[0] - 7, m2[1] - 6), (m2[0] - 14, m2[1] - 26 * h), 1.6, 0.9))
            qs.append(stem(a, m2, (m2[0] + 7, m2[1] - 6), (m2[0] + 15, m2[1] - 25 * h), 1.6, 0.9))
        return qs

    def young():
        a = soil(Art())
        with a.group():
            q = shoot(a, 50, 88, 48, 0.5, 0.5, 2.2, 1.2)
            pairs(a, L, q, (0.16, 0.45, 0.74), 21, spread=66, shrink=0.3)
        return a

    def leafy(a, qs, top=True, fill=None, Lk=1.0, few=False):
        D = own_draw(k, fill)
        pairs(a, D, qs[0], (0.1, 0.3, 0.52, 0.72, 0.88) if not few else (0.1, 0.52), 21 * Lk, spread=66, tip=top)
        for q in qs[1:]:
            pairs(a, D, q, (0.42, 0.78) if not few else (0.55,), 18 * Lk, spread=58, tip=top)

    def crop():
        a = soil(Art())
        with a.group():
            qs = frame(a); leafy(a, qs)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = frame(a, 0.9); leafy(a, qs, top=False, Lk=0.95)
            for q, n in zip(qs, (5, 4, 4, 3, 3)):   # each shoot ends in a spike of spaced tiers
                e = q.pt(1); ang = q.ang(1)
                sp = stem(a, e, T(*e, ang)(7), T(*e, ang + 2)(15 if n > 3 else 11), 1.0, 0.7)
                whorl_spike(a, sp, 0.05, 1.0, n, 1.15, fc, "leaf")
        return a

    def seedhead():
        a = soil(Art())
        with a.group():
            qs = frame(a, 0.9); leafy(a, qs, top=False, Lk=0.85, few=True, fill="pear")
            for q, n in zip(qs, (6, 5, 5, 4, 4)):   # old spikes with tiers of brown papery calyces
                e = q.pt(1); ang = q.ang(1)
                sp = stem(a, e, T(*e, ang)(8), T(*e, ang + 2)(17 if n > 4 else 13), 1.0, 0.7, "straw")
                whorl_spike(a, sp, 0.05, 1.0, n, 1.15, fc, dry=True)
        return a

    return {"seed": sown(basil_seed), "seedling": seedling, "young": young, "crop": crop, "flower": flower,
            "seedhead": seedhead}


# ============================================================ mint
def runners(a, y=88, col="pale", spans=((-40, -6), (4, 40))):
    """Pale runners lying along the soil surface, rooting at their joints."""
    qs = []
    for x0, x1 in spans:
        q = a.ribbon((50 + x0, y + 0.6), ((100 + x0 + x1) / 2, y - 1.4), (50 + x1, y + 0.2), 2.0, 1.6, col, lw=0.7)
        for u in (0.25, 0.55, 0.85):
            x_, y_ = q.pt(u)
            a.line(f"M{f(x_)},{f(y_ + 0.8)} q-0.6,2.4 -1.4,4", 0.5, 0.7, "soil")
            a.line(f"M{f(x_)},{f(y_ + 0.8)} q0.8,2.2 1.6,3.4", 0.5, 0.7, "soil")
        qs.append(q)
    return qs


def mint_stages():
    k = "mint"; fc = pal(k).get("flower", "lilac")
    stems_at = ((-24, 30, -6), (-12, 22, -3), (0, 16, 1), (12, 21, 3), (24, 29, 6))

    def patch(a, h=1.0, n=5, Lf=17, tips=True, fill=None, top_us=0.9):
        qs = []
        for dx, top, lean in stems_at[:n] if n == 5 else stems_at[1:4]:
            qs.append(shoot(a, 50 + dx, 88, 88 - (88 - top) * h, lean, 0.4, 1.9, 1.0))
        D = own_draw(k, fill)
        for i, q in enumerate(qs):
            us = even(5 if h > 0.8 else 3, 0.14, top_us)
            pairs(a, D, q, us[i % 2:] if i % 2 else us, Lf, spread=58, shrink=0.3, tip=tips)
        return qs

    def young():
        a = soil(Art())
        with a.group():
            runners(a, spans=((-38, -4), (6, 38)))
            for x, top, lean in ((40, 56, -2), (60, 60, 2)):
                q = shoot(a, x, 88, top, lean, 0.3, 1.7, 1.0)
                pairs(a, own_draw(k), q, (0.2, 0.5, 0.78), 16, spread=58)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            runners(a)
            patch(a)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            runners(a)
            qs = patch(a, 0.86, tips=False, top_us=0.82)
            for q in qs:   # a slender tapering spike on each stem
                e = q.pt(1); ang = q.ang(1)
                sp = stem(a, e, T(*e, ang)(7), T(*e, ang)(16), 1.0, 0.6)
                with a.on(BLOOM):
                    for j in range(9):
                        u = 0.04 + 0.92 * j / 8; x, y = sp.pt(u); w = 2.6 * (1 - 0.55 * u)
                        a.oval(x, y, w, 1.3 + 0.3 * (1 - u), 0, fc, 0.5)
                        for sd in (-1, 1):
                            a.line(f"M{f(x + sd * w * 0.6)},{f(y)} l{f(sd * 1.4)},-0.6", 0.35, 0.8)
        return a

    def seedhead():
        a = soil(Art())
        with a.group():
            qs = patch(a, 0.86, tips=False, top_us=0.6, fill="pear")
            for q in qs:
                q2 = q
                e = q.pt(1); ang = q.ang(1)
                sp = stem(a, e, T(*e, ang)(7), T(*e, ang)(15), 1.0, 0.6, "straw")
                with a.on(BLOOM):
                    for j in range(8):
                        u = 0.04 + 0.92 * j / 7; x, y = sp.pt(u); w = 2.2 * (1 - 0.5 * u)
                        a.oval(x, y, w, 1.3, 0, "seed", 0.5)
        return a

    def dormant():
        a = soil(Art())
        runners(a, spans=((-42, -10), (-6, 22), (26, 42)))
        with a.group():   # a few small shoots at the joints
            for x, h in ((34, 8), (58, 10)):
                q = shoot(a, x, 88, 88 - h, 0.4, 0, 1.2, 0.8)
                pairs(a, own_draw(k), q, (0.55,), 8, spread=55, tipk=0.7)
        return a

    return {"young": young, "crop": crop, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ clumps
def clump(a, spec, col="leaf", y0=88):
    """Several stems from one crown: spec is [(foot x offset, top y, lean)]."""
    return [shoot(a, 50 + dx, y0, top, lean, 0.3, 1.9, 1.0, col) for dx, top, lean in spec]


def axil_cluster(a, x, y, sd, s, fc, calc="leaf", n=3, spot=None, up=-30):
    """A few small two-lipped flowers in a leaf joint, on side sd (1 right)."""
    for j in range(n):
        ang = (0 if sd > 0 else 180) + sd * (up - 26 * j + 26)
        mini_lip(a, x + sd * 0.6, y - 0.6 * j, ang, s * (1 - 0.1 * j), fc, calc, spot)


def dry_cluster(a, x, y, sd, s, n=3):
    """The dry brown calyces left in a leaf joint after flowering."""
    with a.on(BLOOM):
        for j in range(n):
            ang = (0 if sd > 0 else 180) + sd * (-60 + 30 * j)
            a.leaf(x, y - 0.5 * j, ang, 3.4 * s, 0.42, "seed", lw=0.5, detail=False)


def balm_seed(a, x, y):
    """Tiny shiny dark brown seeds, oval with one end narrower."""
    for k, (dx, dy, r) in enumerate(((-10, -2, 20), (2, -6, -30), (11, 0, 60), (-4, 7, 100), (8, 9, 10), (-14, 9, -50))):
        t = T(x + dx, y + dy, r)
        a.shape(f"M{P(t(-3.4, 0))} Q{P(t(-3.2, -2.4))} {P(t(0.6, -2.2))} Q{P(t(3.6, -1.2))} {P(t(3.8, 0))} Q{P(t(3.6, 1.2))} {P(t(0.6, 2.2))} Q{P(t(-3.2, 2.4))} {P(t(-3.4, 0))} Z", "dark", 0.8)
        a.dot(*t(-1.2, -0.9), 0.55, "white")


def balm_stages():
    k = "lemon-balm"; fc = pal(k).get("flower", "white")
    D = own_draw(k)
    spec = ((-6, 46, -30), (-3, 34, -13), (0, 28, 1), (3, 33, 14), (6, 45, 30))

    def seedling():
        a = seedling_base(Art()); G = S10.G
        stem(a, (50, G), (49.5, G - 7), (50, G - 13), 1.6, 1.2, "pale")
        with a.on(LEAF):
            for sd in (-1, 1):
                a.line(f"M50,{G - 13} l{f(sd * 3)},-0.6", 0.8, 0.85)
                a.oval(50 + sd * 7.5, G - 14, 4.6, 3.6, sd * -10, "pale", 0.8)
            own(a, k, 50, G - 13, -122, 13); own(a, k, 50, G - 13, -58, 13)
        return a

    def young():
        a = soil(Art())
        with a.group():
            qs = clump(a, ((-4, 66, -16), (0, 60, 0), (4, 66, 16)))
            for q in qs:
                pairs(a, D, q, (0.3, 0.75), 17, spread=62, tipk=0.6)
            for ang in (-168, -12):   # low leaves on long stalks from the crown
                own(a, k, 50, 87, ang, 19)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            qs = clump(a, spec)
            for i, q in enumerate(qs):
                pairs(a, D, q, (0.16, 0.38, 0.6, 0.8) if i % 2 == 0 else (0.26, 0.5, 0.72), 19, spread=60, shrink=0.3)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = clump(a, spec)
            for i, q in enumerate(qs):
                us = (0.16, 0.38, 0.6, 0.8) if i % 2 == 0 else (0.26, 0.5, 0.72)
                pairs(a, D, q, us, 18, spread=60, shrink=0.3)
                with a.on(BLOOM):
                    for u in us[1:]:
                        x, y = q.pt(u)
                        for sd in (-1, 1):
                            axil_cluster(a, x, y - 1, sd, 1.3, fc, "leaf", n=2)
        return a

    def seedhead():
        a = soil(Art())
        with a.group():
            qs = clump(a, spec, "straw")
            for i, q in enumerate(qs):
                us = (0.16, 0.38, 0.6, 0.8) if i % 2 == 0 else (0.26, 0.5, 0.72)
                pairs(a, own_draw(k, "pear"), q, us[:2], 15, spread=66, shrink=0.35, tip=False)
                for u in us[1:] + (0.95,):
                    x, y = q.pt(u)
                    for sd in (-1, 1):
                        dry_cluster(a, x, y - 0.5, sd, 1.0)
        return a

    def dormant():
        a = soil(Art())
        with a.group():
            for dx, top, lean in ((-6, 72, -5), (-2, 68, -1), (2, 70, 2), (6, 73, 5)):   # old stems cut back
                q = shoot(a, 50 + dx, 88, top, lean, 0, 1.8, 1.4, "straw")
                e = q.pt(1); a.line(f"M{f(e[0] - 1)},{f(e[1])} l2,-0.4", 0.8, 0.75)
            for ang, L in ((-164, 14), (-16, 14), (-136, 13), (-44, 13), (-110, 12), (-70, 12)):   # the low winter tuft
                own(a, k, 50, 87.5, ang, L)
        return a

    return {"seed": sown(balm_seed), "seedling": seedling, "young": young, "crop": crop, "flower": flower,
            "seedhead": seedhead, "dormant": dormant}


# ============================================================ catnip
def catnip_seed(a, x, y):
    """Small oval dark brown seeds, each with a small pale mark at one end."""
    for dx, dy, r in ((-8, -1, 15), (8, -4, -25), (0, 8, 70)):
        t = T(x + dx, y + dy, r)
        a.oval(x + dx, y + dy, 6.6, 4.2, r, "dark", 1.0)
        a.oval(*t(4.6, 0), 1.3, 1.6, r, "white", 0.5)


def head_small(a, q, n, s, fc, calc, spot=None, dry=False):
    """A dense head of flowers in crowded rings at the top of stem q, the
    lowest ring a little apart (catnip, at plant scale)."""
    e = q.pt(1); ang = q.ang(1)
    with a.on(BLOOM):
        if not dry:   # the mass of flowers behind
            c = T(*e, ang)(n * 1.0)
            a.oval(c[0], c[1], n * 1.5, 4.6 * s / 1.5, ang, fc, 0.6)
        for j in range(n):
            p = T(*e, ang)(-1 + j * 2.1 + (0 if j else -1.5)); k = 1 - 0.12 * j
            for sd in (-1, 1):
                for off in ((40, 76) if j < n - 1 else (40,)):
                    aa = ang + sd * off
                    if dry:
                        a.leaf(p[0], p[1], aa, 3.4 * s * k, 0.38, "seed", lw=0.5, detail=False)
                    else:
                        mini_lip(a, p[0], p[1], aa, s * k, fc, calc, spot)
        if not dry:
            tp = T(*e, ang)(-1 + n * 2.1)
            a.oval(tp[0], tp[1], 1.3, 1.7, ang + 90, calc, 0.5)


def catnip_stages():
    k = "cat-nip"; fc = pal(k).get("flower", "white"); spot = pal(k).get("centre", "mauve"); lc = pal(k).get("leaf", "sage")
    D = own_draw(k)
    spec = ((-6, 34, -26), (-3, 24, -12), (0, 18, 0), (3, 23, 12), (6, 33, 26))

    def seedling():
        a = seedling_base(Art()); G = S10.G
        stem(a, (50, G), (49.5, G - 7), (50, G - 13), 1.6, 1.2, "pale")
        with a.on(LEAF):
            for sd in (-1, 1):
                a.line(f"M50,{G - 13} l{f(sd * 3)},-0.6", 0.8, 0.85)
                a.oval(50 + sd * 7.2, G - 14, 4.4, 3.4, 0, "pale", 0.8)
            own(a, k, 50, G - 13, -120, 13.5); own(a, k, 50, G - 13, -60, 13.5)
        return a

    def young():
        a = soil(Art())
        with a.group():
            qs = clump(a, ((-4, 64, -14), (0, 56, 0), (4, 64, 14)), lc)
            for q in qs:
                pairs(a, D, q, (0.3, 0.72), 17, spread=60, tipk=0.6)
            for ang in (-170, -10):
                own(a, k, 50, 87, ang, 18)
        return a

    def plant(a, tops=True, fill=None):
        qs = clump(a, spec, lc)
        for i, q in enumerate(qs):
            us = (0.16, 0.4, 0.62) if i % 2 == 0 else (0.26, 0.52)
            pairs(a, own_draw(k, fill), q, us, 17, spread=58, shrink=0.35, tip=False)
        return qs

    def flower():
        a = soil(Art())
        with a.group():
            for q in plant(a):
                head_small(a, q, 5, 1.5, fc, lc, spot)
        return a

    def seedhead():
        a = soil(Art())
        with a.group():
            for q in plant(a, fill="pear"):
                head_small(a, q, 5, 1.2, fc, lc, dry=True)
        return a

    def dormant():
        a = soil(Art())
        with a.group():
            for dx, top, lean in ((-5, 74, -4), (0, 71, 0), (5, 74, 4)):
                q = shoot(a, 50 + dx, 88, top, lean, 0, 1.6, 1.2, "straw")
            for ang, L in ((-166, 13), (-14, 13), (-138, 12), (-42, 12), (-104, 11), (-76, 11)):
                own(a, k, 50, 87.5, ang, L)
        return a

    return {"seed": sown(catnip_seed), "seedling": seedling, "young": young, "flower": flower,
            "seedhead": seedhead, "dormant": dormant}


# ============================================================ oregano
def oval_draw(fill, W=0.62, stalkL=0.16, pf="oregano", **kw):
    """Small oval leaves on short stalks, for oregano at plant scale."""
    def d(a, x, y, ang, L):
        with a.on(LEAF):
            nleaf(a, x, y, ang, L, L * W, fill, pf, lw=0.6, stalkL=L * stalkL, **kw)
    return d


def flat_head(a, x, y, w, fc, br, dry=False, n=7):
    """Oregano's flat-topped head at plant scale: short dense spikes on
    branching stalks, dark bracts with pink flowers among them."""
    with a.on(BLOOM):
        for j in range(n):
            v = j / (n - 1) - 0.5; px = x + v * w * 2; py = y - 3 + abs(v) * 3.2
            a.line(f"M{f(x)},{f(y + 4)} Q{f(x + v * w)},{f(y + 1)} {f(px)},{f(py + 1.4)}", 0.6, 0.85, "line")
        for j in range(n):
            v = j / (n - 1) - 0.5; px = x + v * w * 2; py = y - 3 + abs(v) * 3.2
            a.oval(px, py, 1.7, 2.1, 0, "seed" if dry else br, 0.5)
            if not dry:
                a.dot(px - 0.6, py - 1.0, 0.75, fc); a.dot(px + 0.7, py - 0.2, 0.7, fc)


def oregano_stages():
    k = "oregano"; fc = pal(k).get("flower", "mauve"); br = pal(k).get("centre", "plum"); lc = pal(k).get("leaf", "deep")
    D = oval_draw(lc)
    spec = ((-6, 42, -24), (-3, 34, -11), (0, 30, 0), (3, 34, 11), (6, 42, 24))

    def seedling():
        a = seedling_base(Art()); G = S10.G
        stem(a, (50, G), (49.6, G - 5), (50, G - 10), 1.2, 1.0, "pale")
        with a.on(LEAF):
            for sd in (-1, 1):
                a.oval(50 + sd * 3.6, G - 10.5, 2.8, 2.2, 0, "pale", 0.7)
            oval_draw(lc, stalkL=0.1)(a, 50, G - 10, -118, 7)
            oval_draw(lc, stalkL=0.1)(a, 50, G - 10, -62, 7)
        return a

    def plant(a, tips=True, fill=None, sc="plum", us2=None):
        qs = clump(a, spec, sc)
        Df = oval_draw(fill or lc)
        for i, q in enumerate(qs):
            pairs(a, Df, q, us2 or ((0.14, 0.34, 0.54, 0.74) if i % 2 == 0 else (0.24, 0.44, 0.64)), 10, spread=58, shrink=0.2, tip=tips, cross=True)
        return qs

    def young():
        a = soil(Art())
        with a.group():
            qs = clump(a, ((-5, 70, -14), (-2, 66, -5), (2, 66, 5), (5, 70, 14)), "plum")
            for q in qs:
                pairs(a, D, q, (0.3, 0.7), 10, spread=60, tipk=0.7)
            for ang in (-172, -150, -30, -8):
                D(a, 50, 87.5, ang, 9)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            plant(a)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            for i, q in enumerate(plant(a, tips=False)):
                e = q.pt(1); flat_head(a, e[0], e[1] - 1, 4.6 if i in (0, 4) else 5.4, fc, br)
        return a

    def seedhead():
        a = soil(Art())
        with a.group():
            for i, q in enumerate(plant(a, tips=False, fill="pear", sc="straw", us2=(0.2, 0.5))):
                e = q.pt(1); flat_head(a, e[0], e[1] - 1, 4.6 if i in (0, 4) else 5.4, fc, br, dry=True)
        return a

    def dormant():
        a = soil(Art())
        with a.group():
            for j in range(14):   # a low mat of small rounded leaves, some purple-tinged
                x = 30 + 40 * ((j * 0.618) % 1); ang = -90 + (x - 50) * 3.2 + (j % 3 - 1) * 14
                oval_draw("plum" if j % 3 == 0 else lc, W=0.72)(a, 50 + (x - 50) * 0.3, 87.5, ang, 9 + (j % 3))
        return a

    return {"seed": sown(S10_dust), "seedling": seedling, "young": young, "crop": crop, "flower": flower,
            "seedhead": seedhead, "dormant": dormant}


def S10_dust(a, x, y):
    """Tiny round brown seeds like dust."""
    for k in range(26):
        rr = 15 * math.sqrt((k + 0.5) / 26); th = k * GOLD
        a.oval(x + rr * math.cos(th) * 1.3, y + rr * math.sin(th) * 0.75, 1.0, 0.85, k * 40, "bark", 0.5)


# ============================================================ shrubby herbs
def bush(a, n, width, height, woody=0.32, top="leaf", foot=8, dome=0.35, y0=88, lean_out=1.0):
    """The stems of a small shrub: n stems from a woody base, spreading to a
    width either side and up to height, the outer ones lower (dome). The
    lower part of each (woody, a share of its length) is brown bark, the
    rest the colour of the young shoots (top). Returns the stems as curves."""
    qs = []
    for i in range(n):
        v = (i / (n - 1) - 0.5) * 2 if n > 1 else 0
        x0 = 50 + v * foot * 0.5
        e = (50 + v * width * lean_out, y0 - height * (1 - dome * v * v))
        c = (x0 + (e[0] - x0) * 0.25, (y0 + e[1]) / 2 + 2)
        q = Quad((x0, y0), c, e)
        a.ribbon(q.p0, q.c, q.p1, 1.7, 0.9, top, lw=0.7)
        qs.append(q)
    for q in qs:   # the woody base, over the green
        p1 = q.pt(woody); c = q.pt(woody * 0.5)
        a.ribbon(q.p0, c, p1, 2.6, 1.7, "bark", lw=0.8)
    return qs


def shrub_leaves(a, qs, draw, L, us=None, spread=48, cross=False, tip=True, tufts=None, skip=0.3):
    """Leaves in opposite pairs up each stem of a shrub, above the bare
    woody part (skip)."""
    for i, q in enumerate(qs):
        u_s = us or even(6, skip, 0.92)
        pairs(a, draw, q, u_s[(i % 2):] if i % 2 else u_s, L, spread=spread, cross=cross, shrink=0.25, tip=tip, tipk=0.6)
        if tufts:
            with a.on(LEAF):
                for u in u_s[:-1]:
                    x, y = q.pt(u)
                    for sd in (-1, 1):
                        tufts(a, x, y, q.ang(u) + sd * 18, L * 0.38)


def hyssop_stages():
    k = "hyssop"; fc = pal(k).get("flower", "herbs_violet"); lc = pal(k).get("leaf", "deep")
    D = narrow_draw(lc, 0.2, "hyssop")
    T_ = lambda a, x, y, ang, L: nleaf(a, x, y, ang, L, L * 0.3, lc, "hyssop", mid=False, lw=0.5, shade=0)

    def young():
        a = soil(Art())
        with a.group():
            qs = bush(a, 4, 9, 30, woody=0.2, foot=6, dome=0.2)
            shrub_leaves(a, qs, D, 11, spread=46, skip=0.22)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            qs = bush(a, 7, 24, 52, foot=10, dome=0.28)
            shrub_leaves(a, qs, D, 11, spread=44, tufts=T_)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = bush(a, 7, 24, 48, foot=10, dome=0.28)
            shrub_leaves(a, qs, D, 10.5, us=even(6, 0.3, 0.76), spread=44, tip=False)
            for i, q in enumerate(qs):   # a dense spike at the top of every stem, the flowers turned one way
                e = q.pt(1); ang = q.ang(1)
                sp = stem(a, e, T(*e, ang)(6), T(*e, ang)(13), 0.9, 0.6)
                with a.on(BLOOM):
                    for j in range(7):
                        x, y = sp.pt(0.05 + 0.9 * j / 6); kk = 1 - 0.35 * j / 6
                        D(a, x, y, sp.ang(0.05) - 70, 4.4 * kk)
                        for off in (-34, 4):
                            a.leaf(x + 0.5, y, off + (ang + 90) * 0.4, 3.6 * kk, 0.42, fc, lw=0.5, detail=False)
                        e2 = T(x + 0.5, y, (ang + 90) * 0.4 - 10)(4.6 * kk); a.dot(e2[0], e2[1], 0.35, "plum")
        return a

    return {"young": young, "crop": crop, "flower": flower}


def lavender_stages():
    k = "lavender"; fc = pal(k).get("flower", "herbs_lavender"); lc = pal(k).get("leaf", "sage")
    D = narrow_draw(lc, 0.16, "strap", lw=0.42, felt=True)
    T_ = lambda a, x, y, ang, L: nleaf(a, x, y, ang, L, L * 0.2, lc, "strap", mid=False, lw=0.5, shade=0)

    def mound(a, n, width, height, L, tufts=True):
        qs = bush(a, n, width, height, woody=0.22, top=lc, foot=12, dome=0.55, lean_out=1.0)
        shrub_leaves(a, qs, D, L, us=even(6, 0.26, 0.9), spread=34, tufts=T_ if tufts else None)
        return qs

    def young():
        a = soil(Art())
        with a.group():
            mound(a, 5, 16, 22, 10, tufts=False)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            mound(a, 9, 36, 34, 11)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = mound(a, 9, 36, 30, 10.5)
            for i, q in enumerate(qs[1:-1]):   # long bare stalks rising well above the mound, each ending in a spike
                e = q.pt(0.9); v = (i / (len(qs) - 3) - 0.5) * 2
                top = (e[0] + v * 9, 14 + abs(v) * 10)
                sp = stem(a, e, ((e[0] + top[0]) / 2, (e[1] + top[1]) / 2), top, 1.0, 0.7, lc)
                with a.on(BLOOM):
                    ang = sp.ang(1)
                    for j in range(6):
                        p = T(*top, ang)(-1 - j * 1.9 - (1.8 if j == 5 else 0))
                        a.oval(p[0], p[1], 1.6 - 0.05 * j, 1.25, ang + 90, fc if j < 4 else "plum", 0.5)
                    p = T(*top, ang)(0.6); a.oval(p[0], p[1], 1.0, 1.2, ang + 90, fc, 0.5)
        return a

    return {"young": young, "crop": crop, "flower": flower}


def rosemary_stages():
    k = "rosemary"; fc = pal(k).get("flower", "blue"); lc = pal(k).get("leaf", "marrow")
    D = narrow_draw(lc, 0.13, "strap", under="white")

    def plant(a, n, width, height, L, us=None):
        qs = bush(a, n, width, height, woody=0.4, top="bark", foot=8, dome=0.25)
        shrub_leaves(a, qs, D, L, us=us or even(9, 0.3, 0.94), spread=40)
        return qs

    def young():
        a = soil(Art())
        with a.group():
            plant(a, 3, 8, 40, 9, us=even(8, 0.15, 0.94))
        return a

    def crop():
        a = soil(Art())
        with a.group():
            plant(a, 6, 22, 64, 9.5)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = plant(a, 6, 22, 64, 9.5)
            for i, q in enumerate(qs):   # small clusters in the leaf joints along the upper shoots, no spikes
                for j, u in enumerate((0.55, 0.68, 0.8)):
                    x, y = q.pt(u); sd = 1 if (i + j) % 2 else -1
                    for m in range(2):
                        mini_lip(a, x + sd * 0.6, y - m * 1.2, (0 if sd > 0 else 180) + sd * (-30 + 30 * m), 1.25, fc, "leaf", "plum")
        return a

    return {"young": young, "crop": crop, "flower": flower}


def sage_stages():
    k = "sage"; fc = pal(k).get("flower", "herbs_salvia"); lc = pal(k).get("leaf", "sage")
    D = own_draw(k)

    def plant(a, n, width, height, L, tip=True, us=None):
        qs = bush(a, n, width, height, woody=0.3, top=lc, foot=12, dome=0.5)
        for i, q in enumerate(qs):
            pairs(a, D, q, us or ((0.4, 0.68) if i % 2 else (0.34, 0.6, 0.84)), L, spread=54, shrink=0.2, tip=tip, tipk=0.55)
        return qs

    def young():
        a = soil(Art())
        with a.group():
            qs = bush(a, 3, 8, 26, woody=0.12, top=lc, foot=6, dome=0.3)
            for q in qs:
                pairs(a, D, q, (0.3, 0.66), 16, spread=58, tipk=0.6)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            plant(a, 7, 36, 34, 17)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = plant(a, 7, 36, 32, 16, tip=False)
            for i, q in enumerate(qs[1:-1]):   # upright spikes held above the leaves, spaced rings of flowers
                e = q.pt(1); ang = q.ang(1)
                sp = stem(a, e, T(*e, ang * 0.5 - 45)(10), T(*e, ang * 0.3 - 63)(26), 1.1, 0.7, lc)
                with a.on(BLOOM):
                    for j, u in enumerate((0.3, 0.55, 0.78)):
                        x, y = sp.pt(u)
                        for sd in (-1, 1):
                            mini_lip(a, x, y, (0 if sd > 0 else 180) - sd * 20, 1.7 - 0.25 * j, fc, "plum")
                    x, y = sp.pt(1); a.oval(x, y, 1.0, 1.6, 0, "plum", 0.5)
        return a

    return {"young": young, "crop": crop, "flower": flower}


def savory_stages():
    k = "savory"; fc = pal(k).get("flower", "white"); lc = pal(k).get("leaf", "deep"); spot = pal(k).get("centre", "mauve")
    D = narrow_draw(lc, 0.2, "savory", gloss=True)
    T_ = lambda a, x, y, ang, L: nleaf(a, x, y, ang, L, L * 0.3, lc, "savory", mid=False, lw=0.5, shade=0)

    def young():
        a = soil(Art())
        with a.group():
            qs = bush(a, 3, 7, 26, woody=0.15, foot=5, dome=0.2)
            shrub_leaves(a, qs, D, 9, spread=46, skip=0.2)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            qs = bush(a, 9, 30, 30, woody=0.3, foot=12, dome=0.4)
            shrub_leaves(a, qs, D, 8.5, spread=46, tufts=T_)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = bush(a, 9, 30, 32, woody=0.3, foot=12, dome=0.4)
            shrub_leaves(a, qs, D, 8.5, spread=46)
            for i, q in enumerate(qs):   # small clusters in the upper leaf joints: loose leafy spikes
                for j, u in enumerate((0.62, 0.78, 0.92)):
                    x, y = q.pt(u)
                    for sd in (-1, 1):
                        if (i + j) % 2 or sd > 0:
                            mini_lip(a, x, y - 0.6, (0 if sd > 0 else 180) + sd * -40, 1.05, fc, "leaf", spot)
        return a

    return {"young": young, "crop": crop, "flower": flower}


def thyme_stages():
    k = "thyme"; fc = pal(k).get("flower", "pink"); lc = pal(k).get("leaf", "sage")

    def tiny(fill):
        n = [0]

        def d(a, x, y, ang, L):
            n[0] += 1   # fill "winter": darker leaves, every third one purple-tinged
            c = ("plum" if n[0] % 3 == 0 else "deep") if fill == "winter" else fill
            nleaf(a, x, y, ang, L, L * 0.42, c, "thyme", mid=False, lw=0.45, shade=0)
        return d

    def plant(a, n, width, height, fill=None, twigs=True, us=None):
        qs = bush(a, n, width, height, woody=0.45, top="bark", foot=14, dome=0.5)
        D = tiny(fill or lc)
        for i, q in enumerate(qs):
            pairs(a, D, q, us or even(8, 0.3, 0.94), 4.2, spread=52, cross=False, shrink=0.1, tip=True, tipk=0.8)
            if twigs:   # a short side twig, also crowded with leaves
                x, y = q.pt(0.5); v = (i / (n - 1) - 0.5) * 2 if n > 1 else 0; sd = 1 if v >= 0 else -1
                tw = stem(a, (x, y), (x + sd * 3, y - 3), (x + sd * 6, y - 8), 0.9, 0.6, "bark", lw=0.5)
                pairs(a, D, tw, (0.3, 0.6, 0.9), 3.8, spread=52, cross=False, shrink=0.1, tipk=0.8)
        return qs

    def heads(a, qs, dry=False):
        with a.on(BLOOM):
            for q in qs:
                e = q.pt(1); ang = q.ang(1); c = T(*e, ang)(1.8)
                a.oval(c[0], c[1], 2.6, 2.3, 0, "seed" if dry else fc, 0.5)
                if not dry:
                    for m in range(4):
                        p = T(*c, m * 90 + 45)(1.2); a.dot(p[0], p[1], 0.4, "plum")

    def young():
        a = soil(Art())
        with a.group():
            plant(a, 5, 12, 20, twigs=False)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            plant(a, 11, 34, 26)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            heads(a, plant(a, 11, 34, 26))
        return a

    def seedhead():
        a = soil(Art())
        with a.group():
            heads(a, plant(a, 11, 34, 26), dry=True)
        return a

    def dormant():
        a = soil(Art())
        with a.group():
            plant(a, 11, 34, 24, fill="winter")
        return a

    return {"young": young, "crop": crop, "flower": flower, "seedhead": seedhead, "dormant": dormant}


# ============================================================ tarragon, wormwood, bay
def tarragon_stages():
    k = "tarragon"; lc = pal(k).get("leaf", "deep")
    D = narrow_draw(lc, 0.11, "tarragon", gloss=True)

    def young():
        a = soil(Art())
        with a.group():
            for dx, top, lean in ((-4, 56, -6), (1, 50, 1), (5, 58, 7)):
                q = shoot(a, 50 + dx, 88, top, lean, 0.4, 1.4, 0.8)
                singles(a, D, q, even(6, 0.12, 0.9), 12, spread=40, shrink=0.25)
        return a

    def crop():
        a = soil(Art())
        with a.group():
            for dx, top, lean in ((-6, 22, -22), (-3, 14, -8), (0, 10, 2), (3, 15, 12), (6, 24, 24)):
                q = shoot(a, 50 + dx, 88, top, lean, 0.8, 1.6, 0.8)
                singles(a, D, q, even(9, 0.12, 0.94), 12, spread=38, shrink=0.25)
                for u, sd in ((0.5, -1), (0.68, 1)):   # slender side branches, leaves set singly
                    x, y = q.pt(u); ang = q.ang(u) + sd * 34
                    br = stem(a, (x, y), T(x, y, ang)(6), T(x, y, ang + sd * 8)(15), 0.8, 0.5, lw=0.55)
                    singles(a, D, br, (0.3, 0.6, 0.9), 9, spread=36, shrink=0.2, tip=False)
        return a

    def dormant():
        a = soil(Art())
        for dx, h, ln in ((-9, 18, -4), (-3, 26, -1), (3, 22, 2), (9, 15, 4)):   # dead brown stems, nothing green
            q = a.ribbon((50 + dx, 88), (50 + dx + ln * 0.3, 88 - h * 0.5), (50 + dx + ln, 88 - h), 1.4, 0.9, "bark", lw=0.7)
            x, y = q.pt(0.6); a.line(f"M{f(x)},{f(y)} l{f(ln * 0.6 + 2.5)},-4", 0.6, 0.75, "bark")
        return a

    return {"young": young, "crop": crop, "dormant": dormant}


def cut_small(fill, stalkk=0.3):
    """Wormwood's leaf at plant scale: a stalk, then narrow blunt segments in
    pairs, each forked once, and a three-forked end."""
    def d(a, x, y, ang, L):
        with a.on(LEAF):
            t = T(x, y, ang); e = t(L)
            a.ribbon((x, y), t(L * 0.5), e, max(0.8, L * 0.07), 0.5, fill, lw=0.4)
            for u in (0.35, 0.58, 0.8) if L > 9 else (0.5, 0.8):
                p = t(L * u); l = L * 0.42 * (1.15 - u * 0.6)
                for sd in (-1, 1):
                    pa = ang + sd * 52
                    nleaf(a, p[0], p[1], pa, l, max(1.2, l * 0.26), fill, "seg", mid=False, lw=0.4, shade=0)
                    if L > 12:
                        q2 = T(*p, pa)(l * 0.5)
                        nleaf(a, q2[0], q2[1], pa - sd * 40, l * 0.5, max(1.1, l * 0.24), fill, "seg", mid=False, lw=0.38, shade=0)
            for off in (-30, 0, 30):
                nleaf(a, e[0], e[1], ang + off, L * 0.3, max(1.2, L * 0.08), fill, "seg", mid=False, lw=0.4, shade=0)
    return d


def wormwood_stages():
    k = "wormwood"; fc = pal(k).get("flower", "primrose"); lc = pal(k).get("leaf", "herbs_silver")
    D = cut_small(lc)

    def young():
        a = soil(Art())
        with a.group():
            for ang, L in ((-168, 20), (-12, 20), (-140, 22), (-40, 22), (-112, 21), (-68, 21), (-90, 18)):
                D(a, 50, 87, ang, L)
        return a

    def clump_(a, height, us, L):
        qs = []
        for dx, top, lean in ((-6, 88 - height * 0.8, -24), (-3, 88 - height * 0.95, -10), (0, 88 - height, 1),
                              (3, 88 - height * 0.95, 11), (6, 88 - height * 0.8, 24)):
            q = shoot(a, 50 + dx, 88, top, lean, 0.6, 2.0, 0.9, lc)
            p1 = q.pt(0.18); a.ribbon(q.p0, q.pt(0.09), p1, 2.6, 2.0, "bark", lw=0.8)
            qs.append(q)
        for i, q in enumerate(qs):
            singles(a, D, q, us, L, spread=50, shrink=0.55, start=1 if i % 2 else -1)
        return qs

    def growing():
        a = soil(Art())
        with a.group():
            clump_(a, 60, even(6, 0.2, 0.9), 19)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            qs = clump_(a, 70, even(4, 0.16, 0.5), 18)
            smallD = narrow_draw(lc, 0.16, "seg")
            for i, q in enumerate(qs):   # the upper part a leafy spray of side branches hung with tiny nodding yellow balls
                for j, u in enumerate((0.58, 0.7, 0.8, 0.9)):
                    x, y = q.pt(u); sd = 1 if (i + j) % 2 else -1; ang = q.ang(u) + sd * 50
                    br = stem(a, (x, y), T(x, y, ang)(4), T(x, y, ang + sd * 16)(9 - j), 0.7, 0.5, lc, lw=0.5)
                    with a.on(LEAF):
                        smallD(a, x, y, q.ang(u) - sd * 44, 5.5 - j * 0.6)
                    with a.on(BLOOM):
                        for v in (0.45, 0.8):
                            hx, hy = br.pt(v); a.line(f"M{f(hx)},{f(hy)} l0,1.3", 0.4, 0.85)
                            a.oval(hx, hy + 2.3, 1.15, 1.05, 0, fc, 0.45)
                with a.on(BLOOM):
                    e = q.pt(1); a.oval(e[0], e[1] + 1.4, 1.1, 1.0, 0, fc, 0.45)
        return a

    return {"young": young, "growing": growing, "flower": flower}


def bay_stages():
    k = "bay"; fc = pal(k).get("flower", "primrose"); lc = pal(k).get("leaf", "marrow")
    D = own_draw(k)

    def young():
        a = soil(Art())
        with a.group():
            q = shoot(a, 50, 88, 30, 1, 0.5, 2.4, 1.0, "rust")
            a.ribbon((50, 88), (50, 80), (50.2, 72), 2.8, 2.2, "bark", lw=0.8)
            singles(a, D, q, even(7, 0.25, 0.92), 16, spread=48, shrink=0.25)
            x, y = q.pt(0.5); br = stem(a, (x, y), (x + 6, y - 4), (x + 12, y - 12), 1.2, 0.8, "rust")
            singles(a, D, br, (0.5, 0.95), 13, spread=44, tip=False)
        return a

    def shrub(a, clusters=False):
        """A dense upright evergreen bush: grey stems, a head of glossy pointed
        leaves set singly, shoots pointing up and out."""
        qs = []
        for dx, top, lean in ((-3, 30, -18), (0, 12, -2), (3, 26, 16), (-1, 44, -26), (1, 42, 26)):
            q = a.ribbon((50 + dx, 88), (50 + dx + lean * 0.2, 70), (50 + dx + lean, top), 2.4, 1.0, "bark", lw=0.8)
            qs.append(q)
        for i, q in enumerate(qs):
            singles(a, D, q, even(7, 0.4, 0.95), 15, spread=44, shrink=0.2, start=1 if i % 2 else -1)
            for j, u in enumerate((0.55, 0.75)):   # short side shoots fill the bush out
                x, y = q.pt(u); sd = 1 if (i + j) % 2 else -1; ang = q.ang(u) + sd * 40
                br = stem(a, (x, y), T(x, y, ang)(5), T(x, y, ang)(11), 1.0, 0.6, "rust", lw=0.6)
                singles(a, D, br, (0.4, 1.0), 13, spread=40, tip=False)
                if clusters:
                    with a.on(BLOOM):
                        for (cx, cy) in (q.pt(u + 0.06), br.pt(0.5)):
                            for m in range(4):
                                p = T(cx, cy, m * 90 + 20)(1.3); a.dot(p[0], p[1], 1.0, fc)
                            a.dot(cx, cy, 0.6, "sun")
        return qs

    def growing():
        a = soil(Art())
        with a.group():
            shrub(a)
        return a

    def flower():
        a = soil(Art())
        with a.group():
            shrub(a, clusters=True)
        return a

    return {"young": young, "growing": growing, "flower": flower}


STAGE = {"basil": basil_stages(), "mint": mint_stages(), "lemon-balm": balm_stages(), "cat-nip": catnip_stages(),
         "oregano": oregano_stages(), "hyssop": hyssop_stages(), "lavender": lavender_stages(),
         "rosemary": rosemary_stages(), "sage": sage_stages(), "savory": savory_stages(), "thyme": thyme_stages(),
         "tarragon": tarragon_stages(), "wormwood": wormwood_stages(), "bay": bay_stages()}
