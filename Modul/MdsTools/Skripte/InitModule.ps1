#======================================================================
# Datei:        InitModule.ps1  (ScriptsToProcess, laeuft VOR dem Laden des Moduls
#               im Bereich des Aufrufers - beim Profil also global)
# Beschreibung: Setzt die globalen mds-Variablen, legt fehlende Root-Ordner an,
#               nimmt $mdsBin in den PATH auf und laedt unter Windows MdsSkripte.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Neu fuer MdsTools (ersetzt Set-Global/woy-Variablen)
#======================================================================

# Native Programme (dotnet, git, ...) geben UTF-8 aus. Ohne UTF-8-Ausgabekodierung
# erscheinen Umlaute unter Windows falsch. Bei umgeleiteter Ausgabe kann der Setter werfen.
try {
    if (-not [Console]::IsOutputRedirected) {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    }
}
catch { }

# Globale Variablen (MdsTools.md, Abschnitt Globale Variablen). $env:DEV_ROOT uebersteuert $mdsDev.
$global:mdsVersion = [version](Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '../MdsTools.psd1')).ModuleVersion
$global:mdsDev = if ($env:DEV_ROOT) { $env:DEV_ROOT } else { Join-Path $HOME 'Dev' }
$global:mdsRepos = Join-Path $mdsDev 'Repos'
$global:mdsRoot = Join-Path $mdsDev 'Root'
$global:mdsBin = Join-Path $mdsRoot 'Bin'
$global:mdsConfig = Join-Path $mdsRoot 'Config'
$global:mdsData = Join-Path $mdsRoot 'Data'
$global:mdsLogs = Join-Path $mdsRoot 'Logs'
$global:mdsTemp = Join-Path $mdsRoot 'Temp'

foreach ($ordner in $mdsRepos, $mdsBin, $mdsConfig, $mdsData, $mdsLogs, $mdsTemp) {
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
