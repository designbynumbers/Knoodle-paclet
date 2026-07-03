PacletObject[<|
  "Name" -> "Knoodle",
  "Version" -> "0.0.1",
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
    (* KLUT lookup tables (platform-independent) -- a directory asset the Kernel
       passes to knoodleidentify via --data-dir. *)
    {"Asset", "Root" -> "Resources", "Assets" -> {{"KlutData", "Klut"}}}
  }
|>]
