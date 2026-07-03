#!/usr/bin/env wolframscript
(* ::Package:: *)

(* package-paclet.wls STAGE OUT
 *
 * Builds a .paclet from an already-assembled staging directory STAGE (which
 * must contain PacletInfo.wl, Kernel/, Documentation/ (source authoring
 * notebooks), and Resources/ with per-SystemID binary dirs + a Klut/ data
 * dir), placing the finished archive in OUT. Prints the .paclet path on the
 * last line of stdout.
 *
 * Runs LOCALLY under the caller's own Wolfram license (no on-demand
 * entitlement / Service Credits) -- it is invoked by both ci/build-paclet.sh
 * (dev) and ci/release.sh (release). PacletBuild does the documentation build
 * (source authoring notebooks -> in-product notebooks + search index) itself.
 *
 * Before building, the staged PacletInfo.wl's "Asset" extensions are filtered
 * down to the platforms actually present under Resources/ -- so a Mac-only dev
 * staging doesn't trip PacletBuild's "extension root does not name an existing
 * directory" check on the Windows/Linux asset roots, while a full release
 * staging (all three) keeps them all. Non-platform extensions (Kernel,
 * Documentation, and the SystemID-less Klut asset) are always kept.
 *)

If[Length[Rest[$ScriptCommandLine]] < 2,
  Print["usage: package-paclet.wls STAGE OUT"]; Exit[1]];
{stage, out} = Rest[$ScriptCommandLine][[1 ;; 2]];

Needs["PacletTools`"];

piPath = FileNameJoin[{stage, "PacletInfo.wl"}];
info   = Get[piPath];
assoc  = First[info];

(* SystemID subdirectories actually staged under Resources/ (everything but Klut). *)
resDir = FileNameJoin[{stage, "Resources"}];
presentSIDs = Select[FileNameTake /@ Select[FileNames["*", resDir], DirectoryQ], # =!= "Klut" &];
Print["Staged platforms: ", presentSIDs];

keepExtension[ext_] := With[
  {sid = Lookup[Association @ Rest[ext], "SystemID", None]},
  sid === None || MemberQ[presentSIDs, sid]];

filtered = Select[assoc["Extensions"], keepExtension];
Put[PacletObject[Append[assoc, "Extensions" -> filtered]], piPath];

res = PacletBuild[stage, out];
If[Head[res] =!= Success,
  Print["PacletBuild FAILED: ", res]; Exit[1]];

archive = res["PacletArchive"];
If[! StringQ[archive] || ! FileExistsQ[archive],
  Print["PacletBuild returned no archive: ", res]; Exit[1]];

Print["Packaged ", Length[Normal[res["PacletManifest"]]["Files"]], " files."];
(* Last line = the archive path, for the calling shell script to capture. *)
Print[archive];
