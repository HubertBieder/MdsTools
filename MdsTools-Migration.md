# MdsTools – Ablösung von mdsPackage

> **MDS** = **M**ulti **D**evelopment **S**ystem

## Historie

| Datum      | Version | Autor                | Änderung                                                     |
| ---------- | ------- | -------------------- | ------------------------------------------------------------ |
| 2026-11-03 | 1.0     | Hubert Bieder/Claude | Aus MdsTools.md herausgelöst (Versionen 0.1–0.18 siehe dort) |

## Inhalt und Abgrenzung

Dieses Dokument hält fest, **warum und wie** MdsTools das alte Modul mdsPackage abgelöst hat: Motivation, Ziele,
Entscheidungen, Umsetzungsschritte, Abnahmekriterien und umbenannte Cmdlets. Es ist abgeschlossen, sobald
mdsPackage auf LUNA und MARS entfernt ist.

Das Modul selbst beschreibt [MdsTools.md](MdsTools.md), die Systematik [MDS-Development.md](MDS-Development.md).

## Motivation

Das PowerShell-7-Modul **mdsPackage** übernimmt bisher die Unterstützung der Entwicklung. Es ist historisch auf
Windows ausgerichtet und enthält viele Bezüge zur Infrastruktur des alten Auftragsprogramms woy. Zusätzlich wurde
ein JSON-basiertes Dateiformat eingeführt, mit dem ein Projekt beschrieben wird. Einziger Einsatzzweck dieses
Formats war die Auftragsabwicklung.

Das neue Modul **MdsTools** konzentriert sich auf die C#-Entwicklung unter macOS (LUNA) und Windows (MARS).
Die Erweiterungen für die Auftragsabwicklung werden nur unter Windows geladen, und zwar über das Skript
`InitMDS.ps1`.

## Ziele und Nicht-Ziele

### Ziele

- Ein installierbares PS7-Modul mit klarer, gut wartbarer Struktur.
- Gleiche Befehle auf macOS und Windows; Unterschiede (Verzeichnisstruktur, `$mdsWoy`) nur über `$IsWindows` / `$IsMacOS`.
- Konventionen statt Konfiguration (siehe [MDS-Development.md](MDS-Development.md)).
- Schneller Wechsel zwischen Repos (`go`), einheitliches Bauen von Programmen (`mk`) und Repo-Werkzeuge (`run`).

### Nicht-Ziele

- Kein JSON-Projektformat mehr (`Read-PackageDefinition`, `New-Package`, `Invoke-PackageBuild` u. a. entfallen).
- Kein Git-Wrapper im Modul (siehe [E4](#entscheidungen)).
- Keine Weiterentwicklung der woy-Funktionen – sie werden nur übernommen, damit sie unter Windows weiter laufen.
- mdsPackage und MdsTools werden **nie gleichzeitig** geladen.

## Entscheidungen

| Nr. | Frage                                  | Entscheidung / Vorschlag                                                                                                                                  | Status      |
| --- | -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| E1  | Startversion des Moduls                | **8.0.0** statt 6.0: mdsPackage steht bereits auf 7.0, eine niedrigere Version wirkt wie ein Rückschritt.                                                 | entschieden |
| E2  | Schreibweise des Dev-Ordners           | **`Dev`** (so ist es angelegt). MDS-Development.md ist angeglichen.                                                                                       | entschieden |
| E3  | Altes Repo mdsPackage                  | Wird ignoriert und gehört nicht zur Struktur. Sobald MdsTools funktioniert, wird `Repos/mdsPackage` entfernt.                                             | entschieden |
| E4  | Git-Wrapper entfernen?                 | **Ja.** `git` direkt verwenden; CloneAll/PushAll brauchen keinen Wrapper.                                                                                 | entschieden |
| E5  | Installation: kopieren oder verlinken? | **Kopieren** in den Benutzer-Modulpfad (wie bisher). Entwicklung über `Import-Module ./Modul/MdsTools -Force`.                                            | entschieden |
| E6  | Name des Bau-Skripts                   | **`scripts/Make.ps1`** (einheitlich zu `Make-*.ps1`), Aufruf über `mk`.                                                                                   | entschieden |
| E7  | Name des Aufräum-Skripts               | **`Uninstall.ps1`** statt `clear.ps1` (passend zu `Install.ps1`, kein Konflikt mit dem Befehl `clear`).                                                   | entschieden |
| E8  | JSON-Verfahren                         | Komplett nach `MdsSkripte` (nur Windows), im Modul selbst entfernen.                                                                                      | entschieden |
| E9  | `Update-PowerShell` vs. `UpdatePS.ps1` | Das Update erledigt das Modul (`Update-PowerShell`). `UpdatePS.ps1` entfällt.                                                                             | entschieden |
| E10 | Binärordner                            | Standard `$mdsBin/<Kurzname>/<Programm>/`; je Programm in `Make.ps1` oder per `-OutDir` übersteuerbar (siehe [Ausgabeordner](MdsTools.md#ausgabeordner)). | entschieden |
| E11 | Schlecht benannte Cmdlets              | Werden umbenannt (siehe [Umbenennungen](#umbenennungen)).                                                                                                 | entschieden |
| E12 | `Copy-*WithCredential`                 | Öffentlich im Modul, auch für macOS (siehe [MdsTools.md](MdsTools.md#copy-filewithcredential--copy-folderwithcredential)).                                | entschieden |

## Umsetzung

Stand 2026-10-31: Schritte 1, 2, 4, 5, 6, 8 und 9 erledigt, Schritt 7 zur Hälfte (siehe dort) und auf LUNA installiert; von Schritt 3 nur `InitMDS.ps1` und
`WoyEnv.ps1`. mdsPackage ist auf LUNA deinstalliert (Sicherung unter `~/Dev/Archiv/mdsPackage-Installation-2026-10-31`).

1. Gerüst anlegen: `Modul/MdsTools/` mit Manifest, Root-Modul und `InitModule.ps1`.
2. Funktionen gemäß der Tabelle in [MdsTools.md](MdsTools.md#cmdlets-und-funktionen) aus mdsPackage übernehmen und den Export im Manifest setzen.
3. `mdsProfile.ps1` (675 Zeilen) thematisch in einzelne Dateien unter `MdsSkripte/` aufteilen und `InitMDS.ps1` erstellen.
4. `go` und `mk` implementieren.
5. `Profile/profile.ps1` und `Install.ps1` auf MdsTools umstellen.
6. `Uninstall.ps1` erstellen:
   - entfernt `mdsPackage` und `MdsTools` aus allen Benutzer-Modulpfaden,
   - sichert `$PROFILE` vor jeder Änderung.
7. `Make.ps1` in `Net/scripts` und `Maui/scripts` einführen; alte `Make-*.ps1` danach entfernen.
   - Erledigt: `Make.ps1` in beiden Repos (Programmtabelle + `Invoke-Make` aus MdsTools). Ersetzt
     `Net/scripts/Make-All.ps1`, `Make-DKB.ps1`, `Maui/Make-MauiApps.ps1`, `Make-Single.ps1`.
   - Offen bis zur Umstellung von MARS: Die alten Skripte bleiben, solange MARS mdsPackage nutzt.
     Die Deploy-Skripte (`Make-TaskAPI`, `Make-RestSRV`, `Make-AufAPI`, `Make-My*`, `Make-TaskScheduler`,
     `Make-Rebuild`) gehen **nicht** in `Make.ps1` auf: Sie stoppen/starten Dienste und IIS und werden aus
     Programmen aufgerufen (`TaskAdminConfig.RebuildScript`, `GlobalConfig.cs`). Sie werden nur auf
     MdsTools und die neuen Pfade umgestellt. In Net liegen die Windows-Skripte unter `scripts/Windows`.
   Die alten Skripte rufen noch `Publish-NET` und `Build-Projects` auf und laufen mit MdsTools nicht mehr.
8. Pester-Tests für `go`, Pfadauflösung und Export-Liste schreiben.
   Erledigt: `tests/MdsTools.Tests.ps1` (Aufruf `Invoke-Pester ./tests`), läuft im Pester-TestDrive.
9. `UpdatePS.ps1` aus `Skripte/` und aus `$mdsDev` entfernen (E9).
10. Sobald MdsTools auf LUNA und MARS funktioniert: `Repos/mdsPackage` lokal entfernen und auf GitHub archivieren (E3).

## Abnahmekriterien

- `Install.ps1` läuft auf LUNA und MARS ohne Fehler.
- Danach gilt in einer neuen Shell:
  - `Get-Module MdsTools` zeigt die erwartete Version.
  - `go net` springt ins Repo `Net`.
  - `mk maui` baut alle Apps; Desktop-Programme landen gemeinsam in `Root/Bin/Desktop/`.
  - `Copy-FileWithCredential` kopiert auf LUNA und MARS eine Datei auf eine SMB-Freigabe.
- Unter macOS werden keine `MdsSkripte` geladen und keine Fehler ausgegeben.
- `Uninstall.ps1` hinterlässt weder mdsPackage noch MdsTools im Modulpfad.
- `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1` meldet keine Fehler.
- `Invoke-Pester ./tests` läuft ohne Fehler.

## Umbenennungen

Diese Cmdlets und Funktionen erhalten in MdsTools einen neuen Namen. Aliase für die alten Namen gibt es nicht,
da mdsPackage und MdsTools nie gleichzeitig geladen werden.

| Alter Name        | Neuer Name        | Grund                                                         |
| ----------------- | ----------------- | ------------------------------------------------------------- |
| `Build-Projects`  | `Build-Project`   | PowerShell empfiehlt Substantive im Singular                  |
| `Limit-Files`     | `Remove-OldFile`  | Zweck erkennbar: behält die neuesten n Dateien, löscht ältere |
| `Get-ZipEntries`  | `Get-ZipEntry`    | Singular                                                      |
| `Show-Powershell` | `Show-PowerShell` | Schreibweise                                                  |
| `Find-csProj`     | `Find-CsProj`     | Schreibweise                                                  |
| `Publish-NET`     | `Publish-DotNet`  | Schreibweise, einheitlich zu `Update-DotNet`                  |
| `GetLogDir`       | `Get-LogDir`      | Verb-Substantiv-Schema (intern)                               |
| `IsInPattern`     | `Test-InPattern`  | Verb-Substantiv-Schema (intern)                               |
| `IsMauiExe`       | `Test-MauiExe`    | Verb-Substantiv-Schema (intern)                               |

## Nicht übernommene Funktionen von mdsPackage

- **Git** (`GitUtil.psm1`: `Invoke-Commit`, `Invoke-Push`, `Show-Git*`, `Get-GitRepos` …): entfällt, siehe [E4](#entscheidungen).
- **JSON-Verfahren** (`New-Package`, `Read-PackageDefinition`, `Invoke-PackageBuild`, `Get-PackageTargetDirs`,
  `Show-MdsPackage`, `Get-MDS`): wandert nach `MdsSkripte` oder entfällt.
- **woy** (`Enable-WoyTls`, `Get-UncShareRoot`): wandert nach `MdsSkripte`.
- **Intern** (`Test-IsAdmin`, `Assert-Admin`, `Start-Spinner`, `Initialize-LogFile` …): werden mit übernommen,
  aber nicht exportiert.
