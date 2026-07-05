# KnoodleSimplify

Reference material for the Mathematica Documentation Center page(s) at
`Documentation/English/ReferencePages/Symbols/KnoodleSimplify.nb`. Written
from the session that built this function; intended as a source of truth
for a future session filling out the full "Details and Options" /
"Examples" sections of the real reference page (currently skeletal: two
options mentioned, one example).

## What it does

`KnoodleSimplify[input]` simplifies a knot or link diagram — reducing the
number of crossings without changing the underlying knot/link type — using
the Knoodle CLI tool `knoodlesimplify` (full Reapr pipeline by default:
decompose, pass-simplify, then randomized 3D embedding + compaction).
Diagrams built from typed-in codes or sampled from space curves are often
needlessly complicated; this finds a simpler diagram of the same knot or
link.

## Calling convention

```
KnoodleSimplify[input]
KnoodleSimplify[input, opts]
```

Returns a `PlanarDiagramComplex[<|"serialized" -> string|>]` object, or
`$Failed` (with a `KnoodleSimplify::badinput` message) if `input` isn't
recognized. The returned object can be passed directly to `KnoodleDraw` (to
render it) or `KnoodleIdentify` (to look it up in the knot table) — no
conversion needed, since both of those also go through the same shared
`toTSV` normalizer and `ReadKnot` parser.

## Input formats

Identical to `KnoodleDraw` — see `KnoodleDraw.md` for the full list
(KnotData spec, sampled `Function`, 3D space curve, list of 3D curves for a
link, native Knoodle PD code, multi-summand list including `{{}}` for the
unknot, KnotTheory `PD`/`DTCode`/`GaussCode`, or another
`PlanarDiagramComplex`).

## The `PlanarDiagramComplex` wire format, and why it exists

This is the single most important implementation detail for anyone working
on this function. `knoodlesimplify`'s *ordinary* TSV output format (bare
`k`/`s` markers + 4-7 column PD rows, the same format `knoodledraw`/
`knoodleidentify` read) has **no way to represent a colored unknot
summand** — a component that simplifies away to a free-floating unknot
just becomes a bare `s` line with the color silently discarded, even
though the input was colored. This was a real, verified bug in the
underlying tool at the start of this feature's development, found by
testing (not just reading docs): feeding a colored input where one
component collapses to nothing, the color vanished from the output.

The fix adopted was **not** a new ad hoc extension of that TSV grammar.
Instead, `--format=pdc` (which `KnoodleSimplify` always uses) makes
`knoodlesimplify` emit `PlanarDiagramComplex`'s own native serialization —
the same format its C++ `WriteToFile`/`FromInString` methods already use
internally, extended to the CLI tools rather than reimplemented:
- `'s <flag>'` + colored PD rows for a real (non-trivial) diagram (`<flag>`
  is `ProvenMinimalQ()`, 0 or 1).
- `'u <color>'` for a colored unknot (Anello) summand — the fix for the bug
  above.

`ReadKnot` (shared by all three CLI tools) auto-detects this format
(distinguishing it from the plain bare-`s`/PD-row grammar purely by the
first marker's shape — `'u'` never otherwise appears, `'s <digit>'` has a
trailing token the plain grammar's bare `'s'` never has) and delegates the
whole record to `PDC_T::FromInString`, so it round-trips through
`KnoodleSimplify` → `KnoodleDraw`/`KnoodleIdentify` transparently, and even
back through `KnoodleSimplify` again (re-simplifying an already-simplified
`PlanarDiagramComplex` is idempotent and works correctly).

**Known caveat**: PDC-native format can only represent an Anello (0-crossing
unknot) with a *valid* (non-negative) color — a genuinely colorless
unknot summand (e.g. from `{{}}`, or a component that reduces to nothing
starting from uncolored 4/5-column PD input) would otherwise make the
underlying `PD_T::InvalidQ()` true and get silently dropped by
`WriteToFile`. Fixed by substituting a **synthetic color from a very high
numeric base** (`(2^63-1)/2`-ish, incrementing per summand) whenever the
real color is unknown — astronomically unlikely to collide with a real
user-supplied color, but genuinely visible if you inspect the serialized
string or a drawn `"Component"->` value for a colorless-input unknot: you
will see a large, arbitrary-looking integer rather than a small one. This
is expected, not a bug, but worth knowing so it isn't mistaken for one.

The returned `PlanarDiagramComplex` gets a proper interpretable summary box
in the notebook (`BoxForm\`ArrangeSummaryBox`, the same idiom WL uses for
things like `TimeSeries`/`Interpreter`-wrapped objects) showing Crossings/
Summands/Unknots counts — derived cheaply by scanning the serialized
string's line prefixes (`pdcSummary`), not from separately-stored fields
that could drift out of sync with the actual serialized content.

**Versioning tradeoff, worth being upfront about**: because `KnoodleSimplify`
calls the `knoodlesimplify` CLI as a black box and just carries its output
string around, Henrik (who owns `Knoodle`'s `src/`) can freely change
`WriteToFile`/`FromInString`'s exact format in the future without this
paclet needing a matching code change — the paclet only needs its `Knoodle`
git submodule pin bumped. The tradeoff: if a notebook has a
`PlanarDiagramComplex` object cached from a session using an older pinned
Knoodle version, and the paclet is later updated to a newer submodule pin
with an incompatible format change, that cached object could stop parsing.
Not observed in practice yet, just a known structural risk.

## Options

| Option | Default | Meaning |
|---|---|---|
| `"SimplifyLevel"` | `Automatic` | Maps to `knoodlesimplify`'s `--simplify-level`. `Automatic` = the tool's own default (full Reapr pipeline, level 6). The scale (rewired upstream at Knoodle `34ba537`, 2026-07-04 — levels 1–3 were silent no-ops before; see `~/Knoodle/handoff/knoodlesimplify-simplify-levels-rewired/`): `0` no simplification (PD passthrough); `1`–`3` **local-only diagnostic tiers**, no rerouting (`1` Reidemeister I only, `2` R I+II, `3` all local moves incl. assisted R1a/R2a) — for display and for benchmarking other simplifiers, *not* for hard diagrams; `4` path rerouting; `5` +summand/connect-sum detection; `6`+ full Reapr (randomized 3D embedding + compaction). The 3→4 boundary is deliberately **not** a superset: level 4 drops the local pass (upstream tuning found it doesn't help once rerouting engages), so per-level crossing counts need not be monotone between 3 and 4. The reference page demonstrates the tiers on the 128-crossing raw projection of a Gaussian random 100-gon (`SeedRandom[5]`, `"RandomizeProjection" -> False`): 128 → 119 (R1) → 45 (R1+R2) → 18 (all local) → 6 (full pipeline; `KnoodleIdentify` names it 6_2), with Haken's Gordian unknot as the counterpoint that stays at 141 crossings at every level below full. |
| `"RandomizeProjection"` | `True` | Same semantics as `KnoodleDraw`'s option of the same name — see there. |
| `"Unite"` | `False` | **The most important option for composite/split links.** `False` (default) matches `knoodlesimplify`'s own `--split` output shape: one diagram per diagrammatically-prime connect-sum factor, with same-colored factors belonging to the same original link component (colors are globally persistent/traceable across the whole complex — confirmed by reading `Split.hpp`, never renumbered per-summand). This is the natural input shape for `KnoodleIdentify` on a composite knot (e.g. the granny knot round-trips as *two separate* `KnotSymbol[3,1,...]` summands in this shape, with multiplicity 2 once identified). `True` uses `--unite`, which connect-sums same-colored factors *back together* via genuine arc splicing, giving one diagram per physically split link component — the natural single-PD-code-per-component form for exporting to KnotTheory or Regina. See the dedicated section below — getting this option's C++ implementation right took two attempts. |
| `"SimplifyOptions"` | `{}` | Forwards arbitrary `knoodlesimplify` flags, same passthrough convention as `KnoodleDraw`'s `"LayoutOptions"` (`"name"->value` → `--name=value`; `"name"->True`/`False` → `--name`/`--no-name`). This is how to reach the full `PlanarDiagramComplex::Simplify_Args_T` surface (see table below) beyond the coarse `"SimplifyLevel"` preset. |
| `"OutputFormat"` | `"PlanarDiagramComplex"` | `"KnotTheory"` returns KnotTheory\` PD codes instead of a `PlanarDiagramComplex` — one `PD[X[...], ...]` per **physically split portion** of the link (a bare `PD` when there is only one, a list otherwise; a 0-crossing portion is KnotTheory's `PD[Loop[1]]`) — ready for KnotTheory invariant computations (`Jones[pd][q]` etc.). Implies `"Unite" -> True`: PD codes cannot express that separate diagrams share a link component (the complex's cross-summand colors), so same-colored connect-sum factors are spliced together first. Implementation is **WL-side** (the CLI still emits the full PDC, so nothing is lost internally): the `PD`/`X`/`Loop` heads are created in the KnotTheory\` context *without* loading the package (a later ``Needs["KnotTheory`"]`` binds the same symbols), arcs are 1-based per KnotTheory's convention, and — because the CLI's `--unite` merges physically split components into one `s` block with disjoint arc ranges (verified 2026-07-04) — split portions are recovered WL-side as connected components of the crossings-sharing-arcs graph, each rank-renumbered to a self-contained code. |

### `"SimplifyOptions"` flags (full `Simplify_Args_T` surface)

All of these are optional CLI flags on `knoodlesimplify` that override
whatever `"SimplifyLevel"`'s preset already chose (applied on top, not
instead of). None of these currently have dedicated named WL options — they
all go through `"SimplifyOptions"`.

| Flag (inside `"SimplifyOptions"`) | Simplify_Args_T field | Type / valid values |
|---|---|---|
| `"compress-initial"` | `compress_initialQ` | bool (default true in the tool) |
| `"local-opt-level"` | `local_opt_level` | integer 0-4 |
| `"dijkstra-strategy"` | `strategy` | `"unidirectional"`, `"alternating"`, `"bidirectional"` |
| `"start-max-dist"` | `start_max_dist` | integer |
| `"final-max-dist"` | `final_max_dist` | integer |
| `"reroute"` | `rerouteQ` | bool (also set implicitly by `"SimplifyLevel">=4`) |
| `"disconnect"` | `disconnectQ` | bool (also set implicitly by `"SimplifyLevel">=5`) |
| `"compress"` | `compressQ` | bool |
| `"compression-threshold"` | `compression_threshold` | integer |
| `"reapr-rotation-trials"` | `rotation_trials` | non-negative integer (default 25) |
| `"reapr-permute-random"` | `permute_randomQ` | bool |
| `"reapr-scaling"` | `scaling` | real (default 1.0) |
| `"randomize-bends"` | `randomize_bends` | integer (default 4) |
| `"randomize-virtual-edges"` | `randomize_virtual_edgesQ` | bool |
| `"compaction-method"` | `compaction_method` | `"unknown"`, `"topological-numbering"`, `"topological-ordering"`, `"length-mcf"` (default), `"length-clp"`, `"area-length-clp"` |
| `"canonicalize"` | `canonicalizeQ` | bool |

Also pre-existing, not part of `Simplify_Args_T`, but reachable the same
way: `"max-reapr-attempts"` (integer, default 25) and `"reapr-energy"`
(`"tv"`, `"dirichlet"`, `"bending"`, `"height"`, `"tv_clp"`, `"tv_mcf"` —
note `dirichlet`/`bending` need a `KNOODLE_USE_UMFPACK` build and
`tv_clp`/`length-clp`/`area-length-clp` need `KNOODLE_USE_CLP`; neither is
currently compiled into the paclet's bundled binaries, confirmed via
`knoodlesimplify --help`, which lists only `TV, Height, TV_MCF` as
available).

**Deliberately not exposed, anywhere**: `splitQ` (the `Simplify_Args_T`
field, distinct from the `"Unite"` option above despite similar naming).
It's hardcoded `true` always. Setting it `false` doesn't just skip a
cosmetic merge step — it actively *degrades* simplification quality:
verified by reading `Simplify.hpp`, when a diagram has multiple components
and `splitQ` is false, Reapr is skipped entirely for it (falls straight to
"push onto the done pile" with no attempt at randomized embedding). The
`"Unite"` option achieves the desired *output shape* as a post-processing
step instead, without sacrificing simplification quality — this is why the
two are named differently and neither is a synonym for the other.

## `"Unite"` implementation notes (real pitfalls, both found empirically)

Two wrong turns were taken and corrected while building this, both worth
knowing about since they represent genuine API traps in the underlying
`PlanarDiagramComplex` class that a future session could easily re-fall
into:

1. **`SubcomplexByColor`/`Subcomplex` don't filter unknots by color.** They
   filter *arcs* by color, but a 0-crossing Anello has no arcs to filter —
   so it passes through *every* existing Anello unconditionally regardless
   of the requested color. Confirmed empirically: grouping two colorless
   unknots (different colors) through this mechanism duplicated them, once
   per distinct color group present, instead of keeping them separate.
2. **`PlanarDiagramComplex::Unite()`/`Union()` do not actually perform a
   connect sum**, despite the name. They just pack multiple diagrams'
   crossing/arc data side by side into one `PD_T`'s arrays (offset
   indices) — no arc splicing happens. The result is still, topologically,
   several disconnected diagram components bundled into one `PD_T` object.
   Confirmed the hard way: feeding `Unite()`'s output to `KnoodleDraw`
   segfaulted `OrthoDraw` with "Input planar diagram has more than one
   diagram components." The actual connect-sum operation is a *different*
   method: `PlanarDiagramComplex::Connect()`/`ConnectedSum()`
   (`Connect.hpp`) — it groups by color, picks a representative diagram per
   color, and performs genuine arc surgery (`PD_T::Connect(a,b)`, which
   splices two arcs into one) between the representative and every other
   same-colored diagram. It already handles unknots exactly right (a color
   with any non-trivial diagram absorbs — drops — that color's unknots, a
   no-op connect-sum; a color with only unknots keeps exactly one). The
   final, correct implementation of `"Unite"->True"` is just
   `all_pdc.Connect();` — one line, once the right method was found.

## Example

```
Needs["Knoodle`"]
simplified = KnoodleSimplify[Knot[6, 2]];
KnoodleDraw[simplified]
```

```
(* two same-colored trefoils (a connect sum) plus a differently-colored,
   separate unknot component -- i.e. a genuine 2-component link, one
   component of which is the granny knot *)
grannyPlusUnknot = {
  {{5, 2, 0, 3, -1, 3, 3}, {3, 0, 4, 1, -1, 3, 3}, {1, 4, 2, 5, -1, 3, 3}},
  {{5, 2, 0, 3, -1, 3, 3}, {3, 0, 4, 1, -1, 3, 3}, {1, 4, 2, 5, -1, 3, 3}},
  {{0, 0, 1, 1, 1, 7, 7}}
};
KnoodleSimplify[grannyPlusUnknot]                  (* 3 summands: two 3_1's + an unknot *)
KnoodleSimplify[grannyPlusUnknot, "Unite" -> True] (* 2 summands: one 6-crossing granny knot + the unknot *)
```

```
(* the reference page's color-semantics example: the connect sum of a
   trefoil (on component 0) and a Hopf link (components 0 and 1), as
   colored 6-column PD input *)
trefC = {{0, 3, 1, 4, 0, 0}, {2, 5, 3, 0, 0, 0}, {4, 1, 5, 2, 0, 0}};
hopfC = {{3, 0, 2, 1, 1, 0}, {1, 2, 0, 3, 0, 1}};
KnoodleDraw[KnoodleSimplify[{trefC, hopfC}, "Unite" -> True], PlotLegends -> Automatic]
Row[KnoodleDraw[KnoodleSimplify[{trefC, hopfC}], PlotLegends -> Automatic]]
```

United: one connected 5-crossing two-component diagram. Split: two prime
factors whose **strand colors are meaningful across the summands** — same
color, same physical link component (`KnoodleDraw` colors by the wire
colors the complex carries; see `KnoodleDraw.md`'s "Component coloring").
The trefoil factor draws entirely in component 0's color, the same color as
the Hopf strand it is tied into.
