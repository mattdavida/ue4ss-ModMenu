namespace ModMenu.Harness.Tests;

public sealed class Ue4ssLayoutTests
{
    [Fact]
    public void Detects_ue4ss_folder()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("Binaries", "Win64");
        Directory.CreateDirectory(System.IO.Path.Combine(win64, "ue4ss"));
        Assert.True(Ue4ssLayout.IsInstalled(win64));
    }

    [Fact]
    public void Detects_dwmapi_proxy()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("Binaries", "Win64");
        Directory.CreateDirectory(win64);
        File.WriteAllBytes(System.IO.Path.Combine(win64, "dwmapi.dll"), [1]);
        Assert.True(Ue4ssLayout.IsInstalled(win64));
    }

    [Fact]
    public void Empty_win64_is_not_installed()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("Binaries", "Win64");
        Directory.CreateDirectory(win64);
        Assert.False(Ue4ssLayout.IsInstalled(win64));
    }

    [Fact]
    public void Results_path_is_under_the_ue4ss_root()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("Binaries", "Win64");
        Directory.CreateDirectory(Path.Combine(win64, "ue4ss"));

        Assert.Equal(
            Path.Combine(win64, "ue4ss", Ue4ssLayout.ResultsFileName),
            Ue4ssLayout.ResultsPath(win64));
        Assert.Equal(Path.Combine(win64, "ue4ss", "Mods"), Ue4ssLayout.ModsDirectory(win64));
    }
}
