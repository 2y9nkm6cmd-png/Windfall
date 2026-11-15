"""Windfall plant drawings: a close-up of the leaf and of the flower of every kind.

Run:  python3 leaves_flowers.py OUT_FOLDER
Writes OUT_FOLDER/light and OUT_FOLDER/dark with plant-<kind>-leaf.svg and
plant-<kind>-bloom.svg, and review sheets. Uses the same kit, colours and
100 by 100 grid as the life-stage drawings (plant_kit.py), and reads each
kind's leaf and flower settings from the KINDS list in plants_all.py, so a
change to a plant's settings there changes its close-ups here too.

What each kind gets is decided in leaf_spec() and bloom_spec(). The LEAFX and
BLOOMX tables near the foot change single kinds: those are where a plant
is put right by hand.
"""
import json, math, os, sys
from plant_kit import Art, T, P, f
import plants_all as PA

GOLD = 2.39996


# ============================================================ shape helpers
def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


def tilt(cy, k):
    """Squashes the picture up and down about cy: a flat flower seen at a slant."""
    return lambda p: (p[0], cy + (p[1] - cy) * k)


# How wide a leaf or petal is along its length, as a share of its widest.
# u runs from 0 at the base to 1 at the tip.
PROF = {
    "ovate":    lambda u: math.sin(math.pi * u ** 0.72) ** 0.9,
    "elliptic": lambda u: math.sin(math.pi * u) ** 0.8,
    "lance":    lambda u: math.sin(math.pi * u ** 0.62) ** 1.1,
    "obovate":  lambda u: math.sin(math.pi * u ** 1.45) ** 0.72,
    "round":    lambda u: math.sin(math.pi * u ** 1.1) ** 0.5,
    "claw":     lambda u: (0.22 if u < 0.3 else 0.22 + 0.78 * math.sin(math.pi * 0.5 * min(1, (u - 0.3) / 0.35))) * math.sin(math.pi * min(1, u * 1.0 + 0.0001)) ** 0.25 if u < 0.98 else 0.3,
    "linear":   lambda u: min(1, u / 0.06) ** 0.5 * (1 if u < 0.72 else math.cos(math.pi * 0.5 * (u - 0.72) / 0.28) ** 0.8),
    "ray":      lambda u: min(1, u / 0.18) ** 0.6,
    "spoon":    lambda u: 0.2 + 0.8 * math.sin(math.pi * max(0, (u - 0.25) / 0.75) ** 0.9) ** 0.7 if u > 0.25 else 0.2 * min(1, u / 0.05),
}


# The nick in the edge across one tooth: s runs from 0 at the start of the
# tooth (nearer the stalk) to 1 at its end. 1 is the bottom of a nick, 0 the
# tip of a tooth.
NICK = {
    "saw":    lambda s: (1 - s) ** 1.6,                                   # sharp teeth pointing to the tip: apple, mint
    "double": lambda s: (1 - s) ** 1.3 + (0.36 * (1 - (s - 0.5) / 0.5) ** 1.3 if s >= 0.5 else 0),   # a big tooth with a small one on its back: raspberry, bramble
    "round":  lambda s: abs(math.cos(math.pi * s)) ** 2.4,                # rounded teeth: foxglove, lemon balm, cowslip
    "wave":   lambda s: 0.5 + 0.5 * math.cos(2 * math.pi * s),            # no teeth, only a wavy edge: bay
}


def blade_pts(L, W, prof="ovate", teeth=0, td=0.07, cut=0, cutn=0, tip=None, n=None, tk="saw", tmin=0):
    """The two edges of a leaf or petal laid along the x axis from 0 to L.
    teeth gives a toothed edge, cut and cutn deep lobes down each side
    (a radish or rocket leaf), tip='teeth' a flat end with three small teeth
    (a daisy's petal). tk is the kind of tooth (see NICK). tmin is the
    least a tooth may stand out, in grid squares: leaves pass it so that
    teeth still show at the size the app draws them, and then no tooth is
    shorter than about three squares either. Returns the upper edge, the
    lower edge and a function giving the half width at any point."""
    if teeth and tmin and tk != "wave":
        teeth = max(3, min(teeth, int(L / (4.4 if tk == "double" else 3.0))))
        td = max(td, min(tmin / max(W / 2, 0.01), 0.34))
    n = n or max(60, teeth * (16 if tk == "double" else 9), cutn * 22)
    pr = PROF[prof]; nick = NICK[tk]

    def hw(u, side=1):
        w = pr(u) * W / 2
        if cutn:
            c = cut * max(0.0, min(1.0, (0.8 - u) / 0.16))
            w *= 1 - c * (0.5 + 0.5 * math.cos(2 * math.pi * u * cutn)) ** 2.5
        if teeth:
            s = (u * teeth + (0 if side > 0 else 0.5)) % 1
            w *= 1 - td * nick(s) * math.sin(math.pi * u) ** 0.6
        return w

    end = 0.97 if tip == "teeth" else 1.0
    us = [end * i / n for i in range(n + 1)]
    top = [(L * u, hw(u, 1)) for u in us]
    bot = [(L * u, -hw(u, -1)) for u in us]
    if tip == "teeth":
        w = hw(end)
        top += [(L * 1.0, w * 0.62), (L * 0.965, w * 0.3), (L * 1.0, 0)]
        bot += [(L * 1.0, -w * 0.62), (L * 0.965, -w * 0.3)]
    return top, bot, hw


def blade(a, x, y, ang, L, W, fill, prof="ovate", teeth=0, td=0.07, cut=0, cutn=0, veins=6, lw=1.15,
          M=None, shade=0.1, midw=0.75, veinc="line", tip=None, net=False, petal=False, tk="saw", tmin=0):
    """A leaf (or a petal, with petal=True) drawn large, with its veins."""
    t = T(x, y, ang)
    mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    top, bot, hw = blade_pts(L, W, prof, teeth, td, cut, cutn, tip, tk=tk, tmin=tmin)
    a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), fill, lw)
    if shade:
        a.shape(path([mp(p) for p in top] + [mp((p[0], 0)) for p in top[::-1]]), "shade", 0, fa=shade)
    if petal:   # a few fine lines running out from the base
        for o in ([0] if W < L * 0.3 else [-0.45, 0, 0.45]):
            q = [mp((L * u, o * hw(u) * 0.8)) for u in (0.12, 0.4, 0.66)]
            a.line(f"M{P(q[0])} Q{P(q[1])} {P(q[2])}", 0.45, 0.28)
        return hw
    a.line(opath([mp((L * u, 0)) for u in (0.0, 0.3, 0.6, 0.92)]), midw, 0.55, veinc)
    if veins:
        if cutn:
            spots = [(k + 0.5) / cutn for k in range(cutn) if (k + 0.5) / cutn < 0.86]
        else:
            spots = [0.12 + 0.74 * (k + 0.5) / veins for k in range(veins)]
        for u1 in spots:
            u0 = max(0.03, u1 - (0.1 if cutn else 0.12))
            for sg in (1, -1):
                w1 = hw(min(0.99, u1), sg) * 0.84 * sg
                p0, c, p1 = mp((L * u0, 0)), mp((L * (u0 + 0.06), w1 * 0.5)), mp((L * u1, w1))
                a.line(f"M{P(p0)} Q{P(c)} {P(p1)}", 0.5, 0.36, veinc)
                if net and L > 30:   # a hint of the finer net between the side veins
                    m = mp((L * (u0 + 0.05), w1 * 0.55)); e = mp((L * (u1 + 0.04), w1 * 0.3))
                    a.line(f"M{P(m)} L{P(e)}", 0.35, 0.22, veinc)
    return hw


def curved_blade(a, p0, c, p1, W, fill, prof="linear", veins=(0.35, -0.35, 0.7, -0.7), lw=1.15, shade=0.11,
                 midw=0.6, teeth=0, td=0.05, n=60):
    """A long leaf that follows a curve: a strap or a sword."""
    from plant_kit import Quad
    q = Quad(p0, c, p1); pr = PROF[prof]
    L, R, mid = [], [], []
    for i in range(n + 1):
        u = i / n; x, y = q.pt(u); a_ = math.radians(q.ang(u) + 90)
        w = pr(u) * W / 2
        if teeth:
            w *= 1 - td * abs(math.sin(math.pi * u * teeth))
        nx, ny = math.cos(a_), math.sin(a_)
        L.append((x + w * nx, y + w * ny)); R.append((x - w * nx, y - w * ny)); mid.append((x, y, nx, ny, w))
    a.shape(path(L + R[::-1]), fill, lw)
    if shade:
        a.shape(path(L + [(m[0], m[1]) for m in mid[::-1]]), "shade", 0, fa=shade)
    for o in veins:
        a.line(opath([(m[0] + o * m[4] * m[2], m[1] + o * m[4] * m[3]) for m in mid[2:-3:3]]), 0.4, 0.3)
    if midw:
        a.line(opath([(m[0], m[1]) for m in mid[1:-4:3]]), midw, 0.45)
    return q


def polar_leaf(a, x, y, ang, R, g, fill, veins=(), lw=1.15, shade=0.1, n=200, veinc="line", M=None):
    """A broad leaf drawn round a centre, its stalk joining at x,y where the
    edge comes in to a notch. g(angle) is how far out the edge is, as a
    share of R, with angle 0 pointing to the tip. veins lists the angles of
    the main veins, which all start where the stalk joins."""
    d = R * g(math.pi)
    t = T(x, y, ang)
    mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    th = [-math.pi + 2 * math.pi * i / n for i in range(n + 1)]
    loc = [(d + R * g(h) * math.cos(h), R * g(h) * math.sin(h)) for h in th]
    a.shape(path([mp(p) for p in loc]), fill, lw)
    if shade:
        half = [p for h, p in zip(th, loc) if h >= 0]
        a.shape(path([mp(p) for p in half] + [mp((0, 0))]), "shade", 0, fa=shade)
    for v in veins:
        e = (d + R * g(v) * 0.86 * math.cos(v), R * g(v) * 0.86 * math.sin(v))
        m = (e[0] * 0.5 - e[1] * 0.06, e[1] * 0.5 + e[0] * 0.06)
        a.line(f"M{P(mp((0, 0)))} Q{P(mp(m))} {P(mp(e))}", 0.6 if v == 0 else 0.5, 0.45, veinc)
        L_ = math.hypot(*e)
        if L_ > 16:   # side veins off each main vein
            va = math.atan2(e[1], e[0])
            for u in (0.35, 0.6):
                b = (e[0] * u, e[1] * u)
                for sg in (1, -1):
                    sa = va + sg * 0.75; k = L_ * 0.22 * (1 - u * 0.4)
                    a.line(f"M{P(mp(b))} L{P(mp((b[0] + k * math.cos(sa), b[1] + k * math.sin(sa))))}", 0.38, 0.28, veinc)
    return d


def stalk(a, p0, c, p1, w0=2.6, w1=1.9, fill="leaf"):
    return a.ribbon(p0, c, p1, w0, w1, fill, lw=0.9)


def notch(depth, width=0.4):
    return lambda h: 1 - depth * math.exp(-((abs(h) - math.pi) / width) ** 2)


# ================================================================== leaves
TMIN = 1.4         # the least a leaf's tooth stands out, in grid squares, so that it shows (see blade_pts)
BASE = (20, 92)   # where the leaf stalk starts, bottom left
ANG = -52          # the leaf lies along this line, up to the top right


def leaf_blade(a, sp):
    """An ordinary leaf: stalk, then a blade with side veins."""
    pf = sp.get("petiole", 0.2); LT = sp.get("len", 98); L = LT * (1 - pf)
    t = T(*BASE, ANG); A = t(LT * pf)
    stalk(a, BASE, t(LT * pf * 0.5, 1.5), A, 3.4 if sp.get("stalkc") else 2.4, 2.6 if sp.get("stalkc") else 1.8, sp.get("stalkc", sp["fill"]))
    hw = blade(a, A[0], A[1], ANG, L, L * sp.get("W", 0.5), sp["fill"], sp.get("prof", "ovate"), sp.get("teeth", 0), sp.get("td", 0.07),
               sp.get("cut", 0), sp.get("cutn", 0), sp.get("veins", 7), midw=1.6 if sp.get("stalkc") else 0.9,
               veinc=sp.get("veinc", "line"), net=True, tk=sp.get("tk", "saw"), tmin=sp.get("tmin", TMIN))
    if sp.get("stalkc"):   # a thick midrib the colour of the stalk
        a.ribbon(A, t(LT * pf + L * 0.3, 0), t(LT * pf + L * 0.86), 2.6, 0.6, sp["stalkc"], lw=0.6)
    if sp.get("chevron"):
        _chevron(a, A, ANG, L * 0.55, L * sp.get("W", 0.5))
    if sp.get("spots"):   # lungwort's white blotches, St John's-wort's clear dots
        r = sp.get("spotr", 1.5)
        for j in range(16):
            u = 0.14 + 0.72 * ((j * 0.618) % 1); v = ((j * 0.37) % 1 - 0.5) * 1.3
            p = t(LT * pf + L * u, hw(u) * v)
            a.oval(p[0], p[1], r, r * 0.75, j * 40, sp["spots"], 0, la=0)
    return a


def _chevron(a, base, ang, at, W):
    t = T(*base, ang)
    a.line(f"M{P(t(at - W * 0.2, W * 0.3))} L{P(t(at, 0))} L{P(t(at - W * 0.2, -W * 0.3))}", 2.2, 0.5, "white")


def leaf_polar(a, sp):
    kind = sp["kind"]; R = sp.get("R", 31); fill = sp["fill"]
    pf = sp.get("petiole", 0.22); t = T(*BASE, ANG); A = t(98 * pf)
    stalk(a, BASE, t(98 * pf * 0.5, 2), A, 3.6 if sp.get("stalkc") else 2.6, 2.4 if sp.get("stalkc") else 1.8, sp.get("stalkc", fill))
    td = sp.get("td", 0); teeth = sp.get("teeth", 0)
    if teeth and td >= 0.045:   # a toothed edge, not just a wavy one: make sure the teeth show
        td = max(td, sp.get("tmin", TMIN + 0.2) / R)
    saw = (lambda h: 1 - td * (((h + math.pi) * teeth / (2 * math.pi)) % 1) ** 1.5) if teeth else (lambda h: 1)
    if kind == "round":
        g = lambda h: (1 + 0.05 * math.cos(h)) * notch(0.6, 0.38)(h) * saw(h)
        veins = [0, 0.9, -0.9, 1.9, -1.9]
    elif kind == "heart":
        pt = sp.get("point", 0.35)
        g = lambda h: (1 + 0.1 * math.cos(h)) * (1 + pt * math.exp(-(h / 0.36) ** 2)) * notch(0.78, 0.5)(h) * saw(h)
        veins = [0, 0.8, -0.8, 1.6, -1.6, 2.3, -2.3]
    elif kind == "hastate":
        return leaf_hastate(a, sp, A)
    else:  # lobed
        lobes = sp.get("lobes", 5); cut = sp.get("cut", 0.36); sharp = sp.get("sharp", 0.7)
        g = lambda h: ((1 - cut) + cut * abs(math.cos(lobes * h / 2)) ** sharp) * notch(0.55, 0.3)(h) * saw(h)
        veins = [2 * math.pi * k / lobes for k in range(-(lobes // 2), lobes // 2 + 1)]
    polar_leaf(a, A[0], A[1], ANG, R, g, fill, veins, veinc=sp.get("veinc", "line"))
    if sp.get("marbled"):   # cyclamen: a pale band inside the edge
        h2 = lambda h: g(h) * 0.62
        d = R * g(math.pi); t2 = T(*A, ANG)
        pts = [t2(d + R * h2(h) * math.cos(h), R * h2(h) * math.sin(h)) for h in [-math.pi * 0.85 + 1.7 * math.pi * i / 80 for i in range(81)]]
        a.line(opath(pts), 3.2, 0.55, "white")
    if sp.get("flecks"):   # courgette: silver flecks along the main veins
        d = R * g(math.pi); t2 = T(*A, ANG)
        for v in veins:
            for u in (0.3, 0.5, 0.68):
                p = t2(d * 0 + (d + R * g(v) * math.cos(v)) * u, R * g(v) * math.sin(v) * u)
                a.oval(p[0], p[1], 1.2, 0.7, math.degrees(v) + ANG, "sage", 0, la=0)
    return a


def leaf_hastate(a, sp, A):
    """An arrow-shaped leaf with two ears at the base: sorrel, orache,
    Good King Henry. ear is how far back the ears point."""
    L = 62; W = sp.get("W", 0.62) * L; ear = sp.get("ear", 0.16); t = T(*A, ANG)
    up = [(L, 0), (L * 0.62, W * 0.2), (L * 0.32, W * 0.42), (L * 0.1, W * 0.5), (-L * ear, W * 0.56), (-L * ear * 0.3, W * 0.34), (L * 0.02, W * 0.1), (0, 0)]
    pts = []
    for i in range(len(up) - 1):   # smooth the corners a little
        p0, p1 = up[i], up[i + 1]
        for k in range(6):
            u = k / 6; pts.append((p0[0] + (p1[0] - p0[0]) * u, p0[1] + (p1[1] - p0[1]) * u))
    sm = [pts[0]] + [((pts[i - 1][0] + 2 * pts[i][0] + pts[i + 1][0]) / 4, (pts[i - 1][1] + 2 * pts[i][1] + pts[i + 1][1]) / 4) for i in range(1, len(pts) - 1)] + [pts[-1]]
    full = sm + [(x, -y) for x, y in sm[::-1]]
    a.shape(path([t(*p) for p in full]), sp["fill"])
    a.shape(path([t(*p) for p in sm] + [t(L * 0.5, 0)]), "shade", 0, fa=0.1)
    a.line(f"M{P(t(0, 0))} L{P(t(L * 0.92, 0))}", 0.9, 0.55, sp.get("veinc", "line"))
    for u, w in ((0.25, 0.42), (0.45, 0.32), (0.65, 0.2)):
        for sg in (1, -1):
            a.line(f"M{P(t(L * u * 0.7, 0))} Q{P(t(L * u, sg * W * w * 0.6))} {P(t(L * (u + 0.1), sg * W * w))}", 0.5, 0.36)
    for sg in (1, -1):
        a.line(f"M{P(t(0, 0))} Q{P(t(-L * ear * 0.2, sg * W * 0.3))} {P(t(-L * ear * 0.8, sg * W * 0.5))}", 0.5, 0.36)
    return a


def leaf_peltate(a, sp):
    """A round leaf with the stalk joined at its middle: nasturtium."""
    c = (54, 44); R = 30
    stalk(a, (22, 96), (30, 70), (c[0] - 4, c[1] + 6), 2.4, 1.8, sp["fill"])
    a.polar(c[0], c[1], lambda h: 1 + 0.035 * math.cos(5 * h + 0.5), R, R * 0.9, -12, sp["fill"])
    hub = (c[0] - 3, c[1] + 3)
    for k in range(9):
        ang = k * 40 + 10; e = T(*c, ang)((R - 2) * (0.92 if 30 < ang % 360 < 150 else 0.97))
        e = (e[0], c[1] + (e[1] - c[1]) * 0.9)
        m = ((hub[0] + e[0]) / 2 + 1, (hub[1] + e[1]) / 2 - 1)
        a.line(f"M{P(hub)} Q{P(m)} {P(e)}", 0.6, 0.45)
    a.dot(hub[0], hub[1], 1.1, "pale")
    return a


def leaf_fan(a, sp):
    """A ginkgo leaf: a fan with a notch in its outer edge and fine veins
    that fork as they spread."""
    A = (34, 72)
    stalk(a, (14, 96), (22, 86), A, 2.0, 1.6, sp["fill"])
    pts = [A]
    for i in range(61):
        ph = math.radians(-62 + 124 * i / 60); r = 54 * (1 + 0.035 * math.sin(9 * ph)) * (1 - 0.22 * math.exp(-(ph / 0.08) ** 2))
        pts.append(T(*A, ANG + 4)(r * math.cos(ph), r * math.sin(ph)))
    a.shape(path(pts), sp["fill"])
    a.shape(path([A] + pts[31:]), "shade", 0, fa=0.1)
    for k in range(17):
        ph = math.radians(-56 + 112 * k / 16); r = 50 * (1 - 0.22 * math.exp(-(ph / 0.08) ** 2))
        e = T(*A, ANG + 4)(r * math.cos(ph), r * math.sin(ph)); m = T(*A, ANG + 4)(r * 0.45 * math.cos(ph * 0.7), r * 0.45 * math.sin(ph * 0.7))
        a.line(f"M{P(A)} Q{P(m)} {P(e)}", 0.4, 0.3)
    return a


def leaf_pinnate(a, sp):
    """A leaf of several leaflets on one stalk: rose, tomato, pea."""
    from plant_kit import Quad
    pairs = sp.get("pairs", 3); t = T(*BASE, ANG); LT = 98
    ll, lw_ = sp.get("ll", 25), sp.get("lW", 0.5)
    tl = ll * sp.get("termk", 1.12)   # termk: how big the end leaflet is beside the others
    end = 0.8 if sp.get("tendril") else 0.78
    if "termk" in sp and sp.get("terminal", True):
        end = min(end, (LT + 8 - tl) / LT)   # a big end leaflet: a shorter stalk, so that it stays in the picture
    q = Quad(BASE, t(LT * 0.5 * end / (0.8 if sp.get("tendril") else 0.78), -3), t(LT * end))
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.2, sp["fill"], lw=0.8)
    if sp.get("stipule"):   # pea: two large leafy ears where the stalk joins
        x, y = q.pt(0.1)
        for sg in (1, -1):
            blade(a, x, y, ANG + sg * 70, 15, 11, sp["fill"], "ovate", veins=2)
    if sp.get("ears"):   # rose: two narrow ears joined to the foot of the stalk
        x, y = q.pt(0.03)
        for sg in (1, -1):
            blade(a, x, y, q.ang(0.03) + sg * 16, 13, 3.4, sp["fill"], "lance", veins=0, lw=0.8)
    tk = sp.get("tk", "saw"); tmin = sp.get("tmin", TMIN)
    order = []
    for i in range(pairs):
        u = 0.28 + (0.62 if sp.get("tendril") else 0.6) * i / max(1, pairs - 1)
        if pairs == 1 and not sp.get("tendril"):
            u = 0.74   # a leaf of three: the side pair sits just under the end leaflet
        order.append(u)
    for i, u in enumerate(order):
        x, y = q.pt(u); ang = q.ang(u); s = 1 - 0.18 * i / max(1, pairs - 1) if not sp.get("grow") else 0.82 + 0.18 * i / max(1, pairs - 1)
        for sg in (1, -1):
            blade(a, x, y, ang + sg * sp.get("spread", 58), ll * s, ll * s * lw_, sp["fill"], sp.get("prof", "ovate"),
                  sp.get("teeth", 0), sp.get("td", 0.08), sp.get("cut", 0), sp.get("cutn", 0), veins=4, lw=1.0, tk=tk, tmin=tmin)
        if sp.get("small") and i < pairs - 1:   # tomato: small leaflets between the big ones
            x2, y2 = q.pt(u + 0.1)
            for sg in (1, -1):
                blade(a, x2, y2, ang + sg * 62, ll * 0.32, ll * 0.18, sp["fill"], "ovate", veins=0, lw=0.8)
    ex, ey = q.pt(1)
    if sp.get("tendril"):
        for off, curl in ((-22, 1), (0, -1), (24, 1)):
            e = T(ex, ey, q.ang(1) + off)(12)
            a.line(f"M{f(ex)},{f(ey)} Q{P(T(ex, ey, q.ang(1) + off)(7))} {P(e)} q{f(curl * 3)},-3 {f(curl * 1)},-5 q{f(-curl * 2)},0 {f(-curl * 1.5)},2", 0.8, 0.8)
    elif sp.get("terminal", True):
        blade(a, ex, ey, q.ang(1), tl, tl * sp.get("termW", lw_), sp["fill"], sp.get("termprof", sp.get("prof", "ovate")), max(sp.get("teeth", 0), int(sp.get("teeth", 0) * sp.get("termk", 1.12))), sp.get("td", 0.08),
              sp.get("cut", 0), sp.get("cutn", 0), veins=5 if tl > 30 else 4, lw=1.0, tk=tk, tmin=tmin)
    return a


def leaf_trefoil(a, sp):
    """Three leaflets from the top of one stalk: clover, strawberry, bean."""
    t = T(*BASE, ANG); A = t(40)
    stalk(a, BASE, t(20, 2), A, 2.4, 1.8, sp["fill"])
    L = sp.get("ll", 38)
    if sp.get("basal"):   # bird's-foot trefoil: two more leaflets down at the foot of the stalk
        for sg in (1, -1):
            blade(a, *t(5), ANG + sg * 62, L * 0.6, L * 0.6 * sp.get("lW", 0.62), sp["fill"], sp.get("prof", "obovate"), veins=3, lw=1.0)
    for off in (-66, 66, 0):
        if sp.get("obcord"):   # wood sorrel: each leaflet a heart, point inwards
            g = lambda h: (1 - 0.7 * math.exp(-(h / 0.3) ** 2)) * (1 - 0.86 * math.exp(-((abs(h) - math.pi) / 0.9) ** 2)) * (1 + 0.15 * abs(math.sin(h)))
            polar_leaf(a, A[0], A[1], ANG + off, L * 0.5, g, sp["fill"], (0,))
        else:
            hw = blade(a, A[0], A[1], ANG + off, L * (1 if off == 0 else 0.9), L * sp.get("lW", 0.62), sp["fill"], sp.get("prof", "obovate"),
                       sp.get("teeth", 0), sp.get("td", 0.07), cut=sp.get("cut", 0), cutn=sp.get("cutn", 0),
                       veins=sp.get("veins", 6), tk=sp.get("tk", "saw"), tmin=sp.get("tmin", TMIN))
            if sp.get("chevron"):
                _chevron(a, (A[0], A[1]), ANG + off, L * 0.52, L * 0.5)
    return a


def leaf_palmate(a, sp):
    """Leaflets spreading like fingers from the top of the stalk: lupin."""
    t = T(*BASE, ANG); A = t(44)
    stalk(a, BASE, t(22, 2), A, 2.4, 1.8, sp["fill"])
    n = sp.get("n", 9); spread = sp.get("spread", 128)
    for k in sorted(range(n), key=lambda k: -abs(k - (n - 1) / 2)):
        off = -spread + 2 * spread * k / (n - 1); L = sp.get("ll", 40) * (1 - 0.42 * (abs(off) / 128) ** 1.5)
        blade(a, A[0], A[1], ANG + off, L, L * sp.get("lW", 0.24), sp["fill"], sp.get("prof", "lance"), sp.get("teeth", 0), sp.get("td", 0.08),
              veins=4 if sp.get("lW", 0.24) > 0.3 else 0, lw=1.0, tk=sp.get("tk", "saw"), tmin=sp.get("tmin", TMIN))
    a.oval(A[0], A[1], 1.8, 1.8, 0, sp["fill"], 0.8)
    return a


def leaf_fern(a, sp):
    """A leaf cut twice over into small segments: carrot, dill, cosmos."""
    from plant_kit import Quad
    t = T(*BASE, ANG); q = Quad(BASE, t(50, -4), t(96))
    a.ribbon(q.p0, q.c, q.p1, 2.0, 0.8, sp["fill"], lw=0.8)
    thread = sp.get("thread"); n = sp.get("pinnae", 6)
    narrow = sp.get("narrow")   # short flat narrow segments with no teeth: Californian poppy, corn chamomile
    for i in range(n):
        u = 0.22 + 0.7 * i / (n - 1); x, y = q.pt(u); ang = q.ang(u); L = 30 * (1.05 - 0.75 * u)
        for sg in (1, -1):
            pa = ang + sg * 52; tq = T(x, y, pa)
            a.line(f"M{f(x)},{f(y)} Q{P(tq(L * 0.5, -sg * 1.5))} {P(tq(L))}", 0.7, 0.75)
            for j in range(4):
                v = 0.25 + 0.2 * j; px, py = tq(L * v, -sg * 1.5 * 4 * v * (1 - v)); l = L * 0.42 * (1.1 - v * 0.6)
                for sg2 in (1, -1):
                    if thread:
                        blade(a, px, py, pa + sg2 * 38, l * 1.1, 1.3, sp["fill"], "linear", veins=0, lw=0.5, shade=0)
                    elif narrow:
                        blade(a, px, py, pa + sg2 * 40, l * 1.05, 2.3, sp["fill"], "linear", veins=0, lw=0.55, shade=0)
                    else:
                        blade(a, px, py, pa + sg2 * 44, l, l * 0.42, sp["fill"], "lance", teeth=sp.get("teeth", 0), td=0.18, veins=0, lw=0.6, shade=0.08)
            e = tq(L)
            blade(a, e[0], e[1], pa, L * 0.3, 1.3 if thread else (2.3 if narrow else L * 0.12), sp["fill"], "linear" if thread or narrow else "lance", veins=0, lw=0.6, shade=0)
    e = q.pt(1)
    blade(a, e[0], e[1], q.ang(1), 9, 1.3 if thread else (2.3 if narrow else 3.6), sp["fill"], "linear" if thread or narrow else "lance", veins=0, lw=0.6, shade=0)
    return a


def leaf_strap(a, sp):
    """Long leaves with parallel veins: leek, onion, tulip, iris."""
    W = sp.get("W", 10); fill = sp["fill"]
    if sp.get("two", True):
        curved_blade(a, (42, 98), (28, 62), (10, 34), W * 0.8, fill, sp.get("prof", "linear"), veins=(0.4, -0.4), midw=0)
    curved_blade(a, (40, 98), (44, 42), (86, 12), W, fill, sp.get("prof", "linear"), midw=sp.get("midw", 0.6),
                 teeth=sp.get("wavy", 0), td=0.06)
    if sp.get("stripe"):   # crocus: a white line down the middle
        a.ribbon((40, 96), (44, 42), (84, 14), 1.4, 0.4, "white", lw=0)
    if sp.get("sheath"):   # a pale sheath where the leaves wrap round each other
        a.ribbon((40, 99), (40.5, 92), (41, 84), W * 1.15, W * 1.0, "pale", lw=0.9)
    return a


def leaf_needles(a, sp):
    """A sprig: a woody shoot crowded with narrow leaves. Rosemary, lavender."""
    from plant_kit import Quad
    q = Quad((26, 96), (40, 52), (76, 12))
    a.ribbon(q.p0, q.c, q.p1, 2.6, 1.2, sp.get("stemc", "bark"), lw=0.8)
    n = sp.get("n", 13); L0 = sp.get("nl", 17); W = sp.get("nw", 0.16)
    for i in range(n):
        u = 0.08 + 0.9 * i / (n - 1); x, y = q.pt(u); ang = q.ang(u); L = L0 * (1.05 - 0.55 * u)
        for sg in (1, -1):
            if sp.get("alt") and (i % 2) == (sg > 0):
                continue
            blade(a, x, y, ang + sg * sp.get("spread", 40), L, L * W, sp["fill"], sp.get("prof", "linear"), veins=0, lw=0.8, midw=0.5)
    return a


def leaf_whorls(a, sp):
    """Narrow leaves in rings round a thin stem: lady's bedstraw."""
    a.ribbon((48, 98), (49, 55), (52, 6), 1.6, 1.0, "leaf", lw=0.7)
    for y, s in ((80, 1), (52, 0.85), (27, 0.7)):
        M = tilt(y, 0.42)
        for k in sorted(range(8), key=lambda k: math.sin(k * 2 * math.pi / 8)):
            ang = k * 45 + 10
            blade(a, 50, y, ang, 22 * s, 2.6 * s, sp["fill"], "linear", veins=0, lw=0.7, M=M, shade=0.08)
    a.oval(53, 12, 2.0, 1.6, 0, "leaf", 0.6)
    return a


def leaf_pair(a, sp):
    """Two leaflets and a tendril on one stalk: meadow vetchling, sweet pea."""
    t = T(*BASE, ANG); A = t(46)
    stalk(a, BASE, t(23, 2), A, 2.4, 1.6, sp["fill"])
    for sg in (1, -1):
        blade(a, A[0], A[1], ANG + sg * 34, 44, 44 * 0.26, sp["fill"], "lance", veins=0)
        blade(a, *t(5), ANG + sg * 75, 9, 3.4, sp["fill"], "lance", veins=0, lw=0.7)   # stipules: two small ears
    e = t(66)
    a.line(f"M{P(A)} L{P(e)} q3,-4 1,-7 q-3,-1 -3,2", 0.8, 0.8)
    return a


def leaf_sprig(a, sp):
    """A shoot of small leaves in pairs: thyme, oregano."""
    from plant_kit import Quad
    q = Quad((30, 96), (40, 52), (70, 12))
    a.ribbon(q.p0, q.c, q.p1, 1.8, 1.0, sp.get("stemc", "bark"), lw=0.7)
    for i in range(7):
        u = 0.12 + 0.82 * i / 6; x, y = q.pt(u); ang = q.ang(u); L = sp.get("nl", 15) * (1.05 - 0.5 * u)
        for sg in (1, -1):
            blade(a, x, y, ang + sg * 58, L, L * sp.get("nw", 0.5), sp["fill"], sp.get("prof", "elliptic"), veins=2, lw=0.8)
    return a


LEAF_DRAW = {"blade": leaf_blade, "round": leaf_polar, "heart": leaf_polar, "lobed": leaf_polar, "hastate": leaf_polar,
             "peltate": leaf_peltate, "fan": leaf_fan, "pinnate": leaf_pinnate, "trefoil": leaf_trefoil,
             "palmate": leaf_palmate, "fern": leaf_fern, "strap": leaf_strap, "needles": leaf_needles,
             "whorls": leaf_whorls, "pair": leaf_pair, "sprig": leaf_sprig}


# ================================================================= flowers
CX, CY = 50, 44


def bloom_stem(a, top, fill="leaf", base=(56, 98), w=2.8):
    return stalk(a, base, ((base[0] + top[0]) / 2 + 2, (base[1] + top[1]) / 2 + 4), top, w, w * 0.78, fill)


def stamens(a, cx, cy, r0, r1, n, anth="sun", M=None, lw=0.45):
    for k in range(n):
        ang = k * 360 / n + 9 * (k % 2)
        rr = r1 * (0.8 + 0.2 * (k % 3) / 2)
        p0 = T(cx, cy, ang)(r0); p1 = T(cx, cy, ang)(rr)
        if M:
            p0, p1 = M(p0), M(p1)
        a.line(f"M{P(p0)} L{P(p1)}", lw, 0.6)
        a.oval(p1[0], p1[1], 0.95, 0.7, ang, anth, 0.4)


def ring_of_petals(a, n, R, W, fill, prof="obovate", cx=CX, cy=CY, k=0.86, start=-90, teeth=0, td=0.05, tip=None, lw=0.9, jitter=0):
    M = tilt(cy, k)
    order = sorted(range(n), key=lambda i: math.sin(math.radians(start + 360 * i / n)))
    for i in order:
        ang = start + 360 * i / n + (jitter * ((i * 37) % 7 - 3))
        blade(a, cx, cy, ang, R, W, fill, prof, teeth, td, M=M, lw=lw, petal=True, tip=tip,
              shade=0.06 + (0.05 if math.sin(math.radians(ang)) > 0.3 else 0))
    return M


def bud(a, x, y, ang, L, fill, sepal="leaf"):
    blade(a, x, y, ang, L, L * 0.56, fill, "ovate", veins=0, petal=True, lw=0.9)
    for off in (-14, 14):
        blade(a, x, y, ang + off, L * 0.62, L * 0.2, sepal, "lance", veins=0, petal=True, lw=0.7)


def fl_daisy(a, sp):
    R = sp.get("R", 33); disc = sp.get("disc", 0.3); n = sp.get("rays", 18); cen = sp.get("cen", "sun"); k = 0.86
    if sp.get("rayless"):   # pineappleweed: a greenish-yellow dome of disc florets and no rays at all
        for top, base, s_ in (((50, 40), (52, 98), 1.0), ((76, 62), (60, 96), 0.62)):
            stalk(a, base, ((base[0] + top[0]) / 2 + 3, (base[1] + top[1]) / 2 + 6), (top[0], top[1] + 14 * s_), 2.4 * s_, 2.0 * s_)
            for i in range(9):   # the bracts cupping the foot of the dome
                blade(a, top[0] + (i - 4) * 2.6 * s_, top[1] + 15 * s_, -90 + (i - 4) * 9, 9 * s_, 3.6 * s_, "leaf", "ovate", veins=0, petal=True, lw=0.6)
            a.polar(top[0], top[1], lambda h: 1 - 0.1 * math.sin(h), 13 * s_, 17 * s_, 0, "pear", 0.9)
            m = int(70 * s_)
            for j in range(m):
                rr = 0.9 * math.sqrt((j + 0.5) / m); th = j * GOLD
                a.dot(top[0] + 12 * s_ * rr * math.cos(th), top[1] + 1 + 15 * s_ * rr * math.sin(th), 0.5 * s_ + 0.15, "unripe")
        return a
    bloom_stem(a, (CX + 2, CY + R * disc * k))
    if sp.get("budside"):
        stalk(a, (58, 96), (70, 86), (78, 70), 2.0, 1.6); bud(a, 78, 70, -78, 9, "leaf")
    M = tilt(CY, k)
    for i in range(14):   # the green bracts behind the petals
        blade(a, CX, CY, i * 360 / 14 + 12, R * (disc + 0.22), R * 0.12, "leaf", "lance", veins=0, M=M, lw=0.7, petal=True)
    rows = sp.get("rows", 1)
    for r in range(rows):
        ring_of_petals(a, n, R * (1 - 0.16 * r), R * sp.get("rw", 0.2), sp["fc"], sp.get("rprof", "ray"), start=-90 + r * 360 / n / 2,
                       tip=None if sp.get("plain") else "teeth", k=k, lw=0.75)
    dc = sp["fc"] if sp.get("lig") else cen
    rd = R * disc * (0.6 if sp.get("lig") else 1)
    a.oval(CX, CY, rd, rd * k, 0, dc, 0.9)
    if sp.get("lig"):   # chicory family: no disc, only small inner petals
        ring_of_petals(a, 12, R * 0.38, R * 0.12, sp["fc"], "ray", tip="teeth", k=k, lw=0.6)
        for kk in range(8):
            e = M(T(CX, CY, kk * 45)(R * 0.12)); a.line(f"M{f(CX)},{f(CY)} L{P(e)}", 0.6, 0.6)
        return a
    dot = {"dark": "amber", "sun": "rust", "amber": "rust", "rust": "amber", "primrose": "amber", "plum": "pink", "white": "sun"}.get(dc, "amber")
    m = int(10 + rd * rd * 0.9)
    for j in range(m):
        rr = rd * 0.92 * math.sqrt((j + 0.5) / m); th = j * GOLD
        x, y = CX + rr * math.cos(th), CY + rr * math.sin(th) * k
        if rr > rd * 0.7:   # the outer ring of disc florets is open: tiny stars
            a.flower(x, y, max(0.9, rd * 0.1), 5, dc, None, 0.6, lw=0.35)
        else:
            a.dot(x, y, max(0.35, rd * 0.045), dot)
    return a


def fl_flat(a, sp):
    n = sp.get("n", 5); R = sp.get("R", 30); k = sp.get("k", 0.88); cen = sp.get("cen", "sun")
    bloom_stem(a, (CX + 3, CY + 6))
    if sp.get("bud", True):
        stalk(a, (62, 97), (70, 84), (80, 72), 2.0, 1.5); bud(a, 80, 72, -64, 11, sp.get("budc", sp["fc"]))
    M = tilt(CY, k)
    PR = R * sp.get("pl", 1)   # pl: the petals' length as a share of the usual (raspberry: small petals, long sepals)
    if sp.get("sepals", True):
        for i in range(n):
            blade(a, CX, CY, -90 + 360 * (i + 0.5) / n, R * sp.get("sepl", 0.62), R * sp.get("sepw", 0.2), sp.get("sepc", "leaf"), "lance", veins=0, M=M, lw=0.7, petal=True)
    ring_of_petals(a, n, PR, PR * sp.get("pw", 0.92), sp["fc"], sp.get("prof", "round"), k=k, teeth=sp.get("teeth", 0), td=0.04,
                   start=sp.get("start", -90))
    if sp.get("edge"):   # candy cane sorrel: a red line round each petal
        for i in range(n):
            ang = -90 + 360 * i / n; t = T(CX, CY, ang)
            pts = [M(t(R * u, R * 0.4 * PROF["round"](u) * 0.94)) for u in (0.45, 0.65, 0.82, 0.95)]
            a.line(opath(pts), 1.0, 0.85, sp["edge"])
    if sp.get("tinge"):   # apple blossom: pink on the backs, seen at the edges
        for i in range(n):
            ang = -90 + 360 * i / n; t = T(CX, CY, ang)
            a.line(opath([M(t(R * u, -R * 0.44 * PROF["round"](u))) for u in (0.5, 0.7, 0.88)]), 1.2, 0.55, sp["tinge"])
    if sp.get("blotch"):
        for i in range(n):
            e = M(T(CX, CY, -90 + 360 * i / n)(R * 0.3)); a.oval(e[0], e[1], R * 0.1, R * 0.07, -90 + 360 * i / n, sp["blotch"], 0)
    r0 = R * 0.16
    if sp.get("receptacle"):   # strawberry: a raised green-yellow middle covered in tiny dots
        a.oval(CX, CY, R * 0.24, R * 0.22 * k, 0, cen, 0.8)
        for j in range(24):
            rr = R * 0.2 * math.sqrt((j + 0.5) / 24); a.dot(CX + rr * math.cos(j * GOLD), CY + rr * math.sin(j * GOLD) * k, 0.35, "unripe")
        stamens(a, CX, CY, R * 0.24, R * 0.36, 20, sp.get("anth", "sun"), M)
    else:
        stamens(a, CX, CY, r0 * 0.4, R * 0.34, sp.get("ns", 16), sp.get("anth", "sun"), M)
        a.oval(CX, CY, r0 * 0.7, r0 * 0.6, 0, cen, 0.8)
    return a


def fl_four(a, sp):
    R = sp.get("R", 29); k = 0.88
    bloom_stem(a, (CX + 2, CY + 5))
    stalk(a, (60, 98), (70, 82), (78, 66), 1.9, 1.4); bud(a, 78, 66, -70, 9, "leaf")
    M = tilt(CY, k)
    for i in range(4):
        blade(a, CX, CY, -45 + 90 * i + 45, R * 0.5, R * 0.16, "leaf", "lance", veins=0, M=M, lw=0.7, petal=True)
    ring_of_petals(a, 4, R, R * sp.get("pw", 0.62), sp["fc"], "claw", start=-45, k=k)
    if sp.get("veins"):   # rocket: dark veins on cream petals
        for i in range(4):
            t = T(CX, CY, -45 + 90 * i)
            for o in (-0.22, 0, 0.22):
                a.line(opath([M(t(R * u, o * R * 0.62 * u)) for u in (0.34, 0.6, 0.9)]), 0.5, 0.8, sp["veins"])
    stamens(a, CX, CY, 1, R * 0.3, 6, "sun", M)
    a.oval(CX, CY - 1.5, 1.4, 3.2, 0, "unripe", 0.7)
    return a


def fl_six(a, sp):
    R = sp.get("R", 31); k = 0.86
    bloom_stem(a, (CX + 3, CY + 5))
    M = ring_of_petals(a, 6, R, R * 0.4, sp["fc"], "elliptic", start=-90, k=k)
    if sp.get("stripe"):   # a dark line down each petal
        for i in range(6):
            t = T(CX, CY, -90 + 60 * i); a.line(opath([M(t(R * u)) for u in (0.12, 0.5, 0.86)]), 1.1, 0.85, sp["stripe"])
    stamens(a, CX, CY, 1.5, R * 0.42, 6, sp.get("anth", "sun"), tilt(CY, k), lw=0.6)
    a.oval(CX, CY, 2.0, 1.7, 0, sp.get("cen", "unripe"), 0.7)
    return a


def fl_star(a, sp):
    """Five narrow pointed petals round a cone of anthers: tomato, potato, borage."""
    R = sp.get("R", 31); k = 0.88; cen = sp.get("cen", "sun"); M = tilt(CY, k)
    bloom_stem(a, (CX + 2, CY + 4), w=2.2)
    stalk(a, (60, 98), (64, 80), (76, 68), 1.8, 1.4); bud(a, 76, 68, -60, 10, "leaf")
    for i in range(5):   # the green calyx, its points showing between the petals
        blade(a, CX, CY, -90 + 72 * (i + 0.5), R * 0.55, R * 0.12, "leaf", "lance", veins=0, M=M, lw=0.7, petal=True)
    ring_of_petals(a, 5, R, R * sp.get("pw", 0.36), sp["fc"], "lance", k=k)
    if sp.get("scales"):   # borage: a white ring at the base of the cone
        for i in range(5):
            e = M(T(CX, CY, -90 + 72 * i + 36)(R * 0.16)); a.oval(e[0], e[1], 1.6, 1.1, 0, "white", 0.5)
    for i in range(5):   # the anthers, standing together in a cone
        blade(a, CX, CY, -90 + 72 * i, R * 0.3, R * 0.13, cen, "ovate", veins=0, M=M, lw=0.7, petal=True)
    a.dot(CX, CY, 0.8, "unripe")
    return a


def fl_cup(a, sp):
    """A cup of broad petals seen from the side: poppy, tulip, crocus."""
    kind = sp.get("cup", "poppy"); fc = sp["fc"]
    base = (50, 70) if kind != "crocus" else (50, 74)
    if kind == "crocus":
        a.ribbon((50, 98), (50, 86), base, 3.2, 3.0, "white", lw=0.9)
    else:
        bloom_stem(a, base, base=(52, 98))
    if kind == "poppy" and sp.get("bud", True):
        a.line("M60,98 Q74,82 74,68", 1.2, 0.85); bud(a, 74, 70, 100, 10, "leaf", "leaf")
    if kind == "tulip":
        back = [(-112, 46, 0.5), (-68, 46, 0.5), (-90, 47, 0.46)]; front = [(-124, 42, 0.48), (-56, 42, 0.48), (-90, 43, 0.44)]
        prof = "elliptic"
    elif kind == "crocus":
        back = [(-108, 38, 0.42), (-72, 38, 0.42), (-90, 40, 0.4)]; front = [(-118, 36, 0.4), (-62, 36, 0.4), (-90, 37, 0.38)]
        prof = "elliptic"
    elif kind == "eschscholzia":
        back = [(-122, 36, 0.86), (-58, 36, 0.86)]; front = [(-150, 30, 0.8), (-30, 30, 0.8)]; prof = "round"
    else:
        back = [(-124, 38, 0.95), (-56, 38, 0.95)]; front = [(-162, 30, 0.9), (-18, 30, 0.9)]; prof = "round"
    for ang, L, w in back:
        blade(a, base[0], base[1], ang, L, L * w, fc, prof, teeth=9 if kind == "poppy" else 0, td=0.04, veins=0, petal=True,
              shade=0.14)
    # what is inside the cup
    ic = (base[0], base[1] - (26 if kind == "tulip" else 22 if kind != "crocus" else 24))
    if kind in ("poppy", "eschscholzia"):
        if sp.get("blotch"):
            for ang in (-118, -62):
                e = T(*base, ang)(8); a.oval(e[0], e[1], 4.4, 3.2, ang, sp["blotch"], 0)
        for j in range(22):
            ang = -175 + 170 * j / 21; e = T(ic[0], ic[1] + 6, ang)(10 + 2 * (j % 2))
            a.line(f"M{f(ic[0])},{f(ic[1] + 8)} L{P(e)}", 0.45, 0.6); a.dot(e[0], e[1], 0.8, sp.get("cen", "dark"))
        if kind == "poppy":
            a.oval(ic[0], ic[1] + 3, 5.4, 6.6, 0, "unripe", 0.9)
            a.oval(ic[0], ic[1] - 3.4, 5.6, 1.8, 0, "dark", 0.7)
            for j in range(8):
                e = T(ic[0], ic[1] - 3.4, j * 45)(5.2); a.line(f"M{f(ic[0])},{f(ic[1] - 3.4)} L{f(e[0])},{f(ic[1] - 3.4 + (e[1] - ic[1] + 3.4) * 0.32)}", 0.5, 0.6, "straw")
        else:
            a.ribbon((ic[0], ic[1] + 10), (ic[0], ic[1]), (ic[0] + 1, ic[1] - 6), 2.2, 1.6, "unripe", lw=0.7)
    elif kind == "tulip":
        for dx in (-6, -2, 2, 6):
            a.line(f"M{f(ic[0] + dx * 0.4)},{f(ic[1] + 14)} L{f(ic[0] + dx)},{f(ic[1] + 2)}", 0.6, 0.7)
            a.oval(ic[0] + dx, ic[1] + 1, 1.0, 2.6, dx * 3, "dark", 0.5)
        a.oval(ic[0], ic[1] + 6, 2.2, 5, 0, "unripe", 0.7)
    else:   # crocus: three orange stigmas
        for dx in (-3, 0, 3):
            a.line(f"M{f(ic[0])},{f(ic[1] + 10)} Q{f(ic[0] + dx)},{f(ic[1])} {f(ic[0] + dx * 1.6)},{f(ic[1] - 6)}", 1.3, 0.95, "carrot")
    for ang, L, w in front:
        blade(a, base[0], base[1], ang, L, L * w, fc, prof, teeth=9 if kind == "poppy" else 0, td=0.04, veins=0, petal=True,
              shade=0.09)
        if kind == "crocus" and sp.get("feather"):
            t = T(*base, ang)
            for o in (-2, 0, 2):
                a.line(f"M{P(t(4, o * 0.5))} Q{P(t(12, o))} {P(t(18, o * 1.4))}", 0.6, 0.6, sp["feather"])
    return a


def bell_shape(a, x, y, ang, L, W, fill, lobes=5, urn=False, spots=None, inside="shade"):
    """One bell hanging from x,y, its mouth at the far end."""
    t = T(x, y, ang)
    if urn:
        hw = lambda u: W / 2 * (0.42 + 0.58 * math.sin(math.pi * min(1, u * 1.05)) ** 0.7) * (1 - 0.35 * max(0, u - 0.8) / 0.2)
    else:
        hw = lambda u: W / 2 * (0.3 + 0.7 * u ** 1.3)
    us = [i / 30 for i in range(31)]
    top = [t(L * u, hw(u)) for u in us]; bot = [t(L * u, -hw(u)) for u in us]
    # the rim, with small lobes turned back
    rim = []
    wm = hw(1) * (1.25 if not urn else 1.4)
    for j in range(41):
        v = -1 + 2 * j / 40
        bump = 1 + 0.12 * abs(math.sin(math.pi * v * lobes / 2))
        rim.append(t(L + 1.8 * bump * (1 - v * v) ** 0.5 + 0.8, v * wm))
    a.shape(path(top + rim[::-1] + bot[::-1]), fill, 0.9)
    a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    mouth = T(*t(L + 0.6), ang)
    a.polar(*t(L + 0.6), lambda h: 1, wm * 0.32, wm * 0.92, ang, inside if inside != "shade" else None, 0.6, shade=False)
    if inside == "shade":
        a.shape(path([mouth(wm * 0.32 * math.cos(h), wm * 0.92 * math.sin(h)) for h in [2 * math.pi * i / 30 for i in range(30)]]), "shade", 0, fa=0.22)
    for u in (0.35, 0.65):
        a.line(opath([t(L * v, hw(v) * (u * 2 - 1) * 0.8) for v in (0.12, 0.5, 0.92)]), 0.4, 0.3)
    if spots:
        for u, o in ((0.6, -0.3), (0.72, 0.1), (0.82, -0.45), (0.86, 0.35), (0.7, -0.6)):
            p = t(L * u, hw(u) * o); a.dot(p[0], p[1], 0.7, spots)


def fl_bell(a, sp):
    """Bells hanging from an arching stalk: foxglove, comfrey, blueberry, cowslip."""
    from plant_kit import Quad
    fc = sp["fc"]; L = sp.get("L", 22); W = sp.get("W", 13); mix = sp.get("mix")
    if sp.get("umbel"):   # cowslip: a nodding bunch at the top of a bare stalk
        a.ribbon((48, 98), (46, 60), (50, 26), 2.6, 2.0, "leaf", lw=0.9)
        for k, ang in enumerate((150, 30, 122, 58, 90)):
            e = T(50, 26, ang)(7)
            a.line(f"M50,26 L{P(e)}", 0.8, 0.8)
            a.oval(*T(*e, ang)(3), 4.4, 3.0, ang, "pale", 0.7)   # the pale, swollen calyx
            bell_shape(a, *T(*e, ang)(5), ang, L, W, fc, spots=sp.get("spots"))
        return a
    q = Quad((40, 98), (36, 40), (62, 12))
    a.ribbon(q.p0, q.c, q.p1, 2.6, 1.4, "leaf", lw=0.9)
    nodes = sp.get("nodes", [(0.42, 1, 1.0), (0.62, -1, 0.85), (0.8, 1, 0.7)])
    for i, (u, sd, s) in enumerate(nodes):
        x, y = q.pt(u); e = (x + sd * 7 * s, y - 2)
        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 5 * s)},{f(y - 4)} {P(e)}", 0.9, 0.85)
        a.oval(e[0], e[1] + 1, 1.8 * s, 2.2 * s, 0, "leaf", 0.6)
        bell_shape(a, e[0], e[1] + 1.5, 90 - sd * sp.get("lean", 22), L * s, W * s, (mix if (mix and i % 2) else fc), urn=sp.get("urn"),
                   spots=sp.get("spots"))
    for u in (0.9, 0.97):
        x, y = q.pt(u); a.oval(x + 2, y + 1, 1.6, 2.4, 30, fc if not mix else mix, 0.6)
    return a


def lip_flower(a, x, y, ang, s, fc, calyx="deep"):
    """One two-lipped flower from the side, its tube along ang."""
    blade(a, x, y, ang, 8 * s, 4.2 * s, calyx, "obovate", veins=0, petal=True, lw=0.7)
    t = T(x, y, ang); m = t(7 * s)
    a.ribbon((x, y), t(6 * s), t(12 * s), 2.2 * s, 3.4 * s, fc, lw=0.7)
    e = t(12 * s)
    up = -1 if math.cos(math.radians(ang)) >= 0 else 1
    blade(a, e[0], e[1], ang - up * 32, 10 * s, 4.2 * s, fc, "elliptic", veins=0, petal=True, lw=0.7)
    blade(a, e[0], e[1], ang + up * 38, 8 * s, 6.4 * s, fc, "round", veins=0, petal=True, lw=0.7)


def fl_lip(a, sp):
    """Whorls of two-lipped flowers up a stem: sage, basil, lavender."""
    fc = sp["fc"]; dense = sp.get("dense")
    a.ribbon((50, 98), (51, 60), (50, 8), 2.4, 1.4, "leaf", lw=0.8)
    if dense:   # lavender: tight whorls of small flowers and bracts
        for j, y in enumerate((70, 56, 44, 34, 25, 17)):
            s = 0.8 - j * 0.05
            for sd in (-1, 1):
                lip_flower(a, 50 + sd * 1.2, y, -90 + sd * 62, s, fc, fc if j % 2 else "plum")
            a.oval(50, y + 1, 2.6 * s * 1.6, 2.0, 0, "plum", 0.6)
        return a
    for j, (y, s) in enumerate([(76, 1.25), (54, 1.1), (34, 0.9)]):
        for sd in (-1, 1):
            lip_flower(a, 50 + sd * 1.2, y, -90 + sd * 64, s, fc, sp.get("calyx", "deep"))
        blade(a, 50, y + 2, 180, 7, 3, "leaf", "ovate", veins=0, petal=True, lw=0.6); blade(a, 50, y + 2, 0, 7, 3, "leaf", "ovate", veins=0, petal=True, lw=0.6)
    for y in (20, 14):
        a.oval(50, y, 2.0, 3.0, 0, "deep", 0.6)
    return a


def pea_flower(a, x, y, face, s, fc, wing=None, keel=None):
    """A pea flower from the side. face is 1 to face right, -1 to face left."""
    blade(a, x, y, 90 - face * 70, 7 * s, 5 * s, "leaf", "obovate", veins=0, petal=True, lw=0.7)   # calyx
    sx, sy = x + face * 3 * s, y - 4 * s
    a.polar(sx, sy - 6 * s, lambda h: 1 + 0.06 * math.cos(2 * h), 9.5 * s, 9 * s, -face * 14, fc, 0.9)   # the standard
    a.line(f"M{f(sx)},{f(sy)} L{f(sx - face * 1.5 * s)},{f(sy - 11 * s)}", 0.5, 0.35)
    for o in (-1, 1):
        a.line(f"M{f(sx)},{f(sy)} Q{f(sx + o * 3 * s)},{f(sy - 6 * s)} {f(sx + o * 4.5 * s - face * s)},{f(sy - 11 * s)}", 0.4, 0.28)
    wc = wing or fc
    blade(a, x + face * 2 * s, y - 1.5 * s, -face * 0 + (0 if face > 0 else 180) - face * 12, 12 * s, 7 * s, wc, "obovate", veins=0, petal=True, lw=0.8)
    if keel:
        blade(a, x + face * 3 * s, y, (0 if face > 0 else 180) + face * 8, 11 * s, 4.6 * s, keel, "ovate", veins=0, petal=True, lw=0.7)
    if wing and wing != fc:   # a dark blotch on the wing
        e = (x + face * 9 * s, y - 2 * s); a.oval(e[0], e[1], 2.6 * s, 2.0 * s, 0, "dark", 0)


def fl_pea(a, sp):
    from plant_kit import Quad
    fc = sp["fc"]; cen = sp.get("cen", "sun"); wing = cen if cen in ("dark", "lilac", "pink", "white", "plum") and cen != fc else None
    keel = sp.get("keel")
    if sp.get("spike"):   # lupin, vetch: many small flowers up one stem
        q = Quad((50, 98), (52, 56), (48, 8))
        a.ribbon(q.p0, q.c, q.p1, 2.6, 1.2, "leaf", lw=0.8)
        for j in range(9):
            u = 0.3 + 0.62 * j / 8; x, y = q.pt(u); sd = 1 if j % 2 else -1; s = 0.62 - 0.03 * j
            a.line(f"M{f(x)},{f(y)} L{f(x + sd * 3)},{f(y - 1)}", 0.7, 0.8)
            pea_flower(a, x + sd * 4, y, sd, s, fc, sp.get("wingc"), keel)
        return a
    if sp.get("head"):   # bird's-foot trefoil: a ring of flowers at the top of a stalk
        a.ribbon((50, 98), (52, 76), (50, 56), 2.2, 1.8, "leaf", lw=0.8)
        for j, ang in enumerate((-160, -20, -120, -60)):
            e = T(50, 56, ang)(12); sd = 1 if math.cos(math.radians(ang)) > 0 else -1
            a.line(f"M50,56 L{P(e)}", 0.9, 0.85)
            pea_flower(a, e[0], e[1], sd, 1.15, fc if j < 3 else "carrot")
        return a
    q = Quad((44, 98), (40, 56), (58, 16))
    a.ribbon(q.p0, q.c, q.p1, 2.4, 1.4, "leaf", lw=0.8)
    for u, sd, s in ((0.48, -1, 1.55), (0.72, 1, 1.25)):
        x, y = q.pt(u); e = (x + sd * 6, y - 1)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.9, 0.85)
        pea_flower(a, e[0] + sd * 2, e[1] + 4, sd, s, fc, wing, keel)
    x, y = q.pt(0.94); bud(a, x, y, -60, 9, fc)
    return a


def sphere_points(n, seed=0.5):
    pts = []
    for i in range(n):
        z = 1 - 2 * (i + seed) / n; r = math.sqrt(max(0, 1 - z * z)); th = i * GOLD
        pts.append((r * math.cos(th), r * math.sin(th), z))
    return pts


def fl_globe(a, sp):
    """A ball of small star flowers on fine stalks: leek, chives, allium."""
    fc = sp["fc"]; R = sp.get("R", 30); c = (50, 40); loose = sp.get("loose")
    if sp.get("drum"):   # round-headed leek: a tight egg-shaped head, the flowers too close to see their stalks
        R = 19; c = (50, 36)
        a.ribbon((50, 98), (51, 76), (c[0], c[1] + R), 2.6, 2.2, "leaf", lw=0.9)
        a.oval(c[0], c[1], R * 0.86, R * 1.12, 0, fc, 1.0)
        for x, y, z in sorted([q for q in sphere_points(120) if q[2] > -0.1], key=lambda q: q[2]):
            e = (c[0] + x * R * 0.8, c[1] + y * R * 1.06)
            if y > 0.5 and sp.get("topc"):   # it colours from the top down: the buds at the foot are the last to turn, and still green
                a.oval(e[0], e[1], 1.5, 1.9, 0, sp["topc"], 0.4)
            else:
                a.flower(e[0], e[1], 2.9 * (0.7 + 0.3 * z), 6, fc, None, 0.5, start=-90 + x * 80, lw=0.4)
                a.dot(e[0], e[1], 0.4, "pink")
        return a
    a.ribbon((50, 98), (51, 76), (c[0], c[1] + (R * 0.5 if not loose else 0)), 3.0, 2.6, "leaf", lw=0.9)
    if not loose:
        for sg in (-1, 1):   # the papery spathe, split and hanging
            blade(a, c[0] + sg * 2, c[1] + R * 0.55, 90 + sg * 30, 16, 6, "straw", "lance", veins=0, petal=True, lw=0.7)
    pts = sphere_points(sp.get("n", 52 if not loose else 18))
    if loose:
        pts = [(x, -abs(y) * 0.7 - 0.3, z) for x, y, z in pts]
    else:
        a.shape(path([(c[0] + R * 0.86 * math.cos(h), c[1] + R * 0.82 * math.sin(h)) for h in [2 * math.pi * i / 60 for i in range(60)]]), fc, 0, fa=0.35)
    for x, y, z in sorted(pts, key=lambda p: p[2]):
        e = (c[0] + x * R, c[1] + y * R * (0.95 if not loose else 1.1))
        if z > -0.2 or loose:
            m = (c[0] + (e[0] - c[0]) * 0.86, c[1] + (e[1] - c[1]) * 0.86)
            a.line(f"M{P(c)} L{P(m)}", 0.35, 0.16 + 0.16 * (z + 1) / 2)
        s = (3.6 if not loose else 7.0) * (0.75 + 0.25 * (z + 1) / 2)
        a.flower(e[0], e[1], s, 6, fc, sp.get("cen", "unripe") if z > 0 else None, 0.46, start=-90 + (x * 90), cr=s * 0.24, lw=0.35)
    return a


def fl_mop(a, sp):
    """A dome of four-petalled florets: hydrangea."""
    fc = sp["fc"]; c = (50, 46); R = 34
    if sp.get("lacecap"):   # a flat head: tiny fertile flowers in the middle, a ring of showy ones round the edge
        c = (50, 42); R = 33; k = 0.5
        bloom_stem(a, (c[0], c[1] + 16), w=3.2)
        ring = [(c[0] + R * math.cos(math.radians(g)), c[1] + R * k * math.sin(math.radians(g)), g) for g in [i * 45 + 14 for i in range(8)]]
        for x, y, g in ring:
            a.line(f"M{f(c[0])},{f(c[1] + 15)} Q{f((c[0] + x) / 2)},{f((c[1] + 15 + y) / 2 + 3)} {f(x)},{f(y)}", 0.6, 0.6)
        for x, y, g in [r for r in ring if math.sin(math.radians(r[2])) < 0]:
            a.flower(x, y, 8.2, 4, fc, "white", 0.82, start=-45 + g, cr=1.2, lw=0.6)
        a.shape(path([(c[0] + R * 0.66 * math.cos(h), c[1] + R * 0.66 * k * math.sin(h)) for h in [2 * math.pi * i / 50 for i in range(50)]]), sp.get("fertile", "beet"), 0, fa=0.18)
        for j in range(54):
            rr = R * 0.62 * math.sqrt((j + 0.5) / 54); th = j * GOLD; x, y = c[0] + rr * math.cos(th), c[1] + rr * k * math.sin(th)
            if j % 3 == 0:
                a.flower(x, y, 2.3, 5, fc, None, 0.7, start=j * 20, lw=0.35)
            else:
                a.oval(x, y, 1.1, 1.1, 0, sp.get("fertile", "beet"), 0.4)
        for x, y, g in [r for r in ring if math.sin(math.radians(r[2])) >= 0]:
            a.flower(x, y, 8.8, 4, fc, "white", 0.82, start=-45 + g, cr=1.2, lw=0.6)
        return a
    bloom_stem(a, (c[0], c[1] + 18), w=3.4)
    for i, (x, y, z) in enumerate(sorted([p for p in sphere_points(90) if p[2] > -0.25], key=lambda p: p[2])):
        e = (c[0] + x * R, c[1] + y * R * 0.82)
        a.flower(e[0], e[1], 4.4 * (0.7 + 0.3 * z), 4, fc if i % 5 else "lilac", "pale", 0.8, start=-45 + 30 * x, cr=0.7, lw=0.5)
    return a


def fl_spiky(a, sp):
    """A ball covered in small spiky flowers: globe thistle."""
    fc = sp["fc"]; c = (50, 42); R = 24
    bloom_stem(a, (c[0], c[1] + R), fill="sage", w=3.0)
    for sg in (-1, 1):
        blade(a, c[0], c[1] + R - 2, 90 + sg * 48, 14, 3, "sage", "lance", veins=0, petal=True, lw=0.7)
    a.oval(c[0], c[1], R, R, 0, fc, 1.0)
    for x, y, z in sorted([p for p in sphere_points(70) if p[2] > 0], key=lambda p: p[2]):
        e = (c[0] + x * R * 0.92, c[1] + y * R * 0.92)
        for k in range(5):
            ang = k * 72 + x * 50; p = T(*e, ang)(2.6)
            a.line(f"M{P(e)} L{P(p)}", 0.5, 0.6)
        a.dot(e[0], e[1], 0.6, "white")
    return a


def fl_pin(a, sp):
    """A pincushion head: scabious. Large frilled florets round the edge,
    small ones in the middle with their stamens standing up like pins."""
    fc = sp["fc"]; c = (50, 44); R = 30; k = 0.8; M = tilt(c[1], k)
    bloom_stem(a, (c[0], c[1] + 8))
    for i in range(12):
        blade(a, c[0], c[1], i * 30 + 15, R * 0.5, R * 0.14, "leaf", "lance", veins=0, M=M, lw=0.6, petal=True)
    even = sp.get("even")   # devil's-bit: a rounder head, every floret the same size
    if not even:
        for i in sorted(range(11), key=lambda i: math.sin(i * 2 * math.pi / 11)):
            ang = i * 360 / 11; e = M(T(*c, ang)(R * 0.62))
            blade(a, e[0], e[1], ang, R * 0.4, R * 0.42, fc, "round", veins=0, M=None, lw=0.7, petal=True, teeth=5, td=0.2)
    dome = 0.72 if even else 0.56
    if even:
        k = 0.92
    a.oval(c[0], c[1], R * dome, R * dome * k, 0, fc, 0.8)
    nf = 64 if even else 40
    for j in range(nf):
        rr = R * (dome - 0.06) * math.sqrt((j + 0.5) / nf); th = j * GOLD; x, y = c[0] + rr * math.cos(th), c[1] + rr * math.sin(th) * k
        a.flower(x, y, 1.4, 4, fc, None, 0.6, lw=0.35)
        a.line(f"M{f(x)},{f(y)} L{f(x + 0.6)},{f(y - 3.2)}", 0.4, 0.5); a.dot(x + 0.6, y - 3.4, 0.55, "white")
    return a


def fl_clover(a, sp):
    """A round head of tiny pea flowers: clover."""
    fc = sp["fc"]; c = (50, 42); R = 22
    bloom_stem(a, (c[0], c[1] + R * 0.8))
    a.oval(c[0], c[1], R * 0.8, R * 0.76, 0, "pale" if fc == "white" else fc, 0.9)
    rows = 7
    for r in range(rows):   # rows of florets from the top down; the lowest have gone over
        y = c[1] - R * 0.72 + r * R * 0.24; w = R * 0.92 * math.sqrt(max(0.05, 1 - ((y - c[1]) / (R * 0.95)) ** 2))
        n = max(3, int(w / 2.4)); old = r >= rows - 2
        for j in range(n):
            x = c[0] - w + 2 * w * (j + 0.5 + 0.25 * (r % 2)) / (n + 0.25)
            ang = (75 + (x - c[0]) * 2.5) if old else (-90 + (x - c[0]) / R * 70)
            blade(a, x, y, ang, 9 if not old else 7, 3.2, "straw" if old else fc, "obovate", veins=0, petal=True, lw=0.5)
            if not old:
                e = T(x, y, ang)(8); a.dot(e[0], e[1], 0.5, "pink" if fc == "white" else "beet")
    for sg in (-1, 1):
        blade(a, c[0], c[1] + R + 4, -90 + sg * 75, 12, 4.4, "leaf", "lance", veins=0, petal=True, lw=0.6)
    return a


def fl_umbel(a, sp):
    """A plate of small flowers on spokes, in small plates again: carrot, dill."""
    fc = sp["fc"]; hub = (50, 72); c = (50, 38); R = sp.get("R", 34); k = 0.34
    bloom_stem(a, hub, base=(52, 98), w=2.6)
    if sp.get("bracts"):   # carrot: forked bracts under the head
        for ang in (-160, -130, -50, -20):
            e = T(*hub, ang)(13); a.line(f"M{P(hub)} L{P(e)} M{P(T(*hub, ang)(8))} L{P(T(*T(*hub, ang)(8), ang + 30)(5))}", 0.7, 0.75)
    n = sp.get("rays", 9)
    us = [(i * 360 / n + 10) for i in range(n)] + ["c"]
    def place(ang):
        if ang == "c": return c, 0.6
        r = math.radians(ang); return (c[0] + R * math.cos(r), c[1] + R * k * math.sin(r)), math.sin(r)
    for ang in sorted(us, key=lambda g: place(g)[1]):
        e, z = place(ang)
        a.line(f"M{P(hub)} Q{f((hub[0] + e[0]) / 2)},{f((hub[1] + e[1]) / 2 + 4)} {P(e)}", 0.7, 0.75)
        rr = 8.0 * (0.9 + 0.12 * z)
        for j in sorted(range(8), key=lambda j: math.sin(j * 0.9)):
            th = j * 51 + 5; p = (e[0] + rr * math.cos(math.radians(th)), e[1] - 3 + rr * 0.5 * math.sin(math.radians(th)))
            if j == 7: p = (e[0], e[1] - 4)
            a.line(f"M{P(e)} L{P(p)}", 0.4, 0.5)
            outer = ang != "c" and abs(math.atan2(p[1] - c[1], (p[0] - c[0]) * k)) >= 0 and math.hypot(p[0] - c[0], (p[1] - c[1]) / k) > R
            a.flower(p[0], p[1], 2.2 if not outer else 3.0, 5, fc, None, 0.8, start=-90 + th, lw=0.38)
            a.dot(p[0], p[1], 0.45, "unripe")
    if sp.get("purple"):   # carrot: a single dark floret in the middle
        a.flower(c[0], c[1] - 4, 2.4, 5, "plum", None, 0.8, lw=0.45)
    return a


def fl_tuft(a, sp):
    """A cup of scaly bracts with florets standing out of it: cornflower,
    thistle, artichoke."""
    fc = sp["fc"]; style = sp.get("style", "brush"); big = sp.get("big")
    c = (50, 62 if not big else 66); W = 22 if not big else 34; H = 18 if not big else 28
    bloom_stem(a, (c[0], c[1] + H * 0.5), fill=sp.get("bractc", "leaf"), w=3.4 if big else 2.6)
    if style == "funnel":   # cornflower: big jagged funnels round the edge
        for i in sorted(range(9), key=lambda i: -abs(i - 4)):
            ang = -170 + 160 * i / 8
            blade(a, c[0], c[1] - H * 0.4, ang, 30, 13, fc, "obovate", teeth=6, td=0.5, veins=0, petal=True, lw=0.7)
        for i in range(14):
            ang = -150 + 120 * i / 13; e = T(c[0], c[1] - H * 0.4, ang)(11)
            a.line(f"M{f(c[0])},{f(c[1] - H * 0.4)} L{P(e)}", 1.2, 0.85, sp.get("inner", "plum")); a.dot(e[0], e[1], 0.8, "plum")
    else:   # a brush of fine florets
        for i in range(36):
            ang = -165 + 150 * i / 35 + 3 * math.sin(i * 1.7); L = (20 if not big else 24) * (0.75 + 0.25 * math.sin(math.pi * i / 35))
            e = T(c[0], c[1] - H * 0.35, ang)(L)
            a.line(f"M{f(c[0] + (i - 18) * 0.25)},{f(c[1] - H * 0.35)} L{P(e)}", 1.0, 0.9, "line"); a.line(f"M{f(c[0] + (i - 18) * 0.25)},{f(c[1] - H * 0.35)} L{P(e)}", 0.6, 1.0, fc if fc in ("plum", "lilac", "pink", "blue", "beet") else "plum")
    # the bracts, as overlapping scales
    a.oval(c[0], c[1], W * 0.5, H * 0.5, 0, sp.get("bractc", "leaf"), 1.0)
    for row in range(3 if not big else 4):
        y = c[1] - H * 0.3 + row * H * (0.22 if not big else 0.18); w = W * 0.5 * math.sqrt(max(0.1, 1 - ((y - c[1]) / (H * 0.5)) ** 2))
        m = 4 + row
        for j in range(m):
            x = c[0] - w + (2 * w) * (j + 0.5 * (row % 2)) / m
            if abs(x - c[0]) > w * 0.95:
                continue
            if big:
                blade(a, x, y + 5, -90, 8, 7, sp.get("bractc", "sage"), "ovate", veins=0, petal=True, lw=0.7)
            else:
                a.line(f"M{f(x - 2)},{f(y + 1.6)} Q{f(x)},{f(y - 1.2)} {f(x + 2)},{f(y + 1.6)}", 0.55, 0.55)
                if sp.get("fringe"):
                    a.dot(x, y - 0.6, 0.55, "dark")
    return a


def fl_plume(a, sp):
    """A branched spray of tiny flowers: meadowsweet, rhubarb, sweetcorn tassel."""
    from plant_kit import Quad
    fc = sp["fc"]; tassel = sp.get("tassel")
    q = Quad((50, 98), (49, 60), (50, 8))
    a.ribbon(q.p0, q.c, q.p1, 3.0, 1.2, "leaf" if not tassel else "pale", lw=0.8)
    for j in range(7):
        u = 0.32 + 0.6 * j / 6; x, y = q.pt(u); sd = 1 if j % 2 else -1; L = 32 * (1 - 0.6 * u)
        if tassel:
            e = (x + sd * L, y + L * 0.5); m = (x + sd * L * 0.6, y - 2)
            a.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)}", 0.8, 0.85)
            from plant_kit import Quad as Q2
            qq = Q2((x, y), m, e)
            for v in (0.3, 0.5, 0.7, 0.9):
                p = qq.pt(v); a.oval(p[0], p[1] - 1, 2.0, 3.4, sd * 30, fc, 0.6)
                a.line(f"M{f(p[0])},{f(p[1] + 2)} L{f(p[0])},{f(p[1] + 5)}", 0.5, 0.7); a.oval(p[0], p[1] + 6.2, 0.9, 1.6, 0, "amber", 0.4)
            continue
        e = (x + sd * L, y - L * 0.5)
        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * L * 0.5)},{f(y - 1)} {P(e)}", 0.7, 0.8)
        for v in (0.4, 0.7, 1.0):
            px, py = x + (e[0] - x) * v, y + (e[1] - y) * v - v * (1 - v) * 4
            for kk in range(4):
                th = kk * GOLD * 1.3; rr = 2.6 + 1.2 * (kk % 2)
                p = (px + rr * math.cos(th), py + rr * math.sin(th) * 0.8)
                if kk < 2:
                    a.flower(p[0], p[1], 3.2, sp.get("n", 5), fc, "sun" if fc == "white" else None, 0.8, start=th * 30, cr=0.8, lw=0.45)
                else:
                    a.oval(p[0], p[1], 1.6, 1.6, 0, fc, 0.5)
    for k in range(5):
        x, y = q.pt(0.93 + 0.015 * k); a.oval(x + (k % 2 - 0.5) * 3, y, 1.2, 1.2, 0, fc, 0.45)
    return a


def fl_trumpet(a, sp):
    """A daffodil: six petals round a long trumpet that points at you."""
    fc = sp["fc"]; cen = sp.get("cen", "sun"); c = (44, 50); k = 0.84
    a.ribbon((64, 98), (66, 60), (66, 32), 3.2, 3.0, "leaf", lw=0.9)
    a.line("M66,32 Q64,28 58,36", 2.4, 0.9); a.oval(59, 37, 2.6, 2.0, 40, "unripe", 0.7)
    blade(a, 66, 31, -70, 12, 4.4, "straw", "lance", veins=0, petal=True, lw=0.6)   # papery spathe
    ring_of_petals(a, 6, 30, 15, fc, "ovate", cx=c[0], cy=c[1], k=k, start=-60)
    off = (-5, 5); r0, r1 = 7, 11
    tc = (c[0] + off[0], c[1] + off[1])
    a.shape(f"M{f(c[0] - r0)},{f(c[1])} L{f(tc[0] - r1)},{f(tc[1])} L{f(tc[0] + r1)},{f(tc[1])} L{f(c[0] + r0)},{f(c[1])} Z", cen, 0.9)
    a.oval(c[0], c[1], r0, r0 * k, 0, cen, 0.9)
    a.shape(f"M{f(c[0] - r0 * 0.7)},{f(c[1] + r0 * 0.6)} L{f(tc[0] - r1 * 0.7)},{f(tc[1] + r1 * 0.6)} L{f(tc[0] + r1)},{f(tc[1])} L{f(c[0] + r0)},{f(c[1])} Z", "shade", 0, fa=0.1)
    a.polar(tc[0], tc[1], lambda h: 1 + 0.06 * math.cos(14 * h), r1 * 1.08, r1 * 0.86, 0, cen, 0.9)
    a.shape(path([(tc[0] + r1 * 0.72 * math.cos(h), tc[1] + r1 * 0.56 * math.sin(h)) for h in [2 * math.pi * i / 30 for i in range(30)]]), "shade", 0, fa=0.2)
    for dx, dy in ((-2, -1), (1.5, -1.5), (0, 1.5), (2.5, 1), (-2.4, 1.8)):
        a.dot(tc[0] + dx, tc[1] + dy, 0.8, "amber")
    return a


def fl_tiny(a, sp):
    """Small flowers in a cluster, drawn much larger than life."""
    fc = sp["fc"]; n = sp.get("n", 5)
    a.ribbon((52, 98), (50, 74), (50, 58), 2.6, 2.0, "leaf", lw=0.8)
    for ang in (-140, -90, -40):
        e = T(50, 58, ang)(14); a.line(f"M50,58 L{P(e)}", 0.9, 0.85)
    spots = [(34, 44, 9), (50, 34, 10), (66, 44, 9), (42, 26, 7.5), (60, 25, 7.5), (26, 32, 6.5), (74, 32, 6.5)]
    for x, y, r in sorted(spots, key=lambda s: s[1]):
        a.line(f"M50,58 Q{f((50 + x) / 2)},{f((58 + y) / 2 + 3)} {f(x)},{f(y)}", 0.5, 0.55)
        if sp.get("button"):   # wormwood: small round nodding heads with no petals
            a.oval(x, y - r * 0.3, r * 0.5, r * 0.3, 0, "sage", 0.6)
            a.oval(x, y + r * 0.1, r * 0.56, r * 0.5, 0, fc, 0.7)
            for j in range(9):
                rr = r * 0.4 * math.sqrt((j + 0.5) / 9); a.dot(x + rr * math.cos(j * GOLD), y + r * 0.14 + rr * 0.8 * math.sin(j * GOLD), 0.4, "amber")
            continue
        a.flower(x, y, r, n, fc, sp.get("cen", "sun"), 0.72, start=-90 + x, cr=r * 0.22, lw=0.6)
    for x, y in ((50, 16), (36, 16), (64, 15)):
        a.oval(x, y, 2.2, 2.8, 0, sp.get("budc", fc), 0.6)
    return a


def fl_pansy(a, sp):
    """A pansy or viola seen face on: two petals up, one to each side, a
    broad lip below, and dark lines running in to a yellow eye."""
    fc = sp["fc"]; c = (50, 46)
    bloom_stem(a, (53, 60))
    for ang in (-116, -64):
        blade(a, c[0], c[1], ang, 30, 30, sp.get("upc", fc), "round", veins=0, petal=True, lw=0.9, shade=0.14)
    for ang in (168, 12):
        blade(a, c[0], c[1], ang, 27, 27, fc, "round", veins=0, petal=True, lw=0.9)
    blade(a, c[0], c[1] - 1, 90, 31, 40, sp.get("lipc", fc), "round", veins=0, petal=True, lw=0.9)
    for ang, spread in ((90, (-24, -12, 0, 12, 24)), (168, (-10, 0, 10)), (12, (-10, 0, 10))):
        for o in spread:
            e = T(c[0], c[1], ang + o)(11 if o else 13)
            a.line(f"M{f(c[0])},{f(c[1])} L{P(e)}", 0.7, 0.85, "dark")
    a.oval(c[0], c[1] + 1.5, 3.0, 2.2, 0, "sun", 0.6)
    return a


def fl_horned(a, sp):
    """A rampion: a round head of narrow curved florets, like claws, with
    long narrow bracts spreading beneath it."""
    fc = sp["fc"]; c = (50, 40); R = 21
    bloom_stem(a, (50, 54), w=2.2)
    for ang, L in ((172, 30), (8, 30), (206, 22), (-26, 22), (140, 20), (40, 20)):
        blade(a, 50, 53, ang, L, 3.0, "leaf", "lance", veins=0, lw=0.7, shade=0.06)
    a.oval(c[0], c[1] + 2, 9, 8, 0, fc, 0.8)
    for kk in range(30):
        ang = -205 + 230 * kk / 29; L = R * (0.82 + 0.18 * math.sin(kk * 1.9))
        bend = -22 if ang > -90 else 22   # each tip curls in towards the top of the head
        m = T(c[0], c[1] + 2, ang)(L * 0.6); e = T(c[0], c[1] + 2, ang + bend)(L)
        d = f"M{f(c[0] + (kk - 14.5) * 0.3)},{f(c[1] + 2)} Q{P(m)} {P(e)}"
        a.line(d, 2.4, 0.9, "line"); a.line(d, 1.5, 1.0, fc)
    return a


def fl_funnel(a, sp):
    """A courgette or squash flower: a big funnel with five pointed lobes."""
    fc = sp["fc"]; c = (58, 34); k = 0.6; base = (40, 76)
    if sp.get("fruit"):   # a female flower sits on her small fruit
        a.ribbon((22, 96), (30, 86), (38, 80), 3.4, 3.0, "leaf", lw=0.9)
        a.ribbon((26, 92), (32, 86), base, 7, 6.4, sp["fruit"], lw=0.9, round_tip=False)
    else:
        a.ribbon((30, 98), (34, 88), base, 3.2, 2.8, "leaf", lw=0.9)
    for sg in (-1, 1):
        blade(a, base[0], base[1], -60 + sg * 50, 9, 2.0, "leaf", "lance", veins=0, petal=True, lw=0.6)
    M = tilt(c[1], k)
    order = sorted(range(5), key=lambda i: math.sin(math.radians(-60 + 72 * i)))
    for i in order[:2]:
        blade(a, c[0], c[1], -60 + 72 * i, 27, 22, fc, "ovate", veins=0, M=M, petal=True, lw=0.9)
    p1, p2 = (c[0] - 15, c[1] + 3), (c[0] + 13, c[1] - 6)
    a.shape(f"M{f(base[0] - 2.5)},{f(base[1])} Q{f(base[0] - 4)},{f(base[1] - 16)} {P(p1)} L{P(p2)} Q{f(base[0] + 12)},{f(base[1] - 18)} {f(base[0] + 3)},{f(base[1] + 1)} Z", fc, 0.9)
    a.shape(f"M{f(base[0] + 0.5)},{f(base[1])} Q{f(base[0] + 6)},{f(base[1] - 18)} {P(p2)} Q{f(base[0] + 12)},{f(base[1] - 18)} {f(base[0] + 3)},{f(base[1] + 1)} Z", "shade", 0, fa=0.12)
    for o in (-0.5, 0, 0.5):
        a.line(f"M{f(base[0] + o * 2)},{f(base[1] - 2)} Q{f(base[0] + o * 6 + 3)},{f(base[1] - 18)} {f((p1[0] + p2[0]) / 2 + o * 12)},{f((p1[1] + p2[1]) / 2 - o * 4)}", 0.5, 0.35)
    a.polar(c[0] - 1, c[1] - 1, lambda h: 1, 15, 15 * k, -16, fc, 0.9)
    a.shape(path([(c[0] - 1 + 11 * math.cos(h) * math.cos(-0.28) - 11 * k * 0.8 * math.sin(h) * math.sin(-0.28), c[1] - 1 + 11 * math.cos(h) * math.sin(-0.28) + 11 * k * 0.8 * math.sin(h) * math.cos(-0.28)) for h in [2 * math.pi * i / 30 for i in range(30)]]), "shade", 0, fa=0.22)
    for i in order[2:]:
        blade(a, c[0], c[1], -60 + 72 * i, 27, 22, fc, "ovate", veins=0, M=M, petal=True, lw=0.9)
    a.ribbon((c[0] - 2, c[1] + 4), (c[0] - 1, c[1]), (c[0], c[1] - 4), 4.4, 3.4, sp.get("cen", "amber"), lw=0.7)
    for dx in (-1.5, 0, 1.5):
        a.dot(c[0] + dx * 0.6, c[1] - 4.4, 0.7, "rust")
    return a


def fl_snowdrop(a, sp):
    a.ribbon((44, 98), (46, 60), (48, 24), 2.4, 2.0, "sage", lw=0.9)
    blade(a, 48, 26, -80, 10, 3.6, "pale", "lance", veins=0, petal=True, lw=0.6)   # the spathe
    a.line("M48,24 Q60,14 64,30", 1.0, 0.9)
    a.oval(64, 33, 3.0, 4.0, -8, "unripe", 0.8)
    top = (64, 37)
    blade(a, *top, 100, 44, 19, "white", "obovate", veins=0, petal=True, lw=0.9)
    blade(a, *top, 90, 28, 16, "white", "ovate", veins=0, petal=True, lw=0.9, shade=0.14)
    a.line(f"M{f(top[0] - 4)},{f(top[1] + 24)} L{f(top[0])},{f(top[1] + 20)} L{f(top[0] + 4)},{f(top[1] + 24)}", 2.0, 0.9, "deep")
    blade(a, *top, 60, 44, 19, "white", "obovate", veins=0, petal=True, lw=0.9)
    blade(a, *top, 128, 38, 16, "white", "obovate", veins=0, petal=True, lw=0.9)
    return a


def fl_reflex(a, sp):
    """A cyclamen: the flower hangs nose down and its petals sweep back up."""
    fc = sp["fc"]; nose = (52, 66)
    a.line(f"M40,98 Q36,60 46,46 Q54,40 {f(nose[0])},{f(nose[1] - 2)}", 1.6, 0.9, "line")
    for ang in (-150, -30, -128, -52, -90):
        blade(a, nose[0], nose[1], ang, 34 if abs(ang + 90) < 50 else 28, 11, fc, "lance", veins=0, petal=True, lw=0.9)
        e = T(*nose, ang)(5); a.oval(e[0], e[1], 2.8, 1.8, ang, sp.get("cen", "beet"), 0)
    a.oval(nose[0], nose[1] + 1.5, 3.6, 2.4, 0, fc, 0.8); a.dot(nose[0], nose[1] + 4.2, 0.7, "beet")
    return a


def fl_blossom(a, sp):
    """Tree blossom: a cluster of open flowers and buds on a short spur."""
    fc = sp["fc"]; tinge = sp.get("tinge"); anth = sp.get("anth", "primrose")
    a.ribbon((6, 92), (40, 80), (94, 82), 4.4, 3.0, "bark", lw=0.9)
    spur = (50, 80)
    a.ribbon((50, 84), (50, 82), spur, 4, 3, "bark", lw=0.7)
    for ang, L in ((-160, 18), (-24, 20)):
        blade(a, spur[0], spur[1], ang, L, L * 0.44, "leaf", "ovate", teeth=10, td=0.08, veins=3, lw=0.8)
    flowers = [(28, 44, 17), (56, 30, 18), (74, 54, 15)]
    for x, y, r in flowers:
        a.line(f"M{P(spur)} Q{f((spur[0] + x) / 2)},{f(y + 14)} {f(x)},{f(y)}", 0.8, 0.85)
    for x, y in ((40, 60), (64, 64)):
        a.line(f"M{P(spur)} L{f(x)},{f(y)}", 0.8, 0.85); a.oval(x, y - 2.5, 3.0, 3.6, 0, tinge or fc, 0.8)
    for x, y, r in flowers:
        M = tilt(y, 0.86)
        for i in range(5):
            blade(a, x, y, -90 + 72 * (i + 0.5), r * 0.5, r * 0.22, "leaf", "lance", veins=0, M=M, lw=0.6, petal=True)
        ring_of_petals(a, 5, r, r * 0.92, fc, "round", cx=x, cy=y, k=0.86, start=-90 + x)
        if tinge:
            for i in range(5):
                ang = -90 + x + 72 * i; t = T(x, y, ang)
                a.line(opath([M(t(r * u, -r * 0.42 * PROF["round"](u))) for u in (0.5, 0.72, 0.9)]), 1.0, 0.55, tinge)
        stamens(a, x, y, 0.8, r * 0.34, 14, anth, M, lw=0.4)
        a.oval(x, y, 1.2, 1.0, 0, "unripe", 0.6)
    return a


def fl_fig(a, sp):
    """A fig's flowers are inside it: a fig cut in half, and one whole."""
    a.line("M74,8 L72,20", 1.6, 0.9)
    PA.FR(a, "pear", 72, 20, 7, "plum")
    c = (42, 58)
    pts = []
    for i in range(80):
        h = 2 * math.pi * i / 80; r = 1 + 0.25 * max(0, -math.sin(h)) ** 2
        pts.append((c[0] + 22 * math.cos(h) * (1 - 0.28 * max(0, -math.sin(h))), c[1] + 26 * math.sin(h) * r * 0.9))
    a.shape(path(pts), "unripe")
    inner = [(c[0] + (p[0] - c[0]) * 0.8, c[1] + (p[1] - c[1]) * 0.8 + 1) for p in pts]
    a.shape(path(inner), "white", 0.6)
    cav = [(c[0] + (p[0] - c[0]) * 0.55, c[1] + (p[1] - c[1]) * 0.55 + 2) for p in pts]
    a.shape(path(cav), "pink", 0.6)
    for k in range(34):
        h = 2 * math.pi * k / 34; p0 = cav[int(k * 80 / 34) % 80]
        p1 = (p0[0] + (c[0] - p0[0]) * 0.32, p0[1] + (c[1] + 2 - p0[1]) * 0.32)
        a.line(f"M{P(p0)} L{P(p1)}", 0.6, 0.6, "berry"); a.dot(p1[0], p1[1], 0.6, "berry")
    a.line(f"M{f(c[0])},{f(c[1] + 22)} L{f(c[0])},{f(c[1] + 15)}", 1.0, 0.8)
    a.line(f"M{f(c[0])},{f(c[1] - 22)} L{f(c[0] + 1)},{f(c[1] - 30)}", 1.6, 0.9)
    return a


def fl_iris(a, sp):
    """An iris: three narrow standards standing up, three falls arching out and
    down, each with a bright signal mark, and a short style arm lying on each fall."""
    fc = sp["fc"]; c = (50, 50); sig = sp.get("sig", "sun"); falls = sp.get("falls", (28, 152, 90))
    a.ribbon((52, 98), (52, 80), (c[0], c[1] + 10), 3.2, 2.8, "leaf", lw=0.9)
    blade(a, c[0] + 1, c[1] + 14, -96, 14, 5, "straw", "lance", veins=0, petal=True, lw=0.6)
    sl = sp.get("sl", 36); sw = sp.get("sw", 9)   # the standards' length and width
    for ang in (-64, -116, -90):
        blade(a, c[0], c[1], ang, sl if ang == -90 else sl - 3, sw, fc, "obovate", veins=0, petal=True, lw=0.9)
    for ang in falls:
        blade(a, c[0], c[1], ang, 36, sp.get("fw", 20), fc, "obovate", veins=0, petal=True, lw=0.9, shade=0.12)
        t = T(*c, ang)
        a.ribbon(t(12), t(19), t(28), 5.0, 1.4, sig, lw=0.5)   # the signal: the mark that guides a bee in
        for o in (-0.5, 0.5):
            a.line(f"M{P(t(13, o * 6))} Q{P(t(21, o * 10))} {P(t(31, o * 12))}", 0.5, 0.55, sp.get("veinc", "plum"))
    for ang in falls:     # the style arms, short, so the signal shows beyond them
        blade(a, c[0], c[1], ang, 11, 6, fc, "elliptic", veins=0, petal=True, lw=0.7)
    return a


def fl_string(a, sp):
    """A hanging string of small open flowers, the youngest at the tip: red and white currants."""
    from plant_kit import Quad
    fc = sp["fc"]
    q = Quad((30, 8), (58, 30), (62, 92))
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.0, "leaf", lw=0.8)
    for j in range(7):
        u = 0.16 + 0.8 * j / 6; x, y = q.pt(u); sd = -1 if j % 2 else 1; r = 8.5 * (1 - 0.45 * u)
        e = (x + sd * 13, y + 3)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.8, 0.85)
        a.flower(e[0], e[1], r, 5, fc, sp.get("cen", "primrose"), 0.8, start=-90 + 20 * sd, cr=r * 0.3, lw=0.6)
    return a


def fl_stars(a, sp):
    """Peacock orchid: six white petals with a dark heart, nodding."""
    fc = sp["fc"]; c = (48, 46)
    a.line(f"M60,98 Q70,40 {f(c[0] + 6)},{f(c[1] - 24)}", 1.6, 0.9)
    a.line(f"M{f(c[0] + 6)},{f(c[1] - 24)} Q{f(c[0] + 2)},{f(c[1] - 16)} {f(c[0])},{f(c[1] - 6)}", 1.2, 0.9)
    a.ribbon((c[0] + 1, c[1] - 6), (c[0] + 0.5, c[1] - 2), c, 3.2, 2.4, "leaf", lw=0.7)
    M = ring_of_petals(a, 6, 30, 13, fc, "elliptic", cx=c[0], cy=c[1] + 2, k=0.8, start=-60)
    for i in range(6):
        ang = -60 + 60 * i
        blade(a, c[0], c[1] + 2, ang, 10, 6, sp.get("cen", "plum"), "ovate", veins=0, M=M, petal=True, lw=0, shade=0)
    stamens(a, c[0], c[1] + 2, 1, 9, 3, "straw", M, lw=0.6)
    bud(a, 76, 28, -10, 10, "white")
    return a


def fl_spike(a, sp):
    """A dense spike of small urns: grape hyacinth. Or of small stars: puschkinia."""
    fc = sp["fc"]; open_ = sp.get("open")
    a.ribbon((50, 98), (50, 80), (50, 60), 3.0, 2.6, "leaf", lw=0.9)
    rows = 9
    for r in range(rows):
        y = 60 - r * 5.4; w = (14 - r * 1.1) * (0.6 if r == 0 else 1); s = 1 - r * 0.07
        n = 4 if r % 2 else 3
        for j in sorted(range(n), key=lambda j: -abs(j - (n - 1) / 2)):
            x = 50 + (j - (n - 1) / 2) * (2 * w / max(1, n - 1)) * 0.9
            if open_:
                a.line(f"M50,{f(y + 2)} L{f(x)},{f(y)}", 0.4, 0.5)
                a.flower(x, y, 5.4 * s, 6, fc, "pale", 0.44, start=-90 + x * 7, cr=1, lw=0.5)
                for k in range(6):
                    e = T(x, y, -90 + x * 7 + k * 60)(4.4 * s); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.9, 0.85, sp.get("stripe", "blue"))
            else:
                col = fc if r < rows - 2 else sp.get("topc", "lilac")
                a.oval(x, y, 3.4 * s, 4.0 * s, 0, col, 0.7)
                a.oval(x, y + 3.6 * s, 1.8 * s, 0.8 * s, 0, "white", 0.4)
    return a


def fl_nod(a, sp):
    """Snake's head fritillary: one nodding square-shouldered bell, chequered."""
    fc = sp["fc"]
    a.line("M42,98 Q40,40 56,16 Q62,14 62,24", 1.6, 0.9)
    t = T(62, 24, 90); L, W = 52, 40
    hw = lambda u: W / 2 * (0.22 + 0.78 * math.sin(math.pi / 2 * min(1, u / 0.3)) ** 0.7) * (1 - 0.14 * u)
    us = [i / 30 for i in range(31)]
    top = [t(L * u, hw(u)) for u in us]; bot = [t(L * u, -hw(u)) for u in us]
    tips = [t(L + (3 if j % 2 == 0 else 0), hw(1) * (1 - 2 * j / 6)) for j in range(7)]
    a.shape(path(top + tips + bot[::-1]), fc, 0.9)
    for i in range(8):          # the chequers: pale squares inside the outline
        for j in range(-3, 4):
            if (i + j) % 2:
                continue
            u0, u1 = 0.06 + i * 0.115, 0.06 + (i + 1) * 0.115
            v0, v1 = j / 3.5, (j + 1) / 3.5
            if v1 > 1:
                continue
            q = [t(L * u0, hw(u0) * v0 * 0.95), t(L * u1, hw(u1) * v0 * 0.95), t(L * u1, hw(u1) * v1 * 0.95), t(L * u0, hw(u0) * v1 * 0.95)]
            a.shape(path(q), "pink", 0, fa=0.55)
    a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    return a


def fl_crown(a, sp):
    """Crown imperial: a ring of hanging bells under a tuft of leaves."""
    fc = sp["fc"]; top = (50, 34)
    a.ribbon((50, 98), (50, 66), top, 4.0, 3.2, "unripe", lw=0.9)
    for k in range(9):
        ang = -160 + 140 * k / 8
        blade(a, top[0], top[1], ang, 22 - abs(k - 4) * 1.6, 4.2, "leaf", "lance", veins=0, lw=0.8)
    ring = [(top[0] + 21 * math.cos(math.radians(th)), top[1] + 7 + 5 * math.sin(math.radians(th))) for th in (-140, -40, 170, 10, 90)]
    for p in sorted(ring, key=lambda p: p[1]):
        a.line(f"M{f(top[0])},{f(top[1] + 2)} Q{f(p[0])},{f(top[1] - 3)} {P(p)}", 0.9, 0.85)
        bell_shape(a, p[0], p[1], 90 - (p[0] - 50) * 1.6, 26, 12, fc, lobes=6)
    return a


def fl_bluebell(a, sp):
    fc = sp["fc"]
    from plant_kit import Quad
    q = Quad((40, 98), (42, 30), (70, 14))
    a.ribbon(q.p0, q.c, q.p1, 2.6, 1.4, "leaf", lw=0.9)
    for j, u in enumerate((0.42, 0.56, 0.68, 0.8, 0.9)):
        x, y = q.pt(u); s = 1 - 0.12 * j
        e = (x + 5 * s, y + 1)
        a.line(f"M{f(x)},{f(y)} Q{f(x + 4)},{f(y - 2)} {P(e)}", 0.8, 0.85)
        bell_shape(a, e[0], e[1], 76, 20 * s, 9 * s, fc, lobes=6)
        m = T(*e, 76)(20 * s + 1)
        for sg in (-1, 1):
            p = T(*m, 76 + sg * 90)(4.4 * s); a.line(f"M{P(p)} q{f(sg * 1.6)},{f(-0.4)} {f(sg * 1.2)},{f(-2)}", 0.8, 0.8)
    return a


BLOOM_DRAW = {"string": fl_string, "daisy": fl_daisy, "flat": fl_flat, "four": fl_four, "six": fl_six, "star": fl_star, "cup": fl_cup,
              "bell": fl_bell, "lip": fl_lip, "pea": fl_pea, "globe": fl_globe, "mop": fl_mop, "spiky": fl_spiky,
              "pin": fl_pin, "clover": fl_clover, "umbel": fl_umbel, "tuft": fl_tuft, "plume": fl_plume,
              "trumpet": fl_trumpet, "tiny": fl_tiny, "funnel": fl_funnel, "snowdrop": fl_snowdrop, "reflex": fl_reflex,
              "blossom": fl_blossom, "fig": fl_fig, "iris": fl_iris, "stars": fl_stars, "spike": fl_spike, "nod": fl_nod,
              "crown": fl_crown, "bluebell": fl_bluebell, "pansy": fl_pansy, "horned": fl_horned}


# ======================================================= what each kind gets
def leaf_spec(slug, s):
    """The close-up leaf for one kind, worked out from its settings."""
    lf = s.get("leaf"); lc = s.get("lc", "leaf"); h = s.get("habit")
    sp = dict(fill=lc)
    if s.get("stalkc"):
        sp["stalkc"] = s["stalkc"]
    if h in ("bulb", "cyclamen") or lf is None:
        sp.update(kind="strap", W=16 if s.get("bleaf") == "broad" else 9, prof="linear")
    elif lf == "simple": sp.update(kind="blade", prof="ovate", W=0.52)
    elif lf == "lance": sp.update(kind="blade", prof="lance", W=0.26, veins=9)
    elif lf == "needle": sp.update(kind="needles")
    elif lf == "round": sp.update(kind="round", R=30)
    elif lf == "heart": sp.update(kind="heart", R=29)
    elif lf == "tooth": sp.update(kind="blade", prof="elliptic", W=0.56, teeth=20, td=0.08)
    elif lf == "cut": sp.update(kind="blade", prof="obovate", W=0.5, cut=0.62, cutn=4, teeth=26, td=0.06)
    elif lf == "lobed": sp.update(kind="lobed", R=30, teeth=40, td=0.04)
    elif lf == "fern": sp.update(kind="fern")
    elif lf == "compound":
        sp.update(kind="pinnate", pairs=3, ll=24, lW=0.5, teeth=0 if h in ("climb",) or s.get("fruit", ("", ""))[0] == "pod" else 14)
        if h == "climb":
            sp.update(tendril=True, stipule=True, terminal=False, pairs=2, ll=26, lW=0.62, prof="elliptic")
    elif lf == "trefoil": sp.update(kind="trefoil", teeth=0)
    elif lf == "palm": sp.update(kind="palmate")
    elif lf == "strap": sp.update(kind="strap", W=11)
    elif lf == "fan": sp.update(kind="fan")
    if h == "tree" and lf == "simple":
        sp.update(teeth=34, td=0.05)
    sp.update(LEAFX.get(slug, {}))
    return sp


def bloom_spec(slug, s):
    """The close-up flower for one kind, or None if it has none worth drawing."""
    if slug in BLOOMX and BLOOMX[slug] is None:
        return None
    h = s.get("habit"); fl = s.get("fl")
    if h == "hand":   # the ten drawn by hand: everything is in BLOOMX
        return dict(BLOOMX[slug])
    if h == "tree":
        if s.get("noflower"):
            return None
        sp = dict(kind="blossom", fc=s.get("fc", "white"))
    elif h == "cyclamen":
        sp = dict(kind="reflex", fc=s.get("fc", "pink"))
    elif not fl:
        return None
    else:
        kind = {"goblet": "cup", "bells": "bluebell", "nod": "nod", "crown": "crown", "iris": "iris", "stars": "stars",
                "spike": "spike"}.get(fl, fl)
        sp = dict(kind=kind, fc=s.get("fc", "white"), cen=s.get("cen", "sun"))
        if fl == "goblet": sp["cup"] = "crocus"
        if h == "bulb" and fl == "cup": sp["cup"] = "tulip"
        if kind == "cup" and "cup" not in sp: sp["cup"] = "poppy"
        if h == "trail" and fl == "flat" and s.get("crop") == "fruit":
            sp.update(kind="funnel", fruit=s["fruit"][1] if s["fruit"][0] != "round" else "unripe")
        if kind == "pea" and s.get("arr") == "spire": sp["spike"] = True
        if kind == "lip" and h == "mound" and s.get("arr") == "spire": sp["dense"] = True
    sp.update(BLOOMX.get(slug) or {})
    return sp


# Changes for single kinds. ⚠️ CHECK: all from Claude's knowledge, not a book.
LEAFX = {
    # the ten drawn by hand in plants.py
    "carrot": dict(kind="fern", fill="leaf"),
    "broad-bean": dict(kind="pinnate", fill="sage", pairs=2, ll=30, lW=0.5, prof="elliptic", terminal=False, teeth=0),
    "tomato": dict(kind="pinnate", fill="leaf", pairs=3, ll=24, lW=0.48, teeth=12, td=0.12, small=True),
    "lettuce": dict(kind="blade", fill="leaf", prof="obovate", W=0.78, teeth=24, td=0.05, veins=7),
    "leek": dict(kind="strap", fill="sage", W=13, sheath=True),
    "courgette": dict(kind="lobed", fill="leaf", R=31, lobes=5, cut=0.48, sharp=1.3, teeth=50, td=0.05, flecks=True),
    "sunflower": dict(kind="heart", fill="leaf", R=28, teeth=40, td=0.05, point=0.5),
    "strawberry": dict(kind="trefoil", fill="leaf", teeth=14, td=0.12, lW=0.64),
    "snowdrop": dict(kind="strap", fill="sage", W=7),
    "apple": dict(kind="blade", fill="leaf", prof="ovate", W=0.5, teeth=34, td=0.05),
    # roots
    "beetroot": dict(veinc="beet", stalkc="beet"), "radish": dict(cutn=3),
    "mangelwurzel": dict(stalkc="pale"),
    # herbs
    "dill": dict(thread=True), "wormwood": dict(fill="sage"),
    "thyme": dict(kind="sprig", nl=11, nw=0.42, fill="sage"), "oregano": dict(kind="sprig", nl=16, nw=0.7, prof="ovate"),
    "lavender": dict(kind="needles", n=9, nl=24, nw=0.12, spread=34, stemc="sage"),
    "rosemary": dict(kind="needles", n=16, nl=17, nw=0.13, spread=46, stemc="bark"),
    "hyssop": dict(kind="needles", n=10, nl=19, nw=0.18, spread=44, stemc="leaf"),
    "savory": dict(kind="needles", n=10, nl=16, nw=0.16, spread=40, stemc="bark"),
    "sage": dict(kind="blade", fill="sage", prof="elliptic", W=0.42, teeth=30, td=0.03, petiole=0.26),
    "bay": dict(kind="blade", prof="elliptic", W=0.34, teeth=14, td=0.02),
    "basil": dict(kind="blade", prof="ovate", W=0.62),
    "tarragon": dict(W=0.16, veins=0),
    "lady-s-bedstraw": dict(kind="whorls"),
    # leaves
    "good-king-henry": dict(kind="hastate", W=0.78, ear=0.08), "purple-orach": dict(kind="hastate", W=0.66, ear=0.1),
    "spinach": dict(kind="heart", point=0.2),
    "pak-choi": dict(kind="blade", prof="spoon", W=0.62, stalkc="white", petiole=0.04),
    "swiss-chard": dict(kind="blade", prof="ovate", W=0.62, stalkc="berry", veinc="berry"),
    "spinach-beet": dict(kind="blade", prof="ovate", W=0.62, stalkc="pale"),
    "celery": dict(kind="pinnate", stalkc="pale", pairs=2, ll=24, teeth=10, td=0.15),
    "rhubarb": dict(kind="heart", R=33, point=0.15, stalkc="berry", teeth=12, td=0.04, veinc="berry"),
    "cabbage": dict(kind="round", R=32, fill="sage"),
    "cauliflower": dict(kind="blade", prof="obovate", W=0.5, veins=9),
    "chicory": dict(cut=0.7, cutn=5, teeth=30, td=0.1),
    "lambs-lettuce": dict(prof="spoon", W=0.4),
    "cress": dict(kind="blade", prof="obovate", W=0.5, cut=0.7, cutn=3),
    "celtuce": dict(prof="lance", W=0.36),
    # alliums
    "onion": dict(W=10), "chives": dict(W=5, two=True), "garlic": dict(W=12, midw=1.0),
    "wild-garlic": dict(kind="blade", prof="elliptic", W=0.34, veins=0, petiole=0.28),
    "spring-onion": dict(W=8),
    # gourds and beans
    "squash": dict(kind="lobed", lobes=5, cut=0.25, sharp=1.0, flecks=False),
    "cucumber": dict(kind="lobed", lobes=5, cut=0.2, sharp=2.2), "melon": dict(kind="lobed", lobes=5, cut=0.14, sharp=2.0),
    "loofah": dict(kind="lobed", lobes=7, cut=0.3, sharp=1.2),
    "nasturtium": dict(kind="peltate"),
    "french-bean": dict(prof="ovate", lW=0.68, ll=40),
    "pea": dict(fill="sage"), "sweet-pea": dict(kind="pair"),
    "tufted-vetch": dict(kind="pinnate", pairs=7, ll=11, lW=0.3, prof="elliptic", tendril=True, terminal=False, teeth=0, spread=64),
    "meadow-vetchling": dict(kind="pair"),
    "clover": dict(chevron=True, prof="elliptic", lW=0.56, teeth=30, td=0.02),
    "red-clover": dict(chevron=True, prof="elliptic", lW=0.5),
    "alfalfa": dict(teeth=12, td=0.06, lW=0.42),
            "potatoes": dict(kind="pinnate", pairs=3, ll=22, lW=0.56, teeth=0, small=True),
    # flowers
    "sweet-william": dict(veins=0), "linum": dict(W=0.16, veins=0),
    "viola": dict(kind="heart", teeth=18, td=0.06, point=0.1),
    "russian-comfrey": dict(prof="lance", W=0.32, veins=8),
        "native-cowslip": dict(prof="obovate", W=0.52, teeth=16, td=0.05),
    "foxglove": dict(prof="lance", W=0.36, teeth=24, td=0.03),
    "blue-globe-thistle": dict(cutn=5, cut=0.7, teeth=40, td=0.22),
    "globe-artichoke": dict(cutn=5, cut=0.74, teeth=36, td=0.12),
    "marshmallow": dict(kind="lobed", lobes=3, cut=0.2, sharp=1.0, fill="sage"),
    "senecio-angel-wings": dict(kind="blade", prof="obovate", W=0.8, teeth=18, td=0.05),
    "geum": dict(kind="pinnate", pairs=2, ll=16, lW=0.6, teeth=10, td=0.12),
    "meadowsweet": dict(kind="pinnate", pairs=3, ll=22, lW=0.42, teeth=16, td=0.08),
    "hogweed": dict(kind="blade", prof="obovate", W=0.62, cut=0.6, cutn=3, teeth=24, td=0.08),
    "yarrow": dict(kind="fern", pinnae=8), "salvia": dict(prof="ovate", W=0.46, teeth=28, td=0.04),
    "aubrieta": dict(prof="obovate", W=0.5, teeth=8, td=0.08),
    "rock-sea-lavender": dict(prof="spoon", W=0.44),
    "selfheal": dict(prof="ovate", W=0.48),
    # bulbs
    "daffodil": dict(W=10, prof="linear"), "tulip": dict(W=18, prof="lance", two=True),
    "crocus": dict(W=5, stripe=True), "iris": dict(W=13, prof="lance", midw=0), "yellow-iris": dict(W=13, prof="lance", midw=0),
    "crown-imperial": dict(W=12, prof="lance"), "peacock-orchid": dict(W=10, prof="lance"),
        "cyclamen": dict(kind="heart", fill="deep", R=26, point=0.25, marbled=True, stalkc="beet"),
    # trees and fruit
    "pear": dict(prof="ovate", W=0.62, teeth=30, td=0.03), "plum": dict(prof="obovate", W=0.5),
    "olive-tree": dict(prof="lance", W=0.18, teeth=0, veins=0), "nectarine": dict(teeth=40, td=0.04),
    "bristol-whitebeam": dict(prof="ovate", W=0.62, teeth=18, td=0.1, veins=9),
    "fig": dict(lobes=5, cut=0.6, sharp=2.0, teeth=0, R=32),
    "blackcurrant": dict(lobes=5, cut=0.3, teeth=36, td=0.08), "whitecurrant": dict(lobes=5, cut=0.3, teeth=36, td=0.08),
    "gooseberry": dict(lobes=5, cut=0.34, teeth=20, td=0.12, R=26),
    "grape": dict(lobes=5, cut=0.36, teeth=36, td=0.08),     "blueberry": dict(prof="elliptic", W=0.46), "honeyberry": dict(prof="elliptic", W=0.5),
    "rose": dict(pairs=2, ll=24, lW=0.6, teeth=20, td=0.06), "raspberry": dict(pairs=2, ll=28, lW=0.58, teeth=22, td=0.08),
    "blackberry": dict(kind="palmate", n=5, spread=100, ll=34, lW=0.52, prof="ovate", teeth=22, td=0.08), "loganberry": dict(pairs=1, ll=30, lW=0.6, teeth=22, td=0.08),
    "japanese-wineberry": dict(pairs=1, ll=30, lW=0.66, teeth=22, td=0.08),   # all five changed again in the sweep of 15 November: see the foot of this list
    "hydrangea": dict(prof="ovate", W=0.56, teeth=24, td=0.05),     "asparagus": dict(kind="fern", thread=True, pinnae=7, fill="leaf"),
    # ---- put right in the accuracy check of 15 November 2026 (project doc 81)
    "african-daisy": dict(prof="obovate", W=0.34, teeth=6, td=0.12),
    "aubergine": dict(prof="ovate", W=0.62, teeth=5, td=0.14),
    "bristol-onion": dict(W=4),
    "calendula": dict(prof="obovate", W=0.34),
    "candy-cane-sorrel": dict(prof="linear", lW=0.15, ll=36, veins=0),
    "cat-nip": dict(kind="heart", R=27, teeth=22, td=0.08, point=0.4),
    "common-bird-s-foot-trefoil": dict(kind="trefoil", prof="obovate", lW=0.5, ll=30, basal=True),
    "common-valerian": dict(pairs=5, ll=17, lW=0.32, prof="lance", teeth=8, td=0.12),
    "fennel": dict(thread=True, fill="bark"),
    "french-marigold": dict(kind="pinnate", pairs=5, ll=15, lW=0.3, prof="lance", teeth=8, td=0.2, spread=62),
    "japanese-spiraea": dict(prof="lance", W=0.34, teeth=24, td=0.1, fill="pear"),
    "kiwi": dict(kind="blade", prof="ovate", W=0.62, teeth=40, td=0.05),
    "leaf-salad": dict(kind="blade", prof="obovate", W=0.78, teeth=24, td=0.05, veins=7, cut=0, cutn=0),
    "lungwort": dict(prof="ovate", W=0.46, spots="white"),
    "mizuna": dict(kind="blade", prof="lance", W=0.5, cut=0.82, cutn=6, teeth=40, td=0.2),
    "parsley": dict(kind="pinnate", pairs=2, ll=22, lW=0.7, prof="obovate", teeth=7, td=0.3),
    "perforate-st-john-s-wort": dict(prof="elliptic", W=0.34, veins=4, spots="pale", spotr=0.55),
    "poppy": dict(fill="leaf"),
    "sorrel": dict(kind="blade", prof="lance", W=0.34, veins=8, petiole=0.24),
    "sweetcorn": dict(W=17, prof="lance", midw=1.3),
    "winter-windflower": dict(kind="trefoil", fill="leaf", prof="obovate", lW=0.74, ll=36, teeth=5, td=0.42, veins=3),
    "yellow-rattle": dict(prof="lance", W=0.24, teeth=18, td=0.12),
    # ---- the sweep of 15 November 2026, evening (William: "they're smooth edged which real raspberry leaves aren't").
    # Every toothed leaf now shows its teeth (TMIN above). These are the kinds changed beyond that.
    "raspberry": dict(pairs=2, ll=27, lW=0.62, teeth=6, td=0.26, tk="double", termk=1.3, termW=0.66),
    "blackberry": dict(kind="palmate", n=5, spread=104, ll=37, lW=0.56, prof="ovate", teeth=8, td=0.2, tk="double"),
    "loganberry": dict(pairs=1, ll=31, lW=0.62, teeth=7, td=0.2, tk="double", termk=1.25),
    "japanese-wineberry": dict(pairs=1, ll=27, lW=0.7, teeth=6, td=0.2, tk="double", termk=1.55, termW=0.86, termprof="round"),
    "rose": dict(pairs=2, ll=24, lW=0.6, teeth=9, td=0.16, ears=True),
    "meadowsweet": dict(kind="pinnate", pairs=3, ll=22, lW=0.5, teeth=6, td=0.2, tk="double", small=True, termk=1.25, termW=0.8),
    "geum": dict(kind="pinnate", pairs=2, ll=13, lW=0.66, teeth=4, td=0.22, grow=True, termk=2.5, termW=0.86, termprof="round"),
    "hogweed": dict(kind="pinnate", pairs=2, ll=26, lW=0.74, prof="ovate", teeth=5, td=0.3, cut=0.34, cutn=2, termk=1.2, spread=64),
    "coriander": dict(kind="pinnate", pairs=1, ll=25, lW=0.92, prof="obovate", teeth=5, td=0.32, termk=1.2),
    "anise": dict(kind="pinnate", pairs=1, ll=24, lW=0.86, prof="obovate", teeth=6, td=0.26, termk=1.15),
    "lovage": dict(kind="pinnate", pairs=2, ll=26, lW=0.58, prof="obovate", teeth=4, td=0.34),
    "poppy": dict(fill="leaf", prof="lance", W=0.56, cut=0.8, cutn=5, teeth=30, td=0.16),
    "california-poppy": dict(narrow=True, pinnae=5), "corn-chamomile": dict(narrow=True),
    "cosmos": dict(thread=True), "wild-chamomile": dict(thread=True),
    "foxglove": dict(prof="lance", W=0.4, teeth=16, td=0.06, tk="round"),
    "lemon-balm": dict(kind="blade", prof="ovate", W=0.62, teeth=11, td=0.09, tk="round"),
    "native-cowslip": dict(prof="obovate", W=0.52, teeth=14, td=0.06, tk="round"),
    "salvia": dict(prof="ovate", W=0.46, teeth=18, td=0.05, tk="round"),
    "sage": dict(kind="blade", fill="sage", prof="elliptic", W=0.42, teeth=30, td=0.03, petiole=0.26, tk="round", tmin=0.8),
    "bay": dict(kind="blade", prof="elliptic", W=0.34, teeth=7, td=0.035, tk="wave"),
    "clover": dict(chevron=True, prof="elliptic", lW=0.56, teeth=30, td=0.02, tmin=0.7),
    "pear": dict(prof="ovate", W=0.62, teeth=30, td=0.03, tmin=0.9), "nectarine": dict(teeth=40, td=0.04, tmin=1.0),
    "marshmallow": dict(kind="lobed", lobes=3, cut=0.2, sharp=1.0, fill="sage", teeth=26, td=0.07),    # ---- redrawn 15 November 2026, 20:40 (project doc 109): asparagus has tufts of needles, cress a cut leaf
    "asparagus": dict(kind="whorls", fill="leaf"),
    "cress": dict(kind="pinnate", pairs=3, ll=16, lW=0.34, prof="lance", teeth=6, td=0.2),
}

BLOOMX = {
    "carrot": dict(kind="umbel", fc="white", bracts=True, purple=True),
    "broad-bean": dict(kind="pea", fc="white", cen="dark"),
    "tomato": dict(kind="star", fc="primrose", cen="sun"),
    "lettuce": dict(kind="daisy", fc="primrose", lig=True, rays=16, R=26),
    "leek": dict(kind="globe", fc="white"),
    "courgette": dict(kind="funnel", fc="sun", fruit="marrow"),
    "sunflower": dict(kind="daisy", fc="sun", cen="dark", rays=24, R=34, disc=0.42),
    "strawberry": dict(kind="flat", fc="white", cen="primrose", receptacle=True),
    "snowdrop": dict(kind="snowdrop", fc="white"),
    "apple": dict(kind="blossom", fc="white", tinge="pink", anth="primrose"),
    # the rest
    "pear": dict(anth="beet"), "plum": dict(anth="primrose"), "nectarine": dict(fc="pink", anth="rust"),
    "bristol-whitebeam": dict(kind="tiny", fc="white", n=5, cen="primrose"),
    "olive-tree": dict(kind="tiny", fc="white", n=4, cen="primrose"), "bay": dict(kind="tiny", fc="primrose", n=4, cen="sun"),
    "fig": dict(kind="fig"),
    "parsnip": dict(bracts=False), "dill": dict(rays=11), "coriander": dict(fc="white"), "hogweed": dict(R=36),
        "chicory": dict(lig=True, rays=18), "salsify": dict(lig=True, rays=16), "scorzonera": dict(lig=True, rays=16),
    "celtuce": dict(lig=True, rays=14), "rudbeckia": dict(disc=0.34, rays=14, rw=0.28),
    "calendula": dict(rows=2, rays=20, disc=0.26), "french-marigold": dict(rows=2, rays=12, rw=0.36, disc=0.22),
    "zinnia": dict(rows=2, rays=16, rw=0.26, disc=0.22), "aster": dict(rays=30, rw=0.12, disc=0.24),
    "corn-chamomile": dict(disc=0.36, rays=16), "feverfew": dict(disc=0.4, rays=12, rw=0.3),
    "helipterum-rosum": dict(rays=26, rw=0.16, disc=0.3),
        "cornflower": dict(kind="tuft", style="funnel", fringe=True), "globe-artichoke": dict(kind="tuft", style="brush", big=True, bractc="sage"),
        "clover": dict(kind="clover"), "red-clover": dict(kind="clover"),
    "blue-globe-thistle": dict(kind="spiky"),
        "wild-garlic": dict(kind="globe", loose=True, cen="primrose"), "chives": dict(n=40, R=24),
    "poppy": dict(blotch="dark", cen="dark"), "california-poppy": dict(cup="eschscholzia", cen="amber"),
    "candy-cane-sorrel": dict(kind="flat", fc="white", edge="berry", cen="primrose", sepals=False, bud=False),
    "tulip": dict(cup="tulip"), "crocus": dict(feather="plum"),
    "foxglove": dict(L=30, W=16, spots="plum", lean=10, nodes=[(0.38, 1, 1.0), (0.56, 1, 0.88), (0.74, 1, 0.74)]),
    "russian-comfrey": dict(L=18, W=10), "lungwort": dict(L=18, W=10, mix="blue"),
    "native-cowslip": dict(umbel=True, L=20, W=11, spots="carrot"),
    "blueberry": dict(urn=True, fc="white", L=16, W=12), "honeyberry": dict(L=20, W=9),
    "asparagus": dict(kind="bell", fc="primrose", L=12, W=8),
    "lavender": dict(dense=True), "rosemary": dict(kind="lip", dense=False),
    "sage": dict(kind="lip", dense=False), "mint": dict(kind="lip", dense=True), "oregano": dict(n=4),
    "common-bird-s-foot-trefoil": dict(head=True), "lupin": dict(spike=True, keel="white"),
    "tufted-vetch": dict(spike=True), "alfalfa": dict(kind="pea", spike=True, fc="lilac"),
    "meadowsweet": dict(kind="plume"), "rhubarb": dict(kind="plume", fc="white"),
    "sweetcorn": dict(kind="plume", tassel=True, fc="straw"),
    "borage": dict(scales=True, cen="dark"), "aubergine": dict(cen="sun"), "potatoes": dict(cen="sun"),
    "tomatillo": dict(kind="flat", fc="primrose", cen="plum", prof="round", pw=1.1, sepals=True),
    "chinese-lanterns": dict(kind="flat", fc="white", cen="primrose", pw=1.0),
    "nasturtium": dict(kind="flat", fc="carrot", cen="sun", blotch="berry", pw=1.0),
    "kiwi": dict(kind="flat", fc="white", cen="primrose", ns=28, anth="dark", pw=0.9),
    "grape": dict(kind="tiny", fc="unripe", n=5, cen="primrose"),
    "rose": dict(kind="flat", fc="pink", cen="primrose", ns=28, pw=1.05),
    "raspberry": dict(kind="flat", fc="white", cen="unripe", pw=0.55, ns=24), "blackberry": dict(kind="flat", pw=0.8, ns=24, cen="unripe"),
    "loganberry": dict(kind="flat", pw=0.75, ns=24, cen="unripe"), "japanese-wineberry": dict(kind="flat", pw=0.6, ns=22, cen="unripe"),
    "blackcurrant": dict(kind="bell", fc="unripe", L=10, W=7, nodes=[(0.4, 1, 1.0), (0.5, -1, 0.95), (0.6, 1, 0.9), (0.7, -1, 0.85), (0.8, 1, 0.8)]),
    "whitecurrant": dict(kind="bell", fc="unripe", L=10, W=7, nodes=[(0.4, 1, 1.0), (0.5, -1, 0.95), (0.6, 1, 0.9), (0.7, -1, 0.85), (0.8, 1, 0.8)]),
    "gooseberry": dict(kind="bell", fc="unripe", L=12, W=9, mix="beet"),
    "marshmallow": dict(kind="flat", fc="pink", cen="white", pw=0.9),         "perforate-st-john-s-wort": dict(kind="flat", fc="sun", cen="sun", ns=40, pw=0.62),
    "aubrieta": dict(R=26),
    "japanese-spiraea": dict(kind="tiny", n=5),
    "peacock-orchid": dict(cen="plum"), "puschkinia": dict(kind="six", fc="white", stripe="blue", anth="sun"),
    "tarragon": None, "shallot": None, "senecio-angel-wings": None,
    # ---- put right in the accuracy check of 15 November 2026 (project doc 81)
    "african-daisy": dict(rays=18, rw=0.2, fc="pink"),
    "cat-nip": dict(fc="white", calyx="sage"),
    "chilli-pepper": dict(kind="star", fc="white", pw=0.42, cen="lilac"),
    "cosmos": dict(kind="daisy", rays=8, rw=0.5, disc=0.2, cen="sun"),
    "devil-s-bit-scabious": dict(kind="pin", even=True),
    "geum": dict(kind="flat", pw=0.95, fc="berry"),
    "grape-hyacinth": dict(topc="white"),
    "hydrangea": dict(kind="mop", lacecap=True),
    "hyssop": dict(dense=True, fc="pink"),
    "iris": dict(fc="plum"),
    "lady-s-bedstraw": dict(n=4),
    "leaf-salad": dict(kind="daisy", fc="primrose", lig=True, rays=16, R=26),
    "lemon-balm": dict(kind="lip", fc="white", calyx="leaf"),
    "linum": dict(kind="flat", pw=0.8, fc="berry", cen="dark"),
    "oxford-rampion": dict(kind="horned"),
    "rocket-salad": dict(veins="plum"),
    "savory": dict(kind="lip", fc="white", calyx="leaf", dense=False),
    "scabiosa": dict(kind="pin", fc="pink"),
    "selfheal": dict(kind="lip", fc="plum", calyx="plum", dense=True),
    "thyme": dict(n=4),
    "viola": dict(kind="pansy", lipc="lilac"),
    "wild-chamomile": dict(kind="daisy", rayless=True),
    "winter-windflower": dict(kind="daisy", fc="pink", rays=14, rw=0.16, disc=0.2, rprof="elliptic", plain=True),
    "wormwood": dict(kind="tiny", button=True),
    "yarrow": dict(kind="tiny", fc="pink", n=5, cen="primrose"),
    "yellow-iris": dict(fc="sun"),
    # ---- the sweep of 15 November 2026, evening
    "raspberry": dict(kind="flat", fc="white", cen="unripe", pl=0.6, pw=0.5, prof="obovate", ns=30, sepl=0.8, sepw=0.22, sepc="sage"),
    "japanese-wineberry": dict(kind="flat", fc="pink", cen="unripe", pl=0.44, pw=0.6, prof="obovate", ns=22, sepl=0.98, sepw=0.26, sepc="beet", budc="beet"),
    "bristol-onion": dict(kind="globe", drum=True, topc="unripe"),
    # ---- put right in the photograph check of 15 November 2026 (project doc 107)
    # The goosefoot family and the docks carry tiny flowers up a branched spike, not in a flat-topped cluster.
    "beetroot": dict(kind="plume"), "mangelwurzel": dict(kind="plume"), "swiss-chard": dict(kind="plume"),
    "spinach-beet": dict(kind="plume"), "spinach": dict(kind="plume"), "good-king-henry": dict(kind="plume"),
    "purple-orach": dict(kind="plume"), "sorrel": dict(kind="plume"),    # ---- redrawn 15 November 2026, 20:40 (project doc 109)
    # Cucumber, melon and loofah: a flat yellow flower of five petals, not the courgette's big funnel.
    "cucumber": dict(kind="flat", fc="sun", cen="amber"), "melon": dict(kind="flat", fc="sun", cen="amber"),
    "loofah": dict(kind="flat", fc="primrose", cen="amber", R=33),
    "iris": dict(fc="plum", sig="white", veinc="white"),
    "yellow-iris": dict(fc="sun", sig="amber", veinc="rust", sl=22, sw=7, fw=24),
    "whitecurrant": dict(kind="string", fc="unripe"),
    "grape": dict(kind="plume", fc="unripe"), "rock-sea-lavender": dict(kind="plume", fc="lilac"),
    "chives": dict(n=40, R=24, fc="mauve"),
}


# ============================================================ and the files
def parts(slug, s):
    """The close-ups for one kind as (part, label, drawing function)."""
    out = []
    lsp = leaf_spec(slug, s)
    out.append(("leaf", "Leaf", lambda: LEAF_DRAW[lsp["kind"]](Art(), lsp)))
    bsp = bloom_spec(slug, s)
    if bsp:
        lab = "Flowers, inside the fig" if bsp["kind"] == "fig" else ("Blossom" if bsp["kind"] == "blossom" else "Flower")
        out.append(("bloom", lab, lambda: BLOOM_DRAW[bsp["kind"]](Art(), bsp)))
    return out


def all_kinds():
    """(slug, name, settings) for every kind: the ten from plants.py get
    settings of their own here."""
    ten = {slug: name for slug, name, _ in PA.S10.PLANTS}
    out = [(slug, name, dict(habit="hand")) for slug, name in ten.items()]
    out += [(slug, name, s) for slug, name, s, _ in PA.KINDS]
    return sorted(out, key=lambda k: k[1].lower())


def sheet(kinds, mode, cell=110, per_row=4):
    bg, card, ink, soft = [("#F8F1E5", "#FFFCF6", "#15271D", "#3A5549"), ("#0C1C14", "#142414", "#F1EADB", "#A7B5A5")][mode]
    pad, head, lab = 12, 22, 18
    colw = 2 * cell + pad
    W = pad + per_row * (colw + 2 * pad); rows = (len(kinds) + per_row - 1) // per_row
    rowh = head + cell + lab + 10; H = pad + rows * rowh + pad
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">', f'<rect width="{W}" height="{H}" fill="{bg}"/>']
    for i, (slug, name, s) in enumerate(kinds):
        x0 = pad + (i % per_row) * (colw + 2 * pad); y0 = pad + (i // per_row) * rowh
        out.append(f'<text x="{x0}" y="{y0 + 16}" font-family="Georgia, serif" font-size="15" fill="{ink}">{name.replace("&", "and")}</text>')
        for j, (pt, lb, fn) in enumerate(parts(slug, s)):
            x = x0 + j * (cell + pad); y = y0 + head
            out.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="11" fill="{card}"/>')
            out.append(f'<g transform="translate({x},{y}) scale({cell / 100})" stroke-linecap="round" stroke-linejoin="round">{fn().body(mode)}</g>')
            out.append(f'<text x="{x + cell / 2}" y="{y + cell + 13}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="10" fill="{soft}">{lb}</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out_parts"
    kinds = all_kinds(); n = 0
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
    if only:
        kinds = [k for k in kinds if k[0] in only]
    for mode, look in enumerate(("light", "dark")):
        os.makedirs(os.path.join(out, look), exist_ok=True)
        for slug, name, s in kinds:
            for pt, lb, fn in parts(slug, s):
                with open(os.path.join(out, look, f"plant-{slug}-{pt}.svg"), "w", encoding="utf-8") as fh:
                    fh.write(fn().svg(mode)); n += 1
        per = 32
        for i in range(0, len(kinds), per):
            with open(os.path.join(out, f"parts-{look}-{i // per + 1:02d}.svg"), "w", encoding="utf-8") as fh:
                fh.write(sheet(kinds[i:i + per], mode))
    index = {"kinds": [{"slug": slug, "name": name, "parts": [{"part": pt, "label": lb} for pt, lb, _ in parts(slug, s)]}
                       for slug, name, s in kinds]}
    with open(os.path.join(out, "plant-parts.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, indent=1, ensure_ascii=False)
    print(len(kinds), "kinds,", n // 2, "close-ups, each in light and dark, written to", out)
