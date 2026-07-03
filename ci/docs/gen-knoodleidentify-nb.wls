#!/usr/bin/env wolframscript
(* Regenerate Documentation/English/ReferencePages/Symbols/KnoodleIdentify.nb
   with full Notes + options table + genuinely-evaluated examples. *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out    = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnoodleIdentify.nb"}];
$review = FileNameJoin[{$TemporaryDirectory, "knoodle-doc-review"}]; Quiet[CreateDirectory[$review]];

$png = 0;
inCell[h_HoldForm] := Cell[BoxData[ToBoxes[h]], "Input"];
group[h_HoldForm] := Module[{res = ReleaseHold[h]},
  Cell[CellGroupData[{inCell[h], Cell[BoxData[ToBoxes[res]], "Output"]}, Open]]];
silent[h_HoldForm] := (ReleaseHold[h]; inCell[h]);
text[s_]  := Cell[s, "ExampleText"];
delim     := Cell["", "ExampleDelimiter"];
notes[s_] := Cell[s, "Notes"];
optRow[nameBox_, defBox_, desc_String] :=
  {Cell["      ", "ModInfo"], nameBox, defBox, Cell[desc, "TableText"]};

(* Shared PD-code explainer cells (defines pdExplainerCells). *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "pd-explainer.wls"}]];

categorization = Cell[CellGroupData[{
   Cell["Categorization", "CategorizationSection"],
   Cell["Symbol", "Categorization", CellLabel -> "Entity Type"],
   Cell["Knoodle", "Categorization", CellLabel -> "Paclet Name"],
   Cell["Knoodle`", "Categorization", CellLabel -> "Context"],
   Cell["Knoodle/ref/KnoodleIdentify", "Categorization", CellLabel -> "URI"]}, Closed]];

usageSection = Cell[CellGroupData[{
   Cell["KnoodleIdentify", "ObjectName"],
   Cell[TextData[{
     Cell["   ", "ModInfo"],
     Cell[BoxData[RowBox[{"KnoodleIdentify", "[", StyleBox["input", "TI"], "]"}]],
      "InlineFormula"],
     "\[LineSeparator]identifies the knot type of a knot diagram by looking \
it up in Knoodle's knot lookup table (KLUT)."}], "Usage"],
   notes["KnoodleIdentify returns an Association from each identified prime \
summand, a KnotSymbol[c, i, alternating, coset], to its integer multiplicity. \
A connect sum of several prime knots gives one entry per distinct prime \
factor, with the factor's multiplicity as the value. The unknot gives <||>, \
the empty association: an unknot summand is the identity element for connect \
sum, so it is simply omitted."],
   notes["input accepts the same representations as KnoodleDraw. The lookup \
is self-contained: it decomposes and simplifies internally, so input need not \
be simplified first."],
   notes["A summand with more crossings than the lookup table covers comes \
back as Unidentified[n, pd] -> multiplicity, where pd is the summand's own \
signed PD code, for offline analysis. A summand inside the table's range \
that still fails to resolve comes back as NotFound[n, pd] -> multiplicity \
instead."],
   notes["KnoodleIdentify only identifies knots. A genuine link (more than \
one component) fails with $Failed and a KnoodleIdentify::link message; apply \
KnoodleSimplify with \"Unite\" -> True first if the components should be \
treated as connect-summed into a single knot."],
   notes["3D geometry is randomly rotated before being projected to a \
diagram, as in KnoodleDraw and KnoodleSimplify -- without this a highly \
symmetric curve can hit a degenerate projection and fail. Set \
\"RandomizeProjection\" -> False for the plain z-axis projection; if the \
projection then degenerates, KnoodleIdentify returns $Failed with a \
KnoodleIdentify::failed message."],
   notes["The following options can be given:"],
   Cell[BoxData[GridBox[{
      optRow[ToBoxes["MaxCrossings"], "Automatic",
       "restrict the lookup to subtables with at most this many crossings \
(3 to 13); Automatic is the table's full range. Knots above a restricted \
range come back as NotFound."],
      optRow[ToBoxes["RandomizeProjection"], "True",
       "randomly rotate 3D input before projecting, avoiding degenerate \
projections; set False for reproducibility"]
      }]], "3ColumnTableMod"]
   }, Open]];

(* ---------- examples ---------- *)
SeedRandom[42];
ex1 = {
   text["Identify the trefoil knot:"],
   group[HoldForm[KnoodleIdentify[Knot[3, 1]]]]};

SeedRandom[42];
ex2 = {
   delim,
   text["Identify a knot by its KnotData name; the coset field reports that \
the figure-eight knot is fully amphichiral:"],
   group[HoldForm[KnoodleIdentify["FigureEight"]]]};

ex3 = {
   delim,
   text["A composite knot reports each distinct prime factor with its \
multiplicity. The granny knot is the connect sum of two like-handed \
trefoils, given here as two PD-code summands:"],
   silent[HoldForm[granny = {
       {{5, 2, 0, 3, -1, 3, 3}, {3, 0, 4, 1, -1, 3, 3}, {1, 4, 2, 5, -1, 3, 3}},
       {{5, 2, 0, 3, -1, 3, 3}, {3, 0, 4, 1, -1, 3, 3}, {1, 4, 2, 5, -1, 3, 3}}};]],
   group[HoldForm[KnoodleIdentify[granny]]]};

ex4 = {
   delim,
   text["The unknot identifies as the empty association:"],
   group[HoldForm[KnoodleIdentify[{{}}]]]};

ex5 = {
   delim,
   text["Both KnoodleSimplify and KnoodleIdentify handle large geometric \
input quickly. Generate a Gaussian random polygon with 5000 vertices:"],
   silent[HoldForm[GaussianRandomPolygon[n_] := Accumulate[Standardize[
       RandomVariate[NormalDistribution[], {n, 3}], Mean, 1 &]]]],
   silent[HoldForm[SeedRandom[1]; P = GaussianRandomPolygon[5000];]],
   text["Simplifying decomposes it into a connect sum of 14 prime summands, \
in a few hundredths of a second:"],
   group[HoldForm[AbsoluteTiming[KnoodleSimplify[P]]]],
   text["Identifying every summand is just as fast, and reports each prime \
factor with its multiplicity, distinguishing mirror trefoils along the way:"],
   group[HoldForm[AbsoluteTiming[KnoodleIdentify[P]]]]};

exMutants = {
   delim,
   text["Lookup is by knot type, not by polynomial invariants, so \
KnoodleIdentify distinguishes the famous mutant pair that shares Alexander \
and Jones polynomials: the Conway knot (11n34) and the Kinoshita-Terasaka \
knot (11n42):"],
   silent[HoldForm[conway = PD[X[4,2,5,1], X[8,4,9,3], X[12,5,13,6],
       X[2,8,3,7], X[9,17,10,16], X[11,18,12,19], X[6,13,7,14],
       X[15,20,16,21], X[17,1,18,22], X[19,14,20,15], X[21,10,22,11]];]],
   silent[HoldForm[kt = PD[X[4,2,5,1], X[8,4,9,3], X[12,5,13,6], X[2,8,3,7],
       X[9,18,10,19], X[11,21,12,20], X[6,13,7,14], X[15,10,16,11],
       X[17,22,18,1], X[19,15,20,14], X[21,16,22,17]];]],
   group[HoldForm[KnoodleIdentify /@ {conway, kt}]],
   group[HoldForm[Row[{Labeled[KnoodleDraw[conway, ImageSize -> 200], "Conway"],
       Labeled[KnoodleDraw[kt, ImageSize -> 200], "Kinoshita-Terasaka"]},
      Spacer[25]]]]};

exCosets = {
   delim,
   text["9_32 is chiral and noninvertible, so its four symmetry variants \
(identity, reverse, mirror, mirror-reverse) are four genuinely different \
oriented knots, and KnoodleIdentify assigns each its own coset. Mirroring a \
PD code flips every crossing; reversal renumbers the arcs backwards:"],
   silent[HoldForm[mirrorPD[p_PD] := With[{n = Length[p]},
      Replace[p, X[i_, j_, k_, l_] :>
        If[Mod[l - j, 2 n] == 1, X[j, k, l, i], X[l, i, j, k]], 1]];]],
   silent[HoldForm[reversePD[p_PD] := With[{s = 2 Length[p] + 1},
      Replace[p, X[i_, j_, k_, l_] :> X[s - k, s - l, s - i, s - j], 1]];]],
   silent[HoldForm[k932 = PD[X[14,18,15,17], X[18,6,1,5], X[10,15,11,16],
       X[16,9,17,10], X[4,11,5,12], X[8,3,9,4], X[6,14,7,13], X[2,7,3,8],
       X[12,1,13,2]];]],
   silent[HoldForm[reps = {k932, reversePD[k932], mirrorPD[k932],
       mirrorPD[reversePD[k932]]};]],
   group[HoldForm[KnoodleIdentify /@ reps]],
   text["Oriented drawings of the four representatives:"],
   group[HoldForm[Row[MapThread[Labeled[KnoodleDraw[#1, "Orientation" -> True,
        ImageSize -> 160], #2] &, {reps, {"e", "r", "m", "mr"}}], Spacer[12]]]]};

ex6 = {
   delim,
   text["A knot with more crossings than the lookup table covers comes back \
as Unidentified together with its signed PD code. Here a (2,17) torus knot \
is sampled as a space curve:"],
   silent[HoldForm[torus = Most@Table[N@{Cos[2 t] (2 + Cos[17 t]),
         Sin[2 t] (2 + Cos[17 t]), Sin[17 t]}, {t, 0., 2 Pi, 2 Pi/680}];]],
   group[HoldForm[KnoodleIdentify[torus]]]};

SeedRandom[42];
ex7 = {
   delim,
   text["Restricting \"MaxCrossings\" below a knot's crossing number forces \
a NotFound result:"],
   group[HoldForm[KnoodleIdentify[Knot[5, 1], "MaxCrossings" -> 3]]]};

ex8 = {
   delim,
   text["A genuine link fails with a KnoodleIdentify::link message rather \
than being reported as if it were a knot:"],
   group[HoldForm[KnoodleIdentify[{{0, 1, 2, 3, 1, 0, 0}, {2, 3, 0, 1, 1, 1, 1}}]]]};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, ex2, pdExplainerCells, ex3, ex4, ex5, exMutants, exCosets, ex6, ex7, ex8}], Open]];

nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
