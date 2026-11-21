<#
.SYNOPSIS
    Holt bzw. aktualisiert nur woyV26 (Auftragsabwicklung, WinForms) nach Repos/Auf (Windows/MARS und macOS/LUNA).

.DESCRIPTION
    Ruft CloneAll.ps1 aus demselben Ordner mit -Repos Auf auf.
    Lokale, nicht committete Änderungen bleiben erhalten (Repo wird dann übersprungen).

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-11-21  Hubi/Claude   Erste Version, analog CloneNetLib.ps1 (nutzt CloneAll 3.7.0)
#>
[CmdletBinding()]
param()

$cloneAll = Join-Path $PSScriptRoot 'CloneAll.ps1'
if (-not (Test-Path $cloneAll)) {
    Write-Error "CloneAll.ps1 nicht gefunden in $PSScriptRoot"
    exit 1
}
& $cloneAll -Repos 'Auf'
