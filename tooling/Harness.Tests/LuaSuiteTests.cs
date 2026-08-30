namespace ModMenu.Harness.Tests;

public sealed class LuaSuiteTests
{
    [Fact]
    public void Lua_unit_suite_passes()
    {
        var result = LuaSuite.Run();
        Assert.True(result.Ok, string.Join("\n", result.Failures));
        Assert.True(result.Passed > 0);
        Assert.Equal(0, result.Failed);
        Assert.Equal(result.Passed, result.Tests.Count);
        Assert.All(result.Tests, check => Assert.False(string.IsNullOrWhiteSpace(check.Name)));
    }
}
