"""Windfall plant drawings, the redraw of 16 November 2026: the DAISIES group.

William, this file holds every change to the drawings of 19 plants: sunflower,
calendula, cosmos, zinnia, rudbeckia, French marigold, ox-eye daisy, corn
chamomile, wild chamomile (pineappleweed), feverfew, aster, African daisy,
Helipterum, cornflower, blue globe thistle, scabious (Scabiosa), devil's-bit
scabious, Oxford rampion and Senecio 'Angel Wings'. Each drawing was checked
against the plant's written description (Design/Plants/descriptions/<kind>.json)
and photographs of the real plant.

What was wrong before: these plants were built from one "daisy" template.
Almost every leaf was the same plain pointed leaf, every flower the same
ring of square-ended petals, every plant the same fan of stems, and every
seed the same grey-green sliver. So a cornflower, an aster and a feverfew
looked like the same plant in different colours.

So every drawing of every kind is now made here, in four steps.

1. LEAVES. One function per kind (lf_sunflower, lf_feverfew and so on)
   draws that plant's own leaf at any size. The close-up uses it large and
   the life stages use it small, so the two always agree. Outlines are
   built in three ways:
   - simple_edges(): a plain leaf, its width along its length set by a
     "profile" (prof()). "cord" pulls the base back past the stalk, which
     gives a heart-shaped base or ears that clasp the stem.
   - polar_edges(): a broad leaf drawn round a centre (the sunflower's
     heart shape with its sharp tip).
   - lobed_edges(): a leaf cut into lobes down both sides (feverfew, globe
     thistle, scabious). Each lobe is a bump on the edge; the whole edge is
     then leant forwards ("sheared") so the lobes point to the tip.
   serrate() then cuts teeth into any edge: sharp, rounded, wavy or spiny.
   Feathery leaves (cosmos, pineappleweed, corn chamomile, French marigold)
   are built from a midrib with segments along it; thread() draws a segment
   too thin to fill as a dark line with a green line on top.

2. FLOWERS. head() draws any daisy head from any angle. It works out every
   point on the flat face of the head, then tilts and turns it (view()),
   so the same settings give a face-on close-up or a small head seen from
   the side on the whole plant. Its settings for each kind are in HEADS:
   how many rays, their shape (ray_pts(): square-tipped with teeth, wedge,
   rounded, pointed, narrow, or a papery bract), how many rows (a double
   calendula), the disc (flat, domed or a tall cone, with yellow star
   florets round its edge), the cup of bracts underneath, a frill of short
   rays (semi-double cosmos), a coloured edge (cosmos picotee) or a blotch
   (French marigold). bud_side() draws a bud from the side, so the bracts
   the descriptions ask for can be seen. The heads that are not daisies
   have their own: cornflower_head() (jagged funnels on a scaly cup),
   globe_ball() (a ball of tiny star florets), pincushion() (scabious),
   ball_head() (devil's-bit), rampion_head() (claws and horns) and
   cone_head() (pineappleweed, which has no rays at all).

3. LIFE STAGES. Every stage is drawn by hand (the STAGE table) from a few
   helpers: seedling() (roots, stem, two seed leaves and the first true
   leaves), shoot() (a stem with its leaves, alternate or in pairs),
   _bush() (several stems from one base), rosette() and the heads above.
   Each kind's seed has its own drawing (SEEDS), from the sunflower's
   striped tear-drop to the scabious's shuttlecock.

4. COLOURS. Eight new ones, asked for in the descriptions ("palette_wish"):
   daisies_picotee (cosmos edge), daisies_raspberry (zinnia), daisies_navy
   (African daisy centre), daisies_cornblue (cornflower), daisies_steel
   (globe thistle), daisies_violet (devil's-bit), daisies_rampion (Oxford
   rampion) and daisies_silver (Senecio leaves). Each has a light and a
   dark-mode value, and the descriptions' palettes now name them.

What could not be put fully right is listed, with why, in the results file
that went with this work.
"""
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
    "daisies_scabious":  ("#E07BAE", "#E08DBA"),   # Scabiosa 'Kudo Pink': bright pink
    "daisies_aster":     ("#D98AC4", "#C982B8"),   # dwarf Michaelmas daisy 'Pink': lilac-pink, strong enough to read small
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


def width_of(edge, L):
    """The half width of a leaf at any share of its length, read off one edge."""
    def hw(u, sd=1):
        x = u * L; best = 0.0
        for (x0, y0), (x1, y1) in zip(edge, edge[1:]):
            if (x0 - x) * (x1 - x) <= 0 and x1 != x0:
                best = max(best, abs(y0 + (y1 - y0) * (x - x0) / (x1 - x0)))
        return best
    return hw


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
    if w0 < 1.5:   # at life-stage size: a thin outlined stalk, not a dark bar
        thread(a, qpts((x, y), t(ln * 0.5, ln * bend), t(ln), 4), fill, max(0.45, w0 - 0.35), 0.45)
    else:
        a.ribbon((x, y), t(ln * 0.5, ln * bend), t(ln), w0, w1, fill, lw=0.8 if w0 < 2 else 0.9)
    return t(ln)


def lf_sunflower(a, x, y, ang, L, fill, small=False, bend=0.0):
    """Broad heart-shaped leaf with a sharp tip, coarse forward teeth all
    round, three big veins from the base, on a long stalk. bend turns the
    blade on its stalk (a leaf hanging down)."""
    pet = 0.34 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, max(0.9, L * 0.034), max(0.7, L * 0.026), fill, 0.03)
    R = BL * 0.36
    g = lambda h: (1 + 0.12 * math.cos(h) ** 2) * (1 + 0.6 * math.exp(-abs(h) / 0.24)) * notch(0.88, 0.42)(h)
    top, bot = polar_edges(R, g)
    BL = top[-1][0]
    sp = max(1.7, BL * 0.07); dp = max(0.7, BL * 0.028)
    top = serrate(top, 1, sp, dp, "saw", BL, -1, 0.95, irr=0.35); bot = serrate(bot, -1, sp, dp, "saw", BL, -1, 0.95, irr=0.35)
    top, bot = [(0, 0)] + top, [(0, 0)] + bot
    main, veins = [], []
    if not small or L > 12:   # the midrib and two strong veins, all three from the top of the stalk
        for sd in (1, -1):
            main.append([(0, 0), (0.08 * BL, sd * 0.16 * BL), (0.3 * BL, sd * 0.3 * BL), (0.62 * BL, sd * 0.26 * BL)])
        if not small:
            hw = width_of(top, BL)
            for u in (0.62, 0.76):
                for sd in (1, -1):
                    veins.append([(u * BL - 0.1 * BL, 0), (u * BL - 0.04 * BL, sd * hw(u) * 0.4), (u * BL + 0.02 * BL, sd * hw(u) * 0.78)])
            for sd in (1, -1):   # smaller veins running out from the outer side of each big vein
                for v in (0.12, 0.24, 0.38):
                    p = (v * BL, sd * (0.18 + 0.5 * v) * BL)
                    veins.append([p, (p[0] - 0.02 * BL, p[1] + sd * 0.1 * BL)])
    mp = draw_leaf(a, A[0], A[1], ang + bend, top, bot, fill, _lw(L), veins=veins, mid=[(0, 0), (0.5 * BL, 0), (0.92 * BL, 0)],
                   midw=1.1 if not small else 0.6, vw=0.5, va=0.32)
    for v in main:
        a.line(opath([mp(p) for p in qpts(v[0], v[1], v[2], 5)] + [mp(v[3])]), 1.1 if not small else 0.55, 0.55)


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
            subs = (0.22, 0.36, 0.5, 0.64, 0.78) if not small else (0.35, 0.65)
            for j, v in enumerate(subs):   # fine segments set singly along the pinna, first one side then the other
                b = tp(l * v, -sd * l * 0.12 * v * (1 - v))
                sd2 = 1 if j % 2 else -1
                sl = l * 0.42 * (1.15 - v * 0.7)
                e = T(*b, pa + sd2 * 40)(sl); m = T(*b, pa + sd2 * 34)(sl * 0.5)
                thread(a, [b, m, e], fill, w * 0.85, ow)
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
        hairs(a, x, y, ang, top[2:-2], 1.1, 1.7, la=0.8, lw=0.45)
        hairs(a, x, y, ang, bot[2:-2], 1.1, 1.7, la=0.8, lw=0.45)
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
    top, bot = simple_edges(l, l * (0.26 if not small else 0.36), pf, n=90)
    if not small:
        sp = max(0.9, l * 0.1); dp = max(0.45, l * 0.04)
        top = serrate(top, 1, sp, dp, "saw", l, 0.12, 0.92); bot = serrate(bot, -1, sp, dp, "saw", l, 0.12, 0.92)
    draw_leaf(a, x, y, ang, top, bot, fill, 0.8 if not small else 0.45, shade=0.1 if not small else 0,
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
    for i in range(4):   # each lobe cut almost to the midrib, and lobed again
        u = 0.1 + 0.2 * i; ln = BL * (0.26 - 0.035 * i)
        for sd, du in ((1, 0), (-1, 0.03)):
            if small:
                lobes.append((u + du, 0.06, ln, "round", sd))
            else:
                lobes += [(u + du - 0.035, 0.032, ln * 0.62, "round", sd), (u + du, 0.04, ln, "round", sd), (u + du + 0.032, 0.03, ln * 0.7, "round", sd)]
    lobes += [(0.86, 0.04, BL * 0.1, "round", 1), (0.86, 0.04, BL * 0.1, "round", -1), (0.93, 0.06, BL * 0.08, "round", 1), (0.93, 0.06, BL * 0.08, "round", -1)]
    wing = lambda u: BL * 0.022 * (1 - u * 0.3)
    top, bot, hw = lobed_edges(BL, wing, lobes, shear=0.42)
    if not small:
        sp = max(1.3, BL * 0.035); dp = max(0.5, BL * 0.012)
        msk = lambda px, py: 1.0 if abs(py) > BL * 0.06 else 0.0
        top = serrate(top, 1, sp, dp, "round", BL * 1.1, 0.0, 1.2, msk); bot = serrate(bot, -1, sp, dp, "round", BL * 1.1, 0.0, 1.2, msk)
    main = [lb for lb in lobes if lb[2] >= BL * 0.15]
    veins = [[(lb[0] * BL - 0.04 * BL, 0), (lb[0] * BL + 0.5 * 0.42 * lb[2], lb[4] * lb[2] * 0.5), (lb[0] * BL + 0.85 * 0.42 * lb[2], lb[4] * lb[2] * 0.85)]
             for lb in main] if not small else []
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L) if not small else 0.5, veins=veins, mid=[(0, 0), (0.5 * BL, 0), (0.92 * BL, 0)],
              midw=0.9 if not small else 0.4, va=0.3, shade=0.1 if not small else 0.06)


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
        top, bot = simple_edges(L, max(2.0 if small else 1.4, L * (0.12 if small else 0.085)), pf, n=80)
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
        u = 0.1 + 0.62 * i / (n - 1); ln = BL * ((0.24 if not fine else 0.22) - 0.04 * i / (n - 1))
        sp = 0.04 if not fine else 0.03
        lobes += [(u, sp, ln, "round" if not fine else "point", 1), (u + 0.04, sp, ln * 0.94, "round" if not fine else "point", -1)]
    wing = lambda u: BL * (0.02 if not fine else 0.016) + BL * 0.075 * max(0, min(1, (u - 0.72) / 0.1)) * min(1, (1 - u) / 0.22) ** 0.7 * (1 if not fine else 0.4)
    top, bot, hw = lobed_edges(BL, wing, lobes, shear=0.55)
    if not small and not fine:
        msk = lambda px, py: 1.0 if abs(py) > BL * 0.05 else 0.0
        top = serrate(top, 1, 2.2, 0.8, "saw", BL * 1.1, 0.0, 1.2, msk); bot = serrate(bot, -1, 2.2, 0.8, "saw", BL * 1.1, 0.0, 1.2, msk)
    veins = [[(lb[0] * BL - 0.02 * BL, 0), (tp_[0] * 0.85 + lb[0] * BL * 0.15, tp_[1] * 0.8)] for tp_, lb in zip(lobe_tips(BL, lobes, 0.55), lobes)] if not (small or fine) else []
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L) * (0.85 if fine else 1), veins=veins, va=0.3,
              mid=[(0, 0), (0.5 * BL, 0), (0.92 * BL, 0)] if not small else None, midw=0.8)
    if not small and not fine:
        t = T(*A, ang)
        hairs(a, A[0], A[1], ang, [p for p in top if abs(p[1]) > 1.5][::2], 1.3, 0.9, la=0.55)
        hairs(a, A[0], A[1], ang, [p for p in bot if abs(p[1]) > 1.5][::2], 1.3, 0.9, la=0.55)


def lf_devilsbit(a, x, y, ang, L, fill, small=False, stem=False):
    """Basal leaf: undivided, oblong to elliptic, narrowing into a short
    winged stalk, smooth-edged, a strong pale midrib, purple at the edge.
    stem=True: a small narrow stem leaf."""
    if stem:
        pf = prof(0.4, "wedge", "point", bp=0.7, tp=0.8, b0=0.1); W = 0.18 * L
    else:
        pf = prof(0.55, "taper", "blunt", bp=1.5, tp=2.6, b0=0.05); W = 0.34 * L
    top, bot = simple_edges(L, W, pf)
    hw = lambda u, sd: pf(u) * W / 2
    veins = side_veins(L, hw, (0.4, 0.56, 0.7, 0.82), 0.75, 0.18) if not (small or stem) else []
    mp = draw_leaf(a, x, y, ang, top, bot, fill, _lw(L), veins=veins, va=0.25, mid=[(0, 0), (0.5 * L, 0), (0.92 * L, 0)],
                   midw=1.5 if not small else 0.6, midc="pale" if not small else "line", mida=1.0 if not small else 0.45)
    if not stem:   # a purple flush along the edge
        for e in (top, bot):
            a.line(opath([mp((px, py * 0.92)) for px, py in e[int(len(e) * 0.2):-2]]), 1.8 if not small else 1.0, 0.85, "beet")
        a.shape(path([mp(p) for p in top] + [mp(p) for p in bot[::-1]]), None, _lw(L))


def lf_rampion(a, x, y, ang, L, fill, small=False, stem=False):
    """Basal leaf: oval to heart-shaped, on a long thin stalk, the edge with
    small shallow uneven teeth, smooth and a little glossy. stem=True: a
    narrow, almost grass-like stem leaf."""
    if stem:
        return lf_aster(a, x, y, ang, L, fill, small)
    pet = 0.5 * L
    A = stalk_to(a, x, y, ang, pet, max(0.7, L * 0.02), max(0.55, L * 0.016), fill, 0.04)
    R = (L - pet) * 0.46
    g = lambda h: (1 + 0.06 * math.cos(h)) * (1 + 0.32 * math.exp(-abs(h) / 0.3)) * notch(0.72, 0.5)(h)
    top, bot = polar_edges(R, g)
    BL = top[-1][0]
    if not small:
        top = serrate(top, 1, 2.6, 0.55, "round", BL, -1, 0.95, irr=0.4); bot = serrate(bot, -1, 2.6, 0.55, "round", BL, -1, 0.95, irr=0.4)
    top, bot = [(0, 0)] + top, [(0, 0)] + bot
    veins = []
    if not small:
        for sd in (1, -1):
            veins.append([(0, 0), (0.12 * BL, sd * 0.2 * BL), (0.4 * BL, sd * 0.3 * BL), (0.7 * BL, sd * 0.2 * BL)])
        veins += side_veins(BL, width_of(top, BL), (0.6, 0.76), 0.7, 0.12)
    mp = draw_leaf(a, A[0], A[1], ang, top, bot, fill, _lw(L), veins=veins, va=0.25, mid=[(0, 0), (0.5 * BL, 0), (0.9 * BL, 0)], midw=0.8 if not small else 0.45)
    if not small:
        a.line(opath([mp((BL * u, width_of(top, BL)(u) * 0.45)) for u in (0.3, 0.42, 0.54, 0.64)]), 1.3, 0.45, "white")


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
    stem_piece(a, (10, 81), (17, 88), (27, 98), 3.4, 3.0, sp["fill"])
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
    q = stem_piece(a, (80, 100), (82, 70), (88, 36), 1.6, 1.3, sp["fill"])
    with a.on(LEAF):
        lf_rampion(a, 14, 94, -56, 92, sp["fill"])
        x, y = q.pt(0.5); lf_rampion(a, x, y, -60, 26, sp["fill"], stem=True)
    return a


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


# ============================================================ flower heads
# A daisy "flower" is a head of many tiny flowers (florets): strap-shaped
# ray florets round the edge and tubular disc florets in the middle, on a
# cup of green bracts. head() draws one from any angle. Everything is first
# placed on the flat plane of the head (u across, v away from you, and z
# standing up out of the face), then seen at a slant: k is how much the
# face is squashed (1 = straight on, 0.3 = nearly edge on), ang the way
# the face points on the page (-90 = up).

def view(x, y, k, ang):
    s = math.sqrt(max(0.0, 1 - k * k)); r = math.radians(ang + 90); c, sn = math.cos(r), math.sin(r)

    def V(u, v, z=0.0):
        px, py = u, v * k - z * s
        return (x + px * c - py * sn, y + px * sn + py * c)
    return V


def ray_pts(L, W, shape="strap", teeth=3):
    """The outline of one ray (or bract), base at 0, tip at L, as points
    measured along it. shape: strap (square tip with small teeth), wedge
    (widening to a broad toothed tip), oblong (rounded tip), point (narrow
    oval with a sharp tip), narrow (thin strap), bract (a pointed scale)."""
    n = 26; notched = shape in ("strap", "wedge")
    hw = {"strap": lambda u: 0.5 + 0.5 * min(1, u / 0.22) ** 0.6,
          "wedge": lambda u: 0.22 + 0.78 * u ** 0.75,
          "oblong": lambda u: (0.45 + 0.55 * min(1, u / 0.22) ** 0.6) * (1 - (max(0, u - 0.72) / 0.28) ** 2.2) ** 0.5,
          "point": lambda u: math.sin(math.pi * min(1, u ** 0.8)) ** 0.75,
          "narrow": lambda u: (0.55 + 0.45 * min(1, u / 0.18)) * (1 - (max(0, u - 0.8) / 0.2) ** 1.6) ** 0.6,
          "bract": lambda u: math.sin(math.pi * min(1, u ** 0.62)) ** 0.9}[shape]
    end = 0.965 if notched else 1.0
    us = [end * i / n for i in range(n + 1)]
    top = [(L * u, hw(u) * W / 2) for u in us]; bot = [(L * u, -hw(u) * W / 2) for u in us]
    tip = []
    if notched:
        w = hw(end) * W / 2; m = 2 * teeth
        for j in range(1, m):
            yy = w * (1 - 2 * j / m)
            tip.append((L * (1.0 if j % 2 else end - 0.01), yy))
    return top + tip + bot[::-1]


def head(a, x, y, R, o, k=0.85, ang=-90, small=False):
    """One daisy head, R from the middle to the ray tips. o holds its
    settings (see the kinds' HEADS below)."""
    V = view(x, y, k, ang)
    lw = 0.7 if R > 12 else (0.5 if R > 6 else 0.4)
    rd = R * o.get("disc", 0.3); fc = o.get("rayc", "white")
    # the cup of bracts under the head, seen below the rays
    cup = o.get("cup")
    if cup and k < 0.97:
        rc = rd * cup.get("rc", 1.1); h = rd * cup.get("h", 0.8); col = cup.get("col", "leaf")
        rim = [V(rc * math.cos(t_), rc * math.sin(t_) * 0.999, -h * math.sin(t_) ** 1.2) for t_ in [math.pi * i / 30 for i in range(31)]]
        back = [V(rc * math.cos(t_), rc * math.sin(t_), 0) for t_ in [math.pi + math.pi * i / 30 for i in range(31)]]
        a.shape(path(rim + back), col, lw)
        if not small:
            rows = cup.get("rows", 2)
            for r_ in range(rows):
                dz = h * (0.25 + 0.6 * r_ / max(1, rows - 1)) if rows > 1 else h * 0.4
                m = cup.get("n", 7) - r_
                for j in range(m):
                    t_ = math.pi * (j + 0.5 + 0.5 * (r_ % 2)) / m
                    if not 0.08 < t_ < math.pi - 0.08:
                        continue
                    rr = rc * (1 - 0.35 * (dz / h) ** 2)
                    p = V(rr * math.cos(t_), rr * math.sin(t_), -dz)
                    sc = cup.get("scale", rc * 0.55)
                    tang = ang + (math.cos(t_)) * -35
                    pts = ray_pts(sc, sc * cup.get("sw", 0.7), cup.get("shape", "bract"))
                    tt = T(p[0], p[1], tang + 180)
                    q = [tt(px_, py_) for px_, py_ in pts]
                    a.shape(path(q), col, lw * 0.8)
                    if cup.get("edge"):
                        a.line(opath(q[2:-2]), lw * 1.6, 0.9, cup["edge"])
                        a.shape(path(q), None, lw * 0.8)
    # bracts lying in the plane behind the rays (sunflower's leafy tips)
    br = o.get("bracts")
    if br:
        nb = br.get("n", 16) if not small else max(8, br.get("n", 16) // 2)
        for j in range(nb):
            ph = 2 * math.pi * (j + br.get("off", 0.5)) / nb
            _plane_ray(a, V, ph, rd * 0.8, R * br.get("l", 0.3), R * br.get("w", 0.08), br.get("col", "leaf"), br.get("shape", "bract"), lw * 0.85)
    # the rays, row by row, the back ones first
    n = o.get("n", 16); rows = o.get("rows", 1); r0 = rd * o.get("r0", 0.9)
    if small and n:
        n = max(6, int(n * o.get("smallk", 0.6)))
    items = []
    for r_ in range(rows):
        for i in range(n):
            ph = 2 * math.pi * (i + 0.5 * r_) / n + o.get("start", 0.0) + 0.06 * math.sin(i * 2.3) * o.get("jit", 0)
            L = (R - r0) * (1 - o.get("rowstep", 0.15) * r_) * (1 + 0.04 * math.sin(i * 1.7) * o.get("jit", 0))
            items.append((r_, ph, L))
    items.sort(key=lambda it: (-it[0], math.sin(it[1])))
    for r_, ph, L in items:
        if math.sin(ph) < 0 or k > 0.9:
            _plane_ray(a, V, ph, r0, L, R * o.get("rw", 0.2), o.get("rowc", [fc] * 9)[r_], o.get("shape", "strap"), lw,
                       o.get("teeth", 3), o.get("droop", 0), o.get("picotee"), o.get("lines", 0) if not small else 0, o.get("blotch"))
    # inner frill (semi-double): short rays round the middle
    inn = o.get("inner")
    if inn:
        ni = inn.get("n", 12) if not small else max(5, inn.get("n", 12) // 2)
        for j in sorted(range(ni), key=lambda j: math.sin(2 * math.pi * j / ni)):
            ph = 2 * math.pi * (j + 0.3) / ni
            _plane_ray(a, V, ph, rd * 0.5, R * inn.get("l", 0.25), R * inn.get("w", 0.12), inn.get("cols", [inn.get("col", fc)])[j % len(inn.get("cols", [0]))], inn.get("shape", "strap"),
                       lw * 0.9, inn.get("teeth", 2), -inn.get("rise", 0.4), inn.get("picotee"))
    disc(a, V, rd, o, lw, small)
    for r_, ph, L in items:   # the front rays over the disc's lower edge
        if not (math.sin(ph) < 0 or k > 0.9):
            _plane_ray(a, V, ph, r0, L, R * o.get("rw", 0.2), o.get("rowc", [fc] * 9)[r_], o.get("shape", "strap"), lw,
                       o.get("teeth", 3), o.get("droop", 0), o.get("picotee"), o.get("lines", 0) if not small else 0, o.get("blotch"))
    rim = o.get("rim")
    if rim:   # the tips of the bracts behind, showing between the bases of the rays
        nr = rim.get("n", n)
        for j in range(nr):
            ph = 2 * math.pi * (j + rim.get("off", 0.5)) / nr + o.get("start", 0.0)
            if rim.get("front") and math.sin(ph) < 0.1:
                continue
            _plane_ray(a, V, ph, rd * rim.get("r0", 0.95), R * rim.get("l", 0.12), R * rim.get("w", 0.05), rim.get("col", "leaf"), "bract",
                       lw * 0.8, 3, rim.get("droop", 0.3))
    return V


def _plane_ray(a, V, ph, r0, L, W, fill, shape, lw, teeth=3, droop=0.0, picotee=None, lines=0, blotch=None):
    """One ray lying on the head's plane at angle ph, from r0 out, bending
    down by droop (or up, if droop is negative) as it goes."""
    c, s = math.cos(ph), math.sin(ph)
    def X(p):
        al, ac = p
        return V((r0 + al) * c - ac * s, (r0 + al) * s + ac * c, -droop * al * abs(al) / max(L, 0.1))
    pts = ray_pts(L, W, shape, teeth)
    q = [X(p) for p in pts]
    if W < 2.6:
        lw = min(lw, 0.45)
    a.shape(path(q), fill, lw)
    if blotch:   # a dark blotch at the base of the ray (French marigold)
        bq = [X(p) for p in ray_pts(L * 0.42, W * 0.7, "oblong")]
        a.shape(path(bq), blotch, 0, fa=0.85)
    if picotee:   # a coloured edge round the outer part of the ray
        n = len(pts); outer = [q[i] for i in range(n) if pts[i][0] > L * 0.62]
        a.line(opath(outer), max(0.6, W * 0.09), 0.95, picotee)
        for o_ in (-0.25, 0.1, 0.32):   # streaks running in from the edge
            a.line(opath([X((L * u, o_ * W)) for u in (0.78, 0.9)]), max(0.4, W * 0.04), 0.7, picotee)
        a.shape(path(q), None, lw)
    if lines:
        for o_ in ([0] if lines == 1 else [-0.28, 0, 0.28]):
            a.line(opath([X((L * u, o_ * W)) for u in (0.12, 0.45, 0.8)]), 0.4, 0.28)


def disc(a, V, rd, o, lw, small):
    """The disc: flat, domed or a raised cone, packed with tiny florets."""
    col = o.get("cen", "sun"); hd = rd * o.get("dome", 0.0)
    front = [V(rd * math.cos(t_), rd * math.sin(t_), 0) for t_ in [math.pi * i / 36 for i in range(37)]]
    backp = [V(rd * math.cos(t_), rd * math.sin(t_), hd * abs(math.sin(t_)) ** 0.8) for t_ in [math.pi + math.pi * i / 36 for i in range(37)]]
    a.shape(path(front + backp), col, lw * 1.1)
    if hd > rd * 0.15:   # a little shading on one side of a dome
        a.shape(path(front[18:] + [V(0, 0, hd)] + backp[:6]), "shade", 0, fa=0.12)
    dc = o.get("dots", "rust"); ring = o.get("ring")
    sp_ = o.get("spiral")
    if sp_:   # the florets in crossing spiral rows, as on a sunflower
        n1, n2 = (13, 21) if not small else (8, 13)
        for nn, sg in ((n1, 1), (n2, -1)):
            for j in range(nn):
                pts = []
                for i in range(9):
                    v = 0.14 + 0.86 * i / 8; th = 2 * math.pi * j / nn + sg * 2.4 * v
                    pts.append(V(rd * 0.96 * v * math.cos(th), rd * 0.96 * v * math.sin(th), hd * (1 - v * v)))
                a.line(opath(pts), 0.45 if not small else 0.3, 0.95, sp_)
    m = o.get("nd", int(14 + rd * rd * 1.1))
    if small:
        m = min(m, max(5, int(rd * rd * 0.7)), o.get("smalldots", 999))
    dr = o.get("dr", max(0.3, rd * 0.05))
    for j in range(m):
        rr = rd * 0.9 * math.sqrt((j + 0.5) / m); th = j * GOLD
        z = hd * (1 - (rr / rd) ** 2)
        p = V(rr * math.cos(th), rr * math.sin(th), z)
        if o.get("crest"):   # French marigold: a cushion of short frilly florets
            a.flower(p[0], p[1], rd * (0.27 if not small else 0.3), 5, o["rayc"], None, 1.0, start=th * 57, lw=lw * 0.6)
        elif ring and rr > rd * o.get("ringat", 0.68) and not small:
            a.flower(p[0], p[1], max(0.8, rd * o.get("rings", 0.1)), 5, ring, None, 0.6, start=th * 57, lw=0.3)
        else:
            a.dot(p[0], p[1], dr, ring if (ring and small and rr > rd * 0.6) else dc)


# How each kind's head is built (head() above). The colours come from the
# description's palette when the drawing is made (rayc, cen).
HEADS = {
    "sunflower": dict(n=17, rows=2, shape="point", rw=0.1, disc=0.42, dots="dark", spiral="bark", ring="sun", ringat=0.84, nd=140, dr=0.5,
                      rim=dict(n=34, l=0.17, w=0.065, col="leaf", r0=0.98, droop=0.1),
                      bracts=dict(n=17, l=0.5, w=0.13, col="leaf", off=0.25), cup=dict(rc=1.08, h=0.22, rows=2, n=10, col="leaf"),
                      jit=1, smallk=0.7),
    "calendula": dict(n=16, rows=3, rowstep=0.24, shape="strap", rw=0.18, teeth=3, disc=0.24, dots="amber", jit=1,
                      rim=dict(n=16, l=0.1, w=0.045, front=True, r0=1.0),
                      cup=dict(rc=1.25, h=0.7, rows=2, n=9, sw=0.32, col="leaf")),
    "cosmos": dict(n=8, rows=1, shape="wedge", rw=0.56, teeth=4, disc=0.13, dome=0.4, dots="amber", lines=3, r0=0.6, jit=1, smallk=1,
                   inner=dict(n=16, l=0.27, w=0.15, shape="wedge", rise=0.3, teeth=3), bracts=dict(n=8, l=0.3, w=0.05, col="leaf"),
                   cup=dict(rc=1.3, h=0.6, rows=1, n=6, sw=0.4, col="leaf")),
    "zinnia": dict(n=13, rows=1, shape="strap", rw=0.3, teeth=2, disc=0.25, dome=0.55, dots="rust", ring="sun", ringat=0.5, rings=0.17, nd=40, jit=1,
                   rim=dict(n=13, l=0.1, w=0.07, front=True, r0=1.0),
                   cup=dict(rc=1.35, h=0.9, rows=3, n=7, sw=0.9, shape="oblong", edge="dark", col="leaf"), smallk=0.8),
    "rudbeckia": dict(n=14, rows=1, shape="strap", rw=0.25, teeth=3, disc=0.3, dome=0.75, droop=0.22, dots="rust", nd=60, ring="sun", ringat=0.8,
                      rim=dict(n=14, l=0.12, w=0.06, front=True, r0=1.0, droop=0.5),
                      jit=1, cup=dict(rc=1.4, h=0.8, rows=2, n=8, sw=0.45, col="leaf"), smallk=0.8),
    "french-marigold": dict(n=8, rows=1, shape="oblong", rw=0.5, disc=0.4, dome=0.9, crest=True, nd=24, blotch="rust", jit=1, smallk=1),
    "ox-eye-daisy": dict(n=24, rows=1, shape="strap", rw=0.14, teeth=3, disc=0.28, dome=0.1, dots="amber", jit=1,
                         rim=dict(n=24, l=0.08, w=0.05, front=True, r0=1.0),
                         cup=dict(rc=1.15, h=0.6, rows=3, n=8, sw=0.75, shape="oblong", edge="bark", col="leaf"), smallk=0.55),
    "corn-chamomile": dict(n=16, rows=1, shape="strap", rw=0.16, teeth=2, disc=0.34, dome=0.7, dots="amber", jit=1,
                           cup=dict(rc=1.15, h=0.6, rows=2, n=8, sw=0.55, edge="white", col="sage"), smallk=0.6),
    "feverfew": dict(n=13, rows=1, shape="strap", rw=0.3, teeth=3, disc=0.48, dome=0.15, dots="amber", jit=1,
                     cup=dict(rc=1.05, h=0.5, rows=2, n=7, sw=0.55, edge="white", col="leaf"), smallk=0.7),
    "aster": dict(n=34, rows=1, shape="narrow", rw=0.075, disc=0.25, dots="amber", jit=1, smallk=0.5,
                  rim=dict(n=17, l=0.1, w=0.05, front=True, r0=1.0),
                  cup=dict(rc=1.2, h=0.7, rows=3, n=9, sw=0.32, col="leaf")),
    "african-daisy": dict(n=16, rows=1, shape="oblong", rw=0.2, disc=0.24, dots="sun", nd=26, dr=0.45, smalldots=4, lines=1, jit=1,
                          rim=dict(n=16, l=0.1, w=0.05, front=True, r0=1.0),
                          cup=dict(rc=1.2, h=0.6, rows=2, n=9, sw=0.35, col="leaf"), smallk=0.7),
    "helipterum-rosum": dict(n=13, rows=4, shape="bract", rw=0.2, disc=0.3, dots="amber", lines=1, jit=1, smallk=0.7,
                             cup=dict(rc=1.3, h=0.7, rows=2, n=8, sw=0.6, col="straw")),
}


def opts(kind, fc=None, cen=None, **over):
    o = dict(HEADS[kind])
    o["rayc"] = fc or pal(kind, "flower", "white"); o["cen"] = cen or pal(kind, "centre", "sun")
    if kind == "cosmos":
        o["picotee"] = pal(kind, "flower_edge", "daisies_picotee")
        o["inner"] = dict(o["inner"], col=o["rayc"], cols=[o["rayc"], "pink"], picotee=o["picotee"])
    if kind == "french-marigold":
        o["cen"] = o["rayc"]
    if kind == "calendula":   # the rows of a double head, the inner ones a little lighter, so the rows show
        o["rowc"] = [o["rayc"], "amber", o["rayc"]]
    if kind == "helipterum-rosum":
        o["rowc"] = [o["rayc"]] * 4
    o.update(over)
    return o


def stalk_line(a, p0, c, p1, w0, w1, fill="leaf", woolly=False, hairy=False):
    q = a.ribbon(p0, c, p1, w0, w1, fill, lw=0.85 if w0 > 1.5 else 0.6)
    if hairy:
        for i in range(14):
            u = 0.06 + 0.9 * i / 13; x, y = q.pt(u); an = q.ang(u) + (90 if i % 2 else -90)
            e = T(x, y, an - 30 * (1 if i % 2 else -1))(w0 * 0.5 + 1.0)
            b = T(x, y, an)(w0 * 0.45)
            a.line(f"M{P(b)} L{P(e)}", 0.35, 0.6)
    if woolly:
        for k in range(7):
            u = 0.08 + 0.12 * k; x, y = q.pt(u); x2, y2 = q.pt(u + 0.06)
            a.line(f"M{f(x - w0 * 0.3)},{f(y)} Q{f(x + w0 * 0.4)},{f((y + y2) / 2)} {f(x2 - w0 * 0.2)},{f(y2)}", 0.4, 0.8, "white")
    return q


# ============================================================ close-up flowers
def bud_side(a, x, y, r, kind, ang=-90, open_=0.0, fc=None, lw=0.6):
    """A bud from the side: a smooth rounded dome, the cup of bracts round
    its lower half (one row, each bract drawn plainly, with its dark or
    pale edge if it has one), and the rays' tips just showing at the top
    (open_ from 0, shut, to 1, about to open). x, y is where the stalk
    joins; the bud points along ang and is r long."""
    o = opts(kind, fc=fc)
    cup = o.get("cup") or dict(col="leaf")
    col = cup.get("col", "leaf"); t = T(x, y, ang)
    if open_ > 0:
        for j in range(5):
            a.leaf(*t(r * 0.5, (j - 2) * r * 0.12), ang + (j - 2) * 10, r * (0.45 + 0.55 * open_), 0.3, o["rayc"], lw=lw * 0.8, detail=False)
    body = [t(r * 0.48 + r * 0.5 * math.cos(h), r * 0.46 * math.sin(h)) for h in [2 * math.pi * i / 40 for i in range(40)]]
    a.shape(path(body), col, lw)
    a.shape(path(body[:21] + [t(r * 0.48, 0)]), "shade", 0, fa=0.1)
    shape = cup.get("shape", "bract")
    for j in (-1.5, 1.5, -0.5, 0.5):   # the outer bracts, overlapping round the foot of the bud
        p = t(r * 0.04, j * r * 0.24)
        sl = r * (0.7 if shape == "oblong" else 0.82)
        pts = ray_pts(sl, sl * (0.62 if shape == "oblong" else 0.36), shape)
        tt = T(p[0], p[1], ang + j * 14)
        q = [tt(*pp) for pp in pts]
        a.shape(path(q), col, lw * 0.85)
        if cup.get("edge"):
            a.line(opath([tt(*pp) for pp in pts if pp[0] > sl * 0.3]), lw * 2.0, 0.95, cup["edge"]); a.shape(path(q), None, lw * 0.85)


def bl_sunflower(a, sp):
    stalk_line(a, (60, 100), (58, 80), (52, 62), 4.4, 3.6, "leaf", hairy=True)
    head(a, 50, 42, 42, opts("sunflower", sp["fc"], sp.get("cen")), k=0.86)
    return a


def bl_calendula(a, sp):
    stalk_line(a, (54, 100), (54, 80), (50, 56), 3.0, 3.6, "leaf", hairy=True)   # the stalk thickens under the head
    stalk_line(a, (60, 100), (66, 86), (80, 76), 1.9, 1.6, "leaf")
    bud_side(a, 81, 72, 6, "calendula", -70, 0.4, sp["fc"])
    head(a, 48, 40, 34, opts("calendula", sp["fc"], sp.get("cen")), k=0.7)
    return a


def bl_cosmos(a, sp):
    stalk_line(a, (52, 100), (54, 76), (50, 56), 1.8, 1.6, "leaf")
    stalk_line(a, (62, 100), (70, 92), (82, 86), 1.4, 1.2, "leaf")
    bud_side(a, 82, 86, 9, "cosmos", -40, 0.0, sp["fc"])
    head(a, 46, 42, 38, opts("cosmos", sp["fc"], sp.get("cen")), k=0.78)
    return a


def bl_zinnia(a, sp):
    stalk_line(a, (54, 100), (54, 80), (50, 60), 2.8, 2.6, "leaf", hairy=True)
    stalk_line(a, (62, 100), (70, 88), (80, 80), 1.9, 1.7, "leaf")
    bud_side(a, 80, 80, 13, "zinnia", -62, 0.3, sp["fc"])
    head(a, 46, 40, 34, opts("zinnia", sp["fc"], sp.get("cen")), k=0.62)
    return a


def bl_rudbeckia(a, sp):
    stalk_line(a, (54, 100), (54, 80), (50, 58), 2.8, 2.4, "leaf", hairy=True)
    stalk_line(a, (62, 100), (70, 88), (80, 80), 1.9, 1.7, "leaf", hairy=True)
    bud_side(a, 80, 80, 12, "rudbeckia", -66, 0.35, sp["fc"])
    head(a, 46, 42, 36, opts("rudbeckia", sp["fc"], sp.get("cen")), k=0.62)
    return a


def bl_oxeye(a, sp):
    stalk_line(a, (54, 100), (54, 80), (50, 56), 2.2, 2.0, "leaf")
    stalk_line(a, (64, 100), (72, 90), (80, 82), 1.7, 1.5, "leaf")
    bud_side(a, 80, 82, 12, "ox-eye-daisy", -58, 0.25, sp["fc"])
    head(a, 46, 40, 36, opts("ox-eye-daisy", sp["fc"], sp.get("cen")), k=0.62)
    return a


def bl_cornchamomile(a, sp):
    stalk_line(a, (54, 100), (54, 80), (50, 56), 2.0, 2.4, "sage", hairy=True)
    stalk_line(a, (60, 100), (70, 90), (80, 82), 1.6, 1.4, "sage", hairy=True)
    bud_side(a, 80, 82, 11, "corn-chamomile", -60, 0.3, sp["fc"])
    head(a, 46, 42, 34, opts("corn-chamomile", sp["fc"], sp.get("cen")), k=0.6)
    return a


def bl_feverfew(a, sp):
    hub = (50, 76)
    stalk_line(a, (52, 100), (51, 88), hub, 2.4, 2.0, "leaf")
    heads = [(28, 44, 15, -100), (52, 32, 17, -90), (74, 46, 14, -80), (60, 60, 10, -70)]
    for x, y, r, an in heads:
        a.line(f"M{P(hub)} Q{f((hub[0] + x) / 2)},{f((hub[1] + y) / 2 + 6)} {f(x)},{f(y + r * 0.35)}", 1.1, 0.85)
    for x, y, r, an in sorted(heads, key=lambda h: h[1]):
        head(a, x, y, r, opts("feverfew", sp["fc"], sp.get("cen")), k=0.72, ang=an)
    return a


def bl_aster(a, sp):
    stalk_line(a, (46, 100), (44, 80), (36, 62), 1.6, 1.3, "bark")
    stalk_line(a, (45, 86), (60, 76), (70, 66), 1.3, 1.1, "bark")
    a.leaf(46, 80, -18, 10, 0.2, "deep", lw=0.6)
    bud_side(a, 70, 66, 9, "aster", -60, 0.5, sp["fc"])
    head(a, 36, 42, 30, opts("aster", sp["fc"], sp.get("cen")), k=0.82)
    return a


def bl_african(a, sp):
    stalk_line(a, (54, 100), (54, 80), (50, 58), 2.2, 2.0, "leaf")
    stalk_line(a, (62, 100), (70, 90), (80, 82), 1.7, 1.5, "leaf")
    bud_side(a, 80, 82, 12, "african-daisy", -58, 0.3, sp["fc"])
    head(a, 46, 40, 36, opts("african-daisy", sp["fc"], sp.get("cen")), k=0.68)
    return a


def bl_helipterum(a, sp):
    stalk_line(a, (54, 100), (56, 80), (50, 60), 1.5, 1.3, "sage")
    stalk_line(a, (55, 92), (70, 80), (78, 68), 1.2, 1.0, "sage")
    a.ribbon((78, 68), (80, 66), (80, 70), 1.0, 1.0, "sage", lw=0.5)
    bud_side(a, 79, 75, 5, "helipterum-rosum", 100, 0.5, sp["fc"])   # the bud nods before it opens
    o = opts("helipterum-rosum", sp["fc"], sp.get("cen"))
    V = head(a, 48, 42, 34, o, k=0.74)
    rd = 34 * o["disc"]   # the narrow dark ring of short inner bracts round the yellow middle
    a.line(opath([V(rd * 1.04 * math.cos(t_), rd * 1.04 * math.sin(t_)) for t_ in [2 * math.pi * i / 40 for i in range(41)]]), 1.5, 0.9, "dark")
    return a


def bl_marigold(a, sp):
    """French marigold from a little below the side: the slim tube of joined
    bracts with five small points, then the double head on top."""
    fc = sp["fc"]; c = (50, 40)
    stalk_line(a, (54, 100), (54, 86), (51, 76), 2.0, 3.0, "leaf")   # the stalk swells under the head
    tube = [(c[0] - 6, c[1] + 6), (c[0] - 5, c[1] + 26), (c[0] - 2.2, c[1] + 36), (c[0] + 2.2, c[1] + 36), (c[0] + 5, c[1] + 26), (c[0] + 6, c[1] + 6)]
    a.shape(f"M{P(tube[0])} Q{P(tube[1])} {P(tube[2])} L{P(tube[3])} Q{P(tube[4])} {P(tube[5])} Z", "deep", 0.9)
    a.shape(f"M{P(tube[0])} Q{P(tube[1])} {P(tube[2])} L{f(c[0] - 1)},{f(c[1] + 36)} L{f(c[0] - 2)},{f(c[1] + 6)} Z", "shade", 0, fa=0.12)
    for dx in (-3.2, 0, 3.2):   # faint ribs
        a.line(f"M{f(c[0] + dx)},{f(c[1] + 8)} L{f(c[0] + dx * 0.5)},{f(c[1] + 34)}", 0.4, 0.35)
    for j in range(5):   # the five points at its top, and its oil glands
        x0 = c[0] - 6 + 3 * j
        a.shape(f"M{f(x0 - 1.5)},{f(c[1] + 8)} L{f(x0)},{f(c[1] + 2)} L{f(x0 + 1.5)},{f(c[1] + 8)} Z", "deep", 0.6)
        a.dot(c[0] - 3 + 1.6 * j, c[1] + 16 + 5 * (j % 2), 0.45, "pale")
    head(a, c[0], c[1], 32, opts("french-marigold", fc, sp.get("cen")), k=0.55)
    return a



def cone_head(a, x, y, r, fc, small=False, dry=False):
    """Pineappleweed: a rounded cone of tiny greenish-yellow florets and no
    rays, on a short cup of bracts with broad pale papery edges. x, y is
    the top of the stalk; r is the cone's half width."""
    lw = 0.8 if not small else 0.5
    cx, cy = x, y - r * 1.05
    for j in range(5):   # the bracts, much shorter than the head, cupping its foot
        bx = x + (j - 2) * r * 0.34
        tt = T(bx, y + r * 0.3, -90 + (j - 2) * 34)
        pts = [tt(*p) for p in ray_pts(r * 0.55, r * 0.4, "oblong")]
        a.shape(path(pts), "straw" if dry else "leaf", lw * 0.8)
        if not small:
            a.line(opath(pts[8:-8]), lw * 1.6, 0.95, "white"); a.shape(path(pts), None, lw * 0.8)
    a.polar(cx, cy, lambda h: 1 - 0.12 * math.sin(h), r, r * 1.25, 0, "bark" if dry else fc, lw, shade=not small)
    m = int(r * r * 0.9) if not small else int(r * r * 0.6)
    for j in range(max(4, m)):
        rr = 0.85 * math.sqrt((j + 0.5) / max(4, m)); th = j * GOLD
        a.dot(cx + r * rr * math.cos(th), cy + r * 1.15 * rr * math.sin(th), max(0.28, r * 0.06), "dark" if dry else "unripe")


def bl_pineapple(a, sp):
    stalk_line(a, (50, 100), (50, 86), (48, 70), 2.0, 1.8, "leaf")
    a.line("M48,72 Q38,64 32,58", 1.4, 0.85); a.line("M48,74 Q62,66 70,62", 1.4, 0.85)
    for x, y, r in ((32, 58, 10), (70, 62, 8.5), (48, 46, 13)):
        if (x, y) == (48, 46):
            a.line("M48,70 L48,46", 1.6, 0.85)
        cone_head(a, x, y, r, sp["fc"])
    return a


def funnel(a, x, y, ang, L, W, fill, teeth=6, lw=0.6, inner="shade"):
    """One outer cornflower floret: a slim tube opening into a funnel with a
    jagged rim of pointed teeth."""
    t = T(x, y, ang); n = 12
    top = [(L * 0.85 * u, W * 0.5 * (0.14 + 0.86 * u ** 1.6)) for u in [i / n for i in range(n + 1)]]
    rim = []
    for j in range(2 * teeth + 1):
        v = 1 - 2 * j / (2 * teeth)
        rim.append((L * (1.0 if j % 2 else 0.86), W * 0.5 * v * (1.12 if j % 2 else 1.0)))
    bot = [(px, -py) for px, py in top]
    a.shape(path([t(*p) for p in top] + [t(*p) for p in rim] + [t(*p) for p in bot[::-1]]), fill, lw)
    a.shape(path([t(*p) for p in top] + [t(px, 0) for px, py in top[::-1]]), "shade", 0, fa=0.1)
    if L > 10:
        for o in (-0.2, 0.2):
            a.line(opath([t(L * u, o * W * 0.5 * u) for u in (0.3, 0.6, 0.84)]), 0.4, 0.3)


def cornflower_head(a, x, y, s, fc, cen, small=False, dry=False):
    """A cornflower head from the side: the egg-shaped cup of scaly bracts,
    each with a dark fringed edge, the ring of jagged funnels round the
    outside and the smaller darker florets in the middle. x, y is the top
    of the stalk; s the size (1 = the close-up)."""
    lw = 0.8 if not small else 0.5
    rx, ry = 10 * s, 12 * s; c = (x, y - ry); top = (x, y - ry * 1.85)
    if not dry:
        fun = [(-160, 0.92), (-20, 0.92), (-132, 1.0), (-48, 1.0), (-108, 1.0), (-72, 1.0), (-90, 0.9)] if not small else [(-158, 1), (-22, 1), (-120, 1), (-60, 1), (-90, 0.9)]
        for an, k in fun[4 if not small else 3:]:
            funnel(a, top[0], top[1], an, 25 * s * k, 11 * s * k, fc, lw=lw * 0.8)
        for j in range(9 if not small else 4):   # the inner florets
            an = -125 + 70 * j / (8 if not small else 3)
            e = T(*top, an)(11 * s)
            a.line(f"M{P(top)} L{P(e)}", 2.2 * s + 0.6, 0.9, "line"); a.line(f"M{P(top)} L{P(e)}", 2.2 * s, 1.0, cen)
            if not small:
                a.dot(e[0], e[1], 0.8, "dark")
        for an, k in fun[:4 if not small else 3]:
            funnel(a, top[0], top[1] + 1, an, 25 * s * k, 11 * s * k, fc, lw=lw * 0.8)
    a.polar(c[0], c[1], lambda h: 1 - 0.18 * max(0, -math.sin(h)), rx, ry, 0, "straw" if dry else "leaf", lw, shade=not small)
    if dry:
        a.shape(f"M{f(top[0] - rx * 0.5)},{f(top[1] + ry * 0.3)} L{f(top[0])},{f(top[1] - 1)} L{f(top[0] + rx * 0.5)},{f(top[1] + ry * 0.3)} Z", "straw", lw)
    rows = 4 if not small else 2
    for r_ in range(rows):   # the bracts, each edged with a dark fringe
        yy = c[1] - ry * 0.55 + r_ * ry * 1.25 / rows; hw_ = rx * math.sqrt(max(0.05, 1 - ((yy - c[1]) / (ry * 1.02)) ** 2))
        m = 3 + (r_ % 2)
        for j in range(m):
            xx = c[0] - hw_ + 2 * hw_ * (j + 0.5 + 0.25 * (r_ % 2)) / (m + 0.25)
            w2 = hw_ / m * 1.1
            d = f"M{f(xx - w2)},{f(yy + ry * 0.18)} Q{f(xx)},{f(yy - ry * 0.16)} {f(xx + w2)},{f(yy + ry * 0.18)}"
            a.line(d, 1.1 if not small else 0.7, 0.9, "dark")
            if not small:
                for q in range(5):
                    px = xx - w2 * 0.8 + w2 * 1.6 * q / 4; py = yy + ry * 0.12 - ry * 0.18 * (1 - ((px - xx) / w2) ** 2) ** 0.8
                    a.line(f"M{f(px)},{f(py)} l{f((px - xx) * 0.1)},-1.1", 0.4, 0.8, "white" if q % 2 else "dark")
    return top


def bl_cornflower(a, sp):
    stalk_line(a, (52, 100), (52, 86), (50, 78), 2.4, 2.2, "sage", woolly=True)
    cornflower_head(a, 50, 79, 1.15, sp["fc"], sp.get("cen", "plum"))
    return a


def globe_ball(a, x, y, R, fc, small=False, dry=False, bud=False):
    """A globe thistle head: a perfect ball of many tiny star-like florets
    (no face, no rays), with short bristly bracts turned back at its foot."""
    lw = 0.9 if not small else 0.55
    for j in range(7 if not small else 4):   # the bristly bracts, turned back
        an = 90 + (j - (3 if not small else 1.5)) * 22
        b = T(x, y + R * 0.86, an - 180)(0)
        e = T(*b, an)(R * 0.32)
        a.line(f"M{P(b)} L{P(e)}", 0.8 if not small else 0.5, 0.85, "straw" if dry else "sage")
    col = "bark" if dry else fc
    a.oval(x, y, R, R, 0, col, lw)
    if not small:
        a.shape(path([(x + R * math.cos(h), y + R * math.sin(h)) for h in [math.radians(-30 + 200 * i / 30) for i in range(31)]] + [(x - R * 0.2, y + R * 0.1)]), "shade", 0, fa=0.12)
    pts = [p for p in _sphere(70 if not small else 26) if p[2] > 0]
    for px, py, pz in sorted(pts, key=lambda p: p[2]):
        e = (x + px * R * 0.9, y + py * R * 0.9)
        r = (3.2 if not small else max(0.9, R * 0.16)) * (0.6 + 0.4 * pz)
        if dry:
            for kk in range(4):
                p2 = T(*e, kk * 90 + px * 40)(r * 0.8); a.line(f"M{P(e)} L{P(p2)}", 0.4, 0.7, "straw")
        elif bud:
            a.leaf(e[0], e[1] + r * 0.5, -90 + px * 50, r * 1.3, 0.4, fc, lw=0.35, detail=False)
        else:
            for kk in range(5):   # five narrow lobes curling back
                p2 = T(*e, kk * 72 + px * 50)(r); a.line(f"M{P(e)} L{P(p2)}", 0.5 if not small else 0.35, 0.65)
            if not small:
                a.dot(e[0], e[1], 0.55, "dark")


def _sphere(n, seed=0.5):
    out = []
    for i in range(n):
        z = 1 - 2 * (i + seed) / n; r = math.sqrt(max(0, 1 - z * z)); th = i * GOLD
        out.append((r * math.cos(th), r * math.sin(th), z))
    return out


def bl_globethistle(a, sp):
    stalk_line(a, (50, 100), (51, 80), (50, 62), 3.2, 2.8, "white", woolly=False)
    stalk_line(a, (50.5, 84), (62, 78), (74, 70), 2.0, 1.8, "white")
    for k in range(5):   # the white wool shows as faint grey lines
        a.line(f"M{f(49 + k * 0.4)},{f(98 - k * 7)} q1,-2 0.4,-4", 0.35, 0.4)
    globe_ball(a, 76, 62, 8, sp["fc"], bud=True)
    globe_ball(a, 50, 38, 25, sp["fc"])
    return a


def bl_scabiosa(a, sp):
    """A pincushion seen at a slant: a ring of large frilly florets, each
    lopsided outwards, round a dome of small florets studded with pale
    stamens like pins; narrow green bracts beneath."""
    fc = sp["fc"]; pin = sp.get("cen", "white")
    stalk_line(a, (54, 100), (54, 80), (50, 56), 2.0, 1.8, "sage")
    pincushion(a, 50, 42, 34, fc, pin, k=0.8)
    return a


def pincushion(a, x, y, R, fc, pin, k=0.6, small=False, ang=-90):
    V = view(x, y, k, ang); lw = 0.65 if not small else 0.45
    for j in range(12 if not small else 6):   # narrow pointed bracts, showing between the outer florets
        _plane_ray(a, V, 2 * math.pi * (j + 0.5) / (12 if not small else 6), R * 0.3, R * 0.62, R * 0.06, "leaf", "bract", lw * 0.8)
    n = 12 if not small else 8
    order = sorted(range(n), key=lambda i: math.sin(2 * math.pi * i / n))
    rd = R * 0.42
    W = 2 * math.pi * R * 0.45 / n * 1.25
    for i in order:   # a regular ring of the large lopsided florets, then the dome over their inner ends
        _outer_floret(a, V, 2 * math.pi * i / n, R * 0.32, R * 0.66, W, fc, lw, small)
    _dome_pins(a, V, rd, R, fc, pin, lw, small)
    return V


def _outer_floret(a, V, ph, r0, L, W, fc, lw, small):
    """One outer scabious floret: a short tube opening into a lopsided fan
    of lobes, the outward-facing lobes much the largest, their edge frilled."""
    c, s = math.cos(ph), math.sin(ph)
    X = lambda p: V((r0 + p[0]) * c - p[1] * s, (r0 + p[0]) * s + p[1] * c, 0)
    pts = [(0, -W * 0.18)]
    for i in range(61):
        th = -1.0 + 2.0 * i / 60
        rr = L * (0.62 + 0.38 * math.cos(th * 1.3))                      # a broad fan, longest in the middle
        rr *= 1 - 0.2 * max(0.0, math.cos(th * 4.7)) ** 8 * (abs(th) > 0.3)   # clefts between the lobes
        if not small:
            rr *= 1 - 0.045 * abs(math.sin(th * 15))                     # the frilled edge
        pts.append((rr * math.cos(th * 0.62), W * 0.75 * math.sin(th * 1.2) * (0.6 + 0.4 * rr / L)))
    pts.append((0, W * 0.18))
    q = [X(p) for p in pts]
    a.shape(path(q), fc, lw)
    if not small:
        for o in (-0.45, 0.45):
            a.line(opath([X((L * 0.3, o * W * 0.2)), X((L * 0.7, o * W * 0.55))]), 0.4, 0.4)


def _dome_pins(a, V, rd, R, fc, pin, lw, small):
    hd = rd * 0.75
    front = [V(rd * math.cos(t_), rd * math.sin(t_), 0) for t_ in [math.pi * i / 30 for i in range(31)]]
    backp = [V(rd * math.cos(t_), rd * math.sin(t_), hd * abs(math.sin(t_)) ** 0.8) for t_ in [math.pi + math.pi * i / 30 for i in range(31)]]
    a.shape(path(front + backp), fc, lw)
    m = 46 if not small else 10
    pts = []
    for j in range(m):
        rr = rd * 0.92 * math.sqrt((j + 0.5) / m); th = j * GOLD
        pts.append((rr, th, V(rr * math.cos(th), rr * math.sin(th), hd * (1 - (rr / rd) ** 2))))
    for rr, th, p in sorted(pts, key=lambda q: q[2][1]):
        if not small:
            a.flower(p[0], p[1], 1.5, 4, fc, None, 0.6, start=th * 50, lw=0.3)
        h = (3.4 if not small else 1.6)
        lean = (p[0] - V(0, 0)[0]) * 0.12
        a.line(f"M{P(p)} L{f(p[0] + lean)},{f(p[1] - h)}", 0.4 if not small else 0.35, 0.6)
        a.dot(p[0] + lean, p[1] - h - 0.2, 0.6 if not small else 0.45, pin)


def ball_head(a, x, y, r, fc, anth="dark", small=False, dry=False):
    """Devil's-bit scabious: a small round dome, every floret the same size,
    long stamens with dark anthers making it fuzzy; green bracts beneath."""
    lw = 0.8 if not small else 0.5
    for j in range(7 if not small else 4):   # the bracts under the head
        an = 90 + (j - (3 if not small else 1.5)) * 26
        tt = T(x, y + r * 0.55, an)
        a.shape(path([tt(*p) for p in ray_pts(r * 0.5, r * 0.32, "bract")]), "straw" if dry else "leaf", lw * 0.7)
    col = "bark" if dry else fc
    pts = [(x + r * math.cos(h), y + r * 0.72 * math.sin(h) if math.sin(h) > 0 else y + r * 0.98 * math.sin(h)) for h in [2 * math.pi * i / 40 for i in range(40)]]
    if not dry and not small:   # the stamens sticking out round the edge
        for j in range(30):
            h = math.pi + math.pi * (j + 0.5) / 30 + 0.15
            b = (x + r * 0.9 * math.cos(h), y + r * 0.9 * math.sin(h)); e = (x + r * 1.3 * math.cos(h), y + r * 1.25 * math.sin(h))
            a.line(f"M{P(b)} L{P(e)}", 0.4, 0.55); a.dot(e[0], e[1], 0.55, anth)
    a.shape(path(pts), col, lw)
    m = 40 if not small else 9
    for j in range(m):
        rr = 0.9 * math.sqrt((j + 0.5) / m); th = j * GOLD
        px, py = x + r * rr * math.cos(th), y + r * rr * math.sin(th) * (0.9 if math.sin(th) < 0 else 0.65)
        if dry:
            a.dot(px, py, max(0.3, r * 0.05), "dark")
        elif not small:
            a.flower(px, py, 1.3, 4, fc, None, 0.6, start=th * 40, lw=0.3)
            e = (px + (px - x) * 0.16, py - 2.6); a.line(f"M{f(px)},{f(py)} L{P(e)}", 0.35, 0.5); a.dot(e[0], e[1], 0.5, anth)
        else:
            a.dot(px, py - 0.6, 0.4, anth)


def bl_devilsbit(a, sp):
    fc = sp["fc"]; anth = "dark"
    stalk_line(a, (50, 100), (50, 86), (50, 72), 1.8, 1.6, "leaf")
    stalk_line(a, (50, 72), (50, 60), (50, 48), 1.6, 1.4, "leaf")
    a.line("M50,72 Q38,68 28,58", 1.3, 0.85); a.line("M50,72 Q62,68 72,58", 1.3, 0.85)
    for sd in (1, -1):   # the pair of small leaves where the stem forks
        a.leaf(50, 72, -90 + sd * 70, 9, 0.22, pal("devil-s-bit-scabious", "leaf", "deep"), lw=0.6)
    ball_head(a, 28, 52, 9, fc, anth); ball_head(a, 72, 52, 9, fc, anth)
    ball_head(a, 50, 36, 15, fc, anth)
    return a


def rampion_head(a, x, y, r, fc, sty="lilac", small=False, dry=False, lc="leaf"):
    """Oxford rampion: a round spiky ball of narrow, curved, claw-like
    flowers radiating outwards, curled styles sticking out of the open
    ones, and long narrow bracts spreading beneath like horns. x, y is the
    middle of the ball, r its radius; the stalk should reach y + 0.3 r."""
    lw = 0.75 if not small else 0.5
    for an, L in ((166, 2.0), (14, 2.0), (146, 1.7), (34, 1.7), (124, 1.4), (56, 1.4)):   # the horns
        b = (x + r * 0.3 * math.cos(math.radians(an)), y + r * 0.3)
        tt = T(*b, an)
        a.shape(path([tt(*p) for p in ray_pts(r * L, r * 0.2, "bract")]), "straw" if dry else lc, lw * 0.8)
    col = "bark" if dry else fc
    a.oval(x, y, r * 0.42, r * 0.4, 0, col, lw)
    nn = 30 if not small else 14
    claws = []
    for kk in range(nn):   # radiating in every direction but straight down, a shorter ring in front
        an = -90 + (kk - (nn - 1) / 2) * (300 / nn) + 5 * math.sin(kk * 2.3)
        claws.append((1.0, an))
    for kk in range(nn // 2):
        claws.append((0.62, -90 + (kk - (nn // 2 - 1) / 2) * (320 / (nn // 2)) + 9))
    for sc_, an in sorted(claws, key=lambda c: (-c[0], -abs(c[1] + 90))):
        ca, sa = math.cos(math.radians(an)), math.sin(math.radians(an))
        L = r * sc_ * (0.95 + 0.12 * math.sin(an * 0.3))
        b = (x + ca * r * 0.25, y + sa * r * 0.25)
        e = (x + ca * L, y + sa * L)
        hook = 0.22 * (1 if ca >= 0 else -1)   # the tip curves over a little
        m = (x + ca * L * 0.62 - sa * r * hook * 0.4, y + sa * L * 0.62 + ca * r * hook * 0.4)
        e2 = (e[0] - sa * r * hook, e[1] + ca * r * hook)
        d = f"M{P(b)} Q{P(m)} {P(e2)}"
        w = r * 0.1 if not small else max(0.7, r * 0.15)
        a.line(d, w + 0.6, 0.9, "line"); a.line(d, w, 1.0, col)
        if sc_ == 1.0 and not small and not dry and int(an) % 3 == 0 and an < -30 and an > -150:   # a style with its curled tip
            s2 = (e2[0] + ca * r * 0.32, e2[1] + sa * r * 0.32)
            a.line(f"M{P(e2)} L{P(s2)}", 0.5, 0.8)
            a.line(f"M{P(s2)} q{f(ca * 1.3 - sa * 0.8)},{f(sa * 1.3 + ca * 0.8)} {f(ca * 0.3 + sa * 1.2)},{f(sa * 0.3 - ca * 1.2)}", 0.6, 0.9, sty)


def bl_rampion(a, sp):
    stalk_line(a, (50, 100), (51, 76), (50, 46), 2.0, 1.8, "leaf")
    rampion_head(a, 50, 40, 21, sp["fc"], sp.get("cen", "lilac"), lc=pal("oxford-rampion", "leaf", "deep"))
    return a


# ============================================================ seeds
# Each draws the seed large at x, y (the "seed" stage puts it under the soil
# line, as plants.sown does). Tiny seeds are drawn three together.
def _body(a, x, y, ang, L, W, fill, pf, lw=1.0):
    top, bot = simple_edges(L, W, pf, n=60)
    t = T(x, y, ang)
    a.shape(path([t(*p) for p in top] + [t(*p) for p in bot[::-1]]), fill, lw)
    return t


def seed_sunflower(a, x, y):
    """A flattened tear-drop, pointed at one end, striped black and grey-white."""
    t = _body(a, x - 2, y + 15, -96, 32, 17, "dark", prof(0.62, "wedge", "round", bp=0.9, tp=2.2))
    for o, u0, u1 in ((-4.6, 0.25, 0.85), (-1.6, 0.15, 0.95), (1.6, 0.15, 0.95), (4.6, 0.25, 0.85)):
        a.line(opath([t(32 * u, o * (0.55 + 0.45 * u)) for u in (u0, (u0 + u1) / 2, u1)]), 1.1, 0.9, "white")


def seed_calendula(a, x, y):
    """Strongly curved, C-shaped, its back knobbly and ridged; beige-brown."""
    pts_o, pts_i = [], []
    for i in range(41):
        th = math.radians(-60 + 260 * i / 40); w = 4.6 * math.sin(math.pi * i / 40) ** 0.5 + 0.8
        ro = 12 + w * 0.5 + (1.3 * abs(math.sin(i * 1.4)) if 4 < i < 36 else 0); ri = 12 - w * 0.5
        pts_o.append((x + ro * math.cos(th), y + ro * math.sin(th))); pts_i.append((x + ri * math.cos(th), y + ri * math.sin(th)))
    a.shape(path(pts_o + pts_i[::-1]), "seed", 1.0)
    for i in range(6, 36, 4):
        th = math.radians(-60 + 260 * i / 40)
        a.line(f"M{f(x + 11 * math.cos(th))},{f(y + 11 * math.sin(th))} L{f(x + 14.5 * math.cos(th))},{f(y + 14.5 * math.sin(th))}", 0.6, 0.45)


def seed_cosmos(a, x, y):
    """Long, slender and dark, with two or three short barbed bristles at the top."""
    y += 6
    a.ribbon((x - 6, y + 18), (x - 1, y), (x + 4, y - 14), 3.6, 2.2, "dark", lw=0.9)
    for an in (-120, -84, -56):
        e = T(x + 4, y - 14, an)(7); a.line(f"M{f(x + 4)},{f(y - 14)} L{P(e)}", 0.8, 0.9)
        for v in (0.4, 0.7):
            b = T(x + 4, y - 14, an)(7 * v); a.line(f"M{P(b)} l{f(math.cos(math.radians(an + 150)) * 1.4)},{f(math.sin(math.radians(an + 150)) * 1.4)}", 0.4, 0.8)


def seed_zinnia(a, x, y):
    """Flat, wedge- to arrowhead-shaped, grey-brown."""
    pts = [(x, y + 16), (x - 4, y + 4), (x - 10, y - 9), (x - 9, y - 13), (x - 4, y - 10), (x, y - 13), (x + 4, y - 10), (x + 9, y - 13), (x + 10, y - 9), (x + 4, y + 4)]
    a.shape(path(pts), "bark", 1.0)
    a.line(f"M{f(x)},{f(y + 13)} L{f(x)},{f(y - 9)}", 0.6, 0.45)
    a.shape(path([(x, y + 16), (x - 4, y + 4), (x - 10, y - 9), (x - 9, y - 13), (x - 4, y - 10), (x, y - 13)]), "shade", 0, fa=0.12)


def _tiny(a, x, y, draw):
    for dx, dy, an in ((-9, 4, -110), (5, -4, -70), (11, 10, -96)):
        draw(a, x + dx, y + dy, an)


def seed_rudbeckia(a, x, y):
    """Tiny, black, narrow and four-angled, with no fluff."""
    def one(a, x, y, an):
        t = _body(a, x, y + 7, an, 15, 4.4, "dark", prof(0.6, "wedge", "blunt", bp=0.8, b0=0.3), 0.8)
        a.line(f"M{P(t(1))} L{P(t(14))}", 0.5, 0.5, "straw")
    _tiny(a, x, y, one)


def seed_marigold(a, x, y):
    """Thin and needle-like, black, with a straw-coloured bristly tip."""
    a.ribbon((x - 4, y + 20), (x - 1, y), (x + 3, y - 14), 1.6, 2.8, "dark", lw=0.8)
    for an, L in ((-120, 7), (-88, 9), (-60, 7)):
        e = T(x + 3, y - 14, an)(L)
        a.ribbon((x + 3, y - 14), T(x + 3, y - 14, an)(L * 0.5), e, 1.4, 0.3, "straw", lw=0.6)


def seed_ribbed(fill, rib, rim=False, crown=False):
    def draw(a, x, y):
        def one(a, x, y, an):
            t = _body(a, x, y + 6, an, 12, 5.2, fill, prof(0.5, "round", "blunt", bp=0.5, b0=0.45), 0.8)
            for o in (-1.4, 0, 1.4):
                a.line(f"M{P(t(1.2, o))} L{P(t(11, o))}", 0.55, 0.85, rib)
            if rim:
                a.line(f"M{P(t(12, -2.6))} Q{P(t(13.6, 0))} {P(t(12, 2.6))}", 0.9, 0.85)
            if crown:
                for o in (-2, -0.7, 0.7, 2):
                    a.line(f"M{P(t(12, o))} L{P(t(14, o * 1.3))}", 0.6, 0.85)
        _tiny(a, x, y, one)
    return draw


def seed_aster(a, x, y):
    """Tiny, narrow, flattened and brown, with a tuft of fine white hairs."""
    def one(a, x, y, an):
        t = _body(a, x, y + 8, an, 9, 3.6, "bark", prof(0.5, "round", "point", bp=0.6), 0.8)
        for o in range(-3, 4):
            e = t(9 + 9, o * 2.0)
            a.line(f"M{P(t(9))} Q{P(t(13, o * 0.8))} {P(e)}", 0.4, 0.4)
    _tiny(a, x, y, one)


def seed_african(a, x, y):
    """Hard and bony, a little curved, with several parallel warty ribs
    along it; grey-brown."""
    t = _body(a, x - 3, y + 15, -80, 30, 13, "bark", prof(0.5, "round", "round", bp=0.5, tp=1.6))
    for o in (-3.6, -1.2, 1.2, 3.6):
        a.line(opath([t(30 * u, o * (0.6 + 0.6 * math.sin(math.pi * u))) for u in (0.12, 0.35, 0.6, 0.85)]), 0.8, 0.6)
        for u in (0.25, 0.5, 0.72):
            p = t(30 * u, o * (0.6 + 0.6 * math.sin(math.pi * u)) + 0.6); a.dot(p[0], p[1], 0.6, "dark")


def seed_helipterum(a, x, y):
    """Small and woolly, with a ring of feathery white bristles."""
    a.oval(x, y + 8, 3.4, 6.4, 0, "seed", 0.9)
    for j in range(5):
        a.line(f"M{f(x - 2.4)},{f(y + 4 + j * 2)} l{f(-1.2)},{f(-0.6)} M{f(x + 2.4)},{f(y + 4 + j * 2)} l1.2,-0.6", 0.4, 0.5)
    for j in range(9):
        an = -90 + (j - 4) * 17; e = T(x, y + 2, an)(18)
        a.line(f"M{f(x)},{f(y + 2)} L{P(e)}", 0.5, 0.6)
        for v in (0.35, 0.55, 0.75, 0.92):
            b = T(x, y + 2, an)(18 * v)
            for sg in (1, -1):
                a.line(f"M{P(b)} l{f(math.cos(math.radians(an + sg * 40)) * 1.6)},{f(math.sin(math.radians(an + sg * 40)) * 1.6)}", 0.35, 0.4)


def seed_cornflower(a, x, y):
    """Smooth, shiny, pale grey and oblong, with a short brush of stiff
    reddish-brown bristles at one end."""
    t = _body(a, x - 2, y + 14, -84, 22, 10, "pale", prof(0.5, "round", "blunt", bp=0.5, b0=0.5))
    a.line(opath([t(22 * u, -2.6) for u in (0.2, 0.45, 0.7)]), 1.2, 0.7, "white")
    for o in range(-4, 5):
        b = t(22, o * 0.9); e = t(29, o * 1.3)
        a.line(f"M{P(b)} L{P(e)}", 0.7, 0.9, "rust")


def seed_globethistle(a, x, y):
    """Long and cylindrical, covered in silky pale hairs, with a short crown."""
    t = _body(a, x - 2, y + 16, -86, 28, 7, "seed", prof(0.5, "round", "blunt", bp=0.5, b0=0.5))
    for j in range(14):   # silky pale hairs lying along the seed
        u = 0.08 + 0.75 * ((j * 0.618) % 1); o = (((j * 0.37) % 1) - 0.5) * 6
        a.line(f"M{P(t(28 * u, o))} Q{P(t(28 * u + 4, o * 1.05))} {P(t(28 * u + 8, o * 1.15))}", 0.5, 0.95, "straw")
    for o in (-2.4, -0.8, 0.8, 2.4):
        a.line(f"M{P(t(28, o))} L{P(t(32, o * 1.3))}", 0.6, 0.85, "straw")


def seed_scabiosa(a, x, y):
    """The seed sits in a papery, ribbed, funnel-shaped collar with a star
    of five dark bristles at its middle, like a shuttlecock."""
    a.oval(x, y + 14, 3.6, 6.4, 0, "seed", 0.9)
    a.shape(f"M{f(x - 2.6)},{f(y + 9)} L{f(x - 13)},{f(y - 6)} Q{f(x)},{f(y - 1)} {f(x + 13)},{f(y - 6)} L{f(x + 2.6)},{f(y + 9)} Z", "straw", 0.9)
    a.oval(x, y - 6, 13, 3.4, 0, "straw", 0.8)
    for dx in (-8, -4, 0, 4, 8):
        a.line(f"M{f(x + dx * 0.25)},{f(y + 8)} L{f(x + dx)},{f(y - 4)}", 0.45, 0.4)
    for an in (-90, -162, -18, -126, -54):
        e = T(x, y - 7, an)(14 if an == -90 else 12); a.line(f"M{f(x)},{f(y - 7)} L{P(e)}", 1.0, 0.95, "dark")


def seed_devilsbit(a, x, y):
    """Tiny and hairy, in a four-angled collar with five short bristles."""
    def one(a, x, y, an):
        t = T(x, y + 7, an)
        a.shape(path([t(0, -2), t(9, -3.2), t(11, -2.4), t(11, 2.4), t(9, 3.2), t(0, 2)]), "bark", 0.8)
        a.line(f"M{P(t(1, 0))} L{P(t(10, 0))}", 0.5, 0.5)
        for o in (-2, -1, 0, 1, 2):
            a.line(f"M{P(t(11, o * 0.9))} L{P(t(14.5, o * 1.5))}", 0.6, 0.9, "dark")
    _tiny(a, x, y, one)


def seed_rampion(a, x, y):
    """Tiny, oval, flattened and shiny brown."""
    def one(a, x, y, an):
        t = _body(a, x, y + 5, an, 9, 6, "bark", prof(0.5, "round", "round", bp=0.5), 0.8)
        a.line(opath([t(9 * u, -1.4) for u in (0.3, 0.5, 0.7)]), 0.8, 0.7, "white")
    _tiny(a, x, y, one)


SEEDS = {"sunflower": seed_sunflower, "calendula": seed_calendula, "cosmos": seed_cosmos, "zinnia": seed_zinnia,
         "rudbeckia": seed_rudbeckia, "french-marigold": seed_marigold, "ox-eye-daisy": seed_ribbed("dark", "pale"),
         "corn-chamomile": seed_ribbed("straw", "bark", rim=True), "wild-chamomile": seed_ribbed("seed", "bark", rim=True),
         "feverfew": seed_ribbed("seed", "bark", crown=True), "aster": seed_aster, "african-daisy": seed_african,
         "helipterum-rosum": seed_helipterum, "cornflower": seed_cornflower, "blue-globe-thistle": seed_globethistle,
         "scabiosa": seed_scabiosa, "devil-s-bit-scabious": seed_devilsbit, "oxford-rampion": seed_rampion}



# ============================================================ life-stage helpers
def sown(kind):
    return S10.sown(SEEDS[kind])


def cot_leaf(a, x, y, ang, L, W, shape="oval"):
    """One seed leaf (cotyledon): smooth, pale green."""
    pf = {"oval": prof(0.5, "round", "round", bp=0.6, tp=2.0), "oblong": prof(0.45, "round", "round", bp=0.4, tp=3.0, b0=0.3),
          "narrow": prof(0.4, "round", "round", bp=0.5, tp=2.5, b0=0.45), "round": prof(0.5, "round", "round", bp=0.45, tp=1.6)}[shape]
    top, bot = simple_edges(L, W, pf, n=40)
    draw_leaf(a, x, y, ang, top, bot, "pale", 0.9, shade=0.08, mid=[(0, 0), (0.8 * L, 0)], midw=0.45)


def seedling(cot=("oval", 10, 6), h=14, stemw=1.6, stemc="pale", true=None, spread=16):
    """The seedling stage: roots, a short stem, two seed leaves and the
    first true leaves (true(a, x, y) draws them at the top of the stem)."""
    def draw():
        a = Art(); a.ground(G); a.roots(50, G, 3, 12, 50)
        top = (50, G - h)
        a.ribbon((50, G), (49.4, G - h * 0.5), top, stemw, stemw * 0.8, stemc)
        sh, L, W = cot
        cot_leaf(a, 50, G - h, -180 + spread, L, W, sh); cot_leaf(a, 50, G - h, -spread, L, W, sh)
        if true:
            true(a, *top)
        return a
    return draw


def shoot(a, p0, c, p1, w0, w1, col="leaf", leaf=None, n=0, Ls=(12, 7), lang=55, opp=False, us=(0.15, 0.85),
          lfill="leaf", side=1, droop=0, lkw=None):
    """A stem with its leaves: n leaves (or pairs, opp=True) spread from us[0]
    to us[1] along it, their sizes going from Ls[0] to Ls[1]."""
    q = a.ribbon(p0, c, p1, w0, w1, col, lw=0.75 if w0 < 2 else 0.85)
    if leaf and n:
        with a.on(LEAF):
            for i in range(n):
                u = us[0] + (us[1] - us[0]) * i / max(1, n - 1)
                x, y = q.pt(u); qa = q.ang(u)
                L = Ls[0] + (Ls[1] - Ls[0]) * i / max(1, n - 1)
                for sd in ((1, -1) if opp else ((side if i % 2 == 0 else -side),)):
                    leaf(a, x, y, qa + sd * (lang + droop), L, lfill, small=True, **(lkw or {}))
    return q


def rosette(a, x, y, leaf, fill, angs, L, lkw=None):
    """Leaves fanning out from one point on the ground, the flattest first."""
    with a.on(LEAF):
        for ang in sorted(angs, key=lambda g: -abs(g + 90)):
            leaf(a, x, y, ang, L * (0.72 + 0.28 * (1 - abs(ang + 90) / 90)), fill, small=True, **(lkw or {}))


def tuft(a, x, y, n=5, h=4, col="leaf"):
    """A low tuft of small new shoots at the soil."""
    for j in range(n):
        an = -90 + (j - (n - 1) / 2) * 24
        a.leaf(x + (j - (n - 1) / 2) * 1.8, y, an, h * (1 - 0.2 * abs(j - (n - 1) / 2) / n), 0.36, col, lw=0.7, detail=False)


def dead_stem(a, x0, y0, x1, y1, w=1.2, col="straw"):
    return a.ribbon((x0, y0), ((x0 + x1) / 2 + 1, (y0 + y1) / 2), (x1, y1), w * 1.2, w * 0.8, col, lw=0.7)


def H(kind, x, y, R, k=0.6, ang=-90, **over):
    """A daisy head at life-stage size."""
    def draw(a):
        with a.on(BLOOM):
            head(a, x, y, R, opts(kind, **over), k=k, ang=ang, small=True)
    return draw


def sh(a, kind, x, y, R, k=0.6, ang=-90, **over):
    with a.on(BLOOM):
        return head(a, x, y, R, opts(kind, **over), k=k, ang=ang, small=True)



# ============================================================ sunflower
def _lc(kind):
    return pal(kind, "leaf", "leaf")


def sf_seedling():
    def true(a, x, y):
        with a.on(LEAF):
            lf_sunflower(a, x, y, -116, 12, _lc("sunflower"), small=True); lf_sunflower(a, x, y, -64, 12, _lc("sunflower"), small=True)
    return seedling(("oblong", 15, 6.6), h=17, stemw=2.8, true=true, spread=12)()


def _sf_leaves(a, q, plan, fill, hang=0):
    with a.on(LEAF):
        for u, sd, L, ang in plan:
            x, y = q.pt(u)
            lf_sunflower(a, x, y, ang if sd > 0 else -180 - ang, L, fill, small=True, bend=sd * hang)


def sf_young():
    a = Art(); a.ground(88); lc = _lc("sunflower")
    with a.group():
        q = stalk_line(a, (50, 88), (51, 62), (50, 30), 4.0, 2.6, "leaf", hairy=True)
        _sf_leaves(a, q, [(0.08, 1, 26, -8), (0.08, -1, 26, -8), (0.3, 1, 24, -22), (0.3, -1, 24, -22),
                          (0.52, 1, 21, -30), (0.68, -1, 17, -34), (0.82, 1, 13, -40)], lc)
        with a.on(BLOOM):
            bud_side(a, 50, 31, 7, "sunflower", -90)
    return a


def sf_flower():
    a = Art(); a.ground(88); lc = _lc("sunflower")
    with a.group():
        q = stalk_line(a, (50, 88), (52, 50), (54, 26), 4.0, 2.6, "leaf", hairy=True)
        _sf_leaves(a, q, [(0.1, 1, 22, -14), (0.1, -1, 22, -14), (0.3, -1, 22, -22), (0.46, 1, 21, -26), (0.62, -1, 19, -30), (0.78, 1, 15, -32)], lc, hang=58)
        with a.on(BLOOM):
            head(a, 58, 20, 18, opts("sunflower"), k=0.62, ang=-50, small=True)
    return a


def sf_seedhead():
    a = Art(); a.ground(88)
    with a.group():
        q = a.ribbon((50, 88), (49, 40), (58, 24), 4.0, 2.8, "straw", lw=0.85)
        a.ribbon((58, 24), (64, 18), (66, 26), 2.8, 2.6, "straw", lw=0.85)
        with a.on(LEAF):
            for u, sd, L, ang in [(0.12, 1, 18, 40), (0.12, -1, 18, 40), (0.36, -1, 17, 48), (0.56, 1, 15, 52), (0.74, -1, 12, 56)]:
                x, y = q.pt(u)
                lf_sunflower(a, x, y, ang if sd > 0 else 180 - ang, L, "straw" if u > 0.3 else "bark", small=True)
        with a.on(BLOOM):   # the heavy head hangs face down, its rays shrivelled, its face packed with seed
            head(a, 64, 40, 15, opts("sunflower", fc="straw", cen="dark", rw=0.07, n=14, rows=1, disc=0.72, dots="bark", spiral="bark", ring=None, rim=None, nd=40, dr=0.45,
                                     bracts=dict(n=14, l=0.32, w=0.09, col="bark"), cup=dict(rc=1.05, h=0.25, rows=1, n=8, col="straw")),
                 k=0.5, ang=125)
    return a


def dome(m, W, H, by=88, inner=0, ih=0.62):
    """Points spread over a dome W wide (each side of the middle) and H high:
    where the tips of the stems of a low rounded plant end. inner adds that
    many more a little lower down, among the leaves."""
    pts = []
    for i in range(m):
        th = math.pi * (0.06 + 0.88 * i / (m - 1))
        pts.append((50 - W * math.cos(th), by - H * (0.42 + 0.58 * math.sin(th))))
    for i in range(inner):
        th = math.pi * (0.2 + 0.6 * (i + 0.5) / inner)
        pts.append((50 - W * 0.6 * math.cos(th), by - H * ih * (0.5 + 0.5 * math.sin(th))))
    return pts


def mound(a, kind, leaf, tips, Ls=(14, 9), n=4, opp=False, lang=52, col="leaf", lfill=None, w=(1.5, 1.0), lkw=None, us=(0.18, 0.9), spread=0.3):
    """A low leafy plant: a stem from near the middle of the base to each
    tip, curving out and up, with leaves all along it, so the leaves build a
    rounded mound and the tips sit on its surface. Returns the stems."""
    qs = []
    for tx, ty in tips:
        x0 = 50 + (tx - 50) * spread * 0.4
        c = (x0 + (tx - x0) * 0.75, 88 - (88 - ty) * 0.3)
        qs.append(shoot(a, (x0, 88), c, (tx, ty), w[0], w[1], col, leaf, n, Ls, lang, opp, us, lfill or _lc(kind),
                        side=1 if tx >= 50 else -1, lkw=lkw))
    return qs


# ============================================================ calendula
def _bush(a, kind, stems, leaf, Ls, n, lang=52, w=(2.0, 1.2), col="leaf", lfill=None, opp=False, droop=0, by=88, lkw=None):
    """Several leafy stems from one base; returns the stems' curves."""
    qs = []
    for x0, dx, h, bend in stems:
        p1 = (x0 + dx, by - h)
        qs.append(shoot(a, (x0, by), (x0 + dx * 0.25 + bend, by - h * 0.55), p1, w[0], w[1], col, leaf, n, Ls, lang, opp,
                        (0.16, 0.86), lfill or _lc(kind), side=1 if dx >= 0 else -1, droop=droop, lkw=lkw))
    return qs


CAL_STEMS = [(46, -26, 36, -4), (54, 26, 36, 4), (48, -12, 46, -2), (52, 12, 46, 2), (50, 0, 52, 0)]


def cal_young():
    a = Art(); a.ground(88)
    with a.group():
        qs = _bush(a, "calendula", [(x, dx * 0.8, h * 0.72, b) for x, dx, h, b in CAL_STEMS], lf_calendula, (15, 10), 3, lang=48)
        with a.on(BLOOM):
            for q in qs:
                e = q.pt(1); bud_side(a, e[0], e[1], 4.4, "calendula", q.ang(1))
    return a


def cal_flower():
    a = Art(); a.ground(88)
    with a.group():
        qs = _bush(a, "calendula", CAL_STEMS, lf_calendula, (16, 10), 4, lang=48)
        with a.on(BLOOM):
            for q, (x0, dx, h, b) in sorted(zip(qs, CAL_STEMS), key=lambda z: -z[1][2]):
                e = q.pt(1); head(a, e[0], e[1] - 1, 8.5, opts("calendula", rows=2, n=11, rw=0.27, smallk=1), k=0.5, ang=-90 + dx * 0.6, small=True)
    return a


def _c_seed(a, x, y, s, ang, fill="bark", lw=0.5):
    """One calendula seed: a thick C-shaped curl, s across, opening along ang."""
    t = T(x, y, ang); out, inn = [], []
    for i in range(17):
        th = math.radians(40 + 280 * i / 16); w = 0.32 * math.sin(math.pi * i / 16) ** 0.5 + 0.08
        out.append(t(s * (0.5 + w * 0.5) * math.cos(th), s * (0.5 + w * 0.5) * math.sin(th)))
        inn.append(t(s * (0.5 - w * 0.5) * math.cos(th), s * (0.5 - w * 0.5) * math.sin(th)))
    a.shape(path(out + inn[::-1]), fill, lw)


def cal_seedring(a, x, y, r):
    """What is left of a calendula head: a ring of separate, strongly curled
    brown seeds round the top of the stalk, dry bract tips beneath."""
    for j in range(7):   # the dry bracts, pointing down and out under the ring
        a.leaf(x + (j - 3) * r * 0.22, y + r * 0.2, 90 + (j - 3) * 24, r * 0.75, 0.22, "straw", lw=0.4, detail=False)
    a.oval(x, y, r * 0.35, r * 0.2, 0, "straw", 0.4)
    for j in sorted(range(9), key=lambda j: math.sin(2 * math.pi * j / 9)):
        th = 2 * math.pi * j / 9 - math.pi / 2
        px, py = x + r * 0.78 * math.cos(th), y + r * 0.45 * math.sin(th) - r * 0.1
        _c_seed(a, px, py, r * 0.62, math.degrees(math.atan2(math.sin(th) * 0.6, math.cos(th))), "bark", 0.45)


def cal_seedhead():
    a = Art(); a.ground(88)
    with a.group():
        qs = _bush(a, "calendula", CAL_STEMS, lf_calendula, (15, 10), 4, lang=56, droop=6)
        with a.on(BLOOM):
            for q in qs:
                e = q.pt(1); cal_seedring(a, e[0], e[1] - 1, 6)
    return a


# ============================================================ cosmos
def cos_young():
    a = Art(); a.ground(88)
    with a.group():
        q = shoot(a, (50, 88), (51, 60), (50, 30), 2.2, 1.4, "leaf", lf_cosmos, 4, (20, 12), 50, True, (0.14, 0.8))
        for u, sd in ((0.45, -1), (0.6, 1)):   # side branches, also with their leaves in pairs
            b = q.pt(u); e = (b[0] + sd * 18, b[1] - 22)
            shoot(a, b, (b[0] + sd * 8, b[1] - 6), e, 1.2, 0.9, "leaf", lf_cosmos, 2, (11, 8), 50, True, (0.45, 0.95))
        with a.on(LEAF):
            lf_cosmos(a, 50, 31, -112, 9, _lc("cosmos"), small=True); lf_cosmos(a, 50, 31, -68, 9, _lc("cosmos"), small=True)
    return a


def cos_plant(a, heads):
    q = shoot(a, (50, 88), (51, 70), (50, 52), 2.4, 1.8, "leaf", lf_cosmos, 3, (20, 15), 52, True, (0.15, 0.95))
    for (ex, ey), c in heads:
        b = q.pt(0.9 if ex != 50 else 1.0)
        qq = shoot(a, b, c, (ex, ey), 1.3, 1.0, "leaf", lf_cosmos, 1 if ex != 50 else 0, (12, 12), 50, True, (0.2, 0.2))
    return q


COS_HEADS = [((26, 18), (30, 40)), ((74, 24), (68, 44)), ((52, 10), (50, 32))]


def cos_flower():
    a = Art(); a.ground(88)
    with a.group():
        cos_plant(a, COS_HEADS)
        with a.on(BLOOM):
            for (ex, ey), c in COS_HEADS:
                head(a, ex, ey - 1, 10, opts("cosmos"), k=0.66, ang=-90 + (ex - 50) * 0.8, small=True)
    return a


def seed_burst(a, x, y, r, col="dark"):
    """Cosmos gone to seed: a loose starburst of long narrow dark seeds
    pointing outwards from the top of the stalk."""
    for j in range(13):
        an = -205 + 230 * j / 12 + 6 * math.sin(j * 2.1)
        e = T(x, y, an)(r * (0.85 + 0.15 * math.sin(j * 1.3)))
        a.ribbon(T(x, y, an)(r * 0.15), T(x, y, an)(r * 0.55), e, 0.9, 1.2, col, lw=0.4)
        for sg in (-1, 1):
            p = T(*e, an + sg * 25)(1.6); a.line(f"M{P(e)} L{P(p)}", 0.35, 0.8)
    a.dot(x, y, 1.2, "straw")


def cos_seedhead():
    a = Art(); a.ground(88)
    with a.group():
        cos_plant(a, COS_HEADS)
        with a.on(BLOOM):
            for (ex, ey), c in COS_HEADS:
                seed_burst(a, ex, ey, 8.5)
    return a


# ============================================================ zinnia
ZIN_STEMS = [(44, -30, 30, -3), (56, 30, 30, 3), (47, -16, 40, -2), (53, 16, 40, 2), (50, 0, 46, 0), (45, -24, 22, -6), (55, 24, 22, 6)]


def zin_young():
    a = Art(); a.ground(88)
    with a.group():
        _bush(a, "zinnia", [(x, dx * 0.7, h * 0.62, b) for x, dx, h, b in ZIN_STEMS[:5]], lf_zinnia, (12, 8), 3, lang=56, opp=True)
    return a


ZIN_TIPS = dome(7, 30, 42, inner=3)


def zin_flower(dry=False):
    """A compact leafy mound with single flowers resting on its surface."""
    a = Art(); a.ground(88)
    with a.group():
        qs = mound(a, "zinnia", lf_zinnia, ZIN_TIPS, (13, 10), 3, opp=True, lang=58, lfill=("straw" if dry else None), col="straw" if dry else "leaf")
        with a.on(BLOOM):
            for (tx, ty) in sorted(ZIN_TIPS, key=lambda p: p[1]):
                if dry:   # papery faded rays still attached round a brown cone of seeds
                    head(a, tx, ty - 1, 7.5, opts("zinnia", fc="straw", cen="bark", ring=None, dots="dark", droop=0.4, dome=1.4, disc=0.42, n=9, smallk=1), k=0.5, small=True)
                else:
                    head(a, tx, ty - 1, 9, opts("zinnia", n=10, smallk=1, ring=None, dots="sun", rim=None), k=0.5, ang=-90 + (tx - 50) * 0.5, small=True)
    return a


# ============================================================ rudbeckia
RUD_STEMS = [(46, -24, 40, -3), (54, 24, 40, 3), (48, -10, 50, -2), (52, 10, 50, 2), (50, 0, 56, 0), (47, -30, 30, -4), (53, 30, 30, 4)]
RUD_ROS = [-170, -10, -150, -30, -128, -52]


def rud_young():
    a = Art(); a.ground(88)
    with a.group():
        rosette(a, 50, 88, lf_rudbeckia, _lc("rudbeckia"), RUD_ROS + [-104, -76], 26)
        _bush(a, "rudbeckia", [(48, -6, 26, -2), (52, 8, 30, 2)], lf_rudbeckia, (11, 8), 3, lang=50, lkw=dict(stem=True))
    return a


RUD_TIPS = dome(8, 32, 44, inner=2)


def rud_flower(seed=False):
    """'Toto': a compact bun, its golden flowers nearly covering the leaves."""
    a = Art(); a.ground(88)
    with a.group():
        rosette(a, 50, 88, lf_rudbeckia, "bark" if seed else _lc("rudbeckia"), RUD_ROS, 20)
        mound(a, "rudbeckia", lf_rudbeckia, RUD_TIPS, (12, 8), 3, lang=50, lkw=dict(stem=True), lfill="straw" if seed else None,
              col="straw" if seed else "leaf")
        with a.on(BLOOM):
            for tx, ty in sorted(RUD_TIPS, key=lambda p: p[1]):
                if seed:   # the rays gone: a dark cone left on the bare stalk
                    head(a, tx, ty, 4, opts("rudbeckia", n=0, disc=0.75, dome=1.2, ring=None, dots="dark", cup=None, rim=None), k=0.5, small=True)
                else:
                    head(a, tx, ty - 1, 10, opts("rudbeckia", rim=None), k=0.5, ang=-90 + (tx - 50) * 0.5, small=True)
    return a


def rud_dormant():
    a = Art(); a.ground(88)
    with a.group():
        rosette(a, 50, 88, lf_rudbeckia, _lc("rudbeckia"), [-176, -4, -160, -20, -142, -38, -118, -62], 22)
        for x0, x1, y1 in ((44, 34, 42), (56, 66, 48)):
            dead_stem(a, x0, 88, x1, y1, 1.6, "bark")
            with a.on(BLOOM):
                head(a, x1, y1, 4, opts("rudbeckia", n=0, disc=0.75, dome=1.2, ring=None, dots="dark", cup=None), k=0.5, small=True)
    return a


BLOOM_DRAW = {"daisies_" + k: fn for k, fn in {
    "sunflower": bl_sunflower, "calendula": bl_calendula, "cosmos": bl_cosmos, "zinnia": bl_zinnia,
    "rudbeckia": bl_rudbeckia, "marigold": bl_marigold, "oxeye": bl_oxeye, "cornchamomile": bl_cornchamomile,
    "feverfew": bl_feverfew, "aster": bl_aster, "african": bl_african, "helipterum": bl_helipterum,
    "pineapple": bl_pineapple, "cornflower": bl_cornflower, "globethistle": bl_globethistle, "scabiosa": bl_scabiosa,
    "devilsbit": bl_devilsbit, "rampion": bl_rampion}.items()}
BLOOMX = {k: dict(kind="daisies_" + _LK[k], fc=pal(k, "flower", "white"), cen=pal(k, "centre", "sun"))
          for k in _LK if "daisies_" + _LK[k] in BLOOM_DRAW}



# ============================================================ French marigold
MARI_STEMS = [(45, -26, 22, -4), (55, 26, 22, 4), (47, -14, 30, -2), (53, 14, 30, 2), (50, 0, 34, 0), (46, -32, 14, -6), (54, 32, 14, 6)]


def mari_head(a, x, y, r, fc, dry=False):
    """A French marigold head at life-stage size: the slim tube of bracts,
    then the double head; dry=True: the brown tube with its brush of
    black, pale-tipped seeds."""
    a.ribbon((x, y + r * 1.0), (x, y + r * 0.5), (x, y), r * 0.4, r * 0.55, "straw" if dry else "deep", lw=0.5)
    if dry:
        for j in range(7):
            an = -90 + (j - 3) * 11; e = T(x, y, an)(r * 0.9)
            a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.7, 0.9, "dark"); a.dot(e[0], e[1], 0.45, "straw")
        return
    head(a, x, y - r * 0.15, r, opts("french-marigold", fc=fc), k=0.48, small=True)


MARI_TIPS = dome(8, 32, 32, inner=3, ih=0.7)


def mari_young():
    a = Art(); a.ground(88)
    with a.group():
        mound(a, "french-marigold", lf_marigold, dome(6, 26, 24), (17, 13), 2, opp=True, lang=50, col="plum", w=(1.3, 0.9))
    return a


def mari_flower(dry=False):
    """A low leafy mound with small double flowers sitting just above it."""
    a = Art(); a.ground(88)
    with a.group():
        mound(a, "french-marigold", lf_marigold, MARI_TIPS, (15, 11), 2, opp=True, lang=50, col="plum", w=(1.3, 0.9), us=(0.25, 0.85))
        with a.on(BLOOM):
            for j, (tx, ty) in enumerate(sorted(MARI_TIPS, key=lambda p: p[1])):
                mari_head(a, tx, ty - 1, 4.4 if dry else 6.6, "sun" if j % 3 == 1 else pal("french-marigold", "flower", "carrot"), dry)
    return a


# ============================================================ ox-eye daisy
OX_ROS = [-172, -8, -152, -28, -130, -50, -110, -70, -90]


def ox_plant(stage):
    a = Art(); a.ground(88); lc = _lc("ox-eye-daisy")
    with a.group():
        if stage in ("young", "dormant"):
            rosette(a, 50, 88, lf_oxeye, lc, OX_ROS, 28 if stage == "young" else 24)
            return a
        rosette(a, 50, 88, lf_oxeye, lc, OX_ROS[:6], 22)
        stems = [(49, -16, 62, -3), (51, 14, 70, 3), (50, 0, 54, 1)]
        qs = []
        for x0, dx, h, b in stems:
            q = shoot(a, (x0, 88), (x0 + b, 88 - h * 0.5), (x0 + dx, 88 - h), 1.5, 1.2, "leaf", lf_oxeye_stem, 3, (10, 6), 40,
                      us=(0.3, 0.7), lfill=lc, side=1 if dx >= 0 else -1)
            qs.append(q)
        with a.on(BLOOM):
            for q in qs:
                e = q.pt(1)
                if stage == "flower":
                    head(a, e[0], e[1] - 1, 10.5, opts("ox-eye-daisy"), k=0.6, small=True)
                else:   # rays gone: a brownish disc on the stem
                    head(a, e[0], e[1], 4.4, opts("ox-eye-daisy", n=0, disc=0.8, cen="bark", dome=0.35, dots="dark"), k=0.6, small=True)
    return a


# ============================================================ corn chamomile
CC_STEMS = [(46, -34, 30, -14), (54, 34, 30, 14), (47, -18, 44, -8), (53, 20, 46, 8), (50, 2, 54, 2)]


def cc_plant(stage):
    """Sprawling at the base, then upright: branched stems leafy all along."""
    a = Art(); a.ground(88)
    with a.group():
        if stage == "young":   # a low spreading tuft, leaves all along the stems
            tips = [(14, 82), (86, 82), (22, 72), (78, 70), (36, 64), (64, 62), (50, 60)]
            mound(a, "corn-chamomile", lf_cornchamomile, tips, (13, 9), 4, lang=55, col="sage", w=(1.4, 1.0), us=(0.15, 0.95), spread=0.15)
            return a
        tips = dome(7, 34, 50, inner=2)
        mound(a, "corn-chamomile", lf_cornchamomile, tips, (14, 9), 4, lang=55, col="sage", w=(1.4, 0.9), us=(0.12, 0.8))
        with a.on(BLOOM):
            for tx, ty in sorted(tips, key=lambda p: p[1]):
                if stage == "flower":
                    head(a, tx, ty - 1, 7.5, opts("corn-chamomile"), k=0.55, small=True)
                else:   # the rays wither and hang; the disc grows into a brownish-yellow cone
                    head(a, tx, ty - 1, 5.5, opts("corn-chamomile", fc="straw", cen="seed", dots="bark", droop=1.4, dome=1.4, disc=0.5, n=10), k=0.55, small=True)
    return a


# ============================================================ wild chamomile (pineappleweed)
PW_TIPS = dome(9, 32, 26, inner=4, ih=0.75)


def pw_plant(stage):
    """A low, dense, leafy cushion with many small cones among and just
    above the leaves."""
    a = Art(); a.ground(88); fc = pal("wild-chamomile", "flower", "pear")
    with a.group():
        if stage == "young":
            rosette(a, 50, 88, lf_pineapple, _lc("wild-chamomile"), [-170, -10, -146, -34, -120, -60, -90], 20)
            return a
        mound(a, "wild-chamomile", lf_pineapple, PW_TIPS, (14, 10), 3, lang=55, w=(1.2, 0.9), us=(0.15, 0.85), spread=0.4)
        with a.on(BLOOM):
            for tx, ty in sorted(PW_TIPS, key=lambda p: p[1]):
                cone_head(a, tx, ty, 2.4, fc, small=True, dry=stage == "seedhead")
    return a


# ============================================================ feverfew
def ff_plant(stage):
    """A bushy yellow-green clump, leafy all the way up, with loose
    flat-topped clusters of small daisies on top."""
    a = Art(); a.ground(88); lc = _lc("feverfew")
    with a.group():
        if stage in ("young", "dormant"):
            rosette(a, 50, 88, lf_feverfew, lc, [-168, -12, -146, -34, -122, -58, -100, -80], 26 if stage == "young" else 20)
            if stage == "young":   # a compact bushy clump
                mound(a, "feverfew", lf_feverfew, dome(5, 24, 34), (15, 11), 3, lang=52, us=(0.15, 0.95), spread=0.5)
            else:   # the old flowering stems, dead and cut back
                for x0, x1, y1 in ((44, 40, 66), (50, 50.5, 62), (56, 60, 67)):
                    dead_stem(a, x0, 88, x1, y1, 1.6, "bark")
                    a.line(f"M{f(x1 - 1.2)},{f(y1)} l2.4,-0.6", 0.7, 0.8)
            return a
        dry = stage == "seedhead"
        tips = dome(5, 24, 48)
        qs = mound(a, "feverfew", lf_feverfew, tips, (18, 12), 5, lang=50, us=(0.08, 0.95), spread=0.5,
                   lfill=None)
        tops = []
        for (tx, ty), q in zip(tips, qs):   # each stem ends in a loose flat-topped cluster just above the leaves
            for ox in (-5, 0, 5):
                hx, hy = tx + ox * 1.1, ty - 7 - (2 if ox == 0 else 0)
                if ox:
                    a.line(f"M{f(tx)},{f(ty)} Q{f(tx + ox * 0.3)},{f((ty + hy) / 2)} {f(hx)},{f(hy)}", 0.8, 0.85)
                else:
                    a.line(f"M{f(tx)},{f(ty)} L{f(hx)},{f(hy)}", 0.8, 0.85)
                tops.append((hx, hy))
        with a.on(BLOOM):
            for tx, ty in sorted(set(tops), key=lambda p: p[1]):
                if not dry:
                    head(a, tx, ty, 5.8, opts("feverfew", rim=None), k=0.6, small=True)
                else:
                    head(a, tx, ty, 2.8, opts("feverfew", n=0, disc=0.95, cen="bark", dots="dark", dome=0.4), k=0.6, small=True)
    return a


# ============================================================ aster
AS_STEMS = [(44, -26, 44, -6), (56, 26, 44, 6), (46, -14, 54, -3), (54, 14, 54, 3), (50, 0, 58, 0), (45, -32, 32, -8), (55, 32, 32, 8)]


def as_plant(stage):
    a = Art(); a.ground(88); lc = _lc("aster")
    with a.group():
        if stage == "dormant":   # old stems cut down to stubs; tufts of new green shoots at the soil
            for x0, h in ((38, 9), (44, 12), (50, 10), (56, 13), (62, 9)):
                a.ribbon((x0, 88), (x0, 88 - h * 0.5), (x0 + 0.4, 88 - h), 2.2, 1.9, "bark", lw=0.7)
                a.line(f"M{f(x0 - 1.1)},{f(88 - h)} l2.6,-0.7", 0.8, 0.8)
            for x0 in (32, 50, 68):
                tuft(a, x0, 88, 5, 9, lc)
            return a
        young = stage == "young"; dry = stage == "seedhead"
        st = [(x, dx * (0.6 if young else 1), h * (0.66 if young else 1), b) for x, dx, h, b in AS_STEMS]
        qs = _bush(a, "aster", st, lf_aster, (12, 7), 5 if young else 4, lang=42, col="straw" if dry else "leaf", w=(1.4, 0.9),
                   lfill="straw" if dry else lc)
        if young:
            return a
        heads = []
        for q, (x0, dx, h, b) in zip(qs, st):   # loose leafy sprays of small heads on wiry branches
            for u, sd in ((0.62, -1), (0.78, 1), (1.0, 0)):
                x, y = q.pt(u)
                e = (x + sd * 6, y - 4) if sd else (x, y)
                if sd:
                    a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.6, 0.85)
                heads.append(e)
        with a.on(BLOOM):
            for x, y in sorted(heads, key=lambda p: p[1]):
                if dry:   # a small fluffy grey-white seed head
                    for j in range(9):
                        e = T(x, y - 2, -90 + (j - 4) * 30)(3.2); a.line(f"M{f(x)},{f(y - 2)} L{P(e)}", 0.4, 0.45)
                    a.oval(x, y - 2, 2.2, 2.0, 0, "white", 0.4)
                else:
                    head(a, x, y - 1, 5.8, opts("aster", rw=0.2, n=16, smallk=1, rim=None), k=0.62, small=True)
    return a


# ============================================================ African daisy
AF_STEMS = [(44, -34, 16, -10), (56, 34, 16, 10), (47, -20, 24, -6), (53, 20, 24, 6), (50, 0, 28, 0)]
AF_STALK = [(10, 42), (-10, 40), (4, 52), (-4, 54), (0, 62)]   # each stem's flower stalk: how far it leans, how high its head stands


def af_plant(stage):
    a = Art(); a.ground(88); lc = _lc("african-daisy")
    with a.group():
        young = stage == "young"
        st = [(x, dx * (0.8 if young else 1), h * (0.8 if young else 1), b) for x, dx, h, b in AF_STEMS]
        qs = _bush(a, "african-daisy", st, lf_african, (15, 11), 4, lang=50, w=(2.0, 1.4), col="leaf")
        a.ribbon((44, 88), (50, 86), (56, 88), 4, 4, "bark", lw=0.7)   # woody at the base
        if young:
            return a
        tops = []
        for q, (lean, hh) in zip(qs, AF_STALK):   # long bare stalks lift the heads above the leaves
            b = q.pt(0.9); e = (b[0] + lean, 88 - hh)
            a.ribbon(b, ((b[0] + e[0]) / 2 - lean * 0.3, (b[1] + e[1]) / 2), e, 1.2, 1.0, "leaf", lw=0.6)
            tops.append(e)
        with a.on(BLOOM):
            for hx, hy in sorted(tops, key=lambda h: h[1]):
                if stage == "flower":
                    head(a, hx, hy - 1, 11, opts("african-daisy", rim=None, disc=0.3), k=0.55, small=True)
                else:   # closed, the rays withered, a ring of hard seeds round the edge
                    for j in range(8):
                        e = (hx + 3.8 * math.cos(j * math.pi / 4), hy - 1 + 1.9 * math.sin(j * math.pi / 4))
                        a.oval(e[0], e[1], 1.2, 0.8, j * 45, "bark", 0.4)
                    a.oval(hx, hy - 1, 3.0, 1.6, 0, "straw", 0.5)
                    for j in range(5):
                        a.leaf(hx + (j - 2) * 1.0, hy - 1.5, -90 + (j - 2) * 10, 4.2, 0.28, "bark", lw=0.4, detail=False)
    return a


# ============================================================ Helipterum
HL_STEMS = [(46, -18, 62, -4), (54, 16, 66, 4), (49, -4, 72, -1), (51, 26, 46, 6)]


def hl_plant(stage):
    a = Art(); a.ground(88); lc = _lc("helipterum-rosum")
    with a.group():
        young = stage == "young"
        st = [(x, dx * (0.6 if young else 1), h * (0.6 if young else 1), b) for x, dx, h, b in HL_STEMS]
        qs = _bush(a, "helipterum-rosum", st, lf_helipterum, (10, 7), 5 if young else 4, lang=40, w=(1.1, 0.8), col="sage",
                   lfill="straw" if stage == "seedhead" else lc)
        if young:
            return a
        with a.on(BLOOM):
            for j, (q, stm) in enumerate(zip(qs, st)):
                e = q.pt(1)
                if stage == "flower" and j == 3:   # a bud, nodding before it opens
                    a.line(f"M{P(e)} q2,-3 4,0", 0.8, 0.85); bud_side(a, e[0] + 4, e[1], 4, "helipterum-rosum", 100, 0.6)
                elif stage == "flower":
                    head(a, e[0], e[1] - 1, 10, opts("helipterum-rosum"), k=0.55, small=True)
                else:   # a fluffy white seed head in a ring of dry papery bracts
                    for jj in range(10):
                        a.leaf(e[0], e[1], -180 + jj * 20, 5.4, 0.3, "straw", lw=0.4, detail=False)
                    for jj in range(14):
                        p = T(e[0], e[1] - 2, -180 + jj * 13)(5.6); a.line(f"M{f(e[0])},{f(e[1] - 2)} L{P(p)}", 0.4, 0.45)
                    a.oval(e[0], e[1] - 2.4, 4.4, 3.4, 0, "white", 0.5)
    return a



def lf_first(a, x, y, ang, L, fill, small=True, teeth=False):
    """A seedling's first true leaf: a small oval blade on a stalk,
    smooth or toothed."""
    pet = 0.38 * L; BL = L - pet
    A = stalk_to(a, x, y, ang, pet, 0.9, 0.7, fill)
    top, bot = simple_edges(BL, BL * 0.62, prof(0.45, "round", "point", bp=0.6, tp=0.9))
    if teeth:
        top = serrate(top, 1, max(1.2, BL * 0.16), 0.5, "saw", BL, 0.2, 0.9); bot = serrate(bot, -1, max(1.2, BL * 0.16), 0.5, "saw", BL, 0.2, 0.9)
    draw_leaf(a, A[0], A[1], ang, top, bot, fill, 0.7, mid=[(0, 0), (0.8 * BL, 0)], midw=0.45)


# ============================================================ cornflower
def cf_plant(stage):
    a = Art(); a.ground(88); lc = _lc("cornflower"); fc = pal("cornflower", "flower", "blue"); cen = pal("cornflower", "centre", "plum")
    with a.group():
        if stage == "young":
            for x0, dx, h in ((48, -8, 40), (52, 6, 46), (50, -1, 30)):
                shoot(a, (x0, 88), (x0, 88 - h * 0.5), (x0 + dx, 88 - h), 1.4, 1.0, "sage", lf_cornflower, 5, (16, 9), 32, us=(0.08, 0.9), lfill=lc)
            return a
        dry = stage == "seedhead"
        q = shoot(a, (50, 88), (51, 66), (50, 40), 1.6, 1.3, "straw" if dry else "sage", lf_cornflower, 4, (18, 12), 34, us=(0.1, 0.8), lfill="straw" if dry else lc)
        tops = []
        for u, dx, h in ((0.0, -22, 18), (0.0, 18, 22), (0.0, -6, 22), (0.0, 8, 10)):   # wiry branches in the upper half
            b = q.pt(1.0) if dx in (-6, 8) else q.pt(0.85)
            e = (b[0] + dx, b[1] - h)
            shoot(a, b, (b[0] + dx * 0.2, (b[1] + e[1]) / 2), e, 1.0, 0.8, "straw" if dry else "sage", lf_cornflower, 1, (10, 10), 30, us=(0.4, 0.4),
                  lfill="straw" if dry else lc)
            tops.append(e)
        with a.on(BLOOM):
            for x, y in sorted(tops, key=lambda p: p[1]):
                cornflower_head(a, x, y + 1, 0.36, fc, cen, small=True, dry=dry)
    return a


# ============================================================ globe thistle
def gt_plant(stage):
    a = Art(); a.ground(88); lc = _lc("blue-globe-thistle"); fc = pal("blue-globe-thistle", "flower", "blue")
    with a.group():
        if stage == "young":
            with a.on(LEAF):
                for j, ang in enumerate(sorted([-170, -10, -146, -34, -120, -60, -90], key=lambda g: -abs(g + 90))):
                    lf_globethistle(a, 50, 88, ang, 30 * (0.75 + 0.25 * (1 - abs(ang + 90) / 90)), lc, small=True, under=(j in (1, 4)))
            return a
        dry = stage in ("seedhead", "dormant")
        sc = "straw" if dry else "white"
        tops = []
        stems = [(48, -10, 74), (53, 12, 66)] if stage != "dormant" else [(47, -8, 62), (53, 10, 54)]
        for x0, dx, h in stems:
            q = shoot(a, (x0, 88), (x0, 88 - h * 0.5), (x0 + dx, 88 - h), 2.0, 1.4, sc,
                      lf_globethistle if stage != "dormant" else None, 3, (20, 13), 50, us=(0.12, 0.5), lfill="straw" if dry else lc)
            tops.append(q.pt(1))
            if stage != "dormant":
                b = q.pt(0.7); e = (b[0] + dx * 1.6 + (10 if dx > 0 else -10), b[1] - 14)
                a.ribbon(b, ((b[0] + e[0]) / 2, b[1] - 4), e, 1.3, 1.1, sc, lw=0.6); tops.append(e)
        if stage == "dormant":
            with a.on(LEAF):
                for ang in (-166, -14, -140):
                    lf_globethistle(a, 50, 88, ang, 18, lc, small=True)
        with a.on(BLOOM):
            for x, y in tops:
                globe_ball(a, x, y - 5, 5.6, fc, small=True, dry=dry)
    return a


# ============================================================ scabious (Scabiosa)
def scab_ball(a, x, y, r):
    """A seed head of scabious: a round straw-coloured ball, each seed's
    papery collar showing as a ring with a star of dark bristles."""
    a.oval(x, y, r, r, 0, "straw", 0.6)
    for px, py, pz in [p for p in _sphere(12) if p[2] > 0.1]:
        e = (x + px * r * 0.75, y + py * r * 0.75)
        a.oval(e[0], e[1], r * 0.18, r * 0.18, 0, None, 0.35)
        for kk in range(5):
            p2 = T(*e, kk * 72 + px * 30)(r * 0.26); a.line(f"M{P(e)} L{P(p2)}", 0.35, 0.85, "dark")


def sc_plant(stage):
    a = Art(); a.ground(88); lc = _lc("scabiosa"); fc = pal("scabiosa", "flower", "mauve"); pin = pal("scabiosa", "centre", "white")
    with a.group():
        if stage in ("young", "dormant"):
            rosette(a, 50, 88, lf_scabiosa, lc, [-168, -12, -148, -32, -126, -54, -100, -78], 28 if stage == "young" else 22)
            return a
        rosette(a, 50, 88, lf_scabiosa, lc, [-168, -12, -146, -34, -120, -60], 22)
        tops = []
        for x0, dx, h in ((48, -24, 52), (52, 22, 54), (49, -10, 64), (51, 9, 66), (50, 0, 58)):
            q = shoot(a, (x0, 88), (x0 + dx * 0.2, 88 - h * 0.5), (x0 + dx, 88 - h), 1.2, 0.9, "sage", lf_scabiosa, 1, (8, 8), 46, True,
                      (0.3, 0.3), lfill=lc, lkw=dict(fine=True))
            tops.append(q.pt(1))
        with a.on(BLOOM):
            for x, y in sorted(tops, key=lambda p: p[1]):
                if stage == "flower":
                    pincushion(a, x, y - 1, 8.5, fc, pin, k=0.6, small=True)
                else:
                    scab_ball(a, x, y - 3, 4.4)
    return a


# ============================================================ devil's-bit scabious
def db_plant(stage):
    a = Art(); a.ground(88); lc = _lc("devil-s-bit-scabious"); fc = pal("devil-s-bit-scabious", "flower", "lilac")
    with a.group():
        if stage in ("young", "dormant"):
            L = 32 if stage == "young" else 27
            with a.on(LEAF):   # a flat rosette seen from a little above: leaves lying out on the soil all round
                for ang, k in ((-150, 0.7), (-30, 0.7), (-120, 0.55), (-60, 0.55), (-178, 1.0), (-2, 1.0), (162, 0.62), (18, 0.62), (128, 0.42), (52, 0.42), (90, 0.34)):
                    lf_devilsbit(a, 50, 84, ang, L * k, lc, small=True)
            return a
        rosette(a, 50, 88, lf_devilsbit, lc, [-172, -8, -152, -28, -130, -50], 22)
        tops = []
        for x0, dx, h in ((48, -10, 70), (52, 12, 62)):
            q = shoot(a, (x0, 88), (x0, 88 - h * 0.5), (x0 + dx, 88 - h), 1.3, 1.0, "leaf", lf_devilsbit, 2, (9, 7), 40, True, (0.3, 0.55),
                      lfill=lc, lkw=dict(stem=True))
            e = q.pt(1); tops.append(e)
            b = q.pt(0.78)
            for sd in (-1, 1):   # the side branches, in a pair
                e2 = (b[0] + sd * 9, b[1] - 9)
                a.line(f"M{P(b)} Q{f(b[0] + sd * 5)},{f(b[1] - 2)} {P(e2)}", 0.9, 0.85); tops.append(e2)
        with a.on(BLOOM):
            for x, y in tops:
                ball_head(a, x, y - 3, 4.4 if (x, y) in tops[::3] else 3.6, fc, small=True, dry=stage == "seedhead")
    return a


# ============================================================ Oxford rampion
def rp_plant(stage):
    a = Art(); lc = _lc("oxford-rampion"); fc = pal("oxford-rampion", "flower", "plum")
    if stage == "dormant":
        a.ground(88)
        with a.group():
            rosette(a, 50, 88, lf_rampion, lc, [-150, -30, -110], 13)
        return a
    a.ground(88)
    with a.group():
        if stage == "young":
            rosette(a, 50, 88, lf_rampion, lc, [-160, -20, -138, -42, -116, -64, -90], 32)
            return a
        dry = stage == "seedhead"
        rosette(a, 50, 88, lf_rampion, "straw" if dry else lc, [-160, -20, -136, -44], 22)
        tops = []
        for x0, c, e in (((48, 88), (22, 66), (24, 38)), ((52, 88), (80, 64), (74, 40)), ((50, 88), (40, 52), (50, 24))):
            q = shoot(a, x0, c, e, 1.3, 1.0, "straw" if dry else "leaf", lf_aster, 4, (11, 7), 36, us=(0.15, 0.75), lfill="straw" if dry else lc)
            tops.append(e)
        with a.on(BLOOM):
            for x, y in tops:
                rampion_head(a, x, y - 1.5, 5.4, fc, small=True, dry=dry, lc="straw" if dry else lc)
    return a


# ============================================================ Senecio 'Angel Wings'
def se_plant(stage):
    a = Art(); a.ground(88); lc = _lc("senecio-angel-wings")
    with a.group():
        a.ribbon((50, 88), (50, 86), (50, 82), 4.4, 3.8, "sage", lw=0.7)   # the short thick stem
        if stage == "young":
            rosette(a, 50, 84, lf_senecio, lc, [-160, -20, -124, -56, -90], 30)
        elif stage == "crop":
            with a.on(LEAF):
                for ang, L, dx in ((-172, 36, -2), (-8, 36, 2), (-150, 40, -1), (-30, 40, 1), (-124, 42, 0), (-56, 42, 0), (-102, 40, 0), (-80, 40, 0), (-90, 30, 0)):
                    lf_senecio(a, 50 + dx, 82, ang, L, lc, small=True)
        else:
            with a.on(LEAF):
                for ang, L, col in ((-176, 24, "bark"), (-6, 22, "straw")):   # outer leaves browned and collapsed
                    lf_senecio(a, 50, 86, ang + (8 if ang < -90 else -8), L, col, small=True)
            rosette(a, 50, 83, lf_senecio, lc, [-140, -40, -110, -70], 22)
    return a


STAGE = {
    "sunflower": {"seed": sown("sunflower"), "seedling": sf_seedling, "young": sf_young, "flower": sf_flower, "seedhead": sf_seedhead},
    "calendula": {"seed": sown("calendula"), "seedling": seedling(("oblong", 12, 5.6), 13, true=lambda a, x, y: lf_calendula(a, x, y, -84, 14, _lc("calendula"), small=True)),
                  "young": cal_young, "flower": cal_flower, "seedhead": cal_seedhead},
    "cosmos": {"seed": sown("cosmos"), "seedling": seedling(("narrow", 14, 3.2), 14, true=lambda a, x, y: [lf_cosmos(a, x, y, g, 9, _lc("cosmos"), small=True) for g in (-112, -68)]),
               "young": cos_young, "flower": cos_flower, "seedhead": cos_seedhead},
    "zinnia": {"seed": sown("zinnia"), "seedling": seedling(("oval", 10, 6.4), 13, true=lambda a, x, y: [lf_zinnia(a, x, y, g, 9, _lc("zinnia"), small=True) for g in (-122, -58)]),
               "young": zin_young, "flower": zin_flower, "seedhead": lambda: zin_flower(True)},
    "rudbeckia": {"seed": sown("rudbeckia"), "seedling": seedling(("oval", 8, 5), 10, true=lambda a, x, y: [lf_rudbeckia(a, x, y, g, L, _lc("rudbeckia"), small=True) for g, L in ((-100, 10), (-66, 7))]),
                  "young": rud_young, "flower": rud_flower, "seedhead": lambda: rud_flower(True), "dormant": rud_dormant},
    "french-marigold": {"seed": sown("french-marigold"),
                        "seedling": seedling(("narrow", 9, 3.2), 12, stemw=2.0, stemc="plum", true=lambda a, x, y: [lf_marigold(a, x, y, g, 9, _lc("french-marigold"), small=True) for g in (-112, -68)]),
                        "young": mari_young, "flower": mari_flower, "seedhead": lambda: mari_flower(True)},
    "ox-eye-daisy": {"seed": sown("ox-eye-daisy"), "seedling": seedling(("round", 6.5, 5.6), 9, true=lambda a, x, y: lf_oxeye(a, x, y, -86, 11, _lc("ox-eye-daisy"), small=True)),
                     "young": lambda: ox_plant("young"), "flower": lambda: ox_plant("flower"), "seedhead": lambda: ox_plant("seedhead"),
                     "dormant": lambda: ox_plant("dormant")},
    "corn-chamomile": {"seed": sown("corn-chamomile"), "seedling": seedling(("oval", 7, 4.4), 9, true=lambda a, x, y: [lf_cornchamomile(a, x, y, g, 9, _lc("corn-chamomile"), small=True) for g in (-104, -72)]),
                       "young": lambda: cc_plant("young"), "flower": lambda: cc_plant("flower"), "seedhead": lambda: cc_plant("seedhead")},
    "wild-chamomile": {"seed": sown("wild-chamomile"), "seedling": seedling(("oval", 5.4, 3.2), 8, true=lambda a, x, y: [lf_pineapple(a, x, y, g, 8, _lc("wild-chamomile"), small=True) for g in (-104, -72)]),
                       "young": lambda: pw_plant("young"), "flower": lambda: pw_plant("flower"), "seedhead": lambda: pw_plant("seedhead")},
    "feverfew": {"seed": sown("feverfew"), "seedling": seedling(("round", 6.5, 5.6), 9, true=lambda a, x, y: lf_feverfew(a, x, y, -88, 11, _lc("feverfew"), small=True)),
                 "young": lambda: ff_plant("young"), "flower": lambda: ff_plant("flower"), "seedhead": lambda: ff_plant("seedhead"),
                 "dormant": lambda: ff_plant("dormant")},
    "aster": {"seed": sown("aster"), "seedling": seedling(("round", 5, 4.4), 8, true=lambda a, x, y: [lf_aster(a, x, y, g, 9, _lc("aster"), small=True) for g in (-104, -74)]),
              "young": lambda: as_plant("young"), "flower": lambda: as_plant("flower"), "seedhead": lambda: as_plant("seedhead"),
              "dormant": lambda: as_plant("dormant")},
    "african-daisy": {"seed": sown("african-daisy"), "seedling": seedling(("oblong", 9, 4.4), 11, true=lambda a, x, y: lf_african(a, x, y, -86, 11, _lc("african-daisy"), small=True)),
                      "young": lambda: af_plant("young"), "flower": lambda: af_plant("flower"), "seedhead": lambda: af_plant("seedhead")},
    "helipterum-rosum": {"seed": sown("helipterum-rosum"), "seedling": seedling(("oval", 6, 3.8), 10, true=lambda a, x, y: [lf_helipterum(a, x, y, g, 9, _lc("helipterum-rosum"), small=True) for g in (-104, -74)]),
                         "young": lambda: hl_plant("young"), "flower": lambda: hl_plant("flower"), "seedhead": lambda: hl_plant("seedhead")},
    "cornflower": {"seed": sown("cornflower"), "seedling": seedling(("oval", 9, 5), 11, true=lambda a, x, y: lf_cornflower(a, x, y, -86, 11, _lc("cornflower"), small=True)),
                   "young": lambda: cf_plant("young"), "flower": lambda: cf_plant("flower"), "seedhead": lambda: cf_plant("seedhead")},
    "blue-globe-thistle": {"seed": sown("blue-globe-thistle"),
                           "seedling": seedling(("oval", 9, 5), 11, true=lambda a, x, y: [lf_globethistle(a, x, y, -100, 11, _lc("blue-globe-thistle"), small=True),
                                                                                          lf_globethistle(a, x, y, -40, 13, _lc("blue-globe-thistle"), small=True, under=True)]),
                           "young": lambda: gt_plant("young"), "flower": lambda: gt_plant("flower"), "seedhead": lambda: gt_plant("seedhead"),
                           "dormant": lambda: gt_plant("dormant")},
    "scabiosa": {"seed": sown("scabiosa"), "seedling": seedling(("oval", 7, 4.6), 9, true=lambda a, x, y: lf_first(a, x, y, -84, 11, _lc("scabiosa"), teeth=True)),
                 "young": lambda: sc_plant("young"), "flower": lambda: sc_plant("flower"), "seedhead": lambda: sc_plant("seedhead"),
                 "dormant": lambda: sc_plant("dormant")},
    "devil-s-bit-scabious": {"seed": sown("devil-s-bit-scabious"), "seedling": seedling(("oval", 7, 4.4), 9, true=lambda a, x, y: lf_first(a, x, y, -84, 11, _lc("devil-s-bit-scabious"))),
                             "young": lambda: db_plant("young"), "flower": lambda: db_plant("flower"), "seedhead": lambda: db_plant("seedhead"),
                             "dormant": lambda: db_plant("dormant")},
    "oxford-rampion": {"seed": sown("oxford-rampion"), "seedling": seedling(("round", 5, 4.4), 8, true=lambda a, x, y: lf_first(a, x, y, -84, 10, _lc("oxford-rampion"))),
                       "young": lambda: rp_plant("young"), "flower": lambda: rp_plant("flower"), "seedhead": lambda: rp_plant("seedhead"),
                       "dormant": lambda: rp_plant("dormant")},
    "senecio-angel-wings": {"young": lambda: se_plant("young"), "crop": lambda: se_plant("crop"), "dormant": lambda: se_plant("dormant")},
}
