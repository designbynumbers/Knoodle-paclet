# Knoodle paclet

A Wolfram Language paclet that makes [Knoodle](https://github.com/HenrikSchumacher/Knoodle)
— fast knot/link diagram simplification, drawing, and identification — installable
and usable directly from Mathematica on **macOS, Linux, and Windows**, with no heavy
dependencies. The goal: a Windows user can `PacletInstall` this and *just use Knoodle*.

## Status

Early scaffold. Not yet installable. See the design discussion in the upstream
Knoodle repo.

## What it exposes

Three functions, in true Mathematica style — one symbol each, with representation
conversion hidden behind the usual templates:

- **`KnoodleDraw`** — draw a diagram (intended as a cleaner drop-in for
  KnotTheory\`'s `DrawPD`), rendering to a native `Graphics` object.
- **`KnoodleSimplify`** — simplify a diagram, returning PD codes.
- **`KnoodleIdentify`** — identify a diagram against Knoodle's knot lookup table.

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

## License

MIT — see [LICENSE](LICENSE). Bundled Knoodle components remain under their own
MIT license (© 2024 HenrikSchumacher), whose notice is preserved in the packaged
paclet.
