# Windfall — Project Summary

*Updated 15 August 2026*

## What it is

A multiplatform Apple app (iPhone, iPad, Mac) for planning, tracking and recording two gardens — a permaculture garden and an allotment — with an offline AI naturalist assistant built in.

Two halves sharing one data layer:

- **The garden manager** — what to plant, where, when, and how it did.
- **Eira** — an on-device assistant for identifying plants and wildlife and answering questions about them, working without a signal.

---

## Settled decisions

| Question | Decision |
|---|---|
| Persistence | **SwiftData** |
| Sync | **CloudKit**, via an existing iCloud subscription |
| Platforms | **Multiplatform target** — iPhone, iPad, Mac |
| Spreadsheet | **Google Sheets** (Numbers has no usable API) |
| Vision | **In from the start** |
| Distribution | **Apple Developer Programme** — required for iCloud and entitlements |
| Public release | Deferred, but hard refusal rules if it happens |
| Scope | Garden and natural history only; no teaching content |

### Who owns what

- **Google Sheets** — plant reference data, and the observations log.
- **CloudKit** — observations, chats, notes, app state.

Bidirectional: edits made in the app write back to Sheets.

### CloudKit constraints to honour from day one

Every SwiftData property must be optional or have a default value, and unique constraints are not allowed. Cheap now, painful to retrofit.

---

## Part 1 — The garden manager

*Specified in full; build started.*

### Data foundation

- Google Sheets API v4, shared Google account, OAuth 2.0 with Keychain.
- SwiftData for local storage and CloudKit sync.
- Two schemas kept separate but viewable together: the allotment sheet (~40 columns, seed and sowing focused) and the permaculture sheet (~70 columns in eight named category groups — Growth Patterns, Growth Habits, Permaculture Category, Sowing from Seed, Growth Constraints, Human Management, Ecological Interactions, Description).
- Those eight groupings preserved as collapsible sections in the plant detail view.
- Additional sheets imported: allotment planting schedule, companion planting matrix, plants to buy, previously owned plants.

### Features

| Feature | Description |
|---|---|
| Plant browser | Search and browse both databases with sowing dates |
| Planting schedule | Calendar view of what to sow and when |
| Garden map | Visual layout showing named zones and permaculture layers |
| Progress tracking | Sow date, germination, transplant, harvest with yield |
| Photo timeline | Plant life cycles over a season |
| Tree growth | Measurements tracked over years |
| Companion matrix | Surfaced in plant details and as a standalone search |
| Plants to buy | Editable in-app: add, mark purchased, promote to main list |

### Stack

SwiftUI, SwiftData, CloudKit, Sheets API v4, OAuth 2.0 with Keychain, PhotosUI, Swift Charts, PencilKit, MLX Swift, SpeechAnalyzer, AVFoundation.

Bundle ID `com.54brookroad.Windfall`. Google Cloud project created, APIs enabled, credentials generated. Xcode project set up with GoogleSignIn-iOS 9.1.0 and five Swift files written — mid-way through Phase 1.

---

## Part 2 — Garden structure and records

### Beds and sections

Beds are **entities, not text**. Each has a stable identity and a separate display label, so renumbering, resizing or turning the layout through ninety degrees changes the label and leaves five years of history attached to the right ground.

- **Allotment**: four beds (extendable), each divided into 1.2 m sections lettered A–F.
- Beds carry geometry — origin, length, width, rotation — so the layout is editable data driving the map view rather than something hardcoded.
- Dismantling a bed sets `retiredAt` rather than deleting it.
- A planting occupies a **set** of sections, since carrots might run 3B to 3D.

This unlocks **crop rotation warnings**: what family grew here last year, and a flag when brassicas are about to go back into the same ground. The existing Group column is what rotation needs.

### Plant and Planting

The central split. **Plant** is reference data — Latin name, hardiness, germination time — true wherever it grows, stored once. **Planting** is an instance: this sowing, in these sections, on this date, with this outcome.

Carrots sown every 7–14 days become one Plant and a dozen Plantings, distinguished by succession round. Plants to Buy and Previously Owned share the same 69-column schema as the main permaculture sheet, so they are one model with a status enum, not three models.

### Harvests

**One row per picking**, not a total — courgettes get harvested thirty times. Date, quantity, unit, and destination: eaten, stored, frozen, preserved, given away, sold, seed saved, composted, lost.

That last field is the quietly useful one. It is the difference between "we grew 14 kg of beans" and "we grew 14 kg and composted 4 of them", and it is the join a future preserving-and-recipes module would consume.

### Phenology

First leaf, first flower, full flower, first fruit, first ripe fruit, leaf fall, dieback, bolted.

Bloom dates set alongside pollinator counts show whether what is flowering matches what is flying. Also submittable to Nature's Calendar in its own right.

### Pest and disease events

Dated events recording what actually happened, as opposed to the Plant's static list of what it might get. Kind, severity, treatment, outcome, resolution date.

### Seed stock and viability

Packets with supplier, year, use-by, quantity and storage. Germination tests recorded, and viability inferred from how actual sowings performed. Feeds a suggested sowing multiplier — sow more thickly as a packet declines.

### Frost and weather

Last spring frost and first autumn frost drive every sowing decision, and turn "the beans were poor" into "the beans were poor because of the frost on the 12th". Weather snapshots also supply the conditions FIT Counts require.

---

## Part 3 — Wildlife recording

The layer that connects the garden manager to Eira.

Generalised beyond pollinators. Two record shapes, deliberately separate.

A **Survey** is any structured, repeatable count following a published protocol. An **Observation** is a single sighting of anything — insect, bird, mammal, amphibian, mollusc, fungus. Each scheme supplies its own group vocabulary and duration, so adding a protocol later needs no schema change.

### Type 1 — Survey (structured, submittable)

**FIT Count**

Follows the UK Pollinator Monitoring Scheme's **Flower-Insect Timed Count** protocol, which is the established national method for exactly the question being asked: what visits which plant, and how many.

The protocol:

- One target flower species, a 50 × 50 cm patch.
- Count the floral units in the patch first.
- Ten-minute timer; count every insect that lands on the target flowers.
- Allocate each to one of ten broad insect groups — **not** to species.
- Season is 1 April to 30 September, dry, at least 13°C in sun or 15°C in cloud.

This maps neatly onto the vision tiers: PoMS only asks for broad groups, so the on-device model is sufficient for the structured survey. Species-level identification is a separate, optional enrichment.

**Earthworm count** — the `#60minworms` protocol. A 20 × 20 × 20 cm pit, soil hand-sorted for five minutes, worms sorted into three ecological groups: epigeic, anecic, endogeic. Repeated across several pits, hence a pit number on each record.

Restricted to spring and autumn. Dig in high summer or hard frost and you undercount badly, which would make year-on-year comparison meaningless.

Data model: a **count is a parent record** — place, date, time, conditions, duration — with group tallies hanging off it. Not a flat list of sightings. A count of zero is a valid and meaningful result; absence is data.

Species-level identifications ride on observations attached to the survey. Tallies stay at group level, because the protocols require it. A `TaxonMapper` rolls a species up into its scheme group via family and genus — identify *Eristalis tenax*, GBIF returns Syrphidae, the app knows that is "Hoverflies".

### Type 2 — Casual observation

- Photo, with location and timestamp from EXIF
- Provisional identification and confidence
- Confirmed identification
- **Link to the plant record** — a real reference, not free text
- Count, life stage, notes

### Reminders

Not quarterly — the season and the weather decide. The app should prompt when it's within the recording season and conditions are suitable, and nudge if a plant hasn't been counted for a while. A weather lookup makes this close to automatic.

### Wildlife sheet

Both types append to a new sheet in the existing spreadsheet, giving a long-run record of what visits the garden and in what numbers.

**Design the columns to match the import templates exactly** — the PoMS form for counts, iRecord's occurrence template for casual records — so export is free rather than a later conversion job.

### iRecord export

No open submission API — Indicia's requires app authorisation configured in BRC's warehouse. The supported route is spreadsheet upload.

iRecord accepts .xlsx or .csv, one row per record, minimum five columns: **species name, grid reference, date, recorder, stage**.

Two things to build around:

1. It wants an **OS grid reference**, not lat/long — needs WGS84 to OSGB36 conversion from the photo's GPS.
2. **If one record fails, the whole file is rejected** — so validate before export.

Result: a one-tap validated export, uploaded manually. Roughly ten seconds per batch.

---

## Part 4 — Eira, the assistant

*Not started.*

### Inference

- **MLX Swift** on-device. iPad Mini 7 and iPhone 15 Pro are both A17 Pro with 8GB — comfortable with a 4-bit 3–4B model.
- A **`Backend` protocol** with two implementations: local MLX, and a remote OpenAI-compatible endpoint pointing at the MacBook over Tailscale. Heavier models at home, on-device fallback in the field.
- Requires the Increased Memory Limit entitlement. Cannot be tested in the Simulator.
- Model management in v1: see sizes, delete, re-download.

### Vision — three tiers

Identification degrades gracefully rather than pretending to a precision it hasn't got.

| Tier | Where | What it does |
|---|---|---|
| Coarse | Phone / iPad, on-device VLM | Insect group and context — "a hoverfly on fennel" |
| Finer | Mac, larger VLM over Tailscale | Field marks, narrowing, reasoning over candidates |
| Species | iNaturalist CV, online | Actual species-level classification |

Revisit the phone tier as device RAM grows.

Honest limit worth holding on to: many UK invertebrates cannot be identified to species from a photograph at all, by any model or any person. The app should be able to say so.

### Voice — push-to-talk

- **SpeechAnalyzer / SpeechTranscriber**, fully on-device, no API key.
- Volatile results enabled so text appears live as you speak.
- Mapped to the Action Button on the iPhone 15 Pro.
- App Intent so Siri can launch it hands-free.
- `AVSpeechSynthesizer` for replies; audio session ducking between record and speak.
- Asset availability checked and handled on first run.

### Reasoning display

- Stream parsed into two buffers, reasoning and answer, shown as a collapsible box.
- Delimiters configured **per model family**, not hardcoded.
- Collapsed by default.
- Tokens/sec and time-to-first-token captured alongside.

### Lookup — two separate tools

- **`lookup_species`** — POWO, GBIF, NBN Atlas, iNaturalist. Free, authoritative, mostly keyless. Also does **name normalisation**: turns whatever the model says into an accepted scientific name.
- **`search_web`** — self-hosted SearXNG on the MacBook over Tailscale. No key, no bill.
- A manual "look this up" button forces either call, since small models are unreliable about deciding when to use tools.

### Knowledge base

RAG over the book, notes and garden-corrections file. On-device embedding model, chunks in SQLite, brute-force cosine similarity — no vector database needed at this size.

### Custom model — later

LoRA fine-tuning via `mlx-lm` on the MacBook, roughly 30 minutes per run at 16GB. Adapter fused and converted for on-device use.

Fine-tuning teaches **behaviour**, not facts — the ID output structure and register. Facts stay in RAG where they can be corrected without retraining. The corrections file doubles as the seed training set.

---

## Still open

1. **Photo storage.** Original plan was iCloud Drive with filename references in Sheets. CloudKit assets may now be simpler. Photos are the bulk of the storage.

2. **Recorder identity.** iRecord needs a recorder name and grid-reference precision per record — including how precisely to publish your own garden's location.

3. **Which models.** Settled by testing on-device, not by deciding in advance.

---

## Where the build has got to

**Done**

- Xcode project, bundle ID, Google Cloud credentials, GoogleSignIn 9.1.0
- Google sign-in and navigation, working on iOS and macOS
- The complete data layer — thirteen SwiftData models across three files:
  - `GardenStructure.swift` — Bed, BedSection, FrostRecord, WeatherSnapshot
  - `PlantModels.swift` — Plant, Planting, Harvest, PhenologyEvent, PestDiseaseEvent, SeedPacket
  - `WildlifeModels.swift` — Survey, SurveyTally, Observation, TaxonMapper
- `Windfall_New_Sheets.xlsx` — Plantings, FIT Counts, FIT Tallies, Wildlife Observations

**Next**

1. Confirm the model layer compiles on both platforms.
2. Enrol in the Apple Developer Programme, then switch CloudKit on.
3. Sheets import — read the two plant sheets into `Plant`.
4. Plant browser UI, with the eight collapsible category groups.
5. Bed and section setup, and the garden map view.
6. Planting, harvest and phenology entry.
7. Survey UI — FIT Count and worm count timers.
8. Export — grid reference conversion and validated iRecord output.
9. Local MLX chat with streaming and reasoning display.
10. Backend protocol, adding the Mac.
11. Vision, then voice.
12. Lookup tools, then the knowledge base.

Finish the Jan setup on the Mac alongside this. It is the working spec for Eira, and it generates the corrections data that later becomes training data.
