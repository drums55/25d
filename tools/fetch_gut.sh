#!/usr/bin/env bash
# Fetch GUT (unit test framework) at a pinned tag into addons/gut (gitignored).
set -euo pipefail
GUT_TAG="${GUT_TAG:-v9.4.0}"
cd "$(dirname "$0")/.."
if [ -f addons/gut/plugin.cfg ] && grep -q "version=\"${GUT_TAG#v}\"" addons/gut/plugin.cfg; then
  echo "GUT ${GUT_TAG} already present"; exit 0
fi
tmp="$(mktemp -d)"
git clone -q --depth 1 --branch "$GUT_TAG" https://github.com/bitwes/Gut "$tmp/gut"
rm -rf addons/gut && mkdir -p addons && cp -r "$tmp/gut/addons/gut" addons/gut
rm -rf "$tmp"
echo "GUT ${GUT_TAG} -> addons/gut"
