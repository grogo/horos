# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Horos is a macOS DICOM medical image viewer (a fork of OsiriX), written mostly in Objective-C / Objective-C++ (`.m` / `.mm`) with C++ third-party libraries (VTK, ITK, DCMTK, GDCM). Current version and build number live in `Horos/Horos.xcconfig`; release notes in `Changelog.md` (Keep a Changelog format — update it for user-visible changes).

## Build

Prerequisites: `cmake`, `pkg-config` (in `PATH` or `/opt/local/bin`), and `git-lfs` (needed for VTK). A full build takes 5–30 minutes because all third-party libraries are compiled from source.

```sh
git submodule update --init --recursive   # third-party sources (ITK, VTK, DCMTK, GDCM, OpenSSL, ...)
make                                       # = xcodebuild -project Horos.xcodeproj -target Horos (Release)
make clean                                 # rm -rf ./build
```

Or open `Horos.xcodeproj` in Xcode and build the `Horos` scheme. Individual dependencies can be built on their own via their targets/schemes (`VTK`, `ITK`, `DCMTK`, `GDCM`, `OpenSSL`, `CharLS`, `OpenJPEG`, `Grok`, `FeedbackReporter`, `Unzip Binaries`), e.g. `xcodebuild -project Horos.xcodeproj -target DCMTK`.

- `Config.xcconfig` sets the signing team, the single target architecture (`ARCHS = arm64` or `x86_64` — only one at a time is supported), and the deployment target (macOS 11.0).
- With an empty `DEVELOPMENT_TEAM`, the `Makefile` passes `CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual` (ad-hoc signing); the project's target-level `"Apple Development"` identity otherwise overrides the xcconfig. Building from the Xcode GUI without a team needs the same overrides.
- The `Makefile` exports `CMAKE_POLICY_VERSION_MINIMUM=3.5` because CMake 4.x rejects old submodules (e.g. CharLS). Set it yourself when invoking `xcodebuild` directly.
- Third-party CMake scripts must not pick up Homebrew packages (`/opt/homebrew`): its OpenSSL 3 headers break DCMTK, which expects the bundled OpenSSL 1.1.1, and linked dylibs would make the app depend on Homebrew. DCMTK's script excludes them via `CMAKE_IGNORE_PATH` (the other scripts only exclude MacPorts' `/opt/local`), and OpenJPEG/Grok build with `BUILD_CODEC=OFF` (Horos only needs `libopenjp2.a`).
- There is no active unit-test target; `Horos/Unit Tests/` contains legacy test sources not wired into any scheme.

## Third-party library build pipeline

Each submodule (top-level `ITK/`, `VTK/`, `DCMTK/`, `GDCM/`, `OpenSSL/`, `CharLS/`, `OpenJPEG/`, `Grok/`, `FeedbackReporter/`) is built by an Xcode target that runs scripts in `Horos/Scripts/<Lib>/`:

- `CMake.sh` (or `Config.sh` for OpenSSL) configures into `$TARGET_TEMP_DIR/CMake` and installs to `$TARGET_TEMP_DIR/Install`. It caches a hash of the script + build environment in `.cmakehash` and skips reconfiguration if unchanged — editing the script forces a reconfigure.
- `Make.sh` compiles and copies results into `$BUILT_PRODUCTS_DIR/<Lib>`; it is skipped if that directory exists without an `.incomplete` marker. Delete `build/` (or that directory) to force a rebuild.
- The `Submodules` target runs `git submodule update --init --recursive` on every build, resetting each submodule to the commit recorded in the superproject. To change a library version, check out the new tag in the submodule **and `git add <submodule>`** before building, or the build silently uses the old version.
- **Local fixes to submodule sources are not committed in the submodules.** They live as `Horos/Scripts/<Lib>/compile-fixes.patch` (currently VTK, ITK, DCMTK) and are applied by `CMake.sh` with `patch --forward`. To change third-party code, update the patch file rather than relying on edits inside the submodule (submodules are configured `ignore = dirty`).

`Binaries/` holds zipped prebuilt assets (Weasis, report templates, Core Data model history, etc.) extracted by the `Unzip Binaries` target (`Horos/Scripts/Horos/Unzip.sh`). `Binaries/dcmtk-source/` is a separate in-tree copy of DCMTK sources, distinct from the `DCMTK/` submodule; the Xcode project still compiles a few files from it directly (mainly the `dcmjpls` JPEG-LS codec).

## Architecture

- `Horos/Sources/` — the application (~700 files, flat directory). Key hubs:
  - `AppController` — app delegate, global startup, DICOM listener/services.
  - `BrowserController` (+ categories `+Sources`, `+Activity`, `DCMTKCategory`) — the database browser window.
  - `DicomDatabase` (+ `+Scan`, `+Routing`, `+Clean`, `+DCMTK`) — Core Data–backed local DICOM database; models in `Horos/Models/` (`OsiriXDB_DataModel.xcdatamodeld`, plus a mapping model for migrations). Old model versions come from `Binaries/DB_Previous_Models.zip`.
  - `DicomFile` / `DCMPix` — file parsing and per-image pixel data; `DCMView` — 2D image view; `ViewerController` — 2D viewer window.
  - `VRController`, `MPR*`, `CPR*`, etc. — 3D/MPR viewers built on VTK; ITK used for segmentation/filters (`MSRG/` region growing).
  - `WebPortal*` — embedded web server (built on `cocoahttpserver/`) with its own Core Data model `WebPortalDB.xcdatamodeld`.
  - `PluginManager` / `PluginFilter` — plugin loading and the base class plugins subclass.
  - `*DCMTKCategory.mm` files isolate DCMTK (C++) usage behind Objective-C categories.
- `DCM Framework/` — Objective-C DICOM object model (`DCMObject`, `DCMAttribute`, transfer syntaxes, JPEG/JPEG2000 pixel codecs), built as the `DCM` target.
- `Nitrogen/` — shared Cocoa utility library (N2* classes) used across the app.
- `API/` + `Horos/Scripts/Horos/API-Headers.pl` / `API.sh` — the `API` target produces `Horos.framework`, whose public headers are generated from `Nitrogen/Sources` and `Horos/Sources`. `API.sh` also emits copies named `HorosAPI`, `OsiriXAPI`, `OsiriX Headers`, `HorosDCM` because existing plugins hard-link against those names — keep this in mind when renaming or removing public classes/methods, since plugins depend on the binary API.
- `Decompress/` — helper executable for decompressing images in a separate process.
- `Preference Panes/`, `DICOMPrint/`, `DicomImporter/`, `Papyrus3/`, `NIfTI_Library/`, `OpenSSL` etc. — supporting modules and legacy libraries compiled into the app.

## Localization

`LocalizationExtract.sh` and `LocalizationGenerate.sh` at the repo root extract/generate `.strings` files; localized resources are in `Horos/Resources/*.lproj`.
