# DrawPD gallery

Pre-rendered drawings made with the `DrawPD` function of the **KnotTheory`**
package (Bar-Natan, Morrison et al., https://katlas.org/wiki/KnotTheory;
DrawPD's manual page is https://katlas.org/wiki/Drawing_Planar_Diagrams).
They are bundled as example data for the `KnoodleDraw` documentation's
side-by-side comparisons, so those examples display DrawPD's output even for
users who do not have KnotTheory` installed.

Regenerate with `ci/docs/gen-drawpd-gallery.wls` (the one doc generator that
does require KnotTheory`), by `Get`-ing it in a **full interactive kernel**
— not `wolframscript`/`wolfram -script`, where KnotTheory's on-demand
DrawPD load comes up broken and hangs; see the script header. The exact PD
codes live in that script.

- `millett-drawpd.png` — "the Millett unknot", the 10-crossing hard unknot
  used as the worked example on DrawPD's own manual page, drawn with the
  page's recommended `Gap -> 0.03`.
- `granny-drawpd.png` — the granny knot (trefoil # trefoil) as a single
  6-crossing PD code: DrawPD terminates on this non-prime diagram but
  crushes the two summands into tiny corner tangles — the documentation's
  "diagrams which are not prime" robustness example.
- `gauss50-drawpd.png` — the unsimplified z-projection of a Gaussian random
  50-gon (`SeedRandom[2026]`, 21 crossings) with its three R1 monogons
  removed (15 crossings) and *nothing else* simplified. The monogon removal
  is required: DrawPD's circle-packing step does not terminate on diagrams
  containing a kink (verified empirically across a dozen random
  projections; the reduction is done in the generator script).
- `13a1-drawpd.png` — the alternating 13-crossing knot 13a_1, PD code as
  published by KnotInfo (C. Livingston and A. H. Moore,
  https://knotinfo.org).

All three PNGs are exported at `ImageSize -> 260`, `ImageResolution -> 144`
(520 px wide, crisp at the documentation's display size).
