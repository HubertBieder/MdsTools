#Requires -Version 7.6
<#
.SYNOPSIS
    Installiert das Modul MdsTools, das Profil und die globalen Skripte fuer den aktuellen Benutzer.

.DESCRIPTION
    Laeuft unter PowerShell 7.6+ auf Windows (MARS) und macOS (LUNA).
      1. Modul/MdsTools      -> Benutzer-Modulordner (vorhandene Version wird ersetzt)
      2. Profile/profile.ps1 -> $PROFILE.CurrentUserAllHosts (vorher Sicherung *.bak)
      3. Modul/Skripte/*.ps1 -> $mdsRepos (nur wenn neuer); veraltete Skripte werden entfernt
      4. nur Windows: ~/.woy/woy.env einrichten (woy-Anmeldedaten)

.EXAMPLE
    ./Install.ps1

.NOTES
    Version  Datum       Wer           Was
    5.1                  H. Bieder     Installation mdsPackage
    6.0.0    2026-10-31  Hubi/Claude   Umstellung auf MdsTools (MdsTools.md, Schritt 5)
    6.1.0    2026-11-04  Hubi/Claude   Globale Skripte aus Modul/Skripte; Kopf-/Schlusszeile mit Modulversion
    6.2.0    2026-11-05  Hubi/Claude   Globale Skripte nach $mdsRepos ($mdsDev entfaellt, 8.3)
    6.3.0    2026-11-05  Hubi/Claude   Pruefung auf mdsPackage entfernt
#>
[CmdletBinding()]
param()

# Angezeigt wird die Modulversion aus dem Manifest im Repo (einzige Versionsnummer, A2).
$ModulVersion = (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'Modul/MdsTools/MdsTools.psd1')).ModuleVersion

# Repo-Wurzel = Ordner dieses Skripts (unabhaengig vom aktuellen Verzeichnis).
$script:RepoRoot = $PSScriptRoot

# Skripte, die frueher nach $mdsDev/$mdsRepos kopiert wurden und entfallen sind (E9: UpdatePS.ps1 -> Update-PowerShell).
$script:ObsoleteScripts = @('UpdatePS.ps1')

# Gemeinsame Pfad-Helfer: Get-UserHome, Get-ProfileRoot, Get-CurrentUserModuleDir
. (Join-Path $PSScriptRoot 'InstallHelper.ps1')

function Install-MdsModule() {
    $sourceDir = Join-Path $script:RepoRoot 'Modul/MdsTools'
    $targetDir = Join-Path (Get-CurrentUserModuleDir) 'MdsTools'
    Write-Host "---   von [$sourceDir] ==> [$targetDir]   -----------------------------"
    if (-not (Test-Path -Path $sourceDir -PathType Container)) {
        Write-Host -ForegroundColor Red "Quellverzeichnis fehlt: $sourceDir"
        return $false
    }
    Remove-Module MdsTools -ErrorAction SilentlyContinue
    if (Test-Path -Path $targetDir -PathType Container) {
        Remove-Item -Path $targetDir -Recurse -Force
    }
    Copy-Item -Path $sourceDir -Destination $targetDir -Force -Recurse
    if (Test-Path -Path (Join-Path $targetDir 'MdsTools.psd1') -PathType Leaf) {
        Write-Host -ForegroundColor blue "===>   Modul installiert: MdsTools $((Import-PowerShellDataFile (Join-Path $targetDir 'MdsTools.psd1')).ModuleVersion)   <==="
        return $true
    }
    return $false
}

function Copy-Profile() {
    $target = Join-Path (Get-ProfileRoot) 'profile.ps1'
    $source = Join-Path $script:RepoRoot 'Profile/profile.ps1'
    Write-Host "---   von [$source] ==> [$target]   -----------------------------"
    if (Test-Path -Path $target -PathType Leaf) {
        if ((Get-FileHash $target).Hash -eq (Get-FileHash $source).Hash) {
            Write-Host -ForegroundColor DarkYellow "profile.ps1 ist aktuell, bleibt unveraendert"
            return
        }
        $backup = "$target.$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
        Copy-Item -Path $target -Destination $backup -Force
        Write-Host -ForegroundColor DarkYellow "Bisheriges Profil gesichert: $backup"
    }
    Copy-Item -Path $source -Destination $target -Force
    Write-Host -ForegroundColor blue "===>   profile.ps1   <==="
}

# Kopiert die globalen Skripte nach $ReposDir, wenn sie dort fehlen oder aelter sind,
# und entfernt die nicht mehr gepflegten Skripte aus $script:ObsoleteScripts.
function Copy-GlobalScripts([string] $ReposDir) {
    foreach ($skript in Get-ChildItem -LiteralPath (Join-Path $script:RepoRoot 'Modul/Skripte') -Filter '*.ps1' -File) {
        $target = Join-Path $ReposDir $skript.Name
        if ((Test-Path -LiteralPath $target -PathType Leaf) -and
            ((Get-Item -LiteralPath $target).LastWriteTimeUtc -ge $skript.LastWriteTimeUtc)) {
            Write-Verbose "$($skript.Name) ist aktuell"
            continue
        }
        Copy-Item -LiteralPath $skript.FullName -Destination $target -Force
        Write-Host -ForegroundColor blue "===>   $($skript.Name) ==> $ReposDir   <==="
    }
    foreach ($name in $script:ObsoleteScripts) {
        $target = Join-Path $ReposDir $name
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force
            Write-Host -ForegroundColor DarkYellow "Veraltetes Skript entfernt: $target"
        }
    }
}

function Install-WoyEnv() {
    # Nur Windows: richtet den Runtime-Ort der woy-Anmeldedaten ein: %USERPROFILE%\.woy.
    # MdsSkripte/WoyEnv.ps1 (Get-WoyEnvPath) liest von dort.
    #   - woy.env: wird aus der Repo-.env angelegt bzw. aktualisiert, sobald die
    #     Repo-.env neuer ist als die vorhandene woy.env (sonst bleibt sie unberuehrt).
    #   - woy.env.example: Vorlage/Muster, wird immer aktualisiert.
    $woyDir = Join-Path (Get-UserHome) '.woy'
    if (-not (Test-Path -Path $woyDir -PathType Container)) {
        New-Item -Path $woyDir -ItemType Directory -Force | Out-Null
    }

    $exampleSrc = Join-Path $script:RepoRoot '.env.example'
    if (Test-Path -Path $exampleSrc -PathType Leaf) {
        $exampleDst = Join-Path $woyDir 'woy.env.example'
        Copy-Item -Path $exampleSrc -Destination $exampleDst -Force
        Write-Host -ForegroundColor blue "===>   Muster kopiert: $exampleDst   <==="
    }

    $envDst = Join-Path $woyDir 'woy.env'
    $envSrc = Join-Path $script:RepoRoot '.env'
    if (Test-Path -Path $envSrc -PathType Leaf) {
        $doCopy = $true
        if (Test-Path -Path $envDst -PathType Leaf) {
            $doCopy = (Get-Item -LiteralPath $envSrc).LastWriteTimeUtc -gt (Get-Item -LiteralPath $envDst).LastWriteTimeUtc
        }
        if ($doCopy) {
            Copy-Item -Path $envSrc -Destination $envDst -Force
            Write-Host -ForegroundColor blue "===>   woy.env aktualisiert (Repo-.env neuer): $envDst   <==="
        }
        else {
            Write-Host -ForegroundColor DarkYellow "woy.env ist aktuell, bleibt unveraendert: $envDst"
        }
    }
    elseif (Test-Path -Path $envDst -PathType Leaf) {
        Write-Host -ForegroundColor DarkYellow "Keine Repo-.env - vorhandene woy.env bleibt unveraendert: $envDst"
    }
    elseif (Test-Path -Path $exampleSrc -PathType Leaf) {
        Copy-Item -Path $exampleSrc -Destination $envDst -Force
        Write-Host -ForegroundColor DarkYellow "woy.env aus Vorlage erzeugt (Passwoerter eintragen!): $envDst"
    }
    else {
        Write-Host -ForegroundColor Yellow "Weder .env noch .env.example gefunden - woy.env nicht angelegt."
    }
}

Write-Host "================= MdsTools installieren ==========================  V$ModulVersion  ====="
if (-not (Install-MdsModule)) {
    Write-Host -ForegroundColor Red "Installation abgebrochen."
    return
}
Copy-Profile

# Modul laden: setzt $mdsRepos/$mdsRoot und legt die Root-Ordner an (Skripte/InitModule.ps1).
Import-Module MdsTools -Global -Force
Copy-GlobalScripts -ReposDir $mdsRepos
if ($IsWindows) {
    Install-WoyEnv
}

Write-Host ""
Write-Host "================= MdsTools installiert ===========================  V$ModulVersion  ====="
Write-Host ""
$modul = Get-Module MdsTools
Write-Host "Modul:        MdsTools $($modul.Version)  ($($modul.ModuleBase))"
Write-Host "Profil:       $(Join-Path (Get-ProfileRoot) 'profile.ps1')"
Write-Host "mdsRepos:     $mdsRepos"
Write-Host "mdsRoot:      $mdsRoot"
Write-Host "Neue PowerShell-Sitzung starten, damit das Profil geladen wird."
