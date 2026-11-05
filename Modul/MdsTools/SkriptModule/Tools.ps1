#======================================================================
# Datei:        Tools.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Anzeigen und Aktualisieren von PowerShell 7 und .NET-SDK (Windows und macOS);
#               Anzeige der mds-Variablen (Show-Mds).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (SkriptModule\*.psm1) uebernommen,
#                            Cmdlets umbenannt (siehe MdsTools.md, Umbenennungen)
#   2026-11-03  Hubi/Claude  Show-Mds
#   2026-11-03  Hubi/Claude  Show-Mds: Zeile System, Windows-Zeilen mdsWoySrc/Bin/Run
#   2026-11-04  Hubi/Claude  Show-Mds -Full (-F): zusaetzlich alle externen Befehle
#   2026-11-04  Hubi/Claude  Update-PowerShell: unter Windows nur Anzeige, Installation ueber
#                            Update-PowerShell7.cmd (Windows PowerShell 5.1); Install-PowerShell7FromGithub entfaellt
#   2026-11-05  Hubi/Claude  Show-Mds: Zeile mdsDev entfaellt (8.3)
#
# Oeffentlich: Update-DotNet, Update-PowerShell, Show-PowerShell, Show-Mds
#======================================================================

# [intern] Ermittelt die hoechste im winget-Repository verfuegbare Version eines Pakets.
#   PackageId  winget-Paket-ID
# Rueckgabewert: [version] der neuesten verfuegbaren Version, sonst [version]"0.0.0".
function Get-WingetAvailableVersion {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "winget-Paket-ID")]
        [string] $PackageId
    )

    try {
        # --source winget: Mehrdeutigkeit mit der msstore-Quelle vermeiden.
        # ANSI/VT-Codes entfernen: neuere winget-Versionen geben Steuerzeichen aus
        # (auch mit --disable-interactivity), sonst matcht die Version-Zeile nicht.
        $ausgabe = winget show --id $PackageId --exact --source winget `
            --accept-source-agreements --disable-interactivity 2>$null |
            ForEach-Object { $_ -replace '\x1b\[[0-9;?]*[A-Za-z]', '' }
        # "Version: 7.6.3" (Ressourcen geladen) oder "ShowLabelVersion 7.6.3" (roher Schluessel).
        $verZeile = $ausgabe | Where-Object { $_ -match '(?i)^\s*(ShowLabel)?Version\b' } | Select-Object -First 1
        if ($verZeile -and $verZeile -match '([0-9]+(\.[0-9]+)+)') {
            return [version]$Matches[1]
        }
    }
    catch { }

    return [version]"0.0.0"
}

# [intern] Ermittelt die hoechste veroeffentlichte Version ueber die GitHub-Releases-API.
# Sinnvoll, wenn der winget-Index hinterherhinkt (z. B. PowerShell 7.6.3 auf GitHub,
# in winget aber noch 7.6.2).
#   Repository  GitHub-Repository "Besitzer/Repo"
function Get-GithubLatestVersion {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "GitHub-Repository in der Form 'Besitzer/Repo'")]
        [string] $Repository
    )

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" `
            -Headers @{ 'User-Agent' = 'MdsTools' } -TimeoutSec 10
        if ($release.tag_name -and $release.tag_name -match '([0-9]+(\.[0-9]+)+)') {
            return [version]$Matches[1]
        }
    }
    catch { }

    return [version]"0.0.0"
}

# [intern] Ermittelt die Version der installierten pwsh (nicht der laufenden Sitzung).
# Windows: maschinenweite Installation unter Program Files; sonst pwsh aus dem PATH.
# Rueckgabewert: [version], [version]"0.0.0" wenn nicht ermittelbar.
function Get-InstalledPwshVersion {
    try {
        if ($IsWindows) {
            $pwshExe = "C:\Program Files\PowerShell\7\pwsh.exe"
            if (Test-Path -LiteralPath $pwshExe) {
                return [version]((Get-Item -LiteralPath $pwshExe).VersionInfo.ProductVersion -replace '[^0-9.].*$')
            }
            return [version]"0.0.0"
        }
        $ausgabe = & pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        return [version]($ausgabe -replace '-.*$', '')
    }
    catch { return [version]"0.0.0" }
}

# [intern] Laedt ein Asset des neuesten GitHub-Releases (Muster mit Platzhaltern) ins
# Temp-Verzeichnis. Rueckgabewert: Pfad der Datei oder $null.
function Save-GithubReleaseAsset([string] $Repository, [string] $Pattern) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" `
            -Headers @{ 'User-Agent' = 'MdsTools' } -TimeoutSec 30
        $asset = $release.assets | Where-Object name -like $Pattern | Select-Object -First 1
        if (-not $asset) {
            Write-Error "Kein Download für Muster '$Pattern' im neuesten Release von $Repository gefunden."
            return $null
        }
        $datei = Join-Path ([System.IO.Path]::GetTempPath()) $asset.name
        Write-Host "Lade $($asset.name) ..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $datei -UseBasicParsing
        return $datei
    }
    catch {
        Write-Error "Download von GitHub fehlgeschlagen: $_"
        return $null
    }
}

# [intern] Installiert das .NET-SDK winget-frei ueber das offizielle Skript (https://dot.net).
# Laedt dotnet-install.ps1, fuehrt es maschinenweit in einem eigenen Prozess aus
# (ExecutionPolicy Bypass; ein evtl. 'exit' beendet so NICHT die Sitzung) und nimmt
# $InstallDir dauerhaft in die Maschinen-PATH auf. Laeuft auch aus Windows PowerShell 5.1.
#   Channel     SDK-Kanal, z. B. '10.0' oder 'LTS'
#   InstallDir  Installationsverzeichnis (maschinenweit)
# Rueckgabewert: $true bei Erfolg, sonst $false.
function Install-DotNetFromOfficial {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, HelpMessage = "SDK-Kanal, z. B. '10.0' oder 'LTS'")]
        [string] $Channel = "LTS",

        [Parameter(Position = 1, HelpMessage = "Installationsverzeichnis (maschinenweit)")]
        [string] $InstallDir = "$env:ProgramFiles\dotnet"
    )

    try {
        $scriptPfad = Join-Path $env:TEMP 'dotnet-install.ps1'
        Write-Host "Lade dotnet-install.ps1 ..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $scriptPfad -UseBasicParsing

        Write-Host "Installiere .NET-SDK (Kanal $Channel) nach $InstallDir ..." -ForegroundColor Yellow
        # Im Kindprozess ausfuehren (Isolation: ein 'throw'/'exit' beendet nicht die
        # aktuelle Sitzung). TLS 1.2 MUSS hier separat gesetzt werden - der Kindprozess
        # erbt unsere Einstellung nicht, und dotnet-install.ps1 setzt sie unter WinPS 5.1
        # nicht selbst (sonst "Unable to download ...zip"). Pfade in Einfachquotes wegen
        # Leerzeichen (z. B. 'C:\Program Files\dotnet').
        $cmd = "[Net.ServicePointManager]::SecurityProtocol = " +
               "[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; " +
               "& '$scriptPfad' -Channel $Channel -InstallDir '$InstallDir' -Architecture x64"
        $argLine = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $prozess = Start-Process powershell.exe -Wait -PassThru -NoNewWindow -ArgumentList $argLine
        Remove-Item -LiteralPath $scriptPfad -ErrorAction SilentlyContinue

        if ($prozess.ExitCode -ne 0) {
            Write-Error "dotnet-install fehlgeschlagen (Exit-Code $($prozess.ExitCode)). Hinweis: maschinenweite Installation nach '$InstallDir' erfordert erhöhte Rechte."
            return $false
        }

        # dotnet in die PATH aufnehmen: aktuelle Sitzung sofort, Maschine dauerhaft.
        if (($env:PATH -split ';') -notcontains $InstallDir) {
            $env:PATH = "$InstallDir;$env:PATH"
        }
        try {
            $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
            if (($machinePath -split ';') -notcontains $InstallDir) {
                [Environment]::SetEnvironmentVariable('Path', "$machinePath;$InstallDir", 'Machine')
            }
        }
        catch {
            Write-Warning "PATH (Maschine) konnte nicht dauerhaft ergänzt werden (Rechte?). In neuen Sitzungen ggf. '$InstallDir' manuell ergänzen."
        }
        return $true
    }
    catch {
        Write-Error "Installation über dotnet-install.ps1 fehlgeschlagen: $_"
        return $false
    }
}

# [public] Update-DotNet — Prueft die installierte .NET-SDK-Version und aktualisiert
# sie ohne Bedienereingriff, falls sie unter der Zielversion liegt. Standardweg ist
# winget-FREI ueber dotnet-install (https://dot.net; laeuft auch aus WinPS 5.1). Mit
# -UseWinget stattdessen der winget-Weg. ERFORDERT ADMINRECHTE (maschinenweite Installation).
#   MinVersion  Mindest-Zielversion
#   Channel     SDK-Kanal ('10.0','LTS'); leer -> aus MinVersion abgeleitet
#   InstallDir  Installationsverzeichnis (maschinenweit)
#   UseWinget   Statt dotnet-install den winget-Weg nutzen
#   PackageId   winget-Paket-ID (nur mit -UseWinget)
# Rueckgabewert: $true wenn aktuell genug (oder Update erfolgreich), sonst $false.
function Update-DotNet {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, HelpMessage = "Mindest-Zielversion")]
        [version] $MinVersion = [version]"10.0.301",

        [Parameter(Position = 1, HelpMessage = "SDK-Kanal (z. B. '10.0', 'LTS'); leer -> aus MinVersion abgeleitet")]
        [string] $Channel = "",

        [Parameter(HelpMessage = "Installationsverzeichnis (maschinenweit)")]
        [string] $InstallDir = "$env:ProgramFiles\dotnet",

        [Parameter(HelpMessage = "Statt dotnet-install den winget-Weg nutzen")]
        [switch] $UseWinget,

        [Parameter(HelpMessage = "winget-Paket-ID (nur mit -UseWinget)")]
        [string] $PackageId = "Microsoft.DotNet.SDK.10"
    )

    $aktuell = try { [version](dotnet --version 2>$null) } catch { [version]"0.0.0" }

    if ($aktuell -ge $MinVersion) {
        Write-Host ".NET ist aktuell ($aktuell)" -ForegroundColor Green
        return $true
    }

    # macOS: ueber Homebrew (cask dotnet-sdk); ohne Homebrew nur Hinweis auf den Download.
    if ($IsMacOS) {
        $brewCask = $false
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            & brew list --cask dotnet-sdk *> $null
            $brewCask = ($LASTEXITCODE -eq 0)
        }
        if ($brewCask) {
            & brew update
            & brew upgrade --cask dotnet-sdk
        }
        else {
            Write-Warning "Bitte das .NET-SDK von https://dotnet.microsoft.com/download installieren (oder 'brew install --cask dotnet-sdk')."
            return $false
        }
        $neu = try { [version](dotnet --version 2>$null) } catch { [version]"0.0.0" }
        if ($neu -ge $MinVersion) {
            Write-Host ".NET aktualisiert ($aktuell -> $neu)" -ForegroundColor Green
            return $true
        }
        Write-Error "Update durchgeführt, aber Version weiterhin zu niedrig ($neu)."
        return $false
    }

    # Erst wenn wirklich installiert werden muss, Adminrechte einfordern.
    if (-not (Assert-Admin "Das Aktualisieren des .NET-SDK")) { return $false }

    Write-Host "Update nötig ($aktuell -> $MinVersion) ..." -ForegroundColor Yellow

    if ($UseWinget) {
        Write-Host "Installiere $PackageId über winget ..." -ForegroundColor Yellow
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Error "winget ist nicht installiert/verfügbar. Installation nicht möglich."
            return $false
        }
        winget install --id $PackageId --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) {
            Write-Error "winget-Installation fehlgeschlagen (Exit-Code $LASTEXITCODE)."
            return $false
        }
    }
    else {
        # Kanal aus MinVersion ableiten (z. B. 10.0.301 -> '10.0'), falls nicht gesetzt.
        if ([string]::IsNullOrWhiteSpace($Channel)) {
            $Channel = "$($MinVersion.Major).$($MinVersion.Minor)"
        }
        if (-not (Install-DotNetFromOfficial -Channel $Channel -InstallDir $InstallDir)) {
            return $false
        }
    }

    # Nach dem Update erneut pruefen
    $neu = try { [version](dotnet --version 2>$null) } catch { [version]"0.0.0" }
    if ($neu -ge $MinVersion) {
        Write-Host ".NET aktualisiert ($aktuell -> $neu)" -ForegroundColor Green
        return $true
    }

    Write-Error "Update durchgeführt, aber Version weiterhin zu niedrig ($neu)."
    return $false
}

# [public] Update-PowerShell — Prueft die installierte PowerShell-7-Version und aktualisiert
# sie im laufenden Betrieb, falls sie unter der Zielversion liegt. Mit -Last ist das Ziel die
# neueste GitHub-Release-Version.
#   macOS:   Homebrew (cask powershell), falls darueber installiert, sonst PKG von GitHub
#            per 'sudo installer' (fragt nach dem Passwort).
#   Windows: nur Anzeige (installierte und neueste Version). Installiert wird mit
#            Update-PowerShell7.cmd im Repo Mds: Es laeuft in Windows PowerShell 5.1, denn ein
#            MSI-Update aus der laufenden pwsh beendet diese pwsh mitten in der Installation.
#   MinVersion  Mindest-Zielversion
#   Last        Auf die neueste GitHub-Release-Version aktualisieren
# Rueckgabewert: $true wenn aktuell genug (oder Update erfolgreich), sonst $false.
# 2026-10-31 Hubi/Claude: macOS-Zweig aus UpdatePS.ps1 uebernommen (E9), UpdatePS.ps1 entfaellt
# 2026-11-04 Hubi/Claude: Windows nur Anzeige, Verweis auf Update-PowerShell7.cmd; ohne -PackageId
function Update-PowerShell {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, HelpMessage = "Mindest-Zielversion")]
        [version] $MinVersion = [version]"7.6.2",

        [Parameter(HelpMessage = "Auf die neueste GitHub-Release-Version aktualisieren")]
        [switch] $Last
    )

    $aktuell = Get-InstalledPwshVersion

    # Windows: nur anzeigen, installiert wird aus Windows PowerShell 5.1 (Update-PowerShell7.cmd)
    if ($IsWindows) {
        $neueste = Get-GithubLatestVersion -Repository 'PowerShell/PowerShell'
        $ziel = if ($Last -and $neueste -gt $MinVersion) { $neueste } else { $MinVersion }
        Write-Host "PowerShell 7 installiert: $aktuell" -ForegroundColor Cyan
        if ($neueste -gt [version]'0.0.0') { Write-Host "Neueste Version:          $neueste" }
        $starter = Join-Path (Join-Path $mdsRepos 'Mds') 'Update-PowerShell7.cmd'
        if ($neueste -gt $aktuell -or $aktuell -lt $ziel) {
            Write-Host "Aktualisieren aus Windows PowerShell 5.1 (nicht aus pwsh):" -ForegroundColor Yellow
            Write-Host "  $starter -Last" -ForegroundColor Yellow
        }
        else {
            Write-Host "PowerShell 7 ist aktuell." -ForegroundColor Green
        }
        return ($aktuell -ge $ziel)
    }

    # Bei -Last die neueste GitHub-Version als Ziel verwenden
    if ($Last) {
        $githubNeueste = Get-GithubLatestVersion -Repository 'PowerShell/PowerShell'
        if ($githubNeueste -gt $MinVersion) { $MinVersion = $githubNeueste }
    }

    if ($aktuell -ge $MinVersion) {
        Write-Host "PowerShell 7 ist aktuell ($aktuell)" -ForegroundColor Green
        return $true
    }

    Write-Host "Update nötig ($aktuell -> $MinVersion) ..." -ForegroundColor Yellow

    if ($IsMacOS) {
        $brewCask = $false
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            & brew list --cask powershell *> $null
            $brewCask = ($LASTEXITCODE -eq 0)
        }
        if ($brewCask) {
            & brew update
            & brew upgrade --cask powershell
        }
        else {
            $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()
            $pkg = Save-GithubReleaseAsset -Repository 'PowerShell/PowerShell' -Pattern "*osx-$arch.pkg"
            if (-not $pkg) { return $false }
            Write-Host 'Installation benötigt Admin-Rechte (sudo) ...'
            & sudo installer -pkg $pkg -target /
            Remove-Item -LiteralPath $pkg -ErrorAction SilentlyContinue
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Update meldete Exit-Code $LASTEXITCODE."
            return $false
        }
    }
    else {
        Write-Error "Update-PowerShell unterstützt nur Windows und macOS."
        return $false
    }

    # Nach dem Update erneut pruefen
    $neu = Get-InstalledPwshVersion
    if ($neu -ge $MinVersion) {
        Write-Host "PowerShell 7 aktualisiert ($aktuell -> $neu). Bitte offene pwsh-Fenster neu starten." -ForegroundColor Green
        return $true
    }

    Write-Error "Update durchgeführt, aber Version weiterhin zu niedrig ($neu)."
    return $false
}

# [public] Show-PowerShell — Zeigt Informationen zur laufenden PowerShell und zum .NET-SDK:
# aktuelle Version sowie die hoechste verfuegbare Version (Max aus winget und GitHub-Releases).
# Reine Anzeige, keine Adminrechte noetig.
#   PowerShellPackageId  winget-Paket-ID der PowerShell
#   DotNetPackageId      winget-Paket-ID des .NET-SDK
function Show-PowerShell {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, HelpMessage = "winget-Paket-ID der PowerShell")]
        [string] $PowerShellPackageId = "Microsoft.PowerShell",

        [Parameter(Position = 1, HelpMessage = "winget-Paket-ID des .NET-SDK")]
        [string] $DotNetPackageId = "Microsoft.DotNet.SDK.10"
    )

    # --- PowerShell ---
    $psPfad = try { (Get-Process -Id $PID).Path } catch { $null }
    if ([string]::IsNullOrWhiteSpace($psPfad)) {
        $exe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
        $psPfad = Join-Path $PSHOME $exe
    }
    $psAktuell = $PSVersionTable.PSVersion
    # winget hinkt teils hinterher -> hoechste Version aus winget und GitHub nehmen
    $psWinget = if ($IsWindows) { Get-WingetAvailableVersion -PackageId $PowerShellPackageId } else { [version]"0.0.0" }
    $psGithub = Get-GithubLatestVersion -Repository 'PowerShell/PowerShell'
    $psVerfuegbar = if ($psGithub -gt $psWinget) { $psGithub } else { $psWinget }

    Write-Host "PowerShell" -ForegroundColor Cyan
    Write-Host "  Pfad:       $psPfad"
    Write-Host "  Version:    $psAktuell"
    if ($IsWindows) { Write-Host "  winget:     $psWinget" -ForegroundColor $(if ($psWinget -gt $psAktuell) { 'Yellow' } else { 'Green' }) }
    Write-Host "  GitHub:     $psGithub" -ForegroundColor $(if ($psGithub -gt $psAktuell) { 'Yellow' } else { 'Green' })
    Write-Host "  Verfügbar: $psVerfuegbar" -ForegroundColor $(if ($psVerfuegbar -gt $psAktuell) { 'Yellow' } else { 'Green' })

    # --- .NET-SDK ---
    $netAktuell = try { [version](dotnet --version 2>$null) } catch { [version]"0.0.0" }
    $netVerfuegbar = if ($IsWindows) { Get-WingetAvailableVersion -PackageId $DotNetPackageId } else { [version]"0.0.0" }

    Write-Host ".NET-SDK" -ForegroundColor Cyan
    Write-Host "  Version:    $netAktuell"
    if ($IsWindows) {
        Write-Host "  Verfügbar: $netVerfuegbar" -ForegroundColor $(if ($netVerfuegbar -gt $netAktuell) { 'Yellow' } else { 'Green' })
    }
}

<#
.SYNOPSIS
    Zeigt die globalen mds-Variablen strukturiert an, inklusive Modulversion und woy-Stand.

.DESCRIPTION
    Liefert je Variable ein Objekt mit Wert, Quelle und (bei Ordnern) ob der Ordner existiert.
    Quelle ist "DEV_<NAME>", wenn die Umgebungsvariable den Ordner umlenkt, sonst "Standard"
    (macOS: ~/Repos, ~/Root; Windows: C:\woyCode, D:\Root bzw. C:\Root). Vorweg erscheint eine Kopfzeile mit Modul-,
    PowerShell-Version und Betriebssystem.

.PARAMETER Full
    Gibt zusaetzlich alle externen Befehle aus: die exportierten Funktionen des Moduls und
    (nur Windows) die globalen woy-/Auftrags-Funktionen aus MdsSkripte. Je Befehl erscheint eine
    Zeile mit Name (Spalte Variable), Kurzbeschreibung (Wert) und Datei (Quelle). Kurzform: -F.

.EXAMPLE
    Show-Mds

.EXAMPLE
    Show-Mds -F

.EXAMPLE
    Show-Mds | Where-Object Vorhanden -eq $false
#>
# 2026-11-03 Hubi/Claude: erstellt
function Show-Mds {
    [CmdletBinding()]
    param(
        # 2026-11-04 Hubi/Claude: alle externen Befehle mit ausgeben
        [Alias('F')]
        [switch] $Full
    )

    $os = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' }
    Write-Info "MdsTools $mdsVersion | woy $mdsWoy | PowerShell $($PSVersionTable.PSVersion) | $os"

    # 2026-11-03 Hubi/Claude: Betriebssystem als eigene Zeile (Windows oder macOS sofort erkennbar)
    $osVariable = if ($IsWindows) { 'IsWindows' } elseif ($IsMacOS) { 'IsMacOS' } else { 'IsLinux' }
    [pscustomobject]@{ Variable = 'System'; Wert = $os; Quelle = $osVariable; Vorhanden = $null }
    [pscustomobject]@{ Variable = 'mdsVersion'; Wert = "$mdsVersion"; Quelle = 'MdsTools.psd1'; Vorhanden = $null }
    [pscustomobject]@{ Variable = 'mdsWoy'; Wert = "$mdsWoy"; Quelle = $os; Vorhanden = $null }

    $ordner = [ordered]@{
        mdsRepos = 'REPOS'; mdsRoot = 'ROOT'; mdsBin = 'BIN'
        mdsConfig = 'CONFIG'; mdsData = 'DATA'; mdsLogs = 'LOGS'; mdsTemp = 'TEMP'
    }
    foreach ($eintrag in $ordner.GetEnumerator()) {
        $wert = (Get-Variable -Name $eintrag.Key -Scope Global -ValueOnly -ErrorAction SilentlyContinue)
        $env = "DEV_$($eintrag.Value)"
        [pscustomobject]@{
            Variable  = $eintrag.Key
            Wert      = $wert
            Quelle    = if ([Environment]::GetEnvironmentVariable($env)) { $env } else { 'Standard' }
            Vorhanden = [bool]($wert -and (Test-Path -LiteralPath $wert -PathType Container))
        }
    }

    # 2026-11-03 Hubi/Claude: Legacy-Adressen der Auftragsabwicklung, nur unter Windows
    if ($IsWindows) {
        foreach ($name in 'mdsWoySrc', 'mdsWoyBin', 'mdsWoyRun') {
            $wert = (Get-Variable -Name $name -Scope Global -ValueOnly -ErrorAction SilentlyContinue)
            [pscustomobject]@{
                Variable  = $name
                Wert      = $wert
                Quelle    = 'Legacy (fest)'
                Vorhanden = [bool]($wert -and (Test-Path -LiteralPath $wert -PathType Container))
            }
        }
    }

    if ($Full) {
        Get-MdsCommand | ForEach-Object {
            [pscustomobject]@{ Variable = $_.Name; Wert = $_.Beschreibung; Quelle = $_.Datei; Vorhanden = $null }
        }
    }
}

# [intern] Liefert alle externen Befehle von MdsTools, nach Name sortiert: die exportierten
# Funktionen des Moduls und die globalen Funktionen aus MdsSkripte (nur Windows geladen).
# Rueckgabewert: Objekte mit Name, Beschreibung und Datei. Beschreibung ist die .SYNOPSIS, sonst
# die erste Zeile des Kommentarblocks ueber der Funktion (ohne "[public] <Name> —").
# 2026-11-04 Hubi/Claude: erstellt fuer Show-Mds -Full
function Get-MdsCommand {
    [CmdletBinding()]
    param()

    $modulOrdner = Split-Path $PSScriptRoot -Parent
    $befehle = @((Get-Module MdsTools).ExportedFunctions.Values) +
        @(Get-ChildItem -Path Function:\ | Where-Object {
            $_.ScriptBlock.File -and $_.ScriptBlock.File.StartsWith((Join-Path $modulOrdner 'MdsSkripte'), [StringComparison]::OrdinalIgnoreCase)
        })
    foreach ($befehl in $befehle | Sort-Object Name -Unique) {
        $hilfe = Get-Help $befehl.Name -ErrorAction SilentlyContinue
        # Ohne kommentarbasierte Hilfe liefert Get-Help nur die Syntax als Synopsis.
        $text = if ($hilfe -and $hilfe.Synopsis -and -not $hilfe.Synopsis.Trim().StartsWith($befehl.Name)) {
            ($hilfe.Synopsis -replace '\s+', ' ').Trim()
        }
        else {
            Get-FunctionComment $befehl
        }
        [pscustomobject]@{
            Name         = $befehl.Name
            Beschreibung = "$text"
            Datei        = if ($befehl.ScriptBlock.File) { Split-Path $befehl.ScriptBlock.File -Leaf } else { '' }
        }
    }
}

# [intern] Liefert den ersten Satz des Kommentarblocks direkt ueber einer Funktion, ohne Praefix
# "[public]"/"[intern]" und ohne "<Name> —". Gelesen wird bis zur ersten eingerueckten Zeile
# (Parameterliste) oder Zeile mit Datum (Historie). Ohne Kommentar: "".
# 2026-11-04 Hubi/Claude: erstellt fuer Show-Mds -Full
function Get-FunctionComment([System.Management.Automation.FunctionInfo] $Befehl) {
    $datei = $Befehl.ScriptBlock.File
    if (-not $datei -or -not (Test-Path -LiteralPath $datei -PathType Leaf)) { return '' }
    $zeilen = @(Get-Content -LiteralPath $datei)
    $start = $Befehl.ScriptBlock.Ast.Extent.StartLineNumber - 2   # Zeile davor, 0-basiert
    $block = @()
    for ($i = $start; $i -ge 0 -and $zeilen[$i] -match '^\s*#(?!>)'; $i--) {
        $block = , ($zeilen[$i] -replace '^\s*#\s?', '') + $block
    }
    $text = @()
    foreach ($zeile in $block) {
        if (-not $zeile.Trim() -or $zeile -match '^\s{2}' -or $zeile -match '^\d{4}-\d{2}-\d{2}') { break }
        $text += $zeile.Trim()
    }
    $satz = ($text -join ' ') -replace '^\[(public|intern)\]\s*', ''
    $satz = $satz -replace "^$([regex]::Escape($Befehl.Name))\s*[—-]\s*", ''
    # Erster Satz: Punkt nach einem Wort mit mind. 3 Buchstaben (nicht "z. B."), danach Grossbuchstabe oder Ende.
    if ($satz -match '^(.+?(?:\p{L}{3}|\))\.)(?=\s+\p{Lu}|\s*$)') { $satz = $Matches[1] }
    return $satz.Trim()
}
