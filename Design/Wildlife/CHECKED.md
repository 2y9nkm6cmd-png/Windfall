# Wildlife drawings checked against outside sources

Each single-animal drawing in Windfall was first made from Claude's memory. This file records which have since been set beside a trustworthy written description, and what was found. **A drawing not listed here has not been checked.**

**What a check is.** The identification notes on the page named are read, and the colours and markings they give are compared with the colour words in the animal's drawing function (`Tools/design/wildlife_species.py` and `wildlife_species2.py`). It is a check of colours and markings. It is not a check of the drawn outline against a photograph: for that, see "Photographs" below.

**Checked so far: 14 of 203, all birds, on 15 November 2026.**

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

## Not yet checked

Every other bird (40), every mammal, amphibian and reptile, and every insect, spider, snail and slug. The raven, hooded crow and chough, drawn at 19:25 on 15 November, are among them.

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
