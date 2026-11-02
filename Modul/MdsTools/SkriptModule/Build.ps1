#======================================================================
# Datei:        Build.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Bauen und Veroeffentlichen von .NET-Projekten (dotnet build/publish).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (SkriptModule\*.psm1) uebernommen,
#                            Cmdlets umbenannt (siehe MdsTools.md, Umbenennungen)
#   2026-11-02  Hubi/Claude  Invoke-Make: Gruppen, Init.ps1/Post.ps1, Logdatei
#   2026-11-02  Hubi/Claude  Invoke-Make: Init.ps1/Post.ps1 nicht bei einzelnem Programm
#
# Oeffentlich: Publish-DotNet, Build-Project, Clear-BinFolder, Invoke-Make
#======================================================================

# [intern] Liefert den Pfad der dotnet-Executable (script/Global:DotNetExe oder PATH); Fallback "dotnet".
function Get-DotNetCommandPath() {
    if (-not [string]::IsNullOrWhiteSpace($script:DotNetExe)) {
        return $script:DotNetExe
    }

    if (-not [string]::IsNullOrWhiteSpace($Global:DotNetExe)) {
        return $Global:DotNetExe
    }

    $dotnetCommand = Get-Command -Name "dotnet" -ErrorAction SilentlyContinue
    if ($null -ne $dotnetCommand -and -not [string]::IsNullOrWhiteSpace($dotnetCommand.Source)) {
        return $dotnetCommand.Source
    }

    return "dotnet"
}

# [intern] Liefert den Publish-RID je OS, Prozessor und Framework.
#   macOS:   osx-arm64 / maccatalyst-arm64 (Apple Silicon) bzw. osx-x64 / maccatalyst-x64 (Intel)
#   Windows: win-x64
# 2026-10-31 Hubi/Claude: macOS-Architektur wird erkannt statt fest x64
function Get-PublishRuntimeIdentifier([string] $Framework) {
    if ($IsMacOS) {
        $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq
            [System.Runtime.InteropServices.Architecture]::Arm64) { 'arm64' } else { 'x64' }
        if ($Framework.StartsWith('@')) {
            return "maccatalyst-$arch"
        }
        return "osx-$arch"
    }

    return "win-x64"
}

# [intern] Erkennt Windows-spezifische Projekte (WPF/WinForms/-windows-Target), die unter macOS
# nicht baubar sind. Rueckgabewert: $true = nur Windows.
function Test-WindowsOnlyProject([string] $Proj) {
    # Mehrfach-Targets (MAUI) gelten als plattformuebergreifend.
    if ([string]::IsNullOrWhiteSpace($Proj) -or !(Test-Path -LiteralPath $Proj -PathType Leaf)) {
        return $false
    }

    $xmlproject = New-Object XML
    $xmlproject.Load((Resolve-MdsPath -Path $Proj))

    if ((Get-FrameworkValue -ProjectXml $xmlproject -ElementName "UseWPF").ToUpperInvariant().Contains("TRUE")) {
        return $true
    }
    if ((Get-FrameworkValue -ProjectXml $xmlproject -ElementName "UseWindowsForms").ToUpperInvariant().Contains("TRUE")) {
        return $true
    }
    foreach ($item in $xmlproject.GetElementsByTagName("TargetFramework")) {
        if ($item.InnerText.ToString().ToLowerInvariant().Contains("-windows")) {
            return $true
        }
    }
    return $false
}

# [intern] Liefert den ersten nicht-leeren InnerText des angegebenen csproj-Elements ("" wenn keiner).
function Get-FrameworkValue([xml] $ProjectXml, [string] $ElementName) {
    foreach ($element in $ProjectXml.GetElementsByTagName($ElementName)) {
        $value = $element.InnerText.ToString().Trim()
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    return ""
}

# [public] Find-CsProj — Ermittelt den Pfad einer .csproj: ohne $Proj die eindeutige im aktuellen
# Ordner, sonst per Name (auch rekursiv gesucht). Rueckgabewert: Voller Pfad oder "".
function Find-CsProj {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $False, HelpMessage = "Name of csproj-File")]
        [string] $Proj = ""
    )
    $currentPath = (Get-Location).Path
    if ([string]::IsNullOrWhiteSpace($Proj)) {
        $all = Get-ChildItem -LiteralPath $currentPath -File -Filter *.csproj
        $anz = $all.Count
        if ($anz -eq 1) {
            return $all[0].FullName
        }
    }
    else {
        if (!$Proj.ToLowerInvariant().EndsWith(".csproj")) {
            $Proj = $Proj + ".csproj"
        }
        if ([System.IO.Path]::IsPathRooted($Proj)) {
            if (Test-Path -LiteralPath $Proj -PathType Leaf) {
                return (Resolve-MdsPath -Path $Proj)
            }

            # Datei nicht am exakten Pfad: rekursiv unter dem naechsten
            # vorhandenen Elternverzeichnis nach dem Dateinamen suchen.
            # Faengt z. B. einen fehlenden Unterordner im Pfad ab
            # (Service\AufAPI.csproj -> Service\AufAPI\AufAPI.csproj).
            $leaf = Split-Path -Path $Proj -Leaf
            $searchRoot = Split-Path -Path $Proj -Parent
            while ((-not [string]::IsNullOrWhiteSpace($searchRoot)) -and !(Test-Path -LiteralPath $searchRoot -PathType Container)) {
                $searchRoot = Split-Path -Path $searchRoot -Parent
            }
            if ((-not [string]::IsNullOrWhiteSpace($searchRoot)) -and (Test-Path -LiteralPath $searchRoot -PathType Container)) {
                $found = @(Get-ChildItem -LiteralPath $searchRoot -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
                if ($found.Count -eq 1) {
                    Write-Verbose "csProj rekursiv gefunden: $($found[0].FullName)"
                    return $found[0].FullName
                }
                if ($found.Count -gt 1) {
                    Write-Fail "Mehrere Projektdateien '$leaf' unter '$searchRoot' gefunden - bitte einen eindeutigen Pfad angeben."
                    return ""
                }
            }

            Write-Fail "Keine Projektdatei: $Proj gefunden"
            return ""
        }
        if (Test-Path -LiteralPath $Proj -PathType Leaf) {
            return (Resolve-MdsPath -Path $Proj)
        }
        $searchPattern = Split-Path -Path $Proj -Leaf
        $all = Get-ChildItem -LiteralPath $currentPath -Recurse -File -Filter $searchPattern

        $anz = $all.Count
        if ($anz -eq 1) {
            return $all[0].FullName
        }
    }
    Write-Fail "Keine Projektdatei: $Proj gefunden"
    return ""
}

# [intern] Startet die zu $FileName gehoerende .exe im $TargetDir, falls vorhanden.
function Start-Exe {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $False, HelpMessage = "Bin Folder")]
        [string]$TargetDir = "",
        [Parameter(Position = 1, Mandatory = $False, HelpMessage = "Name of Application")]
        [string]$FileName = ""
    )
    if ([string]::IsNullOrWhiteSpace($TargetDir) -or [string]::IsNullOrWhiteSpace($FileName)) {
        Write-Fail "TargetDir und FileName werden benötigt"
        return
    }

    [string] $exe = Join-Path -Path $TargetDir -ChildPath "$FileName.exe"
    if (Test-Path -LiteralPath $exe -PathType Leaf) {
        Write-Info  "Starten von :  $exe"
        & $exe
    }
    else {
        Write-Fail "Projekt-Exe $exe nicht gefunden"
    }
}

# [intern] Ermittelt/erzeugt das Ausgabeverzeichnis. Ohne $Folder gilt der Standard
# $mdsBin/<Kurzname>/<Name> (Kurzname = Repo-Ordner unter $mdsRepos, in dem der aktuelle
# Ordner liegt); mit -IsBuild $mdsRoot/Temp/Build/<Name>. Ein relativer $Folder gilt
# relativ zu $mdsBin. Rueckgabewert: aufgeloester Zielpfad oder "".
# 2026-10-31 Hubi/Claude: Standard von $woyDev/Bin auf $mdsBin/<Kurzname> umgestellt (E10)
function Get-TargetDir {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $False, HelpMessage = "TargetFolder")]
        [string]$Folder = "",
        [Parameter(Position = 1, Mandatory = $False, HelpMessage = "Name of Application")]
        [string]$Name = "",
        [Parameter(Position = 2, Mandatory = $False, HelpMessage = "Build- oder Bin-Folder")]
        [bool]$IsBuild = $false
    )
    if ([string]::IsNullOrWhiteSpace($Folder)) {
        $resolvedName = $Name
        if ($resolvedName.ToUpperInvariant().EndsWith(".CLI")) {
            $resolvedName = $resolvedName.Substring(0, $resolvedName.Length - 4)
        }

        if ($IsBuild) {
            $Folder = Join-Path (Join-Path $mdsTemp 'Build') $resolvedName
        }
        else {
            $repo = Get-RepoShortName
            $Folder = if ($repo) { Join-Path (Join-Path $mdsBin $repo) $resolvedName } else { Join-Path $mdsBin $resolvedName }
        }
    }
    elseif ($Folder.StartsWith('~')) {
        $Folder = Join-Path $HOME $Folder.Substring(1).TrimStart([char]'/', [char]'\')
    }
    elseif (-not [System.IO.Path]::IsPathRooted($Folder) -and -not $Folder.StartsWith('.')) {
        $Folder = Join-Path $mdsBin $Folder
    }
    else {
        $Folder = Resolve-MdsPath -Path $Folder -AllowMissing
    }

    if (!(Test-Path -LiteralPath $Folder -PathType Container)) {
        New-Item -Path $Folder -Force -ItemType Directory | Out-Null
    }
    if (Test-Path -LiteralPath $Folder -PathType Container) {
        return (Resolve-MdsPath -Path $Folder)
    }
    Write-Fail "Keine Ausgabeverzeichnis gefunden"
    return ""
}

# [intern] Liefert den Kurznamen des Repos (Ordner unter $mdsRepos), in dem $Path liegt,
# sonst "". Standard fuer $Path ist der aktuelle Ordner.
function Get-RepoShortName([string] $Path = (Get-Location).Path) {
    $repos = [System.IO.Path]::GetFullPath($mdsRepos).TrimEnd([char]'/', [char]'\') + [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath($Path) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($repos, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ""
    }
    return $full.Substring($repos.Length).Split([char[]]@('/', '\'), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
}

# [intern] Packt einen Ordner als datierte <Name>_yyyyMMdd.zip in dessen Elternordner (via Copy-ToZip).
function New-ZipArchiv {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $False, HelpMessage = "Source Folder")]
        [string]$Folder = ""
    )
    if ([string]::IsNullOrWhiteSpace($Folder)) {
        return ""
    }

    $sourceFolder = Resolve-MdsPath -Path $Folder
    $d = (Get-Date -format "yyyyMMdd")
    $archiv = (Get-Item -LiteralPath $sourceFolder).Parent.FullName
    if (Test-Path -LiteralPath $archiv -PathType Container) {
        $fileName = (Get-Item -LiteralPath $sourceFolder).Basename + "_" + $d + ".zip"
        $zip = Join-Path -Path $archiv -ChildPath $fileName
        if (Test-Path -LiteralPath $zip -PathType Leaf) {
            Write-Host  "$zip bereits vorhanden"
        }
        else {
            Write-Host "Packen von $archiv"
            if (Copy-ToZip -Folder $sourceFolder -Archive $zip) {
                Write-Host "$zip erstellt"
                return $zip
            }
        }
    }
    return ""
}

# [public] Get-TargetFramework — Ermittelt aus einer .csproj das relevante TargetFramework von
# ausfuehrbaren Projekten. Praefix kodiert den Typ: "!"=NET-Exe, "@"=MAUI-Exe; "" bei Libraries.
function Get-TargetFramework {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $False, ValueFromPipeline = $true, HelpMessage = "csProj-File")]
        [string]$Proj = ""
    )
    process {
        if (![string]::IsNullOrWhiteSpace($Proj)) {
            $exe = ""
            $target = ""
            if (Test-Path -LiteralPath $Proj -PathType Leaf) {
                $resolvedProj = Resolve-MdsPath -Path $Proj
                $xmlproject = New-Object XML
                $xmlproject.Load($resolvedProj)
                $outputType = Get-FrameworkValue -ProjectXml $xmlproject -ElementName "OutputType"
                if ($outputType.ToUpperInvariant().Contains("EXE")) {
                    Write-Verbose "OutputType: $outputType"
                    $exe = "!"
                }
                if ($exe.Length -gt 0) {
                    $useMaui = Get-FrameworkValue -ProjectXml $xmlproject -ElementName "UseMaui"
                    if ($useMaui.ToUpperInvariant().Contains("TRUE")) {
                        Write-Verbose "UseMaui: $useMaui"
                        $exe = "@"
                    }

                    if ($exe -eq "@") {
                        foreach ($frameworkList in $xmlproject.GetElementsByTagName("TargetFrameworks")) {
                            $values = $frameworkList.InnerText.ToString().Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
                            $target = ($values | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)

                            if ($IsMacOS) {
                                $target = ($values | ForEach-Object { $_.Trim() } | Where-Object { $_.ToLowerInvariant().Contains("mac") } | Select-Object -First 1)
                                if (-not [string]::IsNullOrWhiteSpace($target)) {
                                    Write-Verbose "MacTarget: $target"
                                    break
                                }
                            }
                            elseif ($IsWindows) {
                                $target = ($values | ForEach-Object { $_.Trim() } | Where-Object { $_.ToLowerInvariant().Contains("win") } | Select-Object -First 1)
                                if (-not [string]::IsNullOrWhiteSpace($target)) {
                                    Write-Verbose "WinTarget: $target"
                                    break
                                }
                            }

                            if (-not [string]::IsNullOrWhiteSpace($target)) {
                                break
                            }
                        }
                    }
                    else {
                        foreach ($item in $xmlproject.GetElementsByTagName("TargetFramework")) {
                            $value = $item.InnerText.ToString().Trim()
                            if ($value.ToUpperInvariant().Contains("NET")) {
                                $target = $value
                                Write-Verbose "Target: $target"
                                break
                            }
                        }
                    }
                    if ($exe.StartsWith("@")) {
                        Write-Verbose "MauiExe - Target: $target"
                    }
                    else {
                        Write-Verbose "NetExe - Target: $target"
                    }
                    return "$exe$target"
                }
            }
        }
        return ""
    }
}

# [intern] Prueft eine csproj-Datei: 2 = MAUI-Exe, 1 = normale Exe, 0 = Library/keine.
function Test-MauiExe([string]$FileName) {
    if (![string]::IsNullOrWhiteSpace($FileName)) {
        #https://www.windowspro.de/script/select-string-dateien-suchen-powershell
        $content = Get-Content -LiteralPath $FileName
        if (Select-String -InputObject $content -Pattern "<OutputType>Exe") {
            if (Select-String -InputObject $content -Pattern "<UseMaui>true") {
                return 2
            }
            return 1
        }
    }
    return 0
}

# [public] Clear-BinFolder — Bereinigt ein Publish-/Bin-Verzeichnis: entfernt ueberfluessige
# Dateien (mit -IsDebug bleiben *.pdb) und nicht benoetigte Unterordner. Behaelt die .mui-
# Kulturordner der aktuellen UI-Sprache (sonst WinUI-Crash 0xC0000409).
function Clear-BinFolder {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Folder to clear")]
        [string]$Folder,

        [Parameter(Mandatory = $false, HelpMessage = "Es ist ein Debug Build")]
        [switch]$IsDebug
    )
    Begin {
        if (($null -eq $Folder) -or ($Folder.Length -eq 0)) {
            $Folder = (Get-Location).Path
        }
        else {
            $Folder = Resolve-FileIoPath -Path $Folder -AllowMissing
        }
        if (Test-Path -LiteralPath $Folder) {
            $ProgressPreference = 'SilentlyContinue'
            Write-Header "Clear-BinFolder: $Folder"
            [int] $vorher = (Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue | Measure-Object).Count
            #Microsoft.Sql*.dll braucht man doch
            $pattern = "mscorlib.dll,*.xml,*.bak,*.msi,*.nlp,*.log,*.manifest,*.release,ExtractZip.exe.config"
            if ($IsDebug) {
                $pattern = "$pattern"
            }
            else {
                $pattern = "$pattern,*.pdb"
            }
            $patterns = $pattern.Split(',')
            # Dateien in *.app-Paketen (macOS) nie anfassen: jede Aenderung bricht die Signatur.
            # 2026-11-01 Hubi/Claude
            Get-ChildItem -Path (Join-Path -Path $Folder -ChildPath '*') -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '\.app[\\/]' -and (Test-InPattern $_.Name $patterns) } |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
            [int] $nachher = $vorher - (Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue | Measure-Object).Count
            if ($nachher -gt 0) {
                Write-Verbose "$nachher Files removed"
            }
            else {
                Write-Verbose "No Files removed"
            }
            [int] $anz = 0
            # Immer zu behaltende Funktions-/Asset-Ordner. Zusaetzlich bleiben alle *.app-Pakete
            # (macOS/MAUI), sonst loescht ein Build in einen gemeinsamen Ordner die anderen Apps.
            # 2026-10-31 Hubi/Claude: *.app ergaenzt
            # 2026-11-02 Hubi/Claude: PlugIns ergaenzt - der TaskScheduler (Bin/Task) traegt seine Tasks in
            #                         PlugIns/<Name>; ein Neubau des Schedulers darf sie nicht loeschen
            $keepFolders = @('runtimes', 'images', 'wwwRoot', 'Microsoft.UI.Xaml', 'NpuDetect', 'PlugIns')
            # WinUI 3 (MAUI-Windows) laedt beim Start die nativen .mui-Ressourcen
            # passend zur UI-Sprache des Rechners. Fehlt der Ordner der aktuellen
            # UI-Kultur (z. B. de-DE) bzw. der englische Fallback, bricht die App
            # mit Fail-Fast (ExitCode 0xC0000409) ab - der Splash erscheint, dann
            # stuerzt sie ab. Daher diese Kultur-Ordner behalten; alle uebrigen
            # (rund 115) Sprachordner duerfen entfernt werden.
            $ui = [System.Globalization.CultureInfo]::CurrentUICulture
            $keepFolders += $ui.Name, $ui.TwoLetterISOLanguageName, 'en', 'en-US'
            if (-not [string]::IsNullOrWhiteSpace($ui.Parent.Name)) { $keepFolders += $ui.Parent.Name }
            $keepFolders = $keepFolders | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique
            Write-Verbose "Behaltene Ordner: $($keepFolders -join ', ')"
            $ClearFolder = @()
            $ClearFolder = Get-ChildItem -LiteralPath $Folder -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $keepFolders -and $_.Extension -ne '.app' }
            Remove-Folder -Folder (Join-Path -Path $Folder -ChildPath 'Debug') | Out-Null
            # WICHTIG: Schleifenvariable NICHT $folder nennen - sie kollidiert
            # mit dem [string]-Parameter $Folder (case-insensitiv). Dadurch
            # wuerde das DirectoryInfo zu einem String und .FullName leer sein.
            foreach ($sub in $ClearFolder ) {
                if (Remove-Folder -Folder $sub.FullName) {
                    $anz++
                }
            }
            if ($anz -gt 0) {
                Write-Verbose "$anz Folder cleared"
            }
        }
        else {
            Write-Warning "Folder $Folder not exisiting"
        }
    }
}

# [intern] Kopiert die fertige <App>.app aus bin/<Config>/<Framework>/<RID> des Projekts in den
# Zielordner (vorhandene .app wird ersetzt). ditto erhaelt Bundle-Struktur, Symlinks und Signatur.
# Rueckgabewert: Pfad der kopierten .app, leer bei Fehler.
# 2026-11-01 Hubi/Claude: erstellt
function Copy-AppBundle([string] $CsProj, [string] $Config, [string] $Frame, [string] $Rid, [string] $TargetDir) {
    $binDir = Join-Path (Split-Path -Path $CsProj -Parent) "bin/$Config/$Frame/$Rid"
    $app = Get-ChildItem -LiteralPath $binDir -Directory -Filter '*.app' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $app) {
        Write-Fail "Keine .app in $binDir gefunden"
        return ""
    }
    $ziel = Join-Path $TargetDir $app.Name
    if (Test-Path -LiteralPath $ziel) {
        Remove-Item -LiteralPath $ziel -Recurse -Force
    }
    & ditto $app.FullName $ziel
    if ($LastExitCode -ne 0) {
        Write-Fail "Kopieren von $($app.Name) nach $TargetDir fehlgeschlagen"
        return ""
    }
    Write-Info "App:           $ziel"
    return $ziel
}

# [public] Publish-DotNet — Veroeffentlicht ein .NET-Projekt per 'dotnet publish' (RID je OS/Prozessor, framework-
# abhaengig ermittelt) ins Zielverzeichnis; behandelt MAUI-/Windows-Besonderheiten und kann
# optional zippen/starten.
# macOS-MAUI (Mac Catalyst): Standard ist die direkt startbare <App>.app im Zielordner (ersetzt die
# vorhandene), mit -Package das Installationspaket <App>-<Version>.pkg zum Weitergeben.
# 2026-11-01 Hubi/Claude: .app statt .pkg als Standard, Schalter -Package
function Publish-DotNet {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $False, ValueFromPipeline = $true, HelpMessage = "Name of csProj-File")]
        [string] $Path = "",

        [Parameter(Position = 1, Mandatory = $False, HelpMessage = "OutputDirectory")]
        [string]$TargetDir = "",

        [Parameter(Mandatory = $False, HelpMessage = "Exe will be executed after build")]
        [ValidateNotNullOrEmpty()]
        [switch]$Run = $false,

        # Default: 64 Bit Mode vs AnyCPU
        [Parameter(Mandatory = $False, HelpMessage = "Compile with AnyCPU Architecture")]
        [ValidateNotNullOrEmpty()]
        [switch]$AnyCPU = $false,

        # Default: Release Mode vs Debug Mode (with more warnings, no optimizations, etc.)
        [Parameter(Mandatory = $False, HelpMessage = "Compile in Release Mode")]
        [ValidateNotNullOrEmpty()]
        [switch]$IsDebug = $false,

        [Parameter(Mandatory = $False, HelpMessage = "Targetdirectory will be cleaned")]
        [ValidateNotNullOrEmpty()]
        [switch]$Clear = $false,

        [Parameter(Mandatory = $False, HelpMessage = "Result will be zipped")]
        [ValidateNotNullOrEmpty()]
        [switch]$Zip = $false,

        [Parameter(Mandatory = $False, HelpMessage = "Will be used a Build")]
        [ValidateNotNullOrEmpty()]
        [switch]$Build = $false,

        # macOS-MAUI: Standard ist die direkt startbare .app im Zielordner; mit -Package
        # das Installationspaket (.pkg) zum Weitergeben.
        [Parameter(Mandatory = $False, HelpMessage = "macOS-MAUI: Installationspaket (.pkg) statt .app")]
        [switch]$Package = $false
    )
    process {
        $csProj = Find-CsProj -Proj $Path
        if ($csProj.Length -gt 0) {
            $csProj = Resolve-MdsPath -Path $csProj
            Write-Verbose "csProj: $csProj"
            $fileName = (Get-Item -LiteralPath $csProj).BaseName

            # Ein WPF-/Windows-Programm ist unter MacOS nicht lauffaehig.
            if ($IsMacOS -and (Test-WindowsOnlyProject -Proj $csProj)) {
                Write-Fail "Das Projekt '$fileName' ist ein Windows-Programm (z. B. WPF) und kann unter MacOS nicht erstellt/ausgeführt werden."
                return $false
            }

            $framework = "net10.0"
            $api = $fileName.ToUpperInvariant().EndsWith("API")
            $isLib = $false
            if (!$api) {
                $exeFramework = Get-TargetFramework -Proj $csProj
                if ($exeFramework.Length -gt 0) {
                    $framework = $exeFramework
                }
                else {
                    # Kein EXE-OutputType -> Bibliothek: TargetFramework direkt aus der Projektdatei lesen.
                    $isLib = $true
                    $xmlproject = New-Object XML
                    $xmlproject.Load($csProj)
                    $framework = Get-FrameworkValue -ProjectXml $xmlproject -ElementName "TargetFramework"
                    if ($framework.Length -eq 0) {
                        $frameworkList = Get-FrameworkValue -ProjectXml $xmlproject -ElementName "TargetFrameworks"
                        if ($frameworkList.Length -gt 0) {
                            $framework = $frameworkList.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)[0].Trim()
                        }
                    }
                    if ($framework.Length -eq 0) {
                        Write-Fail "Kein TargetFramework in $fileName gefunden"
                        return $false
                    }
                }
            }
            # 2026-10-31 Hubi/Claude: Zielordner immer ueber Get-TargetDir (Standard
            # $mdsBin/<Kurzname>/<Programm>, relativer Pfad relativ zu $mdsBin, E10)
            $TargetDir = Get-TargetDir -Folder $TargetDir -Name $fileName -IsBuild $Build.IsPresent
            if ($TargetDir.Length -gt 0) {
                # WICHTIG: MSBuild-$(OutDir) MUSS auf einen Verzeichnistrenner enden.
                # Fehlt er, haengen WinUI/MAUI-Targets relative Pfade per String-
                # Konkatenation an (z. B. Platforms\Windows\App.xbf) -> es entsteht
                # ein Schwester-Verzeichnis "<Ziel>Platforms" statt "<Ziel>\Platforms".
                $TargetDir = $TargetDir.TrimEnd([char]'\', [char]'/') + [System.IO.Path]::DirectorySeparatorChar
                $rtm = Get-PublishRuntimeIdentifier -Framework $framework
                if ($framework.ToUpperInvariant().StartsWith("NET")) {
                    $frame = $framework
                }
                else {
                    $frame = $framework.Substring(1)
                }
                # Konfiguration: Standard Release, mit -IsDebug wird Debug compiliert
                # (mehr Warnungen, keine Optimierungen usw.).
                $config = "Release"
                if ($IsDebug) {
                    $config = "Debug"
                }
                # MAUI-Windows-Ziel (.NET 10): Ein Release-PUBLISH ist self-contained
                # und verlangt den Runtime-Pack Microsoft.NETCore.App.Runtime.win-x64.
                # Der wird beim RID-losen Restore (siehe Windows-Zweig unten) NICHT
                # geladen -> NETSDK1112 zusammen mit --no-restore. Deshalb hier zwingend
                # ein framework-dependenter Debug-BUILD (kein Runtime-Pack noetig).
                $isMauiWindows = $framework.StartsWith("@") -and $frame.ToLowerInvariant().Contains("-windows")
                if ($isMauiWindows) {
                    $config = "Debug"
                }
                # Architektur: Standard ueber den RID (Get-PublishRuntimeIdentifier), mit -AnyCPU wird
                # plattformneutral und ohne RuntimeIdentifier compiliert.
                $arch = $rtm
                if ($AnyCPU) {
                    $arch = "AnyCPU"
                }
                if ($isLib) {
                    $arch = "Lib"
                }
                Write-Start "DotNet-Publish V6: [$fileName] [$arch] [$frame] [$config]"
                Write-Info  "TargetFolder:  $TargetDir"
                $doIT = "publish"
                if ($Build) {
                    $doIT = "build"
                }
                # MAUI-Windows: immer BUILD (kein Publish) -> framework-dependent,
                # vermeidet den nicht ladbaren Runtime-Pack (NETSDK1112).
                if ($isMauiWindows) {
                    $doIT = "build"
                }
                # -Verbose des Aufrufers auswerten (CmdletBinding setzt VerbosePreference).
                # Mit -Verbose: Terminal-Logger mit vollem Build-Log.
                # Ohne -Verbose: dotnet gibt nur Warnungen und Fehler aus.
                [bool] $isVerbose = ($VerbosePreference -eq 'Continue')
                [string] $tl = "--tl:on"
                if (-not $isVerbose) {
                    $tl = "-v:q"
                }
                # Wird beim MAUI-Windows-Ziel gesetzt: Restore vorab OHNE RID, dann
                # Compilieren mit --no-restore (siehe Begruendung im Windows-Zweig).
                $separateRestore = $false
                # Mac Catalyst ohne -Package: .app nach dem Publish in den Zielordner kopieren.
                $copyApp = $false
                $appPath = ""
                # HINWEIS: Frueher wurde hier -p:NoWarn="CS86xx;$(NoWarn)" uebergeben.
                # Das funktioniert nicht wie gedacht: Kommandozeilen-Properties
                # ERSETZEN die Projektwerte ($(NoWarn) wird nicht expandiert),
                # wodurch z.B. die zentrale CA1416-Unterdrueckung aus der
                # Directory.Build.props verloren ging. Die Nullable-Warnings sind
                # inzwischen im Code beseitigt - Unterdrueckung entfaellt.
                if ($isLib) {
                    # Bibliothek: ohne AppHost und ohne RuntimeIdentifier
                    # veroeffentlichen - es werden nur die DLL und ihre
                    # Abhaengigkeiten in das Zielverzeichnis kopiert.
                    $arguments = @($doIT, $csProj, "-c", $config, $tl, "-f", $frame, "-o:$TargetDir")
                }
                elseif ($framework.StartsWith("!") -or $api) {
                    $arguments = @($doIT, $csProj, "-c", $config, "-p:UseAppHost=true", $tl, "-f", $frame)
                    if ($AnyCPU) {
                        # AnyCPU: keinen RID uebergeben, sonst wuerde plattform-
                        # spezifisch (x64) compiliert.
                        $arguments += "-p:PlatformTarget=AnyCPU"
                    }
                    else {
                        $arguments += "-r", $rtm
                    }
                    $arguments += "-o:$TargetDir"
                    if ($api) {
                        #DotNet publish "$csProj" -c Release --tl:on "-p:UseAppHost=true" -f net10.0 -r win-x64 --self-contained false -o:"$targetDir"
                        #verhindert runtime
                        $arguments += "--self-contained", "false"
                    }
                }
                else {
                    # MAUI-Veroeffentlichung. Beim Windows-Ziel KEIN explizites -r
                    # uebergeben: das MAUI-SDK setzt den RuntimeIdentifier (win-x64,
                    # CoreCLR) selbst. Mit "-r win-x64" wuerde stattdessen der fuer
                    # .NET 10 nicht existierende Mono-Runtime-Pack angefordert (NU1102).
                    if ($frame.ToLowerInvariant().Contains("-windows")) {
                        # Der vom SDK hergeleitete RID win-x64 wird beim impliziten
                        # Restore ueber Projektverweise auch auf die Mono-Ziel-
                        # frameworks (android/ios) referenzierter MAUI-Bibliotheken
                        # vererbt -> NU1102 fuer Microsoft.NETCore.App.Runtime.Mono.win-x64.
                        # Deshalb zuerst RID-los restoren (separater Aufruf weiter unten)
                        # und hier mit --no-restore compilieren.
                        $separateRestore = $true
                        $arguments = @($doIT, $csProj, "-c", $config, $tl, "-f", $frame, "--no-restore", "-o:$TargetDir")
                    }
                    elseif ($frame.ToLowerInvariant().Contains("-maccatalyst") -and -not $Package -and -not $Build) {
                        # Ohne Paket: die .app entsteht im bin-Ordner des Projekts und wird nach dem
                        # Publish kopiert. Mit -o legt dotnet sie unter dem vollen Quellpfad ab.
                        $copyApp = $true
                        $arguments = @($doIT, $csProj, "-c", $config, $tl, "-f", $frame, "-r", $rtm, "-p:CreatePackage=false")
                    }
                    else {
                        $arguments = @($doIT, $csProj, "-c", $config, $tl, "-f", $frame, "-r", $rtm, "-o:$TargetDir")
                    }
                }

                $dotNetCommand = Get-DotNetCommandPath
                $last = '"{0}" {1}' -f $dotNetCommand, ($arguments -join ' ')
                $logDir = Join-Path -Path (Get-Location).Path -ChildPath ".Log"
                if (-not (Test-Path -LiteralPath $logDir)) {
                    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
                }
                $datei = Join-Path -Path $logDir -ChildPath ("LOG-{0}.ps1" -f (Get-Item -LiteralPath $csproj).BaseName)
                Set-Content -LiteralPath $datei -Value $last -Encoding UTF8 -Force

                # Vorab RID-los restoren, damit der RID win-x64 nicht auf die
                # Mono-Zielframeworks der Projektverweise vererbt wird (NU1102).
                if ($separateRestore) {
                    if ($isVerbose) {
                        Write-Host ("### {0} restore {1}" -f $dotNetCommand, $csProj) -ForegroundColor Cyan
                        & $dotNetCommand restore $csProj | Write-Host
                    }
                    else {
                        # Ausgabe sammeln, damit sie die Spinner-Zeile nicht ueberschreibt.
                        $spin = Start-Spinner -Message "[$fileName] restore läuft"
                        try { $restoreOut = & $dotNetCommand restore $csProj -v:q 2>&1 }
                        finally { Stop-Spinner $spin }
                        if ($restoreOut) { $restoreOut | Write-Host }
                    }
                    if ($LastExitCode -ne 0) {
                        Write-Fail "restore of Project $fileName exited with ExitCode $($LastExitCode)."
                        return $false
                    }
                }

                # Finalen Aufruf auf dem Bildschirm anzeigen (zur Diagnose / zum Kopieren).
                # Nur mit -Verbose; ohne steht er weiterhin im .Log-Ordner.
                if ($isVerbose) {
                    Write-Host ("### {0}" -f $last) -ForegroundColor Cyan
                }

                # Waehrend des (oft langen) dotnet-Laufs einen Spinner anzeigen.
                # Im Verbose-Modus das volle Build-Log streamen (kein Spinner).
                # Sonst die dotnet-Ausgabe sammeln, damit sie die Spinner-Zeile nicht
                # ueberschreibt, und erst nach dem Spinner ausgeben.
                if ($isVerbose) {
                    & $dotNetCommand $arguments | Write-Host
                    $exit = $LastExitCode
                }
                else {
                    $spinner = Start-Spinner -Message "[$fileName] $doIT läuft"
                    try {
                        $dotnetOut = & $dotNetCommand $arguments 2>&1
                        $exit = $LastExitCode
                    }
                    finally {
                        Stop-Spinner $spinner
                    }
                    if ($dotnetOut) { $dotnetOut | Write-Host }
                }

                if ($exit -ne 0) {
                    Write-Fail "$doIT of Project $fileName exited with ExitCode $exit."
                    return $false
                }
                Write-Success "[$fileName] has been $doIT successfully"
                if ($copyApp) {
                    $appPath = Copy-AppBundle -CsProj $csProj -Config $config -Frame $frame -Rid $rtm -TargetDir $TargetDir
                    if ($appPath.Length -eq 0) {
                        return $false
                    }
                }
                # Nach Abschluss des Compilierens das Zielverzeichnis von nicht
                # benoetigten Dateien bereinigen (Clear-BinFolder).
                # Bei einer API wird immer bereinigt, sonst steuerbar ueber -Clear/-Zip/-Run.
                if ($Clear -or $Zip -or $Run -or $api) {
                    Clear-BinFolder $targetDir
                }
                if ($Zip) {
                    New-ZipArchiv -Folder $targetDir | Out-Null
                }
                if ($Run -and !$isLib) {
                    if ($appPath.Length -gt 0) {
                        Write-Info "Starten von :  $appPath"
                        & open $appPath
                    }
                    else {
                        Start-Exe $targetDir $fileName
                    }
                }
                return $true
            }
        }
        return $false
    }
}

# [public] Build-Project — Veroeffentlicht eine Liste von .csproj (via Publish-DotNet) in ein
# gemeinsames $Target (das zuvor geleert/angelegt wird). Rueckgabewert: $true, wenn alle Erfolg.
function Build-Project {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Project Files")]
        [string[]] $Projects,

        [Parameter(Position = 1, Mandatory = $true, HelpMessage = "Target Folder")]
        [string] $Target
    )
    if (-not (Clear-Target -target $target)) {
        Write-Error "Zielordner $target konnte nicht angelegt werden."
        return $false
    }

    [int] $fehler = 0
    [int] $erfolg = 0
    foreach ($csprj in $Projects) {
        if (-not (Test-Path -Path $csprj)) {
            $fehler++
            Write-Error "Projektdatei nicht gefunden: $csprj"
            continue
        }

        [string] $name = Split-Path -Path $csprj -LeafBase

        Write-Host ""
        Write-Host "=== $target === $name ======================================" -ForegroundColor Yellow

        if (Publish-DotNet -Path $csprj -TargetDir $target -Verbose:($VerbosePreference -eq 'Continue')) {
            $erfolg++
        }
        else {
            $fehler++
            Write-Error "$name nicht erstellt"
        }
    }
    Write-Host ""
    if (($erfolg -gt 0) -and ($fehler -eq 0)) {
        Clear-BinFolder -Folder $target
        Write-Host "Fertig! Alle Projekte erfolgreich erstellt. Erfolgreich: $erfolg" -ForegroundColor Green
    }
    else {
        Write-Host "Fertig!  ==> Erfolgreich: $erfolg  Fehlgeschlagen: $fehler" -ForegroundColor Cyan
    }
    return ($fehler -eq 0)
}

# [intern] Text einer Gruppe fuer die Anzeige: Buchstabe (gross) und, falls bekannt, ihr Name.
function Get-MakeGroupText([string] $Group, [System.Collections.IDictionary] $Gruppen) {
    if (-not $Group) { return "" }
    $g = $Group.ToUpperInvariant()
    $name = if ($Gruppen) { $Gruppen.Keys | Where-Object { $_ -eq $g } | ForEach-Object { $Gruppen[$_] } | Select-Object -First 1 }
    if ($name) { "$g $name" } else { $g }
}

# [intern] Ruft ein optionales Skript (Init.ps1/Post.ps1) mit den Argumenten auf, falls es existiert.
# Jeder Fehler im Skript gilt als Abbruch. Rueckgabewert: $false bei Fehler, sonst $true.
function Invoke-MakeHook([string] $Datei, [hashtable] $Argumente) {
    $name = Split-Path $Datei -Leaf
    if (-not (Test-Path -LiteralPath $Datei -PathType Leaf)) {
        Write-Info "$name nicht vorhanden - wird nicht ausgeführt"
        return $true
    }
    Write-Info "$name wird ausgeführt"
    try {
        $ErrorActionPreference = 'Stop'
        & $Datei @Argumente | Out-Host
        return $true
    }
    catch {
        Write-Fail "${name}: $($_.Exception.Message)"
        return $false
    }
}

# [public] Invoke-Make — Baut Programme eines Repos nach einer Programmtabelle. Wird von
# <Repo>/scripts/Make.ps1 aufgerufen (und damit von mk).
#   Programme  [ordered] Name -> @{ Project = <csproj relativ zu RepoRoot> (frueher Projekt, wird weiter verstanden)
#                                   Group   = <optional: ein Buchstabe, Gross-/Kleinschreibung egal>
#                                   OutDir  = <optional: relativ zu $mdsBin oder absolut>
#                                   Nur     = <optional: 'Windows' oder 'MacOS'> }
#   Gruppen    optional: Buchstabe -> Name der Gruppe (nur fuer die Anzeige)
#   RepoRoot   Wurzel des Repos (Standard: aktueller Ordner)
#   Programm   leer: alle Programme; +<Buchstaben>: alle Programme dieser Gruppen (z. B. +dI);
#              sonst nur dieses Programm (Name aus der Tabelle, Gross-/Kleinschreibung egal)
#   OutDir     Ausgabeordner fuer diesen Lauf, uebersteuert die Tabelle
#   List       Tabelle anzeigen statt bauen
#   Package    macOS-MAUI: Installationspaket (.pkg) statt direkt startbarer .app
# Ablauf: scripts/Init.ps1 -> Programme bauen -> scripts/Post.ps1 (beide optional). Sie erhalten
#   -Auswahl <Programm-Argument> -Gruppen <Buchstaben der gewaehlten Programme> -Programme <Namen>,
#   Post.ps1 zusaetzlich -Erfolg <$true/$false>. Ein Fehler in Init.ps1 bricht vor dem Bauen ab.
#   Nur bei allen Programmen oder +<Gruppen>, nicht bei einem einzeln angegebenen Programm.
# Log: <RepoRoot>/.Log/yyyy-MM-dd_HHmmss_MakeOK.log bzw. ..._MakeErr.log (Mitschnitt per Start-Transcript),
#   im selben Ordner wie die LOG-<Projekt>.ps1 von Publish-DotNet.
# Ausgabeordner: -OutDir, sonst OutDir der Tabelle, sonst $mdsBin/<Kurzname>/<Projekt> (E10).
# Rueckgabewert: $true, wenn alle ausgewaehlten Programme (und Init/Post) erfolgreich waren.
# 2026-10-31 Hubi/Claude: erstellt (MdsTools.md, Schritt 7)
# 2026-11-02 Hubi/Claude: Gruppen (+<Buchstaben>), Init.ps1/Post.ps1, Logdatei, Schluessel Project
# 2026-11-02 Hubi/Claude: Init.ps1/Post.ps1 nicht bei einzelnem Programm
function Invoke-Make {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, HelpMessage = "Programmtabelle")]
        [System.Collections.IDictionary] $Programme,

        [Parameter(Mandatory = $false, HelpMessage = "Wurzel des Repos")]
        [string] $RepoRoot = (Get-Location).Path,

        [Parameter(Mandatory = $false, HelpMessage = "Programm oder +<Gruppen>")]
        [string] $Programm = "",

        [Parameter(Mandatory = $false, HelpMessage = "Ausgabeordner fuer diesen Lauf")]
        [string] $OutDir = "",

        [Parameter(Mandatory = $false, HelpMessage = "Programmtabelle anzeigen")]
        [switch] $List,

        [Parameter(Mandatory = $false, HelpMessage = "macOS-MAUI: Installationspaket (.pkg) statt .app")]
        [switch] $Package,

        [Parameter(Mandatory = $false, HelpMessage = "Namen der Gruppen (Buchstabe -> Name)")]
        [System.Collections.IDictionary] $Gruppen = @{}
    )
    $repo = Get-RepoShortName $RepoRoot
    $projektVon = { param($p) if ($p.Project) { $p.Project } else { $p.Projekt } }
    $gruppeVon = { param($name) "$($Programme[$name].Group)".ToUpperInvariant() }
    if ($List) {
        $Programme.Keys | ForEach-Object {
            $p = $Programme[$_]
            $projekt = & $projektVon $p
            $ziel = if ($p.OutDir) { $p.OutDir } else { "$repo/$([System.IO.Path]::GetFileNameWithoutExtension($projekt))" }
            [pscustomobject]@{ Programm = $_; Gruppe = Get-MakeGroupText $p.Group $Gruppen; Ausgabe = $ziel; Nur = $p.Nur; Projekt = $projekt }
        } | Format-Table -AutoSize | Out-Host
        return $true
    }

    $namen = @($Programme.Keys)
    if ($Programm.StartsWith('+')) {
        $wahl = @($Programm.Substring(1).ToUpperInvariant().ToCharArray() | ForEach-Object { [string]$_ } | Select-Object -Unique)
        $bekannt = @($Programme.Keys | ForEach-Object { & $gruppeVon $_ } | Where-Object { $_ } | Select-Object -Unique)
        $unbekannt = @($wahl | Where-Object { $_ -notin $bekannt })
        if ($wahl.Count -eq 0 -or $unbekannt.Count -gt 0) {
            Write-Fail "Unbekannte Gruppe '$($unbekannt -join '')' in '$Programm'. Bekannt: $($bekannt -join ', ')"
            return $false
        }
        $namen = @($Programme.Keys | Where-Object { (& $gruppeVon $_) -in $wahl })
    }
    elseif ($Programm) {
        $namen = @($Programme.Keys | Where-Object { $_ -eq $Programm })
        if ($namen.Count -eq 0) {
            Write-Fail "Unbekanntes Programm '$Programm'. Bekannt: $($Programme.Keys -join ', ')"
            return $false
        }
    }
    $hookArgs = @{
        Auswahl   = $Programm
        Gruppen   = @($namen | ForEach-Object { & $gruppeVon $_ } | Where-Object { $_ } | Select-Object -Unique)
        Programme = $namen
    }
    $scripts = Join-Path $RepoRoot 'scripts'
    $mitHooks = -not $Programm -or $Programm.StartsWith('+')

    $logOrdner = Join-Path $RepoRoot '.Log'
    New-Item -ItemType Directory -Path $logOrdner -Force | Out-Null
    $stempel = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $logLauf = Join-Path $logOrdner "${stempel}_Make.log"
    Start-Transcript -LiteralPath $logLauf -UseMinimalHeader | Out-Null

    [int] $erfolg = 0
    [int] $fehler = 0
    [int] $uebersprungen = 0
    Push-Location -LiteralPath $RepoRoot
    try {
        if (-not $mitHooks) {
            Write-Info "Einzelnes Programm - Init.ps1 und Post.ps1 werden nicht ausgeführt"
        }
        $initOk = -not $mitHooks -or (Invoke-MakeHook (Join-Path $scripts 'Init.ps1') $hookArgs)
        if (-not $initOk) {
            $fehler++
            $namen = @()
        }
        foreach ($name in $namen) {
            $p = $Programme[$name]
            if (($p.Nur -eq 'Windows' -and -not $IsWindows) -or ($p.Nur -eq 'MacOS' -and -not $IsMacOS)) {
                Write-Info "$name wird nur unter $($p.Nur) gebaut - übersprungen"
                $uebersprungen++
                continue
            }
            $gruppe = Get-MakeGroupText $p.Group $Gruppen
            Write-Start ($gruppe ? "$name  [$gruppe]" : $name)
            $ziel = if ($OutDir) { $OutDir } elseif ($p.OutDir) { $p.OutDir } else { "" }
            $projekt = Join-Path $RepoRoot (& $projektVon $p)
            if (Publish-DotNet -Path $projekt -TargetDir $ziel -Clear -Package:$Package -Verbose:($VerbosePreference -eq 'Continue')) {
                $erfolg++
            }
            else {
                $fehler++
            }
        }
        if ($mitHooks -and $initOk) {
            if (-not (Invoke-MakeHook (Join-Path $scripts 'Post.ps1') ($hookArgs + @{ Erfolg = ($fehler -eq 0) }))) {
                $fehler++
            }
        }
        $farbe = if ($fehler -eq 0) { 'Green' } else { 'Red' }
        Write-Host "Fertig: $erfolg erfolgreich, $fehler fehlgeschlagen, $uebersprungen übersprungen" -ForegroundColor $farbe
    }
    finally {
        Pop-Location
        Stop-Transcript | Out-Null
        $art = $fehler -eq 0 ? 'MakeOK' : 'MakeErr'
        $log = Join-Path $logOrdner "${stempel}_$art.log"
        # Zwei Laeufe in derselben Sekunde: kein Log ueberschreiben
        for ($n = 2; Test-Path -LiteralPath $log; $n++) { $log = Join-Path $logOrdner "${stempel}_${art}_$n.log" }
        Move-Item -LiteralPath $logLauf -Destination $log
    }
    Write-Info "Log: $log"
    return ($fehler -eq 0)
}
