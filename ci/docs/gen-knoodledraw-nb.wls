#!/usr/bin/env wolframscript
(* Regenerate Documentation/English/ReferencePages/Symbols/KnoodleDraw.nb
   from scratch: full Notes + options table + worked, genuinely-evaluated
   examples. Also exports each example's output as PNG for review. *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
(* KnotTheory` must load before the example definitions below: .wls files
   parse each top-level expression just before evaluating it, so loading it
   first makes the examples' PD/X/DrawPD/Gap symbols parse into the
   KnotTheory` context instead of Global`. NOTE: this generator never
   EVALUATES DrawPD (exD5 evaluates KnoodleDraw on a KnotTheory PD and only
   displays the DrawPD call; the DrawPD images come from the committed
   DrawPDGallery assets) -- DrawPD's convergence is too environment-
   sensitive to sit inside routine doc regeneration; see ci/docs/README.md.
   Only gen-drawpd-gallery.wls actually runs DrawPD. *)
Needs["KnotTheory`"];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out    = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnoodleDraw.nb"}];
$review = FileNameJoin[{$TemporaryDirectory, "knoodle-doc-review"}]; Quiet[CreateDirectory[$review]];

(* ---------- cell builders ---------- *)
$png = 0;
(* Input cells are built from the code's InputForm string through the front
   end's own parser -- exactly the boxes typing the code would produce, so
   the cell re-evaluates like ordinary user input. The previous
   ToBoxes[HoldForm[...]] approach had two defects (found by evaluating a
   shipped page, 2026-07-04): the HoldForm TagBox made evaluating any doc
   input a display-only no-op (assignments silently didn't happen), and
   MakeBoxes applied *output* formatting to unevaluated input -- a literal
   Graphics3D[...] input typeset as a Graphics3DBox with symbolic
   coordinates, which the front end renders as an "error of unspecified
   nature" box. *)
heldInputForm[HoldForm[e_]] := ToString[Unevaluated[e], InputForm];
inCell[h_HoldForm] := Cell[BoxData[First @ First @ UsingFrontEnd @ MathLink`CallFrontEnd[
      FrontEnd`UndocumentedTestFEParserPacket[heldInputForm[h], False]]], "Input"];
(* display-only input cell: shown to the reader, never evaluated here *)
shown[h_HoldForm] := inCell[h];
(* Evaluate, snapshot a review PNG when graphical, return an Input+Output group. *)
group[h_HoldForm] := Module[{res = ReleaseHold[h]},
  If[! FreeQ[res, _Graphics | _Graphics3D],
   $png++;
   Export[FileNameJoin[{$review, "ex" <> ToString[$png] <> ".png"}], res, ImageResolution -> 100]];
  Cell[CellGroupData[{inCell[h], Cell[BoxData[ToBoxes[res]], "Output"]}, Open]]];
silent[h_HoldForm] := (ReleaseHold[h]; inCell[h]);
text[s_]  := Cell[s, "ExampleText"];
delim     := Cell["", "ExampleDelimiter"];
notes[s_] := Cell[s, "Notes"];

optRow[nameBox_, defBox_, desc_String] :=
  {Cell["      ", "ModInfo"], nameBox, defBox, Cell[desc, "TableText"]};

(* ---------- header / usage / notes ---------- *)
(* Shared PD-code explainer cells (defines pdExplainerCells). *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "pd-explainer.wls"}]];

categorization = Cell[CellGroupData[{
   Cell["Categorization", "CategorizationSection"],
   Cell["Symbol", "Categorization", CellLabel -> "Entity Type"],
   Cell["Knoodle", "Categorization", CellLabel -> "Paclet Name"],
   Cell["Knoodle`", "Categorization", CellLabel -> "Context"],
   Cell["Knoodle/ref/KnoodleDraw", "Categorization", CellLabel -> "URI"]}, Closed]];

usageSection = Cell[CellGroupData[{
   Cell["KnoodleDraw", "ObjectName"],
   Cell[TextData[{
     Cell["   ", "ModInfo"],
     Cell[BoxData[RowBox[{"KnoodleDraw", "[", StyleBox["input", "TI"], "]"}]],
      "InlineFormula"],
     "\[LineSeparator]draws a picture of a knot or link diagram, returning a \
Graphics object."}], "Usage"],
   notes["input may be a KnotData specification (e.g. Knot[3,1], {3,1}, or \
\"Trefoil\"), a PD/DTCode/GaussCode from the KnotTheory package, a Function \
(sampled as a closed space curve for t from 0 to 2 Pi), a list of 3D points \
(one closed space curve), a list of point lists (a multi-component link), a \
native Knoodle PD code, or a PlanarDiagramComplex from KnoodleSimplify."],
   notes["A native Knoodle PD code is a list of crossing rows of 4 to 7 \
integers each: 4 columns give an unsigned PD code, a 5th column gives the \
crossing handedness (\[PlusMinus]1), and two further columns carry the \
incoming under-/over-arc component colors that keep link components \
identified through simplification. A list of such row lists denotes a \
connect sum or split link, one summand each; the empty summand {} is an \
unknot, so {{}} draws the standalone unknot."],
   notes["3D geometry and KnotData inputs are simplified before drawing by \
default; explicit diagram inputs (PD codes, KnotTheory objects, \
PlanarDiagramComplex) are drawn exactly as given unless \"Simplify\" -> True \
is set."],
   notes["KnoodleDraw returns Graphics, or Legended[Graphics, \[Ellipsis]] \
when PlotLegends -> Automatic is given. When the input yields several \
diagrams (a multi-summand PlanarDiagramComplex, a connect sum, or a split \
link), it returns a list of Graphics drawn at one common scale: the widest \
drawing gets the requested ImageSize and the others are proportionally \
smaller, so strands, gaps, arrowheads, and label text are the same physical \
size across the whole output. Unrecognized input yields $Failed with a \
KnoodleDraw::badinput message."],
   notes["Labels are set in Source Sans Pro at the largest size at which \
every label fits its allotted space, uniformly across all diagrams of the \
output. LabelStyle styles the label text (family, weight, color, \
\[Ellipsis]); its directives merge on top of the default, and a font family \
that is not actually installed will fall back silently with possibly \
mismatched label sizing. A numeric FontSize inside LabelStyle is honored \
only when no explicit ImageSize is given, and then sets the overall drawing \
scale; label placement is not configurable."],
   notes["The following options can be given:"],
   Cell[BoxData[GridBox[{
      optRow[ToBoxes["Simplify"], "Automatic",
       "whether to simplify the diagram before drawing; Automatic simplifies \
geometry/KnotData input but draws explicit diagram input as-is"],
      optRow[ToBoxes["Thickness"], "Automatic",
       "strand thickness: Automatic scales with the diagram so crossing gaps \
stay visible (capped at 7 pt); a number is an AbsoluteThickness in points, \
clamped to the same proportional bound; any other directive is used as-is"],
      optRow[ToBoxes["Checkerboard"], "False",
       "shade the diagram's two-colorable faces"],
      optRow[ToBoxes["Orientation"], "False",
       "True marks each arc's orientation with arrowheads along the strand \
(two per grid square of run)"],
      optRow[ToBoxes["Labels"], RowBox[{"{", "}"}],
       "annotate 0-based element ids: a subset of {\"Crossings\", \"Arcs\", \
\"Faces\"}. Arc labels are set into the strand, once per grid square of run"],
      optRow["LabelStyle", RowBox[{"{", "}"}],
       "styles the label text (font family, weight, color, \[Ellipsis]); \
merged over the default Source Sans Pro. Label size and placement are \
computed and not configurable, except that a FontSize given without an \
explicit ImageSize sets the overall drawing scale"],
      optRow[ToBoxes["ExteriorFace"], "Automatic",
       "which face (0-based id) to lay out as the unbounded exterior region"],
      optRow["PlotLegends", "None",
       "Automatic adds a LineLegend matching component colors to component \
numbers"],
      optRow[ToBoxes["RandomizeProjection"], "True",
       "randomly rotate 3D input before projecting, avoiding degenerate \
projections; set False for reproducibility"],
      optRow[ToBoxes["LayoutOptions"], RowBox[{"{", "}"}],
       "extra knoodledraw layout flags, e.g. {\"randomize-bends\" -> 3}; see \
knoodledraw --help"],
      optRow["ImageSize", "340",
       "size of the resulting Graphics; with several diagrams, the size of \
the widest (the rest are proportionally smaller, at a common scale)"]
      }]], "3ColumnTableMod"]
   }, Open]];

(* ---------- examples (evaluated for real) ---------- *)
pdTref = {{0, 3, 1, 4}, {2, 5, 3, 0}, {4, 1, 5, 2}};

SeedRandom[7];
ex1 = {
   text["Draw the trefoil knot:"],
   group[HoldForm[KnoodleDraw[Knot[3, 1]]]]};

ex2 = {
   delim,
   text["3D geometry is simplified before drawing by default. Turn \
\"Simplify\" off to draw the raw projection of a Gaussian random 200-gon, \
with well over a hundred crossings:"],
   silent[HoldForm[GaussianRandomPolygon[n_] := Accumulate[Standardize[
       RandomVariate[NormalDistribution[], {n, 3}], Mean, 1 &]]]],
   silent[HoldForm[SeedRandom[3]; P = GaussianRandomPolygon[200];]],
   (SeedRandom[103]; group[HoldForm[KnoodleDraw[P, "Simplify" -> False]]]),
   text["The default pipeline simplifies first, revealing that this polygon \
is a trefoil:"],
   (SeedRandom[103]; group[HoldForm[KnoodleDraw[P, ImageSize -> 200]]])};

(* Native PD code input: the shared explainer (drawn exactly as given). *)
ex3 = pdExplainerCells;

ex4 = {
   delim,
   text["The empty summand {} is an unknot, so {{}} draws the standalone \
unknot:"],
   group[HoldForm[KnoodleDraw[{{}}, ImageSize -> 100]]]};

SeedRandom[11];
ex5 = {
   delim,
   text["Shade the two-colorable faces and label the crossings, arcs, and \
faces of a diagram:"],
   group[HoldForm[KnoodleDraw[Knot[7, 4], "Checkerboard" -> True,
      "Labels" -> {"Crossings", "Arcs", "Faces"}]]]};

ex6 = {
   delim,
   text["LabelStyle styles the label text -- here bold and red on a trefoil \
PD code. The label font size is computed to fit the diagram and is uniform \
across all labels:"],
   silent[HoldForm[pd = {{0, 3, 1, 4}, {2, 5, 3, 0}, {4, 1, 5, 2}};]],
   group[HoldForm[KnoodleDraw[pd, "Labels" -> {"Crossings", "Arcs"},
      LabelStyle -> {Bold, Red}, ImageSize -> 300]]]};

ex7 = {
   delim,
   text["Strand thickness scales with the diagram by default, keeping the \
over/under gaps at every crossing visible even on dense diagrams. Here a \
(2,15) torus knot is drawn from a sampled space curve:"],
   silent[HoldForm[
     torus = Most@Table[N@{Cos[2 t] (2 + Cos[15 t]), Sin[2 t] (2 + Cos[15 t]),
          Sin[15 t]}, {t, 0., 2 Pi, 2 Pi/600}];]],
   (SeedRandom[1]; group[HoldForm[KnoodleDraw[torus]]])};

ex8 = {
   delim,
   text["A list of point lists is a multi-component link, one closed 3D \
curve per component. Two circles in orthogonal planes form a Hopf link:"],
   silent[HoldForm[
     c1 = Most@Table[N@{Cos[t], Sin[t], 0}, {t, 0., 2 Pi, 2 Pi/60}];]],
   silent[HoldForm[
     c2 = Most@Table[N@{1 + Cos[t], 0, Sin[t]}, {t, 0., 2 Pi, 2 Pi/60}];]],
   group[HoldForm[Graphics3D[{CapForm["Round"],
       ColorData[97][1], Tube[Append[c1, First[c1]], 0.05],
       ColorData[97][2], Tube[Append[c2, First[c2]], 0.05]},
      Boxed -> False, ImageSize -> 200]]],
   text["KnoodleDraw projects the 3D geometry to a link diagram; a legend \
matches each component's color (the same colors as above) to its component \
number:"],
   (SeedRandom[5]; group[HoldForm[KnoodleDraw[{c1, c2}, PlotLegends -> Automatic,
       ImageSize -> 250]]])};

ex8b = {
   delim,
   text["Drawing a multi-summand complex gives a list of Graphics at one \
common scale, and strand colors identify link components across the \
summands: same color, same physical component. The connect sum of a \
trefoil and a Hopf link (colored PD input: trefoil rows on component 0, \
Hopf rows on components 0 and 1) splits into two prime factors -- the \
trefoil factor draws in component 0's color, the same color as the Hopf \
strand it is tied into:"],
   silent[HoldForm[trefC = {{0, 3, 1, 4, 0, 0}, {2, 5, 3, 0, 0, 0},
       {4, 1, 5, 2, 0, 0}};]],
   silent[HoldForm[hopfC = {{3, 0, 2, 1, 1, 0}, {1, 2, 0, 3, 0, 1}};]],
   group[HoldForm[Row[KnoodleDraw[KnoodleSimplify[{trefC, hopfC}],
       PlotLegends -> Automatic, ImageSize -> 180], Spacer[15]]]],
   text["\"Unite\" -> True splices the factors back together into a single \
two-component diagram, in the same component colors:"],
   group[HoldForm[KnoodleDraw[KnoodleSimplify[{trefC, hopfC}, "Unite" -> True],
      PlotLegends -> Automatic, ImageSize -> 220]]]};

ex9 = {
   delim,
   text["\"ExteriorFace\" chooses which face is laid out as the unbounded \
exterior region; label the faces to see the ids:"],
   group[HoldForm[Row[{KnoodleDraw[pd, "Labels" -> "Faces", ImageSize -> 160],
       KnoodleDraw[pd, "Labels" -> "Faces", "ExteriorFace" -> 2,
        ImageSize -> 160]}, Spacer[20]]]]};

ex10 = {
   delim,
   text["\"Orientation\" -> True marks each arc's orientation with \
arrowheads along the strand:"],
   (SeedRandom[5];
    group[HoldForm[Row[{KnoodleDraw[pd, "Orientation" -> True, ImageSize -> 200],
        KnoodleDraw[{c1, c2}, "Orientation" -> True, ImageSize -> 190]},
       Spacer[20]]]])};

(* ---- layout variety: same PD code, very different drawings ---- *)
ex11 = {
   delim,
   text["A PD code determines the diagram but not the drawing: \
\"LayoutOptions\" forwards layout flags to the knoodledraw tool, and \
different compaction or bend choices give very different orthogonal \
drawings of the same code. Here the 13-crossing knot 13a_1 \
(PD code from KnotInfo, 0-based) with the default layout, with \
\"compaction\" -> \"topo-order\", and with four rounds of bend \
randomization:"],
   silent[HoldForm[pd13a1 = {{2, 0, 3, 25}, {0, 7, 1, 8}, {6, 1, 7, 2},
       {8, 4, 9, 3}, {4, 13, 5, 14}, {12, 5, 13, 6}, {14, 10, 15, 9},
       {10, 19, 11, 20}, {18, 11, 19, 12}, {20, 16, 21, 15},
       {16, 23, 17, 24}, {22, 17, 23, 18}, {24, 22, 25, 21}};]],
   group[HoldForm[Row[{KnoodleDraw[pd13a1, ImageSize -> 180],
       KnoodleDraw[pd13a1, "LayoutOptions" -> {"compaction" -> "topo-order"},
        ImageSize -> 180],
       KnoodleDraw[pd13a1, "LayoutOptions" -> {"randomize-bends" -> 4},
        ImageSize -> 180]}, Spacer[15]]]]};

(* ---- comparison with KnotTheory`'s DrawPD ----
   The DrawPD side of each pair is a pre-rendered PNG bundled as the
   DrawPDGallery paclet asset (generated by gen-drawpd-gallery.wls), so
   these examples display -- and mostly run -- without KnotTheory`
   installed. Only exD5, the drop-in-replacement demo, evaluates DrawPD for
   real at generation time. Narrative: two comparisons where both programs
   succeed (Millett unknot, 13a_1), then the robustness examples --
   KnoodleDraw draws diagrams with R1 loops, non-prime diagrams, and
   complicated diagrams that defeat DrawPD. *)
exD1 = {
   delim,
   text["KnotTheory`'s DrawPD function \
(katlas.org/wiki/Drawing_Planar_Diagrams) also draws diagrams directly \
from PD codes. The comparisons below show DrawPD's output from drawings \
bundled with this paclet, so they display even without KnotTheory` \
installed. First, the 10-crossing \"Millett unknot\" -- the worked example \
on DrawPD's own manual page -- drawn by DrawPD (left, with the page's \
recommended Gap -> 0.03) and by KnoodleDraw (right, from the same PD code, \
0-based):"],
   silent[HoldForm[gallery = PacletObject["Knoodle"]["AssetLocation", "DrawPDGallery"];]],
   silent[HoldForm[millett = {{0, 9, 1, 10}, {8, 1, 9, 2}, {2, 6, 3, 5},
       {14, 4, 15, 3}, {4, 16, 5, 15}, {6, 13, 7, 14}, {7, 17, 8, 16},
       {10, 17, 11, 18}, {18, 11, 19, 12}, {12, 19, 13, 0}};]],
   group[HoldForm[Row[{
       Labeled[Image[Import[FileNameJoin[{gallery, "millett-drawpd.png"}]],
         ImageSize -> 260], "DrawPD"],
       Labeled[KnoodleDraw[millett, ImageSize -> 260], "KnoodleDraw"]},
      Spacer[20]]]]};

exD2 = {
   delim,
   text["A 13-crossing knot, drawn by DrawPD (left) and KnoodleDraw \
(right) from KnotInfo's published PD code for 13a_1 (the same pd13a1 as \
above); KnoodleIdentify confirms the knot:"],
   group[HoldForm[KnoodleIdentify[pd13a1]]],
   group[HoldForm[Row[{
       Labeled[Image[Import[FileNameJoin[{gallery, "13a1-drawpd.png"}]],
         ImageSize -> 260], "DrawPD"],
       Labeled[KnoodleDraw[pd13a1, ImageSize -> 260], "KnoodleDraw"]},
      Spacer[20]]]]};

(* -- robustness: R1 loops -- *)
exD3 = {
   delim,
   text["KnoodleDraw is more robust than DrawPD. First, it draws diagrams \
containing Reidemeister-I loops: the raw z-axis projection of a Gaussian \
random 50-gon has 21 crossings, three of them kinks, and DrawPD's circle \
packing does not terminate on any diagram containing a monogon. \
KnoodleDraw draws it exactly as projected:"],
   silent[HoldForm[GaussianRandomPolygon[n_] := Accumulate[Standardize[
       RandomVariate[NormalDistribution[], {n, 3}], Mean, 1 &]]]],
   silent[HoldForm[SeedRandom[2026]; Q = GaussianRandomPolygon[50];]],
   group[HoldForm[KnoodleDraw[Q, "Simplify" -> False,
      "RandomizeProjection" -> False, ImageSize -> 260]]]};

(* -- robustness: non-prime diagrams -- *)
exD4a = {
   delim,
   text["Second, KnoodleDraw handles diagrams which are not prime. On the \
granny knot (the connect sum of two trefoils) as a single 6-crossing PD \
code, DrawPD (left) terminates but crushes the two summands into tiny \
corner tangles; KnoodleDraw (right) gives both summands equal weight:"],
   silent[HoldForm[granny = {{8, 11, 9, 0}, {0, 3, 1, 4}, {4, 1, 5, 2},
       {2, 5, 3, 6}, {6, 9, 7, 10}, {10, 7, 11, 8}};]],
   group[HoldForm[Row[{
       Labeled[Image[Import[FileNameJoin[{gallery, "granny-drawpd.png"}]],
         ImageSize -> 260], "DrawPD"],
       Labeled[KnoodleDraw[granny, ImageSize -> 260], "KnoodleDraw"]},
      Spacer[20]]]]};

(* -- robustness: complicated diagrams -- *)
exD4b = {
   delim,
   text["Third, complicated diagrams: removing just the three kinks from \
the 50-gon projection above (and simplifying nothing else) leaves a \
15-crossing diagram that DrawPD can draw -- but with wildly non-uniform \
crossing sizes (left); KnoodleDraw's grid layout (right) keeps every \
crossing and gap the same size no matter how tangled the diagram gets:"],
   silent[HoldForm[gauss50 = {{26, 0, 27, 29}, {0, 28, 1, 27}, {14, 2, 15, 1},
       {2, 14, 3, 13}, {3, 12, 4, 13}, {15, 4, 16, 5}, {20, 5, 21, 6},
       {19, 7, 20, 6}, {7, 24, 8, 25}, {23, 8, 24, 9}, {18, 9, 19, 10},
       {17, 11, 18, 10}, {22, 12, 23, 11}, {16, 22, 17, 21},
       {25, 28, 26, 29}};]],
   group[HoldForm[Row[{
       Labeled[Image[Import[FileNameJoin[{gallery, "gauss50-drawpd.png"}]],
         ImageSize -> 260], "DrawPD"],
       Labeled[KnoodleDraw[gauss50, ImageSize -> 260], "KnoodleDraw"]},
      Spacer[20]]]]};

(* The drop-in demo evaluates KnoodleDraw on a KnotTheory PD object for
   real, but only DISPLAYS the DrawPD call (shown[] = input cell, no
   evaluation, no output group): DrawPD's numerics are environment-
   sensitive enough that evaluating it here made doc regeneration hostage
   to kernel luck (see ci/docs/README.md); its output for this very PD is
   already shown from the bundled gallery asset in the first comparison. *)
exD5 = {
   delim,
   text["For users who do have KnotTheory` installed, KnoodleDraw is a \
drop-in replacement for DrawPD: it accepts KnotTheory's PD[X[...], ...] \
objects (and DTCode/GaussCode) directly, in KnotTheory's own 1-based arc \
numbering. The Millett unknot again, exactly as written on the DrawPD \
manual page:"],
   silent[HoldForm[Needs["KnotTheory`"]]],
   silent[HoldForm[MillettUnknot = PD[X[1, 10, 2, 11], X[9, 2, 10, 3],
       X[3, 7, 4, 6], X[15, 5, 16, 4], X[5, 17, 6, 16], X[7, 14, 8, 15],
       X[8, 18, 9, 17], X[11, 18, 12, 19], X[19, 12, 20, 13],
       X[13, 20, 14, 1]];]],
   group[HoldForm[KnoodleDraw[MillettUnknot, ImageSize -> 260]]],
   text["Anywhere a session calls DrawPD[MillettUnknot, {Gap -> 0.03}], \
KnoodleDraw[MillettUnknot] accepts the identical input (its DrawPD output \
is the left panel of the first comparison above):"],
   shown[HoldForm[Show[DrawPD[MillettUnknot, {Gap -> 0.03}]]]]};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, ex2, ex3, ex4, ex5, ex6, ex7, ex8, ex8b, ex9, ex10, ex11,
    exD1, exD2, exD3, exD4a, exD4b, exD5}], Open]];

(* ---------- assemble + save ---------- *)
nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
