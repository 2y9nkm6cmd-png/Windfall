# Plant drawings

One drawing for each kind of plant in the library at each stage of its life that applies: 172 kinds, 908 drawings, each in `light/` and `dark/`.

**Redrawn on 16 and 17 November 2026 from a written description of each plant (below). Not yet seen by William.** In the app since 14 November (life stages) and 15 November (leaf and flower), on each plant's page. Project docs 58 and 59 say how they were made, what is weak and what is to be checked.

| File | What it is |
|---|---|
| `light/plant-<kind>-<stage>.svg` | The drawing for light mode, on a 100 by 100 grid |
| `dark/plant-<kind>-<stage>.svg` | The same drawing in dark-mode colours |
| `plant-drawings.json` | Every kind, its stages with their labels, and the names in the plant library that use it |
| `light/plant-<kind>-leaf.svg`, `-bloom.svg` (and the same in `dark/`) | Close-ups of the kind's leaf and flower, added 15 November 2026: 172 leaves and 168 flowers. "bloom" because `flower` is already a stage |
| `plant-parts.json` | Every kind and its close-ups with their labels ("Leaf", "Flower", "Blossom", "Flowers, inside the fig") |

Stages: `seed`, `seedling`, `young`, `crop`, `flower`, `seedhead`, `dormant`, and for some plants `bulb`, `shoots`, `set`, `clove`, `tuber`, `crown`, `runner`, `growing`, `autumn`.

## Do not edit these files by hand

They are written by a script. To change a drawing, change the code and run it again from the top of the repository:

```
python3 Tools/design/plants_all.py /tmp/plants
cp -R /tmp/plants/light /tmp/plants/dark /tmp/plants/plant-drawings.json Design/Plants/
```

- `Tools/design/plant_kit.py`: the parts every drawing is made from (stem, leaf, flower, root, soil) and the colours.
- `Tools/design/plants.py`: ten kinds drawn by hand.
- `Tools/design/plants_all.py`: the templates and one line of settings for each of the other 162 kinds.

The close-ups come from their own script, which reads each kind's settings from `plants_all.py`:

```
python3 Tools/design/leaves_flowers.py /tmp/parts
cp /tmp/parts/light/* Design/Plants/light/ && cp /tmp/parts/dark/* Design/Plants/dark/
cp /tmp/parts/plant-parts.json Design/Plants/
```

- `Tools/design/leaves_flowers.py`: the leaf and flower drawings. `LEAFX` and `BLOOMX` near its foot change single kinds.

## Toothed leaves

Checked on 15 November 2026 after William saw that the raspberry's leaves looked smooth-edged.

- **In a life stage**, a kind's leaves are toothed when its line in `KINDS` (`plants_all.py`) has `edge="saw"` (sharp) or `edge="scallop"` (rounded). A leaf too small to show teeth stays smooth.
- **In a close-up**, `teeth` and `td` in `LEAFX` give the number and depth, and `tk` the kind: `saw`, `double`, `round` or `wave`. No tooth is drawn less than `TMIN` (1.4 grid squares) out from the edge, because a finer one cannot be seen at the size the app draws it.
- **A plant that is not a bulb** takes `tuber=True` or `rhizome=True` on its line, and its first stage is labelled to match.

After either, run `python3 Tools/design/build_design_assets.py` to put them in the app.

They are kept out of `Design/Icons` on purpose: `build_design_assets.py` turns every SVG in there into a small icon.

## The redraw of 16 and 17 November 2026

William found the strawberry leaf drawn wrong, and a check of twelve more plants found eight with clear faults. So every plant was given a written description, and every drawing was rebuilt against it and against photographs of the real plant.

- **`descriptions/<kind>.json`**: what each of the 172 kinds looks like, written before drawing (see `descriptions/README.md`). Its `palette` is the one place a kind's colours are set: both scripts read it, so a close-up and the whole plant can no longer differ in colour. Its `must_show` lists are what each drawing was checked against. ⚠️ CHECK: written by Claude.
- **`Tools/design/redraw/<group>.py`**: each group's changes, in nine files (fruit, roots, umbels, herbs, leaves, veg, daisies, flowers, bulbs). `redraw/__init__.py` says what a file may hold. With `REDRAW_ONLY=<group>` the scripts read only that group's file.
- **`leaf="own"`** on a kind's settings draws its own close-up leaf, small, on the whole plant (`Art.place` in `plant_kit.py`).
- **Paths are slimmed** as they are written (`slim` in `plant_kit.py`): points on a straight line are dropped. Same look, files about a third of the size.
- **Checking a kind**: `python3 Tools/design/plant_sheet.py PHOTOS OUT kind --before` sets every drawing of it, new and old, beside photographs sorted by part. `Tools/design/photo-check/fetch_plant_photos.py` downloads those photographs (for looking at only: never into the repository).
