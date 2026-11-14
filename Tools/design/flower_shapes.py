"""Draws Windfall's twenty flower shapes as outline icons. Second draft: more detail.

Each drawing follows the rules in the repository's Design/README.md:
a 24 by 24 grid, black only (so the app can paint it any colour),
round line ends.

Two weights of line are used:
  SW   the outline of the flower
  FINE veins, ribs, stamens, scales and other detail
"""
import math, os, re, sys

SW = 0.85
FINE = 0.5
K = 0.85      # every other line width in this file is multiplied by this
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"


def f(n):
    s = f"{n:.2f}".rstrip("0").rstrip(".")
    return "0" if s == "-0" else s


def _w(sw):
    """The stroke-width text for a line that is not the outline's weight."""
    if not sw:
        return ""
    return f' stroke-width="{f(sw if sw == FINE else sw * K)}"'


def P(d, sw=None):
    """One line of the drawing. sw is its width if not the outline's."""
    return f'<path d="{d}"{_w(sw)}/>'


def dot(x, y, r):
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="#000000" stroke="none"/>'


def ring(x, y, r, sw=None):
    extra = _w(sw)
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}"{extra}/>'


def oval(x, y, rx, ry, sw=None):
    extra = _w(sw)
    return f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx)}" ry="{f(ry)}"{extra}/>'


def _map(d, fn):
    """Runs every point of a path through fn. Understands M L C Q Z with
    absolute coordinates, which is all these drawings use."""
    toks = re.findall(r"[MLCQZ]|-?\d+\.?\d*", d)
    out, i = [], 0
    while i < len(toks):
        t = toks[i]
        if t in "MLCQZ":
            out.append(t); i += 1
        else:
            x, y = fn(float(t), float(toks[i + 1]))
            out.append(f"{f(x)},{f(y)}"); i += 2
    return " ".join(out)


def mirror(d, cx=12.0):
    """Copies a line to the other side of the drawing."""
    return _map(d, lambda x, y: (2 * cx - x, y))


def turn(d, deg, cx=12.0, cy=12.0):
    """Turns a line round the point (cx, cy)."""
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return _map(d, lambda x, y: (cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c))


def move(d, dx, dy):
    return _map(d, lambda x, y: (x + dx, y + dy))


def both(d, sw=None, cx=12.0):
    """A line and its mirror image."""
    return [P(d, sw), P(mirror(d, cx), sw)]


def polar(cx, cy, r, deg, squash=1.0):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a) * squash


def spoke(cx, cy, r0, r1, deg, sw=FINE, squash=1.0):
    x0, y0 = polar(cx, cy, r0, deg, squash); x1, y1 = polar(cx, cy, r1, deg, squash)
    return P(f"M{f(x0)},{f(y0)} L{f(x1)},{f(y1)}", sw)


def lobed(cx, cy, r_in, r_out, n, power=0.55, start=-90, squash=1.0, steps=120):
    """A closed outline with n rounded lobes and sharp notches between
    them, like petals seen face on. squash < 1 tilts it away from you."""
    pts = []
    for k in range(steps):
        th = 2 * math.pi * k / steps
        r = r_in + (r_out - r_in) * abs(math.cos(n * th / 2)) ** power
        a = th + math.radians(start)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a) * squash))
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts) + " Z"


def star(cx, cy, r_in, r_out, n, bulge=0.32, start=-90):
    """Pointed petals: straight-ish sides that swell outward a little."""
    d = ""
    for k in range(n):
        a = [math.radians(start + 360 * (k + j) / n) for j in (0, 0.5, 1)]
        tip = (cx + r_out * math.cos(a[0]), cy + r_out * math.sin(a[0]))
        notch = (cx + r_in * math.cos(a[1]), cy + r_in * math.sin(a[1]))
        nxt = (cx + r_out * math.cos(a[2]), cy + r_out * math.sin(a[2]))

        def ctrl(p, q):
            mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
            return (mx + (mx - cx) * bulge, my + (my - cy) * bulge)
        c1, c2 = ctrl(tip, notch), ctrl(notch, nxt)
        if k == 0:
            d += f"M{f(tip[0])},{f(tip[1])}"
        d += f" Q{f(c1[0])},{f(c1[1])} {f(notch[0])},{f(notch[1])} Q{f(c2[0])},{f(c2[1])} {f(nxt[0])},{f(nxt[1])}"
    return d + " Z"


S = {}  # file name -> list of pieces

# ---------------------------------------------------------------------------
# 1 Bilabiate: side view of a dead-nettle or sage. A toothed calyx, a tube,
#   a hooded upper lip sheltering the stamens, and a lobed lower lip to land on.
S["bilabiate"] = [
    # the corolla, from the top of the tube round both lips and back
    P("M8.3,12.5 C9.6,12.2 10.6,11.4 11.4,10 C12.6,7 15.4,4.4 18.4,4.8 C20.6,5.2 21.7,7.4 21,9.4 "
      "C20.8,10.2 20.2,10.9 19.4,11.1 C18.8,9.7 17,9.3 15.4,10.3 C14.4,10.9 13.8,11.9 13.6,12.9 "
      "C13.4,13.4 13.3,13.9 13.4,14.4 C15,14.2 17,14.8 18.4,16.2 C19.6,17.4 20,19 19.2,20.2 "
      "C18.4,21.2 17,21 16.5,19.8 C16,20.9 14.8,21 14,20 C13,18.8 12.2,17 11.6,15.6 "
      "C10.4,15.6 9.3,15.4 8.3,15.2"),
    # the calyx, with a tooth above and a tooth below
    P("M9.6,10.9 L7.7,12.2 C6.3,11.9 4.9,12.1 3.7,12.7 C3.1,13.4 3.1,14.3 3.7,15 "
      "C4.9,15.6 6.3,15.8 7.7,15.5 L9.6,16.8"),
    P("M3.3,13.85 L1.4,13.85"),
    P("M4.4,13.85 L7.6,13.85", FINE),
    # two stamens lying under the hood
    P("M12.6,11 C13.8,8.2 16.4,6.6 19.2,7.4", FINE), dot(19.5, 7.6, 0.42),
    P("M13.4,11.4 C14.6,9.4 16.4,8.2 18.4,8.5", FINE), dot(18.7, 8.7, 0.42),
    # spots on the lip: the nectar guide
    dot(15.4, 16.3, 0.32), dot(16.9, 17.5, 0.32), dot(15.5, 18.2, 0.32),
]

# 2 Funnel form: a tube that widens steadily to an open mouth. Bindweed-like.
_l = "M4.4,6.5 C6,11.2 10.4,13.4 10.9,19.2"
S["funnel-form"] = (
    [P(lobed(12, 6.3, 6.7, 7.8, 5, power=0.6, squash=0.36)),
     oval(12, 6.7, 2.3, 0.8, FINE)]
    + both(_l)
    # the bands down the middle of each petal
    + [P("M12,9.2 L12,18.6", FINE)] + both("M7.8,8.4 C8.8,12.2 11,14.6 11.4,18.8", FINE)
    # style and two stamens standing in the throat
    + [P("M12,6.8 L12,4.3", FINE), dot(12, 4, 0.42),
       P("M11,6.7 L10.5,4.9", FINE), dot(10.4, 4.6, 0.38),
       P("M13,6.7 L13.5,4.9", FINE), dot(13.6, 4.6, 0.38)]
    # two sepals clasping the base
    + both("M11,20.5 C9.3,19.7 8.3,17.9 8.6,15.9 C9.7,16.8 10.3,17.8 10.6,18.7", 0.8)
    + [P("M11,20.5 Q12,21.3 13,20.5"), P("M12,21 L12,23")]
)

# 3 Urceolate: a hanging urn, pinched in at the mouth. Heather or comfrey.
_l = "M9,5.7 C4.6,7.7 4.4,15 9.6,17.8 C9.7,18.6 9.5,19.2 9.2,19.7 L8.2,21"
S["urceolate"] = (
    [P("M12,0.9 L12,2.8"),
     # the calyx: three of its five teeth lying on the shoulder
     P("M9.6,3.6 L8.4,5.8 L10.6,4.7 L12,6.2 L13.4,4.7 L15.6,5.8 L14.4,3.6 Q12,2.3 9.6,3.6 Z", 0.8)]
    + both(_l)
    # the small turned-back teeth round the mouth
    + [P("M8.2,21 Q9.6,19.9 10.6,21.2 Q12,19.9 13.4,21.2 Q14.4,19.9 15.8,21")]
    # ribs, to show it is round
    + both("M10.5,6.9 C8.4,9.6 8.4,14.4 10.7,17.4", FINE)
    # the style poking out
    + [P("M12,17 L12,22.3", FINE), dot(12, 22.6, 0.42)]
)


# 4 Urceolate, umbellate: urns hanging from one point at the top of a stem.
def urn(cx, y0):
    left = (f"M{f(cx - 0.9)},{f(y0)} C{f(cx - 3.4)},{f(y0 + 1)} {f(cx - 3.4)},{f(y0 + 4.4)} "
            f"{f(cx - 1.5)},{f(y0 + 5.2)} L{f(cx - 2.3)},{f(y0 + 6.6)}")
    return (both(left, None, cx) + [
        P(f"M{f(cx - 0.9)},{f(y0)} L{f(cx + 0.9)},{f(y0)}"),
        P(f"M{f(cx - 2.3)},{f(y0 + 6.6)} Q{f(cx - 1.1)},{f(y0 + 5.6)} {f(cx)},{f(y0 + 6.8)} "
          f"Q{f(cx + 1.1)},{f(y0 + 5.6)} {f(cx + 2.3)},{f(y0 + 6.6)}"),
        P(f"M{f(cx)},{f(y0 + 0.7)} L{f(cx)},{f(y0 + 4.9)}", FINE),
        dot(cx, y0 + 7.6, 0.36)])


S["urceolate-umbellate"] = (
    [P("M12,23 L12,16.2"),
     P("M12,3.4 L12,7"),
     P("M12,3.4 C9.2,2 5.4,3.8 5,8"), P("M12,3.4 C14.8,2 18.6,3.8 19,8"),
     # the papery sheath the flowers burst from
     P("M12,3.4 L10.5,1.3", 0.8), P("M12,3.4 L13.6,1.5", 0.8)]
    + urn(12, 7) + urn(5, 8) + urn(19, 8)
)

# 5 Salverform: a narrow tube that opens suddenly into a flat face. A primrose.
_fy, _sq = 6.6, 0.42
S["salverform"] = (
    [P(lobed(12, _fy, 5.4, 9.2, 5, power=0.5, squash=_sq)),
     oval(12, _fy, 1.5, 0.63)]
    # a vein down the middle of each lobe
    + [spoke(12, _fy, 2.5, 6.9, -90 + 72 * k, FINE, _sq) for k in range(5)]
    + [P("M11.1,9.5 L11.1,15"), P("M12.9,9.5 L12.9,15"),
       # the calyx: a toothed sleeve round the foot of the tube
       P("M10,14 L10.7,15.4 L12,14.2 L13.3,15.4 L14,14", 0.8)]
    + both("M10,14 C9.7,16.6 10,19 11,20.6")
    + [P("M11,20.6 Q12,21.4 13,20.6"), P("M12,15.8 L12,20.2", FINE), P("M12,21.1 L12,23")]
)

# 6 Salverform, paniculate: many small four-lobed florets massed in a cone. Buddleia.
_rows = [(18.2, 5), (16.0, 4), (13.8, 3), (11.6, 2), (9.4, 1)]
_pan = [P("M12,23 L12,19.6")]
for y, n in _rows:
    for i in range(n):
        x = 12 + (i - (n - 1) / 2) * 2.55
        _pan += [P(lobed(x, y, 0.62, 1.12, 4, power=0.6, start=-45, steps=40), 0.7), dot(x, y, 0.26)]
_pan += [ring(12, 7.3, 0.75, 0.7), dot(12, 5.5, 0.6), dot(12, 3.9, 0.48), dot(12, 2.6, 0.36)]
_leaf = "M12,21.4 C10,19.9 7.2,20.3 5,22.3 C7.6,23.3 10.2,22.8 12,21.4"
_pan += both(_leaf, 0.8) + both("M11.2,21.7 C9.4,21.4 7.6,21.6 6,22.2", FINE)
S["salverform-paniculate"] = _pan

# 7 Ligulate, capitate: strap-shaped florets round a central disc. A daisy.
_ray = "M11.25,8.3 L10.6,3.3 L11.3,2.1 L12,2.8 L12.7,2.1 L13.4,3.3 L12.75,8.3"   # a strap with a notched tip
_dai = []
for k in range(11):
    _dai += [P(turn(_ray, 360 * k / 11), 0.9), P(turn("M12,4.4 L12,7.9", 360 * k / 11), FINE)]
_dai += [ring(12, 12, 2.9)]
# the disc florets
_dai += [dot(*polar(12, 12, 1.85, 40 * k), 0.3) for k in range(9)]
_dai += [dot(*polar(12, 12, 0.8, 90 * k + 20), 0.3) for k in range(4)]
S["ligulate-capitate"] = _dai

# 8 Tubular, capitate: a brush of tubed florets above a cup of overlapping scales. A knapweed.
_thi = []
for i in range(-4, 5):
    x0, y0 = 12 + i * 0.93, 11.5 - (0.3 if abs(i) < 4 else 0)
    x1, y1 = 12 + i * 2.25, 4.0 + abs(i) ** 1.5 * 0.42
    _thi.append(P(f"M{f(x0)},{f(y0)} L{f(x1)},{f(y1)}", 0.85))
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))          # each floret ends in a fork
    for da in (-32, 32):
        xe, ye = polar(x1, y1, 1.15, ang + da)
        _thi.append(P(f"M{f(x1)},{f(y1)} L{f(xe)},{f(ye)}", FINE))
_thi += [
    P("M8.2,11.8 C5.8,14.4 7.2,19.4 12,20.2 C16.8,19.4 18.2,14.4 15.8,11.8"),
    P("M8.2,11.8 Q12,13.1 15.8,11.8"),
    # three rows of scales
    P("M7.1,14 Q8.3,15.8 9.55,14 Q10.8,15.8 12,14 Q13.2,15.8 14.45,14 Q15.7,15.8 16.9,14", FINE),
    P("M7.4,16.4 Q8.9,18.2 10.45,16.4 Q12,18.2 13.55,16.4 Q15.1,18.2 16.6,16.4", FINE),
    P("M8.9,18.6 Q10.4,20 12,18.6 Q13.6,20 15.1,18.6", FINE),
    P("M12,20.2 L12,23"),
    P("M12,22.2 C13.6,20.9 15.8,20.9 17.4,21.9 C15.8,22.9 13.8,23 12,22.2", 0.8),
]
S["tubular-capitate"] = _thi

# 9 Rotate: flat and wheel-like. A cranesbill, with sepal tips showing between the petals.
_rot = [P(lobed(12, 12, 6.3, 10, 5, power=0.5))]
for k in range(5):
    a = -90 + 72 * k                      # the middle of a petal
    _rot += [spoke(12, 12, 3.0, 8.0, a), spoke(12, 12, 3.4, 7.0, a - 13), spoke(12, 12, 3.4, 7.0, a + 13)]
    n = a + 36                            # the notch between two petals
    bx0, by0 = polar(12, 12, 7.7, n - 6); ax, ay = polar(12, 12, 9.3, n); bx1, by1 = polar(12, 12, 7.7, n + 6)
    _rot.append(P(f"M{f(bx0)},{f(by0)} L{f(ax)},{f(ay)} L{f(bx1)},{f(by1)}", 0.7))
_rot += [dot(*polar(12, 12, 2.0, 36 * k), 0.3) for k in range(10)]
_rot += [ring(12, 12, 0.7, 0.7)]
S["rotate"] = _rot

# 10 Rotate, spicate: flat flowers up a tall spire. A mullein.
_sp = [P("M12,23 L12,3.3")]
for x, y, r, side in [(8.8, 17.3, 2.5, -1), (15.2, 14.3, 2.5, 1), (9, 11.3, 2.3, -1), (14.9, 8.5, 2.1, 1)]:
    _sp += [P(lobed(x, y, r * 0.62, r, 5, power=0.5), 0.9)]
    _sp += [dot(*polar(x, y, r * 0.36, 72 * k - 90), 0.24) for k in range(5)]
    # the little bract under each flower
    _sp += [P(f"M12,{f(y + r * 0.9)} L{f(12 + side * 2.2)},{f(y + r * 0.9 + 1.5)}", FINE)]
_sp += [ring(10.5, 6.3, 0.9, 0.8), P("M12,7.2 L11.1,6.9", FINE),
        ring(13.4, 4.9, 0.8, 0.8), P("M12,5.8 L12.8,5.4", FINE),
        dot(11.2, 3.8, 0.55), dot(12.7, 2.9, 0.5), dot(12, 1.9, 0.5)]
_leaf = "M12,22.9 C10,20.9 7,20.5 4,21.7 C6.4,23.3 9.6,23.5 12,22.9"
_sp += both(_leaf, 0.8) + both("M11,22.6 C9,21.8 7,21.6 5.2,21.9", FINE)
S["rotate-spicate"] = _sp

# 11 Crateriform: a shallow open bowl. A poppy or wild rose, from the side.
S["crateriform"] = (
    [P("M4,9.4 C4.4,15.6 8,19 12,19 C16,19 19.6,15.6 20,9.4"),
     # the front lip of the bowl, and the tops of the three petals behind
     P("M4,9.4 C6,12.3 18,12.3 20,9.4"),
     P("M4,9.4 C4,6.6 7,5 9.6,6.4 C11,5 13,5 14.4,6.4 C17,5 20,6.6 20,9.4")]
    # where one petal overlaps the next
    + both("M8.2,11.3 C8.6,14.4 10,17.2 11.6,18.8", FINE)
    # the boss of stamens
    + [P(f"M12,10.2 L{f(x)},{f(y)}", FINE) for x, y in [(9.6, 8.5), (10.7, 7.8), (12, 7.5), (13.3, 7.8), (14.4, 8.5)]]
    + [dot(x, y, 0.4) for x, y in [(9.4, 8.2), (10.6, 7.5), (12, 7.2), (13.4, 7.5), (14.6, 8.2)]]
    # two sepals turned back under the bowl
    + both("M11.3,19.1 C9.9,19.5 9.1,20.5 8.9,21.7 C10.1,21.3 11.1,20.5 11.7,19.4", 0.8)
    + [P("M12,19 L12,23")]
)

# 12 Stellate: a star of flat, pointed petals. Borage: narrow sepals show between
#    the petals, with a pale ring and a dark cone of anthers at the centre.
_st = [P(star(12, 12.3, 3.7, 10.3, 5, bulge=0.36))]
for k in range(5):
    a = -90 + 72 * k
    _st.append(spoke(12, 12.3, 3.6, 8.3, a))
    n = a + 36
    bx0, by0 = polar(12, 12.3, 4.7, n - 5.5); ax, ay = polar(12, 12.3, 8.9, n); bx1, by1 = polar(12, 12.3, 4.7, n + 5.5)
    _st.append(P(f"M{f(bx0)},{f(by0)} L{f(ax)},{f(ay)} L{f(bx1)},{f(by1)}", 0.7))
_st += [ring(12, 12.3, 2.4, 0.7), dot(12, 12.3, 1.2)]
S["stellate"] = _st

# 13 Cruciform: four petals in a cross. The cabbage family: narrow sepals between
#    the petals and stamens round the middle.
_pet = "M11.3,10.3 C7.9,6.6 8.3,2 12,2 C15.7,2 16.1,6.6 12.7,10.3"
_cr = []
for k in range(4):
    _cr += [P(turn(_pet, 90 * k)),
            P(turn("M12,9.4 L12,3.9", 90 * k), FINE),
            P(turn("M11.6,9.2 C10.9,7.6 10.4,6 10.4,4.6", 90 * k), FINE),
            P(turn("M12.4,9.2 C13.1,7.6 13.6,6 13.6,4.6", 90 * k), FINE),
            spoke(12, 12, 2.9, 5.2, 45 + 90 * k, 0.7),
            dot(*polar(12, 12, 2.0, 45 + 90 * k), 0.34)]
_cr += [ring(12, 12, 0.8, 0.7)]
S["cruciform"] = _cr

# 14 Cyathiform: a cup or bell with an open mouth. A harebell, nodding on a wiry stalk.
_l = "M10.8,5.7 C7.4,7.4 7.2,12 6.6,15.2 L4.4,18.6"
S["cyathiform"] = (
    [P("M5.2,1.5 C8.4,0.6 11.6,1.8 12,4.5", 0.8), P("M8,1.2 L7.2,2.9", FINE),
     P("M10.8,5.7 Q12,4 13.2,5.7"),
     # the calyx: narrow teeth standing off the top of the bell
     P("M10.9,5.5 L7.6,6.6", 0.7), P("M13.1,5.5 L16.4,6.6", 0.7), P("M12,5.9 L12,8.3", 0.7)]
    + both(_l)
    + [P("M4.4,18.6 Q7,18 8.7,16.6 Q10.4,19.4 12,20.8 Q13.6,19.4 15.3,16.6 Q17,18 19.6,18.6")]
    # the folds between the lobes
    + both("M11.2,7.4 C9.8,10.2 9.2,13.4 8.7,16.3", FINE)
    # the style, ending in a three-part stigma
    + [P("M12,12.6 L12,17.5", FINE), P("M12,17.5 L11.1,18.6", FINE), P("M12,17.5 L12.9,18.6", FINE), P("M12,17.5 L12,18.9", FINE)]
)

# 15 Galeate: the upper part drawn up into a helmet. A monkshood, from the side.
S["galeate"] = [
    # the helmet, with its beak pointing forward
    P("M8,12.6 C6.2,8.6 7.4,3.8 11.6,2.4 C15.4,1.4 18.6,4 18.8,7.8 C18.9,9.4 19.4,10.8 20.8,11.9 "
      "C18.8,12.2 17,11.7 15.6,10.8 C13,10.4 10.4,11.2 8,12.6 Z"),
    P("M9.8,10.6 C8.8,7.8 9.8,5 12.2,4", FINE), P("M12,10 C11.4,8 12,6.2 13.6,5.2", FINE),
    # the round side sepal, and the edge of its pair behind
    P("M8.8,13.3 C7.6,16.4 9.6,19.4 12.6,19.2 C15.6,19 17.4,16.2 16.4,13"),
    P("M17,13.9 C18.6,15 18.6,17.2 17.2,18.5", 0.8),
    P("M10.4,14.2 C10,16 10.8,17.6 12.2,18.2", FINE),
    # the tuft of stamens
    P("M13,12.6 L13.4,15.3", FINE), dot(13.5, 15.7, 0.4),
    P("M13.6,12.4 L14.8,14.6", FINE), dot(15, 14.9, 0.4),
    P("M12.4,12.8 L12.2,15", FINE), dot(12.1, 15.4, 0.4),
    # the two narrow lower sepals
    P("M10.2,18.9 C9.2,20.1 8.6,21.3 8.6,22.7 C10,22.1 11.2,20.9 11.8,19.3", 0.8),
    P("M13.6,19.1 C13.8,20.7 14.6,21.9 16,22.7 C16.2,21.3 15.8,19.9 14.8,18.7", 0.8),
    # the flower stalk
    P("M8,12.6 C6,13.2 4.4,15 3.6,17.8"), P("M5.4,14.4 L3.8,13.6", FINE),
]

# 16 Calceolate: a slipper or pouch. A lady's slipper orchid.
_pt = "M8.5,11 C6.4,10.4 4.2,11.6 2.9,14 C2.3,15.2 2.1,16.4 2.3,17.5 C3.2,15.7 4.3,14.4 5.7,13.4 C6.7,12.7 7.6,12.1 8.4,11.9"
S["calceolate"] = (
    [P("M7.6,12.2 C5.4,15.6 7,21.2 12,21.6 C17,21.2 18.6,15.6 16.4,12.2 C14.8,10.6 9.2,10.6 7.6,12.2 Z"),
     oval(12, 13.1, 2.7, 1.1),
     # the shield over the opening
     P("M11.1,12.3 L12,10.9 L12.9,12.3", 0.8),
     # the sepal standing above
     P("M12,10.2 C9.6,8 10,4.4 12,1.9 C14,4.4 14.4,8 12,10.2 Z"),
     P("M12,9.4 L12,3.6", FINE)]
    + both("M11.5,8.8 C10.9,7.2 11,5.8 11.4,4.6", FINE)
    # the two twisted side petals
    + both(_pt, 0.85)
    # the veins of the pouch
    + [P("M12,14.9 L12,21", FINE)] + both("M10,14.6 C8.7,16.6 8.9,19.4 10.3,20.9", FINE)
)

# 17 Zygomorphic three-part: three upright standards, three drooping falls. An iris.
_std = "M11,11 C8,9.8 6,6.8 6.4,3.6 C9,5 10.8,7.8 11,11 Z"
_fall = "M10.4,12.2 C6.8,11.6 3.2,13.6 2.8,17.6 C2.6,19.8 4.6,20.8 6.2,19.4 C8.4,17.4 9.8,15 10.4,12.2 Z"
S["zygomorphic-three-part"] = (
    [P("M12,11 C9.9,8.6 10.1,4.4 12,1.9 C13.9,4.4 14.1,8.6 12,11 Z"), P("M12,10 L12,4", FINE)]
    + both(_std) + both("M10.5,10.2 C9.4,8.4 8.2,6.6 7.2,5", FINE)
    + both(_fall)
    # the veined patch that guides a bee in along each fall
    + both("M9.4,13 C7.2,13.3 5,14.9 4.1,17.4", FINE) + both("M9.2,14 C7.8,15 6.6,16.6 6,18.2", FINE)
    + both("M8.6,12.6 C6.6,12.4 4.8,13.2 3.8,14.8", FINE)
    + [P("M12,12.8 C10,14.8 9.9,19.2 12,22 C14.1,19.2 14,14.8 12,12.8 Z"),
       P("M12,14.4 L12,20", FINE), P("M11.5,15 L11.1,18.4", FINE), P("M12.5,15 L12.9,18.4", FINE)]
)

# 18 Papilionaceous: the pea-flower, from the side. The standard stands up at the
#    back, a wing lies forward, and the keel curves up beneath it.
S["papilionaceous"] = [
    # the standard, with its veins
    P("M8.8,12.4 C5.4,8.8 6.2,3 11.2,1.7 C14.8,0.9 18,3.4 17.5,6.9 C17.1,9.6 14.2,11.2 11,12"),
    P("M9.5,11.3 C8,8.8 8.2,5.8 9.8,3.7", FINE), P("M10.1,11.1 C10.2,8.2 11.4,5.4 13.4,3.5", FINE),
    P("M10.7,11.1 C11.8,8.8 13.6,7 15.8,6", FINE),
    # the wing
    P("M9.9,12.7 C12.6,10.9 17.4,11 20,13.1 C20.8,13.9 20.4,15 19.2,15.2 C16,15.8 12.6,15.6 10,14.8"),
    P("M11.4,13.4 C14,12.6 16.6,12.8 18.8,13.8", FINE),
    # the keel
    P("M10,15 C11.4,18.4 16.8,19.4 20.4,16.9 C21.4,16.1 21.7,15 21.3,14"),
    # the calyx and its stalk
    P("M8.8,11.3 L6.6,11.5 C4.7,11.9 4,13.9 4.8,15.4 C5.6,16.4 7.2,16.5 8.8,16.1"),
    P("M8.8,11.3 L9.5,12.2", 0.8), P("M8.8,16.1 L9.7,15.4", 0.8),
    P("M5.4,13.8 L8.2,13.8", FINE),
    P("M4.4,13.9 C3.1,14.7 2.5,16.5 2.5,18.8"),
]

# 19 Rotate, umbellate: tiny flat florets held on a plate of spokes. Wild carrot:
#    every spoke ends in a small umbel of its own, with a ruff of bracts below.
_um = [P("M12,23 L12,15")]
for i in range(-3, 4):
    x, y = 12 + i * 2.9, 6.9 + abs(i) ** 1.5 * 0.42
    _um.append(P(f"M12,15 L{f(x)},{f(y + 1.7)}", 0.8))
    for da in (-30, 0, 30):
        xe, ye = polar(x, y + 1.7, 1.55, -90 + da + i * 5)
        _um += [P(f"M{f(x)},{f(y + 1.7)} L{f(xe)},{f(ye)}", FINE), dot(xe, ye, 0.46)]
_um += both("M12,15 C10.6,15.4 9.6,16.2 9,17.4", FINE) + both("M12,15 C11.2,16 10.9,17 10.9,18.2", FINE)
S["rotate-umbellate"] = _um


# 20 Apetalous, amentaceous: petal-less flowers massed in a catkin. Hazel, with the
#    tiny tufted female flower on the twig as well.
def catkin(x, y0, length, lean=0.0):
    x1 = x + lean
    parts = [P(f"M{f(x)},{f(y0 - 1)} L{f(x)},{f(y0)}", 0.8),
             P(f"M{f(x)},{f(y0)} C{f(x - 1.7)},{f(y0 + 1)} {f(x1 - 1.7)},{f(y0 + length - 2)} {f(x1)},{f(y0 + length)} "
               f"C{f(x1 + 1.7)},{f(y0 + length - 2)} {f(x + 1.7)},{f(y0 + 1)} {f(x)},{f(y0)} Z", 0.9)]
    n = int((length - 3) // 1.7)
    for i in range(1, n + 1):          # the overlapping scales
        t = (i + 0.3) / (n + 1.3)
        yy = y0 + t * length; xx = x + lean * t; w = 1.15 * math.sin(math.pi * min(t * 1.15, 0.92)) + 0.1
        parts.append(P(f"M{f(xx - w)},{f(yy - 0.5)} L{f(xx)},{f(yy + 0.4)} L{f(xx + w)},{f(yy - 0.5)}", 0.5))
    return parts


S["apetalous-amentaceous"] = (
    [P("M2.4,6.8 C7,4.6 13,5.2 21.6,2.8", 1.1),
     # a leaf bud, and the female flower with its tuft of styles
     P("M18.6,3.5 C19,2 20.2,1.4 21,1.6 C20.8,2.6 20,3.2 19.4,3.4", 0.8),
     P("M4.6,5.9 C4,4.6 4.6,3.4 5.8,3.2 C6.6,4.2 6.4,5.2 5.8,5.6", 0.8),
     P("M5.4,3.3 L4.6,1.9", FINE), P("M5.7,3.2 L5.7,1.6", FINE), P("M6,3.3 L6.8,2", FINE)]
    + catkin(9, 6.3, 15.5, -0.8) + catkin(12.8, 5.9, 13, 0.4) + catkin(16.4, 5.2, 10, 0.9)
)

NAMES = {
    "bilabiate": "Bilabiate", "funnel-form": "Funnel form", "urceolate": "Urceolate",
    "urceolate-umbellate": "Urceolate, umbellate", "salverform": "Salverform",
    "salverform-paniculate": "Salverform, paniculate", "ligulate-capitate": "Ligulate, capitate",
    "tubular-capitate": "Tubular, capitate", "rotate": "Rotate", "rotate-spicate": "Rotate, spicate",
    "crateriform": "Crateriform", "stellate": "Stellate", "cruciform": "Cruciform",
    "cyathiform": "Cyathiform", "galeate": "Galeate", "calceolate": "Calceolate",
    "zygomorphic-three-part": "Zygomorphic three-part", "papilionaceous": "Papilionaceous",
    "rotate-umbellate": "Rotate, umbellate", "apetalous-amentaceous": "Apetalous, amentaceous",
}


def svg(name):
    body = "".join(S[name])
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
            f'<g fill="none" stroke="#000000" stroke-width="{f(SW)}" stroke-linecap="round" stroke-linejoin="round">\n'
            f"{body}\n</g>\n</svg>\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    assert set(S) == set(NAMES) and len(S) == 20
    for name in S:
        with open(os.path.join(OUT, f"shape-{name}.svg"), "w", encoding="utf-8") as fh:
            fh.write(svg(name))
    print(len(S), "drawings written to", OUT)
