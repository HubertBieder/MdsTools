<#
.SYNOPSIS
    Holt bzw. aktualisiert nur NetCoreLib2026 nach Repos/Net (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Ruft CloneAll.ps1 aus demselben Ordner mit -Repos Net auf.
    Lokale, nicht committete Änderungen bleiben erhalten (Repo wird dann übersprungen).

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-10-30  Claude/Hubi   Erste Version, analog CloneMDS.ps1 (nutzt CloneAll.ps1)
    1.1.0    2026-10-31  Hubi/Claude   Kurzname statt GitHub-Name (CloneAll 3.0.0)
#>
[CmdletBinding()]
param()

$cloneAll = Join-Path $PSScriptRoot 'CloneAll.ps1'
if (-not (Test-Path $cloneAll)) {
    Write-Error "CloneAll.ps1 nicht gefunden in $PSScriptRoot"
    exit 1
}
& $cloneAll -Repos 'Net'
