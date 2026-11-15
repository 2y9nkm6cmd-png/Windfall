# 15 November 2026, 16:50: a UK wildlife reference, with a drawing for each kind of animal

**By the "wildlife rows" chat, from William's iPad, in a cloud workspace. Not built in Xcode.** William, 15:58: "It would be good if you could create a sheet with all wildlife that you could encounter in the uk in it. With drawings." Asked three things, he chose: in the app, the animals Eira can name, and one drawing for each kind. Made on the branch `uk-wildlife-reference`, on top of `species-rows-open` (the entry below), because both change `FaunaViews.swift`.

**Before.** Wildlife, Species listed the 21 animals of William's own Fauna sheet and nothing else.

**Now.** The Species page opens with "All UK wildlife": 4,180 animals in 83 kinds, each kind with a drawing. His own 21 are still there, under "Your species", and 19 of them now show their kind's drawing.

| File | What it is, and why |
|---|---|
| `WildlifeReference.json` (new) | The list that ships inside the app: every animal with 20 or more research-grade UK records on iNaturalist, fetched 15 November 2026. Each has its names, kind, family, order, count of UK records and its count in each month. Field names are one letter to keep the file small |
| `WildlifeReference.swift` (new) | Reads the list and answers questions about it: the kinds under their headings, a kind's animals, an animal by scientific name, search, and the months an animal is about in, in words. No drawing code, so it is tested without a Mac. **The list is read from the file and never written into the database**, so it cannot be muddled with William's records and costs iCloud nothing |
| `WildlifeBookViews.swift` (new) | Three pages. `WildlifeBookView`: the kinds as tiles under headings, with a search box. `WildlifeKindPage`: one kind's animals, most recorded first, with a switch for "only those recorded in November". `WildlifeAnimalPage`: one animal, with twelve bars for the months it is recorded in and a link to William's own notes when he has it |
| `FaunaViews.swift` | A row at the top opens the new pages. "Species" is headed "Your species". Each of his species shows its kind's drawing, found by scientific name, and its page has the drawing and a link to its months |
| `Assets.xcassets/Wildlife` (new) | The 83 drawings, each light and dark |
| `Tools/data/wildlife_kinds.py` (new) | The 83 kinds and the rules that sort an animal into one, from its family, order and class |
| `Tools/data/build_wildlife_reference.py` (new) | Makes `WildlifeReference.json` from what was fetched |
| `Tools/data/wildlife/` (new) | What iNaturalist returned, the three scripts that fetched it and a READ-ME |
| `Tools/design/wildlife_kit.py`, `wildlife.py` (new) | The drawing kit and the 83 drawings. An animal is built from simple shapes joined into one outline, with patches of colour cut to fit. **They need the Python library `shapely`** (`pip install shapely`), the first of the drawing scripts to need anything beyond Python |
| `Tools/design/build_design_assets.py` | `build_wildlife()` copies `Design/Wildlife` into the app's store of pictures |
| `Tools/checks/LogicTests.swift`, `logic-files.txt` | 19 new tests |

**What the code means, in short.**

- `struct WildlifeAnimal: Decodable`: a `struct` is a bundle of values. `Decodable` means Swift can fill one in from a JSON file by itself. `CodingKeys` tells it that the file's `"s"` is `scientificName`, and so on.
- `static let shared`: the list is read once, the first time anything asks for it, and kept.
- `placesByKind` and `placeByName` are look-up tables made once when the list is read, so finding a kind's animals or one animal by name does not mean walking through four thousand rows each time.
- `isAbout(inMonth:)` returns true, false or nothing (`Bool?`). Nothing means the months were not fetched for that animal. The pages keep such an animal when filtering by month, because leaving it out would claim something the list does not know.
- Every link in the new pages is `NavigationLink { page } label: { row }`, the kind that carries its own page (see the entry below).

**⚠️ CHECK, all Claude's:**

1. **The names are iNaturalist's.** Some are not the usual British ones: "Nightcrawler" for the lob worm, "Common Wood-Pigeon", "Buff-tailed Bumble Bee". 780 animals have no common name and are shown by scientific name.
2. **The 83 kinds, their names and their headings**, and every rule in `wildlife_kinds.py`. Some kinds are catch-alls: "Other birds" holds wagtails, pipits, larks, starling, kingfisher and cuckoo. The slow-worm is with the snakes because it looks like one. Gall makers gathers gall wasps, gall midges and gall mites.
3. **The 83 drawings.** Each is a picture of a kind, drawn as one typical member: the bumblebee is a buff-tailed, the tit a blue tit, the thrush a robin. Claude's weakest: the sea snail, the badger, the deer and the squirrel.
4. **"About in a month" means at least 2 in 100 of its records fall in it.** The level is the one Eira's photo rules use. Records follow where and when people look, not only where animals are.
5. **The list is what iNaturalist's recorders have photographed**, so it holds a domestic cat, a horse and a walrus, and misses anything rarely photographed. It should be nearly the animals in the image model's list of 6,421 names, which was cut by the same rule the day before, but the two were fetched a day apart and were not compared.
6. **His own list is not joined to this one.** A species in both is linked by scientific name only. Two of his 21 are not in the UK list: "Andrena spp." (a group, not a species) and *Myrmica sabuleti*.

**Checked:** Windfall's own checks in a cloud workspace (Swift 6.3.1 for Linux): 126 files parse, type check passes, cross-file checks clean, 890 logic tests pass. The drawings were looked at by Claude as a sheet, light and dark. Rebuilding the picture store changed no existing picture.

**Not checked:** a build. No screen in `WildlifeBookViews.swift` or the changed `FaunaViews.swift` has been compiled or seen. How long a list of 580 moths takes to open. How the drawings look at 40 points in a row.

# 15 November 2026, 16:05: a species opens when its row is tapped

**By the "wildlife rows" chat, from William's iPad, in a cloud workspace. Not built in Xcode.** William, 15:58, with a picture of Wildlife, Species on the iPad, the Campion moth row grey: "Nothing happens when you tap the wildlife". Made on the branch `species-rows-open`, from `main` at `6cbfc37`.

**Before.** In `FaunaListView` a species row was `NavigationLink(value: animal)`. That kind of link only hands over the record. Which page a record opens is said once, somewhere else, by `.navigationDestination(for: Fauna.self)`. When a link of this kind cannot find that line, the row goes grey, stays grey and nothing opens, which is what the picture shows.

**Now.** Each row is `NavigationLink { FaunaDetailView(fauna: animal) } label: { ... }`: the link is given its page outright. It is the same kind of link as "Flower shape coverage" and "Cascades" two rows above it, and as the latest sightings on the Wildlife page. The `.navigationDestination(for: Fauna.self)` line is gone from this page, because nothing uses it any more. Search still has its own.

| File | What changed |
|---|---|
| `FaunaViews.swift` | The species rows carry their own page. One line removed |

**⚠️ Not proven.** Why the link could not find the line is not known. The page is opened from a tile on Wildlife, by `GrowingLink`, and that may be what hides it. It could not be run where this was written. **The same pattern is in four other lists** opened the same way: Sowings (`PlantingViews.swift`), Seed (`SeedViews.swift`), Surveys (`SurveyViews.swift`) and Beds (`BedViews.swift`). They are left alone until William has tapped a row in each (checklist card `w-rows-other`). Plants and Sightings use it too. William has worked on plant pages on the phone since and has not reported them failing, so they are taken to open.

**Checked:** see the knowledge-base doc for this chat. **Not checked:** a build, and a tap on a device.
# 15 November 2026, 16:40: the corner drawing rests when it cannot be seen, and two jobs stop being done for nothing

**By the "power efficiency" chat, linked to the Mac. Branch `power-quiet`, made from `main` at `a2744bb`.** The research behind it is doc 91 in the knowledge base. William, 16:16: "Make the changes that will not affect speed or make the app quicker."

**Why.** Measured on the Mac at 15:28: with a web browser in front of it, Windfall was spending 16% to 24% of one processor core, and the only code of its own that was running was the drawing in Today's corner, about thirty times a second. Nothing here changes what the app does. Each change stops work whose result nobody would have seen.

| File | What changed, and why |
|---|---|
| `LivingCorner.swift`, `LivingCorner` | New `isResting`, which decides when the drawing holds still. It did so for Reduce Motion and when the app was put away. It now also rests when its page has left the screen (`isOnScreen`, set by `onAppear` and `onDisappear`), when a sheet is up over Today (`cornerIsCovered`) and, on a Mac, when Windfall's window is not the one in use (`appearsActive`). A paused `TimelineView` keeps its last picture, so the drawing stays where it was and carries on when it can be seen again. The last three wait for `hasGrownIn`, four seconds after the drawing appears, so that a plant is never left standing half grown: found when a copy started behind another window drew for less than a second, which by the code leaves the plant at its first moment of growth |
| `LivingCorner.swift`, `cornerIsCovered` | A new setting handed down through the environment, the way `paintsGlassFlat` is in Theme.swift. A page that puts something over the drawing sets it to true |
| `LivingCorner.swift`, `CornerMeter` | A checking aid, off unless the app is started with `-cornerMeter YES`. It counts the pictures drawn each second and writes the count, with the time, to `windfall-corner-meter.txt` in the app's temporary folder. A second with no drawing writes nothing, so a gap in the times is a rest |
| `TodayView.swift`, `header` | Sets `cornerIsCovered` while the capture sheet or the Add a job sheet is up |
| `VoiceInput.swift`, `WaveformView` | The wave is capped at thirty pictures a second with `minimumInterval`. It was redrawn as often as the screen could manage, up to 120 times a second on some iPads, for a ripple that takes a whole second |
| `WindfallShared/WidgetSummary.swift`, `showsTheSame(as:)` | New. Says whether two summaries would put the same things on every widget. It leaves out `written`, and fractions of a second in `forecastFetched`, because the file keeps times to the whole second |
| `WidgetShare.swift`, `refresh` | Reads the file first and, if what it was about to write `showsTheSame`, writes nothing and does not ask the widgets to redraw. It runs on every coming to the front, every putting away and every quarter of an hour, and most of those times nothing has changed |
| `WeatherDiary.swift`, `bringUpToDate` | New `askedAnything`. When every garden was resting (asked within the hour, with today's record held), no day can have changed, so the last step, reading every day and every frost record to look for new frosts, is skipped. When and what the weather service is asked is exactly as before |

**On a Mac the drawing now stops when another app is in front.** That was Claude's suggestion in doc 91 (Decision 1, option A) and William has not yet answered that card. It is one line, `if !appearsActive { return true }`, and is easy to change to a slow sway or to take out.

**Left out on purpose**, though they were on doc 91's list:

- **A rougher location fix for the weather.** William has reported that no location services seem to be working. Changing the location code now would make that harder to find.
- **Asking the database for today's weather record alone.** It needs a kind of question (`#Predicate`) the logic tests cannot run, so the code that shipped would have been untested, in the part of the app with an open fault. The frost step above is the half of that saving that can be tested.
- **The Journal built a day at a time.** Two other chats changed how the Journal's page ends today, one of them not yet built. There is nothing to gain until the journal holds more than a few days.
- **Eira's reply shown a few words at a time.** It changes how her answer looks, and William has not said he wants that.

**Checked.**

- Windfall's own checks in the cloud workspace (Swift 6.3.1 for Linux): 124 files parse, the type check of the logic files passes, cross-file checks clean, 871 logic tests pass. Eight more checks of `showsTheSame`, run by hand there, pass: a summary read back from the file is not equal by `==` (the fraction of a second) and does show the same, and a newer forecast, a colder night, a job gone or a moved place each count as a change.
- Builds with no errors for the Mac and the simulator, unsigned, in this chat's own copy (`pw1` and `pw2` logs, 16:36 to 16:41). No warnings from the new code. These were also the first builds of the iPad strip change of 16:05, which builds.
- **On the Mac, like for like**: a copy started behind another window with the example garden, read with `top` from 22 seconds after starting. `main` of 15:26: 12.8%, 15.7%, 16.0%, 15.2% and 14.4% of one core. This branch: 0.5%, then 0.0% four times. The counter shows it drawing 27, 31 and 30 times in its first three full seconds, while the plant grew in, and not once in the half minute after.
- **In an iPhone simulator**, with `-motionTour places`: about 30 draws a second on Today, none during the seconds the tour spent on the Journal, Gardens and Wildlife, and 30 again each time it came back to Today.

**Not checked.** The Mac's window in use: nobody has seen that the drawing moves again when Windfall is clicked, since that would have meant taking the screen from William. A sheet over Today, and a plant's page over Today. A real iPhone or iPad. The widgets, which the simulator and an unsigned Mac copy do not run. Whether the iPhone already rested the drawing on another tab before this change: only the new build has a counter.

# 15 November 2026, 16:05: on an iPad, pages stop at Eira's bar again and no longer scroll on past their end

**By the "scrolls too far" chat, from William's iPad. Branch `bar-strip-inside-stack`, made from `main` at `6cbfc37`. Joined into `main` at 16:05 the same day (`78276c7`), at William's word (16:03: "Let's add it to the main branch and push it out"). Written in Claude's cloud workspace: the Mac was not connected, so it has not been built or seen running, and `main` now holds a change no compiler for Apple's devices has read.**

William, 15:47, with a picture of the Journal on the iPad: "The journal app and settings app now scroll too far initially." Asked what he saw, he chose: the page opens at the top, but can be dragged up until a big empty gap sits above Eira's bar. Today, Gardens, Wildlife and Plants do it too. The keyboard had not been up.

**What the picture shows.** The last card of the Journal ends 334 points down a window 744 points tall, with the page at rest. Eira's bar begins at 650. So there are 410 points under the last card where there should be 114: the 20 points of air the page adds, the bar's strip of 74 and the 20 points at the foot of the screen. Take the page's own 20 away and the page had been told that 390 points along its bottom were taken. 390 is five strips of 74 and the 20 at the foot.

**The likely cause.** MainTabView keeps a strip clear for the bar with `safeAreaInset`, put round each place's `NavigationStack`. On an iPad the stack is Apple's older kind of screen with the SwiftUI page fitted inside, and the strip has to be handed across that join. Two things have now been seen there, both wrong: at 13:35 in the simulator the page was told nothing (the Journal's last entry sat behind the bar), and at 15:42 on the iPad every page was told about five times too much. **The count of five was worked out from one picture. It was not reproduced, and why it is five was not found.** Nothing in today's changes to `MainTabView.swift` alters how tall the strip is.

**The change.** On an iPad the strip no longer crosses the join. It is put on the page itself, inside the stack.

| File | What changed, and why |
|---|---|
| `MainTabView.swift`, `sidebarLayout` | New `barStrip`: the empty strip and its measurement, written once. On an iPad it is put on the place's page inside the `NavigationStack` (`#if !os(macOS)`). On a Mac it stays round the stack, as before (`#if os(macOS)`) |
| `JournalViews.swift`, `hiddenByBar` | The note says that an iPad's strip is now on the page, so the extra room it adds there should come to nothing. The sums are unchanged |

**Not changed:** the iPhone, whose strip is still round the stack on each tab. Nobody has reported it there. The Mac. Where the bar sits and how it opens.

**What this costs on an iPad.** A page opened on top of another (a plant, a bed, a page behind a Settings tile) is no longer told about the strip, so its last lines run to the foot of the screen and can sit under the bar's corner. Before 13:35 today the simulator showed those pages untold as well. Giving them the strip needs each of them to add it, or `paperScreen()` to, without also adding it to sheets: a job of its own.

**Checked:** Windfall's own checks in the cloud workspace (Swift 6.3.1 for Linux): 124 files parse, the type check of the logic files passes, cross-file checks clean, 871 logic tests pass. These checks read a screen's code for mistakes of grammar only. They cannot say whether the page now stops in the right place.

**Not checked:** a build of any kind. Anything on a screen. **To check on the iPad:** Journal, Settings and Today each scrolled to the foot (the last card should stop about 20 points above the bar), the same after changing place a few times, with the iPad upright and on its side, and with the sidebar hidden. If the gap is still there, the strip was not the cause and this change can be taken out again.

# 15 November 2026, 15:30: on Identify, a further photo joins the identification

**By the identify photos chat.** William, 14:05: "Can you make it so that when you're identifying plants, if you need to take another photo, the previous one is still stored as part of the identification". Made on the branch `identify-keep-photos`, from `main` at `143e24e`.

**Before.** The Identify screen held one photo. Take another, Another from Photos or a file threw the first away and put the new one in its place, so a sighting only ever had the last photo.

**Now.** A further photo is added. All of them show in a row, the image model looks at each, Eira judges them together, and every one goes on the sighting. Start again clears them for a different plant or animal.

| File | What changed, and why |
|---|---|
| `SpeciesTable.swift` | The matching is split into steps so that several photos can share it. `shares(for:)` gives every species' share for one photo. `averaged(_:)` averages several such lists place by place. `guess(fromShares:)` picks the closest few. `guess(forPhotos:)` strings them together. `guess(for:)`, the one-photo answer, now goes through the same steps and gives what it gave before |
| `SpeciesEye.swift` | `guess(forPhotos:)` puts each photo through the image model in turn and hands the lot to the table. `guess(forPhoto:)` calls it with a list of one. An unreadable photo stops the whole job, so an answer is never quietly to fewer photos than are on screen |
| `EiraIdentify.swift` | An answer remembers how many photos it came from (`photoCount`, 1 unless told otherwise). `photosLine` is the sentence the card shows for more than one. A sighting's note says "from 3 photographs" |
| `IdentifyCards.swift` | New `IdentifyPhoto`: one photo of an identification, with its smaller copy, its original and its own date and place. `EiraIdentify.identify(photos:)` and `startSighting(from:photos:in:)` take a list; the one-photo versions that Eira's chat and the journal use call them with a list of one. The card says "From 3 photos, weighed together: each figure is the average across them." |
| `EiraVision.swift`, `IdentifyView` | Holds a list of photos in place of one. One photo is shown large as before; two or more sit in a sliding row, each with a cross to remove it, and the row slides to the newest. The three ways of bringing a photo in add to the list (up to `mostPhotos`, 6). New Start again button. If Eira had already answered, she looks again by herself whenever a photo is added or removed. `lookNumber` makes sure an answer that arrives after the photos have changed is dropped |
| `DemoGarden.swift` | A checking aid, `-demoPhotoCopies 3`, brings the `-demoPhoto` in three times over so the row can be pictured in the simulator |
| `Tools/checks/LogicTests.swift` | Ten new tests: the averaging, one photo alone giving the old answer exactly, photos that agree, photos that disagree, a clear photo with a poor one, no photos, and the wording for several |

**Claude's choices, for William to confirm (checklist card `d-identify-photos`).**

1. **The photos are averaged.** Species by species, each photo's share is added up and divided by the number of photos. Two photos that agree stay sure. A sharp photo and a poor one come out in between. Two that disagree come out as "not sure". An average is never surer than its photos, and the "not sure" level (0.85, measured on single photos) keeps its meaning. The other way would be to multiply the shares, which rewards agreement but claims more than two photos of one plant can know. **Not measured on test photos either way**: there is no test set of several photos of one thing.
2. **Another photo always adds.** There is no "replace" any more: that is the cross on a photo, or Start again.
3. **Six photos at most**, because every original is held in memory until a sighting is started.
4. **The first photo dates the sighting** and gives Eira the month. Each photo keeps its own date on its own record.
5. **Eira looks again by herself** when a photo is added or removed after she has answered.

**Not changed:** Eira's chat and the journal's "what is this?". There each photo is still its own question with its own answer. A photo dropped on Identify still brings in only the first of several.

**Checked:** Windfall's own checks in a cloud workspace (Swift 6.3.1 for Linux): 123 files parse, type check passes, cross-file checks clean, 864 logic tests pass. Simulator and Mac, unsigned: BUILD SUCCEEDED (`windfall-build-logs/ip1-sim.log`, `ip2-mac.log`). Simulator pictures looked at by Claude (`shots/ip-one-iphone.png`, `ip-three-iphone.png`, `ip-three-ipad.png`, `ip-six-ipad.png`, script `idphotos-shots.sh`): one photo large with the four buttons, three and six photos in a row with a cross on each, the row slid to the newest, the lines of words under them. **The real image model, through the Mac build, on the same 300 UK photos as project doc 35** (`ip-species-regress.md`): first answer right 293, named outright 294 and of those right 290, the same as on 14 November, so one photo at a time is unharmed by the new route.

**Not checked:** the real image model on more than one photo (the simulator cannot run it, and nobody has pressed the buttons on a device). Adding, removing and Start again by hand. A sighting made from several photos, opened afterwards. The row on the Mac's own window. The line on the answer card for several photos was not in any picture: it is below the fold.
# 15 November 2026, 14:45: Eira's bar and panel move steadily, and the bar no longer jumps when the page changes

**By the "steady animations" chat, on the Mac.** William, 14:06: "There's a bit of instability in the animations of the Eira movements, search bar appearing and transitioning between screens." Made on the branch `animation-steady`, from `main` at `143e24e`.

**How the causes were found.** A still picture cannot show an animation. A new checking aid, the motion tour (`MotionTour.swift`), presses the snowdrop and changes place by itself on a fixed timetable. The simulator was filmed while it ran (`windfall-build-logs/steady-film.sh`) and the films were cut into frames laid side by side (`steady-frames.sh`), on an iPhone 17 Pro and an iPad mini. Films and sheets are in `windfall-build-logs/films`: `st1-*` before, `st4-*` and `st5-*` after.

**Four faults were seen on film, and each is fixed.**

| What was seen | The cause | What changed |
|---|---|---|
| **Going to the Journal, Eira's bar sprang open in a single frame while the old page was still on screen. Leaving, it shut in a single frame before the Journal had gone.** On an iPad the open bar sat across Today for about a third of a second. On an iPhone the bar on the tab being left turned into the Journal's bar ("Tell Eira", with the book button) | Nothing animated the change. And an iPhone has a bar on every tab, all reading one shared note of "the newest page anywhere", so the bar on the tab being left answered to the page that was arriving | `EiraScreen.swift`: each page's note now says which tab it is on, and `current(in:)` answers for one tab. A tab that is off screen keeps what it last showed. `MainTabView.swift` names each iPhone tab with `.environment(\.eiraPlace, …)`. `EiraFloatingBar.swift`: the bar reads its own tab's page (`sight`), and `.animation(.smooth(duration: 0.35), value: onJournal)` draws it out or in over a third of a second, in step with the page |
| **On an iPhone or iPad, tapping the snowdrop sent it up the screen as a small circle, carried by the keyboard, and only then across.** Two movements, with a stall between as the keyboard was fetched | The keyboard was asked for a twenty-fifth of a second after the tap. It rises in about a third of a second. The snowdrop's own journey starts slowly and takes half a second or more | `EiraFloatingBar.swift`, `keyboardWillRise`, `keyboardTravelTime`, `open`, `move`: where there is no real keyboard attached, the bar draws out first on a quick spring (0.38 to 0.5 seconds) and the keyboard is asked for when it has all but arrived, so the keyboard lifts a finished bar in one piece. With a real keyboard, and on a Mac, nothing changes: the gust, the bump and typing at once are as they were |
| **Opening a conversation from the bar with the keyboard up made the keyboard drop away, the bar fall to the foot of the page and the keyboard come back, carrying the panel up again** | The bar was told to take no taps the moment the panel appeared (`allowsHitTesting(false)`). A text box that takes no taps gives up the keyboard at once. The conversation's own box then asked for it back | The bar goes on taking taps for as long as its own box has the keyboard, which is until the conversation's box takes it over, a moment later. It fades to one part in a thousand, not to nothing. A safeguard takes the keyboard from the bar's box after 0.7 seconds if nothing else has |
| **"Done" left an empty capsule where the bar should be, and the snowdrop and buttons then appeared in one frame.** On the way up they vanished in one frame | The panel was drawn on top of the bar, so the bar's fade in and out happened unseen underneath the panel's glass | The panel is now drawn underneath the bar. The bar fades out over the rising panel and back in over the sinking one |

**The motion tour, for any later work on movement.** Start the app with the example garden and `-motionTour bar`, `places`, `panel` or `all` (and `-motionTourWait 10` for how many seconds to wait first). It posts notifications that Eira's bar and MainTabView listen for, and each then runs the code a tap would run. It does nothing without `-demoGarden`.

**Tested by trying both ways.** The keyboard fault was pinned down with three films of one build, each with one thing switched: the conversation not asking for the keyboard (the keyboard still dropped, so the bar was losing it by itself), the conversation asking late, and the bar left able to take taps (the keyboard stayed). The switches were then taken out.

**Checked:** simulator and Mac builds, unsigned: BUILD SUCCEEDED (`st5-sim.log`, `st6-mac.log`, and `st8-*` after `main` was merged in). Syntax and cross-file checks pass (`st7-checks.log`). The new logic tests for `EiraScreen` (seven, in `LogicTests.swift`) were run by hand on the Mac with the three old ones and pass. The full type check and logic tests do not run on the Mac, as before. Films of the simulator after the change, all looked at: the bar drawing out and then rising with the keyboard on the iPhone, the bar opening in step with the Journal page on both, the outgoing tab's bar left alone on the iPhone, the panel rising and sinking with the keyboard still, and the bar fading back in.

**Not checked, and not fixed:**

- **Anything by hand, on any real device or on the Mac's own screen.** The simulator draws glass and blur slowly, so its films show the order of things and any jump, and say little about how smooth the real thing is.
- **The pause when changing place on an iPad or Mac.** On film the page stood still for 0.2 to 0.6 seconds after a place was chosen, and the melt to the new page was then already half over. It is the new page being built. It may be shorter or longer on the real iPad. It needs measuring there (Instruments, with the iPad plugged in) before choosing a cure: a lighter first frame for each page, or keeping pages alive once visited.
- **On an iPad the films still showed the snowdrop setting off late on its first outing**, while the simulator fetched its keyboard. Later outings were in order.
- **The Plants search glass on a Mac opens and closes with no animation at all** (`CollapsingSearch.swift`). Left alone: William's words may or may not have meant it.
- After "Done" on an iPhone the keyboard stays up, in the bar's box. It did before this change too.
- Today's corner drawing and the switch between garden plans arrive a moment after the page on an iPad.

# 15 November 2026, 14:08: on the Year page, month names turn on their sides where they do not fit

**By the "year months" chat.** William, 13:10, with a picture of the Year page on the iPad held upright: "On iPad this screen isn't working for me. Instead of the dots, could you make the months aligned vertically." Each month's column there is about 18 points wide and "Nov" needs about 26, so SwiftUI cut every name down to "…". Made on the branch `year-months-upright`, from `main` at `1c0ca84`, with `main` at `143e24e` merged in before it was joined.

| File | What changed, and why |
|---|---|
| `YearView.swift`, `monthHeading` | The heading is now handed to `ViewThatFits` in two versions: the names written across, then the names turned on their sides. `ViewThatFits` measures each and shows the first that fits the width, so a wide page looks as it did and a narrow one gets turned names. Nothing is set per device: an iPad on its side, an iPad Pro and a wide Mac window still read across, and a narrow Mac window turns them |
| New `monthRow(count:names:turned:)` | The row itself (the count of plants, then twelve buttons), written once and used for both versions. Its `HStack` is lined up on the bottom, so "125 plants" stays level with the foot of the names when the turned heading is taller |
| `YearMonthButton` | Takes `allNames` and `turned`. Its `label` is a `ZStack` holding all twelve names in bold and hidden, with the one that shows on top, so every column asks for the room the longest name needs. That is what makes `ViewThatFits`'s measurement true for twelve equal columns, and keeps the twelve the same height when turned. `fixedSize()` on the word means it is never cut to "…" again. A turned name sits at the foot of the heading and reads upwards |
| New `OnItsSide` (a `Layout`) | `rotationEffect` only changes how a view is drawn: the page is still laid out as if the word lay flat. `OnItsSide` asks the word how large it is flat, reports that size with width and height swapped, and puts the word in the middle, so the turned word takes the room it really covers |

**Left as it was:** the iPhone's single letters (J F M A…), the band down this month's column, the rows, and the month's own page that a name opens.

**Checked:** simulator build, unsigned, before the merge: BUILD SUCCEEDED (`windfall-build-logs/ym1-sim.log`). Simulator pictures (`windfall-build-logs/shots/ym-*.png`, script `yearmonths-shots.sh`, which makes simulators of its own): an iPad mini upright in dark shows the twelve names on their sides, each over its column, "Nov" bold in the band; an iPad Pro 13-inch upright shows them across, as before.

**Not checked:** a tap on a turned name, the Mac's own window made narrow, the largest text sizes, and the iPad with the sidebar hidden (the names should go back to reading across).

# 15 November 2026, 13:35: the Journal's last entry scrolls clear of Eira's bar

**By the "zoom still not right" chat, its second job.** William, 13:16, with a picture from the iPad: "In journal, because Eira's bar is there the whole time, the very bottom item is cut off. Could you make it so that you can scroll the posts above the bar?" Made on the branch `journal-clear-of-bar`, from `main` at `720efee`.

**The cause.** MainTabView keeps a strip clear along the bottom of every page for the bar (`safeAreaInset`), put round each place's `NavigationStack`. On an iPad that strip does not reach the page inside the stack: the Journal's scrolling stopped at the screen's own bottom edge, 74 points lower than it should, so the last entry rested behind the bar. A picture of the simulator before the change shows it (`shots/jb-before-ipad-end.png`).

| File | What changed, and why |
|---|---|
| `EiraScreen.swift` | New `barLine`: how far down the window the bar's strip begins. Kept on the tracker every page can already read |
| `MainTabView.swift` | Both strips (sidebar layout and iPhone tabs) report where they begin with `onGeometryChange`, which runs only when the measurement changes |
| `JournalViews.swift`, `JournalTimelineView` | New `hiddenByBar(_:)`: the page's own bottom edge less `barLine`, never under 0 nor over 120. That much is added under the last card, on top of the usual 20 points. Where the strip does reach the page the sum comes to nothing, so room is never added twice |
| `DemoGarden.swift` | A checking aid, `-startSection journal -demoJournalEnd YES`, opens the Journal already scrolled to its foot (`defaultScrollAnchor`) |

**Not changed:** every other page. Today, Gardens and the rest are laid out the same way, so on an iPad their last lines very likely stop 74 points low as well. It shows less there because the bar is closed to a small round button in the corner.

**Checked:** simulator build, unsigned: BUILD SUCCEEDED (`windfall-build-logs/jb2-sim.log`). Simulator pictures with the Journal scrolled to its foot (`shots/jb-after-ipad-end.png` on an iPad mini, `jb-after-iphone-end.png` on an iPhone 17e, script `journalbar-shots.sh`): the last card ends about 20 points above the bar on both.

**Not checked:** a scroll by hand on any device, the Mac's own window, the iPad on its side, and whether the iPhone ever had the fault (the "before" picture of the iPhone was lost: another chat was using the same simulator).
# 15 November 2026, 13:15: Eira's symbol is the app icon's snowdrop, in colour

**By the snowdrop chat.** William, 14 November: "Can we rebuild Eira's icon so it more resembles the snowdrop in the app icon?" On 15 November he chose option A of three drawn for him: "No bee in the Eira icon... it keeps its circle" and "I think A", the whole snowdrop in colour, and of the circle's colour "You used the right green" (project docs 72 and 83). Made on the branch `eira-snowdrop-a`, from `main`.

| File | What changed, and why |
|---|---|
| `Tools/design/eira_snowdrop.py` (new) | Copies the snowdrop's twelve outlines out of the icon's drawing (`Design/AppIcon/windfall-app-icon-light.svg`) and writes them into a Swift file, so nothing is retyped by hand and Eira's snowdrop cannot drift from the icon's. It stops if the icon's drawing has been rearranged, or if the light and dark icons disagree. With `preview` it writes pictures of the symbol, upright and leaning, to look at before a build |
| `WindfallShared/SnowdropArt.swift` (new, written by the script) | The outlines: stalk, three leaves, three petals, the three pieces of the inner cup, the V and the cap, in the icon's own numbers. Also where Eira's circle sits on the drawing: middle 200, 215 and 200 out to the rim, which trims the leaves |
| `WindfallShared/SnowdropDrawing.swift` (new) | The part written by hand. `SnowdropStyle` says what each part is painted with and how wide its line is: `onGreen` is the dark icon's drawing (cream lines, a cream outline round the flower) for a green circle, `onCream` the light icon's (green lines) for a cream circle, and `oneColour` for the Lock Screen. `SnowdropView` paints the parts on a `Canvas` in the icon's order. `SnowdropOnDisc` puts it on its circle. `SnowdropSway` holds the three points the plant bends at |
| `Windfall/Snowdrop.swift` | Now only `EiraSymbol`, which picks the style for light or dark mode, the wind (`SnowdropWind`, unchanged) and a checking page, `SnowdropSheet`. The old outlines from William's logo sheet, and the code that read them, are gone from here: the reading code moved to the shared file |
| `WindfallShared/WidgetViews.swift` | The widgets' second copy of the snowdrop (`WidgetSnowdrop`, flower and hook only) is gone. `WidgetEiraDisc` draws the shared one. A widget's set of colours no longer names a circle colour and a flower colour: it says which style suits it (`snowdrop`), and the Paper look leaves that to light and dark mode |
| `WindfallWidgets/WindfallWidgets.swift` | The Lock Screen circle shows the whole snowdrop in one colour, with the icon's lines as thin gaps |
| `Windfall/WidgetShare.swift` | The checking page has a page 3: `-demoOpen widgets -demoWidgetPage 3` shows the symbol at six sizes, both ways round, leaning, and in one colour |
| `Design/colours.json` and both asset catalogues | Three new named colours, the same in light and dark: `IconGreen` `#06421B`, `IconCream` `#FAEEE0` and `IconLeaf` `#C0D76D`. `EiraDisc` is now `#06421B` in light mode and `#FAEEE0` in dark (it was `#06472A` and `#F8F1E5`), and `EiraFlower` the other way round. Nothing in the code uses those two any more: the snowdrop takes its colours from the three Icon colours. They are left in place, with true values, because `Theme.swift` still names them and another branch is open on the lines beside them |

**Why a `Canvas`.** The old symbol was one colour, so each part was a SwiftUI shape and the colour came from outside. Now every part has a fill and a line of its own, in the icon's order, and the line widths are in the icon's numbers. A `Canvas` is a sheet the code paints on directly: it is lined up with the icon's numbers once, and after that each shape and width is given exactly as the icon gives it. The lean and the nod are three copies of the sheet, each turned a little more than the last.

**The sway is gentler.** The wind's own sums (`SnowdropWind`) are unchanged: up to 24 degrees of lean and about 46 of nod. The new flower fills far more of the circle than the old one, and at full strength it was thrown out of the circle. So the whole plant takes 0.15 of the lean about the point where the leaves meet the ground, the stalk a further 0.35 about its foot behind the tall leaf, and the flower head half of the nod about the stalk's tip. These three numbers are Claude's choice, from pictures of the furthest lean each way.

**Checked:** Mac and simulator builds, unsigned: BUILD SUCCEEDED (`windfall-build-logs/sd1-sim.log`, `sd1-mac.log`, and `sd2-*` after `main` was merged in). Syntax and cross-file checks pass (`sd1-checks.log`; the type check and logic tests do not run on the Mac, as before). Simulator pictures, all looked at (`windfall-build-logs/shots/sd1-*.png`): the checking page, Today on an iPhone 17 Pro and an iPad mini, Eira's chat, the journal's conversation and the Ask Eira widget in Paper and Garden green, in light and dark.

**Not checked:** the sway in motion (only still pictures of its furthest points), the symbol on a Mac's screen, a widget placed on a real Home Screen, and the Lock Screen circle, which iOS colours itself.

# 15 November 2026, 13:11: the plant drawings have solid lines, and stems sit behind leaves behind flowers

**By the "solid lines into the app" chat, on the Mac.** William, 12:19, with a picture of Achillea's "In flower" drawing zoomed in on the iPad: "The opacities used on the drawing of the flowers means that lines are passing through each other and looking a bit odd and more complicated than I think they should." The drawing code was changed in a chat on his phone (project doc 86). This entry puts that code and the redrawn pictures into the app. Branch `solid-lines-15nov`, made from `main` at `baf4a59`, with `eira-box-corners` (the two entries below) joined in.

| File | What changed, and why |
|---|---|
| `Tools/design/plant_kit.py`: `line_colours`, `mix`, `flat`, `inside`, `halfway` | Every line is now written in one solid colour. Until now an outline was drawn 85% see-through and a vein 30 to 42%, so two lines that crossed made a darker spot and a stem showed through the leaf in front of it. The drawing code still says how strong a line is. The last step works out the colour that strength would have looked (an outline over the card colour, a fainter line over whatever it sits on) and writes that as a plain colour |
| `plant_kit.py`: `STEM`, `LEAF`, `BLOOM`, `Art.on`, `Art.group` | Every mark remembers a layer. When a whole plant has been drawn its marks are sorted: stems at the back, then leaves, then flowers and fruit. Until now a clump was drawn one stem at a time, so the second stem's leaves landed on the first stem's flower. An umbel's spokes sit half a layer behind its flowers |
| `Tools/design/plants_all.py` | `@on_layer(LEAF)` on `LF`, `@on_layer(BLOOM)` on `FL`, `FR` and `SH`. `body` draws the plant as one group. The buds at the top of a spire and the fruit of trailing plants are put on the flower layer by hand |
| `Design/Plants/light`, `Design/Plants/dark` | All 908 life stages and 340 close-ups redrawn, each in light and dark |
| `Windfall/Assets.xcassets/Plants` | The same 1,248 drawings as the app holds them, written by `build_design_assets.py` |

No Swift file changed: `plant-drawings.json` and `plant-parts.json` came out identical, so no name, stage or label moved.

**How the code came across.** The project's copies could not be brought to the Mac as files, so the changes were made to the repository's own two files by a script of exact find-and-replace steps (`windfall-build-logs/solid-lines-patch.py`). Each step must match once, or nothing is written.

**Checked** (`windfall-build-logs/solid-lines-compare.py`):

- 340 of the 908 life stages have the same shapes in a new order, and the other 568 the same shapes in the same order. 340 is the number doc 86 gives.
- No close-up changed its drawing order. No file has `stroke-opacity`.
- Achillea's outline in light mode is `#2B6249`, the colour doc 86 works out.
- The card colours the lines are mixed with (`CARD`: `#FFFCF6` light, `#142414` dark) are the app's `Card` colour in `Design/colours.json`.

**Built and seen:** with `main` joined in twice more while this was made (the zoomed Life stages strip, then Eira's snowdrop symbol), Mac and simulator builds, unsigned, and a signed build for any iPhone or iPad: BUILD SUCCEEDED (`windfall-build-logs/sl1-sim.log`, `sl3-mac.log`, `sl3-ios.log`). Simulator pictures (`windfall-build-logs/shots/sl-*.png`): Yarrow's page and its "In flower" drawing zoomed in, light and dark, on an iPhone 17 Pro; Yarrow's and Russian comfrey's pages on an iPad mini; Eira's panel in light and dark. The flower heads sit in front of the leaves and no line shows through another. The "Ask Eira" box has the journal box's corners and sits level with the microphone.

**Not seen:** a tag on two lines. In the pictures "Pollinator plant" and "Dynamic accumulator" each fit on one line and look like pills, as they should. Windfall's own Linux checks were not run: no Swift file changed in the drawings, and the two Swift changes of `eira-box-corners` are views.

**One thing to know:** two close-ups, the daffodil's flower and the peacock orchid's, each have one point a tenth of a grid square (a thousandth of the drawing's width) from where the repository had it. The unchanged code run on this Mac gives the same two differences, so it is this Mac's Python rounding a half the other way, not the new code.

# 15 November 2026, 13:05: the zoomed Life stages page is the card's own row made big, not a slideshow

**By the card zoom chat, second round.** William, 12:51, with a picture of the row of stages: "The zoom in still isn't right. I wanted this to be the thing that fills the screen and you scroll along it." The 12:25 version showed one drawing to a page and snapped from page to page. Made on the branch `card-zoom-15nov`, from `main` at `baf4a59`.

| File | What changed, and why |
|---|---|
| `PlantDrawingViews.swift`, `PlantPicturesZoomed` | Rewritten. The page is now one long strip: every stage side by side with its name beneath, each drawing as tall as the page allows, in a plain sideways `ScrollView` that glides and rests wherever it is let go. Gone: the pages (`containerRelativeFrame`, `.scrollTargetBehavior(.paging)`, `scrollPosition(id:)`), the arrows and arrow keys, the "3 of 5" count and the second row of small tiles. `side(in:alone:)` works the drawing's size out from the page: the smaller of the height left over and 58% of the width (`shareOfWidth`), so the next stage always shows at the edge. Two `Spacer`s put the card in the middle of a tall page. The strip is cut to the card's rounded corners (`clipShape`) |
| The same, for a close-up | A lone Leaf or Flower still opens as one drawing, now centred in the same card and as wide as the page allows |
| `PlantPictureTile` | Lost `isChosen` and its ring. The ring marked which page the slideshow was on, and there are no pages now |

**Not built, on purpose:** a ring on "the plant's current stage". The app does not hold a current stage for a plant, so there is nothing to ring. The strip opens at its start (Seed).

**Checked:** simulator and Mac builds, unsigned: BUILD SUCCEEDED (`windfall-build-logs/cz8-sim.log`, `cz8-mac.log`). Simulator pictures (`windfall-build-logs/shots/cz2-*.png`, script `cardzoom-shots2.sh`): Yarrow's strip at its start on an iPhone 17 Pro in dark and on an iPad mini in dark, its end ("Winter") on the iPad mini in light, Yarrow's flower and Rhubarb's leaf alone, and Yarrow's page with the three cards unchanged.

**Not checked:** a drag along the strip on any device, the Mac's own window, and an iPad or iPhone on its side. The pictures are of pages opened by the checking aid.

# 15 November 2026, 12:35: a tag on two lines is a squircle, not a bulging pill

**By the "search bar corners" chat, from William's phone. On the same branch, `eira-box-corners`. Not built.** William, 12:25, with a picture of a plant's page on the iPad: "The curvature around dynamic accumulator is too much, it should be more of a squircle."

| File | What changed, and why |
|---|---|
| `Theme.swift`, new `Theme.tagShape` | One shape for a tag with words in it: a rectangle with corners of 18 in Apple's smooth curve (`style: .continuous`). On one line (about 36 points tall) the corners meet, so it still looks like a pill. On two lines the sides stay straight |
| `PlantLibraryView.swift` | The three sets of tags on a plant's page use it in place of `.capsule`: a card's tags ("Pollinator plant", "Dynamic accumulator"), the "Add information" buttons ("Human Management", "Ecological Interactions") and "Plants that help with its pests". A capsule's ends are always full half circles, so a two-line tag had ends 30 points deep |

**Not checked:** anything. Not built or seen. The filter buttons and the plant cards' chips are still capsules: they stay on one line.

# 15 November 2026, 12:30: the box in Eira's chat has Windfall's rounded corners

**By the "search bar corners" chat, from William's phone. Branch `eira-box-corners`, from `main` at `baf4a59`. Not built: written in Claude's cloud workspace, which has no Xcode.** William, 12:22, with a picture of Eira's chat in the panel in dark mode: "The curvature of this search bar doesn't match the curvature elsewhere."

| File | What changed, and why |
|---|---|
| `EiraChatView.swift`, the "Ask Eira…" box | It used the system's own box (`.textFieldStyle(.roundedBorder)`), whose corners are small and fixed and which is black in dark mode. It is now `.plain` with the box drawn by hand, exactly as the journal's box is in `JournalChatView.swift`: the card colour at 0.85, corners of 20, a hairline round it, 14 points of room at the sides and 10 above and below |

**Not checked:** anything. It has not been built or seen. The box is taller than before (about 40 points for one line, as the journal's is), which should sit level with the 44-point microphone.

# 15 November 2026, 12:25: the whole Life stages card zooms in, and Leaf and Flower are two cards

**By the card zoom chat.** William, 11:57: "When I said I wanted the life stages card to be able to be tapped to zoom in, I meant the entire card, then able to scroll through the life cycle but it would be zoomed in. For the leaf and flower card, I want these as two separate cards that sit next to each other, but in the same location they're in now." Made on the branch `card-zoom-15nov`, from `main` at `f4b5700`.

| File | What changed, and why |
|---|---|
| `PlantDrawingViews.swift`, `PlantStagesCard` | The whole card is now one `GrowingLink`, so a tap anywhere on it (a drawing, a label, the title or the glass) opens the zoomed page, which grows out of the card. The row of tiles still slides sideways with a drag. Until now each tile was a link of its own |
| `PlantPartsCard`, new `PlantCloseUpCard` | "Leaf" and "Flower" (or "Blossom", "Flowers, inside the fig") are two cards side by side, each its title and its drawing filling the card, in the same place on the page. Each card opens its own drawing zoomed in. A plant with a leaf and no flower shows the leaf card alone at half width |
| `PlantPicturesZoomed` (was `PlantPictureDetailView`) | Every drawing of the card large, one at a time, in a sideways row that stops on each drawing (`.scrollTargetBehavior(.paging)`). Swipe to step through the life cycle while staying zoomed in, or use the arrows either side of "3 of 5", or the arrow keys on a Mac. The small tiles at the foot ring the one in view and slide straight to any stage. `scrollPosition(id:)` reads which drawing the row is on; a `ScrollViewReader` moves it when a button asks |
| `PlantLibraryView.swift` | The checking aid `-demoPlantDrawing` opens the new page; a close-up opens alone, as from its card |
| `PlantPage.swift` | Comment only: the drawing cards' weight for the two-column page is unchanged, as the Leaf and Flower row is about as tall as the old card |

**Put right while checking:** a page opened part-way along (the checking aid) showed the first drawing while saying "3 of 5", because a scroll view starts at the left on its first showing. It now slides to the right drawing once it is on screen.

**Checked:** Mac and simulator builds, unsigned: BUILD SUCCEEDED (`windfall-build-logs/cz5-mac.log`, `cz4-sim.log`). Simulator pictures (`windfall-build-logs/shots/cz-*.png`): Garlic and Tomato on an iPhone 17 Pro in light, Rhubarb in dark, Garlic on an iPad mini, the zoomed page for Garlic's life stages, Rhubarb's leaf and Garlic's flower.

**Not checked:** a tap or a swipe. The pictures are of pages opened by the checking aid; nobody has yet tapped a card, swiped the zoomed row or pressed an arrow on a device.
# 15 November 2026, 12:00: the leaf and flower drawings checked for accuracy, 44 kinds put right

**By the "leaf and flower in the app" chat**, after the midday join had taken in the branch as it stood at 11:26 (`0f9ace9`). This entry is the rest of that branch.

William, 11:27: "When you've done that, could you double check all the drawings for accuracy." Each kind's leaf and flower was set beside the Latin name and variety in his own plant library (`StarterData.json`), and all six sheets were looked at. 44 kinds were changed in `leaves_flowers.py`: 22 leaves and 26 flowers. Project doc 81 lists each one, its reason and what is still in doubt.

- **New drawing code**: a rayless daisy head (`rayless`, pineappleweed), a lacecap hydrangea (`lacecap`), an even pincushion (`even`, devil's-bit scabious), a pansy face (`fl_pansy`), a horned rampion head (`fl_horned`), round button heads (`button`, wormwood), veined petals (`veins`, rocket), spots on a leaf (`spots`, lungwort and St John's-wort), two more leaflets at the foot of a trefoil (`basal`, bird's-foot trefoil).
- **Why the settings sit at the foot of `LEAFX` and `BLOOMX`**: every change from the check is under one comment line, so it can be told from the first pass.

**Checked:** all 680 SVG files well-formed. Windfall's own checks pass in the cloud workspace on the joined code. Built for the simulator and the Mac with no errors (`lf5-sim.log`, `lf6-mac.log`). Seen in the app in still pictures: the hydrangea's lacecap enlarged in dark mode, and Viola's page in light mode.

# 15 November 2026, 11:50: three branches joined into main, tested or not

**By the midday join chat.** William, 11:44: "Merge all changes into the main branch, including untested ones so that I can test all changes." Joined on the branch `join-15nov-midday`, made from `main` at `14315a5`, in its own copy (`~/Developer/windfall-join2`).

**What came in**, in this order:

| Branch | What it is | Tried by William? |
|---|---|---|
| `ipad-fixes-15nov` | Two iPad fixes from the morning (doc 78), described below | Installed on the iPad and iPhone at 11:28 inside the widget colour mix, not yet reported on |
| `fungus-keys-shelf` | Room for John Wright's fungus key, a sample key in its place, and Identify as a place in the sidebar on the Mac and iPad (doc 77) | Mac build only, at 10:30 |
| `leaf-flower-in-app` | The leaf and flower close-ups as a section of their own on a plant's page, and every plant drawing opens large when tapped (doc 79) | No |

**The iPad fixes, which had no entry of their own:**

| File | What changed, and why |
|---|---|
| `Windfall/Theme.swift`, `TagButtonStyle` | A new outline pill the size of a tag, so Confirm on Recent records matches the Provisional tag beside it |
| `StatusTag` | Keeps its word on one line (`lineLimit(1)`, `fixedSize()`), so "Provisional" and "Confirm" no longer break in half in a narrow column |
| Recent records | `ViewThatFits` puts the tag and Confirm side by side, or one above the other when there is no room |
| `NorthRing`, `NorthRingSetter`, `GardenDrawSteps` | Dragging N round the ring froze the iPad for 9.5 seconds: every move saved the garden, so every screen reading the records redrew about 60 times a second. Now only a preview (`liveTop`) moves while dragging, and the garden is saved once when the finger lifts |

**Clashes:** only `CHANGES.md`, twice, where each branch had added its entry at the top. All entries kept, newest first. No Swift file clashed.

**Checked:** Windfall's own checks in a cloud workspace, Swift 6.3.1 for Linux: 123 files parse, the type check passes, cross-file checks clean, **854 logic tests pass, 0 fail**. Mac build, unsigned: BUILD SUCCEEDED (`windfall-build-logs/j2-1-mac.log`).

**Not checked:** anything on a screen. The fungus keys and Identify have never been seen on an iPhone or iPad, and the leaf and flower section has not been seen by William anywhere.

# 15 November 2026, 11:30: the widgets stand on the app icon's background

**By the widget colour chat.** William, 11:15: "The widget background colours should match the app icon background colour." Made on the branch `widget-icon-ground`, from `main` at `505ec61`.

The app icon is cream `#FAEEE0` in light mode and green `#06421B` in dark mode (`Windfall/AppIconMac.icon/icon.json`, doc 47). Before this, the Paper widgets used the card colour (`#FFFCF6` light, `#142414` dark) and Garden green used the sidebar's green `#0C2C14`. Both were near the icon's colours but not the same.

| File | What changed, and why |
|---|---|
| `Design/colours.json` | A new named colour, `IconGround`: `#FAEEE0` light, `#06421B` dark. Kept here and not typed into the Swift, so the icon's background has one home and the light and dark values switch by themselves |
| Both `Assets.xcassets/Colours/IconGround.colorset` | Written by `Tools/design/build_design_assets.py` from the line above. Nothing else in the catalogues changed |
| `WindfallShared/WidgetViews.swift`, `WidgetPalette.paper` | `ground` (the widget's background) is now `IconGround`. `inset` (the photo box and the capture buttons) is now `Card`, because the old inset colour, `Paper` `#F8F1E5`, is almost the same cream as the new background and would have vanished. `Card` is a shade lighter than the cream in light mode and a shade darker than the green in dark mode, so the boxes still show |
| `WindfallShared/WidgetViews.swift`, `WidgetPalette.green` | `ground` is now the icon's green `#06421B`, in both modes. The colours that sit on it were moved up with it so they keep the same step from the background: `inset` `#0E4F25`, `fill` (the tags) `#1F6234`, `line` (the thin dividers) `#2B5F3A`, and `onLeaf` (text on the pale green) `#06421B` |
| `WindfallWidgets/WindfallWidgets.swift` | The words under the Look setting say both looks match the icon |

The app's own screens are not changed: `Card`, `Paper` and the sidebar keep their colours. Only the widgets, and the app's widget checking page (which draws the same views), use `IconGround`.

# 15 November 2026, 10:30: room for John Wright's fungus key, and an Identify place

**By the "mushroom key" chat, on the branch `fungus-keys-shelf`, not yet in `main`.** William, 09:46: "Could we build the mushroom key based on the key on foragers calendar in anticipation of acceptance from the author, so that we can see how it works?" His key is not copied before he says yes, so this builds everything around it, with a sample in its place. William, 09:51: "Build the app changes on a branch to add in later. Could it have its own place on the sidebar?" He chose an Identify place.

**What changed**

| File | Change |
|---|---|
| `Windfall/FungusKey.swift` | A key may have a `title`, a `credit` (author, work, link, terms, `verdictsAllowed`) and be marked `sample`. An answer may carry the author's `verdict`. `faults()` now also fails a verdict in Windfall's own key, a verdict the author has not allowed, and a sample with a real author's name. The "edible" check is unchanged: outside a verdict the word may never appear. New `FungusKeys` lists the keys in the app: Windfall's own, then `WrightFungusKey.json` if it is there, otherwise `SampleFungusKey.json`. `note(reaching:keyName:)` names the key used |
| `Windfall/SampleFungusKey.json` | New. A short key to species, written by Claude in its own words, so the screens can be tried. Nobody's real key. Unchecked |
| `Windfall/FungusKeyView.swift` | Shows whichever key it is given. A sample notice, a credit line for an author's key, and his verdict in a plain box, only when he allowed it and William's switch is on |
| `Windfall/IdentifyViews.swift` | New. The Identify page (photo, then each key, then the verdict switch) and the iPhone's Fungus keys page |
| `Windfall/MainTabView.swift` | `AppSection.identify`, between Wildlife and Journal. Not an iPhone tab: chosen on a wide screen that turns narrow, Wildlife shows |
| `Windfall/HubScreens.swift` | Wildlife keeps its photo and key tiles only on an iPhone. `PageWidth` is no longer private |
| `Windfall/Theme.swift`, `Design/Icons/identify.svg` | The Identify icon: a lens over a leaf |
| `Windfall/DemoGarden.swift` | `-demoFungusKey SampleFungusKey` with `-demoFungus start` opens the sample |
| `.gitignore` | `Windfall/PrivateKeys/` and any `WrightFungusKey.json` are never committed |
| `Tools/checks/LogicTests.swift` | Ten new checks |

**If John Wright says yes:** put his key, in this file's shape, at `Windfall/PrivateKeys/WrightFungusKey.json` on the Mac. Xcode's folder takes it into the app; git does not. Set `credit.verdictsAllowed` as he says. The sample then leaves the app by itself.

**Checked:** the project's checks with Swift 6.3.1 in the cloud: 123 files parse, the type check passes, 843 logic tests pass, 0 fail. **Not checked:** no Mac build. The screens are only syntax-checked here.

# 15 November 2026, 11:30: the leaf and flower close-ups on a plant's page, and every drawing opens large

**By the "leaf and flower in the app" chat.** William, 11:12: "Great work on the plant leaf and flower drawings. Could you add them into the next build. Could you also make it so that you can tap on the life stages to enlarge it." Earlier, at 10:30, he had said where the close-ups go: "This would be a separate section in the plant page."

## On the screen

- **A plant's page has a new card, "Leaf and flower"**, straight under "Life stages": a close-up of its leaf and one of its flower, 96 points each with the label beneath ("Leaf", "Flower", "Blossom" for tree fruit, "Flowers, inside the fig"). On a two-column page it sits with Life stages at the top of the left column. A plant with no drawings (the mixes, the to-buy plants) shows neither card. Ginkgo, Senecio 'Angel Wings', Shallot and Tarragon show a leaf only.
- **Tap any drawing on either card and it opens large**, on a page of its own that grows out of the tile and shrinks back into it on the way back (the same zoom as every other tile, `GrowingLink` in GrowFromTile.swift). The drawing fills the width of the page, up to 560 points. Under it are the plant's name and the drawing's label in the page-title serif, and a row of the card's other drawings at 64 points: tap one to swap it in, so the life stages can be stepped through without going back. The one shown has a green ring.

## How

| File | What changed |
|---|---|
| `Tools/design/leaves_flowers.py` (new) | Draws the close-ups: 340 drawings, each in light and dark. Project doc 79 says how |
| `Design/Plants/light`, `dark`, `plant-parts.json` | The 680 new SVG files and their list |
| `Tools/design/build_design_assets.py` | Also copies `plant-parts.json` into the app as `Windfall/PlantParts.json`. The 340 new picture sets came from the existing loop by themselves: `Assets.xcassets/Plants` now holds 1,248 |
| `PlantDrawings.swift` | New `PlantParts`: reads the list and gives a kind's close-ups by its slug. New `PlantPicture`: one drawing in a row (kind, stage or close-up, label), made from either list. `parts(forPlantNamed:)` finds a plant's close-ups through its kind |
| `PlantDrawingViews.swift` | `PlantPictureRow`: a titled card of tiles, each a `GrowingLink`. `PlantStagesCard` now uses it, and so does the new `PlantPartsCard`. `PlantPictureTile`: one tile. `PlantPictureDetailView`: the enlarged page |
| `PlantLibraryView.swift` | `partsCard` on the plant page under `stagesCard`, in both layouts. The two-column page counts the drawing cards at the top of the left column when it shares out the facts |
| `PlantPage.swift` | `drawingCardsWeight(cards:)`: seven rows for each drawing card. This settles "Not done" 5 of project doc 71 |

- **Why one row for both cards.** The Life stages card and the Leaf and flower card are the same thing: a title and a row of drawings. Making both from `PlantPictureRow` means the tap to enlarge, and anything changed later, is written once.
- **Why the enlarged page is a pushed page, not a sheet.** William's rule of 14 November: a tile that leads to more should grow its page out of itself, with the swipe back kept.
- **Nothing saved has changed.** No record type was touched.

## Checked

| Check | Result |
|---|---|
| Windfall's own checks, cloud workspace, Swift 6.3.1 | Syntax, types and cross-file checks pass. **844 logic tests pass**, 11 of them new |
| New tests | The list of close-ups is read, leaf first. A plant finds its close-ups through its kind by any of its names. A plant with no drawings has none. Picture names. The life stages become a row in order. The two-column weights. With the real files: the app's list is the one in `Design/Plants`, it covers the same 172 kinds as the life stages, and every close-up has a light and a dark drawing |

# 15 November 2026, 03:52: seven more branches joined into main

**By the join chat.** William, 22:49 on 14 November: "In the morning when all the build work is finished on all versions, could you send me a list of jobs I need to do still. Could you also compile the iPhone, iPad and Mac versions when they've included all the changes and errors." The Mac had been quiet since 23:03: no build running, nothing unsaved in any copy of the code, no commit anywhere. The join was made in `~/Developer/windfall-join`, on the branch `join-15nov-morning`, from `main` at `17f0f0b`, and `main` moved only once it built and passed its tests.

**What came in**, in this order:

| Branch | What it is | Built before? |
|---|---|---|
| `today-scroll-iphone` | Today scrolls again on an iPhone and iPad: a card's press and hold is UIKit's long press there | No |
| `job-title-keeps-in` | A job's name keeps a small word that belongs to it: "Put the raspberry cables in" | No |
| `journal-send-keyboard`, which carries `journal-send-closes` | Sending a journal entry puts the keyboard and the panel away | Only inside the iPad mix |
| `eira-put-away` | Eira's bar and keyboard put away by touch, and a swipe down on the panel's heading | For the iPhone, at 20:30 |
| `photos-faster-entry-edit` | Photos show at once, and a journal entry can be changed | Yes |
| `camera-option` | "Take a photo" on an iPhone and iPad, saved to Photos with its position, and in the seed packet scanner | No |
| `garden-draw` | Drawing a garden on the plan, step by step, and three ways to set north, behind one chooser for trying out | Yes |

**Left out:** `todo-cards-open`, which holds nothing `main` lacks (its last commit is a merge of `main`), and the three branches made for one device only, which say so in their last commits: `ipad-journal-mix`, `photos-faster-phone-mix` and `tile-grow-phone-mix`.

## Where the branches met

| File | The clash | Settled by |
|---|---|---|
| `CHANGES.md`, `Tools/checks/logic-files.txt`, `Tools/checks/known-false-alarms.txt` | Each branch added its own lines at the same spot | Keeping both |
| `Tools/checks/LogicTests.swift` (with `garden-draw`) | Both sides added tests at the end | Keeping both, after checking that no name is declared twice |
| `Windfall/EiraVision.swift` (with `camera-option`) | The Identify screen's row of buttons. The photo speed-up asked Photos for each photo as it is stored (`preferredItemEncoding: .current`). The camera branch put the buttons in a `ChipFlow`, which wraps them on a narrow screen, and added "Take a photo" | The camera branch's `ChipFlow` and button, with the speed-up's `preferredItemEncoding: .current` on the Photos button |

## One thing that would not have built

The photo speed-up made the Identify screen's `take(_:)` an `async` function: it waits while the photo is made smaller, away from the screen's own work. The camera branch, written before that, called `take(photo)` straight from the camera's closure, which is not allowed to wait. It now starts the work as a `Task`, as the screen's other ways in do:

```swift
.cameraPhoto(isPresented: $isTakingPhoto) { photo in
    Task { await take(photo) }
}
```

A `Task` is a piece of work Swift runs alongside the screen. `await` means "wait here for this to finish", which only code inside a `Task` or another `async` function may do.

## Checked

| Check | Result |
|---|---|
| Logic checks, Swift 6.3.1 for Linux in the join chat's cloud workspace | 122 files valid, type check passed, 30 record types and 30 in the schema, **833 logic tests pass, 0 fail** |
| The Mac, unsigned | `jm1-mac.log`, 03:39: BUILD SUCCEEDED, at the first attempt |
| The simulator, which also builds the widget program | `jm2-sim.log`, 03:43: BUILD SUCCEEDED |
| Signed, for any iPhone or iPad | `jm3-ios.log`, 03:55: BUILD SUCCEEDED. Its signing profiles list both the iPhone and the iPad, and run out on 21 November at 21:37 |
| A database made by the build of 20:34 opens in this one, and the other way round | Yes, on the iPad mini simulator with a database of its own (`join-migrate.sh Windfall-claude Windfall-join jmm`). No record type changed in the join |
| Crash reports | None |
| Pictures with the example garden, their words read by `read-picture.swift` | Today on an iPad mini and an iPhone 17 Pro Max, the Journal, Settings and tools, the garden drawing chooser and Garlic's page with its Life stages card. `shots/jmm-*.png` |

The name-guessing check raised five false alarms: `other` (a touch recogniser in `TodayBoard.swift`), `step` (a compass offset in `GardenDrawing.swift`) and `card` (a view in `TodayBoard.swift`), each named like something else elsewhere. They are listed in `known-false-alarms.txt`. The builds are the proof they are false.

## Not checked

- **Nothing was tried by hand.** No press, drag, swipe or typing, and no photo taken: the simulator has no camera.
- **Nobody looked at a picture.** The join chat could only read the words in them.
- The garden drawing pages on the Mac, an iPad, in dark mode, and with a compass.

# 14 November 2026, 22:39: snow and great heat in the corner drawing (branch `bee-asleep-at-night`)

**By the "bee asleep" chat.** William, 22:31, of the preview page's Weather switch (Fine, Rain, Frost, Night): "There isn't a snow option in it or an extreme heat option." Both are now kinds of weather the corner draws, on Today from the real weather and in the preview by choice.

| | Snow | Great heat |
|---|---|---|
| When, on Today | The weather service says snow is falling | 30°C or more, by day and dry |
| What is drawn | Flakes falling steadily right across the frame, carried by the wind | The whole plant hangs over, each leaf droops, it hardly sways, and five faint wavy lines of haze rise |
| The bee | Stays away by day. Still asleep in its flower at night | Does not fly |

| File | What and why |
|---|---|
| `Windfall/WeatherService.swift` | `CurrentConditions` keeps the service's `weatherCode`, which was already being asked for and then dropped. New `isSnowing` |
| `Windfall/CornerScene.swift` | `CornerWeather` gains `.snow` and `.heat`. `heatFromC`. `weather(...)` and `make(...)` take `isSnowing`. `isBeeWeather` rules both out. New `isWilting` |
| `Windfall/CornerSprigs.swift` | `isLeaf`, so the engine knows which parts droop |
| `Windfall/LivingCorner.swift` | The steady snowfall, the wilt, the haze and two new lines about the bee in the preview |
| `Windfall/TodayView.swift` | Passes `isSnowing` to the scene |
| `Tools/checks/LogicTests.swift` | Seven new tests |

**How the app knows it is snowing.** The weather service sends a number for the kind of weather with every reading, a WMO weather code. The app asked for it and threw it away. It is now kept:

```swift
var weatherCode: Int? = nil
static let snowCodes: Set<Int> = [71, 73, 75, 77, 85, 86]
var isSnowing: Bool { weatherCode.map { CurrentConditions.snowCodes.contains($0) } ?? false }
```

- `Int?` is "a whole number, or nothing". `= nil` starts it as nothing, so the two other places that make a reading did not have to change.
- `snowCodes` is the set of numbers that mean snow, snow grains and snow showers.
- `isSnowing`: if there is a code, is it one of those? `?? false` is "and if there is no code, the answer is no".

**Which weather wins.** The corner draws one kind at a time:

```swift
if isSnowing { return .snow }
if let precipitationMM, precipitationMM >= rainFromMM { return .rain }
if let temperatureC, temperatureC <= frostAtOrBelowC { return .frost }
if isNight { return .night }
if let temperatureC, temperatureC >= heatFromC { return .heat }
return .fine
```

The lines are tried from the top and the first that fits is the answer. `if let temperatureC` means "if there is a temperature reading at all".

**The wilt.** Two parts. The whole plant leans a steady 5 degrees more, added to the wind's lean. And each leaf turns part of the way to pointing straight down:

```swift
var toDown = 90 - degrees
while toDown > 180 { toDown -= 360 }
while toDown < -180 { toDown += 360 }
degrees += toDown * CornerEngine.leafDroopShare
```

`degrees` is the way the leaf points, and 90 is straight down. `toDown` is how far it has to turn to get there. The two `while` lines pick the short way round. The last line turns it 22% of that.

**⚠️ CHECK, Claude's choices:** 30°C for great heat. That the bee does not fly in great heat (from general knowledge: bumblebees overheat and stop foraging in very hot weather). 5 degrees of lean and 22% of droop. The haze drawn in the autumn-leaf amber. January's and December's own flurries are still there on any day that is not wet or hot, as before.

**Not done:** with Reduce Motion on, snow is not drawn (rain is not either). The wilt is.

# 14 November 2026, 21:51: at night the bee is asleep in its flower (branch `bee-asleep-at-night`)

**By the "bee asleep" chat.** William, 21:28: "The bee doesn't seem to be flying in in the corner drawing." It was night, and the corner was following its rules. Then, 21:33: "At night, can the bee be sleeping in the flower".

**What was happening at night before this.**

1. Rain, frost, a wind over 20 km/h or a reading under 5°C sent the bee away by night as well as by day. On most November nights there was no bee at all.
2. On a dry, mild night the bee was switched on, asleep, 2.2 seconds after Today opened. It did not fly in and it did not grow in. It blinked into place.

**What happens now.** In every month that has a bee, the bee is asleep in its flower all night, whatever the weather. It is there from the moment the drawing opens and grows in with its flower. The rain, the frost sparkle and the wind are still drawn round it. A tap still pushes the sprig, and the bee sleeps on.

| File | What and why |
|---|---|
| `Windfall/CornerScene.swift` | New `isNight`, kept apart from `cornerSky`. New `isAfterDark` and `isBeeWeather`. `beeSleeps` and `beeIsAbout` rewritten |
| `Windfall/LivingCorner.swift` | New `roosts`, `putBeeToBed` and `beeBedsDown`. The bee is drawn at its flower's size while it sleeps. Waking and a new day no longer switch it off. A checking aid, `-cornerNight YES`. The preview's line about the bee |
| `Tools/checks/LogicTests.swift` | Five new tests |

**Why `isNight` had to be added.** `cornerSky` holds one kind of weather, and rain wins over frost, which wins over night. So on a wet night it said `.rain` and nothing in the scene said it was dark. The old rule asked `cornerSky == .night`, which a wet or frosty night never is.

```swift
var isAfterDark: Bool { isNight || cornerSky == .night }
var isBeeWeather: Bool {
    cornerSky != .rain && cornerSky != .frost && breeze != .gusty && isWarmEnoughForBee
}
var beeIsAbout: Bool { hasBee && (isAfterDark || isBeeWeather) }
var beeSleeps: Bool { hasBee && isAfterDark }
```

- Each of these is a question the scene answers with yes or no (`Bool`). `||` is "or", `&&` is "and", `!=` is "is not".
- `isAfterDark`: it is night if the new flag says so, or if night is the weather being drawn. The second half keeps the preview page's Night choice working.
- `isBeeWeather` is the old list of things that stop a bee flying, given a name of its own.
- `beeIsAbout`: a month with a bee, and either it is night or the weather suits. Before, the weather had to suit even at night.
- `beeSleeps`: a month with a bee, and night. Nothing about the weather.

**Why the bee blinked, and what replaced it.** The old lines waited 2.2 seconds and then set the bee down. The new function is called on every frame while it is night:

```swift
private func putBeeToBed(_ time: Double, perches: [Int], roosts: [Int], grown: Double) {
    if beeIsAsleep {
        if beePartIndex == nil { beePartIndex = roosts.first }
        return
    }
    switch beeMode {
    case .away:
        if grown < CornerEngine.openingSeconds {
            if let roost = roosts.first { beeBedsDown(on: roost, at: time) }
        } else if let landing = perches.first {
            // it flies in to bed
        }
    case .arriving, .hopping:
        if time - beeSince >= beeFor, let index = beePartIndex { beeBedsDown(on: index, at: time) }
    case .feeding:
        if let index = beePartIndex { beeBedsDown(on: index, at: time) }
    case .leaving:
        if time - beeSince >= beeFor { beeMode = .away }
    }
}
```

- `switch beeMode` picks one branch by what the bee is doing now.
- `grown` is how many seconds the drawing has been open. Under `openingSeconds` (3) the drawing has just opened, so the bee is put straight on its flower. `roosts` lists the flowers a bee can sit on from the moment each first shows, however small. `perches`, which was there before, lists them only once fully grown.
- Later than that, night has fallen with Today open. A bee that is away flies in. One in the air lands first. One on a flower nods off where it is. One leaving goes, and then flies in.
- In `drawBee`, `if beeIsAsleep { g.scaleBy(x: flowerSize, y: flowerSize) }` draws the sleeping bee at the size its flower has reached, so the two grow in together.
- In a foxglove the sleeping bee is tucked half way into its bell, with its back end showing.

**Morning.** The bee used to be switched off and flown in again a second later. It now wakes where it slept, feeds for about three seconds and carries on by the day's rules, so in rain it flies off to the right.

**A new day while it sleeps.** The drawing is made again for the new day. The bee stays asleep and its flower is found again.

**⚠️ CHECK, Claude's choices:** the bee sleeps through rain, frost, gales and cold. A tap does not wake it. Night under rain or frost is drawn as rain or frost, as before. From general knowledge, for William to check: bumblebees caught out late do spend the night on or in flowers, and they shelter in foxglove bells.
# 14 November 2026, 22:47: the Mac's icon gets shine and shadow

**By the "Mac icon" chat, on the branch `mac-icon-glass`.** William, 22:31: "Could you send me what the icon would look like with shine and shadow?" He was sent the flat icon beside two versions. At 22:43: "Shine and shadow works, you could even have more shadow in the dark mode version."

**One file changed, `Windfall/AppIconMac.icon/icon.json`.** No Swift, and nothing for iPhone or iPad.

| Line | Before | Now | What it does |
|---|---|---|---|
| `"glass"` | `false` | `true` | Lets the drawing take part in Apple's glass look at all |
| `"specular"` | `false` | `true` | The shine: a thin bright rim the Mac draws round the edges of the drawing |
| `"shadow"` | `{ "kind": "none" }` | replaced by the lines below | A soft shadow under the drawing, so it looks lifted off the tile |

```
"shadow-specializations": [
  { "value": { "kind": "neutral", "opacity": 0.5 } },
  { "appearance": "dark", "value": { "kind": "neutral", "opacity": 1.0 } }
]
```

This is the same pattern as the background colour and the drawing in the entry of 21:44: a value with no mode named is the ordinary one, and a value marked `dark` is used in dark mode. `kind` is the sort of shadow: `neutral` is a plain grey-black one. `opacity` is its strength, from 0 (none) to 1 (the most the Mac will draw). So the shadow is at half strength in light mode and full strength in dark mode, where a shadow is harder to see against the green.

**1.0 is the ceiling.** If the dark shadow should be stronger still, it cannot be done with this number. The other kind, `layer-color`, was tried: it takes its colour from the drawing and comes out as a pale glow round the leaves in dark mode, not a shadow.

**Translucency is still off** (`"enabled": false`). William asked for shine and shadow only.

**Checked on the Mac:** Apple's icon tool (`ictool`) draws both modes from the changed file, and the light one is the very picture William chose. Xcode's asset step by hand, for the Mac and for iPhone and iPad: no errors or warnings.

# 14 November 2026, 21:30: plant drawings on the plant cards and pages

**By the plant graphics chat.** William, 21:26, of the plant drawings added at 20:10: "Add these into the app."

**What you see**

- **Each plant's card has its drawing**, at the right of its name: on the Plants page and under Eira's replies, which use the same card. In a month the plant is harvested it is the crop. In a month it flowers it is the flower. Otherwise it is the plant at its best: the crop if it has one, then the flower.
- **Each plant's page has a "Life stages" card**: every stage in a row, with its name beneath, which slides sideways when it is too long.
- A plant with no drawings (the mixes, and the plants on the to-buy list that are not also grown) looks as it did.

**How**

| File | What changed |
|---|---|
| `PlantDrawings.swift` (new, tested) | Reads the list of kinds. `kind(forPlantNamed:)` finds a plant's kind by its name, so "Leeks" finds "leek". `cardStage` chooses the stage for a card. `pictureName` is a drawing's name in the store of pictures |
| `PlantDrawingViews.swift` (new, a screen) | `PlantDrawingView` shows one drawing. `PlantStagesCard` is the row of stages |
| `PlantLibraryCards.swift` | `PlantCardView` shows the drawing before its chevron |
| `PlantLibraryView.swift` | `stagesCard` on a plant's page: under the plantings card when the page is one column, at the top of the left column when it is two |
| `Tools/design/build_design_assets.py` | `build_plants` turns `Design/Plants/light` and `dark` into `Assets.xcassets/Plants`, one picture set for each drawing holding its light and its dark copy, and copies the list into the app as `PlantDrawings.json` |
| `Assets.xcassets/Plants`, `PlantDrawings.json` | Written by that script. Do not edit by hand |

**Why a picture set holds two files.** The drawings have their own colours, and the dark copy has darker fills and a pale line. The app's store of pictures can hold a second copy marked "dark" and hands out the right one by itself, so the code asks for one name and never has to think about light and dark.

**After changing a drawing**: run `python3 Tools/design/plants_all.py /tmp/plants`, copy `light`, `dark` and `plant-drawings.json` into `Design/Plants`, then run `python3 Tools/design/build_design_assets.py`.

**Nothing saved has changed.** No record type was touched.

**The drawings themselves are still a first pass that William has not gone through** (project docs 59, 62 and 63).
# 14 November 2026, 21:50: "Take a photo" on an iPhone and iPad

**By the camera chat, from William's iPhone. Branch `camera-option`, made from `main` at `4b28986`. Not in `main`. Written in Claude's cloud workspace: the Mac was not connected, so it has not been built or seen running.** The repository's own checks pass there: every file parses, 761 logic tests pass and no platform problems are found. Those checks cannot compile a screen, and none of this code is covered by a logic test, because it all needs Apple's camera and picture libraries.

William, 21:44, with a picture of the "+" menu on the Journal page showing "From a file" and "From Photos": "I want an open camera option on phone and ipad".

## What changed, and why

**Before.** A photo could be chosen from Photos, chosen as a file or dragged in. To photograph something in the garden he had to leave Windfall, take it in the Camera app and come back to choose it. The app had no camera code and no leave to use the camera (doc 33 listed it as not built).

**Now.** "Take a photo" is a third choice in three places, on an iPhone or iPad only:

- the "+" on Eira's bar, on every page. On the Journal page the photo starts an entry. Elsewhere it brings up the card of three offers, as any other photo does.
- the camera button in Eira's chat. She says what the photo shows.
- the Identify screen, as a button beside "From Photos" and "From a file". The three buttons now wrap on to a second row on a narrow screen.

A Mac shows no such choice. So does the simulator, which has no camera.

## The code, explained

### `CameraPhoto.swift` (new)

Apple's camera screen is an older, UIKit screen called `UIImagePickerController`. Windfall's screens are SwiftUI. Most of the file is the bridge.

- `CameraPhoto.isAvailable` asks the device whether it has a camera. Each place draws "Take a photo" only if the answer is yes.
- `.cameraPhoto(isPresented:onTaken:)` is a modifier any screen can add. `isPresented` is a `Binding`: a two-way link to a true-or-false value. The screen sets it true to open the camera and the camera sets it false when it closes. `onTaken` is the code to run with the photo.
- `CameraScreen` is a `UIViewControllerRepresentable`: SwiftUI's wrapper for a UIKit screen. Its `Coordinator` is a small helper object, because UIKit reports "Use Photo" and "Cancel" by calling functions on an object, and a SwiftUI view is not one.
- **The photo is handed over only once the camera has slid away** (`onDismiss`). What receives it usually opens a sheet, and iOS will not open one sheet while another is closing.
- `CameraFile.jpeg` puts the picture and the camera's notes back together as one JPEG file. The camera hands them over apart. The rest of Windfall reads a photo's date out of the file (`PhotoFacts.swift`), so without this a photo from the camera would have no date of its own. It also writes which way up the phone was held, or a portrait photo would lie on its side.

Everything that touches UIKit is inside `#if os(iOS)`, so the Mac build does not see it.

### `Info.plist`

`NSCameraUsageDescription`: the sentence iOS shows the first time, beside Allow and Don't Allow. Without it iOS closes an app the moment it asks for the camera.

### `EiraFloatingBar.swift`, `EiraChatView.swift`, `EiraVision.swift`

Each gains one `@State` value (`isTakingPhoto`), one button and one `.cameraPhoto` line. Each hands the photo to the function it already had for a chosen photo (`takePhotos`, `look(at:)`, `take`), so a photo from the camera is treated exactly like any other.

## 22:15: a copy in Photos, a switch for it and the photo's position

William, 22:03: "I'd like it saved into photos as well. you should be able to turn this off. It should record gps."

**Also not built or seen running.** Written the same way, after `main` (`2507727`) was merged into the branch. The checks pass: 114 files parse and 778 logic tests pass, one of them new.

- **A copy in Photos.** After the photo is handed to Windfall it is added to the Photos library, as the same file, so its date and position go with it. `CameraRoll.save` in `CameraPhoto.swift`. It asks iOS for leave to add only (`.addOnly`), not to look at the library. If that is refused the photo still reaches Windfall and no copy is made.
- **The switch.** Settings, under Photos: "Save camera photos to Photos". On unless switched off. It is shown only on a device with a camera. The choice is stored under the name `cameraSavesToPhotos`, written once as `CameraRoll.settingKey` so Settings and the camera cannot drift apart. `@AppStorage` is SwiftUI's way of tying a switch to a stored setting.
- **The position.** Apple's camera screen does not say where the phone was. So when the camera opens, Windfall asks the phone for its position once (`findPlace`, using the app's existing `LocationManager`). When "Use Photo" is pressed the position is written into the photo's file the way a camera writes it (`CameraFile.gps`): how far north and east, a letter for which way, how accurate, the height and the time. If the position has not arrived by then it waits up to two seconds more. With location off for Windfall, or no position in time, the photo is kept without one.
- Because the position has to be known before the file is made, the file is now made after the camera closes, not at the moment "Use Photo" is pressed. `CameraShot` carries the picture and the camera's notes across that gap.
- `PhotoFacts.written` (new, with a logic test) turns a signed number such as -2.6 into the camera's form, 2.6 and "W". It is the reverse of `PhotoFacts.coordinate`, and the test checks that one undoes the other.
- `Info.plist`: `NSPhotoLibraryAddUsageDescription` added, and the location sentence now also says it notes where a photo was taken.

## 22:40: the camera in the seed packet scanner

William, 22:30: "Can seed packet scanning access camera as well?"

**Also not built or seen running.** 114 files parse and 778 logic tests pass.

- **`SeedPacketScanner.swift`: "Photograph the packet"**, above "Choose a photo of the packet", on a device with a camera. One `@State`, one button and one `.cameraPhoto` line. Both ways in now end in one new function, `read(_:)`, which shows the photo, reads it and guesses the plant's name.
- **A packet photo is not copied to the Photos library**, whatever the Settings switch says. `.cameraPhoto` gained a setting for this, `savesToPhotos`, which is true unless a screen says otherwise. The scanner says false.
- **A fault found and fixed: the scanner read portrait photos sideways.** A phone stores a portrait photo on its side with a note saying which way to turn it. The scanner handed Apple's text reader (Vision) only the pixels, so the note was lost. It now hands over the photo's file (`VNImageRequestHandler(data:)`), and Vision turns it upright itself. This affected photos chosen from the library as well, and would have affected nearly every packet photographed with the camera.

## Not done

- **One photo at a time.** The camera closes after "Use Photo".
- Not added to the sighting form, the old diary form, the journal conversation's own photo button or "Add a photo" on the pin-down card. Each is one button and one line now that `CameraPhoto.swift` exists.
- If camera access is refused, Apple's screen opens black. If adding to Photos is refused, no copy is made. Windfall does not yet say so or point to Settings in either case.
- The photo's position is in its file and in the photo's record. It is still not copied to a sighting's own position (doc 33).

## To check on a device

1. The first "Take a photo" asks for the camera, with Windfall's sentence.
2. A portrait photo and a landscape photo both arrive the right way up.
3. On the Journal page the photo starts an entry and no "which day" card appears, since it was taken a moment ago.
4. On the iPad the camera covers the whole screen.
5. The menu's order by the "+". iOS turns a menu over when it opens upwards.
6. The first photo asks to add to Photos, and the photo then appears in the Photos app with its place on the map.
7. With the Settings switch off, no copy appears in Photos.
8. A photo taken within a second or two of opening the camera: does it have a position?
9. Scan a packet: photograph one held upright. The words should be read, and no copy should appear in Photos.

# 14 November 2026, 21:35: a fungus key to step through, with a diagram for each choice

**By the mushroom key chat.** William, 18:21: "I want to step through the key in app." At 18:39, choosing a key of Windfall's own over showing someone else's: "B. And ill check the text." At 20:09: "Connect to my mac to attach changes to the main file. Can you make the diagrams a lot better please." At 20:17, with a picture of the new flower shape drawings: "more what we're after".

**What it is.** Wildlife has a new tile, **Fungus key**. It asks one question at a time, each choice with a drawing beside it, and ends at a group or genus: 21 steps, 106 choices and 83 answers. An answer says what to check, names a few common kinds, carries a warning where the group holds deadly or poisonous fungi, and says what it means in a garden. "Add a sighting" starts an unconfirmed sighting with the steps taken written into its notes.

**What it is not.** It never says whether anything can be eaten, and a test fails if the word "edible" appears in it. It is fixed words with no model in it. Eira is unchanged and still refuses to name a fungus (`EiraSafety.fungiReply`).

**⚠️ Every word of the key was written by Claude from memory and none has been checked.** `FungusKey.json` says `"checked": false` and the page says "To check" until that is changed to `true`. It is not copied from John Wright's key, which William sent as the model: that is his copyright. Project doc 58.

| File | What it is |
|---|---|
| `Windfall/FungusKey.json` | The key itself. **Correct the words here.** The app follows |
| `Windfall/FungusKey.swift` | The rules: reading the file, remembering a walk and stepping back, what a sighting made from an answer holds, and `faults()`, which lists anything wrong with the file |
| `Windfall/FungusKeyView.swift` (new) | The page: the trail of choices as buttons that go back, the question, a card for each choice, the answer card |
| `Windfall/HubScreens.swift` | The tile, after "Identify from a photo" |
| `Windfall/WildlifeModels.swift` | `IDSource` gains `key`: a name reached by stepping through a key. It is kept as a word, so older records still open |
| `Windfall/Theme.swift` | `WIcon.fungusKey`, the tile's icon |
| `Design/Icons/fungus-*.svg` (53) | The diagrams, in colour on a 100 by 100 grid, in the bold manner of the flower shapes. **The same in light and dark mode**: William saw them with a pale outline and with the dark green kept, on a dark background, and at 21:22 said of the second "Yes, that's better." |
| `Tools/design/build_design_assets.py` | `fungus-` joins `shape-` in `SAME_IN_DARK`, the list of drawings that get no dark-mode copy (the flower shape chat added that list the same evening) |
| `Design/Icons/fungus-key.svg` | The tile's icon, an outline like the others |
| `Tools/design/fungus_kit.py`, `fungus_diagrams.py` | The code that draws the diagrams. `python3 Tools/design/fungus_diagrams.py Design/Icons`, then the build script |
| `Windfall/DemoGarden.swift`, `MainTabView.swift` | A checking aid: `-demoGarden YES -startSection gardens -demoFungus r-honey` opens the key at that step or answer, for a still picture |
| `Tools/checks/` | 16 new tests, and `FungusKey.swift` added to the files that are type-checked |

**Why the walk is its own small type.** `FungusWalk` holds the choices taken and where they led, with no screen code in it, so the tests can take a walk, step back and start again without building a screen. The page keeps one in `@State` and draws whatever it has reached.

**Checked:** the project's checks with Swift 6.3.1 in a cloud workspace: 112 files parse, the type check passes, 765 logic tests pass. The tests read the real key and fail if a choice leads nowhere, an answer cannot be reached, or a diagram it names has no drawing.

# 14 November 2026, 20:35: Settings and tools redrawn as tiles

**By the settings chat.** William, 20:29, with a picture of the page on his Mac: "Can you make this settings page better?" The page was a plain list of nine names in a thin line of text at the top of an empty window, while Gardens and Wildlife beside it were drawn with a serif title and glass tiles. Project doc 70.

**What you see now.** A serif title, "Settings and tools", and nine glass tiles under three headings. Each tile has an icon, its name and one line about what is behind it:

| Heading | Tiles |
|---|---|
| Set up | Settings, Reminders, Voice, Corner drawing |
| Find and look back | Search everything, Charts, Knowledge base |
| Your records | Backup, Export records |

Five of the lines are read from the app as it stands, so a tile can tell you something without being opened: Settings says "Recording as William" once a name is set, Reminders says On or Off, Voice says whether Eira reads her replies aloud, Knowledge base counts its documents and Export records counts what is waiting to be sent.

**The nine pages the tiles lead to are not changed.** They are still plain forms and lists.

## The code, and what it means

| File | What changed |
|---|---|
| `Windfall/HubScreens.swift` | The page, `MoreTab`, now lives here with Gardens and Wildlife, and is drawn from the same pieces they use |
| `Windfall/MainTabView.swift` | The old `MoreTab` taken out. A comment says where it went |
| `Windfall/ExportService.swift` | `ExportWaiting`, new: the one rule for what is waiting to be sent |

**Why it moved file.** `HubScreens.swift` already holds the pieces a page like this is made from: `ScreenHeader` (the line of text over a serif title), `HubSectionTitle` (a heading), `HubTile` (the icon, name and line) and `hubTileGlass()` (the glass behind a tile). Two of the things it needs, the page widths and the little function that writes "1 bed" or "3 beds", are marked `private`, which means only code in the same file may use them. Putting the page in that file lets it use them as they are.

**Two small functions do the repeating.** A tile was going to be written out nine times and a grid three times, so each is written once:

```swift
private func tile<Page: View>(_ icon: HubIcon, _ title: String, _ detail: String,
                              @ViewBuilder page: () -> Page) -> some View {
    GrowingLink(destination: page) {
        HubTile(icon: icon, title: title, detail: detail)
    }
    .hubTileGlass()
}
```

- `private func tile` makes a function that only this page can use.
- `<Page: View>` says "this works for any kind of page". It is a placeholder: the nine tiles each lead to a different kind, and Swift fills the placeholder in for each.
- The underscores (`_ icon`) mean the caller does not write the name, so a tile reads as `tile(.symbol("bell"), "Reminders", remindersLine) { NotificationSettingsView() }`.
- `page: () -> Page` is a piece of code handed in, to be run to make the page. The curly brackets after the call are that piece of code.
- `GrowingLink` is the link from doc 49: on an iPhone or iPad the page grows out of the tile.

**How a tile knows the state of things.** Three kinds of line at the top of the page each read something and redraw the page when it changes:

```swift
@Query private var documents: [KnowledgeDocument]
@AppStorage("recorderName") private var recorderName = ""
@State private var remindersAreOn: Bool?
```

- `@Query` asks the database for every record of a kind. Here they are only counted.
- `@AppStorage("recorderName")` reads one saved setting by its name. The Settings page writes it and this page reads it.
- `@State` is the page's own memory. The `?` after `Bool` means "true, false or not known yet". Whether reminders are allowed has to be asked of the system, which takes a moment, so the tile says only what reminders are for until the answer is in. That way it never says "Off" and then changes its mind.

**One rule for "waiting to be sent".** The Export page already worked out how many sightings and counts were ready. The new tile needed the same sums. Writing them out a second time would let the two drift apart, so the sums moved into `ExportWaiting` and both now ask it. The Export page gives the same numbers as before.

## Checked

| Check | Result |
|---|---|
| Logic checks, Swift 6.3.1 for Linux, in this chat's cloud workspace | 110 files valid, type check passed, cross-file checks clean, **749 logic tests pass, 0 fail** |
| The Mac, unsigned | `set1-mac.log`, 20:54: BUILD SUCCEEDED, no warnings in the three files |
| The simulator | `set1-sim.log`, 21:08: BUILD SUCCEEDED |
| **Looked at on the Mac**, in a test copy with the example garden, in dark mode | The page is as described. All nine tiles are the same height and every line fits on one line. A click on Charts opened Charts |

The cross-file check tripped twice on the first try, on names only. A function called `total` was taken for another file's `total`, and `count: ExportWaiting.wormCounts(...)` was read as "count is an ExportWaiting". The function is now `altogether`, and the Export page's worm count has a name of its own, `pendingWormCounts`.

## Not checked

- **Light mode, an iPhone and an iPad.** The simulators would not start: the Mac was very busy with other chats' builds and the simulator service stopped answering. Two simulators made for this chat, "Windfall settings iPad" and "Windfall settings iPhone", are left for the next try (`windfall-build-logs/settings-shots.sh`).
- **On an iPhone the tiles are two across**, so some of the lines will run to two lines and tiles in one row may differ a little in height. Gardens has the same.
- **With William's own records.** The test copy used the example garden.
- Reminders reading "On". The test copy had never been allowed to send any, so it read "Off".

## ⚠️ CHECK: choices that are Claude's

1. The three headings and which tile sits under which. Settings is first because "Settings" is what the sidebar calls the page.
2. The words of every line on a tile, and the line over the title.
3. The icons that are Apple's symbols until drawings are made: the bell, the chart, the books, the drive and the arrow out of a box. Settings, Voice, Search and Corner drawing use Windfall's own.
4. "Knowledge base" has books for its icon in place of the brain.
# 14 November 2026, 22:58: on an iPhone or iPad, pressing send in the journal puts the keyboard away

**By the "iPad" chat, on the branch `journal-send-keyboard`, made from `journal-send-closes` (the entry below), so it holds that work too. Not in `main`.** Project doc 73.

William, 22:56, with three pictures from his iPad: "it looks like a journal entry is hidden because of the keyboard. I think it could be resolved by when you press send the keyboard goes."

**What the pictures showed.** After dark, with words in the journal's box and the keyboard up, the card "It is 22:53 and dark out. Was this about earlier today?" was pushed up the screen with its question out of sight. The branch below already lets go of the keyboard once an entry has gone. It did not when send was held back by that card, which is the moment the card most needs to be seen.

One file changed, `Windfall/JournalChatView.swift`, in one place: near the top of `send()`, before the check for the question card.

```
#if os(iOS)
boxHasFocus = false
#endif
```

- `boxHasFocus` is a `@FocusState`: SwiftUI's record of whether the box to write in has the cursor. Setting it to false takes the cursor out, and iOS lowers the keyboard when no box has it.
- `#if os(iOS)` ... `#endif` compiles the line only for an iPhone or iPad. On a Mac there is no keyboard on the screen, and the cursor stays in the box for the next entry.
- It comes before the check for the question card, so the keyboard goes whether the entry is sent or held back for an answer.

**The cost:** to write a second entry straight after the first, the box has to be tapped again.

# 14 November 2026, 22:02: sending a journal entry puts the panel away

**By the "send closes" chat, on the branch `journal-send-closes`, written from William's phone with no Mac linked. Not built and not tried: no Swift compiler was to hand. Not in `main`.**

William, 21:46, with a screen recording from his iPhone: "When I press send, it should send. I shouldnt then need to press done."

**What the recording showed.** A photo and the word "Test" in the journal's panel, after dark. Two things stood between pressing send and being back on the Journal page:

1. The card "It is 21:45 and dark out. Was this about earlier?" was up. Send did nothing but turn it amber. After choosing "Now", send had to be pressed a second time.
2. Once sent, the panel stayed up with "Noted at 9:45 pm" in it until Done was pressed.

One file changed, `Windfall/JournalChatView.swift`, in three places.

**1. The end of `send()`: the panel closes itself.**

```
if let panel, offers.isEmpty, pinDown == nil,
   NewPlantMention.name(in: text, known: plants.map(\.commonName)) == nil {
    boxHasFocus = false
    panel.close()
}
```

- `if let panel`: `panel` is an optional, a value that may be missing (nil). It is set only when the conversation is drawn in the panel. `if let` runs what follows only when it is there, so a conversation in a sheet is unchanged.
- The commas mean "and". `offers.isEmpty`: Eira found no harvest or sowing to add. `pinDown == nil`: nothing seen and unnamed to pin down. `NewPlantMention.name(...) == nil`: no plant the library lacks. **If any of the three has a card to show, the panel stays up**, because closing would throw the card away before it was seen.
- `boxHasFocus = false` lets go of the keyboard so it does not cover the page.
- `panel.close()` is the same function Done calls (`lowerPanel` in `EiraFloatingBar.swift`).

**2. `answer(_:)` and `answerPhotoCheck(_:with:)`: choosing a time sends, if send was already pressed.**

```
let sendWasPressed = checkWasSkipped
...
checkWasSkipped = false
if sendWasPressed { send() }
```

`checkWasSkipped` is set to true when send is pressed while the question is unanswered. It is copied into `sendWasPressed` first because the next lines clear it. If the question is answered before send is pressed, nothing is sent, as before.

**3. The amber line on the card** now reads "Choose one and it will be sent." in place of "Choose one, then send."

**Claude's choices, for William to confirm:** the panel stays up when Eira has a card to show; the keyboard is put away as the panel closes; the time question is still asked and is not skipped.

**To try:** after dark, a photo and a word, press send, choose "Now": it should send and the panel sink. Then "Harvested 2 kg of potatoes": the panel should stay, with the harvest card. On a Mac the keyboard should go back to the bar's box.

# 14 November 2026, 21:44: the Mac's icon follows light and dark mode

**By the "Mac icon" chat, on the branch `mac-icon-dark`.** William, 21:32, once the cream icon was showing in the Dock: "The mac icon should also respond to the light and dark mode".

**Why the icon of 20:57 could not do it.** That icon was a set of plain pictures in the Mac's slots of `AppIcon.appiconset`. A Mac slot holds one picture. Only the iPhone's and iPad's slots have a second, dark one.

**What a Mac wants instead** is Apple's newer kind of icon, a folder whose name ends in `.icon` (the kind its Icon Composer app makes). It holds the drawing and the background apart, so the Mac can change either with the mode. The Mac now has one, `Windfall/AppIconMac.icon`:

| File | What it is |
|---|---|
| `AppIconMac.icon/Assets/snowdrop-light.svg` | The light drawing from `Design/AppIcon`, with its cream background rectangle taken out |
| `AppIconMac.icon/Assets/snowdrop-dark.svg` | The dark drawing (the thin cream outline), with its green background rectangle taken out |
| `AppIconMac.icon/icon.json` | The instructions: which drawing and which background colour for which mode |

**What `icon.json` says, a piece at a time:**

```
"fill-specializations": [
  { "value": { "solid": "srgb:0.98039,0.93333,0.87843,1.00000" } },
  { "appearance": "dark", "value": { "solid": "srgb:0.02353,0.25882,0.10588,1.00000" } }
]
```

The background. `fill` is the colour behind the drawing. A "specialization" is a value for one mode. The first line names no mode, so it is the ordinary one: cream. The second is for `dark`: the icon's dark green. A colour is written as red, green, blue and solidness, each from 0 to 1. Cream `#FAEEE0` is 250, 238 and 224 out of 255, which is 0.98, 0.93 and 0.88.

```
"image-name-specializations": [
  { "value": "snowdrop-light.svg" },
  { "appearance": "dark", "value": "snowdrop-dark.svg" }
]
```

The drawing, in the same pattern: the light drawing ordinarily and the dark one in dark mode.

```
"glass": false     "specular": false     "shadow": { "kind": "none" }     "translucency": { "enabled": false }
```

Apple's glass look, switched off. Left on, the Mac lays a shine and a shadow over the drawing as if it were a pane of glass. Off, the icon is the flat drawing William approved.

```
"supported-platforms": { "squares": ["macOS"] }
```

This icon is for the Mac only.

**How the Mac build is told to use it.** One line, twice, in `Windfall.xcodeproj/project.pbxproj` (once for the Debug build and once for Release):

```
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
"ASSETCATALOG_COMPILER_APPICON_NAME[sdk=macosx*]" = AppIconMac;
```

The first line was there already: the app's icon is the one called `AppIcon`. The second is new. The square brackets are a condition: "when building for a Mac, the name is `AppIconMac`". So an iPhone or iPad build is untouched and still uses the pictures in `AppIcon.appiconset`.

**No Swift changed.** The app's folder is one that Xcode reads whole, so a file put into `Windfall/` is in the app with nothing more to do.

**Taken out again**, because nothing uses them now: the ten Mac slots in `AppIcon.appiconset/Contents.json`, the seven `windfall-app-icon-mac-...png` pictures and `Tools/design/make_mac_app_icon.swift`. They are in the repository's history at `e7cb8be`.

**Two modes come free.** macOS also has a tinted and a clear icon style. The Mac makes both from the same drawing by itself.
# 14 November 2026, 21:55: Today scrolls again on an iPhone and iPad

**By the Today scroll chat, from William's iPhone. Branch `today-scroll-iphone`, made from `main` at `4b28986`. Not in `main`. Written in Claude's cloud workspace: the Mac was not connected and the workspace has no Swift, so it has not been built, parsed by the Swift compiler or seen running.**

William, 21:41: "On the current iphone build, you can't scroll up and down on the today view".

## The cause

Carrying Today's cards about (`home-screen-rearrange`) joined `main` at 18:18 today. It had only ever been built and tried on a Mac. Its own notes said: "iPhone and iPad: Not built. The press and hold has to live alongside scrolling there."

Each card had a SwiftUI press-and-hold followed by a drag, added with `simultaneousGesture`. On a touch screen, since iOS 18, a SwiftUI gesture of that kind on something inside a `ScrollView` takes the touch from the first moment and the page never scrolls. `simultaneousGesture` does not prevent it. Apple's developer forums have long threads on it. On an iPhone the cards fill Today, so there was nowhere left to scroll from. A Mac scrolls with the trackpad or wheel, not a press, so it never showed there.

**This is Claude's reading of the code and of those reports. It was not confirmed by running anything.**

## What changed (`TodayBoard.swift` only)

- **On an iPhone or iPad the press and hold is now UIKit's long press** (`FingerHold`, a `UIGestureRecognizerRepresentable`). UIKit's long press and the page's scrolling settle between themselves whose touch it is: a finger that moves scrolls, a finger held still for 0.45 seconds lifts the card.
- **On a Mac nothing changes.** `withPickUp` in `BoardCard` picks the gesture when the app is built, with `#if os(iOS)`.
- `hold` and `slack` are the two figures both gestures share: 0.45 seconds and 10 points to start the jiggling, 0.15 seconds and 40 points once jiggling.
- `FingerHold.Coordinator` tells UIKit the long press may not run alongside a scroll view's own gestures, and may run alongside anything else, as `simultaneousGesture` allowed before.

## Checked

| | |
|---|---|
| Braces and brackets balance, iPhone-only code is fenced (`check_platforms.py`) | Yes |
| Swift's own syntax check, the type check, the logic tests | **No.** No Swift in this workspace. No logic file changed |
| Builds for iPhone, Mac or simulator | **No** |
| Tried by hand | **No** |

## To check when it is built

1. iPhone: does Today scroll, starting with the finger on a card and on a button inside a card?
2. Press and hold a card for half a second: do the cards jiggle and does the card lift and follow the finger?
3. While jiggling: does a quick swipe over a card scroll, and a short hold lift it?
4. Carry a card to the top or bottom edge: does the page scroll under it?
5. Hold a button inside a card until the card lifts, then let go: the button should not fire.
6. Mac: carrying cards is as it was.

## ⚠️ CHECK

- If the build fails on `FingerHold`, the likeliest lines are `context.converter.location(in: .named(TodayBoard.pageSpace))` and the `Coordinator` class's `@MainActor`.
- If Today scrolls but a card will not lift when the press starts on a button, the `Coordinator`'s answer is the place to look.
# 14 November 2026, 21:55: a job's name keeps a small word that belongs to it

**By the job-wording chat, from William's iPhone. Branch `job-title-keeps-in`, made from `main` at `4b28986`. Not in `main`. Written in Claude's cloud workspace: the Mac was not connected, so it has not been built or seen running.** Only `GardenJobs.swift` changed, which has no screen code, and it is type-checked and tested here. 763 logic tests pass, 2 of them new.

William, 21:43, with a picture of the card from his phone: "This nearly worked but the actual task was worded wrong". He typed "I need to put the raspberry cables in this month." The card said "Put the raspberry cables". It should say "Put the raspberry cables in".

## Why it happened

The reader lifts the day out of the sentence ("this month") and then tidies the end of what is left. The tidying took off any small word found there: "in", "on", "up", "down", "over", "by", "for" and others. That was written for "fix the gate by tomorrow", where "by" belongs to the day. But in "put the cables in" the "in" belongs to the job. The old rule could not tell the two apart. It even cut "I need to dig the potatoes up" to "Dig the potatoes", with no day in the sentence at all.

## Now

- **"in", "on", "up" and "down" stay**: "Put the raspberry cables in", "Dig the potatoes up", "Turn the heater on".
- **"by", "for", "at", "before", "until", "during", "to" and "the" come off only if the day or garden they led up to was lifted out.** "Fix the gate by tomorrow" is still "Fix the gate". "Find something to tie the beans to" keeps its "to".
- "In the" or "on the" before a day still goes: "Sow the beans in the next week" is "Sow the beans".
- **"Over" depends on the job's first word.** "Turn the compost over this weekend" keeps it. "Mulch the beds over this weekend" drops it. ⚠️ CHECK: the words that keep it are Claude's list: turn, fork, dig, rake, hoe, go, look, check, tip, flip, roll, knock.

## The code, explained

`hanging`, one set of words, is now three sets: `closers` (always tidied off: "please", "and"), `links` (tidied off only when what followed has gone) and `particles` (kept).

```swift
var keptAt = body.filter { !leftOut.contains($0) }
```

Before, this line held the words themselves. Now it holds each word's place in the sentence, a number, because the next step has to ask what came straight after a word.

```swift
var gone = leftOut
while let last = keptAt.last {
    let word = plain[last]
    let nextIsGone = gone.contains(last + 1)
```

`gone` is a set of places: every word lifted out as the day or the garden. `while let last = keptAt.last` reads "for as long as there is a last word, call its place `last`". `gone.contains(last + 1)` asks whether the word after it was lifted. In William's sentence "in" is word 7 and "this" is word 8, which is in `gone`.

```swift
    } else if links.contains(word) {
        isHanging = nextIsGone
    } else if particles.contains(word) {
        isHanging = nextIsGone && tookArticle
```

A link word hangs if what it led to has gone. A particle hangs only if a "the" was taken off just after it as well: `tookArticle` remembers that from the turn of the loop before. `&&` is "and".

```swift
    guard isHanging else { break }
    gone.insert(last)
    keptAt.removeLast()
```

`break` leaves the loop at the first word worth keeping. Otherwise the word's place joins `gone`, so the word before it is judged the same way.

## Not changed, and seen while here

- "Sometime tomorrow" is read as no date, because "sometime" comes first and the earliest wins. "Tomorrow" then stays in the job's name.
- "By next week" and "by tomorrow" lose the "by" from the name but are not read as "from today until then".

# 14 November 2026, 19:20: the to-do cards on Today open out where they are

**Joined to `main` at 21:32 on 14 November 2026** by the night join chat, in its own copy (`~/Developer/windfall-night`, branch `join-14nov-night`). It merged cleanly with the weather work in `TodayView.swift`. Built for the Mac (`nt3-mac.log`) and the simulator (`nt4-sim.log`) together with Eira's more solid bar and the flower shapes: both succeeded. 761 logic tests pass. **It has still not been seen running or tried by hand.**

**By the to-do chat, from William's iPhone. Branch `todo-cards-open`, made from `main` at `71d95d4`. Not in `main`. Written in Claude's cloud workspace: the Mac was not connected, so it has not been built or seen running.**

William, 19:00: "We need to make it so that when you tap to do they expand to give you the whole month". Asked what a tap should do, he chose: the card opens out where it is on Today and lists every job, and a second tap folds it.

## What changed, and why

**Before.** "This week" drew six jobs and "This month" drew five. If there were more, a small "View all" link slid in a separate page. And the month's list was cut short before it was ever drawn: four sowings and three harvests at most, so "View all" did not show the whole month either.

**Now.**

- The heading of each card is a button whenever the card holds more than it shows. Beside the title it says how many are tucked away, "12 more", with a down arrow. A tap opens the card and the cards beneath slide down. The words become "Show fewer" and the arrow turns over.
- An opened card has "Show fewer" at its foot as well, so a long list can be folded without scrolling back up.
- **"This month", opened, is the whole month**: every plant whose sowing months include this one and has not been sown this year, every crop due within a fortnight, every seed packet to check, and your own jobs. Folded, it is the same short pick as before.
- A card stays as it was left, open or folded, after visiting a plant's page and after the app is closed.
- With "Reduce Motion" on, a card opens at once with no sliding.
- The "View all" page for jobs (`AllJobsView`) is gone. Nothing else used it.

## The code, explained

### `WeekJobs.swift`: `JobFold`, the sums

Kept apart from the screen so the logic tests can run them.

```swift
static func rowsShown(of count: Int, folded: Int, isOpen: Bool) -> Int {
    isOpen ? count : min(count, folded)
}
```

`a ? b : c` reads "if a then b, otherwise c". Open: every row. Folded: the smaller of how many there are and how many a folded card holds.

`monthPick(from:)` takes the identifiers of the whole month's jobs and gives back the folded card's short list. It walks the list once, counting sowings (identifiers beginning `sow-`) and harvests (`harvest-`). `continue` means "skip the rest of this turn of the loop", so the fifth sowing and the fourth harvest are passed over. `kept.prefix(monthRows)` then takes the first five.

`headingWords(hidden:isOpen:)` gives "12 more", "Show fewer" or nothing. Its answer is `String?`: the question mark means "a String, or nothing at all". `guard hidden > 0 else { return nil }` reads "carry on only if something is hidden, otherwise hand back nothing".

### `TodayView.swift`

```swift
@AppStorage("todayWeekIsOpen") private var weekIsOpen = false
@AppStorage("todayMonthIsOpen") private var monthIsOpen = false
```

`@AppStorage` is a value SwiftUI saves on the device under the name in quotes and redraws the screen for whenever it changes. Plain `@State` would forget it when Today is rebuilt, which happens each time the page is returned to.

`jobs` no longer has `.prefix(4)` and `.prefix(3)` on its two loops. It now works out the whole month, and the folded card asks `JobFold.monthPick` for its short list.

```swift
private func jobsHeading(_ title: String, hidden: Int, isOpen: Binding<Bool>) -> some View
```

One heading for both cards. A `Binding<Bool>` is not a copy of true or false but a handle on the value the screen keeps, so the function can change it. `$weekIsOpen`, with the dollar sign, is how that handle is passed. `isOpen.wrappedValue` is the value inside it.

```swift
withAnimation(reduceMotion ? nil : .snappy(duration: 0.3)) { isOpen.wrappedValue.toggle() }
```

`toggle()` flips true to false and back. `withAnimation` tells SwiftUI to move everything that changes because of it over 0.3 seconds. `nil` means no animation.

`.contentShape(.rect)` makes the whole width of the heading answer a tap, not only the words. `.allowsHitTesting(hidden > 0)` switches the button off when there is nothing more to show.

## ⚠️ CHECK: choices that are Claude's

1. **"This week" opens to all of this week's jobs, not to the month.** "This month" is the card that gives the whole month.
2. **The whole month can be long.** In a spring month with many plants marked as growing it could run to a hundred rows or more. Nothing limits it.
3. A card stays open until it is folded, even across starting the app again.
4. The heading is the button, not the whole card: each row is already a link to its plant, and its tick box is a button.
5. The words "12 more" and "Show fewer".
6. The folded month's caps are now applied after jobs already in "This week" are left out, where before they were applied first. A folded card can show a sowing it used to drop.

## Checked

| | |
|---|---|
| Every file reads as valid Swift (109 files) | Yes |
| The rules type-check | Yes |
| Logic tests | 739 pass, 5 of them new |
| Builds for the Mac, iPhone and iPad | **No** |
| Seen running | **No** |

`TodayView.swift` is a screen, so here it has only been read as valid Swift. The first Mac build is its real test.

## Not done

- The widgets are unchanged. A widget cannot grow.
- While the cards are being rearranged (jiggling), a heading does not answer a tap, as with everything else inside a card.
# 14 November 2026, 21:20: the flower shape drawings keep their dark outline in dark mode

**By the flower shape chat.** William was sent the light-mode drawings unchanged on the dark background, beside the dark-mode copies with a pale outline that the app had been given. He chose the first: "Yeah, that's better. Leave them unchanged."

| File | What and why |
|---|---|
| `Tools/design/build_design_assets.py` | New `SAME_IN_DARK`: a colour icon whose name starts `shape-` gets no dark-mode copy, so its one drawing is shown in both modes. Every other colour icon is treated as before |
| Both asset catalogues | Rebuilt: the twenty `shape-*-dark.svg` copies are gone, and each `Contents.json` lists one picture |
| `Windfall/FlowerShapeViews.swift`, `Design/README.md` | Comments and notes only |

No Swift code changed. **Not built**: only pictures and their lists changed. The cost William saw and accepted: bare stalks and the umbel's spokes, drawn only in the outline colour, are faint on the dark background.

# 14 November 2026, 20:57: the Mac gets the app icon

**By the "Mac icon" chat, on the branch `mac-app-icon`.** William, 20:52, with a picture of his Dock showing two blank tiles for Windfall: "None of the apps have the icon on the app icon."

**Why the Dock was blank.** The icon went in at 17:36 for iPhone and iPad only. `AppIcon.appiconset/Contents.json` is the list of slots an icon has, and each slot says which kind of device it is for. Every slot in it said `"platform" : "ios"`. A Mac build looked for slots marked `"idiom" : "mac"`, found none, and so made no icon file at all: the built Mac app had no `AppIcon.icns` and no icon named in its `Info.plist`. macOS then draws its blank placeholder. iPhone builds made since 17:36 do carry the icon (`AppIcon60x60@2x.png` is inside them).

**No Swift changed.** Three things were added:

| Where | What |
|---|---|
| `Tools/design/make_mac_app_icon.swift` | A short script that makes the Mac's pictures from the iPhone's square one |
| `AppIcon.appiconset/windfall-app-icon-mac-16.png`, `-32`, `-64`, `-128`, `-256`, `-512`, `-1024` | The Mac's pictures, made by that script from the light icon |
| `AppIcon.appiconset/Contents.json` | Ten Mac slots added. The three iPhone and iPad slots are as they were |

**Why the Mac needs different pictures.** An iPhone takes a plain square and rounds the corners itself. A Mac shows the picture as given, so it must arrive already cut to a rounded square with clear space round it: 824 dots across on a 1024 dot canvas, 100 dots clear each side, which are Apple's measurements. It also wants ten slots (16, 32, 128, 256 and 512 points, each at 1x and 2x) where an iPhone wants one. Seven pictures fill the ten slots, because 16 at 2x and 32 at 1x are the same 32 dots, and so on.

**What a Mac slot looks like:**

```
{
  "filename" : "windfall-app-icon-mac-32.png",
  "idiom" : "mac",
  "scale" : "2x",
  "size" : "16x16"
}
```

`idiom` is the kind of device. `size` is in points, the unit screens are measured in. `scale` is how many dots there are to a point: `2x` is a sharp (Retina) screen, so a 16 point icon at 2x is a picture 32 dots across.

**Checked on the Mac (macOS 27.2.1, Xcode 27.2):** Xcode's asset step (`actool`) for the Mac, with no errors or warnings, now makes `AppIcon.icns` and names `AppIcon` as the icon. The same step for iPhone and iPad gives what it gave before. A stand-in app holding only that icon was made in `/tmp`, and macOS was asked how it would draw it: the cream tile, full size, with no grey box round it (macOS puts an icon of the wrong shape in a grey box). Twelve points of the Mac picture match the same points of the square one exactly, so nothing is flipped or shifted.

**Not done:**

- **A dark icon on the Mac.** These slots take one picture, so the Mac shows the cream icon in light and dark mode. A Mac icon that changes needs Apple's newer icon file, made in its Icon Composer app.
- The tinted slot for iPhone and iPad is still empty.

# 14 November 2026, 20:25: the flower shape drawings redrawn in colour, with shading (branch `flower-shape-drawings`)

**By the flower shape chat.** William, of the one-colour outlines: "Go back through the files and make them more realistic, but still graphicky. they might need shading." Of a sample of four: "They're much better".

| File | What and why |
|---|---|
| `Tools/design/flower_shapes.py` | Rewritten. Each drawing is now built back to front from filled pieces, like cut paper, so a petal can sit in front of another. Shade is a darker tone or a thin dark wash on the side away from the light |
| `Design/Icons/shape-*.svg` (20) | Redrawn by that script, in colour. Same names, so nothing that looks a drawing up by name changes |
| The two asset catalogues | Rebuilt by `build_design_assets.py`: the twenty are now "colour icons", each with a dark-mode copy whose outline is pale |
| `Windfall/FlowerShapeViews.swift` | `FlowerShapePicture` no longer tints the drawing. It has `faded`, which the list uses for a gap: most of the colour washed out, and thinner. A shape's own page always shows it in full colour |
| `Windfall/DemoGarden.swift`, `MainTabView.swift` | Checking aids: `-demoFlowerShapes YES` opens the list and `-demoFlowerShape Bilabiate` one shape's page |
| `Design/README.md` | Brought up to date |

The colours are those of the plant each drawing is taken from: blue borage, a pink dog rose, a yellow flag iris, a lilac sage. ⚠️ CHECK: the botany and the colours are Claude's own and have not been checked against a book.

# 14 November 2026, 19:35: flower shapes get drawings and a page each (branch `flower-shape-drawings`, not built)

**By the flower shape chat, from a cloud workspace. Nothing here has been built in Xcode or seen on a screen.** The branch was made from `main` at `71d95d4`.

William, of the Flower shapes page on his iPhone: "We need graphics for these." Then, of the first drawings: "Make them a bit more detailed." Then: "Icons next to text and then when you tap them they can expand into a bigger tile page that has a bigger image and details and then examples of what we have that has these flowers."

## What changed

| File | What and why |
|---|---|
| `Design/Icons/shape-*.svg` (20 new) | One drawing for each shape in the Flower Form Guide, each of a real plant: a dead-nettle for bilabiate, borage for stellate, a knapweed for tubular capitate. Black only, so the app paints them green or grey |
| `Tools/design/flower_shapes.py` (new) | Draws those twenty files. The drawings are kept as code so that a line can be moved by changing a number |
| `Windfall/Assets.xcassets/Icons`, `WindfallWidgets/Assets.xcassets/Icons` | The same twenty, put there by `build_design_assets.py`. Not edited by hand |
| `Windfall/FaunaModels.swift` | New `FlowerShapeGuide`: the name of a shape's drawing, which plants have a shape, which shapes the garden has, and which animals are recorded on a shape. Here, not in the screen, so it can be tested without a Mac |
| `Windfall/FlowerShapeViews.swift` (new) | `FlowerShapeCoverageView`, moved from `FaunaViews.swift` and redrawn: a tile for each shape with its drawing beside the words. New `FlowerShapeDetailView`: the page a tile grows into |
| `Windfall/FaunaViews.swift` | The old plain list taken out. A note says where it went |
| `Tools/checks/LogicTests.swift` | Seven new tests, one of which fails if any shape in the real guide has no drawing |
| `Design/README.md` | A section on the flower shape drawings |

## The list page

It was a standard list in the system's look. It is now drawn like Today (the rule in project doc 00): glass tiles on paper.

- Each tile has the drawing at 56 points, then the name, the description and the insects, then the tick or the dashed circle as before.
- **A tile grows into its page** when tapped, and the page shrinks back into it on the swipe back. That is `GrowingLink` from `GrowFromTile.swift`, the same piece the Gardens and Wildlife tiles use.
- The shapes are now in name order. Before, they came in whatever order the database gave them.

## The page for one shape

- The drawing at 200 points on a card of its own.
- The plain word for the shape, its name in the title serif, and a tag: "In your garden" or "A gap in your garden".
- **The shape**: the guide's description and note.
- **Who it feeds**: the guide's insects, then every animal the Plant-Fauna Links sheet records on a flower of this shape, as small labels.
- **In your garden**: the growing plants that have the shape. Each opens that plant's page.
- **On your list to buy**: the same for plants still to buy. Left out when there are none.
- **Plants to try**, or **Other plants with this shape** when the garden already has one: the guide's own examples.

## One change to the count

A plant now also counts as having a shape when its own "Flower Form" names one. Before, only the links sheet counted. Four plants in the starter data carry "Stellate" there, so "Shapes present" may go up by one where none of them is in the links sheet. ⚠️ CHECK with William that a plant's own Flower Form should count.

## Checked

- `Tools/checks/run-checks.sh` with Swift 6.3.1: all 110 Swift files pass the syntax check, the logic files pass the type check, the cross-file checks are clean, and **741 tests pass** (734 before).
- `build_design_assets.py` reports 50 outline icons, up from 30, and changed no existing file.

## Not checked

- **It has not been compiled.** `FlowerShapeViews.swift` is screen code, which these checks only read for syntax. The first build in Xcode may find mistakes.
- How the drawings look when Xcode draws them, at 56 or at 200 points.
- The tile growing into its page, on a real iPhone.
- On a Mac the page slides in as every page does there: `GrowingLink` only grows on iPhone and iPad.

## For the chat that builds it

1. Merge `main` into `flower-shape-drawings` first, then build it for the Mac and the simulator.
2. Look at Wildlife, Species, Flower shape coverage, and open a shape the garden has and a gap.
3. Join it to `main` only once it builds and William has seen it.
# 14 November 2026, 21:00: photos show at once, and a journal entry can be changed

**By the "photo speed" chat, on the branch `photos-faster-entry-edit`, made from `main` at `9b18bb4`. Not in `main`.** William, 20:38: "When you add photos to Eira, it's really slow to actually show them. I know it's doing a lot to process them. There's also no way to edit journal entries".

## Photos

**What was slow.** Not the image model. Every small copy of a photo in the app was made by one function, `DiaryEntryEditor.thumbnail`, which:

1. opened the whole photo (a phone's photo is 12 to 48 million dots, 50 to 190MB once opened out in memory),
2. drew it again smaller, at the screen's own scale, so that on an iPhone a "1024" copy came out 3,072 dots wide and a "2048" copy larger than the photo it was made from,
3. saved the drawing as a JPEG,

all on the main thread. A thread is one line of work the device is getting on with, and the main thread is the one that draws the screen and answers touches. While it was opening a photo, nothing on screen could change. A photo given to Eira's bar was opened this way two or three times: for the card that asks what to do with it, again for the journal's box or the Identify screen, and again when kept. And nothing at all was shown between choosing a photo and the last of that work finishing. **⚠️ CHECK: this is read from the code. It has not been timed on the phone.**

**What changed.**

| File | Change |
|---|---|
| `PhotoShrink.swift` (new) | `PhotoShrink.jpeg(from:longestSide:)` makes a copy with ImageIO, Apple's reader for picture files, which reads a photo straight down to the size wanted without ever holding the full-size picture as a drawing. `SpeciesEye.swift` already read photos this way for the image model. Sizes are now in pixels and the same on every device: 600 for a tile, 1,200 for the card, 2,048 for the copy Eira looks at and a sighting keeps. `PhotoWorkshop` is an `actor`: an object that does one job at a time, off the main thread. Photos are shrunk through it one after another, so ten large photos are never open at once |
| `JournalViews.swift` | `DiaryEntryEditor.thumbnail` keeps its name, because nine places call it, and now hands the work to `PhotoShrink`. It is marked `nonisolated`, "may be run from any thread" |
| `PhotoDrop.swift` | `WaitingPhoto` and `WaitingPhotoTile`: a photo that has been chosen and is on its way, drawn as a grey tile with a spinner until its small copy is ready. `PhotoDrop.pictures(from:)` for the Photos chooser fetches every chosen photo at the same time (`withTaskGroup`) and hands them back in the order chosen. They were fetched one after another |
| `JournalChatView.swift` | A tile for each photo goes into the box the moment it is chosen. Each fills in when its photo arrives. Send waits while one is still on its way |
| `PhotoOffer.swift` | The card of three offers shows a grey tile for each photo at once and fills them in |
| `EiraChatView.swift` | "Fetching the photo…" shows from the moment one is chosen. The copy is made in the background |
| `EiraVision.swift` | The Identify screen the same |
| `EiraFloatingBar.swift` | The "+" turns into a spinner while chosen photos are fetched |
| `PhotoStore.swift` | The copy kept in the app when the original goes to the photo folder is 2,048 pixels, where it was "2,048 points" |

Every Photos chooser is also given `preferredItemEncoding: .current`, which asks for each photo as it is stored. Left to itself the chooser may first convert a photo to another format.

**⚠️ CHECK, Claude's choices:** the three sizes. The copy kept with a sighting where no photo folder is chosen is now 2,048 pixels on every device. Before, it was 3,072 on an iPhone and 2,048 on a Mac. One photo is shrunk at a time, so ten photos fill in one after another.

**Not changed:** fetching a photo from the Photos library is Apple's and can still take seconds when iCloud holds the original. The tile and its spinner are there meanwhile. Sending an entry with photos still writes each original to the photo folder before the entry appears.

## Changing a journal entry

**What was there.** Press and hold on an entry in the journal's conversation gave Rename, Change the details and Delete. Nothing on screen said so, the conversation only shows the day it is on, and an entry on the Journal page could not be opened at all. "Change the details" opened the old diary form, a standard `Form`, which wrote every key press straight into the entry, so its Cancel undid nothing.

**What changed.**

| File | Change |
|---|---|
| `JournalEntryEditor.swift` (new) | `JournalEntrySheet`, built from the pieces in `SheetParts.swift`. The words, the heading, when it was, the weather and temperature, which bed it is about, photos added and taken off, and Delete, which asks first. It keeps its own copy of each thing, a draft, and writes the draft into the entry only when Save is pressed |
| `JournalViews.swift` | On the Journal page an entry you wrote is a button with a small pencil at its end. A tap opens the sheet. Sowings, harvests and sightings on the page are as they were |
| `JournalChatView.swift` | A pencil beside each entry's stamp opens the sheet. Press and hold still works, with "Change this entry" first. The old form is no longer opened from anywhere. It stays in `JournalViews.swift` because `thumbnail` lives in it |
| `JournalChat.swift` | `JournalChat.heading(own:written:typed:oldWords:newWords:known:)`: what becomes of the heading. Left alone, a heading of your own stays and one written for you is written again if the words changed. Emptied, one is written from the words. Typed over, it becomes your own. Seven logic tests |

**⚠️ CHECK, Claude's choices:** the weather does not follow a changed time by itself. Where the weather diary has the new time, a button offers its figures. An entry cannot be dated in the future. Deleting asks first. On the Journal page there is no press and hold, only the tap.

**Not built:** opening a sowing, a harvest or a sighting from the Journal page.

## Checked

- The repository's checks, Swift 6.3.1 for Linux in the chat's cloud workspace: 112 files valid, type check passed, 30 record types and 30 in the schema, **756 logic tests pass** (749 before, 7 new).
- `Photo.lastPathComponent` is a new false alarm in the name-guessing check, in `SpeciesTestRun.swift`, where `photo` is a file's address. It is in `known-false-alarms.txt`.
- **Built for the Mac with no errors**, twice: the first version (`ps1-mac.log`, 21:21) and the branch as it now stands, `ff77c82` (`ps2-mac.log`, 21:54). In the chat's own copy `~/Developer/windfall-photospeed` and its own build folder `DerivedData/Windfall-photospeed`.
- **Built signed for the iPhone with no errors** (`ps3-iphone.log`, 21:48), as the branch `photos-faster-phone-mix`: this branch with `eira-put-away` merged in, because that is what the phone held at the time. **That branch is for the phone only and is not to be merged into `main`.** Not installed.
- **`PhotoShrink.jpeg` run on the Mac by itself against the old way**, on four test pictures made for the purpose (`/tmp/photospeed-test`, 21:26, while three other builds were running, so the times are long and only their ratio means anything):

| Picture | Tile, old | Tile, new | Eira's copy, old | Eira's copy, new |
|---|---|---|---|---|
| 12 million dots, JPEG | 1.69 s | 0.38 s | 6.80 s | 1.63 s |
| 24 million dots, HEIC | 4.03 s | 0.73 s | 8.61 s | 1.96 s |
| 48 million dots, HEIC | 8.01 s | 0.92 s | 7.05 s | 0.48 s |
| 1,200 by 900, JPEG | 0.09 s | 0.005 s | 1.10 s | 0.10 s |

  Each copy came out the right size, and three bytes that are not a picture gave nothing back, as they should. The last row shows the old way making a small picture larger: 1,200 dots wide became 2,048.
- **Not done: nobody has pressed anything.** No screen has been looked at, on a Mac or a phone, and nothing has been timed on the phone.
- A photo that no small copy can be made of is kept, with a plain photo symbol on its tile. (The first version of this branch dropped it.)
# 14 November 2026, 22:45: drawing a garden on the plan, step by step, and three ways to set north

**By the Gardens page chat (knowledge base docs 50, 63 and 71).** Branch `garden-draw`. **Not in `main`.** William, 20:26: "The main issues are the drawing of the garden and orientation of it, that interface was difficult to use." Then, of storyboards E, F and G on the design canvas, 20:44: "Put them all in for now so I can test them out."

**Every option is in, side by side, behind "Edit layout" on a garden's plan card. It is there to be tried, not as the finished design.**

| File | What |
|---|---|
| `Windfall/GardenDrawing.swift` (new) | The sums, with no screens: snapping to ten centimetres, turning, repeating a bed in a row, north from a place on a ring, a plot's corners on a map. Also `PlanPlaceable`, a protocol that lets a bed and a feature be handled the same way |
| `Windfall/GardenDrawView.swift` (new) | "Drag it, then type the number". `GardenDrawBoard` is the plan that can be touched: drag to move, a ring at the far corner to size, a green knob to turn. `GardenDrawView` is the page, with the chosen thing's four numbers as buttons. Sheets for typing numbers, a new bed, "Repeat" and the plot. `DrawMaker` makes beds and features |
| `Windfall/GardenDrawSteps.swift` (new) | `GardenDrawSteps`: the plot, north, each bed, then sheds and trees, one question at a time with a picture. `GardenDrawChooser`: the page that lists every editor and every way of setting north |
| `Windfall/NorthSetters.swift` (new) | `NorthRing` and `NorthRingSetter` (drag an N round a ring), `NorthByPointing` (the device's compass, with a picture of where to stand), `NorthByMap` (the plot's outline over a satellite picture, using MapKit) |
| `Windfall/GardenPlanView.swift` | "Draw this garden" and "Edit layout" open `GardenDrawChooser`. They opened `GardenEditorView`, which is now one of the chooser's entries |
| `Windfall/DemoGarden.swift` | Checking aid: `-demoEditor YES -demoDraw drag\|steps\|ring\|point\|map\|chooser` |
| `Tools/checks/LogicTests.swift`, `logic-files.txt` | 20 new tests. 768 pass |

**No record changed shape.** Beds, features and gardens are stored exactly as before, so nothing needs migrating and the older editor reads what the new ones write.

**North is stored as it always was** (`Garden.topFacesDegrees`). The new screens show it the other way round: the plan stays as drawn and north moves.

**New to the app: MapKit**, in `NorthByMap` only. Opening that page asks Apple Maps for a satellite picture of where the garden is.

Checking aids: `-demoDrawChoose YES` starts the drag page with the first bed chosen. `-demoDrawStep 3` starts the steps at step 3. `-startSection gardens` is needed with `-demoEditor`, because the editor stands in for the Gardens page.

**Built** for the Mac and the simulator (`gd3-mac.log`, `gd3-sim.log`). **Seen** as still pictures on an iPhone simulator. **Not tried by hand by Claude:** no drag, twist, resize or typing.

# 14 November 2026, 20:10: plant drawings added to the Design folder

**By the plant graphics chat.** William, 18:15: "Could you create graphics for all the plants I'm growing and have seeds for. Create a graphic for each phase of their life that are relevant." At 19:06: "Make them a bit more detailed and do them all". At 20:06: "Connect to my mac to attach changes to the main file".

**No Swift changed and nothing in the app shows them yet.** This adds files only:

| Where | What |
|---|---|
| `Design/Plants/light`, `Design/Plants/dark` | 908 drawings in each: 172 kinds of plant at each stage of life that applies |
| `Design/Plants/plant-drawings.json` | Each kind, its stages and labels, and the library names that use it |
| `Design/Plants/README.md` | What the files are and how to make them again |
| `Tools/design/plant_kit.py`, `plants.py`, `plants_all.py` | The code that draws them. Needs only Python |

**Shading**, at William's word of 20:08 ("If the diagrams need shadowing to make them look more realistic and understandable you could add shading"): every rounded shape has a soft crescent of shade on its lower right, stems and trunks a band down one side, leaves a darker half, and each plant a faint shadow on the soil. It is one named colour, `shade`, laid thinly over the others, so it darkens in light and in dark mode.

**They are a first pass and William has not approved them.** Ten kinds are drawn by hand and 162 are built from templates with Claude's own settings for each plant, none yet checked. Project docs 58 and 59.

**Not done:** showing a drawing on a plant's card or page. That is Swift work for a chat that builds.
# 14 November 2026, 19:40: Eira's open bar is more solid

**By the "bar opacity" chat, on the branch `eira-bar-opaque`. In `main` since 20:40. It builds for the simulator (`bo1-sim.log`, 20:31). Not yet seen on any device.**

William, 19:34, with a picture of the Journal page on his iPhone: the day's entries and photos showed through the open bar and ran into "Tell Eira". "Could you make Eira's bar more opaque".

**What changed.** One file, `EiraFloatingBar.swift`.

- The open bar now has a layer of the paper's colour inside its glass:
  `.background(Theme.paper.opacity(expanded ? Self.barFill : 0), in: .capsule)`.
  `.background(..., in: .capsule)` paints a colour behind the bar's buttons and words, in the bar's own pill shape. `Theme.paper` is the page's colour, so it is cream in light mode and dark green in dark mode. `.opacity(...)` sets how solid it is. `expanded ? x : 0` means "x when the bar is open, otherwise 0", so the closed snowdrop keeps its clear glass.
- `barFill` is a new named number, 0.85. 0 is clear glass and 1 is solid paper. It is the one number to change if the bar should be more or less solid.
- The glass itself is untouched, so the bar keeps its rim and its shine when pressed.

**⚠️ CHECK:** 0.85 is Claude's choice. It needs a build and a look in light and dark mode.
# 14 November 2026, 20:10: Eira's bar and keyboard put away by touch again, and a swipe down on the panel

**By the "put away" chat**, from William's phone and then his Mac. Branch `eira-put-away`, made from `main` at `8fd0f0c`.

William, 19:37: "the tapping and swiping to close Eira isnt working at the minute on the phone". Asked where: on the Journal page and on the other pages, both.

**Two different causes.**

1. **On the Journal page it never could.** The bar is always open there, so the code that puts the bar away was switched off (`canBePutAway`), and nothing else put the keyboard away.
2. **On the other pages it had worked at 16:57 and then stopped.** The first version hung an invisible layer, 4,000 points square, out beyond the bar's own strip to catch touches on the page. The bar's code was then reshaped for the panel and the two were joined by hand at 17:13. Why touches stopped reaching the layer was not found.

## What changed

**`EiraFloatingBar.swift`**

- **The touch layer is now inside the bar's own space.** Since the panel, the bar is given the whole page to stand in (`growsInPlace`). The layer is the first thing in the bar's `ZStack`, so it is underneath everything, and exactly as large as that space. A view is only certain to be handed a touch that lands inside the space its parent gave it, which is the same reason the panel is drawn inside that space.
- `touchAwayLayer(travel:fillsTheSpace:)`: `fillsTheSpace` chooses between the new layer and the old huge one. The old one is kept only for a bar that is no taller than itself, which no layout uses today.
- **`keyboardCanBePutAway`**, new: true when the bar stays open (pinned, or on the Journal page) and its text box has the keyboard.
- **`touchPutsSomethingAway`**, new: `canBePutAway || keyboardCanBePutAway`. The layer is only there while this is true, so the page works as usual the rest of the time.
- **`putAway(travel:)`**, new: closes the bar if it can close. Otherwise it sets `fieldHasFocus = false`, which hands the keyboard back, and the bar stays open.
- The swipe down on the bar calls `putAway` too, so on the Journal page it puts the keyboard away.
- `swipeDownPutsAway` was `private` to this file. It is now usable from other files, so the panel can use it.

**`EiraPanel.swift`**

- **A swipe down on the panel's heading lowers the panel**, as Done does. `contentShape(.rect)` makes the empty stretch between the title and the buttons count as part of the heading. Only the heading takes the swipe, because the conversation below it scrolls.

**A Mac is unchanged.** All of this is inside `#if os(iOS)`.

## Not changed

- A tap on the page does not close the panel. On an iPhone the panel covers the page, and on an iPad the page behind it is meant to stay in use.
- The first touch that puts the bar or keyboard away is still not passed on to the page.

## CHECK: choices that are Claude's

1. On the Journal page a touch puts the keyboard away and leaves the bar open.
2. The same applies on an iPad, and wherever "Keep the bar open" is ticked: while the bar's box has the keyboard, the first tap on the page only puts the keyboard away.
3. The swipe down on the panel's heading. William was asked whether he wanted it and did not say.

# 14 November 2026, 18:40: seven branches joined into main

**By the join chat.** William, 16:44: "When all the app builds have finished, I want to combine them and then issue an iphone, ipad and mac build to test further." The Mac went quiet at 18:17. The join was made in a copy of its own, `~/Developer/windfall-join`, on the branch `join-14nov-evening`, and `main` moved only once it built and passed its tests.

**What came in**, in this order:

| Branch | What it is | Had it been built before? |
|---|---|---|
| `home-screen-rearrange` | Carrying Today's cards, like a Home Screen | Yes, at midday |
| `journal-follow-up` | "Want to pin it down?" in the journal | Yes, at 13:30 |
| `tile-grow` | A page grows out of the tile that was tapped | Yes, and on the iPhone at 17:08 |
| `larger-text` | Every text style one step larger | No |
| `plant-fill-in`, which carries `eira-web-finds` | Kept facts. A new plant is looked up. A plant's gaps are filled | No |
| `own-jobs` | Jobs of your own, added by telling Eira | No |

`tile-grow-phone-mix` was left out, as its own note asks: it was for the phone only.

**Every entry below that says "not in main", "not built" or "not yet merged" for one of these branches is out of date as of this entry.**

## Where the branches met, and what was done

A "clash" is a place where two branches changed the same lines, so git cannot choose for itself and marks both versions in the file for a person to settle.

| File | The clash | Settled by |
|---|---|---|
| `CHANGES.md`, `Tools/checks/logic-files.txt`, the logic tests | Each branch added its own entries at the same spot | Keeping both, one after the other |
| `JournalChat.swift` | Two branches each added a job to the list in the opening comment | Keeping both. The pin-down is now called the fifth job |
| `EiraChatView.swift`, `TodayView.swift` (with `larger-text`) | `larger-text` changed a text style on lines that another branch had since rewritten or removed | Keeping the newer code, then moving its text styles up (below) |
| `EiraChatView.swift` (with `plant-fill-in`) | The sheet for a plant's page and the sheet for kept facts were added at the same spot. So were two checking aids | Keeping both, each with its own closing brace |
| `EiraConversation.swift` | An example reply with lookups and the whole kept-find section were added at the same spot. Three lines that clear a waiting offer each gained one more line | Keeping both |
| `EiraFloatingBar.swift` | Both sides changed the list of names that open Eira's chat for a picture | One list holding every name |
| `TodayView.swift` (with `own-jobs`) | `main` had moved the gathering of the week's jobs into `WidgetShare.swift` so the widgets could use it. `own-jobs` still had the old gathering, with your own jobs added at its end | `main`'s one call, then your own jobs added to its answer and the list put in order again |

## Three things that did not build, and why

A join with no clashes is not proof that it builds. The compiler found three places where code from one branch relied on something another branch had changed.

1. **Eira's chat, three cards outside their message.** `main` now draws the chat turn by turn (`ForEach(turns)`), and a turn may have no message: lookups whose reply never came. The cards for a new plant, a kept find and a job were written when the chat was drawn message by message, so they used `message` where there might not be one. They now sit inside `if let message = turn.message { ... }`, which means "only when this turn has a message, and call it `message` in here".
2. **The journal's pin-down** called `SpeciesEye.monthTaken(of:)`, which `main` replaced at 13:33 with one reader for a photo's own facts. It now calls `PhotoFacts.read(from: data).month()`.
3. **The logic tests** had two values named `tall`, one from the Today board's tests and one from the photo tests. Swift does not allow the same name twice in one place. The Today board's is now `cardHeights`.

## Larger text, for the lines the other branches brought

`larger-text` moved 384 lines up one step. Lines written on other branches still had the old names. `windfall-build-logs/join-text-styles.py` found them: a line that is word for word in `larger-text`'s copy of the file has been moved up already, and any other line has not. 74 lines in 9 files were moved up by the same table:

| Was | Now |
|---|---|
| `.caption2` | `.caption` |
| `.caption` | `.footnote` |
| `.subheadline`, `.callout` | `.body` |
| `.headline` | `.title3.weight(.semibold)` |

- `.caption` was moved only in the seven files that were wholly new (`EiraChatCards`, `JobViews`, `JournalPinDown`, `KeptFactViews`, `LivingCorner`, `PlantFillInViews`, `TodayBoard`), each of which also used an old name that settles which table it was written to.
- **The widgets' own files are left at their old sizes**, as the fonts chat suggested: a widget has very little room.
- **⚠️ CHECK: the larger titles were not carried over.** `larger-text` also moved sheet titles and serif headings up a step. On the new screens those were left alone, because which `.title3` is a heading and which is not cannot be told by rule. Look at the sheets for a job, a kept fact and "Fill the gaps".

## Checked

| Check | Result |
|---|---|
| Logic checks, Swift 6.3.1 on Linux (`Tools/checks/run-checks.sh`) | 109 files read as valid Swift. The logic files type-check. 30 record types and 30 in the schema. **734 logic tests pass** |
| Built for the Mac | No errors, at the third attempt (`join3-mac.log`, 18:28) |
| Built for the simulator, which also builds the widget program | No errors, at the first attempt (`join4-sim.log`, 18:29) |
| A database made by `main` of 18:10 opens in this version | Yes. iPad mini simulator, a database of its own (`join-migrate.sh`, 18:32) |
| This version's database still opens in `main` of 18:10 | Yes |
| Crash reports | None |
| Pictures, with the example garden, their words read by `read-picture.swift` | Today on an iPad mini and an iPhone: the wigwam job in "This week", "+ Add a job", "Your jobs (2)", "Order seed potatoes" in "This month". The list of kept facts. Eira's chat with one closed bubble and the card that offers to keep a find. Rhubarb's page. "Fill the gaps" on Rhubarb 'Victoria', which read the real RHS page and offered 3 suggestions. `shots/join-*.png` |

The name-guessing check (`check_members.py`) raised 32 false alarms, because the joined branches brought new types whose usual variable names (`session`, `key`, `a`, `b`, `question`, `other`, `target`) are used for other things elsewhere. They are now listed in `known-false-alarms.txt`. The Mac build is the proof that they are false.

## Not checked

- **Nothing was tried by hand.** No press, drag or swipe. A script cannot make one.
- **Nobody has looked at a picture.** The join chat could only read the words in them. Whether the larger text fits its chips, buttons and rows is for William's eye.
- Carrying a card on Today now that the living corner, the widgets' card and your own jobs are on the same page.
- The "Fill the gaps" card on a plant's page was not in the top screen of the picture. The sheet it opens was.
- The new plant form (Plants, "+").

# 14 November 2026, midday: rearranging Today like a Home Screen

**The `home-screen-rearrange` branch**, made from `main`. Built for the Mac
(`rearrange-7-mac.log`) with no errors. The layout's 34 logic tests pass on
the Mac. **Carrying a card was tried on the Mac by a script, which moves the
pointer too fast to watch. The press and hold that starts the jiggling, and
how a carried card looks in the hand, have been tried by nobody yet.** Not
built for the iPhone or iPad.

William, of the build of 13 November: "The wiggle's still wrong and the
rearranging doesn't feel as natural as rearranging an ipad or iphone home
screen, which is more the feel I was after."

## What it does now

- **Press and hold a card** and they all jiggle, and the card under the
  pointer or finger lifts: it grows a touch and gets a shadow.
- **Carry it** and it stays under the finger. The other cards step aside as
  it passes, opening a space where it would go. A soft shape marks the space.
- **Let go** and it settles into the space.
- **Carried to the top or bottom edge of the window, the page scrolls.**
- A card carried from a column to the full-width stack, or back, changes
  shape in the hand to suit where it is going.
- **Reset and Done float in the top right corner.** The bar that pushed the
  page down has gone: it moved the cards out from under the finger that had
  just pressed one.
- **A click on the page between the cards, or Escape, is Done.**
- An empty column or full-width strip shows a dashed outline while
  rearranging, so there is somewhere to carry a card to.

## What has gone

- The label that followed the pointer, the "Drop here" spaces and the green
  outline on the card underneath. They belonged to the system's drag and
  drop, which this no longer uses.
- **The two arrows on each card.** A Home Screen has none. VoiceOver still
  has "Move earlier" and "Move later" on each card. ⚠️ CHECK with William
  that he does not want the arrows back.

## The jiggle

- Four full rocks a second at a steady speed, with no slowing at the ends
  of the swing, and a drift of about a point. These are the figures usually
  quoted for the Home Screen (looked up 14 November 2026; Apple publishes
  none). The versions of 13 November slowed at each end, which is how a
  pendulum moves.
- The ends of every card move about two points each way, so a wide card
  turns through a smaller angle than a narrow one.
- Each card starts at a different point in its rock, so no two keep time.
- To try other figures without a rebuild: `-jiggleSeconds 0.3`,
  `-jiggleTravel 3`, `-jiggleDrift 0`.

## Glass or paint: measured on the Mac

With `-jiggleMeter YES` the app writes how many times a second it draws to
`windfall-jiggle-meter.txt` in its temporary folder. In a half-width window
on William's Mac, 14 November:

| | Frames a second |
|---|---|
| Cards painted flat while they jiggle | about 57 |
| Cards left as glass (`-jiggleGlass YES`) | about 31 |

So the cards stay painted while they jiggle. The garden switch, "Start
count", "Done" and the quiet buttons were still glass and stood out
(William: "the allotment/permaculture bar looks strange", "the start count
doesn't look right either"). They are now painted too: `GlassSwitch` and
`QuietGlassButton` go through `cardGlass`, and the filled green button is
`.leafButton()` (Theme.swift). In dark mode the painted surface is a shade
lighter with a fainter edge, nearer to how the glass looks.

## How it is built

- **`TodayBoard.swift`** (new): `ArrangeSession` (which card is in the hand
  and where the finger is), `TodayBoardLayout` (one layout holding every
  card, so a card moved between columns slides there and does not fade out
  and in), `BoardCard` (the press, the lift, the jiggle) and `Jiggle`.
- **`TodayLayout.swift`**: `TodayBoardPlan`, the sums for where every card
  goes and which place is under the finger, and `move(_:toZone:place:)`.
  `TodayDropTarget` has gone.
- **`TodayView.swift`**: draws the board. `Wiggle`, `LiftToArrange`,
  `DragSurface` and `DragLabel` have gone.
- 15 new logic tests, among them one that tries every finger position on a
  page of unequal cards and checks the cards come to rest.

## On the Mac

- Its own working copy, `/Users/Home/Developer/windfall-rearrange`, built by
  `rearrange.sh` into `DerivedData/Windfall-rearrange`.
- **Built under its own name, `com.54brookroad.Windfall.rearrange`**, so its
  settings are kept apart from the real ones and a chat driving the screen
  can tell it from another chat's copy.

## To check

- Press and hold on a card that is mostly buttons (the capture buttons):
  does the button under the pointer fire when the press ends?
- On an iPhone or iPad: does a held card stop the page scrolling under it,
  and does a quick swipe over a jiggling card still scroll?
- Three columns on a wide window. Only two columns were tried.

# 13 November 2026, afternoon: This week, the sheets, the sliding switch and the sidebar

**On the `today-rearrange` branch**, after the morning's work below.
**None of it has been built on the Mac or seen running.** William was
at school and the Mac could not be reached. It passes the checks that
run without the Mac (every file reads as valid Swift, 323 logic tests
pass). Those do not build the screens. Expect things to put right when
it is first built, and treat how everything here looks as untried.

## 14 November 2026, 17:13: Eira's lookups in one closed bubble, and a card for the plant

**In `main` since 18:09.** Written on the branch `eira-thinking-bubble` in a cloud workspace with no Mac, then built on the Mac from 17:31 once William linked the chat to it and said, at 17:29, "add it into the next build". `main` was merged into the branch four times on the way (`43e8a3a`, `0c4857f`, `c8de15e`, `8341a3c`), because five other chats joined work to `main` in that hour. **It built for the Mac and the simulator with no errors at the first attempt** (`bb1`), and again after each later merge (`bb2`, `bb3`, in `DerivedData/Windfall-bubble`). 629 logic tests pass, 17 of them new. Seen as still pictures with the example garden (`shots/bb2-*`, `bb3-*`): the closed bubble and the plant card in the panel on an 11-inch iPad Pro and an iPhone 17 Pro, light and dark, and the bubble open with its first lookup open. **Not tried by hand: tapping the bubble, tapping a lookup, tapping the card and the plant's page that opens. Not seen: the Mac's own window, and the bubble while she is still replying.**

**Why.** William, 17:02, with a picture of Eira's chat on his iPhone after asking "Find all information about comfrey": "Eira could work a bit better. The searches that it does to present me with an answer should be in a closed 'thinking' bubble, unless you tap it to see what it's doing. This kind of search should also present you to a link to the database information you have as a little card." The picture showed four grey rows (`search_garden`, `plant_visitors`, `search_notes`, `lookup_species`) between his question and her answer. It also showed two faults he did not mention: her answer began "I have no sowings recorded for last week.", and the bold and italic marks were on screen as asterisks.

### 1. What you see

- **One small bubble above each reply**, closed: "Looked in 4 places". Tap it and it opens to a line for each lookup in plain words ("Searched your plants") with where it looked. Tap a line to see what came back. The model's own reasoning, where a model gives any, is in the same bubble. While she is still replying the bubble has a spinner, says "Thinking…" and names the newest lookup.
- **A card for each plant her lookups found in your library**, under the reply, headed "In your plant library". It is the same card as on the Plants page. Tap it and the plant's page opens as a sheet over the chat, with Done to come back. No more than three cards, then "and 2 more, on the Plants page".
- **Bold and italic are shown as bold and italic.**
- **The stray sentence is taken out** before the reply is shown.

### 2. Folding the conversation into turns (`EiraChatLayout.swift`, new)

The conversation is kept as a flat list: your message, each lookup, her reply. The screen used to draw that list as it stood. `EiraChatLayout.turns(from:)` now folds it first:

```swift
struct Turn: Identifiable {
    let id: UUID
    let lookups: [ChatMessage]
    let message: ChatMessage?
}
```

- A `struct` is a small bundle of values. This one is a message together with the lookups that led to it.
- `[ChatMessage]` is a list of messages. `ChatMessage?` with the question mark means "a message, or nothing": lookups can exist before her reply has come.
- `Identifiable` and `id` let SwiftUI tell the turns apart. The id is the message's own, so a photo or a correction card filed under a message still finds it.

```swift
case .tool:
    waiting.append(message)
case .assistant:
    turns.append(Turn(id: message.id, lookups: waiting, message: message))
    waiting = []
```

- The loop walks the list. A lookup (`.tool`) is put in `waiting`. When her reply (`.assistant`) arrives it takes everything waiting, and the waiting list is emptied.
- Lookups followed by another message of yours, because the reply was stopped, keep a turn of their own and are never handed to the next reply.

Nothing is changed in what is saved. A saved conversation opens with its bubbles and cards.

### 3. Which plants get a card

No new field is saved for this. A search of the plant library writes one line for each plant, starting with its name. `EiraChatLayout.plantNames(foundBy:among:)` reads those lines back and matches them to the names in the library. Where two names fit a line the longest wins, so the line for the cider apple Fiona is not taken for the plant called plain "Apple". A test runs the real search and reads its result back, so the two cannot drift apart unnoticed.

Cards come from `search_garden` and from a `lookup_species` that found the species in the plant library. `plant_visitors`, `whats_growing` and the notes give none yet.

### 4. Drawing it (`EiraChatCards.swift`, new, and `EiraChatView.swift`)

- `ThinkingBubble` is the bubble. `@State private var isOpen = false` is a value the view keeps for itself between redraws: whether it is open. It starts closed.
- `ChatPlantLinks` is the cards. Each is a button around the Plants page's own `PlantCardView`. Pressing one sets `plantToShow` on the chat screen, and `.sheet(item: $plantToShow)` there opens the plant's page. **Why a sheet and not a page pushed on to the chat:** since 17:04 the chat on a Mac or an iPad is drawn in the panel that grows out of Eira's bar, where there is no stack of pages to push on to. A sheet works there and on an iPhone alike.
- `EiraChatText.styled` hands the reply to Apple's Markdown reader with `inlineOnlyPreservingWhitespace`, which reads bold, italic and links and leaves line breaks alone.
- `ReasoningBox`, the blue box, is gone. Its job is inside the bubble. The live reasoning used to start open and now starts closed.
- In `MessageView`, a lookup is no longer drawn as a row of its own.

### 5. The stray sentence (`EiraChecks.swift`, `EiraTools.swift`)

Rule 8 of Eira's instructions gives an example of right wording: "I have no sowings recorded for last week". Apple's model said it back word for word in an answer about comfrey. `EiraChecks.withoutEchoedExample` takes that exact sentence out, unless the question speaks of sowing or a lookup reported on sowings, when it may be a true answer. The sentence now has one home, `EiraPrompt.nothingRecordedExample`, read by both the instructions and the rule. **The instructions themselves read exactly as before**, so her marks on the test sheet should not move.

### 6. A checking aid

`-demoOpen eira-lookups`, with the example garden, opens her chat on an example of William's question with three lookups, the closed bubble and the comfrey's card. No model is asked. `-demoOpen eira-lookups-open` is the same with the bubble and its first lookup open, because a script cannot tap.

### Not done

- **Nothing here has been pressed by hand.**
- In the panel in light mode the plant's card has almost no edge, because it is glass lying on glass. It reads as a card in dark mode and in a sheet.
- Drawings of each plant on the cards, which William raised in the same message as "a side note". Not started. The chat uses the Plants page's card, so a drawing added to that card will show in both places.
- In the picture her answer also said nothing was recorded about pollinators visiting comfrey, straight after giving what `plant_visitors` had found. That is the model, and is not changed here.
- Her spoken replies, if switched on, are still handed the reply with its asterisks.
## 14 November 2026, 17:55: an iPhone's conversations grow out of Eira's bar too

**On the branch `eira-panel-iphone`, made from `main` (`0c4857f`), with `main` (`ece03c9`) merged in.** Built for the Mac and the iOS Simulator with no errors (`eb6-mac.log`, `eb6-sim.log`, in `DerivedData/Windfall-eirabar`). 612 logic tests pass. Seen as still pictures with the example garden on an iPhone 17 Pro in the simulator (`shots/eb5-phone-*`): the journal's conversation in the panel, Eira's chat in the panel, and the Journal page with the bar at rest above the tabs. Not seen: Today on an iPhone with the snowdrop closed. **Nothing has been pressed by hand, and nobody has yet seen it with an iPhone's keyboard up.**

**Why.** William, 17:23: "Does the chat change width on window resize on a mac? I want it to behave the same way on iphone as well." The entry of 16:50 below gave the panel to the Mac and the iPad and left the iPhone with its sheets, which was Claude's choice and not his.

**The answer to his question.** Yes, up to a point. The panel is as wide as Eira's bar, and the bar is as wide as the page, so the panel narrows and widens as the window is dragged. It stops at 760 points, because a line of writing much wider than that is tiring to read. The button with two arrows lifts that limit.

### 1. What you see on an iPhone

Exactly what a Mac and an iPad do: send something from Eira's bar, or press its microphone or book button, and the bar grows upwards into the panel with the conversation in it. Done sinks it back. Two things differ, both because of the size of the screen:

- **The panel is always as tall as the page.** On a Mac it stops at 620 points unless made larger. An iPhone has no height to spare.
- **There is no button for a larger size**, because there is no larger size to go to.

The row of tabs along the bottom stays where it is, under the panel's foot.

### 2. How (`MainTabView.swift`)

The iPhone layout now places the bar the way the other layout does. Before:

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    EiraFloatingBar()
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
}
```

After:

```swift
.safeAreaInset(edge: .bottom, spacing: 0) {
    Color.clear.frame(height: EiraFloatingBar.restingHeight + 8)
}
.overlay(alignment: .bottom) {
    EiraFloatingBar(growsInPlace: true, takesPagePhotos: section == .journal)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
}
```

- `safeAreaInset` still keeps a strip clear at the foot of each page, so a long list can be scrolled out from under the bar. The strip now holds nothing (`Color.clear`) and is as tall as the bar plus the 8 points beneath it.
- `.overlay` is a layer on top of the page with the page's whole space. The bar sits at its foot and has the rest to grow into. In the strip it had 60 points and nowhere to go.
- `growsInPlace: true` asks for the panel in place of the sheets.

### 3. One bar for each tab (`EiraFloatingBar.swift`)

An iPhone has five tabs and each has a bar of its own. Photos dropped on the Journal page are handed to "Eira's bar" through the tracker (the entry of 16:50, part 6), and with five bars listening, the wrong one could have taken them and opened its panel on a tab nobody was looking at. `takesPagePhotos` is true only for the Journal tab's bar (`section == .journal`), and a bar where it is false leaves the photos alone.

### 4. The panel on a narrow bar (`EiraPanel.swift`, `EiraFloatingBar.swift`)

```swift
panel(for: open, room: geometry.size.height, isPhoneWide: barWidth < EiraPanel.phoneWidth)
```

A bar narrower than 500 points is on an iPhone, or on an iPad that is sharing its screen with another app. `isPhoneWide` then does two things: the panel is drawn at its fullest (`let isFull = panelIsLarge || isPhoneWide`), and `EiraPanelControls` is given `offersLargerSize: false`, which is what leaves the button out of the heading.

### 5. Photos dropped on the Journal page (`JournalViews.swift`)

They now go to the bar on every device. The page's own sheet is kept only for a Journal page shown with no bar at all.

### ⚠️ CHECK: choices that are Claude's

1. The panel on an iPhone is as tall as the page, with no smaller size.
2. The tabs stay showing under the panel.
3. Nothing but Done closes it. A swipe down on the panel does not.

### Not built

- A swipe down to put the panel away, as a sheet has on an iPhone.
- An iPhone held sideways. The panel is not fitted to a screen that wide and that short.
- `growsInPlace` is now true in every layout, so the two sheets in `EiraFloatingBar.swift` are never shown. They are kept so that going back is one word. If the panel stays, they can be taken out.
## 14 November 2026, 17:35: the text is one step larger everywhere

**On the branch `larger-text`, made from `main` (`0c4857f`).** **Not built and not seen running**: it was written in Claude's cloud workspace, which cannot build the app. It passes the checks that run without the Mac (92 files read as valid Swift, 599 logic tests pass). Those do not draw a screen. **It needs a build on the Mac and a look at each page before it joins `main`.**

**Why.** William, 17:24: "Use the bigger text in the next build". Most of the app's words were 12 or 15 points and Apple's own reading size, 17, was used five times. He saw the larger sizes drawn beside the present ones on the "Windfall fonts" canvas (column A2) first. No font is changed here, only sizes.

**What a text style is.** The app never names a size in points. It asks for one of Apple's named styles:

```swift
Text(job.title)
    .font(.subheadline)
```

`.font(...)` says how the words above it are drawn. `.subheadline` is a name. The device turns the name into points (15 on an iPhone at the standard setting), and into more if the owner has asked for larger text in Settings. So the change is a change of names, and the words still follow that setting.

**The rule: every job uses the style one step larger.**

| Job | Was | Now |
|---|---|---|
| Labels: a card's kind line, chips | `.caption2`, 11 | `.caption`, 12 |
| Details: dates, places, Latin names, tags | `.caption`, 12 | `.footnote`, 13 |
| List text, buttons, what was written | `.subheadline`, 15 | `.body`, 17 |
| The few `.callout` lines | 16 | `.body`, 17 |
| Card headings, names in a list | `.headline`, 17 semibold | `.title3.weight(.semibold)`, 20 |
| A plant's name on its card | `.headline.weight(.medium)` | `.title3.weight(.medium)`, 20 |
| Letter headings on Plants, the weather card's figure | `.title3` in the serif, 20 | `.title2` in the serif, 22 |
| Sheet titles and Eira's panel title | `.title2` in the serif, 22 | `.title` in the serif, 28 |
| The headline of an identification | `.title3`, 20 | `.title2`, 22 |
| Screen titles, the count's numbers | 34 and 42 | Unchanged |

`.headline` came with its own semibold. `.title3` does not, so the weight is now written out: `.title3.weight(.semibold)`.

**What changed.** 384 lines in 42 files, each a swap of one name for another, plus a table in `Theme.swift` saying which style goes with which job. **New screens should follow that table.** `.caption2`, `.subheadline`, `.callout` and `.headline` are no longer used anywhere.

**Not changed.**

- The 23 places that give a size in points (`.font(.system(size: 14, ...))`). All but the count's numbers size a symbol, such as the arrow on a button, not words.
- The symbols drawn with `.font(.title2)`: the send, stop and microphone buttons.
- Words drawn on a garden plan went from 11 to 12 with everything else. They are placed by sum, so look for labels that now touch.

**What to look for when it is built.** Anything with little room: chips and tags, the capture buttons on Today, the sidebar, the month page's rows, the stepper in a sheet, a plan's labels. The new sizes are close to what the old code drew with the device's text size set one notch larger, so a layout that copes with that setting should cope with this. ⚠️ CHECK: that comparison is from Claude's memory of Apple's size tables.

**On a Mac the gain is smaller.** macOS draws the same named styles smaller than an iPhone does, so Command and plus (13 November) is still the main way to enlarge a page there. ⚠️ CHECK: not looked at on the Mac.

**Joining it to another branch.** A branch written before this one still uses the old names. Where the two touch the same line, keep the other branch's line and move its style up by the table. Lines the other branch added also need moving up: search them for `.caption2`, `.subheadline`, `.callout` and `.headline`. **Do not search for `.caption`**, which is now a right answer.

## 14 November 2026, 17:48: a new plant is looked up, and a plant's gaps are filled in

**On the branch `plant-fill-in`, made from `main` at `0c4857f` with `eira-web-finds` joined to it. Written without the Mac, so NOT BUILT.** Every file reads as valid Swift and 664 logic tests pass, 29 of them new. The rules were also run from this branch's own code against the live RHS site for seven plants. **The screens have never been compiled or seen.** Expect things to put right at the first build.

**Why.** William, 17:06: "when you add a new plant to the app or tell Eira youve planted a new plant, it will run a search and fill in as much information about the plant as it can find and you just have to approve each thing. I'd also like a smart way to fill in the gaps."

**What was found first.** The app had no way to add one plant by hand: a plant could only arrive from the spreadsheet file or a seed packet. And the library is mostly gaps: of 437 rows, 19 have a hardiness, 24 have pruning advice and 14 have pests.

**What it does now.**

- **Plants has a "+" button.** It asks for a name, and optionally a variety, a Latin name and a group, adds the plant and opens the look-up at once.
- **A plant's page has a "Fill the gaps" card**: how many of the facts that matter are filled in, and "Look them up".
- **In Eira's chat and the journal's conversation**, saying you have planted, sown or bought a plant the library does not have ("I planted a medlar by the pond") brings a card: "Medlar is not in your plant library yet. Add it and look it up".
- **The look-up shows one card for each empty box it found something for.** Each has the value (which can be changed), the words it was read from, the source and how far it is trusted, and Keep and Skip. **Nothing is written until Keep is pressed on that card.** A kept value gets a KeptFact beside it, so the plant's page shows "RHS, kept Nov 2026" and it is due a check after two years, exactly as a fact kept from Eira's chat.
- **Under the cards, what is still empty**, with three ways on: Ask Eira (for the boxes she has a care lookup for), paste any web address to have the same rules read that page, or type the facts in.

**Where the suggestions come from, best first.**

1. **Your own library** (`LibraryFill`). If the other rhubarbs say "Hardy perennial", a new rhubarb is offered that. A box that can differ by variety, such as the harvest months, needs two other varieties that agree. No internet needed.
2. **The RHS** (`PlantFillIn.lookUp`). The growing guide is found from the plant's name, as Eira already does. Its month-by-month calendar gives the months to sow, plant and harvest. The guide links to the RHS's own page for the species and often the variety, and those hold height, spread, hardiness, sun, soil, pH, foliage, pests, diseases, pruning and propagation. At most three pages for one plant.
3. **Worked out from the family** (`FamilyRules`). The carrot family are umbellifers, most of the pea family fix nitrogen, and a vegetable in the cabbage family is a brassica. The family comes from the RHS's page, or from GBIF if only the Latin name is known. Marked "Worked out, not read".

**Facts are read by fixed rules, not by the AI model** (`PageFacts`). A rule reads the same page the same way each time and cannot make up a figure that is not on the page. Each rule gives nothing when it is not sure. What rules cannot do is read loose prose, which is what "Ask Eira" is for.

**How the code is laid out.**

- `PlantFillIn.swift` (new, no screens, in the logic tests): `PlantGaps` decides which empty boxes matter and to which plants (an apple tree is not asked when to sow it). `LibraryFill`, `RHSPage`, `PageFacts` and `FamilyRules` are the three sources. `PlantFillIn.suggestions` chooses one suggestion for each empty box and notes where two sources disagree. `NewPlantMention` hears a new plant in a sentence.
- `PlantFillInViews.swift` (new, screens): `NewPlantSheet`, `FillInSheet`, `GapsCard`, `NewPlantOfferCard`.
- `KeptFacts.swift`: a `KeptFact` gains `factKey`, so a kept value can sit in any of the record's 66 boxes and not only the 21 a sentence fits. Removing one and the source labels go through `PlantFacts`.
- `EiraSources.swift`: two more kinds of source, "Your own records" and "Worked out, not read". The RHS page finder moved here from `EiraTools.swift`, unchanged, so both can use it.
- `EiraWebLookup.swift`: a page that has been fetched keeps the page as the site sent it (`html`), because the calendar's coloured months and the links are lost in plain text.
- `EiraScreen.swift` and `EiraFloatingBar.swift`: a page can hand Eira's bar a question (`ask`), which is how "Ask Eira" works.
- `PlantLibraryView.swift`, `EiraChatView.swift`, `JournalChatView.swift`: the button and the cards.

**The join with `eira-web-finds`.** Seven files clashed and both sides were kept in each (`b5017dc`). One thing was put right on the way: a kept fact is now noted as changed by hand, so loading the spreadsheet file again no longer replaces it.

**Tried against the live RHS site** from this branch's code, on Linux: rhubarb 'Timperley Early' came back with 17 facts from the variety's own page and the guide. Leek with 10, including Alliums worked out through GBIF. Broad bean with 10, including "Nitrogen fixer". Apple, medlar and lavender with 3 to 5 each: their guides give no Latin name, so the species page is not found.

**Known weak points.**

- The RHS's calendar has one row for sowing and does not say indoors or outdoors. The page's wording decides, and the card says to check.
- The older style of RHS guide (`/fruit/rhubarb/`) has no calendar.
- Pruning, propagation, pests and diseases from a plant page are the RHS's own words, cut to a sentence or two, for William to shorten on the card.
- Flowering from a plant page is by season, so to the nearest three months.
- **Site terms are still open** (doc 36). This reads up to three RHS pages for one plant, when asked, saying it is Windfall.
- There is no list across the whole library yet of which plants have most to gain. `PlantGaps.mostToGain` is written and tested, with no screen.
## 14 November 2026, 17:47: jobs of your own, added by telling Eira

**On the branch `own-jobs`, made from `main` (`0c4857f`).** **Not built on the Mac and not seen running.** Written in Claude's cloud workspace from William's phone. It passes the checks that run without the Mac: all 94 files read as valid Swift, the rules type-check, and 624 logic tests pass, 25 of them new. Those do not build the screens. Expect things to put right when it is first built, and treat how the card, the sheet and the page look as untried.

**Why.** William, 17:19: "Sometimes the jobs that need doing in the garden aren't dictated by season or month and they're just jobs that need doing. It would be good to be able to add these in by telling eira... something like 'I need to build the wigwam in the allotment at the weekend' then eira adds that into the task list."

**Before.** "This week" and "This month" on Today were worked out from the plant library, the records and the forecast. Nothing could be added to them. Typed into Eira's bar, William's sentence went to her chat as a question, where a model would look for a record of a wigwam and find none.

**Now.**

- **Tell Eira.** Type or say something to do into her bar, on any page: "I need to build the wigwam in the allotment at the weekend". A card comes up, "Add a job?", with what she understood filled in: *Build the wigwam*, *This weekend*, *Allotment*. Anything can be changed. **Add** saves it. **Not a job** saves nothing and hands the words to her chat as an ordinary message.
- **In her chat** the same sentence gets the same card, under the message.
- **On Today** the job is listed in "This week" if its day is within seven days or has gone by, and in "This month" if it has no date or is for later in the month. Ticking it marks it done. It stays struck through for the rest of that day and is then gone from the lists. Tapping its words opens it to change or delete.
- **By hand.** "This week" has two new links at its foot: **Add a job**, which opens an empty form, and **Your jobs**, a page of every job: with a day, whenever and done in the last month.
- **No model is used.** Fixed rules read the sentence, as they do for the journal's harvest and sowing offers. So it works on an iPhone that cannot run Eira's model, it is instant, and the same words always give the same card.
- **Nothing is saved until Add is pressed**, which is the standing rule for everything Eira offers.

**What counts as a job.** "I need to", "we must", "I have to", "I've got to", "remind me to", "remember to", "don't forget to", "add a job to", "Job:" and "Need to" or "Must" at the start. Also something that needs doing: "The fence needs fixing by Friday". **Not jobs:** anything with a question mark, anything opening with an asking word ("do I need to water"), finding out ("I need to know when to prune"), and things already done ("I planted the garlic").

**What days it reads.** Today, tonight, tomorrow, at the weekend, next weekend, this week, next week, this month, next month, a day of the week ("on Saturday", "by Friday", "next Monday"), a date ("on 21 November", "on the 21st"), a month ("in March"), a season ("in winter", "before winter"), "in a fortnight", "in two weeks". "Soon" and "sometime" give no date. ⚠️ CHECK, Claude's choices: "next weekend" is the weekend after the coming one, "next Friday" is the Friday of next week, "at the weekend" said on a Sunday means that Sunday, and the seasons are the Met Office's (winter is December to February). The card shows the days it chose, so a wrong guess can be put right before adding.

**How it is built.**

| File | What it holds |
|---|---|
| `GardenJobs.swift` (new) | The record, the rules that read a sentence, the wording of a job's days and the rules for which list a job is in. No screen code, so it is tested without the Mac |
| `JobViews.swift` (new) | The "Add a job?" card, the sheet for adding or changing one by hand and the "Your jobs" page |
| `EiraConversation.swift` | `send` offers a job before the model is asked. `offeredJob` holds the offer for the chat screen |
| `EiraChatView.swift` | Draws the card under the message |
| `EiraFloatingBar.swift` | `ask()` checks for a job first and opens the card in a sheet |
| `TodayView.swift` | Jobs of your own in both lists, their ticks, and the two links |
| `WeekJobs.swift` | A new kind, `own`, and the sorting pulled out into `inOrder` so both kinds of job are sorted by one rule |
| `WindfallApp.swift`, `BackupService.swift` | The new record is in the database's list and in backups |
| `DemoGarden.swift` | Two example jobs |

*The record.* A new kind of record needs a class marked `@Model`, which asks SwiftData to store it:

```swift
@Model
final class GardenJob {
    var id: UUID = UUID()
    var title: String = ""
    var dueFrom: Date?
    var dueBy: Date?
    var siteKey: String?
    var doneAt: Date?
    ...
}
```

`Date?` with a question mark is an *optional*: a date or nothing. A job has a first day and a last day, so "the weekend" is Saturday to Sunday and "by Friday" is today to Friday. Both empty means whenever. `doneAt` is empty until the job is ticked. Every property has a starting value or is optional because iCloud sync needs that.

*Reading a sentence.* `GardenJobs.offer(in:today:places:)` takes the words and hands back a `JobOffer`, or `nil` if it is not a job. It works in four steps: split the text into words, find an opening such as "I need to", find the day and the garden anywhere in the sentence, and keep what is left as the title.

```swift
if !notAJob, offeredCorrection == nil, GardenJobs.offer(in: trimmed, today: .now) != nil {
    offeredJob = OfferedJob(messageID: sent.id, said: trimmed, at: .now)
    answerWithFixedWording(GardenJobs.offerReply)
    return
}
```

This is the new part of `send` in Eira's conversation. `!= nil` asks "did the reader find a job?". If so the offer is noted for the screen to draw, Eira answers in fixed words and `return` stops there, so the model never sees the message and cannot claim to have saved something.

*A job's days are worded fresh each time.* `whenLine` turns the two dates into words using today's date: "Tomorrow" on Friday is "Today" on Saturday, and a job whose day has gone reads "Was for Saturday 14 November". The words that were said are not kept for this, only the dates.

*Two kinds of tick.* A worked-out job's tick is kept in one line of text for the month, as before. A job of your own keeps its tick on its own record (`doneAt`), so it outlasts the month and will sync once iCloud is on. `JobRow` asks which kind it has been given:

```swift
if case .own(let own)? = job.link {
    own.doneAt = own.isDone ? nil : .now
} else {
    tickedStore = TickedJobs.toggling(job.id, in: tickedStore)
}
```

`if case .own(let own)? = job.link` reads "if this job's link is one of your own jobs, call it `own`". The line after it sets the tick time to now, or clears it if it was already ticked.

**The database.** `GardenJob` is a new record type, the 29th. Adding a type is the kind of change SwiftData makes by itself when an older database is opened. **It has not been tried: run `migrate-test.sh` on the Mac before this goes into `main`.**

**To check when it is built.**

1. The card in a sheet from Eira's bar, on the Mac, iPad and iPhone, light and dark. The When menu and the calendar are the system's own controls and may not sit well on the card.
2. The card under a message in Eira's chat, in the panel and in the sheet.
3. "Not a job" from the bar's card: her chat should open a moment later with the same words and no second card.
4. Today with `-demoGarden YES`: "Build the bean wigwam" in This week and "Order seed potatoes" in This month. Tick each, untick each, tap each to open it.
5. The two links at the foot of "This week" in a narrow column, where they may crowd.
6. A sheet opened from a row that is itself on the "Your jobs" page.
7. `migrate-test.sh`.

**Not done.**

- The journal's conversation does not offer a job. "Mulched the raspberries. Need to net the brassicas at the weekend" typed there is saved as an entry and no card is shown. The reader already finds the job in it.
- Eira cannot read your jobs back ("what have I got on this week?"). She needs a tool that reads the same lists.
- Jobs do not appear on the Year page's months or in the widgets (which are not in `main`).
- No reminder is sent for a job.
- A job cannot repeat ("every Sunday").
- One job a message. "I need to build the wigwam and net the brassicas" gives one job with both in its title.
- A done job cannot be turned into a journal entry.

## 14 November 2026, 17:12: on a Mac, a month's page follows two fingers as it turns

**On the branch `month-drag-mac`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`mv7-mac.log`, `mv7-sim.log`, in `DerivedData/Windfall-month`). 596 logic tests pass. **A simulator has no trackpad, so the Mac's row was given to a 13-inch iPad with a checking aid and looked at there**, with the example garden: the row held 300 points to the right shows April sliding off and March coming in beside it, cut off cleanly at the sidebar (`shots/mv7-drag.png`); the forward arrow slides December on to January and the back arrow April back to March (`mv7-on.png`, `mv7-back.png`). **Not tried by anyone: two fingers on a real trackpad.**

**Why.** William, 16:49: "Currently the month swipe works on the iphone exactly as I want it. So that when you're touching the screen you can see the swiping happening like you're dragging something. This is how I want it to work with two finger swipe on the mac."

**Before, on a Mac.** Two fingers swiped sideways did nothing you could see until they had gone 60 points. Then the month turned by itself.

**Now.** The page moves with the fingers from the start, and the month before or after comes into view beside it. Lift the fingers after 60 points or more and the row slides on to that month. Lift sooner and it settles back. The arrows by the month's name slide the same way. **The iPhone and iPad are not changed.**

**Why the Mac needs its own way.** On an iPhone the months are a row that scrolls sideways, and the system moves it under the finger. On a Mac a sideways scroll goes to whatever is under the pointer, which is a page that only scrolls up and down, so the row never heard it. That is why the first version read the trackpad itself and jumped. This version still reads the trackpad itself, and now moves the row with it.

**How it is built** (`YearMonthView.swift`).

*Three pages in a row.* On a Mac the page draws the month showing with its two neighbours, and shows only the middle one:

```swift
let threePages = [pageNow - 1, pageNow, pageNow + 1]

MonthRowSlide(monthDrag: monthDrag) {
    HStack(alignment: .top, spacing: 0) {
        ForEach(threePages, id: \.self) { page in
            monthPage(YearCalendar.month(atPage: page), from: chosenFrom, isWide: isWide)
                .frame(width: space.width, height: space.height)
        }
    }
}
.frame(width: space.width, height: space.height)
.clipped()
```

- `HStack` lays the three pages side by side. Each is made exactly one page wide.
- The `.frame` after it is one page wide and holds the row by its middle, so the middle page fills it. `.clipped()` hides what falls outside: the pages either side.
- `MonthRowSlide` draws the row somewhere else: `monthRow.offset(x: monthDrag.across)`. `offset` moves where a view is drawn without moving anything around it. As `across` grows, the row slides right and the month before comes into view.

*The number that moves it.* `MonthDrag` is a small class marked `@Observable`, holding `across`: how far the row has been dragged. Only a view that reads `across` is redrawn when it changes, and only `MonthRowSlide` reads it. So a drag, which changes it about a hundred times a second, redraws the row's place and none of the cards.

*The trackpad.* `MonthSwipes` already listened to the Mac's scrolling. It used to count up to 60 points and then say "turn". It now reports the distance all the way along (`whenDragged`), and which way to turn when the fingers lift (`whenLifted`).

*Finishing the turn.*

```swift
withAnimation(.smooth(duration: 0.3)) {
    monthDrag.across = landing
} completion: {
    shownPage = target
    monthDrag.across = 0
}
```

- `withAnimation` glides `across` to `landing`, which is one page's width to the left or right, so the neighbour ends up filling the page.
- `completion` is run when the glide has finished. In one go, with no animation, the neighbour becomes the month showing and the row goes back to rest. The two cancel out, so nothing is seen to move. The row is then ready for the next swipe, with new neighbours.

**Changed besides.** While the fingers are moving sideways, the scroll is used up by the row, so the page under the pointer does not creep up or down as well. The glide the Mac sends after the fingers lift is used up too.

**Checking aids**, because a simulator has no trackpad: `-demoMonthMacRow YES` gives an iPad the Mac's row of three pages, and with it `-demoMonthDrag 300` holds the row 300 points to the right, as if part-way through a swipe.

**Choices that are Claude's.** ⚠️ CHECK each.

- Lifting after 60 points turns the month, however quick or slow the swipe. An iPhone also goes by how fast the finger was moving. This does not.
- One swipe turns one month at most.

## 14 November 2026, 17:36: the app has its icon, on an iPhone and an iPad

**On the branch `app-icon`, made from `main` (`0c4857f`).** No Swift code changed, so the logic tests were not run again. **This entry sits below the 17:12 one, out of time order, on purpose**: every open branch adds its entry at the top of this file, and an entry added there too would clash with each of them when they are joined.

**Why.** William, 16:16, of the snowdrop with a bumblebee: "Perfect. That's the app icon. You can save that to the project file and use it as the icon going forward." At 17:32: "Make sure when you push the next update, it has the app icon". Until now the app had no icon at all: the place for one was there and was empty, so an iPhone showed Apple's blank grid.

**What was added.**

| File | What it is |
|---|---|
| `Design/AppIcon/windfall-app-icon-light.svg` and `-dark.svg` | The two drawings William approved, copied from the project (doc 47). The masters |
| `Windfall/Assets.xcassets/AppIcon.appiconset/windfall-app-icon-light-1024.png` and `-dark-1024.png` | The same two drawings as pictures 1024 dots square, with no see-through parts. These are what the app is built with |
| `Windfall/Assets.xcassets/AppIcon.appiconset/Contents.json` | Two lines added, naming the pictures |
| `Design/README.md` | A section on the app icon and how to make the pictures again |

**What the code means.** `Assets.xcassets` is the app's store of pictures and colours. Inside it, `AppIcon.appiconset` is a folder that holds the icon, and its `Contents.json` is a list of slots. Each slot says what kind of picture it wants, and `filename` says which file in the folder fills it:

```json
{
  "filename" : "windfall-app-icon-light-1024.png",
  "idiom" : "universal",
  "platform" : "ios",
  "size" : "1024x1024"
},
{
  "appearances" : [
    { "appearance" : "luminosity", "value" : "dark" }
  ],
  "filename" : "windfall-app-icon-dark-1024.png",
  "idiom" : "universal",
  "platform" : "ios",
  "size" : "1024x1024"
}
```

- `"idiom" : "universal"` and `"platform" : "ios"` mean one picture for every iPhone and iPad. Xcode makes each smaller size from it when it builds.
- A slot with no `appearances` is the ordinary icon. It gets the cream picture.
- `"value" : "dark"` is the slot iOS uses when the Home Screen's icons are set to Dark. It gets the dark green picture.
- The only change is the two `filename` lines. Before, the slots had no `filename`, which is what "empty" means here.
- The project already names this folder as the app's icon (`ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` in the project file), so nothing else had to change.

**Why the drawings are not in `Design/Icons`.** Project doc 47 suggested that folder. `Tools/design/build_design_assets.py` turns every SVG in it into a small icon for use inside the app, and would have done the same to these two. They are in a folder of their own, `Design/AppIcon`.

**Checked.** The two drawings were typed out from the project's copies. Every shape in the light drawing was compared by a script with the same shape in the dark one, and all 16 match, which is the check that nothing was mistyped. Both pictures were looked at by Claude at full size and at Home Screen size. Each is 1024 by 1024 with no see-through layer.

**Not done.**

1. **The third slot, `tinted`, is still empty.** That is the icon in one colour, for a Home Screen set to Tinted. **⚠️ CHECK**, Claude's understanding: with the slot empty, iOS makes a tinted icon itself from the ordinary one. Not seen.
2. **The Mac has no icon yet.** The list has slots for iPhone and iPad only. A Mac icon is drawn differently, with rounded corners and a margin, so it needs its own picture and William's eye.
3. The icon's dark green (`#06421B`) is still not the interface's (doc 47).

## 14 November 2026, 17:50: the weather is fetched by itself

**On the branch `weather-by-itself`, made from `main` at `fb7ce30`, with `main` merged in at `71d95d4` (18:50).** The logic tests pass, 15 of them new, and 14 more for the widgets' sums were run outside the usual checks. **See the knowledge base, doc 61, for whether it has been built and what has been seen.** This entry sits below the 17:36 entry, out of time order, so that it does not clash with entries the open branches add at the top.

**Why.** William, 17:35: "The weather isn't being automatically retrieved." He was looking at a widget or the drawing in Today's corner, on the iPhone and the Mac. Asked how a device with no garden on the map should find out where it is, he chose: "Ask once on opening".

**What was wrong.** Three things, all in how the weather was asked for.

1. *Only the Today page asked.* It fetched the conditions once, in the `.task` that runs when the page is drawn. The widgets and the corner drawing do not fetch anything. They read what Today fetched. So a window left open, or an app brought back from the background, went on showing the weather from when it was opened.
2. *With no garden on the map, nothing asked at all.* A new copy of the app (the iPhone's, or a signed copy on the Mac, each with its own empty database) makes its two gardens with no place. The code only used the device's own position after "Check now" had been tapped, so no reading was ever taken and the widgets' file never had a forecast in it.
3. *The first tap on "Check now" did nothing.* `LocationManager.currentLocation()` asked Apple's location question and returned nothing straight away, without waiting for the answer.

**Now.**

- The app fetches the weather itself: when it opens, each time it comes back to the front, every quarter of an hour while it is open, and the moment a garden is given a place or moved.
- With no garden on the map it uses where the device is. The first time, Apple's location question appears as the app opens. It is asked once. After a No the card on Today says what to do instead.
- When the weather shown is for where the device is, Today's card says so and offers "I am in my garden", which saves that spot as a garden's place. That is what starts the garden's weather diary.
- A widget fetches the forecast for itself when the one it holds is more than three hours old, so "Frost and weather" keeps up without the app being opened.

**How it is built.**

*One place that asks* (`WeatherNow.swift`, new). `WeatherNow.refresh` finds where to ask about, fetches, and then brings the widgets' file up to date:

```swift
await WeatherService.shared.refresh(
    gardenAt: WeatherPlace.garden(among: gardens),
    deviceLocation: { await locationManager.currentLocation(mayAsk: mayAskHere)?.coordinate },
    force: force)
WidgetShare.refresh(context: context)
```

- `gardenAt` is the first garden in use that has a latitude and longitude, or nil.
- `deviceLocation` is a closure: a piece of code handed over to be run later, and only if it is needed. `refresh` runs it only when `gardenAt` is nil, so the GPS is never woken when a garden is on the map.
- `mayAskHere` is false for the example garden, so a test run with nobody watching is never left waiting on a question.

*When it is called* (`MainTabView.swift`). Four moments, each one modifier on the app's main view:

```swift
.task { ... await WeatherNow.refresh(..., mayAsk: true) ... }      // on opening
.onChange(of: scenePhase) { ... if phase == .active { ... } }      // back to the front
.task { while !Task.isCancelled { try? await Task.sleep(for: WeatherNow.lookEvery) ... } }   // every 15 minutes
.onChange(of: gardenPlaces) { ... }                                // a garden placed or moved
```

- `.task` starts a piece of work when a view appears and stops it when the view goes. The third one is a loop that sleeps for a quarter of an hour and looks again. `Task.sleep` waits without using the processor.
- `scenePhase` is SwiftUI's word for whether the app is at the front (`.active`), behind something (`.inactive`) or put away (`.background`).
- `gardenPlaces` is a line of text made from every garden's place (`WeatherPlace.fingerprint`). `onChange` runs its code whenever that text changes. A `@Query` of the gardens keeps it live.

*The sums, where they can be tested* (`WeatherService.swift`). `refresh` and the new `WeatherPlace` hold every decision: which place, whether a reading is still fresh, whether two spots are near enough to share one. A reading is now kept for a quarter of an hour *for its place*. Before, a reading taken anywhere was reused for anywhere, so a garden given its place just after a reading from the device would have gone on showing the old one. `WeatherService` also waits if a fetch is already under way, and its fetching is a value that the tests swap for a canned reply (`download`).

*Waiting for the answer* (`LocationManager.swift`).

```swift
if authorisationStatus == .notDetermined {
    guard mayAsk else { return nil }
    requestPermission()
    await waitForAnswer()
}
guard isAuthorised else { return nil }
```

`waitForAnswer` parks the code with `withCheckedContinuation`, which hands back a `continuation`: a ticket for carrying on later. The ticket is kept in a list. When CoreLocation reports that the question has been answered (`locationManagerDidChangeAuthorization`), every ticket in the list is used, and the code carries on from where it stopped. This also mends "Use where I am now" in the garden editor and the grid reference button, which had the same wasted first tap.

*Today* (`TodayView.swift`). The page no longer fetches when it is drawn. It reads the shared service, as before. `weatherPlace`, used to tell day from night, is now read from the service. "Check now" calls `WeatherNow.refresh` with `force: true`. The new menu, `savePlaceMenu`, shows when `weather.isFromDevice` is true and no garden has a place.

*The widgets* (`WindfallShared/WidgetForecast.swift`, new, and `WindfallWidgets.swift`). The summary file gains two optional fields: `place` (rounded to three decimal places, the same as is sent to the service) and `forecastFetched`. They are optional so that a file written before today still reads. A widget's `timeline` now begins with:

```swift
let summary = await WidgetForecast.refreshIfDue()
```

which reads the file, and if the forecast is more than three hours old fetches a new one, puts only the forecast into the file and leaves the rest as found. The timeline then asks to be looked at again three hours after the forecast was fetched (`.after(nextLook)`), where before it waited until its last card had been shown (`.atEnd`), seven days on. The app, for its part, keeps whichever forecast is newer, its own or a widget's (`WidgetShare.refresh`).

*One build setting* (`Windfall.xcodeproj`). `ENABLE_OUTGOING_NETWORK_CONNECTIONS = YES` for the widget program. On a Mac a widget is fenced in (sandboxed) and may not reach the internet without it. It makes no difference on an iPhone or iPad.

**What a widget still cannot do.** It never finds the device's location itself, and it does not work out the frost and wind jobs on "This week", which need the records. Those jobs are still written by the app, for eight days ahead. So Windfall must have been opened once, with the weather fetched, before a widget can keep itself up to date.

**Sent to the weather service.** Nothing new in kind: a place rounded to about a hundred metres, as Settings says. It is now also sent by the widget program, a few times a day, and for a device with no garden placed the place is where the device is.

**Claude's choices, for William to confirm.** Every quarter of an hour while open. Three hours for a widget's forecast, and an hour before trying again after a failure. A kilometre as "the same spot". The words on Today's card and on the button. That the offer takes the place of "Start count" on the card until a garden is placed. That a place saved from the card goes to whichever garden is chosen from the menu, with no confirmation.

## 14 November 2026, 16:50: a conversation grows out of Eira's bar

**On the branch `eira-bar-expand`, made from `main` (`c89c037`), with `main` (`0ba7173`) merged in.** Built for the Mac and the iOS Simulator with no errors (`eb4-mac.log`, `eb4-sim.log`, in `DerivedData/Windfall-eirabar`). 598 logic tests pass, 2 of them new. Seen as still pictures with the example garden on an 11-inch iPad Pro: the journal's conversation and Eira's chat each standing in the panel, in light and dark, and the bar at rest on Today and on Journal (`shots/eb2-*` and `eb3-*`). **Not seen: an iPhone, and the Mac's own window.** The Mac was too busy with other chats' builds for a second simulator to start. **Nothing has been pressed by hand, and Claude cannot see the panel move.** William judges the growing and the sinking back.

**Why.** William, 15:45, with a picture of the Journal page on the Mac: the journal's conversation open as a sheet in the middle of the window, with its own box to type in, and Eira's bar with a second box idle underneath. "Can we make it so that chat expands from the Eira bar, rather than opening up a new window?" His picture is in `Design/Reference`, `2026-11-14 screenshot-journal-sheet-over-eira-bar-mac.png`.

### 1. What you see

On a Mac and an iPad:

- Send something from Eira's bar, press its microphone or book button, or give it a photo on the Journal page. The bar itself grows upwards into a panel of glass, and the conversation is inside it. The box to type in runs along the panel's foot, exactly where the bar was, so the bar seems to become the box.
- The page behind is not dimmed and still works. You can scroll it, or go to another page, with the panel still up.
- **Done**, or the Esc key, sinks the panel back into the bar.
- The button with two arrows makes the panel larger: the bar's whole width and the page's whole height. The app remembers which size you left it at.
- On a Mac the keyboard goes straight to the panel's box, so typing carries on. Afterwards it goes back to the bar.
- Photos dropped on the Journal page now open in the panel too. That page used to bring up a sheet of its own.

Both conversations use it: the journal's, and Eira's own chat. "It was a question. Ask Eira instead" now swaps what is in the panel at once. As a sheet it had to close one window, wait and open another.

**Not changed:** an iPhone still slides a sheet up, which on a screen that size is nearly the same thing. Search, the card that asks what to do with a photo away from the Journal page, and the Note button on Today are still sheets everywhere.

### 2. How the panel grows (`EiraFloatingBar.swift`)

A sheet is a separate window that SwiftUI puts on top of everything. The panel is not. It is an ordinary view drawn in the same place as the bar, whose height is changed with an animation:

```swift
.frame(height: panelIsUp ? EiraPanel.height(room: room, isLarge: panelIsLarge) : closedSize,
       alignment: .bottom)
.clipShape(.rect(cornerRadius: corner))
.glassEffect(.regular.tint(Theme.paper.opacity(0.8)), in: .rect(cornerRadius: corner))
.onAppear(perform: raisePanel)
```

- `panelIsUp` is a true-or-false value the bar keeps (`@State`). The line reads: "if the panel is up, be as tall as the sum says. If not, be as tall as the bar."
- The panel is first drawn with `panelIsUp` false, so it starts the size and shape of the bar. `.onAppear` runs `raisePanel` the moment it is on screen, and that sets `panelIsUp` to true inside `withAnimation`. SwiftUI then draws every size in between, which is the growing.
- `alignment: .bottom` keeps the foot of the conversation on the bar's line while the rest is uncovered above it.
- `corner` goes from half the bar's height (a capsule) to 28 points, so the round ends of the bar ease into the panel's corners.
- `.clipShape` stops anything being drawn outside that shape while it is small. `.glassEffect` is the same glass the bar is made of, tinted with the paper's colour so the writing stays easy to read over a busy page.
- **Done** runs `lowerPanel`, which sets `panelIsUp` back to false with an animation. Only when that has finished (`completion:`) is the conversation let go.

Which conversation is in the panel is worked out from two values the bar already had, `journalRequest` and `eiraRequest`. They used to open sheets. `sheetOnly(...)` now hands the two `.sheet` lines a value that is always empty wherever the bar grows in place, so no sheet appears, and `openInPanel` reads the same two values to decide what to draw.

### 3. Where the bar lives (`MainTabView.swift`)

The bar used to sit inside a strip at the foot of the page (`safeAreaInset`). A strip 60 points tall has no room for a panel, and a view hung outside its own space may not take taps. So:

- The strip is still kept clear, with nothing in it (`Color.clear`), so a long list can still be scrolled out from under the bar.
- The bar is now in an **overlay**: a layer on top of the page, given the page's whole space. It sits at the foot of that space and grows into the rest of it. The empty part of the layer takes no taps, so the page underneath works as before.

`EiraFloatingBar(growsInPlace: true)` is how the Mac and iPad layout asks for the panel. The iPhone layout does not ask, and is as it was.

### 4. The parts they share (`EiraPanel.swift`, new)

- `EiraPanelControls`: what a conversation is handed when it is in the panel. It holds the larger-size switch, whether to take the keyboard, and the function that closes the panel.
- `EiraPanel`: the sizes in one place. The panel is at most 760 points wide and 620 tall unless made larger, and never taller than the page.
- `PanelPage`: the heading a conversation wears in the panel. It does for the panel what `SheetPage` does for a sheet: title, the line under it, the larger-size button and Done.

### 5. The two conversations (`JournalChatView.swift`, `EiraChatView.swift`)

Each takes an optional `panel:`. Given one, it wears `PanelPage`. Given none, it is a sheet or a page exactly as before, so Today's Note button, the iPhone and every other way in are untouched.

- In the journal's conversation the box to write in loses its own card of glass when it is in the panel, because glass laid on glass turns murky. A fine line above it takes the card's place.
- Eira's chat has no bar along the top in the panel, so its Options menu moved into the heading as a button with three dots. The four things in the menu are now written once (`optionsItems`) and used in both places.
- Eira's chat hugs the foot of the panel (`.defaultScrollAnchor(.bottom)`), so it stays put while the panel grows.
- Each box has a `@FocusState`, which is how a view asks for the keyboard.

### 6. Photos dropped on the Journal page (`EiraScreen.swift`, `JournalViews.swift`)

The Journal page and the bar are separate views, so the page cannot open the bar's panel directly. Both already share `EiraScreen`, the tracker that tells Eira what is on screen. It gained a small pigeonhole: the page puts dropped photos in it (`handToBar`), and the bar, which watches it, takes them out (`takePhotosForBar`) and opens the panel. They are handed over once and then gone, so the same photos cannot start two entries. Two new logic tests cover that.

### Checking aid

`-demoOpen bar-journal` opens the journal's conversation from Eira's bar as soon as the bar appears, as `-demoOpen eira` does for her chat. With `-startSection journal` it gives the picture William sent, in its new form.

### ⚠️ CHECK: choices that are Claude's

1. The panel is glass tinted with the paper's colour at 80%. The page shows through faintly.
2. It is at most 760 points wide and 620 tall, on the left above where the snowdrop sits, with a larger size on the button.
3. The page behind stays live and is not dimmed. Clicking on the page does not close the panel. Only Done and Esc do.
4. The panel stays up when you go to another page.
5. An iPhone keeps its sheets.
6. Search and the photo card are still sheets.

### Not built

- The box in the panel is the conversation's own, not the bar's. They sit in the same place, so it reads as one, but the snowdrop and the bar's search and book buttons are not in the panel.
- Today's Note button and the Journal offer on Today still open the journal's conversation as a sheet.
- Dragging the panel's top edge to resize it.
- The panel does not shrink to fit a short conversation.

## 14 November 2026, 16:45: Eira's bar can be put away by touch on an iPhone, and the carrot-family warning knows 19 more genera

**On the branch `iphone-first-fixes`, made from `main` (`db45898`).** Built and signed for William's iPhone 16 with no errors (`iphone-5.log`, in `DerivedData/Windfall-iphone`) and installed on it at 16:44. Every file reads as valid Swift. **The full logic tests were not run**: they need Linux with Swift, and one test was added. **Nothing here has been tried by hand.** The two touch gestures can only be judged on the phone.

### 1. Putting Eira's bar away (`EiraFloatingBar.swift`)

**Why.** William, 16:04, on first trying the app on his iPhone: once the bar is open "you can't tap out of the chat or swipe the chat down to get rid of it. Tapping the eira icon removes it though." On a Mac the Escape key closes the bar. An iPhone has no Escape key, so the snowdrop was the only way.

**What changed, on an iPhone or iPad only:**

- **A touch on the page closes the bar.** `touchAwayLayer` is an invisible layer that exists only while the bar is open. `Color.clear` draws nothing, and `contentShape(Rectangle())` makes that nothing count as somewhere a finger can land. It is 4,000 points square and lined up with the bottom of the bar, so it reaches up over the whole page. It sits behind the bar (`.background`), so the bar's own buttons get their taps first. A tap on it, or the start of a scroll, calls `close`.
- **The first touch only closes the bar.** It is not passed on to the page, so nothing is opened by accident.
- **A swipe down on the bar closes it.** `swipeDownPutsAway` watches for a drag with `simultaneousGesture`, which notices the drag without taking touches away from the text box and buttons. It counts when the finger went at least 30 points down, and further down than sideways.
- `canBePutAway` is true only when the bar was opened by hand. It is false when the bar is pinned open and on the Journal page, where the bar is always open, so neither of those is changed.

**A Mac is left alone**, with `#if os(iOS)`. A click that did nothing but close the bar would be a nuisance there, and a downward drag across a text box is how text is selected.

**Joined to the panel, 17:15.** `main` gained "a conversation grows out of Eira's bar" (the entry above) while this was on its branch, and both had changed the same lines. The bar's new shape is `main`'s. The swipe and the touch layer were put back on the bar inside it, and `canBePutAway` now also stands down while a conversation is in the panel, because the page behind the panel is meant to go on working. William had tried the version before this join on his iPhone at 16:57 ("It seems to work"). The joined version was built and put on the phone afterwards.

**To check on the phone:** that a tap above the open bar closes it, that a swipe down on the bar closes it, that the bar's own buttons still work, and that the page scrolls normally once the bar is closed.

### 2. The carrot-family warning (`SpeciesTable.swift`)

**Why.** The image model's list on the phone was widened the same afternoon from 778 names to 6,421 (project doc 50). The warning works from `carrotFamilyGenera`, a list of 31 genera. iNaturalist has confirmed UK records for carrot-family plants in 50 genera. Without the other 19, a hemlock look-alike could have been named as one of them with no warning.

**What changed.** The 19 are added: Astrantia, Beruladium, Bunium, Bupleurum, Eryngium, Falcaria, Ferula, Libanotis, Ligusticum, Meum, Orlaya, Peucedanum, Physospermum, Sanicula, Selinum, Tordylium, Trinia, Trocdaris and Visnaga. Some look nothing like hemlock (sea holly, great masterwort) and get the warning all the same: it is better given too often than too seldom. **CHECK: the genera and their common names are iNaturalist's, fetched on 14 November 2026, and have not been checked against a flora.**

One logic test added: the list holds five of the new genera and 50 in all.
## 14 November 2026, 16:55: the drawing in Today's corner comes alive

**On the branch `living-corner`, made from `main` (`0ba7173`).** Knowledge base doc 49 has the design and William's decisions. The design was worked out first on a canvas ("Windfall living corner" in William's artifacts), and the drawing code there is the project file `design/living-corner.js`. This is that design carried into Swift.

**Why.** William, 16:02, of the fixed drawing: "it was going to be a live animation linked to the month or season." 16:10: "I wonder if we play on the bee from the app icon." 16:30: "I don't want this to be a thing that people have to set up, just a fun thing that happens." 16:38: "add it in to the next build of the app (add an option in settings for me to see all the different animations and change the weather as an in settings preview)".

**What it does.** A drawing for each month. It grows in when Today opens, sways as hard as the wind is blowing, and changes a little every day. The bee from the app icon flies in from the left, feeds from flower to flower and leaves to the right, then comes back after a random wait of 10 to 20 seconds. Tapping the drawing calls the bee and pushes the sprig, which springs back. In February it is the icon's own snowdrop.

### The four new files

| File | What is in it |
|---|---|
| `CornerScene.swift` | The deciding: which month, how far through it, calm or breezy or gusty, fine or rain or frost or night, and whether the bee may fly. No drawing, so it is tested (13 new tests) |
| `CornerSprigs.swift` | The twelve drawings, the shapes they are built from, the colours and the bee |
| `CornerIconArt.swift` | The app icon's snowdrop as outlines, for February |
| `LivingCorner.swift` | The engine that moves it all, the view, and the preview page for Settings |

### How a drawing is put together

Each drawing is **stems** and **parts**. A stem is a curved line. A part is a leaf, flower or fruit fixed part way along a stem. Here is September's bough and one of its pears:

```swift
let a = twig.stem(at(6, 90), at(38, 30), at(126, 27), width: 1.7)
twig.add(a, 0.62, .pear(tall: CornerMath.lerp(21, 27, t), ripe: t)) { $0.hangs = true; $0.fan = -3; $0.swing = 0.55 }
```

- `twig.stem(...)` adds a line from 6, 90 (bottom left) that bends towards 38, 30 and ends at 126, 27. It gives back a number, kept in `a`, that stands for this stem.
- `twig.add(a, 0.62, ...)` fixes a part to stem `a`, 62% of the way along it.
- `.pear(tall:ripe:)` says the part is a pear. `t` is how far through the month it is, from 0 to 1. `CornerMath.lerp(21, 27, t)` is a number that slides from 21 to 27 as `t` goes from 0 to 1, so the pear is 21 tall on the 1st and 27 on the 30th.
- The piece in curly brackets sets what is unusual about this part. `$0` means "the part being added". It hangs straight down and swings like a weight.

Because parts are fixed to stems by "how far along", they follow when the wind bends the stem. Nothing has to be moved by hand.

### How it moves

`LivingCorner` wraps its drawing in a `TimelineView`, which asks for the picture again up to thirty times a second, handing over the time. Every frame the engine works everything out afresh from that time:

- **Growing in**: how many seconds since Today opened decides how much of each stem is drawn and how big each part is.
- **Swaying**: three slow sine waves of different lengths added together give a lean in degrees. A wave that never quite repeats looks like wind. Points further from the foot of the plant turn more, which makes it bend like a stem.
- **A tap** adds one more wave that dies away: `nudgeSize * exp(-1.7 * sinceTap) * sin(7.2 * sinceTap)`. `sin` swings back and forth and `exp` of a growing minus number shrinks towards nothing, so the swing gets smaller each time.

It stops redrawing when the app is in the background. With Reduce Motion on it draws once, finished and still, with the bee sitting on the flower.

### Nothing to set up

In `TodayView.swift` the old `BotanicalCorner()` becomes `LivingCorner(cornerScene: cornerScene)`, and `cornerScene` is made from things Today already had:

```swift
CornerScene.make(date: .now, calendar: .current,
                 temperatureC: weather.current?.temperatureC,
                 precipitationMM: weather.current?.precipitationMM,
                 windSpeedKMH: weather.current?.windSpeedKMH,
                 isNight: isNight)
```

- `weather.current` is the last reading from the weather service, or nothing if there has not been one. The `?` means "if there is one".
- `isNight` was already there, worked out from the sun's position for the garden.
- With no reading at all the corner shows a light breeze on a fine day.

The limits, all in `CornerScene.swift` and all Claude's choices for William to check: calm under 8 km/h, gusty over 20 (the app's own "too windy" line), rain from 0.1 mm, frost at 0°C or below, and the bee needs 5°C.

### The preview in Settings

The page the sidebar's Settings opens ("Settings and tools", `MoreTab` in `MainTabView.swift`) has a new row, "Corner drawing". It opens `CornerPreviewView`: one large drawing with a month menu, a day slider, wind and weather switches and "Open it again", then all twelve months moving in a grid. Tapping a month in the grid shows it large. Nothing chosen there changes Today. Things happen sooner there than on Today so there is something to watch.

### Smaller things

- The colours are kept inside `CornerSprigs.swift` as `CornerInks`, a light set and a dark set, and not in `Design/colours.json`. Two reasons: a fruit ripening is one colour mixed into another, which needs the numbers, and the new colours are still a proposal (doc 49). Six of them repeat values from `colours.json`. If those change there, change them here too.
- `BotanicalCorner` is still in `Theme.swift` and is no longer used.
- The crocus and runner bean drawn before William chose daffodil and lavender are not carried across. They are in `design/living-corner.js`.
- Checking aids: `-cornerMonth 2 -cornerDay 20 -cornerWind gusty -cornerSky rain` set the scene on Today and in the preview. `-startSection more -demoCorner YES` opens the preview.
- Names: the cross-file check goes by names, so several here are longer than they need be (`sprigPart`, `cornerSky`, `lineInk`).

## 14 November 2026, 16:26: the sidebar's lens follows the fingers again

**On the branch `sidebar-scroll-follows-fingers`, made from `main`.** One line in `MainTabView.swift`, in `lensScrolled(by:)`.

**Why.** William, 16:22, with a picture of the sidebar: "Can you return the scrolling of this bar to the previous way it was, it's not working as is right now." The sidebar's scrolling has been changed once since it was written: at 22:31 on 13 November the lens was made to move as a list scrolls (fingers pushed up went down the list). This puts back the way before that: two fingers moving down carry the lens down, like a drag.

```swift
let fingers = scroll.isDirectionInvertedFromDevice ? scroll.scrollingDeltaY : -scroll.scrollingDeltaY
```

- `scroll.scrollingDeltaY` is how far the Mac says this piece of the scroll went, up or down.
- `isDirectionInvertedFromDevice` is true when "natural scrolling" is on in System Settings. It is on for William's Mac (the setting has never been changed from Apple's default).
- `a ? b : c` reads "if a, then b, otherwise c". With natural scrolling on the number is used as it is. With it off the Mac reports the opposite sign, so the minus turns it back. Either way fingers down means lens down.
- A mouse wheel goes through the same line, so its direction is turned too.

Nothing else about the sidebar is changed: the gearing (0.6), settling on the nearest row and one row for each click of a wheel are as they were.

**Not tried by hand.** A script cannot make a two-finger scroll.

## 14 November 2026, 16:27: a page grows out of the tile that was tapped

**On the branch `tile-grow`. Built for William's iPhone (signed, `tg1-iphone.log`, 16:48) and for the Mac (`tg3-mac.log`, 17:11) with no errors, at the first attempt.** 596 logic tests pass. Written from William's iPhone without the Mac, then built once he moved the chat to the Mac. **On his iPhone since 17:08**, mixed with the iPhone chat's `iphone-first-fixes` at his word (the branch `tile-grow-phone-mix`, for the phone only). **Nobody has yet said what it looks like moving: it waits on William before it goes into `main`.** His recording is `Design/Reference/2026-11-14 recording-iphone-gardens-tiles-slide-in.mp4`.

**Why.** William, 16:21, with a recording of the Gardens page on his iPhone (tapping "Garden map", swiping back, tapping "Weather"): "I'd like these tiles and any time you tap a tile like this that leads to more information for it to grow from the tile. Still swipe back though as previously agreed."

**What you should see, on an iPhone or iPad.** Tap a tile and its page grows out of that tile to fill the screen. Go back with the back button or a swipe from the left edge and the page shrinks back into the tile.

**Where.**

| Tapped | Opens |
|---|---|
| The nine tiles on Gardens | Plants, Year, Sowings, Beds, Garden map, Seed, Crosses, Scan a seed packet, Weather |
| The four tiles on Wildlife | Sightings, Surveys, Species, Identify from a photo |
| A plant's card on Plants | That plant's page |
| A sighting's card on Sightings | That sighting |
| A cross's card on Crosses | That cross |

Rows in a list and the small "View all" links still slide in from the right. That was Claude's choice of where to stop.

**How (`GrowFromTile.swift`, new).** Apple calls this a "zoom" transition. It needs two lines that point at each other:

```swift
tile.matchedTransitionSource(id: "tile", in: space)             // on the thing tapped
page.navigationTransition(.zoom(sourceID: "tile", in: space))   // on the page it opens
```

- `matchedTransitionSource` marks a view as the place a page grows from.
- `navigationTransition(.zoom(...))` tells a page to grow from the view with the same `id`, in place of sliding in.
- `space` is a `Namespace`: a private box of names. The same `id` in two boxes is two different things. Each tile makes its own box with `@Namespace`, so every tile can use the name "tile".

The file wraps those two lines as `growSource` and `growsFrom`, and adds `GrowingLink`, which is a `NavigationLink` that does both for you. So a tile changed from this:

```swift
NavigationLink { WeatherDiaryView() } label: { HubTile(...) }
```

to this:

```swift
GrowingLink { WeatherDiaryView() } label: { HubTile(...) }
```

Plants and Sightings open their pages a different way (the card hands over a record and the page is named once, in `navigationDestination`), so there the two halves are written out, with the record's own `id` as the name.

**A Mac is unchanged.** Both halves are fenced with `#if os(iOS)`. The Mac keeps its slide and its two-finger back swipe.

**To put the old slide back without a rebuild:** start the app with `-tilesSlide YES`.

**To watch for on the phone.**

1. **A tile that vanishes after a swipe back.** Other developers report this as a fault in iOS 26 itself with this transition: after swiping back, the thing that was tapped is not drawn again, though it still works if tapped (Apple's developer forums, threads 796805, 802908 and 807715, reported up to iOS 26.4). The back button does not cause it. Not known: whether William's iPhone has it. If it does, the choices are a known workaround that makes the tile flash, or going back to the slide.
2. **The swipe back looks different.** The page shrinks towards its tile as it follows the finger. It does not slide off to the right as it did. Apple also lets a page opened this way be pulled down from its top to go back. Neither can be switched off separately.
3. **The glass.** A plant's card is glass and is itself the source. A tile's glass is behind the source. Either may look wrong for a moment as the page grows.
4. A plant's page reached some other way from inside Plants would grow from the middle of the screen, there being no card to grow from.
## 14 November 2026, 16:25: the sighting form's plant list has a row of letters to jump by

**On the branch `plant-letter-jump`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`pl1-mac.log`, `pl1-sim.log`, in `DerivedData/Windfall-plantjump`). 596 logic tests pass, 6 of them new. Seen as still pictures with the example garden: the list open and jumped to M on an iPhone 17 (light) and an 11-inch iPad Air, and jumped to S on the iPhone in dark (`shots/pl1-*`). **Not tried by hand: pressing a letter, choosing a plant, and the Mac's own window.** The pictures were made with the checking aid below, which jumps the same way a press on a letter does but without the glide.

**Why.** William, 15:50, with a picture of the sighting form's "Which plant" menu open: "could you make it so that you can select letters of the alphabet for the first letter so that you can jump to those plants first." The menu held every plant in the library, 376 of them, in one list that always opened at the top.

### 1. What you see

"Which plant" on the sighting form is still a box showing the chosen plant. Pressing it now opens a panel in place of the menu:

- **A row of letters**, A to Z. Press one and the list glides to the plants that begin with it. A letter with no plants (Q and X in the library today) is greyed out and cannot be pressed.
- **The list**, with "None" first and then a small heading for each letter. The chosen plant has a tick and a green band. Press a plant and the panel closes with it chosen.
- It opens at the letter of the plant already chosen, so the tick is in view.
- On an iPad or a Mac the panel is a popover pointing at the box. On an iPhone it slides up as a sheet.

**The order has changed a little.** The menu was in the order of the plants' names alone, so varieties of one plant came in no order (Apple: Spartan, Pigs Snout, Pendragon). The list is in order of name and then variety, so they now run Jonagold, Pendragon, Pigs Nose III, Pigs Snout.

### 2. The workings (`PlantFilter.swift`)

A new piece, `PlantLetters`, with nothing in it that draws, so it can be tested without a screen.

```swift
static func letter(for name: String) -> String {
    guard let first = name.first(where: { $0.isLetter || $0.isNumber }) else { return other }
    let plain = key(String(first)).uppercased()
    return alphabet.contains(plain) ? plain : other
}
```

- `name.first(where:)` finds the first character that is a letter or a number, skipping anything in front, such as a quotation mark.
- `guard ... else { return other }` is the way out when there is none: the name goes under "#".
- `key(...)` drops an accent and `uppercased()` makes a capital, so "é" becomes "E".
- The last line asks whether that is one of A to Z. A number is not, so "3 Sisters" goes under "#" too.

`PlantLetters.groups` puts the whole list in order and returns one `LetterGroup` for each letter in use, each holding its plants. It is handed two small functions, one that gives an item's name and one its variety, so the app can give it plants and the tests plain text.

### 3. The panel (`PlantChooser.swift`, new)

Two views. `PlantChooser` is the box on the form. `PlantChooserList` is the panel.

```swift
ScrollViewReader { scroller in
    ...
    Button {
        withAnimation(.smooth(duration: 0.25)) {
            scroller.scrollTo(letter, anchor: .top)
        }
    } label: { Text(letter) }
    ...
    Text(group.letter)
        .id(group.letter)
}
```

- A `ScrollViewReader` wraps a scrolling list and hands over `scroller`, which can move the list to any view inside it that has been named.
- `.id(group.letter)` is the naming: each letter's heading is named by its letter.
- `scroller.scrollTo(letter, anchor: .top)` moves the list until that heading is at its top. `withAnimation` makes it glide.
- The list is an ordinary stack, not a "lazy" one. A lazy stack builds a row only as it comes into view, and has to guess how far down an unbuilt row is, so a jump can land short. With every row built the jump is exact, and a few hundred rows of text cost little.
- The letters sit in a `LazyVGrid` with "adaptive" columns: as many 30-point letters to a line as fit, the rest on the next line.

### 4. One look for both kinds of box (`ObservationViews.swift`)

The look of the box (the words, the small arrows, the hairline) was written inside `ChoiceMenu`. It is now a view of its own, `ChoiceLabel`, which `ChoiceMenu` and `PlantChooser` both draw, so "Which plant" still matches "Life stage" and "Group" above it and cannot drift from them.

### Checking aid

`-demoOpen sighting -demoPlantLetter M` opens the sighting form, then the list of plants a moment later, already at M (`DemoGarden.jumpsToPlantLetter`). Example garden only.

### Not done, and for William to say

- **The row of letters is not a `GlassSwitch`.** The rule is that every bar of choices is one. Claude's reading: this is a row of buttons to jump by, not a choice that stays made, and 26 pieces would not fit a sliding switch. William to confirm or change.
- **No search box in the panel.** Not asked for. It would be a small addition.
- **Choosing "None" does not clear a plant's name that was filled in from "Known from your reference data" without a plant record behind it.** The old menu behaved the same way. Left alone.
- The sowing form and the other forms that pick a plant were not looked at. Only the sighting form's menu was changed.
## 14 November 2026, 16:50: widgets for the iPhone and iPad

**Added at 17:40: in `main` since about 17:38, and the widget program is now built for the Mac too.** William, 17:21: "Add them to main and then build them for mac as well, it should be for all devices". 599 logic tests pass on the joined code. What changed for the Mac: `WindfallWidgets` supports `macosx` and is fenced in (`ENABLE_APP_SANDBOX = YES`, which a Mac widget must be); the "iOS only" filters in the project are gone; the app's entitlements file is used on every platform; `WindfallGroup.folder` works on a Mac only for a copy signed with the key to the shared folder (`holdsKey`); the Lock Screen shapes are inside `#if os(iOS)`; and the example garden never writes the widgets' file. `WeekFacts.jobs(today:)` became `WeekFacts.jobs(asOf:)`. **A Mac will not show the widgets yet**: macOS takes widgets only from a signed app, and a signed Mac build failed here ("No Accounts", then "requires a provisioning profile"). Until that is sorted out, running the Mac app from Xcode itself may stop with a signing error. Unsigned builds are not affected. Where the rest of this entry says "iPhone and iPad only" or "the Mac is unchanged", this paragraph wins. The knowledge base, doc 54, has the full account.

**On the branch `widgets`, made from `main` (`c89c037`). Not in `main`.** Built for the iOS Simulator and for the Mac with no errors at the first attempt (`wg1-sim.log`, `wg1-mac.log`, in `DerivedData/Windfall-widgets`). The widget drawings were seen in the simulator on a checking page inside the app, with example content: Paper in light and dark. **Not seen: a real widget on a Home Screen or Lock Screen, a tap on one, a tick, or anything on a real iPhone.** A signed build for a real iPhone also succeeded at 17:05 (`wg1-ios.log`): William's free Apple team accepted the widget program's own identifier and the App Group, and both programs carry the key to the shared folder. It was not installed, because the iPhone was not plugged in. **The logic tests were not run** for this change: `Tools/checks` only looks inside the `Windfall` folder, and this chat had no Swift toolchain in its cloud workspace.

**Why.** William, 15:55: "Could we look at adding widget functionality into the app now". At 15:59: "Draw the options on the windfall redesign canvas first. I'd also like there to be an identify widget". At 16:15: "Build all the widgets you presented to me." The drawings are row 5 of the "Windfall redesign" canvas.

### What a widget is, and why it needs a file

A widget is a second small program that ships inside Windfall. iOS fences the two apart, so a widget cannot open the app's database. They share one folder, called an App Group. **The app writes a small summary file there and the widgets read only that.** The database is not moved and no second program ever opens it.

iOS does not run a widget all the time. It asks for a timeline, a stack of ready-made cards each with a time to show it. Windfall's widgets hand over one card for now and one for each of the next seven midnights.

### The widgets

| Widget | Sizes | What it shows |
|---|---|---|
| This week | Small, medium, large, and three Lock Screen shapes | The urgent jobs from Today's "This week". The large one has a ring by each job that ticks it off without opening the app |
| This month | Small, medium | The month's counts, as on a month's page, and its most pressing plants |
| Frost and weather | Small, medium | Tonight's lowest temperature, and the next five nights with a snowflake for a frost and a ring for close to freezing |
| Identify | Small, medium, and a Lock Screen circle | "What is this?", which opens the Identify sheet. The medium one also shows Eira's last answer |
| Last answer | Small | Eira's last answer under its photo |
| Capture | Medium | The six buttons from Today |
| Ask Eira | Small, and a Lock Screen circle | Opens her chat |

Every widget has one setting, **Look**: Paper, which follows light and dark mode, or Garden green. Press and hold a widget and choose Edit Widget.

**A plant that could hurt someone keeps its warning.** When Eira's last answer carries a danger, the warning takes the photo's place on both Identify widgets.

### New folders and files

| File | What it is |
|---|---|
| `WindfallShared/WidgetSummary.swift` | Built into both the app and the widgets. The shared folder's name, the summary file's layout, reading it for one day, the ticks, and the links a widget opens the app with |
| `WindfallShared/WidgetViews.swift` | Built into both. How each widget is drawn, as ordinary SwiftUI views, and the two looks |
| `WindfallWidgets/WindfallWidgets.swift` | The widget program: the Look setting, the tick button, the timeline and the list of widgets |
| `WindfallWidgets/Info.plist`, `WindfallWidgets.entitlements` | What tells iOS this is a widget program, and its key to the shared folder |
| `WindfallWidgets/Assets.xcassets` | The same colours and icons as the app, made by `Tools/design/build_design_assets.py`, which now writes both |
| `Windfall/WidgetShare.swift` | The app's side. `WeekFacts` gathers the week's facts for any day. `WidgetShare` writes the summary file. `WidgetRoute` follows a tap on a widget. `WidgetGallery` is the checking page |
| `Windfall/Windfall.entitlements` | The app's key to the shared folder, used on iPhone and iPad only |

### Changes to existing files

- **`TodayView.swift`.** The gathering for "This week" moved out to `WeekFacts.jobs(today:…)` in `WidgetShare.swift`, word for word apart from taking the day as a value, so a widget can ask for the days ahead and can never disagree with Today. The ticks are now kept in the shared settings (`@AppStorage("todayTickedJobs", store: WindfallGroup.defaults)`), which is the app's own settings wherever there is no shared folder. Today refreshes the widgets' file once the weather is in, and does what a widget's button asked for (`followWidget`).
- **`MainTabView.swift`.** `.onOpenURL` reads a widget's link and shows Today. The widgets' file is refreshed when the app is put away.
- **`EiraFloatingBar.swift`.** Opens her chat when the "Ask Eira" widget asks.
- **`EiraVision.swift`, `EiraChatView.swift`.** After an identification, one line notes the answer and a small copy of the photo for the widgets.
- **`Info.plist`.** Registers links that start `windfall://`.
- **`Windfall.xcodeproj`.** A second target, `WindfallWidgets`, for iPhone and iPad only. The app builds it first and copies it inside itself, on iOS only (`platformFilters = (ios, )`).

### What does not change

- **The Mac.** The widget program is not built for the Mac and is not inside the Mac app. The shared folder is nil there, so nothing is written and the ticks stay where they were.
- **The database.** No record type was added or changed.

### Checking aids

`-demoOpen widgets` opens the checking page. `-demoWidgetPage 0`, `1` or `2` picks which widgets. `-demoWidgetLook green` draws them in Garden green.

### Not built, or not as drawn

1. **"Add a sighting" on the Identify widget.** The answer on the widget is a note of what Eira said. The identification itself is gone once its sheet is closed, so there is nothing to start a sighting from. A tap opens Identify.
2. **"Ask Eira" opens her chat. It does not start listening.**
3. **Taking a photo with the camera.** The app still has no camera code.
4. **Widgets on the Mac.** A Mac widget needs a signed app, which looks in the other database (see the knowledge base, doc 31).
5. Ticks made on the iPhone before this build are not carried into the shared settings.

### ⚠️ CHECK: choices that are Claude's

1. The words under tonight's temperature: "Frost. Cover anything tender before dark.", "Close to freezing. Frost on the ground is possible." and "No frost expected." They use the same 0 and 2 degrees as "This week".
2. Which plants the "This month" widget lists: up to three from each of sow outdoors, sow indoors, plant out and harvest, the pressing ones first, four in all.
3. The widget keeps eight days of jobs. After more than a week without opening the app it says "Open Windfall to bring this up to date."

## 14 November 2026, 15:50: swiping between months, a list of months, and a back swipe that follows the fingers

**On the branch `year-month-swipe`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`mv5-mac.log`, `mv5-sim.log`, in `DerivedData/Windfall-month`). 590 logic tests pass. Seen as still pictures with the example garden: a month's page opening on the right month, the forward and back arrows turning it (December on to January, January back to December) and a month chosen from the list, on a 13-inch iPad Pro and an iPhone. **Not tried by hand, and a still picture cannot show them: a swipe with a finger, the list of months open, and everything on the Mac's trackpad.** The Mac build was started hidden with the example garden and did not crash. Nobody has yet seen the Mac's back swipe move.

**Why.** William, 15:31: "when you're in the month view, you can swipe between the months and tap the month name to bring up a list of the months so that they can be tapped to quickly move to another month." And at 15:33, with a picture of an iPhone's Settings part-way through a swipe back: "When you swipe back to the previous screen can you make it so that the screen swipes over like in this screenshot".

### 1. Swiping between months (`YearMonthView.swift`)

**What you see.** On a month's page, a finger swiped sideways turns to the next or the last month, and the whole page slides, like a calendar. December leads on to January. On a Mac, two fingers swiped sideways on the trackpad do the same, one month for each swipe.

**How.** The months are laid side by side in a row that scrolls sideways:

```swift
ScrollView(.horizontal) {
    LazyHStack(alignment: .top, spacing: 0) {
        ForEach(0..<YearCalendar.monthPageCount, id: \.self) { page in
            monthPage(YearCalendar.month(atPage: page), from: chosenFrom, isWide: isWide)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollPosition(id: $shownPage)
```

- `ScrollView(.horizontal)` is a strip that scrolls sideways. `LazyHStack` lays its contents in a row and only builds a page when it is about to slide into view.
- `ForEach` makes one page for each number from 0 up to `monthPageCount`, which is 240: the twelve months twenty times over. That is what lets December lead on to January. `YearCalendar.month(atPage:)` turns a page's number into its month with a remainder: page 12 is January again.
- `.frame(width:height:)` makes each page exactly as big as the screen's space, so one page fills it.
- `.scrollTargetBehavior(.paging)` makes the strip stop on a whole page, never between two.
- `.scrollPosition(id: $shownPage)` ties the strip to the value `shownPage` both ways. A swipe changes the number. Changing the number scrolls the strip. The arrows and the list of months work by changing it.
- Each page is its own up-and-down `ScrollView`, with its own name and cards.

**On a Mac** the strip is told not to scroll by itself (`.scrollDisabled(true)`), and a small watcher, `MonthSwipes`, reads the trackpad the way `BackSwipe` does and turns one page for each sideways swipe of 60 points or more. Left to itself, the Mac sends a sideways scroll to the page under the pointer, which only scrolls up and down.

**The clash, and William's answer.** On a Mac a two-finger swipe to the right already means "go back". William was asked which it should do on a month's page and chose: **turn the month**. So while a month's page is showing, the back swipe stands aside (`PointerClaims.monthPageIsOpen`), and the back button at the top left goes back to Year.

### 2. The month's name is a list of months

The name is now a button with a small arrow beside it. Pressing it lists the twelve months with a tick by the one showing and "(this month)" beside today's. Choosing one goes straight there, by the shortest way round, with no slide. It is a `Menu` holding a `Picker`, the same pair the "Fruit, veg…" button uses.

### 3. On a Mac, the page follows the fingers when you swipe back (`PageZoom.swift`, `Theme.swift`)

**Before.** Two fingers swiped right went back all at once when they had travelled 90 points.

**Now.** The page on top moves with the fingers, with a soft shadow down its left edge. Lift the fingers after 110 points or more and it slides off to the right and the page before appears. Lift sooner and it springs home.

**How.** `BackSwipe` already listened to the trackpad. It now keeps a number, `pull`, for how far the fingers have dragged the page:

```swift
pull = max(0, travel)
```

and every page carries a new modifier, `BackSwipeSlide`, which draws the page that far across:

```swift
let across = BackSwipe.shared.pulledPage == id ? BackSwipe.shared.pull : 0
content
    .offset(x: across)
```

- `BackSwipe` is marked `@Observable`, so any view that reads `pull` is drawn again each time it changes. That is the whole of the movement.
- `.offset(x:)` draws a view somewhere else without moving anything around it.
- Only the page being dragged moves: every other page reads 0.
- The swipe is decided once, after the fingers have moved 14 points: to the right and at least twice as far across as up or down. Otherwise it is ordinary scrolling and is left alone.
- `paperScreen()` now puts the modifier on after the paper background, so the paper moves with the page.

**⚠️ What it does not do.** In William's picture the screen before is in view underneath as the top one slides. **Here there is blank paper underneath, and the page before appears when the top one has gone.** On a Mac, SwiftUI takes the page before off the screen altogether while another is on top, so there is nothing there to show. Showing it would mean keeping a picture of each page as it is left. Not built: it needs William trying it on the trackpad between attempts.

An iPhone and iPad already do the full thing by themselves and are unchanged.

### Also

- Checking aids: with `-demoMonth 4`, `-demoMonthStep on` or `back` presses an arrow, and `-demoMonthThen 9` chooses September from the list.
- William's picture is in `Design/Reference`.
- Tests: 4 new, 590 in all, for the pages: the months going round, opening in the middle, the shortest way to a month and never running off either end.

**Choices that are Claude's.** ⚠️ CHECK each.

- A sideways swipe of 60 points turns a month on the Mac, and one swipe turns one month however far the fingers go.
- Choosing from the list jumps with no slide.
- 110 points to go back, where it was 90, and only when the fingers lift.
- The shadow on the sliding page, and no rounded corner on it.

## 14 November 2026, 15:24: a month of the Year page, opened up

**On the branch `year-month-view`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`mv1-mac.log`, `mv1-sim.log`, into a build folder of its own, `DerivedData/Windfall-month`). 586 logic tests pass. Looked at running with the example garden as still pictures: April on a 13-inch iPad Pro, dark (two columns), November on an iPhone, light (one column), and the Year page itself (`shots/mv1-*`). **Not tried by hand: pressing a month's name, the two arrows, "Show all", and the Mac's own window.** The pictures were made with the checking aid below, which opens the month's page the same way a press does.

**Why.** William, with a picture of the Year page: "Can you make it so that when you click or tap the month at the top of this page, you can see the month bigger and see what needs to be planted that month".

**What you see.**

1. **Each month's name at the top of the Year page is now a button.** On a Mac, and on an iPad with a trackpad, the name lights up under the pointer. Pressing it opens that month on a page of its own.
2. **The month's page** has the month's name in the large serif letters, a line that counts it up ("14 to sow or plant · 31 to harvest · 3 in flower") and **a card for each job**: Sow indoors, Sow outdoors, Plant out, Harvest and Flowering. Each card lists the plants that job can be done for in that month. From 720 points wide, sowing and planting are on the left and harvest and flowering on the right. Narrower, one column with sowing and planting first.
3. **Beside each plant** is one of: "This month only", "Last chance" (the last month of its stretch), "Starts now" (the first), or how long it can wait, such as "to March". The pressing ones are at the top of each card. A flower has a "Last month", not a last chance.
4. **The two round arrows** by the name step to the month before and the month after, round the end of the year.
5. A card lists ten plants and then offers "Show all 31". Tapping a plant opens its page, as on the Year page.
6. The page keeps to what the Year page lists: plants marked as growing, and the kind chosen on the "Fruit, veg…" button, which is then named above the month ("This month · Vegetables only").

**How it is built.**

*The sums* are in `YearCalendar.swift`, with no screen code, so they are tested. The one that decides the words beside a plant:

```swift
static func place(of month: Int, in months: [Int]) -> MonthPlace? {
    let chosen = Set(months.filter { (1...12).contains($0) })
    guard chosen.contains(month) else { return nil }
    let hasBefore = chosen.contains(monthBefore(month))
    let hasAfter = chosen.contains(monthAfter(month))
    if !hasBefore && !hasAfter { return .onlyMonth }
    if !hasAfter { return .lastChance }
    if !hasBefore { return .opening }
    return .during
}
```

- It is handed a month and the months a job can be done in, and looks at the month's two neighbours. With February to April: February has nothing before it, so it is the opening. April has nothing after it, so it is the last chance.
- `Set` is a bag in which each thing appears once and "is this in it?" is quick to ask.
- `guard ... else { return nil }` is a way out at the top: if the month is not one of the job's months there is nothing to say, and `nil` means "no answer". The `?` after `MonthPlace` says the answer may be missing.
- `monthBefore` and `monthAfter` go round the end of the year, so December and January are neighbours and October to February counts as one stretch.
- `MonthPlace` is an `enum`, a short list of the only answers allowed. Each has a number, 0 to 3, and the page's list is sorted by it, which is what puts the pressing plants first.

`YearCalendar.entries(for:in:from:)` uses it to make one job's list for one month, and `lastMonth(from:in:)` finds where a stretch ends, for "to March".

*The page* is `YearMonthView.swift`, new. It is drawn like the other pages: `ScreenHeader` for the name, glass cards, the Year page's coloured dot for each job. It holds the month in a `@State` value, `shownMonth`, which is a value the page owns and may change. The arrows change it and SwiftUI redraws the cards.

*Opening it* (`YearView.swift`). The Year page has a new `@State` value, `openMonth`, which is empty until a month's name is pressed:

```swift
.navigationDestination(item: $openMonth) { month in
    YearMonthView(month: month, plantKind: plantKind)
}
```

This says: whenever `openMonth` holds a month, slide in that month's page, and when the page is left, empty it again. The `$` hands SwiftUI the value itself to change, not a copy of it. Each name in the heading is a `YearMonthButton`, a small view of its own so that it can remember whether the pointer is over it.

**Changed on the Year page itself.** The month names are 32 points tall where they were 28 (40 on an iPhone), to give a finger more to press. VoiceOver used to skip the heading. It now reads each month as a button.

**Checking aid.** `-demoYear YES -demoMonth 4` opens April's page as soon as the Year page appears.

**Tests.** 11 new, 586 in all: where a month falls in a stretch, round the new year and all year; the last month of a stretch; the order of a month's list; the words beside a plant.

**Not done, and choices that are Claude's.** ⚠️ CHECK each.

- The words "Last chance", "Starts now", "This month only" and "Last month".
- Pressing plants first in each card, then A to Z. The Year page's own order (by family) is not used.
- Harvest and Flowering are on the page as well as the three planting jobs. William asked for "what needs to be planted".
- The page does not follow the Year page's search box or its job buttons. It always shows all five jobs.
- It goes by the plant library's months only. It does not know what has already been sown this year, so a plant sown in March still shows under April. "This week" on Today does know.
- No way to swipe from month to month, and the arrow keys do nothing.

## 14 November 2026, 13:35: a plant's facts can be added and changed in the app

**On the branch `plant-facts-edit`, made from `main` and merged back into it.** Built for the Mac and the iOS Simulator with no errors (`r41-mac.log`, `r41-sim.log`). 558 logic tests pass. Looked at running with the example garden on an iPad Air, a 13-inch iPad Pro and an iPhone, light and dark. The database check passed (`migrate-side.sh origin/main origin/plant-facts-edit m4`, 13:33: the version before made a database holding the full library in the iPad mini simulator, and this version opened it and listed its 376 plants).

**Why.** William, on a plant's page: "It doesn't seem to show any way to add information about the plants either". He was right. Until now a plant's facts could only come in from the spreadsheet file. Nothing in the app could add one or put one right.

**What you see.**

1. **An Edit button** beside the plant's name, and **a pencil on every card**. Either opens the editing sheet. The pencil opens it at that card.
2. **"Add information"**, a new card at the foot of the page. It lists the headings that have nothing under them yet (for the achillea: Growth Patterns, Human Management and Ecological Interactions), each a button that opens the sheet at that heading. Before, an empty heading was simply left off the page, so there was nowhere to start one.
3. **The sheet** has one card for each heading, laid out like the page. Months are twelve buttons to switch on and off. A measurement has its unit beside the box, so only the figure is typed. The yes-or-no facts are boxes to tick. The grey words in an empty box begin "e.g." and are only examples.
4. **Nothing is saved until Save.** The line under the title counts what has been changed. Cancel throws the changes away. Save is grey until something has changed.
5. **The page now shows every fact that is filled in.** It used to show 49 of the 66 a record can hold. Now on the page where a plant has them: rootstock, pollination group, ploidy, root spread, time to full height, leaf size, colour and description, foliage pattern, flower and fruit size, fruit type, sowing temperature, sowing preference, whether it needs a propagator, maintenance propagation, and the type (Seeds, Plant, Scion) on the line above the name. A lone "*" or "?", which the spreadsheet uses as a marker, is not shown.

**How it is built.**

*One list of facts* (`PlantFacts.swift`, new). Four parts of the app go through a plant's facts one by one: the page, the sheet, the import and the backup. Each used to spell them out for itself, and they did not agree. Now the list is written once and all four use it. Two lines of it:

```swift
words("spacingM", "Spacing", .habits, \.spacingM, .measure("m"), hint: "0.35"),
yesNo("isPollinator", "Pollinator plant", .permaculture, \.isPollinator),
```

Reading the first from left to right: the word the fact is filed under, what the page calls it, which card it is on, where it lives in the record, what kind of thing it is, and an example for the empty box.

- `\.spacingM` is a **key path**: a way of naming a place in a record without reading it yet, like the label on a drawer. The helper `words` is handed the label and makes the two small pieces of code that open that drawer, one to read and one to write. That is what lets 66 facts be listed in 66 lines.
- `.measure("m")` is one case of an `enum` that carries a value with it: this fact is a measurement, and its unit is "m".
- A test reads the record's own list of stored values and fails if any is missing from this list, so a fact cannot be added to the record and forgotten here.

*The sheet works on a copy* (`PlantEditView.swift`, new).

```swift
@State private var values: [String: String]
...
_values = State(initialValue: PlantFacts.values(of: plant))
```

- `[String: String]` is a **dictionary**: a set of pairs, here a fact's key and the text typed for it, such as "spacingM" and "0.4".
- The copy is taken once, as the sheet opens. Every box reads and writes the copy, never the record.
- A box needs a `Binding`, which is a pair of small pieces of code: one fetches the text, one stores what was typed. `typed("spacingM")` makes the pair for one fact.
- Save calls `PlantFacts.save`, which compares the copy with the record, writes only what differs, and notes each fact it wrote as changed by hand.

*The page is drawn from the same list* (`PlantPage.swift`). `cards(for:)` used to name each fact itself. It now walks the list, card by card, and puts each filled-in fact in the part of the card that suits its kind. The tests of the old page pass unchanged against the new one.

**Keeping what you type safe.** This is most of the work, and none of it shows.

- **Loading the spreadsheet file again does not undo your changes.** The import used to replace whatever was there with the file's value. Now a fact changed in the app is left as it is, and the import says so: "1 plant updated, 3 facts you changed in the app were kept." Facts you have not touched still come in from the file as before. (`Plant.changedByHand`, `PlantFacts.keepingHandChanges`.)
- **A renamed plant is not added twice.** The file finds a plant by its name and variety. Change either here and the record keeps the old ones, so the file still finds it. (`Plant.importedAs`.)
- **The backup now keeps every fact of a plant.** It kept eight: the names, group, three of the month rows and the notes. That did not matter while the rest could be loaded again from the spreadsheet. It matters now, because the backup is the only other copy of what you type. Backup files are now version 3, and older ones still restore.
- **Restoring on a fresh copy of the app no longer doubles the library.** A fresh copy loads its own starter library, with ids of its own. The old restore did not recognise those plants as the backup's and added a second, nearly empty copy of each, with the sowings joined to the empty ones. It now matches by name and variety, joins sowings and crosses to the plant that is there, and carries over what was typed in the app.
- **Two new values on a plant's record**, `changedByHand` and `importedAs`. The database check, run in the build chat's own copy of the code with the new script `migrate-side.sh`, confirmed that a database made by the version before opens in this one.

**Found on the way and not fixed. ⚠️ CHECK, and say which you want.**

- **The backup still leaves out four kinds of record you make in the app**: seed packets, flowering and fruiting dates, pest and disease records, and the corrections Eira keeps. Its heading says "a complete copy of everything", and it is not.
- **Three columns of the spreadsheet are not read at all**: "Garden Area" (167 plants), "Date Planted/Grafted" (52 plants) and "Moisture" (7). The first two say where a plant is and when it went in, which is what a planting is. They could become plantings.
- **There is still no way to add a plant that is not in the library, or to remove one.**
- **Status** (growing, to buy, previously owned) is not in the sheet yet.

**To check.**

- The names Claude chose for facts the page did not show before: "Time to full height", "Maintenance propagation", "Needs a propagator", "Type".
- Rootstock is on the "Sowing from Seed" card, beside Propagation, which is where the record keeps it. Say if it belongs elsewhere.
- The line above the name now ends with the type: "Summer berries · Wildflower · Hardy perennial · Seeds".
- **The Mac itself has not been looked at by Claude.** The two-column page was seen on a 13-inch iPad, which lays out the same way. The pencils, the Edit button and the size of the sheet on the Mac are untried.
- Saving was seen working in the running app: five example changes typed into the sheet, saved, and shown on the page. Typing by hand and pressing the month buttons have not been tried by anyone.

**For other code that writes a plant's fact.** `PlantFacts.write("...", forKey: "pruning", to: plant)` writes one box and notes it as changed by hand, so the import leaves it alone. It is there for the work on keeping facts read on the web (the branch `eira-web-finds`).

**Found after this was merged: an older build quietly undoes a newer database.** Tried at 13:45 in the simulator. A build from before this change was started on a database this version had opened. It opened with no complaint, and afterwards the two new values were gone from every plant. The plants themselves were untouched. So SwiftData reshapes a database to fit whichever build opens it, and an older build removes whatever it does not know. **Only the newest build should be opened on real records.** A chat's own test build is run with the example garden. Knowledge base doc 42 has the detail and a suggestion for a guard.

**Checking aids.** `-demoPlant Achillea -demoOpen plantEdit` opens the sheet, and `plantEditSowing` opens it at the sowing card. `-demoEdit "spacingM=0.4|notes=Cut back in March"` types changes into it, and `-demoEditSave YES` saves them, so a still can show the page afterwards.
## 14 November 2026, 13:33: one way of giving Eira a photo

**On the branch `eira-photo-join`, made from `main` (`4bd75fc`). It joins `photo-drop` to `main`.** In its own copy of the code, `~/Developer/windfall-photojoin`. Builds for the Mac and the simulator with no errors (`pj1-mac.log`, `pj1-sim.log`). 551 logic tests pass, 2 of them new.

**Why.** William, 11:39: "Eira should use the image model as well as identify though, right?" and at 13:09, "Build it". By then two other chats had built most of it, apart from each other. The identification chat had built Eira's judgement of a photo and the camera button in her chat, which were in `main`. The photo chat had built the "+" on her bar, dropping a photo and the photo's own date, on `photo-drop`. `photo-drop` was made before the Identify screen was rewritten, so the two clashed. At 13:14 William sent a picture of the Journal page with two Eiras on it. That was put right on `photo-drop` and arrives with this join.

**The clashes, and how each was settled.**

1. `EiraVision.swift`, the Identify screen, in four places. `main`'s screen is kept, with Eira's judgement and the shared card. `photo-drop`'s additions are put back into it: a photo to begin with (`startingPhoto`), a photo dropped on the screen and the line saying when the photo was taken.
2. `CHANGES.md` and `Tools/checks/logic-files.txt`. Both branches had added lines in the same place. Both sets are kept. The photo chat's entry now sits below the later ones from `main`, a little out of time order.

**What was made one.**

1. **One function starts a sighting from a photo**: `EiraIdentify.startSighting` in `IdentifyCards.swift`. It can now be handed two more things:

   ```swift
   EiraIdentify.startSighting(from: identification,    // Eira's answer, or nil
                              photo: imageData,        // the copy made smaller
                              original: originalData,  // the photo as it came
                              facts: facts,            // when and where it was taken
                              in: context)
   ```

   In the function's own first lines these are written `original: Data? = nil` and `facts: PhotoFacts? = nil`. The question mark means "this, or nothing". The `= nil` means "nothing, if the caller leaves it out", so older callers still work. With the facts, a photo taken on Wednesday starts a sighting dated Wednesday. With the original, the photo is kept by `Photo.record`, the photo chat's one way of keeping a photo, so it reaches the photo folder if one has been chosen. The Identify screen and Eira's chat both call this function. Before, a sighting started in the chat was dated the moment Add was pressed and kept only the smaller copy.

2. **One reader for a photo's date.** There were two. `SpeciesEye.monthTaken` cut the month out of the camera's text. `PhotoFacts` reads the whole date, falls back to a second date in the file and throws out a camera whose clock was never set. `PhotoFacts` gained:

   ```swift
   func month(in calendar: Calendar = .current) -> Int? {
       taken.map { calendar.component(.month, from: $0) }
   }
   ```

   `taken` is the date, or nothing. `.map` does what is in the braces only if there is a date and hands back nothing if there is not. `$0` stands for that date. `calendar.component(.month, from:)` asks the calendar which month the moment falls in. `SpeciesEye.monthTaken` is gone. The month Eira judges a species by now comes from the same reading as the date a sighting is given.

3. **A photo can be dropped on Eira's chat**, as it already could on her bar, the Journal page and the Identify screen (`.onDrop` in `EiraChatView.swift`). Several are looked at one after another, each with its own answer.

4. **Eira's chat remembers each photo's facts and its original** (`photoFacts` and `photoOriginals`), so that Add a sighting can use them. Only the last eight originals are held, because each is several megabytes. An older photo still starts a sighting, from its smaller copy.

**What "What is this?" now leads to.** The "+" on Eira's bar, and a photo dropped on it, open the card of three offers as the photo chat built it. "What is this?" opens the Identify screen in the same sheet, and that screen is now the one with Eira's judgement. Nothing had to be written for that. The offer card already opened `IdentifyView`, and the join put the newer screen behind that name.

**Seen.** Three pictures from the iPad mini simulator with the example garden: `shots/pj-journal.png`, `pj-offer.png` and `pj-identify.png`. This chat had no way to look at a picture, so their words were read by a small program, `read-picture.swift` in the build logs folder.

- The Journal page has one bar, at the foot, reading "Tell Eira what happened i…" with a "+" beside it.
- The offer card shows "Taken Wednesday 11 November at 2:02 pm" and the three offers.
- The Identify screen shows "Taken Wednesday 11 November at 2:02 pm. A sighting started from this is dated then." and the button "Start a sighting from this".

**Not seen or tried.**

- Eira's card on the Identify screen in these pictures. It was below the foot of the sheet. The identification chat's own pictures show it.
- Any drag, on any device. A script cannot make one.
- A real photo through the image model from the "+" or from a drop. The simulator has no image model and shows an example answer.
- Add a sighting from Eira's chat with a dated photo, and the photo folder.
- The Mac's own window.

**Not built.** Naming what is in a photo inside the journal's conversation. Another chat was changing `JournalChat.swift` and `JournalChatView.swift` at the time, on `journal-follow-up`.

**Found and left.** Sixteen Python package files (`*.whl`, 13MB) have sat at the top of the repository since `7e61a86`. One is called `swift`. They look like the result of asking Python's installer for "swift", which is an unrelated package of that name. ⚠️ CHECK: a guess from the file names. Nothing in the app uses them.

## 14 November 2026, 13:45: care questions, the RHS, and keeping what Eira finds

**On the branch `eira-web-finds`, made from `main`. Not merged**: William asked at 12:57 for the other chats to finish building before anything is joined. Built for the Mac and the iOS Simulator with no errors (`wf5-mac.log`, `wf5-sim.log`). 571 logic tests pass. Put to Apple's built-in model through the app, with the example garden and the real RHS website (`eira-care-3.md` in the build logs folder). The screens have been seen as still pictures only (`shots/wf5-*.png`).

**The database gains one record type, `KeptFact`.** Checked in the iPad (A16) simulator at 13:47 with a database of its own: a database made by `main` opens in this version, and `main` still opens it afterwards (`wf5-after.out`).

**Why.** William asked Eira: "After the first big frost, when the rhubarb has wilted, do I need to chop the leaves back?" She searched the plant library, found no pruning advice and answered "You may still leave the leaves until the season's end." The RHS says the opposite. Reading the code turned up three causes:

1. **The plant search never handed over a plant's pruning.** `search_garden` gave the name, sowing months, harvest months and position, and nothing else.
2. **Rhubarb's Pruning box is empty** in the library, for all three varieties.
3. **Nothing told her that "nothing recorded" is not advice**, and she could only search Wikipedia, which would not have known.

William then asked for three ways for a fact to reach a plant's record, each kept only when he says so: a web address pasted into the chat, Eira finding the page herself on a trusted site, and a fact typed in by hand. And for a kept fact to go into the right box of the plant's record, and to be checked again after two years.

**What a question now goes through.** Taking the rhubarb question:

1. `EiraChecks.lookupFirst` sees a care word ("chop") in a question and chooses the new lookup `plant_care`. The model is not asked whether to look.
2. `plant_care` (in `EiraTools.swift`) finds the plant the question names, here Rhubarb, and reads its Pruning box. If the box holds something, that is handed over and the lookup ends.
3. The box is empty, so the lookup says: "No pruning or cutting back advice is recorded for Rhubarb in the plant library. That means nothing has been written down. It does not mean nothing needs doing."
4. It then finds the RHS's page for rhubarb (below), picks out the paragraph about cutting back and hands that over too, with the RHS named as a checked source.
5. The model answers from that. Under its reply a card offers to keep the fact: for Rhubarb, in Pruning, from the RHS.
6. If **Keep it** is pressed, the words go into the Pruning box of all three rhubarbs, and a small record beside each remembers the RHS, the page's address and the date.
7. Asked again, step 2 finds the box filled and no website is read.

**New files.**

| File | What it holds |
|---|---|
| `KeptFacts.swift` | The record of where a kept value came from (`KeptFact`), the boxes of a plant's record a fact can go into (`PlantField`), the kinds of care question (`CareTopic`) and the rules: which plant, which box, months, the two-year check. No screen code, so all of it is tested |
| `EiraSources.swift` | The websites Eira knows by name and how far each is trusted, how she finds the RHS's page for a plant, how she remembers which address worked, and how the right paragraph is picked out of a long page |
| `KeptFactViews.swift` | The card under her reply, the form on a plant's page and the two lists |

**Finding the RHS's page.** The RHS has no search made for programs. But its growing guides sit at addresses made from the plant's name, in several shapes (William: "RHS for example has a few different structure"). These were seen on its site on 14 November 2026:

| Shape | Example |
|---|---|
| `/vegetables/<name>/grow-your-own` | rhubarb, carrots, garlic, broad-beans |
| `/fruit/<name>/grow-your-own` | apples, raspberries, and rhubarb again |
| `/herbs/<name>/grow-your-own` | mint |
| `/plants/<name>/growing-guide` | lavender |
| `/fruit/<name>/<subject>` | `/fruit/apples/winter-pruning`. Not guessed: reached by a pasted address |
| `/advice/profile?pid=<number>` and `/plants/<number>/<latin-name>/details` | Need the RHS's own number, so they cannot be built from a name. Reached by a pasted address |

```swift
static func candidates(for name: String, kind: PlantKind) -> [String] {
    let names = slugs(for: name)
    ...
    for section in edible {
        for slug in names { growYourOwn.append("https://www.rhs.org.uk/\(section)/\(slug)/grow-your-own") }
    }
```

- `slugs(for:)` turns a name into the part of an address: "Broad bean" gives `broad-bean` and `broad-beans`. Both are tried because the RHS uses both: `/fruit/apples/` but `/vegetables/rhubarb/`.
- `edible` is the sections in an order set by the kind of plant, so a fruit tries `/fruit/` first.
- `"\(section)"` inside a piece of text drops that value into the text. This is how every address here is put together.
- At most eight addresses are tried. The first whose page title names the plant wins (`RHSFinder.isAbout`). That check matters: a wrong address on the RHS gives a page titled "Page Not Found".
- `PageMemory` remembers the address that worked, so the next question about rhubarb goes straight there. A plant with no page is remembered too and not tried again for a month.

**Reading a page properly** (`EiraWebLookup.swift`). Four things were wrong or missing, and each was found by putting real RHS pages through the app:

- A page was cut to its first 4,000 characters as it was read. The pruning advice on a growing guide is far below that. `WebPageReader.fetch` now keeps the whole text and `WebText.passages` picks the part that bears on the question.
- A "not found" page was read as if it were the answer. A site's reply carries a number, 200 for "here it is" and 404 for "no such page", and anything outside 200 to 299 is now treated as no page.
- The RHS tucks the meaning of a word inside the sentence that uses it, hidden until the word is tapped. Left in, the meaning of "perennial" ("they die back to ground level each autumn") was picked out as pruning advice. Both of the RHS's forms of this are now taken out.
- At the foot of a page are teasers for other pages. One, about plums, was handed over as advice on apples, and the model answered with the time to prune plums. Reading now stops at "You may also like".

**Which paragraph** (`WebText.passages`). Each line of the page is marked: two marks for a word of the subject ("cut back", "prun", "die back"), two more if its heading holds one, and one for each of the question's own words. On a page that is about the subject from top to bottom, the question's words decide instead. A question that asks when also looks for months and seasons.

**Into the right box** (`KeptFacts.swift`).

```swift
enum PlantField: String, CaseIterable, Identifiable {
    case pruning, propagation
    ...
    func value(in plant: Plant) -> String? { ... }
    func set(_ value: String?, in plant: Plant) { ... }
}
```

- An `enum` is a fixed list of named choices. This one lists the boxes of a plant's record a fact may go into: 21 of them.
- `value(in:)` and `set(_:in:)` are the only places that know which property of `Plant` each box is. Everything else says `field.value(in: plant)` and never needs to know.
- `CaseIterable` gives `PlantField.allCases`, the whole list, which is what the menu on the card shows.
- The starting choice is made by plain rules from the question (`KeptFacts.field`): "chop", "prune" and "cut back" point to Pruning, "sow" to the sowing months, and anything the rules cannot place goes to Notes. It can be changed on the card.
- **A box of months takes only months.** "Sow from March to May" is stored as "Mar, Apr, May", because the Year page and the sowing reminders read those boxes. The card shows the months before anything is kept, and a fact naming no month cannot go into such a box.
- If the box already holds something, the card shows it and offers **Replace** or **Add to it**.

**Where it came from** (`KeptFact`, a new record type). A box holds only its words, so the source lives in a record beside it: the plant, the box, the words, the site, the address, how far the site is trusted, the date, and what the box held before. That last is what makes **Remove** safe: if the box still holds exactly what the fact put there, the old value is put back. If it has been changed by hand since, it is left alone.

**The check after two years.** `KeptFacts.isDue` is true two years after a fact was kept, or after **Still right** was last pressed. A due fact is marked on the plant's page and in the list, and Eira is told it is "over two years ago and due a check" each time she is handed it. She goes on using it.

**The three ways in.**

1. **A pasted address.** `EiraChecks.webAddress` spots a web address in a message. The app then reads that page before the model answers (`EiraConversation.send`), where before it was left to the model to think of it.
2. **Eira finds it herself.** The `plant_care` lookup above. Only the RHS so far.
3. **By hand.** A plant's page has a new card, **Kept facts**, with a **Keep a fact** button. The form asks for the fact, the box, and where it was read. Given a web address it recognises the site.

**Where kept facts are seen.** On the plant's page, in the Kept facts card, and as a small green label under the value itself ("RHS, kept Nov 2026"). All together under **Kept facts** in the Options menu of Eira's chat, those due a check first. Each has **Open the source**, **Change it** and **Remove**, and **Still right** once it is due.

**Other changes.**

- `search_garden` now hands over a plant's pruning.
- "Should I prune?" names no plant. For so short a question about pruning, feeding or dividing, the lookup now tells the model to ask which plant. On the test sheet no model had (doc 29).
- A page's source line names the site and says how far it is trusted, where before every page was "unverified". The list of sites is `WebSources.all` in `EiraSources.swift`. ⚠️ CHECK: it is Claude's list.
- Eira's test sheet has a section H for all of this, and `-eiraTestFull YES` writes each lookup out whole.

**Tried with Apple's model** (13:35, `eira-care-3.md`):

| Question | Answer |
|---|---|
| The rhubarb question | "cut away the old leaves to expose the growing points to winter cold", from the RHS. The card offered Rhubarb, Pruning, RHS |
| The same in other words, after Keep it | The same advice, "from your own plant database, kept Nov 2026". No website read |
| What does `rhs.org.uk/fruit/apples/winter-pruning` say about when to prune? | "every winter, from November to early March" |
| When should I prune the lavender? | "annually in late summer, just after flowering has finished", from the RHS |
| Should I prune? | "Which plant are you referring to?" |

**Not done.**

- Only the RHS can be found by name. Gardeners' World and the others on the list can be read from a pasted address.
- The RHS's terms for an app reading its pages have not been found (doc 36). One page is read when a question needs it, the request says it is Windfall, and nothing is copied or crawled. ⚠️ CHECK before Windfall is ever given to anyone else.
- The backup file does not carry the kept-fact records. The values themselves are in the plants' records, which it does carry.
- The card's **Plant** box takes a typed name. It does not yet offer a list to choose from.
- Nothing here has been tried by hand.

## 14 November 2026, 12:57: "Sow to crop" was being read as days

**On the branch `sow-to-crop-units`, made from `main` and merged back into it.** 535 logic tests pass.

**What was wrong.** Found while reading the plant page's code, not asked for. Every "Sow to crop" figure in the spreadsheet is written in weeks or months: 89 in weeks, 6 in months, none in days. The app took the number and called it days. Garlic's "20 weeks (typical)" was shown on its page as "Sow to crop: 20 days". Worse, Today works out when a crop is due from the same figure, so it would have offered "Harvest garlic" twenty days after planting.

**What changed.**

1. `DurationParser`, new in `Parsing.swift`, reads the unit as well as the number:

   ```swift
   DurationParser.days(in: "12-16 weeks")      // 84 to 112 days
   DurationParser.describe("12-16 weeks")      // "12–16 weeks"
   DurationParser.describe("14")               // "14 days": no unit named means days
   ```

   It looks for the first unit named in the text (day, week or wk, month or mth, year or yr) and uses only the numbers written before it, so "12 weeks (84 days)" is 12 weeks and not "12 to 84". A week is 7 days, a month a twelfth of a year.
2. A plant's page shows the figure in its own unit: "20 weeks", "9–12 months" (`PlantPage.swift`).
3. Today's two harvest reminders turn it into days properly before adding it to the sowing date (`TodayView.swift`).

Germination was not affected. Its column is in days.

**A test reads the real library**: every sow-to-crop figure in it must come out as weeks or months, and none shorter than a fortnight. If a figure is ever written another way, that test will say so.
## 14 November 2026, 13:30: "Want to pin it down?" in the journal, "tonight" means now, and the weather for earlier today

**On the branch `journal-follow-up`, made from `main` at `06a8915`. Not yet merged.** Built for the Mac with no errors. 537 logic tests pass (17 checks are new). Not yet tried by hand.

**Why.** William wrote "I noticed an insect in my garden tonight" in the journal (13 November, 22:30). The entry was kept, but nothing helped him name the insect while he still remembered it. He also saw two faults: Eira asked "It is 22:30 and dark out. Was this about earlier today?" though he had written "tonight", and the weather chip said the service had no figures for ten that morning.

**What changed.**

1. **Pinning it down** (`JournalChat.swift`, new `JournalPinDown.swift`, `JournalChatView.swift`). When an entry says something was seen (saw, spotted, noticed, found, there was) and names it only loosely ("an insect", "a small brown beetle", "some odd mushrooms"), Eira adds one card: *Want to pin it down?* with **Add a photo**, **Describe it** and **Leave it unidentified**. A photo goes through the same identification as Identify and Eira's chat. Describe asks size in centimetres, colours, wings and how they are held (insects only), what it was doing and where. Either way an unconfirmed sighting is made, dated with the entry. "Red admiral butterfly", "cabbage white butterflies" and "a robin" count as named and get no card.
2. **Not nagging.** One card per entry, never a run of questions. After three finds in a row go by without the card being used, it comes one time in three (`shouldOfferPinDown`).
3. **"Tonight" means now** (`timeCheck`). "Tonight", "this evening", "just now", "right now" and "at the moment" stop the after-dark question.
4. **The weather for earlier today** (`askServiceIfMissing`). Where a garden has a location but its weather diary has no figures yet for that hour, the weather service is now asked at the garden's location. Before, only gardens with no location were asked.

**Will clash with `photo-drop`** in `JournalChat.swift`, as well as the three files doc 37 lists.

## 14 November 2026, 12:50: a sowing or a planting, added from the plant's own page

**On the branch `plant-page-plantings`, made from `main` and merged back into it.** Built for the Mac and the iOS Simulator with no errors (`r33-mac.log`, `r33-sim.log`). 531 logic tests pass. Looked at running in the iPad simulator with the example garden, light and dark.

**Why.** William, looking at the Achillea page: "Could you make it so that you can add a planting of plants in the plant page?" Two things stood in the way. A sowing could only be started from Today or the Sowings list, by finding the plant all over again. And only a plant kept by cloning (a fruit tree, garlic, a potato) could be recorded as *planted*. An achillea bought in a pot could only be written down as seed sown, which is not what happened.

**What changed.**

1. **The card** (`PlantLibraryView.swift`, in `PlantDetailView`). "Sowings" is now "Sowings and plantings". It is always there, where before it was left out until the plant had been sown, and it comes first: under the name when the page is one column, at the top of the right-hand column when it is two. Each row says "Planted 24 Oct 2026" or "Sown 14 Mar 2026", then where and how many ("Herb bed · A · 3 plants"), then the stage, and opens that sowing's own page. Under the rows are two buttons, **Add a sowing** and **Add a planting**.

2. **The form opens with the plant already chosen** (`PlantingViews.swift`). `NewPlantingView` gained a starting point:

   ```swift
   init(plant: Plant? = nil, asPlanting: Bool = false) {
       _selectedPlant = State(initialValue: plant)
       opensAsPlanting = asPlanting
   }
   ```

   - An `init` is the code that runs when a thing is made. This one takes two things, and each has a value to fall back on (`= nil`, `= false`), so the old `NewPlantingView()` on Today still works unchanged.
   - `Plant?` means "a plant, or nothing". `nil` is the nothing.
   - `selectedPlant` is `@State`: a value the form keeps and redraws itself for. `_selectedPlant` with the underscore is the box that value lives in, and `State(initialValue: plant)` is how a starting value is put in the box before the form first appears.

3. **Every plant can go in as a plant** (`SeedTruth.swift`). `SeedTruth.starts` lists the ways of starting that the form offers. It used to hand back an empty list for an ordinary plant, which meant "do not ask". It now always ends with `.plant`, so the form asks **Seed** or **Plants**. For a plant where saved seed matters (a squash, an F1) the three choices are "Seed from a packet", "Seed I saved" and "Plants", as before plus one. A new rule, `asksSeedSource`, keeps one promise from before: for an ordinary plant the form never asked where the seed came from, so nothing about a packet is written into the record.

4. **What is saved for a planting.** `startedFrom = .plant` and the stage "growing", with the date as the day it was planted. The journal already words that as "Planted Achillea" and "3 planted". A planting's own page now says "Planted" where it said "Sown".

5. **A succession round counts sowings only** (`PlantModels.swift`, `Planting.nextRound`). The first still of the new form said "Succession round 3" on a planting, because every earlier record that year was counted. A round is a round of sowing: plants going in neither get a number nor use one up.

6. **The wording of the rows is tested** (`PlantPage.swift`, `plantingLines`). As with the rest of the page, the words are worked out in a file with no screen code, so the checks can run them without a Mac: newest first, "plants" for a planting and "seeds" for a sowing, "1 plant" not "1 plants", "On record" for one with no date.

**How the buttons open the form.** This pattern is worth knowing, because Windfall uses it everywhere:

```swift
private enum AddingToGarden: String, Identifiable {
    case sowing, planting
    var id: String { rawValue }
}
@State private var adding: AddingToGarden?

Button("Add a planting") { adding = .planting }

.sheet(item: $adding) { which in
    NewPlantingView(plant: plant, asPlanting: which == .planting)
}
```

- An `enum` is a short list of named choices: here, which of the two forms.
- `adding` holds one of them, or nothing (the `?`). A button does nothing but set it.
- `.sheet(item:)` watches `adding`. While it holds a choice the sheet is up, and it hands the choice to the code in the braces as `which`. When the sheet is closed, SwiftUI sets `adding` back to nothing by itself. `Identifiable` (the `id` line) is what lets it tell one choice from another.
- So the button never "opens" anything. It changes a value, and the screen follows the value. That is the idea behind all of SwiftUI.

**Also in this change.**

- The example garden has a sowing and a planting of achillea, so the card has something to show in a still. Example data only: it lives in memory and never touches real records.
- Checking aids: `-demoPlant Achillea -demoOpen plantPlanting` and `-demoOpen plantSowing` open the form from the page.
- The checks had been failing on `main` since the Plants search work: a variable called `box` in `CollapsingSearch.swift` was read by the cross-file check as every other `box` in the app. It is now `textBox`. Nothing was wrong with the app itself.
- William's screenshot is filed in `Design/Reference`.

**To check.**

- Is "Seed" and "Plants" the right pair of words? And "For plants that came as plants: bought, given, divided or grown from a cutting"?
- Is the card in the right place, first on the page?

## 14 November 2026, midday: Eira identifies from a photo, and a page for testing the image models

**On the branch `eira-identify`, made from `main` and merged back into it.** Built for the Mac and the iOS Simulator with no errors (`identify-7-mac.log`, `identify-7-sim.log`). 520 logic tests pass. Both image models were run through the app on the same 300 UK photos and scored as they did before (the table below). The answer card was seen in the simulator, in the Identify sheet and in Eira's chat, on example answers. **Not yet tried by hand: giving Eira a real photo in the chat, "Add a sighting", "Ask Eira about it" and the whole of the test page.** The test page has only been compiled. William is the first to run it.

| 300 unseen UK photos, 776 names | BioCLIP 2.5 Huge | BioCLIP 2 |
|---|---|---|
| The model alone: first answer right | 293 (98%) | 289 (96%) |
| The model alone: named outright, and of those right | 294, 290 | 272, 271 |
| Eira: named a species, and right | 251, 247 | 234, 233 |
| Eira: said one of several look-alikes, and the true one among them | 43, 43 | 38, 38 |
| Eira: gave the genus only, and the right genus | 3, 3 | 10, 9 |
| Eira: said she was not sure | 3 | 18 |
| Seconds a photo, both in one run with the chip free | 0.22 | 0.15 |

So with BioCLIP 2.5 Huge she answers 297 of 300 and is wrong on 4, the same 4 the model is wrong on. What the rules change is how the other 293 are put: 43 are given as "one of these" where a species cannot honestly be named from a photo, and 3 that the model would not name are given, rightly, as a genus. The four wrong ones are a common lizard named as a wall lizard, hemlock named as cow parsley (which carries the carrot-family warning), common comfrey named as Russian comfrey and a buff ermine named as a muslin moth. `identify-species-both.md` on the Mac has every photo. The month and the records were not part of this test: the photos carry no dates and the example garden has no sightings of them.

**Why.** William asked: "Could you build the identification part of Eira now for integration in to the app and so I can test the models". Until now the Identify screen showed the image model's three closest names and nothing more, Eira's chat could not be given a photo at all, and only one image model could be installed at a time, so two could not be compared inside the app.

**The idea in one line.** The image model only matches a photo to a list of names. Eira's judgement about that match is now a separate step, done by fixed rules with no model, so it behaves the same whichever image model is underneath.

**What changed.**

1. **Eira's judgement about a photo** (`EiraIdentify.swift`, new). `EiraIdentify.judge` takes the image model's answer and what Windfall knows, and hands back an `EiraIdentification`: a verdict, a headline, warnings, what the records say and the wording for the chat. Five rules:
   - *A genus when the species is unclear.* If she cannot name a species but the closest names are two or more of one genus sharing 85% between them, she gives the genus: "A bumblebee (Bombus), species not certain". The everyday word comes from the English names where they all end the same way.
   - *Look-alikes.* If the name is in a group that cannot be told apart from a photo (`SpeciesLookalikes.json`), she says "Buff-tailed Bumblebee or a look-alike", names the group and gives the reason. ⚠️ CHECK: that file was written by Claude from memory on 13 November. Every warning from it is marked "to check" on screen until the file's own `"checked": false` is changed to `true`.
   - *The month.* The name is checked against UK records month by month (`SpeciesMonths.json`: iNaturalist's counts for 609 species, fetched on 13 November, real figures) and against the flight period in William's own wildlife list. Rarely recorded in that month, or outside his list's flight period, turns "probable" into "possible". **The month is the one the photo was taken in**, read from the photo's own date where it has one, and otherwise this month. ⚠️ CHECK: the levels are Claude's: under 2% of a species' records in the month is "not often", under 0.5% is "rarely".
   - *The records.* Each name is looked up in the plant list, the wildlife list and past sightings: "It is in your plant list: Lavender, Hidcote", "You have recorded it 3 times, last on 12 November 2026, 2 of them confirmed". Names are compared by genus and species only, so a variety or an author's name does not stop a match.
   - *Dangers.* A plant on a list of 19 dangerous ones (`PlantDangers`) brings a boxed warning if it is the first name or holds 2% or more of the model's belief, whatever was named first. This answers the photo of hemlock water-dropwort that was named as yellow iris at 87%. ⚠️ CHECK: the list is Claude's, from general knowledge. It is not a list of every poisonous plant. **The carrot-family warning is the one another chat built the same morning** (`DangerousLookAlikes`, in the entry below). Eira's rules call it and do not repeat it: it shows when any of the three names on screen is of that family, unless one of them has already been warned of by name. A carrot-family plant that is named is never given as better than "possible".

   None of it needs the screen or Apple's AI frameworks, so all of it is tested without a Mac: 44 new logic tests.

2. **One card for the answer, used in two places** (`IdentifyCards.swift`, new). `IdentificationCard` draws the verdict, the warnings, the model's three closest names as bars and the lines from the records. The Identify screen uses it, and so does Eira's chat. The same file gathers what the rules need from the database (`IdentifyKnowledge.gathered`), runs the whole job (`EiraIdentify.identify`) and starts a sighting (`EiraIdentify.startSighting`).

3. **A photo can be given to Eira in her chat** (`EiraChatView.swift`, `EiraConversation.swift`). A camera button beside the text box takes one from Photos or from a file. The photo joins the conversation as a message, and her answer is the card, with two buttons:
   - *Add a sighting.* Starts an unconfirmed sighting with the photo. The name goes in as a suggestion (`provisionalID`), never as confirmed. When she was not sure, no name is written in at all. **This is the only thing here that saves, and only when the button is pressed.**
   - *Ask Eira about it.* Sends "Tell me about …" to her text model with the species lookup run first. `send` gained a third setting, `about:`, so the lookup is given the scientific name and not the whole sentence.

   Naming a photo does not use the text model, so it works where no text model can run. Her answer is also kept in the conversation as words, so the text model has it in front of it for a follow-up question. The photo itself is held only while the chat is open. It is saved when a sighting is started from it.

4. **More than one image model can be installed** (`SpeciesEye.swift`). An image model is now any folder in the Models folder that holds a model, `uk_species.json` and `uk_species_rows_f16.bin`. An optional `eye.json` gives it a name to show and an order. Eira uses the one chosen on the test page, or the first in order. `SpeciesEye.shared` follows that choice, and `SpeciesEye(using:)` makes one tied to a particular model. Until now the folder had to be called `bioclip2` and the model file had one fixed name.
   - Image models no longer appear in the list of text models Eira can talk with. Another chat put this right the same half hour, after the new `bioclip2-original` folder turned up in that list (the entry below). Its fix is the one kept.
   - A species in the list can carry where its name came from (`SpeciesEntry.source`). A name that came from a pot label says so on the card.

5. **A page for testing the image models side by side** (`EyeTestView.swift`, new). Wildlife, Identify from a photo, "Test the image models". Choose up to 60 photos, run them through every installed model, then mark each photo with what it really is: one of the names given, a name typed in, or "not on the list". For each model it counts first answers right, right among the three, named outright and right, **named although not on its list**, and seconds a photo. "Use for Eira" chooses a model. "Copy the results" puts the whole test on the clipboard. "Keep my answers" saves each marked photo and its true name beside the Models folder, in `Photo answers`, where they can later be used to teach or test a model. Nothing is taught by the page itself.

6. **The test run measures Eira's judgement too** (`SpeciesTestRun.swift`). After the model's own totals it now reports what she would have said for each photo and whether that was right, and lists every photo where the model's first answer was wrong and she still gave an answer. `-speciesEyeFolder <folder>` picks the model.

**On the Mac.** `Models/bioclip2` holds BioCLIP 2.5 Huge (doc 30) and now has an `eye.json` naming it, order 1. A new folder, `Models/bioclip2-original`, holds BioCLIP 2 with the table made for it, order 2. The model there is a clone and takes no extra room.

**Checking aids.** `-demoOpen identify -demoMatch YES` shows the Identify sheet on an example answer, as before, now judged against the example garden's real records. `-demoOpen eira-photo` opens Eira's chat on the same example.

**Not done.**
- "Add to the count": offering to add the insect to a FIT count that is under way.
- Opening the plant's page or the species' page from the card.
- A photo in a saved conversation. Reopened later, her answer shows as words without the photo or the card.
- Dropping a photo on to the chat. Another chat is building drops for the journal (`photo-drop`), and its `PhotoFacts` reads a photo's date and place more fully than the month read here. The two should be joined when both are in `main`.
- The rest of the chat screen is still in the old look.
- An image model still cannot be added from inside the app, and the species list is still made on the Mac.

## 14 November 2026, 12:20: the photo model is no longer offered as a model for Eira's chat

**Why.** Eira's settings list every folder in Windfall's Models folder that holds a file ending in `.aimodel`. The photo model's folders (`bioclip2`, and `bioclip2-original` since another chat added it) hold one too, so they were listed beside the two Qwens. Choosing one would only give an error, because a photo model cannot hold a conversation.

**What changed** (`EiraModelLibrary.coreAIModelNames` and `holdsTextModel` in `EiraEngine.swift`). Apple's exporter writes a small file, `metadata.json`, into every model folder it makes, with a line saying what kind of model it is: `"kind": "llm"` for a text model. A folder is now listed only if it has that file and the file does not name another kind. The photo model's folders have no such file, so they drop out. One test builds five pretend folders and checks that the right two are listed.

## 14 November 2026, midday: three things the trained Qwen's test turned up

**In `main` since 12:00**, by way of the branch `carrot-family-warning`, with the warning below. Built for the Mac and the simulator as r26 (`36b0bcd`), no errors. 474 logic tests pass.

The trained Qwen3 8B sat Eira's test sheet for the first time at 11:29 (knowledge base, doc 32). Three of its answers showed faults that were the app's and not the model's.

**1. "Nothing has been recorded" was taken for a claim to have saved** (`EiraChecks.claimsToHaveSaved`).

- *What happened.* Asked what had been harvested this month, the model answered that there were no harvests and that nothing had been recorded. The rule that removes false claims of saving looks for "been recorded… in your…". It found those words, took the sentence out and wrote "Nothing has been saved. I cannot change your records from this chat" under the answer.
- *The change.* The sentence is now read a clause at a time, split at commas and at "but" and "and". In each clause, if a denial ("nothing", "no", "not", "never", "hasn't" and the like) comes before the saving word, the clause is not a claim. "I cannot save changes, but your sowing is now recorded" is still caught, by its second clause.
- *A trap avoided.* The first try looked for any word ending in "nt" to catch "hasn't" and "haven't" (the code strips apostrophes first). That would also have read "plant" and "current" as denials, so "Your plant is now recorded" would have slipped through. Each such word is now listed whole, and a test holds that sentence in place.

**2. The plant search could not find "English lavender"** (`ToolRunner.plantMatches`, used by the `search_garden` lookup in `EiraTools.swift`).

- *What happened.* The plant is stored as Lavender, with English as its variety. The lookup wanted the whole phrase "english lavender" inside one field, and never looked at the variety at all. So the model was told "Nothing matching", and told William his database had no such plant. "Spartan" would not have found Apple, Spartan either.
- *The change.* The search is split into words. Small words ("the", "my") are dropped. Every word left must be somewhere in the plant's name, variety, Latin name or group, in any order. A word ending in "s" also matches without it.
- `allSatisfy` in the code means "true only if every item passes".

**3. A kept correction could be ignored** (`EiraChecks.corrections(bearingOn:among:)`, `handOver`, used in `EiraConversation.generate`).

- *What happened.* The new section G of the test sheet: tell Eira "No, that's wrong. There is also a Bramley apple by the shed", press Keep it, then ask in a new conversation "Do I have a Bramley apple?" Apple's model said yes. The trained Qwen ran a lookup, found nothing and said no, although the correction was in its instructions. A model weighs what arrives with the question more than what stood in its instructions.
- *The change.* Before a question goes to the model, every kept correction is compared with it. One that shares a word that matters with the question, or with the question it was first given on, is put in front of the question, under a line saying it is the gardener's own word and outranks an empty lookup. At most three, newest first.
- *"A word that matters"* (`wordsThatMatter`): four letters or more, not one of about sixty common words ("what", "have", "garden", "plant"…), with a final "s" taken off. Each text becomes a `Set` of such words, and `isDisjoint` asks whether two sets share nothing.
- *A bonus.* Only the ten newest corrections fit in the instructions. This searches all of them, so an old one comes back when a question touches on it. The Corrections list now says so.
- *The wording.* Apple's model, using a correction, said "the garden record confirms" it. The records did not. The line now ends: say "you told me". Do not say the records show it, unless a lookup shows it too.
- Only the model sees the added lines. The conversation on screen, and what is saved, keep the question as it was typed.

## 14 November 2026, midday: a carrot-family warning on photo matches

**In `main` since 12:00**, by way of the branch `carrot-family-warning`. Seen in the simulator in light and dark (`shots/carrot-*.png` on the Mac).

**Why.** That morning the fine-tuning chat put a newer image model into Windfall's Models folder at William's request (BioCLIP 2.5 Huge, doc 30). The build chat ran the same 300 unseen UK photos through the app with it:

| | BioCLIP 2 | BioCLIP 2.5 Huge |
|---|---|---|
| First answer right | 289 | 293 |
| Right answer among the three | 295 | 299 |
| Named outright | 272, of which 1 wrong | 294, of which 4 wrong |

It is right more often and sure more often, and so it is also sure more often when wrong. **It named a photo of hemlock as cow parsley at over 99%.** The older model had said "not sure" for that photo, and had its own such mistake (hemlock water-dropwort named as yellow iris). Both plants are deadly. Both are in the carrot family. Both times a carrot-family plant was among the three candidates on screen.

**What changed.**

- `DangerousLookAlikes` in `SpeciesTable.swift`: a list of 31 carrot-family genera (the first word of a scientific name), and one function. If any of the three candidates is a plant whose genus is in the list, `SpeciesGuess.lookAlikeWarning` returns the warning. Otherwise it returns nil.
- The Identify screen (`EiraVision.swift`) shows that warning in an orange box above the names, however sure the model is. The small print under every answer is unchanged.
- *Why the group is checked as well as the name.* An animal can share a plant's genus name. Oenanthe is the water-dropworts and also the wheatears, which are birds. So the rule asks that the candidate is a plant.
- *Why "any of the three" and not only the first.* In the first mistake the first answer was an iris. The deadly plant was second, at 6%.
- The photo test run (`SpeciesTestRun.swift`) now counts how often the warning shows, how many photos really were of the family and whether any of those went without it.
- `-demoMatch hemlock` shows the warning in the simulator, with the real mistake as the example.
- The comments in `SpeciesTable.swift` no longer say the model is BioCLIP 2 with 768 numbers. The table says how many numbers its rows hold, so the code works with either.

**For William to check.** ⚠️ CHECK: the genus list and the wording of the warning are Claude's, from general knowledge and not from a field guide. The warning reads: "Take care: this may be one of the carrot family. That family holds deadly plants, hemlock and hemlock water-dropwort among them, that look much like cow parsley, wild carrot, wild celery and parsley. A photo cannot tell them apart safely. If you did not sow it yourself, do not eat any part of it on the strength of this, and wear gloves to handle it: giant hogweed, of the same family, burns the skin." It will also show on photos of your own carrots, parsley, fennel and parsnips, which is why it says "if you did not sow it yourself".

**Not done.** Other dangerous pairs: wild garlic with lords-and-ladies and lily of the valley, comfrey with foxglove. Each needs a checked list first. The "not sure" level (0.85) was set for the older model and should be set again for this one from William's own photos (doc 30).
## 14 November 2026, 12:24: the 12GB rule no longer stops Apple's built-in model

**On the branch `search-collapse`.** Built for the Mac and the simulator with no errors (`search7-mac.log`, `search7-sim.log`). The seven checks of the rule were run on the Mac on their own and pass. The full logic tests were not run. **Not tried on an 8GB device. Nothing here has been.**

**Why.** William asked whether 8GB devices could have Eira on a smaller model. They could not have her at all: the rule refused every model on a device under 12GB. But the 12GB figure was sized for a downloaded model of about 8B, which Windfall holds in its own memory. Apple's built-in model is run by the system, and it is Eira's default. William agreed that smaller devices should have Eira on it.

1. **`DeviceCapability` in `EiraEngine.swift`.** `canRunEira` is now `canRunDownloadedModels`, the same sum under a truer name. A new `canRun(_ kind:)` answers for one kind of model: always yes for Apple's built-in, the 12GB rule for a Core AI or MLX model.
2. **`EiraEngineFactory` in `EiraOnDeviceEngine.swift`.** It applies the rule to the model that is chosen, not to the device as a whole. Two new values: `builtInModelIsAvailable`, which asks the system whether Apple's model is on this device and ready, and `deviceCanRunEira`, true if there is the memory for a downloaded model or Apple's is here.
3. **Eira's bar** (`EiraFloatingBar.swift`) opens Eira when `deviceCanRunEira` is true. On a device with neither, it still falls back to plain search, as before.
4. **The wording.** Choosing a downloaded model on a small device now says to choose Apple's built-in model in Eira's settings. The Memory line in her settings says which case this device is in.

**CHECK.** That Apple's built-in model is offered on 8GB devices such as the iPhone 15 Pro and iPad mini 7, and that the system runs it outside the app's memory, is Claude's understanding and was not looked up or tried. The code does not rely on it: it asks the system, and a device without the model is treated as before.

**Not done.** A small model of our own for these devices, such as a 2B or 4B Qwen trained on Eira's habits. It would need its own, lower memory line, set by trying it on a real device.

## 14 November 2026, 12:22: Find in the Edit menu, and the search box takes the cursor

**On the branch `search-collapse`.** Built for the Mac with no errors (`search5-mac.log`). Checked in a test copy with the example garden, without bringing it to the front: Edit, Find opens the box and the cursor is in it. The glass closes an empty box and opens it again with the cursor in it. Seven letters sent as key presses arrived in the box and the cross appeared. Escape emptied and closed it. **Not tried**: Command-F pressed on a real keyboard, and clicking away from the box.

**Why.** William tried Command-F and nothing happened. Looking into it turned up a second fault that nobody had seen yet: when the box opened, the cursor was not in it.

1. **Command-F is now "Find" in the Edit menu** (`FindCommands` in `CollapsingSearch.swift`, added to the app in `WindfallApp.swift`).
   - *What was wrong.* The shortcut had been given to the magnifying glass button itself. A shortcut on a button inside a Mac toolbar was not picked up.
   - *How it works now.* The menu line sends a notification, `windfallFind`. A notification is a note pinned to a board that any part of the app can be watching. The search glass watches for it, opens and takes the cursor. The menu does not need to know which screen is showing.
   - *A limit.* On a screen with no search glass, Find is still in the menu and does nothing.
2. **The box to type in is now AppKit's text field** (`ToolbarTextBox` and `CursorTakingField`).
   - *What was wrong.* It was SwiftUI's `TextField`, with `@FocusState` to put the cursor in it. Inside a Mac toolbar that did nothing, with or without a pause first, while the same `@FocusState` worked for Eira's bar in the same window.
   - *How it works now.* AppKit is the older Mac toolkit SwiftUI sits on. There the window can be told outright which box has the cursor (`makeFirstResponder`). The screen asks by adding one to a number, `cursorRequests`, and the box takes the cursor each time the number changes.
   - Typing, Escape and leaving the box are reported by AppKit to a helper (the `Coordinator`), which passes them on.

**A correction to the entry below:** it says the glass was tried and worked. It opened and closed, and words put into the box narrowed the list. Whether the cursor arrived was listed as not tried. It did not arrive.

## 14 November 2026, midday: the Plants search rests as a magnifying glass

**On the branch `search-collapse`, made from `main`.** Built for the Mac and the simulator with no errors (`search1-mac.log`, `search1-sim.log`). Tried in a test copy on the Mac with the example garden: the glass opens the box, typing "spartan" leaves 1 of 376 plants, the cross empties it and the glass closes it again. **Not tried by hand**: whether the cursor lands in the box when the glass is clicked, Command-F, Escape and clicking away. The logic tests were not run. They need the Linux checker, which this chat did not have.

**Why.** William asked whether the wide search box at the top of the Plants window is needed now that Eira can search. It is: it narrows the list as each letter is typed, with no model, and it works on devices that cannot run Eira. But it does not need to take up the toolbar while it is not in use. William chose to have it rest as a magnifying glass.

**What changed.**

1. **A new piece, `CollapsingSearchField`, in a new file `CollapsingSearch.swift`.** Mac only. It is a magnifying glass button that opens into a box to type in.
   - *Why not Apple's own.* SwiftUI's `.searchable` puts a wide box in a Mac toolbar for good. Apple's shrinking version, `.searchToolbarBehavior(.minimize)`, is marked as not available on a Mac in the macOS 27.2 kit (read from the kit's own list on the Mac, 14 November 2026).
   - *How it behaves.* Click the glass, or press Command-F, and the box opens with the cursor in it. A cross appears once there are words, and empties the box. Escape empties and closes. Clicking away from an empty box closes it. A box with words in it stays open, so it is always plain why the list is short. The glass pressed again with nothing typed closes the box.
   - *How the code holds it.* Two values: `open` (is the box showing) and `typing` (is the cursor in it). The words themselves are not kept here. They are a `@Binding` to the screen's own filter, exactly as with `.searchable`, so nothing about how plants are matched has changed.
2. **`PlantLibraryView.swift`.** On a Mac the `.searchable` line is fenced off with `#if os(iOS)` and the new piece is added to the toolbar, after the Garden data button, with a `ToolbarSpacer(.fixed)` between so each has its own piece of glass. **The iPhone and iPad are unchanged.**
3. **A checking aid.** `-plantsSearch apple` starts the Plants screen with "apple" already typed (`PlantFilter.fromLaunchArguments`). One logic test added for it.

**Not done.** The Year page, Species, Seed and Sightings still have the wide box. The same piece would fit each of them in a line or two.

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

**In `main` since 11:20**, by way of the branch `eira-corrections`. Built for the Mac and the simulator as r23, with no errors. 457 logic tests passed then. Seen in the simulator in light and dark (`shots/corr-*.png` on the Mac). **Tried with Apple's model and the trained Qwen through the test sheet's section G (knowledge base, doc 32). Not yet tried by hand.**

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

4. **A new sheet, Corrections, in the chat's Options menu** (`EiraCorrectionsView`). Every correction, newest first, with the question it answered, when it was kept and a Remove button. From the eleventh on, each is marked "only when a question touches on it" (see the section above on handing corrections over). `@Query` reads the list from the database and keeps it current, so a removed card goes without the screen being told.

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
