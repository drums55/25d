# 25d — 2D isometric adventure (Godot 4.4, Android)

Hades-style 2D isometric adventure for Android tablets (Redmi Pad Pro) and phones.
Placeholder graphics for now; all final art is AI-generated (see `assets/art/README.md`).

## First-time setup on the PC (Windows)

Needs: git, the Android SDK + JDK that Flutter/Android Studio already installed.

```powershell
git clone https://github.com/drums55/25d.git
cd 25d
powershell -ExecutionPolicy Bypass -File tools\dev_setup.ps1
```

`dev_setup.ps1` downloads Godot 4.4.1 to `%USERPROFILE%\godot\4.4.1`, extracts the
Android export templates (one 1.1 GB download), points Godot at your Android SDK/JDK,
imports the project and sets the `GODOT` user env var. Re-running is safe.
Options: `-SdkPath`, `-JavaPath`, `-GodotDir`.

## Normal loop: pull → build → install on the tablet

On the tablet: Settings → Developer options → Wireless debugging → note `ip:port`
(first time also "Pair device with pairing code" → `adb pair ip:pairport`).

```powershell
adb connect 192.168.1.50:41234
$env:ADB_SERIAL = "192.168.1.50:41234"
powershell -ExecutionPolicy Bypass -File tools\update.ps1          # pull + export + install + launch
powershell -ExecutionPolicy Bypass -File tools\update.ps1 -Log     # ... then tail game logs
```

Linux/macOS/Git Bash: `GODOT=/path/to/godot ADB_SERIAL=ip:port tools/update.sh [--log]`.

Play on the PC without a device (no export):

```powershell
powershell -ExecutionPolicy Bypass -File tools\run.ps1                              # game
powershell -ExecutionPolicy Bypass -File tools\run.ps1 --rendering-driver opengl3   # if the window is black
powershell -ExecutionPolicy Bypass -File tools\run.ps1 -Editor                      # Godot editor (F5 = run)
```

WASD/arrows move, J/Space attack, E/K interact; the mouse drives the on-screen joystick.

## Tests / CI

CI (`.github/workflows/ci.yml`) runs gdformat, gdlint and GUT unit tests headless on every push.
It never builds APKs. Locally:

```bash
pip install "gdtoolkit==4.*"; gdformat --check scripts test; gdlint scripts test
GODOT=/path/to/godot bash tools/run_tests.sh
```

## Layout

See `CLAUDE.md` for structure, architecture decisions and gotchas.
