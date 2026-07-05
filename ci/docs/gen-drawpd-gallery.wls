#!/usr/bin/env wolframscript
(* Regenerate Resources/ExampleData/DrawPDGallery: pre-rendered KnotTheory
   DrawPD drawings used by the KnoodleDraw documentation's side-by-side
   comparisons, bundled as paclet assets so the doc examples display DrawPD's
   output even for users who do not have KnotTheory` installed.

   Requires KnotTheory` (https://katlas.org/wiki/KnotTheory) -- the one doc
   generator with a dependency beyond the paclet itself. Run rarely and
   deliberately; the PNGs are committed.

   RUN IN A FULL INTERACTIVE KERNEL (notebook, or a kernel with front-end
   services), via

       Get["<repo>/ci/docs/gen-drawpd-gallery.wls"]

   Do NOT run it through `wolframscript -file` or `wolfram -script`: in
   script-mode kernels KnotTheory's on-demand load of the DrawPD
   implementation comes up structurally broken (Which::argct messages --
   its Which calls lose arguments) and DrawPD then loops for minutes on
   drawings that take 0.08 s in a full kernel. Observed repeatedly on 15.0,
   2026-07-04; mechanism inside KnotTheory's autoload not pinned down. The
   pre-warm + timing self-check below makes a poisoned session fail loudly
   instead of hanging.

   DrawPD cannot draw diagrams containing a monogon (an R1 kink): its
   circle-packing step degenerates (complex-valued radii) and does not
   terminate. Raw knoodle projections of closed space polygons always
   contain a few kinks, so the Gaussian-50-gon entry below removes monogons
   first (and nothing else) before handing the diagram to DrawPD. *)

$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
(* KnotTheory` MUST load before anything that can create System`X (loading
   Knoodle.wl does, via some autoload; wolframscript's own init does too --
   part of why wolframscript is unusable here). If System`X exists first,
   KnotTheory's X splits from it (X::shdw) and DrawPD's solver chews on a
   mismatched crossing representation, spinning for minutes instead of
   0.08 s. Verified empirically both ways, 2026-07-04. *)
Needs["KnotTheory`"];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];

$gallery = FileNameJoin[{$repo, "Resources", "ExampleData", "DrawPDGallery"}];
Quiet[CreateDirectory[$gallery]];

(* ---- the three diagrams (1-indexed KnotTheory row form) ------------------ *)

(* "The Millett unknot", exactly as published on
   https://katlas.org/wiki/Drawing_Planar_Diagrams (the DrawPD manual page). *)
millett = {{1, 10, 2, 11}, {9, 2, 10, 3}, {3, 7, 4, 6}, {15, 5, 16, 4},
   {5, 17, 6, 16}, {7, 14, 8, 15}, {8, 18, 9, 17}, {11, 18, 12, 19},
   {19, 12, 20, 13}, {13, 20, 14, 1}};

(* The granny knot (trefoil # trefoil) as one 6-crossing PD code -- a
   NON-PRIME diagram, the robustness example where DrawPD terminates but
   crushes the two summands into tiny corner tangles. Derived once from
   KnoodleSimplify[{trefoil, trefoil}, "Unite" -> True] (deterministic). *)
granny = {{9, 12, 10, 1}, {1, 4, 2, 5}, {5, 2, 6, 3}, {3, 6, 4, 7},
   {7, 10, 8, 11}, {11, 8, 12, 9}};

(* The z-projection of a Gaussian random 50-gon (SeedRandom[2026]), 21
   crossings raw, with its three R1 monogons removed -- and nothing else --
   for DrawPD's benefit (15 crossings): KnoodleSimplify["SimplifyLevel" -> 1,
   "RandomizeProjection" -> False], level 1 being the Reidemeister-I-only
   diagnostic tier (knoodlesimplify levels rewired upstream, Knoodle
   34ba537/783528d). Derived live below and checked against this committed
   literal. *)
gauss50 = {{27, 1, 28, 30}, {1, 29, 2, 28}, {15, 3, 16, 2}, {3, 15, 4, 14},
   {4, 13, 5, 14}, {16, 5, 17, 6}, {21, 6, 22, 7}, {20, 8, 21, 7},
   {8, 25, 9, 26}, {24, 9, 25, 10}, {19, 10, 20, 11}, {18, 12, 19, 11},
   {23, 13, 24, 12}, {17, 23, 18, 22}, {26, 29, 27, 30}};

(* 13a_1, PD notation as published by KnotInfo
   (https://knotinfo.org, C. Livingston and A. H. Moore). *)
pd13a1 = {{3, 1, 4, 26}, {1, 8, 2, 9}, {7, 2, 8, 3}, {9, 5, 10, 4},
   {5, 14, 6, 15}, {13, 6, 14, 7}, {15, 11, 16, 10}, {11, 20, 12, 21},
   {19, 12, 20, 13}, {21, 17, 22, 16}, {17, 24, 18, 25}, {23, 18, 24, 19},
   {25, 23, 26, 22}};

(* ---- re-derive gauss50 from scratch, so provenance is executable -------- *)
GaussianRandomPolygon[n_] := Accumulate[Standardize[
   RandomVariate[NormalDistribution[], {n, 3}], Mean, 1 &]];
SeedRandom[2026];
derived = Select[ImportString[
    Knoodle`KnoodleSimplify[GaussianRandomPolygon[50], "SimplifyLevel" -> 1,
      "RandomizeProjection" -> False][[1, "serialized"]], "TSV"],
   Length[#] >= 4 &][[All, 1 ;; 4]] + 1;
If[derived =!= gauss50,
 Print["FATAL: derived gauss50 PD does not match the committed literal"]; Exit[1]];

(* ---- likewise re-derive granny (deterministic, no randomness) ------------ *)
trefoil = {{0, 3, 1, 4}, {2, 5, 3, 0}, {4, 1, 5, 2}};
grannyDerived = Select[ImportString[
     Knoodle`KnoodleSimplify[{trefoil, trefoil}, "Unite" -> True][[1, "serialized"]],
     "TSV"], Length[#] >= 4 &][[All, 1 ;; 4]] + 1;
If[grannyDerived =!= granny,
 Print["FATAL: derived granny PD does not match the committed literal"]; Exit[1]];

(* ---- render and export --------------------------------------------------- *)
toPD[rows_] := KnotTheory`PD @@ (KnotTheory`X @@@ rows);

(* Self-check on a REALISTIC diagram before the real renders: in scripted
   kernels DrawPD's on-demand load comes up broken -- tiny diagrams still
   draw, but anything >= ~10 crossings loops forever (0.08 s in a notebook
   kernel), and a small pre-warm does NOT immunize the big ones. The
   TimeConstrained makes an unusable session fail loudly instead of
   hanging; see ci/docs/README.md. *)
With[{t = TimeConstrained[AbsoluteTiming[
      KnotTheory`DrawPD[toPD[millett], {KnotTheory`Gap -> 0.03}];][[1]], 60, 1000.]},
 Print["self-check (millett): ", t, " s"];
 If[t > 30, Print["FATAL: DrawPD unusable in this kernel -- Get this script " <>
    "in a NOTEBOOK kernel; see ci/docs/README.md"]; Exit[1]]];

save[name_, rows_, gap_] := Module[{t, g},
  {t, g} = AbsoluteTiming[KnotTheory`DrawPD[toPD[rows], {KnotTheory`Gap -> gap}]];
  Print["DrawPD ", name, ": ", t, " s"];
  If[t > 60, Print["FATAL: DrawPD is in the deoptimized state (see header)"]; Exit[1]];
  Export[FileNameJoin[{$gallery, name <> "-drawpd.png"}],
   Show[g, ImageSize -> 260], ImageResolution -> 144]];

Print[save["millett", millett, 0.03]];   (* katlas' own recommended Gap *)
Print[save["granny", granny, 0.03]];
Print[save["gauss50", gauss50, 0.02]];
Print[save["13a1", pd13a1, 0.03]];
Print["done: ", $gallery];
