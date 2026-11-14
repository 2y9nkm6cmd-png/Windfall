"""A sample of four flower shapes in a third style: flat colour with a
second, darker tone for shading, and the app's dark green outline.

Drawn back to front, like cut paper: a later piece covers an earlier one.
That is what lets a petal sit in front of another, which the one-colour
outline drawings could not do.

The outline colour is the app's #06472A, which build_design_assets.py
swaps for a pale green in dark mode, as it does for the bee and butterfly.
"""
import math, os, re, sys

OL = "#06472A"          # outline
SW = 0.7                # outline width on the 24 grid
FINE = 0.4


def f(n):
    s = f"{n:.2f}".rstrip("0").rstrip(".")
    return "0" if s == "-0" else s


def shape(d, fill, sw=SW):
    """A filled piece with an outline."""
    return f'<path d="{d}" fill="{fill}" stroke="{OL}" stroke-width="{f(sw)}"/>'


def tone(d, fill):
    """A patch of shading: colour only, no outline."""
    return f'<path d="{d}" fill="{fill}" stroke="none"/>'


def line(d, sw=FINE, col=OL):
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{f(sw)}"/>'


def dot(x, y, r, fill=OL, sw=0):
    st = f' stroke="{OL}" stroke-width="{f(sw)}"' if sw else ' stroke="none"'
    return f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(r)}" fill="{fill}"{st}/>'


def _map(d, fn):
    toks = re.findall(r"[MLCQZ]|-?\d+\.?\d*", d)
    out, i = [], 0
    while i < len(toks):
        if toks[i] in "MLCQZ":
            out.append(toks[i]); i += 1
        else:
            x, y = fn(float(toks[i]), float(toks[i + 1]))
            out.append(f"{f(x)},{f(y)}"); i += 2
    return " ".join(out)


def mirror(d, cx=12.0):
    return _map(d, lambda x, y: (2 * cx - x, y))


def turn(d, deg, cx=12.0, cy=12.0):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return _map(d, lambda x, y: (cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c))


LEAF, LEAF_D = "#B9D67A", "#8FB85A"
S = {}

# ---------------------------------------------------------------- Stellate
# Borage, face on. Green sepals behind, five blue petals each with one side
# in shade, a ring of white scales and the dark cone of anthers.
BLUE, BLUE_D = "#7C9BEA", "#5C7BD2"
cx, cy = 12, 12.3
_sepal = f"M{cx - 0.9},{cy - 3} C{cx - 1.3},{cy - 6} {cx - 0.6},{cy - 8.2} {cx},{cy - 9.6} C{cx + 0.6},{cy - 8.2} {cx + 1.3},{cy - 6} {cx + 0.9},{cy - 3} Z"
_petal = f"M{cx - 1.1},{cy - 2.1} C{cx - 3.7},{cy - 4.2} {cx - 3.1},{cy - 7.2} {cx},{cy - 10.6} C{cx + 3.1},{cy - 7.2} {cx + 3.7},{cy - 4.2} {cx + 1.1},{cy - 2.1} Z"
_half = f"M{cx},{cy - 10.6} C{cx + 3.1},{cy - 7.2} {cx + 3.7},{cy - 4.2} {cx + 1.1},{cy - 2.1} L{cx},{cy - 2.4} Z"
_st = [shape(turn(_sepal, 36 + 72 * k, cx, cy), LEAF, 0.55) for k in range(5)]
for k in range(5):
    a = 72 * k
    _st += [tone(turn(_petal, a, cx, cy), BLUE), tone(turn(_half, a, cx, cy), BLUE_D),
            line(turn(_petal, a, cx, cy), SW), line(turn(f"M{cx},{cy - 3.2} L{cx},{cy - 8.6}", a, cx, cy))]
# the white scales at the throat, as a small five-pointed ring
_scale = f"M{cx - 0.95},{cy - 1.3} L{cx},{cy - 3.1} L{cx + 0.95},{cy - 1.3} Z"
_st += [shape(turn(_scale, 72 * k, cx, cy), "#FFFFFF", 0.45) for k in range(5)]
_st += [dot(cx, cy, 1.5, "#FFFFFF", 0.45), dot(cx, cy, 1.05, "#3A2B52"), dot(cx - 0.3, cy - 0.3, 0.28, "#7A6A98")]
S["stellate"] = _st

# ------------------------------------------------------------- Crateriform
# A dog rose from a little above: three petals behind, the shaded inside of
# the bowl with its boss of stamens, and the front of the bowl over them.
PINK, PINK_D, PINK_IN = "#F6C3D0", "#EBA0B4", "#E48FA6"
S["crateriform"] = [
    line("M12,19 L12,23.2", 0.9, LEAF_D), line("M12,19 L12,23.2", 0.9 + 0, OL) if False else line("M12,19.2 L12,23.2", 0.8),
    # petals behind
    shape("M4,9.6 C3.2,6.2 6.2,3.6 9.2,4.8 C10.6,5.4 11.6,6.6 11.9,7.8 L11.9,9.6 Z", PINK),
    shape("M12.1,9.6 L12.1,7.8 C12.4,6.6 13.4,5.4 14.8,4.8 C17.8,3.6 20.8,6.2 20,9.6 Z", PINK),
    shape("M8.4,9.6 C8,5.4 10,2.8 12.2,2.9 C14.6,3 16.2,5.6 15.6,9.6 Z", PINK),
    tone("M9.3,9.6 C9.2,7.4 10.2,5.8 12.1,5.6 C13.9,5.8 14.8,7.4 14.7,9.6 Z", PINK_D),
    # the inside of the bowl
    f'<ellipse cx="12" cy="9.6" rx="8" ry="2.7" fill="{PINK_IN}" stroke="{OL}" stroke-width="{SW}"/>',
] + [line(f"M12,10.2 L{f(x)},{f(y)}") for x, y in [(8.9, 8.9), (9.9, 8), (11, 7.4), (12.2, 7.2), (13.4, 7.5), (14.4, 8.1), (15.2, 9)]] + [
    dot(x, y, 0.62, "#F2B632", 0.3) for x, y in [(8.8, 8.7), (9.8, 7.8), (10.9, 7.2), (12.2, 7), (13.5, 7.3), (14.5, 7.9), (15.3, 8.8), (10.6, 9), (13.2, 9.1)]
] + [
    dot(12, 9.5, 0.75, LEAF, 0.3),
    # the front of the bowl: two petals, the right one overlapping
    shape("M4,9.6 C6,12.5 18,12.5 20,9.6 C19.6,15.6 16,19 12,19 C8,19 4.4,15.6 4,9.6 Z", PINK),
    tone("M12,19 C16,19 19.6,15.6 20,9.6 C19.5,10.4 18.6,11 17.4,11.4 C17,14.6 15,17 11.4,18.2 Z", PINK_D),
    line("M10.6,11.75 C10.4,14.6 10.9,17 12.4,18.9", 0.5),
    line("M4,9.6 C6,12.5 18,12.5 20,9.6 C19.6,15.6 16,19 12,19 C8,19 4.4,15.6 4,9.6 Z", SW),
    # sepals turned back under the bowl
    shape("M11.4,19 C9.9,19.3 8.9,20.3 8.6,21.7 C10,21.5 11.2,20.7 11.9,19.4 Z", LEAF, 0.5),
    shape("M12.6,19 C14.1,19.3 15.1,20.3 15.4,21.7 C14,21.5 12.8,20.7 12.1,19.4 Z", LEAF, 0.5),
]

# --------------------------------------------------------------- Bilabiate
# A sage or dead-nettle from the side. The hood is lit on top and shaded
# beneath; the lower lip hangs forward with its darker spots; the green
# calyx clasps the foot of the tube.
LILAC, LILAC_D, LILAC_DD = "#C3ACEB", "#A68BDC", "#8A6CCB"
_cor = ("M7.6,12.4 C9.4,12.2 10.6,11.4 11.4,10 C12.6,7 15.4,4.4 18.4,4.8 C20.6,5.2 21.7,7.4 21,9.4 "
        "C20.8,10.2 20.2,10.9 19.4,11.1 C18.8,9.7 17,9.3 15.4,10.3 C14.4,10.9 13.8,11.9 13.6,12.9 "
        "C13.4,13.4 13.3,13.9 13.4,14.4 C15,14.2 17,14.8 18.4,16.2 C19.6,17.4 20,19 19.2,20.2 "
        "C18.4,21.2 17,21 16.5,19.8 C16,20.9 14.8,21 14,20 C13,18.8 12.2,17 11.6,15.6 "
        "C10.4,15.6 9,15.4 7.6,15.3 Z")
S["bilabiate"] = [
    line("M3.6,13.85 L1.3,13.85", 0.8),
    # two stamens reaching out from under the hood, drawn first so the hood covers their feet
    line("M14.2,12.2 C15.6,10.6 17.6,10.4 19.6,11.6", 0.45), dot(19.9, 11.9, 0.5, "#5A3F8A"),
    line("M14.2,12.8 C15.4,11.6 17,11.4 18.6,12.4", 0.45), dot(18.9, 12.7, 0.5, "#5A3F8A"),
    tone(_cor, LILAC),
    # shade under the hood
    tone("M21,9.4 C20.8,10.2 20.2,10.9 19.4,11.1 C18.8,9.7 17,9.3 15.4,10.3 C14.4,10.9 13.8,11.9 13.6,12.9 "
         "C13.4,11.6 13.9,10 15,8.9 C16.6,7.5 19,7.3 20.4,8.3 C20.8,8.6 21,9 21,9.4 Z", LILAC_D),
    # shade along the underside of the tube and the lip
    tone("M7.6,15.3 C9,15.4 10.4,15.6 11.6,15.6 C12.2,17 13,18.8 14,20 C14.8,21 16,20.9 16.5,19.8 "
         "C17,21 18.4,21.2 19.2,20.2 C19.7,19.4 19.7,18.5 19.4,17.6 C18.6,18.6 17.4,18.6 16.6,17.8 "
         "C15.8,18.6 14.8,18.4 14.2,17.4 C13.4,16.2 12.8,15.1 12.2,14.3 C10.6,14.5 9,14.5 7.6,14.4 Z", LILAC_D),
    # the dark of the throat
    tone("M13.6,12.9 C13.4,13.4 13.3,13.9 13.4,14.4 C14.2,14.3 15,14.4 15.8,14.7 C15.4,13.8 14.6,13.1 13.6,12.9 Z", LILAC_DD),
    line(_cor, SW),
    line("M12.6,9.4 C13.8,7.2 16,6 18.4,6.2", 0.4),
    dot(15.6, 16.2, 0.34, LILAC_DD), dot(17, 17, 0.34, LILAC_DD), dot(15.4, 17.6, 0.3, LILAC_DD),
    # the calyx, over the foot of the tube
    shape("M3.7,12.6 C5,11.9 6.6,11.8 8,12 L10.4,10.6 L9.4,12.6 L11,13.85 L9.4,15.1 L10.4,17.1 L8,15.7 "
          "C6.6,15.9 5,15.8 3.7,15.1 C3.1,14.4 3.1,13.3 3.7,12.6 Z", LEAF, 0.6),
    tone("M3.7,15.1 C5,15.8 6.6,15.9 8,15.7 L10.4,17.1 L9.4,15.1 L10.2,14.5 C8,14.9 5.6,14.9 3.4,14.3 C3.4,14.6 3.5,14.9 3.7,15.1 Z", LEAF_D),
    line("M3.7,12.6 C5,11.9 6.6,11.8 8,12 L10.4,10.6 L9.4,12.6 L11,13.85 L9.4,15.1 L10.4,17.1 L8,15.7 "
         "C6.6,15.9 5,15.8 3.7,15.1 C3.1,14.4 3.1,13.3 3.7,12.6 Z", 0.6),
    line("M4.6,13.85 L8.4,13.85", 0.4),
]

# ---------------------------------------------------------- Papilionaceous
# A sweet pea from the side: the standard standing at the back, the keel
# below, a wing lying over the keel, and the calyx at the foot.
ROSE, ROSE_D = "#F3B3CC", "#E58FB2"
WING, WING_D = "#C99BE6", "#AE7AD6"
KEEL, KEEL_D = "#F6E3EC", "#E6C6D6"
_std = "M9.4,13 C5.2,9.4 5.8,3 11.2,1.7 C14.8,0.9 18,3.4 17.5,6.9 C17.1,9.8 14.4,11.6 11.4,12.6 Z"
_wing = "M9.6,12.6 C12.6,10.7 17.6,10.9 20.2,13.1 C21,13.9 20.6,15.1 19.3,15.3 C16,15.9 12.6,15.7 9.8,14.9 Z"
_keel = "M9.4,14.6 C10.8,18.6 16.8,19.6 20.5,17 C21.6,16.2 21.9,15 21.4,13.8 C19,15.4 13,15.6 9.4,14.6 Z"
S["papilionaceous"] = [
    line("M4.4,13.9 C3.1,14.7 2.5,16.5 2.5,18.9", 0.8),
    shape(_std, ROSE),
    tone("M9.4,13 C5.2,9.4 5.8,3 11.2,1.7 C8.4,3.6 7.8,7.4 9.6,10.4 C10.2,11.3 10.8,12 11.4,12.6 Z", ROSE_D),
    line("M10.2,11.6 C9.2,9 9.6,5.8 11.4,3.6", FINE), line("M10.8,11.6 C11,8.6 12.4,5.6 14.6,3.8", FINE),
    line("M11.2,11.8 C12.4,9.4 14.2,7.4 16.4,6.4", FINE),
    line(_std, SW),
    shape(_keel, KEEL),
    tone("M10.4,16.4 C12.4,18.9 17,19.3 20.5,17 C21.2,16.5 21.6,15.8 21.6,15 C19.4,17.4 14,17.9 10.4,16.4 Z", KEEL_D),
    line(_keel, SW),
    shape(_wing, WING),
    tone("M9.8,14.9 C12.6,15.7 16,15.9 19.3,15.3 C20.4,15.1 20.9,14.2 20.5,13.5 C18,14.5 13.4,14.6 9.7,13.8 Z", WING_D),
    line("M11.2,13.3 C13.8,12.5 16.6,12.6 18.9,13.6", FINE),
    line(_wing, SW),
    shape("M9,11.2 L6.6,11.5 C4.7,11.9 4,13.9 4.8,15.4 C5.6,16.4 7.2,16.5 9,16.1 L10.6,16.8 L10,15.2 L11.2,13.9 L10,12.6 L10.8,10.8 Z", LEAF, 0.6),
    tone("M4.8,15.4 C5.6,16.4 7.2,16.5 9,16.1 L10.6,16.8 L10,15.2 L10.6,14.5 C8.6,15 6.4,14.9 4.5,14.4 C4.5,14.8 4.6,15.1 4.8,15.4 Z", LEAF_D),
    line("M9,11.2 L6.6,11.5 C4.7,11.9 4,13.9 4.8,15.4 C5.6,16.4 7.2,16.5 9,16.1 L10.6,16.8 L10,15.2 L11.2,13.9 L10,12.6 L10.8,10.8 Z", 0.6),
]



# ======================================================================
# The other sixteen. Shading here is one dark colour laid thinly over
# whatever is beneath (as the plant drawings do), so no second tone has
# to be chosen for every petal colour. It is not the outline colour,
# because that one turns pale in dark mode and would lighten instead.
SHADE = "#0A2E1C"


def shade(d, strength=0.17):
    return f'<path d="{d}" fill="{SHADE}" fill-opacity="{strength}" stroke="none"/>'


def light(d, strength=0.5):
    return f'<path d="{d}" fill="#FFFFFF" fill-opacity="{strength}" stroke="none"/>'


def crescent(x, y, r, strength=0.17):
    """Shade on the lower right of a round thing."""
    return (f'<path d="M{f(x + r * 0.2)},{f(y - r * 0.98)} A{f(r)},{f(r)} 0 0 1 {f(x - r * 0.98)},{f(y + r * 0.2)} '
            f'A{f(r * 1.25)},{f(r * 1.25)} 0 0 0 {f(x + r * 0.2)},{f(y - r * 0.98)} Z" fill="{SHADE}" fill-opacity="{strength}" stroke="none" '
            f'transform="rotate(180 {f(x)} {f(y)})"/>')


def oval(x, y, rx, ry, fill, sw=SW):
    return f'<ellipse cx="{f(x)}" cy="{f(y)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}" stroke="{OL}" stroke-width="{f(sw)}"/>'


def polar(cx, cy, r, deg, squash=1.0):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a) * squash


def lobed(cx, cy, r_in, r_out, n, power=0.55, start=-90, squash=1.0, steps=120):
    pts = []
    for k in range(steps):
        th = 2 * math.pi * k / steps
        r = r_in + (r_out - r_in) * abs(math.cos(n * th / 2)) ** power
        a = th + math.radians(start)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a) * squash))
    return "M" + " L".join(f"{f(x)},{f(y)}" for x, y in pts) + " Z"


WHITE, CREAM, YELLOW, GOLD = "#FFFFFF", "#FBF1D2", "#F7DA5E", "#F2B632"
STALK = 0.85

# ------------------------------------------------------------ Funnel form
# A lungwort or bugloss flower, upright: a tube widening steadily to a
# lobed mouth, seen a little from above so the throat shows.
FUN, FUN_L, FUN_IN = "#E9A3CC", "#F4C4DF", "#C877AE"
_fl = "M4.4,6.5 C6,11.2 10.4,13.4 10.9,19.4 Q12,20.3 13.1,19.4 C13.6,13.4 18,11.2 19.6,6.5 Z"
S["funnel-form"] = [
    line("M12,20.4 L12,23.2", STALK),
    shape(_fl, FUN),
    shade("M19.6,6.5 C18,11.2 13.6,13.4 13.1,19.4 Q12.6,19.9 12,20 C12.5,14.2 15.2,11 16.8,7.4 Z"),
    line("M12,9.4 L12,18.8"), line("M7.8,8.6 C8.8,12.2 11,14.6 11.4,18.8"), line(mirror("M7.8,8.6 C8.8,12.2 11,14.6 11.4,18.8")),
    shape(lobed(12, 6.3, 6.7, 7.9, 5, power=0.6, squash=0.38), FUN_L),
    f'<ellipse cx="12" cy="6.7" rx="4.3" ry="1.5" fill="{FUN}" stroke="none"/>',
    f'<ellipse cx="12" cy="7" rx="2.3" ry="0.85" fill="{FUN_IN}" stroke="{OL}" stroke-width="0.35"/>',
    line("M12,7 L12,4.2"), dot(12, 3.9, 0.5, "#F6F0D8", 0.3),
    line("M11,6.9 L10.4,5"), dot(10.3, 4.7, 0.5, GOLD, 0.3), line("M13,6.9 L13.6,5"), dot(13.7, 4.7, 0.5, GOLD, 0.3),
    shape("M11.2,20.6 C9.3,19.8 8.2,17.9 8.5,15.7 C9.8,16.7 10.5,17.8 10.8,18.8 Z", LEAF, 0.5),
    shape(mirror("M11.2,20.6 C9.3,19.8 8.2,17.9 8.5,15.7 C9.8,16.7 10.5,17.8 10.8,18.8 Z"), LEAF_D, 0.5),
]

# -------------------------------------------------------------- Urceolate
# A heather bell or comfrey flower: a hanging urn, pinched at the mouth,
# round and lit from the upper left.
URN = "#EFA9C9"
_urn = ("M9,5.7 C4.6,7.7 4.4,15 9.6,17.8 C9.7,18.6 9.5,19.2 9.2,19.7 L8.2,21 Q9.6,19.9 10.6,21.2 Q12,19.9 13.4,21.2 "
        "Q14.4,19.9 15.8,21 L14.8,19.7 C14.5,19.2 14.3,18.6 14.4,17.8 C19.6,15 19.4,7.7 15,5.7 Z")
S["urceolate"] = [
    line("M12,0.9 L12,3", STALK),
    line("M12,17 L12,22.4", 0.45), dot(12, 22.7, 0.45),
    shape(_urn, URN),
    shade("M15,5.7 C19.4,7.7 19.6,15 14.4,17.8 C14.3,18.6 14.5,19.2 14.8,19.7 L15.8,21 Q14.9,20.3 14.2,20.5 "
          "C13.5,19.5 13.3,18.4 13.5,17.4 C17.3,14.6 17.4,9.2 14.2,6.3 Z", 0.2),
    light("M8.3,8.8 C7.3,10.8 7.4,13.4 8.5,15.2 C8.2,13 8.3,10.8 9,9 Z"),
    line("M10.6,7 C8.6,9.8 8.6,14.4 10.8,17.4"), line("M13.4,7 C15.4,9.8 15.4,14.4 13.2,17.4"),
    shape("M9.6,3.6 L8.2,6 L10.6,4.8 L12,6.4 L13.4,4.8 L15.8,6 L14.4,3.6 Q12,2.3 9.6,3.6 Z", LEAF, 0.5),
]


# ---------------------------------------------------- Urceolate, umbellate
# Sicilian honey garlic: cream bells flushed with plum, hanging from one
# point at the top of the stem.
def urn(cx, y0):
    body = (f"M{f(cx - 0.9)},{f(y0)} C{f(cx - 3.4)},{f(y0 + 1)} {f(cx - 3.4)},{f(y0 + 4.4)} {f(cx - 1.5)},{f(y0 + 5.2)} "
            f"L{f(cx - 2.3)},{f(y0 + 6.6)} Q{f(cx - 1.1)},{f(y0 + 5.6)} {f(cx)},{f(y0 + 6.8)} Q{f(cx + 1.1)},{f(y0 + 5.6)} {f(cx + 2.3)},{f(y0 + 6.6)} "
            f"L{f(cx + 1.5)},{f(y0 + 5.2)} C{f(cx + 3.4)},{f(y0 + 4.4)} {f(cx + 3.4)},{f(y0 + 1)} {f(cx + 0.9)},{f(y0)} Z")
    flush = (f"M{f(cx - 0.9)},{f(y0)} C{f(cx - 2.2)},{f(y0 + 0.5)} {f(cx - 2.8)},{f(y0 + 1.6)} {f(cx - 2.9)},{f(y0 + 2.7)} "
             f"Q{f(cx)},{f(y0 + 1.5)} {f(cx + 2.9)},{f(y0 + 2.7)} C{f(cx + 2.8)},{f(y0 + 1.6)} {f(cx + 2.2)},{f(y0 + 0.5)} {f(cx + 0.9)},{f(y0)} Z")
    side = (f"M{f(cx + 0.9)},{f(y0)} C{f(cx + 3.4)},{f(y0 + 1)} {f(cx + 3.4)},{f(y0 + 4.4)} {f(cx + 1.5)},{f(y0 + 5.2)} L{f(cx + 2.3)},{f(y0 + 6.6)} "
            f"Q{f(cx + 1.6)},{f(y0 + 6)} {f(cx + 1)},{f(y0 + 6.1)} C{f(cx + 1.9)},{f(y0 + 4.4)} {f(cx + 2)},{f(y0 + 1.8)} {f(cx + 0.5)},{f(y0 + 0.3)} Z")
    return [tone(body, CREAM), tone(flush, "#C98AA2"), shade(side), line(body, 0.6),
            line(f"M{f(cx)},{f(y0 + 2.4)} L{f(cx)},{f(y0 + 5)}"), dot(cx, y0 + 7.6, 0.36)]


S["urceolate-umbellate"] = (
    [line("M12,23.2 L12,16.2", STALK), line("M12,3.4 L12,7", 0.6),
     line("M12,3.4 C9.2,2 5.4,3.8 5,8", 0.6), line("M12,3.4 C14.8,2 18.6,3.8 19,8", 0.6),
     shape("M12,3.6 L10.2,1 L11.6,2.4 Z", CREAM, 0.45), shape("M12,3.6 L13.9,1.2 L12.5,2.5 Z", CREAM, 0.45)]
    + urn(5, 8) + urn(19, 8) + urn(12, 7)
)

# ------------------------------------------------------------- Salverform
# A primrose: a flat face of five notched lobes with a deeper yellow eye,
# on a narrow tube held in a ribbed green calyx.
PRIM, PRIM_EYE = "#FBF0A2", "#F2C230"
_fy, _sq = 6.6, 0.42
S["salverform"] = (
    [line("M12,21 L12,23.2", STALK),
     shape("M11.1,9 L11.1,16 L12.9,16 L12.9,9 Z", "#E3EDB4", 0.55), shade("M12.2,9 L12.9,9 L12.9,16 L12.2,16 Z", 0.2),
     shape(lobed(12, _fy, 5.4, 9.2, 5, power=0.5, squash=_sq), PRIM),
     tone(lobed(12, _fy, 1.9, 4.2, 5, power=0.9, squash=_sq), PRIM_EYE)]
    + [line("M{},{} L{},{}".format(*map(f, polar(12, _fy, 4.4, -90 + 72 * k, _sq) + polar(12, _fy, 7.4, -90 + 72 * k, _sq)))) for k in range(5)]
    + [f'<ellipse cx="12" cy="{_fy}" rx="1.3" ry="0.55" fill="#B9861A" stroke="{OL}" stroke-width="0.35"/>',
       shape("M10,13.8 L10.7,15.4 L12,14 L13.3,15.4 L14,13.8 C14.3,16.6 14,19 13,20.6 Q12,21.4 11,20.6 C10,19 9.7,16.6 10,13.8 Z", LEAF, 0.55),
       shade("M12.4,14.5 L13.3,15.4 L14,13.8 C14.3,16.6 14,19 13,20.6 Q12.6,20.9 12.2,21 C12.9,19 13,16.6 12.4,14.5 Z", 0.22),
       line("M12,15.6 L12,20.4")]
)

# -------------------------------------------------- Salverform, paniculate
# Buddleia: a cone of small four-lobed florets, each with an orange eye,
# those on the right in shade, with a pair of leaves below.
BUD, BUD_D = "#C9B3EE", "#A88FDD"
_rows = [(18.2, 5), (16.0, 4), (13.8, 3), (11.6, 2), (9.4, 1)]
_pan = [line("M12,23.2 L12,19.6", STALK)]
_lf = "M12,21.4 C10,19.9 7.2,20.3 5,22.3 C7.6,23.3 10.2,22.8 12,21.4 Z"
_pan += [shape(_lf, LEAF, 0.5), shape(mirror(_lf), LEAF_D, 0.5), line("M11.2,21.7 C9.4,21.4 7.6,21.6 6,22.2"), line(mirror("M11.2,21.7 C9.4,21.4 7.6,21.6 6,22.2"))]
_pan += [shape("M4.6,19.4 C6.6,14.4 9.6,9.4 12,6.4 C14.4,9.4 17.4,14.4 19.4,19.4 Q12,20.6 4.6,19.4 Z", "#8D72C8", 0.5)]
for y, n in _rows:
    for i in range(n):
        x = 12 + (i - (n - 1) / 2) * 2.55
        _pan += [shape(lobed(x, y, 0.66, 1.2, 4, power=0.6, start=-45, steps=40), BUD_D if x > 12.6 else BUD, 0.4), dot(x, y, 0.3, "#F0923A")]
_pan += [dot(12, 7.3, 0.85, BUD, 0.4), dot(12, 5.5, 0.65, BUD_D, 0.4), dot(12, 3.9, 0.5, "#8D72C8", 0.35), dot(12, 2.6, 0.36, "#8D72C8", 0.3)]
S["salverform-paniculate"] = _pan

# ------------------------------------------------------ Ligulate, capitate
# An ox-eye daisy: two rows of white straps, the back row showing between
# the front, round a domed yellow disc.
_back = "M11.3,8.6 L10.8,4.2 Q12,2.9 13.2,4.2 L12.7,8.6 Z"
_ray = "M11.25,8.6 L10.55,3.3 L11.3,2.1 L12,2.8 L12.7,2.1 L13.45,3.3 L12.75,8.6 Z"
_dai = [shape(turn(_back, 360 * (k + 0.5) / 11), "#E4E9DB", 0.45) for k in range(11)]
for k in range(11):
    a = 360 * k / 11
    _dai += [shape(turn(_ray, a), WHITE, 0.55)]
    if 55 < a < 215:
        _dai += [shade(turn(_ray, a), 0.1)]
    _dai += [line(turn("M12,4.2 L12,8", a), 0.3)]
_dai += [dot(12, 12, 3, GOLD, 0.55), crescent(12, 12, 2.7, 0.22)]
_dai += [dot(*polar(12, 12, 1.9, 40 * k), 0.26, "#B9861A") for k in range(9)] + [dot(*polar(12, 12, 0.85, 90 * k + 20), 0.26, "#B9861A") for k in range(4)]
S["ligulate-capitate"] = _dai

# ------------------------------------------------------- Tubular, capitate
# A knapweed: a ragged tuft of purple tubed florets above a hard brown cup
# of overlapping scales.
KNAP, CUP = "#D58BD3", "#BFA06C"
_top = [(12 + i * 2.25, 4.0 + abs(i) ** 1.5 * 0.42) for i in range(-4, 5)]
_tuft = "M8.2,11.8 L" + " L".join(f"{f(x - 0.55)},{f(y + 0.5)} L{f(x - 0.35)},{f(y - 0.9)} L{f(x + 0.35)},{f(y - 0.9)} L{f(x + 0.55)},{f(y + 0.5)}" for x, y in _top) + " L15.8,11.8 Z"
_thi = [line("M12,20.2 L12,23.2", STALK),
        shape("M12,22.2 C13.6,20.9 15.8,20.9 17.4,21.9 C15.8,22.9 13.8,23 12,22.2 Z", LEAF, 0.5),
        shape(_tuft, KNAP, 0.55),
        shade("M13.2,11.8 L" + " L".join(f"{f(x - 0.55)},{f(y + 0.5)} L{f(x - 0.35)},{f(y - 0.9)} L{f(x + 0.35)},{f(y - 0.9)} L{f(x + 0.55)},{f(y + 0.5)}" for x, y in _top[6:]) + " L15.8,11.8 Z", 0.2)]
_thi += [line(f"M{f(12 + i * 0.93)},11.6 L{f(x)},{f(y + 0.3)}", 0.3) for i, (x, y) in zip(range(-4, 5), _top)]
_cup = "M8.2,11.8 C5.8,14.4 7.2,19.4 12,20.2 C16.8,19.4 18.2,14.4 15.8,11.8 Q12,13.1 8.2,11.8 Z"
_thi += [shape(_cup, CUP), shade("M15.8,11.8 C18.2,14.4 16.8,19.4 12,20.2 C15.4,18.4 16.2,14.8 14.6,12.2 Z", 0.24),
         line("M7.1,14 Q8.3,15.8 9.55,14 Q10.8,15.8 12,14 Q13.2,15.8 14.45,14 Q15.7,15.8 16.9,14", 0.4),
         line("M7.4,16.4 Q8.9,18.2 10.45,16.4 Q12,18.2 13.55,16.4 Q15.1,18.2 16.6,16.4", 0.4),
         line("M8.9,18.6 Q10.4,20 12,18.6 Q13.6,20 15.1,18.6", 0.4)]
S["tubular-capitate"] = _thi

# ------------------------------------------------------------------ Rotate
# A meadow cranesbill: five round petals lapping over one another, veined,
# with the sepal tips showing between them and ten dark stamens.
CRANE, CRANE_V = "#A9B2F2", "#6C76D2"
_sep = "M11,6.6 L12,0.9 L13,6.6 Z"
_pet = "M12,10.8 C8.4,9.8 6.6,6 8.2,3.2 C9.6,1.2 14.4,1.2 15.8,3.2 C17.4,6 15.6,9.8 12,10.8 Z"
_rot = [shape(turn(_sep, 36 + 72 * k), LEAF, 0.45) for k in range(5)]
for k in range(5):
    a = 72 * k
    _rot += [shape(turn(_pet, a), CRANE, 0.6),
             shade(turn("M12,10.8 C15.6,9.8 17.4,6 15.8,3.2 C15.4,2.6 14.8,2.2 14,1.9 C15.4,4.6 14.4,8.4 12,10.8 Z", a), 0.16)]
    _rot += [line(turn(d, a), 0.3, CRANE_V) for d in ("M12,9.6 L12,3.4", "M11.4,9.2 C10.4,7.6 9.8,5.8 9.8,4.2", "M12.6,9.2 C13.6,7.6 14.2,5.8 14.2,4.2")]
_rot += [dot(12, 12, 2.3, "#EEF0FC", 0.4)] + [dot(*polar(12, 12, 1.75, 36 * k), 0.3, "#3F3A7A") for k in range(10)] + [dot(12, 12, 0.7, "#C96A9E", 0.3)]
S["rotate"] = _rot

# --------------------------------------------------------- Rotate, spicate
# A mullein: flat yellow flowers with orange anthers up a tall spire, buds
# above and two leaves at the foot.
_sp = [line("M12,23 L12,3.3", STALK)]
_lf = "M12,22.9 C10,20.9 7,20.5 4,21.7 C6.4,23.3 9.6,23.5 12,22.9 Z"
_sp += [shape(_lf, LEAF, 0.5), shape(mirror(_lf), LEAF_D, 0.5), line("M11,22.6 C9,21.8 7,21.6 5.2,21.9"), line(mirror("M11,22.6 C9,21.8 7,21.6 5.2,21.9"))]
for x, y, r, side in [(8.8, 17.3, 2.5, -1), (15.2, 14.3, 2.5, 1), (9, 11.3, 2.3, -1), (14.9, 8.5, 2.1, 1)]:
    _sp += [line(f"M12,{f(y + r * 0.9)} L{f(12 + side * 2.2)},{f(y + r * 0.9 + 1.5)}", 0.4),
            shape(lobed(x, y, r * 0.62, r, 5, power=0.5), YELLOW, 0.5), crescent(x, y, r * 0.6, 0.16)]
    _sp += [dot(*polar(x, y, r * 0.36, 72 * k - 90), 0.3, "#E2832A") for k in range(5)]
_sp += [dot(10.5, 6.3, 0.95, "#DDE48E", 0.4), line("M12,7.2 L11.2,6.9"), dot(13.4, 4.9, 0.85, "#DDE48E", 0.4), line("M12,5.8 L12.8,5.4"),
        dot(11.2, 3.8, 0.6, LEAF, 0.35), dot(12.7, 2.9, 0.55, LEAF, 0.35), dot(12, 1.9, 0.5, LEAF, 0.35)]
S["rotate-spicate"] = _sp

# --------------------------------------------------------------- Cruciform
# Sweet rocket or honesty: four petals in a cross, each on a narrow claw,
# narrow sepals between them and six stamens round the stigma.
ROCK, ROCK_V = "#E7BCEA", "#B777C2"
_pet = "M11.3,10.3 C7.9,6.6 8.3,2 12,2 C15.7,2 16.1,6.6 12.7,10.3 Z"
_cr = [shape(turn("M11.4,9.4 L12,5.6 L12.6,9.4 Z", 45 + 90 * k), LEAF, 0.45) for k in range(4)]
for k in range(4):
    a = 90 * k
    _cr += [shape(turn(_pet, a), ROCK, 0.6), shade(turn("M12,2 C15.7,2 16.1,6.6 12.7,10.3 L12,10.3 C13.8,7.6 13.8,4.4 12,2 Z", a), 0.14)]
    _cr += [line(turn(d, a), 0.3, ROCK_V) for d in ("M12,9.4 L12,3.9", "M11.6,9.2 C10.9,7.6 10.4,6 10.4,4.6", "M12.4,9.2 C13.1,7.6 13.6,6 13.6,4.6")]
_cr += [dot(*polar(12, 12, 1.55, 60 * k + 15), 0.42, GOLD, 0.25) for k in range(6)] + [dot(12, 12, 0.75, LEAF, 0.3)]
S["cruciform"] = _cr

# -------------------------------------------------------------- Cyathiform
# A harebell nodding on its wiry stalk: an open bell of five pointed
# lobes, shaded down one side, with narrow green calyx teeth above.
HARE = "#9DBCE8"
_bell = ("M10.8,5.7 C7.4,7.4 7.2,12 6.6,15.2 L4.4,18.6 Q7,18 8.7,16.6 Q10.4,19.4 12,20.8 Q13.6,19.4 15.3,16.6 "
         "Q17,18 19.6,18.6 L17.4,15.2 C16.8,12 16.6,7.4 13.2,5.7 Q12,4.6 10.8,5.7 Z")
S["cyathiform"] = [
    line("M5.2,1.5 C8.4,0.6 11.6,1.8 12,4.4", 0.65), line("M8,1.2 L7.2,2.9"),
    line("M12,19.6 L12,22.2", 0.45), line("M12,22.2 L11.2,23.1", 0.4), line("M12,22.2 L12.8,23.1", 0.4),
    shape(_bell, HARE),
    shade("M13.2,5.7 C16.6,7.4 16.8,12 17.4,15.2 L19.6,18.6 Q17,18 15.3,16.6 C15,13 14.6,9 12.9,6 Z", 0.2),
    light("M9.4,8.4 C8.4,10.4 8.2,12.8 7.9,14.8 C8.6,12.8 9,10.4 9.9,8.6 Z"),
    line("M11.2,7.4 C9.8,10.2 9.2,13.4 8.7,16.3"), line("M12.8,7.4 C14.2,10.2 14.8,13.4 15.3,16.3"),
    shape("M10.8,5.5 L7.2,6.9 L10.4,6.6 Z", LEAF, 0.4), shape("M13.2,5.5 L16.8,6.9 L13.6,6.6 Z", LEAF_D, 0.4),
    shape("M11.5,5.9 L12,8.6 L12.5,5.9 Z", LEAF, 0.4),
    oval(12, 5.1, 1.4, 0.95, LEAF, 0.5),
]

# ----------------------------------------------------------------- Galeate
# A monkshood from the side: the tall helmet with its beak, drawn last so
# it sits over the round side sepals; stamens tucked beneath; two narrow
# sepals hanging below.
MONK, MONK_D = "#8A93E6", "#6670CE"
_helm = ("M8,12.6 C6.2,8.6 7.4,3.8 11.6,2.4 C15.4,1.4 18.6,4 18.8,7.8 C18.9,9.4 19.4,10.8 20.8,11.9 "
         "C18.8,12.2 17,11.7 15.6,10.8 C13,10.4 10.4,11.2 8,12.6 Z")
S["galeate"] = [
    line("M8,12.6 C6,13.2 4.4,15 3.6,17.8", STALK), line("M5.4,14.4 L3.8,13.6"),
    shape("M10.2,18.6 C9.2,20 8.6,21.3 8.6,22.8 C10,22.1 11.3,20.8 11.9,19 Z", MONK, 0.55),
    shape("M13.5,18.8 C13.7,20.6 14.6,21.9 16.1,22.8 C16.3,21.3 15.8,19.8 14.8,18.5 Z", MONK_D, 0.55),
    shape("M16.2,12.6 C18.8,13.6 19.2,17 17.2,18.7 C16.4,17 16,14.8 16.2,12.6 Z", MONK_D, 0.55),
    shape("M8.8,12.9 C7.6,16.2 9.6,19.4 12.6,19.2 C15.6,19 17.4,16.2 16.4,12.6 C14,11.4 11,11.6 8.8,12.9 Z", MONK),
    shade("M16.4,12.6 C17.4,16.2 15.6,19 12.6,19.2 C11.9,19.2 11.3,19.1 10.7,18.8 C13.6,18.4 15.2,15.8 14.6,12.3 Z", 0.18),
    line("M10.4,14.2 C10,16 10.8,17.6 12.2,18.2"),
    line("M13,12.4 L13.4,15.3", 0.4), dot(13.5, 15.7, 0.48, "#F3EBC2", 0.25),
    line("M13.6,12.2 L14.8,14.6", 0.4), dot(15, 14.9, 0.48, "#F3EBC2", 0.25),
    line("M12.4,12.6 L12.2,15", 0.4), dot(12.1, 15.4, 0.48, "#F3EBC2", 0.25),
    shape(_helm, MONK),
    shade("M18.8,7.8 C18.9,9.4 19.4,10.8 20.8,11.9 C18.8,12.2 17,11.7 15.6,10.8 C13,10.4 10.4,11.2 8,12.6 "
          "C10.2,10.4 13.4,9.4 16,9.8 C17.2,9.9 17.6,8.6 17.4,6.6 C17.2,5 16.4,3.8 15.2,3 C17.2,3.8 18.6,5.6 18.8,7.8 Z", 0.2),
    light("M9.6,9.8 C8.8,7.6 9.6,5.2 11.6,4.2 C10.6,5.6 10.2,7.6 10.6,9.6 Z", 0.4),
    line("M12,10 C11.4,8 12,6.2 13.6,5.2"),
]

# -------------------------------------------------------------- Calceolate
# A lady's slipper orchid: the yellow pouch, round and veined, with its
# dark opening; a maroon sepal standing above and two twisted maroon
# petals to the sides.
SLIP, MAROON, MAROON_D = "#F7D85A", "#9A4560", "#7C3049"
_pt = "M8.5,11 C6.4,10.4 4.2,11.6 2.9,14 C2.3,15.2 2.1,16.4 2.3,17.5 C3.2,15.7 4.3,14.4 5.7,13.4 C6.7,12.7 7.6,12.1 8.4,11.9 Z"
S["calceolate"] = [
    shape(_pt, MAROON, 0.55), shape(mirror(_pt), MAROON_D, 0.55),
    shape("M12,10.4 C9.6,8 10,4.4 12,1.9 C14,4.4 14.4,8 12,10.4 Z", MAROON),
    shade("M12,10.4 C14.4,8 14,4.4 12,1.9 C12.8,4.6 12.8,7.8 12,10.4 Z", 0.25),
    line("M12,9.4 L12,3.6", 0.35, "#E7B9C6"),
    shape("M7.6,12.2 C5.4,15.6 7,21.2 12,21.6 C17,21.2 18.6,15.6 16.4,12.2 C14.8,10.6 9.2,10.6 7.6,12.2 Z", SLIP),
    shade("M16.4,12.2 C18.6,15.6 17,21.2 12,21.6 C10.8,21.5 9.8,21.1 9,20.6 C13.2,20.6 16,17.6 15.4,13.4 C15.3,12.8 15.1,12.2 14.8,11.7 C15.4,11.8 16,12 16.4,12.2 Z", 0.2),
    light("M8.2,14.2 C7.6,15.8 7.8,17.6 8.6,19 C8.4,17.4 8.4,15.8 8.9,14.4 Z"),
    line("M12,14.9 L12,21", 0.35, "#B9861A"), line("M10,14.6 C8.7,16.6 8.9,19.4 10.3,20.9", 0.35, "#B9861A"), line("M14,14.6 C15.3,16.6 15.1,19.4 13.7,20.9", 0.35, "#B9861A"),
    f'<ellipse cx="12" cy="13.1" rx="2.7" ry="1.1" fill="#8A5A1E" stroke="{OL}" stroke-width="0.5"/>',
    shape("M11,12.5 L12,10.7 L13,12.5 Z", "#FBF1D2", 0.45),
]

# -------------------------------------------------- Zygomorphic three-part
# A yellow flag iris: three paler standards behind, three broad falls in
# front, each fall marked with the brown veins that lead a bee in.
FLAG, FLAG_L, VEIN = "#F9DC5C", "#FCEEA6", "#A9742A"
_std = "M11,11 C8,9.8 6,6.8 6.4,3.6 C9,5 10.8,7.8 11,11 Z"
_fall = "M10.4,12.2 C6.8,11.6 3.2,13.6 2.8,17.6 C2.6,19.8 4.6,20.8 6.2,19.4 C8.4,17.4 9.8,15 10.4,12.2 Z"
_mid = "M12,12.8 C10,14.8 9.9,19.2 12,22 C14.1,19.2 14,14.8 12,12.8 Z"
S["zygomorphic-three-part"] = [
    shape(_std, FLAG_L), shape(mirror(_std), FLAG_L), shade(mirror(_std), 0.12),
    line("M10.5,10.2 C9.4,8.4 8.2,6.6 7.2,5"), line(mirror("M10.5,10.2 C9.4,8.4 8.2,6.6 7.2,5")),
    shape("M12,11 C9.9,8.6 10.1,4.4 12,1.9 C13.9,4.4 14.1,8.6 12,11 Z", FLAG_L),
    shade("M12,11 C13.9,8.6 13.9,4.4 12,1.9 C12.7,4.8 12.7,8.2 12,11 Z", 0.14), line("M12,10 L12,4"),
    shape(_fall, FLAG), shape(mirror(_fall), FLAG),
    shade("M2.8,17.6 C2.6,19.8 4.6,20.8 6.2,19.4 C8.4,17.4 9.8,15 10.4,12.2 C8.6,15.2 6,17.4 2.8,17.6 Z", 0.16),
    shade(mirror("M2.8,17.6 C2.6,19.8 4.6,20.8 6.2,19.4 C8.4,17.4 9.8,15 10.4,12.2 C8.6,15.2 6,17.4 2.8,17.6 Z"), 0.14),
] + [line(d, 0.28, VEIN) for d in ("M9.4,13 C7.2,13.3 5,14.9 4.1,17.4", "M9.2,14 C7.8,15 6.6,16.6 6,18.2", "M8.6,12.6 C6.6,12.4 4.8,13.2 3.8,14.8")] + [
    line(mirror(d), 0.28, VEIN) for d in ("M9.4,13 C7.2,13.3 5,14.9 4.1,17.4", "M9.2,14 C7.8,15 6.6,16.6 6,18.2", "M8.6,12.6 C6.6,12.4 4.8,13.2 3.8,14.8")] + [
    line(_fall, SW), line(mirror(_fall), SW),
    shape(_mid, FLAG), shade("M12,12.8 C14,14.8 14.1,19.2 12,22 C12.9,19 12.9,15.6 12,12.8 Z", 0.16),
    line("M12,14.4 L12,20", 0.35, VEIN), line("M11.5,15 L11.1,18.4", 0.35, VEIN), line("M12.5,15 L12.9,18.4", 0.35, VEIN),
]

# -------------------------------------------------------- Rotate, umbellate
# Wild carrot: seven spokes, each carrying a small white umbel of its own,
# a ruff of bracts beneath, and the one dark floret at the very centre.
_um = [line("M12,23.2 L12,15", STALK)]
_um += [line(d, 0.4) for d in ("M12,15 C10.6,15.4 9.6,16.2 9,17.4", "M12,15 C11.2,16 10.9,17 10.9,18.2")]
_um += [line(mirror(d), 0.4) for d in ("M12,15 C10.6,15.4 9.6,16.2 9,17.4", "M12,15 C11.2,16 10.9,17 10.9,18.2")]
_heads = []
for i in range(-3, 4):
    x, y = 12 + i * 2.9, 6.9 + abs(i) ** 1.5 * 0.42
    _um.append(line(f"M12,15 L{f(x)},{f(y + 1.7)}", 0.55))
    for da in (-30, 30, 0):
        xe, ye = polar(x, y + 1.7, 1.55, -90 + da + i * 5)
        _heads += [line(f"M{f(x)},{f(y + 1.7)} L{f(xe)},{f(ye)}", 0.3), dot(xe, ye, 0.78, WHITE, 0.35)]
    if i > 0:
        _heads.append(crescent(x + 0.3, y + 0.5, 1.3, 0.12))
_um += _heads + [dot(12, 7.05, 0.5, "#6B2D4A")]
S["rotate-umbellate"] = _um


# --------------------------------------------------- Apetalous, amentaceous
# Hazel: yellow catkins hanging from a brown twig, with a leaf bud and the
# small female flower and its tuft of crimson styles.
CAT = "#E9DC78"


def catkin(x, y0, length, lean=0.0):
    x1 = x + lean
    body = (f"M{f(x)},{f(y0)} C{f(x - 1.7)},{f(y0 + 1)} {f(x1 - 1.7)},{f(y0 + length - 2)} {f(x1)},{f(y0 + length)} "
            f"C{f(x1 + 1.7)},{f(y0 + length - 2)} {f(x + 1.7)},{f(y0 + 1)} {f(x)},{f(y0)} Z")
    half = (f"M{f(x)},{f(y0)} C{f(x + 1.7)},{f(y0 + 1)} {f(x1 + 1.7)},{f(y0 + length - 2)} {f(x1)},{f(y0 + length)} "
            f"C{f(x1 + 0.5)},{f(y0 + length - 3)} {f(x + 0.5)},{f(y0 + 3)} {f(x)},{f(y0)} Z")
    parts = [line(f"M{f(x)},{f(y0 - 1)} L{f(x)},{f(y0)}", 0.6), shape(body, CAT, 0.55), shade(half, 0.2)]
    n = int((length - 3) // 1.7)
    for i in range(1, n + 1):
        t = (i + 0.3) / (n + 1.3)
        yy = y0 + t * length; xx = x + lean * t; w = 1.15 * math.sin(math.pi * min(t * 1.15, 0.92)) + 0.1
        parts.append(line(f"M{f(xx - w)},{f(yy - 0.5)} L{f(xx)},{f(yy + 0.4)} L{f(xx + w)},{f(yy - 0.5)}", 0.3, "#9A8A2E"))
    return parts


S["apetalous-amentaceous"] = (
    [line("M2.4,6.8 C7,4.6 13,5.2 21.6,2.8", 1.7), line("M2.4,6.8 C7,4.6 13,5.2 21.6,2.8", 0.9, "#B08A5E"),
     shape("M18.6,3.5 C19,2 20.2,1.4 21,1.6 C20.8,2.6 20,3.2 19.4,3.4 Z", LEAF, 0.45),
     line("M5.4,3.3 L4.5,1.7", 0.45, "#D8405A"), line("M5.7,3.2 L5.7,1.4", 0.45, "#D8405A"), line("M6,3.3 L6.9,1.8", 0.45, "#D8405A"),
     shape("M4.6,5.9 C4,4.6 4.6,3.4 5.8,3.2 C6.6,4.2 6.4,5.2 5.8,5.6 Z", LEAF, 0.45)]
    + catkin(9, 6.3, 15.5, -0.8) + catkin(12.8, 5.9, 13, 0.4) + catkin(16.4, 5.2, 10, 0.9)
)

ORDER = ["bilabiate", "funnel-form", "urceolate", "urceolate-umbellate", "salverform", "salverform-paniculate",
         "ligulate-capitate", "tubular-capitate", "rotate", "rotate-spicate", "crateriform", "stellate", "cruciform",
         "cyathiform", "galeate", "calceolate", "zygomorphic-three-part", "papilionaceous", "rotate-umbellate",
         "apetalous-amentaceous"]
NAMES = {"bilabiate": "Bilabiate", "funnel-form": "Funnel form", "urceolate": "Urceolate",
         "urceolate-umbellate": "Urceolate, umbellate", "salverform": "Salverform",
         "salverform-paniculate": "Salverform, paniculate", "ligulate-capitate": "Ligulate, capitate",
         "tubular-capitate": "Tubular, capitate", "rotate": "Rotate", "rotate-spicate": "Rotate, spicate",
         "crateriform": "Crateriform", "stellate": "Stellate", "cruciform": "Cruciform", "cyathiform": "Cyathiform",
         "galeate": "Galeate", "calceolate": "Calceolate", "zygomorphic-three-part": "Zygomorphic three-part",
         "papilionaceous": "Papilionaceous", "rotate-umbellate": "Rotate, umbellate",
         "apetalous-amentaceous": "Apetalous, amentaceous"}


def svg(name):
    body = "".join(S[name])
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">\n'
            f'<g stroke-linecap="round" stroke-linejoin="round">\n{body}\n</g>\n</svg>\n')


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out3"
    os.makedirs(out, exist_ok=True)
    assert set(S) == set(ORDER) and len(ORDER) == 20
    for name in ORDER:
        with open(os.path.join(out, f"shape-{name}.svg"), "w", encoding="utf-8") as fh:
            fh.write(svg(name))
    print(len(ORDER), "drawings written to", out)
