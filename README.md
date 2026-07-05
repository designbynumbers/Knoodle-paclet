# Knoodle paclet

A Wolfram Language paclet that makes [Knoodle](https://github.com/HenrikSchumacher/Knoodle)
— fast knot/link diagram simplification, drawing, and identification — installable
and usable directly from Mathematica on **macOS, Linux, and Windows**, with no heavy
dependencies. The goal: a Windows user can `PacletInstall` this and *just use Knoodle*.

## Installation

You need Mathematica (or Wolfram) **13.0 or later** on one of the supported
platforms: **macOS (Apple silicon)**, **Linux (x86-64)**, or **Windows
(x86-64)**. Everything else — the Knoodle command-line tools and the knot
lookup tables — is bundled inside the paclet; there is nothing else to
install.

1. Go to this repository's
   [**Releases** page](https://github.com/designbynumbers/Knoodle-paclet/releases)
   and, under the newest release, download the `Knoodle-<version>.paclet`
   file (any browser; it's a single file).
2. Open Mathematica and evaluate, in a notebook:

   ```wolfram
   PacletInstall["/path/to/Knoodle-<version>.paclet"]
   ```

   replacing the path with wherever your browser saved the file (on macOS
   typically `"~/Downloads/Knoodle-0.9.0.paclet"`). You can also skip the
   manual download and hand `PacletInstall` the release asset's URL
   directly — right-click the file on the Releases page and copy its link.
3. Check that it works:

   ```wolfram
   Needs["Knoodle`"]
   KnoodleDraw["Trefoil"]
   ```

   which should draw a trefoil knot diagram.

The documentation is installed with the paclet: open Mathematica's
Documentation Center (Help ▸ Wolfram Documentation) and search for
**Knoodle** — the guide page links every function, and each reference page
has worked examples you can evaluate in place. If the search doesn't find
it right after installing, restart Mathematica once.

To upgrade, install the newer release the same way (`PacletInstall` with
`ForceVersionInstall -> True` if the version number hasn't changed). To
remove the paclet entirely:

```wolfram
PacletUninstall["Knoodle"]
```

Developers who want a bleeding-edge build from an unreleased Knoodle
checkout can use `ci/build-paclet.sh` instead (requires `clang`,
`wolframscript`, and a sibling Knoodle checkout — see the script header).

## What it exposes

Three functions, in true Mathematica style — one symbol each, with representation
conversion hidden behind the usual templates:

- **`KnoodleDraw`** — draw a diagram (a more robust drop-in for
  KnotTheory\`'s `DrawPD`), rendering to a native `Graphics` object.
- **`KnoodleSimplify`** — simplify a diagram, returning a
  `PlanarDiagramComplex` (its prime connect-sum factors, with link
  components tracked by color) that the other two functions accept directly.
- **`KnoodleIdentify`** — identify a diagram against Knoodle's knot lookup
  table (KLUT, complete through 13 crossings).

Inputs are normalized on the Wolfram side from the forms people actually have —
`KnotData`, KnotTheory\`'s `PD[X[...]]` / `PD[Xp[...], Xn[...]]`, DT/Dowker codes,
Gauss codes, and sampled space curves / polygons — into Knoodle's native input.

## Relationship to Knoodle

This repository is **downstream** of, and packages, the upstream Knoodle library
(`github.com/HenrikSchumacher/Knoodle`, MIT). It consumes the Knoodle CLI tools
(`knoodledraw`, `knoodlesimplify`, `knoodleidentify`) and the knot-lookup-table
data, builds per-platform binaries, and bundles them into an installable paclet.

Distribution/CI machinery lives here, deliberately kept out of the core library.
This is a sibling to the Homebrew tap: another distribution channel for Knoodle.

It is a lightweight alternative to `KnoodleLink`, which exposes far more but carries
large dependencies and is not maintained cross-platform.

## License and citation

MIT — see [LICENSE](LICENSE). Bundled Knoodle components remain under their own
MIT license (© 2024 HenrikSchumacher), whose notice is preserved in the packaged
paclet.

Knoodle is written by Henrik Schumacher and Jason Cantarella; this paclet is
maintained by Jason Cantarella. If you use the Knoodle paclet in academic
research, please cite it as described in
[`CITATION.cff`](https://github.com/HenrikSchumacher/Knoodle/blob/main/CITATION.cff)
on the main Knoodle repository.
