#!/usr/bin/env bash
# Dev loop for Linux/macOS/Git Bash: git pull -> headless APK export -> adb install -> launch.
# Env: GODOT=/path/to/godot (editor binary), ADB_SERIAL=ip:port (optional).
# Flags: --no-pull --no-install --log
set -euo pipefail
PACKAGE=com.drums55.game25d
cd "$(dirname "$0")/.."
APK="$PWD/build/game25d.apk"
GODOT="${GODOT:-godot}"
pull=1 install=1 log=0
for a in "$@"; do
  case "$a" in
    --no-pull) pull=0 ;; --no-install) install=0 ;; --log) log=1 ;;
    *) echo "unknown flag $a"; exit 2 ;;
  esac
done

if [ $pull = 1 ]; then echo "==> git pull"; git pull --ff-only; fi
git log -1 --format='%h %s'
[ -f addons/gut/plugin.cfg ] || bash tools/fetch_gut.sh
echo "==> import"; "$GODOT" --headless --path . --import
echo "==> export"; mkdir -p build; rm -f "$APK"
"$GODOT" --headless --path . --export-debug Android "$APK"
[ -f "$APK" ] || { echo "Export failed: no APK"; exit 1; }
ls -lh "$APK"
[ $install = 1 ] || exit 0

dev=()
[ -n "${ADB_SERIAL:-}" ] && dev=(-s "$ADB_SERIAL")
echo "==> adb install"
out="$(adb "${dev[@]}" install -r "$APK" 2>&1 || true)"; echo "$out"
if grep -q INSTALL_FAILED_UPDATE_INCOMPATIBLE <<<"$out"; then
  echo "signature changed: uninstalling (wipes save)"; adb "${dev[@]}" uninstall "$PACKAGE" || true
  out="$(adb "${dev[@]}" install "$APK" 2>&1 || true)"; echo "$out"
fi
grep -q Success <<<"$out" || { echo "adb install failed"; exit 1; }
[ $log = 1 ] && adb "${dev[@]}" logcat -c
adb "${dev[@]}" shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 >/dev/null
[ $log = 1 ] && adb "${dev[@]}" logcat -s godot:V
exit 0
