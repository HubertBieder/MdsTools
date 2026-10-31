#======================================================================
# Datei:        Share.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Kopieren von/auf SMB-Freigaben mit Anmeldedaten, unter Windows
#               (net use) und macOS (mount_smbfs).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (Common.psm1) uebernommen; ohne woy-
#                            Credential, zusaetzlich macOS und smb://-Pfade (E12)
#
# Oeffentlich: Copy-FolderWithCredential, Copy-FileWithCredential
#======================================================================

# [intern] Zerlegt einen Freigabepfad in Server, Freigabe und Restpfad.
# Erkannt werden \\server\share\rest, //server/share/rest und smb://server/share/rest.
# Rueckgabewert: [pscustomobject] (Server, Share, Rest, Key) oder $null bei lokalen Pfaden.
function Get-ShareInfo([string] $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    $normalized = $Path -replace '\\', '/'
    if ($normalized -match '^(?i)smb://') {
        $normalized = '//' + $normalized.Substring(6)
    }
    if (-not $normalized.StartsWith('//')) {
        return $null
    }
    $parts = $normalized.TrimStart('/').Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Count -lt 2) {
        return $null
    }
    return [pscustomobject]@{
        Server = $parts[0]
        Share  = $parts[1]
        Rest   = ($parts | Select-Object -Skip 2) -join '/'
        Key    = "$($parts[0])/$($parts[1])".ToLowerInvariant()
    }
}

# [intern] Verbindet eine Freigabe mit den Anmeldedaten.
#   Windows: net use \\server\share
#   macOS:   mount_smbfs in einen Ordner unter $mdsTemp
# Rueckgabewert: lokaler Wurzelpfad der Freigabe oder $null bei Fehler.
function Connect-Share([object] $Info, [System.Management.Automation.PSCredential] $Credential) {
    $user = $Credential.UserName
    $pass = $Credential.GetNetworkCredential().Password

    if ($IsWindows) {
        $root = "\\$($Info.Server)\$($Info.Share)"
        # net-use-Ausgabe nur bei -Verbose zeigen.
        (net use $root $pass /User:$user 2>&1) | ForEach-Object { Write-Verbose "$_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Verbindung zu $root fehlgeschlagen (net use Exit-Code $LASTEXITCODE)."
            return $null
        }
        return $root
    }

    if ($IsMacOS) {
        $root = Join-Path $mdsTemp "smb-$($Info.Server)-$($Info.Share)"
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            $null = New-Item -Path $root -ItemType Directory -Force
        }
        # mount_smbfs erwartet //[domain;]user[:password]@server/share
        $domain = ""
        if ($user.Contains('\')) {
            $domain = $user.Split('\')[0] + ';'
            $user = $user.Split('\')[1]
        }
        $url = "//{0}{1}:{2}@{3}/{4}" -f $domain, [uri]::EscapeDataString($user),
            [uri]::EscapeDataString($pass), $Info.Server, $Info.Share
        (mount_smbfs $url $root 2>&1) | ForEach-Object { Write-Verbose "$_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Verbindung zu //$($Info.Server)/$($Info.Share) fehlgeschlagen (mount_smbfs Exit-Code $LASTEXITCODE)."
            Remove-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue
            return $null
        }
        return $root
    }

    Write-Error "Freigaben werden nur unter Windows und macOS unterstuetzt."
    return $null
}

# [intern] Trennt eine mit Connect-Share hergestellte Verbindung.
function Disconnect-Share([string] $Root) {
    if ($IsWindows) {
        (net use $Root /delete /yes 2>&1) | ForEach-Object { Write-Verbose "$_" }
    }
    elseif ($IsMacOS) {
        (umount $Root 2>&1) | ForEach-Object { Write-Verbose "$_" }
        Remove-Item -LiteralPath $Root -Force -ErrorAction SilentlyContinue
    }
}

# [intern] Wandelt die Pfade in lokal erreichbare Pfade um und verbindet dazu alle
# beteiligten Freigaben (jede nur einmal). Fehlt $Credential, wird nachgefragt.
# Rueckgabewert: @{ Paths = <lokale Pfade>; Roots = <verbundene Wurzeln> } oder $null.
function Open-SharePath([string[]] $Paths, [System.Management.Automation.PSCredential] $Credential) {
    $roots = [ordered]@{}
    $local = @()
    foreach ($path in $Paths) {
        $info = Get-ShareInfo $path
        if ($null -eq $info) {
            $local += $path
            continue
        }
        if (-not $roots.Contains($info.Key)) {
            if ($null -eq $Credential) {
                $Credential = Get-Credential -Message "Anmeldedaten für //$($info.Server)/$($info.Share)"
                if ($null -eq $Credential) {
                    Write-Error "Keine Anmeldedaten angegeben - Vorgang abgebrochen."
                    Close-SharePath @($roots.Values)
                    return $null
                }
            }
            $root = Connect-Share $info $Credential
            if ($null -eq $root) {
                Close-SharePath @($roots.Values)
                return $null
            }
            Write-Host "Verbunden mit //$($info.Server)/$($info.Share) als $($Credential.UserName)" -ForegroundColor Green
            $roots[$info.Key] = $root
        }
        $local += if ($info.Rest) { Join-Path $roots[$info.Key] $info.Rest } else { $roots[$info.Key] }
    }
    return @{ Paths = $local; Roots = @($roots.Values) }
}

# [intern] Trennt alle mit Open-SharePath verbundenen Freigaben.
function Close-SharePath([string[]] $Roots) {
    foreach ($root in $Roots) {
        Disconnect-Share $root
    }
}

# [public] Copy-FolderWithCredential — Kopiert einen Ordner von/auf eine Netzfreigabe, die
# Anmeldedaten benoetigt. Ohne -Recurse nur die oberste Ebene. Ohne -Force inkrementell
# (nur neuere Quelldateien ueberschreiben); mit -Force wird das Ziel zuerst bereinigt und
# komplett neu kopiert. Lokale Pfade werden ohne Verbindung direkt bedient.
#   SourceDir   Quellverzeichnis (lokal, \\server\share\... oder smb://server/share/...)
#   TargetDir   Zielverzeichnis (lokal oder Freigabe)
#   Recurse     Unterordner rekursiv mitkopieren
#   Force       Ziel zuerst bereinigen und komplett neu kopieren
#   Credential  Anmeldedaten; fehlen sie und wird eine Freigabe gebraucht, wird nachgefragt
# Rueckgabewert: -1 bei Fehler, sonst Anzahl der kopierten Dateien.
function Copy-FolderWithCredential {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Quellverzeichnis")]
        [string] $SourceDir,

        [Parameter(Position = 1, Mandatory = $true, HelpMessage = "Zielverzeichnis")]
        [string] $TargetDir,

        [Parameter(HelpMessage = "Unterordner rekursiv mitkopieren")]
        [switch] $Recurse,

        [Parameter(HelpMessage = "Ziel zuerst bereinigen und komplett neu kopieren (statt nur neuere Dateien)")]
        [switch] $Force,

        [System.Management.Automation.PSCredential] $Credential = $null
    )

    $shares = Open-SharePath @($SourceDir, $TargetDir) $Credential
    if ($null -eq $shares) {
        return -1
    }
    $source = $shares.Paths[0].TrimEnd([char]'/', [char]'\')
    $target = $shares.Paths[1].TrimEnd([char]'/', [char]'\')

    try {
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            Write-Error "Quellverzeichnis nicht gefunden: $SourceDir"
            return -1
        }
        # Quelle absolut aufloesen, damit Substring($source.Length) gegen $file.FullName
        # den korrekten Relativpfad liefert.
        $source = (Resolve-Path -LiteralPath $source).Path.TrimEnd([char]'/', [char]'\')

        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            $null = New-Item -Path $target -ItemType Directory -Force -ErrorAction Stop
        }

        # Bei -Force das Ziel zuerst bereinigen. Mit -Recurse den gesamten Inhalt,
        # ohne -Recurse nur die Dateien der obersten Ebene.
        if ($Force) {
            $bereinigungsItems = if ($Recurse) {
                Get-ChildItem -LiteralPath $target -Force -ErrorAction Stop
            }
            else {
                Get-ChildItem -LiteralPath $target -File -Force -ErrorAction Stop
            }
            foreach ($item in $bereinigungsItems) {
                Remove-Item -LiteralPath $item.FullName -Recurse:$Recurse -Force -ErrorAction Stop
            }
        }

        $copied = 0
        foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse:$Recurse -ErrorAction Stop) {
            $relative = $file.FullName.Substring($source.Length).TrimStart([char]'/', [char]'\')
            $destFile = Join-Path $target $relative
            $destDir = Split-Path -Path $destFile -Parent

            if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
                $null = New-Item -Path $destDir -ItemType Directory -Force -ErrorAction Stop
            }

            # Ohne -Force nur kopieren, wenn das Ziel fehlt oder aelter ist als die Quelle.
            if (-not $Force -and (Test-Path -LiteralPath $destFile -PathType Leaf)) {
                $destItem = Get-Item -LiteralPath $destFile -ErrorAction Stop
                if ($destItem.LastWriteTime -ge $file.LastWriteTime) {
                    continue
                }
                Remove-Item -LiteralPath $destFile -Force -ErrorAction Stop
            }

            Copy-Item -LiteralPath $file.FullName -Destination $destFile -Force -ErrorAction Stop
            Write-Verbose "Kopiert: $($file.FullName) ==> $destFile"
            $copied++
        }

        Write-Host "Kopieren von $SourceDir nach $TargetDir abgeschlossen ($copied Dateien)." -ForegroundColor Green
        return $copied
    }
    catch {
        Write-Error "Kopieren fehlgeschlagen: $($_.Exception.Message)"
        return -1
    }
    finally {
        Close-SharePath $shares.Roots
    }
}

# [public] Copy-FileWithCredential — Kopiert eine einzelne Datei zwischen lokalem Pfad und
# Netzfreigabe (in beide Richtungen, auch Freigabe->Freigabe). Eine vorhandene Zieldatei
# wird zuerst geloescht.
#   SourceDir   Quellverzeichnis (lokal oder Freigabe)
#   TargetDir   Zielverzeichnis (lokal oder Freigabe)
#   FileName    Dateiname
#   Credential  Anmeldedaten; fehlen sie und wird eine Freigabe gebraucht, wird nachgefragt
# Rueckgabewert: $true bei Erfolg, sonst $false.
function Copy-FileWithCredential {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Quellverzeichnis (lokal oder Freigabe)")]
        [string] $SourceDir,

        [Parameter(Position = 1, Mandatory = $true, HelpMessage = "Zielverzeichnis (lokal oder Freigabe)")]
        [string] $TargetDir,

        [Parameter(Position = 2, Mandatory = $true, HelpMessage = "Dateiname")]
        [string] $FileName,

        [System.Management.Automation.PSCredential] $Credential = $null
    )

    $shares = Open-SharePath @($SourceDir, $TargetDir) $Credential
    if ($null -eq $shares) {
        return $false
    }
    $sourceFile = Join-Path $shares.Paths[0] $FileName
    $target = $shares.Paths[1]
    $destFile = Join-Path $target $FileName

    try {
        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            Write-Error "Quelldatei nicht gefunden: $FileName in $SourceDir"
            return $false
        }
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            $null = New-Item -Path $target -ItemType Directory -Force -ErrorAction Stop
        }
        if (Test-Path -LiteralPath $destFile -PathType Leaf) {
            Remove-Item -LiteralPath $destFile -Force -ErrorAction Stop
        }

        Copy-Item -LiteralPath $sourceFile -Destination $destFile -Force -ErrorAction Stop
        Write-Verbose "Kopiert: $sourceFile ==> $destFile"
        return (Test-Path -LiteralPath $destFile -PathType Leaf)
    }
    catch {
        Write-Error "Kopieren fehlgeschlagen: $($_.Exception.Message)"
        return $false
    }
    finally {
        Close-SharePath $shares.Roots
    }
}
