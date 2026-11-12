#!/usr/bin/env python3
"""Builds the app's colours and icons from the files in the Design folder.

Run it from the top of the repository after changing a colour or an icon:

    python3 Tools/design/build_design_assets.py

What it reads
    Design/colours.json     the named colours, each with a light and a dark value
    Design/Icons/*.svg      one small drawing for each icon, on a 24 by 24 grid

What it writes, inside Windfall/Assets.xcassets (the app's store of pictures
and colours, which Xcode calls the asset catalogue)
    Colours/<Name>.colorset     one for each colour
    Icons/<name>.imageset       one for each icon
    AccentColor.colorset        the colour Apple's own controls use, set to Leaf

Two kinds of icon
    An icon drawn only in black is an OUTLINE icon. The app ignores the black
    and paints the shape in whatever colour the code asks for. Xcode calls
    this a template image.

    An icon with any other colour in it is a COLOUR icon, such as the
    butterfly. It is shown as drawn. Its dark green outline (#06472A) would
    vanish on a dark background, so a second copy is made for dark mode with
    the outline in pale green.
"""
import json, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DESIGN = os.path.join(ROOT, "Design")
CATALOGUE = os.path.join(ROOT, "Windfall", "Assets.xcassets")
OUTLINE_LIGHT = "#06472A"
OUTLINE_DARK = "#D9E8C4"
INFO = {"author": "xcode", "version": 1}


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def components(hex_colour):
    """'#F8F1E5' becomes the red, green and blue values Xcode wants."""
    h = hex_colour.lstrip("#")
    return {"red": "0x" + h[0:2].upper(), "green": "0x" + h[2:4].upper(),
            "blue": "0x" + h[4:6].upper(), "alpha": "1.000"}


def colour_set(light, dark):
    def entry(value, is_dark):
        e = {"idiom": "universal",
             "color": {"color-space": "srgb", "components": components(value)}}
        if is_dark:
            e["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        return e
    return {"colors": [entry(light, False), entry(dark, True)], "info": INFO}


def fresh_folder(path):
    """Empties a folder by removing what is in it, then makes sure it exists."""
    if os.path.isdir(path):
        shutil.rmtree(path)
    os.makedirs(path)


def build_colours():
    with open(os.path.join(DESIGN, "colours.json"), encoding="utf-8") as f:
        colours = json.load(f)["colours"]
    folder = os.path.join(CATALOGUE, "Colours")
    fresh_folder(folder)
    # "provides-namespace" means the app asks for "Colours/Paper", not just
    # "Paper", so a colour can never clash with an icon of the same name.
    write_json(os.path.join(folder, "Contents.json"),
               {"info": INFO, "properties": {"provides-namespace": True}})
    for c in colours:
        write_json(os.path.join(folder, c["name"] + ".colorset", "Contents.json"),
                   colour_set(c["light"], c["dark"]))
        if c["name"] == "Leaf":
            write_json(os.path.join(CATALOGUE, "AccentColor.colorset", "Contents.json"),
                       colour_set(c["light"], c["dark"]))
    return len(colours)


def build_icons():
    source = os.path.join(DESIGN, "Icons")
    folder = os.path.join(CATALOGUE, "Icons")
    fresh_folder(folder)
    write_json(os.path.join(folder, "Contents.json"),
               {"info": INFO, "properties": {"provides-namespace": True}})
    outline, colour = 0, 0
    for filename in sorted(os.listdir(source)):
        if not filename.endswith(".svg"):
            continue
        name = filename[:-4]
        with open(os.path.join(source, filename), encoding="utf-8") as f:
            svg = f.read()
        used = {c.upper() for c in re.findall(r"#[0-9A-Fa-f]{6}", svg)}
        is_outline = used <= {"#000000"}
        image_set = os.path.join(folder, name + ".imageset")
        os.makedirs(image_set)
        with open(os.path.join(image_set, filename), "w", encoding="utf-8") as f:
            f.write(svg)
        images = [{"idiom": "universal", "filename": filename}]
        if is_outline:
            outline += 1
        else:
            colour += 1
            dark_name = name + "-dark.svg"
            with open(os.path.join(image_set, dark_name), "w", encoding="utf-8") as f:
                f.write(re.sub(OUTLINE_LIGHT, OUTLINE_DARK, svg, flags=re.I))
            images.append({"idiom": "universal", "filename": dark_name,
                           "appearances": [{"appearance": "luminosity", "value": "dark"}]})
        write_json(os.path.join(image_set, "Contents.json"), {
            "images": images, "info": INFO,
            "properties": {
                # Keep the drawing as shapes, so it stays sharp at any size.
                "preserves-vector-representation": True,
                "template-rendering-intent": "template" if is_outline else "original",
            }})
    return outline, colour


if __name__ == "__main__":
    n = build_colours()
    outline, colour = build_icons()
    print(f"{n} colours, {outline} outline icons and {colour} colour icons written to Windfall/Assets.xcassets")
