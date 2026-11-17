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
    "bulbs_chestnut": ("#9A5B36", "#9C6442"),  # tulip bulb: shiny chestnut-brown skin
    "bulbs_stripe":  ("#5C84C6", "#86A6DE"),   # puschkinia: the clear darker blue stripe down each tepal
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
        return max(0.0, math.cos(math.pi / 2 * v)) ** 0.9
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
        return max(0.0, math.cos(math.pi / 2 * min(1.0, (t - widest) / (1 - widest)))) ** tipk
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
    band(a, (34, 95), (40, 40), (74, 8), 6.6, fill, SNOW_LEAF, veins=(0.62, -0.62), stripe="white", stripew=0.24, stripefa=0.4, hood=True)
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
    band(a, (32, 96), (40, 40), (70, 7), 8.5, sp["fill"], DAFF_LEAF, veins=(0.62, -0.62, 0.25, -0.25), vla=0.26)
    return a


def daff_head(a, x, y, s, side=-1, d=1, fc="bulbs_yellow", tc="bulbs_gold", seed=False, fr="unripe"):
    """One daffodil flower at the top of a stem that ends at (x, y). The stem
    bends just there, with the thin brown papery spathe standing up at the
    bend; the green ovary leads to a flat star of six pointed tepals, and the
    long trumpet with its frilled rim points out sideways (left for side=-1,
    right for side=1). s: size (1 is the close-up). seed: gone to seed, a
    swollen green pod with the withered tepals shrivelled behind it."""
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
            a.oval(*X(-13.5, -1.6), 8.6 * s, 5.8 * s, A(-210), fr, lw)
            for o in (-1.6, 1.6):
                a.line(f"M{P(X(-8, -4 + o))} Q{P(X(-13.5, -3.6 + o * 1.6))} {P(X(-19, -1.6 + o))}", 0.6, 0.45)
            for k, ang in enumerate((-60, -10, 30, 70, 120)):
                c = X(-21, 1.4)
                petal(a, c[0], c[1], A(ang), 7 * s, 3.4 * s, "straw", "elliptic", lw=0.6, shade=0.08, bend=0.3 * (1 if k % 2 else -1))
            return
        a.oval(oc[0], oc[1], 4.6 * s, 2.8 * s, A(-196), "unripe", lw)
        C = X(-17, 0.4)
        M = squash(C[0], C[1], 0.64, 1.0, -10 if side < 0 else 10)   # the star seen at a slant, three quarters on
        for k in sorted(range(6), key=lambda k: -math.cos(math.radians(-90 + 60 * k + 30))):   # the six tepals, a flat star
            ang = -90 + 60 * k + 30
            petal(a, C[0], C[1], ang, 26 * s, 17 * s, fc, "point", lw=lw, M=M, shade=0.07, lines=3 if d >= 2 else 0, la=0.25)
        # the trumpet, pointing out sideways
        ax = math.radians(A(166)); ux, uy = math.cos(ax), math.sin(ax); nx, ny = -uy, ux
        Lt = 21 * s; r0, r1 = 6.4 * s, 9.0 * s   # as long as the tepals, but pointing half towards you, so it looks shorter
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
        rim = [(R[0] + 5.2 * s * math.cos(h) * ux + 11.2 * s * (1 + 0.07 * math.cos(nfr * h)) * math.sin(h) * nx,
                R[1] + 5.2 * s * math.cos(h) * uy + 11.2 * s * (1 + 0.07 * math.cos(nfr * h)) * math.sin(h) * ny) for h in [2 * math.pi * i / 90 for i in range(90)]]
        a.shape(path(rim), tc, lw)
        mouth = [(R[0] + 3.0 * s * math.cos(h) * ux + 7.8 * s * math.sin(h) * nx, R[1] + 3.0 * s * math.cos(h) * uy + 7.8 * s * math.sin(h) * ny) for h in [2 * math.pi * i / 30 for i in range(30)]]
        a.shape(path(mouth), "shade", 0, fa=0.24)
        if d >= 2:   # the tips of the stamens and the style, just seen deep inside
            for o in (-2.2, 0, 2.2):
                a.dot(R[0] + nx * o * s + ux * 0.8 * s, R[1] + ny * o * s + uy * 0.8 * s, 0.75, "amber")


def daffodil_bloom(a, sp):
    fc = sp.get("fc", "bulbs_yellow"); tc = sp.get("cen", "bulbs_gold")
    with a.group():
        with a.on(STEM):
            a.ribbon((79, 99), (80, 62), (78, 34), 3.8, 3.4, pal("daffodil", "leaf", "sage"), lw=0.9)
            a.line("M79.4,96 Q80,62 78.2,36", 0.5, 0.35)   # the stem is flattened, with two edges
        daff_head(a, 78, 34, 1.12, -1, d=2, fc=fc, tc=tc)
    return a


def daffodil_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 52, 86.4, 8, 9, 120)
    with a.group():
        tunic(a, 71, 82, 22, 15, fill="bark", nose=1.4, lean=0.12)   # an offset bulb, still joined at the base
        tunic(a, 49, 85, 40, 30, fill="bark", nose=1.6, lean=-0.03, d=2)
    return a


def _daff_leaves(a, spec, W=2.8, col=None, droop=False):
    leafc = col or pal("daffodil", "leaf", "sage")
    with a.on(LEAF):
        for (bx, tx, ty, bend) in spec:
            band(a, (bx, G + 0.5), (bx + (tx - bx) * 0.25 + bend, G - (G - ty) * 0.6), (tx, ty), W, leafc, DAFF_LEAF, lw=0.9, veins=(0.4, -0.4) if W > 3.9 else (), vla=0.24)


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
        _daff_leaves(a, [(35, 18, 30, -2), (37, 28, 24, -1), (39.4, 40, 28, 0), (41, 24, 42, -3), (59, 58, 26, 1), (60.6, 70, 28, 2),
                         (62, 82, 38, 3), (57, 50, 34, 0), (43, 46, 30, 0)])
        for x, top, side, s in ((38, 25, -1, 0.44), (61, 21, 1, 0.46)):
            with a.on(STEM):
                a.ribbon((x, G), (x + 0.5 * side, (G + top) / 2), (x, top), 1.9, 1.6, leafc, lw=0.7)
            daff_head(a, x, top, s, side, d=1, fc=fc, tc=tc)
    _daff_bulbs(a)
    return a


def daffodil_seed():
    a = Art(); a.ground(G); leafc = pal("daffodil", "leaf", "sage"); fr = pal("daffodil", "fruit", "unripe")
    with a.group():
        with a.on(LEAF):   # the leaves still green, some starting to flop over
            for p0, c, p1 in [((36, G), (26, 30), (10, 38)), ((38, G), (34, 26), (24, 22)), ((41, G), (44, 30), (50, 30)),
                              ((58, G), (62, 30), (78, 28)), ((61, G), (76, 30), (90, 48)), ((44, G), (40, 40), (20, 54)), ((56, G), (56, 38), (66, 44))]:
                band(a, p0, c, p1, 2.8, leafc, DAFF_LEAF, lw=0.9)
        for x, top, side, s in ((38, 26, -1, 0.46), (61, 22, 1, 0.48)):
            with a.on(STEM):
                a.ribbon((x, G), (x + 0.5 * side, (G + top) / 2), (x, top), 1.9, 1.6, leafc, lw=0.7)
            daff_head(a, x, top, s, side, d=1, seed=True, fr=fr)
    _daff_bulbs(a)
    return a


def daffodil_dormant():
    a = Art(); a.ground(44)
    with a.group():
        with a.on(LEAF):   # the last leaves, yellowed and flopped on the soil
            for p0, c, p1 in [((48, 44), (34, 41), (12, 43.2)), ((50, 44), (64, 40.6), (86, 43)), ((49, 44), (40, 39), (26, 40.4)),
                              ((50.4, 44), (58, 39.4), (70, 40))]:
                band(a, p0, c, p1, 2.6, "straw", DAFF_LEAF, lw=0.9)
    roots(a, 50, 88.5, 8, 7, 120)
    tunic(a, 66, 86, 15, 11, fill="bark", nose=1.4, lean=0.1)
    tunic(a, 49, 88, 30, 22, fill="bark", nose=1.6)
    a.ribbon((49, 59), (49, 52), (49, 44), 2.8, 3.4, "straw", lw=0.6)
    return a



# =================================================================== tulip
TULIP_LEAF = lance(0.26, 0.6, 0.85)


def tulip_leaf_on(a, sx, sy, tip, W, fill, side=1, d=1, lw=None):
    """One broad tulip leaf clasping the stem at (sx, sy) and arching out to
    tip: its wide foot wraps round the stem (an ear of it shows on the far
    side), then it narrows to a pointed, slightly hooded tip."""
    lw = lw or (0.9 if d < 2 else LW)
    with a.on(STEM):   # the far side of the clasping foot, behind the stem
        petal(a, sx - side * W * 0.06, sy + W * 0.02, -90 - side * 50, W * 0.36, W * 0.26, fill, "elliptic", lw=lw * 0.8, shade=0.18)
    c = (sx + (tip[0] - sx) * 0.22, tip[1] + (sy - tip[1]) * 0.42)
    with a.on(LEAF):
        band(a, (sx, sy + W * 0.12), c, tip, W, fill, TULIP_LEAF, lw=lw, veins=(0.62, -0.62, 0.3, -0.3) if d >= 2 else ((0.45, -0.45) if d else ()),
             vla=0.24, mid=0.6 if d >= 1 else 0, midla=0.3, hood=d >= 1)
        a.line(f"M{f(sx - W * 0.3)},{f(sy + W * 0.1)} Q{f(sx)},{f(sy + W * 0.22)} {f(sx + W * 0.3)},{f(sy + W * 0.08)}", 0.5 if d < 2 else 0.7, 0.45)   # where the foot wraps round


def tulip_leaf(a, sp):
    """A broad lance-shaped grey-green leaf clasping a piece of stem."""
    with a.group():
        with a.on(STEM):
            a.ribbon((30, 98), (30, 50), (31, 8), 4.6, 4.0, sp["fill"], lw=0.9)
        tulip_leaf_on(a, 30.5, 80, (86, 18), 28, sp["fill"], 1, d=2)
    return a


def tulip_cup(a, x, y, s, fc, cen="dark", d=1, inside=False, lw=None):
    """A tulip flower on top of a stem that ends at (x, y): six broad rounded
    tepals in an upright cup, no sepals. inside=True opens the front of the
    cup a little to show the dark blotches, the six dark stamens and the
    three-lobed stigma (the close-up)."""
    lw = lw or (0.9 if d >= 1 else 0.7)
    with a.on(BLOOM):
        back = [(-117, 44, 25), (-63, 44, 25), (-90, 46, 26)]
        for ang, L, W in back:   # the inner three, seen from inside at the back of the cup
            petal(a, x, y, ang, L * s, W * s, fc, "obovate", lw=lw, shade=0.16, lines=3 if d >= 2 else 0, la=0.22)
            if inside:
                b = T(x, y, ang)(21 * s); a.oval(b[0], b[1], 5.6 * s, 4.2 * s, ang, cen, 0, la=0)
        if inside:   # the stamens round the green ovary with its three-lobed stigma
            a.ribbon((x, y - 2 * s), (x, y - 14 * s), (x, y - 25 * s), 4.4 * s, 3.8 * s, "unripe", lw=0.7)
            for o in (-1, 0, 1):
                a.oval(x + o * 2.4 * s, y - 26.6 * s, 1.8 * s, 1.3 * s, o * 30, "pale", 0.6)
            for k, (dx, h) in enumerate(((-10, 25), (-6.5, 28.5), (-3, 30.5), (3, 30.5), (6.5, 28.5), (10, 25))):
                a.line(f"M{f(x + dx * 0.3 * s)},{f(y - 4 * s)} L{f(x + dx * s)},{f(y - (h - 4) * s)}", 0.6, 0.7)
                a.oval(x + dx * s, y - h * s, 1.2 * s, 2.8 * s, dx * 2, cen, 0.5)
            front = [(-142, 30, 24), (-38, 30, 24), (-90, 18, 26)]
        else:
            front = [(-126, 40, 24), (-54, 40, 24), (-90, 42, 25)]
        for ang, L, W in front:   # the outer three, in front
            petal(a, x, y, ang, L * s, W * s, fc, "obovate", lw=lw, shade=0.08, lines=2 if d >= 2 else 0, la=0.22)


def tulip_bloom(a, sp):
    fc = sp.get("fc", "berry"); cen = sp.get("cen", "dark")
    with a.group():
        with a.on(STEM):
            a.ribbon((51, 99), (50, 88), (50, 74), 4.4, 4.0, pal("tulip", "leaf", "sage"), lw=0.9)
        tulip_cup(a, 50, 75, 1.0, fc, cen, d=2, inside=True)
    return a


def tulip_bulb_draw(a, x, y, h, w, d=1, split=True):
    """A tulip bulb: pear-shaped, pointed at the top, flat on one side, in a
    shiny chestnut-brown skin that has split to show the cream flesh."""
    top = tunic(a, x, y, h, w, fill="bulbs_chestnut", nose=1.05, flat=0.14, lean=0.04, d=d, split="bulbs_cream" if split else None)
    a.line(f"M{f(x + w * 0.2)},{f(y - h * 0.62)} Q{f(x + w * 0.3)},{f(y - h * 0.42)} {f(x + w * 0.26)},{f(y - h * 0.22)}", 1.2 if d >= 2 else 0.8, 0.5, "white")   # the shine
    return top


def tulip_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 50, 85.4, 8, 9, 120)
    tulip_bulb_draw(a, 50, 84, 36, 30, d=2)
    return a


def _tulip_below(a, x=50):
    a.ribbon((x, 77), (x, 72), (x, G), 3.2, 3.6, "pale", lw=0.6)
    roots(a, x, 92.4, 6, 5, 120)
    tulip_bulb_draw(a, x, 92, 17, 14, split=False)


def tulip_shoots():
    a = Art(); a.ground(G); lc = pal("tulip", "leaf", "sage")
    with a.group():
        with a.on(LEAF):
            # the first leaf opening out, broad
            band(a, (49, G + 0.5), (44, 52), (31, 42), 12, lc, TULIP_LEAF, lw=0.9, veins=(0.45, -0.45), vla=0.24, mid=0.6, midla=0.3, hood=True)
            band(a, (52, G + 0.5), (57, 50), (68, 41), 10, lc, TULIP_LEAF, lw=0.9, veins=(0.45, -0.45), vla=0.24, mid=0.6, midla=0.3, hood=True)
            # the inner leaf still rolled round itself, the bud hidden inside it
            band(a, (50.4, G + 0.5), (50.6, 48), (51, 30), 7.4, lc, lance(0.3, 0.9, 1.1), lw=0.9)
            a.line("M48,58 Q51,53 53.6,47 M48.4,48 Q51,43 53,38", 0.6, 0.4)   # the edge of the rolled leaf, spiralling up
    _tulip_below(a)
    return a


def tulip_plant(a, x, top, fc, lc, seed=False, fr="unripe"):
    with a.group():
        with a.on(STEM):
            a.ribbon((x, G), (x + 0.4, (G + top) / 2), (x, top + 2), 2.4, 2.0, lc, lw=0.8)
        leafc = "pear" if seed else lc
        tulip_leaf_on(a, x, G - 3, (x - 26, G - 30), 10, leafc, -1)
        tulip_leaf_on(a, x, G - 9, (x + 25, G - 36), 8.6, leafc, 1)
        tulip_leaf_on(a, x, G - 16, (x - 15, G - 41), 6.4, leafc, -1)
        if seed:   # the upright three-sided pod on top of the stem
            with a.on(BLOOM):
                a.shape(f"M{f(x - 3.4)},{f(top + 1)} Q{f(x - 4.6)},{f(top - 7)} {f(x - 3)},{f(top - 13)} L{f(x - 1.2)},{f(top - 14.6)} L{f(x)},{f(top - 13.2)} "
                        f"L{f(x + 1.2)},{f(top - 14.6)} L{f(x + 3)},{f(top - 13)} Q{f(x + 4.6)},{f(top - 7)} {f(x + 3.4)},{f(top + 1)} Z", fr, 0.9)
                a.line(f"M{f(x)},{f(top)} L{f(x)},{f(top - 12.6)}", 0.6, 0.5)
                a.line(f"M{f(x + 2.4)},{f(top)} Q{f(x + 3.4)},{f(top - 7)} {f(x + 2.4)},{f(top - 12.4)}", 0.5, 0.35)
        else:
            tulip_cup(a, x, top + 2, 0.36, fc)


def tulip_flower():
    a = Art(); a.ground(G)
    tulip_plant(a, 50, 22, pal("tulip", "flower", "berry"), pal("tulip", "leaf", "sage"))
    _tulip_below(a)
    return a


def tulip_seed():
    a = Art(); a.ground(G)
    tulip_plant(a, 50, 22, None, pal("tulip", "leaf", "sage"), seed=True, fr=pal("tulip", "fruit", "unripe"))
    _tulip_below(a)
    return a


def tulip_dormant():
    a = Art(); a.ground(40)
    roots(a, 50, 86.4, 7, 8, 120, dead=True)
    tulip_bulb_draw(a, 50, 86, 28, 23)
    roots(a, 70, 84.3, 4, 5, 100, dead=True)
    tulip_bulb_draw(a, 70, 84, 13, 10, split=False)   # an offset, a small new bulb
    return a



# ================================================================== crocus
CROCUS_LEAF = strap("point", 0.72, 0.9)


def crocus_leaf_band(a, p0, c, p1, W, fill, d=1):
    """A crocus leaf: very narrow, grass-like, dark green with one clear
    silvery-white stripe down the middle and its edges turned under."""
    return band(a, p0, c, p1, W, fill, CROCUS_LEAF, lw=LW if d >= 2 else 0.8, stripe="white", stripew=0.3 if d >= 2 else 0.34,
                edge="shade" if d >= 1 else None, shade=0.06)


def crocus_leaf(a, sp):
    crocus_leaf_band(a, (36, 96), (44, 44), (72, 6), 7.5, sp["fill"], d=2)
    return a


def crocus_cup(a, x, y, s, fc, d=1, open_=True, style="carrot", lw=None):
    """A crocus flower whose tepals start at (x, y), the top of its white
    tube: six nearly equal, rounded tepals in a goblet, darker and veined
    towards the base. open_: the goblet half open, so the three yellow
    stamens and the frilly orange style show in the middle."""
    lw = lw or (0.9 if d >= 1 else 0.7)
    feather = "plum"
    with a.on(BLOOM):
        for ang in (-114, -66, -90):   # the inner three, at the back
            petal(a, x, y, ang, 38 * s, 17 * s, fc, "elliptic", lw=lw, shade=0.15, lines=3 if d >= 2 else 0, linec=feather, la=0.45)
        if open_:
            for dx in (-3.4, 0, 3.4):   # three yellow stamens
                a.line(f"M{f(x + dx * 0.3 * s)},{f(y - 2 * s)} L{f(x + dx * s)},{f(y - 15 * s)}", 0.6, 0.6)
                a.oval(x + dx * s, y - 19 * s, 1.3 * s, 4.2 * s, dx * 4, "sun", 0.6)
            for dx in (-1, 0, 1):   # the orange style, its three branches frilled at the tips
                tip = (x + dx * 5.4 * s, y - 27 * s)
                a.line(f"M{f(x)},{f(y - 4 * s)} Q{f(x + dx * 1.6 * s)},{f(y - 18 * s)} {P(tip)}", 1.1 * max(0.7, s), 0.95, style)
                a.shape(f"M{f(tip[0] - 2.2 * s)},{f(tip[1] - 2.2 * s)} L{f(tip[0] - 1.1 * s)},{f(tip[1] - 0.8 * s)} L{f(tip[0])},{f(tip[1] - 2.6 * s)} "
                        f"L{f(tip[0] + 1.1 * s)},{f(tip[1] - 0.8 * s)} L{f(tip[0] + 2.2 * s)},{f(tip[1] - 2.2 * s)} L{f(tip[0])},{f(tip[1] + 1.6 * s)} Z", style, 0.5)
            front = [(-128, 30, 16), (-52, 30, 16), (-90, 22, 17)]
        else:
            front = [(-108, 38, 15), (-72, 38, 15), (-90, 39, 16)]
        for ang, L, W in front:   # the outer three, in front, feathered darker at the base
            petal(a, x, y, ang, L * s, W * s, fc, "elliptic", lw=lw, shade=0.07, lines=3 if d >= 2 else (1 if d else 0), linec=feather, la=0.5)
        if d >= 1:
            a.shape(f"M{f(x - 4 * s)},{f(y - 7 * s)} Q{f(x)},{f(y - 2 * s)} {f(x + 4 * s)},{f(y - 7 * s)} L{f(x + 1.4 * s)},{f(y)} L{f(x - 1.4 * s)},{f(y)} Z", feather, 0, fa=0.35)


def crocus_tube(a, x, y0, y1, w, d=1):
    """The long thin white tube the flower stands on, rising straight out of
    the ground (no stalk, no green sepals), and the white papery sheath round
    its foot."""
    with a.on(STEM):
        a.ribbon((x, y0), (x, (y0 + y1) / 2), (x, y1), w, w * 1.15, "white", lw=0.8 if d < 2 else 0.9)


def crocus_bloom(a, sp):
    fc = sp.get("fc", "bulbs_crocus"); cen = sp.get("cen", "carrot")
    with a.group():
        crocus_tube(a, 50, 97, 64, 4.4, d=2)
        with a.on(LEAF):   # the white papery sheath at the soil
            petal(a, 50, 97, -88, 16, 7.4, "white", "lance", lw=0.8, shade=0.14, lines=2)
        crocus_cup(a, 50, 66, 1.12, fc, d=2, style=cen)
    return a


def crocus_corm():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 50, 84, 8, 8, 130)
    corm(a, 50, 84, 36, 22, shoots=2, d=2)
    return a


GC = 70   # the crocus is low: its soil line is lower in the tile


def _crocus_corms(a, xs):
    for x in xs:
        a.ribbon((x, 84), (x, 78), (x, GC), 2.4, 2.8, "white", lw=0.6)
        roots(a, x, 92.3, 5, 4, 120)
        corm(a, x, 92, 12, 8)


def crocus_leaves(a, spec, W=2.6, col=None):
    lc = col or pal("crocus", "leaf", "deep")
    with a.on(LEAF):
        for bx, tx, ty, bend in spec:
            crocus_leaf_band(a, (bx, GC + 0.5), (bx + (tx - bx) * 0.3 + bend, GC - (GC - ty) * 0.6), (tx, ty), W, lc)


def crocus_shoots():
    a = Art(); a.ground(GC)
    with a.group():
        crocus_leaves(a, [(47, 40, 50, -1), (48.6, 46, 44, 0), (51.6, 55, 46, 0.5), (53, 60, 52, 1)])
        with a.on(BLOOM):   # the closed bud rising from the middle of the tuft
            crocus_tube(a, 50, GC, 54, 2.2)
            petal(a, 50, 55, -90, 14, 5.6, pal("crocus", "flower", "bulbs_crocus"), "elliptic", lw=0.8, shade=0.12, lines=1, linec="plum", la=0.5)
        with a.on(BLOOM):   # the white papery sheaths round the foot of the tuft
            petal(a, 50, GC + 1, -90, 12, 7.6, "white", "lance", lw=0.7, shade=0.12, lines=2)
    _crocus_corms(a, (50,))
    return a


def crocus_flower():
    a = Art(); a.ground(GC); fc = pal("crocus", "flower", "bulbs_crocus"); st = pal("crocus", "centre", "carrot")
    with a.group():
        crocus_leaves(a, [(35, 22, 38, -2), (37, 32, 32, -1), (40, 44, 36, 1), (58, 54, 34, 0), (60, 68, 32, 1), (62, 80, 40, 2), (48, 46, 30, 0)])
        for x, top, s in ((38, 46, 0.42), (61, 42, 0.46)):
            crocus_tube(a, x, GC, top, 2.6)
            crocus_cup(a, x, top + 1, s, fc, style=st)
        for x in (38, 61):
            with a.on(BLOOM):
                petal(a, x, GC + 1, -90, 8, 5.4, "white", "lance", lw=0.6, shade=0.12)
    _crocus_corms(a, (38, 61))
    return a


def crocus_seed():
    a = Art(); a.ground(GC); fr = pal("crocus", "fruit", "unripe")
    with a.group():
        crocus_leaves(a, [(46, 22, 12, -3), (47, 34, 8, -2), (49, 46, 10, 0), (51, 60, 8, 2), (53, 74, 14, 3), (48, 14, 30, -4), (52, 86, 30, 4)])
        with a.on(BLOOM):   # the oval pod, pushed up to soil level among the leaves
            a.line(f"M50,{GC + 1} L50,{GC - 3}", 1.0, 0.85)
            a.oval(50, GC - 6.4, 3.0, 4.4, 0, fr, 0.9)
            a.line(f"M50,{GC - 10.6} L50,{GC - 2.4}", 0.5, 0.4)
            a.line(f"M48.2,{GC - 10} Q47,{GC - 6.4} 48.4,{GC - 2.8}", 0.5, 0.35)
    _crocus_corms(a, (50,))
    return a


def crocus_dormant():
    a = Art(); a.ground(40)
    for x, w, h in ((42, 26, 16), (64, 18, 11)):
        roots(a, x, 80.4, 6, 8, 120, dead=True)
        corm(a, x, 80, w, h, shoots=1)
    return a



# ================================================================ bluebell
BELL_LEAF = strap("blunt", 0.88, 0.8)


def bluebell_leaf_band(a, p0, c, p1, W, fill, d=1):
    """A bluebell leaf: long, narrow, even width, glossy and fleshy, with a
    channel down the middle and a blunt hooded tip."""
    return band(a, p0, c, p1, W, fill, BELL_LEAF, lw=LW if d >= 2 else 0.85, mid=0.9 if d >= 2 else (0.6 if d else 0), midla=0.45,
                gloss=d >= 1, hood=d >= 1, shade=0.12)


def bluebell_leaf(a, sp):
    bluebell_leaf_band(a, (18, 95), (38, 0), (88, 44), 9.5, sp["fill"], d=2)
    return a


def bluebell_bell(a, x, y, ang, L, W, fc, d=1, anth="white", bud=False):
    """One bluebell flower hanging from (x, y) along ang (90 is straight
    down): a narrow tube of six tepals joined only at the base, their tips
    curled back at the mouth, cream anthers just inside. bud: still closed."""
    t = T(x, y, ang); lw = 0.9 if d >= 1 else 0.7
    if bud:
        petal(a, x, y, ang, L, W * 0.8, fc, "elliptic", lw=lw, shade=0.12)
        return
    hw = lambda u: W / 2 * (0.5 + 0.5 * math.sin(math.pi / 2 * min(1, u / 0.7)))
    us = [i / 20 for i in range(21)]
    side1 = [t(L * u, hw(u)) for u in us]; side2 = [t(L * u, -hw(u)) for u in us]
    a.shape(path(side1 + side2[::-1]), fc, lw)
    a.shape(path(side1 + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.12)
    if d >= 1:   # where the tepals meet, down the tube
        for o in ((-0.35, 0.35) if d < 2 else (-0.5, 0, 0.5)):
            a.line(opath([t(L * u, o * hw(u)) for u in (0.08, 0.5, 0.9)]), 0.45, 0.32)
    # the tips curled back at the mouth, one each side, and the front one
    for sg in (1, -1):
        e = t(L, sg * hw(1))
        a.shape(f"M{P(e)} Q{P(t(L + W * 0.45, sg * W * 0.95))} {P(t(L - W * 0.18, sg * W * 1.05))} Q{P(t(L - W * 0.05, sg * W * 0.72))} {P(t(L - W * 0.1, sg * hw(0.95) * 0.9))} Z", fc, lw * 0.85)
    a.shape(f"M{P(t(L - 0.2, W * 0.32))} Q{P(t(L + W * 0.55, 0))} {P(t(L - 0.2, -W * 0.32))} Z", fc, lw * 0.85)
    for o in ((-0.22, 0.22) if d < 2 else (-0.28, 0, 0.28)):   # the cream anthers in the mouth
        p = t(L + W * 0.12, o * W); a.oval(p[0], p[1], max(0.5, W * 0.09), max(0.7, W * 0.14), ang, anth, 0.4 if d >= 1 else 0.3)


def bluebell_spike(a, q, us, s, fc, d=1, buds=2, seed=False, fr="unripe", bract=None):
    """The flowers along one side of a stem (the curve q) at the points us,
    the oldest (lowest) first. Each hangs on a short stalk with a pair of
    narrow bluish bracts at its foot. seed: upright oval pods instead."""
    bract = bract or fc
    for j, u in enumerate(us):
        x, y = q.pt(u); ang = q.ang(u); sc = s * (1 - 0.1 * j / max(1, len(us) - 1))
        side = ang + 90   # always the same side of the stem: the lower side as it arches over
        if seed:   # the pods held upright on stalks that have turned up
            e = T(x, y, -90 + 25)(4.2 * sc)
            with a.on(STEM):
                a.line(f"M{f(x)},{f(y)} Q{P(T(x, y, 10)(2 * sc))} {P(e)}", 0.7, 0.85)
            with a.on(BLOOM):
                a.oval(e[0] + 0.6 * sc, e[1] - 3.2 * sc, 2.2 * sc, 3.4 * sc, 18, fr, 0.8)
                a.line(f"M{f(e[0] + 0.6 * sc)},{f(e[1] - 6.2 * sc)} L{f(e[0] + 0.6 * sc)},{f(e[1] - 0.4 * sc)}", 0.45, 0.35)
            continue
        e = T(x, y, side)(3.0 * sc)
        with a.on(STEM):
            a.line(f"M{f(x)},{f(y)} Q{P(T(x, y, side - 30)(2.0 * sc))} {P(e)}", 0.7 if d < 2 else 0.9, 0.85)
            if d >= 1:
                for o in (-18, 22):
                    b = T(x, y, side + o)(4.2 * sc); a.line(f"M{f(x)},{f(y)} L{P(b)}", 0.5 if d < 2 else 0.8, 0.7, bract)
        with a.on(BLOOM):
            bluebell_bell(a, e[0], e[1], 88 + (ang + 90 - 90) * 0.15, 9.5 * sc, 3.8 * sc, fc, d, bud=j >= len(us) - buds)


def bluebell_bloom(a, sp):
    fc = sp.get("fc", "bulbs_bluebell"); anth = sp.get("cen", "white")
    with a.group():
        with a.on(STEM):
            q = a.ribbon((22, 99), (24, 4), (88, 36), 2.8, 1.5, pal("bluebell", "leaf", "deep"), lw=0.9)
        bluebell_spike(a, q, (0.4, 0.52, 0.63, 0.73, 0.82, 0.9, 0.97), 1.65, fc, d=2, buds=2)
    return a


def bluebell_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 50, 84.5, 8, 9, 120)
    white_bulb(a, 50, 84, 30, 26, d=2)
    return a


def _bluebell_below(a, x=50, deep=0):
    a.ribbon((x, 79 + deep), (x, 72), (x, G), 2.8, 3.2, "white", lw=0.6)
    roots(a, x, 93.4, 6, 4, 120)
    white_bulb(a, x, 93, 14, 12)


def bluebell_leaves(a, spec, W=3.4, col=None, d=1):
    lc = col or pal("bluebell", "leaf", "deep")
    with a.on(LEAF):
        for p0, c, p1, *cc in spec:
            bluebell_leaf_band(a, p0, c, p1, W, cc[0] if cc else lc, d)


def bluebell_shoots():
    a = Art(); a.ground(G); fc = pal("bluebell", "flower", "bulbs_bluebell")
    with a.group():
        bluebell_leaves(a, [((47, G), (42, 50), (36, 40)), ((48.6, G), (47, 46), (44, 34)), ((51.6, G), (54, 48), (58, 36)), ((53, G), (60, 52), (66, 44))])
        with a.on(STEM):   # the flower spike rising, its tip hooked over, the buds tight
            q = a.ribbon((50, G), (48, 14), (62, 26), 2.0, 1.3, pal("bluebell", "leaf", "deep"), lw=0.7)
        for u in (0.62, 0.74, 0.85, 0.95):
            x, y = q.pt(u)
            with a.on(BLOOM):
                petal(a, x + 0.4, y + 0.6, 84, 5.2, 2.8, fc, "elliptic", lw=0.7, shade=0.12)
    _bluebell_below(a)
    return a


def bluebell_flower():
    a = Art(); a.ground(G); fc = pal("bluebell", "flower", "bulbs_bluebell")
    with a.group():
        bluebell_leaves(a, [((47, G), (30, 40), (12, 56)), ((48.4, G), (36, 34), (20, 38)), ((53, G), (70, 40), (88, 56)), ((51.6, G), (60, 36), (76, 40)),
                            ((49.4, G), (46, 40), (36, 30))])
        with a.on(STEM):
            q = a.ribbon((46, G), (40, 0), (86, 30), 2.2, 1.2, pal("bluebell", "leaf", "deep"), lw=0.8)
        bluebell_spike(a, q, (0.36, 0.47, 0.58, 0.68, 0.78, 0.87, 0.95), 1.15, fc, d=1, buds=2)
    _bluebell_below(a)
    return a


def bluebell_seed():
    a = Art(); a.ground(G); fr = pal("bluebell", "fruit", "unripe")
    with a.group():
        bluebell_leaves(a, [((47, G), (30, 52), (10, 62), "straw"), ((48.4, G), (36, 44), (18, 50), "pear"), ((53, G), (70, 50), (90, 62), "pear"),
                            ((51.6, G), (62, 46), (80, 50), "straw")], W=3.4)
        with a.on(STEM):   # the stem has straightened
            q = a.ribbon((50, G), (50.6, 36), (51, 10), 2.0, 1.2, "unripe", lw=0.8)
        bluebell_spike(a, q, (0.42, 0.52, 0.62, 0.72, 0.82, 0.92), 1.0, None, seed=True, fr=fr)
    _bluebell_below(a)
    return a


def bluebell_dormant():
    a = Art(); a.ground(36)
    roots(a, 50, 86.4, 7, 8, 120, dead=True)
    white_bulb(a, 50, 86, 22, 19)   # deep down
    return a



# ========================================================== grape hyacinth
MUSC_LEAF = strap("blunt", 0.88, 0.85)


def muscari_leaf_band(a, p0, c, p1, W, fill, d=1):
    """A grape hyacinth leaf: narrow, fleshy and floppy, deeply grooved down
    its upper side (the dark channel down the middle), blunt at the tip."""
    return band(a, p0, c, p1, W, fill, MUSC_LEAF, lw=LW if d >= 2 else 0.8, stripe="shade" if d >= 1 else None, stripew=0.3, stripefa=0.22,
                mid=0.7 if d >= 2 else 0, midla=0.5, shade=0.08)


def muscari_leaf(a, sp):
    muscari_leaf_band(a, (16, 95), (34, 4), (90, 66), 7, sp["fill"], d=2)
    return a


def urn(a, x, y, ang, L, W, fc, d=1, rim="white"):
    """One grape hyacinth flower hanging from (x, y) along ang: a small round
    urn of joined tepals, swollen in the middle and pinched at the mouth,
    with a white rim of six tiny teeth turned back round the mouth."""
    t = T(x, y, ang); lw = 0.8 if d >= 2 else 0.55
    hw = lambda u: W / 2 * (0.42 + 0.58 * math.sin(math.pi * min(1, u / 0.86)) ** 0.75) * (1 - 0.3 * max(0, u - 0.7) / 0.3)
    us = [i / 16 for i in range(17)]
    pts = [t(L * u, hw(u)) for u in us] + [t(L * u, -hw(u)) for u in us[::-1]]
    a.shape(path(pts), fc, lw)
    if d >= 1:
        a.shape(path([t(L * u, hw(u)) for u in us] + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.14)
    m = t(L * 1.02)
    if d >= 2:   # the six little teeth, turned back
        a.polar(m[0], m[1], lambda h: 1 + 0.22 * abs(math.cos(3 * h)), W * 0.2, W * 0.3, ang, rim, 0.5, shade=False)
    else:
        a.oval(m[0], m[1], max(0.5, W * 0.16), max(0.7, W * 0.26), ang, rim, 0.4 if d else 0.3)


def muscari_spike(a, x, y, H, Wd, fc, top, d=1, seed=False, fr="unripe"):
    """The flower spike from (x, y) (its foot, the top of the bare stem) up H:
    twenty or more urns packed in a cone, pointing down and outwards, the top
    few paler and smaller. seed: the papery three-winged pods instead."""
    rows = 12
    with a.on(BLOOM):
        if seed:
            for r in range(6):
                yy = y - r * H / 6.0; n = 1
                for j in range(n):
                    sg = 1 if r % 2 else -1
                    cx = x + sg * Wd * 0.28; col = "straw" if r < 2 else fr
                    a.line(f"M{f(x)},{f(yy)} L{f(cx)},{f(yy - 1.2)}", 0.5, 0.7)
                    w = Wd * 0.3; h = Wd * 0.26
                    # a flat pod of three rounded wings, notched at the top
                    a.shape(f"M{f(cx)},{f(yy - 1)} C{f(cx - w * 1.3)},{f(yy - 1.2)} {f(cx - w * 1.1)},{f(yy - h * 2.4)} {f(cx - w * 0.3)},{f(yy - h * 2.2)} "
                            f"L{f(cx)},{f(yy - h * 1.7)} L{f(cx + w * 0.3)},{f(yy - h * 2.2)} C{f(cx + w * 1.1)},{f(yy - h * 2.4)} {f(cx + w * 1.3)},{f(yy - 1.2)} {f(cx)},{f(yy - 1)} Z", col, 0.7)
                    a.line(f"M{f(cx)},{f(yy - 1.2)} L{f(cx)},{f(yy - h * 1.75)}", 0.45, 0.4)
            return
        if d < 2:   # small: one cone of packed bells, its edge bumpy with them, and the white rims in rows
            pts = []
            for i in range(41):
                u = i / 40; w = Wd / 2 * (1 - 0.78 * u ** 1.1) * (1 + 0.08 * math.cos(u * 34)) * (0.86 + 0.14 * min(1, u / 0.12))
                pts.append((x + w, y - u * H))
            pts = pts + [(2 * x - px, py) for px, py in pts[::-1]]
            a.shape(path(pts), fc, 0.8)
            a.shape(path(pts[:41] + [(x, y - H), (x, y)]), "shade", 0, fa=0.14)
            cap = [(x + Wd * 0.22 * math.sin(math.pi * i / 20) * (1 if i <= 20 else 0), 0) for i in range(21)]
            a.oval(x, y - H * 0.9, Wd * 0.17, H * 0.12, 0, top, 0.7)
            for r in range(4):
                u = 0.06 + r * 0.2; w = Wd / 2 * (1 - 0.78 * u ** 1.1)
                n = 3 if r < 2 else 2
                for j in range(n):
                    v = (j / (n - 1) - 0.5) * 1.5
                    a.dot(x + v * w, y - u * H + 0.4, max(0.35, Wd * 0.045), "white")
            return
        spots = []
        rows = 10
        for r in range(rows):   # rows of bells, each row set half a bell across from the one below, like a bunch of grapes
            u = r / (rows - 1)
            yy = y - u * H; w = Wd / 2 * (1 - 0.66 * u ** 1.2)
            step = Wd * 0.24 * (1 - 0.3 * u)
            k = int(w / step + 0.5); off = 0.5 * step if r % 2 else 0
            for j in range(-k, k + 1):
                px = j * step + off
                if abs(px) <= w + 0.01:
                    spots.append((yy, px / max(w, 0.1), px, u))
        for yy, v, px, u in sorted(spots, key=lambda p: (p[0], -abs(p[1]))):   # the top rows first, each lower row hanging in front
            col = top if u > 0.82 else fc
            sc = 1 - 0.36 * u
            L = Wd * 0.27 * sc; W = Wd * 0.23 * sc
            urn(a, x + px, yy - L * 0.62, 90 - v * 34, L, W, col, d)


def muscari_bloom(a, sp):
    fc = sp.get("fc", "bulbs_muscari"); rim = sp.get("cen", "white")
    with a.group():
        with a.on(STEM):
            a.ribbon((50, 98), (50.6, 86), (50, 72), 3.6, 3.2, pal("grape-hyacinth", "leaf", "leaf"), lw=0.9)
        muscari_spike(a, 50, 78, 62, 36, fc, "bulbs_muscari_pale", d=2)
    return a


def _musc_bulb(a, x, y, s, d=1):
    """A small round bulb in a pale brown papery skin, with offset bulblets round it."""
    roots(a, x, y + 0.4, 7, 8 * s, 120)
    tunic(a, x - 10 * s, y - 0.6 * s, 9 * s, 7.6 * s, fill="seed", nose=0.9, lean=-0.08, d=d)
    tunic(a, x + 11 * s, y - 0.4 * s, 10 * s, 8.4 * s, fill="seed", nose=0.9, lean=0.08, d=d)
    tunic(a, x, y, 20 * s, 18 * s, fill="seed", nose=0.85, d=d)


def muscari_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    _musc_bulb(a, 50, 82, 1.45, d=2)
    return a


def muscari_leaves(a, spec, W=2.6, col=None, d=1):
    lc = col or pal("grape-hyacinth", "leaf", "leaf")
    with a.on(LEAF):
        for p0, c, p1, *cc in spec:
            muscari_leaf_band(a, p0, c, p1, W, cc[0] if cc else lc, d)


def _musc_below(a, x=50):
    a.ribbon((x, 82), (x, 74), (x, G), 2.6, 3.0, "pale", lw=0.6)
    _musc_bulb(a, x, 92, 0.52)


SPRAWL = [((47, G), (32, 40), (8, 58)), ((48, G), (36, 34), (16, 44)), ((53, G), (68, 40), (92, 58)), ((52, G), (66, 34), (84, 42)),
          ((49, G), (42, 34), (28, 34)), ((51, G), (58, 32), (72, 32)), ((48.6, G), (30, 50), (12, 66)), ((51.4, G), (72, 52), (90, 66))]


def muscari_shoots():
    a = Art(); a.ground(G)
    with a.group():   # autumn: the leaves already up and sprawling over the soil, no flower spike yet
        muscari_leaves(a, [((47, G), (34, 44), (12, 58)), ((48, G), (38, 40), (20, 46)), ((53, G), (66, 44), (88, 58)), ((52, G), (64, 38), (80, 44)),
                           ((49.4, G), (46, 44), (36, 42)), ((50.6, G), (56, 42), (64, 40))])
    _musc_below(a)
    return a


def muscari_flower():
    a = Art(); a.ground(G); fc = pal("grape-hyacinth", "flower", "bulbs_muscari"); lc = pal("grape-hyacinth", "leaf", "leaf")
    with a.group():
        muscari_leaves(a, SPRAWL[:6] + [((49.4, G), (40, 40), (24, 26)), ((50.6, G), (62, 42), (76, 26))])
        for x, top, h, w in ((44, 38, 22, 11), (57, 32, 26, 12.5)):
            with a.on(STEM):
                a.ribbon((50 + (x - 50) * 0.2, G), (x, (G + top) / 2 + 4), (x, top), 1.8, 1.6, lc, lw=0.7)
            muscari_spike(a, x, top + 1.6, h, w, fc, "bulbs_muscari_pale", d=1)
    _musc_below(a)
    return a


def muscari_seed():
    a = Art(); a.ground(G); fr = pal("grape-hyacinth", "fruit", "unripe"); lc = pal("grape-hyacinth", "leaf", "leaf")
    with a.group():
        muscari_leaves(a, [((47, G), (32, 52), (8, 62), "straw"), ((53, G), (68, 52), (92, 62), "straw"), ((48, G), (36, 46), (18, 54), "pear"),
                           ((52, G), (66, 46), (82, 54), "pear")])
        for x, top in ((44, 30), (57, 24)):
            with a.on(STEM):
                a.ribbon((50 + (x - 50) * 0.2, G), (x, (G + top) / 2 + 4), (x, top), 1.6, 1.3, "pear", lw=0.7)
                a.line(f"M{f(x)},{f(top + 22)} L{f(x)},{f(top)}", 0.0001, 0)
            muscari_spike(a, x, top + 22, 24, 13, None, None, seed=True, fr=fr)
    _musc_below(a)
    return a


def muscari_dormant():
    a = Art(); a.ground(40)
    _musc_bulb(a, 50, 82, 0.95)
    return a



# ============================================================== puschkinia
PUSCH_LEAF = strap("blunt", 0.86, 0.82)
GP = 70   # puschkinia is a small plant: a lower soil line


def pusch_leaf_band(a, p0, c, p1, W, fill, d=1):
    """A puschkinia leaf: strap-shaped, bright green, blunt, with fine
    parallel veins and a shallow channel down the middle."""
    return band(a, p0, c, p1, W, fill, PUSCH_LEAF, lw=LW if d >= 2 else 0.85,
                veins=(0.6, -0.6, 0.3, -0.3) if d >= 2 else ((0.45, -0.45) if W > 3.5 else ()), vla=0.26, mid=0.6 if d >= 2 else 0, midla=0.3)


def pusch_leaf(a, sp):
    pusch_leaf_band(a, (32, 95), (40, 44), (70, 8), 13, sp["fill"], d=2)
    return a


def pusch_star(a, x, y, R, fc, stripe, d=1, k=0.82, rot=0.0, anth="sun"):
    """One puschkinia flower centred on (x, y), R across to a tepal tip:
    six pointed-oval pale tepals spreading in a star, each with a clear
    darker blue stripe down its middle, round a tiny pale cup (the joined
    stamen stalks) holding yellow anthers. k and rot tilt it: it faces out
    and nods a little."""
    M = squash(x, y, 1.0, k, rot); lw = 0.9 if d >= 2 else 0.6
    order = sorted(range(6), key=lambda i: math.sin(math.radians(-90 + 60 * i + 30)))
    for i in order:
        ang = -90 + 60 * i + 30
        petal(a, x, y, ang, R, R * 0.52, fc, "point", lw=lw, M=M, shade=0.05)
        t = T(x, y, ang)
        a.line(opath([M(t(R * u)) for u in (0.14, 0.45, 0.8)]), max(0.6, R * 0.07), 0.9, stripe)
    cw = R * 0.22
    a.oval(x, y, cw, cw * k, rot, "white", 0.6 if d >= 2 else 0.45)
    if d >= 1:
        for j in range(3 if d < 2 else 5):
            e = T(x, y, j * 72 + 10)(cw * 0.45); a.dot(e[0], e[1], max(0.35, R * 0.035), anth)


def pusch_bloom(a, sp):
    fc = sp.get("fc", "white"); st = sp.get("cen", "blue")
    lc = pal("puschkinia", "leaf", "leaf")
    with a.group():
        with a.on(STEM):
            q = a.ribbon((52, 99), (50, 50), (54, 8), 2.8, 2.0, lc, lw=0.9)
        for u, side, R, k, rot in ((0.38, -1, 22, 0.8, -12), (0.6, 1, 18, 0.72, 14), (0.8, -1, 13, 0.6, -16)):
            x, y = q.pt(u); e = (x + side * 18 * R / 22, y + 4)
            with a.on(STEM):
                a.line(f"M{f(x)},{f(y)} Q{f(x + side * 8)},{f(y - 4)} {P(e)}", 0.9, 0.85)
            with a.on(BLOOM):
                pusch_star(a, e[0], e[1] + R * 0.1, R, fc, st, d=2, k=k, rot=rot)
        with a.on(BLOOM):   # buds at the top
            x, y = q.pt(0.97); petal(a, x, y + 1, -70, 7, 4, fc, "elliptic", lw=0.7, shade=0.1, lines=1, linec=st, la=0.8)
    return a


def pusch_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 50, 84.4, 7, 9, 120)
    tunic(a, 50, 84, 30, 24, fill="bark", nose=1.2, d=2)
    return a


def _pusch_below(a, xs=(50,)):
    for x in xs:
        a.ribbon((x, 84), (x, 78), (x, GP), 2.4, 2.8, "pale", lw=0.6)
        roots(a, x, 93.4, 5, 4, 120)
        tunic(a, x, 93, 10, 8, fill="bark", nose=1.2)


def pusch_plant(a, x, top, lean, fc, st, lc, n=5, seed=False, fr="unripe", leafc=None):
    """One puschkinia: two upright leaves facing each other, wrapping the
    foot of the stem, and a loose spike of pale striped stars (or pods)."""
    leafc = leafc or lc
    with a.on(LEAF):
        pusch_leaf_band(a, (x - 1.4, GP + 0.5), (x - 3 - lean, GP - 16), (x - 10 + lean * 2, GP - 28), 5.0, leafc)
        pusch_leaf_band(a, (x + 1.4, GP + 0.5), (x + 3 - lean, GP - 16), (x + 9 + lean * 2, GP - 30), 5.0, leafc)
    with a.on(STEM):
        q = a.ribbon((x, GP), (x + lean * 0.3, (GP + top) / 2), (x + lean, top), 1.5, 1.2, lc if not seed else "pear", lw=0.7)
    for j in range(n):
        u = 0.5 + 0.5 * j / (n - 1); px, py = q.pt(u); side = -1 if j % 2 else 1
        if seed:
            e = (px + side * 3.2, py + 0.6)
            with a.on(STEM):
                a.line(f"M{f(px)},{f(py)} L{P(e)}", 0.6, 0.85)
            with a.on(BLOOM):   # a round, three-lobed pod
                a.polar(e[0], e[1] + 1.6, lambda h: 1 + 0.1 * math.cos(3 * h), 2.1, 2.0, 0, fr, 0.7)
                a.line(f"M{f(e[0] - 0.6)},{f(e[1] + 0.2)} L{f(e[0] - 0.2)},{f(e[1] + 3.2)}", 0.45, 0.35)
            continue
        e = (px + side * 5.4, py + 1.6)
        with a.on(STEM):
            a.line(f"M{f(px)},{f(py)} Q{f(px + side * 2.4)},{f(py - 1.2)} {P(e)}", 0.6, 0.85)
        with a.on(BLOOM):
            if j >= n - 1:
                petal(a, e[0], e[1], -60 * side - 90 * (1 - side) / 1, 3.6, 2.2, fc, "elliptic", lw=0.6, shade=0.1)
            else:
                pusch_star(a, e[0], e[1] + 1, 6.2 * (1 - 0.1 * j), fc, st, d=1, k=0.75, rot=side * 14)


def pusch_shoots():
    a = Art(); a.ground(GP); lc = pal("puschkinia", "leaf", "leaf"); fc = pal("puschkinia", "flower", "white")
    with a.group():
        with a.on(LEAF):
            pusch_leaf_band(a, (48.8, GP + 0.5), (46.4, GP - 8), (43, GP - 17), 5.0, lc)
            pusch_leaf_band(a, (51.2, GP + 0.5), (53.6, GP - 8), (57, GP - 16), 5.0, lc)
        with a.on(BLOOM):   # the bud cluster rising between the two leaves
            a.ribbon((50, GP), (50, GP - 8), (50, GP - 15), 1.4, 1.2, lc, lw=0.6)
            for dx, dy, ang in ((-1.4, -15, -110), (1.4, -15.6, -70), (0, -18.4, -90)):
                petal(a, 50 + dx * 0.4, GP + dy + 2, ang, 4.4, 2.8, fc, "elliptic", lw=0.6, shade=0.1, lines=1, linec="blue", la=0.8)
    _pusch_below(a)
    return a


def pusch_flower():
    a = Art(); a.ground(GP); lc = pal("puschkinia", "leaf", "leaf"); fc = pal("puschkinia", "flower", "white"); st = pal("puschkinia", "centre", "blue")
    with a.group():
        pusch_plant(a, 30, 22, -2, fc, st, lc, n=5)
        pusch_plant(a, 68, 30, 2, fc, st, lc, n=4)
    _pusch_below(a, (30, 68))
    return a


def pusch_seed():
    a = Art(); a.ground(GP); lc = pal("puschkinia", "leaf", "leaf"); fr = pal("puschkinia", "fruit", "unripe")
    with a.group():
        with a.on(LEAF):
            pusch_leaf_band(a, (48.8, GP + 0.5), (40, GP - 16), (30, GP - 22), 4.2, "pear")
            pusch_leaf_band(a, (51.2, GP + 0.5), (60, GP - 14), (72, GP - 18), 4.2, "straw")
        with a.on(STEM):   # the stem flopping as the pods ripen
            q = a.ribbon((50, GP), (52, GP - 30), (76, GP - 22), 1.5, 1.1, "pear", lw=0.7)
        for j, u in enumerate((0.55, 0.68, 0.8, 0.92)):
            px, py = q.pt(u)
            with a.on(BLOOM):
                a.line(f"M{f(px)},{f(py)} L{f(px + 0.6)},{f(py + 2.4)}", 0.6, 0.85)
                a.polar(px + 0.6, py + 4.4, lambda h: 1 + 0.1 * math.cos(3 * h), 2.3, 2.2, 0, fr, 0.7)
                a.line(f"M{f(px)},{f(py + 2.8)} L{f(px + 0.4)},{f(py + 6.2)}", 0.45, 0.35)
    _pusch_below(a)
    return a


def pusch_dormant():
    a = Art(); a.ground(40)
    roots(a, 44, 82.4, 6, 9, 120, dead=True); tunic(a, 44, 82, 20, 16, fill="bark", nose=1.2)
    roots(a, 63, 81.3, 4, 6, 110, dead=True); tunic(a, 63, 81, 13, 10, fill="bark", nose=1.2)
    return a



# ================================================== snake's head fritillary
FRIT_LEAF = lance(0.1, 0.8, 1.05)


def frit_leaf_on(a, sx, sy, tip, W, fill, d=1):
    """A narrow grey-green fritillary leaf, stalkless and half clasping the
    stem at (sx, sy), tapering gradually to a point at tip."""
    c = (sx + (tip[0] - sx) * 0.35, tip[1] + (sy - tip[1]) * 0.55)
    with a.on(LEAF):
        band(a, (sx, sy + W * 0.2), c, tip, W, fill, FRIT_LEAF, lw=LW if d >= 2 else 0.8,
             veins=(0.5, -0.5) if d >= 2 else (), vla=0.26, mid=0.6 if d >= 2 else 0, midla=0.3, shade=0.1)


def frit_leaf(a, sp):
    with a.group():
        with a.on(STEM):
            a.ribbon((38, 98), (39, 50), (41, 6), 3.2, 2.6, sp["fill"], lw=0.9)
        frit_leaf_on(a, 38.8, 74, (88, 14), 9, sp["fill"], d=2)
    return a


def frit_bell(a, x, y, L, W, fc, pale, d=1, ang=90):
    """A snake's head fritillary flower hanging from (x, y) along ang: a
    square-shouldered bell of six free tepals, a little narrower at the
    mouth, chequered like a chessboard in dark maroon on pale pink-lilac."""
    t = T(x, y, ang); lw = 0.9 if d >= 1 else 0.7
    hw = lambda u: W / 2 * (0.2 + 0.8 * math.sin(math.pi / 2 * min(1, u / 0.2)) ** 0.75) * (1 - 0.15 * max(0, u - 0.3) / 0.7)
    us = [i / 30 for i in range(31)]
    tips = []
    for j in range(7):   # the mouth: the tips of the tepals, slightly pointed
        v = -1 + 2 * j / 6
        tips.append(t(L + (2.4 * L / 52 if j % 2 == 1 else -0.4 * L / 52), hw(1) * v * (1.06 if j % 2 == 1 else 1)))
    out = [t(L * u, hw(u)) for u in us] + tips[::-1] + [t(L * u, -hw(u)) for u in us[::-1]]
    a.shape(path(out), pale, lw)
    rows = 9 if d >= 2 else 5; cols = 7 if d >= 2 else 4
    for i in range(rows):   # the chequers
        u0, u1 = 0.05 + 0.95 * i / rows, 0.05 + 0.95 * (i + 1) / rows
        for j in range(cols):
            if (i + j) % 2:
                continue
            v0, v1 = -1 + 2 * j / cols, -1 + 2 * (j + 1) / cols
            q = [t(L * u0, hw(u0) * v0), t(L * u1, hw(u1) * v0), t(L * min(1, u1), hw(u1) * v1), t(L * u0, hw(u0) * v1)]
            a.shape(path(q), fc, 0)
    a.shape(path([t(L * u, hw(u)) for u in us] + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.14)
    for v in ((-0.34, 0.34) if d < 2 else (-0.66, -0.33, 0.0, 0.33, 0.66)):   # where the tepals meet
        a.line(opath([t(L * u, hw(u) * v) for u in (0.12, 0.4, 0.7, 0.98)]), 0.45 if d < 2 else 0.55, 0.45)
    a.shape(path(out), None, lw)   # the outline again, crisp over the chequers


def frit_bloom(a, sp):
    fc = sp.get("fc", "bulbs_maroon")
    with a.group():
        with a.on(STEM):
            a.ribbon((32, 98), (28, 30), (44, 12), 2.4, 1.8, pal("snake-s-head-fritillary", "leaf", "sage"), lw=0.8)
            a.ribbon((44, 12), (54, 4), (58, 19), 1.8, 1.5, pal("snake-s-head-fritillary", "leaf", "sage"), lw=0.8)
        with a.on(BLOOM):
            frit_bell(a, 58, 17, 62, 38, fc, "bulbs_chequer", d=2, ang=92)
    return a


def frit_bulb():
    a = Art(); a.ground(38, marks=False); soil_flecks(a)
    roots(a, 50, 83, 7, 9, 120)
    scale_bulb(a, 50, 82, 26, 28, d=2)
    return a


def _frit_below(a, x=50):
    a.ribbon((x, 85), (x, 76), (x, G), 1.8, 2.2, "white", lw=0.6)
    roots(a, x, 93.4, 5, 4, 120)
    scale_bulb(a, x, 93, 9, 10)


def frit_plant(a, x, top, lean, lc, stage="flower", fc=None, fr="unripe", leafc=None):
    """One slender stem with a few narrow leaves spaced up it."""
    leafc = leafc or lc
    with a.on(STEM):
        if stage == "seed":   # the stem has straightened to hold the pod up
            q = a.stem((x, G), (x + lean * 0.4, (G + top) / 2), (x + lean * 0.6, top), 1.3, col="line")
        else:
            q = a.stem((x, G), (x + lean * 0.2, top + 8), (x + lean, top), 1.3, col="line")
    for i, (u, side, L) in enumerate(((0.12, -1, 17), (0.32, 1, 16), (0.5, -1, 13), (0.66, 1, 10))):
        px, py = q.pt(u)
        frit_leaf_on(a, px, py, (px + side * L * 0.5, py - L * 0.86), 2.6, leafc)
    tip = q.pt(1)
    with a.on(BLOOM):
        if stage == "flower":
            a.line(f"M{P(tip)} Q{f(tip[0] + 6)},{f(tip[1] - 4)} {f(tip[0] + 8)},{f(tip[1] + 2)}", 1.0, 0.9)
            frit_bell(a, tip[0] + 8, tip[1] + 2, 17, 11.5, fc, "bulbs_chequer", d=1, ang=96)
        elif stage == "shoots":   # a single bud hanging at the tip
            a.line(f"M{P(tip)} Q{f(tip[0] + 4)},{f(tip[1] - 3)} {f(tip[0] + 5)},{f(tip[1] + 1.5)}", 0.9, 0.9)
            petal(a, tip[0] + 5, tip[1] + 1.5, 96, 8, 4.4, "unripe", "elliptic", lw=0.7, shade=0.12)
            a.line(f"M{f(tip[0] + 4.6)},{f(tip[1] + 5)} L{f(tip[0] + 4.4)},{f(tip[1] + 8.6)}", 0.6, 0.6, fc)
        else:   # the oblong three-sided pod, standing upright
            a.shape(f"M{f(tip[0] - 2.4)},{f(tip[1] + 1)} Q{f(tip[0] - 3.4)},{f(tip[1] - 5)} {f(tip[0] - 2.2)},{f(tip[1] - 9.4)} L{f(tip[0])},{f(tip[1] - 10.4)} "
                    f"L{f(tip[0] + 2.2)},{f(tip[1] - 9.4)} Q{f(tip[0] + 3.4)},{f(tip[1] - 5)} {f(tip[0] + 2.4)},{f(tip[1] + 1)} Z", fr, 0.9)
            a.line(f"M{f(tip[0] + 0.6)},{f(tip[1])} L{f(tip[0] + 0.6)},{f(tip[1] - 9.4)}", 0.5, 0.4)


def frit_shoots():
    a = Art(); lc = pal("snake-s-head-fritillary", "leaf", "sage"); a.ground(G)
    with a.group():
        frit_plant(a, 50, 34, 2, lc, "shoots", fc=pal("snake-s-head-fritillary", "flower", "bulbs_maroon"))
    _frit_below(a)
    return a


def frit_flower():
    a = Art(); lc = pal("snake-s-head-fritillary", "leaf", "sage"); a.ground(G); fc = pal("snake-s-head-fritillary", "flower", "bulbs_maroon")
    with a.group():
        frit_plant(a, 34, 16, -3, lc, "flower", fc)
        frit_plant(a, 60, 22, 3, lc, "flower", fc)
    _frit_below(a, 34); _frit_below(a, 60)
    return a


def frit_seed():
    a = Art(); lc = pal("snake-s-head-fritillary", "leaf", "sage"); a.ground(G)
    with a.group():
        frit_plant(a, 50, 14, 1, lc, "seed", fr=pal("snake-s-head-fritillary", "fruit", "unripe"), leafc="pear")
    _frit_below(a)
    return a


def frit_dormant():
    a = Art(); a.ground(40)
    roots(a, 50, 80.4, 6, 8, 120, dead=True)
    scale_bulb(a, 50, 80, 17, 19)
    return a



# =========================================================== crown imperial
CROWN_LEAF = lance(0.32, 0.55, 0.9)


def crown_leaf_on(a, sx, sy, tip, W, fill, d=1):
    """A crown imperial leaf: lance-shaped, glossy, stalkless (joined straight
    to the stem at (sx, sy)), with several parallel veins and a pointed tip."""
    c = lerp((sx, sy), tip, 0.5); c = (c[0] - (tip[1] - sy) * 0.08, c[1] + (tip[0] - sx) * 0.08)
    with a.on(LEAF):
        band(a, (sx, sy), c, tip, W, fill, CROWN_LEAF, lw=LW if d >= 2 else (0.8 if d else 0.6),
             veins=(0.66, -0.66, 0.33, -0.33) if d >= 2 else ((0.45, -0.45) if W >= 4 else ()), vla=0.26,
             mid=0.7 if d >= 2 else (0.5 if W >= 3 else 0), midla=0.4, gloss=d >= 2, shade=0.1)


def crown_leaf(a, sp):
    with a.group():
        with a.on(STEM):
            a.ribbon((24, 98), (25, 50), (27, 6), 6.0, 5.4, "unripe", lw=0.9)
        crown_leaf_on(a, 26, 80, (88, 18), 22, sp["fill"], d=2)
    return a


def crown_bell(a, x, y, ang, L, W, fc, d=1, inside=False, nect="white"):
    """One crown imperial flower hanging from (x, y) along ang: a broad bell
    of six oblong tepals, orange-red with darker veins. inside: tilted
    towards you, so you see up into it: the big white nectaries, each with
    its drop, round the base inside, and the yellow anthers and the style
    hanging just below the rim."""
    t = T(x, y, ang); lw = 0.9 if d >= 1 else 0.7
    hw = lambda u: W / 2 * (0.3 + 0.7 * math.sin(math.pi / 2 * min(1, u / 0.42)) ** 0.8)
    us = [i / 30 for i in range(31)]
    rimk = 0.42 if inside else 0.2
    rim = [t(L + W / 2 * rimk * math.cos(h), W / 2 * math.sin(h) * 1.04) for h in [-math.pi / 2 + math.pi * i / 30 for i in range(31)]]
    out = [t(L * u, -hw(u)) for u in us] + rim + [t(L * u, hw(u)) for u in us[::-1]]
    if inside:   # the anthers and style hang out of the mouth, behind the rim
        for o in (-0.5, -0.2, 0.15, 0.45):
            p0 = t(L * 0.95, o * W * 0.4); p1 = t(L + W * 0.32, o * W * 0.5)
            a.line(f"M{P(p0)} L{P(p1)}", 0.6, 0.7); a.oval(p1[0], p1[1], 1.3, 2.4, ang, "sun", 0.5)
        p0 = t(L * 0.95, 0); p1 = t(L + W * 0.48, W * 0.04)
        a.line(f"M{P(p0)} L{P(p1)}", 0.9, 0.8, "unripe")
        for o in (-30, 0, 30):
            e = T(*p1, ang + o)(1.8); a.line(f"M{P(p1)} L{P(e)}", 0.7, 0.8, "unripe")
    a.shape(path(out), fc, lw)
    a.shape(path([t(L * u, -hw(u)) for u in us] + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=0.14)
    if d >= 1:   # the darker veins down each tepal
        for v in ((-0.6, -0.2, 0.2, 0.6) if d >= 2 else (-0.4, 0.4)):
            a.line(opath([t(L * u, hw(u) * v) for u in (0.18, 0.5, 0.8, 0.97)]), 0.5 if d < 2 else 0.6, 0.6, "beet")
    if inside:
        c = t(L + 0.3)
        mouth = [t(L + W / 2 * rimk * 0.8 * math.cos(h), W / 2 * 0.86 * math.sin(h)) for h in [2 * math.pi * i / 40 for i in range(40)]]
        a.shape(path(mouth), fc, 0.6)
        a.shape(path(mouth), "shade", 0, fa=0.3)
        for k in range(6):   # the white nectaries round the base inside, each holding a drop
            h = 2 * math.pi * k / 6 + 0.3
            p = t(L + W / 2 * rimk * 0.42 * math.cos(h), W / 2 * 0.46 * math.sin(h))
            a.oval(p[0], p[1], 2.2, 2.8, ang, nect, 0.6)
            a.dot(p[0] - 0.5, p[1] - 0.6, 0.7, "blue")
    else:   # the anthers just showing below the rim
        for o in (-0.25, 0.25):
            p = t(L + 1.6, o * W * 0.4); a.oval(p[0], p[1], 0.8, 1.3, ang, "sun", 0.4)


def crown_tuft(a, x, y, R, fill, d=1, n=11):
    """The crown of leafy bracts standing up above the flowers."""
    for k in range(n):
        ang = -90 + (k - (n - 1) / 2) * (150 / (n - 1)); L = R * (1 - 0.3 * abs(k - (n - 1) / 2) / ((n - 1) / 2))
        crown_leaf_on(a, x, y, T(x, y, ang)(L), max(2.0, R * 0.2), fill, d=d)


def crown_bloom(a, sp):
    fc = sp.get("fc", "rust"); nect = sp.get("cen", "white"); lc = pal("crown-imperial", "leaf", "leaf")
    with a.group():
        with a.on(STEM):
            a.ribbon((26, 98), (26, 60), (26, 22), 5.0, 4.2, "unripe", lw=0.9)
            a.line("M27,34 Q44,26 50,38", 1.8, 0.9)
        with a.on(LEAF):
            crown_tuft(a, 26, 23, 17, lc, d=1, n=9)
        with a.on(BLOOM):
            crown_bell(a, 50, 37, 70, 38, 34, fc, d=2, inside=True, nect=nect)
    return a


def crown_bulb():
    a = Art(); a.ground(36, marks=False); soil_flecks(a, (44, 48, 90, 86))
    roots(a, 50, 90, 9, 7, 130)
    scale_bulb(a, 50, 90, 40, 46, fill="bulbs_cream", hole=True, d=2)
    return a


GI = 80   # crown imperial is tall: the soil line is low in the tile


def _crown_below(a, x=50, k=1.0):
    roots(a, x, 97, 6, 2.2, 140)
    scale_bulb(a, x, 97, 14 * k, 20 * k, fill="bulbs_cream", hole=True)


def crown_plant(a, x, stage, lc, fc, fr):
    top = 14
    with a.on(STEM):
        a.ribbon((x, GI), (x, (GI + top) / 2), (x, top + 4), 3.4, 2.6, "pear" if stage == "dormant" else "unripe", lw=0.8)
    # the leaves crowded round the lower half of the stem, in whorls
    for i, (y, L) in enumerate(((GI - 4, 16), (GI - 10, 15), (GI - 16, 13.5), (GI - 22, 12), (GI - 27, 10))):
        for side in (-1, 1):
            ang = -90 + side * (52 - i * 3)
            crown_leaf_on(a, x + side * 1.0, y, T(x + side * 1.0, y, ang)(L), 3.8, lc)
        crown_leaf_on(a, x, y - 1.5, T(x, y - 1.5, -90 + (12 if i % 2 else -12))(L * 0.7), 3.0, lc)
    with a.on(LEAF):
        crown_tuft(a, x, top + 3, 11, lc, d=1, n=11)
    ring = [(-140, 0.8), (-40, 0.8), (170, 1.0), (10, 1.0), (115, 0.9), (65, 0.9)]
    for th, k in sorted(ring, key=lambda p: math.sin(math.radians(p[0]))):
        px = x + 8 * math.cos(math.radians(th)); py = top + 7 + 2.2 * math.sin(math.radians(th))
        with a.on(STEM):
            if stage == "seed":
                a.line(f"M{f(x)},{f(top + 6)} Q{f(px)},{f(top + 7)} {f(px)},{f(py - 3)}", 0.9, 0.85)
            else:
                a.line(f"M{f(x)},{f(top + 6)} Q{f(px)},{f(top + 2)} {f(px)},{f(py)}", 0.9, 0.85)
        with a.on(BLOOM):
            if stage == "seed":   # the pods have turned to stand upright, six-winged
                a.shape(f"M{f(px - 2.4)},{f(py - 2)} L{f(px - 2.8)},{f(py - 8)} L{f(px - 1.2)},{f(py - 10.4)} L{f(px + 1.2)},{f(py - 10.4)} "
                        f"L{f(px + 2.8)},{f(py - 8)} L{f(px + 2.4)},{f(py - 2)} Z", fr, 0.8)
                for o in (-1.2, 1.2):
                    a.line(f"M{f(px + o * 0.8)},{f(py - 2.4)} L{f(px + o)},{f(py - 9.8)}", 0.45, 0.4)
            else:
                crown_bell(a, px, py, 90 + (px - x) * 1.6, 10 * k, 7.6 * k, fc, d=1)


def crown_shoots():
    a = Art(); a.ground(G); lc = pal("crown-imperial", "leaf", "leaf")
    with a.group():
        with a.on(STEM):   # the thick fleshy shoot, like a giant asparagus spear, flushed purple
            band(a, (50, G + 1), (50, 48), (50.6, 24), 11, "unripe", lance(0.12, 0.95, 1.3), lw=0.9, stripe="plum", stripew=0.8, stripefa=0.4,
                 veins=(0.5, -0.5), vla=0.3)
        for y, side, L in ((48, -1, 14), (44, 1, 13), (39, -1, 11), (35, 1, 9.5), (31, -1, 8)):   # the crowded leaves starting to unfold
            crown_leaf_on(a, 50 + side * 2.4, y, (50 + side * L * 0.55, y - L * 0.85), 4.0, lc)
    _crown_below(a, 50, 0.9)
    a.ribbon((50, 84), (50, 75), (50, G), 5, 6, "bulbs_cream", lw=0.6)
    return a


def crown_flower():
    a = Art(); a.ground(GI)
    with a.group():
        crown_plant(a, 50, "flower", pal("crown-imperial", "leaf", "leaf"), pal("crown-imperial", "flower", "rust"), None)
    _crown_below(a)
    return a


def crown_seed():
    a = Art(); a.ground(GI)
    with a.group():
        crown_plant(a, 50, "seed", pal("crown-imperial", "leaf", "leaf"), None, pal("crown-imperial", "fruit", "unripe"))
    _crown_below(a)
    return a


def crown_dormant():
    a = Art(); a.ground(40)
    with a.group():
        with a.on(STEM):   # the old stem dying yellow and brown, with a few dead leaves hanging
            a.ribbon((50, 40), (50.6, 26), (52, 10), 3.2, 2.4, "straw", lw=0.8)
        for y, side in ((36, -1), (32, 1), (27, -1)):
            with a.on(LEAF):
                band(a, (50 + side, y), (50 + side * 6, y - 2), (50 + side * 10, y + 5), 3.0, "bark", CROWN_LEAF, lw=0.7, shade=0.08)
    roots(a, 50, 87, 8, 6, 130, dead=True)
    scale_bulb(a, 50, 87, 30, 36, fill="bulbs_cream", hole=True)
    return a


# ================================================================== tables
LEAF_DRAW = {"bulbs_snowdrop": snowdrop_leaf, "bulbs_daffodil": daffodil_leaf, "bulbs_tulip": tulip_leaf, "bulbs_crocus": crocus_leaf, "bulbs_bluebell": bluebell_leaf, "bulbs_muscari": muscari_leaf, "bulbs_puschkinia": pusch_leaf, "bulbs_fritillary": frit_leaf, "bulbs_crown": crown_leaf}
BLOOM_DRAW = {"bulbs_snowdrop": snowdrop_bloom, "bulbs_daffodil": daffodil_bloom, "bulbs_tulip": tulip_bloom, "bulbs_crocus": crocus_bloom, "bulbs_bluebell": bluebell_bloom, "bulbs_muscari": muscari_bloom, "bulbs_puschkinia": pusch_bloom, "bulbs_fritillary": frit_bloom, "bulbs_crown": crown_bloom}
LEAFX = {"snowdrop": dict(kind="bulbs_snowdrop", fill=pal("snowdrop", "leaf", "sage")),
         "daffodil": dict(kind="bulbs_daffodil", fill=pal("daffodil", "leaf", "sage")),
         "tulip": dict(kind="bulbs_tulip", fill=pal("tulip", "leaf", "sage")),
         "crocus": dict(kind="bulbs_crocus", fill=pal("crocus", "leaf", "deep")),
         "bluebell": dict(kind="bulbs_bluebell", fill=pal("bluebell", "leaf", "deep")),
         "grape-hyacinth": dict(kind="bulbs_muscari", fill=pal("grape-hyacinth", "leaf", "leaf")),
         "puschkinia": dict(kind="bulbs_puschkinia", fill=pal("puschkinia", "leaf", "leaf")),
         "snake-s-head-fritillary": dict(kind="bulbs_fritillary", fill=pal("snake-s-head-fritillary", "leaf", "sage")),
         "crown-imperial": dict(kind="bulbs_crown", fill=pal("crown-imperial", "leaf", "leaf"))}
BLOOMX = {"snowdrop": dict(kind="bulbs_snowdrop", fc=pal("snowdrop", "flower", "white"), cen=pal("snowdrop", "centre", "deep")),
          "daffodil": dict(kind="bulbs_daffodil", fc=pal("daffodil", "flower", "bulbs_yellow"), cen=pal("daffodil", "centre", "bulbs_gold")),
          "tulip": dict(kind="bulbs_tulip", fc=pal("tulip", "flower", "berry"), cen=pal("tulip", "centre", "dark")),
          "crocus": dict(kind="bulbs_crocus", fc=pal("crocus", "flower", "bulbs_crocus"), cen=pal("crocus", "centre", "carrot")),
          "bluebell": dict(kind="bulbs_bluebell", fc=pal("bluebell", "flower", "bulbs_bluebell"), cen=pal("bluebell", "centre", "white")),
          "grape-hyacinth": dict(kind="bulbs_muscari", fc=pal("grape-hyacinth", "flower", "bulbs_muscari"), cen=pal("grape-hyacinth", "centre", "white")),
          "puschkinia": dict(kind="bulbs_puschkinia", fc=pal("puschkinia", "flower", "white"), cen=pal("puschkinia", "centre", "bulbs_stripe")),
          "snake-s-head-fritillary": dict(kind="bulbs_fritillary", fc=pal("snake-s-head-fritillary", "flower", "bulbs_maroon")),
          "crown-imperial": dict(kind="bulbs_crown", fc=pal("crown-imperial", "flower", "rust"), cen=pal("crown-imperial", "centre", "white"))}
STAGE = {
    "snowdrop": {"bulb": snowdrop_bulb, "shoots": snowdrop_shoots, "flower": snowdrop_flower, "seedhead": snowdrop_seed, "dormant": snowdrop_dormant},
    "crown-imperial": {"bulb": crown_bulb, "shoots": crown_shoots, "flower": crown_flower, "seedhead": crown_seed, "dormant": crown_dormant},
    "snake-s-head-fritillary": {"bulb": frit_bulb, "shoots": frit_shoots, "flower": frit_flower, "seedhead": frit_seed, "dormant": frit_dormant},
    "puschkinia": {"bulb": pusch_bulb, "shoots": pusch_shoots, "flower": pusch_flower, "seedhead": pusch_seed, "dormant": pusch_dormant},
    "grape-hyacinth": {"bulb": muscari_bulb, "shoots": muscari_shoots, "flower": muscari_flower, "seedhead": muscari_seed, "dormant": muscari_dormant},
    "bluebell": {"bulb": bluebell_bulb, "shoots": bluebell_shoots, "flower": bluebell_flower, "seedhead": bluebell_seed, "dormant": bluebell_dormant},
    "crocus": {"bulb": ("Corm", crocus_corm), "shoots": crocus_shoots, "flower": crocus_flower, "seedhead": crocus_seed, "dormant": crocus_dormant},
    "tulip": {"bulb": tulip_bulb, "shoots": tulip_shoots, "flower": tulip_flower, "seedhead": tulip_seed, "dormant": tulip_dormant},
    "daffodil": {"bulb": daffodil_bulb, "shoots": daffodil_shoots, "flower": daffodil_flower, "seedhead": daffodil_seed, "dormant": daffodil_dormant},
}
