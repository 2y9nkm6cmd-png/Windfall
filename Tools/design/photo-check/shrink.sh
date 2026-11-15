#!/bin/zsh
# Makes small copies (longest side 400) of every photo, for sending to the chat. Skips ones already made.
cd ~/Developer/windfall-photo-check
find photos -type f | while read f; do
  o="small/${f#photos/}"; o="${o%.*}.jpg"
  [ -s "$o" ] && continue
  mkdir -p "$(dirname "$o")"
  sips -Z 400 -s format jpeg -s formatOptions 70 "$f" --out "$o" >/dev/null 2>&1
done
