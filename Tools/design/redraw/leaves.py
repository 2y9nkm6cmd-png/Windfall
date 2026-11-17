"""Windfall plant drawings, the redraw of 16 November 2026: the leaves group.

The twenty-one kinds in this file: lettuce, leaf salad, celtuce, spinach,
Swiss chard, spinach beet, pak choi, lamb's lettuce, rocket, mizuna,
mustard, cress, chicory, sorrel, Good King Henry, purple orache, cabbage,
cauliflower, broccoli, sprouting broccoli and Brussels sprouts.

WHY THIS FILE EXISTS
William found the strawberry leaf drawn wrong, and a spot check found the
same faults all over: the leaf on the whole plant was a stock leaf, not the
plant's own; flower colours changed between the close-up and the plant;
flowers were built from a few stock shapes; leaf shapes were rough. In this
group, for example, the lettuce leaf had sharp teeth (a lettuce has none),
chard and spinach were drawn with the same leaf, rocket had stock flat
flowers and Brussels sprouts were round fruits on a stalk. Every plant now
has a written description (Design/Plants/descriptions/<kind>.json) with a
"must_show" list for each drawing, and every drawing of these kinds has
been redrawn to show those points, checked against photographs.

HOW IT WORKS (see redraw/__init__.py for what each table does)
  LEAFX, BLOOMX    the close-up leaf and flower of each kind.
  STAGE            every life stage of every kind, drawn by hand here,
                   because the templates in plants_all.py cannot show
                   things like a lettuce's heart, a chicon or a sprout stem.
  KIND             leaf="own" for each kind, so anything still drawn from
                   the templates uses the kind's own close-up leaf.
  LEAF_DRAW, BLOOM_DRAW   the new close-up shapes, all named leaves_...
  COLOURS          five new colours (see the table near the top).
Colours come from each description's palette, as the brief asks; the new
colours are only for parts the palette does not cover (the pale ribs of the
cabbage family, a cabbage's paler head) or were asked for by a description.

THE MAIN NEW SHAPES, IN PLAIN WORDS
  leaf_engine(a, sp)   every close-up leaf. A leaf is built like this:
      a "body" whose width along its length is worked out by body_hw()
      (two numbers, p and q, say how broad and round the base and the tip
      are), sitting on a narrow "wing" along the midrib; side lobes (each a
      small leaf of its own, made by lobe_pts(), leaning forwards or
      backwards) are added along the wing. blade_outline() walks up one
      side and down the other, putting in the lobes as it reaches them,
      so the whole outline is ONE shape with no lines inside it. edge_cut()
      takes a little off (or adds a little to) the edge to give a wave, a
      frill or teeth. The same engine draws the round lettuce leaf (no
      lobes), the rocket leaf (lobes in pairs and a big end lobe), the
      mizuna leaf (many narrow jagged lobes) and the arrow-shaped sorrel
      leaf (two lobes leaning right back as ears). It can add a broad
      coloured midrib (chard), puckering, a shine, a red edge (leaf salad),
      white meal (Good King Henry) and bristles (mustard).
  put(a, slug, ...)    draws the kind's own close-up leaf small on the whole
      plant (with Art.place), so the leaves on the plant match the close-up.
  fl_cross, xflower, xside   the cabbage family's four-petalled crosses,
      face on and from the side, with the sepals hugging the petals or
      spreading flat, and the buds above or below the open flowers.
  fl_ligule, lig_head, lig_side   lettuce and chicory heads: strap-shaped
      florets with toothed tips, and the slim cup of bracts beneath.
  glom, fl_spinach, fl_beetspike, fl_gkh, fl_orache, fl_sorrel   the tiny
      flowers without petals of the goosefoot family and the docks.
  head_ball            a round head of folded leaves round a paler heart
      (lettuce, cabbage). floret_dome() is cauliflower's knobbly curd and
      broccoli's dome of buds, made of rows of rounded lumps; spear() a sprouting broccoli spear; chicon()
      a forced chicory head.

Things Claude chose that William should check are in the results file for
this group (kind, drawing, verdict, note) and in the report.
"""
import math
from plant_kit import Art, T, P, f, Quad, STEM, LEAF, BLOOM
import plants as S10


# ================================================================ helpers
def _lfw():
    import leaves_flowers
    return leaves_flowers


def _pa():
    import plants_all
    return plants_all


def path(pts):
    return "M" + " L".join(P(p) for p in pts) + " Z"


def opath(pts):
    return "M" + " L".join(P(p) for p in pts)


BASE = (20, 92)   # where a close-up leaf's stalk starts (as in leaves_flowers.py)
ANG = -52         # and the way it points
GOLD = 2.39996


def pal(slug, part, default):
    """A colour from the kind's description (its "palette")."""
    return _pa().palette(slug).get(part, default)


def wobble(k):
    """A steady 'random' number between -1 and 1 for the k-th tooth or lobe,
    so uneven edges come out the same every time (no real randomness)."""
    return math.sin(k * 12.9898 + 4.1) * 0.6 + math.sin(k * 3.71 + 1.3) * 0.4


# ======================================================= the leaf engine
def edge_cut(u, side, sp, k0=0):
    """How much the edge moves in (positive) or out (negative) at u, 0 at
    the start of a stretch of edge and 1 at its end. Settings in sp:
      wave, waven     a slow wave, wave grid squares deep, waven waves
      crimp, crimpn   a fine frill of many small waves (Lollo lettuce)
      teeth, td, tk   teeth: how many, how deep, and "saw" (sharp, pointing
                      to the tip), "round" (blunt), "jag" (sharp and uneven)"""
    w = 0.0
    fade = max(0.0, min(1.0, u / 0.08, (1 - u) / 0.05))
    if sp.get("wave"):
        w += sp["wave"] * math.sin(2 * math.pi * u * sp.get("waven", 4) + (0 if side > 0 else 1.9) + k0) * fade
    if sp.get("crimp"):
        s = (u * sp.get("crimpn", 24) + (0 if side > 0 else 0.4)) % 1
        w += sp["crimp"] * (abs(math.cos(math.pi * s)) ** 0.6 - 0.5) * fade
    n = sp.get("teeth", 0)
    if n:
        s = (u * n + (0 if side > 0 else 0.5)) % 1
        k = int(u * n + (0 if side > 0 else 0.5)) + (0 if side > 0 else 37) + k0 * 11
        tk = sp.get("tk", "saw")
        nick = {"saw": (1 - s) ** 1.6, "round": abs(math.cos(math.pi * s)) ** 2.4, "jag": (1 - s) ** 1.3}[tk]
        d = sp.get("td", 1.5) * (1 + (0.45 * wobble(k) if tk == "jag" else 0))
        w += d * nick * fade
    return w


def body_hw(x, L, sp):
    """Half width of the main body of the blade (the whole blade of a simple
    leaf, or the end lobe of a lobed one) at x (0 at the foot of the blade,
    L at its tip). p shapes the base (small: broad and round, big: a narrow
    wedge), q the tip (small: blunt and round, big: a long point)."""
    x0 = sp.get("x0", 0.0) * L
    if x < x0 or x > L:
        return 0.0
    u = (x - x0) / (L - x0)
    p, q = sp.get("p", 0.8), sp.get("q", 0.6)
    um = p / (p + q); m = um ** p * (1 - um) ** q
    return sp.get("W", 0.5) * L / 2 * (u ** p * (1 - u) ** q) / m


def lobe_pts(root, side, a_deg, l, w, r, sp, k0, tipr=0.5, M=None):
    """One side lobe (or ear) of a leaf, as points from its back root round
    its tip to its front root. root is where its axis leaves the edge;
    a_deg how far it leans forward (+) or back (-) from straight out; l its
    length, w its width, r its half width where it joins. Teeth from sp
    (lt, ltd, ltk) on both its edges. tipr: 0.5 a round tip, more a sharper one."""
    a = math.radians(a_deg)
    ax = (math.sin(a), side * math.cos(a)); pp = (math.cos(a), -side * math.sin(a))
    def hwv(v):
        base = r + (w / 2 - r) * math.sin(math.pi / 2 * min(1, v / 0.35))
        tip = (1 - max(0, (v - 0.55) / 0.45) ** 2) ** tipr if v > 0.55 else 1
        return max(0.2, base * tip)
    n = 26; us = [i / n for i in range(n + 1)]
    sub = dict(teeth=sp.get("lt", 0), td=sp.get("ltd", 0), tk=sp.get("ltk", "saw"))
    out = []
    for i, v in enumerate(us):   # back edge, out to the tip
        h = -(hwv(v) - (edge_cut(v, 1, sub, k0) if sub["teeth"] else 0))
        out.append((root[0] + v * l * ax[0] + h * pp[0], root[1] + v * l * ax[1] + h * pp[1]))
    for v in us[::-1][1:]:       # front edge, back in
        h = hwv(v) - (edge_cut(v, -1, sub, k0 + 3) if sub["teeth"] else 0)
        out.append((root[0] + v * l * ax[0] + h * pp[0], root[1] + v * l * ax[1] + h * pp[1]))
    return out


def blade_outline(L, sp):
    """The outline of a leaf blade laid along the x axis from 0 to L, as two
    lists of points (side 1, side -1), each running from the foot to the tip.
    The blade is the body (body_hw) on a narrow wing along the midrib
    ("wing" wide), with side lobes ("lobes": (x, lean, length, width, root
    half width, side) each, x as a share of L, side 1, -1 or 0 for both)."""
    wing = sp.get("wing", 0.0); lobes = sp.get("lobes", [])
    sides = []
    for side in (1, -1):
        mine = sorted([lb for lb in lobes if lb[5] in (0, side)], key=lambda lb: lb[0])
        pts = []; n = sp.get("n", 160)
        xs = [L * i / n for i in range(n + 1)]
        lxs = [lb[0] * L + (sp.get("stagger", 0.012) * L * (side < 0) if lb[5] == 0 else 0) for lb in mine]
        li = 0; skip = -1e9
        for x in xs:
            if x < skip:
                continue
            if li < len(mine) and x >= lxs[li] - mine[li][4]:
                lx = lxs[li]; _, lean, ll, lw_, lr, _ = mine[li]
                bw = max(wing * (1 - 0.3 * lx / L), body_hw(lx, L, sp))
                pts += lobe_pts((lx, side * bw), side, lean, ll, lw_, lr, sp, li * 2 + (side < 0), sp.get("tipr", 0.5))
                skip = lx + lr; li += 1
                continue
            u = x / L
            b = body_hw(x, L, sp)
            hw = max(wing * (1 - 0.3 * u) * min(1.0, (1 - u) / 0.18), b)
            if b > wing:
                x0 = sp.get("x0", 0.0)
                ub = (u - x0) / max(0.01, 1 - x0)
                hw -= edge_cut(ub, side, sp)
            pts.append((x, side * max(0.25, hw)))
        sides.append(pts)
    return sides


def leaf_engine(a, sp):
    """Every close-up leaf in this file. Draws the stalk, the blade (see
    blade_outline), its midrib and side veins, and any of: a broad
    coloured midrib (chard), puckering, a shine, a red flush round the
    edge, mealy dots, small leafy lobes on the stalk, bristles."""
    fill = sp["fill"]; LT = sp.get("len", 98); pf = sp.get("petiole", 0.2)
    ang = sp.get("ang", ANG); base = sp.get("base", BASE)
    t0 = T(*base, ang); A = t0(LT * pf); L = LT * (1 - pf)
    bend = sp.get("bend", 0.0)
    tt = T(*A, ang)
    mp = lambda x, y: tt(x, y + bend * x * x / L)
    if pf > 0:   # the stalk
        sw = sp.get("sw", 2.6); sc = sp.get("stalkc", fill)
        a.ribbon(base, t0(LT * pf * 0.5, sp.get("sbend", 1.2)), t0(LT * pf + sp.get("sinto", 2)), sw, sp.get("sw1", sw * 0.8), sc, lw=0.9)
        for x, size, sd in sp.get("stalklobes", []):   # small leafy lobes along the stalk (broccoli, cabbage)
            p = t0(LT * pf * x, sd * sw * 0.4)
            hw = lambda u, s_, size=size: size * 0.32 * math.sin(math.pi * min(1, u) ** 0.8) ** 0.7 - edge_cut(u, s_, dict(wave=0.5, waven=2))
            _rblade(a, p[0], p[1], ang + sd * sp.get("slang", 58), size, hw, fill, lw=0.9, midw=0.4, shade=0.08)
    up, dn = blade_outline(L, sp)
    outline = [mp(*q) for q in up] + [mp(*q) for q in dn[::-1]]
    a.shape(path(outline), fill, 0 if sp.get("flush") else 1.15)
    if sp.get("shade", 0.1):
        a.shape(path([mp(*q) for q in up] + [mp(q[0], 0) for q in up[::-1]]), "shade", 0, fa=sp.get("shade", 0.1))
    if sp.get("flush"):   # a red-bronze flush round the edge (some lettuces, leaf salad)
        fw = sp.get("flushw", 6)
        for side_pts in (up, dn):
            outer = [q for q in side_pts if q[0] > L * 0.2]
            inner = [(q[0], q[1] - math.copysign(min(abs(q[1]) * 0.6, fw * (0.4 + 0.6 * min(1, (q[0] / L - 0.2) / 0.3))), q[1])) for q in outer]
            a.shape(path([mp(*q) for q in outer] + [mp(*q) for q in inner[::-1]]), sp["flush"], 0, fa=sp.get("flusha", 0.5))
        a.shape(path(outline), None, 1.15)
    # veins
    vc = sp.get("veinc", "line"); va = sp.get("veina", 0.4)
    lob = sp.get("lobes", [])
    for i, (lx, lean, ll, lw_, lr, sd) in enumerate(lob):
        for side in ((1, -1) if sd == 0 else (sd,)):
            bw = max(sp.get("wing", 0), body_hw(lx * L, L, sp))
            ar = math.radians(lean); r0 = (lx * L, side * bw)
            e = (r0[0] + ll * 0.78 * math.sin(ar), r0[1] + side * ll * 0.78 * math.cos(ar))
            a.line(f"M{P(mp(lx * L - (1.5 if lean > -30 else -1), 0))} Q{P(mp(*r0))} {P(mp(*e))}", 0.5, va, vc)
    nv = sp.get("veins", 6); x0 = sp.get("x0", 0.0)
    hwf = lambda x, s_: max(sp.get("wing", 0) * (1 - 0.3 * x / L) * min(1.0, (1 - x / L) / 0.18), body_hw(x, L, sp))
    style = sp.get("vstyle", "pinnate")
    mw = sp.get("midw", 0.9); mc = sp.get("midc", "line"); me = sp.get("midend", 0.95)
    mid_hw = lambda x: min(mw / 2 * (1 - 0.82 * x / (L * me)), sp.get("midk", 0.32) * hwf(x, 1)) if mw >= 2 else 0.0
    fwd = sp.get("vfwd", 0.75)
    for k in range(nv):
        # each side vein leaves the midrib at a steep angle and curves forward
        # to the edge: lower veins further apart and (fan) spreading wider
        v = k / max(1, nv - 1)
        xa = L * (x0 + (1 - x0) * (sp.get("vstart", 0.05) + sp.get("vend", 0.72) * v))
        fk = fwd * ((0.25 + 0.75 * v) if style == "fan" else 1.0)
        for side in (1, -1):
            xb = min(L * 0.96, xa + fk * hwf(xa, side) + L * 0.02)
            yb = hwf(xb, side) * sp.get("vreach", 0.86) * side
            ya = mid_hw(xa) * side
            c = (xa + (xb - xa) * 0.2, ya + (yb - ya) * 0.62)
            a.line(f"M{P(mp(xa, ya))} Q{P(mp(*c))} {P(mp(xb, yb))}", sp.get("vw", 0.5), va, vc)
            if sp.get("branch"):   # a smaller vein forking off towards the edge
                m = (xa + (xb - xa) * 0.45, ya + (yb - ya) * 0.66)
                e2 = (min(L * 0.97, m[0] + abs(yb) * 0.45), hwf(m[0] + abs(yb) * 0.45, side) * 0.8 * side)
                a.line(f"M{P(mp(*m))} L{P(mp(*e2))}", 0.4, va * 0.8, vc)
    if mw >= 2:   # a broad flat midrib, as a band narrowing to near the tip
        xs = [L * me * i / 30 for i in range(31)]
        band = [mp(x, mid_hw(x)) for x in xs] + [mp(L * me + 1.5, 0)] + [mp(x, -mid_hw(x)) for x in xs[::-1]]
        a.shape(path(band), mc, 0)   # no outline, so it still reads as a pale band when drawn small
    else:
        a.line(opath([mp(L * u, 0) for u in (0.0, 0.3, 0.6, me)]), mw, 0.55, mc)
    if sp.get("pucker_auto"):   # blistered all over: a small bulge between each pair of side veins
        for k in range(nv):
            v = (k + 0.5) / max(1, nv - 1)
            if v > 1:
                continue
            xa = L * (x0 + (1 - x0) * (sp.get("vstart", 0.05) + sp.get("vend", 0.72) * v)) + hwf(L * 0.5, 1) * 0.25
            for side in (1, -1):
                for t in (0.38, 0.72):
                    w = hwf(xa, side) * t * side; sz = 1.4 + 1.2 * t
                    a.line(f"M{P(mp(xa - sz, w))} Q{P(mp(xa, w + sz * 0.9 * side))} {P(mp(xa + sz, w))}", 0.55, sp.get("puckera", 0.4))
    for (u, v, s) in sp.get("puckers", []):   # the blade puckered up between the veins
        x = L * u; w = hwf(x, 1) * v
        a.line(f"M{P(mp(x - s, w))} Q{P(mp(x, w + s * 0.8 * (1 if v > 0 else -1)))} {P(mp(x + s, w))}", 0.5, sp.get("puckera", 0.32))
    if sp.get("frills"):   # small folds running in from a frilled edge
        for k in range(sp["frills"]):
            u = 0.3 + 0.66 * k / max(1, sp["frills"] - 1)
            for side in (1, -1):
                w = hwf(L * u, side)
                a.line(f"M{P(mp(L * u, side * w * 0.98))} L{P(mp(L * (u - 0.015), side * w * 0.82))}", 0.45, 0.4)
    if sp.get("gloss"):   # a shine along one half
        a.line(opath([mp(L * u, -hwf(L * u, -1) * 0.55) for u in (0.3, 0.42, 0.55, 0.66)]), 1.2, 0.45, "white")
    if sp.get("underside"):   # one edge turned up, showing the frosted, mealy underside
        side_pts = [q for q in up if 0.18 * L < q[0] < 0.86 * L]
        inner = [(q[0], q[1] - min(q[1] * 0.4, 3.4)) for q in side_pts]
        a.shape(path([mp(*q) for q in side_pts] + [mp(*q) for q in inner[::-1]]), "pale", 0.7)
        for j, q in enumerate(side_pts[::4]):
            d = mp(q[0], q[1] - min(q[1] * 0.4, 3.4) * (0.35 + 0.3 * (j % 2)))
            a.dot(d[0], d[1], 0.5, "white")
    if sp.get("mealy"):   # Good King Henry: a frosting of tiny white grains
        for j in range(sp["mealy"]):
            u = 0.12 + 0.8 * ((j * 0.7548777) % 1); v = ((j * 0.5698403) % 1) * 2 - 1
            q = mp(L * u, hwf(L * u, 1) * v * 0.85)
            a.dot(q[0], q[1], 0.42, "white")
    if sp.get("bristles"):   # stiff hairs (mustard)
        for j in range(sp["bristles"]):
            u = 0.1 + 0.85 * ((j * 0.7548777) % 1); v = ((j * 0.5698403) % 1) * 1.6 - 0.8
            q = mp(L * u, hwf(L * u, 1) * v); e = mp(L * u + 1.2, hwf(L * u, 1) * v + 0.6)
            a.line(f"M{P(q)} L{P(e)}", 0.45, 0.55)
    a.anchor, a.anchor_ang = base, ang
    return a


def _rblade(a, x, y, ang, L, hw, fill, lw=1.15, midw=0.6, shade=0.1, n=60, midc="line"):
    """A small leaf or petal of any outline: hw(u, side) is its half width
    at u (0 at the base, 1 at the tip)."""
    t = T(x, y, ang); us = [i / n for i in range(n + 1)]
    top = [t(L * u, hw(u, 1)) for u in us]; bot = [t(L * u, -hw(u, -1)) for u in us]
    a.shape(path(top + bot[::-1]), fill, lw)
    if shade:
        a.shape(path(top + [t(L * u, 0) for u in us[::-1]]), "shade", 0, fa=shade)
    if midw:
        a.line(opath([t(L * u, 0) for u in (0.0, 0.4, 0.85)]), midw, 0.5, midc)
    return t


LEAF_DRAW = {"leaves_leaf": leaf_engine}


def leaf_cress(a, sp):
    """Garden cress: a lower leaf cut into narrow lobes on a long stalk,
    and beside it the top of a stem with its narrow, stalkless upper leaves."""
    leaf_engine(a, dict(sp, base=(14, 94), len=86))
    q = Quad((70, 98), (76, 70), (72, 44))
    a.ribbon(q.p0, q.c, q.p1, 1.8, 1.3, sp["fill"], lw=0.8)
    for u, sd, L in ((0.25, 1, 17), (0.55, -1, 15), (0.82, 1, 12)):
        x, y = q.pt(u); g = q.ang(u) + sd * 38
        hw = lambda v, s_: 1.7 * math.sin(math.pi * min(1, v) ** 0.5) ** 0.6
        _rblade(a, x, y, g, L, hw, sp["fill"], lw=0.9, midw=0.4, shade=0.08)
    x, y = q.pt(1); a.oval(x, y - 1.5, 1.4, 2.2, 0, sp["fill"], 0.7)
    return a


LEAF_DRAW["leaves_cress"] = leaf_cress

COLOURS = {
    "leaves_rib": ("#E3EBD3", "#7E9A7A"),        # the pale waxy midribs and stalks of the cabbage family
    "leaves_skyblue": ("#6E94E0", "#7FA3EA"),    # chicory's clear sky blue (its description's palette_wish)
    "leaves_paleblue": ("#D3DDF3", "#A9B8DE"),   # lamb's lettuce: very pale lilac-blue, almost white
    "leaves_cream": ("#F6EDCB", "#E2D6A8"),      # rocket's cream petals
    "leaves_head": ("#D5E2C2", "#6A8A64"),       # a cabbage's head: paler than its blue-green outer leaves
    "leaves_yellow": ("#F6DA3A", "#EAD045"),     # the clear yellow of mustard, mizuna and pak choi flowers ("sun" is amber)
    "leaves_orache": ("#6F2A4C", "#8E4A6C"),     # purple orache's deep dusky red-purple
}

_BRASS = dict(kind="leaves_leaf", midc="leaves_rib", stalkc="leaves_rib", veinc="leaves_rib", veina=0.85, vw=0.9, branch=True)

LEAFX = {
    "lettuce": dict(kind="leaves_leaf", fill="leaf", petiole=0, len=88, W=0.8, p=1.15, q=0.55, wing=6.0, midk=0.6, wave=1.6, waven=4.5,
                    crimp=0.5, crimpn=30, midw=7, midc="pale", veins=7, vstyle="fan", branch=True, veinc="white",
                    veina=0.55, frills=6, puckers=[(0.45, 0.45, 2.4), (0.6, -0.5, 2.4), (0.72, 0.35, 2.2), (0.32, -0.42, 2.0), (0.82, -0.3, 2.0)]),
    "leaf-salad": dict(kind="leaves_leaf", fill="leaf", petiole=0, len=96, W=0.5, p=1.0, q=0.5, wing=5.0, midk=0.55, wave=1.5, waven=6,
                       crimp=1.3, crimpn=40, midw=5, midc="pale", veins=6, branch=True, veinc="white", veina=0.5,
                       frills=12, flush="beet", flushw=5, flusha=0.5,
                       puckers=[(0.45, 0.4, 2.0), (0.6, -0.45, 2.0), (0.75, 0.3, 1.8)]),
    "celtuce": dict(kind="leaves_leaf", fill="leaf", petiole=0, len=98, W=0.3, p=0.5, q=1.25, wing=3.6, midk=0.4, wave=0.8, waven=5,
                    midw=3.0, midc="pale", veins=9, vreach=0.8, veinc="line", veina=0.3,
                    puckers=[(0.3, 0.3, 1.6), (0.45, -0.3, 1.6), (0.6, 0.28, 1.4)]),
    "spinach": dict(kind="leaves_leaf", fill="marrow", petiole=0.44, sw=3.0, len=98, W=0.66, p=0.42, q=0.75, wing=1.0,
                    lobes=[(0.025, -52, 5, 6.5, 3.0, 0)], stagger=0, midw=1.4, veins=4, vreach=0.8, veina=0.45, gloss=True,
                    puckers=[(0.4, 0.4, 2.0), (0.55, -0.45, 2.0)]),
    "swiss-chard": dict(kind="leaves_leaf", fill="deep", petiole=0.34, sw=7, sw1=5.6, sinto=6, stalkc="berry", len=98, W=0.66, p=0.45,
                        q=0.55, wing=3.2, wave=1.8, waven=5, midw=6.5, midc="berry", veins=6, veinc="berry",
                        veina=0.6, vw=0.8, gloss=True, puckera=0.55, pucker_auto=True,
                        puckers=[(0.25, 0.5, 2.2), (0.36, -0.55, 2.4), (0.48, 0.6, 2.4), (0.58, -0.4, 2.2), (0.68, 0.45, 2.0),
                                 (0.78, -0.5, 2.0), (0.3, 0.3, 1.6), (0.52, -0.25, 1.8), (0.86, 0.3, 1.6)]),
    "spinach-beet": dict(kind="leaves_leaf", fill="deep", petiole=0.46, sw=2.6, stalkc="leaf", len=98, W=0.62, p=0.6, q=0.6,
                         wing=1.6, wave=0.9, waven=4, midw=1.6, midc="pale", veins=5, vreach=0.8, veina=0.4, gloss=True,
                         puckers=[(0.4, 0.4, 1.8), (0.58, -0.45, 1.8)]),
    "pak-choi": dict(kind="leaves_leaf", fill="marrow", petiole=0.46, sw=10, sw1=6.5, sinto=4, stalkc="white", len=98, W=0.88,
                     p=0.55, q=0.5, wing=3.4, wave=0.6, waven=3, midw=4.2, midc="white", veins=6, veinc="white",
                     veina=0.55, gloss=True),
    "lambs-lettuce": dict(kind="leaves_leaf", fill="deep", petiole=0, len=94, W=0.44, p=1.35, q=0.42, wing=2.0, midw=1.2,
                          veins=3, veina=0.25, gloss=True),
    "cabbage": dict(_BRASS, fill="sage", petiole=0.17, sw=5.4, sw1=4.6, sinto=4, len=92, W=0.9, p=0.75, q=0.42, wing=2.6,
                    teeth=9, td=1.2, tk="round", wave=1.2, waven=3, midw=4.8, veins=6),
    "cauliflower": dict(_BRASS, fill="sage", petiole=0.12, sw=5.0, sw1=4.4, sinto=4, len=98, W=0.44, p=0.85, q=0.6, wing=2.4,
                        teeth=14, td=0.9, tk="round", wave=1.4, waven=6, midw=4.2, veins=8),
    "broccoli": dict(_BRASS, fill="sage", petiole=0.24, sw=4.4, sw1=3.8, len=98, W=0.5, p=0.9, q=0.48, x0=0.22, wing=2.4,
                     lobes=[(0.035, 12, 6.5, 6, 2.0, 0), (0.13, 18, 9, 8, 2.4, 0)], lt=2, ltd=0.6, ltk="round",
                     teeth=12, td=1.1, tk="round", wave=1.3, waven=6, crimp=0.4, crimpn=30, midw=4.2, veins=6),
    "broccoli-sprouting": dict(_BRASS, fill="sage", petiole=0.26, sw=4.4, sw1=3.8, stalkc="plum", len=98, W=0.48, p=0.9, q=0.48,
                               x0=0.2, wing=2.4, lobes=[(0.04, 12, 6, 6, 2.0, 0), (0.12, 18, 8, 7, 2.4, 0)], lt=2, ltd=0.6,
                               ltk="round", teeth=11, td=1.1, tk="round", wave=1.3, waven=5, midw=4.2, veins=6,
                               flush="plum", flushw=4, flusha=0.3),
    "brussels-sprouts": dict(_BRASS, fill="sage", petiole=0.42, sw=4.6, sw1=3.8, len=98, W=0.92, p=0.55, q=0.45, wing=2.4,
                             stalklobes=[(0.72, 8, 1)], teeth=9, td=0.9, tk="round", wave=1.1, waven=4, midw=3.8,
                             veins=5, puckers=[(0.35, 0.45, 2.0), (0.5, -0.5, 2.2), (0.66, 0.4, 2.0)]),
    "rocket-salad": dict(kind="leaves_leaf", fill="leaf", petiole=0.1, sw=2.4, stalkc="pale", len=98, x0=0.6, W=0.27, p=0.6,
                         q=0.55, wing=2.0, midw=1.6, midc="pale", veins=3, veina=0.35,
                         lobes=[(0.1, 8, 9, 5.6, 2.2, 0), (0.25, 14, 13, 7.4, 2.8, 0), (0.41, 20, 16, 8.8, 3.2, 0), (0.55, 26, 15, 8.6, 3.2, 0)],
                         lt=2, ltd=0.6, ltk="round", teeth=5, td=0.9, tk="round"),
    "mustard": dict(kind="leaves_leaf", fill="leaf", petiole=0.14, sw=2.6, len=98, x0=0.64, W=0.34, p=0.5, q=0.6, wing=2.6,
                    midw=1.4, midc="pale", veins=3, veina=0.4, vstart=0.1,
                    lobes=[(0.05, 14, 9, 7, 2.6, 0), (0.19, 18, 14, 10, 3.4, 0), (0.35, 22, 17, 12, 4.0, 0), (0.51, 28, 16, 11.5, 4.0, 0)],
                    lt=3, ltd=2.6, ltk="jag", teeth=6, td=3.0, tk="jag", bristles=30),
    "mizuna": dict(kind="leaves_leaf", fill="leaf", petiole=0.3, sw=3.0, sw1=2.4, stalkc="white", len=98, x0=0.74, W=0.16,
                   p=0.8, q=0.8, wing=1.3, midw=2.2, midc="white", veins=0, teeth=5, td=1.6, tk="jag",
                   lobes=[(0.06, 42, 10, 3.4, 1.2, 0), (0.17, 42, 12, 3.6, 1.3, 0), (0.28, 44, 13, 3.8, 1.3, 0), (0.39, 45, 13, 3.8, 1.3, 0),
                          (0.5, 46, 12, 3.6, 1.3, 0), (0.6, 48, 10.5, 3.4, 1.2, 0), (0.69, 50, 8, 3.0, 1.1, 0)],
                   lt=3, ltd=1.3, ltk="jag", tipr=0.9),
    "cress": dict(kind="leaves_cress", fill="sage", petiole=0.34, sw=1.8, len=86, x0=0.66, W=0.07, p=0.5, q=0.7, wing=1.2,
                  midw=1.0, veins=0, lobes=[(0.12, 34, 13, 3.4, 1.7, 0), (0.33, 36, 14, 3.4, 1.7, 0), (0.53, 40, 12, 3.2, 1.6, 0)],
                  lt=1, ltd=0.6, ltk="round", tipr=0.6),
    "chicory": dict(kind="leaves_leaf", fill="leaf", petiole=0, len=98, x0=0.28, W=0.3, p=0.9, q=0.75, wing=4.2, midk=0.5, wave=0.8, waven=5,
                    teeth=10, td=1.1, tk="saw", midw=4.0, midc="pale", veins=7, veina=0.3,
                    lobes=[(0.07, -40, 8, 6, 2.4, 0), (0.18, -32, 10, 8, 2.8, 0)], tipr=1.3),
    "sorrel": dict(kind="leaves_leaf", fill="leaf", petiole=0.42, sw=2.2, len=98, W=0.36, p=0.32, q=0.5, wing=0.5,
                   lobes=[(0.035, -80, 12.5, 6.2, 2.6, 0)], stagger=0, tipr=1.0, midw=1.0, veins=6, veina=0.3, branch=True),
    "good-king-henry": dict(kind="leaves_leaf", fill="deep", petiole=0.44, sw=2.2, len=98, W=0.78, p=0.24, q=1.0, wing=0.5,
                            lobes=[(0.03, -36, 7, 6.5, 2.6, 0)], stagger=0, tipr=1.3, midw=1.0, veins=4, veina=0.4, mealy=10, underside=True,
                            wave=0.5, waven=3),
    "purple-orach": dict(kind="leaves_leaf", fill="leaves_orache", petiole=0.3, sw=2.2, len=98, W=0.72, p=0.22, q=0.95, wing=0.5,
                         lobes=[(0.03, -18, 6, 6, 2.4, 0)], stagger=0, tipr=1.2, midw=0.9, veins=4, veina=0.4, teeth=5, td=0.8, tk="jag"),
}


# ================================================================ flowers
def tilt(cy, k):
    return lambda p: (p[0], cy + (p[1] - cy) * k)


def small_leaf(a, x, y, ang, L, b, fill, lw=0.7):
    a.leaf(x, y, ang, L, b, fill, lw=lw, detail=False)


# ---- the cabbage family: four petals in a cross
def xflower(a, x, y, R, fc, k=0.8, start=-45, veins=None, sepals="hug", sepc="unripe", anth="sun", cen="unripe", lw=0.8, prof="claw", pw=0.7):
    """One four-petalled cross, face on but tipped back a little (k squashes
    it). sepals "hug": narrow upright sepals, seen only as two short points
    between the petals; "flat": spreading flat out between the petals
    (mustard); None: hidden. veins: fine dark veins along each petal (rocket)."""
    LFW = _lfw(); M = tilt(y, k)
    if sepals == "flat":
        for i in range(4):
            LFW.blade(a, x, y, start + 45 + 90 * i, R * 0.78, R * 0.18, sepc, "lance", veins=0, M=M, lw=0.6, petal=True)
    elif sepals == "hug":
        for g in (start + 45, start + 135):
            LFW.blade(a, x, y, g, R * 0.42, R * 0.16, sepc, "lance", veins=0, M=M, lw=0.6, petal=True)
    LFW.ring_of_petals(a, 4, R, R * pw, fc, prof, cx=x, cy=y, k=k, start=start, lw=lw)
    if veins:
        for i in range(4):
            t = T(x, y, start + 90 * i)
            for o in (-0.28, 0, 0.28):
                a.line(opath([M(t(R * u, o * R * 0.62 * u)) for u in (0.3, 0.6, 0.9)]), 0.45 if R > 8 else 0.35, 0.85, veins)
    if R >= 7:
        LFW.stamens(a, x, y, 0.8, R * 0.32, 6, anth, M, lw=0.4)
    a.oval(x, y - R * 0.04, max(0.5, R * 0.06), max(0.8, R * 0.14), 0, cen, 0.5)
    return M


def xside(a, x, y, ang, s, fc, sepc="unripe", veins=None, sepals="hug"):
    """A cross seen from the side: the narrow sepals standing up round the
    petal claws ("hug"), or spread out ("flat"), and the petal blades
    opening out at the top."""
    t = T(x, y, ang)
    if sepals == "hug":
        for off in (-0.9, 0.9):
            a.shape(f"M{P(t(0, off * 0.6 * s))} Q{P(t(4 * s, off * 1.9 * s))} {P(t(7.2 * s, off * 1.0 * s))} L{P(t(6.2 * s, 0))} Z", sepc, 0.6)
        top = t(6.6 * s)
    else:
        for off in (-1, 1):
            small_leaf(a, *t(1.2 * s), ang + off * 70, 5.5 * s, 0.24, sepc, 0.55)
        top = t(1.6 * s)
    for off, L, b in ((-58, 9.5, 0.55), (58, 9.5, 0.55), (-18, 8.5, 0.5), (18, 8.5, 0.5)):
        g = ang + off
        a.leaf(top[0], top[1], g, L * s, b, fc, lw=0.7, skew=0.66, detail=False)
        if veins and s > 0.5:
            e = T(*top, g)
            a.line(f"M{P(e(L * s * 0.3))} L{P(e(L * s * 0.85))}", 0.4, 0.85, veins)
    for off in (-8, 8):   # stamens poking out
        e = T(*top, ang + off)(4.4 * s); a.line(f"M{P(top)} L{P(e)}", 0.35, 0.7); a.dot(e[0], e[1], max(0.35, 0.5 * s), "sun")


def xbud(a, x, y, ang, L, col="unripe"):
    a.leaf(x, y, ang, L, 0.46, col, lw=0.6, detail=False)
    if L >= 4:
        a.line(f"M{P(T(x, y, ang)(L * 0.25))} L{P(T(x, y, ang)(L * 0.88))}", 0.35, 0.5)


def xpod(a, x, y, ang, L, col, beak=0.25, w=1.6, bumps=4, flatbeak=False):
    """A slender pod (siliqua) with a beak at its tip; bumps over the seeds."""
    t = T(x, y, ang); Lb = L * (1 - beak)
    def hw(u, side):
        v = u * Lb
        b = 1 + 0.14 * abs(math.sin(math.pi * u * bumps)) if bumps else 1
        return w / 2 * b * min(1, u / 0.06) * (1 if u < 0.92 else (1 - (u - 0.92) / 0.08) ** 0.5 + 0.25)
    small = w < 2.2
    _rblade(a, x, y, ang, Lb, hw, col, lw=0.5 if small else 0.6, midw=0 if small else 0.3, shade=0 if small else 0.08, n=40)
    e = t(Lb)
    if flatbeak:   # rocket and mustard: a flat sword-shaped beak
        a.leaf(e[0], e[1], ang, L * beak, 0.18, col, lw=0.6, detail=False)
    else:
        a.line(f"M{P(t(Lb * 0.98))} L{P(t(L))}", 0.6, 0.85)


def fl_cross(a, sp):
    """The cabbage family's flowers: a raceme of four-petalled crosses.
    mode "buds_up": the closed buds stand above the open flowers at the top
    of a lengthening spike (cabbage, cauliflower, broccoli, sprouts, mustard,
    rocket, cress); "flat": the newly opened flowers are held above the
    buds, so the top is flat (mizuna, pak choi)."""
    fc = sp["fc"]; mode = sp.get("mode", "buds_up"); sepals = sp.get("sepals", "hug"); sepc = sp.get("sepc", "unripe")
    veins = sp.get("veins"); R = sp.get("R", 16)
    q = Quad((54, 98), (50, 64), (48, 24))
    a.ribbon(q.p0, q.c, q.p1, 3.0, 1.8, "leaf", lw=0.9)
    if sp.get("pods"):   # young pods lower down the spike
        for u, sd in ((0.18, 1), (0.3, -1)):
            x, y = q.pt(u); g = -90 + sd * 32
            a.line(f"M{f(x)},{f(y)} L{P(T(x, y, -90 + sd * 60)(4))}", 0.7, 0.85)
            e = T(x, y, -90 + sd * 60)(4)
            xpod(a, e[0], e[1], g, sp.get("podl", 18), "unripe", beak=sp.get("beak", 0.2), w=sp.get("podw", 2.4), flatbeak=sp.get("flatbeak", False))
    if mode == "flat":
        hub = q.pt(0.72)
        buds = [(hub[0] - 4, hub[1] - 7, -112, 5), (hub[0] + 3.5, hub[1] - 7.5, -68, 5), (hub[0], hub[1] - 9, -90, 4.8),
                (hub[0] - 7, hub[1] - 4, -150, 4.6), (hub[0] + 7, hub[1] - 4.5, -30, 4.6)]
        flowers = [(20, 30, R * 0.92, -1), (80, 30, R * 0.92, 1), (40, 20, R, -1), (62, 19, R, 1)]
        side = [(26, 52, -130, 0.9), (75, 50, -50, 0.9)]
        for x, y, g, L in buds:
            a.line(f"M{P(hub)} L{f(x)},{f(y)}", 0.6, 0.8)
        for x, y, r_, sd in flowers:
            a.line(f"M{P(hub)} Q{f(hub[0] + (x - hub[0]) * 0.3)},{f(hub[1] - 14)} {f(x)},{f(y + r_ * 0.3)}", 0.85, 0.85)
        for x, y, g, s in side:
            st = q.pt(0.5); a.line(f"M{P(st)} Q{f(st[0] + (x - st[0]) * 0.55)},{f(min(st[1], y) - 3)} {f(x)},{f(y)}", 0.8, 0.85)
            xside(a, x, y, g, s, fc, sepc, veins, sepals)
        for x, y, r_, sd in sorted(flowers, key=lambda f_: f_[1]):
            xflower(a, x, y, r_, fc, k=0.74, start=-45 + sd * 10, veins=veins, sepals=sepals, sepc=sepc, prof=sp.get("prof", "claw"), pw=sp.get("pw", 0.7))
        for x, y, g, L in buds:
            xbud(a, x, y, g, L)
        return a
    # buds above the open flowers: a lengthening spike
    top = q.pt(1)
    a.line(f"M{P(top)} Q{f(top[0] - 1)},{f(top[1] - 8)} {f(top[0] + 1)},{f(top[1] - 14)}", 1.1, 0.85)
    tip = (top[0] + 1, top[1] - 14)
    buds = [(tip[0], tip[1] - 1, -90, 5.4), (tip[0] - 3.2, tip[1] + 2.5, -125, 5.2), (tip[0] + 3.2, tip[1] + 3, -55, 5.2),
            (tip[0] - 4.5, tip[1] + 7, -145, 5.4), (tip[0] + 4.8, tip[1] + 8, -35, 5.4), (tip[0] - 1, tip[1] + 4, -100, 5)]
    for x, y, g, L in buds:
        a.line(f"M{f(tip[0])},{f(y + 4)} L{f(x)},{f(y)}", 0.55, 0.8)
    flowers = sp.get("flowers", [(0.62, -1, R), (0.74, 1, R * 0.92)])
    sides = sp.get("sides", [(0.46, 1, 1.0), (0.86, -1, 0.8)])
    for u, sd, s in sides:
        x, y = q.pt(u); e = (x + sd * 13 * s, y - 6 * s)
        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 7 * s)},{f(y - 1)} {P(e)}", 0.8, 0.85)
        xside(a, e[0], e[1], -90 + sd * 46, s * 1.25, fc, sepc, veins, sepals)
    for x, y, g, L in buds:
        xbud(a, x, y, g, L)
    for u, sd, r_ in flowers:
        x, y = q.pt(u); e = (x + sd * (r_ + 6), y - 4)
        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 6)},{f(y - 1)} {f(e[0])},{f(e[1] + r_ * 0.3)}", 0.9, 0.85)
        xflower(a, e[0], e[1], r_, fc, k=0.8, start=-45 + sd * 8, veins=veins, sepals=sepals, sepc=sepc, prof=sp.get("prof", "claw"), pw=sp.get("pw", 0.7))
    return a


def fl_cress(a, sp):
    """Garden cress: tiny white crosses crowded at the tip of a spike that
    lengthens as it flowers, small flat round notched pods below."""
    fc = sp["fc"]
    q = Quad((50, 98), (52, 60), (48, 18))
    a.ribbon(q.p0, q.c, q.p1, 2.6, 1.4, "sage", lw=0.9)
    for i, u in enumerate((0.12, 0.2, 0.28, 0.36)):   # pods pressed up against the stem
        x, y = q.pt(u); sd = 1 if i % 2 else -1
        e = (x + sd * 4, y - 3); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 3)},{f(y)} {P(e)}", 0.6, 0.85)
        notched_pod(a, e[0], e[1] - 3.4, 3.6, "unripe", -90 + sd * 12)
    for i, u in enumerate((0.46, 0.52, 0.58, 0.64, 0.7, 0.75, 0.8, 0.85)):
        x, y = q.pt(u); sd = -1 if i % 2 else 1; R = 6.4 - i * 0.2
        e = (x + sd * (R + 1.2), y - 1.5)
        a.line(f"M{f(x)},{f(y)} L{f(e[0])},{f(e[1] + 1)}", 0.6, 0.85)
        xflower(a, e[0], e[1], R, fc, k=0.8, start=-45 + sd * 6 + i * 9, sepals="hug", sepc="sage", lw=0.6, prof="spoon", pw=0.6)
    tip = q.pt(1)
    for x, y, g, L in ((tip[0], tip[1] - 2, -90, 4.4), (tip[0] - 3, tip[1] + 1, -130, 4.2), (tip[0] + 3, tip[1] + 1.5, -50, 4.2),
                       (tip[0] - 2, tip[1] + 4.5, -150, 4), (tip[0] + 2.5, tip[1] + 5, -30, 4)):
        a.line(f"M{P(tip)} L{f(x)},{f(y)}", 0.5, 0.8); xbud(a, x, y, g, L, "sage")
    return a


def notched_pod(a, x, y, r, col, ang=-90):
    """Cress's pod: a small flat round to oval disc with a narrow wing and a
    notch at its tip."""
    t = T(x, y, ang + 90)
    pts = []
    for j in range(60):
        h = 2 * math.pi * j / 60
        rr = r * (1 - 0.6 * math.exp(-((h + math.pi / 2) / 0.3) ** 2))
        pts.append(t(rr * math.cos(h) * 0.85, rr * math.sin(h)))
    a.shape(path(pts), col, 0.6)
    a.line(f"M{P(t(0, -r * 0.55))} L{P(t(0, r * 0.85))}", 0.35, 0.45)


# ---- the daisy family: heads of strap-shaped florets (lettuce, chicory)
def lig_head(a, x, y, R, fc, k=0.62, n=16, styles="amber", invol=True, bractc="leaf", outer=False, rot=0, lw=0.65, ch=0.95, cw=0.3):
    """A head of strap-shaped florets only, tipped back (k), with the slim
    cup of bracts (the involucre) below it, ch deep and cw wide (as shares
    of R). styles: the colour of the forked styles in the middle. outer:
    chicory's short outer bracts turned out at the foot of the cup."""
    LFW = _lfw()
    if invol:   # the cup of narrow overlapping bracts, longer than wide
        h = R * ch; w = R * cw
        a.shape(f"M{f(x - w)},{f(y)} L{f(x - w * 0.66)},{f(y + h)} Q{f(x)},{f(y + h + w * 0.45)} {f(x + w * 0.66)},{f(y + h)} L{f(x + w)},{f(y)} Z", bractc, lw)
        a.shape(f"M{f(x + w * 0.1)},{f(y)} L{f(x + w * 0.1)},{f(y + h + w * 0.2)} Q{f(x + w * 0.5)},{f(y + h + w * 0.2)} {f(x + w * 0.66)},{f(y + h)} L{f(x + w)},{f(y)} Z", "shade", 0, fa=0.1)
        rows = 4 if ch > 0.7 else 2
        for j in range(rows):   # the bracts overlapping like roof tiles
            by = y + h * (0.62 + 0.38 * j / max(1, rows - 1)) - h * 0.1 * (rows > 2)
            ww = w * (1 - 0.3 * (by - y) / h)
            for i in range(3):
                bx = x + (i - 1) * ww * 0.62 + (ww * 0.3 if j % 2 else 0)
                if abs(bx - x) > ww * 0.95:
                    continue
                a.line(f"M{f(bx - ww * 0.26)},{f(by + h * 0.1)} L{f(bx)},{f(by - h * 0.12)} L{f(bx + ww * 0.26)},{f(by + h * 0.1)}", 0.4, 0.55)
        if outer:
            for sd in (-1, 1):
                small_leaf(a, x + sd * w * 0.7, y + h * 0.8, 90 + sd * 64, R * 0.4, 0.22, bractc, 0.55)
    LFW.ring_of_petals(a, n, R, R * 0.2, fc, "ray", cx=x, cy=y, k=k, start=-90 + rot, tip="teeth", lw=lw)
    LFW.ring_of_petals(a, 8, R * 0.42, R * 0.16, fc, "ray", cx=x, cy=y - 0.3, k=k, start=-68 + rot, tip="teeth", lw=lw * 0.85)
    for j in range(7):   # the forked styles standing up in the middle
        th = j * GOLD; rr = R * 0.16 * math.sqrt((j + 0.5) / 7)
        px, py = x + rr * math.cos(th), y + rr * math.sin(th) * k
        hgt = R * 0.16
        a.line(f"M{f(px)},{f(py)} L{f(px)},{f(py - hgt)}", 0.55 if R > 8 else 0.4, 0.95, styles)
        a.line(f"M{f(px - R * 0.04)},{f(py - hgt - R * 0.05)} L{f(px)},{f(py - hgt)} L{f(px + R * 0.04)},{f(py - hgt - R * 0.05)}", 0.4, 0.95, styles)


def lig_side(a, x, y, ang, R, fc, bractc="leaf", closed=False, lw=0.6):
    """A small head of the lettuce kind seen from the side on its stalk: the
    slim bract cup and the florets spreading out of its top, or (closed)
    just the cup, its tip pinched."""
    t = T(x, y, ang); h = R * 0.95; w = R * 0.3
    a.shape(f"M{P(t(0, -w * 0.45))} Q{P(t(h * 0.5, -w * 1.05))} {P(t(h, -w * (0.55 if closed else 0.9)))} L{P(t(h, w * (0.55 if closed else 0.9)))} Q{P(t(h * 0.5, w * 1.05))} {P(t(0, w * 0.45))} Z", bractc, lw)
    for v in (0.35, 0.65):
        a.line(f"M{P(t(h * v, -w * 0.7))} L{P(t(h * (v + 0.18), 0))} L{P(t(h * v, w * 0.7))}", 0.35, 0.5)
    if closed:
        a.line(f"M{P(t(h, -w * 0.5))} L{P(t(h * 1.18, 0))} L{P(t(h, w * 0.5))}", 0.5, 0.85)
        return
    e = t(h)
    for off in (-62, -40, -18, 0, 18, 40, 62):
        g = ang + off
        a.leaf(e[0], e[1], g, R * (0.95 - abs(off) * 0.002), 0.16, fc, lw=0.5, skew=0.7, detail=False)


def cup_foot(R, ch, cw):
    """How far below a head's middle the foot of its bract cup is."""
    return R * ch + R * cw * 0.45


def fl_ligule(a, sp):
    """Lettuce, leaf salad, celtuce: small pale yellow heads of strap-shaped
    florets, like little dandelions, each sitting on a slim cylindrical cup
    of overlapping bracts at the tip of its stalk; one open, one seen from
    the side, one still closed."""
    fc = sp["fc"]; sty = sp.get("styles", "amber")
    hub = (52, 72)
    a.ribbon((50, 98), (51, 86), hub, 2.8, 2.2, "leaf", lw=0.9)
    hx, hy, HR = 42, 30, 22
    foot = (hx, hy + cup_foot(HR, 0.72, 0.28))
    a.ribbon(hub, (hub[0] - 2, foot[1] + 8), foot, 1.8, 1.6, "leaf", lw=0.8)
    a.ribbon(hub, (72, 66), (80, 54), 1.5, 1.3, "leaf", lw=0.7)
    a.ribbon(hub, (34, 74), (22, 66), 1.4, 1.2, "leaf", lw=0.7)
    for g in (-160, -20):
        small_leaf(a, hub[0], hub[1], g, 10, 0.3, "leaf")
    lig_side(a, 22, 66, -130, 10, fc, closed=True)
    lig_side(a, 80, 54, -64, 14, fc)
    lig_head(a, hx, hy, HR, fc, k=0.55, n=16, styles=sty, ch=0.72, cw=0.28, lw=0.75)
    return a


def fl_chicory(a, sp):
    """Chicory: big sky-blue heads of strap-shaped florets with squared,
    toothed tips, blue styles in the middle, stalkless on a stiff stem; two
    rows of bracts behind, the outer short ones turned out."""
    fc = sp["fc"]; cen = sp.get("cen", fc)
    q = Quad((62, 98), (58, 56), (44, 8))
    a.ribbon(q.p0, q.c, q.p1, 3.0, 2.0, "leaf", lw=0.9)
    x, y = q.pt(0.12)
    _rblade(a, x, y, -20, 15, lambda u, s_: 3.4 * math.sin(math.pi * min(1, u) ** 0.6) ** 0.8, "leaf", lw=0.8, midw=0.4)   # small clasping stem leaf
    x, y = q.pt(0.36)   # a smaller head sitting on the stem, no stalk
    lig_head(a, x + 6, y - cup_foot(12, 0.6, 0.34) + 1, 12, fc, k=0.6, n=15, styles=cen, outer=True, rot=-10, ch=0.6, cw=0.34)
    x, y = q.pt(0.94); lig_side(a, x, y, -100, 9, fc, closed=True)
    x, y = q.pt(0.62)   # the big open head, also sitting on the stem
    cx, cy = x - 12, y - cup_foot(24, 0.5, 0.3) + 2
    lig_head(a, cx, cy, 24, fc, k=0.62, n=17, styles=cen, outer=True, lw=0.8, ch=0.5, cw=0.3)
    for j in range(5):   # the dark anthers round the styles
        th = j * 1.256 + 0.3; px, py = cx + 2.6 * math.cos(th), cy + 2.6 * math.sin(th) * 0.82
        a.dot(px, py - 1.5, 0.75, sp.get("anth", "plum"))
    return a


# ---- the goosefoot family and the docks: tiny flowers without petals
def glom(a, x, y, r, col="unripe", anth=None, n=7, tep="unripe"):
    """A tight ball of tiny green flowers, each a few curved tepals; anth
    gives yellow stamens hanging out of it (a male spinach cluster)."""
    a.oval(x, y, r, r * 0.9, 0, col, 0.6)
    for j in range(n):
        th = j * GOLD; rr = r * 0.62 * math.sqrt((j + 0.5) / n)
        px, py = x + rr * math.cos(th), y + rr * math.sin(th) * 0.9
        for m in range(4):
            e = T(px, py, m * 90 + j * 20)(r * 0.22)
            a.line(f"M{f(px)},{f(py)} L{P(e)}", 0.35, 0.5)
    if anth:
        for j in range(5):
            g = -150 + 60 * j + (j % 2) * 15
            e0 = T(x, y, g)(r * 0.8); e1 = T(x, y, g)(r * 1.45)
            a.line(f"M{P(e0)} L{P(e1)}", 0.4, 0.75); a.oval(e1[0], e1[1], max(0.6, r * 0.24), max(0.45, r * 0.17), g, anth, 0.35)


def fl_spinach(a, sp):
    """Spinach (a male plant): tiny green flowers with no petals in dense
    rounded clusters along a leafless spike at the top of the stem, their
    yellow stamens hanging out; a pointed arrow-shaped stem leaf below."""
    q = Quad((46, 98), (50, 60), (52, 10))
    a.ribbon(q.p0, q.c, q.p1, 2.8, 1.4, "leaf", lw=0.9)
    x, y = q.pt(0.16)
    put_shape(a, "spinach_stem", x, y, -32, 24)
    for i, u in enumerate((0.3, 0.42, 0.53, 0.63, 0.72, 0.8, 0.87, 0.93)):
        x, y = q.pt(u); s = 1 - 0.45 * i / 8
        for sd in ((-1, 1) if i < 6 else (0,)):
            glom(a, x + sd * 3.6 * s, y - 0.5, 3.0 * s, sp.get("fc", "unripe"), anth="leaves_yellow", n=5)
    x, y = q.pt(1); glom(a, x, y - 1, 2.6, sp.get("fc", "unripe"))
    return a


def beetflower(a, x, y, r, cen):
    a.oval(x, y + r * 0.3, r, r * 0.8, 0, "unripe", 0.55)
    for k in range(5):   # the five segments curving in
        e = T(x, y, -90 + 72 * k)(r * 0.85)
        a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.4, 0.55)
    a.dot(x, y - r * 0.1, max(0.35, r * 0.28), cen)


def fl_beetspike(a, sp):
    """Chard and spinach beet (copied from the root group's beetroot
    spike): tiny green flowers with no petals, two or three together,
    stalkless, spaced along slender spikes that arch at their tips, a small
    narrow bract under each cluster."""
    q = Quad((44, 98), (40, 50), (64, 8))
    a.ribbon(q.p0, q.c, q.p1, 2.2, 1.0, "leaf", lw=0.8)
    sub = Quad(q.pt(0.36), (22, 50), (16, 30))
    a.ribbon(sub.p0, sub.c, sub.p1, 1.5, 0.8, "leaf", lw=0.7)
    for qq, us, s0 in ((q, [0.3, 0.42, 0.53, 0.63, 0.72, 0.8, 0.87, 0.93, 0.98], 1.0), (sub, [0.25, 0.45, 0.63, 0.8, 0.94], 0.8)):
        for i, u in enumerate(us):
            x, y = qq.pt(u); g = qq.ang(u); sd = 1 if i % 2 else -1; s = s0 * (1 - 0.45 * i / len(us))
            small_leaf(a, x, y, g + sd * 50, 9 * s, 3.4 / 9, "leaf")   # the bract
            for m, (dx, dy) in enumerate(((0, 0), (-1, -0.9), (1, -0.8))[: 2 if i % 3 else 3]):
                px, py = T(x, y, g - sd * 90)(3.0 * s); px += dx * 2.6 * s; py += dy * 2.6 * s
                beetflower(a, px, py, 2.4 * s, sp.get("cen", "pear"))
    return a


def fl_gkh(a, sp):
    """Good King Henry: tiny green flowers without petals packed into
    narrow, leafless, upright spikes tapering to a point, at the top of the
    stem and from the upper leaf joints; arrow-shaped leaves below."""
    q = Quad((50, 98), (50, 60), (50, 6))
    a.ribbon(q.p0, q.c, q.p1, 2.8, 1.4, "leaf", lw=0.9)
    x, y = q.pt(0.14); put_shape(a, "gkh", x, y, -150, 22)
    x, y = q.pt(0.22); put_shape(a, "gkh", x, y, -28, 20)
    for u0, sd, L in ((0.38, -1, 26), (0.5, 1, 24)):
        x, y = q.pt(u0); e = (x + sd * 14, y - L)
        a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 10)},{f(y - 4)} {P(e)}", 1.0, 0.85)
        spike_dense(a, (x + sd * 9, y - 6), e, 4.6, sp.get("fc", "unripe"), sp.get("cen", "pear"))
    spike_dense(a, q.pt(0.52), q.pt(1), 6.0, sp.get("fc", "unripe"), sp.get("cen", "pear"))
    return a


def spike_dense(a, p0, p1, w, col, anth, n=None):
    """A narrow tapering spike packed with tiny flower clusters."""
    L = math.dist(p0, p1); n = n or max(6, int(L / 2.2))
    g = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0])); t = T(*p0, g)
    for i in range(n):
        u = i / (n - 1); r = w * 0.5 * (1 - 0.7 * u) + 0.6
        for sd in (-1, 1):
            c = t(L * u, sd * r * 0.45)
            a.oval(c[0], c[1], r * 0.62, r * 0.55, 0, col, 0.5)
            if i % 3 == 1 and anth and w > 3:
                a.dot(c[0] + sd * r * 0.4, c[1] - r * 0.2, max(0.35, r * 0.16), anth)


def fl_orache(a, sp):
    """Orache: tiny flowers without petals in long branched spikes; each
    female flower sits between two flat round bracts, which grow into the
    papery seed discs. All red-purple like the leaves."""
    fc = sp["fc"]
    q = Quad((46, 98), (50, 56), (56, 8))
    a.ribbon(q.p0, q.c, q.p1, 2.4, 1.2, fc, lw=0.9)
    x, y = q.pt(0.16); put_shape(a, "orach", x, y, -30, 20)
    for u0, sd, e in ((0.36, -1, (18, 32)), (0.52, 1, (82, 26))):
        x, y = q.pt(u0); qq = Quad((x, y), (x + sd * 12, y - 4), e)
        a.line(qq.d(), 0.9, 0.85)
        for i in range(6):
            u = 0.3 + 0.7 * i / 5; px, py = qq.pt(u)
            discs(a, px, py, 3.4 * (1 - 0.35 * u), fc, qq.ang(u) + (90 if i % 2 else -90))
    for i in range(9):
        u = 0.36 + 0.62 * i / 8; px, py = q.pt(u)
        discs(a, px, py, 4.0 * (1 - 0.4 * u), fc, q.ang(u) + (90 if i % 2 else -90))
    return a


def discs(a, x, y, r, col, ang):
    """A female orache flower: two flat round bracts face to face, the tiny
    flower showing between them."""
    c = T(x, y, ang)(r * 0.9)
    a.oval(c[0], c[1], r, r * 0.92, ang, col, 0.6)
    a.line(f"M{P(T(*c, ang + 90)(r * 0.9))} L{P(T(*c, ang - 90)(r * 0.9))}", 0.4, 0.6)
    a.dot(c[0], c[1], max(0.35, r * 0.16), "unripe")


def fl_sorrel(a, sp):
    """Sorrel: tiny flowers without petals in small spaced whorls along
    slender upright branched spikes, green flushed red; on a female plant
    tufts of feathery red stigmas."""
    fc = sp["fc"]
    q = Quad((50, 98), (49, 56), (52, 6))
    a.ribbon(q.p0, q.c, q.p1, 2.4, 1.2, "leaf", lw=0.9)
    x, y = q.pt(0.12)
    a.shape(f"M{f(x - 1.6)},{f(y)} L{f(x - 1.2)},{f(y - 5)} L{f(x + 1.4)},{f(y - 5.4)} L{f(x + 1.6)},{f(y)} Z", "straw", 0.5)   # the papery sheath (ochrea)
    put_shape(a, "sorrel_stem", x, y - 2, -36, 22)
    branches = [(0.4, -1, (20, 30)), (0.56, 1, (80, 26)), (0.7, -1, (32, 16))]
    for u0, sd, e in branches:
        x, y = q.pt(u0); qq = Quad((x, y), (x + sd * 8, y - 6), e)
        a.line(qq.d(), 0.8, 0.85)
        for i in range(5):
            u = 0.25 + 0.75 * i / 4; px, py = qq.pt(u); whorl(a, px, py, 2.6 * (1 - 0.3 * u), fc, sp.get("cen", fc))
    for i in range(10):
        u = 0.3 + 0.7 * i / 9; px, py = q.pt(u); whorl(a, px, py, 3.0 * (1 - 0.3 * u), fc, sp.get("cen", fc))
    return a


def whorl(a, x, y, r, col, stig):
    """A small whorl of tiny dock flowers round a stem: a few tepal clusters
    and, on the female flowers, feathery red stigmas."""
    for sd in (-1, 1):
        c = (x + sd * r * 0.75, y)
        a.oval(c[0], c[1], r * 0.62, r * 0.5, 0, col, 0.5)
        a.line(f"M{P(c)} l{f(sd * r * 0.6)},{f(-r * 0.5)} M{P(c)} l{f(sd * r * 0.7)},{f(-r * 0.05)}", 0.4, 0.9, "berry")
    a.oval(x, y - r * 0.15, r * 0.5, r * 0.42, 0, col, 0.5)


def fl_cornsalad(a, sp):
    """Lamb's lettuce: tiny pale lilac-blue flowers, each a short tube with
    five rounded lobes, packed into small flat-topped clusters at the tips
    of stems that fork again and again in twos, a pair of narrow leaves at
    each fork."""
    fc = sp["fc"]
    a.ribbon((50, 98), (50, 82), (50, 70), 2.2, 1.8, "leaf", lw=0.8)
    for sd in (-1, 1):
        small_leaf(a, 50, 70, -90 + sd * 64, 15, 0.22, "deep", 0.8)
    forks = [((50, 70), (32, 46)), ((50, 70), (68, 44))]
    tips = []
    for p0, p1 in forks:
        a.line(f"M{P(p0)} Q{f((p0[0] + p1[0]) / 2)},{f(p0[1] - 8)} {P(p1)}", 1.2, 0.85)
        for sd in (-1, 1):
            small_leaf(a, p1[0], p1[1], -90 + sd * 70, 8, 0.24, "deep", 0.7)
            e = (p1[0] + sd * 10, p1[1] - 12); a.line(f"M{P(p1)} Q{f(p1[0] + sd * 3)},{f(p1[1] - 8)} {P(e)}", 0.9, 0.85)
            tips.append(e)
        tips.append((p1[0], p1[1] - 4))
    for k, (x, y) in enumerate(tips):
        big = k in (0, 3)
        cluster(a, x, y - (3 if big else 1), 11 if big else 8, fc, "blue")
    return a


def five_lobed(a, x, y, r, fc, rot=0, cen="blue", lw=0.45):
    """One tiny lamb's lettuce flower seen from above: a short tube opening
    into five rounded lobes, with a dark eye."""
    a.polar(x, y, lambda h: 0.58 + 0.42 * abs(math.cos(2.5 * (h - math.radians(rot)))) ** 0.7, r, r, 0, fc, lw, shade=False)
    a.dot(x, y, max(0.3, r * 0.2), cen)


def cluster(a, x, y, R, fc, cen):
    """A small flat-topped cluster of tiny five-lobed flowers, a few seen
    face on along the top and a pair of small bracts beneath."""
    for sd in (-1, 1):
        small_leaf(a, x, y + R * 0.35, -90 + sd * 80, R * 0.7, 0.24, "leaf", 0.5)
    spots = [(-0.62, 0.05), (0.62, 0.05), (-0.3, 0.2), (0.32, 0.22), (0.0, 0.0), (-0.32, -0.22), (0.3, -0.24)]
    for dx, dy in sorted(spots, key=lambda q: q[1]):
        five_lobed(a, x + dx * R, y + dy * R * 0.8, R * 0.32, fc, rot=dx * 50)


BLOOM_DRAW = {"leaves_cross": fl_cross, "leaves_cress": fl_cress, "leaves_ligule": fl_ligule, "leaves_chicory": fl_chicory,
              "leaves_spinach": fl_spinach, "leaves_beetspike": fl_beetspike, "leaves_gkh": fl_gkh, "leaves_orache": fl_orache,
              "leaves_sorrel": fl_sorrel, "leaves_cornsalad": fl_cornsalad}

_XB = dict(kind="leaves_cross", mode="buds_up", sepals="hug", pods=True, podl=20, beak=0.1, podw=2.2)
BLOOMX = {
    "lettuce": dict(kind="leaves_ligule", fc="primrose"),
    "leaf-salad": dict(kind="leaves_ligule", fc="primrose"),
    "celtuce": dict(kind="leaves_ligule", fc="primrose"),
    "chicory": dict(kind="leaves_chicory", fc="blue"),
    "cabbage": dict(_XB, fc="primrose"),
    "cauliflower": dict(_XB, fc="primrose"),
    "broccoli": dict(_XB, fc="primrose"),
    "broccoli-sprouting": dict(_XB, fc="primrose"),
    "brussels-sprouts": dict(_XB, fc="primrose"),
    "mizuna": dict(kind="leaves_cross", mode="flat", sepals="hug", fc="leaves_yellow", R=13),
    "pak-choi": dict(kind="leaves_cross", mode="flat", sepals="hug", fc="leaves_yellow", R=13),
    "mustard": dict(kind="leaves_cross", mode="buds_up", sepals="flat", fc="leaves_yellow", pods=True, podl=16, beak=0.5, podw=3.0, flatbeak=True),
    "rocket-salad": dict(kind="leaves_cross", mode="buds_up", sepals="hug", sepc="plum", veins="plum", fc="white", pods=True, podl=14,
                         beak=0.32, podw=3.2, flatbeak=True, R=18, prof="spoon", pw=0.62),
    "cress": dict(kind="leaves_cress", fc="white"),
    "spinach": dict(kind="leaves_spinach"),
    "swiss-chard": dict(kind="leaves_beetspike"),
    "spinach-beet": dict(kind="leaves_beetspike"),
    "good-king-henry": dict(kind="leaves_gkh"),
    "purple-orach": dict(kind="leaves_orache", fc="leaves_orache"),
    "sorrel": dict(kind="leaves_sorrel", fc="rust"),
    "lambs-lettuce": dict(kind="leaves_cornsalad", fc="blue"),
}


# small shapes used inside the flower close-ups
def put_shape(a, name, x, y, ang, L, fill=None):
    """A small stem leaf inside a flower close-up: spinach's pointed arrow,
    Good King Henry's or orache's triangle, sorrel's clasping arrow."""
    fill = fill or {"spinach_stem": "marrow", "gkh": "deep", "orach": "leaves_orache", "sorrel_stem": "leaf"}[name]
    sp = {"spinach_stem": dict(W=0.5, p=0.3, q=1.1, lobes=[(0.03, -40, 3.5, 3.4, 1.2, 0)], tipr=1.2),
          "gkh": dict(W=0.78, p=0.24, q=1.0, lobes=[(0.03, -36, 3.5, 3.4, 1.3, 0)], tipr=1.3),
          "orach": dict(W=0.7, p=0.22, q=0.95, lobes=[(0.03, -18, 3, 3, 1.2, 0)], tipr=1.2),
          "sorrel_stem": dict(W=0.3, p=0.32, q=0.9, lobes=[(0.035, -80, 4, 2.4, 1.0, 0)], tipr=1.0)}[name]
    src = leaf_engine(Art(), dict(sp, fill=fill, petiole=0.12 if name != "sorrel_stem" else 0.02, sw=1.6, len=60, wing=0.3,
                                  midw=0.7, veins=3, veina=0.35, n=90))
    a.place(src, x, y, ang, L / 60, lw=0.8, detail=True)


# ===================================================== life-stage pieces
_OWN = {}
GREENS = ("leaf", "deep", "sage", "pale", "unripe", "marrow", "beet", "leaves_orache", "leaves_rib", "leaves_head", "white", "berry", "plum", "leaves_rib", "sun", "pink", "carrot", "primrose")


def own(slug):
    if slug not in _OWN:
        _OWN[slug] = _lfw().own_leaf(slug)
    return _OWN[slug]


def put(a, slug, x, y, ang, L, fills=None, detail=None, lw=None, dry=False):
    """The kind's own close-up leaf drawn L long at x,y, pointing along ang,
    so a leaf on the whole plant is the same leaf as the close-up. dry: all
    its colours turned to straw (a plant gone to seed)."""
    src, f0 = own(slug)
    if dry:
        fills = {c: "straw" for c in GREENS}
    if lw is None:
        lw = 0.6 if L < 22 else (0.75 if L < 36 else 0.9)
    a.place(src, x, y, ang, L / 95, lw=lw, detail=(L >= 26) if detail is None else detail, fills=fills)


def tuft(a, slug, x, y, leaves, **kw):
    """Several of the kind's own leaves from one point: (angle, length) each."""
    for ang, L in leaves:
        put(a, slug, x, y, ang, L, **kw)


def soil(a, y, marks=True):
    a.ground(y, marks=marks)


def below(a, y0=40):
    """Flecks of soil under the line, for a picture that is mostly underground."""
    for dx, dy, w in [(-30, 6, 4), (27, 10, 3), (-24, 40, 3), (28, 36, 4)]:
        a.line(f"M{50 + dx},{y0 + dy} L{50 + dx + w},{y0 + dy}", 0.9, 0.55, "soil")


def seed_art(fn):
    def draw():
        a = Art(); a.ground(40, marks=False); below(a); fn(a, 50, 64); return a
    return draw


# ------------------------------------------------------------------ seeds
def achenes(cols):
    """Lettuce and its kin: slim, flat seeds 3 to 4 mm with fine lengthwise
    ribs, narrowing at the top into a point (where the beak and its plume
    were), drawn large. One of each colour given."""
    def fn(a, x, y):
        spots = [(-18, 0, -70), (0, -3, -95), (18, 2, -110)][: len(cols)]
        for (dx, dy, g), c in zip(spots, cols):
            t = T(x + dx, y + dy + 12, g); L = 27; W = 6.4
            hw = lambda u, s_: W / 2 * math.sin(math.pi * min(1, u) ** 0.8) ** 0.75 * (1 - 0.55 * max(0, u - 0.7) / 0.3)
            _rblade(a, x + dx, y + dy + 12, g, L, hw, c, lw=0.9, midw=0, shade=0.12)
            for o in (-0.5, -0.17, 0.17, 0.5):
                a.line(opath([t(L * u, o * hw(u, 1) * 1.6) for u in (0.12, 0.45, 0.8)]), 0.45, 0.45, "line" if c != "dark" else "straw")
            a.line(f"M{P(t(L * 0.98))} L{P(t(L * 1.1))}", 0.8, 0.85)
    return fn


def round_seeds(cols, r=5.0, shine=True, spots=None):
    """Small round seeds, drawn large, with a small shine."""
    def fn(a, x, y):
        sp_ = spots or [(-11, 3, 1.0), (6, -4, 1.08), (3, 9, 0.92), (15, 6, 0.86)]
        for i, (dx, dy, k) in enumerate(sp_):
            c = cols[i % len(cols)]; rr = r * k
            a.polar(x + dx, y + dy, lambda h: 1 + 0.03 * math.cos(3 * h + i), rr, rr * 0.94, dx * 5, c)
            if shine:
                a.line(f"M{f(x + dx - rr * 0.5)},{f(y + dy - rr * 0.2)} Q{f(x + dx - rr * 0.35)},{f(y + dy - rr * 0.62)} {f(x + dx + rr * 0.05)},{f(y + dy - rr * 0.66)}", 0.8, 0.6, "white")
    return fn


def spinach_seed(a, x, y):
    """Spinach: hard rounded seeds 3 to 4 mm, beige to grey-brown, each
    still in its dried flower (a small point at the top)."""
    for dx, dy, k, g in ((-11, 3, 1.0, -10), (7, -4, 1.1, 20), (4, 10, 0.9, -30)):
        a.polar(x + dx, y + dy, lambda h: 1 + 0.06 * math.cos(2 * h) + 0.03 * math.sin(5 * h), 7 * k, 6.4 * k, g, "seed")
        tp = T(x + dx, y + dy, g - 90)
        a.line(f"M{P(tp(5.6 * k))} L{P(tp(8.4 * k))}", 0.9, 0.85)
        a.line(f"M{P(tp(-3 * k, -3 * k))} Q{P(tp(0, -4.2 * k))} {P(tp(3 * k, -3 * k))}", 0.5, 0.4)


def seedball(a, x, y):
    """Beet: the corky, knobbly seed ball, light brown, two to four true
    seeds inside. One whole, one broken open to show the seeds."""
    a.polar(x - 8, y, lambda th: 1 + 0.13 * math.cos(5 * th) + 0.07 * math.sin(9 * th + 1), 11, 10, 0, "bark")
    for dx, dy in ((-4, -3), (1, 1), (5, -4), (-3, 5), (3, 6)):
        a.line(f"M{f(x - 8 + dx - 1.4)},{f(y + dy)} q1.4,-1.2 2.8,0", 0.6, 0.45)
    a.polar(x + 14, y + 6, lambda th: 1 + 0.14 * math.cos(5 * th + 1) + 0.06 * math.sin(8 * th), 8, 7.2, 20, "bark")
    a.polar(x + 14, y + 6, lambda th: 1 + 0.08 * math.cos(4 * th), 5.2, 4.4, 20, "seed", lw=0.7)
    for dx, dy in ((-2, -1), (2, 0.5), (0, 2.4)):
        a.oval(x + 14 + dx, y + 6 + dy, 1.4, 1.0, 30, "dark", 0.5)


def oval_seeds(cols, L=8, W=5.6, groove=True):
    def fn(a, x, y):
        for i, (dx, dy, g) in enumerate(((-11, 2, -20), (6, -4, 30), (4, 9, -60), (16, 5, 10))):
            c = cols[i % len(cols)]
            a.oval(x + dx, y + dy, L, W, g, c)
            if groove:
                t = T(x + dx, y + dy, g)
                a.line(f"M{P(t(-L * 0.6, W * 0.1))} Q{P(t(0, W * 0.35))} {P(t(L * 0.6, W * 0.1))}", 0.5, 0.45)
    return fn


def cornsalad_seed(a, x, y):
    """Lamb's lettuce: a tiny flattened rounded nutlet, pale brown, with a
    corky swelling on one side; no plume."""
    for dx, dy, k in ((-9, 2, 1.0), (10, -2, 0.95)):
        a.polar(x + dx, y + dy, lambda h: 1 + 0.05 * math.cos(2 * h), 8 * k, 7 * k, 0, "seed")
        a.polar(x + dx + 4 * k, y + dy, lambda h: 1, 4 * k, 6 * k, 0, "bark", lw=0.7)   # the corky swelling
        a.line(f"M{f(x + dx - 5 * k)},{f(y + dy - 2 * k)} Q{f(x + dx - 2 * k)},{f(y + dy - 4.6 * k)} {f(x + dx + 1 * k)},{f(y + dy - 4 * k)}", 0.5, 0.4)


def chicory_seed(a, x, y):
    """Chicory: small angular seeds, pale brown, topped with a tiny crown
    of scales and no fluffy hairs."""
    for dx, dy, g in ((-10, 2, -80), (6, -2, -100), (14, 6, -70)):
        t = T(x + dx, y + dy + 8, g)
        pts = [t(0, 0), t(4, -3.6), t(15, -4.2), t(17, 0), t(15, 4.2), t(4, 3.6)]
        a.shape(path(pts), "seed")
        a.line(f"M{P(t(1, 0))} L{P(t(16, 0))}", 0.5, 0.45)
        for o in (-3, -1, 1, 3):
            a.line(f"M{P(t(17, o * 1.1))} L{P(t(19, o * 1.3))}", 0.5, 0.8)


def sorrel_seed(a, x, y):
    """Sorrel: a small three-sided glossy dark brown nut inside three
    rounded papery wings, each with a tiny wart at its base."""
    for dx, dy, k in ((-8, 0, 1.0), (13, 6, 0.7)):
        cx, cy = x + dx, y + dy
        for j in range(3):
            g = -90 + 120 * j + 20; c = T(cx, cy, g)(4.6 * k)
            a.oval(c[0], c[1], 6.4 * k, 5.4 * k, g, "rust", 0.8)
            a.line(f"M{P(T(cx, cy, g)(1.5 * k))} L{P(T(cx, cy, g)(9.5 * k))}", 0.4, 0.4)
        a.polar(cx, cy, lambda h: 1 + 0.15 * math.cos(3 * h), 3.4 * k, 3.4 * k, 0, "dark", lw=0.7)
        a.line(f"M{f(cx - 1.2 * k)},{f(cy - 1.2 * k)} l{f(1.2 * k)},{f(-0.4 * k)}", 0.6, 0.6, "white")


def orache_seed(a, x, y):
    """Orache: a flat round papery disc about 1 cm (the two bracts) with
    the flat round seed in the middle; and one seed on its own."""
    a.oval(x - 5, y, 13, 12.4, 0, "plum")
    a.shape(f"M{f(x - 5)},{f(y - 12.4)} L{f(x - 5)},{f(y + 12.4)}", None, 0.5, 0.4)
    a.oval(x - 5, y, 4.4, 4.2, 0, "dark", 0.8)
    for k in range(10):
        g = k * 36; e0 = T(x - 5, y, g)(6.4); e1 = T(x - 5, y, g)(11)
        a.line(f"M{P(e0)} L{P(e1)}", 0.35, 0.3)
    a.oval(x + 16, y + 8, 3.6, 3.4, 0, "dark", 0.8)
    a.line(f"M{f(x + 14.6)},{f(y + 6.6)} l1.4,-0.4", 0.5, 0.6, "white")


# --------------------------------------------------------------- seedlings
G = 72


def stem_up(a, x, y, h, col="pale", w=1.4, lean=0.0, lw=0.8):
    a.ribbon((x, y), (x + lean * 0.3, y - h * 0.5), (x + lean, y - h), w, w * 0.85, col, lw=lw)
    return (x + lean, y - h)


def cot_pair(a, top, kind, col, L=11, spread=66):
    """A pair of seed leaves: "oval", "spoon", "strap" (long and narrow),
    "kidney" (the cabbage family: broader than long, notched at the tip,
    on short stalks) or "trident" (cress: each cut into three)."""
    for sd in (-1, 1):
        g = -90 + sd * spread
        if kind == "kidney":
            e = T(*top, g)(2.6); a.line(f"M{P(top)} L{P(e)}", 0.8, 0.85)
            c = T(*e, g)(L * 0.46)
            a.polar(c[0], c[1], lambda th: (1 - 0.34 * math.exp(-(th / 0.34) ** 2)) * (1 - 0.3 * math.exp(-((abs(th) - math.pi) / 0.5) ** 2)),
                    L * 0.46, L * 0.6, g, col)
        elif kind == "trident":
            e = T(*top, g)(L * 0.35); a.line(f"M{P(top)} L{P(e)}", 0.8, 0.85)
            for off, k in ((-40, 0.75), (40, 0.75), (0, 1.0)):
                small_leaf(a, e[0], e[1], g + off, L * 0.62 * k, 0.32, col, 0.7)
        elif kind == "strap":
            a.leaf(top[0], top[1], g, L * 1.6, 0.12, col, lw=0.8)
        elif kind == "wstrap":   # strap-shaped but broad enough to show their colour
            a.leaf(top[0], top[1], g, L * 1.4, 0.22, col, lw=0.7, skew=0.5)
        elif kind == "spoon":   # smooth, rounded at the end, narrowing to a short stalk
            hw = lambda u, s_: L * 0.25 * math.sin(math.pi * min(1, u) ** 1.25) ** 0.55
            _rblade(a, top[0], top[1], g, L, hw, col, lw=0.8, midw=0, shade=0.08)
        else:
            a.leaf(top[0], top[1], g, L, 0.36, col, lw=0.8)


def seedling(slug, cot, cotc="pale", h=12, L=11, true=None, stemc="pale", n=1, spread=66, roots=True):
    """A seedling: seed leaves on a short stem and the first true leaf (the
    kind's own leaf drawn small, or true=(fn) to draw something else).
    n > 1: a little clump or a crowded row."""
    def draw():
        a = Art(); soil(a, G)
        xs = {1: [50], 2: [44, 56], 3: [38, 50, 62], 4: [30, 43, 57, 70], 7: [35, 40, 45, 50, 55, 60, 65]}[n]
        thin = stemc in ("pale", "white")
        for i, x in enumerate(xs):
            hh = h * (1 - 0.12 * (i % 2) - (0.1 if n == 7 and i % 3 == 1 else 0)); lean = (x - 50) * 0.12
            if roots:
                a.roots(x, G, 3, 9 if n > 1 else 11, 44)
            top = stem_up(a, x, G, hh, stemc, lean=lean, w=1.4 if not thin else 1.3, lw=0.8 if not thin else 0.45)
            cot_pair(a, top, cot, cotc, L * (1 if n < 3 else 0.85), spread)
            if true:
                true(a, top, i)
        return a
    return draw


def first_leaf(slug, L=13, ang=-82, L2=None, ang2=-100, stalk=0.0, detail=False):
    """The first true leaf (or two), the kind's own leaf drawn small."""
    def fn(a, top, i):
        x, y = top
        if stalk:
            e = (x + 0.5, y - stalk); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.8, 0.85); x, y = e
        put(a, slug, x, y, ang, L, lw=0.7, detail=detail)
        if L2:
            put(a, slug, x, y, ang2, L2, lw=0.7, detail=detail)
    return fn


def simple_leaf(L, fill, b=0.5, edge=None, stalk=0.0, ang=-84, skew=0.45, dots=None, two=False):
    """A small plain first leaf: stalk long, then a blade b wide (as a
    share of L), with edge "saw" or "scallop" teeth if given."""
    def fn(a, top, i):
        for g in ((ang, -180 - ang) if two else (ang,)):
            x, y = top
            if stalk:
                e = T(x, y, g)(stalk); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.8, 0.85); x, y = e
            a.leaf(x, y, g, L, b, fill, lw=0.8, skew=skew, edge=edge)
            if dots:
                for k in range(5):
                    p = T(x, y, g)(L * (0.25 + 0.13 * k), (k % 2 - 0.5) * L * b * 0.5); a.dot(p[0], p[1], 0.35, dots)
    return fn


def round_first(r, fill, stalk=5.0, ang=-84):
    """A first true leaf with a rounded blade on a stalk (sorrel)."""
    def fn(a, top, i):
        e = T(*top, ang)(stalk); a.line(f"M{P(top)} L{P(e)}", 0.8, 0.85)
        c = T(*e, ang)(r * 0.95)
        a.polar(c[0], c[1], lambda h: 1 - 0.12 * math.exp(-((abs(h) - math.pi) / 0.5) ** 2), r, r * 0.85, ang, fill, 0.8)
        a.line(f"M{P(e)} L{P(T(*e, ang)(r * 1.7))}", 0.5, 0.45)
    return fn


def multi(*fns):
    def fn(a, top, i):
        for g in fns:
            g(a, top, i)
    return fn


def mealy(a, top, i):
    """Good King Henry's seed leaves: frosted with white meal."""
    for sd in (-1, 1):
        for k in range(4):
            p = T(*top, -90 + sd * 66)(3 + 3.2 * k); a.dot(p[0] + 0.3, p[1], 0.35, "white")


def chard_seedlings(cols, cotc="pale"):
    """Chard or spinach beet: a small clump of seedlings from one seed
    ball, long strap seed leaves on stems coloured red, yellow or white."""
    def draw():
        a = Art(); soil(a, G)
        a.polar(50, G + 5, lambda th: 1 + 0.12 * math.cos(5 * th), 3.2, 2.8, 0, "bark", lw=0.7)   # the old seed ball
        for (dx, h, lean, L), c in zip(((-8, 13, -5, 9), (7, 16, 5, 10), (0, 10, 0, 8)), cols):
            a.roots(50 + dx * 0.3, G, 2, 8, 30)
            top = stem_up(a, 50 + dx * 0.3, G, h, c, w=1.5, lean=dx * 0.7 + lean * 0.3)
            cot_pair(a, top, "strap", cotc, L, 60)
        return a
    return draw


# ---------------------------------------------- small flowers on whole plants
def mini_lig(a, x, y, r, fc, cup="leaf", n=12):
    """A small head of the lettuce kind as it looks on the whole plant: a
    ring of strap florets (deep notches between them, a line down each) on
    a slim cup."""
    a.shape(f"M{f(x - r * 0.32)},{f(y)} L{f(x - r * 0.22)},{f(y + r * 1.0)} L{f(x + r * 0.22)},{f(y + r * 1.0)} L{f(x + r * 0.32)},{f(y)} Z", cup, 0.5)
    a.polar(x, y, lambda h: 1 - 0.3 * abs(math.sin(n * h / 2)) ** 0.4, r, r * 0.75, 0, fc, 0.45, shade=False)
    for k in range(0, n, 2):
        e0 = (x + r * 0.25 * math.cos(2 * math.pi * k / n), y + r * 0.19 * math.sin(2 * math.pi * k / n))
        e1 = (x + r * 0.75 * math.cos(2 * math.pi * k / n), y + r * 0.56 * math.sin(2 * math.pi * k / n))
        a.line(f"M{P(e0)} L{P(e1)}", 0.3, 0.35)


def mini_cup(a, x, y, r, col="straw", ang=-90):
    """A closed head: the slim cup of bracts pinched shut round the seeds."""
    t = T(x, y, ang)
    a.shape(f"M{P(t(0, -r * 0.3))} L{P(t(r * 1.1, -r * 0.28))} L{P(t(r * 1.45, 0))} L{P(t(r * 1.1, r * 0.28))} L{P(t(0, r * 0.3))} Z", col, 0.5)


def mini_clock(a, x, y, r):
    """A small white fluffy clock of seeds on plumes (lettuce, celtuce)."""
    a.oval(x, y - r * 0.15, r, r * 0.9, 0, "white", 0.5, la=0.6)
    for k in range(9):
        g = -180 + k * 22.5; e = T(x, y + r * 0.35, g)(r * 0.9)
        a.line(f"M{f(x)},{f(y + r * 0.35)} L{P(e)}", 0.35, 0.4)
    mini_cup(a, x, y + r * 1.25, r * 0.55, "straw", -90)


def mini_cross(a, x, y, r, fc, veins=None):
    """A small four-petalled cross as it looks on the whole plant."""
    st = -45 + x * 5
    a.flower(x, y, r, 4, fc, None, 0.78, start=st, lw=0.5)
    if veins:   # rocket: a dark vein down each petal
        for k in range(4):
            t = T(x, y, st + 90 * k); a.line(f"M{P(t(r * 0.3))} L{P(t(r * 0.85))}", 0.45, 0.9, veins)
    a.dot(x, y, max(0.35, r * 0.18), "unripe")


def clasp_leaf(a, x, y, ang, L, fill, ears=True, b=0.3, lw=0.7):
    """A stem leaf with no stalk, broad where it joins the stem and
    tapering to a point, its base clasping the stem with two small pointed
    ears that reach down either side of it (lettuce, the cabbage family)."""
    if ears:
        for o in (-1, 1):
            a.shape(f"M{f(x + o * 0.4)},{f(y - 1.2)} L{f(x + o * (1.4 + L * b * 0.22))},{f(y + L * 0.17)} L{f(x + o * 0.6)},{f(y + 1.0)} Z", fill, lw * 0.85)
    hw = lambda u, s_: L * b * 0.5 * min(1.0, 0.55 + u / 0.25) * (1 - u) ** 0.85
    _rblade(a, x, y, ang, L, hw, fill, lw=lw, midw=0.35, shade=0.08, n=30)


def raceme(a, x, y, fc, mode="buds_up", seed=False, s=1.0, n=5, pod=None, podc="unripe", veins=None):
    """The top of one flowering branch of the cabbage family, as it looks
    on the whole plant. buds_up: the buds above the open flowers; flat: the
    open flowers above the buds. In seed: pods (pod = (length, beak share,
    width, lean, flat beak)) up the top of the stem."""
    if seed:
        L, beak, w, lean, flatb = (pod or (8, 0.12, 1.2, 28, False))[:5]
        hairy = len(pod or ()) > 5 and pod[5]
        a.line(f"M{f(x)},{f(y + n * 3.6 * s)} L{f(x)},{f(y - 2)}", 0.6, 0.9, "bark")
        for k in range(n):
            py = y + 1 + k * 3.6 * s; sd = 1 if k % 2 else -1
            b = (x + sd * 0.8, py)
            a.line(f"M{f(x)},{f(py + 0.6)} L{P(b)}", 0.5, 0.9, "bark")
            g = -90 + sd * lean
            xpod(a, b[0], b[1], g, L * s, podc, beak=beak, w=w * s, bumps=3, flatbeak=flatb)
            if hairy:   # white mustard's pods are bristly
                t = T(*b, g)
                for v, o in ((0.1, 1), (0.2, -1), (0.3, 1), (0.4, -1)):
                    p0 = t(L * s * v, o * w * s * 0.5); a.line(f"M{P(p0)} L{P(t(L * s * v - 0.5, o * (w * s * 0.5 + 1.3)))}", 0.4, 0.9, "bark")
        return
    r = 2.9 * s
    if mode == "flat":
        for bx, by in ((x - 1, y + 2.6), (x + 1, y + 2.8), (x, y + 3.6)):
            a.oval(bx, by, 0.8 * s, 1.2 * s, 0, "unripe", 0.45)
        for k, (dx, dy) in enumerate(((-3, -0.6), (3, -0.8), (0, -1.6))):
            a.line(f"M{f(x)},{f(y + 3)} L{f(x + dx)},{f(y + dy)}", 0.45, 0.8)
            mini_cross(a, x + dx, y + dy, r, fc, veins)
        return
    # a lengthening spike: young pods lowest, open flowers spaced up it, buds on top
    a.line(f"M{f(x)},{f(y + 14 * s)} L{f(x)},{f(y - 7 * s)}", 0.6, 0.85)
    for bx, by in ((x, y - 8.4 * s), (x - 1.1 * s, y - 7.2 * s), (x + 1.1 * s, y - 7.4 * s)):
        a.oval(bx, by, 0.8 * s, 1.2 * s, 0, "unripe", 0.45)
    for k, dy in enumerate((11.5, 13.5)):
        sd = -1 if k % 2 else 1
        a.line(f"M{f(x)},{f(y + dy * s)} L{f(x + sd * 1.2 * s)},{f(y + (dy - 1) * s)}", 0.45, 0.8)
        a.line(f"M{f(x + sd * 1.2 * s)},{f(y + (dy - 1) * s)} l{f(sd * 1.0 * s)},{f(-4.5 * s)}", 1.1 * s, 0.85, "unripe")
    for k, dy in enumerate((-3.6, 0.0, 3.8, 7.6)[: n - 1]):
        sd = -1 if k % 2 else 1
        a.line(f"M{f(x)},{f(y + dy * s + 1.2)} L{f(x + sd * 3.0 * s)},{f(y + dy * s)}", 0.45, 0.8)
        mini_cross(a, x + sd * 3.0 * s, y + dy * s, r, fc, veins)


def stalk_up(a, p0, p1, w0, w1, col, bend=1.2):
    """A stem: thick at the foot, thinner at the top."""
    c = ((p0[0] + p1[0]) / 2 + bend, (p0[1] + p1[1]) / 2)
    return a.ribbon(p0, c, p1, w0, w1, col, lw=0.9)


def leaf_scars(a, q, us, w=2.0):
    """The marks left on a stem where leaves have fallen: small crescents."""
    for i, u in enumerate(us):
        x, y = q.pt(u); sd = -1 if i % 2 else 1
        a.line(f"M{f(x + sd * w * 0.1)},{f(y)} Q{f(x + sd * w * 0.6)},{f(y + 1.4)} {f(x + sd * w)},{f(y - 0.2)}", 0.8, 0.75)


# ------------------------------------------------------- the lettuce family
def lettuce_young():
    a = Art(); soil(a, 84)
    for dx, g, L in ((-5, -170, 30), (5, -10, 30), (-3, -146, 31), (3, -34, 31), (-1, -116, 27), (1, -64, 27)):
        put(a, "lettuce", 50 + dx, 83, g, L)
    return a


def head_ball(a, cx, cy, R, outer, heart, crisp=False, veinc="line", wave=0.05):
    """A round head of leaves folded over each other round a paler heart:
    the heart showing at the top between two leaves wrapping the sides, and
    a third leaf across the front, each with its midrib. crisp: smooth,
    tight edges (a cabbage); otherwise soft and wavy (a lettuce)."""
    wv = 0.02 if crisp else wave; fr = 2 if crisp else 6; amp = 0.025 if crisp else 0.06
    a.polar(cx, cy, lambda h: 1 + wv * math.cos(9 * h), R, R * 0.96, 0, heart)
    for k in range(3):   # the heart's own folded leaves, faintly
        x0 = cx + (k - 1) * R * 0.3
        a.line(f"M{f(x0 - R * 0.18)},{f(cy - R * 0.55)} Q{f(x0)},{f(cy - R * 0.9)} {f(x0 + R * 0.18)},{f(cy - R * 0.55)}", 0.5, 0.4)
    def wrap(sd):
        pts = []
        for j in range(31):   # round the side of the ball, from the foot up to the shoulder
            th = math.radians(90 - sd * (25 + 112 * j / 30))
            r = R * (1 + wv * 0.6 * math.cos(9 * th))
            pts.append((cx + r * math.cos(th), cy + r * math.sin(th) * 0.96))
        end = pts[-1]; foot = (cx - sd * R * 0.2, cy + R * 0.9)
        for j in range(1, 17):   # its free edge, curving back down past the middle
            u = j / 16
            x = end[0] + (foot[0] - end[0]) * u - sd * R * 0.22 * math.sin(math.pi * u)
            y = end[1] + (foot[1] - end[1]) * u + R * amp * math.sin(u * math.pi * fr)
            pts.append((x, y))
        a.shape(path(pts), outer, 0.95)
        a.shape(path(pts[:16] + [(cx + sd * R * 0.45, cy + R * 0.2)]), "shade", 0, fa=0.08)
        m0 = (cx + sd * R * 0.2, cy + R * 0.88); m1 = (cx + sd * R * 0.66, cy - R * 0.45)
        a.line(f"M{P(m0)} Q{f(cx + sd * R * 0.66)},{f(cy + R * 0.35)} {P(m1)}", 0.8 if crisp else 0.7, 0.45, veinc)
        for u in (0.35, 0.62):
            b = (m0[0] + (m1[0] - m0[0]) * u + sd * R * 0.1, m0[1] + (m1[1] - m0[1]) * u)
            a.line(f"M{P(b)} l{f(-sd * R * 0.22)},{f(-R * 0.14)}", 0.5, 0.35, veinc)
    wrap(-1)
    wrap(1)
    pts = []   # the front leaf across the foot of the ball, its free edge dipping in the middle
    for j in range(25):
        u = j / 24; x = cx - R * 0.97 + 1.94 * R * u
        y = cy + R * 0.12 + R * 0.3 * math.sin(math.pi * u) + R * amp * math.sin(u * math.pi * (fr + 3))
        pts.append((x, y))
    for j in range(20):
        th = math.radians(8 + 164 * j / 19); pts.append((cx + R * math.cos(th), cy + R * 0.96 * math.sin(th)))
    a.shape(path(pts), outer, 0.95)
    a.shape(path(pts[25:] + [(cx, cy + R * 0.5)]), "shade", 0, fa=0.1)
    a.line(f"M{f(cx)},{f(cy + R * 0.95)} Q{f(cx + R * 0.04)},{f(cy + R * 0.72)} {f(cx + R * 0.05)},{f(cy + R * 0.46)}", 0.8 if crisp else 0.7, 0.45, veinc)


def lettuce_crop():
    a = Art(); soil(a, 86)
    tuft(a, "lettuce", 50, 84, [(-168, 36), (-12, 36), (-152, 38), (-28, 38), (-136, 34), (-44, 34)])
    head_ball(a, 50, 64, 20, "leaf", "pale")
    return a


def lig_tall(slug, stage, H=66, fc="primrose", base="lettuce", lc="leaf"):
    """A bolted plant of the lettuce kind: a tall stem from the middle of
    the old rosette, small arrow-based leaves clasping it, branching at the
    top into a wide spray of small heads; in seed, small white clocks and
    dried closed cups."""
    def draw():
        seed = stage == "seedhead"; sc = "straw" if seed else lc
        a = Art(); soil(a, 88)
        if base == "lettuce":
            tuft(a, slug, 50, 87, [(-172, 22), (-8, 22), (-150, 20), (-30, 20)], dry=seed)
            q = stalk_up(a, (50, 88), (50, 88 - H), 3.4, 1.4, sc)
        else:   # celtuce: the thick stem, grown on
            q = stalk_up(a, (50, 88), (50, 88 - H), 5.4, 2.0, sc, bend=0.6)
            leaf_scars(a, q, (0.08, 0.15, 0.22), 2.2)
        for i in range(6):
            u = 0.2 + 0.085 * i; x, y = q.pt(u); sd = -1 if i % 2 else 1
            clasp_leaf(a, x, y, -90 + sd * 50, 14 - i * 1.3, "straw" if seed else lc)
        top = q.pt(1)
        arms = [(0.74, -1, (18, 26)), (0.78, 1, (82, 22)), (0.86, -1, (30, 14)), (0.9, 1, (70, 12)), (1.0, 0, (52, 8))]
        for u, sd, e in arms:
            x, y = q.pt(u)
            a.line(f"M{f(x)},{f(y)} Q{f(x + (e[0] - x) * 0.5)},{f(y - 2)} {P(e)}", 0.8, 0.85 if not seed else 0.95, "bark" if seed else "line")
            for k, (dx, dy) in enumerate(((0, 0), (-4.2, 3.2), (4.2, 3.4))):
                px, py = e[0] + dx * (1 if sd >= 0 else -1), e[1] + dy
                if k:
                    a.line(f"M{f(e[0] + dx * 0.3 * (1 if sd >= 0 else -1))},{f(e[1] + 3)} L{f(px)},{f(py + 1)}", 0.5, 0.8 if not seed else 0.95, "bark" if seed else "line")
                if seed:
                    if k == 2:
                        mini_cup(a, px, py + 1.5, 2.2)
                    else:
                        mini_clock(a, px, py - 1, 2.6)
                else:
                    if k == 2:
                        mini_cup(a, px, py + 1.5, 2.0, "leaf")
                    else:
                        mini_lig(a, px, py, 3.3, fc)
        return a
    return draw


def salad_tuft(a, x, y, s=1.0, red=(1, 3), cut=False, dry=False):
    """One loose-leaf lettuce plant: an open, upright tuft of separate
    oblong frilly leaves, some edged red, no heart. cut: the leaves have
    been picked, leaving pale stubs with flat cut ends, and new small
    leaves rising from the middle."""
    if cut:
        for g, L in ((-106, 11), (-78, 12), (-92, 9)):   # the new leaves coming from the middle
            put(a, "leaf-salad", x, y - 1, g, L * s, fills={"beet": "leaf"}, detail=False)
        for dx, g, L in ((-3.0, -132, 6), (3.0, -50, 6), (-5.4, -154, 5), (5.4, -26, 5), (-1.4, -114, 4.4), (1.4, -68, 4.4)):
            b = (x + dx * s * 0.5, y); e = T(*b, g)(L * s)   # the stubs of the picked leaves, cut square
            a.ribbon(b, T(*b, g)(L * s * 0.5), e, 2.4 * s, 2.2 * s, "pale", lw=0.8)
            a.line(f"M{P(T(*e, g + 90)(1.2 * s))} L{P(T(*e, g - 90)(1.2 * s))}", 0.9, 0.9)
        return
    leaves = [(-7, -142, 34), (7, -38, 34), (-3, -112, 40), (3, -70, 40)]
    for i, (dx, g, L) in enumerate(leaves):
        put(a, "leaf-salad", x + dx * s, y, g, L * s, fills=None if i in red else {"beet": "leaf"}, dry=dry)


def leafsalad_young():
    a = Art(); soil(a, 86)
    salad_tuft(a, 50, 85, 0.9, red=(1, 4))
    return a


def leafsalad_crop():
    a = Art(); soil(a, 86)
    salad_tuft(a, 21, 86, 0.56, red=(0, 3))
    salad_tuft(a, 79, 86, 0.56, red=(1, 2))
    salad_tuft(a, 50, 86, 2.1, cut=True)
    return a


def celtuce_young():
    a = Art(); soil(a, 86)
    q = stalk_up(a, (50, 86), (50, 78), 4.4, 4.0, "pale", bend=0)
    tuft(a, "celtuce", 50, 80, [(-165, 30), (-15, 30), (-140, 34), (-40, 34), (-115, 36), (-65, 36), (-92, 34)])
    return a


def celtuce_crop():
    a = Art(); soil(a, 88)
    q = stalk_up(a, (50, 88), (50, 34), 7.2, 5.6, "pale", bend=0.4)
    leaf_scars(a, q, (0.08, 0.16, 0.24, 0.32, 0.4), 3.0)
    for u, sd in ((0.5, 1), (0.58, -1), (0.66, 1), (0.74, -1)):
        x, y = q.pt(u); put(a, "celtuce", x + sd * 2.5, y, -90 + sd * 62, 22)
    tuft(a, "celtuce", 50, 36, [(-160, 26), (-20, 26), (-135, 30), (-45, 30), (-110, 30), (-70, 30), (-90, 26)])
    return a


STAGE = {
    "lettuce": {"seed": seed_art(achenes(["straw", "dark", "seed"])),
                "seedling": seedling("lettuce", "spoon", true=first_leaf("lettuce", 19, -84, 12, -106), L=13, h=14),
                "young": lettuce_young, "crop": lettuce_crop,
                "flower": lig_tall("lettuce", "flower"), "seedhead": lig_tall("lettuce", "seedhead")},
    "leaf-salad": {"seed": seed_art(achenes(["straw", "dark", "seed"])),
                   "seedling": seedling("leaf-salad", "spoon", n=7, L=10, h=11, spread=60,
                                        true=lambda a, top, i: put(a, "leaf-salad", top[0], top[1], -90 + (i - 3) * 5, 10, lw=0.55, detail=False) if i in (1, 4) else None),
                   "young": leafsalad_young, "crop": leafsalad_crop,
                   "flower": lig_tall("leaf-salad", "flower", H=62), "seedhead": lig_tall("leaf-salad", "seedhead", H=62)},
    "celtuce": {"seed": seed_art(achenes(["straw", "dark", "seed"])),
                "seedling": seedling("celtuce", "spoon", true=first_leaf("celtuce", 17, -86), L=10),
                "young": celtuce_young, "crop": celtuce_crop,
                "flower": lig_tall("celtuce", "flower", H=76, base="celtuce"), "seedhead": lig_tall("celtuce", "seedhead", H=76, base="celtuce")},
}


# ------------------------------------------ the goosefoot family and the docks
def leafy_stem(a, slug, x, y, H, n, L0, stemc, lean=0.0, w0=2.6, w1=1.2, dry=False, u0=0.12, u1=0.8, shrink=0.5, spread=56, fills=None, start=1):
    """One upright stem with the kind's own leaves alternately up it,
    smaller towards the top. Returns the stem curve."""
    q = stalk_up(a, (x, y), (x + lean, y - H), w0, w1, "straw" if dry else stemc, bend=lean * 0.2 + 0.6)
    for i in range(n):
        u = u0 + (u1 - u0) * i / max(1, n - 1); px, py = q.pt(u); sd = start if i % 2 == 0 else -start
        put(a, slug, px, py, -90 + sd * spread + lean * 0.4, L0 * (1 - shrink * u), dry=dry, fills=fills)
    return q


def spinach_young():
    a = Art(); soil(a, 84)
    tuft(a, "spinach", 50, 82, [(-166, 28), (-14, 28), (-146, 31), (-34, 31), (-118, 31), (-62, 31), (-90, 27)])
    return a


def spinach_crop():
    a = Art(); soil(a, 86)
    tuft(a, "spinach", 50, 84, [(-168, 34), (-12, 34), (-156, 37), (-24, 37), (-134, 39), (-46, 39), (-112, 38), (-68, 38), (-90, 34)])
    return a


def spinach_tall(stage):
    """Spinach bolted: one upright stem, its leaves smaller and pointed,
    arrow-shaped; tiny green flower clusters in the leaf joints and in a
    spike at the top (no petals). In seed: hard round seeds clustered up
    the yellowing stem, the leaves dying."""
    def draw():
        seed = stage == "seedhead"
        a = Art(); soil(a, 88)
        for g, L in ((-166, 20), (-14, 20)):
            put(a, "spinach", 50, 87, g, L, dry=seed)
        q = stalk_up(a, (50, 88), (50, 14), 3.4, 1.4, "straw" if seed else "leaf")
        for i in range(7):
            u = 0.14 + 0.1 * i; x, y = q.pt(u); sd = -1 if i % 2 else 1
            put_shape(a, "spinach_stem", x, y, -90 + sd * 52, 20 - i * 1.6, fill="straw" if seed else None)
            if seed:
                for k in range(3):
                    a.oval(x - sd * (2 + k * 1.6), y - 1 - (k % 2) * 1.6, 1.5, 1.4, 0, "seed", 0.5)
            else:
                glom(a, x - sd * 2.4, y - 1.2, 1.9, "unripe", n=3)
        for i in range(5):
            u = 0.84 + 0.04 * i; x, y = q.pt(u)
            if seed:
                a.oval(x - 1.4, y, 1.4, 1.3, 0, "seed", 0.5); a.oval(x + 1.4, y - 0.6, 1.4, 1.3, 0, "seed", 0.5)
            else:
                glom(a, x, y, 2.2 - 0.2 * i, "unripe", anth="pear", n=3)
        return a
    return draw


def chard_rosette(a, slug, x, y, leaves, cols, dry=False):
    for (g, L), c in zip(leaves, cols):
        put(a, slug, x, y, g, L, fills={"berry": c} if c else None, dry=dry)


CHARD_COLS = ["berry", "sun", "white", "pink", "carrot", "berry", "sun", "white", "carrot"]


def chard_young():
    a = Art(); soil(a, 86)
    chard_rosette(a, "swiss-chard", 50, 85, [(-150, 30), (-30, 30), (-122, 34), (-58, 34), (-92, 36)], ["sun", "white", "berry", "pink", "berry"])
    return a


def chard_crop():
    a = Art(); soil(a, 88)
    a.oval(50, 87, 5, 2.4, 0, "bark", 0.8)
    chard_rosette(a, "swiss-chard", 50, 86, [(-156, 40), (-24, 40), (-134, 48), (-46, 48), (-114, 54), (-66, 54), (-90, 54)],
                  ["white", "carrot", "sun", "pink", "berry", "sun", "berry"])
    return a


def beet_young(slug):
    def draw():
        a = Art(); soil(a, 86)
        tuft(a, slug, 50, 85, [(-152, 28), (-28, 28), (-124, 32), (-56, 32), (-90, 34)])
        return a
    return draw


def beet_crop(slug):
    def draw():
        a = Art(); soil(a, 88)
        tuft(a, slug, 50, 87, [(-164, 32), (-16, 32), (-142, 38), (-38, 38), (-120, 41), (-60, 41), (-100, 42), (-80, 42)])
        return a
    return draw


def spike(a, p0, c, p1, col, seed=False, n=9, s=1.0, bractc="leaf"):
    """A long slender spike of small stalkless clusters, a narrow bract
    under each (beet). In seed, crowded knobbly seed balls."""
    q = a.stem(p0, c, p1, 0.8 if not seed else 0.9, col="line" if not seed else "bark", la=0.85 if not seed else 1.0)
    for i in range(n):
        u = 0.12 + 0.86 * i / (n - 1); x, y = q.pt(u); g = q.ang(u); sd = 1 if i % 2 else -1
        if not seed and u < 0.8:
            a.leaf(x, y, g + sd * 55, 3.4 * s, 0.4, bractc, lw=0.5, detail=False)
        if seed:
            a.polar(x - sd * 0.6, y, lambda h: 1 + 0.15 * math.cos(5 * h), 1.4 * s, 1.3 * s, i * 20, "bark", 0.5, shade=False)
            a.polar(x + sd * 0.9, y - 1.2, lambda h: 1 + 0.15 * math.cos(5 * h + 1), 1.2 * s, 1.1 * s, i * 20, "bark", 0.5, shade=False)
        else:
            for dx, dy in ((0, 0), (0.9, -0.6), (-0.8, -0.7)):
                a.oval(x + dx * s - sd * 0.8, y + dy * s, 0.95 * s, 0.85 * s, 0, col, 0.45)
    return q


def beet_tall(slug, stage, cols=None):
    """Chard or spinach beet in its second year: a tall leafy stem
    branching into long slender arching spikes of tiny green flowers; in
    seed, the spikes crowded with brown knobbly seed balls, the plant
    drying brown."""
    def draw():
        seed = stage == "seedhead"; sc = "straw" if seed else "leaf"
        a = Art(); soil(a, 88)
        base = [(-166, 24), (-14, 24), (-140, 22), (-40, 22)]
        if cols:
            chard_rosette(a, slug, 50, 87, base, cols[:4], dry=seed)
        else:
            tuft(a, slug, 50, 87, base, dry=seed)
        q = stalk_up(a, (50, 88), (50, 22), 3.4, 1.6, sc)
        for u, sd in ((0.18, 1), (0.28, -1), (0.38, 1)):
            x, y = q.pt(u); put(a, slug, x, y, -90 + sd * 56, 19 * (1.1 - u), dry=seed, fills={"berry": "leaf"} if cols else None)
        for u, sd, c, e in ((0.45, -1, (30, 22), (12, 36)), (0.52, 1, (72, 18), (89, 32)), (0.62, -1, (34, 8), (20, 18)), (0.7, 1, (66, 6), (80, 14))):
            x, y = q.pt(u); spike(a, (x, y), c, e, "bark" if seed else "unripe", seed, n=8)
        spike(a, q.pt(0.8), (52, 8), (58, 4), "bark" if seed else "unripe", seed, n=7)
        return a
    return draw


def gkh_young():
    a = Art(); soil(a, 86)
    for g, L in ((-158, 30), (-22, 30), (-128, 34), (-52, 34), (-92, 34)):
        put(a, "good-king-henry", 50, 85, g, L, detail=True)
    return a


def gkh_clump(stage):
    """Good King Henry: a leafy clump of upright, little-branched stems
    with arrow-shaped leaves. crop: young shoots at the tips to pick;
    flower: narrow leafless spikes of green flowers at the tips; seedhead:
    the spikes dull red-brown and the leaves yellowing."""
    def draw():
        seed = stage == "seedhead"
        a = Art(); soil(a, 88)
        fills = {"deep": "pear"} if seed else None
        tuft(a, "good-king-henry", 50, 87, [(-166, 24), (-14, 24)], fills=fills)
        tips = []
        for dx, H, lean in ((-9, 50, -12), (9, 54, 12), (0, 62, 1)):
            q = leafy_stem(a, "good-king-henry", 50 + dx * 0.3, 88, H, 5, 27, "leaf", lean=lean, w0=2.4, w1=1.2, u0=0.16, u1=0.78,
                           shrink=0.55, fills=fills, start=1 if dx <= 0 else -1)
            tips.append((q, lean))
        for q, lean in tips:
            if stage == "crop":   # the young shoot tip, a tight bunch of small leaves
                x, y = q.pt(1)
                for g, L in ((-120, 9), (-60, 9), (-90, 10)):
                    put(a, "good-king-henry", x, y + 1, g + lean * 0.5, L, detail=False)
            else:
                spike_dense(a, q.pt(0.82), (q.pt(1)[0] + lean * 0.15, q.pt(1)[1] - 8), 4.2, "rust" if seed else "unripe",
                            None if seed else "pear")
        return a
    return draw


def gkh_dormant():
    """Good King Henry in late winter: nothing above the soil but fat
    pinkish-green shoots pushing up from the crown."""
    a = Art(); soil(a, 62)
    below(a, 62)
    a.polar(50, 72, lambda h: 1 + 0.12 * math.cos(4 * h) + 0.05 * math.sin(7 * h), 13, 7, 0, "bark")
    a.roots(50, 76, 7, 16, 140, lw=1.0)
    for dx, h, lean in ((-7, 10, -3), (0, 15, 0), (7, 8, 3)):
        e = (50 + dx + lean, 62 - h)
        a.ribbon((50 + dx * 0.7, 68), (50 + dx, 62), e, 4.2, 2.6, "pink", lw=0.9, round_tip=True)
        for sd in (-1, 1):   # the folded first leaves at the tip
            a.leaf(e[0], e[1] + 2.4, -90 + sd * 24 + lean * 4, 5.4, 0.42, "unripe", lw=0.6, detail=False)
    return a


def orache_plant(stage):
    """Purple orache: young, a small upright purple plant; crop, a leafy
    plant 20 to 40 cm; flower, a tall narrow spire with long branched
    spikes at the top; seedhead, the spikes drooping, crowded with flat
    round papery discs, purple fading to buff."""
    def draw():
        a = Art(); soil(a, 88)
        if stage == "young":
            leafy_stem(a, "purple-orach", 50, 88, 30, 5, 20, "leaves_orache", w0=2.2, w1=1.2, u0=0.15, u1=0.85, shrink=0.45, spread=58)
            put(a, "purple-orach", 50, 58, -90, 10, detail=False)
            return a
        if stage == "crop":
            q = leafy_stem(a, "purple-orach", 50, 88, 56, 8, 30, "leaves_orache", w0=3.0, w1=1.4, u0=0.1, u1=0.86, shrink=0.55, spread=60)
            x, y = q.pt(1); put(a, "purple-orach", x, y, -92, 12, detail=False)
            return a
        seed = stage == "seedhead"
        fills = {"leaves_orache": "seed"} if seed else None
        q = leafy_stem(a, "purple-orach", 50, 88, 82, 6, 19, "seed" if seed else "leaves_orache", w0=3.6, w1=1.2, u0=0.06, u1=0.5,
                       shrink=0.5, spread=62, fills=fills)
        dc = "seed" if seed else "leaves_orache"; r0 = 2.3 if seed else 1.5
        for u, sd, L in ((0.52, -1, 16), (0.58, 1, 18), (0.65, -1, 17), (0.72, 1, 15), (0.79, -1, 12), (0.85, 1, 9)):
            x, y = q.pt(u)
            e = (x + sd * L * 0.62, y + (L * 0.7 if seed else -L * 0.62))
            qq = Quad((x, y), (x + sd * L * 0.62, y - (3 if seed else 5)), e)
            a.line(qq.d(), 0.7, 0.9 if seed else 0.85, "bark" if seed else "line")
            n = 6 if seed else 7
            for k in range(n):
                v = 0.25 + 0.75 * k / (n - 1); px, py = qq.pt(v)
                c = "plum" if (seed and k % 3 == 0) else dc
                rr = r0 * (1 - 0.25 * v)
                if seed:
                    a.oval(px + (1.2 if k % 2 else -1.2), py + 1.0, rr, rr * 0.95, 0, c, 0.5)
                    a.dot(px + (1.2 if k % 2 else -1.2), py + 1.0, 0.4, "bark")
                else:
                    a.oval(px + (0.8 if k % 2 else -0.8), py, rr, rr * 0.9, 0, c, 0.5)
        if seed:   # the top of the spire bends over and hangs, heavy with discs
            x, y = q.pt(0.86); qq = Quad((x, y), (x + 4, y - 12), (x + 15, y + 2))
            a.line(qq.d(), 0.9, 0.9, "bark")
            for k in range(8):
                px, py = qq.pt(0.15 + 0.85 * k / 7)
                a.oval(px + (1.1 if k % 2 else -1.1), py + 1.2, r0 * 0.9, r0 * 0.85, 0, "plum" if k % 3 == 1 else dc, 0.5)
        else:
            for k in range(7):
                px, py = q.pt(0.86 + 0.02 * k)
                a.oval(px + (1.0 if k % 2 else -1.0), py, r0 * 0.85, r0 * 0.8, 0, dc, 0.5)
        return a
    return draw


def sorrel_clump(stage):
    """Sorrel: a leafy clump of long-stalked, arrow-based leaves; in flower
    and seed, slender upright branched spikes rising well above it."""
    def draw():
        a = Art(); soil(a, 88)
        if stage in ("young", "crop"):
            s = 0.82 if stage == "young" else 1.0
            tuft(a, "sorrel", 50, 87, [(g, L * s) for g, L in ((-158, 32), (-22, 32), (-132, 38), (-48, 38), (-108, 42), (-72, 42), (-90, 40))])
            return a
        if stage == "dormant":
            tuft(a, "sorrel", 50, 87, [(-170, 20), (-10, 20), (-140, 19), (-40, 19)], fills=None)
            for g, L in ((-118, 18), (-62, 18)):
                put(a, "sorrel", 50, 87, g, L, fills={"leaf": "rust"})
            return a
        seed = stage == "seedhead"
        tuft(a, "sorrel", 50, 87, [(-166, 26), (-14, 26), (-140, 28), (-40, 28)], dry=False)
        col = "rust"
        for dx, H, lean in ((-4, 72, -6), (5, 64, 8)):
            q = stalk_up(a, (50 + dx * 0.3, 87), (50 + dx + lean, 87 - H), 2.0, 1.0, "bark" if seed else "rust")
            x, y = q.pt(0.22); clasp_leaf(a, x, y, -90 + (-1 if lean < 0 else 1) * 50, 10, "leaf", ears=False, b=0.25)
            for u, sd in ((0.5, -1), (0.62, 1), (0.74, -1)):
                x, y = q.pt(u); e = (x + sd * 9, y - 12)
                a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 5)},{f(y - 4)} {P(e)}", 0.6, 0.85)
                for k in range(4):
                    v = 0.35 + 0.65 * k / 3; px, py = x + (e[0] - x) * v, y + (e[1] - y) * v - 2 * v * (1 - v)
                    whorl_small(a, px, py, 1.3, col, seed)
            for k in range(8):
                px, py = q.pt(0.45 + 0.07 * k); whorl_small(a, px, py, 1.5, col, seed)
        return a
    return draw


def whorl_small(a, x, y, r, col, seed):
    for sd in (-1, 1):
        a.oval(x + sd * r * 0.8, y, r * 0.75, r * 0.6 if not seed else r * 0.75, 0, col, 0.45)


STAGE.update({
    "spinach": {"seed": seed_art(spinach_seed),
                "seedling": seedling("spinach", "strap", L=12, h=12, true=first_leaf("spinach", 15, -80, 11, -104)),
                "young": spinach_young, "crop": spinach_crop, "flower": spinach_tall("flower"), "seedhead": spinach_tall("seedhead")},
    "swiss-chard": {"seed": seed_art(seedball), "seedling": chard_seedlings(["berry", "sun", "white"]),
                    "young": chard_young, "crop": chard_crop,
                    "flower": beet_tall("swiss-chard", "flower", CHARD_COLS), "seedhead": beet_tall("swiss-chard", "seedhead", CHARD_COLS)},
    "spinach-beet": {"seed": seed_art(seedball), "seedling": chard_seedlings(["beet", "pale", "beet"]),
                     "young": beet_young("spinach-beet"), "crop": beet_crop("spinach-beet"),
                     "flower": beet_tall("spinach-beet", "flower"), "seedhead": beet_tall("spinach-beet", "seedhead")},
    "good-king-henry": {"seed": seed_art(round_seeds(["dark"], r=4.4)),
                        "seedling": seedling("good-king-henry", "strap", L=8, h=11, true=multi(mealy, first_leaf("good-king-henry", 14, -82, 11, -104))),
                        "young": gkh_young, "crop": gkh_clump("crop"), "flower": gkh_clump("flower"), "seedhead": gkh_clump("seedhead"),
                        "dormant": gkh_dormant},
    "purple-orach": {"seed": seed_art(orache_seed),
                     "seedling": seedling("purple-orach", "wstrap", cotc="leaves_orache", stemc="leaves_orache", L=9, h=12, true=first_leaf("purple-orach", 13, -82, 10, -104)),
                     "young": orache_plant("young"), "crop": orache_plant("crop"), "flower": orache_plant("flower"), "seedhead": orache_plant("seedhead")},
    "sorrel": {"seed": seed_art(sorrel_seed),
               "seedling": seedling("sorrel", "oval", L=10, h=11, true=round_first(6.5, "leaf", stalk=6, ang=-80)),
               "young": sorrel_clump("young"), "crop": sorrel_clump("crop"), "flower": sorrel_clump("flower"),
               "seedhead": sorrel_clump("seedhead"), "dormant": sorrel_clump("dormant")},
})


# ------------------------------------------------------ the cabbage family
def cross_tall(slug, stage, fc, base=None, H=70, stemc="leaf", clasp="sage", mode="buds_up", pod=None, arms=None, podc="unripe",
               stem_leaves=None, bristly=False, veins=None):
    """A bolted plant of the cabbage family: a branched stem, small leaves
    clasping it, racemes of crosses at the tips; in seed, pods up the tops
    of the stems, all drying straw-brown. base(a, seed) draws what the
    stem rises from and returns the point it starts at."""
    def draw():
        seed = stage == "seedhead"
        a = Art(); soil(a, 88)
        x0, y0 = base(a, seed) if base else (50, 88)
        if not base:
            tuft(a, slug, 50, 87, [(-166, 22), (-14, 22), (-142, 20), (-38, 20)], dry=seed)
        top = (50, 88 - H)
        q = stalk_up(a, (x0, y0), top, 3.2, 1.4, "straw" if seed else stemc, bend=0.8)
        if bristly:
            for u in (0.3, 0.45, 0.6, 0.75):
                x, y = q.pt(u)
                for sd in (-1, 1):
                    a.line(f"M{f(x + sd * 1.0)},{f(y)} l{f(sd * 1.1)},{f(1.0)}", 0.4, 0.7)
        tips = [q.pt(1)]
        for u, sd, e in (arms or ((0.42, -1, (22, 30)), (0.52, 1, (78, 28)), (0.68, -1, (32, 18)), (0.74, 1, (68, 16)))):
            x, y = q.pt(u); qq = a.stem((x, y), (x + (e[0] - x) * 0.55, y - 3), e, 0.9, col="bark" if seed else "line")
            tips.append(e)
            m = qq.pt(0.3)
            if stem_leaves:
                put(a, stem_leaves, m[0], m[1], -90 - sd * 40 + sd * 90, 14, dry=seed, detail=False)
            else:
                clasp_leaf(a, m[0], m[1], -90 + sd * 60, 8, "straw" if seed else clasp)
        for u, sd in ((0.22, 1), (0.32, -1)):
            x, y = q.pt(u)
            if stem_leaves:
                put(a, stem_leaves, x, y, -90 + sd * 55, 21, dry=seed, detail=False)
            else:
                clasp_leaf(a, x, y, -90 + sd * 55, 12, "straw" if seed else clasp)
        for x, y in tips:
            raceme(a, x, y, fc, mode, seed, s=1.15, pod=pod, podc="straw" if seed else podc, veins=veins)
        return a
    return draw


def brassica_young(slug, upright=False, stem=6, L=30):
    def draw():
        a = Art(); soil(a, 88)
        top = (50, 88 - stem)
        a.ribbon((50, 88), (50, 88 - stem * 0.5), top, 3.6, 3.0, "leaves_rib", lw=0.9)
        angs = [(-150, 1.0), (-30, 1.0), (-118, 1.1), (-62, 1.1), (-90, 1.05)] if upright else [(-170, 0.95), (-10, 0.95), (-140, 1.05), (-40, 1.05), (-100, 1.0), (-76, 1.0)]
        tuft(a, slug, top[0], top[1], [(g, L * k) for g, k in angs])
        return a
    return draw


def cabbage_crop():
    a = Art(); soil(a, 86)
    a.ribbon((50, 86), (50, 82), (50, 78), 5, 4.6, "leaves_rib", lw=0.9)
    tuft(a, "cabbage", 50, 80, [(-170, 34), (-10, 34), (-154, 36), (-26, 36), (-136, 32), (-44, 32)])
    head_ball(a, 50, 61, 18, "leaves_head", "leaves_head", crisp=True, veinc="line")
    return a


def split_head(a, seed=False):
    """What a cabbage's flowering stem rises from: the old head split open,
    its leaves folded back, on the short stem."""
    col = "straw" if seed else "leaves_head"
    a.ribbon((50, 88), (50, 84), (50, 80), 5, 4.6, "straw" if seed else "leaves_rib", lw=0.9)
    tuft(a, "cabbage", 50, 82, [(-176, 26), (-4, 26), (-156, 24), (-24, 24)], dry=seed)
    for sd in (-1, 1):   # the two halves of the old head, folded open
        a.oval(50 + sd * 7, 72, 6.5, 9.5, sd * 32, col, 0.9)
        a.line(f"M{f(50 + sd * 2)},{f(80)} Q{f(50 + sd * 6)},{f(74)} {f(50 + sd * 11)},{f(66)}", 0.6, 0.45)
    return (50, 74)


def cauli_crop():
    a = Art(); soil(a, 88)
    a.ribbon((50, 88), (50, 84), (50, 78), 5, 4.6, "leaves_rib", lw=0.9)
    tuft(a, "cauliflower", 50, 82, [(-146, 40), (-34, 40), (-120, 44), (-60, 44), (-170, 32), (-10, 32), (-96, 40)])
    curd(a, 50, 63, 21, 14)
    for sd in (-1, 1):   # inner leaves curving up and over the edge of the curd
        p0 = (50 + sd * 12, 82); c = (50 + sd * 31, 62); p1 = (50 + sd * 20, 53)
        q = a.ribbon(p0, c, p1, 6.0, 1.6, "sage", lw=0.9, round_tip=True)
        a.line(f"M{P(q.pt(0.05))} Q{P(q.pt(0.5))} {P(q.pt(0.92))}", 0.7, 0.6, "leaves_rib")
    return a


def floret_dome(a, cx, cy, rx, ry, col, grain=None, rows=4, k=0.34, line="line"):
    """A dome made of many tight rounded florets: rows of round lumps,
    the back (top) rows first, so each row overlaps the one behind it.
    grain: tiny buds dotted over each lump (broccoli)."""
    for j in range(rows):
        v = j / (rows - 1)                       # 0 at the top row, 1 at the front row
        y = cy - ry * 0.62 + ry * 0.86 * v
        w = rx * math.sqrt(max(0.05, 1 - ((y - cy - ry * 0.25) / (ry * 1.05)) ** 2))
        r = ry * k * (0.8 + 0.3 * v)
        n = max(2, int(round(2 * w / (r * 1.55))))
        for m in range(n):
            x = cx - w + r * 0.8 + (2 * w - r * 1.6) * (m + 0.5 * (j % 2) * (m < n - 1)) / max(1, n - 1)
            a.polar(x, y, lambda h, m=m: 1 + 0.05 * math.cos(5 * h + m), r, r * 0.86, 0, col, 0.7, shade=False)
            if grain:
                for g in range(5):
                    th = g * GOLD; rr = r * 0.6 * math.sqrt((g + 0.5) / 5)
                    a.dot(x + rr * math.cos(th), y + rr * math.sin(th) * 0.86, max(0.35, r * 0.1), grain)
            else:   # the smaller florets each lump is made of
                a.line(f"M{f(x - r * 0.5)},{f(y + r * 0.1)} Q{f(x - r * 0.25)},{f(y - r * 0.45)} {f(x)},{f(y + r * 0.05)} Q{f(x + r * 0.25)},{f(y - r * 0.45)} {f(x + r * 0.5)},{f(y + r * 0.1)}", 0.45, 0.45)


def curd(a, cx, cy, rx, ry, col="white"):
    """A cauliflower curd: a firm, creamy dome made of tight rounded florets."""
    floret_dome(a, cx, cy, rx, ry, col, rows=4, k=0.36)


def brocc_crop():
    a = Art(); soil(a, 88)
    q = stalk_up(a, (50, 88), (50, 54), 7.0, 6.0, "leaves_rib", bend=0.3)
    for u, sd, L, g in ((0.14, -1, 40, 62), (0.24, 1, 42, 60), (0.4, -1, 42, 46), (0.54, 1, 42, 44), (0.7, -1, 36, 30), (0.8, 1, 34, 28)):
        x, y = q.pt(u); put(a, "broccoli", x + sd * 2, y, -90 + sd * g, L)
    floret_dome(a, 50, 46, 21, 13, "marrow", grain="deep", rows=4, k=0.33)
    return a


def sprout_crop():
    a = Art(); soil(a, 88)
    q = stalk_up(a, (50, 88), (50, 22), 6.0, 3.2, "leaves_rib", bend=0.4)
    for u, sd, L in ((0.1, -1, 34), (0.2, 1, 36), (0.32, -1, 34), (0.44, 1, 32), (0.56, -1, 27), (0.68, 1, 22)):
        x, y = q.pt(u); put(a, "broccoli-sprouting", x + sd * 2, y, -90 + sd * 60, L)
    for u, sd in ((0.38, -1), (0.5, 1), (0.62, -1), (0.74, 1)):   # spears from the leaf joints
        x, y = q.pt(u); spear(a, x - sd * 1.5, y, -90 - sd * 26, 13)
    x, y = q.pt(1)
    for g in (-118, -62, -90):
        spear(a, x, y + 2, g, 15)
    return a


def spear(a, x, y, ang, L, col="plum"):
    """A sprouting broccoli spear: a green stalk, a small leaf, and a
    loose little head of purple buds."""
    t = T(x, y, ang); e = t(L * 0.62)
    a.ribbon((x, y), t(L * 0.3), e, 2.0, 1.6, "leaves_rib", lw=0.7)
    small_leaf(a, *t(L * 0.3), ang + 40, L * 0.42, 0.34, "sage", 0.6)
    c = t(L * 0.8)
    for j in range(9):
        th = j * GOLD; rr = 2.6 * math.sqrt((j + 0.5) / 9)
        a.oval(c[0] + rr * math.cos(th), c[1] + rr * math.sin(th) * 1.2, 1.3, 1.3, 0, col, 0.5)


def brussels_crop():
    a = Art(); soil(a, 88)
    q = stalk_up(a, (50, 88), (50, 26), 6.0, 4.4, "leaves_rib", bend=0.2)
    leaf_scars(a, q, (0.05, 0.1, 0.15, 0.2, 0.25), 3.2)   # the bare foot of the stem, leaves fallen
    for i in range(11):   # sprouts packed up the stem, one in each leaf joint
        u = 0.3 + 0.055 * i; x, y = q.pt(u); sd = -1 if i % 2 else 1
        r = 3.5 - 0.1 * i
        a.oval(x + sd * 3.6, y - 1, r, r * 0.92, 0, "unripe", 0.9)
        a.line(f"M{f(x + sd * 3.6 - r * 0.5)},{f(y - 1 + r * 0.4)} Q{f(x + sd * 3.6)},{f(y - 1 - r * 0.3)} {f(x + sd * 3.6 + r * 0.55)},{f(y - 1 - r * 0.3)}", 0.5, 0.5)
    for u, sd in ((0.62, -1), (0.7, 1)):
        x, y = q.pt(u); put(a, "brussels-sprouts", x, y, -90 + sd * 64, 26)
    tuft(a, "brussels-sprouts", 50, 28, [(-160, 28), (-20, 28), (-130, 30), (-50, 30), (-90, 26)])
    return a


def brassica_base(kind):
    """What a bolted cabbage-family crop flowers from: the old plant."""
    def base(a, seed):
        lc = "straw" if seed else "sage"; rib = "straw" if seed else "leaves_rib"
        if kind == "cabbage":
            return split_head(a, seed)
        if kind == "cauliflower":   # the curd loosened, its florets pulled apart on lengthening stalks
            a.ribbon((50, 88), (50, 84), (50, 80), 5, 4.6, rib, lw=0.9)
            tuft(a, "cauliflower", 50, 82, [(-160, 30), (-20, 30), (-136, 32), (-44, 32)], dry=seed)
            for dx, h in ((-11, 7), (-5, 11), (5, 10), (11, 6)):
                e = (50 + dx, 80 - h); a.line(f"M50,80 Q{f(50 + dx * 0.5)},{f(78)} {P(e)}", 1.0, 0.9, "bark" if seed else "line")
                a.polar(e[0], e[1] - 1.2, lambda h_: 1 + 0.08 * math.cos(5 * h_), 2.6, 2.2, 0, "straw" if seed else "white", 0.6, shade=False)
            return (50, 78)
        if kind in ("broccoli", "broccoli-sprouting", "brussels-sprouts"):
            q = stalk_up(a, (50, 88), (50, 62), 5.6, 4.6, rib, bend=0.2)
            if kind == "brussels-sprouts":
                for i in range(4):
                    x, y = q.pt(0.15 + 0.22 * i); sd = -1 if i % 2 else 1
                    a.oval(x + sd * 3.4, y, 2.8, 2.6, 0, "straw" if seed else "unripe", 0.7)
            for u, sd, L in ((0.3, -1, 24), (0.62, 1, 22)):
                x, y = q.pt(u); put(a, kind, x, y, -90 + sd * 58, L, dry=seed)
            if kind in ("broccoli-sprouting", "brussels-sprouts"):   # each spear or sprout has opened into a flowering shoot
                for u, sd in ((0.22, 1), (0.5, -1), (0.8, 1)):
                    x, y = q.pt(u); e = (x + sd * 16, y - 18)
                    a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 10)},{f(y - 4)} {P(e)}", 0.9, 0.9, "bark" if seed else "line")
                    raceme(a, e[0], e[1], "primrose", "buds_up", seed, s=0.8, n=4, pod=_BPOD, podc="straw" if seed else "unripe")
            return (50, 62)
        return (50, 88)
    return base


# leafy cabbage-family salads
def rocket_young():
    a = Art(); soil(a, 86)
    tuft(a, "rocket-salad", 50, 85, [(-164, 26), (-16, 26), (-136, 29), (-44, 29), (-108, 30), (-72, 30)])
    return a


def rocket_crop():
    a = Art(); soil(a, 86)
    tuft(a, "rocket-salad", 50, 85, [(-170, 34), (-10, 34), (-148, 38), (-32, 38), (-124, 41), (-56, 41), (-100, 42), (-80, 42)])
    return a


def mizuna_leaf(a, x, y, g, L):
    """A mizuna leaf on the whole plant: the feathery blade drawn light,
    and its long white stalk drawn over again wide enough to show white."""
    put(a, "mizuna", x, y, g, L, lw=0.45 if L < 40 else 0.55, detail=False)
    t = T(x, y, g)
    a.ribbon((x, y), t(L * 0.17), t(L * 0.33), 2.0, 1.4, "white", lw=0.45)


def mizuna_young():
    a = Art(); soil(a, 86)
    for g, L in ((-140, 30), (-40, 30), (-116, 33), (-64, 33), (-92, 33)):
        mizuna_leaf(a, 50, 85, g, L)
    return a


def mizuna_crop():
    a = Art(); soil(a, 88)
    lv = [(-172, 38), (-8, 38), (-156, 42), (-24, 42), (-140, 45), (-40, 45), (-124, 46), (-56, 46), (-108, 46), (-72, 46), (-96, 44), (-84, 44)]
    for g, L in lv:
        mizuna_leaf(a, 50, 87, g, L)
    a.ribbon((50, 88.5), (50, 86.5), (50, 84), 5.4, 4.2, "white", lw=0.6)   # the white stalks gathered at the foot
    return a


def mustard_plant(a, x, y, H, s=1.0, dry=False):
    q = stalk_up(a, (x, y), (x + 0.5, y - H), 2.4 * s, 1.2 * s, "straw" if dry else "leaf", bend=0.4)
    for i in range(5):
        u = 0.05 + 0.2 * i; px, py = q.pt(u); sd = -1 if i % 2 else 1
        put(a, "mustard", px, py, -90 + sd * 52, 22 * s * (1.05 - 0.45 * u), dry=dry)
    return q


def mustard_young():
    a = Art(); soil(a, 86)
    q = mustard_plant(a, 50, 86, 20, 1.15)
    x, y = q.pt(1); put(a, "mustard", x, y, -90, 11, detail=False)
    for u in (0.3, 0.6):   # the stiff bristles on the stem
        x, y = q.pt(u); a.line(f"M{f(x - 1.2)},{f(y)} l-1,1 M{f(x + 1.2)},{f(y)} l1,1", 0.4, 0.7)
    return a


def mustard_crop():
    a = Art(); soil(a, 88)
    for x, H, s in ((24, 28, 0.85), (76, 30, 0.85), (35, 34, 0.95), (65, 33, 0.95), (44, 38, 1.0), (56, 40, 1.0)):
        q = mustard_plant(a, x, 88, H, s)
        e = q.pt(1); put(a, "mustard", e[0], e[1], -90, 10, detail=False)
    return a


def pakchoi_young():
    a = Art(); soil(a, 86)
    tuft(a, "pak-choi", 50, 85, [(-128, 26), (-52, 26), (-108, 29), (-72, 29), (-90, 30)])
    return a


def pakchoi_crop():
    """Pak choi: an upright vase of broad dark glossy blades on thick white
    stalks, the stalks overlapping into a swollen base; no heart."""
    a = Art(); soil(a, 88)
    tuft(a, "pak-choi", 50, 86, [(-132, 50), (-48, 50), (-116, 54), (-64, 54), (-100, 56), (-80, 56), (-90, 52)])
    pts = []   # the swollen base, the stalks wrapped round each other
    for j in range(31):
        v = j / 30; y = 87 - 15 * v; w = 7.6 * math.sin(math.pi * (0.25 + 0.75 * (1 - v))) + 3.2 * v
        pts.append((50 - w, y))
    pts += [(100 - x, y) for x, y in pts[::-1]]
    a.shape(path(pts), "white", 0.95)
    for dx in (-4.4, -1.4, 1.6, 4.6):
        a.line(f"M{f(50 + dx * 0.9)},{f(86.5)} Q{f(50 + dx * 1.3)},{f(80)} {f(50 + dx * 0.75)},{f(72)}", 0.6, 0.5)
    a.shape(path([(x, y) for x, y in pts[31:]] + [(50, 72)]), "shade", 0, fa=0.08)
    return a


def cress_crop():
    """Cress as a crop: a dense mat of thin, pale stems about 5 cm tall,
    each topped by its pair of three-lobed seed leaves."""
    a = Art(); soil(a, 82)
    spots = [(16, 28, -3), (27, 33, 2), (38, 29, -1), (50, 34, 1), (62, 30, -2), (73, 33, 1), (84, 28, 2),
             (21, 22, 1), (33, 24, -1), (45, 23, 0), (56, 24, 1), (68, 22, -1), (79, 21, 1)]
    for x, h, lean in sorted(spots, key=lambda s: s[1]):
        top = stem_up(a, x, 82, h, "pale", w=1.2, lean=lean, lw=0.4)
        cot_pair(a, top, "trident", "leaf", 13, 70)
    return a


def cress_young():
    """A young cress plant: a low rosette of narrowly lobed leaves, the two
    three-lobed seed leaves still there at its foot."""
    a = Art(); soil(a, 84)
    tuft(a, "cress", 50, 83, [(-170, 26), (-10, 26), (-148, 28), (-32, 28)])
    top = stem_up(a, 50, 84, 7, "pale", w=1.4, lw=0.45)
    cot_pair(a, top, "trident", "leaf", 17, 62)
    return a


def cress_tall(stage):
    """Cress grown on: a slender upright branched plant, narrow stalkless
    leaves up the stems, tiny white flowers in spikes; in seed, small flat
    round notched pods pressed upright against the stem, crowded along
    long spikes."""
    def draw():
        seed = stage == "seedhead"; sc = "straw" if seed else "sage"
        a = Art(); soil(a, 88)
        tuft(a, "cress", 50, 87, [(-156, 20), (-24, 20)], dry=seed)
        q = stalk_up(a, (50, 88), (50, 12), 2.4, 1.0, sc, bend=0.4)
        for u, sd, e in ((0.36, -1, (26, 20)), (0.46, 1, (76, 18)), (0.58, -1, (36, 8))):
            x, y = q.pt(u); qq = a.stem((x, y), (x + (e[0] - x) * 0.4, y - 8), e, 0.8, col="bark" if seed else "line")
            cress_spike(a, qq, seed)
            m = qq.pt(0.2); a.leaf(m[0], m[1], -90 - sd * 30 + sd * 90 - sd * 40, 7, 0.16, sc, lw=0.5, detail=False)
        for i, u in enumerate((0.12, 0.2, 0.28)):
            x, y = q.pt(u); sd = -1 if i % 2 else 1
            a.leaf(x, y, -90 + sd * 40, 10, 0.14, sc, lw=0.6, detail=False)
        cress_spike(a, Quad(q.pt(0.62), q.pt(0.8), q.pt(1)), seed)
        return a
    return draw


def cress_spike(a, qq, seed):
    n = 10 if seed else 7
    for i in range(n):
        u = 0.4 + 0.6 * i / (n - 1); x, y = qq.pt(u); sd = -1 if i % 2 else 1
        if seed:
            notched_pod(a, x + sd * 1.3, y - 1.4, 2.2, "straw", -90 + sd * 6)
        elif u > 0.75:
            a.oval(x + sd * 0.8, y, 0.9, 1.2, 0, "sage", 0.4)
        else:
            mini_cross(a, x + sd * 2.4, y - 0.6, 2.4, "white")


_KID = dict(cot="kidney", cotc="sage", L=11, h=11)
_BPOD = (9, 0.1, 0.95, 22, False)   # cabbage-family pods: long, slender, short beak


def brassica_stages(slug, young, crop, kind):
    return {"seed": seed_art(round_seeds(["rust", "dark"], r=4.2)),
            "seedling": seedling(slug, "kidney", cotc="sage", L=12, h=11,
                                 true=simple_leaf(8.5, "sage", b=0.7, stalk=6, ang=-82, skew=0.5)),
            "young": young, "crop": crop,
            "flower": cross_tall(slug, "flower", "primrose", base=brassica_base(kind), H=72, stemc="sage", clasp="sage", pod=_BPOD),
            "seedhead": cross_tall(slug, "seedhead", "primrose", base=brassica_base(kind), H=72, stemc="sage", clasp="sage", pod=_BPOD)}


STAGE.update({
    "cabbage": brassica_stages("cabbage", brassica_young("cabbage", stem=6, L=30), cabbage_crop, "cabbage"),
    "cauliflower": brassica_stages("cauliflower", brassica_young("cauliflower", upright=True, stem=6, L=36), cauli_crop, "cauliflower"),
    "broccoli": brassica_stages("broccoli", brassica_young("broccoli", upright=True, stem=12, L=34), brocc_crop, "broccoli"),
    "broccoli-sprouting": brassica_stages("broccoli-sprouting", brassica_young("broccoli-sprouting", upright=True, stem=14, L=34), sprout_crop, "broccoli-sprouting"),
    "brussels-sprouts": brassica_stages("brussels-sprouts", brassica_young("brussels-sprouts", upright=True, stem=24, L=28), brussels_crop, "brussels-sprouts"),
    "rocket-salad": {"seed": seed_art(oval_seeds(["seed"], L=6.4, W=4.6)),
                     "seedling": seedling("rocket-salad", "kidney", cotc="pale", L=12, h=11,
                                          true=lambda a, top, i: (a.line(f"M{P(top)} L{f(top[0] + 0.5)},{f(top[1] - 5)}", 0.8, 0.85),
                                                                  a.toothleaf(top[0] + 0.5, top[1] - 5, -86, 13, 8.4, 7, "leaf", 0.06))),
                     "young": rocket_young, "crop": rocket_crop,
                     "flower": cross_tall("rocket-salad", "flower", "leaves_cream", H=66, stemc="leaf", clasp="leaf", stem_leaves="rocket-salad",
                                          pod=(6, 0.36, 1.9, 8, True), veins="plum"),
                     "seedhead": cross_tall("rocket-salad", "seedhead", "leaves_cream", H=66, stemc="leaf", stem_leaves="rocket-salad",
                                            pod=(6, 0.36, 1.9, 8, True))},
    "mizuna": {"seed": seed_art(round_seeds(["rust", "bark"], r=3.6)),
               "seedling": seedling("mizuna", "kidney", cotc="pale", L=12, h=11,
                                    true=simple_leaf(13, "leaf", b=0.34, stalk=6, ang=-84, edge="saw")),
               "young": mizuna_young, "crop": mizuna_crop,
               "flower": cross_tall("mizuna", "flower", "leaves_yellow", H=66, stemc="sage", clasp="sage", mode="flat", pod=(10, 0.24, 0.9, 26, False)),
               "seedhead": cross_tall("mizuna", "seedhead", "leaves_yellow", H=66, stemc="sage", clasp="sage", mode="flat", pod=(10, 0.24, 0.9, 26, False))},
    "mustard": {"seed": seed_art(round_seeds(["straw"], r=4.6)),
                "seedling": seedling("mustard", "kidney", cotc="pale", L=14, h=12, true=first_leaf("mustard", 16, -84, detail=True)),
                "young": mustard_young, "crop": mustard_crop,
                "flower": cross_tall("mustard", "flower", "leaves_yellow", H=70, stemc="leaf", stem_leaves="mustard", pod=(9, 0.5, 1.4, 46, True, True), bristly=True),
                "seedhead": cross_tall("mustard", "seedhead", "leaves_yellow", H=70, stemc="leaf", stem_leaves="mustard", pod=(9, 0.5, 1.4, 46, True, True), bristly=True)},
    "pak-choi": {"seed": seed_art(round_seeds(["rust", "bark"], r=3.6)),
                 "seedling": seedling("pak-choi", "kidney", cotc="pale", L=12, h=11, true=first_leaf("pak-choi", 17, -84)),
                 "young": pakchoi_young, "crop": pakchoi_crop,
                 "flower": cross_tall("pak-choi", "flower", "leaves_yellow", H=66, stemc="sage", clasp="marrow", mode="flat", pod=(10, 0.24, 0.9, 26, False)),
                 "seedhead": cross_tall("pak-choi", "seedhead", "leaves_yellow", H=66, stemc="sage", clasp="marrow", mode="flat", pod=(10, 0.24, 0.9, 26, False))},
    "cress": {"seed": seed_art(oval_seeds(["rust"], L=7, W=4.2)),
              "seedling": seedling("cress", "trident", cotc="leaf", L=17, h=22, stemc="pale"),
              "young": cress_young, "crop": cress_crop, "flower": cress_tall("flower"), "seedhead": cress_tall("seedhead")},
})


# ------------------------------------------------------ lamb's lettuce
CS_ROS = [(-178, 1.0), (-2, 1.0), (-164, 1.05), (-16, 1.05), (-148, 0.95), (-32, 0.95), (-130, 0.82), (-50, 0.82)]


def cornsalad_rosette(a, x, y, L, dry=False, n=8):
    """A flat rosette of spoon-shaped leaves in opposite pairs, spread low
    over the soil."""
    for g, k in CS_ROS[:n]:
        put(a, "lambs-lettuce", x, y, g, L * k, dry=dry, detail=L * k >= 22)


def cornsalad_young():
    a = Art(); soil(a, 82)
    cornsalad_rosette(a, 50, 81, 22, n=6)
    return a


def cornsalad_crop():
    a = Art(); soil(a, 84)
    cornsalad_rosette(a, 50, 83, 38)
    put(a, "lambs-lettuce", 50, 83, -108, 22); put(a, "lambs-lettuce", 50, 83, -72, 22)
    return a


def cornsalad_tall(stage):
    """Lamb's lettuce in flower: a slender stem forking again and again in
    twos, a pair of narrow leaves at each fork, tiny pale blue flowers in
    small flat clusters at the tips. In seed, the forks dried yellow-brown,
    tiny round seeds in small clusters at the tips."""
    def draw():
        seed = stage == "seedhead"; sc = "straw" if seed else "leaf"; lc = "straw" if seed else "deep"
        fc = pal("lambs-lettuce", "flower", "blue")
        a = Art(); soil(a, 88)
        cornsalad_rosette(a, 50, 87, 18, dry=seed, n=4)
        def fork(p, ang, L, depth):
            e = T(*p, ang)(L)
            a.line(f"M{P(p)} Q{P(T(*p, ang + 6)(L * 0.5))} {P(e)}", 1.1 if depth == 0 else 0.9, 0.95 if seed else 0.85, "bark" if seed else "line")
            if depth == 0:
                a.ribbon(p, T(*p, ang)(L * 0.5), e, 2.0, 1.4, sc, lw=0.8)
            for sd in (-1, 1):
                a.leaf(e[0], e[1], ang + sd * 58, 9 * (1 - 0.25 * depth), 0.2, lc, lw=0.6, detail=False)
            if depth < 2:
                for sd in (-1, 1):
                    fork(e, ang + sd * 30, L * 0.62, depth + 1)
            else:
                for sd in (-1, 1):
                    tip = T(*e, ang + sd * 22)(5)
                    a.line(f"M{P(e)} L{P(tip)}", 0.7, 0.95 if seed else 0.85, "bark" if seed else "line")
                    if seed:
                        for k in range(4):
                            a.oval(tip[0] + (k - 1.5) * 1.3, tip[1] - (k % 2) * 1.0, 0.9, 0.85, 0, "seed", 0.4)
                    else:
                        for k in range(5):
                            a.flower(tip[0] + (k - 2) * 1.7, tip[1] - 1.0 - (k % 2) * 1.2, 1.6, 5, fc, None, 0.95, lw=0.4)
        fork((50, 87), -90, 34, 0)
        return a
    return draw


# ------------------------------------------------------------------ chicory
def chicory_young():
    a = Art(); soil(a, 86)
    for dx, g, L in ((-6, -148, 36), (6, -32, 36), (-3, -122, 41), (3, -58, 41), (-1, -100, 44), (1, -80, 44)):
        put(a, "chicory", 50 + dx, 85, g, L)
    return a


def chicon(a, x, y, H, W):
    """A forced chicon: a tight, pointed, spindle-shaped head of creamy white
    leaves closely wrapped, their tips pale yellow."""
    def side(sd, k):
        return [(x + sd * W / 2 * k * math.sin(math.pi * min(1, v) ** 0.75) ** 0.8, y - H * v) for v in [j / 20 for j in range(21)]]
    pts = side(-1, 1) + side(1, 1)[::-1]
    a.shape(path(pts), "white")
    a.shape(path(side(1, 1) + [(x, y - H * v) for v in [j / 20 for j in range(20, -1, -1)]]), "shade", 0, fa=0.08)
    tip = [(x + (px - x), py) for px, py in pts if py < y - H * 0.72]
    a.shape(path(tip), "primrose", 0)
    a.shape(path(pts), None, 1.1)
    for sd, k0, k1 in ((-1, 0.0, 0.92), (1, 0.08, 0.84), (-1, 0.2, 0.7)):   # the edges of the wrapped leaves
        a.line(f"M{f(x + sd * W * 0.36)},{f(y - H * k0)} Q{f(x + sd * W * 0.22)},{f(y - H * (k0 + k1) / 2)} {f(x - sd * W * 0.05)},{f(y - H * k1)}", 0.6, 0.55)


def chicory_crop():
    """Witloof chicory: the forced chicon on its thick lifted root."""
    a = Art(); soil(a, 56)
    below(a, 56)
    a.ribbon((50, 56), (50.5, 74), (50, 93), 13, 3, "white", lw=1.0)   # the thick white root, cut back
    for y in (64, 72, 80):
        a.line(f"M{f(50 - (13 - (y - 56) * 0.26) * 0.42)},{f(y)} Q50,{f(y + 1.2)} {f(50 + (13 - (y - 56) * 0.26) * 0.42)},{f(y)}", 0.6, 0.5)
    for k, (dx, dy) in enumerate(((-5.2, 66), (5.6, 74), (-4.2, 82))):
        sd = -1 if dx < 0 else 1
        a.line(f"M{f(50 + dx)},{f(dy)} q{f(sd * 3)},1.2 {f(sd * 5.4)},3.6", 0.6, 0.75, "soil")
    a.ribbon((50, 57), (50, 55.5), (50, 54), 11, 10, "straw", lw=0.8)   # the crown, cut flat
    chicon(a, 50, 55, 42, 15)
    return a


def chicory_tall(stage):
    """Chicory in its second summer: stiff, branched, wiry stems with few
    small leaves, the sky-blue flowers stalkless along them in ones to
    threes. In seed: bare brown wiry stems with small closed brown bract
    cups along them, no clocks."""
    def draw():
        seed = stage == "seedhead"; sc = "bark" if seed else "leaf"
        fc = pal("chicory", "flower", "blue")
        a = Art(); soil(a, 88)
        if not seed:
            tuft(a, "chicory", 50, 87, [(-162, 24), (-18, 24), (-140, 22), (-40, 22)])
        q = stalk_up(a, (50, 88), (50, 10), 2.8, 1.2, sc, bend=0.4)
        branches = [(0.28, -1, (16, 30)), (0.36, 1, (84, 26)), (0.5, -1, (26, 14)), (0.58, 1, (76, 12))]
        stems = [q]
        for u, sd, e in branches:
            x, y = q.pt(u); stems.append(Quad((x, y), (x + (e[0] - x) * 0.3, y - 10), e))
            a.line(stems[-1].d(), 1.0, 0.95 if seed else 0.85, "bark" if seed else "line")
        for j, qq in enumerate(stems):
            us = (0.3, 0.5, 0.7, 0.88) if j else (0.66, 0.78, 0.9, 1.0)
            for k, u in enumerate(us):
                x, y = qq.pt(u); g = qq.ang(u)
                if not seed and k == 0 and j:
                    a.leaf(x, y, g - 40, 6, 0.24, "leaf", lw=0.55, detail=False)   # a small leaf at the joint
                n = 1 + (k + j) % 3 if not seed else 2
                for m in range(n):
                    off = (m - (n - 1) / 2) * 3.4
                    px, py = T(x, y, g + 90)(off)
                    if seed:
                        mini_cup(a, px, py, 2.2, "bark", g - 90 + off * 8)
                    elif (k + m) % 4 == 3:
                        mini_cup(a, px, py, 2.0, "leaf", g - 60)
                    else:
                        mini_lig(a, px, py - 0.5, 3.6 if j == 0 else 3.2, fc, n=14)
        return a
    return draw


def chicory_dormant():
    """Chicory in winter: the leaves died back, the crown at the soil on
    its thick white taproot, a few small leaves at most."""
    a = Art(); soil(a, 44); below(a, 44)
    a.ribbon((50, 44), (51, 66), (50, 92), 12, 2.4, "white", lw=1.0)
    for y in (52, 60, 68, 76):
        w = 12 * (1 - (y - 44) / 50) * 0.42
        a.line(f"M{f(50 - w)},{f(y)} Q50,{f(y + 1.2)} {f(50 + w)},{f(y)}", 0.6, 0.5)
    for dx, dy in ((-4.4, 58), (4.6, 66), (-3.6, 76)):
        sd = -1 if dx < 0 else 1
        a.line(f"M{f(50 + dx)},{f(dy)} q{f(sd * 3)},1.2 {f(sd * 5)},3.6", 0.6, 0.75, "soil")
    a.ribbon((50, 45.5), (50, 44), (50, 42.5), 10, 9, "bark", lw=0.8)   # the crown, with old leaf bases
    for g, L in ((-150, 12), (-30, 11), (-100, 10)):
        put(a, "chicory", 50, 42.5, g, L, detail=False)
    return a


STAGE.update({
    "lambs-lettuce": {"seed": seed_art(cornsalad_seed),
                      "seedling": seedling("lambs-lettuce", "oval", cotc="pale", L=9, h=9,
                                           true=lambda a, top, i: (put(a, "lambs-lettuce", top[0], top[1], -60, 12, lw=0.7, detail=False),
                                                                   put(a, "lambs-lettuce", top[0], top[1], -120, 12, lw=0.7, detail=False))),
                      "young": cornsalad_young, "crop": cornsalad_crop,
                      "flower": cornsalad_tall("flower"), "seedhead": cornsalad_tall("seedhead")},
    "chicory": {"seed": seed_art(chicory_seed),
                "seedling": seedling("chicory", "oval", cotc="pale", L=11, h=11,
                                     true=simple_leaf(13, "leaf", b=0.3, ang=-84, edge="saw")),
                "young": chicory_young, "crop": ("Forced chicon", chicory_crop),
                "flower": chicory_tall("flower"), "seedhead": chicory_tall("seedhead"), "dormant": chicory_dormant},
})


# The life-stage settings: every kind here is drawn by hand above (STAGE),
# but its line in plants_all.py is told to use its own close-up leaf too,
# so anything still drawn from the templates matches the close-up.
KIND = {slug: dict(leaf="own") for slug in (
    "leaf-salad", "spinach", "swiss-chard", "spinach-beet", "rocket-salad", "mizuna", "mustard", "pak-choi", "lambs-lettuce",
    "cress", "chicory", "celtuce", "sorrel", "good-king-henry", "purple-orach", "cabbage", "cauliflower", "broccoli",
    "broccoli-sprouting", "brussels-sprouts")}
