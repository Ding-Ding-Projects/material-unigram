<#
.SYNOPSIS
    Hosts the Material Unigram Telegram proxy (MTProxy + dashboard) in Docker on this computer.

.DESCRIPTION
    host.bat --detached   start in the background, wait until healthy, print the LAN address
    host.bat --logs       live log view with keyboard controls (leaving it keeps the proxy running)
    host.bat --stop       stop the proxy (data and secret are kept)
    host.bat              ask which of the above

    Settings live in server\.env (ignored by git). If it does not exist yet, this script asks for
    a dashboard password and writes one. Exit code is non-zero whenever something did not work.
#>
[CmdletBinding()]
param(
    [ValidateSet('ask', 'detached', 'logs', 'stop')]
    [string] $Mode = 'ask',

    # proxy: MTProxy for your real Telegram account. full: a private Telegram-compatible server.
    [ValidateSet('proxy', 'full')]
    [string] $Server = 'proxy'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$serverDir = Join-Path $root 'server'
if ($Server -eq 'full') {
    $stackDir = Join-Path $serverDir 'full'
    $label = 'full server'
} else {
    $stackDir = $serverDir
    $label = 'Telegram proxy'
}
$compose = Join-Path $stackDir 'compose.yaml'
$envFile = Join-Path $stackDir '.env'
$serviceForLogs = if ($Server -eq 'full') { '' } else { 'proxy' }

function Say([string] $text, [string] $color = 'Gray') { Write-Host $text -ForegroundColor $color }
function Fail([string] $text) { Say "FAILED: $text" 'Red'; exit 1 }

function Invoke-Compose {
    param([string[]] $Arguments)
    # Out-Host: docker's output must reach the console, not become part of the return value.
    & docker compose -f $compose --env-file $envFile @Arguments | Out-Host
    return $LASTEXITCODE
}

function Get-LanAddress {
    # The address on the interface that holds the default route: the one other devices can reach.
    $route = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1
    if ($route) {
        $ip = Get-NetIPAddress -InterfaceIndex $route.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1
        if ($ip) { return $ip.IPAddress }
    }
    return $null
}

function Read-EnvValue([string] $name) {
    if (-not (Test-Path $envFile)) { return $null }
    foreach ($line in Get-Content $envFile) {
        if ($line -match "^\s*$name\s*=\s*(.*)$") { return $Matches[1].Trim() }
    }
    return $null
}

function Write-EnvValue([string] $name, [string] $value) {
    $lines = @()
    if (Test-Path $envFile) { $lines = @(Get-Content $envFile) }
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$name\s*=") { $lines[$i] = "$name=$value"; $found = $true }
    }
    if (-not $found) { $lines += "$name=$value" }
    Set-Content -Path $envFile -Value $lines -Encoding ascii
}

function Test-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Fail 'Docker is not installed. Install Docker Desktop (or run build.bat, which can install it), then try again.'
    }
    & docker info --format '{{.ServerVersion}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        Fail 'Docker is installed but not running. Start Docker Desktop, wait until it says it is running, then try again.'
    }
}

function New-Secret([int] $bytes = 24) {
    $buffer = New-Object byte[] $bytes
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    return ([Convert]::ToBase64String($buffer) -replace '[^A-Za-z0-9]', '')
}

function Ensure-Settings {
    if (-not (Test-Path $envFile)) {
        Copy-Item (Join-Path $stackDir '.env.example') $envFile
    }
    if ($Server -eq 'full') {
        # Internal service credentials: random, written once, never shown.
        foreach ($name in 'MYSQL_ROOT_PASSWORD', 'MYSQL_PASSWORD', 'MINIO_ROOT_PASSWORD') {
            if (-not (Read-EnvValue $name)) { Write-EnvValue $name (New-Secret) }
        }
        if (-not (Read-EnvValue 'MINIO_ROOT_USER')) { Write-EnvValue 'MINIO_ROOT_USER' ('store' + (New-Secret 6)) }
    }
    $password = Read-EnvValue 'DASHBOARD_PASSWORD'
    if (-not $password -or $password.Length -lt 8) {
        Say 'Choose a dashboard password (8 characters or more). It is saved in server\.env on this computer only.'
        do {
            $secure = Read-Host -AsSecureString 'Dashboard password'
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
            if ($plain.Length -lt 8) { Say 'That is shorter than 8 characters.' 'Yellow' }
        } while ($plain.Length -lt 8)
        Write-EnvValue 'DASHBOARD_PASSWORD' $plain
    }
    $lan = Get-LanAddress
    if (-not (Read-EnvValue 'PUBLIC_HOST') -and $lan) {
        Write-EnvValue 'PUBLIC_HOST' $lan
    }
    return $lan
}

function Start-Detached {
    Test-Docker
    $lan = Ensure-Settings

    Say "==> Getting the $label images" 'Cyan'
    if ((Invoke-Compose @('pull', '--quiet', '--ignore-buildable')) -ne 0 -or (Invoke-Compose @('pull', '--quiet')) -ne 0) {
        Say '    Some published images are not available; building them here instead (several minutes).' 'Yellow'
        if ((Invoke-Compose @('build')) -ne 0) { Fail "Building the $label images failed. Read the error above." }
    }

    Say '==> Starting' 'Cyan'
    if ((Invoke-Compose @('up', '-d')) -ne 0) { Fail 'docker compose up failed. Read the error above.' }

    $port = Read-EnvValue 'DASHBOARD_HOST_PORT'; if (-not $port) { $port = if ($Server -eq 'full') { '8081' } else { '8080' } }
    $proxyPort = if ($Server -eq 'full') { Read-EnvValue 'GATEWAY_PORT' } else { Read-EnvValue 'PROXY_PORT' }
    if (-not $proxyPort) { $proxyPort = if ($Server -eq 'full') { '10443' } else { '443' } }
    $waitSeconds = if ($Server -eq 'full') { 300 } else { 90 }

    Say "==> Waiting for the $label to be healthy (up to $waitSeconds seconds)" 'Cyan'
    $healthy = $false
    for ($i = 0; $i -lt ($waitSeconds / 2); $i++) {
        try {
            $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:$port/healthz"
            if ($r.StatusCode -eq 200) { $healthy = $true; break }
        } catch { }
        Start-Sleep -Seconds 2
    }
    if (-not $healthy) {
        Invoke-Compose @('logs', '--tail', '40') | Out-Null
        Fail "The $label did not become healthy within $waitSeconds seconds. Run host.bat --logs to see why."
    }

    $lanOk = $false
    if ($lan) {
        try {
            $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://${lan}:$port/healthz"
            $lanOk = $r.StatusCode -eq 200
        } catch { }
    }

    Say ''
    Say "The $label is running." 'Green'
    if ($lan) {
        Say "  Dashboard:  http://${lan}:$port/" 'White'
        $what = if ($Server -eq 'full') { 'Server:    ' } else { 'Proxy:     ' }
        Say "  $what ${lan}:$proxyPort" 'White'
        if ($lanOk) { Say '  Checked: the dashboard answered on the network address, not only on this computer.' 'Green' }
        else { Say '  Warning: the dashboard did not answer on the network address. Windows Firewall may be blocking it.' 'Yellow' }
    } else {
        Say "  Dashboard:  http://127.0.0.1:$port/  (no network address found)" 'Yellow'
    }
    if ($Server -eq 'full') { Say '  The server key fingerprint for Material Unigram is on the dashboard.' }
    else { Say '  The share link for Material Unigram and phones is on the dashboard.' }
    return 0
}

function Show-Logs {
    Test-Docker
    $follow = $true
    $filter = ''
    while ($true) {
        if ($follow) {
            Clear-Host
            $state = (& docker compose -f $compose --env-file $envFile ps --format '{{.Service}} {{.State}} {{.Health}}' 2>$null) -join '; '
            Say "Material Unigram $label - logs   ($state)" 'Green'
            Say ('-' * 72) 'DarkGray'
            $logArgs = @('compose', '-f', $compose, '--env-file', $envFile, 'logs', '--no-color', '--tail', '40')
            if ($serviceForLogs) { $logArgs += $serviceForLogs }
            $lines = & docker @logArgs 2>&1
            foreach ($line in $lines) {
                if (-not $filter -or "$line" -match $filter) { Write-Host "$line" }
            }
            Say ('-' * 72) 'DarkGray'
            $filterText = if ($filter) { " filter: $filter" } else { '' }
            Say "[F] pause/follow  [/] filter (regex)  [C] clear filter  [Q] leave (keeps running)  [S] stop proxy$filterText" 'Yellow'
        }
        $deadline = (Get-Date).AddSeconds(2)
        while ((Get-Date) -lt $deadline) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true).Key
                switch ($key) {
                    'F' { $follow = -not $follow; if (-not $follow) { Say 'Paused. Press F to follow again.' 'Yellow' } }
                    'Oem2' {
                        $candidate = Read-Host 'Regex filter'
                        try { [void][regex]::new($candidate); $filter = $candidate } catch { Say "Not a valid pattern: $($_.Exception.Message)" 'Red'; Start-Sleep 2 }
                    }
                    'Divide' { $filter = Read-Host 'Regex filter' }
                    'C' { $filter = '' }
                    'Q' { Say 'Left the log view. The proxy keeps running.' 'Green'; return 0 }
                    'S' { Invoke-Compose @('stop') | Out-Null; Say 'Proxy stopped. Your secret and settings are kept.' 'Green'; return 0 }
                }
                break
            }
            Start-Sleep -Milliseconds 100
        }
    }
}

switch ($Mode) {
    'detached' { exit (Start-Detached) }
    'logs' { exit (Show-Logs) }
    'stop' {
        Test-Docker
        if ((Invoke-Compose @('stop')) -ne 0) { Fail 'Stopping failed.' }
        Say 'Proxy stopped. Your secret and settings are kept.' 'Green'
        exit 0
    }
    default {
        Say 'Material Unigram Telegram proxy' 'Green'
        Say '  [1] Start in the background'
        Say '  [2] Start and watch the live log'
        Say '  [3] Stop'
        Say '  [Q] Quit'
        while ($true) {
            $key = [Console]::ReadKey($true).KeyChar
            switch ($key) {
                '1' { exit (Start-Detached) }
                '2' { $code = Start-Detached; if ($code -ne 0) { exit $code }; exit (Show-Logs) }
                '3' { Test-Docker; Invoke-Compose @('stop') | Out-Null; Say 'Proxy stopped.' 'Green'; exit 0 }
                { $_ -in 'q', 'Q' } { exit 0 }
            }
        }
    }
}
