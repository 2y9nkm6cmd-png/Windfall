# Design

Everything about how Windfall looks is kept here.

| Folder or file | What it holds |
|---|---|
| `Reference/` | Pictures and files William has sent, each with the date it arrived. These are the originals and are never edited |
| `Icons/` | One small SVG drawing for each icon in the app. These are the masters: edit one and the app follows |
| `colours.json` | Every named colour, each with a light-mode and a dark-mode value |
| `Archive/` | Anything that has been replaced or set aside, kept in case it is wanted again |

## The rules

1. **Every file William sends goes into `Reference/`**, named with the date and what it is.
2. **When a newer version arrives, the old one moves to `Archive/`.** Nothing is deleted.
3. **Ideas that were built and then set aside go to `Archive/` too**, with a note saying what they were and how to bring them back.

## Changing a colour or an icon

1. Edit `colours.json`, or replace the icon's file in `Icons/`.
2. From the top of the repository run:

   ```
   python3 Tools/design/build_design_assets.py
   ```

3. Build the app. No Swift code needs to change.

The script copies the colours and icons into `Windfall/Assets.xcassets`, which is the app's own store of pictures and colours. Do not edit the `Colours` and `Icons` folders in there by hand, because the script rebuilds them each time.

## Two kinds of icon

- **Outline icons** are drawn only in black. The app ignores the black and paints the shape in whatever colour it needs, so one file works in light and dark mode.
- **Colour icons**, such as the butterfly, have other colours in them and are shown as drawn. Their dark green outline (`#06472A`) is swapped for pale green in dark mode, which the script does by itself.

Icons are drawn on a 24 by 24 grid with a line 1.6 wide and rounded ends.

## What is in Reference

| File | What it is |
|---|---|
| `2026-11-12 today-three-devices.png` | William's concept picture of the Today screen on Mac, iPad and iPhone |
| `2026-11-12 icon-set-reference.png` | The icon set William said was "closer to what I was after". The style reference for icons |
| `2026-11-12 eira-logo-sheet.svg` | The fine-line snowdrop in five sizes, light and dark. The app's snowdrop is taken from this |
| `2026-11-12 icon-sheet-first-draft.svg` | The first SVG icon sheet. William was "not 100% happy with all icons" |
| `2026-11-12 note-partly-cloudy-and-sun.png` | William's note on the Partly cloudy icon in the first draft |
| `2026-11-12 note-windfall-branch.png` | William's note on the branch icon: "This is weird" |
| `2026-11-12 screenshot-sidebar-highlight.png` | The sidebar as first built, sent with "more of that liquid glass animation as it moves between sections" |
| `2026-11-12 screenshot-eira-bar-short-of-sidebar.png` | Eira's bar stopping short of the sidebar, sent with "roll right across to the sidebar" and "a little bounce" |
| `2026-11-12 screenshot-plants-with-eira-bar.png` | The plant library on the Mac with Eira's bar open, sent with the request to type straight away |
| `2026-11-12 screenshot-year-page-before.png` | The Year page as a grid of solid blocks, before any redesign. Sent with "Dots in each month might be good" |
| `2026-11-12 music-tab-bar-lens.mp4` | William's screen recording of the bottom bar in Apple's Music app: the moving lens he wants for the sidebar. Made smaller to keep the repository light. He has the original |
| `2026-11-12 music-tab-bar-lens-frames.jpg` | Still frames from that recording, three a second, for looking at without playing it |
| `2026-11-12 screenshot-plants-before-filters.png` | The plant library before its filters, sent with "filtered by permaculture layer, Fruit, Vegetables, Season of (sowing, fruiting, flowering, etc), Plant family (brassica, etc)" |
| `2026-11-12 screenshot-gardens-list-before.png` | The Gardens page as a plain list of links, sent with "Can these look more like the today page?" |
| `2026-11-12 screenshot-wildlife-list-before.png` | The Wildlife page as a plain list of links, sent with the Gardens one |
| `2026-11-12 screenshot-journal-entry-form.png` | The journal's diary entry form, sent with "This doesn't look too nice right now". William's idea: a journal that works like a conversation with Eira |
| `2026-11-13 screenshot-today-mac-before-rearranging.png` | Today on the Mac with the cards in fixed places, sent with "rearrange the home view by tapping and holding the object (like the This month box), and it wiggling to rearrange" |
| `2026-11-13 screenshot-earthworm-count-setup-mac.png` | The earthworm count's setup as a standard form on the Mac, sent with "Can you make the interface a bit nicer for this please" |
| `2026-11-13 screenshot-earthworm-count-running-mac.png` | The earthworm count while counting, sent with the same request |
| `2026-11-13 screenshot-sidebar-mac.png` | The sidebar, sent with "two finger scroll on the mac on the side bar please and the glass selector moves" |
| `2026-11-13 screenshot-new-sighting-form-mac.png` | The new sighting form on the Mac, sent with "A lot of the buried menus are looking quite different to the top level interface" and a note about the bars at the top and bottom of the windows |
| `2026-11-13 screenshot-new-sowing-form-mac.png` | The new sowing form on the Mac, sent with the same note |
| `2026-11-13 screenshot-harvest-picker-mac.png` | "What did you harvest?" with one sowing and a tall empty window, sent with the same note |
| `2026-11-13 screenshot-fit-count-setup-mac.png` | The FIT Count's setup on the Mac, with bare bands above and below the form |
| `2026-11-13 screenshot-garden-switch-half-width-mac.png` | The Allotment and Permaculture garden switch at half the Mac window's width: squarer corners than the cards, wider than them, and no sliding glass |
| `2026-11-13 screenshot-eira-bar-over-card-edge-mac.png` | Eira's bar running out past the edge of the card above it, sent with "it should sit slightly within it" |
| `2026-11-13 screenshot-journal-filter-menu-centre-mac.png` | The Journal on the Mac with its filter menu in the middle of the bar at the top, sent with "Is there a reason that this menu is in the middle of the top bar?" |
| `2026-11-13 screenshot-diary-entry-form-mac.png` | The diary entry form on the Mac, sent with "the journal entry isn't very chat interface like. Is there a way that we can add all these options into a sleeker chat like interface?" |
| `2026-11-13 screenshot-plant-page-garlic-mac.png` | Garlic's page as a standard form on the Mac, sent with "Can you make these more card like as well. You could use the overall sections that I used in my spreadsheet to create sections" |
| `2026-11-13 screenshot-companions-list-mac.png` | Garlic's companions as one long list, sent with "make the companion planting two columns and then if the window is narrow it has a top bar that has the friends and enemies" |

## What is in Archive

| File | What it is |
|---|---|
| `2026-11-12 Eira opens by rolling along.md` | Eira's button rolling like a coin. William kept the wind-blown version |
