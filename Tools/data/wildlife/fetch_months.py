"""The month counts, the quick way: for each month and each group, ask iNaturalist
for every species' count of research-grade UK records observed in that month.
About 300 requests in place of 4,000. Writes months_fast.json: {taxon id: [12 counts]}."""
import json, time, urllib.request, urllib.parse, sys
UA = {"User-Agent": "Windfall garden app (species reference list); one request a second"}
GROUPS = ["Insecta", "Arachnida", "Aves", "Mammalia", "Amphibia", "Reptilia", "Mollusca", "Actinopterygii", "Animalia"]
wanted = {a["id"] for a in json.load(open("animals.json"))}
out = {i: [0] * 12 for i in wanted}
calls = 0
for month in range(1, 13):
    for g in GROUPS:
        page = 1
        while True:
            url = "https://api.inaturalist.org/v1/observations/species_counts?" + urllib.parse.urlencode(dict(
                place_id=6857, quality_grade="research", iconic_taxa=g, month=month, per_page=500, page=page))
            d = None
            for attempt in range(6):
                try:
                    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90) as r:
                        d = json.load(r); break
                except Exception as e:
                    print("retry", month, g, page, e, file=sys.stderr, flush=True); time.sleep(10 + 20 * attempt)
            calls += 1; time.sleep(1)
            if d is None: raise SystemExit("gave up")
            for r in d["results"]:
                if r["taxon"]["id"] in out: out[r["taxon"]["id"]][month - 1] = r["count"]
            if not d["results"] or page * 500 >= d["total_results"]: break
            page += 1
    print("month", month, "done,", calls, "requests so far", flush=True)
    json.dump(out, open("months_fast.json", "w"))
print("finished")
