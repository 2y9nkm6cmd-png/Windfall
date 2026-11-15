# Wildlife drawings checked against outside sources

Each single-animal drawing in Windfall was first made from Claude's memory. This file records which have since been set beside a trustworthy written description, and what was found. **A drawing not listed here has not been checked.**

**What a check is.** The identification notes on the page named are read, and the colours and markings they give are compared with the colour words in the animal's drawing function (`Tools/design/wildlife_species.py` and `wildlife_species2.py`). It is a check of colours and markings. It is not a check of the drawn outline against a photograph: for that, see "Photographs" below.

**Checked against written descriptions: 14 of 203, all birds. Checked against photographs: all 203, on 15 November 2026 (see "Checked against photographs" below).**

## Sources

- **WT garden birds**: The Wildlife Trusts, "Identify garden birds", https://www.wildlifetrusts.org/node/7510
- **WT birds of prey**: The Wildlife Trusts, "Identify birds of prey", as carried by Wildlife BCN, https://www.wildlifebcn.org/node/4002 and Avon Wildlife Trust, https://www.avonwildlifetrust.org.uk/node/2316
- **Sussex WT**: Sussex Wildlife Trust, "How to identify birds of prey", https://sussexwildlifetrust.org.uk/news/how-to-identify-birds-of-prey and "Who's who in the world of Birds of Prey", https://sussexwildlifetrust.org.uk/news/whos-who-in-the-world-of-birds-of-prey
- **RSPB birds of prey**: RSPB, "What's that bird of prey?", https://rspb.org.uk/birds-and-wildlife/whats-that-bird-of-prey

## Birds

| Animal | Source | What the source gives | Found |
|---|---|---|---|
| House sparrow (male) | WT garden birds | Streaky brown above, grey below, chestnut and white in the wing, black bib, grey cap | Agrees |
| Starling | WT garden birds | Glossy black with a purple and green sheen, pale spots in winter | Agrees |
| Blue tit | WT garden birds | Greenish-blue above, yellow below, blue cap, white cheeks, black eye stripes, blue wings and tail | Agrees |
| **Blackbird (male)** | WT garden birds | Black, with a yellow bill and a yellow ring round the eye | **Was wrong: bill and ring were orange. Corrected** |
| Woodpigeon | WT garden birds | Grey above, pink breast, white neck patch, white patches on the wings | Agrees |
| Goldfinch | WT garden birds | Gingery-brown above, pale below, black and yellow wings, black crown, white cheeks, red face | Agrees |
| Chaffinch (male) | WT garden birds | Blue-grey crown, brown back, pink breast | Agrees |
| Great tit | WT garden birds | Green above, yellow below, black head, white cheeks, black stripe down the breast | Agrees |
| Robin | WT garden birds | Brown above, white belly, red breast | Agrees but for one word: the source says red and the breast is drawn orange. ⚠️ Left as it is, as Claude takes a robin's "red" to be orange in life. The belly is drawn cream, an off-white |
| Long-tailed tit | WT garden birds | Black, white and pink above, pale pink below, white head with a broad black stripe above the eye, long black and white tail | Agrees |
| Sparrowhawk (male) | WT birds of prey | Small. Blue-grey back, white underparts barred with orange | Agrees |
| Buzzard | WT birds of prey | Medium. Brown, with broad wings and a short tail | Agrees |
| Kestrel (male) | Sussex WT, RSPB birds of prey | Bluish head, a dark moustache mark, pale underside with black speckles not bars, a long tail with a black band at the end | Agrees |
| Red kite | Sussex WT | Rich red-brown with a paler head, a black-tipped yellow bill, a pale patch under each wing before the black tip, a long deeply forked tail | Agrees |

## Not yet checked against a written description

Every other bird, every mammal, amphibian and reptile, and every insect, spider, snail and slug. All of them have since been looked at beside photographs (next section).

## Checked against photographs, 15 November 2026 (19:40 to 20:20)

**Every one of the 203 single-animal drawings was looked at beside photographs**, by Claude, in the "photo check" chat linked to William's Mac. This is a check of the drawn shape, colours and markings by eye. ⚠️ It is Claude's eye, not William's, and not a specialist's.

**The photographs.** For each animal, the first five of the photos iNaturalist itself shows for the species (its "taxon photos"), 1,656 in all. For insects, amphibians and birds also up to five research-grade records marked as larva, pupa, nymph, egg, female or juvenile. They are on the Mac in `~/Developer/windfall-photo-check/photos`, with each photographer's name and licence in `credits.csv` beside them. **They were looked at and not copied. None is in the app or in this repository.** `Tools/design/photo-check/` holds the two scripts.

**Found wrong and corrected (27):**

| Animal | What the photographs showed | Change |
|---|---|---|
| Marmalade hoverfly | A dark bronze thorax | Thorax was tan |
| Large, small and green-veined white | Three different butterflies | They shared one drawing. Now three: bold black tips and two spots, a small grey tip, and grey veins |
| Holly blue | Pale sky blue | Was lilac |
| Violet ground beetle (both) | Black, violet only at the edges | Was violet all over |
| Stag beetle | Dark chestnut wing cases | Were crimson |
| Black-headed cardinal beetle | A black head | Shared the common cardinal's red head |
| Migrant hawker | Blue spots, brown thorax | Shared the southern hawker's green |
| Broad-bodied chaser | A very broad abdomen, dark wing bases | Broader, bases darker |
| Beautiful demoiselle | The male's wings are dark blue | The drawing was the female. She is now under "Female" |
| False widows (both) | Dark brown | Were crimson |
| Leopard slug | Black spots and stripes | Had faint brown dots |
| Blue tit | A small dark chin | Had a great tit's bib |
| Starling | Dark wings | Wings were pale brown |
| Swallow | A dark band under the red throat | Added |
| Swift | Sooty brown, scythe wings | Was pale brown. Redrawn |
| Grey heron | Grey flanks, white neck and head | Body was white |
| Red kite | Fingered black wing tips, white patches, pale head | Redrawn with the new flight figure |
| Stoat and weasel | The weasel has no black tail tip, and is smaller and redder | They shared one drawing. Now two |
| Bank vole | Chestnut back, ears showing | Shared the field vole's |
| Common frog | Olive-brown with a dark mask | Was green |
| Marsh frog | Green with a pale line down the back | Shared the common frog's |
| Natterjack | A yellow line down the back | Shared the common toad's |
| Smooth and palmate newt | Olive-brown, dark spots, orange belly | Was green with an orange stripe |
| Slow-worm | Bronze-brown | Was yellow |

**Looked at and left (176).** The rest agreed well enough at this size. Noted but not changed: the hairy shield bug's shoulders are purple-brown where the drawing has olive, the wasp beetle's legs are orange, the bullfinch's breast is a softer pink, and the common and soprano pipistrelle, the two seals, the three dolphins, the brown and mountain hare, and the red and sika deer still share a drawing each.

**Added the same day, each drawn beside its photographs:** the early mining bee, the red ants (three *Myrmica*), the yellow meadow ant and the large blue.

## More than one drawing of an animal (15 November 2026)

72 animals now have other drawings, 96 in all, made beside the life-stage photographs where there were any: 15 birds in flight, 8 females and 3 other plumages of birds, a perched red kite, a roe doe, 8 insects of the other sex, 9 butterflies with their wings closed, 14 caterpillars, 5 chrysalises, pupae and cocoons, 5 ladybird larvae and 2 pupae, 7 grubs and other larvae, a row of eggs, 1 shield bug nymph, 3 kinds of dragonfly and damselfly nymph, frog and toad spawn and tadpoles, and a newt larva. ⚠️ The flight drawings and the females of the birds were made from the species' own photos, few of which show a bird overhead, and from Claude's memory of the rest.

## Photographs: a route that works, proved at 19:33 on 15 November 2026

The first check above was of words only. **A drawing can also be set beside photographs, when the chat is linked to William's Mac.** One photo was taken the whole way as a test:

1. On the Mac (Desktop Commander's shell), ask iNaturalist for photos of the animal and download one with `curl`. The Mac can reach the web freely. Claude's cloud workspace cannot.
2. Save it in `~/Developer/windfall-photo-check`, a folder William has let the chat read (he is asked once in each chat).
3. Bring it into the chat with the tool that copies a file from the Mac (`device_stage_files`), and look at it.

**What the test taught.** The photo asked for was the most-liked research-grade UK blackbird with an open licence. It was a white blackbird. **The most-liked photos are the oddities.** For a typical animal use the photo iNaturalist itself shows for the species (`default_photo` from `https://api.inaturalist.org/v1/taxa/<id>`), and three or four recent research-grade records beside it, not the most liked.

**How to do all 203.** On the Mac, a script that for each animal downloads the species' own photo and three recent ones at the small size (about 500 points across, some 40MB in all), keeping each photographer's name and licence in a file beside them. Then one picture for each animal with its drawing beside its photos, looked at a group at a time. The photos are for checking only. They are other people's work and do not go into the app or the repository.

## For whoever carries on

- The web tool opens a page only if its address came back from a search or was given by William. An address found by following a link on a page is refused. So each animal needs a search of its own, or a page that describes many at once.
- Pages that describe many at once, and are worth searching for by title: The Wildlife Trusts' "How to identify owls", "Identify gulls", "Identify UK woodpeckers", "How to identify swifts, swallows, sand martins and house martins", "How to identify bumblebees", "Identify garden butterflies", "Identify shieldbugs" and "Identify UK snakes". Butterfly Conservation and the Bumblebee Conservation Trust have their own.
- Add a row here for each animal as it is checked, and note any correction in `CHANGES.md`.
