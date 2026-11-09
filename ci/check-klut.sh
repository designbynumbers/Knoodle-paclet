#!/usr/bin/env bash
#
# ci/check-klut.sh DIR [KNOODLEIDENTIFY] -- check the KLUT tables staged in DIR
# before they are packaged, so a damaged or partial copy stops the build here
# rather than at a user's first KnoodleIdentify.
#
# Knoodle after v1.1.0 ships data/Klut/Klut_Manifest.txt, listing every table
# file with its size, key count and SHA-256, and knoodleidentify checks the
# tables against it on every run. So the paclet ships the manifest beside the
# tables, and this script checks the staged copy:
#
#   - with a Klut_Manifest.txt in DIR: every file it lists is present, is not a
#     Git LFS pointer, and has the listed size and SHA-256, and it lists all 22
#     table files (Klut_Keys_03.bin .. Klut_Values_13.tsv). Given a
#     knoodleidentify that runs on this machine, also runs
#     `knoodleidentify --verify-tables --data-dir=DIR`, which is the tool's own
#     verdict on the set (and a smoke test of the binary).
#   - without one (a Knoodle pin from before the manifest): only that all 22
#     table files are present, non-empty, and not LFS pointers.
set -euo pipefail

DIR="${1:?usage: ci/check-klut.sh DIR [KNOODLEIDENTIFY]}"
KI="${2:-}"
MAN="$DIR/Klut_Manifest.txt"

fail() { printf 'check-klut: %s\n' "$*" >&2; exit 1; }
sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
lfs_pointer() { head -c 64 "$1" | grep -q '^version https://git-lfs.github.com/spec/'; }

if [ ! -f "$MAN" ]; then
  n=0
  for c in 03 04 05 06 07 08 09 10 11 12 13; do
    for f in "Klut_Keys_$c.bin" "Klut_Values_$c.tsv"; do
      [ -s "$DIR/$f" ] || fail "$DIR/$f is missing or empty"
      lfs_pointer "$DIR/$f" && fail "$DIR/$f is a Git LFS pointer, not a table (run git lfs pull)"
      n=$((n + 1))
    done
  done
  echo "check-klut: $n table files present in $DIR (no Klut_Manifest.txt at this Knoodle pin, so presence only)"
  exit 0
fi

head -n 3 "$MAN" | grep -qx 'klut-manifest 1' || fail "$MAN is not a version-1 KLUT manifest"
n=0
while read -r name bytes keys sum rest; do
  case "$name" in ''|'#'*|klut-manifest|set) continue ;; esac
  [ -n "$sum" ] && [ -z "${rest:-}" ] || fail "$MAN: malformed line for $name"
  f="$DIR/$name"
  [ -f "$f" ] || fail "$f is missing (listed in Klut_Manifest.txt)"
  lfs_pointer "$f" && fail "$f is a Git LFS pointer, not a table (run git lfs pull)"
  have=$(wc -c < "$f" | tr -d '[:space:]')
  [ "$have" = "$bytes" ] || fail "$f is $have bytes; Klut_Manifest.txt says $bytes"
  [ "$(sha256 "$f")" = "$sum" ] || fail "$f does not match its SHA-256 in Klut_Manifest.txt"
  n=$((n + 1))
done < "$MAN"
[ "$n" = 22 ] || fail "$MAN lists $n table files, not 22"
echo "check-klut: $n table files in $DIR match Klut_Manifest.txt (table set $(awk '$1 == "set" { print $2 }' "$MAN"))"

if [ -n "$KI" ]; then
  if out=$("$KI" --verify-tables --data-dir="$DIR" 2>&1); then
    echo "   $out"
  else
    fail "knoodleidentify --verify-tables refused $DIR:
$out"
  fi
fi
