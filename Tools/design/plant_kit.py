"""Windfall plant drawings: the drawing kit.

Every drawing is made on a 100 by 100 grid (0,0 is the top left, y grows
downwards) from a small set of parts: stems, leaves, petals, fruit, roots.
Colours are given by NAME and turned into real colours only when a file is
written, so one drawing gives a light-mode and a dark-mode picture.
"""
import math, re
from contextlib import contextmanager

LW = 1.15  # the usual line width, on the 100 grid

# The layers of a plant, from the back to the front. Inside a "group" (see
# Art.group) everything on a lower layer is drawn before everything on a
# higher one, whatever order the code asked for it in.
STEM, LEAF, BLOOM = 0, 1, 2

# The colour of the card a drawing sits on (light, dark). See "line_colours" below.
CARD = ("#FFFCF6", "#142414")


# name: (light, dark). The first block is from Design/colours.json and doc 49.
COLOURS = {
    "line":     ("#06472A", "#BCEC8C"),
    "leaf":     ("#C4DC84", "#35522A"),
    "deep":     ("#8DB56B", "#2C5A34"),
    "sage":     ("#B7CBA2", "#4C6A4C"),
    "white":    ("#FFFDF8", "#F1EADB"),
    "pink":     ("#F4C3CC", "#B98592"),
    "sun":      ("#F2B632", "#F2B632"),
    "primrose": ("#F7E58A", "#E3CF6E"),
    "berry":    ("#C9453C", "#D9655A"),
    "unripe":   ("#B4D182", "#5E7F3F"),
    "rust":     ("#C4682F", "#B8683A"),
    "amber":    ("#E9A93A", "#C98500"),
    # new for the plant drawings
    "pale":     ("#E4EDBE", "#4F6E3C"),   # seed leaves, blanched stems
    "carrot":   ("#EE8A3C", "#E0893F"),
    "soil":     ("#A9845F", "#8B6F54"),
    "seed":     ("#DDBE8E", "#B7986A"),
    "bark":     ("#B8936C", "#7C6149"),
    "straw":    ("#E6D39C", "#A39058"),
    "dark":     ("#4B3A33", "#6E5A4E"),   # black seeds, dry bean pods
    "lilac":    ("#C3B2E8", "#8E7FC8"),
    "marrow":   ("#5E9150", "#3F7242"),   # courgette skin
    "blue":     ("#8FB4E0", "#5E88B8"),
    "plum":     ("#7A5A8C", "#8E74A8"),
    "beet":     ("#9C2F52", "#B5506C"),
    "pear":     ("#DDD67A", "#A9A650"),
    "shade":    ("#06472A", "#020A06"),   # laid thinly over a colour to darken one side
}


def f(n):
    s = f"{n:.1f}"
    return s[:-2] if s.endswith(".0") else s


def T(x, y, ang):
    """Returns a function that turns a point measured ALONG a direction
    (ang, in degrees: 0 is right, -90 is straight up) into a grid point."""
    a = math.radians(ang); c, s = math.cos(a), math.sin(a)
    return lambda px, py=0: (x + px * c - py * s, y + px * s + py * c)


def P(pt):
    return f"{f(pt[0])},{f(pt[1])}"


def mix(top, under, a):
    """The solid colour you SEE when colour `top` is painted over colour
    `under` at strength a (1 = fully solid, 0 = invisible)."""
    tc = [int(top[i:i + 2], 16) for i in (1, 3, 5)]; uc = [int(under[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x * a + y * (1 - a)):02X}" for x, y in zip(tc, uc))


def flat(d):
    """Turns a path (the "M10,20 Q30,40 50,60 Z" text) into plain lists of
    points, one list for each separate stroke in it. Curves become short
    straight pieces. Only used to find out what a faint line lies on."""
    tok = re.findall(r"[MLQCTZmlqctz]|-?\d*\.?\d+", d)
    subs, cur, i, cmd, pos, last_c = [], [], 0, None, (0.0, 0.0), None
    need = {"M": 2, "L": 2, "T": 2, "Q": 4, "C": 6}
    while i < len(tok):
        if tok[i].isalpha():
            cmd = tok[i]; i += 1
            if cmd in "Zz":
                if cur: cur.append(cur[0]); pos = cur[0]
                continue
        n = need[cmd.upper()]; v = [float(x) for x in tok[i:i + n]]; i += n
        if cmd.islower():
            v = [x + pos[k % 2] for k, x in enumerate(v)]
        pts = [(v[k], v[k + 1]) for k in range(0, n, 2)]; up = cmd.upper()
        if up == "M":
            if cur: subs.append(cur)
            cur = [pts[0]]; cmd = "L" if cmd == "M" else "l"
        elif up == "L":
            cur.append(pts[0])
        else:
            if up == "T":   # a curve that carries on smoothly from the one before
                c = (2 * pos[0] - last_c[0], 2 * pos[1] - last_c[1]) if last_c else pos
                pts = [c, pts[0]]
            for k in range(1, 9):
                u = k / 8; w = 1 - u
                if len(pts) == 2:
                    cur.append((w * w * pos[0] + 2 * w * u * pts[0][0] + u * u * pts[1][0],
                                w * w * pos[1] + 2 * w * u * pts[0][1] + u * u * pts[1][1]))
                else:
                    cur.append((w ** 3 * pos[0] + 3 * w * w * u * pts[0][0] + 3 * w * u * u * pts[1][0] + u ** 3 * pts[2][0],
                                w ** 3 * pos[1] + 3 * w * w * u * pts[0][1] + 3 * w * u * u * pts[1][1] + u ** 3 * pts[2][1]))
        last_c = pts[-2] if up in "QT" else None
        pos = pts[-1]
    if cur: subs.append(cur)
    return subs


def inside(pt, poly):
    """Is the point inside the closed outline? (Counts how many edges a line
    drawn out to the right of the point crosses: an odd number means inside.)"""
    x, y = pt; hit = False
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
            hit = not hit
    return hit


def halfway(pts):
    """The point half-way along a run of points, measured along the line."""
    if len(pts) < 2:
        return pts[0]
    seg = [math.dist(a, b) for a, b in zip(pts, pts[1:])]; half = sum(seg) / 2
    for (a, b), l in zip(zip(pts, pts[1:]), seg):
        if half <= l and l > 0:
            u = half / l; return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u)
        half -= l
    return pts[-1]


class Quad:
    """A curve from p0 to p1, pulled towards c. Used for stems, so that
    leaves and flowers can be placed part-way along it."""
    def __init__(s, p0, c, p1):
        s.p0, s.c, s.p1 = p0, c, p1

    def pt(s, t):
        u = 1 - t
        return (u * u * s.p0[0] + 2 * u * t * s.c[0] + t * t * s.p1[0],
                u * u * s.p0[1] + 2 * u * t * s.c[1] + t * t * s.p1[1])

    def ang(s, t):
        dx = 2 * (1 - t) * (s.c[0] - s.p0[0]) + 2 * t * (s.p1[0] - s.c[0])
        dy = 2 * (1 - t) * (s.c[1] - s.p0[1]) + 2 * t * (s.p1[1] - s.c[1])
        return math.degrees(math.atan2(dy, dx))

    def d(s):
        return f"M{P(s.p0)} Q{P(s.c)} {P(s.p1)}"


class Art:
    def __init__(s):
        s.items = []      # every mark, in the order it will be drawn (back first)
        s.lay = []        # the layer each mark is on, in step with items
        s.layer = STEM    # the layer new marks are put on

    # ----- layers: what is drawn in front of what -----
    @contextmanager
    def on(s, layer):
        """`with a.on(LEAF):` puts everything drawn inside it on that layer."""
        old = s.layer; s.layer = layer
        try:
            yield
        finally:
            s.layer = old

    @contextmanager
    def group(s):
        """`with a.group():` draws a whole plant. When it ends, the marks made
        inside it are put in order of layer: stems at the back, then leaves,
        then flowers and fruit. Marks on the SAME layer keep the order they
        were made in. Marks made outside the group are not moved."""
        start = len(s.items)
        yield
        order = sorted(range(start, len(s.items)), key=lambda i: s.lay[i])
        s.items[start:] = [s.items[i] for i in order]; s.lay[start:] = [s.lay[i] for i in order]

    def _add(s, item):
        s.items.append(item); s.lay.append(s.layer)

    # ----- the two basic marks -----
    def shape(s, d, fill=None, lw=LW, la=0.85, col="line", fa=1):
        s._add(("path", d, fill, lw, la, col, fa)); return s

    def line(s, d, lw=LW, la=0.85, col="line"):
        return s.shape(d, None, lw, la, col)

    # ----- parts -----
    def stem(s, p0, c, p1, lw=1.3, col="line", la=0.85):
        q = Quad(p0, c, p1); s.line(q.d(), lw, la, col); return q

    def ribbon(s, p0, c, p1, w0, w1, fill="leaf", lw=LW, n=18, round_tip=False):
        """A band that follows a curve and changes width: a strap leaf,
        a thick stem, a trunk, a pod."""
        q = Quad(p0, c, p1); L, R = [], []
        for i in range(n + 1):
            t = i / n; x, y = q.pt(t); a = math.radians(q.ang(t) + 90)
            w = (w0 + (w1 - w0) * t) / 2
            if round_tip:
                w *= math.sqrt(max(0.0, 1 - max(0, (t - 0.8) / 0.2) ** 2))
            L.append((x + w * math.cos(a), y + w * math.sin(a)))
            R.append((x - w * math.cos(a), y - w * math.sin(a)))
        pts = L + R[::-1]
        s.shape("M" + " L".join(P(p) for p in pts) + " Z", fill, lw)
        if fill and max(w0, w1) >= 2.4:   # a soft line down one side, to give it some roundness
            m = [((l[0] * 0.38 + r[0] * 0.62), (l[1] * 0.38 + r[1] * 0.62)) for l, r in zip(L, R)]
            s.shape("M" + " L".join(P(p) for p in R + m[::-1]) + " Z", "shade", 0, fa=0.12)
        return q

    def leaf(s, x, y, ang, L, b=0.28, fill="leaf", vein=False, lw=LW, skew=0.45, detail=True, edge=None):
        """A simple pointed leaf starting at x,y and pointing along ang.
        b is how fat it is. A leaf that is big enough gets a shaded half,
        a midrib and side veins. detail=False leaves those off (petals).
        edge gives it a toothed margin: "saw" for sharp teeth that point to
        the tip (raspberry, apple, mint), "scallop" for rounded ones
        (foxglove, lemon balm). A leaf too small to show teeth stays smooth."""
        t = T(x, y, ang)
        top = bot = None
        if edge and fill and L >= 4.5 and b >= 0.26:
            top, bot = s._toothed(L, b, skew, edge)
            s.shape("M" + " L".join(P(t(*p)) for p in top + bot[::-1]) + " Z", fill, lw)
        else:
            s.shape(f"M{P(t(0))} Q{P(t(L * skew, L * b))} {P(t(L))} Q{P(t(L * skew, -L * b))} {P(t(0))} Z", fill, lw)
        if not detail or not fill:
            return s
        if L >= 8 and b >= 0.18:
            if top:
                s.shape("M" + " L".join(P(t(*p)) for p in top) + " Z", "shade", 0, fa=0.11)
            else:
                s.shape(f"M{P(t(0))} Q{P(t(L * skew, L * b))} {P(t(L))} Z", "shade", 0, fa=0.11)
        if vein or L >= 8:
            s.line(f"M{P(t(L * 0.06))} L{P(t(L * 0.84))}", 0.6, 0.42)
        if L >= 12 and b >= 0.3:
            for u in (0.24, 0.42, 0.6):
                w = b * L * 2 * (u + 0.13) * (1 - u - 0.13) * 0.8
                s.line(f"M{P(t(L * u))} L{P(t(L * (u + 0.13), w))} M{P(t(L * u))} L{P(t(L * (u + 0.13), -w))}", 0.5, 0.3)
        return s

    @staticmethod
    def _toothed(L, b, skew, edge):
        """The two edges of a toothed leaf as points, measured along the
        leaf: (distance from the base, distance out from the midrib).
        The teeth stand a little outside the smooth leaf and the nicks
        between them go a little inside it, so the leaf keeps its size."""
        n = max(4, min(9, round(L / 2.0)))            # teeth down each side
        deep = 0.24                                   # nick to tooth tip, as a share of the half width there
        steps = [(0.0, 1.0), (0.72, 0.0), (1.0, 1.0)] if edge != "scallop" else [(0.0, 1.0), (0.2, 0.35), (0.5, 0.0), (0.8, 0.35), (1.0, 1.0)]

        def pt(u, cutin, side):
            x = 2 * u * (1 - u) * L * skew + u * u * L; y = 2 * u * (1 - u) * L * b
            fade = min(1.0, u / 0.1, (1 - u) / 0.06)   # no teeth right at the stalk or the very tip
            return (x, side * y * (1 + deep * (0.4 - cutin) * max(0.0, fade)))

        out = []
        for side in (1, -1):
            pts = [(0.0, 0.0)]
            for k in range(n):
                u0 = 0.04 + 0.94 * k / n; du = 0.94 / n
                for j, (v, cutin) in enumerate(steps):
                    if k and j == 0:
                        continue
                    pts.append(pt(u0 + du * v, cutin, side))
            pts.append((L, 0.0)); out.append(pts)
        return out[0], out[1]

    def oval(s, x, y, rx, ry, rot=0, fill=None, lw=LW, col="line", la=0.85):
        return s.polar(x, y, lambda th: 1, rx, ry, rot, fill, lw, steps=40, col=col, la=la)

    def polar(s, x, y, fn, rx, ry, rot=0, fill=None, lw=LW, steps=90, col="line", la=0.85, shade=True):
        """A closed outline. fn(angle) says how far out the edge is at each
        angle, as a share of rx and ry. Gives lobed and toothed leaves."""
        t = T(x, y, rot); pts = []
        for k in range(steps):
            th = 2 * math.pi * k / steps; r = fn(th)
            pts.append(t(rx * r * math.cos(th), ry * r * math.sin(th)))
        s.shape("M" + " L".join(P(p) for p in pts) + " Z", fill, lw, la, col)
        if fill and shade and min(rx, ry) >= 2.2:
            c = t(0, 0); a0, a1 = -int(steps * 0.1), int(steps * 0.42); outer, inner = [], []
            for j in range(a0, a1 + 1):
                px, py = pts[j % steps]; k = 1 - 0.34 * math.sin(math.pi * (j - a0) / (a1 - a0))
                outer.append((px, py)); inner.append((c[0] + (px - c[0]) * k, c[1] + (py - c[1]) * k))
            s.shape("M" + " L".join(P(p) for p in outer + inner[::-1]) + " Z", "shade", 0, fa=0.11)
        return s

    def dot(s, x, y, r, fill="line"):
        s._add(("dot", x, y, r, fill)); return s

    # ----- bigger parts built from the above -----
    def toothleaf(s, x, y, ang, L, W, teeth=11, fill="leaf", depth=0.07, edge=None):
        """A broad leaf with an uneven edge. With edge left out the edge is
        a soft wave (teeth waves round the whole leaf, depth deep): a
        lettuce, or the lobes of a radish leaf. edge="saw" gives sharp
        teeth pointing to the tip, edge="scallop" rounded ones: then teeth
        is how many down EACH side."""
        t = T(x, y, ang); cx, cy = t(L / 2)
        if edge:
            n = max(4, min(teeth, round(L / 2.0)))

            def fn(th):
                v = (math.pi - abs(math.atan2(math.sin(th), math.cos(th)))) / math.pi   # 0 at the stalk, 1 at the tip
                fade = min(1.0, v / 0.08, (1 - v) / 0.05)
                q = (v * n) % 1
                nick = (1 - q / 0.72 if q < 0.72 else (q - 0.72) / 0.28) if edge != "scallop" else abs(math.cos(math.pi * q)) ** 2.2
                return 1 + max(depth, 0.17) * (0.4 - nick) * max(0.0, fade)
            s.polar(cx, cy, fn, L / 2, W / 2, ang, fill, steps=max(90, n * 28))
        else:
            s.polar(cx, cy, lambda th: 1 + depth * math.cos(teeth * th), L / 2, W / 2, ang, fill)
        s.line(f"M{P(t(L * 0.1))} L{P(t(L * 0.85))}", 0.6, 0.42)
        if L >= 11:
            for u in (0.25, 0.42, 0.59):
                w = W * 0.5 * math.sqrt(max(0, 1 - (2 * (u + 0.12) - 1) ** 2)) * 0.78
                s.line(f"M{P(t(L * u))} L{P(t(L * (u + 0.12), w))} M{P(t(L * u))} L{P(t(L * (u + 0.12), -w))}", 0.5, 0.3)
        return s

    def lobedleaf(s, x, y, ang, R, lobes=5, fill="leaf", cut=0.36, teeth=0):
        """A broad leaf with rounded lobes and a notch where the stalk joins.
        teeth gives each lobe that many small sharp teeth (a currant, a
        vine, a courgette). A leaf too small to show them stays smooth."""
        t = T(x, y, ang); cx, cy = t(R * 0.8)
        teeth = teeth if R >= 4.5 else 0
        fn = lambda th: ((1 - cut) + cut * abs(math.cos(lobes * (th - math.pi) / 2)) ** 0.7) * (1 - 0.13 * (1 - ((th * lobes * teeth / (2 * math.pi)) % 1)) ** 1.4 if teeth else 1)
        s.polar(cx, cy, fn, R, R * 0.95, ang, fill, steps=max(90, lobes * teeth * 9))
        for k in range(lobes):
            a = ang + 180 + 360 * (k + 0.5) / lobes
            e = T(cx, cy, a)(R * 0.72)
            s.line(f"M{P(t(R * 0.22))} L{P(e)}", 0.6, 0.35)
        return s

    def fern(s, x, y, ang, L, bend=0.12, fill="leaf", pairs=6, spread=58, size=0.3):
        """A feathery leaf: a midrib with small leaflets down each side."""
        t = T(x, y, ang)
        q = s.stem(t(0), t(L * 0.5, L * bend), t(L), 0.9)
        for i in range(pairs):
            u = 0.3 + 0.62 * i / max(1, pairs - 1)
            px, py = q.pt(u); a = q.ang(u); l = L * size * (1.15 - u * 0.75)
            s.leaf(px, py, a - spread, l, 0.34, fill, lw=0.8)
            s.leaf(px, py, a + spread, l, 0.34, fill, lw=0.8)
        ex, ey = q.pt(1); s.leaf(ex, ey, q.ang(1), L * size * 0.5, 0.34, fill, lw=0.8)
        return q

    def compound(s, x, y, ang, L, pairs=2, b=0.42, fill="leaf", end=True, bend=0.1, size=0.4, spread=62, edge=None, endk=1.1):
        """A leaf made of a few larger leaflets: tomato, bean, rose.
        edge gives every leaflet a toothed margin (see leaf). endk is how
        big the end leaflet is beside the others."""
        t = T(x, y, ang)
        q = s.stem(t(0), t(L * 0.5, L * bend), t(L * (0.78 if end else 0.9)), 0.9)
        for i in range(pairs):
            u = 0.45 + 0.5 * i / max(1, pairs - 1) if pairs > 1 else 0.9
            px, py = q.pt(u); a = q.ang(u); l = L * size
            s.leaf(px, py, a - spread, l, b, fill, vein=True, lw=0.9, edge=edge)
            s.leaf(px, py, a + spread, l, b, fill, vein=True, lw=0.9, edge=edge)
        if end:
            ex, ey = q.pt(1); s.leaf(ex, ey, q.ang(1), L * size * endk, b, fill, vein=True, lw=0.9, edge=edge)
        return q

    def flower(s, x, y, r, n=5, fill="white", centre="sun", b=0.5, start=-90, cr=None, lw=0.9):
        """A flat flower seen face on: n petals round a centre."""
        for k in range(n):
            s.leaf(x, y, start + 360 * k / n, r, b, fill, lw=lw, skew=0.6, detail=False)
            if r >= 6:   # a faint line down each petal
                e0 = T(x, y, start + 360 * k / n)(r * 0.3); e1 = T(x, y, start + 360 * k / n)(r * 0.72)
                s.line(f"M{P(e0)} L{P(e1)}", 0.45, 0.3)
        if centre:
            c = cr or r * 0.3
            s.oval(x, y, c, c, 0, centre, lw=0.8)
            if c >= 1.8:   # a ring of stamens
                for k in range(6):
                    e = T(x, y, k * 60 + 15)(c * 0.55); s.dot(e[0], e[1], 0.42, "amber" if centre != "amber" else "rust")
        return s

    def umbel(s, x, y, ang, R, fill="white", spokes=7, fan=120, blob=None, curl=0.0):
        """A flat plate of tiny flowers on spokes, like carrot or hogweed.
        curl pulls the outer spokes inwards, as a carrot head does in seed."""
        blob = blob or R * 0.2
        with s.on(s.layer - 0.5):   # the spokes: half a layer back, so no head's spokes cross another head's flowers
            for k in range(spokes):
                u = k / (spokes - 1) - 0.5
                a = ang + u * fan * (1 - curl * 0.55)
                r = R * (1 - 0.18 * abs(u) * 2) * (1 - curl * 0.1)
                e = T(x, y, a)(r)
                m = T(x, y, ang + u * fan * (1 + curl * 0.5))(r * 0.55)
                s.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)}", 0.8)
        for k in range(spokes):
            u = k / (spokes - 1) - 0.5
            a = ang + u * fan * (1 - curl * 0.55)
            r = R * (1 - 0.18 * abs(u) * 2) * (1 - curl * 0.1)
            e = T(x, y, a)(r)
            s.oval(e[0], e[1], blob * 1.25, blob, a + 90, fill, lw=0.8)
        return s

    def ground(s, y, x0=7, x1=93, marks=True):
        """The soil surface: one soft line and a few flecks beneath it."""
        m = (x0 + x1) / 2
        if y > 42:
            s.shape(f"M{f(m - 19)},{f(y + 0.6)} Q{f(m + 3)},{f(y - 1.6)} {f(m + 25)},{f(y + 0.6)} Q{f(m + 3)},{f(y + 3.4)} {f(m - 19)},{f(y + 0.6)} Z", "shade", 0, fa=0.11)
        s.line(f"M{f(x0)},{f(y)} Q{f((x0 + m) / 2)},{f(y - 0.9)} {f(m)},{f(y)} T{f(x1)},{f(y)}", 1.1, 0.9, "soil")
        if marks:
            for dx, dy, w in [(-30, 4.5, 4), (-9, 7, 3), (16, 5, 4), (33, 8, 3)]:
                s.line(f"M{f(m + dx)},{f(y + dy)} L{f(m + dx + w)},{f(y + dy)}", 0.9, 0.55, "soil")
        # more to look at: small stones and a few crumbs, above and below the line
        for dx, dy, r in [(-36, 2.6, 1.5), (24, 2.4, 1.2), (-17, 3.2, 0.9)]:
            if y + dy < 97:
                s.shape(f"M{f(m + dx - r)},{f(y + dy)} Q{f(m + dx)},{f(y + dy - r * 1.3)} {f(m + dx + r)},{f(y + dy)} Q{f(m + dx)},{f(y + dy + r * 0.9)} {f(m + dx - r)},{f(y + dy)} Z", "soil", 0.6, 0.7, "soil", fa=0.35)
        for dx in (-41, -25, 21, 38):
            s.dot(m + dx, y - 1.1, 0.45, "soil")
        return s

    def roots(s, x, y, n=3, L=9, spread=50, lw=0.8, col="soil"):
        for k in range(n):
            u = (k / (n - 1) - 0.5) if n > 1 else 0
            a = 90 + u * spread
            e = T(x, y, a)(L * (1 - 0.25 * abs(u) * 2)); m = T(x, y, a + 14 * (1 if u >= 0 else -1))(L * 0.5)
            s.line(f"M{f(x)},{f(y)} Q{P(m)} {P(e)}", lw, 0.8, col)
            if L >= 9:   # a side root
                h = T(m[0], m[1], a + (50 if u >= 0 else -50))(L * 0.3)
                s.line(f"M{P(m)} L{P(h)}", lw * 0.7, 0.65, col)
        return s

    # ----- writing the picture out -----
    def line_colours(s, mode=0):
        """Works out one SOLID colour for every line.

        The drawing code still says how strong a line is (0.85 for an outline,
        0.3 for a faint vein). Drawn see-through at that strength, a line
        shows whatever is under it: two that cross make a darker spot, and a
        stem shows through the outline of the leaf in front of it. So each
        line is given the colour it WOULD have looked, painted at that
        strength over what lies beneath it, and is then drawn solid:
          - an outline (0.8 or stronger) is mixed with the card colour;
          - a fainter line is mixed with the colour it sits on, found by
            looking at the point half-way along it.
        Fills laid thinly on purpose (the shading) are left as they are: each
        lies only on its own shape, so nothing shows through it.
        Returns a list in step with items: the line colour, or None."""
        geo, out = [], []   # geo, for each mark with a fill: its box, an "is this point in it" test, its colour, its strength

        def under(i, pt):
            """The colour showing at pt before mark i is drawn."""
            c = CARD[mode]
            for g in geo[:i]:
                if g and g[0] <= pt[0] <= g[2] and g[1] <= pt[1] <= g[3] and g[4](pt):
                    c = mix(g[5], c, g[6])
            return c

        for i, it in enumerate(s.items):
            if it[0] == "dot":
                _, x, y, r, fill = it
                geo.append((x - r, y - r, x + r, y + r, lambda p, x=x, y=y, r=r: math.dist(p, (x, y)) <= r, COLOURS[fill][mode], 1))
                out.append(None); continue
            _, d, fill, lw, la, col, fa = it
            faint = lw and la < 0.8
            subs = flat(d) if (fill or faint) else []
            sc = None
            if lw:
                sc = COLOURS[col][mode]
                if faint:
                    base = under(i, halfway(subs[0]))
                    if fill:
                        base = mix(COLOURS[fill][mode], base, fa)
                    sc = mix(sc, base, la)
                elif la < 1:
                    sc = mix(sc, CARD[mode], la)
            if fill:
                poly = subs[0]; xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
                geo.append((min(xs), min(ys), max(xs), max(ys), lambda p, poly=poly: inside(p, poly), COLOURS[fill][mode], fa))
            else:
                geo.append(None)
            out.append(sc)
        return out

    def body(s, mode=0):
        out = []
        for it, sc in zip(s.items, s.line_colours(mode)):
            if it[0] == "path":
                _, d, fill, lw, la, col, fa = it
                fl = COLOURS[fill][mode] if fill else "none"
                if fa != 1:
                    fl += f'" fill-opacity="{fa}'
                st = f' stroke="{sc}" stroke-width="{f(lw)}"' if lw else ' stroke="none"'
                out.append(f'<path d="{d}" fill="{fl}"{st}/>')
            else:
                _, x, y, r, fill = it
                out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{COLOURS[fill][mode]}"/>')
        return "\n".join(out)

    def svg(s, mode=0, size=100):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 100 100">\n'
                f'<g stroke-linecap="round" stroke-linejoin="round">\n{s.body(mode)}\n</g>\n</svg>\n')
