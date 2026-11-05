# MDS-Development – Systematik der Entwicklungsumgebung

> **MDS** = **M**ulti **D**evelopment **S**ystem

## Historie

| Datum      | Version | Autor                | Änderung                                                                                                  |
| ---------- | ------- | -------------------- | --------------------------------------------------------------------------------------------------------- |
| 2026-10-31 | 0.1     | Hubert Bieder/Claude | Erste Fassung (LUNA/MARS, `~/Dev`, Repos, Kurznamen)                                                      |
| 2026-11-01 | 0.2     | Hubert Bieder/Claude | `DEV_<NAME>` lenkt genau den Ordner `<Name>` um (`DEV_HOME` = `~/Dev`)                                    |
| 2026-11-03 | 1.0     | Hubert Bieder/Claude | Neu gegliedert: nur Systematik; Windows flach unter `C:\woyCode`; `$mdsWoy`; Umsetzung in MdsTools.md     |
| 2026-11-03 | 1.1     | Hubert Bieder/Claude | Windows: Root auf `D:\Dev\Root`, ohne Laufwerk D: auf `C:\Dev\Root`                                       |
| 2026-11-03 | 1.2     | Hubert Bieder/Claude | Ausnahme Auftragsabwicklung (Legacy-Pfade), Repo `Auf`, Init/Post nur bei vollem Lauf, Doku in `Net/docs` |
| 2026-11-05 | 1.3     | Hubert Bieder/Claude | Repos und Root unabhängig (`~/Repos`, `~/Root`; `C:\woyCode`, `D:\Root`); Dev entfällt (MdsTools 8.3); Umstellungsrezept |
| 2026-11-05 | 1.4     | Hubert Bieder/Claude | Offene Punkte: C# auf 8.3 und mdsPackage erledigt, `Auf` präzisiert; Rezept LUNA mit Befehlen (MdsTools 8.3.1) |

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
  aber die Basis der Umgebung (siehe [Windows](#windows-mars)).

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

Es gibt genau zwei Bereiche. Sie sind **unabhängig voneinander** und haben keinen gemeinsamen Elternordner:

| Bereich | Inhalt                                                                                             | Variable    |
| ------- | -------------------------------------------------------------------------------------------------- | ----------- |
| Repos   | Git-Clones (jeder Unterordner = ein Repo, Kurzname) und die globalen Skripte (CloneAll, PushAll …) | `$mdsRepos` |
| Root    | Laufzeitumgebung `Bin`, `Config`, `Data`, `Logs`, `Temp` – nie in Git                              | `$mdsRoot`  |

Wo die Bereiche auf der Platte liegen, unterscheidet sich zwischen macOS und Windows; das Modell ist gleich.

> Bis MdsTools 8.2 gab es zusätzlich den Elternordner Dev (`$mdsDev`, `~/Dev`, `DEV_HOME`). Er entfällt ab 8.3.

### macOS (LUNA)

Beide Bereiche liegen direkt im User-Ordner (Schreibweise immer genau so – Linux/HA-Server unterscheiden
Groß-/Kleinschreibung).

```text
~/Repos/              # $mdsRepos (/Users/hubert/Repos)
   *.ps1              # globale Verwaltungsskripte – nicht in Git
   Mds/               # MdsTools
   Net/               # NetCoreLib2026
   Maui/              # NetMauiApps
   PHB/               # PythonHB

~/Root/               # $mdsRoot  (/Users/hubert/Root)
   Bin/               # ausführbare Tools, gebaute CLIs/Services (im PATH)
   Config/            # Einstellungen, Secrets
   Data/              # Laufzeitdaten der Services (HA-MCP, REST-Dienste)
   Logs/              # Protokolle der Skripte und Services
   Temp/              # Zwischendateien, jederzeit löschbar
   Archiv/            # Sicherungen (z. B. von Uninstall.ps1)
```

### Windows (MARS)

Repos liegen fest in `C:\woyCode`, direkt darin (zusammen mit den woy-Repos). Root liegt **auf Laufwerk D:**,
wenn es eines gibt (MARS): `D:\Root`. Ohne Laufwerk D: liegt Root auf `C:\Root`. Fehlen Root oder die
Laufzeitordner, legt MdsTools sie beim Laden an.

```text
C:\woyCode\           # $mdsRepos
   *.ps1              # globale Verwaltungsskripte
   Mds\  Net\  Maui\  …   # Repos (Kurznamen), dazu die woy-Repos

D:\Root\              # $mdsRoot (ohne Laufwerk D: C:\Root)
   Bin\  Config\  Data\  Logs\  Temp\   # Laufzeitordner
```

Folgen:

- Wer alle Repos braucht, darf nicht einfach alle Unterordner von `$mdsRepos` nehmen, sondern muss Repos erkennen
  (z. B. an `.git` oder an `scripts/Make.ps1`). Unter Windows liegen in `C:\woyCode` auch Ordner, die keine Repos sind.

#### Ausnahme: Auftragsabwicklung (Legacy-Pfade)

Die Auftragsabwicklung (Repo `Auf`) folgt der Trennung Repos/Root **nicht**. Ihre Pfade sind historisch gewachsen,
es gibt keinen weiteren Rechner damit; sie sind deshalb fest und absolut eingetragen und nur unter Windows gesetzt:

| Variable     | Pfad                 | Bedeutung                                                                     |
| ------------ | -------------------- | ----------------------------------------------------------------------------- |
| `$mdsWoySrc` | `C:\woyCode\Auf`     | Quellen                                                                       |
| `$mdsWoyBin` | `C:\woyCode\Auf\Bin` | Ergebnis des Übersetzens (`mk auf`) – im Repo-Ordner, nicht in Git            |
| `$mdsWoyRun` | `D:\woySystems\Bin`  | installierte Programme; `D:\woySystems\InstallDir` ist das Ziel des Kopierens |

`mk auf` baut daher nach `$mdsWoyBin` und **nicht** nach `$mdsBin`. Alle anderen Repos nutzen `$mdsBin`.

### Gegenüberstellung

| Bereich              | macOS (LUNA)        | Windows (MARS)                                             |
| -------------------- | ------------------- | ---------------------------------------------------------- |
| Repos                | `~/Repos`           | `C:\woyCode`                                               |
| Root                 | `~/Root`            | `D:\Root` (ohne D: `C:\Root`)                              |
| Bin … Temp           | `~/Root/<Name>`     | `<Root>\<Name>`                                            |
| Basis abgeleitet aus | `$HOME`             | fest eingetragen                                           |
| Auftragsabwicklung   | –                   | `C:\woyCode\Auf\Bin`, `D:\woySystems` (Legacy, siehe oben) |

### Trennung ist Pflicht

- Repos enthalten nur Quellcode (Git).
- Root enthält nur, was zur Laufzeit gebraucht oder erzeugt wird (Binaries, Konfiguration, Daten).
- Kein Repo schreibt Konfiguration oder Daten in seinen eigenen Ordner, sondern immer nach Root.
  Kein Inhalt von Root wird eingecheckt.
- Root kann unabhängig von den Repos gesichert werden (die liegen auf GitHub).

### Umlenken per Umgebungsvariable

Regel: **`DEV_<NAME>` zeigt genau auf den Ordner `<Name>`** – `DEV_REPOS`, `DEV_ROOT`, `DEV_BIN`,
`DEV_CONFIG`, `DEV_DATA`, `DEV_LOGS`, `DEV_TEMP`. Untergeordnete Ordner folgen mit, sofern sie nicht selbst gesetzt
sind (`DEV_ROOT` verschiebt auch `Bin`, `Config` …). Die Regel gilt auf beiden Systemen; ohne Umgebungsvariable
gilt der Standard aus der Tabelle oben.

> Bis 01.11.2026 stand `DEV_ROOT` für `~/Dev`, danach `DEV_HOME`. Ab MdsTools 8.3 gibt es `DEV_HOME` nicht mehr.

## Repositories

| Kurzname / Ordner | GitHub-Repo (HubertBieder) | Inhalt                                         |
| ----------------- | -------------------------- | ---------------------------------------------- |
| `Mds`             | MdsTools                   | PowerShell-Modul zur Entwicklungsunterstützung |
| `Net`             | NetCoreLib2026             | C#-Basisklassen, Services, CLIs                |
| `Maui`            | NetMauiApps                | .NET-MAUI-Apps für alle Systeme                |
| `PHB`             | PythonHB                   | Python                                         |
| `Auf`             | woyV26                     | Auftragsabwicklung (nur Windows)               |

Unter Windows liegen unter `C:\woyCode` zusätzlich weitere woy-Repos.

**Konvention:** Der Kurzname ist gleichzeitig

- der lokale Ordnername unter Repos,
- das Sprungziel für `go <Kurzname>`,
- der Schlüssel in der Repo-Tabelle von CloneAll/PushAll.

### Ordnername ≠ Repo-Name

Git ist der Ordnername egal. Die Verbindung zum Remote steht in `<Ordner>/.git/config`:

```powershell
git -C ~/Repos/Net remote -v   # → NetCoreLib2026
```

Klonen mit Kurzname:

```powershell
git clone https://github.com/HubertBieder/NetCoreLib2026.git ~/Repos/Net
```

Ein bestehender Ordner kann jederzeit umbenannt werden (vorher VS Code schließen). Danach Verweise prüfen:

```powershell
Get-ChildItem $mdsRepos -Recurse -Include *.csproj,*.sln,*.slnx,*.props,*.code-workspace |
    Select-String 'NetCoreLib' | Select-Object Path, LineNumber, Line
```

### Repo-Tabelle für CloneAll / PushAll

Die globalen Skripte (`Modul/Skripte/` in diesem Repo, installiert nach `$mdsRepos`) arbeiten mit einer Tabelle
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

- `Init.ps1`/`Post.ps1` erhalten die Auswahl (`-Auswahl`, `-Gruppen`, `-Programme`) und entscheiden selbst, was sie
  tun. Arbeiten, die nur beim **vollständigen** Bau Sinn ergeben (Ordner leeren, packen, committen), prüfen
  `if ($Auswahl) { return }` – so in `Auf`.
- Ordner im Bin-Ziel, die das Bereinigen nach dem Bauen überleben müssen (z. B. `Template`, `Bilder`, `Log`), stehen
  in der Programmtabelle von `Make.ps1` unter `Keep`.
- Pfade zu anderen Repos werden absolut über `$mdsRepos` gebildet (z. B. `C:\woyCode\Net`), nicht über alte
  Repo-Namen wie `NetCoreLib`.

### Repo-übergreifende Dokumentation

Themen, die **Net, Maui und Auf gemeinsam** betreffen, werden an einer Stelle beschrieben: in
**`Net/docs/`**. Die Repos verweisen von ihren Dateien (z. B. `Directory.Packages.props`) dorthin, statt das Thema je
Repo zu wiederholen.

| Datei                          | Inhalt                                          | Prüfen          |
| ------------------------------ | ----------------------------------------------- | --------------- |
| `Net/docs/NuGet-Sicherheit.md` | NuGet-Sicherheitslücken, Pins je Repo, Vorgehen | `run net nuget` |

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

- Programmcode in `Auf` setzt noch `Import-Module mdsPackage` voraus (AdminControl `PSDesktopLink.cs` und
  `DesktopIcons.json`, woyControlCenter `UpdateServer.KorrigierePowerShellLinks`, `xBase/PROCESS.cs`,
  woyLib `StartPowerShell.cs`) – Umstellung offen, betrifft auch Kundenrechner. Die Desktop-Symbole rufen Cmdlets
  der Auftragsabwicklung auf (`Invoke-ArtImportDownload`, `Invoke-XRechnung`, `Invoke-Backup` …), die MdsTools
  **nicht** enthält. Vor der Umstellung ist zu entscheiden, welches Modul diese Cmdlets auf Kundenrechnern
  bereitstellt; erst dann wird `ImportCmd` in `PSDesktopLink.cs`/`UpdateServer.cs` ersetzt.
- Umzug LUNA und MARS nach [Umstellung auf MdsTools 8.3](#umstellung-auf-mdstools-83-dev-entfällt) (braucht `sudo`
  bzw. Admin, Dienste stehen kurz still).

Erledigt:

- 05.11.2026: C# an MdsTools 8.3 angepasst (NetCoreLib2026 `68659b52`, NetMauiApps `8c04d99`). `xBase.BasePfad`/
  `BaseRoot` setzen Repos und Root unabhängig (`DEV_REPOS` bzw. `~/Repos`, `C:\woyCode`; `DEV_ROOT` bzw. `~/Root`,
  `D:\Root`/`C:\Root`), `Dev`, `DEV_HOME` und der Konstruktor mit Dev-Pfad entfallen (neu: `repos`, `root`,
  `config`). Ebenso `FritzConfig`, `ImageToolsConfig`, `GlobalConfig` (RepoRoot, MachineDefault),
  `ServiceInstaller` (plist setzt `DEV_ROOT=~/Root`), TaskScheduler und TaskAdmin (prüfen `Root` statt `Dev`).
- 05.11.2026: mdsPackage ist auf LUNA und MARS nicht mehr installiert, `Repos/mdsPackage` gibt es nicht mehr
  (E3 in [MdsTools-Migration.md](MdsTools-Migration.md)). Reste auf MARS unter `C:\woyCode\_Alt\mdsPackage`;
  das GitHub-Repo bleibt für die Kundenrechner (siehe oben) erhalten.

## Umstellung auf MdsTools 8.3 (Dev entfällt)

Rezept für den Umzug von `~/Dev/Repos` und `~/Dev/Root` auf die unabhängigen Ordner `~/Repos` und `~/Root`
(LUNA) bzw. von `D:\Dev\Root` auf `D:\Root` (MARS). Die Net-Änderung kommt **vor** dem Stoppen der Dienste, damit
die Dienste nur für Umzug, Bauen und Installieren stillstehen.

### Vorher (Dienste laufen weiter)

1. ~~NetCoreLib2026 auf 8.3 umstellen~~ – erledigt 05.11.2026 (Net `68659b52`, Maui `8c04d99`, siehe
   [Offene Punkte](#offene-punkte)).

### LUNA (macOS)

1. Dienste stoppen und die alte launchd-plist entfernen (sie enthält noch `DEV_HOME=~/Dev`). Der TaskScheduler
   startet die RestServices (AufAPI, MusterAPI); sie laufen aus `~/Dev/Root/Bin/Rest` und werden mit beendet:

   ```bash
   sudo launchctl bootout system /Library/LaunchDaemons/de.bieders.taskscheduler.plist
   sudo rm /Library/LaunchDaemons/de.bieders.taskscheduler.plist
   pgrep -fl /Dev/Root/Bin    # muss leer sein, sonst: pkill -f /Dev/Root/Bin
   ```

2. Ordner umziehen:

   ```bash
   mv ~/Dev/Repos ~/Repos
   mv ~/Dev/Root ~/Root
   [ -d ~/Dev/Archiv ] && mv ~/Dev/Archiv ~/Root/Archiv
   ```

3. `DEV_HOME` entfernen, falls gesetzt (Shell-Profil, launchd).
4. Neue Shell, MdsTools aktualisieren und installieren – erst danach zeigt `$mdsBin` auf `~/Root/Bin`:

   ```powershell
   cd ~/Repos/Mds
   git pull
   ./Install.ps1
   ```

5. Neue Shell, `Show-Mds` prüfen: `mdsRepos` und `mdsRoot` mit Quelle `Standard` und `Vorhanden = True`.
6. Config auf alte absolute Pfade prüfen und korrigieren (der Umzug korrigiert sie nicht). Stand 05.11.2026 betrifft
   das `TaskScheduler/TaskScheduler.json` (SchedulerPath, DataRoot, Bin-/PWA-Ordner, Task MakeTaskScheduler),
   `Invoices/TestInvoice.json`, `AdminRDM/AdminRDM.json` und `TaskAdmin/TaskAdmin.Config`:

   ```powershell
   $alt = Get-ChildItem ~/Root/Config -Recurse -File -Exclude *.bak* | Select-String -List '/Dev/'
   $alt.Path
   foreach ($f in $alt.Path) {
       Copy-Item $f "$f.bak-83"
       (Get-Content -Raw $f) -replace '/Users/hubert/Dev/Root', '/Users/hubert/Root' `
                             -replace '/Users/hubert/Dev/Repos', '/Users/hubert/Repos' | Set-Content -NoNewline $f
   }
   ```

7. Net und Maui aktualisieren und neu bauen (TaskScheduler und Tasks nach `~/Root/Bin/Task`, RestServices nach
   `~/Root/Bin/Rest`; TaskAdmin aus Maui):

   ```powershell
   go net;  git pull; mk net +t; mk net +r
   go maui; git pull; mk maui TaskAdmin
   ```

8. Dienst neu installieren; der `ServiceInstaller` schreibt die neue plist mit `DEV_ROOT=~/Root`:

   ```bash
   sudo ~/Root/Bin/Task/TaskScheduler --install
   sudo launchctl bootstrap system /Library/LaunchDaemons/de.bieders.taskscheduler.plist
   ```

9. Prüfen, dass die Dienste laufen und Config, Data und Logs unter `~/Root` verwenden (neue Logdateien in
   `~/Root/Logs`).
10. `Invoke-Pester ./tests` in `~/Repos/Mds`; danach die alten `~/Dev/*.ps1` und den leeren Ordner `~/Dev` löschen.

### MARS (Windows)

1. Den Inhalt von `D:\Dev\Root` nach `D:\Root` verschieben, **bevor** das Modul neu geladen wird (sonst legt
   MdsTools ein leeres `D:\Root` an).
2. `cd C:\woyCode\Mds`, `git pull`, `./Install.ps1`, neue Shell, `Show-Mds` prüfen (Root `D:\Root`).
3. Config wie oben auf `\Dev\` prüfen; Programme, die nach `$mdsBin` bauen, neu bauen.
4. Den leeren Ordner `D:\Dev` löschen.
