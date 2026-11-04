#Requires -Version 7.6
<#
.SYNOPSIS
    Weckt MARS bei Bedarf auf und aktiviert die SMB-Freigaben woyCode und woyAufInstall (run mars, nur macOS).

.DESCRIPTION
    Globales run-Skript aus Mds/scripts, gilt von ueberall:
      1. Prueft per TCP-Port 445 (SMB), ob MARS antwortet - ohne die Freigaben anzufassen, denn eine
         eingebundene Freigabe eines schlafenden Rechners blockiert jeden Zugriff.
      2. Antwortet MARS nicht: Wake-on-LAN-Paket senden (alle 15 s wiederholt) und warten, bis Port 445
         offen ist (hoechstens -Timeout Sekunden).
      3. Je Freigabe: eine haengende Einbindung unter /Volumes wird mit umount -f geloest; fehlt sie,
         wird sie mit "open smb://..." neu eingebunden (Passwort aus dem macOS-Schluesselbund, beim
         ersten Mal fragt der Finder).
      4. Mit -Go wird danach in die erste Freigabe gewechselt.

.PARAMETER Rechner
    Name des Rechners fuer die SMB-Freigaben (wie im Schluesselbund). Standard: mars

.PARAMETER Adresse
    LAN-Adresse von MARS fuer die Erreichbarkeitspruefung (unabhaengig von der Namensaufloesung).
    Das Wake-on-LAN-Paket geht zusaetzlich an den Broadcast dieses Netzes (x.x.x.255).

.PARAMETER Freigaben
    SMB-Freigaben, die aktiviert werden. Standard: woyCode, woyAufInstall

.PARAMETER Timeout
    Sekunden, die nach dem Wecken hoechstens gewartet wird. Standard: 120

.PARAMETER Go
    Nach dem Verbinden in die erste Freigabe (/Volumes/woyCode) wechseln.

.EXAMPLE
    run mars
    run mars -Go
    run mars -Verbose

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-11-04  Hubi/Claude   Erste Version
#>
[CmdletBinding()]
param(
    [string] $Rechner = 'mars',

    # LAN-Adresse von MARS, Stand 2026-11-04
    [string] $Adresse = '192.168.104.59',

    [string] $Benutzer = 'hubert',

    [string[]] $Freigaben = @('woyCode', 'woyAufInstall'),

    # MAC-Adresse des LAN-Anschlusses von MARS (ASUS-Mainboard), Stand 2026-11-04 aus dem ARP-Cache von LUNA
    [string] $Mac = 'F0-2F-74-8B-62-06',

    [int] $Timeout = 120,

    [switch] $Go
)

if (-not $IsMacOS) {
    Write-Fail 'run mars ist nur fuer macOS gedacht (Freigaben von MARS auf LUNA einbinden).'
    exit 1
}

# [intern] $true, wenn der Rechner auf dem TCP-Port antwortet (innerhalb von $Millisekunden).
function Test-Port([string] $Ziel, [int] $Port = 445, [int] $Millisekunden = 2000) {
    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $versuch = $client.ConnectAsync($Ziel, $Port)
        return ($versuch.Wait($Millisekunden) -and $client.Connected)
    }
    catch { return $false }
    finally { $client.Dispose() }
}

# [intern] Sendet ein Wake-on-LAN-Paket (6 x FF, dann 16 x MAC) auf UDP 7 und 9: an den allgemeinen
# Broadcast und an den Broadcast des LAN von $LanAdresse (x.x.x.255, /24).
function Send-WakeOnLan([string] $MacAdresse, [string] $LanAdresse) {
    $bytes = [byte[]]($MacAdresse -split '[-:]' | ForEach-Object { [Convert]::ToByte($_, 16) })
    if ($bytes.Count -ne 6) { throw "Ungueltige MAC-Adresse: $MacAdresse" }
    $paket = [byte[]](@(0xFF) * 6) + (@($bytes) * 16)
    $udp = [System.Net.Sockets.UdpClient]::new()
    try {
        $udp.EnableBroadcast = $true
        $ziele = @([System.Net.IPAddress]::Broadcast)
        if ($LanAdresse -match '^(\d+\.\d+\.\d+)\.\d+$') { $ziele += [System.Net.IPAddress]::Parse("$($Matches[1]).255") }
        foreach ($ziel in $ziele) {
            foreach ($port in 7, 9) {
                [void]$udp.Send($paket, $paket.Length, [System.Net.IPEndPoint]::new($ziel, $port))
            }
        }
    }
    finally { $udp.Dispose() }
}

# [intern] $true, wenn unter $Pfad eine SMB-Freigabe eingebunden ist (laut mount, ohne Zugriff).
function Test-Eingebunden([string] $Pfad) {
    [bool](mount | Where-Object { $_ -like "* on $Pfad (smbfs*" })
}

# [intern] $true, wenn der Ordner innerhalb von $Millisekunden lesbar ist. Ein Zugriff auf eine haengende
# Freigabe blockiert, deshalb in einem eigenen Prozess mit Zeitlimit.
function Test-Lesbar([string] $Pfad, [int] $Millisekunden = 10000) {
    $info = [System.Diagnostics.ProcessStartInfo]::new('/bin/ls', @($Pfad))
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $prozess = [System.Diagnostics.Process]::Start($info)
    $prozess.StandardOutput.ReadToEndAsync() | Out-Null
    if (-not $prozess.WaitForExit($Millisekunden)) {
        try { $prozess.Kill() } catch { Write-Verbose "ls laesst sich nicht beenden: $_" }
        return $false
    }
    return ($prozess.ExitCode -eq 0)
}

# --- 1. und 2. Erreichbarkeit pruefen, bei Bedarf wecken ---
$start = Get-Date
if (Test-Port $Adresse) {
    Write-Info "$Rechner ist wach."
}
else {
    Write-Info "$Rechner ($Adresse) antwortet nicht - Wake-on-LAN an $Mac ..."
    $letztesWecken = [datetime]::MinValue
    while (-not (Test-Port $Adresse)) {
        $vergangen = ((Get-Date) - $start).TotalSeconds
        if ($vergangen -gt $Timeout) {
            Write-Fail "$Rechner ist nach $Timeout s nicht erreichbar (Wake-on-LAN im BIOS/Netzwerkadapter aktiv?)."
            exit 1
        }
        if (((Get-Date) - $letztesWecken).TotalSeconds -ge 15) {
            Send-WakeOnLan $Mac $Adresse
            $letztesWecken = Get-Date
        }
        Write-Host ("  ... warte auf {0} ({1:N0} s)" -f $Rechner, $vergangen) -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
    }
    Write-Info ("{0} ist wach ({1:N0} s)." -f $Rechner, ((Get-Date) - $start).TotalSeconds)
}

# --- 3. Freigaben aktivieren ---
$fehler = 0
foreach ($freigabe in $Freigaben) {
    $pfad = "/Volumes/$freigabe"
    if (Test-Eingebunden $pfad) {
        # Nach dem Aufwachen verbindet macOS eine vorhandene Einbindung meist selbst wieder.
        if (Test-Lesbar $pfad) {
            Write-Success "$freigabe ist verbunden: $pfad"
            continue
        }
        Write-Info "$freigabe haengt - Einbindung wird geloest ..."
        umount -f $pfad 2>$null
        if (Test-Eingebunden $pfad) { diskutil unmount force $pfad 2>&1 | Write-Verbose }
    }
    Write-Info "Verbinde smb://$Benutzer@$Rechner/$freigabe ..."
    open "smb://$Benutzer@$Rechner/$freigabe"
    $ende = (Get-Date).AddSeconds(30)
    while (-not ((Test-Eingebunden $pfad) -and (Test-Lesbar $pfad 5000)) -and (Get-Date) -lt $ende) {
        Start-Sleep -Seconds 1
    }
    if ((Test-Eingebunden $pfad) -and (Test-Lesbar $pfad 5000)) {
        Write-Success "$freigabe ist verbunden: $pfad"
    }
    else {
        Write-Fail "$freigabe konnte nicht eingebunden werden (Anmeldung im Finder abgebrochen?)."
        $fehler++
    }
}

# --- 4. Optional in die erste Freigabe wechseln ---
if ($Go -and $fehler -eq 0 -and $Freigaben) {
    Set-Location "/Volumes/$($Freigaben[0])"
}
if ($fehler -gt 0) { exit 1 }
