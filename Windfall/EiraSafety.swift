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
    /// Checked 11 November 2026: the British Mycological Society's website
    /// has a "Find a Fungus Group near you" page and pages for affiliated
    /// local groups (britmycolsoc.org.uk, Recording Network).
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
    /// Checked 11 November 2026 against the Food Standards Agency's
    /// "Consumer advice for food preservation at home" on GOV.UK. It says
    /// botulism "can cause paralysis or death", that canning and bottling
    /// are "difficult to carry out safely" at home, and to "always follow
    /// instructions supplied with your equipment or from a recognised
    /// source". It gives no times itself. The US National Center for Home
    /// Food Preservation is named because it publishes tested times.
    static let preservingReply = """
    I don't give times, temperatures or methods for canning, bottling, \
    pickling or blanching. Small mistakes can make preserved food unsafe, \
    and botulism from home-preserved food can cause paralysis or death. \
    You cannot tell by look, smell or taste.

    Please follow a tested, published recipe exactly, along with the \
    instructions that came with your equipment. The Food Standards Agency \
    has UK advice on preserving food at home, and the US National Center \
    for Home Food Preservation publishes tested times.

    I'm happy to help with when to harvest, how to store fresh crops and \
    planning what to grow for preserving.
    """

    /// The reply given to any question asking how much pesticide, slug
    /// pellet, weedkiller or homemade spray to use.
    ///
    /// Checked 11 November 2026. The RHS ("Chemical labels explained")
    /// says "Gardeners are legally required to follow the instructions on
    /// pesticide labels". The Health and Safety Executive's home and
    /// garden page says "Always use PPPs as instructed on the label" and
    /// warns against assuming that household chemicals used as a pesticide
    /// are without risk or always legal.
    static let pesticideReply = """
    I don't give amounts, rates or dilutions for pesticides, slug pellets, \
    weedkillers or homemade sprays. Too much can harm wildlife, pets and \
    the soil, and in the UK you are legally required to follow the \
    instructions on the product label.

    Please follow the label exactly. Homemade sprays made from household \
    products have no tested rate, and the Health and Safety Executive \
    warns they are not always safe or legal. If you'd like, I can suggest \
    ways to deal with the problem without chemicals.
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
        // Last, so that a safety reply always wins over this one.
        if asksToSaveARecord(question) { return savingReply }
        return nil
    }

    /// The reply given when the chat is asked to save, record or log
    /// something. Not a safety matter in the way the four above are, but
    /// the same remedy: Eira cannot change records from the chat, and a
    /// model asked to will sometimes say it has. On 13 November 2026
    /// Qwen3 8B answered "your sowing is now recorded in the system".
    static let savingReply = """
    I haven't saved anything, and I can't change your records from this \
    chat.

    To record it, tell the journal: write what you sowed, planted or \
    picked as a plain statement, without a question mark. I'll offer a \
    card with the details, and it is saved only when you press Add.
    """

    /// True when a message asks for something to be saved or recorded.
    ///
    /// It needs a request and an act together, or an act and a place:
    ///
    ///   "I've sown carrots in bed 2, can you save that?"   stopped here
    ///   "Please record that I picked 2kg of apples"        stopped here
    ///   "Add it to my journal"                             stopped here
    ///   "How do I save seed from peas?"                    goes to the model
    ///   "Can you put that another way?"                    goes to the model
    ///   "Please note that I garden on clay"                goes to the model
    static func asksToSaveARecord(_ question: String) -> Bool {
        let text = tidied(question)

        // Saving seed is gardening, not record keeping.
        let seedSaving = [" save seed", " saving seed", " seed saving", " save the seed", " save my own seed",
                          " save some seed", " for next year "]
        if containsAny(of: seedSaving, in: text) { return false }

        let requests = [" can you ", " could you ", " will you ", " would you ", " please ", " pls "]
        let acts = [" save that ", " save this ", " save it ", " save them ",
                    " record that ", " record this ", " record it ", " record them ",
                    " log that ", " log this ", " log it ", " log them ",
                    " add that ", " add this ", " add it ", " add them ",
                    " store that ", " store this ", " store it ",
                    " note that down ", " note this down ", " note it down ",
                    " write that down ", " write this down ", " write it down ",
                    " make a note ", " make a record ", " update my records ", " update the records "]
        let places = [" to my records ", " in my records ", " to my journal ", " in my journal ",
                      " to my diary ", " in my diary ", " to the journal ", " in the journal ",
                      " to the records ", " to my log ", " in my log "]
        let actWords = [" save ", " record ", " log ", " add ", " store ", " put ", " enter ", " note "]

        if containsAny(of: requests, in: text) && containsAny(of: acts, in: text) { return true }
        if containsAny(of: actWords, in: text) && containsAny(of: places, in: text) { return true }
        return false
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
