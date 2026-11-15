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

## What the new reader gives (15 November 2026, 22:26, branch `packet-reader-rules`)

The rules were moved into `Windfall/PacketReading.swift` and rewritten. `read-lines.txt` is now a logic test (`Tools/checks/LogicTests.swift`): these are the values it must keep giving. **15 findings where the old scanner gave 4.** Not yet tried on a device: the test uses the lines copied by hand, which have no sizes or places.

| Field | The packet says | The new reader gives | Written to the record as |
|---|---|---|---|
| Plant | Linaria | Linaria (low confidence: no plant of William's is named, so it is the first word of the title line) | the "Which plant?" box |
| Variety | Fairy Bouquet Mixed | Fairy Bouquet Mixed | `SeedPacket.variety`, and `Plant.variety` for a new plant |
| Latin name | Linaria (the genus only) | **nothing.** The packet prints no Latin name apart from the plant's name, and the reader does not know that Linaria is a genus | |
| Life cycle | Hardy annual | Hardy annual | `Plant.classification` (the library's Classification column already says "Hardy annual"; `hardiness` holds RHS ratings such as H6) |
| Position | Sunny | Full sun (the words the web fill-in uses for "sunny position") | `Plant.sunShade` |
| Soil | Well drained | Well drained | `Plant.preferredSoilConditions` |
| Sow outdoors | March to May, August to September | March, April, May, August and September | `mar apr may aug sep` |
| Germination | 14 to 21 days | 14-21 days | `14-21 days` |
| Sowing depth | "Cover lightly with fine soil" | Cover lightly | the words |
| Row spacing | 20 cm | 20 cm | the packet's note |
| Thin to | 15 cm | 15 cm | `0.15` (metres) |
| Successions | 2 to 3 sowings | "Make 2-3 sowings for successive flowering." | the packet's note |
| Flowering | June to October | June, July, August, September and October | `jun jul aug sep oct` |
| Sow by | December 2028 | December 2028 | `useByDate` 31 December 2028, `packetYear` 2028 |
| Supplier | Country Value | Country Value | `SeedPacket.supplier` |
| Barcode | 5 010931 212569 | 5010931212569 (its check digit is right) | the packet's note |
| Seed count | not printed | nothing | |

Not read: the supplier's address (Newmarket, Suffolk, CB8 7QB), and the TIP.
