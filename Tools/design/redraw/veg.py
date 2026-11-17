"""DOCSTRING_PLACEHOLDER"""
import math
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10

BASE = (20, 92)    # where a close-up leaf's stalk starts, as in leaves_flowers.py
ANG = -52          # the way a close-up leaf points
GOLD = 2.39996

COLOURS = {
    "veg_cream": ("#F1E6C4", "#CDBF97"),     # cream seeds: courgette, squash, cucumber, melon
    "veg_aubergine": ("#3B1E40", "#6E4C7C"),  # aubergine fruit: glossy deep purple-black (asked for in its description)
    "veg_vetch": ("#6A5FC8", "#8F86E0"),      # tufted vetch flowers: bluish violet (asked for)
    "veg_lucerne": ("#7A5CC0", "#9C82DC"),    # alfalfa (lucerne) flowers: violet-purple (asked for)
    "veg_lupin": ("#5E6CC8", "#8794E2"),      # lupin 'Gallery Blue': violet-blue (asked for)
    "veg_artichoke": ("#7448C8", "#9A78E4"),  # globe artichoke florets: bright violet-blue purple (asked for)
}
LEAFX, BLOOMX, KIND, STAGE = {}, {}, {}, {}
LEAF_DRAW, BLOOM_DRAW, LF, FL = {}, {}, {}, {}


# ============================================================ small helpers
def _pa():
    import plants_all as PA      # imported here, not at the top: plants_all imports this file
    return PA


def pal(slug, part, default):
    """One colour of a kind, from its description's palette."""
    return _pa().palette(slug).get(part, default)


def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


def lerp(p, q, u):
    return (p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u)


def tilt(cy, k):
    return lambda p: (p[0], cy + (p[1] - cy) * k)


# ------------------------------------------------------------ leaf outlines
def prof(umax=0.5, base="round", tip="point", bp=None, tp=None):
    """How wide a leaf is along its length (u: 0 at the stalk, 1 at the tip),
    as a share of its widest. umax: where it is widest. base: "wedge",
    "round", "taper" or "heart". tip: "point", "acum" (a long drawn-out
    point), "round" or "blunt"."""
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


def teeth(n, d, start=0.06, end=0.97, kind="saw", jag=0.0):
    """A toothed edge: n teeth down each side between start and end (as a
    share of the length), each cutting in d of the half width. kind "saw"
    (sharp, leaning to the tip) or "round". jag makes them uneven (seeded,
    so the drawing is the same every time)."""
    def fn(u, side):
        if u < start or u > end:
            return 1.0
        s = ((u - start) / (end - start) * n + (0 if side > 0 else 0.5)) % 1
        k = int((u - start) / (end - start) * n)
        dd = d * (1 + jag * math.sin(k * 2.7 + side))
        nick = (1 - s) ** 1.6 if kind == "saw" else abs(math.cos(math.pi * s)) ** 2.4
        fade = min(1.0, (u - start) / 0.05, (end - u) / 0.05)
        return 1 - dd * nick * fade
    return fn


def waves(n, d, start=0.05, end=0.95):
    """A wavy edge of n shallow rounded bays down each side (aubergine)."""
    def fn(u, side):
        if u < start or u > end:
            return 1.0
        s = (u - start) / (end - start) * n + (0 if side > 0 else 0.35)
        return 1 - d * (0.5 - 0.5 * math.cos(2 * math.pi * s)) ** 1.5
    return fn


def blade(a, x, y, ang, L, W, fill, pr, margin=None, veins=5, lw=1.0, shade=0.1, lop=0.0, midc="line",
          vla=0.36, mid=0.6, n=90, notch=0.0, petal=False, M=None):
    """A leaf or leaflet from x,y along ang, L long, W wide at its widest.
    pr is its profile (see prof), margin an edge (teeth, waves). lop makes
    it lopsided: the upper side wider by that share. notch cuts a small
    notch in the tip (alfalfa). Returns the outline points."""
    t0 = T(x, y, ang)
    t = (lambda px, py=0: M(t0(px, py))) if M else t0
    us = [i / n for i in range(n + 1)]

    def hw(u, side):
        w = pr(u) * W / 2 * (1 + lop * side)
        if margin:
            w *= margin(u, side)
        if notch and u > 1 - notch:
            w = max(w, 0)
        return w
    top = [(L * u, hw(u, 1)) for u in us]
    bot = [(L * u, -hw(u, -1)) for u in us]
    if notch:   # pull the tip back in: a squared, notched end
        top[-1] = (L * (1 - notch), 0); bot[-1] = top[-1]
    pts = [t(*p) for p in top] + [t(*p) for p in bot[::-1]]
    a.shape(path(pts), fill, lw)
    if petal:
        return pts
    if shade:
        a.shape(path([t(*p) for p in top] + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=shade)
    if mid:
        a.line(opath([t(L * u, 0) for u in (0.0, 0.35, 0.7, 0.93)]), mid, 0.55, midc)
    for k in range(veins):
        u1 = 0.18 + 0.7 * (k + 0.5) / veins; u0 = max(0.03, u1 - 0.16)
        for sg in (1, -1):
            w1 = hw(min(0.99, u1), sg) * 0.82 * sg
            a.line(f"M{P(t(L * u0, 0))} Q{P(t(L * (u0 + 0.07), w1 * 0.55))} {P(t(L * u1, w1))}", 0.45, vla, midc)
    return pts


def bristles(a, q, n=9, side=1.4, la=0.6):
    """Short stiff hairs along a stalk: the prickly leaf stalks of courgette."""
    for k in range(n):
        u = 0.08 + 0.84 * k / max(1, n - 1); x, y = q.pt(u); g = q.ang(u)
        sg = 1 if k % 2 else -1
        e = T(x, y, g + sg * 60)(side)
        a.line(f"M{P(T(x, y, g + sg * 90)(side * 0.5))} L{P(e)}", 0.45, la)


# ------------------------------------------------------------ placing small copies
_SMALL = {}


def small(key, build):
    """A drawing made once and kept, to be drawn small many times (Art.place)."""
    if key not in _SMALL:
        _SMALL[key] = build()
    return _SMALL[key]


def put(a, src, x, y, ang, L, lw=None, fills=None, detail=None):
    """Draws src (an Art with .anchor, .anchor_ang and .size) L long at x,y along ang."""
    sc = L / src.size
    if detail is None:
        detail = L >= 13
    a.place(src, x, y, ang, sc, lw=lw if lw is not None else (0.8 if L < 14 else 0.95), detail=detail, fills=fills)


def soil(a, y=88, marks=True):
    a.ground(y, marks=marks)


def sown(fn):
    """The seed stage, as in plants.py: the seed drawn large under the soil line."""
    return S10.sown(fn)


def roots(a, x, y, n=3, L=12, spread=50):
    a.roots(x, y, n, L, spread)


# ================================================================ THE GOURDS
# One leaf shape for all five: a palm of lobes round a notch where the stalk
# joins. Each lobe tip is a point on a circle round the stalk; between two
# tips the edge comes in to a bay (the sinus). "pointy" lobes come to a
# corner, round ones (squash, melon) curve smoothly over.
GOURD = {
    #            lobes (angle, length) from the tip round to the base,  sinus depth, round tips?, teeth, tooth depth, wave
    "courgette": dict(lobes=[(0, 1.0), (58, 0.9), (118, 0.68)], sinus=0.5, rnd=0.0, nt=70, td=0.035, wav=0.05, wn=30, notch=0.16, flecks=True, pp=0.55),
    "squash":    dict(lobes=[(0, 1.0), (62, 0.98), (124, 0.9)], sinus=0.94, rnd=1.0, nt=64, td=0.022, wav=0.02, wn=22, notch=0.22),
    "cucumber":  dict(lobes=[(0, 1.0), (55, 0.78), (115, 0.66)], sinus=0.8, rnd=0.0, nt=46, td=0.04, wav=0.0, wn=0, notch=0.2, pp=1.0),
    "melon":     dict(lobes=[(0, 0.96), (60, 0.96), (120, 0.88)], sinus=0.88, rnd=0.8, nt=48, td=0.03, wav=0.025, wn=20, notch=0.24),
    "loofah":    dict(lobes=[(0, 1.0), (44, 0.94), (90, 0.84), (134, 0.62)], sinus=0.6, rnd=0.0, nt=60, td=0.04, wav=0.0, wn=0, notch=0.14, pp=0.75),
}


def gourd_g(sp):
    """The leaf's edge as a function of the angle round the centre (0 at the
    tip, pi at the stalk): how far out it is, as a share of R."""
    tips = sorted([(math.radians(g), l) for g, l in sp["lobes"]] + [(-math.radians(g), l) for g, l in sp["lobes"] if g])
    last = tips[-1][0]
    sinus = sp["sinus"]; rnd = sp["rnd"]; nt = sp["nt"]; td = sp["td"]; wav = sp["wav"]; wn = sp["wn"]

    def g(h):
        h = math.atan2(math.sin(h), math.cos(h))
        if abs(h) >= last:   # the heart-shaped base: down from the last lobe into the notch
            v = (math.pi - abs(h)) / (math.pi - last)          # 0 at the notch, 1 at the lobe tip
            l = tips[-1][1]
            r = sp["notch"] + (l - sp["notch"]) * math.sin(math.pi / 2 * v) ** 0.5
        else:
            for (h0, l0), (h1, l1) in zip(tips, tips[1:]):
                if h0 <= h <= h1:
                    break
            m = (h0 + h1) / 2; s = sinus * min(l0, l1)
            if h <= m:
                v = (h - h0) / (m - h0); l = l0       # v: 0 at the tip, 1 at the sinus
            else:
                v = (h1 - h) / (h1 - m); l = l1
            pointed = (1 - v) ** sp.get("pp", 0.8)
            rounded = math.cos(math.pi / 2 * v) ** 0.8
            r = s + (l - s) * (rnd * rounded + (1 - rnd) * pointed)
        r *= 1 - td * (((h + math.pi) * nt / (2 * math.pi)) % 1) ** 1.6
        if wn:
            r *= 1 - wav * (0.5 + 0.5 * math.cos(h * wn))
        return r
    return g, tips


def gourd_blade(a, x, y, ang, R, fill, sp, lw=1.1, detail=True):
    """The blade of a gourd leaf, its stalk joining at x,y, pointing along ang."""
    g, tips = gourd_g(sp)
    d = R * g(math.pi) + R * 0.02
    t = T(x, y, ang)
    hs = [-math.pi + 2 * math.pi * i / 360 for i in range(361)]
    loc = [(d + R * g(h) * math.cos(h), R * g(h) * math.sin(h)) for h in hs]
    a.shape(path([t(*p) for p in loc]), fill, lw)
    if not detail:
        return
    half = [p for h, p in zip(hs, loc) if h >= 0]
    a.shape(path([t(*p) for p in half] + [t(0, 0)]), "shade", 0, fa=0.1)
    for h, l in tips:   # a main vein into each lobe, with side veins
        e = (d + R * l * 0.86 * math.cos(h), R * l * 0.86 * math.sin(h))
        m = (e[0] * 0.5, e[1] * 0.5)
        a.line(f"M{P(t(0, 0))} Q{P(t(*m))} {P(t(*e))}", 0.7 if h == 0 else 0.6, 0.5)
        L_ = math.hypot(*e); va = math.atan2(e[1], e[0])
        for u in (0.32, 0.55, 0.75):
            b = (e[0] * u, e[1] * u)
            for sg in (1, -1):
                k = L_ * 0.2 * (1 - u * 0.5); sa = va + sg * 0.8
                a.line(f"M{P(t(*b))} L{P(t(b[0] + k * math.cos(sa), b[1] + k * math.sin(sa)))}", 0.4, 0.28)
        if sp.get("flecks"):   # courgette: silver-white blotches along the main veins
            for u in (0.2, 0.36, 0.52):
                for sg in (1, -1):
                    c = (e[0] * u + R * 0.035 * math.cos(va + sg * 1.4), e[1] * u + R * 0.035 * math.sin(va + sg * 1.4))
                    rot = va + sg * 0.7
                    blob = [t(c[0] + R * 0.06 * math.cos(w) * math.cos(rot) - R * 0.02 * math.sin(w) * math.sin(rot),
                              c[1] + R * 0.06 * math.cos(w) * math.sin(rot) + R * 0.02 * math.sin(w) * math.cos(rot)) for w in [k * math.pi / 6 for k in range(12)]]
                    a.shape(path(blob), "white", 0, fa=0.6)


def gourd_leaf(slug):
    """LEAF_DRAW for the gourds: the leaf on its long stalk."""
    def draw(a, sp):
        g = GOURD[slug]; fill = sp["fill"]
        A = T(*BASE, ANG)(30)
        q = a.ribbon(BASE, T(*BASE, ANG)(15, 2), A, 3.6 if slug == "courgette" else 2.8, 2.6 if slug == "courgette" else 2.0, fill, lw=0.9)
        if slug in ("courgette", "cucumber"):
            bristles(a, q, 9, 1.5 if slug == "courgette" else 1.1)
        if slug == "courgette":   # the stalk is five-angled: a ridge down it
            a.line(opath([q.pt(u) for u in (0.05, 0.5, 0.95)]), 0.45, 0.4)
        gourd_blade(a, A[0], A[1], ANG + (8 if slug == "cucumber" else 0), sp.get("R", 33), fill, g)
        return a
    return draw


def gourd_small(slug, fill=None):
    """The blade alone, for drawing small on the whole plant."""
    def build():
        a = Art(); g = GOURD[slug]
        gourd_blade(a, 0, 0, 0, 30, fill or pal(slug, "leaf", "leaf"), g, lw=1.1)
        a.anchor, a.anchor_ang, a.size = (0, 0), 0, 30
        return a
    return small(("gourd", slug, fill), build)


def gleaf(a, slug, x, y, ang, R, fill=None, detail=None):
    """One gourd leaf blade, R across, on the whole plant."""
    src = gourd_small(slug)
    fills = {pal(slug, "leaf", "leaf"): fill} if fill else None
    a.place(src, x, y, ang, R / 30, lw=0.75 if R < 9 else 0.9, detail=(R >= 8) if detail is None else detail, fills=fills)


for _k in GOURD:
    LEAF_DRAW[f"veg_{_k}"] = gourd_leaf(_k)
LEAFX.update({
    "courgette": dict(kind="veg_courgette", fill="deep", R=38),
    "squash": dict(kind="veg_squash", fill="leaf", R=34),
    "cucumber": dict(kind="veg_cucumber", fill="deep", R=36),
    "melon": dict(kind="veg_melon", fill="leaf", R=31),
    "loofah": dict(kind="veg_loofah", fill="deep", R=37),
})


# ------------------------------------------------------------ flowers seen face on
def face(a, cx, cy, n, R, W, fill, pr, k=0.88, start=-90, lw=0.9, lines=3, margin=None, order=True):
    """n petals round cx,cy, the flower tilted (k squashes it up and down).
    lines: how many fine lines run down each petal."""
    M = tilt(cy, k)
    idx = sorted(range(n), key=lambda i: math.sin(math.radians(start + 360 * i / n))) if order else range(n)
    for i in idx:
        g = start + 360 * i / n
        blade(a, cx, cy, g, R, W, fill, pr, margin, veins=0, lw=lw, petal=True, M=M)
        t = T(cx, cy, g)
        sh = 0.06 + (0.05 if math.sin(math.radians(g)) > 0.3 else 0)
        for j in range(lines):
            o = (j - (lines - 1) / 2) * 0.45
            q = [M(t(R * u, o * pr(u) * W / 2 * 0.8)) for u in (0.15, 0.45, 0.75)]
            a.line(f"M{P(q[0])} Q{P(q[1])} {P(q[2])}", 0.4, 0.3)
    return M


def sepals(a, cx, cy, n, L, W, fill="leaf", start=-90, k=0.88, lw=0.7):
    M = tilt(cy, k)
    for i in range(n):
        blade(a, cx, cy, start + 360 * (i + 0.5) / n, L, W, fill, prof(0.3, "round", "point"), veins=0, lw=lw, petal=True, M=M)


# ------------------------------------------------------------ the gourd flowers
def trumpet(a, base, ang, L, W, fc, cen, pointed=True, s=1.0, ovary=None, ovc="marrow", lobes=True):
    """A courgette or squash flower from the side: a funnel from base along
    ang, L long, W across the mouth, five lobes round the mouth. ovary:
    None (a male, on a thin stalk), "long" (courgette: a small courgette
    behind) or "ball" (squash: a round swelling)."""
    t = T(*base, ang)
    if ovary == "long":
        a.ribbon(t(-16 * s), t(-8 * s), t(0), 5.6 * s, 6.2 * s, ovc, lw=0.9)
        for o in (-1.4, 1.4):
            a.line(opath([t(-15 * s, o * s), t(-1 * s, o * s * 1.2)]), 0.4, 0.4)
    elif ovary == "ball":
        c = t(-5 * s); a.oval(c[0], c[1], 6 * s, 5.4 * s, ang, ovc, 0.9)
        a.line(f"M{P(t(-9 * s, -2 * s))} Q{P(t(-5 * s, -3.4 * s))} {P(t(-1 * s, -2 * s))}", 0.45, 0.4)
    for sg in (-1, 1):   # five narrow sepals at the foot of the funnel
        blade(a, *t(0.5 * s, sg * 2 * s), ang + sg * 52, 8 * s, 1.8 * s, "leaf", prof(0.3), veins=0, lw=0.6, petal=True)
    w = lambda u: (2.6 + (W / 2 - 2.6) * u ** 2.2) * s
    us = [i / 24 for i in range(25)]
    side1 = [t(L * s * u, w(u)) for u in us]; side2 = [t(L * s * u, -w(u)) for u in us]
    mouth = t(L * s)
    r0 = W / 2 * s; k = 0.45; Lb = W * (0.5 if pointed else 0.42) * s
    # the mouth is a flat ring of five lobes seen at a slant: in its own plane
    # x runs along the funnel (squashed by k), y across it. Each lobe grows
    # out from the rim.
    def mp(px, py):
        return t(L * s + px * k, py)
    pr = prof(0.3, "round", "point", tp=0.8) if pointed else prof(0.42, "round", "round", tp=2.0)
    far = [g for g in (0, 72, 144, 216, 288) if math.cos(math.radians(g + 36)) > 0]
    near = [g for g in (0, 72, 144, 216, 288) if g not in far]

    def lobe(g):
        tt = lambda px, py=0: mp(*T(0, 0, g + 36)(r0 * 0.62 + px, py))
        hw = r0 * 0.62 * math.pi / 5 * (1.3 if pointed else 1.6)
        us_ = [i / 30 for i in range(31)]
        up = [tt(Lb * u, max(pr(u), 0.75 if u < 0.25 else 0) * hw) for u in us_]
        dn = [tt(Lb * u, -max(pr(u), 0.75 if u < 0.25 else 0) * hw) for u in us_]
        a.shape(path(up + dn[::-1]), fc, 0.9)
        a.line(f"M{P(tt(Lb * 0.05))} L{P(tt(Lb * 0.8))}", 0.45, 0.35)
        a.shape(path(up + [tt(Lb * u, 0) for u in us_[::-1]]), "shade", 0, fa=0.07)
    for g in far:
        lobe(g)
    a.shape(path(side1 + side2[::-1]), fc, 0.9)
    a.shape(path(side2 + [t(L * s * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    for o in (-0.55, 0, 0.55):   # green veins down the outside
        a.line(opath([t(L * s * u, o * w(u)) for u in (0.08, 0.4, 0.7, 0.95)]), 0.5, 0.5, "line")
    throat = [mp(r0 * 0.85 * math.cos(h), r0 * 0.85 * math.sin(h)) for h in [2 * math.pi * i / 30 for i in range(30)]]
    a.shape(path(throat), fc, 0.6)
    a.shape(path(throat), "shade", 0, fa=0.13)
    for g in near:
        lobe(g)
    c0 = mp(0, 0)   # the column of stamens (male) or the lobed stigma (female)
    if ovary:
        for o in (-1.6, 0, 1.6):
            a.oval(c0[0] + o * s * 1.3, c0[1] - 1.6 * s, 2.0 * s, 2.5 * s, o * 12, cen, 0.6)
    else:
        a.ribbon(T(*c0, ang)(-4 * s), T(*c0, ang)(-1 * s), T(*c0, ang - 10)(4 * s), 3.6 * s, 2.8 * s, cen, lw=0.7)
    return mouth


def fl_trumpet(a, sp):
    """Courgette and squash: a big funnel flower from the side, and its bud."""
    fc, cen = sp["fc"], sp.get("cen", "amber")
    stalkc = "leaf"
    if sp.get("ovary"):   # a female: short thick stalk, the young fruit behind the flower
        a.ribbon((10, 98), (13, 90), (18, 85), 3.8, 3.4, stalkc, lw=0.9)
        trumpet(a, (28, 78) if sp["ovary"] == "long" else (26, 80), -48, 40, 40, fc, cen, sp.get("pointed", True), 1.0, sp["ovary"], sp.get("ovc", "marrow"))
    else:
        a.ribbon((22, 98), (26, 88), (30, 78), 2.4, 2.0, stalkc, lw=0.9)
        trumpet(a, (28, 80), -48, 40, 40, fc, cen, sp.get("pointed", True))
    # a closed bud on its own stalk
    a.ribbon((86, 98), (88, 90), (86, 80), 1.8, 1.5, stalkc, lw=0.8)
    blade(a, 86, 80, -98, 16, 5.6, fc, prof(0.45, "round", "point"), veins=0, lw=0.8, petal=True)
    a.line("M85.4,77 L85.6,66", 0.45, 0.4)
    for sg in (-1, 1):
        blade(a, 86, 80, -98 + sg * 40, 5, 1.2, "leaf", prof(0.3), veins=0, lw=0.5, petal=True)
    return a


def gourd_face(a, cx, cy, R, fc, cen, kind, k=0.9, start=-90):
    """A small gourd flower face on: five petals joined only at the base."""
    if kind == "cucumber":
        pr, Wk, mg = prof(0.5, "round", "point", tp=0.7), 0.8, waves(2, 0.06)
    elif kind == "melon":
        pr, Wk, mg = prof(0.55, "round", "round", tp=1.6), 0.86, None
    else:   # loofah: broad, rounded, a little wavy at the edge
        pr, Wk, mg = prof(0.6, "wedge", "round", bp=0.8, tp=2.0), 1.05, waves(3, 0.05, 0.5, 0.98)
    sepals(a, cx, cy, 5, R * 0.42, R * 0.14, "leaf", start, k)
    M = face(a, cx, cy, 5, R, R * Wk, fc, pr, k, start, lines=3 if R > 12 else 1, margin=mg)
    a.shape(path([(cx + R * 0.2 * math.cos(h), cy + R * 0.17 * math.sin(h)) for h in [2 * math.pi * i / 24 for i in range(24)]]), "shade", 0, fa=0.18)
    for j in range(3 if kind != "loofah" else 5):   # the short stamens close together
        e = M(T(cx, cy, j * (120 if kind != "loofah" else 72) + 20)(R * 0.09))
        a.oval(e[0], e[1], R * 0.07, R * 0.06, 0, cen, 0.5)


def gourd_female(a, x, y, ang, R, fc, cen, kind, s=1.0):
    """A female flower from the side, its small fruit behind it."""
    t = T(x, y, ang)
    if kind == "cucumber":   # a tiny prickly cucumber
        a.ribbon(t(-14 * s), t(-7 * s), t(0), 4.6 * s, 5.2 * s, "marrow", lw=0.8)
        for k in range(6):
            p = t((-12 + k * 2.2) * s, (2.6 if k % 2 else -2.6) * s); a.dot(p[0], p[1], 0.55 * s, "white")
            a.line(f"M{P(p)} L{P(T(*p, ang + (100 if k % 2 else -100))(1.2 * s))}", 0.4, 0.6)
    elif kind == "melon":    # a small hairy oval
        c = t(-5 * s); a.oval(c[0], c[1], 6 * s, 3.6 * s, ang, "unripe", 0.8)
        for k in range(7):
            p = t((-9 + k * 1.6) * s, (3.6 if k % 2 else -3.6) * s); a.line(f"M{P(p)} L{P(T(*p, ang + (80 if k % 2 else -80))(1.2 * s))}", 0.35, 0.5)
    else:                    # loofah: a long slim smooth ovary
        a.ribbon(t(-22 * s), t(-11 * s), t(0), 3.4 * s, 4.2 * s, "marrow", lw=0.8)
        for o in (-0.8, 0.8):
            a.line(opath([t(-20 * s, o * s), t(-1 * s, o * s * 1.3)]), 0.35, 0.4)
    for sg in (-1, 1):
        blade(a, x, y, ang + sg * 40, R * 0.45, R * 0.12, "leaf", prof(0.3), veins=0, lw=0.5, petal=True)
    for g in (-48, 48, -16, 16, 0):   # the petals, spread, seen from the side
        blade(a, x, y, ang + g, R, R * 0.62, fc, prof(0.55, "round", "point" if kind == "cucumber" else "round", tp=1.0), veins=0, lw=0.7, petal=True)
    e = t(R * 0.3); a.oval(e[0], e[1], R * 0.12, R * 0.09, 0, cen, 0.5)


def fl_gourdstar(a, sp):
    """Cucumber, melon, loofah: a male flower face on, and a female flower
    from the side sitting on her small young fruit."""
    fc, cen, kind = sp["fc"], sp.get("cen", "amber"), sp["gk"]
    if kind == "loofah":   # males in a long-stalked cluster: one open, buds above
        a.ribbon((40, 98), (42, 80), (44, 58), 2.2, 1.8, "leaf", lw=0.8)
        for j, (dx, dy, r) in enumerate([(-6, -6, 3.4), (5, -9, 3.0), (-2, -14, 2.4)]):
            a.line(f"M44,58 Q{f(44 + dx * 0.5)},{f(58 + dy * 0.6)} {f(44 + dx)},{f(58 + dy)}", 0.6, 0.8)
            a.oval(44 + dx, 58 + dy - r, r * 0.8, r, dx * 3, "unripe" if j else fc, 0.6)
        a.line("M44,58 Q42,52 40,46", 0.8, 0.85)
        gourd_face(a, 40, 36, 26, fc, cen, kind)
        a.ribbon((88, 98), (86, 88), (82, 82), 1.8, 1.5, "leaf", lw=0.7)
        gourd_female(a, 78, 64, -104, 14, fc, cen, kind, 0.9)
        return a
    a.ribbon((30, 98), (31, 76), (36, 48), 2.2, 1.8, "leaf", lw=0.8)
    gourd_face(a, 36, 40, 25, fc, cen, kind)
    a.ribbon((88, 98), (86, 90), (80, 84), 2.6, 2.2, "leaf", lw=0.8)
    gourd_female(a, 77, 72, -104, 17, fc, cen, kind, 1.3)
    return a


BLOOM_DRAW.update({"veg_trumpet": fl_trumpet, "veg_gourdstar": fl_gourdstar})
BLOOMX.update({
    # courgette is one of the ten drawn by hand, so its entry is used as it stands (no palette): colours written in
    "courgette": dict(kind="veg_trumpet", fc="sun", cen="amber", ovary="long", ovc="marrow", pointed=True),
    "squash": dict(kind="veg_trumpet", fc="sun", cen="amber", ovary="ball", ovc="unripe", pointed=False),
    "cucumber": dict(kind="veg_gourdstar", gk="cucumber", fc="sun", cen="amber"),
    "melon": dict(kind="veg_gourdstar", gk="melon", fc="sun", cen="amber"),
    "loofah": dict(kind="veg_gourdstar", gk="loofah", fc="sun", cen="amber"),
})


# ------------------------------------------------------------ gourd life stages
def gseed(fill, L=26, W=15, point=0.35, rim="line", n=1):
    """A flat gourd seed: an oval, pointed at one end, with a thin raised rim."""
    def draw(a, x, y):
        spots = [(0, 0, 1.0)] if n == 1 else [(-8, 2, 0.8), (9, -2, 0.8)]
        for dx, dy, k in spots:
            pr = prof(0.55, "round", "point", tp=0.6 + point)
            blade(a, x + dx - L * k / 2 * 0.9, y + dy + L * k * 0.15, -16, L * k, W * k, fill, pr, veins=0, lw=1.1, petal=True)
            blade(a, x + dx - L * k / 2 * 0.9 + 1.4 * k, y + dy + L * k * 0.15 - 0.4 * k, -16, L * k - 2.8 * k, W * k - 3.2 * k, None, pr, veins=0, lw=0.6, petal=True)
            a.shape(path([T(x + dx - L * k / 2 * 0.9, y + dy + L * k * 0.15, -16)(L * k * u, -pr(u) * W * k / 2 * 0.6) for u in [i / 20 for i in range(21)]]
                         + [T(x + dx - L * k / 2 * 0.9, y + dy + L * k * 0.15, -16)(L * k * u, -pr(u) * W * k / 2 * 0.25) for u in [i / 20 for i in range(20, -1, -1)]]), "shade", 0, fa=0.08)
    return draw


def tendril(a, x, y, ang, L, arms=1, curl=1, col="line"):
    """A tendril: a thin thread out from the joint ending in a tight coil.
    arms > 1 gives a branched one (squash, loofah)."""
    for k in range(arms):
        g = ang + (k - (arms - 1) / 2) * 34
        e = T(x, y, g)(L * (1 - 0.15 * abs(k - (arms - 1) / 2)))
        m = T(x, y, g + 18 * curl)(L * 0.5)
        pts = []
        for j in range(16):   # the coil: a small spiral at the end
            th = math.radians(g + curl * (90 + j * 40)); r = L * 0.16 * (1 - j / 18)
            pts.append((e[0] + r * math.cos(th) - L * 0.16 * math.cos(math.radians(g + curl * 90)), e[1] + r * math.sin(th) - L * 0.16 * math.sin(math.radians(g + curl * 90))))
        a.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)} " + " ".join("L" + P(p) for p in pts), 0.55, 0.8, col)


def gfruit_long(a, p0, c, p1, w0, w1, col, speck=True, remains="sun", ridge=0):
    """A courgette, cucumber or loofah: a long fruit with a short hard stalk."""
    q = a.ribbon(p0, c, p1, w0, w1, col, lw=0.9, round_tip=True)
    if speck:
        for k in range(7):
            x, y = q.pt(0.15 + 0.11 * k); g = q.ang(0.15 + 0.11 * k)
            e = T(x, y, g + 90)((k % 3 - 1) * w0 * 0.22); a.dot(e[0], e[1], 0.32, "pale")
    for o in ([0.25, -0.2] if ridge else []):
        a.line(opath([T(*q.pt(u), q.ang(u) + 90)(o * w0) for u in (0.08, 0.4, 0.7, 0.9)]), 0.4, 0.4)
    if remains:   # the withered flower at the tip
        e = q.pt(1); g = q.ang(1)
        blade(a, *T(*e, g)(w1 * 0.3), g + 12, w1 * 0.9, w1 * 0.55, remains, prof(0.5), veins=0, lw=0.6, petal=True)
        blade(a, *T(*e, g)(w1 * 0.3), g - 16, w1 * 0.8, w1 * 0.45, remains, prof(0.5), veins=0, lw=0.6, petal=True)
    return q


def gourd_seedling(slug, cot_b=0.5, cot_L=19, true_R=6.0):
    def draw():
        a = Art(); soil(a, 72); roots(a, 50, 72, 3, 12, 56)
        a.ribbon((50, 72), (49.5, 64), (50, 56), 3.0, 2.6, "pale", lw=0.9)
        for g in (-166, -14):   # two big smooth seed leaves, rounded at the tip
            blade(a, 50, 56, g, cot_L, cot_L * cot_b, "leaf", prof(0.5, "round", "round", tp=2.4), veins=2, lw=1.0)
        a.line("M50,56 L50.6,51", 1.0, 0.85)
        gleaf(a, slug, 50.6, 51, -96, true_R, pal(slug, "leaf", "leaf"))
        return a
    return draw


def courgette_plant(stage):
    def draw():
        lc = pal("courgette", "leaf", "deep")
        a = Art(); soil(a, 86, marks=False)
        crown = (50, 82)
        a.ribbon((38, 86), (42, 83), crown, 5.0, 4.4, "pale", lw=0.9)   # the short thick stem, leaning
        spots = {"young": [((26, 56), 16), ((74, 56), 16), ((50, 38), 18), ((62, 70), 10)],
                 "flower": [((19, 50), 17), ((81, 50), 17), ((38, 30), 18), ((64, 28), 18)],
                 "crop": [((19, 46), 17), ((81, 46), 17), ((38, 26), 18), ((64, 24), 18)]}[stage]
        with a.on(STEM):
            for (x, y), R in spots:
                q = a.ribbon(crown, ((crown[0] + x) / 2 + (x - crown[0]) * 0.12, (crown[1] + y) / 2 + 3), (x, y), 2.6, 1.8, lc, lw=0.8)
                bristles(a, q, 7, 1.1, 0.5)
        with a.on(LEAF):
            for (x, y), R in spots:
                g = math.degrees(math.atan2(y - crown[1], x - crown[0]))
                gleaf(a, "courgette", x, y, g * 0.6 - 36, R)
        with a.on(BLOOM):
            if stage == "flower":   # trumpets low in the middle, among the leaf stalks
                trumpet(a, (54, 76), -64, 20, 18, "sun", "amber", True, 0.85)
                trumpet(a, (44, 80), -124, 18, 16, "sun", "amber", True, 0.8, "long", "marrow")
            if stage == "crop":     # the fruit lying in the middle on short hard stalks
                gfruit_long(a, (47, 81), (36, 79), (17, 82), 7.2, 6.4, "marrow")
                gfruit_long(a, (54, 80), (64, 77), (80, 76), 6.2, 5.6, "marrow")
                trumpet(a, (51, 74), -80, 16, 14, "sun", "amber", True, 0.7)
        return a
    return draw


STAGE["courgette"] = {
    "seed": sown(gseed("veg_cream", 28, 15, 0.4)),
    "seedling": gourd_seedling("courgette", 0.5, 20, 7),
    "young": courgette_plant("young"), "flower": courgette_plant("flower"), "crop": courgette_plant("crop"),
}


def trail_plant(slug, stage):
    """Squash and melon: a vine running along the ground, rooting at its
    joints, the leaves standing up on long stalks, tendrils at the joints."""
    def draw():
        lc = pal(slug, "leaf", "leaf"); fc = pal(slug, "flower", "sun"); cen = pal(slug, "centre", "amber")
        frc = pal(slug, "fruit", "carrot")
        sq = slug == "squash"
        a = Art(); soil(a, 86, marks=False)
        n = 3 if stage == "young" else 5
        x0, x1 = (30, 70) if stage == "young" else (14, 90)
        q = a.ribbon((x0, 85), ((x0 + x1) / 2, 82.5), (x1, 85), 2.6, 1.6, "leaf" if sq else lc, lw=0.8)
        a.roots(x0, 85.5, 3, 5, 60)
        R = (12.5 if sq else 10) * (0.9 if stage == "young" else 1)
        H = (34 if sq else 24) * (0.8 if stage == "young" else 1)
        joints = [0.12 + 0.8 * i / (n - 1) for i in range(n)]
        for i, u in enumerate(joints):
            x, y = q.pt(u); sd = -1 if i % 2 else 1
            hh = H * (0.82 + 0.25 * ((i * 7) % 3) / 2) * (0.75 if stage == "crop" and i in (1, 3) else 1)
            e = (x + sd * 4, y - hh)
            with a.on(STEM):
                a.ribbon((x, y), (x - sd * 1.5, y - hh * 0.5), e, 1.8, 1.4, lc, lw=0.7)
                tendril(a, x, y - 1, -40 if sd > 0 else -140, 9, arms=3 if sq else 1, curl=sd)
                if i:
                    a.roots(x, y + 0.5, 2, 4, 40)
            with a.on(LEAF):
                gleaf(a, slug, e[0], e[1], -90 + sd * 14, R)
            if stage == "flower" and i % 2 == 1:
                with a.on(BLOOM):
                    a.stem((x, y), (x + sd * 2, y - 4), (x + sd * 4, y - 8), 1.0)
                    if sq:
                        trumpet(a, (x + sd * 4, y - 8), -90 + sd * 46, 16, 15, fc, cen, False, 0.95)
                    else:
                        gourd_face(a, x + sd * 5, y - 15, 5.2, fc, cen, "melon", k=0.8)
        if stage == "crop":
            with a.on(BLOOM):
                for u, k in ((0.3, 1.0), (0.72, 0.85)):
                    x, y = q.pt(u)
                    if sq:   # an onion-shaped squash, red-orange, on a thick round corky stalk
                        r = 11 * k; cx = x + 4; cy = 85 - r * 0.8
                        a.shape(f"M{f(cx)},{f(cy - r * 1.05)} C{f(cx + r * 0.5)},{f(cy - r * 0.95)} {f(cx + r * 1.25)},{f(cy - r * 0.2)} {f(cx + r * 1.15)},{f(cy + r * 0.35)} "
                                f"C{f(cx + r * 1.0)},{f(cy + r * 0.85)} {f(cx - r * 1.0)},{f(cy + r * 0.85)} {f(cx - r * 1.15)},{f(cy + r * 0.35)} "
                                f"C{f(cx - r * 1.25)},{f(cy - r * 0.2)} {f(cx - r * 0.5)},{f(cy - r * 0.95)} {f(cx)},{f(cy - r * 1.05)} Z", frc, 1.0)
                        for o in (-0.6, -0.2, 0.25, 0.65):   # faint paler stripes
                            a.line(f"M{f(cx + o * r * 0.3)},{f(cy - r * 0.95)} Q{f(cx + o * r * 1.3)},{f(cy)} {f(cx + o * r * 0.9)},{f(cy + r * 0.7)}", 0.6, 0.35, "primrose")
                        a.shape(f"M{f(cx + r * 0.2)},{f(cy - r * 0.9)} C{f(cx + r * 1.1)},{f(cy - r * 0.6)} {f(cx + r * 1.2)},{f(cy + r * 0.4)} {f(cx + r * 0.7)},{f(cy + r * 0.72)} C{f(cx + r * 0.9)},{f(cy)} {f(cx + r * 0.8)},{f(cy - r * 0.5)} {f(cx + r * 0.2)},{f(cy - r * 0.9)} Z", "shade", 0, fa=0.12)
                        a.ribbon((x, y - 0.5), (cx - 1, cy - r * 1.3), (cx, cy - r * 0.95), 2.8, 3.6, "straw", lw=0.8)
                    else:    # a round melon with a fine raised net
                        r = 8 * k; cx = x + 3; cy = 85 - r * 0.92
                        a.oval(cx, cy, r, r * 0.94, 0, frc, 1.0)
                        for j in range(5):
                            g = -70 + 35 * j
                            a.line(f"M{f(cx)},{f(cy - r * 0.94)} Q{f(cx + r * 1.1 * math.sin(math.radians(g)))},{f(cy)} {f(cx)},{f(cy + r * 0.94)}", 0.45, 0.35)
                        for j in range(12):
                            p = (cx + r * 0.75 * math.sqrt((j + 0.5) / 12) * math.cos(j * GOLD), cy + r * 0.7 * math.sqrt((j + 0.5) / 12) * math.sin(j * GOLD))
                            a.line(f"M{f(p[0] - 1)},{f(p[1])} L{f(p[0])},{f(p[1] - 0.8)} L{f(p[0] + 1)},{f(p[1])}", 0.35, 0.35)
                        a.line(f"M{f(x)},{f(y)} L{f(cx)},{f(cy - r * 0.9)}", 1.0, 0.85)
        return a
    return draw


def climb_plant(slug, stage):
    """Cucumber: a vine trained up a cane, simple coiling tendrils at each
    joint, small yellow flowers and the long fruit hanging from the joints.
    Loofah: the same up a post and along a wire, the fruit hanging down."""
    def draw():
        lc = pal(slug, "leaf", "deep"); fc = pal(slug, "flower", "sun"); cen = pal(slug, "centre", "amber")
        frc = pal(slug, "fruit", "marrow")
        lf = slug == "loofah"
        a = Art(); soil(a, 88)
        top = 26 if stage == "young" else 8
        with a.on(STEM):
            a.ribbon((50, 89), (50, 50), (50, top - 2 if not lf else 10), 2.0, 1.8, "bark", lw=0.8)
            if lf and stage != "young":
                a.line("M8,12 L92,12", 0.8, 0.7)
        n = 4 if stage == "young" else 7
        H = 88 - top
        pts = []
        for i in range(n + 1):
            yv = 86 - H * i / n; xv = 50 + (2.2 if i % 2 else -2.2)
            pts.append((xv, yv))
        if lf and stage != "young":   # along the wire to both sides
            pts += [(60, 13), (78, 14), (92, 13)]
        with a.on(STEM):
            a.line("M" + " L".join(P(p) for p in pts), 1.4, 0.85)
        R = 10 if not lf else 10.5
        for i, (x, y) in enumerate(pts[1:-1] if not lf or stage == "young" else pts[1:n] + pts[n + 1:]):
            sd = -1 if i % 2 else 1
            on_wire = lf and stage != "young" and y < 20
            e = (x + sd * 12, y - 6) if not on_wire else (x + 2, y - 2)
            with a.on(STEM):
                if not on_wire:
                    a.stem((x, y), (x + sd * 6, y - 1), e, 0.9)
                tendril(a, x, y, (180 if sd > 0 else 0) + sd * 25, 7, arms=4 if lf else 1, curl=-sd)
            with a.on(LEAF):
                if on_wire:
                    gleaf(a, slug, x, y + 1, -100, R * 0.9)
                else:
                    gleaf(a, slug, e[0], e[1], -90 + sd * 30, R * (1 - 0.03 * i))
            with a.on(BLOOM):
                if stage == "flower" and i % 2 == 0 and i < 6:
                    if lf:   # a long-stalked cluster: one open saucer, buds
                        p = (x - sd * 7, y - 3)
                        a.stem((x, y), (x - sd * 4, y + 1), p, 0.8)
                        a.oval(p[0] - sd * 1.5, p[1] + 2.4, 1.2, 1.6, 0, "unripe", 0.6)
                        gourd_face(a, p[0], p[1] - 2, 6.5, fc, cen, "loofah", k=0.85)
                    else:
                        gourd_face(a, x - sd * 5, y - 1, 4.4, fc, cen, "cucumber", k=0.85)
                        if i == 2:
                            gourd_female(a, x - sd * 4, y + 6, 90 + sd * 30, 3.4, fc, cen, "cucumber", 0.4)
                if stage == "crop" and (i in (1, 2, 5) if not lf else on_wire):
                    p = (x - sd * 9, y + 1)
                    if lf:
                        gfruit_long(a, (x, y + 1), (x + 1, y + 22), (x - 1, y + 44), 4.8, 6.2, frc, speck=False, remains=None, ridge=1)
                    else:
                        a.stem((x, y), (x - sd * 4, y - 1), p, 0.9)
                        gfruit_long(a, p, (p[0] - sd * 1.5, p[1] + 12), (p[0] - sd * 1, p[1] + 26 - i), 4.6, 4.0, frc, speck=True, remains="primrose")
        return a
    return draw


STAGE["squash"] = {"seed": sown(gseed("veg_cream", 30, 19, 0.15)), "seedling": gourd_seedling("squash", 0.58, 19, 6.5),
                   "young": trail_plant("squash", "young"), "flower": trail_plant("squash", "flower"), "crop": trail_plant("squash", "crop")}
STAGE["melon"] = {"seed": sown(gseed("veg_cream", 20, 8.5, 0.5)), "seedling": gourd_seedling("melon", 0.56, 15, 5.5),
                  "young": trail_plant("melon", "young"), "flower": trail_plant("melon", "flower"), "crop": trail_plant("melon", "crop")}
STAGE["cucumber"] = {"seed": sown(gseed("veg_cream", 24, 9.5, 0.6)), "seedling": gourd_seedling("cucumber", 0.48, 17, 5.5),
                     "young": climb_plant("cucumber", "young"), "flower": climb_plant("cucumber", "flower"), "crop": climb_plant("cucumber", "crop")}
STAGE["loofah"] = {"seed": sown(gseed("dark", 25, 14, 0.3)), "seedling": gourd_seedling("loofah", 0.44, 18, 6.0),
                   "young": climb_plant("loofah", "young"), "flower": climb_plant("loofah", "flower"), "crop": climb_plant("loofah", "crop")}


# ================================================================ SIMPLE LEAVES
def margin_of(m):
    """A margin written in a kind's settings: ("teeth", n, depth[, kind, jag, start])
    or ("waves", n, depth)."""
    if not m:
        return None
    if m[0] == "teeth":
        return teeth(m[1], m[2], m[5] if len(m) > 5 else 0.08, 0.95, m[3] if len(m) > 3 else "saw", m[4] if len(m) > 4 else 0)
    return waves(m[1], m[2])


def simple_blade(a, x, y, ang, L, sp, fill, lw=1.0, detail=True):
    pr = prof(*sp["pr"])
    return blade(a, x, y, ang, L, L * sp["W"], fill, pr, margin_of(sp.get("mg")), veins=sp.get("veins", 6) if detail else 0,
                 lw=lw, midc=sp.get("veinc", "line"), mid=0.8 if detail else 0, shade=0.1 if detail else 0.08,
                 vla=sp.get("vla", 0.36))


def leaf_simple(a, sp):
    """A simple leaf on its stalk: the profile, edge and veins come from the
    kind's settings (pr, W, mg, veins, veinc, petiole, stalkw)."""
    pf = sp.get("petiole", 0.2); t = T(*BASE, ANG); A = t(98 * pf)
    a.ribbon(BASE, t(98 * pf * 0.5, 1.2), A, sp.get("stalkw", 2.4), sp.get("stalkw", 2.4) * 0.75, sp["fill"], lw=0.9)
    simple_blade(a, A[0], A[1], ANG, 98 * (1 - pf) * sp.get("len", 1.0), sp, sp["fill"], lw=1.15)
    if sp.get("decur"):   # the blade running down into the stalk as a narrow wing
        for sg in (1, -1):
            a.shape(path([t(98 * pf * 0.45), t(98 * pf + 2, sg * 2.2), t(98 * pf + 1, 0)]), sp["fill"], 0.9)
    return a


LEAF_DRAW["veg_simple"] = leaf_simple


def spec(slug):
    """The kind's close-up leaf settings, colours from its description."""
    import leaves_flowers as LFW
    return LFW.leaf_spec(slug, LFW.settings(slug))


def oleaf(a, slug, x, y, ang, L, fill=None, stalk=0.0, lw=None):
    """One of the kind's own simple leaves, L long, on the whole plant. With
    stalk, a stalk that long comes first."""
    sp = spec(slug)
    if stalk:
        e = T(x, y, ang)(stalk); a.line(f"M{P((x, y))} L{P(e)}", 0.8, 0.85); x, y = e

    def build():
        b = Art(); simple_blade(b, 0, 0, 0, 40, sp, sp["fill"], lw=1.1)
        b.anchor, b.anchor_ang, b.size = (0, 0), 0, 40
        return b
    src = small(("simple", slug), build)
    put(a, src, x, y, ang, L, lw=lw, fills={sp["fill"]: fill} if fill and fill != sp["fill"] else None)


def own(a, slug, x, y, ang, L, fill=None, lw=None, detail=None, **over):
    """The kind's whole close-up leaf (stalk and all), drawn L long. over
    changes a setting for the small copy only (pea: no piece of stem)."""
    import leaves_flowers as LFW
    sp = dict(spec(slug), **over)

    def build():
        b = LFW.LEAF_DRAW[sp["kind"]](Art(), sp)
        b.anchor, b.anchor_ang, b.size = BASE, ANG, 98
        return b
    src = small(("own", slug, tuple(sorted(over.items()))), build)
    put(a, src, x, y, ang, L, lw=lw, fills={sp["fill"]: fill} if fill and fill != sp["fill"] else None, detail=detail)


# ------------------------------------------------------------ the tomato leaf
def leaf_tomato(a, sp):
    """Tomato: an irregular pinnate leaf. Big leaflets on short stalks of
    their own, lopsided and coarsely toothed, often lobed near the base;
    tiny leaflets between them; one at the tip. Puckered between the veins."""
    fill = sp["fill"]; t = T(*BASE, ANG)
    q = Quad(BASE, t(46, -3), t(80))
    a.ribbon(q.p0, q.c, q.p1, 2.4, 1.3, fill, lw=0.8)
    pr = prof(0.4, "round", "point", bp=0.6, tp=0.9)
    lob = lambda u, side: teeth(7, 0.2, 0.06, 0.95, "saw", 0.6)(u, side) * (1 - 0.32 * math.exp(-((u - 0.2) / 0.08) ** 2))
    for i, (u, L) in enumerate(((0.3, 25), (0.55, 24), (0.78, 21))):
        x, y = q.pt(u); g = q.ang(u)
        for sg in (1, -1):
            e = T(x, y, g + sg * 62)(3)
            a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.8, 0.85)
            blade(a, *e, g + sg * 56, L, L * 0.52, fill, pr, lob, veins=4, lw=0.95, lop=0.12 * sg)
            for v in (0.35, 0.6):   # the puckering: short creases between the veins
                c = T(*e, g + sg * 56)(L * v, sg * L * 0.1)
                a.line(f"M{P(T(*c, g)(-1.2))} Q{P(T(*c, g + 90)(0.6))} {P(T(*c, g)(1.2))}", 0.35, 0.25)
        if i < 2:   # tiny leaflets between the pairs
            x2, y2 = q.pt(u + 0.13)
            for sg in (1, -1):
                blade(a, x2, y2, q.ang(u) + sg * 70, 7, 3.6, fill, prof(0.45), teeth(2, 0.2), veins=0, lw=0.7)
    ex, ey = q.pt(1)
    blade(a, ex, ey, q.ang(1), 22, 12, fill, pr, lob, veins=4, lw=0.95)
    return a


LEAF_DRAW["veg_tomato"] = leaf_tomato


# ================================================================ STAR AND WHEEL FLOWERS
def wheel(a, cx, cy, R, n, fill, join=0.3, pp=0.8, k=0.86, start=-90, lw=0.9, lines=True, rnd=0.0):
    """A flower of joined petals seen face on: n lobes, joined for `join` of
    their length (0: free petals, a star; 0.85: a bowl with shallow lobes).
    pp shapes the lobes (smaller is broader); rnd rounds their tips."""
    tips = [math.radians(start + 360 * i / n) for i in range(n)]
    step = 2 * math.pi / n

    def r(h):
        v = ((h - tips[0]) % step) / step          # 0 at one tip, 1 at the next
        v = min(v, 1 - v) * 2                      # 0 at a tip, 1 at the bay between
        pointed = (1 - v) ** pp
        rounded = math.cos(math.pi / 2 * v) ** 0.7
        return join + (1 - join) * (rnd * rounded + (1 - rnd) * pointed)
    hs = [2 * math.pi * i / (n * 24) for i in range(n * 24)]
    pts = [(cx + R * r(h) * math.cos(h), cy + R * r(h) * math.sin(h) * k) for h in hs]
    a.shape(path(pts), fill, lw)
    half = [p for h, p in zip(hs, pts) if math.sin(h) > -0.2]
    if lines:
        for h in tips:   # a crease down the middle of each lobe, a fold between
            e = (cx + R * 0.86 * math.cos(h), cy + R * 0.86 * math.sin(h) * k)
            a.line(f"M{f(cx)},{f(cy)} L{P(e)}", 0.5, 0.35)
            h2 = h + step / 2
            e2 = (cx + R * join * 0.95 * math.cos(h2), cy + R * join * 0.95 * math.sin(h2) * k)
            if join > 0.25:
                a.line(f"M{P(lerp((cx, cy), e2, 0.35))} L{P(e2)}", 0.4, 0.28)
    return lambda h, rr: (cx + R * rr * math.cos(math.radians(h)), cy + R * rr * math.sin(math.radians(h)) * k)


def cone(a, cx, cy, L, W, ang, fill):
    """The cone of joined anthers in the middle of a tomato or aubergine flower."""
    t = T(cx, cy, ang)
    a.shape(path([t(0, W / 2), t(L * 0.55, W * 0.38), t(L, 0), t(L * 0.55, -W * 0.38), t(0, -W / 2)]), fill, 0.7)
    a.line(f"M{P(t(0))} L{P(t(L * 0.9))}", 0.4, 0.4)


def nodding(a, x, y, ang, L, fill, sep="leaf", swept=False, cen=None, cenL=0.0, n=3, wide=0.5, sepL=0.5):
    """A flower seen from the side, hanging along ang from its stalk at x,y.
    swept: the petals bent right back towards the stalk (tomato)."""
    t = T(x, y, ang)
    for sg in (-1, 1):   # sepals
        blade(a, x, y, ang + sg * (60 if swept else 30), L * sepL, L * 0.12, sep, prof(0.3), veins=0, lw=0.6, petal=True)
    base = t(L * 0.18)
    if swept:
        for g in (-150, 150, -125, 125):
            blade(a, *base, ang + g, L * 0.75, L * 0.18, fill, prof(0.35, "round", "point"), veins=0, lw=0.7, petal=True)
        cone(a, *base, L * 0.8, L * 0.24, ang, cen or "sun")
        return
    for j in range(n):
        g = (j - (n - 1) / 2) * 26
        blade(a, *base, ang + g, L, L * wide, fill, prof(0.6, "round", "point", tp=0.8), veins=0, lw=0.7, petal=True)
    if cen:
        cone(a, *t(L * 0.3), L * cenL, L * 0.22, ang, cen)


def fl_solanum(a, sp):
    """The nightshade flowers: tomato, aubergine, chilli, tomatillo and
    Chinese lanterns. One flower face on, and one or more from the side."""
    fc, cen, kind = sp["fc"], sp.get("cen", "sun"), sp["sk"]
    if kind == "tomato":   # a truss of nodding flowers, petals swept back round a pointed cone
        q = Quad((60, 98), (64, 70), (52, 50))
        a.ribbon(q.p0, q.c, q.p1, 2.4, 2.0, "leaf", lw=0.8)
        tr = Quad((52, 50), (40, 38), (26, 46))
        a.line(tr.d(), 1.1, 0.85)
        for u, sd in ((0.35, 1), (0.7, -1)):
            p = tr.pt(u); e = (p[0] + sd * 6, p[1] + 8)
            a.line(f"M{P(p)} Q{f(p[0] + sd * 4)},{f(p[1] + 1)} {P(e)}", 0.8, 0.85)
            nodding(a, *e, 80 + sd * 18, 15, fc, swept=True, cen=cen)
        a.line("M26,46 Q22,50 22,56", 0.8, 0.85); blade(a, 22, 56, 92, 8, 3.4, "leaf", prof(0.5), veins=0, lw=0.6, petal=True)
        # one flower face on, close: six narrow petals swept back, sepals between, the cone pointing out
        cx, cy = 68, 34
        a.line(f"M52,50 Q62,46 {cx},{cy + 3}", 0.9, 0.85)
        sepals(a, cx, cy, 6, 21, 3.2, "leaf", -90, 0.86, 0.6)
        M = face(a, cx, cy, 6, 20, 6.4, fc, prof(0.3, "round", "point", tp=0.8), 0.86, -60, lines=1)
        a.oval(cx, cy, 5.2, 4.6, 0, cen, 0.7)
        for j in range(6):
            e = M(T(cx, cy, j * 60 - 30)(4.6)); a.line(f"M{f(cx)},{f(cy)} L{P(e)}", 0.4, 0.4)
        a.dot(cx, cy, 1.1, "unripe")
        return a
    if kind == "aubergine":
        a.ribbon((40, 98), (36, 70), (44, 40), 3.4, 2.8, "sage", lw=0.9)
        a.line("M44,40 Q54,30 60,34", 1.4, 0.85)
        cx, cy = 58, 52
        for i in range(6):   # the big felted calyx, its lobes showing between the petals
            blade(a, cx, cy, -90 + 60 * (i + 0.5), 17, 6, "sage", prof(0.35, "round", "point"), veins=0, lw=0.7, petal=True, M=tilt(cy, 0.86))
        a.line(f"M60,34 Q62,40 {cx},{cy - 6}", 1.6, 0.85)
        at = wheel(a, cx, cy, 27, 6, fc, join=0.5, pp=0.85, start=-60)
        for j in range(6):   # darker veins in each lobe
            p0 = at(-60 + 60 * j, 0.25); p1 = at(-60 + 60 * j, 0.8)
            a.line(f"M{P(p0)} L{P(p1)}", 0.6, 0.6, "plum")
        cone(a, cx, cy + 1, 13, 7, 100, cen)
        for sg in (-1, 1):
            a.line(f"M{f(cx)},{f(cy + 1)} L{f(cx + sg * 2.4)},{f(cy + 11)}", 0.5, 0.6)
        nodding(a, 30, 40, 96, 18, fc, "sage", cen=None, n=3, wide=0.55, sepL=0.6)
        a.line("M44,40 Q34,34 30,40", 1.0, 0.85)
        return a
    if kind == "chilli":   # small white stars, nodding, blue-violet anthers
        a.ribbon((44, 98), (44, 70), (46, 46), 2.6, 2.2, "leaf", lw=0.8)
        for sd in (-1, 1):   # the stem forks; a flower hangs in the fork
            a.ribbon((46, 46), (46 + sd * 10, 40), (46 + sd * 22, 28), 2.2, 1.6, "leaf", lw=0.8)
        a.line("M46,46 Q44,52 40,56", 0.9, 0.85)
        cx, cy = 36, 66
        sepals(a, cx, cy, 5, 7, 6, "leaf", -54, 0.8)
        M = face(a, cx, cy, 5, 20, 8.6, fc, prof(0.4, "round", "point", tp=0.9), 0.8, -54, lines=1)
        for j in range(5):
            e = M(T(cx, cy, -18 + 72 * j)(6)); a.line(f"M{f(cx)},{f(cy)} L{P(e)}", 0.6, 0.7)
            a.oval(e[0], e[1], 1.5, 2.0, -18 + 72 * j, cen, 0.5)
        a.dot(cx, cy, 1.0, "unripe")
        a.line("M60,36 Q70,40 70,50", 0.8, 0.85)
        nodding(a, 70, 50, 96, 16, fc, n=3, wide=0.42)
        return a
    if kind == "tomatillo":   # an open yellow bowl, five dark blotches in the throat
        a.ribbon((40, 98), (38, 72), (44, 54), 2.6, 2.2, "leaf", lw=0.8)
        cx, cy = 50, 42
        sepals(a, cx, cy, 5, 25, 7, "leaf", -90, 0.84)
        at = wheel(a, cx, cy, 31, 5, fc, join=0.84, pp=1.0, start=-54, rnd=0.7)
        for j in range(5):
            p = at(-90 + 72 * j, 0.4)
            a.oval(p[0], p[1], 4.6, 3.6, -90 + 72 * j, "dark", 0)
        for j in range(5):
            e = at(-54 + 72 * j, 0.2); a.line(f"M{f(cx)},{f(cy)} L{P(e)}", 0.8, 0.7)
            a.oval(e[0], e[1], 1.7, 2.3, -54 + 72 * j, cen, 0.5)
        a.dot(cx, cy, 1.3, "unripe")
        return a
    # Chinese lanterns: a small creamy star, hanging on a curved stalk under a leaf
    a.ribbon((26, 98), (24, 60), (30, 14), 2.8, 2.2, "leaf", lw=0.8)
    a.line("M28,40 Q50,30 56,46", 1.0, 0.85)
    cx, cy = 58, 62
    a.line(f"M56,46 L{cx},{cy - 6}", 1.0, 0.85)
    sepals(a, cx, cy, 5, 12, 6, "leaf", -90, 0.8)
    at = wheel(a, cx, cy, 25, 5, fc, join=0.6, pp=0.9, k=0.8, start=-54)
    a.oval(cx, cy, 7, 5.6, 0, cen, 0)
    for j in range(5):
        e = at(-18 + 72 * j, 0.24); a.line(f"M{f(cx)},{f(cy)} L{P(e)}", 0.6, 0.7)
        a.oval(e[0], e[1], 1.2, 1.6, 0, "sun", 0.5)
    a.dot(cx, cy, 1.2, "unripe")
    return a


BLOOM_DRAW["veg_solanum"] = fl_solanum
BLOOMX.update({
    "tomato": dict(kind="veg_solanum", sk="tomato", fc="sun", cen="amber"),   # one of the ten: colours written in
    "aubergine": dict(kind="veg_solanum", sk="aubergine"),
    "chilli-pepper": dict(kind="veg_solanum", sk="chilli"),
    "tomatillo": dict(kind="veg_solanum", sk="tomatillo"),
    "chinese-lanterns": dict(kind="veg_solanum", sk="lanterns"),
})
LEAFX.update({
    "tomato": dict(kind="veg_tomato", fill="deep"),
    "aubergine": dict(kind="veg_simple", pr=(0.45, "round", "point", 0.6, 1.0), W=0.66, mg=("waves", 4, 0.13), veins=6,
                      veinc="plum", vla=0.5, petiole=0.17, stalkw=3.0),
    "chilli-pepper": dict(kind="veg_simple", pr=(0.36, "round", "acum", 0.75, 1.3), W=0.42, len=0.92, veins=7, petiole=0.2, stalkw=1.8),
    "tomatillo": dict(kind="veg_simple", pr=(0.36, "round", "point", 0.8, 1.1), W=0.52, len=0.9, mg=("teeth", 5, 0.2, "saw", 0.7, 0.2),
                      veins=6, petiole=0.26, stalkw=1.8),
    "chinese-lanterns": dict(kind="veg_simple", pr=(0.42, "round", "point", 1.5, 1.0), W=0.62, len=0.92, mg=("waves", 3, 0.06), veins=5,
                             petiole=0.2, stalkw=1.8, decur=True),
})


# ------------------------------------------------------------ nightshade life stages
def nseed(fill, n=1, hairy=False, kidney=0.12, R=10):
    """Small flat rounded nightshade seeds, with the little notch where they
    were joined on. hairy: the fine hairs of a tomato seed."""
    def draw(a, x, y):
        spots = [(0, 0, 1.0)] if n == 1 else [(-11, 3, 0.8), (8, -3, 0.85), (2, 10, 0.7)][:n]
        for dx, dy, k in spots:
            cx, cy, r = x + dx, y + dy, R * k
            a.polar(cx, cy, lambda h: 1 - kidney * math.exp(-((h - 0.5) / 0.35) ** 2), r, r * 0.88, dx * 4, fill, 1.0)
            a.oval(cx - r * 0.1, cy + r * 0.05, r * 0.55, r * 0.46, dx * 4, None, 0.6, la=0.35)
            if hairy:
                for j in range(26):
                    h = 2 * math.pi * j / 26; e0 = (cx + r * 0.98 * math.cos(h), cy + r * 0.86 * math.sin(h))
                    e1 = (cx + r * 1.12 * math.cos(h + 0.08), cy + r * 1.0 * math.sin(h + 0.08))
                    a.line(f"M{P(e0)} L{P(e1)}", 0.35, 0.5)
    return draw


def nseedling(slug, cotL=16, cotb=0.2, true_L=11, compound=False):
    def draw():
        a = Art(); soil(a, 72); roots(a, 50, 72, 3, 12, 50)
        a.ribbon((50, 72), (49.4, 63), (50, 54), 1.8, 1.5, "plum" if slug == "tomato" else "pale", lw=0.8)
        for g in (-162, -18):
            blade(a, 50, 54, g, cotL, cotL * cotb, "leaf", prof(0.5, "round", "point" if cotb < 0.3 else "round"), veins=0, lw=0.9)
        if compound:
            own(a, slug, 50, 54, -86, true_L * 1.6)
        else:
            a.line("M50,54 L50.4,50", 0.9, 0.85)
            oleaf(a, slug, 50.4, 50, -98, true_L)
            oleaf(a, slug, 50.4, 51, -70, true_L * 0.6)
        return a
    return draw


def tomato_fruit(a, x, y, r, col):
    a.oval(x, y + r, r, r * 0.92, 0, col, 0.9)
    a.line(f"M{f(x - r * 0.45)},{f(y + r * 0.6)} Q{f(x - r * 0.7)},{f(y + r)} {f(x - r * 0.45)},{f(y + r * 1.4)}", 0.5, 0.35, "white")
    for k in range(5):   # the green star of sepals left on top
        blade(a, x, y + r * 0.14, -90 + (k - 2) * 44 + 180 * (k % 2 == 5), r * 0.75, r * 0.22, "leaf", prof(0.3), veins=0, lw=0.5, petal=True, M=tilt(y + r * 0.14, 0.5))


def tomato_plant(stage):
    """A cordon tomato tied to a cane: leaves all the way up, and trusses of
    flowers or fruit coming from the stem BETWEEN the leaves."""
    def draw():
        a = Art(); soil(a, 88)
        fc = "sun"; frc = "berry"
        top = 30 if stage == "young" else 8
        with a.on(STEM):
            a.ribbon((58, 89), (58, 50), (58, top - 6), 2.0, 1.8, "bark", lw=0.8)
        q = a.ribbon((50, 88), (53, (88 + top) / 2), (52, top), 3.0, 1.6, "leaf", lw=0.8)
        with a.on(STEM):
            for u in (0.3, 0.62, 0.9):   # ties to the cane
                x, y = q.pt(u); a.line(f"M{f(x - 1)},{f(y)} Q{f(x + 3)},{f(y - 2)} {f(59.5)},{f(y + 0.5)}", 0.6, 0.6, "straw")
        n = 4 if stage == "young" else 6
        for i in range(n):
            u = 0.14 + 0.78 * i / (n - 1); x, y = q.pt(u); sd = -1 if i % 2 else 1
            with a.on(LEAF):
                own(a, "tomato", x, y, -90 + sd * (62 - 8 * u), (30 if stage == "young" else 27) * (1 - 0.3 * u))
            if stage != "young" and 0 < i < n - 1:   # a truss, from the stem between this leaf and the next
                xm, ym = q.pt(u + 0.39 / (n - 1)); sdx = -sd
                e = (xm + sdx * 11, ym + 2)
                with a.on(BLOOM):
                    a.line(f"M{f(xm)},{f(ym)} Q{f(xm + sdx * 6)},{f(ym - 4)} {P(e)}", 0.9, 0.85)
                    if stage == "flower":
                        for k, (dx, dy) in enumerate([(0, 0), (5, 2.5), (-4, 3.5)]):
                            p = (e[0] + sdx * dx, e[1] + dy)
                            a.line(f"M{P(e)} L{P(p)}", 0.6, 0.8)
                            nodding(a, p[0], p[1], 90 + sdx * 10, 8.0, fc, swept=True, cen="amber")
                    else:
                        ripe = i in (1, 2)
                        for k, (dx, dy, r) in enumerate([(0, 0, 4.6), (5.5, 2, 4.2), (-4, 4, 3.8)]):
                            p = (e[0] + sdx * dx, e[1] + dy)
                            a.line(f"M{P(e)} L{P(p)}", 0.6, 0.8)
                            tomato_fruit(a, p[0], p[1], r * (0.85 if not ripe else 1), frc if ripe and k < 2 else ("amber" if ripe else "unripe"))
        with a.on(LEAF):
            own(a, "tomato", 52, top + 1, -100, 13)
        return a
    return draw


STAGE["tomato"] = {
    "seed": sown(nseed("seed", hairy=True, R=11)),
    "seedling": nseedling("tomato", 15, 0.2, 10, compound=True),
    "young": tomato_plant("young"), "flower": tomato_plant("flower"), "crop": tomato_plant("crop"),
}


def calyx_cap(a, x, y, w, ang, col="sage", n=5):
    """The big calyx left on top of an aubergine: lobes lying down over the fruit."""
    for k in range(n):
        g = ang + (k - (n - 1) / 2) * (110 / (n - 1))
        blade(a, x, y, g, w, w * 0.42, col, prof(0.35, "round", "point"), veins=0, lw=0.6, petal=True)


def aubergine_plant(stage):
    def draw():
        a = Art(); soil(a, 88)
        lc = pal("aubergine", "leaf", "sage"); fc = pal("aubergine", "flower", "lilac"); frc = pal("aubergine", "fruit", "plum")
        sc = "sage"
        H = 0.7 if stage == "young" else 1.0
        q = a.ribbon((50, 88), (51, 88 - 30 * H), (50, 88 - 64 * H), 3.6, 2.0, sc, lw=0.8)
        br = []
        for u, sd in ((0.45, -1), (0.6, 1)):
            x, y = q.pt(u)
            br.append((a.ribbon((x, y), (x + sd * 10 * H, y - 6 * H), (x + sd * 20 * H, y - 22 * H), 2.2, 1.4, sc, lw=0.7), sd))
        with a.on(LEAF):
            for i, (u, sd, L) in enumerate(((0.2, -1, 26), (0.3, 1, 27), (0.75, -1, 22), (0.9, 1, 18))):
                x, y = q.pt(u); oleaf(a, "aubergine", x, y, -90 + sd * 64, L * H, lc, stalk=3 * H)
            for b, sd in br:
                x, y = b.pt(1); oleaf(a, "aubergine", x, y, -90 + sd * 30, 20 * H, lc, stalk=2)
                x, y = b.pt(0.5); oleaf(a, "aubergine", x, y, -90 - sd * 10, 16 * H, lc, stalk=2)
            x, y = q.pt(1); oleaf(a, "aubergine", x, y, -96, 13 * H, lc)
        with a.on(BLOOM):
            if stage == "flower":   # drooping singly on short stalks, between the leaves
                for b, sd in br:
                    x, y = b.pt(0.3)
                    a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 3)},{f(y - 2)} {f(x + sd * 4)},{f(y + 2)}", 0.8, 0.85)
                    nodding(a, x + sd * 4, y + 2, 90 - sd * 12, 11, fc, "sage", n=3, wide=0.6, sepL=0.55)
                x, y = q.pt(0.82)
                a.line(f"M{f(x)},{f(y)} Q{f(x + 4)},{f(y - 2)} {f(x + 5)},{f(y + 3)}", 0.8, 0.85)
                nodding(a, x + 5, y + 3, 82, 10.5, fc, "sage", n=3, wide=0.6, sepL=0.55)
            if stage == "crop":     # glossy dark purple fruit hanging, each with a green calyx cap
                for (b, sd), L in zip(br, (24, 20)):
                    x, y = b.pt(0.32); e = (x - sd * 1, y + 4)
                    a.line(f"M{f(x)},{f(y)} L{P(e)}", 1.2, 0.85)
                    r = L * 0.3
                    a.shape(f"M{f(e[0])},{f(e[1])} C{f(e[0] + r * 1.1)},{f(e[1] + 1)} {f(e[0] + r * 1.3)},{f(e[1] + L)} {f(e[0])},{f(e[1] + L)} C{f(e[0] - r * 1.3)},{f(e[1] + L)} {f(e[0] - r * 1.1)},{f(e[1] + 1)} {f(e[0])},{f(e[1])} Z", frc, 1.0)
                    a.line(f"M{f(e[0] - r * 0.55)},{f(e[1] + L * 0.3)} Q{f(e[0] - r * 0.8)},{f(e[1] + L * 0.6)} {f(e[0] - r * 0.5)},{f(e[1] + L * 0.85)}", 1.0, 0.5, "white")
                    calyx_cap(a, e[0], e[1], r * 1.0, 90, "sage")
        return a
    return draw


STAGE["aubergine"] = {
    "seed": sown(nseed("seed", n=3, R=8)),
    "seedling": nseedling("aubergine", 13, 0.5, 10),
    "young": aubergine_plant("young"), "flower": aubergine_plant("flower"), "crop": aubergine_plant("crop"),
}


def chilli_pod(a, x, y, L, col, sd=1):
    """A long chilli hanging from its stalk, tapering to a point, a green cup on top."""
    a.line(f"M{f(x)},{f(y - 3)} Q{f(x + sd)},{f(y - 1)} {f(x)},{f(y)}", 0.9, 0.85)
    a.ribbon((x, y + 1), (x + sd * L * 0.15, y + L * 0.5), (x - sd * L * 0.08, y + L), 4.4, 0.6, col, lw=0.8)
    a.line(f"M{f(x - 0.6)},{f(y + L * 0.2)} Q{f(x + sd * L * 0.08)},{f(y + L * 0.5)} {f(x)},{f(y + L * 0.75)}", 0.5, 0.45, "white")
    a.oval(x, y + 1.2, 2.2, 1.4, 0, "leaf", 0.7)


def chilli_plant(stage):
    """A small bush whose stems fork again and again, a flower or fruit in each fork."""
    def draw():
        a = Art(); soil(a, 88)
        lc = pal("chilli-pepper", "leaf", "deep"); fc = pal("chilli-pepper", "flower", "white"); frc = pal("chilli-pepper", "fruit", "berry")
        k = 0.72 if stage == "young" else 1.0
        F0 = (50, 88 - 26 * k)
        a.ribbon((50, 88), (50.5, 88 - 13 * k), F0, 3.0, 2.4, "leaf", lw=0.8)
        forks = [F0]; tips = []
        for (fx, fy) in [F0]:
            for sd in (-1, 1):
                F1 = (fx + sd * 15 * k, fy - 20 * k)
                a.ribbon((fx, fy), (fx + sd * 6 * k, fy - 8 * k), F1, 2.2, 1.7, "leaf", lw=0.75); forks.append(F1)
                for sd2 in (-1, 1):
                    F2 = (F1[0] + sd * (9 + sd2 * 5) * k, F1[1] - 18 * k)
                    a.ribbon(F1, ((F1[0] + F2[0]) / 2, (F1[1] + F2[1]) / 2 + 1), F2, 1.6, 1.1, "leaf", lw=0.7); tips.append((F2, sd))
        with a.on(LEAF):
            for (x, y), sd in tips:
                oleaf(a, "chilli-pepper", x, y, -90 + sd * 42, 15 * k, lc, stalk=2)
                oleaf(a, "chilli-pepper", x, y + 6 * k, -90 - sd * 50, 12 * k, lc, stalk=2)
            for (x, y) in forks:
                for sd in (-1, 1):
                    oleaf(a, "chilli-pepper", x, y, -90 + sd * 72, 15 * k, lc, stalk=2)
        with a.on(BLOOM):
            for j, (x, y) in enumerate(forks):
                if stage == "flower":   # one small white flower nodding in each fork
                    a.line(f"M{f(x)},{f(y)} Q{f(x + 2)},{f(y + 2)} {f(x + 2)},{f(y + 5)}", 0.6, 0.85)
                    nodding(a, x + 2, y + 5, 90, 5.6, fc, n=3, wide=0.45)
                    a.oval(x + 2, y + 9.4, 1.1, 0.7, 0, pal("chilli-pepper", "centre", "lilac"), 0.4)
                elif stage == "crop":
                    chilli_pod(a, x + (1.5 if j % 2 else -1.5), y + 3, 19 if j else 16, frc if j != 1 else "unripe", 1 if j % 2 else -1)
            if stage == "crop":
                (x, y), sd = tips[1]; chilli_pod(a, x, y + 3, 15, frc, -1)
        return a
    return draw


STAGE["chilli-pepper"] = {
    "seed": sown(nseed("primrose", n=3, R=8, kidney=0.2)),
    "seedling": nseedling("chilli-pepper", 18, 0.16, 9),
    "young": chilli_plant("young"), "flower": chilli_plant("flower"), "crop": chilli_plant("crop"),
}


def husk(a, x, y, L, col, fruit=None, vein="plum", split=False, skeleton=False):
    """A papery husk (the swollen calyx) hanging from x,y: five-angled, a
    sunken top where the stalk goes in, a pointed tip. tomatillo, Chinese lanterns.
    skeleton: the winter lantern, only a net of veins round the red berry."""
    W = L * 0.78
    hw = lambda u: W / 2 * math.sin(math.pi * min(1, u ** 0.8)) ** 0.75
    us = [i / 24 for i in range(25)]
    out = [(x + hw(u), y + L * u) for u in us] + [(x - hw(u), y + L * u) for u in us[::-1]]
    if skeleton:
        a.oval(x, y + L * 0.45, L * 0.22, L * 0.22, 0, fruit or "berry", 0.8)
        a.shape(path(out), None, 0.7, la=0.85, col="bark")
        for o in (-0.7, -0.35, 0, 0.35, 0.7):
            a.line(opath([(x + o * hw(u), y + L * u) for u in us[1:-1]]), 0.55, 0.75, "bark")
        for u in (0.25, 0.42, 0.6, 0.78):
            a.line(f"M{f(x - hw(u))},{f(y + L * u)} Q{f(x)},{f(y + L * u + 1)} {f(x + hw(u))},{f(y + L * u)}", 0.4, 0.6, "bark")
        a.line(f"M{f(x)},{f(y - 2.5)} L{f(x)},{f(y)}", 0.8, 0.85)
        return
    a.line(f"M{f(x)},{f(y - 3)} L{f(x)},{f(y + 0.6)}", 0.9, 0.85)
    a.shape(path(out), col, 0.9)
    a.shape(path(out[:25] + [(x + 0.1 * hw(u), y + L * u) for u in us[::-1]]), "shade", 0, fa=0.12)
    if fruit and split:   # the fruit filling the husk and splitting it open
        a.oval(x + W * 0.05, y + L * 0.62, W * 0.36, W * 0.36, 0, fruit, 0.8)
    for o in (-0.62, 0, 0.62):   # the ridges, with fine veins between
        a.line(opath([(x + o * hw(u), y + L * u) for u in (0.04, 0.3, 0.55, 0.8, 0.98)]), 0.55, 0.6)
    for o in (-0.32, 0.32):
        a.line(opath([(x + o * hw(u), y + L * u) for u in (0.1, 0.4, 0.7, 0.92)]), 0.4, 0.5, vein)


def tomatillo_plant(stage):
    """Sprawling, wider than tall: branches leaning out; flowers singly at
    the joints; papery husks hanging like small lanterns."""
    def draw():
        a = Art(); soil(a, 88)
        lc = pal("tomatillo", "leaf", "leaf"); fc = pal("tomatillo", "flower", "sun"); frc = pal("tomatillo", "fruit", "unripe")
        k = 0.7 if stage == "young" else 1.0
        brs = []
        for sd, h, sp in ((-1, 30, 36), (1, 34, 34), (-1, 18, 22), (1, 44, 12)):
            e = (50 + sd * sp * k, 88 - h * k)
            brs.append((a.ribbon((50, 88), (50 + sd * sp * 0.35 * k, 88 - h * 0.75 * k), e, 2.6, 1.4, "leaf", lw=0.75), sd))
        with a.on(LEAF):
            for j, (b, sd) in enumerate(brs):
                for i, u in enumerate((0.35, 0.62, 0.9)):
                    x, y = b.pt(u); s2 = sd if i % 2 else -sd
                    oleaf(a, "tomatillo", x, y, -90 + s2 * 50 + sd * 20, 15 * k * (1.1 - 0.25 * u), lc, stalk=2.5)
        with a.on(BLOOM):
            for j, (b, sd) in enumerate(brs):
                for i, u in enumerate((0.5, 0.78)):
                    if stage == "young" or (j == 3 and i == 0):
                        continue
                    x, y = b.pt(u)
                    if stage == "flower":
                        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 2)},{f(y + 1)} {f(x + sd * 3)},{f(y + 4)}", 0.6, 0.85)
                        at = wheel(a, x + sd * 3, y + 6, 4.4, 5, fc, join=0.84, pp=1.0, rnd=0.7, k=0.8, lines=False)
                        for g in range(5):
                            p = at(-90 + 72 * g, 0.42); a.dot(p[0], p[1], 0.5, "dark")
                    else:
                        husk(a, x + sd * 1.5, y + 3, 12 - 1.5 * i, "pale", fruit=frc, split=(i == 0 and j < 2))
        return a
    return draw


STAGE["tomatillo"] = {
    "seed": sown(nseed("seed", n=3, R=6.5)),
    "seedling": nseedling("tomatillo", 9, 0.55, 9),
    "young": tomatillo_plant("young"), "flower": tomatillo_plant("flower"), "crop": tomatillo_plant("crop"),
}


def lantern_plant(stage):
    """Chinese lanterns: a patch of upright unbranched stems from creeping
    underground stems. Small cream flowers hang singly under the leaves;
    in autumn bright orange lanterns hang in a row up the stem."""
    def draw():
        a = Art(); soil(a, 86)
        lc = pal("chinese-lanterns", "leaf", "leaf"); fc = pal("chinese-lanterns", "flower", "white"); frc = pal("chinese-lanterns", "fruit", "carrot")
        dead = stage == "dormant"
        lcol = {"crop": "pear"}.get(stage, lc)
        with a.on(STEM):   # the creeping underground stem joining the shoots
            a.line("M20,92 Q34,89 50,91 T82,92", 1.3, 0.8, "soil")
        k = 0.66 if stage == "young" else 1.0
        stems = [(26, 52), (50, 70), (74, 58)]
        for sx, h in stems:
            h *= k; top = (sx + 2, 86 - h)
            q = a.ribbon((sx, 91), (sx - 1, 86 - h * 0.5), top, 2.2, 1.4, "bark" if dead else "leaf", lw=0.75)
            n = max(3, int(h / 11))
            for i in range(n):
                u = 0.2 + 0.75 * i / max(1, n - 1); x, y = q.pt(u); sd = -1 if i % 2 else 1
                if dead:
                    if u > 0.45:
                        a.line(f"M{f(x)},{f(y)} L{f(x + sd * 3)},{f(y - 1.5)}", 0.7, 0.85, "bark")
                        husk(a, x + sd * 3, y + 1.5, 11, None, fruit="berry", skeleton=True)
                    continue
                with a.on(LEAF):
                    if not (stage == "crop" and i % 3 == 1):
                        oleaf(a, "chinese-lanterns", x, y, -90 + sd * 55, 14 * (1 - 0.3 * u), lcol, stalk=2)
                with a.on(BLOOM):
                    if stage == "flower" and 0 < i < n - 1:   # hanging beneath the leaf on a curved stalk
                        e = (x - sd * 3, y + 5)
                        a.line(f"M{f(x)},{f(y)} Q{f(x - sd * 3.5)},{f(y)} {P(e)}", 0.6, 0.85)
                        nodding(a, *e, 90 + sd * 8, 5.5, fc, n=3, wide=0.6)
                    if stage == "crop" and u > 0.35:
                        a.line(f"M{f(x)},{f(y)} Q{f(x - sd * 3)},{f(y - 1)} {f(x - sd * 3.5)},{f(y + 1.5)}", 0.7, 0.85)
                        husk(a, x - sd * 3.5, y + 3.5, 11, frc, vein="rust")
        return a
    return draw


STAGE["chinese-lanterns"] = {
    "seed": sown(nseed("veg_cream", n=3, R=6)),
    "seedling": nseedling("chinese-lanterns", 9, 0.55, 9),
    "young": lantern_plant("young"), "flower": lantern_plant("flower"), "crop": lantern_plant("crop"), "dormant": lantern_plant("dormant"),
}


# ================================================================ THE PEA FAMILY
def peaflower(a, x, y, face, s, std, wing=None, keel=None, calyx="leaf", blotch=None, lines=None, frill=False,
              coil=False, droop=0.0, slim=1.0, back=None):
    """One pea flower from the side, its stalk joining at x,y, its mouth
    facing right (face=1) or left (-1). droop turns the whole flower down
    (in degrees). The five petals: the STANDARD standing up at the back,
    two WINGS held forward, and the KEEL, a boat between them.
    blotch: a dark patch on the wings (broad bean). lines: fine lines on
    the standard. frill: a wavy standard (sweet pea). coil: the keel coiled
    (French bean). slim narrows the flower (vetch). back: the colour of the
    back of the standard if not the same (bird's-foot trefoil's red streaks)."""
    wing = wing or std; keel = keel or wing
    g0 = (0 if face > 0 else 180) + face * droop
    t = T(x, y, g0)
    loc = lambda px, py: t(px, py * face)      # px forward, py DOWN when facing right; mirrored when facing left
    # calyx: a short green cup with teeth
    cal = [loc(0, -1.6 * s), loc(4.6 * s, -2.4 * s * slim), loc(5.4 * s, -1.6 * s), loc(4.8 * s, 0), loc(5.6 * s, 1.4 * s),
           loc(4.4 * s, 2.0 * s * slim), loc(0, 1.4 * s)]
    # standard: a broad rounded petal rising from the top of the calyx, leaning back
    sc = loc(2.6 * s, -6.6 * s * slim)
    R1, R2 = 4.6 * s * slim, 7.4 * s
    wav = (lambda h: 1 + 0.05 * math.cos(9 * h)) if frill else (lambda h: 1 - 0.07 * math.exp(-((h - math.pi / 2) / 0.3) ** 2))
    stdpts = [T(*sc, g0 - face * 14)(R1 * wav(h) * math.cos(h), R2 * wav(h) * math.sin(h) * face) for h in [2 * math.pi * i / 48 for i in range(48)]]
    a.shape(path(stdpts), back or std, 0.8)
    if back and back != std:   # the front of the standard, the other colour, seen inside the streaked back
        a.shape(path([lerp(sc, p, 0.72) for p in stdpts]), std, 0, fa=1)
    base = loc(4.6 * s, -1.6 * s)
    for o in ((-0.5, 0, 0.5) if not lines else (-0.6, -0.3, 0, 0.3, 0.6)):
        e = T(*sc, g0 - face * 14 - 90 * face + o * 50)(R2 * 0.85)
        a.line(f"M{P(base)} Q{P(lerp(base, e, 0.5))} {P(e)}", 0.5 if lines else 0.4, 0.75 if lines else 0.3, lines or "line")
    a.shape(path(cal), calyx, 0.7)
    # keel: a boat curving up at its tip, or coiled
    if coil:
        pts = []
        for j in range(22):
            th = j * 0.5; r = 4.4 * s * (1 - j / 30)
            pts.append(loc(9.2 * s + r * math.sin(th) * 0.8, 1.0 * s - r * (1 - math.cos(th)) * 0.6))
        a.line(opath([loc(4.6 * s, 0.6 * s)] + pts), 1.6 * s, 0.85)
        a.line(opath([loc(4.6 * s, 0.6 * s)] + pts), 0.9 * s, 1.0, keel)
    else:
        kp = [loc(4.4 * s, -0.4 * s), loc(10 * s, 0.6 * s), loc(14.4 * s * (0.9 + 0.1 * slim), -2.0 * s), loc(11 * s, 3.6 * s * slim), loc(5 * s, 2.4 * s)]
        a.shape(f"M{P(kp[0])} Q{P(kp[1])} {P(kp[2])} Q{P(kp[3])} {P(kp[4])} Z", keel, 0.7)
    # wings: held forward over the keel
    wp = [loc(4.0 * s, -1.8 * s), loc(9.6 * s, -6.0 * s * slim), loc(14.0 * s * (0.9 + 0.1 * slim), -1.8 * s), loc(10 * s, 2.4 * s), loc(4.6 * s, 0.8 * s)]
    a.shape(f"M{P(wp[0])} Q{P(wp[1])} {P(wp[2])} Q{P(wp[3])} {P(wp[4])} Z", wing, 0.75)
    a.line(f"M{P(loc(5 * s, -0.6 * s))} Q{P(loc(8.4 * s, -1.6 * s))} {P(loc(11 * s, -1.2 * s))}", 0.4, 0.3)
    if blotch:
        c = loc(8.4 * s, -1.0 * s); a.oval(c[0], c[1], 2.4 * s, 1.6 * s, g0 - face * 10, blotch, 0)
    return sc


def mini_pea(a, x, y, face, s, std, wing=None, droop=0.0, mark=None):
    """A pea flower too small for detail: standard and wing only."""
    wing = wing or std; g0 = (0 if face > 0 else 180) + face * droop
    t = T(x, y, g0); loc = lambda px, py: t(px, py * face)
    sc = loc(2.4 * s, -4.4 * s)
    a.oval(sc[0], sc[1], 3.4 * s, 4.0 * s, g0, std, 0.6)
    if mark:   # lupin: a white patch on the standard
        a.oval(sc[0] - face * 0.3 * s, sc[1] - 0.6 * s, 1.6 * s, 2.0 * s, g0, mark, 0)
    w = [loc(1 * s, -1 * s), loc(5 * s, -2.8 * s), loc(7.4 * s, -0.4 * s), loc(4.6 * s, 1.4 * s)]
    a.shape(f"M{P(w[0])} Q{P(w[1])} {P(w[2])} Q{P(w[3])} {P(w[0])} Z", wing, 0.6)
    a.oval(*loc(0.6 * s, 0), 1.2 * s, 0.9 * s, g0, "leaf", 0.4)


# ------------------------------------------------------------ compound leaves
def leaflet(a, x, y, ang, L, W, fill, pr, mg=None, lop=0.0, notch=0.0, mark=None, veins=3, lw=0.95):
    pts = blade(a, x, y, ang, L, W, fill, pr, mg, veins=veins, lw=lw, lop=lop, notch=notch, mid=0.55)
    if mark == "chevron":   # clover: a pale V across the leaflet
        t = T(x, y, ang)
        a.line(f"M{P(t(L * 0.62, W * 0.3))} L{P(t(L * 0.42, 0))} L{P(t(L * 0.62, -W * 0.3))}", max(0.7, W * 0.07), 0.5, "white")
    elif mark == "crescent":   # red clover: a pale crescent
        t = T(x, y, ang)
        a.line(f"M{P(t(L * 0.6, W * 0.3))} Q{P(t(L * 0.38, 0))} {P(t(L * 0.6, -W * 0.3))}", max(0.7, W * 0.08), 0.5, "white")
    return pts


def stip(a, x, y, ang, kind, size, fill):
    """The stipules: a pair of ears where the leaf stalk joins the stem."""
    for sg in (1, -1):
        g = ang + sg * 90
        if kind == "pea":   # huge leafy half-hearts clasping the stem, toothed along the lower edge
            t = T(x, y, ang)
            pts = [t(-size * 0.5, 0), t(-size * 0.55, sg * size * 0.5), t(-size * 0.1, sg * size * 0.9), t(size * 0.45, sg * size * 0.75),
                   t(size * 0.8, sg * size * 0.2), t(size * 0.3, sg * size * 0.08), t(0, 0)]
            sm = []
            for i in range(len(pts) - 1):
                for k in range(5):
                    p = lerp(pts[i], pts[i + 1], k / 5)
                    if i <= 1 and k % 2:   # teeth on the lower edge
                        p = lerp(p, t(-size * 0.8, sg * size * 0.3), -0.06)
                    sm.append(p)
            a.shape(path(sm), fill, 0.85)
            a.line(f"M{P(t(0, 0))} Q{P(t(size * 0.1, sg * size * 0.4))} {P(t(-size * 0.1, sg * size * 0.7))}", 0.4, 0.35)
        elif kind == "arrowhead":   # meadow vetchling: big arrowheads, nearly as big as the leaflets
            t = T(x, y, ang - sg * 20)
            a.shape(path([t(-size * 0.35, sg * size * 0.15), t(size * 0.1, sg * size * 0.3), t(size, sg * size * 0.12), t(size * 0.2, 0)]), fill, 0.75)
        elif kind in ("half", "spot"):   # small half-arrows; broad bean's with a dark nectar spot
            t = T(x, y, g)
            a.shape(path([t(0, 0), t(size * 0.5, -size * 0.35 * sg), t(size, 0), t(size * 0.4, size * 0.25 * sg)]), fill, 0.6)
            if kind == "spot":
                p = t(size * 0.45, 0); a.dot(p[0], p[1], max(0.5, size * 0.12), "dark")
        elif kind == "narrow":
            blade(a, x, y, g - sg * 30, size, size * 0.24, fill, prof(0.3, "round", "point"), veins=0, lw=0.6, petal=True)
        elif kind == "bristle":   # red clover: pale triangles with a long bristle tip
            t = T(x, y, ang)
            a.shape(path([t(0, 0), t(size * 0.6, sg * size * 0.25), t(size * 1.5, sg * size * 0.12), t(size * 0.6, sg * size * 0.05)]), "pale", 0.6)
            a.line(f"M{P(t(size * 0.2, sg * size * 0.12))} L{P(t(size * 0.9, sg * size * 0.12))}", 0.35, 0.6, "beet")
        elif kind == "papery":
            a.shape(path([T(x, y, ang)(-size * 0.6, sg * 1.2), T(x, y, ang)(size, sg * 1.6), T(x, y, ang)(size * 0.9, 0)]), "pale", 0.5)


def tendril_branched(a, x, y, ang, L, arms=3, lw=0.75):
    for k in range(arms):
        g = ang + (k - (arms - 1) / 2) * 26
        e = T(x, y, g)(L * (0.85 + 0.15 * (k == (arms - 1) // 2)))
        c1 = 1 if k % 2 else -1
        a.line(f"M{f(x)},{f(y)} Q{P(T(x, y, g - c1 * 8)(L * 0.6))} {P(e)} q{f(c1 * L * 0.12)},{f(-L * 0.12)} {f(c1 * L * 0.02)},{f(-L * 0.22)} q{f(-c1 * L * 0.1)},0 {f(-c1 * L * 0.08)},{f(L * 0.1)}", lw, 0.8)


def leaf_pinnate_v(a, sp):
    """A pinnate leaf of the pea family: pairs of leaflets along a stalk,
    ending in a tendril, a small point or nothing; stipules at the foot."""
    fill = sp["fill"]; t = T(*BASE, ANG); n = sp["pairs"]; LT = sp.get("LT", 82)
    q = Quad(BASE, t(LT * 0.5, -3 * sp.get("bend", 1)), t(LT))
    if sp.get("wing"):   # sweet pea: the stalk winged
        a.ribbon(q.p0, q.c, q.p1, 4.2, 2.6, fill, lw=0.8)
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.0, fill, lw=0.8)
    if sp.get("stip") == "pea":   # pea: the stipules wrapped round the stem (in the close-up, a piece of it)
        x, y = q.pt(0.1)
        if sp.get("stem", True):
            a.ribbon((x - 4, 99), (x - 2, y), (x + 4, y - 30), 2.6, 2.0, fill, lw=0.8)
        stip(a, x, y, q.ang(0.1), "pea", sp.get("stipL", 10), fill)
    elif sp.get("stip"):
        stip(a, *q.pt(0.04), q.ang(0.04), sp["stip"], sp.get("stipL", 10), fill)
    pr = prof(*sp.get("pr", (0.5, "round", "round")))
    u0, u1 = sp.get("span", (0.3, 0.86))
    for i in range(n):
        u = u0 + (u1 - u0) * i / max(1, n - 1) if n > 1 else u1
        x, y = q.pt(u); g = q.ang(u); L = sp["ll"] * (1 + sp.get("grow", 0) * i / max(1, n - 1))
        for sg in (1, -1):
            leaflet(a, x, y, g + sg * sp.get("spread", 55), L, L * sp["lW"], fill, pr, veins=sp.get("veins", 3), lw=0.9 if L > 12 else 0.75)
    ex, ey = q.pt(1)
    end = sp.get("end", "point")
    if end == "tendril":
        tendril_branched(a, ex, ey, q.ang(1), sp.get("tl", 16), sp.get("arms", 3))
    elif end == "point":   # broad bean: the stalk ends in a tiny soft point
        a.line(f"M{f(ex)},{f(ey)} L{P(T(ex, ey, q.ang(1))(3))}", 1.0, 0.85)
    return a


def leaf_three(a, sp):
    """A leaf of three leaflets (or five, bird's-foot trefoil). mid: how long
    the end leaflet's own stalk is (French bean, alfalfa: longer)."""
    fill = sp["fill"]; t = T(*BASE, ANG); S = sp.get("stalk", 38)
    A = t(S)
    a.ribbon(BASE, t(S * 0.5, 1.5), A, 2.2, 1.6, fill, lw=0.85)
    if sp.get("stip"):
        stip(a, *BASE, ANG, sp["stip"], sp.get("stipL", 6), fill)
    pr = prof(*sp.get("pr", (0.6, "wedge", "round")))
    mg = margin_of(sp.get("mg")); L = sp["ll"]; W = L * sp["lW"]
    if sp.get("basal"):   # bird's-foot trefoil: a pair of leaflets right at the foot of the stalk
        for sg in (1, -1):
            leaflet(a, *t(4), ANG + sg * 64, L * 0.7, L * 0.7 * sp["lW"], fill, pr, lop=0.15 * sg)
    mid = sp.get("mid", 0)
    E = t(S + mid)
    if mid:
        a.line(f"M{P(A)} L{P(E)}", 1.0, 0.85)
    if sp.get("stipels"):   # French bean: tiny stipels at the foot of each leaflet stalk
        for p in (A, E):
            for sg in (1, -1):
                blade(a, *p, ANG + sg * 40, 2.6, 0.8, fill, prof(0.3), veins=0, lw=0.4, petal=True)
    for sg in (1, -1):
        g = ANG + sg * sp.get("spread", 70)
        p0 = T(*A, g)(sp.get("sstalk", 0))
        if sp.get("sstalk"):
            a.line(f"M{P(A)} L{P(p0)}", 0.9, 0.85)
        leaflet(a, *p0, g, L * sp.get("sidek", 0.92), W * sp.get("sidek", 0.92), fill, pr, mg, lop=-sp.get("lop", 0) * sg,
                notch=sp.get("notch", 0), mark=sp.get("mark"), veins=sp.get("veins", 4))
    leaflet(a, *E, ANG, L, W, fill, pr, mg, notch=sp.get("notch", 0), mark=sp.get("mark"), veins=sp.get("veins", 4))
    return a


def leaf_wheel(a, sp):
    """Lupin: narrow leaflets radiating from the top of a long stalk like spokes."""
    fill = sp["fill"]; t = T(*BASE, ANG); A = t(40)
    a.ribbon(BASE, t(20, 2), A, 2.4, 1.8, fill, lw=0.85)
    n = sp.get("n", 11); spread = sp.get("spread", 150)
    for k in sorted(range(n), key=lambda k: -abs(k - (n - 1) / 2)):
        off = -spread + 2 * spread * k / (n - 1); L = sp.get("ll", 36) * (1 - 0.32 * (abs(off) / 150) ** 1.6)
        leaflet(a, *A, ANG + off, L, L * sp.get("lW", 0.2), fill, prof(0.55, "wedge", "point", 1.4, 0.9), veins=0, lw=0.85)
    a.oval(A[0], A[1], 1.8, 1.8, 0, fill, 0.8)
    return a


LEAF_DRAW.update({"veg_pinnate": leaf_pinnate_v, "veg_three": leaf_three, "veg_wheel": leaf_wheel})
LEAFX.update({
    # broad bean is one of the ten: its entry is complete
    "broad-bean": dict(kind="veg_pinnate", fill="sage", pairs=2, ll=30, lW=0.52, pr=(0.55, "wedge", "round", 0.9, 1.6),
                       span=(0.36, 0.86), end="point", stip="spot", stipL=7, LT=74, spread=42, veins=4, grow=0.12),
    "pea": dict(kind="veg_pinnate", pairs=2, ll=22, lW=0.62, pr=(0.5, "round", "round", 0.6, 1.8),
                end="tendril", tl=20, arms=5, stip="pea", stipL=18, LT=70, spread=50, span=(0.45, 0.72)),
    "sweet-pea": dict(kind="veg_pinnate", pairs=1, ll=34, lW=0.42, pr=(0.48, "round", "point", 0.7, 1.0), span=(0.55, 0.55),
                      end="tendril", tl=26, arms=3, stip="narrow", stipL=9, LT=70, wing=True, spread=34, veins=4),
    "tufted-vetch": dict(kind="veg_pinnate", pairs=10, ll=12, lW=0.26, pr=(0.5, "round", "round", 0.5, 2.6), span=(0.1, 0.84),
                         end="tendril", tl=14, arms=3, stip="narrow", stipL=5, LT=80, spread=62, veins=0),
    "meadow-vetchling": dict(kind="veg_pinnate", pairs=1, ll=40, lW=0.2, pr=(0.45, "wedge", "point", 0.9, 0.9), span=(0.42, 0.42),
                             end="tendril", tl=18, arms=1, stip="arrowhead", stipL=22, LT=62, spread=30, veins=0),
    "french-bean": dict(kind="veg_three", ll=34, lW=0.72, pr=(0.36, "round", "acum", 0.5, 1.1), stalk=34, mid=10, sstalk=3,
                        lop=0.18, spread=78, stipels=True, veins=5),
    "alfalfa": dict(kind="veg_three", ll=30, lW=0.38, pr=(0.72, "taper", "blunt", 1.4, 3.0), stalk=40, mid=6, mg=("teeth", 7, 0.2, "saw", 0, 0.62),
                    notch=0.03, spread=48, stip="narrow", stipL=8, veins=4),
    "clover": dict(kind="veg_three", ll=28, lW=0.82, pr=(0.62, "wedge", "round", 0.75, 2.4), stalk=46, mg=("teeth", 18, 0.05, "saw"),
                   mark="chevron", spread=118, stip="papery", stipL=8, veins=6),
    "red-clover": dict(kind="veg_three", ll=34, lW=0.5, pr=(0.48, "round", "round", 0.7, 1.6), stalk=40, mark="crescent", spread=72,
                       stip="bristle", stipL=8, veins=6),
    "common-bird-s-foot-trefoil": dict(kind="veg_three", ll=32, lW=0.5, pr=(0.6, "wedge", "point", 0.8, 1.6), stalk=30, basal=True,
                                       spread=40, veins=0),
    "lupin": dict(kind="veg_wheel", n=11, ll=40, lW=0.17, spread=150),
})


# ------------------------------------------------------------ pea-family flowers
def head_ball(a, cx, cy, R, fc, old="bark", k=0.95, droop_rows=2, rows=7, tip="beet"):
    """A clover head: rows of tiny pea flowers on a ball; the lowest rows
    gone over, brown and bent down."""
    for r in range(rows):
        y = cy - R * 0.8 + r * R * 1.6 / (rows - 1); w = R * 0.95 * math.sqrt(max(0.04, 1 - ((y - cy) / (R * 1.0)) ** 2))
        n = max(3, int(w / 2.0)); gone = r >= rows - droop_rows
        for j in range(n):
            x = cx - w + 2 * w * (j + 0.5 + 0.25 * (r % 2)) / (n + 0.25)
            g = (80 + (x - cx) * 3) if gone else (-90 + (x - cx) / R * 75)
            blade(a, x, y, g, R * (0.4 if not gone else 0.36), R * 0.16, old if gone else fc, prof(0.6, "wedge", "round"), veins=0, lw=0.5, petal=True)
            if not gone and tip:
                e = T(x, y, g)(R * 0.36); a.dot(e[0], e[1], max(0.3, R * 0.025), tip)


def fl_peas(a, sp):
    """Every flower of the pea family, by sp["pk"]."""
    pk = sp["pk"]; fc = sp["fc"]; cen = sp.get("cen")
    if pk == "broad-bean":   # a short cluster tight in the leaf joint, all facing one way
        a.ribbon((50, 99), (51, 60), (50, 4), 4.4, 3.4, "sage", lw=0.9)
        a.ribbon((51, 60), (64, 52), (90, 40), 2.4, 1.8, "sage", lw=0.8)
        for (dx, dy, s, dr) in ((-2, 58, 2.3, 30), (-2, 44, 2.2, 10), (-2, 72, 2.0, 48)):
            a.line(f"M50,{dy + 4} L{f(50 + dx)},{dy}", 1.0, 0.85)
            peaflower(a, 50 + dx, dy, -1, s, fc, fc, "white", "leaf", blotch="dark", lines="plum", droop=dr)
        return a
    if pk == "pea":
        q = Quad((42, 99), (40, 70), (46, 40))
        a.ribbon(q.p0, q.c, q.p1, 2.4, 2.0, "sage", lw=0.8)
        a.line("M46,40 Q50,30 58,28", 1.0, 0.85); a.line("M46,40 Q40,34 32,36", 1.0, 0.85)
        peaflower(a, 58, 28, 1, 2.4, fc, fc, fc, "sage", droop=18)
        peaflower(a, 32, 36, -1, 1.9, fc, fc, fc, "sage", droop=30)
        return a
    if pk == "french-bean":   # a short loose cluster, the keel coiled
        a.ribbon((40, 99), (42, 70), (48, 50), 2.2, 1.8, "leaf", lw=0.8)
        for (x, y, face, s, dr) in ((60, 34, 1, 2.2, 10), (30, 40, -1, 1.9, 20), (52, 64, 1, 1.6, 40)):
            a.line(f"M48,50 Q{f((48 + x) / 2)},{f(y + 6)} {f(x)},{f(y)}", 0.8, 0.85)
            peaflower(a, x, y, face, s, fc, fc, fc, "leaf", coil=True, droop=dr)
        a.line("M48,50 L48,40", 0.7, 0.85); a.oval(48, 38, 1.6, 2.6, 0, "pale", 0.6)
        return a
    if pk == "sweet-pea":   # sprays on a long stiff upright stalk, big frilly standards
        a.ribbon((44, 99), (46, 60), (48, 26), 2.0, 1.6, "leaf", lw=0.8)
        for (x, y, face, s, dr) in ((60, 22, 1, 2.4, 6), (30, 40, -1, 2.2, 14), (60, 56, 1, 2.0, 26)):
            a.line(f"M48,{f(y + 10)} Q{f((48 + x) / 2)},{f(y + 6)} {f(x)},{f(y)}", 0.8, 0.85)
            peaflower(a, x, y, face, s, fc, fc, cen or fc, "leaf", frill=True, droop=dr)
        bud(a, 48, 26, -88, 6, fc)
        return a
    if pk == "tufted-vetch":   # a dense one-sided spike, the flowers hanging down from one side
        a.ribbon((34, 99), (38, 70), (44, 54), 1.8, 1.5, "leaf", lw=0.8)
        q = Quad((44, 54), (62, 30), (86, 22))
        a.line(q.d(), 1.2, 0.85)
        for j in range(13):
            u = 0.1 + 0.86 * j / 12; x, y = q.pt(u)
            mini_pea(a, x, y + 1.5, -1 if j % 2 else 1, 1.5 * (1 - 0.3 * u), fc, fc, droop=72)
        return a
    if pk == "meadow-vetchling":   # a loose head at the end of a stalk longer than the leaf
        a.ribbon((44, 99), (44, 70), (48, 44), 2.0, 1.6, "leaf", lw=0.8)
        for (x, y, face, s, dr) in ((62, 28, 1, 1.5, 10), (34, 30, -1, 1.5, 10), (66, 44, 1, 1.4, 40), (30, 46, -1, 1.4, 40), (50, 22, 1, 1.3, -20)):
            a.line(f"M48,44 Q{f((48 + x) / 2)},{f(y + 4)} {f(x)},{f(y)}", 0.7, 0.85)
            peaflower(a, x, y, face, s, fc, fc, fc, "leaf", lines="rust", droop=dr)
        return a
    if pk == "alfalfa":   # a short dense oblong head, held up on a stalk
        a.ribbon((46, 99), (48, 76), (50, 62), 2.0, 1.6, "leaf", lw=0.8)
        a.line("M50,62 L50,24", 1.2, 0.85)
        for r in range(8):
            y = 60 - r * 5.0
            for j, face in enumerate((-1, 1)):
                mini_pea(a, 50 + face * 1.2, y, face, 1.6 - 0.05 * r, fc, fc, droop=-15 + 20 * (r % 2))
            if r % 2:
                mini_pea(a, 50, y + 2, 1, 1.2, fc, fc, droop=-60)
        return a
    if pk == "lupin":   # a tall dense spike, rings of flowers opening from the bottom, buds at the top
        a.ribbon((50, 99), (50, 60), (50, 6), 3.2, 1.6, "leaf", lw=0.8)
        for r in range(9):
            y = 90 - r * 8.4; s = 1.2 - 0.06 * r
            if r >= 7:
                for face in (-1, 1):
                    a.oval(50 + face * 2.4, y, 1.8, 2.6, face * 20, fc if r == 7 else "pale", 0.6)
                continue
            for face in (-1, 1):
                mini_pea(a, 50 + face * 1.4, y, face, s * 1.8, fc, fc, droop=8, mark=cen or "white")
            mini_pea(a, 50, y + 2.5, 1, s * 1.3, fc, fc, droop=70, mark=cen or "white")
        return a
    if pk == "birds-foot":   # a ring of flowers at the top of a long stalk, a leafy bract beneath
        a.ribbon((50, 99), (52, 78), (50, 58), 2.0, 1.6, "leaf", lw=0.8)
        for g in (-150, -90, -30):
            leaflet(a, 50, 58, g + 180, 8, 4, "leaf", prof(0.6, "wedge", "point"), veins=0, lw=0.6)
        for (g, face, s, col) in ((-170, -1, 1.7, fc), (-10, 1, 1.7, fc), (-130, -1, 1.6, fc), (-50, 1, 1.6, fc), (-92, 1, 1.4, "x")):
            e = T(50, 58, g)(12); a.line(f"M50,58 L{P(e)}", 0.8, 0.85)
            if col == "x":   # a bud, red
                blade(a, *e, -80, 9, 4.6, cen or "carrot", prof(0.5), veins=0, lw=0.7, petal=True)
                continue
            peaflower(a, *e, face, s, col, fc, fc, "leaf", droop=-20, back=cen or "carrot" if g in (-130, -10) else None)
        return a
    if pk == "clover":   # a round white head on a long leafless stalk; the old flowers brown and bent down
        a.ribbon((50, 99), (51, 80), (50, 60), 2.0, 1.8, "leaf", lw=0.8)
        a.oval(50, 42, 17, 16, 0, "pale", 0.8)
        head_ball(a, 50, 42, 21, fc, "bark", tip=cen or "pink")
        return a
    # red clover: the head sits straight on a pair of leaves, with no stalk of its own
    a.ribbon((50, 99), (51, 80), (50, 64), 2.6, 2.2, "leaf", lw=0.8)
    for sg in (-1, 1):
        own(a, "red-clover", 50, 64, -90 + sg * 70, 38, detail=True)
    a.oval(50, 44, 16, 16, 0, fc, 0.8)
    head_ball(a, 50, 44, 21, fc, "bark", droop_rows=0, tip="beet")
    return a


def bud(a, x, y, ang, L, fill):
    blade(a, x, y, ang, L, L * 0.5, fill, prof(0.45), veins=0, lw=0.7, petal=True)
    for sg in (-1, 1):
        blade(a, x, y, ang + sg * 18, L * 0.55, L * 0.18, "leaf", prof(0.3), veins=0, lw=0.5, petal=True)


BLOOM_DRAW["veg_peas"] = fl_peas
BLOOMX.update({
    "broad-bean": dict(kind="veg_peas", pk="broad-bean", fc="white", cen="dark"),   # one of the ten: colours written in
    "pea": dict(kind="veg_peas", pk="pea"), "french-bean": dict(kind="veg_peas", pk="french-bean"),
    "sweet-pea": dict(kind="veg_peas", pk="sweet-pea"), "tufted-vetch": dict(kind="veg_peas", pk="tufted-vetch"),
    "meadow-vetchling": dict(kind="veg_peas", pk="meadow-vetchling"), "alfalfa": dict(kind="veg_peas", pk="alfalfa"),
    "lupin": dict(kind="veg_peas", pk="lupin"), "common-bird-s-foot-trefoil": dict(kind="veg_peas", pk="birds-foot"),
    "clover": dict(kind="veg_peas", pk="clover"), "red-clover": dict(kind="veg_peas", pk="red-clover"),
})


# ------------------------------------------------------------ pea-family life stages
def pulse(fill, n=1, R=11, kidney=0.0, mottle=None, scar=None, heart=0.0, flat=0.9, wrinkled=False, spots=None):
    """Seeds of the pea family: round, kidney- or heart-shaped. scar: the
    colour of the scar (hilum); mottle: speckles."""
    def draw(a, x, y):
        pos = spots or ([(0, 0, 1.0)] if n == 1 else [(-9, 3, 0.9), (9, -2, 1.0), (1, 11, 0.8), (-12, -9, 0.7), (12, 10, 0.75)][:n])
        for i, (dx, dy, k) in enumerate(pos):
            cx, cy, r = x + dx, y + dy, R * k
            col = fill[i % len(fill)] if isinstance(fill, (list, tuple)) else fill
            g = lambda h: (1 - kidney * math.exp(-((h + math.pi / 2) / 0.5) ** 2) - heart * math.exp(-((h + math.pi / 2) / 0.25) ** 2)
                           + (0.05 * math.sin(7 * h) if wrinkled and i % 2 else 0))
            a.polar(cx, cy, g, r, r * flat, dx * 2, col, 1.0 if R > 6 else 0.7)
            if mottle:
                for j in range(9):
                    rr = r * 0.7 * math.sqrt((j + 0.5) / 9); a.dot(cx + rr * math.cos(j * GOLD + i), cy + rr * flat * math.sin(j * GOLD + i), r * 0.07, mottle)
            if scar:
                a.oval(cx, cy - r * flat * (0.86 - kidney * 0.9), r * 0.3, r * 0.1, dx * 2, scar, 0.5)
            if wrinkled and i % 2:
                a.line(f"M{f(cx - r * 0.5)},{f(cy)} Q{f(cx)},{f(cy - r * 0.3)} {f(cx + r * 0.4)},{f(cy + r * 0.2)}", 0.5, 0.4)
    return draw


def under_seed(a, x, y, col, k=1.0):
    """The seed left under the soil when its seed leaves stay inside it (pea, broad bean)."""
    a.polar(x, y, lambda h: 1, 4.2 * k, 3.6 * k, 0, col, 0.8)
    a.roots(x, y + 3 * k, 3, 11, 50)


def hypogeal(slug, seedc, h=26, L=20, over=None):
    """A pea-family seedling whose seed leaves stay underground: a thin shoot,
    small scale leaves, then the first true leaves."""
    def draw():
        a = Art(); soil(a, 72)
        under_seed(a, 50, 77, seedc)
        q = a.ribbon((50, 74), (49, 72 - h * 0.5), (50.5, 72 - h), 1.8, 1.3, "pale" if slug != "broad-bean" else "leaf", lw=0.8)
        for u, sd in ((0.25, 1), (0.45, -1)):   # scale leaves
            x, y = q.pt(u); blade(a, x, y, -90 + sd * 40, 3, 1.6, "pale", prof(0.4), veins=0, lw=0.5, petal=True)
        x, y = q.pt(0.7); own(a, slug, x, y, -90 + 50, L * 0.75, **(over or {}))
        x, y = q.pt(1); own(a, slug, x, y, -90 - 20, L, **(over or {}))
        return a
    return draw


def epigeal(slug, cot=(9, 0.6), first="round", L=10, thick=False, coll="leaf"):
    """A seedling whose seed leaves come up: two seed leaves and the first leaf."""
    def draw():
        a = Art(); soil(a, 72); roots(a, 50, 72, 3, 11, 50)
        a.ribbon((50, 72), (49.5, 65), (50, 58), 2.4 if thick else 1.5, 2.0 if thick else 1.2, "pale", lw=0.8)
        for g in (-160, -20):
            blade(a, 50, 58, g, cot[0], cot[0] * cot[1], "pale" if thick else coll, prof(0.5, "round", "round", tp=2.2), veins=0 if not thick else 1, lw=0.9)
        if first == "round":   # one round, spade-shaped first leaf on a stalk
            a.line("M50,58 Q50.5,52 51,47", 0.8, 0.85)
            blade(a, 51, 47, -90, L, L * 0.86, "leaf", prof(0.55, "round", "round", 0.5, 1.6), veins=2, lw=0.9)
        elif first == "heart":   # French bean: a pair of opposite simple heart-shaped pointed leaves
            a.line("M50,58 L50,52", 1.0, 0.85)
            for sg in (-1, 1):
                blade(a, 50, 52, -90 + sg * 48, L, L * 0.8, "leaf", prof(0.32, "round", "acum", 0.4, 1.1), veins=3, lw=0.9)
        else:   # the kind's own leaf, small
            a.line("M50,58 L50,54", 0.9, 0.85)
            own(a, slug, 50, 54, -94, L)
        return a
    return draw


def pod(a, x, y, ang, L, W, col, bumps=4, beak=True, hairy=False, twist=False, lw=0.8):
    """A pea-family pod from x,y along ang. twist: split open and twisted
    (sweet pea, vetchling): two curled valves."""
    t = T(x, y, ang)
    if twist:
        for sg in (-1, 1):
            pts = [t(L * u, sg * W * 0.3 + W * 0.5 * math.sin(u * 5 + sg)) for u in [i / 16 for i in range(17)]]
            a.line(opath(pts), W * 0.45, 0.85)
            a.line(opath(pts), W * 0.3, 1.0, col)
        return
    hw = lambda u: W / 2 * (min(1, u / 0.12) ** 0.6) * (1 - max(0, (u - 0.85) / 0.15) ** 1.5) * (1 + (0.12 * abs(math.sin(math.pi * u * bumps)) if bumps else 0))
    us = [i / 30 for i in range(31)]
    top = [t(L * u, hw(u)) for u in us]; bot = [t(L * u, -hw(u)) for u in us]
    a.shape(path(top + bot[::-1]), col, lw)
    a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    a.line(opath([t(L * u, -hw(u) * 0.55) for u in us[2:-3]]), 0.4, 0.35)
    if beak:
        a.line(f"M{P(t(L * 0.98))} Q{P(t(L * 1.08, -W * 0.1))} {P(t(L * 1.12, -W * 0.35))}", 0.6, 0.85)
    if hairy:
        for u in us[3:-3:3]:
            for sg in (1, -1):
                p = t(L * u, sg * hw(u)); a.line(f"M{P(p)} L{P(T(*p, ang + sg * 75)(0.9))}", 0.35, 0.55)


def grass(a, by=88, col="sage", n=9, H=40, dead=False):
    """Grass for a scrambling plant to lean on."""
    for k in range(n):
        x = 12 + 76 * k / (n - 1) + (3 if k % 2 else -2); h = H * (0.6 + 0.4 * ((k * 5) % 7) / 6)
        lean = (k % 3 - 1) * 6
        a.ribbon((x, by), (x + lean * 0.3, by - h * 0.6), (x + lean, by - h), 1.6, 0.3, "straw" if dead else col, lw=0.55)


def climber_leg(slug, stage, support="net", n=6, L=20, H=78, flower=None, fruit=None, dryc="straw", over=None, top_leaf=True):
    """A pea-family climber or scrambler: a weak stem up a support, a leaf at
    each joint (the kind's own leaf, with its tendril and stipules), and at
    some joints flowers or pods. flower(a, x, y, side, i) and fruit(a, x, y,
    side, i, dry) draw what hangs there."""
    def draw():
        a = Art(); soil(a, 88)
        dry = stage == "seedhead"
        if support == "net":
            with a.on(STEM):
                for px in (22, 78):
                    a.ribbon((px, 89), (px, 50), (px, 8), 2.0, 1.8, "bark", lw=0.8)
                for yy in range(16, 88, 12):
                    a.line(f"M22,{yy} L78,{yy}", 0.45, 0.45)
                for xx in range(30, 78, 10):
                    a.line(f"M{xx},12 L{xx},88", 0.45, 0.45)
        elif support == "cane":
            with a.on(STEM):
                a.ribbon((50, 89), (50, 50), (50, 6), 2.0, 1.8, "bark", lw=0.8)
        elif support == "grass":
            with a.on(STEM):
                grass(a, 88, "sage", 11, H * 0.7, dead=stage == "dormant")
        if stage == "dormant":   # dead brown stems lying in the grass, nothing green
            for p0, c, p1 in (((30, 88), (40, 70), (62, 74)), ((52, 88), (60, 76), (78, 82)), ((44, 88), (34, 74), (22, 80))):
                a.line(f"M{P(p0)} Q{P(c)} {P(p1)}", 0.9, 0.8, "bark")
                for u in (0.4, 0.7):
                    q = Quad(p0, c, p1); x, y = q.pt(u); a.line(f"M{f(x)},{f(y)} l2,-3 M{f(x)},{f(y)} l-2,-2", 0.6, 0.7, "bark")
            return a
        h = H * (0.55 if stage == "young" else 1.0)
        nn = max(3, int(n * (0.6 if stage == "young" else 1)))
        pts = [(50 + (3 if i % 2 else -3) * (1 if support != "grass" else 2), 88 - h * i / nn) for i in range(nn + 1)]
        with a.on(STEM):
            a.line("M" + " L".join(P(p) for p in pts), 1.1, 0.85, "line" if not dry else "bark")
        fills = {pal(slug, "leaf", "leaf"): dryc} if dry else None
        for i, (x, y) in enumerate(pts[1:]):
            sd = -1 if i % 2 else 1
            with a.on(LEAF):
                if i < nn - 1 or top_leaf:
                    own(a, slug, x, y, -90 + sd * 52, L * (1 - 0.12 * i / nn), fill=dryc if dry else None, **(over or {}))
            with a.on(BLOOM):
                if stage == "flower" and flower and i >= 1:
                    flower(a, x, y, -sd, i)
                if stage in ("crop", "seedhead") and fruit and i >= 1:
                    fruit(a, x, y, -sd, i, dry)
        return a
    return draw


# --- pea
def _pea_fl(a, x, y, sd, i):
    if i % 2 == 0 or i > 4:
        return
    e = (x + sd * 6, y - 3); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 3)},{f(y - 4)} {P(e)}", 0.7, 0.85)
    peaflower(a, *e, sd, 0.62, pal("pea", "flower", "white"), calyx="sage", droop=8)
    if i == 2:
        e2 = (e[0] + sd * 3, e[1] + 4); a.line(f"M{P(e)} L{P(e2)}", 0.6, 0.85)
        peaflower(a, *e2, sd, 0.55, pal("pea", "flower", "white"), calyx="sage", droop=36)


def _pea_fr(a, x, y, sd, i, dry):
    if i % 2 == 1 and i < 6:
        e = (x + sd * 4, y + 1); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.7, 0.85)
        pod(a, *e, 90 - sd * 25, 14, 4.4, "straw" if dry else pal("pea", "fruit", "leaf"), bumps=5, beak=True)


STAGE["pea"] = {
    "seed": sown(pulse(["pear", "veg_cream"], n=2, R=10, wrinkled=True, scar="seed", spots=[(-8, 0, 1.0), (10, 1, 0.95)])),
    "seedling": hypogeal("pea", "pear", 26, 18, over=dict(stem=False)),
    "young": climber_leg("pea", "young", "net", L=22, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
    "flower": climber_leg("pea", "flower", "net", L=21, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
    "crop": climber_leg("pea", "crop", "net", L=21, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
    "seedhead": climber_leg("pea", "seedhead", "net", L=19, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
}


# --- sweet pea: sprays on long upright stalks held above the leaves
def _sp_fl(a, x, y, sd, i):
    if i % 2 == 0 and i >= 2:
        fc = pal("sweet-pea", "flower", "mauve"); cen = pal("sweet-pea", "centre", "pink")
        e = (x + sd * 10, y - 24); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 8)},{f(y - 10)} {P(e)}", 0.8, 0.85)
        peaflower(a, *e, sd, 0.85, fc, fc, cen, frill=True, droop=10)
        e2 = T(*e, 90 + sd * 20)(3); peaflower(a, *e2, -sd, 0.7, fc, fc, cen, frill=True, droop=24)


def _sp_fr(a, x, y, sd, i, dry):
    if i % 2 == 0 and i >= 2:
        e = (x + sd * 8, y - 12); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 6)},{f(y - 6)} {P(e)}", 0.7, 0.85)
        pod(a, *e, 60 if sd > 0 else 120, 11, 3.2, pal("sweet-pea", "fruit", "straw"), bumps=0, hairy=True, twist=(i == 4))
        pod(a, *e, 30 if sd > 0 else 150, 10, 3.0, pal("sweet-pea", "fruit", "straw"), bumps=0, hairy=True)


STAGE["sweet-pea"] = {
    "seed": sown(pulse(["dark", "bark"], n=3, R=7, mottle="seed")),
    "seedling": hypogeal("sweet-pea", "dark", 26, 18),
    "young": climber_leg("sweet-pea", "young", "cane", L=22, flower=_sp_fl, fruit=_sp_fr),
    "flower": climber_leg("sweet-pea", "flower", "cane", L=20, flower=_sp_fl, fruit=_sp_fr),
    "seedhead": climber_leg("sweet-pea", "seedhead", "cane", L=19, flower=_sp_fl, fruit=_sp_fr),
}


# --- tufted vetch: dense one-sided spikes on long stalks from the joints
def _tv_fl(a, x, y, sd, i):
    if i % 2:
        fc = pal("tufted-vetch", "flower", "veg_vetch")
        q = Quad((x, y), (x + sd * 10, y - 12), (x + sd * 20, y - 14))
        a.line(q.d(), 0.7, 0.85)
        for j in range(7):
            u = 0.45 + 0.55 * j / 6; px, py = q.pt(u)
            mini_pea(a, px, py + 1, sd if j % 2 else -sd, 0.55, fc, fc, droop=78)


def _tv_fr(a, x, y, sd, i, dry):
    if i % 2:
        q = Quad((x, y), (x + sd * 9, y - 10), (x + sd * 18, y - 12))
        a.line(q.d(), 0.6, 0.8, "bark")
        for j in range(3):
            px, py = q.pt(0.55 + 0.2 * j)
            pod(a, px, py, 100 - sd * 30, 6, 2.2, pal("tufted-vetch", "fruit", "bark"), bumps=3, beak=True, lw=0.6)


STAGE["tufted-vetch"] = {
    "seed": sown(pulse("dark", n=5, R=4.5)),
    "seedling": hypogeal("tufted-vetch", "dark", 24, 18),
    "young": climber_leg("tufted-vetch", "young", "grass", L=20, H=70, flower=_tv_fl, fruit=_tv_fr),
    "flower": climber_leg("tufted-vetch", "flower", "grass", L=19, H=70, flower=_tv_fl, fruit=_tv_fr),
    "seedhead": climber_leg("tufted-vetch", "seedhead", "grass", L=18, H=70, flower=_tv_fl, fruit=_tv_fr, dryc="pear"),
    "dormant": climber_leg("tufted-vetch", "dormant", "grass", H=50),
}


# --- meadow vetchling: loose yellow heads on stalks longer than the leaves
def _mv_fl(a, x, y, sd, i):
    if i % 2:
        fc = pal("meadow-vetchling", "flower", "sun")
        e = (x + sd * 10, y - 18); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4)},{f(y - 12)} {P(e)}", 0.7, 0.85)
        for j, (g, face) in enumerate(((-150, -1), (-30, 1), (-100, -1), (-70, 1))):
            p = T(*e, g)(2.4); peaflower(a, *p, face, 0.42, fc, fc, fc, droop=10 + 10 * (j > 1))


def _mv_fr(a, x, y, sd, i, dry):
    if i % 2:
        e = (x + sd * 10, y - 16); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4)},{f(y - 10)} {P(e)}", 0.6, 0.85)
        col = pal("meadow-vetchling", "fruit", "dark")
        pod(a, *e, -60 if sd > 0 else -120, 9, 2.6, col, bumps=0, beak=True, lw=0.6)
        pod(a, *e, -20 if sd > 0 else -160, 8, 2.6, col, bumps=0, twist=(i == 3), lw=0.6)


STAGE["meadow-vetchling"] = {
    "seed": sown(pulse("bark", n=4, R=5)),
    "seedling": hypogeal("meadow-vetchling", "bark", 24, 18),
    "young": climber_leg("meadow-vetchling", "young", "grass", L=19, H=64, flower=_mv_fl, fruit=_mv_fr),
    "flower": climber_leg("meadow-vetchling", "flower", "grass", L=18, H=64, flower=_mv_fl, fruit=_mv_fr),
    "seedhead": climber_leg("meadow-vetchling", "seedhead", "grass", L=17, H=64, flower=_mv_fl, fruit=_mv_fr, dryc="pear"),
    "dormant": climber_leg("meadow-vetchling", "dormant", "grass", H=46),
}
