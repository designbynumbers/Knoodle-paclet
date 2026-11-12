# Example move traces

A *move trace* is the record a simplifier writes of what it did to a knot or
link diagram: the diagram it started from and, for each move, the move and the
diagram it left. The format is Knoodle's `docs/move-descriptor.md`.
`KnoodleProve` checks one (with Knoodle's `knoodleprove`). When a trace ends at
the empty diagram and every move checks out, it proves its input an unlink: for
a knot, the unknot. A record marked `#candidate` is a move the simplifier
evaluated but did not make: its claims are checked, but it is not part of the
proof.

Nothing in Knoodle writes a trace yet. These five were recorded by the
simplifier of the *middlestrands* project, which is built on Knoodle; the
`#comment` lines at the top of each file say how. They are copies of test
fixtures in Knoodle (`test/<name>.trace`; the same in v1.2.0 and v1.2.1), and
are bundled as example data for the `KnoodleProve` documentation.

| File | What it is | Moves | Checked |
|---|---|---|---|
| `pass_lasso.trace` | The smallest whole story: one pass move on a 3-crossing unknot diagram (the descending trefoil shadow), then one curl removed. | 1 pass, 1 r1 | an unlink |
| `fhw_unlink.trace` | The Freedman–He–Wang hard unknot (32 crossings) taken all the way to the empty diagram. | 11 pass, 4 r1 | an unlink |
| `middlepass_unlink.trace` | Middle passes: the strand goes over some of what it crosses and under the rest. Each is sound only by the feasibility witness (`#feas`) it carries, which is checked too. | 2 middlepass, 8 r1; each middle pass is first recorded as a candidate | an unlink |
| `redraw_link_example.trace` | A redraw: the Hopf link as a curve on the integer lattice, seen from another side, its two components' colours kept. | 1 redraw | every claim VERIFIED |
| `exterior_sticky_example.trace` | Six records of a longer run whose `#view` lines, which say which face is the outside one, are wrong. The moves check out; with `"CheckExterior" -> True`, four of the six views do not. | 3 pass, 2 middlepass, and 1 middlepass candidate | the views are refused |
