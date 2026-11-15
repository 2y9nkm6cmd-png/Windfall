"""Windfall plant drawings: every kind of plant in the library.

Run:  python3 plants_all.py OUT_FOLDER
Ten plants are drawn by hand in plants.py. Every other kind is built here
from a TEMPLATE (its habit: upright, rosette, clump, climber, trailer, mat,
bush, cane, vine, tree or bulb) and a short list of SETTINGS (leaf shape and
size, flower shape and colour, what is harvested, what the seed looks like).
The settings for each plant are in the KINDS list near the foot of the file.
"""
import json, math, os, re, sys
from plant_kit import Art, T, P, f, COLOURS, LEAF, BLOOM
import plants as S10

G = 72
GOLD = 2.39996  # the golden angle: spreads dots evenly over a round head


# ============================================================ small pieces
def on_layer(layer):
    """Written as @on_layer(LEAF) on the line above a function, this makes
    everything that function draws go on that layer (see Art.group)."""
    def wrap(fn):
        def inner(a, *args, **kw):
            with a.on(layer):
                return fn(a, *args, **kw)
        return inner
    return wrap


@on_layer(LEAF)
def LF(a, kind, x, y, ang, L, fill):
    """One leaf of the named kind, starting at x,y and pointing along ang."""
    if L < 2.5:
        return
    t = T(x, y, ang)
    if kind == "simple": a.leaf(x, y, ang, L, 0.44, fill)
    elif kind == "lance": a.leaf(x, y, ang, L, 0.2, fill)
    elif kind == "needle": a.leaf(x, y, ang, L * 0.7, 0.14, fill, lw=0.8)
    elif kind == "round": a.leaf(x, y, ang, L * 0.8, 0.86, fill, skew=0.5)
    elif kind == "heart": a.leaf(x, y, ang, L, 0.72, fill, skew=0.36)
    elif kind == "tooth": a.toothleaf(x, y, ang, L, L * 0.55, 9, fill)
    elif kind == "cut": a.toothleaf(x, y, ang, L, L * 0.5, 7, fill, 0.2)
    elif kind == "lobed":
        e = t(L * 0.3); a.line(f"M{f(x)},{f(y)} L{P(e)}", 1.1); a.lobedleaf(e[0], e[1], ang, L * 0.42, 5, fill)
    elif kind == "fern": a.fern(x, y, ang, L, fill=fill, pairs=5, bend=0.1)
    elif kind == "compound": a.compound(x, y, ang, L, pairs=2, fill=fill)
    elif kind == "trefoil":
        e = t(L * 0.5); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.9)
        for off in (-72, 72, 0):
            a.leaf(e[0], e[1], ang + off, L * 0.52, 0.72, fill, skew=0.55, lw=0.9)
    elif kind == "palm":
        e = t(L * 0.45); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.9)
        for k in range(7):
            a.leaf(e[0], e[1], ang - 78 + 26 * k, L * 0.55, 0.2, fill, lw=0.8)
    elif kind == "strap":
        ex, ey = t(L); ey += L * 0.22; cx, cy = t(L * 0.55); cy -= L * 0.06
        a.ribbon((x, y), (cx, cy), (ex, ey), max(1.3, L * 0.12), 0.4, fill)
    elif kind == "fan":
        a.polar(*t(L * 0.5), lambda th: 0.55 + 0.45 * max(0, math.cos(th)) ** 0.5, L * 0.5, L * 0.55, ang, fill)


@on_layer(BLOOM)
def FL(a, kind, x, y, r, col, cen="sun", ang=-90):
    """One flower of the named kind, r across (roughly), facing along ang."""
    t = T(x, y, ang)
    if kind == "daisy":
        for k in range(14):
            a.leaf(x, y, k * 360 / 14, r, 0.26, col, lw=0.7, skew=0.6, detail=False)
        a.oval(x, y, r * 0.36, r * 0.36, 0, cen, 0.8)
        for k in range(7):
            e = T(x, y, k * 51)(r * 0.2); a.dot(e[0], e[1], 0.35, "rust" if cen != "dark" else "straw")
    elif kind == "flat": a.flower(x, y, r, 5, col, cen, 0.74)
    elif kind == "four": a.flower(x, y, r, 4, col, cen, 0.74, start=-45)
    elif kind == "six": a.flower(x, y, r, 6, col, cen, 0.5)
    elif kind == "star": a.flower(x, y, r, 5, col, cen, 0.36)
    elif kind == "trumpet":
        a.flower(x, y, r, 6, col, None, 0.52); a.oval(x, y, r * 0.44, r * 0.44, 0, cen)
        a.oval(x, y, r * 0.22, r * 0.22, 0, None, 0.6, la=0.5)
    elif kind == "cup":
        for off in (-30, 30, 0):
            a.leaf(x, y, ang + off, r * 1.5, 0.62, col, skew=0.55, detail=False)
        a.line(f"M{P(t(r * 0.3))} L{P(t(r * 1.0))}", 0.5, 0.3)
    elif kind == "bell":
        a.leaf(x, y, ang, r * 1.9, 0.6, col, skew=0.68, detail=False)
        e = t(r * 1.9); a.line(f"M{P(t(r * 1.5, -r * 0.5))} Q{P(e)} {P(t(r * 1.5, r * 0.5))}", 0.6, 0.5)
    elif kind == "lip":
        a.leaf(x, y, ang - 24, r * 1.4, 0.5, col, detail=False, lw=0.8); a.leaf(x, y, ang + 26, r * 1.1, 0.5, col, detail=False, lw=0.8)
    elif kind == "pea":
        a.leaf(x, y, ang - 38, r * 1.6, 0.85, col, skew=0.55, detail=False, lw=0.9)
        a.leaf(x, y, ang + 22, r * 1.15, 0.5, cen if cen != "sun" else col, detail=False, lw=0.8)
    elif kind == "globe":
        a.oval(x, y, r, r, 0, col)
        for k in range(int(r * 2.2)):
            rr = r * 0.86 * math.sqrt((k + 0.5) / (r * 2.2)); a.flower(x + rr * math.cos(k * GOLD), y + rr * math.sin(k * GOLD), max(1.1, r * 0.15), 4, "white", None, 0.5, lw=0.4)
    elif kind == "umbel": a.umbel(x, y, ang, r * 1.5, col, 7, 125)
    elif kind == "tuft":
        for k in range(9):
            a.leaf(x, y, ang - 60 + 15 * k, r * 1.35, 0.17, col, lw=0.6, detail=False)
        c = t(-r * 0.1); a.oval(c[0], c[1], r * 0.5, r * 0.62, ang + 90, "deep", 0.8)
    elif kind == "plume":
        for k in range(16):
            rr = r * math.sqrt((k + 0.5) / 16); e = t(r * 0.6 + rr * math.cos(k * GOLD) * 1.1, rr * math.sin(k * GOLD) * 0.7)
            a.oval(e[0], e[1], r * 0.2, r * 0.2, 0, col, 0.5)
    else:  # "tiny": a small cluster
        for dx, dy in [(0, 0), (-0.9, -0.5), (0.9, -0.4), (-0.3, -1.1), (0.5, 0.7)]:
            a.oval(x + dx * r * 0.7, y + dy * r * 0.7, r * 0.42, r * 0.42, 0, col, 0.6)


@on_layer(BLOOM)
def FR(a, kind, x, y, r, col, side=1):
    """One fruit of the named kind hanging from x,y."""
    if kind == "round":
        a.oval(x, y + r, r, r * 0.94, 0, col); a.line(f"M{f(x - r * 0.35)},{f(y + r * 0.55)} Q{f(x - r * 0.6)},{f(y + r)} {f(x - r * 0.4)},{f(y + r * 1.4)}", 0.5, 0.3)
    elif kind == "pod":
        a.ribbon((x, y), (x + side * r * 1.6, y + r * 2.4), (x + side * r * 0.8, y + r * 5.4), r * 1.5, r * 1.2, col, round_tip=True)
    elif kind == "long":
        a.ribbon((x, y), (x + side * r * 1.2, y + r * 1.6), (x + side * r * 0.4, y + r * 4.2), r * 1.5, r * 0.5, col)
    elif kind == "egg":
        a.oval(x, y + r * 1.5, r * 0.95, r * 1.5, 0, col)
        for k in range(4):
            a.leaf(x, y + 0.4, 90 + (k - 1.5) * 38, r * 0.9, 0.4, "deep", lw=0.6, detail=False)
    elif kind == "pear":
        a.shape(f"M{f(x)},{f(y)} C{f(x + r * 0.6)},{f(y + r * 0.2)} {f(x + r * 0.5)},{f(y + r)} {f(x + r)},{f(y + r * 1.7)} C{f(x + r * 1.3)},{f(y + r * 2.7)} {f(x - r * 1.3)},{f(y + r * 2.7)} {f(x - r)},{f(y + r * 1.7)} C{f(x - r * 0.5)},{f(y + r)} {f(x - r * 0.6)},{f(y + r * 0.2)} {f(x)},{f(y)} Z", col)
    elif kind == "knob":
        for dx, dy in [(-0.5, 0.5), (0.5, 0.5), (0, 0.2), (-0.6, 1.2), (0.6, 1.2), (0, 1.0), (0, 1.75)]:
            a.oval(x + dx * r, y + dy * r + r * 0.3, r * 0.5, r * 0.5, 0, col, 0.6)
    elif kind == "string":
        for k in range(5):
            a.oval(x + side * 0.6 * (k % 2), y + 1.2 + k * r * 1.7, r * (1 - k * 0.07), r * (1 - k * 0.07), 0, col, 0.7)
    elif kind == "bunch":
        for row, n in enumerate([3, 3, 2, 1]):
            for k in range(n):
                a.oval(x + (k - (n - 1) / 2) * r * 1.7, y + r + row * r * 1.5, r, r, 0, col, 0.7)
    elif kind == "lantern":
        a.leaf(x, y, 90, r * 3, 0.8, col, skew=0.4)
    elif kind == "cob":
        a.ribbon((x, y), (x + side * r * 1.2, y - r * 2), (x + side * r * 1.8, y - r * 4.6), r * 2.1, r * 1.3, "pear", round_tip=True)
        e = (x + side * r * 1.8, y - r * 4.6)
        for k in (-1, 0, 1):
            a.line(f"M{P(e)} q{f(side * 2 + k)},{f(-2)} {f(side * 3 + k * 1.6)},{f(1.5)}", 0.6, 0.8, "amber")


@on_layer(BLOOM)
def SH(a, kind, x, y, r, ang=-90):
    """What is left when the flower has gone to seed."""
    t = T(x, y, ang)
    if kind == "head":
        for k in range(8):
            a.leaf(x, y, k * 45, r * 0.62, 0.3, "straw", lw=0.6, detail=False)
        a.oval(x, y, r * 0.42, r * 0.42, 0, "bark", 0.8)
        for k in range(8):
            rr = r * 0.32 * math.sqrt((k + 0.5) / 8); a.dot(x + rr * math.cos(k * GOLD), y + rr * math.sin(k * GOLD), 0.4, "dark")
    elif kind == "fluff":
        for k in range(11):
            e = T(x, y, k * 360 / 11)(r * 0.8); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.5, 0.55); a.dot(e[0], e[1], 0.4, "straw")
        a.dot(x, y, 0.9, "bark")
    elif kind == "capsule":
        c = t(r * 0.5); a.oval(c[0], c[1], r * 0.5, r * 0.62, ang + 90, "straw")
        a.line(f"M{P(t(r * 1.05, -r * 0.5))} L{P(t(r * 1.05, r * 0.5))}", 1.4, 0.9)
    elif kind == "pods":
        for off in (-34, 0, 34):
            e = T(x, y, ang + off)(r * 2.2); m = T(x, y, ang + off * 1.4)(r * 1.1)
            a.ribbon((x, y), m, e, 1.5, 0.5, "straw", lw=0.7)
    elif kind == "legume":
        a.ribbon((x, y), (x + r * 1.2, y + r * 2), (x + r * 0.4, y + r * 4.6), r * 1.3, r * 1.0, "dark", round_tip=True)
    elif kind == "umbel":
        a.umbel(x, y, ang, r * 1.5, "straw", 7, 125, curl=1)
    elif kind == "burr":
        a.oval(x, y, r, r, 0, "straw")
        for k in range(int(r * 2.4)):
            rr = r * 0.85 * math.sqrt((k + 0.5) / (r * 2.4)); a.dot(x + rr * math.cos(k * GOLD), y + rr * math.sin(k * GOLD), max(0.5, r * 0.07), "dark")
    else:  # "dry"
        c = t(r * 0.3); a.oval(c[0], c[1], max(1.0, r * 0.4), max(1.2, r * 0.5), ang + 90, "straw", 0.7)


def bloom(a, s, stage, x, y, ang=-90, scale=1.0, side=1):
    r = s.get("fr", 4) * scale
    if stage == "seedhead":
        SH(a, s.get("sh", "dry"), x, y, r, ang)
    elif stage == "crop" and s.get("crop") in ("fruit", "pod"):
        k, c, fr_ = s["fruit"]; FR(a, k, x, y, fr_ * scale, c, side)
    elif stage in ("flower", "crop"):
        FL(a, s["fl"], x, y, r, s["fc"], s.get("cen", "sun"), ang)


# ============================================================== templates
def stemplant(a, s, bx, by, H, stage, lean=0.0, leaves=True, bare=False):
    """One stem with its leaves, and its flowers, fruit or seed heads when
    the stage calls for them. Used on its own and several at a time."""
    dry = stage == "seedhead"
    lc = "straw" if dry else s["lc"]; sc = "straw" if dry else s.get("sc", "leaf")
    top = (bx + lean, by - H)
    q = a.ribbon((bx, by), (bx + lean * 0.3 + (1.2 if H > 30 else 0.4), by - H * 0.5), top, max(1.5, H * 0.045), max(0.9, H * 0.02), sc)
    arr = s.get("arr", "top")
    show = (stage in ("flower", "seedhead") and s.get("fl")) or (stage == "crop" and s.get("crop") in ("fruit", "pod"))
    spire = arr == "spire" and show
    dense = s["leaf"] == "needle"
    n = max(3, int(H / (4.5 if dense else 10))); umax = 0.55 if spire else 0.9
    k = min(1.0, 0.55 + H / 110)
    for i in range(n):
        u = 0.14 + (umax - 0.14) * i / (n - 1); x, y = q.pt(u); side = -1 if i % 2 else 1
        ang = -90 + side * (58 + (32 if dry else 0))
        if bare:
            e = T(x, y, -90 + side * 50)(H * 0.13); a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.9, 0.85); a.dot(e[0], e[1], 0.7, "bark")
            continue
        if leaves:
            L = s["ls"] * k * (1 - 0.35 * u)
            LF(a, s["leaf"], x, y, ang, L, lc)
            if s.get("opp") or dense:
                LF(a, s["leaf"], x, y, -180 - ang, L, lc)
        if arr == "axil" and show and i > 0 and (i % 2 or n < 6):
            bloom(a, s, stage, x - side * 2.2, y - 0.5, -90 - side * 48, 1.0, -side)
    if bare:
        a.dot(top[0], top[1], 0.8, "bark"); return q
    if show and arr == "top":
        bloom(a, s, stage, top[0], top[1], -90)
    elif show and arr in ("heads", "spray"):
        m = 2 if arr == "heads" else 4
        for j in range(m):
            u = 0.56 + 0.34 * j / m; x, y = q.pt(u); side = -1 if j % 2 else 1
            ex, ey = x + side * H * (0.24 - 0.03 * j), y - H * (0.17 - 0.02 * j)
            a.stem((x, y), (x + side * H * 0.1, y - H * 0.02), (ex, ey), 1.0)
            bloom(a, s, stage, ex, ey, -90 + side * 18, 0.8)
        bloom(a, s, stage, top[0], top[1], -90)
    elif spire:
        m = max(5, int(H * 0.46 / max(2.6, s.get("fr", 3) * 0.95)))
        for j in range(m):
            u = 0.56 + 0.43 * j / (m - 1); x, y = q.pt(u); side = -1 if j % 2 else 1
            if j >= m - 2 and stage == "flower":
                with a.on(BLOOM):
                    a.oval(x + side * 0.8, y, 1.0, 1.3, 0, "unripe", 0.6)
                continue
            down = s.get("fl") == "bell"
            ang = (0 if side > 0 else 180) + side * (32 if down else -34)
            bloom(a, s, stage, x + side * 0.9, y, ang, 1 - 0.4 * j / m)
    elif not show and not dense and stage != "seedhead":
        LF(a, s["leaf"], top[0], top[1], -112, s["ls"] * k * 0.42, lc); LF(a, s["leaf"], top[0], top[1], -68, s["ls"] * k * 0.42, lc)
    return q


ROS = [-172, -8, -150, -30, -126, -54, -104, -76, -90]


def rosette(a, s, bx, by, size, stage, n=7):
    """Leaves fanning out from one point on the ground."""
    dry = stage == "seedhead"; lc = "straw" if dry else s["lc"]
    for i, ang in enumerate(ROS[:n] if n < 9 else ROS):
        L = s["ls"] * size * (0.72 + 0.28 * (1 - abs(ang + 90) / 90))
        if s.get("stalkc"):
            t = T(bx, by, ang); e = t(L * 0.5)
            a.ribbon((bx, by), t(L * 0.25, 1), e, 3.0 * size, 2.0 * size, "straw" if dry else s["stalkc"])
            LF(a, s["leaf"], e[0], e[1], ang, L * 0.62, lc)
        else:
            LF(a, s["leaf"], bx, by, ang, L, lc)


def root(a, s, x, y, scale=1.0):
    kind, colr, w, L = s["root"]; w *= scale; L *= scale
    if kind == "long":
        S10.carrot_root(a, x, y, w, L, colr, rings=3 if scale > 0.7 else 0)
    else:
        ry = L / 2; cy = y + ry * 0.72
        a.oval(x, cy, w / 2, ry, 0, colr)
        a.line(f"M{f(x - w * 0.3)},{f(cy - ry * 0.3)} Q{f(x - w * 0.42)},{f(cy)} {f(x - w * 0.3)},{f(cy + ry * 0.4)}", 0.6, 0.35)
        a.line(f"M{f(x)},{f(cy + ry)} Q{f(x + 1.5)},{f(cy + ry + L * 0.2)} {f(x)},{f(cy + ry + L * 0.36)}", 0.9, 0.85, colr)
        if s.get("top"):
            a.shape(f"M{f(x - w * 0.47)},{f(cy - ry * 0.3)} Q{f(x)},{f(cy - ry * 1.5)} {f(x + w * 0.47)},{f(cy - ry * 0.3)} Q{f(x)},{f(cy - ry * 0.05)} {f(x - w * 0.47)},{f(cy - ry * 0.3)} Z", s["top"], 0.8)


def body(a, s, stage, size, by=88):
    """The whole plant above the ground, by its habit. It is drawn as one
    group, so all its stems go behind all its leaves, and all its leaves
    behind all its flowers and fruit, however many stems it has."""
    with a.group():
        _body(a, s, stage, size, by)


def _body(a, s, stage, size, by):
    h = s["habit"]; H = s["H"] * size
    if h == "up":
        stemplant(a, s, 50, by, H, stage)
    elif h in ("clump", "bush", "mound", "cane"):
        fan = {"clump": [(-0.3, 0.8), (0.3, 0.82), (-0.12, 0.94), (0.14, 0.9), (0, 1)],
               "bush": [(-0.62, 0.72), (0.62, 0.74), (-0.3, 0.92), (0.3, 0.9), (0, 1)],
               "mound": [(-0.8, 0.6), (0.8, 0.6), (-0.52, 0.8), (0.52, 0.8), (-0.24, 0.94), (0.24, 0.94), (0, 1)],
               "cane": [(-0.34, 0.88), (0.34, 0.9), (0, 1)]}[h]
        if h == "cane":
            for px in (16, 84):
                a.ribbon((px, by), (px, by - 30), (px, by - 62), 2.4, 2.2, "bark")
            for wy in (by - 28, by - 54):
                a.line(f"M16,{wy} L84,{wy}", 0.7, 0.6)
        for lean, hh in fan:
            stemplant(a, s, 50 + lean * 9, by, H * hh, stage, lean=lean * H * (0.9 if h != "clump" else 1), bare=(stage == "dormant"))
    elif h == "ros":
        tall = stage in ("flower", "seedhead")
        rosette(a, s, 50, by, size * (0.72 if tall else 1), stage, n=5 if tall else 7)
        if tall:
            s2 = dict(s, ls=s["ls"] * 0.42)
            for lean, hh in ([(0, 1)] if s.get("scapes", 1) == 1 else [(-0.22, 0.85), (0.22, 0.9), (0, 1)]):
                stemplant(a, s2, 50, by - 1, s["H"] * hh, stage, lean=lean * s["H"], leaves=not s.get("scape"))
    elif h == "climb":
        a.ribbon((50, by), (50, by - 40), (50, 7), 1.7, 1.5, "bark")
        q = stemplant(a, s, 46, by, H, stage, lean=8)
        if size > 0.6:
            for u in (0.36, 0.6, 0.82):
                x, y = q.pt(u); a.line(f"M{f(x)},{f(y)} q5,-4 7,0 q0,3 -3,2", 0.6, 0.7)
    elif h == "trail":
        for sgn in (-1, 1):
            q = a.ribbon((50, by - 2), (50 + sgn * 20 * size, by - 9), (50 + sgn * 41 * size, by - 3), 2.2, 1.2, "pale")
            for u in (0.4, 0.78):
                x, y = q.pt(u); e = (x + sgn * 3, y - s["H"] * size * (1.15 - u * 0.4))
                a.stem((x, y), (x, (y + e[1]) / 2), e, 1.2)
                LF(a, s["leaf"], e[0], e[1] + 3, -90 + sgn * 22, s["ls"] * (0.6 + 0.4 * size), s["lc"])
            if stage == "flower":
                x, y = q.pt(0.6); a.stem((x, y), (x, y - 5), (x + sgn * 2, y - 11), 1.0); FL(a, s["fl"], x + sgn * 2, y - 12, s["fr"], s["fc"], s.get("cen", "sun"))
            if stage == "crop":
                k, c, r = s["fruit"]; x, y = q.pt(0.95)
                with a.on(BLOOM):
                    if k == "long":
                        a.ribbon((x - sgn * 6, by - 4), (x + sgn * 2, by - 6), (x + sgn * 9, by - 3.6), r * 1.1, r * 0.95, c, round_tip=True)
                    else:
                        a.oval(x, by - r * 0.92, r * 1.1, r * 0.92, 0, c)
                        for dx in (-0.45, 0, 0.45):
                            a.line(f"M{f(x + dx * r)},{f(by - r * 1.75)} Q{f(x + dx * r * 2.1)},{f(by - r)} {f(x + dx * r)},{f(by - r * 0.1)}", 0.5, 0.3)
        e = (50, by - 2 - s["H"] * size * 1.25); a.stem((50, by - 2), (50, by - 10), e, 1.2)
        LF(a, s["leaf"], e[0], e[1] + 3, -90, s["ls"] * (0.6 + 0.4 * size), s["lc"])
    elif h == "mat":
        W = 42 * (0.45 + 0.55 * size); hh = s["H"] * (0.5 + 0.5 * size)
        pts = [(50 + W * math.cos(math.pi + math.pi * i / 30), by - hh * math.sin(math.pi * i / 30) * (1 + 0.05 * math.sin(i * 1.9))) for i in range(31)]
        a.shape("M" + " L".join(P(p) for p in pts) + " Z", "straw" if stage == "seedhead" else s["lc"])
        for k in range(26):
            rr = math.sqrt((k + 0.5) / 26); th = k * GOLD
            x, y = 50 + W * 0.88 * rr * math.cos(th), by - 1 - abs(hh * 0.86 * rr * math.sin(th))
            if stage in ("flower", "seedhead") and k % 3 == 0 and s.get("fl"):
                bloom(a, s, stage, x, y - 1, -90, 1.0)
            else:
                a.leaf(x, y, -90 + 60 * math.sin(k * 1.7), s["ls"], 0.5, None, lw=0.6)


# ================================================================== starts
def round_seed(a, x, y):
    for dx, dy, r in [(-9, 2, 6.5), (7, -3, 7.5), (2, 9, 5.5)]:
        a.oval(x + dx, y + dy, r, r, 0, "bark"); a.line(f"M{x + dx - r * 0.5},{y + dy - r * 0.3} Q{x + dx - r * 0.2},{y + dy - r * 0.7} {x + dx + r * 0.3},{y + dy - r * 0.6}", 0.6, 0.35)


def pea_seed(a, x, y):
    a.polar(x, y, lambda th: 1 + 0.04 * math.cos(5 * th + 1), 11, 10.5, 0, "pear")
    a.line(f"M{x - 5},{y - 3} Q{x - 1},{y - 6} {x + 4},{y - 4} M{x - 4},{y + 4} Q{x + 1},{y + 6} {x + 6},{y + 2}", 0.6, 0.4); a.dot(x + 8.6, y - 3, 1.2, "dark")


def dust_seed(a, x, y):
    for k in range(14):
        rr = 13 * math.sqrt((k + 0.5) / 14); a.oval(x + rr * math.cos(k * GOLD) * 1.3, y + rr * math.sin(k * GOLD) * 0.8, 1.5, 1.1, k * 40, "bark", 0.6)


def corn_seed(a, x, y):
    a.shape(f"M{x},{y + 12} C{x - 5},{y + 8} {x - 11},{y - 2} {x - 9},{y - 9} C{x - 5},{y - 13} {x + 5},{y - 13} {x + 9},{y - 9} C{x + 11},{y - 2} {x + 5},{y + 8} {x},{y + 12} Z", "sun")
    a.line(f"M{x - 4},{y - 7} Q{x},{y - 3} {x + 4},{y - 7}", 0.7, 0.4)


def knob_seed(a, x, y):
    a.polar(x, y, lambda th: 1 + 0.14 * math.cos(5 * th) + 0.07 * math.sin(9 * th), 11, 10, 0, "bark")
    a.line(f"M{x - 4},{y - 2} L{x + 1},{y + 1} L{x + 5},{y - 3} M{x + 1},{y + 1} L{x},{y + 6}", 0.7, 0.4)


SEEDS = {"ridged": S10.carrot_seed, "bean": S10.bean_seed, "disc": S10.tomato_seed, "slim": S10.lettuce_seed,
         "black": S10.leek_seed, "flat": S10.courgette_seed, "stripe": S10.sunflower_seed, "round": round_seed,
         "pea": pea_seed, "dust": dust_seed, "corn": corn_seed, "knob": knob_seed}


def start_piece(s, kind):
    a = Art(); a.ground(38, marks=False)
    for dx, dy, w in [(-30, 46, 4), (27, 50, 3), (-24, 80, 3), (28, 76, 4)]:
        a.line(f"M{50 + dx},{dy} L{50 + dx + w},{dy}", 0.9, 0.55, "soil")
    if kind == "tuber":
        a.polar(50, 64, lambda th: 1 + 0.05 * math.cos(3 * th + 1), 17, 12, -8, "seed")
        for dx, dy in [(-8, -9), (2, -12), (10, -8)]:
            a.ribbon((50 + dx, 64 + dy + 3), (50 + dx - 1, 64 + dy - 1), (50 + dx + 1, 64 + dy - 5), 2.4, 1.0, "plum", lw=0.8)
        for dx, dy in [(-6, 3), (7, 4), (0, -1)]:
            a.line(f"M{50 + dx - 1.5},{64 + dy} q1.5,-1.4 3,0", 0.6, 0.45)
    elif kind == "clove":
        a.leaf(50, 79, -84, 30, 0.62, "white", skew=0.34); a.line("M49,77 L52,77", 1.6, 0.8, "bark")
    elif kind == "set":
        S10.bulb(a, 50, 64, 1.5)
    elif kind == "crown":
        a.polar(50, 62, lambda th: 1 + 0.1 * math.cos(4 * th), 14, 8, 0, "bark")
        a.roots(50, 68, 7, 16, 150, lw=1.2)
        for dx in (-7, 0, 7):
            a.leaf(50 + dx, 57, -90 + dx * 2, 9, 0.5, s.get("budc", "pink"), detail=False)
    return a


def seedling(s):
    a = Art(); a.ground(G); a.roots(50, G, 3, 12, 50); cot = s.get("cot", "round"); lc = s["lc"]
    if cot == "grass":
        a.ribbon((50, G), (49, G - 12), (53, G - 26), 2.0, 0.4, lc); a.ribbon((50, G), (51, G - 8), (45, G - 16), 1.6, 0.4, lc); return a
    h = 15 if cot != "bean" else 20
    a.ribbon((50, G), (49.3, G - h * 0.5), (50, G - h), 1.9 if cot in ("oval", "bean") else 1.3, 1.3, "pale")
    b, L = {"narrow": (0.16, 15), "round": (0.72, 10), "oval": (0.56, 18), "bean": (0.6, 8)}[cot]
    cy = G - h if cot != "bean" else G - 7
    a.leaf(50, cy, -162, L, b, "pale"); a.leaf(50, cy, -18, L, b, "pale")
    L2 = min(14, max(8, s["ls"] * 0.55))
    if cot == "bean":
        a.leaf(50, G - h, -150, 13, 0.7, lc, skew=0.36); a.leaf(50, G - h, -30, 13, 0.7, lc, skew=0.36)
    else:
        LF(a, s["leaf"], 50, G - h, -104, L2, lc); LF(a, s["leaf"], 50, G - h, -68, L2 * 0.6, lc)
    return a


def dormant_herb(s):
    a = Art(); a.ground(88)
    for dx, hh, ln in [(-13, 15, -5), (-5, 24, -1), (5, 19, 3), (14, 13, 6), (0, 11, 0)]:
        a.ribbon((50 + dx, 88), (50 + dx + ln * 0.3, 88 - hh * 0.5), (50 + dx + ln, 88 - hh), 2.6, 2.0, "straw", lw=0.9)
        a.line(f"M{f(50 + dx + ln - 1.4)},{f(88 - hh)} l2.8,-0.6", 0.8, 0.7)
    for ang in (-166, -14, -128, -52, -90):
        LF(a, s["leaf"] if s["leaf"] not in ("fern", "compound", "strap", "palm", "lobed") else "simple", 50, 88, ang, 13, "deep")
    return a


# ======================================================== woody and bulbs
SPOTS = S10.SPOTS


def tree(s, stage):
    a = Art(); a.ground(88)
    if stage == "young":
        a.ribbon((58, 88), (58, 66), (58, 44), 2.4, 2.4, "bark")
        q = a.stem((50, 88), (48.5, 54), (50, 20), 1.9); a.oval(50, 81, 2.1, 1.5, 0, "bark", 0.8)
        a.line("M49.4,58 Q54,56 58,58", 1.2, 0.9, "soil")
        for i in range(8):
            u = 0.36 + 0.08 * i; x, y = q.pt(u); side = -1 if i % 2 else 1
            LF(a, s["leaf"] if s["leaf"] != "lobed" else "heart", x, y, -90 + side * 58, 10.5 - i * 0.3, s["lc"])
        return a
    if stage == "dormant":
        S10.fork(a, 50, 62, -122, 21, 3, 2.3); S10.fork(a, 50, 60, -58, 21, 3, 2.3); S10.fork(a, 50, 58, -90, 20, 2, 2.0)
        a.ribbon((50, 88), (49.4, 72), (50, 56), 6.4, 4.2, "bark")
        for dx, dy in [(-22, -30), (-9, -44), (12, -42), (24, -28), (2, -52)]:
            a.dot(50 + dx, 62 + dy, 0.8, "bark")
        return a
    rx, ry = {"round": (33, 27), "tall": (24, 31), "wide": (37, 23)}[s.get("canopy", "round")]
    cy = 62 - ry + 2
    a.line("M50,64 Q42,58 36,50", 2.0, 0.9); a.line("M50,62 Q58,56 63,49", 2.0, 0.9)
    a.ribbon((50, 88), (49.4, 74), (50, 58), 6.4, 4.4, "bark")
    a.line("M48.6,84 L48.9,70 M51.6,80 L51.3,66", 0.5, 0.35)
    a.polar(50, cy, lambda th: 1 + 0.055 * math.cos(7 * th) + 0.03 * math.sin(11 * th), rx, ry, 0, "amber" if stage == "autumn" else s["lc"])
    for k in range(30):  # leaves hinted all over the crown
        rr = math.sqrt((k + 0.5) / 30); x, y = 50 + rx * 0.84 * rr * math.cos(k * GOLD), cy + ry * 0.84 * rr * math.sin(k * GOLD)
        a.leaf(x, y, -60 + 50 * math.sin(k * 2.1), 4.6, 0.5, "primrose" if stage == "autumn" else "deep", lw=0.5, detail=False)
    fk, fc_, fr_ = s.get("fruit") or ("round", "berry", 4)
    for i, (dx, dy) in enumerate(SPOTS):
        x, y = 50 + dx * rx / 33, cy + dy * ry / 27
        if stage == "flower":
            a.flower(x, y, 4.4, 5, s["fc"] if i % 3 else "white", "sun", 0.7, start=-90 + i * 23, cr=1.1, lw=0.6)
        elif stage == "set" and i % 5 != 4:
            a.oval(x, y, 2.4, 2.5, 0, "unripe", 0.8)
        elif stage == "crop" and i % 5 != 4:
            a.line(f"M{f(x)},{f(y - 0.4)} L{f(x + 0.8)},{f(y - 2.6)}", 0.8)
            FR(a, fk, x, y - 0.4, fr_ if fk != "pear" else fr_ * 0.62, fc_ if i % 4 else s.get("fruit2", fc_))
    if stage == "flower":
        a.leaf(74, 72, 60, 3.4, 0.6, s["fc"], lw=0.6, detail=False); a.leaf(27, 78, 110, 3.4, 0.6, s["fc"], lw=0.6, detail=False)
    if stage == "autumn":
        for x, y, r in [(22, 86, 30), (70, 85, 200), (80, 70, 110)]:
            a.leaf(x, y, r, 5, 0.5, "amber", lw=0.6, detail=False)
    if stage == "crop" and fk in ("round", "pear"):
        FR(a, fk, 73, 80 if fk == "round" else 79, fr_ if fk != "pear" else fr_ * 0.62, fc_)
    return a


def vine(s, stage):
    a = Art(); a.ground(88)
    for px in (12, 88):
        a.ribbon((px, 88), (px, 60), (px, 30), 2.4, 2.2, "bark")
    a.line("M12,44 L88,44", 0.7, 0.6)
    a.ribbon((50, 88), (48, 66), (50, 44), 4.6, 3.2, "bark")
    if stage == "young":
        a.stem((50, 60), (51, 40), (50, 26), 1.3)
        for y, sd in [(52, 1), (42, -1), (33, 1)]:
            LF(a, s["leaf"], 50, y, -90 + sd * 60, s["ls"] * 0.8, s["lc"])
        return a
    for sgn in (-1, 1):
        q = a.ribbon((50, 46), (50 + sgn * 16, 41), (50 + sgn * 36, 44), 2.6, 1.4, "bark", lw=0.9)
        for i, u in enumerate((0.3, 0.62, 0.94)):
            x, y = q.pt(u)
            if stage == "dormant":
                a.line(f"M{f(x)},{f(y)} L{f(x + sgn * 2)},{f(y - 9)}", 1.0, 0.85); a.dot(x + sgn * 2, y - 9.6, 0.8, "bark"); continue
            e = (x + sgn * 3, y - 17 + i * 2); a.stem((x, y), (x, y - 8), e, 1.1)
            LF(a, s["leaf"], e[0], e[1] + 4, -90 + sgn * 15, s["ls"], s["lc"])
            LF(a, s["leaf"], x, y - 5, -90 - sgn * 70, s["ls"] * 0.7, s["lc"])
            if stage == "flower":
                FL(a, "plume", x, y + 2, 4, s["fc"], ang=90)
            if stage == "crop":
                k, c, r = s["fruit"]; a.line(f"M{f(x)},{f(y)} L{f(x)},{f(y + 4)}", 0.8); FR(a, k, x, y + 3, r, c)
    return a


def bulbplant(s, stage):
    if stage == "bulb":
        return S10.snowdrop_bulb()
    if stage == "dormant":
        return S10.snowdrop_dormant()
    a = Art(); a.ground(66); H = s["H"]; lc = s["lc"]; top = (50, 72 - H)
    if stage == "shoots":
        for dx, hh in [(-2.6, 13), (0, 19), (2.8, 15)][: s.get("nl", 3)]:
            a.ribbon((50 + dx, 70), (50 + dx * 1.2, 70 - hh * 0.5), (50 + dx * 1.6, 70 - hh), 3.6, 0.8, lc)
        S10.bulb(a, 50, 79, 0.85); return a
    seed = stage == "seedhead"; wide = s.get("bleaf") == "broad"
    lcol = "straw" if seed else lc
    ends = [(-22, 0.62), (20, 0.56), (-9, 0.8), (11, 0.74)][: s.get("nl", 4)]
    for dx, hh in ends:
        e = (50 + dx * (1.5 if seed else 1), 72 - H * hh * (0.6 if seed else 1))
        a.ribbon((50 + dx * 0.08, 72), (50 + dx * 0.35, 72 - H * hh * 0.6), e, 7 if wide else 3.8, 0.9, lcol, round_tip=True)
    fl = s["fl"]; fc = s["fc"]; r = s["fr"]
    if fl == "goblet":   # crocus: the flower comes almost straight from the ground
        if seed:
            a.stem((50, 72), (52, 64), (56, 62), 1.0); a.oval(57, 62, 2.2, 3, 60, "unripe")
        else:
            a.ribbon((50, 72), (50, 62), (50, 54), 2.2, 2.0, "white")
            FL(a, "cup", 50, 56, r, fc); a.line("M50,50 L50,45", 1.6, 0.9, "carrot")
    else:
        bend = s.get("bend", 0)
        q = a.stem((50, 72), (50 - bend * 0.3, 72 - H * 0.6), (50 + bend, top[1]), 1.5)
        x, y = 50 + bend, top[1]
        if seed:
            a.oval(x, y - 2, 2.6, 3.8, bend, "unripe"); a.line(f"M{f(x)},{f(y - 4)} L{f(x)},{f(y + 0)}", 0.5, 0.4)
        elif fl in ("bells", "spike"):
            m = 7
            for j in range(m):
                u = 0.56 + 0.44 * j / (m - 1); px, py = q.pt(u); side = 1 if fl == "bells" else (-1 if j % 2 else 1)
                if fl == "bells":
                    a.line(f"M{f(px)},{f(py)} q3,-1.5 4.4,0.6", 0.6); FL(a, "bell", px + 4.4, py + 0.6, r * (1 - j * 0.06), fc, ang=80)
                else:
                    a.oval(px + side * 1.7, py, r * (1 - j * 0.07), r * 0.85 * (1 - j * 0.07), 0, fc, 0.7)
        elif fl == "nod":
            a.stem((x, y), (x + 5, y - 5), (x + 9, y + 1), 1.2)
            FL(a, "bell", x + 9, y + 1, r, fc, ang=90)
            for k in range(6):
                a.dot(x + 9 + (k % 2 - 0.5) * r * 0.5, y + 4 + k * r * 0.26, 0.5, "white")
        elif fl == "crown":
            for k in range(5):
                ang = 20 + k * 35; e = T(x, y, ang)(5)
                a.line(f"M{f(x)},{f(y)} L{P(e)}", 0.7); FL(a, "bell", e[0], e[1], r, fc, ang=90)
            for k in range(7):
                a.leaf(x, y, -150 + k * 20, 9, 0.2, lc, lw=0.8)
        elif fl == "iris":
            for off in (-34, 34, 0):
                a.leaf(x, y, -90 + off, r * 1.5, 0.5, fc, detail=False)
            for off in (-62, 62):
                a.leaf(x, y, 90 + off, r * 1.5, 0.6, fc, skew=0.6, detail=False)
                e = T(x, y, 90 + off)(r * 0.8); a.line(f"M{f(x)},{f(y)} L{P(e)}", 1.2, 0.9, "sun")
        elif fl == "stars":
            for j, u in enumerate((0.7, 0.85, 1.0)):
                px, py = q.pt(u); FL(a, "six", px + (4 if j % 2 else -4), py, r, fc, "plum")
        else:
            FL(a, fl, x, y, r, fc, s.get("cen", "sun"))
    S10.bulb(a, 50, 81, 0.8)
    return a


def cyclamen(s, stage):
    a = Art(); a.ground(70)
    if stage in ("flower", "seedhead"):
        for dx, hh in [(-12, 26), (2, 32), (14, 24)]:
            q = a.stem((50, 72), (50 + dx * 0.4, 72 - hh * 0.7), (50 + dx, 72 - hh), 1.0)
            if stage == "flower":
                FL(a, "cup", 50 + dx, 72 - hh + 2, 5, s["fc"], ang=-90); a.dot(50 + dx, 72 - hh + 2.6, 1.0, "beet")
            else:
                a.line(f"M{f(50 + dx)},{f(72 - hh)} q4,-2 5,3 q0,4 -4,3", 0.9); a.oval(50 + dx + 1, 72 - hh + 6, 2, 2, 0, "unripe", 0.7)
    if stage != "dormant" and stage != "bulb":
        for ang, L in [(-165, 17), (-15, 17), (-135, 15), (-45, 15)] if stage != "flower" else [(-168, 12), (-12, 12)]:
            e = T(50, 72, ang)(L * 0.55); a.line(f"M50,72 L{P(e)}", 0.9); a.leaf(e[0], e[1], ang, L * 0.8, 0.8, "deep", skew=0.36)
            m = T(e[0], e[1], ang)(L * 0.36); a.oval(m[0], m[1], L * 0.2, L * 0.12, ang, None, 0.6, col="white", la=0.7)
    a.polar(50, 79, lambda th: 1 + 0.05 * math.cos(3 * th), 9 if stage != "bulb" else 13, 5.5 if stage != "bulb" else 8, 0, "bark")
    a.roots(50, 73.5 if stage != "bulb" else 71, 5, 5, 150)
    return a


def asparagus(s, stage):
    a = Art(); a.ground(84 if stage != "crown" else 38)
    if stage == "crown":
        return start_piece(dict(budc="unripe"), "crown")
    if stage == "crop":
        for dx, hh in [(-14, 30), (-4, 44), (7, 36), (16, 22)]:
            a.ribbon((50 + dx, 84), (50 + dx, 84 - hh * 0.5), (50 + dx + 0.6, 84 - hh), 4.2, 3.2, "unripe", round_tip=True)
            for k in range(5):
                y = 84 - hh + 2.5 + k * 3.0; sd = 1 if k % 2 else -1
                a.leaf(50 + dx + sd * 1.0, y + 2.6, -90 + sd * 12, 3.4, 0.5, "plum" if k < 2 else "deep", lw=0.5, detail=False)
        return a
    colr = "amber" if stage == "dormant" else "leaf"
    for lean, hh in [(-12, 56), (10, 66), (0, 72)]:
        q = a.stem((50 + lean * 0.3, 84), (50 + lean * 0.4, 84 - hh * 0.5), (50 + lean, 84 - hh), 1.3)
        for i in range(7):
            u = 0.3 + 0.1 * i; x, y = q.pt(u); sd = 1 if i % 2 else -1
            e = (x + sd * (15 - i), y - 7); a.line(f"M{f(x)},{f(y)} Q{f(x + sd * 6)},{f(y - 6)} {P(e)}", 0.7)
            for k in range(5):
                px, py = x + (e[0] - x) * (0.3 + 0.17 * k), y + (e[1] - y) * (0.3 + 0.17 * k) - 1
                a.line(f"M{f(px)},{f(py)} l{f(sd * 1.8)},-3.4 M{f(px)},{f(py)} l{f(-sd * 1.2)},-3", 0.5, 0.7, "line" if colr == "leaf" else "amber")
            if stage == "seedhead" and i % 2:
                a.oval(x + sd * 6, y - 2.5, 1.5, 1.5, 0, "berry", 0.6)
    return a


# ============================================================ every stage
LABEL = {"seed": "Seed", "seedling": "Seedling", "young": "Young plant", "flower": "In flower", "seedhead": "Gone to seed",
         "dormant": "Winter", "tuber": "Seed tuber", "clove": "Clove", "set": "Set", "crown": "Crown", "bulb": "Bulb",
         "shoots": "Shoots", "set_": "Fruit set", "growing": "In leaf", "autumn": "Autumn"}
CROPLAB = {"root": "Ready to pull", "leaf": "Ready to pick", "head": "Ready to cut", "fruit": "Fruiting", "pod": "Pods to pick",
           "bulb": "Ready to lift", "tuber": "Ready to dig", "stalk": "Ready to pull", "bud": "Ready to cut"}


def stages(s):
    h = s["habit"]
    if h == "tree":
        st = ["young", "growing" if s.get("ever") else "dormant", "growing" if s.get("noflower") else "flower"]
        if s.get("fruit"): st += ["set", "crop"]
        if s.get("autumn"): st += ["autumn"]
        return st
    if h in ("bulb", "cyclamen"):
        return ["bulb", "shoots", "flower", "seedhead", "dormant"]
    if h == "asparagus":
        return ["crown", "crop", "growing", "seedhead", "dormant"]
    if h in ("bush", "cane", "vine"):
        st = ["young"] + ([] if s.get("ever") else ["dormant"]) + ["flower"]
        return st + (["crop"] if s.get("crop") else ["growing"])
    if h == "mound":
        return ["young", "crop" if s.get("crop") else "growing", "flower"] + (["seedhead"] if s.get("sh") else [])
    start = s.get("start", "seed")
    st = ["seed", "seedling"] if start == "seed" else ([] if start == "plant" else [start])
    st.append("young"); crop = s.get("crop")
    first = crop in ("root", "leaf", "head", "bulb", "stalk", "bud") or s.get("veg")
    if first: st.append("crop")
    if s.get("fl"): st.append("flower")
    if crop and not first: st.append("crop")
    if s.get("sh"): st.append("seedhead")
    if s.get("per"): st.append("dormant")
    return st


def label(s, stage):
    if stage == "crop": return s.get("croplab") or CROPLAB.get(s.get("crop"), "Ready to pick")
    if stage == "set": return "Fruit set" if s["habit"] == "tree" else "Set"
    if stage == "young" and s["habit"] == "tree": return "Young tree"
    if stage == "flower":
        if s["habit"] == "tree": return "Blossom"
        return "In flower (year 2)" if s.get("bi") else "In flower"
    if stage == "seedhead" and s["habit"] == "asparagus": return "Fern and berries"
    if stage == "growing" and s["habit"] == "asparagus": return "Fern"
    if stage == "dormant" and s["habit"] in ("bulb", "cyclamen"): return "Dormant"
    if stage == "bulb" and s["habit"] == "cyclamen": return "Tuber"
    return LABEL[stage]


def make(s, stage):
    h = s["habit"]
    if h == "tree": return tree(s, stage)
    if h == "vine": return vine(s, "flower" if stage == "growing" else stage)
    if h == "bulb": return bulbplant(s, stage)
    if h == "cyclamen": return cyclamen(s, stage)
    if h == "asparagus": return asparagus(s, stage)
    if stage == "seed": return S10.sown(SEEDS[s.get("seed", "round")])()
    if stage in ("tuber", "clove", "set", "crown"): return start_piece(s, stage)
    if stage == "seedling": return seedling(s)
    if stage == "dormant" and h not in ("bush", "cane", "mound"): return dormant_herb(s)
    a = Art(); crop = s.get("crop"); woody = h in ("bush", "cane", "mound")
    if stage == "young":
        if crop in ("root", "bulb") and not s.get("above"):
            a.ground(G); rosette(a, s, 50, G - 1, 0.62, stage, n=5)
            if crop == "root": root(a, s, 50, G, 0.32)
            else: a.ribbon((50, G + 7), (50, G), (50, G - 6), 4, 3.2, "white"); a.roots(50, G + 7, 4, 7, 90)
        else:
            a.ground(88); body(a, s, stage, 0.8 if h in ("ros", "trail", "mat") else 0.6)
        return a
    if stage == "crop" and crop == "root":
        if s.get("above"):
            a.ground(84); k_, colr, w, L = s["root"]
            for ang in (-150, -30, -120, -60, -90):
                e = T(50, 84 - L * 0.55, ang)(w * 0.42); q = a.stem(e, T(*e, ang)(8), T(*e, ang - (ang + 90) * 0.3)(20), 1.4)
                LF(a, s["leaf"], *q.pt(1), ang - (ang + 90) * 0.3, s["ls"] * 0.6, s["lc"])
            a.oval(50, 84 - L * 0.5, w / 2, L / 2, 0, colr); a.roots(50, 84, 3, 8, 70)
            a.line(f"M{50 - w * 0.3},{84 - L * 0.7} Q{50 - w * 0.42},{84 - L * 0.5} {50 - w * 0.3},{84 - L * 0.3}", 0.6, 0.35)
        else:
            a.ground(45); rosette(a, s, 50, 43.5, 0.9, stage); root(a, s, 50, 45)
        return a
    if stage == "crop" and crop == "bulb":
        a.ground(66); k_, colr, w, L = s.get("root", ("round", "amber", 22, 22)); n_ = s.get("bulbs", 1)
        rosette(a, s, 50, 64 - L * 0.5, 0.86, stage, n=5)
        for j in range(n_):
            x = 50 + (j - (n_ - 1) / 2) * w * 0.8; ww = w if n_ == 1 else w * 0.7
            a.shape(f"M{f(x)},{f(66 - L * 0.78)} C{f(x + ww * 0.3)},{f(66 - L * 0.6)} {f(x + ww * 0.55)},{f(66 - L * 0.25)} {f(x + ww * 0.5)},{f(66 + L * 0.1)} C{f(x + ww * 0.45)},{f(66 + L * 0.42)} {f(x - ww * 0.45)},{f(66 + L * 0.42)} {f(x - ww * 0.5)},{f(66 + L * 0.1)} C{f(x - ww * 0.55)},{f(66 - L * 0.25)} {f(x - ww * 0.3)},{f(66 - L * 0.6)} {f(x)},{f(66 - L * 0.78)} Z", colr)
            for o in (-0.22, 0.22):
                a.line(f"M{f(x)},{f(66 - L * 0.7)} Q{f(x + ww * o * 1.8)},{f(66 - L * 0.1)} {f(x + ww * o * 0.6)},{f(66 + L * 0.32)}", 0.6, 0.35)
            a.roots(x, 66 + L * 0.34, 5, 7, 120)
        return a
    if stage == "crop" and crop == "tuber":
        a.ground(54); body(a, dict(s, H=s["H"] * 0.68), "young", 1, by=54)
        for dx, dy, rx_, ry_ in [(-17, 13, 8, 6), (-2, 22, 9.5, 7), (16, 14, 7.5, 5.6), (7, 32, 6, 4.6), (-13, 31, 5, 4)]:
            a.line(f"M50,56 Q{50 + dx * 0.4},{56 + dy * 0.3} {50 + dx},{54 + dy - ry_}", 0.8, 0.8, "soil")
            a.polar(50 + dx, 54 + dy, lambda th: 1 + 0.05 * math.cos(3 * th + dx), rx_, ry_, dx, "seed")
            a.dot(50 + dx - 2, 54 + dy - 1, 0.5, "bark"); a.dot(50 + dx + 2.4, 54 + dy + 1, 0.5, "bark")
        return a
    a.ground(88)
    if stage == "crop" and crop in ("leaf", "head", "stalk") and h == "ros":
        rosette(a, s, 50, 88, 1.12, stage, n=9)
        if crop == "head":
            a.polar(50, 66, lambda th: 1 + 0.035 * math.cos(9 * th), 19, 19.5, 0, s.get("headc", "unripe"))
            a.line("M40,54 Q52,60 52,82", 0.8, 0.5); a.line("M62,56 Q50,64 48,84", 0.8, 0.5); a.line("M43,66 Q50,61 58,67", 0.7, 0.4)
        return a
    if stage == "crop" and crop == "bud":
        if h == "ros" and not s.get("scape"):
            rosette(a, s, 50, 88, 1.1, stage, n=9)
            a.polar(50, 68, lambda th: 1 + 0.07 * math.cos(11 * th) + 0.04 * math.sin(17 * th), 17, 13, 0, s.get("budc", "white"))
            for k in range(14):
                rr = math.sqrt((k + 0.5) / 14); a.oval(50 + 13 * rr * math.cos(k * GOLD), 68 + 9.5 * rr * math.sin(k * GOLD), 2.2, 2.0, 0, None, 0.5, la=0.35)
        else:
            body(a, dict(s, fl=None), "young", 1)
            if h == "ros":   # the stalk the bud stands on
                a.ribbon((50, 87), (51, 88 - s["H"] * 0.5), (50, 88 - s["H"] + 6), 3.2, 2.6, s["lc"])
            for x, y, r in [(50, 88 - s["H"], 8)] + ([(50 - s["H"] * 0.22, 88 - s["H"] * 0.72, 5.5), (50 + s["H"] * 0.2, 88 - s["H"] * 0.66, 5.5)] if s.get("buds") else []):
                a.oval(x, y, r * 0.9, r, 0, s.get("budc", "unripe"))
                for k in range(5):
                    a.line(f"M{f(x - r * 0.7)},{f(y + r * 0.5 - k * r * 0.3)} Q{f(x)},{f(y + r * 0.9 - k * r * 0.34)} {f(x + r * 0.7)},{f(y + r * 0.5 - k * r * 0.3)}", 0.5, 0.4)
        return a
    if stage == "crop" and crop in ("leaf", "stalk"):
        body(a, s, "young", 1); return a
    if stage == "growing":
        body(a, s, "young", 1); return a
    body(a, s, stage, 1 if stage != "dormant" else 0.9)
    if s.get("cob") and stage == "crop":
        FR(a, "cob", 51, 58, 2.6, "pale", 1); FR(a, "cob", 49, 46, 2.3, "pale", -1)
    return a


# ================================================= settings for each kind
B = dict(
    root=dict(habit="ros", H=58, leaf="tooth", ls=30, lc="leaf", fl="four", fc="primrose", fr=3, arr="spray", crop="root",
              root=("round", "beet", 24, 24), sh="pods", seed="round", cot="round", bi=True),
    umbel=dict(habit="up", H=64, leaf="fern", ls=22, lc="leaf", fl="umbel", fc="white", fr=8, arr="heads", sh="umbel", seed="ridged", cot="narrow"),
    salad=dict(habit="ros", H=56, leaf="tooth", ls=28, lc="leaf", fl="four", fc="primrose", fr=3, arr="spray", crop="leaf", sh="pods", seed="round", cot="round"),
    allium=dict(habit="ros", H=62, leaf="strap", ls=42, lc="sage", fl="globe", fc="lilac", fr=10, arr="top", scape=True, crop="bulb",
                sh="burr", seed="black", cot="grass", bi=True),
    gourd=dict(habit="trail", H=24, leaf="lobed", ls=24, lc="leaf", fl="flat", fc="sun", cen="amber", fr=7, crop="fruit",
               fruit=("round", "carrot", 9), seed="flat", cot="oval"),
    pea=dict(habit="climb", H=76, leaf="compound", ls=19, lc="leaf", fl="pea", fc="white", fr=3.4, arr="axil", crop="pod",
             fruit=("pod", "unripe", 2.3), sh="legume", seed="pea", cot="bean"),
    night=dict(habit="up", H=64, leaf="simple", ls=20, lc="leaf", fl="star", fc="white", cen="sun", fr=3.6, arr="axil", crop="fruit",
               fruit=("round", "berry", 4.4), seed="disc", cot="narrow"),
    daisy=dict(habit="clump", H=56, leaf="lance", ls=15, lc="leaf", fl="daisy", fc="white", cen="sun", fr=8, arr="top", sh="head", seed="slim", cot="round"),
    spire=dict(habit="clump", H=64, leaf="tooth", ls=17, lc="leaf", fl="lip", fc="lilac", fr=3, arr="spire", sh="dry", seed="round", cot="round", per=True),
    herb=dict(habit="clump", H=44, leaf="simple", ls=13, lc="leaf", fl="tiny", fc="white", fr=3, arr="top", crop="leaf", sh="dry", seed="round", cot="round"),
    mound=dict(habit="mound", H=40, leaf="needle", ls=9, lc="sage", fl="lip", fc="lilac", fr=3.6, arr="spire", crop="leaf", start="plant", ever=True),
    wild=dict(habit="clump", H=48, leaf="simple", ls=13, lc="leaf", fl="flat", fc="pink", fr=5, arr="heads", sh="dry", seed="round", cot="round", per=True),
    mat=dict(habit="mat", H=15, leaf="simple", ls=4, lc="leaf", fl="tiny", fc="lilac", fr=2.6, sh="dry", seed="dust", cot="round", per=True),
    bulb=dict(habit="bulb", H=46, lc="sage", fl="cup", fc="berry", fr=8),
    tree=dict(habit="tree", lc="leaf", leaf="simple", fc="white", fruit=("round", "berry", 4.0), canopy="round"),
    bush=dict(habit="bush", H=54, leaf="simple", ls=11, lc="leaf", sc="bark", fl="tiny", fc="white", fr=2.6, arr="axil", crop="fruit",
              fruit=("round", "berry", 2.4), start="plant"),
    cane=dict(habit="cane", H=72, leaf="compound", ls=17, lc="leaf", sc="bark", fl="flat", fc="white", fr=3, arr="axil", crop="fruit",
              fruit=("knob", "berry", 3.0), start="plant"),
)
KINDS = []


def K(name, base, also=(), **kw):
    d = dict(B[base]); d.update(kw)
    if d["habit"] not in ("tree", "bulb", "cyclamen", "vine", "asparagus"):   # fill the tile
        d["H"] = min(80, d["H"] * (1.5 if d["habit"] == "mat" else 1.24)); d["ls"] = d["ls"] * 1.18; d["fr"] = d.get("fr", 4) * 1.15
    KINDS.append((re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-"), name, d, [name] + list(also)))


# ---- roots
K("Parsnip", "root", ["Parsnips"], leaf="compound", root=("long", "white", 20, 49), fl="umbel", fc="primrose", fr=8, arr="heads", sh="umbel", seed="disc", cot="narrow", H=66)
K("Beetroot", "root", leaf="simple", stalkc="beet", seed="knob", fl="tiny", fc="unripe", arr="spire", sh="dry")
K("Radish", "root", leaf="cut", ls=24, root=("round", "berry", 15, 15), fl="four", fc="pink", bi=False)
K("Turnip", "root", leaf="cut", root=("round", "white", 25, 21), top="plum")
K("Swede", "root", leaf="cut", lc="sage", root=("round", "pear", 29, 26), top="plum")
K("Celeriac", "root", leaf="compound", root=("round", "seed", 28, 24), fl="umbel", fc="white", fr=7, arr="heads", sh="umbel", seed="ridged", cot="narrow")
K("Mangelwurzel", "root", leaf="simple", stalkc="pale", root=("round", "rust", 26, 34), seed="knob", fl="tiny", fc="unripe", arr="spire", sh="dry")
K("Salsify", "root", leaf="strap", lc="sage", root=("long", "seed", 9, 50), fl="daisy", fc="lilac", fr=7, arr="top", sh="fluff", seed="slim", cot="grass")
K("Scorzonera", "root", leaf="strap", root=("long", "dark", 9, 50), fl="daisy", fc="sun", fr=7, arr="top", sh="fluff", seed="slim", cot="grass")
K("Kohlrabi", "root", leaf="simple", lc="sage", root=("round", "unripe", 24, 22), above=True, croplab="Ready to cut")
K("Potatoes", "night", ["Potato"], leaf="compound", ls=24, H=50, start="tuber", crop="tuber", cen="sun", fc="white", fr=3.4, arr="top", habit="clump")
# ---- the carrot family and other herbs
K("Dill", "umbel", fc="primrose", ls=20, crop="leaf")
K("Fennel", "umbel", fc="primrose", H=72, ls=24, crop="leaf", per=True)
K("Coriander", "umbel", H=52, leaf="cut", ls=13, crop="leaf")
K("Parsley", "umbel", habit="ros", leaf="cut", ls=24, H=52, fc="pear", crop="leaf", bi=True, stalkc="leaf")
K("Chervil", "umbel", H=46, ls=17, crop="leaf")
K("Anise", "umbel", H=50, ls=16, leaf="cut")
K("Lovage", "umbel", H=74, leaf="compound", fc="pear", crop="leaf", per=True)
K("Celery", "umbel", habit="ros", leaf="compound", ls=34, stalkc="pale", H=58, crop="stalk", croplab="Ready to cut", bi=True)
K("Wild angelica", "umbel", H=74, leaf="compound", fc="pink", fr=10, per=True, sc="plum")
K("Hogweed", "umbel", ["Heradeum"], H=74, leaf="lobed", ls=28, fr=11, per=True)
K("Yarrow", "umbel", ["Achillea"], fc="pink", habit="clump", H=50, ls=17, fr=6, arr="top", per=True)
K("Common Valerian", "umbel", H=72, leaf="compound", fc="pink", fr=6, per=True)
K("Meadowsweet", "wild", H=64, leaf="compound", ls=20, fl="plume", fc="white", fr=7, arr="top")
K("Basil", "herb", leaf="simple", ls=15, lc="leaf", fl="lip", arr="spire", opp=True, H=42)
K("Mint", "herb", ["Applemint"], leaf="tooth", ls=14, fl="tiny", fc="lilac", arr="spire", opp=True, H=46, per=True, start="plant")
K("Lemon Balm", "herb", leaf="tooth", ls=15, arr="axil", fr=2.2, opp=True, per=True)
K("Oregano", "herb", ["Marjoram", "Wild marjoram"], leaf="round", ls=9, fl="tiny", fc="pink", arr="heads", opp=True, H=40, per=True)
K("Tarragon", "herb", leaf="lance", ls=13, fl=None, sh=None, per=True, start="plant", H=48)
K("Cat nip", "spire", fc="white", leaf="tooth", lc="sage", ls=13, H=46, opp=True)
K("Hyssop", "mound", fc="pink", lc="leaf", H=42)
K("Lavender", "mound", ["Lavandula allardii Meerlo"], H=46)
K("Rosemary", "mound", lc="deep", fc="blue", arr="axil", H=48)
K("Sage", "mound", leaf="simple", ls=13, H=40)
K("Savory", "mound", lc="leaf", fc="white", H=32)
K("Wormwood", "mound", leaf="fern", ls=15, fl="tiny", fc="primrose", H=48, crop=None)
K("Thyme", "mat", ["Wild thyme"], crop="leaf", start="plant")
K("Bay", "tree", ever=True, lc="deep", fruit=None, fc="primrose", canopy="tall")
# ---- leaves and brassicas
K("Leaf salad", "salad", leaf="cut", fl="daisy", fr=4.4)
K("Spinach", "salad", leaf="heart", lc="deep", fl="tiny", fc="unripe", arr="spire", sh="dry", seed="knob")
K("Swiss Chard", "salad", leaf="simple", lc="deep", stalkc="berry", fl="tiny", fc="unripe", arr="spire", sh="dry", seed="knob", ls=32, bi=True)
K("Spinach Beet", "salad", leaf="simple", lc="deep", stalkc="pale", fl="tiny", fc="unripe", arr="spire", sh="dry", seed="knob", ls=32, bi=True)
K("Rocket salad", "salad", leaf="cut", ls=24, fc="white")
K("Mizuna", "salad", leaf="fern", ls=28)
K("Mustard", "salad", leaf="cut", ls=26, H=62)
K("Pak Choi", "salad", leaf="round", ls=30, stalkc="white", lc="deep")
K("Lambs Lettuce", "salad", leaf="simple", ls=17, lc="deep", fc="white", fl="tiny", H=30, sh="dry")
K("Cress", "salad", leaf="trefoil", ls=13, H=30, fc="white")
K("Chicory", "salad", leaf="cut", fl="daisy", fc="blue", fr=6, arr="axil", sh="head", seed="slim", H=68, per=True)
K("Celtuce", "salad", leaf="simple", fl="daisy", fc="primrose", fr=3.4, sh="fluff", seed="slim", croplab="Ready to cut")
K("Sorrel", "salad", leaf="lance", ls=27, fl="tiny", fc="rust", arr="spire", sh="dry", per=True)
K("Good King Henry", "salad", leaf="heart", ls=22, fl="tiny", fc="unripe", arr="spire", sh="dry", per=True)
K("Purple Orach", "salad", habit="up", leaf="heart", ls=17, lc="plum", sc="plum", fl="tiny", fc="beet", arr="spire", sh="dry", H=72)
K("Cabbage", "salad", leaf="round", ls=30, lc="sage", crop="head", headc="unripe", bi=True)
K("Cauliflower", "salad", leaf="simple", ls=32, lc="sage", crop="bud", budc="white", bi=True)
K("Broccoli", "salad", leaf="cut", ls=30, lc="sage", crop="bud", budc="deep")
K("Broccoli (sprouting)", "salad", habit="up", H=62, leaf="cut", ls=22, lc="sage", crop="bud", budc="plum", buds=True, bi=True)
K("Brussels sprouts", "salad", habit="up", H=66, leaf="round", ls=19, lc="sage", crop="fruit", fruit=("round", "unripe", 2.5), arr="axil", croplab="Ready to pick", bi=True, veg=True)
# ---- alliums
K("Onion", "allium", root=("round", "amber", 24, 24), fc="white", start="set", ls=38)
K("Shallot", "allium", root=("round", "rust", 15, 19), bulbs=3, fc="white", start="set", ls=32, fl=None, sh=None)
K("Garlic", "allium", root=("round", "white", 22, 21), start="clove", fc="pink", fr=6, ls=36, leaf="strap")
K("Spring onion", "allium", root=("round", "white", 8, 15), ls=34, fc="white", croplab="Ready to pull")
K("Chives", "allium", ls=30, H=38, fr=5.5, scapes=3, crop="leaf", per=True, bi=False, croplab="Ready to cut")
K("Wild garlic", "allium", leaf="simple", ls=30, lc="leaf", fl="umbel", fc="white", fr=7, H=40, crop="leaf", per=True, bi=False, start="set", sh="dry")
K("Bristol Onion", "allium", fc="beet", fr=7, H=62, ls=30, crop=None, per=True, bi=False, start="set")
# ---- gourds
K("Squash", "gourd", ["Winter squash"])
K("Cucumber", "gourd", fruit=("long", "marrow", 6))
K("Melon", "gourd", fruit=("round", "pear", 9.5))
K("Loofah", "gourd", fruit=("long", "unripe", 7.5))
# ---- peas and beans
K("Pea", "pea", ["Mangetout", "Sugarsnap peas"])
K("French bean", "pea", ["Dwarf/french bean", "French Beans", "French beans"], habit="up", H=44, leaf="trefoil", ls=24, fc="lilac", fruit=("pod", "unripe", 1.8), seed="bean")
K("Sweet pea", "pea", fc="pink", cen="lilac", fr=4.2, crop=None, sh="legume")
K("Tufted vetch", "pea", leaf="fern", ls=17, fc="plum", fr=2.6, arr="spire", crop=None, sh="legume", per=True, H=66)
K("Meadow vetchling", "pea", leaf="lance", ls=13, opp=True, fc="sun", crop=None, sh="legume", per=True, H=60)
K("Alfalfa", "wild", leaf="trefoil", ls=13, fl="tiny", fc="lilac", arr="spire", H=54, cot="bean")
K("Clover", "wild", leaf="trefoil", ls=14, fl="tuft", fc="white", fr=4.4, arr="top", H=28)
K("Red clover", "wild", leaf="trefoil", ls=14, fl="tuft", fc="pink", fr=5, arr="top", H=36)
K("Common bird's-foot-trefoil", "mat", leaf="simple", fl="pea", fc="sun", fr=2.6, H=14)
K("Lupin", "spire", ["Lupinus 'Gallery Blue'"], leaf="palm", ls=20, fl="pea", fc="blue", cen="white", fr=2.8, sh="legume", H=62, seed="pea", cot="bean")
# ---- nightshades
K("Aubergine", "night", ls=22, fl="star", fc="lilac", fruit=("egg", "plum", 4.6), H=56)
K("Chilli pepper", "night", fruit=("long", "berry", 2.6), H=52, ls=17)
K("Tomatillo", "night", leaf="tooth", fc="primrose", fruit=("lantern", "unripe", 3.2), H=60)
K("Chinese lanterns", "night", leaf="simple", fruit=("lantern", "carrot", 3.4), per=True, croplab="Lanterns", H=54)
# ---- other vegetables
K("Sweetcorn", "night", leaf="strap", ls=34, lc="leaf", fl="plume", fc="straw", fr=7, arr="top", crop="fruit", cob=True, fruit=("round", "sun", 0.1), seed="corn", cot="grass", H=76, croplab="Cobs ready")
K("Globe artichoke", "salad", ["Artichoke"], leaf="cut", ls=36, lc="sage", H=64, fl="tuft", fc="lilac", fr=8, arr="top", crop="bud", scape=True, sh="fluff", seed="stripe", per=True, cot="oval")
K("Asparagus", "herb", habit="asparagus")
K("Rhubarb", "salad", leaf="heart", ls=40, stalkc="berry", lc="deep", fl="plume", fc="white", fr=9, arr="top", scape=True, crop="stalk", start="crown", per=True, sh=None, H=54)
K("Nasturtium", "gourd", leaf="round", ls=17, fl="flat", fc="carrot", cen="berry", fr=6, crop=None, H=20, seed="pea")
# ---- daisies
K("Calendula", "daisy", fc="carrot", cen="rust", ls=16, H=42, leaf="simple", seed="ridged")
K("Cosmos", "daisy", fc="pink", leaf="fern", ls=17, H=66, arr="heads", fl="flat", fr=7)
K("Zinnia", "daisy", fc="berry", leaf="simple", opp=True, H=52)
K("Rudbeckia", "daisy", fc="sun", cen="dark", H=58, per=True)
K("French Marigold", "daisy", fc="carrot", cen="rust", leaf="fern", ls=14, H=30, fr=6)
K("Ox-eye Daisy", "daisy", ["Oxeye Daisy"], leaf="cut", H=54, per=True)
K("Corn chamomile", "daisy", leaf="fern", ls=13, H=40, fr=6, arr="heads")
K("Wild chamomile", "daisy", leaf="fern", ls=13, H=38, fr=5, arr="heads", fl="tiny", fc="pear")
K("Feverfew", "daisy", leaf="cut", ls=14, H=46, fr=4.4, arr="spray", per=True)
K("Aster", "daisy", fc="lilac", H=56, fr=6, arr="heads", per=True)
K("African Daisy", "daisy", fc="pink", cen="plum", leaf="simple", H=34, fr=8)
K("Helipterum Rosum", "daisy", fc="pink", lc="sage", H=40, fr=6.5)
K("Cornflower", "daisy", ["Field cornflower"], lc="sage", fl="tuft", fc="blue", fr=6, H=60, arr="heads", sh="dry")
K("Blue globe thistle", "daisy", leaf="cut", ls=22, lc="sage", fl="globe", fc="blue", fr=7, H=66, arr="heads", sh="burr", per=True)
K("Scabiosa", "daisy", leaf="cut", fl="globe", fc="pink", fr=6, H=58, arr="heads", sh="burr", per=True)
K("Devil's-bit scabious", "daisy", leaf="lance", fl="globe", fc="blue", fr=5, H=60, arr="heads", sh="burr", per=True)
K("Oxford rampion", "daisy", leaf="lance", fl="tuft", fc="blue", fr=5, H=44, sh="dry", per=True)
K("Senecio 'Angel Wings'", "salad", ["Senecio canc Angel Wings"], leaf="tooth", ls=30, lc="white", fl=None, sh=None, crop="leaf", croplab="Full size", start="plant", per=True)
# ---- spires
K("Foxglove", "spire", ["Wild foxglove", "Digitalis Dalmatian Peach"], habit="ros", leaf="tooth", ls=26, fl="bell", fc="pink", fr=3.6, H=74, bi=True, per=False, seed="dust", sh="capsule")
K("Salvia", "spire", ["Salvia Amisiad"], fc="plum", opp=True, H=62)
K("Common evening-primrose", "spire", habit="ros", leaf="lance", ls=24, fl="four", fc="primrose", fr=5, H=74, bi=True, per=False, seed="dust", sh="pods")
K("Wallflower", "spire", leaf="lance", ls=15, fl="four", fc="carrot", fr=3.6, H=46, sh="pods", per=False, bi=True)
K("Yellow-rattle", "spire", habit="up", leaf="tooth", ls=11, opp=True, fc="primrose", H=42, per=False, sh="capsule", seed="flat")
K("Selfheal", "mat", leaf="simple", fl="tuft", fc="plum", fr=3, H=16)
K("Sweet William", "wild", leaf="lance", opp=True, fl="tiny", fc="beet", fr=6, arr="top", H=46, per=False, bi=True)
# ---- other flowers
K("Poppy", "wild", leaf="cut", ls=17, lc="sage", fl="cup", fc="berry", fr=6, arr="heads", sh="capsule", seed="dust", H=60, per=False)
K("California Poppy", "wild", leaf="fern", ls=15, lc="sage", fl="cup", fc="carrot", fr=5, arr="top", sh="pods", seed="dust", H=34, per=False)
K("Borage", "wild", leaf="simple", ls=18, fl="star", fc="blue", cen="dark", fr=4, arr="spray", H=56, per=False, seed="black")
K("Russian comfrey", "wild", leaf="lance", ls=26, fl="bell", fc="plum", fr=2.4, arr="spray", H=62, start="plant", sh=None, crop="leaf", croplab="Ready to cut")
K("Lungwort", "wild", habit="ros", leaf="simple", ls=20, lc="deep", fl="bell", fc="pink", fr=2.2, arr="spray", H=30, start="plant", sh=None)
K("Native Cowslip", "wild", ["Cowslip"], habit="ros", leaf="tooth", ls=20, fl="bell", fc="sun", fr=2.2, arr="spray", scape=True, H=36)
K("Geum", "wild", leaf="tooth", ls=16, fc="berry", fr=4.6, H=46)
K("Viola", "mat", leaf="simple", ls=5, fl="flat", fc="plum", cen="sun", fr=4, H=17)
K("Aubrieta", "mat", fl="four", fc="lilac", fr=3, H=14, start="plant")
K("Linum", "wild", leaf="lance", ls=10, fc="blue", fr=4.4, H=50, per=False)
K("Marshmallow", "wild", leaf="lobed", ls=20, lc="sage", fc="pink", fr=4.4, arr="axil", H=72)
K("Perforate st John's-wort", "wild", leaf="simple", ls=8, opp=True, fl="star", fc="sun", fr=3.6, arr="spray", H=54)
K("Lady's bedstraw", "wild", leaf="needle", ls=8, fl="plume", fc="sun", fr=5, arr="heads", H=46)
K("Rock Sea Lavender", "wild", habit="ros", leaf="simple", ls=17, fl="tiny", fc="lilac", fr=3, arr="spray", scape=True, H=36)
K("Candy Cane Sorrel", "wild", leaf="trefoil", ls=12, fl="cup", fc="white", fr=3.4, arr="top", H=26, start="set", sh=None)
# ---- bulbs, corms and tubers
K("Daffodil", "bulb", fl="trumpet", fc="primrose", cen="sun", fr=10)
K("Tulip", "bulb", ["Late Tulip"], bleaf="broad", nl=3, fr=8.5)
K("Crocus", "bulb", fl="goblet", fc="lilac", H=22, fr=7)
K("Bluebell", "bulb", fl="bells", fc="blue", fr=2.6, bend=7)
K("Grape Hyacinth", "bulb", fl="spike", fc="blue", fr=2.4, H=34)
K("Puschkinia", "bulb", fl="spike", fc="white", fr=2.6, H=30, nl=2)
K("Snake's head fritillary", "bulb", ["Fritillaria, snake's head fritillary"], fl="nod", fc="plum", fr=6.5, H=42, nl=3)
K("Crown imperial", "bulb", ["Fritillaria, crown imperial 'William Rex'"], fl="crown", fc="carrot", fr=4, H=58, bleaf="broad")
K("Iris", "bulb", fl="iris", fc="plum", fr=8, H=52)
K("Yellow Iris", "bulb", fl="iris", fc="sun", fr=8, H=58)
K("Peacock Orchid", "bulb", fl="stars", fc="white", fr=5.4, H=58, bend=8)
K("Winter windflower", "bulb", ["winter windflower"], fl="daisy", fc="pink", fr=7, H=24, nl=2)
K("Cyclamen", "bulb", ["Cyclamen hederifolium Pink", "Cyclamen hederifolium White"], habit="cyclamen", fc="pink")
# ---- tree fruit and other trees
K("Pear", "tree", ["Perry Pear"], fruit=("pear", "pear", 4.6), canopy="tall")
K("Plum", "tree", fruit=("round", "plum", 3.6))
K("Nectarine", "tree", leaf="lance", fc="pink", fruit=("round", "carrot", 4.0), fruit2="berry", canopy="wide")
K("Fig", "tree", leaf="lobed", lc="deep", fruit=("pear", "plum", 4.4), canopy="wide", fc="unripe")
K("Olive Tree", "tree", leaf="lance", lc="sage", ever=True, fruit=("round", "dark", 2.2), fruit2="unripe")
K("Bristol Whitebeam", "tree", lc="sage", fruit=("round", "berry", 2.0))
K("Gingko", "tree", leaf="fan", canopy="tall", fruit=None, autumn=True, noflower=True)
# ---- bush, cane and vine fruit, and shrubs
K("Blackcurrant", "bush", leaf="lobed", ls=17, fruit=("string", "dark", 1.9))
K("Whitecurrant", "bush", leaf="lobed", ls=17, fruit=("string", "white", 1.9))
K("Gooseberry", "bush", leaf="lobed", ls=14, fruit=("round", "unripe", 2.9))
K("Blueberry", "bush", ["Wild blueberry"], fl="bell", fr=1.8, fruit=("round", "blue", 2.3))
K("Honeyberry", "bush", fl="bell", fc="primrose", fr=1.8, fruit=("egg", "blue", 1.7))
K("Rose", "bush", leaf="compound", ls=17, fl="flat", fc="pink", fr=5.4, fruit=("round", "berry", 2.6), croplab="Hips")
K("Hydrangea", "bush", leaf="tooth", ls=17, fl="globe", fc="pink", fr=7, arr="top", crop=None)
K("Japanese Spiraea", "bush", leaf="tooth", ls=11, fl="tiny", fc="pink", fr=4.4, arr="top", crop=None)
K("Raspberry", "cane")
K("Blackberry", "cane", fruit=("knob", "dark", 3.2), fc="pink")
K("Loganberry", "cane", ["Tayberry", "Tummelberry"], fruit=("knob", "beet", 3.4))
K("Japanese Wineberry", "cane", fruit=("knob", "carrot", 2.8), sc="rust")
K("Grape", "bush", habit="vine", leaf="lobed", ls=17, fc="unripe", fruit=("bunch", "plum", 2.1))
K("Kiwi", "bush", habit="vine", leaf="heart", ls=17, fc="white", fruit=("egg", "bark", 2.6))

SKIPPED = ["Herb mix", "Overwinter mix", "Overwinter Mix", "Wildflower1", "Wildflower2", "Unknown Eden"]
SAMPLE_ALSO = {"carrot": ["Carrots", "Flowering carrot"], "leek": ["Leeks"], "apple": ["Apple (Cider)", "Apple (Culinary)"]}


def all_plants():
    """Every kind as (slug, name, [(stage, label, drawing function)], names in the library)."""
    out = [(slug, name, st, [name] + SAMPLE_ALSO.get(slug, [])) for slug, name, st in S10.PLANTS]
    for slug, name, s, names in KINDS:
        out.append((slug, name, [(st, label(s, st), (lambda s=s, st=st: make(s, st))) for st in stages(s)], names))
    return sorted(out, key=lambda p: p[1].lower())


def sheet(plants, mode, cell=120, cols=7):
    bg, card, ink, soft = [("#F8F1E5", "#FFFCF6", "#15271D", "#3A5549"), ("#0C1C14", "#142414", "#F1EADB", "#A7B5A5")][mode]
    pad, lab, head = 12, 22, 26
    W = pad + cols * (cell + pad); rowh = head + cell + lab + 6; H = pad + len(plants) * rowh + pad
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">', f'<rect width="{W}" height="{H}" fill="{bg}"/>']
    for r, (slug, name, sts, _) in enumerate(plants):
        y0 = pad + r * rowh
        out.append(f'<text x="{pad}" y="{y0 + 18}" font-family="Georgia, serif" font-size="17" fill="{ink}">{name.replace("&", "and")}</text>')
        for c, (st, lb, fn) in enumerate(sts):
            x = pad + c * (cell + pad); y = y0 + head
            out.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="12" fill="{card}"/>')
            out.append(f'<g transform="translate({x},{y}) scale({cell / 100})" stroke-linecap="round" stroke-linejoin="round">{fn().body(mode)}</g>')
            out.append(f'<text x="{x + cell / 2}" y="{y + cell + 15}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="11" fill="{soft}">{lb}</text>')
    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "out_all"
    plants = all_plants(); n = 0
    for mode, look in enumerate(("light", "dark")):
        os.makedirs(os.path.join(out, look), exist_ok=True)
        for slug, name, sts, _ in plants:
            for st, lb, fn in sts:
                with open(os.path.join(out, look, f"plant-{slug}-{st}.svg"), "w", encoding="utf-8") as fh:
                    fh.write(fn().svg(mode)); n += 1
        per = 24
        for i in range(0, len(plants), per):
            with open(os.path.join(out, f"sheet-{look}-{i // per + 1:02d}.svg"), "w", encoding="utf-8") as fh:
                fh.write(sheet(plants[i:i + per], mode))
    index = {"kinds": [{"slug": slug, "name": name, "stages": [{"stage": st, "label": lb} for st, lb, _ in sts], "libraryNames": names}
                       for slug, name, sts, names in plants], "notDrawn": SKIPPED}
    with open(os.path.join(out, "plant-drawings.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, indent=1, ensure_ascii=False)
    print(len(plants), "kinds,", n // 2, "drawings, each in light and dark, written to", out)
