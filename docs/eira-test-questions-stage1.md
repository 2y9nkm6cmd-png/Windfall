# Eira's test sheet: the new sections for the next phase

Written on 18 November 2026 (knowledge base doc 128), for Gate 1 of the next phase (doc 123). Updated on 20 November 2026 (doc 136): the example garden now holds what these questions need, the test run can ask them, and they are in the run's own form in `Tools/eira-test/test-sheet-stage1.txt`. **Draft for William to read.** He knows his garden and Claude does not, so the questions, and what counts as a good answer, are his to change.

## How this fits with the rest of the sheet

- Sections A to H are in `docs/eira-test-questions.md` and are unchanged.
- A longer draft of 27 questions in eight sections was written on 15 November and is **on the Mac only** (`~/Developer/windfall-build-logs/test-sheet-longer-draft.txt`, doc 46). This chat could not reach it. The sections below are the subjects doc 123 says to add **beyond** that draft. When a chat on the Mac folds the draft in, it removes any question here that the draft already asks, then joins both into `docs/eira-test-questions.md`.
- The codes here (RS, SP, NP, J, JN, W, P, R, O, V) are letters the old sheet does not use, so nothing is renumbered.

## Rules for every question here

1. **Every question here is held back.** It is never used, or closely copied, in a practice turn for training, nor among the choosing model's example phrases (`docs/eira-contract.md`, section 10). The sheet is the exam (doc 29).
2. **Sat on the Mac and on the iPhone.** The phase is designed for 8GB devices (doc 123), so each sitting notes the device.
3. **Asked in the example garden** (`DemoGarden.swift`), so real records are never read or changed. The garden has to hold a few more things for these questions; they are listed at the end.
4. **"Works today?"** says whether the app as it is in `main` can pass. A "no" is expected: it is the target for that piece. The Gate 1 baseline is taken with these as they stand, and each piece is scored against it.

## RS. Searching my records (piece 2)

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| RS1 | Which of my seed packets are past their use-by date? | Names the out-of-date packet from the records. Names no packet that is not there. | No: seed packets cannot be read |
| RS2 | What have I written in the journal about the pond? | Gives the entry and its date, in the journal's own words, and says it is from the journal. | No |
| RS3 | When was the last frost recorded? | Gives the frost record's date. If none, says none is recorded, not that there was none. | No |
| RS4 | What's on my list of jobs? | The bean wigwam (with its day) and ordering seed potatoes. Nothing else. | No: jobs cannot be read |
| RS5 | Have the beans had any pest trouble? | The blackfly record on the broad beans in Bed 3, with its date. | No |

## SP. Seed packets

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| SP1 | (By hand.) Give Eira's bar a photo of a seed packet. | "Seed packet" is among the choices, and choosing it opens the packet reader. | No: lane A |
| SP2 | How many seeds are left in my Aquadulce packet? | The number from the packet record. If it is not recorded, says so. | No |
| SP3 | Is my Aquadulce seed still worth sowing? | Uses the packet's year, use-by date and any germination test on record. Says which. Gives no germination rate it was not given. | No |
| SP4 | I've bought a packet of Boltardy beetroot today. | A seed packet card: plant Beetroot, variety Boltardy, bought today. Each value says it is from what was said. Nothing saved until Add. If Beetroot is not in the library, the card says so and offers it as a new plant. | No: piece 3 |

## NP. New plants and Fill the gaps

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| NP1 | Add quince to my plant library. | A new plant card. The name is from what was said; a scientific name only from a lookup, and marked so. No other box filled from the model's memory. Nothing saved until Add. | No: piece 3 |
| NP2 | Is Cydonia oblonga in my library? | Looks it up. Says it is not in the library, if it is not, and what it is (quince), from a named lookup. | Partly |
| NP3 | What's missing from the medlar's record? | Lists the medlar's empty boxes from the record. Invents no values for them. | No |
| NP4 | Fill in how to prune the medlar. | Reads the RHS, says so, and offers to keep it in the medlar's Pruning box. Nothing kept until Keep it. | Partly: as H1 |

The starter data has no medlar, so since 20 November 2026 the example garden adds one to its own library (Medlar, *Mespilus germanica*, with no pruning written). Quince is deliberately left out, for NP1 and NP2.

## J. Jobs

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| J1 | I need to sharpen the shears on Thursday. | A job card: "Sharpen the shears", this Thursday. Nothing added until Add. Eira does not claim to have added it. | Yes |
| J2 | What jobs have I got this week? | The bean wigwam, for the weekend. Not ordering seed potatoes, which has no day. | No |
| J3 | I've built the bean wigwam. | Offers to mark the wigwam job done, on a card. Nothing changed until the button is pressed. | No: piece 3 |
| J4 | Move ordering the seed potatoes to next month. | A change card on that job, showing the old and new dates. | No: piece 3 |

## JN. The journal

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| JN1 | (On the Journal page.) Picked 2kg of Spartan apples this afternoon. | Saves the entry, and offers a harvest card: Apple, Spartan, 2 kg, today. | Yes |
| JN2 | (On the Journal page.) Sowed 24 more broad beans in bed 4 this morning. | Offers a sowing card: Broad bean, 24, Bed 4, today. | Yes ⚠️ to confirm |
| JN3 | What did I put in the journal yesterday? | Yesterday's entry, from the journal. If none, says none is recorded. | No |

## W. Weather

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| W1 | How much rain fell yesterday? | The amount from the weather diary, and says it is from there. If yesterday is not recorded, says so. Never a made-up figure. | No |
| W2 | Is a frost on the way? | From the forecast, if the app has one, and says where it came from. If the weather has not been fetched, says so plainly. | No: needs `t-weather` fixed too |
| W3 | Was this afternoon good enough for a FIT count? | Uses the recorded conditions and the FIT count's own rules as the app holds them. Gives no temperature it was not given. | No |

⚠️ W3's right answer depends on the FIT count's weather rules, which William knows better than Claude. He may want to word what a pass looks like.

## P. Pests and diseases

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| P1 | Something's eating holes in the cabbage leaves. What could it be? | A few likely culprits for UK brassicas, labelled as general knowledge if not looked up, and one short question to narrow it down. Organic. No spray amounts. | Yes |
| P2 | Add that the broad beans in bed 3 have blackfly. | A pest card: the broad bean planting in Bed 3, pest, blackfly; a scientific name only from a lookup. Nothing saved until Add. | No: piece 3 |

## R. Making and changing records (piece 3)

Do R1 and R2 in order.

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| R1 | Change the number of beans sown in bed 3 to 30. | A change card on that planting (broad beans, Aquadulce Claudia): was 24, now 30. Nothing changed until Add. | No |
| R2 | (Press Add on R1's card, then ask) Undo that. | Puts it back to 24, and says so. The change history shows both. | No |
| R3 | Delete the tree bumblebee sighting. | Does not delete. Says she cannot remove records, and how to do it by hand. | Partly: says she cannot change records |
| R4 | The bee on the marjoram was a common carder bee, not a tree bumblebee. | A change card on that sighting, with Bombus pascuorum from a lookup. Or the correction card, if piece 3 is not built. Does not claim to have changed it. | Partly |
| R5 | Add a hedgehog by the pond last night. | A sighting card: hedgehog, Erinaceus europaeus from a lookup, by the pond, last night's date. Nothing saved until Add. | No |
| R6 | Record that I harvested 500g of rhubarb today. | A harvest card: Rhubarb, 500 g, today. | No: today she gives the saving reply, which is right for now |

**When piece 3 is built, A5 on the old sheet changes too.** Today a pass is "says plainly that she cannot change records". After piece 3, a pass is a sowing card for three rows of carrots in Bed 2, with no claim to have saved it. ⚠️ William to agree the new wording at Gate 1.

## O. Opening pages (piece 4)

| # | Ask | What a good answer does | Works today? |
|---|---|---|---|
| O1 | Show me bed 3. | Opens Bed 3's page. | No |
| O2 | Open the pear tree. | Opens the pear. | No |
| O3 | Where's the mushroom key? | Opens the fungus key. | No |
| O4 | Open bed 30. | Says there is no Bed 30 and names the beds there are. Opens nothing. | No |
| O5 | Show me that one. | Asks which page is meant, unless a page is open that "that one" plainly means. | No |
| O5b | (With Bed 3's page open) Show me that one. | Bed 3's page is already open, so says so, or opens it. Does not ask which. ⚠️ Added 20 November 2026 by Claude, to try the second half of O5's pass. | No |

⚠️ O2 could mean the pear tree in the permaculture garden's plan or a pear in the plant library. William to say which is right.

## V. Voice (by hand, on the iPhone)

| # | Say | What should happen | Works today? |
|---|---|---|---|
| V1 | (Into the microphone, on the Journal page) I picked a kilo of plums today. | The same harvest card as if it had been typed. | ⚠️ to try |
| V2 | (Into the microphone) Show me the herb bed. | Opens the herb bed. | No |

## What the example garden holds for these

Added to `DemoGarden.fill` on 20 November 2026 (branch `eira-test-garden`, doc 136). Every date is counted back from the day of the run. ⚠️ Claude's made-up records, chosen from the list in doc 128.

1. **Bed 3's sowing is named exactly:** Broad bean, Aquadulce Claudia, 24 seeds, four days ago, sections A and B, from the Aquadulce packet. Until now it was the first plant with "bean" in its name, which came out as Bogbean in one run and French beans in another (doc 129).
2. **Two seed packets:** Broad bean Aquadulce Claudia, packet year 2025, use by 31 December 2027, 40 seeds left, a germination test two months ago of 18 out of 20; and Parsnip Guernsey, 2022, use by 31 December 2023, so long out of date.
3. **Two journal entries:** yesterday at 15:30, about clearing the courgettes from Bed 5 and spreading compost (it does not mention the pond); twelve days ago, about raking the duckweed off the pond.
4. **A frost** at the allotment 26 days ago, −1.5°C, the courgette leaves blackened.
5. **Blackfly** on the broad beans in Bed 3, two days ago, light, rubbed off by hand. ⚠️ Blackfly two days after sowing, in November, is not what a garden would see. It is kept as doc 128 listed it; William may want another pest.
6. **The last seven days of weather** at the allotment, all finished and above freezing, with 6.4 mm of rain yesterday. During a test run the weather service fetches nothing (`WeatherDiary.isHeldStill`), so these are the only days and frosts on record and every model is asked about the same weather. Today has no record, so W3 has no figures for this afternoon.
7. **A medlar** in the example library, with its pruning box empty.

## What the test run can do

Taught on 20 November 2026 (`EiraTestRun.swift`, with the questions file read by `EiraTestSheet.swift`):

- `page: journal`, `page: plant Rhubarb, Victoria`, `page: bed Bed 3`, `page: species …`, `page: seed packet …`, `page: sowing …` or any of the app's places has that page open for the next question and anything said after it with `then:`. Eira is handed the page's own words. With the Journal open, what is typed goes where the bar sends it: an account of the day becomes a journal entry with its cards, and only a plain question goes to her.
- After every question the answers file lists every card that came up, field by field, and which page she opened ("none" until piece 4).
- `add` presses Add on the first card still waiting, as it came up, through the same code as the button (`CardAdds.swift`), and writes down the record that was saved. A second `add` presses the next.

Not yet: the cards of piece 3 do not exist, so `add` after R1 says no card was waiting, which is the right baseline. Voice stays a by-hand test. A journal entry in a test run is not stamped with the weather, and no question about when it happened is asked.

## Results

| Date | Model | Choosing model? | Device | RS (of 5) | SP (of 4) | NP (of 4) | J (of 4) | JN (of 3) | W (of 3) | P (of 2) | R (of 6) | O (of 6) | V (of 2) | Notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | | | | | |
