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
diagram is drawn as-is or a simplified diagram of the same knot is drawn.";

$KnoodleBinaryDirectory::usage =
  "$KnoodleBinaryDirectory is the directory holding the knoodle CLI executables.";

Begin["`Private`"];

(* ---- binary locations (development default; overridden when packaged) ---- *)
$KnoodleBinaryDirectory = "/Users/jasoncantarella/Knoodle/tools";
exe[name_String] := FileNameJoin[{$KnoodleBinaryDirectory, name}];

(* ---- context-free head test (KnotTheory symbols live in various contexts) ---- *)
headNameQ[x_, name_String] := MatchQ[Head[x], _Symbol] && SymbolName[Head[x]] === name;

(* ---- run knoodledraw --format=wl (optionally simplifying first) ----
   Returns a list of geometry associations, one per connect-sum summand. *)
runGeometry[tsv_String, simplify_] := Module[{drawIn, out},
  drawIn = If[TrueQ[simplify],
     RunProcess[{exe["knoodlesimplify"], "--streaming-mode"}, "StandardOutput", tsv],
     tsv];
  out = RunProcess[{exe["knoodledraw"], "--format=wl"}, "StandardOutput", drawIn];
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

(* ---- render a geometry association as Graphics ---- *)
render[assoc_Association, thick_, img_] := Graphics[
  {CapForm["Round"], JoinForm["Round"], AbsoluteThickness[thick],
   Table[{ColorData[97][arc["Component"] + 1], Line[arc["Points"]]},
     {arc, assoc["Arcs"]}]},
  AspectRatio -> Automatic, ImageSize -> img, PlotRangePadding -> Scaled[0.07]
];

(* ---- public entry point ---- *)
KnoodleDraw::badinput = "`1` is not a recognized knot/link input.";
Options[KnoodleDraw] = {"Simplify" -> Automatic, ImageSize -> 340, "Thickness" -> 7};
KnoodleDraw[input_, opts : OptionsPattern[]] := Module[{norm, tsv, def, simp, geos},
  norm = toTSV[input];
  If[norm === $Failed, Return[$Failed]];
  {tsv, def} = norm;
  simp = Replace[OptionValue["Simplify"], Automatic -> def];
  geos = runGeometry[tsv, simp];
  If[geos === {}, Return[$Failed]];
  render[First[geos], OptionValue["Thickness"], OptionValue[ImageSize]]
];

End[];
EndPackage[];
