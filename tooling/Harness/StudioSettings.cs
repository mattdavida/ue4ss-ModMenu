using System.Text.Json;
using System.Text.Json.Serialization;

namespace ModMenu.Harness;

public sealed class StudioSettings
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    [JsonPropertyName("lastGameName")]
    public string? LastGameName { get; set; }

    [JsonPropertyName("lastInstallPath")]
    public string? LastInstallPath { get; set; }

    public static string DefaultPath => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "ModMenu.Studio",
        "settings.json");

    public static StudioSettings Load(string? path = null)
    {
        var file = path ?? DefaultPath;
        if (!File.Exists(file))
            return new StudioSettings();

        try
        {
            var text = File.ReadAllText(file);
            return JsonSerializer.Deserialize<StudioSettings>(text, JsonOptions) ?? new StudioSettings();
        }
        catch (JsonException)
        {
            return new StudioSettings();
        }
    }

    public static void Save(StudioSettings settings, string? path = null)
    {
        var file = path ?? DefaultPath;
        var dir = Path.GetDirectoryName(file);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        File.WriteAllText(file, JsonSerializer.Serialize(settings, JsonOptions));
    }

    /// <summary>
    /// Last game only if that install path still exists in the list. Gone installs are unset.
    /// </summary>
    public static DetectedGame? MatchLast(IReadOnlyList<DetectedGame> games, StudioSettings settings)
    {
        if (string.IsNullOrWhiteSpace(settings.LastInstallPath))
            return null;

        return games.FirstOrDefault(game =>
            string.Equals(game.InstallPath, settings.LastInstallPath, StringComparison.OrdinalIgnoreCase));
    }

    public static StudioSettings FromGame(DetectedGame game) => new()
    {
        LastGameName = game.Name,
        LastInstallPath = game.InstallPath
    };
}
