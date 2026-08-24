param(
    [Parameter(Mandatory = $true)]
    [string] $SkiaSharpRoot,

    [string] $ExpectedSkiaSha = "bdd0c3a8eaba1afa7148f02bba3a07f94e682847"
)

$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $SkiaSharpRoot).Path
$skiaRoot = Join-Path $root 'externals\skia'
$outDir = Join-Path $skiaRoot 'out\windows\x64'
$argsFile = Join-Path $outDir 'args.gn'
$dll = Join-Path $root 'output\native\windows\x64\libSkiaSharp.dll'

if (!(Test-Path $skiaRoot)) {
    throw "Skia submodule directory was not found: $skiaRoot"
}

$actualSkiaSha = (git -C $skiaRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the Skia submodule commit.'
}
if ($actualSkiaSha -ne $ExpectedSkiaSha) {
    throw "Unexpected Skia commit. Expected $ExpectedSkiaSha but got $actualSkiaSha"
}

if (!(Test-Path $argsFile)) {
    throw "GN args file was not found: $argsFile"
}

$args = Get-Content $argsFile -Raw

$required = @{
    'skia_use_harfbuzz'            = 'false'
    'skia_use_icu'                 = 'false'
    'skia_pdf_subset_harfbuzz'     = 'true'
    'skia_use_system_harfbuzz'     = 'false'
}

foreach ($entry in $required.GetEnumerator()) {
    $name = [regex]::Escape($entry.Key)
    $value = [regex]::Escape($entry.Value)
    if ($args -notmatch "(?m)^\s*$name\s*=\s*$value\s*$") {
        Write-Host '----- args.gn -----'
        Write-Host $args
        throw "Expected GN argument '$($entry.Key)=$($entry.Value)' was not found."
    }
}

if (!(Test-Path $dll)) {
    throw "Built native library was not found: $dll"
}


# Verify ThinLTO was added without replacing Skia's normal Release optimization.
# Skia's Windows Release optimize config contributes /O2. SkiaSharpX only adds
# -flto=thin, leaving the upstream optimization level unchanged.
$ninjaFiles = Get-ChildItem -Path $outDir -Filter '*.ninja' -Recurse -File
$ninjaText = ($ninjaFiles | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n"

if ($ninjaText -notmatch [regex]::Escape('-flto=thin')) {
    throw "Required optimization flag '-flto=thin' was not found in the generated Ninja graph."
}

# Confirm at least one generated compile command contains both the upstream /O2
# Release optimization and the custom ThinLTO flag. No O3/LTO-backend override is
# used: lld-link therefore keeps its normal LTO optimization level (O2).
$optimizationOk = $false
foreach ($line in ($ninjaText -split "`r?`n")) {
    $o2 = $line.IndexOf('/O2', [System.StringComparison]::OrdinalIgnoreCase)
    $thin = $line.IndexOf('-flto=thin', [System.StringComparison]::Ordinal)
    if ($o2 -ge 0 -and $thin -ge 0) {
        $optimizationOk = $true
        break
    }
}

if (!$optimizationOk) {
    throw 'Could not confirm a generated compile command with upstream /O2 and ThinLTO enabled.'
}

# The GN PDF target must propagate this define to the generated Ninja graph.
# This is stronger than only checking args.gn.
$defineFound = $false
Get-ChildItem -Path $outDir -Filter '*.ninja' -Recurse -File | ForEach-Object {
    if (!$defineFound) {
        $match = Select-String -Path $_.FullName -SimpleMatch 'SK_PDF_USE_HARFBUZZ_SUBSET' -Quiet
        if ($match) {
            $defineFound = $true
        }
    }
}

if (!$defineFound) {
    throw 'SK_PDF_USE_HARFBUZZ_SUBSET was not found in the generated Ninja build graph.'
}

$item = Get-Item $dll
$hash = (Get-FileHash $dll -Algorithm SHA256).Hash

Write-Host "Skia commit: $actualSkiaSha"
Write-Host "Native DLL:   $($item.FullName)"
Write-Host "DLL size:     $($item.Length) bytes"
Write-Host "DLL SHA256:   $hash"
Write-Host 'PDF HarfBuzz subset + upstream O2 + ThinLTO build verification passed.'
