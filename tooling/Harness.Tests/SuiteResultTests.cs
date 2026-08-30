namespace ModMenu.Harness.Tests;

public sealed class SuiteResultTests
{
    [Fact]
    public void Parses_ok_summary()
    {
        var result = SuiteResult.Parse("""{"ok":true,"passed":12,"failed":0,"failures":[]}""");
        Assert.True(result.Ok);
        Assert.Equal(12, result.Passed);
        Assert.Equal(0, result.Failed);
        Assert.Empty(result.Failures);
    }

    [Fact]
    public void Parses_failures()
    {
        var result = SuiteResult.Parse("""{"ok":false,"passed":1,"failed":1,"failures":["dock: got 0 want 1"]}""");
        Assert.False(result.Ok);
        Assert.Equal("dock: got 0 want 1", Assert.Single(result.Failures));
    }

    [Fact]
    public void Parses_each_check()
    {
        var result = SuiteResult.Parse("""
            {"ok":true,"passed":1,"failed":0,"failures":[],
             "tests":[{"name":"Get default dock","ok":true}]}
            """);
        var check = Assert.Single(result.Tests);
        Assert.Equal("Get default dock", check.Name);
        Assert.True(check.Ok);
    }
}
