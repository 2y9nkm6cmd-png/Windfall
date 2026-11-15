"""Windfall's wildlife reference: the KINDS of animal, and which kind an animal is.

A kind is a group you would know by sight: bumblebee, hoverfly, tit, newt.
Each has one drawing (Tools/design/wildlife.py), shared by every animal of
that kind. Which kind an animal is, is worked out from its place in the
tree of life (its class, order, family and sometimes genus), as iNaturalist
gives it. The rules are in `kind_of` below, in plain lists, so that they can
be read and corrected.

⚠️ The kinds, their names and every rule here are Claude's, written on
15 November 2026. William has not checked them.
"""

# (slug, the name shown, the heading it sits under on the Species page)
KINDS = [
    ("bumblebee", "Bumblebees", "Bees, wasps and ants"),
    ("honeybee", "Honeybee", "Bees, wasps and ants"),
    ("solitary-bee", "Solitary bees", "Bees, wasps and ants"),
    ("wasp", "Wasps", "Bees, wasps and ants"),
    ("ant", "Ants", "Bees, wasps and ants"),
    ("sawfly", "Sawflies", "Bees, wasps and ants"),
    ("parasitic-wasp", "Ichneumons and other parasitic wasps", "Bees, wasps and ants"),
    ("hoverfly", "Hoverflies", "Flies"),
    ("bee-fly", "Bee-flies", "Flies"),
    ("cranefly", "Craneflies, gnats and midges", "Flies"),
    ("fly", "Other flies", "Flies"),
    ("butterfly", "Butterflies", "Butterflies and moths"),
    ("moth", "Larger moths", "Butterflies and moths"),
    ("micro-moth", "Micro-moths", "Butterflies and moths"),
    ("ladybird", "Ladybirds", "Beetles"),
    ("ground-beetle", "Ground beetles", "Beetles"),
    ("flower-beetle", "Soldier beetles and other flower beetles", "Beetles"),
    ("longhorn", "Longhorn beetles", "Beetles"),
    ("chafer", "Chafers, dung beetles and stag beetles", "Beetles"),
    ("leaf-beetle", "Leaf beetles", "Beetles"),
    ("weevil", "Weevils", "Beetles"),
    ("beetle", "Other beetles", "Beetles"),
    ("shield-bug", "Shield bugs and their kin", "Bugs"),
    ("aphid", "Aphids, scale insects and psyllids", "Bugs"),
    ("hopper", "Leafhoppers and froghoppers", "Bugs"),
    ("bug", "Plant bugs, water bugs and other true bugs", "Bugs"),
    ("gall-maker", "Gall makers", "Bugs"),
    ("dragonfly", "Dragonflies", "Other insects"),
    ("damselfly", "Damselflies", "Other insects"),
    ("grasshopper", "Grasshoppers and groundhoppers", "Other insects"),
    ("cricket", "Bush-crickets and crickets", "Other insects"),
    ("earwig", "Earwigs", "Other insects"),
    ("lacewing", "Lacewings and their kin", "Other insects"),
    ("riverfly", "Mayflies, caddisflies and stoneflies", "Other insects"),
    ("other-insect", "Springtails and other small insects", "Other insects"),
    ("spider", "Spiders, harvestmen and mites", "Spiders and other minibeasts"),
    ("woodlouse", "Woodlice and sea slaters", "Spiders and other minibeasts"),
    ("centipede", "Centipedes and millipedes", "Spiders and other minibeasts"),
    ("earthworm", "Earthworms", "Slugs, snails and worms"),
    ("slug", "Slugs", "Slugs, snails and worms"),
    ("snail", "Land and pond snails", "Slugs, snails and worms"),
    ("worm", "Flatworms, leeches and other worms", "Slugs, snails and worms"),
    ("tit", "Tits", "Birds"),
    ("finch", "Finches, sparrows and buntings", "Birds"),
    ("thrush", "Thrushes, robin and chats", "Birds"),
    ("warbler", "Warblers, wren and other small insect eaters", "Birds"),
    ("crow", "Crows", "Birds"),
    ("pigeon", "Pigeons and doves", "Birds"),
    ("woodpecker", "Woodpeckers", "Birds"),
    ("swallow", "Swallows, martins and swift", "Birds"),
    ("owl", "Owls", "Birds"),
    ("raptor", "Birds of prey", "Birds"),
    ("gamebird", "Pheasants, partridges and grouse", "Birds"),
    ("duck", "Ducks, geese and swans", "Birds"),
    ("coot", "Coot, moorhen, grebes and divers", "Birds"),
    ("heron", "Herons, egrets and other long-legged birds", "Birds"),
    ("wader", "Waders", "Birds"),
    ("seabird", "Gulls, terns and other seabirds", "Birds"),
    ("bird", "Other birds", "Birds"),
    ("hedgehog", "Hedgehog", "Mammals"),
    ("small-mammal", "Mice, voles, shrews and other small mammals", "Mammals"),
    ("squirrel", "Squirrels", "Mammals"),
    ("rabbit", "Rabbit and hares", "Mammals"),
    ("bat", "Bats", "Mammals"),
    ("fox", "Fox", "Mammals"),
    ("cat", "Cats", "Mammals"),
    ("badger", "Badger, otter, stoat and their kin", "Mammals"),
    ("deer", "Deer and other large grazers", "Mammals"),
    ("seal", "Seals", "Mammals"),
    ("whale", "Dolphins, porpoise and whales", "Mammals"),
    ("frog", "Frogs", "Amphibians and reptiles"),
    ("toad", "Toads", "Amphibians and reptiles"),
    ("newt", "Newts", "Amphibians and reptiles"),
    ("lizard", "Lizards and terrapins", "Amphibians and reptiles"),
    ("snake", "Snakes and the slow-worm", "Amphibians and reptiles"),
    ("fish", "Fish", "Fish"),
    ("crab", "Crabs, shrimps and lobsters", "Sea and shore"),
    ("sea-snail", "Sea snails, limpets and chitons", "Sea and shore"),
    ("sea-slug", "Sea slugs", "Sea and shore"),
    ("bivalve", "Cockles, mussels and other two-shelled molluscs", "Sea and shore"),
    ("cephalopod", "Octopus, cuttlefish and squid", "Sea and shore"),
    ("starfish", "Starfish, sea urchins and their kin", "Sea and shore"),
    ("anemone", "Sea anemones and corals", "Sea and shore"),
    ("jellyfish", "Jellyfish and their kin", "Sea and shore"),
    ("sea-colony", "Barnacles, sponges and other fixed sea life", "Sea and shore"),
]

BEES = {"Apidae", "Andrenidae", "Halictidae", "Megachilidae", "Colletidae", "Melittidae"}
SAWFLIES = {"Tenthredinidae", "Argidae", "Cimbicidae", "Diprionidae", "Pamphiliidae", "Siricidae", "Cephidae",
            "Xiphydriidae", "Blasticotomidae", "Xyelidae", "Orussidae", "Heptamelidae"}
WASPS = {"Vespidae", "Crabronidae", "Sphecidae", "Pompilidae", "Chrysididae", "Tiphiidae", "Mutillidae", "Sapygidae",
         "Philanthidae", "Bembicidae", "Psenidae", "Pemphredonidae", "Astatidae", "Mellinidae", "Ammoplanidae", "Scoliidae"}
GNATS = {"Tipulidae", "Limoniidae", "Pediciidae", "Ptychopteridae", "Trichoceridae", "Culicidae", "Chironomidae",
         "Mycetophilidae", "Sciaridae", "Psychodidae", "Simuliidae", "Ceratopogonidae", "Anisopodidae", "Bibionidae",
         "Keroplatidae", "Chaoboridae", "Dixidae", "Scatopsidae", "Bolitophilidae", "Cylindrotomidae"}
BUTTERFLIES = {"Nymphalidae", "Pieridae", "Lycaenidae", "Hesperiidae", "Papilionidae", "Riodinidae"}
LARGER_MOTHS = {"Noctuidae", "Geometridae", "Erebidae", "Notodontidae", "Sphingidae", "Drepanidae", "Lasiocampidae",
                "Saturniidae", "Hepialidae", "Cossidae", "Zygaenidae", "Sesiidae", "Nolidae", "Limacodidae", "Endromidae"}
WEEVILS = {"Curculionidae", "Brentidae", "Apionidae", "Attelabidae", "Rhynchitidae", "Anthribidae", "Nanophyidae", "Erirhinidae"}
FLOWER_BEETLES = {"Cantharidae", "Oedemeridae", "Melyridae", "Pyrochroidae", "Mordellidae", "Scraptiidae", "Lampyridae", "Malachiidae", "Dasytidae"}
CHAFERS = {"Scarabaeidae", "Geotrupidae", "Lucanidae", "Trogidae"}
SHIELD_BUGS = {"Pentatomidae", "Acanthosomatidae", "Scutelleridae", "Cydnidae", "Sehiridae", "Thyreocoridae", "Coreidae",
               "Rhopalidae", "Alydidae", "Stenocephalidae", "Pyrrhocoridae"}
APHIDS = {"Aphididae", "Adelgidae", "Phylloxeridae", "Coccidae", "Diaspididae", "Pseudococcidae", "Eriococcidae",
          "Triozidae", "Psyllidae", "Aphalaridae", "Liviidae", "Aleyrodidae", "Calophyidae", "Eriosomatidae", "Monophlebidae"}
HOPPERS = {"Cicadellidae", "Aphrophoridae", "Cercopidae", "Delphacidae", "Membracidae", "Issidae", "Cixiidae", "Cicadidae", "Tettigometridae"}
DRAGONFLIES = {"Libellulidae", "Aeshnidae", "Corduliidae", "Cordulegastridae", "Gomphidae"}
SLUGS = {"Limacidae", "Arionidae", "Agriolimacidae", "Milacidae", "Testacellidae", "Boettgerillidae", "Trigonochlamydidae"}
POND_SNAILS = {"Planorbidae", "Lymnaeidae", "Physidae", "Viviparidae", "Bithyniidae", "Tateidae", "Neritidae", "Pomatiidae",
               "Acroloxidae", "Valvatidae", "Succineidae"}
SEA_SLUG_ORDERS = {"Nudibranchia", "Aplysiida", "Pleurobranchida", "Cephalaspidea", "Systellommatophora"}
SEA_SLUG_FAMILIES = {"Plakobranchidae", "Limapontiidae", "Hermaeidae"}
SWIMMING_HYDROZOA = {"Porpitidae", "Aequoreidae", "Laodiceidae", "Mitrocomidae", "Pandeidae", "Physaliidae"}
WHALES = {"Delphinidae", "Balaenopteridae", "Phocoenidae", "Ziphiidae", "Physeteridae", "Balaenidae", "Monodontidae", "Kogiidae"}
BIRDS = {
    "tit": {"Paridae", "Aegithalidae"},
    "finch": {"Fringillidae", "Passeridae", "Emberizidae", "Calcariidae"},
    "thrush": {"Turdidae", "Muscicapidae"},
    "warbler": {"Phylloscopidae", "Sylviidae", "Acrocephalidae", "Locustellidae", "Regulidae", "Troglodytidae", "Certhiidae",
                "Sittidae", "Prunellidae", "Cettiidae", "Scotocercidae", "Panuridae"},
    "crow": {"Corvidae"},
    "swallow": {"Hirundinidae", "Apodidae"},
    "pigeon": {"Columbidae"},
    "woodpecker": {"Picidae"},
    "owl": {"Strigidae", "Tytonidae"},
    "raptor": {"Accipitridae", "Pandionidae", "Falconidae"},
    "duck": {"Anatidae"},
    "seabird": {"Laridae", "Stercorariidae", "Alcidae", "Procellariidae", "Hydrobatidae", "Diomedeidae", "Sulidae", "Phalacrocoracidae"},
    "wader": {"Scolopacidae", "Charadriidae", "Recurvirostridae", "Haematopodidae", "Burhinidae"},
    "heron": {"Ardeidae", "Threskiornithidae", "Ciconiidae", "Gruidae", "Phoenicopteridae"},
    "coot": {"Rallidae", "Podicipedidae", "Gaviidae"},
    "gamebird": {"Phasianidae", "Numididae", "Otididae"},
}


def kind_of(L):
    """L is the animal's lineage: {"phylum": ..., "class": ..., "order": ..., "family": ..., "genus": ..., "suborder": ...}."""
    ph, cl, o, fam, g = L.get("phylum"), L.get("class"), L.get("order"), L.get("family"), L.get("genus")
    if cl == "Insecta":
        if o == "Hymenoptera":
            if g == "Bombus": return "bumblebee"
            if g == "Apis": return "honeybee"
            if fam in BEES: return "solitary-bee"
            if fam == "Formicidae": return "ant"
            if fam in {"Cynipidae", "Diplolepididae"}: return "gall-maker"
            if fam in SAWFLIES or L.get("suborder") == "Symphyta": return "sawfly"
            if fam in WASPS: return "wasp"
            return "parasitic-wasp"
        if o == "Diptera":
            if fam == "Syrphidae": return "hoverfly"
            if fam == "Bombyliidae": return "bee-fly"
            if fam == "Cecidomyiidae": return "gall-maker"
            return "cranefly" if fam in GNATS else "fly"
        if o == "Lepidoptera":
            if fam in BUTTERFLIES: return "butterfly"
            return "moth" if fam in LARGER_MOTHS else "micro-moth"
        if o == "Coleoptera":
            if fam == "Coccinellidae": return "ladybird"
            if fam == "Carabidae": return "ground-beetle"
            if fam in WEEVILS: return "weevil"
            if fam == "Chrysomelidae": return "leaf-beetle"
            if fam == "Cerambycidae": return "longhorn"
            if fam in FLOWER_BEETLES: return "flower-beetle"
            if fam in CHAFERS: return "chafer"
            return "beetle"
        if o == "Hemiptera":
            if fam in SHIELD_BUGS: return "shield-bug"
            if fam in APHIDS: return "aphid"
            if fam in HOPPERS: return "hopper"
            return "bug"
        if o == "Odonata": return "dragonfly" if fam in DRAGONFLIES else "damselfly"
        if o == "Orthoptera": return "grasshopper" if fam in {"Acrididae", "Tetrigidae"} else "cricket"
        if o == "Dermaptera": return "earwig"
        if o in {"Neuroptera", "Raphidioptera", "Megaloptera", "Mecoptera"}: return "lacewing"
        if o in {"Trichoptera", "Ephemeroptera", "Plecoptera"}: return "riverfly"
        return "other-insect"
    if cl == "Entognatha": return "other-insect"
    if cl == "Arachnida": return "gall-maker" if fam in {"Eriophyidae", "Phytoptidae"} else "spider"
    if cl in {"Chilopoda", "Diplopoda"}: return "centipede"
    if cl == "Malacostraca": return "woodlouse" if o == "Isopoda" else "crab"
    if cl == "Pycnogonida": return "crab"
    if cl == "Hexanauplia": return "sea-colony"
    if ph == "Mollusca":
        if cl == "Bivalvia": return "bivalve"
        if cl == "Cephalopoda": return "cephalopod"
        if cl == "Gastropoda":
            if fam in SLUGS: return "slug"
            if o == "Stylommatophora" or fam in POND_SNAILS: return "snail"
            if o in SEA_SLUG_ORDERS or fam in SEA_SLUG_FAMILIES: return "sea-slug"
        return "sea-snail"
    if ph == "Annelida": return "earthworm" if o == "Crassiclitellata" else "worm"
    if ph in {"Platyhelminthes", "Nemertea"}: return "worm"
    if ph == "Cnidaria":
        if cl == "Anthozoa": return "anemone"
        if cl in {"Scyphozoa", "Staurozoa"} or fam in SWIMMING_HYDROZOA: return "jellyfish"
        return "sea-colony"
    if ph == "Ctenophora": return "jellyfish"
    if ph == "Echinodermata": return "starfish"
    if ph in {"Bryozoa", "Porifera"} or cl == "Ascidiacea": return "sea-colony"
    if cl in {"Actinopterygii", "Chondrichthyes", "Petromyzonti", "Elasmobranchii"}: return "fish"
    if cl == "Amphibia":
        if o != "Anura": return "newt"
        return "frog" if fam == "Ranidae" else "toad"
    if cl == "Reptilia": return "snake" if fam in {"Colubridae", "Viperidae", "Anguidae", "Natricidae"} else "lizard"
    if cl == "Mammalia":
        if o == "Chiroptera": return "bat"
        if o == "Rodentia": return "squirrel" if fam == "Sciuridae" else "small-mammal"
        if o == "Eulipotyphla": return "hedgehog" if fam == "Erinaceidae" else "small-mammal"
        if o == "Lagomorpha": return "rabbit"
        if fam == "Mustelidae": return "badger"
        if fam == "Canidae": return "fox"
        if fam == "Felidae": return "cat"
        if fam in {"Phocidae", "Odobenidae"}: return "seal"
        if fam in WHALES: return "whale"
        return "deer"
    if cl == "Aves":
        for slug, fams in BIRDS.items():
            if fam in fams: return slug
        return "bird"
    return None
