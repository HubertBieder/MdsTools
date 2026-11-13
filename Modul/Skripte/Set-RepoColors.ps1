#Requires -Version 7.0
<#
.SYNOPSIS
    Setzt VS-Code-Farben pro Repository abhängig vom Repo-Typ (C#, Python, PowerShell).

.DESCRIPTION
    Durchsucht alle Git-Repos direkt unterhalb von -Root, erkennt den Typ anhand der Dateien
    und schreibt/merged .vscode/settings.json (workbench.colorCustomizations, peacock.color, window.title).
    Andere Einstellungen bleiben erhalten. Die settings.json wird mit committet,
    dadurch sind die Farben auf LUNA (macOS) und MARS (Windows) automatisch gleich.

    Erkennung (erste Regel gewinnt):
      C#         : *.sln, *.slnx, *.csproj
      Python     : pyproject.toml, requirements.txt, setup.py, *.py
      PowerShell : *.psd1, *.psm1, *.ps1

.PARAMETER Root
    Ordner mit den Repos. Standard wie CloneAll.ps1: macOS ~/Repos, Windows C:\woyCode;
    $env:DEV_REPOS übersteuert.

.PARAMETER ExcludeFromGit
    Trägt .vscode/settings.json in .git/info/exclude ein (nur lokal, nicht committet).

.EXAMPLE
    ./Set-RepoColors.ps1 -WhatIf
    ./Set-RepoColors.ps1
    ./Set-RepoColors.ps1 -Root ~/Repos

.NOTES
    Version  Datum       Wer           Was
    1.0.0    2026-11-10  Claude/Hubi   Erstversion
    1.1.0    2026-11-10  Claude/Hubi   Standard-Root wie CloneAll (~/Repos bzw. C:\woyCode);
                                       kompletter Peacock-Farbsatz + peacock.color, damit keine
                                       alten Peacock-Farben stehen bleiben
    1.2.0    2026-11-10  Claude/Hubi   C# jetzt Gold (bisher Lila), Python jetzt Grün (bisher Gold)
    1.3.0    2026-11-10  Claude/Hubi   C# und PowerShell getauscht: C# Blau, PowerShell Gold
    1.4.0    2026-11-13  Claude/Hubi   Python und PowerShell getauscht: Python Gold, PowerShell Grün;
                                       C# Titel- und Statusleiste heller (#0A3170)
    1.5.0    2026-11-13  Claude/Hubi   Deckkraft inaktiver Schrift pro Typ (Dim), C# heller (DD);
                                       peacock.color wird entfernt, damit Peacock nicht überschreibt
    1.6.0    2026-11-13  Claude/Hubi   C# wieder Blau #012456 (Activity Bar #023988), Schrift Weiß
    1.7.0    2026-11-13  Claude/Hubi   C#: Titel-, Statuszeile und Activity Bar einheitlich #023988
    1.8.0    2026-11-13  Claude/Hubi   PowerShell: alle drei Bereiche einheitlich #43A047, inaktive Schrift heller (DD)
    1.9.0    2026-11-13  Claude/Hubi   Python: alle drei Bereiche einheitlich #D9A21B
    1.10.0   2026-11-13  Claude/Hubi   Titelzeile unfokussierter Fenster in voller Farbe (ohne Transparenz)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Root,
    [switch]$ExcludeFromGit
)

if (-not $Root) {
    $Root = if ($env:DEV_REPOS) { $env:DEV_REPOS }
            elseif ($IsWindows) { 'C:\woyCode' }
            else { Join-Path $HOME 'Repos' }
}

# --- Farbschemata pro Typ (hier anpassen) ---------------------------------
#     Bg = Grundfarbe, Hi = hellere Variante (Activity Bar, Hover), Fg = Schrift, Badge/BadgeFg = Akzent,
#     Dim = Deckkraft (Hex-Alpha) inaktiver Schrift: nicht aktive Icons links, Titel unfokussierter Fenster
$Schemes = @{
    'CSharp'     = @{ Bg = '#023988'; Hi = '#023988'; Fg = '#FFFFFF'; Badge = '#4FC3F7'; BadgeFg = '#15202B'; Dim = 'DD'; Label = 'C#' }  # Blau
    'Python'     = @{ Bg = '#D9A21B'; Hi = '#D9A21B'; Fg = '#15202B'; Badge = '#5C2D91'; BadgeFg = '#FFFFFF'; Dim = '99'; Label = 'Py' }  # Gold
    'PowerShell' = @{ Bg = '#43A047'; Hi = '#43A047'; Fg = '#FFFFFF'; Badge = '#FFD43B'; BadgeFg = '#15202B'; Dim = 'DD'; Label = 'PS' }  # Grün
}

function Get-RepoType {
    param([string]$Path)
    $files = Get-ChildItem -Path $Path -Recurse -File -Depth 4 -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch '[\\/](\.git|bin|obj|node_modules|\.venv|venv|archiv|archive)[\\/]' }
    $names = $files.Name
    $ext   = $files.Extension

    if ($ext -match '^\.(sln|slnx|csproj)$')                                  { return 'CSharp' }
    if ($names -match '^(pyproject\.toml|requirements\.txt|setup\.py)$' -or
        $ext -contains '.py')                                                  { return 'Python' }
    if ($ext -match '^\.(psd1|psm1|ps1)$')                                     { return 'PowerShell' }
    return $null
}

function Get-ColorBlock {
    param($S)
    # Gleicher Schlüsselsatz wie Peacock, damit alte Peacock-Werte vollständig ersetzt werden
    [ordered]@{
        'activityBar.activeBackground'        = $S.Hi
        'activityBar.activeBorder'            = $S.Fg
        'activityBar.background'              = $S.Hi
        'activityBar.foreground'              = $S.Fg
        'activityBar.inactiveForeground'      = $S.Fg + $S.Dim
        'activityBarBadge.background'         = $S.Badge
        'activityBarBadge.foreground'         = $S.BadgeFg
        'activityBarTop.activeBackground'     = $S.Hi
        'activityBarTop.activeBorder'         = $S.Fg
        'activityBarTop.background'           = $S.Hi
        'activityBarTop.foreground'           = $S.Fg
        'activityBarTop.inactiveForeground'   = $S.Fg + $S.Dim
        'commandCenter.border'                = $S.Fg + $S.Dim
        'commandCenter.foreground'            = $S.Fg
        'sash.hoverBorder'                    = $S.Hi
        'statusBar.background'                = $S.Bg
        'statusBar.foreground'                = $S.Fg
        'statusBar.inactiveBackground'        = $S.Bg
        'statusBar.debuggingBackground'       = $S.Bg
        'statusBar.debuggingForeground'       = $S.Fg
        'statusBarItem.hoverBackground'       = $S.Hi
        'statusBarItem.remoteBackground'      = $S.Bg
        'statusBarItem.remoteForeground'      = $S.Fg
        'titleBar.activeBackground'           = $S.Bg
        'titleBar.activeForeground'           = $S.Fg
        'titleBar.inactiveBackground'         = $S.Bg
        'titleBar.inactiveForeground'         = $S.Fg + $S.Dim
    }
}

if (-not (Test-Path $Root)) { throw "Root nicht gefunden: $Root" }

$repos = Get-ChildItem -Path $Root -Directory |
         Where-Object { Test-Path (Join-Path $_.FullName '.git') }

foreach ($repo in $repos) {
    $type = Get-RepoType -Path $repo.FullName
    if (-not $type) {
        Write-Warning "$($repo.Name): Typ nicht erkannt - übersprungen."
        continue
    }
    $scheme   = $Schemes[$type]
    $vsDir    = Join-Path $repo.FullName '.vscode'
    $settings = Join-Path $vsDir 'settings.json'

    # Vorhandene settings.json einlesen (pwsh 7 toleriert // Kommentare)
    $json = [ordered]@{}
    if (Test-Path $settings) {
        try {
            $raw  = Get-Content $settings -Raw
            $json = if ($raw.Trim()) { $raw | ConvertFrom-Json -AsHashtable } else { [ordered]@{} }
        } catch {
            Write-Warning "$($repo.Name): settings.json nicht lesbar ($($_.Exception.Message)) - übersprungen."
            continue
        }
    }

    # Farben mergen (fremde colorCustomizations-Schlüssel bleiben erhalten)
    $colors = if ($json.Contains('workbench.colorCustomizations')) { $json['workbench.colorCustomizations'] } else { [ordered]@{} }
    (Get-ColorBlock $scheme).GetEnumerator() | ForEach-Object { $colors[$_.Key] = $_.Value }
    $json['workbench.colorCustomizations'] = $colors
    $json.Remove('peacock.color')            # sonst überschreibt Peacock die Farben mit eigenen Werten
    $json['window.title']  = "[$($scheme.Label)] `${rootName}`${separator}`${activeEditorShort}"

    if ($PSCmdlet.ShouldProcess($repo.FullName, "Farben '$type' setzen")) {
        New-Item -ItemType Directory -Path $vsDir -Force | Out-Null
        $json | ConvertTo-Json -Depth 10 | Set-Content -Path $settings -Encoding utf8NoBOM
        Write-Host ("{0,-10} -> {1,-10} {2}" -f $repo.Name, $type, $scheme.Bg) -ForegroundColor Green

        if ($ExcludeFromGit) {
            $exclude = Join-Path $repo.FullName '.git/info/exclude'
            $line = '.vscode/settings.json'
            if (-not (Select-String -Path $exclude -SimpleMatch $line -Quiet -ErrorAction SilentlyContinue)) {
                Add-Content -Path $exclude -Value $line
            }
        }
    }
}
