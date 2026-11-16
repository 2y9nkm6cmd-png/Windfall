# Plant descriptions

One file for each kind of plant in `Design/Plants`: what the plant looks like, written down before it is drawn. Made on 16 November 2026, after William found the strawberry leaf drawn wrong and a check of twelve more plants found eight with clear faults.

**Every drawing of a plant is built from and checked against its description.** The colours in `palette` are read straight into both drawing scripts. The rest is the list a drawing is checked against, point by point, beside photographs.

**⚠️ CHECK: written by Claude** from field-guide knowledge and photographs on iNaturalist, not from a book. William's corrections go in the file itself, and the drawings are then put right to match.

## The fields

| Field | What it holds |
|---|---|
| `kind` | The file name and the drawings' name, such as `strawberry` |
| `name` | The name in the library |
| `latin` | The Latin name, as a flora would give it today |
| `family` | The plant family, in Latin and English |
| `grown_as` | What the garden grows: a crop variety, a wild flower, a shrub. Where William's own variety matters to the look and is not known, this says so |
| `habit` | The shape of the whole plant and how big it grows |
| `leaf` | `arrangement` (rosette, alternate, opposite, in whorls), `type` (simple, or compound and how), `outline`, `base`, `tip`, `margin` (and where on the leaf the teeth are), `veins`, `surface` (hairs, gloss, wrinkles, pleats, colour beneath), `stalk`, `colour` |
| `flower` | `form` (the shape, in plain words), `petals` (how many, free or joined, their shape), `colour`, `centre` (stamens, eye, cone), `behind` (sepals or bracts that show), `carried` (alone, in a spike, a head, an umbel, a spray; upright or nodding), `size`, `season`. `null` for a plant not drawn in flower |
| `fruit` | Fruit, pods or seed heads, and their colour when ripe |
| `seedling` | The seed leaves and the first true leaves |
| `winter` | What is left above ground in winter, if anything |
| `palette` | The colour names (from `COLOURS` in `Tools/design/plant_kit.py`) for `leaf`, `flower`, `centre` and `fruit`. Leave out any that do not apply |
| `must_show` | For each drawing (`leaf`, `bloom`, and each life stage the kind has: `seed`, `seedling`, `young`, `flower`, `crop`, `seedhead`, `dormant` and the rest), the few things it must show to be right. These are what the check marks |
| `look_alikes` | Plants it could be taken for, and what tells them apart |
| `checked` | What the drawings were checked against, when, and what was found |

The drawings themselves are made by `Tools/design/plants_all.py` and `Tools/design/leaves_flowers.py`, with each group's changes in `Tools/design/redraw/`. See `Design/Plants/README.md`.
