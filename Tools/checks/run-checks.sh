#!/bin/bash
# Checks the Windfall source without a Mac.
#
# What it can do:
#   1. Syntax-check every Swift file with the real Swift parser.
#   2. Fully type-check the files listed in logic-files.txt (records,
#      sync, backup, export, weather, Eira's tools and chat logic), with
#      screens removed and small stand-ins for Apple-only types.
#   3. Run cross-file checks: every record type is in the schema, no
#      screen uses a property a record lacks, and iPhone-only or Mac-only
#      code is fenced off for the right platform.
#   4. Run the logic tests in LogicTests.swift, which exercise the
#      conversation, memory management, web lookup, the 12GB rule and
#      the grid reference conversion with a stand-in for the model.
#
# What it cannot do: build the app. Screens and anything that needs
# SwiftUI, SwiftData's own behaviour or other Apple-only frameworks are
# only syntax-checked here. The real test is a build in Xcode.
#
# Usage:  Tools/checks/run-checks.sh /path/to/swift/usr/bin
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"; SRC="$ROOT/Windfall"
SWIFT_BIN="${1:-$(dirname "$(command -v swiftc)")}"
WORK="$(mktemp -d)"; status=0

echo "1. Syntax check"
fail=0
for f in "$SRC"/*.swift; do
  out="$("$SWIFT_BIN/swiftc" -frontend -parse "$f" 2>&1)"
  if [ -n "$out" ]; then fail=$((fail+1)); echo "$out" | head -5; fi
done
echo "   files checked: $(ls "$SRC"/*.swift | wc -l), with problems: $fail"; [ "$fail" -eq 0 ] || status=1

echo "2. Type check of the logic files"
python3 -I "$HERE/make_harness.py" "$SRC" "$WORK/harness" $(cat "$HERE/logic-files.txt")
( cd "$WORK/harness" && "$SWIFT_BIN/swiftc" -typecheck -swift-version 5 *.swift ) > "$WORK/typecheck.txt" 2>&1
rc=$?; grep -E "error:|warning:" "$WORK/typecheck.txt" | grep -v "^ " | head -20
echo "   result: $([ $rc -eq 0 ] && echo passed || echo FAILED)"; [ $rc -eq 0 ] || status=1

echo "3. Cross-file checks"
python3 -I "$HERE/check_schema.py" "$SRC" | grep -E "@Model classes|models missing|schema entries with no" | sed 's/^== /   /'
# The member check guesses a variable's type from its name, so a few
# names used for two different things raise false alarms. Those are
# listed in known-false-alarms.txt and hidden here. Anything printed
# below is new and worth a look.
new_alarms="$(python3 -I "$HERE/check_members.py" "$SRC" | tail -n +2 | grep -v -F -f "$HERE/known-false-alarms.txt")"
if [ -n "$new_alarms" ]; then echo "   properties used but not defined:"; echo "$new_alarms"; status=1
else echo "   properties used but not defined: none"; fi
python3 -I "$HERE/check_platforms.py" "$SRC" | tail -3
echo "4. Logic tests"
cp "$HERE/LogicTests.swift" "$WORK/harness/"
( cd "$WORK/harness" && "$SWIFT_BIN/swiftc" -swift-version 5 -parse-as-library *.swift -o logictests ) > "$WORK/build.txt" 2>&1
if [ -x "$WORK/harness/logictests" ]; then
  WINDFALL_STARTER="$SRC/StarterData.json" LD_LIBRARY_PATH="$SWIFT_BIN/../lib/swift/linux:${LD_LIBRARY_PATH:-}" "$WORK/harness/logictests" || status=1
else
  echo "   the tests did not build:"; grep -E "error:" "$WORK/build.txt" | grep -v "^ " | head -10; status=1
fi
rm -rf "$WORK"; exit $status
