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
# Currently: P2 (Tools' PrettyTypeName). Keep the harness -- the next
# portability wart goes here.
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

# --- Active --------------------------------------------------------------------
# P2: Tools src/TypeName.hpp, PrettyTypeName's last branch is a bare `#elif`
#     (no condition) where `#else` was meant. A compiler only evaluates it when
#     every earlier branch failed, and clang targeting MSVC is the one that gets
#     there: TOOLS_COMPILER_IS_ANY_CLANG is defined as
#       CLANG || APPLE_CLANG || CLANGCL && !defined(_MSC_VER)
#     and && binds tighter than ||, so clang-cl (which defines _MSC_VER) never
#     counts as "any clang". Then: "error: expected value in expression".
#     Still present on HenrikSchumacher/Tools main (5b85258) as of 2026-11-06.
#     Delete when the Knoodle pin carries a Tools with `#else` there.
apply "P2: Tools PrettyTypeName bare #elif -> #else" \
  "submodules/Tensors/submodules/Tools/src/TypeName.hpp" \
  's/^    #elif$/    #else/' \
  '^    #elif$'

echo "=== temporary Windows src patches applied ==="
