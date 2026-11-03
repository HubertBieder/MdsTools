#======================================================================
# Datei:        Navigation.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Schnellzugriff: go (Sprung in Ordner), mk <Repo> [Programm] (Programme bauen) und
#               run <Repo> <Skript> (Repo-Skripte scripts/_<Skript>.ps1 ausfuehren).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt (MdsTools.md, Abschnitt Befehle)
#   2026-11-01  Hubi/Claude  mk: Repo des aktuellen Ordners, -Package
#   2026-11-03  Hubi/Claude  run: Skripte mit Praefix _ in scripts/ ausfuehren und auflisten
#
# Oeffentlich: go, mk, run
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

# [intern] Kurzname des Repos, in dem der aktuelle Ordner liegt (auch in Unterordnern), sofern es
# ein scripts/Make.ps1 hat; sonst leer.
function Get-CurrentMakeRepo {
    Get-CurrentRepo @(Get-MakeRepo)
}

# [intern] Welches der angegebenen Repos enthaelt den aktuellen Ordner (auch Unterordner)? Sonst leer.
# 2026-11-03 Hubi/Claude: aus Get-CurrentMakeRepo herausgeloest (auch fuer run)
function Get-CurrentRepo([string[]]$Kandidaten) {
    $hier = (Get-Location).Path.TrimEnd([char]'/', [char]'\') + [System.IO.Path]::DirectorySeparatorChar
    $vergleich = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    foreach ($name in @($Kandidaten)) {
        $wurzel = (Join-Path $mdsRepos $name).TrimEnd([char]'/', [char]'\') + [System.IO.Path]::DirectorySeparatorChar
        if ($hier.StartsWith($wurzel, $vergleich)) {
            return $name
        }
    }
    return ""
}

# [public] mk — Baut Programme eines Repos ueber $mdsRepos/<Repo>/scripts/Make.ps1.
# Funktioniert von jedem Ordner aus; Gross-/Kleinschreibung des Repos spielt keine Rolle.
#   mk                          im Repo-Ordner: alle Programme dieses Repos; sonst Repos anzeigen
#   mk <Programm>               im Repo-Ordner: nur dieses Programm (kein gleichnamiges Repo)
#   mk <Repo>                   alle Programme des Repos
#   mk <Repo> <Programm>        nur dieses Programm
#   mk <Repo> +<Gruppen>        alle Programme dieser Gruppen, z. B. mk maui +dI (im Repo-Ordner: mk +dI)
#   mk <Repo> -OutDir <Pfad>    Ausgabeordner fuer diesen Lauf (relativ zu $mdsBin oder absolut)
#   mk <Repo> -List             bekannte Programme anzeigen
#   mk <Repo> -Package          macOS-MAUI: Installationspaket (.pkg) statt direkt startbarer .app
# Make.ps1 muss die Parameter Programm, OutDir und List anbieten (fuer -Package auch Package).
# 2026-10-31 Hubi/Claude: Repo als erster Positionsparameter statt aktuellem Git-Repo
# 2026-11-01 Hubi/Claude: ohne Repo das Repo des aktuellen Ordners; -Package
# 2026-11-02 Hubi/Claude: Programm auch als +<Gruppen>; -<Buchstaben> meldet Hinweis auf +
function mk {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Repo-Kurzname, z. B. net")]
        [string] $Repo = "",

        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "Programmname oder +<Gruppen>")]
        [string] $Programm = "",

        [Parameter(Mandatory = $false, HelpMessage = "Ausgabeordner fuer diesen Lauf")]
        [string] $OutDir = "",

        [Parameter(Mandatory = $false, HelpMessage = "Bekannte Programme anzeigen")]
        [switch] $List,

        [Parameter(Mandatory = $false, HelpMessage = "macOS-MAUI: Installationspaket (.pkg) statt .app")]
        [switch] $Package,

        # Faengt Unbekanntes wie -di ab (Gruppen gehen mit +, -d allein waere -Debug)
        [Parameter(ValueFromRemainingArguments = $true, DontShow = $true)]
        [string[]] $Rest
    )
    if ($Rest) {
        $hinweis = @($Rest | Where-Object { $_ -match '^-[a-zA-Z]+$' } | ForEach-Object { "+$($_.Substring(1))" })
        Write-Fail "Unbekanntes Argument '$($Rest -join ' ')'.$(if ($hinweis) { " Gruppen werden mit + gewählt: mk $($hinweis -join ' ')" })"
        return
    }
    $repos = @(Get-MakeRepo)
    $aktuell = Get-CurrentMakeRepo
    $treffer = $repos | Where-Object { $_ -eq $Repo } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($Repo)) {
        if (-not $aktuell) {
            Write-Info "Aufruf: mk <Repo> [Programm|+Gruppen] [-OutDir <Pfad>] [-List] [-Package]"
            Write-Info "Repos mit scripts/Make.ps1: $($repos -join ', ')"
            return
        }
        $treffer = $aktuell
    }
    elseif (-not $treffer) {
        if (-not $aktuell -or $Programm) {
            Write-Fail "Kein Repo '$Repo' mit scripts/Make.ps1. Gültig: $($repos -join ', ')"
            return
        }
        # Im Repo-Ordner ist der erste Parameter das Programm
        $Programm = $Repo
        $treffer = $aktuell
    }
    $make = Join-Path (Join-Path $mdsRepos $treffer) 'scripts/Make.ps1'
    $makeArgs = @{}
    if ($Programm) { $makeArgs.Programm = $Programm }
    if ($OutDir) { $makeArgs.OutDir = $OutDir }
    if ($List) { $makeArgs.List = $true }
    if ($Package) { $makeArgs.Package = $true }
    & $make @makeArgs -Verbose:($VerbosePreference -eq 'Continue')
}

Register-ArgumentCompleter -CommandName mk -ParameterName Repo -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    Get-MakeRepo | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_) }
}

# [intern] Namen der run-Skripte eines Repos: scripts/_<Name>.ps1 -> <Name> (das Praefix _ markiert sie).
# 2026-11-03 Hubi/Claude: erstellt
function Get-RunScript([string]$Repo) {
    $ordner = Join-Path (Join-Path $mdsRepos $Repo) 'scripts'
    Get-ChildItem -LiteralPath $ordner -File -Filter '_*.ps1' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '_*.ps1' } |
        ForEach-Object { $_.BaseName.Substring(1) } | Where-Object { $_ } | Sort-Object
}

# [intern] Repos unter $mdsRepos mit mindestens einem run-Skript (scripts/_*.ps1).
function Get-RunRepo {
    Get-ChildItem -LiteralPath $mdsRepos -Directory -ErrorAction SilentlyContinue |
        Where-Object { @(Get-RunScript $_.Name).Count -gt 0 } |
        Select-Object -ExpandProperty Name
}

# [public] run — Fuehrt ein Repo-Skript $mdsRepos/<Repo>/scripts/_<Skript>.ps1 aus.
# Nur Skripte mit Praefix _ gelten als run-Skripte; Gross-/Kleinschreibung spielt keine Rolle.
#   run                         im Repo-Ordner: Skripte dieses Repos anzeigen; sonst alle Repos mit Skripten
#   run <Skript> [Argumente]    im Repo-Ordner: scripts/_<Skript>.ps1 ausfuehren
#   run <Repo>                  Skripte des Repos anzeigen
#   run <Repo> <Skript> [...]   scripts/_<Skript>.ps1 des Repos ausfuehren
#   run [<Repo>] -List          verfuegbare Skripte anzeigen
# Alle weiteren Argumente (auch benannte wie -Ziel TEST-SRV) gehen unveraendert an das Skript.
# Bewusst eine einfache Funktion (kein [CmdletBinding()]), damit $args die benannten Argumente behaelt.
# 2026-11-03 Hubi/Claude: erstellt
function run([string] $Skript = "", [switch] $List) {
    $repos = @(Get-RunRepo)
    $aktuell = Get-CurrentRepo $repos
    $weiter = @($args)
    $treffer = $repos | Where-Object { $_ -eq $Skript } | Select-Object -First 1
    if ($treffer) {
        # Erster Parameter ist ein Repo, der naechste (sofern kein -Schalter) das Skript
        $Skript = ""
        if ($weiter.Count -gt 0 -and "$($weiter[0])" -notlike '-*') {
            $Skript = "$($weiter[0])"
            $weiter = @($weiter | Select-Object -Skip 1)
        }
    }
    elseif ($aktuell) {
        $treffer = $aktuell
    }
    elseif ($Skript) {
        Write-Fail "Kein Repo '$Skript' mit Skripten scripts/_*.ps1. Gültig: $($repos -join ', ')"
        return
    }

    if (-not $treffer) {
        Write-Info "Aufruf: run [<Repo>] <Skript> [Argumente] | run [<Repo>] -List"
        foreach ($repo in $repos) {
            Write-Info "  $($repo): $((Get-RunScript $repo) -join ', ')"
        }
        if (-not $repos) { Write-Info "Kein Repo hat Skripte scripts/_*.ps1." }
        return
    }

    $skripte = @(Get-RunScript $treffer)
    if ($List -or -not $Skript) {
        Write-Info "Skripte in $treffer/scripts (run <Skript>): $($skripte -join ', ')"
        return
    }
    $name = $skripte | Where-Object { $_ -eq $Skript } | Select-Object -First 1
    if (-not $name) {
        Write-Fail "Kein Skript '_$Skript.ps1' in $treffer/scripts. Gültig: $($skripte -join ', ')"
        return
    }
    $pfad = Join-Path (Join-Path (Join-Path $mdsRepos $treffer) 'scripts') "_$name.ps1"
    & $pfad @weiter
}

Register-ArgumentCompleter -CommandName run -ParameterName Skript -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    $repos = @(Get-RunRepo)
    $aktuell = Get-CurrentRepo $repos
    $ziele = @(if ($aktuell) { Get-RunScript $aktuell }) + $repos
    $ziele | Select-Object -Unique | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_) }
}
