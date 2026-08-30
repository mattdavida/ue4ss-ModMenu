namespace ModMenu.Harness;

public static class GameCatalog
{
    public static List<DetectedGame> Load(StudioSettings? settings = null)
    {
        var games = SteamScanner.FindUnrealGames().ToList();
        return MergeLastManual(games, settings ?? new StudioSettings());
    }

    /// <summary>
    /// Re-adds a last-used install that Steam no longer lists (manual add).
    /// Missing paths are dropped.
    /// </summary>
    public static List<DetectedGame> MergeLastManual(
        IReadOnlyList<DetectedGame> steamGames,
        StudioSettings settings)
    {
        var games = steamGames.ToList();
        if (string.IsNullOrWhiteSpace(settings.LastInstallPath)
            || !Directory.Exists(settings.LastInstallPath))
        {
            return games;
        }

        if (games.Any(game =>
                string.Equals(game.InstallPath, settings.LastInstallPath, StringComparison.OrdinalIgnoreCase)))
        {
            return games;
        }

        var win64 = PathDetector.FindWin64Directory(settings.LastInstallPath);
        if (win64 is null)
            return games;

        games.Insert(0, ManualGameResolver.ToGame(settings.LastInstallPath, win64));
        return games;
    }
}
