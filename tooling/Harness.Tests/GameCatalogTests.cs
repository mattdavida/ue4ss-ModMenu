namespace ModMenu.Harness.Tests;

public sealed class GameCatalogTests
{
    [Fact]
    public void Readds_a_last_manual_install_that_Steam_did_not_list()
    {
        using var temp = new TempDir();
        var install = temp.Combine("MyOfflineGame");
        var win64 = Path.Combine(install, "Binaries", "Win64");
        Directory.CreateDirectory(win64);

        var merged = GameCatalog.MergeLastManual([], new StudioSettings
        {
            LastGameName = "MyOfflineGame",
            LastInstallPath = install
        });

        var game = Assert.Single(merged);
        Assert.Equal(Path.GetFullPath(install), game.InstallPath);
        Assert.Equal(Path.GetFullPath(win64), game.Win64Path);
    }

    [Fact]
    public void Drops_a_last_install_that_no_longer_exists()
    {
        var merged = GameCatalog.MergeLastManual([], new StudioSettings
        {
            LastGameName = "Gone",
            LastInstallPath = Path.Combine(Path.GetTempPath(), "modmenu-missing-game-" + Guid.NewGuid().ToString("N"))
        });
        Assert.Empty(merged);
    }
}
