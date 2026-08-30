namespace ModMenu.Harness;

/// <summary>
/// Turns a folder the user picked into list-row fields. Copied from UE4SSInstaller.
/// </summary>
public static class ManualGameResolver
{
    public readonly record struct Identity(string Name, string InstallPath, string AppId);

    public static Identity Resolve(string pickedPath, string win64Path)
    {
        var installPath = InferInstallPath(pickedPath, win64Path);
        var name = Path.GetFileName(installPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        var appId = string.Empty;

        if (SteamScanner.TryIdentifyCommonInstall(installPath, out var manifestName, out var manifestAppId))
        {
            if (!string.IsNullOrWhiteSpace(manifestName))
                name = manifestName;
            appId = manifestAppId;
        }

        if (string.IsNullOrWhiteSpace(name))
            name = "Added game";

        return new Identity(name, installPath, appId);
    }

    public static DetectedGame ToGame(string pickedPath, string win64Path)
    {
        var identity = Resolve(pickedPath, win64Path);
        var appId = string.IsNullOrWhiteSpace(identity.AppId) ? null : identity.AppId;
        return new DetectedGame
        {
            Name = identity.Name,
            InstallPath = identity.InstallPath,
            Win64Path = Path.GetFullPath(win64Path),
            AppId = appId,
            ExePath = PathDetector.FindGameExecutable(win64Path),
            ArtworkPath = GameArtwork.FindSteamArtwork(SteamScanner.FindSteamPath(), appId)
        };
    }

    internal static string InferInstallPath(string pickedPath, string win64Path)
    {
        var win64 = Path.GetFullPath(win64Path);
        var fromSteam = SteamCommonGameRoot(win64);
        if (fromSteam is not null)
            return fromSteam;

        var picked = Path.GetFullPath(pickedPath.Trim().Trim('"'));
        if (Directory.Exists(picked)
            && IsUnderOrEqual(win64, picked)
            && !IsBinariesWin64(picked))
        {
            return picked;
        }

        return GameFolderFromWin64(win64);
    }

    internal static string? SteamCommonGameRoot(string path)
    {
        var full = Path.GetFullPath(path);
        var parts = full.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        for (var i = 0; i < parts.Length - 2; i++)
        {
            if (!parts[i].Equals("steamapps", StringComparison.OrdinalIgnoreCase)
                || !parts[i + 1].Equals("common", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var take = i + 3;
            return Path.GetFullPath(string.Join(Path.DirectorySeparatorChar, parts[..take]));
        }

        return null;
    }

    private static string GameFolderFromWin64(string win64)
    {
        var binaries = Path.GetDirectoryName(win64);
        var game = binaries is null ? null : Path.GetDirectoryName(binaries);
        return string.IsNullOrEmpty(game) ? win64 : game;
    }

    private static bool IsBinariesWin64(string directory)
    {
        var normalized = Path.GetFullPath(directory).Replace('\\', '/').TrimEnd('/');
        return normalized.EndsWith("/Binaries/Win64", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsUnderOrEqual(string child, string parent)
    {
        var a = Path.GetFullPath(child).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var b = Path.GetFullPath(parent).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (a.Equals(b, StringComparison.OrdinalIgnoreCase))
            return true;

        var prefix = b + Path.DirectorySeparatorChar;
        return a.StartsWith(prefix, StringComparison.OrdinalIgnoreCase);
    }
}
