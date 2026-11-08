#========================================================================================
# Scriptname    profile.ps1 (CurrentUserAllHosts) – wird von Install.ps1 kopiert
# Developer:    Hubert Bieder
# Last Changes: 27.03.2024 Optimierung und Trennung Profil und Development
#               18.12.2024 Update auf V25
#               28.12.2025 Restrukturierung
#               14.01.2026 Anaconda Pfad korrigiert
#               30.10.2026 macOS: cdBin -> woyRoot/Bin, cdAuf/2Auf nur Windows, Conda-Hinweis
#               31.10.2026 Hubi/Claude: Umstellung auf MdsTools; cd*/2*-Aliase durch go ersetzt,
#                          woy-Variablen durch $mds*, zip-Alias entfernt (verdeckte /usr/bin/zip)
#               05.11.2026 Hubi/Claude: prompt zeigt den User-Ordner als ~ (PS ~/Repos>)
#               08.11.2026 Hubi/Claude: Anaconda auf macOS (Homebrew), $condaRoot/Get-CondaPython, py/py313/py315
#               08.11.2026 Hubi/Claude: MARS auf Anaconda 2026.07, py/py313/py315/pyb fuer Windows und macOS gleich
#========================================================================================

# MdsTools setzt beim Laden UTF-8-Ausgabe, die globalen $mds*-Variablen und den PATH auf $mdsBin.
Import-Module -Name MdsTools -ErrorAction Stop

# Sichert alle Git-Repos unter $mdsRepos als datierte ZIP (Backup-Develop je Repo).
function Save-Develop() {
    foreach ($repo in Get-ChildItem -LiteralPath $mdsRepos -Directory) {
        if (Test-Path -LiteralPath (Join-Path $repo.FullName '.git') -PathType Container) {
            Backup-Develop -sourceDir $repo.FullName -force | Out-Null
        }
    }
}

# Anaconda-Basisordner: Windows systemweit, macOS per Homebrew (brew install --cask anaconda)
$condaRoot = if ($IsWindows) { "C:\ProgramData\Anaconda" } elseif ($IsMacOS) { "/opt/homebrew/anaconda3" } else { $null }

# Python einer Conda-Umgebung ('base' = Anaconda-Basis); envs liegen unter $condaRoot/envs oder ~/.conda/envs
function Get-CondaPython([string] $envName = 'base') {
    $exe = if ($IsWindows) { 'python.exe' } else { 'bin/python' }
    $dirs = if ($envName -eq 'base') { @($condaRoot) } else {
        @((Join-Path $condaRoot "envs/$envName"), (Join-Path $HOME ".conda/envs/$envName"))
    }
    foreach ($d in $dirs) {
        $p = Join-Path $d $exe
        if (Test-Path -LiteralPath $p) { return $p }
    }
    throw "Conda-Umgebung '$envName' nicht gefunden"
}

# Aktiviert conda in der aktuellen Sitzung (danach: conda activate py314)
function Use-Conda() {
    $conda = if ($IsWindows) { Join-Path $condaRoot 'Scripts\conda.exe' } else { Join-Path $condaRoot 'bin/conda' }
    if (Test-Path -LiteralPath $conda) {
        (& $conda "shell.powershell" "hook") | Out-String | Where-Object { $_ } | Invoke-Expression
        Write-Host "Conda Umgebung initialisiert" -ForegroundColor Green
    }
    else {
        Write-Warning "Conda nicht installiert ($conda)"
    }
}

# 2026-11-05 Hubi/Claude: Prompt wie der Standard, aber $HOME als ~ (PS ~/Repos/Mds>)
function prompt {
    $p = $PWD.Path
    if ($PWD.Provider.Name -eq 'FileSystem' -and
        ($p -eq $HOME -or $p.StartsWith($HOME + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
        $p = '~' + $p.Substring($HOME.Length)
    }
    "PS $p$('>' * ($NestedPromptLevel + 1)) "
}

function Show-Header([string] $os) {
    $lMax = 80
    $ps = $PSVersionTable.PSVersion
    $message = "+--- [PWS $($ps.Major).$($ps.Minor).$($ps.Patch)] --- <$([Environment]::UserName)> [$os] -"
    $version = "- [MdsTools $mdsVersion] -"
    return "$message".PadRight($lMax, '-') + "$version--+"
}

Clear-Host
$os = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "MacOS" } else { "Linux" }
Write-Host (Show-Header -os $os) -ForegroundColor blue
Remove-Variable os

if ($IsWindows) {
    function androidbuild { dotnet build src/Apps/DataBrowser/DataBrowser.csproj --framework net10.0-android --configuration Debug -t:Run -p:AdbTarget=-d }
    New-Alias -Name "nubia" -Value androidbuild -Force

    # DataCLI (PHB) laeuft weiter in der alten Umgebung Hubi_311 (Python 3.11)
    function data_cli { & (Get-CondaPython Hubi_311) (Join-Path $mdsRepos 'PHB/src/DataCLI/Data_cli.py') @args }
    Set-Alias -Name DataCLI -Value data_cli -Force -option private
    function py311 { & (Get-CondaPython Hubi_311) @args }
}

# Python aus Anaconda, auf Windows (MARS) und macOS (LUNA) identisch:
# py314 (Alltag), py313 (Kompatibilitaet/ML), py315 (nur testen); base bleibt unveraendert
if ($IsWindows -or $IsMacOS) {
    function py_314 { & (Get-CondaPython py314) @args }
    Set-Alias -Name py -Value py_314
    function py313 { & (Get-CondaPython py313) @args }
    function py315 { & (Get-CondaPython py315) @args }

    function pyBase { & (Get-CondaPython base) @args }
    Set-Alias -Name pyb -Value pyBase
}
