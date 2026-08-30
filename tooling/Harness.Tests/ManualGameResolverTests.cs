namespace ModMenu.Harness.Tests;

public sealed class ManualGameResolverTests
{
    [Fact]
    public void Uses_steamapps_common_folder_as_the_install_root()
    {
        using var temp = new TempDir();
        var install = temp.Combine("steamapps", "common", "MortalShell2");
        var win64 = Path.Combine(install, "MortalShell2", "Binaries", "Win64");
        Directory.CreateDirectory(win64);

        var resolved = ManualGameResolver.InferInstallPath(win64, win64);
        Assert.Equal(Path.GetFullPath(install), resolved);
    }

    [Fact]
    public void Uses_the_picked_Steam_folder_when_it_is_above_Win64()
    {
        using var temp = new TempDir();
        var install = temp.Combine("MyGame");
        var win64 = Path.Combine(install, "Binaries", "Win64");
        Directory.CreateDirectory(win64);

        var resolved = ManualGameResolver.InferInstallPath(install, win64);
        Assert.Equal(Path.GetFullPath(install), resolved);
    }

    [Fact]
    public void Names_the_row_from_the_common_folder()
    {
        using var temp = new TempDir();
        var install = temp.Combine("steamapps", "common", "MortalShell2");
        var win64 = Path.Combine(install, "Binaries", "Win64");
        Directory.CreateDirectory(win64);

        var identity = ManualGameResolver.Resolve(win64, win64);
        Assert.Equal("MortalShell2", identity.Name);
        Assert.Equal(Path.GetFullPath(install), identity.InstallPath);
    }
}
