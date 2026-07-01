#!/usr/bin/env bash
#
# TEMPORARY downstream patches applied to the *ephemeral* Knoodle CI checkout so
# the native-Windows (MSVC-target clang) build compiles. These are NOT committed
# to Knoodle — each one corresponds to an upstream portability fix to be handed
# off to Henrik (~/Knoodle/handoff/). As each upstream fix lands and the paclet's
# Knoodle submodule is bumped, delete the corresponding entry here.
#
# This file is intentionally the single source of truth for "what still needs
# fixing upstream to build Knoodle on Windows."
#
set -euo pipefail
KND="${KND:-Knoodle}"

apply () {  # description  file  sed-expr
  local desc="$1" f="$2" expr="$3"
  echo ">> $desc"
  echo "   $KND/$f"
  # Portable in-place edit: GNU `sed -i EXPR` and BSD/macOS `sed -i '' EXPR`
  # disagree, so use a temp file (plain `sed` is identical on both).
  sed "$expr" "$KND/$f" > "$KND/$f.tmp" && mv "$KND/$f.tmp" "$KND/$f"
}

# --- P1 -----------------------------------------------------------------------
# src/OrthoDraw/Bends.hpp:164
#   std::uniform_int_distribution<Int8> dice( -1, 1 );   (Int8 = std::int8_t)
# MSVC's <random> static_asserts that the type is one of short/int/long/long long
# (+unsigned) — N4950 [rand.req.genl]/1.5 — and rejects char types. libc++ and
# libstdc++ accept it, so it only breaks on the Windows target.
# Fix: widen the distribution to int (the draw is copy-assigned to an Int8 at
# line 176, a narrowing *warning*, not an error).
apply "P1: uniform_int_distribution<Int8> -> <int> (MSVC <random> rejects char types)" \
  "src/OrthoDraw/Bends.hpp" \
  's/std::uniform_int_distribution<Int8>/std::uniform_int_distribution<int>/'

echo "=== temporary Windows src patches applied ==="
