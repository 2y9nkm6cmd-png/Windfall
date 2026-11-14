"""Windfall fungus diagrams: the drawing kit.

Every diagram is drawn on a 100 by 100 grid (0,0 is the top left and y
grows downwards), in colour, in the manner of the plant drawings
(Tools/design or design/plant_kit.py): a dark green outline, flat fills,
a soft shaded side and a little ground or wood to stand on.

One file serves light and dark. The outline is #06472A, which the
repository's build_design_assets.py swaps for a pale green in dark mode.
Shading uses a brown that is NOT swapped, so shade stays shade.
"""
import math

LINE = "#06472A"     # outline: swapped for pale green in dark mode by the build script
SHADE = "#3A2A1E"    # shading, always used at low strength
LW = 1.5        # the usual outline, before BOLD
BOLD = 2.5      # every outline is drawn this many times heavier: the bold look of the flower shapes
TINT = 1.7      # the same for coloured detail lines

C = {
    "stem": "#F6EEDB", "cream": "#F3E7C9", "white": "#FFFDF6", "gill": "#EAD9B8", "gillpink": "#EDB9B4",
    "gillbrown": "#B88A5E", "gilldark": "#6A5148", "tan": "#D9A86C", "brown": "#A9713F", "chestnut": "#8A4F2B",
    "red": "#C9453C", "scarlet": "#DA3B2E", "orange": "#EC8B3A", "yolk": "#F2C445", "sulphur": "#EBD556",
    "honey": "#D9A545", "grey": "#B4B0A6", "slate": "#8794A0", "olive": "#A3A558", "pale_olive": "#D5D79A",
    "violet": "#A98FD0", "black": "#3B2F2B", "ink": "#2B2422", "soil": "#A9845F", "soildark": "#8B6A4A",
    "bark": "#B8936C", "barkdark": "#8E6E4E", "wood": "#E3C79A", "moss": "#8DB56B", "leaf": "#C4DC84",
    "pore": "#E9D36A", "paper": "#FBF8F1", "paperdark": "#1E1C1B", "pinkprint": "#E08E8A", "rust": "#A9602C",
    "amber": "#E9A93A", "apricot": "#F0CFA0", "buff": "#E6CFA0", "coral": "#F0DFA6", "deepred": "#8E2B22", "jelly": "#F0B429", "ear": "#A8674A", "purple": "#5B3F63", "flesh": "#FBF4E2",
}


def darker(colour, by=0.13):
    """The same colour, a tone deeper: what a shaded side is painted in."""
    h = C.get(colour, colour).lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    k = 1 - by * 1.25
    # Blue is taken down a little more than red, which keeps the tone warm.
    return "#%02X%02X%02X" % (round(r * k), round(g * (k - 0.01)), round(b * (k - 0.04)))


def f(n):
    s = f"{n:.1f}"
    return s[:-2] if s.endswith(".0") else s


def pts_d(pts, close=True):
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts) + (" Z" if close else "")


def smooth_d(pts, close=False):
    """A soft curve through points (quadratic through midpoints)."""
    if len(pts) < 3:
        return pts_d(pts, False)
    if close:
        p = pts + pts[:2]
        d = f"M{f((p[0][0] + p[1][0]) / 2)},{f((p[0][1] + p[1][1]) / 2)}"
        for i in range(1, len(pts) + 1):
            mx, my = (p[i][0] + p[i + 1][0]) / 2, (p[i][1] + p[i + 1][1]) / 2
            d += f" Q{f(p[i][0])},{f(p[i][1])} {f(mx)},{f(my)}"
        return d + " Z"
    d = f"M{f(pts[0][0])},{f(pts[0][1])}"
    for i in range(1, len(pts) - 1):
        mx, my = (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2
        d += f" Q{f(pts[i][0])},{f(pts[i][1])} {f(mx)},{f(my)}"
    return d + f" L{f(pts[-1][0])},{f(pts[-1][1])}"


def rot(pts, deg, cx, cy):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


def ellipse_pts(x, y, rx, ry, ang=0, n=36, a0=0, a1=360):
    out = []
    for k in range(n + 1):
        t = math.radians(a0 + (a1 - a0) * k / n)
        out.append((x + rx * math.cos(t), y + ry * math.sin(t)))
    return rot(out, ang, x, y) if ang else out


SHAPES = {
    "dome": lambda u: math.sqrt(max(0, 1 - u * u)),
    "bun": lambda u: max(0, 1 - abs(u) ** 2.8) ** 0.62,
    "flat": lambda u: max(0, 1 - abs(u) ** 3.6) ** 0.5,
    "bell": lambda u: max(0, 1 - abs(u) ** 1.5) ** 0.85,
    "cone": lambda u: max(0, 1 - abs(u) ** 1.15) ** 0.9,
}


class Art:
    def __init__(s):
        s.o = []
        s.last = None   # the colour of the last solid shape, so its shade can be a deeper tone of it

    # ----- basic marks -----
    def path(s, d, fill=None, stroke=LINE, sw=LW, so=1, fo=1):
        if fill and fo == 1 and fill != SHADE:
            s.last = fill
        a = f'<path d="{d}" fill="{C.get(fill, fill) if fill else "none"}"'
        if fill and fo != 1: a += f' fill-opacity="{fo}"'
        if stroke and sw:
            sw = max(sw * BOLD, 1.5) if stroke == LINE else sw * TINT
            a += f' stroke="{C.get(stroke, stroke)}" stroke-width="{f(sw)}"'
            if so != 1: a += f' stroke-opacity="{so}"'
        else:
            a += ' stroke="none"'
        s.o.append(a + "/>"); return s

    def poly(s, pts, fill=None, **kw):
        return s.path(pts_d(pts), fill, **kw)

    def blob(s, pts, fill=None, **kw):
        return s.path(smooth_d(pts, True), fill, **kw)

    def curve(s, pts, **kw):
        return s.path(smooth_d(pts), None, **kw)

    def line(s, x0, y0, x1, y1, **kw):
        return s.path(f"M{f(x0)},{f(y0)} L{f(x1)},{f(y1)}", None, **kw)

    def oval(s, x, y, rx, ry, fill=None, ang=0, **kw):
        return s.path(pts_d(ellipse_pts(x, y, rx, ry, ang)), fill, **kw)

    def dot(s, x, y, r, fill=LINE, fo=1):
        a = f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r * 1.35)}" fill="{C.get(fill, fill)}"'
        if fo != 1: a += f' fill-opacity="{fo}"'
        s.o.append(a + "/>"); return s

    def shade(s, pts, strength=0.16, of=None):
        """A shaded side, painted a deeper tone of the shape it lies on."""
        base = of or s.last
        if base is None:
            return s.path(pts_d(pts), SHADE, stroke=None, fo=min(0.42, strength * 1.75))
        keep = s.last
        s.o.append(f'<path d="{pts_d(pts)}" fill="{darker(base, 0.1 + strength * 0.45)}" stroke="none"/>')
        s.last = keep; return s

    def shine(s, pts, strength=0.55, sw=1.6):
        return s.path(smooth_d(pts), None, stroke="#FFFFFF", sw=sw * 1.15, so=min(0.85, strength + 0.2))

    def drop(s, x, y, r, fill="white", sw=1.0):
        d = (f"M{f(x)},{f(y - r * 1.9)} C{f(x - r * 0.3)},{f(y - r)} {f(x - r)},{f(y - r * 0.4)} {f(x - r)},{f(y)} "
             f"C{f(x - r)},{f(y + r * 1.3)} {f(x + r)},{f(y + r * 1.3)} {f(x + r)},{f(y)} "
             f"C{f(x + r)},{f(y - r * 0.4)} {f(x + r * 0.3)},{f(y - r)} {f(x)},{f(y - r * 1.9)} Z")
        return s.path(d, fill, sw=sw)

    # ----- where it stands -----
    def ground(s, y, x0=14, x1=86, grass=True, flecks=True):
        """Something to stand on: one low green mound."""
        m = (x0 + x1) / 2
        return s.path(f"M{f(x0)},{f(y + 4.5)} Q{f(x0 + 4)},{f(y - 1.5)} {f(m)},{f(y - 2.5)} Q{f(x1 - 4)},{f(y - 1.5)} {f(x1)},{f(y + 4.5)} "
                      f"Q{f(m)},{f(y + 8)} {f(x0)},{f(y + 4.5)} Z", "leaf")

    def soil_cut(s, y, x0=8, x1=92, depth=18):
        """The ground cut through, so what is below the surface can be seen."""
        s.path(f"M{f(x0)},{f(y)} L{f(x1)},{f(y)} L{f(x1)},{f(y + depth - 5)} Q{f(x1)},{f(y + depth)} {f(x1 - 5)},{f(y + depth)} "
               f"L{f(x0 + 5)},{f(y + depth)} Q{f(x0)},{f(y + depth)} {f(x0)},{f(y + depth - 5)} Z", "#D9BE9A", sw=0)
        s.path(f"M{f(x0)},{f(y)} L{f(x1)},{f(y)} L{f(x1)},{f(y + 4)} L{f(x0)},{f(y + 4)} Z", "leaf", sw=0)
        return s.line(x0, y, x1, y)

    def trunk(s, x0, x1, y0=4, y1=96):
        s.path(f"M{f(x0 + 4)},{f(y0)} L{f(x1)},{f(y0)} L{f(x1)},{f(y1)} L{f(x0 + 4)},{f(y1)} Q{f(x0)},{f(y1)} {f(x0)},{f(y1 - 4)} "
               f"L{f(x0)},{f(y0 + 4)} Q{f(x0)},{f(y0)} {f(x0 + 4)},{f(y0)} Z", "bark", sw=0)
        w = x1 - x0
        s.path(f"M{f(x0 + w * 0.55)},{f(y0)} L{f(x1)},{f(y0)} L{f(x1)},{f(y1)} L{f(x0 + w * 0.55)},{f(y1)} Z", SHADE, stroke=None, fo=0.14)
        for fx, a, b in [(0.3, 12, 34), (0.42, 50, 72), (0.26, 80, 92)]:
            s.line(x0 + w * fx, a, x0 + w * fx, b, stroke="barkdark", sw=1.5)
        return s.line(x1, y0, x1, y1)

    def log(s, y0, y1, x0=5, x1=95, end=True):
        r = (y1 - y0) / 2; cy = (y0 + y1) / 2
        s.path(f"M{f(x0 + r * 0.6)},{f(y0)} L{f(x1 - r * 0.6)},{f(y0)} Q{f(x1)},{f(cy)} {f(x1 - r * 0.6)},{f(y1)} "
               f"L{f(x0 + r * 0.6)},{f(y1)} Q{f(x0)},{f(cy)} {f(x0 + r * 0.6)},{f(y0)} Z", "bark")
        s.path(f"M{f(x0 + r * 0.7)},{f(cy + r * 0.25)} L{f(x1 - r)},{f(cy + r * 0.25)} L{f(x1 - r * 0.8)},{f(y1 - 1.6)} L{f(x0 + r * 0.8)},{f(y1 - 1.6)} Z", SHADE, stroke=None, fo=0.16)
        if end:
            s.oval(x1 - r * 0.7, cy, r * 0.42, r * 0.8, "wood", sw=1.0)
        for fx, w in [(0.16, 12), (0.5, 14)]:
            s.line(x0 + (x1 - x0) * fx, cy - r * 0.3, x0 + (x1 - x0) * fx + w, cy - r * 0.3, stroke="barkdark", sw=1.4)
        return s

    def twig(s, pts, w=4.5, fill="bark"):
        L, R = [], []
        for i, (x, y) in enumerate(pts):
            j = min(i + 1, len(pts) - 1); k = max(i - 1, 0)
            dx, dy = pts[j][0] - pts[k][0], pts[j][1] - pts[k][1]; n = math.hypot(dx, dy) or 1
            L.append((x - dy / n * w / 2, y + dx / n * w / 2)); R.append((x + dy / n * w / 2, y - dx / n * w / 2))
        return s.poly(L + R[::-1], fill, sw=1.4)

    # ----- a mushroom, part by part -----
    def stem(s, top, base, w_top, w_bot, bend=0.0, fill="stem", bulb=0.0, shade=True, sw=LW):
        """A stem from top to base. Returns a function giving its centre and half-width at any height (0 top, 1 base)."""
        (x0, y0), (x1, y1) = top, base
        cx = (x0 + x1) / 2 + bend
        def at(t):
            u = 1 - t
            x = u * u * x0 + 2 * u * t * cx + t * t * x1
            y = y0 + (y1 - y0) * t
            w = (w_top + (w_bot - w_top) * t) / 2
            if bulb:
                w += bulb * math.exp(-((t - 0.9) / 0.13) ** 2)
            return x, y, w
        n = 22
        L = [(at(i / n)[0] - at(i / n)[2], at(i / n)[1]) for i in range(n + 1)]
        R = [(at(i / n)[0] + at(i / n)[2], at(i / n)[1]) for i in range(n + 1)]
        foot = [(x1 + (w_bot / 2 + bulb * 0.6) * math.cos(math.radians(a)), y1 + 1.6 * math.sin(math.radians(a))) for a in range(0, 181, 30)]
        s.poly(L + foot[::-1] + R[::-1], fill, sw=sw)
        if shade:
            s.shade([(at(i / n)[0] + at(i / n)[2] * 0.35, at(i / n)[1]) for i in range(n + 1)] + R[::-1], 0.13)
        return at

    def cap(s, cx, yb, w, h, shape="dome", fill="tan", rim=1.6, umbo=0.0, tilt=0, shade=True, shine=True, sw=LW):
        """A cap seen from the side. Returns a function placing a point on it: across (-1 to 1), up (0 to 1)."""
        fn = SHAPES[shape]
        def top(u):
            v = fn(u) + umbo * math.exp(-(u / 0.2) ** 2)
            return cx + u * w, yb - h * v
        n = 44
        us = [-1 + 2 * i / n for i in range(n + 1)]
        outer = [top(u) for u in us]
        lower = [(cx + u * w, yb + rim * (1 - u * u)) for u in us]
        pts = outer + lower[::-1]
        if tilt: pts = rot(pts, tilt, cx, yb)
        s.poly(pts, fill, sw=sw)
        def on(u, v=1.0):
            x, y = cx + u * w, yb - (yb - top(u)[1]) * v
            return rot([(x, y)], tilt, cx, yb)[0] if tilt else (x, y)
        if shade:
            a = [on(u, 1) for u in us if u >= 0.1]
            b = [on(0.1 + (u - 0.1) * 0.8, 0.86) for u in us if u >= 0.1]
            lo = [rot([(cx + u * w, yb + rim * (1 - u * u))], tilt, cx, yb)[0] for u in us if u >= 0.55]
            s.shade(a + lo[::-1] + b[::-1], 0.15)
        if shine:
            s.shine([on(-0.7, 0.5), on(-0.56, 0.74), on(-0.34, 0.86)], 0.45, 2.0)
        return on

    def underside(s, cx, yb, w, depth, fill="gill", kind="gills", n=9, stem_w=5, line=LINE, thick=0.7, tilt=0):
        """What shows beneath the cap edge: gills, pores or spines."""
        us = [-1 + 2 * i / 40 for i in range(41)]
        upper = [(cx + u * w, yb) for u in us]
        lower = [(cx + u * w, yb + depth * (1 - u * u)) for u in us]
        tr = (lambda p: rot(p, tilt, cx, yb)) if tilt else (lambda p: p)
        s.poly(tr(upper + lower[::-1]), fill, sw=1.5)
        n = min(n, 5 if w > 20 else 3); line = LINE if line == SHADE else line
        if kind == "gills":
            for side in (-1, 1):
                for k in range(n):
                    u = side * (0.12 + 0.86 * (k + 0.5) / n)
                    x1, y1 = cx + u * w, yb + depth * (1 - u * u) - 0.3
                    x0, y0 = cx + side * (stem_w * 0.5 + abs(u) * w * 0.16), yb + depth * 0.42 * (1 - u * u)
                    p = tr([(x0, y0), (x1, y1)])
                    s.line(p[0][0], p[0][1], p[1][0] * 0.96 + cx * 0.04, p[1][1] - 0.5, stroke=line, sw=max(thick, 0.75))
        elif kind == "pores":
            for yy, m in ((0.3, 7), (0.66, 5)):
                for k in range(m):
                    u = ((k + 0.5) / m * 2 - 1) * math.sqrt(max(0, 1 - yy)) * 0.9
                    if abs(u * w) > stem_w * 0.5 + 2.5 or yy < 0.2:
                        p = tr([(cx + u * w, yb + depth * yy)])[0]
                        s.dot(p[0], p[1], 0.9, line)
        return s

    def ring(s, at, t=0.3, flare=2.4, drop=6, fill="cream", wavy=True):
        x, y, w = at(t)
        top = [(x - w, y), (x + w, y)]
        bot = []
        for k in range(9):
            u = k / 8
            bx = x - w * flare + 2 * w * flare * u
            by = y + drop * (0.72 + 0.28 * math.sin(u * math.pi)) + (0.7 * math.sin(u * math.pi * 3) if wavy else 0)
            bot.append((bx, by))
        s.poly(top + bot[::-1], fill, sw=1.4)
        s.shade([(x + w * 0.2, y), (x + w, y)] + bot[::-1][:4] + [(x + w * 0.5, y + drop * 0.7)], 0.12)
        return s

    def volva(s, x, y, w, h, fill="white"):
        """A bag round the stem base: an open sack with a torn, lobed edge."""
        pts = [(x - w * 0.72, y - h * 0.9), (x - w * 0.45, y - h * 0.7), (x - w * 0.2, y - h * 0.94), (x, y - h * 0.68),
               (x + w * 0.2, y - h * 0.94), (x + w * 0.45, y - h * 0.7), (x + w * 0.72, y - h * 0.9), (x + w * 0.82, y - h * 0.45),
               (x + w * 0.6, y), (x, y + h * 0.12), (x - w * 0.6, y), (x - w * 0.82, y - h * 0.45)]
        s.blob(pts, fill, sw=1.5)
        s.shade([(x + w * 0.3, y - h * 0.86), (x + w * 0.42, y - h * 0.8), (x + w * 0.64, y - h * 0.98), (x + w * 0.74, y - h * 0.55),
                 (x + w * 0.62, y - h * 0.12), (x + w * 0.3, y + h * 0.1), (x + w * 0.36, y - h * 0.4)], 0.14)
        return s

    def tube(s, pts, w, fill="stem", edge=1.25):
        edge = edge * 1.25 if edge else 0
        """A rounded tube along a line: a thin stem, a coral branch, a strand."""
        d = smooth_d(pts)
        if edge:
            s.o.append(f'<path d="{d}" fill="none" stroke="{LINE}" stroke-width="{f(w + 2 * edge * BOLD)}"/>')
        s.o.append(f'<path d="{d}" fill="none" stroke="{C.get(fill, fill)}" stroke-width="{f(w)}"/>'); return s

    def tubes(s, specs, fill="stem", edge=1.25):
        """Several tubes that join: every outline first, then every fill, so they read as one shape."""
        for pts, w in specs:
            s.o.append(f'<path d="{smooth_d(pts)}" fill="none" stroke="{LINE}" stroke-width="{f(w + 2 * edge * 1.25 * BOLD)}"/>')
        for pts, w in specs:
            s.o.append(f'<path d="{smooth_d(pts)}" fill="none" stroke="{C.get(fill, fill)}" stroke-width="{f(w)}"/>')
        return s

    def body(s):
        return "\n".join(s.o)

    def svg(s, size=100):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="5 5 90 90">\n'
                f'<g stroke-linecap="round" stroke-linejoin="round">\n{s.body()}\n</g>\n</svg>\n')
