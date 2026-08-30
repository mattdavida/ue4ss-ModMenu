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
}
