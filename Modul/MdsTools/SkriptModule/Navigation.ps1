#======================================================================
# Datei:        Navigation.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Schnellzugriff: go (Sprung in Ordner), mk <Repo> [Programm] (Programme bauen) und
#               run <Repo> <Skript> (Repo-Skripte scripts/_<Skript>.ps1 ausfuehren).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Erstellt (MdsTools.md, Abschnitt Befehle)
#   2026-11-01  Hubi/Claude  mk: Repo des aktuellen Ordners, -Package
#   2026-11-03  Hubi/Claude  run: Skripte mit Praefix _ in scripts/ ausfuehren und auflisten
#   2026-11-03  Hubi/Claude  go repos (unter Windows gleich go dev = C:\woyCode)
#   2026-11-03  Hubi/Claude  go: nur Ordner mit .git (keine Laufzeitordner unter C:\woyCode)
#   2026-11-04  Hubi/Claude  run: globale Skripte aus Mds/scripts, eindeutige Abkuerzung (run back)
#   2026-11-04  Hubi/Claude  Show-Repos: Repos mit GitHub-Name, letzter Aenderung, Kurzbeschreibung
#   2026-11-05  Hubi/Claude  go dev entfaellt, go ohne Argument = go repos (8.3)
#   2026-11-05  Hubi/Claude  push/clone (Invoke-PushAll/-CloneAll), Show-Alias (8.3.3)
#
# Oeffentlich: go, mk, run, Show-Repos, Invoke-PushAll (push), Invoke-CloneAll (clone), Show-Alias
#======================================================================

# [intern] Git-Repos unter $mdsRepos: nur Ordner mit .git (Ordner oder Datei bei Worktrees).
# Unter Windows liegen in C:\woyCode auch Bin, Config, ... - die sind keine Sprungziele;
# die woy-Repos der Auftragsabwicklung (nur Windows) haben .git und gehoeren dazu.
function Get-GoRepo {
    Get-ChildItem -LiteralPath $mdsRepos -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } |
        Select-Object -ExpandProperty Name
}

# [intern] Liefert alle gueltigen Sprungziele fuer go: repos, root und die Repo-Kurznamen.
function Get-GoTarget {
    return @('repos', 'root') + @(Get-GoRepo)
}

# [public] go — Wechselt in einen Ordner. Gross-/Kleinschreibung spielt keine Rolle.
#   go / go repos -> $mdsRepos
#   go root       -> $mdsRoot
#   go <Kurzname> -> $mdsRepos/<Kurzname> (nur Ordner mit .git)
# 2026-11-05 Hubi/Claude: go dev entfaellt ($mdsDev gibt es nicht mehr), go = go repos (8.3)
function go {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "repos, root oder Repo-Kurzname")]
        [string] $Ziel = 'repos'
    )
    switch ($Ziel.ToLowerInvariant()) {
        'repos' { Set-Location -LiteralPath $mdsRepos; return }
        'root' { Set-Location -LiteralPath $mdsRoot; return }
    }
    $repo = Get-GoRepo | Where-Object { $_ -eq $Ziel } | Select-Object -First 1
    if ($repo) {
        Set-Location -LiteralPath (Join-Path $mdsRepos $repo)
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

# [intern] Sucht ein run-Skript: zuerst exakt, sonst eindeutige Abkuerzung (back -> backup).
# Gross-/Kleinschreibung spielt keine Rolle. Rueckgabewert: alle Treffer (genau einer = eindeutig).
# 2026-11-04 Hubi/Claude: erstellt
function Find-RunScript([string[]] $Skripte, [string] $Skript) {
    $exakt = @($Skripte | Where-Object { $_ -eq $Skript })
    if ($exakt) { return $exakt[0] }
    return @($Skripte | Where-Object { $_ -like "$([WildcardPattern]::Escape($Skript))*" })
}

# Repo mit den globalen run-Skripten (scripts/_*.ps1), die von ueberall gelten: run backup.
$script:RunGlobalRepo = 'Mds'

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
# Fehlt das Skript im aktuellen Repo (oder steht man ausserhalb der Repos), gilt Mds/scripts
# (globale Skripte, z. B. run backup). Eine eindeutige Abkuerzung genuegt (run back).
# Alle weiteren Argumente (auch benannte wie -Ziel TEST-SRV) gehen unveraendert an das Skript.
# Bewusst eine einfache Funktion (kein [CmdletBinding()]), damit $args die benannten Argumente behaelt.
# 2026-11-03 Hubi/Claude: erstellt
# 2026-11-04 Hubi/Claude: globale Skripte aus Mds/scripts, Abkuerzungen
function run([string] $Skript = "", [switch] $List) {
    $repos = @(Get-RunRepo)
    $aktuell = Get-CurrentRepo $repos
    $weiter = @($args)
    $global = $repos | Where-Object { $_ -eq $script:RunGlobalRepo } | Select-Object -First 1
    $treffer = $repos | Where-Object { $_ -eq $Skript } | Select-Object -First 1
    $explizit = [bool]$treffer
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
    elseif ($Skript -and $global) {
        # Ausserhalb der Repos (z. B. in Dev): globale Skripte
        $treffer = $global
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
    $namen = @(Find-RunScript $skripte $Skript)
    if ($namen.Count -eq 0 -and -not $explizit -and $global -and $treffer -ne $global) {
        # Nicht im aktuellen Repo: globales Skript aus Mds/scripts
        $globaleNamen = @(Find-RunScript @(Get-RunScript $global) $Skript)
        if ($globaleNamen.Count -gt 0) {
            $treffer = $global
            $namen = $globaleNamen
            $skripte = @(Get-RunScript $global)
        }
    }
    if ($namen.Count -gt 1) {
        Write-Fail "Skript '$Skript' ist nicht eindeutig in $treffer/scripts: $($namen -join ', ')"
        return
    }
    if ($namen.Count -eq 0) {
        Write-Fail "Kein Skript '_$Skript.ps1' in $treffer/scripts. Gültig: $($skripte -join ', ')"
        return
    }
    $name = $namen[0]
    $pfad = Join-Path (Join-Path (Join-Path $mdsRepos $treffer) 'scripts') "_$name.ps1"
    & $pfad @weiter
}

Register-ArgumentCompleter -CommandName run -ParameterName Skript -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    $repos = @(Get-RunRepo)
    $aktuell = Get-CurrentRepo $repos
    $global = $repos | Where-Object { $_ -eq $script:RunGlobalRepo } | Select-Object -First 1
    $ziele = @(if ($aktuell) { Get-RunScript $aktuell }) + @(if ($global) { Get-RunScript $global }) + $repos
    $ziele | Select-Object -Unique | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_) }
}

# [intern] Kurzbeschreibung eines Repos aus der ersten Zeile der README.md: "# <Name> – <Beschreibung>".
# Fehlt der Teil nach dem Gedankenstrich, gilt die erste Textzeile nach der Ueberschrift.
# Laenger als 80 Zeichen wird mit "…" gekuerzt. Rueckgabewert: Text oder "".
# 2026-11-04 Hubi/Claude: erstellt fuer Show-Repos
function Get-RepoDescription([string] $Pfad) {
    $readme = Get-ChildItem -LiteralPath $Pfad -File -Filter 'README.md' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $readme) { return '' }
    $zeilen = @(Get-Content -LiteralPath $readme.FullName -TotalCount 40 -Encoding utf8 |
        ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $zeilen) { return '' }
    $text = ''
    if ($zeilen[0] -match '^#\s+.+?\s+[–-]\s+(.+)$') {
        $text = $Matches[1]
    }
    else {
        # Erste Zeile, die keine Ueberschrift, kein Zitat, keine Tabelle, Liste oder Codeblock ist
        $text = $zeilen | Select-Object -Skip 1 |
            Where-Object { $_ -notmatch '^(#|>|\||-|\*|```|<)' } | Select-Object -First 1
    }
    $text = "$text".Trim()
    if ($text.Length -gt 80) { $text = $text.Substring(0, 79).TrimEnd() + '…' }
    return $text
}

# [intern] Stand des Branches gegenueber seinem Upstream (ohne fetch): "aktuell", "vor 2", "zurueck 1",
# "vor 2 / zurueck 1" oder "kein Upstream".
# 2026-11-04 Hubi/Claude: erstellt fuer Show-Repos -Full
function Get-RepoSyncState([string] $Pfad) {
    $zahlen = git -C $Pfad rev-list --left-right --count '@{u}...HEAD' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $zahlen) { return 'kein Upstream' }
    $zurueck, $vor = "$zahlen" -split '\s+' | ForEach-Object { [int]$_ }
    $teile = @()
    if ($vor -gt 0) { $teile += "vor $vor" }
    if ($zurueck -gt 0) { $teile += "zurueck $zurueck" }
    if (-not $teile) { return 'aktuell' }
    return $teile -join ' / '
}

<#
.SYNOPSIS
    Listet alle Repos unter $mdsRepos mit GitHub-Name, letzter Aenderung und Kurzbeschreibung.

.DESCRIPTION
    Je Repo (Ordner mit .git) ein Objekt:
      Name          Ordnername (Kurzname), z. B. Mds
      Repo          GitHub-Name aus der Remote-URL origin, z. B. MdsTools
      Datum         Datum des letzten Commits (yyyy-MM-dd HH:mm, Ortszeit)
      Geändert      $true, wenn es nicht committete Aenderungen gibt (git status)
      Beschreibung  erste Zeile der README.md "# <Name> – <Beschreibung>" (max. 80 Zeichen)
    Mit -Full (-F) zusaetzlich Branch, Stand gegenueber dem Upstream (ohne fetch) und Remote-URL.

.EXAMPLE
    Show-Repos

.EXAMPLE
    Show-Repos -F

.EXAMPLE
    Show-Repos | Where-Object Geändert
#>
# 2026-11-04 Hubi/Claude: erstellt
function Show-Repos {
    [CmdletBinding()]
    param(
        [Alias('F')]
        [switch] $Full
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Fail 'git ist nicht installiert oder nicht im PATH.'
        return
    }
    $ordner = Get-ChildItem -LiteralPath $mdsRepos -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.git') } | Sort-Object Name
    if (-not $ordner) {
        Write-Info "Keine Repos unter $mdsRepos."
        return
    }
    foreach ($repo in $ordner) {
        $pfad = $repo.FullName
        $url = git -C $pfad remote get-url origin 2>$null
        $iso = git -C $pfad log -1 --format=%cI 2>$null
        $zeile = [ordered]@{
            Name         = $repo.Name
            Repo         = if ($url) { (("$url" -replace '\.git$', '').TrimEnd('/') -split '[/:]')[-1] } else { '' }
            Datum        = if ($iso) { ([datetimeoffset]::Parse("$iso")).LocalDateTime.ToString('yyyy-MM-dd HH:mm') } else { '' }
            'Geändert'   = [bool](git -C $pfad status --porcelain 2>$null)
            Beschreibung = Get-RepoDescription $pfad
        }
        if ($Full) {
            $zeile.Branch = "$(git -C $pfad branch --show-current 2>$null)"
            $zeile.Stand = Get-RepoSyncState $pfad
            $zeile.Remote = "$url"
        }
        [pscustomobject]$zeile
    }
}

# [intern] Pfad eines globalen Skripts in $mdsRepos (von Install.ps1 aus Modul/Skripte kopiert).
# Fehlt es, kommt eine Fehlermeldung und $null zurueck.
# 2026-11-05 Hubi/Claude: erstellt fuer push/clone
function Get-GlobalScript([string] $Name) {
    $pfad = Join-Path $mdsRepos $Name
    if (Test-Path -LiteralPath $pfad -PathType Leaf) { return $pfad }
    Write-Error "$Name fehlt in $mdsRepos - ./Install.ps1 im Repo Mds ausfuehren."
    return $null
}

<#
.SYNOPSIS
    Committet und pusht alle Repos ($mdsRepos/PushAll.ps1), Alias push.
.DESCRIPTION
    Alle Argumente werden an PushAll.ps1 weitergereicht (-Repos, -Message).
.EXAMPLE
    push
.EXAMPLE
    push -Repos Net, Maui -Message "Neue Logging-Klasse"
#>
# 2026-11-05 Hubi/Claude: erstellt
function Invoke-PushAll {
    $skript = Get-GlobalScript 'PushAll.ps1'
    if ($skript) { & $skript @args }
}

<#
.SYNOPSIS
    Klont bzw. aktualisiert alle Repos ($mdsRepos/CloneAll.ps1), Alias clone.
.DESCRIPTION
    Alle Argumente werden an CloneAll.ps1 weitergereicht.
.EXAMPLE
    clone
#>
# 2026-11-05 Hubi/Claude: erstellt
function Invoke-CloneAll {
    $skript = Get-GlobalScript 'CloneAll.ps1'
    if ($skript) { & $skript @args }
}

Set-Alias -Name push -Value Invoke-PushAll
Set-Alias -Name clone -Value Invoke-CloneAll

<#
.SYNOPSIS
    Zeigt die Kurzbefehle von MdsTools (go, mk, run, push, clone, Show-*) mit Beschreibung.
.DESCRIPTION
    Je Befehl: Name, Ziel (bei Aliasen die Funktion dahinter) und die Kurzbeschreibung.
.EXAMPLE
    Show-Alias
#>
# 2026-11-05 Hubi/Claude: erstellt
function Show-Alias {
    [CmdletBinding()]
    param()

    $beschreibung = @{}
    foreach ($befehl in Get-MdsCommand) { $beschreibung[$befehl.Name] = $befehl.Beschreibung }
    foreach ($name in 'go', 'mk', 'run', 'push', 'clone', 'Show-Repos', 'Show-Mds', 'Show-Alias') {
        $cmd = Get-Command -Name $name -Module MdsTools -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        $ziel = if ($cmd.CommandType -eq 'Alias') { $cmd.Definition } else { $cmd.Name }
        [pscustomobject]@{ Befehl = $name; Ziel = $ziel; Beschreibung = $beschreibung[$ziel] }
    }
}
