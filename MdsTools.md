# MdsTools – Beschreibung des Moduls

## Historie

| Datum      | Version | Autor                | Änderung                                                                                  |
| ---------- | ------- | -------------------- | ----------------------------------------------------------------------------------------- |
| 2026-10-31 | 0.1     | Hubert Bieder        | README formatiert, Historie ergänzt, Pfad relativ gesetzt                                 |
| 2026-10-31 | 0.2     | Hubert Bieder/Claude | Spezifikation korrigiert, Entscheidungen und offene Punkte ergänzt                        |
| 2026-10-31 | 0.3     | Hubert Bieder/Claude | Entscheidungen übernommen, Cmdlets umbenannt, Ausgabeordner wählbar                       |
| 2026-10-31 | 0.11    | Hubert Bieder/Claude | mk: Repo als erster Positionsparameter (`mk <Repo> [Programm]`)                           |
| 2026-10-31 | 0.10    | Hubert Bieder/Claude | Schritt 8: Pester-Tests, ScriptAnalyzer-Einstellungen, process-Blöcke                     |
| 2026-10-31 | 0.9     | Hubert Bieder/Claude | Schritt 7 (Teil): Invoke-Make, Make.ps1 in Net und Maui, *.app bleibt bei Clear-BinFolder |
| 2026-10-31 | 0.8     | Hubert Bieder/Claude | Schritt 6: Uninstall.ps1                                                                  |
| 2026-10-31 | 0.7     | Hubert Bieder/Claude | Globale Skripte auf Repo-Tabelle und Kurznamen umgestellt                                 |
| 2026-10-31 | 0.6     | Hubert Bieder/Claude | Schritt 5: Install.ps1 und Profil auf MdsTools umgestellt, UpdatePS.ps1 entfernt          |
| 2026-10-31 | 0.5     | Hubert Bieder/Claude | Umsetzung Schritte 1, 2 und 4; SkriptModule als *.ps1; Backup-Develop gefunden            |
| 2026-10-31 | 0.4     | Hubert Bieder/Claude | E3 und E9 entschieden                                                                     |
| 2026-11-01 | 0.12    | Hubert Bieder/Claude | `DEV_HOME` statt `DEV_ROOT` für `~/Dev`; jeder Ordner über `DEV_<NAME>` umlenkbar         |
| 2026-11-01 | 0.13    | Hubert Bieder/Claude | mk: Repo des aktuellen Ordners; macOS-MAUI als .app, `-Package` für .pkg                  |
| 2026-11-02 | 0.14    | Hubert Bieder/Claude | Invoke-Make: Gruppen (`mk +dI`), `Init.ps1`/`Post.ps1`, Logdatei; Schlüssel `Project`     |
| 2026-11-02 | 0.15    | Hubert Bieder/Claude | Invoke-Make: `Init.ps1`/`Post.ps1` nicht bei einzeln angegebenem Programm                 |
| 2026-11-03 | 0.16    | Hubert Bieder/Claude | Windows: feste Basis `C:\woyCode`, `Repos` und `Root` auf derselben Ebene                 |
| 2026-11-03 | 0.17    | Hubert Bieder/Claude | `run`: Repo-Skripte `scripts/_<Name>.ps1` ausführen und auflisten                         |
| 2026-11-03 | 0.18    | Hubert Bieder/Claude | `$mdsWoy`, `Show-Mds`; Systematik nach MDS-Development.md verschoben                      |
| 2026-11-03 | 0.19    | Hubert Bieder/Claude | Migration nach MdsTools-Migration.md; Kapitel Auftragsabwicklung (Gerüst)                 |
| 2026-11-03 | 0.20    | Hubert Bieder/Claude | `go repos`; CloneAll unter Windows direkt nach `C:\woyCode`                               |
| 2026-11-03 | 0.21    | Hubert Bieder/Claude | `go`: nur Ordner mit `.git`                                                               |
| 2026-11-03 | 0.22    | Hubert Bieder/Claude | Windows: `$mdsRoot` = `D:\Dev\Root`, ohne Laufwerk D: `C:\Dev\Root`                      |
| 2026-11-03 | 0.23    | Hubert Bieder/Claude | 8.2: Schlüssel `Keep` (Invoke-Make/Clear-BinFolder); JSON-Verfahren (`*.mds`) entfällt    |
| 2026-11-03 | 0.24    | Hubert Bieder/Claude | Windows: `$mdsWoySrc`/`Bin`/`Run`, Show-Mds mit Zeile `System`, MdsSkripte/Auftrag.ps1    |
| 2026-11-03 | 0.25    | Hubert Bieder/Claude | Auftragsabwicklung: `mk auf` (Init/Post), `run auf copy`, Schlüssel der woy.env           |
| 2026-11-03 | 0.26    | Hubert Bieder/Claude | `run auf auto/version/backup/desktop`, `run net nuget`; Backup-Develop liefert Pfad/`$null`; „Verbunden mit“ nur mit `-Verbose` |
| 2026-11-04 | 0.27    | Hubert Bieder/Claude | 8.2.1: `Show-Mds -Full` (`-F`); globale Skripte unter `Modul/Skripte`, Root-Ordner `scripts/` |
| 2026-11-04 | 0.28    | Hubert Bieder/Claude | `run`: globale Skripte aus `Mds/scripts`, Abkürzungen; `run backup [Repo] [-Force]`         |
| 2026-11-04 | 0.29    | Hubert Bieder/Claude | `Install-PowerShell7.ps1/.cmd` (Windows, 5.1) gehört zum Repo; Install/Uninstall zeigen die Modulversion |
| 2026-11-04 | 0.30    | Hubert Bieder/Claude | 8.2.2: `Show-Repos`; erste Zeile der README.md `# <Name> – <Kurzbeschreibung>`                |
| 2026-11-04 | 0.31    | Hubert Bieder/Claude | `run mars`: MARS wecken (Wake-on-LAN) und Freigaben auf LUNA aktivieren                    |

---

**Autor:** Hubert Bieder

> **MDS** = **M**ulti **D**evelopment **S**ystem

## Inhalt und Abgrenzung

Dieses Dokument beschreibt das PowerShell-7-Modul **MdsTools**: Aufbau, Initialisierung, globale Variablen, die
Hilfsfunktionen `go`, `mk`, `run` und `Show-Mds`, die übrigen Cmdlets sowie die
[Auftragsabwicklung](#auftragsabwicklung-nur-windows) unter Windows.

Die zugrunde liegende Systematik – Systeme, Verzeichnisstruktur unter macOS und Windows, `DEV_<NAME>`,
Repo-Konventionen – steht in [MDS-Development.md](MDS-Development.md) und wird hier nicht wiederholt.

## Relevante Dokumente

- [README.md](README.md) – Einführung in dieses Repo
- [MDS-Development.md](MDS-Development.md) – Systematik der Entwicklungsumgebung
- [MdsTools-Migration.md](MdsTools-Migration.md) – Ablösung von mdsPackage (Motivation, Entscheidungen,
  Umsetzung, Umbenennungen)
- `C:\woyCode\Net\docs\NuGet-Sicherheit.md` – NuGet-Sicherheitslücken und Pins, zentral für Net, Maui und Auf
  (Prüfen: `run net nuget`)

## Begriffe

| Begriff       | Bedeutung                                                                  |
| ------------- | -------------------------------------------------------------------------- |
| mdsPackage    | Bisheriges PowerShell-Modul unter `~/Dev/Repos/mdsPackage` (Version 7.0)   |
| MdsTools      | Neues Modul, Nachfolger von mdsPackage, Repo-Ordner `~/Dev/Repos/Mds`      |
| woy           | Altes Auftragsprogramm samt Infrastruktur – wird nicht weiterentwickelt    |
| Auftrag (MDS) | Auftragsabwicklung auf Basis von woy/mdsProfile – **nur unter Windows**    |
| Kurzname      | Ordnername eines Repos unter `Repos/` (z. B. `Net`, `Maui`), Ziel für `go` |

## Anforderungen

| Nr. | Anforderung                                                                                                                                                 |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1  | Nur PowerShell 7, mindestens **7.6** (`PowerShellVersion = '7.6'` im Manifest, `#Requires -Version 7.6`).                                                   |
| A2  | Die Modulversion wird **zentral** im Manifest `MdsTools.psd1` festgelegt; `$mdsVersion` liest sie aus.                                                      |
| A3  | `Install.ps1` in der Repo-Root installiert das Modul, das Profil und die globalen Skripte.                                                                  |
| A4  | `Uninstall.ps1` in der Repo-Root entfernt alte Installationen von mdsPackage und MdsTools.                                                                  |
| A5  | Übernommene Cmdlets behalten ihren Namen, außer den Einträgen unter [Umbenennungen](MdsTools-Migration.md#umbenennungen).                                   |
| A6  | Funktionen für woy und Auftragsabwicklung kommen als einzelne `*.ps1` nach `MdsSkripte`. Das JSON-Verfahren (`*.mds`) entfällt (8.2).        |
| A7  | Alle übrigen Funktionen kommen thematisch gruppiert in `*.ps1`-Dateien unter `SkriptModule`; `MdsTools.psm1` lädt sie per Dot-Sourcing in den Modulbereich. |
| A8  | Nur Funktionen, die von außen gebraucht werden, werden exportiert; alles andere bleibt intern.                                                              |
| A9  | Jede öffentliche Funktion hat eine Comment-based Help (`.SYNOPSIS`, `.EXAMPLE`).                                                                            |
| A10 | Windows-only-Funktionen prüfen `$IsWindows` und brechen auf macOS mit einer verständlichen Meldung ab.                                                      |

## Verzeichnisstruktur

PowerShell lädt ein Modul nur dann automatisch, wenn der Ordnername gleich dem Modulnamen ist. Deshalb liegt das
Modul in `Modul/MdsTools/`.

Die Funktionsdateien in `SkriptModule` sind `*.ps1` und keine eigenen `*.psm1`-Module. Das Root-Modul lädt sie per
Dot-Sourcing in **einen** gemeinsamen Modulbereich. So sehen sich alle Funktionen gegenseitig, und interne Helfer
wie `Resolve-MdsPath` müssen nicht exportiert werden. mdsPackage musste sie wegen der getrennten `NestedModules`
global machen.

```text
~/Dev/Repos/Mds/
   README.md
   MDS-Development.md          # Systematik der Entwicklungsumgebung
   MdsTools.md                 # diese Beschreibung
   MdsTools-Migration.md       # Ablösung von mdsPackage
   Install.ps1                 # Installation (analog mdsPackage)
   Uninstall.ps1               # entfernt alte Installationen (bisher "clear.ps1")
   InstallHelper.ps1           # gemeinsame Pfad-Helfer für Install.ps1 und Uninstall.ps1
   Install-PowerShell7.ps1     # nur Windows, läuft unter 5.1: PowerShell 7 prüfen/installieren (-Last, -Version)
   Install-PowerShell7.cmd     # Starter: 5.1 als Administrator, Argumente werden durchgereicht
   Modul/
      MdsTools/
         MdsTools.psd1         # Manifest, Version, Exportliste
         MdsTools.psm1         # Root-Modul, lädt SkriptModule/*.ps1
         Skripte/
            InitModule.ps1     # ScriptsToProcess: globale Variablen, Root-Ordner, PATH
         SkriptModule/         # *.ps1 – Funktionen des Moduls
            Output.ps1         # Write-Header/Start/Info/Success/Fail
            Common.ps1         # interne Helfer (Resolve-MdsPath, Spinner, Admin-Prüfung)
            Build.ps1          # Publish-DotNet, Build-Project, Clear-BinFolder
            FileIO.ps1         # Kopieren, Sichern, Bereinigen
            Share.ps1          # Copy-*WithCredential (Windows und macOS)
            Zip.ps1            # ZIP-Funktionen
            Tools.ps1          # Update-/Show-PowerShell, Update-DotNet, Show-Mds
            Navigation.ps1     # go, mk, run
         MdsSkripte/           # *.ps1 – woy/Auftrag (aus mdsProfile.ps1), nur Windows
            InitMDS.ps1        # lädt alle MdsSkripte
            WoyEnv.ps1         # Get-WoyValue, Get-WoyCredential (woy.env)
      Skripte/                 # globale Skripte (CloneAll, PushAll, …) → $mdsDev
   Profile/
      profile.ps1              # wird nach $PROFILE kopiert
   scripts/                    # globale run-Skripte (_backup.ps1), gelten in allen Repos
   tests/                      # Pester-Tests (Invoke-Pester ./tests)
   PSScriptAnalyzerSettings.psd1  # bewusst ausgeschlossene Analyzer-Regeln
```

`Modul/Skripte/` wird von `Install.ps1` nach `$mdsDev` kopiert, aber nur, wenn die Quelle neuer ist.

## Initialisierung und Ablauf

1. `$PROFILE` (aus `Profile/profile.ps1`) führt `Import-Module MdsTools` aus.
2. `Skripte/InitModule.ps1` setzt die globalen Variablen (je nach Betriebssystem, siehe unten), legt fehlende
   Ordner an und nimmt `$mdsBin` in den `PATH` auf.
3. Nur unter Windows wird `MdsSkripte/InitMDS.ps1` geladen; es stellt die woy- und Auftrags-Cmdlets bereit.
4. Das Profil gibt eine kurze Statuszeile aus (Modulversion, PS-Version, OS).

## Globale Variablen

`Skripte/InitModule.ps1` setzt die Variablen beim Laden des Moduls. Die Verzeichnislogik dahinter (Hierarchie
unter macOS, flach unter `C:\woyCode` unter Windows) beschreibt
[MDS-Development.md](MDS-Development.md#verzeichnisstruktur).

| Variable      | macOS (LUNA)        | Windows (MARS)      | Bedeutung                                    |
| ------------- | ------------------- | ------------------- | -------------------------------------------- |
| `$mdsVersion` | `8.x` aus Manifest  | `8.x` aus Manifest  | Modulversion, auf allen Systemen gleich (A2) |
| `$mdsWoy`     | `0`                 | `26`                | woy-Stand des Systems, `[int]`               |
| `$mdsDev`     | `/Users/hubert/Dev` | `C:\woyCode`        | Einstiegspunkt, Ziel von `go dev`            |
| `$mdsRepos`   | `$mdsDev/Repos`     | `C:\woyCode`        | Git-Clones, Ziel von `go repos`              |
| `$mdsRoot`    | `$mdsDev/Root`      | `D:\Dev\Root` ¹     | Laufzeitumgebung, Ziel von `go root`         |
| `$mdsBin`     | `$mdsRoot/Bin`      | `$mdsRoot\Bin`      | gebaute Programme, steht im `PATH`           |
| `$mdsConfig`  | `$mdsRoot/Config`   | `$mdsRoot\Config`   | Konfiguration je Programm                    |
| `$mdsData`    | `$mdsRoot/Data`     | `$mdsRoot\Data`     | Laufzeitdaten der Services                   |
| `$mdsLogs`    | `$mdsRoot/Logs`     | `$mdsRoot\Logs`     | Protokolle                                   |
| `$mdsTemp`    | `$mdsRoot/Temp`     | `$mdsRoot\Temp`     | Zwischendateien, Freigabe-Mounts (macOS)     |

¹ Wenn es ein Laufwerk D: gibt (MARS); sonst `C:\Dev\Root`. Fehlende Ordner legt MdsTools beim Laden an.

Nur unter Windows gibt es zusätzlich die **Legacy-Adressen der Auftragsabwicklung**. Sie sind fest und absolut
(es gibt keinen weiteren Rechner mit woy), werden nicht umgelenkt und nicht angelegt; unter macOS fehlen sie.

| Variable     | Windows (MARS)       | Bedeutung                                              |
| ------------ | -------------------- | ------------------------------------------------------ |
| `$mdsWoySrc` | `C:\woyCode\Auf`     | Quellen der Auftragsabwicklung                         |
| `$mdsWoyBin` | `C:\woyCode\Auf\Bin` | Binärdaten aus dem Übersetzen (`Auf/scripts/Make.ps1`) |
| `$mdsWoyRun` | `D:\woySystems\Bin`  | Zielverzeichnis der installierten Programme            |

Die Hilfsfunktionen dazu (`Clear-WoyProcess`, `Write-WoyVersionCS`, `Write-DateiListe`) stehen in
`MdsSkripte/Auftrag.ps1` und werden von `Auf/scripts/Init.ps1` und `Post.ps1` benutzt.

- `$mdsWoy` ist bewusst ein Integer: Skripte können `if ($mdsWoy -ge 26)` oder `if (-not $mdsWoy)` prüfen.
  Der Wert 26 steht in `InitModule.ps1` als Konstante.
- Jeder Ordner lässt sich mit `DEV_<NAME>` umlenken (`DEV_HOME` → `$mdsDev`, `DEV_REPOS` → `$mdsRepos`,
  `DEV_ROOT` → `$mdsRoot`, `DEV_BIN` … `DEV_TEMP`); Regel siehe
  [MDS-Development.md](MDS-Development.md#umlenken-per-umgebungsvariable).
- Die C#-Klasse `xBase.BaseRoot` in NetCoreLib2026 verwendet dieselbe Logik.

## Befehle

| Befehl     | Zweck                                        | Datei            |
| ---------- | -------------------------------------------- | ---------------- |
| `go`       | in einen Ordner bzw. ein Repo springen       | `Navigation.ps1` |
| `mk`       | Programme eines Repos bauen (`Make.ps1`)     | `Navigation.ps1` |
| `run`      | Repo-Werkzeuge `scripts/_<Name>.ps1` starten | `Navigation.ps1` |
| `Show-Repos` | alle Repos mit GitHub-Name, letzter Änderung, Kurzbeschreibung | `Navigation.ps1` |
| `Show-Mds` | mds-Variablen strukturiert anzeigen          | `Tools.ps1`      |

`go`, `mk` und `run` sind kurze Kleinbuchstaben-Befehle für die tägliche Arbeit; sie folgen bewusst nicht dem
Verb-Substantiv-Schema.

### go – Sprung in Ordner

`go` ist eine **Funktion**, kein Alias: ein Alias kann keine Argumente verarbeiten. Groß- und Kleinschreibung des
Arguments spielt keine Rolle.

| Aufruf      | Ziel                                                         |
| ----------- | ------------------------------------------------------------ |
| `go`        | `$mdsDev`                                                    |
| `go dev`    | `$mdsDev`                                                    |
| `go repos`  | `$mdsRepos`                                                  |
| `go root`   | `$mdsRoot`                                                   |
| `go <Kurz>` | `$mdsRepos/<Kurz>` (z. B. `go net`), nur Ordner mit `.git`   |

- Die Namen `dev`, `repos` und `root` sind reserviert und dürfen kein Repo-Kurzname sein.
- Unter Windows führen `go`, `go dev` und `go repos` nach `C:\woyCode`, `go root` nach `D:\Dev\Root`
  (ohne Laufwerk D: nach `C:\Dev\Root`).
- Außer den festen Zielen springt `go` nur in Ordner unter `$mdsRepos`, die ein `.git` enthalten. Unter Windows
  sind damit die Laufzeitordner (`Bin`, `Config`, …) ausgeschlossen, die woy-Repos der Auftragsabwicklung aber
  erreichbar; unter macOS gibt es diese nicht.
- Die Tab-Vervollständigung der Kurznamen erfolgt über `Register-ArgumentCompleter`.
- Ein unbekanntes Ziel erzeugt eine Warnung mit der Liste der gültigen Ziele.
- Die Repo-Namen werden bei jedem Aufruf (auch bei jeder Tab-Vervollständigung) aus `$mdsRepos` gelesen, es gibt
  keine Liste. Unter Windows (flach) erscheinen dadurch auch `Bin`, `Config` … als Ziele.

### mk – Programme bauen

Jedes C#-Repo hat ein Verzeichnis `scripts/` mit **genau einem** Einstieg `Make.ps1`.

| Aufruf im Repo-Ordner (oder darunter) | Wirkung                             |
| ------------------------------------- | ----------------------------------- |
| `mk`                                  | alle Programme dieses Repos bauen   |
| `mk <Programm>`                       | nur dieses Programm bauen           |
| `mk +<Gruppen>`                       | alle Programme dieser Gruppen bauen |

| Aufruf von überall                    | Wirkung                                                    |
| ------------------------------------- | ---------------------------------------------------------- |
| `mk`                                  | außerhalb der Repos: Repos mit `scripts/Make.ps1` anzeigen |
| `mk <Repo>`                           | alle Programme des Repos bauen                             |
| `mk <Repo> <Programm>`                | nur dieses Programm bauen                                  |
| `mk <Repo> +<Gruppen>`                | alle Programme dieser Gruppen, z. B. `mk maui +dI`         |
| `mk <Repo> -List`                     | bekannte Programme des Repos anzeigen                      |
| `mk <Repo> <Programm> -OutDir <Pfad>` | Ausgabeordner für diesen Lauf                              |
| `mk <Repo> <Programm> -Package`       | macOS-MAUI: Installationspaket statt .app                  |

- `mk` ist eine Modulfunktion und funktioniert von jedem Ordner aus. Sie ruft `$mdsRepos/<Repo>/scripts/Make.ps1` auf.
- Steht man in einem Repo-Ordner, gilt dieses Repo; der erste Parameter ist dann das Programm (außer er ist selbst ein Repo-Name).
- macOS-MAUI (Mac Catalyst): Standard ist die direkt startbare `<Programm>.app` im Ausgabeordner (ersetzt die vorhandene,
  Start per Doppelklick oder `open`). Mit `-Package` entsteht stattdessen `<Programm>-<Version>.pkg` zum Weitergeben
  (installiert nach `/Applications`). `Clear-BinFolder` fasst Dateien in `*.app` nicht an (Signatur).
- `<Repo>` ist der Kurzname wie bei `go` (Groß-/Kleinschreibung egal, Tab-Vervollständigung).
- `Make.ps1` enthält oben eine Tabelle mit den Programmen des Repos (siehe Beispiel unten).
- Konfiguration: `$mdsConfig/<Programm>/`.
- Musterimplementierung mit allen Funktionen: `Maui/scripts/Make.ps1` (mit `Init.ps1` und `Post.ps1`).
- Nach dem Build werden aus dem Ausgabeordner entfernt: `*.pdb`, XML-Dokumentation, fremde Runtimes
  (`runtimes/*` außer der Ziel-RID) und Satellitensprachen außer `de`/`en`.
  Die genaue Liste steht zentral in `Clear-BinFolder`.

#### Ausgabeordner

Der Ausgabeordner wird in dieser Reihenfolge bestimmt:

1. Parameter `-OutDir` beim Aufruf (`mk maui TestTool -OutDir ~/Test`) – gilt nur für diesen Lauf.
2. Eintrag `OutDir` in der Programmtabelle von `Make.ps1`.
3. Standard: `$mdsBin/<Kurzname>/<Programm>/`, z. B. `~/Dev/Root/Bin/Net/TaskAPI/`.

Ein relativer `OutDir` gilt relativ zu `$mdsBin`; ein absoluter Pfad wird unverändert übernommen. Fehlt der
Ordner, legt `Make.ps1` ihn an.

```powershell
# 2026-11-02 Hubi/Claude: Programmtabelle (Auszug aus Maui/scripts/Make.ps1)
$Gruppen = @{ 'D' = 'Data'; 'I' = 'Invoice'; 'A' = 'Apps' }       # nur fuer die Anzeige
$Programme = [ordered]@{
    'AdminMAUI' = @{ Project = 'src/Desktop/AdminMAUI/AdminMAUI.csproj'; Group = 'D'; OutDir = 'Desktop' }  # -> $mdsBin/Desktop
    'MyInvoice' = @{ Project = 'src/Desktop/MyInvoice/MyInvoice.csproj'; Group = 'I'; OutDir = 'Desktop' }
    'DataApp'   = @{ Project = 'src/Apps/DataApp/DataApp.csproj'; Group = 'A' }                        # -> $mdsBin/Maui/DataApp
}
```

Schlüssel je Programm: `Project` (Pflicht; der frühere Name `Projekt` wird weiter verstanden), `Group`, `OutDir`,
`Nur` (`'Windows'`/`'MacOS'`), `Keep` (ab 8.2: Unterordner, die `Clear-BinFolder` nach dem Bauen zusätzlich
behält, z. B. `@('Template', 'Bilder', 'Log')` in einem gemeinsamen Bin-Ordner).

Baut ein Repo in einen eigenen Bin-Ordner (z. B. `C:\woyCode\Auf\Bin\Net10` statt `$mdsBin`), trägt `Make.ps1`
den absoluten Pfad als `OutDir` ein (siehe `Auf/scripts/Make.ps1`).

#### Gruppen

- `Group` ist genau ein Buchstabe, Groß-/Kleinschreibung egal. Die Gruppe steht in `-List` und in der Ausgabe je Programm.
- Auswahl mit `+` und einem oder mehreren Buchstaben: `mk maui +dI` baut die Gruppen Data und Invoice.
- Nicht `@`: PowerShell liest `@dI` als Splatting der Variablen `$dI` und übergibt nichts, `mk` würde dann alles bauen.
  `#` leitet einen Kommentar ein.
- Unbekannte Buchstaben brechen mit Fehlermeldung ab, gebaut wird dann nichts.

#### Init.ps1 und Post.ps1

Liegt `scripts/Init.ps1` bzw. `scripts/Post.ps1` im Repo, ruft `Invoke-Make` sie vor bzw. nach dem Bauen auf. Die
Ausgabe meldet jeweils „wird ausgeführt“ oder „nicht vorhanden – wird nicht ausgeführt“.
Das gilt nur, wenn alle Programme (ohne Argument) oder Gruppen (`+<Buchstaben>`) gebaut werden. Bei einem einzeln
angegebenen Programm (`mk maui Invoice`) laufen weder `Init.ps1` noch `Post.ps1`.

| Parameter    | Inhalt                                                               |
| ------------ | -------------------------------------------------------------------- |
| `-Auswahl`   | Argument des Aufrufs: leer, Programmname oder `+<Gruppen>`           |
| `-Gruppen`   | Buchstaben (groß) der gewählten Programme; ohne Auswahl alle Gruppen |
| `-Programme` | Namen der gewählten Programme                                        |
| `-Erfolg`    | nur `Post.ps1`: `$true`, wenn alle Programme gebaut wurden           |

Ein Fehler in `Init.ps1` (`throw`, `Write-Error`) bricht vor dem Bauen ab; `Post.ps1` läuft dann nicht.

#### Logdatei

Jeder Lauf (außer `-List`) wird per `Start-Transcript` in `<Repo>/.Log/` mitgeschrieben:
`yyyy-MM-dd_HHmmss_MakeOK.log` ohne Fehler, `yyyy-MM-dd_HHmmss_MakeErr.log` mit Fehler.

`.Log/` ist der eine Log-Ordner je Repo:

| Datei                           | Erzeugt von      | Inhalt                                                 |
| ------------------------------- | ---------------- | ------------------------------------------------------ |
| `yyyy-MM-dd_HHmmss_MakeOK.log`  | `Invoke-Make`    | gesamte Ausgabe eines `mk`-Laufs ohne Fehler           |
| `yyyy-MM-dd_HHmmss_MakeErr.log` | `Invoke-Make`    | dasselbe mit Fehler                                    |
| `LOG-<Projekt>.ps1`             | `Publish-DotNet` | letzter `dotnet`-Aufruf des Projekts (zum Nachstarten) |

Der Punkt verbirgt den Ordner im Finder (anzeigen mit ⇧⌘.), VS Code zeigt ihn. `.gitignore` enthält `**/.Log/`.

Wenn mehrere Programme in denselben Ordner geschrieben werden (z. B. alle Desktop-Programme nach
`$mdsBin/Desktop`), gilt:

- `Clear-BinFolder` darf dort nur Dateien des gerade gebauten Programms entfernen, nicht den ganzen Ordner leeren.
- Gemeinsame DLLs werden vom zuletzt gebauten Programm überschrieben. Die Programme in einem gemeinsamen Ordner
  müssen daher dieselben Paketversionen nutzen (zentral über `Directory.Packages.props`, wie in `Maui` vorhanden).
- Die bestehenden `Make-*.ps1` (z. B. `Net/scripts/Make-AufAPI.ps1`, `Maui/Make-Single.ps1`) gehen in `Make.ps1` auf.
  `Maui/Make-*.ps1` wandern dazu nach `Maui/scripts/`.

### run – Repo-Skripte ausführen

Neben `mk` (bauen) und `go` (springen) startet `run` eigene Skripte eines Repos, z. B. unter Windows das
Kopieren nach TEST-SRV oder SQL-SRV. Die Skripte liegen lokal im Repo unter `scripts/` und sind am **Präfix `_`**
erkennbar: `scripts/_<Name>.ps1`. Dateien ohne Präfix (z. B. `Make.ps1`, Hilfsskripte) bietet `run` nicht an.

| Aufruf                            | Wirkung                                                                            |
| --------------------------------- | ---------------------------------------------------------------------------------- |
| `run`                             | im Repo-Ordner: Skripte dieses Repos anzeigen; sonst alle Repos mit ihren Skripten |
| `run <Name> [Argumente]`          | im Repo-Ordner: `scripts/_<Name>.ps1` ausführen                                    |
| `run <Repo>` / `run <Repo> -List` | verfügbare Skripte des Repos anzeigen                                              |
| `run <Repo> <Name> [Argumente]`   | `scripts/_<Name>.ps1` des Repos ausführen, von überall                             |

- Alle weiteren Argumente gehen unverändert an das Skript, auch benannte: `run net Copy -Ziel TEST-SRV -Force`.
- **Globale Skripte:** `Mds/scripts/_*.ps1` gelten überall. Hat das aktuelle Repo kein passendes Skript oder
  steht man außerhalb der Repos (z. B. in Dev), nimmt `run` das Skript aus `Mds/scripts`. Ein gleichnamiges
  Skript des aktuellen Repos hat Vorrang (z. B. `Auf/scripts/_backup.ps1`).
- **Abkürzungen:** Eine eindeutige Abkürzung genügt (`run back` = `run backup`); ist sie mehrdeutig, meldet
  `run` die Treffer.
- Groß-/Kleinschreibung spielt keine Rolle; Tab vervollständigt Repos und (im Repo-Ordner) Skriptnamen.
- Wie bei `mk` gewinnt ein Repo-Name: Ein Skript sollte nicht so heißen wie ein Repo.
- `-List` gehört `run` selbst; ein run-Skript sollte deshalb keinen Parameter `-List` haben.
- Das Skript läuft im aktuellen Ordner; Pfade im Repo bildet es über `$PSScriptRoot`.

#### Vorhandene run-Skripte

| Repo | Aufruf                       | Skript                 | Zweck                                                                 |
| ---- | ---------------------------- | ---------------------- | --------------------------------------------------------------------- |
| Mds  | `run back[up] [Repo] [-Force] [-Verbose]` | `scripts/_backup.ps1` | global: Repo als `<Repo>_yyyyMMdd.zip` sichern – angegebenes Repo, sonst das aktuelle, außerhalb der Repos Mds; `-Force` erstellt ein vorhandenes Tagesarchiv neu |
| Mds  | `run mars [-Go]` | `scripts/_mars.ps1` | global, nur macOS: MARS bei Bedarf per Wake-on-LAN wecken (LAN `192.168.104.59`), hängende Freigaben `woyCode`/`woyAufInstall` lösen und neu einbinden; `-Go` wechselt nach `/Volumes/woyCode` |
| Auf  | `run auf auto [-MitDatenbank]` | `scripts/_auto.ps1`  | bauen (`mk auf`), lokal kopieren, woyControlCenter starten            |
| Auf  | `run auf copy [t\|s]`        | `scripts/_copy.ps1`    | Deck nach InstallDir: lokal, TEST-SRV, SQL-SRV                        |
| Auf  | `run auf version [-Verbose]` | `scripts/_version.ps1` | Versionen aus `Dateiliste.txt` an allen Stellen                       |
| Auf  | `run auf backup`             | `scripts/_backup.ps1`  | Repo als `Auf_yyyyMMdd.zip` sichern, Pfad und Größe ausgeben          |
| Auf  | `run auf desktop`            | `scripts/_desktop.ps1` | alle Desktop-Verknüpfungen der Auftragsabwicklung anlegen             |
| Net  | `run net nuget [Repo]`       | `scripts/_nuget.ps1`   | Net, Maui, Auf auf NuGet-Sicherheitslücken prüfen                     |

Die Auf-Skripte beschreibt [Auftragsabwicklung](#auftragsabwicklung-nur-windows), `run net nuget` die zentrale
Übersicht `C:\woyCode\Net\docs\NuGet-Sicherheit.md`.

### Show-Repos – Repos anzeigen

`Show-Repos` listet alle Repos unter `$mdsRepos` (Ordner mit `.git`), nach Name sortiert:

| Spalte         | Quelle                                                                  |
| -------------- | ----------------------------------------------------------------------- |
| `Name`         | Ordnername (Kurzname), z. B. `Mds`                                      |
| `Repo`         | GitHub-Name aus `git remote get-url origin`, z. B. `MdsTools`           |
| `Datum`        | letzter Commit (`git log -1`), `yyyy-MM-dd HH:mm`                       |
| `Geändert`     | `True`, wenn es nicht committete Änderungen gibt (`git status`)         |
| `Beschreibung` | erste Zeile der `README.md`, höchstens 80 Zeichen                       |

`Show-Repos -Full` (kurz `-F`) zeigt zusätzlich `Branch`, `Stand` gegenüber dem Upstream (`aktuell`, `vor 2`,
`zurueck 1`, ohne vorheriges `fetch`) und die `Remote`-URL. Beispiel: `Show-Repos | Where-Object Geändert`.

```text
Name Repo           Datum            Geändert Beschreibung
---- ----           -----            -------- ------------
Maui NetMauiApps    2026-11-03 21:53    False .NET-MAUI-Anwendungen für Windows und macOS
Mds  MdsTools       2026-11-03 21:53     True PowerShell-Modul MdsTools für die Multi-Entwicklungsumgebung (MDS)
```

**Konvention für die README.md:** Die erste Zeile jedes Repos lautet `# <Name> – <Kurzbeschreibung>` (höchstens
80 Zeichen). Fehlt der Teil nach dem Gedankenstrich, nimmt `Show-Repos` die erste Textzeile nach der Überschrift.
`.git/description` wird nicht verwendet: Die Datei wird weder versioniert noch geklont.

### Show-Mds – Variablen anzeigen

`Show-Mds` zeigt eine Kopfzeile (Modulversion, woy-Stand, PowerShell-Version, Betriebssystem) und je Variable eine
Zeile mit Wert, Quelle und – bei Ordnern – ob der Ordner existiert. Quelle ist `DEV_<NAME>`, wenn eine
Umgebungsvariable den Ordner umlenkt, sonst `Standard`. Die erste Zeile `System` zeigt, ob man unter Windows oder
macOS arbeitet. Nur unter Windows folgen am Ende `mdsWoySrc`, `mdsWoyBin` und `mdsWoyRun` (Quelle `Legacy (fest)`).

```text
*----  MdsTools 8.2.1 | woy 0 | PowerShell 7.6.9 | macOS  -------

Variable   Wert                          Quelle        Vorhanden
--------   ----                          ------        ---------
System     macOS                         IsMacOS
mdsVersion 8.2.1                         MdsTools.psd1
mdsWoy     0                             macOS
mdsDev     /Users/hubert/Dev             Standard      True
mdsRepos   /Users/hubert/Dev/Repos       Standard      True
…
```

Unter Windows zusätzlich:

```text
mdsWoySrc  C:\woyCode\Auf                Legacy (fest) True
mdsWoyBin  C:\woyCode\Auf\Bin            Legacy (fest) True
mdsWoyRun  D:\woySystems\Bin             Legacy (fest) True
```

Die Zeilen sind Objekte und lassen sich weiterverarbeiten, z. B. `Show-Mds | Where-Object Vorhanden -eq $false`.

`Show-Mds -Full` (kurz `-F`) gibt danach alle externen Befehle aus, nach Name sortiert: die exportierten
Funktionen des Moduls und unter Windows die globalen woy-/Auftrags-Funktionen aus `MdsSkripte`. Je Befehl
steht in `Variable` der Name, in `Wert` die Kurzbeschreibung (`.SYNOPSIS`, sonst der erste Satz des Kommentars
über der Funktion) und in `Quelle` die Datei.

```text
Write-Info     Gibt eine Info-Statuszeile aus.                              Output.ps1
go             Wechselt in einen Ordner.                                    Navigation.ps1
mk             Baut Programme eines Repos über $mdsRepos/<Repo>/scripts/…   Navigation.ps1
…
```

## Cmdlets und Funktionen

Grundlage ist die Exportliste von mdsPackage, ausgewertet mit einer Suche nach Aufrufen in den Repos
`Net`, `Maui`, `PHB`, in den globalen Skripten und in `mdsProfile.ps1`.

Die Tabelle verwendet bereits die neuen Namen (siehe [Umbenennungen](MdsTools-Migration.md#umbenennungen)).

| Funktion                                                         | Bisher in | Ziel             | Export | Begründung                                                                             |
| ---------------------------------------------------------------- | --------- | ---------------- | ------ | -------------------------------------------------------------------------------------- |
| `Write-Header`, `Write-Info`                                     | Base      | `Output.ps1`     | ja     | in Make-Skripten verwendet                                                             |
| `Write-Start`, `Write-Success`, `Write-Fail`                     | Base      | `Output.ps1`     | ja     | einheitliche Ausgabe für `Make.ps1`                                                    |
| `Publish-DotNet`, `Build-Project`, `Invoke-Make`                 | DevNet    | `Build.ps1`      | ja     | in Make-Skripten verwendet; Invoke-Make für scripts/Make.ps1                           |
| `Clear-BinFolder`                                                | FileIO    | `Build.ps1`      | ja     | in Make-Skripten verwendet                                                             |
| `Get-TargetFramework`, `Find-CsProj`                             | DevNet    | `Build.ps1`      | nein   | nur intern genutzt                                                                     |
| `Update-DotNet`, `Update-PowerShell`, `Show-PowerShell`          | Tools     | `Tools.ps1`      | ja     | interaktiv genutzt                                                                     |
| `Show-Mds`                                                       | neu       | `Tools.ps1`      | ja     | Anzeige der mds-Variablen                                                              |
| `go`, `mk`, `run`, `Show-Repos`                                  | neu       | `Navigation.ps1` | ja     | Befehle für die tägliche Arbeit                                                        |
| `Clear-CodeFolder`, `Clear-Target`, `Remove-Folder`              | FileIO    | `FileIO.ps1`     | ja     | interaktiv genutzt                                                                     |
| `Copy-FileWithCredential`, `Copy-FolderWithCredential`           | Common    | `Share.ps1`      | ja     | auch auf dem Mac nötig, siehe unten                                                    |
| `Copy-Folder`, `Remove-OldFile`, `Get-DevelopFiles`              | FileIO    | `FileIO.ps1`     | nein   | kein externer Aufruf gefunden                                                          |
| `Copy-ToZip`, `Copy-FileToZip`, `Export-FromZip`, `Get-ZipEntry` | Zip       | `Zip.ps1`        | ja     | allgemeine Hilfsfunktionen                                                             |
| `Resolve-MdsPath`                                                | Common    | `Common.ps1`     | nein   | wird durch die globalen Variablen ersetzt                                              |
| `Get-ProjectReference`, `Get-ExportedMember`                     | Common    | `Common.ps1`     | nein   | kein externer Aufruf gefunden                                                          |
| `Test-Package`                                                   | Common    | **entfällt**     | –      | gehört zum JSON-Verfahren, wird ab 8.2 nicht mehr unterstützt (E8)                     |
| `Write-Error`                                                    | –         | **entfällt**     | –      | eingebautes Cmdlet, darf nicht überschrieben werden                                    |
| `Backup-Develop`, `Get-OneDriveRoot`                             | FileIO    | `FileIO.ps1`     | ja     | waren als `global:` definiert; macOS ergänzt (OneDrive unter `~/Library/CloudStorage`) |

### Copy-FileWithCredential / Copy-FolderWithCredential

Beide Funktionen sind heute nur unter Windows lauffähig. Für den Einsatz auf dem Mac sind drei Änderungen nötig:

| Heute                                               | Neu                                                                                       |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Standard-Credential aus `Get-WoyCredential` (woy)   | `-Credential` ohne woy-Vorgabe; fehlt er, wird mit `Get-Credential` nachgefragt           |
| Verbindung zur Freigabe mit `net use` (nur Windows) | Windows: `net use`; macOS: `mount_smbfs` in einen temporären Ordner unter `$mdsRoot/Temp` |
| Freigabe nur als UNC-Pfad `\\server\share`          | zusätzlich `smb://server/share` (macOS-Schreibweise); beide werden intern umgerechnet     |

Die Verbindung wird nach dem Kopieren immer wieder getrennt, auch im Fehlerfall (`finally`).
Unter Windows kann `MdsSkripte` weiterhin die woy-Anmeldedaten übergeben.

## Auftragsabwicklung (nur Windows)

> **Stand:** Auf MARS eingerichtet: Bauen mit `mk auf`, Kopieren mit `run auf copy`. Stellen mit **TODO** sind
> noch offen.

Die Auftragsabwicklung (früher woy/mdsProfile) läuft nur unter Windows. Unter macOS wird nichts davon
geladen; `$mdsWoy` ist dort `0`. Entwicklungsroot ist `C:\woyCode`, Laufzeit-Root `D:\woySystems`.

### Voraussetzungen

| Punkt          | Wert / Prüfung                                                                                         |
| -------------- | ------------------------------------------------------------------------------------------------------ |
| Betriebssystem | Windows (MARS), `$IsWindows`                                                                           |
| woy-Stand      | `$mdsWoy` = `26` (Prüfung in Skripten: `if ($mdsWoy -ge 26)`)                                          |
| Basisordner    | `C:\woyCode` (flach, siehe [MDS-Development.md](MDS-Development.md#windows-mars-flach-unter-cwoycode)) |
| Legacy-Pfade   | `$mdsWoySrc`, `$mdsWoyBin`, `$mdsWoyRun` (siehe [Globale Variablen](#globale-variablen))               |
| Anmeldedaten   | `%USERPROFILE%\.woy\woy.env`                                                                           |
| Server         | TEST-SRV, SQL-SRV, je Freigabe `\\<Server>\woyAufInstall`                                              |

### Bauen: mk auf

`Auf/scripts/Make.ps1` enthält die Programmtabelle (früher `auftrag.mds`). Jeder Part der `.mds` ist eine Gruppe;
die Programme landen absolut in `$mdsWoyBin` (`C:\woyCode\Auf\Bin\<Ordner>`), nicht in `$mdsBin`.

| Gruppe        | Programme                                             | Ausgabe ($mdsWoyBin\…)   |
| ------------- | ----------------------------------------------------- | ------------------------ |
| R = Release   | Auf2000V26, TapiServer                                | `Net10`                  |
| A = Admin     | AdminRDM, AdminControl, woyArtImport, Lizenz, Monitor | `Admin`                  |
| S = ServiceNT | AufServiceNT, woyRest.ServiceHost                     | `ServiceNT`              |
| C = Control   | woyControlCenter                                      | `UpdateService`          |
| T = PSwoyTask | cmdAuftrag, cmdPrint                                  | `PowerShell\woyTask\Bin` |
| P = RepApp    | RepApp, Signatur                                      | `RepApp`                 |
| U = Update    | UpdateGuid, TestGuid                                  | `Update`                 |

`Keep` schützt die Unterordner `Template`, `Bilder`, `Log` und `Skripte` vor `Clear-BinFolder`.

`Init.ps1` und `Post.ps1` (früher `Auftrag_Pre.ps1`/`Auftrag_Post.ps1`) arbeiten **nur bei `mk auf` ohne
Auswahl**; bei `mk auf +r` oder einem einzelnen Programm geschieht dort nichts.

| Skript     | Inhalt                                                                                                 |
| ---------- | ------------------------------------------------------------------------------------------------------ |
| `Init.ps1` | Prozesse beenden (`Clear-WoyProcess`), `Net10`, `UpdateService`, `ServiceNT`, `Admin` löschen,         |
|            | `Version.cs` schreiben (`Write-WoyVersionCS`); ein Fehler bricht vor dem Bauen ab                      |
| `Post.ps1` | nur wenn alle Programme gebaut wurden: Bibliotheken, Schemastände, Bilder, woyTask-Paket kopieren,     |
|            | ZIPs ins Deck `UpdateService`, AufAPI/MyRepApp/MyArtikel/MyOrderApp aus `C:\woyCode\Net`,              |
|            | `Dateiliste.txt` (`Write-DateiListe`), `Backup-Develop`, Commit und Push (`git` direkt)                |

Die Hilfsfunktionen `Clear-WoyProcess`, `Write-WoyVersionCS` und `Write-DateiListe` stehen in
`MdsSkripte/Auftrag.ps1`.

### Laden

1. `Skripte/InitModule.ps1` erkennt Windows und lädt `MdsSkripte/InitMDS.ps1`.
2. `InitMDS.ps1` lädt zuerst `WoyEnv.ps1`, dann alle übrigen `MdsSkripte/*.ps1` in alphabetischer Reihenfolge.
3. Die Funktionen sind **global** definiert (`function global:…`), stehen also nicht in der Exportliste des
   Manifests und erscheinen nicht in `Get-Command -Module MdsTools`.

Neue Funktionen der Auftragsabwicklung kommen als eigene `*.ps1` nach `MdsSkripte/` (Anforderung A6) – sie
werden ohne weitere Eintragung geladen.

### Anmeldedaten: woy.env

Die woy.env ist eine rechnerlokale Datei mit Zeilen `KEY=VALUE`. Gesucht wird in dieser Reihenfolge:

1. Pfad in der Umgebungsvariablen `WOY_ENV_FILE`,
2. `%USERPROFILE%\.woy\woy.env`,
3. `.env` in der Wurzel dieses Repos (nur für die Entwicklung).

`Install.ps1` legt unter Windows `%USERPROFILE%\.woy\` an und kopiert die Repo-`.env` dorthin, wenn sie neuer ist;
`.env.example` wird als `woy.env.example` mitkopiert.

| Funktion                   | Zweck                                                             |
| -------------------------- | ----------------------------------------------------------------- |
| `Get-WoyValue <Key>`       | Einzelwert (kein Passwort), mit `-Default` für fehlende Schlüssel |
| `Get-WoyCredential <Name>` | `PSCredential` aus `WOY_<NAME>_USER` / `WOY_<NAME>_PASS`          |
| `Import-WoyEnv [-Refresh]` | woy.env einlesen (zwischengespeichert), mit `-Refresh` neu        |
| `Get-WoyEnvPath`           | Pfad der verwendeten woy.env                                      |

Steht bei User oder Passwort `*` oder `!`, fragt `Get-WoyCredential` interaktiv nach und merkt sich die Eingabe für
die Sitzung. Die Passwörter stehen bewusst im Klartext in der rechnerlokalen Datei (nie in Git).

```text
# woy.env (Beispiel, Werte erfunden)
WOY_SERVER_USER=DOMAIN\hubert
WOY_SERVER_PASS=*
```

Auf MARS benötigte Schlüssel:

| Schlüssel                            | Zweck                                       | Standard ohne Eintrag |
| ------------------------------------ | ------------------------------------------- | --------------------- |
| `WOY_SERVER_USER`, `WOY_SERVER_PASS` | Anmeldung an TEST-SRV und SQL-SRV           | –                     |
| `WOY_TESTSRV`                        | Adresse TEST-SRV (MARS: `192.168.50.28`)    | `TEST-SRV`            |
| `WOY_SQLSRV`                         | Adresse SQL-SRV (MARS: `192.168.50.17`)     | `SQL-SRV`             |

### Werkzeuge mit run

Rechner- und serverbezogene Abläufe liegen als `scripts/_<Name>.ps1` im jeweiligen Repo und werden mit
[`run`](#run--repo-skripte-ausführen) gestartet.

#### run auf copy – Installationsverzeichnis verteilen

`Auf/scripts/_copy.ps1` (aus `Publish-Auf2000` in mdsProfile.ps1) kopiert das Deck
`$mdsWoyBin\UpdateService` (entsteht bei `mk auf`) inkrementell in das `InstallDir` des Ziels. Der erste
Buchstabe des Ziels reicht.

| Aufruf           | Ziel                                                        |
| ---------------- | ----------------------------------------------------------- |
| `run auf copy`   | `D:\woySystems\InstallDir` (lokal auf MARS)                 |
| `run auf copy t` | `\\TEST-SRV\woyAufInstall\InstallDir`, dazu `Bin\RepApp`    |
| `run auf copy s` | `\\SQL-SRV\woyAufInstall\InstallDir`                        |

Für Freigaben meldet sich das Skript mit `Get-WoyCredential 'server'` an. Es definiert die globalen Funktionen
`Publish-Auf2000 [<Ziel>]` und `Get-WoyServerShare <Ziel>`, die danach in der Sitzung aufrufbar bleiben.

**TODO:** Kopieren vom Entwicklungsrechner nach TERRA (früher als `_Copy2Terra.ps1` vorgesehen).

#### run auf auto, version, desktop

| Aufruf                       | Skript         | Inhalt (früher in mdsProfile.ps1 / Make-MDS.ps1)                                        |
| ---------------------------- | -------------- | --------------------------------------------------------------------------------------- |
| `run auf auto`               | `_auto.ps1`    | `Make.ps1` (= `mk auf`), bei Erfolg `_copy.ps1` lokal, dann woyControlCenter als Admin  |
|                              |                | (`KEEPPID=<PID> OhneDBF`, mit `-MitDatenbank` `Installieren`) – ersetzt Make-MDS.ps1     |
| `run auf version`            | `_version.ps1` | Version aus `Dateiliste.txt`: Deck, lokal (InstallDir, Config), SQL-SRV, TEST-SRV        |
| `run auf desktop`            | `_desktop.ps1` | alle Desktop-Verknüpfungen: D@, D0–D5 auf die run-Skripte, C, M, T, S, R auf die         |
|                              |                | Programme in `$mdsWoyBin` (früher Install-DevLink/Install-ProgLink)                     |

`Get-WoyServerShare <t|s>` (UNC-Wurzel `\\<Server>\woyAufInstall`) steht in `MdsSkripte/Auftrag.ps1`.

#### run auf backup – Repo sichern

`Auf/scripts/_backup.ps1` ruft `Backup-Develop -Force -Verbose` für `$mdsWoySrc` auf: ein vorhandenes
Tagesarchiv `Auf_yyyyMMdd.zip` wird überschrieben, am Ende stehen Pfad und Größe der Ziel-ZIP.

`Backup-Develop` liefert ab 8.2 den **Pfad der Ziel-ZIP** (bisher `$true`/`$false`), bei Fehler `$null`. Ohne
`-Force` und mit vorhandenem Tagesarchiv bleibt das Archiv unverändert, zurück kommt sein Pfad.

### Deploy-Skripte

Die Deploy-Skripte in `Net/scripts/Windows` (`Make-TaskAPI`, `Make-RestSRV`, `Make-AufAPI`, `Make-My*`,
`Make-TaskScheduler`, `Make-Rebuild`) stoppen/starten Dienste und IIS und werden aus Programmen aufgerufen
(`TaskAdminConfig.RebuildScript`, `GlobalConfig.cs`). Sie gehen nicht in `Make.ps1` auf, sondern werden auf
MdsTools und die neuen Pfade umgestellt (siehe [MdsTools-Migration.md](MdsTools-Migration.md#umsetzung), Schritt 7).

**TODO:** Ergebnis der Umstellung je Skript.

### Einrichten und Testen auf MARS

- [ ] `Install.ps1` ausführen, neue Shell: `Show-Mds` zeigt `woy 26`, Dev/Repos `C:\woyCode`, Root `D:\Dev\Root`.
- [ ] `%USERPROFILE%\.woy\woy.env` vorhanden und vollständig (`Get-WoyEnvPath`, `Get-WoyValue …`).
- [ ] `Get-WoyCredential server` liefert eine Anmeldung.
- [ ] `go`, `mk`, `run` in `C:\woyCode` (flache Struktur) prüfen.
- [x] Bauen mit `mk auf` (Programmtabelle, `-List` geprüft); vollständiger Lauf mit Init/Post noch zu testen.
- [ ] Kopieren lokal mit `run auf copy`.
- [ ] Kopieren nach TEST-SRV mit `run auf copy t`.
- [ ] Kopieren nach SQL-SRV mit `run auf copy s`.
- [ ] Deploy-Skripte in `Net/scripts/Windows` mit MdsTools.
- [ ] **TODO:** weitere Besonderheiten.

## Offene Punkte

- Repo `MdsTools` auf GitHub ist noch leer: Erster Push von `Repos/Mds` steht aus (`git push -u origin main`).
- Die Kurzbefehle `2Net`, `2Maui` … und der Alias `zip` des alten Profils entfallen (`go` bzw. `Save-Develop`).
- Präfix für neue Cmdlets festlegen (z. B. `Mds`) – betrifft nur neue Funktionen, nicht die übernommenen.
- Logging: Format und Aufbewahrungsdauer der Dateien in `$mdsLogs`.
- `.env.example` (Vorlage für die woy.env) fehlt im Repo; `Install.ps1` erwartet sie.

