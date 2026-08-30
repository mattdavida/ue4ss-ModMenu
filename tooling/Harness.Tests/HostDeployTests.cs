namespace ModMenu.Harness.Tests;

public sealed class HostDeployTests
{
    [Fact]
    public void Writes_enabled_mod_folder()
    {
        using var temp = new TempDir();
        var mods = temp.Combine("ue4ss", "Mods");
        var root = HostDeploy.WriteEnabledHost(mods, "ModMenuHarness", "print('ok')\n");

        Assert.True(File.Exists(System.IO.Path.Combine(root, "enabled.txt")));
        Assert.Equal("print('ok')\n", File.ReadAllText(System.IO.Path.Combine(root, "Scripts", "main.lua")));
    }
}
