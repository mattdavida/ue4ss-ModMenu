using System.Text.Json;
using System.Text.Json.Serialization;

namespace ModMenu.Harness;

public sealed class InGameResults
{
    [JsonPropertyName("ok")]
    public bool Ok { get; set; }

    [JsonPropertyName("schema")]
    public int Schema { get; set; }

    [JsonPropertyName("instanceId")]
    public string? InstanceId { get; set; }

    [JsonPropertyName("dock")]
    public string? Dock { get; set; }

    [JsonPropertyName("open")]
    public bool Open { get; set; }

    [JsonPropertyName("tabs")]
    public List<string> Tabs { get; set; } = [];

    [JsonPropertyName("tab")]
    public string? Tab { get; set; }

    [JsonPropertyName("sections")]
    public List<string> Sections { get; set; } = [];

    [JsonPropertyName("passed")]
    public int Passed { get; set; }

    [JsonPropertyName("failed")]
    public int Failed { get; set; }

    [JsonPropertyName("failures")]
    public List<string> HostFailures { get; set; } = [];

    [JsonPropertyName("errors")]
    public List<string> Errors { get; set; } = [];

    [JsonIgnore]
    public List<string> Failures { get; set; } = [];

    public static InGameResults Parse(string json)
    {
        var result = JsonSerializer.Deserialize<InGameResults>(json.Trim());
        if (result is null)
            throw new InvalidOperationException("In-game results JSON was empty.");

        return result;
    }

    public static InGameResults Combine(InGameResults primary, InGameResults peer)
    {
        var failures = primary.Failures
            .Concat(peer.Failures.Select(line => "Harness B: " + line))
            .ToList();
        return new InGameResults
        {
            Ok = failures.Count == 0,
            Schema = Math.Max(primary.Schema, peer.Schema),
            InstanceId = primary.InstanceId,
            Dock = primary.Dock,
            Open = primary.Open,
            Tabs = primary.Tabs,
            Tab = primary.Tab,
            Sections = primary.Sections,
            Passed = primary.Passed + peer.Passed,
            Failed = primary.Failed + peer.Failed,
            HostFailures = primary.HostFailures.Concat(peer.HostFailures).ToList(),
            Errors = primary.Errors.Concat(peer.Errors).ToList(),
            Failures = failures
        };
    }

    public static InGameResults Evaluate(string json, InGameResultExpect? expect = null)
    {
        expect ??= InGameResultExpect.Primary;
        var result = Parse(json);
        var failures = new List<string>();

        if (!string.Equals(result.InstanceId, expect.InstanceId, StringComparison.Ordinal))
            failures.Add($"instanceId: got {result.InstanceId ?? "null"} want {expect.InstanceId}");
        if (expect.Dock is not null && !string.Equals(result.Dock, expect.Dock, StringComparison.Ordinal))
            failures.Add($"dock: got {result.Dock ?? "null"} want {expect.Dock}");
        if (!result.Open)
            failures.Add("menu was not open");

        if (result.Schema >= 2)
        {
            if (result.Passed <= 0)
                failures.Add("host ran no checks");
            if (result.Failed > 0 || result.HostFailures.Count > 0)
                failures.AddRange(result.HostFailures.Select(line => "host: " + line));
            if (!result.Ok && result.HostFailures.Count == 0 && result.Failed == 0)
                failures.Add("host reported ok=false");
        }
        else
        {
            if (!result.Ok)
                failures.Add("host reported ok=false");
            if (!string.Equals(result.Dock, "left", StringComparison.Ordinal))
                failures.Add($"dock: got {result.Dock ?? "null"} want left");
            if (!result.Tabs.Contains("Cheats", StringComparer.Ordinal))
                failures.Add("tabs missing Cheats");
            if (!result.Tabs.Contains("Give", StringComparer.Ordinal))
                failures.Add("tabs missing Give");
            if (!result.Sections.Contains("Status", StringComparer.Ordinal))
                failures.Add("sections missing Status");
            if (!result.Sections.Contains("Widgets", StringComparer.Ordinal))
                failures.Add("sections missing Widgets");
        }

        if (result.Errors.Count > 0)
            failures.AddRange(result.Errors.Select(err => "host: " + err));

        result.Failures = failures;
        result.Ok = failures.Count == 0;
        return result;
    }
}

public sealed class InGameResultExpect
{
    public string InstanceId { get; init; } = HostDeploy.ModName;
    public string? Dock { get; init; }

    public static InGameResultExpect Primary { get; } = new();

    public static InGameResultExpect Peer { get; } = new()
    {
        InstanceId = HostDeploy.PeerModName,
        Dock = "right"
    };
}
