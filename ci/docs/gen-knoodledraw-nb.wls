#!/usr/bin/env wolframscript
(* Regenerate Documentation/English/ReferencePages/Symbols/KnoodleDraw.nb
   from scratch: full Notes + options table + worked, genuinely-evaluated
   examples. Also exports each example's output as PNG for review. *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out    = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnoodleDraw.nb"}];
$review = FileNameJoin[{$TemporaryDirectory, "knoodle-doc-review"}]; Quiet[CreateDirectory[$review]];

(* ---------- cell builders ---------- *)
$png = 0;
inCell[h_HoldForm] := Cell[BoxData[ToBoxes[h]], "Input"];
(* Evaluate, snapshot a review PNG when graphical, return an Input+Output group. *)
group[h_HoldForm] := Module[{res = ReleaseHold[h]},
  If[! FreeQ[res, _Graphics],
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
when PlotLegends -> Automatic is given. Unrecognized input yields $Failed \
with a KnoodleDraw::badinput message."],
   notes["The following options can be given:"],
   Cell[BoxData[GridBox[{
      optRow[ToBoxes["Simplify"], "Automatic",
       "whether to simplify the diagram before drawing; Automatic simplifies \
geometry/KnotData input but draws explicit diagram input as-is"],
      optRow[ToBoxes["CornerRadius"], ToBoxes[1/3],
       "corner-arc radius as a fraction of one grid square, 0 (sharp) to 1/2"],
      optRow[ToBoxes["Thickness"], "Automatic",
       "strand thickness: Automatic scales with the diagram so crossing gaps \
stay visible (capped at 7 pt); a number is a fixed AbsoluteThickness; any \
other directive is used as-is"],
      optRow[ToBoxes["Checkerboard"], "False",
       "shade the diagram's two-colorable faces"],
      optRow[ToBoxes["Orientation"], "False",
       "True marks each link component's orientation with an arrowhead on its \
longest arc; All marks every arc. Heads sit mid-run, clear of crossings and \
labels, and scale with the strand thickness"],
      optRow[ToBoxes["Labels"], RowBox[{"{", "}"}],
       "annotate 0-based element ids: a subset of {\"Crossings\", \"Arcs\", \
\"Faces\"}"],
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
      optRow["ImageSize", "340", "size of the resulting Graphics"]
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
   text["\"CornerRadius\" runs from 0 (sharp corners) to 1/2 (maximally \
rounded), here on a trefoil PD code:"],
   silent[HoldForm[pd = {{0, 3, 1, 4}, {2, 5, 3, 0}, {4, 1, 5, 2}};]],
   group[HoldForm[Row[Table[KnoodleDraw[pd, "CornerRadius" -> r,
        ImageSize -> 160], {r, {0, 1/2}}], Spacer[20]]]]};

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
   text["Draw a Hopf link from its two component curves, with a legend \
matching each component's color to its component number:"],
   silent[HoldForm[
     c1 = Most@Table[N@{Cos[t], Sin[t], 0}, {t, 0., 2 Pi, 2 Pi/60}];]],
   silent[HoldForm[
     c2 = Most@Table[N@{1 + Cos[t], 0, Sin[t]}, {t, 0., 2 Pi, 2 Pi/60}];]],
   (SeedRandom[5]; group[HoldForm[KnoodleDraw[{c1, c2}, PlotLegends -> Automatic,
       ImageSize -> 250]]])};

ex9 = {
   delim,
   text["\"ExteriorFace\" chooses which face is laid out as the unbounded \
exterior region; label the faces to see the ids:"],
   group[HoldForm[Row[{KnoodleDraw[pd, "Labels" -> "Faces", ImageSize -> 160],
       KnoodleDraw[pd, "Labels" -> "Faces", "ExteriorFace" -> 2,
        ImageSize -> 160]}, Spacer[20]]]]};

ex10 = {
   delim,
   text["\"Orientation\" -> All marks the orientation of every arc with an \
arrowhead; True marks each link component just once, on its longest arc:"],
   (SeedRandom[5];
    group[HoldForm[Row[{KnoodleDraw[pd, "Orientation" -> All, ImageSize -> 160],
        KnoodleDraw[{c1, c2}, "Orientation" -> True, ImageSize -> 190]},
       Spacer[20]]]])};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, ex2, ex3, ex4, ex5, ex6, ex7, ex8, ex9, ex10}], Open]];

(* ---------- assemble + save ---------- *)
nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
