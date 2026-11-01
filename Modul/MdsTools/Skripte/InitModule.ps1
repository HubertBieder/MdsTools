#======================================================================
# Datei:        InitModule.ps1  (ScriptsToProcess, laeuft VOR dem Laden des Moduls
#               im Bereich des Aufrufers - beim Profil also global)
# Beschreibung: Setzt die globalen mds-Variablen, legt fehlende Root-Ordner an,
#               nimmt $mdsBin in den PATH auf und laedt unter Windows MdsSkripte.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Neu fuer MdsTools (ersetzt Set-Global/woy-Variablen)
#   2026-11-01  Hubi/Claude  DEV_HOME statt DEV_ROOT fuer ~/Dev; DEV_<Ordner> lenkt jeden Ordner um
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
# Regel: $env:DEV_<NAME> lenkt genau den Ordner <Name> um (DEV_HOME = ~/Dev, DEV_ROOT = ~/Dev/Root).
# Gleiche Logik wie die C#-Klasse xBase.BaseRoot in NetCoreLib2026.
function Get-DevOrdner([string]$Name, [string]$Basis) {
    $wert = [Environment]::GetEnvironmentVariable("DEV_$($Name.ToUpperInvariant())")
    if ($wert) { $wert } else { Join-Path $Basis $Name }
}
$global:mdsVersion = [version](Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '../MdsTools.psd1')).ModuleVersion
$global:mdsDev = if ($env:DEV_HOME) { $env:DEV_HOME } else { Join-Path $HOME 'Dev' }
$global:mdsRepos = Get-DevOrdner 'Repos' $mdsDev
$global:mdsRoot = Get-DevOrdner 'Root' $mdsDev
$global:mdsBin = Get-DevOrdner 'Bin' $mdsRoot
$global:mdsConfig = Get-DevOrdner 'Config' $mdsRoot
$global:mdsData = Get-DevOrdner 'Data' $mdsRoot
$global:mdsLogs = Get-DevOrdner 'Logs' $mdsRoot
$global:mdsTemp = Get-DevOrdner 'Temp' $mdsRoot
Remove-Item Function:Get-DevOrdner

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
