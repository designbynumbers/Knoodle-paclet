# Hard unknot diagrams

The 21 hard diagrams of the unknot catalogued in:

> Benjamin A. Burton, Hsien-Chih Chang, Maarten Löffler, Arnaud de Mesmay,
> Clément Maria, Saul Schleimer, Eric Sedgwick, and Jonathan Spreer,
> "Hard Diagrams of the Unknot", *Experimental Mathematics* 33(3), 2023.
> DOI: 10.1080/10586458.2022.2161676, arXiv:2104.14076.

Each `.tsv` is one diagram in Knoodle's native signed PD-code format: one
crossing per row, five tab-separated integers (four 0-based arc labels plus
the crossing handedness ±1). The diagrams were converted from the Gauss
codes published in the paper's Appendix A. File names follow the paper's
own names (Table, Section 2.1), which carry their original attributions —
e.g. `H`/`J` (Henrich–Kauffman), `Culprit` (Kauffman–Lambropoulou),
`Goeritz`, `Monster`, `Thistlethwaite`, `OchiaiI`–`OchiaiIV` (Ochiai; IV due
to Suzuki), `FHW`/`FakeFHW` (Freedman–He–Wang and the paper's "fake"
variant), `TuzunSikora`, `PZ31`/`PZ120`/`PZ138` (Petronio–Zanellati),
`Haken` (Haken's Gordian unknot), and the paper's own hard diagrams
`D28`, `D43`, and `PZ78`.

Every diagram in this directory is the unknot. They are bundled as example
data for the `KnoodleSimplify` documentation.
