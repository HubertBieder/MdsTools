# Mars – Umstellung in einem Stück

Erst beginnen, wenn [Luna.md](Luna.md) **komplett** erledigt ist. Die Liste wird in einem Durchgang abgearbeitet.
Dafür braucht es Admin-Rechte. Auf MARS gibt es keinen TaskScheduler; die REST-Dienste laufen direkt in der
Auftragsabwicklung und stehen für die Abschnitte 1–2 still.

| Datum      | Autor                | Änderung                                                          |
| ---------- | -------------------- | ----------------------------------------------------------------- |
| 2026-11-05 | Hubert Bieder/Claude | Erste Fassung                                                     |
| 2026-11-05 | Hubert Bieder/Claude | Ohne TaskScheduler und Deploy-Skripte; REST in Auftragsabwicklung |

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

- [ ] Verschieben und alte Umgebungsvariablen prüfen:

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
- [ ] Config auf alte Pfade prüfen und korrigieren (Sicherung `*.bak-83`):

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

## 3. Neu bauen und Einrichten

- [ ] Net, Maui und Auf aktualisieren und bauen:

  ```powershell
  go net;  git pull; mk net
  go maui; git pull; mk maui
  go auf;  git pull; mk auf          # vollständiger Lauf mit Init/Post
  ```

- [ ] Auftragsabwicklung samt REST starten, neue Logdateien unter `D:\Root\Logs` bzw. im Log der Auftragsabwicklung.
- [ ] `%USERPROFILE%\.woy\woy.env` vorhanden und vollständig (`Get-WoyEnvPath`, `Get-WoyValue …`), Vergleich mit
      `woy.env.example`.
- [ ] `Get-WoyCredential server` liefert eine Anmeldung.
- [ ] `go`, `mk`, `run` in `C:\woyCode` (flache Struktur).
- [ ] Kopieren lokal: `run auf copy`.
- [ ] Kopieren nach TEST-SRV: `run auf copy t`.
- [ ] Kopieren nach SQL-SRV: `run auf copy s`.
- [ ] `run auf version`, `run auf desktop` (Desktop-Verknüpfungen neu, keine Ziele unter `D:\Dev`).
- [ ] `Copy-FileWithCredential` kopiert eine Datei auf eine SMB-Freigabe.
- [ ] `Invoke-Pester ./tests` in `C:\woyCode\Mds`.
- [ ] Kopieren vom Entwicklungsrechner nach TERRA klären (früher `_Copy2Terra.ps1`).

## 4. Auf von mdsPackage lösen

Gemäß der Entscheidung aus [Luna.md](Luna.md#2-entscheidungen) (MdsTools kommt nicht auf Kundenrechner):

- [ ] `Import-Module mdsPackage` ersetzen in AdminControl `PSDesktopLink.cs` und `DesktopIcons.json`,
      woyControlCenter `UpdateServer.KorrigierePowerShellLinks`, `xBase/PROCESS.cs`, woyLib `StartPowerShell.cs`
      (`ImportCmd`).
- [ ] Modul mit den Auftrags-Cmdlets für Kundenrechner bereitstellen; Update auf einem Testrechner (TEST-SRV) prüfen.

## 5. Aufräumen

- [ ] Leeren Ordner `D:\Dev` löschen.
- [ ] `C:\woyCode\_Alt\mdsPackage` löschen.
- [ ] Alte Skripte `Maui/Make-MauiApps.ps1` und `Maui/Make-Single.ps1` entfernen (durch `mk maui` ersetzt).
- [ ] Doku nachziehen: in [MDS-Development.md](MDS-Development.md#offene-punkte) unter „Erledigt“ eintragen,
      Stand in [MdsTools.md](MdsTools.md#auftragsabwicklung-nur-windows) aktualisieren, `Luna.md` und `Mars.md`
      löschen.
