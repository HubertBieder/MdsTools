<#
.SYNOPSIS
    Holt bzw. aktualisiert die Entwicklungs-Repositories (macOS: ~/Repos, Windows: C:\woyCode).

.DESCRIPTION
    Für jedes Repository aus der Repo-Tabelle (GitHub-Name -> lokaler Kurzname):
      - nicht vorhanden          -> git clone nach Repos/<Kurzname>
      - vorhanden, sauber        -> git pull --ff-only
      - vorhanden, mit lokalen Änderungen -> Warnung, wird übersprungen (nichts wird gelöscht)
    Wurde Mds neu geklont oder hat der pull neue Commits geholt, läuft danach sofort Mds/Install.ps1.
    macOS/Linux: Repos ist der Ordner, in dem das Skript liegt (~/Repos).
    Windows:     feste Basis C:\woyCode, die Repos liegen direkt darin (wie $mdsRepos in MdsTools).
    $env:DEV_REPOS übersteuert.

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
    3.1.0    2026-11-01  Hubi/Claude   DEV_HOME statt DEV_ROOT, DEV_REPOS
    3.2.0    2026-11-03  Hubi/Claude   Windows: Repos direkt in C:\woyCode statt C:\woyCode\Repos;
                                       Zielverzeichnis am Ende ausgeben
    3.3.0    2026-11-04  Hubi/Claude   Im Repo unter Modul/Skripte (statt Skripte)
    3.4.0    2026-11-05  Hubi/Claude   Ohne Dev-Ordner: Skript liegt direkt in Repos (~/Repos), DEV_HOME entfällt
    3.5.0    2026-11-06  Hubi/Claude   Mds geändert (neu geklont oder neue Commits) -> sofort Mds/Install.ps1;
                                       Status 'Aktuell', wenn der pull nichts geholt hat
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @()
)

$ScriptVersion = '3.5.0'
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

# --- Repos bestimmen (gleiche Logik wie InitModule.ps1 in MdsTools).
#     Windows: feste Basis C:\woyCode, Repos direkt darin.
#     macOS/Linux: Ordner des Skripts (~/Repos); laeuft es direkt aus dem Repo (Repos/Mds/Modul/Skripte),
#     drei Ebenen nach oben.
#     $env:DEV_REPOS uebersteuert. ---
if ($onWindows) {
    $ReposDir = if ($env:DEV_REPOS) { $env:DEV_REPOS } else { 'C:\woyCode' }
}
else {
    $ReposDir = $PSScriptRoot
    # 2026-11-04 Hubi/Claude: Skripte liegen im Repo unter Modul/Skripte (Repos/Mds/Modul/Skripte)
    if ((Split-Path $ReposDir -Leaf) -eq 'Skripte' -and (Split-Path (Split-Path $ReposDir -Parent) -Leaf) -eq 'Modul') {
        $ReposDir = Split-Path (Split-Path (Split-Path $ReposDir -Parent) -Parent) -Parent
    }
    if ($env:DEV_REPOS) { $ReposDir = $env:DEV_REPOS }
}

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

# Wird auf $true gesetzt, wenn Mds neu geklont wurde oder der pull neue Commits geholt hat.
$mdsGeaendert = $false

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
        $vorher = git -C $target rev-parse HEAD
        git -C $target pull --ff-only
        if ($LASTEXITCODE -ne 0) {
            $status = "FEHLER beim pull ($LASTEXITCODE)"
        }
        elseif ((git -C $target rev-parse HEAD) -ne $vorher) {
            $status = 'Aktualisiert (pull)'
            if ($kurz -eq 'Mds') { $mdsGeaendert = $true }
        }
        else {
            $status = 'Aktuell'
        }
    }
    elseif (Test-Path $target) {
        Write-Warning "$target existiert, ist aber kein Git-Repository - übersprungen."
        $status = 'Übersprungen (kein Git-Repo)'
    }
    else {
        git clone "$GitHubBase$repo.git" $target
        $status = if ($LASTEXITCODE -eq 0) { 'Neu geklont' } else { "FEHLER beim clone ($LASTEXITCODE)" }
        if ($LASTEXITCODE -eq 0 -and $kurz -eq 'Mds') { $mdsGeaendert = $true }
    }
    [pscustomobject]@{ Repo = $kurz; GitHub = $repo; Status = $status }
}

Write-Host ''
$result | Format-Table -AutoSize | Out-Host
Write-Host "Zielverzeichnis: $ReposDir" -ForegroundColor Cyan

# --- Mds geaendert: MdsTools sofort neu installieren (Modul, Profil, globale Skripte) ---
# 2026-11-06 Hubi/Claude: erstellt
if ($mdsGeaendert) {
    $install = Join-Path (Join-Path $ReposDir 'Mds') 'Install.ps1'
    Write-Host "`nMds wurde geändert - $install wird ausgeführt." -ForegroundColor Cyan
    if ($PSVersionTable.PSVersion -lt [version]'7.6') {
        Write-Warning "Install.ps1 braucht PowerShell 7.6 - bitte in pwsh ausführen: $install"
    }
    elseif (-not (Test-Path -LiteralPath $install -PathType Leaf)) {
        Write-Warning "$install nicht gefunden."
    }
    else {
        & $install
    }
}
