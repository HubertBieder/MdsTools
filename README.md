# Mds – PowerShell-Modul MdsTools für die Multi-Entwicklungsumgebung (MDS)

> **MDS** = **M**ulti **D**evelopment **S**ystem

**Autor:** Hubert Bieder

## Historie

| Datum      | Version | Autor                | Änderung                                                  |
| ---------- | ------- | -------------------- | --------------------------------------------------------- |
| 2026-10-31 | 0.1     | Hubert Bieder        | README formatiert, Historie ergänzt, Pfad relativ gesetzt |
| 2026-11-03 | 0.2     | Hubert Bieder/Claude | Neu als Einführung in das Repo                            |

## Worum es geht

Dieses Repository (GitHub: **MdsTools**, lokaler Ordner **Mds**) enthält das PowerShell-7-Modul **MdsTools**. Es
unterstützt die Entwicklung von C#- (und Python-) Systemen auf **macOS (LUNA)** und **Windows (MARS)** mit
denselben Befehlen:

- einheitliche Verzeichnisstruktur und globale Variablen (`$mdsRepos`, `$mdsRoot`, `$mdsBin`, …),
- schnelle Befehle für die tägliche Arbeit: `go` (springen), `mk` (bauen), `run` (Repo-Werkzeuge),
- Cmdlets zum Bauen und Veröffentlichen (`Publish-DotNet`, `Invoke-Make`), für Dateien, ZIP und SMB-Freigaben,
- unter Windows zusätzlich die woy- und Auftragsfunktionen.

## Dokumente

| Dokument                                       | Inhalt                                                                                                              |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [MDS-Development.md](MDS-Development.md)       | **Systematik**: Systeme, PowerShell 7, Verzeichnisstruktur macOS/Windows, `DEV_<NAME>`, Repos und ihre Konventionen |
| [MdsTools.md](MdsTools.md)                     | **Modul**: Aufbau, Variablen, `go`/`mk`/`run`/`Show-Mds`, Cmdlets, Auftragsabwicklung (Windows)                     |
| [Luna.md](Luna.md) / [Mars.md](Mars.md)        | **Offene Aufgaben**: erst allgemein und LUNA, danach MARS in einem Stück                                            |
| [Anaconda.md](Anaconda.md)                     | **Python**: Anaconda-Installation macOS/Windows, Umgebungen py314/py313/py315, Profil-Befehle `py`/`pyb`            |

## Schnellstart

Voraussetzung: PowerShell 7.6 oder neuer. Unter Windows prüft bzw. installiert `Update-PowerShell7.cmd`
(Doppelklick, läuft in Windows PowerShell 5.1 als Administrator) die PowerShell 7:

| Aufruf                                   | Wirkung                                                                 |
| ---------------------------------------- | ----------------------------------------------------------------------- |
| `Update-PowerShell7.cmd`                 | keine PowerShell 7: Warnung, neueste installieren; sonst Version und ob es eine neuere gibt |
| `Update-PowerShell7.cmd -Last`           | in jedem Fall die neueste Version installieren                          |
| `Update-PowerShell7.cmd -Version 7.6.4`  | diese Version installieren                                              |

Ohne Administratorrechte bricht `Update-PowerShell7.ps1` nach einer Warnung ab.

```powershell
git clone https://github.com/HubertBieder/MdsTools.git ~/Repos/Mds   # Windows: C:\woyCode\Mds
cd ~/Repos/Mds
./Install.ps1          # Modul, Profil und globale Skripte installieren
```

Danach in einer neuen Shell:

```powershell
Show-Mds               # Version, woy-Stand und alle Ordner anzeigen
Show-Mds -F            # zusätzlich alle Befehle des Moduls
Show-Repos             # alle Repos: GitHub-Name, letzte Änderung, Kurzbeschreibung
Show-Alias             # Kurzbefehle: go, mk, run, push, clone, Show-*
push                   # alle Repos committen und pushen (PushAll.ps1)
clone                  # alle Repos klonen bzw. aktualisieren (CloneAll.ps1); Mds geändert → Install.ps1
go                     # nach Repos springen (auch go dev, go home; go root: nach Root)
go net                 # ins Repo Net springen
mk                     # im Repo-Ordner: alle Programme bauen
run                    # Werkzeuge des Repos (scripts/_*.ps1) anzeigen
run Copy -Ziel TEST-SRV
```

## Aufbau des Repos

```text
Mds/
   README.md                  # diese Einführung
   MDS-Development.md         # Systematik der Entwicklungsumgebung
   MdsTools.md                # Beschreibung des Moduls
   Luna.md / Mars.md          # offene Aufgaben: erst Luna, dann Mars
   Anaconda.md                # Python: Anaconda-Installation und Umgebungen
   Install.ps1 / Uninstall.ps1 / InstallHelper.ps1
   Update-PowerShell7.ps1/.cmd   # nur Windows: PowerShell 7 prüfen/installieren (läuft unter 5.1)
   Modul/MdsTools/            # das Modul (Manifest, SkriptModule, MdsSkripte)
   Modul/Skripte/             # globale Skripte (CloneAll, PushAll, …) → $mdsRepos
   Profile/profile.ps1        # wird nach $PROFILE kopiert
   scripts/                   # globale run-Skripte (run backup)
   tests/                     # Pester-Tests
```

## Entwickeln und Testen

```powershell
Import-Module ./Modul/MdsTools -Force     # Modul aus dem Repo laden (ohne Installation)
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

Die Modulversion steht nur im Manifest `Modul/MdsTools/MdsTools.psd1` und ist auf allen Systemen gleich.
