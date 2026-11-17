"""Windfall plant drawings, the redraw of 16 November 2026: the FRUIT group.

William, this file holds every change to the drawings of 23 plants: strawberry,
apple, pear, plum, nectarine, fig, olive, Bristol whitebeam, ginkgo, the three
currants and gooseberry, blueberry, honeyberry, rose, hydrangea, Japanese
spiraea, raspberry, blackberry, loganberry, Japanese wineberry, grape and kiwi.
Each was checked, one drawing at a time, against its written description
(Design/Plants/descriptions/<kind>.json) and photographs of the real plant.

Why so much is new here: the old drawings were made from a few shared shapes.
A raspberry got a rose's flat flower, every fruit tree was the same green ball,
and the leaves on the whole plants were a stock leaf, not the plant's own.
So this file draws each plant's own parts, in four steps.

1. LEAVES (close-ups). Three new ways of drawing a leaf:
   - leaflet(): one blade, or one leaflet of a compound leaf. Its outline comes
     from a "profile" (how wide it is along its length: where it is widest,
     whether the base is a wedge or rounded, whether the tip is rounded,
     pointed or drawn out into a long point). Teeth are cut into the edge,
     and can be kept to part of it ("tfrom": strawberry teeth start a third
     of the way up). "lop" makes a leaflet lopsided. Side veins can run
     straight into the teeth, as on a strawberry, or curve forward, as on
     an apple.
   - fruit_lobed: a hand-shaped leaf (fig, currants, gooseberry, grape). It is
     built as several lobes, each a leaflet shape spreading from the top of the
     stalk, joined together: the program sends out rays from the stalk and
     keeps the furthest edge any lobe reaches. Teeth are then cut along the
     joined edge, leaning towards the tip of the lobe they are on.
   - fruit_simple, fruit_trefoil, fruit_pinnate, fruit_palmate and fruit_fan
     put leaflets together into a whole leaf: one blade on a stalk, three
     leaflets (strawberry), leaflets in pairs along a stalk (rose, raspberry),
     leaflets all from one point (blackberry), and the ginkgo's fan.
   The life-stage drawings then use the SAME leaf, drawn small (leaf="own"),
   so the whole plant and the close-up can no longer disagree.

2. FLOWERS (close-ups). New flower shapes where the old ones were wrong:
   the raspberry's small upright petals in a cup of sepals, the rose's rings
   of petals, hanging strings of currant bells, the gooseberry's swept-back
   sepals, honeyberry pairs, kiwi cups facing down, grape flowers dropping
   their caps, olive and spiraea heads, and tree blossom drawn three ways
   (apple clusters, pear clusters with dark anthers, plum and nectarine flowers
   along the bare wood).

3. LIFE STAGES. Drawn by hand here (the STAGE table), because the shared
   templates could not show what the descriptions ask for: spurs and buds on
   bare fruit trees, blossom on bare nectarine shoots, canes tied to wires,
   hanging strings of currants, a grape vine's framework, kiwi stems twined
   round a post, and so on. Each stage function is short and uses a few
   helpers: tree_frame() (trunk and branches), crown() (a head of the kind's
   own leaves), canes(), bush_stems() and the fruit shapes.

4. COLOURS. Four new ones. fruit_rose, a deep rose-pink, is for the
   Japanese spiraea's flowers (the palette's "mauve" drew them lilac). Two
   were asked for in the descriptions: fruit_pearl, the pearly cream of
   white currants, and fruit_dusk, the dusky blue of blueberries and
   honeyberries under their bloom. The last, fruit_greybark, is the smooth
   grey bark of fig, olive, plum and Bristol whitebeam, which the plain
   brown "bark" got wrong.

Everything that could not be put fully right is listed, with why, in the
results file that went with this work.
"""
import math
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10

GOLD = 2.39996
BASE = (20, 92)    # where a close-up leaf's stalk starts, as in leaves_flowers.py
ANG = -52          # the way a close-up leaf points

COLOURS = {
    "fruit_pearl": ("#F3EBC8", "#D9CFA6"),   # white currant berries: translucent pearly cream
    "fruit_dusk": ("#4E6390", "#7389BC"),    # blueberry and honeyberry: dusky blue under a grey-blue bloom
    "fruit_greybark": ("#ABA59A", "#7D786E"), # the smooth grey bark of fig, olive, plum and whitebeam
    "fruit_rose": ("#E07A9C", "#C96A8B"),     # Japanese spiraea flowers: deep rose-pink
}


# ============================================================ outlines
def prof(umax=0.5, base="round", tip="point", bp=None, tp=None):
    """A leaf's width along its length (0 at the base, 1 at the tip), as a
    share of its widest. umax is where it is widest. base: "wedge" (straight
    sides narrowing to the stalk), "round", or "taper" (a long narrow wedge).
    tip: "round", "point" (a plain point), "acum" (drawn out into a long
    point, the sides curving in) or "blunt"."""
    def fn(u):
        if u <= 0 or u >= 1:
            return 0.0
        if u <= umax:
            v = u / umax
            if base == "wedge":   # nearly straight sides, rounding into the widest part with no corner
                return math.sin(math.pi / 2 * v) ** (bp or 1.0)
            if base == "taper":
                return math.sin(math.pi / 2 * v) ** (bp or 1.7)
            return math.sin(math.pi / 2 * v) ** (bp or 0.55)
        v = (u - umax) / (1 - umax)
        if tip == "round":
            return (1 - v ** (tp or 2.2)) ** 0.5
        if tip == "blunt":
            return (1 - v ** (tp or 3.0)) ** 0.42
        if tip == "acum":
            return math.cos(math.pi / 2 * v) ** 0.75 * (1 - v) ** (tp or 0.9)
        if tip == "cusp":     # rounded, then an abrupt short point (kiwi)
            return (1 - v ** 2.4) ** 0.55 * (1 - 0.5 * max(0.0, (v - 0.78) / 0.22) ** 0.7)
        return math.cos(math.pi / 2 * v) ** (tp or 0.95)
    return fn


PROFS = {
    "oval":     prof(0.5, "round", "point"),
    "elliptic": prof(0.5, "round", "point", bp=0.75, tp=0.8),
    "obovate":  prof(0.62, "wedge", "round", bp=1.05),
    "obov_pt":  prof(0.6, "wedge", "point", bp=1.0, tp=0.8),
    "lance":    prof(0.35, "wedge", "acum", bp=0.8, tp=0.6),
    "acum":     prof(0.42, "round", "acum", bp=0.6, tp=1.0),
    "broad":    prof(0.45, "round", "point", bp=0.45, tp=0.7),
    "roundish": prof(0.48, "round", "point", bp=0.42, tp=0.55),
    "oblong":   prof(0.5, "round", "blunt", bp=0.5),
    "narrow":   prof(0.45, "taper", "point", bp=1.3, tp=0.9),
    "spatula":  prof(0.72, "taper", "round", bp=1.5, tp=2.0),
    "lens":     lambda u: 4 * u * (1 - u) if 0 < u < 1 else 0.0,   # an ellipse tapering evenly to a point at both ends
}

# The nick across one tooth: s runs 0 to 1 along the tooth (towards the leaf
# tip). 1 is the bottom of a nick, 0 the point of a tooth (as in leaves_flowers.py).
NICK = {
    "saw":    lambda s: (1 - s) ** 1.6,
    "double": lambda s: (1 - s) ** 1.3 + (0.42 * (1 - (s - 0.5) / 0.5) ** 1.3 if s >= 0.5 else 0),
    "round":  lambda s: abs(math.cos(math.pi * s)) ** 2.4,
    "blunt":  lambda s: (1 - s) ** 0.8 * 0.9,
}


def outline(L, W, pf="oval", teeth=0, td=0.0, tk="saw", tfrom=0.0, lop=0.0, irr=0.0,
            lobes=0, ld=0.0, lfrom=0.2, lpeak=0.5, n=None, lsym=False, lk="saw"):
    """The two edges of a leaflet laid along the x axis from 0 to L.
    teeth: how many teeth down each side over the WHOLE length; td: how deep
    (in grid squares, not a share), tk: their kind (NICK). tfrom: no teeth
    below this share of the length. lop: one side wider than the other.
    irr: teeth of uneven size. lobes, ld: shallow lobes (Bristol whitebeam),
    deepest at lpeak and fading out to the tip. Returns (upper edge, lower
    edge, half width function)."""
    pr = PROFS[pf] if isinstance(pf, str) else pf
    nick = NICK[tk]
    n = n or max(140, teeth * 16 + lobes * 24)

    def hw(u, side=1):
        w = pr(u) * W / 2 * (1 + side * lop)
        if lobes and u > lfrom:
            env = (u - lfrom) / (lpeak - lfrom) if u < lpeak else ((1 - u) / (1 - lpeak)) ** 1.1
            s = ((u - lfrom) * lobes / (1 - lfrom) + (0 if side > 0 or lsym else 0.5)) % 1   # lsym: lobes level on both sides
            w -= ld * max(0.0, env) * NICK[lk](s)   # lk "round": shallow rounded lobes
        if teeth and u > tfrom:
            fade = min(1.0, (u - tfrom) / 0.06, (1 - u) / 0.035)
            s = (u * teeth + (0 if side > 0 else 0.5)) % 1
            k = int(u * teeth + (0 if side > 0 else 0.5))
            d = td * (1 + irr * math.sin(k * 2.7 + side * 1.3))
            w -= min(d * nick(s) * max(0.0, fade), w * 0.7)
        return max(w, 0.0)

    us = [i / n for i in range(n + 1)]
    top = [(L * u, hw(u, 1)) for u in us]
    bot = [(L * u, -hw(u, -1)) for u in us]
    return top, bot, hw


def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


def leaflet(a, x, y, ang, L, W, fill="leaf", pf="oval", teeth=0, td=0.0, tk="saw", tfrom=0.0, lop=0.0, irr=0.0,
            lobes=0, ld=0.0, lfrom=0.2, lpeak=0.5, veins=6, vstyle="curve", vang=0.16, lw=1.0, shade=0.1,
            midw=0.8, net=False, under=None, gloss=False, bend=0.0, lsym=False, lk="saw", M=None):
    """One leaf blade (or leaflet) from x,y along ang, with its veins.
    vstyle "straight": side veins run straight and parallel into the teeth
    (strawberry, raspberry); "curve": they curve forward and fade before the
    edge (apple, plum). under: a colour for a narrow strip along the lower
    edge, the pale underside showing where the edge rolls under (olive).
    gloss: a soft light line, for a shiny leaf. bend: the blade arches to
    one side (a nectarine leaf hanging)."""
    t = T(x, y, ang)
    mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    top, bot, hw = outline(L, W, pf, teeth, td, tk, tfrom, lop, irr, lobes, ld, lfrom, lpeak, lsym=lsym, lk=lk)
    a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), fill, lw)
    if under:   # the paler underside, seen as a strip along the lower edge
        inner = [(px, py + min(1.5, -py * 0.38)) for px, py in bot]
        a.shape(path([mp(p) for p in bot] + [mp(p) for p in inner[::-1]]), under, 0)
        a.line(opath([mp(p) for p in inner[4:-4]]), 0.45, 0.5)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((p[0], 0)) for p in top[::-1]]), "shade", 0, fa=shade)
    if gloss:
        a.line(opath([mp((L * u, hw(u, 1) * 0.5)) for u in (0.22, 0.34, 0.46, 0.56)]), 1.3, 0.5, "white")
    a.line(opath([mp((L * u, 0)) for u in (0.0, 0.3, 0.6, 0.88)]), midw, 0.55)
    if not veins:
        return hw
    if vstyle == "straight":
        # parallel veins, each ending in a tooth (or a lobe) tip
        per = lobes if lobes else teeth
        if per:
            start = lfrom if lobes else 0.0
            for side in (1, -1):
                k0 = 0
                tips = []
                for k in range(1, per * 2):
                    u = (start + (k - (0 if side > 0 or lsym else 0.5)) * (1 - start) / per) if lobes else ((k - (0 if side > 0 else 0.5)) / teeth)
                    if (lobes or u > tfrom + 0.04) and 0.08 < u < 0.93:
                        tips.append(u)
                step = max(1, round(len(tips) / veins)) if veins else 1
                for u in tips[::step]:
                    u0 = max(0.02, u - vang)
                    e = (L * (u - 0.006), side * hw(u - 0.006, side) * 0.93)
                    a.line(f"M{P(mp((L * u0, 0)))} L{P(mp(e))}", 0.55, 0.42)
            return hw
    for k in range(veins):
        u1 = 0.14 + 0.72 * (k + 0.5) / veins
        u0 = max(0.03, u1 - vang)
        for side in (1, -1):
            w1 = side * hw(u1, side) * 0.8
            p0, c, p1 = mp((L * u0, 0)), mp((L * (u0 + vang * 0.35), w1 * 0.55)), mp((L * u1, w1))
            a.line(f"M{P(p0)} Q{P(c)} {P(p1)}", 0.5, 0.36)
            if net and k < veins - 1:
                q0 = mp((L * (u0 + vang * 0.6), w1 * 0.45)); q1 = mp((L * (u1 + 0.72 / veins * 0.5), w1 * 0.55))
                a.line(f"M{P(q0)} L{P(q1)}", 0.35, 0.24)
    return hw


def stalk(a, p0, c, p1, w0=2.4, w1=1.8, fill="leaf", lw=0.9):
    return a.ribbon(p0, c, p1, w0, w1, fill, lw=lw)


LEAFLET_KEYS = ("shade", "lk", "lsym", "bend", "pf", "teeth", "td", "tk", "tfrom", "lop", "irr", "lobes", "ld", "lfrom", "lpeak", "veins", "vstyle", "vang", "net", "under", "gloss")


def lkw(sp, **over):
    """The leaflet settings out of a close-up's settings."""
    d = {k: sp[k] for k in LEAFLET_KEYS if k in sp}
    d.update(over)
    return d


# ============================================================ close-up leaves
def leaf_simple(a, sp):
    """One simple leaf on its stalk."""
    pf = sp.get("petiole", 0.2); LT = sp.get("len", 98); L = LT * (1 - pf)
    t = T(*BASE, ANG); A = t(LT * pf)
    stalk(a, BASE, t(LT * pf * 0.5, 1.2), A, sp.get("sw0", 2.4), sp.get("sw1", 1.7), sp.get("stalkc", sp["fill"]))
    if sp.get("young"):   # a young leaf of another colour beside it (spiraea: copper-red young leaves)
        col, k, off = sp["young"]
        leaflet(a, BASE[0], BASE[1], ANG + off, LT * k, LT * k * sp.get("W", 0.5) * 0.9, col, lw=0.9, midw=0.6, **lkw(sp, veins=3))
    leaflet(a, A[0], A[1], ANG, L, L * sp.get("W", 0.5), sp["fill"], lw=1.1, midw=0.9, **lkw(sp))
    return a


def leaf_trefoil(a, sp):
    """Three leaflets from the top of one stalk: the middle one on a short
    stalk of its own, the two side ones almost stalkless and lopsided, their
    outer halves wider (strawberry, Japanese wineberry)."""
    t = T(*BASE, ANG); A = t(sp.get("stalk", 36))
    stalk(a, BASE, t(sp.get("stalk", 36) * 0.5, 1.5), A, 2.4, 1.8, sp.get("stalkc", sp["fill"]))
    if sp.get("bristles"):
        for k in range(9):
            p = t(4 + k * 3.6, (1 if k % 2 else -1) * 1.2)
            a.line(f"M{P(p)} l{f(math.cos(math.radians(ANG - 100 + 200 * (k % 2))) * 2)},{f(math.sin(math.radians(ANG - 100 + 200 * (k % 2))) * 2)}", 0.6, 0.85, sp["bristles"])
    L = sp.get("ll", 40); sw = sp.get("spread", 64); ms = sp.get("midstalk", 4)
    for off in (-sw, sw):
        lop = sp.get("lop", 0.16) * (1 if off > 0 else -1)
        leaflet(a, A[0], A[1], ANG + off, L * sp.get("sidek", 0.9), L * sp.get("lW", 0.64) * sp.get("sidek", 0.9),
                sp["fill"], **lkw(sp, lop=lop))
    m = t(sp.get("stalk", 36) + ms)
    if ms:
        a.line(f"M{P(A)} L{P(m)}", 1.6, 0.85)
    tk = sp.get("termk", 1.0)
    leaflet(a, m[0], m[1], ANG, L * tk, L * sp.get("termW", sp.get("lW", 0.64)) * tk, sp["fill"], **lkw(sp, lop=0.0))
    return a


def leaf_pinnate(a, sp):
    """Leaflets in opposite pairs along one stalk and one at the end on a
    longer stalk of its own (rose, raspberry, loganberry). wings: the rose's
    pair of narrow leafy wings joined along the foot of the stalk."""
    t = T(*BASE, ANG); LT = sp.get("rach", 66); pairs = sp.get("pairs", 2)
    q = Quad(BASE, t(LT * 0.5, -2), t(LT))
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.3, sp.get("stalkc", sp["fill"]), lw=0.8)
    if sp.get("wings"):   # rose: a narrow leafy wing (stipule) joined along each side of the foot of the stalk, its tip free
        us_ = [0.02 + 0.22 * i / 12 for i in range(13)]
        for sg in (1, -1):
            inner = [q.pt(u) for u in us_]
            outer = []
            for u in us_:
                x, y = q.pt(u); nn = math.radians(q.ang(u) + 90 * sg)
                w = 1.0 + 1.9 * (u - 0.02) / 0.22
                outer.append((x + w * math.cos(nn), y + w * math.sin(nn)))
            tipp = T(*outer[-1], q.ang(0.24) + 28 * sg)(4.2)
            a.shape(path(inner + [tipp] + outer[::-1]), sp["fill"], 0.75)
            a.line(opath(outer[2:-1]), 0.4, 0.4)
    ll = sp.get("ll", 26); lW = sp.get("lW", 0.55)
    us = sp.get("at") or [0.42 + 0.4 * i / max(1, pairs - 1) for i in range(pairs)]
    for i, u in enumerate(us):
        x, y = q.pt(u); ang = q.ang(u); s = sp.get("grow", 0.82) + (1 - sp.get("grow", 0.82)) * i / max(1, pairs - 1)
        for sg in (1, -1):
            leaflet(a, x, y, ang + sg * sp.get("spread", 60), ll * s, ll * s * lW, sp["fill"], **lkw(sp, lop=sp.get("lop", 0.08) * sg))
    ex, ey = q.pt(1); e2 = T(ex, ey, q.ang(1))(sp.get("termstalk", 6))
    a.line(f"M{f(ex)},{f(ey)} L{P(e2)}", 1.4, 0.85)
    tk = sp.get("termk", 1.15)
    leaflet(a, e2[0], e2[1], q.ang(1), ll * tk, ll * tk * sp.get("termW", lW), sp["fill"], **lkw(sp, lop=0.0))
    return a


def leaf_palmate(a, sp):
    """Five leaflets all spreading from the top of one stalk (blackberry):
    the end leaflet the largest on its own stalk, the middle pair on short
    stalks, the lowest pair stalked from the foot of the middle pair."""
    t = T(*BASE, ANG); A = t(sp.get("stalk", 34))
    stalk(a, BASE, t(sp.get("stalk", 34) * 0.5, 1.5), A, 2.4, 1.8, sp["fill"])
    ll = sp.get("ll", 32); lW = sp.get("lW", 0.62)
    if sp.get("five", True):
        for sg in (1, -1):   # the lowest pair, from the foot of the middle pair's stalks
            b = T(*A, ANG + sg * 64)(3)
            e = T(*b, ANG + sg * 128)(3.5)
            a.line(f"M{P(b)} L{P(e)}", 1.1, 0.85)
            leaflet(a, e[0], e[1], ANG + sg * 132, ll * 0.7, ll * 0.7 * lW, sp["fill"], **lkw(sp, lop=0.12 * sg, veins=4))
    for sg in (1, -1):
        e = T(*A, ANG + sg * 64)(5)
        a.line(f"M{P(A)} L{P(e)}", 1.2, 0.85)
        leaflet(a, e[0], e[1], ANG + sg * 64, ll * 0.88, ll * 0.88 * lW, sp["fill"], **lkw(sp, lop=0.1 * sg))
    e = T(*A, ANG)(sp.get("termstalk", 9))
    a.line(f"M{P(A)} L{P(e)}", 1.4, 0.85)
    leaflet(a, e[0], e[1], ANG, ll, ll * sp.get("termW", lW), sp["fill"], **lkw(sp))
    return a


def _ray(poly, h):
    """How far a ray from (0,0) at angle h goes before it leaves the outline."""
    dx, dy = math.cos(h), math.sin(h); best = 0.0
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        ex, ey = x1 - x0, y1 - y0
        det = -dx * ey + ex * dy
        if abs(det) < 1e-12:
            continue
        tt = (-x0 * ey + ex * y0) / det
        s = (dx * y0 - dy * x0) / det
        if 0 <= s <= 1 and tt > best:
            best = tt
    return best


def lobed_outline(lobes, r0, notch=0.0, n=360):
    """The outline of a hand-shaped leaf, in its own frame: (0,0) is where the
    stalk joins and the leaf points along +x. lobes: [(angle, length, width,
    profile)], each lobe a leaflet shape starting at (0,0). r0: a disc in the
    middle, which rounds off the bottoms of the gaps between lobes. notch: how
    far the gap at the stalk cuts in. Returns the points and their angles."""
    polys = []
    for ang, L, W, pf in lobes:
        top, bot, _ = outline(L, W, pf, n=40)
        t = T(-L * 0.03 * math.cos(math.radians(ang)), -L * 0.03 * math.sin(math.radians(ang)), ang)
        polys.append([t(*p) for p in top] + [t(*p) for p in bot[::-1]])
    hs = [-math.pi + 2 * math.pi * (i + 0.5) / n for i in range(n)]
    rs = []
    for h in hs:
        r = max([r0] + [_ray(p, h) for p in polys])
        if notch:   # the gap where the stalk joins
            r *= 1 - notch * math.exp(-((abs(h) - math.pi) / 0.22) ** 2)
        rs.append(r)
    sm = [(rs[i - 1] + 2 * rs[i] + rs[(i + 1) % n]) / 4 for i in range(n)]   # soften the corners a little
    return [(r * math.cos(h), r * math.sin(h)) for r, h in zip(sm, hs)], hs


def toothed(pts, tsp=3.6, td=1.4, kind="sharp", zone=None, hs=None, double=False):
    """Cuts teeth along a closed outline. tsp: the width of one tooth, td its
    depth (grid squares). kind "sharp": teeth leaning towards the lobe tip they
    are on; "blunt": rounded scallops. zone(h): False where no teeth go."""
    n = len(pts); out = []
    acc = [0.0]
    for i in range(1, n + 1):
        acc.append(acc[-1] + math.dist(pts[i - 1], pts[i % n]))
    for i, (x, y) in enumerate(pts):
        r = math.hypot(x, y)
        if zone and hs is not None and not zone(hs[i]):
            out.append((x, y)); continue
        s = (acc[i] / tsp) % 1; k = int(acc[i] / tsp)
        rn = math.hypot(*pts[(i + 2) % n]); rp = math.hypot(*pts[i - 2])
        if kind == "blunt":
            nick = 1 - math.sin(math.pi * s) ** 0.45
        else:
            nick = (1 - s) ** 1.5 if rn >= rp else s ** 1.5   # lean the tooth towards the nearer lobe tip
        d = td * (0.55 if double and k % 2 else 1.0) * nick
        out.append((x * (1 - d / max(r, 0.1)), y * (1 - d / max(r, 0.1))))
    return out


def leaf_lobed(a, sp):
    """A hand-shaped leaf: fig, currants, gooseberry, grape. See lobed_outline."""
    B0 = sp.get("base", BASE)   # where the stalk starts (moved for a leaf that would run off the tile)
    pf = sp.get("petiole", 0.26); t = T(*B0, ANG); A = t(98 * pf)
    stalk(a, B0, t(98 * pf * 0.5, 1.6), A, sp.get("sw0", 2.8), sp.get("sw1", 2.0), sp.get("stalkc", sp["fill"]))
    k = sp.get("size", 1.0)
    lobes = [(ang, L * k, W * k, pf_) for ang, L, W, pf_ in sp["lobes"]]
    pts, hs = lobed_outline(lobes, sp.get("r0", 6) * k, sp.get("notch", 0.0))
    if sp.get("td"):
        lim = math.radians(sp.get("bare", 168))
        pts = toothed(pts, sp.get("tsp", 3.6), sp["td"], sp.get("tk", "sharp"), (lambda h: abs(h) < lim), hs, sp.get("double", False))
    tt = T(A[0], A[1], ANG)
    world = [tt(*p) for p in pts]
    a.shape(path(world), sp["fill"], 1.1)
    half = [tt(*p) for p, h in zip(pts, hs) if h >= 0]
    a.shape(path(half + [A]), "shade", 0, fa=0.1)
    for ang, L, W, _ in lobes:   # a main vein into each lobe, with side veins
        e = tt(*T(0, 0, ang)(L * 0.86))
        a.line(f"M{P(A)} L{P(e)}", 0.7 if abs(ang) < 1 else 0.6, 0.5)
        if L > 14:
            for u in sp.get("side", (0.3, 0.52, 0.72)):
                b = T(0, 0, ang)(L * u * 0.86)
                for sg in (1, -1):
                    e2 = T(*b, ang + sg * 48)(W * 0.36 * (1.1 - u))
                    a.line(f"M{P(tt(*b))} L{P(tt(*e2))}", 0.4, 0.3)
    return a


def leaf_fan(a, sp):
    """A ginkgo leaf: a fan narrowing into a long stalk, its outer edge wavy
    and split by a notch in the middle into two equal lobes, and no midrib:
    many fine veins fan out from the base, each forking once or twice."""
    dirn = sp.get("dirn", -76); A = T(*BASE, dirn)(sp.get("stalk", 30)); A = (A[0] + 8, A[1])
    stalk(a, (BASE[0] + 8, BASE[1]), T(BASE[0] + 8, BASE[1], dirn)(15), A, 2.0, 1.6, sp["fill"])
    R = sp.get("R", 50); spread = sp.get("spread", 58); cut = sp.get("cut", 0.3)
    def rad(ph):   # how far out the edge is at angle ph (0: the middle of the fan)
        return R * (1 + 0.025 * math.sin(13 * ph) + 0.015 * math.sin(29 * ph + 1)) * (1 - cut * math.exp(-(ph / 0.06) ** 2)) \
            * (1 - 0.12 * (abs(ph) / math.radians(spread)) ** 4)
    pts = [A]
    for i in range(141):
        ph = math.radians(-spread + 2 * spread * i / 140)
        pts.append(T(*A, dirn)(rad(ph) * math.cos(ph), rad(ph) * math.sin(ph)))
    a.shape(path(pts), sp["fill"], 1.1)
    a.shape(path([A] + pts[71:]), "shade", 0, fa=0.1)
    n = 14
    for k in range(n):   # fine veins from the base, each forking into two, the outer ones again
        ph = math.radians(-spread * 0.92 + 2 * spread * 0.92 * (k + 0.5) / n)
        r1 = R * 0.42
        p0 = A; p1 = T(*A, dirn)(r1 * math.cos(ph), r1 * math.sin(ph))
        a.line(f"M{P(p0)} L{P(p1)}", 0.4, 0.32)
        for d in (-1, 1):
            ph2 = ph + d * math.radians(spread) / n * 0.5
            r2 = rad(ph2) * 0.94
            p2 = T(*A, dirn)(r2 * math.cos(ph2), r2 * math.sin(ph2))
            a.line(f"M{P(p1)} L{P(p2)}", 0.36, 0.3)
    return a


def leaf_pair(a, sp):
    """A twig tip with one pair of opposite leaves (olive): one leaf shows its
    upper side, the other is turned to show its paler underside ("back")."""
    t = T(*BASE, ANG); A = t(30)
    a.ribbon(BASE, t(15, 1), A, 2.2, 1.6, "bark", lw=0.8)
    L = sp.get("ll", 64); W = L * sp.get("W", 0.17)
    for sg, fill in ((-1, sp.get("back", sp["fill"])), (1, sp["fill"])):
        leaflet(a, A[0], A[1], ANG + sg * sp.get("spread", 24), L, W, fill, lw=1.05, midw=0.8, **lkw(sp))
    a.oval(*t(31.5), 1.2, 1.6, ANG + 90, "sage", 0.6)   # the bud between them
    return a


LEAF_DRAW = {"fruit_pair": leaf_pair, "fruit_simple": leaf_simple, "fruit_trefoil": leaf_trefoil, "fruit_pinnate": leaf_pinnate,
             "fruit_palmate": leaf_palmate, "fruit_lobed": leaf_lobed, "fruit_fan": leaf_fan}


# The close-up leaf of each kind. Sizes are on the 100 grid. ⚠️ CHECK: from the
# descriptions and photographs, not measured from real leaves.
D = math.degrees
LEAFX = {
    "strawberry": dict(kind="fruit_trefoil", fill="leaf", ll=44, lW=0.78, pf="obovate", teeth=11, td=2.4, tfrom=0.42,
                       vstyle="straight", veins=8, vang=0.2, lop=0.26, spread=60, midstalk=3, stalk=38),
    "apple": dict(kind="fruit_simple", fill="leaf", pf="elliptic", W=0.56, petiole=0.22, teeth=26, td=0.9, tk="round",
                  veins=6, vang=0.2),
    "pear": dict(kind="fruit_simple", fill="deep", pf="broad", W=0.7, petiole=0.34, teeth=40, td=0.45, tk="round",
                 veins=7, vang=0.2, gloss=True),
    "plum": dict(kind="fruit_simple", fill="deep", pf="obov_pt", W=0.54, petiole=0.14, teeth=24, td=0.9, tk="round",
                 irr=0.35, veins=7, vang=0.2, net=True),
    "nectarine": dict(kind="fruit_simple", fill="leaf", pf="lance", W=0.24, petiole=0.07, teeth=30, td=0.7,
                      veins=12, vang=0.1, gloss=True, bend=0.08),
    "olive-tree": dict(kind="fruit_pair", fill="sage", pf=prof(0.45, "round", "point", bp=0.9, tp=0.85), W=0.17, teeth=0, veins=0, back="white"),
    "bristol-whitebeam": dict(kind="fruit_simple", fill="leaf", pf=prof(0.56, "taper", "point", bp=1.3, tp=0.8), W=0.7,
                              petiole=0.16, lobes=6, ld=5.0, lfrom=0.34, lpeak=0.56, teeth=34, td=0.75, tfrom=0.36,
                              vstyle="straight", veins=6, vang=0.12, lsym=True, lk="round", shade=0.05),
    "gingko": dict(kind="fruit_fan", fill="leaf", cut=0.32),
    "blackcurrant": dict(kind="fruit_lobed", fill="deep", petiole=0.28, size=1.32, r0=7, notch=0.55,
                         lobes=[(0, 38, 27, "oval"), (-60, 33, 24, "oval"), (60, 33, 24, "oval"), (-128, 18, 15, "oval"), (128, 18, 15, "oval")],
                         td=1.9, tsp=4.2, double=True, bare=172),
    "whitecurrant": dict(kind="fruit_lobed", fill="leaf", petiole=0.3, size=1.25, r0=10, notch=0.3,
                         lobes=[(0, 35, 27, "oval"), (-64, 31, 25, "oval"), (64, 31, 25, "oval"), (-128, 19, 17, "oval"), (128, 19, 17, "oval")],
                         td=1.8, tsp=4.6, tk="blunt", bare=172),
    "gooseberry": dict(kind="fruit_lobed", fill="leaf", petiole=0.32, size=1.12, r0=6, notch=0.18,
                       lobes=[(0, 35, 25, "roundish"), (-62, 31, 22, "roundish"), (62, 31, 22, "roundish"), (-122, 19, 15, "roundish"), (122, 19, 15, "roundish")],
                       td=2.6, tsp=6.2, tk="blunt", bare=150),
    "fig": dict(kind="fruit_lobed", fill="leaf", petiole=0.26, size=1.15, r0=12, notch=0.6,
                lobes=[(0, 44, 26, "spatula"), (-58, 38, 24, "spatula"), (58, 38, 24, "spatula"), (-118, 24, 18, "spatula"), (118, 24, 18, "spatula")],
                td=1.1, tsp=7.0, tk="blunt", bare=150),
    "grape": dict(kind="fruit_lobed", fill="leaf", petiole=0.27, size=1.12, r0=10, notch=0.8, base=(25, 84),
                  lobes=[(0, 40, 30, "oval"), (-58, 35, 27, "oval"), (58, 35, 27, "oval"), (-140, 25, 22, "oval"), (140, 25, 22, "oval")],
                  td=2.0, tsp=4.6, double=True, bare=176, stalkc="beet", sw0=2.0, sw1=1.3),
    "blueberry": dict(kind="fruit_simple", fill="leaf", pf="lens", W=0.46, shade=0.05, petiole=0.05, len=86, teeth=0, veins=5, vang=0.22),
    "honeyberry": dict(kind="fruit_simple", fill="sage", pf="oblong", W=0.44, petiole=0.05, len=84, teeth=0, veins=4, vang=0.24),
    "rose": dict(kind="fruit_pinnate", fill="deep", pairs=2, rach=58, ll=28, lW=0.6, pf="oval", teeth=11, td=1.2,
                 veins=5, vang=0.16, wings=True, termstalk=5, termk=1.2, grow=0.85, spread=58),
    "hydrangea": dict(kind="fruit_simple", fill="leaf", pf=prof(0.42, "wedge", "acum", bp=0.9, tp=0.55), W=0.42, petiole=0.14, teeth=18, td=1.3, tfrom=0.3,
                      veins=6, vang=0.2),
    "japanese-spiraea": dict(kind="fruit_simple", fill="primrose", pf=prof(0.45, "wedge", "point", bp=1.0, tp=0.8), W=0.36,
                             petiole=0.06, len=84, teeth=10, td=2.2, tk="double", tfrom=0.36, veins=5, vang=0.18,
                             young=("rust", 0.5, 44)),
    "raspberry": dict(kind="fruit_pinnate", fill="leaf", pairs=2, rach=48, ll=30, lW=0.64, pf="acum", teeth=10, td=1.9,
                      tk="double", irr=0.25, vstyle="straight", veins=6, vang=0.15, termstalk=10, termk=1.25, termW=0.66,
                      grow=0.78, spread=62, lop=0.1),
    "blackberry": dict(kind="fruit_palmate", fill="deep", stalk=32, ll=31, lW=0.66, pf=prof(0.42, "round", "acum", bp=0.5, tp=1.1),
                       teeth=11, td=1.7, tk="double", irr=0.3, vstyle="straight", veins=6, vang=0.15, termstalk=10),
    "loganberry": dict(kind="fruit_pinnate", fill="leaf", pairs=1, at=[0.86], rach=42, ll=31, lW=0.7, pf="broad", teeth=11,
                       td=2.0, tk="double", irr=0.2, vstyle="straight", veins=6, vang=0.15, termstalk=8, termk=1.2, spread=66),
    "japanese-wineberry": dict(kind="fruit_trefoil", fill="leaf", ll=27, lW=0.74, pf="broad", teeth=9, td=2.2, tk="double",
                               irr=0.45, vstyle="straight", veins=6, vang=0.16, lop=0.16, spread=70, midstalk=10, stalk=34,
                               termk=1.55, termW=0.86, sidek=0.95, stalkc="beet", bristles="beet"),
    "kiwi": dict(kind="fruit_simple", fill="deep", pf=prof(0.46, "round", "cusp", bp=0.5), W=0.8, petiole=0.32, teeth=40, td=0.7, veins=6,
                 vang=0.2, gloss=True, stalkc="berry"),
}


# ============================================================ close-up flowers
CX, CY = 50, 44

PROFS.update({
    "petal":  prof(0.58, "round", "round", bp=0.7, tp=2.0),
    "spoon":  prof(0.72, "taper", "round", bp=1.5, tp=2.0),
    "sepal":  prof(0.3, "round", "point", bp=0.6, tp=1.1),
    "lobe":   prof(0.5, "round", "round", bp=0.4, tp=1.6),
})


def tilt(cy, k):
    """Squashes the picture up and down about cy: a flat flower seen at a slant."""
    return lambda p: (p[0], cy + (p[1] - cy) * k)


def petal(a, x, y, ang, L, W, fill, pf="petal", M=None, lw=0.85, shade=0.07, lines=True, crinkle=0.0, notch=0.0):
    """One petal (or sepal) from x,y along ang. crinkle: a wavy edge
    (blackberry). notch: a small nick in the end (rose)."""
    t = T(x, y, ang); mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    top, bot, hw = outline(L, W, pf, teeth=7 if crinkle else 0, td=crinkle, tk="round", n=60)
    if notch:
        top = [(px - notch * L * math.exp(-((py) / (W * 0.18)) ** 2) * (px / L) ** 8, py) for px, py in top]
        bot = [(px - notch * L * math.exp(-((py) / (W * 0.18)) ** 2) * (px / L) ** 8, py) for px, py in bot]
    a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), fill, lw)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((p[0], 0)) for p in top[::-1]]), "shade", 0, fa=shade)
    if lines and L > 8:
        for o in ([0] if W < L * 0.4 else [-0.4, 0, 0.4]):
            q = [mp((L * u, o * hw(u) * 0.8)) for u in (0.14, 0.42, 0.68)]
            a.line(f"M{P(q[0])} Q{P(q[1])} {P(q[2])}", 0.45, 0.28)
    return hw


def stamen_ring(a, cx, cy, r0, r1, n, anth="sun", M=None, lw=0.45, fil="line", fla=0.6, ar=0.9):
    """A ring of stamens: thin stalks (filaments) out from r0 to about r1,
    each with an anther on its end."""
    for k in range(n):
        ang = k * 360 / n + 9 * (k % 2)
        rr = r1 * (0.8 + 0.2 * ((k * 7) % 3) / 2)
        p0 = T(cx, cy, ang)(r0); p1 = T(cx, cy, ang)(rr)
        if M:
            p0, p1 = M(p0), M(p1)
        a.line(f"M{P(p0)} L{P(p1)}", lw, fla, fil)
        a.oval(p1[0], p1[1], ar, ar * 0.72, ang, anth, 0.4 if ar >= 1.0 else 0)   # a small anther: colour only, so it does not read as a dark speck


def bloom_stalk(a, top, base=(56, 96), w=2.6, fill="leaf"):
    return a.ribbon(base, ((base[0] + top[0]) / 2 + 2, (base[1] + top[1]) / 2 + 4), top, w, w * 0.78, fill, lw=0.9)


def bud(a, x, y, ang, L, fill, sepal="leaf", swirl=False, small=False):
    """A closed flower bud with its sepals clasping it. swirl: the twisted
    lines of a rose bud. small: short sepals, so most of the bud shows."""
    petal(a, x, y, ang, L, L * 0.62, fill, "oval", lines=False)
    if swirl:
        t = T(x, y, ang)
        for o in (-0.18, 0.12):
            a.line(f"M{P(t(L * 0.3, o * L))} Q{P(t(L * 0.62, -o * L * 1.2))} {P(t(L * 0.95, 0))}", 0.5, 0.5)
    for off in (-16, 16, 0):
        petal(a, x, y, ang + off, L * (0.36 if small else 0.66), L * 0.2, sepal, "sepal", lines=False, lw=0.7)


def fl_rosa(a, sp):
    """An open five-petalled flower face on, of the rose family kind:
    strawberry, blackberry, loganberry. Sepals show between the petals
    (two rings on a strawberry), stamens round a centre that is a raised
    dome: the strawberry's receptacle, or a bramble's green dome of pistils."""
    n = sp.get("n", 5); R = sp.get("R", 30); k = sp.get("k", 0.9); M = tilt(CY, k)
    bloom_stalk(a, (CX + 3, CY + 6))
    if sp.get("bud", True):
        a.ribbon((62, 95), (70, 84), (80, 72), 2.0, 1.5, "leaf", lw=0.9)
        bud(a, 80, 72, -64, 11, sp.get("budc", sp["fc"]), sp.get("sepc", "leaf"))
    for ring, (nn, sl, sw, off) in enumerate(sp.get("sepals", [(5, 0.7, 0.22, 0.5)])):
        for i in range(nn):
            petal(a, CX, CY, -90 + 360 * (i + off) / nn, R * sl, R * sw, sp.get("sepc", "leaf"), "sepal", M=M, lw=0.7, lines=False)
    order = sorted(range(n), key=lambda i: math.sin(math.radians(-90 + 360 * i / n)))
    for i in order:
        ang = -90 + 360 * i / n + sp.get("twist", 0) * ((i * 37) % 5 - 2)
        petal(a, CX, CY, ang, R * sp.get("pl", 1.0), R * sp.get("pw", 0.8), sp["fc"], sp.get("pf", "petal"), M=M,
              crinkle=sp.get("crinkle", 0), shade=0.06 + (0.05 if math.sin(math.radians(ang)) > 0.3 else 0))
    cen = sp.get("cen", "primrose"); dr = R * sp.get("dome", 0.22)
    sr = sp.get("sr", 0.42)
    stamen_ring(a, CX, CY, dr * 0.8, R * sr, sp.get("ns", 22), sp.get("anth", "sun"), M, fil=sp.get("fil", "line"),
                fla=0.6 if sp.get("fil", "line") == "line" else 1.0, lw=0.5 if sp.get("fil", "line") == "line" else 0.7)
    a.oval(CX, CY, dr, dr * k, 0, cen, 0.8)
    a.shape(path([(CX + dr * 0.95 * math.cos(h), CY + dr * k * 0.95 * math.sin(h)) for h in [math.pi * 0.05 + math.pi * 0.9 * i / 20 for i in range(21)]]
                 + [(CX, CY + dr * 0.2)]), "shade", 0, fa=0.12)
    for j in range(int(10 + dr * dr * 0.5)):   # the tiny pistils (or seeds) dotted over the dome
        rr = dr * 0.82 * math.sqrt((j + 0.5) / int(10 + dr * dr * 0.5)); th = j * GOLD
        a.dot(CX + rr * math.cos(th), CY + rr * math.sin(th) * k, 0.38, sp.get("dots", "unripe"))
    return a


def blossom_flower(a, x, y, r, sp, start=-90, k=0.86, face=True):
    """One flower of tree blossom. sp: fc (petals), tinge (the flush on the
    backs of the petals, seen at their edges), pw (petal width: small for gaps
    between the petals), anth and fil (anther and filament colours), styles
    (1 for plum and nectarine, 5 for apple and pear), cup (a reddish cup
    behind: nectarine)."""
    M = tilt(y, k)
    if r < 4.6:   # drawn small on a whole tree: a plain flower, so the petal colour reads
        a.flower(x, y, r, 5, sp["fc"], None, min(0.95, sp.get("pw", 0.9)), start=start, lw=0.5)
        if sp.get("tinge"):
            for i in range(5):
                e = T(x, y, start + 72 * i)(r * 0.8); a.dot(e[0], e[1], max(0.35, r * 0.16), sp["tinge"])
        a.dot(x, y, max(0.45, r * 0.24), sp.get("anth", "sun"))
        return
    for i in range(5):   # sepals: sepl long enough and their tips show between the petals (apple)
        petal(a, x, y, start + 72 * (i + 0.5), r * sp.get("sepl", 0.46), r * sp.get("sepw", 0.2), sp.get("sepc", "leaf"), "sepal", M=M, lw=0.55, lines=False)
    order = sorted(range(5), key=lambda i: math.sin(math.radians(start + 72 * i)))
    for i in order:
        ang = start + 72 * i
        petal(a, x, y, ang, r, r * sp.get("pw", 0.9), sp["fc"], "petal", M=M, lw=0.7,
              shade=0.05 + (0.05 if math.sin(math.radians(ang)) > 0.3 else 0), lines=r > 9)
        if sp.get("tinge"):
            t = T(x, y, ang)
            a.line(opath([M(t(r * u, -r * sp.get("pw", 0.9) * 0.44 * PROFS["petal"](u))) for u in (0.4, 0.6, 0.78, 0.92)]), 1.6, 0.75, sp["tinge"])
    if sp.get("cup"):   # the reddish cup in the middle (nectarine): colour only
        a.oval(x, y, r * 0.22, r * 0.22 * k, 0, sp["cup"], 0)
    stamen_ring(a, x, y, r * 0.12, r * sp.get("sr", 0.44), sp.get("ns", 16), sp.get("anth", "sun"), M,
                lw=0.4 if sp.get("fil", "line") == "line" else 0.55, fil=sp.get("fil", "line"),
                fla=0.6 if sp.get("fil", "line") == "line" else 1.0, ar=max(0.6, r * sp.get("ark", 0.06)))
    if sp.get("styles", 5) == 1:   # one style, standing in the middle
        a.line(f"M{f(x)},{f(y)} L{f(x + 0.2)},{f(y - r * 0.22)}", 0.7, 0.7, "pale")
        a.dot(x + 0.2, y - r * 0.22, 0.45, "pale")
    else:
        for j in range(5):
            e = M(T(x, y, -90 + 72 * j)(r * 0.12))
            a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.6, 0.8, "unripe")
        a.dot(x, y, 0.8, "pale")


def fl_blossom(a, sp):
    """Tree blossom on its wood, laid out four ways (sp "lay"):
    "spur"  apple: a cluster on a short spur, the king flower in the middle,
            deep pink buds, a tuft of young leaves opening with them;
    "pear"  pear: a rounder cluster on longer stalks, pure white;
    "along" plum: flowers in ones to threes on short stalks along the twig,
            the first small leaves just showing;
    "bare"  nectarine: flowers with no stalk at all, tight against a bare
            reddish shoot, before any leaves."""
    lay = sp.get("lay", "spur"); fc = sp["fc"]
    if lay in ("spur", "pear"):
        a.ribbon((4, 94), (40, 82), (96, 86), 4.6, 3.2, "bark", lw=0.9)
        spur = (50, 80)
        a.ribbon((48, 86), (49, 83), spur, 4.4, 3.4, "bark", lw=0.8)
        for dx in (-1.4, 0.6):
            a.line(f"M{f(spur[0] + dx - 1.4)},{f(spur[1] + 2.6 + dx)} q1.4,-0.8 2.8,0", 0.5, 0.5)
        lv = sp.get("leaves", [(-158, 22), (-22, 24), (-128, 16)])
        for ang, L in lv:
            leaflet(a, spur[0], spur[1], ang, L, L * sp.get("lw_", 0.5), sp.get("lc", "leaf"), sp.get("lpf", "elliptic"),
                    teeth=sp.get("lteeth", 12), td=0.6, tk="round", veins=4)
        if lay == "spur":
            fl_ = [(50, 30, 15, -90), (27, 46, 14, -70), (73, 48, 14, -110), (38, 62, 12, -60)]
            buds = [(62, 62), (66, 30), (30, 26)]
        else:
            fl_ = [(50, 26, 13, -90), (28, 38, 12.5, -60), (72, 36, 12.5, -120), (36, 58, 11, -40), (66, 58, 11, -140), (52, 46, 11, -100)]
            buds = [(16, 50), (84, 52)]
        for x, y, r, _ in fl_:
            a.line(f"M{P(spur)} Q{f((spur[0] + x) / 2)},{f(y + (spur[1] - y) * 0.6)} {f(x)},{f(y)}", 0.8, 0.85)
        for x, y in buds:
            a.line(f"M{P(spur)} Q{f((spur[0] + x) / 2)},{f(y + (spur[1] - y) * 0.6)} {f(x)},{f(y)}", 0.8, 0.85)
            bud(a, x, y, math.degrees(math.atan2(y - spur[1], x - spur[0])), sp.get("budl", 7.5), sp.get("budc", fc), sp.get("sepc", "leaf"), small=True)
        for x, y, r, st in sorted(fl_, key=lambda q: -q[1]):
            blossom_flower(a, x, y, r, sp, start=st)
        return a
    # along the wood: plum (short stalks, ones to threes) and nectarine (no stalks, bare shoot)
    shoot = Quad((9, 90), (40, 52), (92, 14))
    a.ribbon(shoot.p0, shoot.c, shoot.p1, 4.0, 2.2, sp.get("wood", "bark"), lw=0.9)
    spots = sp.get("spots", [(0.2, 1), (0.42, -1), (0.62, 1), (0.82, -1)])
    for j, (u, sd) in enumerate(spots):
        x, y = shoot.pt(u); ang = shoot.ang(u)
        nrm = ang - 90 * sd
        if lay == "bare":
            fx, fy = T(x, y, nrm)(3.5)
            blossom_flower(a, fx, fy, sp.get("r", 13) * (1 - 0.12 * j), sp, start=nrm + 18)
        else:
            for m in range(sp.get("per", 2) if j % 2 == 0 else 1):
                e = T(x, y, nrm + (m - 0.5) * 34)(9 + 3 * m)
                a.line(f"M{f(x)},{f(y)} Q{P(T(x, y, nrm + (m - 0.5) * 20)(5))} {P(e)}", 0.7, 0.85)
                blossom_flower(a, e[0], e[1], sp.get("r", 12) * (1 - 0.08 * j), sp, start=nrm + 30 * m)
            if sp.get("tinyleaves"):
                for sg in (-1, 1):
                    leaflet(a, x, y, nrm + 180 + sg * 30, 7, 3.2, "leaf", "elliptic", veins=0, lw=0.6, midw=0.4)
    return a


def hang_bell(a, x, y, ang, L, W, fc, inside="primrose", tips=True, lobes=5):
    """A small bell hanging from x,y, its mouth at the far end (blackcurrant).
    tips: the five sepal tips curl back at the mouth."""
    t = T(x, y, ang)
    hw = lambda u: W / 2 * (0.45 + 0.55 * math.sin(math.pi / 2 * min(1, u * 1.15)) ** 0.8)
    us = [i / 24 for i in range(25)]
    top = [t(L * u, hw(u)) for u in us]; bot = [t(L * u, -hw(u)) for u in us]
    a.shape(path(top + bot[::-1]), fc, 0.8)
    a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    a.oval(*t(L), W * 0.2, W * 0.42, ang, inside, 0.6)   # the paler inside, seen at the mouth
    if tips:
        for sg in (1, -1):
            b = t(L, sg * hw(1) * 0.9)
            petal(a, b[0], b[1], ang + sg * 125, W * 0.55, W * 0.32, fc, "sepal", lw=0.6, lines=False, shade=0.06)


def urn(a, x, y, ang, L, W, fc):
    """A hanging urn narrowed at the mouth, with five tiny teeth turned back
    (blueberry)."""
    t = T(x, y, ang)
    hw = lambda u: W / 2 * (0.35 + 0.65 * math.sin(math.pi * min(1, 0.12 + u * 0.95)) ** 0.6) * (1 - 0.3 * max(0, u - 0.82) / 0.18)
    us = [i / 30 for i in range(31)]
    top = [t(L * u, hw(u)) for u in us]; bot = [t(L * u, -hw(u)) for u in us]
    a.shape(path(top + bot[::-1]), fc, 0.8)
    a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    for u in (0.3, 0.6):
        a.line(opath([t(L * v, hw(v) * (u * 2 - 1) * 0.8) for v in (0.15, 0.5, 0.85)]), 0.4, 0.3)
    m = hw(1)
    for j in range(5):   # the little teeth round the mouth, curled back and out
        o = (j - 2) / 2 * m * 1.25
        b = t(L * 1.0, o)
        e = T(*b, ang + (o / max(m, 0.1)) * 75)(W * 0.24 + 0.8)
        a.shape(path([T(*b, ang + 90)(1.0), e, T(*b, ang - 90)(1.0)]), fc, 0.6)
    for sg in (1, -1, 0):   # the small cup of sepals at the top
        petal(a, x, y, ang + sg * 40, W * 0.34, W * 0.24, "unripe", "sepal", lw=0.5, lines=False, shade=0)


def fl_strig(a, sp):
    """A hanging string (a strig, or raceme) of small flowers, with a leaf
    behind: blackcurrant bells, white currant saucers, blueberry urns."""
    form = sp.get("form", "bell"); fc = sp["fc"]
    a.ribbon((6, 29), (30, 22), (60, 16), 4.0, 3.2, "bark", lw=0.9)   # the old wood it hangs from
    node = (sp.get("nodex", 36), 21)
    if sp.get("leaf"):
        import leaves_flowers as LFW
        src, own = LFW.own_leaf(sp["leaf"])
        a.place(src, node[0] + 2, node[1], sp.get("leafang", -24), sp.get("leafk", 0.42), lw=0.9, detail=True)
    drop = sp.get("drop", 94)
    q = Quad(node, (node[0] + sp.get("swing", 10), (node[1] + drop) / 2), (node[0] + sp.get("swing", 10) * 0.6, drop))
    a.line(q.d(), 1.1, 0.9)
    nf = sp.get("nf", 7)
    for j in range(nf):
        u = 0.16 + 0.82 * j / (nf - 1); x, y = q.pt(u); sd = -1 if j % 2 else 1
        s = 1 - 0.3 * u
        if form == "saucer":   # white currant: tiny flat saucers on short stalks
            e = (x + sd * 7 * s, y + 3)
            a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4 * s)},{f(y - 0.5)} {P(e)}", 0.7, 0.85)
            a.oval(e[0], e[1] - 2.2 * s, 1.8 * s, 1.6 * s, 0, "unripe", 0.5)   # the small ovary behind
            blossom_flower(a, e[0], e[1] + 1.4 * s, 6.6 * s, dict(fc=fc, pw=1.0, sepc=fc, anth=sp.get("anth", "pale"), ns=5, sr=0.3,
                                                                    styles=5, cup=sp.get("cen")), start=-90 + 20 * sd, k=0.72)
        elif form == "urn":
            e = (x + sd * 6 * s, y + 1)
            a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4 * s)},{f(y - 1)} {P(e)}", 0.7, 0.85)
            urn(a, e[0], e[1], 90 - sd * 14, 15 * s, 11 * s, fc)
        else:   # blackcurrant: little bells, the swollen green ovary above each
            e = (x + sd * 6 * s, y + 1)
            a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4 * s)},{f(y - 1)} {P(e)}", 0.7, 0.85)
            a.oval(e[0], e[1] + 1.4 * s, 2.0 * s, 2.4 * s, 0, sp.get("ovary", "unripe"), 0.6)
            hang_bell(a, e[0], e[1] + 3.2 * s, 90 - sd * 12, 10 * s, 8 * s, fc, sp.get("cen", "pear"))
    return a


def fl_goose(a, sp):
    """Gooseberry: one or two flowers hanging under the shoot. Above each, the
    green bristly ovary; below it the short tube, and the five reddish sepals
    swept sharply back up; the small white petals and the stamens point
    down out of the mouth."""
    fc = sp["fc"]
    sh = Quad((6, 26), (40, 16), (94, 24))
    a.ribbon(sh.p0, sh.c, sh.p1, 3.6, 2.6, "bark", lw=0.9)
    x0, y0 = sh.pt(0.46)
    for sg in (-1, 1, 0):   # the spines under the leaf cluster
        a.shape(f"M{f(x0 + sg * 2 - 0.8)},{f(y0 + 1)} L{f(x0 + sg * 4.5)},{f(y0 + 7)} L{f(x0 + sg * 2 + 0.8)},{f(y0 + 1)} Z", "straw", 0.6)
    import leaves_flowers as LFW
    src, own = LFW.own_leaf("gooseberry")
    a.place(src, x0, y0 - 1, -40, 0.3, lw=0.85); a.place(src, x0, y0 - 1, -150, 0.26, lw=0.85)
    for (dx, L0, s) in ((-15, 16, 1.7), (18, 14, 1.35)):
        top = (x0 + dx * 0.3, y0 + 1)
        ov = (x0 + dx, y0 + L0 * s)
        a.line(f"M{P(top)} Q{f(x0 + dx * 0.9)},{f(y0 + 6)} {f(ov[0])},{f(ov[1] - 4 * s)}", 0.8, 0.85)
        a.oval(ov[0], ov[1], 3.4 * s, 4.2 * s, 0, "unripe", 0.8)                       # the ovary, which becomes the berry
        for j in range(6):
            b = T(ov[0], ov[1], -150 + j * 24 + (180 if j > 2 else 0))(3.6 * s)
            a.line(f"M{P(b)} L{P(T(*b, -160 + j * 24 + (180 if j > 2 else 0))(1.6 * s))}", 0.5, 0.8)
        # below the ovary, a small greenish bell; at its mouth the five narrow reddish sepals fold
        # sharply back, so they lie up against the bell and the ovary; the small white petals and
        # the stamens only just show at the mouth
        tb = (ov[0], ov[1] + 3.6 * s); Lb = 6.5 * s
        hw = lambda u: s * (2.2 + 1.4 * u)
        m = (tb[0], tb[1] + Lb)
        for off in (-1, 1):   # two sepals behind, folded back up and out past the sides of the bell
            b = (m[0] + off * hw(1) * 0.8, m[1] - 0.3 * s)
            petal(a, b[0], b[1], -90 + off * 30, 8.5 * s, 2.0 * s, fc, "sepal", lw=0.65, lines=False, shade=0.06)
        us = [i / 12 for i in range(13)]
        a.shape(path([(tb[0] + hw(u), tb[1] + Lb * u) for u in us] + [(tb[0] - hw(u), tb[1] + Lb * u) for u in us[::-1]]), "pear", 0.8)
        for dxp in (-1.4, 0, 1.4):   # the small white petals at the mouth
            petal(a, m[0] + dxp * s, m[1] - 0.6 * s, 90 + dxp * 10, 2.6 * s, 1.8 * s, sp.get("cen", "white"), "oblong", lw=0.55, lines=False, shade=0)
        for dxp in (-0.9, 0.9):     # the stamens, just past the petals
            e = (m[0] + dxp * 1.6 * s, m[1] + 3.0 * s)
            a.line(f"M{f(m[0] + dxp * s)},{f(m[1])} L{P(e)}", 0.55, 0.7)
            a.oval(e[0], e[1] + 0.4, 0.7, 0.9, 0, "primrose", 0)
        for off in (-1.0, 0.0, 1.0):   # three sepals in front, narrow, folded sharply back against the bell
            b = (m[0] + off * hw(1) * 0.9, m[1] - 0.2 * s)
            petal(a, b[0], b[1], -90 - off * 8, 7.5 * s, 1.6 * s, fc, "sepal", lw=0.6, lines=False, shade=0.05)
    return a


def fl_honey(a, sp):
    """Honeyberry: a pair of narrow pale yellow funnels side by side, hanging
    from where a pair of leaves joins the stem, each opening into five short
    spreading lobes with the stamens poking out."""
    fc = sp["fc"]
    a.ribbon((48, 96), (49, 50), (50, 6), 3.0, 2.2, sp.get("stemc", "beet"), lw=0.9)
    node = (49.5, 34)
    for sg in (-1, 1):   # the pair of half-open leaves
        leaflet(a, node[0], node[1], -90 + sg * 62, 30, 12, sp.get("lc", "sage"), "oblong", veins=3, lw=0.9)
    for sg in (-1, 1):   # the two flowers of the pair
        st = (node[0] + sg * 2, node[1] + 3)
        ang = 90 + sg * 30
        a.oval(*T(*st, ang)(3), 2.4, 2.0, 0, "unripe", 0.6)
        t = T(*st, ang)
        b0 = t(4.5); L = 30
        hw = lambda u: 2.4 + 4.0 * u ** 1.6
        us = [i / 20 for i in range(21)]
        tt = T(*b0, ang)
        a.shape(path([tt(L * u, hw(u)) for u in us] + [tt(L * u, -hw(u)) for u in us[::-1]]), fc, 0.85)
        a.shape(path([tt(L * u, hw(u)) for u in us] + [tt(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
        mouth = tt(L)
        for j in range(5):   # the five short lobes, spreading
            petal(a, mouth[0], mouth[1], ang + (j - 2) * 34, 7.5, 5.2, fc, "lobe", lw=0.7, lines=False, shade=0.05)
        for j in (-1, 0, 1):
            e = T(*mouth, ang + j * 10)(9)
            a.line(f"M{P(mouth)} L{P(e)}", 0.6, 0.75); a.oval(e[0], e[1], 0.9, 1.2, ang, "sun", 0.4)
    return a


def fl_rose(a, sp):
    """A semi-double rose face on: an outer ring of broad, notched petals,
    a second ring between them, inner petals cupped round a ring of golden
    stamens; long pointed sepals turned back below, some with side lobes;
    a swirled bud beside it."""
    fc = sp["fc"]; R = sp.get("R", 31); k = 0.86; M = tilt(CY, k)
    bloom_stalk(a, (CX + 2, CY + 8))
    a.ribbon((62, 95), (72, 84), (82, 70), 2.0, 1.5, "leaf", lw=0.9)
    bud(a, 82, 70, -70, 13, fc, "leaf", swirl=True)
    for i in range(5):   # sepals, turned back: their tips show below and between the petals
        ang = -54 + 72 * i
        petal(a, CX, CY, ang, R * 1.12, R * 0.12, "leaf", "sepal", M=M, lw=0.7, lines=False)
        if i % 2 == 0:
            for u in (0.5, 0.7):
                b = M(T(CX, CY, ang)(R * 1.12 * u))
                a.line(f"M{P(b)} L{P(T(*b, ang + 40)(2.4))}", 0.5, 0.8)
    for ring, (rk, w, off) in enumerate(((1.0, 0.92, 0), (0.8, 0.8, 36), (0.56, 0.7, 12))):
        order = sorted(range(5), key=lambda i: math.sin(math.radians(-90 + off + 72 * i)))
        for i in order:
            ang = -90 + off + 72 * i
            petal(a, CX, CY, ang, R * rk, R * rk * w, fc, "petal", M=M, lw=0.8, notch=0.05 if ring < 2 else 0,
                  shade=0.05 + 0.04 * ring + (0.04 if math.sin(math.radians(ang)) > 0.3 else 0), lines=ring == 0)
    # the inner petals cupped round the middle: seen as curved edges
    for j in range(6):
        ang = j * 60 + 20
        p0 = M(T(CX, CY, ang)(R * 0.3)); p1 = M(T(CX, CY, ang + 50)(R * 0.3)); c = M(T(CX, CY, ang + 25)(R * 0.42))
        a.line(f"M{P(p0)} Q{P(c)} {P(p1)}", 0.7, 0.7)
    stamen_ring(a, CX, CY, R * 0.06, R * 0.24, 26, sp.get("cen", "sun"), M, lw=0.45, ar=0.9)
    a.oval(CX, CY, R * 0.07, R * 0.06, 0, "unripe", 0.6)
    return a


def fl_corymb(a, sp):
    """A flat-topped head of many small flowers (a corymb) on stalks that
    branch at several levels: side branches leave the main stalk one above
    another, each forks again, and the outer stalks are longer, so all the
    flowers come level in a flat top (Bristol whitebeam, Japanese spiraea).
    Seen almost from the side. fluffy: long stamens standing out past the
    petals (spiraea)."""
    fc = sp["fc"]; c = (50, 38); R = sp.get("R", 34); k = sp.get("k", 0.24)
    stc = sp.get("stemc", "leaf")
    axis = Quad((52, 96), (51, 74), (50, c[1] + 6))
    a.ribbon(axis.p0, axis.c, axis.p1, 3.0, 1.8, stc, lw=0.9)
    if sp.get("leaf"):
        import leaves_flowers as LFW
        src, own = LFW.own_leaf(sp["leaf"])
        a.place(src, 51.5, 84, -158, 0.44, lw=0.85); a.place(src, 51.2, 78, -26, 0.4, lw=0.85)
    m = sp.get("m", 30)
    spots = []
    for j in range(m):
        rr = R * 0.94 * math.sqrt((j + 0.5) / m); th = j * GOLD
        spots.append((c[0] + rr * math.cos(th), c[1] + rr * k * math.sin(th), math.sin(th)))
    # first level: side branches leaving the main stalk one above another
    prim = []
    for i, (u, side, reach) in enumerate(((0.45, -1, 0.72), (0.56, 1, 0.7), (0.68, -1, 0.36), (0.78, 1, 0.34))):
        b = axis.pt(u); e = (c[0] + side * R * reach, c[1] + 11)
        a.line(f"M{P(b)} Q{f(b[0] + (e[0] - b[0]) * 0.6)},{f(b[1] - 1)} {P(e)}", 0.8, 0.9)
        prim.append(e)
    prim.append(axis.p1)
    # second level: each branch forks again towards the flowers above it
    sec = []
    for (px, py) in prim:
        for d in (-0.16, 0.16):
            e = (px + d * R, c[1] + 5)
            a.line(f"M{f(px)},{f(py)} L{P(e)}", 0.6, 0.85)
            sec.append(e)
    for x, y, z in spots:   # last level: a short stalk to each flower
        sx, sy = min(sec, key=lambda q: (q[0] - x) ** 2 + (q[1] - y) ** 2)
        a.line(f"M{f(sx)},{f(sy)} L{f(x)},{f(y)}", 0.45, 0.7)
    r = sp.get("r", 6.4)
    for x, y, z in sorted(spots, key=lambda q: q[1]):
        if sp.get("fluffy"):
            for kk in range(6):   # long stamens, past the petals
                e = T(x, y, kk * 60 + x * 7)(r * 1.45)
                e = (e[0], y + (e[1] - y) * 0.6)
                a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.35, 0.55)
                a.dot(e[0], e[1], 0.45, sp.get("anth", "pink"))
        blossom_flower(a, x, y, r * (0.92 + 0.08 * z), dict(fc=fc, pw=1.0, anth=sp.get("anth", "primrose"), ns=8 if not sp.get("fluffy") else 0,
                                                            sr=0.5, styles=3, sepc=sp.get("sepc", "leaf")), start=-90 + x * 9, k=0.62)
    return a


def fl_olive(a, sp):
    """Olive: a short loose spray of tiny four-lobed creamy flowers, each with
    two yellow stamens standing up, from where a pair of narrow leaves joins
    the twig."""
    fc = sp["fc"]
    a.ribbon((8, 94), (40, 70), (90, 32), 3.0, 2.0, "bark", lw=0.9)
    sh = Quad((8, 94), (40, 70), (90, 32))
    for u, off in ((0.3, 1), (0.6, 1)):   # leaf pairs; the spray comes from the angle of the upper pair
        x, y = sh.pt(u); ang = sh.ang(u)
        for sg in (-1, 1):
            leaflet(a, x, y, ang + sg * 34, 32, 6.4, sp.get("lc", "sage"), PROFS["oval"], veins=0, lw=0.9, midw=0.6)
    x, y = sh.pt(0.6)
    q = Quad((x, y), (x - 2, y - 20), (x + 6, y - 44))
    a.line(q.d(), 0.9, 0.9)
    pts = []
    for j, (u, sd) in enumerate(((0.3, -1), (0.45, 1), (0.6, -1), (0.75, 1), (0.9, -1))):
        bx, by = q.pt(u); e = (bx + sd * 10 * (1 - u * 0.5), by - 5)
        a.line(f"M{f(bx)},{f(by)} Q{f(bx + sd * 5)},{f(by - 1)} {P(e)}", 0.6, 0.85)
        pts.append(e)
        if j < 3:
            e2 = (bx + sd * 4, by - 8); a.line(f"M{f(bx + sd * 2)},{f(by - 1)} L{P(e2)}", 0.5, 0.85); pts.append(e2)
    pts.append(q.pt(1))
    for j, (px, py) in enumerate(sorted(pts, key=lambda p: p[1])):
        if j % 4 == 3:
            a.oval(px, py, 1.8, 2.2, 0, "pale", 0.5); continue
        r = 6.8
        M = tilt(py, 0.84)
        for i in range(4):
            petal(a, px, py, -45 + 90 * i + j * 13, r, r * 0.72, fc, "lobe", M=M, lw=0.55, lines=False, shade=0.05)
        for sg in (-1, 1):   # the two stamens
            e = (px + sg * 1.6, py - 3.2)
            a.line(f"M{f(px)},{f(py)} L{P(e)}", 0.6, 0.8); a.oval(e[0], e[1], 1.2, 0.9, 0, sp.get("cen", "primrose"), 0.45)
    return a


def fl_rubus_nod(a, sp):
    """Raspberry and Japanese wineberry: a small nodding flower, NOT flat like
    a rose. Seen from the side: the five small petals stand round the middle
    like a little cup opening downwards, shorter than the sepals; inside them
    white stamens ring a dome of green pistils, which hangs out below.
    The sepals are turned back (raspberry) or close round the petals in a
    hairy cup (cup=True, wineberry). bristly: sepals and stalks thick with
    red hairs."""
    fc = sp["fc"]; sepc = sp.get("sepc", "sage"); br = sp.get("bristly"); cup = sp.get("cup")
    stc = br or "leaf"
    q = Quad((22, 96), (20, 46), (40, 14))
    a.ribbon(q.p0, q.c, q.p1, 2.8, 2.0, stc, lw=0.9)
    hairs = lambda q_, n_: [a.line(f"M{P(q_.pt(0.05 + 0.9 * j / (n_ - 1)))} l{f((1 if j % 2 else -1) * 2.2)},{f(-0.8)}", 0.6, 0.85, br) for j in range(n_)]
    if br:
        hairs(q, 16)
    c = (62, 46); ang = 96; t = T(*c, ang)
    q2 = Quad((40, 14), (60, 6), (c[0] - 0.6, c[1] - 7))
    a.line(q2.d(), 1.5, 0.9, br or "line")
    if br:
        hairs(q2, 7)
    sl = sp.get("sepl", 26); sw = sp.get("sepw", 8)
    seps = (-150, 150, -118, 118, 180) if not cup else (-56, 56, -34, 34)
    if cup:
        for off in (-150, 150):   # two sepals still turned back behind
            petal(a, *t(-2), ang + off, sl * 0.8, sw, sepc, "sepal", lw=0.8, lines=False, shade=0.06)
    else:
        for off in seps:
            petal(a, *t(-2), ang + off, sl, sw, sepc, "sepal", lw=0.8, lines=False, shade=0.06)
    if cup:   # the long hairy sepals, cupped round behind the petals
        for off in seps:
            petal(a, *t(-2), ang + off, sl, sw, sepc, "sepal", lw=0.8, lines=False, shade=0.06)
            if br:
                e = T(*t(-2), ang + off)
                for u in (0.25, 0.45, 0.65, 0.82):
                    b = e(sl * u); sg = 1 if off > 0 else -1
                    a.line(f"M{P(b)} l{f(1.8 * math.cos(math.radians(ang + off + sg * 80)))},{f(1.8 * math.sin(math.radians(ang + off + sg * 80)))}", 0.5, 0.85, br)
    a.oval(*t(-1), 6.6, 8.0, ang + 90, sepc, 0.8)   # the calyx, where sepals and petals join
    pl = sp.get("pl", 13); pw = sp.get("pw", 6.2)
    for off in (-14, 14):   # the back petals
        petal(a, *t(3), ang + off, pl, pw, fc, "spoon", lw=0.75, lines=False, shade=0.12)
    for j in range(16):   # white stamens round the dome
        o = (j - 7.5) / 7.5
        b = t(3, o * 5); e = t(11 - abs(o) * 3, o * 9)
        a.line(f"M{P(b)} L{P(e)}", 0.5, 0.75)
        a.dot(e[0], e[1], 0.65, "white")
    d = t(12)
    a.oval(d[0], d[1], 5.4, 4.6, ang, sp.get("cen", "pale"), 0.8)   # the dome of pistils
    for j in range(16):
        rr = 4.2 * math.sqrt((j + 0.5) / 16); th = j * GOLD
        a.dot(d[0] + rr * math.cos(th), d[1] + rr * 0.85 * math.sin(th), 0.42, "unripe")
    for off in ((-20, 20) if cup else (-40, 40)):   # the front petals: upright inside the sepal cup (wineberry), spread (raspberry)
        petal(a, *t(3), ang + off, pl, pw, fc, "spoon", lw=0.75, lines=False, shade=0.05)
    # a bud beside it, on its own stalk
    bq = (26, 52)
    a.line(f"M{P(q.pt(0.42))} Q{f(bq[0] + 2)},{f(bq[1] - 10)} {P(bq)}", 1.0, 0.85, br or "line")
    if br:   # wineberry: the bud a hairy red cage of sepals
        petal(a, bq[0], bq[1], 90, 13, 9, sepc, "oval", lw=0.8, lines=False)
        for j in range(7):
            b = T(bq[0], bq[1], 90)(2 + j * 1.6)
            a.line(f"M{P(b)} l{f((1 if j % 2 else -1) * 2.4)},{f(0.6)}", 0.5, 0.85, br)
        for off in (-12, 12):
            a.line(f"M{P(T(*bq, 90 + off)(1))} Q{P(T(*bq, 90 + off * 0.3)(8))} {P(T(*bq, 90)(13))}", 0.5, 0.5)
    else:
        petal(a, bq[0], bq[1], 90, 11, 8, sp.get("budc", "white"), "oval", lw=0.8, lines=False)
        for off in (-30, 30, 0):
            petal(a, bq[0], bq[1] - 1, 90 + off, 10, 3.4, sepc, "sepal", lw=0.6, lines=False)
    return a


def fl_grape(a, sp):
    """Grape: a dense, branched, cone-shaped cluster (a panicle) of tiny green
    flower buds hanging from the shoot opposite a leaf, a tendril beside it.
    Here and there an open flower: no petals to see, only five stamens spread
    out round a small green ovary; on one the petals, still joined at their
    tips, are lifting off as a little cap."""
    fc = sp["fc"]; bc = sp.get("budc", "unripe")
    a.ribbon((6, 21), (40, 14), (94, 20), 3.4, 2.6, "bark", lw=0.9)   # the shoot
    a.line("M64,17 q4,-9 12,-10 q5,0 4,4 q-2,2 -4,0", 0.8, 0.85)       # a tendril
    top = (42, 18)
    ax = Quad(top, (44, 32), (47, 90))
    a.line(ax.d(), 1.4, 0.9)
    W = lambda u: 26 * (1 - u) ** 0.75 + 2.5   # half width of the cone at u down its length
    opens = []
    for j in range(8):   # side branches, each carrying a tight bunch of buds
        u = 0.12 + 0.8 * j / 7; x, y = ax.pt(u); sd = -1 if j % 2 else 1; w = W(u)
        e = (x + sd * w * 0.8, y + 3)
        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * w * 0.4)},{f(y - 1)} {P(e)}", 0.7, 0.85)
        opens.append((e, j))
    # the buds, packed in the cone from the back rows to the front
    buds = []
    for i in range(190):
        u = 0.1 + 0.88 * ((i * 0.618034) % 1); v = (((i * 0.7548777) % 1) * 2 - 1) * 0.95
        x, y = ax.pt(u); w = W(u)
        buds.append((x + v * w, y + 1.2 * math.sin(i * 2.3), abs(v)))
    for x, y, d in sorted(buds, key=lambda q: -q[2]):
        a.oval(x, y, 1.9, 2.2, 20 * math.sin(x), bc, 0.5)
    def flower(x, y, cap, s=1.0):
        for i in range(5):   # stamens spread out
            e = T(x, y, -90 + 72 * i + x * 3)(6.4 * s)
            a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.6, 0.85); a.oval(e[0], e[1], 1.3 * s, 0.95 * s, 72 * i, sp.get("cen", "primrose"), 0)
        a.oval(x, y, 2.4 * s, 2.4 * s, 0, fc, 0.7); a.dot(x, y - 0.4, 0.8, "unripe")
        if cap:   # the cap of petals, lifting off on the stamens
            for i in (-1, 1):
                a.line(f"M{f(x + i * 1.2)},{f(y - 1)} L{f(x + i * 1.6)},{f(y - 5.8 * s)}", 0.5, 0.8)
            a.polar(x, y - 7.6 * s, lambda h: 1 + 0.1 * math.cos(5 * h), 3.6 * s, 2.6 * s, 0, bc, 0.75)
            a.line(f"M{f(x - 2.4 * s)},{f(y - 7.4 * s)} Q{f(x)},{f(y - 6.2 * s)} {f(x + 2.4 * s)},{f(y - 7.4 * s)}", 0.4, 0.5)
    for (x, y), cap, s_ in (((30, 36), False, 1.0), ((60, 44), True, 1.15), ((34, 58), False, 0.9), ((54, 70), False, 0.8)):
        flower(x, y, cap, s_)
    return a


def fl_kiwi(a, sp):
    """Kiwi: a nodding cup of five separate, round, thick white petals,
    hanging under the leaves on a short stalk, seen from a little below so the
    inside shows: many stamens with dark purple-black anthers round a white
    ovary topped with a star of thread-like white styles."""
    fc = sp["fc"]; c = (50, 56); R = 27; k = 0.6; M = tilt(c[1], k)
    import leaves_flowers as LFW
    src, own = LFW.own_leaf("kiwi")
    a.ribbon((6, 12), (40, 6), (94, 12), 3.0, 2.4, "bark", lw=0.9)
    a.place(src, 70, 10, 52, 0.36, lw=0.9)
    a.ribbon((40, 8), (40, 20), (c[0], c[1] - R * k * 0.95), 2.2, 1.8, sp.get("stalkc", "leaf"), lw=0.9)
    for i in range(5):   # small round green sepals, between the petals at the back
        petal(a, c[0], c[1], -90 + 72 * (i + 0.5), R * 0.62, R * 0.4, "leaf", "lobe", M=M, lw=0.7, lines=False)
    order = sorted(range(5), key=lambda i: math.sin(math.radians(-90 + 72 * i)))
    for i in order:   # five separate round petals, cupped: the near ones a little foreshortened
        ang = -90 + 72 * i
        petal(a, c[0], c[1], ang, R * (0.92 if math.sin(math.radians(ang)) > 0.3 else 1.0), R * 0.86, fc, "petal", M=M, lw=0.9,
              shade=0.07 + (0.07 if math.sin(math.radians(ang)) > 0.3 else 0))
    a.oval(c[0], c[1], R * 0.4, R * 0.4 * k, 0, "pale", 0)
    stamen_ring(a, c[0], c[1], R * 0.16, R * 0.44, 34, sp.get("cen", "dark"), M, lw=0.45, ar=1.05)
    a.oval(c[0], c[1], R * 0.17, R * 0.17 * k, 0, "white", 0.7)
    for i in range(12):   # the star of thread-like white styles
        e = M(T(*c, i * 30)(R * 0.22))
        a.line(f"M{f(c[0])},{f(c[1])} L{P(e)}", 0.9, 0.7)
        a.line(f"M{f(c[0])},{f(c[1])} L{P(e)}", 0.5, 1.0, "white")
    a.line("M24,9 Q16,18 18,34", 1.0, 0.85)
    bud(a, 18, 34, 92, 11, fc, "leaf")
    return a


def shifted(src, dx, dy):
    """A copy of a drawing moved dx, dy, every line and colour as it was."""
    import re
    a = Art()
    def mv(d):
        out = []
        for cmd, nums in re.findall(r"([MLCQTZmlcqtz])([^MLCQTZmlcqtz]*)", d):
            v = [float(n) for n in re.findall(r"-?\d*\.?\d+(?:e-?\d+)?", nums)]
            if cmd.isupper():
                v = [x + (dx if i % 2 == 0 else dy) for i, x in enumerate(v)]
            out.append(cmd + " ".join(f(n) for n in v))
        return " ".join(out)
    for it, layer in zip(src.items, src.lay):
        a.layer = layer
        a._add(("dot", it[1] + dx, it[2] + dy, it[3], it[4]) if it[0] == "dot" else (it[0], mv(it[1])) + tuple(it[2:]))
    return a


def fl_lacecap(a, sp):
    """Hydrangea: the shared lacecap drawing (leaves_flowers.fl_mop), lifted
    two squares so its stalk stays inside the tile."""
    import leaves_flowers as LFW
    return shifted(LFW.fl_mop(Art(), sp), 0, -2.5)


BLOOM_DRAW = {"fruit_lacecap": fl_lacecap, "fruit_rosa": fl_rosa, "fruit_blossom": fl_blossom, "fruit_strig": fl_strig, "fruit_goose": fl_goose,
              "fruit_honey": fl_honey, "fruit_rose": fl_rose, "fruit_corymb": fl_corymb, "fruit_olive": fl_olive,
              "fruit_rubus": fl_rubus_nod, "fruit_grape": fl_grape, "fruit_kiwi": fl_kiwi}

BLOOMX = {
    "strawberry": dict(kind="fruit_rosa", fc="white", cen="primrose", R=29, pw=0.84, ns=22, anth="sun", dome=0.25,
                       sepals=[(5, 0.92, 0.24, 0.5), (5, 0.62, 0.14, 0.32)], sr=0.4),
    "apple": dict(kind="fruit_blossom", lay="spur", fc="white", tinge="pink", budc="pink", budl=11, anth="sun", pw=0.84, styles=5,
                  sepc="sage", sepl=1.04, sepw=0.22, lc="leaf", lteeth=14),
    "pear": dict(kind="fruit_blossom", lay="pear", fc="white", anth="beet", pw=0.7, styles=5, budc="white", lc="deep",
                 lpf="broad", lw_=0.66, lteeth=24, leaves=[(-160, 18), (-20, 20)]),
    "plum": dict(kind="fruit_blossom", lay="along", fc="white", anth="primrose", pw=0.82, styles=1, ns=24, sr=0.56,
                 r=12, per=2, tinyleaves=True, wood="bark"),
    "nectarine": dict(kind="fruit_blossom", lay="bare", fc="pink", anth="carrot", fil="beet", pw=0.9, styles=1, ns=24, sr=0.5,
                      r=14, cup="pink", wood="beet", ark=0.075, spots=[(0.2, 1), (0.44, -1), (0.66, 1), (0.86, -1)]),
    "olive-tree": dict(kind="fruit_olive", fc="white", cen="primrose"),
    "bristol-whitebeam": dict(kind="fruit_corymb", fc="white", anth="primrose", r=6.6, m=26, leaf="bristol-whitebeam", sepc="sage"),
    "blackcurrant": dict(kind="fruit_strig", form="bell", fc="pink", cen="pear", nf=6, leaf="blackcurrant", swing=8, leafang=-8, leafk=0.38, drop=84),
    "whitecurrant": dict(kind="fruit_strig", form="saucer", fc="pear", cen="plum", nf=8, leaf="whitecurrant", swing=6, nodex=40, leafang=-8, leafk=0.38, drop=84),
    "blueberry": dict(kind="fruit_strig", form="urn", fc="white", nf=6, leaf="blueberry", swing=10, leafang=-14, leafk=0.42, drop=80),
    "gooseberry": dict(kind="fruit_goose", fc="beet", cen="white"),
    "honeyberry": dict(kind="fruit_honey", fc="primrose", lc="sage"),
    "rose": dict(kind="fruit_rose", fc="pink", cen="sun"),
    "hydrangea": dict(kind="fruit_lacecap", fc="pink", lacecap=True, fertile="mauve"),
    "japanese-spiraea": dict(kind="fruit_corymb", fc="mauve", anth="pink", r=4.6, m=46, fluffy=True, leaf="japanese-spiraea", stemc="rust"),
    "raspberry": dict(kind="fruit_rubus", fc="white", cen="pale", sepc="sage", pl=14, pw=6.0),
    "japanese-wineberry": dict(kind="fruit_rubus", fc="white", cen="pale", sepc="beet", bristly="beet", sepl=24, sepw=6,
                               pl=13, pw=5.4, budc="beet", cup=True),
    "blackberry": dict(kind="fruit_rosa", fc="white", cen="pale", R=30, pw=0.78, crinkle=0.9, ns=34, anth="white", fil="pink",
                       sr=0.44, dome=0.2, sepc="sage", sepals=[(5, 1.06, 0.2, 0.5)], budc="pink", twist=3),
    "loganberry": dict(kind="fruit_rosa", fc="white", cen="pale", R=30, pw=0.74, ns=30, anth="white", sr=0.44, dome=0.22,
                       sepc="sage", sepals=[(5, 0.66, 0.2, 0.5)]),
    "grape": dict(kind="fruit_grape", fc="pale", cen="primrose"),
    "kiwi": dict(kind="fruit_kiwi", fc="white", cen="dark", stalkc="berry"),
}


# ============================================================ life stages: helpers
_OWN = {}


def own(a, kind, x, y, ang, L, fill=None, detail=None, lw=None):
    """The kind's own close-up leaf, drawn L long at x,y pointing along ang
    (as plants_all.own_leaf does). fill swaps its colour (autumn, winter)."""
    import leaves_flowers as LFW
    if kind not in _OWN:
        _OWN[kind] = LFW.own_leaf(kind)
        if LEAFX.get(kind, {}).get("base"):   # the close-up's stalk was moved: place from where it now starts
            _OWN[kind][0].anchor = LEAFX[kind]["base"]
    src, of = _OWN[kind]
    rec = {of: fill} if fill and fill != of else None
    with a.on(LEAF):
        a.place(src, x, y, ang, L / 92, lw=lw or (0.7 if L < 16 else 0.9), detail=(L >= 14) if detail is None else detail, fills=rec)


def pal(kind):
    """The kind's colours from its description (read here directly, as
    plants_all.palette does, so this file need not import plants_all)."""
    import json, os
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "Design", "Plants", "descriptions", f"{kind}.json")
    with open(p, encoding="utf-8") as fh:
        return json.load(fh).get("palette", {})


def limb(a, p0, c, p1, w0, w1, col="bark"):
    """A branch drawn as a band of bark that narrows towards its end."""
    return a.ribbon(p0, c, p1, w0, w1, col, lw=0.9)


def twigs(a, x, y, ang, L, depth, lw, spread=26, col="line", la=0.9):
    """Thin twigs forking from x,y (like plants.fork, but in any colour)."""
    e = T(x, y, ang)(L); m = T(x, y, ang + (6 if depth % 2 else -6))(L * 0.5)
    a.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)}", lw, la, col)
    if depth:
        twigs(a, e[0], e[1], ang - spread, L * 0.74, depth - 1, lw * 0.7, spread, col, la)
        twigs(a, e[0], e[1], ang + spread * 0.9, L * 0.7, depth - 1, lw * 0.7, spread, col, la)
    return e


def spurs(a, q, us, L=2.8, bud="bark", br=0.9, side=1, col="line", knob=True, w=1.1):
    """Short knobbly spur shoots along a branch q, each ending in a bud."""
    out = []
    for i, u in enumerate(us):
        x, y = q.pt(u); sd = side * (1 if i % 2 else -1)
        ang = q.ang(u) + sd * 70
        e = T(x, y, ang)(L)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", w, 0.9, col)
        if knob:
            a.line(f"M{P(T(x, y, ang)(L * 0.45))} l{f(math.cos(math.radians(ang + 90)) * 0.9)},{f(math.sin(math.radians(ang + 90)) * 0.9)}", 0.6, 0.7, col)
        if bud:
            a.oval(*T(x, y, ang)(L + br * 0.8), br * 0.8, br, ang + 90, bud, 0.5)
        out.append((e, ang))
    return out


def crown(a, kind, cx, cy, rx, ry, n=34, L=9.0, fill=None, blob=None, seed=0.0, edge=1.0, backs=None):
    """A head of leaves: a soft shape of the leaf colour, covered with the
    kind's own leaves drawn small, those round the edge pointing outwards so
    the outline is leafy."""
    lc = fill or pal(kind).get("leaf", "leaf")
    if blob is not False:
        a.polar(cx, cy, lambda th: 1 + 0.05 * math.cos(7 * th + seed) + 0.03 * math.sin(11 * th), rx * 0.9, ry * 0.9, 0, blob or lc)
    pts = []
    for k in range(n):
        rr = math.sqrt((k + 0.5) / n) * edge; th = k * GOLD + seed
        pts.append((cx + rx * 0.92 * rr * math.cos(th), cy + ry * 0.92 * rr * math.sin(th), th, rr))
    for i, (x, y, th, rr) in enumerate(sorted(pts, key=lambda p: p[3])):
        ang = math.degrees(th) if rr > 0.55 else -90 + 70 * math.sin(th * 3)
        own(a, kind, x, y, ang, L * (0.9 + 0.2 * rr), backs[0] if backs and i % backs[1] == 1 else fill)
    return pts


def ground(a, y=88):
    a.ground(y)
    return a


# ---- fruit shapes
def apple_fruit(a, x, y, r, col="berry", flush=None):
    """An apple hanging from x,y: round, a little flattened, the stalk sunk
    in a hollow. flush: a patch of a second colour low on one side (the
    yellow-green showing under the red)."""
    a.oval(x, y + r * 0.95, r * 1.05, r * 0.95, 0, col, 0.85)
    if flush:
        a.oval(x + r * 0.42, y + r * 1.25, r * 0.45, r * 0.38, -30, flush, 0)
    a.line(f"M{f(x - r * 0.35)},{f(y + r * 0.3)} Q{f(x)},{f(y + r * 0.62)} {f(x + r * 0.35)},{f(y + r * 0.3)}", 0.6, 0.5)   # the hollow
    a.line(f"M{f(x)},{f(y + r * 0.45)} L{f(x + 0.4)},{f(y - r * 0.25)}", 0.8, 0.9)
    a.line(f"M{f(x - r * 0.55)},{f(y + r * 0.9)} Q{f(x - r * 0.7)},{f(y + r * 1.3)} {f(x - r * 0.45)},{f(y + r * 1.6)}", 0.5, 0.3, "white")


def pear_fruit(a, x, y, r, col="pear", russet=True):
    """A pear hanging from its long stalk at x,y: narrow at the top, broad below."""
    a.line(f"M{f(x)},{f(y)} L{f(x - 0.3)},{f(y + r * 0.9)}", 0.8, 0.9)
    y += r * 0.8
    a.shape(f"M{f(x)},{f(y)} C{f(x + r * 0.6)},{f(y + r * 0.1)} {f(x + r * 0.45)},{f(y + r * 0.9)} {f(x + r)},{f(y + r * 1.6)} "
            f"C{f(x + r * 1.3)},{f(y + r * 2.6)} {f(x - r * 1.3)},{f(y + r * 2.6)} {f(x - r)},{f(y + r * 1.6)} "
            f"C{f(x - r * 0.45)},{f(y + r * 0.9)} {f(x - r * 0.6)},{f(y + r * 0.1)} {f(x)},{f(y)} Z", col, 0.85)
    if russet:
        a.oval(x + r * 0.35, y + r * 1.75, r * 0.4, r * 0.3, 20, "bark", 0, la=0)
    a.dot(x, y + r * 2.28, max(0.35, r * 0.12), "bark")


def plum_fruit(a, x, y, r, col="plum"):
    """A plum: oval, matt under a pale grey-blue waxy bloom, with a groove
    (the suture) down one side."""
    a.line(f"M{f(x)},{f(y)} L{f(x + 0.2)},{f(y + r * 0.5)}", 0.7, 0.9)
    a.oval(x, y + r * 1.55, r * 0.92, r * 1.25, 6, col, 0.85)
    a.shape(path([(x - r * 0.12 + r * 0.68 * math.cos(h), y + r * 1.4 + r * 0.93 * math.sin(h)) for h in [2 * math.pi * i / 20 for i in range(20)]]), "blue", 0, fa=0.45)   # the bloom
    a.line(f"M{f(x + r * 0.3)},{f(y + r * 0.42)} Q{f(x + r * 0.62)},{f(y + r * 1.55)} {f(x + r * 0.26)},{f(y + r * 2.7)}", 0.8, 0.85)   # the groove


def round_fruit(a, x, y, r, col, stalk=True, shine=True):
    if stalk:
        a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y + r * 0.2)}", 0.7, 0.9)
    a.oval(x, y + r, r, r, 0, col, 0.8)
    if shine and r > 1.6:
        a.dot(x - r * 0.35, y + r * 0.62, max(0.3, r * 0.2), "white")


# ============================================================ fruit trees
SPOTS = [(-20, -6), (-9, -15), (5, -17), (17, -9), (22, 3), (9, -3), (-4, -3), (-15, 7), (-1, 10), (12, 12), (-24, 2)]


def in_crown(cx, cy, rx, ry, n=11, k=0.8, seed=0.6):
    return [(cx + rx * k * math.sqrt((j + 0.5) / n) * math.cos(j * GOLD + seed), cy + ry * k * math.sqrt((j + 0.5) / n) * math.sin(j * GOLD + seed)) for j in range(n)]


def frame(a, form, bark="bark", young=None):
    """The trunk and main branches of a tree. Returns the branches (as
    curves) and the crown's centre and size."""
    qs = []
    if form == "round":      # apple, plum: a rounded, spreading crown
        a.ribbon((50, 88), (49.4, 74), (50, 60), 6.4, 4.6, bark)
        for p0, c, p1, w0, w1 in [((49, 63), (42, 57), (29, 47), 3.6, 1.8), ((51, 62), (58, 56), (71, 46), 3.6, 1.8),
                                  ((50, 61), (49, 48), (51, 31), 3.4, 1.6), ((48, 61), (40, 52), (36, 34), 2.6, 1.4),
                                  ((52, 61), (60, 50), (64, 33), 2.6, 1.4)]:
            qs.append(limb(a, p0, c, p1, w0, w1, bark))
        return qs, (50, 40, 33, 25)
    if form == "upright":    # pear: narrower, the branches rising steeply
        a.ribbon((50, 88), (49.5, 76), (50, 62), 6.0, 4.4, bark)
        for p0, c, p1, w0, w1 in [((49, 65), (43, 55), (38, 36), 3.4, 1.6), ((51, 65), (57, 55), (62, 35), 3.4, 1.6),
                                  ((50, 63), (50, 46), (50, 26), 3.4, 1.5), ((49, 69), (41, 63), (32, 52), 2.4, 1.3),
                                  ((51, 69), (59, 63), (68, 52), 2.4, 1.3)]:
            qs.append(limb(a, p0, c, p1, w0, w1, bark))
        return qs, (50, 44, 24, 27)
    if form == "fan":        # nectarine: trained flat as a fan against a wall
        for wy in (30, 46, 62):
            a.line(f"M10,{wy} L90,{wy}", 0.6, 0.45)
        a.ribbon((50, 88), (50, 82), (50, 75), 5.2, 4.4, bark)
        for sg in (-1, 1):
            arm = limb(a, (50, 76), (50 + sg * 8, 68), (50 + sg * 20, 58), 3.6, 2.6, bark); qs.append(arm)
            for ang, L in ((-90 + sg * 6, 42), (-90 + sg * 26, 38), (-90 + sg * 46, 29), (-90 + sg * 64, 19)):
                e = T(50 + sg * 20, 58, ang)(L); o = (50 + sg * 20, 58)
                q = Quad(o, T(*o, ang)(L * 0.5), e)
                a.ribbon(o, T(*o, ang)(L * 0.25), q.pt(0.5), 2.4, 1.6, bark)   # the older wood of the rib
                a.ribbon(q.pt(0.5), q.pt(0.75), e, 1.4, 0.8, young or bark, lw=0.8)   # last year's shoot: red on a nectarine
                qs.append(q)
        return qs, (50, 40, 38, 26)
    if form == "olive":      # olive: a short gnarled grey trunk, a dense rounded head
        a.ribbon((48, 88), (54, 76), (48, 64), 6.0, 4.6, bark)
        a.line("M47,86 Q52,77 47.6,67", 0.6, 0.4); a.line("M50.6,84 Q55,76 50.4,66", 0.6, 0.4)
        for p0, c, p1, w0, w1 in [((48, 66), (42, 58), (34, 48), 3.0, 1.6), ((49, 65), (56, 56), (66, 46), 3.0, 1.6),
                                  ((48, 65), (48, 54), (50, 38), 2.8, 1.4)]:
            qs.append(limb(a, p0, c, p1, w0, w1, bark))
        return qs, (50, 40, 30, 23)
    if form == "whitebeam":  # compact rounded crown on upright branches, smooth grey bark
        a.ribbon((50, 88), (49.6, 72), (50, 56), 5.6, 4.2, bark)
        for p0, c, p1, w0, w1 in [((49, 59), (43, 48), (38, 30), 3.0, 1.4), ((51, 59), (57, 48), (62, 30), 3.0, 1.4),
                                  ((50, 57), (50, 42), (50, 20), 3.0, 1.4)]:
            qs.append(limb(a, p0, c, p1, w0, w1, bark))
        return qs, (50, 38, 27, 27)
    if form == "fig":        # fig: several thick, stubby grey stems from the base, spreading wide
        for p0, c, p1, w0, w1 in [((46, 88), (38, 72), (22, 52), 5.0, 3.2), ((54, 88), (62, 72), (78, 52), 5.0, 3.2),
                                  ((49, 88), (46, 66), (40, 40), 4.6, 3.0), ((51, 88), (55, 66), (61, 38), 4.6, 3.0)]:
            qs.append(limb(a, p0, c, p1, w0, w1, bark))
        return qs, (50, 44, 38, 26)
    if form == "ginkgo":     # a gaunt young tree: a straight leader, a few stiff, almost level branches
        q = a.ribbon((50, 88), (50, 50), (50, 12), 4.4, 1.6, bark); qs.append(q)
        for y, sd, L in ((64, -1, 26), (56, 1, 28), (44, -1, 22), (36, 1, 20), (25, -1, 14), (19, 1, 12)):
            qs.append(limb(a, (50, y), (50 + sd * L * 0.5, y - 1.5), (50 + sd * L, y - 4), 2.2, 1.0, bark))
        return qs, (50, 40, 30, 32)
    raise KeyError(form)


TREE = {
    # form, bark colour, crown leaf size, number of leaves
    "apple": dict(form="round", bark="bark", L=8.6, n=40),
    "pear": dict(form="upright", bark="bark", L=8.6, n=40),
    "plum": dict(form="round", bark="fruit_greybark", L=8.6, n=40),
    "nectarine": dict(form="fan", bark="beet", L=11, n=0),
    "olive-tree": dict(form="olive", bark="fruit_greybark", L=7.5, n=56),
    "bristol-whitebeam": dict(form="whitebeam", bark="fruit_greybark", L=8.6, n=40, backs=("sage", 3)),   # grey-felted backs
    "fig": dict(form="fig", bark="fruit_greybark", L=15, n=16),
    "gingko": dict(form="ginkgo", bark="bark", L=8, n=0),
}


def young_tree(kind, arms=((0.5, 1, 18, 9), (0.6, -1, 16, 10), (0.72, 1, 12, 9)), stake=True, L=10.5, opp=False, leader=22):
    """A young tree a year or two after planting: a single straight stem
    tied to a stake, a few side branches (arms: where up the stem, which
    side, how long, how much they rise) and the kind's own leaves."""
    cf = TREE[kind]; a = Art(); ground(a)
    if stake:
        a.ribbon((60, 88), (60, 70), (60, 52), 2.4, 2.4, "bark")
        a.line("M50.6,70 Q55,68 60,70", 1.2, 0.9, "soil")
    q = a.ribbon((50, 88), (49.4, 56), (50, leader), 3.0, 1.6, cf["bark"])
    a.oval(50, 81, 2.1, 1.5, 0, cf["bark"], 0.8)   # the graft union
    tips = []
    for u, sd, ln, rise in arms:
        x, y = q.pt(u); e = (x + sd * ln, y - rise)
        a.ribbon((x, y), (x + sd * ln * 0.45, y - rise * 0.3), e, 1.7, 0.9, cf["bark"], lw=0.8); tips.append((x, y, e, sd))
    with a.group():
        for x, y, e, sd in tips:
            bq = Quad((x, y), (x + (e[0] - x) * 0.45, y - (y - e[1]) * 0.3), e)
            for j, v in enumerate((0.45, 0.78, 1.0)):
                px, py = bq.pt(v)
                ang = -90 + sd * (30 if j == 2 else (60 if j % 2 else 120))
                own(a, kind, px, py, ang, L * (0.95 - 0.08 * j))
                if opp and j < 2:
                    own(a, kind, px, py, ang + sd * (60 if j % 2 else -60), L * (0.85 - 0.08 * j))
        lead = (0.66, 0.79, 0.91) if not opp else (0.78, 0.9)
        for i, u in enumerate(lead):   # alternate up the leader, one at a time, well spaced
            x, y = q.pt(u); sd = -1 if i % 2 else 1
            own(a, kind, x, y, -90 + sd * 52, L * (1 - 0.08 * i))
            if opp:
                own(a, kind, x, y, -90 - sd * 52, L * (1 - 0.08 * i))
        own(a, kind, 50, leader, -84 if not opp else -90, L * 0.72)
    return a


def bare_tree(kind, bud="seed", br=1.0, spur_us=(0.35, 0.55, 0.75), twig_depth=2, extra=None):
    """A tree in winter: the trunk and branches, thin twigs at their ends,
    and short knobbly spurs along the branches with buds on them."""
    cf = TREE[kind]; a = Art(); ground(a)
    qs, (cx, cy, rx, ry) = frame(a, cf["form"], cf["bark"])
    for q in qs:
        e = q.pt(1); ang = q.ang(1)
        twigs(a, e[0], e[1], ang - 14, 8, twig_depth, 1.0, 24)
        twigs(a, e[0], e[1], ang + 18, 7, twig_depth - 1, 0.9, 24)
    out = []
    for q in qs:
        out += spurs(a, q, spur_us, 3.0, bud, br)
    if extra:
        extra(a, qs, out)
    return a


def leafy_tree(kind, stage, spots_fn=None, n=None, L=None, blob=None, fill=None):
    """A tree in leaf: trunk and branches, a head of its own leaves, and
    whatever the stage adds (spots_fn draws flowers or fruit at points in
    the crown)."""
    cf = TREE[kind]; a = Art(); ground(a)
    qs, (cx, cy, rx, ry) = frame(a, cf["form"], cf["bark"])
    crown(a, kind, cx, cy, rx, ry, n or cf["n"], L or cf["L"], fill=fill, blob=blob, backs=cf.get("backs"))
    if spots_fn:
        spots_fn(a, cx, cy, rx, ry)
    return a


def blossom_cluster(a, x, y, kind, s=1.0):
    """A cluster of blossom at a spur tip, drawn small for the whole tree."""
    sp = dict(BLOOMX[kind])
    if kind == "apple":
        for dx, dy, r in ((0, 0, 3.6), (-3.4, 2.4, 3.0), (3.4, 2.2, 3.0)):
            blossom_flower(a, x + dx * s, y + dy * s, r * s, dict(sp, ns=8, sr=0.4), start=-90 + dx * 10, k=0.9)
        a.oval(x + 1.6 * s, y - 3.6 * s, 1.1 * s, 1.5 * s, 20, "pink", 0.5)   # a deep pink bud
    elif kind == "pear":
        for dx, dy, r in ((0, -1.6, 2.8), (-3.2, 1.0, 2.8), (3.2, 1.0, 2.8), (0, 3.0, 2.6)):
            blossom_flower(a, x + dx * s, y + dy * s, r * s, dict(sp, ns=7, sr=0.42, pw=0.74), start=-90 + dx * 10, k=0.9)


def edge_spots(cx, cy, rx, ry, n=8, k=0.9, a0=-170, a1=-10):
    """n points spaced round the crown's edge, from angle a0 to a1 (the top
    half): where fruitlets stand out clear of the leaves."""
    return [(cx + rx * k * math.cos(math.radians(g)), cy + ry * k * math.sin(math.radians(g)), g)
            for g in [a0 + (a1 - a0) * i / (n - 1) for i in range(n)]]


def fruitlets(a, kind, cx, cy, rx, ry, n=8):
    """Fruit set on a tree: a few clear clusters of young fruit standing out on
    their stalks round the edge of the crown, in pale green with a firm
    outline so they read against the leaves even when drawn small."""
    with a.on(BLOOM):
        for j, (x, y, g) in enumerate(edge_spots(cx, cy, rx, ry, n, 0.92)):
            out = 90 - 30 * math.cos(math.radians(g)) if kind == "plum" else g   # plum: hanging on short stalks
            for d in ((-26, 0, 26) if j % 2 == 0 else (-17, 17)):
                stl = {"pear": 8.0, "plum": 3.4, "bristol-whitebeam": 3.6}.get(kind, 5.0)
                e = T(x, y, out + d)(stl)
                a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.8, 0.95)
                if kind == "plum":   # on the deep green crown a mid green reads; elsewhere pale
                    c = T(*e, out + d)(2.4); a.oval(c[0], c[1], 2.1, 2.8, out + d + 90, "unripe", 1.0)
                elif kind == "bristol-whitebeam":
                    c = T(*e, out + d)(1.9); a.oval(c[0], c[1], 1.9, 1.9, 0, "pale", 0.95)
                    a.dot(*T(*c, out + d)(1.6), 0.45, "bark")
                elif kind == "pear":
                    c = T(*e, out + d)(3.0); a.oval(c[0], c[1], 2.2, 3.1, out + d + 90, "unripe", 1.0)
                    a.dot(*T(*c, out + d)(3.0), 0.6, "bark")   # the dried sepals at the tip
                else:
                    c = T(*e, out + d)(2.9); a.oval(c[0], c[1], 2.9, 2.8, 0, "pale", 1.0)
                    a.dot(*T(*c, out + d)(2.8), 0.6, "bark")


def apple_like(kind):
    """The life stages of apple, pear and plum, which differ only in detail."""
    lc = pal(kind).get("leaf", "leaf"); fr = pal(kind).get("fruit", "berry")

    def flower():
        if kind == "plum":   # small white flowers crowded along the bare branches, the first leaves just showing
            a = bare_tree(kind, bud=None, spur_us=(), twig_depth=2)
            qs, _ = frame(Art(), TREE[kind]["form"], "bark")
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.3, 0.45, 0.6, 0.75, 0.9)):
                    x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                    for m in range(1 + (j % 2)):
                        e = T(x, y, q.ang(u) + sd * (60 + 40 * m))(2.6)
                        blossom_flower(a, e[0], e[1], 2.9, dict(BLOOMX["plum"], ns=8, sr=0.5), start=-90 + j * 20, k=0.9)
                    if j % 2 == 0:
                        own(a, kind, x, y, q.ang(u) - sd * 80, 4.6, detail=False)
            # blossom on the twigs too
            for q in qs:
                e = q.pt(1)
                for k_ in range(3):
                    p = T(*e, q.ang(1) + (k_ - 1) * 30)(5 + k_ * 2)
                    blossom_flower(a, p[0], p[1], 2.7, dict(BLOOMX["plum"], ns=8), start=-90 + k_ * 30, k=0.9)
            return a
        a = Art(); ground(a); cf = TREE[kind]
        qs, (cx, cy, rx, ry) = frame(a, cf["form"], cf["bark"])
        for q in qs:   # the young leaves are only just opening: the branches show through
            e = q.pt(1); twigs(a, e[0], e[1], q.ang(1) - 14, 7, 1, 0.9, 26)
        pts = in_crown(cx, cy, rx, ry, 18, 0.92, 0.3)
        for j, (x, y) in enumerate(pts):
            for sg in (-1, 1):
                own(a, kind, x, y + 1, -90 + sg * 55 + j * 7, 6.4, detail=False)
        for j, (x, y) in enumerate(in_crown(cx, cy, rx, ry, 13, 0.86, 1.4)):
            blossom_cluster(a, x, y, kind, 1.0)
        return a

    def set_():
        return leafy_tree(kind, "set", lambda a, cx, cy, rx, ry: fruitlets(a, kind, cx, cy, rx, ry))

    def crop():
        def sp(a, cx, cy, rx, ry):
            for j, (x, y) in enumerate(in_crown(cx, cy, rx, ry, 11, 0.82)):
                if j % 5 == 4:
                    continue
                if kind == "apple":
                    apple_fruit(a, x, y - 1, 3.5, fr, flush="unripe" if j % 3 == 0 else None)
                elif kind == "pear":
                    pear_fruit(a, x, y - 3, 3.4, fr)
                else:
                    plum_fruit(a, x, y - 2, 3.4, fr)   # hanging singly on short stalks
            if kind == "apple":
                apple_fruit(a, 72, 80.5, 3.4, fr)   # a windfall
        return leafy_tree(kind, "crop", sp)

    def dormant():
        if kind == "plum":   # clusters of small round flower buds on the spurs
            def ex(a, qs, out):
                for (e, ang) in out:
                    for d in (-40, 40):
                        a.oval(*T(*e, ang + d)(1.6), 0.7, 0.7, 0, "bark", 0.4)
            return bare_tree(kind, bud="bark", br=0.8, extra=ex)
        if kind == "pear":   # plump, pointed, shiny brown buds
            return bare_tree(kind, bud="bark", br=1.1, spur_us=(0.3, 0.5, 0.7, 0.86))
        return bare_tree(kind, bud="seed", br=1.25)   # apple: fat, rounded, downy buds

    arms = {"pear": ((0.46, 1, 8, 21), (0.56, -1, 7, 20), (0.68, 1, 6, 16))}.get(kind, ((0.46, 1, 18, 9), (0.56, -1, 16, 10), (0.7, 1, 12, 9)))
    return {"young": lambda: young_tree(kind, arms), "dormant": dormant, "flower": flower, "set": set_, "crop": crop}


STAGE = {}
for _k in ("apple", "pear", "plum"):
    STAGE[_k] = apple_like(_k)


def nectarine_stages():
    """Nectarine, trained as a fan on wires against a wall."""
    kind = "nectarine"; fr = pal(kind).get("fruit", "berry")

    def ribs(a):
        qs, _ = frame(a, "fan", "bark", young="beet")   # grey-brown old wood, red young shoots
        return qs[1:5] + qs[6:10]   # the ribs, not the two arms

    def leaves(a, qs, us=(0.35, 0.6, 0.85), L=11):
        with a.group():
            for q in qs:
                for j, u in enumerate(us):
                    x, y = q.pt(u); sd = 1 if j % 2 else -1
                    own(a, kind, x, y, 90 + sd * 38 + (q.ang(u) + 90) * 0.3, L)   # long narrow leaves, drooping
                e = q.pt(1); own(a, kind, e[0], e[1], q.ang(1) + (-24 if e[0] > 50 else 24), L * 0.8)   # the tip leaf turned up, inside the tile

    def young():
        a = Art(); ground(a)
        for wy in (30, 46, 62):
            a.line(f"M10,{wy} L90,{wy}", 0.6, 0.45)
        a.ribbon((50, 88), (50, 82), (50, 75), 4.0, 3.4, "bark")
        qs = []
        for sg in (-1, 1):
            for ang, L in ((-90 + sg * 24, 30), (-90 + sg * 58, 26)):
                qs.append(limb(a, (50, 76), T(50, 76, ang)(L * 0.5), T(50, 76, ang)(L), 2.0, 1.0, "beet"))
        leaves(a, qs, (0.4, 0.75), 11)
        return a

    def dormant():
        a = Art(); ground(a); qs = ribs(a)
        for q in qs:
            for u in (0.55, 0.72, 0.9):   # small dark buds in threes on the young shoots: a round flower bud either side of a slim leaf bud
                x, y = q.pt(u); ang = q.ang(u) - 90
                a.oval(*T(x, y, ang)(1.3), 0.45, 0.9, ang + 90, "bark", 0.4)
                for d in (-1, 1):
                    a.oval(*T(x, y, ang + d * 45)(1.2), 0.6, 0.6, 0, "beet", 0.4)
        return a

    def flower():
        a = Art(); ground(a); qs = ribs(a)
        sp = dict(BLOOMX[kind], ns=8, sr=0.5)
        for q in qs:   # pink flowers tight along the bare shoots, before the leaves
            for j, u in enumerate((0.24, 0.4, 0.56, 0.72, 0.88)):
                x, y = q.pt(u); sd = 1 if j % 2 else -1
                e = T(x, y, q.ang(u) + sd * 90)(1.6)
                blossom_flower(a, e[0], e[1], 3.0, sp, start=-90 + j * 25, k=0.9)
        return a

    def fruit(setting):
        def draw():
            a = Art(); ground(a); qs = ribs(a)
            leaves(a, qs)
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.48, 0.78)):
                    if (qi + j) % 3 == 2:
                        continue
                    x, y = q.pt(u); sd = 1 if (qi + j) % 2 else -1
                    c = T(x, y, q.ang(u) + sd * 90)(2.4 if setting else 3.4)
                    if setting:   # small smooth green fruitlets, tight against the shoot
                        a.oval(c[0], c[1], 2.0, 2.2, 0, "pale", 0.85)
                    else:         # round, smooth and shiny, red over yellow, sitting close against the shoot
                        a.oval(c[0], c[1], 3.4, 3.3, 0, "primrose", 0.85)
                        a.shape(path([(c[0] + 3.3 * math.cos(h), c[1] + 3.2 * math.sin(h)) for h in [math.radians(-200 + 240 * i / 24) for i in range(25)]]), fr, 0)
                        a.line(f"M{f(c[0] - 0.4)},{f(c[1] - 3)} Q{f(c[0] + 0.6)},{f(c[1])} {f(c[0] - 0.2)},{f(c[1] + 3)}", 0.5, 0.4)
                        a.dot(c[0] - 1.2, c[1] - 1.2, 0.6, "white")
            return a
        return draw

    return {"young": young, "dormant": dormant, "flower": flower, "set": fruit(True), "crop": fruit(False)}


def olive_leaves(a, cx, cy, rx, ry, n=46, L=8.5, seed=0.3):
    """The olive's head of narrow, silvery grey-green leaves: some turned to
    show their silver backs (white)."""
    for k in range(n):
        rr = math.sqrt((k + 0.5) / n); th = k * GOLD + seed
        x, y = cx + rx * 0.92 * rr * math.cos(th), cy + ry * 0.92 * rr * math.sin(th)
        ang = math.degrees(th) if rr > 0.5 else -90 + 70 * math.sin(th * 3)
        with a.on(LEAF):
            leaflet(a, x, y, ang, L, L * 0.2, "white" if k % 4 == 1 else "sage", PROFS["oval"], veins=0, lw=0.6, midw=0.4, shade=0)


def olive_stages():
    kind = "olive-tree"; fr = pal(kind).get("fruit", "dark")

    def head(a):
        qs, (cx, cy, rx, ry) = frame(a, "olive", "fruit_greybark")
        a.polar(cx, cy, lambda th: 1 + 0.05 * math.cos(7 * th) + 0.03 * math.sin(11 * th), rx * 0.88, ry * 0.88, 0, "sage")
        olive_leaves(a, cx, cy, rx, ry)
        return cx, cy, rx, ry

    def pair_leaves(a, q, us, L=9.5):
        """Narrow leaves in opposite pairs along a twig, one of some pairs
        turned to show its silver underside."""
        with a.on(LEAF):
            for j, u in enumerate(us):
                x, y = q.pt(u); ang = q.ang(u)
                for sg in (-1, 1):
                    leaflet(a, x, y, ang + sg * 50, L, L * 0.2, "white" if (sg > 0 and j % 2) else "sage", PROFS["oval"],
                            veins=0, lw=0.65, midw=0.45, shade=0)
            e = q.pt(1)
            leaflet(a, e[0], e[1], q.ang(1), L * 0.8, L * 0.16, "sage", PROFS["oval"], veins=0, lw=0.65, midw=0.45, shade=0)

    def young():   # a short grey trunk, branching into a few twigs that carry paired narrow leaves
        a = Art(); ground(a)
        a.ribbon((62, 88), (62, 72), (62, 56), 2.4, 2.4, "bark"); a.line("M51,72 Q56,70 62,72", 1.2, 0.9, "soil")
        a.ribbon((50, 88), (49, 74), (50, 60), 3.6, 2.8, "fruit_greybark")
        twigs_ = []
        for p0, c, p1 in (((50, 61), (40, 54), (28, 42)), ((50, 61), (58, 52), (70, 40)), ((50, 61), (49, 46), (50, 26)),
                          ((44, 56), (40, 48), (38, 34)), ((56, 55), (62, 48), (64, 32))):
            twigs_.append(a.ribbon(p0, c, p1, 1.6, 0.9, "fruit_greybark", lw=0.8))
        for q in twigs_:
            pair_leaves(a, q, (0.45, 0.72), 10)
        return a

    def growing():
        a = Art(); ground(a); head(a); return a

    def flower():
        a = Art(); ground(a); cx, cy, rx, ry = head(a)
        with a.on(BLOOM):
            for j, (x, y) in enumerate(in_crown(cx, cy, rx, ry, 13, 0.86)):   # small sprays of tiny cream flowers
                for d in range(5):
                    p = T(x, y, -90 + (d - 2) * 32)(2.6 + 0.8 * (d % 2))
                    a.line(f"M{f(x)},{f(y)} L{P(p)}", 0.5, 0.8)
                    a.flower(p[0], p[1], 1.8, 4, "white", None, 0.9, lw=0.4)
                    a.dot(p[0], p[1], 0.45, "sun")
        return a

    def fruit(ripe):
        def draw():
            a = Art(); ground(a); cx, cy, rx, ry = head(a)
            cols = (fr, "plum", "pear") if ripe else ("pear",)
            with a.on(BLOOM):
                if not ripe:   # small young olives on the old flower sprays, standing out round the head
                    for j, (x, y, g) in enumerate(edge_spots(cx, cy, rx, ry, 9, 0.9, -175, 5)):
                        for m in (-1, 1):
                            e = T(x, y, g + m * 22)(3.4)
                            a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.5, 0.85)
                            c = T(*e, g + m * 22)(1.7); a.oval(c[0], c[1], 1.3, 1.8, g + m * 22 + 90, "pear", 0.75)
                    return a
                for j, (x, y) in enumerate(in_crown(cx, cy, rx, ry, 14, 0.86)):
                    for m in range(2):
                        c = cols[(j + m) % len(cols)]
                        px, py = x + (m - 0.5) * 3, y + (1 if m % 2 else 0)
                        a.line(f"M{f(x)},{f(y - 2)} L{f(px)},{f(py)}", 0.5, 0.85)
                        a.oval(px, py + 2.2, 1.6, 2.3, 10, c, 0.6); a.dot(px - 0.5, py + 1.5, 0.35, "white")   # oval olives, green, purple and black together
            return a
        return draw

    return {"young": young, "growing": growing, "flower": flower, "set": fruit(False), "crop": fruit(True)}


def corymb_small(a, x, y, r, fc, cen, berries=None):
    """A flat-topped head drawn small: of tiny flowers, or of berries."""
    if not berries:   # a flat head, its top edge bumpy with tiny flowers, dotted with their centres
        a.polar(x, y, lambda h: 1 + 0.14 * abs(math.cos(5 * h)) * (1 if math.sin(h) < 0.2 else 0.3), r * 1.15, r * 0.52, 0, fc, 0.6)
        for j in range(9):
            rr = r * 0.85 * math.sqrt((j + 0.5) / 9); th = j * GOLD
            a.dot(x + rr * math.cos(th), y + rr * 0.4 * math.sin(th), 0.42, cen)
        return
    for j in range(9):
        rr = r * math.sqrt((j + 0.5) / 9); th = j * GOLD
        px, py = x + rr * math.cos(th), y + rr * 0.45 * math.sin(th)
        if berries:
            a.line(f"M{f(x)},{f(y + r * 0.6)} L{f(px)},{f(py)}", 0.4, 0.7)
        else:
            a.flower(px, py, 1.5, 5, fc, cen, 0.9, cr=0.4, lw=0.35)
    if berries:
        for j in range(9):
            rr = r * math.sqrt((j + 0.5) / 9); th = j * GOLD
            px, py = x + rr * math.cos(th), y + rr * 0.45 * math.sin(th)
            a.oval(px, py, 1.25, 1.25, 0, berries, 0.5)
            if berries != "unripe":
                a.dot(px + 0.2, py - 0.9, 0.3, "bark")


def whitebeam_stages():
    kind = "bristol-whitebeam"; fr = pal(kind).get("fruit", "carrot")

    def young():   # a single straight stem: leaves on very short side shoots all the way up
        return young_tree(kind, arms=((0.38, 1, 4, 3), (0.48, -1, 4, 3), (0.58, 1, 4, 3), (0.68, -1, 4, 3)), L=11, leader=20)

    def dormant():   # fat green buds with brown-edged scales
        def ex(a, qs, out):
            for (e, ang) in out:
                b = T(*e, ang)(1.4); a.line(f"M{P(T(*b, ang + 90)(0.9))} L{P(T(*b, ang - 90)(0.9))}", 0.5, 0.8, "bark")
        return bare_tree(kind, bud="unripe", br=1.35, extra=ex)

    def heads(berries):
        def sp(a, cx, cy, rx, ry):
            if berries == "unripe":
                return fruitlets(a, kind, cx, cy, rx, ry, 8)
            if berries:
                for j, (x, y) in enumerate(in_crown(cx, cy - 4, rx, ry * 0.8, 8, 0.86, 2.2)):
                    corymb_small(a, x, y - 1, 4.2, "white", "primrose", berries)
                return
            with a.on(BLOOM):   # flat white heads held up on short stalks at the shoot tips, above the leaves
                for j, (x, y, g) in enumerate(edge_spots(cx, cy, rx, ry, 7, 0.82, -165, -15)):
                    e = (x + 2 * math.cos(math.radians(g)), y - 5)
                    for d in (-2, 0, 2):
                        a.line(f"M{f(x)},{f(y)} L{f(e[0] + d)},{f(e[1])}", 0.5, 0.85)
                    corymb_small(a, e[0], e[1], 4.4, "white", "primrose")
        return sp

    return {"young": young, "dormant": dormant, "flower": lambda: leafy_tree(kind, "flower", heads(None)),
            "set": lambda: leafy_tree(kind, "set", heads("unripe")), "crop": lambda: leafy_tree(kind, "crop", heads(fr))}


def fig_fruit(a, x, y, r, col, up=False):
    """A fig: top-shaped, narrowing to its short stalk; the eye at the broad end."""
    sg = -1 if up else 1
    a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y + sg * r * 0.4)}", 0.8, 0.9)
    y0 = y + sg * r * 0.4
    a.shape(f"M{f(x)},{f(y0)} C{f(x + r * 0.5)},{f(y0 + sg * r * 0.2)} {f(x + r * 0.6)},{f(y0 + sg * r * 0.9)} {f(x + r)},{f(y0 + sg * r * 1.5)} "
            f"C{f(x + r * 1.25)},{f(y0 + sg * r * 2.5)} {f(x - r * 1.25)},{f(y0 + sg * r * 2.5)} {f(x - r)},{f(y0 + sg * r * 1.5)} "
            f"C{f(x - r * 0.6)},{f(y0 + sg * r * 0.9)} {f(x - r * 0.5)},{f(y0 + sg * r * 0.2)} {f(x)},{f(y0)} Z", col, 0.8)
    a.dot(x, y0 + sg * r * 2.2, max(0.35, r * 0.13), "dark")


def fig_stages():
    kind = "fig"; fr = pal(kind).get("fruit", "plum")

    def tips(a):
        qs, _ = frame(a, "fig", "fruit_greybark")
        return qs

    def tufts(a, qs, L=15, figs=None):
        with a.group():
            for qi, q in enumerate(qs):
                e = q.pt(1); ang = q.ang(1)
                for j, (u, off) in enumerate(((0.72, -80), (0.84, 75), (1.0, -20 if qi % 2 else 20))):
                    p = q.pt(u)
                    own(a, kind, p[0], p[1], ang + off, L * (0.85 if j < 2 else 1.0))
                if figs:   # in the leaf angles, low enough on the stems to stand clear of the big leaves
                    for j, (u, sd) in enumerate(((0.44, 1), (0.54, -1)) if figs == "set" else ((0.56, 1), (0.64, -1))):
                        p = q.pt(u)
                        b = T(*p, q.ang(u) + sd * 90)(1.8)
                        with a.on(BLOOM):
                            if figs == "set":   # small hard green figs, held upright
                                fig_fruit(a, b[0], b[1], 3.3, "pale", up=True)
                            else:               # ripe figs drooping on their short stalks
                                fig_fruit(a, b[0], b[1], 2.8, fr)

    def young():
        a = Art(); ground(a)
        for p0, c, p1 in (((47, 88), (44, 74), (40, 58)), ((53, 88), (56, 72), (60, 54))):
            limb(a, p0, c, p1, 4.4, 3.4, "fruit_greybark")
        with a.group():   # a few very large hand-shaped leaves on stout stalks
            for (x, y), ang in (((40, 58), -128), ((60, 54), -52), ((50, 62), -92)):
                own(a, kind, x, y, ang, 36)
        return a

    def dormant():
        a = Art(); ground(a); qs = tips(a)
        for q in qs:   # pointed green-brown buds at the tips, pea-sized embryo figs just below
            e = q.pt(1); ang = q.ang(1)
            a.leaf(e[0], e[1], ang, 4.4, 0.5, "unripe", lw=0.8, detail=False)
            for sd in (-1, 1):
                b = T(*q.pt(0.93), ang + sd * 90)(2.2)
                a.oval(b[0], b[1], 1.2, 1.2, 0, "unripe", 0.6)
            p = q.pt(0.6); a.line(f"M{P(T(*p, ang + 90)(1.4))} q0.8,-0.6 1.6,0", 0.6, 0.6)   # a pale leaf scar
        return a

    def leafy(figs):
        def draw():
            a = Art(); ground(a); qs = tips(a); tufts(a, qs, 24, figs); return a
        return draw

    return {"young": young, "dormant": dormant, "growing": leafy(None), "set": leafy("set"), "crop": leafy("crop")}


def ginkgo_stages():
    kind = "gingko"

    def tufts(a, qs, fill=None, L=7.5, per=3):
        with a.group():
            for qi, q in enumerate(qs[1:]):
                for j, u in enumerate((0.35, 0.6, 0.85)):
                    x, y = q.pt(u)
                    a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y - 1.6)}", 1.1, 0.9)   # the spur
                    for m in range(per):
                        own(a, kind, x, y - 1.6, -90 + (m - (per - 1) / 2) * 42, L, fill)
            q = qs[0]
            for u in (0.75, 0.88, 1.0):
                x, y = q.pt(u); own(a, kind, x, y, -90 + (u - 0.88) * 300, L, fill)

    def young():
        a = Art(); ground(a); qs, _ = frame(a, "ginkgo", "bark")
        with a.group():
            for qi, q in enumerate(qs[1:]):
                for j, u in enumerate((0.45, 0.8)):
                    x, y = q.pt(u); own(a, kind, x, y, -90 + (1 if j % 2 else -1) * 25, 7.5)
            for u in (0.6, 0.8, 0.95):
                x, y = qs[0].pt(u); own(a, kind, x, y, -90 + (u - 0.8) * 200, 7.5)
        return a

    def dormant():
        a = Art(); ground(a); qs, _ = frame(a, "ginkgo", "bark")
        for q in qs[1:]:   # short knobbly spur shoots studding the level branches, each with a small dome bud
            for u in (0.3, 0.52, 0.74, 0.94):
                x, y = q.pt(u)
                a.ribbon((x, y), (x, y - 1), (x, y - 2.4), 1.6, 1.4, "bark", lw=0.6)
                a.line(f"M{f(x - 0.8)},{f(y - 1.2)} l1.6,0", 0.4, 0.6)
                a.shape(f"M{f(x - 1)},{f(y - 2.4)} Q{f(x)},{f(y - 4.4)} {f(x + 1)},{f(y - 2.4)} Z", "bark", 0.6)
        return a

    def leafy(fill):
        def draw():
            a = Art(); ground(a); qs, _ = frame(a, "ginkgo", "bark"); tufts(a, qs, fill)
            if fill:   # a few fallen yellow fans on the ground
                for x, ang in ((26, -20), (34, 200), (70, 10), (78, 160)):
                    own(a, kind, x, 87, ang, 6.5, fill, detail=False)
            return a
        return draw

    return {"young": young, "dormant": dormant, "growing": leafy(None), "autumn": leafy("sun")}


STAGE["nectarine"] = nectarine_stages()
STAGE["olive-tree"] = olive_stages()
STAGE["bristol-whitebeam"] = whitebeam_stages()
STAGE["fig"] = fig_stages()
STAGE["gingko"] = ginkgo_stages()



# ============================================================ bushes
def stems(a, form, col="bark", n=None):
    """The woody stems of a bush, as curves. form: "upright" (many stems from
    the soil, no trunk), "goblet" (a short single leg, then an open cup of
    stems), "arch" (stems arching out and over), "mound" (many thin twiggy
    stems, low)."""
    qs = []
    if form == "upright":
        for dx, top, lean in ((-4, 22, -16), (4, 20, 14), (-1.5, 14, -4), (1.5, 16, 6), (-6, 34, -28), (6, 32, 26))[: n or 6]:
            qs.append(a.ribbon((50 + dx, 88), (50 + dx + lean * 0.25, 60), (50 + dx + lean, top), 2.0, 1.0, col, lw=0.8))
    elif form == "goblet":
        a.ribbon((50, 88), (49.6, 82), (50, 75), 4.6, 4.0, col)
        for lean, top in ((-26, 30), (26, 30), (-11, 22), (11, 20)):
            qs.append(a.ribbon((50, 76), (50 + lean * 0.3, 60), (50 + lean, top), 2.2, 1.0, col, lw=0.8))
    elif form == "arch":
        for p0, c, p1 in (((47, 88), (30, 40), (8, 50)), ((53, 88), (70, 40), (92, 50)), ((49, 88), (40, 30), (24, 30)),
                          ((51, 88), (60, 28), (76, 30))):
            qs.append(a.ribbon(p0, c, p1, 2.0, 1.0, col, lw=0.8))
    elif form == "dome":   # many stems fanning out from the base to a rounded outline
        for k in range(n or 9):
            g = math.radians(-162 + 144 * k / ((n or 9) - 1))
            e = (50 + 34 * math.cos(g), 86 + 56 * math.sin(g))
            qs.append(a.ribbon((50 + (k - 4) * 0.8, 88), (50 + (e[0] - 50) * 0.3, 86 + (e[1] - 86) * 0.55), e, 1.8, 0.9, col, lw=0.8))
    elif form == "mound":
        for k in range(9):
            u = k / 8 - 0.5
            qs.append(a.ribbon((50 + u * 14, 88), (50 + u * 30, 72), (50 + u * 62, 62 - 8 * (1 - abs(u) * 2)), 1.4, 0.8, col, lw=0.7))
    return qs


def leaves_on(a, kind, qs, us=(0.35, 0.55, 0.75, 0.95), L=10, opp=False, fill=None, top=True, spread=55, tipfill=None, backs=None, lw=None):
    """The kind's own leaves along each stem: alternate, or in opposite pairs.
    backs: (colour, n): every nth leaf is turned to show its pale underside."""
    with a.group():
        for qi, q in enumerate(qs):
            for j, u in enumerate(us):
                x, y = q.pt(u); ang = q.ang(u); sd = 1 if (j + qi) % 2 else -1
                k = 1 - 0.18 * u
                fl = backs[0] if backs and (j + 2 * qi) % backs[1] == 1 else fill
                own(a, kind, x, y, ang + sd * spread, L * k, fl, lw=lw)
                if opp:
                    own(a, kind, x, y, ang - sd * spread, L * k, fill, lw=lw)
            if top:
                e = q.pt(1); own(a, kind, e[0], e[1], q.ang(1) + 8, L * 0.75, tipfill or fill, lw=lw)


def strig_small(a, x, y, n, item, col, step=2.6, sway=1.2, r=1.25):
    """A hanging string at plant scale: of small bells, saucers or berries."""
    a.line(f"M{f(x)},{f(y)} Q{f(x + sway)},{f(y + n * step * 0.5)} {f(x + sway * 0.4)},{f(y + n * step + 1)}", 0.6, 0.9)
    with a.on(BLOOM):
        for j in range(n):
            px, py = x + sway * 0.8 * math.sin(j * 0.9) + (0.6 if j % 2 else -0.6), y + 2 + j * step
            if item == "bell":
                a.leaf(px, py - 1.4, 90, 3.8, 0.6, col, lw=0.55, detail=False)
            elif item == "saucer":
                a.flower(px, py, 1.5, 5, col, None, 1.0, lw=0.35); a.dot(px, py, 0.4, "plum")
            else:
                a.oval(px, py, r, r, 0, col, 0.55)
                if r > 1.0:
                    a.dot(px - r * 0.35, py - r * 0.35, max(0.25, r * 0.22), "white")


def currant_stages(kind):
    lc = pal(kind).get("leaf", "leaf"); fr = pal(kind).get("fruit", "dark"); fc = pal(kind).get("flower", "pink")
    form = "goblet" if kind == "whitecurrant" else "upright"
    nodes = (0.45, 0.65, 0.85)

    def young():
        a = Art(); ground(a); qs = stems(a, form, "bark"); leaves_on(a, kind, qs, (0.3, 0.46, 0.62, 0.78, 0.92), 13); return a

    def dormant():
        a = Art(); ground(a); qs = stems(a, form, "straw" if kind == "blackcurrant" else "seed")
        for q in qs:   # fat pale pointed buds (black); short spurs with pointed buds standing away (white)
            for j, u in enumerate((0.3, 0.45, 0.6, 0.75, 0.9)):
                x, y = q.pt(u); sd = 1 if j % 2 else -1; ang = q.ang(u) + sd * 45
                if kind == "whitecurrant":
                    e = T(x, y, ang)(2.2); a.line(f"M{f(x)},{f(y)} L{P(e)}", 1.0, 0.9)
                    a.leaf(e[0], e[1], ang, 2.6, 0.45, "bark", lw=0.6, detail=False)
                else:
                    a.leaf(x, y, ang - sd * 15, 3.2, 0.5, "seed", lw=0.7, detail=False)
            e = q.pt(1); a.leaf(e[0], e[1], q.ang(1), 3.2, 0.5, "seed" if kind == "blackcurrant" else "bark", lw=0.7, detail=False)
        return a

    def flower():
        a = Art(); ground(a); qs = stems(a, form, "bark")
        leaves_on(a, kind, qs, (0.4, 0.62, 0.84), 9.5)   # the young leaves just opening
        for qi, q in enumerate(qs):
            for j, u in enumerate((0.42, 0.62, 0.82)):
                x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                if kind == "whitecurrant":
                    strig_small(a, x + sd * 1.2, y, 6, "saucer", fc, 2.6)
                else:
                    strig_small(a, x + sd * 1.2, y, 4, "bell", fc, 3.2)
        return a

    def crop():
        a = Art(); ground(a); qs = stems(a, form, "bark")
        leaves_on(a, kind, qs, (0.36, 0.62, 0.9), 13)
        outer = [q for i, q in enumerate(qs) if kind == "whitecurrant" or i in (0, 1, 4, 5)]   # where the strings hang clear
        for qi, q in enumerate(outer):
            for j, u in enumerate((0.5, 0.78)):
                x, y = q.pt(u); sd = 1 if q.p1[0] > 50 else -1
                if kind == "whitecurrant":   # long strings of pearly berries
                    strig_small(a, x + sd * 1.2, y, 7, "berry", fr, 2.3, r=1.15, sway=0.4)
                else:                        # hanging strings of glossy black berries, one under the other
                    strig_small(a, x + sd * 1.2, y, 5, "berry", fr, 3.0, r=1.5, sway=0.3)
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


def goose_stages():
    kind = "gooseberry"; fr = pal(kind).get("fruit", "berry"); fc = pal(kind).get("flower", "beet")

    def spines(a, qs, every=(0.25, 0.4, 0.55, 0.7, 0.85)):
        for q in qs:
            for j, u in enumerate(every):
                x, y = q.pt(u); ang = q.ang(u) + 90
                for d in ((-25, 25) if j % 2 else (0,)):
                    e = T(x, y, ang + d)(2.6)
                    a.shape(f"M{P(T(x, y, ang + d + 90)(0.5))} L{P(e)} L{P(T(x, y, ang + d - 90)(0.5))} Z", "straw", 0.5)

    def young():
        a = Art(); ground(a); qs = stems(a, "arch", "bark"); spines(a, qs); leaves_on(a, kind, qs, (0.25, 0.4, 0.55, 0.7, 0.85), 11); return a

    def dormant():
        a = Art(); ground(a); qs = stems(a, "arch", "bark"); spines(a, qs, (0.2, 0.32, 0.44, 0.56, 0.68, 0.8, 0.92))
        for q in qs:
            for u in (0.38, 0.62, 0.86):
                x, y = q.pt(u); a.leaf(x, y, q.ang(u) - 60, 2.4, 0.5, "bark", lw=0.6, detail=False)
        return a

    def flower():
        a = Art(); ground(a); qs = stems(a, "arch", "bark"); spines(a, qs); leaves_on(a, kind, qs, (0.3, 0.55, 0.8), 9.5, top=True)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.42, 0.68)):
                    x, y = q.pt(u)
                    for m in range(1 + (j + qi) % 2):   # hanging singly or in twos well below the shoot
                        px = x + (m - 0.5) * 4.0
                        a.line(f"M{f(x)},{f(y)} L{f(px)},{f(y + 4.5)}", 0.6, 0.9)
                        a.oval(px, y + 5.4, 1.5, 1.6, 0, "unripe", 0.55)                     # the green ovary above
                        a.shape(f"M{f(px - 1.2)},{f(y + 6.6)} L{f(px - 1.9)},{f(y + 10.4)} L{f(px + 1.9)},{f(y + 10.4)} L{f(px + 1.2)},{f(y + 6.6)} Z", "pear", 0.55)   # the small greenish bell
                        a.dot(px, y + 11.0, 0.6, "white")                                   # petals just showing at the mouth
                        for d in (-1, 1):   # narrow reddish sepals folded back up against it
                            a.leaf(px + d * 1.9, y + 10.6, -90 - d * 12, 4.6, 0.32, fc, lw=0.5, detail=False)
        return a

    def crop():
        a = Art(); ground(a); qs = stems(a, "arch", "bark"); spines(a, qs); leaves_on(a, kind, qs, (0.25, 0.45, 0.65, 0.85), 11)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.36, 0.6, 0.84)):
                    x, y = q.pt(u); r = 2.6
                    a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y + 2.4)}", 0.6, 0.9)
                    a.oval(x, y + 2.4 + r * 1.1, r * 0.92, r * 1.1, 0, fr, 0.75)   # veined, translucent, hanging singly
                    for o in (-0.5, 0, 0.5):
                        a.line(f"M{f(x + o * r * 0.3)},{f(y + 2.6)} Q{f(x + o * r * 1.7)},{f(y + 2.4 + r * 1.1)} {f(x + o * r * 0.3)},{f(y + 2.4 + r * 2.1)}", 0.4, 0.45, "white")
                    a.dot(x, y + 2.4 + r * 2.2, 0.45, "bark")
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


def blueberry_stages():
    kind = "blueberry"; fr = pal(kind).get("fruit", "blue")

    def young():
        a = Art(); ground(a); qs = stems(a, "upright", "bark"); leaves_on(a, kind, qs, (0.3, 0.45, 0.6, 0.75, 0.9), 10); return a

    def dormant():
        a = Art(); ground(a); qs = stems(a, "upright", "bark")
        for q in qs:   # bright red young twigs, fat rounded flower buds at their tips
            e = q.pt(1); ang = q.ang(1)
            for d in (-28, 24):
                t2 = T(*e, ang + d)(7); a.line(f"M{P(e)} L{P(t2)}", 1.0, 0.95, "berry")
                a.oval(*T(*t2, ang + d)(1.2), 1.3, 1.6, ang + d + 90, "beet", 0.55)
            p = q.pt(0.75); t3 = T(*p, ang - 50)(6); a.line(f"M{P(p)} L{P(t3)}", 0.9, 0.95, "berry")
            a.oval(*T(*t3, ang - 50)(1.0), 1.1, 1.4, ang + 40, "beet", 0.5)
        return a

    def flower():
        a = Art(); ground(a); qs = stems(a, "upright", "bark"); leaves_on(a, kind, qs, (0.55, 0.8), 7.5)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.48, 0.7, 0.9)):
                    x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                    hub = (x + sd * 1.4, y + 0.6)
                    for m, d in enumerate((-30, -8, 14, 34)):   # a short hanging cluster of small white urns
                        p = T(*hub, 90 + d)(1.8 + (m % 2) * 1.2)
                        a.line(f"M{P(hub)} L{P(p)}", 0.4, 0.85)
                        a.leaf(p[0], p[1], 90 + d * 0.4, 3.0, 0.62, "white", lw=0.5, detail=False)
        return a

    def crop():
        a = Art(); ground(a); qs = stems(a, "upright", "bark"); leaves_on(a, kind, qs, (0.32, 0.52, 0.72, 0.9), 10)
        cols = (fr, fr, "pink", fr, "unripe")
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.5, 0.78)):
                    x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                    for m, (dx, dy) in enumerate(((1.8, 2.2), (4.2, 3.0), (2.8, 5.2), (5.4, 6.0))):   # a loose bunch, ripening unevenly
                        c = cols[(m + j + qi) % 5]; px, py = x + sd * dx, y + dy
                        a.oval(px, py, 2.1, 2.05, 0, c, 0.55)
                        if c == fr:   # the pale powder-blue bloom
                            a.shape(path([(px + 1.85 * math.cos(h), py + 1.8 * math.sin(h)) for h in [2 * math.pi * i / 16 for i in range(16)]]), "blue", 0, fa=0.55)
                        for d in range(5):   # the little five-pointed crown of old sepals, in a ring on top
                            e = T(px, py - 0.9, -90 + d * 72)(0.8)
                            a.line(f"M{f(px)},{f(py - 0.9)} L{P(e)}", 0.4, 0.95, "dark")
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


def honeyberry_stages():
    kind = "honeyberry"; fr = pal(kind).get("fruit", "blue"); fc = pal(kind).get("flower", "primrose")

    def young():
        a = Art(); ground(a); qs = stems(a, "upright", "beet", 5); leaves_on(a, kind, qs, (0.42, 0.62, 0.82), 9, opp=True, spread=50); return a

    def dormant():
        a = Art(); ground(a); qs = stems(a, "upright", "seed", 5)
        for qi, q in enumerate(qs):   # light brown bark peeling in long strips; small paired buds
            for u in (0.2, 0.45):
                x, y = q.pt(u); e = q.pt(u + 0.14)
                sd = 1 if qi % 2 else -1
                a.line(f"M{f(x + sd * 0.8)},{f(y)} Q{f((x + e[0]) / 2 + sd * 2.6)},{f((y + e[1]) / 2)} {f(e[0] + sd * 2.2)},{f(e[1] + 1)}", 0.7, 0.85, "bark")
            for u in (0.66, 0.84, 1.0):
                x, y = q.pt(u)
                for sd in (-1, 1):
                    a.oval(*T(x, y, q.ang(u) + sd * 70)(1.2), 0.7, 1.0, 0, "bark", 0.45)
        return a

    def flower():
        a = Art(); ground(a); qs = stems(a, "upright", "beet", 5); leaves_on(a, kind, qs, (0.55, 0.8), 6.5, opp=True, spread=45)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.55, 0.8)):
                    x, y = q.pt(u)
                    for sd in (-1, 1):   # a pair of pale yellow funnels hanging from the leaf pair
                        p = T(x, y, 90 + sd * 24)(1)
                        a.leaf(p[0], p[1], 90 + sd * 24, 5.4, 0.34, fc, lw=0.5, detail=False)
        return a

    def crop():
        a = Art(); ground(a); qs = stems(a, "upright", "beet", 5); leaves_on(a, kind, qs, (0.45, 0.68, 0.9), 8.5, opp=True, spread=50)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.45, 0.7)):
                    x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                    a.line(f"M{f(x)},{f(y)} L{f(x + sd * 0.8)},{f(y + 1.6)}", 0.5, 0.9)
                    a.oval(x + sd * 1.0, y + 4.4, 1.5, 3.0, sd * 8, fr, 0.6)   # long oval berries with a pale bloom
                    a.line(f"M{f(x + sd * 1.0 - 0.5)},{f(y + 2.6)} L{f(x + sd * 1.0 - 0.6)},{f(y + 5.6)}", 0.6, 0.5, "white")
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


def prickles(a, qs, us=(0.2, 0.34, 0.48, 0.62, 0.76, 0.9), col="rust"):
    """Hooked prickles scattered along the stems (rose)."""
    for q in qs:
        for j, u in enumerate(us):
            x, y = q.pt(u); sd = 1 if j % 2 else -1; ang = q.ang(u) + sd * 90
            b0 = T(x, y, q.ang(u))(-0.6); b1 = T(x, y, q.ang(u))(0.8); e = T(x, y, ang)(2.0); e = T(*e, q.ang(u) + 180)(0.9)
            a.shape(f"M{P(b0)} Q{P(T(x, y, ang)(1.6))} {P(e)} Q{P(T(x, y, ang)(0.6))} {P(b1)} Z", col, 0.45)


def rose_stages():
    kind = "rose"; fr = pal(kind).get("fruit", "berry"); fc = pal(kind).get("flower", "pink")

    def base(a, col="leaf"):
        qs = stems(a, "upright", col, 5)
        prickles(a, qs)
        return qs

    def hip(a, x, y, r=1.9):
        a.oval(x, y + r * 1.25, r, r * 1.3, 0, fr, 0.65)
        for d in (-40, 0, 40):   # the dried sepals on top
            a.line(f"M{f(x)},{f(y + 0.4)} L{P(T(x, y + 0.4, -90 + d)(2.0))}", 0.6, 0.85, "bark")
        a.dot(x - r * 0.35, y + r * 0.9, 0.4, "white")

    def young():
        a = Art(); ground(a); qs = base(a); leaves_on(a, kind, qs, (0.42, 0.66, 0.9), 14, top=False); return a

    def dormant():
        a = Art(); ground(a); qs = base(a, "rust")
        for q in qs[1:4]:
            e = q.pt(1); hip(a, e[0], e[1] - 0.5, 1.7)
        for q in qs:
            for u in (0.4, 0.7):
                x, y = q.pt(u); a.oval(*T(x, y, q.ang(u) - 50)(1.1), 0.7, 1.0, 0, "berry", 0.4)   # small red buds
        return a

    def flower():
        a = Art(); ground(a); qs = base(a); leaves_on(a, kind, qs, (0.36, 0.6, 0.82), 13, top=False)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                e = q.pt(1)
                if qi in (2, 4):   # a swirled bud
                    a.leaf(e[0], e[1] + 1, -90, 5.4, 0.48, fc, lw=0.7, detail=False)
                    a.leaf(e[0], e[1] + 1, -100, 3.4, 0.4, "leaf", lw=0.5, detail=False); a.leaf(e[0], e[1] + 1, -80, 3.4, 0.4, "leaf", lw=0.5, detail=False)
                    continue
                a.flower(e[0], e[1] - 2, 6.2, 5, fc, None, 0.95, start=-90 + qi * 20, lw=0.7)
                a.flower(e[0], e[1] - 2, 4.4, 5, fc, None, 0.95, start=-54 + qi * 20, lw=0.6)
                a.oval(e[0], e[1] - 2, 1.5, 1.5, 0, pal(kind).get("centre", "sun"), 0.5)
        return a

    def crop():
        a = Art(); ground(a); qs = base(a); leaves_on(a, kind, qs, (0.36, 0.6, 0.82), 13, top=False)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                e = q.pt(1)
                hip(a, e[0], e[1] - 1)
                if qi % 2:
                    hip(a, e[0] + 3.4, e[1] + 1.4, 1.7)
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


def lacecap_small(a, x, y, r, fc, cen):
    """A lacecap head drawn small: tiny beads in the middle, a ring of
    four-petalled florets round the edge."""
    a.oval(x, y, r * 0.62, r * 0.3, 0, cen, 0.5)
    for k in range(12):
        rr = r * 0.55 * math.sqrt((k + 0.5) / 12); th = k * GOLD
        a.dot(x + rr * math.cos(th), y + rr * 0.45 * math.sin(th), 0.4, "beet")
    for k in range(6):
        g = math.radians(k * 60 + 15)
        a.flower(x + r * 0.9 * math.cos(g), y + r * 0.42 * math.sin(g), r * 0.36, 4, fc, None, 0.85, start=-45 + k * 20, lw=0.45)


def hydrangea_stages():
    kind = "hydrangea"; fc = pal(kind).get("flower", "pink"); cen = pal(kind).get("centre", "mauve")

    def young():
        a = Art(); ground(a); qs = stems(a, "upright", "leaf", 4); leaves_on(a, kind, qs, (0.5, 0.76, 1.0), 15, opp=True, top=False, spread=55); return a

    def growing():   # a dense rounded bush: stems fanning to a dome, clothed in pairs of pointed leaves
        a = Art(); ground(a); qs = stems(a, "dome", "leaf", 9)
        leaves_on(a, kind, qs, (0.42, 0.66, 0.88), 15, opp=True, top=True, spread=48); return a

    def flower():
        a = Art(); ground(a); qs = stems(a, "upright", "leaf"); leaves_on(a, kind, qs, (0.3, 0.52, 0.74), 12, opp=True, top=False)
        with a.on(BLOOM):
            for q in qs:
                e = q.pt(1); lacecap_small(a, e[0], e[1] - 1.5, 7.5, fc, cen)
        return a

    def dormant():
        a = Art(); ground(a); qs = stems(a, "upright", "bark")
        for q in qs:
            for u in (0.62, 0.82):   # fat paired buds near the top
                x, y = q.pt(u)
                for sd in (-1, 1):
                    a.oval(*T(x, y, q.ang(u) + sd * 70)(1.3), 0.9, 1.3, q.ang(u), "beet", 0.45)
            e = q.pt(1)   # the dry papery heads, left on
            a.oval(e[0], e[1] - 1.5, 6.6, 2.8, 0, "straw", 0.6)
            for k in range(6):
                g = math.radians(k * 60 + 15)
                a.flower(e[0] + 6.4 * math.cos(g), e[1] - 1.5 + 2.9 * math.sin(g), 2.4, 4, "straw", None, 0.85, lw=0.4)
            for k in range(7):
                a.dot(e[0] + (k - 3) * 1.4, e[1] - 1.5 + 0.6 * math.sin(k), 0.4, "bark")
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "growing": growing}


def spiraea_stages():
    kind = "japanese-spiraea"; fc = pal(kind).get("flower", "mauve"); lc = pal(kind).get("leaf", "primrose")

    def stems_(a, n=13, W=70, H=30, col="bark"):
        """Thin brown twiggy stems, drawn as brown lines."""
        qs = []
        for k in range(n):
            u = k / (n - 1) - 0.5
            q = Quad((50 + u * 16, 88), (50 + u * W * 0.5, 80), (50 + u * W, 88 - H * (1 - (u * 2) ** 2 * 0.55)))
            a.line(q.d(), 1.2, 0.95, col); qs.append(q)
        return qs

    def mound(a, tips=True, us=(0.3, 0.46, 0.62, 0.78, 0.94), L=11, W=70, H=30):
        # a low dense mound built from the golden leaves themselves, copper-red young ones at the tips
        qs = stems_(a, 11, W, H)
        leaves_on(a, kind, qs, us, L, spread=48, tipfill="rust" if tips else None, lw=0.6)
        return qs

    def young():
        a = Art(); ground(a)
        qs = stems_(a, 6, 30, 26)   # a low clump of thin upright stems
        leaves_on(a, kind, qs, (0.4, 0.6, 0.8), 10, spread=50, tipfill="rust", lw=0.6)
        return a

    def growing():
        a = Art(); ground(a); mound(a); return a

    def flower():
        a = Art(); ground(a); qs = mound(a, False, (0.35, 0.55, 0.75))
        with a.on(BLOOM):
            for q in qs[::2]:   # flat pink heads on top of the shoots
                e = q.pt(1)
                a.oval(e[0], e[1] - 1.8, 5.2, 2.2, 0, fc, 0.6)
                for k in range(10):
                    rr = 4.6 * math.sqrt((k + 0.5) / 10); th = k * GOLD
                    a.dot(e[0] + rr * math.cos(th), e[1] - 2.0 + rr * 0.4 * math.sin(th), 0.45, "pink")
                for k in range(8):
                    a.line(f"M{f(e[0] - 4.4 + k * 1.26)},{f(e[1] - 2.8)} l{f((k - 3.5) * 0.15)},-1.3", 0.35, 0.6)
        return a

    def dormant():
        a = Art(); ground(a); qs = stems_(a, 13, 70, 30)
        for j, q in enumerate(qs):   # small reddish buds; flat rusty-brown seed heads left on top
            for u in (0.45, 0.7):
                x, y = q.pt(u); a.dot(*T(x, y, q.ang(u) - 70)(0.9), 0.5, "berry")
            p = q.pt(0.62); twigs(a, p[0], p[1], q.ang(0.62) + 30, 4, 0, 0.6, col="bark")
            if j % 2 == 0:
                e = q.pt(1)
                a.oval(e[0], e[1] - 1.2, 3.6, 1.5, 0, pal(kind).get("fruit", "rust"), 0.55)
                for k in range(6):
                    rr = 3.0 * math.sqrt((k + 0.5) / 6); th = k * GOLD
                    a.dot(e[0] + rr * math.cos(th), e[1] - 1.4 + rr * 0.36 * math.sin(th), 0.38, "bark")
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "growing": growing}


STAGE["blackcurrant"] = currant_stages("blackcurrant")
STAGE["whitecurrant"] = currant_stages("whitecurrant")
STAGE["gooseberry"] = goose_stages()
STAGE["blueberry"] = blueberry_stages()
STAGE["honeyberry"] = honeyberry_stages()
STAGE["rose"] = rose_stages()
STAGE["hydrangea"] = hydrangea_stages()
STAGE["japanese-spiraea"] = spiraea_stages()


# ============================================================ cane fruit
def wires(a, posts=(12, 88), ys=(58, 34), top=24):
    for px in posts:
        a.ribbon((px, 88), (px, 60), (px, top), 2.4, 2.2, "bark")
    for wy in ys:
        a.line(f"M{posts[0]},{wy} L{posts[1]},{wy}", 0.7, 0.6)


def drupe(a, x, y, r, col, long=1.0, cap="leaf", shine=False):
    """A bramble fruit hanging from x,y: a cluster of small round drupelets,
    each outlined in a darker shade of the fruit's own colour (not the dark
    line colour, which would turn a small red berry dark). long > 1 makes it
    a long cone (loganberry). shine: a glint on each drupelet (blackberry)."""
    dark = {"berry": "beet", "beet": "plum", "dark": "line", "unripe": "deep"}.get(col, "line")
    cy = y + r * long
    if cap:   # the green sepals behind, at the top
        for d in (-50, 0, 50):
            a.leaf(x, y + 0.4, -90 + d + 180, r * 0.8, 0.45, cap, lw=0.45, detail=False)
    a.oval(x, cy, r, r * long, 0, col, 0.7)
    rows = max(2, int(2 * long + 1))
    for i in range(rows):
        v = -0.66 + 1.32 * i / (rows - 1); w = math.sqrt(max(0, 1 - v * v)) * r
        m = max(1, int(w / (r * 0.42)))
        for j in range(m):
            px = x - w * 0.66 + (1.32 * w * j / max(1, m - 1) if m > 1 else w * 0.66)
            py = cy + v * r * long * 0.82
            a.oval(px, py, r * 0.3, r * 0.3, 0, col, 0.35, col=dark, la=0.9)
            if shine:
                a.dot(px - r * 0.1, py - r * 0.1, max(0.22, r * 0.08), "white")


def cane_stages(kind):
    lc = pal(kind).get("leaf", "leaf"); fr = pal(kind).get("fruit", "berry")
    redbr = kind == "japanese-wineberry"
    cane_col = {"raspberry": "leaf", "blackberry": "plum", "loganberry": "rust", "japanese-wineberry": "berry"}[kind]

    def canes(a, col=None, tied=True):
        col = col or cane_col
        if kind == "raspberry":   # upright, little-branched canes in a row
            qs = [a.ribbon((50 + dx, 88), (50 + dx * 1.2, 56), (50 + dx * 1.4, 12 + abs(dx) * 0.4), 2.4, 1.4, col, lw=0.8)
                  for dx in (-19, 0, 19)]
        else:                     # long arching canes, fanned out and tied along the wires
            qs = []
            for sg in (-1, 1):
                for p1, c in (((50 + sg * 38, 34), (50 + sg * 12, 30)), ((50 + sg * 40, 57), (50 + sg * 14, 52)), ((50 + sg * 30, 22), (50 + sg * 4, 20))):
                    qs.append(a.ribbon((50 + sg * 2, 88), c, p1, 2.2, 1.2, col, lw=0.8))
        if redbr:   # wineberry: canes thick with soft red bristles
            for q in qs:
                for j in range(24):
                    x, y = q.pt(0.04 + 0.94 * j / 23); ang = q.ang(0.04 + 0.94 * j / 23) + (90 if j % 2 else -90)
                    a.line(f"M{f(x)},{f(y)} L{P(T(x, y, ang + 20)(1.8))}", 0.6, 0.95, "beet")
        elif kind != "blackberry":   # fine prickles (raspberry, loganberry); 'Thornfree' blackberry has none
            for q in qs:
                for j in range(8):
                    u = 0.1 + 0.85 * j / 7; x, y = q.pt(u); ang = q.ang(u) + (90 if j % 2 else -90)
                    a.line(f"M{f(x)},{f(y)} L{P(T(x, y, ang + 30)(1.2))}", 0.45, 0.8)
        return qs

    def frame_(a, col=None):
        wires(a)
        return canes(a, col)

    backs = ("white", 4 if kind == "raspberry" else 3) if kind in ("raspberry", "japanese-wineberry") else None   # white-felted beneath

    def leaves(a, qs, us=(0.3, 0.5, 0.7, 0.9), L=14, fill=None):
        if kind == "raspberry":   # fewer, larger leaves, so each reads as a leaf of five leaflets when small
            us, L = (0.34, 0.62, 0.9), L * 1.35
        leaves_on(a, kind, qs, us, L, fill=fill, spread=60, top=False, backs=backs)

    def young():
        a = Art(); ground(a)
        if kind == "raspberry":
            qs = canes(a)
        else:   # young canes, not yet tied in
            qs = [a.ribbon((50 + sg * 2, 88), (50 + sg * 17, 40), (50 + sg * 35, 52 - 10 * k), 2.0, 1.1, cane_col, lw=0.8)
                  for sg in (-1, 1) for k in (0, 1)]
            if redbr:
                for q in qs:
                    for j in range(12):
                        x, y = q.pt(0.06 + 0.9 * j / 11); ang = q.ang(0.06 + 0.9 * j / 11) + (90 if j % 2 else -90)
                        a.line(f"M{f(x)},{f(y)} L{P(T(x, y, ang + 20)(1.6))}", 0.55, 0.9, "berry")
        leaves(a, qs, (0.3, 0.52, 0.74, 0.95), 18)
        return a

    def dormant():
        a = Art(); ground(a); qs = frame_(a, "bark" if kind == "raspberry" else None)
        for q in qs:
            for u in (0.3, 0.5, 0.7, 0.9):
                x, y = q.pt(u); a.oval(*T(x, y, q.ang(u) - 70)(1.1), 0.7, 1.0, 0, "bark" if not redbr else "berry", 0.45)
        if kind == "raspberry":   # each cane tied to the wires
            for q in qs:
                for wy in (58, 34):
                    best = min((abs(q.pt(i / 40)[1] - wy), i / 40) for i in range(41))[1]
                    x, y = q.pt(best); a.line(f"M{f(x - 1.6)},{f(y - 1)} L{f(x + 1.6)},{f(y + 1)}", 0.9, 0.9, "straw")
        if kind == "blackberry":   # a few purplish leaves left on
            for q in qs[::2]:
                x, y = q.pt(0.8); own(a, kind, x, y, q.ang(0.8) - 60, 11, "plum")
        return a

    def flower():
        a = Art(); ground(a); qs = frame_(a); leaves(a, qs, (0.3, 0.55, 0.8), 16)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.45, 0.72, 0.96)):
                    if kind == "raspberry" and j == 2:
                        continue
                    x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                    if kind == "raspberry":   # a side shoot reaching out clear of the leaves
                        u = (0.48, 0.76)[j]; x, y = q.pt(u); e = (x + sd * 8, y - 2)
                        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4)},{f(y - 3)} {P(e)}", 0.7, 0.9)
                    else:
                        e = (x + sd * 4, y - 3); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.6, 0.9)   # a short side shoot
                    for m, (dx, dy) in enumerate(((0, 0), (sd * 2.6, 2.2), (-sd * 1.6, 2.6))):
                        px, py = e[0] + dx, e[1] + dy
                        if kind == "raspberry":   # small nodding white cups: grey-green sepals turned back, white petals below
                            if m == 2:
                                continue
                            px, py = e[0] + (sd * 4.4 if m else 0), e[1] + (1.6 if m else 0)
                            a.line(f"M{P(e)} Q{f(px)},{f(py - 1)} {f(px)},{f(py + 1)}", 0.5, 0.85)
                            for d in (-55, 55):
                                a.leaf(px, py + 1.2, -90 + d, 2.4, 0.42, "sage", lw=0.4, detail=False)
                            for d in (-28, 0, 28):
                                a.leaf(px, py + 1.0, 90 + d, 4.0, 0.62, "white", lw=0.5, detail=False)
                            a.oval(px, py + 4.0, 1.4, 1.2, 0, "pale", 0.5)
                        elif redbr:              # red bristly buds and small white flowers
                            if m == 1:
                                a.oval(px, py, 1.6, 2.0, 0, "beet", 0.5)
                                for d in range(4):
                                    a.line(f"M{f(px)},{f(py)} L{P(T(px, py, d * 90 + 45)(2.6))}", 0.4, 0.85, "berry")
                            else:
                                for d in range(5):
                                    a.leaf(px, py, -90 + d * 72, 3.2, 0.3, "beet", lw=0.45, detail=False)
                                a.flower(px, py, 1.7, 5, "white", None, 0.6, lw=0.4); a.dot(px, py, 0.5, "pale")
                        else:                     # open flowers, buds among them
                            if m == 2:
                                a.oval(px, py, 1.2, 1.5, 0, "pink" if kind == "blackberry" else "white", 0.5)
                            else:
                                a.flower(px, py, 3.0, 5, "white", None, 0.85, start=-90 + m * 30, lw=0.5); a.dot(px, py, 0.8, "pale")
        return a

    def crop():
        a = Art(); ground(a); qs = frame_(a); leaves(a, qs, (0.3, 0.55, 0.8), 16)
        with a.on(BLOOM):
            for qi, q in enumerate(qs):
                for j, u in enumerate((0.45, 0.72, 0.95)):
                    if kind == "raspberry" and j == 2:
                        continue
                    x, y = q.pt(u); sd = 1 if (j + qi) % 2 else -1
                    if kind == "raspberry":   # hanging from a side shoot, clear of the leaves
                        u = (0.48, 0.76)[j]; x, y = q.pt(u); e = (x + sd * 7, y - 1)
                        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 4)},{f(y - 3)} {P(e)}", 0.7, 0.9)
                    else:
                        e = (x + sd * 3, y - 1); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.6, 0.9)
                    for m, dx in enumerate((-2.6, 2.6) if (j % 2 or kind == "raspberry") else (0,)):
                        px = e[0] + dx; a.line(f"M{P(e)} L{f(px)},{f(e[1] + 2)}", 0.4, 0.85)
                        if kind == "raspberry":   # solid red rounded berries of drupelets
                            drupe(a, px, e[1] + 2, 2.8, fr, 1.05)
                        elif kind == "blackberry":   # glossy black, with red and green ones among them
                            drupe(a, px, e[1] + 2, 2.2, (fr, "berry", fr, "unripe")[(qi + j + m) % 4], 1.15, shine=True)
                        elif kind == "loganberry":   # long cones, dark red; green and red ones beside
                            drupe(a, px, e[1] + 2, 1.8, (fr, "berry", fr, "unripe")[(qi + j + m) % 4], 1.6)
                        else:                         # wineberry: scarlet berries sitting in the opened bristly sepals
                            for d in range(5):
                                a.leaf(px, e[1] + 3.6, -90 + d * 72 + 36, 3.4, 0.3, "beet", lw=0.45, detail=False)
                            a.oval(px, e[1] + 3.6, 1.9, 1.9, 0, fr, 0.55); a.dot(px - 0.6, e[1] + 2.9, 0.4, "white")
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


for _k in ("raspberry", "blackberry", "loganberry", "japanese-wineberry"):
    STAGE[_k] = cane_stages(_k)


# ============================================================ vines
def grape_stages():
    kind = "grape"; fr = pal(kind).get("fruit", "plum"); fc = pal(kind).get("flower", "pale")

    def tendril(a, x, y, sd):
        a.line(f"M{f(x)},{f(y)} q{f(sd * 3)},-3 {f(sd * 5)},-2 q{f(sd * 2)},1 {f(sd * 1)},3 q{f(-sd * 1.5)},0.5 {f(-sd * 1)},-1", 0.6, 0.85)

    def frame_(a, young=False):
        for px in (10, 90):
            a.ribbon((px, 88), (px, 60), (px, 26), 2.4, 2.2, "bark")
        for wy in (54, 40, 28):
            a.line(f"M10,{wy} L90,{wy}", 0.6, 0.55)
        if young:
            a.ribbon((60, 88), (60, 60), (60, 30), 2.0, 2.0, "bark")   # a cane to grow up
            return a.ribbon((50, 88), (52, 66), (58, 30), 2.4, 1.4, "bark", lw=0.85)
        a.ribbon((50, 88), (48.5, 70), (50, 55), 5.0, 4.0, "bark")   # the gnarled trunk, its bark peeling
        for dy in (82, 74, 66):
            a.line(f"M{f(48.4)},{dy} q1.4,-2 2.6,-4", 0.6, 0.55)
        rods = []
        for sg in (-1, 1):   # one long rod along the bottom wire each way
            rods.append(a.ribbon((50, 56), (50 + sg * 16, 53), (50 + sg * 38, 54), 2.8, 1.8, "bark", lw=0.85))
        return rods

    def shoots(a, rods, extra=None):
        with a.group():
            for qi, q in enumerate(rods):
                sg = -1 if qi == 0 else 1
                for j, u in enumerate((0.25, 0.55, 0.85)):
                    x, y = q.pt(u)
                    e = (x + sg * 2, y - 26); sh = Quad((x, y), (x + sg * 1, y - 13), e)
                    a.line(sh.d(), 1.1, 0.9)
                    own(a, kind, *sh.pt(0.45), -90 - sg * 70, 13)
                    own(a, kind, *sh.pt(1.0), -90 + sg * 20, 12)
                    tendril(a, *sh.pt(0.75), -sg)
                    if extra:
                        extra(a, sh, sg, j)

    def young():
        a = Art(); ground(a); q = frame_(a, True)
        a.line("M53,72 L60,72", 1.0, 0.9, "straw"); a.line("M56,48 L60,48", 1.0, 0.9, "straw")
        with a.group():
            for j, u in enumerate((0.38, 0.62, 0.86)):
                x, y = q.pt(u); sd = -1 if j % 2 else 1
                own(a, kind, x, y, -90 + sd * 60, 14)
                tendril(a, x, y - 1, -sd)   # the tendril stands opposite the leaf
            own(a, kind, *q.pt(1), -96, 10)
        return a

    def dormant():
        a = Art(); ground(a); rods = frame_(a)
        for q in rods:
            for u in (0.18, 0.38, 0.58, 0.78, 0.96):
                x, y = q.pt(u); a.shape(f"M{f(x - 1)},{f(y - 1)} Q{f(x)},{f(y - 3.6)} {f(x + 1)},{f(y - 1)} Z", "bark", 0.6)   # a bud at each node
            for u in (0.3, 0.7):
                x, y = q.pt(u); a.line(f"M{f(x - 2)},{f(y + 0.4)} q2,0.8 4,0", 0.5, 0.5)   # peeling bark
        return a

    def flower():
        a = Art(); ground(a); rods = frame_(a)
        def ex(a, sh, sg, j):   # a dense green flower cluster opposite a leaf
            x, y = sh.pt(0.45)
            with a.on(BLOOM):
                for k in range(9):
                    rr = math.sqrt((k + 0.5) / 9); th = k * GOLD
                    a.oval(x + sg * 3 + rr * 2.6 * math.cos(th), y + 3 + rr * 4.4 * (0.5 + 0.5 * math.sin(th)), 1.0, 1.1, 0, fc, 0.4)
        shoots(a, rods, ex)
        return a

    def crop():
        a = Art(); ground(a); rods = frame_(a)
        def ex(a, sh, sg, j):   # a hanging cone-shaped bunch of grapes with a pale bloom
            x, y = sh.pt(0.3)
            with a.on(BLOOM):
                a.line(f"M{f(x)},{f(y)} L{f(x + sg * 3)},{f(y + 2)}", 0.6, 0.9)
                bx, by = x + sg * 3, y + 2
                for row, n in enumerate((4, 3, 3, 2, 1)):
                    for k in range(n):
                        px, py = bx + (k - (n - 1) / 2) * 2.2, by + 1.4 + row * 2.0
                        a.oval(px, py, 1.2, 1.25, 0, fr, 0.45)
                        a.dot(px - 0.4, py - 0.4, 0.3, "white")
        shoots(a, rods, ex)
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


def kiwi_stages():
    kind = "kiwi"; fr = pal(kind).get("fruit", "unripe")

    def twine(a, x, y0, y1, col="rust", turns=3.5, amp=3.0, post=True):
        """A stem twining round a post: the parts behind the post are drawn
        before it, the parts in front after it. Returns points along it."""
        n = 60
        pts = [(x + amp * math.sin(2 * math.pi * turns * i / n), y0 + (y1 - y0) * i / n, math.cos(2 * math.pi * turns * i / n)) for i in range(n + 1)]
        segs_back, segs_front, cur, front = [], [], [pts[0]], pts[0][2] > 0
        for p in pts[1:]:
            cur.append(p)
            if (p[2] > 0) != front:
                (segs_front if front else segs_back).append(cur); cur = [p]; front = p[2] > 0
        (segs_front if front else segs_back).append(cur)
        for sgm in segs_back:
            a.line(opath([(p[0], p[1]) for p in sgm]), 1.4, 0.85, col)
        if post:
            a.ribbon((x, 88), (x, 60), (x, y1 - 4), 3.0, 2.8, "bark")
        for sgm in segs_front:
            a.line(opath([(p[0], p[1]) for p in sgm]), 1.6, 0.95, col)
        return pts

    def frame_(a, col="rust"):
        a.line("M10,22 L90,22", 0.7, 0.6)
        for px in (10, 90):
            a.ribbon((px, 88), (px, 60), (px, 20), 2.4, 2.2, "bark")
        pts = twine(a, 50, 88, 24, col, 4.0, 2.6)
        arms = []
        for sg in (-1, 1):   # two arms twined along the wire
            n = 30; arm = []
            for i in range(n + 1):
                u = i / n; arm.append((50 + sg * 38 * u, 23 + 1.6 * math.sin(2 * math.pi * 5 * u)))
            a.line(opath(arm), 1.3, 0.9, col)
            arms.append(arm)
        return pts, arms

    def leaves(a, arms, L=13, hang=None):
        with a.group():
            for sg, arm in zip((-1, 1), arms):
                for j, i in enumerate((7, 14, 21, 27)):
                    x, y = arm[i]
                    own(a, kind, x, y, -90 + sg * (25 + 20 * (j % 2)), L)
                    if hang:
                        hang(a, x, y, sg, j)

    def young():
        a = Art(); ground(a)
        pts = twine(a, 50, 88, 30, "rust", 3.0, 2.4)
        with a.group():
            for j, i in enumerate((22, 34, 46, 58)):
                x, y, _ = pts[i]; sd = 1 if j % 2 else -1
                own(a, kind, x + sd * 1.5, y, -90 + sd * 62, 15)
        return a

    def dormant():
        a = Art(); ground(a); pts, arms = frame_(a, "rust")
        for arm in arms:
            for i in (6, 14, 22, 28):
                x, y = arm[i]; a.dot(x, y + 1.2, 0.6, "bark")
        return a

    def flower():
        a = Art(); ground(a); pts, arms = frame_(a)
        def hang(a, x, y, sg, j):   # white cup flowers hanging under the leaves, in ones to threes
            with a.on(BLOOM):
                for m in range(1 + j % 3):
                    px = x + (m - 1) * 3.2
                    a.line(f"M{f(x)},{f(y)} L{f(px)},{f(y + 6)}", 0.5, 0.9)
                    a.shape(f"M{f(px - 1.2)},{f(y + 6)} Q{f(px - 3.0)},{f(y + 8.5)} {f(px - 3.0)},{f(y + 9.4)} L{f(px + 3.0)},{f(y + 9.4)} Q{f(px + 3.0)},{f(y + 8.5)} {f(px + 1.2)},{f(y + 6)} Z", "white", 0.6)
                    a.oval(px, y + 9.4, 3.0, 0.9, 0, "white", 0.5); a.dot(px, y + 9.5, 0.6, "dark")
        leaves(a, arms, 13, hang)
        return a

    def crop():
        a = Art(); ground(a); pts, arms = frame_(a)
        def hang(a, x, y, sg, j):   # small smooth green fruit, grape-sized, hanging along the stems
            with a.on(BLOOM):
                for m in range(3):
                    px = x + (m - 1) * 3.0 + sg
                    a.line(f"M{f(x)},{f(y)} L{f(px)},{f(y + 6 + (m % 2))}", 0.5, 0.9)
                    a.oval(px, y + 8.6 + (m % 2), 1.6, 2.2, 0, fr, 0.55)
                    a.dot(px, y + 10.9 + (m % 2), 0.35, "bark"); a.dot(px - 0.5, y + 7.8 + (m % 2), 0.3, "white")
        leaves(a, arms, 13, hang)
        return a

    return {"young": young, "dormant": dormant, "flower": flower, "crop": crop}


STAGE["grape"] = grape_stages()
STAGE["kiwi"] = kiwi_stages()


# ============================================================ strawberry
def strawberry_stages():
    """No stem: every leaf and flower stalk rises from a crown at the soil.
    Each leaf is the close-up's three-leaflet leaf, drawn small."""
    kind = "strawberry"; fr = pal(kind).get("fruit", "berry")

    def rosette(a, crown, leaves, fill=None, k=1.0):
        """Leaves on long arching stalks from the crown: (direction, stalk
        length, leaf colour if not the usual)."""
        with a.group():
            for ang, S, *rest in leaves:
                e = T(*crown, ang)(S * k); c = T(*crown, ang + (8 if ang < -90 else -8))(S * k * 0.55)
                c = (c[0], c[1] - S * k * 0.12)
                a.stem(crown, c, e, 1.0)
                own(a, kind, e[0], e[1], ang + (10 if ang < -90 else -10 if ang > -90 else 0), 26 * k, rest[0] if rest else fill)

    def young():
        a = Art(); ground(a, 84)
        rosette(a, (50, 84), [(-146, 22), (-34, 22), (-116, 30), (-64, 30), (-90, 34)])
        a.oval(50, 83.6, 3.4, 1.8, 0, "bark", 0.8)
        return a

    def flower():
        a = Art(); ground(a, 84)
        rosette(a, (50, 84), [(-150, 22), (-30, 22), (-120, 28), (-60, 28)], k=0.95)
        sp = dict(BLOOMX[kind], ns=10, sr=0.42, pw=0.86, sepc="leaf", anth="sun", styles=5, cup=None)
        with a.on(BLOOM):
            for (x, y), c, fl in (((40, 34), (44, 60), ((-4, 0), (4.5, 3))), ((63, 42), (58, 62), ((0, 0), (-5, 4)))):
                a.stem((50, 84), c, (x, y), 1.0)
                for k, (dx, dy) in enumerate(fl):   # small loose clusters on branched stalks
                    a.line(f"M{f(x)},{f(y)} L{f(x + dx)},{f(y + dy)}", 0.7, 0.85)
                    blossom_flower(a, x + dx, y + dy, 6.4 if k == 0 else 5.4, sp, start=-90 + k * 20, k=0.88)
                    a.oval(x + dx, y + dy, 1.4, 1.2, 0, pal(kind).get("centre", "primrose"), 0.5)
            a.line("M61,48 Q66,46 69,47", 0.7, 0.85); a.oval(70.4, 47, 1.8, 1.6, 0, "unripe", 0.6)
        return a

    def crop():
        a = Art(); ground(a, 86)
        rosette(a, (50, 86), [(-140, 22), (-40, 22), (-112, 30), (-68, 30), (-90, 34)])
        with a.on(BLOOM):
            for (x, y), c, s_, fill in (((20, 72), (24, 58), 1.0, fr), ((80, 71), (76, 57), 0.95, fr), ((63, 75), (62, 64), 0.7, "white")):
                a.stem((50, 86), c, (x, y - 1), 1.0)   # the fruit hang on their own stalks, down to rest near the soil
                S10.berry(a, x, y, s_, fill)   # red cone-shaped fruit: seeds on the surface, a green ruff
        return a

    def runner():
        a = Art(); ground(a, 84)
        rosette(a, (27, 84), [(-136, 18), (-44, 18), (-92, 26)], k=0.8)
        a.oval(27, 83.6, 2.8, 1.6, 0, "bark", 0.8)
        a.line("M29,83 Q50,74 70,83", 1.0, 0.85, "berry"); a.line("M70,83 Q81,78 92,82", 0.9, 0.85, "berry")   # the runner, along the ground
        a.roots(70, 84, 3, 6, 60)
        rosette(a, (70, 83), [(-130, 9), (-50, 9), (-92, 12)], k=0.5)   # a new small plant, rooting where it touched down
        return a

    def dormant():
        a = Art(); ground(a, 84)
        rosette(a, (50, 84), [(-158, 14, "rust"), (-22, 14, "berry"), (-120, 16), (-60, 16, "rust"), (-90, 16)], k=0.8)
        a.oval(50, 83.2, 3.8, 2.2, 0, "bark", 0.9)
        return a

    return {"young": young, "flower": flower, "crop": crop, "runner": runner, "dormant": dormant}


STAGE["strawberry"] = strawberry_stages()

# leaf="own": the life stages use each kind's own close-up leaf. (Every stage of
# these kinds is drawn by hand above, which does this already; the setting says
# so for anything else that reads the kind's settings.)
KIND = {k: dict(leaf="own") for k in ("pear", "plum", "nectarine", "fig", "olive-tree", "bristol-whitebeam", "gingko",
                                      "blackcurrant", "whitecurrant", "gooseberry", "blueberry", "honeyberry", "rose",
                                      "hydrangea", "japanese-spiraea", "raspberry", "blackberry", "loganberry",
                                      "japanese-wineberry", "grape", "kiwi")}
