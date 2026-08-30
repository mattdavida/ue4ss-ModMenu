using System.Diagnostics;

namespace ModMenu.Harness;

public static class HostDeploy
{
    public const string ModName = "ModMenuHarness";
    public const string PeerModName = "ModMenuHarnessB";

    public static string WriteEnabledHost(string modsDir, string modName, string mainLua)
    {
        var root = Path.Combine(modsDir, modName);
        var scripts = Path.Combine(root, "Scripts");
        Directory.CreateDirectory(scripts);
        File.WriteAllText(Path.Combine(root, "enabled.txt"), "");
        File.WriteAllText(Path.Combine(scripts, "main.lua"), mainLua);
        return root;
    }

    public static string Deploy(string win64Path, string repoRoot, Action<string>? log = null, bool playLive = false)
    {
        var mods = Ue4ssLayout.ModsDirectory(win64Path);
        Directory.CreateDirectory(mods);
        EnsureSharedModMenu(mods, repoRoot, log);

        var primary = DeployHost(mods, repoRoot, ModName, "ModMenuHarness.lua", playLive, log);
        DeployHost(mods, repoRoot, PeerModName, "ModMenuHarnessB.lua", playLive, log);

        foreach (var results in new[] { Ue4ssLayout.ResultsPath(win64Path), Ue4ssLayout.PeerResultsPath(win64Path) })
        {
            if (File.Exists(results))
                File.Delete(results);
        }

        return primary;
    }

    public static void Remove(string win64Path, Action<string>? log = null)
    {
        foreach (var name in new[] { ModName, PeerModName })
        {
            var root = Path.Combine(Ue4ssLayout.ModsDirectory(win64Path), name);
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
                log?.Invoke($"Removed {root}");
            }
        }

        foreach (var results in new[] { Ue4ssLayout.ResultsPath(win64Path), Ue4ssLayout.PeerResultsPath(win64Path) })
        {
            if (File.Exists(results))
            {
                File.Delete(results);
                log?.Invoke($"Removed {results}");
            }
        }
    }

    private static string DeployHost(
        string mods,
        string repoRoot,
        string modName,
        string exampleFile,
        bool playLive,
        Action<string>? log)
    {
        var hostLuaPath = Path.Combine(repoRoot, "examples", exampleFile);
        if (!File.Exists(hostLuaPath))
            throw new FileNotFoundException("Missing harness host Lua.", hostLuaPath);

        var root = WriteEnabledHost(mods, modName, File.ReadAllText(hostLuaPath));
        if (playLive)
        {
            File.WriteAllText(Path.Combine(root, "play-live.txt"), "");
            log?.Invoke($"play-live: {modName} will step with in-game delays.");
        }

        log?.Invoke($"Deployed {modName} to {root}");
        return root;
    }

    private static void EnsureSharedModMenu(string modsDir, string repoRoot, Action<string>? log)
    {
        var destDir = Path.Combine(modsDir, "shared", "ModMenu");
        var dest = Path.Combine(destDir, "ModMenu.lua");
        var facade = Path.Combine(repoRoot, "ModMenu.lua");
        var release = Path.Combine(repoRoot, "dist", "release", "shared", "ModMenu", "ModMenu.lua");
        var bundle = Path.Combine(repoRoot, "dist", "ModMenu.bundle.lua");

        if (File.Exists(facade))
        {
            try
            {
                log?.Invoke("Bundling ModMenu so the game gets this repo…");
                RunBundle(repoRoot);
            }
            catch (Exception ex)
            {
                log?.Invoke("Bundle step failed: " + ex.Message);
                if (!File.Exists(release) && !File.Exists(bundle))
                    throw;
                log?.Invoke("Using the existing dist bundle. Run `npm run bundle` in a terminal if this copy is stale.");
            }
        }

        // bundle.lua is what `npm run bundle` writes. release/ can be an older deploy zip copy.
        var src = File.Exists(bundle) ? bundle : release;

        if (!File.Exists(src))
            throw new FileNotFoundException("ModMenu bundle missing. Run npm run bundle.", bundle);

        Directory.CreateDirectory(destDir);
        File.Copy(src, dest, overwrite: true);
        log?.Invoke($"Refreshed shared/ModMenu from {src}");
    }

    private static void RunBundle(string repoRoot)
    {
        var start = OperatingSystem.IsWindows()
            ? new ProcessStartInfo
            {
                FileName = "cmd.exe",
                Arguments = "/c npm run bundle",
                WorkingDirectory = repoRoot,
                UseShellExecute = false
            }
            : new ProcessStartInfo
            {
                FileName = "npm",
                Arguments = "run bundle",
                WorkingDirectory = repoRoot,
                UseShellExecute = false
            };

        using var process = Process.Start(start)
            ?? throw new InvalidOperationException("Could not start npm run bundle.");
        process.WaitForExit();
        if (process.ExitCode != 0)
            throw new InvalidOperationException("npm run bundle failed.");
    }
}
