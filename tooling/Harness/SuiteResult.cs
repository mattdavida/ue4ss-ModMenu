using System.Text.Json;
using System.Text.Json.Serialization;

namespace ModMenu.Harness;

public sealed class SuiteResult
{
    [JsonPropertyName("ok")]
    public bool Ok { get; set; }

    [JsonPropertyName("passed")]
    public int Passed { get; set; }

    [JsonPropertyName("failed")]
    public int Failed { get; set; }

    [JsonPropertyName("failures")]
    public List<string> Failures { get; set; } = [];

    public static SuiteResult Parse(string json)
    {
        try
        {
            var result = JsonSerializer.Deserialize<SuiteResult>(json.Trim());
            if (result is null)
                throw new InvalidOperationException("Suite JSON was empty.");

            return result;
        }
        catch (JsonException ex)
        {
            throw new InvalidOperationException("Suite JSON was not a result object: " + json.Trim(), ex);
        }
    }
}
