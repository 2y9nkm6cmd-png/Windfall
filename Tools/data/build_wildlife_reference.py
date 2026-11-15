#!/usr/bin/env python3
"""Builds the app's UK wildlife reference, Windfall/WildlifeReference.json.

Run it from the top of the repository:

    python3 Tools/data/build_wildlife_reference.py

What it reads
    Tools/data/wildlife/uk-animals-inaturalist.json
        every animal with 20 or more "research grade" records in the United
        Kingdom on iNaturalist, as fetched by Tools/data/wildlife/fetch_*.py:
        its names, where it sits in the tree of life, how many UK records it
        has and how many fall in each month.
    Tools/data/wildlife_kinds.py
        the kinds (bumblebee, hoverfly, tit...) and the rules that sort an
        animal into one.

What it writes
    Windfall/WildlifeReference.json, with short field names to keep it small:
        s  scientific name          c  common name (may be missing)
        k  the kind's slug          f  family           o  order
        n  UK records               m  records in each month, January first
        i  true when iNaturalist marks it as introduced to the UK
        p  the name of its own drawing, for an animal that has one
           (Design/Wildlife/species-drawings.json, written by Tools/design/wildlife.py)
    and, on a kind, "is": the animal that kind's drawing shows.

⚠️ Nothing in the file has been checked by William. The names are
iNaturalist's own, so some are not the usual British ones.
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from wildlife_kinds import KINDS, kind_of

src = json.load(open(os.path.join(HERE, "wildlife", "uk-animals-inaturalist.json"), encoding="utf-8"))
order = {slug: i for i, (slug, _, _) in enumerate(KINDS)}
drawn = json.load(open(os.path.join(ROOT, "Design", "Wildlife", "species-drawings.json"), encoding="utf-8"))
own, typical = drawn["species"], drawn["kindsDrawnAs"]
# An animal's OTHER drawings (in flight, the female, the caterpillar) and what its first drawing shows.
views, shows = drawn.get("views", {}), drawn.get("mainShows", {})
animals, unsorted = [], []
for a in src["animals"]:
    k = kind_of(a["lineage"])
    if k is None:
        unsorted.append(a["name"]); continue
    row = {"s": a["name"]}
    if a.get("common"):
        row["c"] = a["common"][0].upper() + a["common"][1:]
    row["k"] = k
    if a["lineage"].get("family"): row["f"] = a["lineage"]["family"]
    if a["lineage"].get("order"): row["o"] = a["lineage"]["order"]
    row["n"] = a["records"]
    if a.get("months"): row["m"] = a["months"]
    if a.get("introduced"): row["i"] = True
    if a["name"] in own: row["p"] = own[a["name"]]
    if a["name"] in views: row["v"] = views[a["name"]]; row["w"] = shows.get(a["name"], "adult")
    animals.append(row)
animals.sort(key=lambda r: (order[r["k"]], -r["n"], r["s"]))
# For a few genera, the animal whose drawing stands for every member: used for one of William's own species that the list does not hold.
genera = {g.lower(): name for g, name in drawn.get("genera", {}).items()}
out = {"source": src["source"], "fetched": src["fetched"], "rule": src["rule"], "checked": False, "genera": genera,
       "kinds": [dict({"slug": s, "name": n, "group": g}, **({"is": typical[s]} if s in typical else {})) for s, n, g in KINDS], "animals": animals}
path = os.path.join(ROOT, "Windfall", "WildlifeReference.json")
with open(path, "w", encoding="utf-8") as fh:
    json.dump(out, fh, ensure_ascii=False, separators=(",", ":"))
    fh.write("\n")
with_months = sum(1 for r in animals if "m" in r)
lost = sorted(set(own) - {r["s"] for r in animals})
print(f"{sum(1 for r in animals if 'p' in r)} animals have a drawing of their own. Drawn but not in the list: {lost}")
print(f"{sum(1 for r in animals if 'v' in r)} of them have more than one drawing: {sum(len(r['v']) for r in animals if 'v' in r)} other drawings in all.")
print(f"{len(animals)} animals in {len(KINDS)} kinds written to Windfall/WildlifeReference.json "
      f"({os.path.getsize(path) // 1024} KB). {with_months} have month counts. Not sorted into a kind: {unsorted}")
