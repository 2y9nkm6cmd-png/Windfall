//
//  CardAdds.swift
//  Windfall
//
//  What the Add button does on each of Eira's cards that makes a
//  record: a job, a harvest and a sowing.
//
//  Why this file exists. Until 20 November 2026 each card wrote its
//  record inside its own screen code (JobViews.swift and
//  JournalOfferCards.swift). The test run (EiraTestRun.swift) now
//  presses Add with nobody at the screen, and it must make exactly the
//  record the button makes, or the test would be testing something the
//  app does not do. So the making is here, once, and both the cards and
//  the test run call it.
//
//  Nothing here draws anything, so it can be checked without a screen.
//  Each function is handed the values as they stand on the card when
//  Add is pressed, makes the record, hands it to the database and gives
//  back the line Eira says afterwards.
//

import Foundation
import SwiftData

enum CardAdd {

    // MARK: A job

    /// "Add a job?" (JobOfferCard in JobViews.swift.)
    ///
    /// - `title`: the job's words as the card shows them.
    /// - `from`, `by`: its first and last day, or both nil for whenever.
    /// - `siteKey`: the garden it is for, or nil.
    /// - `said`: the sentence it was read from, kept with the job.
    ///
    /// Returns the job and the line Eira says.
    @discardableResult
    static func job(title: String, from: Date?, by: Date?, siteKey: String?, said: String,
                    into context: ModelContext, today: Date = .now) -> (job: GardenJob, line: String) {
        let job = GardenJob(title: title)
        job.dueFrom = from
        job.dueBy = by
        job.siteKey = siteKey
        job.saidAs = said
        // `insert` hands the new record to the database.
        context.insert(job)
        return (job, GardenJobs.addedLine(title: title, span: JobDays(from: from, by: by), today: today))
    }

    // MARK: A harvest

    /// "Add a harvest?" (HarvestOfferCard in JournalOfferCards.swift.)
    ///
    /// - `planting`: the sowing or planting chosen on the card. Nil when
    ///   the plant has none on record; then one is made, as the card
    ///   says it will be.
    ///
    /// Returns the harvest and the line Eira says.
    @discardableResult
    static func harvest(of plant: Plant, from planting: Planting?, amount: Double, unit: HarvestUnit,
                        destination: HarvestDestination, on date: Date,
                        into context: ModelContext) -> (harvest: Harvest, line: String) {
        // No sowing or planting on record, as with a tree that was here
        // before the app. One is made, marked as cropping, with a note
        // saying where it came from. See `Planting.putOnRecord`.
        let source = planting ?? Planting.putOnRecord(plant, from: "the journal", in: context)

        let harvest = Harvest()
        harvest.date = date
        harvest.quantity = amount
        harvest.unit = unit
        harvest.destination = destination
        harvest.planting = source
        source.harvests?.append(harvest)
        if source.status == .growing || source.status == .plantedOut {
            source.status = .harvesting
        }
        return (harvest, "Added a harvest: \(plainNumber(amount)) \(unit.displayName) of \(plant.displayName).")
    }

    // MARK: A sowing

    /// "Add a sowing?" (SowingOfferCard in JournalOfferCards.swift.)
    ///
    /// - `bed`: the bed chosen on the card. The whole bed is used, since
    ///   the words do not say which part; the sections can be put right
    ///   from the sowing's own page.
    /// - `quantity`: how many, or nil if the box was left empty.
    ///
    /// Returns the sowing and the line Eira says.
    @discardableResult
    static func sowing(of plant: Plant, in bed: Bed?, sownWhere: SowingLocation, quantity: Int?,
                       on date: Date, into context: ModelContext,
                       calendar: Calendar = .current) -> (planting: Planting, line: String) {
        let planting = Planting()
        planting.plant = plant
        planting.dateSown = date
        planting.sowingLocation = sownWhere
        planting.status = .sown
        planting.quantitySown = quantity

        // If it has been sown before this year, this is the next round,
        // as it would be from the sowing form.
        let year = calendar.component(.year, from: date)
        let sownThisYear = (plant.plantings ?? []).filter { earlier in
            earlier.dateSown.map { calendar.component(.year, from: $0) == year } ?? false
        }
        planting.successionRound = sownThisYear.isEmpty ? nil : sownThisYear.count + 1

        if let bed {
            planting.sections = bed.orderedSections
        }
        context.insert(planting)
        return (planting, "Added a sowing: \(plant.displayName)\(bed.map { " in \($0.name)" } ?? "").")
    }

    // MARK: Words

    /// A number as it would be typed: "50", not "50.0".
    static func plainNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
