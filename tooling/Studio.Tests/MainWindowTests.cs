using System.Collections;
using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.Interactivity;
using Avalonia.Threading;
using ModMenu.Harness;

namespace ModMenu.Studio.Tests;

[Collection("StudioWindow")]
public sealed class MainWindowTests
{
    [AvaloniaFact]
    public void Empty_catalog_opens_the_picker_and_disables_launch()
    {
        var window = Open(new StudioSettings(), []);

        Assert.True(window.PickerOverlay.IsVisible);
        Assert.False(window.InGameTestButton.IsEnabled);
        Assert.False(window.InGameLiveTestButton.IsEnabled);
        Assert.Equal("<select game>", window.SelectGameLabel.Text);
        Assert.Contains("Refresh", window.LogBox.Text, StringComparison.Ordinal);
        Assert.Contains("UE4SS Installer", window.EmptyGamesHint.Text, StringComparison.Ordinal);
        Assert.True(window.EmptyGamesHint.IsVisible);
    }

    [AvaloniaFact]
    public void Remembered_install_skips_the_picker_and_enables_launch()
    {
        var claw = Game("Fatal Claw", @"D:\games\Fatal Claw");
        var window = Open(
            new StudioSettings
            {
                LastGameName = "Fatal Claw",
                LastInstallPath = claw.InstallPath
            },
            [claw]);

        Assert.False(window.PickerOverlay.IsVisible);
        Assert.True(window.InGameTestButton.IsEnabled);
        Assert.True(window.InGameLiveTestButton.IsEnabled);
        Assert.Equal("Fatal Claw", window.SelectGameLabel.Text);
        Assert.Equal("Fatal Claw", window.SelectedName.Text);
    }

    [AvaloniaFact]
    public void Refresh_rebinds_a_game_that_appeared_after_open()
    {
        var catalog = new List<DetectedGame>();
        var window = Open(
            new StudioSettings(),
            _ => catalog.ToList());

        Assert.DoesNotContain("Mortal Shell II", Names(window));

        catalog.Add(Game("Mortal Shell II", @"D:\SteamLibrary\steamapps\common\Sparta"));
        window.RefreshGamesButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));

        Assert.Contains("Mortal Shell II", Names(window));
        Assert.True(window.PickerOverlay.IsVisible);
        Assert.Contains("Found 1 UE4SS game.", window.LogBox.Text, StringComparison.Ordinal);
    }

    [AvaloniaFact]
    public void Picking_a_game_hides_the_picker_and_remembers_it()
    {
        DetectedGame? persisted = null;
        var claw = Game("Fatal Claw", @"D:\games\Fatal Claw");
        var window = Open(new StudioSettings(), [claw], game => persisted = game);

        var row = Assert.Single(Rows(window));
        window.GamesList.SelectedItem = row;

        Assert.False(window.PickerOverlay.IsVisible);
        Assert.True(window.InGameTestButton.IsEnabled);
        Assert.Equal("Fatal Claw", window.SelectGameLabel.Text);
        Assert.Same(claw, persisted);
    }

    [AvaloniaFact]
    public async Task Run_Lua_tests_lists_each_check()
    {
        var window = Open(new StudioSettings(), []);
        window.LuaTestsButton.RaiseEvent(new RoutedEventArgs(Button.ClickEvent));

        var log = await WaitForLog(window, "Get default dock", TimeSpan.FromSeconds(15));
        Assert.Contains("PASS  Get default dock", log, StringComparison.Ordinal);
        Assert.Contains("passed", log, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("FAIL  ", log, StringComparison.Ordinal);
    }

    private static MainWindow Open(
        StudioSettings settings,
        IReadOnlyList<DetectedGame> games,
        Action<DetectedGame>? persist = null)
        => Open(settings, _ => games, persist);

    private static MainWindow Open(
        StudioSettings settings,
        Func<StudioSettings, IReadOnlyList<DetectedGame>> loadGames,
        Action<DetectedGame>? persist = null)
    {
        var window = new MainWindow
        {
            LoadSettings = () => settings,
            LoadUe4ssGames = loadGames,
            PersistGame = persist ?? (_ => { })
        };
        window.Show();
        return window;
    }

    private static DetectedGame Game(string name, string install) => new()
    {
        Name = name,
        InstallPath = install,
        Win64Path = Path.Combine(install, "Binaries", "Win64")
    };

    private static IReadOnlyList<string> Names(MainWindow window)
        => Rows(window).Select(row => row.Name).ToList();

    private static IReadOnlyList<GameRow> Rows(MainWindow window)
        => window.GamesList.ItemsSource is IEnumerable items
            ? items.Cast<GameRow>().ToList()
            : [];

    private static async Task<string> WaitForLog(MainWindow window, string needle, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            Dispatcher.UIThread.RunJobs();
            var text = window.LogBox.Text ?? "";
            if (text.Contains(needle, StringComparison.Ordinal))
                return text;
            await Task.Delay(50);
        }

        return window.LogBox.Text ?? "";
    }
}

[CollectionDefinition("StudioWindow", DisableParallelization = true)]
public sealed class StudioWindowCollection;
