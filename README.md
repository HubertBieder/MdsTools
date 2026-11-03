# Mds – MdsTools

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

- einheitliche Verzeichnisstruktur und globale Variablen (`$mdsDev`, `$mdsRepos`, `$mdsBin`, …),
- schnelle Befehle für die tägliche Arbeit: `go` (springen), `mk` (bauen), `run` (Repo-Werkzeuge),
- Cmdlets zum Bauen und Veröffentlichen (`Publish-DotNet`, `Invoke-Make`), für Dateien, ZIP und SMB-Freigaben,
- unter Windows zusätzlich die woy- und Auftragsfunktionen.

## Dokumente

| Dokument                                       | Inhalt                                                                                                              |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [MDS-Development.md](MDS-Development.md)       | **Systematik**: Systeme, PowerShell 7, Verzeichnisstruktur macOS/Windows, `DEV_<NAME>`, Repos und ihre Konventionen |
| [MdsTools.md](MdsTools.md)                     | **Modul**: Aufbau, Variablen, `go`/`mk`/`run`/`Show-Mds`, Cmdlets, Auftragsabwicklung (Windows)                     |
| [MdsTools-Migration.md](MdsTools-Migration.md) | Ablösung von mdsPackage: Motivation, Entscheidungen, Umsetzung, Umbenennungen                                       |

## Schnellstart

Voraussetzung: PowerShell 7.6 oder neuer.

```powershell
git clone https://github.com/HubertBieder/MdsTools.git ~/Dev/Repos/Mds   # Windows: C:\woyCode\Mds
cd ~/Dev/Repos/Mds
./Install.ps1          # Modul, Profil und globale Skripte installieren
```

Danach in einer neuen Shell:

```powershell
Show-Mds               # Version, woy-Stand und alle Ordner anzeigen
go net                 # ins Repo Net springen
mk                     # im Repo-Ordner: alle Programme bauen
run                    # Werkzeuge des Repos (scripts/_*.ps1) anzeigen
run Copy -Ziel TEST-SRV
```

Ist noch das alte Modul mdsPackage installiert, bricht `Install.ps1` ab; vorher `./Uninstall.ps1` ausführen.

## Aufbau des Repos

```text
Mds/
   README.md                  # diese Einführung
   MDS-Development.md         # Systematik der Entwicklungsumgebung
   MdsTools.md                # Beschreibung des Moduls
   MdsTools-Migration.md      # Ablösung von mdsPackage
   Install.ps1 / Uninstall.ps1 / InstallHelper.ps1
   Modul/MdsTools/            # das Modul (Manifest, SkriptModule, MdsSkripte)
   Profile/profile.ps1        # wird nach $PROFILE kopiert
   Skripte/                   # globale Skripte (CloneAll, PushAll, …) → $mdsDev
   tests/                     # Pester-Tests
```

## Entwickeln und Testen

```powershell
Import-Module ./Modul/MdsTools -Force     # Modul aus dem Repo laden (ohne Installation)
Invoke-Pester ./tests
Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
```

Die Modulversion steht nur im Manifest `Modul/MdsTools/MdsTools.psd1` und ist auf allen Systemen gleich.
