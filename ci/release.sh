#!/usr/bin/env bash
#
# ci/release.sh [PACLET_TAG] -- build and publish a world-readable Knoodle
# .paclet as a GitHub Release asset on the public paclet repo.
#
# GATED: refuses unless the Knoodle submodule is pinned to an exact Knoodle
# RELEASE TAG, so the released paclet stands only on released, publicly
# distributed Knoodle. Everything the paclet contains from Knoodle traces to
# one public artifact: binaries are compiled in CI *from the Knoodle release
# tarball* (not the submodule clone), and KLUT data is taken from that same
# tarball. Packaging (PacletBuild) runs locally under your Wolfram license.
#
# Flow (create-last): preflight gate -> dispatch release-build CI (tarball) ->
# wait -> download tarball-built binaries + the tarball -> assemble -> build
# .paclet locally -> create the GitHub Release, with the .paclet + notes, last.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"
KND="$REPO/Knoodle"
PACLET_REPO="designbynumbers/Knoodle-paclet"
KNOODLE_REPO="HenrikSchumacher/Knoodle"
WORKFLOW="release-build.yml"

command -v gh >/dev/null            || { echo "gh (GitHub CLI) required"; exit 1; }
command -v wolframscript >/dev/null || { echo "wolframscript required"; exit 1; }

# ------------------------------------------------------------------ preflight
echo "== preflight gate =="

# 1. Release the committed state -- no local edits.
if [ -n "$(git status --porcelain)" ]; then
  echo "ABORT: paclet working tree has uncommitted changes. Commit or stash first."; exit 1; fi

# 2. HARD GATE: submodule pin is EXACTLY a Knoodle release tag.
git -C "$KND" fetch --tags -q || true
if ! KVER=$(git -C "$KND" describe --exact-match --tags HEAD 2>/dev/null); then
  cat >&2 <<EOF
ABORT: the Knoodle submodule pin ($(git -C "$KND" describe --tags --always)) is not an
       exact Knoodle release tag. A paclet release must stand on a *released*
       Knoodle -- otherwise it ships binaries built from upstream code that
       exists in no public Knoodle release. Cut/choose a Knoodle release, re-pin
       the submodule to that tag, commit, and retry. (For local debugging of an
       unreleased Knoodle, use ci/build-paclet.sh instead.)
EOF
  exit 1
fi
echo "   Knoodle release tag: $KVER"

# 3. No submodule drift (committed pin == checked-out pin).
if git -C "$REPO" submodule status Knoodle | grep -q '^[+-]'; then
  echo "ABORT: Knoodle submodule is not at its committed pin (local drift/uninitialized)."; exit 1; fi

# 4. That release actually ships the vendored tarball we build from.
KVER_NO_V="${KVER#v}"
TARBALL="knoodle-${KVER_NO_V}-vendored.tar.gz"
if ! gh release view "$KVER" --repo "$KNOODLE_REPO" --json assets --jq '.assets[].name' \
     | grep -qx "$TARBALL"; then
  echo "ABORT: Knoodle release $KVER has no vendored tarball asset '$TARBALL'."; exit 1; fi
echo "   source tarball: $TARBALL"

# Soft check: warn if not the latest Knoodle release.
LATEST=$(gh release view --repo "$KNOODLE_REPO" --json tagName --jq '.tagName' 2>/dev/null || true)
[ -n "$LATEST" ] && [ "$LATEST" != "$KVER" ] && \
  echo "   NOTE: pinned to $KVER, but the latest Knoodle release is $LATEST."

PVER=$(wolframscript -code 'First[Get["PacletInfo.wl"]]["Version"]' | tr -d '"[:space:]')
PACLET_TAG="${1:-v$PVER}"
echo "   paclet version: $PVER   (release tag: $PACLET_TAG)"
if gh release view "$PACLET_TAG" --repo "$PACLET_REPO" >/dev/null 2>&1; then
  echo "ABORT: paclet release $PACLET_TAG already exists on $PACLET_REPO."; exit 1; fi

# --------------------------------------------- CI: binaries from the tarball
echo "== dispatching $WORKFLOW to compile binaries from $TARBALL =="
gh workflow run "$WORKFLOW" --repo "$PACLET_REPO" -f knoodle_version="$KVER"
echo "   waiting for the run to register..."
sleep 10
RUN_ID=$(gh run list --repo "$PACLET_REPO" --workflow "$WORKFLOW" --event workflow_dispatch \
         --limit 1 --json databaseId --jq '.[0].databaseId')
echo "   run $RUN_ID -- watching (fails here if any platform fails to build) ..."
gh run watch "$RUN_ID" --repo "$PACLET_REPO" --exit-status

# ---------------------------------------------------------- assemble locally
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
STAGE="$TMP/Knoodle"; OUT="$TMP/out"; ART="$TMP/artifacts"; TB="$TMP/tarball"
mkdir -p "$STAGE" "$OUT" "$ART" "$TB"

echo "== downloading tarball-built binaries from run $RUN_ID =="
gh run download "$RUN_ID" --repo "$PACLET_REPO" --dir "$ART"

echo "== downloading Knoodle $KVER tarball for KLUT data =="
gh release download "$KVER" --repo "$KNOODLE_REPO" --pattern "$TARBALL" --dir "$TB"
tar xzf "$TB/$TARBALL" -C "$TB"
TBDIR="$TB/knoodle-${KVER_NO_V}-vendored"

echo "== assembling staging =="
cp "$REPO/PacletInfo.wl" "$STAGE/"
[ -f "$REPO/LICENSE" ] && cp "$REPO/LICENSE" "$STAGE/"
cp -R "$REPO/Kernel" "$STAGE/Kernel"
cp -R "$REPO/Documentation" "$STAGE/Documentation"
mkdir -p "$STAGE/Resources/Klut"
cp -R "$REPO/Resources/ExampleData" "$STAGE/Resources/ExampleData"
cp "$TBDIR/data/Klut/"Klut_Keys_*.bin "$TBDIR/data/Klut/"Klut_Values_*.tsv "$STAGE/Resources/Klut/"
for a in "$ART"/knoodle-tools-*; do
  sid="${a##*knoodle-tools-}"
  mkdir -p "$STAGE/Resources/$sid"
  cp "$a"/* "$STAGE/Resources/$sid/"
  chmod +x "$STAGE/Resources/$sid/"* 2>/dev/null || true
done
echo "   platforms staged: $(ls "$STAGE/Resources" | grep -v '^Klut$' | tr '\n' ' ')"

echo "== building .paclet (local Wolfram license) =="
PACLET=$(wolframscript -file "$REPO/ci/package-paclet.wls" "$STAGE" "$OUT" | tail -1)
[ -f "$PACLET" ] || { echo "paclet build failed"; exit 1; }
mkdir -p "$REPO/dist"; DEST="$REPO/dist/$(basename "$PACLET")"; cp "$PACLET" "$DEST"
echo "   $DEST"

# ------------------------------------------- create the release LAST, complete
echo "== creating GitHub release $PACLET_TAG with the .paclet asset (create-last) =="
ASSET_URL="https://github.com/$PACLET_REPO/releases/download/$PACLET_TAG/$(basename "$DEST")"
NOTES=$(cat <<EOF
Knoodle paclet $PVER — built against Knoodle $KVER ($TARBALL).

Install (any platform, no download needed):

    PacletInstall["$ASSET_URL"]

then \`Needs["Knoodle\`"]\`.
EOF
)
gh release create "$PACLET_TAG" "$DEST" \
  --repo "$PACLET_REPO" --title "Knoodle paclet $PVER" --notes "$NOTES"
echo "== released: https://github.com/$PACLET_REPO/releases/tag/$PACLET_TAG =="
