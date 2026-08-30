namespace ModMenu.Harness;

/// <summary>
/// Resolves non-Engine Binaries/Win64 from a Steam install folder.
/// Copied from UE4SSInstaller (no installer project reference).
/// </summary>
public static class PathDetector
{
    private static readonly HashSet<string> SkipDirectoryNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "Engine",
        "Content",
        "Intermediate",
        "Saved",
        "DerivedDataCache",
        "Movies",
        ".git"
    };

    public static string? FindWin64Directory(string gameInstallPath)
    {
        var startDir = ResolveStartDirectory(gameInstallPath);
        if (startDir is null)
            return null;

        if (IsTargetWin64(startDir))
            return startDir;

        return FindWin64Under(startDir, maxDepth: 8);
    }

    public static string? FindGameExecutable(string win64Path)
    {
        if (string.IsNullOrWhiteSpace(win64Path) || !Directory.Exists(win64Path))
            return null;

        FileInfo[] exes;
        try
        {
            exes = Directory.EnumerateFiles(win64Path, "*.exe")
                .Select(path => new FileInfo(path))
                .Where(info => !IsHelperExecutable(info.Name))
                .ToArray();
        }
        catch
        {
            return null;
        }

        if (exes.Length == 0)
            return null;

        var shipping = exes.FirstOrDefault(info =>
            info.Name.Contains("-Win64-Shipping", StringComparison.OrdinalIgnoreCase));
        if (shipping is not null)
            return shipping.FullName;

        return exes.OrderByDescending(info => info.Length).First().FullName;
    }

    private static bool IsHelperExecutable(string fileName)
    {
        ReadOnlySpan<string> skip =
        [
            "UE4SS", "dwmapi", "crashpad", "EasyAntiCheat", "EOS", "steam_api",
            "UnrealCEF", "CrashReportClient"
        ];

        foreach (var token in skip)
        {
            if (fileName.Contains(token, StringComparison.OrdinalIgnoreCase))
                return true;
        }

        return false;
    }

    private static string? ResolveStartDirectory(string gameInstallPath)
    {
        if (string.IsNullOrWhiteSpace(gameInstallPath))
            return null;

        var full = Path.GetFullPath(gameInstallPath.Trim().Trim('"'));

        if (Directory.Exists(full))
            return full;

        if (File.Exists(full))
        {
            var parent = Path.GetDirectoryName(full);
            return Directory.Exists(parent) ? parent : null;
        }

        return null;
    }

    private static string? FindWin64Under(string directory, int maxDepth)
    {
        var pending = new Queue<(string Path, int Depth)>();
        pending.Enqueue((directory, 0));

        while (pending.Count > 0)
        {
            var (current, depth) = pending.Dequeue();
            if (IsTargetWin64(current))
                return current;

            if (depth >= maxDepth)
                continue;

            IEnumerable<string> children;
            try
            {
                children = Directory.EnumerateDirectories(current);
            }
            catch (Exception)
            {
                continue;
            }

            foreach (var child in children)
            {
                var name = Path.GetFileName(child);
                if (SkipDirectoryNames.Contains(name))
                    continue;

                pending.Enqueue((child, depth + 1));
            }
        }

        return null;
    }

    private static bool IsTargetWin64(string directory)
    {
        var normalized = Normalize(directory);
        if (!normalized.EndsWith("/Binaries/Win64", StringComparison.OrdinalIgnoreCase))
            return false;

        foreach (var segment in normalized.Split('/', StringSplitOptions.RemoveEmptyEntries))
        {
            if (segment.Equals("Engine", StringComparison.OrdinalIgnoreCase))
                return false;
        }

        return true;
    }

    private static string Normalize(string path)
        => Path.GetFullPath(path).Replace('\\', '/').TrimEnd('/');
}
