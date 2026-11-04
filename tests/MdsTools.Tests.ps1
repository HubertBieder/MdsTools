#Requires -Modules Pester
<#
.SYNOPSIS
    Pester-Tests fuer MdsTools (MdsTools.md, Schritt 8).

.DESCRIPTION
    Laedt das Modul aus dem Repo (nicht die installierte Kopie) mit $env:DEV_HOME im
    Pester-TestDrive, damit weder ~/Dev noch der echte PATH veraendert werden.
    Aufruf: Invoke-Pester ./tests

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-10-31  Hubi/Claude   Erste Version
    1.1.0    2026-11-01  Hubi/Claude   DEV_HOME statt DEV_ROOT, Umlenkung DEV_REPOS/DEV_ROOT/DEV_CONFIG
    1.2.0    2026-11-02  Hubi/Claude   Invoke-Make: Gruppen, Init.ps1/Post.ps1, Logdatei; Schutz vor echtem mdsRepos
    1.3.0    2026-11-03  Hubi/Claude   run: Skripte scripts/_<Name>.ps1, Liste
    1.4.0    2026-11-03  Hubi/Claude   mdsWoy, Show-Mds
    1.2.1    2026-11-02  Hubi/Claude   Invoke-Make: Init.ps1/Post.ps1 nicht bei einzelnem Programm
    1.5.0    2026-11-03  Hubi/Claude   Clear-BinFolder -Keep, Invoke-Make Schluessel Keep (8.2)
    1.5.1    2026-11-03  Hubi/Claude   Backup-Develop: Rueckgabe Pfad/$null
    1.6.0    2026-11-04  Hubi/Claude   Show-Mds -Full
    1.7.0    2026-11-04  Hubi/Claude   run: globale Skripte aus Mds/scripts, Abkuerzungen
    1.8.0    2026-11-04  Hubi/Claude   Show-Repos
#>

BeforeAll {
    $script:alteEnv = @{}
    foreach ($n in 'HOME', 'REPOS', 'ROOT', 'BIN', 'CONFIG', 'DATA', 'LOGS', 'TEMP') {
        $script:alteEnv[$n] = [Environment]::GetEnvironmentVariable("DEV_$n")
        [Environment]::SetEnvironmentVariable("DEV_$n", $null)
    }
    $script:alterPath = $env:PATH
    $env:DEV_HOME = Join-Path $TestDrive 'Dev'
    # Windows: Root laege sonst auf D:\Dev\Root (echtes Laufwerk) - in den TestDrive lenken
    $script:testRoot = if ($IsWindows) { Join-Path $TestDrive 'Root' } else { $null }
    $env:DEV_ROOT = $script:testRoot
    $script:manifest = Join-Path $PSScriptRoot '../Modul/MdsTools/MdsTools.psd1'
    Remove-Module MdsTools -ErrorAction SilentlyContinue
    Import-Module $script:manifest -Force
    # Schutz: Die Tests schreiben scripts/Make.ps1 in $mdsRepos und duerfen nie die echten Repos treffen
    if (-not $mdsRepos.StartsWith($TestDrive.ToString())) { throw "mdsRepos zeigt nicht in den TestDrive: $mdsRepos" }
    New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'Net/src') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'Net/.git') -Force | Out-Null
}

AfterAll {
    Remove-Module MdsTools -ErrorAction SilentlyContinue
    foreach ($n in $script:alteEnv.Keys) {
        [Environment]::SetEnvironmentVariable("DEV_$n", $script:alteEnv[$n])
    }
    $env:PATH = $script:alterPath
}

Describe 'Modul' {
    It 'hat die Version aus dem Manifest' {
        $soll = (Import-PowerShellDataFile $script:manifest).ModuleVersion
        (Get-Module MdsTools).Version | Should -Be ([version]$soll)
        $mdsVersion | Should -Be ([version]$soll)
    }

    It 'exportiert genau die Funktionen aus FunctionsToExport' {
        $soll = (Import-PowerShellDataFile $script:manifest).FunctionsToExport | Sort-Object
        (Get-Module MdsTools).ExportedFunctions.Keys | Sort-Object | Should -Be $soll
    }

    It 'haelt interne Helfer privat' -ForEach @('Resolve-MdsPath', 'Get-TargetDir', 'Get-ShareInfo', 'New-StatusLine') {
        (Get-Module MdsTools).ExportedFunctions.ContainsKey($_) | Should -BeFalse
    }

    # Vergleich mit Gross-/Kleinschreibung: Show-Powershell (alt) <> Show-PowerShell (neu)
    It 'exportiert keine alten Namen aus mdsPackage' -ForEach @('Publish-NET', 'Build-Projects', 'Limit-Files', 'Get-ZipEntries', 'Show-Powershell') {
        @((Get-Module MdsTools).ExportedFunctions.Values.Name) -ccontains $_ | Should -BeFalse
    }
}

Describe 'Globale Variablen und Root-Ordner' {
    It 'leitet alle Pfade aus DEV_HOME ab' {
        $mdsDev | Should -Be $env:DEV_HOME
        if ($IsWindows) {
            # Windows: Repos liegen direkt in $mdsDev, Root ist im Test per DEV_ROOT umgelenkt
            $mdsRepos | Should -Be $mdsDev
            $mdsRoot | Should -Be $script:testRoot
        }
        else {
            $mdsRepos | Should -Be (Join-Path $mdsDev 'Repos')
            $mdsRoot | Should -Be (Join-Path $mdsDev 'Root')
        }
        $mdsBin | Should -Be (Join-Path $mdsRoot 'Bin')
        $mdsTemp | Should -Be (Join-Path $mdsRoot 'Temp')
    }

    It 'legt die Root-Unterordner an' -ForEach @('Bin', 'Config', 'Data', 'Logs', 'Temp') {
        Join-Path $mdsRoot $_ | Should -Exist
    }

    It 'setzt mdsWoy als Integer (Windows 26, sonst 0)' {
        $mdsWoy | Should -BeOfType [int]
        $mdsWoy | Should -Be $(if ($IsWindows) { 26 } else { 0 })
    }

    It 'Show-Mds zeigt Version, woy und alle Ordner mit Quelle' {
        $zeilen = Show-Mds 6>$null
        $soll = @('System', 'mdsVersion', 'mdsWoy', 'mdsDev', 'mdsRepos', 'mdsRoot', 'mdsBin', 'mdsConfig', 'mdsData', 'mdsLogs', 'mdsTemp')
        if ($IsWindows) { $soll += 'mdsWoySrc', 'mdsWoyBin', 'mdsWoyRun' }
        $zeilen.Variable | Should -Be $soll
        ($zeilen | Where-Object Variable -eq 'System').Wert | Should -Be $(if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } else { 'Linux' })
        ($zeilen | Where-Object Variable -eq 'mdsVersion').Wert | Should -Be "$mdsVersion"
        ($zeilen | Where-Object Variable -eq 'mdsDev').Quelle | Should -Be 'DEV_HOME'
        ($zeilen | Where-Object Variable -eq 'mdsBin').Quelle | Should -Be 'Standard'
        ($zeilen | Where-Object Variable -eq 'mdsBin').Vorhanden | Should -BeTrue
    }

    It 'Show-Mds -Full (-F) zeigt zusaetzlich alle exportierten Befehle mit Beschreibung und Datei' {
        $basis = @(Show-Mds 6>$null)
        $zeilen = @(Show-Mds -F 6>$null)
        $befehle = $zeilen | Select-Object -Skip $basis.Count
        $export = (Get-Module MdsTools).ExportedFunctions.Keys
        foreach ($name in $export) { $befehle.Variable | Should -Contain $name }
        ($befehle | Where-Object Variable -eq 'go').Quelle | Should -Be 'Navigation.ps1'
        ($befehle | Where-Object Variable -eq 'Write-Info').Wert | Should -Be 'Gibt eine Info-Statuszeile aus.'
        ($befehle | Where-Object Variable -eq 'Show-Mds').Wert | Should -Match '^Zeigt die globalen mds-Variablen'
    }

    It 'lenkt Repos, Root und Config ueber DEV_REPOS, DEV_ROOT, DEV_CONFIG um' {
        $env:DEV_REPOS = Join-Path $TestDrive 'AndereRepos'
        $env:DEV_ROOT = Join-Path $TestDrive 'Laufzeit'
        $env:DEV_CONFIG = Join-Path $TestDrive 'Konfig'
        try {
            Import-Module $script:manifest -Force
            $mdsDev | Should -Be $env:DEV_HOME
            $mdsRepos | Should -Be $env:DEV_REPOS
            $mdsRoot | Should -Be $env:DEV_ROOT
            $mdsBin | Should -Be (Join-Path $env:DEV_ROOT 'Bin')
            $mdsConfig | Should -Be $env:DEV_CONFIG
        }
        finally {
            $env:DEV_REPOS = $null; $env:DEV_ROOT = $script:testRoot; $env:DEV_CONFIG = $null
            Import-Module $script:manifest -Force
        }
    }

    It 'nimmt $mdsBin genau einmal in den PATH auf' {
        Import-Module $script:manifest -Force
        @($env:PATH -split [IO.Path]::PathSeparator | Where-Object { $_ -eq $mdsBin }).Count | Should -Be 1
    }
}

Describe 'go' {
    BeforeEach { Push-Location $TestDrive }
    AfterEach { Pop-Location }

    It 'springt ohne Argument nach $mdsDev' {
        go
        (Get-Location).Path | Should -Be $mdsDev
    }

    It 'springt nach root (Gross-/Kleinschreibung egal)' {
        go ROOT
        (Get-Location).Path | Should -Be $mdsRoot
    }

    It 'springt nach repos' {
        go repos
        (Get-Location).Path | Should -Be $mdsRepos
    }

    It 'springt in ein Repo per Kurzname' {
        go net
        (Get-Location).Path | Should -Be (Join-Path $mdsRepos 'Net')
    }

    It 'springt nicht in Ordner ohne .git' {
        New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'OhneGit') -Force | Out-Null
        $warnung = go OhneGit 3>&1
        $warnung | Should -Match 'Unbekanntes Ziel'
        (Get-Location).Path | Should -Be $TestDrive.ToString()
    }

    It 'warnt bei unbekanntem Ziel und bleibt stehen' {
        $warnung = go gibtsnicht 3>&1
        $warnung | Should -Match 'Unbekanntes Ziel'
        (Get-Location).Path | Should -Be $TestDrive.ToString()
    }
}

Describe 'mk' {
    BeforeAll {
        # Test-Repo mit einem Make.ps1, das seine Parameter in eine Datei schreibt
        $script:protokoll = Join-Path $TestDrive 'mk-aufruf.txt'
        $scripts = Join-Path $mdsRepos 'Net/scripts'
        New-Item -ItemType Directory -Path $scripts -Force | Out-Null
        Set-Content -Path (Join-Path $scripts 'Make.ps1') -Value @"
param([string] `$Programm = '', [string] `$OutDir = '', [switch] `$List, [switch] `$Package)
"P=`$Programm|O=`$OutDir|L=`$List|K=`$Package" | Set-Content '$($script:protokoll)'
"@
        New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'Net/src/Tief') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'OhneMake') -Force | Out-Null
    }
    BeforeEach { Remove-Item $script:protokoll -ErrorAction SilentlyContinue }

    It 'ruft scripts/Make.ps1 des Repos auf (Gross-/Kleinschreibung egal), auch von ausserhalb' {
        Push-Location $TestDrive
        try { mk NET } finally { Pop-Location }
        Get-Content $script:protokoll | Should -Be 'P=|O=|L=False|K=False'
    }

    It 'reicht Programm, -OutDir und -List durch' {
        mk net DKB.CLI -OutDir Test -List
        Get-Content $script:protokoll | Should -Be 'P=DKB.CLI|O=Test|L=True|K=False'
    }

    It 'reicht -Package durch' {
        mk net DKB.CLI -Package
        Get-Content $script:protokoll | Should -Be 'P=DKB.CLI|O=|L=False|K=True'
    }

    It 'nimmt ohne Repo das Repo des aktuellen Ordners (auch aus Unterordnern)' {
        Push-Location (Join-Path $mdsRepos 'Net/src/Tief')
        try { mk } finally { Pop-Location }
        Get-Content $script:protokoll | Should -Be 'P=|O=|L=False|K=False'
    }

    It 'versteht im Repo-Ordner den ersten Parameter als Programm' {
        Push-Location (Join-Path $mdsRepos 'Net')
        try { mk DKB.CLI } finally { Pop-Location }
        Get-Content $script:protokoll | Should -Be 'P=DKB.CLI|O=|L=False|K=False'
    }

    It 'zeigt ohne Repo ausserhalb der Repos nur die Repos mit Make.ps1' {
        Push-Location $TestDrive
        try { $ausgabe = mk 6>&1 | Out-String } finally { Pop-Location }
        $ausgabe | Should -Match 'Net'
        $ausgabe | Should -Not -Match 'OhneMake'
        $script:protokoll | Should -Not -Exist
    }

    It 'meldet -Buchstaben mit Hinweis auf + und baut nichts' {
        $ausgabe = mk net -di 6>&1 | Out-String
        $ausgabe | Should -Match 'mk \+di'
        $script:protokoll | Should -Not -Exist
    }

    It 'reicht +Gruppen als Programm durch' {
        Push-Location (Join-Path $mdsRepos 'Net')
        try { mk +dI } finally { Pop-Location }
        Get-Content $script:protokoll | Should -Be 'P=+dI|O=|L=False|K=False'
    }

    It 'meldet ein Repo ohne Make.ps1' {
        Push-Location $TestDrive
        try { $ausgabe = mk OhneMake 6>&1 | Out-String } finally { Pop-Location }
        $ausgabe | Should -Match 'Kein Repo'
        $script:protokoll | Should -Not -Exist
    }
}

Describe 'run' {
    BeforeAll {
        # Test-Repo mit run-Skripten (_*.ps1) und einem Skript ohne Praefix, das nicht gelten darf
        $script:runProtokoll = Join-Path $TestDrive 'run-aufruf.txt'
        $scripts = Join-Path $mdsRepos 'Tools/scripts'
        New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'Tools/src') -Force | Out-Null
        New-Item -ItemType Directory -Path $scripts -Force | Out-Null
        Set-Content -Path (Join-Path $scripts '_Copy.ps1') -Value @"
param([string] `$Ziel = '', [switch] `$Force, [Parameter(ValueFromRemainingArguments)] `$Rest)
"Z=`$Ziel|F=`$Force|R=`$Rest" | Set-Content '$($script:runProtokoll)'
"@
        Set-Content -Path (Join-Path $scripts '_Sql.ps1') -Value "'sql' | Set-Content '$($script:runProtokoll)'"
        Set-Content -Path (Join-Path $scripts 'Intern.ps1') -Value "'intern' | Set-Content '$($script:runProtokoll)'"
    }
    BeforeEach { Remove-Item $script:runProtokoll -ErrorAction SilentlyContinue }

    It 'fuehrt scripts/_<Skript>.ps1 des Repos aus und reicht benannte Argumente durch' {
        Push-Location $TestDrive
        try { run tools copy -Ziel TEST-SRV -Force } finally { Pop-Location }
        Get-Content $script:runProtokoll | Should -Be 'Z=TEST-SRV|F=True|R='
    }

    It 'nimmt im Repo-Ordner den ersten Parameter als Skript (auch aus Unterordnern)' {
        Push-Location (Join-Path $mdsRepos 'Tools/src')
        try { run Copy SQL-SRV } finally { Pop-Location }
        Get-Content $script:runProtokoll | Should -Be 'Z=SQL-SRV|F=False|R='
    }

    It 'listet nur Skripte mit Praefix _ (ohne Praefix, ohne .ps1)' {
        Push-Location (Join-Path $mdsRepos 'Tools')
        try { $ausgabe = run -List 6>&1 | Out-String } finally { Pop-Location }
        $ausgabe | Should -Match 'Copy, Sql'
        $ausgabe | Should -Not -Match 'Intern'
        $script:runProtokoll | Should -Not -Exist
    }

    It 'listet ausserhalb der Repos alle Repos mit ihren Skripten' {
        Push-Location $TestDrive
        try { $ausgabe = run 6>&1 | Out-String } finally { Pop-Location }
        $ausgabe | Should -Match 'Tools: Copy, Sql'
        $ausgabe | Should -Not -Match 'Net:'
    }

    It 'fuehrt ein Skript ohne Praefix nicht aus' {
        Push-Location (Join-Path $mdsRepos 'Tools')
        try { $ausgabe = run Intern 6>&1 | Out-String } finally { Pop-Location }
        $ausgabe | Should -Match "Kein Skript '_Intern.ps1'"
        $script:runProtokoll | Should -Not -Exist
    }
}

Describe 'run (globale Skripte aus Mds/scripts)' {
    BeforeAll {
        $script:runProtokoll = Join-Path $TestDrive 'run-global.txt'
        $mds = Join-Path $mdsRepos 'Mds/scripts'
        $eigen = Join-Path $mdsRepos 'Eigen/scripts'
        New-Item -ItemType Directory -Path $mds, $eigen, (Join-Path $mdsRepos 'Eigen/src') -Force | Out-Null
        Set-Content -Path (Join-Path $mds '_backup.ps1') -Value @"
[CmdletBinding()] param([string] `$Repo = '', [switch] `$Force)
"B=`$Repo|F=`$Force|V=`$(`$PSBoundParameters['Verbose'] -eq `$true)|O=`$((Get-Location).Path)" | Set-Content '$($script:runProtokoll)'
"@
        Set-Content -Path (Join-Path $mds '_bauen.ps1') -Value "'bauen' | Set-Content '$($script:runProtokoll)'"
        Set-Content -Path (Join-Path $eigen '_copy.ps1') -Value "'copy' | Set-Content '$($script:runProtokoll)'"
    }
    BeforeEach { Remove-Item $script:runProtokoll -ErrorAction SilentlyContinue }

    It 'fuehrt ausserhalb der Repos das globale Skript mit Abkuerzung aus und reicht Argumente durch' {
        Push-Location $TestDrive
        try { run back Net -Force -Verbose } finally { Pop-Location }
        Get-Content $script:runProtokoll | Should -BeLike 'B=Net|F=True|V=True|O=*'
    }

    It 'nimmt im Repo ohne eigenes Skript das globale (aktueller Ordner bleibt)' {
        Push-Location (Join-Path $mdsRepos 'Eigen/src')
        try { run backup } finally { Pop-Location }
        Get-Content $script:runProtokoll | Should -Be "B=|F=False|V=False|O=$(Join-Path $mdsRepos 'Eigen/src')"
    }

    It 'bevorzugt das Skript des aktuellen Repos' {
        Push-Location (Join-Path $mdsRepos 'Eigen')
        try { run co } finally { Pop-Location }
        Get-Content $script:runProtokoll | Should -Be 'copy'
    }

    It 'meldet eine mehrdeutige Abkuerzung' {
        Push-Location $TestDrive
        try { $ausgabe = run ba 6>&1 | Out-String } finally { Pop-Location }
        $ausgabe | Should -Match 'nicht eindeutig'
        $script:runProtokoll | Should -Not -Exist
    }
}

Describe 'Show-Repos' {
    BeforeAll {
        # Zwei Git-Repos: eines mit "# Name – Beschreibung", eines mit Beschreibung in der Zeile danach
        $script:repoA = Join-Path $mdsRepos 'Alpha'
        $script:repoB = Join-Path $mdsRepos 'Beta'
        New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'OhneGit') -Force | Out-Null
        foreach ($r in $script:repoA, $script:repoB) {
            New-Item -ItemType Directory -Path $r -Force | Out-Null
            git -C $r init -q -b main 2>$null
        }
        Set-Content (Join-Path $script:repoA 'README.md') "# Alpha – Kurzbeschreibung Alpha`n`nText" -Encoding utf8
        Set-Content (Join-Path $script:repoB 'README.md') "# Beta`n`n> Zitat`n`nZweite Zeile gilt $('x' * 90)" -Encoding utf8
        git -C $script:repoA remote add origin 'https://github.com/Test/AlphaRepo.git'
        foreach ($r in $script:repoA, $script:repoB) {
            git -C $r add -A
            git -C $r -c user.name=Test -c user.email=test@example.invalid commit -q -m 'Start' 2>$null
        }
        Set-Content (Join-Path $script:repoB 'neu.txt') 'offen'
    }

    It 'listet nur Ordner mit .git, mit Repo-Name, Datum, Geändert und Beschreibung' {
        $zeilen = @(Show-Repos | Where-Object Name -in 'Alpha', 'Beta', 'OhneGit')
        $zeilen.Name | Should -Be @('Alpha', 'Beta')
        $a = $zeilen | Where-Object Name -eq 'Alpha'
        $a.Repo | Should -Be 'AlphaRepo'
        $a.Datum | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$'
        $a.'Geändert' | Should -BeFalse
        $a.Beschreibung | Should -Be 'Kurzbeschreibung Alpha'
        $b = $zeilen | Where-Object Name -eq 'Beta'
        $b.Repo | Should -Be ''
        $b.'Geändert' | Should -BeTrue
        $b.Beschreibung.Length | Should -Be 80
        $b.Beschreibung | Should -BeLike 'Zweite Zeile gilt x*…'
    }

    It 'zeigt mit -F zusaetzlich Branch, Stand und Remote' {
        $a = Show-Repos -F | Where-Object Name -eq 'Alpha'
        $a.Branch | Should -Be 'main'
        $a.Stand | Should -Be 'kein Upstream'
        $a.Remote | Should -Be 'https://github.com/Test/AlphaRepo.git'
    }
}

Describe 'Ausgabeordner (Get-TargetDir)' {
    It 'Standard im Repo ist $mdsBin/Kurzname/Programm' {
        InModuleScope MdsTools {
            Push-Location (Join-Path $mdsRepos 'Net/src')
            try { Get-TargetDir -Name 'MyApp' } finally { Pop-Location }
        } | Should -Be (Join-Path $mdsBin 'Net/MyApp')
    }

    It 'Standard ausserhalb eines Repos ist $mdsBin/Programm' {
        InModuleScope MdsTools {
            Push-Location $mdsRoot
            try { Get-TargetDir -Name 'MyApp' } finally { Pop-Location }
        } | Should -Be (Join-Path $mdsBin 'MyApp')
    }

    It 'entfernt .CLI aus dem Programmnamen' {
        InModuleScope MdsTools {
            Push-Location $mdsRoot
            try { Get-TargetDir -Name 'Tool.CLI' } finally { Pop-Location }
        } | Should -Be (Join-Path $mdsBin 'Tool')
    }

    It 'ein relativer Ordner gilt relativ zu $mdsBin' {
        InModuleScope MdsTools { Get-TargetDir -Folder 'Desktop' } | Should -Be (Join-Path $mdsBin 'Desktop')
    }

    It 'ein absoluter Ordner bleibt unveraendert' {
        $ziel = Join-Path $TestDrive 'Absolut'
        InModuleScope MdsTools -Parameters @{ Ziel = $ziel } { param($Ziel) Get-TargetDir -Folder $Ziel } |
            Should -Be $ziel
    }
}

Describe 'Publish-RID' {
    It 'passt zum Prozessor unter macOS' -Skip:(-not $IsMacOS) {
        $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } else { 'x64' }
        InModuleScope MdsTools { Get-PublishRuntimeIdentifier -Framework 'net10.0' } | Should -Be "osx-$arch"
        InModuleScope MdsTools { Get-PublishRuntimeIdentifier -Framework '@net10.0-maccatalyst' } | Should -Be "maccatalyst-$arch"
    }

    It 'ist win-x64 unter Windows' -Skip:(-not $IsWindows) {
        InModuleScope MdsTools { Get-PublishRuntimeIdentifier -Framework 'net10.0' } | Should -Be 'win-x64'
    }
}

Describe 'Freigabepfade (Get-ShareInfo)' {
    It 'zerlegt <Pfad>' -ForEach @(
        @{ Pfad = '\\srv\daten\a\b'; Server = 'srv'; Share = 'daten'; Rest = 'a/b' }
        @{ Pfad = '//srv/daten'; Server = 'srv'; Share = 'daten'; Rest = '' }
        @{ Pfad = 'smb://SRV/Daten/x'; Server = 'SRV'; Share = 'Daten'; Rest = 'x' }
    ) {
        $info = InModuleScope MdsTools -Parameters @{ Pfad = $Pfad } { param($Pfad) Get-ShareInfo $Pfad }
        $info.Server | Should -Be $Server
        $info.Share | Should -Be $Share
        $info.Rest | Should -Be $Rest
        $info.Key | Should -Be "$Server/$Share".ToLowerInvariant()
    }

    It 'liefert $null fuer lokale Pfade' -ForEach @('/Users/x', 'C:\Temp', '', '\\nurserver') {
        InModuleScope MdsTools -Parameters @{ Pfad = $_ } { param($Pfad) Get-ShareInfo $Pfad } | Should -BeNullOrEmpty
    }
}

Describe 'Dateifunktionen' {
    BeforeEach {
        $script:arbeit = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:arbeit | Out-Null
    }

    It 'Clear-BinFolder entfernt *.pdb/*.xml und fremde Ordner, behaelt runtimes und *.app' {
        $bin = Join-Path $script:arbeit 'bin'
        New-Item -ItemType Directory -Path (Join-Path $bin 'runtimes'), (Join-Path $bin 'fr'), (Join-Path $bin 'Andere.app/Contents') -Force | Out-Null
        'x' | Set-Content (Join-Path $bin 'app.dll'), (Join-Path $bin 'app.pdb'), (Join-Path $bin 'app.xml')
        'x' | Set-Content (Join-Path $bin 'Andere.app/Contents/Info.xml'), (Join-Path $bin 'Andere.app/Contents/app.pdb')
        Clear-BinFolder $bin 6>$null | Out-Null
        (Get-ChildItem $bin).Name | Sort-Object | Should -Be @('Andere.app', 'app.dll', 'runtimes')
        # Inhalt der .app bleibt unangetastet (sonst ist die Signatur ungueltig)
        (Get-ChildItem (Join-Path $bin 'Andere.app/Contents')).Name | Sort-Object | Should -Be @('app.pdb', 'Info.xml')
    }

    It 'Clear-BinFolder -Keep behaelt weitere Ordner' {
        $bin = Join-Path $script:arbeit 'bin'
        New-Item -ItemType Directory -Path (Join-Path $bin 'Template'), (Join-Path $bin 'Bilder'), (Join-Path $bin 'fr') -Force | Out-Null
        Clear-BinFolder $bin -Keep 'Template', 'Bilder' 6>$null | Out-Null
        (Get-ChildItem $bin).Name | Sort-Object | Should -Be @('Bilder', 'Template')
    }

    It 'Backup-Develop liefert den Pfad der ZIP, ohne -force das vorhandene Archiv, sonst $null' {
        $repo = Join-Path $script:arbeit 'Probe'
        New-Item -ItemType Directory -Path (Join-Path $repo '.git') -Force | Out-Null
        'x' | Set-Content (Join-Path $repo 'a.txt')
        $ziel = Join-Path $script:arbeit 'ziel'
        $zip = Backup-Develop -sourceDir $repo -targetDir $ziel -force 6>$null 3>$null
        $zip | Should -BeOfType [string]
        $zip | Should -BeLike "*Probe_$(Get-Date -Format yyyyMMdd).zip"
        Test-Path -LiteralPath $zip | Should -BeTrue
        Backup-Develop -sourceDir $repo -targetDir $ziel 6>$null 3>$null | Should -Be $zip
        $ohneGit = Join-Path $script:arbeit 'OhneGit'
        New-Item -ItemType Directory -Path $ohneGit | Out-Null
        Backup-Develop -sourceDir $ohneGit -targetDir $ziel 6>$null 3>$null | Should -BeNullOrEmpty
    }

    It 'Remove-OldFile behaelt die neuesten n Dateien' {
        1..5 | ForEach-Object {
            $datei = Join-Path $script:arbeit "bak$_.zip"
            'x' | Set-Content $datei
            (Get-Item $datei).LastWriteTime = (Get-Date).AddDays(-$_)
        }
        InModuleScope MdsTools -Parameters @{ Ordner = $script:arbeit } { param($Ordner) Remove-OldFile -Folder $Ordner -Pattern 'bak*.zip' -Max 2 } 6>$null | Out-Null
        (Get-ChildItem $script:arbeit -Filter 'bak*.zip').Name | Sort-Object | Should -Be @('bak1.zip', 'bak2.zip')
    }

    It 'Copy-ToZip und Get-ZipEntry ergeben einen Rundlauf' {
        $quelle = Join-Path $script:arbeit 'src'
        New-Item -ItemType Directory -Path (Join-Path $quelle 'sub') -Force | Out-Null
        'a' | Set-Content (Join-Path $quelle 'a.txt')
        'b' | Set-Content (Join-Path $quelle 'sub/b.txt')
        $archiv = Join-Path $script:arbeit 'test.zip'
        Copy-ToZip -Folder $quelle -Archiv $archiv | Out-Null
        (Get-ZipEntry -Archive $archiv).FullName | Sort-Object | Should -Be @('a.txt', 'sub/b.txt')
    }

    It 'Copy-FolderWithCredential kopiert lokal inkrementell' {
        $quelle = Join-Path $script:arbeit 'q'
        $ziel = Join-Path $script:arbeit 'z'
        New-Item -ItemType Directory -Path (Join-Path $quelle 'sub') -Force | Out-Null
        'a' | Set-Content (Join-Path $quelle 'a.txt')
        'b' | Set-Content (Join-Path $quelle 'sub/b.txt')
        Copy-FolderWithCredential $quelle $ziel -Recurse 6>$null | Should -Be 2
        Copy-FolderWithCredential $quelle $ziel -Recurse 6>$null | Should -Be 0
        Join-Path $ziel 'sub/b.txt' | Should -Exist
    }

    It 'Copy-FileWithCredential kopiert lokal eine Datei' {
        'a' | Set-Content (Join-Path $script:arbeit 'a.txt')
        Copy-FileWithCredential $script:arbeit (Join-Path $script:arbeit 'z') 'a.txt' | Should -BeTrue
    }
}

Describe 'Invoke-Make' {
    BeforeAll {
        $script:tabelle = [ordered]@{
            'Eins'    = @{ Projekt = 'src/Eins/Eins.csproj'; Group = 'a' }
            'Zwei'    = @{ Project = 'src/Zwei/Zwei.csproj'; OutDir = 'Desktop'; Group = 'B' }
            'NurWin'  = @{ Projekt = 'src/W/W.csproj'; Nur = 'Windows'; Group = 'a' }
            'NurMac'  = @{ Projekt = 'src/M/M.csproj'; Nur = 'MacOS'; Group = 'a' }
        }
        $script:repo = Join-Path $TestDrive 'MakeRepo'
        $script:scripts = Join-Path $script:repo 'scripts'
        $script:log = Join-Path $script:repo '.Log'
        $script:hookProtokoll = Join-Path $TestDrive 'hook.txt'
        New-Item -ItemType Directory -Path $script:scripts -Force | Out-Null
    }

    BeforeEach {
        Mock -ModuleName MdsTools Publish-DotNet { $true }
        Mock -ModuleName MdsTools Write-Host { }
        Remove-Item (Join-Path $script:scripts '*.ps1'), $script:log, $script:hookProtokoll -Recurse -ErrorAction SilentlyContinue
    }

    It 'baut alle Programme, ueberspringt fremde Betriebssysteme' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo 6>$null | Should -BeTrue
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 3 -Exactly
    }

    It 'Ausgabeordner: Tabelle, sonst Standard' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'zwei' 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $TargetDir -eq 'Desktop' -and $Path -like '*Zwei.csproj' }
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Eins' 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $TargetDir -eq '' -and $Path -like '*Eins.csproj' }
    }

    It '-OutDir uebersteuert die Tabelle' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' -OutDir 'Test' 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $TargetDir -eq 'Test' }
    }

    It '-Package wird an Publish-DotNet weitergegeben (Standard: ohne)' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { -not $Package }
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' -Package 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $Package }
    }

    It 'Keep der Tabelle wird an Publish-DotNet weitergegeben' {
        $tabelle = [ordered]@{ 'Vier' = @{ Project = 'src/V/V.csproj'; Keep = @('Template', 'Log') } }
        Invoke-Make -Programme $tabelle -RepoRoot $script:repo 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { ($Keep -join ',') -eq 'Template,Log' }
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $Keep.Count -eq 0 -and $Path -like '*Zwei.csproj' }
    }

    It 'meldet ein unbekanntes Programm mit $false' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Drei' 6>$null | Should -BeFalse
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 0 -Exactly
    }

    It 'liefert $false, wenn ein Build fehlschlaegt' {
        Mock -ModuleName MdsTools Publish-DotNet { $false }
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Eins' 6>$null | Should -BeFalse
    }

    It '-List baut nichts' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -List 6>$null | Out-Null
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 0 -Exactly
    }

    It '+Gruppen baut alle Programme der Gruppen (Gross-/Kleinschreibung egal)' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm '+b' 6>$null | Should -BeTrue
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $Path -like '*Zwei.csproj' }
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm '+Ab' 6>$null | Should -BeTrue
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 2 -Exactly -ParameterFilter { $Path -like '*Zwei.csproj' }
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 1 -Exactly -ParameterFilter { $Path -like '*Eins.csproj' }
    }

    It 'meldet eine unbekannte Gruppe mit $false' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm '+bx' 6>$null | Should -BeFalse
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 0 -Exactly
    }

    It 'ruft Init.ps1 und Post.ps1 mit Auswahl, Gruppen und Ergebnis auf' {
        Set-Content (Join-Path $script:scripts 'Init.ps1') "param(`$Auswahl, `$Gruppen, `$Programme) `"I:`${Auswahl}:`$(`$Gruppen -join ''):`$(`$Programme -join ',')`" | Add-Content '$($script:hookProtokoll)'"
        Set-Content (Join-Path $script:scripts 'Post.ps1') "param(`$Auswahl, `$Gruppen, `$Programme, `$Erfolg) `"P:`$Erfolg`" | Add-Content '$($script:hookProtokoll)'"
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo 6>$null | Should -BeTrue
        Get-Content $script:hookProtokoll | Should -Be @('I::AB:Eins,Zwei,NurWin,NurMac', 'P:True')
    }

    It 'ruft Init.ps1 und Post.ps1 nicht bei einem einzelnen Programm auf' {
        Set-Content (Join-Path $script:scripts 'Init.ps1') "'I' | Add-Content '$($script:hookProtokoll)'"
        Set-Content (Join-Path $script:scripts 'Post.ps1') "'P' | Add-Content '$($script:hookProtokoll)'"
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' 6>$null | Should -BeTrue
        Test-Path $script:hookProtokoll | Should -BeFalse
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm '+b' 6>$null | Should -BeTrue
        Get-Content $script:hookProtokoll | Should -Be @('I', 'P')
    }

    It 'bricht ab, wenn Init.ps1 fehlschlaegt' {
        Set-Content (Join-Path $script:scripts 'Init.ps1') "throw 'kaputt'"
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm '+b' 6>$null | Should -BeFalse
        Should -Invoke -ModuleName MdsTools Publish-DotNet -Times 0 -Exactly
    }

    It 'schreibt die Logdatei MakeOK bzw. MakeErr' {
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' 6>$null | Out-Null
        (Get-ChildItem $script:log).Name | Should -Match '^\d{4}-\d{2}-\d{2}_\d{6}_MakeOK\.log$'
        Remove-Item $script:log -Recurse
        Mock -ModuleName MdsTools Publish-DotNet { $false }
        Invoke-Make -Programme $script:tabelle -RepoRoot $script:repo -Programm 'Zwei' 6>$null | Out-Null
        (Get-ChildItem $script:log).Name | Should -Match '_MakeErr\.log$'
    }
}
