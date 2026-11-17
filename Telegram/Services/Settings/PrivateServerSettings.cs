//
// Copyright (c) Material Unigram contributors 2026
//
// Distributed under the GNU General Public License v3.0. (See accompanying
// file LICENSE or copy at https://www.gnu.org/licenses/gpl-3.0.txt)
//

using System;
using System.Text.RegularExpressions;

namespace Telegram.Services.Settings
{
    /// <summary>
    /// The self-hosted Telegram-compatible server an account can use instead of Telegram.
    /// Accounts made on it are added as test-path sessions; the patched TDLib reads the address
    /// and public key below from the process environment, which Apply sets.
    /// </summary>
    public partial class PrivateServerSettings : SettingsServiceBase
    {
        public const string AddressVariable = "MATERIAL_UNIGRAM_SERVER";
        public const string KeyVariable = "MATERIAL_UNIGRAM_SERVER_KEY";

        private static readonly Regex AddressPattern = new(@"^[A-Za-z0-9.\-\[\]:]+:\d{1,5}$");

        public PrivateServerSettings(ISettingsStore container)
            : base(container)
        {
        }

        /// <summary>host:port the server's gateway listens on, for example 192.0.2.10:10443.</summary>
        public string Address => GetValueOrDefault("Address", string.Empty);

        /// <summary>The server's RSA public key in PEM form, copied from its dashboard.</summary>
        public string PublicKey => GetValueOrDefault("PublicKey", string.Empty);

        public bool IsConfigured => Validate(Address, PublicKey) == null;

        /// <summary>Returns null when both values can be used, otherwise a sentence saying why not.</summary>
        public static string Validate(string address, string publicKey)
        {
            address = address?.Trim() ?? string.Empty;
            publicKey = publicKey?.Trim() ?? string.Empty;

            if (!AddressPattern.IsMatch(address))
            {
                return "Enter the address as host:port, for example 192.0.2.10:10443.";
            }

            var colon = address.LastIndexOf(':');
            if (!int.TryParse(address[(colon + 1)..], out int port) || port < 1 || port > 65535)
            {
                return "The port must be a number from 1 to 65535.";
            }

            if (!publicKey.StartsWith("-----BEGIN RSA PUBLIC KEY-----") || !publicKey.EndsWith("-----END RSA PUBLIC KEY-----"))
            {
                return "Paste the whole public key, from -----BEGIN RSA PUBLIC KEY----- to -----END RSA PUBLIC KEY-----.";
            }

            return null;
        }

        public void Save(string address, string publicKey)
        {
            AddOrUpdateValue("Address", address.Trim());
            AddOrUpdateValue("PublicKey", publicKey.Trim().Replace("\r\n", "\n"));
            Apply();
        }

        public void Forget()
        {
            AddOrUpdateValue("Address", string.Empty);
            AddOrUpdateValue("PublicKey", string.Empty);
            Apply();
        }

        /// <summary>
        /// Hands the values to TDLib. Called before the first client starts; TDLib reads the key
        /// once per run, so a changed key takes effect after the app restarts.
        /// </summary>
        public void Apply()
        {
            if (IsConfigured)
            {
                Environment.SetEnvironmentVariable(AddressVariable, Address);
                Environment.SetEnvironmentVariable(KeyVariable, PublicKey + "\n");
            }
            else
            {
                Environment.SetEnvironmentVariable(AddressVariable, null);
                Environment.SetEnvironmentVariable(KeyVariable, null);
            }
        }
    }
}
