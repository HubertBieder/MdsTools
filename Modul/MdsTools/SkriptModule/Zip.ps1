#======================================================================
# Datei:        Zip.ps1  (wird von MdsTools.psm1 dot-gesourct)
# Beschreibung: Packen und Entpacken von ZIP-Archiven (System.IO.Compression).
#
# Versionshistorie:
#   2026-10-31  Hubi/Claude  Aus mdsPackage (SkriptModule\*.psm1) uebernommen,
#                            Cmdlets umbenannt (siehe MdsTools.md, Umbenennungen)
#
# Oeffentlich: Copy-ToZip, Copy-FileToZip, Export-FromZip, Get-ZipEntry
#======================================================================

# Assemblys fuer den Umgang mit ZIP-Dateien
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression

# [intern] Ermittelt den Eintragsnamen (relativ zu $RootPath, mit '/' als Trenner) einer
# Datei fuer die Ablage im ZIP. Ohne $RootPath wird nur der Dateiname verwendet.
function Get-ZipEntryName([string] $FilePath, [string] $RootPath = "") {
    $fileFullPath = Resolve-MdsPath -Path $FilePath

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        return (Split-Path -Path $fileFullPath -Leaf)
    }

    $rootFullPath = Resolve-MdsPath -Path $RootPath
    $comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
    $normalizedRoot = $rootFullPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

    if ($fileFullPath.StartsWith($normalizedRoot, $comparison)) {
        return $fileFullPath.Substring($normalizedRoot.Length).Replace('\', '/')
    }

    return (Split-Path -Path $fileFullPath -Leaf)
}

# [public] Copy-ToZip — Zippt einen kompletten Ordner in eine Archivdatei (ueberschreibt ein
# vorhandenes Archiv). Rueckgabewert: $true bei Erfolg, sonst $false.
#   Folder   Zu zippender Ordner (Alias: Path)
#   Archive  Zu erstellende Archivdatei (Standard: Ordnername + .zip)
function Copy-ToZip {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Path of a folder to create a zip")]
        [Alias('Path')]
        [ValidateScript({ Test-Path $_ })]
        [string]$Folder,

        [Parameter(Mandatory = $false, Position = 1, HelpMessage = "Path of zip file to create")]
        [string]$Archive
    )

    begin {
        Write-Verbose "Check Paths"
        $Folder = Resolve-MdsPath -Path $Folder
        if ([string]::IsNullOrWhiteSpace($Archive)) {
            $Archive = $Folder
        }
        if (!$Archive.EndsWith(".zip")) { $Archive += ".zip" }
        $Archive = Resolve-MdsPath -Path $Archive -AllowMissing
    }
    process {
        if (Test-Path -LiteralPath $Archive) {
            Write-Verbose "Remove existing Target Archive"
            Remove-Item -LiteralPath $Archive -Force
        }
        Write-Verbose "Create new Archive from directory"
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Folder, $Archive, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    }
    end {
        if (Test-Path -LiteralPath $Archive -PathType Leaf) {
            Write-Verbose "Successfully created $($Archive) from folder $($Folder)"
            return $true
        }
        else {
            Write-Warning "Archive $($Archive) from folder $($Folder) not created"
            return $false
        }
    }
}

# [public] Copy-FileToZip — Fuegt eine oder mehrere Dateien einem (vorhandenen oder neuen)
# ZIP hinzu. Bereits vorhandene Eintraege werden ersetzt.
#   Files         Hinzuzufuegende Dateien (pipeline-faehig)
#   Archive       Ziel-ZIP (wird angelegt oder erweitert)
#   Root          Wurzelpfad, der die Ordnerstruktur im ZIP bestimmt
#   ShowProgress  Fortschrittsbalken anzeigen (Alias: Progress, Bar)
function Copy-FileToZip {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = "Path of a folder to create a zip/add to existing zip")]
        [string[]]$Files,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Path of zip file to create or add the folder to")]
        [ValidateNotNullOrEmpty()]
        [string]$Archive,

        [Parameter(Mandatory = $false, Position = 2, HelpMessage = "Root path defining the folder structure of the zip file")]
        [ValidateNotNullOrEmpty()]
        [string]$Root,

        [Parameter(HelpMessage = "Show ProgressBar")]
        [ValidateNotNullOrEmpty()]
        [Alias('Progress')]
        [Alias('Bar')]
        [switch]$ShowProgress = $false
    )

    begin {
        $allFiles = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($file in @($Files)) {
            if (-not [string]::IsNullOrWhiteSpace($file)) {
                [void]$allFiles.Add($file)
            }
        }
    }

    end {
        if (!$Archive.EndsWith(".zip")) {
            throw "Angegebene Archivdatei hat nicht das richtige Format (.zip)"
        }

        $Archive = Resolve-MdsPath -Path $Archive -AllowMissing
        if (-not [string]::IsNullOrWhiteSpace($Root)) {
            $Root = Resolve-MdsPath -Path $Root
        }

        $archiveParent = Split-Path -Path $Archive -Parent
        if (!(Test-Path -LiteralPath $archiveParent)) {
            New-Item -Path $archiveParent -ItemType directory -Force | Out-Null
        }

        [System.IO.Compression.ZipArchive] $zip = $null
        $fileIndex = 0
        $fileCount = $allFiles.Count

        try {
            $zip = [System.IO.Compression.ZipFile]::Open($Archive, [System.IO.Compression.ZipArchiveMode]::Update)

            foreach ($file in $allFiles) {
                if (Test-Path -LiteralPath $file -PathType Leaf) {
                    if ($ShowProgress -and $fileCount -gt 0) {
                        $percentComplete = 25 + (($fileIndex / $fileCount) * 75)
                        Write-Progress -Activity "Copy to Zip" -PercentComplete $percentComplete -Status "Copy file $($fileIndex + 1) of $($fileCount) to zipfile $($Archive)" -Id 1
                    }

                    try {
                        $filePath = Resolve-MdsPath -Path $file
                        $entryName = Get-ZipEntryName -FilePath $filePath -RootPath $Root
                        $existing = $zip.GetEntry($entryName)
                        if ($null -ne $existing) {
                            $existing.Delete()
                        }

                        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $filePath, $entryName) | Out-Null
                        $fileIndex++
                    }
                    catch {
                        Write-Warning "File $($file) could not be added to zip: $($_.Exception.Message)"
                    }
                }
                elseif (Test-Path -LiteralPath $file -PathType Container) {
                    Write-Warning "Only files can be added to the zip file. $($file) is a directory"
                }
                else {
                    Write-Warning "File $($file) not found"
                }
            }
        }
        finally {
            if ($ShowProgress) {
                Write-Progress -Activity "Copy to Zip" -PercentComplete 100 -Status "Ready" -Id 1
                Write-Progress -Id 1 -Completed
            }
            if ($null -ne $zip) {
                $zip.Dispose()
            }
        }

        Write-Output "Updated $($Archive) with $($fileIndex) files"
    }
}

# [public] Export-FromZip — Entpackt ein ZIP-Archiv in ein Zielverzeichnis (bereits vorhandene
# Zieldateien werden zuvor entfernt). Rueckgabewert: $true, wenn Eintraege entpackt wurden.
#   Archive      Zu entpackendes ZIP
#   Destination  Zielverzeichnis (wird bei Bedarf angelegt)
function Export-FromZip {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false, HelpMessage = "Path of a zipfile to extract")]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Archive ,

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Directory to extract the files to")]
        [ValidateNotNullOrEmpty()]
        [string]$Destination
    )

    begin {
        $anz = 0
        $Archive = Resolve-MdsPath -Path $Archive
        $Destination = Resolve-MdsPath -Path $Destination -AllowMissing
        if (!(Test-Path -LiteralPath $Destination)) {
            $null = New-Item -Path $Destination -ItemType directory -Force
            Write-Verbose "Create Destination"
        }
        $zip = $null
    }
    process {
        if (Test-Path -LiteralPath $Archive) {
            Write-Host -ForegroundColor blue "### [EntZip]: $Archive ==> $Destination"
            Write-Verbose "Open zip archive"
            [System.IO.Compression.ZipArchive] $zip = [System.IO.Compression.ZipFile]::Open($Archive, [System.IO.Compression.ZipArchiveMode]::Read)
            Write-Verbose "Clear target directory ..."
            $all = $zip.Entries
            foreach ($akt in $all) {
                $anz++
                $ziel = Join-Path -Path $Destination -ChildPath $akt.FullName
                if (Test-Path -LiteralPath $ziel) {
                    Remove-Item -LiteralPath $ziel -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Verbose "Extract files to target directory ..."
            [System.IO.Compression.ZipFileExtensions]::ExtractToDirectory($zip, $Destination)
        }
    }
    end {
        if ($null -ne $zip) {
            $zip.Dispose()
            $zip = $null
        }
        Write-Verbose "Successfully extracted $anz Files from $($Archive) to $($Destination)"
        if ($anz -gt 0) {
            Write-Host -ForegroundColor green "### $($Archive) entpackt"
        }
        Write-Output ($anz -gt 0)
    }
}

# [public] Get-ZipEntry — Liefert die Eintraege (ZipArchiveEntry) eines ZIP-Archivs.
#   Archive  Zu lesendes ZIP
function Get-ZipEntry {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false, HelpMessage = "Path of a zipfile to extract")]
        [ValidateScript({ Test-Path $_ })]
        [string]$Archive
    )
    begin {
        $Archive = Resolve-MdsPath -Path $Archive
        $zip = $null
        if (Test-Path -LiteralPath $Archive) {
            Write-Verbose "Open zip archive"
            [System.IO.Compression.ZipArchive] $zip = [System.IO.Compression.ZipFile]::Open($Archive, [System.IO.Compression.ZipArchiveMode]::Read)
            $w = $zip.Entries
            Write-Output $w
        }
    }
    end {
        if ($null -ne $zip) {
            $zip.Dispose()
        }
    }
}
