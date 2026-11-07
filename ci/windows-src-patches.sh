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

# P3: Tools src/ToString.hpp, the generic integer ToString is
#     `return std::format("{:d}",value);`, and MSVC's STL has no
#     std::formatter<__int128> (libc++ and libstdc++ do). Knoodle reaches it
#     with Int128 values: Prosector/IntersectionTime_Hybrid.hpp logs a
#     DepressedCubic via TOOLS_LOGDUMP -> ToString(DepressedCubic) ->
#     ToString(Int128). The replacement converts integers wider than 64 bits by
#     hand, using only 64-bit division (clang targeting MSVC does not link the
#     compiler-rt helpers that 128-bit division needs). Same diagnostics text
#     everywhere; it is not on a hot path. Still on Tools main (5b85258).
#     Delete when Tools' ToString handles 128-bit integers itself.
apply "P3: Tools ToString for 128-bit integers without std::format" \
  "submodules/Tensors/submodules/Tools/src/ToString.hpp" \
  's#^            return std::format("{:d}",value);$#            if constexpr ( sizeof(T) > 8 ) { using U = unsigned __int128; const bool neg = value < T(0); U u = neg ? U(0) - static_cast<U>(value) : static_cast<U>(value); std::uint64_t d[4] = { std::uint64_t(u >> 96) \& 0xFFFFFFFFu, std::uint64_t(u >> 64) \& 0xFFFFFFFFu, std::uint64_t(u >> 32) \& 0xFFFFFFFFu, std::uint64_t(u) \& 0xFFFFFFFFu }; std::string s; do { std::uint64_t r = 0; for( int i = 0; i < 4; ++i ) { const std::uint64_t cur = (r << 32) | d[i]; d[i] = cur / 10; r = cur % 10; } s.insert(s.begin(), static_cast<char>('\''0'\'' + r)); } while( d[0] | d[1] | d[2] | d[3] ); if( neg ) { s.insert(s.begin(), '\''-'\''); } return s; } else { return std::format("{:d}",value); }#' \
  '^            return std::format("{:d}",value);$'

echo "=== temporary Windows src patches applied ==="
