//
//  BackupService.swift
//  Windfall
//
//  A complete copy of everything, as one JSON file.
//
//  Why this exists even with CloudKit and a spreadsheet behind it: sync
//  propagates mistakes as faithfully as it propagates data. Delete a
//  year of plantings by accident and CloudKit will helpfully remove them
//  from all three devices. A dated file you keep somewhere else is the
//  only thing that protects against that.
//
//  Photos are excluded by choice — they would make the file enormous and
//  they are already in iCloud Photos. This is the records.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Transfer shapes

/// Plain structs rather than the models themselves, so the file format
/// stays stable even when the SwiftData schema changes. Restoring an old
/// backup into a newer app should still work.
private struct Backup: Codable {
    /// 2 added gardens, features and the measurements of each bed. The new
    /// parts are optional, so a version 1 file still restores.
    var version = 2
    var created = Date.now
    var gardens: [GardenDTO]?
    var features: [FeatureDTO]?
    var beds: [BedDTO] = []
    var plants: [PlantDTO] = []
    var plantings: [PlantingDTO] = []
    var harvests: [HarvestDTO] = []
    var surveys: [SurveyDTO] = []
    var observations: [ObservationDTO] = []
    var diary: [DiaryDTO] = []
    var frosts: [FrostDTO] = []
}

private struct BedDTO: Codable {
    var id: UUID, name: String, site: String, order: Int
    var raised: Bool, hugel: Bool
    var sections: [SectionDTO]
    var retiredAt: Date?
    // Where the bed is on the plan and how big it is. Missing from files
    // made before version 2.
    var x: Double?, y: Double?, length: Double?, width: Double?
    var rotation: Double?, height: Double?
}
private struct SectionDTO: Codable { var id: UUID, label: String, order: Int, length: Double? }

private struct GardenDTO: Codable {
    var id: UUID, key: String, name: String, order: Int
    var width: Double?, depth: Double?, topFaces: Double
    var slopeDown: Double?, steepness: String?, soil: String?
    var latitude: Double?, longitude: Double?
    var notes: String?, retiredAt: Date?
}

private struct FeatureDTO: Codable {
    var id: UUID, name: String, kind: String, site: String
    var x: Double, y: Double, length: Double, width: Double
    var rotation: Double, height: Double, blocksLight: Bool
    var notes: String?, removedAt: Date?
}

private struct PlantDTO: Codable {
    var id: UUID, commonName: String
    var latinName: String?, variety: String?, group: String?
    var sowIndoors: String?, sowOutdoors: String?, harvest: String?
    var notes: String?
}

private struct PlantingDTO: Codable {
    var id: UUID, plantID: UUID?, sectionIDs: [UUID]
    var round: Int?, sown: Date?, germinated: Date?, plantedOut: Date?
    var quantitySown: Int?, quantitySurvived: Int?, status: String, notes: String?
}

private struct HarvestDTO: Codable {
    var id: UUID, plantingID: UUID?, date: Date
    var quantity: Double, unit: String, destination: String?, notes: String?
}

private struct SurveyDTO: Codable {
    var id: UUID, scheme: String, started: Date, duration: Int?
    var targetPlant: String?, floralUnits: Int?, gridRef: String?
    var temperature: Double?, sky: String?, dry: Bool, windy: Bool
    var recorder: String?, submitted: Bool, notes: String?
    var tallies: [TallyDTO]
}
private struct TallyDTO: Codable { var group: String, quantity: Int }

private struct ObservationDTO: Codable {
    var id: UUID, observed: Date
    var commonName: String?, scientificName: String?, confirmedID: String?
    var quantity: Int?, lifeStage: String?, plantName: String?, interaction: String?
    var gridRef: String?, precision: Int, recorder: String?
    var submitted: Bool, notes: String?
}

private struct DiaryDTO: Codable {
    var id: UUID, date: Date, title: String?, body: String
    var scope: String, weather: String?, temperature: Double?, tags: [String]
}

private struct FrostDTO: Codable {
    var id: UUID, date: Date, kind: String, minimum: Double?
}

// MARK: - Service

@Observable
@MainActor
final class BackupService {

    var lastError: String?
    var lastMessage: String?
    var isWorking = false

    // MARK: Export

    func export(from context: ModelContext) throws -> URL {
        isWorking = true
        defer { isWorking = false }

        var backup = Backup()

        backup.beds = (try context.fetch(FetchDescriptor<Bed>())).map { bed in
            BedDTO(id: bed.id, name: bed.name, site: bed.siteRaw,
                   order: bed.displayOrder, raised: bed.isRaised,
                   hugel: bed.hasHugelkultur,
                   sections: bed.orderedSections.map {
                       SectionDTO(id: $0.id, label: $0.label, order: $0.displayOrder,
                                  length: $0.lengthMetres)
                   },
                   retiredAt: bed.retiredAt,
                   x: bed.originX, y: bed.originY,
                   length: bed.lengthMetres, width: bed.widthMetres,
                   rotation: bed.rotationDegrees, height: bed.heightMetres)
        }

        backup.gardens = (try context.fetch(FetchDescriptor<Garden>())).map { garden in
            GardenDTO(id: garden.id, key: garden.siteKey, name: garden.name,
                      order: garden.displayOrder,
                      width: garden.widthMetres, depth: garden.depthMetres,
                      topFaces: garden.topFacesDegrees,
                      slopeDown: garden.slopeDownDegrees,
                      steepness: garden.slopeSteepnessRaw, soil: garden.soilRaw,
                      latitude: garden.latitude, longitude: garden.longitude,
                      notes: garden.notes, retiredAt: garden.retiredAt)
        }

        backup.features = (try context.fetch(FetchDescriptor<GardenFeature>())).map { feature in
            FeatureDTO(id: feature.id, name: feature.name, kind: feature.kindRaw,
                       site: feature.siteRaw,
                       x: feature.originX, y: feature.originY,
                       length: feature.lengthMetres, width: feature.widthMetres,
                       rotation: feature.rotationDegrees, height: feature.heightMetres,
                       blocksLight: feature.blocksLight,
                       notes: feature.notes, removedAt: feature.removedAt)
        }

        backup.plants = (try context.fetch(FetchDescriptor<Plant>())).map { plant in
            PlantDTO(id: plant.id, commonName: plant.commonName,
                     latinName: plant.latinName, variety: plant.variety,
                     group: plant.group,
                     sowIndoors: plant.sowIndoorsMonthsText,
                     sowOutdoors: plant.sowOutdoorsMonthsText,
                     harvest: plant.harvestMonthsText,
                     notes: plant.notes)
        }

        backup.plantings = (try context.fetch(FetchDescriptor<Planting>())).map { planting in
            PlantingDTO(id: planting.id, plantID: planting.plant?.id,
                        sectionIDs: (planting.sections ?? []).map(\.id),
                        round: planting.successionRound,
                        sown: planting.dateSown, germinated: planting.dateGerminated,
                        plantedOut: planting.datePlantedOut,
                        quantitySown: planting.quantitySown,
                        quantitySurvived: planting.quantitySurvived,
                        status: planting.statusRaw, notes: planting.notes)
        }

        backup.harvests = (try context.fetch(FetchDescriptor<Harvest>())).map { harvest in
            HarvestDTO(id: harvest.id, plantingID: harvest.planting?.id,
                       date: harvest.date, quantity: harvest.quantity,
                       unit: harvest.unitRaw, destination: harvest.destinationRaw,
                       notes: harvest.notes)
        }

        backup.surveys = (try context.fetch(FetchDescriptor<Survey>())).map { survey in
            SurveyDTO(id: survey.id, scheme: survey.schemeRaw,
                      started: survey.startedAt, duration: survey.durationSeconds,
                      targetPlant: survey.targetPlantName,
                      floralUnits: survey.floralUnitCount,
                      gridRef: survey.gridReference,
                      temperature: survey.temperatureC, sky: survey.skyConditionRaw,
                      dry: survey.isDry, windy: survey.isWindy,
                      recorder: survey.recorderName, submitted: survey.submitted,
                      notes: survey.notes,
                      tallies: (survey.tallies ?? []).map {
                          TallyDTO(group: $0.groupName, quantity: $0.quantity)
                      })
        }

        backup.observations = (try context.fetch(FetchDescriptor<WildlifeObservation>())).map {
            ObservationDTO(id: $0.id, observed: $0.observedAt,
                           commonName: $0.commonName, scientificName: $0.scientificName,
                           confirmedID: $0.confirmedID, quantity: $0.quantity,
                           lifeStage: $0.lifeStage, plantName: $0.associatedPlantName,
                           interaction: $0.interaction, gridRef: $0.gridReference,
                           precision: $0.gridPrecisionMetres, recorder: $0.recorderName,
                           submitted: $0.submittedToIRecord, notes: $0.notes)
        }

        backup.diary = (try context.fetch(FetchDescriptor<DiaryEntry>())).map {
            DiaryDTO(id: $0.id, date: $0.date, title: $0.title, body: $0.body,
                     scope: $0.scopeRaw, weather: $0.weatherRaw,
                     temperature: $0.temperatureC, tags: $0.tags)
        }

        backup.frosts = (try context.fetch(FetchDescriptor<FrostRecord>())).map {
            FrostDTO(id: $0.id, date: $0.date, kind: $0.kindRaw,
                     minimum: $0.minimumTemperatureC)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(backup)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("windfall-backup-\(formatter.string(from: .now)).json")

        try data.write(to: url, options: .atomic)

        let counts = [
            "\(backup.plants.count) plants",
            "\(backup.plantings.count) sowings",
            "\(backup.harvests.count) harvests",
            "\(backup.surveys.count) surveys",
            "\(backup.observations.count) sightings"
        ]
        lastMessage = counts.joined(separator: ", ")

        return url
    }

    // MARK: Import

    /// Restores anything missing. Never deletes and never overwrites —
    /// records already present are skipped by id, so a restore can't
    /// undo work done since the backup was taken.
    func restore(from url: URL, into context: ModelContext) throws {
        isWorking = true
        defer { isWorking = false }

        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "Windfall", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't open that file."])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)

        var restored = 0

        // Plants first — plantings point at them.
        let existingPlants = Set((try context.fetch(FetchDescriptor<Plant>())).map(\.id))
        var plantsByID: [UUID: Plant] = [:]
        for plant in try context.fetch(FetchDescriptor<Plant>()) { plantsByID[plant.id] = plant }

        for dto in backup.plants where !existingPlants.contains(dto.id) {
            let plant = Plant(commonName: dto.commonName)
            plant.id = dto.id
            plant.latinName = dto.latinName
            plant.variety = dto.variety
            plant.group = dto.group
            plant.sowIndoorsMonthsText = dto.sowIndoors
            plant.sowOutdoorsMonthsText = dto.sowOutdoors
            plant.harvestMonthsText = dto.harvest
            plant.notes = dto.notes
            context.insert(plant)
            plantsByID[dto.id] = plant
            restored += 1
        }

        // Gardens. A garden is matched by its key, not its id, because a
        // fresh copy of the app makes its own two starting gardens. If the
        // one already here has never been filled in, the backup's details
        // are copied onto it. If it has, it is left alone.
        var gardensByKey: [String: Garden] = [:]
        for garden in try context.fetch(FetchDescriptor<Garden>()) { gardensByKey[garden.siteKey] = garden }

        for dto in backup.gardens ?? [] {
            let garden: Garden
            if let existing = gardensByKey[dto.key] {
                let untouched = existing.widthMetres == nil && existing.depthMetres == nil
                    && existing.latitude == nil && existing.soilRaw == nil
                    && existing.slopeDownDegrees == nil && existing.topFacesDegrees == 0
                guard untouched else { continue }
                garden = existing
            } else {
                garden = Garden(name: dto.name, siteKey: dto.key)
                garden.id = dto.id
                context.insert(garden)
                gardensByKey[dto.key] = garden
            }
            garden.name = dto.name
            garden.displayOrder = dto.order
            garden.widthMetres = dto.width
            garden.depthMetres = dto.depth
            garden.topFacesDegrees = dto.topFaces
            garden.slopeDownDegrees = dto.slopeDown
            garden.slopeSteepnessRaw = dto.steepness
            garden.soilRaw = dto.soil
            garden.latitude = dto.latitude
            garden.longitude = dto.longitude
            garden.notes = dto.notes
            garden.retiredAt = dto.retiredAt
            restored += 1
        }

        // Sheds, paths, trees and the rest
        let existingFeatures = Set((try context.fetch(FetchDescriptor<GardenFeature>())).map(\.id))
        for dto in backup.features ?? [] where !existingFeatures.contains(dto.id) {
            let feature = GardenFeature(name: dto.name, siteKey: dto.site)
            feature.id = dto.id
            feature.kindRaw = dto.kind
            feature.originX = dto.x
            feature.originY = dto.y
            feature.lengthMetres = dto.length
            feature.widthMetres = dto.width
            feature.rotationDegrees = dto.rotation
            feature.heightMetres = dto.height
            feature.blocksLight = dto.blocksLight
            feature.notes = dto.notes
            feature.removedAt = dto.removedAt
            context.insert(feature)
            restored += 1
        }

        // Beds and sections
        let existingBeds = Set((try context.fetch(FetchDescriptor<Bed>())).map(\.id))
        var sectionsByID: [UUID: BedSection] = [:]
        for section in try context.fetch(FetchDescriptor<BedSection>()) {
            sectionsByID[section.id] = section
        }

        for dto in backup.beds where !existingBeds.contains(dto.id) {
            let bed = Bed(name: dto.name)
            bed.id = dto.id
            bed.siteRaw = dto.site
            bed.displayOrder = dto.order
            bed.isRaised = dto.raised
            bed.hasHugelkultur = dto.hugel
            bed.retiredAt = dto.retiredAt
            bed.originX = dto.x ?? 0
            bed.originY = dto.y ?? 0
            bed.lengthMetres = dto.length
            bed.widthMetres = dto.width
            bed.rotationDegrees = dto.rotation ?? 0
            bed.heightMetres = dto.height
            context.insert(bed)

            for sectionDTO in dto.sections {
                let section = BedSection()
                section.id = sectionDTO.id
                section.label = sectionDTO.label
                section.displayOrder = sectionDTO.order
                if let length = sectionDTO.length { section.lengthMetres = length }
                section.bed = bed
                bed.sections?.append(section)
                sectionsByID[sectionDTO.id] = section
            }
            restored += 1
        }

        // Plantings
        let existingPlantings = Set((try context.fetch(FetchDescriptor<Planting>())).map(\.id))
        var plantingsByID: [UUID: Planting] = [:]
        for planting in try context.fetch(FetchDescriptor<Planting>()) {
            plantingsByID[planting.id] = planting
        }

        for dto in backup.plantings where !existingPlantings.contains(dto.id) {
            let planting = Planting()
            planting.id = dto.id
            planting.plant = dto.plantID.flatMap { plantsByID[$0] }
            planting.sections = dto.sectionIDs.compactMap { sectionsByID[$0] }
            planting.successionRound = dto.round
            planting.dateSown = dto.sown
            planting.dateGerminated = dto.germinated
            planting.datePlantedOut = dto.plantedOut
            planting.quantitySown = dto.quantitySown
            planting.quantitySurvived = dto.quantitySurvived
            planting.statusRaw = dto.status
            planting.notes = dto.notes
            context.insert(planting)
            plantingsByID[dto.id] = planting
            restored += 1
        }

        // Harvests
        let existingHarvests = Set((try context.fetch(FetchDescriptor<Harvest>())).map(\.id))
        for dto in backup.harvests where !existingHarvests.contains(dto.id) {
            let harvest = Harvest()
            harvest.id = dto.id
            harvest.planting = dto.plantingID.flatMap { plantingsByID[$0] }
            harvest.date = dto.date
            harvest.quantity = dto.quantity
            harvest.unitRaw = dto.unit
            harvest.destinationRaw = dto.destination
            harvest.notes = dto.notes
            context.insert(harvest)
            restored += 1
        }

        // Surveys
        let existingSurveys = Set((try context.fetch(FetchDescriptor<Survey>())).map(\.id))
        for dto in backup.surveys where !existingSurveys.contains(dto.id) {
            let survey = Survey()
            survey.id = dto.id
            survey.schemeRaw = dto.scheme
            survey.startedAt = dto.started
            survey.durationSeconds = dto.duration
            survey.targetPlantName = dto.targetPlant
            survey.floralUnitCount = dto.floralUnits
            survey.gridReference = dto.gridRef
            survey.temperatureC = dto.temperature
            survey.skyConditionRaw = dto.sky
            survey.isDry = dto.dry
            survey.isWindy = dto.windy
            survey.recorderName = dto.recorder
            survey.submitted = dto.submitted
            survey.notes = dto.notes
            context.insert(survey)

            for tallyDTO in dto.tallies {
                let tally = SurveyTally(groupName: tallyDTO.group, quantity: tallyDTO.quantity)
                tally.survey = survey
                survey.tallies?.append(tally)
            }
            restored += 1
        }

        // Sightings
        let existingObservations = Set((try context.fetch(FetchDescriptor<WildlifeObservation>())).map(\.id))
        for dto in backup.observations where !existingObservations.contains(dto.id) {
            let observation = WildlifeObservation()
            observation.id = dto.id
            observation.observedAt = dto.observed
            observation.commonName = dto.commonName
            observation.scientificName = dto.scientificName
            observation.confirmedID = dto.confirmedID
            observation.quantity = dto.quantity
            observation.lifeStage = dto.lifeStage
            observation.associatedPlantName = dto.plantName
            observation.interaction = dto.interaction
            observation.gridReference = dto.gridRef
            observation.gridPrecisionMetres = dto.precision
            observation.recorderName = dto.recorder
            observation.submittedToIRecord = dto.submitted
            observation.notes = dto.notes
            context.insert(observation)
            restored += 1
        }

        // Diary
        let existingDiary = Set((try context.fetch(FetchDescriptor<DiaryEntry>())).map(\.id))
        for dto in backup.diary where !existingDiary.contains(dto.id) {
            let entry = DiaryEntry(body: dto.body)
            entry.id = dto.id
            entry.date = dto.date
            entry.title = dto.title
            entry.scopeRaw = dto.scope
            entry.weatherRaw = dto.weather
            entry.temperatureC = dto.temperature
            entry.tags = dto.tags
            context.insert(entry)
            restored += 1
        }

        lastMessage = restored == 0
            ? "Nothing new to restore — everything in that file is already here."
            : "\(restored) records restored."
    }
}

// MARK: - Backup screen

struct BackupView: View {

    @Environment(\.modelContext) private var context

    @State private var service = BackupService()
    @State private var exportedFile: URL?
    @State private var showingImporter = false

    var body: some View {
        Form {
            Section {
                Button {
                    do {
                        exportedFile = try service.export(from: context)
                        service.lastError = nil
                    } catch {
                        service.lastError = error.localizedDescription
                    }
                } label: {
                    Label("Create a backup", systemImage: "arrow.down.doc")
                }

                if let exportedFile {
                    ShareLink(item: exportedFile) {
                        Label("Save it somewhere", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Everything except photos, as one JSON file. Photos are left out because they'd make it enormous and they're already in iCloud Photos.")
            }

            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label("Restore from a backup", systemImage: "arrow.up.doc")
                }
            } footer: {
                Text("Restoring only adds what's missing. It never deletes or overwrites, so it can't undo anything you've done since the backup was made.")
            }

            if let message = service.lastMessage {
                Section {
                    Label(message, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }

            if let error = service.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Label("Sync copies mistakes as faithfully as it copies data. A dated file kept elsewhere is the only thing that protects against deleting a year of records by accident.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Backup")
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    try service.restore(from: url, into: context)
                    service.lastError = nil
                } catch {
                    service.lastError = error.localizedDescription
                }
            case .failure(let error):
                service.lastError = error.localizedDescription
            }
        }
    }
}
