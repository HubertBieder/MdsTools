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

function Use-Conda() {
    if ($IsWindows) {
        #region conda initialize
        # !! Contents within this block are managed by 'conda init' !!
        If (Test-Path "C:\ProgramData\Anaconda\Scripts\conda.exe") {
            (& "C:\ProgramData\Anaconda\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | Where-Object { $_ } | Invoke-Expression
            Write-Host "Conda Umgebung initialisiert" -ForegroundColor Green
        }
        else {
            Write-Warning "Conda nicht installiert"
        }
        #endregion
    }
    elseif ($IsMacOS) {
        # Auf macOS ist Conda aktuell nicht installiert; greift automatisch, sobald es unter /opt/anaconda3 liegt
        If (Test-Path "/opt/anaconda3/bin/conda") {
            (& "/opt/anaconda3/bin/conda" "shell.powershell" "hook") | Out-String | Where-Object { $_ } | Invoke-Expression
            Write-Host "Conda Umgebung initialisiert" -ForegroundColor Green
        }
        else {
            Write-Warning "Conda ist auf macOS (noch) nicht installiert"
        }
    }
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

    function data_cli { & "C:\Users\huber\.conda\envs\hubi_311\python.exe" (Join-Path $mdsRepos 'PHB/src/DataCLI/Data_cli.py') }
    Set-Alias -Name DataCLI -Value data_cli -Force -option private
    function py_311 { & "C:\Users\huber\.conda\envs\hubi_311\python.exe" @args }
    Set-Alias -Name py -Value py_311

    function pyBase { & "C:\ProgramData\Anaconda\python.exe" @args }
    Set-Alias -Name pyb -Value pyBase
}
