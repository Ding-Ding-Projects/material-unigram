# Handoff

## 2026-11-17: hosted servers and signing in to your own server

- `server/` hosts Telegram's open-source MTProxy with a signed-in dashboard; `server/full/` hosts
  the Teamgram full server (MySQL, Redis, etcd, Kafka, SeaweedFS for S3, the dashboard). Each
  install generates its own RSA key, because the key Teamgram ships is public.
- `host.bat` (Docker, `--full` for the full server), `go-host.bat` (WSL, proxy only) and
  `appliance/build-appliance.bat` (Debian appliance image) are the three forms. `hostassistant/`
  is an Electron portable exe that runs the same scripts in five steps.
- Material Unigram can add an account on the full server. TDLib is patched at build time
  (`Libraries/tdjson/patches/private-server.patch`); the submodule stays on its pinned commit.
  The patch reads `MATERIAL_UNIGRAM_SERVER` and `MATERIAL_UNIGRAM_SERVER_KEY` through
  `GetEnvironmentVariableA`, which the app sets from Settings before the first client starts.
  Accounts on the server are test-path sessions, so while a private server is set up the hidden
  Telegram test-server entry is not offered.
- Per-chat appearance: right-click a chat for "Chat look", saved for that chat.

### Verification

- MTProxy in Docker and WSL: started and answered on the LAN address. The full server: all
  services up and a real `req_pq_multi` returned this install's key fingerprint.
- Appliance: the proxy image builds; its boot test had not answered when this entry was written.
- Not yet verified: the native app build, the private-server sign-in in a running app, the
  host assistant driven end to end, and the full-server appliance image.

## 2026-11-17: second design pass, every screen and every feature

- Replaced the first, generic-looking design with the "Ink and Tide" look: ink navigation, floating
  white sheets, emerald, lime, coral and violet accents, Bricolage Grotesque and Figtree type.
- Drew 48 boards on 12 category pages, plus three shared parts (`TopBar`, `ElementTools`,
  `SiteBar`) that put search with the regex builder, context menus with shortcuts, the per-element
  appearance editor, tabs, language and version on every screen. See `design/HANDOFF.md`.
- Features with nothing to draw for this app are listed with reasons in `design/HANDOFF.md`.
- Verification: every design file passes the public-language scan. Boards were not rendered or
  reviewed as frames. No app code has changed.

## 2026-11-17: repository and first design pass

- Created `Ding-Ding-Projects/material-unigram` as a public fork of `TelegramMessenger/Unigram`
  (GPL-3.0). The name avoids "Telegram" so the client never presents itself as official.
- Added the first redesign pass to `design/`. See `design/HANDOFF.md` for each board and what
  remains open.
- Added `AGENTS.md`, `ROADMAP.md` and this file.

### Verification

- Design boards were published to the design canvas. They were not rendered or reviewed
  as frames in this pass.
- Nothing was built. No app code has changed from upstream.

### Next steps

1. Render and review every design board, then fix what the review finds.
2. Add root build scripts that install the Visual Studio workload, Windows SDK and vcpkg
   dependencies, and initialize the submodules.
3. Start Phase 2 of `ROADMAP.md` with language modes and the setup wizard.
4. Unigram needs a Telegram API ID and hash. Keep them in an uncommitted local file.
