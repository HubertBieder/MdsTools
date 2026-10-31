#======================================================================
# Datei:        Output.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Einheitliche Konsolenausgabe (Ueberschriften, Start/Info/Erfolg/Fehler).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (SkriptModule\*.psm1) uebernommen,
#                            Cmdlets umbenannt (siehe MdsTools.md, Umbenennungen)
#
# Oeffentlich: Write-Header, Write-Start, Write-Info, Write-Success, Write-Fail
#======================================================================

# [intern] Baut eine gefuellte Statuszeile ("---  Message  ---...") fester Breite.
function New-StatusLine([string] $Message="", [string] $Prefix="---", [char] $FillCharacter='-', [int] $Width=60)
{
    [string] $txt = $Prefix
    if ($Message.Length -gt 0)
    {
        $txt = "$txt  $Message  $txt"
    }

    return ($FillCharacter + $txt.PadRight($Width, $FillCharacter) + "$FillCharacter$FillCharacter$FillCharacter")
}

# [public] Write-Header — Gibt eine hervorgehobene Ueberschrift aus ($Level 0..2 = Farbe/Stil).
function Write-Header([string] $Message="", [int] $Level=0)
{
    $s = '+'
    $c = '='
    [int] $max = 78
    switch ($Level)
    {
        0 {$s ='#'; $c = '='; $max = 86}
        1 {$s ='+'; $c = '-'; $max = 86}
        2 {$s ='+'; $c = '-'; $max = 86}
    }
    $txt = $s.PadRight(6, $c) + $Message.PadRight($max, $c) + "$c$c$c$c$c$s";
    switch ($Level)
    {
        1 { Write-Host ""; Write-Host $txt -ForegroundColor Black -BackgroundColor DarkGreen -NoNewline; Write-Host " " -ForegroundColor Gray -BackgroundColor Black }
        2 { Write-Host $txt -ForegroundColor Black -BackgroundColor Cyan -NoNewline; Write-Host " "  -ForegroundColor Gray -BackgroundColor Black}
        Default {Write-Host ""; Write-Host $txt -ForegroundColor DarkGray -BackgroundColor DarkBlue -NoNewline; Write-Host " " -ForegroundColor Gray -BackgroundColor Black }
    }               
    Write-Host ""
}

# [public] Write-Start — Gibt eine Startzeile (invertiert) fuer den Beginn eines Vorgangs aus.
function Write-Start([string] $Message="")
{
    [string] $txt = New-StatusLine -Message $Message -Prefix "===" -FillCharacter '=' -Width 68
    $txt = "#" + $txt + "#"
    Write-Host $txt -ForegroundColor Black -BackgroundColor Gray -NoNewline; 
    Write-Host "" -ForegroundColor Gray -BackgroundColor Black 
}

# [public] Write-Info — Gibt eine Info-Statuszeile aus.
function Write-Info([string] $Message="")
{
    [string] $txt = New-StatusLine -Message $Message -Prefix "---" -FillCharacter '-'
    $txt = "*" + $txt
    Write-Host $txt
}

# [public] Write-Success — Gibt eine Erfolgs-Statuszeile (gruen) aus.
function Write-Success([string] $Message="")
{
    [string] $txt = New-StatusLine -Message $Message -Prefix "---" -FillCharacter '-'
    $txt = "+" + $txt
    Write-Host $txt -ForegroundColor DarkGreen 
}

# [public] Write-Fail — Gibt eine Fehler-Statuszeile (rot) aus.
function Write-Fail([string] $Message="")
{
    [string] $txt = New-StatusLine -Message $Message -Prefix "---" -FillCharacter '-'
    $txt = "!" + $txt
    Write-Host $txt -ForegroundColor DarkRed
}
