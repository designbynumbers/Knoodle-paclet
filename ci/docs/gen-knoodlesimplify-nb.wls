#!/usr/bin/env wolframscript
(* Regenerate Documentation/English/ReferencePages/Symbols/KnoodleSimplify.nb
   with full Notes + options table + worked examples: round trip, 5000-gon
   Unite/split, the Burton et al. hard-unknot rogue's gallery (timed), the
   three largest Applebaum et al. very hard unknots (timed), SimplifyLevel. *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* KnotTheory` is needed by the "OutputFormat" -> "KnotTheory" example (it
   computes Jones polynomials for real -- pure symbolic computation, safe in
   any kernel, unlike DrawPD) and must load before the example definitions
   below so their PD/X/Jones symbols parse into the KnotTheory` context. *)
Needs["KnotTheory`"];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnoodleSimplify.nb"}];

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
optRow[nameBox_, defBox_, desc_String] :=
  {Cell["      ", "ModInfo"], nameBox, defBox, Cell[desc, "TableText"]};

(* Shared PD-code explainer cells (defines pdExplainerCells). *)
Get[FileNameJoin[{DirectoryName[$InputFileName], "pd-explainer.wls"}]];

categorization = Cell[CellGroupData[{
   Cell["Categorization", "CategorizationSection"],
   Cell["Symbol", "Categorization", CellLabel -> "Entity Type"],
   Cell["Knoodle", "Categorization", CellLabel -> "Paclet Name"],
   Cell["Knoodle`", "Categorization", CellLabel -> "Context"],
   Cell["Knoodle/ref/KnoodleSimplify", "Categorization", CellLabel -> "URI"]}, Closed]];

usageSection = Cell[CellGroupData[{
   Cell["KnoodleSimplify", "ObjectName"],
   Cell[TextData[{
     Cell["   ", "ModInfo"],
     Cell[BoxData[RowBox[{"KnoodleSimplify", "[", StyleBox["input", "TI"], "]"}]],
      "InlineFormula"],
     "\[LineSeparator]simplifies a knot or link diagram, reducing the number \
of crossings without changing the underlying knot or link type."}], "Usage"],
   notes["Returns a PlanarDiagramComplex object representing the simplified \
diagram, which can be passed directly to KnoodleDraw (to see the picture) or \
KnoodleIdentify (to look it up in the knot table). input accepts the same \
representations as KnoodleDraw."],
   notes["A composite diagram is decomposed into its connect-sum factors: by \
default the result holds one diagram per diagrammatically-prime factor \
(factors of the same link component share a color), the natural input for \
KnoodleIdentify. \"Unite\" -> True connect-sums same-colored factors back \
together, giving one diagram per split component -- the natural \
one-PD-per-component form for other software."],
   notes["A diagram that simplifies all the way to a 0-crossing unknot is \
recorded as an unknot summand of the complex rather than disappearing."],
   notes["The following options can be given:"],
   Cell[BoxData[GridBox[{
      optRow[ToBoxes["SimplifyLevel"], "Automatic",
       "simplification effort: 0 none; 1, 2, 3 are local-only tiers \
(Reidemeister I; I+II; all local moves); 4 path rerouting; 5 adds summand \
detection; Automatic (or 6 and up) is the full Reapr pipeline"],
      optRow[ToBoxes["Unite"], "False",
       "False: one diagram per prime connect-sum factor; True: reconnect \
same-colored factors into one diagram per split component"],
      optRow[ToBoxes["RandomizeProjection"], "True",
       "randomly rotate 3D input before projecting, avoiding degenerate \
projections; set False for reproducibility"],
      optRow[ToBoxes["MaxReaprAttempts"], "Automatic",
       "maximum number of Reapr iterations; Automatic is the tool's default \
of 25. Reapr runs only at \"SimplifyLevel\" 6 and up, so this has no effect \
at lower levels"],
      optRow[ToBoxes["Compaction"], "True",
       "whether the Reapr layout runs OrthoDraw's compaction pass; False \
skips it (Reapr only)"],
      optRow[ToBoxes["ReaprEnergy"], "Automatic",
       "energy functional Reapr minimizes: Automatic (the tool's default), \
or one of \"TV\", \"Height\", \"TV_MCF\" (Reapr only)"],
      optRow[ToBoxes["SimplifyOptions"], RowBox[{"{", "}"}],
       "extra knoodlesimplify flags, e.g. {\"dijkstra-strategy\" -> \
\"alternating\"}; see knoodlesimplify --help"],
      optRow[ToBoxes["OutputFormat"], ToBoxes["PlanarDiagramComplex"],
       "\"KnotTheory\" returns KnotTheory` PD codes instead: one \
PD[X[...], ...] per physically split portion of the link (a list when \
there are several; PD[Loop[1]] for a 0-crossing portion). Implies \
\"Unite\" -> True"]
      }]], "3ColumnTableMod"]
   }, Open]];

(* ---------- examples ---------- *)
SeedRandom[42];
ex1 = {
   text["Simplify a 6-crossing knot; the result is a PlanarDiagramComplex:"],
   group[HoldForm[pdc = KnoodleSimplify[Knot[6, 2]]]],
   text["The result can be drawn and identified directly:"],
   group[HoldForm[KnoodleDraw[pdc, ImageSize -> 180]]],
   group[HoldForm[KnoodleIdentify[pdc]]]};

ex2 = {
   delim,
   text["Simplification decomposes a composite knot into its connect-sum \
factors. Generate a Gaussian random polygon with 5000 vertices and simplify \
it:"],
   silent[HoldForm[GaussianRandomPolygon[n_] := Accumulate[Standardize[
       RandomVariate[NormalDistribution[], {n, 3}], Mean, 1 &]]]],
   silent[HoldForm[SeedRandom[1]; P = GaussianRandomPolygon[5000];]],
   group[HoldForm[split = KnoodleSimplify[P]]],
   text["Drawing the complex gives one diagram per prime factor, at a \
common scale:"],
   group[HoldForm[Row[KnoodleDraw[split, ImageSize -> 280], Spacer[10]]]],
   text["\"Unite\" -> True connect-sums the factors back together into a \
single 51-crossing diagram of the same knot:"],
   group[HoldForm[KnoodleDraw[KnoodleSimplify[P, "Unite" -> True],
      ImageSize -> 320]]],
   text["KnoodleIdentify accepts the complex directly and names the factors:"],
   group[HoldForm[KnoodleIdentify[split]]]};

exSum = {
   delim,
   text["Colors carry link-component identity through a complex. Here a \
composite link -- the connect sum of a trefoil and a Hopf link -- as native \
colored PD input: the last two columns of each crossing row are the \
incoming under- and over-arcs' component colors, so the trefoil rows live \
on component 0 while the Hopf rows carry components 0 and 1:"],
   silent[HoldForm[trefC = {{0, 3, 1, 4, 0, 0}, {2, 5, 3, 0, 0, 0},
       {4, 1, 5, 2, 0, 0}};]],
   silent[HoldForm[hopfC = {{3, 0, 2, 1, 1, 0}, {1, 2, 0, 3, 0, 1}};]],
   text["\"Unite\" -> True splices same-colored factors together: the whole \
link is one connected 5-crossing diagram with two components:"],
   group[HoldForm[KnoodleDraw[KnoodleSimplify[{trefC, hopfC}, "Unite" -> True],
      PlotLegends -> Automatic, ImageSize -> 220]]],
   text["The default split shape gives one diagram per diagrammatically \
prime factor, and the colors are meaningful across the summands: same \
color, same link component. The trefoil factor draws entirely in component \
0's color -- the same color as the strand that threads the Hopf factor -- \
because that is the component the trefoil is tied into:"],
   group[HoldForm[Row[KnoodleDraw[KnoodleSimplify[{trefC, hopfC}],
       PlotLegends -> Automatic, ImageSize -> 180], Spacer[15]]]]};

exKT = {
   delim,
   text["To compute invariants with the KnotTheory` package, request the \
result as KnotTheory PD codes: \"OutputFormat\" -> \"KnotTheory\" returns \
one PD[X[...], ...] per physically split portion of the link (a bare PD \
code when there is only one). PD codes cannot express that separate \
diagrams share a link component, so this implies \"Unite\" -> True. This \
200-vertex Gaussian random polygon is a composite knot (a trefoil \
connect-summed with a 5_2); it simplifies straight to a single 8-crossing \
PD code, the factors united:"],
   silent[HoldForm[Needs["KnotTheory`"]]],
   silent[HoldForm[SeedRandom[5]; R = GaussianRandomPolygon[200];]],
   group[HoldForm[pdR = KnoodleSimplify[R, "OutputFormat" -> "KnotTheory",
      "RandomizeProjection" -> False]]],
   text["The result feeds KnotTheory's invariant machinery directly -- \
here its Jones polynomial:"],
   group[HoldForm[Jones[pdR][q]]],
   text["The trefoil-with-Hopf-link connect sum from the previous example \
unites into a single two-component code, and KnotTheory computes link \
invariants from it just as directly:"],
   group[HoldForm[pdTH = KnoodleSimplify[{trefC, hopfC}, "OutputFormat" -> "KnotTheory"]]],
   group[HoldForm[Jones[pdTH][q]]]};

exLink = {
   delim,
   text["A list of point lists is a multi-component link, one closed 3D \
curve per component. Superimpose two Gaussian random 20-gons, the second \
nudged half a unit sideways (each polygon's steps sum to zero, so its last \
vertex is exactly the origin -- unshifted copies would touch there). With \
this seed the two polygons happen to link:"],
   silent[HoldForm[SeedRandom[3]; L1 = GaussianRandomPolygon[20];]],
   silent[HoldForm[L2 = (# + {1/2, 0, 0}) & /@ GaussianRandomPolygon[20];]],
   group[HoldForm[hopf = KnoodleSimplify[{L1, L2}]]],
   text["Drawing the complex shows the two polygons form a Hopf link:"],
   group[HoldForm[KnoodleDraw[hopf, PlotLegends -> Automatic, ImageSize -> 200]]]};

ex3 = {
   delim,
   text["A rogue's gallery: the 21 hard unknot diagrams catalogued by \
B. A. Burton, H.-C. Chang, M. L\[ODoubleDot]ffler, A. de Mesmay, C. Maria, \
S. Schleimer, E. Sedgwick and J. Spreer, \"Hard Diagrams of the Unknot\", \
Experimental Mathematics 33(3), 2023 (arXiv:2104.14076). These diagrams \
defeat naive Reidemeister simplification -- several provably require extra \
crossings before they can be simplified at all. The diagrams ship with this \
paclet as example data. In order of crossing number (9 to 141), with the \
names and attributions used in that paper:"],
   silent[HoldForm[dir = PacletObject["Knoodle"]["AssetLocation", "HardUnknots"];]],
   silent[HoldForm[files = {"H.tsv", "J.tsv", "Culprit.tsv", "Monster.tsv",
       "Goeritz.tsv", "Thistlethwaite.tsv", "OchiaiI.tsv", "TuzunSikora.tsv",
       "D28.tsv", "PZ31.tsv", "FHW.tsv", "FakeFHW.tsv", "ReducedOchiaiII.tsv",
       "D43.tsv", "OchiaiII.tsv", "OchiaiIV.tsv", "OchiaiIII.tsv", "PZ78.tsv",
       "PZ120.tsv", "PZ138.tsv", "Haken.tsv"};]],
   silent[HoldForm[names = {"H", "J", "Culprit", "Monster", "Goeritz",
       "Thistlethwaite", "Ochiai I", "Tuzun-Sikora", Subscript["D", 28],
       Subscript["PZ", 31], "FHW", "\"Fake\" FHW", "Ochiai II (red.)",
       Subscript["D", 43], "Ochiai II", "Ochiai IV", "Ochiai III",
       Subscript["PZ", 78], Subscript["PZ", 120], Subscript["PZ", 138],
       "Haken"};]],
   silent[HoldForm[hardunknots = Import[FileNameJoin[{dir, #}], "Table"] & /@ files;]],
   group[HoldForm[Grid[Partition[MapThread[
       Labeled[KnoodleDraw[#1, ImageSize -> {110, 110}], #2] &,
       {hardunknots, names}], UpTo[5]], Spacings -> {1, 1},
      Alignment -> {Center, Center}]]],
   text["KnoodleSimplify untangles all 21 in a fifth of a second, total:"],
   group[HoldForm[{time, results} = AbsoluteTiming[KnoodleSimplify /@ hardunknots]; time]],
   text["Every result is the same complex: a single unknot summand."],
   group[HoldForm[Union[results]]]};

ex4 = {
   delim,
   text["T. Applebaum, S. Blackwell, A. Davies, T. Edlich, A. Juh\[AAcute]sz, \
M. Lackenby, N. Toma\[SHacek]ev and D. Zheng, \"The Unknotting Number, Hard \
Unknot Diagrams, and Reinforcement Learning\", Experimental Mathematics, 2025 \
(arXiv:2409.09032) used reinforcement learning to construct unknot diagrams \
designed to be hard to simplify. The three largest of the paper's published \
examples (59, 51, and 48 crossings) ship with this paclet:"],
   silent[HoldForm[vdir = PacletObject["Knoodle"]["AssetLocation", "VeryHardUnknots"];]],
   silent[HoldForm[veryhard = Import[FileNameJoin[{vdir, #}], "Table"] & /@
       {"juhasz-veryhard-257.tsv", "juhasz-veryhard-216.tsv",
        "juhasz-veryhard-240.tsv"};]],
   group[HoldForm[Row[MapThread[Labeled[KnoodleDraw[#1, ImageSize -> {160, 160}], #2] &,
      {veryhard, {"#257 (59 cr.)", "#216 (51 cr.)", "#240 (48 cr.)"}}], Spacer[15]]]],
   text["All three are unknotted in well under a tenth of a second, total:"],
   group[HoldForm[{time, results} = AbsoluteTiming[KnoodleSimplify /@ veryhard]; time]],
   group[HoldForm[Union[results]]]};

ex5 = {
   delim,
   text["\"SimplifyLevel\" controls how hard KnoodleSimplify works. Levels \
1-3 are local-only diagnostic tiers: 1 removes Reidemeister I kinks, 2 uses \
Reidemeister I and II, 3 all local moves. Level 4 switches to path \
rerouting, 5 adds connect-sum detection, and the default (Automatic, or 6 \
and up) is the full Reapr pipeline. Each tier bites deeper into the \
128-crossing raw projection of a Gaussian random 100-gon:"],
   silent[HoldForm[SeedRandom[5]; Q = GaussianRandomPolygon[100];]],
   group[HoldForm[stages = KnoodleSimplify[Q, "SimplifyLevel" -> #,
        "RandomizeProjection" -> False] & /@ {0, 1, 2, 3, Automatic}]],
   text["Drawing the five stages at one glance -- 128 crossings raw, 119 \
after Reidemeister I, 45 after I+II, 18 after all local moves, and the \
6-crossing minimal diagram from the full pipeline:"],
   group[HoldForm[Row[MapThread[Labeled[KnoodleDraw[#1, ImageSize -> 128], #2] &,
      {stages, {"0", "1", "2", "3", "Automatic"}}], Spacer[10]]]],
   text["The fully simplified polygon is the knot 6_2:"],
   group[HoldForm[KnoodleIdentify[Last[stages]]]],
   text["The local tiers are diagnostic, not a cheaper substitute for the \
pipeline: Haken's 141-crossing Gordian unknot has no local moves and no \
reroutes available at all, so every level below the full pipeline returns \
it untouched:"],
   silent[HoldForm[haken = Last[hardunknots];]],
   group[HoldForm[KnoodleSimplify[haken, "SimplifyLevel" -> #] & /@ {3, 4, 5}]],
   group[HoldForm[KnoodleSimplify[haken]]]};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, pdExplainerCells, ex2, exSum, exKT, exLink, ex3, ex4, ex5}], Open]];

nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
