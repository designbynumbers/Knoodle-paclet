# Knoodle-paclet TODO

## Upstream (handed off): knoodlesimplify segfaults on a malformed .kndlxyz

Found 2026-07-03 while building the link doc example: a `.kndlxyz` file that
fails to parse logs `ReadFromFile: Reading file failed` and then dies with
exit 139 (SIGSEGV) instead of a clean error exit — something dereferences
the returned invalid LinkEmbedding. Handed off:
`~/Knoodle/handoff/knoodlesimplify-kndlxyz-readfail-segfault/ROUND-1.md`.
No paclet follow-up needed once fixed (the WL wrappers now message on
empty/failed tool output).

## KLUT 14-16-crossing NotFound quirk — NO ACTION (decision 2026-07-03)

Found while writing the KnoodleIdentify reference page:
`Klut::max_crossing_count` is already 16 in `src/Klut.hpp` but the data
tables stop at 13, so a 14-16-crossing knot currently comes back
`NotFound[n, pd]` ("suspicious") instead of `Unidentified[n, pd]` ("beyond
the table"). Jason: the table extension to 16 crossings is in progress, so
this window closes by itself — do not "fix" the classification boundary.
The reference page's Unidentified example deliberately uses a (2,17) torus
knot so it is correct both before and after the data lands.

## RESOLVED (2026-07-03, upstream 356f9bc + paclet follow-ups): the two
## handed-off geometry bugs

Both handoffs came back fixed the same day (upstream commit 356f9bc,
responses in `~/Knoodle/handoff/*/ROUND-1-RESPONSE.md`); submodule bumped,
paclet follow-ups done:

1. **knoodleidentify --randomize-projection**: flag added upstream exactly
   as scoped. Paclet side: `"RandomizeProjection" -> True` option wired
   through `KnoodleIdentify` (matching the other two wrappers), and a new
   `KnoodleIdentify::failed` message replaces the silent `$Failed` on
   empty/unparseable tool output. Reference page + markdown docs updated
   (the RotationTransform workaround text is gone).
2. **Plain unknot returning $Failed**: root cause was NOT the streaming
   writer (as ROUND-1 guessed) but `CreateDiagramFrom3D` in
   `tools/knoodle_io.hpp` discarding the unlinks tensor when
   `FromKnotEmbedding` returns an invalid PD for a zero-crossing curve —
   the fix also cured the identical latent symptom in knoodleidentify.
   Verified through the wrappers: `KnoodleDraw[circle]` draws the circle,
   `KnoodleSimplify[circle]` gives the unknot complex, and
   `KnoodleIdentify[circle]` gives `<||>`.

Sonnet's response also flags: ASCII-mode `knoodledraw` still deliberately
draws nothing for a bare unknot summand (design choice upstream, only
`--format=wl` emits the marker) — irrelevant to the paclet, noted in case
it ever surprises someone.

## Documentation build — RESOLVED (2026-07-03)

The `PacletDocumentationBuild` mystery below is solved. Key facts, verified
against MaTeX 1.7.10 (installed from the Paclet Repository, i.e. its *shipped*
built form) on this machine:

- Doc notebooks exist in **two forms**: *source/authoring* (visible
  `CategorizationSection` cells, no stylesheet) and *built/in-product*
  (Categorization folded into `TaggingRules -> {"Metadata" -> {...}}`, Wolfram
  `Reference.nb`/`Guide` stylesheet, plus generated `SearchIndex/`,
  `SpellIndex/`, `Index/`). `PacletDocumentationBuild[dir]` transforms the
  former into the latter under `build/Knoodle/Documentation/`.
- The build was **already working** for the 3 reference pages; the earlier
  `SuccessfulFilesCount -> 0` was incremental-rebuild noise. The *only* real
  failure was the **Guide page**: it lacked a `Categorization` section, so the
  builder threw `"Entity Type" value not found` and produced no built guide.
- **Fix applied** to `Documentation/English/Guides/Knoodle.nb`:
  1. Added a `Categorization` group (`Entity Type -> "Guide"`,
     `Paclet Name -> "Knoodle"`, `Context -> "Knoodle`"`,
     `URI -> "Knoodle/guide/Knoodle"`).
  2. Switched the body to real guide styles (`GuideTitle`, `GuideAbstract`,
     `GuideReferenceSection`, `GuideText`) with clickable
     `paclet:Knoodle/ref/*` links for the three documented functions. (This
     also cleared a `GetNotebookTitle::notitle` warning — the title must be a
     `GuideTitle`/`GuideTOCTitle` cell.)
- Result: a clean `PacletDocumentationBuild` → `SuccessfulFilesCount -> 4`,
  `FailedFilesCount -> 0`, no `notitle` warning. All 4 built notebooks have
  Categorization stripped + the Wolfram stylesheet; full tree
  (Guide + 3 Symbols + Index/SearchIndex/SpellIndex) matches MaTeX's shipped
  layout. (Two residual messages — `Options::optnf` for `TaggingRules` and
  `MIMETypeToFormatList::fmterr` — are benign DocumentationBuild internals;
  they fail no file.)

**Remaining doc work (the actual distribution bug — was item (b)): RESOLVED,
verified 2026-07-03.** `ci/package-paclet.wls`'s `PacletBuild` performs the
documentation build itself; inspected `build-local/Knoodle-0.0.1.paclet` and
confirmed the shipped `Documentation/` is the **built** form (SearchIndex +
SpellIndex present, Categorization folded into TaggingRules). Also: the hand-edited source guide's
internal cache (`NotebookDataLength`, byte offsets, trailing
`NotebookFileOutline`) is now stale — harmless (the front end recomputes on
open/save; the builder reads the real `Notebook[...]` expression), but open +
save it once in the FE if a clean source diff is wanted.

## Documentation Center reference pages (historical notes)

**Status**: skeletal but working. Reference pages exist for `KnoodleDraw`,
`KnoodleSimplify`, `KnoodleIdentify`
(`Documentation/English/ReferencePages/Symbols/*.nb` — note **plural**
`Symbols`, confirmed against Wolfram.app's own
`SystemFiles/Components/PacletTools/Examples/Greetings` example paclet;
singular `Symbol` silently breaks `?symbol` lookup with no error, just
falls back to a raw internal-code dump), plus a one-paragraph skeleton
Guide page (`Documentation/English/Guides/Knoodle.nb`). `PacletInfo.wl` has
the `"Documentation"` extension wired up.

**Verified working end-to-end**, in a real front-end session (not just the
headless kernel this was mostly built against): `?KnoodleDraw` shows the
usage text plus a "Documentation → Local »" link, and clicking it opens the
actual reference page — correct `ObjectName`/`Usage`/real worked
`Examples` (with genuine evaluated Input/Output pairs, not just
illustrative text).

**Remaining cosmetic defect**: the `Categorization` section (pure
search-index metadata — Entity Type/Paclet Name/Context/URI, not
reader-facing content) renders expanded and prominent at the top of each
reference page, instead of being hidden/collapsed the way real WRI
reference pages present it. Confirmed this is *not* a `CellGroupData[...,
Open]` vs. `Closed` issue (tried `Closed`, no change — even `SayHello.nb`,
a genuine WRI-authored example, has this section `Open` in its raw file).

This is apparently the job of `PacletDocumentationBuild` (from the
`PacletTools` system paclet — "Paclet documentation authored with
DocumentationTools will be built into styled notebooks," per its own
reference page), but its actual behavior proved opaque and was not solved
this session:

- `PacletDocumentationBuild[pacletObjectOrDirectory]` only ever scanned
  `Guides/Knoodle.nb`, never the three `ReferencePages/Symbols/*.nb` files
  — regardless of passing a `PacletObject` (via `PacletFind["Knoodle"]`)
  vs. a bare directory string, `OverwriteTarget -> True`, or a guessed
  `"Notebooks" -> {...}` option (which may not even be a real option name
  for this function — genuinely undocumented, found no reference for it).
- It refuses to process even `Guides/Knoodle.nb`, failing with
  `` DocumentationBuild`Info`GetNotebookCategorization::val: "Entity Type"
  value not found in notebook `` — meaning the Guide page needs its *own*
  `Categorization` section (presumably `"Entity Type" -> "Guide"`, by
  analogy with the `"Entity Type" -> "Symbol"` convention on reference
  pages) before the build tool will even proceed past it.
- **Real clue for whoever picks this up**: despite the `Success[...]`
  return value reporting `SuccessfulFilesCount -> 0`, a `build/` directory
  (gitignored, not committed) appeared in the repo root afterward,
  containing what look like *processed* copies of all three reference
  pages (`build/Knoodle/Documentation/English/ReferencePages/Symbols/*.nb`)
  plus a `SearchIndex`/`Index`/`SpellIndex`. This strongly suggests the
  build tool *did* do something useful with the reference pages despite
  the confusing terminal output/return value — this directory (if it
  still exists locally, or by re-running the build) is very likely the
  fastest way to see what a "properly built" reference page should
  actually look like, and to diff against the current source `.nb` files
  to figure out what transformation is missing.

**Next steps for whoever picks this up**:
1. Add a `Categorization` section to `Guides/Knoodle.nb`
   (`"Entity Type" -> "Guide"`, `"Paclet Name" -> "Knoodle"`,
   `"URI" -> "Knoodle/guide/Knoodle"` or similar — verify the exact
   convention against a real guide page's *source* form if one can be
   found, not a built one like `WSMLink.nb` was).
2. Re-run `PacletDocumentationBuild` and see if it now proceeds past the
   Guide page and actually processes the reference pages.
3. Inspect the `build/` output directory for the already-processed
   versions from the earlier attempt — compare against
   `Documentation/English/ReferencePages/Symbols/*.nb` to see exactly what
   changed structurally.
4. Re-verify in a live front-end session (same check as before: `?symbol`
   → "Documentation → Local" → does the Categorization section render
   collapsed now).

This was deliberately deferred (explicit user decision) rather than chased
further, since the functionally important part — `?symbol` correctly
resolving to a real, correct reference page — was already confirmed
working, and this remaining issue is purely cosmetic.

## Content reference for filling out the reference pages

The three existing reference pages are intentionally skeletal (one option
mentioned, one minimal example each, matching an explicit "skeletal
documentation" scope for this pass). `/markdown-docs/*.md` in this repo
contains **skeletal-but-feature-complete** Markdown documentation for
`KnoodleDraw`, `KnoodleSimplify`, `KnoodleIdentify`, and `KnotSymbol` —
full option tables, all input formats, known implementation pitfalls/
gotchas found the hard way (with enough detail to explain *why*, not just
*what*), and multiple worked examples per function. Written from the
session that built these functions, specifically so a future Claude
session (with less standing context) has a single, dense source of truth
to draw on when writing the real "Details and Options" / "Examples"
sections of the Mathematica reference pages, without needing to
re-derive everything from the C++ source and WL package source again from
scratch.

`PlanarDiagramComplex` does not yet have its own reference page or a
dedicated markdown file — it's covered in reasonable depth inside
`markdown-docs/KnoodleSimplify.md` (as `KnoodleSimplify`'s return type),
which may be sufficient, or may warrant promoting to its own page/file
later if it ends up needing more standalone treatment (e.g. if more
functions start returning/consuming it directly).
