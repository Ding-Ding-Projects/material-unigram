# Material Unigram roadmap

Material Unigram is an unofficial Material Design 3 redesign of
[Unigram](https://github.com/TelegramMessenger/Unigram), the open-source Telegram client for
Windows. It is not affiliated with or endorsed by Telegram.

A tick means implemented, verified, and where it claims something visible, captured from the
real built app. Anything written but unverified stays unticked with its state beside it.

## Phase 0: repository

- [x] Public fork created from `TelegramMessenger/Unigram` with an `upstream` remote
- [x] Agent instructions, roadmap and handoff records added
- [ ] Root `build.bat` that installs missing dependencies automatically (a full build now publishes `Telegram.exe`, which starts and reaches Running; not yet run on a fresh machine)
- [ ] Root `build-installer.bat` (not started)
- [ ] API credentials supplied through a local, uncommitted configuration file (never in source)

## Phase 1: design

- [x] First design pass: chat workspace, setup wizard, settings, New tab catalogue, mobile chat list, documentation site home (`design/`)
- [x] Second design pass, "Ink and Tide": 48 boards across 12 category pages covering every app, mobile and documentation-site screen and every applicable required feature (`design/HANDOFF.md`)
- [x] Shared top bar, context menu with shortcuts and per-element appearance editor placed on every screen
- [ ] Rendered review of every board with fixes applied (not done: the canvas needs a signed-in browser)

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
- [ ] Material Design 3 theming, appearance customization and the animation editor (started: the Ink and Tide colours, corner radii and accent defaults are in `Telegram/Themes/InkTide.xaml`; not yet seen in a running build)
- [ ] Per-chat appearance saved for each contact (written: `ChatLookSettings` and `ChatLookPopup` for outgoing colour, accent and wallpaper; bubble corners and text size are stored but not applied; not yet seen in a running build)
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

## Phase 4: hosted servers

Two servers, each in three forms: a Docker image with Compose and `host.bat`, plain processes in
WSL, and a minimal Linux appliance image. Run from the repository or from the host assistant.

- [x] MTProxy Docker image and dashboard (`server/`): built, started with `host.bat --detached`, signed in, LAN address checked
- [x] MTProxy in WSL (`go-host.bat`): built in a dedicated distribution, started, LAN address checked
- [x] Teamgram full server in Docker (`server/full/`): all seven services up, and a real MTProto handshake offered this install's own key fingerprint
- [ ] Appliance image (`appliance/`): the proxy image builds, boots and starts the stack, and the dashboard answers inside the guest; its health check reports 503 because MTProxy restarts every minute under software emulation (not yet tried on real hardware); the full-server image has not been built
- [ ] Host assistant (`hostassistant/`): the portable exe builds; steps 1 to 3 driven in the built exe (real Docker check, empty password refused); Start not yet run from it
- [ ] Sign in to the full server from Material Unigram (written and built: TDLib patch `Libraries/tdjson/patches/private-server.patch`, `PrivateServerSettings`, `PrivateServerPopup` and the Add account menu; not yet driven in the running app, because the app's window cannot be captured off-screen)
- [ ] Share links and the private server's values as QR codes on the dashboard
