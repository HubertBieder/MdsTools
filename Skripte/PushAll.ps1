<#
.SYNOPSIS
    Committet alle lokalen Änderungen und pusht sie ins GitHub-Repository (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Für jedes Git-Repository unter ~/Dev/Repos:
      1. git add -A und commit (nur wenn es Änderungen gibt)
      2. git fetch und prüfen, ob der Server neuere Commits hat
         -> ja: kein Push, Hinweis auf CloneAll.ps1 (pull)
         -> nein: git push, falls lokale Commits vorhanden sind
    Root ist der Ordner, in dem das Skript liegt (~/Dev); $env:DEV_ROOT übersteuert.

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
#>
[CmdletBinding()]
param(
    [string[]]$Repos = @(),
    [string]$Message
)

$ScriptVersion = '2.0.0'

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
