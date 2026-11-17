"""Windfall plant drawings: the redraw of the BULBS group, 16 to 17 November 2026.

For William. This file changes every drawing of fourteen plants: snowdrop,
daffodil, tulip, crocus, bluebell, grape hyacinth, puschkinia, snake's head
fritillary, crown imperial, bearded iris, yellow iris, peacock orchid,
winter windflower and cyclamen.

Why: before this, every one of them was made from the same template. All
fourteen had the same tan teardrop bulb, the same little tuft of shoots, the
same green knob for a seed pod and the same strap leaves, whatever the plant.
A crocus has a corm, an iris a rhizome, a fritillary a bulb of bare white
scales, a cyclamen a corky disc; a tulip's leaf is broad and clasps the stem,
a crocus leaf has a white stripe, an iris leaf is a flat sword. So each kind's
drawings are now drawn by hand here, from its written description
(Design/Plants/descriptions/<kind>.json) and photographs.

How the file is laid out
  1. Colours added for this group (COLOURS), and pal(), which reads a kind's
     colours from its description.
  2. Small helpers: band() draws any long leaf (a strap, a sword, a grass
     leaf) along a curve with a chosen outline; petal() draws one petal.
  3. What grows under the ground: tunic() a bulb in a papery skin, corm(),
     white_bulb(), scale_bulb(), knob_tuber(), disc_tuber(), rhizome().
  4. Then one section per plant: its close-up leaf, its close-up flower, a
     small flower for the whole-plant drawings, and its five life stages.
  5. At the foot, the tables plants_all.py and leaves_flowers.py read:
     LEAF_DRAW / BLOOM_DRAW (the new close-up shapes, named bulbs_...),
     LEAFX / BLOOMX (which kind uses which) and STAGE (the life stages).

The same leaf shape is used in a plant's close-up and in all its life-stage
drawings (the one band() call with the same outline), so the two cannot
disagree, which was fault (1) in the check of 16 November.

A note on reading the code: every drawing is on a 100 by 100 grid, x across
and y DOWN (so a smaller y is higher up). T(x, y, ang) gives a little helper
that measures along a direction: T(50, 60, -90)(10) is the point 10 squares
straight up from (50, 60). Colours are always names (sage, white, bulbs_iris),
never codes, so one drawing makes both the light and the dark picture.
"""
import json, math, os
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM, LW
import plants as S10

HERE = os.path.dirname(os.path.abspath(__file__))
G = 66   # the soil line in a whole-plant drawing

# ================================================================ colours
# (light, dark). The dark values are lighter or richer so that they still
# stand out on the dark card (#142414).
COLOURS = {
    "bulbs_yellow":  ("#F8DA3C", "#EDCD3A"),   # a true clear yellow: daffodil petals, yellow iris
    "bulbs_gold":    ("#F4C21E", "#E6B521"),   # a deeper golden yellow: the daffodil's trumpet
    "bulbs_crocus":  ("#8A6CC8", "#A088DA"),   # crocus 'Grand Maitre': rich lilac-violet
    "bulbs_bluebell": ("#5A58C0", "#7E7CD8"),  # bluebell: violet-blue
    "bulbs_muscari": ("#3B4FB0", "#6478D0"),   # grape hyacinth: deep cobalt blue
    "bulbs_muscari_pale": ("#9AAAE2", "#8C9CD8"),   # the paler top flowers of the grape hyacinth
    "bulbs_maroon":  ("#6E2F55", "#9A5A82"),   # snake's head fritillary: dull maroon-purple
    "bulbs_chequer": ("#D9B4CE", "#C79CBC"),   # the paler squares of its chequers: pink-lilac
    "bulbs_iris":    ("#5E3C8F", "#8A6CC0"),   # bearded iris falls: deep violet-purple
    "bulbs_iris_light": ("#8E70C4", "#A68CD6"),   # its standards, a lighter violet
    "bulbs_eye":     ("#4A1A35", "#8A4A6E"),   # peacock orchid: the very dark maroon eye
    "bulbs_rose":    ("#E58AB0", "#D27CA0"),   # winter windflower: rose-pink
    "bulbs_cream":   ("#F1E3B2", "#BFAF7C"),   # crown imperial bulb: fleshy cream-yellow scales
    "bulbs_silver":  ("#C8D4C2", "#7F927E"),   # cyclamen leaf marbling: silver-grey
    "bulbs_rhizome": ("#C69A84", "#8F6A5C"),   # yellow iris rhizome: brownish pink
    "bulbs_water":   ("#A9C8E0", "#3E5C74"),   # pond water by the yellow iris
}

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


# ================================================================ helpers
def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


def lerp(p, q, u):
    return (p[0] + (q[0] - p[0]) * u, p[1] + (q[1] - p[1]) * u)


# Outlines for long leaves: how wide the leaf is at t (0 at the base, 1 at
# the tip), as a share of its full width.
def _tip(t, start, kind):
    if t <= start:
        return 1.0
    v = min(1.0, (t - start) / (1 - start))
    if kind == "blunt":      # a rounded end: snowdrop, daffodil, bluebell
        return max(0.0, 1 - v * v) ** 0.5
    if kind == "point":      # tapering gradually to a point: fritillary, crocus
        return math.cos(math.pi / 2 * v) ** 0.9
    return (1 - v) ** 0.85   # "sword": straight sides, then a sharp point


def strap(tip="blunt", start=0.86, base=0.85):
    """A leaf the same width nearly all the way, narrowing a little at the
    foot (base) and ending in the chosen tip from start onwards."""
    return lambda t: (base + (1 - base) * min(1.0, t / 0.12)) * _tip(t, start, tip)


def lance(widest=0.3, foot=0.78, tipk=0.8):
    """Broad near the foot and tapering to a point: tulip, crown imperial."""
    def fn(t):
        if t < widest:
            return foot + (1 - foot) * math.sin(math.pi / 2 * t / widest)
        return math.cos(math.pi / 2 * (t - widest) / (1 - widest)) ** tipk
    return fn


def band(a, p0, c, p1, W, fill, prof, lw=LW, n=36, shade=0.11, veins=(), vla=0.28, vw=0.4,
         mid=0.0, midla=0.4, midc="line", stripe=None, stripew=0.26, stripefa=1, gloss=False, hood=False, edge=None):
    """One long leaf following the curve from p0 (its foot) through c to p1
    (its tip), W wide at its widest, its outline given by prof (above).
    veins: fine lines running its length, each at that share of the half
    width out from the middle. mid: a line down the middle that wide (a
    groove or a midrib). stripe: a coloured band down the middle (the crocus's
    white stripe), laid at strength stripefa (less than 1 for a faint
    band). gloss: a pale shine (bluebell). hood: a tip that curls in
    a little (snowdrop, bluebell). edge: a narrow dark band along both edges,
    the edges turned under (crocus). Returns the curve, so things can be
    put part-way along it."""
    q = Quad(p0, c, p1); L, R, M = [], [], []
    for i in range(n + 1):
        t = i / n; x, y = q.pt(t); an = math.radians(q.ang(t) + 90)
        w = W / 2 * prof(t); nx, ny = math.cos(an), math.sin(an)
        L.append((x + w * nx, y + w * ny)); R.append((x - w * nx, y - w * ny)); M.append((x, y, nx, ny, w, t))
    a.shape(path(L + R[::-1]), fill, lw)
    if shade:
        a.shape(path(L + [(m[0], m[1]) for m in M[::-1]]), "shade", 0, fa=shade)
    inner = [m for m in M if 0.05 < m[5] < 0.86]
    if edge:
        for sg in (1, -1):
            a.shape(path([(m[0] + sg * m[4] * m[2], m[1] + sg * m[4] * m[3]) for m in inner] +
                         [(m[0] + sg * m[4] * 0.72 * m[2], m[1] + sg * m[4] * 0.72 * m[3]) for m in inner[::-1]]), edge, 0, fa=0.35)
    if stripe:
        a.shape(path([(m[0] + m[4] * stripew * m[2], m[1] + m[4] * stripew * m[3]) for m in inner] +
                     [(m[0] - m[4] * stripew * m[2], m[1] - m[4] * stripew * m[3]) for m in inner[::-1]]), stripe, 0, fa=stripefa)
    for o in veins:
        a.line(opath([(m[0] + o * m[4] * m[2], m[1] + o * m[4] * m[3]) for m in M[2:-3:2]]), vw, vla)
    if mid:
        a.line(opath([(m[0], m[1]) for m in M[1:-3:2]]), mid, midla, midc)
    if gloss:
        g = [m for m in M if 0.18 < m[5] < 0.62]
        a.line(opath([(m[0] + m[4] * 0.45 * m[2], m[1] + m[4] * 0.45 * m[3]) for m in g]), max(0.6, W * 0.09), 0.45, "white")
    if hood:   # the tip curls in: a short line across, just below it
        m = M[int(n * 0.93)]
        a.line(f"M{P((m[0] + m[4] * 0.8 * m[2], m[1] + m[4] * 0.8 * m[3]))} Q{P((m[0] - m[4] * 0.1 * m[2] - 0.4 * m[3], m[1] - m[4] * 0.1 * m[3] + 0.4 * m[2]))} {P((m[0] - m[4] * 0.8 * m[2], m[1] - m[4] * 0.8 * m[3]))}", 0.5, 0.4)
    return q


def PROF(name):
    """Petal outlines: width along the petal (0 base, 1 tip) as a share of the widest."""
    return {
        "ovate":    lambda u: math.sin(math.pi * u ** 0.72) ** 0.9,
        "elliptic": lambda u: math.sin(math.pi * u) ** 0.8,
        "obovate":  lambda u: math.sin(math.pi * u ** 1.45) ** 0.72,
        "round":    lambda u: math.sin(math.pi * u ** 1.1) ** 0.5,
        "spoon":    lambda u: (0.3 + 0.7 * math.sin(math.pi / 2 * min(1, u / 0.55))) * (1 if u < 0.7 else max(0.0, 1 - ((u - 0.7) / 0.3) ** 2) ** 0.5),
        "oblong":   lambda u: min(1, (u / 0.12)) ** 0.6 * (1 if u < 0.8 else max(0.0, 1 - ((u - 0.8) / 0.2) ** 2) ** 0.5),
        "lance":    lambda u: math.sin(math.pi * u ** 0.62) ** 1.1,
        "point":    lambda u: math.sin(math.pi * u ** 0.85) ** 0.85 * (1 - 0.3 * u ** 4),
    }[name]


def petal(a, x, y, ang, L, W, fill, prof="ovate", lw=0.9, M=None, shade=0.08, lines=0, linec="line", la=0.28, n=30, bend=0.0):
    """One petal from x,y along ang, L long and W wide. M, if given, bends
    every point (a petal seen at a slant). lines: how many fine lines run
    out along it. bend curves the whole petal sideways (a twisted or swept
    petal). Returns the outline as a list of points."""
    t = T(x, y, ang); pr = PROF(prof) if isinstance(prof, str) else prof
    mp = (lambda p: M(t(*p))) if M else (lambda p: t(*p))
    def sw(u):
        return bend * L * 4 * u * (1 - u) * 0.5 + bend * L * u * u * 0.5
    top = [mp((L * u, W / 2 * pr(u) + sw(u))) for u in [i / n for i in range(n + 1)]]
    bot = [mp((L * u, -W / 2 * pr(u) + sw(u))) for u in [i / n for i in range(n + 1)]]
    pts = top + bot[::-1]
    a.shape(path(pts), fill, lw)
    if shade:
        a.shape(path(top + [mp((L * u, sw(u))) for u in [i / n for i in range(n, -1, -1)]]), "shade", 0, fa=shade)
    for k in range(lines):
        o = (k - (lines - 1) / 2) / max(1, lines) * 1.2
        a.line(opath([mp((L * u, o * W / 2 * pr(u) + sw(u))) for u in (0.1, 0.35, 0.6, 0.82)]), 0.45, la, linec)
    return pts


def squash(cx, cy, kx=1.0, ky=1.0, rot=0.0):
    """Squashes a drawing about (cx, cy) by kx across and ky up and down,
    then turns it by rot degrees: a flat flower seen at a slant."""
    r = math.radians(rot); c, s = math.cos(r), math.sin(r)
    def M(p):
        dx, dy = (p[0] - cx) * kx, (p[1] - cy) * ky
        return (cx + dx * c - dy * s, cy + dx * s + dy * c)
    return M


def ellipse(cx, cy, rx, ry, rot=0.0, n=40, a0=0.0, a1=2 * math.pi):
    r = math.radians(rot); c, s = math.cos(r), math.sin(r)
    out = []
    for i in range(n + 1 if a1 - a0 < 2 * math.pi - 1e-6 else n):
        h = a0 + (a1 - a0) * i / n; x, y = rx * math.cos(h), ry * math.sin(h)
        out.append((cx + x * c - y * s, cy + x * s + y * c))
    return out


def soil_flecks(a, ys=(46, 50, 78, 74)):
    """The few soil marks under a bulb drawn large (as in plants.py)."""
    for (dx, w), dy in zip([(-30, 4), (27, 3), (-24, 3), (28, 4)], ys):
        a.line(f"M{50 + dx},{dy} L{50 + dx + w},{dy}", 0.9, 0.55, "soil")


def water(a, x0, x1, y):
    """Shallow water at a pond edge: a pale band and two ripple lines."""
    with a.on(STEM):
        a.shape(f"M{f(x0)},{f(y)} L{f(x1)},{f(y)} L{f(x1)},{f(y + 5)} L{f(x0)},{f(y + 5)} Z", "bulbs_water", 0, fa=0.7)
        a.line(f"M{f(x0 + 2)},{f(y + 0.2)} L{f(x1 - 1)},{f(y + 0.2)}", 0.9, 0.7, "blue")
        a.line(f"M{f(x0 + 6)},{f(y + 2.6)} q3,-0.8 6,0 q3,0.8 6,0", 0.6, 0.5, "blue")


# ============================================================ underground
def roots(a, x, y, n, L, spread=110, col="soil", lw=0.8, dead=False):
    """A tuft of roots from x,y. dead: the roots dying back in summer:
    shorter, straw-coloured, some broken off."""
    if dead:
        for k in range(n):
            u = (k / (n - 1) - 0.5) if n > 1 else 0; ang = 90 + u * spread
            l = L * (0.35 + 0.25 * ((k * 0.618) % 1))
            e = T(x, y, ang)(l); m = T(x, y, ang + 10)(l * 0.5)
            a.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)}", lw * 0.9, 0.8, "straw")
        return
    a.roots(x, y, n, L, spread, lw=lw, col=col)


def tunic(a, x, y, h, w, fill="seed", nose=1.0, flat=0.0, lean=0.0, lines=True, tuft=True, plate=True, d=1, split=None):
    """A bulb in a papery skin, standing on its base plate at (x, y) and
    h tall, w wide. nose: how long and drawn-out the neck is (bigger is
    longer). flat: one side flatter (a tulip). lean tips the nose sideways.
    split: a patch where the skin has split to show the flesh, in that
    colour (a tulip). Returns the point at the top of the nose."""
    n = 30; right, left = [], []
    for i in range(n + 1):
        s = i / n
        fw = 0.62 + 0.38 * math.sin(math.pi / 2 * s / 0.34) if s < 0.34 else math.cos(math.pi / 2 * (s - 0.34) / 0.66) ** nose
        cx = x + lean * h * s * s; cy = y - h * s
        right.append((cx + w / 2 * fw * (1 - flat), cy)); left.append((cx - w / 2 * fw, cy))
    bottom = [(x + w * 0.31 * math.cos(math.pi * k / 8), y + h * 0.04 * math.sin(math.pi * k / 8)) for k in range(1, 8)]
    a.shape(path(right + left[::-1] + sorted(bottom, key=lambda p: p[0])), fill, lw=0.9 if d < 2 else 1.1)
    a.shape(path(right + [(x + lean * h * (i / n) ** 2, y - h * i / n) for i in range(n, -1, -1)]), "shade", 0, fa=0.11)
    if split:   # the skin split open on one side, the cream flesh showing
        sx = x - w * 0.12; sy = y - h * 0.32
        sp = [(sx - w * 0.16, sy + h * 0.16), (sx - w * 0.2, sy - h * 0.02), (sx - w * 0.1, sy - h * 0.18), (sx + w * 0.02, sy - h * 0.1),
              (sx + w * 0.08, sy + h * 0.06), (sx + w * 0.02, sy + h * 0.2)]
        a.shape(path(sp), split, 0.6)
    if lines:   # the papery skin: a few fine lines up from the base to the nose
        for o in ((-0.24, 0.26) if d < 2 else (-0.3, -0.1, 0.12, 0.32)):
            a.line(opath([(x + lean * h * s * s + o * w * (0.62 + 0.38 * math.sin(math.pi / 2 * min(1, s / 0.34))) * (math.cos(math.pi / 2 * max(0, s - 0.34) / 0.66) ** nose if s > 0.34 else 1) * (1 - flat * (o > 0)),
                               y - h * s) for s in (0.05, 0.25, 0.45, 0.65, 0.82)]), 0.5 if d < 2 else 0.6, 0.38)
    top = (x + lean * h, y - h)
    if tuft:   # the dry papery tip of the nose
        a.line(f"M{P(top)} l{f(-0.5 - lean * 2)},{f(-h * 0.07)} M{P(top)} l{f(0.6 - lean * 2)},{f(-h * 0.08)}", 0.6 if d < 2 else 0.8, 0.7)
    if plate:   # the base plate the roots grow from
        a.line(f"M{f(x - w * 0.3)},{f(y + h * 0.02)} L{f(x + w * 0.3)},{f(y + h * 0.02)}", 1.0 if d < 2 else 1.6, 0.85, "bark")
    return top


def corm(a, x, y, w, h, fill="bark", shoots=1, d=1, shootc="pale"):
    """A corm (crocus, peacock orchid): round and flattened, covered in a
    brown fibrous net, with pointed shoots on top and roots from a flat base.
    (x, y) is the middle of its base."""
    cy = y - h / 2
    pts = [(x + w / 2 * math.cos(th), cy + h / 2 * math.sin(th) * (0.88 if math.sin(th) > 0 else 1)) for th in [2 * math.pi * i / 48 for i in range(48)]]
    pts = [(px, min(py, y)) for px, py in pts]   # a flat base
    a.shape(path(pts), fill, 0.9 if d < 2 else 1.1)
    a.shape(path([p for p in pts if p[0] >= x] + [(x, y), (x, y - h)]), "shade", 0, fa=0.12)
    nl = 4 if d < 2 else 6
    for k in range(nl):   # the fibrous net: lines crossing one way, then the other
        for sg in (1, -1):
            u = (k + 0.5) / nl - 0.5
            p0 = (x + u * w * 0.95 - sg * w * 0.14, cy - h * 0.42); p1 = (x + u * w * 0.95 + sg * w * 0.14, y - h * 0.06)
            if abs(p0[0] - x) < w * 0.44 and abs(p1[0] - x) < w * 0.44:
                a.line(f"M{P(p0)} Q{P(((p0[0] + p1[0]) / 2 + sg * 0.6, (p0[1] + p1[1]) / 2))} {P(p1)}", 0.45 if d < 2 else 0.55, 0.42)
    a.line(f"M{f(x - w * 0.36)},{f(y)} L{f(x + w * 0.36)},{f(y)}", 1.0 if d < 2 else 1.4, 0.85, "dark")   # the flat base
    tops = []
    for k in range(shoots):
        sx = x + (k - (shoots - 1) / 2) * w * 0.26; sh = h * (0.62 if k == (shoots - 1) // 2 else 0.4)
        a.shape(f"M{f(sx - h * 0.1)},{f(cy - h * 0.4)} Q{f(sx - h * 0.05)},{f(cy - h * 0.5 - sh * 0.6)} {f(sx)},{f(cy - h * 0.5 - sh)} "
                f"Q{f(sx + h * 0.05)},{f(cy - h * 0.5 - sh * 0.6)} {f(sx + h * 0.1)},{f(cy - h * 0.4)} Z", shootc, 0.8)
        tops.append((sx, cy - h * 0.5 - sh))
    return tops


def white_bulb(a, x, y, h, w, d=1, fill="white"):
    """A bluebell bulb: white and rounded, with no papery skin; the fleshy
    scales show as faint curves. (x, y) is its base."""
    pts = []
    for i in range(41):
        s = i / 40; fw = math.sin(math.pi * min(1, (s + 0.12) / 1.12)) ** 0.6
        pts.append((x + w / 2 * fw, y - h * s))
    pts = pts + [(2 * x - px, py) for px, py in pts[::-1]]
    a.shape(path(pts), fill, 0.9 if d < 2 else 1.1)
    a.shape(path(pts[:41] + [(x, y - h), (x, y)]), "shade", 0, fa=0.1)
    for o in (-0.22, 0.2):
        a.line(f"M{f(x + o * w)},{f(y - h * 0.08)} Q{f(x + o * w * 1.7)},{f(y - h * 0.5)} {f(x + o * w * 0.3)},{f(y - h * 0.92)}", 0.5, 0.35)
    a.line(f"M{f(x - w * 0.26)},{f(y + 0.3)} L{f(x + w * 0.26)},{f(y + 0.3)}", 1.0, 0.8, "seed")
    return (x, y - h)


def scale_bulb(a, x, y, h, w, fill="white", halves=2, hole=False, d=1):
    """A bulb of a few fat fleshy scales with no papery skin: the snake's
    head fritillary (two white halves) or, with hole=True and many scales, the
    crown imperial (a big round bulb with a hole down the middle where last
    year's stem was). (x, y) is its base."""
    lw = 0.9 if d < 2 else 1.1
    if not hole:
        for k in range(halves):   # each half a fat scale, flat face to the middle
            sg = -1 if k == 0 else 1; gx = x + sg * w * 0.04
            pts = [(gx, y - h * 0.06)]
            for i in range(25):
                th = math.pi * i / 24
                pts.append((gx + sg * w * 0.48 * math.sin(th) ** 0.8, y - h * 0.5 + h * 0.5 * math.cos(th) * (1.0 if i < 12 else 0.94)))
            pts.append((gx, y - h * 0.96))
            a.shape(path(pts), fill, lw)
            if sg > 0:
                a.shape(path(pts[:13] + [(gx, y - h * 0.5)]), "shade", 0, fa=0.1)
            a.line(f"M{f(gx + sg * w * 0.08)},{f(y - h * 0.18)} Q{f(gx + sg * w * 0.26)},{f(y - h * 0.5)} {f(gx + sg * w * 0.1)},{f(y - h * 0.84)}", 0.5, 0.32)
        a.line(f"M{f(x - w * 0.22)},{f(y + 0.2)} L{f(x + w * 0.22)},{f(y + 0.2)}", 1.0 if d < 2 else 1.4, 0.8, "seed")
        return (x, y - h)
    # the crown imperial: a ring of scales round a hole
    cy = y - h * 0.48
    out = ellipse(x, cy, w / 2, h / 2, n=48)
    a.shape(path(out), fill, lw)
    a.shape(path([p for p in out if p[0] >= x] + [(x, y - h * 0.02), (x, y - h)]), "shade", 0, fa=0.1)
    for k, (o, s) in enumerate(((-0.34, 0.9), (0.34, 0.9), (-0.17, 0.98), (0.17, 0.98))):   # the scales, overlapping
        a.line(f"M{f(x + o * w * 0.5)},{f(y - h * 0.04)} Q{f(x + o * w * 1.5)},{f(cy)} {f(x + o * w * 0.55)},{f(y - h * s)}", 0.6 if d < 2 else 0.8, 0.45)
    a.oval(x, y - h * 0.9, w * 0.14, h * 0.07, 0, "dark", 0.7)   # the hole where last year's stem was
    a.line(f"M{f(x - w * 0.3)},{f(y)} L{f(x + w * 0.3)},{f(y)}", 1.2 if d < 2 else 1.6, 0.8, "seed")
    return (x, y - h * 0.9)


def knob_tuber(a, x, y, s, d=1, buds=True, root=True):
    """A winter windflower tuber: an irregular knobbly dark lump like a bit of
    dry wood, with no skin and no clear top or bottom, a few pale buds and
    roots coming from anywhere on it. (x, y) is its middle."""
    if root:
        for ang, L in ((70, 9), (110, 8), (150, 6), (35, 7)):
            e = T(x, y, ang)(s * 5 + L * s * 0.9); m = T(x, y, ang + 12)(s * 5 + L * s * 0.4)
            a.line(f"M{P(T(x, y, ang)(s * 4))} Q{P(m)} {P(e)}", 0.8, 0.8, "soil")
    g = lambda th: 1 + 0.16 * math.cos(3 * th + 1) + 0.1 * math.sin(5 * th + 0.4) + 0.06 * math.cos(8 * th)
    a.polar(x, y, g, 8.6 * s, 5.4 * s, -10, "dark", 0.9 if d < 2 else 1.1)
    for dx, dy, l in ((-3.6, -1.2, 2.6), (1.6, 1.6, 2.4), (3.4, -2.0, 1.8)):   # cracks like dry bark
        a.line(f"M{f(x + dx * s)},{f(y + dy * s)} q{f(l * 0.5 * s)},{f(-0.7 * s)} {f(l * s)},0", 0.6, 0.5, "straw")
    tips = []
    if buds:
        for ang, L in ((-70, 3.0), (-118, 2.4)):
            b = T(x, y, ang)(s * 5.2); e = T(*b, ang - 8)(L * s)
            a.shape(f"M{P(T(*b, ang + 90)(1.0 * s))} Q{P(T(*b, ang)(L * s * 0.6))} {P(e)} Q{P(T(*b, ang)(L * s * 0.6))} {P(T(*b, ang - 90)(1.0 * s))} Z", "pink", 0.7)
            tips.append(e)
    return tips


def disc_tuber(a, x, y, w, h, d=1, top_roots=True):
    """A cyclamen tuber: a flattened corky brown disc, its top slightly
    hollow, roots from the top and the sides as well as below. (x, y) is
    the middle of its top."""
    lw = 0.9 if d < 2 else 1.1
    if top_roots:   # roots from the top edge and the sides, not only below
        for sg in (1, -1):
            a.line(f"M{f(x + sg * w * 0.38)},{f(y + h * 0.05)} Q{f(x + sg * w * 0.62)},{f(y - h * 0.2)} {f(x + sg * w * 0.74)},{f(y + h * 0.16)}", 0.7, 0.75, "soil")
            a.line(f"M{f(x + sg * w * 0.49)},{f(y + h * 0.5)} Q{f(x + sg * w * 0.66)},{f(y + h * 0.56)} {f(x + sg * w * 0.76)},{f(y + h * 0.84)}", 0.7, 0.75, "soil")
    for dx in (-0.22, 0.04, 0.26):
        a.line(f"M{f(x + dx * w)},{f(y + h * 0.95)} Q{f(x + dx * w * 1.4)},{f(y + h * 1.25)} {f(x + dx * w * 1.2)},{f(y + h * 1.55)}", 0.7, 0.75, "soil")
    pts = []
    for i in range(48):
        th = 2 * math.pi * i / 48; c, s_ = math.cos(th), math.sin(th)
        px = x + w / 2 * c * (1 + 0.03 * math.sin(5 * th)); py = y + h / 2 + h / 2 * s_ * (0.8 if s_ < 0 else 1.0)
        pts.append((px, py))
    a.shape(path(pts), "bark", lw)
    a.shape(path(pts[:25] + [(x - w / 2, y + h / 2)]), "shade", 0, fa=0.14)
    a.line(f"M{f(x - w * 0.36)},{f(y + h * 0.12)} Q{f(x)},{f(y + h * 0.34)} {f(x + w * 0.36)},{f(y + h * 0.12)}", 0.6, 0.45)   # the hollow top
    for dx, dy in ((-0.28, 0.55), (0.06, 0.66), (0.3, 0.5), (-0.08, 0.84)):   # corky cracks
        a.line(f"M{f(x + dx * w)},{f(y + dy * h)} l{f(w * 0.08)},{f(-h * 0.06)} l{f(w * 0.05)},{f(h * 0.08)}", 0.5, 0.45, "dark")
    return (x, y + h * 0.2)


def rhizome(a, x0, x1, y, wd, fill="bark", d=1, scars=5, roots_=True, branch=None):
    """A rhizome: a thick knobbly stem lying along the soil from x0 to x1
    (its growing end at x1), wd thick, ringed with old leaf scars, with roots
    underneath. branch: (x, dy) a side branch rising from it."""
    if roots_:
        for k in range(4):
            rx = x0 + (x1 - x0) * (0.15 + 0.22 * k)
            a.roots(rx, y + wd * 0.35, 2, wd * 1.4, 50, lw=0.7)
    segs = 3; pts_top, pts_bot = [], []
    for i in range(61):
        u = i / 60; px = x0 + (x1 - x0) * u
        knob = 1 + 0.16 * abs(math.sin(math.pi * u * segs)) ** 0.6
        end = min(1.0, (u / 0.06) ** 0.5, ((1 - u) / 0.08) ** 0.5)
        hw = wd / 2 * knob * (0.75 + 0.25 * end)
        pts_top.append((px, y - hw)); pts_bot.append((px, y + hw * 0.9))
    a.shape(path(pts_top + pts_bot[::-1]), fill, 0.9 if d < 2 else 1.1)
    a.shape(path([(p[0], p[1] * 0.5 + y * 0.5) for p in pts_top] + pts_bot[::-1]), "shade", 0, fa=0.1)
    for k in range(scars):   # the rings of old leaf scars
        u = (k + 0.6) / (scars + 0.4); px = x0 + (x1 - x0) * u
        a.line(f"M{f(px - 0.6)},{f(y - wd * 0.5)} Q{f(px + 1.2)},{f(y)} {f(px - 0.2)},{f(y + wd * 0.44)}", 0.5, 0.4)
    if branch:
        bx, dy = branch
        a.ribbon((bx, y), (bx + 3, y + dy * 0.5), (bx + 8, y + dy), wd * 0.8, wd * 0.6, fill, lw=0.9, round_tip=True)
    return (x1, y)


# ============================================================ leaf fans
def fan(a, x, y, H, n, fill, W, lean=0.0, spread=1.0, prof=None, veins=(0.45, -0.45), mid=0.0, midla=0.4, base="plum", dead=0, lw=0.9, sheath=True):
    """A flat fan of sword leaves (iris, gladiolus) from (x, y): n leaves,
    the middle ones tallest, all in one flat plane. Each leaf is folded at
    its foot and sits astride the next (equitant), so the feet overlap in a
    V. dead: the outer leaves on each side that are brown and dead (winter).
    base: the colour of the overlapping feet (iris: tinged purple)."""
    prof = prof or strap("sword", 0.62, 1.0)
    tips = []
    order = sorted(range(n), key=lambda k: -abs(k - (n - 1) / 2))   # the outer leaves first, so the inner ones sit inside them
    for k in order:
        u = (k - (n - 1) / 2) / max(1, (n - 1) / 2)    # -1 the outermost on the left, 1 on the right
        hh = H * (1 - 0.32 * abs(u) ** 1.4)
        bx = x + u * W * 0.45
        tip = (x + u * H * 0.32 * spread + lean * hh, y - hh)
        cpt = (bx + u * H * 0.06 * spread + lean * hh * 0.3, y - hh * 0.55)
        isdead = dead and abs(k - (n - 1) / 2) > (n - 1) / 2 - dead
        col = "straw" if isdead else fill
        if isdead:   # a dead leaf: brown, bent over part-way
            tip = (bx + u * hh * 0.7, y - hh * 0.42); cpt = (bx + u * hh * 0.1, y - hh * 0.5)
        band(a, (bx, y), cpt, tip, W, col, prof, lw=lw, veins=() if isdead else veins, mid=0 if isdead else mid, midla=midla)
        tips.append(tip)
    if sheath:   # the folded feet, overlapping
        with a.on(LEAF):
            for k in range(n):
                u = (k - (n - 1) / 2) / max(1, (n - 1) / 2)
                bx = x + u * W * 0.45
                a.shape(f"M{f(bx - W * 0.45)},{f(y)} Q{f(bx - W * 0.2)},{f(y - H * 0.1)} {f(x + u * W * 0.2)},{f(y - H * (0.16 - 0.06 * abs(u)))} "
                        f"L{f(bx + W * 0.45)},{f(y)} Z", base, 0, fa=0.35)
    return tips


# ================================================================ snowdrop
SNOW_LEAF = strap("blunt", 0.9, 0.82)


def snowdrop_leaf(a, sp):
    """The close-up: one narrow grey-green strap leaf, the same width almost
    all the way, a faint paler band down the middle, and a blunt tip that
    curls in a little (hooded). At its foot, the pale sheath."""
    fill = sp["fill"]
    band(a, (34, 95), (40, 40), (74, 8), 8, fill, SNOW_LEAF, veins=(0.62, -0.62), stripe="white", stripew=0.24, stripefa=0.4, hood=True)
    return a


def snowdrop_head(a, x, y, s, fc="white", mark="deep", d=1, ov="unripe"):
    """One hanging snowdrop flower. (x, y) is where the hair-thin stalk meets
    the top of the green ovary; the flower hangs straight down from it.
    s is its size (1 is about 10 squares long). Three long outer tepals (one
    behind, two spreading), and in front the short inner cup, each of its
    tepals notched at the tip with a green upside-down V above the notch."""
    lw = 0.9 if d >= 1 else 0.7
    oc = (x, y + 1.9 * s)
    top = (x, y + 3.6 * s)
    with a.on(BLOOM):
        petal(a, *top, 90, 10.4 * s, 4.6 * s, fc, "spoon", lw=lw, shade=0.1, lines=2 if d >= 2 else 0)        # the outer tepal behind
        for sg in (1, -1):
            petal(a, top[0] + sg * 0.4 * s, top[1], 90 - sg * 34, 10 * s, 4.4 * s, fc, "spoon", lw=lw, shade=0.06, lines=2 if d >= 2 else 0)
        # the inner cup: three short tepals, the middle one in front
        cw, ch = 2.5 * s, 5.4 * s; cy0 = top[1] + 0.2 * s
        cup = [(x - cw * 0.8, cy0), (x - cw, cy0 + ch * 0.75), (x - cw * 0.92, cy0 + ch), (x - cw * 0.38, cy0 + ch * 0.94), (x, cy0 + ch * 1.04),
               (x + cw * 0.38, cy0 + ch * 0.94), (x + cw * 0.92, cy0 + ch), (x + cw, cy0 + ch * 0.75), (x + cw * 0.8, cy0)]
        a.shape(path(cup), fc, lw)
        a.shape(path(cup[4:] + [(x, cy0)]), "shade", 0, fa=0.1)
        # where the tepals meet, and the notch at the tip of the front one
        for sg in (1, -1):
            a.line(f"M{f(x + sg * cw * 0.55)},{f(cy0 + ch * 0.25)} L{f(x + sg * cw * 0.42)},{f(cy0 + ch * 0.9)}", 0.45, 0.4)
        a.line(f"M{f(x - 0.5 * s)},{f(cy0 + ch * 1.02)} L{f(x)},{f(cy0 + ch * 0.9)} L{f(x + 0.5 * s)},{f(cy0 + ch * 1.02)}", 0.5 if d < 2 else 0.7, 0.7)
        # the green upside-down V just above the notch
        vw = 1.5 * s
        a.line(f"M{f(x - vw * 0.6)},{f(cy0 + ch * 0.88)} L{f(x)},{f(cy0 + ch * 0.56)} L{f(x + vw * 0.6)},{f(cy0 + ch * 0.88)}", max(0.9, 0.5 * s), 0.95, mark)
        # the green knob of the ovary on top
        a.oval(oc[0], oc[1] + 0.2 * s, 1.35 * s, 1.75 * s, 0, ov, 0.8 if d >= 1 else 0.6)
    return top


def snowdrop_stem(a, base, top, s=1.0, d=1, spathe="leaf", stemc="sage", flower=True, fc="white", mark="deep", head=True):
    """A flower stem from base to top, the green spathe (two bracts joined)
    standing up at the top, and the hair-thin flower stalk arching out of it
    and over, so the flower hangs beside the stem."""
    with a.on(STEM):
        a.ribbon(base, ((base[0] + top[0]) / 2 - 0.6, (base[1] + top[1]) / 2), top, 1.5 * s, 1.2 * s, stemc, lw=0.7)
    with a.on(LEAF):
        petal(a, top[0], top[1] + 0.6 * s, -84, 7.2 * s, 2.3 * s, spathe, "lance", lw=0.7, shade=0.08)   # the spathe
    hang = (top[0] + 6.2 * s, top[1] + 3.2 * s)
    with a.on(STEM):
        a.line(f"M{f(top[0] + 0.3 * s)},{f(top[1] - 0.6 * s)} Q{f(top[0] + 5.6 * s)},{f(top[1] - 3.6 * s)} {P(hang)}", 0.7 if d < 2 else 0.9, 0.9)
    if head:
        snowdrop_head(a, hang[0], hang[1], s, fc, mark, d)
    return hang


def snowdrop_bloom(a, sp):
    fc = sp.get("fc", "white"); mark = sp.get("cen", "deep")
    leafc = pal("snowdrop", "leaf", "sage")
    with a.group():
        a.ribbon((40, 99), (41, 60), (42, 22), 2.6, 2.2, leafc, lw=0.9)
        with a.on(LEAF):
            petal(a, 42, 24, -84, 18, 5.4, "leaf", "lance", lw=0.8, shade=0.1, lines=1)   # the green spathe
        a.line("M42.6,22 Q54,8 61,18", 0.9, 0.9)   # the hair-thin flower stalk, arching out of the spathe
        snowdrop_head(a, 61.4, 18.6, 4.0, fc, mark, d=2)
    return a


def snowdrop_plant(a, x, flower_h, s, leaves, d=1, seed=False):
    """One snowdrop bulb's stem and two leaves above the soil at x."""
    leafc = pal("snowdrop", "leaf", "sage")
    with a.on(LEAF):
        for dx, (tx, ty) in leaves:
            band(a, (x + dx, G + 0.5), (x + dx * 1.5 + (tx - x) * 0.15, G - (G - ty) * 0.55), (tx, ty), 3.0 * s, leafc, SNOW_LEAF, lw=0.9, hood=d >= 1, shade=0.1)
    with a.on(STEM):   # the pale sheath round the foot of the leaves
        a.ribbon((x, G + 1), (x, G - 1), (x, G - 3.2 * s), 4.4 * s, 3.8 * s, "pale", lw=0.7)


def snowdrop_shoots():
    a = Art(); a.ground(G); leafc = pal("snowdrop", "leaf", "sage")
    tunic(a, 50, 89, 14, 11, nose=1.15)
    a.ribbon((50, 75.5), (50, 71), (50, G), 3.6, 4.2, "pale", lw=0.7)   # the neck of the bulb up to the soil
    with a.group():
        with a.on(LEAF):
            # the two leaves, pressed together face to face, blunt tips
            band(a, (48.7, G), (48.2, 55), (47.6, 41), 3.2, leafc, SNOW_LEAF, lw=0.9, hood=True)
            band(a, (51.3, G), (51.8, 56), (52.6, 44), 3.2, leafc, SNOW_LEAF, lw=0.9, hood=True)
        with a.on(BLOOM):
            # the flower bud, wrapped in its green spathe, rising between them
            a.ribbon((50, G - 4), (50, 50), (50, 40), 1.3, 1.1, leafc, lw=0.6)
            petal(a, 50, 41.5, -90, 10, 3.4, "leaf", "lance", lw=0.8, shade=0.1)
            a.line("M49.3,38 L49.6,34", 0.6, 0.5, "white")
        a.ribbon((50, G + 2.5), (50, G), (50, G - 5), 5.6, 4.8, "pale", lw=0.7)   # the pale sheath at the soil
    return a


def snowdrop_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 50, 83.4, 7, 9, 120)
    tunic(a, 50, 82, 34, 26, nose=1.25, d=2)
    return a


def snowdrop_flower():
    a = Art(); a.ground(G)
    plants = [(46, 13, 1.0, [(-1.2, (36, 26)), (1.2, (55, 30))]),
              (24, 30, 0.86, [(-1, (12, 42)), (1, (31, 41))]),
              (68, 24, 0.9, [(-1, (61, 38)), (1, (82, 36))])]
    with a.group():
        for x, top, s, lv in plants:
            snowdrop_plant(a, x, top, s, lv)
            snowdrop_stem(a, (x, G), (x - 0.5, top), s * 1.3)
    for x, (bx, s) in zip((24, 46, 68), ((24, 0.62), (46, 0.72), (68, 0.66))):   # the clump of bulbs below
        a.ribbon((x, 82 - 13 * s), (x, (G + 82 - 13 * s) / 2), (x, G), 2.6, 3.0, "pale", lw=0.6)
        roots(a, x, 86.5, 5, 6, 110)
        tunic(a, x, 86, 18 * s, 14 * s, nose=1.15)
    return a


def snowdrop_seed():
    a = Art(); a.ground(G); leafc = pal("snowdrop", "leaf", "sage"); fr = pal("snowdrop", "fruit", "unripe")
    with a.group():
        with a.on(LEAF):   # the leaves, longer now and flopping
            for p0, c, p1 in [((48, G), (40, 36), (14, 44)), ((52, G), (62, 34), (86, 46)), ((49.6, G), (44, 28), (30, 26)),
                              ((50.6, G), (58, 26), (70, 24)), ((48.8, G), (34, 48), (10, 60))]:
                band(a, p0, c, p1, 3.4, leafc, SNOW_LEAF, lw=0.9, hood=True)
        for x0, c, e in [((49.2, G), (38, 30), (28, 63)), ((50.8, G), (66, 32), (74, 63))]:
            with a.on(STEM):
                a.line(f"M{P(x0)} Q{P(c)} {P(e)}", 1.1, 0.85)   # the stalk gone weak, the pod lying on the ground
            with a.on(BLOOM):
                a.oval(e[0], e[1] - 1.0, 3.4, 3.1, 0, fr, 0.9)
                a.line(f"M{f(e[0] - 1.2)},{f(e[1] - 2.2)} Q{f(e[0] - 1.8)},{f(e[1])} {f(e[0] - 1)},{f(e[1] + 1.2)}", 0.5, 0.35)
                a.leaf(e[0], e[1] - 3.4, -90 + (e[0] - 50) * 0.8, 2.2, 0.4, "straw", lw=0.5, detail=False)   # the shrivelled tepals
        a.ribbon((50, G + 2), (50, G), (50, G - 3.6), 4.6, 4.0, "pale", lw=0.7)
    a.ribbon((50, 76), (50, 71), (50, G), 3.0, 3.6, "pale", lw=0.6)
    roots(a, 50, 89.4, 5, 6, 110); tunic(a, 50, 89, 14, 11, nose=1.15)
    return a


def snowdrop_dormant():
    a = Art(); a.ground(40)
    for x, y, h, w in ((40, 82, 22, 17), (62, 80, 17, 13)):   # two bulbs of the clump, resting
        roots(a, x, y + 0.6, 6, 10, 110, dead=True)
        tunic(a, x, y, h, w, nose=1.2)
    return a



# ================================================================ daffodil
DAFF_LEAF = strap("blunt", 0.9, 0.86)


def daffodil_leaf(a, sp):
    """One long grey-green strap leaf, even width, fine parallel veins,
    a blunt rounded tip and a smooth edge."""
    band(a, (30, 96), (40, 40), (70, 7), 11, sp["fill"], DAFF_LEAF, veins=(0.62, -0.62, 0.25, -0.25), vla=0.26)
    return a


def daff_head(a, x, y, s, side=-1, d=1, fc="bulbs_yellow", tc="bulbs_gold", seed=False, fr="unripe"):
    """One daffodil flower at the top of a stem that ends at (x, y). The stem
    bends just there, with the thin brown papery spathe standing up at the
    bend; the green ovary leads to a flat star of six pointed tepals, and the
    long trumpet with its frilled rim points out sideways (left for side=-1,
    right for side=1). s: size (1 is the close-up). seed: gone to seed, a
    swollen green pod with the withered tepals shrivelled behind it."""
    X = lambda dx, dy: (x - side * dx * s if False else x + (-dx if side < 0 else dx) * s * -1 * -1, y + dy * s)
    def X(dx, dy):   # a point measured from the bend, the flower facing to the side
        return (x + (dx if side < 0 else -dx) * s, y + dy * s)
    def A(ang):      # an angle, mirrored to match
        return ang if side < 0 else 180 - ang
    lw = 0.9 if d >= 1 else 0.7
    with a.on(LEAF):   # the papery spathe at the bend
        petal(a, *X(0.6, 0.6), A(-78), 15 * s, 4.6 * s, "seed", "lance", lw=0.6 if d < 2 else 0.8, shade=0.1, lines=2 if d >= 2 else 0, la=0.35)
    with a.on(STEM):   # the neck, bending over
        a.line(f"M{P(X(0, 0))} Q{P(X(-1.5, -7))} {P(X(-9, -5))}", 2.0 * s if d >= 2 else max(1.1, 2.6 * s), 0.9)
    with a.on(BLOOM):
        oc = X(-12.5, -3.2)
        if seed:   # the swollen three-sided pod, with the dead tepals shrivelled behind it
            a.oval(*X(-13.5, -2.6), 7.2 * s, 4.8 * s, A(-196) if side < 0 else A(-196), fr, lw)
            for o in (-1.6, 1.6):
                a.line(f"M{P(X(-8, -4 + o))} Q{P(X(-13.5, -3.6 + o * 1.6))} {P(X(-19, -1.6 + o))}", 0.6, 0.45)
            for k, ang in enumerate((-60, -10, 30, 70, 120)):
                c = X(-21, -0.6)
                petal(a, c[0], c[1], A(ang + 180 if False else ang), 5.5 * s, 2.6 * s, "straw", "elliptic", lw=0.6, shade=0.08, bend=0.25 * (1 if k % 2 else -1))
            return
        a.oval(oc[0], oc[1], 4.6 * s, 2.8 * s, A(-196), "unripe", lw)
        C = X(-17, 0.4)
        M = squash(C[0], C[1], 0.46, 1.0, A(-8) if side < 0 else -A(-8) + 180)
        M = squash(C[0], C[1], 0.46, 1.0, -8 if side < 0 else 8)
        for k in sorted(range(6), key=lambda k: -math.cos(math.radians(-90 + 60 * k + 30))):   # the six tepals, a flat star
            ang = -90 + 60 * k + 30
            petal(a, C[0], C[1], ang, 26 * s, 14 * s, fc, "point", lw=lw, M=M, shade=0.07, lines=3 if d >= 2 else 0, la=0.25)
        # the trumpet, pointing out sideways
        ax = math.radians(A(172)); ux, uy = math.cos(ax), math.sin(ax); nx, ny = -uy, ux
        Lt = 30 * s; r0, r1 = 6.0 * s, 9.0 * s
        R = (C[0] + ux * Lt, C[1] + uy * Lt)
        body = [(C[0] + nx * r0, C[1] + ny * r0), (R[0] + nx * r1, R[1] + ny * r1), (R[0] - nx * r1, R[1] - ny * r1), (C[0] - nx * r0, C[1] - ny * r0)]
        a.shape(f"M{P(body[0])} Q{P(lerp(body[0], body[1], 0.5))} {P(body[1])} L{P(body[2])} Q{P(lerp(body[3], body[2], 0.5))} {P(body[3])} Z", tc, lw)
        a.shape(path([body[0], body[1], R, C]) if ny > 0 else path([body[3], body[2], R, C]), "shade", 0, fa=0.1)
        if d >= 1:
            for o in ((-0.55, 0, 0.55) if d >= 2 else (-0.4, 0.4)):   # ridges along the trumpet
                a.line(f"M{P((C[0] + nx * r0 * o + ux * 2 * s, C[1] + ny * r0 * o + uy * 2 * s))} L{P((R[0] + nx * r1 * o - ux * 2 * s, R[1] + ny * r1 * o - uy * 2 * s))}", 0.45, 0.32)
        # the frilled, flared rim, seen at a slant, and the dark mouth inside it
        rot = math.degrees(ax)
        nfr = 16 if d >= 1 else 10
        rim = [(R[0] + (3.4 * s * math.cos(h)) * ux - (11.2 * s * (1 + 0.07 * math.cos(nfr * h)) * math.sin(h)) * nx * -1,
                R[1] + (3.4 * s * math.cos(h)) * uy + (11.2 * s * (1 + 0.07 * math.cos(nfr * h)) * math.sin(h)) * ny) for h in [2 * math.pi * i / 90 for i in range(90)]]
        rim = [(R[0] + 3.4 * s * math.cos(h) * ux + 11.2 * s * (1 + 0.07 * math.cos(nfr * h)) * math.sin(h) * nx,
                R[1] + 3.4 * s * math.cos(h) * uy + 11.2 * s * (1 + 0.07 * math.cos(nfr * h)) * math.sin(h) * ny) for h in [2 * math.pi * i / 90 for i in range(90)]]
        a.shape(path(rim), tc, lw)
        mouth = [(R[0] + 1.6 * s * math.cos(h) * ux + 7.6 * s * math.sin(h) * nx, R[1] + 1.6 * s * math.cos(h) * uy + 7.6 * s * math.sin(h) * ny) for h in [2 * math.pi * i / 30 for i in range(30)]]
        a.shape(path(mouth), "shade", 0, fa=0.24)
        if d >= 2:   # the tips of the stamens and the style, just seen deep inside
            for o in (-2.2, 0, 2.2):
                a.dot(R[0] + nx * o * s + ux * 0.8 * s, R[1] + ny * o * s + uy * 0.8 * s, 0.75, "amber")


def daffodil_bloom(a, sp):
    fc = sp.get("fc", "bulbs_yellow"); tc = sp.get("cen", "bulbs_gold")
    with a.group():
        with a.on(STEM):
            a.ribbon((75, 99), (76, 62), (74, 34), 3.6, 3.2, pal("daffodil", "leaf", "sage"), lw=0.9)
            a.line("M75.4,96 Q76,62 74.2,36", 0.5, 0.35)   # the stem is flattened, with two edges
        daff_head(a, 74, 34, 1.0, -1, d=2, fc=fc, tc=tc)
    return a


def daffodil_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 52, 86.4, 8, 9, 120)
    with a.group():
        tunic(a, 71, 82, 22, 15, fill="bark", nose=1.4, lean=0.12)   # an offset bulb, still joined at the base
        tunic(a, 49, 85, 40, 30, fill="bark", nose=1.6, lean=-0.03, d=2)
    return a


def _daff_leaves(a, spec, W=3.8, col=None, droop=False):
    leafc = col or pal("daffodil", "leaf", "sage")
    with a.on(LEAF):
        for (bx, tx, ty, bend) in spec:
            band(a, (bx, G + 0.5), (bx + (tx - bx) * 0.25 + bend, G - (G - ty) * 0.6), (tx, ty), W, leafc, DAFF_LEAF, lw=0.9, veins=(0.4, -0.4) if W > 3.5 else (), vla=0.24)


def _daff_bulbs(a, xs=(38, 60)):
    for i, x in enumerate(xs):
        a.ribbon((x, 77), (x, 72), (x, G), 3.4, 4.0, "pale", lw=0.6)
        roots(a, x, 92.4, 6, 5, 120)
        tunic(a, x, 92, 16 + 2 * (i % 2), 13 + i, fill="bark", nose=1.5)


def daffodil_shoots():
    a = Art(); a.ground(G); leafc = pal("daffodil", "leaf", "sage")
    with a.group():
        _daff_leaves(a, [(45.4, 42, 50, -1), (47.6, 45.6, 44, -0.5), (52.6, 54.6, 45, 0.5), (54.6, 58, 51, 1), (50.2, 50.6, 52, 0)], W=4.2)
        with a.on(STEM):
            a.ribbon((50, G), (50, 54), (50.4, 44), 2.4, 2.2, leafc, lw=0.7)
        with a.on(BLOOM):   # the fat flower bud in its papery sheath
            petal(a, 50.4, 46, -90, 16, 6.4, "seed", "lance", lw=0.8, shade=0.1, lines=2, la=0.35)
            a.line("M49.6,38 Q50,36 50.6,38", 0.7, 0.5, "bulbs_gold")
    _daff_bulbs(a, (50,))
    return a


def daffodil_flower():
    a = Art(); a.ground(G); leafc = pal("daffodil", "leaf", "sage")
    fc = pal("daffodil", "flower", "bulbs_yellow"); tc = pal("daffodil", "centre", "bulbs_gold")
    with a.group():
        _daff_leaves(a, [(35, 20, 26, -2), (37, 30, 18, -1), (40, 40, 22, 0), (41.6, 26, 36, -2), (58, 60, 20, 1), (60, 72, 24, 2),
                         (62, 80, 34, 3), (56, 48, 30, 0), (44, 46, 16, 0)])
        for x, top, side, s in ((38, 21, -1, 0.34), (61, 17, 1, 0.36)):
            with a.on(STEM):
                a.ribbon((x, G), (x + 0.5 * side, (G + top) / 2), (x, top), 1.9, 1.6, leafc, lw=0.7)
            daff_head(a, x, top, s, side, d=1, fc=fc, tc=tc)
    _daff_bulbs(a)
    return a


def daffodil_seed():
    a = Art(); a.ground(G); leafc = pal("daffodil", "leaf", "sage"); fr = pal("daffodil", "fruit", "unripe")
    with a.group():
        with a.on(LEAF):   # the leaves still green, some starting to flop over
            for p0, c, p1 in [((36, G), (26, 30), (12, 34)), ((38, G), (34, 24), (26, 16)), ((41, G), (44, 26), (50, 22)),
                              ((58, G), (62, 30), (80, 22)), ((61, G), (74, 30), (90, 46)), ((44, G), (40, 40), (20, 52)), ((56, G), (56, 36), (66, 40))]:
                band(a, p0, c, p1, 3.8, leafc, DAFF_LEAF, lw=0.9, veins=(0.4, -0.4), vla=0.24)
        for x, top, side, s in ((38, 26, -1, 0.34), (61, 22, 1, 0.36)):
            with a.on(STEM):
                a.ribbon((x, G), (x + 0.5 * side, (G + top) / 2), (x, top), 1.9, 1.6, leafc, lw=0.7)
            daff_head(a, x, top, s, side, d=1, seed=True, fr=fr)
    _daff_bulbs(a)
    return a


def daffodil_dormant():
    a = Art(); a.ground(44)
    with a.group():
        with a.on(LEAF):   # the last leaves, yellowed and flopped on the soil
            for p0, c, p1 in [((48, 44), (34, 40), (14, 43)), ((50, 44), (62, 38.6), (84, 42.6)), ((49, 44), (42, 41), (28, 41))]:
                band(a, p0, c, p1, 3.6, "straw", DAFF_LEAF, lw=0.9)
    roots(a, 50, 88.5, 8, 7, 120)
    tunic(a, 66, 86, 15, 11, fill="bark", nose=1.4, lean=0.1)
    tunic(a, 49, 88, 30, 22, fill="bark", nose=1.6)
    a.ribbon((49, 59), (49, 52), (49, 44), 2.8, 3.4, "straw", lw=0.6)
    return a


# ================================================================== tables
LEAF_DRAW = {"bulbs_snowdrop": snowdrop_leaf, "bulbs_daffodil": daffodil_leaf}
BLOOM_DRAW = {"bulbs_snowdrop": snowdrop_bloom, "bulbs_daffodil": daffodil_bloom}
LEAFX = {"snowdrop": dict(kind="bulbs_snowdrop", fill=pal("snowdrop", "leaf", "sage")),
         "daffodil": dict(kind="bulbs_daffodil", fill=pal("daffodil", "leaf", "sage"))}
BLOOMX = {"snowdrop": dict(kind="bulbs_snowdrop", fc=pal("snowdrop", "flower", "white"), cen=pal("snowdrop", "centre", "deep")),
          "daffodil": dict(kind="bulbs_daffodil", fc=pal("daffodil", "flower", "bulbs_yellow"), cen=pal("daffodil", "centre", "bulbs_gold"))}
STAGE = {
    "snowdrop": {"bulb": snowdrop_bulb, "shoots": snowdrop_shoots, "flower": snowdrop_flower, "seedhead": snowdrop_seed, "dormant": snowdrop_dormant},
    "daffodil": {"bulb": daffodil_bulb, "shoots": daffodil_shoots, "flower": daffodil_flower, "seedhead": daffodil_seed, "dormant": daffodil_dormant},
}
