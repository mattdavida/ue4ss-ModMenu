namespace ModMenu.Harness.Tests;

public sealed class GameResolverTests
{
    [Fact]
    public void Matches_a_unique_substring()
    {
        var games = new[]
        {
            new DetectedGame { Name = "Fatal Claw", InstallPath = @"D:\a", Win64Path = @"D:\a\Win64" },
            new DetectedGame { Name = "Mortal Shell II", InstallPath = @"D:\b", Win64Path = @"D:\b\Win64" }
        };

        var hit = GameResolver.Find("fatal", games);
        Assert.Equal("Fatal Claw", hit?.Name);
    }

    [Fact]
    public void Returns_null_when_ambiguous()
    {
        var games = new[]
        {
            new DetectedGame { Name = "Mortal Shell", InstallPath = @"D:\a", Win64Path = @"D:\a\Win64" },
            new DetectedGame { Name = "Mortal Shell II", InstallPath = @"D:\b", Win64Path = @"D:\b\Win64" }
        };

        Assert.Null(GameResolver.Find("Mortal", games));
    }
}
