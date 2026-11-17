"""Windfall plant drawings, the redraw of 16 November 2026: the VEG group.

William, this file holds every change to the drawings of 26 plants: the
gourds (courgette, squash, cucumber, melon, loofah), the pea family (broad
bean, pea, French bean, sweet pea, tufted vetch, meadow vetchling, alfalfa,
white and red clover, bird's-foot trefoil, lupin), the nightshades (tomato,
aubergine, chilli, tomatillo, Chinese lanterns) and five others (sweetcorn,
globe artichoke, asparagus, rhubarb, nasturtium). Each drawing was checked,
one at a time, against the plant's written description
(Design/Plants/descriptions/<kind>.json) and photographs of the real plant.

WHY. The old drawings were built from a few shared shapes. Every gourd had
the same lobed leaf and the same flower; the pea family shared one pea
flower and one stock leaf; the life stages used a stock leaf unlike the
close-up. Here each plant gets its own parts, and the whole-plant drawings
reuse the plant's own close-up leaf drawn small, so the two always agree.

HOW THE FILE IS LAID OUT (top to bottom)

1. Small helpers. prof() describes a leaf's outline as "how wide it is at
   each point along its length" (where it is widest, a wedge or rounded
   base, a plain or long drawn-out tip). teeth() and waves() describe the
   edge. blade() draws a leaf or petal from those. own() and oleaf() draw a
   kind's own close-up leaf small on a whole plant, using Art.place, and
   small() keeps each small copy so it is only built once.

2. The gourds. gourd_g() works out a palm-shaped leaf as a distance from
   the middle at every angle: each lobe tip is a point on a circle, and
   between two tips the edge dips into a bay. The settings in GOURD give
   each kind its own lobes (deep and pointed for courgette, hardly there and
   rounded for squash, angular for cucumber, seven points for loofah).
   trumpet() draws a courgette or squash flower from the side: a funnel with
   five lobes growing out from its rim, seen at a slant. gourd_face() and
   gourd_female() draw the small flat flowers of cucumber, melon and loofah,
   the female sitting on her tiny fruit. tendril() draws a coiling tendril.

3. Simple leaves and the nightshades. leaf_simple() is one leaf on its
   stalk, its outline and edge set in LEAFX. leaf_tomato() is the tomato's
   uneven compound leaf with tiny leaflets between the big ones. wheel()
   draws a flower of joined petals face on (from the star of a chilli to
   the shallow bowl of a tomatillo); cone() is the yellow cone of anthers
   in a tomato or aubergine; nodding() is a flower hanging seen from the
   side; husk() is the papery lantern of tomatillo and Chinese lanterns.

4. The pea family. peaflower() draws one pea flower from the side with its
   five petals: the standard standing up at the back, the two wings and the
   keel. Settings give the broad bean its black wing blotch, the sweet pea
   its frilly standard, the French bean its coiled keel. mini_pea() is a
   simpler one for flowers too small for detail (lupin, vetch). The leaves
   come from leaf_pinnate_v() (pairs of leaflets, ending in a tendril or a
   point, with the right stipules at the foot), leaf_three() (three
   leaflets, or five for bird's-foot trefoil) and leaf_wheel() (lupin).
   climber_leg() and clump() build the whole plants.

5. Sweetcorn, globe artichoke, asparagus, rhubarb and nasturtium, each with
   its own leaf, flower and stages.

THE TABLES at the end of each part tell the drawing scripts what to use:
LEAFX and BLOOMX for the close-ups, LEAF_DRAW and BLOOM_DRAW for the new
shapes, STAGE for every life-stage drawing (all of them are drawn here; the
only one left as it was is the broad bean's seed, which was already right).

COLOURS. Six new ones. Five were asked for in the descriptions:
veg_vetch (tufted vetch), veg_lucerne (alfalfa), veg_lupin, veg_artichoke
and veg_aubergine (the fruit). The sixth, veg_cream, is the cream of gourd
and lantern seeds. Each has a dark-mode colour checked on the dark card.

Courgette, tomato and broad bean are three of the ten drawn by hand in
plants.py, so their flower settings here name their colours in full: the
description's palette is not applied to those automatically.

Everything that could not be put fully right is listed, with why, in the
results file that went with this work. Colours and shapes came from the
descriptions and photographs; the descriptions themselves are still marked
for you to check.
"""
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
    "veg_redclover": ("#C8559A", "#D97AB4"),  # red clover heads: pink-purple (the checker found mauve too lilac)
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


def bristles(a, q, n=9, side=1.4, la=0.6, w=None):
    """Short stiff hairs along a stalk: the prickly leaf stalks of courgette.
    w: the stalk's width, so the hairs start at its edge."""
    for k in range(n):
        u = 0.08 + 0.84 * k / max(1, n - 1); x, y = q.pt(u); g = q.ang(u)
        sg = 1 if k % 2 else -1
        b = T(x, y, g + sg * 90)((w or side) * 0.5)
        e = T(*b, g + sg * 50)(side)
        a.line(f"M{P(b)} L{P(e)}", 0.5, la)


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
    "courgette": dict(lobes=[(0, 1.0), (56, 0.9), (112, 0.72)], sinus=0.5, rnd=0.0, nt=70, td=0.035, wav=0.05, wn=30, notch=0.1, flecks=True, pp=0.55, vee=0.3),
    "squash":    dict(lobes=[(0, 1.0), (62, 0.98), (124, 0.9)], sinus=0.94, rnd=1.0, nt=64, td=0.022, wav=0.02, wn=22, notch=0.12, vee=0.26, shoulder=0.98),
    "cucumber":  dict(lobes=[(0, 1.0), (55, 0.78), (115, 0.66)], sinus=0.8, rnd=0.0, nt=46, td=0.04, wav=0.0, wn=0, notch=0.1, pp=1.0, vee=0.34),
    "melon":     dict(lobes=[(0, 0.96), (60, 0.96), (120, 0.88)], sinus=0.88, rnd=0.8, nt=48, td=0.03, wav=0.025, wn=20, notch=0.12, vee=0.28),
    "loofah":    dict(lobes=[(0, 1.0), (44, 0.94), (90, 0.84), (134, 0.62)], sinus=0.6, rnd=0.0, nt=60, td=0.04, wav=0.0, wn=0, notch=0.1, pp=0.75, vee=0.3),
}


def gourd_g(sp):
    """The leaf's edge as a function of the angle round the centre (0 at the
    tip, pi at the stalk): how far out it is, as a share of R."""
    tips = sorted([(math.radians(g), l) for g, l in sp["lobes"]] + [(-math.radians(g), l) for g, l in sp["lobes"] if g])
    last = tips[-1][0]
    sinus = sp["sinus"]; rnd = sp["rnd"]; nt = sp["nt"]; td = sp["td"]; wav = sp["wav"]; wn = sp["wn"]

    def g(h):
        h = math.atan2(math.sin(h), math.cos(h))
        if abs(h) >= last:   # the heart-shaped base: two rounded basal lobes round a deep V where the stalk joins
            vw = sp.get("vee", 0.34); l = tips[-1][1]
            edge = math.pi - vw                                  # where the basal lobe turns in to the V
            sh = l * sp.get("shoulder", 0.92)                    # how far out the basal lobe reaches
            if abs(h) <= edge:
                v = (abs(h) - last) / (edge - last)              # 0 at the last lobe tip, 1 at the V
                r = l + (sh - l) * math.sin(math.pi / 2 * v) - 0.12 * l * math.sin(math.pi * v) * (1 - rnd) * 0.5
            else:
                v = (math.pi - abs(h)) / vw                      # 0 at the bottom of the V, 1 at its rim
                r = sp["notch"] + (sh - sp["notch"]) * v ** 0.75
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
        A = T(*BASE, ANG)(40 if slug == "courgette" else 32)
        q = a.ribbon(BASE, T(*BASE, ANG)(18, 2), A, 4.2 if slug == "courgette" else 2.8, 3.4 if slug == "courgette" else 2.0, fill, lw=0.9)
        if slug in ("courgette", "cucumber"):
            bristles(a, q, 14 if slug == "courgette" else 9, 2.2 if slug == "courgette" else 1.3, 0.85, w=3.8 if slug == "courgette" else 2.4)
        if slug == "courgette":   # the stalk is five-angled: a ridge down it
            a.line(opath([q.pt(u) for u in (0.05, 0.5, 0.95)]), 0.45, 0.4)
        gourd_blade(a, A[0], A[1], ANG + (8 if slug == "cucumber" else 0), sp.get("R", 33), fill, g)
        if slug == "cucumber":   # a rough, bristly surface: short stiff hairs dotted over it
            t = T(*A, ANG + 8); d = sp.get("R", 33) * 0.14
            for j in range(26):
                rr = 0.62 * math.sqrt((j + 0.5) / 26); th = j * GOLD
                p = t(d + sp.get("R", 33) * rr * math.cos(th), sp.get("R", 33) * rr * math.sin(th))
                a.line(f"M{P(p)} l0.5,-0.7", 0.45, 0.45)
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
    "courgette": dict(kind="veg_courgette", fill="deep", R=36),
    "squash": dict(kind="veg_squash", fill="leaf", R=34),
    "cucumber": dict(kind="veg_cucumber", fill="deep", R=34),
    "melon": dict(kind="veg_melon", fill="leaf", R=31),
    "loofah": dict(kind="veg_loofah", fill="deep", R=35),
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
        hw = r0 * 0.62 * math.pi / 5 * (1.0 if pointed else 1.3)
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
    if ovary:   # one short thick stigma, lobed at the top
        a.ribbon(T(*c0, ang)(-4 * s), T(*c0, ang)(-1 * s), T(*c0, ang - 6)(3 * s), 4.4 * s, 5.6 * s, cen, lw=0.7)
        e = T(*c0, ang - 6)(3 * s)
        for o in (-1, 1):
            a.line(f"M{P(e)} L{P(T(*e, ang + 180 + o * 30)(1.8 * s))}", 0.5, 0.6)
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
        pr, Wk, mg = prof(0.45, "round", "point", 0.8, 1.0), 0.66, waves(2, 0.05)
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
    """A tendril: a thread out from the joint ending in a coiled spring
    (three loops), drawn thick enough to read small. arms > 1 gives a
    branched one (squash, loofah): the arms spread from one short stalk."""
    base = T(x, y, ang)(L * 0.3) if arms > 1 else (x, y)
    if arms > 1:
        a.line(f"M{f(x)},{f(y)} L{P(base)}", 0.75, 0.85, col)
    for k in range(arms):
        g = ang + (k - (arms - 1) / 2) * 38
        Lk = (L * (0.7 if arms > 1 else 1)) * (1 - 0.12 * abs(k - (arms - 1) / 2))
        e = T(*base, g)(Lk * 0.55); m = T(*base, g + 20 * curl)(Lk * 0.3)
        r = max(0.9, Lk * 0.11); pts = []
        for j in range(31):   # the coil: loops along the end of the thread, like a telephone cord
            th = 2 * math.pi * 3 * j / 30
            along = Lk * 0.45 * j / 30
            pts.append(T(*e, g)(along + r * 0.7 * math.sin(th), curl * r * (1 - math.cos(th))))
        a.line(f"M{P(base)} Q{P(m)} {P(e)} " + " ".join("L" + P(p) for p in pts), 0.7, 0.85, col)


def tendril_to(a, x, y, cx, cy, col="line", wrap=1.4):
    """A tendril from a joint at x,y reaching across to a cane (or wire) at
    cx,cy and coiling round it: the loops cross the cane."""
    m = ((x + cx) / 2, (y + cy) / 2 - 2)
    a.line(f"M{f(x)},{f(y)} Q{P(m)} {f(cx)},{f(cy)}", 0.7, 0.85, col)
    for j in range(3):   # loops round the cane
        yy = cy + j * 1.6
        a.line(f"M{f(cx - wrap)},{f(yy)} Q{f(cx)},{f(yy - 1.4)} {f(cx + wrap)},{f(yy + 0.4)} Q{f(cx + wrap * 1.5)},{f(yy + 1.2)} {f(cx)},{f(yy + 1.4)}", 0.6, 0.85, col)


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
                tendril(a, x, y - 1, -30 if sd > 0 else -150, 15, arms=3 if sq else 1, curl=sd)
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
                        a.line(f"M{f(x)},{f(y)} Q{f(x + 1)},{f(cy - r * 1.5)} {f(cx - 1)},{f(cy - r * 1.4)}", 1.0, 0.85)
                        a.ribbon((cx - 1.2, cy - r * 1.45), (cx - 0.4, cy - r * 1.25), (cx, cy - r * 0.98), 3.0, 3.8, "straw", lw=0.8)
                        a.line(f"M{f(cx - 0.6)},{f(cy - r * 1.35)} L{f(cx - 0.2)},{f(cy - r * 1.05)}", 0.45, 0.5)
                    else:    # a round melon with a fine raised net
                        r = 8 * k; cx = x + 3; cy = 85 - r * 0.92
                        a.oval(cx, cy, r, r * 0.94, 0, frc, 1.0)
                        for j in range(-3, 4):   # the fine raised net: two sets of curved lines crossing
                            for sg in (1, -1):
                                pts = []
                                for v in [i / 10 for i in range(11)]:
                                    yy = -0.9 + 1.8 * v; xx = j * 0.26 + sg * 0.5 * (yy)
                                    if xx * xx + yy * yy < 0.85:
                                        pts.append((cx + xx * r, cy + yy * r * 0.94))
                                if len(pts) > 1:
                                    a.line(opath(pts), 0.4, 0.45, "bark")
                        a.line(f"M{f(x)},{f(y)} Q{f(x + 1)},{f(cy - r * 1.3)} {f(cx)},{f(cy - r * 1.1)}", 1.0, 0.85)
                        a.ribbon((cx, cy - r * 1.15), (cx, cy - r * 1.05), (cx, cy - r * 0.9), 1.8, 2.4, "leaf", lw=0.7)
        return a
    return draw


def climb_plant(slug, stage):
    """Cucumber: a vine trained up a cane, beside it (it does not twine), held
    by simple tendrils from the joints coiled round the cane; small yellow
    flowers at the joints; the long fruit hanging down. Loofah: the same up a
    post and along a wire, branched tendrils, males in stalked clusters,
    the long fruit hanging from the wire."""
    def draw():
        lc = pal(slug, "leaf", "deep"); fc = pal(slug, "flower", "sun"); cen = pal(slug, "centre", "amber")
        frc = pal(slug, "fruit", "marrow")
        lf = slug == "loofah"
        a = Art(); soil(a, 88)
        top = 28 if stage == "young" else 12
        cx = 46
        with a.on(STEM):
            a.ribbon((cx, 89), (cx, 50), (cx, top - 4 if not lf or stage == "young" else 12), 2.0, 1.8, "bark", lw=0.8)
            if lf and stage != "young":
                a.line("M8,14 L92,14", 0.8, 0.7)
        n = 4 if stage == "young" else 6
        H = 87 - top
        q = a.stem((cx + 4, 88), (cx + 6, 88 - H * 0.5), (cx + 4.5, top), 1.4)   # the vine, beside the cane
        nodes = [q.pt(0.12 + 0.86 * i / (n - 1)) for i in range(n)]
        wire = []
        if lf and stage != "young":   # along the wire to the right
            q2 = a.stem((cx + 4.5, top), (cx + 18, 11), (90, 14), 1.2)
            wire = [q2.pt(u) for u in (0.3, 0.6, 0.9)]
        R = 11 if not lf else 11
        for i, (x, y) in enumerate(nodes):
            sd = 1 if i % 2 == 0 else -1          # the leaf goes out to this side
            e = (x + sd * 12 + (2 if sd < 0 else 0) - (8 if sd < 0 else 0), y - 6)
            with a.on(STEM):
                a.stem((x, y), ((x + e[0]) / 2, y - 1), e, 0.9)
                if i < n - 1:
                    if lf:
                        tendril(a, x, y + 1, 150, 8, arms=3, curl=1)
                    else:
                        tendril_to(a, x, y + 1, cx, y - 3)
            with a.on(LEAF):
                gleaf(a, slug, e[0], e[1], -90 + sd * 28, R * (1 - 0.04 * i))
            with a.on(BLOOM):
                if stage == "flower" and (i in (1, 3) if lf else i in (1, 2, 3, 4)):
                    if lf:   # a long stalk standing out from the joint, several flowers at its end
                        p = (x - sd * 16, y - 4)
                        a.stem((x, y), (x - sd * 8, y - 4), p, 0.9)
                        for j, (dx, dy, r) in enumerate(((0, -3, 4.6), (4, 2, 4.0), (-1, 4.5, 1.4), (3, -7, 1.3))):
                            if r > 2:
                                gourd_face(a, p[0] + dx, p[1] + dy, r, fc, cen, "loofah", k=0.85)
                            else:
                                a.oval(p[0] + dx, p[1] + dy, r, r * 1.3, 0, "unripe", 0.6)
                    else:
                        p = (x + 6, y + 1)
                        a.line(f"M{f(x)},{f(y)} L{P(p)}", 0.8, 0.85)
                        gourd_face(a, p[0] + 2, p[1], 4.4, fc, cen, "cucumber", k=0.85)
                        if i == 3:
                            gourd_female(a, x + 3, y + 7, 70, 3.4, fc, cen, "cucumber", 0.4)
                if stage == "crop" and not lf and i in (1, 2, 4):
                    p = (x + 6, y + 1)
                    a.stem((x, y), (x + 3, y), p, 0.9)
                    gfruit_long(a, p, (p[0] + 1.5, p[1] + 12), (p[0] + 1, p[1] + 25 - i), 4.6, 4.0, frc, speck=True, remains="primrose")
        for j, (x, y) in enumerate(wire):
            with a.on(STEM):
                tendril_to(a, x, y + 2, x - 3, 14)
            with a.on(LEAF):
                gleaf(a, slug, x, y - 1, -96 + j * 8, R * 0.85)
            with a.on(BLOOM):
                if stage == "flower":
                    a.stem((x, y), (x + 2, y + 4), (x + 4, y + 9), 0.8)
                    gourd_face(a, x + 4, y + 11, 4.4, fc, cen, "loofah", k=0.85)
                if stage == "crop":
                    gfruit_long(a, (x, y + 1), (x + 1, y + 22), (x - 1, y + 44), 4.8, 6.2, frc, speck=False, remains=None, ridge=1)
        return a
    return draw


STAGE["squash"] = {"seed": sown(gseed("veg_cream", 30, 19, 0.15)), "seedling": gourd_seedling("squash", 0.58, 19, 6.5),
                   "young": trail_plant("squash", "young"), "flower": trail_plant("squash", "flower"), "crop": trail_plant("squash", "crop")}
STAGE["melon"] = {"seed": sown(gseed("veg_cream", 26, 10.5, 0.5)), "seedling": gourd_seedling("melon", 0.56, 15, 5.5),
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


def inked(a, start, ink):
    """Redraws the lines of everything added since `start` in another
    colour: a dead or dying plant drawn in brown ink, not green."""
    for i in range(start, len(a.items)):
        it = a.items[i]
        if it[0] == "path" and it[5] == "line":
            a.items[i] = it[:5] + (ink,) + it[6:]


def own(a, slug, x, y, ang, L, fill=None, lw=None, detail=None, ink=None, **over):
    """The kind's whole close-up leaf (stalk and all), drawn L long. over
    changes a setting for the small copy only (pea: no piece of stem)."""
    import leaves_flowers as LFW
    sp = dict(spec(slug), **over)

    def build():
        b = LFW.LEAF_DRAW[sp["kind"]](Art(), sp)
        b.anchor, b.anchor_ang, b.size = BASE, ANG, 98
        return b
    src = small(("own", slug, tuple(sorted(over.items()))), build)
    n0 = len(a.items)
    put(a, src, x, y, ang, L, lw=lw, fills={sp["fill"]: fill} if fill and fill != sp["fill"] else None, detail=detail)
    if ink:
        inked(a, n0, ink)


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
            for v in (0.28, 0.45, 0.62, 0.78):   # the puckering: little blisters between the veins
                for o in (0.12, -0.12):
                    c = T(*e, g + sg * 56)(L * v, o * L)
                    a.line(f"M{P(T(*c, g + sg * 56)(-1.3))} Q{P(T(*c, g + sg * 56 - 90)(1.0))} {P(T(*c, g + sg * 56)(1.3))}", 0.4, 0.32)
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


def open_star(a, x, y, R, fc, cen, n=6, join=0.5, sep="sage", calyx=True):
    """A small open nightshade flower for the whole plant, hanging and tipped
    towards us: a calyx showing behind, the star of petals, the yellow centre."""
    if calyx:
        for i in range(n):
            blade(a, x, y, -90 + 360 * (i + 0.5) / n, R * 1.15, R * 0.5, sep, prof(0.35, "round", "point"), veins=0, lw=0.5, petal=True, M=tilt(y, 0.7))
    wheel(a, x, y, R, n, fc, join=join, pp=0.85, k=0.7, lines=False, lw=0.75)
    a.oval(x, y, R * 0.28, R * 0.22, 0, cen, 0.5)


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
        # one flower close, from the side: narrow petals swept right back, long sepals, the pointed cone
        a.line("M52,50 Q58,34 62,30", 1.0, 0.85)
        x, y, g = 62, 30, 64
        t = T(x, y, g)
        base = t(4)
        for o in (-150, 150, -116, 116, 180):   # petals bent right back towards the stalk
            blade(a, *base, g + o, 24, 6.0, fc, prof(0.35, "round", "point", 0.8, 0.9), veins=0, lw=0.85, petal=True)
            a.line(f"M{P(T(*base, g + o)(4))} L{P(T(*base, g + o)(17))}", 0.4, 0.3)
        for o in (-165, 165, -133, 133, -100, 100):   # long narrow hairy sepals, showing between the petals
            blade(a, *t(2), g + o, 19, 2.6, "leaf", prof(0.3, "round", "point"), veins=0, lw=0.7, petal=True)
        cone(a, *base, 26, 8.4, g, "sun")
        a.line(f"M{P(T(*base, g)(27))} L{P(T(*base, g)(32))}", 0.8, 0.85)   # the style poking out of the tip
        return a
    if kind == "aubergine":
        a.ribbon((40, 98), (36, 70), (44, 40), 3.4, 2.8, "sage", lw=0.9)
        a.line("M44,40 Q54,30 60,34", 1.4, 0.85)
        cx, cy = 58, 52
        for i in range(6):   # the big thick felted calyx, its broad lobes showing well beyond the petals
            blade(a, cx, cy, -90 + 60 * (i + 0.5), 30, 13, "sage", prof(0.35, "round", "point"), veins=0, lw=0.8, petal=True, M=tilt(cy, 0.86))
            p = T(cx, cy, -90 + 60 * (i + 0.5))(24); a.line(f"M{P(tilt(cy, 0.86)(p))} l0.8,-1.2", 0.5, 0.6)   # a prickle
        a.line(f"M60,34 Q62,40 {cx},{cy - 6}", 1.6, 0.85)
        at = wheel(a, cx, cy, 25, 6, fc, join=0.5, pp=0.85, start=-60)
        for j in range(6):   # darker veins in each lobe
            p0 = at(-60 + 60 * j, 0.25); p1 = at(-60 + 60 * j, 0.8)
            a.line(f"M{P(p0)} L{P(p1)}", 0.6, 0.6, "plum")
        for j in range(5):   # the cone of thick yellow anthers, pointing straight at us
            blade(a, cx, cy, -90 + 72 * j, 7.5, 3.6, cen, prof(0.35, "round", "point"), veins=0, lw=0.7, petal=True)
        a.dot(cx, cy, 1.2, "unripe")
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
        if compound:   # tomato: one small first leaf of three to five toothed leaflets
            a.line("M50,54 L50.6,47", 0.9, 0.85)
            for g, L in ((-150, 6), (-30, 6), (-92, 8)):
                blade(a, 50.6, 47 if g == -92 else 49.5, g, L, L * 0.55, "leaf", prof(0.45), teeth(3, 0.22), veins=1, lw=0.8)
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
        top = 32 if stage == "young" else 15
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
    "seedling": nseedling("tomato", 15, 0.18, 10, compound=True),
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
                    open_star(a, x + sd * 5, y + 6, 6.0, fc, pal("aubergine", "centre", "sun"))
                x, y = q.pt(0.82)
                a.line(f"M{f(x)},{f(y)} Q{f(x + 4)},{f(y - 2)} {f(x + 5)},{f(y + 3)}", 0.8, 0.85)
                open_star(a, x + 6, y + 7, 5.6, fc, pal("aubergine", "centre", "sun"))
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
                if stage == "flower":   # one white flower hanging in each fork, tipped towards us
                    a.line(f"M{f(x)},{f(y)} Q{f(x + 2)},{f(y + 2)} {f(x + 2.4)},{f(y + 5)}", 0.7, 0.85)
                    open_star(a, x + 2.4, y + 8, 6.4, fc, pal("chilli-pepper", "centre", "lilac"), n=5, join=0.18, sep="leaf")
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
    if fruit and split:   # the fruit filling the husk and splitting it open: a dark slit, the fruit bulging through
        a.shape(path([(x, y + L * 0.2), (x + W * 0.3, y + L * 0.55), (x, y + L * 0.97), (x - W * 0.3, y + L * 0.55)]), "shade", 0, fa=0.3)
        a.oval(x, y + L * 0.58, W * 0.34, W * 0.36, 0, fruit, 0.9)
        a.line(f"M{f(x - W * 0.15)},{f(y + L * 0.5)} Q{f(x - W * 0.2)},{f(y + L * 0.58)} {f(x - W * 0.12)},{f(y + L * 0.68)}", 0.5, 0.5, "white")
    for o in ((-0.62, 0.62) if (fruit and split) else (-0.62, 0, 0.62)):   # the ridges, with fine veins between
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
                        husk(a, x + sd * 1.5, y + 3, 13 - 1.5 * i, "pale", fruit=frc, split=True)
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
                        open_star(a, e[0], e[1] + 3, 4.6, fc, pal("chinese-lanterns", "centre", "pear"), n=5, join=0.55, sep="leaf")
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
    cal = [loc(0, -1.6 * s), loc(3.2 * s, -2.0 * s * slim), loc(6.4 * s, -2.8 * s * slim), loc(4.6 * s, -1.0 * s), loc(6.6 * s, 0.2 * s),
           loc(4.6 * s, 0.9 * s), loc(6.2 * s, 2.4 * s * slim), loc(3.2 * s, 1.9 * s * slim), loc(0, 1.4 * s)]
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
    # keel: a boat curving up at its tip (a coiled keel is drawn after the wings, in front)
    if not coil:
        kp = [loc(4.4 * s, -0.4 * s), loc(10 * s, 0.6 * s), loc(14.4 * s * (0.9 + 0.1 * slim), -2.0 * s), loc(11 * s, 3.6 * s * slim), loc(5 * s, 2.4 * s)]
        a.shape(f"M{P(kp[0])} Q{P(kp[1])} {P(kp[2])} Q{P(kp[3])} {P(kp[4])} Z", keel, 0.7)
    # wings: held forward over the keel
    wp = [loc(4.0 * s, -1.8 * s), loc(9.6 * s, -6.0 * s * slim), loc(14.0 * s * (0.9 + 0.1 * slim), -1.8 * s), loc(10 * s, 2.4 * s), loc(4.6 * s, 0.8 * s)]
    a.shape(f"M{P(wp[0])} Q{P(wp[1])} {P(wp[2])} Q{P(wp[3])} {P(wp[4])} Z", wing, 0.75)
    a.line(f"M{P(loc(5 * s, -0.6 * s))} Q{P(loc(8.4 * s, -1.6 * s))} {P(loc(11 * s, -1.2 * s))}", 0.4, 0.3)
    if coil:   # French bean: the keel twisted into a tight spiral, sticking out below the wings
        pts = [loc(5 * s, 1.6 * s)]
        for j in range(40):
            th = -math.pi / 2 + 2 * math.pi * 1.6 * j / 39; r = 4.2 * s * (1 - 0.7 * j / 39)
            pts.append(loc(9.5 * s + r * math.cos(th), 3.2 * s + r * math.sin(th)))
        a.line(opath(pts), 2.6 * s, 0.85)
        a.line(opath(pts), 1.5 * s, 1.0, keel)
    if blotch:
        c = loc(8.4 * s, -1.0 * s); a.oval(c[0], c[1], 2.4 * s, 1.6 * s, g0 - face * 10, blotch, 0)
    return sc


def pea_front(a, x, y, s, std, wing=None, keel=None, calyx="leaf", blotch=None, lines=None, frill=False):
    """A pea flower seen from the front: the standard standing up behind,
    the two wings spread below it either side of the keel. Shows both of a
    broad bean's black wing blotches. x,y is the middle, where they meet."""
    wing = wing or std; keel = keel or wing
    a.shape(path([(x - 3 * s, y + 3 * s), (x - 2.2 * s, y + 8 * s), (x + 2.2 * s, y + 8 * s), (x + 3 * s, y + 3 * s)]), calyx, 0.7)
    for sg in (-1, 1):   # calyx teeth
        a.shape(path([(x + sg * 2.6 * s, y + 6 * s), (x + sg * 4 * s, y + 9 * s), (x + sg * 1.4 * s, y + 7.6 * s)]), calyx, 0.6)
    wav = (lambda h: 1 + 0.05 * math.cos(9 * h)) if frill else (lambda h: 1 - 0.08 * math.exp(-((h + math.pi / 2) / 0.3) ** 2))
    a.shape(path([(x + 10 * s * wav(h) * math.cos(h), y - 8 * s + 10 * s * wav(h) * math.sin(h) * 1.05) for h in [2 * math.pi * i / 60 for i in range(60)]]), std, 0.9)
    for o in (-50, -25, 0, 25, 50):   # lines on the standard, running out from its base
        e = T(x, y - 1 * s, -90 + o)(14 * s); a.line(f"M{f(x)},{f(y - 1 * s)} Q{P(T(x, y - 1 * s, -90 + o * 0.8)(7 * s))} {P(e)}", 0.5 if lines else 0.4, 0.75 if lines else 0.3, lines or "line")
    for sg in (-1, 1):   # the wings
        blade(a, x + sg * 1 * s, y, 90 + sg * 62, 12 * s, 8 * s, wing, prof(0.55, "round", "round", 0.6, 2.0), veins=0, lw=0.85, petal=True)
        if blotch:
            c = T(x + sg * s, y, 90 + sg * 62)(7.4 * s); a.oval(c[0], c[1], 3.4 * s, 2.6 * s, 90 + sg * 62, blotch, 0)
    blade(a, x, y + 1 * s, 90, 8 * s, 4.6 * s, keel, prof(0.5, "round", "round"), veins=0, lw=0.7, petal=True)


def vetch_flower(a, x, y, ang, s, fc):
    """One small narrow pea flower of tufted vetch, hanging from the underside
    of the spike along ang: a short calyx, the narrow body (wings and keel)
    pointing down, the small standard turned back at the top."""
    blade(a, x, y, ang, 2.6 * s, 1.6 * s, "leaf", prof(0.5), veins=0, lw=0.5, petal=True)
    b = T(x, y, ang)(2.0 * s)
    blade(a, *b, ang - 28, 4.4 * s, 3.6 * s, fc, prof(0.5, "round", "round"), veins=0, lw=0.55, petal=True)   # the standard, turned back
    blade(a, *b, ang + 6, 8.0 * s, 2.8 * s, fc, prof(0.45, "round", "round", 0.7, 1.4), veins=0, lw=0.6, petal=True)   # wings and keel
    a.line(f"M{P(T(*b, ang + 6)(1.5 * s))} L{P(T(*b, ang + 6)(6.5 * s))}", 0.35, 0.35)


def comb_spike(a, q, n, s, fc, u0=0.15, side=1):
    """Tufted vetch's spike: n narrow flowers all hanging from one side of
    the stalk q, packed like the teeth of a comb, smaller towards the tip."""
    for j in range(n):
        u = u0 + (0.98 - u0) * j / max(1, n - 1); x, y = q.pt(u); g = q.ang(u)
        ss = s * (1 - 0.35 * (u - u0) / (1 - u0))
        vetch_flower(a, x, y, g + side * 105, ss, fc)


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
        if kind == "pea":   # huge leafy half-hearts clasping the stem, toothed along their lower edge
            blade(a, x, y, ang + sg * 118, size, size * 0.8, fill, prof(0.42, "round", "point", 0.5, 0.9),
                  lambda u, side, sg=sg: teeth(6, 0.14)(u, side) if side == -sg else 1.0, veins=2, lw=0.85, lop=0.25 * sg)
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
        x, y = q.pt(0.2)
        if sp.get("stem", True):
            a.ribbon((x - 5, 99), (x - 2, y), (x + 4, y - 30), 2.6, 2.0, fill, lw=0.8)
        stip(a, x, y, q.ang(0.2), "pea", sp.get("stipL", 10), fill)
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
    fill = sp["fill"]; t = T(*BASE, ANG); S = sp.get("S", 40); A = t(S)
    a.ribbon(BASE, t(S / 2, 2), A, 2.4, 1.8, fill, lw=0.85)
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
                end="tendril", tl=20, arms=5, stip="pea", stipL=16, LT=72, spread=50, span=(0.5, 0.75)),
    "sweet-pea": dict(kind="veg_pinnate", pairs=1, ll=34, lW=0.42, pr=(0.48, "round", "point", 0.7, 1.0), span=(0.55, 0.55),
                      end="tendril", tl=26, arms=3, stip="narrow", stipL=9, LT=70, wing=True, spread=34, veins=4),
    "tufted-vetch": dict(kind="veg_pinnate", pairs=10, ll=12, lW=0.26, pr=(0.5, "round", "round", 0.5, 2.6), span=(0.1, 0.84),
                         end="tendril", tl=14, arms=3, stip="narrow", stipL=5, LT=80, spread=62, veins=0),
    "meadow-vetchling": dict(kind="veg_pinnate", pairs=1, ll=40, lW=0.2, pr=(0.45, "wedge", "point", 0.9, 0.9), span=(0.42, 0.42),
                             end="tendril", tl=18, arms=1, stip="arrowhead", stipL=22, LT=62, spread=30, veins=0),
    "french-bean": dict(kind="veg_three", ll=31, lW=0.64, pr=(0.42, "round", "acum", 0.85, 1.2), stalk=30, mid=19, sstalk=3,
                        lop=0.16, spread=80, stipels=True, veins=5),
    "alfalfa": dict(kind="veg_three", ll=29, lW=0.38, pr=(0.72, "taper", "blunt", 1.4, 3.0), stalk=36, mid=13, mg=("teeth", 7, 0.2, "saw", 0, 0.62),
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
    if pk == "broad-bean":   # one flower facing us from its place in the leaf joint, a second from the side
        a.ribbon((70, 99), (71, 60), (70, 4), 4.4, 3.4, "sage", lw=0.9)
        a.ribbon((71, 70), (82, 62), (96, 52), 2.4, 1.8, "sage", lw=0.8)
        peaflower(a, 69, 80, -1, 1.5, fc, fc, "white", "leaf", blotch="dark", lines="plum", droop=30)
        a.line("M70,52 Q62,52 52,54", 1.2, 0.85)
        pea_front(a, 42, 46, 2.3, fc, fc, "white", blotch="dark", lines="plum")
        return a
    if pk == "pea":
        q = Quad((42, 99), (40, 76), (46, 52))
        a.ribbon(q.p0, q.c, q.p1, 2.4, 2.0, "sage", lw=0.8)
        a.line("M46,52 Q50,42 56,40", 1.0, 0.85); a.line("M46,52 Q40,46 32,50", 1.0, 0.85)
        peaflower(a, 56, 40, 1, 2.3, fc, fc, fc, "sage", droop=14)
        peaflower(a, 32, 50, -1, 1.8, fc, fc, fc, "sage", droop=30)
        return a
    if pk == "french-bean":   # a short loose cluster, the keel coiled
        a.ribbon((40, 99), (42, 70), (48, 50), 2.2, 1.8, "leaf", lw=0.8)
        for (x, y, face, s, dr) in ((58, 40, 1, 2.0, 10), (30, 46, -1, 1.8, 20), (54, 68, 1, 1.5, 40)):
            a.line(f"M48,50 Q{f((48 + x) / 2)},{f(y + 6)} {f(x)},{f(y)}", 0.8, 0.85)
            peaflower(a, x, y, face, s, fc, fc, fc, "leaf", coil=True, droop=dr)
        a.line("M48,50 L48,40", 0.7, 0.85); a.oval(48, 38, 1.6, 2.6, 0, "pale", 0.6)
        return a
    if pk == "sweet-pea":   # sprays on a long stiff upright stalk, big frilly standards
        a.ribbon((44, 99), (46, 66), (48, 32), 2.0, 1.6, "leaf", lw=0.8)
        for (x, y, face, s, dr) in ((60, 32, 1, 2.1, 6), (30, 48, -1, 2.0, 14), (60, 66, 1, 1.8, 26)):
            a.line(f"M48,{f(y + 10)} Q{f((48 + x) / 2)},{f(y + 6)} {f(x)},{f(y)}", 0.8, 0.85)
            peaflower(a, x, y, face, s, fc, fc, cen or fc, "leaf", frill=True, droop=dr)
        bud(a, 48, 32, -88, 6, fc)
        return a
    if pk == "tufted-vetch":   # a dense one-sided spike, the flowers hanging down from one side
        a.ribbon((34, 99), (38, 70), (44, 54), 1.8, 1.5, "leaf", lw=0.8)
        q = Quad((44, 54), (62, 26), (90, 20))
        a.line(q.d(), 1.2, 0.85)
        comb_spike(a, q, 15, 2.0, fc, 0.12)
        return a
    if pk == "meadow-vetchling":   # a loose head at the end of a stalk longer than the leaf
        a.ribbon((44, 99), (44, 70), (48, 44), 2.0, 1.6, "leaf", lw=0.8)
        for (x, y, face, s, dr) in ((62, 28, 1, 1.5, 10), (34, 30, -1, 1.5, 10), (66, 44, 1, 1.4, 40), (30, 46, -1, 1.4, 40), (50, 22, 1, 1.3, -20)):
            a.line(f"M48,44 Q{f((48 + x) / 2)},{f(y + 4)} {f(x)},{f(y)}", 0.7, 0.85)
            peaflower(a, x, y, face, s, fc, fc, fc, "leaf", lines="rust", droop=dr)
        return a
    if pk == "alfalfa":   # a short dense oblong head, held up on a stalk
        a.ribbon((46, 99), (48, 76), (50, 62), 2.0, 1.6, "leaf", lw=0.8)
        a.line("M50,62 L50,30", 1.2, 0.85)
        for r in range(5):   # a short dense oblong head of small pea flowers
            y = 60 - r * 6.4
            for j, face in enumerate((-1, 1)):
                peaflower(a, 50 + face * 1.2, y, face, 0.95 - 0.06 * r, fc, fc, fc, "leaf", droop=-10 + 25 * (r % 2))
        for k in range(3):
            a.oval(50 + (k - 1) * 2.6, 28 - abs(k - 1) * 1.4, 1.6, 2.6, (k - 1) * 20, fc, 0.6)
        return a
    if pk == "lupin":   # a tall dense spike, rings of flowers opening from the bottom, buds at the top
        a.ribbon((50, 99), (50, 60), (50, 6), 3.2, 1.6, "leaf", lw=0.8)
        for r in range(9):
            y = 84 - r * 8.0; s = 1.2 - 0.06 * r
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
            g = lambda h: (1 - kidney * math.exp(-((h + math.pi / 2) / 0.5) ** 2) - heart * math.exp(-((h + math.pi / 2) / 0.3) ** 2)
                           + heart * 0.5 * math.exp(-((h - math.pi / 2) / 0.35) ** 2)
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
        bb = slug == "broad-bean"
        under_seed(a, 50, 79 if bb else 77, seedc, 1.6 if bb else 1.0)
        q = a.ribbon((50, 75), (49, 72 - h * 0.5), (50.5, 72 - h), 4.0 if bb else 1.8, 3.0 if bb else 1.3, "pale" if not bb else "leaf", lw=0.8)
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


def pod(a, x, y, ang, L, W, col, bumps=4, beak=True, hairy=False, twist=False, lw=0.8, beakL=0.12):
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
        a.line(f"M{P(t(L * 0.98))} Q{P(t(L * (0.96 + beakL * 0.8), -W * 0.1))} {P(t(L * (1 + beakL), -W * 0.35 - L * beakL * 0.5))}", 0.6 if beakL <= 0.12 else 0.8, 0.85)
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


def climber_leg(slug, stage, support="net", n=6, L=20, H=72, flower=None, fruit=None, dryc="straw", over=None, top_leaf=True, lw=None):
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
                for yy in range(20, 88, 20):
                    a.line(f"M22,{yy} L78,{yy}", 0.4, 0.28)
                for xx in range(36, 78, 14):
                    a.line(f"M{xx},14 L{xx},88", 0.4, 0.28)
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
            if slug == "sweet-pea":   # the stem has two narrow green wings running down it
                for p0, p1 in zip(pts, pts[1:]):
                    a.ribbon(p0, lerp(p0, p1, 0.5), p1, 2.6, 2.2, dryc if dry else pal(slug, "leaf", "leaf"), lw=0.6)
            a.line("M" + " L".join(P(p) for p in pts), 1.1, 0.85, "line" if not dry else "bark")
        for i, (x, y) in enumerate(pts[1:]):
            sd = -1 if i % 2 else 1
            with a.on(LEAF):
                if i < nn - 1 or top_leaf:
                    own(a, slug, x, y, -90 + sd * 52, L * (1 - 0.12 * i / nn), fill=dryc if dry else None, lw=lw, ink="bark" if dry else None, **(over or {}))
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
    fc = pal("pea", "flower", "white")
    e = (x + sd * 7, y - 2); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 3)},{f(y - 4)} {P(e)}", 0.8, 0.85)
    peaflower(a, *e, sd, 1.15, fc, calyx="leaf", droop=8)
    if i == 3:
        e2 = (e[0] + sd * 1, e[1] + 6); a.line(f"M{P(e)} L{P(e2)}", 0.7, 0.85)
        peaflower(a, *e2, sd, 0.95, fc, calyx="leaf", droop=40)


def _pea_fr(a, x, y, sd, i, dry):
    """Smooth pods hanging down from the joints on short stalks."""
    if i in (1, 2, 4):
        e = (x + sd * 10, y + 1); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 6)},{f(y - 2)} {P(e)}", 0.9, 0.85, "line" if not dry else "bark")
        pod(a, *e, 90 - sd * 18, 16, 4.8, "straw" if dry else pal("pea", "fruit", "leaf"), bumps=0, beak=True)


STAGE["pea"] = {
    "seed": sown(pulse(["pear", "veg_cream"], n=2, R=10, wrinkled=True, scar="seed", spots=[(-8, 0, 1.0), (10, 1, 0.95)])),
    "seedling": hypogeal("pea", "pear", 26, 18, over=dict(stem=False)),
    "young": climber_leg("pea", "young", "net", L=28, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
    "flower": climber_leg("pea", "flower", "net", L=27, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
    "crop": climber_leg("pea", "crop", "net", L=27, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
    "seedhead": climber_leg("pea", "seedhead", "net", L=25, over=dict(stem=False), flower=_pea_fl, fruit=_pea_fr),
}


# --- sweet pea: sprays on long upright stalks held above the leaves
def _sp_fl(a, x, y, sd, i):
    """Sprays of large frilly flowers on long stiff stalks, standing up above the leaves."""
    if i in (1, 4):
        fc = pal("sweet-pea", "flower", "mauve"); cen = pal("sweet-pea", "centre", "pink")
        e = (x + sd * (22 if i == 1 else 12), 16 if i == 4 else 24)
        a.ribbon((x, y), (x + sd * 6, (y + e[1]) / 2 + 4), e, 1.0, 0.8, "leaf", lw=0.6)
        peaflower(a, *e, sd, 0.95, fc, fc, cen, frill=True, droop=4)
        e2 = (e[0] - sd * 1, e[1] + 6); peaflower(a, *e2, -sd, 0.85, fc, fc, cen, frill=True, droop=22)
        e3 = (e[0] + sd * 1, e[1] + 11); peaflower(a, *e3, sd, 0.7, fc, fc, cen, frill=True, droop=36)


def _sp_fr(a, x, y, sd, i, dry):
    if i in (1, 3, 4):
        e = (x + sd * 9, y - 10); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 6)},{f(y - 5)} {P(e)}", 0.8, 0.85, "bark" if dry else "line")
        col = pal("sweet-pea", "fruit", "straw")
        pod(a, *e, 55 if sd > 0 else 125, 15, 4.0, col, bumps=0, hairy=True, twist=(i == 3))
        pod(a, *e, 20 if sd > 0 else 160, 14, 3.8, col, bumps=0, hairy=True)


STAGE["sweet-pea"] = {
    "seed": sown(pulse(["dark", "bark"], n=3, R=7, mottle="seed")),
    "seedling": hypogeal("sweet-pea", "dark", 26, 18),
    "young": climber_leg("sweet-pea", "young", "cane", L=22, flower=_sp_fl, fruit=_sp_fr),
    "flower": climber_leg("sweet-pea", "flower", "cane", L=20, flower=_sp_fl, fruit=_sp_fr),
    "seedhead": climber_leg("sweet-pea", "seedhead", "cane", L=19, flower=_sp_fl, fruit=_sp_fr),
}


# --- tufted vetch: dense one-sided spikes on long stalks from the joints
def _tv_fl(a, x, y, sd, i):
    """Long one-sided spikes on stalks about as long as the leaf, from the joints."""
    if i % 2:
        fc = pal("tufted-vetch", "flower", "veg_vetch")
        q = Quad((x, y), (x + sd * 12, y - 16), (x + sd * 28, max(10, y - 18)))
        a.line(q.d(), 0.8, 0.85)
        comb_spike(a, q, 9, 0.85, fc, 0.42, side=sd)


def _tv_fr(a, x, y, sd, i, dry):
    if i % 2:
        q = Quad((x, y), (x + sd * 9, y - 10), (x + sd * 18, y - 12))
        a.line(q.d(), 0.6, 0.8, "bark")
        for j in range(3):
            px, py = q.pt(0.55 + 0.2 * j)
            pod(a, px, py, 100 - sd * 30, 6, 2.2, pal("tufted-vetch", "fruit", "bark"), bumps=3, beak=True, lw=0.6)


STAGE["tufted-vetch"] = {
    "seed": sown(pulse("dark", n=5, R=4.5)),
    "seedling": hypogeal("tufted-vetch", "dark", 24, 24, over=dict(pairs=3, span=(0.4, 0.7), arms=1, tl=22, ll=16)),
    "young": climber_leg("tufted-vetch", "young", "grass", L=32, H=70, flower=_tv_fl, fruit=_tv_fr, lw=0.5, over=dict(pairs=7, ll=14, tl=24)),
    "flower": climber_leg("tufted-vetch", "flower", "grass", L=28, H=70, flower=_tv_fl, fruit=_tv_fr, lw=0.5, over=dict(pairs=7, ll=14, tl=24)),
    "seedhead": climber_leg("tufted-vetch", "seedhead", "grass", L=26, H=70, flower=_tv_fl, fruit=_tv_fr, dryc="pear", lw=0.5, over=dict(pairs=7, ll=14, tl=24)),
    "dormant": climber_leg("tufted-vetch", "dormant", "grass", H=50),
}


# --- meadow vetchling: loose yellow heads on stalks longer than the leaves
def _mv_fl(a, x, y, sd, i):
    """A loose head of 6 yellow flowers at the end of a stalk longer than the leaf."""
    if i in (1, 3):
        fc = pal("meadow-vetchling", "flower", "sun")
        e = (x + sd * 12, max(y - 28, 14)); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 3)},{f(y - 16)} {P(e)}", 0.8, 0.85)
        for j, (g, face, dr) in enumerate(((-160, -1, 10), (-20, 1, 10), (-125, -1, -10), (-55, 1, -10), (-90, 1, -30), (150, -1, 40))):
            p = T(*e, g)(3.0); peaflower(a, *p, face, 0.55, fc, fc, fc, droop=dr)


def _mv_fr(a, x, y, sd, i, dry):
    if i in (1, 3):
        e = (x + sd * 12, max(y - 24, 14)); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 3)},{f(y - 14)} {P(e)}", 0.7, 0.85, "bark")
        col = pal("meadow-vetchling", "fruit", "dark")
        pod(a, *e, -55 if sd > 0 else -125, 13, 3.2, col, bumps=0, beak=True, lw=0.7)
        pod(a, *e, -10 if sd > 0 else -170, 12, 3.2, col, bumps=0, beak=True, lw=0.7)
        pod(a, *e, 40 if sd > 0 else 140, 11, 4.0, col, bumps=0, twist=True, lw=0.7)


STAGE["meadow-vetchling"] = {
    "seed": sown(pulse("bark", n=4, R=5)),
    "seedling": hypogeal("meadow-vetchling", "bark", 24, 18),
    "young": climber_leg("meadow-vetchling", "young", "grass", L=26, H=64, flower=_mv_fl, fruit=_mv_fr, lw=0.6, over=dict(stipL=30)),
    "flower": climber_leg("meadow-vetchling", "flower", "grass", L=22, H=64, flower=_mv_fl, fruit=_mv_fr, lw=0.6, over=dict(stipL=30)),
    "seedhead": climber_leg("meadow-vetchling", "seedhead", "grass", L=21, H=64, flower=_mv_fl, fruit=_mv_fr, dryc="pear", lw=0.6, over=dict(stipL=30)),
    "dormant": climber_leg("meadow-vetchling", "dormant", "grass", H=46),
}


# --- broad bean: stiff, upright, no tendrils; flowers in clusters tight in the upper joints
def broad_bean(stage):
    def draw():
        a = Art(); soil(a, 88)
        dry = stage == "seedhead"
        lc = "straw" if dry else "sage"; sc = "straw" if dry else "leaf"
        top = 40 if stage == "young" else 12
        q = a.ribbon((50, 88), (51.5, (88 + top) / 2), (50, top), 3.6, 2.0, sc, lw=0.85)
        a.line(opath([q.pt(u) for u in (0.02, 0.5, 0.98)]), 0.45, 0.4)   # the square stem: an edge down it
        n = 4 if stage == "young" else 6
        for i in range(n):
            u = 0.12 + 0.76 * i / (n - 1); x, y = q.pt(u); sd = -1 if i % 2 else 1
            with a.on(LEAF):
                own(a, "broad-bean", x, y, -90 + sd * (56 + (40 if dry else 0)), 30 * (1 - 0.28 * u), fill=lc if dry else None, ink="bark" if dry else None)
            with a.on(BLOOM):
                if stage == "flower" and i >= 2:   # 2 to 4 flowers close to the stem, all facing one way
                    for k in range(3 if i < 5 else 2):
                        peaflower(a, x - sd * 1.6, y - 1 - k * 4.2, -sd, 0.68, "white", "white", "white", "leaf", blotch="dark", droop=20 + k * 6)
                if stage == "crop" and 1 <= i <= 4:   # thick green pods, held up at first, then leaning
                    pod(a, x - sd * 1, y, -90 - sd * (30 + 22 * (i % 2)), 17, 5.2, "leaf", bumps=4, beak=False)
                if dry and 1 <= i <= 4:   # ripe pods: black, leathery, hanging
                    pod(a, x - sd * 1, y, 90 + sd * 24, 15, 4.6, "dark", bumps=4, beak=False)
        with a.on(LEAF):
            for g in (-112, -68):
                own(a, "broad-bean", 50, top, g, 11, fill=lc if dry else None, ink="bark" if dry else None)
        return a
    return draw


def bb_seed(a, x, y):
    """A broad bean: flat and oblong, about one and a half times as long as
    wide, a long dark scar (the hilum) across one end."""
    a.polar(x, y, lambda h: 1 - 0.05 * math.cos(2 * h) ** 2, 10.5, 15.5, 0, "seed", 1.1)
    a.shape(path([(x + 10.5 * 0.55 * math.cos(h), y - 15.5 * 0.55 * math.sin(h) * 0.4 - 13) for h in [math.pi * i / 20 for i in range(21)]]
                 + [(x + 10.5 * 0.55 * math.cos(h), y - 13 + 1.4) for h in [math.pi * i / 20 for i in range(20, -1, -1)]]), "dark", 0.7)
    a.line(f"M{f(x - 6)},{f(y - 3)} Q{f(x - 7.5)},{f(y + 4)} {f(x - 5)},{f(y + 10)}", 0.6, 0.35)
    a.line(f"M{f(x + 3)},{f(y + 12)} Q{f(x + 6)},{f(y + 8)} {f(x + 7)},{f(y + 2)}", 0.5, 0.3)


STAGE["broad-bean"] = {
    "seed": sown(bb_seed),
    "seedling": hypogeal("broad-bean", "seed", 30, 22),
    "young": broad_bean("young"), "flower": broad_bean("flower"), "crop": broad_bean("crop"), "seedhead": broad_bean("seedhead"),
}


# --- French bean: a dwarf bush of three-leaflet leaves on long stalks
def french_bean(stage):
    def draw():
        a = Art(); soil(a, 88)
        dry = stage == "seedhead"
        fc = pal("french-bean", "flower", "white"); frc = pal("french-bean", "fruit", "leaf")
        k = 0.72 if stage == "young" else 1.0
        stems = [(-0.5, 0.75), (0.5, 0.8), (0, 1.0)]
        nodes = []
        for lean, hh in stems:
            H = 50 * hh * k; e = (50 + lean * 26 * k, 88 - H)
            q = a.ribbon((50, 88), (50 + lean * 8, 88 - H * 0.6), e, 2.2, 1.4, "straw" if dry else "leaf", lw=0.75)
            nodes += [(q.pt(0.45), lean), (e, lean)]
        with a.on(LEAF):
            for j, ((x, y), lean) in enumerate(nodes):
                sd = 1 if (lean > 0 or (lean == 0 and j % 2)) else -1
                g = -90 + sd * (30 + 30 * (j % 2)) + (50 if dry else 0) * sd
                own(a, "french-bean", x, y, g, 30 * k * (0.9 if j % 2 == 0 else 1), fill="straw" if dry else None, ink="bark" if dry else None)
        with a.on(BLOOM):
            for j, ((x, y), lean) in enumerate(nodes):
                sd = -1 if lean > 0 else 1
                if j % 2 == 1 and stage == "young":
                    continue
                if stage == "flower" and j in (0, 2, 4):
                    for m in range(2):
                        peaflower(a, x + sd * (2 + m * 3), y - 1 + m * 3, sd, 0.42, fc, coil=True, droop=30)
                if stage in ("crop", "seedhead") and j in (0, 2, 4, 5):
                    for m in range(3 if not dry else 2):   # slim pods hanging in a bunch, a thin curved beak at the end
                        p = (x + sd * (1 + m * 1.6), y + 1)
                        pod(a, *p, 90 - sd * ((8 + 10 * m) if not dry else (28 + 14 * m)), 18, 2.8 if not dry else 3.4, "straw" if dry else frc,
                            bumps=5 if dry else 0, beak=True, beakL=0.2, lw=0.8)
        return a
    return draw


STAGE["french-bean"] = {
    "seed": sown(pulse(["white", "bark", "dark"], n=3, R=10, kidney=0.45, flat=0.6, scar="white", mottle=None,
                       spots=[(-11, -3, 1.0), (9, 5, 1.0), (-2, 13, 0.9)])),
    "seedling": epigeal("french-bean", (9, 0.8), "heart", 11, thick=True),
    "young": french_bean("young"), "flower": french_bean("flower"), "crop": french_bean("crop"), "seedhead": french_bean("seedhead"),
}


# --- alfalfa: an upright leafy clump of many stems from a woody crown
def spiral_pod(a, x, y, r, col):
    """Alfalfa's pod: coiled flat into a spiral of two or three turns, a hole
    in the middle, like a tiny snail shell."""
    a.oval(x, y, r, r * 0.9, 0, col, 0.7)
    pts = [(x + r * (0.92 - 0.62 * j / 60) * math.cos(j * 0.27), y + r * 0.9 * (0.92 - 0.62 * j / 60) * math.sin(j * 0.27)) for j in range(61)]
    a.line(opath(pts), 0.5, 0.9, "straw")
    a.oval(x, y, r * 0.22, r * 0.2, 0, "soil", 0.4)


def clump(slug, stage, nstem=5, H=60, L=16, head=None, seed=None, dormant=None, spread=26, tops=True):
    """A clump of upright leafy stems from one crown, a leaf at each joint
    (the kind's own), and a flower head (or seed head) at the stem tips."""
    def draw():
        a = Art(); soil(a, 88)
        if stage == "dormant":
            dormant(a); return a
        dry = stage == "seedhead"
        k = 0.65 if stage == "young" else 1.0
        tipsl = []
        for j in range(nstem):
            u = j / (nstem - 1) - 0.5; hh = H * k * (1 - 0.3 * abs(u) * 2)
            e = (50 + u * spread * 2 * k, 88 - hh)
            q = a.stem((50 + u * 4, 88), (50 + u * spread * 0.7, 88 - hh * 0.6), e, 1.0, col="line" if not dry else "bark")
            tipsl.append((q, u))
            with a.on(LEAF):
                for i in range(3):
                    v = 0.3 + 0.25 * i; x, y = q.pt(v); sd = -1 if (i + j) % 2 else 1
                    own(a, slug, x, y, -90 + sd * 60, L * (1 - 0.2 * v), fill="straw" if dry else None, ink="bark" if dry else None)
        with a.on(BLOOM):
            for q, u in tipsl:
                x, y = q.pt(1)
                if stage == "flower" and head:
                    head(a, x, y, u)
                elif dry and seed:
                    seed(a, x, y, u)
                elif tops:
                    own(a, slug, x, y, -90 + u * 40, L * 0.6, fill="straw" if dry else None)
        return a
    return draw


def _alf_head(a, x, y, u):
    fc = pal("alfalfa", "flower", "veg_lucerne")
    a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y - 3)}", 0.7, 0.85)
    for r in range(3):   # a short dense head held just above the leaves
        for face in (-1, 1):
            peaflower(a, x + face * 0.4, y - 3 - r * 2.6, face, 0.38, fc, fc, fc, "leaf", droop=-10 + 20 * (r % 2))


def _alf_seed(a, x, y, u):
    for r in range(2):
        spiral_pod(a, x + (r % 2 - 0.5) * 5, y - r * 6, 3.4, pal("alfalfa", "fruit", "dark"))


def _alf_dorm(a):
    a.polar(50, 88, lambda h: 1 + 0.08 * math.cos(5 * h), 9, 4, 0, "bark", 0.9)
    for dx, hh in ((-6, 9), (-2, 13), (3, 11), (7, 7)):
        a.ribbon((50 + dx, 87), (50 + dx * 1.1, 87 - hh / 2), (50 + dx * 1.2, 87 - hh), 1.4, 1.0, "bark", lw=0.7)
    a.roots(50, 90, 3, 9, 30)


STAGE["alfalfa"] = {
    "seed": sown(pulse("seed", n=5, R=5.2, kidney=0.42, flat=0.66)),
    "seedling": epigeal("alfalfa", (8, 0.55), "round", 7),
    "young": clump("alfalfa", "young", L=17), "flower": clump("alfalfa", "flower", L=16, head=_alf_head),
    "seedhead": clump("alfalfa", "seedhead", L=15, seed=_alf_seed), "dormant": clump("alfalfa", "dormant", dormant=_alf_dorm),
}


# --- white clover: creeping stems rooting at the joints; leaves and heads stand up on long stalks
def clover_plant(stage):
    def draw():
        a = Art(); soil(a, 86)
        fc = pal("clover", "flower", "white")
        k = 0.7 if stage in ("young", "dormant") else 1.0
        q = a.ribbon((14, 85.5), (50, 83), (86, 85.5), 1.6, 1.4, "leaf", lw=0.7)
        for i, u in enumerate((0.12, 0.3, 0.5, 0.7, 0.88)):
            x, y = q.pt(u)
            a.roots(x, y + 0.6, 2, 4, 50)
            with a.on(LEAF):
                for sd in (-1, 1):
                    h = (16 + 8 * ((i + (sd > 0)) % 2)) * k
                    own(a, "clover", x, y, -90 + sd * (14 + 6 * i % 3), h * 1.5 if stage != "dormant" else h * 1.1)
            if stage in ("flower", "seedhead") and i in (1, 3):
                with a.on(BLOOM):
                    e = (x + 2, y - 40)
                    a.line(f"M{f(x)},{f(y)} Q{f(x + 3)},{f(y - 20)} {P(e)}", 0.9, 0.85)
                    a.oval(e[0], e[1] - 4, 4.6, 4.4, 0, "pale" if stage == "flower" else "bark", 0.6)
                    head_ball(a, e[0], e[1] - 4, 6.5, fc if stage == "flower" else "bark", "bark", droop_rows=2 if stage == "flower" else 5, rows=5, tip=None)
        return a
    return draw


STAGE["clover"] = {
    "seed": sown(pulse(["amber", "bark"], n=5, R=5.2, heart=0.5, flat=0.9)),
    "seedling": epigeal("clover", (7, 0.6), "round", 7),
    "young": clover_plant("young"), "flower": clover_plant("flower"), "seedhead": clover_plant("seedhead"), "dormant": clover_plant("dormant"),
}


# --- red clover: an upright hairy clump; the heads sit straight on a pair of leaves
def _rc_head(a, x, y, u, dry=False):
    fc = pal("red-clover", "flower", "mauve")
    for sg in (-1, 1):
        own(a, "red-clover", x, y + 1, -90 + sg * 72, 10, fill="straw" if dry else None, ink="bark" if dry else None)
    a.oval(x, y - 4, 5.6, 5.4, 0, "bark" if dry else fc, 0.6)
    head_ball(a, x, y - 4, 7, "bark" if dry else fc, "bark", droop_rows=0 if not dry else 5, rows=5, tip=None)


def _rc_dorm(a):
    for g in (-170, -10, -140, -40, -110, -70):
        own(a, "red-clover", 50, 87, g, 22)


STAGE["red-clover"] = {
    "seed": sown(pulse(["amber", "plum"], n=5, R=5.2, kidney=0.42, flat=0.66)),
    "seedling": epigeal("red-clover", (7, 0.6), "round", 7),
    "young": clump("red-clover", "young", nstem=4, H=50, L=20),
    "flower": clump("red-clover", "flower", nstem=4, H=50, L=19, head=_rc_head),
    "seedhead": clump("red-clover", "seedhead", nstem=4, H=50, L=18, seed=lambda a, x, y, u: _rc_head(a, x, y, u, True)),
    "dormant": clump("red-clover", "dormant", dormant=_rc_dorm),
}


# --- bird's-foot trefoil: low and sprawling, the tips turning up; flower crowns on long stalks
def birdsfoot(stage):
    def draw():
        a = Art(); soil(a, 86)
        fc = pal("common-bird-s-foot-trefoil", "flower", "sun"); cen = pal("common-bird-s-foot-trefoil", "centre", "carrot")
        frc = pal("common-bird-s-foot-trefoil", "fruit", "dark")
        if stage == "dormant":   # a few short low shoots at a woody base, reddened
            a.polar(50, 86, lambda h: 1, 6, 2.6, 0, "bark", 0.8)
            for g in (-160, -20, -120, -60):
                e = T(50, 85, g)(9); a.line(f"M50,85 L{P(e)}", 0.8, 0.85, "rust")
                own(a, "common-bird-s-foot-trefoil", *e, g + 30, 9, fill="rust")
            return a
        k = 0.7 if stage == "young" else 1.0
        for sgn in (-1, 1):
            for j, (reach, lift) in enumerate(((40, 10), (28, 18))):
                q = Quad((50, 85), (50 + sgn * reach * 0.6 * k, 85 - 2), (50 + sgn * reach * k, 85 - lift * k))
                a.line(q.d(), 0.9, 0.85)
                with a.on(LEAF):
                    for u in (0.3, 0.55, 0.8):
                        x, y = q.pt(u); own(a, "common-bird-s-foot-trefoil", x, y, -90 + sgn * (30 - 20 * j), 15 * k)
                if stage in ("flower", "seedhead") and j == 0:
                    with a.on(BLOOM):
                        x, y = q.pt(0.65); e = (x - sgn * 2, y - 26)
                        a.line(f"M{f(x)},{f(y)} Q{f(x)},{f(y - 14)} {P(e)}", 0.8, 0.85)
                        if stage == "flower":
                            for g, face in ((-160, -1), (-20, 1), (-120, -1), (-60, 1)):
                                p = T(*e, g)(2.6); peaflower(a, *p, face, 0.6, fc, droop=-25, back=cen if g in (-120, -20) else None)
                            blade(a, *e, -90, 3.4, 1.8, cen, prof(0.5), veins=0, lw=0.5, petal=True)
                        else:   # the pods spread from the stalk top like the toes of a bird's foot
                            for g in (-150, -115, -65, -30):
                                pod(a, *e, g, 9, 1.3, frc, bumps=0, beak=False, lw=0.5)
        return a
    return draw


STAGE["common-bird-s-foot-trefoil"] = {
    "seed": sown(pulse("bark", n=5, R=4.4)),
    "seedling": epigeal("common-bird-s-foot-trefoil", (7, 0.6), "own", 12),
    "young": birdsfoot("young"), "flower": birdsfoot("flower"), "seedhead": birdsfoot("seedhead"), "dormant": birdsfoot("dormant"),
}


# --- lupin: a mound of long-stalked wheel leaves; tall dense spikes above
def lupin_plant(stage):
    """A mound of separate wheel-shaped leaves, each on its own long stalk;
    tall dense spikes standing above them."""
    def draw():
        a = Art(); soil(a, 88)
        fc = pal("lupin", "flower", "veg_lupin"); cen = pal("lupin", "centre", "white"); frc = pal("lupin", "fruit", "dark")
        if stage == "dormant":   # a crown at the soil; little or nothing green
            a.polar(50, 88, lambda h: 1 + 0.08 * math.cos(6 * h), 9, 3.6, 0, "bark", 0.9)
            for dx in (-5, 0, 5):   # cut stubs of the old stems
                a.ribbon((50 + dx, 87), (50 + dx, 85), (50 + dx, 82), 2.0, 1.8, "straw", lw=0.7)
            a.oval(52.5, 85.4, 1.3, 1.8, 10, "unripe", 0.5)   # one small new bud
            return a
        k = 0.8 if stage == "young" else 1.0
        dry = stage == "seedhead"
        if stage in ("flower", "seedhead"):
            for x0, top in ((36, 16), (64, 20), (50, 8)):
                with a.on(BLOOM):
                    a.ribbon((50, 76), ((50 + x0) / 2, 50), (x0, top), 2.0, 1.2, "leaf" if not dry else "straw", lw=0.75)
                    q = Quad((50, 76), ((50 + x0) / 2, 50), (x0, top))
                    for r in range(9):
                        u = 0.42 + 0.58 * r / 8; x, y = q.pt(u); s_ = 0.8 - 0.03 * r
                        if dry:   # hairy pods standing out from the spike, black below, some twisted open
                            if r % 2 == 0 and r < 8:
                                for face in (-1, 1):
                                    pod(a, x + face * 0.8, y, -90 + face * 48, 7.5, 2.4, frc if r < 5 else "unripe", bumps=3, hairy=True,
                                        beak=False, lw=0.6, twist=(r == 2 and face > 0))
                            continue
                        if r >= 7:
                            a.oval(x, y, 1.6, 2.2, 0, fc if r == 7 else "pale", 0.5); continue
                        for face in (-1, 1):
                            mini_pea(a, x + face * 0.8, y, face, s_, fc, fc, droop=8, mark=cen)
        with a.on(LEAF):
            for g, L in ((-158, 44), (-22, 44), (-124, 54), (-56, 54), (-90, 46)):
                own(a, "lupin", 50, 88, g if stage == "young" else g + (8 if g < -90 else -8 if g > -90 else 0), L * k,
                    fill="pear" if dry else None, lw=0.6, ink="bark" if dry else None, S=62, ll=30)
        return a
    return draw


STAGE["lupin"] = {
    "seed": sown(pulse(["seed", "bark"], n=3, R=8, flat=0.8, mottle="bark")),
    "seedling": epigeal("lupin", (10, 0.6), "own", 18, thick=True),
    "young": lupin_plant("young"), "flower": lupin_plant("flower"), "seedhead": lupin_plant("seedhead"), "dormant": lupin_plant("dormant"),
}


# ================================================================ SWEETCORN
def corn_blade(a, p0, c, p1, W, fill, wav=True, n=40, veins=True, lw=1.0):
    """A long grass blade along a curve: widest near the middle, crinkled at
    the edge, a pale midrib and fine parallel veins."""
    q = Quad(p0, c, p1); L, R, mid = [], [], []
    for i in range(n + 1):
        u = i / n; x, y = q.pt(u); g = math.radians(q.ang(u) + 90)
        w = W / 2 * (0.55 + 0.45 * math.sin(math.pi * min(1, u * 1.15)) ** 0.6) * (1 - max(0, (u - 0.8) / 0.2) ** 1.4)
        e = (1 + 0.07 * math.sin(u * 60)) if wav and 0.1 < u < 0.9 else 1
        L.append((x + w * e * math.cos(g), y + w * e * math.sin(g))); R.append((x - w * math.cos(g), y - w * math.sin(g))); mid.append((x, y, g, w))
    a.shape(path(L + R[::-1]), fill, lw)
    a.shape(path(L + [(m[0], m[1]) for m in mid[::-1]]), "shade", 0, fa=0.1)
    if veins:
        for o in (0.45, -0.45, 0.78, -0.78):
            a.line(opath([(m[0] + o * m[3] * math.cos(m[2]), m[1] + o * m[3] * math.sin(m[2])) for m in mid[2:-4:3]]), 0.35, 0.28)
    a.line(opath([(m[0], m[1]) for m in mid[1:-5]]), max(0.6, W * 0.12), 0.5, "pale")
    return q


def leaf_corn(a, sp):
    """Sweetcorn: a piece of the jointed stem, the leaf sheath wrapping it,
    and the long blade arching out, its pale midrib and parallel veins."""
    fill = sp["fill"]
    a.ribbon((30, 99), (30, 60), (31, 20), 5.0, 4.4, fill, lw=0.9)
    a.line("M27.6,62 Q30.5,64 33.4,62", 0.8, 0.7)   # the joint
    a.ribbon((30, 62), (31, 52), (32, 42), 6.4, 5.6, fill, lw=0.8)   # the sheath, a little wider than the stem
    a.line("M32.6,62 Q34,52 33,42", 0.45, 0.4)
    corn_blade(a, (32, 43), (56, 2), (97, 62), 10, fill, n=60)
    return a


def corn_cob(a, x, y, ang, L, open_=False, silk="pear", husk="leaf"):
    """A cob in its leafy husks, a tuft of silks at its tip. open_: one husk
    pulled back to show straight rows of yellow kernels."""
    t = T(x, y, ang); W = L * 0.36
    hw = lambda u: W / 2 * math.sin(math.pi * min(1, 0.15 + u * 0.95)) ** 0.6
    us = [i / 24 for i in range(25)]
    if open_:
        a.shape(path([t(L * u, hw(u) * 0.86) for u in us] + [t(L * u, -hw(u) * 0.86) for u in us[::-1]]), "sun", 0.8)
        for r in range(-2, 3):
            for j in range(7):
                u = 0.14 + 0.8 * j / 7; p = t(L * u, r * hw(u) * 0.3); a.oval(p[0], p[1], L * 0.05, hw(u) * 0.14, ang, "primrose", 0.45)
        a.shape(path([t(L * u, -hw(u) * 0.55) for u in us] + [t(L * u, -hw(u) * 1.05) for u in us[::-1]]), husk, 0.8)
        a.shape(path([t(L * 0.1, hw(0.1)), t(L * 0.4, hw(0.4) * 1.5), t(L * 0.62, hw(0.62) * 1.9), t(L * 0.3, hw(0.3) * 0.9)]), husk, 0.8)
    else:
        for o in (1, -1, 0):
            a.shape(path([t(L * u, o * hw(u) * 0.3 + hw(u) * (0.75 if o >= 0 else -0.75) * (1 if o else 0) + (hw(u) if o == 0 else 0)) for u in us]
                         + [t(L * u, o * hw(u) * 0.3 - (hw(u) if o == 0 else 0)) for u in us[::-1]]), husk, 0.8)
        a.shape(path([t(L * u, hw(u)) for u in us] + [t(L * u, -hw(u)) for u in us[::-1]]), husk, 0.9)
        for o in (-0.4, 0.2, 0.6):
            a.line(opath([t(L * u, o * hw(u)) for u in us[2:-2:4]]), 0.45, 0.4)
    e = t(L * 1.0)
    for k in range(7):   # the silks
        g = ang + (k - 3) * 9 + 30; m = T(*e, g)(L * 0.2); d = T(*e, g + 25)(L * 0.38)
        a.line(f"M{P(e)} Q{P(m)} {P(d)}", 0.55, 0.9, silk)


def tassel(a, x, y, s=1.0, col="straw"):
    """The male tassel: spreading branches of small spikelets, stamens dangling."""
    a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y - 14 * s)}", 1.0, 0.85)
    for j, (g, L) in enumerate(((-150, 12), (-30, 12), (-125, 10), (-55, 10), (-90, 4))):
        p0 = (x, y - j * 2.2 * s); e = T(*p0, g)(L * s)
        q = Quad(p0, T(*p0, g - 12 * (1 if g < -90 else -1))(L * s * 0.5), (e[0], e[1] + 3 * s))
        a.line(q.d(), 0.6, 0.85)
        for u in (0.35, 0.6, 0.85):
            p = q.pt(u); a.oval(p[0], p[1] - 0.6 * s, 0.6 * s, 1.1 * s, 0, col, 0.4)
            a.line(f"M{f(p[0])},{f(p[1] + 0.5 * s)} L{f(p[0])},{f(p[1] + 1.8 * s)}", 0.35, 0.6)
            a.oval(p[0], p[1] + 2.4 * s, 0.4 * s, 0.7 * s, 0, "amber", 0.3)
    for u in range(5):
        p = (x, y - 14 * s + u * 2.6 * s); a.oval(p[0] + (u % 2 - 0.5) * 1.2 * s, p[1], 0.7 * s, 1.2 * s, 0, col, 0.4)


def fl_corn(a, sp):
    """Sweetcorn's two kinds of flower: the branched male tassel at the top,
    and a cob below wrapped in husks with its silks hanging from the tip."""
    a.ribbon((34, 99), (35, 60), (36, 40), 4.2, 3.4, "leaf", lw=0.9)
    a.line("M32.4,80 Q35.4,82 38.4,80", 0.7, 0.7)
    tassel(a, 36, 40, 2.3, sp["fc"])
    corn_blade(a, (36, 82), (20, 70), (6, 82), 6, "leaf", veins=False)
    corn_cob(a, 38, 80, -40, 34, silk=sp.get("cen", "pear"))
    return a


def corn_plant(stage):
    def draw():
        a = Art(); soil(a, 88)
        lc = pal("sweetcorn", "leaf", "leaf"); fc = pal("sweetcorn", "flower", "straw")
        top = 30 if stage == "young" else 18
        q = a.ribbon((50, 88), (50.5, 60), (50, top), 3.8, 2.6, lc, lw=0.85)
        for u in (0.25, 0.48, 0.68, 0.85):   # the joints, like bamboo
            x, y = q.pt(u); a.line(f"M{f(x - 1.8)},{f(y)} Q{f(x)},{f(y + 0.8)} {f(x + 1.8)},{f(y)}", 0.6, 0.6)
        a.line("M48.6,86 L46,89 M51.4,86 L54,89", 0.8, 0.8)   # prop roots
        n = 5 if stage == "young" else 6
        with a.on(LEAF):
            for i in range(n):
                u = 0.12 + 0.8 * i / (n - 1); x, y = q.pt(u); sd = -1 if i % 2 else 1
                L = (40 if stage == "young" else 44) * (1 - 0.3 * u)
                corn_blade(a, (x, y), (x + sd * L * 0.45, y - L * 0.6), (x + sd * L * 0.95, y - L * 0.02), 3.8, lc, veins=False, lw=0.75)
        with a.on(BLOOM):
            if stage in ("flower", "crop"):
                tassel(a, 50, top + 1, 1.2, fc if stage == "flower" else "bark")
                for u, sd, op in ((0.5, 1, False), (0.66, -1, stage == "crop")):
                    x, y = q.pt(u)
                    corn_cob(a, x + sd * 1.2, y, -90 + sd * 30, 21 if op else 19, open_=op, silk=pal("sweetcorn", "centre", "pear") if stage == "flower" else "bark")
        return a
    return draw


def corn_kernel(a, x, y):
    """A sweetcorn seed: a flattened wedge, shrivelled and wrinkled."""
    a.shape(f"M{x},{y + 12} C{x - 5},{y + 8} {x - 11},{y - 2} {x - 9},{y - 9} C{x - 5},{y - 13} {x + 5},{y - 13} {x + 9},{y - 9} C{x + 11},{y - 2} {x + 5},{y + 8} {x},{y + 12} Z", "sun")
    for d in (f"M{x - 6},{y - 6} Q{x - 2},{y - 2} {x - 4},{y + 4}", f"M{x + 5},{y - 7} Q{x + 2},{y - 1} {x + 4},{y + 5}", f"M{x - 2},{y - 9} Q{x + 1},{y - 6} {x + 2},{y - 10}"):
        a.line(d, 0.6, 0.45)
    a.oval(x, y + 6, 2.2, 3.4, 0, "primrose", 0.5)


def corn_seedling():
    a = Art(); soil(a, 72); roots(a, 50, 72, 4, 11, 70)
    a.ribbon((50, 72), (49.6, 64), (50, 58), 2.4, 1.8, "pale", lw=0.8)   # the rolled spear
    corn_blade(a, (50, 60), (51, 48), (42, 40), 4.4, "leaf", wav=False, veins=False, lw=0.8)
    corn_blade(a, (50, 58), (52, 52), (60, 50), 3.4, "leaf", wav=False, veins=False, lw=0.8)
    return a


LEAF_DRAW["veg_corn"] = leaf_corn
BLOOM_DRAW["veg_corn"] = fl_corn
LEAFX["sweetcorn"] = dict(kind="veg_corn")
BLOOMX["sweetcorn"] = dict(kind="veg_corn")
STAGE["sweetcorn"] = {"seed": sown(corn_kernel), "seedling": corn_seedling, "young": corn_plant("young"),
                      "flower": corn_plant("flower"), "crop": corn_plant("crop")}


# ================================================================ GLOBE ARTICHOKE
def cut_margin(n=7, cut=0.86, tn=3, td=0.3):
    """A leaf cut nearly to the midrib into n lobes down each side, each lobe
    itself with tn coarse teeth."""
    def fn(u, side):
        if u > 0.93:
            return 1.0
        s = (u * n + (0 if side > 0 else 0.5)) % 1
        lobe = math.sin(math.pi * s) ** 1.4
        tooth = 1 - td * ((s * tn) % 1) ** 1.5
        return (1 - cut) + cut * lobe * tooth
    return fn


def artichoke_blade(a, x, y, ang, L, fill, lw=1.0, detail=True):
    pr = prof(0.5, "taper", "point", 1.2, 0.9)
    blade(a, x, y, ang, L, L * 0.5, fill, pr, cut_margin(), veins=0, lw=lw, shade=0.1 if detail else 0, mid=0)
    t = T(x, y, ang)
    a.ribbon(t(0), t(L * 0.5, 0), t(L * 0.92), max(1.0, L * 0.05), 0.4, "white" if detail else "pale", lw=0.5 if detail else 0.35)   # the thick pale midrib
    if detail:
        for k in range(7):
            u = (k + 0.5) / 7 * 0.9
            for sg in (1, -1):
                a.line(f"M{P(t(L * u, 0))} L{P(t(L * (u + 0.04), sg * L * 0.1 * pr(u)))}", 0.4, 0.4)


def leaf_artichoke(a, sp):
    t = T(*BASE, ANG)
    a.ribbon(BASE, t(6, 1), t(12), 5.4, 4.0, sp["fill"], lw=0.9)
    artichoke_blade(a, *t(10), ANG, 92, sp["fill"])
    return a


def art_head(a, cx, cy, R, stage, fc="veg_artichoke", bract="sage"):
    """An artichoke head: a globe of thick overlapping bracts. "crop": a tight
    bud. "flower": a dome of thread-like florets bursting out of the top.
    "seedhead": dry and brown, white silky plumes coming out."""
    if stage == "flower":
        for i in range(30):
            g = -170 + 160 * i / 29; L = R * (0.75 + 0.2 * math.sin(i * 1.7))
            p0 = (cx + (i - 15) * R * 0.02, cy - R * 0.55); e = T(*p0, g)(L)
            a.line(f"M{P(p0)} L{P(e)}", max(0.9, R * 0.1), 0.9, "line")
            a.line(f"M{P(p0)} L{P(e)}", max(0.5, R * 0.06), 1.0, fc)
    if stage == "seedhead":
        for i in range(13):
            g = -165 + 150 * i / 12; e = T(cx, cy - R * 0.5, g)(R * 1.15)
            a.line(f"M{f(cx)},{f(cy - R * 0.5)} L{P(e)}", 0.45, 0.6)
            for sg in (-1, 1):
                a.line(f"M{P(e)} L{P(T(*e, g + sg * 40)(R * 0.25))}", 0.35, 0.5)
            a.dot(e[0], e[1], max(0.4, R * 0.06), "white")
    col = "straw" if stage == "seedhead" else bract
    a.oval(cx, cy, R * 0.8, R * 0.78 if stage == "crop" else R * 0.64, 0, col, 0.9)
    # the bracts: broad, thick, pointed scales lapping over each other like
    # roof tiles, the top rows drawn first so each lower row lies over them
    rows = 5
    for r in range(rows):
        v = r / (rows - 1)                                  # 0 at the top row, 1 at the bottom
        y = cy - R * (0.55 if stage == "crop" else 0.4) + v * R * 1.05
        w = R * 0.8 * math.sqrt(max(0.2, 1 - ((y - cy) / (R * 1.0)) ** 2))
        m = 3 + (r % 2)
        for j in range(m):
            x = cx - w + 2 * w * (j + 0.5) / m
            g = -90 + (x - cx) / R * 35
            L = R * (0.5 - 0.08 * v); W = R * (0.46 - 0.06 * v)
            blade(a, x, y + L * 0.75, g, L, W, col, prof(0.4, "round", "point", 0.5, 0.75), veins=0, lw=0.65, petal=True)
            a.line(f"M{P(T(x, y + L * 0.75, g)(L * 0.2))} L{P(T(x, y + L * 0.75, g)(L * 0.7))}", 0.4, 0.3)
            if stage != "seedhead":   # the purple-tinged notched tip
                tip = T(x, y + L * 0.75, g)(L * 0.9)
                blade(a, *T(x, y + L * 0.75, g)(L * 0.62), g, L * 0.38, W * 0.5, "plum", prof(0.4, "round", "point"), veins=0, lw=0, petal=True)


def fl_artichoke(a, sp):
    a.ribbon((50, 99), (51, 80), (50, 64), 6.0, 5.2, "sage", lw=0.9)
    art_head(a, 50, 54, 24, "flower", sp["fc"])
    return a


def artichoke_plant(stage):
    def draw():
        a = Art(); soil(a, 88)
        lc = pal("globe-artichoke", "leaf", "sage"); fc = pal("globe-artichoke", "flower", "veg_artichoke")
        k = {"young": 0.8, "dormant": 0.6}.get(stage, 1.0)
        tall = stage in ("crop", "flower", "seedhead")
        if tall:
            with a.on(STEM):
                for x0, top, r in ((50, 12, 8.5), (34, 34, 5.5), (68, 30, 6)):
                    q = a.ribbon((50, 86), ((50 + x0) / 2, 60), (x0, top + r), 3.2 if x0 == 50 else 2.2, 2.6 if x0 == 50 else 1.8, lc, lw=0.8)
                    a.line(opath([q.pt(u) for u in (0.1, 0.5, 0.95)]), 0.4, 0.35)
            with a.on(BLOOM):
                for x0, top, r in ((50, 12, 8.5), (34, 34, 5.5), (68, 30, 6)):
                    art_head(a, x0, top + r, r, stage, fc, "sage")
        with a.on(LEAF):
            ends = ([(-158, 40), (-22, 40), (-130, 50), (-50, 50), (-108, 54), (-72, 54)] if stage != "dormant"
                    else [(-165, 30), (-15, 30), (-130, 32), (-50, 32), (-95, 26)])
            for g, L in ends:
                g2 = g + (14 if g < -90 else -14) * (1 if tall else 0)
                artichoke_blade(a, 50, 87, g2, L * k, "straw" if stage == "seedhead" else lc, lw=0.7 if stage != "dormant" else 0.6, detail=False)
        if stage == "dormant":   # old flower stems cut down
            for dx in (-4, 3):
                a.ribbon((50 + dx, 87), (50 + dx, 84), (50 + dx, 80), 2.6, 2.4, "straw", lw=0.8)
        return a
    return draw


def art_seedling():
    a = Art(); soil(a, 72); roots(a, 50, 72, 3, 12, 50)
    a.ribbon((50, 72), (49.5, 64), (50, 57), 2.4, 2.0, "pale", lw=0.8)
    for g in (-162, -18):
        blade(a, 50, 57, g, 14, 8, "leaf", prof(0.5, "round", "round", tp=2.2), veins=1, lw=0.9)
    a.line("M50,57 L50.4,53", 0.9, 0.85)
    blade(a, 50.4, 53, -96, 14, 6.4, "sage", prof(0.5, "taper", "point"), teeth(5, 0.22), veins=3, lw=0.9)
    return a


def art_seed(a, x, y):
    blade(a, x - 12, y + 3, -14, 25, 10, "seed", prof(0.55, "round", "blunt"), veins=0, lw=1.1, petal=True)
    for j in range(10):
        p = T(x - 12, y + 3, -14)(4 + j * 2, (j % 3 - 1) * 2.2); a.dot(p[0], p[1], 0.7, "bark")


LEAF_DRAW["veg_artichoke"] = leaf_artichoke
BLOOM_DRAW["veg_artichoke"] = fl_artichoke
LEAFX["globe-artichoke"] = dict(kind="veg_artichoke")
BLOOMX["globe-artichoke"] = dict(kind="veg_artichoke")
STAGE["globe-artichoke"] = {"seed": sown(art_seed), "seedling": art_seedling, "young": artichoke_plant("young"),
                            "crop": artichoke_plant("crop"), "flower": artichoke_plant("flower"),
                            "seedhead": artichoke_plant("seedhead"), "dormant": artichoke_plant("dormant")}


# ================================================================ ASPARAGUS
def needle_tuft(a, x, y, ang, L, col="leaf", n=5, lw=0.55):
    """A tuft of thread-thin needles (not true leaves: tiny branchlets) from one point."""
    for k in range(n):
        g = ang + (k - (n - 1) / 2) * (100 / max(1, n - 1))
        e = T(x, y, g)(L * (0.8 + 0.2 * (k % 2))); m = T(x, y, g + 8)(L * 0.5)
        d = f"M{f(x)},{f(y)} Q{P(m)} {P(e)}"
        a.line(d, lw * 1.9, 0.85)          # an outline, then the green inside it
        a.line(d, lw * 0.9, 1.0, col)


def fern_branch(a, p0, ang, L, col="leaf", needle=4.0, dense=1.0, linec="line"):
    """One branch of asparagus fern: a fine stem with side branchlets, each
    carrying tufts of needles."""
    e = T(*p0, ang)(L); q = Quad(p0, T(*p0, ang - 6)(L * 0.5), e)
    a.line(q.d(), 0.6, 0.85, linec)
    m = max(3, int(L / 6 * dense))
    for j in range(m):
        u = 0.15 + 0.8 * j / m; x, y = q.pt(u); g = q.ang(u)
        needle_tuft(a, x, y, g + (40 if j % 2 else -40), needle, col, 4)
    needle_tuft(a, *e, ang, needle * 1.1, col, 5)
    return q


def leaf_asp(a, sp):
    """Asparagus 'leaf': a fine branch carrying tufts of 3 to 8 needles."""
    t = T(*BASE, ANG)
    q = fern_branch(a, BASE, ANG, 100, sp["fill"], needle=9, dense=0.9)
    for u, sd in ((0.3, 1), (0.5, -1), (0.7, 1)):
        x, y = q.pt(u); fern_branch(a, (x, y), q.ang(u) + sd * 42, 30 * (1.1 - u * 0.6), sp["fill"], needle=7)
    return a


def asp_bell(a, x, y, L, fc, ang=90):
    """One tiny asparagus flower, hanging from x,y: a narrow bell of six
    tepals, joined, their tips flaring out at the mouth."""
    t = T(x, y, ang); W = L * 0.42
    side = lambda sg: [t(L * u, sg * W / 2 * (0.45 + 0.45 * u ** 1.6)) for u in [i / 12 for i in range(13)]]
    rim = []
    for j in range(7):   # the mouth: tepal tips flaring out, three to each side of the middle one
        v = -1 + 2 * j / 6
        out = 1.0 if j % 2 == 0 else 0.0
        rim.append(t(L + out * L * 0.16 - (1 - out) * L * 0.02, v * W / 2 * (0.95 + 0.4 * out * abs(v))))
    a.shape(path(side(1) + rim[::-1] + side(-1)[::-1]), fc, 0.85)
    for o in (-0.5, 0, 0.5):
        a.line(opath([t(L * u, o * W / 2 * (0.45 + 0.45 * u ** 1.6)) for u in (0.1, 0.5, 0.9)]), 0.4, 0.4)
    a.shape(path(side(1) + [t(L * u, 0) for u in [i / 12 for i in range(12, -1, -1)]]), "shade", 0, fa=0.1)


def fl_asp(a, sp):
    """Tiny narrow bells of six tepals, hanging on thin jointed stalks among the fern."""
    fc = sp["fc"]
    q = fern_branch(a, (14, 96), -58, 100, "leaf", needle=7, dense=0.6)
    for u, sd, s in ((0.3, 1, 1.0), (0.48, -1, 1.0), (0.66, 1, 0.95)):
        x, y = q.pt(u); j = (x + sd * 4, y + 5 * s); e = (x + sd * 6, y + 11 * s)
        a.line(f"M{f(x)},{f(y)} L{P(j)} L{P(e)}", 0.8, 0.85)
        a.oval(j[0], j[1], 0.9, 0.9, 0, "leaf", 0.5)   # the joint in the stalk
        asp_bell(a, *e, 18 * s, fc, 90 - sd * 8)
    return a


def asp_crown(a, x, y, k=1.0, buds=True):
    """The crown: a central knot with budded tips and many long thick fleshy
    roots spread out like a spider."""
    for j in range(9):
        g = 180 * j / 8 + (6 if j % 2 else -6)
        e = T(x, y + 2 * k, g)(26 * k * (0.85 + 0.15 * (j % 2)))
        a.ribbon((x, y + 2 * k), T(x, y + 2 * k, g + 8)(12 * k), e, 2.6 * k, 1.6 * k, "seed", lw=0.7)
    a.polar(x, y, lambda h: 1 + 0.12 * math.cos(5 * h), 9 * k, 4.6 * k, 0, "bark", 0.9)
    if buds:
        for dx in (-5, -1.5, 2, 5.5):
            a.ribbon((x + dx * k, y - 2 * k), (x + dx * k, y - 4 * k), (x + dx * 1.1 * k, y - 7 * k), 2.6 * k, 1.6 * k, "pale", lw=0.6, round_tip=True)
            a.dot(x + dx * 1.1 * k, y - 6.4 * k, 0.6 * k, "plum")


def asp_stage(stage):
    def draw():
        a = Art()
        if stage == "crown":
            a.ground(30, marks=False); asp_crown(a, 50, 50, 1.3); return a
        soil(a, 84)
        if stage == "crop":   # separate green spears straight out of the soil, scale leaves lapped at each tip
            for dx, hh in ((-15, 30), (-4, 46), (8, 38), (18, 22)):
                a.ribbon((50 + dx, 85), (50 + dx, 84 - hh * 0.5), (50 + dx + 0.5, 84 - hh), 4.4, 3.6, "unripe", lw=0.85, round_tip=True)
                for kk in range(6):
                    y = 84 - hh + 2 + kk * (2.6 if kk < 3 else 6); sd = 1 if kk % 2 else -1
                    if y + 2.4 > 81:   # no scale leaves at or below the soil
                        continue
                    blade(a, 50 + dx + sd * 0.9, y + 2.4, -90 + sd * 14, 3.6 if kk < 3 else 2.6, 2.2, "plum" if kk < 3 else "deep", prof(0.4), veins=0, lw=0.5, petal=True)
            return a
        if stage == "dormant":   # cut down to short stubs in the mulch; nothing else above ground
            a.shape("M18,84 Q50,79 82,84 Z", "bark", 0.6, fa=0.5)
            for dx in (-14, -6, 3, 11, 17):
                a.ribbon((50 + dx, 85), (50 + dx, 83), (50 + dx, 80), 2.2, 2.0, "straw", lw=0.7)
                a.line(f"M{f(50 + dx - 1.1)},80 L{f(50 + dx + 1.1)},80", 0.7, 0.8, "bark")
            return a
        # the fern: tall, airy, much branched, a soft green cloud; berries on a female plant
        fernc = "leaf" if stage == "growing" else "pear"
        a.polar(50, 46, lambda h: 1 + 0.08 * math.cos(5 * h) + 0.05 * math.sin(8 * h), 30, 34, 0, fernc, 0, shade=False)
        a.items[-1] = a.items[-1][:6] + (0.45,)   # the cloud: see-through, no outline
        for lean, H in ((-14, 62), (12, 70), (0, 78)):
            q = a.stem((50 + lean * 0.2, 85), (50 + lean * 0.4, 85 - H * 0.5), (50 + lean, 85 - H), 1.3)
            for i in range(6):
                u = 0.3 + 0.12 * i; x, y = q.pt(u); sd = 1 if i % 2 else -1
                br = fern_branch(a, (x, y), -90 + sd * (55 - i * 4), 22 - i * 1.5, fernc, needle=2.8, dense=1.4)
                if stage == "seedhead" and i % 2 == 0:
                    p = br.pt(0.6); a.line(f"M{P(p)} L{f(p[0])},{f(p[1] + 3)}", 0.5, 0.85)
                    a.oval(p[0], p[1] + 4.4, 1.6, 1.6, 0, pal("asparagus", "fruit", "berry"), 0.6)
            needle_tuft(a, *q.pt(1), -90, 3, fernc, 5)
        return a
    return draw


LEAF_DRAW["veg_asp"] = leaf_asp
BLOOM_DRAW["veg_asp"] = fl_asp
LEAFX["asparagus"] = dict(kind="veg_asp")
BLOOMX["asparagus"] = dict(kind="veg_asp")
STAGE["asparagus"] = {st: asp_stage(st) for st in ("crown", "crop", "growing", "seedhead", "dormant")}


# ================================================================ RHUBARB
def rhubarb_g(h):
    """The rhubarb leaf's edge: broadly heart-shaped, a little wider than
    long, rounded lobes either side of an OPEN sinus at the base where the
    stalk joins, the whole edge strongly wavy and crimped."""
    h = math.atan2(math.sin(h), math.cos(h)); ah = abs(h)
    base = (1 + 0.06 * math.cos(h)) * (1 + 0.12 * math.exp(-(h / 0.4) ** 2))
    vw = 0.62                                    # half-width of the open sinus, in radians round the centre
    if ah > math.pi - vw:
        v = (math.pi - ah) / vw                  # 0 at the bottom of the sinus, 1 at its rim
        base *= 0.42 + 0.58 * v ** 0.8
    return base * (1 + 0.045 * math.sin(h * 23) + 0.025 * math.sin(h * 41 + 1))


def rhubarb_blade(a, x, y, ang, R, fill="deep", veinc="berry", lw=1.1, detail=True, k=1.0):
    d = R * rhubarb_g(math.pi) * 1.0
    t = T(x, y, ang)
    hs = [-math.pi + 2 * math.pi * i / 300 for i in range(301)]
    loc = [(d + R * rhubarb_g(h) * math.cos(h), R * 1.08 * rhubarb_g(h) * math.sin(h) * k) for h in hs]
    a.shape(path([t(*p) for p in loc]), fill, lw)
    a.shape(path([t(*p) for h, p in zip(hs, loc) if h >= 0] + [t(0, 0)]), "shade", 0, fa=0.1)
    for v in (0, 0.75, -0.75, 1.5, -1.5, 2.15, -2.15):   # seven thick veins spreading from the top of the stalk
        e = (d + R * rhubarb_g(v) * 0.86 * math.cos(v), R * 1.08 * rhubarb_g(v) * 0.86 * math.sin(v) * k)
        a.line(f"M{P(t(0, 0))} Q{P(t(e[0] * 0.5, e[1] * 0.45))} {P(t(*e))}", (1.1 if v == 0 else 0.8) if detail else 0.6, 0.7, veinc)
        if detail:
            for u in (0.4, 0.65):   # side veins, and the puckering between them
                b = (e[0] * u, e[1] * u); va = math.atan2(e[1], e[0])
                for sg in (1, -1):
                    kk = R * 0.2; sa = va + sg * 0.8
                    a.line(f"M{P(t(*b))} Q{P(t(b[0] + kk * 0.6 * math.cos(sa + sg * 0.3), b[1] + kk * 0.6 * math.sin(sa + sg * 0.3)))} {P(t(b[0] + kk * math.cos(sa), b[1] + kk * math.sin(sa)))}", 0.4, 0.3)


def leaf_rhubarb(a, sp):
    t = T(*BASE, ANG)
    A = t(30)
    a.ribbon(BASE, t(15, 1), A, 6.0, 4.4, sp.get("stalkc", "berry"), lw=0.9)   # thick fleshy red stalk, grooved on top
    a.line(opath([t(2, 0.6), t(15, 0.6), t(29, 0.4)]), 0.5, 0.45)
    rhubarb_blade(a, *A, ANG, 34, sp["fill"], "berry")
    return a


def fl_rhubarb(a, sp):
    """A big branched plume of tiny creamy flowers on a stout stem."""
    fc = sp["fc"]
    q = Quad((50, 99), (49, 60), (50, 10))
    a.ribbon(q.p0, q.c, q.p1, 4.0, 1.6, "leaf", lw=0.85)
    for u in (0.25, 0.45):   # papery sheaths at the joints
        x, y = q.pt(u); blade(a, x, y + 1, -90, 6, 5, "straw", prof(0.4), veins=0, lw=0.6, petal=True)
    for j in range(9):
        u = 0.3 + 0.64 * j / 8; x, y = q.pt(u); sd = 1 if j % 2 else -1; L = 30 * (1 - 0.65 * u)
        bq = Quad((x, y), (x + sd * L * 0.5, y - 2), (x + sd * L, y - L * 0.6))
        a.line(bq.d(), 0.8, 0.85)
        for v in [0.25 + 0.75 * i / 6 for i in range(7)]:
            p = bq.pt(v)
            for kk in range(3):
                g = kk * 120 + v * 90; e = T(*p, g)(1.4)
                a.oval(e[0], e[1], 1.15, 1.15, 0, fc, 0.45)
    for k in range(6):
        x, y = q.pt(0.94 + 0.01 * k); a.oval(x + (k % 2 - 0.5) * 2.4, y, 1.2, 1.2, 0, fc, 0.45)
    return a


def rh_crown(a, x, y, k=1.0, buds=True):
    """A knobbly woody crown at the soil with fat rounded pink-red buds."""
    a.polar(x, y + 4 * k, lambda h: 1 + 0.09 * math.cos(5 * h) + 0.05 * math.sin(9 * h), 15 * k, 6 * k, 0, "bark", 0.9)
    a.roots(x, y + 9 * k, 6, 9 * k, 130)
    if buds:
        for dx, s in ((-7, 0.9), (0, 1.15), (7, 0.85)):
            a.oval(x + dx * k, y - 2 * k * s, 4.2 * k * s, 5.2 * k * s, dx * 2, "berry", 0.8)
            a.oval(x + dx * k - 1.2 * k * s, y - 3.4 * k * s, 1.2 * k * s, 2.0 * k * s, dx * 2, "pink", 0)
            a.line(f"M{f(x + dx * k - 2 * k * s)},{f(y - 4 * k * s)} Q{f(x + dx * k)},{f(y - 1 * k * s)} {f(x + dx * k + 2 * k * s)},{f(y - 4.6 * k * s)}", 0.5, 0.5, "berry")


def rh_stage(stage):
    def draw():
        a = Art()
        lc = pal("rhubarb", "leaf", "deep"); fc = pal("rhubarb", "flower", "white")
        if stage == "crown":
            a.ground(48, marks=False); rh_crown(a, 50, 47, 1.4); return a
        soil(a, 86)
        if stage == "dormant":   # bare crown, large red buds, no leaves
            rh_crown(a, 50, 84, 1.1); return a
        if stage == "young":     # crumpled leaves unfolding from the crown on short red stalks
            rh_crown(a, 50, 84, 0.8, buds=False)
            for g, L, R in ((-140, 16, 10), (-45, 18, 11), (-95, 22, 9)):
                e = T(50, 82, g)(L)
                a.ribbon((50, 82), T(50, 82, g + 6)(L * 0.5), e, 3.2, 2.6, "berry", lw=0.8)
                rhubarb_blade(a, *e, g, R, lc, "berry", lw=0.9, detail=False, k=0.55)
                for j in range(5):   # the crumpling: the blade still folded and puckered as it opens
                    p = T(*e, g)(R * (0.3 + 0.28 * j)); sg = 1 if j % 2 else -1
                    a.line(f"M{P(T(*p, g + 90)(R * 0.45))} Q{P(T(*p, g + sg * 30)(R * 0.25))} {P(T(*p, g)(0))} Q{P(T(*p, g - sg * 30)(R * 0.25))} {P(T(*p, g - 90)(R * 0.45))}", 0.55, 0.55)
            return a
        rh_crown(a, 50, 84, 0.8, buds=False)
        spots = [(-150, 30, 15), (-30, 30, 15), (-118, 40, 16), (-62, 40, 16), (-90, 36, 15)]
        if stage == "flower":
            spots = [(-162, 22, 11), (-18, 22, 11), (-134, 26, 12), (-46, 26, 12)]
            with a.on(BLOOM):   # a tall stout stem, high above the leaves, a creamy plume on top
                q = a.ribbon((52, 84), (53, 46), (52, 16), 4.6, 3.0, "leaf", lw=0.85)
                for u in (0.3, 0.55):
                    x, y = q.pt(u); blade(a, x, y + 1, -90, 4, 3.6, "straw", prof(0.4), veins=0, lw=0.5, petal=True)
                for j in range(7):
                    u = 0.62 + 0.38 * j / 6; x, y = q.pt(u); sd = 1 if j % 2 else -1; L = 13 * (1.1 - u * 0.6)
                    e = (x + sd * L, y - L * 0.6); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * L * 0.5)},{f(y - 1)} {P(e)}", 0.6, 0.85)
                    for v in (0.4, 0.7, 1.0):
                        p = lerp((x, y), e, v); a.oval(p[0], p[1] - 0.8, 1.5, 1.4, 0, fc, 0.4)
                for k in range(5):
                    a.oval(52 + (k % 2 - 0.5) * 3, 16 - k * 1.8, 1.4, 1.4, 0, fc, 0.4)
        with a.on(STEM):
            for g, L, R in spots:   # thick red stalks straight from the crown
                e = T(50, 82, g)(L)
                a.ribbon((50, 82), T(50, 82, g + 4)(L * 0.5), e, 4.2, 3.2, "berry", lw=0.8)
        with a.on(LEAF):
            for g, L, R in spots:
                e = T(50, 82, g)(L)
                rhubarb_blade(a, *e, -90 + (g + 90) * 0.7, R, lc, "berry", lw=0.9, detail=False)
        return a
    return draw


LEAF_DRAW["veg_rhubarb"] = leaf_rhubarb
BLOOM_DRAW["veg_rhubarb"] = fl_rhubarb
LEAFX["rhubarb"] = dict(kind="veg_rhubarb", stalkc="berry")
BLOOMX["rhubarb"] = dict(kind="veg_rhubarb")
STAGE["rhubarb"] = {st: rh_stage(st) for st in ("crown", "young", "crop", "flower", "dormant")}


# ================================================================ NASTURTIUM
def shield(a, cx, cy, R, fill, ang=-12, lw=1.1, detail=True):
    """A round shield-shaped leaf seen from above: the stalk joins underneath
    near the middle, and the veins run out from there like wheel spokes."""
    a.polar(cx, cy, lambda h: 1 + 0.03 * math.cos(5 * h + 0.5) + 0.025 * math.sin(9 * h), R, R * 0.92, ang, fill, lw)
    hub = (cx - R * 0.08, cy + R * 0.08)
    if detail:
        for k in range(9):
            g = k * 40 + 10; e = T(cx, cy, g)(R * 0.9); e = (e[0], cy + (e[1] - cy) * 0.92)
            m = ((hub[0] + e[0]) / 2 + 0.6, (hub[1] + e[1]) / 2 - 0.6)
            a.line(f"M{P(hub)} Q{P(m)} {P(e)}", 0.55, 0.45)
            for u in (0.55,):   # the veins fork towards the edge
                p = lerp(hub, e, u)
                for sg in (1, -1):
                    a.line(f"M{P(p)} L{P(T(*p, g + sg * 28)(R * 0.22))}", 0.4, 0.3)
    a.dot(hub[0], hub[1], max(0.5, R * 0.04), "pale")
    return hub


def leaf_nasturtium(a, sp):
    hub = (52, 46)
    a.ribbon((20, 98), (30, 76), (hub[0] - 3, hub[1] + 8), 2.6, 2.0, sp["fill"], lw=0.85)   # the stalk, running in under the leaf
    shield(a, 54, 44, 32, sp["fill"])
    return a


def nast_flower(a, x, y, s, fc, cen, ang=0, spur=True):
    """A nasturtium flower, three-quarter face: two broad upper petals with
    dark lines, three lower ones narrowing to fringed claws, a long straight
    spur sticking out behind."""
    if spur:   # the spur, behind the flower
        a.ribbon(T(x, y, ang - 60)(3 * s), T(x, y, ang - 45)(10 * s), T(x, y, ang - 40)(17 * s), 3.2 * s, 1.0 * s, fc, lw=0.7)
    for g in (-125, -55):   # the two upper petals, broad and rounded
        blade(a, x, y, ang + g, 13 * s, 12 * s, fc, prof(0.62, "wedge", "round", 1.0, 2.0), veins=0, lw=0.8, petal=True)
        for o in (-0.25, 0, 0.25):
            a.line(f"M{P(T(x, y, ang + g)(2 * s))} L{P(T(x, y, ang + g + o * 40)(8 * s))}", 0.5 * s + 0.1, 0.9, cen)
    for g in (165, 90, 15):   # the three lower ones, with fringed hairy claws at their base
        blade(a, x, y, ang + g, 12.5 * s, 10 * s, fc, prof(0.7, "taper", "round", 1.6, 2.2), veins=0, lw=0.8, petal=True)
        for j in range(3):
            p = T(x, y, ang + g)(3 * s + j * 0.8 * s)
            for sg in (1, -1):
                a.line(f"M{P(p)} L{P(T(*p, ang + g + sg * 90)(1.6 * s))}", 0.35, 0.7)
    a.shape(path([(x + 2.6 * s * math.cos(h), y + 2.2 * s * math.sin(h)) for h in [2 * math.pi * i / 20 for i in range(20)]]), "shade", 0, fa=0.18)   # the open throat
    for g in (-110, -90, -70):   # stamens
        e = T(x, y, ang + g)(3.4 * s); a.dot(e[0], e[1], 0.45 * s + 0.1, "sun")


def fl_nasturtium(a, sp):
    fc, cen = sp["fc"], sp.get("cen", "berry")
    a.ribbon((30, 99), (36, 74), (44, 58), 2.2, 1.8, "leaf", lw=0.8)
    nast_flower(a, 50, 46, 2.2, fc, cen, ang=0)
    return a


def nast_seed(a, x, y):
    for dx, dy, r in ((-8, 2, 9), (9, -1, 9.5)):
        a.polar(x + dx, y + dy, lambda h: 1 + 0.06 * math.cos(6 * h) + 0.04 * math.sin(11 * h), r, r * 0.9, 0, "seed", 1.0)
        for j in range(4):   # the ridges and wrinkles
            g = j * 45 - 60
            a.line(f"M{f(x + dx)},{f(y + dy)} Q{P(T(x + dx, y + dy, g + 15)(r * 0.5))} {P(T(x + dx, y + dy, g)(r * 0.9))}", 0.6, 0.45)


def nast_stage(stage):
    def draw():
        a = Art()
        lc = pal("nasturtium", "leaf", "leaf"); fc = pal("nasturtium", "flower", "carrot"); cen = pal("nasturtium", "centre", "berry")
        if stage == "seedling":   # no seed leaves: already small round shields on long stalks
            soil(a, 72); roots(a, 50, 72, 3, 12, 50)
            a.ribbon((50, 72), (49, 64), (48, 56), 2.0, 1.6, "pale", lw=0.8)
            for e, R in (((40, 44), 7.0), ((58, 48), 6.0)):
                a.line(f"M48,56 Q{f((48 + e[0]) / 2)},{f(e[1] + 6)} {f(e[0])},{f(e[1] + 2)}", 1.0, 0.85)
                shield(a, e[0], e[1], R, lc, lw=0.9)
            return a
        soil(a, 86)
        k = 0.8 if stage == "young" else 1.0
        spots = [((22, 64), 9), ((40, 52), 10), ((60, 50), 10), ((80, 62), 9), ((30, 76), 7.5), ((68, 72), 8)]
        with a.on(STEM):
            for sg in (-1, 1):   # trailing stems along the ground
                a.ribbon((50, 85), (50 + sg * 20 * k, 82), (50 + sg * 40 * k, 84), 2.2, 1.4, "pale", lw=0.7)
        for i, ((x, y), R) in enumerate(spots):
            x = 50 + (x - 50) * k
            base = (50 + (x - 50) * 0.7, 84)
            with a.on(STEM):
                a.line(f"M{P(base)} Q{f(base[0] + (x - base[0]) * 0.2)},{f(y + 12)} {f(x)},{f(y + 2)}", 1.0, 0.85)
            with a.on(LEAF):
                shield(a, x, y, R * k, lc, lw=0.9)
        if stage == "flower":
            with a.on(BLOOM):
                for (x, y), ang in (((30, 46), -10), ((70, 40), 10), ((50, 66), 0)):
                    a.line(f"M50,84 Q{f((50 + x) / 2)},{f(y + 20)} {f(x)},{f(y + 4)}", 0.9, 0.85)
                    nast_flower(a, x, y, 0.7, fc, cen, ang)
        return a
    return draw


LEAF_DRAW["veg_nasturtium"] = leaf_nasturtium
BLOOM_DRAW["veg_nasturtium"] = fl_nasturtium
LEAFX["nasturtium"] = dict(kind="veg_nasturtium")
BLOOMX["nasturtium"] = dict(kind="veg_nasturtium")
STAGE["nasturtium"] = {"seed": sown(nast_seed), "seedling": nast_stage("seedling"), "young": nast_stage("young"), "flower": nast_stage("flower")}
