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
