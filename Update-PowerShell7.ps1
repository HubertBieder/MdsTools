#======================================================================
# Skript:       Update-PowerShell7.ps1  (Teil von MdsTools, liegt neben Install.ps1)
# Beschreibung: Prueft bzw. installiert PowerShell 7 aus dem offiziellen
#               GitHub-Release (win-x64-MSI), winget-frei. Nur Windows.
#
#               "Neueste" heisst immer: neueste Version der Linie -Linie (Standard 7.6,
#               LTS auf .NET 10). Auf 7.7 erst zusammen mit .NET 11 umstellen, ebenso
#               $PwshLinie in Modul/MdsTools/SkriptModule/Tools.ps1. Ab 7.7 gibt es
#               kein MSI mehr, nur noch MSIX/ZIP - dieses Skript muss dann angepasst werden.
#
#               Ablauf:
#                 - keine PowerShell 7 vorhanden  -> Warnung, neueste Version installieren
#                 - PowerShell 7 vorhanden        -> installierte Version anzeigen und ob
#                                                    es eine neuere gibt (keine Installation)
#                 - mit -Last                     -> in jedem Fall die neueste installieren
#                 - mit -Version 7.6.4            -> in jedem Fall diese Version installieren
#               Ohne Administratorrechte bricht das Skript nach einer Warnung ab.
#
#               LAEUFT BEWUSST UNTER WINDOWS POWERSHELL 5.1 (powershell.exe).
#               Grund: Startet man das MSI-Update aus der laufenden pwsh.exe
#               heraus, beendet der Windows Installer per Restart Manager im
#               Silent-Modus genau diese pwsh.exe ("das Fenster verschwindet").
#               Das MSI ist ein Major Upgrade - es deinstalliert zuerst die alte
#               Version. Sind die Dateien gesperrt, werden die Ersetzungen auf
#               den naechsten Neustart verschoben (Exit-Code 3010) bzw. das
#               Setup rollt zurueck: pwsh.exe fehlt danach.
#               Aus 5.1 heraus haelt niemand die Dateien -> sauberes Upgrade.
#
#               Das Skript repariert auch den kaputten Zustand "MSI-Produkt
#               registriert, pwsh.exe fehlt" (REINSTALL=ALL).
#
# Aufruf: am einfachsten ueber den Starter Update-PowerShell7.cmd (Doppelklick,
#   startet 5.1, umgeht die Execution Policy nur fuer diesen Prozess, holt
#   Adminrechte per UAC; Argumente werden durchgereicht). Direkt in Windows
#   PowerShell 5.1 "Als Administrator":
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Update-PowerShell7.ps1
#     -Last           neueste Version der Linie installieren, auch wenn schon eine vorhanden ist
#     -Version 7.6.4  diese Version installieren (statt der neuesten)
#     -Force          laufende pwsh.exe-Prozesse vor der Installation beenden
#     -KeepMsi        heruntergeladene MSI behalten
#     -Linie 7.6      Versionslinie fuer "neueste" (Standard 7.6)
#
# Exit-Codes: 0 = OK, 1 = Fehler, 2 = falscher Host/keine Adminrechte,
#             3010 = installiert, aber Neustart erforderlich
#
# Versionshistorie:
#   29.07.2026  H. Bieder    Erstfassung
#   2026-11-04  Hubi/Claude  2.0.0: Teil von MdsTools; ohne PowerShell 7 installieren, sonst
#                            nur Version und neuere Version anzeigen; -Last; -Force beendet
#                            nur noch laufende pwsh.exe; Warnung ohne Adminrechte
#   2026-11-04  Hubi/Claude  2.1.0: umbenannt von Install-PowerShell7.ps1 (Tab-Vervollstaendigung
#                            bei ./Inst...); Update-PowerShell im Modul verweist unter Windows hierher
#   2026-11-11  Hubi/Claude  2.2.0: -Linie (Standard 7.6): -Last und die Anzeige bleiben in der Linie;
#                            Hinweis, wenn die installierte Version neuer als die Linie ist
#
# PowerShell: 5.1 (Desktop)
#======================================================================

#Requires -Version 5.1

# Keine Positionsparameter: ".\Update-PowerShell7.ps1 latest" landete sonst
# als -Repository und lieferte einen 404 von GitHub (11.09.2026).
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(HelpMessage = "GitHub-Repository in der Form 'Besitzer/Repo'")]
    [string] $Repository = 'PowerShell/PowerShell',

    [Parameter(HelpMessage = "Diese Version installieren statt der neuesten, z. B. '7.6.4'")]
    [string] $Version,

    [Parameter(HelpMessage = "Neueste Version der Linie installieren, auch wenn PowerShell 7 schon vorhanden ist")]
    [switch] $Last,

    [Parameter(HelpMessage = "Versionslinie Major.Minor fuer 'neueste', z. B. '7.6'")]
    [string] $Linie = '7.6',

    [Parameter(HelpMessage = "Laufende pwsh.exe-Prozesse vor der Installation beenden")]
    [switch] $Force,

    [Parameter(HelpMessage = "Heruntergeladene MSI nach der Installation behalten")]
    [switch] $KeepMsi,

    [Parameter(HelpMessage = "Pfad des ausfuehrlichen msiexec-Protokolls")]
    [string] $LogPath = (Join-Path $env:TEMP 'PowerShell7-Install.log')
)

$ErrorActionPreference = 'Stop'
# Ohne das ist Invoke-WebRequest -OutFile unter 5.1 fuer ~110 MB quaelend langsam.
$ProgressPreference = 'SilentlyContinue'

# 64-Bit-Programmverzeichnis auch aus einem 32-Bit-Host korrekt aufloesen.
$programFiles = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
$pwshExe = Join-Path $programFiles 'PowerShell\7\pwsh.exe'


#====================== BEGIN FUNCTIONS ===========================#

# Vereinheitlicht Versionsangaben aus allen drei Quellen auf Major.Minor.Build:
# GitHub-Tag 'v7.6.4', Datei-Produktversion '7.6.4 SHA: ...' und Registry-
# DisplayVersion '7.6.4.0'. Ohne diese Normalisierung waeren 7.6.4 und 7.6.4.0
# per -eq NICHT gleich (Revision -1 gegen 0). Ein Praerelease-Suffix
# ('7.7.0-preview.2') faellt dabei weg - dafuer ist -Version explizit gedacht.
# Rueckgabewert: [version], 0.0.0 wenn nichts Versionsartiges enthalten ist.
function ConvertTo-Version([string] $Text) {
    if ($Text -match '([0-9]+)\.([0-9]+)\.([0-9]+)') {
        return [version]('{0}.{1}.{2}' -f $Matches[1], $Matches[2], $Matches[3])
    }
    if ($Text -match '([0-9]+)\.([0-9]+)') {
        return [version]('{0}.{1}.0' -f $Matches[1], $Matches[2])
    }
    return [version]'0.0.0'
}

# Versionsnummer der installierten pwsh.exe aus den Dateiinformationen.
# Rueckgabewert: [version], 0.0.0 wenn die Datei fehlt.
function Get-PwshDateiVersion {
    if (-not (Test-Path -LiteralPath $script:pwshExe)) { return [version]'0.0.0' }
    try {
        $roh = (Microsoft.PowerShell.Management\Get-Item -LiteralPath $script:pwshExe).VersionInfo.ProductVersion
        return ConvertTo-Version $roh
    }
    catch { return [version]'0.0.0' }
}

# In der Windows-Installer-Registry eingetragenes Produkt "PowerShell 7-x64".
# Wichtig fuer den Fall "Produkt registriert, Dateien fehlen": ein einfaches
# /i derselben Version wuerde dann kommentarlos nichts tun.
function Get-PwshProdukt {
    $pfade = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $pfade -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'PowerShell 7*' -and $_.DisplayVersion } |
        Select-Object -First 1
}

# Prueft die OLE-Signatur (D0 CF 11 E0 A1 B1 1A E1) einer Datei. Ein per
# Fehlerseite/Redirect "heruntergeladenes" HTML wuerde msiexec sonst mit einer
# nichtssagenden Meldung quittieren.
function Test-MsiDatei([string] $Pfad) {
    try {
        $strom = [IO.File]::OpenRead($Pfad)
        try {
            $puffer = New-Object byte[] 8
            if ($strom.Read($puffer, 0, 8) -ne 8) { return $false }
        }
        finally { $strom.Dispose() }
        $erwartet = [byte[]] (0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1)
        for ($i = 0; $i -lt 8; $i++) { if ($puffer[$i] -ne $erwartet[$i]) { return $false } }
        return $true
    }
    catch { return $false }
}

#====================== END FUNCTIONS ===========================#


# --- 1. Host pruefen: Dieses Skript gehoert in die Windows PowerShell 5.1 ---
if ($PSVersionTable.PSEdition -ne 'Desktop') {
    Write-Host "Dieses Skript muss in der Windows PowerShell 5.1 laufen, nicht in pwsh." -ForegroundColor Red
    Write-Host "Sonst beendet der Windows Installer die laufende pwsh.exe mitten im Upgrade." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','$PSCommandPath'" -ForegroundColor Yellow
    exit 2
}

# --- 2. Adminrechte pruefen (maschinenweite Installation) ---
$identitaet = [Security.Principal.WindowsIdentity]::GetCurrent()
$prinzipal = New-Object Security.Principal.WindowsPrincipal($identitaet)
if (-not $prinzipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "WARNUNG: Keine Administratorrechte - Abbruch." -ForegroundColor Yellow
    Write-Host "Bitte 'Als Administrator' starten oder Update-PowerShell7.cmd verwenden." -ForegroundColor Yellow
    exit 2
}

# --- 3. Ist-Zustand aufnehmen ---
$dateiVersion = Get-PwshDateiVersion
$produkt = Get-PwshProdukt
$registriert = if ($produkt) { ConvertTo-Version $produkt.DisplayVersion } else { [version]'0.0.0' }

Write-Host "PowerShell 7 - Ist-Zustand" -ForegroundColor Cyan
Write-Host "  Datei:       $(if ($dateiVersion -eq [version]'0.0.0') { 'nicht vorhanden' } else { "$dateiVersion ($pwshExe)" })"
Write-Host "  Registriert: $(if ($registriert -eq [version]'0.0.0') { 'kein MSI-Produkt' } else { $registriert })"

$defekt = ($dateiVersion -eq [version]'0.0.0' -and $registriert -ne [version]'0.0.0')
if ($defekt) {
    Write-Host "  -> Produkt ist registriert, aber pwsh.exe fehlt (abgebrochenes Upgrade)." -ForegroundColor Yellow
}

# Installiert wird ohne PowerShell 7 (auch im defekten Zustand) oder auf ausdruecklichen Wunsch.
$vorhanden = ($dateiVersion -ne [version]'0.0.0')
$wunsch = $Last -or -not [string]::IsNullOrWhiteSpace($Version)
if (-not $vorhanden) {
    Write-Host "WARNUNG: PowerShell 7 ist nicht installiert - $(if ($Version) { "Version $Version" } else { 'die neueste Version' }) wird installiert." -ForegroundColor Yellow
}

# --- 4. Zielversion und Download-URL von GitHub holen ---
[Net.ServicePointManager]::SecurityProtocol =
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$basis = "https://api.github.com/repos/$Repository/releases"
$kopf = @{ 'User-Agent' = 'MdsTools' }

Write-Host "Frage GitHub-Release ab ..." -ForegroundColor Yellow
try {
    if ([string]::IsNullOrWhiteSpace($Version)) {
        # Neueste stabile Version der Linie, z. B. hoechstes v7.6.x. Erst in eine Variable:
        # unter 5.1 gibt Invoke-RestMethod ein JSON-Array als EIN Objekt in die Pipeline.
        $muster = '^v' + [regex]::Escape($Linie) + '\.[0-9]+$'
        $liste = Invoke-RestMethod -Uri "$($basis)?per_page=100" -Headers $kopf -TimeoutSec 30
        $release = $liste |
            Where-Object { -not $_.prerelease -and -not $_.draft -and $_.tag_name -match $muster } |
            Sort-Object { ConvertTo-Version $_.tag_name } -Descending |
            Select-Object -First 1
        if (-not $release) { throw "Kein Release der Linie $Linie gefunden." }
    }
    else {
        $release = Invoke-RestMethod -Uri "$basis/tags/v$($Version -replace '^v')" -Headers $kopf -TimeoutSec 30
    }
}
catch {
    if (-not [string]::IsNullOrWhiteSpace($Version) -and "$_" -match '"status"\s*:\s*"404"') {
        Write-Host "Version '$Version' gibt es nicht als Release (Tag v$($Version -replace '^v') nicht gefunden)." -ForegroundColor Red
        Write-Host "Ohne -Version wird die neueste Version der Linie $Linie installiert." -ForegroundColor Yellow
    }
    else {
        Write-Host "GitHub-Release konnte nicht ermittelt werden: $_" -ForegroundColor Red
    }
    # Nur Anzeige gewuenscht: die installierte Version steht schon oben
    if ($vorhanden -and -not $wunsch) { exit 0 }
    exit 1
}

$asset = $release.assets | Where-Object { $_.name -match 'win-x64\.msi$' } | Select-Object -First 1
if (-not $asset) {
    Write-Host "Kein win-x64-MSI im Release '$($release.tag_name)' gefunden." -ForegroundColor Red
    exit 1
}
$zielVersion = ConvertTo-Version $release.tag_name

# --- 5. Vorhandene PowerShell 7 ohne -Last/-Version: nur Version und neuere anzeigen ---
if ($vorhanden -and -not $wunsch) {
    Write-Host "  Neueste:     $zielVersion (Linie $Linie)"
    if ($dateiVersion -gt $zielVersion -and "$($dateiVersion.Major).$($dateiVersion.Minor)" -ne $Linie) {
        Write-Host "Installiert ist $dateiVersion, also neuer als die Linie $Linie." -ForegroundColor Yellow
        Write-Host "Zurueck mit: Update-PowerShell7.cmd -Version $zielVersion (ggf. vorher deinstallieren)" -ForegroundColor Yellow
    }
    elseif ($zielVersion -gt $dateiVersion) {
        Write-Host "Neuere Version verfuegbar: $zielVersion (installiert: $dateiVersion)." -ForegroundColor Yellow
        Write-Host "Installieren mit: Update-PowerShell7.cmd -Last" -ForegroundColor Yellow
    }
    else {
        Write-Host "PowerShell 7 ist aktuell ($dateiVersion)." -ForegroundColor Green
    }
    exit 0
}

Write-Host "  Ziel:        $zielVersion ($($asset.name))"
if ($vorhanden -and $zielVersion -lt $dateiVersion) {
    Write-Host "WARNUNG: Ziel $zielVersion ist aelter als die installierte $dateiVersion - der Installer kann das Downgrade ablehnen." -ForegroundColor Yellow
}

# Gleiche Version bereits registriert -> /i allein waere ein No-Op.
# Mit REINSTALL=ALL/REINSTALLMODE=amus werden alle Dateien neu geschrieben.
$reinstall = ($registriert -eq $zielVersion)

# --- 6. Laufende pwsh-Prozesse: bewusst vorher beenden, nicht dem Installer ueberlassen ---
$laufend = @(Get-Process -Name 'pwsh' -ErrorAction SilentlyContinue)
if ($laufend.Count -gt 0) {
    Write-Host "Es laufen $($laufend.Count) pwsh.exe-Prozess(e):" -ForegroundColor Yellow
    foreach ($p in $laufend) { Write-Host "  PID $($p.Id)  $($p.Path)" }
    if (-not $Force) {
        Write-Host "Abbruch: Der Installer wuerde diese Prozesse selbst beenden und die" -ForegroundColor Red
        Write-Host "Dateiersetzung auf den naechsten Neustart verschieben. Erneut mit -Force" -ForegroundColor Red
        Write-Host "aufrufen oder die Sitzungen vorher schliessen." -ForegroundColor Red
        exit 1
    }
    Write-Host "Beende laufende pwsh.exe-Prozesse (-Force) ..." -ForegroundColor Yellow
    foreach ($p in $laufend) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop }
        catch { Write-Host "  PID $($p.Id) konnte nicht beendet werden: $_" -ForegroundColor Yellow }
    }
    Start-Sleep -Seconds 2
}

# --- 7. MSI herunterladen und pruefen ---
$msiPfad = Join-Path $env:TEMP $asset.name
Write-Host "Lade $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB) ..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msiPfad -UseBasicParsing -TimeoutSec 600
}
catch {
    Write-Host "Download fehlgeschlagen: $_" -ForegroundColor Red
    exit 1
}
if (-not (Test-MsiDatei $msiPfad)) {
    Write-Host "Die heruntergeladene Datei ist kein gueltiges MSI: $msiPfad" -ForegroundColor Red
    exit 1
}

# --- 8. Installieren ---
$argumente = @("/i `"$msiPfad`"", '/qn', '/norestart', 'REBOOT=ReallySuppress', "/l*v `"$LogPath`"")
if ($reinstall -or $defekt) { $argumente += @('REINSTALL=ALL', 'REINSTALLMODE=amus') }

Write-Host "Installiere (Protokoll: $LogPath) ..." -ForegroundColor Yellow
Write-Host "  Major Upgrade: alte Version wird entfernt, neue installiert - dauert typisch 1 bis 3 Minuten." -ForegroundColor DarkGray
# Nicht -Wait: alle 10 Sekunden ein Lebenszeichen, damit es nicht wie ein
# Haenger aussieht. Steht im Fenstertitel "Auswaehlen", ist die Konsole im
# Markiermodus (QuickEdit) und blockiert jede Ausgabe - dann Esc druecken.
$prozess = Start-Process msiexec.exe -ArgumentList ($argumente -join ' ') -PassThru
$start = Get-Date
while (-not $prozess.WaitForExit(10000)) {
    Write-Host ("  ... laeuft seit {0:mm\:ss} (msiexec PID {1})" -f ((Get-Date) - $start), $prozess.Id) -ForegroundColor DarkGray
}
$prozess.WaitForExit()   # ohne Timeout, sonst ist ExitCode unter 5.1 gelegentlich noch leer
$code = $prozess.ExitCode

if (-not $KeepMsi) { Remove-Item -LiteralPath $msiPfad -ErrorAction SilentlyContinue }

switch ($code) {
    0     { Write-Host "msiexec: erfolgreich." -ForegroundColor Green }
    3010  { Write-Host "msiexec: erfolgreich, aber NEUSTART erforderlich (3010)." -ForegroundColor Yellow }
    1641  { Write-Host "msiexec: erfolgreich, Neustart wurde eingeleitet (1641)." -ForegroundColor Yellow }
    1618  { Write-Host "msiexec: eine andere Installation laeuft bereits (1618). Spaeter erneut versuchen." -ForegroundColor Red; exit 1 }
    1603  { Write-Host "msiexec: schwerer Fehler (1603). Details im Protokoll: $LogPath" -ForegroundColor Red; exit 1 }
    default {
        Write-Host "msiexec fehlgeschlagen (Exit-Code $code). Details im Protokoll: $LogPath" -ForegroundColor Red
        exit 1
    }
}

# --- 9. Ergebnis verifizieren ---
$neu = Get-PwshDateiVersion
if ($neu -eq [version]'0.0.0') {
    Write-Host "pwsh.exe fehlt weiterhin unter $pwshExe." -ForegroundColor Red
    $pending = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
                -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pending -and ($pending -join "`n") -match 'PowerShell') {
        Write-Host "Es stehen Dateioperationen bis zum naechsten Neustart aus." -ForegroundColor Yellow
        Write-Host "Server neu starten und dieses Skript danach erneut ausfuehren." -ForegroundColor Yellow
        exit 3010
    }
    Write-Host "Protokoll pruefen: $LogPath" -ForegroundColor Yellow
    exit 1
}

# PATH der Maschine in die laufende Sitzung uebernehmen, damit 'pwsh' sofort greift.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [Environment]::GetEnvironmentVariable('Path', 'User')

# Startfaehigkeit wirklich pruefen, nicht nur die Dateiversion lesen.
$gemeldet = & $pwshExe -NoProfile -NoLogo -Command '$PSVersionTable.PSVersion.ToString()' 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "pwsh.exe ist vorhanden ($neu), startet aber nicht: $gemeldet" -ForegroundColor Red
    exit 1
}

Write-Host "PowerShell 7 installiert: $gemeldet" -ForegroundColor Green
Write-Host "  Pfad: $pwshExe"
if ($code -eq 3010) { exit 3010 }
exit 0
