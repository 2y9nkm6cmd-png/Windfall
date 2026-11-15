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

⚠️ Nothing in the file has been checked by William. The names are
iNaturalist's own, so some are not the usual British ones.
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from wildlife_kinds import KINDS, kind_of

src = json.load(open(os.path.join(HERE, "wildlife", "uk-animals-inaturalist.json"), encoding="utf-8"))
order = {slug: i for i, (slug, _, _) in enumerate(KINDS)}
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
    animals.append(row)
animals.sort(key=lambda r: (order[r["k"]], -r["n"], r["s"]))
out = {"source": src["source"], "fetched": src["fetched"], "rule": src["rule"], "checked": False,
       "kinds": [{"slug": s, "name": n, "group": g} for s, n, g in KINDS], "animals": animals}
path = os.path.join(ROOT, "Windfall", "WildlifeReference.json")
with open(path, "w", encoding="utf-8") as fh:
    json.dump(out, fh, ensure_ascii=False, separators=(",", ":"))
    fh.write("\n")
with_months = sum(1 for r in animals if "m" in r)
print(f"{len(animals)} animals in {len(KINDS)} kinds written to Windfall/WildlifeReference.json "
      f"({os.path.getsize(path) // 1024} KB). {with_months} have month counts. Not sorted into a kind: {unsorted}")
