# Closeout prompt (2026-11-17)

```text
Repository: Ding-Ding-Projects/material-unigram (public fork of TelegramMessenger/Unigram, GPL-3.0)
Default branch: develop. Records commit: 177c6214d2f98f1222d2d297a588d39d6436a2a4 (on the remote).

Goal: an unofficial Material Design 3 redesign of Unigram for Windows that carries every
required feature listed in ROADMAP.md.

Done:
- Fork created, upstream remote set, repository description set.
- Second design pass in design/: 48 boards on 12 category pages plus shared TopBar,
  ElementTools and SiteBar parts covering every screen and every applicable required feature.
  Design only, not implemented. design/HANDOFF.md lists boards, tokens and what was not drawn.
- AGENTS.md, ROADMAP.md, HANDOFF.md, design/HANDOFF.md, README fork notice, .gitignore
  exceptions for these Markdown records (upstream ignores *.md).

Not done:
- Rendered review of the design boards (the canvas needs a signed-in browser).
- Root build.bat and build-installer.bat with automatic dependency setup.
- Any app code change; every ROADMAP Phase 2 item is unticked.
- Installer, GitHub Pages documentation site, About homepage, release.

Sign-in: the app signs in with a real account by QR code or phone number once built. It needs
an API ID and hash from my.telegram.org in Telegram/Constants.Secret.cs, which is gitignored.
Never commit those values.

Next steps: build entrypoints, a first local build, then language modes and the setup wizard.
```
