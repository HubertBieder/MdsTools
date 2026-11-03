#======================================================================
# Datei:        Auftrag.ps1  (wird von InitMDS.ps1 geladen, nur Windows)
# Beschreibung: Hilfsfunktionen fuer das Bauen der Auftragsabwicklung, aufgerufen aus
#               Auf/scripts/Init.ps1 und Auf/scripts/Post.ps1 (mk auf).
#               Pfade ueber die Legacy-Adressen $mdsWoySrc, $mdsWoyBin (InitModule.ps1).
#
# Versionshistorie:
#   2026-11-03  Hubi/Claude  Aus mdsProfile.ps1 uebernommen (Clear-WoyProcess, Write-WoyVersionCS,
#                            Write-DateiListe); $woyVersion -> $mdsWoy, $woyBaseDir -> $mdsWoySrc
#   2026-11-03  Hubi/Claude  Get-WoyServerShare (aus Auf/scripts/_copy.ps1, auch fuer _version.ps1)
#======================================================================

# [global] UNC-Wurzel der Freigabe woyAufInstall auf TEST-SRV ('t...') bzw. SQL-SRV ('s...'), sonst $null.
#   Adressen aus der woy.env (WOY_TESTSRV, WOY_SQLSRV), ohne Eintrag TEST-SRV bzw. SQL-SRV.
function global:Get-WoyServerShare([string] $Name) {
    [string] $address = switch -Regex ($Name.Trim()) {
        '^(?i)t' { Get-WoyValue -Key 'WOY_TESTSRV' -Default 'TEST-SRV' }
        '^(?i)s' { Get-WoyValue -Key 'WOY_SQLSRV' -Default 'SQL-SRV' }
        default { '' }
    }
    if (-not $address) {
        Write-Error "Unbekannter Server '$Name' (erwartet: t... fuer TEST-SRV oder s... fuer SQL-SRV)."
        return $null
    }
    return "\\$address\woyAufInstall"
}

# [global] Beendet Prozesse der Auftragsabwicklung, damit ihre Dateien ueberschrieben werden koennen.
function global:Clear-WoyProcess() {
    Get-Process |
    Where-Object {
        $n = $_.Name.ToUpperInvariant()
        $n.Contains('AUFTRAG') -or $n.Contains('TAPISERVER') -or $n.Contains('ADMINDBS') -or $n.Contains('WOYCONTROLCENTER')
    } |
    ForEach-Object { $_.Kill() }
}

# [global] Schreibt Source\Libs\AuftragLib\woyAuftrag.Global\Version.cs (Release = MMdd, MajorVersion = $mdsWoy).
# Rueckgabewert: "<Version>.<MMdd> ==> <Datei>" oder "! Fehler <Datei>".
function global:Write-WoyVersionCS([string] $BaseDir = $mdsWoySrc) {
    if ([string]::IsNullOrWhiteSpace($BaseDir)) { $BaseDir = $mdsWoySrc }

    $td = Get-Date
    [string] $mark = $td.ToString('MMdd')
    $Ziel = Join-Path $BaseDir 'Source\Libs\AuftragLib\woyAuftrag.Global\Version.cs'
    if (Test-Path -LiteralPath $Ziel) {
        (Get-Item -LiteralPath $Ziel).IsReadOnly = $false
        Remove-Item -LiteralPath $Ziel -Force
    }
    [string[]] $zeilen = @(
        "namespace woyAuftrag"
        "{"
        "   /// Erzeugt am $($td.ToShortDateString()) um $($td.ToShortTimeString()) PowerShellScript MdsTools"
        "   /// Net10 Version"
        "   /// V$mdsWoy"
        "   public class aktVersion"
        "   {"
        "       public static int Release = $mark;"
        "       public static int MajorVersion = $mdsWoy;"
        "       public static string Text = `"`";"
        "   }"
        "}"
    )
    [System.IO.File]::WriteAllLines($Ziel, $zeilen)
    if (Test-Path -LiteralPath $Ziel) {
        return "$mdsWoy.$mark ==> $Ziel"
    }
    return "! Fehler $Ziel"
}

# [global] Schreibt die Dateiliste.txt des Deploy-Ordners (Version, Datum, Kennzahlen von AufDB.repos, Dateinamen).
function global:Write-DateiListe([string] $dir, [int] $ver = $mdsWoy) {
    $Ziel = Join-Path $dir 'Dateiliste.txt'
    $td = Get-Date
    if (Test-Path -LiteralPath $Ziel) {
        (Get-Item -LiteralPath $Ziel).IsReadOnly = $false
        Remove-Item -LiteralPath $Ziel -Force
    }
    Remove-Item -Path (Join-Path $dir '*.bak') -Force -ErrorAction SilentlyContinue
    "! V $ver.0_$($td.ToString('MMdd'))" | Set-Content -LiteralPath $Ziel -Encoding UTF8 -Force
    "! Erzeugt am $($td.ToShortDateString()) um $($td.ToShortTimeString())" | Add-Content -LiteralPath $Ziel
    $repos = Join-Path $dir 'AufDB.repos'
    if (Test-Path -LiteralPath $repos) {
        $datei = @(Get-Content -LiteralPath $repos)
        "!# Zeilen : $($datei.Count)" | Add-Content -LiteralPath $Ziel
        "!@ Zeichen: $(($datei | Measure-Object -Property Length -Sum).Sum)" | Add-Content -LiteralPath $Ziel
        "!* $($td.ToShortDateString())" | Add-Content -LiteralPath $Ziel
    }
    (Get-ChildItem -Path (Join-Path $dir '*.*') -File).Name | Add-Content -LiteralPath $Ziel
}
