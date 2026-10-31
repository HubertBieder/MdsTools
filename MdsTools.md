# MDS Tools – Spezifikation

## Historie

| Datum      | Version | Autor                | Änderung                                                                                  |
| ---------- | ------- | -------------------- | ----------------------------------------------------------------------------------------- |
| 2026-10-31 | 0.1     | Hubert Bieder        | README formatiert, Historie ergänzt, Pfad relativ gesetzt                                 |
| 2026-10-31 | 0.2     | Hubert Bieder/Claude | Spezifikation korrigiert, Entscheidungen und offene Punkte ergänzt                        |
| 2026-10-31 | 0.3     | Hubert Bieder/Claude | Entscheidungen übernommen, Cmdlets umbenannt, Ausgabeordner wählbar                       |
| 2026-10-31 | 0.9     | Hubert Bieder/Claude | Schritt 7 (Teil): Invoke-Make, Make.ps1 in Net und Maui, *.app bleibt bei Clear-BinFolder |
| 2026-10-31 | 0.8     | Hubert Bieder/Claude | Schritt 6: Uninstall.ps1                                                                  |
| 2026-10-31 | 0.7     | Hubert Bieder/Claude | Globale Skripte auf Repo-Tabelle und Kurznamen umgestellt                                 |
| 2026-10-31 | 0.6     | Hubert Bieder/Claude | Schritt 5: Install.ps1 und Profil auf MdsTools umgestellt, UpdatePS.ps1 entfernt          |
| 2026-10-31 | 0.5     | Hubert Bieder/Claude | Umsetzung Schritte 1, 2 und 4; SkriptModule als *.ps1; Backup-Develop gefunden            |
| 2026-10-31 | 0.4     | Hubert Bieder/Claude | E3 und E9 entschieden                                                                     |

---

**Autor:** Hubert Bieder

> **MDS** = **M**ulti **D**evelopment **S**ystem

## Relevante Dokumente

- [README.md](README.md)
- [NewToolMDS.md](NewToolMDS.md) *(existiert noch nicht)*
- [MDS-Development.md](../../MDS-Development.md)

## Begriffe

| Begriff       | Bedeutung                                                                  |
| ------------- | -------------------------------------------------------------------------- |
| mdsPackage    | Bisheriges PowerShell-Modul unter `~/Dev/Repos/mdsPackage` (Version 7.0)   |
| MdsTools      | Neues Modul, Nachfolger von mdsPackage, Repo-Ordner `~/Dev/Repos/Mds`      |
| woy           | Altes Auftragsprogramm samt Infrastruktur – wird nicht weiterentwickelt    |
| Auftrag (MDS) | Auftragsabwicklung auf Basis von woy/mdsProfile – **nur unter Windows**    |
| Kurzname      | Ordnername eines Repos unter `Repos/` (z. B. `Net`, `Maui`), Ziel für `go` |

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
- Identisches Verhalten auf macOS und Windows (Pfade über `$HOME`, OS-Erkennung über `$IsWindows` / `$IsMacOS`).
- Konventionen statt Konfiguration (siehe [MDS-Development.md](../../MDS-Development.md)).
- Schneller Wechsel zwischen Repos (`go`) und einheitliches Bauen von Programmen (`mk`).

### Nicht-Ziele

- Kein JSON-Projektformat mehr (`Read-PackageDefinition`, `New-Package`, `Invoke-PackageBuild` u. a. entfallen).
- Kein Git-Wrapper im Modul (siehe [E4](#entscheidungen)).
- Keine Weiterentwicklung der woy-Funktionen – sie werden nur übernommen, damit sie unter Windows weiter laufen.
- mdsPackage und MdsTools werden **nie gleichzeitig** geladen.

## Anforderungen

| Nr. | Anforderung                                                                                                                                                 |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1  | Nur PowerShell 7, mindestens **7.6** (`PowerShellVersion = '7.6'` im Manifest, `#Requires -Version 7.6`).                                                   |
| A2  | Die Modulversion wird **zentral** im Manifest `MdsTools.psd1` festgelegt; `$mdsVersion` liest sie aus.                                                      |
| A3  | `Install.ps1` in der Repo-Root installiert das Modul, das Profil und die globalen Skripte.                                                                  |
| A4  | `Uninstall.ps1` in der Repo-Root entfernt alte Installationen von mdsPackage und MdsTools.                                                                  |
| A5  | Übernommene Cmdlets behalten ihren Namen, außer den Einträgen unter [Umbenennungen](#umbenennungen).                                                        |
| A6  | Funktionen für woy, Auftragsabwicklung und das JSON-Verfahren kommen als einzelne `*.ps1` nach `MdsSkripte`.                                                |
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
   MdsTools.md                 # diese Spezifikation
   Install.ps1                 # Installation (analog mdsPackage)
   Uninstall.ps1               # entfernt alte Installationen (bisher "clear.ps1")
   InstallHelper.ps1           # gemeinsame Pfad-Helfer für Install.ps1 und Uninstall.ps1
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
            Tools.ps1          # Update-/Show-PowerShell, Update-DotNet
            Navigation.ps1     # go, mk
         MdsSkripte/           # *.ps1 – woy/Auftrag (aus mdsProfile.ps1), nur Windows
            InitMDS.ps1        # lädt alle MdsSkripte
            WoyEnv.ps1         # Get-WoyValue, Get-WoyCredential (woy.env)
   Profile/
      profile.ps1              # wird nach $PROFILE kopiert
   Skripte/                    # globale Skripte (CloneAll, PushAll, …)
   tests/                      # Pester-Tests
```

`Skripte/` wird von `Install.ps1` nach `$mdsDev` kopiert, aber nur, wenn die Quelle neuer ist.

## Initialisierung und Ablauf

1. `$PROFILE` (aus `Profile/profile.ps1`) führt `Import-Module MdsTools` aus.
2. `Skripte/InitModule.ps1` setzt die globalen Variablen, legt fehlende `Root/`-Unterordner an und nimmt
   `$mdsBin` in den `PATH` auf.
3. Nur unter Windows wird `MdsSkripte/InitMDS.ps1` geladen; es stellt die woy- und Auftrags-Cmdlets bereit.
4. Das Profil gibt eine kurze Statuszeile aus (Modulversion, PS-Version, OS).

> Das aktuelle `Profile/profile.ps1` importiert noch `mdsPackage` (Zeile 47) und muss umgestellt werden.

## Globale Variablen

| Variable      | Wert (LUNA)                 | Bedeutung                                |
| ------------- | --------------------------- | ---------------------------------------- |
| `$mdsVersion` | aus Manifest, z. B. `8.0.0` | Modulversion (nicht doppelt pflegen)     |
| `$mdsDev`     | `/Users/hubert/Dev`         | Einstiegspunkt, Ziel von `go dev`        |
| `$mdsRepos`   | `$mdsDev/Repos`             | Git-Clones                               |
| `$mdsRoot`    | `$mdsDev/Root`              | Laufzeitumgebung, Ziel von `go root`     |
| `$mdsBin`     | `$mdsRoot/Bin`              | gebaute Programme, steht im `PATH`       |
| `$mdsConfig`  | `$mdsRoot/Config`           | Konfiguration je Programm                |
| `$mdsData`    | `$mdsRoot/Data`             | Laufzeitdaten der Services               |
| `$mdsLogs`    | `$mdsRoot/Logs`             | Protokolle                               |
| `$mdsTemp`    | `$mdsRoot/Temp`             | Zwischendateien, Freigabe-Mounts (macOS) |

Alle Werte werden aus `$HOME` abgeleitet und lassen sich über `$env:DEV_ROOT` übersteuern. Es gibt keine fest
eingetragenen Pfade.

## Befehle

### go – Sprung in Ordner

`go` ist eine **Funktion**, kein Alias: ein Alias kann keine Argumente verarbeiten. Groß- und Kleinschreibung des
Arguments spielt keine Rolle.

| Aufruf      | Ziel                                |
| ----------- | ----------------------------------- |
| `go`        | `$mdsDev`                           |
| `go dev`    | `$mdsDev`                           |
| `go root`   | `$mdsRoot`                          |
| `go <Kurz>` | `$mdsRepos/<Kurz>` (z. B. `go net`) |

- Die Namen `dev` und `root` sind reserviert und dürfen kein Repo-Kurzname sein.
- Die Tab-Vervollständigung der Kurznamen erfolgt über `Register-ArgumentCompleter`.
- Ein unbekanntes Ziel erzeugt eine Warnung mit der Liste der gültigen Ziele.

### mk – Programme bauen

Jedes C#-Repo hat ein Verzeichnis `scripts/` mit **genau einem** Einstieg `Make.ps1`.

| Aufruf          | Wirkung                                  |
| --------------- | ---------------------------------------- |
| `mk`            | alle Programme des aktuellen Repos bauen |
| `mk <Programm>` | nur dieses Programm bauen                |
| `mk -List`      | bekannte Programme anzeigen              |

- `mk` ist eine Modulfunktion. Sie sucht vom aktuellen Ordner aus die Git-Root und ruft dort `scripts/Make.ps1` auf.
- `Make.ps1` enthält oben eine Tabelle mit den Programmen des Repos (siehe Beispiel unten).
- Konfiguration: `$mdsConfig/<Programm>/`.
- Nach dem Build werden aus dem Ausgabeordner entfernt: `*.pdb`, XML-Dokumentation, fremde Runtimes
  (`runtimes/*` außer der Ziel-RID) und Satellitensprachen außer `de`/`en`.
  Die genaue Liste steht zentral in `Clear-BinFolder`.

#### Ausgabeordner

Der Ausgabeordner wird in dieser Reihenfolge bestimmt:

1. Parameter `-OutDir` beim Aufruf (`mk MyApp -OutDir ~/Test`) – gilt nur für diesen Lauf.
2. Eintrag `OutDir` in der Programmtabelle von `Make.ps1`.
3. Standard: `$mdsBin/<Kurzname>/<Programm>/`, z. B. `~/Dev/Root/Bin/Net/TaskAPI/`.

Ein relativer `OutDir` gilt relativ zu `$mdsBin`; ein absoluter Pfad wird unverändert übernommen. Fehlt der
Ordner, legt `Make.ps1` ihn an.

```powershell
# 2026-10-31 Hubi/Claude: Programmtabelle in Maui/scripts/Make.ps1
$Programme = [ordered]@{
    'MyArtikel' = @{ Projekt = 'src/MyArtikel/MyArtikel.csproj'; OutDir = 'Desktop' }  # -> $mdsBin/Desktop
    'MyRepApp'  = @{ Projekt = 'src/MyRepApp/MyRepApp.csproj';   OutDir = 'Desktop' }
    'TaskSched' = @{ Projekt = 'src/TaskSched/TaskSched.csproj' }                       # -> $mdsBin/Maui/TaskSched
}
```

Wenn mehrere Programme in denselben Ordner geschrieben werden (z. B. alle Desktop-Programme nach
`$mdsBin/Desktop`), gilt:

- `Clear-BinFolder` darf dort nur Dateien des gerade gebauten Programms entfernen, nicht den ganzen Ordner leeren.
- Gemeinsame DLLs werden vom zuletzt gebauten Programm überschrieben. Die Programme in einem gemeinsamen Ordner
  müssen daher dieselben Paketversionen nutzen (zentral über `Directory.Packages.props`, wie in `Maui` vorhanden).
- Die bestehenden `Make-*.ps1` (z. B. `Net/scripts/Make-AufAPI.ps1`, `Maui/Make-Single.ps1`) gehen in `Make.ps1` auf.
  `Maui/Make-*.ps1` wandern dazu nach `Maui/scripts/`.

## Cmdlets und Funktionen

Grundlage ist die Exportliste von mdsPackage, ausgewertet mit einer Suche nach Aufrufen in den Repos
`Net`, `Maui`, `PHB`, in den globalen Skripten und in `mdsProfile.ps1`.

Die Tabelle verwendet bereits die neuen Namen (siehe [Umbenennungen](#umbenennungen)).

| Funktion                                                         | Bisher in | Ziel         | Export | Begründung                                                                             |
| ---------------------------------------------------------------- | --------- | ------------ | ------ | -------------------------------------------------------------------------------------- |
| `Write-Header`, `Write-Info`                                     | Base      | `Output.ps1` | ja     | in Make-Skripten verwendet                                                             |
| `Write-Start`, `Write-Success`, `Write-Fail`                     | Base      | `Output.ps1` | ja     | einheitliche Ausgabe für `Make.ps1`                                                    |
| `Publish-DotNet`, `Build-Project`                                | DevNet    | `Build.ps1`  | ja     | in Make-Skripten verwendet                                                             |
| `Clear-BinFolder`                                                | FileIO    | `Build.ps1`  | ja     | in Make-Skripten verwendet                                                             |
| `Get-TargetFramework`, `Find-CsProj`                             | DevNet    | `Build.ps1`  | nein   | nur intern genutzt                                                                     |
| `Update-DotNet`, `Update-PowerShell`, `Show-PowerShell`          | Tools     | `Tools.ps1`  | ja     | interaktiv genutzt                                                                     |
| `Clear-CodeFolder`, `Clear-Target`, `Remove-Folder`              | FileIO    | `FileIO.ps1` | ja     | interaktiv genutzt                                                                     |
| `Copy-FileWithCredential`, `Copy-FolderWithCredential`           | Common    | `Share.ps1`  | ja     | auch auf dem Mac nötig, siehe unten                                                    |
| `Copy-Folder`, `Remove-OldFile`, `Get-DevelopFiles`              | FileIO    | `FileIO.ps1` | nein   | kein externer Aufruf gefunden                                                          |
| `Copy-ToZip`, `Copy-FileToZip`, `Export-FromZip`, `Get-ZipEntry` | Zip       | `Zip.ps1`    | ja     | allgemeine Hilfsfunktionen                                                             |
| `Resolve-MdsPath`                                                | Common    | `Common.ps1` | nein   | wird durch die globalen Variablen ersetzt                                              |
| `Get-ProjectReference`, `Get-ExportedMember`                     | Common    | `Common.ps1` | nein   | kein externer Aufruf gefunden                                                          |
| `Test-Package`                                                   | Common    | `MdsSkripte` | –      | gehört zum JSON-Verfahren (E8)                                                         |
| `Write-Error`                                                    | –         | **entfällt** | –      | eingebautes Cmdlet, darf nicht überschrieben werden                                    |
| `Backup-Develop`, `Get-OneDriveRoot`                             | FileIO    | `FileIO.ps1` | ja     | waren als `global:` definiert; macOS ergänzt (OneDrive unter `~/Library/CloudStorage`) |

### Copy-FileWithCredential / Copy-FolderWithCredential

Beide Funktionen sind heute nur unter Windows lauffähig. Für den Einsatz auf dem Mac sind drei Änderungen nötig:

| Heute                                               | Neu                                                                                       |
| --------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Standard-Credential aus `Get-WoyCredential` (woy)   | `-Credential` ohne woy-Vorgabe; fehlt er, wird mit `Get-Credential` nachgefragt           |
| Verbindung zur Freigabe mit `net use` (nur Windows) | Windows: `net use`; macOS: `mount_smbfs` in einen temporären Ordner unter `$mdsRoot/Temp` |
| Freigabe nur als UNC-Pfad `\\server\share`          | zusätzlich `smb://server/share` (macOS-Schreibweise); beide werden intern umgerechnet     |

Die Verbindung wird nach dem Kopieren immer wieder getrennt, auch im Fehlerfall (`finally`).
Unter Windows kann `MdsSkripte` weiterhin die woy-Anmeldedaten übergeben.

Weitere Funktionen von mdsPackage, die nicht in der bisherigen Liste standen:

- **Git** (`GitUtil.psm1`: `Invoke-Commit`, `Invoke-Push`, `Show-Git*`, `Get-GitRepos` …): entfällt, siehe [E4](#entscheidungen).
- **JSON-Verfahren** (`New-Package`, `Read-PackageDefinition`, `Invoke-PackageBuild`, `Get-PackageTargetDirs`,
  `Show-MdsPackage`, `Get-MDS`): wandert nach `MdsSkripte` oder entfällt.
- **woy** (`Enable-WoyTls`, `Get-UncShareRoot`): wandert nach `MdsSkripte`.
- **Intern** (`Test-IsAdmin`, `Assert-Admin`, `Start-Spinner`, `Initialize-LogFile` …): werden mit übernommen,
  aber nicht exportiert.

## Entscheidungen

| Nr. | Frage                                  | Entscheidung / Vorschlag                                                                                                                       | Status      |
| --- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| E1  | Startversion des Moduls                | **8.0.0** statt 6.0: mdsPackage steht bereits auf 7.0, eine niedrigere Version wirkt wie ein Rückschritt.                                      | entschieden |
| E2  | Schreibweise des Dev-Ordners           | **`Dev`** (so ist es angelegt). MDS-Development.md ist angeglichen.                                                                            | entschieden |
| E3  | Altes Repo mdsPackage                  | Wird ignoriert und gehört nicht zur Struktur. Sobald MdsTools funktioniert, wird `Repos/mdsPackage` entfernt.                                  | entschieden |
| E4  | Git-Wrapper entfernen?                 | **Ja.** `git` direkt verwenden; CloneAll/PushAll brauchen keinen Wrapper.                                                                      | entschieden |
| E5  | Installation: kopieren oder verlinken? | **Kopieren** in den Benutzer-Modulpfad (wie bisher). Entwicklung über `Import-Module ./Modul/MdsTools -Force`.                                 | entschieden |
| E6  | Name des Bau-Skripts                   | **`scripts/Make.ps1`** (einheitlich zu `Make-*.ps1`), Aufruf über `mk`.                                                                        | entschieden |
| E7  | Name des Aufräum-Skripts               | **`Uninstall.ps1`** statt `clear.ps1` (passend zu `Install.ps1`, kein Konflikt mit dem Befehl `clear`).                                        | entschieden |
| E8  | JSON-Verfahren                         | Komplett nach `MdsSkripte` (nur Windows), im Modul selbst entfernen.                                                                           | entschieden |
| E9  | `Update-PowerShell` vs. `UpdatePS.ps1` | Das Update erledigt das Modul (`Update-PowerShell`). `UpdatePS.ps1` entfällt.                                                                  | entschieden |
| E10 | Binärordner                            | Standard `$mdsBin/<Kurzname>/<Programm>/`; je Programm in `Make.ps1` oder per `-OutDir` übersteuerbar (siehe [Ausgabeordner](#ausgabeordner)). | entschieden |
| E11 | Schlecht benannte Cmdlets              | Werden umbenannt (siehe [Umbenennungen](#umbenennungen)).                                                                                      | entschieden |
| E12 | `Copy-*WithCredential`                 | Öffentlich im Modul, auch für macOS (siehe [oben](#copy-filewithcredential--copy-folderwithcredential)).                                       | entschieden |

## Umsetzung

Stand 2026-10-31: Schritte 1, 2, 4, 5, 6 und 9 erledigt, Schritt 7 zur Hälfte (siehe dort) und auf LUNA installiert; von Schritt 3 nur `InitMDS.ps1` und
`WoyEnv.ps1`. mdsPackage ist auf LUNA deinstalliert (Sicherung unter `~/Dev/Archiv/mdsPackage-Installation-2026-10-31`).

1. Gerüst anlegen: `Modul/MdsTools/` mit Manifest, Root-Modul und `InitModule.ps1`.
2. Funktionen gemäß der Tabelle oben aus mdsPackage übernehmen und den Export im Manifest setzen.
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
     MdsTools und die neuen Pfade umgestellt.
   Die alten Skripte rufen noch `Publish-NET` und `Build-Projects` auf und laufen mit MdsTools nicht mehr.
8. Pester-Tests für `go`, Pfadauflösung und Export-Liste schreiben.
9. `UpdatePS.ps1` aus `Skripte/` und aus `$mdsDev` entfernen (E9).
10. Sobald MdsTools auf LUNA und MARS funktioniert: `Repos/mdsPackage` lokal entfernen und auf GitHub archivieren (E3).

## Abnahmekriterien

- `Install.ps1` läuft auf LUNA und MARS ohne Fehler.
- Danach gilt in einer neuen Shell:
  - `Get-Module MdsTools` zeigt die erwartete Version.
  - `go net` springt ins Repo `Net`.
  - `mk` baut im Repo `Maui` alle Apps; Desktop-Programme landen gemeinsam in `Root/Bin/Desktop/`.
  - `Copy-FileWithCredential` kopiert auf LUNA und MARS eine Datei auf eine SMB-Freigabe.
- Unter macOS werden keine `MdsSkripte` geladen und keine Fehler ausgegeben.
- `Uninstall.ps1` hinterlässt weder mdsPackage noch MdsTools im Modulpfad.
- `Invoke-ScriptAnalyzer -Recurse` meldet keine Fehler.

## Offene Punkte

- `NewToolMDS.md` anlegen oder Verweis entfernen.
- Architektur der Mac-Builds: `Publish-DotNet` baut fest für `osx-x64` bzw. `maccatalyst-x64`, LUNA ist ein Apple-Silicon-Mac (arm64).
- PSScriptAnalyzer installieren (Abnahmekriterium).
- MAUI-Workloads auf LUNA fehlen (`dotnet workload restore` in `Repos/Maui`), `mk` in `Maui` baut daher auf dem Mac noch nicht.
- Repo `MdsTools` auf GitHub ist noch leer: Erster Push von `Repos/Mds` steht aus (`git push -u origin main`).
- Die Kurzbefehle `2Net`, `2Maui` … und der Alias `zip` des alten Profils entfallen (`go` bzw. `Save-Develop`).
- Präfix für neue Cmdlets festlegen (z. B. `Mds`) – betrifft nur neue Funktionen, nicht die übernommenen.
- Logging: Format und Aufbewahrungsdauer der Dateien in `$mdsLogs`.

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
