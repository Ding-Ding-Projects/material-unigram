# Redesign handoff

Design references for Material Unigram, an unofficial Material Design 3 redesign of the Unigram
Windows client. Nothing here is implemented yet; these files describe what to build.

## Second pass (2026-11-17): "Ink and Tide", every screen, every required feature

The first pass looked too generic, so this pass replaces it with a stronger visual identity, draws
every screen and every required app and documentation-site feature, and puts the cross-cutting
features (search with regex builder, context menus with shortcuts, the per-element appearance
editor, tabs, language, version and update time) on every screen.

### Look

| Token | Value | Use |
| --- | --- | --- |
| Ink | `#0f1a24` | Navigation rail, top bar, dark panels |
| Ground | `#e7ecf2` | Window background behind floating sheets |
| Sheet | `#ffffff` | Floating panels, 24 px radius, 10 px gaps |
| Emerald | `#0e7c66` | Primary actions, outgoing messages |
| Lime | `#d4f36b` | Active navigation pill, logo, highlights |
| Coral | `#e2482a` | Unread badges, errors, destructive actions |
| Violet | `#5b4fe0` | Regex builder, tags, selection outlines |

- Type: Bricolage Grotesque for headings, Figtree for body text, JetBrains Mono for patterns and
  code, Noto Sans HK for Chinese.
- Squircle avatars with pastel fills, a dotted chat wallpaper, and an original speech-bubble logo
  (no paper plane, so the client never looks official).
- Shared tokens and parts live in `theme.css`. On the hosted canvas every board links it as an
  uploaded asset (`/_blob/eb8c360684d4e055bab1b5ffb359a01e`); in this folder the same file is
  `theme.css`.

### Shared parts on every screen

| File | What it carries |
| --- | --- |
| `TopBar.dc.html` | Account tabs and New tab, global search with the regex builder button, `Ctrl Shift F` palette shortcut, language toggle (EN, Cantonese, Both), Edit look switch, notifications, version and last update time |
| `ElementTools.dc.html` | The context menu every element opens (copy, open in a new tab, explain, edit appearance, lock, select several, search inside, export, favourites, all shortcuts, each with its shortcut) and the per-element appearance editor it opens |
| `SiteBar.dc.html` | The same duties for every documentation-site page: tabs, docs search with regex builder, palette, language, playfulness, personal wording upload, Edit look, version and update time |

Every app board imports `TopBar` (except the lock screen and first-run wizard, where workspace
chrome would leak content or confuse setup) and shows `ElementTools` open on a relevant element.
Every documentation-site board imports `SiteBar` and `ElementTools`. Mobile boards show the same
actions as a long-press sheet and the appearance editor as a bottom sheet.

### Boards by canvas page (one feature category per page)

| Page | Boards |
| --- | --- |
| Messenger screens | `Main` (workspace), `Contacts`, `Calls`, `ChatInfo` (members, bulk select, live chart, collapsible filters) |
| Onboarding, navigation and search | `Onboarding` (wizard), `NewTab` (catalogue), `Palette`, `Workbench` (full regex builder), `Guided` (presets, info icons, rich controls, empty state) |
| Settings groups | `Settings` (language, playfulness, emoji switch, schedules), `SetAppearance` (themes, element editor, colour picker, sizing), `SetMotion` (animation editor), `SetNotify` (notifications, sounds, narrator voices), `SetPrivacy` (app lock, School mode, element locks), `SetChats` (focus modes, rendered posts, media), `SetAccounts` (accounts, devices, extensions, Status Hub), `SetAdvanced` (about, storage, coverage, settings file, recording, reset) |
| Safety, locks and recovery | `Lock` (unlock ladder), `SuperConfirm` (two-key confirmation, element locks), `Support` (tickets, authenticator, QR pairing) |
| Records, history and notifications | `Export`, `History` (version history, changelog), `Notifications` (centre, toasts, inline recovery), `HelpArticle` (offline docs), `Tours` |
| Personal wording and fun | `Wording` (drop, celebration, refusal), `DimSum`, `Rename` (app name and logo) |
| Built-in tools | `Converter` (file converter, Base64, type generator), `Drawing`, `DiskManager`, `Ollama`, `Minecraft` (server manager, world generator), `Handoff` (VS Code, gist publishing), `Downloads` |
| Installer, updates and build app | `Installer`, `Update` (automatic update, icon sizes), `BuildGui` (build companion) |
| Mobile | `Phone`, `PhoneChat` (long-press actions), `PhoneSettings` (appearance bottom sheet) |
| Documentation site | `Site`, `SiteGuide`, `SiteDownload` (honest no-release state), `SiteFeatures`, `Embed` (link preview) |
| Repository records | `Readme` (tabbed README) |
| Release pipeline | `Release` |
| Shared chrome | `TopBar`, `ElementTools`, `SiteBar` |

### Features deliberately not drawn

- Job-application wording label: this is not a job app.
- Browser download hand-off: browser extensions only.
- Single-file editions, prompt banner, project profiles: the maintainer's memory repository only.
- Roblox catalogue and realism: games only.
- Encrypted public builder: private repositories only.
- Discord bridge, panic dispatch, Tidbyt frames: the Status Hub app only.
- Repository records with no screen (instruction mirror, vocabulary block, hash lock, feature docs,
  Postman, wiki sync, handoff, closeout prompt, Discussions, Project board, operational skill) are
  files, tracked in `ROADMAP.md`.

### Placeholders

Content that only the real build can supply is marked in square brackets, for example
`[SCREENSHOT FROM THE BUILT APP]`, `[PUBLIC PHOTO: HAR GOW]`, `[HASH]` and `[LAN ADDRESS]`.

## Process notes

- Stageshow skill, fresh install, commit `299140fafd08df55a9c234e610c3f64af3f45531` (matches the
  maintainer's cache apart from line endings). Applied: restraint in copy, real words on the
  subject only, hierarchy from proportion and surface, stroke icons, no invented logos, no emoji in
  controls. Not applicable to real app screens: cursor choreography, loop and poster rules, edge
  bleed for marketing crops.
- Gold example consulted: `slack` product study (chat layout interaction only).

## Still open

- No board has been rendered and reviewed as frames. The hosted canvas needs a signed-in browser,
  and the boards depend on the canvas runtime, so a local render was not possible.
- Message reaction chips on `PhoneChat` use emoji characters as reaction content; confirm the
  accessible names during implementation.
- Implementation has not started. See the root `ROADMAP.md`.
