using Avalonia.Media.Imaging;
using ModMenu.Harness;

namespace ModMenu.Studio;

public sealed class GameRow
{
    public required DetectedGame Game { get; init; }
    public Bitmap? Icon { get; init; }

    public string Name => Game.Name;
    public string Initial => Game.Initial;
    public string Ue4ssLabel => Game.Ue4ssLabel;
    public string InstallPath => Game.InstallPath;
    public bool HasIcon => Icon is not null;
}
