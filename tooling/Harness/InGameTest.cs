namespace ModMenu.Harness;

public static class InGameTest
{
    public static InGameResults Run(DetectedGame game, InGameTestOptions? options = null)
    {
        options ??= new InGameTestOptions();
        var log = options.Log ?? (_ => { });
        var repo = options.RepoRoot ?? RepoRoot.Find();

        if (!Ue4ssLayout.IsInstalled(game.Win64Path))
        {
            return Fail("UE4SS is not installed. Use UE4SS Installer, then retry.");
        }

        var resultsPath = Ue4ssLayout.ResultsPath(game.Win64Path);
        var peerPath = Ue4ssLayout.PeerResultsPath(game.Win64Path);
        try
        {
            log("Deploying ModMenuHarness + Harness B (before launch)…");
            HostDeploy.Deploy(game.Win64Path, repo, log, options.PlayLive);

            if (!options.SkipLaunch)
            {
                log($"Launching {game.Name} via Steam…");
                GameLauncher.Start(game);
                log("Host will not open the menu for 30s after it loads (game settle).");
            }
            else
            {
                log("Skip launch — waiting for an already-running game.");
            }

            var files = WaitForResults([resultsPath, peerPath], options, log);
            var primaryJson = files[0];
            var peerJson = files[1];
            if (primaryJson is null)
            {
                return Fail(
                    $"No {Ue4ssLayout.ResultsFileName} after {options.TotalTimeout.TotalSeconds:0}s. " +
                    "Is the game in-world, and did UE4SS load ModMenuHarness?");
            }

            if (peerJson is null)
            {
                return Fail(
                    $"No {Ue4ssLayout.PeerResultsFileName} after {options.TotalTimeout.TotalSeconds:0}s. " +
                    "Harness A finished; did UE4SS load ModMenuHarnessB?");
            }

            log("Results files found. Evaluating A then B…");
            return InGameResults.Combine(
                InGameResults.Evaluate(primaryJson),
                InGameResults.Evaluate(peerJson, InGameResultExpect.Peer));
        }
        finally
        {
            if (!options.SkipLaunch)
            {
                try
                {
                    GameLauncher.TryClose(game, log);
                }
                catch (Exception ex)
                {
                    log("Could not close the game: " + ex.Message);
                }
            }

            log("Removing harness mods…");
            try
            {
                HostDeploy.Remove(game.Win64Path, log);
            }
            catch (Exception ex)
            {
                log("Cleanup failed: " + ex.Message);
            }
        }
    }

    private static string?[] WaitForResults(string[] paths, InGameTestOptions options, Action<string> log)
    {
        var found = new string?[paths.Length];
        var deadline = DateTime.UtcNow + options.TotalTimeout;
        var nextPing = DateTime.UtcNow;
        var round = 1;
        var announcedA = false;

        while (DateTime.UtcNow < deadline)
        {
            if (DateTime.UtcNow >= nextPing)
            {
                log($"Waiting for results (round {round}/{options.EffectiveRounds}, {options.Round.TotalSeconds:0}s)…");
                nextPing = DateTime.UtcNow + options.Round;
                round++;
            }

            for (var i = 0; i < paths.Length; i++)
            {
                if (found[i] is not null)
                    continue;
                found[i] = TryReadResults(paths[i]);
            }

            if (!announcedA && found[0] is not null)
            {
                log("Harness A results found — waiting for Harness B…");
                announcedA = true;
            }

            if (found.All(text => text is not null))
                return found;

            Thread.Sleep(options.PollInterval);
        }

        return found;
    }

    private static string? TryReadResults(string path)
    {
        if (!File.Exists(path))
            return null;

        try
        {
            var text = File.ReadAllText(path);
            return string.IsNullOrWhiteSpace(text) ? null : text;
        }
        catch (IOException)
        {
            return null;
        }
    }

    private static InGameResults Fail(string message)
        => new()
        {
            Ok = false,
            Failures = [message]
        };
}

public sealed class InGameTestOptions
{
    public TimeSpan PollInterval { get; init; } = TimeSpan.FromSeconds(1);
    public TimeSpan Round { get; init; } = TimeSpan.FromSeconds(30);
    public int Rounds { get; init; } = 4;
    public bool SkipLaunch { get; init; }
    public bool PlayLive { get; init; }
    public string? RepoRoot { get; init; }
    public Action<string>? Log { get; init; }

    public int EffectiveRounds => PlayLive ? Math.Max(Rounds, 8) : Math.Max(1, Rounds);

    public TimeSpan TotalTimeout => TimeSpan.FromTicks(Round.Ticks * EffectiveRounds);
}
