# Design decisions for #350, #351, and #352

Sam chose to build [#352](https://github.com/samanyudas/miri/issues/352), [#351](https://github.com/samanyudas/miri/issues/351), and [#350](https://github.com/samanyudas/miri/issues/350) on 8 November 2026, and every design choice goes to Sam before implementation.
This folder holds one decision sheet for each choice that Sam makes, with the options side by side and the recommendation marked.
Sam picked an option for every sheet on 9 November 2026, and the **Sam picked** column records it.

## How the pictures were made

Each picture is an off-screen SwiftUI render that uses `Sources/Miri/Design.swift` from `3dc50c83`.
They are not screenshots of the running app, and they show no part of the desktop.
AppKit controls such as buttons, switches, and the search field are drawn copies, because SwiftUI's image renderer does not draw them.
Every non-English sample is a machine draft for length and layout only, and each sheet that shows one says so.
Pages are cropped narrower than the real 584 pt content column so that three options fit side by side, and each such sheet says by how much.

Sam approved pushing these PNG files on 9 November 2026, under the media rule in `scripts/check-pushed-media.py`.
A changed or new picture needs a new approval.

## Sheets

| File in `sheets/` | Decision | Recommended | Sam picked |
| --- | --- | --- | --- |
| `352-1-menu-position.png` | Where the two items go in the menu bar menu | A, under Copy Diagnostics | C, a Help submenu, then changed to under Copy Diagnostics (see below) |
| `352-2-settings-placement.png` | Where the two actions go in Settings | A, a Feedback section on Diagnostics | A |
| `352-3-item-wording.png` | What the items are called | A, Report a Bug… and Request a Feature… | B, one Send Feedback… item |
| `352-4-bug-flow.png` | Browser directly, or the Diagnostics preview first | B, the Diagnostics preview first | B, adapted to one item (see below) |
| `351-1-illustration-style.png` | Strip sketch, glyph, or before and after pair | A, strip sketch | C, before and after pair |
| `351-2-size-and-placement.png` | Inline, popover, or preview panel on the Shortcuts page | C, preview panel above the list | C |
| `351-3-motion.png` | Still, animated on hover or focus, or looping, and what Reduce Motion shows | B, animated only in the preview | B |
| `351-4-voiceover-wording.png` | What VoiceOver reads for an illustration | A, what moves, where, and what stays | A |
| `350-1-clipping.png` | Wrap, shorter translations, or a wider window | A, wrap and never cut off | A |
| `350-2-arabic-layout.png` | Mirror the window for Arabic, or right-align the text only | A, mirror, with real directions kept | A |
| `350-3-action-names.png` | Translated, English, or both names in the Shortcuts list | A, translated, and search also matches English | A |
| `350-4-monitor-or-display.png` | "Monitor" or "display" in the English names, before translation | B, "display" everywhere | B |
| `350-5-diagnostics-language.png` | Whether the Copy Diagnostics report stays in English or follows the Mac's language | A, English | B, the Mac's language |

The `mocks/` folder holds the first-round mocks from the same session, which the sheets replace.

## How the #352 picks fit together

Wording B leaves one **Send Feedback…** item, so no **Report a Bug…** item is left for bug flow B to route through the Diagnostics preview.
On 9 November 2026 Sam chose this combination:

- **Send Feedback…** opens GitHub's list of issue forms, `issues/new/choose`, where the person picks a form.
- It sits in the menu bar menu under **Copy Diagnostics…**, and in a **Feedback** section on the Settings Diagnostics page.
  Sam first picked a Help submenu, then on 10 November 2026 asked to drop it, because it held only this one item.
- The Diagnostics preview gains a **Copy and Open Bug Report…** button, which copies the report and opens the bug report form.

## Decisions without a sheet

Sam took the recommendation for each of these on 9 November 2026.

1. #352: the new-issue address names only the form and fills in no fields, because filling in fields sends data to GitHub when the page loads.
2. #352: a simpler public bug form follows as a separate task before the public release.
   The current forms require fields such as Acceptance criteria that people outside the project cannot fill in, and GitHub's list of forms also shows the maintainer forms Task and Decision.
3. #350: an AI drafts the translations from the glossary, a second model checks them, and a native speaker reviews each language where Sam can find one.
   A missing reviewer does not hold a language back.
4. #350: the translator glossary lives in a `TRANSLATION.md` file, which Xcode 27 reads, with Apple's own names for macOS settings.

## Settled without Sam

T3 Tots settled these technical choices for Sam on 8 November 2026, so they have no sheet.
On the same day, T3 Tots moved the language of the Copy Diagnostics report back to Sam as a product choice, which `350-5-diagnostics-language.png` shows.

- The order is #352, then the #350 groundwork with an English copy pass, then #351, then the translations.
- The illustration scenes live in code, with one test for a missing scene and one test against the keybinding reference.
- `scripts/check-strings.py` lists interface text, and its `--check` option joins `make lint` once a string catalog exists.

## Acceptance criteria that Sam's picks change

Sam's picks on 9 November 2026 approve these changes, and each issue body carries them.

### #352

- **Send Feedback…** replaces **Report a Bug…** and **Request a Feature…**, in the menu bar menu and in a Feedback section on the Settings Diagnostics page.
  It opens `github.com/samanyudas/miri/issues/new/choose`.
- The Diagnostics preview has a **Copy and Open Bug Report…** button, which copies the report and opens the bug report form.
- The Swift test checks the bug report form and the address of the list of forms.

### #351

- The illustration shows in one preview panel above the list, for the row under the pointer or with keyboard focus, not inside each row.
- Each illustration is a before and after pair of strip sketches.
- The preview plays the move once on hover or focus, and Reduce Motion shows the still pair.
- VoiceOver reads the visible caption, which says what moves, where, and what stays, and the drawing itself is hidden from VoiceOver.

### #350

- Criterion 1 covers `Sources/MiriCore` as well as `Sources/Miri`, because setup checks, action names, and configuration errors live there.
- Criterion 1 names `make strings`, which `make native` and CI run, instead of `make lint` or a Swift test.
  Sam chose this on 10 November 2026, because the check needs the Swift compiler and `make lint` also runs on Linux.
- Criterion 7 changes: the Copy Diagnostics report follows the Mac's language, and its Swift test checks that the report uses the translation.
- Criteria 2, 4, and 5 launch Miri with `-AppleLanguages`, because agents must not change the Mac's language.
  Sam keeps a change of the system language as a hand check.
- Criterion 3 keeps all 22 languages, because a missing native reviewer does not hold a language back.
- Criterion 4 names the exceptions to the mirrored layout: key caps, illustrations, and display directions keep the screen's real left and right.
- Criterion 6 gains an automatic check with longer test text, next to the manual check, because labels wrap instead of being cut off.

### Outside the issues

- 8 action names say "display" instead of "monitor" before translation, `decisions/keybinding reference.md` changes to match, and `GLOSSARY.md` may need its term Physical monitor reworded.
