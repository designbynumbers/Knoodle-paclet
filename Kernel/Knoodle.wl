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
(* Forward layout-tuning knobs to knoodledraw. "name"->n or "name"->"s" become
   --name=..., "name"->True/False become --name / --no-name. Lets a caller pull up
   alternate layouts of the same diagram, e.g.
     "LayoutOptions" -> {"randomize-bends" -> 3}
     "LayoutOptions" -> {"compaction" -> "topo-order", "turn-regularize" -> False} *)
layoutFlags[rules : {___Rule}] := Map[
  Which[
    #[[2]] === True,  "--" <> #[[1]],
    #[[2]] === False, "--no-" <> #[[1]],
    True,             "--" <> #[[1]] <> "=" <> ToString[#[[2]]]] &,
  List @@@ rules];
layoutFlags[_] := {};

runGeometry[tsv_String, simplify_, extraFlags_List] := Module[{drawIn, out},
  drawIn = If[TrueQ[simplify],
     RunProcess[{exe["knoodlesimplify"], "--streaming-mode"}, "StandardOutput", tsv],
     tsv];
  (* Square grid: undo the ASCII rectangular-character aspect compensation, since a
     Graphics is rendered on a square grid. Equal x/y grid sizes. Caller flags come
     last so they can override. *)
  out = RunProcess[
     Join[{exe["knoodledraw"], "--format=wl",
           "--x-grid-size=" <> ToString[$gridSize], "--y-grid-size=" <> ToString[$gridSize]},
          extraFlags],
     "StandardOutput", drawIn];
  ToExpression /@ Select[StringSplit[StringTrim[out], "\n"], StringStartsQ[#, "<|"] &]
];

(* ---- input normalization: input -> {tsvString, defaultSimplifyQ} ----
   Geometry/KnotData inputs default to simplifying (the raw projection is arbitrary);
   explicit codes default to drawing *this* diagram. *)
toTSV[pts : {{_?NumericQ, _?NumericQ, _?NumericQ} ..}] := {ExportString[N[pts], "TSV"], True};
toTSV[f_Function] := toTSV[Most@Table[f[t], {t, 0., 2 Pi, 2 Pi/160}]];
toTSV[spec : {_Integer, _Integer}] := toTSV[KnotData[spec, "SpaceCurve"]];
toTSV[name_String] := toTSV[KnotData[name, "SpaceCurve"]];
toTSV[k_ /; headNameQ[k, "Knot"]] := toTSV[Take[List @@ k, 2]];
(* native Knoodle PD: rows of 4 (unsigned) or 5 (signed) integers *)
toTSV[pd : {{Repeated[_Integer, {4, 5}]} ..}] := {ExportString[pd, "TSV"], False};
(* KnotTheory PD[X[i,j,k,l], ...] -> Knoodle 4-col unsigned, 0-indexed (identity slots) *)
toTSV[p_ /; headNameQ[p, "PD"]] :=
  {ExportString[((List @@ # &) /@ (List @@ p)) - 1, "TSV"], False};
(* DT / Gauss codes -> PD (via KnotTheory) -> the PD path above *)
toTSV[c_ /; headNameQ[c, "DTCode"] || headNameQ[c, "GaussCode"]] :=
  (Needs["KnotTheory`"]; toTSV[Symbol["KnotTheory`PD"][c]]);
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

(* ---- render a geometry association as Graphics ----
   radiusFrac is the corner radius as a fraction of one grid square, in [0, 1/2]
   (0 = sharp corners). checkerboardQ shades faces; labelSet is a subset of
   {"Crossings","Arcs","Faces"}. *)
render[assoc_Association, thick_, img_, radiusFrac_, checkerboardQ_, labelSet_] := Module[
  {r = Clip[radiusFrac, {0, 0.5}] $gridSize, faceLayer, strandLayer, labelLayer, style},
  style = labelStyle[];

  (* faceFill[...] returns a *list* of directives ({Opacity[...], color}); it must be
     spliced (Sequence @@) into the surrounding primitive list, not nested as a single
     list element -- Graphics directive scoping does not propagate out of a nested
     sub-list, so {{Opacity[...],color}, Polygon[...]} silently ignores the styling. *)
  faceLayer = If[TrueQ[checkerboardQ] && KeyExistsQ[assoc, "Faces"],
    Table[{Sequence @@ faceFill[face["Color"]], EdgeForm[], Polygon[face["Boundary"]]},
      {face, assoc["Faces"]}],
    {}];

  strandLayer = {CapForm["Round"], JoinForm["Round"], AbsoluteThickness[thick],
    Table[{ColorData[97][arc["Component"] + 1],
       Line[If[r > 0, roundedPolyline[arc["Points"], r], N@arc["Points"]]]},
      {arc, assoc["Arcs"]}]};

  labelLayer = {
    If[MemberQ[labelSet, "Crossings"] && KeyExistsQ[assoc, "Crossings"],
     Table[Text[style[cr["Id"]], cr["Pos"], {-1, -1}, Background -> None],
       {cr, assoc["Crossings"]}], {}],
    If[MemberQ[labelSet, "Arcs"],
     Table[
       Text[style[arc["Id"]], Sequence @@ arcLabelSpec[arc["Points"]], Background -> None],
       {arc, assoc["Arcs"]}], {}],
    If[MemberQ[labelSet, "Faces"] && KeyExistsQ[assoc, "Faces"],
     Table[
       Text[style[face["Id"]], polygonCentroid[face["Boundary"]], {0, 0}, Background -> None],
       {face, assoc["Faces"]}], {}]
    };

  Graphics[{faceLayer, strandLayer, labelLayer},
   AspectRatio -> Automatic, ImageSize -> img, PlotRangePadding -> Scaled[0.07]]
];

(* ---- public entry point ---- *)
KnoodleDraw::badinput = "`1` is not a recognized knot/link input.";
(* "CornerRadius": corner arc radius as a fraction of one grid square, in [0, 1/2]
   (0 = sharp corners). "Checkerboard": shade the two-colorable faces. "Labels": a
   subset of {"Crossings","Arcs","Faces"} (a single string is also accepted). *)
Options[KnoodleDraw] = {"Simplify" -> Automatic, "CornerRadius" -> 1/3, "LayoutOptions" -> {},
   "Checkerboard" -> False, "Labels" -> {}, ImageSize -> 340, "Thickness" -> 7};
KnoodleDraw[input_, opts : OptionsPattern[]] := Module[{norm, tsv, def, simp, geos, labelSet},
  norm = toTSV[input];
  If[norm === $Failed, Return[$Failed]];
  {tsv, def} = norm;
  simp = Replace[OptionValue["Simplify"], Automatic -> def];
  geos = runGeometry[tsv, simp, layoutFlags[OptionValue["LayoutOptions"]]];
  If[geos === {}, Return[$Failed]];
  labelSet = Flatten[{OptionValue["Labels"]}];
  render[First[geos], OptionValue["Thickness"], OptionValue[ImageSize],
    OptionValue["CornerRadius"], OptionValue["Checkerboard"], labelSet]
];

End[];
EndPackage[];
