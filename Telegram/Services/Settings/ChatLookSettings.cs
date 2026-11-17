//
// Copyright (c) Fela Ameghino 2015-2026
// Copyright (c) Material Unigram contributors 2026
//
// Distributed under the GNU General Public License v3.0. (See accompanying
// file LICENSE or copy at https://www.gnu.org/licenses/gpl-3.0.txt)
//

using System;
using System.Collections.Generic;
using System.Globalization;
using Telegram.Td.Api;

namespace Telegram.Services.Settings
{
    /// <summary>
    /// A look the user chose for one chat only, stored on this device and keyed by chat id, so each
    /// contact or group keeps its own colours while every other chat follows the app theme.
    /// </summary>
    /// <remarks>
    /// Colours are stored as 0xRRGGBB integers, matching the TDLib theme settings they feed.
    /// A null value means "inherit from the app theme".
    /// </remarks>
    public sealed class ChatLook
    {
        public int? OutgoingColor { get; set; }

        public int? AccentColor { get; set; }

        public int? WallpaperColor { get; set; }

        /// <summary>Corner radius of message bubbles in this chat, in pixels.</summary>
        public double? BubbleRadius { get; set; }

        /// <summary>Message text size in this chat, in pixels.</summary>
        public double? TextSize { get; set; }

        public bool IsEmpty => OutgoingColor == null && AccentColor == null && WallpaperColor == null && BubbleRadius == null && TextSize == null;

        public ChatLook Clone() => (ChatLook)MemberwiseClone();
    }

    public sealed class ChatLookChangedEventArgs : EventArgs
    {
        public ChatLookChangedEventArgs(long chatId) => ChatId = chatId;

        public long ChatId { get; }
    }

    public partial class ChatLookSettings : SettingsServiceBase
    {
        private const string IndexKey = "ChatLookIndex";

        private readonly Dictionary<long, ChatLook> _cache = new();

        public ChatLookSettings(ISettingsStore container)
            : base(container)
        {
        }

        /// <summary>Raised after a chat's look is saved, replaced or cleared.</summary>
        public event EventHandler<ChatLookChangedEventArgs> Changed;

        /// <summary>The chats that currently have their own look.</summary>
        public IReadOnlyList<long> CustomizedChats
        {
            get
            {
                var result = new List<long>();
                foreach (var part in GetValueOrDefault(IndexKey, string.Empty).Split(',', StringSplitOptions.RemoveEmptyEntries))
                {
                    if (long.TryParse(part, NumberStyles.Integer, CultureInfo.InvariantCulture, out long chatId))
                    {
                        result.Add(chatId);
                    }
                }

                return result;
            }
        }

        public bool TryGet(long chatId, out ChatLook look)
        {
            if (_cache.TryGetValue(chatId, out look))
            {
                return look != null;
            }

            look = new ChatLook
            {
                OutgoingColor = ReadInt(chatId, nameof(ChatLook.OutgoingColor)),
                AccentColor = ReadInt(chatId, nameof(ChatLook.AccentColor)),
                WallpaperColor = ReadInt(chatId, nameof(ChatLook.WallpaperColor)),
                BubbleRadius = ReadDouble(chatId, nameof(ChatLook.BubbleRadius)),
                TextSize = ReadDouble(chatId, nameof(ChatLook.TextSize))
            };

            if (look.IsEmpty)
            {
                look = null;
            }

            _cache[chatId] = look;
            return look != null;
        }

        public void Set(long chatId, ChatLook look)
        {
            if (look == null || look.IsEmpty)
            {
                Clear(chatId);
                return;
            }

            Write(chatId, nameof(ChatLook.OutgoingColor), look.OutgoingColor);
            Write(chatId, nameof(ChatLook.AccentColor), look.AccentColor);
            Write(chatId, nameof(ChatLook.WallpaperColor), look.WallpaperColor);
            Write(chatId, nameof(ChatLook.BubbleRadius), look.BubbleRadius);
            Write(chatId, nameof(ChatLook.TextSize), look.TextSize);

            _cache[chatId] = look.Clone();
            UpdateIndex(chatId, true);
            Changed?.Invoke(this, new ChatLookChangedEventArgs(chatId));
        }

        public void Clear(long chatId)
        {
            foreach (var name in new[] { nameof(ChatLook.OutgoingColor), nameof(ChatLook.AccentColor), nameof(ChatLook.WallpaperColor), nameof(ChatLook.BubbleRadius), nameof(ChatLook.TextSize) })
            {
                _container.Remove(Key(chatId, name));
            }

            _cache[chatId] = null;
            UpdateIndex(chatId, false);
            Changed?.Invoke(this, new ChatLookChangedEventArgs(chatId));
        }

        /// <summary>Copies one chat's look onto another chat, replacing whatever that chat had.</summary>
        public void CopyTo(long sourceChatId, long targetChatId)
        {
            if (TryGet(sourceChatId, out ChatLook look))
            {
                Set(targetChatId, look.Clone());
            }
        }

        /// <summary>
        /// Builds TDLib theme settings for this chat's look on top of the app's own settings for the
        /// same base, or returns null when the chat has no look of its own.
        /// </summary>
        public ThemeSettings ToThemeSettings(long chatId, ThemeSettings baseSettings)
        {
            if (!TryGet(chatId, out ChatLook look) || (look.OutgoingColor == null && look.AccentColor == null && look.WallpaperColor == null))
            {
                return null;
            }

            var accent = look.AccentColor ?? baseSettings?.AccentColor ?? 0x0E7C66;
            var outgoing = look.OutgoingColor ?? baseSettings?.OutgoingMessageAccentColor ?? accent;

            var dark = baseSettings?.Background?.IsDark ?? false;
            var background = look.WallpaperColor is int wallpaper
                ? new Background(0, false, dark, string.Empty, null, new BackgroundTypeFill(new BackgroundFillSolid(wallpaper), 0))
                : baseSettings?.Background;

            return new ThemeSettings
            {
                BaseTheme = baseSettings?.BaseTheme,
                AccentColor = accent,
                HasOutgoingMessageAccentColor = true,
                OutgoingMessageAccentColor = outgoing,
                OutgoingMessageFill = new BackgroundFillSolid(outgoing),
                AnimateOutgoingMessageFill = false,
                Background = background
            };
        }

        private static string Key(long chatId, string name)
        {
            return "ChatLook" + chatId.ToString(CultureInfo.InvariantCulture) + name;
        }

        private int? ReadInt(long chatId, string name)
        {
            return _container.TryGetValue(Key(chatId, name), out object value) && value is int number ? number : null;
        }

        private double? ReadDouble(long chatId, string name)
        {
            return _container.TryGetValue(Key(chatId, name), out object value) && value is double number ? number : null;
        }

        private void Write(long chatId, string name, int? value)
        {
            if (value is int number)
            {
                _container.SetValue(Key(chatId, name), number);
            }
            else
            {
                _container.Remove(Key(chatId, name));
            }
        }

        private void Write(long chatId, string name, double? value)
        {
            if (value is double number)
            {
                _container.SetValue(Key(chatId, name), number);
            }
            else
            {
                _container.Remove(Key(chatId, name));
            }
        }

        private void UpdateIndex(long chatId, bool present)
        {
            var chats = new List<long>(CustomizedChats);
            chats.Remove(chatId);

            if (present)
            {
                chats.Add(chatId);
            }

            AddOrUpdateValue(IndexKey, string.Join(',', chats.ConvertAll(x => x.ToString(CultureInfo.InvariantCulture))));
        }
    }
}
