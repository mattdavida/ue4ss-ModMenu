namespace ModMenu.Harness.Tests;

public sealed class GameLauncherTests
{
    [Fact]
    public void Steam_games_launch_through_rungameid()
    {
        var info = GameLauncher.CreateStartInfo(new DetectedGame
        {
            Name = "Fatal Claw",
            InstallPath = @"D:\SteamLibrary\steamapps\common\Fatal Claw",
            Win64Path = @"D:\SteamLibrary\steamapps\common\Fatal Claw\FatalClaw\Binaries\Win64",
            AppId = "123456",
            ExePath = @"D:\SteamLibrary\steamapps\common\Fatal Claw\FatalClaw\Binaries\Win64\FatalClaw.exe"
        });

        Assert.Equal("steam://rungameid/123456", info.FileName);
        Assert.True(info.UseShellExecute);
    }

    [Fact]
    public void Non_Steam_games_launch_the_exe_in_Win64()
    {
        using var temp = new TempDir();
        var win64 = temp.Combine("Binaries", "Win64");
        Directory.CreateDirectory(win64);
        var exe = Path.Combine(win64, "MyGame.exe");
        File.WriteAllBytes(exe, [1]);

        var info = GameLauncher.CreateStartInfo(new DetectedGame
        {
            Name = "MyGame",
            InstallPath = temp.Path,
            Win64Path = win64,
            ExePath = exe
        });

        Assert.Equal(exe, info.FileName);
        Assert.Equal(win64, info.WorkingDirectory);
    }

    [Fact]
    public void Process_name_strips_the_exe_suffix()
    {
        Assert.Equal(
            "FatalClaw-Win64-Shipping",
            GameLauncher.ProcessNameFromExe(@"D:\games\FatalClaw-Win64-Shipping.exe"));
        Assert.Null(GameLauncher.ProcessNameFromExe(null));
    }
}
