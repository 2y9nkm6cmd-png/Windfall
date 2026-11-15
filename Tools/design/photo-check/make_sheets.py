"""Makes checking sheets: each animal's drawing beside its reference photographs.
Run with python3 -I. Arguments: photos folder, drawings folder, output folder, list.tsv, order file, mode.
mode 'gallery' uses the t-* photos; mode 'stages' uses every other photo."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

photos, draw_dir, out, list_tsv, order_file, mode = sys.argv[1:7]
ROWS = int(sys.argv[7]) if len(sys.argv) > 7 else 6
H = 200
info = {}
for line in open(list_tsv, encoding="utf-8"):
    tid, name, slug, cls, order, common = line.rstrip("\n").split("\t")
    info[slug] = (name, common, cls, order)
slugs = [s.strip() for s in open(order_file) if s.strip()]
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
except Exception:
    font = ImageFont.load_default()


def strip(slug):
    d = os.path.join(photos, slug)
    files = sorted(os.listdir(d)) if os.path.isdir(d) else []
    if mode == "gallery":
        files = [f for f in files if f.startswith("t-")]
        files.sort(key=lambda f: int(f.split("-")[1].split(".")[0]))
        files = files[:int(os.environ.get("NPH", "6"))]
    else:
        files = [f for f in files if not f.startswith("t-")]
    cells = []
    dp = os.path.join(draw_dir, slug + ".png")
    if os.path.exists(dp):
        cells.append((Image.open(dp).convert("RGB").resize((H, H)), "drawing"))
    extra = os.path.join(draw_dir, "extra")
    if os.path.isdir(extra):
        for f in sorted(os.listdir(extra)):
            if f.startswith(slug + "--"):
                cells.append((Image.open(os.path.join(extra, f)).convert("RGB").resize((H, H)), f.split("--")[1].split(".")[0]))
    for f in files:
        try:
            im = Image.open(os.path.join(d, f)).convert("RGB")
        except Exception:
            continue
        w = max(1, int(im.width * H / im.height))
        im = im.resize((w, H))
        if w > 300:
            x0 = (w - 300) // 2
            im = im.crop((x0, 0, x0 + 300, H))
        cells.append((im, f.split(".")[0] if mode != "gallery" else ""))
    return cells


n = 0
for k in range(0, len(slugs), ROWS):
    rows = [(s, strip(s)) for s in slugs[k:k + ROWS]]
    rows = [(s, c) for s, c in rows if len(c) > (1 if mode != "gallery" else 0)]
    if not rows:
        continue
    width = max(sum(c[0].width + 4 for c in cells) for _, cells in rows) + 8
    width = max(width, 900)
    sheet = Image.new("RGB", (width, len(rows) * (H + 24) + 4), "#ffffff")
    dr = ImageDraw.Draw(sheet)
    for r, (s, cells) in enumerate(rows):
        y = 4 + r * (H + 24)
        name, common, cls, order = info.get(s, (s, "", "", ""))
        dr.text((6, y), f"{common}  ({name})", fill="#000000", font=font)
        x = 4
        for im, lab in cells:
            sheet.paste(im, (x, y + 20))
            if lab:
                dr.rectangle((x, y + 20, x + 8 * len(lab) + 6, y + 38), fill="#000000")
                dr.text((x + 3, y + 20), lab, fill="#ffff00", font=font)
            x += im.width + 4
    n += 1
    sheet.save(os.path.join(out, f"{mode}-{n:02d}.jpg"), quality=80)
print(n, "sheets")
