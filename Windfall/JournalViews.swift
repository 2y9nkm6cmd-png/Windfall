//
//  JournalViews.swift
//  Windfall
//
//  The diary editor and the unified timeline.
//
//  New things here:
//
//  PhotosPicker    Apple's photo chooser. Gives back an opaque item that
//                  you load data from asynchronously — the picture is not
//                  handed over immediately.
//
//  .task           runs async work tied to a view's lifetime. Cancelled
//                  automatically when the view goes away, which is what
//                  stops a half-loaded photo writing into a dead view.
//
//  Multiple @Query properties in one view. The timeline needs seven,
//  because SwiftData can't query across a protocol.
//

import SwiftUI
import SwiftData
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Timeline

struct JournalTimelineView: View {

    // One query per record type. They all update independently.
    @Query(sort: [SortDescriptor(\DiaryEntry.date, order: .reverse)])
    private var diary: [DiaryEntry]

    @Query private var plantings: [Planting]
    @Query private var phenology: [PhenologyEvent]
    @Query private var harvests: [Harvest]
    @Query private var problems: [PestDiseaseEvent]
    @Query private var surveys: [Survey]
    @Query private var sightings: [WildlifeObservation]

    @Environment(\.modelContext) private var context

    @State private var kinds: Set<TimelineKind> = Set(TimelineKind.allCases)
    @State private var newEntry: DiaryEntry?

    private var items: [TimelineItem] {
        TimelineBuilder.build(
            diary: diary,
            plantings: plantings,
            phenology: phenology,
            harvests: harvests,
            problems: problems,
            surveys: surveys,
            sightings: sightings,
            kinds: kinds
        )
    }

    private var months: [(month: Date, items: [TimelineItem])] {
        TimelineBuilder.groupedByMonth(items)
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("Nothing recorded yet", systemImage: "book.closed")
                } description: {
                    Text("Diary entries, sowings, harvests and sightings all appear here together.")
                }
            }

            ForEach(months, id: \.month) { group in
                Section {
                    ForEach(group.items) { item in
                        TimelineRow(item: item)
                    }
                } header: {
                    Text(group.month, format: .dateTime.month(.wide).year())
                }
            }
        }
        .navigationTitle("Journal")
        .paperScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let entry = DiaryEntry()
                    context.insert(entry)
                    newEntry = entry
                } label: {
                    Label("New entry", systemImage: "square.and.pencil")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    ForEach(TimelineKind.allCases) { kind in
                        Toggle(isOn: Binding(
                            get: { kinds.contains(kind) },
                            set: { on in
                                if on { kinds.insert(kind) } else { kinds.remove(kind) }
                            }
                        )) {
                            Label(kind.displayName, systemImage: kind.symbolName)
                        }
                    }

                    Divider()

                    Button("Show everything") {
                        kinds = Set(TimelineKind.allCases)
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(item: $newEntry) { entry in
            DiaryEntryEditor(entry: entry)
        }
    }
}

// MARK: - Timeline row

private struct TimelineRow: View {

    let item: TimelineItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: item.kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(colour)
                    .frame(width: 18)

                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let detail = item.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 26)
            }

            if !item.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(item.photos) { photo in
                            PhotoThumbnail(photo: photo, size: 72)
                        }
                    }
                    .padding(.leading, 26)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var colour: Color {
        switch item.kind {
        case .diary:     return .brown
        case .planting:  return .green
        case .phenology: return .pink
        case .harvest:   return .orange
        case .problem:   return .red
        case .survey:    return .blue
        case .sighting:  return .purple
        }
    }
}

// MARK: - Photo thumbnail

struct PhotoThumbnail: View {

    let photo: Photo
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let image = loadedImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.secondary.opacity(0.15))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Prefers the thumbnail. Decoding full-size images in a scrolling
    /// list is the classic cause of stutter.
    private var loadedImage: Image? {
        let data = photo.thumbnailData ?? photo.imageData
        guard let data else { return nil }

        #if os(iOS)
        guard let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
        #elseif os(macOS)
        guard let ns = NSImage(data: data) else { return nil }
        return Image(nsImage: ns)
        #endif
    }
}

// MARK: - Diary editor

struct DiaryEntryEditor: View {

    @Bindable var entry: DiaryEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Bed.displayOrder)]) private var beds: [Bed]

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $entry.date, displayedComponents: .date)

                    TextField("Title (optional)", text: Binding(
                        get: { entry.title ?? "" },
                        set: { entry.title = $0.isEmpty ? nil : $0 }
                    ))
                } footer: {
                    if entry.titleIsGenerated {
                        Label("Heading written by Eira", systemImage: "sparkles")
                            .font(.caption)
                    }
                }

                Section("Entry") {
                    TextField("What happened in the garden?",
                              text: $entry.body, axis: .vertical)
                        .lineLimit(6...20)
                }

                Section("About") {
                    Picker("Scope", selection: Binding(
                        get: { entry.scope },
                        set: { entry.scope = $0 }
                    )) {
                        Text("The garden").tag(DiaryScope.garden)
                        Text("A bed").tag(DiaryScope.bed)
                        Text("A sowing").tag(DiaryScope.planting)
                        Text("A plant").tag(DiaryScope.plant)
                    }

                    if entry.scope == .bed {
                        Picker("Bed", selection: $entry.bed) {
                            Text("None").tag(Bed?.none)
                            ForEach(beds) { bed in
                                Text(bed.name).tag(Bed?.some(bed))
                            }
                        }
                    }
                }

                Section("Weather") {
                    Picker("Conditions", selection: Binding(
                        get: { entry.weather ?? .mild },
                        set: { entry.weather = $0 }
                    )) {
                        ForEach(Weather.allCases) { w in
                            Label(w.rawValue.capitalized, systemImage: w.symbolName).tag(w)
                        }
                    }

                    LabeledContent("Temperature") {
                        TextField("°C", value: $entry.temperatureC, format: .number)
                            .multilineTextAlignment(.trailing)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                }

                Section("Photos") {
                    if let photos = entry.photos, !photos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(photos) { photo in
                                    PhotoThumbnail(photo: photo, size: 88)
                                        .contextMenu {
                                            Button("Remove", role: .destructive) {
                                                context.delete(photo)
                                            }
                                        }
                                }
                            }
                        }
                    }

                    PhotosPicker(selection: $pickerItems,
                                 maxSelectionCount: 10,
                                 matching: .images) {
                        Label("Add photos", systemImage: "photo.badge.plus")
                    }

                    if isLoadingPhotos {
                        HStack {
                            ProgressView()
                            Text("Loading…").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Diary entry")
            .paperScreen()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if entry.body.isEmpty && (entry.photos ?? []).isEmpty {
                            context.delete(entry)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        entry.modifiedAt = .now
                        dismiss()
                    }
                    .disabled(entry.body.isEmpty && (entry.photos ?? []).isEmpty)
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await load(items) }
            }
        }
    }

    /// Loads each picked image, makes a thumbnail, attaches it to the entry.
    @MainActor
    private func load(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        defer {
            isLoadingPhotos = false
            pickerItems = []
        }

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            let photo = Photo()
            photo.imageData = data
            photo.thumbnailData = Self.thumbnail(from: data)
            photo.sourceLocalIdentifier = item.itemIdentifier
            photo.diaryEntry = entry
            entry.photos?.append(photo)
        }
    }

    /// Downscales to roughly 300 pt on the long edge.
    static func thumbnail(from data: Data, maxDimension: CGFloat = 300) -> Data? {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let small = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return small.jpegData(compressionQuality: 0.7)
        #elseif os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let small = NSImage(size: target)
        small.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target))
        small.unlockFocus()
        guard let tiff = small.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
        #endif
    }
}

#Preview {
    NavigationStack {
        JournalTimelineView()
    }
    .modelContainer(for: [DiaryEntry.self, Photo.self, Bed.self, BedSection.self,
                          Plant.self, Planting.self, Harvest.self,
                          PhenologyEvent.self, PestDiseaseEvent.self,
                          Survey.self, SurveyTally.self, WildlifeObservation.self],
                    inMemory: true)
}
