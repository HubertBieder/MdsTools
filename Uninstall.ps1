#Requires -Version 7.0
<#
.SYNOPSIS
    Entfernt alte Installationen von mdsPackage und MdsTools fuer den aktuellen Benutzer.

.DESCRIPTION
    Laeuft unter PowerShell 7 auf Windows (MARS) und macOS (LUNA).
      1. Module mdsPackage und MdsTools aus der Sitzung entladen
      2. Modulordner mdsPackage und MdsTools in allen Benutzer-Modulpfaden loeschen
         (Benutzer-Modulordner sowie alle PSModulePath-Eintraege unterhalb des Benutzer-Homes)
      3. Profildateien sichern und entfernen:
           mdsProfile.ps1                 immer
           profile.ps1                    nur, wenn es mdsPackage oder MdsTools laedt
      Die Sicherung liegt unter <Root>/Archiv/Uninstall-<Datum-Uhrzeit>.
    Modulordner in maschinenweiten Pfaden werden nur gemeldet, nicht geloescht.
    Danach kann mit Install.ps1 neu installiert werden.

.PARAMETER KeepMdsTools
    Nur mdsPackage entfernen, MdsTools und ein Profil, das MdsTools laedt, bleiben erhalten.

.EXAMPLE
    ./Uninstall.ps1 -WhatIf
    ./Uninstall.ps1
    ./Uninstall.ps1 -KeepMdsTools

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-10-31  Hubi/Claude   Erste Version (MdsTools.md, Schritt 6)
    1.0.1    2026-11-01  Hubi/Claude   DEV_HOME statt DEV_ROOT
    1.1.0    2026-11-04  Hubi/Claude   Kopf-/Schlusszeile mit Modulversion
    1.2.0    2026-11-05  Hubi/Claude   Sicherung unter <Root>/Archiv statt <Dev>/Archiv (DEV_HOME entfaellt, 8.3)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch] $KeepMdsTools
)

# Angezeigt wird die Modulversion aus dem Manifest im Repo (einzige Versionsnummer, A2).
$ModulVersion = (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'Modul/MdsTools/MdsTools.psd1')).ModuleVersion

# Gemeinsame Pfad-Helfer: Get-UserHome, Get-ProfileRoot, Get-CurrentUserModuleDir
. (Join-Path $PSScriptRoot 'InstallHelper.ps1')

$moduleNames = if ($KeepMdsTools) { @('mdsPackage') } else { @('mdsPackage', 'MdsTools') }
# Root wie InitModule.ps1 (das Modul ist hier evtl. nicht geladen): DEV_ROOT, sonst
# Windows D:\Root bzw. C:\Root, macOS/Linux ~/Root.
$rootDir = if ($env:DEV_ROOT) { $env:DEV_ROOT }
elseif (-not $IsWindows) { Join-Path (Get-UserHome) 'Root' }
elseif (Test-Path -LiteralPath 'D:\' -PathType Container) { 'D:\Root' }
else { 'C:\Root' }
$backupDir = Join-Path $rootDir "Archiv/Uninstall-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

# Verschiebt eine Datei in den Sicherungsordner (statt sie zu loeschen).
function Move-ToBackup {
    [CmdletBinding(SupportsShouldProcess)]
    param([string] $Path)
    if (-not $PSCmdlet.ShouldProcess($Path, "Sichern nach $backupDir und entfernen")) {
        return
    }
    if (-not (Test-Path -LiteralPath $backupDir -PathType Container)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    Move-Item -LiteralPath $Path -Destination (Join-Path $backupDir (Split-Path $Path -Leaf)) -Force
    Write-Host -ForegroundColor DarkYellow "Gesichert und entfernt: $Path"
}

Write-Host "================= mdsPackage/MdsTools entfernen ==================  V$ModulVersion  ====="

# 1. Aus der Sitzung entladen
Remove-Module -Name $moduleNames -Force -ErrorAction SilentlyContinue

# 2. Modulordner loeschen. Benutzerpfade: eigener Modulordner + PSModulePath-Eintraege unter dem Home.
$userHome = Get-UserHome
$userPaths = @(Get-CurrentUserModuleDir) + @($env:PSModulePath -split [IO.Path]::PathSeparator |
        Where-Object { $_ -and $_.StartsWith($userHome, [System.StringComparison]::OrdinalIgnoreCase) })
$userPaths = $userPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    ForEach-Object { (Resolve-Path -LiteralPath $_).Path.TrimEnd('/', '\') } | Sort-Object -Unique

$removed = 0
foreach ($path in $userPaths) {
    foreach ($name in $moduleNames) {
        $dir = Join-Path $path $name
        if ((Test-Path -LiteralPath $dir -PathType Container) -and $PSCmdlet.ShouldProcess($dir, 'Modulordner loeschen')) {
            Remove-Item -LiteralPath $dir -Recurse -Force
            Write-Host -ForegroundColor blue "===>   Modul entfernt: $dir   <==="
            $removed++
        }
    }
}

# Maschinenweite Installationen nur melden (Loeschen braucht Adminrechte und betrifft alle Benutzer).
foreach ($modul in Get-Module -ListAvailable -Name $moduleNames) {
    $imBenutzerpfad = $userPaths | Where-Object { $modul.ModuleBase.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }
    if ($imBenutzerpfad) {
        continue
    }
    Write-Warning "Weiterhin installiert (nicht im Benutzerpfad, bitte von Hand entfernen): $($modul.ModuleBase)"
}

# 3. Profildateien sichern und entfernen
$profileRoot = Get-ProfileRoot
$mdsProfile = Join-Path $profileRoot 'mdsProfile.ps1'
if (Test-Path -LiteralPath $mdsProfile -PathType Leaf) {
    Move-ToBackup $mdsProfile
}
$profileFile = Join-Path $profileRoot 'profile.ps1'
if (Test-Path -LiteralPath $profileFile -PathType Leaf) {
    $pattern = if ($KeepMdsTools) { 'mdsPackage' } else { 'mdsPackage|MdsTools' }
    if (Select-String -LiteralPath $profileFile -Pattern $pattern -Quiet) {
        Move-ToBackup $profileFile
    }
}

Write-Host ""
Write-Host "================= entfernt =======================================  V$ModulVersion  ====="
Write-Host "Modulordner entfernt: $removed"
if (Test-Path -LiteralPath $backupDir) {
    Write-Host "Sicherung:            $backupDir"
}
Write-Host "Neu installieren mit: $(Join-Path $PSScriptRoot 'Install.ps1')"
