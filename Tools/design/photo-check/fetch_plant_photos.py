"""Downloads photographs of every plant kind from iNaturalist, sorted by the
part of the plant they show, for checking the drawings against.

THE PHOTOGRAPHS ARE OTHER PEOPLE'S WORK. They are for looking at only.
Never put one in the app or in this repository.

Run (needs the web; Claude's cloud workspace can reach iNaturalist since
16 November 2026, so the Mac is no longer needed):

    python3 fetch_plant_photos.py OUT_FOLDER [kind,kind,...]

For each kind in plant-names.tsv it writes OUT_FOLDER/<kind>/:
    species.jpg      the photo iNaturalist itself shows for the species
    leaf-N.jpg       records marked "no evidence of flowering": leaves and habit
    flower-N.jpg     records marked "flowering"
    fruit-N.jpg      records marked "fruiting": fruit and seed heads
    winter-N.jpg     records from December to February with no flowers
    credits.tsv      each photo's record, photographer and licence

Records from Great Britain come first (place 6857); if there are too few,
records from anywhere fill the gap. Only research-grade records with an open
licence are used. One request a second, as iNaturalist asks.
"""
import json, os, sys, time, urllib.parse, urllib.request

API = "https://api.inaturalist.org/v1/"
PARTS = [("leaf", "&term_id=12&term_value_id=21", 4), ("flower", "&term_id=12&term_value_id=13", 4),
         ("fruit", "&term_id=12&term_value_id=14", 3), ("winter", "&term_id=12&term_value_id=21&month=12,1,2", 2)]
LIC = "cc0,cc-by,cc-by-nc,cc-by-sa,cc-by-nc-sa,cc-by-nd,cc-by-nc-nd"
_last = [0.0]


def get(url, raw=False):
    wait = 1.0 - (time.time() - _last[0])
    if wait > 0:
        time.sleep(wait)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Windfall-drawing-check/1.0"})
            with urllib.request.urlopen(req, timeout=40) as r:
                data = r.read()
            _last[0] = time.time()
            return data if raw else json.loads(data)
        except Exception as e:
            if attempt == 3:
                raise
            time.sleep(4 * (attempt + 1))


def taxon(name):
    res = get(f"{API}taxa?q={urllib.parse.quote(name)}&per_page=10")["results"]
    for t in res:
        if t["name"].lower().replace(" × ", " ").replace("×", "") == name.lower():
            return t
    return res[0] if res else None


def main():
    out = sys.argv[1]
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
    here = os.path.dirname(os.path.abspath(__file__))
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(here, "plant-names.tsv"), encoding="utf-8")][1:]
    for kind, name in rows:
        if only and kind not in only:
            continue
        d = os.path.join(out, kind)
        if os.path.exists(os.path.join(d, "credits.tsv")):
            continue
        os.makedirs(d, exist_ok=True)
        t = taxon(name)
        if not t:
            print("not found:", kind, name, flush=True); continue
        credits = [("file", "taxon", "record", "photographer", "licence", "url")]
        dp = t.get("default_photo") or {}
        if dp.get("medium_url"):
            open(os.path.join(d, "species.jpg"), "wb").write(get(dp["medium_url"], raw=True))
            credits.append(("species.jpg", t["name"], "", dp.get("attribution", ""), dp.get("license_code", ""), dp["medium_url"]))
        for part, q, n in PARTS:
            urls = []
            for place in ("&place_id=6857", ""):
                res = get(f"{API}observations?taxon_id={t['id']}{place}&quality_grade=research&photos=true{q}"
                          f"&photo_license={LIC}&per_page={n * 3}")["results"]
                for o in res:
                    p = o["photos"][0]
                    u = p["url"].replace("square", "medium")
                    if u not in [x[0] for x in urls]:
                        urls.append((u, o["id"], o["user"]["login"], p.get("license_code", "")))
                if len(urls) >= n:
                    break
            for i, (u, oid, who, lic) in enumerate(urls[:n]):
                fn = f"{part}-{i + 1}.jpg"
                open(os.path.join(d, fn), "wb").write(get(u, raw=True))
                credits.append((fn, t["name"], f"https://www.inaturalist.org/observations/{oid}", who, lic, u))
        with open(os.path.join(d, "credits.tsv"), "w", encoding="utf-8") as fh:
            fh.write("\n".join("\t".join(map(str, c)) for c in credits) + "\n")
        print("done", kind, t["name"], len(credits) - 1, "photos", flush=True)


if __name__ == "__main__":
    main()
