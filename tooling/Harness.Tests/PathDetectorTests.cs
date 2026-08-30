namespace ModMenu.Harness.Tests;

public sealed class PathDetectorTests
{
    [Fact]
    public void Finds_the_game_Win64_folder_and_skips_Engine()
    {
        using var temp = new TempDir();
        var engine = temp.Combine("Engine", "Binaries", "Win64");
        var game = temp.Combine("MyGame", "Binaries", "Win64");
        Directory.CreateDirectory(engine);
        Directory.CreateDirectory(game);

        var found = PathDetector.FindWin64Directory(temp.Path);
        Assert.Equal(System.IO.Path.GetFullPath(game), found);
    }

    [Fact]
    public void Returns_null_when_only_Engine_Win64_exists()
    {
        using var temp = new TempDir();
        Directory.CreateDirectory(temp.Combine("Engine", "Binaries", "Win64"));
        Assert.Null(PathDetector.FindWin64Directory(temp.Path));
    }

    [Fact]
    public void Prefers_the_shipping_exe_over_helpers()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("Binaries", "Win64");
        Directory.CreateDirectory(win64);
        File.WriteAllBytes(System.IO.Path.Combine(win64, "dwmapi.dll"), [1]);
        File.WriteAllBytes(System.IO.Path.Combine(win64, "UE4SS-Test.exe"), new byte[10]);
        File.WriteAllBytes(System.IO.Path.Combine(win64, "MyGame-Win64-Shipping.exe"), new byte[4]);

        var exe = PathDetector.FindGameExecutable(win64);
        Assert.Equal("MyGame-Win64-Shipping.exe", System.IO.Path.GetFileName(exe));
    }

    [Fact]
    public void Accepts_Binaries_Win64_when_that_folder_is_picked()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("MortalShell2", "Binaries", "Win64");
        Directory.CreateDirectory(win64);

        var found = PathDetector.FindWin64Directory(win64);
        Assert.Equal(System.IO.Path.GetFullPath(win64), found);
    }

    [Fact]
    public void Rejects_Engine_Win64_when_that_folder_is_picked()
    {
        using var temp = new TempDir();
        var engineWin64 = temp.Combine("Engine", "Binaries", "Win64");
        Directory.CreateDirectory(engineWin64);

        Assert.Null(PathDetector.FindWin64Directory(engineWin64));
    }
}
