#Requires -Version 7.0
<#
.SYNOPSIS
    Setzt VS-Code-Farben pro Repository abhängig vom Repo-Typ (C#, Python, PowerShell).

.DESCRIPTION
    Durchsucht alle Git-Repos direkt unterhalb von -Root, erkennt den Typ anhand der Dateien
    und schreibt/merged .vscode/settings.json und *.code-workspace im Repo-Root
    (workbench.colorCustomizations, window.title; peacock.color wird entfernt).
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
    1.11.0   2026-11-14  Claude/Hubi   Nur schreiben, wenn sich etwas ändert; atomar über Temp-Datei,
                                       damit offene VS-Code-Fenster nicht auf Schwarz zurückfallen
    1.12.0   2026-11-14  Claude/Hubi   Auch *.code-workspace im Repo-Root einfärben (Multi-Root-Workspaces);
                                       abschließende Kommas in JSONC werden toleriert
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

function Set-ColorSettings {
    # Farben, Titel in ein Settings-Objekt mergen (fremde Schlüssel bleiben erhalten)
    param($Settings, $Scheme)
    $colors = if ($Settings.Contains('workbench.colorCustomizations')) { $Settings['workbench.colorCustomizations'] } else { [ordered]@{} }
    (Get-ColorBlock $Scheme).GetEnumerator() | ForEach-Object { $colors[$_.Key] = $_.Value }
    $Settings['workbench.colorCustomizations'] = $colors
    $Settings.Remove('peacock.color')            # sonst überschreibt Peacock die Farben mit eigenen Werten
    $Settings['window.title'] = "[$($Scheme.Label)] `${rootName}`${separator}`${activeEditorShort}"
}

function Read-JsonFile {
    # JSON/JSONC lesen (pwsh 7 toleriert // Kommentare); $null = nicht lesbar
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{} }
    $raw = Get-Content -LiteralPath $Path -Raw
    if (-not $raw.Trim()) { return [ordered]@{} }
    # 1.12.0: abschließende Kommas (in .code-workspace üblich) vor } bzw. ] entfernen
    $raw = [regex]::Replace($raw, ',(\s*[\}\]])', '$1')
    return ($raw | ConvertFrom-Json -AsHashtable)
}

function Write-JsonIfChanged {
    # Nur schreiben, wenn sich etwas ändert; atomar über Temp-Datei + Umbenennen
    param([string]$Path, $Object, [string]$Info)
    $neu = ($Object | ConvertTo-Json -Depth 20) + "`n"
    $alt = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { $null }
    if ($alt -and ($alt -replace "`r`n", "`n").TrimEnd() -eq $neu.TrimEnd()) {
        Write-Host "$Info  (unverändert)" -ForegroundColor DarkGray
        return
    }
    $dir = Split-Path -Parent $Path
    $tmp = Join-Path $dir ((Split-Path -Leaf $Path) + '.tmp-' + [guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($tmp, $neu, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
    Write-Host $Info -ForegroundColor Green
}

foreach ($repo in $repos) {
    $type = Get-RepoType -Path $repo.FullName
    if (-not $type) {
        Write-Warning "$($repo.Name): Typ nicht erkannt - übersprungen."
        continue
    }
    $scheme = $Schemes[$type]
    $info   = "{0,-10} -> {1,-10} {2}" -f $repo.Name, $type, $scheme.Bg

    # --- Ordner: .vscode/settings.json ---
    $vsDir    = Join-Path $repo.FullName '.vscode'
    $settings = Join-Path $vsDir 'settings.json'
    try { $json = Read-JsonFile $settings }
    catch { Write-Warning "$($repo.Name): settings.json nicht lesbar ($($_.Exception.Message)) - übersprungen."; continue }
    Set-ColorSettings $json $scheme

    if ($PSCmdlet.ShouldProcess($settings, "Farben '$type' setzen")) {
        New-Item -ItemType Directory -Path $vsDir -Force | Out-Null
        Write-JsonIfChanged $settings $json $info

        if ($ExcludeFromGit) {
            $exclude = Join-Path $repo.FullName '.git/info/exclude'
            $line = '.vscode/settings.json'
            if (-not (Select-String -Path $exclude -SimpleMatch $line -Quiet -ErrorAction SilentlyContinue)) {
                Add-Content -Path $exclude -Value $line
            }
        }
    }

    # --- 1.12.0: Workspace-Dateien im Repo-Root (*.code-workspace) ---
    #     Im Multi-Root-Workspace gelten Farben/Titel nur aus der Workspace-Datei, nicht aus den Ordnern.
    foreach ($wsFile in Get-ChildItem -LiteralPath $repo.FullName -File -Filter '*.code-workspace') {
        try { $ws = Read-JsonFile $wsFile.FullName }
        catch { Write-Warning "$($wsFile.Name): nicht lesbar ($($_.Exception.Message)) - übersprungen."; continue }
        if (-not $ws.Contains('settings')) { $ws['settings'] = [ordered]@{} }
        Set-ColorSettings $ws['settings'] $scheme
        if ($PSCmdlet.ShouldProcess($wsFile.FullName, "Farben '$type' setzen")) {
            Write-JsonIfChanged $wsFile.FullName $ws ("{0,-10}    {1}" -f '', $wsFile.Name)
        }
    }
}
