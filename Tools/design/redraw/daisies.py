"""DOCSTRING_PLACEHOLDER"""
import json, math, os
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10

GOLD = 2.39996
BASE = (20, 92)    # where a close-up leaf's stalk starts (as in leaves_flowers.py)
ANG = -52          # and the way a close-up leaf points
G = 72             # the soil line in a seedling drawing

COLOURS = {
    "daisies_picotee":   ("#C2335E", "#D9668A"),   # cosmos 'Fizzy Rose Picotee': the dark pinkish-red edge
    "daisies_raspberry": ("#D2386C", "#DE5F88"),   # zinnia 'Raspberry Lemonade'
    "daisies_navy":      ("#3B2F6E", "#7466B0"),   # African daisy: the deep blue-purple middle
    "daisies_cornblue":  ("#3D6FD1", "#6B91E0"),   # cornflower: strong mid blue
    "daisies_steel":     ("#4F78C4", "#7698D8"),   # globe thistle: metallic steel blue
    "daisies_violet":    ("#6F5FB3", "#9584D2"),   # devil's-bit scabious: blue-violet
    "daisies_rampion":   ("#4B4FB0", "#7B7ED6"),   # Oxford rampion: deep violet-blue
    "daisies_silver":    ("#DCE3DE", "#AEB9B1"),   # Senecio 'Angel Wings': silvery white felt
}

DESC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "Design", "Plants", "descriptions")
_PAL = {}


def pal(kind, part, default):
    """A colour from the kind's description ("palette"), by name."""
    if kind not in _PAL:
        try:
            with open(os.path.join(DESC, kind + ".json"), encoding="utf-8") as fh:
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


# ============================================================ outlines
def prof(umax=0.5, base="round", tip="point", bp=None, tp=None, b0=0.0):
    """A leaf's width along its length (0 at the base, 1 at the tip), as a
    share of its widest. umax is where it is widest. base: "wedge", "round"
    or "taper" (a long narrow wedge). tip: "round", "point", "acum" (drawn
    out into a long point) or "blunt". b0: how wide it already is at the
    very base (a leaf whose base is cut straight across)."""
    def fn(u):
        if u <= 0 or u >= 1:
            return b0 if u <= 0 else 0.0
        if u <= umax:
            v = u / umax
            if base == "wedge":
                w = v ** (bp or 1.0)
            elif base == "taper":
                w = v ** (bp or 1.7)
            else:
                w = math.sin(math.pi / 2 * v) ** (bp or 0.55)
            return b0 + (1 - b0) * w
        v = (u - umax) / (1 - umax)
        if tip == "round":
            return (1 - v ** (tp or 2.2)) ** 0.5
        if tip == "blunt":
            return (1 - v ** (tp or 3.0)) ** 0.42
        if tip == "acum":
            return math.cos(math.pi / 2 * v) ** 0.75 * (1 - v) ** (tp or 0.9)
        return math.cos(math.pi / 2 * v) ** (tp or 0.95)
    return fn


NICK = {
    "saw":   lambda s: (1 - s) ** 1.6,                           # sharp, pointing to the tip
    "round": lambda s: abs(math.cos(math.pi * s)) ** 2.4,        # rounded teeth
    "wave":  lambda s: 0.5 + 0.5 * math.cos(2 * math.pi * s),    # only a wavy edge
    "spine": lambda s: (1 - s) ** 0.7,                           # narrow sharp points
}


def resample(pts, step=0.3):
    """The same line with its points evenly spaced, step apart."""
    out = [pts[0]]; carry = 0.0
    for a_, b_ in zip(pts, pts[1:]):
        L = math.dist(a_, b_)
        if L == 0:
            continue
        d = step - carry
        while d <= L:
            u = d / L; out.append((a_[0] + (b_[0] - a_[0]) * u, a_[1] + (b_[1] - a_[1]) * u)); d += step
        carry = L - (d - step)
    if out[-1] != pts[-1]:
        out.append(pts[-1])
    return out


def serrate(pts, side, spacing, depth, kind="saw", L=100.0, frm=0.0, to=1.0, mask=None, irr=0.0):
    """Cuts teeth into one edge of a leaf. pts run from the base to the tip,
    measured along the leaf (x from 0 to L; side 1 is the upper edge, -1 the
    lower). A tooth every `spacing` along the edge, `depth` deep (both in
    grid squares), of the kind in NICK. Only between frm and to (shares of
    the length); mask(x, y) can switch teeth off (0) or on (1) anywhere."""
    pts = resample(pts, min(0.3, spacing / 10))
    out = [pts[0]]; s = 0.0
    for i in range(1, len(pts) - 1):
        s += math.dist(pts[i - 1], pts[i])
        tx, ty = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]; n = math.hypot(tx, ty) or 1
        tx, ty = tx / n, ty / n
        nx, ny = (ty, -tx) if side > 0 else (-ty, tx)   # pointing into the leaf
        u = pts[i][0] / L
        fade = max(0.0, min(1.0, (u - frm) / 0.05, (to - u) / 0.04))
        if mask:
            fade *= mask(*pts[i])
        k = int(s / spacing)
        d = depth * (1 + irr * math.sin(k * 2.7 + side)) * NICK[kind]((s / spacing) % 1) * fade
        out.append((pts[i][0] + nx * d, pts[i][1] + ny * d))
    out.append(pts[-1])
    return out


def simple_edges(L, W, pf, n=140, cord=0.0, lop=0.0):
    """The two edges of a simple leaf laid along x from 0 to L. cord pulls
    the base back past where the stalk joins: a heart-shaped base, or ears
    that clasp a stem."""
    us = [i / n for i in range(n + 1)]
    back = lambda u: cord * L * max(0.0, math.sin(math.pi * u / 0.32)) if u < 0.32 else 0.0
    top = [(L * u - back(u), pf(u) * W / 2 * (1 + lop)) for u in us]
    bot = [(L * u - back(u), -pf(u) * W / 2 * (1 - lop)) for u in us]
    return top, bot


def notch(depth, width=0.4):
    """A dip in a round outline where the stalk joins (angle pi)."""
    return lambda h: 1 - depth * math.exp(-((abs(h) - math.pi) / width) ** 2)


def polar_edges(R, g, n=120):
    """The two edges of a broad leaf drawn round a centre: g(angle) is how
    far out the edge is, as a share of R, angle 0 pointing to the tip and
    pi to the stalk. The stalk joins at x=0, the tip is at the far end."""
    d = R * g(math.pi)
    top = [(d + R * g(h) * math.cos(h), R * g(h) * math.sin(h)) for h in [math.pi * (1 - i / n) for i in range(n + 1)]]
    bot = [(x, -y) for x, y in top]
    return top, bot


def lobed_edges(L, wing, lobes, shear=0.5, n=420, tipw=None):
    """The two edges of a leaf cut into lobes down both sides.
    wing(u): half width of the uncut band along the midrib. lobes: a list of
    (u, half span as a share of L, length out, shape, side): shape "round"
    or "point"; side 1 or -1. Each side's edge is the furthest out the band
    or any lobe reaches; then the whole edge is sheared forward so the lobes
    lean towards the tip, as they do on a real leaf."""
    def g(t, shape):
        if abs(t) >= 1:
            return 0.0
        return math.sqrt(1 - t * t) if shape == "round" else (1 - abs(t)) ** 0.85 * (1 + 0.25 * (1 - abs(t)))

    def hw(u, side):
        w = wing(u)
        for uc, sp, ln, sh, sd in lobes:
            if sd == side:
                w = max(w, ln * g((u - uc) / sp, sh))
        return w
    out = []
    for side in (1, -1):
        e = []
        for i in range(n + 1):
            u = i / n; w = hw(u, side)
            e.append((L * u + shear * w, side * w))
        out.append(e)
    return out[0], out[1], hw


def lobe_tips(L, lobes, shear=0.5):
    return [(L * uc + shear * ln, sd * ln) for uc, sp, ln, sh, sd in lobes]


def draw_leaf(a, x, y, ang, top, bot, fill, lw=1.0, shade=0.1, veins=(), mid=None, midw=0.8, vw=0.5, va=0.36,
              M=None, veinc="line", midc="line", mida=0.55):
    """Fills the outline made of two edges (each from the base to the tip),
    shades its upper half and draws the midrib and veins (lines measured
    along the leaf, like the edges)."""
    t = T(x, y, ang)
    mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), fill, lw)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((p[0], 0)) for p in top[::-1]]), "shade", 0, fa=shade)
    if mid:
        a.line(opath([mp(p) for p in mid]), midw, mida, midc)
    for v in veins:
        a.line(opath([mp(p) for p in v]), vw, va, veinc)
    return mp


def side_veins(L, hw, us, reach=0.8, lean=0.1, curve=0.5):
    """Side veins from the midrib curving forward to the edge."""
    out = []
    for u1 in us:
        u0 = max(0.02, u1 - lean)
        for sd in (1, -1):
            w = hw(u1, sd) * reach * sd
            out.append([(L * u0, 0), (L * (u0 + lean * curve * 0.6), w * 0.45), (L * u1, w)])
    return out


def hairs(a, x, y, ang, edge, every=2.2, ln=1.1, M=None, col="line", la=0.6, lw=0.35):
    """Short hairs standing out from one edge of a leaf (or stem)."""
    t = T(x, y, ang)
    mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    pts = resample(edge, every)
    for i in range(1, len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i - 1], pts[i + 1]
        tx, ty = x1 - x0, y1 - y0; n = math.hypot(tx, ty) or 1
        sd = 1 if pts[i][1] >= 0 else -1
        nx, ny = (-ty / n, tx / n) if sd > 0 else (ty / n, -tx / n)
        p0 = pts[i]; p1 = (p0[0] + nx * ln + tx / n * ln * 0.5, p0[1] + ny * ln + ty / n * ln * 0.5)
        a.line(f"M{P(mp(p0))} L{P(mp(p1))}", lw, la, col)


def thread(a, pts, fill, w=1.2, ow=0.6):
    """A thread-thin leaf segment: an outline line with a coloured line on top."""
    d = opath(pts) if len(pts) > 2 else f"M{P(pts[0])} L{P(pts[1])}"
    a.line(d, w + ow, 0.9, "line"); a.line(d, w, 1.0, fill)


def qpts(p0, c, p1, n=6):
    q = Quad(p0, c, p1); return [q.pt(i / n) for i in range(n + 1)]


# ============================================================ each kind's leaf
# Every function below draws one leaf from x,y pointing along ang, L long
# (stalk and all), in colour fill. small=True is the same leaf with less
# detail, for the life-stage drawings, where it is only 8 to 25 squares long.
# The close-ups (LEAF_DRAW, further down) and the life stages both call
# these, so the leaf on the whole plant is the same leaf as the close-up.

def _lw(L):
    return 1.0 if L > 40 else (0.85 if L > 16 else 0.7)


def stalk_to(a, x, y, ang, ln, w0, w1, fill, bend=0.0):
    t = T(x, y, ang)
    a.ribbon((x, y), t(ln * 0.5, ln * bend), t(ln), w0, w1, fill, lw=0.8 if w0 < 2 else 0.9)
    return t(ln)


def lf_sunflower(a, x, y, ang, L, fill, small=False):
    """Broad heart-shaped leaf with a sharp tip, coarse forward teeth all
    round, three big veins from the base, on a long stalk."""
    pet = 0.34 * L; BL = L - pet; W = BL * 0.92
    A = stalk_to(a, x, y, ang, pet, max(0.9, L * 0.034), max(0.7, L * 0.026), fill, 0.03)
    R = BL * 0.5
    g = lambda h: (1 + 0.1 * math.cos(h)) * (1 + 0.42 * math.exp(-(h / 0.42) ** 2)) * notch(0.72, 0.5)(h)
    top, bot = polar_edges(R, g)
    BL = top[-1][0]
    pf = lambda u: 0.9
    sp = max(1.7, BL * 0.07); dp = max(0.7, BL * 0.028)
    top = serrate(top, 1, sp, dp, "saw", BL, 0.0, 0.97, irr=0.35); bot = serrate(bot, -1, sp, dp, "saw", BL, 0.0, 0.97, irr=0.35)
    veins = []
    if not small or L > 14:
        for sd in (1, -1):
            veins.append([(0.02 * BL, 0), (0.12 * BL, sd * 0.2 * BL), (0.34 * BL, sd * 0.3 * BL), (0.6 * BL, sd * 0.25 * BL)])
        if not small:
            hw = lambda u, sd: pf(u) * W / 2
            veins += side_veins(BL, hw, (0.5, 0.64, 0.78), 0.82, 0.12)
            for sd in (1, -1):   # small veins off the outer side of each big vein
                for v in (0.2, 0.36):
                    veins.append([(v * BL, sd * 0.27 * BL), (v * BL + 0.06 * BL, sd * 0.37 * BL)])
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L), veins=veins, mid=[(0, 0), (0.5 * BL, 0), (0.92 * BL, 0)],
              midw=0.9 if not small else 0.6, vw=0.55 if not small else 0.45)


def lf_calendula(a, x, y, ang, L, fill, small=False, hairy=True):
    """Spoon-shaped, widest near the rounded tip, the base narrowing and
    clasping the stem, a few small far-spaced teeth, soft hairs, pale midrib."""
    pf = prof(0.66, "taper", "round", bp=1.25, tp=2.0, b0=0.16)
    top, bot = simple_edges(L, L * 0.36, pf, cord=0.035)
    sp = L * 0.15; dp = max(0.4, L * 0.012)
    top = serrate(top, 1, sp, dp, "saw", L, 0.32, 0.9); bot = serrate(bot, -1, sp * 1.1, dp, "saw", L, 0.3, 0.9)
    hw = lambda u, sd: pf(u) * L * 0.18
    veins = side_veins(L, hw, (0.42, 0.6, 0.76), 0.7, 0.16) if not small else []
    mp = draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), veins=veins, va=0.25, mid=[(0, 0), (0.5 * L, 0), (0.9 * L, 0)],
                   midw=1.4 if not small else 0.7, midc="pale" if not small else "line", mida=1.0 if not small else 0.45)
    if hairy and not small:
        hairs(a, x, y, ang, top[3:-3], 1.5, 0.8, la=0.4)
        hairs(a, x, y, ang, bot[3:-3], 1.5, 0.8, la=0.4)


def lf_cosmos(a, x, y, ang, L, fill, small=False):
    """Cut twice into thread-fine, smooth segments; broadly oval to
    triangular overall, sitting almost straight on the stem."""
    t = T(x, y, ang); w = 1.15 if not small else 0.55; ow = 0.6 if not small else 0.45
    q = Quad(t(0), t(L * 0.5, -L * 0.03), t(L))
    thread(a, [q.pt(i / 8) for i in range(9)], fill, w * 1.1, ow)
    n = 4 if not small else 3
    for i in range(n):
        u = 0.08 + 0.7 * i / (n - 1); px, py = q.pt(u); qa = q.ang(u)
        l = L * 0.55 * (1 - u) ** 0.5 * min(1.0, (u + 0.3) / 0.45)
        for sd in (1, -1):
            pa = qa + sd * 50; tp = T(px, py, pa)
            pts = [tp(l * v, -sd * l * 0.12 * v * (1 - v)) for v in (0, 0.25, 0.5, 0.75, 1)]
            thread(a, pts, fill, w, ow)
            subs = (0.3, 0.62) if not small else (0.45,)
            for j, v in enumerate(subs):
                b = tp(l * v, -sd * l * 0.12 * v * (1 - v))
                for sd2 in ((1, -1) if not small else (sd,)):
                    sl = l * 0.5 * (1.1 - v * 0.5)
                    e = T(*b, pa + sd2 * 42)(sl); m = T(*b, pa + sd2 * 36)(sl * 0.55)
                    thread(a, [b, m, e], fill, w * 0.9, ow)
    e = q.pt(1); thread(a, [e, T(*e, q.ang(1))(L * 0.12)], fill, w, ow)


def lf_zinnia(a, x, y, ang, L, fill, small=False):
    """Lance-shaped to narrow oval, stalkless with a rounded base, smooth,
    with three veins from the base."""
    pf = prof(0.33, "round", "point", bp=0.55, tp=0.85, b0=0.12)
    top, bot = simple_edges(L, L * 0.38, pf, cord=0.03)
    veins = []
    if not small or L > 12:
        for sd in (1, -1):
            veins.append([(0.03 * L, 0), (0.12 * L, sd * 0.1 * L), (0.42 * L, sd * 0.12 * L), (0.75 * L, sd * 0.06 * L)])
    draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), veins=veins, mid=[(0, 0), (0.5 * L, 0), (0.9 * L, 0)], midw=0.8 if not small else 0.5)


def lf_rudbeckia(a, x, y, ang, L, fill, small=False, stem=False):
    """Oval to spoon-shaped on a winged stalk (a basal leaf), or lance-shaped
    and stalkless (stem=True); a few shallow teeth, stiff bristly hairs."""
    if stem:
        pf = prof(0.4, "round", "point", bp=0.7, tp=0.85, b0=0.1); W = 0.3 * L
    else:
        pf = prof(0.58, "taper", "point", bp=1.7, tp=0.85, b0=0.04); W = 0.42 * L
    top, bot = simple_edges(L, W, pf)
    sp = L * 0.12; dp = max(0.35, L * 0.016)
    top = serrate(top, 1, sp, dp, "saw", L, 0.4, 0.9, irr=0.3); bot = serrate(bot, -1, sp, dp, "saw", L, 0.38, 0.9, irr=0.3)
    veins = []
    if not small:
        u0 = 0.06 if stem else 0.3
        for sd in (1, -1):
            veins.append([(u0 * L, 0), ((u0 + 0.08) * L, sd * W * 0.25), ((u0 + 0.3) * L, sd * W * 0.32), (0.86 * L, sd * W * 0.12)])
    draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), veins=veins, mid=[(0, 0), (0.5 * L, 0), (0.9 * L, 0)], midw=1.0 if not small else 0.5)
    if not small:
        hairs(a, x, y, ang, top[2:-2], 1.25, 1.2, la=0.55, lw=0.38)
        hairs(a, x, y, ang, bot[2:-2], 1.25, 1.2, la=0.55, lw=0.38)
        t = T(x, y, ang)
        for k in range(26):   # bristles on the surface
            u = 0.25 + 0.65 * ((k * 0.618) % 1); v = ((k * 0.37) % 1 - 0.5) * 1.5 * pf(u) * W / 2
            p = t(u * L, v); e = t(u * L + 1.1, v + 0.4)
            a.line(f"M{P(p)} L{P(e)}", 0.35, 0.3)


def lf_marigold(a, x, y, ang, L, fill, small=False):
    """Pinnate: about eleven narrow, sharply toothed leaflets along a central
    stalk and one at the end; dark green, with clear oil-gland dots."""
    t = T(x, y, ang)
    q = Quad(t(0), t(L * 0.5, -L * 0.02), t(L * 0.8))
    a.ribbon(q.p0, q.c, q.p1, max(0.8, L * 0.02), max(0.5, L * 0.012), fill, lw=0.6 if small else 0.8)
    pairs = 5 if not small else 3
    for i in range(pairs):
        u = 0.18 + 0.78 * i / (pairs - 1); px, py = q.pt(u); qa = q.ang(u)
        l = L * 0.3 * (0.7 + 0.3 * min(1, u / 0.5))
        for sd in (1, -1):
            _leaflet_mari(a, px, py, qa + sd * 56, l, fill, small, glands=not small)
    e = q.pt(1); _leaflet_mari(a, e[0], e[1], q.ang(1), L * 0.27, fill, small, glands=not small)


def _leaflet_mari(a, x, y, ang, l, fill, small, glands=False):
    pf = prof(0.4, "wedge", "acum", bp=0.9, tp=0.7, b0=0.06)
    top, bot = simple_edges(l, l * 0.26, pf, n=90)
    if not small or l > 5:
        sp = max(0.9, l * 0.1); dp = max(0.45, l * 0.04)
        top = serrate(top, 1, sp, dp, "saw", l, 0.12, 0.92); bot = serrate(bot, -1, sp, dp, "saw", l, 0.12, 0.92)
    draw_leaf(a, x, y, ang, top, bot, fill, 0.8 if not small else 0.6, shade=0.1 if not small else 0,
              mid=[(0, 0), (0.85 * l, 0)] if not small else None, midw=0.5)
    if glands:
        t = T(x, y, ang)
        for u, sd in ((0.35, 1), (0.55, -1), (0.7, 1)):
            p = t(u * l, sd * pf(u) * l * 0.08); a.dot(p[0], p[1], 0.38, "pale")


def lf_oxeye(a, x, y, ang, L, fill, small=False):
    """Basal leaf: a round, spoon-shaped blade with rounded teeth, on a
    stalk about as long as itself."""
    pet = 0.46 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, max(0.8, L * 0.026), max(0.6, L * 0.02), fill, 0.02)
    pf = prof(0.62, "taper", "round", bp=1.25, tp=2.0, b0=0.06)
    top, bot = simple_edges(BL, BL * 0.66, pf)
    top, bot = [(0, 0)] + top, [(0, 0)] + bot
    sp = max(1.6, BL * 0.12); dp = max(0.6, BL * 0.05)
    top = serrate(top, 1, sp, dp, "round", BL, 0.12, 0.97); bot = serrate(bot, -1, sp, dp, "round", BL, 0.12, 0.97)
    hw = lambda u, sd: pf(u) * BL * 0.33
    veins = side_veins(BL, hw, (0.45, 0.65, 0.82), 0.7, 0.14) if not small else []
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L), veins=veins, va=0.25, mid=[(0, 0), (0.5 * BL, 0), (0.9 * BL, 0)],
              midw=0.9 if not small else 0.5)


def lf_oxeye_stem(a, x, y, ang, L, fill, small=False):
    """Stem leaf: narrow oblong, stalkless, clasping the stem with small
    ears, toothed along both sides, the teeth larger near the base."""
    pf = prof(0.3, "round", "blunt", bp=0.4, tp=2.4, b0=0.5)
    top, bot = simple_edges(L, L * 0.24, pf, cord=0.08)
    sp = max(1.4, L * 0.1); dp = max(0.55, L * 0.05)
    mask = lambda px, py: max(0.35, 1.25 - px / L)
    top = serrate(top, 1, sp, dp, "saw", L, 0.02, 0.95, mask); bot = serrate(bot, -1, sp, dp, "saw", L, 0.02, 0.95, mask)
    draw_leaf(a, x, y, ang, top, bot, fill, _lw(L) * 0.9, mid=[(0, 0), (0.85 * L, 0)], midw=0.6)


def lf_cornchamomile(a, x, y, ang, L, fill, small=False):
    """Cut once or twice into short, flat, narrow lobes, each ending in a
    tiny bristle point; grey-green and downy. Oblong overall, stalkless."""
    t = T(x, y, ang); lwd = 0.55 if not small else 0.45
    q = Quad(t(0), t(L * 0.5, -L * 0.02), t(L * 0.9))
    a.ribbon(q.p0, q.c, q.p1, max(0.9, L * 0.03), max(0.6, L * 0.018), fill, lw=lwd)
    n = 5 if not small else 4
    W = max(1.0, L * 0.04) if not small else max(0.9, L * 0.06)
    for i in range(n):
        u = 0.12 + 0.82 * i / (n - 1); px, py = q.pt(u); qa = q.ang(u)
        l = L * 0.24 * (0.75 + 0.25 * math.sin(math.pi * min(1, u + 0.1))) * (1 - 0.35 * max(0, u - 0.7) / 0.3)
        for sd in (1, -1):
            pa = qa + sd * 55
            _flat_lobe(a, px, py, pa, l, W * 1.3, fill, lwd, small)
            if not small:
                for v, sd2 in ((0.38, 1), (0.38, -1), (0.66, -1)):
                    b = T(px, py, pa)(l * v)
                    _flat_lobe(a, b[0], b[1], pa + sd2 * sd * 46, l * 0.42, W, fill, lwd, small)
    e = q.pt(1); _flat_lobe(a, e[0], e[1], q.ang(1), L * 0.12, W * 1.3, fill, lwd, small)


def _flat_lobe(a, x, y, ang, l, w, fill, lw, small):
    pf = prof(0.5, "wedge", "point", bp=0.3, tp=0.6, b0=0.7)
    top, bot = simple_edges(l, w, pf, n=24)
    draw_leaf(a, x, y, ang, top, bot, fill, lw, shade=0)
    if not small and l > 3:   # the bristle point
        t = T(x, y, ang); a.line(f"M{P(t(l))} L{P(t(l + 1.2))}", 0.4, 0.7)


def lf_pineapple(a, x, y, ang, L, fill, small=False):
    """Cut two or three times into very narrow, thread-like segments,
    short and crowded; oblong overall, stalkless, bright green."""
    t = T(x, y, ang); w = 1.05 if not small else 0.55; ow = 0.55 if not small else 0.45
    q = Quad(t(0), t(L * 0.5, -L * 0.02), t(L * 0.92))
    thread(a, [q.pt(i / 8) for i in range(9)], fill, w * 1.15, ow)
    n = 6 if not small else 4
    for i in range(n):
        u = 0.12 + 0.82 * i / (n - 1); px, py = q.pt(u); qa = q.ang(u)
        l = L * 0.3 * (0.8 + 0.2 * math.sin(math.pi * u)) * (1 - 0.4 * max(0, u - 0.7) / 0.3)
        for sd in (1, -1):
            pa = qa + sd * 50; tp = T(px, py, pa)
            thread(a, [tp(0), tp(l * 0.5, -sd * l * 0.05), tp(l)], fill, w, ow)
            if not small:
                for v, sd2 in ((0.4, 1), (0.4, -1), (0.7, -sd)):
                    b = tp(l * v, -sd * l * 0.05)
                    thread(a, [b, T(*b, pa + sd2 * 42)(l * 0.38 * (1.1 - v * 0.5))], fill, w * 0.9, ow)
    e = q.pt(1); thread(a, [e, T(*e, q.ang(1))(L * 0.1)], fill, w, ow)


def lf_feverfew(a, x, y, ang, L, fill, small=False):
    """Deeply cut into about four pairs of oblong lobes, each with rounded
    teeth and small lobes of its own; on a stalk. Yellow-green."""
    pet = 0.2 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, max(0.8, L * 0.024), max(0.6, L * 0.02), fill)
    lobes = []
    for i in range(4):
        u = 0.1 + 0.2 * i; ln = BL * (0.25 - 0.035 * i)
        lobes += [(u, 0.075, ln, "round", 1), (u + 0.03, 0.075, ln * 0.96, "round", -1)]
    lobes += [(0.9, 0.1, BL * 0.1, "round", 1), (0.9, 0.1, BL * 0.1, "round", -1)]
    wing = lambda u: BL * 0.035 * (1 - u * 0.3)
    top, bot, hw = lobed_edges(BL, wing, lobes, shear=0.42)
    if not small or L > 12:
        sp = max(1.3, BL * 0.045); dp = max(0.5, BL * 0.018)
        msk = lambda px, py: 1.0 if abs(py) > BL * 0.06 else 0.0
        top = serrate(top, 1, sp, dp, "round", BL * 1.1, 0.0, 1.2, msk); bot = serrate(bot, -1, sp, dp, "round", BL * 1.1, 0.0, 1.2, msk)
    veins = [[(L0 - 0.04 * BL, 0), (L0 + 0.5 * (tx - L0), ty * 0.5), (L0 + 0.85 * (tx - L0), ty * 0.85)]
             for (tx, ty), L0 in [(tp_, lb[0] * BL) for tp_, lb in zip(lobe_tips(BL, lobes, 0.42), lobes)]][:-2] if not small else []
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L), veins=veins, mid=[(0, 0), (0.5 * BL, 0), (0.92 * BL, 0)],
              midw=0.9 if not small else 0.5, va=0.3)


def lf_aster(a, x, y, ang, L, fill, small=False):
    """Narrow lance-shaped, pointed, stalkless, smooth and a little glossy."""
    pf = prof(0.38, "wedge", "acum", bp=0.75, tp=0.7, b0=0.14)
    top, bot = simple_edges(L, L * 0.2, pf, cord=0.02)
    mp = draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), mid=[(0, 0), (0.5 * L, 0), (0.9 * L, 0)], midw=0.8 if not small else 0.5)
    if not small:
        a.line(opath([mp((L * u, pf(u) * L * 0.05)) for u in (0.2, 0.32, 0.44, 0.54)]), 1.2, 0.45, "white")


def lf_african(a, x, y, ang, L, fill, small=False):
    """Oblong to spoon-shaped, widest beyond the middle, with a few widely
    spaced coarse teeth; no stalk."""
    pf = prof(0.66, "taper", "point", bp=1.25, tp=0.8, b0=0.1)
    top, bot = simple_edges(L, L * 0.34, pf)
    sp = L * 0.14; dp = max(0.55, L * 0.035)
    top = serrate(top, 1, sp, dp, "saw", L, 0.34, 0.88, irr=0.25); bot = serrate(bot, -1, sp * 1.05, dp, "saw", L, 0.32, 0.88, irr=0.25)
    hw = lambda u, sd: pf(u) * L * 0.17
    veins = side_veins(L, hw, (0.48, 0.66, 0.8), 0.7, 0.16) if not small else []
    draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), veins=veins, va=0.25, mid=[(0, 0), (0.5 * L, 0), (0.9 * L, 0)], midw=0.9 if not small else 0.5)


def lf_helipterum(a, x, y, ang, L, fill, small=False):
    """Narrow, linear, smooth-edged and stalkless, with a fine point."""
    pf = prof(0.35, "wedge", "point", bp=0.5, tp=0.7, b0=0.35)
    top, bot = simple_edges(L, max(1.4, L * 0.1), pf, n=60)
    draw_leaf(a, x, y, ang, top, bot, fill, _lw(L) * 0.9, mid=[(0, 0), (0.85 * L, 0)] if L > 14 else None, midw=0.5)
    if not small:
        t = T(x, y, ang); a.line(f"M{P(t(L))} L{P(t(L + 1.4))}", 0.45, 0.7)


def lf_cornflower(a, x, y, ang, L, fill, small=False, lobed=False):
    """Long, narrow and grass-like (upper leaves), or lance-shaped with a
    few narrow side lobes (lobed=True, lower leaves); grey and cottony."""
    if lobed:
        lobes = [(0.32, 0.05, L * 0.16, "point", 1), (0.36, 0.05, L * 0.14, "point", -1),
                 (0.5, 0.05, L * 0.12, "point", 1), (0.54, 0.05, L * 0.11, "point", -1)]
        pf = prof(0.55, "taper", "acum", bp=1.2, tp=0.7, b0=0.1)
        top, bot, hw = lobed_edges(L, lambda u: pf(u) * L * 0.06, lobes, shear=0.9)
    else:
        pf = prof(0.4, "wedge", "acum", bp=0.5, tp=0.6, b0=0.3)
        top, bot = simple_edges(L, max(1.4, L * 0.085), pf, n=80)
    draw_leaf(a, x, y, ang, top, bot, fill, _lw(L) * 0.95, mid=[(0, 0), (0.88 * L, 0)] if L > 14 else None, midw=0.55)
    if not small:   # cobwebby white wool
        t = T(x, y, ang)
        for k in range(5):
            u0 = 0.12 + 0.16 * k; o = 0.4 * ((k % 2) * 2 - 1)
            a.line(f"M{P(t(u0 * L, o))} Q{P(t((u0 + 0.05) * L, -o * 1.4))} {P(t((u0 + 0.11) * L, o * 0.6))}", 0.4, 0.75, "white")


def lf_globethistle(a, x, y, ang, L, fill, small=False, under=False):
    """Cut deeply, nearly to the midrib, into narrow pointed lobes, every lobe
    ending in a spine and the edges spiny; dark green and glossy above.
    under=True: the same leaf turned over, white-felted."""
    n = 6 if not small else 4
    lobes = []
    for i in range(n):
        u = 0.1 + 0.8 * i / (n - 1) * 0.92; ln = L * (0.2 - 0.12 * i / (n - 1))
        lobes += [(u, 0.055, ln, "point", 1), (u + 0.035, 0.055, ln * 0.95, "point", -1)]
    wing = lambda u: L * 0.022 * (1 - u * 0.4) + L * 0.05 * max(0, (u - 0.85) / 0.15) * (1 - u) * 5
    shear = 0.75
    top, bot, hw = lobed_edges(L, wing, lobes, shear=shear)
    if not small:
        msk = lambda px, py: 1.0 if abs(py) > L * 0.035 else 0.0
        top = serrate(top, 1, 2.4, 0.7, "spine", L * 1.15, 0.0, 1.2, msk); bot = serrate(bot, -1, 2.4, 0.7, "spine", L * 1.15, 0.0, 1.2, msk)
    veins = [[(lb[0] * L - 0.02 * L, 0), (tp_[0] * 0.92 + lb[0] * L * 0.08, tp_[1] * 0.85)] for tp_, lb in zip(lobe_tips(L, lobes, shear), lobes)] if not small else []
    mp = draw_leaf(a, x, y, ang, top, bot, "white" if under else fill, _lw(L), veins=veins, va=0.3,
                   mid=[(0, 0), (0.5 * L, 0), (0.95 * L, 0)], midw=1.2 if not small else 0.55,
                   midc="pale" if not (small or under) else "line", mida=1.0 if not (small or under) else 0.5)
    t = T(x, y, ang)
    for (tx, ty), lb in zip(lobe_tips(L, lobes, shear), lobes):   # a spine at every lobe tip
        sd = lb[4]; d = math.atan2(ty, tx - lb[0] * L)
        sl = 2.4 if not small else max(0.8, L * 0.05)
        e = (tx + sl * math.cos(d), ty + sl * math.sin(d))
        a.line(f"M{P(t(tx, ty))} L{P(t(*e))}", 0.5 if not small else 0.4, 0.85)


def lf_scabiosa(a, x, y, ang, L, fill, small=False, fine=False):
    """Basal leaf cut deeply into narrow lobes, each with a few teeth, on a
    stalk; fine=True: a stem leaf, smaller and cut more finely."""
    pet = 0.22 * L if not fine else 0.04 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, max(0.8, L * 0.024), max(0.6, L * 0.018), fill) if pet > 1 else (x, y)
    n = 5 if not fine else 4
    lobes = []
    for i in range(n):
        u = 0.1 + 0.62 * i / (n - 1); ln = BL * ((0.17 if not fine else 0.22) - 0.03 * i / (n - 1))
        sp = 0.045 if not fine else 0.03
        lobes += [(u, sp, ln, "round" if not fine else "point", 1), (u + 0.04, sp, ln * 0.94, "round" if not fine else "point", -1)]
    wing = lambda u: BL * (0.03 if not fine else 0.016) + BL * 0.075 * max(0, min(1, (u - 0.72) / 0.1)) * min(1, (1 - u) / 0.22) ** 0.7 * (1 if not fine else 0.4)
    top, bot, hw = lobed_edges(BL, wing, lobes, shear=0.55)
    if not small and not fine:
        msk = lambda px, py: 1.0 if abs(py) > BL * 0.05 else 0.0
        top = serrate(top, 1, 2.2, 0.8, "saw", BL * 1.1, 0.0, 1.2, msk); bot = serrate(bot, -1, 2.2, 0.8, "saw", BL * 1.1, 0.0, 1.2, msk)
    veins = [[(lb[0] * BL - 0.02 * BL, 0), (tp_[0] * 0.85 + lb[0] * BL * 0.15, tp_[1] * 0.8)] for tp_, lb in zip(lobe_tips(BL, lobes, 0.55), lobes)] if not (small or fine) else []
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L) * (0.85 if fine else 1), veins=veins, va=0.3,
              mid=[(0, 0), (0.5 * BL, 0), (0.92 * BL, 0)] if not small else None, midw=0.8)
    if not small and not fine:
        t = T(*A, ang)
        hairs(a, A[0], A[1], ang, [p for p in top if abs(p[1]) > 1.5][::3], 1.6, 0.7, la=0.35)


def lf_devilsbit(a, x, y, ang, L, fill, small=False, stem=False):
    """Basal leaf: undivided, oblong to elliptic, narrowing into a short
    winged stalk, smooth-edged, a strong pale midrib, purple at the edge.
    stem=True: a small narrow stem leaf."""
    if stem:
        pf = prof(0.4, "wedge", "point", bp=0.7, tp=0.8, b0=0.1); W = 0.18 * L
    else:
        pf = prof(0.55, "taper", "point", bp=1.5, tp=0.75, b0=0.05); W = 0.34 * L
    top, bot = simple_edges(L, W, pf)
    hw = lambda u, sd: pf(u) * W / 2
    veins = side_veins(L, hw, (0.4, 0.56, 0.7, 0.82), 0.75, 0.18) if not (small or stem) else []
    mp = draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), veins=veins, va=0.25, mid=[(0, 0), (0.5 * L, 0), (0.92 * L, 0)],
                   midw=1.5 if not small else 0.6, midc="pale" if not small else "line", mida=1.0 if not small else 0.45)
    if not stem:   # a purple flush along the edge
        for e in (top, bot):
            a.line(opath([mp((px, py * 0.93)) for px, py in e[int(len(e) * 0.2):-2]]), 1.8 if not small else 0.8, 0.45, "plum")


def lf_rampion(a, x, y, ang, L, fill, small=False):
    """Basal leaf: narrow lance-shaped on a long stalk, finely and unevenly
    toothed, smooth and a little glossy."""
    pet = 0.42 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, max(0.7, L * 0.02), max(0.55, L * 0.016), fill, 0.03)
    pf = prof(0.3, "round", "acum", bp=0.6, tp=0.8, b0=0.18)
    top, bot = simple_edges(BL, BL * 0.3, pf)
    top, bot = [(0, 0)] + top, [(0, 0)] + bot
    if not small:
        top = serrate(top, 1, 2.6, 0.5, "saw", BL, 0.06, 0.9, irr=0.5); bot = serrate(bot, -1, 2.6, 0.5, "saw", BL, 0.06, 0.9, irr=0.5)
    hw = lambda u, sd: pf(u) * BL * 0.15
    veins = side_veins(BL, hw, (0.3, 0.5, 0.7), 0.7, 0.15) if not small else []
    mp = draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L), veins=veins, va=0.22, mid=[(0, 0), (0.5 * BL, 0), (0.9 * BL, 0)], midw=0.8 if not small else 0.5)
    if not small:
        a.line(opath([mp((BL * u, pf(u) * BL * 0.07)) for u in (0.12, 0.24, 0.36, 0.48)]), 1.2, 0.45, "white")


def lf_senecio(a, x, y, ang, L, fill, small=False):
    """Big, broad and rounded, a wavy edge with small shallow teeth, on a
    short broad stalk; thick white felt hides the veins."""
    pet = 0.16 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, max(1.2, L * 0.05), max(1.0, L * 0.045), fill)
    pf = prof(0.5, "round", "round", bp=0.45, tp=1.7, b0=0.28)
    top, bot = simple_edges(BL, BL * 0.88, pf, cord=0.05)
    top, bot = [(0, 0)] + top, [(0, 0)] + bot
    sp = max(2.2, BL * 0.1); dp = max(0.6, BL * 0.022)
    top = serrate(top, 1, sp, dp, "wave", BL, 0.06, 0.98); bot = serrate(bot, -1, sp * 1.08, dp, "wave", BL, 0.06, 0.98)
    if not small:
        top = serrate(top, 1, 2.0, 0.45, "saw", BL * 1.05, 0.08, 1.0); bot = serrate(bot, -1, 2.0, 0.45, "saw", BL * 1.05, 0.08, 1.0)
    mp = draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L), shade=0.07, mid=[(0, 0), (0.45 * BL, 0), (0.8 * BL, 0)], midw=0.9, mida=0.25)
    if not small:   # the felt: a soft white sheen
        a.line(opath([mp((BL * u, -pf(u) * BL * 0.2)) for u in (0.2, 0.35, 0.5, 0.62)]), 3.0, 0.35, "white")


# ============================================================ close-up leaves
def stem_piece(a, p0, c, p1, w0, w1, fill, woolly=False):
    q = a.ribbon(p0, c, p1, w0, w1, fill, lw=0.9)
    if woolly:   # white cobwebby wool along the stem
        for k in range(6):
            u = 0.1 + 0.14 * k; x, y = q.pt(u); x2, y2 = q.pt(u + 0.07)
            a.line(f"M{f(x - 0.6)},{f(y)} Q{f(x + 0.9)},{f((y + y2) / 2)} {f(x2 - 0.3)},{f(y2)}", 0.4, 0.75, "white")
    return q


def cl_sunflower(a, sp):
    lf_sunflower(a, *BASE, ANG, 98, sp["fill"]); return a


def cl_calendula(a, sp):
    stem_piece(a, (6, 78), (16, 88), (30, 100), 3.4, 3.0, sp["fill"])
    with a.on(LEAF):
        lf_calendula(a, 18, 89, ANG, 94, sp["fill"])
    return a


def cl_cosmos(a, sp):
    q = stem_piece(a, (50, 100), (52, 56), (50, 8), 2.2, 1.6, "leaf")
    with a.on(LEAF):
        x, y = q.pt(0.26); lf_cosmos(a, x, y, -24, 50, sp["fill"]); lf_cosmos(a, x, y, -156, 50, sp["fill"])
        x, y = q.pt(0.7); lf_cosmos(a, x, y, -58, 34, sp["fill"]); lf_cosmos(a, x, y, -122, 34, sp["fill"])
    return a


def cl_zinnia(a, sp):
    q = stem_piece(a, (50, 100), (51, 56), (50, 8), 2.8, 2.0, sp["fill"])
    with a.on(LEAF):
        x, y = q.pt(0.3); lf_zinnia(a, x - 1, y, -24, 50, sp["fill"]); lf_zinnia(a, x + 1, y, -156, 50, sp["fill"])
        x, y = q.pt(0.74); lf_zinnia(a, x - 0.8, y, -50, 30, sp["fill"]); lf_zinnia(a, x + 0.8, y, -130, 30, sp["fill"])
    return a


def cl_rudbeckia(a, sp):
    lf_rudbeckia(a, *BASE, ANG, 98, sp["fill"]); return a


def cl_marigold(a, sp):
    lf_marigold(a, *BASE, ANG, 98, sp["fill"]); return a


def cl_oxeye(a, sp):
    stem_piece(a, (76, 100), (80, 76), (90, 50), 2.2, 1.8, sp["fill"])
    with a.on(LEAF):
        lf_oxeye(a, 16, 94, -55, 90, sp["fill"])
        lf_oxeye_stem(a, 80, 82, -38, 24, sp["fill"])
    return a


def cl_cornchamomile(a, sp):
    q = stem_piece(a, (34, 100), (40, 50), (62, 4), 2.2, 1.6, sp["fill"])
    with a.on(LEAF):
        for u, ang_, L in ((0.18, -22, 52), (0.5, -150, 48), (0.78, -36, 34)):
            x, y = q.pt(u); lf_cornchamomile(a, x, y, ang_, L, sp["fill"])
    return a


def cl_pineapple(a, sp):
    q = stem_piece(a, (34, 100), (40, 50), (62, 4), 2.2, 1.6, sp["fill"])
    with a.on(LEAF):
        for u, ang_, L in ((0.18, -22, 50), (0.5, -150, 46), (0.78, -36, 34)):
            x, y = q.pt(u); lf_pineapple(a, x, y, ang_, L, sp["fill"])
    return a


def cl_feverfew(a, sp):
    lf_feverfew(a, *BASE, ANG, 98, sp["fill"]); return a


def cl_aster(a, sp):
    q = stem_piece(a, (26, 100), (36, 50), (64, 4), 2.2, 1.4, "bark")
    with a.on(LEAF):
        for u, ang_, L in ((0.12, -22, 66), (0.4, -150, 50), (0.66, -30, 38), (0.88, -140, 24)):
            x, y = q.pt(u); lf_aster(a, x, y, ang_, L, sp["fill"])
    return a


def cl_african(a, sp):
    stem_piece(a, (6, 80), (16, 88), (30, 100), 3.4, 3.0, "bark")
    with a.on(LEAF):
        lf_african(a, 18, 90, ANG, 94, sp["fill"])
    return a


def cl_helipterum(a, sp):
    q = stem_piece(a, (40, 100), (44, 50), (60, 2), 1.7, 1.1, sp["fill"])
    with a.on(LEAF):
        for u, ang_, L in ((0.14, -16, 50), (0.36, -164, 48), (0.58, -22, 42), (0.8, -158, 30)):
            x, y = q.pt(u); lf_helipterum(a, x, y, ang_, L, sp["fill"])
    return a


def cl_cornflower(a, sp):
    q = stem_piece(a, (34, 100), (40, 50), (62, 2), 2.0, 1.3, sp["fill"], woolly=True)
    with a.on(LEAF):
        x, y = q.pt(0.06); lf_cornflower(a, x, y, -24, 66, sp["fill"], lobed=True)
        for u, ang_, L in ((0.4, -152, 50), (0.62, -28, 42), (0.84, -150, 28)):
            x, y = q.pt(u); lf_cornflower(a, x, y, ang_, L, sp["fill"])
    return a


def cl_globethistle(a, sp):
    with a.on(LEAF):
        lf_globethistle(a, 14, 90, -78, 62, sp["fill"], under=True)
        lf_globethistle(a, 22, 94, -46, 96, sp["fill"])
    return a


def cl_scabiosa(a, sp):
    q = stem_piece(a, (80, 100), (82, 70), (88, 38), 1.9, 1.5, sp["fill"])
    with a.on(LEAF):
        lf_scabiosa(a, 14, 94, -54, 86, sp["fill"])
        x, y = q.pt(0.42); lf_scabiosa(a, x, y, -60, 24, sp["fill"], fine=True); lf_scabiosa(a, x, y, -168, 20, sp["fill"], fine=True)
    return a


def cl_devilsbit(a, sp):
    lf_devilsbit(a, *BASE, ANG, 98, sp["fill"]); return a


def cl_rampion(a, sp):
    lf_rampion(a, *BASE, ANG, 98, sp["fill"]); return a


def cl_senecio(a, sp):
    lf_senecio(a, 22, 94, -48, 96, sp["fill"]); return a


LEAF_DRAW = {"daisies_" + k: fn for k, fn in {
    "sunflower": cl_sunflower, "calendula": cl_calendula, "cosmos": cl_cosmos, "zinnia": cl_zinnia,
    "rudbeckia": cl_rudbeckia, "marigold": cl_marigold, "oxeye": cl_oxeye, "cornchamomile": cl_cornchamomile,
    "pineapple": cl_pineapple, "feverfew": cl_feverfew, "aster": cl_aster, "african": cl_african,
    "helipterum": cl_helipterum, "cornflower": cl_cornflower, "globethistle": cl_globethistle,
    "scabiosa": cl_scabiosa, "devilsbit": cl_devilsbit, "rampion": cl_rampion, "senecio": cl_senecio}.items()}

_LK = {"sunflower": "sunflower", "calendula": "calendula", "cosmos": "cosmos", "zinnia": "zinnia", "rudbeckia": "rudbeckia",
       "french-marigold": "marigold", "ox-eye-daisy": "oxeye", "corn-chamomile": "cornchamomile", "wild-chamomile": "pineapple",
       "feverfew": "feverfew", "aster": "aster", "african-daisy": "african", "helipterum-rosum": "helipterum",
       "cornflower": "cornflower", "blue-globe-thistle": "globethistle", "scabiosa": "scabiosa",
       "devil-s-bit-scabious": "devilsbit", "oxford-rampion": "rampion", "senecio-angel-wings": "senecio"}
LEAFX = {k: dict(kind="daisies_" + v, fill=pal(k, "leaf", "leaf")) for k, v in _LK.items()}
