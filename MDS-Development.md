# MDS-Development – Entwicklungsumgebung LUNA / MARS

Stand: 31.10.2026 (Hubi / Claude)

## Ziel

- Einheitliche, schlanke Entwicklungsumgebung auf **LUNA** (macOS) und **MARS** (Windows).
- Schwerpunkt: C#-Entwicklung (WinForms, WPF, .NET MAUI, Services) unter macOS.
- **Konventionen statt Konfiguration**: Die bisherige JSON-getriebene Modellierung (mdsPackage) wird abgelöst.
- `woy` / `woyCode` ist Geschichte und wird nicht mehr verwendet.

## Verzeichnisstruktur

Ein einziger Anker im User-Ordner: `~/Dev` (Schreibweise immer genau so – Linux/HA-Server unterscheidet Groß-/Kleinschreibung).

```text
~/Dev/
   *.ps1        # globale Verwaltungsskripte (CloneAll, PushAll, …) – nicht in Git
   Repos/       # ausschließlich Git-Clones, jeder Unterordner = ein Repo
      Mds/      # MdsTools        (Nachfolger von mdsPackage)
      Net/      # NetCoreLib2026
      Maui/     # NetMauiApps
      PHB/      # PythonHB
   Root/        # Laufzeitumgebung – strikt getrennt von Repos, nie in Git
      Bin/      # ausführbare Tools, gebaute CLIs/Services
      Config/   # Einstellungen, Secrets
      Data/     # Laufzeitdaten der Services (HA-MCP, REST-Dienste)
      Logs/     # Protokolle der Skripte und Services
      Temp/     # Zwischendateien, jederzeit löschbar
```

**Trennung ist Pflicht:**

- `Repos/` enthält nur Quellcode (Git).
- `Root/` enthält nur, was zur Laufzeit gebraucht oder erzeugt wird (Binaries, Konfiguration, Daten).
- Kein Repo schreibt in seinen eigenen Ordner Konfiguration oder Daten, sondern immer nach `Root/`. Kein Inhalt von `Root/` wird eingecheckt.
- Gesichert werden kann `Root/` unabhängig von den Repos (die liegen ja auf GitHub).

| System         | Pfad                  |
| -------------- | --------------------- |
| LUNA (macOS)   | `/Users/hubert/Dev`   |
| MARS (Windows) | `C:\Users\hubert\Dev` |

Beide liegen unter `$HOME`, damit bleibt die Skriptlogik identisch.

### Umlenken per Umgebungsvariable

Regel: **`DEV_<NAME>` zeigt genau auf den Ordner `<Name>`** – `DEV_HOME` (`~/Dev`), `DEV_REPOS`,
`DEV_ROOT` (`~/Dev/Root`), `DEV_BIN`, `DEV_CONFIG`, `DEV_DATA`, `DEV_LOGS`, `DEV_TEMP`.
Untergeordnete Ordner folgen mit. Gilt gleich für MdsTools (`$mds*`) und die C#-Klasse `xBase.BaseRoot`.

## Repositories

| Kurzname / Ordner | GitHub-Repo (HubertBieder) | Inhalt                                         |
| ----------------- | -------------------------- | ---------------------------------------------- |
| `Mds`             | **MdsTools** (neu)         | PowerShell-Modul zur Entwicklungsunterstützung |
| `Net`             | NetCoreLib2026             | C#-Basisklassen, Services, CLIs                |
| `Maui`            | NetMauiApps                | .NET-MAUI-Apps für alle Systeme                |
| `PHB`             | PythonHB                   | Python                                         |

**Konvention:** Der Kurzname ist gleichzeitig

- der lokale Ordnername unter `~/Dev/Repos`,
- das Sprungziel für `go <Kurzname>`,
- der Schlüssel in der Repo-Tabelle von CloneAll/PushAll.

### Ordnername ≠ Repo-Name

Git ist der Ordnername egal. Die Verbindung zum Remote steht in `<Ordner>/.git/config`:

```powershell
git -C ~/Dev/Repos/Net remote -v   # → NetCoreLib2026
```

Klonen mit Kurzname:

```powershell
git clone https://github.com/HubertBieder/NetCoreLib2026.git ~/Dev/Repos/Net
```

Ein bestehender Ordner kann jederzeit umbenannt werden (vorher VS Code schließen). Danach Verweise prüfen:

```powershell
Get-ChildItem ~/Dev/Repos -Recurse -Include *.csproj,*.sln,*.slnx,*.props,*.code-workspace |
    Select-String 'NetCoreLib' | Select-Object Path, LineNumber, Line
```

## Modul MdsTools

- Repo / Modul: **MdsTools**, lokaler Ordner: **Mds**
- *mds* = **M**ulti**D**evelopment**S**ystem
- Aufgaben: Erstellen und Verwalten von WinForms-, WPF-, MAUI- und Service-Projekten (Zielsprache C#), neue Projekte werden per PS-Skript erzeugt.
- **Cmdlet-Namen bleiben gegenüber mdsPackage unverändert**, bis auf die Umbenennungen in `Repos/Mds/MdsTools.md`.
- Das alte mdsPackage liegt vorerst noch unter `~/Dev/Repos/mdsPackage` und gehört nicht zur Struktur. Sobald MdsTools funktioniert, wird es entfernt.
- Es darf **nicht parallel** geladen werden (gleiche Cmdlet-Namen → das zuletzt importierte Modul gewinnt). mdsPackage daher **nicht** in `PSModulePath` / `$PROFILE` aufnehmen.

### Struktur (Vorschlag)

PowerShell lädt Module nur automatisch, wenn Ordnername = Modulname. Deshalb liegt das Modul eine Ebene tiefer:

```text
~/Dev/Repos/Mds/
   src/MdsTools/MdsTools.psd1
   src/MdsTools/MdsTools.psm1
   src/MdsTools/Public/       # exportierte Cmdlets
   src/MdsTools/Private/
   templates/                 # WinForms, WPF, MAUI, Service
   tests/
   README.md
```

In `$PROFILE`:

```powershell
$env:PSModulePath = (Join-Path $HOME 'dev/Repos/Mds/src') +
    [IO.Path]::PathSeparator + $env:PSModulePath
```

## Zentrale Hilfsfunktionen

```powershell
# 2026-10-31 Hubi/Claude: zentrale Pfadauflösung unter ~/Dev
#   Repos  -> ~/Dev/Repos
#   Root   -> ~/Dev/Root
#   Bin/Config/Data/Logs/Temp -> ~/Dev/Root/<Sub>
# 2026-11-01 Hubi/Claude: DEV_<NAME> lenkt genau den Ordner <Name> um (DEV_HOME = ~/Dev)
function Get-DevPath {
    param([ValidateSet('','Repos','Root','Bin','Config','Data','Logs','Temp')]
          [string]$Sub = '')
    $name = if ($Sub) { $Sub } else { 'Home' }
    $wert = [Environment]::GetEnvironmentVariable("DEV_$($name.ToUpperInvariant())")
    if ($wert) { return $wert }
    switch ($Sub) {
        ''      { Join-Path $HOME 'Dev' }
        'Repos' { Join-Path (Get-DevPath) 'Repos' }
        'Root'  { Join-Path (Get-DevPath) 'Root' }
        default { Join-Path (Get-DevPath Root) $Sub }
    }
}

# 2026-10-31 Hubi/Claude: in Repo-Ordner springen (go Net)
function go {
    param([Parameter(Mandatory)][string]$Name)
    $p = Join-Path (Get-DevPath Repos) $Name
    if (Test-Path $p) { Set-Location $p }
    else { Write-Warning "Kein Repo '$Name' unter $(Get-DevPath Repos)" }
}
```

### Repo-Tabelle für CloneAll / PushAll

```powershell
# 2026-10-31 Hubi/Claude: GitHub-Repo -> lokaler Kurzname
$Repos = [ordered]@{
    'MdsTools'       = 'Mds'
    'NetCoreLib2026' = 'Net'
    'NetMauiApps'    = 'Maui'
    'PythonHB'       = 'PHB'
}
foreach ($r in $Repos.GetEnumerator()) {
    $target = Join-Path (Get-DevPath Repos) $r.Value
    if (Test-Path (Join-Path $target '.git')) { git -C $target pull --ff-only }
    else { git clone "https://github.com/HubertBieder/$($r.Key).git" $target }
}
```

Regeln aus dem bisherigen Stand bleiben: vorhandene Repos per `pull` aktualisieren statt löschen, bei lokalen Änderungen mit Warnung abbrechen, OS-Erkennung (`$IsWindows` / `$IsMacOS`), Versionierung per Kommentar (wann / wer / was).

## Plattformhinweise

### Windows (MARS)

- Lange Pfade (MAUI-`obj`-Ordner):

  ```powershell
  git config --global core.longpaths true
  # einmalig als Admin:
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' LongPathsEnabled 1
  ```

- Visual Studio: Standard-Speicherort (`source\repos`) auf `~\Dev\Repos` umstellen.

### macOS (LUNA)

- Versteckte Dateien im Finder: **⌘ ⇧ .** (umschalten) oder dauerhaft:

  ```powershell
  defaults write com.apple.finder AppleShowAllFiles -bool true; killall Finder
  ```

- In pwsh: `Get-ChildItem -Force`.
- Neuer Ordner im Finder: **⌘ ⇧ N**.
- Hinweis: Der macOS-Spotlight-Dienst heißt ebenfalls `mds` – kein Konflikt, da kein Programm `mds` im PATH liegt.

## Allgemein

- Repos **nicht** in iCloud/OneDrive ablegen (`.git`, `bin`, `obj`).
- Groß-/Kleinschreibung der Ordner konsequent halten.

## Bin in den PATH

Damit Tools aus `Root/Bin` überall aufrufbar sind, in `$PROFILE`:

```powershell
$env:PATH = (Get-DevPath Bin) + [IO.Path]::PathSeparator + $env:PATH
```

## Offene Punkte

- Beschreibung des Moduls MdsTools (folgt).
- Präfix der bestehenden Cmdlets prüfen und dokumentieren.
- `go` mit Tab-Vervollständigung der Kurznamen.
- CloneAll / PushAll auf `Get-DevPath` und Repo-Tabelle umstellen.
- Altes Repo mdsPackage entfernen, sobald MdsTools funktioniert.
