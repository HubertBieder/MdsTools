# Mars – Umstellung in einem Stück

Erst beginnen, wenn [Luna.md](Luna.md) leer ist. Die Liste wird in einem Durchgang abgearbeitet; erledigte Punkte
werden gelöscht. Es braucht Admin-Rechte. Auf MARS gibt es keinen TaskScheduler; die REST-Dienste laufen direkt in
der Auftragsabwicklung und stehen für die Abschnitte 1–2 still.

## 0. Vorher prüfen

- [ ] Alle Repos auf GitHub aktuell (LUNA: `PushAll`), auf MARS keine lokalen Änderungen in `C:\woyCode\*`.
- [ ] Sicherung von `D:\Dev\Root` (vor allem `Config` und `Data`).

## 1. Root umziehen (`D:\Dev\Root` → `D:\Root`)

Root muss verschoben sein, **bevor** MdsTools 8.3 geladen wird, sonst legt das Modul ein leeres `D:\Root` an.

- [ ] Programme der Auftragsabwicklung (samt REST) beenden und prüfen, dass nichts mehr aus `D:\Dev\Root` läuft
      (PowerShell als Admin):

  ```powershell
  Get-Process | Where-Object Path -like 'D:\Dev\Root\*'    # muss leer sein
  ```

- [ ] Verschieben und Umgebungsvariablen prüfen:

  ```powershell
  Move-Item D:\Dev\Root D:\Root
  'DEV_HOME', 'DEV_ROOT' | ForEach-Object {
      [Environment]::GetEnvironmentVariable($_, 'Machine'), [Environment]::GetEnvironmentVariable($_, 'User')
  }   # DEV_HOME löschen; DEV_ROOT nur, wenn es noch auf D:\Dev\Root zeigt
  ```

## 2. MdsTools installieren und Pfade korrigieren

- [ ] Modul installieren, neue Shell:

  ```powershell
  cd C:\woyCode\Mds; git pull; ./Install.ps1
  ```

- [ ] `Show-Mds` zeigt `woy 26`, Repos `C:\woyCode`, Root `D:\Root` (Quelle `Standard`, `Vorhanden = True`).
- [ ] Config auf `D:\Dev\` prüfen und korrigieren (Sicherung `*.bak-83`):

  ```powershell
  $alt = Get-ChildItem D:\Root\Config -Recurse -File -Exclude *.bak* | Select-String -List -SimpleMatch 'D:\Dev\'
  $alt.Path
  foreach ($f in $alt.Path) {
      Copy-Item $f "$f.bak-83"
      (Get-Content -Raw $f) -replace [regex]::Escape('D:\Dev\Root'), 'D:\Root' | Set-Content -NoNewline $f
  }
  ```

  In JSON-Dateien stehen Backslashes doppelt (`D:\\Dev\\Root`). Vorher mit `$alt` prüfen und gegebenenfalls
  zusätzlich `-replace [regex]::Escape('D:\\Dev\\Root'), 'D:\\Root'` anwenden.
- [ ] Aufgabenplanung prüfen: `Get-ScheduledTask | Where-Object { $_.Actions.Execute -like '*\Dev\*' }`.

## 3. Bauen, starten, testen

- [ ] Net und Maui aktualisieren und bauen (Ziel `$mdsBin` = `D:\Root\Bin`):

  ```powershell
  go net;  git pull; mk net
  go maui; git pull; mk maui
  ```

- [ ] Auftragsabwicklung samt REST starten.
- [ ] `%USERPROFILE%\.woy\woy.env` vollständig (`Get-WoyEnvPath`, `Get-WoyValue …`), Vergleich mit `woy.env.example`.
- [ ] `Get-WoyCredential server` liefert eine Anmeldung.
- [ ] `go`, `mk`, `run` in `C:\woyCode`.
- [ ] Kopieren: `run auf copy`, `run auf copy t` (TEST-SRV), `run auf copy s` (SQL-SRV).
- [ ] `run auf version`, `run auf desktop` (keine Ziele unter `D:\Dev`).
- [ ] `Copy-FileWithCredential` kopiert eine Datei auf eine SMB-Freigabe.
- [ ] `Invoke-Pester ./tests` in `C:\woyCode\Mds`.
- [ ] Kopieren vom Entwicklungsrechner nach TERRA klären.

## 4. Aufräumen

- [ ] Leeren Ordner `D:\Dev` löschen.
- [ ] `C:\woyCode\_Alt\mdsPackage` löschen.
- [ ] `Maui/Make-MauiApps.ps1` und `Maui/Make-Single.ps1` entfernen (durch `mk maui` ersetzt).
- [ ] Doku auf den aktuellen Stand bringen, `Luna.md` und `Mars.md` löschen.
