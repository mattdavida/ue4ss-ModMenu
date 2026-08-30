using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Threading;
using ModMenu.Harness;

namespace ModMenu.Studio;

public partial class MainWindow : Window
{
    private readonly List<GameRow> _games = [];
    private DetectedGame? _selected;
    private bool _busy;
    private bool _applyingPickerSelection;

    internal Func<StudioSettings> LoadSettings { get; set; } = () => StudioSettings.Load();
    internal Action<DetectedGame> PersistGame { get; set; } = game => StudioSettings.Save(StudioSettings.FromGame(game));
    internal Func<StudioSettings, IReadOnlyList<DetectedGame>> LoadUe4ssGames { get; set; } =
        settings => GameCatalog.Load(settings).Where(game => game.HasUe4ss).ToList();

    public MainWindow()
    {
        InitializeComponent();
        Opened += (_, _) => ReloadGames();
    }

    private void OnRefreshGamesClick(object? sender, RoutedEventArgs e)
    {
        if (_busy)
            return;

        Log("Refreshing UE4SS games…");
        ReloadGames(keepPicker: true);
        if (_games.Count > 0)
            Log(_games.Count == 1 ? "Found 1 UE4SS game." : $"Found {_games.Count} UE4SS games.");
    }

    private void ReloadGames(bool keepPicker = false)
    {
        var settings = LoadSettings();
        var previous = _selected;
        _games.Clear();
        foreach (var game in LoadUe4ssGames(settings))
            _games.Add(ToRow(game));

        ApplyFilter();

        if (_games.Count == 0)
        {
            ApplySelected(null, persist: false);
            if (!keepPicker)
                ShowPicker();
            Log("No UE4SS games found. Install UE4SS with UE4SS Installer, then Refresh.");
            return;
        }

        DetectedGame? next = null;
        if (previous is not null)
            next = _games.Select(row => row.Game).FirstOrDefault(game => SameInstall(game, previous));
        next ??= StudioSettings.MatchLast(_games.Select(row => row.Game).ToList(), settings);

        if (next is not null)
        {
            ApplySelected(next, persist: false);
            if (keepPicker)
                ApplyFilter();
            return;
        }

        ApplySelected(null, persist: false);
        if (!keepPicker)
            ShowPicker();
        Log("Pick a UE4SS game to run Launch and test.");
    }

    private static GameRow ToRow(DetectedGame game) => new()
    {
        Game = game,
        Icon = GameIconLoader.Load(game.ExePath, game.ArtworkPath)
    };

    private void ApplyFilter()
    {
        var query = SearchBox.Text?.Trim() ?? "";
        var filtered = string.IsNullOrEmpty(query)
            ? _games.ToList()
            : _games.Where(row => row.Name.Contains(query, StringComparison.OrdinalIgnoreCase)).ToList();

        _applyingPickerSelection = true;
        GamesList.ItemsSource = filtered;
        GamesList.SelectedItem = _selected is null
            ? null
            : filtered.FirstOrDefault(row => SameInstall(row.Game, _selected));
        _applyingPickerSelection = false;

        SearchBox.IsVisible = _games.Count > 0;
        if (_games.Count == 0)
        {
            EmptyGamesHint.Text = "Install UE4SS into a game with UE4SS Installer, then Refresh.";
            EmptyGamesHint.IsVisible = true;
        }
        else if (filtered.Count == 0)
        {
            EmptyGamesHint.Text = "No matching UE4SS game.";
            EmptyGamesHint.IsVisible = true;
        }
        else
        {
            EmptyGamesHint.IsVisible = false;
        }
    }

    private void OnSearchChanged(object? sender, TextChangedEventArgs e) => ApplyFilter();

    private void OnSelectGameClick(object? sender, RoutedEventArgs e) => ShowPicker();

    private void OnPickerCloseClick(object? sender, RoutedEventArgs e) => HidePicker();

    private void OnPickerGameSelected(object? sender, SelectionChangedEventArgs e)
    {
        if (_applyingPickerSelection)
            return;
        if (GamesList.SelectedItem is not GameRow row)
            return;

        ApplySelected(row.Game, persist: true);
        HidePicker();
        Log($"Using {row.Name}.");
    }

    private void OnPickerBackdropPressed(object? sender, PointerPressedEventArgs e)
    {
        if (_selected is not null)
            HidePicker();
    }

    private void OnWindowKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape && PickerOverlay.IsVisible)
        {
            HidePicker();
            e.Handled = true;
        }
    }

    private void ShowPicker()
    {
        PickerOverlay.IsVisible = true;
        ApplyFilter();
        if (SearchBox.IsVisible)
            SearchBox.Focus();
    }

    private void HidePicker() => PickerOverlay.IsVisible = false;

    private void ApplySelected(DetectedGame? game, bool persist)
    {
        _selected = game;
        if (game is null)
        {
            SelectGameLabel.Text = "<select game>";
            NavGlyph.IsVisible = false;
            NavIcon.Source = null;
            NavIconBorder.IsVisible = false;
            NavInitialBorder.IsVisible = false;
            SelectedName.Text = _games.Count == 0 ? "No UE4SS game" : "No game selected";
            SelectedPath.Text = _games.Count == 0
                ? "Install UE4SS into a game with UE4SS Installer, then Refresh."
                : "Choose a UE4SS game from the navbar.";
            SelectedStatus.Text = "";
            SetInGameButtonsEnabled(false);
            return;
        }

        var row = _games.FirstOrDefault(item => SameInstall(item.Game, game));
        SelectGameLabel.Text = game.Name;
        NavGlyph.IsVisible = true;
        NavIcon.Source = row?.Icon;
        NavIconBorder.IsVisible = row?.HasIcon == true;
        NavInitialBorder.IsVisible = row?.HasIcon != true;
        NavInitial.Text = game.Initial;
        SelectedName.Text = game.Name;
        SelectedPath.Text = game.Win64Path;
        SelectedStatus.Text = "UE4SS is present.";
        SetInGameButtonsEnabled(!_busy);
        if (persist)
            PersistGame(game);
    }

    private async void OnRunLuaTestsClick(object? sender, RoutedEventArgs e)
    {
        if (_busy)
            return;

        SetBusy(true);
        Log("Running no-game Lua suite…");
        try
        {
            var result = await Task.Run(() => LuaSuite.Run());
            foreach (var check in result.Tests)
            {
                if (check.Ok)
                    Log("  PASS  " + check.Name);
                else
                    Log("  FAIL  " + check.Name + (string.IsNullOrEmpty(check.Detail) ? "" : ": " + check.Detail));
            }

            Log($"{result.Passed} passed, {result.Failed} failed.");
            if (result.Ok)
                Log("Lua suite ok.");
        }
        catch (Exception ex)
        {
            Log("Lua suite failed to run: " + ex.Message);
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void OnInGameTestClick(object? sender, RoutedEventArgs e)
        => _ = RunInGameTest(playLive: false);

    private void OnInGameLiveTestClick(object? sender, RoutedEventArgs e)
        => _ = RunInGameTest(playLive: true);

    private async Task RunInGameTest(bool playLive)
    {
        if (_busy || _selected is null)
            return;

        var game = _selected;
        SetBusy(true);
        Log(playLive
            ? $"Launch and test live: {game.Name} (suite steps with delays)"
            : $"Launch and test: {game.Name}");
        try
        {
            var result = await Task.Run(() => InGameTest.Run(game, new InGameTestOptions
            {
                PlayLive = playLive,
                Log = line => Log(line)
            }));
            if (result.Passed > 0 || result.Failed > 0)
                Log($"{result.Passed} host checks passed, {result.Failed} failed.");
            foreach (var failure in result.Failures)
                Log("  " + failure);
            Log(result.Ok ? "In-game harness ok." : "In-game harness failed.");
        }
        catch (Exception ex)
        {
            Log("In-game test failed to run: " + ex.Message);
        }
        finally
        {
            SetBusy(false);
        }
    }

    private void SetBusy(bool busy)
    {
        _busy = busy;
        SetInGameButtonsEnabled(!busy && _selected is not null);
    }

    private void SetInGameButtonsEnabled(bool enabled)
    {
        InGameTestButton.IsEnabled = enabled;
        InGameLiveTestButton.IsEnabled = enabled;
    }

    private static bool SameInstall(DetectedGame a, DetectedGame b)
        => string.Equals(a.InstallPath, b.InstallPath, StringComparison.OrdinalIgnoreCase);

    private void Log(string line)
    {
        void Append()
        {
            var stamp = DateTime.Now.ToString("HH:mm:ss");
            var next = $"[{stamp}] {line}";
            LogBox.Text = string.IsNullOrEmpty(LogBox.Text) ? next : LogBox.Text + Environment.NewLine + next;
            LogBox.CaretIndex = LogBox.Text.Length;
        }

        if (Dispatcher.UIThread.CheckAccess())
            Append();
        else
            Dispatcher.UIThread.Post(Append);
    }
}
