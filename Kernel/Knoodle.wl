(* ::Package:: *)

(* Knoodle paclet -- knot/link diagram drawing, simplification, and
   identification. The heavy lifting is done by the Knoodle CLI tools
   (knoodledraw / knoodlesimplify / knoodleidentify), which this package drives
   via RunProcess. The Wolfram side handles representation conversion (KnotData,
   KnotTheory PD/DTCode/GaussCode, 3D curves) and rendering. *)

BeginPackage["Knoodle`"];

KnoodleDraw::usage =
  "KnoodleDraw[input] renders a knot or link diagram as a Graphics object. \
input may be a KnotData/Knot specification (e.g. {3,1} or \"Trefoil\"), a KnotTheory \
PD[X[...]] / DTCode / GaussCode, a list of 3D points, or a native Knoodle PD code \
(rows of 4 or 5 integers). Option \"Simplify\" (Automatic) controls whether the given \
diagram is drawn as-is or a simplified diagram of the same knot is drawn. Option \
\"Checkerboard\" (False) shades the diagram's two-colorable faces. Option \"Labels\" \
(a subset of {\"Crossings\",\"Arcs\",\"Faces\"}) annotates the diagram with 0-based \
element ids.";

KnoodleSimplify::usage =
  "KnoodleSimplify[input] simplifies a knot or link diagram, returning a PlanarDiagramComplex \
object that KnoodleDraw can render directly. input accepts the same representations as \
KnoodleDraw. Option \"SimplifyLevel\" (Automatic, knoodlesimplify's own default) sets the \
simplification effort. \"RandomizeProjection\" (True) applies a random shear before \
projecting 3D input, as in KnoodleDraw. \"Unite\" (False, i.e. the default \"split\" shape) \
controls the output shape for composite/split links: False gives one diagram per \
diagrammatically-prime factor (same-colored factors share a link component -- the natural \
input for KnoodleIdentify on a composite knot); True connect-sums same-colored factors back \
together via PlanarDiagramComplex::Connect, giving one diagram per physically split component \
(the natural single-PD-per-component form for KnotTheory/Regina). \"SimplifyOptions\" ({}) \
forwards arbitrary knoodlesimplify flags controlling PlanarDiagramComplex::Simplify's \
algorithm (e.g. {\"dijkstra-strategy\"->\"alternating\", \"canonicalize\"->False} -- see \
knoodlesimplify --help for the full list), the same passthrough convention as \
KnoodleDraw's \"LayoutOptions\".";

PlanarDiagramComplex::usage =
  "PlanarDiagramComplex[<|\"serialized\"->...|>] wraps the result of KnoodleSimplify: a \
simplified knot/link complex in PlanarDiagramComplex's own native serialization, which \
preserves colors exactly, including for components that simplified away to a free-floating \
unknot. Pass it directly to KnoodleDraw.";

KnotSymbol::usage =
  "KnotSymbol[c,i,alternating,coset] identifies a table-looked-up knot summand, as emitted \
by knoodleidentify (see its --help for the full field description): c crossings, i \
KnotInfo's per-crossing-count index, alternating a boolean, coset which of {e,m,r,mr} this \
diagram represents ('/'-joined when several coincide, e.g. \"e/r\"). Displays in KnotInfo \
notation -- c_i for 3<=c<=10 (e.g. 3_1), or c<a|n>_i for c>=11 (e.g. 11a_456, alternating/\
non-alternating) -- with a superscript coset tag whenever the coset does not include the \
identity variant \"e\" (e.g. 3_1^(m/mr) for the mirror trefoil). FullForm is unchanged.";

$KnoodleBinaryDirectory::usage =
  "$KnoodleBinaryDirectory is the directory holding the knoodle CLI executables.";

Begin["`Private`"];

(* ---- binary locations (development default; overridden when packaged) ---- *)
$KnoodleBinaryDirectory = "/Users/jasoncantarella/Knoodle/tools";
exe[name_String] := FileNameJoin[{$KnoodleBinaryDirectory, name}];

(* Square grid spacing requested from knoodledraw (see runGeometry). One grid
   square is this many coordinate units; the corner radius is a fraction of it. *)
$gridSize = 4;

(* ---- context-free head test (KnotTheory symbols live in various contexts) ---- *)
headNameQ[x_, name_String] := MatchQ[Head[x], _Symbol] && SymbolName[Head[x]] === name;

(* ---- run knoodledraw --format=wl (optionally simplifying first) ----
   Returns a list of geometry associations, one per connect-sum summand. *)
(* Forward arbitrary tuning knobs to a CLI tool. "name"->n or "name"->"s" become
   --name=..., "name"->True/False become --name / --no-name. Lets a caller reach
   any flag without a dedicated named option, e.g.
     "LayoutOptions" -> {"randomize-bends" -> 3}
     "SimplifyOptions" -> {"dijkstra-strategy" -> "alternating", "canonicalize" -> False} *)
toCliFlags[rules : {___Rule}] := Map[
  Which[
    #[[2]] === True,  "--" <> #[[1]],
    #[[2]] === False, "--no-" <> #[[1]],
    True,             "--" <> #[[1]] <> "=" <> ToString[#[[2]]]] &,
  List @@@ rules];
toCliFlags[_] := {};

(* A unique scratch file, e.g. tempFile["knoodle-simplified-", ".tsv"]. *)
tempFile[prefix_String, extension_String] :=
  FileNameJoin[{$TemporaryDirectory, prefix <> CreateUUID[] <> extension}];

(* File[path] input (multi-component 3D / .kndlxyz -- see toTSV) can't be piped
   through --streaming-mode, which only reads stdin; knoodlesimplify's file mode
   needs an explicit --output. Draw-from-file likewise takes the path as a
   trailing argument instead of stdin.
   randomizeQ is --randomize-projection: the default projection is straight
   down the z axis, which can degenerate on vertical/coplanar segments or (for
   .kndlxyz) exact coincidental intersections between components. Applied to
   whichever tool actually reads the geometry -- knoodlesimplify when
   simplifying first, knoodledraw otherwise -- in both the stdin (single
   component) and file (multi-component) cases; both now honor the flag. *)
runGeometry[in_, simplify_, extraFlags_List, randomizeQ_ : False] := Module[{tsv, out, gridFlags, randFlag},
  gridFlags = {"--x-grid-size=" <> ToString[$gridSize], "--y-grid-size=" <> ToString[$gridSize]};
  randFlag = If[TrueQ[randomizeQ], {"--randomize-projection"}, {}];
  tsv = Which[
     TrueQ[simplify] && Head[in] === File,
      Module[{outFile = tempFile["knoodle-simplified-", ".tsv"]},
       RunProcess[Join[{exe["knoodlesimplify"], "--output=" <> outFile}, randFlag, {First[in]}]];
       Import[outFile, "Text"]],
     TrueQ[simplify],
      RunProcess[Join[{exe["knoodlesimplify"], "--streaming-mode"}, randFlag], "StandardOutput", in],
     Head[in] === File, None,  (* draw directly from the file, no simplify step *)
     True, in];
  out = If[tsv === None,
     RunProcess[Join[{exe["knoodledraw"], "--format=wl"}, gridFlags, extraFlags, randFlag, {First[in]}], "StandardOutput"],
     RunProcess[Join[{exe["knoodledraw"], "--format=wl"}, gridFlags, extraFlags, randFlag], "StandardOutput", tsv]];
  ToExpression /@ Select[StringSplit[StringTrim[out], "\n"], StringStartsQ[#, "<|"] &]
];

(* ---- run knoodlesimplify --format=pdc, returning the raw serialized string
   (PlanarDiagramComplex's own native format -- see WriteToFile/FromInString
   and the paired knoodle_io.hpp/knoodlesimplify.cpp changes) for
   KnoodleSimplify to wrap. File[...] input (multi-component 3D) can't stream
   through --streaming-mode, same constraint as runGeometry -- see its
   comment -- so it goes through an explicit --output file instead; this
   otherwise mirrors runGeometry's dispatch but stops after the simplify
   step rather than also drawing. *)
runSimplifyPdc[in_, extraFlags_List] := If[Head[in] === File,
   Module[{outFile = tempFile["knoodle-pdc-", ".txt"]},
    RunProcess[Join[{exe["knoodlesimplify"], "--format=pdc", "--output=" <> outFile}, extraFlags, {First[in]}]];
    Import[outFile, "Text"]],
   RunProcess[Join[{exe["knoodlesimplify"], "--format=pdc", "--streaming-mode"}, extraFlags],
     "StandardOutput", in]
];

(* ---- cheap line-prefix summary of a PDC-native serialized string, for
   PlanarDiagramComplex's summary box (below) -- every line is either a
   marker ("k", "u <color>", "s <flag>") or a tab-separated PD data row, so a
   crossing count is just "does this line contain a tab". *)
pdcSummary[s_String] := Module[{lines = DeleteCases[StringSplit[s, "\n"], "" | "k"]},
  <|
   "CrossingCount" -> Count[lines, _?(StringContainsQ[#, "\t"] &)],
   "SummandCount" -> Count[lines, _?(StringStartsQ[#, "s "] &)],
   "UnknotCount" -> Count[lines, _?(StringStartsQ[#, "u "] &)]
   |>
];

PlanarDiagramComplex /: MakeBoxes[pdc : PlanarDiagramComplex[assoc_Association], fmt_] :=
 Module[{summary = pdcSummary[assoc["serialized"]]},
  BoxForm`ArrangeSummaryBox[
   PlanarDiagramComplex, pdc, None,
   {{BoxForm`SummaryItem[{"Crossings: ", summary["CrossingCount"]}]},
    {BoxForm`SummaryItem[{"Summands: ", summary["SummandCount"]}],
     BoxForm`SummaryItem[{"Unknots: ", summary["UnknotCount"]}]}},
   {}, fmt, "Interpretable" -> Automatic
  ]
];

(* ---- KnotSymbol display: KnotInfo-style typeset name, FullForm unchanged.
   Built with the expression-level Subscript/Superscript/Interpretation (not
   their *Box primitives directly) and handed to ToBoxes at the very end --
   InterpretationBox holds its first argument completely (not even a bound
   local variable's value gets substituted in), so assembling raw boxes by
   hand here left the display broken no matter how evaluation was forced;
   Interpretation[...] is a plain expression with its own correct MakeBoxes
   rule and has none of that trouble. A String argument to Subscript/
   Superscript displays as its literal characters, with no quote marks and
   no risk of "/" being read as division -- both verified directly (a bare
   MakeBoxes-level check doesn't actually render InterpretationBox; only a
   rendered/exported image does). *)
knotSymbolExpr[c_Integer, i_Integer, alternating : (True | False), coset_String] :=
 Module[{base},
  base = If[3 <= c <= 10, Subscript[c, i], Subscript[ToString[c] <> If[alternating, "a", "n"], i]];
  If[MemberQ[StringSplit[coset, "/"], "e"], base, Superscript[base, coset]]
];

KnotSymbol /: MakeBoxes[
   ks : KnotSymbol[c_Integer, i_Integer, alternating : (True | False), coset_String], fmt_] :=
 ToBoxes[Interpretation[knotSymbolExpr[c, i, alternating, coset], ks], fmt];

(* ---- input normalization: input -> {tsvString, defaultSimplifyQ} ----
   Geometry/KnotData inputs default to simplifying (the raw projection is arbitrary);
   explicit codes default to drawing *this* diagram. *)
toTSV[pts : {{_?NumericQ, _?NumericQ, _?NumericQ} ..}] := {ExportString[N[pts], "TSV"], True};
toTSV[f_Function] := toTSV[Most@Table[f[t], {t, 0., 2 Pi, 2 Pi/160}]];
toTSV[spec : {_Integer, _Integer}] := toTSV[KnotData[spec, "SpaceCurve"]];
toTSV[name_String] := toTSV[KnotData[name, "SpaceCurve"]];
toTSV[k_ /; headNameQ[k, "Knot"]] := toTSV[Take[List @@ k, 2]];
(* Multi-component 3D geometry -- one link component per point list. Knoodle
   only reads this format (blank-line-separated vertex blocks, one component
   per block) from a *file* with a .kndlxyz extension, never from stdin -- see
   README.md's "Input formats" section -- so this writes a scratch file and
   returns File[...] instead of a TSV string; runGeometry knows how to draw
   (and, if needed, simplify) directly from a File[...]. *)
toTSV[components : {{{_?NumericQ, _?NumericQ, _?NumericQ} ..} ..}] := Module[{f = tempFile["knoodle-", ".kndlxyz"]},
  Export[f, StringRiffle[ExportString[N[#], "TSV"] & /@ components, "\n"], "Text"];
  {File[f], True}];
(* native Knoodle PD: rows of 4 (unsigned), 5 (signed), 6 (unsigned+colors), or
   7 (signed+colors) integers -- one summand. The last two columns, when
   present, are the incoming under-/over-arc's explicit color (see
   PDCode.hpp) -- how a link's components are tagged on the wire, and how
   knoodlesimplify preserves component identity through simplification when
   given colored input (knoodle_io.hpp: colored in -> colored out). *)
toTSV[pd : {{Repeated[_Integer, {4, 7}]} ..}] := {ExportString[pd, "TSV"], False};
(* Multiple summands: a list where each entry is itself a summand's row list, or
   {} for a bare unknot summand (connect-sum factor or split component -- Knoodle's
   wire format doesn't distinguish the two; see knoodle_io.hpp). {{}} is the
   standalone unknot, the one-summand case of this same pattern. *)
toTSV[summands : {({{Repeated[_Integer, {4, 7}]} ...} | {}) ..}] := {
   "k\n" <> StringJoin[("s\n" <> If[# === {}, "", ExportString[#, "TSV"]]) & /@ summands],
   False};
(* KnotTheory PD[X[i,j,k,l], ...] -> Knoodle 4-col unsigned, 0-indexed (identity slots) *)
toTSV[p_ /; headNameQ[p, "PD"]] :=
  {ExportString[((List @@ # &) /@ (List @@ p)) - 1, "TSV"], False};
(* DT / Gauss codes -> PD (via KnotTheory) -> the PD path above *)
toTSV[c_ /; headNameQ[c, "DTCode"] || headNameQ[c, "GaussCode"]] :=
  (Needs["KnotTheory`"]; toTSV[Symbol["KnotTheory`PD"][c]]);
(* KnoodleSimplify's own result type -- already simplified, so def is False,
   same as any other explicit-code input. The serialized string is
   PlanarDiagramComplex's native format (colors, including for unknot
   summands, intact); ReadKnot (knoodle_io.hpp) auto-detects and parses it
   exactly like any other TSV content, so no special-casing is needed past
   this point -- it flows through runGeometry/runSimplifyPdc unchanged,
   including re-simplifying it if the caller explicitly asks for that. *)
toTSV[pdc_ /; headNameQ[pdc, "PlanarDiagramComplex"]] := {pdc[[1, "serialized"]], False};
toTSV[other_] := (Message[KnoodleDraw::badinput, other]; $Failed);

(* ---- corner rounding: replace each 90-degree bend with a circular arc of the
   given (fixed) radius, tangent to both edges. The radius is a fraction of one
   grid square (not of the edge), so long edges do not get larger arcs and the
   arc always stays inside the corner's grid cell (radius <= half a grid square).
   Clamped to half the shorter adjacent edge only to stay within pathologically
   short edges. *)
cornerArc[Pm_, Pi_, Pp_, radius_] := Module[{Lin, Lout, uin, uout, d, a, b},
  Lin = EuclideanDistance[Pm, Pi]; Lout = EuclideanDistance[Pi, Pp];
  If[Lin < 1.*^-9 || Lout < 1.*^-9, Return[Nothing]];
  uin = (Pm - Pi)/Lin; uout = (Pp - Pi)/Lout;
  If[Abs[uin . uout + 1] < 1.*^-6, Return[Nothing]];      (* collinear: no real corner *)
  d = Min[radius, 0.5 Min[Lin, Lout]];
  a = Pi + d uin; b = Pi + d uout;
  {a, b, a + b - Pi, d}                                   (* {start, end, center, radius} (90-degree) *)
];
arcSample[a_, b_, center_, d_, k_ : 8] := Module[{ta, sweep},
  ta = ArcTan @@ (a - center);
  sweep = Mod[(ArcTan @@ (b - center)) - ta + Pi, 2 Pi] - Pi;   (* short signed sweep *)
  Table[center + d {Cos[ta + t sweep], Sin[ta + t sweep]}, {t, 0., 1., 1./k}]
];
roundedPolyline[pts_, radius_] := Module[{out = {N@First[pts]}, ca},
  If[Length[pts] < 3, Return[N@pts]];
  Do[
    ca = cornerArc[pts[[i - 1]], pts[[i]], pts[[i + 1]], radius];
    If[ca === Nothing, AppendTo[out, N@pts[[i]]], out = Join[out, arcSample @@ ca]],
    {i, 2, Length[pts] - 1}];
  Append[out, N@Last[pts]]
];

(* ---- label styling: matches system plotting functions (Plot, Graph, ...), which
   never hardcode a FontFamily -- LabelStyle/BaseStyle resolve to {} even on a
   fully-resolved Plot, so fonts are purely inherited from the notebook stylesheet.
   Mirroring that (no FontFamily here either) makes labels track whatever font the
   surrounding notebook already uses. Color/opacity use the theme system (ThemeColor,
   LightDark-aware) rather than fixed grays, so labels stay legible and appropriately
   subdued in both light and dark mode, and under custom notebook themes. *)
labelStyle[sz_ : 11] := Style[#, sz, Opacity[0.7], ThemeColor["Foreground"]] &;

(* ---- polygon centroid (area-weighted; falls back to a vertex average for
   degenerate/zero-area or self-touching boundaries) -- used for face labels. *)
polygonCentroid[pts_] := Module[{p, n, cross, area, cx, cy},
  p = N[pts];
  If[Length[p] > 1 && First[p] == Last[p], p = Most[p]];
  n = Length[p];
  If[n < 3, Return[Mean[p]]];
  cross[i_] := p[[i, 1]] p[[Mod[i, n] + 1, 2]] - p[[Mod[i, n] + 1, 1]] p[[i, 2]];
  area = Sum[cross[i], {i, n}]/2;
  If[Abs[area] < 10.^-9, Return[Mean[p]]];
  cx = Sum[(p[[i, 1]] + p[[Mod[i, n] + 1, 1]]) cross[i], {i, n}]/(6 area);
  cy = Sum[(p[[i, 2]] + p[[Mod[i, n] + 1, 2]]) cross[i], {i, n}]/(6 area);
  {cx, cy}
];

(* ---- face label placement: a discretized "pole of inaccessibility", restricted
   to grid-square centers, so it stays well inside even very non-convex faces
   (a plain polygon centroid can land outside a non-convex face entirely).
   A grid square is one cell of OrthoDraw's own layout grid (BoundingBox is its
   width/height in cells); its center in Points/Boundary coordinates is offset
   by half a grid square from the cell's corner. Boundary distance and
   containment both come straight from the Region framework -- no hand-rolled
   geometry. *)
gridSquareCenters[w_, h_] := Flatten[
   Table[$gridSize {i + 1/2, j + 1/2}, {i, 0, w - 1}, {j, 0, h - 1}], 1];

(* Lexicographic-max of {distance, x, y} -- WL's default Sort/Order on same-shape
   lists of reals is lexicographic, so Last@Sort gives exactly that: farthest
   from the boundary, ties broken rightmost then topmost. *)
lexBest[scored_] := Last[Sort[scored]][[{2, 3}]];

interiorFaceLabelPos[face_, w_, h_] := Module[{poly = face["Boundary"], inside},
  inside = Select[gridSquareCenters[w, h], RegionMember[Polygon[poly]]];
  If[inside === {}, Return[polygonCentroid[poly]]];  (* face smaller than one grid cell *)
  lexBest[{RegionDistance[Line[poly], #], #[[1]], #[[2]]} & /@ inside]
];

(* The exterior face is unbounded, so candidates are restricted to the ring of
   grid cells framing the diagram's own bounding rectangle R (only R's right
   edge grows if that ring turns up empty -- e.g. the diagram fills its box
   edge-to-edge on all other sides). Distance is capped by closeness to R's own
   edge too, so the label doesn't crowd the image boundary. *)
exteriorFaceLabelPos[extFace_, w_, h_, interiorPolys_] := Module[
  {expand = 0, rw, ring, notInterior, ex},
  notInterior = RegionMember[RegionUnion @@ (Polygon /@ interiorPolys)] /* Not;
  While[True,
   rw = w + expand;
   ring = $gridSize (# + {1/2, 1/2}) & /@ Select[Tuples[{Range[0, rw - 1], Range[0, h - 1]}],
      (#[[1]] == 0 || #[[1]] == rw - 1 || #[[2]] == 0 || #[[2]] == h - 1) &];
   ex = Select[ring, notInterior];
   If[ex =!= {} || expand > 20, Break[]];
   expand++];
  If[ex === {}, Return[polygonCentroid[extFace["Boundary"]]]];  (* shouldn't happen *)
  lexBest[{Min[RegionDistance[Line[extFace["Boundary"]], #],
       RegionDistance[RegionBoundary[Rectangle[{0, 0}, $gridSize {rw, h}]], #]], #[[1]], #[[2]]} & /@ ex]
];

faceLabelPos[face_, w_, h_, interiorPolys_] := If[TrueQ[face["Exterior"]],
   exteriorFaceLabelPos[face, w, h, interiorPolys],
   interiorFaceLabelPos[face, w, h]];

(* ---- arc label placement, per spec, computed on the RAW (un-rounded) polyline:
   - if the arc has a horizontal section, place the label's bottom-center at the
     midpoint of its LONGEST horizontal segment, nudged up a bit (like underlining).
   - if the arc is purely vertical (no horizontal segment at all), place the label's
     left-center at the arc-length midpoint of the whole polyline, nudged right.
   Every segment on this grid is axis-aligned, so these two cases are exhaustive. *)
$labelGap = 0.35;
arcLabelSpec[pts_] := Module[
  {segs, horiz, longest, mid, lens, cum, total, half, i, t, pos},
  segs = Partition[pts, 2, 1];
  horiz = Select[segs, (#[[1, 2]] == #[[2, 2]]) &];
  If[horiz =!= {},
   longest = First[SortBy[horiz, -Abs[#[[2, 1]] - #[[1, 1]]] &]];
   mid = {Mean[longest[[All, 1]]], longest[[1, 2]]};
   {mid + {0, $labelGap}, {0, -1}}
   ,
   lens = EuclideanDistance @@@ segs;
   cum = Prepend[Accumulate[lens], 0.];
   total = Last[cum];
   half = total/2;
   i = Clip[LengthWhile[cum, # < half &], {1, Length[segs]}];
   t = If[cum[[i + 1]] == cum[[i]], 0., (half - cum[[i]])/(cum[[i + 1]] - cum[[i]])];
   pos = segs[[i, 1]] + t (segs[[i, 2]] - segs[[i, 1]]);
   {pos + {$labelGap, 0}, {-1, 0}}
   ]
];

(* ---- checkerboard face fill: low-opacity theme-color washes rather than fixed
   colors, so shading adapts to light/dark mode and to custom notebook themes.
   Color[+1] faces are washed with the notebook's Accent1 (ties the shading to
   the theme's own accent); Color[-1] faces get a barely-there foreground wash
   (like graph paper), so the picture reads as "shaded", not "painted". *)
faceFill[colorSign_] := If[colorSign > 0,
  {Opacity[0.14], ThemeColor["Accent1"]},
  {Opacity[0.045], ThemeColor["Foreground"]}];

(* ---- render one summand's geometry association as a primitive list ----
   compOffset shifts this summand's arc "Component" indices, so every summand in
   a multi-summand picture (connect-sum factors / split components -- see
   toTSV's multi-summand pattern) draws in its own run of ColorData[97] colors
   instead of each restarting at color 1. radiusFrac is the corner radius as a
   fraction of one grid square, in [0,1/2] (0 = sharp corners). checkerboardQ
   shades faces; labelSet is a subset of {"Crossings","Arcs","Faces"}. *)
summandPrimitives[assoc_Association, thick_, radiusFrac_, checkerboardQ_, labelSet_, compOffset_] := Module[
  {r = Clip[radiusFrac, {0, 0.5}] $gridSize, style = labelStyle[], interiorFaces, interiorPolys, w, h},

  interiorFaces = If[KeyExistsQ[assoc, "Faces"], Select[assoc["Faces"], !TrueQ[#["Exterior"]] &], {}];
  interiorPolys = interiorFaces[[All, "Boundary"]];
  {w, h} = assoc["BoundingBox"];

  {
   (* faceFill[...] returns a *list* of directives ({Opacity[...], color}); it must be
      spliced (Sequence @@) into the surrounding primitive list, not nested as a single
      list element -- Graphics directive scoping does not propagate out of a nested
      sub-list, so {{Opacity[...],color}, Polygon[...]} silently ignores the styling.
      The exterior face is never filled (it isn't part of the checkerboard picture). *)
   If[TrueQ[checkerboardQ],
    Table[{Sequence @@ faceFill[face["Color"]], EdgeForm[], Polygon[face["Boundary"]]},
      {face, interiorFaces}],
    {}],

   {CapForm["Round"], JoinForm["Round"], AbsoluteThickness[thick],
    Table[{ColorData[97][arc["Component"] + compOffset + 1],
       Line[If[r > 0, roundedPolyline[arc["Points"], r], N@arc["Points"]]]},
      {arc, assoc["Arcs"]}]},

   If[MemberQ[labelSet, "Crossings"] && KeyExistsQ[assoc, "Crossings"],
    Table[Text[style[cr["Id"]], cr["Pos"], {-1, -1}, Background -> None],
      {cr, assoc["Crossings"]}], {}],
   If[MemberQ[labelSet, "Arcs"],
    Table[Text[style[arc["Id"]], Sequence @@ arcLabelSpec[arc["Points"]], Background -> None],
      {arc, assoc["Arcs"]}], {}],
   If[MemberQ[labelSet, "Faces"] && KeyExistsQ[assoc, "Faces"],
    Table[Text[style[face["Id"]], faceLabelPos[face, w, h, interiorPolys], {0, 0}, Background -> None],
      {face, assoc["Faces"]}], {}]
   }
];

(* A bare "<|"Unknot"->True|>" marker (knoodledraw's stand-in for a 0-crossing
   summand -- see the C++-side comment on DrawKnot) draws as a simple loop, in
   the same strand style, occupying one grid square. *)
unknotPrimitives[thick_, compOffset_] := {CapForm["Round"], JoinForm["Round"], AbsoluteThickness[thick],
   ColorData[97][compOffset + 1], Circle[$gridSize {1/2, 1/2}, $gridSize/2]};

geoWidth[assoc_] := If[KeyExistsQ[assoc, "Unknot"], $gridSize, First[assoc["BoundingBox"]] $gridSize];
geoComponentCount[assoc_] := If[KeyExistsQ[assoc, "Unknot"], 1,
   Max[assoc["Arcs"][[All, "Component"]], -1] + 1];

(* Lay out one or more summands (connect-sum factors / split components) left to
   right, each gap grid squares apart, each in its own local coordinate frame
   translated into place with the built-in Translate (no manual coordinate
   arithmetic needed) -- and each claiming its own run of component colors, so
   two unrelated summands never accidentally share "Component 0"'s color. *)
$summandGap = 2;
layoutGeos[geos_List, thick_, radiusFrac_, checkerboardQ_, labelSet_] := Module[{x = 0, c = 0, prims, w, nc, dx},
  Table[
   {prims, w, nc} = If[KeyExistsQ[geo, "Unknot"],
      {unknotPrimitives[thick, c], $gridSize, 1},
      {summandPrimitives[geo, thick, radiusFrac, checkerboardQ, labelSet, c], geoWidth[geo], geoComponentCount[geo]}];
   dx = x; x += w + $summandGap $gridSize; c += nc;
   Translate[prims, {dx, 0}],
   {geo, geos}]
];

totalComponentCount[geos_List] := Total[If[KeyExistsQ[#, "Unknot"], 1, geoComponentCount[#]] & /@ geos];

(* legendQ draws a LineLegend matching each component's strand color to its
   (global, 0-based) component number -- the same numbering layoutGeos assigns
   colors by, running across every summand, not restarting per summand. *)
render[geos_List, thick_, img_, radiusFrac_, checkerboardQ_, labelSet_, legendQ_] := Module[
  {g = Graphics[layoutGeos[geos, thick, radiusFrac, checkerboardQ, labelSet],
     AspectRatio -> Automatic, ImageSize -> img, PlotRangePadding -> Scaled[0.07]], n},
  If[TrueQ[legendQ],
   n = totalComponentCount[geos];
   Legended[g, LineLegend[ColorData[97] /@ Range[n], Range[0, n - 1]]],
   g]
];

(* ---- public entry point ---- *)
KnoodleDraw::badinput = "`1` is not a recognized knot/link input.";
(* "CornerRadius": corner arc radius as a fraction of one grid square, in [0, 1/2]
   (0 = sharp corners). "Checkerboard": shade the two-colorable faces. "Labels": a
   subset of {"Crossings","Arcs","Faces"} (a single string is also accepted).
   "ExteriorFace": which face OrthoDraw lays out as the unbounded exterior region
   (a non-negative integer, 0-based; Automatic, the default, is OrthoDraw's own
   default -- the largest face by arc count). Applies uniformly to every summand
   of a multi-summand diagram. PlotLegends -> Automatic adds a legend matching
   each link component's color to its (global) component number.
   "RandomizeProjection" (True by default): apply a random shear before
   projecting 3D geometry to a diagram. The default projection is straight
   down the z axis, which can degenerate on vertical/coplanar segments,
   so this defaults on; set to False to get the plain z-axis projection
   (e.g. for reproducibility). Only meaningful for 3D input read from stdin
   (KnotData/space-curve/point-list inputs); a no-op otherwise. *)
Options[KnoodleDraw] = {"Simplify" -> Automatic, "CornerRadius" -> 1/3, "LayoutOptions" -> {},
   "Checkerboard" -> False, "Labels" -> {}, "ExteriorFace" -> Automatic, PlotLegends -> None,
   "RandomizeProjection" -> True, ImageSize -> 340, "Thickness" -> 7};
KnoodleDraw[input_, opts : OptionsPattern[]] := Module[{norm, tsv, def, simp, geos, labelSet, extFlag},
  norm = toTSV[input];
  If[norm === $Failed, Return[$Failed]];
  {tsv, def} = norm;
  simp = Replace[OptionValue["Simplify"], Automatic -> def];
  extFlag = Replace[OptionValue["ExteriorFace"],
     {n_Integer?NonNegative :> {"--exterior-face=" <> ToString[n]}, _ :> {}}];
  geos = runGeometry[tsv, simp, Join[toCliFlags[OptionValue["LayoutOptions"]], extFlag],
    TrueQ[OptionValue["RandomizeProjection"]]];
  If[geos === {}, Return[$Failed]];
  labelSet = Flatten[{OptionValue["Labels"]}];
  render[geos, OptionValue["Thickness"], OptionValue[ImageSize], OptionValue["CornerRadius"],
    OptionValue["Checkerboard"], labelSet, OptionValue[PlotLegends] =!= None]
];

KnoodleSimplify::badinput = "`1` is not a recognized knot/link input.";
(* "SimplifyLevel": knoodlesimplify's --simplify-level (Automatic = its own
   default). "RandomizeProjection": as in KnoodleDraw, applies only to 3D
   input read from stdin. "Unite": False (default) is knoodlesimplify's own
   --split (one diagram per prime factor); True is --unite (connect-sums
   same-colored factors into one diagram per split component -- see
   KnoodleSimplify::usage). "SimplifyOptions": arbitrary knoodlesimplify
   flags, same passthrough convention as KnoodleDraw's "LayoutOptions". *)
Options[KnoodleSimplify] = {"SimplifyLevel" -> Automatic, "RandomizeProjection" -> True,
   "Unite" -> False, "SimplifyOptions" -> {}};
KnoodleSimplify[input_, opts : OptionsPattern[]] := Module[
  {norm, tsv, levelFlag, randFlag, uniteFlag, extraFlags, serialized},
  norm = toTSV[input];
  If[norm === $Failed, Message[KnoodleSimplify::badinput, input]; Return[$Failed]];
  tsv = First[norm];
  levelFlag = Replace[OptionValue["SimplifyLevel"],
     {Automatic -> {}, n_Integer :> {"--simplify-level=" <> ToString[n]}}];
  randFlag = If[TrueQ[OptionValue["RandomizeProjection"]], {"--randomize-projection"}, {}];
  uniteFlag = If[TrueQ[OptionValue["Unite"]], {"--unite"}, {}];
  extraFlags = toCliFlags[OptionValue["SimplifyOptions"]];
  serialized = runSimplifyPdc[tsv, Join[levelFlag, randFlag, uniteFlag, extraFlags]];
  If[! StringQ[serialized], Return[$Failed]];
  PlanarDiagramComplex[<|"serialized" -> serialized|>]
];

End[];
EndPackage[];
