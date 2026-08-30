using System.Runtime.Versioning;
using Avalonia.Media.Imaging;
using DrawingIcon = System.Drawing.Icon;
using DrawingImageFormat = System.Drawing.Imaging.ImageFormat;

namespace ModMenu.Studio;

/// <summary>
/// Same Steam cache + exe-icon path as UE4SS Installer.
/// </summary>
public static class GameIconLoader
{
    public static Bitmap? Load(string? exePath, string? steamArtworkPath)
    {
        var fromSteam = TryLoadFile(steamArtworkPath);
        if (fromSteam is not null)
            return fromSteam;

        if (OperatingSystem.IsWindows() && !string.IsNullOrEmpty(exePath))
            return LoadFromExe(exePath);

        return null;
    }

    [SupportedOSPlatform("windows")]
    private static Bitmap? LoadFromExe(string exePath)
    {
        try
        {
            using var icon = DrawingIcon.ExtractAssociatedIcon(exePath);
            if (icon is null)
                return null;

            using var bitmap = icon.ToBitmap();
            using var stream = new MemoryStream();
            bitmap.Save(stream, DrawingImageFormat.Png);
            stream.Position = 0;
            return new Bitmap(stream);
        }
        catch
        {
            return null;
        }
    }

    private static Bitmap? TryLoadFile(string? path)
    {
        if (string.IsNullOrEmpty(path) || !File.Exists(path))
            return null;

        try
        {
            return new Bitmap(path);
        }
        catch
        {
            return null;
        }
    }
}
