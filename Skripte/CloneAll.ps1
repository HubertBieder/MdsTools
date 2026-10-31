<#
.SYNOPSIS
    Holt bzw. aktualisiert die Entwicklungs-Repositories unter woyCode (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Für jedes Repository:
      - nicht vorhanden          -> git clone
      - vorhanden, sauber        -> git pull --ff-only
      - vorhanden, mit lokalen Änderungen -> Warnung, wird übersprungen (nichts wird gelöscht)
    Root ist der Ordner, in dem das Skript liegt. Liegt es in mdsPackage/MacUtils,
    wird automatisch zwei Ebenen nach oben (woyCode) gewechselt.

.PARAMETER Repos
    Liste der Repositories. Standard: mdsPackage, NetCoreLib2026, NetMauiApps, PythonHB

.EXAMPLE
    ./CloneAll.ps1
    ./CloneAll.ps1 -Repos NetMauiApps

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-01-14  Hubi          Erste Version (nur macOS, löscht und klont neu)
    2.0.0    2026-10-29  Claude/Hubi   Windows + macOS, pull statt löschen, Schutz lokaler Änderungen,
                                       neue Repo-Liste, Root aus Skriptpfad
    2.1.0    2026-10-29  Claude/Hubi   GitHub-User HubertBieder fest in der URL, Prüfung Credential-Helper
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @('mdsPackage', 'NetCoreLib2026', 'NetMauiApps', 'PythonHB')
)

$ScriptVersion = '2.1.0'
$GitHubUser    = 'HubertBieder'
$GitHubBase    = "https://$GitHubUser@github.com/$GitHubUser/"

# --- Betriebssystem erkennen (auch Windows PowerShell 5.1) ---
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$osName    = if ($onWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
$hostName  = [System.Net.Dns]::GetHostName()

# --- Root bestimmen ---
$Root = $PSScriptRoot
if ((Split-Path $Root -Leaf) -eq 'MacUtils') { $Root = Split-Path (Split-Path $Root -Parent) -Parent }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'git wurde nicht gefunden. Bitte zuerst Git installieren.'
    exit 1
}

# --- Anmeldung bei GitHub: ohne Credential-Helper fragt git jedes Mal nach User/Token ---
$helper = git config --get credential.helper
if (-not $helper) {
    Write-Warning ('Kein git credential.helper konfiguriert - git wird nach Benutzer/Token fragen. ' +
                   'Einmalig einrichten: "gh auth login" und "gh auth setup-git" (GitHub CLI) ' +
                   'oder Git Credential Manager installieren.')
}

Write-Host "CloneAll $ScriptVersion auf $hostName ($osName) - Root: $Root" -ForegroundColor Cyan

$result = foreach ($repo in $Repos) {
    $target = Join-Path $Root $repo
    Write-Host "`n=== $repo" -ForegroundColor Yellow

    if (Test-Path (Join-Path $target '.git')) {
        $dirty = git -C $target status --porcelain
        if ($dirty) {
            Write-Warning "$repo hat lokale Änderungen ($(@($dirty).Count) Dateien) - übersprungen. Erst committen (PushAll.ps1)."
            [pscustomobject]@{ Repo = $repo; Status = 'Übersprungen (lokale Änderungen)' }
            continue
        }
        git -C $target pull --ff-only
        $status = if ($LASTEXITCODE -eq 0) { 'Aktualisiert (pull)' } else { "FEHLER beim pull ($LASTEXITCODE)" }
    }
    elseif (Test-Path $target) {
        Write-Warning "$target existiert, ist aber kein Git-Repository - übersprungen."
        $status = 'Übersprungen (kein Git-Repo)'
    }
    else {
        git clone "$GitHubBase$repo.git" $target
        $status = if ($LASTEXITCODE -eq 0) { 'Neu geklont' } else { "FEHLER beim clone ($LASTEXITCODE)" }
    }
    [pscustomobject]@{ Repo = $repo; Status = $status }
}

Write-Host ''
$result | Format-Table -AutoSize
