using System.Runtime.Versioning;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace ModMenu.Harness;

/// <summary>
/// Finds installed Steam Unreal games. Copied from UE4SSInstaller (no icons / UE4SS badges).
/// </summary>
public static class SteamScanner
{
    private static readonly Regex VdfPathRegex = new(
        @"^\s*""path""\s+""(.+)""\s*$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex VdfNameRegex = new(
        @"^\s*""name""\s+""(.+)""\s*$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex VdfInstallDirRegex = new(
        @"^\s*""installdir""\s+""(.+)""\s*$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static readonly Regex VdfAppIdRegex = new(
        @"^\s*""appid""\s+""(.+)""\s*$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    public static IReadOnlyList<DetectedGame> FindUnrealGames()
    {
        var steamPath = FindSteamInstallPath();
        if (steamPath is null)
            return [];

        var libraries = CollectLibraryPaths(steamPath);
        var seenInstalls = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var games = new List<DetectedGame>();

        foreach (var library in libraries)
        {
            var steamapps = Path.Combine(library, "steamapps");
            if (!Directory.Exists(steamapps))
                continue;

            IEnumerable<string> manifests;
            try
            {
                manifests = Directory.EnumerateFiles(steamapps, "appmanifest_*.acf");
            }
            catch (Exception)
            {
                continue;
            }

            foreach (var manifest in manifests)
            {
                if (!TryReadManifest(manifest, out var name, out var installDir, out var appId))
                    continue;

                var installPath = Path.Combine(steamapps, "common", installDir);
                if (!Directory.Exists(installPath))
                    continue;

                string fullInstall;
                try
                {
                    fullInstall = Path.GetFullPath(installPath);
                }
                catch (Exception)
                {
                    continue;
                }

                if (!seenInstalls.Add(fullInstall))
                    continue;

                var win64 = PathDetector.FindWin64Directory(fullInstall);
                if (win64 is null)
                    continue;

                var exePath = PathDetector.FindGameExecutable(win64);
                games.Add(new DetectedGame
                {
                    Name = name,
                    InstallPath = fullInstall,
                    Win64Path = win64,
                    ExePath = exePath,
                    AppId = appId,
                    ArtworkPath = GameArtwork.FindSteamArtwork(steamPath, appId)
                });
            }
        }

        games.Sort((a, b) => string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase));
        return games;
    }

    internal static bool TryIdentifyCommonInstall(string installPath, out string displayName, out string appId)
    {
        displayName = string.Empty;
        appId = string.Empty;

        string steamapps;
        try
        {
            var common = Directory.GetParent(Path.GetFullPath(installPath));
            var parent = common?.Parent;
            if (parent is null || !parent.Name.Equals("steamapps", StringComparison.OrdinalIgnoreCase))
                return false;

            steamapps = parent.FullName;
        }
        catch (Exception)
        {
            return false;
        }

        var installDir = Path.GetFileName(installPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
        if (string.IsNullOrWhiteSpace(installDir) || !Directory.Exists(steamapps))
            return false;

        IEnumerable<string> manifests;
        try
        {
            manifests = Directory.EnumerateFiles(steamapps, "appmanifest_*.acf");
        }
        catch (Exception)
        {
            return false;
        }

        foreach (var manifest in manifests)
        {
            if (!TryReadManifest(manifest, out var name, out var dir, out var parsedAppId))
                continue;

            if (!dir.Equals(installDir, StringComparison.OrdinalIgnoreCase))
                continue;

            displayName = name;
            appId = parsedAppId;
            return displayName.Length > 0;
        }

        return false;
    }

    public static string? FindSteamPath() => FindSteamInstallPath();

    private static string? FindSteamInstallPath()
    {
        if (OperatingSystem.IsWindows())
        {
            var fromRegistry = FindSteamInstallPathFromRegistry();
            if (fromRegistry is not null)
                return fromRegistry;
        }

        foreach (var candidate in GetUnixSteamCandidates())
        {
            var existing = ExistingDirectory(candidate);
            if (existing is not null)
                return existing;
        }

        return null;
    }

    [SupportedOSPlatform("windows")]
    private static string? FindSteamInstallPathFromRegistry()
    {
        string[] hklmSubkeys =
        [
            @"SOFTWARE\WOW6432Node\Valve\Steam",
            @"SOFTWARE\Valve\Steam"
        ];

        foreach (var subkey in hklmSubkeys)
        {
            var path = ReadRegistryPath(Registry.LocalMachine, subkey, "InstallPath");
            if (path is not null)
                return path;
        }

        return ReadRegistryPath(Registry.CurrentUser, @"SOFTWARE\Valve\Steam", "SteamPath");
    }

    [SupportedOSPlatform("windows")]
    private static string? ReadRegistryPath(RegistryKey root, string subkeyName, string valueName)
    {
        try
        {
            using var key = root.OpenSubKey(subkeyName);
            if (key?.GetValue(valueName) is not string raw || string.IsNullOrWhiteSpace(raw))
                return null;

            return ExistingDirectory(UnescapeVdf(raw.Trim()));
        }
        catch (Exception)
        {
            return null;
        }
    }

    private static IEnumerable<string> GetUnixSteamCandidates()
    {
        var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        if (string.IsNullOrEmpty(home))
            home = Environment.GetEnvironmentVariable("HOME") ?? string.Empty;

        if (string.IsNullOrEmpty(home))
            yield break;

        yield return Path.Combine(home, ".steam", "steam");
        yield return Path.Combine(home, ".steam", "root");
        yield return Path.Combine(home, ".local", "share", "Steam");
        yield return Path.Combine(home, ".var", "app", "com.valvesoftware.Steam", ".local", "share", "Steam");
    }

    private static HashSet<string> CollectLibraryPaths(string steamPath)
    {
        var libraries = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            steamPath
        };

        string[] vdfPaths =
        [
            Path.Combine(steamPath, "config", "libraryfolders.vdf"),
            Path.Combine(steamPath, "steamapps", "libraryfolders.vdf")
        ];

        foreach (var vdfPath in vdfPaths)
        {
            if (!File.Exists(vdfPath))
                continue;

            IEnumerable<string> lines;
            try
            {
                lines = File.ReadLines(vdfPath);
            }
            catch (Exception)
            {
                continue;
            }

            foreach (var line in lines)
            {
                var match = VdfPathRegex.Match(line);
                if (!match.Success)
                    continue;

                var library = ExistingDirectory(UnescapeVdf(match.Groups[1].Value));
                if (library is not null)
                    libraries.Add(library);
            }
        }

        return libraries;
    }

    private static bool TryReadManifest(string manifestPath, out string name, out string installDir, out string appId)
    {
        name = string.Empty;
        installDir = string.Empty;
        appId = string.Empty;

        string[] lines;
        try
        {
            lines = File.ReadAllLines(manifestPath);
        }
        catch (Exception)
        {
            return false;
        }

        string? parsedName = null;
        string? parsedInstallDir = null;
        string? parsedAppId = null;

        foreach (var line in lines)
        {
            if (parsedName is null)
            {
                var nameMatch = VdfNameRegex.Match(line);
                if (nameMatch.Success)
                    parsedName = UnescapeVdf(nameMatch.Groups[1].Value);
            }

            if (parsedInstallDir is null)
            {
                var installMatch = VdfInstallDirRegex.Match(line);
                if (installMatch.Success)
                    parsedInstallDir = UnescapeVdf(installMatch.Groups[1].Value);
            }

            if (parsedAppId is null)
            {
                var appMatch = VdfAppIdRegex.Match(line);
                if (appMatch.Success)
                    parsedAppId = UnescapeVdf(appMatch.Groups[1].Value);
            }

            if (parsedName is not null && parsedInstallDir is not null && parsedAppId is not null)
                break;
        }

        if (string.IsNullOrWhiteSpace(parsedName) || string.IsNullOrWhiteSpace(parsedInstallDir))
            return false;

        name = parsedName.Trim();
        installDir = parsedInstallDir.Trim();
        appId = parsedAppId?.Trim() ?? string.Empty;
        return name.Length > 0 && installDir.Length > 0;
    }

    private static string UnescapeVdf(string value)
        => value.Replace(@"\\", @"\", StringComparison.Ordinal)
            .Replace(@"\""", "\"", StringComparison.Ordinal);

    private static string? ExistingDirectory(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return null;

        try
        {
            var full = Path.GetFullPath(path.Trim().Trim('"'));
            return Directory.Exists(full) ? full : null;
        }
        catch (Exception)
        {
            return null;
        }
    }
}
