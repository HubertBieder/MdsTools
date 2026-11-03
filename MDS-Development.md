# MDS-Development – Systematik der Entwicklungsumgebung

> **MDS** = **M**ulti **D**evelopment **S**ystem

## Historie

| Datum      | Version | Autor                | Änderung                                                                                              |
| ---------- | ------- | -------------------- | ----------------------------------------------------------------------------------------------------- |
| 2026-10-31 | 0.1     | Hubert Bieder/Claude | Erste Fassung (LUNA/MARS, `~/Dev`, Repos, Kurznamen)                                                  |
| 2026-11-01 | 0.2     | Hubert Bieder/Claude | `DEV_<NAME>` lenkt genau den Ordner `<Name>` um (`DEV_HOME` = `~/Dev`)                                |
| 2026-11-03 | 1.0     | Hubert Bieder/Claude | Neu gegliedert: nur Systematik; Windows flach unter `C:\woyCode`; `$mdsWoy`; Umsetzung in MdsTools.md |
| 2026-11-03 | 1.1     | Hubert Bieder/Claude | Windows: Root auf `D:\Dev\Root`, wenn Laufwerk D: vorhanden                                          |

## Inhalt und Abgrenzung

Dieses Dokument beschreibt die **Logik** der Entwicklungsumgebung: Systeme, PowerShell 7, Verzeichnisstruktur je
Betriebssystem, Umlenkung per Umgebungsvariable, Repos und ihre Konventionen. Es gilt gleich für das
PowerShell-Modul und für die C#-Klasse `xBase.BaseRoot` in NetCoreLib2026.

Wie das Modul **MdsTools** diese Systematik umsetzt (Variablen `$mds*`, `go`, `mk`, `run`, `Show-Mds`, Cmdlets),
steht in [MdsTools.md](MdsTools.md), dort auch die Auftragsabwicklung unter Windows. Eine Einführung in dieses Repo gibt [README.md](README.md).

## Ziel

- Einheitliche, schlanke Entwicklungsumgebung auf **LUNA** (macOS) und **MARS** (Windows).
- Schwerpunkt: C#-Entwicklung (WinForms, WPF, .NET MAUI, Services), zusätzlich Python.
- **Konventionen statt Konfiguration**: Die JSON-getriebene Modellierung von mdsPackage ist abgelöst.
- Das alte Auftragsprogramm **woy** wird nicht weiterentwickelt. Unter Windows bleibt sein Ordner `C:\woyCode`
  aber die Basis der Umgebung (siehe [Windows](#windows-mars-flach-unter-cwoycode)).

## Systeme und PowerShell

| System | Betriebssystem | Rolle                                      | woy-Stand (`$mdsWoy`) |
| ------ | -------------- | ------------------------------------------ | --------------------- |
| LUNA   | macOS          | Hauptentwicklung                           | `0`                   |
| MARS   | Windows        | Windows-Programme, Auftragsabwicklung, IIS | `26`                  |

- Nur **PowerShell 7**, mindestens **7.6**, auf beiden Systemen.
- Unterschiede zwischen den Systemen werden ausschließlich über `$IsWindows` / `$IsMacOS` erkannt, nie über den
  Rechnernamen.
- Es gibt zwei getrennte Kennzahlen:
  - **Modulversion** (`$mdsVersion`, z. B. `8.x`): Stand von MdsTools, auf allen Systemen **identisch**.
  - **woy-Stand** (`$mdsWoy`, Integer): unterscheidet die Systeme. macOS `0` (kein woy), Windows `26`
    (aktueller Stand von woyCode).

## Verzeichnisstruktur

Es gibt genau drei Bereiche:

| Bereich | Inhalt                                                                | Variable    |
| ------- | --------------------------------------------------------------------- | ----------- |
| Dev     | Einstiegspunkt; globale Verwaltungsskripte (CloneAll, PushAll, …)     | `$mdsDev`   |
| Repos   | ausschließlich Git-Clones, jeder Unterordner = ein Repo (Kurzname)    | `$mdsRepos` |
| Root    | Laufzeitumgebung `Bin`, `Config`, `Data`, `Logs`, `Temp` – nie in Git | `$mdsRoot`  |

Wie die Bereiche auf der Platte liegen, unterscheidet sich zwischen macOS und Windows.

### macOS (LUNA): Hierarchie unter `~/Dev`

Ein einziger Anker im User-Ordner: `~/Dev` (Schreibweise immer genau so – Linux/HA-Server unterscheiden
Groß-/Kleinschreibung).

```text
~/Dev/                # $mdsDev   (/Users/hubert/Dev)
   *.ps1              # globale Verwaltungsskripte – nicht in Git
   Repos/             # $mdsRepos
      Mds/            # MdsTools
      Net/            # NetCoreLib2026
      Maui/           # NetMauiApps
      PHB/            # PythonHB
   Root/              # $mdsRoot
      Bin/            # ausführbare Tools, gebaute CLIs/Services (im PATH)
      Config/         # Einstellungen, Secrets
      Data/           # Laufzeitdaten der Services (HA-MCP, REST-Dienste)
      Logs/           # Protokolle der Skripte und Services
      Temp/           # Zwischendateien, jederzeit löschbar
```

### Windows (MARS): flach unter `C:\woyCode`

Unter Windows stehen Dev und Repos **nicht in einer Hierarchie, sondern auf einer Verzeichnisebene**. Die
Basis ist fest `C:\woyCode`; `$mdsDev` und `$mdsRepos` zeigen auf denselben Ordner, die Repos liegen direkt darin.

Root liegt **auf Laufwerk D:**, wenn es eines gibt (MARS): `D:\Dev\Root`. Fehlen `D:\Dev\Root` oder die
Laufzeitordner, legt MdsTools sie beim Laden an. Ohne Laufwerk D: liegt Root ebenfalls flach in `C:\woyCode`.

```text
C:\woyCode\           # $mdsDev = $mdsRepos
   *.ps1              # globale Verwaltungsskripte
   Mds\  Net\  Maui\  …   # Repos (Kurznamen), dazu die woy-Repos

D:\Dev\Root\         # $mdsRoot (ohne Laufwerk D: = C:\woyCode)
   Bin\  Config\  Data\  Logs\  Temp\   # Laufzeitordner
```

Folgen der flachen Struktur:

- Ohne Laufwerk D: sind `Bin`, `Config`, `Data`, `Logs` und `Temp` reservierte Namen und dürfen kein
  Repo-Kurzname sein.
- Wer alle Repos braucht, darf nicht einfach alle Unterordner von `$mdsRepos` nehmen, sondern muss Repos erkennen
  (z. B. an `.git` oder an `scripts/Make.ps1`).

### Gegenüberstellung

| Bereich              | macOS (LUNA)        | Windows (MARS)      |
| -------------------- | ------------------- | ------------------- |
| Dev                  | `/Users/hubert/Dev` | `C:\woyCode`        |
| Repos                | `~/Dev/Repos`       | `C:\woyCode`        |
| Root                 | `~/Dev/Root`        | `D:\Dev\Root` (ohne D: `C:\woyCode`) |
| Bin … Temp           | `~/Dev/Root/<Name>` | `<Root>\<Name>`     |
| Basis abgeleitet aus | `$HOME`             | fest eingetragen    |

### Trennung ist Pflicht

- Repos enthalten nur Quellcode (Git).
- Root enthält nur, was zur Laufzeit gebraucht oder erzeugt wird (Binaries, Konfiguration, Daten).
- Kein Repo schreibt Konfiguration oder Daten in seinen eigenen Ordner, sondern immer nach Root.
  Kein Inhalt von Root wird eingecheckt.
- Root kann unabhängig von den Repos gesichert werden (die liegen auf GitHub).

### Umlenken per Umgebungsvariable

Regel: **`DEV_<NAME>` zeigt genau auf den Ordner `<Name>`** – `DEV_HOME`, `DEV_REPOS`, `DEV_ROOT`, `DEV_BIN`,
`DEV_CONFIG`, `DEV_DATA`, `DEV_LOGS`, `DEV_TEMP`. Untergeordnete Ordner folgen mit, sofern sie nicht selbst gesetzt
sind (`DEV_ROOT` verschiebt auch `Bin`, `Config` …). Die Regel gilt auf beiden Systemen; ohne Umgebungsvariable
gilt der Standard aus der Tabelle oben.

> Bis 01.11.2026 stand `DEV_ROOT` für `~/Dev` (heute `DEV_HOME`).

## Repositories

| Kurzname / Ordner | GitHub-Repo (HubertBieder) | Inhalt                                         |
| ----------------- | -------------------------- | ---------------------------------------------- |
| `Mds`             | MdsTools                   | PowerShell-Modul zur Entwicklungsunterstützung |
| `Net`             | NetCoreLib2026             | C#-Basisklassen, Services, CLIs                |
| `Maui`            | NetMauiApps                | .NET-MAUI-Apps für alle Systeme                |
| `PHB`             | PythonHB                   | Python                                         |

Unter Windows liegen unter `C:\woyCode` zusätzlich die bestehenden woy-Repos.

**Konvention:** Der Kurzname ist gleichzeitig

- der lokale Ordnername unter Repos,
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
Get-ChildItem $mdsRepos -Recurse -Include *.csproj,*.sln,*.slnx,*.props,*.code-workspace |
    Select-String 'NetCoreLib' | Select-Object Path, LineNumber, Line
```

### Repo-Tabelle für CloneAll / PushAll

Die globalen Skripte (`Skripte/` in diesem Repo, installiert nach `$mdsDev`) arbeiten mit einer Tabelle
GitHub-Repo → Kurzname. Vorhandene Repos werden per `pull --ff-only` aktualisiert statt gelöscht; bei lokalen
Änderungen bricht das Skript mit Warnung ab.

```powershell
# 2026-10-31 Hubi/Claude: GitHub-Repo -> lokaler Kurzname
$Repos = [ordered]@{
    'MdsTools'       = 'Mds'
    'NetCoreLib2026' = 'Net'
    'NetMauiApps'    = 'Maui'
    'PythonHB'       = 'PHB'
}
```

### Konventionen im Repo

| Pfad im Repo          | Zweck                                                             | Aufruf       |
| --------------------- | ----------------------------------------------------------------- | ------------ |
| `scripts/Make.ps1`    | einziger Einstieg zum Bauen aller Programme des Repos             | `mk`         |
| `scripts/Init.ps1`    | optional: vor dem Bauen (alle Programme/Gruppen)                  | über `mk`    |
| `scripts/Post.ps1`    | optional: nach dem Bauen                                          | über `mk`    |
| `scripts/_<Name>.ps1` | eigene Werkzeuge des Repos (z. B. Kopieren nach TEST-SRV/SQL-SRV) | `run <Name>` |
| `.Log/`               | Protokolle der `mk`-Läufe (nicht in Git)                          | –            |

Das Präfix `_` markiert ein Skript als Werkzeug für `run`. Details in [MdsTools.md](MdsTools.md#befehle).

### Versionierung im Code

Jede Änderung wird im Kommentar vermerkt: wann / wer / was, z. B. `# 2026-11-03 Hubi/Claude: …`.

## Plattformhinweise

### Windows (MARS)

- Lange Pfade (MAUI-`obj`-Ordner):

  ```powershell
  git config --global core.longpaths true
  # einmalig als Admin:
  Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' LongPathsEnabled 1
  ```

- Visual Studio: Standard-Speicherort (`source\repos`) auf `C:\woyCode` umstellen.
- Die woy- und Auftrags-Funktionen (MdsSkripte) werden nur hier geladen.

### macOS (LUNA)

- Versteckte Dateien im Finder: **⌘ ⇧ .** (umschalten) oder dauerhaft:

  ```powershell
  defaults write com.apple.finder AppleShowAllFiles -bool true; killall Finder
  ```

- In pwsh: `Get-ChildItem -Force`.
- Neuer Ordner im Finder: **⌘ ⇧ N**.
- Der macOS-Spotlight-Dienst heißt ebenfalls `mds` – kein Konflikt, da kein Programm `mds` im PATH liegt.

### Allgemein

- Repos **nicht** in iCloud/OneDrive ablegen (`.git`, `bin`, `obj`).
- Groß-/Kleinschreibung der Ordner konsequent halten.
- `Bin` steht im PATH, damit gebaute Tools überall aufrufbar sind (erledigt MdsTools beim Laden).

## Offene Punkte

- C#: Der Konstruktor von `xBase.BaseRoot` muss ohne Eingabe die Standards für Windows (`C:\woyCode`, flach) bzw.
  macOS (`~/Dev`, Hierarchie) setzen; wird ein Pfad übergeben, werden die Ordner daraus abgeleitet.
- Altes Repo mdsPackage entfernen, sobald MdsTools auf LUNA und MARS läuft.
