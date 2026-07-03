# KnoodleIdentify

Reference material for the Mathematica Documentation Center page(s) at
`Documentation/English/ReferencePages/Symbols/KnoodleIdentify.nb`. Written
from the session that built this function; intended as a source of truth
for a future session filling out the full "Details and Options" /
"Examples" sections of the real reference page (currently skeletal: one
option mentioned, one example).

## What it does

`KnoodleIdentify[input]` identifies a knot: it looks the diagram up in the
KLUT (Knot LookUp Table), using the Knoodle CLI tool `knoodleidentify`,
which is *self-contained* — it decomposes and simplifies internally (via
its own pass-reduce → escalate-with-Reapr → table-lookup protocol), so it
does not need (and should not be given) an already-simplified diagram; it
does its own work regardless. If the diagram is a connect sum of several
simpler knots (e.g. the granny knot = two trefoils tied end to end),
`KnoodleIdentify` reports each of the simpler pieces and how many times it
occurs, rather than failing to find a single table entry for the whole
composite.

## Calling convention

```
KnoodleIdentify[input]
KnoodleIdentify[input, opts]
```

Returns an `Association` from each identified knot summand (a
`KnotSymbol[...]`, see below) to its integer multiplicity, or `$Failed` if
`input` isn't recognized (`KnoodleIdentify::badinput`) or is a genuine link
(`KnoodleIdentify::link`, see below).

## Input formats

Identical to `KnoodleDraw` — see `KnoodleDraw.md` (KnotData spec, sampled
`Function`, 3D space curve, list of 3D curves for a link, native Knoodle PD
code, multi-summand list including `{{}}` for the unknot, KnotTheory
`PD`/`DTCode`/`GaussCode`, or a `PlanarDiagramComplex` from
`KnoodleSimplify`). The last case is worth calling out specifically: even
though the underlying `knoodleidentify --help` text says "feed it the SAME
stream you would feed `knoodlesimplify`, not the output of
`knoodlesimplify`" (because it does its own internal simplification and
doesn't need pre-simplified input), passing a `PlanarDiagramComplex` still
works correctly for this WL wrapper — `knoodleidentify` shares the same
`ReadKnot` parser as the other two tools, so PDC-native-format input (which
is all a `PlanarDiagramComplex` really is) parses transparently; it's just
redundant/unnecessary work, not wrong.

## Return value: the `KnotSymbol`/`Association` shape

- **A single prime knot**: `<|KnotSymbol[c, i, alternating, "coset"] -> 1|>`.
- **A composite (connect sum)**: one entry per *distinct* prime factor, with
  its multiplicity as the value — e.g. the granny knot (trefoil # trefoil)
  gives `<|KnotSymbol[3, 1, True, "m/mr"] -> 2|>`, not two separate
  `-> 1` entries.
- **The unknot**: `<||>`, the empty association. An unknot summand is the
  identity element for connect sum, so it's simply omitted rather than
  appearing with some placeholder key.
- **A summand outside the table's crossing range** (`n > 13`, the KLUT's
  current maximum): `Unidentified[n, pd] -> mult`, where `pd` is the
  summand's own signed PD code (for offline analysis — it genuinely cannot
  be resolved further, there is no larger table to escalate to).
- **A summand inside the table's range but still unresolved after Reapr
  escalation** (`n <= 13`): `NotFound[n, pd] -> mult` — this is the
  *suspicious* case (in principle everything `<= 13` crossings should
  resolve; if it doesn't, either the table has a real gap or something else
  went wrong) as opposed to `Unidentified`, which is simply expected/normal
  for large inputs.
- **A genuine link** (see next section): fails outright, does not appear as
  a value in a returned Association at all.

### The `"MaxCrossings"` option and `NotFound`

Restricting `"MaxCrossings"` below a knot's actual minimal crossing number
is a reliable, deliberate way to force a `NotFound` result for testing —
confirmed directly: `KnoodleIdentify[Knot[5, 1], "MaxCrossings" -> 3]`
gives `<|NotFound[5, {{4,9,5,0,-1}, ...}] -> 1|>` (the tool correctly
recognizes it *can't* resolve within the restricted table, rather than
either mis-identifying it or silently ignoring the restriction).

| Option | Default | Meaning |
|---|---|---|
| `"MaxCrossings"` | `Automatic` | Maps to `knoodleidentify`'s `--max-crossings`. `Automatic` = the tool's own default (13, the KLUT's current max). Valid range 3-13. Restricts lookup to smaller subtables — smaller/faster, but anything above the restricted range that would otherwise have resolved instead comes back as `NotFound` (not `Unidentified` — the distinction above is based on the tool's *actual* max range, 13, not the caller-restricted one). |

Not currently exposed as WL options (available only via the raw
`knoodleidentify` CLI, not surfaced through this function at all):
`--data-dir` (KLUT data directory override — auto-detected relative to the
binary's location, `data/Klut` next to the executable's parent directory;
this already resolves correctly for the paclet's dev-mode
`$KnoodleBinaryDirectory` setup, so there was no pressing need to expose
it), `--expanded` (alternate one-line-per-knot output joined by `' # '`
using raw `K[...]` table names instead of an `Association`), `--tsv`
(per-summand tab-separated output), `--quiet` (suppresses the stderr
summary — irrelevant to the WL wrapper anyway, since `RunProcess[...,
"StandardOutput", ...]` only ever captures stdout, confirmed the summary
line is cleanly stderr-only).

## Link handling: fails, does not return `<|Link[n]->1|>`

`KnoodleIdentify` only identifies knots. If given a genuine link (more than
one component), it fails with `$Failed` and a `KnoodleIdentify::link`
message naming the crossing count, rather than returning
`<|Link[n] -> 1|>` as if that were a normal, usable result (an earlier,
initial version of this function did exactly that, and was deliberately
changed on request — a link result silently succeeding was considered
actively misleading, not just incomplete). The message suggests the escape
hatch: `KnoodleSimplify[..., "Unite" -> True]` first, if the components
should be treated as connect-summed into a single knot rather than kept as
a genuine link.

This is safe to detect reliably because of how the underlying tool's
`IdentifyInto` function works: it checks `work.ColorCount() != 1` on the
*whole* input PDC *before* any summand-level identification even begins —
so a link result is always exactly one entry, `Link[n]`, never mixed in
among real `KnotSymbol` summands. The detection code is
`Cases[Keys[result], k_ /; headNameQ[k, "Link"] :> First[k]]`.

**Real bug found and fixed while implementing this detection, worth
remembering**: the obvious-looking pattern `Cases[Keys[result], Link[n_] :>
n]` silently never matched anything. `ToExpression` parses
`knoodleidentify`'s stdout at *runtime*, in whatever context is active at
the call site (the *caller's* context) — so the `Link` symbol it produces
there is not the same symbol as a `Link` written directly in this package's
source, which gets resolved to `Knoodle`Private`Link` when the package file
itself is loaded. Two different symbols, never equal, no error, just a
pattern that quietly never fires. Fixed with `headNameQ` (a helper already
used elsewhere in this package for the identical problem: matching
KnotTheory symbols regardless of which context that package happens to
load into) — context-independent matching by symbol name string, not a
literal pattern. **Do not "fix" this by declaring a public `Knoodle`Link`
symbol** to sidestep the mismatch — that would shadow the unrelated
built-in `System`Link` (used for WSTP/MathLink connections), a strictly
worse problem than the one it would solve.

## `KnotSymbol[c, i, alternating, coset]`

The full field/coset-notation reference lives in `KnotSymbol.md` — a future
session filling out `KnoodleIdentify`'s reference page will likely also
want to build a dedicated `KnotSymbol` reference page and can pull directly
from that file (fields, valid coset values by KnotInfo symmetry type,
display-format rules, implementation gotchas from getting the box
formatting to actually render).

## Example

```
Needs["Knoodle`"]
KnoodleIdentify[Knot[3, 1]]
```

gives `<|KnotSymbol[3, 1, True, "m/mr"] -> 1|>` (note: `Knot[3,1]`'s default
chirality identifies as the `"m/mr"` coset, *not* `"e/r"` — verified
directly, don't assume the "identity" coset without checking).

```
grannyOnly = {
  {{5, 2, 0, 3, -1, 3, 3}, {3, 0, 4, 1, -1, 3, 3}, {1, 4, 2, 5, -1, 3, 3}},
  {{5, 2, 0, 3, -1, 3, 3}, {3, 0, 4, 1, -1, 3, 3}, {1, 4, 2, 5, -1, 3, 3}}
};
KnoodleIdentify[grannyOnly]
```

gives `<|KnotSymbol[3, 1, True, "m/mr"] -> 2|>` (multiplicity, not two
entries).

```
KnoodleIdentify[{{0, 1, 2, 3, 1, 0, 0}, {2, 3, 0, 1, 1, 1, 1}}]
```

fails with `$Failed` and `KnoodleIdentify::link` (this is a genuine
2-crossing, 2-component link).
