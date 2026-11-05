# Luna – Offene Punkte (allgemein und LUNA)

Was **vor** der Umstellung von MARS erledigt sein muss. Erst wenn diese Liste leer ist, wird [Mars.md](Mars.md) in
einem Stück abgearbeitet. Erledigte Punkte werden gelöscht.

## Entscheidungen

- [ ] **Präfix für neue Cmdlets** festlegen (z. B. `Mds`), gilt nur für neue Funktionen.
- [ ] **Logging:** Format und Aufbewahrungsdauer der Dateien in `$mdsLogs`.

## Modul MdsTools

- [ ] `./Install.ps1` auf LUNA, neue Shell: Prompt zeigt `PS ~/Repos/Mds>`.
- [ ] Präfix und Logging umsetzen und in [MdsTools.md](MdsTools.md) beschreiben.
- [ ] `Copy-FileWithCredential` auf LUNA: Datei auf eine SMB-Freigabe kopieren.
- [ ] `Invoke-Pester ./tests` und `Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1`
      ohne Fehler.
