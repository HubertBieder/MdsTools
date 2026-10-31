#======================================================================
# Datei:        WoyEnv.ps1  (wird von InitMDS.ps1 geladen, nur Windows)
# Beschreibung: Liest rechnerspezifische Werte und Anmeldedaten aus der woy.env.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (Skripte/InitModule.ps1) uebernommen
#======================================================================

# [global] Liefert das massgebliche Home-Verzeichnis (%USERPROFILE%, nicht $HOME).
function global:Get-WoyEnvHome {
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE) -and (Test-Path -LiteralPath $env:USERPROFILE)) {
        return $env:USERPROFILE
    }
    return $HOME
}

# [global] Ermittelt den Pfad der woy.env (WOY_ENV_FILE -> <Home>\.woy\woy.env -> <Repo>\.env).
function global:Get-WoyEnvPath {
    if (-not [string]::IsNullOrWhiteSpace($env:WOY_ENV_FILE)) {
        return $env:WOY_ENV_FILE
    }

    $candidates = @( (Join-Path (Get-WoyEnvHome) '.woy/woy.env') )

    if ($PSScriptRoot) {
        # Entwicklung: .env in der Repo-Wurzel (zwei Ebenen ueber Skripte).
        $repoEnv = Join-Path $PSScriptRoot '..\..\..\.env'
        try { $repoEnv = [System.IO.Path]::GetFullPath($repoEnv) } catch { }
        $candidates += $repoEnv
    }

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return $c }
    }

    return $candidates[0]
}

# [global] Liest die woy.env (KEY=VALUE) in eine gecachte Hashtable. Mit -Refresh neu einlesen.
function global:Import-WoyEnv {
    [CmdletBinding()]
    param([switch] $Refresh)

    if (-not $Refresh -and ($Global:WoyEnvCache -is [hashtable])) {
        return $Global:WoyEnvCache
    }

    $path = Get-WoyEnvPath
    $map = @{}

    if (Test-Path -LiteralPath $path -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $path) {
            $t = $line.Trim()
            if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
            $idx = $t.IndexOf('=')
            if ($idx -lt 1) { continue }
            $key = $t.Substring(0, $idx).Trim()
            $val = $t.Substring($idx + 1).Trim()
            # Umschliessende Anfuehrungszeichen entfernen
            if ($val.Length -ge 2 -and
                (($val[0] -eq '"' -and $val[-1] -eq '"') -or
                 ($val[0] -eq "'" -and $val[-1] -eq "'"))) {
                $val = $val.Substring(1, $val.Length - 2)
            }
            $map[$key] = $val
        }
    }
    else {
        Write-Warning "woy.env nicht gefunden: $path (Vorlage: .env.example)."
    }

    $Global:WoyEnvCache = $map
    return $map
}

# [global] Baut eine PSCredential aus der woy.env (WOY_<NAME>_USER/_PASS). '*'/'!' -> interaktiv.
# Rueckgabewert: PSCredential oder $null (Aufrufer bricht dann ab).
function global:Get-WoyCredential {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Logischer Name, z. B. 'local' oder 'server'")]
        [string] $Name,

        [switch] $Refresh
    )

    $envMap = Import-WoyEnv -Refresh:$Refresh
    $prefix = "WOY_" + $Name.ToUpper()
    $user = $envMap["${prefix}_USER"]
    $pass = $envMap["${prefix}_PASS"]

    # Platzhalter '*' oder '!' bei User oder Passwort -> beide interaktiv erfragen.
    $askUser = $user -eq '*' -or $user -eq '!'
    $askPass = $pass -eq '*' -or $pass -eq '!'
    if ($askUser -or $askPass) {
        # Einmal eingegebene Credential fuer die Session merken (nur EINMAL nachfragen).
        if (-not ($Global:WoyCredCache -is [hashtable])) { $Global:WoyCredCache = @{} }
        if ($Refresh) { $Global:WoyCredCache.Remove($Name) }
        if ($Global:WoyCredCache.ContainsKey($Name)) { return $Global:WoyCredCache[$Name] }

        $vorgabe = if ($askUser) { '' } else { $user }
        $cred = Get-Credential -Message "Anmeldedaten '$Name' eingeben" -UserName $vorgabe
        if ($null -eq $cred -or
            [string]::IsNullOrWhiteSpace($cred.UserName) -or
            $cred.Password.Length -eq 0) {
            Write-Error "Anmeldedaten '$Name' abgebrochen oder unvollstaendig - Vorgang abgebrochen."
            return $null
        }
        $Global:WoyCredCache[$Name] = $cred
        return $cred
    }

    if ([string]::IsNullOrWhiteSpace($user) -or [string]::IsNullOrWhiteSpace($pass)) {
        Write-Error "Anmeldedaten '$Name' fehlen in $(Get-WoyEnvPath). Erwartet: ${prefix}_USER und ${prefix}_PASS."
        return $null
    }

    return [System.Management.Automation.PSCredential]::new(
        $user, (ConvertTo-SecureString $pass -AsPlainText -Force))
}

# [global] Liest einen Einzelwert (kein Passwort) aus der woy.env; $Default falls fehlend.
function global:Get-WoyValue {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Schluesselname in der woy.env")]
        [string] $Key,

        [Parameter(Position = 1, HelpMessage = "Rueckgabewert, falls der Schluessel fehlt")]
        [string] $Default = $null,

        [switch] $Refresh
    )

    $envMap = Import-WoyEnv -Refresh:$Refresh
    $value = $envMap[$Key]
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    return $value
}
