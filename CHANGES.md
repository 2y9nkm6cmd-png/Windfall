# 13 November 2026, afternoon: This week, the sheets, the sliding switch and the sidebar

**On the `today-rearrange` branch**, after the morning's work below.
**None of it has been built on the Mac or seen running.** William was
at school and the Mac could not be reached. It passes the checks that
run without the Mac (every file reads as valid Swift, 323 logic tests
pass). Those do not build the screens. Expect things to put right when
it is first built, and treat how everything here looks as untried.

## 14 November 2026, midday: giving Eira a photo

**On the branch `photo-drop`, made from `main` (`98fd66c`), in its own copy of the code at `~/Developer/windfall-photo-drop`,** because another chat was working in the main copy. Built for the Mac and the simulator as `pd4`, with no errors. 471 logic tests pass (14 new). Seen in the simulator as still pictures (`shots/pd-*.png`). **Nothing has been dragged by hand.** A drag cannot be made from a script, so the drop itself, the "+" menu and the photo folder are William's to try.

**Why.** William, with a picture of three photos held over the Journal page: "the journal part of windfall doesn't let you just drag photos over to it to start an entry. Also on the journal page Eira appears twice". Then: "eira has a photo button on it so that you can start with uploading a photo", and "Store the photos on icloud for now until we get cloudkit up and running."

**What changed.**

1. **A photo's own date and place are read** (new file `PhotoFacts.swift`).
   - A camera writes notes into each photo's file (EXIF): when the shutter was pressed and, on a phone, where. `PhotoFacts.read(from:)` opens the file with ImageIO, Apple's reader for picture files, and pulls those out. The picture itself is not decoded, so it is quick.
   - The camera writes a date as "2026:11:11 14:02:33", with its distance from Greenwich beside it ("+01:00") on a phone. `PhotoFacts.date(written:offset:zone:)` turns that into a date. A date before 1990 is refused: it is what a camera whose clock was never set writes.
   - A position is kept only whole, and nought north, nought east is refused as an unset GPS.
   - A screenshot or a picture saved from the web has no such notes. Nothing is guessed for it.
   - The first half of the file needs nothing from Apple, so it is in `logic-files.txt` and tested.

2. **Eira asks which day an entry with photos is about** (`JournalChat.photoCheck`, and the card in `JournalChatView.swift`).
   - *The rule.* Photos from the last hour ask nothing. Otherwise each day with photos is offered, newest first, at the time of that day's last photo, then "Now". A photo dated in the future is ignored. No more than four days.
   - *The card is the time check's card.* `checkCard` used to be drawn from the words' question only. It is now drawn from a question and a list of choices (`CheckChoice`), so the photos' question and the "this morning" question look and work alike. The photos' question is put first where both arise: it is the firmer evidence.
   - *The photo keeps its own time* (`Photo.capturedAt`) whichever time the entry is stamped with. Its place goes into `Photo.latitude` and `longitude`, which were there and unused.

3. **Photos can be dragged in at three places**, all read by one function (new file `PhotoDrop.swift`).
   - The Journal page: a dashed outline says "Drop to start a journal entry" and the journal's conversation opens with the photos in its box.
   - Eira's bar, on any page.
   - The Identify screen: Eira looks at the photo at once.
   - *How a drop arrives.* SwiftUI hands over an "item provider" for each thing dropped, a promise to supply it a moment later. A photo dragged from Finder arrives as the file's address, one from Photos as the picture. `PhotoDrop.pictures(from:)` tries the file first, which gives the photo exactly as the camera saved it, notes and all. The journal's own sheet took drops before, but only as pictures, so a file from Finder may not have worked there. It now uses the same reader.

4. **Eira's bar has a "+" beside her snowdrop** (`EiraFloatingBar.swift`): "From Photos" or "From a file". **Taking a photo with the camera is not built**: the app has no camera code or permission yet.

5. **The Journal page has one Eira, not two.** Its own "Tell Eira what happened in the garden" bar at the top is gone. On that page Eira's bar at the foot is always open, carries those words (on an iPhone, where there is room for two words, "Tell Eira"), and has a book button at its right-hand end that opens the journal's conversation. A screen says it is the journal with `eiraLooksAt(..., isJournal: true)`.
   - *What is typed there is an entry unless it plainly asks* (`JournalChat.readsAsAsking`, tested): a question mark, an asking word ("when", "show", "wonder") or one word alone goes to Eira or to search. Everywhere else the old, cautious rule stands (`readsAsTelling`).
   - On an iPhone's Journal page the search button gives way to make room. Return still searches or asks.

6. **Away from the Journal page, Eira asks what to do with a photo** (new file `PhotoOffer.swift`): **What is this?** (the Identify screen, which looks at once), **Journal entry** or **Sighting** (a new sighting with the photos attached, dated when the earliest was taken). The card and the three things it leads to share one sheet. Nothing is saved by choosing.

7. **A sighting started from the Identify screen is dated when its photo was taken**, and the screen says so under the photo.

8. **Originals can be kept in a folder in iCloud Drive** (new file `PhotoStore.swift`, and a "Photos" section in Settings).
   - Choose a folder in Settings. From then on the original of each new photo is written there as a file, in a folder for each year, named with the time it was taken and the first eight characters of its record's label: `2026/2026-11-11 14.02.33 3F2A9C1E.heic`. The app keeps a copy no more than 2048 points on its longer side, and the small one for lists.
   - *Why a folder you choose.* Choosing it yourself is what gives the app permission to write there, on a Mac, an iPad or an iPhone, with no paid Apple developer membership. The app remembers it with a "bookmark".
   - *Nothing new is stored in a photo's record.* The file is found again from the record's own time and label. So the database is unchanged, and `migrate-test.sh` was not needed.
   - With no folder chosen, everything is as before. Nothing is written while the example garden is showing.
   - **Not done:** moving photos already in the app out to the folder, showing an original at full size, and fetching one that iCloud has not downloaded.

**Every place that keeps a new photo now goes through `Photo.record(of:)`** (in `PhotoDrop.swift`): the journal's conversation, the Identify screen and the new sighting offer. Two older places still make a photo by hand and do not read its date or use the folder: the old diary form (`JournalViews.swift`) and the sighting form's own photo button (`ObservationViews.swift`).

**Checking aids** (with `-demoGarden`): `-demoPhoto /path/to/photo.jpg` hands that photo to whatever `-demoOpen` opens. `-demoOpen journal` shows it waiting in the conversation with the day question, `-demoOpen identify` on the Identify screen, and the new `-demoOpen photo` opens the card of three offers. Two test photos with dates written in are in `windfall-build-logs/photo-drop-test`.

**To check by hand.** ⚠️ CHECK each of these on the Mac:
- Dragging photos from Finder and from Photos on to the Journal page, Eira's bar and the Identify screen.
- That a HEIC photo from an iPhone gives its date (the reader was tried on JPEG test photos).
- The "+" menu's look on the Mac. It has only been seen on an iPad.
- The Photos section in Settings and choosing a folder. It builds and has not been seen.
- Whether photos chosen "From Photos" keep their date. Apple's chooser may hand over a copy without the camera's notes.

## 14 November 2026, late morning: telling Eira she is wrong

**On the branch `eira-corrections`, made from `main`.** Built for the Mac and the simulator as r23, with no errors. 457 logic tests pass. Seen in the simulator in light and dark (`shots/corr-*.png` on the Mac). **Not yet tried by hand with a real model.**

**Why.** William asked: "I assume if it makes mistakes and I tell it that, then it will update the notes it keeps to improve in the future?" It did not. A correction was kept only if he pressed and held a reply and chose "Correct this", which nobody would find. Typing "No, that's wrong" was answered and then forgotten. And there was nowhere to read the corrections already kept, or to take a wrong one back.

**What a correction is.** A note, not training. The model's own numbers never change. The ten newest corrections are written into Eira's instructions at the start of every conversation, under "Corrections the gardener has given you. These are right even if you believe otherwise". All of them are kept, however many there are, so they can become practice turns if the model is trained again.

**What changed.**

1. **A typed correction brings up a card** (`EiraChecks.correctionWords`, `EiraConversation.send`, `CorrectionOfferCard` in `EiraChatView.swift`).
   - *The rule.* A message is read as a correction if it opens by disagreeing ("No, ...", "That's wrong", "Not quite", "Actually", "Correction:") or by naming the mistake ("That's not a Spartan, it's a Bramley", "You said ... but ..."), and goes on to state a fact of three words or more. It is plain code that looks for words. No model is asked.
   - *What is kept.* Where the opening is set apart by a comma or a full stop it is taken off: "No, that's wrong. It's a Bramley." offers "It's a Bramley." Where it is not, the whole message is offered, because "That is wrong for clay soil" would otherwise be kept as "for clay soil".
   - *What it leaves alone on purpose.* A question. "No thanks". "No dig beds are what I use" and "No slugs on the hostas this year", where "no" is the subject. "No, tell me about the other one", a request. Praise ("Actually that's really helpful"). A grumble about the app ("It's not working"). A plain "No" straight after Eira has asked a question, which is an answer to it. Anything over 240 characters, because the line read to the model would be cut off. The tests hold 35 examples in place, both ways.
   - *When unsure it offers nothing.* The button under every reply (below) is there for whatever the rule misses.
   - *Nothing is kept unless "Keep it" is pressed.* The words can be changed on the card first. Once kept, the card shrinks to a line with Undo. "No thanks", or simply sending the next message, takes the card away.
   - *How the code holds the offer.* `EiraConversation` has a new value, `offeredCorrection`, of a small type `OfferedCorrection`: which message of yours it sits under, which reply of hers it puts right, the words and, once kept, the saved record. `send` sets it, the screen draws a card when it is not nil, and the buttons call `keepOfferedCorrection(as:)`, `undoKeptCorrection()` and `dismissOfferedCorrection()`.
   - *Safety.* A message about eating fungi, preserving times, pesticide amounts or medicine gets its fixed reply as before and **is never offered as a correction**. `EiraSafety.fixedReply` was split so the chat can ask for those four on their own (`safetyReply`).
   - *The reply cannot pretend.* If the model answers a correction with "I've noted that", the rule that already removes false claims of saving now says where the correction really stands: "I have not kept that yet. Press "Keep it" on the card above", or, once kept, that it is kept and that the records themselves are unchanged (`EiraChecks.CorrectionStanding`).

2. **"Correct this" is a button under every reply** (`MessageView`). It is still in the press-and-hold menu too.

3. **The "Correct this" sheet is drawn like the rest of the app** (`EiraCorrectionView`). It was a standard `Form`. It is now a `SheetPage` with two `SheetCard`s and a `FieldBox`, the same pieces as the sowing form. It warns if what is typed is longer than the 240 characters read to the model.

4. **A new sheet, Corrections, in the chat's Options menu** (`EiraCorrectionsView`). Every correction, newest first, with the question it answered, when it was kept and a Remove button. From the eleventh on, each is marked "not read to her now". `@Query` reads the list from the database and keeps it current, so a removed card goes without the screen being told.

5. **Every line of a correction is read to the model** (`EiraCorrection.promptLine`, `EiraChatStore.oneLine`). Only the first line was, so a correction typed over two lines lost its second.

6. **One frame for every offer Eira makes.** The journal's "Add a harvest?" card frame (`OfferFrame` in `JournalOfferCards.swift`) was private to that file. It is now shared, with the filled button's title as a setting, so the correction card matches it.

7. **The chat keeps its newest thing in view.** The list now scrolls to a marker at its very end when a message, a piece of the reply or an offer card arrives. Before, it scrolled to the last message, which could leave a card below it out of sight.

**Checking aids.** `-demoOpen eira` opens the chat on an example exchange with the card showing. `-demoOpen corrections` also keeps two example corrections and opens the list. Both only work with the example garden, whose records live in memory.

**A second build script on the Mac.** `pull-side.sh` does what `pull.sh` does but builds the Mac app into its own folder (`DerivedData/Windfall-claude-side`). William had Windfall open with his real records when this was built, started from the usual folder, and a build into that folder would have replaced the app underneath him.

**Not done.** The rule only reads English openings it has been given, so it will miss corrections phrased another way. A correction is not yet shown anywhere outside the chat. The rest of the chat screen (the message bubbles, the settings and past conversations sheets) is still in the old look.

## 14 November 2026, morning: other chats' work brought into the main branch

**What happened.** On the evening of 13 November William asked other chats for four things, and each was committed on the Mac without being sent to GitHub:

| Commit | What | Asked of |
|---|---|---|
| `476540a` | The Plants page as glass cards under letters (`PlantLibraryCards.swift`, new) | the fine-tuning chat |
| `8fdca0b` | The Settings icon redrawn as an even eight-tooth gear | the settings icon chat ("Commit and relaunch the app") |
| `0fd5dfc` | The Today jiggle as a smooth side-to-side rock | the wiggle chat |
| `1b2c05f` | The journal asks the weather service for the stamp's hour, and the sidebar scrolls the way the Mac is set | another chat |

Two of them were committed straight onto the Mac's copy of `today-rearrange`. **The build chat's own script, `pull.sh`, then moved that copy back to what GitHub had, at 22:42, and they dropped out of the working copy.** Nothing was lost: a chat had already gathered all four on a local branch, `launch-13nov`. But from 22:42 anyone running the working copy from Xcode got the old gear back.

**What changed.**

- `launch-13nov` is merged into `today-rearrange` (`3b05ea5`). Git combined the two without a single clash. The checks pass on the result: 401 logic tests.
- One name in `PlantLibraryCards.swift` was changed (`runs` to `stretches`), only so that the cross-file checker does not confuse it with a function of the same name elsewhere.
- **`pull.sh` now refuses to move the Mac's copy if it holds commits GitHub does not have.** It prints them and stops. Before, it used `git checkout -B`, which means "make this branch match that one, whatever it held". That is the right tool only when nothing else writes to the copy, and on 13 November four chats did.

**The lesson**, now in doc 00: a chat that commits on the Mac sends its commits to GitHub straight away, or works in its own copy.

## 14 November 2026, morning: a warning under every photo match

**Why.** 300 unseen UK photos were run through the app with its new list of 776 names. It was right first time on 289 and said "not sure" for 10 of the 11 it got wrong. The eleventh was a photo of hemlock water-dropwort, one of the most poisonous plants in Britain, named as yellow iris at 87%. Hemlock itself was read as cow parsley or chervil, which the "not sure" level caught.

**What changed** (`SpeciesTable.swift`, `caveat`). The small print under every answer on the Identify screen now also says: never eat anything, or handle a plant that may be poisonous, on the strength of a match. One sentence, shown every time, whatever the plant.

**Not done.** A warning that appears only for plants with dangerous look-alikes would be better. It needs a checked list of those look-alikes. The fine-tuning chat has drafted one (`lookalikes.json`, doc 28) from memory, and it is not yet checked.

## 13 November 2026, late night: rules around the model

William asked how the models could be made cleverer, and chose two of the four ways offered: hand the model the facts when it is asked, and check its answer before he sees it. Both are done by fixed rules a person can read, with no model involved, so they help whichever model Eira uses. Each rule answers something a model got wrong on the test sheet that evening. `EiraChecks.swift` is new and holds most of it. 14 new logic tests, 401 in all.

**Before the model answers: a lookup the app runs itself.**

- *The mistake.* "What should I be sowing now?" Apple's model suggested parsnips in November. Qwen thought for four minutes and wrote nothing. Neither looked at the sowing months in the plant library.
- *The rule* (`EiraChecks.lookupFirst`). If a message is a question, mentions sowing and says "now", "this month", "this week", "today" or names the current month, the app runs a new lookup, `sowing_now`, and hands the result to the model with the question: "The app has already looked this up for you…". The model's job becomes reading a list out.
- *The lookup* (`ToolRunner.sowingNow` and `sowingText` in `EiraTools.swift`). It goes through the plant library, keeps the plants whose indoor or outdoor sowing months include this month, and writes them as two lists. At most 30 names each, with a count of the rest.
- *Why the model is not offered this lookup as one of its tools.* It already chooses among eight, and small models choose worse from a longer list. This one is only ever run by the rule.
- *How it joins the conversation* (`EiraConversation.send`). `forcedTool ?? EiraChecks.lookupFirst(for: trimmed)`. The `??` means "use the left side if there is one, otherwise the right": a lookup William forces by hand still comes first.

**A request to save something gets fixed wording** (`EiraSafety.asksToSaveARecord`, `savingReply`).

- *The mistake.* "I've added three rows of carrots to bed 2, can you save that?" Qwen answered "your sowing… is now recorded in the system". Nothing was.
- *The rule.* A message with a request ("can you", "please"…) and an act ("save that", "record it", "log this"…), or an act and a place ("add it to my journal"), never reaches the model. Eira says she has saved nothing, cannot from the chat, and how to record it in the journal.
- *What is let through on purpose.* "How do I save seed from peas?", "Can you put that another way?" and "Please note that I garden on clay" all still go to the model. The tests hold those in place.

**After the model answers: the reply is read by rule** (`EiraChecks.checked`, called from `EiraConversation.commitReply`). A reply William stops himself is left as it was.

1. *A claim to have saved is taken out* (`claimsToHaveSaved`, `withoutSaveClaims`). The reply is split into sentences. Any that says "now recorded", "I've saved", "I'll log", "has been added to your…" and the like is removed, and one plain line is added at the end: nothing has been saved. "You recorded a harvest on 9 November" is about William's own records and is left alone.
2. *A scientific name that no lookup supplied is flagged* (`uncheckedNames`). Qwen wrote "Marjoram (Origanum majoricum)" from memory, and it is probably the wrong name. The rule finds two-word names in italics or brackets and looks for each in the question, the lookups' results, the garden notes and the corrections. Any found in none gets a line at the end: "Not checked: the name … came from the model's memory, not from a lookup." It is a flag and not a correction: the name may be right.
3. *An empty reply is said to be empty.* Twice Qwen thought and then wrote nothing, and the chat showed nothing. It now says so and suggests asking again.

**What these do not do.** They do not make a model know more. They stop three kinds of mistake reaching William and put one kind of fact in front of the model. More rules of both kinds can follow the same pattern, each with its tests.

## 13 November 2026, night: Eira's bed lookup

**What was wrong.** Asked "What's growing in Bed 3?", Qwen3 8B looked up the bed as "3". The lookup only knew a bed by its exact name, so it answered "Nothing growing in 3 at the moment", and Qwen told William the bed was empty. French beans were in it. Apple's model happened to send "Bed 3" and got it right.

**What changed** (`EiraTools.swift`).

- `ToolRunner.bedMatches(asked:name:)` decides whether what a model wrote means a given bed. Both names are put in lower case, punctuation is dropped, a leading "bed" is taken off and number words become digits. So "3", "bed 3", "bed three" and "Bed 3." all find Bed 3, and none finds Bed 30.
- If the name matches no bed at all, the lookup now says so and lists the beds there are. "No such bed" and "an empty bed" are different facts, and the model was being given the second when the first was true.

**Why fix the lookup and not blame the model.** Any small model will phrase things loosely. A lookup that forgives that helps every model, including Apple's.

## 13 November 2026, night: naming what is in a photo

**Built on the Mac at the first attempt (22:43, Mac and simulator) and tried there.** The five test photos of doc 18 were run through the app itself with `SpeciesTestRun`, against a test list of 20 species: 5 of 5 named to species, each at over 99%, 5.4 seconds for the first photo (which loads the model) and 0.3 seconds for each after. That matches the Python test of 12 November, so the app's way of preparing a photo is sound. The matching has 13 logic tests (388 in all). **Not yet tried: the Identify screen by hand, the real UK list, William's own photos, an iPad.**

**What it does.** The Identify screen had a button that only said identification was not built. It now matches the photo against a list of UK species with BioCLIP 2, on the device, and names a species only when the match is strong.

**How, in three steps, and which file does each:**

1. *Prepare the photo* (`SpeciesEye.swift`, with the sums in `PhotoArithmetic` in `SpeciesTable.swift`). The photo is opened the right way up, its middle square is cut out and drawn at 224 by 224 pixels, and each colour value is adjusted the way BioCLIP 2 was trained to expect: take off an average, divide by a spread. The pixels are then rearranged from "red, green, blue, red, green, blue…" to "all the reds, all the greens, all the blues", which is the order the model wants.
2. *Run the model* (`SpeciesEye.swift`). Core AI loads `bioclip2_image_f16.aimodel` and runs its one function, `main`. In goes an `NDArray`, Core AI's block of numbers with a shape (1 photo, 3 colours, 224, 224). Out come 768 numbers that describe what the photo looks like. This is the only step that needs Core AI, so it is fenced with `#if canImport(CoreAI) && arch(arm64)`: "only build this where Core AI exists and the chip is one of Apple's own".
3. *Match* (`SpeciesTable.swift`). The table has one row of 768 numbers for each species. For each row, the photo's numbers and the row's are multiplied pair by pair and added up. The bigger the sum, the closer the match. The sums are turned into shares that add up to 1. If the top share reaches the "not sure" level that came with the table, the species is named. If not, the screen says "Not sure" and shows the closest three.

**Why a "not sure" level.** The model always picks something. The level was set on the Mac so that a named answer was right 19 times in 20 on photos it had not seen. Below it, a wrong name is too likely to show as if it were an answer.

**Fungi.** The table is made without fungi. The code also drops any row whose group is fungi when the table is read, so a later table that included them still could not name one.

**What a sighting started from the screen now holds** (`EiraVision.swift`, `createObservation`). A strong match goes in as the provisional name, marked "probable" and "on-device model". A weak one is not written in as a name at all: the closest three go in the notes. Before, the whole sentence of the answer was stored as the name.

**`SpeciesTestRun.swift`**, new: the photo twin of `EiraTestRun`. From Terminal it runs a folder of photos through the same code as the screen and writes what came back, with marks if it is given the right answers. It is how the app's own accuracy gets compared with the figures measured in Python on the Mac.

**Three files have to be in the Models folder**, in a folder called `bioclip2`: the model (there since 22:25), `uk_species.json` and `uk_species_rows_f16.bin` (being made by the fine-tuning chat). Until all three are there the screen says which are missing.

**The Identify screen is redrawn** (`EiraVision.swift`, commit `b4de32a`, not yet built or looked at). It was a standard form. It is now made of the same cards as the other sheets:

- It opens as a sheet from Today (`IdentifyView(inSheet: true)`, inside a `SheetPage`) and as a page from Wildlife (a `ScreenHeader` and the same cards). One set of cards, two frames, the way the sighting form does it.
- A photo can come **from Photos or from a file**. `.fileImporter` opens the Mac's or the iPad's file window. A file chosen there may only be read between `startAccessingSecurityScopedResource` and its matching stop call, which is the system's way of giving an app leave to read one file it does not own.
- Each possible species is a `CandidateRow`: its English name, its scientific name in italics, its share as a figure and as a bar. The bar is two capsules, a full-width track and a filled part on top. `GeometryReader` tells the row how wide its space is, and the filled part is that width times the share.
- The one that is named outright is larger and green. When nothing is named the card is headed "Eira is not sure" and says why.
- `-demoOpen identify -demoMatch YES` opens it with a made-up answer, so the cards can be looked at in the simulator, where the model cannot run.

## 13 November 2026, late evening: Apple's model package, and a test Eira can sit on her own

William asked for the converted models to be put into Windfall. Doc 27 in the knowledge base has the whole account. What changed in the code:

**Apple's `coreai-models` package is in the project, for the Mac only.**

- *What it is.* The Swift code that runs a converted language model (a folder ending `.aimodel`) and hands it to Apple's `LanguageModelSession`, which is what Eira's chat already talks to. Windfall's engine had the lines to use it since 11 November, fenced with `#if canImport(CoreAILanguageModels)`, which means "only build this if that code is present". Until tonight it never was.
- *Why through a go-between.* The iOS Simulator has no Core AI, so the package cannot be compiled there. Xcode builds a package the app depends on directly for every platform, whatever filter is set. A package can leave out one of its *own* dependencies by platform though. So `Packages/WindfallCoreAI` is a tiny package that depends on Apple's only on macOS (`condition: .when(platforms: [.macOS])`), and Windfall depends on that. Its one Swift file passes Apple's code straight on.
- *What it brings with it.* Nine other packages that Apple's depends on (for reading tokenisers and chat templates, among other things). `Package.resolved` now records the exact version of each, so every build uses the same ones.
- **The Mac app now needs macOS 27.0**, up from 26.0, because Apple's package does. The iPhone and iPad minimum is unchanged.

**Where models live on a Mac** (`EiraEngine.swift`). `Application Support/Windfall/Models`, not Documents. A Mac's Documents folder is often kept in iCloud, and a 4GB model would start uploading. Nothing had been put in the old place.

**"Add a model from a folder…"** in Eira's settings (`EiraChatView.swift`, `EiraModelLibrary.importModel`). A signed copy of Windfall runs in a "sandbox", a fenced-off part of the disk, and cannot read a model lying elsewhere. Choosing the folder in a file window gives Windfall leave to read it, and it copies the folder in. On the same disk the copy is a "clone": instant, and it takes no extra room.

**A test Eira can sit on her own** (`EiraTestRun.swift`, new, and `Tools/eira-test`).

- *Why.* The test sheet (`docs/eira-test-questions.md`) was 22 questions to type by hand for every model. Nobody was going to do that five times.
- *What it does.* Started from Terminal, the Mac app asks each question through the same code as the chat screen (`EiraConversation`), so the fixed safety replies, the lookups and the corrections all take part. It writes each answer, each lookup and the time taken to a file, then closes.
- *How.* `Tools/eira-test/run.sh coreAI qwen3_8b_4bit_dynamic qwen-1` on the Mac. It always uses the example garden, held in memory, so real records are never read or changed.
- *A trap worth knowing.* Every launch argument must be a pair: `-demoGarden YES`, not `-demoGarden`. A Mac treats a file path that is not paired with a dashed word as a document to open, and then never opens the app's window. The first two tries sat there doing nothing for that reason.
- *What it does not do.* Mark the answers. A person reads them against the sheet.

## 13 November 2026, evening: what William found in the first build

William tried the first build on the Mac and sent seventeen pictures. Each change below says why it was made. The pictures are in `Design/Reference`, named "2026-11-13 evening".

### The sliding switch (`GlassSwitch.swift`, new file)

- **Why**: dragged, the lens only slid. Apple's own switches lift into clear glass that magnifies. And there was no two-finger swipe.
- The lens now has two looks. At rest it is green glass. Lifted, it is clear, taller than its track, and the words under it are magnified by the same small graphics program as the sidebar's lens (`LensBend`).
- Its left and right edges are kept as two numbers. On a tap one edge sets off first, so it stretches across. While carried it stretches with its speed and draws back when the finger stops.
- On a Mac, a sideways two-finger swipe with the pointer over a switch carries the lens. An up-and-down swipe is left to the page.
- **The rule**: every bar of choices is a `GlassSwitch`. The last standard one, on Charts, was swapped.

### The jiggle (`TodayView.swift`, `Wiggle`)

- **Why**: every card rocked through the same angle in step, like a machine.
- Each card now has its own pace, chosen at random once, and bobs up and down a little as well as turning. A small card turns further than a wide one. Apple publishes no figures for its jiggle, so this copies what can be seen.

### A plan card for each garden (`TodayLayout.swift`, `TodayView.swift`)

- **Why**: the two garden plans moved as one card.
- `TodayPanel` changed from a fixed list of cases to a struct holding a name, so there can be one panel for each garden ("plan:allotment"). On a three-column screen each garden's plan is its own card. Narrower screens keep one card with the switch.
- An arrangement saved before this still reads: the old "plans" card is swapped for the garden cards where it stood.
- The arrows now sit astride the card's top edge. Inside the corner they covered the compass.

### Telling Eira something (`JournalChat.swift`, `EiraFloatingBar.swift`, `JournalChatView.swift`)

- **Why**: "Today I planted beans" typed into Eira's bar went to her ordinary chat, which looked for a record and found none.
- `JournalChat.readsAsTelling` is a fixed rule that tells an account ("I planted", "We harvested") from a question. It is cautious: in doubt, the words go to Eira as before.
- An account now opens the journal's conversation with the words waiting in the box. Sending it there notes the time and weather and brings up the card that asks which bean and where. A button hands the words back to Eira if it was a question after all.

### On a Mac: text size, going back, the sidebar (`PageZoom.swift`, `TextSize.swift`, new files)

- **Command and plus or minus** make the page larger or smaller, and Command and 0 puts it back. A Mac has no text size setting that apps can follow (tried on William's Mac: asking for larger type changed nothing), so the page is laid out for a smaller window and enlarged, as a web browser does.
- **Two fingers swiped right** go back a page. Each page that was opened on top of another hands `BackSwipe` its own way of leaving.
- **The sidebar can be hidden**: a button at the left of the window's bar, and "Hide Sidebar" in the View menu (Control, Command and S). On an iPad the button is in the sidebar's heading.
- **The rectangle behind the sidebar is gone.** The window and each page drew their own washes of colour, each from its own edges, so they did not meet. Pages now draw the window's (`PaperBackground(followsWindow:)`).

### Pages redrawn in the app's own look

- **Journal** (`JournalViews.swift`, `JournalPage.swift`): a card for each day, with the day's weather, what was written and what was recorded. A bar at the top opens the conversation. Ticks choose which kinds show.
- **Sightings** and **the sighting form** (`ObservationViews.swift`): cards, the app's icons and tags. The form is built from `SheetParts`.
- **Year** (`YearView.swift`): a "Fruit, veg…" button filters by kind of plant, using the Plants page's sorting. Every job button whose lines are showing is now lit green. Before, with "Every job" on, all five looked switched off.
- **The garden's plot** (`GardenEditorView.swift`): plus and minus turn the plan five degrees at a time, held down they keep turning, and the plan turns inside a compass ring with north at the top. The stray "Not set" beside each number is fixed.

### Sheets on a Mac can be made larger (`SheetParts.swift`)

- **Why**: a sheet such as the FIT Count had one fixed size.
- A sheet's frame is now given as smallest, usual and largest. It opens at the usual size and its edges can be dragged. A button beside the title jumps to a larger size and back.
- `SheetScroll` measures its cards and passes the height up (a SwiftUI "preference"), so a sheet still opens exactly as tall as what is in it.

### Plants that do not come true from seed (`SeedTruth.swift`, new file)

- **Why**: William tried to record a sowing of the apple 'Pendragon'. A pip from a Pendragon grows a new seedling, not a Pendragon.
- `SeedTruth` sorts plants by name into three habits: kept by cloning (apples, potatoes, garlic, soft fruit), crosses readily (squash, brassicas, sweetcorn, beet) and mostly true (tomatoes, peas, French beans, lettuce). **The lists are Claude's, not looked up, and need William's check.** Run over the real library they gave 88 plants kept by cloning, 73 that cross and 26 mostly true. 189 are not on any list.
- For a plant on the first two lists, or an F1 variety, the sowing form now asks how it was started. A plant, tree or tuber is recorded as planted. Saved or crossed seed records its seed parent, its pollen parent if known, and whether the cross was made by hand.
- Four new fields on a sowing hold that. All may be empty, so a database from before still opens. Backups carry them.
- The journal reads "Planted Apple" or "Sowed seed of Apple", with the cross written as seed parent × pollen parent.

### Recording a cross (`Crosses.swift`, `CrossViews.swift`, new files)

- **Why**: a cross is made in spring and its seed sown the year after. By then nobody remembers whose pollen it was.
- `PlantCross` is a new kind of record: seed parent, pollen parent, the date, whether it was by hand, whether the flowers were bagged, how many flowers, and later how much seed.
- Each parent is kept as a name in words and, where it is in the library, as that plant's identifier. So a neighbour's tree can be a parent, and a parent still reads correctly if its plant is later removed.
- **Gardens has a Crosses tile.** It lists them and has "New cross".
- **The sowing form offers them.** Sowing saved seed of a plant, it lists crosses made on that plant, then on others of its kind, and fills in the parents from the one picked. A sowing remembers which cross it came from (`crossKey`).
- Backups carry crosses. A backup made before they existed still reads.

### The sowing form's buttons (`SheetParts.swift`, `PlantingViews.swift`)

- **Why**: on a Mac, Apple's glass button style filled with green, so Cancel, Save and the resize button all looked like the main button.
- `QuietGlassButton` is dark glass with plain words. Every button that is not the main one now uses it.
- "Change" is now "Choose another", and the list it opens has a "Back to" button for the plant you had.

### Not seen or tried

Everything here was built on the Mac without errors. The lens moving, the jiggle, the swipes, Command and plus, and hiding the sidebar can only be judged by hand.

## "This week": the urgent jobs (`WeekJobs.swift`, new)

William: "Eira could organise the this week to make sure it is specific
based on the conditions... 'this is the last week to plant this seed or
plant or plant it out' that kind of thing, basically the urgents."

A seventh card on Today, above "This month". It lists:

- **Frost on the way**, named for the night before ("Frost on Sunday
  night"), or "Close to freezing" at 2°C or under.
- **Strong wind**: the windiest day of the week if gusts reach 40 mph.
- **A dry spell**: last week lost 15 mm more water to the air than fell
  as rain, and under 5 mm is forecast for the next three days.
- **The last week to sow** something not yet sown this year, when its
  sowing months end with this month. Indoor and outdoor months are
  taken together.
- **The last week to plant out** a sowing raised indoors or under cover.
- **A crop due** within seven days, or up to a fortnight overdue.

Weather first, then whatever runs out soonest.

- **Fixed rules pick the list, not the AI model.** A list of what is
  urgent has to be the same each time and has to be true. Rules can
  promise that and can be tested (12 new tests).
- ⚠️ CHECK: the four weather thresholds (0°C, 2°C, 40 mph, 15 mm) are
  Claude's rules of thumb. They are named at the top of `WeekJobs`.
- A job in "This week" is left out of "This month". Both use the same
  ticks.
- **The forecast** comes in the same reply as the current conditions
  (`WeatherService`), so there is no extra request. It now asks for
  today and the seven days after.
- **Last week's rain and water lost** come from the weather diary.
- The card says so when there is no forecast yet.
- Not done: jobs William adds himself, a plant bought as a plant
  (there is no record of one tree or bush yet), and Eira being able to
  read the list out.

**Found while doing this:** the weather check on Today sent the
garden's or device's location in full. Settings says it is rounded to
about a hundred metres. It is now rounded, as the weather diary's
already was.

`TodayLayout.swift`: "This week" is a new panel, above "This month" in
each standard arrangement. An arrangement saved before it existed gains
it as near its standard place as it can go.

## Sheets that look like the rest of the app (`SheetParts.swift`, new)

William, with pictures of four forms: "A lot of the buried menus are
looking quite different to the top level interface... There also seems
to be bars at the top and bottom of the windows".

Why they looked as they did: each was a standard `Form`. On a Mac a
Form is laid out in two columns, as tall as its rows and no taller,
inside a sheet that had been given a set height. The grey bands were
the sheet showing above and below the form. The title and the Cancel
and Save buttons sat in bars of the sheet's own.

- **`SheetParts.swift`** holds pieces for building a sheet in the app's
  own look: `SheetPage` (title, Cancel, Save, paper), `SheetScroll`,
  `SheetCard`, `SettingRow`, `FieldBox`, `NumberStepper`,
  `ProblemsCard`, `SheetMainButton` and `GlassSwitch`. A sheet built
  from them has no bars and is as tall as its contents, up to a limit.
- **Rebuilt from them:** the FIT Count and earthworm count, the new
  sowing form, "What did you harvest?" and the harvest form.
- **Every other form**, on a Mac, now uses the "grouped" look (boxed
  sections that scroll and fill the window), set once in
  `paperScreen()`. This is a stopgap that removes the two columns and
  the bare bands. The paper is also put behind the whole of each sheet
  (`macSheetSize`). **The title and button bars of those sheets may
  still be there.** They are to be rebuilt one at a time once they can
  be seen: the sighting form first.

### The counts (`SurveyViews.swift`)

- Setup is two cards. The conditions are three sliding switches and a
  small box for the temperature.
- **The conditions fill themselves in** from the weather service if
  Today checked it within the hour, with a line saying so.
- Counting has a ring that empties around the time left, larger rows
  and a hint under each worm group.
- ⚠️ CHECK: the four worm hints were written by Claude from AHDB's "How
  to count earthworms".
- The result shows each group with a bar for its share. All four worm
  groups are shown, because none found is worth knowing.
- **Abandon now asks first and throws the count away.** It used to keep
  it, looking like a finished count. Say if that should be put back.
- Fixed: the pit number showed 1 but was not recorded unless changed.
  An abandoned count left an iPhone's screen set never to sleep. The
  time left is no longer worked out by changing the screen's own state
  while it was being drawn.
- An iPhone buzzes when the time is up.

### The harvest forms

- With one thing growing, the harvest form opens straight away.
- With more, choosing a sowing swaps the list for the form in the same
  sheet, with a Back button, where it used to open a second sheet.
- Destinations read "Given away" and "Seed saved", not "Givenaway".

## The sliding switch (`GlassSwitch`, in `SheetParts.swift`)

William, of the Allotment and Permaculture garden switch: "The curves...
are different to the other boxes, it is also wider than the other boxes
... you can't drag it across like a slider".

It was the system's joined buttons. On a Mac they will not shrink below
the width of their words, so in a narrow column they stuck out past the
cards. `GlassSwitch` replaces them: a glass track the width it is given,
with a piece of green glass that slides to a tap and lifts and follows
a press and slide. It is used for the garden switch on Today, Gardens
and Weather, on the old garden map, and in the count and sowing forms.
The year switch on the Charts page is still the system's.

## Two-finger scrolling on the sidebar (`MainTabView.swift`, Mac only)

Two fingers on the trackpad, with the pointer over the sidebar, carry
the lens up and down. It settles on the nearest row when the fingers
lift. A mouse wheel moves one row a click. With Reduce Motion on, a
scroll is one step.

SwiftUI has no way to hear a scroll on a view that is not a scrolling
list, so the Mac is asked to pass every scroll in the app through the
sidebar first (`NSEvent.addLocalMonitorForEvents`). Scrolls elsewhere
are handed straight back untouched.

## Eira's bar

It ran out past the cards to the sidebar. It now stops 20 points in
from the left and 28 from the right, a little inside the cards' edges.

## The journal as a conversation (`JournalChatView.swift`, `JournalChat.swift`, new)

William, of the diary form: "the journal entry isn't very chat interface
like. Is there a way that we can add all these options into a sleeker
chat like interface?" This is the first slice of the design agreed on
12 November and drawn on the canvas as artboards A and B.

- **One box to write in and a send button.** Return sends. Shift and
  Return starts a new line.
- **The form's options are three chips above the box**: when ("Now"
  unless changed), the conditions and what it is about (the garden or
  one bed).
- **The conditions fill themselves in**: from the figures Today fetched
  if they are under an hour old, otherwise from that hour of the weather
  diary. Tap the chip to change them, and it says where they came from.
- **The title is written from the entry's own first words.** "This
  morning I mulched the raspberries with leaf mould and saw a wren"
  becomes "Mulched the raspberries with leaf mould". It is stored where
  Eira's headings go, so it is marked as written for you, and can be
  renamed.
- **Photos**: a button, or dragged on to the sheet on a Mac or iPad.
- **Hold the microphone to speak.** What is heard goes into the box to
  be read over, and is not sent by itself.
- **The day so far is above the box**: what has been written, as green
  bubbles with a stamp of time and weather, and that day's sowings,
  harvests, counts and sightings in between.
- **The time check.** Written after dark, or with "this morning",
  "this afternoon", "yesterday" or "earlier" in it, a card asks when it
  was about and offers each time with its weather. Send waits until one
  is chosen. "Dark" is worked out from the sun at the garden.
- **Press and hold a bubble** (right-click on a Mac) to rename it,
  change its details in the old form, or delete it.
- Each thing sent is an ordinary diary entry. **Nothing about how
  entries are stored has changed**, so no database check is needed.
- Opened from Today's Note button, Today's journal offer and the
  Journal's New entry button. Nothing is saved until something is sent,
  where the form made an empty entry as soon as it opened.

**Fixed rules, not the AI model**, write the title, choose the weather
word and decide when to ask about the time. Eira's lines are fixed
wording. 10 new tests.

Rain of 4 mm an hour or more is called "heavy rain". That is the Met
Office's own line: 4 mm an hour or more is "termed heavy" (its guide to
the rainfall map for government users, read 13 November 2026).

Not built: names becoming links, a day read back as a page, the wide
layout with days down the left, "this week in other years" and the
evening summary. The Journal page itself is still a plain list.

### The title reads the whole entry

William: "The title of the journal entry should more heavily analyse the
message as I might have a first sentence that's not necessarily what the
majority of the entry is about."

The first version used the first sentence. Now every word that says
something is counted across the whole entry, and each sentence is scored
by the words in it that the entry uses more than once. The title is made
from the highest-scoring sentence. A sentence that names one of the
garden's plants or beds counts double. "Cold start today. Spent the
morning mulching the raspberries with leaf mould, then pruned the autumn
raspberries and tied in the new canes. The raspberries look healthy." is
titled "Mulching the raspberries with leaf mould".

Still fixed rules. **Not done: asking Eira's model to write the title**,
which would read better still. It needs trying on the Mac, and would
only run where a model is available, with these rules as the fallback.

### Eira offers a harvest or a sowing (`JournalOffers.swift`, `JournalOfferCards.swift`, new)

The design agreed on 12 November: "We harvested 50 kg of Jonagolds"
brings up a card to add a harvest, and nothing is saved until Add is
pressed.

- When an entry is sent, its words are read for something harvested
  ("picked", "dug", "harvested"...) or sown ("sowed", "planted"...),
  followed by the name of a plant in the library.
- Each find is a card from Eira with what was understood filled in:
  the plant, the amount and its measure, where the crop went, the bed,
  where it was sown. Anything can be changed. **Add** saves it and Eira
  says so. The other button takes the card away.
- **Amounts**: "50kg", "2.5 kg", "a kilo of", "half a dozen", "12
  apples", or after the plant, "about 2.5 kg". Pounds and ounces are
  turned into kilograms and grams. No amount written means none guessed.
- **A name shared by several plants** ("apples") offers all of them to
  choose from. A variety ("Jonagold's") picks out the one.
- **Where a crop went** is picked up from words such as "froze",
  "stored", "for cider" (which counts as preserved), "gave".
- **A harvest for a plant with nothing on record as sown or planted**,
  such as a tree that was here before the app: the card says so, and
  adding the harvest also puts the plant on record as growing, with a
  note. The journal lists it as "put on record", not as sown that day.
- **A sowing in a named bed** is offered as the whole bed, since the
  words do not say which part.
- **Not offered**: plans ("need to sow"), things not done ("didn't
  pick"), "planted out" (that moves an existing sowing on, which is not
  built), and plants that are not in the library.
- Offers last until the next entry is sent or the sheet is closed.

Fixed rules, with 8 tests, William's own example among them. Rules will
miss some ways of putting things. A miss costs nothing: the entry is
saved all the same.

Along the way: "Under cover" and the other sowing places have their
wording in one spot (`SowingLocation.words`).

## A plant's page as cards (`PlantPage.swift`, new, and `PlantLibraryView.swift`)

William, of a plant's page: "Can you make these more card like as well.
You could use the overall sections that I used in my spreadsheet to
create sections."

- One glass card for each group of columns in the spreadsheet: Growth
  Patterns, Growth Habits, Permaculture Category, Sowing from Seed,
  Growth Constraints, Human Management, Ecological Interactions and
  Description. **A card with nothing in it is left out**, which the old
  page meant to do and did not.
- Two columns of cards where the page is 720 points wide or more, one
  where it is not. The cards are shared out so the columns come out
  about level.
- **Months are drawn as a strip of twelve blocks**, in the Year page's
  colours, with a ring on this month. They were written out in words.
- Short facts sit side by side with the name above the value. Long ones
  take the full width.
- Measurements have their units: "0.15 m", "25-50 mm".
- The permaculture roles are chips.
- The top of the page is the plant's name in the serif, its Latin name
  under it and "softneck · Alliums · Perennial" above.

`PlantPage.swift` decides what goes on each card and has no screen code,
so it is tested (4 tests).

## Companions: two columns, sides, symbols and pests (`CompanionPlanting.swift`)

William: "Could you make the companion planting two columns and then if
the window is narrow it has a top bar that has the friends and enemies",
and then: "I wonder if we could also have icons in with them... Maybe
there's a way that if you've identified a pest you can select plants
that deter them."

- **Two columns** from 640 points wide: "Grows well with" on the left
  and "Keep apart from" on the right, each a glass card. Narrower, a
  sliding switch at the top chooses Friends or Enemies.
- **Each plant is listed once.** The matrix can hold the same two plants
  more than once, and the old page listed them as many times.
- **The reasons now say whom they are for.** Each row of the matrix says
  what its second plant does for its first (its heading is "How plant2
  impacts plant1"). The old page ignored that, so on garlic's page
  "Carrots: deters carrot fly" read as something carrots do. It now
  reads "Garlic helps it: Deters carrot fly, root maggots", beside
  "Helps Garlic: Repel onion fly and leek moth".
- **A symbol for the kind of reason**, with the kind in words under the
  name: keeps pests off, draws pests away, brings helpful insects, feeds
  or opens the soil, shares the space, gives shade or cover, better crop
  or flavour, likes the same conditions. For enemies: shares pests,
  competes, stunts growth, toxic, wants different conditions. The kinds
  are worked out from the words of each reason. Tried on every reason
  in the shipped matrix, four of about 145 fit no kind and show a plain
  tick or cross. The symbols are Apple's, standing in until Windfall
  has drawings of its own.
- **Pests.** Where a plant's friends help it against pests the matrix
  names, those pests are chips above the lists. Picking one leaves only
  the friends that help against it.
- **"Pest helpers"** (new page): start from the pest. Every plant the
  matrix records as helping against it, with the crops it is recorded
  with. Reached from the foot of any Companions page, and from a new
  card on a plant's page that lists those of its known pests the matrix
  has an answer for.

⚠️ CHECK: the pests are found from a list of names and the ways the
matrix writes them, made by Claude. Greenfly and blackfly are counted as
aphids. Cabbage worms, cabbage moths and cabbage whites are counted as
caterpillars. Carrot root fly and carrot rust fly are counted as carrot
fly. Blight is in the list though it is a disease. A pest that is not
in the list is not found.

6 tests, using rows from the matrix as shipped.

Not done: icons drawn in Windfall's own style, a picture of each plant,
a link from a recorded pest or disease to its helpers, and Eira being
able to answer "what deters carrot fly?" from the same list.

## A filter in the middle of the bar

William, of the Journal's filter menu on the Mac: "Is there a reason
that this menu is in the middle of the top bar?" No good one. It was
placed as a `.secondaryAction`, which an iPhone tucks into its "more"
menu and a Mac puts in the middle of the window's bar, on its own.
`ToolbarItemPlacement.besideMain` (in `Theme.swift`) now puts such a
button at the right-hand end on a Mac, beside the main button, and
leaves an iPhone and iPad as they were. Used for the Journal's filter,
the sightings list's group filter and the sowings list's "Show
finished".

## To check when it is built

- Each rebuilt sheet on the Mac, iPad and iPhone, light and dark. Does a
  Mac sheet take the height of its contents, and follow when they
  change (setup, counting, result)?
- Do the other sheets still have bars at the top and bottom?
- The sliding switch: does the glass read well on the track? Does a
  page still scroll when a finger starts on a switch?
- The sidebar: is 0.6 the right gearing? Does scrolling still work in
  the page beside it?
- "This week" with a real forecast.
- Does Return in a notes box press Save when it should make a new line?
- A plant's page: are the month strips clear, and are the two columns
  about level? Try a plant with little filled in.
- Companions: two columns when wide, the switch when narrow. Do the
  symbols exist and read well? (One wrong symbol name shows as a blank.)
- The offer cards: do the small menus on them (plant, measure, where it
  went) look right on a card? Try "We harvested 50kg of Jonagold's".
- The journal's conversation: does the box stay above the keyboard on
  an iPhone? Do the two small panels (when, conditions) open as panels
  and not full screens? Does a photo dragged from Finder or Photos land?
  Does holding the microphone work beside the text box?

# 13 November 2026, morning: rearranging the Today screen

**The `today-rearrange` branch**, on top of `weather-diary`. **Not yet
built on the Mac and not seen running**: the link to the Mac was down
while this was written. It passes the checks that can be run without the
Mac (every file reads as valid Swift, 311 logic tests pass), but those
do not build the screens. Treat everything about how it looks and feels
as untried until it has been built and used.

William asked: "Can we make it so that you can rearrange the home view by
tapping and holding the object (like the This month box), and it wiggling
to rearrange".

## What it does

- **Press and hold a card** on Today and all the cards start to wiggle.
  On an iPhone or iPad the card lifts under the finger, ready to drag.
  On a Mac, click and hold for half a second, then drag.
- **Drag a card onto another** and it takes that card's place. The other
  cards move along.
- **A dashed "Drop here" space** sits at the foot of each column while
  rearranging, and one at the top and bottom for full width. This is how
  a card reaches an empty column, or is made to span the page.
- **Two arrows on each card** move it one place earlier or later without
  dragging. They are there for anyone who finds dragging awkward and for
  VoiceOver.
- **A bar at the top** says what is going on, with Reset (the standard
  arrangement) and Done. A "Rearrange this page" button at the foot of
  the page starts it too, so it can be found without knowing about
  press and hold.
- **Each width keeps its own arrangement**: three columns (Mac, wide
  iPad), two (narrower iPad) and one (iPhone). Moving cards on the Mac
  does not disturb the iPhone's order.
- **Cards fit the room they are given.** The capture buttons are a row of
  six at full width, three across in a wide column and two in a narrow
  one. The conditions card stacks when it is put in a column. With three
  columns, the one holding the garden plans gets the most room.
- **The journal offer** only appears on days when there is something to
  offer. While rearranging it shows as a placeholder so it can still be
  given a place.
- **Reduce Motion** (an Accessibility setting) swaps the wiggle for a
  dashed outline.

## How it is built

- **`TodayLayout.swift`** (new) holds the arrangement and its rules, with
  no screen code in it, so it can be tested without the Mac. A
  `TodayPanel` is one movable card. A `TodayArrangement` is the list of
  cards in each zone (a full-width stack at the top, each column, a
  full-width stack at the bottom). It can move a card onto another, move
  one to the end of a zone, nudge one a step, and turn itself into a line
  of text to be saved and back again. Reading saved text is forgiving: a
  card it does not know is skipped and a card that is missing is put
  back in its standard place, so adding a card in a later version cannot
  lose anyone's arrangement.
- **`TodayView.swift`** now draws the page from the arrangement where it
  used to have the three layouts written out by hand. The cards
  themselves are unchanged. The pieces that do the wiggling and dragging
  (`Wiggle`, `LiftToArrange`, `DragSurface`, `DragLabel`) are at the foot
  of the file.
- The arrangement is saved as text under three settings names:
  `todayArrangementWide`, `todayArrangementMiddle`,
  `todayArrangementNarrow`. The standard arrangement is saved as nothing
  at all.
- 19 new logic tests cover the arrangement.

Checking aid: `-todayArranging YES` opens Today already wiggling. An
arrangement can be tried without dragging by passing its saved text, for
example `-todayArrangementWide "conditions|jobs,capture|plans|recent,journal|"`.

## To check when it is built

- Does a press and hold on an iPhone or iPad lift the card and carry on
  into a drag in one movement, with scrolling still working?
- Does the Mac's click and hold start the wiggling without pressing the
  button under the pointer?
- If a card is let go outside the window, does it stay dimmed? (It may.
  Done clears it.)
- Is the wiggle the right size on the wide cards?
- Does the bar at the top cover the page heading?

# 12 to 13 November 2026, overnight: the weather diary, fixes and a sweep of the code

**The `weather-diary` branch**, on top of `plant-filters`. Builds on the
Mac for macOS, iOS and the iOS Simulator with no new warnings. 292 logic
tests pass. Looked at in the iPad Pro, iPad mini and iPhone simulators.
A database made by the `plant-filters` version opens in this one
(tried in the iPad mini simulator). **Not run with William's real
records.**

## The weather diary (`WeatherDiary.swift`, `WeatherDiaryView.swift`)

William asked for "a record of the weather for the day(s) and longer
term". The app now keeps one record a day for each garden that has a
location: coldest, warmest, rain, strongest wind, sunshine, water lost
to the air, soil temperature at seed depth, the kind of day, and the
temperature, rain, cloud, wind and soil for each hour.

- **It fills itself in.** When the app opens, and each time it comes
  back to the front, it works out which days are missing and fetches
  them. Nothing needs to be pushed to the app and no day is lost by not
  opening it. It asks the service at most once an hour for each garden.
- **Two sources, both Open-Meteo.** The ordinary address for the newest
  days, and the long-term record for older ones. Found by trying it:
  asked for 92 days, the ordinary address sent figures for only the
  newest 64, so days older than that come from the long-term record,
  which runs about five days behind. Each day records which it came
  from.
- **Today's record is part forecast** and is marked unfinished. It is
  fetched once more after the day ends and then left alone.
- **Frosts come from the diary.** A finished day that went to freezing
  or below becomes a frost record, once. This replaces the separate
  frost check, which asked the service a second time for the same
  figures and needed the device's location.
- **Gardens within about a mile share one diary.**
- **The Weather page**, from the Gardens page's Weather tile: four
  figures (the latest finished day, the week's rain against water lost,
  soil temperature, the last frost), the last 30 days as two charts,
  the days one by one, and this year's frosts. Each day opens to its own
  page with the temperature and rain hour by hour. "Fetch a year of
  earlier weather" goes further back.
- **The hour-by-hour figures are what the journal's time check needs**:
  `WeatherHours.conditions(atHour:)` gives the conditions at any hour of
  any day held.
- **These are not readings from the garden.** They are worked out for
  its place on the map from weather models. The page says so.
- **Credit.** Open-Meteo's licence asks for one wherever its figures are
  shown. It is on the Weather page, each day's page and in Settings.
- The Settings line "Nothing is sent anywhere" was not quite true and
  now says what is sent: each garden's location, rounded to about a
  hundred metres, to the weather service.
- The diary is not in the backup file. It can be fetched again.

Not built: fetching in the background while the app is closed, the
Shortcuts actions and the HomeKit sensors. See the project notes.

Checking aids: `-demoWeather` opens the Weather page and
`-demoWeatherDay` opens the newest finished day, both with `-demoGarden`.

## Three small fixes

- **Fruit trees now show on the Year page's Harvest.** Their months are
  in the Fruiting/Harvest column, which arrives in a different field.
  Harvest now reads both.
- **Frost records come back from a backup.** They were written to the
  file and never read from it. Their garden and notes are now in the
  file too.
- **The voice wave moves.** Its bars were meant to ripple and stood
  still, because the ripple was driven by a kind of animation a Canvas
  cannot follow. It now follows the clock.

## A sweep of the code for waste

William asked for "a high quality sweep of the code to check for
anything extraneous or anything that would add inefficiencies". Timings
are from the test harness, built unoptimised, as Xcode builds when
running from it.

| What | Before | Now |
|---|---|---|
| Reading month text ("mar apr may") | Read afresh on every call, 54 millionths of a second each. The Year page asked about 1,700 times a redraw, so about 90 thousandths of a second each time a button was pressed or a letter typed. Today's jobs and the Plants filters did the same | Each piece of text is read once and remembered (`MonthParser`). A needless sort on every call is gone |
| Sun hours in the garden editor | Worked out bed by bed, each time working out every shadow again: 62 thousandths of a second a redraw for ten beds in June | Every bed in one pass over the same shadows: 17. The answers are identical, which a test checks (`Shade.sunHours(onEach:)`, `GardenPlan.sunHours(forBedsIn:)`) |
| Today's jobs and recent records | Each worked out up to four times a redraw | Once |
| Today's weather | Fetched again every time Today was returned to, with the card going blank meanwhile | One weather service for the app, which keeps its answer |
| Month names and the number pattern | A date formatter or a pattern built on every call | Built once, or asked of the calendar |
| The frost check | A second request for figures the diary now has | Gone |

Removed as no longer used: the `WeatherSnapshot` record, which nothing
ever wrote or read. The weather diary does its job.

Notes in the code that still spoke of writing back to a spreadsheet are
corrected.

**Two speed checks in Settings**, for William to try, because their
effect could not be measured without watching the app move:

- **Plain background** leaves out the two large, heavily blurred washes
  of colour behind every screen.
- **Plain fade between places** swaps the melt for a simple fade.

Found and left alone, for William to decide:

- Unused but looks planned: `EiraChatStore.recentChats`,
  `EiraVisionPrompt`, `WebSearchProvider`, `TaxonMapper`,
  `NotificationService.scheduleFrostWarning`, `RangeParser.upperBound`.
  `GardenPlan.overlappingBeds`, `Bed.longSideFaces` and
  `Sun.noonAltitude` are used only by the tests.
- Two icons are drawn and never shown: `saved` and `north`.
- `Plant.sourceRow`, `sourceSheet` and `lastSyncedAt` are filled on
  import and never read.
- Every change of place in the sidebar builds the new screen from
  nothing and runs all its database questions again. That is how each
  place gets a fresh "back" trail. Keeping the screens alive would be
  quicker and is a bigger change.
- The garden editor still works out the sun again on every redraw,
  including ones that change nothing about the layout.

# 12 November 2026, late night: filters on the Plants screen, and Gardens and Wildlife redrawn

**The `plant-filters` branch**, on top of `visual-design`. Builds on the
Mac for macOS, iOS and the iOS Simulator. 251 logic tests pass. Looked at
in the iPad Pro and iPhone simulators, light and dark. **Not run with
William's real records. The menus have not been seen open: William
should try them on the Mac.**

## Filters on the Plants screen (`PlantFilter.swift`, `PlantLibraryView.swift`)

William asked to filter by "permaculture layer, Fruit, Vegetables,
Season of (sowing, fruiting, flowering, etc), Plant family (brassica,
etc)". A row of glass buttons sits above the list, in the style of the
Year page's buttons. Each opens a menu, and each choice shows how many
plants it would leave, with the other buttons still applied.

| Button | Choices | Read from |
|---|---|---|
| Growing | Growing, To buy, Previously owned, All plants | The plant's status |
| Fruit, veg… | Fruit, Vegetables, Herbs, Flowers, Green manure, Not sorted | The plant's group (see below) |
| Layer | Trees, Shrubs, Herbaceous, Ground Cover, Vines, from the canopy down | The Layer column |
| Family | Alliums, Beans, Brassicas, Gourd, Root veg and the rest | The group, two spellings counted as one |
| Season | Sowing, Sowing indoors, Sowing outdoors, Planting out, Flowering, Fruiting or harvest, in this month or any month | The month columns |
| Role | Pollinator, Nitrogen fixer, Dynamic accumulator, Ground cover, Pest repeller, Umbellifer. More than one means all of them | The tick columns |

- A chosen button turns pale green and says what is chosen, such as
  "Vegetables" or "Sowing in March". "Clear" appears when anything is
  chosen and puts everything back, leaving the search as typed.
- The old menu's "Pollinator plants only" and "Sowable this month" are
  now Role and Season. "Garden data" is a button of its own.
- The screen is titled "Plants", as in the sidebar, not "Library".
- "Fruiting or harvest" reads both the allotment's Harvest column and the
  permaculture sheet's Fruiting/Harvest column, which arrive in two
  different fields. **The Year page's Harvest reads only the first**, so
  fruit trees do not show there. Worth fixing.

**How fruit and vegetables are told apart.** The records have no fruit
or vegetable column. The group decides: Fruit is fruit. Root veg, Leaves,
Brassicas, Gourd, Alliums, Beans, Nightshades and Microgreens are
vegetables. Herbs are herbs. Wildflower, Flower, Pollinators, Ornamental
and Shrub (the roses, hydrangea and spiraea) are flowers. **Claude chose
this sorting.** In the real library: 71 fruit, 108 vegetables, 37 herbs,
121 flowers, 4 green manure and 35 not sorted, which are the plants with
no group, such as Asparagus, Purple Orach and several wildflowers.
"Not sorted" is a choice in the menu so they can be found and given one.

**Family is the group, not the botanical family.** The records' groups
are what the menu offers. Rosaceae, Brassicaceae and so on are not in the
records. They could be added from the Latin names, as researched data for
William to check.

Checking aid: `-plantsKind Vegetables`, `-plantsLayer Shrubs`,
`-plantsFamily brassica`, `-plantsSeason Sowing`, `-plantsMonth 3` and
`-plantsRole Pollinator` start the screen with those chosen.

## Gardens and Wildlife look like Today (`HubScreens.swift`)

William: "Can these look more like the today page?" Both were plain lists
of links. They are now built like Today: a line of facts above a large
serif title, then glass cards and tiles. Both moved out of
`MainTabView.swift` into a new file.

- **Gardens**: "2 gardens · 10 beds · 1 sowing on the go", the garden
  plans drawn to scale (side by side on a wide screen), then eight tiles
  with a line of facts each: Plants (335 growing · 40 to buy), Year
  (17 to sow this month), Sowings, Beds, Garden map, Seed, Scan a seed
  packet, Frost and weather. On an iPhone the tiles come first, because
  this page is the only way to Plants and Year there, and the plans show
  one at a time with a switch, as on Today.
- **Wildlife**: "2 sightings and 0 surveys this year · 1 to confirm",
  four tiles (Sightings, Surveys, Species, Identify from a photo), then
  cards for the latest sightings, tagged Confirmed or Provisional, and
  the latest surveys.
- Shared pieces any page can use: `ScreenHeader`, `HubTile`,
  `HubSectionTitle`, `ViewAllLink`.
- Three tiles use Apple's symbols until there are drawings for them:
  Beds, Seed and Scan a seed packet. Plants and Sowings share the same
  sprout drawing. Both for the next round of icons.

## Filed

William's four screenshots from this evening are in `Design/Reference`:
the plant library, Gardens and Wildlife before, and the journal's entry
form, which he wants redesigned as a conversation with Eira.

# 12 November 2026, night: the Year page, and the sidebar lens switched on

**Still the `visual-design` branch.** Builds on the Mac for macOS and the
iOS Simulator. 223 logic tests pass. Looked at in the iPad Pro and iPhone
simulators, light and dark. **Not run with William's real records.**

## The Year page (`YearView.swift`, `YearCalendar.swift`)

William chose from four options on the design canvas: "the small dots
that are in option A", "the bars with the curved ends in option B, so
that if the months you can sow or plant etc are consecutive, it's a bar,
but you still have the dots otherwise", and option C "as a toggle on and
off".

- A small faint dot for a month with nothing to do. A filled dot for a
  job that fits one month. A bar with round ends for months in a row.
- A ring inside a mark where it crosses this month, and a soft band down
  this month's column.
- A window that crosses the new year (October to February) is drawn with
  square ends at the edges of the year.
- **"Every job"** shows all five jobs on each plant as thin lines. Each
  job keeps its own height in the row. Sowing indoors is an outline and
  flowering is a row of dots, so the lines differ by shape as well as
  colour. The job buttons then switch single lines on and off.
- Plants are grouped by family (`Plant.group`), with the variety beside
  the name. A menu offers "By when it starts" and "A to Z".
- Tapping a plant opens its page.
- The marks are one drawing per row (`Canvas`), with the same thing said
  in words for VoiceOver.
- Five named colours were added for the jobs (`Design/colours.json`).
  The first four pass a colour-blindness check as a set. Violet for
  flowering does not pass against the blue, which is why those two
  differ by shape. **The colours are Claude's proposal.**
- The old `SowingCalendarView` is gone. `SearchAndCalendar.swift` now
  holds only the search.

Found in the data: one plant's family is spelt "Allium" where the others
say "Alliums". The page treats them as one family. The record is not
changed. "Leek" and "Leeks" also both appear as plant names.

## The sidebar lens is on

William agreed to the Metal Toolchain (838.9 MB, from Apple through
Xcode). It is installed, `Lens.metal` is back inside the app and
`LensRefraction.isBuilt` is true.

- Lifted, the lens is clear with a bright rim. What is under it is
  magnified a little, the rows just outside are squeezed in at the rim
  and there is a faint colour fringe.
- At rest it is Apple's glass tinted lime, as before.
- The amounts in `Lens.metal` were tuned once from still pictures:
  rim 11 wide, reach 11, fringe 2, magnification 10 per cent.
  **William has not yet judged it moving.**
- The toolchain does not make anything faster. William reported the app
  feeling slow and glitchy. The cause is not yet known.

## Checking aids

- `-sidebarLensHeld 0.5` holds the lens lifted, moved down by that many
  rows. `0` holds it over the chosen row.
- `-demoYear` opens the Year page in place of the Gardens list, which is
  how it is checked on an iPhone.
- `-yearShowsEveryJob YES` starts with every job showing.

# 12 November 2026, late evening: Eira knows the screen, and a lens for the sidebar

**Still the `visual-design` branch.** Builds on the Mac for macOS and the
iOS Simulator. 209 logic tests pass. Looked at in the iPad Pro simulator.
**Not run with William's real records, and Eira's use of the new screen
hint has not been tried with a real model.**

## What is new

- **Typing straight away** (`EiraFloatingBar.swift`). Pressing the
  snowdrop gives the text box the keyboard at once, so typing can start
  while the bar is still opening. Before, the keyboard waited for the
  animation to finish. Command-K opens the bar from the keyboard.
- **Eira is told what is on screen** (`EiraScreen.swift`). A screen says
  what it shows with one line, `.eiraLooksAt("the plant Apple, Spartan",
  short: "Apple, Spartan")`. The bar's hint then reads "Ask Eira about
  Apple, Spartan", and the phrase is put in front of the question for the
  model only. The chat shows what she was told, with a "Don't use this"
  button. Screens that do this so far: each sidebar place, a plant, a bed,
  a sowing, a species, a garden plan and a seed packet.
  - She does not see the screen. She gets one phrase the screen wrote.
  - A fixed safety reply still wins over anything on screen (tested).
  - With no phrase, nothing about her prompt changes (tested).
- **The sidebar's highlight is a lens** (`MainTabView.swift`). At rest it
  is Apple's glass, tinted lime, lying over the rows. It can be carried
  by pressing and sliding, and settles on the nearest row.
- **Files William sent this evening** are in `Design/Reference`: four
  screenshots and his recording of the bottom bar in Apple's Music app.

## Waiting on one thing

William wants the highlight to magnify and bend what is under it as it
moves, like the lens on the tab bar in Apple's Music app.

- Apple does not offer that lens as a separate piece. The public glass
  (`glassEffect`, `Glass.regular`, `.clear`, `.tint`, `.interactive`,
  `GlassEffectContainer`, `glassEffectID`, `glassEffectUnion`) was
  checked in the SDK on William's Mac (Xcode 27.2). In the simulator,
  clear glass frosts what is behind it. It does not magnify it.
- On iPhone the app uses Apple's own tab bar, which has the real lens.
- For the sidebar the bending is written as a small program for the
  graphics chip, `Design/Shaders/Lens.metal`, called by `LensRefraction`
  in `MainTabView.swift`.
- **It was switched off at this point**, because Xcode cannot build a
  `.metal` file without the "Metal Toolchain". That was installed later
  the same night and the lens is now on. See the section above.
- To switch it on: install the toolchain
  (`xcodebuild -downloadComponent MetalToolchain`), move `Lens.metal`
  into the `Windfall` folder, set `isBuilt` to true, build.
- ⚠️ The program has never been built or seen running. Expect to tune it.

## A checking aid

Starting the app with `-sidebarLensHeld YES` leaves the lens lifted and
between two rows, so a still picture can show the bending.

## Design work, not code

Four options for the Year page are on the design canvas ("Windfall
redesign"): dots, ribbons, every job on one line, and this month first.
William has not chosen yet. The Year screen in the app is unchanged.

# 12 November 2026, evening: the visual design

**This is the `visual-design` branch.** It sits on top of `garden-editor`.
It builds on the Mac for macOS, iOS and the iOS Simulator, and has been
looked at on the Mac and in the iPhone, iPad Pro and iPad mini simulators.
William has tried it in the example garden. **It has not been run with
his real records.**

## Why

William has concept art for how Windfall should look (doc 15 in the
knowledge base, and `Design/Reference`) and asked for it to be built with
Apple's liquid glass, with Eira as a floating button.

## What is new

- **A theme** (`Theme.swift`). Every colour has a name, a light value and
  a dark value. Screens ask for `Theme.paper` or `Theme.leaf` and never
  write a colour of their own. Titles use a serif face at medium weight
  and body text is regular weight, after William found the concept art
  "too bold".
- **Icons** (`Design/Icons`). 35 icons redrawn as SVG files to match
  William's reference picture. Each is its own file, so one can be
  replaced without touching code.
- **Colours and icons are built by a script**,
  `Tools/design/build_design_assets.py`, from the `Design` folder.
- **The frame** (`MainTabView.swift`). A dark green glass sidebar on Mac
  and iPad, tabs on iPhone. One list of places drives both. The sidebar's
  highlight stretches and snaps between rows like a drop of liquid.
- **A new Today screen** (`TodayView.swift`) replacing `DashboardView`:
  the date, a conditions card, six capture buttons, this month's jobs
  with tick boxes, garden plans, recent records with Confirmed and
  Provisional tags, and an offer to write a journal entry from what was
  logged that day.
- **Garden plans drawn to scale** (`GardenPlanView.swift`) from the
  measurements on each record: beds, planted sections, sheds, ponds,
  trees, things outside the boundary, dimension lines and a compass.
- **A first garden editor** (`GardenEditorView.swift`): a form for the
  plot, each bed and each feature, with the plan redrawing above it and
  hours of direct sun for each bed this month.
- **A compass** (`CompassRose.swift`). On iPhone and iPad it can follow
  the device, turning the plan to match the ground, and can set which way
  a plan faces. ⚠️ Not tested: neither the Mac nor the simulator has a
  compass.
- **Eira's floating button** (`EiraFloatingBar.swift`, `Snowdrop.swift`).
  Her snowdrop sits bottom right. Tapped, it is blown across to the
  sidebar, bumps against it and settles, drawing out a bar to ask, search
  or open anything. The snowdrop is William's own drawing, kept as shapes
  so the stem can lean and the flower head can swing.
- **Paper behind every screen.** Each titled screen gained one line,
  `.paperScreen()`.
- **An example garden** (`DemoGarden.swift`), shown only when the app is
  started with `-demoGarden`. It lives in memory and never touches real
  records.

## Decided along the way

- Eira opens blown by the wind. The rolling version is in
  `Design/Archive` with its code.
- The bar runs the full width, across to the sidebar.
- "Plans" was left out of the sidebar, because it looked like the same
  place as "Gardens".
- The Eira tab is gone. She is reached from her button on every screen.

## Not done yet

- Icons still to draw: bird, newt, blossom, leaf, seeds, fruit,
  vegetable, snow.
- Jobs in "This month" are worked out from records. You cannot yet add
  your own.
- The Photo button opens "Identify from a photo", which cannot identify
  anything yet.
- The older screens have the paper background and green tint but are
  otherwise unchanged.
- The garden editor is a plain form. Gardens cannot be added and beds are
  still added in Gardens, then Beds.
- No app icon.

---

# Overnight, 11 to 12 November 2026: the workings behind the garden editor

**This is the `garden-editor` branch.** It is kept apart from
`eira-on-device` so the version being tested is not disturbed. Checked
here (200 logic tests pass) but **not yet built in Xcode**. No screen has
changed, so the app looks the same.

## Why

William wants to draw each garden from measurements, set which way it
faces, add things inside and outside it, and see where shade falls. The
app had two gardens written into the code and a map that drew every new
bed in the same corner.

## What is new

- **`GardenLayout.swift`: gardens and features as records.**
  - A `Garden` holds its name, size, which way the top of the plan faces,
    slope, soil and location. The allotment and the permaculture garden
    are made as records the first time the app opens. More can be added.
  - A `GardenFeature` is anything on the plan that is not a bed: path,
    shed, greenhouse, compost, water, tree, hedge, fence, building. It
    has a position, size, rotation and height. A negative position puts
    it outside the plot, such as a neighbour's tree.
  - A feature can be marked as see-through (a fruit cage) so it is drawn
    but casts no shade.
- **Beds have a height**, so a tall raised bed or bean frame can shade
  its neighbours.
- **`SunAndShade.swift`: where the sun is and where shadows fall.**
  Plain arithmetic with no database or screens in it.
  - The sun's height and compass direction for any latitude, day and time.
  - The outline of the shadow each object casts.
  - Hours of direct sun on a bed, for a day or for each month.
- **Help for the editor:** a check for beds that overlap, and a way to
  spread out beds that have never been placed.
- **Backups carry the layout.** The backup file now holds gardens,
  features and each bed's position, size, rotation and height. Before
  this, a restored backup lost where every bed was. Older backup files
  still restore.
- **Eira's fixed safety replies were fact-checked** and now name UK
  sources. See the comments in `EiraSafety.swift`.

## How beds find their garden

Every bed already stores a short piece of text saying which garden it is
in: "allotment" or "permaculture". Each `Garden` record has a `siteKey`
holding the same text. So no existing record had to change.

## Not done yet

- The screens still use the old fixed list of two gardens. The editor
  screen and a map that draws to scale come next, and need Xcode.
- The existing map turns a bed about its middle. The new sums turn it
  about its first corner, the one you measure. The map must follow.
- Shade ignores the slope and treats a bare tree like one in leaf.
- Found on the way: frost records are written to the backup file but
  never restored from it. Not fixed here.

---

# Later on 11 November 2026: three more safety rules in code

Written away from the Mac. Checked here (138 logic tests pass) but
**not yet built in Xcode**.

**Why:** the mushroom question showed the model follows its "never"
rules most of the time, not every time. Three more rules are serious
enough to take away from the model completely:

- **Preserving.** Questions asking for canning, bottling, pickling or
  kitchen blanching times, temperatures or safety get fixed wording that
  points to a tested, published recipe. Garden blanching (keeping light
  off celery, endive or leeks) still goes to the model.
- **Pesticide amounts.** Questions asking how much slug pellet,
  weedkiller, pesticide or homemade spray to use get fixed wording that
  points to the label and offers chemical-free ideas.
- **Medicine.** Questions asking for doses, remedies or medicinal uses
  get fixed wording that points to a GP, pharmacist or qualified
  medical herbalist.

**How it works:** `EiraSafety.swift` tidies each question (lower case,
punctuation turned into spaces) and looks for two halves together, such
as a preserving word and a time word. Needing both halves keeps ordinary
gardening questions reaching the model. The model's own rule 12 is still
there as a second line of defence for anything the word lists miss.

**Known gap:** "How long do I can tomatoes?" is not caught, because
"can" on its own appears in too many ordinary questions. Rule 12 covers it.

⚠️ CHECK: the sources named in the preserving reply and the point that
UK pesticide labels are legally binding were written by Claude from
general knowledge.

---

# Changes on 11 November 2026

These came out of the first evening of building and running the app on
the Mac. The older notes follow below and describe how things stood on
10 November.

## The app builds and runs

- The Xcode project from the Mac is now in the repository.
- Three fixes were needed for the first build: a `Section` form SwiftUI
  does not offer (`SurveyViews`), a missing `import SwiftData`
  (`MainTabView`) and two main-actor warnings (`ExportService`).
- Opening Eira crashed because `Info.plist` gave no reason for using
  speech recognition. Reasons for speech, the microphone and location
  were added, and the matching Mac sandbox permissions switched on.

## Google is gone

- No sign-in, no welcome screen, no Sheets reader or write-back and no
  GoogleSignIn package. The app opens straight into the garden.
- Reference data now comes from `Windfall/StarterData.json`, loaded on
  first launch, or from a JSON or CSV file chosen in
  Settings > Garden data.
- The app's own database is the master copy and stays on the device.

## Eira

- Questions about eating fungi or naming a mushroom get fixed wording
  from `EiraSafety.swift` and never reach the model.
- `lookup_species` tries your own records, then GBIF, then Wikipedia to
  turn an everyday name into a scientific one.
- Return sends a message. Shift-Return starts a new line.
- Pop-up sheets have a size on the Mac. Past conversations had opened as
  an empty sliver.
- Voice permission is asked for when the microphone button is tapped,
  not when Eira opens.
- A failed save is shown on screen.

## Checks

107 logic tests, including an import of the real starter data.

---

# What changed, and why

This file lists every change made to the Windfall source since the files
were attached on 10 November 2026. Newest first.

How to read the history: the very first commit in this repository holds
the 39 files exactly as attached. Every change below is a later commit,
so GitHub and Xcode can show you each one line by line.

---

## Eira on the device (10 November 2026, branch `eira-on-device`)

**The aim:** Eira runs entirely on the device in your hand. No server,
no Ollama, no Tailscale. This is new work, kept on its own branch so it
cannot disturb the first build of `main`.

**Needs:** Xcode 27 and iOS 27, iPadOS 27 or macOS 27 for Eira herself.
Built with Xcode 26, the app still builds and Eira explains what she
needs. A device needs at least 12GB of memory to run her.

### Removed

- `EiraBackend.swift`, which held the code that talked to a model server.
- The server address setting, and every mention of Tailscale and Ollama.
- Sending photos to a server for identification (see "Not done" below).

### New files

| File | What it holds | Checked how |
|---|---|---|
| `EiraEngine.swift` | Message shapes, the `EiraEngine` interface, the 12GB rule, the model choice, where models are kept | Type-checked and tested |
| `EiraConversation.swift` | Runs one conversation: sending, streaming, stop, saving, memory management, corrections | Type-checked and tested |
| `EiraChatStore.swift` | Saved conversations and corrections (three new record types) | Type-checked and tested |
| `EiraWebLookup.swift` | Wikipedia lookup and reading a web page, straight from the device | Type-checked and tested |
| `EiraOnDeviceEngine.swift` | Runs a model through Apple's Foundation Models framework, with Core AI underneath | Checked against a stand-in only |
| `EiraMLXLoader.swift` | Optional: loads a model by name with MLX | Syntax only |

### Changed files

- `EiraTools.swift`: two new tools, the tool hub, the garden notes and
  rewritten standing instructions.
- `EiraChatView.swift`: rebuilt around the new engine. Adds a stop
  button, past conversations, "Correct this" and model settings.
- `EiraVision.swift`: server code removed. The screen can still save a
  photo as a sighting.
- `WindfallApp.swift`: three new record types in the schema, now 25.

### How Eira now works

1. **One interface.** The chat screen only talks to `EiraEngine`. Which
   model sits behind it is a setting: Apple's built-in model, a Core AI
   model or an MLX model. An "online service" entry exists as an empty
   slot and does nothing yet.
2. **Apple's framework runs the tools.** Each lookup is described to the
   framework, which lets the model call it and passes the answer back.
   This replaces the hand-written loop that had the multi-step bug.
3. **The 12GB rule.** Checked before any model is loaded. Below it, the
   chat says so and the rest of the app carries on.
4. **Standing instructions built fresh each time**, with today's date,
   the season, your garden notes and your recent corrections filled in.
5. **Memory management.** When a conversation outgrows what a small
   model can hold, older turns are shortened, old lookups are dropped
   and the model is restarted with that summary.
6. **Stop really stops.** The send button becomes a stop button while
   she replies, and what has arrived is kept.
7. **Conversations are saved**, which Handoff and iCloud sync will need.
8. **Corrections are kept.** Press and hold a reply, choose "Correct
   this", and she is told that fact at the start of every conversation
   from then on.
9. **Online lookup from the device.** Wikipedia and reading a single web
   page, both labelled as unverified. Species names still go to GBIF.

### Two faults the checks caught in my own new code

Worth recording, because it shows what the checks are for.

- The page-reading code used a pattern the system would have rejected,
  so every page came back empty. A test caught it.
- A helper was fenced to the main thread but used from a record type
  that is not. The compiler caught it.

### Not done on this branch

- **Photo identification.** Needs a vision model run by Core AI. The
  package has one (`CoreAIVisionLanguageModel`). It is the next piece.
- **Handoff to the Mac.**
- **Tools that add or change records.** Eira can only look things up.
  Her instructions tell her never to claim she has saved anything.
- **General web search.** Needs a search service. The socket for one
  (`WebSearchProvider`) is in `EiraWebLookup.swift`.
- **Saved chats in the backup file.**

### What to expect on the first build

`EiraOnDeviceEngine.swift` and the screens have never been through
Xcode. The framework calls were written from Apple's own published
source and tests, read on 10 November 2026, and then checked against a
small imitation of that framework. That proves the code is consistent
with what was read. It does not prove Apple's real framework matches.
Expect a handful of small corrections, most likely in that one file.

### Setting up in Xcode (after `main` builds)

1. Add the package `https://github.com/apple/coreai-models` and choose
   the product **CoreAILM**. This is what runs Core AI models.
2. Optional: add `https://github.com/ml-explore/mlx-swift-lm` for MLX
   models. Not needed to begin.
3. In Signing & Capabilities add **Increased Memory Limit** (needs the
   Apple Developer Programme) and, on the Mac, **Outgoing Connections
   (Client)** so lookups can reach GBIF and Wikipedia.
4. In Info, add `UIFileSharingEnabled` and
   `LSSupportsOpeningDocumentsInPlace`, both set to YES. These make
   Windfall's Models folder appear in the Files app on iPad.
5. Start with **Apple built-in** in Eira's settings. It needs no
   download and no package, so it is the quickest way to see her work.

---

## Corrected set (10 November 2026)

**The aim:** make the 39 files agree with each other so the project can
build. Nothing new was added and no design was changed.

**How it was checked:** see "How this was checked" at the end.

### 1. `WildlifeModels.swift`: sighting record renamed

- **Change:** the record type `Observation` is now `WildlifeObservation`.
- **Why:** Apple has its own framework called Observation. Two things
  with one name confuse the compiler. Eleven other files already used
  the new name, so this file was the odd one out.
- **What the code means:** a "type" is a kind of record. Renaming it
  changes what every other file calls it, which is why all files must
  agree.

### 2. `WildlifeModels.swift`: photos link added

- **Change:** `var photoIdentifiers: [String]` was replaced by a link to
  the `Photo` record:
  ```swift
  @Relationship(deleteRule: .cascade, inverse: \Photo.observation)
  var photos: [Photo]? = []
  ```
- **Why:** photos used to be remembered as a list of text labels. They
  are now proper `Photo` records, and `Journal.swift` expects a sighting
  to link to them.
- **What the code means:**
  - `@Relationship` tells SwiftData that two record types are linked.
  - `inverse: \Photo.observation` names the matching link on the other
    side, so each photo knows which sighting it belongs to.
  - `deleteRule: .cascade` means deleting a sighting also deletes its
    photos, so none are left orphaned.
  - `[Photo]? = []` is an optional list that starts empty. iCloud sync
    requires links to be optional.

### 3. `WildlifeModels.swift`: missing field added

- **Change:** added `var associatedPlantName: String?` to
  `WildlifeObservation`.
- **Why:** five files read or write this field (the sightings screen,
  backup, export, sheet sync and Eira's tools) but it was never defined.
  The project could not have built without it.
- **What the code means:** the sighting keeps the plant's name as plain
  text as well as the link to the plant record. If the plant is later
  removed from the library, the sighting still says what it was on.
  `Survey` already does the same with `targetPlantName`.

### 4. `PlantModels.swift`: photos links added to three records

- **Change:** `PhenologyEvent` and `PestDiseaseEvent` swapped
  `photoIdentifiers` for a `photos` link. `Harvest` gained a `photos`
  link it never had.
- **Why:** the same reason as change 2. `Journal.swift` defines the
  `Photo` side of all three links, and a link must exist on both sides.

### 5. `AuthenticationManager.swift`: moved to `@Observable`

- **Change:** `class AuthenticationManager: ObservableObject` with
  `@Published` properties became `@Observable final class
  AuthenticationManager` with plain properties.
- **Why:** these are two generations of the same idea. Both let a screen
  redraw when sign-in state changes. The settings screen already asked
  for the newer kind, and an app must use one kind consistently.
- **What the code means:** `@Observable` watches every property
  automatically, so `@Published` is no longer needed. `final` means no
  other class can build on this one, which the compiler likes.

### 6. `RootView.swift` and `SignInView.swift`: new wiring

- **Change:** `@EnvironmentObject var authManager` became
  `@Environment(AuthenticationManager.self) private var authManager`,
  and the previews use `.environment(...)`.
- **Why:** this is how a screen asks for an `@Observable` object. It
  goes with change 5.

### 7. `WindfallApp.swift`: full record list and shared objects

- **Change:**
  - The schema now lists all 22 record types. It listed 13.
  - `@StateObject` became `@State`, and `.environmentObject` became
    `.environment`.
  - A `LocationManager` is now created and handed to every screen.
- **Why:**
  - A record type missing from the schema is silently never saved.
    Nine were missing, including the diary, photos and reference data.
  - The wiring change goes with change 5.
  - Two screens ask for the location manager. Without it the app would
    crash when either opened.
- **What the code means:** the schema is the list of record types the
  app is allowed to store. `.environment(...)` passes a shared object
  down to every screen.

### 8. `EiraChatView.swift`: two small fixes

- **Change:** the manual lookup buttons now build their request with
  `JSONSerialization` instead of pasting text into a string by hand.
  An unused name was also removed to clear a compiler warning.
- **Why:** typing a quotation mark into the box used to break the
  lookup, because the hand-built text was no longer valid.
- **What the code means:** JSON is a standard way of writing structured
  data as text. Letting the system write it means special characters
  are handled properly.

### 9. `docs/windfall-manifest.md`: heading corrected

- The heading said 33 files. The tables list 39, and 39 is right.

---

## Known problems that were deliberately left alone

These live in the part of Eira that talks to a model server. That part
is being replaced by on-device models, so mending it would be wasted
work. The replacement is on the `eira-on-device` branch.

1. Multi-step lookups are likely to fail, because the model's request
   for a tool is not recorded in the conversation.
2. Changing the model settings has no effect until the chat screen is
   reopened.
3. With no server address set, sending a message does nothing.
4. Conversations are not saved.
5. Tailscale and Ollama are still mentioned in three files.

One more thing to know: if the Xcode project is ever switched to "Swift
6 language mode", `EiraTools.swift` will need a small change. It is fine
in the default mode.

---

## How this was checked

There is no Mac in the place this work was done, so the app itself was
not built. Three things were done instead, and you can repeat them with
`Tools/checks/run-checks.sh`.

1. **Syntax check, all 39 files.** Each file was read by the real Swift
   parser (Swift 6.2). All pass.
2. **Full type check, 17 files.** The files that hold the app's logic
   were compiled with screens removed and small stand-ins for Apple-only
   types. All pass with no errors and no warnings. Run on the files as
   originally attached, the same check fails, which shows it catches
   real faults.
3. **Cross-file checks, all 39 files.** Every record type is in the
   schema. Every link between records exists on both sides. No screen
   uses a property that a record lacks. iPhone-only and Mac-only code is
   fenced off for the right platform.

**What this does not prove:** that the app builds. The 22 screen files
were only syntax-checked and cross-checked, because SwiftUI does not
exist outside Apple's platforms. Expect some errors on the first build
in Xcode. They should be few, and each one will be explained as it is
fixed.
