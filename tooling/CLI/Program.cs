using ModMenu.Harness;

if (args.Length == 0 || args[0] is "-h" or "--help" or "help")
{
    PrintHelp();
    return 0;
}

try
{
    return args[0] switch
    {
        "detect" => Detect(),
        "test" => Test(args),
        _ => Unknown(args[0])
    };
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex.Message);
    return 1;
}

static int Detect()
{
    var games = SteamScanner.FindUnrealGames();
    if (games.Count == 0)
    {
        Console.WriteLine("No Unreal Steam games found.");
        return 0;
    }

    foreach (var game in games)
    {
        var ue4ss = Ue4ssLayout.IsInstalled(game.Win64Path) ? "ue4ss" : "no-ue4ss";
        Console.WriteLine($"{game.Name}\t{ue4ss}\t{game.Win64Path}");
    }

    return 0;
}

static int Test(string[] argv)
{
    var gameQuery = ParseOption(argv, "--game");
    if (gameQuery is null)
    {
        var result = LuaSuite.Run();
        foreach (var check in result.Tests)
        {
            if (check.Ok)
                Console.WriteLine("  PASS  " + check.Name);
            else
                Console.Error.WriteLine("  FAIL  " + check.Name + (string.IsNullOrEmpty(check.Detail) ? "" : ": " + check.Detail));
        }

        Console.WriteLine($"{result.Passed} passed, {result.Failed} failed.");

        return result.Ok ? 0 : 1;
    }

    var game = GameResolver.Find(gameQuery);
    if (game is null)
    {
        Console.Error.WriteLine($"No unique game matched {gameQuery}. Run `modmenu detect`.");
        return 2;
    }

    var inGame = InGameTest.Run(game, new InGameTestOptions
    {
        SkipLaunch = argv.Any(a => a is "--skip-launch"),
        PlayLive = argv.Any(a => a is "--play-live"),
        Log = Console.WriteLine
    });

    if (inGame.Passed > 0 || inGame.Failed > 0)
        Console.WriteLine($"{inGame.Passed} host checks passed, {inGame.Failed} failed.");
    foreach (var failure in inGame.Failures)
        Console.Error.WriteLine("  " + failure);

    Console.WriteLine(inGame.Ok ? "In-game harness ok." : "In-game harness failed.");
    return inGame.Ok ? 0 : 1;
}

static string? ParseOption(string[] argv, string name)
{
    for (var i = 0; i < argv.Length; i++)
    {
        if (argv[i].Equals(name, StringComparison.Ordinal) && i + 1 < argv.Length)
            return argv[i + 1];

        const string prefix = "--game=";
        if (name == "--game" && argv[i].StartsWith(prefix, StringComparison.Ordinal))
            return argv[i][prefix.Length..];
    }

    return null;
}

static int Unknown(string command)
{
    Console.Error.WriteLine($"Unknown command: {command}");
    PrintHelp();
    return 2;
}

static void PrintHelp()
{
    Console.WriteLine("""
        modmenu — ModMenu CLI

          detect                         List Unreal Steam games
          test                           No-game Lua suite
          test --game "Fatal Claw"       Deploy host, launch via Steam, poll results, remove host
          test --game "Fatal Claw" --skip-launch
          test --game "Fatal Claw" --play-live   Step the suite in-game with delays so you can watch

        dotnet test tooling/ModMenu.sln
        """);
}
