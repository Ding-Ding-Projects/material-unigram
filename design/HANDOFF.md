# Redesign handoff (2026-11-17)

This folder holds the first design pass for Material Unigram: a Material Design 3 redesign of the
Unigram Windows client. These are design references. None of this is implemented yet, so nothing
here should be read as shipped behavior.

## Files

| File | Board | Size | What it shows |
| --- | --- | --- | --- |
| `canvas.json` | Canvas index | | Pages, frames and notes, one feature category per page |
| `Main.dc.html` | Chat workspace | 1440 x 900, fluid | Title bar with version and update date, workspace tabs per account, navigation rail, chat search with an adjacent regex button, folder chips, chat list, conversation and composer. Selecting a chat or a tab works. |
| `Onboarding.dc.html` | First-run setup wizard | 1440 x 900 | Six steps with saved progress, Back, Next and Skip; language mode cards; separate English and Cantonese playfulness sliders; QR sign-in step. |
| `Settings.dc.html` | Settings | 1440 x 1080, fluid | Task-oriented groups, a settings search with an adjacent regex builder (pattern, flags, Match/Replace/Split/Debug modes, token explanation, validation, bounded execution), language modes, both playfulness sliders, the dialog emoji switch, personal wording upload and drop zone, motion profiles with an editor link, action sounds and narration, app lock and School mode, reset and export. |
| `NewTab.dc.html` | New tab catalogue | 1440 x 900 | Dialog listing every page and tool with its open or closed state, its own search with a regex button, group filters and Open every tab. |
| `Phone.dc.html` | Mobile chat list | 390 x 844 | The same features at phone width: More overflow, horizontally scrolling chips, a bottom navigation bar, 48 px touch targets. |
| `Site.dc.html` | Documentation site home | 1440 x 1700, fluid | Task-led home with docs search and regex button, language toggle, honest in-development status, task cards and an interactive walkthrough labelled as a demonstration. |

## Look

- Material Design 3 tonal palette built around a teal-blue primary (`#0b6780`), its own color
  rather than Telegram's brand color, so the client never reads as official.
- Roboto Flex for Latin text, Noto Sans HK for Chinese, Roboto Mono for regex patterns.
- Corner radii follow Material Design 3: 8 px chips, 16 px list items, 20 to 28 px cards and dialogs.

## Design process notes

- The pass followed the Stageshow skill at commit `299140fafd08df55a9c234e610c3f64af3f45531`
  (fresh install, identical to the maintainer's cached copy apart from line endings). Rules
  applied: restraint in copy, real words only where the screen is about something, hierarchy
  from proportion and surface color instead of borders, inline stroke icons, no invented logos.
- Stageshow rules that do not apply to real app screens: cursor choreography, the loop and
  poster rules, edge bleed and cropping for marketing frames, and the `compact` phone-column
  variant (the mobile board covers the narrow layout instead).
- Closest gold example used for reference: `slack` (product study for chat layout), borrowing
  only the interaction pattern, not another product's identity.

## Still open

- Frames were not filmed in this pass. A rendered review of each board, and fixes from that
  review, are still to do.
- Boards for the animation editor, message history export, notifications, calls and the
  installer are not drawn yet.
- Implementation in the WinUI codebase has not started. See the root `ROADMAP.md`.
