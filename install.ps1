<#
.SYNOPSIS
    Neural Seam Client Runtime - one-liner installer for Windows.

.DESCRIPTION
    Detects the CPU architecture, resolves the matching release asset
    (neural-seam-windows-<arch>.exe), downloads it, verifies its sha256 against
    the release's checksums.txt (MANDATORY - aborts on mismatch), installs it as
    neural-seam.exe under a per-user directory, and adds that directory to the
    user PATH (or instructs how when it cannot).

    Compliance (P2): this script only fetches, verifies and places a binary. It
    runs no inference and triggers nothing. After install, the
    developer-initiated update path is `neural-seam upgrade`.

    Hardening: sha256 verification is mandatory here. Code signing and TLS
    pinning are not yet active; this installer does not verify a signature.
    See docs/install.md.

.PARAMETER Version
    Install a specific release (bare SemVer, e.g. 1.2.3). Defaults to the latest
    release. May also be set via the NEURAL_SEAM_VERSION environment variable.

.PARAMETER InstallDir
    Install location. Defaults to %LOCALAPPDATA%\Programs\neural-seam. May also
    be set via the NEURAL_SEAM_INSTALL_DIR environment variable.

.EXAMPLE
    irm https://raw.githubusercontent.com/NeuralSeam/neural-seam-releases/HEAD/install.ps1 | iex

.EXAMPLE
    # Pin a version when piping to iex:
    $env:NEURAL_SEAM_VERSION = '1.2.3'; irm .../install.ps1 | iex
#>
[CmdletBinding()]
param(
    [string]$Version = $env:NEURAL_SEAM_VERSION,
    [string]$InstallDir = $env:NEURAL_SEAM_INSTALL_DIR
)

# Fail loudly: any unhandled error aborts rather than half-installing.
$ErrorActionPreference = 'Stop'
# Modern TLS for the downloads on older Windows PowerShell hosts.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# Public distribution repo (source lives in the private neural-seam-runtime;
# releases + this script are published to the public neural-seam-releases).
$Repo = 'NeuralSeam/neural-seam-releases'
$Binary = 'neural-seam'

function Fail([string]$Message) {
    # Single actionable line on stderr, no PowerShell stack trace, no partial
    # install (the binary is only moved into place as the last step).
    Write-Error "neural-seam install: $Message" -ErrorAction Continue
    exit 1
}

function Info([string]$Message) {
    Write-Host $Message
}

# --- detect arch ----------------------------------------------------------

function Get-TargetArch {
    # PROCESSOR_ARCHITECTURE reflects the process; for a 32-bit shell on 64-bit
    # Windows, PROCESSOR_ARCHITEW6432 carries the real machine arch.
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
    switch ($arch.ToUpperInvariant()) {
        'AMD64' { return 'amd64' }
        'ARM64' { return 'arm64' }
        'X86' { Fail 'unsupported architecture: x86 (32-bit). Supported: amd64, arm64.' }
        default { Fail "unsupported architecture: $arch (supported: amd64, arm64)" }
    }
}

$Arch = Get-TargetArch
# Asset naming is the release contract: neural-seam-windows-<arch>.exe. Mirrors
# internal/selfupdate AssetName so installer and self-update agree.
$Asset = "$Binary-windows-$Arch.exe"

# --- pilot platform gate --------------------------------------------------

# The pilot release publishes only windows/amd64; windows/arm64 (and
# darwin/linux) are DEFERRED in .goreleaser.yml. Fail early with an actionable
# message here instead of a raw "asset not found" download error further down.
# When the multi-arch/OS pipeline is restored (sibling card
# readd-release-pipeline-steps-after-pilot.md), remove this gate.
if ($Arch -ne 'amd64') {
    Fail "the pilot release publishes only windows/amd64; windows/$Arch is not published yet. Install on an amd64 host, or wait for the multi-arch release. See docs/install.md."
}

# --- resolve version / URLs ----------------------------------------------

function Resolve-LatestTag {
    $api = "https://api.github.com/repos/$Repo/releases/latest"
    try {
        # A User-Agent header is required by the GitHub API.
        $rel = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'neural-seam-runtime' }
    }
    catch {
        Fail "could not reach the GitHub releases API ($api). Check your network and try again, or pass -Version."
    }
    if (-not $rel.tag_name) {
        Fail 'could not determine the latest release tag from the GitHub API response'
    }
    return $rel.tag_name
}

if ($Version) {
    # Accept a bare SemVer or a full tag; normalise to the runtime-v tag.
    $v = $Version -replace '^runtime-v', '' -replace '^v', ''
    $Tag = "runtime-v$v"
    $DisplayVersion = $v
}
else {
    $Tag = Resolve-LatestTag
    $DisplayVersion = $Tag -replace '^runtime-v', ''
}

$BaseUrl = "https://github.com/$Repo/releases/download/$Tag"
$AssetUrl = "$BaseUrl/$Asset"
$ChecksumsUrl = "$BaseUrl/checksums.txt"

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'Programs\neural-seam'
}

# --- download + verify ----------------------------------------------------

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("neural-seam-install-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

try {
    Info "Installing $Binary $DisplayVersion (windows/$Arch)..."

    $assetPath = Join-Path $TmpDir $Asset
    $checksumsPath = Join-Path $TmpDir 'checksums.txt'

    try {
        Invoke-WebRequest -Uri $AssetUrl -OutFile $assetPath -UseBasicParsing -Headers @{ 'User-Agent' = 'neural-seam-runtime' }
    }
    catch {
        Fail "download failed for $AssetUrl. The asset may not exist for this arch/version, or the network is unavailable."
    }
    try {
        Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $checksumsPath -UseBasicParsing -Headers @{ 'User-Agent' = 'neural-seam-runtime' }
    }
    catch {
        Fail "download failed for $ChecksumsUrl. Cannot verify integrity, aborting."
    }

    # Mandatory sha256 gate. Find the line for our asset in checksums.txt
    # ("<hexdigest>  <filename>", tolerating a leading "*" binary-mode marker).
    $expected = $null
    foreach ($line in Get-Content -LiteralPath $checksumsPath) {
        $parts = $line -split '\s+', 2 | Where-Object { $_ -ne '' }
        if ($parts.Count -lt 2) { continue }
        $name = ($parts[1].Trim()) -replace '^\*', ''
        # Strip any path prefix so a "dist/neural-seam-..." entry still matches.
        $name = Split-Path -Leaf $name
        if ($name -ieq $Asset) { $expected = $parts[0].Trim(); break }
    }
    if (-not $expected) {
        Fail "no checksum entry for $Asset in checksums.txt; refusing to install an unverifiable binary."
    }

    $actual = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash
    if ($actual.ToLowerInvariant() -ne $expected.ToLowerInvariant()) {
        Fail "checksum mismatch for ${Asset}: expected $expected, got $actual. The download is corrupt or tampered; aborting (nothing installed)."
    }
    Info 'Checksum verified (sha256).'

    # --- install ----------------------------------------------------------

    if (-not (Test-Path -LiteralPath $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    $dest = Join-Path $InstallDir "$Binary.exe"
    # Move into place last. Remove a prior copy first so Move-Item does not fail
    # on an existing target.
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
    Move-Item -LiteralPath $assetPath -Destination $dest -Force

    Info "Installed $Binary to $dest."
}
finally {
    if (Test-Path -LiteralPath $TmpDir) { Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# --- PATH setup -----------------------------------------------------------

# Add InstallDir to the *user* PATH (HKCU) if it is not already present. This
# never touches the machine PATH and needs no elevation.
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @()
if ($userPath) { $pathEntries = $userPath -split ';' | Where-Object { $_ -ne '' } }

$alreadyOnPath = $pathEntries | Where-Object { $_.TrimEnd('\') -ieq $InstallDir.TrimEnd('\') }
if ($alreadyOnPath) {
    Info ''
    Info "Run '$Binary version' to confirm. Update later with '$Binary upgrade'."
}
else {
    try {
        $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        # Make it usable in the current session too.
        $env:Path = "$env:Path;$InstallDir"
        Info ''
        Info "Added $InstallDir to your user PATH. Open a new terminal (or run the line below) so it takes effect:"
        Info "  `$env:Path = `"`$env:Path;$InstallDir`""
        Info ''
        Info "Then run '$Binary version' to confirm. Update later with '$Binary upgrade'."
    }
    catch {
        Info ''
        Info "$InstallDir is not on your PATH and it could not be added automatically."
        Info 'Add it manually, e.g.:'
        Info "  [Environment]::SetEnvironmentVariable('Path', `"`$([Environment]::GetEnvironmentVariable('Path','User'));$InstallDir`", 'User')"
        Info ''
        Info "Then open a new terminal and run '$Binary version' to confirm."
    }
}
