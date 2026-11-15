#!/usr/bin/env python3
"""Eira's snowdrop, taken from the app icon.

Eira's symbol is the app icon's snowdrop without the bee, on a circle
(William, 15 November 2026, option A). This script copies the snowdrop's
outlines out of the icon's drawing and writes them into a Swift file, so
the two can never drift apart and nothing is retyped by hand.

Run it from the top of the repository after the icon's drawing changes:

    python3 Tools/design/eira_snowdrop.py

What it reads
    Design/AppIcon/windfall-app-icon-light.svg   the icon, light version
    Design/AppIcon/windfall-app-icon-dark.svg    only to check the outlines match

What it writes
    WindfallShared/SnowdropArt.swift   the outlines, as the path text an SVG uses

With the word "preview" after it, it also writes pictures of the symbol
(SVG files) into the folder named next, for looking at before a build:

    python3 Tools/design/eira_snowdrop.py preview /tmp/snowdrop

The colours, the line widths and the sway are not here. They are in
WindfallShared/SnowdropDrawing.swift, written by hand.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ICON = os.path.join(ROOT, "Design", "AppIcon", "windfall-app-icon-%s.svg")
SWIFT = os.path.join(ROOT, "WindfallShared", "SnowdropArt.swift")

# Where Eira's circle sits on the icon's drawing, in the icon's own numbers:
# its middle, and how far out its edge is. The rim trims the leaves.
CENTRE = (200.0, 215.0)
RADIUS = 200.0


def paths_of(svg_text):
    """Every <path> in the icon, in order, as (outline, attributes)."""
    found = []
    for match in re.finditer(r"<path\b([^>]*)>", svg_text):
        attributes = match.group(1)
        outline = re.search(r'\bd="([^"]*)"', attributes).group(1)
        found.append((outline, attributes))
    return found


def snowdrop_parts(mode):
    """The snowdrop's twelve outlines from one version of the icon.

    The parts are told apart by how the icon draws them: the stalk is the
    one line with no fill and round ends, the leaves have the 9.1 line (5.0
    in the dark icon), and so on. If the icon's drawing is ever rearranged,
    the counts below stop matching and the script stops instead of guessing."""
    paths = paths_of(open(ICON % mode).read())
    line = "#06421B"

    def having(*needles):
        return [d for d, a in paths if all(n in a for n in needles)]

    leaf_width = "9.1" if mode == "light" else "5.0"
    parts = {
        "stalk": [d for d in having('fill="none"', 'stroke-linecap="round"') if d.startswith("M98.5,262.0")],
        "leaves": having(f'stroke-width="{leaf_width}"', 'fill="#C0D76D"'),
        "petals": having('stroke-width="8.8"', 'fill="#FFFFFF"', f'stroke="{line}"'),
        "cup": having('stroke-width="6.4"', 'fill="#FFFFFF"', f'stroke="{line}"'),
        "vMark": [d for d, a in paths if 'fill="#C0D76D"' in a and "stroke" not in a],
        "cap": having('stroke-width="8.7"', 'fill="#C0D76D"'),
    }
    wanted = {"stalk": 1, "leaves": 3, "petals": 3, "cup": 3, "vMark": 1, "cap": 1}
    for name, count in wanted.items():
        if len(parts[name]) != count:
            sys.exit(f"The {mode} icon has {len(parts[name])} of '{name}', not {count}. Has its drawing changed?")
    return parts


def swift_text(parts):
    def quoted(d):
        return '"' + d + '"'

    def one(name, note):
        return f"    /// {note}\n    static let {name} = {quoted(parts[name][0])}\n"

    def many(name, note):
        rows = ",\n".join("        " + quoted(d) for d in parts[name])
        return f"    /// {note}\n    static let {name} = [\n{rows}\n    ]\n"

    return f"""//
//  SnowdropArt.swift
//  WindfallShared
//
//  The outlines of Eira's snowdrop.
//
//  DO NOT CHANGE THIS FILE BY HAND. It is written by
//  Tools/design/eira_snowdrop.py, which copies every outline out of the
//  app icon's drawing (Design/AppIcon/windfall-app-icon-light.svg), so
//  Eira's snowdrop and the icon's are one drawing. To change a shape,
//  change the icon and run the script again.
//
//  The numbers are the icon's own, about 0 to 460 across. In this text
//  M means "move to", C means "curve to" (two control points, then the
//  end point) and Z means "close the shape".
//
//  The parts are kept apart so that each can have its own colour and so
//  the stalk can lean and the flower head swing. How they are coloured
//  and moved is in SnowdropDrawing.swift.
//

import CoreGraphics

nonisolated enum SnowdropArt {{

    /// The middle of Eira's circle on the icon's drawing.
    static let centre = CGPoint(x: {CENTRE[0]:g}, y: {CENTRE[1]:g})
    /// How far the circle's edge is from its middle. Its rim trims the leaves.
    static let radius: CGFloat = {RADIUS:g}

{one("stalk", "The arching stalk, a line with no inside. It ends under the cap.")}
{many("leaves", "The leaves: left, right, then the tall one in front.")}
{many("petals", "The three outer petals: left, right, then the middle one behind.")}
{many("cup", "The inner cup: two side pieces, then the front piece.")}
{one("vMark", "The small green V on the front of the cup.")}
{one("cap", "The green cap the petals hang from.")}}}
"""


# Pictures for looking at before a build

GREEN, LEAF, CREAM, WHITE = "#06421B", "#C0D76D", "#FAEEE0", "#FFFFFF"


def preview(parts, mode, plant=0.0, stalk=0.0, nod=0.0, ground=(98.0, 400.0),
            stalk_base=(98.5, 262.0), tip=(256.5, 84.0)):
    """The symbol as an SVG. `mode` is "light" (green circle) or "dark"
    (cream circle). The three angles are in degrees, as in SnowdropView."""
    def p(d, **a):
        return f'<path d="{d}" ' + " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in a.items()) + "/>"

    def turned(items, angle, about):
        return f'<g transform="rotate({angle} {about[0]} {about[1]})">' + "".join(items) + "</g>"

    back, front = [], []
    if mode == "light":
        back.append(p(parts["stalk"][0], fill="none", stroke=CREAM, stroke_width=8.0, stroke_linecap="round"))
        leaves = [p(d, fill=LEAF, stroke=CREAM, stroke_width=5.0, stroke_linejoin="round") for d in parts["leaves"]]
        for d in parts["petals"]:
            front.append(p(d, fill=CREAM, stroke=CREAM, stroke_width=16.8, stroke_linejoin="round"))
        for d in parts["cup"]:
            front.append(p(d, fill=CREAM, stroke=CREAM, stroke_width=14.4, stroke_linejoin="round"))
        front.append(p(parts["cap"][0], fill=CREAM, stroke=CREAM, stroke_width=16.7, stroke_linejoin="round"))
    else:
        back.append(p(parts["stalk"][0], fill="none", stroke=GREEN, stroke_width=12.9, stroke_linecap="round"))
        leaves = [p(d, fill=LEAF, stroke=GREEN, stroke_width=9.1, stroke_linejoin="round") for d in parts["leaves"]]
    for d in parts["petals"]:
        front.append(p(d, fill=WHITE, stroke=GREEN, stroke_width=8.8, stroke_linejoin="round"))
    for d in parts["cup"]:
        front.append(p(d, fill=WHITE, stroke=GREEN, stroke_width=6.4, stroke_linejoin="round"))
    front.append(p(parts["vMark"][0], fill=LEAF))
    front.append(p(parts["cap"][0], fill=LEAF, stroke=GREEN, stroke_width=8.7, stroke_linejoin="round"))

    head = turned(front, nod, tip)
    body = turned([turned(back, stalk, stalk_base)] + leaves + [turned([head], stalk, stalk_base)], plant, ground)
    s = 100.0 / RADIUS
    circle = GREEN if mode == "light" else CREAM
    page = "#F8F1E5" if mode == "light" else "#0C1C14"
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-100 -100 200 200" width="400" height="400">'
            f'<defs><clipPath id="c"><circle r="100"/></clipPath></defs>'
            f'<rect x="-100" y="-100" width="200" height="200" fill="{page}"/>'
            f'<circle r="100" fill="{circle}"/>'
            f'<g clip-path="url(#c)"><g transform="scale({s}) translate({-CENTRE[0]} {-CENTRE[1]})">{body}</g></g></svg>')


if __name__ == "__main__":
    light, dark = snowdrop_parts("light"), snowdrop_parts("dark")
    if light != dark:
        sys.exit("The light and dark icons do not have the same snowdrop outlines.")
    if len(sys.argv) >= 3 and sys.argv[1] == "preview":
        folder = sys.argv[2]
        os.makedirs(folder, exist_ok=True)
        # A lean, and the nod that goes with it in SnowdropWind (1.9 times as far).
        poses = {"rest": (0, 0), "right": (24, 45.6), "left": (-24, -45.6), "back": (-15, -28.5)}
        # How much of the lean the whole plant takes, how much more the stalk
        # takes, and how much of the nod the flower head takes. These three
        # match SnowdropSway in SnowdropDrawing.swift unless given here.
        numbers = [float(n) for n in sys.argv[3:6]]
        plant_share, stalk_share, nod_share = numbers if len(numbers) == 3 else (0.15, 0.35, 0.5)
        for mode in ("light", "dark"):
            for name, (lean, nod) in poses.items():
                with open(os.path.join(folder, f"snowdrop-{mode}-{name}.svg"), "w") as f:
                    f.write(preview(light, mode, plant=lean * plant_share, stalk=lean * stalk_share,
                                    nod=nod * nod_share))
        print("pictures written to", folder)
    else:
        with open(SWIFT, "w") as f:
            f.write(swift_text(light))
        print("written", os.path.relpath(SWIFT, ROOT))
