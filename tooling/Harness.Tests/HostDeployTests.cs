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

    [Fact]
    public void Deploys_then_removes_only_the_harness_mod()
    {
        using var temp = new TempDir();
        var repo = temp.Combine("repo");
        Directory.CreateDirectory(Path.Combine(repo, "examples"));
        Directory.CreateDirectory(Path.Combine(repo, "dist"));
        File.WriteAllText(Path.Combine(repo, "examples", "ModMenuHarness.lua"), "print('host')\n");
        File.WriteAllText(Path.Combine(repo, "examples", "ModMenuHarnessB.lua"), "print('peer')\n");
        File.WriteAllText(Path.Combine(repo, "dist", "ModMenu.bundle.lua"), "-- bundle\n");

        var win64 = temp.Combine("Game", "Binaries", "Win64");
        var mods = Path.Combine(win64, "ue4ss", "Mods");
        Directory.CreateDirectory(Path.Combine(mods, "FatalClawMod"));
        File.WriteAllText(Path.Combine(mods, "FatalClawMod", "keep.txt"), "player");

        HostDeploy.Deploy(win64, repo, playLive: true);
        Assert.True(File.Exists(Path.Combine(mods, "ModMenuHarness", "Scripts", "main.lua")));
        Assert.True(File.Exists(Path.Combine(mods, "ModMenuHarnessB", "Scripts", "main.lua")));
        Assert.True(File.Exists(Path.Combine(mods, "ModMenuHarness", "play-live.txt")));
        Assert.True(File.Exists(Path.Combine(mods, "ModMenuHarnessB", "play-live.txt")));
        Assert.True(File.Exists(Path.Combine(mods, "shared", "ModMenu", "ModMenu.lua")));

        HostDeploy.Remove(win64);
        Assert.False(Directory.Exists(Path.Combine(mods, "ModMenuHarness")));
        Assert.False(Directory.Exists(Path.Combine(mods, "ModMenuHarnessB")));
        Assert.True(File.Exists(Path.Combine(mods, "FatalClawMod", "keep.txt")));
        Assert.True(File.Exists(Path.Combine(mods, "shared", "ModMenu", "ModMenu.lua")));
    }
}
