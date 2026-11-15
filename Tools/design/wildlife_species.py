"""Windfall wildlife drawings: single animals. Part 1, insects and other minibeasts.

wildlife.py draws one picture for each KIND of animal. This file and
wildlife_species2.py draw the animals William is most likely to see each as
ITSELF: the seven common bumblebees by their bands, the garden's ladybirds
by their spots, the butterflies by their wings.

Each drawing is tied to a scientific name with `@sp("Bombus terrestris")`.
An animal with a drawing of its own shows that. Every other animal shows
the drawing of its kind. Two animals that cannot be told apart at this
size can share one drawing: `@sp("Eristalis tenax", "Eristalis pertinax")`.

⚠️ Every drawing here is Claude's, made on 15 November 2026 from memory of
each animal's markings. None has been checked against a field guide.
"""
import math
from shapely.geometry import Polygon
from wildlife_kit import Art, P, LW, turn, curve, ell, blob, poly, limb, mirror, band, paint, figure, stroke, eye, spots
import wildlife as W
from wildlife import sp, insect, beetle, six_legs, wing_shape, feelers

BEE_WINGS = [(-1, 52, 25, 6.2, "wing", 0.85), (2.5, 30, 17, 4.6, "wing", 0.85)]


def midline(a, cx, ay, arx, ary, w=1.6, colour="black", v0=-0.9, v1=0.95):
    """A dark line down the middle of an abdomen, cut to its outline."""
    paint(a, poly((cx - w, ay + v0 * ary), (cx + w, ay + v0 * ary), (cx + w * 0.5, ay + v1 * ary), (cx - w * 0.5, ay + v1 * ary)).intersection(ell(cx, ay, arx, ary)), colour)


# ---------------------------------------------------------------- bumblebees

def bumble(th="black", th_bands=(), ab="black", bands=(), head=(4.6, 3.8, "black")):
    a = Art()
    insect(a, head=head, th=(9.5, 8.5, th), ab=(11.5, 13.5, ab), fuzz=0.045, th_bands=th_bands, bands=bands,
           wings=BEE_WINGS, legs=14, leg_lw=1.3, ant=(7, 7, 1.5))
    return a


@sp("Bombus terrestris")
def buff_tailed(): return bumble(th_bands=[(-1, -0.25, "amber")], bands=[(-0.62, -0.12, "amber"), (0.5, 1.1, "buff")])


@sp("Bombus lucorum")
def white_tailed(): return bumble(th_bands=[(-1, -0.25, "primrose")], bands=[(-0.62, -0.12, "primrose"), (0.5, 1.1, "white")])


@sp("Bombus lapidarius")
def red_tailed(): return bumble(bands=[(0.42, 1.1, "red")])


@sp("Bombus pratorum")
def early_bumblebee(): return bumble(th_bands=[(-1, -0.2, "yellow")], bands=[(-0.66, -0.2, "yellow"), (0.62, 1.1, "orange")])


@sp("Bombus hypnorum")
def tree_bumblebee(): return bumble(th="rust", bands=[(0.5, 1.1, "white")])


@sp("Bombus hortorum")
def garden_bumblebee():
    return bumble(th_bands=[(-1, -0.42, "yellow"), (0.52, 1, "yellow")], bands=[(-1, -0.52, "yellow"), (0.5, 1.1, "white")], head=(4.2, 4.8, "black"))


@sp("Bombus pascuorum")
def common_carder(): return bumble(th="rust", ab="tan", bands=[(-0.32, -0.14, "brown"), (0.16, 0.34, "brown"), (0.66, 1.1, "rust")])


# ------------------------------------------------------------- solitary bees

def solbee(th, ab, bands=(), th_bands=(), fuzz=0.05, ab_size=(8.2, 13)):
    a = Art()
    insect(a, head=(4.6, 3.9, "black"), th=(7.4, 7.2, th), ab=(ab_size[0], ab_size[1], ab), fuzz=fuzz, bands=bands, th_bands=th_bands,
           wings=[(-1, 46, 24, 5.6, "wing", 0.85), (2, 28, 16, 4.2, "wing", 0.85)], legs=12, leg_lw=1.1, ant=(8, 7, 1.5))
    return a


@sp("Osmia bicornis")
def red_mason(): return solbee("rust", "orange", [(-0.2, -0.08, "rust"), (0.25, 0.37, "rust"), (0.66, 0.78, "rust")])


@sp("Andrena fulva")
def tawny_mining(): return solbee("rust", "orange", fuzz=0.06)


@sp("Andrena cineraria")
def ashy_mining(): return solbee("black", "black", th_bands=[(-1, -0.45, "grey"), (0.5, 1, "grey")], fuzz=0.04)


@sp("Andrena haemorrhoa")
def early_mining():          # a foxy-red thorax and a shiny black abdomen that ends in an orange tail. Asked for by William, 15 November 2026
    return solbee("rust", "black", [(0.6, 1.1, "orange")], fuzz=0.045)


W.GENUS_IS["Andrena"] = "Andrena haemorrhoa"      # his own list has "Early mining bee, Andrena spp."


@sp("Colletes hederae")
def ivy_bee():
    return solbee("rust", "black", [(-0.56, -0.42, "buff"), (-0.14, 0.0, "buff"), (0.28, 0.42, "buff"), (0.68, 0.82, "buff")], fuzz=0.04)


@sp("Anthophora plumipes")
def hairy_footed():
    a = Art()
    hy, ty, ay = insect(a, head=(4.8, 3.9, "black"), th=(8.6, 8, "black"), ab=(10, 12, "black"), fuzz=0.05,
                        wings=BEE_WINGS, legs=13, leg_lw=1.2, ant=(8, 7, 1.5))
    for s in (1, -1):   # the female's orange hind legs
        stroke(a, [(50 + s * 12.4, ty + 8.6), (50 + s * 16.6, ty + 13.4)], 2.6, col="orange", smooth=False, la=1)
    return a


@sp("Anthidium manicatum")
def wool_carder():
    a = solbee("black", "black", fuzz=0.03, ab_size=(9, 12.5))
    for v in (-0.5, -0.1, 0.3, 0.66):   # yellow spots down each side
        for s in (1, -1):
            a.dot(50 + s * (6.2 - abs(v) * 1.6), 62.5 + v * 12.5, 1.5, "yellow")
    return a


# -------------------------------------------------------------------- wasps

sp("Vespula vulgaris", "Vespula germanica")(W.DRAW["wasp"])


@sp("Vespa crabro")
def hornet():
    a = Art()
    insect(a, head=(5.6, 4.6, "amber"), th=(8, 8.6, "rust"), ab=(9.4, 16, "yellow"), tip=0.2, waist=1.6,
           bands=[(-1, -0.5, "rust"), (-0.22, -0.06, "brown"), (0.2, 0.34, "brown"), (0.62, 0.74, "brown")],
           wings=[(-1, 34, 31, 5.2, "buff", 0.8), (2, 20, 20, 3.8, "buff", 0.8)], legs=15, leg_lw=1.2, ant=(11, 8, 2), eyes="brown")
    return a


# --------------------------------------------------------------------- ants

def ant_fig(colour="rust", dark=None, nodes=2):
    """A worker ant from above.  colour  the body.  dark  the head and the
    hind part, where those are darker.  nodes  how many small knobs make
    the waist: two for the red ants (Myrmica), one for the garden ants."""
    a = Art()
    cx = 50
    six_legs(a, cx, 47, 3.6, 7, 17, 1.1, angles=(-48, 4, 52), col=colour if colour != "black" else "line")
    figure(a, [ell(cx, 72, 8.2, 11.5)], dark or colour, close=0)
    for v in (-0.2, 0.3):
        stroke(a, [(cx - 7.6, 72 + v * 11.5), (cx, 73.5 + v * 11.5), (cx + 7.6, 72 + v * 11.5)], 0.5, 0.35, col="cream")
    for y, r in (((56.4, 2.0), (60.4, 2.3)) if nodes == 2 else ((59, 2.4),)):
        figure(a, [ell(cx, y, r, 2.1)], colour, close=0)
    figure(a, [ell(cx, 42, 4.6, 6), ell(cx, 51, 3.4, 5)], colour, close=1.6)
    figure(a, [blob([(cx, 21), (cx + 6, 24), (cx + 6.8, 31), (cx + 3.6, 36.5), (cx - 3.6, 36.5), (cx - 6.8, 31), (cx - 6, 24)])], dark or colour, close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 2.2, 21.5), (cx + s * 3, 17.5), (cx + s * 0.6, 16)], 1.0, smooth=False)
        stroke(a, [(cx + s * 4.5, 25), (cx + s * 12.5, 22), (cx + s * 15, 12.5)], 1.0, smooth=False)
        eye(a, cx + s * 4.4, 28, 0.9, False)
    return a


@sp("Myrmica rubra", "Myrmica ruginodis", "Myrmica scabrinodis")
def red_ant(): return ant_fig("rust", "chestnut", nodes=2)       # red-brown, darker on the head and tail, with a waist of two knobs. It stings. Asked for by William


W.GENUS_IS["Myrmica"] = "Myrmica rubra"            # his own list has "Red ant, Myrmica sabuleti", which is too scarce to be in the UK list


@sp("Lasius flavus")
def yellow_meadow_ant(): return ant_fig("amber", nodes=1)        # yellow-orange all over: the ant of the mounds in old lawns and meadows


# ---------------------------------------------------------------- hoverflies

sp("Episyrphus balteatus")(W.DRAW["hoverfly"])


def hover(head, th, ab, bands, eyes="rust", wing=(44, 29, 6.2, "wing"), mid=True, extra=None):
    a = Art()
    hy, ty, ay = insect(a, head=head, th=th, ab=ab, eyes=eyes, bands=bands,
                        wings=[(-0.5, wing[0], wing[1], wing[2], wing[3], 0.85)], legs=11, leg_lw=1.0, ant=(2.6, 2.2, 0))
    if mid:
        midline(a, 50, ay, ab[0], ab[1])
        paint(a, ell(50, ay, ab[0], ab[1]), None, LW)
    if extra:
        extra(a, hy, ty, ay)
    return a


@sp("Eristalis tenax", "Eristalis pertinax")
def drone_fly():
    return hover((6.4, 4.6, "brown"), (8, 7.6, "brown"), (8.4, 13, "black"), [(-0.78, -0.3, "amber"), (0.08, 0.15, "buff"), (0.5, 0.57, "buff")], eyes="bark", wing=(40, 28, 6.4, "wing"))


@sp("Myathropa florea")
def batman_hoverfly():
    def marks(a, hy, ty, ay):
        paint(a, blob([(46, ty - 3), (50, ty - 1.6), (54, ty - 3), (55, ty + 2.6), (50, ty + 1), (45, ty + 2.6)], 6), "black")
    return hover((6.2, 4.4, "amber"), (7.6, 7.4, "grey"), (8, 13.5, "black"), [(-0.82, -0.5, "yellow"), (-0.22, 0.04, "yellow"), (0.4, 0.6, "yellow")], extra=marks)


@sp("Helophilus pendulus")
def sun_fly():
    def stripes(a, hy, ty, ay):
        for dx in (-4.6, -1.6, 1.6, 4.6):
            stroke(a, [(50 + dx, ty - 5.6 + abs(dx) * 0.4), (50 + dx, ty + 5.6 - abs(dx) * 0.4)], 1.2, 0.95, col="primrose", smooth=False)
    return hover((6, 4.4, "amber"), (7.4, 7.4, "black"), (7.8, 14, "black"), [(-0.82, -0.42, "yellow"), (-0.12, 0.2, "yellow"), (0.5, 0.7, "buff")], extra=stripes)


@sp("Volucella zonaria")
def hornet_hoverfly():
    return hover((6.8, 4.8, "amber"), (9, 8.4, "rust"), (10, 14.5, "yellow"), [(-1, -0.7, "rust"), (-0.26, -0.06, "black"), (0.3, 0.5, "black")],
                 wing=(42, 32, 7, "buff"), mid=False)


@sp("Volucella pellucens")
def pellucid_hoverfly():
    return hover((6.4, 4.6, "brown"), (8.6, 8, "black"), (10, 13.5, "black"), [(-0.86, -0.34, "white")], wing=(42, 31, 7, "wing"), mid=False)


sp("Bombylius major")(W.DRAW["bee-fly"])


# --------------------------------------------------------------- butterflies

FORE = [(52, 45), (58, 30), (72, 18), (88, 15), (91, 24), (84, 38), (72, 47), (56, 50)]
HIND = [(52, 49), (66, 47), (80, 50), (85, 62), (79, 75), (67, 79), (58, 72), (53, 60)]


def flutter(base="orange", border="brown", bw=2.6, hind_base=None, hind_border=None, fore_marks=(), hind_marks=(), tips=None, tip_cut=72,
            body="brown", notch=(), veins=None, fore_pts=None, hind_pts=None, vein_w=0.45, vein_a=0.4):
    """A butterfly with its wings open, from above.
      base, border   the wing colour and the colour of its edge (bw is how wide the edge is, 0 for none)
      fore_marks     marks on the front wing, given for the RIGHT wing and copied to the left:
                     ("dot", x, y, size, colour)  ("eye", x, y, size, ring colour, pupil colour)
                     ("patch", [points], colour)
      tips           a colour for the tip of the front wing
      notch          bites out of the edge, for a ragged wing: (x, y, size)"""
    a = Art()
    fore = blob(fore_pts or FORE, 8); hind = blob(hind_pts or HIND, 8)
    for x, y, r in notch:
        fore = fore.difference(ell(x, y, r, r, n=20)); hind = hind.difference(ell(x, y, r, r, n=20))

    def mark(sil, m, flip):
        fx = (lambda x: 100 - x) if flip else (lambda x: x)
        if m[0] == "dot":
            paint(a, ell(fx(m[1]), m[2], m[3], m[3], n=20).intersection(sil), m[4])
        elif m[0] == "eye":
            paint(a, ell(fx(m[1]), m[2], m[3], m[3], n=24).intersection(sil), m[4])
            paint(a, ell(fx(m[1]), m[2], m[3] * 0.62, m[3] * 0.62, n=20).intersection(sil), m[5])
            if m[3] >= 3:
                a.dot(fx(m[1]) - m[3] * 0.2, m[2] - m[3] * 0.2, m[3] * 0.18, "white")
        elif m[0] == "patch":
            g = blob([(fx(x), y) for x, y in m[1]], 6)
            paint(a, g.intersection(sil), m[2])

    for flip in (False, True):
        for wing, colour, edge, marks in ((hind, hind_base or base, hind_border or border, hind_marks), (fore, base, border, fore_marks)):
            g = mirror(wing) if flip else wing
            patches = []
            if tips and wing is fore:
                x0 = 100 - tip_cut if flip else tip_cut
                patches.append((poly((x0, 0), (x0 + (-40 if flip else 40), 0), (x0 + (-40 if flip else 40), 60), (x0 + (-6 if flip else 6), 44)), tips))
            if bw:
                patches.append((g.difference(g.buffer(-bw)), edge))
            sil = figure(a, [g], colour, patches, close=0)
            if veins:
                root = (100 - 53, 47) if flip else (53, 47)
                for q in list(g.exterior.coords)[::9]:
                    stroke(a, [root, ((root[0] + q[0] * 3) / 4, (root[1] + q[1] * 3) / 4)], vein_w, vein_a, col=veins, smooth=False)
            for m in marks:
                mark(sil, m, flip)
            paint(a, sil, None, LW)
    for s in (1, -1):   # six legs, tucked close, showing either side of the body
        for (bx, by, ex, ey_) in [(1.8, 43, 7.5, 39.5), (2, 47, 8.6, 47.5), (1.8, 51, 7.6, 55)]:
            stroke(a, [(50 + s * bx, by), (50 + s * ex, ey_)], 0.8, smooth=False)
    figure(a, [ell(50, 55, 2.5, 14)], body, close=0)
    figure(a, [ell(50, 39, 2.9, 3)], body, close=0)
    for s in (1, -1):
        stroke(a, [(50 + s * 1.2, 36.5), (50 + s * 6, 24), (50 + s * 11, 15)], 0.8)
        a.dot(50 + s * 11, 15, 1.1, "line")
        eye(a, 50 + s * 2.1, 38.2, 0.7, False)
    return a


@sp("Aglais io")
def peacock():
    return flutter("red", "brown", 2.4, fore_marks=[("eye", 80, 25, 5, "yellow", "steel"), ("patch", [(62, 26), (66, 21), (69, 23), (65, 29)], "ink"), ("patch", [(69, 21), (73, 18), (75, 21), (71, 25)], "ink")],
                   hind_marks=[("eye", 74, 62, 4.6, "cream", "steel")])


@sp("Vanessa atalanta")
def red_admiral():
    return flutter("black", "black", 0, hind_border="red", fore_marks=[("patch", [(56, 41), (70, 33), (84, 29), (85, 34), (70, 39), (58, 46)], "red"),
                   ("dot", 77, 22, 2.2, "white"), ("dot", 84, 23.5, 1.4, "white"), ("dot", 72, 19.5, 1.3, "white"), ("dot", 86, 19.5, 1.0, "white")],
                   hind_marks=[("patch", [(60, 72), (70, 75), (80, 68), (84, 60), (87, 62), (81, 76), (68, 82), (58, 76)], "red"),
                               ("dot", 66, 75.6, 0.8, "ink"), ("dot", 72, 74.4, 0.8, "ink"), ("dot", 78, 70.4, 0.8, "ink")], body="black")


@sp("Aglais urticae")
def small_tortoiseshell():
    blue = [("dot", 86.4, 27, 1.0, "blue"), ("dot", 83.4, 36.6, 1.0, "blue"), ("dot", 76, 44.4, 1.0, "blue")]
    return flutter("orange", "black", 3.2,
                   fore_marks=[("patch", [(58, 30), (62, 24), (66, 26), (62, 32)], "ink"), ("patch", [(65, 24.6), (69, 20.4), (72, 22.6), (68, 27)], "yellow"),
                               ("patch", [(71, 20.6), (76, 17.6), (79, 20.4), (74, 24)], "ink"), ("dot", 83, 18.6, 1.6, "white"), ("dot", 64, 40, 2.2, "ink"), ("dot", 70.4, 34.6, 1.8, "ink")] + blue,
                   hind_marks=[("patch", [(52, 49), (66, 47.4), (64, 62), (53, 62)], "brown"), ("dot", 82, 62, 1.0, "blue"), ("dot", 77.6, 72, 1.0, "blue"), ("dot", 68, 76.6, 1.0, "blue")])


@sp("Polygonia c-album")
def comma():
    return flutter("orange", "brown", 2.2, notch=[(90.6, 31, 3.6), (81, 44.6, 3), (86, 58, 3), (75.6, 79, 3.2), (62, 78.6, 2.2)],
                   fore_marks=[("dot", 62, 30, 2.1, "ink"), ("dot", 68.6, 36, 2.1, "ink"), ("dot", 73, 25.6, 2.6, "ink"), ("dot", 64, 42, 1.6, "ink"), ("dot", 80, 28, 2.0, "brown")],
                   hind_marks=[("dot", 63, 56, 2.0, "ink"), ("dot", 70, 61, 1.8, "ink"), ("dot", 64, 66, 1.4, "brown")])


@sp("Pararge aegeria")
def speckled_wood():
    return flutter("brown", "brown", 0, fore_marks=[("dot", 66, 28, 2.4, "cream"), ("dot", 73.6, 23.6, 2.3, "cream"), ("dot", 76, 36.4, 2.5, "cream"), ("dot", 66, 40.4, 2.3, "cream"),
                   ("dot", 61, 34, 1.7, "cream"), ("eye", 82, 23.6, 2.8, "cream", "ink")],
                   hind_marks=[("eye", 65.6, 69, 2.7, "cream", "ink"), ("eye", 72.6, 66.6, 2.7, "cream", "ink"), ("eye", 78.6, 61, 2.7, "cream", "ink"), ("dot", 62, 56, 2.1, "cream")])


@sp("Maniola jurtina")
def meadow_brown():
    return flutter("brown", "bark", 1.6, fore_marks=[("patch", [(66, 25), (79, 20), (86, 27), (77, 36), (66, 35)], "orange"), ("eye", 80.6, 25, 3.2, "ink", "white")])


@sp("Pyronia tithonus")
def gatekeeper():
    return flutter("orange", "brown", 4.2, fore_marks=[("patch", [(57, 39), (70, 32), (72, 36.4), (60, 43.6)], "brown"), ("eye", 80, 25.6, 3.3, "ink", "ink"), ("dot", 79.2, 24.6, 0.75, "white"), ("dot", 81, 26.6, 0.75, "white")],
                   hind_marks=[("eye", 72, 67, 1.7, "ink", "white")])


@sp("Vanessa cardui")
def painted_lady():
    return flutter("orange", "brown", 1.4, tips="black", tip_cut=73,
                   fore_marks=[("dot", 79.6, 22, 1.8, "white"), ("dot", 85.4, 25.6, 1.4, "white"), ("dot", 75.6, 19.6, 1.3, "white"), ("dot", 81, 30, 1.2, "white"),
                               ("dot", 63.6, 34, 2.5, "ink"), ("dot", 69.6, 40, 2.1, "ink"), ("dot", 60, 42, 1.6, "ink")],
                   hind_marks=[("dot", 66, 72.4, 1.4, "ink"), ("dot", 72, 70.4, 1.4, "ink"), ("dot", 77.6, 65.6, 1.4, "ink"), ("dot", 81.6, 58.6, 1.4, "ink"), ("patch", [(52, 49), (62, 48), (60, 58), (53, 60)], "tan")])


@sp("Pieris rapae")
def small_white():           # a small grey tip and one or two grey spots
    return flutter("white", "white", 0, tips="slate", tip_cut=81, fore_marks=[("dot", 72, 34, 2.0, "slate")], hind_marks=[("dot", 66, 51, 1.3, "slate")], body="slate", veins="slate")


@sp("Pieris brassicae")
def large_white():           # bigger, with a bold black tip that runs down the wing's outer edge. The female, drawn here, has two black spots
    return flutter("white", "white", 0, tips="black", tip_cut=74, fore_marks=[("dot", 71, 33, 2.4, "black"), ("dot", 66, 43, 2.2, "black")], hind_marks=[("dot", 66, 50.6, 1.5, "black")], body="dark")


@sp("Pieris napi")
def green_veined_white():    # grey along every vein, and a tip broken into grey streaks
    return flutter("white", "white", 0, tips="grey", tip_cut=80, fore_marks=[("dot", 72, 34, 1.9, "slate")], body="slate", veins="slate", vein_w=0.9, vein_a=0.85)


@sp("Anthocharis cardamines")
def orange_tip():
    return flutter("white", "white", 0, tips="orange", tip_cut=71, fore_marks=[("dot", 73, 30.6, 1.4, "ink"), ("patch", [(84, 15), (90, 15.6), (91, 23), (87, 21)], "slate")],
                   hind_marks=[("dot", 64, 58, 2.2, "sage"), ("dot", 72, 62, 2.4, "sage"), ("dot", 66, 68, 2.2, "sage"), ("dot", 76, 70, 1.9, "sage"), ("dot", 60, 64, 1.6, "sage")], body="slate")


@sp("Polyommatus icarus")
def common_blue(): return flutter("blue", "white", 1.3, body="slate", veins="steel")


@sp("Phengaris arion")
def large_blue():            # blue with a dark border and an arc of black spots on the front wing. In William's own list, where it was showing the peacock
    return flutter("blue", "dark", 2.6, fore_marks=[("dot", 70, 27, 1.6, "ink"), ("dot", 75, 30, 1.7, "ink"), ("dot", 78, 35, 1.6, "ink"), ("dot", 74, 40, 1.5, "ink"), ("dot", 66, 33, 1.9, "ink")],
                   hind_marks=[("dot", 70, 58, 1.1, "ink"), ("dot", 75, 62, 1.1, "ink"), ("dot", 72, 68, 1.1, "ink")], body="slate", veins="steel")


@sp("Celastrina argiolus")
def holly_blue(): return flutter("sky", "ink", 1.3, tips="ink", tip_cut=84, body="slate")      # pale sky blue, by the photographs. The broad dark tip is the female's


@sp("Gonepteryx rhamni")
def brimstone():
    return flutter("yellow", "yellow", 0, fore_marks=[("dot", 70, 32, 1.4, "orange")], hind_marks=[("dot", 68, 62, 1.4, "orange")], body="olive", veins="amber",
                   fore_pts=[(52, 45), (58, 30), (72, 19), (86, 14), (93, 17), (87, 27), (84, 39), (72, 47), (56, 50)],
                   hind_pts=[(52, 49), (66, 47), (80, 50), (85, 60), (88, 68), (80, 73), (67, 79), (58, 72), (53, 60)])


# --------------------------------------------------------------------- moths

def moth_fig(fore="tan", edge="bark", hind="yellow", hind_edge="brown", marks=None, body="bark", lines=True, feathery=False):
    """A moth at rest from above: front wings swept back in a triangle, the
    hind wings just showing between them. `marks(a, m, flip)` draws one
    wing's markings, where m turns a right-wing x into the right place."""
    a = Art()
    hind_g = blob([(50, 60), (62, 62), (70, 72), (64, 81), (54, 80), (50, 74)], 8)
    fore_g = blob([(50.4, 27), (57, 28), (68, 44), (79, 68), (76, 76), (64, 77), (53, 68), (50.4, 52)], 8)
    for flip in (False, True):
        g = mirror(hind_g) if flip else hind_g
        figure(a, [g], hind, [(g.difference(g.buffer(-3)), hind_edge)] if hind_edge else [], close=0)
    for s in (1, -1):
        for pts in ([(54, 33), (62, 27), (66, 20)], [(57, 39), (67, 37), (72, 42)]):
            stroke(a, [(50 + s * (x - 50), y) for x, y in pts], 0.8, smooth=False)
    for flip in (False, True):
        g = mirror(fore_g) if flip else fore_g
        m = (lambda x: 100 - x) if flip else (lambda x: x)
        sil = figure(a, [g], fore, [(g.difference(g.buffer(-2.2)), edge)] if edge else [], close=0)
        if lines:
            stroke(a, [(m(54), 46), (m(60), 44), (m(66), 47)], 0.6, 0.5)
            stroke(a, [(m(54), 58), (m(62), 55), (m(70), 60), (m(74), 59)], 0.6, 0.5)
        if marks:
            marks(a, m, flip, sil)
            paint(a, sil, None, LW)
    figure(a, [ell(50, 32, 5.6, 6.4)], body, close=0)
    figure(a, [ell(50, 24.6, 3.6, 2.8)], body, close=0)
    for s in (1, -1):
        stroke(a, [(50 + s * 2, 23), (50 + s * 9, 16), (50 + s * 19, 14)], 0.8)
        if feathery:
            for k in range(1, 6):
                x = 50 + s * (2 + k * 2.8); y = 23 - k * 1.6
                stroke(a, [(x, y - 1.6), (x, y + 1.6)], 0.5, 0.6, smooth=False)
        eye(a, 50 + s * 2.8, 24, 0.8, False)
    return a


@sp("Noctua pronuba")
def large_yellow_underwing():
    def marks(a, m, flip, sil):
        paint(a, ell(m(61), 50.5, 2.6, 1.8, 20 if flip else -20).intersection(sil), "brown")
        paint(a, ell(m(58), 41, 1.2, 1.2).intersection(sil), "cream")
        a.dot(m(72.6), 66, 1.0, "ink")
    return moth_fig(marks=marks)


@sp("Tyria jacobaeae")
def cinnabar():
    def marks(a, m, flip, sil):
        paint(a, limb([(m(56.5), 31), (m(66), 46), (m(74), 62)], 2.4, 2.4).intersection(sil), "red")
        for x, y in ((72, 72), (64.6, 73.6)):
            paint(a, ell(m(x), y, 2.3, 2.3).intersection(sil), "red")
    return moth_fig("black", None, "red", "black", marks, body="black", lines=False)


@sp("Autographa gamma")
def silver_y():
    def marks(a, m, flip, sil):
        paint(a, blob([(m(55), 44), (m(64), 42), (m(70), 54), (m(62), 60), (m(54), 56)], 6).intersection(sil), "brown")
        stroke(a, [(m(58), 47.6), (m(60.6), 51), (m(64), 49.6)], 1.1, 1, col="white", smooth=False)
        stroke(a, [(m(60.6), 51), (m(60), 55)], 1.1, 1, col="white", smooth=False)
    return moth_fig("grey", "slate", "buff", "brown", marks, body="slate")


@sp("Euplagia quadripunctaria")
def jersey_tiger():
    def marks(a, m, flip, sil):
        for pts in ([(52, 36), (60, 33), (62, 36), (53, 40)], [(52, 50), (66, 44), (68, 48), (53, 55)], [(56, 66), (72, 56), (75, 60), (60, 70)], [(66, 74), (76, 66), (77, 70), (70, 77)]):
            paint(a, poly(*[(m(x), y) for x, y in pts]).intersection(sil), "cream")
    a = moth_fig("black", None, "orange", None, marks, body="black", lines=False)
    for s in (1, -1):
        a.dot(50 + s * 9, 74, 1.4, "ink"); a.dot(50 + s * 5.6, 77.6, 1.1, "ink")
    return a


@sp("Deilephila elpenor")
def elephant_hawk_moth():
    def marks(a, m, flip, sil):
        paint(a, limb([(m(53), 36), (m(64), 54), (m(74), 72)], 3, 3).intersection(sil), "pink")
        paint(a, limb([(m(57), 30), (m(70), 48), (m(78.6), 66)], 1.6, 1.6).intersection(sil), "pink")
    a = moth_fig("olive", "pink", "pink", "ink", marks, body="olive", lines=False)
    stroke(a, [(50, 27.6), (50, 37.6)], 1.3, 1, col="pink", smooth=False)
    return a


@sp("Zygaena filipendulae")
def six_spot_burnet():
    def marks(a, m, flip, sil):
        for x, y, r in ((54.6, 35, 1.9), (58.6, 36.6, 1.9), (58.6, 48, 2.1), (64, 49, 2.1), (64.6, 62, 2.2), (70.6, 64.6, 2.2)):
            paint(a, ell(m(x), y, r, r).intersection(sil), "red")
    return moth_fig("black", None, "red", "black", marks, body="black", lines=False)


# ----------------------------------------------------------------- ladybirds

sp("Coccinella septempunctata")(W.DRAW["ladybird"])


def lady(ely, marks, mark_col="black", pro="black", head="black", cheeks="cream", pro_marks=()):
    a = Art()
    hy, py, ey = beetle(a, head=(4.2, 2.8, head), pro=(8.6, 4.6, pro), ely=(17, 18.5, ely), marks=marks, mark_col=mark_col,
                        legs=9, leg_lw=1.1, ant=(3, 5, 0), club=0.8)
    if cheeks:
        for s in (1, -1):
            paint(a, ell(50 + s * 5.6, py - 0.4, 2.1, 2.5), cheeks)
    for dx, dy, r in pro_marks:
        a.dot(50 + dx, py + dy, r, "black")
    return a


@sp("Harmonia axyridis")
def harlequin():
    m = [(0, -0.78, 2.2)] + [(s * x, y, r) for s in (1, -1) for x, y, r in ((0.3, -0.5, 2.3), (0.64, -0.36, 2.3), (0.22, -0.08, 2.5), (0.6, 0.06, 2.5), (0.82, -0.02, 1.7), (0.28, 0.4, 2.3), (0.62, 0.46, 2.1), (0.3, 0.76, 1.8))]
    a = lady("orange", m, pro="cream", cheeks=None)
    paint(a, blob([(44.6, 23.6), (47, 28.6), (50, 26), (53, 28.6), (55.4, 23.6), (54, 31), (46, 31)], 5), "black")   # the black M behind its head
    return a


@sp("Adalia bipunctata")
def two_spot(): return lady("red", [(-0.46, -0.1, 3.6), (0.46, -0.1, 3.6)])


@sp("Propylea quatuordecimpunctata")
def fourteen_spot():
    m = [(s * x, y, r) for s in (1, -1) for x, y, r in ((0.2, -0.62, 2.6), (0.62, -0.5, 2.6), (0.2, -0.1, 2.9), (0.68, -0.02, 2.7), (0.22, 0.42, 2.7), (0.6, 0.48, 2.5), (0.26, 0.8, 1.9))]
    a = lady("primrose", m)
    stroke(a, [(50, 34), (50, 72)], 2.2, 1, col="black", smooth=False)
    return a


@sp("Halyzia sedecimguttata")
def orange_ladybird():
    m = [(s * x, y, r) for s in (1, -1) for x, y, r in ((0.24, -0.68, 2.0), (0.6, -0.5, 2.1), (0.3, -0.24, 2.2), (0.72, -0.06, 2.1), (0.34, 0.18, 2.2), (0.7, 0.36, 2.0), (0.36, 0.58, 2.0), (0.2, 0.84, 1.6))]
    return lady("orange", m, "cream", pro="orange", head="orange", cheeks=None)


@sp("Psyllobora vigintiduopunctata")
def twenty_two_spot():
    m = [(s * x, y, r) for s in (1, -1) for x, y, r in ((0.18, -0.76, 1.4), (0.46, -0.66, 1.4), (0.72, -0.48, 1.4), (0.22, -0.4, 1.5), (0.52, -0.26, 1.5), (0.84, -0.12, 1.3),
                                                           (0.24, -0.02, 1.5), (0.56, 0.14, 1.5), (0.26, 0.38, 1.5), (0.62, 0.5, 1.4), (0.3, 0.74, 1.3))]
    return lady("yellow", m, pro="yellow", head="yellow", cheeks=None, pro_marks=[(-4.6, 0.6, 0.9), (-1.6, -0.6, 0.9), (1.6, -0.6, 0.9), (4.6, 0.6, 0.9), (0, 1.8, 0.9)])


@sp("Calvia quatuordecimguttata")
def cream_spot():
    m = [(s * x, y, r) for s in (1, -1) for x, y, r in ((0.3, -0.62, 2.3), (0.2, -0.16, 2.4), (0.56, -0.2, 2.4), (0.84, -0.06, 1.9), (0.26, 0.32, 2.4), (0.64, 0.4, 2.3), (0.3, 0.76, 1.9))]
    return lady("rust", m, "cream", pro="rust", head="rust")


# -------------------------------------------------------------- other beetles

sp("Cetonia aurata")(W.DRAW["chafer"])
sp("Rhagonycha fulva")(W.DRAW["flower-beetle"])
sp("Rutpela maculata")(W.DRAW["longhorn"])
@sp("Carabus violaceus", "Carabus problematicus")
def violet_ground_beetle():  # black, with a violet sheen only along the edges (the first drawing was violet all over)
    a = Art()
    hy, py, ey = beetle(a, head=(4.4, 4, "black"), pro=(7.6, 6.2, "black"), ely=(10.5, 20, "black"), square=0.6,
                        legs=15, leg_lw=1.3, ant=(12, 12, 0), leg_angles=(-48, 12, 58))
    for s in (1, -1):
        stroke(a, [(50 + s * 8.6, ey - 13), (50 + s * 9.4, ey - 2), (50 + s * 7.6, ey + 10), (50 + s * 4, ey + 17)], 1.3, 0.95, col="plum")
        stroke(a, [(50 + s * 6.2, py - 3.6), (50 + s * 6.6, py + 3.6)], 1.2, 0.95, col="plum", smooth=False)
        stroke(a, [(50 + s * 2, hy - 3.4), (50 + s * 3.4, hy - 6.4), (50 + s * 0.8, hy - 6.6)], 1.0, smooth=False)
    for dx in (-5.4, -2.7, 2.7, 5.4):
        stroke(a, [(50 + dx, ey - 14), (50 + dx * 0.96, ey), (50 + dx * 0.6, ey + 13)], 0.5, 0.4, col="slate")
    return a


W.DRAW["ground-beetle"] = violet_ground_beetle


@sp("Melolontha melolontha")
def cockchafer():
    a = Art()
    paint(a, poly((46.6, 68), (53.4, 68), (50, 77.6)), "black", LW)                            # the pointed tail
    hy, py, ey = beetle(a, top=17, head=(4.6, 3.6, "black"), pro=(9.6, 6.2, "black"), ely=(11.6, 18.5, "brown"), square=0.85, legs=14, leg_lw=1.5, ant=None)
    for dx in (-7.4, -3.7, 3.7, 7.4):
        stroke(a, [(50 + dx, ey - 14), (50 + dx * 0.96, ey), (50 + dx * 0.62, ey + 14)], 0.6, 0.5, col="cream")
    for s in (1, -1):
        for k in range(4):                                                                     # white triangles down each side
            y = ey - 8 + k * 5.6
            paint(a, poly((50 + s * 11.4, y - 1.5), (50 + s * 11.6, y + 1.5), (50 + s * 9.2, y)), "white")
        stroke(a, [(50 + s * 2.4, hy - 2.4), (50 + s * 7, hy - 6.4)], 1.0, smooth=False)
        for d in (-1.6, 0.4, 2.4):                                                             # the fan on each feeler
            stroke(a, [(50 + s * 7, hy - 6.4), (50 + s * (10.6 + d * 0.3), hy - 9.6 + d)], 1.1, col="rust", smooth=False)
    return a


@sp("Lucanus cervus")
def stag_beetle():
    a = Art()
    for s in (1, -1):                                                                          # the male's antlers, which are its jaws
        figure(a, [limb([(50 + s * 4, 27), (50 + s * 11, 19), (50 + s * 9.6, 9), (50 + s * 4.6, 6)], 3.2, 1.6), limb([(50 + s * 10.4, 14), (50 + s * 6, 13)], 2, 1.2)], "rust", close=0.5, lw=0.9)
    hy, py, ey = beetle(a, top=24, head=(7.6, 4.8, "black"), pro=(9, 5.2, "black"), ely=(9.4, 18, "chestnut"), square=0.8, legs=17, leg_lw=1.5, ant=None)
    for s in (1, -1):
        stroke(a, [(50 + s * 5.6, hy - 1), (50 + s * 12.6, hy - 3), (50 + s * 15.6, hy + 2.6)], 1.0, smooth=False)
        a.dot(50 + s * 15.6, hy + 2.6, 1.2, "line")
    return a


@sp("Oedemera nobilis")
def thick_legged():
    a = Art()
    cx = 50
    six_legs(a, cx, 40, 3.4, 6, 13, 1.0, angles=(-44, 4, 20))
    for s in (1, -1):                                                                          # his swollen hind thighs
        figure(a, [ell(cx + s * 9, 55, 3.2, 6.6, s * -24)], "green", close=0, lw=0.9)
        stroke(a, [(cx + s * 11.4, 60.6), (cx + s * 12.6, 71), (cx + s * 15, 75)], 1.0, smooth=False)
    figure(a, [limb([(cx, 38), (cx, 76)], 3.6, 2.2)], "bark", close=0)
    for s in (1, -1):                                                                          # wing cases that taper and gape apart
        figure(a, [blob([(cx + s * 0.6, 36), (cx + s * 5.6, 37), (cx + s * 5.6, 52), (cx + s * 4.6, 72), (cx + s * 2.6, 76), (cx + s * 1.6, 58), (cx + s * 0.6, 46)], 6)], "green", close=0)
        stroke(a, [(cx + s * 3.6, 39), (cx + s * 3.9, 70)], 0.5, 0.6, col="white", smooth=False)
    figure(a, [ell(cx, 32, 3.8, 4.2)], "green", close=0)
    figure(a, [ell(cx, 25.4, 3.4, 3.2)], "green", close=0)
    feelers(a, cx, 23, 3, 13, 12, 0, 0.8)
    for s in (1, -1):
        eye(a, cx + s * 2.6, 25, 0.8, False)
    return a


def cardinal(head):
    a = Art()
    hy, py, ey = beetle(a, top=19, head=(4, 3.4, head), pro=(5, 4.2, "red"), ely=(8.6, 20, "red"), square=0.5, legs=14, leg_lw=1.1, ant=None, shine=True)
    for s in (1, -1):
        pts = [(50 + s * 2.2, hy - 2.4), (50 + s * 8, hy - 9), (50 + s * 16, hy - 10), (50 + s * 22, hy - 4)]
        stroke(a, pts, 1.0)
        c = curve(pts, 4)
        for q in c[3:]:
            stroke(a, [q, (q[0] + s * 0.4, q[1] + 2.2)], 0.7, smooth=False)                    # the teeth of its comb-like feelers
    return a


@sp("Pyrochroa serraticornis")
def cardinal_beetle(): return cardinal("red")        # the common one: red all over, head too


@sp("Pyrochroa coccinea")
def black_headed_cardinal(): return cardinal("black")


@sp("Ocypus olens")
def devils_coach_horse():
    a = Art()
    cx = 50
    six_legs(a, cx, 37, 5, 7, 15, 1.3, angles=(-42, 8, 50))
    figure(a, [blob([(cx - 5.6, 48), (cx + 5.6, 48), (cx + 6, 64), (cx + 3.6, 82), (cx, 88), (cx - 3.6, 82), (cx - 6, 64)], 6)], "black", close=0)
    for y in (54, 60, 66, 72, 78):
        w = 5.6 if y < 68 else 4.4
        stroke(a, [(cx - w, y), (cx, y + 1.2), (cx + w, y)], 0.5, 0.5, col="grey")
    figure(a, [blob([(cx - 6, 39), (cx + 6, 39), (cx + 6.4, 49), (cx, 50.6), (cx - 6.4, 49)], 6)], "black", close=0)   # short wing cases
    stroke(a, [(cx, 39.6), (cx, 50)], 0.6, 0.5, col="grey", smooth=False)
    figure(a, [ell(cx, 33, 6, 5.4)], "black", close=0)
    figure(a, [blob([(cx - 5.6, 19), (cx + 5.6, 19), (cx + 6.4, 26), (cx, 28.6), (cx - 6.4, 26)], 6)], "black", close=0)
    for s in (1, -1):
        stroke(a, [(cx + s * 3, 19.4), (cx + s * 4.6, 14.6), (cx + s * 1, 13.6)], 1.3, smooth=False)   # jaws
        stroke(a, [(cx + s * 5, 21), (cx + s * 12, 16), (cx + s * 18, 18)], 0.9)
    return a


@sp("Cicindela campestris")
def green_tiger_beetle():
    a = Art()
    beetle(a, head=(5.6, 3.6, "green"), pro=(5.6, 4.4, "marrow"), ely=(9.6, 17, "green"), marks=[(s * x, y, r) for s in (1, -1) for x, y, r in ((0.62, -0.5, 1.5), (0.4, -0.05, 1.9), (0.72, 0.2, 1.5), (0.4, 0.62, 1.5))],
           mark_col="cream", legs=20, leg_lw=1.0, ant=(12, 12, 0), leg_angles=(-46, 10, 58))
    return a


@sp("Clytus arietis")
def wasp_beetle():
    a = Art()
    hy, py, ey = beetle(a, top=20, head=(4, 3.4, "black"), pro=(5.4, 5, "black"), ely=(6.6, 20, "black"), legs=15, leg_lw=1.0, ant=(10, 10, 0), shine=False, leg_angles=(-46, 10, 60))
    cases = ell(50, ey, 6.6, 20)
    for v1, v2 in ((-0.86, -0.76), (-0.34, -0.2), (0.24, 0.36), (0.86, 1.1)):
        paint(a, band(50, ey, 6.6, 20, v1, v2).intersection(cases), "yellow")
    paint(a, band(50, py, 5.4, 5, -1, -0.66).intersection(ell(50, py, 5.4, 5)), "yellow")
    paint(a, cases, None, LW)
    return a


@sp("Lilioceris lilii")
def lily_beetle():
    a = Art()
    beetle(a, head=(3.8, 3.4, "black"), pro=(4.8, 4, "red"), ely=(10, 15.5, "red"), square=0.7, legs=12, leg_lw=1.2, ant=(9, 9, 0))
    return a


@sp("Otiorhynchus sulcatus")
def vine_weevil():
    a = Art()
    hy, py, ey = beetle(a, head=(3.8, 3.4, "black"), pro=(6.6, 5.6, "black"), ely=(10.6, 16.5, "black"), snout=6, legs=13, leg_lw=1.3, ant=None, shine=False)
    for i in range(22):
        x = 42.6 + (i * 37) % 15; y = ey - 12 + (i * 23) % 25
        if ((x - 50) / 10.6) ** 2 + ((y - ey) / 16.5) ** 2 < 0.8:
            a.dot(x, y, 0.75, "tan")
    for s in (1, -1):
        stroke(a, [(50 + s * 1, hy - 5), (50 + s * 6.5, hy - 9), (50 + s * 10.5, hy - 3.6)], 0.9, smooth=False)
        a.dot(50 + s * 10.5, hy - 3.6, 1.0, "line")
    return a


@sp("Chrysolina americana")
def rosemary_beetle():
    a = Art()
    hy, py, ey = beetle(a, head=(4.2, 3, "marrow"), pro=(8.4, 4.8, "marrow"), ely=(12.6, 16.5, "green"), legs=11, leg_lw=1.2, ant=(8.5, 10, 0), shine=False)
    for dx in (-9, -6, -3, 3, 6, 9):
        stroke(a, [(50 + dx, ey - 13 + abs(dx) * 0.6), (50 + dx * 0.98, ey), (50 + dx * 0.7, ey + 13 - abs(dx) * 0.5)], 1.2, 0.9, col="plum")
    return a


# ---------------------------------------------------------------- shield bugs

sp("Palomena prasina")(W.DRAW["shield-bug"])


def shield(body="green", tips="bark", scut="leaf", shoulders=None, wingcase=None, rim=None, legs="line", pointed=1.0, scut_tip=None, wide=1.0):
    a = Art()
    cx = 50
    six_legs(a, cx, 45, 12, 10, 15, 1.1, angles=(-44, 6, 48), col=legs)
    sh = 18.5 * pointed
    outline = blob([(cx, 24), (cx + 6, 27), (cx + sh, 36), (cx + 15.5 * wide, 46), (cx + 14 * wide, 62), (cx + 8, 76), (cx, 80),
                    (cx - 8, 76), (cx - 14 * wide, 62), (cx - 15.5 * wide, 46), (cx - sh, 36), (cx - 6, 27)], 8)
    patches = [(ell(cx, 72, 9, 10), tips)]
    if wingcase:
        patches.insert(0, (poly((cx - 20, 41), (cx + 20, 41), (cx + 16, 68), (cx - 16, 68)), wingcase))
    if shoulders:
        patches += [(ell(cx + s * sh, 36, 5, 4), shoulders) for s in (1, -1)]
    sil = figure(a, [outline], body, patches, close=0)
    paint(a, poly((cx - 9.5, 41), (cx + 9.5, 41), (cx, 63)), scut, 0.8)
    if scut_tip:
        a.dot(cx, 60.4, 1.9, scut_tip)
    stroke(a, [(cx - 16.5, 40), (cx, 41.5), (cx + 16.5, 40)], 0.7, 0.6)
    for s in (1, -1):
        stroke(a, [(cx + s * 9.5, 41), (cx + s * 13.6, 62)], 0.6, 0.5, smooth=False)
        stroke(a, [(cx + s * 3, 63), (cx + s * 9.6, 74)], 0.6, 0.5, smooth=False)
        for k in range(5):
            a.dot(cx + s * (14.6 * wide - k * 0.5), 48 + k * 4, 0.7 if rim else 0.55, rim or "cream")
        stroke(a, [(cx + s * 2.6, 25), (cx + s * 7, 17), (cx + s * 13, 13), (cx + s * 16, 6.5)], 0.9)
        eye(a, cx + s * 5.2, 27.4, 0.9, False)
    return a


@sp("Pentatoma rufipes")
def forest_bug(): return shield("brown", "bark", "brown", legs="orange", pointed=1.08, scut_tip="orange", rim="orange")


@sp("Acanthosoma haemorrhoidale")
def hawthorn_shield_bug(): return shield("green", "bark", "green", shoulders="rust", wingcase="rust", pointed=1.06)


@sp("Coreus marginatus")
def dock_bug(): return shield("tan", "bark", "brown", wide=1.16, pointed=0.86, rim="brown")


@sp("Dolycoris baccarum")
def hairy_shield_bug(): return shield("olive", "bark", "olive", wingcase="plum", scut_tip="cream", rim="ink")


# ------------------------------------------------- dragonflies and damselflies

def dragon2(damsel=False, body="blue", thorax="olive", rings="black", broad=1.0, tip=None, side_spots=None, line=None, wing_base=None, wing_band=None,
            wing_spot=False, eyes="green", thorax_stripe=None, ring_at=(-0.62, -0.3, 0.02, 0.34, 0.62), wing_tint="wing"):
    """A dragonfly or damselfly from above.
      broad       how wide the abdomen is (a chaser's is nearly three times a darter's)
      tip         a colour for the last part of the abdomen
      side_spots  a row of coloured spots down each side
      wing_base   a dark patch where each wing joins   wing_band  a dark band across each wing"""
    a = Art()
    cx = 50
    if damsel:
        wings = [(34, 66, 30, 3.6), (37, 50, 28, 3.4)]; top, w0, w1, length = 26, 3.0, 2.2, 54
    else:
        wings = [(33, 96, 37, 6.2), (38.5, 82, 35, 7.4)]; top, w0, w1, length = 22, 6.4 * broad, 3.2 * (1 + (broad - 1) * 0.5), 54 - (broad - 1) * 7
    for y, sweep, L, B in wings:
        for side in (1, -1):
            ang = 90 - side * sweep
            w = wing_shape(cx + side * 2.4, y, ang, L, B, 0.5)
            paint(a, w, wing_tint, 0.8, fa=0.8)
            t = turn(cx + side * 2.4, y, ang)
            if wing_base:
                paint(a, Polygon([t(0, -B), t(L * 0.2, -B), t(L * 0.16, B), t(0, B)]).intersection(w), wing_base, fa=0.85)
            if wing_band:
                paint(a, Polygon([t(L * 0.45, -B), t(L * 0.86, -B), t(L * 0.86, B), t(L * 0.45, B)]).intersection(w), wing_band, fa=0.8)
            stroke(a, [t(2), t(L - 2, -side * B * 0.25)], 0.45, 0.4, smooth=False)
            stroke(a, [t(L * 0.3, 0), t(L * 0.85, side * B * 0.5)], 0.45, 0.4, smooth=False)
            for u in (0.25, 0.45, 0.65):
                stroke(a, [t(L * u, -side * B * 0.5 * math.sin(math.pi * u)), t(L * u + 1, side * B * 0.55 * math.sin(math.pi * u))], 0.35, 0.3, smooth=False)
            paint(a, Polygon([t(L * 0.8, -side * B * 0.5), t(L * 0.9, -side * B * 0.46), t(L * 0.9, -side * B * 0.86), t(L * 0.8, -side * B * 0.9)]).intersection(w), "brown")
            if wing_spot:
                paint(a, ell(*t(L * 0.48, -side * B * 0.55), 1.4, 1.1).intersection(w), "ink")
            if wing_band or wing_base:
                paint(a, w, None, 0.8)
    for s in (1, -1):   # legs, held forward in a basket
        for pts in ([(2.4, 33), (8, 29), (10, 22)], [(2.6, 35), (10.6, 33.6), (14.6, 28)], [(2.6, 37.4), (10, 40.6), (13.6, 47)]):
            stroke(a, [(cx + s * x, y - (4 if damsel else 0) * 0) for x, y in pts], 0.8, smooth=False)
    c0 = 42 + length * 0.43
    tail = limb([(cx, 42), (cx, 42 + length * 0.5), (cx, 42 + length * 0.86)], w0, w1)
    marks = [(band(cx, c0, 9, length * 0.43, v, v + 0.07), rings) for v in ring_at] if rings else []
    if damsel and rings:
        marks.append((band(cx, c0, 6, length * 0.43, 0.62, 0.84), rings))
    if tip:
        marks.append((band(cx, c0, 9, length * 0.43, tip[0], tip[1]), tip[2]))
    sil = figure(a, [tail], body, marks, close=0)
    if line:
        stroke(a, [(cx, 44), (cx, 42 + length * 0.84)], 1.0 if not damsel else 0.7, 0.95, col=line, smooth=False)
    if side_spots:
        for k in range(7):
            y = 46 + k * (length * 0.11)
            for s in (1, -1):
                paint(a, ell(cx + s * (w0 * 0.3), y, w0 * 0.2, 1.4).intersection(sil), side_spots)
    th = ell(cx, 36, 4.6 if not damsel else 3.2, 7 if not damsel else 6)
    figure(a, [th], thorax, [(ell(cx + s * 1.7, 36, 0.8, 5), thorax_stripe) for s in (1, -1)] if thorax_stripe else [], close=0)
    if damsel:
        figure(a, [ell(cx, top + 2, 5.4, 2.4)], "black", close=0)
        for s in (1, -1):
            paint(a, ell(cx + s * 4.3, top + 2, 2, 2), eyes, 0.6)
    else:
        figure(a, [ell(cx, top + 3.4, 5.4, 4.2)], thorax, close=0)
        for s in (1, -1):
            paint(a, ell(cx + s * 2.6, top + 2.6, 2.8, 3.4, s * 20), eyes, 0.6)
    return a


@sp("Sympetrum striolatum", "Sympetrum sanguineum")
def common_darter(): return dragon2(body="red", thorax="rust", rings="rust", broad=0.72, eyes="rust")


@sp("Aeshna mixta")
def migrant_hawker(): return dragon2(body="ink", thorax="brown", rings=None, side_spots="blue", thorax_stripe="primrose", eyes="blue")      # blue spots in pairs, a brown thorax


@sp("Aeshna cyanea")
def southern_hawker(): return dragon2(body="ink", thorax="brown", rings=None, side_spots="green", tip=(0.6, 0.9, "blue"), thorax_stripe="green", eyes="green")


@sp("Libellula depressa")
def broad_bodied_chaser(): return dragon2(body="blue", thorax="brown", rings=None, broad=2.2, side_spots="yellow", wing_base="dark", eyes="brown")


@sp("Libellula quadrimaculata")
def four_spotted_chaser(): return dragon2(body="tan", thorax="brown", rings=None, broad=1.3, side_spots="yellow", wing_base="brown", wing_spot=True, tip=(0.4, 0.9, "ink"), eyes="brown")


@sp("Anax imperator")
def emperor(): return dragon2(body="blue", thorax="green", rings=None, line="ink", broad=1.05, eyes="blue")


@sp("Orthetrum cancellatum")
def black_tailed_skimmer(): return dragon2(body="blue", thorax="brown", rings=None, broad=1.25, tip=(0.45, 0.9, "ink"), eyes="slate")


@sp("Enallagma cyathigerum", "Coenagrion puella")
def blue_damselfly(): return dragon2(True, body="blue", thorax="black", thorax_stripe="blue", eyes="blue")


@sp("Pyrrhosoma nymphula")
def large_red_damselfly(): return dragon2(True, body="red", thorax="black", thorax_stripe="red", eyes="red")


@sp("Ischnura elegans")
def blue_tailed_damselfly(): return dragon2(True, body="ink", thorax="black", rings=None, tip=(0.42, 0.56, "blue"), thorax_stripe="blue", eyes="blue")


@sp("Calopteryx splendens")
def banded_demoiselle(): return dragon2(True, body="steel", thorax="steel", rings=None, wing_band="steel", eyes="ink")


@sp("Calopteryx virgo")
def beautiful_demoiselle(): return dragon2(True, body="steel", thorax="steel", rings=None, wing_tint="navy", eyes="ink")      # the male: wings dark blue all over. The female is under "Female"


# ------------------------------------------------------------------- spiders

sp("Araneus diadematus")(W.DRAW["spider"])


def spider_fig(abdomen, base, edge=None, head="brown", legs="brown", banded=True, reach=1.0, leg_lw=1.7, marks=None, forward=False):
    a = Art()
    cx = 50
    sets = [((3.6, 34), (15, 17), (27, 9)), ((4.6, 36.5), (24, 28), (39, 31)), ((4.6, 39.5), (25, 46), (38, 61)), ((3.6, 42), (15, 60), (22, 82))]
    if forward:   # the front two pairs held together and forwards
        sets = [((3.6, 34), (11, 18), (16, 5)), ((4.4, 35), (14, 20), (21, 8)), ((4.6, 39.5), (22, 48), (32, 64)), ((3.6, 42), (13, 60), (18, 80))]
    for s in (1, -1):
        for b, k, e in sets:
            pts = [(cx + s * b[0], b[1]), (cx + s * (b[0] + (k[0] - b[0]) * reach), 38 + (k[1] - 38) * reach), (cx + s * (b[0] + (e[0] - b[0]) * reach), 38 + (e[1] - 38) * reach)]
            stroke(a, pts, leg_lw, smooth=False, col=legs)
            if banded:
                mx, my = (pts[1][0] + pts[2][0]) / 2, (pts[1][1] + pts[2][1]) / 2
                stroke(a, [((pts[1][0] + mx) / 2, (pts[1][1] + my) / 2), (mx, my)], leg_lw, col="cream", smooth=False, la=0.9)
        stroke(a, [(cx + s * 1.8, 30), (cx + s * 3, 24.6)], 1.6, smooth=False, col=legs)
    g = blob(abdomen)
    sil = figure(a, [g], base, [(g.difference(g.buffer(-2.4)), edge)] if edge else [], close=0)
    if marks:
        marks(a, sil)
        paint(a, sil, None, LW)
    figure(a, [ell(cx, 37, 6.4, 7)], head, close=0)
    for dx in (-2.4, -0.8, 0.8, 2.4):
        a.dot(cx + dx, 31.6, 0.6, "ink")
    return a


@sp("Pisaura mirabilis")
def nursery_web_spider():
    def marks(a, sil):
        paint(a, limb([(50, 44), (50, 78)], 2.2, 1.0).intersection(sil), "cream")
        for y in (52, 60, 68):
            stroke(a, [(45.6, y), (50, y + 2), (54.4, y)], 0.6, 0.6, col="brown")
    return spider_fig([(50, 43), (55.6, 47), (57, 60), (54, 74), (50, 80), (46, 74), (43, 60), (44.4, 47)], "tan", None, head="tan", legs="tan", banded=False, leg_lw=1.4, marks=marks, forward=True)


@sp("Steatoda nobilis", "Steatoda grossa")
def false_widow():
    def marks(a, sil):
        paint(a, band(50, 59, 14, 16, -0.86, -0.62).intersection(sil), "cream")
        paint(a, blob([(46, 52), (50, 49), (54, 52), (53, 60), (50, 63), (47, 60)], 6).intersection(sil), "tan")
    return spider_fig([(50, 43), (59, 46), (63.6, 57), (61, 69), (50, 75), (39, 69), (36.4, 57), (41, 46)], "chestnut", None, head="rust", legs="rust", banded=False, reach=0.86, leg_lw=1.5, marks=marks)


@sp("Salticus scenicus")
def zebra_jumping_spider():
    def marks(a, sil):
        for v in (-0.6, -0.1, 0.4):
            paint(a, band(50, 58, 12, 15, v, v + 0.2).intersection(sil), "white")
    a = spider_fig([(50, 43), (56.6, 46), (58.6, 58), (55.6, 70), (50, 74), (44.4, 70), (41.4, 58), (43.4, 46)], "black", None, head="black", legs="grey", banded=False, reach=0.6, leg_lw=2.0, marks=marks)
    for dx, r in ((-1.9, 1.5), (1.9, 1.5)):
        a.dot(50 + dx, 31.4, r, "ink"); a.dot(50 + dx - 0.4, 31, 0.45, "white")   # its big front eyes
    return a


@sp("Pholcus phalangioides")
def cellar_spider():
    return spider_fig([(50, 43), (53, 46), (53.6, 58), (52, 68), (50, 70), (48, 68), (46.4, 58), (47, 46)], "buff", None, head="buff", legs="tan", banded=False, reach=1.16, leg_lw=0.9)


@sp("Misumena vatia")
def crab_spider():
    def marks(a, sil):
        for s in (1, -1):
            paint(a, limb([(50 + s * 8, 50), (50 + s * 9.6, 60)], 1.6, 1.6).intersection(sil), "red")
    a = spider_fig([(50, 43), (60, 47), (64, 58), (59, 69), (50, 73), (41, 69), (36, 58), (40, 47)], "white", None, head="primrose", legs="pear", banded=False, reach=0.9, leg_lw=2.0, marks=marks)
    return a


# --------------------------------------------------------- snails and slugs

def snail_fig(shell="yellow", bands=(), body="buff", mottle=None, lip=None):
    a = Art()
    foot = blob([(16, 70), (30, 66), (56, 65), (72, 62), (80, 53), (86, 52), (88, 58), (84, 68), (74, 72), (40, 73), (20, 73)], 8)
    for bx, by, ex, ey_ in [(84, 53, 91, 40), (81, 54, 84, 41)]:
        stroke(a, [(bx, by), (ex, ey_)], 1.4, smooth=False)
        a.dot(ex, ey_, 1.4, "line")
    for bx, by, ex, ey_ in [(86, 57, 92, 59), (85, 59, 90, 62.6)]:
        stroke(a, [(bx, by), (ex, ey_)], 1.0, smooth=False)
    fsil = figure(a, [foot], body, close=0)
    spots(a, fsil, [(24, 70), (32, 69), (58, 68.6), (66, 67), (76, 66), (80, 60), (84, 62)], 0.6, "tan")
    sh = ell(46, 45, 23, 22, -8)
    sil = figure(a, [sh], shell, close=0)
    spiral = []
    for k in range(0, 150):
        th = math.radians(k * 6.2 - 50); r = 21.6 * (1 - k / 150) ** 1.25
        spiral.append((45.5 + r * math.cos(th) * 1.02, 45.5 + r * math.sin(th)))
    for scale, w, colour in bands:
        stroke(a, [(q[0] * scale + 45.5 * (1 - scale), q[1] * scale + 45.5 * (1 - scale)) for q in spiral[6:62]], w, 0.9, col=colour, smooth=False)
    if mottle:
        for i in range(26):
            x = 26 + (i * 37) % 40; y = 26 + (i * 23) % 38
            if ((x - 46) / 21) ** 2 + ((y - 45) / 20) ** 2 < 1:
                stroke(a, [(x, y), (x + 2.2, y + 1.2)], 1.2, 0.7, col=mottle, smooth=False)
    stroke(a, spiral[8:], 1.0, 0.8, smooth=False)
    if lip:
        stroke(a, [(66, 56), (63, 64), (56, 66.4)], 2.0, 1, col=lip)
    paint(a, sh, None, LW)
    stroke(a, [(8, 74.5), (92, 74.5)], 0.8, 0.5, col="soil", smooth=False)
    return a


@sp("Cornu aspersum")
def garden_snail(): return snail_fig("tan", [(0.9, 2.4, "brown"), (0.72, 1.8, "brown")], body="grey", mottle="buff")


@sp("Cepaea nemoralis")
def brown_lipped_snail(): return snail_fig("yellow", [(0.92, 1.6, "brown"), (0.8, 1.8, "brown"), (0.66, 1.4, "brown")], lip="brown")


@sp("Cepaea hortensis")
def white_lipped_snail(): return snail_fig("primrose", [(0.92, 1.6, "brown"), (0.8, 1.8, "brown"), (0.66, 1.4, "brown")], lip="white")


@sp("Limax maximus")
def leopard_slug():          # pale grey-brown, the shield behind its head spotted with black and the back striped with it
    a = Art()
    body = blob([(10, 66), (24, 58), (44, 51), (62, 49), (76, 52), (87, 58), (90, 65), (84, 69), (60, 70), (34, 70), (16, 69.5)], 8)
    mantle = blob([(52, 50), (66, 47.5), (78, 52), (79, 60), (66, 63), (53, 59)], 8)
    for bx, by, ex, ey_ in [(86, 58, 93, 47), (83.5, 56.5, 88, 45.5)]:
        stroke(a, [(bx, by), (ex, ey_)], 1.4, smooth=False)
        a.dot(ex, ey_, 1.3, "line")
    stroke(a, [(89, 64), (95, 63)], 1.2, smooth=False)
    sil = figure(a, [body], "tan", [(band(50, 69, 50, 4, 0, 1.2), "buff")], close=0)
    for pts in ([(14, 65.4), (26, 60), (38, 57), (50, 55.6)], [(18, 67.4), (30, 64), (42, 62), (52, 61)]):      # two broken black stripes along the back
        c = curve(pts, 8)
        for i in range(0, len(c) - 3, 6):
            stroke(a, c[i:i + 4], 1.3, 0.95, col="ink")
    figure(a, [mantle], "tan", close=0, lw=0.9)
    spots(a, mantle, [(58, 53), (63, 51), (68, 55), (73, 52.6), (62, 58), (70, 59.6), (75, 56.6), (57, 57)], 1.3, "ink")
    a.dot(76.6, 59, 0.9, "ink")
    stroke(a, [(8, 71.5), (92, 71.5)], 0.8, 0.5, col="soil", smooth=False)
    return a


W.DRAW["slug"] = leopard_slug


@sp("Arion ater")
def large_black_slug():
    a = Art()
    body = blob([(10, 67), (20, 56), (40, 47), (62, 45), (78, 50), (88, 58), (90, 65), (84, 69), (60, 70), (34, 70), (16, 70)], 8)
    for bx, by, ex, ey_ in [(86, 58, 93, 48), (83.5, 56.5, 88, 46.5)]:
        stroke(a, [(bx, by), (ex, ey_)], 1.4, smooth=False)
        a.dot(ex, ey_, 1.3, "line")
    sil = figure(a, [body], "black", [(band(50, 69, 50, 3.4, 0, 1.2), "orange")], close=0)
    figure(a, [blob([(56, 47), (70, 45.6), (80, 51), (80, 59), (68, 61), (57, 57)], 8)], "black", close=0, lw=0.9)
    for i in range(9):   # the ridges along its back
        x = 14 + i * 4.6
        stroke(a, [(x, 66 - i * 1.5), (x + 6, 64.6 - i * 1.6)], 0.6, 0.6, col="grey", smooth=False)
    a.dot(77, 57, 1.0, "grey")
    stroke(a, [(8, 71.5), (92, 71.5)], 0.8, 0.5, col="soil", smooth=False)
    return a


# The animal each kind's own drawing shows, where that kind now has
# drawings of single animals. Read by Tools/data/build_wildlife_reference.py.
W.KIND_IS = {"bumblebee": "Bombus terrestris", "wasp": "Vespula vulgaris", "hoverfly": "Episyrphus balteatus", "ladybird": "Coccinella septempunctata",
             "chafer": "Cetonia aurata", "flower-beetle": "Rhagonycha fulva", "longhorn": "Rutpela maculata", "ground-beetle": "Carabus violaceus",
             "shield-bug": "Palomena prasina", "spider": "Araneus diadematus", "slug": "Limax maximus", "bee-fly": "Bombylius major"}
