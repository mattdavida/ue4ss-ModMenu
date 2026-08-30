namespace ModMenu.Harness;

public static class Ue4ssLayout
{
    public static bool IsInstalled(string win64Path)
    {
        if (string.IsNullOrWhiteSpace(win64Path) || !Directory.Exists(win64Path))
            return false;

        if (Directory.Exists(Path.Combine(win64Path, "ue4ss")))
            return true;

        return File.Exists(Path.Combine(win64Path, "dwmapi.dll"));
    }

    public static string Ue4ssRoot(string win64Path)
    {
        var nested = Path.Combine(win64Path, "ue4ss");
        return Directory.Exists(nested) ? nested : win64Path;
    }

    public static string ModsDirectory(string win64Path)
        => Path.Combine(Ue4ssRoot(win64Path), "Mods");

    public const string ResultsFileName = "ModMenuHarness-results.json";
    public const string PeerResultsFileName = "ModMenuHarnessB-results.json";

    public static string ResultsPath(string win64Path)
        => Path.Combine(Ue4ssRoot(win64Path), ResultsFileName);

    public static string PeerResultsPath(string win64Path)
        => Path.Combine(Ue4ssRoot(win64Path), PeerResultsFileName);
}
