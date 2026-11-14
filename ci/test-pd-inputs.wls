#!/usr/bin/env wolframscript
(* ::Package:: *)

(* test-pd-inputs.wls [PACLET]
 *
 * End-to-end check of the PD-code input forms that toTSV (Kernel/Knoodle.wl)
 * accepts, run through the real tools of a BUILT paclet:
 *
 *   - native rows 4, 5 or 7 wide, numbered from 0 (Knoodle's own convention)
 *     or from 1 (KnotTheory, SnapPy, the printed tables), which toTSV
 *     renumbers to 0 before the tool sees them;
 *   - SnapPy-style PD strings, "[(1,4,2,5),...]" or "[[1,4,2,5],...]", with
 *     arbitrary whitespace and line breaks, from 0 or 1;
 *   - multi-summand lists, renumbered summand by summand;
 *   - an invalid code, which must come back $Failed rather than be misread;
 *   - KnotData names and specs, which must be unaffected.
 *
 * Every form goes through KnoodleIdentify, KnoodleSimplify and KnoodleDraw.
 * Then a round trip for several knots: simplify, rewrite the result as a
 * 1-indexed SnapPy string (and as 1-indexed 7-wide rows), identify that, and
 * compare with identifying the original.
 *
 * PACLET is a .paclet archive or an unpacked paclet directory. It defaults to
 * the newest build-local/Knoodle-*.paclet, i.e. what ci/build-paclet.sh just
 * built. The paclet is loaded with PacletDirectoryLoad in this kernel only;
 * nothing is installed. The script stops if PacletObject["Knoodle"] resolves
 * anywhere else (an installed release would otherwise win silently).
 *
 * Prints one PASS/FAIL line per check; exits 0 only if every check passes.
 *)

repo = ParentDirectory[DirectoryName[$InputFileName]];

arg = If[Length[Rest[$ScriptCommandLine]] >= 1, First[Rest[$ScriptCommandLine]],
  Last[SortBy[FileNames["Knoodle-*.paclet", FileNameJoin[{repo, "build-local"}]], FileDate],
    Print["no PACLET given and no build-local/Knoodle-*.paclet; run ci/build-paclet.sh first"]; Exit[1]]];
arg = ExpandFileName[arg];

(* A .paclet is a zip archive; ExtractArchive goes by the extension. The
   unpacked copy (KLUT tables included, ~25 MB) is removed on every exit. *)
tmpDir = None;
finish[code_] := (
  If[tmpDir =!= None, Quiet@DeleteDirectory[tmpDir, DeleteContents -> True]];
  Exit[code]);
pacletDir = Which[
  DirectoryQ[arg], arg,
  FileExistsQ[arg] && StringEndsQ[arg, ".paclet"],
    tmpDir = CreateDirectory[];
    ExtractArchive[CopyFile[arg, FileNameJoin[{tmpDir, "paclet.zip"}]], tmpDir];
    DirectoryName[First[FileNames["PacletInfo.wl", tmpDir, 2],
      Print["no PacletInfo.wl inside ", arg]; finish[1]]],
  True, Print["not a .paclet or a directory: ", arg]; finish[1]];
pacletDir = StringTrim[pacletDir, $PathnameSeparator ~~ EndOfString];

PacletDirectoryLoad[pacletDir];
Needs["Knoodle`"];
loc = PacletObject["Knoodle"]["Location"];
Print["paclet: ", loc, "  (version ", PacletObject["Knoodle"]["Version"], ")"];
If[!StringStartsQ[loc, pacletDir],
  Print["WRONG PACLET LOADED (expected one under ", pacletDir, ") -- aborting"]; finish[1]];

pass = 0; fail = 0;
ok[name_, test_, info_ : ""] := If[TrueQ[test],
  pass++; Print["PASS  ", name],
  fail++; Print["FAIL  ", name, "   got: ", ToString[info, InputForm]]];

(* The rows of a one-summand PlanarDiagramComplex, as integers. *)
rowsOf[pdc_PlanarDiagramComplex] := Module[{ls = StringSplit[pdc[[1, "serialized"]], "\n"]},
  If[Count[ls, l_ /; StringStartsQ[l, "s"]] =!= 1, Return[$Failed]];
  ToExpression /@ StringSplit[#, "\t"] & /@ Select[ls, StringContainsQ[#, "\t"] &]];
rowsOf[_] := $Failed;

(* Only the first four columns are arc labels; sign and colors stay put. *)
oneIdx[rows_] := Join[Take[#, 4] + 1, Drop[#, 4]] & /@ rows;
cols[rows_, n_] := Take[#, n] & /@ rows;
snappy[rows_, {l_, r_}, sep_] :=
  "[" <> StringRiffle[(l <> StringRiffle[ToString /@ #, ", "] <> r) & /@ rows, sep] <> "]";

(* ---- One trefoil, many spellings, all three functions ---- *)
t0 = rowsOf[KnoodleSimplify[{3, 1}]];   (* 0-indexed, 7 wide: 4 arcs, sign, 2 colors *)
ref = KnoodleIdentify[{3, 1}];
If[t0 === $Failed || !AssociationQ[ref] || Length[ref] =!= 1,
  Print["cannot get a reference trefoil (", t0, ", ", ref, ") -- aborting"]; finish[1]];
Print["reference: ", ref, "   rows: ", t0];
t1 = oneIdx[t0];

forms = {
  "0-indexed 7-wide rows"                     -> t0,
  "1-indexed 7-wide rows"                     -> t1,
  "1-indexed 5-wide rows (signed)"            -> cols[t1, 5],
  "1-indexed 4-wide rows"                     -> cols[t1, 4],
  "SnapPy string, 1-indexed, (..)"            -> snappy[cols[t1, 4], {"(", ")"}, ","],
  "SnapPy string, 1-indexed, [..] + newlines" -> snappy[cols[t1, 4], {"[", "]"}, ",\n   "],
  "SnapPy string, 0-indexed"                  -> snappy[cols[t0, 4], {"(", ")"}, ", "],
  "SnapPy string, 1-indexed, 5-tuples"        -> snappy[cols[t1, 5], {"(", ")"}, ","]};

Do[
  {name, in} = List @@ f;
  id = KnoodleIdentify[in];
  ok["Identify | " <> name, id === ref, id];
  s = KnoodleSimplify[in];
  ok["Simplify | " <> name, Head[s] === PlanarDiagramComplex && KnoodleIdentify[s] === ref, s];
  d = KnoodleDraw[in];
  ok["Draw     | " <> name, MatchQ[d, _Graphics | {__Graphics}], Head[d]],
  {f, forms}];

(* ---- Multi-summand: two trefoils and an unknot summand = the granny knot.
   Every row in one input must have the same width (the tool rejects a mix),
   but the numbering base may differ from summand to summand. ---- *)
granny = ref /. 1 -> 2;
Do[
  {name, in} = List @@ m;
  g = KnoodleIdentify[in];
  ok["Identify | multi-summand: " <> name, g === granny, g];
  s = KnoodleSimplify[in];
  ok["Simplify | multi-summand: " <> name, Head[s] === PlanarDiagramComplex && KnoodleIdentify[s] === granny, s],
  {m, {
    "1-indexed 7-wide x2 + unknot"         -> {t1, {}, t1},
    "1-indexed 4-wide x2 + unknot"         -> {cols[t1, 4], {}, cols[t1, 4]},
    "0-indexed + 1-indexed summands mixed" -> {t0, {}, t1}}}];

(* ---- Invalid in both conventions: passed through untouched, so the tool
   rejects it and the wrapper returns $Failed (its message is expected). ---- *)
bad = ReplacePart[cols[t1, 4], {1, 2} -> 99];
b = Quiet[KnoodleIdentify[bad]];
ok["Identify | invalid code -> $Failed", b === $Failed, b];

(* ---- Strings that are not PD codes still mean KnotData names ---- *)
ok["Identify | KnotData name \"Trefoil\"", KnoodleIdentify["Trefoil"] === ref, KnoodleIdentify["Trefoil"]];

(* ---- Round trip. KnotData has space curves only up to 8 crossings. ---- *)
Do[
  If[MissingQ[KnotData[k, "SpaceCurve"]], ok["Round trip " <> ToString[k], False, "no KnotData space curve"]; Continue[]];
  r0 = rowsOf[KnoodleSimplify[k]];
  idk = KnoodleIdentify[k];
  If[r0 === $Failed || !AssociationQ[idk],
    ok["Round trip " <> ToString[k], False, {r0, idk}]; Continue[]];
  s4 = snappy[cols[oneIdx[r0], 4], {"(", ")"}, ", "];
  ok["Round trip " <> ToString[k] <> " via 1-indexed SnapPy 4-tuples -> " <> ToString[idk],
    KnoodleIdentify[s4] === idk, KnoodleIdentify[s4]];
  ok["Round trip " <> ToString[k] <> " via 1-indexed 7-wide rows",
    KnoodleIdentify[oneIdx[r0]] === idk, KnoodleIdentify[oneIdx[r0]]],
  {k, {{3, 1}, {4, 1}, {5, 2}, {6, 2}, {7, 4}, {8, 19}, {8, 20}}}];

Print["\n", pass, " passed, ", fail, " failed"];
finish[If[fail === 0, 0, 1]];
