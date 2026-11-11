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

    /// The reply given to any question asking for canning, bottling,
    /// pickling or kitchen blanching times, temperatures or safety.
    ///
    /// ⚠️ CHECK: the named sources were chosen by Claude from general
    /// knowledge on 11 November 2026.
    static let preservingReply = """
    I don't give times, temperatures or methods for canning, bottling, \
    pickling or blanching. Small mistakes can make preserved food unsafe, \
    and botulism from home-canned vegetables can be fatal.

    Please follow a tested, published recipe exactly, such as the guidance \
    from the US National Center for Home Food Preservation or the \
    instructions from your jar maker.

    I'm happy to help with when to harvest, how to store fresh crops and \
    planning what to grow for preserving.
    """

    /// The reply given to any question asking how much pesticide, slug
    /// pellet, weedkiller or homemade spray to use.
    ///
    /// ⚠️ CHECK: the point about UK labels being legally binding was
    /// written by Claude from general knowledge on 11 November 2026.
    static let pesticideReply = """
    I don't give amounts, rates or dilutions for pesticides, slug pellets, \
    weedkillers or homemade sprays. Too much can harm wildlife, pets and \
    the soil, and in the UK the product label is the legal guide to how \
    much to use.

    Please follow the label exactly. If you'd like, I can suggest ways to \
    deal with the problem without chemicals.
    """

    /// The reply given to any question asking for medical advice, doses
    /// or remedies, including herbal ones.
    static let medicineReply = """
    I can't give medical advice, doses or remedies, including herbal ones. \
    Plants used as medicine can be harmful, can interfere with other \
    medicines and can be dangerous in pregnancy, and the right amount \
    depends on the person.

    Please ask a GP or pharmacist, or a qualified medical herbalist for \
    herbs. I'm happy to tell you about the plant itself: its history, how \
    to grow it and what visits it.
    """

    /// Returns fixed wording when a question must not go to the model, or
    /// nil when the model may answer as usual.
    ///
    /// The checks run in order and the first match wins. Pesticides come
    /// before medicine so that "how much soapy water for aphids" gets the
    /// pesticide reply, not the medicine one.
    static func fixedReply(to question: String) -> String? {
        if asksAboutEatingOrNamingFungi(question) { return fungiReply }
        if asksForPreservingDetails(question) { return preservingReply }
        if asksForPesticideAmounts(question) { return pesticideReply }
        if asksForMedicalAdvice(question) { return medicineReply }
        return nil
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

    // MARK: Preserving, pesticides and medicine
    //
    // These three checks read a tidied copy of the question (see `tidied`),
    // so the word lists can say exactly where a word starts and ends:
    //
    //   " pain "   only the whole word "pain"
    //   " inflam"  any word starting "inflam", such as "inflammation"
    //
    // That matters. Without it "pain" would match "painted lady", and
    // "my back" would match "my back garden".

    /// True when a message asks for canning, bottling, pickling or kitchen
    /// blanching times, temperatures or safety.
    ///
    ///   "How long do I water-bath can runner beans?"   stopped here
    ///   "How long should I blanch broad beans?"         stopped here
    ///   "How do I store onions over winter?"           goes to the model
    ///   "How long should I blanch my endive?"           goes to the model
    static func asksForPreservingDetails(_ question: String) -> Bool {
        let text = tidied(question)
        let wantsDetail = containsAny(of: preservingDetailWords, in: text)

        if containsAny(of: preservingWords, in: text) && wantsDetail { return true }

        // "Blanching" means two different things. In the kitchen it is a
        // quick boil before freezing. In the garden it is keeping light off
        // celery, endive or leeks for a few weeks so they grow pale and
        // sweet. Only the kitchen meaning is stopped.
        if text.contains(" blanch") {
            if containsAny(of: kitchenWords, in: text) { return true }
            if wantsDetail && !containsAny(of: gardenBlanchingWords, in: text) { return true }
        }
        return false
    }

    /// True when a message asks how much pesticide, slug pellet, weedkiller
    /// or homemade spray to use.
    ///
    ///   "How much slug pellet per square metre?"       stopped here
    ///   "How do I get rid of slugs organically?"       goes to the model
    ///   "How much comfrey tea for my tomatoes?"        goes to the model
    static func asksForPesticideAmounts(_ question: String) -> Bool {
        let text = tidied(question)
        return containsAny(of: pestControlWords, in: text) && containsAny(of: amountWords, in: text)
    }

    /// True when a message asks for medical advice, a dose or a remedy.
    ///
    ///   "Is comfrey tea safe to drink for a bad back?"  stopped here
    ///   "What are the medicinal uses of yarrow?"        stopped here
    ///   "Is comfrey good for my compost?"               goes to the model
    ///   "Will the cold kill my plants?"                 goes to the model
    static func asksForMedicalAdvice(_ question: String) -> Bool {
        let text = tidied(question)
        if containsAny(of: medicineWords, in: text) { return true }
        return containsAny(of: healthWords, in: text) && containsAny(of: takingWords, in: text)
    }

    /// Lower case, with apostrophes removed and every other mark turned
    /// into a space, and a space at each end. So "Water-bath, my beans?"
    /// becomes " water bath my beans ".
    static func tidied(_ question: String) -> String {
        var result = ""
        for character in question.lowercased() {
            if character.isLetter || character.isNumber {
                result.append(character)
            } else if character == "'" || character == "\u{2019}" {
                continue   // "what's" becomes "whats"
            } else if result.last != " " {
                result.append(" ")
            }
        }
        return " " + result.trimmingCharacters(in: .whitespaces) + " "
    }

    /// Ways of preserving that need tested times. "Can" on its own is left
    /// out, because "how long can my tomatoes stay out" would trip it.
    private static let preservingWords = [
        " canning ", " canned ", " canner", " water bath", " waterbath",
        " pressure can", " pressure cook", " bottling ", " bottled fruit",
        " bottled veg", " kilner", " mason jar", " sterilis", " steriliz",
        " botulism", " preserv", " pickl", " jam ", " jams ", " chutney",
        " passata"
    ]

    /// Asking for a time, a temperature or whether it is safe. Plain
    /// "time" is left out, because "the best time to pick plums for jam"
    /// is a harvesting question.
    private static let preservingDetailWords = [
        " how long", " minute", " hour", " seconds ", " processing time",
        " temperature", " temp ", " degree", " psi ", " safe", " how hot",
        " boil for", " process"
    ]

    /// Words that show blanching means the kitchen kind.
    private static let kitchenWords = [
        " freez", " boil", " steam", " ice ", " ice water", " scald",
        " minute", " second"
    ]

    /// Crops and jobs that show blanching means the garden kind.
    private static let gardenBlanchingWords = [
        " celery", " celeriac", " endive", " chicory", " leek", " cardoon",
        " seakale", " sea kale", " dandelion", " rhubarb", " cauliflower",
        " lettuce", " fennel", " asparagus", " earth up", " earthing",
        " cover", " pot over", " forcing", " forced", " light", " dark",
        " collar", " tie ", " tying"
    ]

    /// Things used to kill pests, weeds or diseases.
    private static let pestControlWords = [
        " pesticide", " insecticide", " herbicide", " fungicide",
        " weedkiller", " weed killer", " slug pellet", " pellets ",
        " slug killer", " ant killer", " ant powder", " glyphosate",
        " ferric phosphate", " metaldehyde", " neem", " pyrethr", " derris",
        " rotenone", " bug spray", " insect spray", " soap spray",
        " soapy water", " washing up liquid", " fatty acid",
        " copper sulphate", " bordeaux", " sulphur dust", " sulfur dust",
        " nematode", " rat bait", " rodenticide", " poison "
    ]

    /// Asking how much, how strong or how often.
    private static let amountWords = [
        " how much", " how many", " per square", " per m ", " per metre",
        " per meter", " per litre", " per liter", " ml ", " gram", " g per",
        " rate", " dilut", " mix ", " mixing", " strength", " concentrat",
        " dose", " dosage", " how strong", " spoonful", " teaspoon",
        " tablespoon", " capful", " sachet", " how often"
    ]

    /// Words that are about medicine whatever else is in the question.
    private static let medicineWords = [
        " medicinal", " medicine", " dosage", " tincture", " poultice",
        " herbal remed", " salve", " decoction"
    ]

    /// Health problems. These only count beside a taking word.
    private static let healthWords = [
        " bad back ", " back pain", " backache", " my back hurt",
        " headache", " migraine", " arthritis", " eczema", " a cold ",
        " colds ", " common cold", " flu ", " cough", " sore throat",
        " insomnia", " for sleep ", " help me sleep", " sleep better",
        " anxiety", " blood pressure", " diabet", " pregnan",
        " period pain", " indigestion", " constipation", " diarrhoea",
        " diarrhea", " a rash", " wound", " bruise", " inflam", " pain ",
        " pains ", " painful", " painkiller", " pain relief", " ailment",
        " symptom", " illness", " unwell", " my health"
    ]

    /// Taking, using or asking how much of something.
    private static let takingWords = [
        " drink", " take ", " taking ", " eat ", " eating ", " apply",
        " rub ", " swallow", " how much", " how many", " dose", " for my ",
        " help with", " helps with", " good for ", " treat", " use for ",
        " use it for", " used for ", " safe to ", " safe for me",
        " tea for ", " cure", " relieve", " ease "
    ]
}
