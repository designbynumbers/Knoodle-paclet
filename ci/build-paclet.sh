#!/usr/bin/env bash
#
# ci/build-paclet.sh -- build a LOCAL, bleeding-edge Knoodle .paclet for THIS
# machine, to install and debug. Source is the Knoodle *submodule* at its
# current pin (which may be ahead of the latest Knoodle release); KLUT data is
# the submodule's own LFS data at that pin, so binaries + data are coherent for
# whatever commit you're debugging. Binaries are compiled for THIS platform
# only. NOT gated, NEVER uploaded -- for public releases use ci/release.sh.
#
# Packaging (PacletBuild) runs under your own Wolfram license -- no on-demand
# entitlement, no Service Credits.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
# Knoodle source to build from. Defaults to the pinned submodule; set KNOODLE_SRC
# to build from another checkout (e.g. a local fix/feature branch of Knoodle
# ahead of the pin -- exactly what "bleeding-edge dev paclet" means).
KND="${KNOODLE_SRC:-$REPO/Knoodle}"

command -v wolframscript >/dev/null || { echo "wolframscript not found on PATH"; exit 1; }

echo "== Knoodle submodule pin: $(git -C "$KND" describe --tags --always 2>/dev/null) (bleeding-edge; dev only) =="

echo "== ensuring nested submodules + KLUT LFS data at the pin =="
git -C "$KND" submodule update --init --recursive
git -C "$KND" lfs pull --include "data/Klut/*"

SID=$(wolframscript -code '$SystemID' | tr -d '"[:space:]')
echo "== building for \$SystemID = $SID =="

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; STAGE="$TMP/Knoodle"; OUT="$TMP/out"
mkdir -p "$BIN" "$STAGE" "$OUT"

echo "== compiling tools from the submodule pin =="
KND="$KND" OUT="$BIN" bash "$REPO/ci/build-tools.sh" >/dev/null
echo "   built: $(ls "$BIN" | tr '\n' ' ')"

echo "== assembling staging =="
cp "$REPO/PacletInfo.wl" "$STAGE/"
[ -f "$REPO/LICENSE" ] && cp "$REPO/LICENSE" "$STAGE/"
cp -R "$REPO/Kernel" "$STAGE/Kernel"
cp -R "$REPO/Documentation" "$STAGE/Documentation"
mkdir -p "$STAGE/Resources/$SID" "$STAGE/Resources/Klut"
cp -R "$REPO/Resources/ExampleData" "$STAGE/Resources/ExampleData"
cp "$BIN/"* "$STAGE/Resources/$SID/"
chmod +x "$STAGE/Resources/$SID/"* 2>/dev/null || true
cp "$KND/data/Klut/"Klut_Keys_*.bin "$KND/data/Klut/"Klut_Values_*.tsv "$STAGE/Resources/Klut/"

echo "== building .paclet (local Wolfram license) =="
PACLET=$(wolframscript -file "$REPO/ci/package-paclet.wls" "$STAGE" "$OUT" | tail -1)
[ -f "$PACLET" ] || { echo "build failed"; exit 1; }

mkdir -p "$REPO/build-local"
DEST="$REPO/build-local/$(basename "$PACLET")"
cp "$PACLET" "$DEST"
echo
echo "== done: $DEST =="
echo "Install with:  PacletInstall[\"$DEST\", ForceVersionInstall -> True]"
