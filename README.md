> **Material Unigram** is an unofficial Material Design 3 redesign of Unigram for Windows, in
> development. It is not affiliated with or endorsed by Telegram. See [ROADMAP.md](ROADMAP.md) for
> what is done, [HANDOFF.md](HANDOFF.md) for the latest state, and [design/](design/) for the
> redesign references. The original Unigram README follows.

## Host your own server

Material Unigram ships two servers you can run yourself, each as a Docker container
(`host.bat`, add `--full` for the full server), as plain processes in WSL (`go-host.bat`, proxy
only), or as a bootable appliance image (`appliance/build-appliance.bat`):

- **Telegram proxy**: Telegram's open-source MTProxy. Your real Telegram account connects
  through it.
- **Full private server**: the open-source Teamgram server. Accounts on it can talk to each
  other but not to people on Telegram. In Material Unigram, right-click **Add account** in
  Settings and choose **Set up a private server…**, then paste the address and public key from
  the server dashboard.

The host assistant (`hostassistant/`) does all of this in five steps. These captures are from
its built portable exe:

| Choose | Check this computer | Settings (empty password refused) |
| --- | --- | --- |
| ![Choosing the proxy and Docker](Screenshots/host-assistant/1-choose.png) | ![Docker found running](Screenshots/host-assistant/2-check.png) | ![Settings refusing an empty password](Screenshots/host-assistant/3-settings-refused.png) |

<p align="center">
<a href="https://apps.microsoft.com/detail/9n97zckpd60q">
<img src="/Telegram/Assets/Logos/StoreLogo.scale-200.png" width="96" height="96" alt="Unigram logo">
</a>
</p>

<h1 align="center">Unigram</h1>

<p align="center">
  <b>Telegram, built for Windows.</b>
  <br>
  Native, fast, and designed to feel right at home on Windows 10 and 11.
</p>

<p align="center">
  <a href="https://apps.microsoft.com/detail/9n97zckpd60q">
    <img src="https://get.microsoft.com/images/en-us%20dark.svg" width="200" alt="Get it from Microsoft">
  </a>
</p>

<p align="center">
  <a href="https://github.com/TelegramMessenger/Unigram/releases"><img src="https://img.shields.io/github/v/release/TelegramMessenger/Unigram?label=release&color=2AABEE" alt="Latest release"></a>
  <a href="https://t.me/unigram"><img src="https://img.shields.io/badge/news-t.me%2Funigram-2AABEE?logo=telegram" alt="Unigram News"></a>
  <a href="https://translations.telegram.org/en/Unigram"><img src="https://img.shields.io/badge/languages-30%2B-2AABEE" alt="30+ languages"></a>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="/Screenshots/Screen.dark.png">
    <img src="/Screenshots/Screen.light.png" alt="Unigram showing the chat list and a group chat">
  </picture>
</p>

## Why Unigram

Unigram brings Telegram to Windows with a native experience, without compromising on the features you already know and use.

- 🪟 **Made for Windows.** A familiar Fluent design, light and dark themes that follow your system, native notifications, and seamless sharing with other apps.
- ⚡ **Native performance.** Built specifically for Windows, not wrapped in a web browser. Fast, responsive, and right at home on your desktop.
- 💬 **Everything you expect from Telegram.** Chats, channels, stories, folders, secret chats, polls, stickers, and much more.
- 📞 **Stay connected.** Make voice and video calls, join group video chats, and watch live streams.
- 👥 **All your accounts in one place.** Add multiple Telegram accounts and switch between them whenever you need.
- ⌨️ **Work faster with your keyboard.** A wide range of keyboard shortcuts makes navigating Unigram a breeze. [See the full list](Documentation/Shortcuts.md).
- 🌍 **Your language, your way.** Available in over 30 languages, with support for all language packs on the Telegram translations platform.
- 🔒 **Your privacy matters.** Unigram doesn't collect any user data. Telegram's [Privacy Policy](https://telegram.org/privacy) applies.

## Stay in the loop

Follow Unigram's development and join the community:

- [Unigram News](https://t.me/unigram) — Release announcements, updates, and changelogs. You can also find every release on [GitHub](https://github.com/TelegramMessenger/Unigram/releases).
- [Unigram Insiders](https://t.me/unigraminsiders) — Join the conversation with the developers and other Unigram users.

## Help with translations

Unigram is available in over 30 languages, and there's always room for improvement. Help refine an existing translation or bring Unigram to a new language through the [Telegram translations platform](https://translations.telegram.org/en/Unigram).

## Contributing

Found a bug, have an idea, or want to suggest an improvement? Head over to the [Bugs and Suggestions Platform](https://bugs.telegram.org/?tag_ids=47&type=issues&sort=time).

If you'd like to contribute code, please take a moment to read the [contributing guidelines](/CONTRIBUTING.md) and [build instructions](Documentation/Build-instructions.md) before opening a pull request.

## Windows 10 N

Windows 10 N editions require the Media Feature Pack to run Unigram.

To install it, open `Settings > Apps and Features > Add a feature`, find and select `Media Feature Pack`, and install it. Restart Windows once the installation is complete.
