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
style on a square grid, with rounded corners by default.

## Calling convention

```
KnoodleDraw[input]
KnoodleDraw[input, opts]
```

Returns a `Graphics` object (or `Legended[Graphics, ...]` if
`PlotLegends -> Automatic` is given), or `$Failed` (with a
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
| `"CornerRadius"` | `1/3` | Corner-arc radius as a fraction of one grid square, in `[0, 1/2]`. `0` = sharp corners. The radius is a fraction of the grid square (not of the edge length), so long edges don't get disproportionately large arcs, and the arc always stays inside the corner's own grid cell. |
| `"LayoutOptions"` | `{}` | Forwards arbitrary layout-tuning flags to `knoodledraw`. `"name" -> n` or `"name" -> "s"` become `--name=...`; `"name" -> True`/`False` become `--name`/`--no-name`. E.g. `"LayoutOptions" -> {"randomize-bends" -> 3}` or `{"compaction" -> "topo-order", "turn-regularize" -> False}`. See `knoodledraw --help` for the full flag list. |
| `"Checkerboard"` | `False` | Shades the diagram's two-colorable faces (theme-aware wash colors: `Accent1` for `Color->+1` faces, a faint foreground wash for `Color->-1`). |
| `"Labels"` | `{}` | A subset of `{"Crossings", "Arcs", "Faces"}` (a single string is also accepted, not just a list). Annotates the diagram with 0-based element ids. Placement rules (all computed on the *un-rounded* polyline, so corner rounding doesn't perturb label positions): crossing labels have their lower-left corner at the crossing location, transparent background (so they don't obscure the over/under gap). Arc labels: if the arc has a horizontal segment, bottom-center of the label at the midpoint of the *longest* horizontal segment, nudged up (like underlining); if the arc is purely vertical, left-center of the label at the arc-length midpoint of the whole polyline, nudged right. Face labels: see the dedicated section below. |
| `"ExteriorFace"` | `Automatic` | Which face OrthoDraw lays out as the unbounded exterior region — a non-negative integer, 0-based. `Automatic` is OrthoDraw's own default (the face with the largest number of edges). Applies uniformly to every summand of a multi-summand diagram. |
| `PlotLegends` | `None` | `Automatic` adds a `LineLegend` matching each link component's color to its (global, 0-based) component number — numbered consistently with how colors are assigned across summands (see below), not per-summand. |
| `"RandomizeProjection"` | `True` | Applies a random rotation (via `Reapr::RandomRotation`, *not* a shear — this was reworked mid-session, see Notes) before projecting/using 3D geometry. The default projection can degenerate on vertical/coplanar segments (stdin single-component case) or exact coincidental intersections between components (multi-component `.kndlxyz` case) — this defaults on to avoid both. Set to `False` for reproducibility (e.g. testing) or when you know your geometry is already generic. Meaningful for *any* 3D-geometry input (both the stdin single-curve path and the `.kndlxyz` multi-component file path — both were fixed to honor this flag over the course of the session; earlier in development the file path silently ignored it). No-op for PD-code/`PlanarDiagramComplex` input (nothing to project). |
| `ImageSize` | `340` | Standard `Graphics` option, passed through to the final `Graphics[...]`/`Legended[...]`. |
| `"Thickness"` | `Automatic` | Strand thickness. `Automatic` scales the stroke with the diagram — strands are drawn `$strandWidth` (0.5) coordinate units wide, i.e. 1/8 of a grid square, capped at `AbsoluteThickness[7]`. The cap means small diagrams look exactly as they did when `7` was the fixed default, while dense diagrams (many grid squares squeezed into one `ImageSize`) get proportionally thinner strands so the 2-unit under-strand break at each crossing stays visible instead of being swallowed by the stroke (the original failure mode: a fixed 7-pt stroke fills the gaps on any drawing rendered small). An explicit number is the old behavior — `AbsoluteThickness[n]`, fixed printer's points at every scale. Any other value is passed through as a raw `Graphics` directive (e.g. `Thickness[0.02]`, which also survives interactive resizing). |

## Rendering details worth knowing

- **Grid**: one square = `$gridSize` (4) coordinate units. Square (not
  rectangular) unlike the ASCII-art tools' character-cell grid.
- **Component coloring**: `ColorData[97]`, assigned sequentially. For a
  multi-summand diagram, each summand's own local `"Component"` index (from
  `knoodledraw`'s `pd.ArcLinkComponents()` — a *topological*, per-summand
  0-based renumbering, **not** the raw wire-format color value) is offset by
  a running total (`compOffset`) as summands are laid out left to right, so
  two unrelated summands never accidentally share a color. A free-floating
  unknot summand (from `<|"Unknot"->True|>`, possibly with
  `"Component"->rawColor` when known) currently *also* uses this same
  running `compOffset` scheme for its rendering color, **not** the raw wire
  color — i.e. the raw color carried by the unknot marker (which can be a
  large synthetic value, see `KnoodleSimplify.md`) is not currently wired
  into the rendering color choice. This was flagged as a real design
  tension mid-session (the two numbering schemes — topological-local vs.
  raw-wire-color — aren't compatible without further work) and deliberately
  left unresolved/undecided rather than silently picking one.
- **Multi-summand layout**: summands placed left to right,
  `$summandGap` (2) grid squares apart, via `Translate[...]` (no manual
  coordinate arithmetic).
- **Face label placement**: a discretized "pole of inaccessibility"
  algorithm, not a plain polygon centroid (which can land outside a
  non-convex face entirely — face polygons from real diagrams are often
  extremely non-convex). Candidates are restricted to grid-square centers
  strictly inside the face polygon (`RegionMember`); the winner maximizes
  distance to the face boundary (`RegionDistance`), ties broken
  lexicographically (rightmost then topmost). The exterior face (unbounded)
  is handled separately: candidates are the ring of grid cells framing the
  diagram's own bounding rectangle, expanding the ring outward only if it
  turns up entirely empty (e.g. the diagram fills its bounding box
  edge-to-edge).
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
- Labels never hardcode `FontFamily` (system plotting functions like `Plot`
  don't either — confirmed by inspecting `AbsoluteOptions` on a real `Plot`
  output) — so labels inherit whatever font the surrounding notebook
  stylesheet uses. Color/opacity use the theme system (`ThemeColor`,
  `LightDarkSwitched`) rather than fixed grays, so both labels and
  checkerboard shading track light/dark mode and custom notebook themes
  automatically.

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

Draws the standalone unknot (a single circle).

```
KnoodleDraw[Knoodle`KnoodleSimplify[Knot[6, 2], "Unite" -> True], PlotLegends -> Automatic]
```

Full pipeline: simplify, connect-sum back to one diagram per split
component, draw with a component-color legend.
