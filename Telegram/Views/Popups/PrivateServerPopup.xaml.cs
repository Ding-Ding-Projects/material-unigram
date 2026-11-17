//
// Copyright (c) Material Unigram contributors 2026
//
// Distributed under the GNU General Public License v3.0. (See accompanying
// file LICENSE or copy at https://www.gnu.org/licenses/gpl-3.0.txt)
//

using Telegram.Controls;
using Telegram.Services;
using Telegram.Services.Settings;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;

namespace Telegram.Views.Popups
{
    /// <summary>
    /// Enters the address and public key of a self-hosted server, both shown on its dashboard.
    /// Primary saves (and stays open on invalid input), secondary forgets the server.
    /// </summary>
    public sealed partial class PrivateServerPopup : ModalPopup
    {
        public PrivateServerPopup()
        {
            InitializeComponent();

            Title = Strings.PrivateServer;
            InfoLabel.Text = Strings.PrivateServerInfo;
            AddressField.Header = Strings.PrivateServerAddress;
            KeyField.Header = Strings.PrivateServerKey;
            NoteLabel.Text = Strings.PrivateServerNote;

            AddressField.Text = AppSettings.PrivateServer.Address;
            KeyField.Text = AppSettings.PrivateServer.PublicKey;

            PrimaryButtonText = Strings.Save;
            SecondaryButtonText = AppSettings.PrivateServer.IsConfigured ? Strings.PrivateServerForget : string.Empty;
            CloseButtonText = Strings.Cancel;
        }

        private void OnPrimaryButtonClick(ModalPopup sender, ModalPopupButtonClickEventArgs args)
        {
            var error = PrivateServerSettings.Validate(AddressField.Text, KeyField.Text);
            if (error != null)
            {
                ErrorLabel.Text = error;
                ErrorLabel.Visibility = Visibility.Visible;
                args.Cancel = true;
            }
        }

        public void Commit(ContentDialogResult result)
        {
            if (result == ContentDialogResult.Primary)
            {
                AppSettings.PrivateServer.Save(AddressField.Text, KeyField.Text);
            }
            else if (result == ContentDialogResult.Secondary)
            {
                AppSettings.PrivateServer.Forget();
            }
        }
    }
}
