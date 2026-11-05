# Luna – Offene Punkte (allgemein und LUNA)

Alles, was **vor** der Umstellung von MARS erledigt sein muss: Entscheidungen und Arbeiten am Modul, die sich auf
LUNA erledigen lassen. Erst wenn diese Liste komplett abgehakt ist, wird [Mars.md](Mars.md) in einem Stück
abgearbeitet.

MdsTools wird nur auf **LUNA und MARS** installiert, sonst bisher nirgends (keine Kundenrechner).

| Datum      | Autor                | Änderung                                                                  |
| ---------- | -------------------- | ------------------------------------------------------------------------- |
| 2026-11-05 | Hubert Bieder/Claude | Erste Fassung                                                             |
| 2026-11-05 | Hubert Bieder/Claude | Deploy-Skripte gestrichen; `.env.example` angelegt; Kurzbefehle erledigt  |

## 1. Stand sichern

- [x] Offene Änderungen in `Mds` committen und pushen (05.11.2026).
- [ ] `./Install.ps1` auf LUNA, neue Shell: Prompt zeigt `PS ~/Repos/Mds>`.

## 2. Entscheidungen

- [ ] **Auftrags-Cmdlets auf Kundenrechnern:** Die Desktop-Symbole der Auftragsabwicklung rufen
      `Invoke-ArtImportDownload`, `Invoke-XRechnung`, `Invoke-Backup` … auf und laden dafür bisher mdsPackage.
      MdsTools enthält diese Cmdlets nicht und kommt auf Kundenrechner auch nicht. Zu entscheiden: Welches Modul
      stellt sie dort bereit (mdsPackage beibehalten oder ein eigenes kleines Modul)? Erst danach wird `Auf`
      umgestellt ([Mars.md](Mars.md#4-auf-von-mdspackage-lösen)).
- [ ] **Präfix für neue Cmdlets** festlegen (z. B. `Mds`), gilt nur für neue Funktionen.
- [ ] **Logging:** Format und Aufbewahrungsdauer der Dateien in `$mdsLogs`.

## 3. Modul MdsTools

- [x] `.env.example` im Repo angelegt (Dummy-Werte; `.env` steht in `.gitignore`).
- [x] Kurzbefehle `2Net`, `2Maui` … und Alias `zip` entfallen (nicht mehr im Profil).
- [ ] Entscheidungen aus Abschnitt 2 umsetzen (Präfix, Logging) und in [MdsTools.md](MdsTools.md) beschreiben.
- [ ] Abnahme LUNA: `Copy-FileWithCredential` kopiert eine Datei auf eine SMB-Freigabe.
- [ ] `Invoke-Pester ./tests` und `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1`
      ohne Fehler (Stand 05.11.2026: 83 Tests grün, 0 Fehler, 31 Warnungen).
- [ ] Modulversion erhöhen (z. B. 8.3.2), committen, pushen.

## 4. Abschluss

- [ ] Alle Punkte oben erledigt → [Mars.md](Mars.md) durchgehen und Termin für MARS festlegen.
