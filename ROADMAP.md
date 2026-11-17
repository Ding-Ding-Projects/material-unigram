# Material Unigram roadmap

Material Unigram is an unofficial Material Design 3 redesign of
[Unigram](https://github.com/TelegramMessenger/Unigram), the open-source Telegram client for
Windows. It is not affiliated with or endorsed by Telegram.

A tick means implemented, verified, and where it claims something visible, captured from the
real built app. Anything written but unverified stays unticked with its state beside it.

## Phase 0: repository

- [x] Public fork created from `TelegramMessenger/Unigram` with an `upstream` remote
- [x] Agent instructions, roadmap and handoff records added
- [ ] Root `build.bat` and `build-installer.bat` that install missing dependencies automatically
- [ ] API credentials supplied through a local, uncommitted configuration file (never in source)

## Phase 1: design

- [x] First design pass: chat workspace, setup wizard, settings, New tab catalogue, mobile chat list, documentation site home (`design/`)
- [ ] Rendered review of every board with fixes applied
- [ ] Boards for the animation editor, message history export, notifications, calls and installer

## Phase 2: required app features

Each item needs implementation, documentation in English and Cantonese, localized copy in all
three language modes, persistence, tests and screenshots from the built app.

- [ ] Language modes: English, Cantonese, bilingual
- [ ] English and Cantonese playfulness sliders and the dialog emoji switch
- [ ] Personal wording file: Settings upload plus drop anywhere on the window, with outcome sounds
- [ ] First-run setup wizard with save and resume
- [ ] Search everywhere with an adjacent full regex builder
- [ ] Workspace tabs per account and the New tab catalogue; every page open by default
- [ ] Command palette
- [ ] Material Design 3 theming, appearance customization and the animation editor
- [ ] Action sound effects with a Settings switch
- [ ] Spoken narrator with voice pickers
- [ ] School mode and app lock
- [ ] Non-blocking notifications
- [ ] Exports and local history
- [ ] Mobile-width parity at 360 px with no removed features
- [ ] Version and last-updated date on the front screen

## Phase 3: delivery

- [ ] Unsigned Squirrel.Windows installer
- [ ] Documentation site on GitHub Pages with complete articles and wiki content
- [ ] Repository About homepage pointing at the live documentation site
- [ ] Normal GitHub release with installer assets
