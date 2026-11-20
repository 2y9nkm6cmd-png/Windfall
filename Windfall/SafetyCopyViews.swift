//
//  SafetyCopyViews.swift
//  Windfall
//
//  The Safety copies section at the top of Settings › Backup: the copies
//  on this device, newest first, with a button to make one now, a way to
//  save one to Files and a way to put one back. Built 20 November 2026
//  (knowledge base doc 138). The work itself is in SafetyCopy.swift.
//
//  The slow parts (making a copy, packing one as a .zip) are done with
//  `Task.detached`, which runs them away from the main thread. `await`
//  waits for the answer while the screen carries on being drawn.
//

import SwiftUI

struct SafetyCopiesSection: View {

    @State private var copies: [SafetyCopy.Copy] = []
    /// The copy asked to be put back next time, by folder name.
    @State private var waiting: String?
    @State private var isMaking = false
    @State private var problem: String?
    /// The copy whose "Put back" was tapped, waiting for a yes.
    @State private var toPutBack: SafetyCopy.Copy?
    /// A copy packed as a .zip, ready for the share sheet, and which
    /// copy it is.
    @State private var packed: URL?
    @State private var packedName: String?
    @State private var packingName: String?

    var body: some View {
        Section {
            if let waiting {
                VStack(alignment: .leading, spacing: 6) {
                    Label("The copy of \(when(named: waiting)) will be put back the next time Windfall opens. Close Windfall fully and open it again. On an iPhone or iPad, swipe it away in the app switcher first.",
                          systemImage: "clock.arrow.circlepath")
                    Button("Call it off") {
                        SafetyCopy.callOffPutBack()
                        reload()
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button {
                makeNow()
            } label: {
                Label(isMaking ? "Making a safety copy…" : "Make a safety copy now",
                      systemImage: "externaldrive.badge.checkmark")
            }
            .disabled(isMaking)

            ForEach(copies) { copy in
                row(copy)
            }

            if copies.isEmpty, !isMaking {
                Text("No safety copies yet. The first is made by itself a little after Windfall opens.")
                    .foregroundStyle(.secondary)
            }

            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Safety copies, photos included")
        } footer: {
            Text("Made by itself once a day when Windfall opens. The newest seven are kept on this device. Each holds every record and every photo. Save one to Files to keep it off the device as well.")
        }
        .task { reload() }
        .alert("Put this copy back?",
               isPresented: Binding(get: { toPutBack != nil }, set: { if !$0 { toPutBack = nil } }),
               presenting: toPutBack) { copy in
            Button("Put it back next time Windfall opens", role: .destructive) {
                askToPutBack(copy)
            }
            Button("Cancel", role: .cancel) {}
        } message: { copy in
            Text("Everything on this device goes back to how it was on \(when(copy.about.made)). A copy of how things are now is made first, so this can be undone the same way.")
        }
    }

    /// One copy: when, what kind, what it holds, and its two buttons.
    private func row(_ copy: SafetyCopy.Copy) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(when(copy.about.made))
                .font(.body.weight(.semibold))
            Text(copy.about.kind.words + ". " + SafetyCopyPlan.summary(copy.about))
                .font(.footnote)
                .foregroundStyle(copy.about.checkedWhole ? Color.secondary : Color.orange)
            HStack(spacing: 18) {
                if packedName == copy.name, let packed {
                    ShareLink(item: packed) {
                        Label("Save to Files", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        pack(copy)
                    } label: {
                        Label(packingName == copy.name ? "Packing…" : "Pack to save",
                              systemImage: "archivebox")
                    }
                    .disabled(packingName != nil)
                }
                Button {
                    toPutBack = copy
                } label: {
                    Label("Put back", systemImage: "arrow.uturn.backward")
                }
            }
            .buttonStyle(.borderless)
            .font(.footnote)
        }
        .padding(.vertical, 2)
    }

    // MARK: Doing

    private func reload() {
        copies = SafetyCopy.list()
        waiting = SafetyCopy.waitingToPutBack()
    }

    private func makeNow() {
        isMaking = true
        problem = nil
        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try SafetyCopy.make(.byHand)
                }.value
            } catch {
                problem = error.localizedDescription
            }
            isMaking = false
            reload()
        }
    }

    /// Packs a copy as one .zip file. Then its button becomes the share
    /// sheet's, which offers Save to Files (and iCloud Drive) among the
    /// rest. Packing is a separate tap because a copy with many photos
    /// takes a moment to pack.
    private func pack(_ copy: SafetyCopy.Copy) {
        packingName = copy.name
        problem = nil
        Task {
            do {
                packed = try await Task.detached(priority: .userInitiated) {
                    try SafetyCopy.zipped(copy)
                }.value
                packedName = copy.name
            } catch {
                problem = error.localizedDescription
            }
            packingName = nil
        }
    }

    private func askToPutBack(_ copy: SafetyCopy.Copy) {
        do {
            try SafetyCopy.askToPutBack(copy)
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
        reload()
    }

    // MARK: Words

    /// "Friday 20 November at 20:35".
    private func when(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute())
    }

    private func when(named name: String) -> String {
        copies.first(where: { $0.name == name }).map { when($0.about.made) } ?? name
    }
}
