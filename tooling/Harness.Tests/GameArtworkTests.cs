namespace ModMenu.Harness.Tests;

public sealed class GameArtworkTests
{
    [Fact]
    public void Prefers_icon_over_other_cache_art()
    {
        using var temp = new TempDir();
        var icon = Path.Combine(temp.Path, "icon.jpg");
        var other = Path.Combine(temp.Path, "capsule.jpg");
        File.WriteAllBytes(icon, [1]);
        File.WriteAllBytes(other, [2]);

        Assert.Equal(icon, GameArtwork.RankArtwork([other, icon]));
    }

    [Fact]
    public void Skips_library_header_hero_logo()
    {
        using var temp = new TempDir();
        var hero = Path.Combine(temp.Path, "hero.jpg");
        var capsule = Path.Combine(temp.Path, "capsule.jpg");
        File.WriteAllBytes(hero, [1]);
        File.WriteAllBytes(capsule, [2]);

        Assert.Equal(capsule, GameArtwork.RankArtwork([hero, capsule]));
    }
}
