# Windfall — file manifest

*39 Swift files. Add every one to the Windfall target.*

## Order to add them

Dependencies flow downwards, so adding in this order means the compiler
always has what it needs. If you add everything at once instead, expect a
lot of errors that resolve themselves once the last file is in.

### 1 — Foundations (no dependencies)

| File | What it holds |
|---|---|
| `Parsing.swift` | Month, range and boolean parsers for the spreadsheet's free text |
| `OSGridReference.swift` | WGS84 → OS grid reference conversion |
| `GardenStructure.swift` | `Bed`, `BedSection`, `FrostRecord`, `WeatherSnapshot` |

### 2 — Data models

| File | What it holds |
|---|---|
| `PlantModels.swift` | `Plant`, `Planting`, `Harvest`, `PhenologyEvent`, `PestDiseaseEvent`, `SeedPacket` |
| `WildlifeModels.swift` | `Survey`, `SurveyTally`, `WildlifeObservation`, `TaxonMapper` |
| `FaunaModels.swift` | `Fauna`, `PlantFaunaLink`, `FlowerShape`, `Cascade` |
| `CompanionPlanting.swift` | `CompanionPair`, checker, companion views |
| `Journal.swift` | `DiaryEntry`, `Photo`, `TimelineEntry` protocol, `TimelineBuilder` |
| `KnowledgeBase.swift` | `KnowledgeDocument`, `KnowledgeChunk`, chunker, embedder |

### 3 — Services

| File | What it holds |
|---|---|
| `AuthenticationManager.swift` | Google sign-in, iOS and macOS |
| `LocationManager.swift` | CoreLocation wrapper, `GridReferenceField` |
| `WeatherService.swift` | Open-Meteo conditions, frost detection, `FrostRecordsView` |
| `SheetsService.swift` | Reading the spreadsheet |
| `SheetsWriteBack.swift` | Writing records back, `SyncView` |
| `ExportService.swift` | iRecord and PoMS CSV, `ExportView` |
| `BackupService.swift` | Full JSON backup and restore, `BackupView` |
| `NotificationService.swift` | Seasonal reminders, `NotificationSettingsView` |
| `VoiceInput.swift` | Push-to-talk, speech synthesis, `PushToTalkButton` |
| `SeedPacketScanner.swift` | Vision OCR, `SeedPacketScanView` |

### 4 — Eira

| File | What it holds |
|---|---|
| `EiraBackend.swift` | `EiraBackend` protocol, `RemoteBackend`, reasoning parser, metrics |
| `EiraTools.swift` | Tool definitions, `ToolRunner`, system prompt |
| `EiraChatView.swift` | Chat, reasoning box, model settings |
| `EiraVision.swift` | Photo identification, `IdentifyView` |

### 5 — Screens

| File | What it holds |
|---|---|
| `BedViews.swift` | Bed list and detail |
| `PlantLibraryView.swift` | Plant browser, detail, import |
| `PlantingViews.swift` | Sowings, harvests, phenology, problems |
| `SurveyViews.swift` | FIT Counts and earthworm counts |
| `ObservationViews.swift` | Wildlife sightings |
| `SeedViews.swift` | Seed packets, germination tests |
| `GardenMapView.swift` | Visual layout |
| `FaunaViews.swift` | Species reference, flower shape coverage, cascades |
| `JournalViews.swift` | Timeline, diary editor, photo thumbnails |
| `ChartsView.swift` | Yield, pollinators, flowering against flying |
| `SearchAndCalendar.swift` | Universal search, sowing calendar |
| `DashboardView.swift` | Today |

### 6 — App shell

| File | What it holds |
|---|---|
| `RootView.swift` | Signed in or not |
| `SignInView.swift` | Google button |
| `MainTabView.swift` | Five tabs, grouped menus, `SettingsView` |
| `WindfallApp.swift` | Entry point, SwiftData container |

---

## The schema

`WindfallApp.swift` must list all 22 model types. Missing one means it
silently isn't saved.

```swift
let schema = Schema([
    // Garden structure
    Bed.self, BedSection.self, FrostRecord.self, WeatherSnapshot.self,
    // Plants and growing
    Plant.self, Planting.self, Harvest.self, PhenologyEvent.self,
    PestDiseaseEvent.self, SeedPacket.self,
    // Wildlife
    Survey.self, SurveyTally.self, WildlifeObservation.self,
    // Reference data
    Fauna.self, PlantFaunaLink.self, FlowerShape.self, Cascade.self,
    CompanionPair.self,
    // Journal
    DiaryEntry.self, Photo.self,
    // Knowledge base
    KnowledgeDocument.self, KnowledgeChunk.self
])
```

---

## Info.plist keys

| Key | Type | Why |
|---|---|---|
| `GIDClientID` | String | Google sign-in. Without it the app crashes on the sign-in button. |
| `CFBundleURLTypes` | Array | Callback after Google sign-in |
| `NSPhotoLibraryUsageDescription` | String | Attaching photos to records |
| `NSLocationWhenInUseUsageDescription` | String | Grid references for records |
| `NSMicrophoneUsageDescription` | String | Push-to-talk |
| `NSSpeechRecognitionUsageDescription` | String | Transcribing speech |

---

## Setup, in order

1. Settings → your recorder name
2. Settings → Import plants from Sheets
3. Settings → Import reference data
4. Settings → Import companion planting
5. Garden → Beds → Set up the allotment
6. More → Reminders → turn on
7. More → Voice → allow microphone
8. Eira → Model settings → Mac's Tailscale address
9. More → Knowledge base → add your book and notes
10. More → Backup → create one before anything else

---

## Still to build

**Local MLX inference.** The `EiraBackend` protocol has two intended
implementations; only `RemoteBackend` exists. Local needs the Apple
Developer Programme for the increased-memory entitlement, and the MLX
Swift package added through SPM. Nothing above the protocol changes when
it lands.

**iNaturalist classifier.** The third vision tier. Their computer-vision
API is not openly published, so this needs investigating rather than
writing.

**Photo gallery.** Photos are stored and shown as thumbnails, but there's
no full-screen viewer.

**LoRA fine-tuning.** Deferred until the corrections file has accumulated
enough examples to be worth training on.
