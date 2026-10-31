<#
.SYNOPSIS
    Installiert bzw. aktualisiert PowerShell 7 auf die neueste Version (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Ermittelt die neueste Version über GitHub (PowerShell/PowerShell, latest release)
    und vergleicht sie mit der installierten pwsh-Version.
      Windows: winget (Microsoft.PowerShell), sonst MSI-Download
      macOS:   Homebrew (cask powershell), falls darüber installiert, sonst PKG-Download + sudo installer
    Tipp Windows: am besten aus Windows PowerShell 5.1 oder Windows Terminal starten,
    damit kein laufender pwsh-Prozess das Update blockiert.

.EXAMPLE
    ./UpdatePS.ps1
    ./UpdatePS.ps1 -Force

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-10-29  Claude/Hubi   Erste Version, Windows + macOS
#>
[CmdletBinding()]
param(
    [switch]$Force   # auch installieren, wenn bereits aktuell
)

$ScriptVersion = '1.0.0'

$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$osName    = if ($onWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
$hostName  = [System.Net.Dns]::GetHostName()
$arch      = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()  # x64 / arm64

Write-Host "UpdatePS $ScriptVersion auf $hostName ($osName, $arch)" -ForegroundColor Cyan

# --- installierte pwsh-Version ---
$installed = $null
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    $installed = [version]((& pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') -replace '-.*$', '')
}

# --- neueste Version von GitHub ---
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -UseBasicParsing
$latest  = [version]($release.tag_name.TrimStart('v'))

Write-Host "Installiert: $(if ($installed) { $installed } else { 'keine' })   Neueste: $latest"
if ($installed -and $installed -ge $latest -and -not $Force) {
    Write-Host 'PowerShell ist aktuell.' -ForegroundColor Green
    return
}

function Get-Asset([string]$pattern) {
    $asset = $release.assets | Where-Object name -like $pattern | Select-Object -First 1
    if (-not $asset) { throw "Kein Download für Muster '$pattern' gefunden." }
    $file = Join-Path ([System.IO.Path]::GetTempPath()) $asset.name
    Write-Host "Lade $($asset.name) ..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -UseBasicParsing
    return $file
}

if ($onWindows) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetArgs = @('install', '--id', 'Microsoft.PowerShell', '--source', 'winget', '-e',
                        '--accept-package-agreements', '--accept-source-agreements')
        if ($installed) { $wingetArgs[0] = 'upgrade' }
        & winget @wingetArgs
    }
    else {
        $msi = Get-Asset "*win-$arch.msi"
        Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /passive ADD_PATH=1" -Verb RunAs -Wait
    }
}
elseif ($IsMacOS) {
    $brewCask = $false
    if (Get-Command brew -ErrorAction SilentlyContinue) {
        & brew list --cask powershell *> $null
        $brewCask = ($LASTEXITCODE -eq 0)
    }
    if ($brewCask) {
        & brew update
        & brew upgrade --cask powershell
    }
    else {
        $pkg = Get-Asset "*osx-$arch.pkg"
        Write-Host 'Installation benötigt Admin-Rechte (sudo) ...'
        & sudo installer -pkg $pkg -target /
    }
}
else {
    Write-Warning 'Nur Windows und macOS werden unterstützt.'
    return
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "Fertig. Neue Version: $(& pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')" -ForegroundColor Green
    Write-Host 'Bitte offene pwsh-Fenster (z. B. iTerm) neu starten.'
}
else {
    Write-Warning "Update meldete Exit-Code $LASTEXITCODE."
}
