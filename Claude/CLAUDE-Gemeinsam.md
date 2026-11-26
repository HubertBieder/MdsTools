# Gemeinsame Claude-Regeln für alle Repos (MDS)

<!--
Version  Datum       Wer           Was
1.0.0    2026-11-26  Hubi/Claude   Erste Fassung; repoübergreifende Teile aus Maui/CLAUDE.md übernommen.
Diese Datei wird von der CLAUDE.md jedes Repos per `@../Mds/Claude/CLAUDE-Gemeinsam.md` eingebunden
(in Mds selbst per `@Claude/CLAUDE-Gemeinsam.md`). Repo-spezifisches gehört in die CLAUDE.md des Repos.
-->

Entwickler: Hubert Bieder (Hubi, hubert@bieders.de). Sprache in Antworten, Kommentaren und Doku: Deutsch.

## Systeme

| System | OS      | Rolle                                                            | `$mdsRepos`          |
| ------ | ------- | ---------------------------------------------------------------- | -------------------- |
| LUNA   | macOS   | **führend** – alles außer reiner Windows-Entwicklung entsteht hier und wird dann portiert | `/Users/hubert/Repos` |
| MARS   | Windows | Windows-Programme, Auftragsabwicklung, IIS, SQL Server           | `C:\woyCode`         |

- Pfade nie fest verdrahten: immer `$mdsRepos` (MdsTools) bzw. relative Pfade zwischen den Repos (`../Net`).
- Unterschiede zwischen den Systemen nur über `$IsWindows` / `$IsMacOS`, nie über den Rechnernamen.
- Details der Umgebung: `Mds/MDS-Development.md` (Systematik), `Mds/MdsTools.md` (Modul, `go`, `mk`, `run`).

## Repos (Ordner = Kurzname, ≠ GitHub-Name)

| Ordner | GitHub (HubertBieder) | Inhalt                                   | Systeme      |
| ------ | --------------------- | ---------------------------------------- | ------------ |
| `Mds`  | MdsTools              | PowerShell-Modul MdsTools, globale Skripte | beide      |
| `Net`  | NetCoreLib2026        | C#-Basisklassen, Libs, Services, CLIs    | beide        |
| `Maui` | NetMauiApps           | .NET-MAUI-/Desktop-Apps (GUI-Seite)      | beide        |
| `PHB`  | PythonHB              | Python                                   | beide        |
| `Auf`  | woyV26                | Auftragsabwicklung (WinForms)            | beide        |
| `V27`, `Desk` | –              | Windows-spezifische Software             | nur MARS     |

- In Pfaden, Doku und Code immer die Kurznamen verwenden, nie die GitHub-Namen.
- Abhängigkeitsrichtung: `Maui` → `Net`, `Auf` → `Net` (Net hängt von keinem anderen Repo ab).
- NuGet-Versionen zentral in `Directory.Packages.props` (Central Package Management), keine `Version=` im csproj.
  Sicherheits-Pins: `Net/docs/NuGet-Sicherheit.md`.
- Bauen/Ausliefern mit `mk` (MdsTools) → `<Repo>/scripts/Make.ps1`.

## Arbeitsweise

- Editor: VS Code auf beiden Systemen.
- Skripte und Beispiele: PowerShell 7 (mind. 7.6), lauffähig auf macOS **und** Windows.
- Jede Skript-/Datei-Änderung im Kopf versionieren (Tabelle `Version  Datum  Wer  Was`, Wer z. B. `Hubi/Claude`);
  im Code bei nicht offensichtlichen Änderungen kurzer Kommentar `# JJJJ-MM-TT Hubi/Claude: …`.
- Globale Skripte (CloneAll, PushAll …) liegen in `Mds/Modul/Skripte` und werden nach `$mdsRepos` installiert –
  dort nicht direkt ändern.
- Commits/Pushes nur auf Anweisung; Abgleich zwischen LUNA und MARS läuft über GitHub (PushAll/CloneAll).
