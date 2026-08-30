namespace ModMenu.Harness;

/// <summary>
/// Steam library-cache icon paths. Bitmap load stays in Studio (same as UE4SS Installer).
/// </summary>
public static class GameArtwork
{
    public static string? FindSteamArtwork(string? steamPath, string? appId)
    {
        if (string.IsNullOrWhiteSpace(steamPath) || string.IsNullOrWhiteSpace(appId))
            return null;

        var cacheRoot = Path.Combine(steamPath, "appcache", "librarycache");
        var appDir = Path.Combine(cacheRoot, appId);
        if (Directory.Exists(appDir))
        {
            var ranked = RankArtwork(SafeEnumerate(appDir, "*.jpg")
                .Concat(SafeEnumerate(appDir, "*.png")));
            if (ranked is not null)
                return ranked;
        }

        foreach (var candidate in new[]
                 {
                     Path.Combine(cacheRoot, $"{appId}_icon.jpg"),
                     Path.Combine(cacheRoot, $"{appId}.jpg"),
                     Path.Combine(cacheRoot, appId, "icon.jpg"),
                     Path.Combine(cacheRoot, appId, "icon.png")
                 })
        {
            if (File.Exists(candidate))
                return candidate;
        }

        return null;
    }

    internal static string? RankArtwork(IEnumerable<string> files)
    {
        string? icon = null;
        string? other = null;

        foreach (var file in files)
        {
            var name = Path.GetFileName(file);
            if (name.Contains("icon", StringComparison.OrdinalIgnoreCase))
            {
                icon = file;
                break;
            }

            if (name.StartsWith("library", StringComparison.OrdinalIgnoreCase)
                || name.StartsWith("header", StringComparison.OrdinalIgnoreCase)
                || name.StartsWith("logo", StringComparison.OrdinalIgnoreCase)
                || name.StartsWith("hero", StringComparison.OrdinalIgnoreCase))
                continue;

            other ??= file;
        }

        return icon ?? other;
    }

    private static IEnumerable<string> SafeEnumerate(string directory, string pattern)
    {
        try
        {
            return Directory.EnumerateFiles(directory, pattern);
        }
        catch
        {
            return [];
        }
    }
}
