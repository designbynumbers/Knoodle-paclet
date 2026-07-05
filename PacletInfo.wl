PacletObject[<|
  "Name" -> "Knoodle",
  "Version" -> "0.9.0",
  "WolframVersion" -> "13.0+",
  "Description" -> "Knot and link diagram drawing, simplification, and identification, powered by the Knoodle CLI tools.",
  "Creator" -> "Jason Cantarella",
  "License" -> "MIT",
  "Extensions" -> {
    {"Kernel", "Root" -> "Kernel", "Context" -> "Knoodle`"},
    {"Documentation", "Language" -> "English", "MainPage" -> "Guides/Knoodle"},
    (* Per-platform CLI executables, looked up at runtime via
       PacletObject["Knoodle"]["AssetLocation", "knoodledraw"] etc. -- no
       hard-coded paths, and the SystemID field selects the right binary. *)
    {"Asset", "Root" -> "Resources/MacOSX-ARM64", "SystemID" -> "MacOSX-ARM64",
      "Assets" -> {
        {"knoodledraw", "knoodledraw"},
        {"knoodlesimplify", "knoodlesimplify"},
        {"knoodleidentify", "knoodleidentify"}}},
    {"Asset", "Root" -> "Resources/Windows-x86-64", "SystemID" -> "Windows-x86-64",
      "Assets" -> {
        {"knoodledraw", "knoodledraw.exe"},
        {"knoodlesimplify", "knoodlesimplify.exe"},
        {"knoodleidentify", "knoodleidentify.exe"}}},
    {"Asset", "Root" -> "Resources/Linux-x86-64", "SystemID" -> "Linux-x86-64",
      "Assets" -> {
        {"knoodledraw", "knoodledraw"},
        {"knoodlesimplify", "knoodlesimplify"},
        {"knoodleidentify", "knoodleidentify"}}},
    (* Platform-independent data: the KLUT lookup tables (a directory asset
       the Kernel passes to knoodleidentify via --data-dir), and the hard-
       unknot example diagrams used by the KnoodleSimplify documentation
       (Burton et al. 2023, Applebaum et al. 2025 -- see the READMEs there).
       Unlike the binaries and KLUT data, ExampleData lives in the source
       repo itself and ships with every build. *)
    {"Asset", "Root" -> "Resources", "Assets" -> {
      {"KlutData", "Klut"},
      {"HardUnknots", "ExampleData/HardUnknots"},
      {"VeryHardUnknots", "ExampleData/VeryHardUnknots"},
      {"DrawPDGallery", "ExampleData/DrawPDGallery"}}}
  }
|>]
