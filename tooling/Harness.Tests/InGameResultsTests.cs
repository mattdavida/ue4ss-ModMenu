namespace ModMenu.Harness.Tests;

public sealed class InGameResultsTests
{
    [Fact]
    public void Accepts_schema2_host_suite()
    {
        var json = """
            {"ok":true,"schema":2,"instanceId":"ModMenuHarness","dock":"left","open":true,
             "tabs":["Cheats","Give","Keybinds"],"tab":"Cheats",
             "sections":["Status","Values","Buttons","Give","Keybinds"],
             "passed":40,"failed":0,"failures":[],"errors":[]}
            """;

        var result = InGameResults.Evaluate(json);
        Assert.True(result.Ok, string.Join("\n", result.Failures));
        Assert.Equal(40, result.Passed);
    }

    [Fact]
    public void Surfaces_host_failures()
    {
        var json = """
            {"ok":false,"schema":2,"instanceId":"ModMenuHarness","dock":"left","open":true,
             "tabs":["Cheats"],"tab":"Cheats","sections":["Status"],
             "passed":1,"failed":1,"failures":["Set/Get checkbox: got false want true"],"errors":[]}
            """;

        var result = InGameResults.Evaluate(json);
        Assert.False(result.Ok);
        Assert.Contains(result.Failures, line => line.Contains("Set/Get checkbox"));
    }

    [Fact]
    public void Accepts_schema1_payload()
    {
        var json = """
            {"ok":true,"schema":1,"instanceId":"ModMenuHarness","dock":"left","open":true,
             "tabs":["Cheats","Give"],"tab":"Cheats","sections":["Status","Widgets"],"errors":[]}
            """;

        var result = InGameResults.Evaluate(json);
        Assert.True(result.Ok, string.Join("\n", result.Failures));
    }
}
