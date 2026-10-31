#======================================================================
# Datei:        FileIO.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Kopieren, Sichern und Bereinigen von Ordnern und Dateien.
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (SkriptModule\*.psm1) uebernommen,
#                            Cmdlets umbenannt (siehe MdsTools.md, Umbenennungen)
#
# Oeffentlich: Clear-CodeFolder, Clear-Target, Remove-Folder, Backup-Develop, Get-OneDriveRoot
#======================================================================

$ExcludeFileExt = @( "*.bak", `
        "*.log", `
        "*.pdb", `
        "*.sdf", `
        "*.vssscc", `
        "*.vspscc", `
        "*.reposbak", `
        "*.tmp_proj", `
        "*.cache", `
        "*.user")

$ExcludeFolder = @( "*bin", `
        "*bin64", `
        "*obj", `
        "obj", `
        "x86", `
        "Build", `
        "alt", `
        "*.alt", `
        "bin", `
        "*tf", `
        "Doku", `
        "BuildLog", `
        "*eispiel", `
        "archiv", `
        "*backup", `
        "packages", `
        "*.vs", `
        "*obsolete", `
        ".mypy_cache", `
        "archive",
    "beispiele", `
        "*.git", `
        "*archiv")

# [intern] Duenne Delegation auf die gemeinsame Implementierung Resolve-MdsPath (Common.ps1).
function Resolve-FileIoPath([string] $Path, [string] $BasePath = "", [switch] $AllowMissing) {
    return Resolve-MdsPath -Path $Path -BasePath $BasePath -AllowMissing:$AllowMissing
}

# [intern] Entfernt bei Verzeichnispfaden den abschliessenden Trenner (ausser Laufwerkswurzel).
function Format-FileIoDirectoryPath([string] $Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $normalizedPath = $Path
    $minimumLength = if ($IsWindows) { 3 } else { 1 }
    if ($normalizedPath.Length -gt $minimumLength) {
        $normalizedPath = $normalizedPath.TrimEnd('\', '/')
    }

    return $normalizedPath
}

# [intern] Liefert den Pfadanteil von $ChildPath relativ zu $RootPath ("" wenn identisch/darueber).
function Get-RelativePathSegment([string] $RootPath, [string] $ChildPath) {
    $normalizedRoot = Format-FileIoDirectoryPath (Resolve-FileIoPath -Path $RootPath -AllowMissing)
    $normalizedChild = Resolve-FileIoPath -Path $ChildPath -AllowMissing

    if ($normalizedChild.Length -le $normalizedRoot.Length) {
        return ""
    }

    return $normalizedChild.Substring($normalizedRoot.Length).TrimStart('\', '/')
}

# [intern] Prueft, ob $name (case-insensitiv) auf eines der Wildcard-Muster $pattern passt.
function Test-InPattern([string] $name, [string[]] $pattern) {
    $x = $name.ToUpper()
    foreach ($muster in $pattern) {
        if ($x -like $muster.ToUpper()) {
            return $true
        }
    }
    return $false
}

# [intern] Prueft anhand der echten Dateiendung ($ExcludeFileExt) und .DS_Store, ob eine Datei
# kopiert/gesichert werden soll. Rueckgabewert: $true = relevant, $false = ausschliessen.
function Test-Extension([string] $destName) {
    if ([string]::IsNullOrWhiteSpace($destName)) {
        return $false
    }

    $fileName = [System.IO.Path]::GetFileName($destName)
    if ($fileName.Equals(".DS_Store", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    # Echte Dateiendung vergleichen statt Teilstring - vermeidet z. B. das
    # faelschliche Ausschliessen von "config.user.txt" durch das Muster "*.user".
    $extension = [System.IO.Path]::GetExtension($fileName)
    foreach ($ext in $ExcludeFileExt) {
        # $ext hat die Form "*.bak" -> Vergleich gegen die echte Endung ".bak"
        if ($extension.Equals($ext.Substring(1), [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }
    return $true
}

# [public] Copy-Folder — Kopiert relevante Dateien von $Source nach $Target. Mit -Recurse inkl.
# Unterordner, mit -Force alle Dateien (sonst nur neuere). $Pattern filtert die Dateinamen.
# Rueckgabewert: Anzahl der kopierten Dateien.
function Copy-Folder {
    [CmdletBinding()]
    param
    (
        [Parameter(HelpMessage = "Source Folder")]
        [string]$Source = "",

        [Parameter(Mandatory = $true, HelpMessage = "Target Folder")]
        [ValidateNotNullOrEmpty()]
        [string]$Target,

        [Parameter(Mandatory = $false, HelpMessage = "FilePattern")]
        [string []]$Pattern,

        [Parameter(Mandatory = $False, HelpMessage = "Copy of all Subdirectorys")]
        [switch]$Recurse = $false,

        [Parameter(Mandatory = $False, HelpMessage = "Copy of all Files")]
        [switch]$Force = $false
    )
    Begin {
        [bool]$shouldStop = $false
        $SourceFolder = [Collections.ArrayList]@()
        if ([string]::IsNullOrWhiteSpace($Source)) {
            $Source = (Get-Location).Path
        }

        $Source = Resolve-FileIoPath -Path $Source -AllowMissing
        $Target = Resolve-FileIoPath -Path $Target -AllowMissing

        if (!(Test-Path -LiteralPath $Source -PathType Container)) {
            Write-Fail "SourceDir $Source not found"
            $shouldStop = $true
        }
        if (!(Test-Path -LiteralPath $Target -PathType Container)) {
            New-Item -Path $Target -ItemType Directory -Force | Out-Null
        }
        if (!(Test-Path -LiteralPath $Target -PathType Container)) {
            Write-Fail "TargetDir $Target not found"
            $shouldStop = $true
        }
        if (!$shouldStop) {
            Write-Host "Copy-Folder: $Source ==> $Target" -ForeGroundColor Blue
            if ($Recurse) {
                $folder = @(
                    Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
                    Get-ChildItem -LiteralPath $Source -Recurse -Directory -Force -ErrorAction SilentlyContinue
                )
                $SourceFolder = [Collections.ArrayList]@(($folder | Sort-Object FullName | Select-Object -ExpandProperty FullName))
            }
            else {
                [void]$SourceFolder.Add($Source)
            }  
        }
    }
    Process {
        [int]$all = 0
        [int]$anz = 0
        if (!$shouldStop) {            
            foreach ($fld in $SourceFolder) {
                $relativePath = Get-RelativePathSegment -RootPath $Source -ChildPath $fld
                $targetFolder = if ([string]::IsNullOrWhiteSpace($relativePath)) { $Target } else { Join-Path -Path $Target -ChildPath $relativePath }
                if (($null -eq $Pattern) -or ($Pattern.Count -eq 0)) {
                    $quelle = Get-ChildItem -LiteralPath $fld -File | Where-Object Name -ne '.DS_Store'
                }
                else {
                    $quelle = Get-ChildItem -LiteralPath $fld -File | Where-Object -FilterScript { Test-InPattern $_.Name $Pattern }
                }
                if (($null -ne $quelle) -and ($quelle.Count -gt 0)) {
                    $i = $quelle.Count
                    Write-Verbose "[$i] $fld ==> $targetFolder"
                    $all += $i
                    if (!(Test-Path -LiteralPath $targetFolder -PathType Container)) {
                        Write-Verbose "Create TargetDir: $targetFolder"
                        New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                    }                    
                    if ($Force) {
                        $quelle | Copy-Item -Destination $targetFolder -Force -ErrorAction SilentlyContinue
                        $anz += $quelle.Count
                    }
                    else {
                        foreach ($file in $quelle) {
                            $ziel = Join-Path -Path $targetFolder -ChildPath $file.Name
                            if (!(Test-Path -LiteralPath $ziel)) {
                                Copy-Item -LiteralPath $file.FullName -Destination $ziel
                                if (Test-Path -LiteralPath $ziel -PathType Leaf) {
                                    $anz++
                                }
                            }
                            else {
                                $dest = Get-Item -LiteralPath $ziel -ErrorAction SilentlyContinue -Force
                                if ($dest.LastWriteTime -lt $file.LastWriteTime) {
                                    $dest.Delete()
                                    [void]$file.CopyTo($ziel)
                                    $anz++
                                    $dest = Get-Item -LiteralPath $ziel -ErrorAction SilentlyContinue -Force
                                    if ($null -ne $dest) {
                                        $dest.LastWriteTime = $file.LastWriteTime
                                        $dest.LastWriteTimeUtc = $file.LastWriteTimeUtc
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    End {
        Write-Verbose "$anz Files from $all copied"
        Write-Output $anz  
    }
}

# [public] Get-DevelopFiles — Sammelt rekursiv alle entwicklungsrelevanten Dateien unter
# $SourceDir (Filter via Test-Extension/$ExcludeFolder). Mit -Root nur die oberste Ebene.
# Rueckgabewert: String-Array der Dateipfade.
function Get-DevelopFiles {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "Path of the SourceDir")]
        [Alias("Source")]
        [string]$SourceDir = "",

        [Parameter(Mandatory = $False, HelpMessage = "Only Root Folder")]
        [switch]$Root = $false
    )
    begin {
        [string[]] $files = @()
        # Prüfen der Parameter      
        if ([string]::IsNullOrWhiteSpace($SourceDir)) {
            $SourceDir = (Get-Location).Path
        }
        else {
            $SourceDir = Resolve-FileIoPath -Path $SourceDir
        }
        if (!(Test-Path -LiteralPath $SourceDir -PathType Container)) {
            throw "! $SourceDir not found" 
        }
    }
    process {               
        #Bearbeiten der gefundenen Dateien
        $dateien = Get-ChildItem -LiteralPath $SourceDir -File -Force -ErrorAction SilentlyContinue
        [string[]] $lokal = @()
        $a = $dateien.Count
        Write-Verbose "$SourceDir [$a] Files"
        foreach ($datei in $dateien) {
            if (Test-Extension $datei.Name) {
                $lokal += $datei.FullName
            }
        }        
        $sum = $lokal.Count
        Write-Verbose "[$sum] $SourceDir" 
        $files = $lokal
        if (!$root) {
            # Suche nach weiteren Foldern
            $folders = Get-ChildItem -LiteralPath $SourceDir -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { -not (Test-InPattern $_.Name $ExcludeFolder) }
            foreach ($dir in $folders) {
                $files = $files + (Get-DevelopFiles -SourceDir $dir.FullName)
            }
        }
    }
    end {
        # Abschluss und Aufräumen
        return $files
    }
}

# [public] Remove-OldFile — Behaelt im $Folder nur die $Max neuesten Dateien je $Pattern (z. B.
# ZIP-Backups) und loescht die aelteren. Rueckgabewert: $true, wenn etwas geloescht wurde.
function Remove-OldFile {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Working Folder")]
        [ValidateScript({ Test-Path $_ })]
        [string]$Folder,
        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "FilePattern")]
        [string]$Pattern = "*.zip",
        [Parameter(Position = 2, Mandatory = $false, HelpMessage = "Max Count of Files")]
        [int]$Max = 3
    )
    Begin {
        $Folder = Resolve-FileIoPath -Path $Folder
        $search = Join-Path -Path $Folder -ChildPath $Pattern
        if (!$Pattern.Contains("*")) {
            $search = "$search*"      
        }
        Write-Info "Remove-OldFile, $search on Max $Max"
        $dateien = Get-ChildItem -Path $search -File | Sort-Object LastWriteTime -Descending
        $clear = 0
        if ($null -ne $dateien) {
            $anz = $dateien.Count
            if ($anz -gt $max) {
                for ($i = $Max; $i -lt $anz; $i++) {
                    try {
                        Remove-Item -LiteralPath $dateien[$i].FullName -Force -ErrorAction SilentlyContinue
                        Write-Verbose $dateien[$i]
                        $clear++                       
                    }
                    catch {
                    }
                }
            }
        }
        return ($clear -gt 0)
    }
}

# [public] Get-OneDriveRoot — Ermittelt die OneDrive-Wurzel ("OneDrive - <name>"); mit $subDir
# den passenden Unterordner. Rueckgabewert: Pfad oder "" wenn nicht gefunden.
#   Windows: D:\@HB (MARS) bzw. C:\ + "OneDrive - <name>"
#   macOS:   ~/Library/CloudStorage/OneDrive-<name> (Leerzeichen im Namen werden ignoriert)
# 2026-10-31 Hubi/Claude: macOS ergaenzt
function Get-OneDriveRoot() {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Unterordner (Muster)")]
        [string]$subDir = "",

        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "Name des OneDrive-Kontos")]
        [string]$name = "Familie Bieder"
    )
    begin {
        if ($IsMacOS) {
            $cloud = Join-Path $HOME 'Library/CloudStorage'
            $kompakt = $name -replace '\s', ''
            $root = Get-ChildItem -LiteralPath $cloud -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue |
                Where-Object { ($_.Name -replace '\s', '') -like "OneDrive*$kompakt*" } |
                Select-Object -First 1 -ExpandProperty FullName
            if (-not $root) {
                return ""
            }
        }
        else {
            ##D:\@HB\OneDrive - Familie Bieder
            if (($env:computername -eq "MARS") -and (Test-Path -Path "D:\@HB" -PathType Container)) {
                $root = "D:\@HB"
            }
            else {
                $root = "C:\"
            }
            $root = Join-Path -Path $root -ChildPath "OneDrive - $name"
        }
        if ($subDir.Length -gt 0) {
            $foundDirs = Get-ChildItem -LiteralPath $root -Directory -Filter $subDir -ErrorAction SilentlyContinue
            if ($foundDirs.Length -gt 0) {
                return $foundDirs[0].FullName
            }
        }
        if (Test-Path -LiteralPath $root -PathType Container) {
            return $root
        }
        return ""
    }
}

# [public] Backup-Develop — Sichert ein Git-Arbeitsverzeichnis als datierte ZIP nach $targetDir
# (Standard: OneDrive-*_Backup, unter Windows sonst <Laufwerk>\_Backup, unter macOS $mdsRoot/Backup). Mit -force wird ein vorhandenes
# Tagesarchiv ueberschrieben. Rueckgabewert: $true bei erstelltem Backup.
function Backup-Develop() {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "sourceDir")]
        [string]$sourceDir = "",

        [Parameter(Position = 1, Mandatory = $false, HelpMessage = "targetDir")]
        [string]$targetDir = "",

        [Parameter(Mandatory = $False, HelpMessage = "unbedingt ausführen")]
        [switch]$force = $false
    )
    Begin {
        [bool] $result = $false

        $folderName = ""
        $archiv = ""
        if ([string]::IsNullOrWhiteSpace($sourceDir)) {
            $sourceDir = (Get-Location).Path
        }
        else {
            $sourceDir = Resolve-FileIoPath -Path $sourceDir
        }
        $test = Join-Path -Path $sourceDir -ChildPath ".git" 
        if (Test-Path -LiteralPath $test -PathType Container) {
            $folderName = Split-Path $sourceDir -Leaf
        }
        else {
            $sourceDir = ""
            $folderName = ""
        }
        if ($sourceDir.Length -gt 0) {
            if ($targetDir.Length -eq 0) {
                ## Suche nach   D:\@HB\OneDrive - Familie Bieder\4_Backup    
                $targetDir = Get-OneDriveRoot "*_Backup"
            }
            if (($targetDir.Length -eq 0) -and $IsWindows) {
                $drives = get-psdrive -psprovider "FileSystem" 
                foreach ($drive in $drives) {
                    $sub = $drive.Root + "_Backup"
                    if (Test-Path -Path $sub -PathType Container) {
                        $targetDir = $sub
                        break
                    }
                }   
            }
            if ($targetDir.Length -eq 0) {
                $targetDir = if ($IsWindows) { "D:\_Backup" } else { Join-Path $mdsRoot 'Backup' }
                if (!(Test-Path -LiteralPath $targetDir)) {
                    $null = New-Item -Path $targetDir -ItemType directory -Force
                }
            }
            $targetDir = Join-Path -Path $targetDir -ChildPath $folderName
            if (!(Test-Path -LiteralPath $targetDir)) {
                $null = New-Item -Path $targetDir -ItemType directory -Force
            }
            $datum = Get-Date -Format yyyyMMdd
            $name = $folderName + "_" + "$datum.zip"
            $archiv = Join-Path -Path $TargetDir -ChildPath $name     
            if ($force) {
                Remove-Item -LiteralPath $archiv -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            Write-Fail "RootDir not found"
        }
    }
    Process {
        if (Test-Path -LiteralPath $archiv) {
            Write-Warning "$Archiv already exist"
        }
        else {
            if ($sourceDir.Length -gt 0) {
                Write-Info  "Backup [$sourceDir] ==> $archiv"
                $dateien = Get-DevelopFiles -SourceDir $sourceDir
                Copy-FileToZip -Files $dateien -Archiv $archiv -Root $sourceDir    
                $result = $true
            }
            else {
                Write-Warning "SourceDir not exist"
            }
        }
    }
    End {
        Write-Output $result
    }
}

# [public] Clear-CodeFolder — Entfernt ueberfluessige Ordner (bin/obj/build/.git ...) und Dateien
# (*.bak/*.sik/*.tmp) sowie doppelte .sln unterhalb eines Code-Verzeichnisses.
function Clear-CodeFolder([string]$Folder) {
    if ([string]::IsNullOrWhiteSpace($Folder)) {
        $Folder = (Get-Location).Path
    }
    else {
        $Folder = Resolve-FileIoPath -Path $Folder
    }
    if (Test-Path -LiteralPath $Folder) {
        Write-Start "Clear-CodeFolder $Folder"
        foreach ($folderPattern in @("backup", "packages", "obj", "build*", "bin", "alt", "bin64", "x86", "*obsolete", ".git")) {
            Write-Info "Remove Folder $folderPattern"
            Get-ChildItem -Path (Join-Path -Path $Folder -ChildPath '*') -Recurse -Directory -Force -Filter $folderPattern -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        foreach ($filePattern in @("*.bak", "*.sik", "*.tmp")) {
            Write-Info "Remove Files $filePattern"
            Get-ChildItem -Path (Join-Path -Path $Folder -ChildPath '*') -Recurse -File -Force -Filter $filePattern -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        }
        $all = Get-ChildItem -Path (Join-Path -Path $Folder -ChildPath '*') -Recurse -Force -File -Filter *.sln -ErrorAction SilentlyContinue
        if ($all.Count -gt 1) {
            Write-Info "Find Double Solution Files"
            foreach ($akt in $all) {
                if ($akt.Directory.Fullname.Length -gt $Folder.Length) {
                    Write-Info "Lösche $akt"
                    Remove-Item -Path $akt.FullName -Force
                }
            }
        }
        Write-Success "Clear-DevelopFolder $Folder"        
    }
}

# [public] Remove-Folder — Entfernt ein Verzeichnis rekursiv. Rueckgabewert: $true, wenn es
# danach nicht mehr existiert.
function Remove-Folder {
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory = $false, HelpMessage = "Folder to remove")]
        [string]$Folder = $null
    )
    Begin {
        if (-not [string]::IsNullOrWhiteSpace($Folder)) {
            $Folder = Resolve-FileIoPath -Path $Folder -AllowMissing
            if (Test-Path -LiteralPath $Folder) {
                try {
                    Remove-Item -LiteralPath $Folder -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Verbose "Folder $Folder removed"
                }
                catch {
                    $err = $_.Exception.Message
                    Write-Fail "Remove-Folder Error: $err"
                }
            }
            else {
                Write-Verbose "Folder $Folder not existing"
            }    
        }
        else {
            Write-Verbose "Foldername has to be defined"
        }   
    }
    End {
        if ((-not [string]::IsNullOrWhiteSpace($Folder)) -and (!(Test-Path -LiteralPath $Folder))) {
            Write-Output $true
        }
        else {
            Write-Output $false      
        }
    }
}

# [public] Clear-Target — Leert ein vorhandenes Zielverzeichnis (loescht den Inhalt) oder legt
# es neu an. Rueckgabewert: $true, wenn das Verzeichnis existiert.
function Clear-Target {
    param
    (
        [Parameter(Position = 0, Mandatory = $true, HelpMessage = "Target Dir")]
        [string] $target
    )
    if (Test-Path -Path $target) {
        Write-Host "Verzeichnis $target existiert bereits, lösche alte Dateien..."
        # Zielordner existiert bereits, löschen der alten Dateien
        Remove-Item -Path $target\* -Recurse
    }
    else {
        New-Item -Path $target -ItemType Directory -Verbose | Out-Null
    }
    return (Test-Path -Path $target)
}
