# Design decisions for #350, #351, and #352

Sam chose to build [#352](https://github.com/samanyudas/miri/issues/352), [#351](https://github.com/samanyudas/miri/issues/351), and [#350](https://github.com/samanyudas/miri/issues/350) on 8 November 2026, and every design choice goes to Sam before implementation.
This folder holds one decision sheet for each choice that Sam makes, with the options side by side and the recommendation marked.
Nothing here is implemented, and no option is accepted until Sam picks it.

## How the pictures were made

Each picture is an off-screen SwiftUI render that uses `Sources/Miri/Design.swift` from `3dc50c83`.
They are not screenshots of the running app, and they show no part of the desktop.
AppKit controls such as buttons, switches, and the search field are drawn copies, because SwiftUI's image renderer does not draw them.
Every non-English sample is a machine draft for length and layout only, and each sheet that shows one says so.
Pages are cropped narrower than the real 584 pt content column so that three options fit side by side, and each such sheet says by how much.

The PNG files are in a separate commit that waits for Sam's approval under the media rule in `scripts/check-pushed-media.py`.

## Sheets

| File in `sheets/` | Decision | Recommended |
| --- | --- | --- |
| `352-1-menu-position.png` | Where the two items go in the menu bar menu | A, under Copy Diagnostics |
| `352-2-settings-placement.png` | Where the two actions go in Settings | A, a Feedback section on Diagnostics |
| `352-3-item-wording.png` | What the items are called | A, Report a Bug… and Request a Feature… |
| `352-4-bug-flow.png` | Browser directly, or the Diagnostics preview first | B, the Diagnostics preview first |
| `351-1-illustration-style.png` | Strip sketch, glyph, or before and after pair | A, strip sketch |
| `351-2-size-and-placement.png` | Inline, popover, or preview panel on the Shortcuts page | C, preview panel above the list |
| `351-3-motion.png` | Still, animated on hover or focus, or looping, and what Reduce Motion shows | B, animated only in the preview |
| `351-4-voiceover-wording.png` | What VoiceOver reads for an illustration | A, what moves, where, and what stays |
| `350-1-clipping.png` | Wrap, shorter translations, or a wider window | A, wrap and never cut off |
| `350-2-arabic-layout.png` | Mirror the window for Arabic, or right-align the text only | A, mirror, with real directions kept |
| `350-3-action-names.png` | Translated, English, or both names in the Shortcuts list | A, translated, and search also matches English |
| `350-4-monitor-or-display.png` | "Monitor" or "display" in the English names, before translation | B, "display" everywhere |

The `mocks/` folder holds the first-round mocks from the same session, which the sheets replace.

## Decisions for Sam without a sheet

1. #352: whether the new-issue address names only the form, or also fills in the Miri and macOS versions.
   The recommendation is the form only, because filling in fields sends data to GitHub when the page loads.
2. #352: whether a simpler public bug form follows as a separate task before the public release.
   The current forms require fields such as Acceptance criteria that people outside the project cannot fill in.
3. #350: where translations come from and who reviews them.
   The recommendation is a machine draft from a glossary, a second model that checks it, and a native speaker review for the languages where Sam can find one.
4. #350: whether the translator glossary lives in a `TRANSLATION.md` file, which Xcode 27 reads, with Apple's own names for macOS settings.

## Settled without Sam

T3 Tots settled these technical choices for Sam on 8 November 2026, so they have no sheet:

- The order is #352, then the #350 groundwork with an English copy pass, then #351, then the translations.
- The illustration scenes live in code, with one test for a missing scene and one test against the keybinding reference.
- `MiriCore` returns translatable text, and Copy Diagnostics writes it in English.
- `scripts/check-strings.py` lists interface text, and its `--check` option joins `make lint` once a string catalog exists.

## Acceptance criteria that a recommendation would change

Sam has approved none of these changes.
Each one applies only if Sam picks the option named.

### #352

- Criterion 1 says that **Report a Bug…** opens the bug report form.
  With bug flow B, it opens the Diagnostics preview first, and its **Copy and Open Bug Report…** button opens the form.
- Criteria 1 and 2 name **Report a Bug…** and **Request a Feature…**.
  With wording B or C, both names change, and with wording B one item replaces the two.

### #351

- The issue's proposed behavior says that each shortcut row can show a small illustration.
  With placement C, the illustration shows in one preview panel above the list, for the row under the pointer or with keyboard focus, not inside each row.
- Criterion 4 says that VoiceOver reads a text description of each illustration.
  With placement C and wording A, VoiceOver reads the visible caption, and the drawing itself is hidden from VoiceOver.

### #350

- Criterion 1 covers every user-facing string in `Sources/Miri`.
  The settled choice for `MiriCore` widens it to `Sources/MiriCore` as well, except the Copy Diagnostics report.
- Criteria 2, 4, and 5 set the Mac's primary language.
  The proposal is to launch Miri with `-AppleLanguages` instead, because agents must not change the Mac's language, and to keep a change of the system language as a hand check for Sam only.
- Criterion 3 asks for a complete translation of all 22 languages.
  If Sam decides that some languages ship only after a native speaker review, those languages leave the first release, and the criterion lists fewer languages.
- Criterion 4 says that Settings and initial setup lay out right to left.
  With Arabic layout A, key caps, illustrations, and display directions keep the screen's real left and right, so the criterion names those exceptions.
- Criterion 6 checks that labels fit at the default window size.
  With clipping C, the default window size grows, and with clipping A an automatic check with longer test text joins the manual check.
- With action names B, criterion 2 needs an exception, because action names stay in English inside a translated Settings window.

### Outside the issues

- With monitor or display B, 8 action names and `decisions/keybinding reference.md` change before translation, and `GLOSSARY.md` may need its term Physical monitor reworded.
