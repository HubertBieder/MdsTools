#Requires -Version 7.6
<#
.SYNOPSIS
    Installiert MdsTools, Profil und globale Skripte aus diesem Repo neu (run mds install).

.DESCRIPTION
    Globales run-Skript aus Mds/scripts, gilt von ueberall (run mds install, kurz run inst).
    Ruft Mds/Install.ps1 in einem eigenen pwsh-Prozess auf: Install.ps1 entlaedt und ersetzt das
    Modul MdsTools, aus dem run selbst gerade laeuft. Die laufende Sitzung bleibt so unberuehrt.

    Danach eine neue Shell oeffnen, damit Modul und Profil neu geladen werden.

.EXAMPLE
    run mds install

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-11-15  Hubi/Claude   Erste Version
#>
[CmdletBinding()]
param()

[string] $install = Join-Path (Split-Path $PSScriptRoot -Parent) 'Install.ps1'
if (-not (Test-Path -LiteralPath $install -PathType Leaf)) {
    Write-Fail "Install.ps1 nicht gefunden: $install"
    exit 1
}

& (Join-Path $PSHOME ($IsWindows ? 'pwsh.exe' : 'pwsh')) -NoProfile -File $install
# Install.ps1 meldet Erfolg und Abbruch selbst; ungleich 0 kommt nur bei einem Laufzeitfehler
[int] $rc = $LASTEXITCODE
if ($rc -ne 0) {
    Write-Fail "Install.ps1 mit Fehler beendet (Rueckgabe $rc)."
    exit $rc
}
