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
    if (argv.Any(a => a is "--game" || a.StartsWith("--game=", StringComparison.Ordinal)))
    {
        Console.Error.WriteLine("In-game `test --game` is not implemented yet. Run `modmenu test` for the no-game Lua suite.");
        return 2;
    }

    var result = LuaSuite.Run();
    Console.WriteLine($"{result.Passed} passed, {result.Failed} failed.");
    foreach (var failure in result.Failures)
        Console.Error.WriteLine("  " + failure);

    return result.Ok ? 0 : 1;
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
        modmenu — ModMenu CLI (no-game tests + Steam detect)

          detect          List Unreal Steam games (Win64 + whether UE4SS is present)
          test            Run the Lua unit suite (no game)
          test --game …   Not yet (in-game harness)

        dotnet test tooling/ModMenu.sln
        """);
}
