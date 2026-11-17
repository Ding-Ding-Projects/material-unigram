<#
.SYNOPSIS
    Builds the Material Unigram appliance image (Super form): a minimal Debian that boots straight
    into the Telegram proxy, or with -Variant full into the full Telegram-compatible server.

.DESCRIPTION
    Output in appliance\out:
      material-unigram-appliance-<variant>-0.1.0.img    raw disk: write to a USB stick or disk
      material-unigram-appliance-<variant>-0.1.0.vhdx   for Hyper-V (Generation 2, Secure Boot off)

    Needs Docker Desktop. The image itself is assembled by mkosi in a privileged Debian container.
    Every container image the stack needs is bundled, so the first boot does not depend on a
    registry. Exit code is non-zero on any failure.
#>
[CmdletBinding()]
param(
    [ValidateSet('proxy', 'full')]
    [string] $Variant = 'proxy'
)

$ErrorActionPreference = 'Stop'
$appliance = $PSScriptRoot
$root = Split-Path -Parent $appliance
$build = Join-Path $appliance '.build'
$out = Join-Path $appliance 'out'
$version = '0.1.0'

function Step([string] $text) { Write-Host "==> $text" -ForegroundColor Cyan }
function Check([string] $what) { if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)." } }

& docker info --format '{{.ServerVersion}}' *> $null
if ($LASTEXITCODE -ne 0) { throw 'Docker is not running. Start Docker Desktop and try again.' }

$compose = if ($Variant -eq 'full') { Join-Path $root 'server\full\compose.yaml' } else { Join-Path $root 'server\compose.yaml' }

# Placeholder values only satisfy the compose file's required-variable checks while building;
# the appliance makes its real, random values on first boot.
$env:IMAGE_TAG = $version
foreach ($name in 'DASHBOARD_PASSWORD', 'MYSQL_ROOT_PASSWORD', 'MYSQL_PASSWORD', 'MINIO_ROOT_USER', 'MINIO_ROOT_PASSWORD') {
    Set-Item "env:$name" 'build-time-placeholder'
}

Step "Building and collecting the $Variant images"
& docker compose -f $compose build; Check 'docker compose build'
& docker compose -f $compose pull --ignore-buildable; Check 'docker compose pull'
$images = @(& docker compose -f $compose config --images | Sort-Object -Unique)
Check 'docker compose config'

Step 'Staging the image contents'
if (Test-Path $build) { Remove-Item -Recurse -Force $build }
Copy-Item -Recurse (Join-Path $appliance 'mkosi.extra') (Join-Path $build 'mkosi.extra')
Copy-Item (Join-Path $appliance 'mkosi.conf'), (Join-Path $appliance 'mkosi.postinst') $build
$opt = Join-Path $build 'mkosi.extra\opt\material-unigram'
$stack = Join-Path $opt 'stack'
New-Item -ItemType Directory -Force (Join-Path $stack 'full') | Out-Null
Copy-Item (Join-Path $root 'server\compose.yaml'), (Join-Path $root 'server\.env.example') $stack
Copy-Item (Join-Path $root 'server\full\compose.yaml'), (Join-Path $root 'server\full\.env.example') (Join-Path $stack 'full')
New-Item -ItemType Directory -Force (Join-Path $build 'mkosi.extra\etc\material-unigram') | Out-Null
Set-Content -Path (Join-Path $build 'mkosi.extra\etc\material-unigram\variant') -Value $Variant -Encoding ascii -NoNewline
& docker save -o (Join-Path $opt 'images.tar') @images; Check 'docker save'

Step 'Assembling the disk image with mkosi (privileged Debian container)'
New-Item -ItemType Directory -Force $out | Out-Null
$name = "material-unigram-appliance-$Variant-$version"
$script = @"
set -e
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends mkosi systemd-boot systemd-container dosfstools mtools e2fsprogs qemu-utils debian-archive-keyring ca-certificates >/dev/null
cd /work
mkosi --force build || exit 1
img=`$(ls -1 material-unigram-appliance*.raw | head -n1)
[ -n "`$img" ] || { echo 'mkosi produced no raw image'; exit 1; }
cp "`$img" /out/$name.img
qemu-img convert -f raw -O vhdx -o subformat=dynamic /out/$name.img /out/$name.vhdx
"@ -replace "`r`n", "`n"
$script | & docker run --rm -i --privileged -v "${build}:/work" -v "${out}:/out" debian:trixie sh -s
Check 'mkosi build'

Get-ChildItem $out -Filter "$name.*" | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    Write-Host ("    {0}  {1:N0} MB  sha256 {2}" -f $_.Name, ($_.Length / 1MB), $hash) -ForegroundColor Green
}
Write-Host "Appliance image ready in $out" -ForegroundColor Green
