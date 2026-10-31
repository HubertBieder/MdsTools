<#
.SYNOPSIS
    Holt bzw. aktualisiert nur MdsTools nach Repos/Mds (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Ruft CloneAll.ps1 aus demselben Ordner mit -Repos Mds auf.
    Lokale, nicht committete Änderungen bleiben erhalten (Repo wird dann übersprungen).

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2025-01-28  Hubi          Erste Version (nur macOS, löscht und klont neu)
    2.0.0    2026-10-29  Claude/Hubi   Nutzt CloneAll.ps1, Windows + macOS, kein Löschen mehr
    3.0.0    2026-10-31  Hubi/Claude   MdsTools (Repos/Mds) statt mdsPackage
#>
[CmdletBinding()]
param()

$cloneAll = Join-Path $PSScriptRoot 'CloneAll.ps1'
if (-not (Test-Path $cloneAll)) {
    Write-Error "CloneAll.ps1 nicht gefunden in $PSScriptRoot"
    exit 1
}
& $cloneAll -Repos 'Mds'
