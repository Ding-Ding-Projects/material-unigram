<#
.SYNOPSIS
    Installs everything Material Unigram needs to build on a fresh Windows machine.

.DESCRIPTION
    Idempotent: anything already present at a usable version is used as it is. Installs only what
    is missing, into locations owned by this repository, and verifies every step.

      1. Chocolatey (if missing), then PHP, CMake and gperf through it.
      2. Visual Studio 2026 Build Tools with the C++, Clang, UWP and Windows SDK components,
         installed into a dedicated folder so other projects' toolchains are never modified.
      3. A complete vcpkg clone next to the repository, checked out at the commit vcpkg.json pins.
      4. Git submodules.

    Installing Visual Studio and Chocolatey needs administrator approval: Windows shows one
    consent prompt. If it is cancelled, the script stops with a non-zero exit code and leaves
    everything as it was.

    Writes the Visual Studio path it used to scripts\.toolchain (ignored by git), which build.bat
    reads to pin MATERIAL_UNIGRAM_VS.
#>
[CmdletBinding()]
param(
    [string] $VisualStudioPath = (Join-Path $env:LOCALAPPDATA 'MaterialUnigramBuildTools\VS2026')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Step([string] $text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Ok([string] $text) { Write-Host "    ok: $text" -ForegroundColor Green }

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Test-Command([string] $name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# Machine and user PATH first: a tool installed by an earlier run is otherwise invisible to a
# shell started before that install, and the script would install it again.
Refresh-Path

# 1. Chocolatey, PHP, CMake, gperf -----------------------------------------------------------
Step 'Chocolatey'
if (-not (Test-Command 'choco')) {
    Write-Host '    Installing Chocolatey (Windows will ask for approval)...'
    $install = "Set-ExecutionPolicy Bypass -Scope Process -Force; [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList '-NoProfile', '-Command', $install
    if ($p.ExitCode -ne 0) { throw "Chocolatey install failed or was cancelled (exit $($p.ExitCode))." }
    Refresh-Path
}
Ok (choco --version)

$chocoPackages = @()
if (-not (Test-Command 'php')) { $chocoPackages += 'php' }
# TDLib's code generator needs gperf.
if (-not (Test-Command 'gperf')) { $chocoPackages += 'gperf' }
$cmake = Get-Command cmake -ErrorAction SilentlyContinue
if (-not $cmake -or [version]((cmake --version | Select-Object -First 1) -replace '[^\d\.]', '') -lt [version]'4.4') { $chocoPackages += 'cmake' }

if ($chocoPackages.Count -gt 0) {
    Step "Installing with Chocolatey: $($chocoPackages -join ', ')"
    $p = Start-Process choco -Verb RunAs -Wait -PassThru -ArgumentList (@('install') + $chocoPackages + @('-y', '--no-progress'))
    if ($p.ExitCode -ne 0) { throw "choco install $($chocoPackages -join ' ') failed or was cancelled (exit $($p.ExitCode))." }
    Refresh-Path
}
Step 'PHP, CMake and gperf'
if (-not (Test-Command 'php')) { throw 'PHP is still not on PATH after installing.' }
if (-not (Test-Command 'gperf')) { throw 'gperf is still not on PATH after installing.' }
Ok (gperf --version | Select-Object -First 1)
Ok (php --version | Select-Object -First 1)
Ok (cmake --version | Select-Object -First 1)

# 2. Visual Studio 2026 Build Tools ----------------------------------------------------------
$components = @(
    'Microsoft.VisualStudio.Workload.VCTools',
    'Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools',
    'Microsoft.VisualStudio.Workload.UniversalBuildTools',
    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    'Microsoft.VisualStudio.Component.VC.Llvm.Clang',
    'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset',
    'Microsoft.VisualStudio.Component.Windows11SDK.26100',
    'Microsoft.VisualStudio.Component.VC.ATL'
)

Step "Visual Studio 2026 Build Tools at $VisualStudioPath"
$msbuild = Join-Path $VisualStudioPath 'MSBuild\Current\Bin\amd64\MSBuild.exe'
$clang = Join-Path $VisualStudioPath 'VC\Tools\Llvm\x64\bin\clang-cl.exe'

if (-not ((Test-Path $msbuild) -and (Test-Path $clang))) {
    $bootstrapper = Join-Path $env:TEMP 'material-unigram-vs_buildtools.exe'
    $urls = @('https://aka.ms/vs/18/stable/vs_buildtools.exe', 'https://aka.ms/vs/18/release/vs_buildtools.exe')
    $downloaded = $false
    foreach ($url in $urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $bootstrapper -UseBasicParsing
            $downloaded = $true
            break
        } catch {
            Write-Host "    $url failed: $($_.Exception.Message)"
        }
    }
    if (-not $downloaded) { throw 'Could not download the Visual Studio 2026 Build Tools bootstrapper.' }

    $signature = Get-AuthenticodeSignature $bootstrapper
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation') {
        throw "The Visual Studio bootstrapper is not validly signed by Microsoft ($($signature.Status))."
    }

    $arguments = @('--installPath', "`"$VisualStudioPath`"", '--quiet', '--wait', '--norestart', '--nocache', '--includeRecommended')
    foreach ($component in $components) { $arguments += @('--add', $component) }

    Write-Host '    Installing (Windows will ask for approval; this takes a while)...'
    $p = Start-Process $bootstrapper -Verb RunAs -Wait -PassThru -ArgumentList $arguments
    # 3010 means success with a restart recommended; nothing here needs the restart.
    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) { throw "Visual Studio Build Tools install failed or was cancelled (exit $($p.ExitCode))." }
}
if (-not (Test-Path $msbuild)) { throw "MSBuild was not found at $msbuild after installing." }
if (-not (Test-Path $clang)) { throw "clang-cl was not found at $clang after installing." }
Ok $msbuild
Ok $clang
Set-Content -Path (Join-Path $PSScriptRoot '.toolchain') -Value $VisualStudioPath -Encoding ascii

# 3. vcpkg -------------------------------------------------------------------------------------
$baseline = (Get-Content (Join-Path $root 'vcpkg.json') -Raw | ConvertFrom-Json).'builtin-baseline'
$vcpkg = Join-Path (Split-Path -Parent $root) 'vcpkg'

Step "vcpkg at $vcpkg (baseline $baseline)"
if (-not (Test-Path (Join-Path $vcpkg '.vcpkg-root'))) {
    git clone https://github.com/microsoft/vcpkg.git $vcpkg
    if ($LASTEXITCODE -ne 0) { throw 'git clone of vcpkg failed.' }
}
git -C $vcpkg fetch --quiet origin
git -C $vcpkg -c advice.detachedHead=false checkout --quiet $baseline
if ($LASTEXITCODE -ne 0) { throw "Could not check out vcpkg at $baseline." }
& (Join-Path $vcpkg 'bootstrap-vcpkg.bat') -disableMetrics
if ($LASTEXITCODE -ne 0) { throw 'bootstrap-vcpkg failed.' }
Ok (& (Join-Path $vcpkg 'vcpkg.exe') version | Select-Object -First 1)

# 4. Submodules --------------------------------------------------------------------------------
Step 'Git submodules'
git -C $root submodule update --init --recursive --jobs 6
if ($LASTEXITCODE -ne 0) { throw 'git submodule update failed.' }
Ok 'submodules ready'

Write-Host ''
Write-Host 'Toolchain ready.' -ForegroundColor Green
