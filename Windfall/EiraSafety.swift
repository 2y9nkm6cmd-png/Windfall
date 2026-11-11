//
//  EiraSafety.swift
//  Windfall
//
//  Rules that are too important to leave to a language model.
//
//  A model follows its instructions most of the time, not every time. On
//  11 November 2026 the built-in model was asked whether lawn mushrooms
//  were safe to eat. It did say it could not confirm that, but first it
//  asked for a description "to determine if they are safe". That offer is
//  exactly what must never happen.
//
//  So this file answers such questions itself, with fixed wording, before
//  the model is asked anything. Ordinary code gives the same answer every
//  time. The model's own instructions still carry the rule as a second
//  line of defence.
//

import Foundation

enum EiraSafety {

    /// The reply given to any question about eating fungi or naming a mushroom.
    ///
    /// ⚠️ CHECK: the pointer to the British Mycological Society's local
    /// groups was written by Claude from general knowledge.
    static let fungiReply = """
    I can't identify mushrooms or other fungi, and I can't say whether any \
    are safe to eat. Mistakes with fungi can be fatal, and they cannot be \
    judged reliably from a description or a photo.

    Please don't eat them. If you want to know what they are, ask a local \
    fungus group or an experienced forager who can see them in the hand. \
    The British Mycological Society lists local groups.
    """

    /// Returns fixed wording when a question must not go to the model, or
    /// nil when the model may answer as usual.
    static func fixedReply(to question: String) -> String? {
        asksAboutEatingOrNamingFungi(question) ? fungiReply : nil
    }

    /// True when a message asks about eating fungi, or asks for a mushroom
    /// to be named.
    ///
    /// Two halves are always needed, a fungus word and an intent, so that
    /// ordinary gardening questions still reach the model:
    ///
    ///   "Are fungi good for my soil?"            goes to the model
    ///   "What is this fungus on my rose leaves?"  goes to the model
    ///   "Can I eat these mushrooms?"              stopped here
    ///   "What mushroom is this?"                  stopped here
    static func asksAboutEatingOrNamingFungi(_ question: String) -> Bool {
        let text = " " + question.lowercased() + " "
        let mentionsMushroom = containsAny(of: mushroomWords, in: text)
        let mentionsAnyFungus = mentionsMushroom || containsAny(of: otherFungusWords, in: text)

        if mentionsAnyFungus && containsAny(of: eatingWords, in: text) { return true }
        if mentionsMushroom && containsAny(of: mushroomOnlyWords, in: text) { return true }
        if mentionsMushroom && containsAny(of: namingWords, in: text) { return true }
        return false
    }

    // These are word beginnings, so "mushroom" also catches "mushrooms".

    /// The kinds of fungus people pick and eat.
    private static let mushroomWords = [
        "mushroom", "toadstool", "puffball", "bolete", "boletus", "chanterelle",
        "morel", "ink cap", "inkcap", "truffle", "amanita", "agaric",
        "death cap", "deathcap", "chicken of the woods", "penny bun"
    ]

    /// Fungi in general, which also covers plant diseases. These only
    /// count when the question is about eating.
    private static let otherFungusWords = ["fungus", "fungi", "fungal"]

    /// Words about eating or being poisoned. These count with any fungus word.
    private static let eatingWords = [
        " eat", "edib", "cook", " fry", " fried", "taste", "tasty",
        "poison", "toxic", "forag", "consum", "recipe"
    ]

    /// Looser words that only count beside a mushroom word. "Is it safe to
    /// compost leaves with a fungal disease?" should reach the model, but
    /// "Are the mushrooms safe for my dog?" should not.
    private static let mushroomOnlyWords = ["safe", "pick ", "picked", "picking"]

    private static let namingWords = [
        "identif", " id ", "what is this", "what's this", "what are these",
        "what is it", "what are they", "what kind", "what type", "what sort",
        "what species", "what mushroom", "which mushroom", "which toadstool",
        "name of", "name this", "name these", "is this a", "is it a",
        "could this be", "tell me what"
    ]

    private static func containsAny(of words: [String], in text: String) -> Bool {
        words.contains { text.contains($0) }
    }
}
