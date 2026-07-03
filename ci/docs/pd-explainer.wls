(* Shared PD-code explainer, spliced into the Examples of all three function
   pages (KnoodleDraw, KnoodleSimplify, KnoodleIdentify) so the native input
   format is explained wherever a user lands. Get this AFTER the generator's
   cell-builder helpers (text/silent/group/delim) are defined.

   The 5_2 code below is Knoodle's own (KnoodleSimplify[Knot[5,2]], color
   columns dropped), and the row-1 walkthrough in the text was verified
   against the labeled drawing: at crossing 1 the under-strand enters as arc
   0 and leaves as arc 1, and {0,5,1,6} reads counterclockwise from there.
   Conventions per src/PlanarDiagram/PDCode.hpp: entry 0 = incoming
   under-arc, then counterclockwise (KnotTheory-compatible); sign +1
   right-handed / -1 left-handed; color columns = incoming under-/over-arc
   colors. *)

pdExplainerCells := {
   delim,
   text["Knoodle's native PD code describes an explicit diagram, one \
crossing per row. A row {a, b, c, d} lists the four arcs meeting at that \
crossing in counterclockwise order, starting from the incoming under-strand \
arc a. Arcs are numbered 0, 1, 2, \[Ellipsis] consecutively along the knot, \
following its orientation (the 0-based analogue of the KnotTheory` \
convention). An optional fifth entry is the crossing's handedness (+1 \
right-handed, -1 left-handed), and two further optional entries give the \
component colors of the incoming under-arc and over-arc, which is how the \
components of a link keep their identity. A PD code for the knot 5_2:"],
   silent[HoldForm[pd52 = {{6, 9, 7, 0, -1}, {0, 5, 1, 6, -1}, {4, 1, 5, 2, -1},
       {2, 7, 3, 8, -1}, {8, 3, 9, 4, -1}};]],
   text["Drawing it with orientation arrows and crossing and arc labels \
shows the correspondence. Row 1 is crossing 1: the strand enters along arc \
0, passes under, and continues as arc 1 -- and {0, 5, 1, 6} reads \
counterclockwise around that crossing, starting from arc 0:"],
   group[HoldForm[KnoodleDraw[pd52, "Orientation" -> True,
      "Labels" -> {"Crossings", "Arcs"}, ImageSize -> 280]]]
   };
