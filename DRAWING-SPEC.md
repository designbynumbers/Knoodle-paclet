# KnoodleDraw drawing and label-placement specification

Status: draft for review. **Internal design document** — this is the
normative geometry and label specification we build against; it is *not*
user-facing. With one exception — `LabelStyle` (§8.4–8.5), which styles
label *text* — none of the geometry, placement, or sizing rules below are
exposed as tunable options or described in the paclet reference pages
(users who need bespoke label placement can draw their own, e.g. with
`\overpic`). It supersedes the ad-hoc label placement currently implemented
in `Kernel/Knoodle.wl` (crossing labels anchored at the crossing point, arc
labels nudged off the longest segment, `"CornerRadius"` as a free
parameter).

Throughout, "MUST"-style rules are stated as plain declarative sentences;
every sentence in sections 2–9 is normative unless marked *Note*.

## 1. The two grids

### 1.1 Drawing grid

`knoodledraw` (OrthoDraw) lays the diagram out on an integer lattice, the
**drawing grid**. In the TSV geometry it emits, one drawing-grid unit is
`$gridSize = 4` coordinate units. Strands are axis-aligned polylines whose
segments run along drawing-grid lattice lines; crossings and bends occur at
lattice points. A **drawing cell** (or "grid square") is a unit cell of this
lattice; faces of the diagram are unions of drawing cells.

### 1.2 Subgrid

The **subgrid** is dual to the drawing grid. A **subgrid unit** *u* is 1/4 of
the drawing-grid pitch — i.e. exactly **1 coordinate unit** of knoodledraw's
output. Subgrid squares are closed *u* × *u* squares *centered* on the
drawing grid's lattice structure:

- each drawing-grid **lattice point** *P* is the center of a subgrid square
  (the square *P* + [−u/2, u/2]²);
- each drawing-grid **lattice line** runs down the centerline of a strip of
  subgrid squares.

Each drawing cell (*I*, *J*) is covered by a 5 × 5 block of subgrid squares,
indexed by lower-left coordinates (*i*, *j*), *i*, *j* ∈ {0, …, 4}. Square
(*i*, *j*) of cell (*I*, *J*) occupies

    [4I + i − 1/2, 4I + i + 1/2] × [4J + j − 1/2, 4J + j + 1/2]

in output coordinates. Because the footprint is 5 units on a 4-unit pitch,
**adjacent cells overlap by one subgrid strip**: square (4, *j*) of cell
(*I*, *J*) *is* square (0, *j*) of cell (*I*+1, *J*), edge (non-corner)
perimeter squares belong to exactly 2 cells, and corner squares to exactly 4.

The 16 **perimeter** squares of a cell are those with *i* ∈ {0, 4} or
*j* ∈ {0, 4}; the **interior** is the exclusive 3 × 3 block
(*i*, *j*) ∈ {1, 2, 3}².

## 2. Reservation table

Within each cell, subgrid squares are reserved as follows.

| Squares | Reserved for |
|---|---|
| (0,0), (4,0), (0,4), (4,4) — corners | curve events: pass-through, bend, crossing (with its gap) |
| (1,0), (3,0), (0,1), (0,3), (1,4), (3,4), (4,1), (4,3) | orientation arrowheads (strand passes through) |
| (0,2), (2,0), (4,2), (2,4) | arc labels (strand interrupted) |
| (1,1)–(2,1) (a 2 × 1 region) | crossing label |
| (2,2)–(3,2) (a 2 × 1 region) | face label |
| (1,2), (1,3), (2,3), (3,1), (3,3) | unreserved margin; always empty |

*Consistency under sharing (lemma).* A shared square must receive the same
reservation from every cell containing it. This holds: corners map to
corners under all four identifications, and the identifications
(1,0)↔(1,4), (3,0)↔(3,4), (0,1)↔(4,1), (0,3)↔(4,3), (2,0)↔(2,4),
(0,2)↔(4,2) each pair squares of the same class. The interior regions
(crossing label, face label, margin) are exclusive to their cell.

Each non-corner perimeter square borders exactly one drawing edge. A square
is **traversed** when a strand runs along that edge (for corner squares:
when any strand passes through, bends at, or crosses at its lattice point).

## 3. Curve geometry

1. **Strands.** Each straight strand segment is a stroke of width
   *w* ≤ *u*/3, centered on its lattice line. This bound holds regardless of
   drawing scale; any user-supplied thickness is clamped to it. (Strokes
   therefore extend at most *u*/6 to either side of the lattice line and
   never reach a cell's interior 3 × 3 block, whose boundary is *u*/2 away.)
2. **Caps.** All cut ends are flat ("butt") caps: the stroke terminates
   exactly on the cut line, square, not rounded.
3. **Bends.** A bend at a lattice point is a quarter-circle of radius
   exactly *u*/2 joining the midpoint of a horizontal edge of the corner
   square to the midpoint of a vertical edge, tangent to both strand
   centerlines. The bend, including its stroke (outer radius
   ≤ *u*/2 + *w*/2 ≤ 2*u*/3), lies entirely within the corner square. The
   radius is not configurable: tangency plus containment force *u*/2.
4. **Crossings.** At a crossing, both strands pass straight through the
   lattice point. The over-strand is drawn continuously. The under-strand is
   cut at the two boundaries of the corner square, leaving a gap of length
   exactly *u* centered on the crossing, so that within the corner square
   the drawn curve is entirely vertical (horizontal strand cut) or entirely
   horizontal (vertical strand cut). Clearance between the over-strand's
   stroke edge and each under-strand cap is *u*/2 − *w*/2 ≥ *u*/3 at any
   scale.
5. **Pass-throughs.** A strand passing straight through a lattice point
   without event is drawn continuously through the corner square.
6. **Plot range.** The rendered plot range includes the full subgrid
   footprint — the drawing-grid bounding box expanded by *u*/2 on every
   side — so decorations in boundary perimeter squares are never clipped.

## 4. Orientation arrowheads

Enabled by `"Orientation" -> True` (see §11: the current `True`/`All`
distinction collapses).

1. Every arrowhead square traversed by an arc contains exactly one
   arrowhead. (Every drawing edge carrying a strand therefore shows two
   arrowheads; a straight run of *n* cells shows 2*n*. This density is
   intentional.)
2. An arrowhead is a solid head **superimposed on the continuous strand**:
   the strand is not cut, and the head is drawn on top of it, centered in
   the square, symmetric about the strand centerline, pointing in the arc's
   orientation.
3. The arrowhead lies entirely within its subgrid square, regardless of
   drawing rescaling. (Maximum extent 1 × 1 subgrid unit; exact proportions
   within that box are an implementation choice.)

*Note.* Cuts occur only in corner squares (crossing gaps) and arc-label
squares, so a traversed arrowhead square always contains a full *u* of
strand for the head to sit on — including the 1-unit under-strand stubs
between two adjacent crossings.

## 5. Arc labels

Enabled when `"Arcs"` is in the `"Labels"` option. Arc labels are
**inline**:

1. Every arc-label square traversed by an arc contains that arc's label, and
   contains no drawn curve: the strand is cut at the square's two
   boundaries (flat caps) and the label text is centered at the square's
   center, inside the gap. When arc labels are disabled, no such cuts are
   made.
2. One label per traversed edge: an arc spanning *k* drawing edges shows its
   label *k* times ("multiply-labeled"). This density is intentional — arc
   labels are a debugging view of the PD code, not a presentation default.
3. **Reading direction.** On horizontal edges the text is upright and reads
   left-to-right, regardless of the arc's direction. On vertical edges the
   text is rotated ±90° so that it reads in the direction of the arc's
   orientation (upward edge: bottom-to-top; downward edge: top-to-bottom).
   A single arc may therefore show differently-oriented copies of its label
   on different edges.
4. **Fit.** The label's rendered extent (after any rotation) fits within the
   1 × 1 subgrid square, in both width and height.

## 6. Crossing labels

Enabled when `"Crossings"` is in the `"Labels"` option.

1. Each crossing's label appears once, in the (1,1)–(2,1) region of its
   **host cell**: the unique cell in which the crossing occupies corner
   square (0,0). Equivalently, this is the reserved region closest to the
   crossing (distance ≈ 0.71*u*, versus ≥ 1.58*u* for the three cells where
   the crossing sits at (4,0), (0,4), or (4,4)).
2. Since every cell has exactly one (0,0) corner, no cell hosts more than
   one crossing label. A cell may host both a crossing label and a face
   label; the reserved regions are disjoint.
3. The text is horizontal and **left-justified** in the 2 × 1 region — the
   left edge of its rendered extent on the region's left edge, vertically
   centered — and its rendered extent fits the region in both dimensions.
   *Note.* The region's left edge is the edge nearest the crossing.
   Centering was the earlier rule, but it lets a short label drift toward
   the middle of the host cell — a 1-digit label in the 2-unit-wide region
   floats an extra half unit from the crossing it names — so justification
   toward the crossing wins.

## 7. Face labels

Enabled when `"Faces"` is in the `"Labels"` option.

Each face's label appears exactly once, horizontal and centered in the
(2,2)–(3,2) region of a host cell chosen as follows. The interior 3 × 3
block is curve-free by construction (§3.1), so any cell qualifies
geometrically.

1. **Cells of a face.** A drawing cell belongs to a face when the cell's
   center lies inside the face's boundary polygon. Every interior face of a
   lattice-line diagram contains at least one cell.
2. **Interior faces.** Among the face's cells, the host maximizes the triple
   (Euclidean distance from the cell center to the face's boundary
   polyline, cell *x*, cell *y*) in lexicographic order — a discretized pole
   of inaccessibility with a deterministic rightmost-then-topmost
   tie-break.
3. **Exterior face.** Candidates are the cells on the boundary ring of the
   diagram's bounding rectangle *R* (*w* × *h* drawing cells) that belong to
   no interior face. If that set is empty (the diagram fills *R*
   edge-to-edge), *R* is extended one column to the right, whose cells are
   all exterior; one extension always suffices. The host maximizes
   (min(distance to the exterior face's boundary, distance to ∂*R*),
   *x*, *y*) lexicographically — the second term keeps the label from
   crowding the image edge.

## 8. Label text: font, size, and measurement

1. All three label classes (crossing, arc, face) use the same font and the
   same size.
2. The size is the **largest** value such that, simultaneously, every arc
   label's rendered extent fits a 1 × 1 subgrid box (both dimensions, after
   rotation), and every crossing and face label's rendered extent fits a
   2 × 1 box. "Rendered extent" — not character count — is the measured
   quantity: `"11"` may be narrower than `"9"` in a proportional font.
3. **Scope is global.** The constraint set ranges over every label of every
   drawing produced by a single `KnoodleDraw` call — all summands and, for a
   `PlanarDiagramComplex`, all diagrams — so the text size is identical
   across the whole output, matching the shared geometric scale (§9).
4. **`LabelStyle` (the one user-facing hook).** A `LabelStyle` option
   styles label *text only*: font family, weight, slant, color, and the
   like. It cannot override placement, and the placement rules are not
   documented in the reference pages. Unlike system plotting functions, the
   default **pins a concrete font**: the option default resolves to
   `FontFamily -> "Source Sans Pro"` (bundled in every Wolfram
   installation's `SystemFiles/Fonts`, so guaranteed present), because the
   fit invariant (§8.2) cannot survive a font the kernel can't observe at
   drawing time. User directives **merge with** the default rather than
   replace it — resolution is `Directive[FontFamily -> "Source Sans Pro",
   userStyle]` with the user's directives last, so `LabelStyle -> Bold`
   bolds the pinned font while `LabelStyle -> {FontFamily -> ...}` swaps
   it. Extent measurement (§8.2) is always performed under the fully
   resolved style, so styling choices (a wider family, bold weight)
   automatically participate in the fit.
5. **Size precedence.** A numeric `FontSize` inside `LabelStyle` interacts
   with `ImageSize` as follows:
   - *Neither given*: default `ImageSize`; font size by the largest-fit
     rule (§8.2).
   - *`ImageSize` only*: largest-fit rule at that size.
   - *`FontSize` only*: the requested size is honored and **sets the global
     scale** — the points-per-subgrid-unit scale is the smallest value at
     which every label at that font size fits its box (§8.2 run in
     reverse), and every drawing's `ImageSize` is derived from the
     resulting common scale (§9).
   - *Both*: `ImageSize` wins; the requested `FontSize` is ignored and the
     largest-fit rule applies.
   If no labels are enabled, `FontSize` constrains nothing and is ignored.
6. *Note (measurement caveat, mostly eliminated).* With the family pinned
   by default, the resolved style is fully determined and fit is exact both
   out of the box and under user overrides (their font is measured too).
   The one residual failure mode: the user names a `FontFamily` that is not
   installed, the front end silently falls back, and metrics mismatch —
   worth one sentence in the `LabelStyle` reference-page notes. Against
   platform rendering differences (hinting, rasterization quantization),
   size to a fixed safety fraction of each box — 95–97% rather than 100%.
7. The rendered font size in printer's points is the subgrid-unit size
   times the points-per-coordinate-unit scale of the common scale (§9), so
   labels scale with the drawing.

## 9. Scale and multi-drawing output

1. **Common scale.** All drawings produced by one `KnoodleDraw` call render
   at the same points-per-subgrid-unit scale, so grid squares — and hence
   strand widths, gaps, arrowheads, and label text — are the same physical
   size across the output.
2. **`ImageSize`.** A user-supplied `ImageSize` applies to the **largest**
   (widest, in coordinate units including padding) drawing of the output;
   every other drawing receives a proportionally smaller `ImageSize` at the
   common scale. When a `FontSize` sets the scale instead (§8.5), every
   drawing's `ImageSize` is derived from that scale.
3. **Return shape.** A `PlanarDiagramComplex` yielding several diagrams
   returns them as a `List` of `Graphics`, not a `GraphicsGrid`/`Grid`
   (which would renormalize cell sizes and break the common scale).
4. **0-crossing unknot summands** draw as the boundary of one drawing cell
   in the standard strand style, its four bends rounded per §3.3 (quarter-
   circles of radius *u*/2) — a rounded 1 × 1-cell box, so an unknot reads
   in the same orthogonal drawing language as every other summand rather
   than as a foreign circle. They participate in the common scale but carry
   no arcs, crossings, or faces, hence no labels and no arrowheads.

## 10. Assumptions (guaranteed by OrthoDraw)

1. Each lattice point hosts at most one event — pass-through, bend, or
   crossing. In particular OrthoDraw never emits "knock-knees" (two
   opposite bends sharing one lattice point); the corner-square case
   analysis in §3 is exhaustive.
2. Every drawing edge has length exactly one drawing cell or an integer
   multiple; there are no fractional edges, so every traversed edge carries
   its full complement of reserved squares (½ corner + arrowhead + label +
   arrowhead + ½ corner per cell of run).
3. Arc polylines are emitted in orientation order, consistently circulating
   around each component (this is what §4's arrowhead direction and §5's
   vertical reading direction consume).

## 11. Changes from the current implementation

Consequences of this spec that alter existing `Kernel/Knoodle.wl` behavior,
recorded so none lands by accident:

- **`"CornerRadius"` is removed**: the bend radius is pinned at *u*/2 = 1/8
  of the grid pitch. The current default (1/3 of a grid square = 4*u*/3)
  and maximum (2*u*) both violate §3.3.
- **Strand width** default drops from 0.5*u* (with a 7 pt absolute cap) to
  at most *u*/3; the absolute cap may be kept as an additional minimum but
  the *u*/3 proportional bound is mandatory (§3.1).
- **Caps** change from `CapForm["Round"]` to flat (§3.2); the square caps
  are what make the crossing gaps and label gaps read as deliberate.
- **Arrowheads** shrink from 1.75*u* long to at most 1*u* (§4.3), and their
  multiplicity changes from one per component (`True`) / one per arc
  (`All`) to every traversed arrowhead square; the `True`/`All` distinction
  collapses to a boolean.
- **Crossing labels** move from a corner-anchored `Text` at the crossing
  point to the (1,1)–(2,1) region of the host cell, left-justified at the
  region's crossing-side edge (§6).
- **Arc labels** move from a single label nudged off the longest segment to
  inline-in-the-gap labels on every traversed edge (§5).
- **Label sizing** changes from fixed 11 pt to the global largest-fit size
  (§8). `LabelStyle` is added as a new public option — text styling only,
  with the `FontSize`/`ImageSize` precedence of §8.5. The current
  inherit-from-stylesheet behavior (`labelStyle[]`'s deliberate lack of a
  `FontFamily`) is **reversed**: labels now pin `"Source Sans Pro"` by
  default, with user directives merged on top (§8.4).
- **Face labels** keep the pole-of-inaccessibility rule but snap to the
  (2,2)–(3,2) region of the chosen cell rather than the bare cell center
  (§7).
- **0-crossing unknot summands** change from a circle to the rounded
  1 × 1-cell box of §9.4, matching the orthogonal drawing language of the
  other summands.

## 12. Known accepted extremes

- An under-strand spanning a single edge between two crossings, with labels
  and orientation both on, renders as two 1-unit stubs, each carrying an
  arrowhead, flanking the inline label. Defined, dense, and accepted: these
  modes are debugging views.
- Label-and-arrowhead density grows linearly with edge count; a long
  straight run repeats the same arc label once per cell. Accepted for the
  same reason.
- In `FontSize`-only mode (§8.5) the font size is a hard constraint and the
  drawing size absorbs it: a wide widest-label at a large requested size
  can produce a large image. Accepted — that is what "the font size sets
  the scale" means.
