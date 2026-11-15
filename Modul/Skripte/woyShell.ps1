<#
.SYNOPSIS
    Remote-Shell auf einem Rechner mit Auftragsabwicklung (AufServiceNT).

.DESCRIPTION
    Verbindet sich per WebSocket mit ws://<Rechner>:60000/ServiceCtrl/Shell. Dort laeuft je
    Verbindung eine eigene PowerShell-7-Sitzung im Dienst AufServiceNT (Administratorrechte),
    Start im Root der Installation, z. B. D:\woySystems. Variablen, Module und das aktuelle
    Verzeichnis bleiben bis zum Ende der Verbindung erhalten.

    Einrichtung auf dem Zielrechner: woyControlCenter, Reiter Installation, Zeile
    "REST - Service": Haken "Remote-Shell", Schluessel mit "Neu" erzeugen (landet in der
    Zwischenablage), speichern, AufServiceNT neu starten.

    Auf dem Client einmal den Schluessel hinterlegen:
        ./woyShell.ps1 -Rechner MARS -Token <Schluessel> -Merken
    danach genuegt
        ./woyShell.ps1 MARS

    Hinterlegt wird in woyshell.json (Url und Schluessel je Rechner). Gebraucht wird sie nur
    auf den Rechnern, von denen aus man zugreift (Entwicklung), nicht beim Kunden. Ort:
      1. Umgebungsvariable WOYSHELL_CONFIG (voller Dateiname), falls gesetzt
      2. iCloud Drive Documents/Config/woyshell.json, wenn der Ordner Config dort existiert -
         so ist sie auf allen eigenen Rechnern gleich:
           Windows  ~\iCloudDrive\Documents\Config
           macOS    ~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Config
      3. sonst ~/.woy/woyshell.json
    Eine aeltere lokale Datei (~/.woyshell.json, ~/.woy/woyshell.json) wird beim ersten Aufruf
    dorthin verschoben. Statt der Datei geht auch WOYSHELL_TOKEN_<RECHNER>.

    Schlafende Rechner (MARS): steht im Eintrag "Mac" (optional "Adresse"), wird vor dem Verbinden
    der Port geprueft und der Rechner bei Bedarf per Wake-on-LAN geweckt (hoechstens 120 s).

    In der Shell:  exit / quit  beendet,  Strg+C  bricht ein laufendes Kommando ab,
    Tab  vervollstaendigt auf dem Zielrechner,  Root  springt zurueck ins Startverzeichnis.
    Interaktive Eingaben (Read-Host, Get-Credential, Editoren) gehen nicht.

.EXAMPLE
    ./woyShell.ps1 MARS
.EXAMPLE
    ./woyShell.ps1 SQL-SRV -Url ws://sql-srv.fritz.box:60000/ServiceCtrl/Shell -Token abc... -Merken
.EXAMPLE
    ./woyShell.ps1 MARS -Command 'Get-Service AufServiceNT'
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Rechner = 'MARS',
    [string]$Url,
    [string]$Token,
    [switch]$Merken,
    [string]$Command
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Rechner = $Rechner.ToUpperInvariant()
# Lokal (Verlauf je Zielrechner, Rueckfall fuer die Konfiguration)
$WoyDir = Join-Path $HOME '.woy'

#region Konfiguration
function Get-KonfigDatei {
    if ($env:WOYSHELL_CONFIG) { return $env:WOYSHELL_CONFIG }
    $cloud = if ($env:DEV_CLOUD) { $env:DEV_CLOUD }
             elseif ($IsWindows) { Join-Path $HOME 'iCloudDrive/Documents/Config' }
             elseif ($IsMacOS) { Join-Path $HOME 'Library/Mobile Documents/com~apple~CloudDocs/Documents/Config' }
    if ($cloud -and (Test-Path -LiteralPath $cloud -PathType Container)) { return Join-Path $cloud 'woyshell.json' }
    return Join-Path $WoyDir 'woyshell.json'
}
$KonfigDatei = Get-KonfigDatei

# Fruehere Orte - einmalig an den aktuellen verschieben
foreach ($alt in (Join-Path $HOME '.woyshell.json'), (Join-Path $WoyDir 'woyshell.json')) {
    if ($alt -ne $KonfigDatei -and -not (Test-Path -LiteralPath $KonfigDatei) -and (Test-Path -LiteralPath $alt)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $KonfigDatei) | Out-Null
        Move-Item -LiteralPath $alt -Destination $KonfigDatei
        Write-Host "Konfiguration verschoben: $alt -> $KonfigDatei" -ForegroundColor DarkGray
    }
}

function Read-Konfig {
    if (Test-Path -LiteralPath $KonfigDatei) {
        try { return Get-Content -LiteralPath $KonfigDatei -Raw | ConvertFrom-Json -AsHashtable } catch { }
    }
    return @{}
}

$konfig = Read-Konfig
$eintrag = if ($konfig.ContainsKey($Rechner)) { $konfig[$Rechner] } else { @{} }
if (-not $Url) { $Url = $eintrag['Url'] }
if (-not $Url) { $Url = "ws://$($Rechner.ToLowerInvariant()):60000/ServiceCtrl/Shell" }
if (-not $Token) { $Token = [Environment]::GetEnvironmentVariable("WOYSHELL_TOKEN_$($Rechner -replace '[^A-Z0-9]', '_')") }
if (-not $Token) { $Token = $eintrag['Token'] }
if (-not $Token) {
    throw "Kein Schluessel fuer $Rechner. Einmal: woyShell.ps1 -Rechner $Rechner -Token <Schluessel> -Merken (Schluessel aus dem woyControlCenter, Remote-Shell)"
}

if ($Merken) {
    # weitere Angaben des Eintrags (Mac, Adresse) bleiben erhalten
    $neu = @{} + $eintrag
    $neu['Url'] = $Url
    $neu['Token'] = $Token
    $konfig[$Rechner] = $neu
    New-Item -ItemType Directory -Force -Path (Split-Path $KonfigDatei) | Out-Null
    $konfig | ConvertTo-Json | Set-Content -LiteralPath $KonfigDatei -Encoding utf8
    if (-not $IsWindows) { chmod 600 $KonfigDatei }
    Write-Host "Gespeichert in $KonfigDatei" -ForegroundColor DarkGray
}
#endregion

#region Wecken
# 2026-11-15 Hubi/Claude: Rechner, die meist schlafen (MARS): steht im Eintrag "Mac", wird vor dem
# Verbinden der Port der Remote-Shell geprueft; antwortet er nicht, geht alle 15 s ein Wake-on-LAN-
# Paket raus, bis der Port offen ist (hoechstens 120 s). "Adresse" (optional) ist die LAN-Adresse fuer
# Pruefung und Broadcast, sonst der Rechnername aus der Url. Wie run mars (Mds/scripts/_mars.ps1).
function Test-Port([string]$Ziel, [int]$Port, [int]$Millisekunden = 2000) {
    $client = [Net.Sockets.TcpClient]::new()
    try { return ($client.ConnectAsync($Ziel, $Port).Wait($Millisekunden) -and $client.Connected) }
    catch { return $false }
    finally { $client.Dispose() }
}

# Wake-on-LAN (6 x FF, 16 x MAC) auf UDP 7 und 9 an den allgemeinen Broadcast und an x.x.x.255 von $LanAdresse
function Send-WakeOnLan([string]$MacAdresse, [string]$LanAdresse) {
    $bytes = [byte[]]($MacAdresse -split '[-:]' | ForEach-Object { [Convert]::ToByte($_, 16) })
    if ($bytes.Count -ne 6) { throw "Ungueltige MAC-Adresse fuer ${Rechner}: $MacAdresse" }
    $paket = [byte[]](@(0xFF) * 6) + (@($bytes) * 16)
    $udp = [Net.Sockets.UdpClient]::new()
    try {
        $udp.EnableBroadcast = $true
        $ziele = @([Net.IPAddress]::Broadcast)
        if ($LanAdresse -match '^(\d+\.\d+\.\d+)\.\d+$') { $ziele += [Net.IPAddress]::Parse("$($Matches[1]).255") }
        foreach ($ziel in $ziele) {
            foreach ($port in 7, 9) { [void]$udp.Send($paket, $paket.Length, [Net.IPEndPoint]::new($ziel, $port)) }
        }
    }
    finally { $udp.Dispose() }
}

function Invoke-Wecken([int]$Sekunden = 120) {
    $mac = $eintrag['Mac']
    if (-not $mac) { return }
    $uri = [Uri]$Url
    $ziel = if ($eintrag['Adresse']) { $eintrag['Adresse'] } else { $uri.Host }
    if (Test-Port $ziel $uri.Port) { return }

    Write-Host "$Rechner ($ziel) antwortet nicht - Wake-on-LAN an $mac ..." -ForegroundColor Yellow
    $start = [DateTime]::UtcNow
    $letztes = [DateTime]::MinValue
    while (-not (Test-Port $ziel $uri.Port)) {
        $vergangen = ([DateTime]::UtcNow - $start).TotalSeconds
        if ($vergangen -gt $Sekunden) {
            throw "$Rechner ist nach $Sekunden s nicht erreichbar (Wake-on-LAN im BIOS/Netzwerkadapter aktiv? AufServiceNT laeuft?)"
        }
        if (([DateTime]::UtcNow - $letztes).TotalSeconds -ge 15) {
            Send-WakeOnLan $mac $ziel
            $letztes = [DateTime]::UtcNow
        }
        Write-Host ("  ... warte auf {0} ({1:N0} s)" -f $Rechner, $vergangen) -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
    Write-Host ("{0} ist wach ({1:N0} s)" -f $Rechner, ([DateTime]::UtcNow - $start).TotalSeconds) -ForegroundColor Green
}
#endregion

#region WebSocket
$script:ws = $null
$script:empfang = $null
$script:cwd = ''

function Send-Msg([hashtable]$m) {
    $b = [Text.Encoding]::UTF8.GetBytes(($m | ConvertTo-Json -Compress -Depth 4))
    $script:ws.SendAsync([ArraySegment[byte]]::new($b), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
}

#endregion

# Empfang: ReceiveAsync laeuft als Task, gewartet wird in 100-ms-Schritten - dazwischen
# wird Strg+C abgefragt.
$script:puffer = [byte[]]::new(65536)
$script:teile = [IO.MemoryStream]::new()

function Receive-Msg([int]$TimeoutMs = -1, [switch]$Abbrechbar) {
    while ($true) {
        if ($null -eq $script:empfang) {
            $script:empfang = $script:ws.ReceiveAsync([ArraySegment[byte]]::new($script:puffer), [Threading.CancellationToken]::None)
        }
        $start = [DateTime]::UtcNow
        while (-not $script:empfang.Wait(100)) {
            if ($Abbrechbar) {
                try {
                    while ([Console]::KeyAvailable) {
                        $k = [Console]::ReadKey($true)
                        if ($k.Key -eq [ConsoleKey]::C -and ($k.Modifiers -band [ConsoleModifiers]::Control)) {
                            Send-Msg @{ t = 'stop' }
                        }
                    }
                }
                catch { }
            }
            if ($TimeoutMs -ge 0 -and ([DateTime]::UtcNow - $start).TotalMilliseconds -gt $TimeoutMs) { return 'TIMEOUT' }
        }
        $r = $script:empfang.GetAwaiter().GetResult()
        $script:empfang = $null
        if ($r.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close) { return $null }
        $script:teile.Write($script:puffer, 0, $r.Count)
        if ($r.EndOfMessage) {
            $txt = [Text.Encoding]::UTF8.GetString($script:teile.ToArray())
            $script:teile.SetLength(0)
            return ($txt | ConvertFrom-Json)
        }
    }
}

function Get-Hmac([string]$Key, [string]$Text) {
    $h = [Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($Key))
    try { return ([Convert]::ToHexString($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).ToLowerInvariant() }
    finally { $h.Dispose() }
}

function Get-Breite {
    try { $w = [Console]::WindowWidth - 1; if ($w -ge 40) { return $w } } catch { }
    return 120
}

function Write-Ausgabe($m) {
    switch ($m.t) {
        'out' { [Console]::Out.Write($m.s) }
        'err' { Write-Host $m.s -NoNewline -ForegroundColor Red }
        'warn' { Write-Host $m.s -NoNewline -ForegroundColor Yellow }
        'info' { Write-Host $m.s -NoNewline -ForegroundColor Cyan }
        'fehler' { Write-Host "[$Rechner] $($m.s)" -ForegroundColor Red }
    }
}

# Markierung, die Update/DBS auf dem Dienst ausgeben: gleich bricht die Verbindung ab, weil
# AufServiceNT neu installiert wird - danach neu verbinden (siehe Wait-Wiederverbinden).
$K_Marke = '##WOYSHELL:WIEDERVERBINDEN##'
$script:wiederverbinden = $false

# Fuehrt ein Kommando aus und gibt die Ausgaben aus. Ergebnis: $true/$false, $null = Verbindung weg
function Invoke-Remote([string]$Text) {
    $script:wiederverbinden = $false
    $alt = $null
    try { $alt = [Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput = $true } catch { }
    try {
        Send-Msg @{ t = 'cmd'; text = $Text; width = (Get-Breite) }
        while ($true) {
            $m = Receive-Msg -Abbrechbar
            if ($null -eq $m) { return $null }
            if ($m.t -eq 'done') { $script:cwd = $m.cwd; return [bool]$m.ok }
            if ($m.t -eq 'fehler') { Write-Ausgabe $m; return $null }
            if ($m.t -eq 'out' -and $m.s.Contains($K_Marke)) {
                $script:wiederverbinden = $true
                $m.s = $m.s.Replace($K_Marke, '').Trim()
                if (-not $m.s) { continue }
                $m.s += "`n"
            }
            Write-Ausgabe $m
        }
    }
    catch {
        # Verbindung abgerissen (z. B. Dienst beendet) - wie geschlossen behandeln
        return $null
    }
    finally {
        if ($null -ne $alt) { try { [Console]::TreatControlCAsInput = $alt } catch { } }
    }
}

#region Tab-Vervollstaendigung auf dem Zielrechner (Windows-Art: jedes Tab der naechste Treffer)
$script:tab = $null
function Invoke-RemoteTab([int]$Richtung) {
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    $t = $script:tab
    if ($t -and $t.Ergebnis -eq $line -and $t.Cursor -eq $cursor) {
        $t.Index = ($t.Index + $Richtung + $t.Items.Count) % $t.Items.Count
    }
    else {
        Send-Msg @{ t = 'complete'; text = $line; pos = $cursor }
        do { $m = Receive-Msg -TimeoutMs 5000 } while ($m -and $m -ne 'TIMEOUT' -and $m.t -ne 'completion')
        if (-not $m -or $m -eq 'TIMEOUT' -or @($m.items).Count -eq 0) { $script:tab = $null; return }
        $t = @{ Original = $line; Start = [int]$m.start; Length = [int]$m.length; Items = @($m.items); Index = $(if ($Richtung -lt 0) { @($m.items).Count - 1 } else { 0 }) }
    }
    $neu = $t.Original.Substring(0, $t.Start) + $t.Items[$t.Index] + $t.Original.Substring($t.Start + $t.Length)
    [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $neu)
    $t.Cursor = $t.Start + $t.Items[$t.Index].Length
    [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($t.Cursor)
    $line2 = $null; $c2 = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line2, [ref]$c2)
    $t.Ergebnis = $line2
    $t.Cursor = $c2
    $script:tab = $t
}
#endregion

# [MARS*] = Sitzung mit Administratorrechten (Dienstkonto ist Administrator), [MARS] = ohne
function Get-Prompt { "[$Rechner$(if ($script:admin) { '*' })] $($script:cwd)> " }

#region Verbinden und anmelden
# Baut die Verbindung auf und meldet sich an; Ergebnis ist die ready-Nachricht. Wirft bei Fehler.
function Connect-Shell {
    if ($script:ws) { try { $script:ws.Dispose() } catch { } }
    $script:empfang = $null
    $script:teile.SetLength(0)
    $script:ws = [Net.WebSockets.ClientWebSocket]::new()
    $script:ws.Options.KeepAliveInterval = [TimeSpan]::FromSeconds(30)
    try {
        $verbinde = $script:ws.ConnectAsync([Uri]$Url, [Threading.CancellationToken]::None)
        if (-not $verbinde.Wait(10000)) { throw "keine Antwort in 10 s" }
    }
    catch {
        $msg = $_.Exception.GetBaseException().Message
        throw "Verbindung zu $Url fehlgeschlagen: $msg (AufServiceNT laeuft? Remote-Shell im woyControlCenter eingeschaltet und Dienst neu gestartet? Port 60000 in der Firewall frei?)"
    }

    $hello = Receive-Msg -TimeoutMs 10000
    if (-not $hello -or $hello -eq 'TIMEOUT' -or $hello.t -ne 'hello') { throw "Unerwartete Antwort von $Url" }
    $cnonce = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    Send-Msg @{ t = 'auth'; mac = (Get-Hmac $Token $hello.nonce); cnonce = $cnonce }
    $antwort = Receive-Msg -TimeoutMs 30000
    if (-not $antwort -or $antwort -eq 'TIMEOUT') { throw "Keine Antwort auf die Anmeldung" }
    if ($antwort.t -ne 'ready') { throw "[$Rechner] $($antwort.s)" }
    if ($antwort.proof -ne (Get-Hmac $Token "srv|$($hello.nonce)|$cnonce")) {
        throw "Gegenstelle $Url kennt den Schluessel nicht - Verbindung abgebrochen"
    }
    $script:Rechner = $antwort.rechner
    # Aeltere Dienste melden konto/admin noch nicht
    $script:admin = [bool]($antwort.PSObject.Properties['admin'] -and $antwort.admin)
    $script:konto = if ($antwort.PSObject.Properties['konto']) { $antwort.konto } else { '' }
    $script:cwd = $antwort.cwd
    return $antwort
}

# Nach Update/DBS: AufServiceNT wird neu installiert, die Verbindung bricht ab. Wartet, bis
# der Dienst wieder antwortet (hoechstens $Sekunden), verbindet neu und zeigt mit
# "UpdateLog -Wait" das Protokoll, sobald das Update fertig ist. $true = es geht weiter.
# 2026-11-15 Hubi/Claude: Auch wenn die Verbindung erst waehrend "UpdateLog -Wait" abbricht
#   (der Dienst war beim ersten Neuverbinden noch der alte), wird weiter gewartet - hoechstens 3-mal.
function Wait-Wiederverbinden([int]$Sekunden = 120) {
    Write-Host "[$Rechner] AufServiceNT wird neu installiert, warte bis zu $Sekunden s auf den Dienst ..." -ForegroundColor Yellow
    $ende = [DateTime]::UtcNow.AddSeconds($Sekunden)
    $abbrueche = 0
    Start-Sleep -Seconds 5
    while ([DateTime]::UtcNow -lt $ende) {
        try {
            $null = Connect-Shell
            Write-Host ''
            Write-Host "[$Rechner] wieder verbunden" -ForegroundColor Green
            $ok = Invoke-Remote 'UpdateLog -Wait'
            if ($null -ne $ok) { return $true }
            if (++$abbrueche -ge 3) { break }
            Write-Host "[$Rechner] Verbindung erneut beendet - warte weiter ..." -ForegroundColor Yellow
            $ende = [DateTime]::UtcNow.AddSeconds($Sekunden)
            Start-Sleep -Seconds 5
        }
        catch {
            Write-Host '.' -NoNewline -ForegroundColor DarkGray
            Start-Sleep -Seconds 3
        }
    }
    Write-Host ''
    Write-Host "[$Rechner] Dienst nach $Sekunden s nicht erreichbar - spaeter neu verbinden und 'UpdateLog -Wait' aufrufen" -ForegroundColor Red
    return $false
}

# Update-Befehle auch erkennen, wenn ein aelterer Dienst die Markierung noch nicht sendet
function Test-UpdateBefehl([string]$Text) {
    return $Text -match '^\s*(Update|woyControlCenter\s+[-/]?(u|up|upd|upda|updat|update|d|db|dbs))\b'
}

Invoke-Wecken
$ready = Connect-Shell
#endregion

$exitCode = 0
$psrl = $null
$altPrompt = $null
try {
    if ($Command) {
        $ok = Invoke-Remote $Command
        # Markierung gesehen: immer neu verbinden, auch wenn der Befehl vor dem Abbruch fertig war
        if ($script:wiederverbinden -or ($null -eq $ok -and (Test-UpdateBefehl $Command))) {
            $ok = Wait-Wiederverbinden
        }
        $exitCode = if ($null -eq $ok) { 2 } elseif ($ok) { 0 } else { 1 }
    }
    else {

    Write-Host "Remote-Shell $Rechner ($Url) - exit beendet, Strg+C bricht ab" -ForegroundColor DarkGray
    if ($script:konto) {
        if ($script:admin) { Write-Host "Konto $($script:konto) - Administrator (Prompt [$Rechner*])" -ForegroundColor DarkGray }
        else { Write-Host "Konto $($script:konto) - OHNE Administratorrechte (Prompt [$Rechner])" -ForegroundColor Yellow }
    }
    if ($ready.PSObject.Properties['banner'] -and $ready.banner) {
        foreach ($z in ($ready.banner -split "`n")) {
            Write-Host $z -ForegroundColor $(if ($z.StartsWith('!!')) { 'Red' } else { 'DarkGray' })
        }
    }

    # PSReadLine fuer Zeilenbearbeitung und Verlauf (eigener Verlauf je Zielrechner)
    if (-not [Console]::IsInputRedirected -and (Get-Module PSReadLine -ListAvailable)) {
        Import-Module PSReadLine
        $o = Get-PSReadLineOption
        $psrl = @{
            HistorySavePath  = $o.HistorySavePath
            PredictionSource = $o.PredictionSource
            # macOS/Linux (Emacs-Modus): Shift+Tab ist nicht belegt -> $null statt Abbruch unter StrictMode
            Tab              = Get-PSReadLineKeyHandler -Chord Tab | Select-Object -First 1 -ExpandProperty Function
            ShiftTab         = Get-PSReadLineKeyHandler -Chord Shift+Tab | Select-Object -First 1 -ExpandProperty Function
        }
        New-Item -ItemType Directory -Force -Path $WoyDir | Out-Null
        Set-PSReadLineOption -HistorySavePath (Join-Path $WoyDir "woyshell_history_$Rechner.txt") -PredictionSource None
        Set-PSReadLineKeyHandler -Chord Tab -ScriptBlock { Invoke-RemoteTab 1 }
        Set-PSReadLineKeyHandler -Chord Shift+Tab -ScriptBlock { Invoke-RemoteTab -1 }
        # PSReadLine zeichnet bei Bedarf den Prompt neu und ruft dafuer "prompt"
        $altPrompt = $function:global:prompt
        $global:woyShellPrompt = { Get-Prompt }
        $function:global:prompt = { & $global:woyShellPrompt }
    }

    while ($true) {
        Write-Host (Get-Prompt) -NoNewline -ForegroundColor Green
        $script:tab = $null
        $zeile = if ($psrl) {
            [Microsoft.PowerShell.PSConsoleReadLine]::ReadLine($Host.Runspace, $ExecutionContext, $null)
        }
        else {
            [Console]::ReadLine()
        }
        if ($null -eq $zeile) { break }
        $zeile = $zeile.TrimEnd()
        if ($zeile.Trim() -in 'exit', 'quit', 'logout') { break }
        if ($zeile.Trim().Length -eq 0) { continue }
        $ok = Invoke-Remote $zeile
        if ($script:wiederverbinden -or ($null -eq $ok -and (Test-UpdateBefehl $zeile))) {
            if (Wait-Wiederverbinden) { continue }
            $exitCode = 2
            break
        }
        if ($null -eq $ok) {
            Write-Host "[$Rechner] Verbindung beendet" -ForegroundColor Red
            $exitCode = 2
            break
        }
    }
    }
}
finally {
    if ($psrl) {
        Set-PSReadLineOption -HistorySavePath $psrl.HistorySavePath -PredictionSource $psrl.PredictionSource
        # vorher unbelegte Taste wieder freigeben, sonst bliebe die Remote-Vervollstaendigung lokal haengen
        if ($psrl.Tab) { Set-PSReadLineKeyHandler -Chord Tab -Function $psrl.Tab } else { Remove-PSReadLineKeyHandler -Chord Tab }
        if ($psrl.ShiftTab) { Set-PSReadLineKeyHandler -Chord Shift+Tab -Function $psrl.ShiftTab } else { Remove-PSReadLineKeyHandler -Chord Shift+Tab }
        if ($altPrompt) { $function:global:prompt = $altPrompt }
        Remove-Variable -Name woyShellPrompt -Scope Global -ErrorAction SilentlyContinue
    }
    if ($script:ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
        try { $script:ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Ende', [Threading.CancellationToken]::None).Wait(3000) | Out-Null } catch { }
    }
    $script:ws.Dispose()
}
exit $exitCode
