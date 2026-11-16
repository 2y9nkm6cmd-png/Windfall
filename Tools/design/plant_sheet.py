"""A check sheet for one kind of plant: every drawing of it, beside photographs
sorted by the part of the plant they show. Made for the redraw of 16 November 2026.

Run from Tools/design:
    python3 plant_sheet.py PHOTOS OUT kind[,kind...] [--before]

PHOTOS is the folder fetch_plant_photos.py filled (photo-check/). OUT gets
sheet-<kind>.png. With --before a row of the drawings as they are in
Design/Plants/light (the last ones put in the app) goes under the new ones.
Needs rsvg-convert and Python's Pillow. The sheets hold other people's
photographs: never put one in the repository.
"""
import os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont
import plants_all as PA
import leaves_flowers as LFW

CELL = 210
HERE = os.path.dirname(os.path.abspath(__file__))
OLD = os.path.join(HERE, "..", "..", "Design", "Plants", "light")


def font(n):
    for p in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.exists(p):
            return ImageFont.truetype(p, n)
    return ImageFont.load_default()


def png(svg_text, tmp, name):
    s = os.path.join(tmp, name + ".svg"); p = os.path.join(tmp, name + ".png")
    open(s, "w", encoding="utf-8").write(svg_text)
    subprocess.run(["rsvg-convert", "-w", str(CELL), "-h", str(CELL), "-b", "#FFFCF6", s, "-o", p], check=True)
    return Image.open(p).convert("RGB")


def photo(path, h=CELL):
    im = Image.open(path).convert("RGB")
    return im.resize((max(1, int(im.width * h / im.height)), h))


def drawings(kind):
    """[(label, svg text)] for the kind: close-ups, then the life stages."""
    out = []
    for slug, name, s in LFW.all_kinds():
        if slug == kind:
            for pt, lb, fn in LFW.parts(slug, s):
                out.append((pt, fn().svg(0)))
    for slug, name, sts, _ in PA.all_plants():
        if slug == kind:
            for st, lb, fn in sts:
                out.append((st, fn().svg(0)))
    return out


def row(items, W=None):
    """items: [(label, image)] -> one strip with labels above."""
    f = font(15); h = CELL + 22
    w = sum(im.width + 8 for _, im in items) or 10
    strip = Image.new("RGB", (w, h), "white"); d = ImageDraw.Draw(strip); x = 0
    for lb, im in items:
        strip.paste(im, (x, 22)); d.text((x + 3, 2), lb, fill="black", font=f); x += im.width + 8
    return strip


def sheet(photos, out, kind, before):
    with tempfile.TemporaryDirectory() as tmp:
        new = [(lb, png(svg, tmp, lb)) for lb, svg in drawings(kind)]
        rows = [("NEW", row(new))]
        if before:
            old = []
            for lb, _ in new:
                p = os.path.join(OLD, f"plant-{kind}-{lb}.svg")
                if os.path.exists(p):
                    old.append((lb, png(open(p, encoding="utf-8").read(), tmp, "old-" + lb)))
            rows.append(("BEFORE", row(old)))
        pd = os.path.join(photos, kind)
        if os.path.isdir(pd):
            fs = sorted(x for x in os.listdir(pd) if x.endswith(".jpg"))
            order = ["species", "leaf", "any", "winter", "flower", "fruit"]
            fs.sort(key=lambda x: (order.index(x.split("-")[0].split(".")[0]) if x.split("-")[0].split(".")[0] in order else 9, x))
            a = [(x[:-4], photo(os.path.join(pd, x))) for x in fs if x.split("-")[0].split(".")[0] in ("species", "leaf", "any", "winter")]
            b = [(x[:-4], photo(os.path.join(pd, x))) for x in fs if x.split("-")[0] in ("flower", "fruit")]
            rows += [("PHOTOS: leaves and habit", row(a)), ("PHOTOS: flowers and fruit", row(b))]
        W = max(r.width for _, r in rows) + 10
        H = 36 + sum(r.height + 30 for _, r in rows)
        img = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(img)
        d.text((6, 6), kind, fill="black", font=font(22)); y = 36
        for title, r in rows:
            d.text((6, y), title, fill="#444", font=font(14)); img.paste(r, (6, y + 20)); y += r.height + 30
        os.makedirs(out, exist_ok=True)
        p = os.path.join(out, f"sheet-{kind}.png"); img.save(p)
        return p


if __name__ == "__main__":
    photos, out, kinds = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
    for k in kinds:
        print(sheet(photos, out, k, "--before" in sys.argv))
