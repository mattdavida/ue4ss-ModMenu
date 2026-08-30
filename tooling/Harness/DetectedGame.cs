namespace ModMenu.Harness;

public sealed class DetectedGame
{
    public required string Name { get; init; }
    public required string InstallPath { get; init; }
    public required string Win64Path { get; init; }
    public string? AppId { get; init; }
    public string? ExePath { get; init; }
    public string? ArtworkPath { get; init; }

    public string Initial
    {
        get
        {
            foreach (var c in Name)
            {
                if (char.IsLetterOrDigit(c))
                    return char.ToUpperInvariant(c).ToString();
            }

            return "?";
        }
    }

    public bool HasUe4ss => Ue4ssLayout.IsInstalled(Win64Path);

    public string Ue4ssLabel => HasUe4ss ? "ue4ss" : "no-ue4ss";
}
