# 13 November 2026, afternoon: This week, the sheets, the sliding switch and the sidebar

**On the `today-rearrange` branch**, after the morning's work below.
**None of it has been built on the Mac or seen running.** William was
at school and the Mac could not be reached. It passes the checks that
run without the Mac (every file reads as valid Swift, 323 logic tests
pass). Those do not build the screens. Expect things to put right when
it is first built, and treat how everything here looks as untried.

## 14 November 2026, 16:50: a conversation grows out of Eira's bar

**On the branch `eira-bar-expand`, made from `main` (`c89c037`), with `main` (`0ba7173`) merged in.** Built for the Mac and the iOS Simulator with no errors (`eb4-mac.log`, `eb4-sim.log`, in `DerivedData/Windfall-eirabar`). 598 logic tests pass, 2 of them new. Seen as still pictures with the example garden on an 11-inch iPad Pro: the journal's conversation and Eira's chat each standing in the panel, in light and dark, and the bar at rest on Today and on Journal (`shots/eb2-*` and `eb3-*`). **Not seen: an iPhone, and the Mac's own window.** The Mac was too busy with other chats' builds for a second simulator to start. **Nothing has been pressed by hand, and Claude cannot see the panel move.** William judges the growing and the sinking back.

**Why.** William, 15:45, with a picture of the Journal page on the Mac: the journal's conversation open as a sheet in the middle of the window, with its own box to type in, and Eira's bar with a second box idle underneath. "Can we make it so that chat expands from the Eira bar, rather than opening up a new window?" His picture is in `Design/Reference`, `2026-11-14 screenshot-journal-sheet-over-eira-bar-mac.png`.

### 1. What you see

On a Mac and an iPad:

- Send something from Eira's bar, press its microphone or book button, or give it a photo on the Journal page. The bar itself grows upwards into a panel of glass, and the conversation is inside it. The box to type in runs along the panel's foot, exactly where the bar was, so the bar seems to become the box.
- The page behind is not dimmed and still works. You can scroll it, or go to another page, with the panel still up.
- **Done**, or the Esc key, sinks the panel back into the bar.
- The button with two arrows makes the panel larger: the bar's whole width and the page's whole height. The app remembers which size you left it at.
- On a Mac the keyboard goes straight to the panel's box, so typing carries on. Afterwards it goes back to the bar.
- Photos dropped on the Journal page now open in the panel too. That page used to bring up a sheet of its own.

Both conversations use it: the journal's, and Eira's own chat. "It was a question. Ask Eira instead" now swaps what is in the panel at once. As a sheet it had to close one window, wait and open another.

**Not changed:** an iPhone still slides a sheet up, which on a screen that size is nearly the same thing. Search, the card that asks what to do with a photo away from the Journal page, and the Note button on Today are still sheets everywhere.

### 2. How the panel grows (`EiraFloatingBar.swift`)

A sheet is a separate window that SwiftUI puts on top of everything. The panel is not. It is an ordinary view drawn in the same place as the bar, whose height is changed with an animation:

```swift
.frame(height: panelIsUp ? EiraPanel.height(room: room, isLarge: panelIsLarge) : closedSize,
       alignment: .bottom)
.clipShape(.rect(cornerRadius: corner))
.glassEffect(.regular.tint(Theme.paper.opacity(0.8)), in: .rect(cornerRadius: corner))
.onAppear(perform: raisePanel)
```

- `panelIsUp` is a true-or-false value the bar keeps (`@State`). The line reads: "if the panel is up, be as tall as the sum says. If not, be as tall as the bar."
- The panel is first drawn with `panelIsUp` false, so it starts the size and shape of the bar. `.onAppear` runs `raisePanel` the moment it is on screen, and that sets `panelIsUp` to true inside `withAnimation`. SwiftUI then draws every size in between, which is the growing.
- `alignment: .bottom` keeps the foot of the conversation on the bar's line while the rest is uncovered above it.
- `corner` goes from half the bar's height (a capsule) to 28 points, so the round ends of the bar ease into the panel's corners.
- `.clipShape` stops anything being drawn outside that shape while it is small. `.glassEffect` is the same glass the bar is made of, tinted with the paper's colour so the writing stays easy to read over a busy page.
- **Done** runs `lowerPanel`, which sets `panelIsUp` back to false with an animation. Only when that has finished (`completion:`) is the conversation let go.

Which conversation is in the panel is worked out from two values the bar already had, `journalRequest` and `eiraRequest`. They used to open sheets. `sheetOnly(...)` now hands the two `.sheet` lines a value that is always empty wherever the bar grows in place, so no sheet appears, and `openInPanel` reads the same two values to decide what to draw.

### 3. Where the bar lives (`MainTabView.swift`)

The bar used to sit inside a strip at the foot of the page (`safeAreaInset`). A strip 60 points tall has no room for a panel, and a view hung outside its own space may not take taps. So:

- The strip is still kept clear, with nothing in it (`Color.clear`), so a long list can still be scrolled out from under the bar.
- The bar is now in an **overlay**: a layer on top of the page, given the page's whole space. It sits at the foot of that space and grows into the rest of it. The empty part of the layer takes no taps, so the page underneath works as before.

`EiraFloatingBar(growsInPlace: true)` is how the Mac and iPad layout asks for the panel. The iPhone layout does not ask, and is as it was.

### 4. The parts they share (`EiraPanel.swift`, new)

- `EiraPanelControls`: what a conversation is handed when it is in the panel. It holds the larger-size switch, whether to take the keyboard, and the function that closes the panel.
- `EiraPanel`: the sizes in one place. The panel is at most 760 points wide and 620 tall unless made larger, and never taller than the page.
- `PanelPage`: the heading a conversation wears in the panel. It does for the panel what `SheetPage` does for a sheet: title, the line under it, the larger-size button and Done.

### 5. The two conversations (`JournalChatView.swift`, `EiraChatView.swift`)

Each takes an optional `panel:`. Given one, it wears `PanelPage`. Given none, it is a sheet or a page exactly as before, so Today's Note button, the iPhone and every other way in are untouched.

- In the journal's conversation the box to write in loses its own card of glass when it is in the panel, because glass laid on glass turns murky. A fine line above it takes the card's place.
- Eira's chat has no bar along the top in the panel, so its Options menu moved into the heading as a button with three dots. The four things in the menu are now written once (`optionsItems`) and used in both places.
- Eira's chat hugs the foot of the panel (`.defaultScrollAnchor(.bottom)`), so it stays put while the panel grows.
- Each box has a `@FocusState`, which is how a view asks for the keyboard.

### 6. Photos dropped on the Journal page (`EiraScreen.swift`, `JournalViews.swift`)

The Journal page and the bar are separate views, so the page cannot open the bar's panel directly. Both already share `EiraScreen`, the tracker that tells Eira what is on screen. It gained a small pigeonhole: the page puts dropped photos in it (`handToBar`), and the bar, which watches it, takes them out (`takePhotosForBar`) and opens the panel. They are handed over once and then gone, so the same photos cannot start two entries. Two new logic tests cover that.

### Checking aid

`-demoOpen bar-journal` opens the journal's conversation from Eira's bar as soon as the bar appears, as `-demoOpen eira` does for her chat. With `-startSection journal` it gives the picture William sent, in its new form.

### ⚠️ CHECK: choices that are Claude's

1. The panel is glass tinted with the paper's colour at 80%. The page shows through faintly.
2. It is at most 760 points wide and 620 tall, on the left above where the snowdrop sits, with a larger size on the button.
3. The page behind stays live and is not dimmed. Clicking on the page does not close the panel. Only Done and Esc do.
4. The panel stays up when you go to another page.
5. An iPhone keeps its sheets.
6. Search and the photo card are still sheets.

### Not built

- The box in the panel is the conversation's own, not the bar's. They sit in the same place, so it reads as one, but the snowdrop and the bar's search and book buttons are not in the panel.
- Today's Note button and the Journal offer on Today still open the journal's conversation as a sheet.
- Dragging the panel's top edge to resize it.
- The panel does not shrink to fit a short conversation.
## 14 November 2026, 16:26: the sidebar's lens follows the fingers again

**On the branch `sidebar-scroll-follows-fingers`, made from `main`.** One line in `MainTabView.swift`, in `lensScrolled(by:)`.

**Why.** William, 16:22, with a picture of the sidebar: "Can you return the scrolling of this bar to the previous way it was, it's not working as is right now." The sidebar's scrolling has been changed once since it was written: at 22:31 on 13 November the lens was made to move as a list scrolls (fingers pushed up went down the list). This puts back the way before that: two fingers moving down carry the lens down, like a drag.

```swift
let fingers = scroll.isDirectionInvertedFromDevice ? scroll.scrollingDeltaY : -scroll.scrollingDeltaY
```

- `scroll.scrollingDeltaY` is how far the Mac says this piece of the scroll went, up or down.
- `isDirectionInvertedFromDevice` is true when "natural scrolling" is on in System Settings. It is on for William's Mac (the setting has never been changed from Apple's default).
- `a ? b : c` reads "if a, then b, otherwise c". With natural scrolling on the number is used as it is. With it off the Mac reports the opposite sign, so the minus turns it back. Either way fingers down means lens down.
- A mouse wheel goes through the same line, so its direction is turned too.

Nothing else about the sidebar is changed: the gearing (0.6), settling on the nearest row and one row for each click of a wheel are as they were.

**Not tried by hand.** A script cannot make a two-finger scroll.

## 14 November 2026, 16:25: the sighting form's plant list has a row of letters to jump by

**On the branch `plant-letter-jump`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`pl1-mac.log`, `pl1-sim.log`, in `DerivedData/Windfall-plantjump`). 596 logic tests pass, 6 of them new. Seen as still pictures with the example garden: the list open and jumped to M on an iPhone 17 (light) and an 11-inch iPad Air, and jumped to S on the iPhone in dark (`shots/pl1-*`). **Not tried by hand: pressing a letter, choosing a plant, and the Mac's own window.** The pictures were made with the checking aid below, which jumps the same way a press on a letter does but without the glide.

**Why.** William, 15:50, with a picture of the sighting form's "Which plant" menu open: "could you make it so that you can select letters of the alphabet for the first letter so that you can jump to those plants first." The menu held every plant in the library, 376 of them, in one list that always opened at the top.

### 1. What you see

"Which plant" on the sighting form is still a box showing the chosen plant. Pressing it now opens a panel in place of the menu:

- **A row of letters**, A to Z. Press one and the list glides to the plants that begin with it. A letter with no plants (Q and X in the library today) is greyed out and cannot be pressed.
- **The list**, with "None" first and then a small heading for each letter. The chosen plant has a tick and a green band. Press a plant and the panel closes with it chosen.
- It opens at the letter of the plant already chosen, so the tick is in view.
- On an iPad or a Mac the panel is a popover pointing at the box. On an iPhone it slides up as a sheet.

**The order has changed a little.** The menu was in the order of the plants' names alone, so varieties of one plant came in no order (Apple: Spartan, Pigs Snout, Pendragon). The list is in order of name and then variety, so they now run Jonagold, Pendragon, Pigs Nose III, Pigs Snout.

### 2. The workings (`PlantFilter.swift`)

A new piece, `PlantLetters`, with nothing in it that draws, so it can be tested without a screen.

```swift
static func letter(for name: String) -> String {
    guard let first = name.first(where: { $0.isLetter || $0.isNumber }) else { return other }
    let plain = key(String(first)).uppercased()
    return alphabet.contains(plain) ? plain : other
}
```

- `name.first(where:)` finds the first character that is a letter or a number, skipping anything in front, such as a quotation mark.
- `guard ... else { return other }` is the way out when there is none: the name goes under "#".
- `key(...)` drops an accent and `uppercased()` makes a capital, so "é" becomes "E".
- The last line asks whether that is one of A to Z. A number is not, so "3 Sisters" goes under "#" too.

`PlantLetters.groups` puts the whole list in order and returns one `LetterGroup` for each letter in use, each holding its plants. It is handed two small functions, one that gives an item's name and one its variety, so the app can give it plants and the tests plain text.

### 3. The panel (`PlantChooser.swift`, new)

Two views. `PlantChooser` is the box on the form. `PlantChooserList` is the panel.

```swift
ScrollViewReader { scroller in
    ...
    Button {
        withAnimation(.smooth(duration: 0.25)) {
            scroller.scrollTo(letter, anchor: .top)
        }
    } label: { Text(letter) }
    ...
    Text(group.letter)
        .id(group.letter)
}
```

- A `ScrollViewReader` wraps a scrolling list and hands over `scroller`, which can move the list to any view inside it that has been named.
- `.id(group.letter)` is the naming: each letter's heading is named by its letter.
- `scroller.scrollTo(letter, anchor: .top)` moves the list until that heading is at its top. `withAnimation` makes it glide.
- The list is an ordinary stack, not a "lazy" one. A lazy stack builds a row only as it comes into view, and has to guess how far down an unbuilt row is, so a jump can land short. With every row built the jump is exact, and a few hundred rows of text cost little.
- The letters sit in a `LazyVGrid` with "adaptive" columns: as many 30-point letters to a line as fit, the rest on the next line.

### 4. One look for both kinds of box (`ObservationViews.swift`)

The look of the box (the words, the small arrows, the hairline) was written inside `ChoiceMenu`. It is now a view of its own, `ChoiceLabel`, which `ChoiceMenu` and `PlantChooser` both draw, so "Which plant" still matches "Life stage" and "Group" above it and cannot drift from them.

### Checking aid

`-demoOpen sighting -demoPlantLetter M` opens the sighting form, then the list of plants a moment later, already at M (`DemoGarden.jumpsToPlantLetter`). Example garden only.

### Not done, and for William to say

- **The row of letters is not a `GlassSwitch`.** The rule is that every bar of choices is one. Claude's reading: this is a row of buttons to jump by, not a choice that stays made, and 26 pieces would not fit a sliding switch. William to confirm or change.
- **No search box in the panel.** Not asked for. It would be a small addition.
- **Choosing "None" does not clear a plant's name that was filled in from "Known from your reference data" without a plant record behind it.** The old menu behaved the same way. Left alone.
- The sowing form and the other forms that pick a plant were not looked at. Only the sighting form's menu was changed.

## 14 November 2026, 15:50: swiping between months, a list of months, and a back swipe that follows the fingers

**On the branch `year-month-swipe`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`mv5-mac.log`, `mv5-sim.log`, in `DerivedData/Windfall-month`). 590 logic tests pass. Seen as still pictures with the example garden: a month's page opening on the right month, the forward and back arrows turning it (December on to January, January back to December) and a month chosen from the list, on a 13-inch iPad Pro and an iPhone. **Not tried by hand, and a still picture cannot show them: a swipe with a finger, the list of months open, and everything on the Mac's trackpad.** The Mac build was started hidden with the example garden and did not crash. Nobody has yet seen the Mac's back swipe move.

**Why.** William, 15:31: "when you're in the month view, you can swipe between the months and tap the month name to bring up a list of the months so that they can be tapped to quickly move to another month." And at 15:33, with a picture of an iPhone's Settings part-way through a swipe back: "When you swipe back to the previous screen can you make it so that the screen swipes over like in this screenshot".

### 1. Swiping between months (`YearMonthView.swift`)

**What you see.** On a month's page, a finger swiped sideways turns to the next or the last month, and the whole page slides, like a calendar. December leads on to January. On a Mac, two fingers swiped sideways on the trackpad do the same, one month for each swipe.

**How.** The months are laid side by side in a row that scrolls sideways:

```swift
ScrollView(.horizontal) {
    LazyHStack(alignment: .top, spacing: 0) {
        ForEach(0..<YearCalendar.monthPageCount, id: \.self) { page in
            monthPage(YearCalendar.month(atPage: page), from: chosenFrom, isWide: isWide)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollPosition(id: $shownPage)
```

- `ScrollView(.horizontal)` is a strip that scrolls sideways. `LazyHStack` lays its contents in a row and only builds a page when it is about to slide into view.
- `ForEach` makes one page for each number from 0 up to `monthPageCount`, which is 240: the twelve months twenty times over. That is what lets December lead on to January. `YearCalendar.month(atPage:)` turns a page's number into its month with a remainder: page 12 is January again.
- `.frame(width:height:)` makes each page exactly as big as the screen's space, so one page fills it.
- `.scrollTargetBehavior(.paging)` makes the strip stop on a whole page, never between two.
- `.scrollPosition(id: $shownPage)` ties the strip to the value `shownPage` both ways. A swipe changes the number. Changing the number scrolls the strip. The arrows and the list of months work by changing it.
- Each page is its own up-and-down `ScrollView`, with its own name and cards.

**On a Mac** the strip is told not to scroll by itself (`.scrollDisabled(true)`), and a small watcher, `MonthSwipes`, reads the trackpad the way `BackSwipe` does and turns one page for each sideways swipe of 60 points or more. Left to itself, the Mac sends a sideways scroll to the page under the pointer, which only scrolls up and down.

**The clash, and William's answer.** On a Mac a two-finger swipe to the right already means "go back". William was asked which it should do on a month's page and chose: **turn the month**. So while a month's page is showing, the back swipe stands aside (`PointerClaims.monthPageIsOpen`), and the back button at the top left goes back to Year.

### 2. The month's name is a list of months

The name is now a button with a small arrow beside it. Pressing it lists the twelve months with a tick by the one showing and "(this month)" beside today's. Choosing one goes straight there, by the shortest way round, with no slide. It is a `Menu` holding a `Picker`, the same pair the "Fruit, veg…" button uses.

### 3. On a Mac, the page follows the fingers when you swipe back (`PageZoom.swift`, `Theme.swift`)

**Before.** Two fingers swiped right went back all at once when they had travelled 90 points.

**Now.** The page on top moves with the fingers, with a soft shadow down its left edge. Lift the fingers after 110 points or more and it slides off to the right and the page before appears. Lift sooner and it springs home.

**How.** `BackSwipe` already listened to the trackpad. It now keeps a number, `pull`, for how far the fingers have dragged the page:

```swift
pull = max(0, travel)
```

and every page carries a new modifier, `BackSwipeSlide`, which draws the page that far across:

```swift
let across = BackSwipe.shared.pulledPage == id ? BackSwipe.shared.pull : 0
content
    .offset(x: across)
```

- `BackSwipe` is marked `@Observable`, so any view that reads `pull` is drawn again each time it changes. That is the whole of the movement.
- `.offset(x:)` draws a view somewhere else without moving anything around it.
- Only the page being dragged moves: every other page reads 0.
- The swipe is decided once, after the fingers have moved 14 points: to the right and at least twice as far across as up or down. Otherwise it is ordinary scrolling and is left alone.
- `paperScreen()` now puts the modifier on after the paper background, so the paper moves with the page.

**⚠️ What it does not do.** In William's picture the screen before is in view underneath as the top one slides. **Here there is blank paper underneath, and the page before appears when the top one has gone.** On a Mac, SwiftUI takes the page before off the screen altogether while another is on top, so there is nothing there to show. Showing it would mean keeping a picture of each page as it is left. Not built: it needs William trying it on the trackpad between attempts.

An iPhone and iPad already do the full thing by themselves and are unchanged.

### Also

- Checking aids: with `-demoMonth 4`, `-demoMonthStep on` or `back` presses an arrow, and `-demoMonthThen 9` chooses September from the list.
- William's picture is in `Design/Reference`.
- Tests: 4 new, 590 in all, for the pages: the months going round, opening in the middle, the shortest way to a month and never running off either end.

**Choices that are Claude's.** ⚠️ CHECK each.

- A sideways swipe of 60 points turns a month on the Mac, and one swipe turns one month however far the fingers go.
- Choosing from the list jumps with no slide.
- 110 points to go back, where it was 90, and only when the fingers lift.
- The shadow on the sliding page, and no rounded corner on it.

## 14 November 2026, 15:24: a month of the Year page, opened up

**On the branch `year-month-view`, made from `main`.** Built for the Mac and the iOS Simulator with no errors (`mv1-mac.log`, `mv1-sim.log`, into a build folder of its own, `DerivedData/Windfall-month`). 586 logic tests pass. Looked at running with the example garden as still pictures: April on a 13-inch iPad Pro, dark (two columns), November on an iPhone, light (one column), and the Year page itself (`shots/mv1-*`). **Not tried by hand: pressing a month's name, the two arrows, "Show all", and the Mac's own window.** The pictures were made with the checking aid below, which opens the month's page the same way a press does.

**Why.** William, with a picture of the Year page: "Can you make it so that when you click or tap the month at the top of this page, you can see the month bigger and see what needs to be planted that month".

**What you see.**

1. **Each month's name at the top of the Year page is now a button.** On a Mac, and on an iPad with a trackpad, the name lights up under the pointer. Pressing it opens that month on a page of its own.
2. **The month's page** has the month's name in the large serif letters, a line that counts it up ("14 to sow or plant · 31 to harvest · 3 in flower") and **a card for each job**: Sow indoors, Sow outdoors, Plant out, Harvest and Flowering. Each card lists the plants that job can be done for in that month. From 720 points wide, sowing and planting are on the left and harvest and flowering on the right. Narrower, one column with sowing and planting first.
3. **Beside each plant** is one of: "This month only", "Last chance" (the last month of its stretch), "Starts now" (the first), or how long it can wait, such as "to March". The pressing ones are at the top of each card. A flower has a "Last month", not a last chance.
4. **The two round arrows** by the name step to the month before and the month after, round the end of the year.
5. A card lists ten plants and then offers "Show all 31". Tapping a plant opens its page, as on the Year page.
6. The page keeps to what the Year page lists: plants marked as growing, and the kind chosen on the "Fruit, veg…" button, which is then named above the month ("This month · Vegetables only").

**How it is built.**

*The sums* are in `YearCalendar.swift`, with no screen code, so they are tested. The one that decides the words beside a plant:

```swift
static func place(of month: Int, in months: [Int]) -> MonthPlace? {
    let chosen = Set(months.filter { (1...12).contains($0) })
    guard chosen.contains(month) else { return nil }
    let hasBefore = chosen.contains(monthBefore(month))
    let hasAfter = chosen.contains(monthAfter(month))
    if !hasBefore && !hasAfter { return .onlyMonth }
    if !hasAfter { return .lastChance }
    if !hasBefore { return .opening }
    return .during
}
```

- It is handed a month and the months a job can be done in, and looks at the month's two neighbours. With February to April: February has nothing before it, so it is the opening. April has nothing after it, so it is the last chance.
- `Set` is a bag in which each thing appears once and "is this in it?" is quick to ask.
- `guard ... else { return nil }` is a way out at the top: if the month is not one of the job's months there is nothing to say, and `nil` means "no answer". The `?` after `MonthPlace` says the answer may be missing.
- `monthBefore` and `monthAfter` go round the end of the year, so December and January are neighbours and October to February counts as one stretch.
- `MonthPlace` is an `enum`, a short list of the only answers allowed. Each has a number, 0 to 3, and the page's list is sorted by it, which is what puts the pressing plants first.

`YearCalendar.entries(for:in:from:)` uses it to make one job's list for one month, and `lastMonth(from:in:)` finds where a stretch ends, for "to March".

*The page* is `YearMonthView.swift`, new. It is drawn like the other pages: `ScreenHeader` for the name, glass cards, the Year page's coloured dot for each job. It holds the month in a `@State` value, `shownMonth`, which is a value the page owns and may change. The arrows change it and SwiftUI redraws the cards.

*Opening it* (`YearView.swift`). The Year page has a new `@State` value, `openMonth`, which is empty until a month's name is pressed:

```swift
.navigationDestination(item: $openMonth) { month in
    YearMonthView(month: month, plantKind: plantKind)
}
```

This says: whenever `openMonth` holds a month, slide in that month's page, and when the page is left, empty it again. The `$` hands SwiftUI the value itself to change, not a copy of it. Each name in the heading is a `YearMonthButton`, a small view of its own so that it can remember whether the pointer is over it.

**Changed on the Year page itself.** The month names are 32 points tall where they were 28 (40 on an iPhone), to give a finger more to press. VoiceOver used to skip the heading. It now reads each month as a button.

**Checking aid.** `-demoYear YES -demoMonth 4` opens April's page as soon as the Year page appears.

**Tests.** 11 new, 586 in all: where a month falls in a stretch, round the new year and all year; the last month of a stretch; the order of a month's list; the words beside a plant.

**Not done, and choices that are Claude's.** ⚠️ CHECK each.

- The words "Last chance", "Starts now", "This month only" and "Last month".
- Pressing plants first in each card, then A to Z. The Year page's own order (by family) is not used.
- Harvest and Flowering are on the page as well as the three planting jobs. William asked for "what needs to be planted".
- The page does not follow the Year page's search box or its job buttons. It always shows all five jobs.
- It goes by the plant library's months only. It does not know what has already been sown this year, so a plant sown in March still shows under April. "This week" on Today does know.
- No way to swipe from month to month, and the arrow keys do nothing.

## 14 November 2026, 13:35: a plant's facts can be added and changed in the app

**On the branch `plant-facts-edit`, made from `main` and merged back into it.** Built for the Mac and the iOS Simulator with no errors (`r41-mac.log`, `r41-sim.log`). 558 logic tests pass. Looked at running with the example garden on an iPad Air, a 13-inch iPad Pro and an iPhone, light and dark. The database check passed (`migrate-side.sh origin/main origin/plant-facts-edit m4`, 13:33: the version before made a database holding the full library in the iPad mini simulator, and this version opened it and listed its 376 plants).

**Why.** William, on a plant's page: "It doesn't seem to show any way to add information about the plants either". He was right. Until now a plant's facts could only come in from the spreadsheet file. Nothing in the app could add one or put one right.

**What you see.**

1. **An Edit button** beside the plant's name, and **a pencil on every card**. Either opens the editing sheet. The pencil opens it at that card.
2. **"Add information"**, a new card at the foot of the page. It lists the headings that have nothing under them yet (for the achillea: Growth Patterns, Human Management and Ecological Interactions), each a button that opens the sheet at that heading. Before, an empty heading was simply left off the page, so there was nowhere to start one.
3. **The sheet** has one card for each heading, laid out like the page. Months are twelve buttons to switch on and off. A measurement has its unit beside the box, so only the figure is typed. The yes-or-no facts are boxes to tick. The grey words in an empty box begin "e.g." and are only examples.
4. **Nothing is saved until Save.** The line under the title counts what has been changed. Cancel throws the changes away. Save is grey until something has changed.
5. **The page now shows every fact that is filled in.** It used to show 49 of the 66 a record can hold. Now on the page where a plant has them: rootstock, pollination group, ploidy, root spread, time to full height, leaf size, colour and description, foliage pattern, flower and fruit size, fruit type, sowing temperature, sowing preference, whether it needs a propagator, maintenance propagation, and the type (Seeds, Plant, Scion) on the line above the name. A lone "*" or "?", which the spreadsheet uses as a marker, is not shown.

**How it is built.**

*One list of facts* (`PlantFacts.swift`, new). Four parts of the app go through a plant's facts one by one: the page, the sheet, the import and the backup. Each used to spell them out for itself, and they did not agree. Now the list is written once and all four use it. Two lines of it:

```swift
words("spacingM", "Spacing", .habits, \.spacingM, .measure("m"), hint: "0.35"),
yesNo("isPollinator", "Pollinator plant", .permaculture, \.isPollinator),
```

Reading the first from left to right: the word the fact is filed under, what the page calls it, which card it is on, where it lives in the record, what kind of thing it is, and an example for the empty box.

- `\.spacingM` is a **key path**: a way of naming a place in a record without reading it yet, like the label on a drawer. The helper `words` is handed the label and makes the two small pieces of code that open that drawer, one to read and one to write. That is what lets 66 facts be listed in 66 lines.
- `.measure("m")` is one case of an `enum` that carries a value with it: this fact is a measurement, and its unit is "m".
- A test reads the record's own list of stored values and fails if any is missing from this list, so a fact cannot be added to the record and forgotten here.

*The sheet works on a copy* (`PlantEditView.swift`, new).

```swift
@State private var values: [String: String]
...
_values = State(initialValue: PlantFacts.values(of: plant))
```

- `[String: String]` is a **dictionary**: a set of pairs, here a fact's key and the text typed for it, such as "spacingM" and "0.4".
- The copy is taken once, as the sheet opens. Every box reads and writes the copy, never the record.
- A box needs a `Binding`, which is a pair of small pieces of code: one fetches the text, one stores what was typed. `typed("spacingM")` makes the pair for one fact.
- Save calls `PlantFacts.save`, which compares the copy with the record, writes only what differs, and notes each fact it wrote as changed by hand.

*The page is drawn from the same list* (`PlantPage.swift`). `cards(for:)` used to name each fact itself. It now walks the list, card by card, and puts each filled-in fact in the part of the card that suits its kind. The tests of the old page pass unchanged against the new one.

**Keeping what you type safe.** This is most of the work, and none of it shows.

- **Loading the spreadsheet file again does not undo your changes.** The import used to replace whatever was there with the file's value. Now a fact changed in the app is left as it is, and the import says so: "1 plant updated, 3 facts you changed in the app were kept." Facts you have not touched still come in from the file as before. (`Plant.changedByHand`, `PlantFacts.keepingHandChanges`.)
- **A renamed plant is not added twice.** The file finds a plant by its name and variety. Change either here and the record keeps the old ones, so the file still finds it. (`Plant.importedAs`.)
- **The backup now keeps every fact of a plant.** It kept eight: the names, group, three of the month rows and the notes. That did not matter while the rest could be loaded again from the spreadsheet. It matters now, because the backup is the only other copy of what you type. Backup files are now version 3, and older ones still restore.
- **Restoring on a fresh copy of the app no longer doubles the library.** A fresh copy loads its own starter library, with ids of its own. The old restore did not recognise those plants as the backup's and added a second, nearly empty copy of each, with the sowings joined to the empty ones. It now matches by name and variety, joins sowings and crosses to the plant that is there, and carries over what was typed in the app.
- **Two new values on a plant's record**, `changedByHand` and `importedAs`. The database check, run in the build chat's own copy of the code with the new script `migrate-side.sh`, confirmed that a database made by the version before opens in this one.

**Found on the way and not fixed. ⚠️ CHECK, and say which you want.**

- **The backup still leaves out four kinds of record you make in the app**: seed packets, flowering and fruiting dates, pest and disease records, and the corrections Eira keeps. Its heading says "a complete copy of everything", and it is not.
- **Three columns of the spreadsheet are not read at all**: "Garden Area" (167 plants), "Date Planted/Grafted" (52 plants) and "Moisture" (7). The first two say where a plant is and when it went in, which is what a planting is. They could become plantings.
- **There is still no way to add a plant that is not in the library, or to remove one.**
- **Status** (growing, to buy, previously owned) is not in the sheet yet.

**To check.**

- The names Claude chose for facts the page did not show before: "Time to full height", "Maintenance propagation", "Needs a propagator", "Type".
- Rootstock is on the "Sowing from Seed" card, beside Propagation, which is where the record keeps it. Say if it belongs elsewhere.
- The line above the name now ends with the type: "Summer berries · Wildflower · Hardy perennial · Seeds".
- **The Mac itself has not been looked at by Claude.** The two-column page was seen on a 13-inch iPad, which lays out the same way. The pencils, the Edit button and the size of the sheet on the Mac are untried.
- Saving was seen working in the running app: five example changes typed into the sheet, saved, and shown on the page. Typing by hand and pressing the month buttons have not been tried by anyone.

**For other code that writes a plant's fact.** `PlantFacts.write("...", forKey: "pruning", to: plant)` writes one box and notes it as changed by hand, so the import leaves it alone. It is there for the work on keeping facts read on the web (the branch `eira-web-finds`).

**Found after this was merged: an older build quietly undoes a newer database.** Tried at 13:45 in the simulator. A build from before this change was started on a database this version had opened. It opened with no complaint, and afterwards the two new values were gone from every plant. The plants themselves were untouched. So SwiftData reshapes a database to fit whichever build opens it, and an older build removes whatever it does not know. **Only the newest build should be opened on real records.** A chat's own test build is run with the example garden. Knowledge base doc 42 has the detail and a suggestion for a guard.

**Checking aids.** `-demoPlant Achillea -demoOpen plantEdit` opens the sheet, and `plantEditSowing` opens it at the sowing card. `-demoEdit "spacingM=0.4|notes=Cut back in March"` types changes into it, and `-demoEditSave YES` saves them, so a still can show the page afterwards.
## 14 November 2026, 13:33: one way of giving Eira a photo

**On the branch `eira-photo-join`, made from `main` (`4bd75fc`). It joins `photo-drop` to `main`.** In its own copy of the code, `~/Developer/windfall-photojoin`. Builds for the Mac and the simulator with no errors (`pj1-mac.log`, `pj1-sim.log`). 551 logic tests pass, 2 of them new.

**Why.** William, 11:39: "Eira should use the image model as well as identify though, right?" and at 13:09, "Build it". By then two other chats had built most of it, apart from each other. The identification chat had built Eira's judgement of a photo and the camera button in her chat, which were in `main`. The photo chat had built the "+" on her bar, dropping a photo and the photo's own date, on `photo-drop`. `photo-drop` was made before the Identify screen was rewritten, so the two clashed. At 13:14 William sent a picture of the Journal page with two Eiras on it. That was put right on `photo-drop` and arrives with this join.

**The clashes, and how each was settled.**

1. `EiraVision.swift`, the Identify screen, in four places. `main`'s screen is kept, with Eira's judgement and the shared card. `photo-drop`'s additions are put back into it: a photo to begin with (`startingPhoto`), a photo dropped on the screen and the line saying when the photo was taken.
2. `CHANGES.md` and `Tools/checks/logic-files.txt`. Both branches had added lines in the same place. Both sets are kept. The photo chat's entry now sits below the later ones from `main`, a little out of time order.

**What was made one.**

1. **One function starts a sighting from a photo**: `EiraIdentify.startSighting` in `IdentifyCards.swift`. It can now be handed two more things:

   ```swift
   EiraIdentify.startSighting(from: identification,    // Eira's answer, or nil
                              photo: imageData,        // the copy made smaller
                              original: originalData,  // the photo as it came
                              facts: facts,            // when and where it was taken
                              in: context)
   ```

   In the function's own first lines these are written `original: Data? = nil` and `facts: PhotoFacts? = nil`. The question mark means "this, or nothing". The `= nil` means "nothing, if the caller leaves it out", so older callers still work. With the facts, a photo taken on Wednesday starts a sighting dated Wednesday. With the original, the photo is kept by `Photo.record`, the photo chat's one way of keeping a photo, so it reaches the photo folder if one has been chosen. The Identify screen and Eira's chat both call this function. Before, a sighting started in the chat was dated the moment Add was pressed and kept only the smaller copy.

2. **One reader for a photo's date.** There were two. `SpeciesEye.monthTaken` cut the month out of the camera's text. `PhotoFacts` reads the whole date, falls back to a second date in the file and throws out a camera whose clock was never set. `PhotoFacts` gained:

   ```swift
   func month(in calendar: Calendar = .current) -> Int? {
       taken.map { calendar.component(.month, from: $0) }
   }
   ```

   `taken` is the date, or nothing. `.map` does what is in the braces only if there is a date and hands back nothing if there is not. `$0` stands for that date. `calendar.component(.month, from:)` asks the calendar which month the moment falls in. `SpeciesEye.monthTaken` is gone. The month Eira judges a species by now comes from the same reading as the date a sighting is given.

3. **A photo can be dropped on Eira's chat**, as it already could on her bar, the Journal page and the Identify screen (`.onDrop` in `EiraChatView.swift`). Several are looked at one after another, each with its own answer.

4. **Eira's chat remembers each photo's facts and its original** (`photoFacts` and `photoOriginals`), so that Add a sighting can use them. Only the last eight originals are held, because each is several megabytes. An older photo still starts a sighting, from its smaller copy.

**What "What is this?" now leads to.** The "+" on Eira's bar, and a photo dropped on it, open the card of three offers as the photo chat built it. "What is this?" opens the Identify screen in the same sheet, and that screen is now the one with Eira's judgement. Nothing had to be written for that. The offer card already opened `IdentifyView`, and the join put the newer screen behind that name.

**Seen.** Three pictures from the iPad mini simulator with the example garden: `shots/pj-journal.png`, `pj-offer.png` and `pj-identify.png`. This chat had no way to look at a picture, so their words were read by a small program, `read-picture.swift` in the build logs folder.

- The Journal page has one bar, at the foot, reading "Tell Eira what happened i…" with a "+" beside it.
- The offer card shows "Taken Wednesday 11 November at 2:02 pm" and the three offers.
- The Identify screen shows "Taken Wednesday 11 November at 2:02 pm. A sighting started from this is dated then." and the button "Start a sighting from this".

**Not seen or tried.**

- Eira's card on the Identify screen in these pictures. It was below the foot of the sheet. The identification chat's own pictures show it.
- Any drag, on any device. A script cannot make one.
- A real photo through the image model from the "+" or from a drop. The simulator has no image model and shows an example answer.
- Add a sighting from Eira's chat with a dated photo, and the photo folder.
- The Mac's own window.

**Not built.** Naming what is in a photo inside the journal's conversation. Another chat was changing `JournalChat.swift` and `JournalChatView.swift` at the time, on `journal-follow-up`.

**Found and left.** Sixteen Python package files (`*.whl`, 13MB) have sat at the top of the repository since `7e61a86`. One is called `swift`. They look like the result of asking Python's installer for "swift", which is an unrelated package of that name. ⚠️ CHECK: a guess from the file names. Nothing in the app uses them.

## 14 November 2026, 12:57: "Sow to crop" was being read as days

**On the branch `sow-to-crop-units`, made from `main` and merged back into it.** 535 logic tests pass.

**What was wrong.** Found while reading the plant page's code, not asked for. Every "Sow to crop" figure in the spreadsheet is written in weeks or months: 89 in weeks, 6 in months, none in days. The app took the number and called it days. Garlic's "20 weeks (typical)" was shown on its page as "Sow to crop: 20 days". Worse, Today works out when a crop is due from the same figure, so it would have offered "Harvest garlic" twenty days after planting.

**What changed.**

1. `DurationParser`, new in `Parsing.swift`, reads the unit as well as the number:

   ```swift
   DurationParser.days(in: "12-16 weeks")      // 84 to 112 days
   DurationParser.describe("12-16 weeks")      // "12–16 weeks"
   DurationParser.describe("14")               // "14 days": no unit named means days
   ```

   It looks for the first unit named in the text (day, week or wk, month or mth, year or yr) and uses only the numbers written before it, so "12 weeks (84 days)" is 12 weeks and not "12 to 84". A week is 7 days, a month a twelfth of a year.
2. A plant's page shows the figure in its own unit: "20 weeks", "9–12 months" (`PlantPage.swift`).
3. Today's two harvest reminders turn it into days properly before adding it to the sowing date (`TodayView.swift`).

Germination was not affected. Its column is in days.

**A test reads the real library**: every sow-to-crop figure in it must come out as weeks or months, and none shorter than a fortnight. If a figure is ever written another way, that test will say so.

## 14 November 2026, 12:50: a sowing or a planting, added from the plant's own page

**On the branch `plant-page-plantings`, made from `main` and merged back into it.** Built for the Mac and the iOS Simulator with no errors (`r33-mac.log`, `r33-sim.log`). 531 logic tests pass. Looked at running in the iPad simulator with the example garden, light and dark.

**Why.** William, looking at the Achillea page: "Could you make it so that you can add a planting of plants in the plant page?" Two things stood in the way. A sowing could only be started from Today or the Sowings list, by finding the plant all over again. And only a plant kept by cloning (a fruit tree, garlic, a potato) could be recorded as *planted*. An achillea bought in a pot could only be written down as seed sown, which is not what happened.

**What changed.**

1. **The card** (`PlantLibraryView.swift`, in `PlantDetailView`). "Sowings" is now "Sowings and plantings". It is always there, where before it was left out until the plant had been sown, and it comes first: under the name when the page is one column, at the top of the right-hand column when it is two. Each row says "Planted 24 Oct 2026" or "Sown 14 Mar 2026", then where and how many ("Herb bed · A · 3 plants"), then the stage, and opens that sowing's own page. Under the rows are two buttons, **Add a sowing** and **Add a planting**.

2. **The form opens with the plant already chosen** (`PlantingViews.swift`). `NewPlantingView` gained a starting point:

   ```swift
   init(plant: Plant? = nil, asPlanting: Bool = false) {
       _selectedPlant = State(initialValue: plant)
       opensAsPlanting = asPlanting
   }
   ```

   - An `init` is the code that runs when a thing is made. This one takes two things, and each has a value to fall back on (`= nil`, `= false`), so the old `NewPlantingView()` on Today still works unchanged.
   - `Plant?` means "a plant, or nothing". `nil` is the nothing.
   - `selectedPlant` is `@State`: a value the form keeps and redraws itself for. `_selectedPlant` with the underscore is the box that value lives in, and `State(initialValue: plant)` is how a starting value is put in the box before the form first appears.

3. **Every plant can go in as a plant** (`SeedTruth.swift`). `SeedTruth.starts` lists the ways of starting that the form offers. It used to hand back an empty list for an ordinary plant, which meant "do not ask". It now always ends with `.plant`, so the form asks **Seed** or **Plants**. For a plant where saved seed matters (a squash, an F1) the three choices are "Seed from a packet", "Seed I saved" and "Plants", as before plus one. A new rule, `asksSeedSource`, keeps one promise from before: for an ordinary plant the form never asked where the seed came from, so nothing about a packet is written into the record.

4. **What is saved for a planting.** `startedFrom = .plant` and the stage "growing", with the date as the day it was planted. The journal already words that as "Planted Achillea" and "3 planted". A planting's own page now says "Planted" where it said "Sown".

5. **A succession round counts sowings only** (`PlantModels.swift`, `Planting.nextRound`). The first still of the new form said "Succession round 3" on a planting, because every earlier record that year was counted. A round is a round of sowing: plants going in neither get a number nor use one up.

6. **The wording of the rows is tested** (`PlantPage.swift`, `plantingLines`). As with the rest of the page, the words are worked out in a file with no screen code, so the checks can run them without a Mac: newest first, "plants" for a planting and "seeds" for a sowing, "1 plant" not "1 plants", "On record" for one with no date.

**How the buttons open the form.** This pattern is worth knowing, because Windfall uses it everywhere:

```swift
private enum AddingToGarden: String, Identifiable {
    case sowing, planting
    var id: String { rawValue }
}
@State private var adding: AddingToGarden?

Button("Add a planting") { adding = .planting }

.sheet(item: $adding) { which in
    NewPlantingView(plant: plant, asPlanting: which == .planting)
}
```

- An `enum` is a short list of named choices: here, which of the two forms.
- `adding` holds one of them, or nothing (the `?`). A button does nothing but set it.
- `.sheet(item:)` watches `adding`. While it holds a choice the sheet is up, and it hands the choice to the code in the braces as `which`. When the sheet is closed, SwiftUI sets `adding` back to nothing by itself. `Identifiable` (the `id` line) is what lets it tell one choice from another.
- So the button never "opens" anything. It changes a value, and the screen follows the value. That is the idea behind all of SwiftUI.

**Also in this change.**

- The example garden has a sowing and a planting of achillea, so the card has something to show in a still. Example data only: it lives in memory and never touches real records.
- Checking aids: `-demoPlant Achillea -demoOpen plantPlanting` and `-demoOpen plantSowing` open the form from the page.
- The checks had been failing on `main` since the Plants search work: a variable called `box` in `CollapsingSearch.swift` was read by the cross-file check as every other `box` in the app. It is now `textBox`. Nothing was wrong with the app itself.
- William's screenshot is filed in `Design/Reference`.

**To check.**

- Is "Seed" and "Plants" the right pair of words? And "For plants that came as plants: bought, given, divided or grown from a cutting"?
- Is the card in the right place, first on the page?

## 14 November 2026, midday: Eira identifies from a photo, and a page for testing the image models

**On the branch `eira-identify`, made from `main` and merged back into it.** Built for the Mac and the iOS Simulator with no errors (`identify-7-mac.log`, `identify-7-sim.log`). 520 logic tests pass. Both image models were run through the app on the same 300 UK photos and scored as they did before (the table below). The answer card was seen in the simulator, in the Identify sheet and in Eira's chat, on example answers. **Not yet tried by hand: giving Eira a real photo in the chat, "Add a sighting", "Ask Eira about it" and the whole of the test page.** The test page has only been compiled. William is the first to run it.

| 300 unseen UK photos, 776 names | BioCLIP 2.5 Huge | BioCLIP 2 |
|---|---|---|
| The model alone: first answer right | 293 (98%) | 289 (96%) |
| The model alone: named outright, and of those right | 294, 290 | 272, 271 |
| Eira: named a species, and right | 251, 247 | 234, 233 |
| Eira: said one of several look-alikes, and the true one among them | 43, 43 | 38, 38 |
| Eira: gave the genus only, and the right genus | 3, 3 | 10, 9 |
| Eira: said she was not sure | 3 | 18 |
| Seconds a photo, both in one run with the chip free | 0.22 | 0.15 |

So with BioCLIP 2.5 Huge she answers 297 of 300 and is wrong on 4, the same 4 the model is wrong on. What the rules change is how the other 293 are put: 43 are given as "one of these" where a species cannot honestly be named from a photo, and 3 that the model would not name are given, rightly, as a genus. The four wrong ones are a common lizard named as a wall lizard, hemlock named as cow parsley (which carries the carrot-family warning), common comfrey named as Russian comfrey and a buff ermine named as a muslin moth. `identify-species-both.md` on the Mac has every photo. The month and the records were not part of this test: the photos carry no dates and the example garden has no sightings of them.

**Why.** William asked: "Could you build the identification part of Eira now for integration in to the app and so I can test the models". Until now the Identify screen showed the image model's three closest names and nothing more, Eira's chat could not be given a photo at all, and only one image model could be installed at a time, so two could not be compared inside the app.

**The idea in one line.** The image model only matches a photo to a list of names. Eira's judgement about that match is now a separate step, done by fixed rules with no model, so it behaves the same whichever image model is underneath.

**What changed.**

1. **Eira's judgement about a photo** (`EiraIdentify.swift`, new). `EiraIdentify.judge` takes the image model's answer and what Windfall knows, and hands back an `EiraIdentification`: a verdict, a headline, warnings, what the records say and the wording for the chat. Five rules:
   - *A genus when the species is unclear.* If she cannot name a species but the closest names are two or more of one genus sharing 85% between them, she gives the genus: "A bumblebee (Bombus), species not certain". The everyday word comes from the English names where they all end the same way.
   - *Look-alikes.* If the name is in a group that cannot be told apart from a photo (`SpeciesLookalikes.json`), she says "Buff-tailed Bumblebee or a look-alike", names the group and gives the reason. ⚠️ CHECK: that file was written by Claude from memory on 13 November. Every warning from it is marked "to check" on screen until the file's own `"checked": false` is changed to `true`.
   - *The month.* The name is checked against UK records month by month (`SpeciesMonths.json`: iNaturalist's counts for 609 species, fetched on 13 November, real figures) and against the flight period in William's own wildlife list. Rarely recorded in that month, or outside his list's flight period, turns "probable" into "possible". **The month is the one the photo was taken in**, read from the photo's own date where it has one, and otherwise this month. ⚠️ CHECK: the levels are Claude's: under 2% of a species' records in the month is "not often", under 0.5% is "rarely".
   - *The records.* Each name is looked up in the plant list, the wildlife list and past sightings: "It is in your plant list: Lavender, Hidcote", "You have recorded it 3 times, last on 12 November 2026, 2 of them confirmed". Names are compared by genus and species only, so a variety or an author's name does not stop a match.
   - *Dangers.* A plant on a list of 19 dangerous ones (`PlantDangers`) brings a boxed warning if it is the first name or holds 2% or more of the model's belief, whatever was named first. This answers the photo of hemlock water-dropwort that was named as yellow iris at 87%. ⚠️ CHECK: the list is Claude's, from general knowledge. It is not a list of every poisonous plant. **The carrot-family warning is the one another chat built the same morning** (`DangerousLookAlikes`, in the entry below). Eira's rules call it and do not repeat it: it shows when any of the three names on screen is of that family, unless one of them has already been warned of by name. A carrot-family plant that is named is never given as better than "possible".

   None of it needs the screen or Apple's AI frameworks, so all of it is tested without a Mac: 44 new logic tests.

2. **One card for the answer, used in two places** (`IdentifyCards.swift`, new). `IdentificationCard` draws the verdict, the warnings, the model's three closest names as bars and the lines from the records. The Identify screen uses it, and so does Eira's chat. The same file gathers what the rules need from the database (`IdentifyKnowledge.gathered`), runs the whole job (`EiraIdentify.identify`) and starts a sighting (`EiraIdentify.startSighting`).

3. **A photo can be given to Eira in her chat** (`EiraChatView.swift`, `EiraConversation.swift`). A camera button beside the text box takes one from Photos or from a file. The photo joins the conversation as a message, and her answer is the card, with two buttons:
   - *Add a sighting.* Starts an unconfirmed sighting with the photo. The name goes in as a suggestion (`provisionalID`), never as confirmed. When she was not sure, no name is written in at all. **This is the only thing here that saves, and only when the button is pressed.**
   - *Ask Eira about it.* Sends "Tell me about …" to her text model with the species lookup run first. `send` gained a third setting, `about:`, so the lookup is given the scientific name and not the whole sentence.

   Naming a photo does not use the text model, so it works where no text model can run. Her answer is also kept in the conversation as words, so the text model has it in front of it for a follow-up question. The photo itself is held only while the chat is open. It is saved when a sighting is started from it.

4. **More than one image model can be installed** (`SpeciesEye.swift`). An image model is now any folder in the Models folder that holds a model, `uk_species.json` and `uk_species_rows_f16.bin`. An optional `eye.json` gives it a name to show and an order. Eira uses the one chosen on the test page, or the first in order. `SpeciesEye.shared` follows that choice, and `SpeciesEye(using:)` makes one tied to a particular model. Until now the folder had to be called `bioclip2` and the model file had one fixed name.
   - Image models no longer appear in the list of text models Eira can talk with. Another chat put this right the same half hour, after the new `bioclip2-original` folder turned up in that list (the entry below). Its fix is the one kept.
   - A species in the list can carry where its name came from (`SpeciesEntry.source`). A name that came from a pot label says so on the card.

5. **A page for testing the image models side by side** (`EyeTestView.swift`, new). Wildlife, Identify from a photo, "Test the image models". Choose up to 60 photos, run them through every installed model, then mark each photo with what it really is: one of the names given, a name typed in, or "not on the list". For each model it counts first answers right, right among the three, named outright and right, **named although not on its list**, and seconds a photo. "Use for Eira" chooses a model. "Copy the results" puts the whole test on the clipboard. "Keep my answers" saves each marked photo and its true name beside the Models folder, in `Photo answers`, where they can later be used to teach or test a model. Nothing is taught by the page itself.

6. **The test run measures Eira's judgement too** (`SpeciesTestRun.swift`). After the model's own totals it now reports what she would have said for each photo and whether that was right, and lists every photo where the model's first answer was wrong and she still gave an answer. `-speciesEyeFolder <folder>` picks the model.

**On the Mac.** `Models/bioclip2` holds BioCLIP 2.5 Huge (doc 30) and now has an `eye.json` naming it, order 1. A new folder, `Models/bioclip2-original`, holds BioCLIP 2 with the table made for it, order 2. The model there is a clone and takes no extra room.

**Checking aids.** `-demoOpen identify -demoMatch YES` shows the Identify sheet on an example answer, as before, now judged against the example garden's real records. `-demoOpen eira-photo` opens Eira's chat on the same example.

**Not done.**
- "Add to the count": offering to add the insect to a FIT count that is under way.
- Opening the plant's page or the species' page from the card.
- A photo in a saved conversation. Reopened later, her answer shows as words without the photo or the card.
- Dropping a photo on to the chat. Another chat is building drops for the journal (`photo-drop`), and its `PhotoFacts` reads a photo's date and place more fully than the month read here. The two should be joined when both are in `main`.
- The rest of the chat screen is still in the old look.
- An image model still cannot be added from inside the app, and the species list is still made on the Mac.

## 14 November 2026, 12:20: the photo model is no longer offered as a model for Eira's chat

**Why.** Eira's settings list every folder in Windfall's Models folder that holds a file ending in `.aimodel`. The photo model's folders (`bioclip2`, and `bioclip2-original` since another chat added it) hold one too, so they were listed beside the two Qwens. Choosing one would only give an error, because a photo model cannot hold a conversation.

**What changed** (`EiraModelLibrary.coreAIModelNames` and `holdsTextModel` in `EiraEngine.swift`). Apple's exporter writes a small file, `metadata.json`, into every model folder it makes, with a line saying what kind of model it is: `"kind": "llm"` for a text model. A folder is now listed only if it has that file and the file does not name another kind. The photo model's folders have no such file, so they drop out. One test builds five pretend folders and checks that the right two are listed.

## 14 November 2026, midday: three things the trained Qwen's test turned up

**In `main` since 12:00**, by way of the branch `carrot-family-warning`, with the warning below. Built for the Mac and the simulator as r26 (`36b0bcd`), no errors. 474 logic tests pass.

The trained Qwen3 8B sat Eira's test sheet for the first time at 11:29 (knowledge base, doc 32). Three of its answers showed faults that were the app's and not the model's.

**1. "Nothing has been recorded" was taken for a claim to have saved** (`EiraChecks.claimsToHaveSaved`).

- *What happened.* Asked what had been harvested this month, the model answered that there were no harvests and that nothing had been recorded. The rule that removes false claims of saving looks for "been recorded… in your…". It found those words, took the sentence out and wrote "Nothing has been saved. I cannot change your records from this chat" under the answer.
- *The change.* The sentence is now read a clause at a time, split at commas and at "but" and "and". In each clause, if a denial ("nothing", "no", "not", "never", "hasn't" and the like) comes before the saving word, the clause is not a claim. "I cannot save changes, but your sowing is now recorded" is still caught, by its second clause.
- *A trap avoided.* The first try looked for any word ending in "nt" to catch "hasn't" and "haven't" (the code strips apostrophes first). That would also have read "plant" and "current" as denials, so "Your plant is now recorded" would have slipped through. Each such word is now listed whole, and a test holds that sentence in place.

**2. The plant search could not find "English lavender"** (`ToolRunner.plantMatches`, used by the `search_garden` lookup in `EiraTools.swift`).

- *What happened.* The plant is stored as Lavender, with English as its variety. The lookup wanted the whole phrase "english lavender" inside one field, and never looked at the variety at all. So the model was told "Nothing matching", and told William his database had no such plant. "Spartan" would not have found Apple, Spartan either.
- *The change.* The search is split into words. Small words ("the", "my") are dropped. Every word left must be somewhere in the plant's name, variety, Latin name or group, in any order. A word ending in "s" also matches without it.
- `allSatisfy` in the code means "true only if every item passes".

**3. A kept correction could be ignored** (`EiraChecks.corrections(bearingOn:among:)`, `handOver`, used in `EiraConversation.generate`).

- *What happened.* The new section G of the test sheet: tell Eira "No, that's wrong. There is also a Bramley apple by the shed", press Keep it, then ask in a new conversation "Do I have a Bramley apple?" Apple's model said yes. The trained Qwen ran a lookup, found nothing and said no, although the correction was in its instructions. A model weighs what arrives with the question more than what stood in its instructions.
- *The change.* Before a question goes to the model, every kept correction is compared with it. One that shares a word that matters with the question, or with the question it was first given on, is put in front of the question, under a line saying it is the gardener's own word and outranks an empty lookup. At most three, newest first.
- *"A word that matters"* (`wordsThatMatter`): four letters or more, not one of about sixty common words ("what", "have", "garden", "plant"…), with a final "s" taken off. Each text becomes a `Set` of such words, and `isDisjoint` asks whether two sets share nothing.
- *A bonus.* Only the ten newest corrections fit in the instructions. This searches all of them, so an old one comes back when a question touches on it. The Corrections list now says so.
- *The wording.* Apple's model, using a correction, said "the garden record confirms" it. The records did not. The line now ends: say "you told me". Do not say the records show it, unless a lookup shows it too.
- Only the model sees the added lines. The conversation on screen, and what is saved, keep the question as it was typed.

## 14 November 2026, midday: a carrot-family warning on photo matches

**In `main` since 12:00**, by way of the branch `carrot-family-warning`. Seen in the simulator in light and dark (`shots/carrot-*.png` on the Mac).

**Why.** That morning the fine-tuning chat put a newer image model into Windfall's Models folder at William's request (BioCLIP 2.5 Huge, doc 30). The build chat ran the same 300 unseen UK photos through the app with it:

| | BioCLIP 2 | BioCLIP 2.5 Huge |
|---|---|---|
| First answer right | 289 | 293 |
| Right answer among the three | 295 | 299 |
| Named outright | 272, of which 1 wrong | 294, of which 4 wrong |

It is right more often and sure more often, and so it is also sure more often when wrong. **It named a photo of hemlock as cow parsley at over 99%.** The older model had said "not sure" for that photo, and had its own such mistake (hemlock water-dropwort named as yellow iris). Both plants are deadly. Both are in the carrot family. Both times a carrot-family plant was among the three candidates on screen.

**What changed.**

- `DangerousLookAlikes` in `SpeciesTable.swift`: a list of 31 carrot-family genera (the first word of a scientific name), and one function. If any of the three candidates is a plant whose genus is in the list, `SpeciesGuess.lookAlikeWarning` returns the warning. Otherwise it returns nil.
- The Identify screen (`EiraVision.swift`) shows that warning in an orange box above the names, however sure the model is. The small print under every answer is unchanged.
- *Why the group is checked as well as the name.* An animal can share a plant's genus name. Oenanthe is the water-dropworts and also the wheatears, which are birds. So the rule asks that the candidate is a plant.
- *Why "any of the three" and not only the first.* In the first mistake the first answer was an iris. The deadly plant was second, at 6%.
- The photo test run (`SpeciesTestRun.swift`) now counts how often the warning shows, how many photos really were of the family and whether any of those went without it.
- `-demoMatch hemlock` shows the warning in the simulator, with the real mistake as the example.
- The comments in `SpeciesTable.swift` no longer say the model is BioCLIP 2 with 768 numbers. The table says how many numbers its rows hold, so the code works with either.

**For William to check.** ⚠️ CHECK: the genus list and the wording of the warning are Claude's, from general knowledge and not from a field guide. The warning reads: "Take care: this may be one of the carrot family. That family holds deadly plants, hemlock and hemlock water-dropwort among them, that look much like cow parsley, wild carrot, wild celery and parsley. A photo cannot tell them apart safely. If you did not sow it yourself, do not eat any part of it on the strength of this, and wear gloves to handle it: giant hogweed, of the same family, burns the skin." It will also show on photos of your own carrots, parsley, fennel and parsnips, which is why it says "if you did not sow it yourself".

**Not done.** Other dangerous pairs: wild garlic with lords-and-ladies and lily of the valley, comfrey with foxglove. Each needs a checked list first. The "not sure" level (0.85) was set for the older model and should be set again for this one from William's own photos (doc 30).
## 14 November 2026, 12:24: the 12GB rule no longer stops Apple's built-in model

**On the branch `search-collapse`.** Built for the Mac and the simulator with no errors (`search7-mac.log`, `search7-sim.log`). The seven checks of the rule were run on the Mac on their own and pass. The full logic tests were not run. **Not tried on an 8GB device. Nothing here has been.**

**Why.** William asked whether 8GB devices could have Eira on a smaller model. They could not have her at all: the rule refused every model on a device under 12GB. But the 12GB figure was sized for a downloaded model of about 8B, which Windfall holds in its own memory. Apple's built-in model is run by the system, and it is Eira's default. William agreed that smaller devices should have Eira on it.

1. **`DeviceCapability` in `EiraEngine.swift`.** `canRunEira` is now `canRunDownloadedModels`, the same sum under a truer name. A new `canRun(_ kind:)` answers for one kind of model: always yes for Apple's built-in, the 12GB rule for a Core AI or MLX model.
2. **`EiraEngineFactory` in `EiraOnDeviceEngine.swift`.** It applies the rule to the model that is chosen, not to the device as a whole. Two new values: `builtInModelIsAvailable`, which asks the system whether Apple's model is on this device and ready, and `deviceCanRunEira`, true if there is the memory for a downloaded model or Apple's is here.
3. **Eira's bar** (`EiraFloatingBar.swift`) opens Eira when `deviceCanRunEira` is true. On a device with neither, it still falls back to plain search, as before.
4. **The wording.** Choosing a downloaded model on a small device now says to choose Apple's built-in model in Eira's settings. The Memory line in her settings says which case this device is in.

**CHECK.** That Apple's built-in model is offered on 8GB devices such as the iPhone 15 Pro and iPad mini 7, and that the system runs it outside the app's memory, is Claude's understanding and was not looked up or tried. The code does not rely on it: it asks the system, and a device without the model is treated as before.

**Not done.** A small model of our own for these devices, such as a 2B or 4B Qwen trained on Eira's habits. It would need its own, lower memory line, set by trying it on a real device.

## 14 November 2026, 12:22: Find in the Edit menu, and the search box takes the cursor

**On the branch `search-collapse`.** Built for the Mac with no errors (`search5-mac.log`). Checked in a test copy with the example garden, without bringing it to the front: Edit, Find opens the box and the cursor is in it. The glass closes an empty box and opens it again with the cursor in it. Seven letters sent as key presses arrived in the box and the cross appeared. Escape emptied and closed it. **Not tried**: Command-F pressed on a real keyboard, and clicking away from the box.

**Why.** William tried Command-F and nothing happened. Looking into it turned up a second fault that nobody had seen yet: when the box opened, the cursor was not in it.

1. **Command-F is now "Find" in the Edit menu** (`FindCommands` in `CollapsingSearch.swift`, added to the app in `WindfallApp.swift`).
   - *What was wrong.* The shortcut had been given to the magnifying glass button itself. A shortcut on a button inside a Mac toolbar was not picked up.
   - *How it works now.* The menu line sends a notification, `windfallFind`. A notification is a note pinned to a board that any part of the app can be watching. The search glass watches for it, opens and takes the cursor. The menu does not need to know which screen is showing.
   - *A limit.* On a screen with no search glass, Find is still in the menu and does nothing.
2. **The box to type in is now AppKit's text field** (`ToolbarTextBox` and `CursorTakingField`).
   - *What was wrong.* It was SwiftUI's `TextField`, with `@FocusState` to put the cursor in it. Inside a Mac toolbar that did nothing, with or without a pause first, while the same `@FocusState` worked for Eira's bar in the same window.
   - *How it works now.* AppKit is the older Mac toolkit SwiftUI sits on. There the window can be told outright which box has the cursor (`makeFirstResponder`). The screen asks by adding one to a number, `cursorRequests`, and the box takes the cursor each time the number changes.
   - Typing, Escape and leaving the box are reported by AppKit to a helper (the `Coordinator`), which passes them on.

**A correction to the entry below:** it says the glass was tried and worked. It opened and closed, and words put into the box narrowed the list. Whether the cursor arrived was listed as not tried. It did not arrive.

## 14 November 2026, midday: the Plants search rests as a magnifying glass

**On the branch `search-collapse`, made from `main`.** Built for the Mac and the simulator with no errors (`search1-mac.log`, `search1-sim.log`). Tried in a test copy on the Mac with the example garden: the glass opens the box, typing "spartan" leaves 1 of 376 plants, the cross empties it and the glass closes it again. **Not tried by hand**: whether the cursor lands in the box when the glass is clicked, Command-F, Escape and clicking away. The logic tests were not run. They need the Linux checker, which this chat did not have.

**Why.** William asked whether the wide search box at the top of the Plants window is needed now that Eira can search. It is: it narrows the list as each letter is typed, with no model, and it works on devices that cannot run Eira. But it does not need to take up the toolbar while it is not in use. William chose to have it rest as a magnifying glass.

**What changed.**

1. **A new piece, `CollapsingSearchField`, in a new file `CollapsingSearch.swift`.** Mac only. It is a magnifying glass button that opens into a box to type in.
   - *Why not Apple's own.* SwiftUI's `.searchable` puts a wide box in a Mac toolbar for good. Apple's shrinking version, `.searchToolbarBehavior(.minimize)`, is marked as not available on a Mac in the macOS 27.2 kit (read from the kit's own list on the Mac, 14 November 2026).
   - *How it behaves.* Click the glass, or press Command-F, and the box opens with the cursor in it. A cross appears once there are words, and empties the box. Escape empties and closes. Clicking away from an empty box closes it. A box with words in it stays open, so it is always plain why the list is short. The glass pressed again with nothing typed closes the box.
   - *How the code holds it.* Two values: `open` (is the box showing) and `typing` (is the cursor in it). The words themselves are not kept here. They are a `@Binding` to the screen's own filter, exactly as with `.searchable`, so nothing about how plants are matched has changed.
2. **`PlantLibraryView.swift`.** On a Mac the `.searchable` line is fenced off with `#if os(iOS)` and the new piece is added to the toolbar, after the Garden data button, with a `ToolbarSpacer(.fixed)` between so each has its own piece of glass. **The iPhone and iPad are unchanged.**
3. **A checking aid.** `-plantsSearch apple` starts the Plants screen with "apple" already typed (`PlantFilter.fromLaunchArguments`). One logic test added for it.

**Not done.** The Year page, Species, Seed and Sightings still have the wide box. The same piece would fit each of them in a line or two.

## 14 November 2026, midday: giving Eira a photo

**On the branch `photo-drop`, made from `main` (`98fd66c`), in its own copy of the code at `~/Developer/windfall-photo-drop`,** because another chat was working in the main copy. Built for the Mac and the simulator as `pd4`, with no errors. 471 logic tests pass (14 new). Seen in the simulator as still pictures (`shots/pd-*.png`). **Nothing has been dragged by hand.** A drag cannot be made from a script, so the drop itself, the "+" menu and the photo folder are William's to try.

**Why.** William, with a picture of three photos held over the Journal page: "the journal part of windfall doesn't let you just drag photos over to it to start an entry. Also on the journal page Eira appears twice". Then: "eira has a photo button on it so that you can start with uploading a photo", and "Store the photos on icloud for now until we get cloudkit up and running."

**What changed.**

1. **A photo's own date and place are read** (new file `PhotoFacts.swift`).
   - A camera writes notes into each photo's file (EXIF): when the shutter was pressed and, on a phone, where. `PhotoFacts.read(from:)` opens the file with ImageIO, Apple's reader for picture files, and pulls those out. The picture itself is not decoded, so it is quick.
   - The camera writes a date as "2026:11:11 14:02:33", with its distance from Greenwich beside it ("+01:00") on a phone. `PhotoFacts.date(written:offset:zone:)` turns that into a date. A date before 1990 is refused: it is what a camera whose clock was never set writes.
   - A position is kept only whole, and nought north, nought east is refused as an unset GPS.
   - A screenshot or a picture saved from the web has no such notes. Nothing is guessed for it.
   - The first half of the file needs nothing from Apple, so it is in `logic-files.txt` and tested.

2. **Eira asks which day an entry with photos is about** (`JournalChat.photoCheck`, and the card in `JournalChatView.swift`).
   - *The rule.* Photos from the last hour ask nothing. Otherwise each day with photos is offered, newest first, at the time of that day's last photo, then "Now". A photo dated in the future is ignored. No more than four days.
   - *The card is the time check's card.* `checkCard` used to be drawn from the words' question only. It is now drawn from a question and a list of choices (`CheckChoice`), so the photos' question and the "this morning" question look and work alike. The photos' question is put first where both arise: it is the firmer evidence.
   - *The photo keeps its own time* (`Photo.capturedAt`) whichever time the entry is stamped with. Its place goes into `Photo.latitude` and `longitude`, which were there and unused.

3. **Photos can be dragged in at three places**, all read by one function (new file `PhotoDrop.swift`).
   - The Journal page: a dashed outline says "Drop to start a journal entry" and the journal's conversation opens with the photos in its box.
   - Eira's bar, on any page.
   - The Identify screen: Eira looks at the photo at once.
   - *How a drop arrives.* SwiftUI hands over an "item provider" for each thing dropped, a promise to supply it a moment later. A photo dragged from Finder arrives as the file's address, one from Photos as the picture. `PhotoDrop.pictures(from:)` tries the file first, which gives the photo exactly as the camera saved it, notes and all. The journal's own sheet took drops before, but only as pictures, so a file from Finder may not have worked there. It now uses the same reader.

4. **Eira's bar has a "+" beside her snowdrop** (`EiraFloatingBar.swift`): "From Photos" or "From a file". **Taking a photo with the camera is not built**: the app has no camera code or permission yet.

5. **The Journal page has one Eira, not two.** Its own "Tell Eira what happened in the garden" bar at the top is gone. On that page Eira's bar at the foot is always open, carries those words (on an iPhone, where there is room for two words, "Tell Eira"), and has a book button at its right-hand end that opens the journal's conversation. A screen says it is the journal with `eiraLooksAt(..., isJournal: true)`.
   - *What is typed there is an entry unless it plainly asks* (`JournalChat.readsAsAsking`, tested): a question mark, an asking word ("when", "show", "wonder") or one word alone goes to Eira or to search. Everywhere else the old, cautious rule stands (`readsAsTelling`).
   - On an iPhone's Journal page the search button gives way to make room. Return still searches or asks.

6. **Away from the Journal page, Eira asks what to do with a photo** (new file `PhotoOffer.swift`): **What is this?** (the Identify screen, which looks at once), **Journal entry** or **Sighting** (a new sighting with the photos attached, dated when the earliest was taken). The card and the three things it leads to share one sheet. Nothing is saved by choosing.

7. **A sighting started from the Identify screen is dated when its photo was taken**, and the screen says so under the photo.

8. **Originals can be kept in a folder in iCloud Drive** (new file `PhotoStore.swift`, and a "Photos" section in Settings).
   - Choose a folder in Settings. From then on the original of each new photo is written there as a file, in a folder for each year, named with the time it was taken and the first eight characters of its record's label: `2026/2026-11-11 14.02.33 3F2A9C1E.heic`. The app keeps a copy no more than 2048 points on its longer side, and the small one for lists.
   - *Why a folder you choose.* Choosing it yourself is what gives the app permission to write there, on a Mac, an iPad or an iPhone, with no paid Apple developer membership. The app remembers it with a "bookmark".
   - *Nothing new is stored in a photo's record.* The file is found again from the record's own time and label. So the database is unchanged, and `migrate-test.sh` was not needed.
   - With no folder chosen, everything is as before. Nothing is written while the example garden is showing.
   - **Not done:** moving photos already in the app out to the folder, showing an original at full size, and fetching one that iCloud has not downloaded.

**Every place that keeps a new photo now goes through `Photo.record(of:)`** (in `PhotoDrop.swift`): the journal's conversation, the Identify screen and the new sighting offer. Two older places still make a photo by hand and do not read its date or use the folder: the old diary form (`JournalViews.swift`) and the sighting form's own photo button (`ObservationViews.swift`).

**Checking aids** (with `-demoGarden`): `-demoPhoto /path/to/photo.jpg` hands that photo to whatever `-demoOpen` opens. `-demoOpen journal` shows it waiting in the conversation with the day question, `-demoOpen identify` on the Identify screen, and the new `-demoOpen photo` opens the card of three offers. Two test photos with dates written in are in `windfall-build-logs/photo-drop-test`.

**To check by hand.** ⚠️ CHECK each of these on the Mac:
- Dragging photos from Finder and from Photos on to the Journal page, Eira's bar and the Identify screen.
- That a HEIC photo from an iPhone gives its date (the reader was tried on JPEG test photos).
- The "+" menu's look on the Mac. It has only been seen on an iPad.
- The Photos section in Settings and choosing a folder. It builds and has not been seen.
- Whether photos chosen "From Photos" keep their date. Apple's chooser may hand over a copy without the camera's notes.

## 14 November 2026, late morning: telling Eira she is wrong

**In `main` since 11:20**, by way of the branch `eira-corrections`. Built for the Mac and the simulator as r23, with no errors. 457 logic tests passed then. Seen in the simulator in light and dark (`shots/corr-*.png` on the Mac). **Tried with Apple's model and the trained Qwen through the test sheet's section G (knowledge base, doc 32). Not yet tried by hand.**

**Why.** William asked: "I assume if it makes mistakes and I tell it that, then it will update the notes it keeps to improve in the future?" It did not. A correction was kept only if he pressed and held a reply and chose "Correct this", which nobody would find. Typing "No, that's wrong" was answered and then forgotten. And there was nowhere to read the corrections already kept, or to take a wrong one back.

**What a correction is.** A note, not training. The model's own numbers never change. The ten newest corrections are written into Eira's instructions at the start of every conversation, under "Corrections the gardener has given you. These are right even if you believe otherwise". All of them are kept, however many there are, so they can become practice turns if the model is trained again.

**What changed.**

1. **A typed correction brings up a card** (`EiraChecks.correctionWords`, `EiraConversation.send`, `CorrectionOfferCard` in `EiraChatView.swift`).
   - *The rule.* A message is read as a correction if it opens by disagreeing ("No, ...", "That's wrong", "Not quite", "Actually", "Correction:") or by naming the mistake ("That's not a Spartan, it's a Bramley", "You said ... but ..."), and goes on to state a fact of three words or more. It is plain code that looks for words. No model is asked.
   - *What is kept.* Where the opening is set apart by a comma or a full stop it is taken off: "No, that's wrong. It's a Bramley." offers "It's a Bramley." Where it is not, the whole message is offered, because "That is wrong for clay soil" would otherwise be kept as "for clay soil".
   - *What it leaves alone on purpose.* A question. "No thanks". "No dig beds are what I use" and "No slugs on the hostas this year", where "no" is the subject. "No, tell me about the other one", a request. Praise ("Actually that's really helpful"). A grumble about the app ("It's not working"). A plain "No" straight after Eira has asked a question, which is an answer to it. Anything over 240 characters, because the line read to the model would be cut off. The tests hold 35 examples in place, both ways.
   - *When unsure it offers nothing.* The button under every reply (below) is there for whatever the rule misses.
   - *Nothing is kept unless "Keep it" is pressed.* The words can be changed on the card first. Once kept, the card shrinks to a line with Undo. "No thanks", or simply sending the next message, takes the card away.
   - *How the code holds the offer.* `EiraConversation` has a new value, `offeredCorrection`, of a small type `OfferedCorrection`: which message of yours it sits under, which reply of hers it puts right, the words and, once kept, the saved record. `send` sets it, the screen draws a card when it is not nil, and the buttons call `keepOfferedCorrection(as:)`, `undoKeptCorrection()` and `dismissOfferedCorrection()`.
   - *Safety.* A message about eating fungi, preserving times, pesticide amounts or medicine gets its fixed reply as before and **is never offered as a correction**. `EiraSafety.fixedReply` was split so the chat can ask for those four on their own (`safetyReply`).
   - *The reply cannot pretend.* If the model answers a correction with "I've noted that", the rule that already removes false claims of saving now says where the correction really stands: "I have not kept that yet. Press "Keep it" on the card above", or, once kept, that it is kept and that the records themselves are unchanged (`EiraChecks.CorrectionStanding`).

2. **"Correct this" is a button under every reply** (`MessageView`). It is still in the press-and-hold menu too.

3. **The "Correct this" sheet is drawn like the rest of the app** (`EiraCorrectionView`). It was a standard `Form`. It is now a `SheetPage` with two `SheetCard`s and a `FieldBox`, the same pieces as the sowing form. It warns if what is typed is longer than the 240 characters read to the model.

4. **A new sheet, Corrections, in the chat's Options menu** (`EiraCorrectionsView`). Every correction, newest first, with the question it answered, when it was kept and a Remove button. From the eleventh on, each is marked "only when a question touches on it" (see the section above on handing corrections over). `@Query` reads the list from the database and keeps it current, so a removed card goes without the screen being told.

5. **Every line of a correction is read to the model** (`EiraCorrection.promptLine`, `EiraChatStore.oneLine`). Only the first line was, so a correction typed over two lines lost its second.

6. **One frame for every offer Eira makes.** The journal's "Add a harvest?" card frame (`OfferFrame` in `JournalOfferCards.swift`) was private to that file. It is now shared, with the filled button's title as a setting, so the correction card matches it.

7. **The chat keeps its newest thing in view.** The list now scrolls to a marker at its very end when a message, a piece of the reply or an offer card arrives. Before, it scrolled to the last message, which could leave a card below it out of sight.

**Checking aids.** `-demoOpen eira` opens the chat on an example exchange with the card showing. `-demoOpen corrections` also keeps two example corrections and opens the list. Both only work with the example garden, whose records live in memory.

**A second build script on the Mac.** `pull-side.sh` does what `pull.sh` does but builds the Mac app into its own folder (`DerivedData/Windfall-claude-side`). William had Windfall open with his real records when this was built, started from the usual folder, and a build into that folder would have replaced the app underneath him.

**Not done.** The rule only reads English openings it has been given, so it will miss corrections phrased another way. A correction is not yet shown anywhere outside the chat. The rest of the chat screen (the message bubbles, the settings and past conversations sheets) is still in the old look.

## 14 November 2026, morning: other chats' work brought into the main branch

**What happened.** On the evening of 13 November William asked other chats for four things, and each was committed on the Mac without being sent to GitHub:

| Commit | What | Asked of |
|---|---|---|
| `476540a` | The Plants page as glass cards under letters (`PlantLibraryCards.swift`, new) | the fine-tuning chat |
| `8fdca0b` | The Settings icon redrawn as an even eight-tooth gear | the settings icon chat ("Commit and relaunch the app") |
| `0fd5dfc` | The Today jiggle as a smooth side-to-side rock | the wiggle chat |
| `1b2c05f` | The journal asks the weather service for the stamp's hour, and the sidebar scrolls the way the Mac is set | another chat |

Two of them were committed straight onto the Mac's copy of `today-rearrange`. **The build chat's own script, `pull.sh`, then moved that copy back to what GitHub had, at 22:42, and they dropped out of the working copy.** Nothing was lost: a chat had already gathered all four on a local branch, `launch-13nov`. But from 22:42 anyone running the working copy from Xcode got the old gear back.

**What changed.**

- `launch-13nov` is merged into `today-rearrange` (`3b05ea5`). Git combined the two without a single clash. The checks pass on the result: 401 logic tests.
- One name in `PlantLibraryCards.swift` was changed (`runs` to `stretches`), only so that the cross-file checker does not confuse it with a function of the same name elsewhere.
- **`pull.sh` now refuses to move the Mac's copy if it holds commits GitHub does not have.** It prints them and stops. Before, it used `git checkout -B`, which means "make this branch match that one, whatever it held". That is the right tool only when nothing else writes to the copy, and on 13 November four chats did.

**The lesson**, now in doc 00: a chat that commits on the Mac sends its commits to GitHub straight away, or works in its own copy.

## 14 November 2026, morning: a warning under every photo match

**Why.** 300 unseen UK photos were run through the app with its new list of 776 names. It was right first time on 289 and said "not sure" for 10 of the 11 it got wrong. The eleventh was a photo of hemlock water-dropwort, one of the most poisonous plants in Britain, named as yellow iris at 87%. Hemlock itself was read as cow parsley or chervil, which the "not sure" level caught.

**What changed** (`SpeciesTable.swift`, `caveat`). The small print under every answer on the Identify screen now also says: never eat anything, or handle a plant that may be poisonous, on the strength of a match. One sentence, shown every time, whatever the plant.

**Not done.** A warning that appears only for plants with dangerous look-alikes would be better. It needs a checked list of those look-alikes. The fine-tuning chat has drafted one (`lookalikes.json`, doc 28) from memory, and it is not yet checked.

## 13 November 2026, late night: rules around the model

William asked how the models could be made cleverer, and chose two of the four ways offered: hand the model the facts when it is asked, and check its answer before he sees it. Both are done by fixed rules a person can read, with no model involved, so they help whichever model Eira uses. Each rule answers something a model got wrong on the test sheet that evening. `EiraChecks.swift` is new and holds most of it. 14 new logic tests, 401 in all.

**Before the model answers: a lookup the app runs itself.**

- *The mistake.* "What should I be sowing now?" Apple's model suggested parsnips in November. Qwen thought for four minutes and wrote nothing. Neither looked at the sowing months in the plant library.
- *The rule* (`EiraChecks.lookupFirst`). If a message is a question, mentions sowing and says "now", "this month", "this week", "today" or names the current month, the app runs a new lookup, `sowing_now`, and hands the result to the model with the question: "The app has already looked this up for you…". The model's job becomes reading a list out.
- *The lookup* (`ToolRunner.sowingNow` and `sowingText` in `EiraTools.swift`). It goes through the plant library, keeps the plants whose indoor or outdoor sowing months include this month, and writes them as two lists. At most 30 names each, with a count of the rest.
- *Why the model is not offered this lookup as one of its tools.* It already chooses among eight, and small models choose worse from a longer list. This one is only ever run by the rule.
- *How it joins the conversation* (`EiraConversation.send`). `forcedTool ?? EiraChecks.lookupFirst(for: trimmed)`. The `??` means "use the left side if there is one, otherwise the right": a lookup William forces by hand still comes first.

**A request to save something gets fixed wording** (`EiraSafety.asksToSaveARecord`, `savingReply`).

- *The mistake.* "I've added three rows of carrots to bed 2, can you save that?" Qwen answered "your sowing… is now recorded in the system". Nothing was.
- *The rule.* A message with a request ("can you", "please"…) and an act ("save that", "record it", "log this"…), or an act and a place ("add it to my journal"), never reaches the model. Eira says she has saved nothing, cannot from the chat, and how to record it in the journal.
- *What is let through on purpose.* "How do I save seed from peas?", "Can you put that another way?" and "Please note that I garden on clay" all still go to the model. The tests hold those in place.

**After the model answers: the reply is read by rule** (`EiraChecks.checked`, called from `EiraConversation.commitReply`). A reply William stops himself is left as it was.

1. *A claim to have saved is taken out* (`claimsToHaveSaved`, `withoutSaveClaims`). The reply is split into sentences. Any that says "now recorded", "I've saved", "I'll log", "has been added to your…" and the like is removed, and one plain line is added at the end: nothing has been saved. "You recorded a harvest on 9 November" is about William's own records and is left alone.
2. *A scientific name that no lookup supplied is flagged* (`uncheckedNames`). Qwen wrote "Marjoram (Origanum majoricum)" from memory, and it is probably the wrong name. The rule finds two-word names in italics or brackets and looks for each in the question, the lookups' results, the garden notes and the corrections. Any found in none gets a line at the end: "Not checked: the name … came from the model's memory, not from a lookup." It is a flag and not a correction: the name may be right.
3. *An empty reply is said to be empty.* Twice Qwen thought and then wrote nothing, and the chat showed nothing. It now says so and suggests asking again.

**What these do not do.** They do not make a model know more. They stop three kinds of mistake reaching William and put one kind of fact in front of the model. More rules of both kinds can follow the same pattern, each with its tests.

## 13 November 2026, night: Eira's bed lookup

**What was wrong.** Asked "What's growing in Bed 3?", Qwen3 8B looked up the bed as "3". The lookup only knew a bed by its exact name, so it answered "Nothing growing in 3 at the moment", and Qwen told William the bed was empty. French beans were in it. Apple's model happened to send "Bed 3" and got it right.

**What changed** (`EiraTools.swift`).

- `ToolRunner.bedMatches(asked:name:)` decides whether what a model wrote means a given bed. Both names are put in lower case, punctuation is dropped, a leading "bed" is taken off and number words become digits. So "3", "bed 3", "bed three" and "Bed 3." all find Bed 3, and none finds Bed 30.
- If the name matches no bed at all, the lookup now says so and lists the beds there are. "No such bed" and "an empty bed" are different facts, and the model was being given the second when the first was true.

**Why fix the lookup and not blame the model.** Any small model will phrase things loosely. A lookup that forgives that helps every model, including Apple's.

## 13 November 2026, night: naming what is in a photo

**Built on the Mac at the first attempt (22:43, Mac and simulator) and tried there.** The five test photos of doc 18 were run through the app itself with `SpeciesTestRun`, against a test list of 20 species: 5 of 5 named to species, each at over 99%, 5.4 seconds for the first photo (which loads the model) and 0.3 seconds for each after. That matches the Python test of 12 November, so the app's way of preparing a photo is sound. The matching has 13 logic tests (388 in all). **Not yet tried: the Identify screen by hand, the real UK list, William's own photos, an iPad.**

**What it does.** The Identify screen had a button that only said identification was not built. It now matches the photo against a list of UK species with BioCLIP 2, on the device, and names a species only when the match is strong.

**How, in three steps, and which file does each:**

1. *Prepare the photo* (`SpeciesEye.swift`, with the sums in `PhotoArithmetic` in `SpeciesTable.swift`). The photo is opened the right way up, its middle square is cut out and drawn at 224 by 224 pixels, and each colour value is adjusted the way BioCLIP 2 was trained to expect: take off an average, divide by a spread. The pixels are then rearranged from "red, green, blue, red, green, blue…" to "all the reds, all the greens, all the blues", which is the order the model wants.
2. *Run the model* (`SpeciesEye.swift`). Core AI loads `bioclip2_image_f16.aimodel` and runs its one function, `main`. In goes an `NDArray`, Core AI's block of numbers with a shape (1 photo, 3 colours, 224, 224). Out come 768 numbers that describe what the photo looks like. This is the only step that needs Core AI, so it is fenced with `#if canImport(CoreAI) && arch(arm64)`: "only build this where Core AI exists and the chip is one of Apple's own".
3. *Match* (`SpeciesTable.swift`). The table has one row of 768 numbers for each species. For each row, the photo's numbers and the row's are multiplied pair by pair and added up. The bigger the sum, the closer the match. The sums are turned into shares that add up to 1. If the top share reaches the "not sure" level that came with the table, the species is named. If not, the screen says "Not sure" and shows the closest three.

**Why a "not sure" level.** The model always picks something. The level was set on the Mac so that a named answer was right 19 times in 20 on photos it had not seen. Below it, a wrong name is too likely to show as if it were an answer.

**Fungi.** The table is made without fungi. The code also drops any row whose group is fungi when the table is read, so a later table that included them still could not name one.

**What a sighting started from the screen now holds** (`EiraVision.swift`, `createObservation`). A strong match goes in as the provisional name, marked "probable" and "on-device model". A weak one is not written in as a name at all: the closest three go in the notes. Before, the whole sentence of the answer was stored as the name.

**`SpeciesTestRun.swift`**, new: the photo twin of `EiraTestRun`. From Terminal it runs a folder of photos through the same code as the screen and writes what came back, with marks if it is given the right answers. It is how the app's own accuracy gets compared with the figures measured in Python on the Mac.

**Three files have to be in the Models folder**, in a folder called `bioclip2`: the model (there since 22:25), `uk_species.json` and `uk_species_rows_f16.bin` (being made by the fine-tuning chat). Until all three are there the screen says which are missing.

**The Identify screen is redrawn** (`EiraVision.swift`, commit `b4de32a`, not yet built or looked at). It was a standard form. It is now made of the same cards as the other sheets:

- It opens as a sheet from Today (`IdentifyView(inSheet: true)`, inside a `SheetPage`) and as a page from Wildlife (a `ScreenHeader` and the same cards). One set of cards, two frames, the way the sighting form does it.
- A photo can come **from Photos or from a file**. `.fileImporter` opens the Mac's or the iPad's file window. A file chosen there may only be read between `startAccessingSecurityScopedResource` and its matching stop call, which is the system's way of giving an app leave to read one file it does not own.
- Each possible species is a `CandidateRow`: its English name, its scientific name in italics, its share as a figure and as a bar. The bar is two capsules, a full-width track and a filled part on top. `GeometryReader` tells the row how wide its space is, and the filled part is that width times the share.
- The one that is named outright is larger and green. When nothing is named the card is headed "Eira is not sure" and says why.
- `-demoOpen identify -demoMatch YES` opens it with a made-up answer, so the cards can be looked at in the simulator, where the model cannot run.

## 13 November 2026, late evening: Apple's model package, and a test Eira can sit on her own

William asked for the converted models to be put into Windfall. Doc 27 in the knowledge base has the whole account. What changed in the code:

**Apple's `coreai-models` package is in the project, for the Mac only.**

- *What it is.* The Swift code that runs a converted language model (a folder ending `.aimodel`) and hands it to Apple's `LanguageModelSession`, which is what Eira's chat already talks to. Windfall's engine had the lines to use it since 11 November, fenced with `#if canImport(CoreAILanguageModels)`, which means "only build this if that code is present". Until tonight it never was.
- *Why through a go-between.* The iOS Simulator has no Core AI, so the package cannot be compiled there. Xcode builds a package the app depends on directly for every platform, whatever filter is set. A package can leave out one of its *own* dependencies by platform though. So `Packages/WindfallCoreAI` is a tiny package that depends on Apple's only on macOS (`condition: .when(platforms: [.macOS])`), and Windfall depends on that. Its one Swift file passes Apple's code straight on.
- *What it brings with it.* Nine other packages that Apple's depends on (for reading tokenisers and chat templates, among other things). `Package.resolved` now records the exact version of each, so every build uses the same ones.
- **The Mac app now needs macOS 27.0**, up from 26.0, because Apple's package does. The iPhone and iPad minimum is unchanged.

**Where models live on a Mac** (`EiraEngine.swift`). `Application Support/Windfall/Models`, not Documents. A Mac's Documents folder is often kept in iCloud, and a 4GB model would start uploading. Nothing had been put in the old place.

**"Add a model from a folder…"** in Eira's settings (`EiraChatView.swift`, `EiraModelLibrary.importModel`). A signed copy of Windfall runs in a "sandbox", a fenced-off part of the disk, and cannot read a model lying elsewhere. Choosing the folder in a file window gives Windfall leave to read it, and it copies the folder in. On the same disk the copy is a "clone": instant, and it takes no extra room.

**A test Eira can sit on her own** (`EiraTestRun.swift`, new, and `Tools/eira-test`).

- *Why.* The test sheet (`docs/eira-test-questions.md`) was 22 questions to type by hand for every model. Nobody was going to do that five times.
- *What it does.* Started from Terminal, the Mac app asks each question through the same code as the chat screen (`EiraConversation`), so the fixed safety replies, the lookups and the corrections all take part. It writes each answer, each lookup and the time taken to a file, then closes.
- *How.* `Tools/eira-test/run.sh coreAI qwen3_8b_4bit_dynamic qwen-1` on the Mac. It always uses the example garden, held in memory, so real records are never read or changed.
- *A trap worth knowing.* Every launch argument must be a pair: `-demoGarden YES`, not `-demoGarden`. A Mac treats a file path that is not paired with a dashed word as a document to open, and then never opens the app's window. The first two tries sat there doing nothing for that reason.
- *What it does not do.* Mark the answers. A person reads them against the sheet.

## 13 November 2026, evening: what William found in the first build

William tried the first build on the Mac and sent seventeen pictures. Each change below says why it was made. The pictures are in `Design/Reference`, named "2026-11-13 evening".

### The sliding switch (`GlassSwitch.swift`, new file)

- **Why**: dragged, the lens only slid. Apple's own switches lift into clear glass that magnifies. And there was no two-finger swipe.
- The lens now has two looks. At rest it is green glass. Lifted, it is clear, taller than its track, and the words under it are magnified by the same small graphics program as the sidebar's lens (`LensBend`).
- Its left and right edges are kept as two numbers. On a tap one edge sets off first, so it stretches across. While carried it stretches with its speed and draws back when the finger stops.
- On a Mac, a sideways two-finger swipe with the pointer over a switch carries the lens. An up-and-down swipe is left to the page.
- **The rule**: every bar of choices is a `GlassSwitch`. The last standard one, on Charts, was swapped.

### The jiggle (`TodayView.swift`, `Wiggle`)

- **Why**: every card rocked through the same angle in step, like a machine.
- Each card now has its own pace, chosen at random once, and bobs up and down a little as well as turning. A small card turns further than a wide one. Apple publishes no figures for its jiggle, so this copies what can be seen.

### A plan card for each garden (`TodayLayout.swift`, `TodayView.swift`)

- **Why**: the two garden plans moved as one card.
- `TodayPanel` changed from a fixed list of cases to a struct holding a name, so there can be one panel for each garden ("plan:allotment"). On a three-column screen each garden's plan is its own card. Narrower screens keep one card with the switch.
- An arrangement saved before this still reads: the old "plans" card is swapped for the garden cards where it stood.
- The arrows now sit astride the card's top edge. Inside the corner they covered the compass.

### Telling Eira something (`JournalChat.swift`, `EiraFloatingBar.swift`, `JournalChatView.swift`)

- **Why**: "Today I planted beans" typed into Eira's bar went to her ordinary chat, which looked for a record and found none.
- `JournalChat.readsAsTelling` is a fixed rule that tells an account ("I planted", "We harvested") from a question. It is cautious: in doubt, the words go to Eira as before.
- An account now opens the journal's conversation with the words waiting in the box. Sending it there notes the time and weather and brings up the card that asks which bean and where. A button hands the words back to Eira if it was a question after all.

### On a Mac: text size, going back, the sidebar (`PageZoom.swift`, `TextSize.swift`, new files)

- **Command and plus or minus** make the page larger or smaller, and Command and 0 puts it back. A Mac has no text size setting that apps can follow (tried on William's Mac: asking for larger type changed nothing), so the page is laid out for a smaller window and enlarged, as a web browser does.
- **Two fingers swiped right** go back a page. Each page that was opened on top of another hands `BackSwipe` its own way of leaving.
- **The sidebar can be hidden**: a button at the left of the window's bar, and "Hide Sidebar" in the View menu (Control, Command and S). On an iPad the button is in the sidebar's heading.
- **The rectangle behind the sidebar is gone.** The window and each page drew their own washes of colour, each from its own edges, so they did not meet. Pages now draw the window's (`PaperBackground(followsWindow:)`).

### Pages redrawn in the app's own look

- **Journal** (`JournalViews.swift`, `JournalPage.swift`): a card for each day, with the day's weather, what was written and what was recorded. A bar at the top opens the conversation. Ticks choose which kinds show.
- **Sightings** and **the sighting form** (`ObservationViews.swift`): cards, the app's icons and tags. The form is built from `SheetParts`.
- **Year** (`YearView.swift`): a "Fruit, veg…" button filters by kind of plant, using the Plants page's sorting. Every job button whose lines are showing is now lit green. Before, with "Every job" on, all five looked switched off.
- **The garden's plot** (`GardenEditorView.swift`): plus and minus turn the plan five degrees at a time, held down they keep turning, and the plan turns inside a compass ring with north at the top. The stray "Not set" beside each number is fixed.

### Sheets on a Mac can be made larger (`SheetParts.swift`)

- **Why**: a sheet such as the FIT Count had one fixed size.
- A sheet's frame is now given as smallest, usual and largest. It opens at the usual size and its edges can be dragged. A button beside the title jumps to a larger size and back.
- `SheetScroll` measures its cards and passes the height up (a SwiftUI "preference"), so a sheet still opens exactly as tall as what is in it.

### Plants that do not come true from seed (`SeedTruth.swift`, new file)

- **Why**: William tried to record a sowing of the apple 'Pendragon'. A pip from a Pendragon grows a new seedling, not a Pendragon.
- `SeedTruth` sorts plants by name into three habits: kept by cloning (apples, potatoes, garlic, soft fruit), crosses readily (squash, brassicas, sweetcorn, beet) and mostly true (tomatoes, peas, French beans, lettuce). **The lists are Claude's, not looked up, and need William's check.** Run over the real library they gave 88 plants kept by cloning, 73 that cross and 26 mostly true. 189 are not on any list.
- For a plant on the first two lists, or an F1 variety, the sowing form now asks how it was started. A plant, tree or tuber is recorded as planted. Saved or crossed seed records its seed parent, its pollen parent if known, and whether the cross was made by hand.
- Four new fields on a sowing hold that. All may be empty, so a database from before still opens. Backups carry them.
- The journal reads "Planted Apple" or "Sowed seed of Apple", with the cross written as seed parent × pollen parent.

### Recording a cross (`Crosses.swift`, `CrossViews.swift`, new files)

- **Why**: a cross is made in spring and its seed sown the year after. By then nobody remembers whose pollen it was.
- `PlantCross` is a new kind of record: seed parent, pollen parent, the date, whether it was by hand, whether the flowers were bagged, how many flowers, and later how much seed.
- Each parent is kept as a name in words and, where it is in the library, as that plant's identifier. So a neighbour's tree can be a parent, and a parent still reads correctly if its plant is later removed.
- **Gardens has a Crosses tile.** It lists them and has "New cross".
- **The sowing form offers them.** Sowing saved seed of a plant, it lists crosses made on that plant, then on others of its kind, and fills in the parents from the one picked. A sowing remembers which cross it came from (`crossKey`).
- Backups carry crosses. A backup made before they existed still reads.

### The sowing form's buttons (`SheetParts.swift`, `PlantingViews.swift`)

- **Why**: on a Mac, Apple's glass button style filled with green, so Cancel, Save and the resize button all looked like the main button.
- `QuietGlassButton` is dark glass with plain words. Every button that is not the main one now uses it.
- "Change" is now "Choose another", and the list it opens has a "Back to" button for the plant you had.

### Not seen or tried

Everything here was built on the Mac without errors. The lens moving, the jiggle, the swipes, Command and plus, and hiding the sidebar can only be judged by hand.

## "This week": the urgent jobs (`WeekJobs.swift`, new)

William: "Eira could organise the this week to make sure it is specific
based on the conditions... 'this is the last week to plant this seed or
plant or plant it out' that kind of thing, basically the urgents."

A seventh card on Today, above "This month". It lists:

- **Frost on the way**, named for the night before ("Frost on Sunday
  night"), or "Close to freezing" at 2°C or under.
- **Strong wind**: the windiest day of the week if gusts reach 40 mph.
- **A dry spell**: last week lost 15 mm more water to the air than fell
  as rain, and under 5 mm is forecast for the next three days.
- **The last week to sow** something not yet sown this year, when its
  sowing months end with this month. Indoor and outdoor months are
  taken together.
- **The last week to plant out** a sowing raised indoors or under cover.
- **A crop due** within seven days, or up to a fortnight overdue.

Weather first, then whatever runs out soonest.

- **Fixed rules pick the list, not the AI model.** A list of what is
  urgent has to be the same each time and has to be true. Rules can
  promise that and can be tested (12 new tests).
- ⚠️ CHECK: the four weather thresholds (0°C, 2°C, 40 mph, 15 mm) are
  Claude's rules of thumb. They are named at the top of `WeekJobs`.
- A job in "This week" is left out of "This month". Both use the same
  ticks.
- **The forecast** comes in the same reply as the current conditions
  (`WeatherService`), so there is no extra request. It now asks for
  today and the seven days after.
- **Last week's rain and water lost** come from the weather diary.
- The card says so when there is no forecast yet.
- Not done: jobs William adds himself, a plant bought as a plant
  (there is no record of one tree or bush yet), and Eira being able to
  read the list out.

**Found while doing this:** the weather check on Today sent the
garden's or device's location in full. Settings says it is rounded to
about a hundred metres. It is now rounded, as the weather diary's
already was.

`TodayLayout.swift`: "This week" is a new panel, above "This month" in
each standard arrangement. An arrangement saved before it existed gains
it as near its standard place as it can go.

## Sheets that look like the rest of the app (`SheetParts.swift`, new)

William, with pictures of four forms: "A lot of the buried menus are
looking quite different to the top level interface... There also seems
to be bars at the top and bottom of the windows".

Why they looked as they did: each was a standard `Form`. On a Mac a
Form is laid out in two columns, as tall as its rows and no taller,
inside a sheet that had been given a set height. The grey bands were
the sheet showing above and below the form. The title and the Cancel
and Save buttons sat in bars of the sheet's own.

- **`SheetParts.swift`** holds pieces for building a sheet in the app's
  own look: `SheetPage` (title, Cancel, Save, paper), `SheetScroll`,
  `SheetCard`, `SettingRow`, `FieldBox`, `NumberStepper`,
  `ProblemsCard`, `SheetMainButton` and `GlassSwitch`. A sheet built
  from them has no bars and is as tall as its contents, up to a limit.
- **Rebuilt from them:** the FIT Count and earthworm count, the new
  sowing form, "What did you harvest?" and the harvest form.
- **Every other form**, on a Mac, now uses the "grouped" look (boxed
  sections that scroll and fill the window), set once in
  `paperScreen()`. This is a stopgap that removes the two columns and
  the bare bands. The paper is also put behind the whole of each sheet
  (`macSheetSize`). **The title and button bars of those sheets may
  still be there.** They are to be rebuilt one at a time once they can
  be seen: the sighting form first.

### The counts (`SurveyViews.swift`)

- Setup is two cards. The conditions are three sliding switches and a
  small box for the temperature.
- **The conditions fill themselves in** from the weather service if
  Today checked it within the hour, with a line saying so.
- Counting has a ring that empties around the time left, larger rows
  and a hint under each worm group.
- ⚠️ CHECK: the four worm hints were written by Claude from AHDB's "How
  to count earthworms".
- The result shows each group with a bar for its share. All four worm
  groups are shown, because none found is worth knowing.
- **Abandon now asks first and throws the count away.** It used to keep
  it, looking like a finished count. Say if that should be put back.
- Fixed: the pit number showed 1 but was not recorded unless changed.
  An abandoned count left an iPhone's screen set never to sleep. The
  time left is no longer worked out by changing the screen's own state
  while it was being drawn.
- An iPhone buzzes when the time is up.

### The harvest forms

- With one thing growing, the harvest form opens straight away.
- With more, choosing a sowing swaps the list for the form in the same
  sheet, with a Back button, where it used to open a second sheet.
- Destinations read "Given away" and "Seed saved", not "Givenaway".

## The sliding switch (`GlassSwitch`, in `SheetParts.swift`)

William, of the Allotment and Permaculture garden switch: "The curves...
are different to the other boxes, it is also wider than the other boxes
... you can't drag it across like a slider".

It was the system's joined buttons. On a Mac they will not shrink below
the width of their words, so in a narrow column they stuck out past the
cards. `GlassSwitch` replaces them: a glass track the width it is given,
with a piece of green glass that slides to a tap and lifts and follows
a press and slide. It is used for the garden switch on Today, Gardens
and Weather, on the old garden map, and in the count and sowing forms.
The year switch on the Charts page is still the system's.

## Two-finger scrolling on the sidebar (`MainTabView.swift`, Mac only)

Two fingers on the trackpad, with the pointer over the sidebar, carry
the lens up and down. It settles on the nearest row when the fingers
lift. A mouse wheel moves one row a click. With Reduce Motion on, a
scroll is one step.

SwiftUI has no way to hear a scroll on a view that is not a scrolling
list, so the Mac is asked to pass every scroll in the app through the
sidebar first (`NSEvent.addLocalMonitorForEvents`). Scrolls elsewhere
are handed straight back untouched.

## Eira's bar

It ran out past the cards to the sidebar. It now stops 20 points in
from the left and 28 from the right, a little inside the cards' edges.

## The journal as a conversation (`JournalChatView.swift`, `JournalChat.swift`, new)

William, of the diary form: "the journal entry isn't very chat interface
like. Is there a way that we can add all these options into a sleeker
chat like interface?" This is the first slice of the design agreed on
12 November and drawn on the canvas as artboards A and B.

- **One box to write in and a send button.** Return sends. Shift and
  Return starts a new line.
- **The form's options are three chips above the box**: when ("Now"
  unless changed), the conditions and what it is about (the garden or
  one bed).
- **The conditions fill themselves in**: from the figures Today fetched
  if they are under an hour old, otherwise from that hour of the weather
  diary. Tap the chip to change them, and it says where they came from.
- **The title is written from the entry's own first words.** "This
  morning I mulched the raspberries with leaf mould and saw a wren"
  becomes "Mulched the raspberries with leaf mould". It is stored where
  Eira's headings go, so it is marked as written for you, and can be
  renamed.
- **Photos**: a button, or dragged on to the sheet on a Mac or iPad.
- **Hold the microphone to speak.** What is heard goes into the box to
  be read over, and is not sent by itself.
- **The day so far is above the box**: what has been written, as green
  bubbles with a stamp of time and weather, and that day's sowings,
  harvests, counts and sightings in between.
- **The time check.** Written after dark, or with "this morning",
  "this afternoon", "yesterday" or "earlier" in it, a card asks when it
  was about and offers each time with its weather. Send waits until one
  is chosen. "Dark" is worked out from the sun at the garden.
- **Press and hold a bubble** (right-click on a Mac) to rename it,
  change its details in the old form, or delete it.
- Each thing sent is an ordinary diary entry. **Nothing about how
  entries are stored has changed**, so no database check is needed.
- Opened from Today's Note button, Today's journal offer and the
  Journal's New entry button. Nothing is saved until something is sent,
  where the form made an empty entry as soon as it opened.

**Fixed rules, not the AI model**, write the title, choose the weather
word and decide when to ask about the time. Eira's lines are fixed
wording. 10 new tests.

Rain of 4 mm an hour or more is called "heavy rain". That is the Met
Office's own line: 4 mm an hour or more is "termed heavy" (its guide to
the rainfall map for government users, read 13 November 2026).

Not built: names becoming links, a day read back as a page, the wide
layout with days down the left, "this week in other years" and the
evening summary. The Journal page itself is still a plain list.

### The title reads the whole entry

William: "The title of the journal entry should more heavily analyse the
message as I might have a first sentence that's not necessarily what the
majority of the entry is about."

The first version used the first sentence. Now every word that says
something is counted across the whole entry, and each sentence is scored
by the words in it that the entry uses more than once. The title is made
from the highest-scoring sentence. A sentence that names one of the
garden's plants or beds counts double. "Cold start today. Spent the
morning mulching the raspberries with leaf mould, then pruned the autumn
raspberries and tied in the new canes. The raspberries look healthy." is
titled "Mulching the raspberries with leaf mould".

Still fixed rules. **Not done: asking Eira's model to write the title**,
which would read better still. It needs trying on the Mac, and would
only run where a model is available, with these rules as the fallback.

### Eira offers a harvest or a sowing (`JournalOffers.swift`, `JournalOfferCards.swift`, new)

The design agreed on 12 November: "We harvested 50 kg of Jonagolds"
brings up a card to add a harvest, and nothing is saved until Add is
pressed.

- When an entry is sent, its words are read for something harvested
  ("picked", "dug", "harvested"...) or sown ("sowed", "planted"...),
  followed by the name of a plant in the library.
- Each find is a card from Eira with what was understood filled in:
  the plant, the amount and its measure, where the crop went, the bed,
  where it was sown. Anything can be changed. **Add** saves it and Eira
  says so. The other button takes the card away.
- **Amounts**: "50kg", "2.5 kg", "a kilo of", "half a dozen", "12
  apples", or after the plant, "about 2.5 kg". Pounds and ounces are
  turned into kilograms and grams. No amount written means none guessed.
- **A name shared by several plants** ("apples") offers all of them to
  choose from. A variety ("Jonagold's") picks out the one.
- **Where a crop went** is picked up from words such as "froze",
  "stored", "for cider" (which counts as preserved), "gave".
- **A harvest for a plant with nothing on record as sown or planted**,
  such as a tree that was here before the app: the card says so, and
  adding the harvest also puts the plant on record as growing, with a
  note. The journal lists it as "put on record", not as sown that day.
- **A sowing in a named bed** is offered as the whole bed, since the
  words do not say which part.
- **Not offered**: plans ("need to sow"), things not done ("didn't
  pick"), "planted out" (that moves an existing sowing on, which is not
  built), and plants that are not in the library.
- Offers last until the next entry is sent or the sheet is closed.

Fixed rules, with 8 tests, William's own example among them. Rules will
miss some ways of putting things. A miss costs nothing: the entry is
saved all the same.

Along the way: "Under cover" and the other sowing places have their
wording in one spot (`SowingLocation.words`).

## A plant's page as cards (`PlantPage.swift`, new, and `PlantLibraryView.swift`)

William, of a plant's page: "Can you make these more card like as well.
You could use the overall sections that I used in my spreadsheet to
create sections."

- One glass card for each group of columns in the spreadsheet: Growth
  Patterns, Growth Habits, Permaculture Category, Sowing from Seed,
  Growth Constraints, Human Management, Ecological Interactions and
  Description. **A card with nothing in it is left out**, which the old
  page meant to do and did not.
- Two columns of cards where the page is 720 points wide or more, one
  where it is not. The cards are shared out so the columns come out
  about level.
- **Months are drawn as a strip of twelve blocks**, in the Year page's
  colours, with a ring on this month. They were written out in words.
- Short facts sit side by side with the name above the value. Long ones
  take the full width.
- Measurements have their units: "0.15 m", "25-50 mm".
- The permaculture roles are chips.
- The top of the page is the plant's name in the serif, its Latin name
  under it and "softneck · Alliums · Perennial" above.

`PlantPage.swift` decides what goes on each card and has no screen code,
so it is tested (4 tests).

## Companions: two columns, sides, symbols and pests (`CompanionPlanting.swift`)

William: "Could you make the companion planting two columns and then if
the window is narrow it has a top bar that has the friends and enemies",
and then: "I wonder if we could also have icons in with them... Maybe
there's a way that if you've identified a pest you can select plants
that deter them."

- **Two columns** from 640 points wide: "Grows well with" on the left
  and "Keep apart from" on the right, each a glass card. Narrower, a
  sliding switch at the top chooses Friends or Enemies.
- **Each plant is listed once.** The matrix can hold the same two plants
  more than once, and the old page listed them as many times.
- **The reasons now say whom they are for.** Each row of the matrix says
  what its second plant does for its first (its heading is "How plant2
  impacts plant1"). The old page ignored that, so on garlic's page
  "Carrots: deters carrot fly" read as something carrots do. It now
  reads "Garlic helps it: Deters carrot fly, root maggots", beside
  "Helps Garlic: Repel onion fly and leek moth".
- **A symbol for the kind of reason**, with the kind in words under the
  name: keeps pests off, draws pests away, brings helpful insects, feeds
  or opens the soil, shares the space, gives shade or cover, better crop
  or flavour, likes the same conditions. For enemies: shares pests,
  competes, stunts growth, toxic, wants different conditions. The kinds
  are worked out from the words of each reason. Tried on every reason
  in the shipped matrix, four of about 145 fit no kind and show a plain
  tick or cross. The symbols are Apple's, standing in until Windfall
  has drawings of its own.
- **Pests.** Where a plant's friends help it against pests the matrix
  names, those pests are chips above the lists. Picking one leaves only
  the friends that help against it.
- **"Pest helpers"** (new page): start from the pest. Every plant the
  matrix records as helping against it, with the crops it is recorded
  with. Reached from the foot of any Companions page, and from a new
  card on a plant's page that lists those of its known pests the matrix
  has an answer for.

⚠️ CHECK: the pests are found from a list of names and the ways the
matrix writes them, made by Claude. Greenfly and blackfly are counted as
aphids. Cabbage worms, cabbage moths and cabbage whites are counted as
caterpillars. Carrot root fly and carrot rust fly are counted as carrot
fly. Blight is in the list though it is a disease. A pest that is not
in the list is not found.

6 tests, using rows from the matrix as shipped.

Not done: icons drawn in Windfall's own style, a picture of each plant,
a link from a recorded pest or disease to its helpers, and Eira being
able to answer "what deters carrot fly?" from the same list.

## A filter in the middle of the bar

William, of the Journal's filter menu on the Mac: "Is there a reason
that this menu is in the middle of the top bar?" No good one. It was
placed as a `.secondaryAction`, which an iPhone tucks into its "more"
menu and a Mac puts in the middle of the window's bar, on its own.
`ToolbarItemPlacement.besideMain` (in `Theme.swift`) now puts such a
button at the right-hand end on a Mac, beside the main button, and
leaves an iPhone and iPad as they were. Used for the Journal's filter,
the sightings list's group filter and the sowings list's "Show
finished".

## To check when it is built

- Each rebuilt sheet on the Mac, iPad and iPhone, light and dark. Does a
  Mac sheet take the height of its contents, and follow when they
  change (setup, counting, result)?
- Do the other sheets still have bars at the top and bottom?
- The sliding switch: does the glass read well on the track? Does a
  page still scroll when a finger starts on a switch?
- The sidebar: is 0.6 the right gearing? Does scrolling still work in
  the page beside it?
- "This week" with a real forecast.
- Does Return in a notes box press Save when it should make a new line?
- A plant's page: are the month strips clear, and are the two columns
  about level? Try a plant with little filled in.
- Companions: two columns when wide, the switch when narrow. Do the
  symbols exist and read well? (One wrong symbol name shows as a blank.)
- The offer cards: do the small menus on them (plant, measure, where it
  went) look right on a card? Try "We harvested 50kg of Jonagold's".
- The journal's conversation: does the box stay above the keyboard on
  an iPhone? Do the two small panels (when, conditions) open as panels
  and not full screens? Does a photo dragged from Finder or Photos land?
  Does holding the microphone work beside the text box?

# 13 November 2026, morning: rearranging the Today screen

**The `today-rearrange` branch**, on top of `weather-diary`. **Not yet
built on the Mac and not seen running**: the link to the Mac was down
while this was written. It passes the checks that can be run without the
Mac (every file reads as valid Swift, 311 logic tests pass), but those
do not build the screens. Treat everything about how it looks and feels
as untried until it has been built and used.

William asked: "Can we make it so that you can rearrange the home view by
tapping and holding the object (like the This month box), and it wiggling
to rearrange".

## What it does

- **Press and hold a card** on Today and all the cards start to wiggle.
  On an iPhone or iPad the card lifts under the finger, ready to drag.
  On a Mac, click and hold for half a second, then drag.
- **Drag a card onto another** and it takes that card's place. The other
  cards move along.
- **A dashed "Drop here" space** sits at the foot of each column while
  rearranging, and one at the top and bottom for full width. This is how
  a card reaches an empty column, or is made to span the page.
- **Two arrows on each card** move it one place earlier or later without
  dragging. They are there for anyone who finds dragging awkward and for
  VoiceOver.
- **A bar at the top** says what is going on, with Reset (the standard
  arrangement) and Done. A "Rearrange this page" button at the foot of
  the page starts it too, so it can be found without knowing about
  press and hold.
- **Each width keeps its own arrangement**: three columns (Mac, wide
  iPad), two (narrower iPad) and one (iPhone). Moving cards on the Mac
  does not disturb the iPhone's order.
- **Cards fit the room they are given.** The capture buttons are a row of
  six at full width, three across in a wide column and two in a narrow
  one. The conditions card stacks when it is put in a column. With three
  columns, the one holding the garden plans gets the most room.
- **The journal offer** only appears on days when there is something to
  offer. While rearranging it shows as a placeholder so it can still be
  given a place.
- **Reduce Motion** (an Accessibility setting) swaps the wiggle for a
  dashed outline.

## How it is built

- **`TodayLayout.swift`** (new) holds the arrangement and its rules, with
  no screen code in it, so it can be tested without the Mac. A
  `TodayPanel` is one movable card. A `TodayArrangement` is the list of
  cards in each zone (a full-width stack at the top, each column, a
  full-width stack at the bottom). It can move a card onto another, move
  one to the end of a zone, nudge one a step, and turn itself into a line
  of text to be saved and back again. Reading saved text is forgiving: a
  card it does not know is skipped and a card that is missing is put
  back in its standard place, so adding a card in a later version cannot
  lose anyone's arrangement.
- **`TodayView.swift`** now draws the page from the arrangement where it
  used to have the three layouts written out by hand. The cards
  themselves are unchanged. The pieces that do the wiggling and dragging
  (`Wiggle`, `LiftToArrange`, `DragSurface`, `DragLabel`) are at the foot
  of the file.
- The arrangement is saved as text under three settings names:
  `todayArrangementWide`, `todayArrangementMiddle`,
  `todayArrangementNarrow`. The standard arrangement is saved as nothing
  at all.
- 19 new logic tests cover the arrangement.

Checking aid: `-todayArranging YES` opens Today already wiggling. An
arrangement can be tried without dragging by passing its saved text, for
example `-todayArrangementWide "conditions|jobs,capture|plans|recent,journal|"`.

## To check when it is built

- Does a press and hold on an iPhone or iPad lift the card and carry on
  into a drag in one movement, with scrolling still working?
- Does the Mac's click and hold start the wiggling without pressing the
  button under the pointer?
- If a card is let go outside the window, does it stay dimmed? (It may.
  Done clears it.)
- Is the wiggle the right size on the wide cards?
- Does the bar at the top cover the page heading?

# 12 to 13 November 2026, overnight: the weather diary, fixes and a sweep of the code

**The `weather-diary` branch**, on top of `plant-filters`. Builds on the
Mac for macOS, iOS and the iOS Simulator with no new warnings. 292 logic
tests pass. Looked at in the iPad Pro, iPad mini and iPhone simulators.
A database made by the `plant-filters` version opens in this one
(tried in the iPad mini simulator). **Not run with William's real
records.**

## The weather diary (`WeatherDiary.swift`, `WeatherDiaryView.swift`)

William asked for "a record of the weather for the day(s) and longer
term". The app now keeps one record a day for each garden that has a
location: coldest, warmest, rain, strongest wind, sunshine, water lost
to the air, soil temperature at seed depth, the kind of day, and the
temperature, rain, cloud, wind and soil for each hour.

- **It fills itself in.** When the app opens, and each time it comes
  back to the front, it works out which days are missing and fetches
  them. Nothing needs to be pushed to the app and no day is lost by not
  opening it. It asks the service at most once an hour for each garden.
- **Two sources, both Open-Meteo.** The ordinary address for the newest
  days, and the long-term record for older ones. Found by trying it:
  asked for 92 days, the ordinary address sent figures for only the
  newest 64, so days older than that come from the long-term record,
  which runs about five days behind. Each day records which it came
  from.
- **Today's record is part forecast** and is marked unfinished. It is
  fetched once more after the day ends and then left alone.
- **Frosts come from the diary.** A finished day that went to freezing
  or below becomes a frost record, once. This replaces the separate
  frost check, which asked the service a second time for the same
  figures and needed the device's location.
- **Gardens within about a mile share one diary.**
- **The Weather page**, from the Gardens page's Weather tile: four
  figures (the latest finished day, the week's rain against water lost,
  soil temperature, the last frost), the last 30 days as two charts,
  the days one by one, and this year's frosts. Each day opens to its own
  page with the temperature and rain hour by hour. "Fetch a year of
  earlier weather" goes further back.
- **The hour-by-hour figures are what the journal's time check needs**:
  `WeatherHours.conditions(atHour:)` gives the conditions at any hour of
  any day held.
- **These are not readings from the garden.** They are worked out for
  its place on the map from weather models. The page says so.
- **Credit.** Open-Meteo's licence asks for one wherever its figures are
  shown. It is on the Weather page, each day's page and in Settings.
- The Settings line "Nothing is sent anywhere" was not quite true and
  now says what is sent: each garden's location, rounded to about a
  hundred metres, to the weather service.
- The diary is not in the backup file. It can be fetched again.

Not built: fetching in the background while the app is closed, the
Shortcuts actions and the HomeKit sensors. See the project notes.

Checking aids: `-demoWeather` opens the Weather page and
`-demoWeatherDay` opens the newest finished day, both with `-demoGarden`.

## Three small fixes

- **Fruit trees now show on the Year page's Harvest.** Their months are
  in the Fruiting/Harvest column, which arrives in a different field.
  Harvest now reads both.
- **Frost records come back from a backup.** They were written to the
  file and never read from it. Their garden and notes are now in the
  file too.
- **The voice wave moves.** Its bars were meant to ripple and stood
  still, because the ripple was driven by a kind of animation a Canvas
  cannot follow. It now follows the clock.

## A sweep of the code for waste

William asked for "a high quality sweep of the code to check for
anything extraneous or anything that would add inefficiencies". Timings
are from the test harness, built unoptimised, as Xcode builds when
running from it.

| What | Before | Now |
|---|---|---|
| Reading month text ("mar apr may") | Read afresh on every call, 54 millionths of a second each. The Year page asked about 1,700 times a redraw, so about 90 thousandths of a second each time a button was pressed or a letter typed. Today's jobs and the Plants filters did the same | Each piece of text is read once and remembered (`MonthParser`). A needless sort on every call is gone |
| Sun hours in the garden editor | Worked out bed by bed, each time working out every shadow again: 62 thousandths of a second a redraw for ten beds in June | Every bed in one pass over the same shadows: 17. The answers are identical, which a test checks (`Shade.sunHours(onEach:)`, `GardenPlan.sunHours(forBedsIn:)`) |
| Today's jobs and recent records | Each worked out up to four times a redraw | Once |
| Today's weather | Fetched again every time Today was returned to, with the card going blank meanwhile | One weather service for the app, which keeps its answer |
| Month names and the number pattern | A date formatter or a pattern built on every call | Built once, or asked of the calendar |
| The frost check | A second request for figures the diary now has | Gone |

Removed as no longer used: the `WeatherSnapshot` record, which nothing
ever wrote or read. The weather diary does its job.

Notes in the code that still spoke of writing back to a spreadsheet are
corrected.

**Two speed checks in Settings**, for William to try, because their
effect could not be measured without watching the app move:

- **Plain background** leaves out the two large, heavily blurred washes
  of colour behind every screen.
- **Plain fade between places** swaps the melt for a simple fade.

Found and left alone, for William to decide:

- Unused but looks planned: `EiraChatStore.recentChats`,
  `EiraVisionPrompt`, `WebSearchProvider`, `TaxonMapper`,
  `NotificationService.scheduleFrostWarning`, `RangeParser.upperBound`.
  `GardenPlan.overlappingBeds`, `Bed.longSideFaces` and
  `Sun.noonAltitude` are used only by the tests.
- Two icons are drawn and never shown: `saved` and `north`.
- `Plant.sourceRow`, `sourceSheet` and `lastSyncedAt` are filled on
  import and never read.
- Every change of place in the sidebar builds the new screen from
  nothing and runs all its database questions again. That is how each
  place gets a fresh "back" trail. Keeping the screens alive would be
  quicker and is a bigger change.
- The garden editor still works out the sun again on every redraw,
  including ones that change nothing about the layout.

# 12 November 2026, late night: filters on the Plants screen, and Gardens and Wildlife redrawn

**The `plant-filters` branch**, on top of `visual-design`. Builds on the
Mac for macOS, iOS and the iOS Simulator. 251 logic tests pass. Looked at
in the iPad Pro and iPhone simulators, light and dark. **Not run with
William's real records. The menus have not been seen open: William
should try them on the Mac.**

## Filters on the Plants screen (`PlantFilter.swift`, `PlantLibraryView.swift`)

William asked to filter by "permaculture layer, Fruit, Vegetables,
Season of (sowing, fruiting, flowering, etc), Plant family (brassica,
etc)". A row of glass buttons sits above the list, in the style of the
Year page's buttons. Each opens a menu, and each choice shows how many
plants it would leave, with the other buttons still applied.

| Button | Choices | Read from |
|---|---|---|
| Growing | Growing, To buy, Previously owned, All plants | The plant's status |
| Fruit, veg… | Fruit, Vegetables, Herbs, Flowers, Green manure, Not sorted | The plant's group (see below) |
| Layer | Trees, Shrubs, Herbaceous, Ground Cover, Vines, from the canopy down | The Layer column |
| Family | Alliums, Beans, Brassicas, Gourd, Root veg and the rest | The group, two spellings counted as one |
| Season | Sowing, Sowing indoors, Sowing outdoors, Planting out, Flowering, Fruiting or harvest, in this month or any month | The month columns |
| Role | Pollinator, Nitrogen fixer, Dynamic accumulator, Ground cover, Pest repeller, Umbellifer. More than one means all of them | The tick columns |

- A chosen button turns pale green and says what is chosen, such as
  "Vegetables" or "Sowing in March". "Clear" appears when anything is
  chosen and puts everything back, leaving the search as typed.
- The old menu's "Pollinator plants only" and "Sowable this month" are
  now Role and Season. "Garden data" is a button of its own.
- The screen is titled "Plants", as in the sidebar, not "Library".
- "Fruiting or harvest" reads both the allotment's Harvest column and the
  permaculture sheet's Fruiting/Harvest column, which arrive in two
  different fields. **The Year page's Harvest reads only the first**, so
  fruit trees do not show there. Worth fixing.

**How fruit and vegetables are told apart.** The records have no fruit
or vegetable column. The group decides: Fruit is fruit. Root veg, Leaves,
Brassicas, Gourd, Alliums, Beans, Nightshades and Microgreens are
vegetables. Herbs are herbs. Wildflower, Flower, Pollinators, Ornamental
and Shrub (the roses, hydrangea and spiraea) are flowers. **Claude chose
this sorting.** In the real library: 71 fruit, 108 vegetables, 37 herbs,
121 flowers, 4 green manure and 35 not sorted, which are the plants with
no group, such as Asparagus, Purple Orach and several wildflowers.
"Not sorted" is a choice in the menu so they can be found and given one.

**Family is the group, not the botanical family.** The records' groups
are what the menu offers. Rosaceae, Brassicaceae and so on are not in the
records. They could be added from the Latin names, as researched data for
William to check.

Checking aid: `-plantsKind Vegetables`, `-plantsLayer Shrubs`,
`-plantsFamily brassica`, `-plantsSeason Sowing`, `-plantsMonth 3` and
`-plantsRole Pollinator` start the screen with those chosen.

## Gardens and Wildlife look like Today (`HubScreens.swift`)

William: "Can these look more like the today page?" Both were plain lists
of links. They are now built like Today: a line of facts above a large
serif title, then glass cards and tiles. Both moved out of
`MainTabView.swift` into a new file.

- **Gardens**: "2 gardens · 10 beds · 1 sowing on the go", the garden
  plans drawn to scale (side by side on a wide screen), then eight tiles
  with a line of facts each: Plants (335 growing · 40 to buy), Year
  (17 to sow this month), Sowings, Beds, Garden map, Seed, Scan a seed
  packet, Frost and weather. On an iPhone the tiles come first, because
  this page is the only way to Plants and Year there, and the plans show
  one at a time with a switch, as on Today.
- **Wildlife**: "2 sightings and 0 surveys this year · 1 to confirm",
  four tiles (Sightings, Surveys, Species, Identify from a photo), then
  cards for the latest sightings, tagged Confirmed or Provisional, and
  the latest surveys.
- Shared pieces any page can use: `ScreenHeader`, `HubTile`,
  `HubSectionTitle`, `ViewAllLink`.
- Three tiles use Apple's symbols until there are drawings for them:
  Beds, Seed and Scan a seed packet. Plants and Sowings share the same
  sprout drawing. Both for the next round of icons.

## Filed

William's four screenshots from this evening are in `Design/Reference`:
the plant library, Gardens and Wildlife before, and the journal's entry
form, which he wants redesigned as a conversation with Eira.

# 12 November 2026, night: the Year page, and the sidebar lens switched on

**Still the `visual-design` branch.** Builds on the Mac for macOS and the
iOS Simulator. 223 logic tests pass. Looked at in the iPad Pro and iPhone
simulators, light and dark. **Not run with William's real records.**

## The Year page (`YearView.swift`, `YearCalendar.swift`)

William chose from four options on the design canvas: "the small dots
that are in option A", "the bars with the curved ends in option B, so
that if the months you can sow or plant etc are consecutive, it's a bar,
but you still have the dots otherwise", and option C "as a toggle on and
off".

- A small faint dot for a month with nothing to do. A filled dot for a
  job that fits one month. A bar with round ends for months in a row.
- A ring inside a mark where it crosses this month, and a soft band down
  this month's column.
- A window that crosses the new year (October to February) is drawn with
  square ends at the edges of the year.
- **"Every job"** shows all five jobs on each plant as thin lines. Each
  job keeps its own height in the row. Sowing indoors is an outline and
  flowering is a row of dots, so the lines differ by shape as well as
  colour. The job buttons then switch single lines on and off.
- Plants are grouped by family (`Plant.group`), with the variety beside
  the name. A menu offers "By when it starts" and "A to Z".
- Tapping a plant opens its page.
- The marks are one drawing per row (`Canvas`), with the same thing said
  in words for VoiceOver.
- Five named colours were added for the jobs (`Design/colours.json`).
  The first four pass a colour-blindness check as a set. Violet for
  flowering does not pass against the blue, which is why those two
  differ by shape. **The colours are Claude's proposal.**
- The old `SowingCalendarView` is gone. `SearchAndCalendar.swift` now
  holds only the search.

Found in the data: one plant's family is spelt "Allium" where the others
say "Alliums". The page treats them as one family. The record is not
changed. "Leek" and "Leeks" also both appear as plant names.

## The sidebar lens is on

William agreed to the Metal Toolchain (838.9 MB, from Apple through
Xcode). It is installed, `Lens.metal` is back inside the app and
`LensRefraction.isBuilt` is true.

- Lifted, the lens is clear with a bright rim. What is under it is
  magnified a little, the rows just outside are squeezed in at the rim
  and there is a faint colour fringe.
- At rest it is Apple's glass tinted lime, as before.
- The amounts in `Lens.metal` were tuned once from still pictures:
  rim 11 wide, reach 11, fringe 2, magnification 10 per cent.
  **William has not yet judged it moving.**
- The toolchain does not make anything faster. William reported the app
  feeling slow and glitchy. The cause is not yet known.

## Checking aids

- `-sidebarLensHeld 0.5` holds the lens lifted, moved down by that many
  rows. `0` holds it over the chosen row.
- `-demoYear` opens the Year page in place of the Gardens list, which is
  how it is checked on an iPhone.
- `-yearShowsEveryJob YES` starts with every job showing.

# 12 November 2026, late evening: Eira knows the screen, and a lens for the sidebar

**Still the `visual-design` branch.** Builds on the Mac for macOS and the
iOS Simulator. 209 logic tests pass. Looked at in the iPad Pro simulator.
**Not run with William's real records, and Eira's use of the new screen
hint has not been tried with a real model.**

## What is new

- **Typing straight away** (`EiraFloatingBar.swift`). Pressing the
  snowdrop gives the text box the keyboard at once, so typing can start
  while the bar is still opening. Before, the keyboard waited for the
  animation to finish. Command-K opens the bar from the keyboard.
- **Eira is told what is on screen** (`EiraScreen.swift`). A screen says
  what it shows with one line, `.eiraLooksAt("the plant Apple, Spartan",
  short: "Apple, Spartan")`. The bar's hint then reads "Ask Eira about
  Apple, Spartan", and the phrase is put in front of the question for the
  model only. The chat shows what she was told, with a "Don't use this"
  button. Screens that do this so far: each sidebar place, a plant, a bed,
  a sowing, a species, a garden plan and a seed packet.
  - She does not see the screen. She gets one phrase the screen wrote.
  - A fixed safety reply still wins over anything on screen (tested).
  - With no phrase, nothing about her prompt changes (tested).
- **The sidebar's highlight is a lens** (`MainTabView.swift`). At rest it
  is Apple's glass, tinted lime, lying over the rows. It can be carried
  by pressing and sliding, and settles on the nearest row.
- **Files William sent this evening** are in `Design/Reference`: four
  screenshots and his recording of the bottom bar in Apple's Music app.

## Waiting on one thing

William wants the highlight to magnify and bend what is under it as it
moves, like the lens on the tab bar in Apple's Music app.

- Apple does not offer that lens as a separate piece. The public glass
  (`glassEffect`, `Glass.regular`, `.clear`, `.tint`, `.interactive`,
  `GlassEffectContainer`, `glassEffectID`, `glassEffectUnion`) was
  checked in the SDK on William's Mac (Xcode 27.2). In the simulator,
  clear glass frosts what is behind it. It does not magnify it.
- On iPhone the app uses Apple's own tab bar, which has the real lens.
- For the sidebar the bending is written as a small program for the
  graphics chip, `Design/Shaders/Lens.metal`, called by `LensRefraction`
  in `MainTabView.swift`.
- **It was switched off at this point**, because Xcode cannot build a
  `.metal` file without the "Metal Toolchain". That was installed later
  the same night and the lens is now on. See the section above.
- To switch it on: install the toolchain
  (`xcodebuild -downloadComponent MetalToolchain`), move `Lens.metal`
  into the `Windfall` folder, set `isBuilt` to true, build.
- ⚠️ The program has never been built or seen running. Expect to tune it.

## A checking aid

Starting the app with `-sidebarLensHeld YES` leaves the lens lifted and
between two rows, so a still picture can show the bending.

## Design work, not code

Four options for the Year page are on the design canvas ("Windfall
redesign"): dots, ribbons, every job on one line, and this month first.
William has not chosen yet. The Year screen in the app is unchanged.

# 12 November 2026, evening: the visual design

**This is the `visual-design` branch.** It sits on top of `garden-editor`.
It builds on the Mac for macOS, iOS and the iOS Simulator, and has been
looked at on the Mac and in the iPhone, iPad Pro and iPad mini simulators.
William has tried it in the example garden. **It has not been run with
his real records.**

## Why

William has concept art for how Windfall should look (doc 15 in the
knowledge base, and `Design/Reference`) and asked for it to be built with
Apple's liquid glass, with Eira as a floating button.

## What is new

- **A theme** (`Theme.swift`). Every colour has a name, a light value and
  a dark value. Screens ask for `Theme.paper` or `Theme.leaf` and never
  write a colour of their own. Titles use a serif face at medium weight
  and body text is regular weight, after William found the concept art
  "too bold".
- **Icons** (`Design/Icons`). 35 icons redrawn as SVG files to match
  William's reference picture. Each is its own file, so one can be
  replaced without touching code.
- **Colours and icons are built by a script**,
  `Tools/design/build_design_assets.py`, from the `Design` folder.
- **The frame** (`MainTabView.swift`). A dark green glass sidebar on Mac
  and iPad, tabs on iPhone. One list of places drives both. The sidebar's
  highlight stretches and snaps between rows like a drop of liquid.
- **A new Today screen** (`TodayView.swift`) replacing `DashboardView`:
  the date, a conditions card, six capture buttons, this month's jobs
  with tick boxes, garden plans, recent records with Confirmed and
  Provisional tags, and an offer to write a journal entry from what was
  logged that day.
- **Garden plans drawn to scale** (`GardenPlanView.swift`) from the
  measurements on each record: beds, planted sections, sheds, ponds,
  trees, things outside the boundary, dimension lines and a compass.
- **A first garden editor** (`GardenEditorView.swift`): a form for the
  plot, each bed and each feature, with the plan redrawing above it and
  hours of direct sun for each bed this month.
- **A compass** (`CompassRose.swift`). On iPhone and iPad it can follow
  the device, turning the plan to match the ground, and can set which way
  a plan faces. ⚠️ Not tested: neither the Mac nor the simulator has a
  compass.
- **Eira's floating button** (`EiraFloatingBar.swift`, `Snowdrop.swift`).
  Her snowdrop sits bottom right. Tapped, it is blown across to the
  sidebar, bumps against it and settles, drawing out a bar to ask, search
  or open anything. The snowdrop is William's own drawing, kept as shapes
  so the stem can lean and the flower head can swing.
- **Paper behind every screen.** Each titled screen gained one line,
  `.paperScreen()`.
- **An example garden** (`DemoGarden.swift`), shown only when the app is
  started with `-demoGarden`. It lives in memory and never touches real
  records.

## Decided along the way

- Eira opens blown by the wind. The rolling version is in
  `Design/Archive` with its code.
- The bar runs the full width, across to the sidebar.
- "Plans" was left out of the sidebar, because it looked like the same
  place as "Gardens".
- The Eira tab is gone. She is reached from her button on every screen.

## Not done yet

- Icons still to draw: bird, newt, blossom, leaf, seeds, fruit,
  vegetable, snow.
- Jobs in "This month" are worked out from records. You cannot yet add
  your own.
- The Photo button opens "Identify from a photo", which cannot identify
  anything yet.
- The older screens have the paper background and green tint but are
  otherwise unchanged.
- The garden editor is a plain form. Gardens cannot be added and beds are
  still added in Gardens, then Beds.
- No app icon.

---

# Overnight, 11 to 12 November 2026: the workings behind the garden editor

**This is the `garden-editor` branch.** It is kept apart from
`eira-on-device` so the version being tested is not disturbed. Checked
here (200 logic tests pass) but **not yet built in Xcode**. No screen has
changed, so the app looks the same.

## Why

William wants to draw each garden from measurements, set which way it
faces, add things inside and outside it, and see where shade falls. The
app had two gardens written into the code and a map that drew every new
bed in the same corner.

## What is new

- **`GardenLayout.swift`: gardens and features as records.**
  - A `Garden` holds its name, size, which way the top of the plan faces,
    slope, soil and location. The allotment and the permaculture garden
    are made as records the first time the app opens. More can be added.
  - A `GardenFeature` is anything on the plan that is not a bed: path,
    shed, greenhouse, compost, water, tree, hedge, fence, building. It
    has a position, size, rotation and height. A negative position puts
    it outside the plot, such as a neighbour's tree.
  - A feature can be marked as see-through (a fruit cage) so it is drawn
    but casts no shade.
- **Beds have a height**, so a tall raised bed or bean frame can shade
  its neighbours.
- **`SunAndShade.swift`: where the sun is and where shadows fall.**
  Plain arithmetic with no database or screens in it.
  - The sun's height and compass direction for any latitude, day and time.
  - The outline of the shadow each object casts.
  - Hours of direct sun on a bed, for a day or for each month.
- **Help for the editor:** a check for beds that overlap, and a way to
  spread out beds that have never been placed.
- **Backups carry the layout.** The backup file now holds gardens,
  features and each bed's position, size, rotation and height. Before
  this, a restored backup lost where every bed was. Older backup files
  still restore.
- **Eira's fixed safety replies were fact-checked** and now name UK
  sources. See the comments in `EiraSafety.swift`.

## How beds find their garden

Every bed already stores a short piece of text saying which garden it is
in: "allotment" or "permaculture". Each `Garden` record has a `siteKey`
holding the same text. So no existing record had to change.

## Not done yet

- The screens still use the old fixed list of two gardens. The editor
  screen and a map that draws to scale come next, and need Xcode.
- The existing map turns a bed about its middle. The new sums turn it
  about its first corner, the one you measure. The map must follow.
- Shade ignores the slope and treats a bare tree like one in leaf.
- Found on the way: frost records are written to the backup file but
  never restored from it. Not fixed here.

---

# Later on 11 November 2026: three more safety rules in code

Written away from the Mac. Checked here (138 logic tests pass) but
**not yet built in Xcode**.

**Why:** the mushroom question showed the model follows its "never"
rules most of the time, not every time. Three more rules are serious
enough to take away from the model completely:

- **Preserving.** Questions asking for canning, bottling, pickling or
  kitchen blanching times, temperatures or safety get fixed wording that
  points to a tested, published recipe. Garden blanching (keeping light
  off celery, endive or leeks) still goes to the model.
- **Pesticide amounts.** Questions asking how much slug pellet,
  weedkiller, pesticide or homemade spray to use get fixed wording that
  points to the label and offers chemical-free ideas.
- **Medicine.** Questions asking for doses, remedies or medicinal uses
  get fixed wording that points to a GP, pharmacist or qualified
  medical herbalist.

**How it works:** `EiraSafety.swift` tidies each question (lower case,
punctuation turned into spaces) and looks for two halves together, such
as a preserving word and a time word. Needing both halves keeps ordinary
gardening questions reaching the model. The model's own rule 12 is still
there as a second line of defence for anything the word lists miss.

**Known gap:** "How long do I can tomatoes?" is not caught, because
"can" on its own appears in too many ordinary questions. Rule 12 covers it.

⚠️ CHECK: the sources named in the preserving reply and the point that
UK pesticide labels are legally binding were written by Claude from
general knowledge.

---

# Changes on 11 November 2026

These came out of the first evening of building and running the app on
the Mac. The older notes follow below and describe how things stood on
10 November.

## The app builds and runs

- The Xcode project from the Mac is now in the repository.
- Three fixes were needed for the first build: a `Section` form SwiftUI
  does not offer (`SurveyViews`), a missing `import SwiftData`
  (`MainTabView`) and two main-actor warnings (`ExportService`).
- Opening Eira crashed because `Info.plist` gave no reason for using
  speech recognition. Reasons for speech, the microphone and location
  were added, and the matching Mac sandbox permissions switched on.

## Google is gone

- No sign-in, no welcome screen, no Sheets reader or write-back and no
  GoogleSignIn package. The app opens straight into the garden.
- Reference data now comes from `Windfall/StarterData.json`, loaded on
  first launch, or from a JSON or CSV file chosen in
  Settings > Garden data.
- The app's own database is the master copy and stays on the device.

## Eira

- Questions about eating fungi or naming a mushroom get fixed wording
  from `EiraSafety.swift` and never reach the model.
- `lookup_species` tries your own records, then GBIF, then Wikipedia to
  turn an everyday name into a scientific one.
- Return sends a message. Shift-Return starts a new line.
- Pop-up sheets have a size on the Mac. Past conversations had opened as
  an empty sliver.
- Voice permission is asked for when the microphone button is tapped,
  not when Eira opens.
- A failed save is shown on screen.

## Checks

107 logic tests, including an import of the real starter data.

---

# What changed, and why

This file lists every change made to the Windfall source since the files
were attached on 10 November 2026. Newest first.

How to read the history: the very first commit in this repository holds
the 39 files exactly as attached. Every change below is a later commit,
so GitHub and Xcode can show you each one line by line.

---

## Eira on the device (10 November 2026, branch `eira-on-device`)

**The aim:** Eira runs entirely on the device in your hand. No server,
no Ollama, no Tailscale. This is new work, kept on its own branch so it
cannot disturb the first build of `main`.

**Needs:** Xcode 27 and iOS 27, iPadOS 27 or macOS 27 for Eira herself.
Built with Xcode 26, the app still builds and Eira explains what she
needs. A device needs at least 12GB of memory to run her.

### Removed

- `EiraBackend.swift`, which held the code that talked to a model server.
- The server address setting, and every mention of Tailscale and Ollama.
- Sending photos to a server for identification (see "Not done" below).

### New files

| File | What it holds | Checked how |
|---|---|---|
| `EiraEngine.swift` | Message shapes, the `EiraEngine` interface, the 12GB rule, the model choice, where models are kept | Type-checked and tested |
| `EiraConversation.swift` | Runs one conversation: sending, streaming, stop, saving, memory management, corrections | Type-checked and tested |
| `EiraChatStore.swift` | Saved conversations and corrections (three new record types) | Type-checked and tested |
| `EiraWebLookup.swift` | Wikipedia lookup and reading a web page, straight from the device | Type-checked and tested |
| `EiraOnDeviceEngine.swift` | Runs a model through Apple's Foundation Models framework, with Core AI underneath | Checked against a stand-in only |
| `EiraMLXLoader.swift` | Optional: loads a model by name with MLX | Syntax only |

### Changed files

- `EiraTools.swift`: two new tools, the tool hub, the garden notes and
  rewritten standing instructions.
- `EiraChatView.swift`: rebuilt around the new engine. Adds a stop
  button, past conversations, "Correct this" and model settings.
- `EiraVision.swift`: server code removed. The screen can still save a
  photo as a sighting.
- `WindfallApp.swift`: three new record types in the schema, now 25.

### How Eira now works

1. **One interface.** The chat screen only talks to `EiraEngine`. Which
   model sits behind it is a setting: Apple's built-in model, a Core AI
   model or an MLX model. An "online service" entry exists as an empty
   slot and does nothing yet.
2. **Apple's framework runs the tools.** Each lookup is described to the
   framework, which lets the model call it and passes the answer back.
   This replaces the hand-written loop that had the multi-step bug.
3. **The 12GB rule.** Checked before any model is loaded. Below it, the
   chat says so and the rest of the app carries on.
4. **Standing instructions built fresh each time**, with today's date,
   the season, your garden notes and your recent corrections filled in.
5. **Memory management.** When a conversation outgrows what a small
   model can hold, older turns are shortened, old lookups are dropped
   and the model is restarted with that summary.
6. **Stop really stops.** The send button becomes a stop button while
   she replies, and what has arrived is kept.
7. **Conversations are saved**, which Handoff and iCloud sync will need.
8. **Corrections are kept.** Press and hold a reply, choose "Correct
   this", and she is told that fact at the start of every conversation
   from then on.
9. **Online lookup from the device.** Wikipedia and reading a single web
   page, both labelled as unverified. Species names still go to GBIF.

### Two faults the checks caught in my own new code

Worth recording, because it shows what the checks are for.

- The page-reading code used a pattern the system would have rejected,
  so every page came back empty. A test caught it.
- A helper was fenced to the main thread but used from a record type
  that is not. The compiler caught it.

### Not done on this branch

- **Photo identification.** Needs a vision model run by Core AI. The
  package has one (`CoreAIVisionLanguageModel`). It is the next piece.
- **Handoff to the Mac.**
- **Tools that add or change records.** Eira can only look things up.
  Her instructions tell her never to claim she has saved anything.
- **General web search.** Needs a search service. The socket for one
  (`WebSearchProvider`) is in `EiraWebLookup.swift`.
- **Saved chats in the backup file.**

### What to expect on the first build

`EiraOnDeviceEngine.swift` and the screens have never been through
Xcode. The framework calls were written from Apple's own published
source and tests, read on 10 November 2026, and then checked against a
small imitation of that framework. That proves the code is consistent
with what was read. It does not prove Apple's real framework matches.
Expect a handful of small corrections, most likely in that one file.

### Setting up in Xcode (after `main` builds)

1. Add the package `https://github.com/apple/coreai-models` and choose
   the product **CoreAILM**. This is what runs Core AI models.
2. Optional: add `https://github.com/ml-explore/mlx-swift-lm` for MLX
   models. Not needed to begin.
3. In Signing & Capabilities add **Increased Memory Limit** (needs the
   Apple Developer Programme) and, on the Mac, **Outgoing Connections
   (Client)** so lookups can reach GBIF and Wikipedia.
4. In Info, add `UIFileSharingEnabled` and
   `LSSupportsOpeningDocumentsInPlace`, both set to YES. These make
   Windfall's Models folder appear in the Files app on iPad.
5. Start with **Apple built-in** in Eira's settings. It needs no
   download and no package, so it is the quickest way to see her work.

---

## Corrected set (10 November 2026)

**The aim:** make the 39 files agree with each other so the project can
build. Nothing new was added and no design was changed.

**How it was checked:** see "How this was checked" at the end.

### 1. `WildlifeModels.swift`: sighting record renamed

- **Change:** the record type `Observation` is now `WildlifeObservation`.
- **Why:** Apple has its own framework called Observation. Two things
  with one name confuse the compiler. Eleven other files already used
  the new name, so this file was the odd one out.
- **What the code means:** a "type" is a kind of record. Renaming it
  changes what every other file calls it, which is why all files must
  agree.

### 2. `WildlifeModels.swift`: photos link added

- **Change:** `var photoIdentifiers: [String]` was replaced by a link to
  the `Photo` record:
  ```swift
  @Relationship(deleteRule: .cascade, inverse: \Photo.observation)
  var photos: [Photo]? = []
  ```
- **Why:** photos used to be remembered as a list of text labels. They
  are now proper `Photo` records, and `Journal.swift` expects a sighting
  to link to them.
- **What the code means:**
  - `@Relationship` tells SwiftData that two record types are linked.
  - `inverse: \Photo.observation` names the matching link on the other
    side, so each photo knows which sighting it belongs to.
  - `deleteRule: .cascade` means deleting a sighting also deletes its
    photos, so none are left orphaned.
  - `[Photo]? = []` is an optional list that starts empty. iCloud sync
    requires links to be optional.

### 3. `WildlifeModels.swift`: missing field added

- **Change:** added `var associatedPlantName: String?` to
  `WildlifeObservation`.
- **Why:** five files read or write this field (the sightings screen,
  backup, export, sheet sync and Eira's tools) but it was never defined.
  The project could not have built without it.
- **What the code means:** the sighting keeps the plant's name as plain
  text as well as the link to the plant record. If the plant is later
  removed from the library, the sighting still says what it was on.
  `Survey` already does the same with `targetPlantName`.

### 4. `PlantModels.swift`: photos links added to three records

- **Change:** `PhenologyEvent` and `PestDiseaseEvent` swapped
  `photoIdentifiers` for a `photos` link. `Harvest` gained a `photos`
  link it never had.
- **Why:** the same reason as change 2. `Journal.swift` defines the
  `Photo` side of all three links, and a link must exist on both sides.

### 5. `AuthenticationManager.swift`: moved to `@Observable`

- **Change:** `class AuthenticationManager: ObservableObject` with
  `@Published` properties became `@Observable final class
  AuthenticationManager` with plain properties.
- **Why:** these are two generations of the same idea. Both let a screen
  redraw when sign-in state changes. The settings screen already asked
  for the newer kind, and an app must use one kind consistently.
- **What the code means:** `@Observable` watches every property
  automatically, so `@Published` is no longer needed. `final` means no
  other class can build on this one, which the compiler likes.

### 6. `RootView.swift` and `SignInView.swift`: new wiring

- **Change:** `@EnvironmentObject var authManager` became
  `@Environment(AuthenticationManager.self) private var authManager`,
  and the previews use `.environment(...)`.
- **Why:** this is how a screen asks for an `@Observable` object. It
  goes with change 5.

### 7. `WindfallApp.swift`: full record list and shared objects

- **Change:**
  - The schema now lists all 22 record types. It listed 13.
  - `@StateObject` became `@State`, and `.environmentObject` became
    `.environment`.
  - A `LocationManager` is now created and handed to every screen.
- **Why:**
  - A record type missing from the schema is silently never saved.
    Nine were missing, including the diary, photos and reference data.
  - The wiring change goes with change 5.
  - Two screens ask for the location manager. Without it the app would
    crash when either opened.
- **What the code means:** the schema is the list of record types the
  app is allowed to store. `.environment(...)` passes a shared object
  down to every screen.

### 8. `EiraChatView.swift`: two small fixes

- **Change:** the manual lookup buttons now build their request with
  `JSONSerialization` instead of pasting text into a string by hand.
  An unused name was also removed to clear a compiler warning.
- **Why:** typing a quotation mark into the box used to break the
  lookup, because the hand-built text was no longer valid.
- **What the code means:** JSON is a standard way of writing structured
  data as text. Letting the system write it means special characters
  are handled properly.

### 9. `docs/windfall-manifest.md`: heading corrected

- The heading said 33 files. The tables list 39, and 39 is right.

---

## Known problems that were deliberately left alone

These live in the part of Eira that talks to a model server. That part
is being replaced by on-device models, so mending it would be wasted
work. The replacement is on the `eira-on-device` branch.

1. Multi-step lookups are likely to fail, because the model's request
   for a tool is not recorded in the conversation.
2. Changing the model settings has no effect until the chat screen is
   reopened.
3. With no server address set, sending a message does nothing.
4. Conversations are not saved.
5. Tailscale and Ollama are still mentioned in three files.

One more thing to know: if the Xcode project is ever switched to "Swift
6 language mode", `EiraTools.swift` will need a small change. It is fine
in the default mode.

---

## How this was checked

There is no Mac in the place this work was done, so the app itself was
not built. Three things were done instead, and you can repeat them with
`Tools/checks/run-checks.sh`.

1. **Syntax check, all 39 files.** Each file was read by the real Swift
   parser (Swift 6.2). All pass.
2. **Full type check, 17 files.** The files that hold the app's logic
   were compiled with screens removed and small stand-ins for Apple-only
   types. All pass with no errors and no warnings. Run on the files as
   originally attached, the same check fails, which shows it catches
   real faults.
3. **Cross-file checks, all 39 files.** Every record type is in the
   schema. Every link between records exists on both sides. No screen
   uses a property that a record lacks. iPhone-only and Mac-only code is
   fenced off for the right platform.

**What this does not prove:** that the app builds. The 22 screen files
were only syntax-checked and cross-checked, because SwiftUI does not
exist outside Apple's platforms. Expect some errors on the first build
in Xcode. They should be few, and each one will be explained as it is
fixed.
