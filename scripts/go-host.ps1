<#
.SYNOPSIS
    Runs the Material Unigram Telegram proxy as plain processes in WSL: no Docker.

.DESCRIPTION
    go-host.bat            install if needed, start, wait until healthy, print the LAN address
    go-host.bat --stop     stop the proxy processes
    go-host.bat --status   show whether it is running

    Uses its own WSL distro (MaterialUnigramProxy) so no other distro or global WSL setting is
    changed. MTProxy is built there from the same pinned commit as the Docker image. Because WSL
    sits behind its own network address, Windows forwards the proxy and dashboard ports to it;
    adding that forwarding needs administrator approval (one Windows prompt).

    Settings: server\.env (the same file host.bat uses).
#>
[CmdletBinding()]
param(
    [ValidateSet('start', 'stop', 'status')]
    [string] $Mode = 'start'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$distro = 'MaterialUnigramProxy'
$envFile = Join-Path $root 'server\.env'
$mtproxyCommit = '69f2f083b57bbd94932cb9f4f32155f33e719ff1'

function Say([string] $text, [string] $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Fail([string] $text) { Say "FAILED: $text" 'Red'; exit 1 }

function Read-EnvValue([string] $name) {
    if (-not (Test-Path $envFile)) { return $null }
    foreach ($line in Get-Content $envFile) { if ($line -match "^\s*$name\s*=\s*(.*)$") { return $Matches[1].Trim() } }
    return $null
}

function Write-EnvValue([string] $name, [string] $value) {
    $lines = @(); if (Test-Path $envFile) { $lines = @(Get-Content $envFile) }
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$name\s*=") { $lines[$i] = "$name=$value"; $found = $true } }
    if (-not $found) { $lines += "$name=$value" }
    Set-Content -Path $envFile -Value $lines -Encoding ascii
}

function Get-LanAddress {
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1
    if ($route) {
        $ip = Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ip) { return $ip.IPAddress }
    }
    return $null
}

function Invoke-Wsl([string] $script) {
    # Root inside the dedicated distro only. The script goes through a temporary file written as
    # plain UTF-8 with LF endings: piping from PowerShell adds a byte-order mark that sh rejects.
    $file = Join-Path $env:TEMP ("material-unigram-wsl-" + [Guid]::NewGuid().ToString('N') + '.sh')
    try {
        [IO.File]::WriteAllText($file, ($script -replace "`r", ''), (New-Object System.Text.UTF8Encoding $false))
        $linuxPath = (wsl.exe -d $distro -u root -- wslpath -a ($file -replace '\\', '/') | Out-String).Trim()
        & wsl.exe -d $distro -u root -- sh $linuxPath
        return $LASTEXITCODE
    } finally {
        Remove-Item $file -ErrorAction SilentlyContinue
    }
}

function Test-Distro {
    $names = (wsl.exe -l -q 2>$null | Out-String) -replace "`0", ''
    return ($names -split "`r?`n" | ForEach-Object { $_.Trim() }) -contains $distro
}

function Install-Distro {
    if (Test-Distro) { return }
    Say "==> Creating the WSL distro $distro (Debian; one time)" 'Cyan'
    & wsl.exe --install Debian --name $distro --no-launch
    if ($LASTEXITCODE -ne 0 -or -not (Test-Distro)) { Fail "Could not create the WSL distro $distro. Is WSL enabled?" }
}

function Install-Proxy {
    Say '==> Installing MTProxy inside WSL (first time takes a few minutes)' 'Cyan'
    $code = Invoke-Wsl @"
set -e
if [ -x /opt/material-unigram/mtproto-proxy ] && [ "`$(head -n1 /opt/material-unigram/commit 2>/dev/null)" = "$mtproxyCommit" ]; then exit 0; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends git ca-certificates curl build-essential libssl-dev zlib1g-dev nodejs procps >/dev/null
rm -rf /tmp/mtproxy-src && git clone -q https://github.com/TelegramMessenger/MTProxy.git /tmp/mtproxy-src
cd /tmp/mtproxy-src && git checkout -q $mtproxyCommit
make -j`$(nproc) CFLAGS='-O3 -std=gnu11 -Wall -mpclmul -march=core2 -mfpmath=sse -mssse3 -fno-strict-aliasing -fno-strict-overflow -fwrapv -DAES=1 -D_GNU_SOURCE=1 -D_FILE_OFFSET_BITS=64 -fcommon' >/dev/null
mkdir -p /opt/material-unigram && install -m 755 objs/bin/mtproto-proxy /opt/material-unigram/mtproto-proxy
echo $mtproxyCommit > /opt/material-unigram/commit
"@
    if ($code -ne 0) { Fail 'Installing MTProxy inside WSL failed. Read the error above.' }
}

function Get-WslAddress {
    $ip = (wsl.exe -d $distro -u root -- sh -c "hostname -I | cut -d' ' -f1" | Out-String).Trim()
    if (-not $ip) { Fail 'Could not read the WSL address.' }
    return $ip
}

function Set-PortForwarding([string] $wslIp, [string[]] $ports) {
    $commands = @()
    foreach ($port in $ports) {
        $commands += "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=0.0.0.0"
        $commands += "netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIp"
        $commands += "if (-not (Get-NetFirewallRule -DisplayName 'Material Unigram proxy $port' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -DisplayName 'Material Unigram proxy $port' -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow -Profile Private | Out-Null }"
    }
    $current = (netsh interface portproxy show v4tov4 | Out-String)
    $needed = $ports | Where-Object { $current -notmatch "0\.0\.0\.0\s+$_\s+$([regex]::Escape($wslIp))\s+$_" }
    if (-not $needed) { return }
    Say "==> Forwarding ports $($ports -join ', ') to WSL (Windows will ask for approval)" 'Cyan'
    $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-Command', ($commands -join '; ')
    if ($p.ExitCode -ne 0) { Fail 'Port forwarding was not set up (cancelled or failed). The proxy is not reachable from other devices.' }
}

function Start-Proxy {
    if (-not (Test-Path $envFile)) { Copy-Item (Join-Path $root 'server\.env.example') $envFile }
    $password = Read-EnvValue 'DASHBOARD_PASSWORD'
    if (-not $password -or $password.Length -lt 8) {
        do {
            $secure = Read-Host -AsSecureString 'Choose a dashboard password (8+ characters)'
            $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
        } while ($password.Length -lt 8)
        Write-EnvValue 'DASHBOARD_PASSWORD' $password
    }
    $lan = Get-LanAddress
    if (-not (Read-EnvValue 'PUBLIC_HOST') -and $lan) { Write-EnvValue 'PUBLIC_HOST' $lan }

    $proxyPort = Read-EnvValue 'PROXY_PORT'; if (-not $proxyPort) { $proxyPort = '443' }
    $dashPort = Read-EnvValue 'DASHBOARD_HOST_PORT'; if (-not $dashPort) { $dashPort = '8080' }

    Install-Distro
    Install-Proxy

    $serverDir = (wsl.exe -d $distro -u root -- wslpath -a ($root -replace '\\', '/') | Out-String).Trim() + '/server'
    Say '==> Starting MTProxy and the dashboard in WSL' 'Cyan'
    # Settings go in through a root-only file, never on a command line.
    $settings = @(
        "DASHBOARD_PASSWORD='$($password -replace "'", "'\''")'",
        "PUBLIC_HOST='$(Read-EnvValue 'PUBLIC_HOST')'",
        "TLS_DOMAIN='$(Read-EnvValue 'TLS_DOMAIN')'",
        "PROXY_TAG='$(Read-EnvValue 'PROXY_TAG')'",
        "PROXY_PORT=$proxyPort",
        "DASHBOARD_PORT=$dashPort"
    ) -join "`n"
    $code = Invoke-Wsl @"
set -e
umask 077
mkdir -p /var/lib/material-unigram-proxy
tee /var/lib/material-unigram-proxy/settings >/dev/null <<'SETTINGS'
$settings
SETTINGS
pkill -f /opt/material-unigram/mtproto-proxy || true
pkill -f 'dashboard/server.js' || true
set -a; . /var/lib/material-unigram-proxy/settings; set +a
export DATA_DIR=/var/lib/material-unigram-proxy MTPROXY_BIN=/opt/material-unigram/mtproto-proxy DASHBOARD_DIR='$serverDir/dashboard' MTPROXY_COMMIT=$mtproxyCommit
nohup sh '$serverDir/entrypoint.sh' > /var/lib/material-unigram-proxy/host.log 2>&1 &
"@
    if ($code -ne 0) { Fail 'Starting inside WSL failed.' }

    $wslIp = Get-WslAddress
    Set-PortForwarding $wslIp @($proxyPort, $dashPort)

    Say '==> Waiting for the proxy to be healthy (up to 90 seconds)' 'Cyan'
    $healthy = $false
    for ($i = 0; $i -lt 45; $i++) {
        try { if ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://${wslIp}:$dashPort/healthz").StatusCode -eq 200) { $healthy = $true; break } } catch { }
        Start-Sleep 2
    }
    if (-not $healthy) {
        wsl.exe -d $distro -u root -- tail -n 30 /var/lib/material-unigram-proxy/host.log
        Fail 'The proxy did not become healthy within 90 seconds.'
    }
    $lanOk = $false
    if ($lan) { try { $lanOk = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://${lan}:$dashPort/healthz").StatusCode -eq 200 } catch { } }

    Say ''
    Say 'The Telegram proxy is running in WSL (no Docker).' 'Green'
    Say "  Dashboard:  http://${lan}:$dashPort/" 'White'
    Say "  Proxy:      ${lan}:$proxyPort" 'White'
    if ($lanOk) { Say '  Checked: the dashboard answered on the network address.' 'Green' }
    else { Say '  Warning: the dashboard did not answer on the network address yet. Check Windows Firewall.' 'Yellow' }
    exit 0
}

switch ($Mode) {
    'start' { Start-Proxy }
    'stop' {
        if (Test-Distro) { [void](Invoke-Wsl "pkill -f /opt/material-unigram/mtproto-proxy || true; pkill -f 'dashboard/server.js' || true") }
        Say 'Proxy stopped. The secret and settings are kept.' 'Green'
        exit 0
    }
    'status' {
        if (-not (Test-Distro)) { Say 'Not installed.'; exit 1 }
        $running = Invoke-Wsl "pgrep -f /opt/material-unigram/mtproto-proxy >/dev/null"
        if ($running -eq 0) { Say 'Running.' 'Green'; exit 0 } else { Say 'Stopped.' 'Yellow'; exit 1 }
    }
}
