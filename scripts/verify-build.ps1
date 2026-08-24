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
Write-Host 'PDF HarfBuzz subset build verification passed.'
