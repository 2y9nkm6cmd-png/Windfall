import re, sys, os, collections
d = sys.argv[1]
files = sorted(f for f in os.listdir(d) if f.endswith('.swift'))
src = {f: open(os.path.join(d, f), encoding='utf-8').read() for f in files}
def strip(s):
    s = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), s, flags=re.S)
    s = re.sub(r'//[^\n]*', '', s)
    s = re.sub(r'"""(.*?)"""', lambda m: '""' + '\n' * m.group(0).count('\n'), s, flags=re.S)
    def strrepl(m):
        interps = re.findall(r'\\\(([^"]*?)\)', m.group(0))
        return '"" ' + ' '.join('(' + i + ')' for i in interps)
    return re.sub(r'"(\\.|[^"\\\n])*"', strrepl, s)
code = {f: strip(s) for f, s in src.items()}

# collect type bodies (including extensions) -> members
members = collections.defaultdict(set)
kinds = {}
def bodies(s):
    for m in re.finditer(r'\b(class|struct|enum|extension|protocol|actor)\s+([A-Z]\w*)[^{\n]*\{', s):
        i = m.end(); depth = 1; j = i
        while j < len(s) and depth:
            c = s[j]
            if c == '{': depth += 1
            elif c == '}': depth -= 1
            j += 1
        yield m.group(1), m.group(2), s[i:j]
for f, s in code.items():
    for kind, name, body in bodies(s):
        if kind != 'extension': kinds[name] = kind
        for mm in re.finditer(r'\b(?:var|let|func|class|struct|enum|typealias)\s+`?([A-Za-z_]\w*)', body):
            members[name].add(mm.group(1))
        # multiple decls on one line: let a: X, b: Y  /  var a: X; var b: Y handled above; handle comma form
        for mm in re.finditer(r'\b(?:var|let)\s+([^\n=]+)', body):
            for part in re.split(r',\s*', mm.group(1)):
                nm = re.match(r'\s*([a-z_]\w*)\s*:', part)
                if nm: members[name].add(nm.group(1))
        for mm in re.finditer(r'\bcase\s+([^\n]+)', body):
            for part in re.split(r',\s*', mm.group(1)):
                nm = re.match(r'\s*([a-z_]\w*)', part)
                if nm: members[name].add(nm.group(1))
project_types = set(kinds)

# variable name -> set of project types, from explicit annotations
vartypes = collections.defaultdict(set)
alltext = '\n'.join(code.values())
for m in re.finditer(r'\b([a-z_]\w*)\s*:\s*(?:@escaping\s+)?\[?([A-Z]\w*)\]?[?!]?', alltext):
    name, t = m.groups()
    if t in project_types:
        # array annotation means the variable is a collection, skip unless not array
        seg = m.group(0)
        if '[' in seg: continue
        vartypes[name].add(t)
# also "let x = Type(" constructions
for m in re.finditer(r'\b(?:let|var)\s+([a-z_]\w*)\s*=\s*([A-Z]\w*)\(', alltext):
    name, t = m.groups()
    if t in project_types: vartypes[name].add(t)

common = {'rawValue','allCases','id','hashValue','self','description','init','modelContext','persistentModelID',
          'map','flatMap','isEmpty','count','first','last','filter','contains','sorted','reduce','compactMap','forEach','prefix','suffix',
          'body','wrappedValue','projectedValue','debugDescription','localizedDescription','errorDescription'}
problems = collections.defaultdict(list)
for f, s in code.items():
    for m in re.finditer(r'(?<![\w.$])([a-z_]\w*)\??\.([a-z_]\w*)', s):
        name, mem = m.groups()
        ts = vartypes.get(name)
        if not ts or len(ts) != 1: continue
        t = next(iter(ts))
        if kinds.get(t) == 'protocol': continue
        if mem in members[t] or mem in common: continue
        line = s.count('\n', 0, m.start()) + 1
        problems[(t, mem)].append(f"{f}:{line} ({name})")
print("== member accesses on a variable whose type is known, where the type lacks that member:", len(problems))
for (t, mem), locs in sorted(problems.items()):
    print(f"  {t}.{mem}: {', '.join(locs[:5])}{' ...' if len(locs) > 5 else ''}")
