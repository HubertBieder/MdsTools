#Requires -Version 7.0
# Installiert Profile und das Modul mdsPackage fuer den aktuellen Benutzer.
# Laeuft unter PowerShell 7 auf Windows (z.B. Mars) und macOS (z.B. Luna).
# Das Modul selbst verlangt PowerShell 7 (mdsPackage.psd1: PowerShellVersion = 7.0.0).

# Repo-Wurzel = Ordner dieses Skripts (unabhaengig vom aktuellen Verzeichnis).
$script:RepoRoot = $PSScriptRoot

function Get-UserHome()
{
    # In Domaenen mit Roaming-/Home-Verzeichnis kann $HOME (= HOMEDRIVE+HOMEPATH)
    # vom tatsaechlichen Profil abweichen. Massgeblich ist %USERPROFILE%.
    # Beispiel: als SCHWARTZ\Administrator angemeldet ->
    #   $HOME            = C:\Users\Administrator          (falsch, lokales Profil)
    #   $env:USERPROFILE = C:\Users\Administrator.SCHWARTZ (richtig)
    # Unter macOS ist USERPROFILE nicht gesetzt -> $HOME.
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE) -and (Test-Path -LiteralPath $env:USERPROFILE))
    {
        return $env:USERPROFILE
    }
    return $HOME
}

function Get-ProfileRoot()
{
    # Windows: ...\Documents\PowerShell   macOS: ~/.config/powershell
    $base = Split-Path  $profile.CurrentUserAllHosts
    # Zeigt der Profilpfad noch auf ein abweichendes $HOME (siehe Get-UserHome),
    # auf %USERPROFILE% umbiegen, damit Module im echten Profil landen.
    $userHome = Get-UserHome
    if ($HOME -and ($userHome -ne $HOME) -and $base.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase))
    {
        $rel = $base.Substring($HOME.Length).TrimStart('\', '/')
        $base = Join-Path $userHome $rel
    }
    if (-not (Test-Path -Path $base -PathType Container))
    {
        New-Item -Path $base -ItemType Directory -Force | Out-Null
    }
    return $base
}


function Get-CurrentUserModuleDir()
{
    # Deterministisch ableiten statt aus PSModulePath[0]:
    #   Windows: ProfileRoot\Modules  (...\Documents\PowerShell\Modules)
    #   macOS:   ~/.local/share/powershell/Modules - dort sucht PowerShell CurrentUser-Module,
    #            NICHT unter ~/.config/powershell/Modules (Profilordner).
    if ($IsWindows)
    {
        $module = Join-Path (Get-ProfileRoot) 'Modules'
    }
    else
    {
        # Wie PowerShell selbst: $XDG_DATA_HOME, sonst ~/.local/share
        # ([Environment]::GetFolderPath('LocalApplicationData') liefert auf macOS ~/Library/Application Support - falsch).
        $dataHome = if ([string]::IsNullOrWhiteSpace($env:XDG_DATA_HOME)) { Join-Path $HOME '.local/share' } else { $env:XDG_DATA_HOME }
        $module = Join-Path $dataHome 'powershell/Modules'
    }
    if (-not (Test-Path -Path $module -PathType Container))
    {
        New-Item -Path $module -ItemType Directory -Force | Out-Null
    }
    return $module
}

function Copy-Profiles()
{
    $base = Get-ProfileRoot
    $target = Join-Path $base 'profile.ps1'
    $source = Join-Path $script:RepoRoot 'Profile/profile.ps1'
    Write-Host "---   von [$source] ==> [$target]   -----------------------------"
    Copy-Item -Path $source -Destination $target -Force
    if (Test-Path -Path $target -PathType Leaf)
    {
        Write-Host  -ForegroundColor blue "===>   Profile.ps1   <==="
    }
    $target = Join-Path $base 'mdsProfile.ps1'
    $source = Join-Path $script:RepoRoot 'Modules/mdsProfile.ps1'
    Write-Host "---   von [$source] ==> [$target]   -----------------------------"
    Copy-Item -Path $source -Destination $target -Force
    if (Test-Path -Path $target -PathType Leaf)
    {
        Write-Host -ForegroundColor blue "===>   mdsProfile.ps1   <==="
    }
}
function Install-WoyEnv()
{
    # Richtet den massgeblichen Runtime-Ort der Anmeldedaten ein: %USERPROFILE%\.woy (macOS: ~/.woy).
    # Das Modul (Get-WoyEnvPath) liest beim Start UND fuer Credentials von dort.
    #   - woy.env: wird aus der Repo-.env angelegt bzw. aktualisiert, sobald die
    #     Repo-.env neuer ist als die vorhandene woy.env (sonst bleibt sie unberuehrt).
    #   - woy.env.example: Vorlage/Muster, wird immer aktualisiert.
    # Passwoerter und Einstellungen werden danach direkt in ~\.woy gepflegt.
    $woyDir = Join-Path (Get-UserHome) '.woy'
    if (-not (Test-Path -Path $woyDir -PathType Container))
    {
        New-Item -Path $woyDir -ItemType Directory -Force | Out-Null
    }

    $repoRoot = $script:RepoRoot

    # Vorlage immer aktualisieren, damit ein aktuelles Muster vorliegt.
    $exampleSrc = Join-Path -Path $repoRoot -ChildPath '.env.example'
    if (Test-Path -Path $exampleSrc -PathType Leaf)
    {
        $exampleDst = Join-Path -Path $woyDir -ChildPath 'woy.env.example'
        Copy-Item -Path $exampleSrc -Destination $exampleDst -Force
        Write-Host -ForegroundColor blue "===>   Muster kopiert: $exampleDst   <==="
    }

    # woy.env aus der Repo-.env anlegen bzw. aktualisieren, wenn die Repo-.env neuer ist.
    $envDst = Join-Path -Path $woyDir -ChildPath 'woy.env'
    $envSrc = Join-Path -Path $repoRoot -ChildPath '.env'
    if (Test-Path -Path $envSrc -PathType Leaf)
    {
        $doCopy = $true
        if (Test-Path -Path $envDst -PathType Leaf)
        {
            $srcTime = (Get-Item -LiteralPath $envSrc).LastWriteTimeUtc
            $dstTime = (Get-Item -LiteralPath $envDst).LastWriteTimeUtc
            $doCopy = $srcTime -gt $dstTime
        }
        if ($doCopy)
        {
            Copy-Item -Path $envSrc -Destination $envDst -Force
            Write-Host -ForegroundColor blue "===>   woy.env aktualisiert (Repo-.env neuer): $envDst   <==="
        }
        else
        {
            Write-Host -ForegroundColor DarkYellow "woy.env ist aktuell, bleibt unveraendert: $envDst"
        }
    }
    elseif (Test-Path -Path $envDst -PathType Leaf)
    {
        Write-Host -ForegroundColor DarkYellow "Keine Repo-.env - vorhandene woy.env bleibt unveraendert: $envDst"
    }
    else
    {
        # Weder Repo-.env noch woy.env vorhanden -> aus der Vorlage eine Start-woy.env erzeugen.
        if (Test-Path -Path $exampleSrc -PathType Leaf)
        {
            if ($IsWindows)
            {
                Copy-Item -Path $exampleSrc -Destination $envDst -Force
            }
            else
            {
                # Die Vorlage enthaelt Windows-Pfade (C:\woyCode ...). Unter macOS auskommentieren,
                # damit die betriebssystemspezifischen Standardwerte aus InitModule.ps1 greifen.
                $lines = Get-Content -LiteralPath $exampleSrc |
                    ForEach-Object { if ($_ -match '^\s*WOY_(DEV|ROOT|DATA)\s*=') { "# $_   (macOS: Standardwert)" } else { $_ } }
                Set-Content -LiteralPath $envDst -Value $lines -Encoding utf8NoBOM
            }
            Write-Host -ForegroundColor DarkYellow "woy.env aus Vorlage erzeugt (Passwoerter eintragen!): $envDst"
        }
        else
        {
            Write-Host -ForegroundColor Yellow "Weder .env noch .env.example gefunden - woy.env nicht angelegt."
        }
    }
}

function Install-mdsModule([string] $module)
{
    $base = Get-CurrentUserModuleDir
    $targetDir = Join-Path $base $module
    $sourceDir = Join-Path (Join-Path $script:RepoRoot 'Modules') $module
    Write-Host "---   von [$sourceDir] ==> [$targetDir]   -----------------------------"
    if (-not (Test-Path -Path $sourceDir -PathType Container))
    {
        Write-Host -ForegroundColor Red "Quellverzeichnis fehlt: $sourceDir"
        return $false
    }
    if (Test-Path -Path $targetDir -PathType Container)
    {
        Remove-Item -Path $targetDir -Recurse -Force
    }
    Copy-Item -Path $sourceDir -Destination $targetDir -Force -Recurse
    if (Test-Path -Path $targetDir -PathType Container)
    {
        Import-Module $targetDir -global -Verbose
        Write-Host -ForegroundColor blue "===>   Modul installiert: $module   <==="
        return $true
    }
    return $false
}

Clear-Host
Write-Host "================= Profile und Module installieren ================  V5.1  ====="
Copy-Profiles

$a = $false
$b = Install-mdsModule "mdsPackage"
if ($b)
{
    # ~\.woy\woy.env einrichten (nur anlegen, wenn nicht vorhanden) und Muster kopieren,
    # dann Modul neu laden, damit Set-Global die woy.env sofort auswertet.
    Install-WoyEnv
    Import-Module (Join-Path (Get-CurrentUserModuleDir) 'mdsPackage') -Global -Force
}
if ($IsWindows)
{
    # AufDB nur unter Windows
    #$a = Install-mdsModule "AufDB"
}
if ($a -or $b)
{
    Get-Module -ListAvailable
}

Write-Host ""
Write-Host "================= Profile und Module installiert =================  V5.1  ====="
Write-Host ""
$root = Get-ProfileRoot
Write-Host "Profile Root: $root"
Write-Host "Modul-Verz.:  $(Get-CurrentUserModuleDir)"
Write-Host $profile.CurrentUserCurrentHost
Write-Host $profile.AllUsersAllHosts
Write-Host $profile.AllUsersCurrentHost
