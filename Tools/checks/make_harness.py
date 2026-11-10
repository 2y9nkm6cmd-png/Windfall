import re, sys, os
srcdir, outdir = sys.argv[1], sys.argv[2]
names = sys.argv[3:]
os.makedirs(outdir, exist_ok=True)
def strip_blocks(s, pattern):
    out = []; pos = 0
    for m in re.finditer(pattern, s, flags=re.M):
        if m.start() < pos: continue
        i = s.index('{', m.start()) + 1; depth = 1
        # naive brace matching that skips string literals
        j = i; instr = False
        while j < len(s) and depth:
            c = s[j]
            if c == '"' and s[j-1] != '\\': instr = not instr
            elif not instr:
                if c == '{': depth += 1
                elif c == '}': depth -= 1
            j += 1
        out.append(s[pos:m.start()]); out.append('\n' * s.count('\n', m.start(), j)); pos = j
    out.append(s[pos:]); return ''.join(out)
for n in names:
    s = open(os.path.join(srcdir, n), encoding='utf-8').read()
    s = re.sub(r'^import (SwiftData|CoreLocation|NaturalLanguage|SwiftUI|UniformTypeIdentifiers|PhotosUI|Charts)[ \t]*$', '', s, flags=re.M)
    s = re.sub(r'^[ \t]*@Model[ \t]*$', '', s, flags=re.M)
    s = re.sub(r'@Relationship\((?:[^()]|\([^()]*\))*\)\s*', '', s)
    s = re.sub(r'@Attribute\((?:[^()]|\([^()]*\))*\)\s*', '', s)
    s = strip_blocks(s, r'^(?:private |fileprivate )?struct \w+\s*:\s*View\b[^{\n]*\{')
    s = strip_blocks(s, r'^#Preview\b[^{\n]*\{')
    s = "#if canImport(FoundationNetworking)\nimport FoundationNetworking\n#endif\n" + s if 'URLSession' in s else s
    s = s.replace('try await URLSession.shared.bytes(for: request)', 'try await __bytes(request)')
    if not __import__('re').search(r'^import Foundation', s, flags=__import__('re').M): s = 'import Foundation\n' + s
    if '@Observable' in s and 'import Observation' not in s: s = 'import Observation\n' + s
    open(os.path.join(outdir, n), 'w', encoding='utf-8').write(s)
open(os.path.join(outdir, '_Stubs.swift'), 'w').write(open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), 'LinuxStubs.swift')).read())
