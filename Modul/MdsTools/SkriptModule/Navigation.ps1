#======================================================================
# Datei:        Navigation.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Schnellzugriff: go (Sprung in Ordner) und mk (Programme bauen).
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

# [public] mk — Baut Programme des aktuellen Repos ueber <Git-Root>/scripts/Make.ps1.
#   mk                  alle Programme
#   mk <Programm>       nur dieses Programm
#   mk -OutDir <Pfad>   Ausgabeordner fuer diesen Lauf (relativ zu $mdsBin oder absolut)
#   mk -List            bekannte Programme anzeigen
# Make.ps1 muss die Parameter Programm, OutDir und List anbieten.
function mk {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Programmname")]
        [string] $Programm = "",

        [Parameter(Mandatory = $false, HelpMessage = "Ausgabeordner fuer diesen Lauf")]
        [string] $OutDir = "",

        [Parameter(Mandatory = $false, HelpMessage = "Bekannte Programme anzeigen")]
        [switch] $List
    )
    $root = git -C (Get-Location).Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($root)) {
        Write-Fail "Kein Git-Repository: $((Get-Location).Path)"
        return
    }
    $make = Join-Path $root 'scripts/Make.ps1'
    if (-not (Test-Path -LiteralPath $make -PathType Leaf)) {
        Write-Fail "Kein scripts/Make.ps1 in $root"
        return
    }
    $makeArgs = @{}
    if ($Programm) { $makeArgs.Programm = $Programm }
    if ($OutDir) { $makeArgs.OutDir = $OutDir }
    if ($List) { $makeArgs.List = $true }
    & $make @makeArgs -Verbose:($VerbosePreference -eq 'Continue')
}
