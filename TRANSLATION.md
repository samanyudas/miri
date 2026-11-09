# Translating Miri

Miri shows its interface in the Mac's language when a translation exists, and in English otherwise ([#350](https://github.com/samanyudas/miri/issues/350)).
This file says how to draft and review a translation, and holds the glossary for each language.
Xcode 27 reads it as context when it drafts a translation.

## Where the text lives

Every interface text is in one string catalog, [Localization/Localizable.xcstrings](Localization/Localizable.xcstrings).
Each key is the English text as it stands in the Swift code, so a change to the English text makes a new key that has no translation yet.
`make strings-update` adds new keys and removes keys that the code no longer uses.
`make strings`, which `make native` and CI run, fails when a key lacks a translation in any of the languages below.
The list of languages lives in `LANGUAGES` in [scripts/check-strings.py](scripts/check-strings.py).

| Code | Language | Code | Language |
| --- | --- | --- | --- |
| `en` | English | `it` | Italian |
| `zh-Hans` | Simplified Chinese | `ru` | Russian |
| `zh-Hant` | Traditional Chinese | `ar` | Arabic |
| `es` | Spanish | `hi` | Hindi |
| `fr` | French | `nl` | Dutch |
| `de` | German | `tr` | Turkish |
| `ja` | Japanese | `pl` | Polish |
| `ko` | Korean | `id` | Indonesian |
| `pt-BR` | Brazilian Portuguese | `vi` | Vietnamese |
| `pt-PT` | European Portuguese | `th` | Thai |
| `uk` | Ukrainian | `sv` | Swedish |

## Add or change interface text

A change that adds or edits interface text also adds its translation in every language above.

1. Change the English text in the Swift code.
2. Run `make strings-update`.
3. Draft the translation of each new key, in every language, with the rules below.
   An AI model may draft it.
   Mark each draft `needs_review`, as Xcode's **Mark as Needs Review** does.
4. Have a second model, or a person who reads the language, check the draft against the glossary.
5. Run `make strings`.

A native speaker who reviews a translation marks it `translated`.
A draft that no native speaker has reviewed yet still ships, and does not fail `make strings`.

## Rules for every language

- Keep every placeholder, such as `%@`, `%lld`, or `%d`, with the same type and count as the English text.
  When the words change order, number them, such as `%1$@` and `%2$@`.
- Keep a space at the start or end of the text.
  Some texts, such as `Note: ` and `Keypad `, are joined to other text in the code.
- Keep these as they are: the name Miri, the shortcut symbols ⌃ ⌥ ⇧ ⌘, and code words such as `miri.strip_gesture`, `options.stack_limit`, `"off"`, `"left"`, `bindings`, `TOML`, `UTF-8`, `ctrl`, `alt`, `cmd`, `leftarrow`, and `fn`.
  The Copy Diagnostics report also keeps its Markdown marks, such as `## `, `### `, and `- `.
- Name a macOS setting, shortcut, or menu command exactly as macOS shows it in that language.
  The glossary below lists the names that Miri uses.
  A path such as `System Settings > Desktop & Dock > Windows` keeps its ` > ` marks between the translated names.
- Keep left, right, above, and below as the screen's real directions, also in Arabic.
  "Focus column left" moves focus to the left on the screen in every language.
- Keep the ellipsis `…` where the English text has it.
  It marks a command that opens a window or asks a question first.
- Use the quotation marks of the language, such as « » in French or „ “ in German.
- Use the register and words that macOS itself uses in that language, such as _du_ in German and _vous_ in French.
- Keep the text about as short as the English text where the language allows.
  Settings wraps long text, but a short label reads faster.
- Never use the em dash.

## Glossary

The macOS names in each table come from macOS 27's own translations in System Settings.
The Miri terms are the words that each translation uses for Miri's own ideas.
[GLOSSARY.md](GLOSSARY.md) defines the English terms.

| English | Meaning |
| --- | --- |
| Miri | The app's name. Never translate it. |
| engine | The program inside Miri that arranges windows. |
| strip | The row of columns on one display and Space, which scrolls left and right. |
| column | One place in a strip. It holds one window, or a stack of windows. |
| stack | Two or more windows on top of each other in one column. |
| display | A physical screen. Use the word that macOS uses for Displays in System Settings. |
| Space | A macOS desktop from Mission Control. Use the word that macOS uses for it. |
| focus | The window that takes the keyboard. "Focus column left" moves focus, not a window. |
| float | A window that floats sits above the strip, outside its columns. |
| strip swipe | The trackpad swipe that scrolls the strip. |
| shortcut | A keyboard shortcut. Use the word that macOS uses in Keyboard Shortcuts. |
| window management | What Miri does while it runs: arranging windows. |
| configuration file | The file `config.toml` that holds Miri's settings and shortcuts. |
