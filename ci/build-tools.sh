#!/usr/bin/env bash
#
# Build the three Knoodle CLI tools (knoodlesimplify, knoodledraw,
# knoodleidentify) with clang, cross-platform. No Boost, no UMFPACK, no BLAS —
# the dependency-free configuration (mirrors Knoodle's
# tools/compile_without_boost+umfpack.sh), which is what the paclet ships.
#
# Env knobs:
#   KND  path to the Knoodle checkout   (default: Knoodle)
#   OUT  output directory for binaries  (default: build)
#   CXX  compiler                       (default: clang++)
#   OPT  optimization flags             (default: -O2)
#
set -euo pipefail

KND="${KND:-Knoodle}"
OUT="${OUT:-build}"
CXX="${CXX:-clang++}"
OPT="${OPT:--O2}"

mkdir -p "$OUT"

STD="-std=c++20"
FEAT="-fenable-matrix"     # Knoodle's ClangMatrix path needs the matrix extension

INCLUDES=(
  -I"$KND/submodules/Min-Cost-Flow-Class/OPTUtils"
  -I"$KND/submodules/Min-Cost-Flow-Class/MCFClass"
  -I"$KND/submodules/Min-Cost-Flow-Class/MCFSimplex"
  -I"$KND/submodules/Tensors"
)

# Platform-specific bits.
EXE=""
PLATFORM_FLAGS=()
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    EXE=".exe"                       # Windows: threading via the runtime, no -pthread
    # MSVC-target clang: __restrict-qualified pointer types break Tools::function_traits
    # (Tools/FunctionTraits.hpp). Henrik's TOOLS_NO_RESTRICT drops the restrict qualifier.
    PLATFORM_FLAGS+=(-DTOOLS_NO_RESTRICT)
    ;;
  *)
    PLATFORM_FLAGS+=(-pthread)       # POSIX
    ;;
esac

echo "== compiler =="
"$CXX" --version | head -1
echo "== flags: $STD $OPT $FEAT ${PLATFORM_FLAGS[*]:-} =="
echo

for tool in knoodlesimplify knoodledraw knoodleidentify; do
  echo "=== building $tool ==="
  "$CXX" $STD $OPT $FEAT "${INCLUDES[@]}" "${PLATFORM_FLAGS[@]}" \
    "$KND/tools/$tool.cpp" -o "$OUT/$tool$EXE"
  echo "    -> $OUT/$tool$EXE"
done

echo
echo "=== build complete ==="
ls -la "$OUT"
