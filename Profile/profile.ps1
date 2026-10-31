#========================================================================================
# Scriptname    ProfilSkript PowerShell V5-V7
# Developer:    Hubert Bieder
# Last Changes: 27.03.2024 Optimierung und Trennung Profil und Development 
#               18.12.2024 Update auf V25
#               28.12.2025 Restrukturierung
#               14.01.2026 Anaconda Pfad korrigiert
#               30.10.2026 macOS: cdBin -> woyRoot/Bin, cdAuf/2Auf nur Windows, Conda-Hinweis
#========================================================================================

# Native Programme (dotnet, git, ...) geben UTF-8 aus; ohne diese Einstellung
# dekodiert PowerShell deren Pipeline-Ausgabe mit der OEM-Codepage 850
# (Umlaute erscheinen dann als "├╝" usw.).
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Function cdDev { Set-Location -Path "$woyDev" }
# Windows: Bin liegt unter woyDev, macOS/Linux: unter woyRoot
Function cdBin { if ($IsWindows) { Set-Location -Path "$woyDev/Bin" } else { Set-Location -Path "$woyRoot/Bin" } }
# Auftragsabwicklung (woyV..) gibt es nur unter Windows
Function cdAuf {
    if ($IsWindows) { Set-Location -Path "$woyDev/woyV$woyVersion" }
    else { Write-Warning "cdAuf: Auftragsabwicklung gibt es nur unter Windows" }
}
Function cdWoy { Set-Location -Path "$woyRoot" }
Function cdNet { Set-Location -Path "$woyDev/NetCoreLib2026" }
function cdMaui { Set-Location "$woyDev/NetMauiApps" }
Function cdMds { Set-Location -Path "$woyDev/mdsPackage" }    
Function cdHB { Set-Location -Path "$woyDev/PythonHB" }    
function cdCLI { Set-Location "$woyDev/PythonHB/src/DataCLI" }

function save-Develop() {
    cdHB
    backup-develop -force
    cdNet
    backup-develop -force
    if ($IsWindows) {
        cdAuf
        backup-develop -force
    }
    cdMds
    backup-develop -force
}

function Install-Develop() {
    $a = Get-Module -Name mdsPackage
    if ($null -eq $a) {       
        Import-Module -Name mdsPackage -Force
    }
    New-Alias -Name "2Dev" -Value cdDev -Force -Description "Ziel: EntwicklungsRoot" -option private -Scope Global
    New-Alias -Name "2Bin" -Value cdBin -Force -Description "Ziel: Binärverzeichnis" -option private -Scope Global
    if ($IsWindows) {
        New-Alias -Name "2Auf" -Value cdAuf -Force -Description "Ziel: Auftragsabwicklung" -option private -Scope Global
    }
    New-Alias -Name "2Woy" -Value cdWoy -Force -Description "Ziel: Datenverzeichnis"  -option none -Scope Global
    New-Alias -Name "2Net" -Value cdNet -Force -Description "Ziel: NetLIB" -option private -Scope Global
    New-Alias -Name "2Maui" -Value cdMaui -Force -Description "Ziel: NetMauiApp" -option private -Scope Global
    New-Alias -Name "2Mds" -Value cdMds -Force -Description "Ziel: MDS" -option private -Scope Global
    New-Alias -Name "2HB" -Value cdHB -Force -Description "Ziel: PythonHB" -option private -Scope Global
    New-Alias -Name "2PD"  -Value cdPD  -Force -Scope Global
    New-Alias -Name '2CLI' -Value cdCLI -Force -Scope Global
    New-Alias -Name 'zip' -Value save-Develop -Force -Scope Global

}
function Use-Conda() {
    if ($IsWindows) {
        #region conda initialize
        # !! Contents within this block are managed by 'conda init' !!
        If (Test-Path "C:\ProgramData\Anaconda\Scripts\conda.exe") {
            (& "C:\ProgramData\Anaconda\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ? { $_ } | Invoke-Expression
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
            (& "/opt/anaconda3/bin/conda" "shell.powershell" "hook") | Out-String | ? { $_ } | Invoke-Expression
            Write-Host "Conda Umgebung initialisiert" -ForegroundColor Green
        }
        else {
            Write-Warning "Conda ist auf macOS (noch) nicht installiert"
        }
    }
}

function Show-Header([string] $os = "Windows", [string] $version = "" ) {
    $lMax = 80
    $message = "+--- [$pwsVersion] --- <$Env:UserName> [$os] -"
    if ($version.Length -gt 0) {
        $version = "- [V$version.1] -"
    }
    else {
        $version = "".PadRight(11, '-')
    }
    $message = "$message".PadRight($lMax, '-') + "$version--+"     
    return $message;
}
Clear-Host
if ($null -eq $woyVersion) {
    Set-Global  
}

if ($IsMacOS) {
    Write-Host (Show-Header -os "MacOS") -ForegroundColor blue
    Install-Develop
    #aliase für MacOS
}
elseif ($IsWindows) {
    Write-Host (Show-Header -os "Windows" -version $woyVersion) -ForegroundColor blue
    ###Write-Host (Show-Header -os "Windows" ) -ForegroundColor blue
    Install-Develop

    function androidbuild { dotnet build src/Apps/DataBrowser/DataBrowser.csproj --framework net10.0-android --configuration Debug -t:Run -p:AdbTarget=-d }
    New-Alias -Name "nubia" -Value androidbuild
    
    function data_cli { &  "C:\Users\huber\.conda\envs\hubi_311\python.exe"  "C:\woyCode\PythonHB\src\DataCLI\Data_cli.py" }
    Set-Alias -Name DataCLI  -Value data_cli -Force -option private
    function py_311 { &  "C:\Users\huber\.conda\envs\hubi_311\python.exe" @args }
    Set-Alias -Name py  -Value py_311
    
    function pyBase { & "C:\ProgramData\Anaconda\python.exe" @args }   
    Set-Alias -Name pyb -Value pyBase   
           
    #Invoke-RestMethod -Uri https://tinyurl.com/codeAusBuch | new-item -path function: -Name L -Force | OUT-Null   
}
elseif ($IsLinux) {
    Write-Host (Show-Header -os "MacOS") -ForegroundColor blue
    Install-Develop
}

