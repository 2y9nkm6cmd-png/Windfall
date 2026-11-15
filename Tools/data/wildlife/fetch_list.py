"""Every animal with 20 or more research-grade UK records on iNaturalist.
Writes animals.json. One request a second."""
import json, time, urllib.request, urllib.parse, sys
UA = {"User-Agent": "Windfall garden app (species reference list); one request a second"}
BASE = "https://api.inaturalist.org/v1/"
UK = 6857
GROUPS = ["Insecta", "Arachnida", "Aves", "Mammalia", "Amphibia", "Reptilia", "Mollusca", "Actinopterygii", "Animalia"]
MIN = 20
def get(path, **q):
    url = BASE + path + "?" + urllib.parse.urlencode(q)
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return json.load(r)
        except Exception as e:
            print("retry", attempt, e, file=sys.stderr); time.sleep(5 + 10 * attempt)
    raise SystemExit("gave up on " + url)
out = []
for g in GROUPS:
    page = 1
    while True:
        d = get("observations/species_counts", place_id=UK, quality_grade="research", iconic_taxa=g,
                per_page=500, page=page, locale="en-GB", preferred_place_id=UK)
        time.sleep(1)
        rows = d["results"]
        if not rows: break
        stop = False
        for r in rows:
            if r["count"] < MIN: stop = True; break
            t = r["taxon"]
            out.append({"id": t["id"], "name": t["name"], "rank": t["rank"], "common": t.get("preferred_common_name"),
                        "english": t.get("english_common_name"), "iconic": g, "records": r["count"],
                        "ancestors": t.get("ancestor_ids", []), "status": (t.get("conservation_status") or {}).get("status_name"),
                        "introduced": bool(t.get("establishment_means") and t["establishment_means"].get("establishment_means") == "introduced"),
                        "wiki": t.get("wikipedia_url")})
        print(g, "page", page, "total so far", len(out), "of", d["total_results"], flush=True)
        if stop or page * 500 >= d["total_results"]: break
        page += 1
json.dump(out, open("/home/claude/wild/animals.json", "w"), ensure_ascii=False)
print("kept", len(out))
