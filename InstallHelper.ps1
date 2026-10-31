#======================================================================
# Datei:        InstallHelper.ps1  (wird von Install.ps1 und Uninstall.ps1 dot-gesourct)
# Beschreibung: Ermittelt Benutzer-Home, Profilordner und Benutzer-Modulordner
#               fuer Windows und macOS.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus Install.ps1 ausgelagert
#======================================================================

function Get-UserHome() {
    # In Domaenen mit Roaming-/Home-Verzeichnis kann $HOME (= HOMEDRIVE+HOMEPATH)
    # vom tatsaechlichen Profil abweichen. Massgeblich ist %USERPROFILE%.
    # Beispiel: als SCHWARTZ\Administrator angemeldet ->
    #   $HOME            = C:\Users\Administrator          (falsch, lokales Profil)
    #   $env:USERPROFILE = C:\Users\Administrator.SCHWARTZ (richtig)
    # Unter macOS ist USERPROFILE nicht gesetzt -> $HOME.
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE) -and (Test-Path -LiteralPath $env:USERPROFILE)) {
        return $env:USERPROFILE
    }
    return $HOME
}

function Get-ProfileRoot() {
    # Windows: ...\Documents\PowerShell   macOS: ~/.config/powershell
    $base = Split-Path $PROFILE.CurrentUserAllHosts
    # Zeigt der Profilpfad noch auf ein abweichendes $HOME (siehe Get-UserHome),
    # auf %USERPROFILE% umbiegen, damit Profil und Module im echten Profil landen.
    $userHome = Get-UserHome
    if ($HOME -and ($userHome -ne $HOME) -and $base.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $base.Substring($HOME.Length).TrimStart('\', '/')
        $base = Join-Path $userHome $rel
    }
    if (-not (Test-Path -Path $base -PathType Container)) {
        New-Item -Path $base -ItemType Directory -Force | Out-Null
    }
    return $base
}

function Get-CurrentUserModuleDir() {
    # Deterministisch ableiten statt aus PSModulePath[0]:
    #   Windows: ProfileRoot\Modules  (...\Documents\PowerShell\Modules)
    #   macOS:   ~/.local/share/powershell/Modules - dort sucht PowerShell CurrentUser-Module,
    #            NICHT unter ~/.config/powershell/Modules (Profilordner).
    if ($IsWindows) {
        $module = Join-Path (Get-ProfileRoot) 'Modules'
    }
    else {
        # Wie PowerShell selbst: $XDG_DATA_HOME, sonst ~/.local/share
        $dataHome = if ([string]::IsNullOrWhiteSpace($env:XDG_DATA_HOME)) { Join-Path $HOME '.local/share' } else { $env:XDG_DATA_HOME }
        $module = Join-Path $dataHome 'powershell/Modules'
    }
    if (-not (Test-Path -Path $module -PathType Container)) {
        New-Item -Path $module -ItemType Directory -Force | Out-Null
    }
    return $module
}
