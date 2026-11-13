#!/bin/zsh
# Puts Eira's test sheet to one model and writes her answers to a file.
#
# Usage:  run.sh <kind> <model> <name> [questions file]
#   kind   appleBuiltIn, coreAI or mlx
#   model  the model's folder name in Windfall's Models folder ("-" for Apple's)
#   name   what to call the answers file: eira-<name>.md
#
# It starts the Mac app Xcode last built, with the example garden, so
# real records are never read or changed. The app's window appears while
# it runs and closes itself at the end. The answers file ends with the
# word DONE when the run is over.
APP="/Users/Home/Library/Developer/Xcode/DerivedData/Windfall-claude/Build/Products/Debug/Windfall.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/Users/Home/Developer/windfall-build-logs"
SHEET="${4:-$HERE/test-sheet.txt}"
MODEL=()
[ "$2" != "-" ] && MODEL=(-eiraModelValue "$2")
rm -f "$OUT/eira-$3.md" "$OUT/eira-$3.log"
# Two things here were learned the hard way on 13 November 2026.
#
# 1. Every word after a dash is followed by a value, "-demoGarden YES"
#    included. A Mac reads a file path that is not paired with a dashed
#    word as a document to open, and then never opens the app's window,
#    so the run would never start.
#
# 2. The app is started with "open", not by running the program inside
#    it. "open" asks the Mac itself to start the app, so the app does not
#    belong to whatever ran this script. Started the other way from a
#    Claude chat, the run was killed part-way when the Claude app
#    restarted, because everything a chat starts directly is stopped
#    along with it.
open -n -a "$APP" --stdout "$OUT/eira-$3.log" --stderr "$OUT/eira-$3.log" --args \
  -demoGarden YES -eiraTest "$SHEET" -eiraTestOut "$OUT/eira-$3.md" \
  -eiraModelKind "$1" $MODEL
echo "Started. Watch $OUT/eira-$3.md for DONE."
