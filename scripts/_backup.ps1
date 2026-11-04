#Requires -Version 7.6
<#
.SYNOPSIS
    Sichert ein Repo als datierte ZIP (run backup / run back) und gibt die Ziel-ZIP aus.

.DESCRIPTION
    Globales run-Skript aus Mds/scripts, gilt von ueberall:
      - mit Repo-Name:       dieses Repo unter $mdsRepos (z. B. run back Net)
      - im Repo-Ordner:      das aktuelle Repo (auch aus Unterordnern)
      - ausserhalb der Repos (z. B. in Dev): das Repo Mds
    Ruft Backup-Develop auf. Ohne -Force bleibt ein vorhandenes Tagesarchiv <Repo>_yyyyMMdd.zip
    unveraendert, mit -Force wird es neu erstellt. -Verbose wird an Backup-Develop durchgereicht.
    Ziel: OneDrive-*_Backup, sonst <Laufwerk>\_Backup bzw. $mdsRoot/Backup (siehe Backup-Develop).
    Am Ende stehen Pfad und Groesse der ZIP.

.PARAMETER Repo
    Kurzname des Repos unter $mdsRepos (Gross-/Kleinschreibung egal). Standard: aktuelles Repo, sonst Mds.

.PARAMETER Force
    Erzwingt ein neues Backup, auch wenn das Tagesarchiv schon existiert.

.EXAMPLE
    run back                  (aktuelles Repo; in Dev: Mds)
    run backup Net -Force     (Net neu sichern)
    run back -Verbose

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-11-03  Hubi/Claude   Erste Version (Repo Auf, immer -Force -Verbose)
    2.0.0    2026-11-04  Hubi/Claude   Globales Skript in Mds/scripts: Repo per Argument, aktuelles Repo
                                       oder Mds; -Force und -Verbose nur auf Wunsch
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Repo = '',

    [switch] $Force
)

# Repo-Wurzel ermitteln: Argument, sonst aktuelles Repo unter $mdsRepos, sonst Mds (Ordner dieses Skripts).
$reposDir = [IO.Path]::GetFullPath($mdsRepos).TrimEnd([char]'/', [char]'\')
if ($Repo) {
    $ordner = Get-ChildItem -LiteralPath $reposDir -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $Repo -and (Test-Path -LiteralPath (Join-Path $_.FullName '.git')) } |
        Select-Object -First 1
    if (-not $ordner) {
        $gueltig = Get-ChildItem -LiteralPath $reposDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } | Select-Object -ExpandProperty Name
        Write-Fail "Kein Repo '$Repo' unter $reposDir. Gültig: $($gueltig -join ', ')"
        exit 1
    }
    $quelle = $ordner.FullName
}
else {
    $quelle = Split-Path $PSScriptRoot -Parent
    $hier = (Get-Location).ProviderPath.TrimEnd([char]'/', [char]'\') + [IO.Path]::DirectorySeparatorChar
    $basis = $reposDir + [IO.Path]::DirectorySeparatorChar
    if ($hier.StartsWith($basis, [StringComparison]::OrdinalIgnoreCase)) {
        $name = $hier.Substring($basis.Length).Split([char[]]@('/', '\'), [StringSplitOptions]::RemoveEmptyEntries)[0]
        $kandidat = Join-Path $reposDir $name
        if (Test-Path -LiteralPath (Join-Path $kandidat '.git')) {
            $quelle = $kandidat
        }
    }
}

$verbose = $PSBoundParameters['Verbose'] -eq $true
Write-Info "Backup von $quelle$(if ($Force) { ' (-Force: neu erstellen)' })"

# Backup-Develop liefert den Pfad der ZIP (ohne -Force auch ein bereits vorhandenes Tagesarchiv),
# $null wenn kein Backup entstanden ist. Modulfunktionen sehen $VerbosePreference des Skripts nicht,
# deshalb -Verbose ausdruecklich weitergeben.
$zip = Backup-Develop -SourceDir $quelle -Force:$Force -Verbose:$verbose
# MdsTools vor 8.2 liefert "Updated ... with n files" und $true statt des Pfads
if ($null -ne $zip -and $zip -isnot [string]) {
    Write-Fail "Backup-Develop liefert keinen Pfad (installiertes MdsTools ist zu alt) - bitte Install.ps1 im Mds-Repo ausfuehren"
    exit 1
}
if (-not $zip) {
    Write-Fail "Backup von $quelle nicht erstellt"
    exit 1
}
$datei = Get-Item -LiteralPath $zip
$groesse = $datei.Length / 1MB
if (-not $Force -and $datei.LastWriteTime -lt (Get-Date).AddMinutes(-1)) {
    Write-Info ("Tagesarchiv bereits vorhanden: {0} ({1:N1} MB) - mit -Force neu erstellen" -f $zip, $groesse)
}
else {
    Write-Success ("Backup: {0} ({1:N1} MB)" -f $zip, $groesse)
}
