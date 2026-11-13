#======================================================================
# Datei:        InitModule.ps1  (ScriptsToProcess, laeuft VOR dem Laden des Moduls
#               im Bereich des Aufrufers - beim Profil also global)
# Beschreibung: Setzt die globalen mds-Variablen, legt fehlende Root-Ordner an,
#               nimmt $mdsBin in den PATH auf und laedt unter Windows MdsSkripte.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Neu fuer MdsTools (ersetzt Set-Global/woy-Variablen)
#   2026-11-01  Hubi/Claude  DEV_HOME statt DEV_ROOT fuer ~/Dev; DEV_<Ordner> lenkt jeden Ordner um
#   2026-11-03  Hubi/Claude  Windows: feste Basis C:\woyCode, Repos und Root auf derselben Ebene
#   2026-11-03  Hubi/Claude  $mdsWoy (Windows 26, sonst 0)
#   2026-11-03  Hubi/Claude  Windows: Root auf D:\Dev\Root, wenn Laufwerk D: vorhanden, sonst C:\Dev\Root
#   2026-11-03  Hubi/Claude  Windows: Legacy-Adressen $mdsWoySrc, $mdsWoyBin, $mdsWoyRun
#   2026-11-05  Hubi/Claude  8.3: $mdsDev und DEV_HOME entfallen; Repos und Root unabhaengig
#                            (macOS ~/Repos, ~/Root; Windows C:\woyCode, D:\Root bzw. C:\Root)
#======================================================================

# Native Programme (dotnet, git, ...) geben UTF-8 aus. Ohne UTF-8-Ausgabekodierung
# erscheinen Umlaute unter Windows falsch. Bei umgeleiteter Ausgabe kann der Setter werfen.
try {
    if (-not [Console]::IsOutputRedirected) {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    }
}
catch { }

# Globale Variablen (MdsTools.md, Abschnitt Globale Variablen).
# Regel: $env:DEV_<NAME> lenkt genau den Ordner <Name> um (DEV_REPOS, DEV_ROOT, DEV_BIN, ...).
# Gleiche Logik wie die C#-Klasse xBase.BaseRoot im Repo Net (GitHub NetCoreLib2026).
function Get-DevOrdner([string]$Name, [string]$Basis) {
    $wert = [Environment]::GetEnvironmentVariable("DEV_$($Name.ToUpperInvariant())")
    if ($wert) { $wert } else { Join-Path $Basis $Name }
}
$global:mdsVersion = [version](Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '../MdsTools.psd1')).ModuleVersion
# 2026-11-03 Hubi/Claude: woy-Stand des Systems als Integer, getrennt von der Modulversion.
#   Windows (MARS): 26 = aktueller woy-Stand (woyCode); macOS/Linux: 0 = kein woy.
#   $mdsVersion ist dagegen auf allen Systemen gleich (Manifest).
$global:mdsWoy = [int]$(if ($IsWindows) { 26 } else { 0 })
# 2026-11-03 Hubi/Claude: Legacy-Adressen der Auftragsabwicklung, nur Windows (MARS), fest und absolut.
#   Es gibt keinen weiteren Rechner mit woy; die Pfade werden bewusst nicht abgeleitet oder angelegt.
#   $mdsWoySrc  Quellen der Auftragsabwicklung (Repo Auf)
#   $mdsWoyBin  Binaerdaten aus dem Uebersetzen (scripts/Make.ps1)
#   $mdsWoyRun  Zielverzeichnis der installierten Programme
#   Unter macOS/Linux gibt es diese Variablen nicht.
if ($IsWindows) {
    $global:mdsWoySrc = 'C:\woyCode\Auf'
    $global:mdsWoyBin = 'C:\woyCode\Auf\Bin'
    $global:mdsWoyRun = 'D:\woySystems\Bin'
}
# 2026-11-05 Hubi/Claude: Repos und Root unabhaengig, ohne gemeinsamen Elternordner (8.3).
#   macOS/Linux: $mdsRepos = ~/Repos, $mdsRoot = ~/Root
#   Windows:     $mdsRepos = C:\woyCode, $mdsRoot = D:\Root, wenn es ein Laufwerk D: gibt (MARS), sonst C:\Root.
#   Fehlende Ordner (Repos, Root, Bin, Config, ...) werden unten angelegt.
# DEV_<NAME> lenkt auf beiden Systemen genau den Ordner <Name> um.
if ($IsWindows) {
    $standardRepos = 'C:\woyCode'
    $standardRoot = if (Test-Path -LiteralPath 'D:\' -PathType Container) { 'D:\Root' } else { 'C:\Root' }
}
else {
    $standardRepos = Join-Path $HOME 'Repos'
    $standardRoot = Join-Path $HOME 'Root'
}
$global:mdsRepos = if ($env:DEV_REPOS) { $env:DEV_REPOS } else { $standardRepos }
$global:mdsRoot = if ($env:DEV_ROOT) { $env:DEV_ROOT } else { $standardRoot }
Remove-Variable standardRepos, standardRoot
$global:mdsBin = Get-DevOrdner 'Bin' $mdsRoot
$global:mdsConfig = Get-DevOrdner 'Config' $mdsRoot
$global:mdsData = Get-DevOrdner 'Data' $mdsRoot
$global:mdsLogs = Get-DevOrdner 'Logs' $mdsRoot
$global:mdsTemp = Get-DevOrdner 'Temp' $mdsRoot
Remove-Item Function:Get-DevOrdner

foreach ($ordner in $mdsRepos, $mdsRoot, $mdsBin, $mdsConfig, $mdsData, $mdsLogs, $mdsTemp) {
    if (-not (Test-Path -LiteralPath $ordner -PathType Container)) {
        $null = New-Item -Path $ordner -ItemType Directory -Force -ErrorAction SilentlyContinue
    }
}

# Tools aus Root/Bin ueberall aufrufbar machen (nur einmal eintragen).
if (($env:PATH -split [IO.Path]::PathSeparator) -notcontains $mdsBin) {
    $env:PATH = $mdsBin + [IO.Path]::PathSeparator + $env:PATH
}

# woy/Auftragsabwicklung nur unter Windows (MdsTools.md, Initialisierung Schritt 3).
if ($IsWindows) {
    $initMds = Join-Path $PSScriptRoot '../MdsSkripte/InitMDS.ps1'
    if (Test-Path -LiteralPath $initMds -PathType Leaf) {
        . $initMds
    }
    Remove-Variable initMds
}
Remove-Variable ordner -ErrorAction SilentlyContinue
