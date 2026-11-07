#!/usr/bin/env bash
#
# TEMPORARY downstream patches applied to the *ephemeral* Knoodle CI checkout so
# the native-Windows (MSVC-target clang) build compiles. These are NOT committed
# to Knoodle -- each one corresponds to an upstream portability fix to be handed
# off to Henrik (~/Knoodle/handoff/). As each upstream fix lands and the paclet's
# Knoodle submodule is bumped, delete the corresponding entry here.
#
# This file is intentionally the single source of truth for "what still needs
# fixing upstream to build Knoodle on Windows."
#
# Currently: P2 (Tools' PrettyTypeName), P3 (Tools' ToString of Int128).
# Keep the harness -- the next portability wart goes here.
#
set -euo pipefail
KND="${KND:-Knoodle}"

apply () {  # description  file  sed-expr  match-pattern
  local desc="$1" f="$2" expr="$3" pat="$4"
  echo ">> $desc"
  echo "   $KND/$f"
  # A patch that no longer matches is a patch whose fix landed upstream: say so
  # and fail, rather than silently rewriting nothing. (P1 below sat here as a
  # no-op for a while precisely because a stale sed is invisible.)
  if ! grep -q "$pat" "$KND/$f"; then
    echo "   !! pattern not found -- fixed upstream? delete this entry." >&2
    exit 1
  fi
  # Portable in-place edit: GNU `sed -i EXPR` and BSD/macOS `sed -i '' EXPR`
  # disagree, so use a temp file (plain `sed` is identical on both).
  sed "$expr" "$KND/$f" > "$KND/$f.tmp" && mv "$KND/$f.tmp" "$KND/$f"
}

# --- Retired -------------------------------------------------------------------
# P1: src/OrthoDraw/Bends.hpp, std::uniform_int_distribution<Int8> -> <int>.
#     MSVC's <random> static_asserts the type is one of short/int/long/long long
#     (N4950 [rand.req.genl]/1.5) and rejects char types; libc++/libstdc++ accept
#     it, so it only broke the Windows target. Henrik made the change himself
#     rather than merging PR #17 -- Bends.hpp:165 is `<int>` upstream, with a
#     comment recording the constraint. Removed 2026-08-07.

# --- Active (SCRATCH CI branch -- do not merge) ---------------------------------
# P2 retired: Tools d3806b26, in the Knoodle main pin, has `#else` there.
# P3 replaced: test HenrikSchumacher/Tools#5 itself. Check out the PR's commit in
# the nested Tools submodule, and insist that it is exactly one commit on top of
# the Tools that the Knoodle pin carries.
TOOLS_PR_SHA=83632d99ce8dc488c24d401c28884ce207e455ef
T="$KND/submodules/Tensors/submodules/Tools"
echo ">> SCRATCH: Tools -> designbynumbers/Tools windows-clang-msvc-fixes ($TOOLS_PR_SHA)"
base=$(git -C "$T" rev-parse HEAD)
git -C "$T" fetch -q https://github.com/designbynumbers/Tools.git windows-clang-msvc-fixes
git -C "$T" checkout -q FETCH_HEAD
if [ "$(git -C "$T" rev-parse HEAD)" != "$TOOLS_PR_SHA" ]; then
  echo "   !! the fork branch moved: $(git -C "$T" rev-parse HEAD)" >&2; exit 1
fi
if [ "$(git -C "$T" rev-parse HEAD^)" != "$base" ]; then
  echo "   !! the PR commit is not on top of the pinned Tools ($base)" >&2; exit 1
fi
echo "   pinned Tools $base + PR commit $TOOLS_PR_SHA"

echo "=== temporary Windows src patches applied ==="
