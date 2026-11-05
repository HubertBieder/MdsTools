<#
.SYNOPSIS
    Committet alle lokalen Änderungen und pusht sie ins GitHub-Repository (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Für jedes Git-Repository unter Repos (macOS: ~/Repos, Windows: C:\woyCode):
      1. git add -A und commit (nur wenn es Änderungen gibt)
      2. git fetch und prüfen, ob der Server neuere Commits hat
         -> ja: kein Push, Hinweis auf CloneAll.ps1 (pull)
         -> nein: git push, falls lokale Commits vorhanden sind
    macOS/Linux: Repos ist der Ordner, in dem das Skript liegt (~/Repos).
    Windows:     feste Basis C:\woyCode, die Repos liegen direkt darin (wie CloneAll und $mdsRepos).
    $env:DEV_REPOS übersteuert.

.PARAMETER Repos
    Kurznamen (Ordner unter Repos). Standard: alle Git-Repositories unter Repos.

.PARAMETER Message
    Commit-Nachricht. Standard: "Update <Datum Uhrzeit> von <Rechner>"

.EXAMPLE
    ./PushAll.ps1
    ./PushAll.ps1 -Repos Net, Maui -Message "Neue Logging-Klasse"

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-10-29  Claude/Hubi   Erste Version, Windows + macOS
    2.0.0    2026-10-31  Hubi/Claude   Kurznamen, Standard = alle Repos unter ~/Dev/Repos
    2.1.0    2026-11-01  Hubi/Claude   DEV_HOME statt DEV_ROOT, DEV_REPOS
    2.2.0    2026-11-03  Hubi/Claude   Windows: Repos direkt in C:\woyCode statt C:\woyCode\Repos (wie CloneAll 3.2.0);
                                       Abbruch, wenn der Repos-Ordner fehlt
    2.3.0    2026-11-04  Hubi/Claude   Im Repo unter Modul/Skripte (statt Skripte)
    2.4.0    2026-11-05  Hubi/Claude   Ohne Dev-Ordner: Skript liegt direkt in Repos (~/Repos), DEV_HOME entfällt
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @(),
    [string]$Message
)

$ScriptVersion = '2.4.0'

$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or $IsWindows
$osName    = if ($onWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
$hostName  = [System.Net.Dns]::GetHostName()

# --- Repos bestimmen (gleiche Logik wie CloneAll.ps1 und InitModule.ps1 in MdsTools).
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

if (-not (Test-Path -LiteralPath $ReposDir -PathType Container)) {
    Write-Error "Repos-Ordner $ReposDir nicht gefunden - nichts zu tun."
    exit 1
}

if ($Repos.Count -eq 0) {
    $Repos = Get-ChildItem -Path $ReposDir -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName '.git') } |
        Select-Object -ExpandProperty Name
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error 'git wurde nicht gefunden. Bitte zuerst Git installieren.'
    exit 1
}
if (-not $Message) { $Message = "Update $(Get-Date -Format 'yyyy-MM-dd HH:mm') von $hostName" }

Write-Host "PushAll $ScriptVersion auf $hostName ($osName) - Repos: $ReposDir" -ForegroundColor Cyan
Write-Host "Commit-Nachricht: $Message"

$result = foreach ($repo in $Repos) {
    $target = Join-Path $ReposDir $repo
    Write-Host "`n=== $repo" -ForegroundColor Yellow

    if (-not (Test-Path (Join-Path $target '.git'))) {
        Write-Warning "$repo ist nicht vorhanden oder kein Git-Repository - übersprungen."
        [pscustomobject]@{ Repo = $repo; Commit = '-'; Push = 'Übersprungen (kein Repo)' }
        continue
    }

    # 1. Commit
    $commit = 'Keine Änderungen'
    if (git -C $target status --porcelain) {
        git -C $target add -A
        git -C $target commit -m $Message
        $commit = if ($LASTEXITCODE -eq 0) { 'Committet' } else { "FEHLER ($LASTEXITCODE)" }
    }

    # 2. Abgleich mit Server
    git -C $target fetch --quiet
    $upstream = git -C $target rev-parse --abbrev-ref '@{u}' 2>$null
    if (-not $upstream) {
        Write-Warning "$repo`: kein Upstream-Branch - kein Push. Einmalig: git -C $target push -u origin <Branch>"
        [pscustomobject]@{ Repo = $repo; Commit = $commit; Push = 'Kein Upstream' }
        continue
    }
    $behind = [int](git -C $target rev-list --count 'HEAD..@{u}' 2>$null)
    $ahead  = [int](git -C $target rev-list --count '@{u}..HEAD' 2>$null)

    if ($behind -gt 0) {
        Write-Warning "$repo`: Server hat $behind neuere Commits - kein Push. Erst CloneAll.ps1 (pull) ausführen."
        $push = "Nicht gepusht ($behind Commits hinterher)"
    }
    elseif ($ahead -gt 0) {
        git -C $target push
        $push = if ($LASTEXITCODE -eq 0) { "Gepusht ($ahead Commits)" } else { "FEHLER beim push ($LASTEXITCODE)" }
    }
    else {
        $push = 'Aktuell'
    }
    [pscustomobject]@{ Repo = $repo; Commit = $commit; Push = $push }
}

Write-Host ''
$result | Format-Table -AutoSize
