"""Windfall wildlife drawings: a bird in flight.

Many birds are seen far more often overhead than perched: a swift never
perches at all, and a buzzard or a red kite is usually a shape circling in
the sky. `soar` draws a bird from below with its wings spread, head towards
the top of the picture. As with `bird` in wildlife_species2.py, every
number names one part of the SHAPE and every colour word one part of the
plumage, so a correction is a change of one number or one word.

Checked against photographs on 15 November 2026 (Design/Wildlife/CHECKED.md).
"""
import math
from shapely.geometry import Polygon, Point
from shapely.ops import unary_union
from wildlife_kit import Art, LW, turn, curve, ell, blob, poly, limb, mirror, paint, figure, stroke, eye


def soar(span=44, chord=13, shape="broad", sweep=4, arch=3, fingers=4, body=(5.2, 30), head=(4.0, 4.2), tail=(15, 13, "fan"), cy=46,
         col="brown", under=None, tips=None, carpal=None, window=None, edge=None, bars=None, lead=None,
         tail_col=None, tail_tip=None, tail_bars=0, belly=None, breast=None, body_bars=None, head_col=None, throat=None,
         bill=(3.0, 2.4, "yellow"), legs=None, rump=None, feather_lines=True):
    """A bird overhead, seen from below.

    Shape
      span, chord   how long each wing is, and how wide where it joins the body
      shape         "broad" for a wing that ends in spread "fingers" (buzzard, kite, crow),
                    "point" for one that ends in a point (falcon, gull, swallow, pigeon),
                    "scythe" for the long curved blade of a swift
      sweep         how far the wing tip is held back behind the shoulder.  arch  how far the wrist pushes forward
      fingers       how many separate feathers show at the tip of a broad wing
      body          (half-width, length).  head  (half-width, half-length)
      tail          (length, width, kind). Kinds: fan, square, fork, wedge, streamers
      bill          (length, width, colour).  legs  (length, colour) for legs that trail behind (a heron)
    Colour
      col           the flight feathers, and everything not given a colour of its own
      under         the front half of the underwing, nearest the body
      tips          the wing tips.  carpal  a dark patch at the wrist.  window  a pale patch near the tip
      edge          a dark band along the back edge of the wing.  lead  a pale front edge
      bars          a colour for fine bars across the flight feathers
      belly, breast, body_bars, throat, head_col   the body and head
      tail_col, tail_tip, tail_bars  the tail, a band at its end, and how many bars cross it"""
    a = Art()
    cx = 50
    bw, bl = body
    sy = cy - bl * 0.2                                                   # the shoulder
    root = cx + bw * 0.5

    def wing_shape():
        P0 = (root, sy - chord * 0.46); P6 = (root, sy + chord * 0.52)
        if shape == "broad":
            P1 = (cx + span * 0.46, sy - chord * 0.5 - arch)
            P2 = (cx + span * 0.93, sy - chord * 0.22 + sweep)
            P3 = (cx + span, sy + chord * 0.18 + sweep)
            P4 = (cx + span * 0.88, sy + chord * 0.6 + sweep * 0.9)
            P5 = (cx + span * 0.5, sy + chord * 0.64 + sweep * 0.35)
            g = Polygon(curve([P0, P1, P2], 8)[:-1] + curve([P2, P3, P4], 8)[:-1] + curve([P4, P5, P6], 8)).buffer(0)
            arc = curve([P2, P3, P4], 12)
            inner = (cx + span * 0.55, sy + chord * 0.1 + sweep * 0.5)
            for k in range(1, fingers):                                  # the gaps between the "fingers"
                q = arc[int(len(arc) * k / fingers)]
                d = math.hypot(inner[0] - q[0], inner[1] - q[1]) or 1
                ux, uy = (inner[0] - q[0]) / d, (inner[1] - q[1]) / d
                depth = span * 0.15
                g = g.difference(Polygon([(q[0] - uy * 0.6 - ux * 2, q[1] + ux * 0.6 - uy * 2), (q[0] + uy * 0.6 - ux * 2, q[1] - ux * 0.6 - uy * 2),
                                          (q[0] + ux * depth, q[1] + uy * depth)]))
            return g
        if shape == "scythe":
            lead_pts = [P0, (cx + span * 0.4, sy - chord * 0.55 - arch), (cx + span * 0.8, sy - chord * 0.2 + sweep * 0.45), (cx + span, sy + sweep)]
            trail_pts = [(cx + span, sy + sweep), (cx + span * 0.74, sy + chord * 0.1 + sweep * 0.42), (cx + span * 0.4, sy + chord * 0.3), P6]
            return Polygon(curve(lead_pts, 10)[:-1] + curve(trail_pts, 10)).buffer(0)
        lead_pts = [P0, (cx + span * 0.42, sy - chord * 0.5 - arch), (cx + span * 0.78, sy - chord * 0.24 + sweep * 0.6), (cx + span, sy + sweep)]
        trail_pts = [(cx + span, sy + sweep), (cx + span * 0.66, sy + chord * 0.42 + sweep * 0.6), (cx + span * 0.34, sy + chord * 0.62 + sweep * 0.2), P6]
        return Polygon(curve(lead_pts, 10)[:-1] + curve(trail_pts, 10)).buffer(0)

    wr = wing_shape(); wl = mirror(wr)
    tl, tw, tk = tail
    ty = cy + bl * 0.42

    def T(u, v): return (cx + u * tw, ty + v * tl)
    if tk == "fork":
        tail_g = poly(T(-0.2, 0), T(-0.5, 1), T(0, 0.58), T(0.5, 1), T(0.2, 0))
    elif tk == "streamers":
        tail_g = poly(T(-0.22, 0), T(-0.34, 0.45), T(-0.5, 1), T(-0.2, 0.5), T(0, 0.36), T(0.2, 0.5), T(0.5, 1), T(0.34, 0.45), T(0.22, 0))
    elif tk == "wedge":
        tail_g = Polygon(curve([T(-0.24, 0), T(-0.46, 0.62), T(0, 1), T(0.46, 0.62), T(0.24, 0)], 8)).buffer(0)
    elif tk == "square":
        tail_g = poly(T(-0.24, 0), T(-0.4, 1), T(0.4, 1), T(0.24, 0))
    else:                                                                # a fan
        tail_g = Polygon([T(-0.2, 0)] + curve([T(-0.5, 0.78), T(-0.26, 0.97), T(0, 1.02), T(0.26, 0.97), T(0.5, 0.78)], 6) + [T(0.2, 0)]).buffer(0)
    if legs:                                                             # legs trailing out behind the tail
        for s in (1, -1):
            stroke(a, [(cx + s * 1.4, ty), (cx + s * 1.2, ty + legs[0])], 1.3, col=legs[1], smooth=False)
            stroke(a, [(cx + s * 1.2, ty + legs[0]), (cx + s * 2.6, ty + legs[0] + 3.4)], 1.1, col=legs[1], smooth=False)
    body_g = blob([(cx, cy - bl * 0.5), (cx + bw, cy - bl * 0.22), (cx + bw * 0.92, cy + bl * 0.16), (cx + bw * 0.4, cy + bl * 0.5),
                   (cx - bw * 0.4, cy + bl * 0.5), (cx - bw * 0.92, cy + bl * 0.16), (cx - bw, cy - bl * 0.22)], 8)
    hw, hh = head
    hy = cy - bl * 0.5 - hh * 0.45
    head_g = ell(cx, hy, hw, hh)
    blen, bwid, bcol = bill
    paint(a, poly((cx - bwid / 2, hy - hh * 0.72), (cx + bwid / 2, hy - hh * 0.72), (cx, hy - hh * 0.72 - blen)), bcol, 0.8)
    patches = []
    for w, s in ((wr, 1), (wl, -1)):
        def X(u): return cx + s * u
        if under:
            patches.append((poly((X(bw * 0.5), sy - chord), (X(span * 0.5), sy - chord - arch - 2), (X(span * 0.8), sy - chord * 0.3 + sweep * 0.7),
                                 (X(span * 0.62), sy + chord * 0.1 + sweep * 0.45), (X(bw * 0.5), sy + chord * 0.12)).intersection(w), under))
        if edge:
            from shapely.affinity import translate
            patches.append((w.difference(translate(w, 0, -chord * 0.16)).intersection(poly((X(bw), sy), (X(span * 1.1), sy - 4), (X(span * 1.1), sy + chord * 2), (X(bw), sy + chord * 2))), edge))
        if window:
            patches.append((ell(X(span * 0.74), sy + chord * 0.16 + sweep * 0.7, span * 0.13, chord * 0.3, s * 18).intersection(w), window))
        if tips:
            patches.append((poly((X(span * 0.8), sy - chord * 2), (X(span * 1.2), sy - chord * 2), (X(span * 1.2), sy + chord * 3), (X(span * 0.86), sy + chord * 3)).intersection(w), tips))
        if carpal:
            patches.append((ell(X(span * 0.52), sy - chord * 0.16 - arch * 0.4 + sweep * 0.25, span * 0.07, chord * 0.12, s * 20).intersection(w), carpal))
        if lead:
            patches.append((w.difference(w.buffer(-1.3)).intersection(poly((X(0), sy - chord * 2), (X(span * 0.85), sy - chord * 2), (X(span * 0.85), sy - chord * 0.1 + sweep * 0.3), (X(0), sy - chord * 0.3))), lead))
    patches.append((tail_g.buffer(0.3), tail_col or col))
    for k in range(tail_bars):
        v = 0.3 + k * (0.5 / max(tail_bars, 1))
        patches.append((poly(T(-1, v), T(1, v), T(1, v + 0.07), T(-1, v + 0.07)).intersection(tail_g), "ink"))
    if tail_tip:
        patches.append((poly(T(-1, 0.8), T(1, 0.8), T(1, 1.2), T(-1, 1.2)).intersection(tail_g.buffer(0.3)), tail_tip))
    if rump:
        patches.append((ell(cx, ty + 1, bw * 0.9, 3.4), rump))
    patches.append((body_g.buffer(0.3), belly or under or col))
    if breast:
        patches.append((ell(cx, cy - bl * 0.26, bw * 1.2, bl * 0.24).intersection(body_g.buffer(0.3)), breast))
    patches.append((head_g.buffer(0.4), head_col or belly or under or col))
    if throat:
        patches.append((ell(cx, hy + hh * 0.75, hw * 0.9, hh * 0.6), throat))
    sil = figure(a, [wr, wl, tail_g, body_g, head_g], col, patches, close=0.25)
    for s in (1, -1):
        def X(u): return cx + s * u
        if feather_lines:
            n = 7
            for k in range(n):                                           # the flight feathers, fanning from the wrist to the back edge
                u = 0.14 + k * (0.72 / (n - 1))
                p0 = (X(span * u * 0.92), sy + chord * 0.04 + sweep * u * 0.5)
                p1 = (X(span * (u + 0.05)), sy + chord * (0.56 - u * 0.2) + sweep * u * 0.9)
                if sil.buffer(-0.4).contains(Point(p1)) and sil.contains(Point(p0)):
                    stroke(a, [p0, p1], 0.4, 0.4, smooth=False)
        if bars:
            for k in range(5):
                u = 0.3 + k * 0.13
                pts = [(X(span * u), sy + chord * 0.12 + sweep * u * 0.6), (X(span * (u + 0.03)), sy + chord * (0.5 - u * 0.16) + sweep * u * 0.9)]
                if all(sil.contains(Point(p)) for p in pts):
                    stroke(a, pts, 0.8, 0.85, col=bars, smooth=False)
    if body_bars:
        for k in range(5):
            y = cy - bl * 0.22 + k * bl * 0.13
            stroke(a, [(cx - bw * 0.62, y), (cx + bw * 0.62, y)], 0.8, 0.85, col=body_bars, smooth=False)
    for v in (-0.2, 0, 0.2):                                             # the tail's feathers
        stroke(a, [T(v * 0.5, 0.15), T(v * 1.6, 0.86 if tk != "fork" else 0.7)], 0.4, 0.4, smooth=False)
    for s in (1, -1):
        eye(a, cx + s * hw * 0.62, hy - hh * 0.15, 0.8, False)
    return a
