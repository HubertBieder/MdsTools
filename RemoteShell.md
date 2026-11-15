# Remote-Shell – PowerShell auf den Rechnern mit Auftragsabwicklung

**Autor:** Hubert Bieder

## Historie

| Datum      | Version | Autor                | Änderung                                                                  |
| ---------- | ------- | -------------------- | ------------------------------------------------------------------------- |
| 2026-11-15 | 0.1     | Hubert Bieder/Claude | Neu: Schnittstelle, Einrichtung, Befehle, Update; Aufrufe von LUNA aus    |

## Worum es geht

Der Dienst **AufServiceNT** der Auftragsabwicklung bietet eine PowerShell-Sitzung über das Netz an. Damit
lassen sich MARS, TEST-SRV und SQL-SRV (PROD) von jedem Entwicklungsrechner aus bedienen: Status ansehen, das
Update anstoßen, Protokolle lesen.

Der Client `woyShell.ps1` liegt in diesem Repo (`Modul/Skripte`) und läuft unter **Windows (MARS) und macOS
(LUNA)**. Das Repo **Auf** ist auf LUNA nicht vorhanden. Deshalb ist die Schnittstelle hier beschrieben, und
alles, was auf LUNA gebraucht wird, geht ohne Auf.

## Überblick

```text
 Entwicklungsrechner (MARS, LUNA)                  Zielrechner (MARS, TEST-SRV, SQL-SRV)
 ─────────────────────────────────                 ─────────────────────────────────────
 mars@ / test@ / prod@   (Profil)
   └─ woyShell.ps1  ── WebSocket, TCP 60000 ──►    AufServiceNT
        woyshell.json (Url, Schlüssel)               └─ PowerShell-7-Sitzung je Verbindung
                                                        Start in D:\woySystems, Rechte des Dienstkontos
```

- Adresse: `ws://<Rechner>:60000/ServiceCtrl/Shell`.
- Je Verbindung eine eigene PowerShell-7-Sitzung im Dienst. Variablen, Module und das aktuelle Verzeichnis
  bleiben bis zum Ende der Verbindung erhalten.
- Die Sitzung hat die Rechte des Dienstkontos. Ist es Administrator, zeigt der Prompt `[PROD*]`, sonst
  `[PROD]` mit einer Warnung in der Begrüßung.
- Anmeldung mit HMAC-Challenge in beide Richtungen. Der Schlüssel geht nie über die Leitung.
- **Die Verbindung ist nicht verschlüsselt.** Befehle und Ausgaben sind im LAN lesbar. Keine Passwörter
  eintippen.

## Rechner

| Name in `woyshell.json` | Rechner  | Adresse                                   | Profilbefehl |
| ----------------------- | -------- | ----------------------------------------- | ------------ |
| `MARS`                  | MARS     | `ws://mars:60000/ServiceCtrl/Shell`         | `mars@`      |
| `TEST`                  | TEST-SRV | `ws://192.168.50.28:60000/ServiceCtrl/Shell` | `test@`      |
| `PROD`                  | SQL-SRV  | `ws://192.168.50.17:60000/ServiceCtrl/Shell` | `prod@`      |

Stand 2026-11-15. Die Adressen von TEST und PROD sind dieselben wie `WOY_TESTSRV` und `WOY_SQLSRV` in der
`woy.env`.

## Einrichtung

### Auf dem Zielrechner (einmal je Rechner)

1. woyControlCenter, Reiter **Installation**, Zeile **REST - Service**: Haken **Remote-Shell** setzen.
2. Mit **Neu** einen Schlüssel erzeugen. Er landet in der Zwischenablage.
3. Speichern, AufServiceNT neu starten.

Der Dienst legt dabei die Firewall-Regel „AufServiceNT ControlService (TCP 60000)“ an (Profile Privat und
Domäne). Gespeichert wird in `woyService.json` (`RemoteShell`, `RemoteShellToken`).

### Auf dem Entwicklungsrechner (einmal je Zielrechner)

```powershell
woyShell.ps1 -Rechner PROD -Url ws://192.168.50.17:60000/ServiceCtrl/Shell -Token <Schlüssel> -Merken
```

`-Merken` schreibt Url und Schlüssel nach `woyshell.json`. Die Datei liegt in iCloud Drive und ist damit auf
MARS und LUNA gleich. Einrichten muss man sie also nur auf einem der beiden Rechner. Wo die Datei liegt, zeigt
`Show-Mds` in der Zeile `mdsWoyShell`:

1. Umgebungsvariable `WOYSHELL_CONFIG` (voller Dateiname), falls gesetzt,
2. sonst `$mdsCloud/woyshell.json`, wenn der iCloud-Ordner existiert
   (Windows `~\iCloudDrive\Documents\Config`, macOS `~/Library/Mobile Documents/com~apple~CloudDocs/Documents/Config`),
3. sonst `~/.woy/woyshell.json`.

Statt der Datei geht auch eine Umgebungsvariable `WOYSHELL_TOKEN_<RECHNER>`, z. B. `WOYSHELL_TOKEN_PROD`.
Fehlt die Url, gilt `ws://<rechner>:60000/ServiceCtrl/Shell`.

`Install.ps1` (oder `run mds install`) kopiert `woyShell.ps1` nach `$mdsRepos`. Die Profilbefehle finden es dort.
Bis zur ersten Installation nehmen sie es direkt aus `Mds/Modul/Skripte`.

## Aufruf

| Aufruf                                | Wirkung                                                          |
| ------------------------------------- | ---------------------------------------------------------------- |
| `prod@`                               | interaktive Sitzung auf PROD (ebenso `mars@`, `test@`)           |
| `prod@ -Command 'Show'`               | ein Befehl, danach Ende; Rückgabe siehe unten                    |
| `prod@ -Command 'Update'`             | Update auf PROD anstoßen und bis zum Ende des Protokolls warten  |
| `woyShell.ps1 <Name> [-Command '...']` | dasselbe ohne Profil, `<Name>` wie in `woyshell.json`           |

Die Profilbefehle starten `woyShell.ps1` in einem eigenen pwsh-Prozess. Verlauf und Tab-Belegung der eigenen
Sitzung bleiben dadurch unberührt. `@prod` geht nicht, weil PowerShell ein `@` vor dem Namen als Splatting liest.

Parameter von `woyShell.ps1`:

| Parameter  | Bedeutung                                                         |
| ---------- | ----------------------------------------------------------------- |
| `-Rechner` | Name in `woyshell.json` (erste Stelle, Vorgabe `MARS`)            |
| `-Url`     | Adresse, überschreibt `woyshell.json`                             |
| `-Token`   | Schlüssel, überschreibt `woyshell.json`                           |
| `-Merken`  | Url und Schlüssel in `woyshell.json` speichern                    |
| `-Command` | einen Befehl ausführen und beenden statt interaktiv               |

Rückgabe mit `-Command` (`$LASTEXITCODE`):

| Wert | Bedeutung                                                           |
| ---- | ------------------------------------------------------------------- |
| 0    | Befehl erfolgreich                                                  |
| 1    | Befehl mit Fehler beendet                                           |
| 2    | Verbindung abgebrochen (später neu verbinden, `UpdateLog -Wait`)    |

## Befehle in der Sitzung

Alles, was PowerShell 7 auf dem Zielrechner kann, plus diese Kurzbefehle:

| Befehl                           | Wirkung                                                                           |
| -------------------------------- | --------------------------------------------------------------------------------- |
| `Show`                           | Stand der Installation (`woyControlCenter Show`)                                  |
| `Update`                         | Programme aktualisieren (`woyControlCenter Update`)                               |
| `woyControlCenter D`             | Update mit Datenbanken (DBS)                                                      |
| `woyControlCenter ?`             | Hilfe des woyControlCenter                                                        |
| `UpdateLog [-Wait] [-Minuten n]` | letztes Update-Protokoll; `-Wait` wartet erst auf das Ende (höchstens n, Vorgabe 15 Minuten) |
| `Root`                           | zurück ins Startverzeichnis (`$WoyRoot`, z. B. `D:\woySystems`)                   |

Beim woyControlCenter reicht der Wortanfang: `S`, `U`, `D`, `H`.

In der interaktiven Sitzung:

- `exit` oder `quit` beendet.
- `Strg+C` bricht einen laufenden Befehl ab.
- `Tab` vervollständigt auf dem Zielrechner.
- Interaktive Eingaben gehen nicht: kein `Read-Host`, kein `Get-Credential`, keine Editoren.

## Update über die Remote-Shell

`Update` und `woyControlCenter D` installieren AufServiceNT selbst neu, also genau den Dienst, der die Sitzung
trägt. Deshalb läuft der Ablauf so:

1. Der Dienst startet woyControlCenter als eigenen Prozess. Die Ausgabe geht nach
   `Logs\woyControlCenter-<Update|DBS>-yyyyMMdd-HHmmss.log` unter dem Root.
2. Die Verbindung bricht ab, sobald AufServiceNT neu installiert wird.
3. `woyShell.ps1` wartet bis zu 120 s auf den Dienst, verbindet sich neu und ruft `UpdateLog -Wait` auf.
4. Das Protokoll erscheint, sobald woyControlCenter fertig ist.

Kommt der Dienst nicht rechtzeitig zurück, später mit `prod@` verbinden und `UpdateLog -Wait` eingeben.

Vor dem Update müssen die neuen Installationsdateien im `InstallDir` des Zielrechners liegen. Das erledigt
`run auf copy` auf MARS.

## Von MARS und von LUNA aus

| Aufgabe                       | MARS (mit Repo Auf)       | LUNA (ohne Auf)                    |
| ----------------------------- | ------------------------- | ---------------------------------- |
| Installationsdateien kopieren | `run auf copy test\|prod` | geht nicht (Build und Deck auf MARS) |
| Update anstoßen               | `run auf update test\|prod` | `test@ -Command 'Update'` / `prod@ -Command 'Update'` |
| Status ansehen                | `prod@ -Command 'Show'`   | `prod@ -Command 'Show'`            |
| Protokoll des letzten Updates | `prod@ -Command 'UpdateLog'` | `prod@ -Command 'UpdateLog'`    |
| interaktiv arbeiten           | `prod@`                   | `prod@`                            |

`run auf update` (`Auf/scripts/_update.ps1`) ist nur eine Hülle um `woyShell.ps1 TEST|PROD -Command 'Update'`
mit Meldung am Ende. Auf LUNA ist der direkte Aufruf gleichwertig. Bei `run auf copy` und `run auf update`
reicht der erste Buchstabe des Ziels: `t` = TEST-SRV, `p` oder `s` = SQL-SRV (PROD).

## Quellen

| Teil                     | Ort                                                                   |
| ------------------------ | --------------------------------------------------------------------- |
| Client                   | `Mds/Modul/Skripte/woyShell.ps1`                                      |
| Profilbefehle            | `Mds/Profile/profile.ps1` (`Open-WoyShell`, `mars@`, `test@`, `prod@`) |
| Ort von `woyshell.json`  | `$mdsWoyShell` in `Mds/Modul/MdsTools/Skripte/InitModule.ps1`         |
| Server (nur Repo Auf)    | `Auf/Source/ServiceNT/AufServiceNT.Host/RemoteShell.cs`               |
| run-Skripte (nur Auf)    | `Auf/scripts/_copy.ps1`, `Auf/scripts/_update.ps1`                    |
