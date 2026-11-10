import re, sys, os, collections
d = sys.argv[1]
files = sorted(f for f in os.listdir(d) if f.endswith('.swift'))
src = {f: open(os.path.join(d, f), encoding='utf-8').read() for f in files}

def strip(s):
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    s = re.sub(r'"""(.*?)"""', '""', s, flags=re.S)
    s = re.sub(r'"(\\.|[^"\\\n])*"', '""', s)
    return s
code = {f: strip(s) for f, s in src.items()}

defs = collections.defaultdict(list)
for f, s in code.items():
    for m in re.finditer(r'^\s*(?:(?:public|private|fileprivate|internal|final|indirect|@\w+(?:\([^)]*\))?)\s+)*(struct|class|enum|protocol|actor|typealias)\s+([A-Z]\w*)', s, flags=re.M):
        defs[m.group(2)].append((f, m.group(1)))

print("== files:", len(files))
print("== duplicate top-level-ish type names (possible redeclaration; nested types may be fine):")
for n, lst in sorted(defs.items()):
    if len(lst) > 1:
        print("  ", n, lst)

# @Model classes
models = []
for f, s in src.items():
    for m in re.finditer(r'@Model\s+(?:final\s+)?class\s+(\w+)', s):
        models.append((m.group(1), f))
print("== @Model classes:", len(models))
app = src.get('WindfallApp.swift', '')
schema = re.findall(r'(\w+)\.self', app)
print("== schema entries in WindfallApp.swift:", len(schema), schema)
mn = {m for m, _ in models}
print("   models missing from schema:", sorted(mn - set(schema)))
print("   schema entries with no @Model:", sorted(set(schema) - mn))

# undefined capitalised identifiers
used = collections.Counter()
where = collections.defaultdict(set)
for f, s in code.items():
    for m in re.finditer(r'(?<![\.\w#@])([A-Z][A-Za-z0-9_]+)\b', s):
        used[m.group(1)] += 1
        where[m.group(1)].add(f)
undefined = sorted(n for n in used if n not in defs)
print("== capitalised identifiers used but not defined in project:", len(undefined))
print(", ".join(undefined))
