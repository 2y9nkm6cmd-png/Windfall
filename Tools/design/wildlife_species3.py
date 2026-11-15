"""Windfall wildlife drawings: single animals. Part 3, the next animals.

William, 15 November 2026, 20:46: "Could you also start making more drawings
for all the other animals as well." About 3,970 animals in the UK list
still showed the drawing of their kind. This file is where the next ones
go, a batch at a time. The order they are chosen in:

  1. the animals in William's own species list that still borrowed a kind's drawing;
  2. then the animals most often recorded in the UK, garden animals first.

Each uses one of the adjustable figures from parts 1 and 2 (`bird`,
`flutter`, `moth_fig`, `bumble`, `hover`, `lady`, `beetle`, `dragon2`), so
most are a single line: a correction is a change of one word or number.

Every drawing here was made beside photographs from iNaturalist and then
compared with them again (Design/Wildlife/CHECKED.md).
"""
import math
from shapely.geometry import Point
from wildlife_kit import Art, P, LW, turn, curve, ell, blob, poly, limb, mirror, band, paint, figure, stroke, eye, spots
import wildlife as W
from wildlife import sp, insect, beetle
import wildlife_species as S1
from wildlife_species import flutter, moth_fig, hover, lady, dragon2, BEE_WINGS
import wildlife_species2 as S2
from wildlife_species2 import bird, TIT, FINCH, CROW, DOVE


# =====================================================================
# 1. FROM WILLIAM'S OWN SPECIES LIST
# =====================================================================

def bumble2(th="black", th_bands=(), ab="black", bands=()):
    """A bumblebee, as `bumble` in part 1, but handing back where the
    middle of its abdomen is so that a mark can be added there."""
    a = Art()
    hy, ty, ay = insect(a, head=(4.6, 3.8, "black"), th=(9.5, 8.5, th), ab=(11.5, 13.5, ab), fuzz=0.045, th_bands=th_bands, bands=bands,
                        wings=BEE_WINGS, legs=14, leg_lw=1.3, ant=(7, 7, 1.5))
    return a, ay


@sp("Bombus humilis")
def brown_banded_carder():   # gingery all over and paler than the common carder, with one brown band near the front of the abdomen and no black hairs
    return S1.bumble(th="rust", ab="tan", bands=[(-0.58, -0.36, "brown"), (0.7, 1.1, "buff")])


@sp("Bombus soroeensis")
def broken_belted():         # one yellow collar, a yellow band on the abdomen that is broken in the middle, and a white tail tinged peach where it meets the black
    a, ay = bumble2(th_bands=[(-1, -0.3, "yellow")], bands=[(-0.66, -0.26, "yellow"), (0.4, 0.52, "skin"), (0.52, 1.1, "white")])
    paint(a, ell(50, ay - 0.46 * 13.5, 1.5, 3.2), "black")                                     # the break in the band
    return a


@sp("Bombus sylvarum")
def shrill_carder():         # pale straw-grey, with a black band across the thorax between the wings, dark bands on the abdomen and an orange tail
    return S1.bumble(th="straw", th_bands=[(-0.3, 0.4, "black")], ab="straw", bands=[(-0.34, -0.2, "dark"), (0.06, 0.2, "dark"), (0.56, 1.1, "orange")])


sp("Apis mellifera")(W.DRAW["honeybee"])
sp("Lumbricus terrestris")(W.DRAW["earthworm"])


@sp("Eisenia fetida")
def brandling():             # the compost worm: smaller than the lob worm and ringed in dark red and yellow, like a tiger's tail
    a = Art()
    line = [(16, 60), (30, 46), (46, 52), (56, 66), (72, 62), (84, 48)]
    sil = figure(a, [limb(line, 4.6, 5.4)], "primrose", close=0)
    c = curve(line, 16)
    for i in range(2, len(c) - 3, 3):                                                          # a dark red ring, then a yellow gap, all the way along
        if 48 <= i <= 62:
            continue
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)))
        paint(a, poly(t(-1.0, -5), t(1.0, -5), t(1.0, 5), t(-1.0, 5)).intersection(sil), "berry")
    figure(a, [limb(c[52:62], 6.4, 6.4, smooth=False)], "skin", close=0, lw=0.9)                # the saddle
    paint(a, sil, None, LW)
    return a


@sp("Cucullia verbasci")
def mullein_moth():          # long narrow straw-coloured wings with a dark brown streak down each edge: at rest it looks like a splinter of wood
    def marks(a, m, flip, sil):
        paint(a, limb([(m(52), 36), (m(54), 56), (m(60), 74)], 2.6, 2.6).intersection(sil), "brown")
        for y0 in (40, 50, 60):
            stroke(a, [(m(58 + (y0 - 40) * 0.4), y0), (m(62 + (y0 - 40) * 0.5), y0 + 9)], 0.5, 0.6, col="brown", smooth=False)
    a = moth_fig("straw", "brown", "tan", "brown", marks, body="soil", lines=False)
    figure(a, [blob([(47, 27), (50, 21.6), (53, 27), (50, 30)], 5)], "brown", close=0, lw=0.8)  # the pointed tuft behind its head
    return a


@sp("Sideridis rivularis")
def campion_moth():          # mottled brown, with two pale-edged marks on each wing and a pale zigzag line near the edge
    def marks(a, m, flip, sil):
        paint(a, ell(m(60), 44, 2.6, 2.2).intersection(sil), "buff")
        paint(a, ell(m(60), 44, 1.5, 1.2).intersection(sil), "dark")
        paint(a, ell(m(64), 53, 3.4, 2.6, 30 if flip else -30).intersection(sil), "buff")
        paint(a, ell(m(64), 53, 2.2, 1.5, 30 if flip else -30).intersection(sil), "dark")
        stroke(a, [(m(56), 67), (m(60), 64), (m(64), 67), (m(68), 64), (m(73), 68)], 0.7, 0.9, col="buff", smooth=False)
    return moth_fig("brown", "dark", "tan", "brown", marks, body="brown")


@sp("Zacladus geranii")
def geranium_weevil():       # tiny, round and dull black, with a short curved snout: on meadow crane's-bill flowers
    a = Art()
    hy, py, ey = beetle(a, head=(3.2, 2.8, "black"), pro=(5.8, 4.6, "black"), ely=(9.4, 11.5, "black"), snout=5, legs=11, leg_lw=1.2, ant=None, shine=False)
    for dx in (-5, -2.5, 2.5, 5):
        stroke(a, [(50 + dx, ey - 8), (50 + dx * 0.96, ey), (50 + dx * 0.7, ey + 8)], 0.5, 0.5, col="grey")
    for s in (1, -1):
        stroke(a, [(50 + s * 0.8, hy - 4.6), (50 + s * 5, hy - 7.6), (50 + s * 8, hy - 3.6)], 0.8, smooth=False)
        a.dot(50 + s * 8, hy - 3.6, 0.9, "line")
    return a


@sp("Cordulegaster boltonii")
def golden_ringed():         # black with a yellow ring round every part of the abdomen, yellow stripes on the thorax and green eyes: Britain's longest dragonfly
    return dragon2(body="ink", thorax="ink", rings="yellow", broad=0.95, thorax_stripe="yellow", eyes="marrow", ring_at=(-0.8, -0.56, -0.32, -0.08, 0.16, 0.4, 0.64))


# =====================================================================
# 2. THE MOST RECORDED: birds
# =====================================================================

@sp("Anser anser")
def greylag_goose():         # the big grey-brown goose of park lakes, with an orange bill and pink legs
    return bird(bx=42, by=58, bl=25, bd=12.5, tilt=-4, hr=5.8, hdx=8, hdy=-20, neck=[(66, 46), (64, 32)], neck_col="soil", bill=(7.6, 3.8, "duck", "orange"), tail=(8, 7, "fan"), tail_ang=198,
                tail_col="white", back="soil", belly="tan", breast="tan", rump="white", wing="brown", hood="soil", feet="swim", eye_r=0.9, bars="soil")


@sp("Aythya fuligula")
def tufted_duck():           # the drake: black with clean white sides, a yellow eye and a drooping tuft at the back of the head
    def flank(a, sil, head, t):  # the white side, painted last so that the folded wing does not hide it
        g = ell(*t(-1, 1.0), 11.5, 4.6, -3).intersection(sil).intersection(poly((0, 0), (100, 0), (100, 63.6), (0, 63.6)))
        paint(a, g, "white", 0.8)
    return bird(after=flank, bx=46, by=58, bl=22, bd=11.5, tilt=-3, hr=7.6, hdx=3, hdy=-7, neck=[(68, 47)], neck_col="black", bill=(8, 3.4, "duck", "slate"), tail=(7, 6, "fan"), tail_ang=200, tail_col="black",
                back="black", belly="white", breast="black", wing="black", feet="swim", eye_r=1.0, eye_col="yellow", hood="black", crest=(7, 140), vent="black")


@sp("Motacilla cinerea")
def grey_wagtail():          # grey above and lemon yellow below, with the longest tail of the wagtails: by streams and on wet roofs
    return bird(bx=52, by=54, bl=15, bd=9, tilt=-6, hr=6.6, bill=(5.4, 1.7, "fine", "dark"), tail=(33, 4, "square"), tail_ang=176, tail_col="ink", tail_edge="white", back="slate", belly="yellow",
                cap="slate", eyebrow="white", throat="white", wing="ink", wingbars=[(-0.2, -0.08, "white")], legs=(12, "skin"), leg_w=1.0, feet="stand", vent="yellow", rump="yellow")


@sp("Psittacula krameri")
def ring_necked_parakeet():  # bright green with a long pointed tail and a red hooked bill. The male has the thin black and pink ring round his neck
    return bird(bx=50, by=50, bl=17, bd=10, tilt=-52, hr=7.6, bill=(5, 5.6, "hook", "red"), tail=(36, 4.6, "point"), tail_ang=122, tail_col="marrow", back="green", belly="unripe", wing="green",
                collar="ink", legs=(6, "slate"), eye_col="primrose", primaries="marrow")


@sp("Linaria cannabina")
def linnet():                # the male in summer: a grey head, a chestnut back and a crimson forehead and breast
    def forehead(a, sil, head, t):
        paint(a, ell(head[0] + 3.4, head[1] - 4.6, 2.6, 1.9, 20), "berry")
    return bird(**{**FINCH, "bl": 16.5, "bd": 11}, bill=(4.6, 3.6, "cone", "slate"), back="brown", belly="cream", hood="grey", throat="cream", breast="berry", flank="buff", wing="brown",
                primaries="black", tail_col="black", tail_edge="white", vent="white", after=forehead)


@sp("Certhia familiaris")
def treecreeper():           # a brown mouse of a bird that climbs trunks, white below, with a thin curved bill and a stiff tail it props itself on
    return bird(bx=54, by=52, bl=15, bd=8.6, tilt=-72, hr=6.4, hdx=1, hdy=1, bill=(8.6, 1.7, "curve", "dark"), tail=(16, 5, "point"), tail_ang=112, back="brown", belly="white", eyebrow="cream",
                wing="brown", wingbars=[(-0.1, 0.08, "buff")], back_streaks="buff", feet="none", before=S2.trunk)


@sp("Columba oenas")
def stock_dove():            # like a small neat woodpigeon with no white anywhere: blue-grey, a green patch on the neck, a dark eye and two short black bars on the wing
    return bird(**{**DOVE, "bl": 22, "bd": 14, "chest": 1.24}, bill=(5, 2.4, "fine", "primrose"), tail=(15, 9, "round"), tail_col="grey", tail_tip="ink", back="grey", belly="grey",
                collar="marrow", wing="grey", wingbars=[(-0.14, -0.04, "ink"), (0.2, 0.3, "ink")], primaries="ink", legs=(8, "red"))


@sp("Saxicola rubicola")
def stonechat():             # the male: a black head, a white half-collar and an orange breast, upright on top of a gorse bush
    return bird(bx=45, by=54, bl=14, bd=12, tilt=-42, hr=8.2, chest=1.15, bill=(4.6, 1.9, "fine", "dark"), tail=(12, 5, "square"), tail_ang=148, tail_col="dark", back="dark", belly="buff",
                hood="ink", collar="white", breast="orange", wing="dark", wingbars=[(-0.34, -0.18, "white")], legs=(13, "dark"), leg_w=1.0, leg_at=(-1, 5), back_streaks="ink")


@sp("Spinus spinus")
def siskin():                # the male: a small streaky yellow-green finch with a black cap and bib and yellow bars on black wings. On feeders in late winter
    return bird(**{**FINCH, "bl": 14.5, "bd": 10.4, "hr": 7.6, "tail": (12, 5.6, "fork")}, bill=(4.6, 3, "cone", "seed"), back="olive", belly="cream", cap="ink", bib="ink", cheek="pear",
                breast="yellow", wing="black", wingbars=[(-0.34, -0.12, "yellow")], tail_col="black", tail_edge="yellow", streaks="dark", rump="yellow")


@sp("Turdus pilaris")
def fieldfare():             # a big winter thrush: grey head and rump, chestnut back, and an ochre breast spotted with black
    return bird(bx=46, by=52, bl=19, bd=13.4, tilt=-38, hr=8, chest=1.16, belly_h=1.1, bill=(6.5, 2.6, "fine", "amber"), tail=(18, 6, "square"), tail_ang=140, tail_col="ink", back="chestnut",
                belly="cream", breast="straw", flank="straw", hood="grey", rump="grey", spots_="ink", wing="brown", legs=(15, "dark"), leg_w=1.3, feet="stand", leg_at=(-1, 5))


@sp("Larus marinus")
def great_black_backed_gull():         # the biggest gull: black across the back and wings, a heavy bill and pale pink legs
    def spot(a, sil, head, t): a.dot(head[0] + 14.4, head[1] + 3.8, 1.0, "red")
    return bird(bx=44, by=50, bl=24, bd=12.6, tilt=-12, hr=8.4, hdy=-1, bill=(11.4, 5, "hook", "yellow"), tail=(11, 7, "square"), tail_col="white", back="white", belly="white", wing="black",
                wing_len=1.3, legs=(15, "pink"), feet="stand", leg_at=(-1, 6), eye_r=1.1, eye_col="primrose", primaries="ink", after=spot)


@sp("Larus canus")
def common_gull():           # like a small gentle herring gull: a slim greenish-yellow bill with no red spot, a dark eye and greenish legs
    return bird(bx=44, by=51, bl=21, bd=11, tilt=-12, hr=7.6, bill=(7, 2.8, "fine", "pear"), tail=(11, 6.4, "square"), tail_col="white", back="white", belly="white", wing="grey", wing_len=1.3,
                legs=(13, "pear"), feet="stand", leg_at=(-1, 6), eye_r=1.2, primaries="black")


@sp("Curruca communis")
def whitethroat():           # the male: a grey head, a clean white throat and rusty edges to the wing feathers
    return bird(bl=17, bd=10, tilt=-18, hr=7.4, bill=(5.4, 1.9, "fine", "dark"), tail=(18, 5, "square"), tail_edge="white", back="soil", belly="cream", hood="grey", throat="white", bib="white",
                wing="rust", breast="skin", legs=(10, "skin"), leg_w=1.1)


@sp("Anthus pratensis")
def meadow_pipit():          # small, streaky and olive-brown above, buff with dark streaks below, with white outer tail feathers
    return bird(bl=17, bd=10, tilt=-14, hr=7, bill=(5.4, 1.8, "fine", "dark"), tail=(16, 5, "notch"), tail_edge="white", back="soil", belly="cream", breast="buff", streaks="dark",
                back_streaks="ink", eyebrow="cream", legs=(11, "skin"), leg_w=1.0, feet="stand")


@sp("Alauda arvensis")
def skylark():               # streaky brown with a short crest it can raise, a stout bill and white outer tail feathers
    return bird(bl=18, bd=11, tilt=-16, hr=7.6, crest=(5, 205), bill=(5.4, 2.8, "cone", "seed"), tail=(15, 6, "notch"), tail_edge="white", back="soil", belly="cream", breast="buff",
                streaks="dark", back_streaks="ink", eyebrow="cream", cheek="tan", legs=(11, "skin"), feet="stand")


# =====================================================================
# 2. THE MOST RECORDED: butterflies
# =====================================================================

@sp("Lycaena phlaeas")
def small_copper():          # bright copper front wings spotted with black, and dark hind wings with a copper band along the edge
    return flutter("orange", "dark", 2.8, hind_base="dark", hind_border="orange",
                   fore_marks=[("dot", 62, 32, 1.7, "ink"), ("dot", 67, 27, 1.6, "ink"), ("dot", 73, 25, 1.6, "ink"), ("dot", 70, 34, 1.7, "ink"), ("dot", 76, 31, 1.5, "ink"), ("dot", 64, 40, 1.6, "ink"),
                               ("dot", 80, 27, 1.4, "ink")], body="dark")


@sp("Aphantopus hyperantus")
def ringlet():               # velvety dark brown with a white fringe and a few small yellow-ringed eyes
    return flutter("dark", "white", 0.9, fore_marks=[("eye", 76, 28, 1.7, "primrose", "ink"), ("eye", 73, 37, 1.7, "primrose", "ink")],
                   hind_marks=[("eye", 66, 68, 1.7, "primrose", "ink"), ("eye", 73, 64, 1.7, "primrose", "ink")], body="dark")


@sp("Ochlodes sylvanus")
def large_skipper():         # orange-brown, darker toward the edges with faint paler patches. The male has a black line across each front wing
    return flutter("orange", "brown", 4.4, fore_marks=[("patch", [(57, 43), (68, 34), (69.4, 36), (58.4, 45)], "ink"), ("dot", 78, 27, 1.6, "amber"), ("dot", 80, 33, 1.5, "amber"), ("dot", 76, 39, 1.5, "amber")],
                   hind_marks=[("dot", 66, 62, 1.8, "amber"), ("dot", 72, 60, 1.7, "amber"), ("dot", 70, 68, 1.6, "amber")], body="brown")


@sp("Thymelicus sylvestris")
def small_skipper():         # plain bright orange with a thin dark edge. The male has a fine black line on each front wing
    return flutter("orange", "dark", 1.3, fore_marks=[("patch", [(58, 43), (66, 37), (67, 38.4), (59, 44.6)], "ink")], body="brown", veins="brown")


@sp("Coenonympha pamphilus")
def small_heath():           # small and pale orange with a grey-brown edge and one small eye at the tip of the front wing
    return flutter("amber", "soil", 2.0, fore_marks=[("eye", 81, 23, 1.7, "ink", "ink")], body="brown")


@sp("Melanargia galathea")
def marbled_white():         # chequered black and white
    return flutter("white", "black", 3.4,
                   fore_marks=[("patch", [(53, 45), (60, 34), (66, 37), (58, 46)], "black"), ("patch", [(66, 28), (74, 22), (80, 26), (72, 33)], "black"), ("patch", [(70, 40), (80, 34), (84, 38), (74, 45)], "black"),
                               ("dot", 82, 21, 1.6, "white")],
                   hind_marks=[("patch", [(53, 50), (62, 49), (62, 58), (54, 60)], "black"), ("patch", [(64, 62), (76, 56), (80, 62), (70, 70)], "black"), ("dot", 72, 72, 1.4, "white"), ("dot", 79, 66, 1.3, "white")],
                   body="black")


@sp("Lasiommata megera")
def wall_brown():            # orange barred with brown, a large eye at the tip of the front wing and a row of small ones on the hind wing: it basks on walls and bare ground
    return flutter("orange", "brown", 2.4,
                   fore_marks=[("patch", [(57, 40), (68, 33), (69.4, 36), (58.4, 43)], "brown"), ("patch", [(64, 27), (70, 23), (72, 26), (66, 30)], "brown"), ("patch", [(72, 38), (82, 33), (83, 36), (73, 41)], "brown"),
                               ("eye", 80, 25.6, 3.0, "ink", "white")],
                   hind_marks=[("patch", [(53, 50), (62, 49), (61, 58), (54, 60)], "brown"), ("eye", 66, 70, 1.9, "ink", "white"), ("eye", 72.6, 66, 1.9, "ink", "white"), ("eye", 78, 60, 1.9, "ink", "white")])


# =====================================================================
# 2. THE MOST RECORDED: moths
# =====================================================================

@sp("Cydalima perspectalis")
def box_tree_moth():         # white with a broad brown border all round. Its caterpillars strip box hedges
    def marks(a, m, flip, sil):
        paint(a, sil.difference(sil.buffer(-3.4)), "brown")
        paint(a, ell(m(60), 44, 1.5, 1.2).intersection(sil), "white")
    return moth_fig("white", None, "white", "brown", marks, body="white", lines=False)


@sp("Opisthograptis luteolata")
def brimstone_moth():        # lemon yellow, with a few chestnut marks along the front edge of the wing
    def marks(a, m, flip, sil):
        for pts in ([(63, 37), (67, 43), (63.4, 44.6)], [(71, 52), (75.4, 59), (71, 59)], [(76, 64), (79, 69), (75, 70)]):
            paint(a, poly(*[(m(x), y) for x, y in pts]).intersection(sil), "rust")
        a.dot(m(62), 52, 0.8, "rust")
    return moth_fig("primrose", None, "primrose", None, marks, body="primrose")


@sp("Callimorpha dominula")
def scarlet_tiger():         # glossy black front wings with cream and yellow spots, and red hind wings marked with black: it flies by day
    def marks(a, m, flip, sil):
        for x, y, r, c in ((56, 34, 2.0, "cream"), (60, 44, 2.4, "primrose"), (55, 52, 1.9, "primrose"), (66, 55, 2.6, "cream"), (61, 64, 2.0, "cream"), (72, 68, 2.4, "cream"), (66, 73, 1.5, "cream")):
            paint(a, ell(m(x), y, r, r).intersection(sil), c)
    a = moth_fig("black", None, "red", "black", marks, body="black", lines=False)
    for s in (1, -1):
        a.dot(50 + s * 8, 74, 1.5, "ink")
    return a


@sp("Spilosoma lubricipeda")
def white_ermine():          # pure white, peppered with small black dots, like a judge's fur
    def marks(a, m, flip, sil):
        for i in range(16):
            p = (m(54 + (i * 7) % 20), 34 + (i * 11) % 40)
            if sil.buffer(-1).contains(Point(p)):
                a.dot(p[0], p[1], 0.75, "ink")
    return moth_fig("white", None, "white", None, marks, body="white", lines=False, feathery=True)


@sp("Spilosoma lutea")
def buff_ermine():           # buff, with a slanting row of black dashes across each front wing
    def marks(a, m, flip, sil):
        for k in range(4):
            a.dot(m(58 + k * 3.6), 66 - k * 3.4, 0.85, "ink")
        a.dot(m(60), 42, 0.7, "ink")
    return moth_fig("straw", None, "cream", None, marks, body="straw", lines=False, feathery=True)


@sp("Macroglossum stellatarum")
def hummingbird_hawk_moth(): # grey-brown front wings, orange hind wings, and a black and white chequered tail: it hovers at flowers by day like a hummingbird
    def marks(a, m, flip, sil):
        stroke(a, [(m(55), 44), (m(61), 42), (m(66), 46)], 0.9, 0.9, col="dark")
        stroke(a, [(m(56), 56), (m(64), 53), (m(72), 58)], 0.9, 0.9, col="dark")
    a = moth_fig("soil", None, "orange", "brown", marks, body="soil", lines=False)
    figure(a, [blob([(46, 78), (50, 74), (54, 78), (56, 86), (50, 90), (44, 86)], 6)], "ink", close=0, lw=0.9)      # the fan of its tail
    for s in (1, -1):
        a.dot(50 + s * 4, 80.6, 1.3, "white")
    return a


@sp("Phlogophora meticulosa")
def angle_shades():          # like a crumpled dead leaf: olive and pinkish brown, with a bold dark V across each wing
    def marks(a, m, flip, sil):
        paint(a, poly((m(51), 46), (m(66), 42), (m(73), 58), (m(58), 60)).intersection(sil), "brown")
        paint(a, poly((m(55), 49), (m(64), 47), (m(68), 55), (m(60), 57)).intersection(sil), "olive")
        paint(a, ell(m(70), 68, 5, 3.4, 30 if flip else -30).intersection(sil), "skin")
    return moth_fig("tan", "skin", "buff", "tan", marks, body="tan", lines=False)


@sp("Pyrausta aurata")
def mint_moth():             # tiny and reddish purple with a few gold spots: it flies by day round mint, marjoram and catmint
    def marks(a, m, flip, sil):
        paint(a, ell(m(63), 56, 2.6, 2.2).intersection(sil), "amber")
        a.dot(m(58), 46, 1.0, "amber")
    a = moth_fig("beet", "dark", "dark", None, marks, body="beet", lines=False)
    for s in (1, -1):
        paint(a, ell(50 + s * 8.6, 72, 3.4, 1.4, s * 30), "amber")                               # the gold band on the hind wing
    return a


@sp("Agrotis exclamationis")
def heart_and_dart():        # plain brown, with a dark heart-shaped blotch and a short dark dart on each front wing, and a black collar
    def marks(a, m, flip, sil):
        paint(a, blob([(m(60), 50), (m(64), 49), (m(66), 53), (m(62.6), 56), (m(59.6), 53.6)], 5).intersection(sil), "dark")
        stroke(a, [(m(56.6), 40), (m(59), 46)], 1.5, 0.95, col="dark", smooth=False)
        a.dot(m(60), 43, 1.1, "brown")
    a = moth_fig("soil", "brown", "cream", "tan", marks, body="soil")
    stroke(a, [(46.4, 28), (50, 26.6), (53.6, 28)], 1.4, 0.95, col="ink")
    return a


@sp("Phalera bucephala")
def buff_tip():              # silver-grey, with a round buff patch at the tip of each wing and a buff head: at rest it is a broken birch twig
    def marks(a, m, flip, sil):
        paint(a, ell(m(72), 70, 6, 6).intersection(sil), "straw")
        stroke(a, [(m(66), 65), (m(70), 63.4), (m(77), 66)], 0.9, 0.9, col="brown")
        stroke(a, [(m(54), 46), (m(60), 44), (m(66), 47)], 0.8, 0.8, col="brown")
    a = moth_fig("grey", "slate", "cream", "tan", marks, body="straw", lines=False)
    return a


# =====================================================================
# 2. THE MOST RECORDED: other insects
# =====================================================================

@sp("Adalia decempunctata")
def ten_spot():              # small and very variable: most often orange with ten black spots, a pale shield marked with dark, and pale legs
    m = [(s * x, y, r) for s in (1, -1) for x, y, r in ((0.3, -0.56, 2.2), (0.66, -0.2, 2.4), (0.26, -0.02, 2.6), (0.6, 0.36, 2.2), (0.24, 0.6, 2.0))]
    return lady("orange", m, pro="cream", cheeks=None, pro_marks=[(-4.2, 0.4, 0.9), (-1.6, -0.8, 0.9), (1.6, -0.8, 0.9), (4.2, 0.4, 0.9), (0, 1.6, 1.0)])


@sp("Dorcus parallelipipedus")
def lesser_stag_beetle():    # dull black all over, broad-headed, with short jaws: both sexes look like a small female stag beetle
    a = Art()
    hy, py, ey = beetle(a, top=25, head=(6.6, 4.2, "black"), pro=(9.4, 5.6, "black"), ely=(9.8, 18, "black"), square=0.85, legs=16, leg_lw=1.5, ant=None, shine=False)
    for s in (1, -1):
        stroke(a, [(50 + s * 1.6, hy - 3.6), (50 + s * 3.6, hy - 7), (50 + s * 1.2, hy - 7.4)], 1.4, col="black", smooth=False)
        stroke(a, [(50 + s * 5, hy - 1), (50 + s * 11, hy - 3), (50 + s * 13.6, hy + 1.6)], 1.0, smooth=False)
        a.dot(50 + s * 13.6, hy + 1.6, 1.1, "line")
    return a


@sp("Syritta pipiens")
def thick_legged_hoverfly(): # small, slim and dark, with pale spots down the sides and swollen hind thighs
    def thighs(a, hy, ty, ay):
        for s in (1, -1):
            figure(a, [ell(50 + s * 7.6, ty + 9, 2.2, 5.4, s * -28)], "black", close=0, lw=0.8)
            for v in (-0.5, 0.0):
                a.dot(50 + s * 2.6, ay + v * 14, 1.3, "primrose")
    return hover((5.2, 3.8, "brown"), (5.6, 6.4, "slate"), (4.4, 14, "black"), [], eyes="rust", wing=(44, 23, 4.8, "wing"), mid=False, extra=thighs)


@sp("Eupeodes corollae")
def migrant_hoverfly():      # black with three pairs of broad yellow marks, each pair nearly meeting in the middle
    return hover((6, 4.4, "amber"), (7.2, 7.2, "dark"), (7.6, 13.5, "black"), [(-0.72, -0.44, "yellow"), (-0.18, 0.1, "yellow"), (0.38, 0.62, "yellow")], eyes="rust")


@sp("Sphaerophoria scripta")
def long_hoverfly():         # very long and thin, the abdomen reaching past the wing tips, banded yellow and black
    return hover((5.4, 4, "primrose"), (6, 6.6, "dark"), (4.2, 17.5, "black"), [(-0.76, -0.56, "yellow"), (-0.36, -0.12, "yellow"), (0.1, 0.32, "yellow"), (0.56, 0.9, "orange")],
                 eyes="rust", wing=(44, 22, 5, "wing"), mid=False)


@sp("Merodon equestris")
def narcissus_bulb_fly():    # a furry hoverfly that passes for a small bumblebee: tawny thorax, black middle, orange tail. Its grub eats daffodil bulbs
    a = Art()
    insect(a, head=(6.2, 4.4, "dark"), th=(9, 8.4, "tan"), ab=(9.4, 12, "black"), eyes="bark", fuzz=0.045, bands=[(0.34, 1.1, "orange")],
           wings=[(-0.5, 44, 30, 6.6, "wing", 0.85)], legs=12, leg_lw=1.1, ant=(2.6, 2.2, 0))
    return a


def round_leaf_beetle(colour, legs=11):
    a = Art()
    hy, py, ey = beetle(a, head=(3.8, 2.8, colour), pro=(7.4, 4.4, colour), ely=(11.4, 15.5, colour), legs=legs, leg_lw=1.2, ant=(7, 8, 0))
    for dx in (-5.6, 5.6):
        stroke(a, [(50 + dx, ey - 10), (50 + dx * 0.9, ey + 9)], 0.7, 0.5, col="white")       # the shine on a polished beetle
    return a


@sp("Agelastica alni")
def alder_leaf_beetle(): return round_leaf_beetle("navy")         # shining dark blue-violet, in numbers on alder leaves


@sp("Gastrophysa viridula")
def green_dock_beetle(): return round_leaf_beetle("marrow")       # shining metallic green, on dock leaves
