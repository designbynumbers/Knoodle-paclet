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
# Currently: nothing. The list is empty and the Windows build compiles against
# unmodified Knoodle. Keep the harness -- the next portability wart goes here.
#
set -euo pipefail
KND="${KND:-Knoodle}"

# shellcheck disable=SC2317  # not called while the patch list is empty
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
# P2: Tools src/TypeName.hpp, PrettyTypeName's last branch was a bare `#elif`
#     where `#else` was meant; clang targeting MSVC reached it and failed with
#     "expected value in expression". P3: Tools src/ToString.hpp formatted
#     Int128 with std::format, and MSVC's STL has no std::formatter<__int128>.
#     Both were carried on the paclet's knoodle-1.1.1 branch and fixed upstream
#     in Tools PR #5 (the _MSVC_STL_VERSION guard), which Knoodle v1.2.0 pins.
#     Never on paclet main; retired at the v1.2.0 repin, 2026-11-11.
#     (The compiler-rt builtins link in ci/build-tools.sh is NOT a src patch and
#     stays: Int128 <-> double conversions still need it on Windows.)

# --- Active (SCRATCH CI branch -- do not merge) ---------------------------------
# Test the Tools fix for OutString's std::filesystem::path printer (path::c_str()
# is const wchar_t * on Windows) before it goes to Henrik: check out the fork
# commit in the nested Tools submodule, and insist that it is exactly one commit
# on top of the Tools that the Knoodle v1.2.0 pin carries.
TOOLS_PR_SHA=35179be81e3e33d0b955f792ce8348802ec3f2c1
T="$KND/submodules/Tensors/submodules/Tools"
echo ">> SCRATCH: Tools -> designbynumbers/Tools windows-path-outstring ($TOOLS_PR_SHA)"
base=$(git -C "$T" rev-parse HEAD)
git -C "$T" fetch -q https://github.com/designbynumbers/Tools.git windows-path-outstring
git -C "$T" checkout -q FETCH_HEAD
if [ "$(git -C "$T" rev-parse HEAD)" != "$TOOLS_PR_SHA" ]; then
  echo "   !! the fork branch moved: $(git -C "$T" rev-parse HEAD)" >&2; exit 1
fi
if [ "$(git -C "$T" rev-parse HEAD^)" != "$base" ]; then
  echo "   !! the fix is not on top of the pinned Tools ($base)" >&2; exit 1
fi
echo "   pinned Tools $base + fix $TOOLS_PR_SHA"
echo "=== temporary Windows src patches applied ==="
