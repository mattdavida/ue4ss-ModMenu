namespace ModMenu.Harness;

public static class HostDeploy
{
    public static string WriteEnabledHost(string modsDir, string modName, string mainLua)
    {
        var root = Path.Combine(modsDir, modName);
        var scripts = Path.Combine(root, "Scripts");
        Directory.CreateDirectory(scripts);
        File.WriteAllText(Path.Combine(root, "enabled.txt"), "");
        var mainPath = Path.Combine(scripts, "main.lua");
        File.WriteAllText(mainPath, mainLua);
        return root;
    }
}
