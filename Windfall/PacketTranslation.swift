//
//  PacketTranslation.swift
//  Windfall
//
//  Foreign seed packets (doc 120, use 17; doc 140): the plain rules for
//  when to offer a translation and how to set it out. The detecting
//  (Apple's NaturalLanguage) and the translating (Apple's Translation
//  framework, on the device) are in PacketTranslationView.swift, which
//  needs a Mac or a device; this part is tested without one.
//

import Foundation

enum PacketTranslation {

    /// The language a packet is in is only acted on when the detector is
    /// at least this sure of it. ⚠️ CHECK: Claude's number.
    static let sureEnough = 0.5
    /// English counts as present, and nothing is offered, when the
    /// detector gives it at least this share. Many packets are printed in
    /// several languages; one with an English panel needs no translation.
    static let englishEnough = 0.25

    /// The language to offer a translation from, as a short code
    /// ("fr", "de"), or nil.
    ///
    /// - `hypotheses`: the detector's shares by language code, from 0 to
    ///   1 ("fr": 0.83, "en": 0.05).
    static func languageToOffer(hypotheses: [String: Double]) -> String? {
        let english = hypotheses.filter { base($0.key) == "en" }.values.reduce(0, +)
        guard english < englishEnough else { return nil }
        guard let best = hypotheses.filter({ base($0.key) != "en" }).max(by: { $0.value < $1.value }),
              best.value >= sureEnough else { return nil }
        return base(best.key)
    }

    /// "fr-FR" and "fr" both give "fr". Script tags such as "zh-Hans" are
    /// kept, as Chinese in its two scripts are different writing.
    static func base(_ code: String) -> String {
        let parts = code.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
        guard let first = parts.first?.lowercased() else { return "" }
        if first == "zh", parts.count > 1, parts[1].count == 4 { return "zh-" + parts[1] }
        return first
    }

    /// The English name of a language, for "Translate from French".
    /// A language not listed is called by its code, which is never blank.
    static func name(of code: String) -> String {
        let names = [
            "fr": "French", "de": "German", "it": "Italian", "es": "Spanish", "pt": "Portuguese",
            "nl": "Dutch", "pl": "Polish", "da": "Danish", "sv": "Swedish", "nb": "Norwegian",
            "fi": "Finnish", "cs": "Czech", "hu": "Hungarian", "ro": "Romanian", "el": "Greek",
            "tr": "Turkish", "ru": "Russian", "uk": "Ukrainian", "ja": "Japanese", "ko": "Korean",
            "zh-Hans": "Chinese (simplified)", "zh-Hant": "Chinese (traditional)", "zh": "Chinese",
            "ar": "Arabic", "hi": "Hindi", "th": "Thai", "vi": "Vietnamese", "id": "Indonesian",
        ]
        return names[code] ?? code
    }

    /// The lines worth translating, in the order read: blank lines and
    /// lines with no letters (prices, weights, barcode numbers) are left
    /// out, and a line read twice is translated once.
    static func linesToTranslate(_ lines: [PacketLine]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for line in lines {
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.contains(where: \.isLetter), !seen.contains(text) else { continue }
            seen.insert(text)
            out.append(text)
        }
        return out
    }

    /// The text the detector reads: every line joined.
    static func sample(_ lines: [PacketLine]) -> String {
        linesToTranslate(lines).joined(separator: "\n")
    }

    /// Each line paired with its translation, in order. A line the
    /// translator gave nothing back for keeps an empty translation, so
    /// the two columns never slip out of step.
    static func paired(_ originals: [String], with translations: [String: String]) -> [(original: String, english: String)] {
        originals.map { ($0, translations[$0] ?? "") }
    }
}
