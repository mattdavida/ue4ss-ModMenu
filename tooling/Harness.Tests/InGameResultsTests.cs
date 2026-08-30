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

    [Fact]
    public void Accepts_harness_b_on_the_right()
    {
        var json = """
            {"ok":true,"schema":2,"instanceId":"ModMenuHarnessB","dock":"right","open":true,
             "tabs":["Main","Extra"],"tab":"Main","sections":["Peer","Extra"],
             "passed":8,"failed":0,"failures":[],"errors":[]}
            """;

        var result = InGameResults.Evaluate(json, InGameResultExpect.Peer);
        Assert.True(result.Ok, string.Join("\n", result.Failures));
        Assert.Equal(8, result.Passed);
    }

    [Fact]
    public void Combines_a_and_b_totals()
    {
        var a = InGameResults.Evaluate("""
            {"ok":true,"schema":2,"instanceId":"ModMenuHarness","dock":"left","open":true,
             "tabs":["Cheats"],"tab":"Cheats","sections":["Status"],
             "passed":40,"failed":0,"failures":[],"errors":[]}
            """);
        var b = InGameResults.Evaluate("""
            {"ok":false,"schema":2,"instanceId":"ModMenuHarnessB","dock":"left","open":true,
             "tabs":["Main"],"tab":"Main","sections":["Peer"],
             "passed":2,"failed":1,"failures":["GetDock initial: got left want right"],"errors":[]}
            """, InGameResultExpect.Peer);

        var combined = InGameResults.Combine(a, b);
        Assert.False(combined.Ok);
        Assert.Equal(42, combined.Passed);
        Assert.Contains(combined.Failures, line => line.StartsWith("Harness B:"));
    }
}
