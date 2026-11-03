#======================================================================
# Datei:        Common.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Modulweite Helfer: Pfadaufloesung, Adminpruefung, Spinner, Projekt-/Modulinfos.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (SkriptModule\*.psm1) uebernommen,
#                            Cmdlets umbenannt (siehe MdsTools.md, Umbenennungen)
#   2026-11-03  Hubi/Claude  Resolve-MdsPath: fehlender Pfad mit -AllowMissing ohne Ausnahme
#
# Oeffentlich: - (nur intern)
#======================================================================

# [intern] Loest einen (relativen oder absoluten) Pfad auf. Mit -AllowMissing wird auch
# ein noch nicht existierender Pfad als Vollpfad zurueckgegeben, sonst wird geworfen.
function Resolve-MdsPath([string] $Path, [string] $BasePath = "", [switch] $AllowMissing) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $candidatePath = $Path
    if (-not [System.IO.Path]::IsPathRooted($candidatePath)) {
        if ([string]::IsNullOrWhiteSpace($BasePath)) {
            $BasePath = (Get-Location).Path
        }

        $candidatePath = Join-Path -Path $BasePath -ChildPath $candidatePath
    }

    # Fehlender Pfad + AllowMissing: ohne Resolve-Path - dessen abgefangene Ausnahme landet sonst
    # als "PS>TerminatingError" im Transcript (Make-Logs).
    # 2026-11-03 Hubi/Claude
    if ($AllowMissing -and -not (Test-Path -LiteralPath $candidatePath)) {
        return [System.IO.Path]::GetFullPath($candidatePath)
    }

    try {
        return (Resolve-Path -LiteralPath $candidatePath -ErrorAction Stop).Path
    }
    catch {
        if ($AllowMissing) {
            return [System.IO.Path]::GetFullPath($candidatePath)
        }

        throw
    }
}

# [intern] Prueft, ob die aktuelle Sitzung mit Administrator-/Root-Rechten laeuft.
function Test-IsAdmin {
    if ($IsWindows -or $PSEdition -eq 'Desktop') {
        try {
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = [Security.Principal.WindowsPrincipal]::new($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        catch { return $false }
    }
    # Nicht-Windows: root hat UID 0.
    try { return ((id -u) -eq '0') } catch { return $false }
}

# [intern] Bricht mit Fehlermeldung ab, wenn keine Adminrechte vorliegen.
# Rueckgabewert: $true wenn Admin, sonst $false (Aufrufer bricht dann ab).
function Assert-Admin([string] $Action = "Diese Operation") {
    if (Test-IsAdmin) { return $true }
    Write-Error "$Action erfordert Administratorrechte. Bitte PowerShell 'Als Administrator' starten."
    return $false
}

# [intern] Startet eine animierte Warteanzeige (Spinner) in einem eigenen Runspace,
# damit sie sich dreht, waehrend der Hauptthread auf einen langen Aufruf
# (z. B. dotnet publish) blockiert. Rueckgabe ist ein Handle fuer Stop-Spinner.
# Bei umgeleiteter Ausgabe (Datei, CI, Hintergrund-Task) wuerde der Zugriff auf
# [Console] scheitern ("Das Handle ist ungueltig") -> dann No-Op ($null).
function Start-Spinner([string] $Message = "Bitte warten") {
    if ([Console]::IsOutputRedirected) { return $null }
    $sync = [hashtable]::Synchronized(@{ Running = $true; Message = $Message })
    $ps = [powershell]::Create()
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('sync', $sync)
    $ps.Runspace = $rs
    [void]$ps.AddScript({
            $frames = '|', '/', '-', '\'
            $i = 0
            while ($sync.Running) {
                $frame = $frames[$i % 4]
                try { [Console]::Write("`r$frame $($sync.Message) ") } catch { }
                Start-Sleep -Milliseconds 120
                $i++
            }
        })
    return [pscustomobject]@{ PS = $ps; Async = $ps.BeginInvoke(); Sync = $sync }
}

# [intern] Beendet den von Start-Spinner gestarteten Spinner und loescht die Zeile.
# Vertraegt $null (z. B. wenn Start-Spinner wegen Umleitung nichts gestartet hat).
function Stop-Spinner($Spinner) {
    if ($null -eq $Spinner) { return }
    $Spinner.Sync.Running = $false
    try { $Spinner.PS.EndInvoke($Spinner.Async) | Out-Null } catch { }
    try { $Spinner.PS.Runspace.Dispose() } catch { }
    try { $Spinner.PS.Dispose() } catch { }
    try { [Console]::Write("`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r") } catch { }
}

# [public] Get-ProjectReference — Ermittelt rekursiv alle Projektreferenzen (ProjectReference)
# eines *.csproj. Laedt die Projektdatei als XML und folgt den referenzierten Projekten
# (Zyklenschutz via Visited-Set). Rueckgabewert: eindeutige Liste der Referenzpfade.
#   Project  Pfad der *.csproj-Datei, deren Referenzen ermittelt werden
function Get-ProjectReference {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Path of a project file which references should be checked")]
        [string] $Project,

        [Parameter(Mandatory = $false, DontShow = $true)]
        [System.Collections.Generic.HashSet[string]] $Visited
    )

    begin {
        $output = @()
        $refOut = @()

        Write-Verbose "Checking if Input Variable `$Project is valid"
        if ([string]::IsNullOrWhiteSpace($Project)) {
            throw "No Project specified for checking the references"
        }

        if ($null -eq $Visited) {
            $Visited = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        }

        $Project = Resolve-MdsPath -Path $Project
        [void]$Visited.Add($Project)

        Write-Verbose "Checking if the specified project exists"
        if (Test-Path -LiteralPath $Project) {
            Write-Verbose "Load the projects .csproj file as xml"
            $xmlproject = New-Object XML
            $xmlproject.Load($Project)
        }
        else {
            throw "No Project with the specified name was found"
        }
    }
    process {
        $projectRoot = Split-Path $Project -Parent
        Write-Verbose "Get the projects references from the .csproj file"
        $refProjects = $xmlproject.GetElementsByTagName("ProjectReference")
        foreach ($proj in $refProjects) {
            $refPath = Resolve-MdsPath -Path $proj.Include -BasePath $projectRoot -AllowMissing
            if (Test-Path -LiteralPath $refPath -PathType Leaf) {
                if (-not $Visited.Contains($refPath)) {
                    [void]$Visited.Add($refPath)
                    $output += $refPath
                }
            }
        }
        foreach ($projPath in $output) {
            $refOut += Get-ProjectReference -Project $projPath -Visited $Visited
        }
        if ($refOut.Count -gt 0) {
            $output += $refOut
        }
    }
    end {
        # Nur ausgeben, wenn es Referenzen gibt. Sonst liefert "@() | Select-Object -Unique"
        # ein einzelnes $null, das beim Aufrufer als Null-Element landet.
        if ($output.Count -gt 0) {
            Write-Output ($output | Select-Object -Unique)
        }
    }
}

# [public] Get-ExportedMember — Listet die von einem geladenen Modul exportierten Mitglieder
# (Functions, Cmdlets, Variables, Aliases) als Objekt auf.
#   Module  Name des Moduls, dessen Exporte aufgelistet werden
function Get-ExportedMember {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Name of the module for which the exported members should be listed")]
        [ValidateNotNullOrEmpty()]
        [string] $Module
    )

    begin {
        $mod = Get-Module $Module
        if ($null -eq $mod) {
            throw "$($Module) could not be found or is not loaded"
        }
    }
    process {
        $functions = foreach ($item in $mod.ExportedFunctions.Values) { $item.Name }
        $variables = foreach ($item in $mod.ExportedVariables.Values) { $item.Name }
        $aliases = foreach ($item in $mod.ExportedAliases.Values) { $item.Name }
        $cmdlets = foreach ($item in $mod.ExportedCmdlets.Values) { $item.Name }

        $ExportedMembers = New-Object PSObject
        $ExportedMembers | Add-Member -MemberType NoteProperty -Name Functions -Value $functions
        $ExportedMembers | Add-Member -MemberType NoteProperty -Name Cmdlets   -Value $cmdlets
        $ExportedMembers | Add-Member -MemberType NoteProperty -Name Variables -Value $variables
        $ExportedMembers | Add-Member -MemberType NoteProperty -Name Aliases   -Value $aliases
    }
    end {
        Write-Output $ExportedMembers
    }
}
