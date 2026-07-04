#!/usr/bin/env wolframscript
(* Regenerate Documentation/English/ReferencePages/Symbols/KnoodleSimplify.nb
   with full Notes + options table + worked examples: round trip, 5000-gon
   Unite/split, the Burton et al. hard-unknot rogue's gallery (timed), the
   three largest Applebaum et al. very hard unknots (timed), SimplifyLevel. *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnoodleSimplify.nb"}];

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
       "simplification effort: 0 none, 3 Reidemeister I+II, 4 adds path \
rerouting, 5 adds summand detection; Automatic (or 6 and up) is the full \
Reapr pipeline"],
      optRow[ToBoxes["Unite"], "False",
       "False: one diagram per prime connect-sum factor; True: reconnect \
same-colored factors into one diagram per split component"],
      optRow[ToBoxes["RandomizeProjection"], "True",
       "randomly rotate 3D input before projecting, avoiding degenerate \
projections; set False for reproducibility"],
      optRow[ToBoxes["SimplifyOptions"], RowBox[{"{", "}"}],
       "extra knoodlesimplify flags, e.g. {\"dijkstra-strategy\" -> \
\"alternating\"}; see knoodlesimplify --help"]
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
   text["Drawing the complex shows one diagram per prime factor:"],
   group[HoldForm[KnoodleDraw[split, ImageSize -> 620]]],
   text["\"Unite\" -> True connect-sums the factors back together into a \
single 51-crossing diagram of the same knot:"],
   group[HoldForm[KnoodleDraw[KnoodleSimplify[P, "Unite" -> True],
      ImageSize -> 320]]],
   text["KnoodleIdentify accepts the complex directly and names the factors:"],
   group[HoldForm[KnoodleIdentify[split]]]};

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
   text["\"SimplifyLevel\" controls how hard KnoodleSimplify works: level 3 \
uses Reidemeister I+II moves only, level 4 adds path rerouting, level 5 adds \
summand detection, and the default is the full Reapr pipeline. Haken's \
141-crossing Gordian unknot is completely rigid under everything below the \
full pipeline:"],
   silent[HoldForm[haken = Last[hardunknots];]],
   group[HoldForm[KnoodleSimplify[haken, "SimplifyLevel" -> #] & /@ {3, 4, 5}]],
   group[HoldForm[KnoodleSimplify[haken]]]};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, pdExplainerCells, ex2, exLink, ex3, ex4, ex5}], Open]];

nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
