//
//  PacketTranslationView.swift
//  Windfall
//
//  Foreign seed packets (doc 120, use 17; doc 140). When the packet
//  reader reads words that are not English, this offers a translation
//  into English, made on the device by Apple's Translation framework,
//  and shows each line of the packet with its translation beside it,
//  marked as a translation.
//
//  Nothing is sent anywhere. The first time a language is used, the
//  system may offer to download that language for translation; that
//  question is Apple's own.
//
//  The translation is shown, not used: the sheet's rows are still read
//  from the packet as printed (card d-packet-translation-rows-140).
//

import Foundation
import NaturalLanguage
import SwiftUI
import Translation

/// Which language some text is in, by Apple's NaturalLanguage, on the
/// device. The rules for when to act on it are in PacketTranslation.swift.
enum PacketLanguage {

    /// Too little text to judge: a few words of a brand name are often
    /// read as some other language.
    static let fewestLetters = 20

    /// The language to offer a translation from ("fr"), or nil for
    /// English, for too little text, or when the detector is unsure.
    static func detect(_ text: String) -> String? {
        guard text.filter(\.isLetter).count >= fewestLetters else { return nil }
        let recogniser = NLLanguageRecognizer()
        recogniser.processString(text)
        // The three likeliest languages and how likely each is.
        let likely = recogniser.languageHypotheses(withMaximum: 3)
        var shares: [String: Double] = [:]
        for (language, share) in likely { shares[language.rawValue] = share }
        return PacketTranslation.languageToOffer(hypotheses: shares)
    }
}

/// A section of the packet sheet: "This packet is in French", a button
/// to translate it, then each line with its English beside it.
struct PacketTranslationSection: View {

    /// The packet's language, as a short code ("fr").
    let language: String
    /// Its lines, in the order read (`PacketTranslation.linesToTranslate`).
    let lines: [String]

    /// Set when the button is pressed. `.translationTask` below watches
    /// it, and runs its translation once it is set.
    @State private var configuration: TranslationSession.Configuration?
    /// Each line's English, found by the line itself.
    @State private var translations: [String: String] = [:]
    @State private var isWorking = false
    @State private var failure: String?
    #if os(iOS)
    /// Wide (an iPad, an iPhone on its side) or narrow.
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var languageName: String { PacketTranslation.name(of: language) }

    /// Side by side where there is room, one under the other on a phone.
    private var sideBySide: Bool {
        #if os(iOS)
        return sizeClass == .regular
        #else
        return true
        #endif
    }

    var body: some View {
        Section {
            if translations.isEmpty {
                Button {
                    failure = nil
                    if configuration == nil {
                        configuration = TranslationSession.Configuration(
                            source: Locale.Language(identifier: language),
                            target: Locale.Language(identifier: "en"))
                    } else {
                        // Asked again after a failure: `invalidate` makes
                        // the task below run once more.
                        configuration?.invalidate()
                    }
                } label: {
                    Label(isWorking ? "Translating…" : "Translate from \(languageName) into English",
                          systemImage: "translate")
                }
                .disabled(isWorking || lines.isEmpty)
            } else {
                ForEach(Array(PacketTranslation.paired(lines, with: translations).enumerated()), id: \.offset) { numbered in
                    pairRow(original: numbered.element.original, english: numbered.element.english)
                }
            }
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("This packet is in \(languageName)")
        } footer: {
            Text("Translated on this device by Apple. The translation is marked with the translate sign; it is not the packet's own words, so check anything you act on. The rows above are still read from the packet as printed.")
        }
        // Runs the translation whenever `configuration` is set or made
        // invalid. The session is the system's: it translates on the
        // device, and may first ask to download the language.
        .translationTask(configuration) { translator in
            isWorking = true
            defer { isWorking = false }
            do {
                // Each line goes as one request, labelled with the line
                // itself, so each answer can be put back beside its line.
                let requests = lines.map { TranslationSession.Request(sourceText: $0, clientIdentifier: $0) }
                let answers = try await translator.translations(from: requests)
                var found: [String: String] = [:]
                for answer in answers {
                    if let line = answer.clientIdentifier { found[line] = answer.targetText }
                }
                translations = found
            } catch {
                failure = "No translation could be made: \(error.localizedDescription)"
            }
        }
    }

    /// One line of the packet and its English.
    @ViewBuilder
    private func pairRow(original: String, english: String) -> some View {
        let originalText = Text(original)
            .font(.footnote)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        let englishText = Label {
            Text(english.isEmpty ? "No translation came back for this line." : english)
                .italic(english.isEmpty)
        } icon: {
            Image(systemName: "translate")
                .accessibilityLabel("Translation")
        }
        .font(.footnote)
        .foregroundStyle(Theme.inkSoft)
        .frame(maxWidth: .infinity, alignment: .leading)

        if sideBySide {
            HStack(alignment: .top, spacing: 16) {
                originalText
                englishText
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                originalText
                englishText
            }
        }
    }
}
