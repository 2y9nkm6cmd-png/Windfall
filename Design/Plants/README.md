# Plant drawings

One drawing for each kind of plant in the library at each stage of its life that applies: 172 kinds, 908 drawings, each in `light/` and `dark/`.

**A first pass, not yet approved by William and not yet shown anywhere in the app.** Project docs 58 and 59 say how they were made, what is weak and what is to be checked.

| File | What it is |
|---|---|
| `light/plant-<kind>-<stage>.svg` | The drawing for light mode, on a 100 by 100 grid |
| `dark/plant-<kind>-<stage>.svg` | The same drawing in dark-mode colours |
| `plant-drawings.json` | Every kind, its stages with their labels, and the names in the plant library that use it |

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

They are kept out of `Design/Icons` on purpose: `build_design_assets.py` turns every SVG in there into a small icon.
