"""Windfall wildlife drawings: the drawing kit.

It stands on the plant drawings' kit (plant_kit.py): the same 100 by 100
grid, the same named colours, the same way of writing a light and a dark
picture from one drawing. What it adds is a way of building an ANIMAL.

HOW AN ANIMAL IS BUILT
An animal is a few simple shapes stuck together: an oval for the body, a
circle for the head, a wedge for the tail. Drawn one on top of another,
each shape's outline would show inside the animal. So the shapes are first
joined into ONE outline (a "silhouette"), and patches of colour, such as a
robin's red breast, are cut to fit inside it. The joining and cutting is
done by a geometry library called shapely.

    pip install shapely        (the only thing this needs beyond Python)

Shapely is used only while drawing. What is written out is plain SVG paths,
like every other drawing in the app.
"""
import math
from shapely.geometry import Polygon
from shapely.geometry.polygon import orient
from shapely.affinity import translate
from shapely.ops import unary_union
import plant_kit as K
from plant_kit import Art, P, f, LW

# Colours the animals need that the plants did not. name: (light, dark).
K.COLOURS.update({
    "black":  ("#3B332E", "#2E2925"),   # a soft black: beetles, bees, crows
    "ink":    ("#1E1916", "#12100E"),   # eyes
    "brown":  ("#8A6444", "#8F6C4E"),
    "tan":    ("#C9A77C", "#A98B66"),
    "buff":   ("#E9D9B4", "#B7A57C"),
    "grey":   ("#B9BEB6", "#7F8980"),
    "slate":  ("#7C8B93", "#70828E"),
    "wing":   ("#E3EEE9", "#40564E"),   # a clear insect wing
    "water":  ("#BFD9E6", "#2F4E60"),
    "olive":  ("#A3A860", "#6F7440"),
    "skin":   ("#E7B5A0", "#B98A78"),   # worms, a mouse's ear and tail
    "red":    ("#D8463A", "#DC6156"),
    "orange": ("#EE8A3C", "#E0893F"),
    "yellow": ("#F2C230", "#E9BC36"),
    "cream":  ("#FBF3DA", "#D9CFB0"),
    "green":  ("#7FB069", "#4E8050"),
    "steel":  ("#4F6D8F", "#5F81A8"),   # a swallow's back, a blue tit's cap
    "sky":      ("#B5D3F0", "#7FA6CF"),   # a holly blue: paler than a common blue
    "chestnut": ("#7B3F2E", "#93543F"),   # a stag beetle's wing cases, a false widow, a female blackbird
    "khaki":    ("#B4A268", "#8E8250"),   # a common frog: olive-brown, not green
    "navy":     ("#2F3F63", "#4A5F8C"),   # a male beautiful demoiselle's wings
})


# ----- points and turning -----

def turn(x, y, ang):
    """A function that places a point measured along a direction. ang is in
    degrees: 0 is right, 90 is down, -90 is up (y grows downwards)."""
    return K.T(x, y, ang)


def curve(pts, n=10, closed=False):
    """A smooth run of points through the ones given (each piece is a
    Catmull-Rom curve, which passes through every point it is given)."""
    p = list(pts); out = []
    if closed:
        q = [p[-1]] + p + [p[0], p[1]]; last = len(p)
    else:
        q = [p[0]] + p + [p[-1]]; last = len(p) - 1
    for i in range(last):
        p0, p1, p2, p3 = q[i], q[i + 1], q[i + 2], q[i + 3]
        for k in range(n):
            t = k / n; t2 = t * t; t3 = t2 * t
            out.append(tuple(0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                                    + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)))
    if not closed:
        out.append(tuple(p[-1]))
    return out


# ----- shapes -----

def ell(cx, cy, rx, ry, rot=0, n=56):
    """An oval. rot turns it (degrees, clockwise on the page)."""
    t = turn(cx, cy, rot)
    return Polygon([t(rx * math.cos(2 * math.pi * k / n), ry * math.sin(2 * math.pi * k / n)) for k in range(n)])


def blob(pts, n=10):
    """A closed smooth shape through the points given."""
    return Polygon(curve(pts, n, closed=True)).buffer(0)


def poly(*pts):
    return Polygon(pts).buffer(0)


def limb(pts, w0, w1=None, n=10, smooth=True):
    """A band along a line that can change width from w0 to w1: a leg, a
    tail, a worm. Its ends are round."""
    w1 = w0 if w1 is None else w1
    c = curve(pts, n) if smooth and len(pts) > 2 else list(pts)
    if len(c) == 2:
        c = [c[0], ((c[0][0] + c[1][0]) / 2, (c[0][1] + c[1][1]) / 2), c[1]]
    m = len(c) - 1; parts = []
    for i in range(m):
        wa = w0 + (w1 - w0) * i / m; wb = w0 + (w1 - w0) * (i + 1) / m
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        d = math.hypot(x1 - x0, y1 - y0) or 1e-6; nx, ny = -(y1 - y0) / d, (x1 - x0) / d
        parts.append(Polygon([(x0 + nx * wa / 2, y0 + ny * wa / 2), (x1 + nx * wb / 2, y1 + ny * wb / 2),
                              (x1 - nx * wb / 2, y1 - ny * wb / 2), (x0 - nx * wa / 2, y0 - ny * wa / 2)]).buffer(0))
        parts.append(ell(x1, y1, wb / 2, wb / 2, n=14))
    parts.append(ell(c[0][0], c[0][1], w0 / 2, w0 / 2, n=14))
    return unary_union(parts)


def mirror(g, cx=50):
    """The same shape flipped left to right about the line x = cx."""
    from shapely.affinity import scale
    return scale(g, xfact=-1, yfact=1, origin=(cx, 0))


def band(cx, cy, rx, ry, v1, v2, rot=0):
    """A stripe across an oval: from v1 to v2 down its length, where -1 is
    one end and 1 the other. Cut to the oval by `figure`."""
    t = turn(cx, cy, rot)
    return Polygon([t(-rx * 1.5, ry * v1), t(rx * 1.5, ry * v1), t(rx * 1.5, ry * v2), t(-rx * 1.5, ry * v2)])


def polys(g):
    if g is None or g.is_empty:
        return []
    return [p for p in getattr(g, "geoms", [g]) if p.geom_type == "Polygon" and p.area > 0.04]


def path(p):
    """The SVG path for a shape. A shape with a hole in it (a ring, such as
    the dark border of a butterfly's wing) is written as its outer edge
    followed by the hole's edge going round the other way, which is how
    SVG is told to leave the middle empty."""
    p = orient(p.simplify(0.06), 1.0)
    rings = [p.exterior] + [r for r in p.interiors if Polygon(r).area > 0.04]
    return " ".join("M" + " L".join(P(q) for q in list(r.coords)[:-1]) + " Z" for r in rings)


# ----- putting marks on the drawing -----

def paint(a, g, fill, lw=0, fa=1, col="line", la=0.85):
    for p in polys(g):
        a.shape(path(p), fill, lw, la, col, fa)


def figure(a, parts, base, patches=(), lw=LW, close=0.9, shade=True, light=(-1.5, -2.1), fa=1):
    """Draws one piece of an animal.
      parts    the shapes that are joined into its outline
      base     its main colour
      patches  (shape, colour) pairs, each cut to fit inside the outline
      close    how far to round the corners where two shapes meet
      shade    a soft darker edge away from the light, for roundness
    Returns the outline, in case more is to be cut to it."""
    sil = unary_union([p for p in parts if p is not None and not p.is_empty])
    if close:
        sil = sil.buffer(close).buffer(-close)
    paint(a, sil, base, fa=fa)
    for g, colour in patches:
        paint(a, g.intersection(sil), colour)
    if shade:
        paint(a, sil.difference(translate(sil, *light)), "shade", fa=0.13)
    if lw:
        paint(a, sil, None, lw)
    return sil


def stroke(a, pts, lw=1.0, la=0.85, col="line", smooth=True, n=8):
    c = curve(pts, n) if smooth and len(pts) > 2 else pts
    a.line("M" + " L".join(P(p) for p in c), lw, la, col)


def eye(a, x, y, r=1.2, shine=True):
    a.dot(x, y, r, "ink")
    if shine and r >= 0.9:
        a.dot(x - r * 0.32, y - r * 0.32, r * 0.3, "white")


def spots(a, sil, places, r, fill, fa=1):
    """Round spots, each cut to the outline it sits on."""
    for x, y in places:
        paint(a, ell(x, y, r, r, n=18).intersection(sil), fill, fa=fa)
