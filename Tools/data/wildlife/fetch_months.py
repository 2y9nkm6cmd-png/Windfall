"""One of three workers. Usage: fetch_months_w.py <k>. Takes every third animal still missing, at most one request every 2 seconds."""
import json, time, urllib.request, urllib.parse, sys, os, glob
k = int(sys.argv[1])
UA = {"User-Agent": "Windfall garden app (species reference list)"}
animals = json.load(open("animals.json"))
done = set()
for fn in glob.glob("months*.jsonl"):
    for line in open(fn):
        try: done.add(json.loads(line)["id"])
        except Exception: pass
todo = [a for a in animals if a["id"] not in done]
f = open(f"months-w{k}.jsonl", "a")
for i, a in enumerate(todo):
    if i % 3 != k: continue
    t0 = time.time(); d = None
    url = "https://api.inaturalist.org/v1/observations/histogram?" + urllib.parse.urlencode(dict(
        taxon_id=a["id"], place_id=6857, quality_grade="research", date_field="observed", interval="month_of_year"))
    for attempt in range(5):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                d = json.load(r); break
        except Exception as e:
            time.sleep(15 + 30 * attempt)
    if d is None: continue
    m = d["results"]["month_of_year"]
    f.write(json.dumps({"id": a["id"], "m": [m.get(str(j), 0) for j in range(1, 13)]}) + "\n"); f.flush()
    time.sleep(max(0.0, 2.0 - (time.time() - t0)))
print("finished", k)
