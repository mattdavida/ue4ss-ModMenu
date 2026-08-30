using System.Diagnostics;

namespace ModMenu.Harness;

public static class HostDeploy
{
    public const string ModName = "ModMenuHarness";

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

        var hostLuaPath = Path.Combine(repoRoot, "examples", "ModMenuHarness.lua");
        if (!File.Exists(hostLuaPath))
            throw new FileNotFoundException("Missing harness host Lua.", hostLuaPath);

        var root = WriteEnabledHost(mods, ModName, File.ReadAllText(hostLuaPath));
        var liveFlag = Path.Combine(root, "play-live.txt");
        if (playLive)
        {
            File.WriteAllText(liveFlag, "");
            log?.Invoke("play-live: suite will step with in-game delays.");
        }

        var results = Ue4ssLayout.ResultsPath(win64Path);
        if (File.Exists(results))
            File.Delete(results);

        log?.Invoke($"Deployed {ModName} to {root}");
        return root;
    }

    public static void Remove(string win64Path, Action<string>? log = null)
    {
        var root = Path.Combine(Ue4ssLayout.ModsDirectory(win64Path), ModName);
        if (Directory.Exists(root))
        {
            Directory.Delete(root, recursive: true);
            log?.Invoke($"Removed {root}");
        }

        var results = Ue4ssLayout.ResultsPath(win64Path);
        if (File.Exists(results))
        {
            File.Delete(results);
            log?.Invoke($"Removed {results}");
        }
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
