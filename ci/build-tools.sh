#!/usr/bin/env bash
#
# Build the four Knoodle CLI tools (knoodlesimplify, knoodledraw,
# knoodleidentify, knoodleprove) with clang, cross-platform. No Boost, no UMFPACK, no BLAS —
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
PLATFORM_LIBS=()
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    EXE=".exe"                       # Windows: threading via the runtime, no -pthread
    # MSVC-target clang: __restrict-qualified pointer types break Tools::function_traits
    # (Tools/FunctionTraits.hpp). Henrik's TOOLS_NO_RESTRICT drops the restrict qualifier.
    PLATFORM_FLAGS+=(-DTOOLS_NO_RESTRICT)
    # Knoodle >= 1.1 does exact Int128 arithmetic (Prosector_Int), and Int128 <->
    # double conversions (__floattidf, ...) live in compiler-rt's builtins
    # library, which clang does not link for the MSVC target. Ask clang where
    # its own copy is and link it explicitly; fail loudly if it is missing.
    RT_BUILTINS="$("$CXX" --rtlib=compiler-rt -print-libgcc-file-name 2>/dev/null || true)"
    if [ -z "$RT_BUILTINS" ] || [ ! -f "$RT_BUILTINS" ]; then
      echo "!! compiler-rt builtins library not found (clang said: '${RT_BUILTINS}')" >&2
      exit 1
    fi
    PLATFORM_LIBS+=("$RT_BUILTINS")
    ;;
  *)
    PLATFORM_FLAGS+=(-pthread)       # POSIX
    ;;
esac

echo "== compiler =="
"$CXX" --version | head -1
echo "== flags: $STD $OPT $FEAT ${EXTRA:-} ${PLATFORM_FLAGS[*]:-} =="
echo "== libs:  ${PLATFORM_LIBS[*]:-(none)} =="
echo

for tool in knoodlesimplify knoodledraw knoodleidentify knoodleprove; do
  echo "=== building $tool ==="
  "$CXX" $STD $OPT $FEAT ${EXTRA:-} "${INCLUDES[@]}" "${PLATFORM_FLAGS[@]}" \
    "$KND/tools/$tool.cpp" ${PLATFORM_LIBS[@]+"${PLATFORM_LIBS[@]}"} -o "$OUT/$tool$EXE"
  echo "    -> $OUT/$tool$EXE"
done

echo
echo "=== build complete ==="
ls -la "$OUT"
