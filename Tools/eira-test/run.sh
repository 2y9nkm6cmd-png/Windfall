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
# it runs and closes itself at the end.
APP="/Users/Home/Library/Developer/Xcode/DerivedData/Windfall-claude/Build/Products/Debug/Windfall.app/Contents/MacOS/Windfall"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="/Users/Home/Developer/windfall-build-logs"
SHEET="${4:-$HERE/test-sheet.txt}"
MODEL=()
[ "$2" != "-" ] && MODEL=(-eiraModelValue "$2")
"$APP" -demoGarden -eiraTest "$SHEET" -eiraTestOut "$OUT/eira-$3.md" \
  -eiraModelKind "$1" $MODEL > "$OUT/eira-$3.log" 2>&1
echo "EXIT $?" >> "$OUT/eira-$3.log"
