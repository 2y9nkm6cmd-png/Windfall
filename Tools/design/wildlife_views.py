"""Windfall wildlife drawings: an animal's OTHER pictures.

One picture is often not enough to know an animal by. A buzzard is seen
overhead far more than perched. A female blackbird is brown. A ladybird
spends weeks as a larva that looks nothing like a ladybird, and it is the
larva that eats the most greenfly. This file draws those other pictures.

Each is tied to an animal and to a short key that says what it shows:

    @view("female", "Turdus merula", main="male")

`main` says what the animal's FIRST picture shows (the one drawn in
wildlife_species.py or wildlife_species2.py), so the app can label both.
The keys and the words shown for them are VIEW_NAMES in wildlife.py.

Drawn on 15 November 2026 beside photographs from iNaturalist, which were
looked at and not copied (Design/Wildlife/CHECKED.md says which).
"""
import math
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from wildlife_kit import Art, P, LW, turn, curve, ell, blob, poly, limb, mirror, band, paint, figure, stroke, eye, spots
import wildlife as W
from wildlife import view, insect, beetle, six_legs
import wildlife_species as S1
import wildlife_species2 as S2
from wildlife_species2 import bird, TIT, FINCH, CROW, DOVE
from wildlife_flight import soar


# =====================================================================
# BIRDS IN FLIGHT, from below. See wildlife_flight.py for what each word means.
# =====================================================================

@view("flight", "Buteo buteo", main="perched")
def buzzard_flight():        # broad wings held in a shallow V, a short fanned tail, a dark patch at each wrist and a dark back edge
    return soar(span=44, chord=15, shape="broad", sweep=3, col="brown", under="buff", carpal="dark", edge="dark", tips="dark", tail=(13, 16, "fan"), tail_col="buff",
                tail_tip="brown", tail_bars=2, belly="buff", breast="brown", head_col="brown", bill=(2.6, 2.4, "yellow"))


@view("flight", "Falco tinnunculus", main="male")
def kestrel_flight():        # pointed wings and a long tail, fanned as it hovers, with a black band at its end
    return soar(span=42, chord=10, shape="point", sweep=6, col="buff", under="cream", tips="dark", bars="brown", tail=(22, 9, "fan"), tail_col="grey", tail_tip="ink", belly="buff",
                body_bars="brown", head_col="slate", body=(4.4, 26))


@view("flight", "Accipiter nisus", main="male")
def sparrowhawk_flight():    # short, broad, blunt wings and a long square tail: barred all over
    return soar(span=36, chord=14, shape="broad", sweep=5, col="cream", under="cream", bars="slate", tail=(24, 8, "square"), tail_col="grey", tail_bars=3, belly="cream",
                body_bars="orange", head_col="slate", body=(4.6, 26))


@view("flight", "Hirundo rustica", main="perched")
def swallow_flight():        # long tail streamers, a red throat above a dark band, cream below
    return soar(span=40, chord=8, shape="point", sweep=14, arch=1, col="steel", under="cream", tail=(26, 14, "streamers"), tail_col="steel", belly="cream", breast="steel",
                throat="rust", head_col="steel", body=(4.2, 24), head=(3.6, 3.4), bill=(1.4, 1.8, "ink"), cy=38)


@view("flight", "Delichon urbicum", main="perched")
def house_martin_flight():   # stubbier than a swallow, a short forked tail and pure white below
    return soar(span=36, chord=9, shape="point", sweep=11, arch=1, col="ink", under="grey", tail=(12, 11, "fork"), tail_col="ink", belly="white", throat="white", head_col="ink",
                body=(4.6, 24), head=(3.8, 3.4), bill=(1.2, 1.8, "ink"), cy=42)


@view("flight", "Larus argentatus", main="perched")
def herring_gull_flight():   # long white wings, grey along the back edge, with black tips
    return soar(span=47, chord=10, shape="point", sweep=8, col="white", under="white", tips="black", edge="grey", tail=(10, 11, "fan"), tail_col="white", belly="white",
                head_col="white", bill=(4.4, 2.4, "yellow"), body=(5, 28))


@view("flight", "Larus fuscus", main="perched")
def lesser_black_backed_flight():      # the same shape, but the flight feathers show dark from below
    return soar(span=47, chord=10, shape="point", sweep=8, col="slate", under="white", tips="black", tail=(10, 11, "fan"), tail_col="white", belly="white", head_col="white",
                bill=(4.4, 2.4, "yellow"), body=(5, 28))


@view("flight", "Chroicocephalus ridibundus", main="summer")
def black_headed_gull_flight():        # slimmer, with a white front edge to the wing and dark under the tips
    return soar(span=44, chord=9, shape="point", sweep=9, col="grey", under="white", tips="dark", lead="white", tail=(10, 10, "fan"), tail_col="white", belly="white",
                head_col="brown", bill=(3.6, 1.8, "red"), body=(4.4, 26))


@view("flight", "Ardea cinerea", main="perched")
def heron_flight():          # huge bowed wings, dark behind and grey in front, the neck drawn in and the legs trailing
    return soar(span=46, chord=17, shape="broad", sweep=2, col="slate", under="grey", tail=(7, 9, "square"), tail_col="grey", belly="white", head_col="white",
                bill=(8, 2.2, "yellow"), legs=(15, "olive"), body=(5, 26), head=(3.4, 4.6), cy=44)


@view("flight", "Columba palumbus", main="perched")
def woodpigeon_flight():     # a deep chest and a small head, a dark band at the end of the tail
    return soar(span=38, chord=13, shape="point", sweep=5, col="slate", under="grey", tail=(14, 11, "fan"), tail_col="grey", tail_tip="ink", belly="grey", breast="pink",
                head_col="grey", bill=(1.8, 1.8, "amber"), body=(6, 28))


@view("flight", "Corvus corone", main="perched")
def crow_flight():           # all black, with fingered wing tips and a square-ended fan of a tail
    return soar(span=42, chord=14, shape="broad", sweep=3, col="black", tail=(14, 13, "fan"), bill=(4.6, 2.8, "black"), body=(5.4, 28))


@view("flight", "Corvus corax", main="perched")
def raven_flight():          # bigger and longer-winged than a crow, and the tail comes to a wedge: the surest way to tell it overhead
    return soar(span=46, chord=13, shape="broad", sweep=5, col="black", tail=(18, 14, "wedge"), bill=(6, 3.4, "black"), body=(5.6, 30), head=(4.4, 4.6))


@view("flight", "Tyto alba", main="perched")
def barn_owl_flight():       # ghost-white below, with broad rounded wings and a big round head
    return soar(span=42, chord=15, shape="broad", sweep=1, arch=2, col="white", under="white", tips="buff", tail=(9, 11, "fan"), tail_col="white", belly="white", head_col="white",
                bill=(1.4, 1.4, "skin"), body=(5.6, 24), head=(5.6, 5.2), legs=(4, "skin"))


@view("flight", "Sturnus vulgaris", main="adult")
def starling_flight():       # a short tail and pointed, triangular wings: a small dark arrowhead
    return soar(span=34, chord=13, shape="point", sweep=5, arch=1, col="dark", under="brown", tail=(8, 9, "square"), tail_col="dark", belly="black", head_col="black",
                bill=(4, 1.8, "yellow"), body=(5, 26))


@view("flight", "Anas platyrhynchos", main="male")
def mallard_flight():        # a long neck stretched out in front, white under the wings, the drake's dark head and breast
    return soar(span=38, chord=11, shape="point", sweep=6, col="grey", under="white", tail=(8, 9, "fan"), tail_col="white", belly="grey", breast="brown", head_col="marrow",
                bill=(4.6, 3, "yellow"), body=(5.4, 34), head=(3.6, 4.4), cy=50)


# =====================================================================
# BIRDS: the female, the young bird, the winter bird
# =====================================================================

@view("female", "Turdus merula", main="male")
def blackbird_female():      # dark brown, paler and faintly streaked on the throat and breast, with a duller bill and no bright eye ring
    return bird(bx=45, by=54, bl=21, bd=12, tilt=-10, hr=8, hh=0.9, chest=1.05, bill=(8, 3.2, "fine", "soil"), culmen=0.14, tail=(22, 7, "square"), tail_ang=189, back="chestnut", belly="brown",
                wing="chestnut", throat="tan", breast="brown", streaks="chestnut", legs=(14, "dark"), leg_w=1.5, feet="stand", leg_at=(0, 7))


@view("female", "Passer domesticus", main="male")
def house_sparrow_female():  # plain buff-brown, with a pale stripe behind the eye and no black bib or grey cap
    return bird(**{**FINCH, "bd": 12.6, "hr": 8.8, "hh": 0.88, "chest": 1.16, "tilt": -18, "tail": (15, 6, "square")}, bill=(5.4, 4.8, "cone", "seed"), back="brown", belly="buff", cap="soil",
                cheek="buff", wing="brown", wingbars=[(-0.44, -0.32, "cream")], back_streaks="ink", breast="buff", eyebrow="cream")


@view("female", "Fringilla coelebs", main="male")
def chaffinch_female():      # olive-brown where the male is pink and blue, but with the same two white wing bars
    return bird(**{**FINCH, "bl": 18.5, "bd": 11.4, "hr": 7.8, "hh": 1.0, "tilt": -15, "tail": (18, 6, "notch")}, bill=(5.6, 3.6, "cone", "seed"), back="soil", belly="buff",
                breast="buff", cap="soil", cheek="buff", wing="black", wingbars=[(-0.52, -0.34, "white"), (-0.06, 0.05, "white")], tail_col="black", tail_edge="white",
                rump="olive", vent="white")


@view("female", "Pyrrhula pyrrhula", main="male")
def bullfinch_female():      # the same black cap and white rump, but the breast is buff-grey, not pink
    return bird(**{**FINCH, "bl": 16, "bd": 14, "hr": 8.8, "hw": 1.06, "hh": 0.92, "tilt": -14, "chest": 1.25, "tail": (15, 6, "square"), "culmen": 0.5}, bill=(3.4, 4.6, "cone", "black"),
                back="soil", belly="tan", breast="tan", cheek="tan", throat="tan", cap="ink", rump="white", wing="black", wingbars=[(-0.42, -0.28, "white")], tail_col="black", vent="white",
                face="ink")


@view("female", "Sylvia atricapilla", main="male")
def blackcap_female():       # her cap is chestnut-brown
    return bird(bl=18, bd=10.6, tilt=-18, hr=7.4, bill=(5.6, 1.9, "fine", "dark"), tail=(17, 5, "square"), back="soil", belly="cream", cap="rust", wing="brown", legs=(10, "slate"), leg_w=1.1,
                breast="buff", wing_len=1.06)


@view("female", "Anas platyrhynchos", main="male")
def mallard_female():        # mottled brown all over, with an orange and brown bill and the same blue patch in the wing
    return bird(bx=46, by=58, bl=25, bd=11.5, tilt=-3, hr=7.4, hdx=4, hdy=-9, neck=[(70, 46)], bill=(9, 3.6, "duck", "orange"), tail=(8, 7, "fan"), tail_ang=200, tail_col="buff", back="soil", belly="tan",
                breast="tan", wing="brown", wingbars=[(0.2, 0.42, "steel")], feet="swim", eye_r=1.1, hood="tan", cap="brown", eyeline="brown", neck_col="tan", spots_="brown", back_streaks="dark")


@view("female", "Phasianus colchicus", main="male")
def pheasant_female():       # sandy brown, mottled with black, and a shorter tail
    return bird(bx=50, by=56, bl=20, bd=12, tilt=-8, hr=6.2, hdx=2, hdy=-8, neck=[(68, 46)], neck_col="tan", bill=(4.4, 3, "cone", "buff"), tail=(26, 6.5, "point"), tail_ang=186, tail_col="tan",
                back="tan", belly="buff", hood="tan", wing="tan", spots_="dark", back_streaks="dark", legs=(12, "slate"), feet="stand", leg_at=(-2, 6), eye_r=1.0)


@view("female", "Falco tinnunculus")
def kestrel_female():        # brown-headed, with a barred brown back and tail where the male is grey and spotted rust
    return bird(bx=47, by=50, bl=18, bd=9.6, tilt=-66, hr=6.6, hdx=-1.5, hdy=1.5, bill=(4.6, 4, "hook", "slate"), tail=(27, 6, "round"), tail_ang=104, tail_col="soil", tail_tip="ink",
                back="soil", belly="buff", hood="soil", moustache="ink", wing="soil", primaries="ink", wing_len=1.25, streaks="brown", back_streaks="ink", legs=(8, "yellow"), leg_at=(1, 6),
                thigh=4.5, eye_r=1.4, eye_ring="yellow", extra=[(ell(62.2, 25.2, 1.7, 1.4), "yellow")])


@view("juvenile", "Erithacus rubecula", main="adult")
def robin_juvenile():        # no red at all for its first summer: brown, speckled all over with buff
    def speckles(a, sil, head, t):
        for i in range(26):
            p = t(11 - (i * 7) % 24, -9 + (i * 5) % 19)
            if sil.buffer(-1).contains(Point(p)):
                a.dot(p[0], p[1], 0.7, "buff")
        for i in range(5):
            a.dot(head[0] - 4 + i * 1.9, head[1] - 4.6 + (i % 2) * 1.6, 0.6, "buff")
    return bird(bx=45, by=54, bl=14.5, bd=13.2, tilt=-42, hr=8.6, chest=1.2, belly_h=1.1, bill=(5.4, 2.0, "fine", "dark"), tail=(14, 5.4, "square"), tail_ang=148, back="brown", belly="buff",
                breast="tan", legs=(14, "brown"), leg_w=1.0, droop=0.55, leg_at=(-1, 5), eye_r=1.5, spots_="brown", after=speckles)


@view("juvenile", "Sturnus vulgaris")
def starling_juvenile():     # plain mouse-brown with a pale throat and a dark bill: often taken for a different bird
    return bird(bl=18, bd=12, tilt=-30, hr=7.4, hh=0.84, chest=1.1, bill=(10, 2.8, "dagger", "dark"), tail=(9, 6, "notch"), wing_len=1.25, back="soil", belly="tan", throat="cream",
                wing="brown", primaries="brown", legs=(13, "skin"), leg_w=1.5, feet="stand")


@view("winter", "Chroicocephalus ridibundus")
def black_headed_gull_winter():        # from late summer the dark hood goes, leaving a white head with a dark smudge behind the eye
    def smudge(a, sil, head, t):
        a.dot(head[0] - 2.2, head[1] + 0.6, 1.5, "dark")
    return bird(bx=44, by=51, bl=21, bd=11, tilt=-12, hr=7.4, bill=(8, 2.8, "fine", "red"), tail=(11, 6.4, "square"), tail_col="white", back="white", belly="white", wing="grey", wing_len=1.3,
                legs=(13, "red"), feet="stand", leg_at=(-1, 6), eye_r=1.0, primaries="black", after=smudge)


@view("perched", "Milvus milvus", main="flight")
def red_kite_perched():      # rusty, streaked, with a pale grey head, a pale eye and long wings that reach the forked tail
    return bird(bx=47, by=50, bl=22, bd=12, tilt=-62, hr=7.2, hdx=-1.5, hdy=1.5, chest=1.08, bill=(5.6, 4.6, "hook", "yellow"), tail=(22, 9, "fork"), tail_ang=106, tail_col="orange",
                back="rust", belly="rust", hood="grey", wing="brown", primaries="ink", wing_len=1.3, streaks="dark", back_streaks="dark", legs=(8, "yellow"), leg_w=1.7, leg_at=(1, 6), thigh=6,
                eye_r=1.4, eye_col="primrose")


@view("female", "Capreolus capreolus", main="male")
def roe_doe(): return S2.deer_fig(antlers="none")      # the doe has no antlers


# =====================================================================
# INSECTS: the other sex
# =====================================================================

@view("male", "Anthophora plumipes", main="female")
def hairy_footed_male():     # the female is black. The male is gingery brown with a cream face, and hovers in front of flowers
    a = Art()
    hy, ty, ay = insect(a, head=(4.8, 3.9, "buff"), th=(8.6, 8, "soil"), ab=(10, 12, "soil"), fuzz=0.05, bands=[(0.5, 1.1, "dark")],
                        wings=S1.BEE_WINGS, legs=13, leg_lw=1.2, ant=(8, 7, 1.5))
    for s in (1, -1):        # the long hairs on his middle legs, which give the bee its name
        for k in range(4):
            stroke(a, [(50 + s * (14 + k * 1.2), ty + 1 + k * 0.6), (50 + s * (15 + k * 1.2), ty + 4 + k * 0.6)], 0.5, 0.7, col="dark", smooth=False)
    return a


@view("female", "Anthocharis cardamines", main="male")
def orange_tip_female():     # no orange: a white butterfly with a grey-black wing tip and one black spot. The mossy green underside tells her from the other whites
    return S1.flutter("white", "white", 0, tips="slate", tip_cut=76, fore_marks=[("dot", 73, 30.6, 1.5, "ink")],
                      hind_marks=[("dot", 64, 58, 2.2, "sage"), ("dot", 72, 62, 2.4, "sage"), ("dot", 66, 68, 2.2, "sage"), ("dot", 76, 70, 1.9, "sage"), ("dot", 60, 64, 1.6, "sage")], body="slate")


@view("female", "Polyommatus icarus", main="male")
def common_blue_female():    # brown, dusted with blue near the body, with a row of orange spots round the edge of each wing
    edge = [("dot", 86, 30, 1.3, "orange"), ("dot", 82, 38, 1.3, "orange"), ("dot", 76, 44, 1.3, "orange")]
    hind = [("dot", 83, 60, 1.3, "orange"), ("dot", 80, 69, 1.3, "orange"), ("dot", 73, 75, 1.3, "orange"), ("dot", 64, 77, 1.3, "orange")]
    return S1.flutter("brown", "white", 1.0, fore_marks=[("patch", [(53, 45), (60, 36), (66, 40), (58, 48)], "steel")] + edge,
                      hind_marks=[("patch", [(53, 50), (62, 50), (62, 60), (54, 60)], "steel")] + hind, body="slate")


@view("female", "Lucanus cervus", main="male")
def stag_beetle_female():    # smaller, with ordinary small jaws and no antlers
    a = Art()
    hy, py, ey = beetle(a, top=26, head=(5.2, 3.6, "black"), pro=(8.6, 5.2, "black"), ely=(9.6, 19, "chestnut"), square=0.8, legs=16, leg_lw=1.5, ant=None)
    for s in (1, -1):
        stroke(a, [(50 + s * 1.4, hy - 3), (50 + s * 3, hy - 6), (50 + s * 1, hy - 6.6)], 1.2, col="chestnut", smooth=False)      # her jaws
        stroke(a, [(50 + s * 4, hy - 1), (50 + s * 10, hy - 3), (50 + s * 12.6, hy + 1.6)], 1.0, smooth=False)
        a.dot(50 + s * 12.6, hy + 1.6, 1.1, "line")
    return a


@view("female", "Libellula depressa", main="male")
def broad_bodied_chaser_female():      # golden brown where the male is powder blue, with the same yellow spots down each side
    return S1.dragon2(body="amber", thorax="brown", rings=None, broad=2.2, side_spots="yellow", wing_base="dark", eyes="brown")


@view("female", "Sympetrum striolatum", "Sympetrum sanguineum", main="male")
def darter_female():         # yellow-brown, where the male is red
    return S1.dragon2(body="straw", thorax="tan", rings="brown", broad=0.72, eyes="brown")


@view("female", "Calopteryx splendens", main="male")
def banded_demoiselle_female():        # metallic green, with clear greenish wings and no dark band
    return S1.dragon2(True, body="marrow", thorax="marrow", rings=None, wing_tint="pear", eyes="ink")


@view("female", "Calopteryx virgo", main="male")
def beautiful_demoiselle_female():     # metallic green with brown wings
    return S1.dragon2(True, body="marrow", thorax="marrow", rings=None, wing_tint="brown", eyes="ink")


# =====================================================================
# BUTTERFLIES WITH THEIR WINGS CLOSED
# =====================================================================

def closed(hind="brown", fore=None, hind_marks=(), fore_marks=(), veins=None, notch=(), hooked=False, body="dark", edge=None, flower="lilac"):
    """A butterfly at rest with its wings closed over its back, from the
    side, facing right. Most of what shows is the UNDERSIDE of the hind
    wing, with the tip of the front wing above it. The marks are
    ("dot", x, y, size, colour), ("ring", x, y, size, ring colour, middle colour)
    and ("patch", [points], colour)."""
    a = Art()
    stroke(a, [(50, 96), (52, 76), (56, 68)], 1.4, col="green")                               # a flower to sit on
    for dx, dy in ((-6, 0), (0, -3.4), (6, 0), (-3.4, 3), (3.4, 3)):
        figure(a, [ell(56 + dx, 71 + dy, 3.6, 3.0)], flower, close=0, lw=0.8)
    a.dot(56, 71, 1.8, "yellow")
    fore_g = blob([(50, 62), (52, 40), (60, 20), (72, 13), (80, 16) if not hooked else (84, 12), (79, 30), (72, 48), (60, 62)], 8)
    hind_g = blob([(44, 64), (37, 50), (40, 34), (52, 26), (66, 28), (75, 40), (74, 54) if not hooked else (79, 56), (64, 64)], 8)
    for x, y, r in notch:
        fore_g = fore_g.difference(ell(x, y, r, r, n=20)); hind_g = hind_g.difference(ell(x, y, r, r, n=20))
    for stroke_pts in ([(58, 64), (60, 72)], [(62, 63), (65, 71)], [(54, 65), (53, 72)]):       # legs
        stroke(a, stroke_pts, 0.8, smooth=False)

    def marks(sil, items):
        for m in items:
            if m[0] == "dot":
                paint(a, ell(m[1], m[2], m[3], m[3], n=20).intersection(sil), m[4])
            elif m[0] == "ring":
                paint(a, ell(m[1], m[2], m[3], m[3], n=22).intersection(sil), m[4])
                paint(a, ell(m[1], m[2], m[3] * 0.55, m[3] * 0.55, n=18).intersection(sil), m[5])
            elif m[0] == "patch":
                paint(a, blob(m[1], 6).intersection(sil), m[2])
    for g, colour, items, root in ((fore_g, fore or hind, fore_marks, (54, 58)), (hind_g, hind, hind_marks, (50, 60))):
        patches = [(g.difference(g.buffer(-1.2)), edge)] if edge else []
        sil = figure(a, [g], colour, patches, close=0)
        if veins:
            for q in list(g.exterior.coords)[::8]:
                stroke(a, [root, ((root[0] + q[0] * 4) / 5, (root[1] + q[1] * 4) / 5)], veins[1], veins[2], col=veins[0], smooth=False)
        marks(sil, items)
        paint(a, sil, None, LW)
    figure(a, [limb([(42, 66), (54, 63), (64, 60)], 3.4, 3.0)], body, close=0)
    figure(a, [ell(67, 58.6, 2.8, 2.6)], body, close=0)
    eye(a, 68, 58, 0.9, False)
    for ex, ey_ in ((80, 46), (84, 50)):
        stroke(a, [(68.6, 56.6), ((68.6 + ex) / 2 + 1, (56.6 + ey_) / 2 - 1), (ex, ey_)], 0.8)
        a.dot(ex, ey_, 1.0, "line")
    return a


@view("underside", "Aglais io", main="upperside")
def peacock_closed():        # nearly black underneath, like a dead leaf
    return closed("dark", veins=("ink", 0.5, 0.5), edge="ink")


@view("underside", "Aglais urticae", main="upperside")
def tortoiseshell_closed():  # dark brown at the base and paler buff-brown beyond
    return closed("dark", hind_marks=[("patch", [(58, 26), (68, 28), (76, 40), (75, 54), (66, 62), (60, 52), (62, 40)], "soil")],
                  fore_marks=[("patch", [(62, 30), (72, 16), (80, 17), (76, 34), (68, 44)], "tan")], veins=("ink", 0.4, 0.4), edge="dark")


@view("underside", "Vanessa atalanta", main="upperside")
def red_admiral_closed():    # mottled dark brown, with the red band and white spots of the front wing showing above
    return closed("dark", fore="black", fore_marks=[("patch", [(58, 46), (66, 34), (74, 30), (76, 36), (68, 44), (62, 52)], "red"), ("dot", 73, 21, 1.8, "white"), ("dot", 78, 24, 1.2, "white"),
                                                     ("dot", 68, 19, 1.2, "white")], hind_marks=[("dot", 50, 40, 2.4, "soil"), ("dot", 62, 36, 2.0, "brown"), ("dot", 58, 50, 2.6, "soil"), ("dot", 68, 48, 1.8, "brown")],
                  veins=("ink", 0.4, 0.4))


@view("underside", "Polygonia c-album", main="upperside")
def comma_closed():          # a ragged dead leaf, with the small white comma mark that names it
    a = closed("brown", notch=[(81, 24, 3.4), (77, 42, 2.6), (76, 48, 3.0), (70, 61, 2.6), (40, 42, 2.4), (58, 26, 2.2)], veins=("dark", 0.5, 0.5), edge="dark",
               hind_marks=[("patch", [(44, 44), (56, 34), (68, 36), (66, 44), (54, 48)], "dark")])
    stroke(a, [(57.6, 44.6), (55.4, 47), (57, 49.6), (59.6, 48.6)], 1.3, 1, col="white")
    return a


@view("underside", "Gonepteryx rhamni", main="upperside")
def brimstone_closed():      # it always rests like this: a pale green-yellow leaf with a hooked tip and a small rusty spot
    return closed("pear", hooked=True, veins=("olive", 0.5, 0.6), hind_marks=[("dot", 58, 42, 1.3, "rust")], fore_marks=[("dot", 68, 34, 1.1, "rust")], body="olive")


@view("underside", "Anthocharis cardamines", main="male")
def orange_tip_closed():     # mossy green blotches on white: both sexes, and the way to know a female from the other whites
    blot = [("patch", [(41, 48), (46, 40), (52, 44), (47, 52)], "sage"), ("patch", [(46, 34), (54, 29), (60, 34), (53, 39)], "sage"), ("patch", [(56, 44), (64, 40), (69, 46), (61, 51)], "sage"),
            ("patch", [(62, 31), (69, 33), (72, 40), (65, 38)], "sage"), ("patch", [(48, 56), (56, 53), (62, 58), (53, 62)], "sage"), ("patch", [(66, 52), (72, 50), (73, 56), (67, 58)], "sage")]
    return closed("white", hind_marks=blot, fore_marks=[("patch", [(64, 26), (72, 14), (80, 17), (77, 30), (70, 36)], "orange"), ("dot", 66, 40, 1.2, "ink")], body="slate")


@view("underside", "Celastrina argiolus", main="upperside")
def holly_blue_closed():     # silvery pale blue with small black dots and no orange: the blue seen round holly and ivy in gardens
    dots = [("dot", 46, 46, 0.8, "ink"), ("dot", 50, 39, 0.8, "ink"), ("dot", 56, 34, 0.8, "ink"), ("dot", 63, 35, 0.8, "ink"), ("dot", 68, 41, 0.8, "ink"), ("dot", 69, 49, 0.8, "ink"), ("dot", 58, 46, 0.8, "ink"), ("dot", 52, 54, 0.8, "ink")]
    return closed("water", hind_marks=dots, fore_marks=[("dot", 68, 26, 0.8, "ink"), ("dot", 72, 32, 0.8, "ink")], body="slate")


@view("underside", "Polyommatus icarus", main="male")
def common_blue_closed():    # grey-buff with black spots ringed in white and a row of orange marks along the edge
    spots_ = [("ring", x, y, 1.5, "white", "ink") for x, y in ((46, 46), (50, 38), (57, 33), (64, 35), (68, 42), (58, 44), (52, 52), (62, 52))]
    orange = [("dot", 73, 46, 1.2, "orange"), ("dot", 72, 53, 1.2, "orange"), ("dot", 67, 59, 1.2, "orange"), ("dot", 44, 56, 1.2, "orange")]
    return closed("buff", hind_marks=spots_ + orange, fore_marks=[("ring", 67, 26, 1.4, "white", "ink"), ("ring", 72, 31, 1.4, "white", "ink"), ("ring", 74, 22, 1.2, "white", "ink")], body="slate")


@view("underside", "Pieris napi", main="upperside")
def green_veined_closed():   # the veins are edged in grey-green on pale yellow: this is the side that names it
    return closed("primrose", fore="white", veins=("sage", 1.6, 0.95), fore_marks=[("patch", [(66, 24), (72, 14), (80, 17), (76, 30)], "primrose")], body="slate")


# =====================================================================
# CATERPILLARS AND CHRYSALISES
# =====================================================================

def caterpillar(body="green", head="dark", back=None, side=None, dots=(), dot_r=0.9, hoops=None, spines=None, hairs=None, horn=None, eyespots=False, fat=1.0, loop=False, segs=11, leaf="leaf"):
    """A caterpillar from the side on a stem, head to the right.
      body, head    its colours.  back  a stripe along the top.  side  a stripe along the side, low down
      dots          (how far across, colour) for a spot on every ring of the body: -1 is the back, 1 the belly
      hoops         a colour for every other ring, for a banded caterpillar (the cinnabar)
      spines        a colour for short branched spines.  hairs  a colour for long fine hairs
      horn          a colour for the hawk-moths' tail horn.  eyespots  the elephant hawk-moth's false eyes
      fat           how plump it is.  loop  arched up in the middle, as a looper walks"""
    a = Art()
    figure(a, [limb([(5, 71), (38, 67), (70, 68), (96, 63)], 3.2, 2.4)], "green", close=0, lw=0.9)
    lf = blob([(58, 68), (68, 77), (82, 82), (93, 78), (86, 71), (72, 67)], 6)
    figure(a, [lf], leaf, close=0, lw=0.9)
    stroke(a, [(60, 69), (76, 75), (90, 78.6)], 0.5, 0.5)
    w = 9.6 * fat
    pts = [(15, 62), (32, 56.5), (50, 55), (66, 56.5), (80, 61)] if not loop else [(20, 63), (30, 62), (40, 48), (50, 42), (60, 50), (68, 62), (80, 61)]
    c = curve(pts, 12)
    n = len(c) - 1

    def at(f):                                                           # a way of placing marks at a point along the body
        i = min(n - 1, max(0, int(f * n)))
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        return turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)))
    feet = (0.1, 0.34, 0.42, 0.5, 0.58) if not loop else (0.06, 0.14)
    for f in feet:                                                       # the stumpy false legs that grip the stem
        t = at(f); stroke(a, [t(0, w * 0.3), t(-0.6, w * 0.5 + 2.2)], 2.2, col=body, smooth=False); stroke(a, [t(0, w * 0.3), t(-0.6, w * 0.5 + 2.2)], 0.5, 0.4, smooth=False)
    for f in (0.84, 0.89, 0.94):                                         # the three pairs of true legs, behind the head
        t = at(f); stroke(a, [t(0, w * 0.3), t(1.2, w * 0.5 + 2.4)], 0.9, smooth=False)
    if hairs:
        for k in range(46):
            t = at(0.04 + k * 0.02); L = w * (0.75 + (k % 3) * 0.16)
            stroke(a, [t(0, -w * 0.3), t(-1.6 + (k % 5) * 0.8, -w * 0.45 - L)], 0.4, 0.75, col=hairs, smooth=False)
            if k % 2:
                stroke(a, [t(0, w * 0.2), t(-1 + (k % 4) * 0.7, w * 0.5 + L * 0.5)], 0.4, 0.6, col=hairs, smooth=False)
    if horn:
        t = at(0.03); stroke(a, [t(1, -w * 0.4), t(-2.4, -w * 0.5 - 4.6)], 1.3, col=horn, smooth=False)
    body_g = limb(pts, w * 0.84, w)
    tip = at(0.999)
    head_c = tip(w * 0.36, 0.6)
    patches = []
    if hoops:
        for k in range(segs):
            if k % 2 == 0:
                t = at((k + 0.5) / segs); h = n / segs * 0.36
                patches.append((poly(t(-h, -w), t(h, -w), t(h, w), t(-h, w)), hoops))
    if back:
        patches.append((limb([(x, y - w * 0.3) for x, y in pts], w * 0.34), back))
    if side:
        patches.append((limb([(x, y + w * 0.2) for x, y in pts], w * 0.18), side))
    sil = figure(a, [body_g], body, patches, close=0.6)
    inner = sil.buffer(-0.5)
    for k in range(1, segs):                                             # the rings of the body
        t = at(k / segs)
        stroke(a, [t(0, -w * 0.4), t(0, w * 0.4)], 0.4, 0.35, smooth=False)
    for k in range(segs):
        t = at((k + 0.5) / segs)
        for v, colour in dots:
            p = t(0, v * w * 0.4)
            if inner.contains(Point(p)):
                a.dot(p[0], p[1], dot_r, colour)
        if spines and 0 < k < segs:
            for v in (-0.48, -0.2):
                b = t(0, v * w)
                e = t(-0.6, v * w - 3.6)
                stroke(a, [b, e], 0.7, col=spines, smooth=False)
                stroke(a, [((b[0] + e[0]) / 2, (b[1] + e[1]) / 2), (e[0] + 1.6, e[1] + 1.0)], 0.5, col=spines, smooth=False)
    if eyespots:
        for f in (0.74, 0.81):
            p = at(f)(0, -w * 0.1)
            a.dot(p[0], p[1], 1.9, "buff"); a.dot(p[0], p[1], 1.2, "ink")
    figure(a, [ell(head_c[0], head_c[1], w * 0.4, w * 0.42)], head, close=0, lw=0.9)
    a.dot(head_c[0] + w * 0.16, head_c[1] - 0.6, 0.6, "white")
    return a


@view("caterpillar", "Aglais io", main="upperside")
def peacock_caterpillar():   # velvet black with fine white dots and black spines, in crowds on nettles
    return caterpillar("black", "ink", dots=[(-0.6, "white"), (0.1, "white"), (0.6, "white")], dot_r=0.55, spines="ink")


@view("caterpillar", "Aglais urticae", main="upperside")
def tortoiseshell_caterpillar():       # black and bristly, with two broken yellow lines down each side, also in crowds on nettles
    return caterpillar("black", "ink", back="yellow", side="yellow", spines="ink", dots=[(-0.75, "ink")], dot_r=1.0)


@view("caterpillar", "Vanessa atalanta", main="upperside")
def red_admiral_caterpillar():         # dark and spiny with a row of yellow patches low on each side, alone in a folded nettle leaf
    return caterpillar("dark", "ink", spines="dark", dots=[(0.55, "primrose"), (-0.4, "grey")], dot_r=1.1)


@view("caterpillar", "Polygonia c-album", main="upperside")
def comma_caterpillar():     # orange-brown and spiny with a white saddle on the hind half, like a bird dropping
    a = caterpillar("rust", "ink", spines="buff", dots=[(0.5, "ink")], dot_r=0.7)
    paint(a, limb([(17, 59.6), (30, 54.6), (44, 52.6)], 3.6), "white")
    stroke(a, [(17, 59.6), (30, 54.6), (44, 52.6)], 0.4, 0.4)
    return a


@view("caterpillar", "Vanessa cardui", main="upperside")
def painted_lady_caterpillar():        # black and spiny with a yellow line along each side, in a web on thistles
    return caterpillar("dark", "ink", side="primrose", spines="grey", dots=[(-0.3, "primrose")], dot_r=0.5)


@view("caterpillar", "Pieris brassicae", main="female")
def large_white_caterpillar():         # yellow-green with black spots and a yellow line down the back, in crowds on cabbages and nasturtiums
    return caterpillar("pear", "slate", back="yellow", dots=[(-0.2, "ink"), (0.35, "ink"), (0.7, "ink")], dot_r=0.85, hairs=None)


@view("caterpillar", "Pieris rapae", main="upperside")
def small_white_caterpillar():         # plain velvety green with a thin yellow line, alone, well hidden along a leaf rib
    return caterpillar("green", "green", back="pear", fat=0.86, dots=[(0.45, "yellow")], dot_r=0.5)


@view("caterpillar", "Anthocharis cardamines", main="male")
def orange_tip_caterpillar():          # slender, blue-green above and white along the side, lying along a seed pod of garlic mustard
    return caterpillar("sage", "sage", side="white", fat=0.7, segs=13)


@view("caterpillar", "Gonepteryx rhamni", main="upperside")
def brimstone_caterpillar():           # plain green with a pale line low on the side, along the midrib of a buckthorn leaf
    return caterpillar("green", "green", side="pale", fat=0.8, segs=12)


@view("caterpillar", "Tyria jacobaeae", main="adult")
def cinnabar_caterpillar():            # hooped in orange and black, in numbers on ragwort
    return caterpillar("carrot", "ink", hoops="ink", hairs="grey", fat=0.95)


@view("caterpillar", "Deilephila elpenor", main="adult")
def elephant_hawk_caterpillar():       # big and grey-brown, with two pairs of false eyes behind a trunk-like head, and a small horn on the tail
    return caterpillar("brown", "brown", eyespots=True, horn="dark", fat=1.25, dots=[(0.5, "dark")], dot_r=0.7)


@view("caterpillar", "Zygaena filipendulae", main="adult")
def burnet_caterpillar():              # plump, pale yellow-green with two rows of black spots
    return caterpillar("primrose", "ink", dots=[(-0.55, "ink"), (0.1, "ink")], dot_r=1.2, fat=1.1, hairs="grey", segs=10)


@view("caterpillar", "Noctua pronuba", main="adult")
def yellow_underwing_caterpillar():    # a "cutworm": a fat brown or green grub with black dashes along the back, found curled in the soil
    return caterpillar("soil", "brown", back="tan", dots=[(-0.6, "ink")], dot_r=1.0, fat=1.15)


@view("caterpillar", "Autographa gamma", main="adult")
def silver_y_caterpillar():            # green with fine white lines, walking in loops because it has too few false legs
    return caterpillar("green", "green", back="pale", side="white", fat=0.8, loop=True)


@view("caterpillar", "Cucullia verbasci", main="adult")
def mullein_caterpillar():             # far better known than the moth: whitish, with yellow bands and black spots, eating mullein and buddleia in early summer
    return caterpillar("white", "primrose", hoops="primrose", dots=[(-0.6, "ink"), (0.0, "ink"), (0.6, "ink")], dot_r=1.0, fat=1.1)


@view("caterpillar", "Cydalima perspectalis", main="adult")
def box_tree_caterpillar():            # green-yellow with black stripes, white dots and a black head, in webbing on box
    return caterpillar("pear", "ink", back="ink", side="ink", dots=[(-0.05, "white")], dot_r=0.6, fat=0.9, hairs="grey")


def chrysalis(colour="soil", kind="hang", spikes=None, shine=None, marks=None):
    """A chrysalis or pupa.  kind: "hang" head down from a twig, "girdle"
    upright against a stem held by a thread of silk, "soil" lying loose,
    "cocoon" a papery case high on a grass stem."""
    a = Art()
    if kind == "hang":
        figure(a, [limb([(14, 20), (50, 16), (88, 22)], 3.6, 2.8)], "bark", close=0, lw=0.9)
        stroke(a, [(50, 18), (50, 25)], 1.0, col="grey", smooth=False)
        g = blob([(50, 24), (56, 32), (60, 46), (58, 62), (52, 76), (50, 80), (48, 76), (42, 62), (40, 46), (44, 32)], 8)
        sil = figure(a, [g], colour, [(blob([(50, 46), (57, 52), (55, 68), (50, 76)], 6), shine)] if shine else [], close=0)
        for y in (32, 38, 44):
            stroke(a, [(45 - (y - 32) * 0.2, y), (55 + (y - 32) * 0.2, y)], 0.4, 0.4, smooth=False)
        stroke(a, [(50, 46), (45, 56), (47, 70)], 0.5, 0.5)
        if spikes:
            for s in (1, -1):
                for y in (36, 43, 50, 58):
                    stroke(a, [(50 + s * (8.6 - abs(y - 46) * 0.12), y), (50 + s * (11.6 - abs(y - 46) * 0.12), y + 1.6)], 1.0, col=spikes, smooth=False)
            for s in (1, -1):
                stroke(a, [(50 + s * 1.6, 78), (50 + s * 3, 82.6)], 1.0, col=spikes, smooth=False)
    elif kind == "girdle":
        figure(a, [limb([(40, 96), (42, 50), (46, 6)], 3.4, 2.8)], "green", close=0, lw=0.9)
        g = blob([(47, 22), (55, 34), (58, 50), (55, 66), (49, 80), (46, 66), (45, 50), (45, 34)], 8)
        sil = figure(a, [g], colour, close=0)
        stroke(a, [(40, 44), (50, 41), (58, 45)], 0.6, 0.8, col="white")                      # the silk thread round its middle
        stroke(a, [(51, 34), (54, 48), (51, 62)], 0.5, 0.5)
        if marks:
            for i in range(12):
                a.dot(48 + (i * 5) % 8, 30 + (i * 11) % 44, 0.6, marks)
        stroke(a, [(47, 22), (48, 16)], 1.2, col=colour, smooth=False)
    elif kind == "soil":
        stroke(a, [(8, 70), (92, 70)], 0.8, 0.5, col="soil", smooth=False)
        for x, r in ((16, 2.2), (30, 1.6), (72, 2.0), (86, 1.4), (58, 1.2)):
            a.dot(x, 71.6, r, "soil")
        g = blob([(24, 60), (34, 52), (52, 50), (68, 53), (78, 60), (68, 66), (50, 68), (34, 67)], 8)
        sil = figure(a, [g], colour, [(blob([(30, 57), (44, 53), (58, 53), (44, 56)], 5), shine)] if shine else [], close=0)
        for x in (58, 63, 68, 72.6):
            stroke(a, [(x, 53.6 + (x - 58) * 0.22), (x + 1, 66 - (x - 58) * 0.3)], 0.5, 0.5, smooth=False)
        stroke(a, [(26, 60), (40, 62), (54, 60)], 0.5, 0.5)
    else:                                                                # a cocoon on a grass stem
        stroke(a, [(48, 98), (50, 50), (53, 4)], 1.6, col="green")
        stroke(a, [(49, 80), (36, 62), (30, 44)], 1.0, col="green")
        g = blob([(53, 22), (57, 30), (58.6, 44), (57, 58), (53, 66), (49.6, 58), (48.6, 44), (50, 30)], 8)
        sil = figure(a, [g], colour, close=0)
        for dx in (-1.6, 1.4):
            stroke(a, [(53 + dx, 26), (53.6 + dx * 1.6, 44), (53 + dx, 62)], 0.4, 0.45)
    return a


@view("chrysalis", "Aglais io", main="upperside")
def peacock_chrysalis(): return chrysalis("sage", "hang", spikes="soil")       # grey-green or brown, hanging head down, with two horns at the head end


@view("chrysalis", "Aglais urticae", main="upperside")
def tortoiseshell_chrysalis(): return chrysalis("soil", "hang", spikes="amber", shine="amber")      # brown, often washed with gold


@view("chrysalis", "Pieris brassicae", main="female")
def large_white_chrysalis(): return chrysalis("pale", "girdle", marks="ink")   # pale green-grey speckled with black, upright on a wall or fence


@view("pupa", "Noctua pronuba", main="adult")
def yellow_underwing_pupa(): return chrysalis("chestnut", "soil", shine="rust")    # glossy red-brown, turned up when digging


@view("cocoon", "Zygaena filipendulae", main="adult")
def burnet_cocoon(): return chrysalis("primrose", "cocoon")                    # a papery yellow spindle high on a grass stem


# =====================================================================
# LADYBIRD LARVAE AND PUPAE
# =====================================================================

def lady_larva(body="slate", marks=(), dots="ink", spiky=False, legs="dark", stripe=None):
    """A ladybird larva from above: long, tapering and six-legged, like a
    tiny crocodile.  marks  ring numbers (0 is behind the head) that carry a
    coloured patch on each side, and its colour.  stripe  rings joined by one
    long patch each side (the harlequin)."""
    a = Art()
    cx = 50
    six_legs(a, cx, 34, 5, 7, 13, 1.2, angles=(-44, 6, 48), col=legs)
    rings = []
    y = 24
    widths = [5.4, 7.4, 8.2, 8.6, 8.4, 8.0, 7.4, 6.6, 5.6, 4.6, 3.4]
    for i, wd in enumerate(widths):
        h = 5.2 if i < 3 else 4.6
        rings.append((y + h / 2, wd, h)); y += h - 0.5
    parts = [ell(cx, yy, wd, h * 0.62) for yy, wd, h in rings]
    patches = []
    for i, colour in marks:
        yy, wd, h = rings[i]
        for s in (1, -1):
            patches.append((ell(cx + s * wd * 0.62, yy, wd * 0.34, h * 0.46), colour))
    if stripe:
        i0, i1, colour = stripe
        for s in (1, -1):
            patches.append((limb([(cx + s * rings[i][1] * 0.6, rings[i][0]) for i in range(i0, i1 + 1)], 3.0), colour))
    sil = figure(a, parts, body, patches, close=0.5)
    for i, (yy, wd, h) in enumerate(rings):
        if i:
            stroke(a, [(cx - wd * 0.8, yy - h * 0.5), (cx + wd * 0.8, yy - h * 0.5)], 0.4, 0.4, smooth=False)
        for s in (1, -1):
            if dots:
                a.dot(cx + s * wd * 0.26, yy, 0.6, dots)
            if spiky:
                for u in (0.3, 0.72):
                    b = (cx + s * wd * u, yy)
                    stroke(a, [b, (b[0] + s * 1.6, b[1] - 1.8)], 0.6, col="ink", smooth=False)
                stroke(a, [(cx + s * wd, yy), (cx + s * (wd + 2.2), yy - 0.6)], 0.6, col="ink", smooth=False)
    figure(a, [ell(cx, 22, 3.6, 2.8)], "dark" if body != "primrose" and body != "cream" else body, close=0, lw=0.9)
    return a


@view("larva", "Coccinella septempunctata", main="adult")
def seven_spot_larva():      # slate grey-blue with orange patches on the sides of the first and fourth rings behind the legs
    return lady_larva("slate", marks=[(0, "orange"), (3, "orange"), (6, "orange")])


@view("larva", "Harmonia axyridis", main="adult")
def harlequin_larva():       # black and very spiky, with one long orange stripe down each side
    return lady_larva("black", stripe=(3, 7, "orange"), spiky=True, dots=None)


@view("larva", "Adalia bipunctata", main="adult")
def two_spot_larva():        # dark grey with a pale orange patch in the middle and small pale marks
    return lady_larva("dark", marks=[(0, "buff"), (3, "orange")], dots="grey")


@view("larva", "Psyllobora vigintiduopunctata", main="adult")
def twenty_two_spot_larva(): # yellow with rows of black dots, like the adult. It eats mildew, not greenfly
    a = lady_larva("yellow", dots="ink", legs="dark")
    for i in range(10):
        for s in (1, -1):
            a.dot(50 + s * (5.4 - i * 0.3), 28 + i * 4.1, 0.7, "ink")
    return a


@view("larva", "Halyzia sedecimguttata", main="adult")
def orange_ladybird_larva(): # pale cream-yellow with black dots
    a = lady_larva("primrose", dots="ink", legs="slate")
    for i in range(10):
        for s in (1, -1):
            a.dot(50 + s * (5.4 - i * 0.3), 28 + i * 4.1, 0.6, "ink")
    return a


def lady_pupa(colour="orange", spots_="ink"):
    """A ladybird pupa: a hunched dome stuck to a leaf by its tail, the
    crumpled skin of the larva at its base."""
    a = Art()
    lf = blob([(8, 70), (30, 60), (60, 58), (86, 64), (94, 72), (70, 80), (36, 80)], 8)
    figure(a, [lf], "leaf", close=0, lw=0.9)
    stroke(a, [(10, 70), (50, 68), (92, 72)], 0.5, 0.5)
    figure(a, [blob([(28, 64), (32, 58), (38, 60), (40, 66), (34, 68)], 5)], "dark", close=0, lw=0.8)      # the shed skin
    for d in (-2, 0.4, 2.6):
        stroke(a, [(31 + d, 62), (29 + d * 1.4, 57.6)], 0.5, col="dark", smooth=False)
    g = blob([(36, 66), (38, 52), (48, 42), (62, 42), (72, 50), (74, 62), (66, 68), (48, 69)], 8)
    sil = figure(a, [g], colour, close=0)
    for i, x in enumerate((44, 50, 56, 62, 68)):
        stroke(a, [(x, 44 + abs(i - 2) * 2.2), (x + 1, 67)], 0.4, 0.4, smooth=False)
        for y in (50, 57):
            p = (x + 2.6, y + abs(i - 2) * 1.2)
            if sil.buffer(-1).contains(Point(p)):
                a.dot(p[0], p[1], 1.2, spots_)
    return a


@view("pupa", "Coccinella septempunctata", main="adult")
def seven_spot_pupa(): return lady_pupa("orange", "ink")


@view("pupa", "Harmonia axyridis", main="adult")
def harlequin_pupa(): return lady_pupa("carrot", "dark")


# =====================================================================
# GRUBS AND OTHER LARVAE
# =====================================================================

def grub(body="cream", head="rust", legs=True, rear=None, size=1.0, hairy=False):
    """A beetle grub curled in a C, as it lies in soil or compost.
      legs  three pairs behind the head (a chafer). A weevil grub has none
      rear  a darker hind end, where the gut shows through the skin"""
    a = Art()
    stroke(a, [(8, 82), (92, 82)], 0.8, 0.5, col="soil", smooth=False)
    for x, r in ((16, 2.4), (30, 1.4), (76, 2.0), (88, 1.5)):
        a.dot(x, 83.4, r, "soil")
    k = size
    pts = [(50 + (x - 50) * k, 52 + (y - 52) * k) for x, y in [(62, 30), (44, 26), (30, 36), (26, 52), (34, 68), (52, 74), (66, 66)]]
    w = 15 * k
    if legs:
        for f in (0.9, 1.9, 2.9):
            x, y = pts[0][0] - f * 4.4 * k, pts[0][1] + 2.4 * k + f * 0.4
            stroke(a, [(x, y), (x + 1.6 * k, y + 8.6 * k), (x + 4.4 * k, y + 11.6 * k)], 1.3, col=head, smooth=False)
    body_g = limb(pts, w * 0.8, w)
    patches = [(limb(pts[4:], w * 1.1), rear)] if rear else []
    sil = figure(a, [body_g], body, patches, close=0.8)
    c = curve(pts, 10)
    for i in range(6, len(c) - 3, 6):                                    # the folds of its skin
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)))
        stroke(a, [t(0, -w * 0.42), t(0, w * 0.42)], 0.45, 0.4, smooth=False)
        a.dot(*t(1.6, -w * 0.26), 0.5, "soil")                                                # breathing holes along the side
        if hairy:
            stroke(a, [t(0, -w * 0.46), t(-1, -w * 0.46 - 2.2)], 0.4, 0.6, col="rust", smooth=False)
    hx, hy = pts[0][0] + 5.4 * k, pts[0][1] + 2.2 * k
    figure(a, [ell(hx, hy, 5.2 * k, 5.6 * k)], head, close=0, lw=0.9)
    stroke(a, [(hx + 3.4 * k, hy + 3.6 * k), (hx + 5.6 * k, hy + 6.6 * k)], 1.2, col="dark", smooth=False)     # its jaws
    return a


@view("larva", "Melolontha melolontha", main="adult")
def cockchafer_grub(): return grub("cream", "rust", rear="grey", size=1.05)        # big, C-shaped, with long legs and a dark hind end: under lawns for three or four years


@view("larva", "Cetonia aurata", main="adult")
def rose_chafer_grub(): return grub("cream", "soil", rear="grey", size=1.0, hairy=True)      # fatter, with a small head and short legs: in compost heaps, where it does good


@view("larva", "Lucanus cervus", main="male")
def stag_beetle_grub(): return grub("cream", "orange", rear="grey", size=1.1)      # very large, with an orange head: in rotting wood underground for years


@view("larva", "Otiorhynchus sulcatus", main="adult")
def vine_weevil_grub(): return grub("cream", "soil", legs=False, size=0.72)        # small, legless and cream with a brown head: among the roots of plants in pots


def soft_larva(kind):
    """The soft, legless or slug-like larvae a gardener meets on leaves."""
    a = Art()
    lf = blob([(6, 62), (26, 46), (56, 40), (84, 46), (95, 60), (80, 74), (50, 80), (22, 76)], 8)
    figure(a, [lf], "leaf", close=0, lw=0.9)
    stroke(a, [(8, 62), (50, 60), (93, 60)], 0.6, 0.5)
    if kind == "hoverfly":       # a blind, legless maggot, pointed at the head end, pale green with a white line. It eats greenfly
        for x, y in ((70, 50), (76, 54), (72, 58), (80, 50), (66, 55)):
            figure(a, [ell(x, y, 1.9, 1.4)], "unripe", close=0, lw=0.6)                       # the greenfly it is hunting
        g = blob([(24, 66), (30, 58), (44, 54), (56, 53), (63, 56), (58, 62), (44, 66), (32, 69)], 8)
        sil = figure(a, [g], "pale", [(limb([(28, 63), (44, 58.6), (60, 56.6)], 1.6), "white")], close=0)
        for x in (34, 40, 46, 52):
            stroke(a, [(x, 56.6 - (x - 34) * 0.12), (x + 0.6, 66.6 - (x - 34) * 0.28)], 0.4, 0.4, smooth=False)
    elif kind == "lily":         # the lily beetle's grub: orange underneath, hidden under a wet black heap of its own droppings
        hole = blob([(60, 48), (70, 46), (74, 54), (66, 58), (58, 54)], 5)
        paint(a, hole, "white", 0.8)
        figure(a, [blob([(30, 62), (34, 56), (44, 58), (48, 66), (38, 68)], 6)], "carrot", close=0, lw=0.9)
        figure(a, [blob([(28, 60), (30, 50), (40, 46), (50, 52), (50, 62), (40, 66), (32, 66)], 7)], "ink", close=0, lw=0.9)
        for x, y in ((34, 52), (41, 50), (45, 57), (37, 60)):
            a.dot(x, y, 1.0, "dark")
        a.dot(47.6, 65, 1.3, "ink")
    else:                        # the rosemary beetle's grub: plump, grey-white, with dark stripes along it and a dark head
        g = blob([(28, 66), (30, 56), (42, 50), (56, 50), (66, 56), (66, 64), (54, 68), (38, 69)], 8)
        sil = figure(a, [g], "grey", [(limb([(30, 58), (46, 53), (64, 57)], 1.4), "dark"), (limb([(29, 63), (46, 58.6), (65, 61.6)], 1.4), "dark")], close=0)
        figure(a, [ell(68, 61, 3, 3.4)], "dark", close=0, lw=0.9)
        for x in (38, 46, 54, 60):
            stroke(a, [(x, 68.4), (x + 0.6, 71.4)], 0.9, col="dark", smooth=False)
    return a


@view("larva", "Episyrphus balteatus", main="adult")
def hoverfly_larva(): return soft_larva("hoverfly")


@view("larva", "Lilioceris lilii", main="adult")
def lily_beetle_larva(): return soft_larva("lily")


@view("larva", "Chrysolina americana", main="adult")
def rosemary_beetle_larva(): return soft_larva("rosemary")


@view("eggs", "Lilioceris lilii", main="adult")
def lily_beetle_eggs():      # a short row of orange-red eggs on the underside of a lily leaf
    a = Art()
    lf = blob([(6, 62), (26, 46), (56, 40), (84, 46), (95, 60), (80, 74), (50, 80), (22, 76)], 8)
    figure(a, [lf], "leaf", close=0, lw=0.9)
    stroke(a, [(8, 62), (50, 60), (93, 60)], 0.6, 0.5)
    for i in range(7):
        figure(a, [ell(34 + i * 5, 56 - i * 0.6 + (i % 2) * 1.2, 2.0, 3.0, -16)], "red", close=0, lw=0.7)
    return a


@view("nymph", "Palomena prasina", main="adult")
def green_shield_bug_nymph():          # round and wingless, green with a row of dark marks down the middle of its back
    a = Art()
    cx = 50
    six_legs(a, cx, 42, 9, 8, 14, 1.1, angles=(-44, 6, 48))
    for s in (1, -1):
        stroke(a, [(cx + s * 2.4, 27), (cx + s * 8, 18), (cx + s * 12, 9)], 0.9, col="dark")
    body = blob([(cx, 26), (cx + 6, 28), (cx + 13, 38), (cx + 16, 52), (cx + 12, 66), (cx, 73), (cx - 12, 66), (cx - 16, 52), (cx - 13, 38), (cx - 6, 28)], 8)
    sil = figure(a, [body], "unripe", [(body.difference(body.buffer(-1.4)), "dark")], close=0)
    stroke(a, [(cx - 11, 37), (cx, 40), (cx + 11, 37)], 0.6, 0.6)
    for y, r in ((48, 2.4), (55, 2.6), (62, 2.0)):
        paint(a, ell(cx, y, r * 1.5, r * 0.8), "dark")
    for s in (1, -1):
        for y in (46, 54, 62):
            a.dot(cx + s * (12.6 - abs(y - 52) * 0.2), y, 0.8, "dark")
        eye(a, cx + s * 5, 28.6, 0.9, False)
    return a


def water_nymph(damsel=False, colour="soil"):
    """A dragonfly or damselfly nymph, which lives under water for a year or
    more: wingless, with small wing buds. A damselfly's is slim, with three
    leaf-shaped tails. A dragonfly's is stout and ends in short spikes."""
    a = Art()
    cx = 50
    L = 13 if not damsel else 11
    for s in (1, -1):
        for (bx, by), (kx, ky), (fx, fy) in (((3, 34), (13, 26), (19, 16)), ((3.4, 38), (15, 40), (23, 36)), ((3.4, 42), (14, 52), (20, 64))):
            stroke(a, [(cx + s * bx, by), (cx + s * kx, ky), (cx + s * fx, fy)], 1.2 if not damsel else 0.9, col=colour, smooth=False)
            stroke(a, [(cx + s * bx, by), (cx + s * kx, ky), (cx + s * fx, fy)], 0.4, 0.4, smooth=False)
    if damsel:
        for dx in (-5, 0, 5):                                                                 # three leaf-like gills
            figure(a, [blob([(cx + dx * 0.3, 74), (cx + dx - 1.6, 82), (cx + dx * 1.4, 92), (cx + dx + 1.6, 82)], 5)], "seed", close=0, lw=0.8)
        body = limb([(cx, 30), (cx, 52), (cx, 76)], 6.4, 3.0)
    else:
        for dx in (-2, 0, 2):
            stroke(a, [(cx + dx, 78), (cx + dx * 1.4, 83.6)], 1.1, col=colour, smooth=False)
        body = blob([(cx, 30), (cx + 6, 36), (cx + 8.6, 54), (cx + 6.4, 70), (cx, 80), (cx - 6.4, 70), (cx - 8.6, 54), (cx - 6, 36)], 8)
    sil = figure(a, [body], colour, close=0)
    for y in range(48, 76, 5):
        hw = (7.6 if not damsel else 2.6) * (1 - abs(y - 54) / 60)
        stroke(a, [(cx - hw, y), (cx + hw, y)], 0.45, 0.45, smooth=False)
    for s in (1, -1):                                                                         # wing buds
        figure(a, [ell(cx + s * (2.4 if not damsel else 1.6), 44, 2.0 if not damsel else 1.3, 6.4, s * -8)], "dark", close=0, lw=0.7)
    figure(a, [ell(cx, 26, 6.4 if not damsel else 4.8, 4.2)], colour, close=0)
    for s in (1, -1):
        paint(a, ell(cx + s * (4.4 if not damsel else 3.6), 25, 2.4, 2.8), "dark", 0.6)
        stroke(a, [(cx + s * 1.4, 22.4), (cx + s * 3, 17)], 0.6, smooth=False)
    return a


@view("nymph", "Aeshna cyanea", "Aeshna mixta", "Anax imperator", main="male")
def hawker_nymph(): return water_nymph(False, "soil")


@view("nymph", "Libellula depressa", main="male")
def chaser_nymph(): return water_nymph(False, "brown")


@view("nymph", "Enallagma cyathigerum", "Coenagrion puella", "Pyrrhosoma nymphula", "Ischnura elegans", main="male")
def damselfly_nymph(): return water_nymph(True, "tan")


# =====================================================================
# FROGS, TOADS AND NEWTS: spawn and tadpoles
# =====================================================================

def pond(a):
    paint(a, blob([(4, 30), (30, 26), (70, 28), (96, 32), (96, 84), (70, 88), (30, 86), (4, 82)], 8), "water", 0, fa=0.6)
    stroke(a, [(4, 30), (30, 26), (70, 28), (96, 32)], 0.8, 0.7, col="slate")


@view("spawn", "Rana temporaria", main="adult")
def frog_spawn():            # a floating clump of clear jelly, each ball with one black dot. Toad spawn is in strings
    a = Art()
    pond(a)
    k = 0
    for row in range(5):
        for col in range(7 - abs(row - 2)):
            x = 26 + abs(row - 2) * 4 + col * 8 + (row % 2) * 2; y = 40 + row * 7.4
            paint(a, ell(x, y, 4.6, 4.2), "white", 0.6, fa=0.75)
            a.dot(x + (k % 3 - 1) * 0.8, y + (k % 2) * 0.8, 1.5, "ink"); k += 1
    return a


@view("spawn", "Bufo bufo", main="adult")
def toad_spawn():            # long strings of jelly with a double row of black eggs, wound round water plants
    a = Art()
    pond(a)
    for x in (30, 72):
        stroke(a, [(x, 86), (x + 2, 60), (x - 2, 34)], 1.6, col="green")
    line = [(10, 48), (26, 40), (40, 50), (30, 62), (46, 70), (64, 62), (74, 46), (86, 54), (90, 70)]
    paint(a, limb(line, 5.0), "white", 0.6, fa=0.75)
    c = curve(line, 10)
    for i in range(2, len(c) - 2, 2):
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)))
        a.dot(*t(0, -1.1), 0.75, "ink"); a.dot(*t(1.2, 1.1), 0.75, "ink")
    return a


def tadpole_fig(colour="dark", speck=None, legs=True):
    a = Art()
    pond(a)

    def one(x, y, k, hind):
        tail = blob([(x - 4 * k, y - 3.4 * k), (x - 16 * k, y - 5 * k), (x - 30 * k, y), (x - 16 * k, y + 5 * k), (x - 4 * k, y + 3.4 * k)], 6)
        figure(a, [tail], "seed", [(limb([(x - 2 * k, y), (x - 28 * k, y)], 3.0 * k, 0.6), colour)], close=0, lw=0.8)
        if hind:
            stroke(a, [(x - 4 * k, y + 4 * k), (x - 9 * k, y + 9 * k), (x - 5 * k, y + 12 * k)], 1.3 * k, col=colour, smooth=False)
        sil = figure(a, [ell(x + 2 * k, y, 9 * k, 6.6 * k)], colour, close=0)
        if speck:
            for i in range(8):
                p = (x - 3 * k + (i * 5) % 11 * k, y - 3 * k + (i * 3) % 6 * k)
                if sil.buffer(-0.6).contains(Point(p)):
                    a.dot(p[0], p[1], 0.5, speck)
        a.dot(x + 6.6 * k, y - 1.6 * k, 1.1 * k, "white"); a.dot(x + 6.8 * k, y - 1.6 * k, 0.6 * k, "ink")
    one(44, 46, 1.0, False)
    one(66, 68, 1.15, legs)
    return a


@view("tadpole", "Rana temporaria", main="adult")
def frog_tadpole(): return tadpole_fig("soil", speck="amber")        # brown, speckled with gold as it grows. The lower one has grown its hind legs


@view("tadpole", "Bufo bufo", main="adult")
def toad_tadpole(): return tadpole_fig("ink", legs=True)             # jet black, and swims in shoals


@view("larva", "Lissotriton vulgaris", "Lissotriton helveticus", "Triturus cristatus", main="adult")
def newt_larva():            # a newt "tadpole" is slender, with feathery gills behind its head, and grows its FRONT legs first
    a = Art()
    pond(a)
    line = [(74, 46), (58, 50), (42, 56), (26, 60), (12, 58)]
    fin = blob([(52, 46), (34, 48), (12, 54), (10, 60), (30, 66), (50, 60)], 6)
    figure(a, [fin], "seed", close=0, lw=0.8)
    for (bx, by), (ex, ey_) in (((62, 51), (66, 60)), ((60, 50), (55, 41)), ((46, 56), (49, 65)), ((45, 54), (40, 46))):
        stroke(a, [(bx, by), (ex, ey_)], 1.0, col="soil", smooth=False)
    sil = figure(a, [limb(line, 7, 1.6), ell(77, 45.4, 6, 4.6, -12)], "tan", close=1.0)
    for s in (1, -1):                                                                          # three feathery gills each side
        for k in range(3):
            t = turn(72, 46 + s * 3.4, 180 + s * (40 + k * 26))
            stroke(a, [t(0), t(7.6)], 0.9, col="berry", smooth=False)
            for u in (3, 5, 7):
                stroke(a, [t(u), t(u + 1, 1.6)], 0.4, col="berry", smooth=False); stroke(a, [t(u), t(u + 1, -1.6)], 0.4, col="berry", smooth=False)
    spots(a, sil, [(64, 48), (56, 51), (48, 54), (40, 56.6), (32, 58.6)], 0.8, "brown")
    a.dot(80, 43.4, 1.0, "ink"); a.dot(79, 47.6, 1.0, "ink")
    return a
