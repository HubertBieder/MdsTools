#======================================================================
# Datei:        Navigation.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Schnellzugriff: go (Sprung in Ordner) und mk <Repo> [Programm] (Programme bauen).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt (MdsTools.md, Abschnitt Befehle)
#
# Oeffentlich: go, mk
#======================================================================

# [intern] Liefert alle gueltigen Sprungziele fuer go: dev, root und die Repo-Kurznamen.
function Get-GoTarget {
    $repos = Get-ChildItem -LiteralPath $mdsRepos -Directory -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Name
    return @('dev', 'root') + @($repos)
}

# [public] go — Wechselt in einen Ordner. Gross-/Kleinschreibung spielt keine Rolle.
#   go / go dev   -> $mdsDev
#   go root       -> $mdsRoot
#   go <Kurzname> -> $mdsRepos/<Kurzname>
function go {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "dev, root oder Repo-Kurzname")]
        [string] $Ziel = 'dev'
    )
    switch ($Ziel.ToLowerInvariant()) {
        'dev' { Set-Location -LiteralPath $mdsDev; return }
        'root' { Set-Location -LiteralPath $mdsRoot; return }
    }
    $repo = Get-ChildItem -LiteralPath $mdsRepos -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq $Ziel } | Select-Object -First 1
    if ($repo) {
        Set-Location -LiteralPath $repo.FullName
    }
    else {
        Write-Warning "Unbekanntes Ziel '$Ziel'. Gültig: $((Get-GoTarget) -join ', ')"
    }
}

Register-ArgumentCompleter -CommandName go -ParameterName Ziel -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    Get-GoTarget | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_) }
}

# [intern] Liefert die Repos unter $mdsRepos, die ein scripts/Make.ps1 haben (Ziele fuer mk).
function Get-MakeRepo {
    Get-ChildItem -LiteralPath $mdsRepos -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'scripts/Make.ps1') -PathType Leaf } |
        Select-Object -ExpandProperty Name
}

# [public] mk — Baut Programme eines Repos ueber $mdsRepos/<Repo>/scripts/Make.ps1.
# Funktioniert von jedem Ordner aus; Gross-/Kleinschreibung des Repos spielt keine Rolle.
#   mk                          Repos mit scripts/Make.ps1 anzeigen
#   mk <Repo>                   alle Programme des Repos
#   mk <Repo> <Programm>        nur dieses Programm
#   mk <Repo> -OutDir <Pfad>    Ausgabeordner fuer diesen Lauf (relativ zu $mdsBin oder absolut)
#   mk <Repo> -List             bekannte Programme anzeigen
# Make.ps1 muss die Parameter Programm, OutDir und List anbieten.
# 2026-10-31 Hubi/Claude: Repo als erster Positionsparameter statt aktuellem Git-Repo
function mk {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Repo-Kurzname, z. B. net")]
        [string] $Repo = "",

        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "Programmname")]
        [string] $Programm = "",

        [Parameter(Mandatory = $false, HelpMessage = "Ausgabeordner fuer diesen Lauf")]
        [string] $OutDir = "",

        [Parameter(Mandatory = $false, HelpMessage = "Bekannte Programme anzeigen")]
        [switch] $List
    )
    $repos = @(Get-MakeRepo)
    if ([string]::IsNullOrWhiteSpace($Repo)) {
        Write-Info "Aufruf: mk <Repo> [Programm] [-OutDir <Pfad>] [-List]"
        Write-Info "Repos mit scripts/Make.ps1: $($repos -join ', ')"
        return
    }
    $treffer = $repos | Where-Object { $_ -eq $Repo } | Select-Object -First 1
    if (-not $treffer) {
        Write-Fail "Kein Repo '$Repo' mit scripts/Make.ps1. Gültig: $($repos -join ', ')"
        return
    }
    $make = Join-Path (Join-Path $mdsRepos $treffer) 'scripts/Make.ps1'
    $makeArgs = @{}
    if ($Programm) { $makeArgs.Programm = $Programm }
    if ($OutDir) { $makeArgs.OutDir = $OutDir }
    if ($List) { $makeArgs.List = $true }
    & $make @makeArgs -Verbose:($VerbosePreference -eq 'Continue')
}

Register-ArgumentCompleter -CommandName mk -ParameterName Repo -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    Get-MakeRepo | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_) }
}
