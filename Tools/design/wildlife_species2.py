"""Windfall wildlife drawings: single animals. Part 2, birds, mammals, amphibians and reptiles.

See wildlife_species.py for how a drawing is tied to an animal.

The birds all come from one adjustable figure, `bird`, which takes the
colour of each part of the plumage. So a great tit and a coal tit differ
only in the words handed to it, and a correction is a change of one word.

⚠️ Every drawing here is Claude's, made on 15 November 2026 from memory of
each animal's markings. None has been checked against a field guide.
"""
import math
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from wildlife_kit import Art, P, LW, turn, curve, ell, blob, poly, limb, mirror, band, paint, figure, stroke, eye, spots
import wildlife as W
from wildlife import sp
import wildlife_species as S1


def bird(bx=44, by=56, bl=19, bd=12.5, tilt=-22, hr=8.4, hdx=0.0, hdy=0.0, neck=None, neck_col=None,
         bill=(6.5, 3.0, "cone", "dark"), tail=(19, 6.5, "square"), tail_ang=None, tail_col=None, tail_tip=None,
         legs=(11, "dark"), leg_at=(-3, 5), feet="perch",
         back="brown", belly="cream", hood=None, cap=None, cheek=None, bib=None, throat=None, breast=None, wing=None, wingbars=(), nape=None,
         rump=None, eyeline=False, eyebrow=None, streaks=None, spots_=None, bars=None, back_streaks=None, face=None, collar=None, moustache=None,
         belly_stripe=None, wing_len=1.0, eye_r=1.3, eye_col=None, eye_ring=None, extra=(), before=None, after=None):
    """A bird from the side, facing right, built from an oval body, a round
    head, a tail and a bill. Every colour word names one part of the plumage:
      back, belly, breast, rump     the body
      hood                          the whole head. cap, nape, cheek, face, throat, bib, moustache and collar are parts of it
      wing, wingbars                the folded wing, and stripes across it (from, to, colour)
      spots_, bars, streaks         dark marks on the underside.  back_streaks  dark marks on the back
      eye_col, eye_ring             a coloured eye, and a ring round it
      bill                          (length, depth, shape, colour). Shapes: cone, fine, dagger, hook, duck, curve
      tail                          (length, width, shape). Shapes: square, fork, point, fan
      feet                          perch, stand, swim or none
      before, after                 extra drawing behind the bird (a trunk) or on top of it"""
    a = Art()
    if before:
        before(a)
    t = turn(bx, by, tilt)
    body = ell(bx, by, bl, bd, tilt)
    front = t(bl * 0.72, -bd * 0.35)
    hx, hy = front[0] + hr * 0.25 + hdx, front[1] - hr * 0.62 + hdy
    head = ell(hx, hy, hr, hr * 0.94)
    rear = t(-bl * 0.84, -bd * 0.06)
    ta = (tilt + 180 - 14) if tail_ang is None else tail_ang
    tl, tw, tk = tail
    tt = turn(rear[0], rear[1], ta)
    if tk == "fork":
        tail_g = poly(tt(-3, -tw * 0.42), tt(tl, -tw * 0.62), tt(tl * 0.56, 0), tt(tl, tw * 0.62), tt(-3, tw * 0.42))
    elif tk == "point":
        tail_g = poly(tt(-3, -tw * 0.5), tt(tl * 0.6, -tw * 0.34), tt(tl, 0), tt(tl * 0.6, tw * 0.34), tt(-3, tw * 0.5))
    elif tk == "fan":
        tail_g = poly(tt(-3, -tw * 0.36), tt(tl, -tw * 0.7), tt(tl * 1.06, 0), tt(tl, tw * 0.7), tt(-3, tw * 0.36))
    else:
        tail_g = poly(tt(-3, -tw * 0.46), tt(tl, -tw * 0.5), tt(tl, tw * 0.5), tt(-3, tw * 0.46))
    lx = [bx + leg_at[0], bx + leg_at[1]]
    ground = by + bd * 0.75 + legs[0]
    if feet in ("perch", "stand"):
        for x in lx:
            top = (x, by + bd * 0.6); foot = (x + 1.2, ground)
            stroke(a, [top, foot], 1.3, col=legs[1], smooth=False)
            for dx, dy in ((3.6, 0.5), (3.0, 1.5), (-2.4, 0.6)):   # three toes forward and one back
                stroke(a, [foot, (foot[0] + dx, foot[1] + dy)], 1.0, col=legs[1], smooth=False)
        if feet == "perch":
            figure(a, [limb([(lx[0] - 24, ground + 4.4), (lx[0], ground + 2.4), (lx[1] + 24, ground + 3.4)], 3.4, 2.6)], "bark", close=0, lw=0.9)
            stroke(a, [(lx[0] - 14, ground + 3.2), (lx[0] - 6, ground + 2.6)], 0.5, 0.5, col="cream", smooth=False)
    bl_, bdp, bk, bc = bill
    b0 = (hx + hr * 0.78, hy + hr * 0.12)
    if bk == "hook":
        bill_g = blob([(b0[0] - 2, b0[1] - bdp * 0.6), (b0[0] + bl_ * 0.6, b0[1] - bdp * 0.5), (b0[0] + bl_, b0[1] + bdp * 0.25), (b0[0] + bl_ * 0.8, b0[1] + bdp * 0.9),
                       (b0[0] + bl_ * 0.5, b0[1] + bdp * 0.42), (b0[0] - 2, b0[1] + bdp * 0.5)], 6)
    elif bk == "duck":
        bill_g = blob([(b0[0] - 2, b0[1] - bdp * 0.5), (b0[0] + bl_ * 0.6, b0[1] - bdp * 0.3), (b0[0] + bl_, b0[1] + bdp * 0.1), (b0[0] + bl_ * 0.92, b0[1] + bdp * 0.6), (b0[0] - 2, b0[1] + bdp * 0.6)], 6)
    elif bk == "curve":
        bill_g = limb([(b0[0] - 2, b0[1]), (b0[0] + bl_ * 0.5, b0[1] + 0.6), (b0[0] + bl_, b0[1] + bl_ * 0.26)], bdp, 0.7)
    else:
        drop = {"cone": 0.3, "fine": 0.2, "dagger": 0.25}[bk]
        bill_g = poly((b0[0] - 2.4, b0[1] - bdp * 0.55), (b0[0] + bl_, b0[1] + bdp * drop), (b0[0] - 2.4, b0[1] + bdp * 0.6))
    figure(a, [bill_g], bc, close=0, lw=0.9)
    if bk != "curve" and bl_ > 4:
        stroke(a, [(b0[0] - 1, b0[1] + bdp * 0.1), (b0[0] + bl_ * 0.82, b0[1] + bdp * (0.25 if bk != "duck" else 0.2))], 0.45, 0.5, smooth=False)
    parts = [body, head, tail_g]
    neck_g = None
    if neck:
        neck_g = limb([front, *neck, (hx - hr * 0.2, hy + hr * 0.3)], bd * 0.95, hr * 1.2)
        parts.append(neck_g)
    patches = [(tail_g.buffer(0.2), tail_col or wing or back)]
    if tail_tip:
        patches.append((poly(tt(tl * 0.78, -tw), tt(tl * 1.2, -tw), tt(tl * 1.2, tw), tt(tl * 0.78, tw)), tail_tip))
    under = ell(t(bl * 0.12, bd * 0.62)[0], t(bl * 0.12, bd * 0.62)[1], bl * 1.02, bd * 0.72, tilt + 6)
    if neck:
        under = unary_union([under, limb([t(bl * 0.6, bd * 0.3), *[(q[0] + 2.6, q[1] + 1) for q in neck], (hx + 1, hy + hr * 0.8)], bd * 0.7, hr * 0.7)])
    patches.append((unary_union([under, ell(hx + hr * 0.3, hy + hr * 0.75, hr * 0.8, hr * 0.6)]), belly))
    if breast:
        patches.append((ell(t(bl * 0.6, bd * 0.3)[0], t(bl * 0.6, bd * 0.3)[1], bl * 0.6, bd * 0.86, tilt - 35).intersection(under.buffer(2)), breast))
    if belly_stripe:
        patches.append((ell(t(bl * 0.3, bd * 0.8)[0], t(bl * 0.3, bd * 0.8)[1], bl * 0.8, bd * 0.2, tilt + 6), belly_stripe))
    if rump:
        patches.append((ell(rear[0] + 2, rear[1] + 2, bl * 0.36, bd * 0.6, tilt), rump))
    if neck_col and neck_g is not None:
        patches.append((neck_g.buffer(0.6), neck_col))
    if hood:
        patches.append((head.buffer(0.7), hood))
    if nape:
        patches.append((ell(hx - hr * 0.75, hy + hr * 0.25, hr * 0.5, hr * 0.8), nape))
    if cap:
        patches.append((head.buffer(0.7).intersection(poly((hx - hr * 1.4, hy - hr * 1.4), (hx + hr * 1.4, hy - hr * 1.4), (hx + hr * 1.4, hy - hr * 0.22), (hx - hr * 1.4, hy + hr * 0.1))), cap))
    if collar:
        patches.append((ell(hx - hr * 0.2, hy + hr * 0.98, hr * 1.1, hr * 0.24, -14), collar))
    if cheek:
        patches.append((ell(hx + hr * 0.1, hy + hr * 0.3, hr * 0.72, hr * 0.5), cheek))
    if face:
        patches.append((ell(hx + hr * 0.52, hy + hr * 0.12, hr * 0.56, hr * 0.74), face))
    if throat:
        patches.append((ell(hx + hr * 0.36, hy + hr * 0.82, hr * 0.74, hr * 0.5), throat))
    if moustache:
        patches.append((ell(hx + hr * 0.42, hy + hr * 0.5, hr * 0.44, hr * 0.2, 20), moustache))
    if bib:
        patches.append((ell(hx + hr * 0.42, hy + hr * 0.92, hr * 0.56, hr * 0.5), bib))
    patches.extend(extra)
    sil = figure(a, parts, back, patches, close=1.6)
    for mark, kind in ((spots_, "spot"), (bars, "bar"), (streaks, "streak")):
        if not mark:
            continue
        for c in range(6):
            for r in range(3):
                p = t(bl * (0.74 - c * 0.2 - (r % 2) * 0.1), bd * (0.12 + r * 0.3))
                if not (sil.contains(Point(p)) and under.contains(Point(p))):
                    continue
                if kind == "spot":
                    a.dot(p[0], p[1], 0.75, mark)
                elif kind == "bar":
                    stroke(a, [(p[0] - 1.5, p[1] - 0.3), (p[0] + 1.5, p[1] + 0.3)], 0.8, 0.9, col=mark, smooth=False)
                else:
                    stroke(a, [p, (p[0] - 0.9, p[1] + 2.2)], 0.7, 0.8, col=mark, smooth=False)
    stroke(a, [tt(1, -tw * 0.14), tt(tl * 0.94, -tw * 0.16)], 0.45, 0.4, smooth=False)   # tail feathers
    stroke(a, [tt(1, tw * 0.14), tt(tl * 0.94, tw * 0.16)], 0.45, 0.4, smooth=False)
    wc = wing or back
    w = blob([t(bl * 0.5, -bd * 0.56), t(bl * 0.1, -bd * 0.78), t(-bl * 0.5, -bd * 0.5), t(-bl * (0.84 + 0.5 * (wing_len - 1)), -bd * 0.02 * wing_len - (wing_len - 1) * 3),
              t(-bl * 0.42, bd * 0.24), t(bl * 0.2, bd * 0.2), t(bl * 0.52, -bd * 0.1)], 8)
    wg = w.intersection(sil.buffer(3 + (wing_len - 1) * 14))
    wsil = figure(a, [wg], wc, [(band(t(-bl * 0.1, -bd * 0.2)[0], t(-bl * 0.1, -bd * 0.2)[1], bd, bl, v1, v2, tilt + 90), c) for v1, v2, c in wingbars], close=0, lw=0.9)
    tipx = -bl * (0.8 + 0.5 * (wing_len - 1))
    for k, (u0, v0) in enumerate(((0.3, 0.06), (0.26, -0.1), (0.2, -0.26))):                  # the long flight feathers
        stroke(a, [t(bl * u0, bd * v0), t(-bl * 0.25, bd * (v0 + 0.02)), t(tipx * (0.96 - k * 0.1), bd * (v0 * 0.5 - 0.04) - (wing_len - 1) * 3)], 0.45, 0.45)
    for k in range(4):                                                                         # a row of small feathers at the shoulder
        p = t(bl * (0.3 - k * 0.17), -bd * (0.46 - k * 0.02))
        stroke(a, [(p[0] + 1.6, p[1] - 0.6), (p[0], p[1] + 1.4), (p[0] - 1.8, p[1] - 0.2)], 0.4, 0.4)
    if back_streaks:
        for c in range(5):
            p = t(bl * (0.36 - c * 0.2), -bd * (0.66 - (c % 2) * 0.12))
            if sil.contains(Point(p)):
                stroke(a, [p, (p[0] - 2.2, p[1] + 0.9)], 0.8, 0.85, col=back_streaks, smooth=False)
    if eyebrow:
        stroke(a, [(hx - hr * 0.5, hy - hr * 0.34), (hx + hr * 0.2, hy - hr * 0.52), (hx + hr * 0.75, hy - hr * 0.3)], 1.3, 0.95, col=eyebrow)
    if eyeline:
        stroke(a, [(hx - hr * 0.86, hy - hr * 0.04), (hx + hr * 0.3, hy - hr * 0.14), (hx + hr * 0.88, hy + hr * 0.05)], 1.2, 0.95, col="ink" if eyeline is True else eyeline)
    ex, ey_ = hx + hr * 0.36, hy - hr * 0.16
    if eye_ring:
        a.dot(ex, ey_, eye_r * 1.55, eye_ring)
    if eye_col:
        a.dot(ex, ey_, eye_r * 1.2, eye_col); a.dot(ex, ey_, eye_r * 0.62, "ink"); a.dot(ex - 0.3, ey_ - 0.3, eye_r * 0.2, "white")
    else:
        eye(a, ex, ey_, eye_r)
    if feet == "swim":
        y = by + bd * 0.56
        figure(a, [blob([(bx - bl - 16, y), (bx - bl * 0.4, y - 1.3), (bx + bl * 0.5, y + 0.8), (bx + bl + 16, y - 0.6), (bx + bl + 12, y + 6), (bx, y + 7.6), (bx - bl - 12, y + 6)], 8)],
               "water", close=0, lw=0, shade=False)
        stroke(a, [(bx - bl - 16, y), (bx - bl * 0.4, y - 1.3), (bx + bl * 0.5, y + 0.8), (bx + bl + 16, y - 0.6)], 0.9, 0.7, col="slate")
        stroke(a, [(bx - bl - 6, y + 4.4), (bx - bl + 6, y + 3.6)], 0.7, 0.5, col="slate", smooth=False)
        stroke(a, [(bx + bl - 2, y + 4.6), (bx + bl + 9, y + 3.8)], 0.7, 0.5, col="slate", smooth=False)
    elif feet == "stand":
        stroke(a, [(lx[0] - 22, ground + 1.8), (lx[1] + 24, ground + 1.8)], 0.8, 0.5, col="soil", smooth=False)
    if after:
        after(a, sil, (hx, hy), t)
    return a


TIT = dict(bl=16.5, bd=12.5, hr=8.6, bill=(4.2, 2.6, "cone", "dark"), tail=(17, 5.6, "square"), legs=(10, "slate"))
FINCH = dict(bl=17.5, bd=12.5, hr=8.6, tail=(17, 6, "fork"), legs=(10, "skin"))
CROW = dict(bx=44, by=52, bl=23, bd=13.5, tilt=-20, hr=9.6, tail=(21, 9, "square"), legs=(15, "slate"), feet="stand", leg_at=(-2, 7))
DOVE = dict(bx=44, by=54, bl=23, bd=14.5, tilt=-20, hr=7.4, feet="stand", leg_at=(-2, 7), eye_r=1.1)


@sp("Cyanistes caeruleus")
def blue_tit(): return bird(**TIT, back="deep", belly="yellow", cap="steel", cheek="white", bib="ink", wing="steel", wingbars=[(-0.1, 0.02, "white")], eyeline=True, tail_col="steel")


@sp("Parus major")
def great_tit():
    return bird(**{**TIT, "bl": 18, "hr": 9}, back="olive", belly="yellow", hood="ink", cheek="white", belly_stripe="ink", wing="steel", wingbars=[(-0.1, 0.02, "white")], tail_col="steel")


@sp("Periparus ater")
def coal_tit(): return bird(**TIT, back="slate", belly="buff", hood="ink", cheek="white", nape="white", wing="slate", wingbars=[(-0.3, -0.2, "white"), (0.0, 0.1, "white")])


@sp("Aegithalos caudatus")
def long_tailed_tit():
    return bird(bx=52, bl=12.5, bd=10.5, hr=7.6, bill=(2.6, 2, "cone", "dark"), tail=(33, 4.4, "square"), legs=(9, "dark"), back="ink", belly="cream", breast="pink", rump="pink",
                hood="white", eyebrow="ink", wing="ink", wingbars=[(-0.5, -0.2, "pink")], tail_col="ink")


@sp("Carduelis carduelis")
def goldfinch():
    return bird(**FINCH, bill=(6.2, 4.6, "cone", "buff"), back="tan", belly="cream", breast="buff", cap="ink", cheek="white", face="red", wing="black", wingbars=[(-0.35, 0.1, "yellow")], tail_col="black")


@sp("Passer domesticus")
def house_sparrow():
    return bird(**FINCH, bill=(5.6, 4.6, "cone", "dark"), back="brown", belly="grey", cap="slate", nape="rust", cheek="cream", bib="ink", wing="brown", wingbars=[(-0.44, -0.32, "white")], back_streaks="ink")


@sp("Fringilla coelebs")
def chaffinch():
    return bird(**FINCH, bill=(5.6, 4, "cone", "slate"), back="brown", belly="skin", breast="skin", cap="slate", nape="slate", cheek="skin", throat="skin", wing="black",
                wingbars=[(-0.52, -0.34, "white"), (-0.06, 0.05, "white")], tail_col="black")


@sp("Chloris chloris")
def greenfinch():
    return bird(**{**FINCH, "bd": 13}, bill=(6, 5, "cone", "skin"), back="olive", belly="pear", wing="olive", wingbars=[(-0.16, 0.1, "yellow")], tail_col="olive", tail_tip="ink")


@sp("Pyrrhula pyrrhula")
def bullfinch():
    return bird(**{**FINCH, "bd": 13.5}, bill=(4.4, 4.6, "cone", "black"), back="grey", belly="red", breast="red", cheek="red", throat="red", cap="ink", rump="white", wing="black",
                wingbars=[(-0.42, -0.28, "white")], tail_col="black")


@sp("Erithacus rubecula")
def robin():
    return bird(bl=17, bd=13.5, tilt=-34, hr=8.8, bill=(5.6, 2.2, "fine", "dark"), tail=(16, 5.8, "square"), back="brown", belly="cream", breast="orange", face="orange", throat="orange", legs=(13, "brown"))


@sp("Turdus merula")
def blackbird():
    return bird(bl=20, bd=13, hr=8.6, bill=(7, 3, "fine", "orange"), tail=(20, 7, "square"), back="black", belly="black", wing="black", eye_ring="orange", legs=(13, "dark"), feet="stand")


@sp("Turdus philomelos", "Turdus viscivorus")
def song_thrush():
    return bird(bl=19, bd=13, tilt=-30, hr=8.4, bill=(6.5, 2.6, "fine", "dark"), tail=(17, 6.4, "square"), back="brown", belly="cream", breast="buff", spots_="brown", legs=(13, "skin"), feet="stand")


@sp("Turdus iliacus")
def redwing():
    return bird(bl=18.5, bd=12.5, tilt=-28, hr=8.2, bill=(6, 2.6, "fine", "dark"), tail=(16, 6.2, "square"), back="brown", belly="cream", streaks="brown", eyebrow="cream", legs=(12, "skin"), feet="stand",
                extra=[(ell(47, 60, 8, 4.4, -14), "rust")])


@sp("Prunella modularis")
def dunnock():
    return bird(bl=18, bd=11.5, tilt=-16, hr=7.8, bill=(5.6, 1.9, "fine", "dark"), tail=(18, 5.6, "square"), back="brown", belly="grey", hood="grey", cap="brown", breast="grey", back_streaks="ink", legs=(10, "skin"))


@sp("Nannus troglodytes")
def wren():
    return bird(bx=48, by=58, bl=13, bd=10.5, tilt=-14, hr=7.2, bill=(6.5, 1.8, "fine", "dark"), tail=(10, 5.4, "square"), tail_ang=-108, back="brown", belly="buff", eyebrow="cream",
                bars="brown", back_streaks="ink", legs=(9, "skin"))


@sp("Phylloscopus collybita", "Phylloscopus trochilus")
def chiffchaff():
    return bird(bl=18.5, bd=10.5, tilt=-12, hr=7.6, bill=(6, 1.8, "fine", "dark"), tail=(18, 5, "square"), back="olive", belly="primrose", eyebrow="primrose", eyeline="brown", legs=(10, "dark"))


@sp("Sitta europaea")
def nuthatch():
    return bird(bl=17, bd=11, tilt=-6, hr=8, bill=(9.5, 2.6, "dagger", "slate"), tail=(8, 6, "square"), back="slate", belly="buff", breast="orange", eyeline=True, throat="white", cheek="white", wing="slate", legs=(8, "skin"))


@sp("Sylvia atricapilla")
def blackcap():
    return bird(bl=18, bd=11, tilt=-14, hr=7.8, bill=(5.6, 1.9, "fine", "dark"), tail=(18, 5.4, "square"), back="grey", belly="cream", cap="ink", wing="slate", legs=(10, "slate"))


@sp("Regulus regulus")
def goldcrest():
    return bird(bx=46, bl=13.5, bd=10.5, hr=7.2, bill=(3.6, 1.5, "fine", "dark"), tail=(12, 4.6, "fork"), back="olive", belly="cream", cap="yellow", eyebrow="ink", wing="olive",
                wingbars=[(-0.2, -0.08, "white")], legs=(9, "skin"))


@sp("Corvus corone")
def carrion_crow(): return bird(**CROW, bill=(11, 5, "cone", "black"), back="black", belly="black", wing="black")


@sp("Corvus frugilegus")
def rook(): return bird(**CROW, bill=(12.5, 4.6, "cone", "grey"), back="black", belly="black", wing="black", face="grey")


@sp("Coloeus monedula")
def jackdaw(): return bird(**{**CROW, "bl": 20, "hr": 9}, bill=(7, 4, "cone", "black"), back="black", belly="black", wing="black", nape="grey", cheek="grey", eye_col="white")


@sp("Pica pica")
def magpie():
    return bird(**{**CROW, "bx": 52, "bl": 19, "bd": 12, "tail": (36, 7, "point")}, bill=(8, 4, "cone", "black"), back="black", belly="white", hood="black", breast="black", wing="steel",
                wingbars=[(-0.8, -0.34, "white")], tail_col="marrow")


@sp("Garrulus glandarius")
def jay():
    return bird(**{**CROW, "bl": 20, "bd": 12.5, "hr": 9, "legs": (13, "skin")}, bill=(7, 4, "cone", "black"), back="skin", belly="skin", throat="white", moustache="ink", rump="white", wing="black",
                wingbars=[(-0.66, -0.44, "blue"), (-0.3, -0.12, "white")], tail_col="black")


@sp("Columba palumbus")
def woodpigeon():
    return bird(**DOVE, bill=(5, 2.4, "fine", "amber"), tail=(18, 9, "square"), tail_col="slate", tail_tip="ink", back="grey", belly="grey", breast="pink", collar="white", wing="grey",
                wingbars=[(-0.62, -0.5, "white")], legs=(11, "red"), eye_col="primrose")


@sp("Columba livia")
def feral_pigeon():
    return bird(**DOVE, bill=(5, 2.4, "fine", "dark"), tail=(16, 9, "square"), tail_col="slate", tail_tip="ink", back="slate", belly="slate", breast="plum", collar="marrow", wing="grey",
                wingbars=[(-0.12, 0.0, "ink"), (0.3, 0.42, "ink")], legs=(11, "red"), eye_col="orange")


@sp("Streptopelia decaocto")
def collared_dove():
    return bird(**{**DOVE, "bl": 21, "bd": 12.5}, bill=(4.6, 2.2, "fine", "dark"), tail=(23, 8, "square"), tail_col="grey", back="buff", belly="buff", breast="skin", wing="tan", legs=(10, "red"),
                eye_col="red", extra=[(ell(57.6, 37, 1.0, 4.4, -24), "ink")])


def trunk(a):
    figure(a, [poly((74, 4), (92, 4), (90, 96), (72, 96))], "bark", close=0, lw=0.9)
    for y0, y1, x in [(10, 26, 79), (34, 50, 85), (58, 80, 80), (20, 30, 87), (70, 90, 87)]:
        stroke(a, [(x, y0), (x + 0.8, (y0 + y1) / 2), (x - 0.4, y1)], 0.6, 0.45)
    stroke(a, [(56, 70), (66, 74), (73, 70)], 1.3, col="slate", smooth=False)
    stroke(a, [(55, 60), (66, 62), (73, 58)], 1.3, col="slate", smooth=False)


@sp("Dendrocopos major")
def great_spotted_woodpecker():
    return bird(bx=52, by=52, bl=19, bd=10.5, tilt=-72, hr=7.6, hdx=1, hdy=1, bill=(9, 3, "dagger", "slate"), tail=(18, 6, "point"), tail_ang=112, back="black", belly="cream", cheek="white",
                nape="red", wing="black", wingbars=[(-0.5, -0.24, "white"), (0.3, 0.38, "white"), (0.56, 0.64, "white")], feet="none", extra=[(ell(40, 73, 5.4, 6.6), "red")], before=trunk)


@sp("Picus viridis")
def green_woodpecker():
    return bird(bl=20, bd=11.5, tilt=-38, hr=8, bill=(11, 3.4, "dagger", "slate"), tail=(13, 6, "point"), back="green", belly="pear", cap="red", face="ink", moustache="red", rump="yellow",
                wing="green", legs=(11, "slate"), feet="stand", eye_col="white")


@sp("Sturnus vulgaris")
def starling():
    def flecks(a, sil, head, t):
        for i in range(16):
            p = t(14 - (i * 7) % 30, -7 + (i * 5) % 14)
            if sil.contains(Point(p)):
                a.dot(p[0], p[1], 0.6, "cream")
    return bird(bl=19, bd=12.5, tilt=-28, hr=8, bill=(9, 3, "dagger", "yellow"), tail=(11, 6, "square"), back="black", belly="black", breast="plum", nape="marrow", wing="bark",
                legs=(13, "skin"), feet="stand", after=flecks)


@sp("Motacilla alba")
def pied_wagtail():
    return bird(bx=50, by=54, bl=15.5, bd=9.5, tilt=-8, hr=7, bill=(5.4, 1.8, "fine", "dark"), tail=(28, 4.2, "square"), tail_col="ink", back="ink", belly="white", cap="ink", face="white", cheek="white",
                bib="ink", wing="ink", wingbars=[(-0.42, -0.24, "white"), (0.0, 0.14, "white")], legs=(12, "dark"), feet="stand")


def wire(a): stroke(a, [(4, 75.6), (96, 73.4)], 1.1, 0.8, col="slate", smooth=False)


def on_wire(a, sil, head, t):
    for x in (46, 51):
        stroke(a, [(x, 67), (x + 0.6, 74.4)], 1.2, col="dark", smooth=False)


@sp("Hirundo rustica")
def swallow():
    return bird(bx=47, by=56, bl=17.5, bd=10, tilt=-30, hr=7.2, bill=(3.6, 1.8, "fine", "dark"), tail=(34, 7, "fork"), tail_ang=140, back="steel", belly="cream", face="rust", bib="rust",
                wing="steel", wing_len=1.75, feet="none", before=wire, after=on_wire)


@sp("Delichon urbicum")
def house_martin():
    return bird(bx=47, by=57, bl=16, bd=10, tilt=-30, hr=7.2, bill=(3.2, 1.7, "fine", "dark"), tail=(15, 7, "fork"), tail_ang=140, back="steel", belly="white", throat="white", rump="white",
                wing="ink", wing_len=1.6, feet="none", before=wire, after=on_wire)


@sp("Apus apus")
def swift():
    a = Art()   # in flight from below: a cigar body and two long curved wings
    wing_r = blob([(52, 46), (64, 38), (80, 36), (93, 44), (96, 54), (88, 47), (74, 46), (60, 52)], 8)
    body = blob([(50, 28), (54, 34), (55, 48), (53, 62), (50, 66), (47, 62), (45, 48), (46, 34)], 8)
    tail = poly((47.4, 62), (44, 78), (50, 70), (56, 78), (52.6, 62))
    sil = figure(a, [wing_r, mirror(wing_r), body, tail], "bark", [(ell(50, 33, 2.4, 2), "cream")], close=1.0)
    for s in (1, -1):
        stroke(a, [(50 + s * 6, 46), (50 + s * 24, 41), (50 + s * 42, 47)], 0.5, 0.45, col="cream")
        eye(a, 50 + s * 2.4, 31, 0.8, False)
    return a


@sp("Alcedo atthis")
def kingfisher():
    return bird(bx=46, by=56, bl=13.5, bd=11, tilt=-30, hr=9, bill=(15, 3.2, "dagger", "dark"), tail=(6, 6, "square"), back="blue", belly="orange", cap="steel", cheek="orange", throat="white",
                nape="white", wing="steel", legs=(6, "red"))


@sp("Anas platyrhynchos")
def mallard():
    return bird(bx=46, by=58, bl=25, bd=11.5, tilt=-3, hr=7.4, hdx=4, hdy=-9, neck=[(70, 46)], bill=(9, 3.6, "duck", "yellow"), tail=(8, 7, "fan"), tail_ang=200, tail_col="white", back="grey", belly="grey",
                breast="bark", collar="white", rump="black", wing="grey", wingbars=[(0.2, 0.42, "steel")], feet="swim", eye_r=1.1, hood="marrow", neck_col="marrow")


@sp("Cygnus olor")
def mute_swan():
    def knob(a, sil, head, t):
        hx, hy = head
        paint(a, blob([(hx + 3, hy - 1.6), (hx + 6.4, hy - 2.6), (hx + 7.4, hy + 0.4), (hx + 4, hy + 1.6)], 5), "ink", 0.7)
    return bird(bx=40, by=58, bl=26, bd=12.5, tilt=-5, hr=5.8, hdx=11, hdy=-24, neck=[(66, 47), (60, 34), (64, 24)], bill=(8.5, 3.2, "duck", "orange"), tail=(9, 7, "point"), tail_ang=196, back="white",
                belly="white", wing="white", feet="swim", eye_r=0.9, after=knob)


@sp("Branta canadensis")
def canada_goose():
    return bird(bx=42, by=58, bl=25, bd=12.5, tilt=-4, hr=5.8, hdx=8, hdy=-20, neck=[(66, 46), (64, 32)], neck_col="ink", bill=(7, 3.2, "duck", "black"), tail=(8, 7, "fan"), tail_ang=198, tail_col="ink",
                back="brown", belly="buff", breast="buff", rump="white", wing="brown", hood="ink", cheek="white", feet="swim", eye_r=0.9)


def rail(bill_col, shield_col, tip=None, body="black", flank=False, under_tail=None):
    def marks(a, sil, head, t):
        hx, hy = head
        paint(a, blob([(hx + 4.4, hy - 5), (hx + 7.6, hy - 2.4), (hx + 7, hy + 1), (hx + 4, hy + 0.4)], 6), shield_col, 0.8)
        if tip:
            a.dot(hx + 11.4, hy + 1.9, 1.3, tip)
        if flank:
            stroke(a, [t(8, 4.4), t(0, 5.4), t(-12, 3.6)], 1.3, 1, col="white")
    return bird(bx=46, by=58, bl=23, bd=12.5, tilt=-5, hr=7.4, hdx=3, hdy=-6, neck=[(68, 48)], bill=(6, 3.4, "cone", bill_col), tail=(7, 8, "fan"), tail_ang=206, tail_col=under_tail,
                back=body, belly="black", wing=body, feet="swim", eye_col="red", eye_r=1.0, after=marks)


@sp("Fulica atra")
def coot(): return rail("white", "white")


@sp("Gallinula chloropus")
def moorhen(): return rail("red", "red", tip="yellow", body="bark", flank=True, under_tail="white")


def wader_legs(colour):
    def draw(a):
        stroke(a, [(45, 56), (44, 90)], 1.4, col=colour, smooth=False)
        stroke(a, [(50, 56), (52, 90)], 1.4, col=colour, smooth=False)
        for x in (44, 52):
            stroke(a, [(x - 4, 90.6), (x, 90), (x + 5, 90.8)], 1.2, col="yellow" if colour == "black" else colour, smooth=False)
        stroke(a, [(18, 91.6), (78, 91.6)], 0.8, 0.5, col="slate", smooth=False)
    return draw


@sp("Ardea cinerea")
def grey_heron():
    def plume(a, sil, head, t):
        stroke(a, [(head[0] - 3, head[1] - 1.4), (head[0] - 10, head[1] + 1), (head[0] - 15, head[1] + 5)], 1.2, col="ink")
    return bird(bx=44, by=46, bl=17, bd=9.5, tilt=-28, hr=5.6, hdx=3, hdy=-17, neck=[(62, 34), (56, 24)], bill=(17, 3.4, "dagger", "yellow"), tail=(9, 6, "square"), tail_col="grey", back="grey",
                belly="white", wing="grey", wingbars=[(-0.8, -0.56, "black")], feet="none", eye_r=1.0, eyeline=True, eye_col="yellow", before=wader_legs("olive"), after=plume)


@sp("Egretta garzetta")
def little_egret():
    def plume(a, sil, head, t):
        stroke(a, [(head[0] - 3, head[1] - 1), (head[0] - 11, head[1] + 2), (head[0] - 15, head[1] + 7)], 0.9, col="grey")
        stroke(a, [t(-12, -3), t(-22, 2), t(-26, 8)], 0.8, col="grey")
    return bird(bx=44, by=46, bl=16, bd=9, tilt=-28, hr=5.2, hdx=3, hdy=-17, neck=[(62, 34), (56, 24)], bill=(15, 2.6, "dagger", "black"), tail=(8, 5.4, "square"), back="white", belly="white",
                wing="white", feet="none", eye_r=0.9, eye_col="yellow", before=wader_legs("black"), after=plume)


@sp("Larus argentatus")
def herring_gull():
    def spot(a, sil, head, t): a.dot(head[0] + 13, head[1] + 3.4, 0.9, "red")
    return bird(bx=44, by=50, bl=23, bd=12, tilt=-12, hr=8, hdy=-1, bill=(10, 4.2, "hook", "yellow"), tail=(11, 7, "square"), tail_col="white", back="white", belly="white", wing="grey", wing_len=1.3,
                legs=(15, "pink"), feet="stand", leg_at=(-1, 6), eye_r=1.1, eye_col="primrose", extra=[(ell(13, 49, 8, 4, -14), "black")], after=spot)


@sp("Larus fuscus")
def lesser_black_backed_gull():
    return bird(bx=44, by=50, bl=23, bd=12, tilt=-12, hr=8, hdy=-1, bill=(10, 4.2, "hook", "yellow"), tail=(11, 7, "square"), tail_col="white", back="white", belly="white", wing="slate", wing_len=1.3,
                legs=(15, "yellow"), feet="stand", leg_at=(-1, 6), eye_r=1.1, eye_col="primrose", extra=[(ell(13, 49, 8, 4, -14), "black")])


@sp("Chroicocephalus ridibundus")
def black_headed_gull():
    return bird(bx=44, by=51, bl=21, bd=11, tilt=-12, hr=7.4, bill=(8, 2.8, "fine", "red"), tail=(11, 6.4, "square"), tail_col="white", back="white", belly="white", hood="brown", wing="grey", wing_len=1.3,
                legs=(13, "red"), feet="stand", leg_at=(-1, 6), eye_ring="white", eye_r=1.0, extra=[(ell(15, 50, 8, 4, -14), "black")])


@sp("Buteo buteo")
def buzzard():
    return bird(bx=47, by=50, bl=21, bd=12, tilt=-66, hr=7.6, hdx=-1.5, hdy=1.5, bill=(5.6, 4.6, "hook", "slate"), tail=(20, 9, "square"), tail_ang=104, tail_col="tan", tail_tip="brown", back="brown",
                belly="buff", breast="brown", wing="brown", bars="brown", legs=(8, "yellow"), leg_at=(1, 6), eye_r=1.4, extra=[(ell(64.4, 22.6, 1.9, 1.6), "yellow")])


@sp("Falco tinnunculus")
def kestrel():
    return bird(bx=47, by=50, bl=19, bd=10, tilt=-66, hr=7, hdx=-1.5, hdy=1.5, bill=(5, 4.2, "hook", "slate"), tail=(25, 6.5, "square"), tail_ang=104, tail_col="slate", tail_tip="ink", back="rust",
                belly="buff", hood="slate", moustache="ink", wing="rust", spots_="ink", back_streaks="ink", legs=(8, "yellow"), leg_at=(1, 6), eye_r=1.4, eye_ring="yellow", extra=[(ell(63.4, 23.6, 1.8, 1.5), "yellow")])


@sp("Accipiter nisus")
def sparrowhawk():
    return bird(bx=47, by=50, bl=19.5, bd=10.5, tilt=-66, hr=7, hdx=-1.5, hdy=1.5, bill=(4.6, 4, "hook", "slate"), tail=(25, 6.5, "square"), tail_ang=104, tail_col="slate", tail_tip="ink", back="slate",
                belly="cream", cheek="orange", wing="slate", bars="orange", legs=(9, "yellow"), leg_at=(1, 6), eye_r=1.4, eye_col="yellow", extra=[(ell(63.4, 23.6, 1.8, 1.5), "yellow")])


@sp("Milvus milvus")
def red_kite():
    a = Art()   # in flight from below: long angled wings and a deeply forked tail
    wing_r = blob([(53, 44), (66, 36), (82, 34), (96, 30), (95, 38), (86, 46), (72, 52), (56, 54)], 8)
    body = blob([(50, 30), (54, 36), (54.6, 52), (52, 62), (48, 62), (45.4, 52), (46, 36)], 8)
    tail = poly((47, 60), (40, 84), (50, 72), (60, 84), (53, 60))
    patches = [(tail.buffer(0.4), "orange"), (body.buffer(0.4), "rust"), (ell(50, 33, 4.6, 4), "grey")]
    for s in (1, -1):
        patches += [(ell(50 + s * 34, 39, 7, 5, -s * 14), "white"), (ell(50 + s * 45, 33, 5, 5), "black")]
    sil = figure(a, [wing_r, mirror(wing_r), body, tail], "rust", patches, close=1.0)
    for s in (1, -1):
        for k in range(4):
            stroke(a, [(50 + s * (40 + k * 2), 38 + k * 1.6), (50 + s * (47 + k * 0.6), 31 + k * 1.6)], 0.5, 0.5, col="cream", smooth=False)
        stroke(a, [(50 + s * 8, 48), (50 + s * 22, 44), (50 + s * 36, 44)], 0.5, 0.45, col="ink")
    paint(a, poly((48.6, 28.6), (51.4, 28.6), (50, 25.4)), "yellow", 0.7)
    for s in (1, -1):
        eye(a, 50 + s * 2.2, 32, 0.8, False)
    return a


def owl_fig(body="tan", chest="buff", wings="brown", face="buff", eyes="ink", heart=False, streak="brown", dots=None):
    a = Art()
    figure(a, [limb([(8, 83), (50, 80), (92, 84)], 5, 3.6)], "bark", close=0, lw=0.9)
    outline = blob([(50, 20), (66, 24), (72, 40), (70, 62), (62, 78), (50, 82), (38, 78), (30, 62), (28, 40), (34, 24)], 8)
    sil = figure(a, [outline], body, [(ell(50, 62, 14, 20), chest)], close=0)
    for s in (1, -1):
        wg = blob([(50 + s * 14, 44), (50 + s * 21.5, 50), (50 + s * 21, 66), (50 + s * 15, 77), (50 + s * 12.6, 60)], 8)
        figure(a, [wg], wings, close=0, lw=0.9)
        for y in (54, 60, 66):
            stroke(a, [(50 + s * 14.6, y), (50 + s * 19.6, y + 3)], 0.45, 0.5, col="cream", smooth=False)
        if dots:
            for k in range(4):
                a.dot(50 + s * (15.6 + (k % 2) * 3), 50 + k * 6, 0.8, dots)
    if streak:
        for x, y in [(44, 52), (50, 54), (56, 52), (41, 60), (47, 62), (53, 62), (59, 60), (44, 69), (50, 71), (56, 69)]:
            stroke(a, [(x, y), (x, y + 3.4)], 0.9, 0.7, col=streak, smooth=False)
    if heart:
        figure(a, [blob([(50, 22), (61, 23), (66, 33), (60, 43), (50, 48), (40, 43), (34, 33), (39, 23)], 8)], face, close=0, lw=0.9)
        stroke(a, [(50, 26), (50, 38)], 0.6, 0.5, smooth=False)
    for s in (1, -1):
        if not heart:
            figure(a, [ell(50 + s * 8.4, 35, 9.4, 10)], face, close=0, lw=0.9)
        if eyes == "yellow":
            a.dot(50 + s * 7.4, 35, 3.8, "yellow"); a.dot(50 + s * 7.4, 35, 2.0, "ink")
        else:
            a.dot(50 + s * (6.4 if heart else 7.4), 35, 2.6 if heart else 3.6, "ink")
        a.dot(50 + s * (6.4 if heart else 7.4) - 1, 33.8, 0.9, "white")
        for dx in (-4, 0, 4):
            stroke(a, [(50 + s * 9 + dx - 1.6, 83.4), (50 + s * 9 + dx, 79.4)], 1.3, col="amber", smooth=False)
    paint(a, poly((47.8, 38.5), (52.2, 38.5), (50, 45)), "amber", 0.8)
    return a


@sp("Strix aluco")
def tawny_owl(): return owl_fig()


@sp("Tyto alba")
def barn_owl(): return owl_fig(body="amber", chest="white", wings="tan", face="white", heart=True, streak=None, dots="grey")


@sp("Athene noctua")
def little_owl(): return owl_fig(body="brown", chest="cream", wings="brown", face="tan", eyes="yellow", dots="cream")


@sp("Phasianus colchicus")
def pheasant():
    return bird(bx=52, by=56, bl=20, bd=12, tilt=-8, hr=6.4, hdx=2, hdy=-8, neck=[(70, 46)], neck_col="marrow", bill=(4.4, 3, "cone", "buff"), tail=(36, 6.5, "point"), tail_ang=186, tail_col="tan",
                back="rust", belly="rust", hood="marrow", face="red", collar="white", wing="tan", spots_="ink", back_streaks="ink", legs=(12, "slate"), feet="stand", leg_at=(-2, 6), eye_r=1.0)


# =====================================================================
# MAMMALS
# =====================================================================

def fur(a, sil, colour, n=16, seed=3, lw=0.5, la=0.55, slant=(-2.2, 1.4)):
    """Short strokes of fur, scattered inside an outline."""
    x0, y0, x1, y1 = sil.bounds
    for i in range(n * 3):
        x = x0 + ((i * 37 + seed * 11) % 97) / 97 * (x1 - x0); y = y0 + ((i * 53 + seed * 7) % 89) / 89 * (y1 - y0)
        if sil.buffer(-2).contains(Point(x, y)):
            stroke(a, [(x, y), (x + slant[0], y + slant[1])], lw, la, col=colour, smooth=False)


def ground(a, y, x0=10, x1=92): stroke(a, [(x0, y), (x1, y)], 0.8, 0.5, col="soil", smooth=False)


def whiskers(a, x, y, n=3, L=9):
    for k in range(n):
        stroke(a, [(x, y), (x + L, y - 2.4 + k * 2.6)], 0.4, 0.5, smooth=False)


@sp("Vulpes vulpes")
def fox():
    a = Art()
    W.four_legs(a, [35, 61], 56, 79, 3.6, "rust", "black", far=True)
    brush = limb([(26, 52), (15, 57), (8, 66), (6, 75)], 7, 12)
    bsil = figure(a, [brush], "orange", [(ell(6.4, 77, 7.6, 7), "white")], close=0)
    fur(a, bsil, "rust", 8, 5)
    body = ell(46, 51, 22, 9.5, -2)
    neck = limb([(62, 48), (70, 40)], 11, 9)
    head = blob([(66, 30), (75, 30), (82, 37), (93, 42.6), (84, 46), (72, 46), (65, 40)], 8)
    for x in (68, 74.5):
        figure(a, [poly((x - 3.4, 32), (x + 0.4, 18.5), (x + 3.6, 32))], "black", [(poly((x - 1.6, 31), (x + 0.4, 24.5), (x + 2, 31)), "cream")], close=0, lw=0.9)
    sil = figure(a, [body, neck, head], "orange", [(blob([(60, 46), (70, 44), (84, 43.6), (91, 44), (84, 47), (70, 50), (66, 60), (58, 60)], 8), "white"), (ell(46, 60, 18, 3), "cream")], close=2.2)
    fur(a, sil, "rust", 12, 2)
    W.four_legs(a, [39, 65], 56, 80, 3.8, "orange", "black")
    a.dot(77.4, 36.6, 1.5, "amber"); a.dot(77.6, 36.6, 0.8, "ink")
    a.dot(93, 42.8, 1.5, "ink")
    whiskers(a, 87, 44.6, 2, 7)
    ground(a, 82.4)
    return a


@sp("Felis catus")
def cat():
    a = Art()   # a tabby, sitting upright: round head, short face, thin tail
    tail = limb([(40, 78), (24, 80), (14, 74), (12, 64)], 4.6, 3.2)
    tsil = figure(a, [tail], "grey", [(band(20, 72, 14, 14, v, v + 0.16, 40), "slate") for v in (-0.9, -0.5, -0.1, 0.3, 0.7)], close=0)
    body = blob([(44, 46), (56, 42), (66, 52), (67, 70), (60, 80), (42, 80), (36, 66)], 8)
    head = ell(62, 33, 10.5, 9.4)
    for x, s in ((55, -1), (68, 1)):
        figure(a, [poly((x - 4, 28), (x + s * 1.6, 15.5), (x + 4, 28))], "grey", [(poly((x - 1.8, 27), (x + s * 1.2, 20), (x + 2, 27)), "skin")], close=0, lw=0.9)
    sil = figure(a, [body, head, limb([(46, 74), (60, 79), (68, 80)], 6.4, 5)], "grey", [(ell(63, 62, 5.4, 14), "white"), (ell(66, 38, 5.6, 4), "white")], close=2.4)
    for k, (x0, y0, x1, y1) in enumerate([(40, 60, 47, 55), (38, 67, 46, 63), (41, 74, 48, 70), (48, 48, 53, 44), (56, 26, 57.6, 30.6), (61, 24.4, 61.4, 29.6), (66, 25.4, 65, 30)]):
        stroke(a, [(x0, y0), (x1, y1)], 1.5, 0.95, col="slate", smooth=False)                  # tabby stripes
    figure(a, [limb([(60, 58), (62, 74), (66, 79)], 5, 4.4)], "grey", close=0, lw=0.9)
    for dx in (-3.6, 4):
        a.dot(63 + dx, 32, 1.9, "pear"); paint(a, ell(63 + dx, 32, 0.6, 1.6), "ink")
    paint(a, poly((62, 36), (64.6, 36), (63.3, 37.8)), "skin", 0.6)
    whiskers(a, 67, 38, 3, 10)
    for k in range(3):
        stroke(a, [(59.6, 38), (50, 35.6 + k * 2.6)], 0.4, 0.5, smooth=False)
    ground(a, 81.4)
    return a


sp("Meles meles")(W.DRAW["badger"])
sp("Erinaceus europaeus")(W.DRAW["hedgehog"])
sp("Oryctolagus cuniculus")(W.DRAW["rabbit"])
sp("Pipistrellus pipistrellus", "Pipistrellus pygmaeus")(W.DRAW["bat"])
sp("Halichoerus grypus", "Phoca vitulina")(W.DRAW["seal"])
sp("Tursiops truncatus", "Delphinus delphis", "Phocoena phocoena")(W.DRAW["whale"])


def long_low(colour, belly, tail_w=(7, 2), tail_tip=None, length=1.0, ear=2.6):
    """An otter or a stoat: a long low body on short legs, facing right."""
    a = Art()
    tail = limb([(22, 60), (12, 64), (5, 72)], tail_w[0], tail_w[1])
    figure(a, [tail], colour, [(ell(5, 73, 5, 5), tail_tip)] if tail_tip else [], close=0)
    for x in (30, 60):
        figure(a, [limb([(x, 62), (x + 1, 72), (x + 5, 74)], 5.4, 4)], colour, close=0, lw=0.9, shade=False)
    body = blob([(20, 60), (30, 50), (50, 48), (64, 50), (72, 44), (76, 40), (86, 40), (92, 46.6), (88, 52), (78, 54), (70, 64), (48, 68), (28, 67)], 8)
    figure(a, [ell(77, 39, ear, ear)], colour, close=0, lw=0.9)
    sil = figure(a, [body], colour, [(blob([(40, 68), (60, 65), (72, 58), (80, 53), (90, 50), (88, 53), (78, 56), (70, 66), (48, 70)], 8), belly)], close=0)
    fur(a, sil, "bark", 10, 4)
    for x in (36, 66):
        figure(a, [limb([(x, 62), (x + 1, 73), (x + 5, 75)], 5.6, 4.2)], colour, close=0, lw=0.9)
    eye(a, 84, 43.6, 1.3)
    a.dot(92, 46.8, 1.4, "ink")
    whiskers(a, 88, 49, 3, 8)
    ground(a, 77)
    return a


@sp("Lutra lutra")
def otter(): return long_low("brown", "buff", (8, 2.4))


@sp("Mustela erminea", "Mustela nivalis")
def stoat(): return long_low("tan", "white", (4, 2.6), tail_tip="ink", ear=3)


def rodent(colour="tan", belly="cream", ear=(6.4, 7), eye_r=1.7, tail=(3.2, 1.4, "skin"), tail_pts=None, snout=0.0, blunt=0.0, body=(21, 12.5), feet="skin"):
    """A mouse, rat, vole or shrew, from the side, facing right.
      snout   how much longer and more pointed the nose is (a shrew)
      blunt   how much rounder and shorter the face is (a vole)"""
    a = Art()
    figure(a, [limb(tail_pts or [(27, 63), (13, 68), (8, 56), (15, 45), (25, 41)], tail[0], tail[1])], tail[2], close=0, lw=0.9)
    for x in (40, 60):
        figure(a, [limb([(x, 68), (x + 2, 74), (x + 6, 75)], 4, 3)], feet, close=0, lw=0.8)
    b = ell(44, 60, body[0], body[1], 4)
    nose = 89 + snout * 6 - blunt * 7
    head = blob([(58, 50 - blunt * 2), (70, 49 - blunt * 2), (82 - blunt * 3, 57), (nose, 63.6), (84 - blunt * 3, 68), (70, 70), (60, 68)], 8)
    figure(a, [ell(66.5, 46.6 + blunt * 2, ear[0], ear[1])], colour, [(ell(67, 47 + blunt * 2, ear[0] * 0.62, ear[1] * 0.66), "skin")], close=0)
    sil = figure(a, [b, head], colour, [(ell(50, 71, 30, 6.4), belly)], close=2.4)
    fur(a, sil, "bark", 10, 6)
    eye(a, 76.6 - blunt * 2, 57.6, eye_r)
    a.dot(nose, 63.8, 1.4, "skin")
    whiskers(a, nose - 4, 64.4, 3, 9)
    ground(a, 76.6)
    return a


@sp("Apodemus sylvaticus", "Mus musculus", "Apodemus flavicollis")
def wood_mouse(): return rodent()


@sp("Rattus norvegicus")
def brown_rat(): return rodent("brown", "grey", ear=(4.6, 5), eye_r=1.4, tail=(4.6, 1.8, "skin"), tail_pts=[(24, 64), (12, 70), (5, 66), (4, 58)], body=(24, 13.5))


@sp("Clethrionomys glareolus", "Microtus agrestis")
def vole(): return rodent("bark", "buff", ear=(3.4, 3.4), eye_r=1.3, tail=(2.4, 1.4, "bark"), tail_pts=[(26, 64), (18, 67), (13, 66)], blunt=1.0, body=(20, 13.5))


@sp("Sorex araneus", "Sorex minutus")
def shrew(): return rodent("dark", "grey", ear=(2.2, 2.2), eye_r=0.8, tail=(2.2, 1.2, "dark"), tail_pts=[(27, 63), (17, 67), (10, 66)], snout=1.0, body=(18, 10.5))


@sp("Talpa europaea")
def mole():
    a = Art()
    hill = blob([(8, 78), (20, 70), (32, 76), (40, 78)], 6)
    figure(a, [hill], "soil", close=0, lw=0.9)
    figure(a, [limb([(24, 62), (17, 64)], 3, 1.6)], "skin", close=0, lw=0.8)
    body = blob([(22, 62), (30, 50), (48, 46), (66, 50), (76, 58), (88, 63), (78, 68), (66, 72), (40, 73), (26, 70)], 8)
    sil = figure(a, [body], "black", close=0)
    fur(a, sil, "grey", 12, 3, la=0.4)
    for x, y, ang in ((66, 70, 30), (38, 72, 150)):   # big pink digging hands
        t = turn(x, y, ang)
        figure(a, [blob([t(0, -3.4), t(7, -4.6), t(10, 0), t(7, 4.6), t(0, 3.4)], 6)], "skin", close=0, lw=0.9)
        for d in (-2.6, 0, 2.6):
            stroke(a, [t(8.6, d), t(12, d * 1.3)], 0.9, smooth=False)
    figure(a, [limb([(84, 62.6), (92, 64)], 4.4, 2.4)], "skin", close=0, lw=0.9)
    a.dot(79.6, 59.6, 0.6, "grey")
    ground(a, 78.6, 36)
    return a


def squirrel_fig(colour, belly, tufts=False, tail_col=None):
    a = Art()
    tail = blob([(42, 80), (26, 76), (14, 58), (16, 36), (30, 20), (45, 18), (53, 27), (47, 36), (40, 44), (38, 60)], 8)   # a full bushy tail, curled up behind
    tsil = figure(a, [tail], tail_col or colour, close=0)
    fur(a, tsil, "white" if colour == "grey" else "amber", 26, 9, 0.7, 0.6, (-3, -2.4))
    body = blob([(46, 48), (58, 44), (66, 54), (66, 70), (58, 80), (42, 80), (38, 66)], 8)
    head = blob([(54, 32), (64, 28), (74, 33), (79, 40.6), (72, 46), (60, 46)], 8)
    for x, y in [(61, 25), (67, 26)]:
        figure(a, [blob([(x - 2.6, y + 5), (x, y - (8 if tufts else 4)), (x + 2.8, y + 5)], 6)], colour, close=0, lw=0.9)
    sil = figure(a, [body, head, limb([(46, 72), (60, 79), (68, 80)], 7, 5)], colour, [(ell(62, 62, 6.4, 15), belly), (ell(72, 44, 6, 3), belly)], close=2.2)
    fur(a, sil, "bark" if colour != "grey" else "slate", 9, 8)
    figure(a, [limb([(56, 54), (66, 58), (71, 54)], 4, 3)], colour, close=0, lw=0.9)
    figure(a, [ell(73.4, 51.6, 3, 3.6, 20)], "bark", close=0, lw=0.8)
    eye(a, 69.4, 35.6, 1.7)
    a.dot(79, 40.6, 1.2, "ink")
    whiskers(a, 76, 42, 2, 7)
    ground(a, 81.4, 18, 88)
    return a


@sp("Sciurus carolinensis")
def grey_squirrel(): return squirrel_fig("grey", "white")


@sp("Sciurus vulgaris")
def red_squirrel(): return squirrel_fig("rust", "cream", tufts=True, tail_col="orange")


@sp("Lepus europaeus", "Lepus timidus")
def brown_hare():
    a = Art()   # taller and rangier than a rabbit, with long black-tipped ears
    for x, y, ang in [(64, 17, -10), (71, 18, 10)]:
        figure(a, [ell(x, y, 3.4, 16, ang)], "tan", [(ell(x + 0.4, y + 1, 1.5, 12, ang), "skin"), (ell(x - ang * 0.26, y - 13, 4, 4), "ink")], close=0)
    figure(a, [ell(24, 62, 4.6, 4.4)], "white", [(ell(24, 60, 4.6, 2.4), "ink")], close=0)
    body = blob([(26, 60), (36, 46), (52, 42), (64, 50), (66, 66), (60, 76), (38, 76), (27, 70)], 8)
    head = blob([(58, 36), (68, 31), (79, 36), (84, 45), (77, 51), (64, 50)], 8)
    sil = figure(a, [body, head, limb([(34, 72), (44, 80), (58, 82)], 6, 4.6), limb([(60, 60), (63, 76), (69, 82)], 4.6, 3.6)], "tan", [(ell(62, 68, 5, 10), "cream")], close=2.4)
    fur(a, sil, "brown", 14, 5)
    stroke(a, [(38, 62), (46, 54), (55, 60), (53, 72)], 0.7, 0.5)
    a.dot(73.6, 39.6, 2.1, "amber"); a.dot(73.8, 39.6, 1.1, "ink")
    a.dot(84, 44.4, 1.3, "skin")
    whiskers(a, 81, 47, 3, 9)
    ground(a, 84, 12, 88)
    return a


def deer_fig(colour="tan", legs="bark", antlers="roe", dappled=False, rump="white", size=1.0, tail=None):
    a = Art()
    W.four_legs(a, [35, 61], 52, 86, 3.8, legs, far=True)
    body = ell(46, 47, 21 * size, 10 * size, -3)
    neck = limb([(60, 44), (67, 32), (70, 24)], 10 * size, 6)
    head = blob([(66, 17), (72, 16), (78, 21), (85, 25.6), (80, 29), (70, 28), (66, 24)], 8)
    for x, ang in [(66.4, -28), (70.4, 6)]:
        figure(a, [ell(x - 1.6, 13, 2.2, 5, ang - 20)], colour, close=0, lw=0.9)
    for x in (68, 71):
        if antlers == "roe":
            stroke(a, [(x, 16), (x - 1, 7), (x - 3, 2)], 1.3, col="bark")
            stroke(a, [(x - 0.8, 9), (x + 2.6, 5)], 1.2, col="bark", smooth=False)
        elif antlers == "red":
            d = x - 68
            stroke(a, [(x, 16), (x - 5 + d, 6), (x - 3 + d * 2, -4 + 6)], 1.4, col="bark")
            for y0, dx in ((12, 5), (8, 6), (5, 4)):
                stroke(a, [(x - 3 + d, y0), (x + dx - 2 + d, y0 - 5)], 1.2, col="bark", smooth=False)
        elif antlers == "palm":
            d = x - 68
            stroke(a, [(x, 16), (x - 3 + d, 9)], 1.4, col="bark", smooth=False)
            figure(a, [blob([(x - 5 + d, 10), (x - 7 + d, 2), (x - 3 + d, 0.6), (x + 2 + d, 3), (x + d, 9)], 6)], "seed", close=0, lw=0.9)
    patches = [(ell(46, 57, 20, 4), "buff")]
    if rump:
        patches.insert(0, (ell(27, 47, 5, 6.6), rump))
    sil = figure(a, [body, neck, head, ell(26, 45, 4, 3.6)], colour, patches, close=2.2)
    if tail:
        figure(a, [limb([(26, 44), (23, 52)], 3, 2)], tail, close=0, lw=0.8)
    if dappled:
        spots(a, sil, [(34, 42), (40, 40), (46, 41), (52, 40), (58, 43), (37, 47), (43, 46), (49, 47), (55, 47), (62, 38)], 1.2, "cream")
    else:
        fur(a, sil, "bark", 9, 4)
    W.four_legs(a, [39, 65], 52, 87, 4.2, colour)
    eye(a, 74.4, 21, 1.3)
    a.dot(85, 25.8, 1.4, "ink")
    ground(a, 89.4, 12, 88)
    return a


@sp("Capreolus capreolus")
def roe_deer(): return deer_fig()


@sp("Cervus elaphus", "Cervus nippon")
def red_deer(): return deer_fig("rust", "bark", "red", rump="buff", size=1.06)


@sp("Dama dama")
def fallow_deer(): return deer_fig("tan", "bark", "palm", dappled=True, tail="ink")


@sp("Muntiacus reevesi")
def muntjac(): return deer_fig("bark", "dark", "none", rump=None, size=0.94, tail="rust")


@sp("Plecotus auritus")
def long_eared_bat():
    a = W.DRAW["bat"]()
    for s in (1, -1):   # ears nearly as long as its body
        figure(a, [blob([(50 + s * 2, 33), (50 + s * 9, 10), (50 + s * 12, 14), (50 + s * 7.6, 33)], 6)], "brown", [(blob([(50 + s * 4, 32), (50 + s * 9, 14), (50 + s * 10.6, 16), (50 + s * 7, 32)], 6), "skin")], close=0, lw=0.9)
    return a


# =====================================================================
# AMPHIBIANS AND REPTILES
# =====================================================================

@sp("Rana temporaria", "Pelophylax ridibundus")
def common_frog():
    a = Art()   # smooth skin, a pointed face, a dark mask behind the eye and long barred legs
    body = blob([(20, 64), (30, 50), (46, 42), (62, 39), (76, 42), (88, 51), (86, 58), (72, 64), (54, 70), (34, 72)], 8)
    figure(a, [limb([(66, 60), (70, 73), (79, 76)], 4.4, 3)], "olive", close=0, lw=0.9)
    for d in (-1.6, 1.6):
        stroke(a, [(79, 76), (85, 76 + d)], 0.9, smooth=False)
    sil = figure(a, [body, ell(71, 39.6, 5.2, 4.6)], "olive", [(blob([(50, 68), (70, 61), (88, 53), (86, 59), (72, 65), (54, 71)], 8), "cream")], close=1.2)
    paint(a, blob([(58, 45), (68, 44), (75, 47.6), (72, 51), (62, 50)], 6).intersection(sil), "brown")   # the mask
    spots(a, sil, [(34, 54), (42, 48), (50, 51), (40, 58), (56, 44)], 1.5, "deep")
    stroke(a, [(32, 50), (46, 43.6), (60, 41)], 0.6, 0.6, col="buff")                        # the ridge down each side of the back
    thigh = limb([(30, 62), (42, 54), (50, 62)], 9, 7)
    shin = limb([(50, 63), (40, 72), (28, 75)], 6, 4)
    lsil = figure(a, [thigh, shin, limb([(28, 75), (42, 78), (56, 77)], 3.6, 2.4)], "olive", close=0.8)
    for x, y in ((36, 58), (42, 56), (47, 59), (45, 68), (38, 72)):
        stroke(a, [(x - 1.6, y - 2), (x + 1.6, y + 2)], 1.3, 0.9, col="deep", smooth=False)   # bars across the leg
    for d in (-1.8, 0, 1.8):
        stroke(a, [(56, 77), (63, 77 + d)], 0.9, smooth=False)
    a.dot(71.4, 40, 2.9, "amber"); paint(a, ell(71.6, 40, 1.9, 1.2), "ink")
    stroke(a, [(78, 52.4), (88, 52)], 0.6, 0.6, smooth=False)
    a.dot(84, 47.4, 0.5, "ink")
    ground(a, 79.4, 12, 90)
    return a


@sp("Bufo bufo", "Epidalea calamita")
def common_toad():
    a = Art()   # squat and warty, a blunt face, short legs: it walks, it does not leap
    body = blob([(18, 66), (24, 50), (40, 41), (58, 39), (72, 43), (82, 51), (83, 60), (74, 68), (54, 73), (30, 73)], 8)
    figure(a, [limb([(64, 62), (66, 73), (74, 76)], 5.4, 4)], "bark", close=0, lw=0.9)
    for d in (-1.6, 1.6):
        stroke(a, [(74, 76), (80, 76 + d)], 1.0, smooth=False)
    sil = figure(a, [body, ell(67, 40, 5, 4)], "bark", [(blob([(40, 72), (60, 68), (80, 58), (83, 61), (74, 69), (54, 74)], 8), "buff")], close=1.2)
    paint(a, blob([(52, 41), (62, 40), (64, 44.6), (54, 46)], 5).intersection(sil), "brown")  # the swollen gland behind the eye
    for i in range(34):                                                                        # warts
        x = 22 + (i * 37) % 56; y = 44 + (i * 23) % 24
        if sil.buffer(-2).contains(Point(x, y)) and y < 66:
            a.dot(x, y, 0.75 + (i % 3) * 0.25, "brown")
    leg = figure(a, [limb([(26, 64), (36, 60), (40, 68)], 9, 7), limb([(40, 69), (32, 75), (24, 76)], 5.4, 4)], "bark", close=0.8)
    for d in (-1.8, 0, 1.8):
        stroke(a, [(24, 76), (18, 76 + d)], 1.0, smooth=False)
    a.dot(67.4, 40.6, 2.8, "orange"); paint(a, ell(67.6, 40.6, 1.9, 0.9), "ink")
    stroke(a, [(72, 54.4), (83, 54)], 0.6, 0.6, smooth=False)
    ground(a, 79.4, 12, 90)
    return a


sp("Lissotriton vulgaris", "Lissotriton helveticus")(W.DRAW["newt"])
sp("Zootoca vivipara")(W.DRAW["lizard"])
sp("Vipera berus")(W.DRAW["snake"])


@sp("Triturus cristatus")
def great_crested_newt():
    a = Art()   # dark and warty, with a jagged crest along the male's back and tail
    line = [(84, 24), (70, 30), (58, 42), (52, 56), (40, 66), (26, 68), (14, 78)]
    c = curve(line, 10)
    crest = []
    for i in range(8, len(c) - 4, 2):
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)) + 90)
        crest.append(t(-(8.6 if (i // 2) % 2 else 5.6) * (1 if i < 44 else 0.7)))
    figure(a, [Polygon(crest + c[-5:7:-1]).buffer(0)], "dark", close=0, lw=0.9)
    W.four_feet(a, [(66, 33, -40), (70, 36, 62), (50, 58, 142), (55, 60, 40)], "dark", 10)
    for x, y, ang in [(66, 33, -40), (70, 36, 62), (50, 58, 142), (55, 60, 40)]:
        a.dot(*turn(x, y, ang)(10.6), 1.1, "orange")                                          # orange toes
    tail = limb([(52, 56), (40, 66), (26, 68), (14, 78)], 9, 1.6)
    sil = figure(a, [limb(line[:4], 8.6, 9.6), tail, ell(85, 23.4, 6.4, 5.2, -22)], "dark", [(limb(line[3:], 1.6, 0.8), "white")], close=1.4)
    for i in range(30):
        x = 16 + (i * 37) % 70; y = 20 + (i * 23) % 58
        if sil.buffer(-1.2).contains(Point(x, y)):
            a.dot(x, y, 0.5, "white")
    eye(a, 87.6, 19.8, 1.0, False); eye(a, 89.4, 25, 1.0, False)
    return a


@sp("Anguis fragilis")
def slow_worm():
    a = Art()   # a legless lizard: smooth, bronze and shiny, with a small head and no neck
    line = [(80, 26), (64, 22), (44, 24), (30, 34), (30, 48), (44, 54), (62, 52), (74, 60), (72, 74), (56, 80), (36, 78), (22, 82)]
    sil = figure(a, [limb(line, 6.6, 2.0), ell(82, 26.6, 5.4, 3.9, 8)], "amber", [(limb(line, 1.0, 0.5), "brown")], close=1.0)
    stroke(a, [(q[0] - 0.9, q[1] - 1.2) for q in curve(line, 8)[4:-10]], 0.7, 0.8, col="cream")
    eye(a, 84.4, 25, 0.9, False)
    stroke(a, [(87, 27.6), (90.6, 28.4)], 0.5, smooth=False)
    return a


@sp("Natrix helvetica")
def grass_snake():
    a = Art()   # olive green, with a yellow and black collar and black bars down each side
    line = [(78, 22), (64, 24), (46, 22), (30, 30), (26, 46), (40, 54), (60, 52), (74, 60), (74, 74), (58, 82), (38, 80), (22, 86)]
    head = blob([(74, 18), (82, 15), (91, 18), (93, 22.6), (88, 26.4), (78, 26)], 6)
    sil = figure(a, [limb(line, 7.4, 2.4), head], "olive", [(ell(74.6, 22.4, 2.2, 5), "yellow"), (ell(71.4, 22.8, 1.7, 5), "ink")], close=1.0)
    c = curve(line, 12)
    for i in range(10, len(c) - 8, 4):
        (x0, y0), (x1, y1) = c[i], c[i + 1]
        t = turn(x0, y0, math.degrees(math.atan2(y1 - y0, x1 - x0)) + 90)
        w = 3.2 * (1 - 0.6 * i / len(c))
        for s in (1, -1):
            stroke(a, [t(s * w), t(s * w * 0.45)], 1.1, 0.95, col="ink", smooth=False)
    a.dot(87.4, 19.4, 1.1, "amber"); a.dot(87.4, 19.4, 0.6, "ink")
    stroke(a, [(93, 22.6), (97, 22), (99, 20.4)], 0.5, smooth=False)
    stroke(a, [(97, 22), (99, 23.6)], 0.5, smooth=False)
    return a


# The kinds whose own drawing is now that of one typical animal, redrawn
# here with more detail. The kind's picture and that animal's are the same.
for kind, fn, sci in [("butterfly", S1.peacock, "Aglais io"), ("moth", S1.large_yellow_underwing, "Noctua pronuba"), ("dragonfly", S1.emperor, "Anax imperator"),
                      ("damselfly", S1.blue_damselfly, "Enallagma cyathigerum"), ("solitary-bee", S1.red_mason, "Osmia bicornis"), ("snail", S1.garden_snail, "Cornu aspersum"),
                      ("tit", blue_tit, "Cyanistes caeruleus"), ("finch", goldfinch, "Carduelis carduelis"), ("thrush", robin, "Erithacus rubecula"), ("warbler", chiffchaff, "Phylloscopus collybita"),
                      ("crow", carrion_crow, "Corvus corone"), ("pigeon", woodpigeon, "Columba palumbus"), ("woodpecker", great_spotted_woodpecker, "Dendrocopos major"),
                      ("swallow", swallow, "Hirundo rustica"), ("owl", tawny_owl, "Strix aluco"), ("raptor", buzzard, "Buteo buteo"), ("gamebird", pheasant, "Phasianus colchicus"),
                      ("duck", mallard, "Anas platyrhynchos"), ("coot", coot, "Fulica atra"), ("heron", grey_heron, "Ardea cinerea"), ("seabird", herring_gull, "Larus argentatus"),
                      ("fox", fox, "Vulpes vulpes"), ("squirrel", grey_squirrel, "Sciurus carolinensis"), ("small-mammal", wood_mouse, "Apodemus sylvaticus"), ("deer", roe_deer, "Capreolus capreolus"),
                      ("frog", common_frog, "Rana temporaria"), ("toad", common_toad, "Bufo bufo"), ("cat", cat, "Felis catus")]:
    W.DRAW[kind] = fn
    W.KIND_IS[kind] = sci
W.KIND_IS.update({"badger": "Meles meles", "hedgehog": "Erinaceus europaeus", "rabbit": "Oryctolagus cuniculus", "bat": "Pipistrellus pipistrellus", "seal": "Halichoerus grypus",
                  "whale": "Tursiops truncatus", "newt": "Lissotriton vulgaris", "lizard": "Zootoca vivipara", "snake": "Vipera berus"})
