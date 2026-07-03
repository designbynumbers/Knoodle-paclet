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

Run from anywhere:

    wolframscript -file ci/docs/gen-knoodledraw-nb.wls

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
