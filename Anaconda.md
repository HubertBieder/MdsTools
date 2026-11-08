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

Anaconda 2026.07 (wie auf LUNA), systemweit unter `C:\ProgramData\Anaconda`. Installiert am 08.11.2026 als
Ersatz für 2025.12 (Python 3.13). Die Umgebungen sind dieselben wie auf LUNA.

Ein Update von einer älteren Version erfolgt als Neuinstallation: alte Version deinstallieren, dann neu
installieren. Beide Schritte brauchen Adminrechte (UAC-Abfrage bestätigen).

```powershell
# 1. Installer laden und prüfen (SHA256 laut winget show --id Anaconda.Anaconda3)
$f = "$env:TEMP\Anaconda3-2026.07-1-Windows-x86_64.exe"
Invoke-WebRequest https://repo.anaconda.com/archive/Anaconda3-2026.07-1-Windows-x86_64.exe -OutFile $f
(Get-FileHash $f).Hash   # B545F4BD8AB3BF32D99002A0779A887668EBFE479EE32ECBF060375670D5EE09

# 2. Alte Version entfernen (läuft im Hintergrund weiter; warten, bis der Ordner leer ist)
Start-Process C:\ProgramData\Anaconda\Uninstall-Anaconda3.exe -ArgumentList '/S' -Verb RunAs -Wait
Remove-Item C:\ProgramData\Anaconda -Recurse -Force   # Reste entfernen, der Installer braucht einen leeren Ordner

# 3. Neu installieren, für alle Benutzer, ohne PATH-Eintrag und ohne Registrierung als System-Python
Start-Process $f -Verb RunAs -Wait -ArgumentList '/InstallationType=AllUsers', '/RegisterPython=0', '/AddToPath=0', '/S', '/D=C:\ProgramData\Anaconda'

# 4. Nutzungsbedingungen, Konfiguration, Umgebungen
$c = 'C:\ProgramData\Anaconda\Scripts\conda.exe'
& $c tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
& $c tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
& $c tos accept --override-channels --channel https://repo.anaconda.com/pkgs/msys2   # nur Windows
& $c tos                                     # Spalte Accepted: Datum bei allen drei Kanälen

& $c config --set auto_activate false        # base nicht automatisch aktivieren
& $c create -n py314 python=3.14 -y
& $c create -n py313 python=3.13 -y
& $c create -n py315 python=3.15 -y
& $c env list
```

Hinweise:

- Windows hat den zusätzlichen Kanal `msys2`. Ohne dessen akzeptierte Bedingungen bricht `conda create` mit
  `CondaToSNonInteractiveError` ab.
- Installer-Exitcode `2` heißt: Zielordner nicht leer. Typische Ursache ist ein noch laufender Prozess aus dem
  alten Anaconda, z. B. der Ruff-Sprachserver aus VS Code (`ruff.exe`). Prüfen und beenden:
  `Get-Process | Where-Object Path -like 'C:\ProgramData\Anaconda*' | Stop-Process`
- `C:\ProgramData\Anaconda` ist für den Benutzer schreibgeschützt; conda legt die Umgebungen deshalb unter
  `C:\Users\huber\.conda\envs` an. `Get-CondaPython` sucht dort automatisch.
- Die alte Umgebung `Hubi_311` (Python 3.11, für DataCLI aus PHB) liegt ebenfalls in `~\.conda\envs` und
  übersteht die Neuinstallation.
- Danach das Profil mit `./Install.ps1` neu installieren und eine neue pwsh-Sitzung starten.

Stand 08.11.2026: base 3.14.6, py314 3.14.2, py313 3.13.11, py315 3.15.2, conda 26.5.3.

## Profil (Profile/profile.ps1)

| Element                       | Wirkung                                                                                            |
| ----------------------------- | -------------------------------------------------------------------------------------------------- |
| `$condaRoot`                  | Anaconda-Ordner: Windows `C:\ProgramData\Anaconda`, macOS `/opt/homebrew/anaconda3`                |
| `Get-CondaPython <env>`       | Pfad zum Python einer Umgebung (`base` = Anaconda); sucht in `$condaRoot/envs` und `~/.conda/envs` |
| `Use-Conda`                   | conda in der aktuellen Sitzung aktivieren, danach z. B. `conda activate py313`                     |
| `py`, `py313`, `py315`, `pyb` | Windows und macOS gleich: Python der jeweiligen Umgebung direkt starten (`py` = py314)             |
| `DataCLI`, `py311`            | nur Windows: Umgebung `Hubi_311`; `DataCLI` startet PHB/src/DataCLI                                |

## VS Code

Umgebung wählen: `⌘⇧P` (Windows `Strg+Umschalt+P`) → „Python: Select Interpreter“ → `py314` (bzw. `py313`).
