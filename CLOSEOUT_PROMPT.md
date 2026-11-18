# Closeout prompt (2026-11-17, second session)

```text
Repository: Ding-Ding-Projects/material-unigram (public fork of TelegramMessenger/Unigram, GPL-3.0)
Default branch: develop. Every change below is pushed to develop.

Goal: an unofficial Material Design 3 redesign of Unigram for Windows with every required
feature in ROADMAP.md, plus self-hosted servers people can run themselves.

Done and verified:
- build.bat builds the app end to end: Telegram/bin/winui-unpackaged/x64/Release/publish/Telegram.exe
  starts and reaches Running. Fixes needed on the way: native projects pinned to Windows SDK
  10.0.26100 (Directory.Build.props), upstream's banned WinRT file types reported as warnings
  (WinUIBannedApisAsErrors=false, set by build.bat), the wallet engine copied only when present,
  and two TDLib patches in Libraries/tdjson/patches applied by the tdjson build:
  private-server.patch (custom server address and RSA key from the environment) and
  request-ids.patch (the td_send/td_receive request-id interface the app's bindings call).
- Hosted servers: MTProxy (server/) and the Teamgram full server (server/full/) in Docker via
  host.bat, MTProxy in WSL via go-host.bat. Both answered on the LAN; the full server returned
  this install's own key fingerprint to a real MTProto handshake.
- Appliance image (appliance/): builds, boots, runs first boot and starts the proxy stack (it
  needed docker-cli). The dashboard answers inside the guest.
- Host assistant (hostassistant/): the portable exe builds; steps 1 to 3 driven in the built exe.
- Design canvas and design/ include the per-chat look, the hosted-server boards and the
  private-server sign-in board.

Written and built, not yet driven in the running app:
- Per-chat look (Chat look in the chat menu); bubble corners and text size are stored only.
- Private-server sign-in: a Private server button on the sign-in page and in the Add account
  menu. Private-server sessions use a placeholder API id when the build has none.

Open:
- Capturing and driving the app. A WinUI window is not composed on an off-screen desktop, so a
  throwaway Windows 11 test VM in VirtualBox was being set up for it (install at 94% when this
  was written). Next: copy the publish folder in, start the full server on the host, and in the
  VM use the Private server button with the host's address as seen through the VM's NAT, port
  10443, and the key from the dashboard.
- Appliance health reports 503: MTProxy restarts every minute under software emulation; try
  real hardware or a KVM host. The full-server appliance image is not built yet.
- Installer (build-installer.bat), documentation site, About homepage, a release, dashboard QR
  codes, and every ROADMAP Phase 2 feature in the app itself.
- Wallet features need the wallet engine library, which is built outside this repository.

Sign-in to Telegram needs your own API ID and hash in Telegram/Constants.Secret.cs, which is
gitignored. Never commit those values.
```
