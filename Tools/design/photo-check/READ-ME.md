# Checking the wildlife drawings against photographs

Used on 15 November 2026 to set every single-animal drawing beside photographs. `Design/Wildlife/CHECKED.md` records what was found.

**The photographs are other people's work. They are for looking at only. Never put one in the app or in this repository.**

1. **On the Mac** (it can reach the web, Claude's cloud workspace cannot): `python3 fetch_photos.py` downloads, for every animal in `Design/Wildlife/species-drawings.json`, the photos iNaturalist shows for the species, and records marked as larva, pupa, nymph, egg, female or juvenile. They go to `~/Developer/windfall-photo-check/photos/<animal>/`, with each photographer's name and licence in `credits.csv`. About 2,200 photos, 220MB, 25 minutes.
2. `shrink.sh` makes small copies in `small/`, which can be zipped and sent to a chat.
3. **Where the drawings are** (the cloud workspace, or any machine with `rsvg-convert` and Python's Pillow): turn each `wild-sp-*.svg` into a PNG, then `python3 -I make_sheets.py <photos> <drawings> <out> <list.tsv> <order.txt> gallery 7` makes sheets with each drawing beside its photos. `stages` in place of `gallery` shows the life-stage photos.
