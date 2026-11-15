import json, time, urllib.request, sys
UA = {"User-Agent": "Windfall garden app (species reference list); one request a second"}
animals = json.load(open("animals.json"))
ids = sorted({x for a in animals for x in a["ancestors"] if x != a["id"]})
print(len(ids), "ancestor ids", flush=True)
out = {}
for i in range(0, len(ids), 30):
    chunk = ids[i:i+30]
    url = "https://api.inaturalist.org/v1/taxa/" + ",".join(map(str, chunk)) + "?locale=en-GB&preferred_place_id=6857"
    for attempt in range(6):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                d = json.load(r); break
        except Exception as e:
            d = None; time.sleep(10 + 20 * attempt)
    for t in d["results"]:
        out[t["id"]] = {"name": t["name"], "rank": t["rank"], "common": t.get("preferred_common_name")}
    time.sleep(1)
json.dump(out, open("ancestors.json", "w"), ensure_ascii=False)
print("done", len(out))
