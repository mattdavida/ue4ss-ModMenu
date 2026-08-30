using MoonSharp.Interpreter;

namespace ModMenu.Harness;

public static class LuaSuite
{
    public static SuiteResult Run(string? repoRoot = null)
    {
        var repo = repoRoot ?? RepoRoot.Find();
        var runLua = Path.Combine(repo, "tooling", "lua", "run.lua");
        if (!File.Exists(runLua))
            throw new FileNotFoundException("Missing Lua suite entry.", runLua);

        var script = new Script(CoreModules.Preset_Complete)
        {
            Options =
            {
                ScriptLoader = new ModMenuScriptLoader(repo),
                DebugPrint = _ => { }
            }
        };
        script.Globals["_REPO"] = repo.Replace('\\', '/');

        DynValue result;
        using (var writer = new StringWriter())
        {
            var originalOut = Script.DefaultOptions.DebugPrint;
            script.Options.DebugPrint = s => writer.WriteLine(s);
            try
            {
                result = script.DoFile(runLua);
            }
            finally
            {
                script.Options.DebugPrint = originalOut;
            }

            var printed = writer.ToString().Trim();
            if (printed.Length > 0)
            {
                var last = printed.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Last();
                return SuiteResult.Parse(last);
            }
        }

        if (result.Type == DataType.Boolean && result.Boolean)
            return new SuiteResult { Ok = true, Passed = 0, Failed = 0 };

        throw new InvalidOperationException("Lua suite printed no JSON summary.");
    }
}
