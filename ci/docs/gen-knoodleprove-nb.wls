#!/usr/bin/env wolframscript
(* Regenerate Documentation/English/ReferencePages/Symbols/KnoodleProve.nb
   with Notes + options table + genuinely-evaluated examples. The examples
   check the move traces bundled in Resources/ExampleData/Traces. *)

(* Repo root: this script lives in ci/docs/. *)
$repo = ExpandFileName[FileNameJoin[{DirectoryName[$InputFileName], "..", ".."}]];
Get[FileNameJoin[{$repo, "Kernel", "Knoodle.wl"}]];
(* Register the source checkout as a paclet so AssetLocation lookups in the
   examples resolve during generation, same as on an installed paclet. *)
PacletDirectoryLoad[$repo];

$out = FileNameJoin[{$repo, "Documentation", "English", "ReferencePages", "Symbols", "KnoodleProve.nb"}];

(* Input cells: built from the code's InputForm string through the front
   end's own parser, as in the other generators (see gen-knoodledraw-nb.wls). *)
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

categorization = Cell[CellGroupData[{
   Cell["Categorization", "CategorizationSection"],
   Cell["Symbol", "Categorization", CellLabel -> "Entity Type"],
   Cell["Knoodle", "Categorization", CellLabel -> "Paclet Name"],
   Cell["Knoodle`", "Categorization", CellLabel -> "Context"],
   Cell["Knoodle/ref/KnoodleProve", "Categorization", CellLabel -> "URI"]}, Closed]];

usageSection = Cell[CellGroupData[{
   Cell["KnoodleProve", "ObjectName"],
   Cell[TextData[{
     Cell["   ", "ModInfo"],
     Cell[BoxData[RowBox[{"KnoodleProve", "[", StyleBox["trace", "TI"], "]"}]],
      "InlineFormula"],
     "\[LineSeparator]checks the claims of a move trace, and says whether it \
proves its input an unlink."}], "Usage"],
   notes["A move trace is the record a simplifier writes of the moves it \
made on a knot or link diagram: the diagram it started from and, for each \
move, the move and the diagram it left. The format is Knoodle's \
docs/move-descriptor.md. Nothing in Knoodle writes a trace yet; the traces \
bundled with this paclet were recorded by the simplifier of the \
middlestrands project, which is built on Knoodle."],
   notes["trace is File[path], a path to a trace file, or the trace's text \
as a string."],
   notes["KnoodleProve runs Knoodle's knoodleprove, which checks every claim \
in the trace that does not depend on a drawing: that each move is well formed \
against its diagram, that it produces the next record's diagram, that the \
pieces it frees are the ones the trace names, and that a middle pass's \
feasibility witness holds. Pass, middle-pass, curl-removal (r1) and redraw \
moves are checked. A move of any other kind is reported as UNCHECKED, never \
skipped. A record marked #candidate is a move the simplifier evaluated but did \
not make: its claims are checked, but it is not part of the proof."],
   notes["The result is an Association. \"Verdict\" is \"VERIFIED\" when \
every claim checked out, \"MISMATCH\" when some claim is false, and \
\"UNCHECKED\" when none is false but some could not be checked. \"Unlink\" is \
True when the trace ends at the empty diagram and that, with every move sound \
and every component freed exactly once, proves its input an unlink: for a \
knot, the unknot. \"Claims\" lists the claims in order, one Association each, \
with keys \"Step\" (the record's number, or All for a claim about the whole \
trace), \"Claim\", \"Verdict\" and \"Detail\". A line that only reports, such \
as which components a move freed, has \"Verdict\" -> None."],
   notes["A false claim is an answer, not a failure: the result says \
\"MISMATCH\", and the claim's \"Detail\" says what is wrong. A trace that \
knoodleprove cannot read gives $Failed with a KnoodleProve::knoodletool \
message quoting its error."],
   notes["The claims that do depend on a drawing (that the pictures of a move \
show the right diagrams) belong to knoodledraw --trace --verify, which this \
paclet does not wrap."],
   notes["The following options can be given:"],
   Cell[BoxData[GridBox[{
      optRow[ToBoxes["CheckExterior"], "False",
       "also check each record's '#view' claim: that its outside face is \
the image of the previous record's across the move"]
      }]], "3ColumnTableMod"]
   }, Open]];

(* ---------- examples ---------- *)
ex1 = {
   text["Check a bundled trace: a pass move on a 3-crossing diagram of the \
unknot, then the removal of the curl it leaves:"],
   silent[HoldForm[dir = PacletObject["Knoodle"]["AssetLocation", "ExampleTraces"];]],
   group[HoldForm[r = KnoodleProve[File[FileNameJoin[{dir, "pass_lasso.trace"}]]];
     {r["Verdict"], r["Unlink"]}]],
   text["The claims, in order. The last is about the whole trace:"],
   group[HoldForm[Dataset[r["Claims"]][All, {"Step", "Claim", "Verdict"}]]],
   text["Each claim also has a \"Detail\":"],
   group[HoldForm[Last[r["Claims"]]]]};

ex2 = {
   delim,
   text["A trace is text. Each record gives a move and the diagram it acts \
on, in Knoodle's own serialization of a planar diagram:"],
   silent[HoldForm[lasso = Import[FileNameJoin[{dir, "pass_lasso.trace"}], "Text"];]],
   group[HoldForm[Column[StringSplit[lasso, "\n"][[4 ;; 22]]]]],
   text["The text itself can be checked:"],
   group[HoldForm[KnoodleProve[lasso]["Verdict"]]]};

ex3 = {
   delim,
   text["Change one crossing of the input, so the diagram alternates and is \
a trefoil. The trace no longer proves anything: the strand of its pass move \
now goes over at one crossing and under at another, so the move is not a \
pass move at all:"],
   silent[HoldForm[trefoil = StringReplace[lasso,
       "C_state = {-1,-1,1}" -> "C_state = {-1,-1,-1}", 1];]],
   group[HoldForm[rt = KnoodleProve[trefoil]; {rt["Verdict"], rt["Unlink"]}]],
   group[HoldForm[SelectFirst[rt["Claims"], #Verdict === "MISMATCH" &]]],
   text["With that link of the chain broken, the trace proves no unlink:"],
   group[HoldForm[Last[rt["Claims"]]]]};

ex4 = {
   delim,
   text["The Freedman\[Dash]He\[Dash]Wang hard unknot, with 32 crossings, \
taken to the empty diagram by 11 pass moves and 4 curl removals. The trace \
proves it an unknot:"],
   group[HoldForm[fhw = KnoodleProve[File[FileNameJoin[{dir, "fhw_unlink.trace"}]]];
     {fhw["Verdict"], fhw["Unlink"]}]],
   group[HoldForm[Last[fhw["Claims"]]]],
   group[HoldForm[Counts[Lookup[fhw["Claims"], "Claim"]]]]};

ex5 = {
   delim,
   text["A middle pass goes over some of what it crosses and under the rest. \
It is sound only by the feasibility witness the trace gives with it, so its \
witness is checked as well (V0, V4, and V2, V3 and V5):"],
   group[HoldForm[mp = KnoodleProve[File[FileNameJoin[{dir, "middlepass_unlink.trace"}]]];
     {mp["Verdict"], mp["Unlink"]}]],
   text["Record 4 is a candidate: a middle pass the simplifier evaluated, \
witness and all, without making it. Record 5 makes it. The claims about \
record 5:"],
   group[HoldForm[Grid[Lookup[Select[mp["Claims"], #Step === 5 &], {"Claim", "Verdict", "Detail"}],
      Alignment -> Left, ItemSize -> {{Automatic, Automatic, 28}}]]]};

ex6 = {
   delim,
   text["A redraw views the same curve on the integer lattice from another \
side. Here the Hopf link, its two components' colours kept. Every claim \
checks out; the trace does not end at the empty diagram, so it proves no \
unlink:"],
   group[HoldForm[rd = KnoodleProve[File[FileNameJoin[{dir, "redraw_link_example.trace"}]]];
     {rd["Verdict"], rd["Unlink"]}]],
   group[HoldForm[Grid[Lookup[rd["Claims"], {"Claim", "Detail"}], Alignment -> Left,
      ItemSize -> {{Automatic, 32}}]]]};

ex7 = {
   delim,
   text["Six records of a longer run whose '#view' lines, which say which \
face of each diagram is the outside one, are wrong. The moves check out. The \
one UNCHECKED claim is the last move's result, since no record follows it to \
compare with:"],
   silent[HoldForm[sticky = File[FileNameJoin[{dir, "exterior_sticky_example.trace"}]];]],
   group[HoldForm[Counts[Lookup[KnoodleProve[sticky]["Claims"], "Verdict"]]]],
   text["With \"CheckExterior\" -> True the views are checked too, and four \
of the six are refused:"],
   group[HoldForm[Grid[Lookup[Select[KnoodleProve[sticky, "CheckExterior" -> True]["Claims"],
       #Claim === "exterior" &], {"Step", "Verdict", "Detail"}], Alignment -> Left,
      ItemSize -> {{Automatic, Automatic, 32}}]]]};

ex8 = {
   delim,
   text["A trace knoodleprove cannot read gives $Failed, with a \
KnoodleProve::knoodletool message quoting its error:"],
   group[HoldForm[KnoodleProve["#trace v=1\n#step n=0 summand=0\nnot a diagram\n"]]]};

examplesSection = Cell[CellGroupData[Flatten[{
    Cell[BoxData[InterpretationBox[GridBox[{{StyleBox["Examples",
           "PrimaryExamplesSection"], ""}}], $Line = 0; Null]],
     "PrimaryExamplesSection"],
    silent[HoldForm[Needs["Knoodle`"]]],
    ex1, ex2, ex3, ex4, ex5, ex6, ex7, ex8}], Open]];

nb = Notebook[{categorization, usageSection, examplesSection},
   StyleDefinitions -> FrontEnd`FileName[{"Wolfram"},
     "FunctionPageStylesExt.nb", CharacterEncoding -> "UTF-8"]];

UsingFrontEnd[Module[{nbo = NotebookPut[nb]},
  NotebookSave[nbo, $out];
  NotebookClose[nbo]]];
Print["saved: ", $out];
