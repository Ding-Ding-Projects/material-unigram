//
// Copyright (c) Material Unigram contributors 2026
//
// Distributed under the GNU General Public License v3.0. (See accompanying
// file LICENSE or copy at https://www.gnu.org/licenses/gpl-3.0.txt)
//

using System;
using System.Collections.Generic;
using Telegram.Common;
using Telegram.Controls;
using Telegram.Services;
using Telegram.Services.Settings;
using Telegram.Td.Api;
using Windows.UI;
using Windows.UI.Text;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Automation;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Media;

namespace Telegram.Views.Popups
{
    /// <summary>
    /// Edits the look of one chat only, saved per contact or group through ChatLookSettings.
    /// Primary saves, secondary resets the chat to the app theme, close cancels.
    /// </summary>
    public sealed partial class ChatLookPopup : ModalPopup
    {
        // null in each list means "follow the app theme".
        private static readonly int?[] OutgoingColors = { null, 0x0E7C66, 0x5B4FE0, 0xE2482A, 0xD4F36B, 0x0F1A24 };
        private static readonly int?[] AccentColors = { null, 0x0E7C66, 0x5B4FE0, 0xE2482A, 0x7A5200 };
        private static readonly int?[] WallpaperColors = { null, 0xDFE7EE, 0xD3F1E7, 0xE6E3FF, 0xFFE7A8, 0x0F1A24 };

        private readonly long _chatId;
        private readonly ChatLook _look;

        public ChatLookPopup(Chat chat)
        {
            InitializeComponent();

            _chatId = chat.Id;
            _look = AppSettings.ChatLook.TryGet(chat.Id, out ChatLook saved) ? saved.Clone() : new ChatLook();

            Title = Strings.ChatLook;
            InfoLabel.Text = Strings.ChatLookInfo + " " + string.Format(Strings.ChatLookSavedFor, chat.Title);
            OutgoingLabel.Text = Strings.ChatLookYourMessages;
            AccentLabel.Text = Strings.ChatLookAccent;
            WallpaperLabel.Text = Strings.ChatLookWallpaper;

            PrimaryButtonText = Strings.Save;
            SecondaryButtonText = Strings.ChatLookUseAppTheme;
            CloseButtonText = Strings.Cancel;

            Build(OutgoingSwatches, OutgoingColors, () => _look.OutgoingColor, value => _look.OutgoingColor = value);
            Build(AccentSwatches, AccentColors, () => _look.AccentColor, value => _look.AccentColor = value);
            Build(WallpaperSwatches, WallpaperColors, () => _look.WallpaperColor, value => _look.WallpaperColor = value);

            UpdatePreview();
        }

        /// <summary>Saves or clears the look according to the button the user pressed.</summary>
        public void Commit(ContentDialogResult result)
        {
            if (result == ContentDialogResult.Primary)
            {
                AppSettings.ChatLook.Set(_chatId, _look);
            }
            else if (result == ContentDialogResult.Secondary)
            {
                AppSettings.ChatLook.Clear(_chatId);
            }
        }

        private void Build(StackPanel panel, IReadOnlyList<int?> colors, Func<int?> get, Action<int?> set)
        {
            foreach (var color in colors)
            {
                var swatch = new ToggleButton
                {
                    Width = 40,
                    Height = 40,
                    Padding = new Thickness(0),
                    CornerRadius = new CornerRadius(14),
                    IsChecked = get() == color,
                    Background = new SolidColorBrush(color is int value ? ToColor(value) : Colors.Transparent),
                    BorderThickness = new Thickness(1.5),
                    Content = color == null ? new TextBlock { Text = "A", FontWeight = FontWeights.Bold } : null
                };

                AutomationHelper(swatch, color == null ? Strings.ChatLookDefault : "#" + ((int)color).ToString("X6"));

                swatch.Click += (s, args) =>
                {
                    set(color);

                    foreach (var child in panel.Children)
                    {
                        if (child is ToggleButton other)
                        {
                            other.IsChecked = ReferenceEquals(other, swatch);
                        }
                    }

                    UpdatePreview();
                };

                panel.Children.Add(swatch);
            }
        }

        private static void AutomationHelper(FrameworkElement element, string name)
        {
            AutomationProperties.SetName(element, name);
            ToolTipService.SetToolTip(element, name);
        }

        private void UpdatePreview()
        {
            var outgoing = _look.OutgoingColor ?? 0x0E7C66;
            PreviewOutgoing.Background = new SolidColorBrush(ToColor(outgoing));
            PreviewOutgoingText.Foreground = new SolidColorBrush(IsLight(outgoing) ? ToColor(0x0F1A24) : Colors.White);

            PreviewWall.Background = _look.WallpaperColor is int wallpaper
                ? new SolidColorBrush(ToColor(wallpaper))
                : new SolidColorBrush(ToColor(0xDFE7EE));
        }

        private static Color ToColor(int rgb)
        {
            return Color.FromArgb(0xFF, (byte)(rgb >> 16), (byte)(rgb >> 8), (byte)rgb);
        }

        private static bool IsLight(int rgb)
        {
            var r = (rgb >> 16) & 0xFF;
            var g = (rgb >> 8) & 0xFF;
            var b = rgb & 0xFF;
            return (0.299 * r + 0.587 * g + 0.114 * b) > 160;
        }
    }
}
