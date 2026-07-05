(* ::Package:: *)

(* Knoodle paclet -- knot/link diagram drawing, simplification, and
   identification. The heavy lifting is done by the Knoodle CLI tools
   (knoodledraw / knoodlesimplify / knoodleidentify), which this package drives
   via RunProcess. The Wolfram side handles representation conversion (KnotData,
   KnotTheory PD/DTCode/GaussCode, 3D curves) and rendering. *)

BeginPackage["Knoodle`"];

KnoodleDraw::usage =
  "KnoodleDraw[input] renders a knot or link diagram as a Graphics object -- or, when \
the input yields several diagrams (a PlanarDiagramComplex or other multi-summand input), \
a list of Graphics sharing one common scale. input may be a KnotData/Knot specification \
(e.g. {3,1} or \"Trefoil\"), a KnotTheory PD[X[...]] / DTCode / GaussCode, a list of 3D \
points, or a native Knoodle PD code (rows of 4 or 5 integers). Option \"Simplify\" \
(Automatic) controls whether the given diagram is drawn as-is or a simplified diagram of \
the same knot is drawn. Option \"Checkerboard\" (False) shades the diagram's \
two-colorable faces. Option \"Labels\" (a subset of {\"Crossings\",\"Arcs\",\"Faces\"}) \
annotates the diagram with 0-based element ids; LabelStyle styles the label text. \
Option \"Orientation\" (False) marks each arc's direction with arrowheads.";

KnoodleSimplify::usage =
  "KnoodleSimplify[input] simplifies a knot or link diagram, returning a PlanarDiagramComplex \
object that KnoodleDraw can render directly. input accepts the same representations as \
KnoodleDraw. Option \"SimplifyLevel\" (Automatic, knoodlesimplify's own default) sets the \
simplification effort: 0 none, 1-3 local-only Reidemeister tiers (I; I+II; all local \
moves), 4 path rerouting, 5 adds summand detection, 6+ (= Automatic) the full Reapr \
pipeline. \"RandomizeProjection\" (True) applies a random shear before \
projecting 3D input, as in KnoodleDraw. \"Unite\" (False, i.e. the default \"split\" shape) \
controls the output shape for composite/split links: False gives one diagram per \
diagrammatically-prime factor (same-colored factors share a link component -- the natural \
input for KnoodleIdentify on a composite knot); True connect-sums same-colored factors back \
together via PlanarDiagramComplex::Connect, giving one diagram per physically split component \
(the natural single-PD-per-component form for KnotTheory/Regina). \"SimplifyOptions\" ({}) \
forwards arbitrary knoodlesimplify flags controlling PlanarDiagramComplex::Simplify's \
algorithm (e.g. {\"dijkstra-strategy\"->\"alternating\", \"canonicalize\"->False} -- see \
knoodlesimplify --help for the full list), the same passthrough convention as \
KnoodleDraw's \"LayoutOptions\". \"OutputFormat\" -> \"KnotTheory\" returns KnotTheory` \
PD codes instead of a PlanarDiagramComplex -- one PD[X[...],...] per physically split \
portion (a list when there are several; PD[Loop[1]] for a 0-crossing portion), ready for \
KnotTheory invariant computations; this implies \"Unite\" -> True, since PD codes cannot \
express that separate diagrams share a link component.";

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

KnoodleIdentify::usage =
  "KnoodleIdentify[input] identifies a knot diagram via the KLUT (Knot LookUp Table), \
returning an Association from each distinct prime knot summand (a KnotSymbol[...]) to its \
multiplicity in the connect-sum decomposition -- e.g. <|KnotSymbol[3,1,True,\"e/r\"]->2|> \
for the square knot. input accepts the same representations as KnoodleDraw (including a \
PlanarDiagramComplex from KnoodleSimplify). A summand outside the table appears as \
Unidentified[n,pd] (n>13, over the table range) or NotFound[n,pd] (n<=13, unresolved even \
after escalation -- suspicious); an unknot gives <||>. Multi-component (link) input fails \
with $Failed and a message -- KnoodleIdentify only identifies knots; use KnoodleSimplify with \
\"Unite\"->True first if the components should be connect-summed into one knot. Option \
\"MaxCrossings\" (Automatic, knoodleidentify's own default of 13) restricts lookup to \
subtables up to that many crossings.";

$KnoodleBinaryDirectory::usage =
  "$KnoodleBinaryDirectory is the directory holding the knoodle CLI executables.";

Begin["`Private`"];

(* ---- binary + data locations --------------------------------------------
   The CLI executables (per SystemID) and the KLUT lookup tables
   (Klut_Keys_NN.bin / Klut_Values_NN.tsv) are declared as "Asset" extensions
   in PacletInfo.wl and located by name via AssetLocation -- no hard-coded
   paths, with the right per-platform binary selected automatically. When this
   package is loaded straight from the source checkout (where those assets
   resolve to files that don't exist yet), each lookup falls back to the
   sibling Knoodle repo's build tree, so ordinary development keeps working. *)
$knoodlePaclet := PacletObject["Knoodle"];

(* AssetLocation for `name`, or `fallback` if unresolved/absent (dev checkout). *)
assetOr[name_String, fallback_String] :=
  With[{loc = Quiet @ $knoodlePaclet["AssetLocation", name]},
    If[StringQ[loc] && (FileExistsQ[loc] || DirectoryQ[loc]), loc, fallback]];

(* The Windows Asset maps "knoodledraw" -> "knoodledraw.exe", so callers always
   ask for the bare tool name and get the right file for this platform. *)
exe[name_String] := assetOr[name, FileNameJoin[{"/Users/jasoncantarella/Knoodle/tools", name}]];

$KnoodleDataDirectory := assetOr["KlutData", "/Users/jasoncantarella/Knoodle/data/Klut"];

$KnoodleBinaryDirectory := DirectoryName[exe["knoodledraw"]];

(* Paclet archives (zip) don't reliably preserve the executable bit, so restore
   it once, at load time, for the bundled binaries. No-op on Windows; harmless
   on a dev checkout (already +x). Failures are ignored so a read-only install
   location can't break loading. *)
If[$OperatingSystem =!= "Windows",
  Quiet @ Run["chmod +x " <> StringRiffle[
     ("\"" <> exe[#] <> "\"") & /@ {"knoodledraw", "knoodlesimplify", "knoodleidentify"}, " "]]];

(* Square grid spacing requested from knoodledraw (see runGeometry). One grid
   square is this many coordinate units. Rendering follows DRAWING-SPEC.md,
   whose unit of account is the subgrid unit u = 1 coordinate unit = 1/4 of
   this pitch: subgrid squares are the closed 1x1 squares centered on the
   lattice's points and lines, and every decoration (arrowhead, arc label,
   crossing gap) lives in its own reserved subgrid square, so nothing ever
   collides (spec sections 1-2). *)
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

(* ---- KnotTheory-format output ("OutputFormat" -> "KnotTheory") ----
   Convert a united PDC serialization into KnotTheory` PD codes on the WL
   side -- the CLI keeps emitting the full PlanarDiagramComplex (nothing is
   lost internally); only this final hop drops what PD codes cannot carry.
   Each "s <flag>" block is one physically split portion of the link: its
   rows' first four columns are Knoodle's 0-based arc labels in exactly
   KnotTheory's X convention, so the code is rows+1 wrapped in X and PD. A
   "u <color>" line is a 0-crossing portion: KnotTheory's PD[Loop[1]]. The
   PD/X/Loop heads are created in the KnotTheory` context WITHOUT loading
   the package -- they are the same symbols a later Needs["KnotTheory`"]
   declares, so results made before the load work after it. *)
pdcPortions[s_String] := Module[{blocks = {}, cur = None, flush},
  flush[] := If[cur =!= None, AppendTo[blocks, cur]; cur = None];
  Do[Which[
     StringStartsQ[line, "u"], flush[]; AppendTo[blocks, "Unknot"],
     StringStartsQ[line, "s"], flush[]; cur = {},
     StringContainsQ[line, "\t"],
      If[cur === None, cur = {}];
      AppendTo[cur, ToExpression /@ StringSplit[line, "\t"]],
     True, Null],                                (* "k" markers, blank lines *)
   {line, StringSplit[s, "\n"]}];
  flush[];
  blocks];

(* One united "s" block can still hold several physically split pieces (the
   CLI's --unite merges split components into one block, arcs disjointly
   renumbered). Split-ness is exactly connectivity of crossings through
   shared arc labels, so the pieces are the connected components of that
   graph. Each piece's arcs are renumbered by rank -- order-preserving, so
   Knoodle's along-the-strand numbering (and hence KnotTheory's implied
   orientation convention) survives -- giving a self-contained code. *)
splitPieces[rows_List] := Module[{byArc, edges, comps},
  byArc = GroupBy[Flatten[MapIndexed[Thread[{#2[[1]], #1[[1 ;; 4]]}] &, rows], 1],
    Last -> First];
  edges = UndirectedEdge @@@ Select[Union /@ Values[byArc], Length[#] == 2 &];
  comps = SortBy[ConnectedComponents[Graph[Range[Length[rows]], edges]], Min];
  Function[piece, With[{arcs = Union @@ piece[[All, 1 ;; 4]]},
     piece /. Thread[arcs -> Range[Length[arcs]] - 1]]][rows[[Sort[#], 1 ;; 4]]] & /@ comps];

toKnotTheoryPD["Unknot"] := Symbol["KnotTheory`PD"][Symbol["KnotTheory`Loop"][1]];
toKnotTheoryPD[rows_List] :=
  Symbol["KnotTheory`PD"] @@ (Symbol["KnotTheory`X"] @@@ (rows + 1));

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

(* ---- bends (spec 3.3): every 90-degree bend is a quarter-circle of radius
   exactly u/2, tangent to both strand centerlines, so the whole bend (stroke
   included) stays inside the lattice point's corner subgrid square. The radius
   is forced -- tangency plus containment leave no free parameter -- which is
   why the old "CornerRadius" option no longer exists. cornerArc's clamp to
   half the shorter adjacent edge is a safety net only: OrthoDraw edges are at
   least one full grid pitch, and label cuts keep >= 3u/2 of straight run on
   either side of a bend. *)
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

(* ---- under-strand gaps (spec 3.4): the under-strand is cut exactly on the
   crossing's corner-square boundary, u/2 from the crossing point, but
   knoodledraw's --gap-size is integer-only and insets each under-strand
   endpoint by a full unit. An arc endpoint at Manhattan distance exactly 1
   from a crossing is such an inset endpoint -- over-strand endpoints sit
   exactly ON their crossing, and distinct lattice events are a full grid
   pitch apart, so there are no false matches -- and is pulled halfway back
   in. Exact (integer -> half-integer) arithmetic, so the station enumeration
   below stays exact. *)
underGapEnd[crossPos_][p_] := With[
   {c = SelectFirst[crossPos, Total[Abs[p - #]] == 1 &]},
   If[MissingQ[c], p, (p + c)/2]];
underGapPoints[pts_, crossPos_] := MapAt[underGapEnd[crossPos], pts, {{1}, {-1}}];

(* Stations along the axis-aligned segment a -> b (varying coordinate index i):
   the points whose varying coordinate is congruent to a residue in res, mod
   the grid pitch. Arrowhead subgrid squares sit at offsets 1 and 3 along
   every drawing edge (spec 4), arc-label squares at offset 2, the edge
   midpoint (spec 5); the fixed coordinate is always on a lattice line, so
   these are exactly the reserved squares' centers. *)
stations[a_, b_, i_, res_] := With[{lo = Min[a[[i]], b[[i]]], hi = Max[a[[i]], b[[i]]]},
   ReplacePart[a, i -> #] & /@ Select[Range[Ceiling[lo], Floor[hi]], MemberQ[res, Mod[#, $gridSize]] &]];

(* One pass over an arc's polyline: collect arrowhead specs {center, direction}
   for every traversed arrowhead square (spec 4.1) and arc-label specs
   {center, textDirection} for every traversed arc-label square (spec 5.2-3:
   horizontal edges read left-to-right; vertical edges read along the arc's
   orientation), and -- when cutQ, i.e. arc labels are shown -- cut the
   polyline at each label square's two boundaries, u/2 to either side of its
   center, so the label sits inline in the gap (spec 5.1). Cut centers are
   always >= 3u/2 from the nearest vertex, so cuts never touch bends, and
   every piece keeps >= 2 points. *)
arcDecorations[pts_, cutQ_] := Module[
  {cur = {First[pts]}, pieces = {}, arrows = {}, labels = {}, i, dir, mids},
  Do[
   i = If[seg[[1, 1]] == seg[[2, 1]], 2, 1];
   dir = Sign[seg[[2]] - seg[[1]]];
   arrows = Join[arrows, {#, dir} & /@ stations[seg[[1]], seg[[2]], i, {1, 3}]];
   mids = SortBy[stations[seg[[1]], seg[[2]], i, {2}], dir[[i]] #[[i]] &];
   labels = Join[labels, {#, If[i == 1, {1, 0}, dir]} & /@ mids];
   If[cutQ, Do[AppendTo[cur, m - dir/2]; AppendTo[pieces, cur]; cur = {m + dir/2}, {m, mids}]];
   AppendTo[cur, seg[[2]]],
   {seg, Partition[pts, 2, 1]}];
  <|"Pieces" -> Append[pieces, cur], "Arrows" -> arrows, "Labels" -> labels|>
];

(* ---- orientation arrowheads (spec 4.2-3): a solid swept-back head
   superimposed on the continuous strand, centered in its subgrid square and
   pointing along dir -- 0.9u tip-to-tail, 0.65u wide, so it fits the 1x1
   square at any drawing scale. It is a coordinate-space Polygon, deliberately
   NOT an Arrowheads[] spec (whose size would track the image instead of the
   grid), and carries no color directive so it inherits the ambient strand
   color. *)
$arrowheadPts = 0.9 {{-1, 0.36}, {0, 0}, {-1, -0.36}, {-0.75, 0}};
arrowheadPolygon[pos_, dir : {dx_, dy_}] :=
  Polygon[(pos + 0.45 dir + {{dx, -dy}, {dy, dx}} . #) & /@ $arrowheadPts];

(* ---- label text style (spec 8.4): the default pins FontFamily ->
   "Source Sans Pro" (bundled in every Wolfram installation's
   SystemFiles/Fonts), because the largest-fit sizing below is only exact for
   a font the kernel can measure at drawing time; color/opacity use the theme
   system (ThemeColor, LightDark-aware) so labels stay legible in both modes.
   User LabelStyle directives merge AFTER the defaults, so LabelStyle -> Bold
   bolds the pinned font while LabelStyle -> {FontFamily -> ...} swaps it --
   and measurement runs under the fully merged style, so a wider family or
   weight automatically participates in the fit. *)
$labelBaseStyle = {Opacity[0.7], ThemeColor["Foreground"], FontFamily -> "Source Sans Pro"};
resolveLabelStyle[user_] := Join[$labelBaseStyle,
   DeleteCases[Flatten[{user} //. Directive[d___] :> {d}], None | Automatic]];

(* A numeric font size requested inside LabelStyle (bare number or
   FontSize -> n), for the spec 8.5 precedence rules; None when absent. *)
userFontSize[dirs_] := Replace[
   Cases[dirs, fs_?NumericQ | (FontSize -> fs_?NumericQ) :> fs],
   {{} -> None, l_ :> Last[l]}];

(* Rendered extent of one label in points, per point of font size, measured
   under the fully resolved style (spec 8.2: extent, not character count, is
   the constrained quantity). Text metrics are linear in FontSize, so one
   measurement at a reference size suffices. Rasterize needs a front end; if
   none is reachable, fall back to a generous digit-metric estimate so
   headless drawing still works. *)
labelExtent[text_, dirs_List] := Quiet @ Check[
   Most[Rasterize[Style[text, Sequence @@ dirs, FontSize -> 96], "BoundingBox"]]/96.,
   {0.65 StringLength[ToString[text]], 1.6}];

(* Largest font size that fits a measured extent into a box of {w, h} subgrid
   units, per unit of the points-per-u scale. Sized to a fixed safety fraction
   of the box (spec 8.6) so platform rasterization differences can't overflow
   it. *)
$fitFraction = 0.96;
fitCoeff[ext_, box_] := Min[box/ext];

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

(* ---- face label placement (spec 7): a discretized "pole of inaccessibility",
   restricted to grid-square centers, so it stays well inside even very
   non-convex faces (a plain polygon centroid can land outside a non-convex
   face entirely). A grid square is one cell of OrthoDraw's own layout grid
   (BoundingBox is its width/height in cells). Boundary distance and
   containment both come straight from the Region framework. The label is
   then centered in the host cell's (2,2)-(3,2) reserved subgrid region --
   u/2 to the right of the cell center. *)
gridSquareCenters[w_, h_] := Flatten[
   Table[$gridSize {i + 1/2, j + 1/2}, {i, 0, w - 1}, {j, 0, h - 1}], 1];

$faceRegionOffset = {1/2, 0};

(* Lexicographic-max of {distance, x, y} -- WL's default Sort/Order on same-shape
   lists of reals is lexicographic, so Last@Sort gives exactly that: farthest
   from the boundary, ties broken rightmost then topmost. *)
lexBest[scored_] := Last[Sort[scored]][[{2, 3}]];

interiorFaceLabelPos[face_, w_, h_] := Module[{poly = face["Boundary"], inside},
  inside = Select[gridSquareCenters[w, h], RegionMember[Polygon[poly]]];
  If[inside === {}, Return[polygonCentroid[poly]]];  (* face smaller than one grid cell *)
  lexBest[{RegionDistance[Line[poly], #], #[[1]], #[[2]]} & /@ inside] + $faceRegionOffset
];

(* The exterior face is unbounded, so candidates are the ring of grid cells
   framing the diagram's own bounding rectangle R that belong to no interior
   face; when that set is empty (the diagram fills R edge-to-edge), R grows
   one column to the right, all of whose cells are exterior -- one extension
   always suffices (spec 7.3). Distance is capped by closeness to R's own
   boundary too, so the label doesn't crowd the image edge. *)
exteriorFaceLabelPos[extFace_, w_, h_, interiorPolys_] := Module[
  {rw = w, notInterior, ring, cand},
  notInterior = RegionMember[RegionUnion @@ (Polygon /@ interiorPolys)] /* Not;
  ring = $gridSize (# + 1/2) & /@ Select[Tuples[{Range[0, w - 1], Range[0, h - 1]}],
     (#[[1]] == 0 || #[[1]] == w - 1 || #[[2]] == 0 || #[[2]] == h - 1) &];
  cand = Select[ring, notInterior];
  If[cand === {}, rw = w + 1; cand = Table[$gridSize ({w, j} + 1/2), {j, 0, h - 1}]];
  $faceRegionOffset + lexBest[{Min[RegionDistance[Line[extFace["Boundary"]], #],
       RegionDistance[RegionBoundary[Rectangle[{0, 0}, $gridSize {rw, h}]], #]], #[[1]], #[[2]]} & /@ cand]
];

faceLabelPos[face_, w_, h_, interiorPolys_] := If[TrueQ[face["Exterior"]],
   exteriorFaceLabelPos[face, w, h, interiorPolys],
   interiorFaceLabelPos[face, w, h]];

(* ---- checkerboard face fill: low-opacity theme-color washes rather than fixed
   colors, so shading adapts to light/dark mode and to custom notebook themes.
   Color[+1] faces are washed with the notebook's Accent1 (ties the shading to
   the theme's own accent); Color[-1] faces get a barely-there foreground wash
   (like graph paper), so the picture reads as "shaded", not "painted". *)
faceFill[colorSign_] := If[colorSign > 0,
  {Opacity[0.14], ThemeColor["Accent1"]},
  {Opacity[0.045], ThemeColor["Foreground"]}];

geoComponentCount[assoc_] := If[KeyExistsQ[assoc, "Unknot"], 1,
   Max[assoc["Arcs"][[All, "Component"]], -1] + 1];

(* ---- strand coloring ----
   knoodledraw (since Knoodle 3fe15b0) exports each arc's raw wire color --
   "Color", the physical link component, stable across every summand of one
   drawing call -- alongside the per-summand topological "Component" index
   (which restarts at 0 in each summand); colored unknot markers carry the
   same key. When every record has it, all summands share ONE palette keyed
   by these color classes: the connect-sum factors of a knot all draw in a
   single color, and a split link's components keep their colors across
   factors. When the key is absent (older binaries), fall back to the old
   scheme: each summand claims its own fresh run of palette colors, keyed by
   "Component" plus a running offset. Bare unknot markers without a color
   (uncolored empty summands) get fresh palette slots after the wire
   classes. wireColorIndex returns class -> palette index, or None for the
   fallback. *)
wireColorIndex[geos_List] := Module[{wire},
  If[! AllTrue[geos, KeyExistsQ[#, "Unknot"] || AllTrue[#["Arcs"], KeyExistsQ[#, "Color"] &] &],
   Return[None]];
  wire = Union @@ Map[If[KeyExistsQ[#, "Unknot"],
      If[KeyExistsQ[#, "Color"], {#["Color"]}, {}], Union[#["Arcs"][[All, "Color"]]]] &, geos];
  AssociationThread[wire -> Range[Length[wire]]]];

(* ---- per-summand drawing content ----------------------------------------
   Everything about one summand except the two globally-resolved quantities
   (font size and stroke width): checkerboard fills, strands (under-gaps
   widened, label gaps cut, bends rounded), arrowheads, label records (text,
   position, reading direction, and the {w, h} subgrid box the text must fit
   -- 1x1 for arc labels, 2x1 for crossing and face labels, spec 8.2), the
   plot range, and the summand's legend entries ({labels, swatch colors} for
   PlotLegends). Strand colors: wire-color classes via idx when available
   (see wireColorIndex -- labels are then the input's own component colors),
   else the compOffset fallback, where each summand claims its own run of
   ColorData[97] colors instead of restarting at color 1. ord is this
   summand's ordinal among colorless unknot markers (wire mode only). *)
(* off is the Text offset spec ({0, 0} = centered at pos; {-1, 0} = text's
   left-center at pos, i.e. left-justified). *)
labelRec[text_, pos_, dir_, box_, off_ : {0, 0}] :=
  <|"Text" -> text, "Pos" -> pos, "Dir" -> dir, "Box" -> box, "Off" -> off|>;

summandContent[assoc_, checkerboardQ_, labelSet_, orientQ_, compOffset_, idx_, ord_] := Module[
  {w, h, crossPos, interiorFaces, interiorPolys, decs, fills, strands, labels, lows, highs,
   strandColor, comps},
  If[KeyExistsQ[assoc, "Unknot"], Return[unknotContent[assoc, compOffset, idx, ord]]];
  strandColor = If[idx === None,
    ColorData[97][#["Component"] + compOffset + 1] &,
    ColorData[97][idx[#["Color"]]] &];
  comps = If[idx === None,
    With[{c = Union[assoc["Arcs"][[All, "Component"]]] + compOffset},
     {c, ColorData[97][# + 1] & /@ c}],
    With[{c = Union[assoc["Arcs"][[All, "Color"]]]},
     {c, ColorData[97][idx[#]] & /@ c}]];
  {w, h} = assoc["BoundingBox"];
  crossPos = If[KeyExistsQ[assoc, "Crossings"], assoc["Crossings"][[All, "Pos"]], {}];
  interiorFaces = If[KeyExistsQ[assoc, "Faces"], Select[assoc["Faces"], ! TrueQ[#["Exterior"]] &], {}];
  interiorPolys = interiorFaces[[All, "Boundary"]];
  decs = arcDecorations[underGapPoints[#["Points"], crossPos], MemberQ[labelSet, "Arcs"]] & /@
    assoc["Arcs"];

  (* faceFill[...] returns a *list* of directives ({Opacity[...], color}); it must be
     spliced (Sequence @@) into the surrounding primitive list, not nested as a single
     list element -- Graphics directive scoping does not propagate out of a nested
     sub-list. The exterior face is never filled. *)
  fills = If[TrueQ[checkerboardQ],
    Table[{Sequence @@ faceFill[face["Color"]], EdgeForm[], Polygon[face["Boundary"]]},
     {face, interiorFaces}], {}];

  strands = MapThread[
    {strandColor[#1],
      Line[roundedPolyline[#, 1/2] & /@ #2["Pieces"]],
      If[TrueQ[orientQ], arrowheadPolygon @@@ #2["Arrows"], Nothing]} &,
    {assoc["Arcs"], decs}];

  labels = Join[
    If[MemberQ[labelSet, "Arcs"],
     Join @@ MapThread[Function[{arc, dec},
        labelRec[arc["Id"], #[[1]], #[[2]], {1, 1}] & /@ dec["Labels"]],
       {assoc["Arcs"], decs}], {}],
    (* a crossing's host cell is the one with the crossing at its (0,0) corner;
       the label is left-justified in the (1,1)-(2,1) reserved region -- its
       left-center (Text offset {-1, 0}) at the region's left edge, u {1/2, 1}
       up-right of the crossing point, the edge nearest the crossing (spec 6) *)
    If[MemberQ[labelSet, "Crossings"] && KeyExistsQ[assoc, "Crossings"],
     labelRec[#["Id"], #["Pos"] + {1/2, 1}, {1, 0}, {2, 1}, {-1, 0}] & /@ assoc["Crossings"], {}],
    If[MemberQ[labelSet, "Faces"] && KeyExistsQ[assoc, "Faces"],
     labelRec[#["Id"], faceLabelPos[#, w, h, interiorPolys], {1, 0}, {2, 1}] & /@
      assoc["Faces"], {}]];

  (* plot range: the full subgrid footprint -- bounding box + u/2 on every side
     (spec 3.6) -- stretched to cover any label box that leaves it (only the
     exterior face label can, via spec 7.3's extension column) *)
  lows = Prepend[(#Pos - (1 + #Off) #Box/2) & /@ labels, {-1/2, -1/2}];
  highs = Prepend[(#Pos + (1 - #Off) #Box/2) & /@ labels, $gridSize {w, h} + 1/2];
  <|"Fills" -> fills, "Strands" -> strands, "Labels" -> labels,
   "PlotRange" -> Transpose[{Min /@ Transpose[lows], Max /@ Transpose[highs]}],
   "Legend" -> comps|>
];

(* A bare "<|"Unknot"->True|>" marker (knoodledraw's stand-in for a 0-crossing
   summand -- see the C++-side comment on DrawKnot) draws as the boundary of
   one drawing cell with the standard u/2 rounded bends -- the same orthogonal
   drawing language as every other summand, not a foreign circle (spec 9.4).
   The loop starts and ends mid-edge so all four corners are interior vertices
   of the polyline and get rounded; the two ends butt-join seamlessly on the
   straight run. It carries no arcs, crossings, or faces -- hence no labels
   and no arrowheads -- but participates in the common scale. A colored marker
   (<|"Unknot"->True,"Color"->k|>) joins wire class k; a colorless one gets
   the ord-th fresh palette slot after the wire classes (or the plain
   compOffset slot in fallback mode). *)
unknotContent[assoc_, compOffset_, idx_, ord_] := Module[{slot, label},
  {slot, label} = Which[
    idx === None, {compOffset + 1, compOffset},
    KeyExistsQ[assoc, "Color"], {idx[assoc["Color"]], assoc["Color"]},
    True, With[{s = Length[idx] + ord}, {s, s - 1}]];
  <|"Fills" -> {},
   "Strands" -> {{ColorData[97][slot],
      Line[roundedPolyline[$gridSize {{1/2, 0}, {1, 0}, {1, 1}, {0, 1}, {0, 0}, {1/2, 0}}, 1/2]]}},
   "Labels" -> {}, "PlotRange" -> {{-1/2, $gridSize + 1/2}, {-1/2, $gridSize + 1/2}},
   "Legend" -> {{label}, {ColorData[97][slot]}}|>];

(* ---- stroke width (spec 3.1): at most u/3 at the common scale -- mandatory,
   so strokes never reach a cell's interior 3x3 block and the crossing-gap
   clearance survives any rescaling -- and additionally never more than 7 pt
   absolute (the old default's cap, kept so small diagrams keep their familiar
   weight). An explicit numeric "Thickness" (printer's points) is clamped to
   the same u/3 bound; any other directive passes through unclamped (escape
   hatch, at the user's own risk). s is the points-per-subgrid-unit scale. *)
imageWidthPt[img_] := Which[
   NumericQ[img], img,
   MatchQ[img, {_?NumericQ, _}], First[img],
   True, 340.];
resolveThickness[Automatic, s_] := AbsoluteThickness[Min[7., s/3]];
resolveThickness[t_?NumericQ, s_] := AbsoluteThickness[Min[t, s/3]];
resolveThickness[t_, _] := t;

(* ---- assemble one summand's Graphics at the common scale s (points per
   subgrid unit). Explicit PlotRange with no range/image padding, so s is
   exact: ImageSize = s * (plot-range width) -- every margin the drawing
   needs is already inside the plot range (spec 3.6). legendQ attaches a
   LineLegend of this drawing's own (global, 0-based) component numbers. *)
summandGraphics[content_, s_, thickD_, dirs_, fontSize_, legendQ_] := Module[{g},
  g = Graphics[
    {content["Fills"],
     {CapForm["Butt"], JoinForm["Round"], thickD, content["Strands"]},
     Table[Text[Style[l["Text"], Sequence @@ dirs, FontSize -> fontSize],
        l["Pos"], l["Off"], l["Dir"]], {l, content["Labels"]}]},
    PlotRange -> content["PlotRange"], PlotRangePadding -> None, ImagePadding -> None,
    AspectRatio -> Automatic,
    ImageSize -> s (content["PlotRange"][[1, 2]] - content["PlotRange"][[1, 1]])];
  If[TrueQ[legendQ],
   Legended[g, LineLegend[content["Legend"][[2]], content["Legend"][[1]]]],
   g]
];

(* ---- render: resolve the two global quantities and build one Graphics per
   summand (spec 8-9). The common scale s comes from ImageSize -- applied to
   the widest drawing, every other drawing proportionally smaller -- unless
   LabelStyle requests a FontSize and no explicit ImageSize is given, in which
   case the requested size is honored and sets s instead (spec 8.5 run in
   reverse); when both are given, ImageSize wins. The label font size is the
   largest at which every arc label fits its 1x1 subgrid box and every
   crossing/face label its 2x1 box, measured once per distinct label text
   under the fully resolved style, uniformly across ALL summands (spec 8.2-3).
   Multi-summand output is a List of Graphics -- never a GraphicsGrid, which
   would renormalize the cells and break the common scale (spec 9.3). *)
render[geos_List, thick_, img_, imageGivenQ_, checkerboardQ_, labelSet_, legendQ_, orientQ_, labelStyleOpt_] :=
 Module[{idx, contents, dirs, labels, extents, fitK, ufs, s, fontSize, thickD, drawings},
  idx = wireColorIndex[geos];
  contents = MapThread[summandContent[#1, checkerboardQ, labelSet, orientQ, #2, idx, #3] &,
    {geos, Most[FoldList[Plus, 0, geoComponentCount /@ geos]],
     Most[FoldList[Plus, 1, Boole[KeyExistsQ[#, "Unknot"] && ! KeyExistsQ[#, "Color"]] & /@ geos]]}];
  dirs = resolveLabelStyle[labelStyleOpt];
  labels = Join @@ (#["Labels"] & /@ contents);
  extents = AssociationMap[labelExtent[#, dirs] &, DeleteDuplicates[#Text & /@ labels]];
  fitK = If[labels === {}, None, Min[fitCoeff[extents[#Text], #Box] & /@ labels]];
  ufs = userFontSize[dirs];
  s = If[fitK =!= None && ufs =!= None && ! imageGivenQ,
    ufs/($fitFraction fitK),
    imageWidthPt[img]/Max[(#["PlotRange"][[1, 2]] - #["PlotRange"][[1, 1]]) & /@ contents]];
  fontSize = Which[
    fitK === None, None,
    ufs =!= None && ! imageGivenQ, ufs,
    True, $fitFraction fitK s];
  thickD = resolveThickness[thick, s];
  drawings = summandGraphics[#, s, thickD, dirs, fontSize, legendQ] & /@ contents;
  If[Length[drawings] == 1, First[drawings], drawings]
];

(* ---- public entry point ---- *)
KnoodleDraw::badinput = "`1` is not a recognized knot/link input.";
KnoodleDraw::failed =
  "knoodledraw produced no geometry for this input (degenerate or self-intersecting \
geometry, or an invalid diagram).";
(* "Checkerboard": shade the two-colorable faces. "Labels": a subset of
   {"Crossings","Arcs","Faces"} (a single string is also accepted). Crossing
   and face labels sit in their host cell's reserved region; arc labels are
   inline -- the strand is cut for one subgrid unit at every traversed edge's
   midpoint and the label sits in the gap, so an arc spanning k edges shows
   its label k times (a debugging view of the PD code, not a presentation
   default). LabelStyle: text styling only (family, weight, color, ...),
   merged over the pinned default font (Source Sans Pro); a numeric FontSize
   is honored -- and sets the drawing scale -- only when no explicit
   ImageSize is given, otherwise the largest-fit rule sizes the text.
   "ExteriorFace": which face OrthoDraw lays out as the unbounded exterior
   region (a non-negative integer, 0-based; Automatic, the default, is
   OrthoDraw's own default -- the largest face by arc count). Applies
   uniformly to every summand of a multi-summand diagram. PlotLegends ->
   Automatic adds a legend matching each link component's strand color to
   its component number (attached per drawing on multi-summand output).
   With current knoodledraw binaries the numbers are the input's own wire
   colors -- the physical link components, shared across all summands, so
   a knot's connect-sum factors all draw in one color; with older binaries
   the legend falls back to per-summand component runs.
   "RandomizeProjection" (True by default): apply a random shear before
   projecting 3D geometry to a diagram. The default projection is straight
   down the z axis, which can degenerate on vertical/coplanar segments,
   so this defaults on; set to False to get the plain z-axis projection
   (e.g. for reproducibility). Only meaningful for 3D input read from stdin
   (KnotData/space-curve/point-list inputs); a no-op otherwise.
   "Thickness": Automatic (default) draws strands u/3 wide (capped at 7 pt);
   a number is an AbsoluteThickness in printer's points, clamped to the same
   u/3 bound; any other directive is used as-is.
   "Orientation": False (default) draws unoriented strands; True puts an
   arrowhead in every traversed arrowhead square -- two per drawing edge
   (spec 4.1; All is accepted as a synonym for True). Unknot-marker summands
   carry no arc data, so they draw without arrowheads.
   ImageSize: applies to the widest drawing of the output; on multi-summand
   output every other drawing gets a proportionally smaller ImageSize at the
   common scale (spec 9). *)
Options[KnoodleDraw] = {"Simplify" -> Automatic, "LayoutOptions" -> {},
   "Checkerboard" -> False, "Labels" -> {}, LabelStyle -> {}, "ExteriorFace" -> Automatic,
   PlotLegends -> None, "RandomizeProjection" -> True, ImageSize -> 340,
   "Thickness" -> Automatic, "Orientation" -> False};
KnoodleDraw[input_, opts : OptionsPattern[]] := Module[{norm, tsv, def, simp, geos, labelSet, extFlag},
  norm = toTSV[input];
  If[norm === $Failed, Return[$Failed]];
  {tsv, def} = norm;
  simp = Replace[OptionValue["Simplify"], Automatic -> def];
  extFlag = Replace[OptionValue["ExteriorFace"],
     {n_Integer?NonNegative :> {"--exterior-face=" <> ToString[n]}, _ :> {}}];
  geos = runGeometry[tsv, simp, Join[toCliFlags[OptionValue["LayoutOptions"]], extFlag],
    TrueQ[OptionValue["RandomizeProjection"]]];
  If[geos === {}, Message[KnoodleDraw::failed]; Return[$Failed]];
  labelSet = Flatten[{OptionValue["Labels"]}];
  render[geos, OptionValue["Thickness"], OptionValue[ImageSize],
    FilterRules[Flatten[{opts}], ImageSize] =!= {},
    OptionValue["Checkerboard"], labelSet, OptionValue[PlotLegends] =!= None,
    MatchQ[OptionValue["Orientation"], True | All], OptionValue[LabelStyle]]
];

KnoodleSimplify::badinput = "`1` is not a recognized knot/link input.";
KnoodleSimplify::failed =
  "knoodlesimplify produced no result for this input (degenerate or self-intersecting \
geometry, or an invalid diagram).";
(* "SimplifyLevel": knoodlesimplify's --simplify-level (Automatic = its own
   default, 6). The scale (rewired upstream at Knoodle 34ba537; levels 1-3
   were silent no-ops before): 0 = none (PD passthrough); 1-3 = local-only
   diagnostic tiers (1 Reidemeister I, 2 R I+II, 3 all local moves incl.
   assisted R1a/R2a) with no rerouting; 4 = path rerouting; 5 = + summand
   detection; 6+ = full Reapr. Note 3 -> 4 is not a superset: level 4 drops
   the local pass (upstream tuning: it doesn't help once rerouting engages).
   "RandomizeProjection": as in KnoodleDraw, applies only to 3D
   input read from stdin. "Unite": False (default) is knoodlesimplify's own
   --split (one diagram per prime factor); True is --unite (connect-sums
   same-colored factors into one diagram per split component -- see
   KnoodleSimplify::usage). "SimplifyOptions": arbitrary knoodlesimplify
   flags, same passthrough convention as KnoodleDraw's "LayoutOptions".
   "OutputFormat": "PlanarDiagramComplex" (default) wraps the full complex;
   "KnotTheory" returns KnotTheory` PD codes instead -- one PD[X[...], ...]
   per physically split portion of the link (a bare PD when there is only
   one, a list otherwise; a 0-crossing portion is PD[Loop[1]]) -- ready for
   KnotTheory invariant computations. PD output implies "Unite" -> True:
   the format cannot express that separate diagrams share a link component
   (the complex's cross-summand colors), so same-colored connect-sum
   factors are spliced back together first. *)
Options[KnoodleSimplify] = {"SimplifyLevel" -> Automatic, "RandomizeProjection" -> True,
   "Unite" -> False, "SimplifyOptions" -> {}, "OutputFormat" -> "PlanarDiagramComplex"};
KnoodleSimplify::badformat = "`1` is not a recognized \"OutputFormat\" \
(\"PlanarDiagramComplex\" or \"KnotTheory\").";
KnoodleSimplify[input_, opts : OptionsPattern[]] := Module[
  {norm, tsv, fmt, levelFlag, randFlag, uniteFlag, extraFlags, serialized, pds},
  norm = toTSV[input];
  If[norm === $Failed, Message[KnoodleSimplify::badinput, input]; Return[$Failed]];
  tsv = First[norm];
  fmt = Replace[OptionValue["OutputFormat"], Automatic -> "PlanarDiagramComplex"];
  If[! MemberQ[{"PlanarDiagramComplex", "KnotTheory"}, fmt],
   Message[KnoodleSimplify::badformat, fmt]; Return[$Failed]];
  levelFlag = Replace[OptionValue["SimplifyLevel"],
     {Automatic -> {}, n_Integer :> {"--simplify-level=" <> ToString[n]}}];
  randFlag = If[TrueQ[OptionValue["RandomizeProjection"]], {"--randomize-projection"}, {}];
  uniteFlag = If[TrueQ[OptionValue["Unite"]] || fmt === "KnotTheory", {"--unite"}, {}];
  extraFlags = toCliFlags[OptionValue["SimplifyOptions"]];
  serialized = runSimplifyPdc[tsv, Join[levelFlag, randFlag, uniteFlag, extraFlags]];
  (* Empty output means the tool bailed (degenerate/self-intersecting
     geometry, invalid diagram): say so rather than returning a quietly
     empty complex. A genuine unknot is NOT empty ("u <color>" line). *)
  If[! StringQ[serialized] || StringTrim[serialized] === "",
   Message[KnoodleSimplify::failed]; Return[$Failed]];
  If[fmt === "KnotTheory",
   pds = toKnotTheoryPD /@ Join @@ Map[
      If[# === "Unknot", {"Unknot"}, splitPieces[#]] &, pdcPortions[serialized]];
   If[Length[pds] == 1, First[pds], pds],
   PlanarDiagramComplex[<|"serialized" -> serialized|>]]
];

(* ---- run knoodleidentify, returning the raw stdout association-text line.
   Unlike knoodlesimplify/knoodledraw, knoodleidentify has no --streaming-mode
   flag (it reads stdin directly whenever no file argument is given), so this
   is simpler than runSimplifyPdc/runGeometry: just the same
   File[...]-vs-stdin dispatch. *)
runIdentify[in_, extraFlags_List] := Module[{dataFlag = {"--data-dir=" <> $KnoodleDataDirectory}},
   If[Head[in] === File,
     RunProcess[Join[{exe["knoodleidentify"]}, dataFlag, extraFlags, {First[in]}], "StandardOutput"],
     RunProcess[Join[{exe["knoodleidentify"]}, dataFlag, extraFlags], "StandardOutput", in]]
];

KnoodleIdentify::badinput = "`1` is not a recognized knot/link input.";
KnoodleIdentify::link =
  "Input is a link (`1` crossings, multiple components) -- KnoodleIdentify only identifies \
knots. Use KnoodleSimplify with \"Unite\"->True first if the components should be treated as \
connect-summed into one knot.";
KnoodleIdentify::failed =
  "knoodleidentify produced no result for this input (a degenerate projection or an \
invalid diagram).";
(* "MaxCrossings": knoodleidentify's --max-crossings (Automatic = its own
   default, 13). "RandomizeProjection": as in KnoodleDraw/KnoodleSimplify --
   randomly rotate 3D geometry before projecting (the flag reached
   knoodleidentify upstream 2026-07-03); no-op for explicit diagram input. *)
Options[KnoodleIdentify] = {"MaxCrossings" -> Automatic, "RandomizeProjection" -> True};
KnoodleIdentify[input_, opts : OptionsPattern[]] := Module[
  {norm, tsv, maxFlag, randFlag, out, result, linkCrossings},
  norm = toTSV[input];
  If[norm === $Failed, Message[KnoodleIdentify::badinput, input]; Return[$Failed]];
  tsv = First[norm];
  maxFlag = Replace[OptionValue["MaxCrossings"],
     {Automatic -> {}, n_Integer?Positive :> {"--max-crossings=" <> ToString[n]}}];
  randFlag = If[TrueQ[OptionValue["RandomizeProjection"]], {"--randomize-projection"}, {}];
  out = runIdentify[tsv, Join[maxFlag, randFlag]];
  If[! StringQ[out], Return[$Failed]];
  result = ToExpression[StringTrim[out]];
  If[Head[result] =!= Association,
   Message[KnoodleIdentify::failed]; Return[$Failed]];
  (* headNameQ, not a literal Link[n_] pattern: ToExpression parses
     knoodleidentify's output at *runtime*, in whatever context is active at
     the call site, so the Link it produces is not necessarily
     Knoodle`Private`Link (the one this file's own Link[n_] would have been
     compiled against at load time) -- the same context-independence
     headNameQ already exists for elsewhere (matching KnotTheory symbols
     regardless of which context that package happens to load into).
     Declaring a public Knoodle`Link would only trade this for a worse
     problem: shadowing the unrelated built-in System`Link (WSTP links). *)
  linkCrossings = Cases[Keys[result], k_ /; headNameQ[k, "Link"] :> First[k]];
  If[linkCrossings =!= {},
   Message[KnoodleIdentify::link, First[linkCrossings]];
   Return[$Failed]];
  result
];

End[];
EndPackage[];
