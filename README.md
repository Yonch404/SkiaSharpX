# SkiaSharpX

SkiaSharpX is an **unofficial custom native build** of SkiaSharp for this project's runtime use. It keeps the official SkiaSharp managed NuGet package unchanged and only replaces the Windows x64 native `libSkiaSharp.dll`.

## Baseline

- SkiaSharp: `4.151.1`
- Upstream tag: `v4.151.1`
- Skia milestone: `m151`
- Expected Skia submodule SHA: `bdd0c3a8eaba1afa7148f02bba3a07f94e682847`
- SkiaSharpX revision: `x1`
- Target: Windows x64
- Runtime filename: `libSkiaSharp.dll`

The official Windows build already sets:

```text
skia_use_harfbuzz=false
skia_use_icu=false
```

SkiaSharpX intentionally keeps those settings and adds only:

```text
skia_pdf_subset_harfbuzz=true
skia_use_system_harfbuzz=false
```

This enables HarfBuzz font subsetting in Skia's PDF backend without switching the application's normal text stack to HarfBuzz shaping and without enabling ICU. HarfBuzz is built from Skia's vendored source, so the resulting runtime does not require a separate HarfBuzz DLL for this PDF-subset feature.

## Build with GitHub Actions

Open:

**Actions → Build SkiaSharpX → Run workflow**

The workflow:

1. Checks out this repository.
2. Checks out the exact official SkiaSharp `v4.151.1` source and all submodules.
3. Verifies that the Skia submodule is exactly the expected commit.
4. Installs the upstream-pinned LLVM toolchain and Ninja.
5. Builds only the Windows x64 `libSkiaSharp` native target with the PDF subset flags.
6. Verifies the effective GN arguments and that `SK_PDF_USE_HARFBUZZ_SUBSET` reached the generated Ninja build graph.
7. Runs a real PDF smoke test with a large open-source CJK TrueType font and requires the output PDF to remain small.
8. Uploads the replacement native DLL as an Actions artifact.

The artifact name is:

```text
SkiaSharpX-4.151.1-x1-win-x64
```

and contains:

```text
libSkiaSharp.dll
libSkiaSharp.pdb
build-info.txt
```

If the workflow is triggered by a Git tag such as `v4.151.1-x1`, it also creates a GitHub Release containing the same files.

## Use in the application

Keep the official package reference:

```xml
<PackageReference Include="SkiaSharp" Version="4.151.1" />
```

Build or publish the application normally, then replace the Windows x64 native file with the SkiaSharpX build. Depending on the project/publish layout, this is usually either next to the application assemblies or under a runtime-native directory such as:

```text
runtimes/win-x64/native/libSkiaSharp.dll
```

The important part is that the native file loaded at runtime is the SkiaSharpX `libSkiaSharp.dll`.

**Do not rename the DLL.** Managed SkiaSharp continues to load the normal `libSkiaSharp` native library name.

A SkiaSharpX `4.151.1-x*` binary is intended to be paired with managed SkiaSharp `4.151.1`.

## Versioning

SkiaSharpX follows the upstream version and adds a small local revision:

```text
4.151.1-x1
4.151.1-x2
...
```

When moving to another stable SkiaSharp release, update these values in `.github/workflows/build.yml`:

```text
SKIASHARP_VERSION
SKIASHARP_REF
EXPECTED_SKIA_SHA
SKIASHARPX_REVISION
```

The verification step is intentionally strict. If upstream changes its GN rules, file layout, or Skia submodule unexpectedly, the workflow should fail instead of silently publishing a native binary with different behavior.

## Local verification

The GitHub Actions workflow is the canonical build environment. If you build locally, use the same upstream tag, LLVM version expected by that tag, and these GN overrides:

```text
skia_pdf_subset_harfbuzz=true skia_use_system_harfbuzz=false
```

After the build, run:

```powershell
./scripts/verify-build.ps1 -SkiaSharpRoot <path-to-SkiaSharp>
```

## Scope and attribution

This repository does not maintain a fork of SkiaSharp managed code and does not publish a custom NuGet package. Its deliverable is a replacement native `libSkiaSharp.dll`.

SkiaSharp and Skia remain subject to their upstream licenses and trademarks. SkiaSharpX is not an official Microsoft, Mono, Google, Skia, or SkiaSharp distribution.
