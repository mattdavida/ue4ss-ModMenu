namespace ModMenu.Harness.Tests;

public sealed class StudioSettingsTests
{
    [Fact]
    public void MatchLast_requires_the_install_path_to_still_exist()
    {
        var claw = new DetectedGame
        {
            Name = "Fatal Claw",
            InstallPath = @"D:\SteamLibrary\steamapps\common\Fatal Claw",
            Win64Path = @"D:\SteamLibrary\steamapps\common\Fatal Claw\FatalClaw\Binaries\Win64"
        };

        var hit = StudioSettings.MatchLast([claw], new StudioSettings
        {
            LastGameName = "Fatal Claw",
            LastInstallPath = claw.InstallPath
        });
        Assert.Same(claw, hit);

        var miss = StudioSettings.MatchLast([claw], new StudioSettings
        {
            LastGameName = "Fatal Claw",
            LastInstallPath = @"D:\gone\Fatal Claw"
        });
        Assert.Null(miss);
    }

    [Fact]
    public void Roundtrips_json()
    {
        using var temp = new TempDir();
        var path = Path.Combine(temp.Path, "settings.json");
        StudioSettings.Save(new StudioSettings
        {
            LastGameName = "Fatal Claw",
            LastInstallPath = @"D:\games\Fatal Claw"
        }, path);

        var loaded = StudioSettings.Load(path);
        Assert.Equal("Fatal Claw", loaded.LastGameName);
        Assert.Equal(@"D:\games\Fatal Claw", loaded.LastInstallPath);
    }
}
