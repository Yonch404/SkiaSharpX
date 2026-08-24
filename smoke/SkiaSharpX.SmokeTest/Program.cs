using SkiaSharp;

if (args.Length != 2)
{
    Console.Error.WriteLine("Usage: SkiaSharpX.SmokeTest <font.ttf> <output.pdf>");
    return 2;
}

var fontPath = Path.GetFullPath(args[0]);
var pdfPath = Path.GetFullPath(args[1]);

if (!File.Exists(fontPath))
{
    Console.Error.WriteLine($"Font does not exist: {fontPath}");
    return 3;
}

var fontBytes = new FileInfo(fontPath).Length;
if (fontBytes < 10 * 1024 * 1024)
{
    Console.Error.WriteLine($"Smoke-test font is unexpectedly small ({fontBytes} bytes). The download may have returned a Git LFS pointer or error page.");
    return 4;
}

Directory.CreateDirectory(Path.GetDirectoryName(pdfPath)!);

using var typeface = SKTypeface.FromFile(fontPath);
if (typeface is null)
{
    Console.Error.WriteLine("SKTypeface.FromFile returned null.");
    return 5;
}

using var font = new SKFont(typeface, 34f);
using var paint = new SKPaint
{
    IsAntialias = true,
    Color = SKColors.Black
};

using (var output = File.Create(pdfPath))
using (var document = SKDocument.CreatePdf(output))
{
    if (document is null)
    {
        Console.Error.WriteLine("SKDocument.CreatePdf returned null.");
        return 6;
    }

    var canvas = document.BeginPage(595f, 842f);
    canvas.Clear(SKColors.White);

    // Deliberately use only a tiny glyph set from a very large CJK TTF.
    canvas.DrawText("SkiaSharpX PDF 字体子集测试 123", 48f, 100f, SKTextAlign.Left, font, paint);
    canvas.DrawText("中文：你好，世界。", 48f, 155f, SKTextAlign.Left, font, paint);

    document.EndPage();
    document.Close();
}

var pdfBytes = new FileInfo(pdfPath).Length;
var ratio = (double)pdfBytes / fontBytes;

Console.WriteLine($"Font: {fontBytes:N0} bytes");
Console.WriteLine($"PDF:  {pdfBytes:N0} bytes");
Console.WriteLine($"PDF/font ratio: {ratio:P2}");

// This test is intentionally generous. A successful CJK subset should be far
// smaller than these limits, while a full embedded 20+ MB TTF should exceed them.
const long absoluteLimit = 2_500_000;
const double ratioLimit = 0.15;

if (pdfBytes >= absoluteLimit || ratio >= ratioLimit)
{
    Console.Error.WriteLine(
        $"PDF is too large for the tiny glyph set. Expected < {absoluteLimit:N0} bytes " +
        $"and < {ratioLimit:P0} of the source font. Font subsetting may not be active.");
    return 10;
}

Console.WriteLine("PDF subset smoke test passed.");
return 0;
