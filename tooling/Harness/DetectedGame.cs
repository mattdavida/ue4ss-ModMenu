namespace ModMenu.Harness;

public sealed class DetectedGame
{
    public required string Name { get; init; }
    public required string InstallPath { get; init; }
    public required string Win64Path { get; init; }
    public string? AppId { get; init; }
    public string? ExePath { get; init; }
}
