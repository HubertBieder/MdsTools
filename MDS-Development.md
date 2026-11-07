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
| 2026-11-05 | 1.5     | Hubert Bieder/Claude | Erledigtes LUNA-Rezept entfernt; MdsTools-Migration.md entfällt; offene Punkte und Rezept MARS in Luna.md/Mars.md |
| 2026-11-05 | 1.6     | Hubert Bieder/Claude | Nur aktueller Stand: Erledigt-Liste, Dev-Hinweise und mdsPackage entfernt |

## Inhalt und Abgrenzung

Dieses Dokument beschreibt die **Logik** der Entwicklungsumgebung: Systeme, PowerShell 7, Verzeichnisstruktur je
Betriebssystem, Umlenkung per Umgebungsvariable, Repos und ihre Konventionen. Es gilt gleich für das
PowerShell-Modul und für die C#-Klasse `xBase.BaseRoot` in NetCoreLib2026.

Wie das Modul **MdsTools** diese Systematik umsetzt (Variablen `$mds*`, `go`, `mk`, `run`, `Show-Mds`, Cmdlets),
steht in [MdsTools.md](MdsTools.md), dort auch die Auftragsabwicklung unter Windows. Eine Einführung in dieses Repo gibt [README.md](README.md).

## Ziel

- Einheitliche, schlanke Entwicklungsumgebung auf **LUNA** (macOS) und **MARS** (Windows).
- Schwerpunkt: C#-Entwicklung (WinForms, WPF, .NET MAUI, Services), zusätzlich Python.
- **Konventionen statt Konfiguration.**
- Das alte Auftragsprogramm **woy** wird nicht weiterentwickelt. Unter Windows bleibt sein Ordner `C:\woyCode`
  aber die Basis der Umgebung (siehe [Windows](#windows-mars)).

## Systeme und PowerShell

| System | Betriebssystem | Rolle                                      | woy-Stand (`$mdsWoy`) |
| ------ | -------------- | ------------------------------------------ | --------------------- |
| LUNA   | macOS          | Hauptentwicklung                           | `0`                   |
| MARS   | Windows        | Windows-Programme, Auftragsabwicklung, IIS | `26`                  |

- MdsTools wird nur auf **LUNA und MARS** installiert, sonst nirgends (keine Kundenrechner).
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
Änderungen bricht das Skript mit Warnung ab. Hat CloneAll das Repo Mds neu geklont oder neue Commits geholt,
ruft es danach sofort `Mds/Install.ps1` auf (gilt auch für `clone` und CloneMDS).

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

Offene Aufgaben stehen in zwei Listen: [Luna.md](Luna.md) (allgemein und LUNA, zuerst) und [Mars.md](Mars.md)
(Umstellung von MARS in einem Stück, danach).
