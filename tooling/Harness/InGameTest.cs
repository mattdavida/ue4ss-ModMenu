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
        try
        {
            log("Deploying ModMenuHarness (before launch)…");
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

            var json = WaitForResults(resultsPath, options, log);
            if (json is null)
            {
                return Fail(
                    $"No {Ue4ssLayout.ResultsFileName} after {options.TotalTimeout.TotalSeconds:0}s. " +
                    "Is the game in-world, and did UE4SS load ModMenuHarness?");
            }

            log("Results file found. Evaluating…");
            return InGameResults.Evaluate(json);
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

            log("Removing ModMenuHarness…");
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

    private static string? WaitForResults(string path, InGameTestOptions options, Action<string> log)
    {
        var deadline = DateTime.UtcNow + options.TotalTimeout;
        var nextPing = DateTime.UtcNow;
        var round = 1;

        while (DateTime.UtcNow < deadline)
        {
            if (DateTime.UtcNow >= nextPing)
            {
                log($"Waiting for results (round {round}/{options.EffectiveRounds}, {options.Round.TotalSeconds:0}s)…");
                nextPing = DateTime.UtcNow + options.Round;
                round++;
            }

            if (File.Exists(path))
            {
                try
                {
                    var text = File.ReadAllText(path);
                    if (!string.IsNullOrWhiteSpace(text))
                        return text;
                }
                catch (IOException)
                {
                    // host may still be writing
                }
            }

            Thread.Sleep(options.PollInterval);
        }

        return null;
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
