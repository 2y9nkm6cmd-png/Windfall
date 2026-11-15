# Linaria 'Fairy Bouquet Mixed', Country Value: what the packet says, and what the scanner made of it

The first real packet scanned with Windfall, by William on his iPad, 15 November 2026, 21:51, with build `60b6284`.
`back.jpg` is his photo of the back. `read-lines.txt` is what Vision read from it.

Everything in "The packet says" is printed on the packet. Nothing here was looked up.

| Field | The packet says | The scanner gave | Where it belongs |
|---|---|---|---|
| Plant | Linaria | **"PRICE"** (wrong) | `Plant.commonName` |
| Variety | Fairy Bouquet Mixed | nothing | `SeedPacket.variety`, `Plant.variety` |
| Latin name | Linaria (the genus only) | **"Great for"** (wrong) | `Plant.latinName` |
| Life cycle | Hardy annual | nothing | `Plant.hardiness` |
| Position | Sunny | nothing | `Plant.sunShade` |
| Soil | Well drained | nothing | `Plant.preferredSoilConditions` |
| Sow outdoors | March to May, August to September | **March, May, August, September** (April lost) | `Plant.sowOutdoorsMonthsText` |
| Germination | 14 to 21 days | nothing | `Plant.germinationDaysText` |
| Sowing depth | "Cover lightly with fine soil" (no number) | nothing | `Plant.sowingDepthMM`, as words |
| Row spacing | 20 cm | 20 cm as "Spacing" | a note, or spacing between rows |
| Thin to | 15 cm | nothing | `Plant.spacingM` (plant to plant) |
| Successions | 2 to 3 sowings | nothing | a note |
| Flowering | June to October | **given as "Sowing time"** (wrong field) | `Plant.floweringMonthsText` |
| Sow by | December 2028 | nothing | `SeedPacket.useByDate`, `packetYear` |
| Supplier | Country Value, Newmarket | nothing | `SeedPacket.supplier` |
| Barcode | 5 010931 212569 | nothing | a note, or a field of its own |
| Seed count | not printed on the back | nothing | `SeedPacket.quantityRemaining` |

## Why each went wrong (read from `SeedPacketScanner.extract`, build 60b6284)

1. **Lines, not sentences.** Vision gives a line at a time. "Seedlings appear" and "14-21 days" are two lines, so the germination rule never saw them together. "Sow by" and "DEC 2028" likewise.
2. **"sow" matches "sowings".** "Late sowings flower the following year" was taken as a sowing time.
3. **Two ranges in one line.** `MonthParser.dashRange` gives up when " to " appears twice ("March to May and August to September") and falls back to the names it can see, losing April.
4. **The Latin name rule** is any capital word of four letters or more followed by a lower-case word, so "Great for" matched. "Linaria Fairy Bouquet Mixed" did not, because "Fairy" has a capital.
5. **The plant name guess** takes the first short line in the first four. It never looks at the size of the text, and the name is the largest text on the packet.
6. **No rule at all** for variety, hardy annual, sun, soil, thinning, successions, flowering, supplier or barcode.
7. **The section headings** (SOW, CARE, FLOWERS, TIP) say what each block is about, and are not used.
