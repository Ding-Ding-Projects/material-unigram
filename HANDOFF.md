# Handoff

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
