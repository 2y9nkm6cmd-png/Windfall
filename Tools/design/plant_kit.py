"""Windfall plant drawings: the drawing kit.

Every drawing is made on a 100 by 100 grid (0,0 is the top left, y grows
downwards) from a small set of parts: stems, leaves, petals, fruit, roots.
Colours are given by NAME and turned into real colours only when a file is
written, so one drawing gives a light-mode and a dark-mode picture.
"""
import math

LW = 1.15  # the usual line width, on the 100 grid

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
        s.items = []

    # ----- the two basic marks -----
    def shape(s, d, fill=None, lw=LW, la=0.85, col="line", fa=1):
        s.items.append(("path", d, fill, lw, la, col, fa)); return s

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

    def leaf(s, x, y, ang, L, b=0.28, fill="leaf", vein=False, lw=LW, skew=0.45, detail=True):
        """A simple pointed leaf starting at x,y and pointing along ang.
        b is how fat it is. A leaf that is big enough gets a shaded half,
        a midrib and side veins. detail=False leaves those off (petals)."""
        t = T(x, y, ang)
        s.shape(f"M{P(t(0))} Q{P(t(L * skew, L * b))} {P(t(L))} Q{P(t(L * skew, -L * b))} {P(t(0))} Z", fill, lw)
        if not detail or not fill:
            return s
        if L >= 8 and b >= 0.18:
            s.shape(f"M{P(t(0))} Q{P(t(L * skew, L * b))} {P(t(L))} Z", "shade", 0, fa=0.11)
        if vein or L >= 8:
            s.line(f"M{P(t(L * 0.06))} L{P(t(L * 0.84))}", 0.6, 0.42)
        if L >= 12 and b >= 0.3:
            for u in (0.24, 0.42, 0.6):
                w = b * L * 2 * (u + 0.13) * (1 - u - 0.13) * 0.8
                s.line(f"M{P(t(L * u))} L{P(t(L * (u + 0.13), w))} M{P(t(L * u))} L{P(t(L * (u + 0.13), -w))}", 0.5, 0.3)
        return s

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
        s.items.append(("dot", x, y, r, fill)); return s

    # ----- bigger parts built from the above -----
    def toothleaf(s, x, y, ang, L, W, teeth=11, fill="leaf", depth=0.07):
        t = T(x, y, ang); cx, cy = t(L / 2)
        s.polar(cx, cy, lambda th: 1 + depth * math.cos(teeth * th), L / 2, W / 2, ang, fill)
        s.line(f"M{P(t(L * 0.1))} L{P(t(L * 0.85))}", 0.6, 0.42)
        if L >= 11:
            for u in (0.25, 0.42, 0.59):
                w = W * 0.5 * math.sqrt(max(0, 1 - (2 * (u + 0.12) - 1) ** 2)) * 0.78
                s.line(f"M{P(t(L * u))} L{P(t(L * (u + 0.12), w))} M{P(t(L * u))} L{P(t(L * (u + 0.12), -w))}", 0.5, 0.3)
        return s

    def lobedleaf(s, x, y, ang, R, lobes=5, fill="leaf", cut=0.36):
        """A broad leaf with rounded lobes and a notch where the stalk joins."""
        t = T(x, y, ang); cx, cy = t(R * 0.8)
        fn = lambda th: (1 - cut) + cut * abs(math.cos(lobes * (th - math.pi) / 2)) ** 0.7
        s.polar(cx, cy, fn, R, R * 0.95, ang, fill)
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

    def compound(s, x, y, ang, L, pairs=2, b=0.42, fill="leaf", end=True, bend=0.1, size=0.4, spread=62):
        """A leaf made of a few larger leaflets: tomato, bean, rose."""
        t = T(x, y, ang)
        q = s.stem(t(0), t(L * 0.5, L * bend), t(L * (0.78 if end else 0.9)), 0.9)
        for i in range(pairs):
            u = 0.45 + 0.5 * i / max(1, pairs - 1) if pairs > 1 else 0.9
            px, py = q.pt(u); a = q.ang(u); l = L * size
            s.leaf(px, py, a - spread, l, b, fill, vein=True, lw=0.9)
            s.leaf(px, py, a + spread, l, b, fill, vein=True, lw=0.9)
        if end:
            ex, ey = q.pt(1); s.leaf(ex, ey, q.ang(1), L * size * 1.1, b, fill, vein=True, lw=0.9)
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
    def body(s, mode=0):
        out = []
        for it in s.items:
            if it[0] == "path":
                _, d, fill, lw, la, col, fa = it
                fl = COLOURS[fill][mode] if fill else "none"
                if fa != 1:
                    fl += f'" fill-opacity="{fa}'
                st = (f' stroke="{COLOURS[col][mode]}" stroke-width="{f(lw)}" stroke-opacity="{la}"' if lw else ' stroke="none"')
                out.append(f'<path d="{d}" fill="{fl}"{st}/>')
            else:
                _, x, y, r, fill = it
                out.append(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{COLOURS[fill][mode]}"/>')
        return "\n".join(out)

    def svg(s, mode=0, size=100):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 100 100">\n'
                f'<g stroke-linecap="round" stroke-linejoin="round">\n{s.body(mode)}\n</g>\n</svg>\n')
