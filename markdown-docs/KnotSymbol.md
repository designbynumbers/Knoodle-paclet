# KnotSymbol

Reference material for a possible future
`Documentation/English/ReferencePages/Symbols/KnotSymbol.nb` (does not exist
yet — only `KnoodleDraw`/`KnoodleSimplify`/`KnoodleIdentify` currently have
reference pages; `KnotSymbol` and `PlanarDiagramComplex` are documented only
via their `::usage` strings so far). Written from the session that built
this display formatting; referenced from `KnoodleIdentify.md`.

## What it is

`KnotSymbol[c, i, alternating, coset]` identifies a table-looked-up knot
summand, as emitted by `knoodleidentify` (parsed via `ToExpression` — see
`KnoodleIdentify.md` for a real context-resolution bug this caused
elsewhere in the package). It is a plain data-carrying expression;
`FullForm` is unchanged by the custom display below (verified: `Head[ks]`
is still `KnotSymbol`, `ks === KnotSymbol[3,1,True,"m/mr"]` is `True`, and
copy/paste round-trips via `Interpretation`).

## Fields

| Field | Meaning |
|---|---|
| `c` (Integer) | Crossing number — the knot's minimal crossing count. |
| `i` (Integer) | Index within KnotInfo's own per-crossing-number naming scheme (the `idx` in KnotInfo's `c_idx` convention — e.g. the `2` in `5_2`). |
| `alternating` (`True`/`False`) | Whether the knot is alternating, per KnotInfo's own classification. Stored as integer 0/1 in the raw `K[c,i,j,"coset"]` table name, converted to a WL boolean here. (Historical note, in case old commit messages/docs reference this differently: an earlier misreading took this field for amphichirality rather than alternating-ness — corrected mid-project via `klut_check`, which showed a knot is identified by `(c,i,j)` where e.g. `12a_i`/`12n_i` share `i` but differ in `j`, and KnotInfo's column 11 is literally labeled "alternating".) |
| `coset` (String) | Which symmetry-group coset of `{e, m, r, mr}` this table entry represents — `e`=identity, `m`=mirror, `r`=reverse (orientation-reversed), `mr`=mirror+reverse. `'/'`-joined when several of the four variants coincide (aren't topologically distinct), e.g. `"e/r"`, `"m/mr"`. |

## Valid coset values, by KnotInfo Symmetry Type

Each KnotInfo knot has exactly one Symmetry Type, which determines how many
distinct table entries (and which coset strings) it gets:

| Symmetry Type | Coset values (→ number of distinct table entries) |
|---|---|
| chiral | `"e"`, `"r"`, `"m"`, `"mr"` (4 entries, all distinct) |
| reversible | `"e/r"`, `"m/mr"` (2 entries) |
| negative amphicheiral | `"e/mr"`, `"m/r"` (2 entries) |
| positive amphicheiral | `"e/m"`, `"r/mr"` (2 entries) |
| fully amphicheiral | `"e/m/r/mr"` (1 entry — e.g. `4_1`, the figure-eight knot) |

A coset string containing `"e"` as one of its `'/'`-joined tokens means the
diagram-as-given is (topologically) the identity/unmodified variant — this
is exactly the condition the display logic below uses to decide whether the
coset needs to be shown at all.

## Display format (custom `MakeBoxes`, `FullForm` unaffected)

Typeset in ordinary KnotInfo notation, not the raw `KnotSymbol[...]` call
form:

- **`3 <= c <= 10`**: `c` with subscript `i` — e.g. `3_1`.
- **`c >= 11`**: `c` concatenated with `"a"` (if `alternating`) or `"n"`
  (if not), as one unit, with subscript `i` — e.g. `11a` subscript `456`,
  or `12n` subscript `3541`.
- **Coset superscript**: appended (superscript, on top of the above) *unless*
  `coset` contains `"e"` as one of its tokens — in that case the coset is
  omitted entirely, since an `"e"`-containing coset means this is already
  the "default"/unmodified diagram and doesn't need disambiguating.

Examples: `KnotSymbol[3,1,True,"e/r"]` → `3_1` (coset has `"e"`, suppressed
— this is the ordinary trefoil). `KnotSymbol[3,1,True,"m/mr"]` → `3_1` with
superscript `m/mr` (the mirror trefoil — same `c,i,alternating`, different
coset, needs the superscript to disambiguate from the plain trefoil).
`KnotSymbol[11,456,True,"e/r"]` → `11a` subscript `456`.
`KnotSymbol[12,3541,False,"m"]` → `12n` subscript `3541` with superscript
`m`.

The superscript coset text renders as **literal characters** — `m/mr`
shown with an ordinary slash, never interpreted as division, and **without
quote marks** around it (unlike formatting an ordinary WL String value,
which shows with quotes unless `ShowStringCharacters -> False` is set).

## Implementation: how the box construction actually has to work

This took three attempts to get right, and the wrong approaches *looked*
plausible enough that they're worth documenting explicitly so a future
session doesn't repeat them.

**Wrong approach #1**: hand-assembling `SubscriptBox`/`SuperscriptBox`/
`InterpretationBox` directly inside the `MakeBoxes` rule, e.g.
`InterpretationBox[Evaluate[knotSymbolBox[...]], ks]`. This *looked*
correct when inspected via `MakeBoxes[expr, StandardForm]` directly in the
kernel (the raw returned box expression looked fully expanded) — but that
inspection method doesn't actually catch this bug. Only rendering to an
actual image (`Export[..., Grid[{{ks, ...}}], ...]` then reading the PNG
back) revealed the real problem: **`InterpretationBox` holds its first
argument completely** — not even a `Module`-bound local variable's
already-computed value gets substituted in; the front end just shows the
literal, un-rendered symbol name (e.g. `Global`box$66194`) as text. This is
true regardless of `Evaluate[...]` wrapping attempts.

**The actual fix**: build the display at the *expression* level instead of
the box level — `Subscript[...]`/`Superscript[...]`/`Interpretation[...]`,
which each have their own correct, built-in `MakeBoxes` rule — and hand the
*whole thing* to `ToBoxes[..., fmt]` only at the very end:

```
knotSymbolExpr[c_Integer, i_Integer, alternating : (True | False), coset_String] :=
 Module[{base},
  base = If[3 <= c <= 10, Subscript[c, i], Subscript[ToString[c] <> If[alternating, "a", "n"], i]];
  If[MemberQ[StringSplit[coset, "/"], "e"], base, Superscript[base, coset]]
 ];

KnotSymbol /: MakeBoxes[
   ks : KnotSymbol[c_Integer, i_Integer, alternating : (True | False), coset_String], fmt_] :=
 ToBoxes[Interpretation[knotSymbolExpr[c, i, alternating, coset], ks], fmt];
```

Also confirmed directly (both facts non-obvious, both verified by rendering
an actual image, not just reasoning about it): a `String` argument to
`Subscript`/`Superscript` displays as its literal characters with no quote
marks, and `Interpretation[displayExpr, actualExpr]` (the *expression*-level
wrapper, distinct from the *box*-level `InterpretationBox`) correctly
evaluates `displayExpr` normally — no held-argument trap the way
`InterpretationBox` has.

## Testing note

`?symbol`-level `Information[...]["Documentation"]` and `MakeBoxes[...]`
return-value inspection are both unreliable ways to verify custom notebook
display code — they can look correct while the actual rendered notebook is
broken (blank/empty boxes). The reliable check used throughout this session
was: build a small `Grid[...]` of test cases, `Export[...]` it as a PNG,
`Read` the PNG back and look at it.
