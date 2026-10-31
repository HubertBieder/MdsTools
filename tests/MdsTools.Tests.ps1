#Requires -Modules Pester
<#
.SYNOPSIS
    Pester-Tests fuer MdsTools (MdsTools.md, Schritt 8).

.DESCRIPTION
    Laedt das Modul aus dem Repo (nicht die installierte Kopie) mit $env:DEV_ROOT im
    Pester-TestDrive, damit weder ~/Dev noch der echte PATH veraendert werden.
    Aufruf: Invoke-Pester ./tests

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-10-31  Hubi/Claude   Erste Version
#>

BeforeAll {
    $script:alterDevRoot = $env:DEV_ROOT
    $script:alterPath = $env:PATH
    $env:DEV_ROOT = Join-Path $TestDrive 'Dev'
    $script:manifest = Join-Path $PSScriptRoot '../Modul/MdsTools/MdsTools.psd1'
    Remove-Module MdsTools -ErrorAction SilentlyContinue
    Import-Module $script:manifest -Force
    New-Item -ItemType Directory -Path (Join-Path $mdsRepos 'Net/src') -Force | Out-Null
}

AfterAll {
    Remove-Module MdsTools -ErrorAction SilentlyContinue
    $env:DEV_ROOT = $script:alterDevRoot
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
    It 'leitet alle Pfade aus DEV_ROOT ab' {
        $mdsDev | Should -Be $env:DEV_ROOT
        $mdsRepos | Should -Be (Join-Path $mdsDev 'Repos')
        $mdsRoot | Should -Be (Join-Path $mdsDev 'Root')
        $mdsBin | Should -Be (Join-Path $mdsRoot 'Bin')
        $mdsTemp | Should -Be (Join-Path $mdsRoot 'Temp')
    }

    It 'legt die Root-Unterordner an' -ForEach @('Bin', 'Config', 'Data', 'Logs', 'Temp') {
        Join-Path $mdsRoot $_ | Should -Exist
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

    It 'springt in ein Repo per Kurzname' {
        go net
        (Get-Location).Path | Should -Be (Join-Path $mdsRepos 'Net')
    }

    It 'warnt bei unbekanntem Ziel und bleibt stehen' {
        $warnung = go gibtsnicht 3>&1
        $warnung | Should -Match 'Unbekanntes Ziel'
        (Get-Location).Path | Should -Be $TestDrive.ToString()
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
        Clear-BinFolder $bin 6>$null | Out-Null
        (Get-ChildItem $bin).Name | Sort-Object | Should -Be @('Andere.app', 'app.dll', 'runtimes')
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
            'Eins'    = @{ Projekt = 'src/Eins/Eins.csproj' }
            'Zwei'    = @{ Projekt = 'src/Zwei/Zwei.csproj'; OutDir = 'Desktop' }
            'NurWin'  = @{ Projekt = 'src/W/W.csproj'; Nur = 'Windows' }
            'NurMac'  = @{ Projekt = 'src/M/M.csproj'; Nur = 'MacOS' }
        }
        $script:repo = Join-Path $mdsRepos 'Net'
    }

    BeforeEach {
        Mock -ModuleName MdsTools Publish-DotNet { $true }
        Mock -ModuleName MdsTools Write-Host { }
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
}
