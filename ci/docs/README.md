# Documentation generators

One `wolframscript` generator per reference page. Each script rebuilds its
notebook **from scratch** — authoring cells (Categorization, Usage, Notes,
options table) plus examples whose Input/Output pairs are **genuinely
evaluated** at generation time — and saves it into
`Documentation/English/ReferencePages/Symbols/` via a front-end
`NotebookSave` (so the file gets the canonical `.nb` headers and outline
cache).

| Script | Page |
|---|---|
| `gen-knoodledraw-nb.wls` | `KnoodleDraw.nb` |
| `gen-knoodlesimplify-nb.wls` | `KnoodleSimplify.nb` |
| `gen-knoodleidentify-nb.wls` | `KnoodleIdentify.nb` |
| `gen-knotsymbol-nb.wls` | `KnotSymbol.nb` |
| `gen-drawpd-gallery.wls` | `Resources/ExampleData/DrawPDGallery/*.png` (assets, not a page) |

`pd-explainer.wls` holds the shared PD-code explainer cells (a labeled,
oriented 5_2 with its code and a row walkthrough) spliced into the Examples
of all three function pages — edit it once, regenerate all three.

Run from anywhere:

    wolframscript -file ci/docs/gen-knoodlesimplify-nb.wls

**Exception — `gen-drawpd-gallery.wls`, the one script that EVALUATES
KnotTheory's DrawPD** (to render the committed
`Resources/ExampleData/DrawPDGallery` PNGs). DrawPD's convergence is
badly environment-sensitive: its circle packing iterates to *exact*
convergence (`NestWhile[..., Unequal]`), and in most kernel environments
the numerics drift complex (`CompiledFunction::cfsa` storms,
`ArcCos[1.+0.*I]`), so diagrams from ~10 crossings up loop apparently
forever while tiny ones still draw — pre-warms, load order, and kernel
mode (`wolframscript`, `wolfram -script`, stdin REPL, even desktop
notebook kernels) all failed at one time or another; one long-lived
service kernel happened to work all day (observed 2026-07-04, WL 15.0,
KnotTheory of 2024-10-29). Consequences:

- `gen-drawpd-gallery.wls` self-checks with a time-constrained 10-crossing
  render and exits loudly if the session is unusable. Regenerate the
  gallery rarely, in whatever kernel passes the self-check, and commit the
  PNGs.
- `gen-knoodledraw-nb.wls` deliberately **never evaluates DrawPD**: the
  comparisons display the committed gallery PNGs, and the drop-in example
  evaluates `KnoodleDraw` on a KnotTheory `PD[X[...]]` object while only
  *displaying* the equivalent DrawPD call. It still needs KnotTheory`
  installed (so those input cells parse into the right context), but runs
  under plain `wolframscript` like the other page generators.

Requirements: a local Wolfram installation with a front end (`UsingFrontEnd`
does the save), and working Knoodle binaries — either an installed Knoodle
paclet or the dev fallback (a sibling `~/Knoodle` checkout with built
`tools/`; see `assetOr` in `Kernel/Knoodle.wl`). The scripts
`PacletDirectoryLoad` the repo so `AssetLocation` lookups in examples (e.g.
the bundled `Resources/ExampleData` hard-unknot diagrams) resolve exactly as
they would on an installed paclet.

Notes:

- **Re-running changes the committed notebooks**: timings (`AbsoluteTiming`
  outputs) and any layout produced through `--randomize-projection` (whose
  randomness lives in the C++ tools, not WL's `SeedRandom`) will differ
  between runs. Regenerate deliberately — after a Kernel or upstream change
  that affects outputs — and review the diff, not habitually.
- `gen-knoodledraw-nb.wls` also exports each graphical example output as a
  PNG under `$TemporaryDirectory/knoodle-doc-review/` for eyeballing.
- After regenerating, validate with
  `PacletTools`PacletDocumentationBuild["<repo>", "<tmp dir>"]` — expect
  `SuccessfulFilesCount -> 5`, `FailedFilesCount -> 0`.
