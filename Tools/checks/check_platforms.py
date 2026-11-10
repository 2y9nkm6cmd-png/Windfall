import re, sys, os
d = sys.argv[1]
ios_only = ['AVAudioSession','UIImpactFeedbackGenerator','UINotificationFeedbackGenerator','UIApplication','UIImage','UIGraphicsImageRenderer','UIViewController','UIWindowScene','UIDevice','UIScreen','UIColor',
            'navigationBarTitleDisplayMode','keyboardType','textInputAutocapitalization','insetGrouped','fullScreenCover','navigationBarTrailing','navigationBarLeading','topBarTrailing','topBarLeading','bottomBar',
            'isIdleTimerDisabled','EditButton','pickerStyle(.wheel)','navigationBarHidden','navigationBarItems','autocapitalization(','import UIKit','statusBarHidden','.decimalPad','.numberPad','jpegData','UIPasteboard','listStyle(.grouped)']
mac_only = ['NSImage','NSApplication','NSWindow','NSBitmapImageRep','import AppKit','NSPasteboard','NSColor','NSWorkspace','lockFocus','tiffRepresentation']
n = 0
for f in sorted(os.listdir(d)):
    if not f.endswith('.swift'): continue
    stack = []  # each entry: current branch condition string
    for i, line in enumerate(open(os.path.join(d, f), encoding='utf-8'), 1):
        t = line.strip()
        if t.startswith('#if'): stack.append(t[3:].strip()); continue
        if t.startswith('#elseif'): stack[-1] = t[7:].strip(); continue
        if t.startswith('#else'): stack[-1] = 'NOT(' + stack[-1] + ')'; continue
        if t.startswith('#endif'): stack.pop(); continue
        code = re.sub(r'//.*', '', line)
        ctx = ' && '.join(stack)
        in_ios = any(('os(iOS)' in c and not c.startswith('NOT')) or 'canImport(UIKit)' in c or c == 'NOT(os(macOS))' for c in stack)
        in_mac = any(('os(macOS)' in c and not c.startswith('NOT')) or 'canImport(AppKit)' in c or c == 'NOT(os(iOS))' for c in stack)
        for sym in ios_only:
            if sym in code and not in_ios:
                n += 1; print(f"  iOS-only outside #if os(iOS): {f}:{i}: {sym}   [{ctx}]")
        for sym in mac_only:
            if sym in code and not in_mac:
                n += 1; print(f"  macOS-only outside #if os(macOS): {f}:{i}: {sym}   [{ctx}]")
print("platform problems:", n)
