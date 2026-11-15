# The UK wildlife list: where it came from

Made by Claude on 15 November 2026 in a cloud workspace. ⚠️ Not checked by William.

| File | What it is |
|---|---|
| `uk-animals-inaturalist.json` | What iNaturalist returned, joined into one file: every animal with 20 or more research-grade records in the United Kingdom, with its names, its place in the tree of life, its count of UK records and its count in each month |
| `fetch_list.py` | Fetches the list, group by group, most recorded first, and stops at 20 records |
| `fetch_ancestors.py` | Looks up each animal's family, order and class |
| `fetch_months.py` | Fetches the month counts: for each month and each group it asks for every species' count of records observed in that month. About 170 requests, three minutes. (The first try asked for one animal at a time, which would have taken over an hour. The two ways gave the same counts for 1,617 of the 1,635 animals fetched both ways, and the other 18 differed by one or two records that arrived in between.) |

The three scripts are kept as they were run, in a scratch folder: they read and write `animals.json`, `ancestors.json` and `months_fast.json` beside themselves. To use them again, run them in an empty folder and join the results the way `uk-animals-inaturalist.json` is laid out.

To rebuild the app's list from this folder, with no fetching:

    python3 Tools/data/build_wildlife_reference.py

The kinds and the rules that sort an animal into one are in `Tools/data/wildlife_kinds.py`.

Source: iNaturalist API, https://api.inaturalist.org/v1/docs/ (place 6857 is the United Kingdom).
