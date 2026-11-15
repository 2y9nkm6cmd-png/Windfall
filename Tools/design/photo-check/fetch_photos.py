# Fetches reference photographs from iNaturalist for every animal that has its own Windfall drawing.
# For checking drawings only. The photos are other people's work: never put them in the app or the repository.
import json, os, sys, time, csv, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor
ROOT = os.path.expanduser("~/Developer/windfall-photo-check")
OUT = os.path.join(ROOT, "photos")
RAW = "https://raw.githubusercontent.com/2y9nkm6cmd-png/Windfall/main/"
UA = {"User-Agent": "Windfall-drawing-check/1.0 (personal garden app; checking drawings against photos)"}
LIC = "cc0,cc-by,cc-by-nc,cc-by-sa,cc-by-nc-sa"
def get(url, tries=4):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40) as r:
                return r.read()
        except Exception as e:
            err = e; time.sleep(3 + 4 * i)
    print("FAILED", url, err, flush=True); return None
def api(path):
    time.sleep(1.05)
    b = get("https://api.inaturalist.org/v1/" + path)
    return json.loads(b) if b else {"results": []}
species = json.loads(get(RAW + "Design/Wildlife/species-drawings.json"))["species"]
animals = {a["name"]: a for a in json.loads(get(RAW + "Tools/data/wildlife/uk-animals-inaturalist.json"))["animals"]}
rows = [(animals[n]["id"], n, s, animals[n]["lineage"].get("class", ""), animals[n]["lineage"].get("order", "")) for n, s in sorted(species.items()) if n in animals]
print(len(rows), "animals", flush=True)
jobs, credits = [], []
def want(slug, tag, i, photo, obs=""):
    url = (photo.get("medium_url") or photo.get("url", "").replace("square", "medium"))
    if not url: return
    ext = url.split("?")[0].rsplit(".", 1)[-1].lower()
    if ext not in ("jpg", "jpeg", "png"): ext = "jpg"
    f = os.path.join(OUT, slug, "%s-%d.%s" % (tag, i, ext))
    jobs.append((url, f))
    credits.append([slug, os.path.basename(f), photo.get("id"), photo.get("license_code") or "all rights reserved", photo.get("attribution", ""), obs])
# 1. each species' own gallery of photos
for k in range(0, len(rows), 30):
    chunk = rows[k:k + 30]
    res = api("taxa/" + ",".join(str(r[0]) for r in chunk)).get("results", [])
    got = {t["id"]: t for t in res}
    for tid, name, slug, cls, order in chunk:
        tp = [p["photo"] for p in got.get(tid, {}).get("taxon_photos", [])]
        n = 10 if cls == "Aves" else 8
        for i, p in enumerate(tp[:n]): want(slug, "t", i, p)
    print("gallery", k + len(chunk), flush=True)
# 2. other life stages and the other sex, from research-grade records with an open licence
def stage(tid, slug, tag, term, value, n):
    q = "observations?taxon_id=%d&term_id=%d&term_value_id=%d&quality_grade=research&photos=true&photo_license=%s&per_page=%d&order_by=votes" % (tid, term, value, LIC, n)
    res = api(q + "&place_id=6857").get("results", [])
    if len(res) < n: res = res + api(q).get("results", [])
    seen = set(); i = 0
    for o in res:
        if o["id"] in seen or not o.get("photos"): continue
        seen.add(o["id"]); want(slug, tag, i, o["photos"][0], "https://www.inaturalist.org/observations/%d" % o["id"]); i += 1
        if i >= n: break
for j, (tid, name, slug, cls, order) in enumerate(rows):
    if cls == "Insecta":
        if order in ("Hemiptera", "Odonata", "Orthoptera"):
            stage(tid, slug, "nymph", 1, 5, 3)
        else:
            stage(tid, slug, "larva", 1, 6, 3); stage(tid, slug, "pupa", 1, 4, 2)
    elif cls == "Amphibia":
        stage(tid, slug, "larva", 1, 6, 3); stage(tid, slug, "egg", 1, 7, 2)
    elif cls == "Aves":
        stage(tid, slug, "female", 9, 10, 2); stage(tid, slug, "juvenile", 1, 8, 2)
    if j % 20 == 0: print("stages", j, name, flush=True)
with open(os.path.join(ROOT, "credits.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(["animal", "file", "inaturalist photo id", "licence", "credit", "record"]); w.writerows(credits)
def fetch(job):
    url, f = job
    if os.path.exists(f) and os.path.getsize(f) > 500: return 1
    os.makedirs(os.path.dirname(f), exist_ok=True)
    b = get(url)
    if b: open(f, "wb").write(b); return 1
    return 0
with ThreadPoolExecutor(6) as ex: done = sum(ex.map(fetch, jobs))
print("photos wanted", len(jobs), "saved", done, flush=True)
print("DONE", flush=True)
