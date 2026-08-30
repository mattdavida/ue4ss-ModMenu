using System.Diagnostics;

namespace ModMenu.Harness;

public static class GameLauncher
{
    public static Process Start(DetectedGame game)
    {
        return Process.Start(CreateStartInfo(game))
            ?? throw new InvalidOperationException("The OS did not start the game process.");
    }

    /// <summary>
    /// Steam titles must go through Steam (app id / overlay / steam_api).
    /// Direct exe launch is what crashes Fatal Claw at startup.
    /// </summary>
    public static ProcessStartInfo CreateStartInfo(DetectedGame game)
    {
        if (!string.IsNullOrWhiteSpace(game.AppId))
        {
            return new ProcessStartInfo
            {
                FileName = $"steam://rungameid/{game.AppId.Trim()}",
                UseShellExecute = true
            };
        }

        if (string.IsNullOrWhiteSpace(game.ExePath) || !File.Exists(game.ExePath))
            throw new InvalidOperationException("No game executable found under Win64.");

        return new ProcessStartInfo
        {
            FileName = game.ExePath,
            WorkingDirectory = game.Win64Path,
            UseShellExecute = true
        };
    }

    public static string? ProcessNameFromExe(string? exePath)
    {
        if (string.IsNullOrWhiteSpace(exePath))
            return null;

        var name = Path.GetFileNameWithoutExtension(exePath);
        return string.IsNullOrWhiteSpace(name) ? null : name;
    }

    /// <summary>
    /// Steam:// start does not return the game process. Find the Win64 exe and ask it to quit.
    /// </summary>
    public static int TryClose(DetectedGame game, Action<string>? log = null, TimeSpan? wait = null)
    {
        var processName = ProcessNameFromExe(game.ExePath);
        if (processName is null)
        {
            log?.Invoke("No exe name to close.");
            return 0;
        }

        var grace = wait ?? TimeSpan.FromSeconds(15);
        var closed = 0;

        foreach (var process in Process.GetProcessesByName(processName))
        {
            using (process)
            {
                if (!MatchesGame(process, game))
                    continue;

                try
                {
                    log?.Invoke($"Closing {processName} (pid {process.Id})…");
                    process.CloseMainWindow();
                    if (!process.WaitForExit((int)grace.TotalMilliseconds))
                    {
                        log?.Invoke($"Game did not exit in {grace.TotalSeconds:0}s — killing.");
                        process.Kill(entireProcessTree: true);
                        process.WaitForExit(5000);
                    }

                    closed++;
                }
                catch (Exception ex)
                {
                    log?.Invoke($"Could not close {processName}: {ex.Message}");
                }
            }
        }

        if (closed == 0)
            log?.Invoke($"No running {processName} process.");

        return closed;
    }

    private static bool MatchesGame(Process process, DetectedGame game)
    {
        if (string.IsNullOrWhiteSpace(game.ExePath) && string.IsNullOrWhiteSpace(game.Win64Path))
            return true;

        try
        {
            var path = process.MainModule?.FileName;
            if (string.IsNullOrEmpty(path))
                return true;

            if (!string.IsNullOrWhiteSpace(game.ExePath)
                && string.Equals(path, game.ExePath, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrWhiteSpace(game.Win64Path))
            {
                var win64 = Path.GetFullPath(game.Win64Path);
                var full = Path.GetFullPath(path);
                return full.StartsWith(win64, StringComparison.OrdinalIgnoreCase);
            }
        }
        catch
        {
            return true;
        }

        return false;
    }
}
