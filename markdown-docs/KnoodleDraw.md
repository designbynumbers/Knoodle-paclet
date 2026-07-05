# KnoodleDraw

Reference material for the Mathematica Documentation Center page(s) at
`Documentation/English/ReferencePages/Symbols/KnoodleDraw.nb`. Written from
the session that built this function; intended as a source of truth for a
future session filling out the full "Details and Options" / "Examples"
sections of the real reference page (currently skeletal: one option
mentioned, one example).

## What it does

`KnoodleDraw[input]` renders a knot or link diagram as a `Graphics` object,
using the Knoodle CLI tool `knoodledraw` under the hood (invoked via
`RunProcess`, not LibraryLink). Crossings are drawn in the usual over/under
style on a square grid, with rounded corners. All geometry, decoration, and
label placement follows the internal normative spec `DRAWING-SPEC.md` (repo
root); none of those placement/sizing rules are user-tunable options, and
they should *not* be restated on the user-facing reference page — `LabelStyle`
(text styling) is the one deliberate hook.

## Calling convention

```
KnoodleDraw[input]
KnoodleDraw[input, opts]
```

Returns a `Graphics` object — or, when the input yields several diagrams
(a multi-summand `PlanarDiagramComplex`, a composite/split input), a
`List` of `Graphics` rendered at one common scale (deliberately *not* a
`GraphicsGrid`/`Grid`, which would renormalize cell sizes and break that
common scale). Each `Graphics` is wrapped in `Legended[...]` if
`PlotLegends -> Automatic` is given. Returns `$Failed` (with a
`KnoodleDraw::badinput` message) if `input` isn't a recognized
representation.

## Input formats

All handled by the internal `toTSV` normalizer, which every one of the
three public functions shares:

- **KnotData specification**: `Knot[3, 1]`, `{3, 1}`, `"Trefoil"` — anything
  `KnotData` itself accepts. Internally resolved via
  `KnotData[spec, "SpaceCurve"]` (sampled at 160 points) and then treated as
  a 3D space curve (see below). Default-simplifies (see `"Simplify"` option).
- **A `Function`**: sampled as a space curve, `f[t]` for
  `t` in `0` to `2 Pi` at 160 points (`Most@Table[f[t], {t, 0., 2 Pi, 2 Pi/160}]`).
  Default-simplifies.
- **List of 3D points** (a single space curve): `{{x,y,z}, ...}`. Written to
  stdin as TSV. Default-simplifies (the raw projection is generally
  arbitrary/degenerate-prone).
- **List of lists of 3D points** (multi-component link, one list per
  component): `{{{x,y,z},...}, {{x,y,z},...}, ...}`. Knoodle only reads this
  format (blank-line-separated vertex blocks) from a *file* with a
  `.kndlxyz` extension, never stdin — so this is written to a scratch file
  and passed as `File[...]`; `runGeometry`/`runSimplifyPdc`/`runIdentify`
  all know how to draw/simplify/identify directly from a `File[...]`.
  Default-simplifies.
- **Native Knoodle PD code, one summand**: a list of crossing rows, each row
  4, 5, 6, or 7 integers. Column counts: 4 = unsigned PD, 5 = signed PD (5th
  = handedness ±1), 6 = unsigned + 2 color columns, 7 = signed + 2 color
  columns. The last two columns (when present) are the incoming
  under-/over-arc's explicit color — this is how a link's components are
  tagged on the wire, and how `knoodlesimplify`/`knoodleidentify` preserve
  component identity through simplification/lookup when given colored
  input. Does *not* default-simplify (drawn as-is unless `"Simplify"->True`
  is given explicitly).
- **Multiple summands**: a list where each entry is itself a summand's row
  list (as above), or `{}` for a bare unknot summand. Represents a
  connect-sum factorization or a split link — Knoodle's own wire format
  doesn't distinguish the two (see `KnoodleSimplify.md`'s `"Unite"` section
  for how that distinction actually gets made). `{{}}` (a list containing
  one empty summand) is the standalone unknot — this is the one-summand
  degenerate case of this same pattern, so no special-casing was needed to
  support it. Does not default-simplify.
- **KnotTheory `PD[X[...]]`**: converted to Knoodle's native 4-column
  unsigned form, 0-indexed (`(List @@ # & /@ List @@ p) - 1`). Does not
  default-simplify.
- **KnotTheory `DTCode`/`GaussCode`**: routed through `KnotTheory`PD[...]`
  (calls `Needs["KnotTheory`"]`) and then the PD path above.
- **`PlanarDiagramComplex`** (from `KnoodleSimplify`): its `"serialized"`
  string (`PlanarDiagramComplex`'s own native `WriteToFile`/`FromInString`
  format) is passed straight through as TSV content. Does not
  default-simplify (it's already simplified) — but *can* be re-simplified
  if `"Simplify" -> True` is given explicitly, since `knoodlesimplify`'s
  shared reader (`ReadKnot`) also understands this format transparently.

## Options

| Option | Default | Meaning |
|---|---|---|
| `"Simplify"` | `Automatic` | Whether to run `knoodlesimplify` before drawing. `Automatic` resolves per input type (see above): geometry/KnotData inputs default to `True` (the raw projection is arbitrary), explicit PD-code inputs default to `False` (draw *this* diagram as given). |
| `"LayoutOptions"` | `{}` | Forwards arbitrary layout-tuning flags to `knoodledraw`. `"name" -> n` or `"name" -> "s"` become `--name=...`; `"name" -> True`/`False` become `--name`/`--no-name`. E.g. `"LayoutOptions" -> {"randomize-bends" -> 3}` or `{"compaction" -> "topo-order", "turn-regularize" -> False}`. See `knoodledraw --help` for the full flag list. |
| `"Checkerboard"` | `False` | Shades the diagram's two-colorable faces (theme-aware wash colors: `Accent1` for `Color->+1` faces, a faint foreground wash for `Color->-1`). |
| `"Labels"` | `{}` | A subset of `{"Crossings", "Arcs", "Faces"}` (a single string is also accepted, not just a list). Annotates the diagram with 0-based element ids. Placement follows DRAWING-SPEC.md §5–7 and is not user-tunable: crossing and face labels sit in reserved 2×1-subgrid-unit regions of a host grid cell (crossing labels left-justified at the region's crossing-side edge, face labels centered); arc labels are *inline* — the strand is cut for one subgrid unit at the midpoint of every drawing edge the arc traverses and the label sits in the gap, upright on horizontal edges, rotated to read along the arc's orientation on vertical edges. An arc spanning k edges shows its label k times; this density is intentional (labels are a debugging view of the PD code, not a presentation default). |
| `LabelStyle` | `{}` | The one user-facing styling hook (DRAWING-SPEC.md §8.4–8.5): styles label *text* only — font family, weight, slant, color, etc. — never placement. The default pins `FontFamily -> "Source Sans Pro"` (bundled in every Wolfram installation's `SystemFiles/Fonts`, so guaranteed present, and measurable by the kernel at drawing time). User directives merge *after* the default, so `LabelStyle -> Bold` bolds the pinned font while `LabelStyle -> {FontFamily -> ...}` swaps it. Text is sized by a global largest-fit rule — the largest size at which every label fits its reserved box, measured (rendered extent, not character count) under the fully resolved style across *all* drawings of the call — so all labels of an output share one size. A numeric `FontSize` inside `LabelStyle` is honored only when no explicit `ImageSize` is given, in which case it *sets the drawing scale* (every drawing's `ImageSize` is derived from it); with an explicit `ImageSize`, `ImageSize` wins and the largest-fit rule applies. **Reference-page caveat worth one sentence**: if a user names a `FontFamily` that is not installed, the front end silently falls back to another font and the measured fit may mismatch the rendering. |
| `"ExteriorFace"` | `Automatic` | Which face OrthoDraw lays out as the unbounded exterior region — a non-negative integer, 0-based. `Automatic` is OrthoDraw's own default (the face with the largest number of edges). Applies uniformly to every summand of a multi-summand diagram. |
| `PlotLegends` | `None` | `Automatic` adds a `LineLegend` matching each link component's color to its (global, 0-based) component number — numbered consistently with how colors are assigned across summands (see below), not per-summand. |
| `"RandomizeProjection"` | `True` | Applies a random rotation (via `Reapr::RandomRotation`, *not* a shear — this was reworked mid-session, see Notes) before projecting/using 3D geometry. The default projection can degenerate on vertical/coplanar segments (stdin single-component case) or exact coincidental intersections between components (multi-component `.kndlxyz` case) — this defaults on to avoid both. Set to `False` for reproducibility (e.g. testing) or when you know your geometry is already generic. Meaningful for *any* 3D-geometry input (both the stdin single-curve path and the `.kndlxyz` multi-component file path — both were fixed to honor this flag over the course of the session; earlier in development the file path silently ignored it). No-op for PD-code/`PlanarDiagramComplex` input (nothing to project). |
| `ImageSize` | `340` | Applies to the **widest** drawing of the output (in coordinate units, padding included); on multi-summand output every other drawing gets a proportionally smaller `ImageSize` so all drawings share one points-per-subgrid-unit scale (DRAWING-SPEC.md §9). Overrides any `FontSize` in `LabelStyle` when both are given explicitly. |
| `"Orientation"` | `False` | `True` puts a solid arrowhead in **every** traversed arrowhead subgrid square — two per drawing edge, superimposed on the continuous strand, centered in its square, pointing along the arc's orientation, at most 1×1 subgrid unit so it survives any rescaling (DRAWING-SPEC.md §4; the head is a coordinate-space `Polygon`, not an `Arrowheads[]` spec, precisely so its size tracks the grid rather than the image). The density — a straight run of n cells shows 2n heads — is intentional; like arc labels, this is a debugging view. The former `True`/`All` distinction (one head per component vs. per arc) collapsed to a boolean; `All` is still accepted as a synonym for `True`. Arc polylines are emitted by `knoodledraw` in orientation order (verified: heads circulate consistently). Unknot-marker summands (`<\|"Unknot"->True\|>`) carry no arc data and draw without arrowheads. |
| `"Thickness"` | `Automatic` | Strand stroke width. `Automatic` draws strands u/3 (one third of a subgrid unit) wide at the common scale, additionally capped at `AbsoluteThickness[7]` — the u/3 proportional bound is mandatory (DRAWING-SPEC.md §3.1: strokes must never reach a cell's interior or swallow the crossing gaps at any scale), the 7 pt cap keeps small diagrams at their familiar weight. An explicit number is `AbsoluteThickness[n]` in printer's points, clamped to the same u/3 bound. Any other value is passed through as a raw `Graphics` directive, unclamped (escape hatch, at the user's own risk). |

## Rendering details worth knowing

- **Grid**: one square = `$gridSize` (4) coordinate units. Square (not
  rectangular) unlike the ASCII-art tools' character-cell grid.
- **Component coloring** (resolved 2026-07-04; the earlier "two numbering
  schemes" tension is gone): strands are colored by the **raw wire color**
  each arc carries — `knoodledraw --format=wl` exports it as `"Color"` on
  every arc and on colored `<|"Unknot"->True|>` markers since Knoodle
  `3fe15b0` (our handoff `knoodledraw-wl-arc-colors`). Wire colors are the
  physical link components and are stable across every summand of one call,
  so all summands share ONE `ColorData[97]` palette keyed by the distinct
  color classes: the connect-sum factors of a knot all draw in a single
  color, and a split link's components keep their colors across factors
  (same color = same component — the drawn semantics of `KnoodleSimplify`'s
  split shape). Colorless unknot markers (bare `s` summands) get fresh
  palette slots after the wire classes. `PlotLegends -> Automatic` labels
  swatches with the wire color values themselves. Fallback: when `"Color"`
  is absent (binaries older than `3fe15b0`), each summand claims its own
  run of palette colors keyed by the per-summand `"Component"` index plus a
  running offset — the old behavior, in which a composite knot's factors
  wrongly got different colors (the bug that prompted the fix). Note
  `"Color"->0` also covers *uncolored* input (the tool defaults it), which
  is exactly right: a knot is one component.
- **The subgrid**: the internal unit of account is the subgrid unit
  u = 1 coordinate unit = 1/4 of the grid pitch (DRAWING-SPEC.md §1–2). Every
  decoration lives in its own reserved 1×1 subgrid square (arrowheads, arc
  labels, crossing gaps) or 2×1 region (crossing/face labels), which is why
  nothing ever collides at any scale. Bends are quarter-circles of radius
  exactly u/2 (forced by tangency + containment in the corner square — the
  reason the former `"CornerRadius"` option was removed); caps are flat
  (`CapForm["Butt"]`), which makes crossing gaps and inline label gaps read
  as deliberate cuts.
- **Under-strand gaps**: the spec wants the under-strand cut exactly u/2
  either side of the crossing (total gap 1u), but `knoodledraw`'s
  `--gap-size` is integer-only (inset 1 unit per side as emitted); the WL
  side identifies under-strand endpoints (arc endpoints at Manhattan distance
  exactly 1 from a crossing) and extends them halfway back in.
- **Multi-summand output**: one `Graphics` per summand, returned as a
  `List`, all at one common points-per-subgrid-unit scale (widest drawing
  gets the requested `ImageSize`, the others proportionally less). The old
  side-by-side single-`Graphics` layout is gone.
- **Face label placement**: a discretized "pole of inaccessibility"
  algorithm, not a plain polygon centroid (which can land outside a
  non-convex face entirely — face polygons from real diagrams are often
  extremely non-convex). Candidates are restricted to grid-square centers
  strictly inside the face polygon (`RegionMember`); the winner maximizes
  distance to the face boundary (`RegionDistance`), ties broken
  lexicographically (rightmost then topmost), and the label snaps to the
  host cell's reserved (2,2)–(3,2) subgrid region — u/2 right of the cell
  center. The exterior face (unbounded) is handled separately: candidates
  are the ring of grid cells framing the diagram's bounding rectangle that
  belong to no interior face; if that set is empty (the diagram fills its
  box edge-to-edge), the rectangle grows one column to the right, all of
  whose cells are exterior — one extension always suffices, and the plot
  range stretches to keep such a label unclipped.
- Uses `RegionDistance`/`RegionMember`/`RegionUnion`/`RegionBoundary`
  throughout rather than hand-rolled point/polygon geometry — an explicit
  style preference from the person who built this ("write short, idiomatic
  WL code... it is usually a matter of correctly leveraging existing
  functions and their options, not re-implementing things ourselves").
- **Graphics directive scoping gotcha** (real bug hit and fixed): a
  directive *list* like `{Opacity[...], color}` must be spliced via
  `Sequence @@ {...}` into the surrounding primitive list — nesting it as
  `{{Opacity[...], color}, Polygon[...]}` silently drops the styling
  (renders solid black/default), since Graphics directive scoping doesn't
  propagate out of a nested sub-list.
- **Label font is pinned, not inherited** (reversed 2026-07-04, per
  DRAWING-SPEC.md §8.4): the earlier design inherited the notebook
  stylesheet's font, but the largest-fit sizing invariant cannot survive a
  font the kernel can't observe at drawing time, so labels now default to
  `FontFamily -> "Source Sans Pro"` with user `LabelStyle` directives merged
  on top. Label extents are measured by `Rasterize[..., "BoundingBox"]`
  under the fully resolved style (once per distinct label text, linear in
  `FontSize`), with a headless fallback estimate if no front end is
  reachable, and sized to a 0.96 safety fraction of each reserved box.
  Color/opacity still use the theme system (`ThemeColor`) rather than fixed
  grays, so labels and checkerboard shading track light/dark mode and custom
  notebook themes automatically.

## Comparison with KnotTheory's DrawPD (documentation examples)

The reference page's example section compares KnoodleDraw with the `DrawPD`
function of the KnotTheory` package (its manual page:
https://katlas.org/wiki/Drawing_Planar_Diagrams), positioning KnoodleDraw
as a drop-in replacement — it accepts KnotTheory's `PD[X[...], ...]`
objects directly. The narrative: two comparisons where both programs
succeed (the Millett unknot from DrawPD's own manual page; 13a_1 from
KnotInfo), then **"KnoodleDraw is more robust than DrawPD"** with three
examples — it draws diagrams with R1 loops, diagrams which are not prime,
and complicated diagrams.

- **Assets**: every DrawPD picture on the page is a pre-rendered PNG
  bundled as the `DrawPDGallery` asset (`Resources/ExampleData/DrawPDGallery`,
  generated by `ci/docs/gen-drawpd-gallery.wls` — the ONLY script that
  evaluates DrawPD, with a time-constrained self-check because DrawPD's
  convergence is environment-sensitive; see `ci/docs/README.md`). The page
  generator itself never runs DrawPD — the drop-in example evaluates
  `KnoodleDraw` on a KnotTheory `PD[X[...]]` object and only displays the
  equivalent DrawPD call — so the examples display without KnotTheory
  installed and the page regenerates under plain wolframscript. Four
  entries: the "Millett unknot" (`Gap -> 0.03` as the manual page
  recommends), the granny knot, a Gaussian random 50-gon projection, and
  13a_1 (PD code from KnotInfo, https://knotinfo.org).
- **R1 loops (empirical, 2026-07-04)**: DrawPD does not terminate on any
  diagram containing a monogon — its circle-packing radii go complex and
  the minimization runs forever; tested across a dozen random polygon
  projections, 7–56 crossings, while monogon-free diagrams draw in
  ~0.1–0.2 s. Raw closed-polygon projections always contain a few kinks, so
  the example shows KnoodleDraw drawing the fully raw 21-crossing 50-gon
  projection that DrawPD cannot.
- **Non-prime**: on the granny knot (trefoil # trefoil, one 6-crossing PD),
  DrawPD terminates but crushes the two summands into tiny corner tangles;
  KnoodleDraw gives both summands equal weight.
- **Complicated**: the 50-gon projection with only its three monogons
  removed (15 crossings, otherwise unsimplified; the reduction lives in
  `gen-drawpd-gallery.wls`) — DrawPD draws it with wildly non-uniform
  crossing sizes, KnoodleDraw's grid keeps every crossing the same size.
- *Aside*: at the time this was built, `knoodlesimplify` levels 1–3 were
  silent no-ops, so the monogon removal was first done WL-side. Upstream
  rewired the levels the same day (Knoodle `34ba537`; see
  `~/Knoodle/handoff/knoodlesimplify-simplify-levels-rewired/`), and
  `gen-drawpd-gallery.wls` now derives the 15-crossing PD with
  `"SimplifyLevel" -> 1` (Reidemeister I only) — verified to reproduce the
  committed literal exactly.
- **Layout variety**: a further example draws one PD code (13a_1) three
  ways — default, `"LayoutOptions" -> {"compaction" -> "topo-order"}`, and
  `{"randomize-bends" -> 4}` — to show that the code determines the diagram
  but not the drawing. The randomize-bends panel differs between doc
  regenerations (the randomness lives in the C++ tool, not WL's
  `SeedRandom`).

## Example

```
Needs["Knoodle`"]
KnoodleDraw[Knot[3, 1]]
```

Draws the trefoil.

```
KnoodleDraw[Knot[7, 4], "Checkerboard" -> True, "Labels" -> {"Crossings", "Arcs", "Faces"}]
```

Draws 7_4 with checkerboard shading and all three label types.

```
KnoodleDraw[{{}}]
```

Draws the standalone unknot (a rounded 1×1-cell box — the same orthogonal
drawing language as every other summand, per DRAWING-SPEC.md §9.4).

```
KnoodleDraw[Knoodle`KnoodleSimplify[Knot[6, 2], "Unite" -> True], PlotLegends -> Automatic]
```

Full pipeline: simplify, connect-sum back to one diagram per split
component, draw with a component-color legend.
