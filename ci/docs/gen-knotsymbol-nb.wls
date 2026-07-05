#!/usr/bin/env wolframscript
(* Create Documentation/English/ReferencePages/Symbols/KnotSymbol.nb *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnotSymbol.nb"}];

(* Input cells: built from the code's InputForm string through the front
   end's own parser -- exactly the boxes typing would produce, so the cell
   re-evaluates like ordinary user input. The old ToBoxes[HoldForm[...]]
   made doc inputs display-only no-ops and applied output formatting to
   unevaluated input (see gen-knoodledraw-nb.wls for the full story). *)
heldInputForm[HoldForm[e_]] := ToString[Unevaluated[e], InputForm];
inCell[h_HoldForm] := Cell[BoxData[First @ First @ UsingFrontEnd @ MathLink`CallFrontEnd[
      FrontEnd`UndocumentedTestFEParserPacket[heldInputForm[h], False]]], "Input"];
group[h_HoldForm] := Module[{res = ReleaseHold[h]},
  Cell[CellGroupData[{inCell[h], Cell[BoxData[ToBoxes[res]], "Output"]}, Open]]];
silent[h_HoldForm] := (ReleaseHold[h]; inCell[h]);
text[s_]  := Cell[s, "ExampleText"];
delim     := Cell["", "ExampleDelimiter"];
notes[s_] := Cell[s, "Notes"];

categorization = Cell[CellGroupData[{
   Cell["Categorization", "CategorizationSection"],
   Cell["Symbol", "Categorization", CellLabel -> "Entity Type"],
   Cell["Knoodle", "Categorization", CellLabel -> "Paclet Name"],
   Cell["Knoodle`", "Categorization", CellLabel -> "Context"],
   Cell["Knoodle/ref/KnotSymbol", "Categorization", CellLabel -> "URI"]}, Closed]];

usageSection = Cell[CellGroupData[{
   Cell["KnotSymbol", "ObjectName"],
   Cell[TextData[{
     Cell["   ", "ModInfo"],
     Cell[BoxData[RowBox[{"KnotSymbol", "[",
        RowBox[{StyleBox["c", "TI"], ",", StyleBox["i", "TI"], ",",
          StyleBox["alternating", "TI"], ",", StyleBox["coset", "TI"]}],
        "]"}]], "InlineFormula"],
     "\[LineSeparator]represents a prime knot identified by KnoodleIdentify, \
in KnotInfo naming."}], "Usage"],
   notes["KnotSymbol expressions appear as the keys of the Association that \
KnoodleIdentify returns. c is the knot's minimal crossing number and i its \
index within KnotInfo's per-crossing-number naming scheme (the 2 in 5_2); \
alternating is True or False per KnotInfo's classification; coset names \
which coset of the symmetry group {e, m, r, mr} the identified diagram \
represents (e = identity, m = mirror, r = reverse, mr = both), with \
'/'-joined values when several variants are topologically the same knot, \
e.g. \"e/r\" or \"m/mr\"."],
   notes["Each knot has one KnotInfo symmetry type, which determines its \
possible coset values: chiral (\"e\", \"r\", \"m\", \"mr\"), reversible \
(\"e/r\", \"m/mr\"), negative amphichiral (\"e/mr\", \"m/r\"), positive \
amphichiral (\"e/m\", \"r/mr\"), or fully amphichiral (\"e/m/r/mr\")."],
   notes["KnotSymbol displays in ordinary KnotInfo notation: c with \
subscript i for knots up to 10 crossings, and c immediately followed by \
\"a\" (alternating) or \"n\" (non-alternating) with subscript i from 11 \
crossings up. The coset appears as a superscript, except that a coset \
containing e is the unmodified variant and displays without one."],
   notes["The display is formatting only: the FullForm, pattern matching, \
and equality testing of a KnotSymbol expression are unaffected, and its \
parts can be extracted positionally."]
   }, Open]];

(* ---------- examples ---------- *)
SeedRandom[42];
ex1 = {
   text["KnoodleIdentify returns KnotSymbol keys; Knot[3,1] identifies as \
the mirror-trefoil coset:"],
   group[HoldForm[KnoodleIdentify[Knot[3, 1]]]]};

ex2 = {
   delim,
   text["KnotInfo display notation: the coset superscript is suppressed \
when the coset contains e, and knots of 11 or more crossings carry an \
alternating/non-alternating tag:"],
   group[HoldForm[{KnotSymbol[3, 1, True, "e/r"], KnotSymbol[3, 1, True, "m/mr"],
      KnotSymbol[11, 456, True, "e/r"], KnotSymbol[12, 3541, False, "m"]}]]};

ex3 = {
   delim,
   text["The display is formatting only; the underlying expression is \
unchanged:"],
   group[HoldForm[FullForm[KnotSymbol[3, 1, True, "m/mr"]]]]};

SeedRandom[42];
ex4 = {
   delim,
   text["Extract the crossing number of an identified knot positionally:"],
   silent[HoldForm[ks = First[Keys[KnoodleIdentify[Knot[7, 4]]]];]],
   group[HoldForm[ks[[1]]]]};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, ex2, ex3, ex4}], Open]];

nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
