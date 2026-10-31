<#
.SYNOPSIS
    Holt bzw. aktualisiert die Entwicklungs-Repositories unter ~/Dev/Repos (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Für jedes Repository aus der Repo-Tabelle (GitHub-Name -> lokaler Kurzname):
      - nicht vorhanden          -> git clone nach Repos/<Kurzname>
      - vorhanden, sauber        -> git pull --ff-only
      - vorhanden, mit lokalen Änderungen -> Warnung, wird übersprungen (nichts wird gelöscht)
    Root ist der Ordner, in dem das Skript liegt (~/Dev); $env:DEV_ROOT übersteuert.

.PARAMETER Repos
    Kurznamen oder GitHub-Namen. Standard: alle aus der Repo-Tabelle (Mds, Net, Maui, PHB).

.EXAMPLE
    ./CloneAll.ps1
    ./CloneAll.ps1 -Repos Maui
    ./CloneAll.ps1 -Repos NetMauiApps

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-01-14  Hubi          Erste Version (nur macOS, löscht und klont neu)
    2.0.0    2026-10-29  Claude/Hubi   Windows + macOS, pull statt löschen, Schutz lokaler Änderungen,
                                       neue Repo-Liste, Root aus Skriptpfad
    2.1.0    2026-10-29  Claude/Hubi   GitHub-User HubertBieder fest in der URL, Prüfung Credential-Helper
    3.0.0    2026-10-31  Hubi/Claude   Repo-Tabelle mit Kurznamen, Ziel ~/Dev/Repos, MdsTools statt mdsPackage
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @()
)

$ScriptVersion = '3.0.0'
$GitHubUser    = 'HubertBieder'
$GitHubBase    = "https://$GitHubUser@github.com/$GitHubUser/"

# --- Repo-Tabelle: GitHub-Repo -> lokaler Kurzname (MDS-Development.md) ---
$RepoTable = [ordered]@{
    'MdsTools'       = 'Mds'
    'NetCoreLib2026' = 'Net'
    'NetMauiApps'    = 'Maui'
    'PythonHB'       = 'PHB'
}

# --- Betriebssystem erkennen (auch Windows PowerShell 5.1) ---
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$osName    = if ($onWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
$hostName  = [System.Net.Dns]::GetHostName()

# --- Root bestimmen: Ordner des Skripts (~/Dev). Laeuft es direkt aus dem Repo
#     (Repos/Mds/Skripte), drei Ebenen nach oben. $env:DEV_ROOT uebersteuert. ---
$Root = $PSScriptRoot
if ((Split-Path $Root -Leaf) -eq 'Skripte' -and (Split-Path (Split-Path (Split-Path $Root -Parent) -Parent) -Leaf) -eq 'Repos') {
    $Root = Split-Path (Split-Path (Split-Path $Root -Parent) -Parent) -Parent
}
if ($env:DEV_ROOT) { $Root = $env:DEV_ROOT }
$ReposDir = Join-Path $Root 'Repos'

# --- Auswahl: Kurz- oder GitHub-Namen auf Tabelleneinträge abbilden ---
$auswahl = [ordered]@{}
if ($Repos.Count -eq 0) {
    foreach ($key in $RepoTable.Keys) { $auswahl[$key] = $RepoTable[$key] }
}
foreach ($name in $Repos) {
    $treffer = $RepoTable.Keys | Where-Object { $_ -eq $name -or $RepoTable[$_] -eq $name } | Select-Object -First 1
    if ($treffer) {
        $auswahl[$treffer] = $RepoTable[$treffer]
    }
    else {
        Write-Warning "Unbekanntes Repo '$name'. Bekannt: $(($RepoTable.Values) -join ', ')"
    }
}

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

if (-not (Test-Path $ReposDir)) {
    New-Item -Path $ReposDir -ItemType Directory -Force | Out-Null
}

Write-Host "CloneAll $ScriptVersion auf $hostName ($osName) - Repos: $ReposDir" -ForegroundColor Cyan

$result = foreach ($repo in $auswahl.Keys) {
    $kurz   = $auswahl[$repo]
    $target = Join-Path $ReposDir $kurz
    Write-Host "`n=== $kurz ($repo)" -ForegroundColor Yellow

    if (Test-Path (Join-Path $target '.git')) {
        $dirty = git -C $target status --porcelain
        if ($dirty) {
            Write-Warning "$kurz hat lokale Änderungen ($(@($dirty).Count) Dateien) - übersprungen. Erst committen (PushAll.ps1)."
            [pscustomobject]@{ Repo = $kurz; GitHub = $repo; Status = 'Übersprungen (lokale Änderungen)' }
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
    [pscustomobject]@{ Repo = $kurz; GitHub = $repo; Status = $status }
}

Write-Host ''
$result | Format-Table -AutoSize
