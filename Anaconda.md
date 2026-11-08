# Anaconda

Python für die Entwicklung kommt aus **Anaconda**. Pakete werden nur in eigenen Umgebungen installiert;
die `base`-Umgebung bleibt unverändert.

## Umgebungen

| Umgebung | Python | Zweck                                                           | Aufruf (Profil) |
| -------- | ------ | --------------------------------------------------------------- | --------------- |
| `py314`  | 3.14   | Alltag, Hauptversion                                            | `py`            |
| `py313`  | 3.13   | Kompatibilität, wenn ein Paket 3.14 noch nicht kann; ML (YOLO/PyTorch) | `py313`  |
| `py315`  | 3.15   | nur zum Ausprobieren, viele Pakete fehlen noch                  | `py315`         |
| `base`   | 3.14   | Anaconda selbst, nicht verändern                                | `pyb`           |

Python 3.10 wird nicht mehr installiert (Anaconda-Support endet im Oktober 2026).

## Nutzung

**Umgebung aktivieren** (gilt für die aktuelle pwsh-Sitzung; danach sind `python` und `pip` die der Umgebung):

```powershell
Use-Conda                 # conda in dieser Sitzung verfügbar machen (einmal je Sitzung)

conda activate py314      # Python 3.14
conda activate py313      # Python 3.13
conda activate py315      # Python 3.15
conda activate base       # Anaconda selbst

conda deactivate          # zurück zur vorherigen Umgebung
conda env list            # alle Umgebungen, * = aktiv
python --version          # Kontrolle
```

**Ohne Aktivieren** direkt starten (Profil-Befehle, z. B. für einzelne Skripte):

```powershell
py skript.py              # Python 3.14 (py314)
py313 skript.py           # Python 3.13
py315 skript.py           # Python 3.15
pyb --version             # base
```

**Pakete installieren** (nie in `base`):

```powershell
conda activate py313
conda install numpy       # bevorzugt aus conda
pip install ultralytics   # was es nur bei pip gibt
conda list                # installierte Pakete der aktiven Umgebung
```

**Umgebung neu anlegen oder entfernen:**

```powershell
conda create -n py312 python=3.12 -y
conda remove -n py312 --all -y
```

## Installation auf macOS (LUNA)

Anaconda 2026.07 über Homebrew; es gibt nur noch Apple Silicon (arm64). Ziel: `/opt/homebrew/anaconda3`.

```powershell
brew install --cask anaconda                 # fragt nach dem Passwort (Installer läuft mit sudo)
sudo chown -R hubert:staff ~/.conda          # sudo legt ~/.conda als root an -> zurück an den Benutzer

$c = '/opt/homebrew/anaconda3/bin/conda'
& $c tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
& $c tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
& $c tos                                     # Spalte Accepted: Datum bei beiden Kanälen

& $c config --set auto_activate_base false   # base nicht automatisch aktivieren
& $c create -n py314 python=3.14 -y
& $c create -n py313 python=3.13 -y
& $c create -n py315 python=3.15 -y
& $c env list
```

Hinweise:

- Ohne `chown` scheitert `conda tos accept` mit `CondaToSPermissionError`.
- Ohne akzeptierte Nutzungsbedingungen bricht `conda create` mit `CondaToSNonInteractiveError` ab.
- Die Umgebungen liegen unter `/opt/homebrew/anaconda3/envs`.

## Installation auf Windows (MARS)

Anaconda liegt systemweit unter `C:\ProgramData\Anaconda`. Die Umgebungen werden dort genauso mit
`conda create` angelegt (Pfad zu conda: `C:\ProgramData\Anaconda\Scripts\conda.exe`).

## Profil (Profile/profile.ps1)

| Element                   | Wirkung                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------- |
| `$condaRoot`              | Anaconda-Ordner: Windows `C:\ProgramData\Anaconda`, macOS `/opt/homebrew/anaconda3`          |
| `Get-CondaPython <env>`   | Pfad zum Python einer Umgebung (`base` = Anaconda); sucht in `$condaRoot/envs` und `~/.conda/envs` |
| `Use-Conda`               | conda in der aktuellen Sitzung aktivieren, danach z. B. `conda activate py313`              |
| `py`, `py313`, `py315`, `pyb` | macOS: Python der jeweiligen Umgebung direkt starten (`py` = py314)                     |
| `py`, `DataCLI`, `pyb`    | Windows: `py` = Umgebung `hubi_311`, `DataCLI` startet PHB/src/DataCLI                       |

## VS Code

Umgebung wählen: `⌘⇧P` → „Python: Select Interpreter“ → `py314` (bzw. `py313`).
