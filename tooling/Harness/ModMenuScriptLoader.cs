using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;

namespace ModMenu.Harness;

internal sealed class ModMenuScriptLoader : ScriptLoaderBase
{
    private readonly string _repo;

    public ModMenuScriptLoader(string repo)
    {
        _repo = repo;
        ModulePaths = ["?"];
    }

    public override bool ScriptFileExists(string name)
        => File.Exists(Resolve(name));

    public override object LoadFile(string file, Table globalContext)
        => File.ReadAllText(Resolve(file));

    public override string ResolveFileName(string filename, Table globalContext)
        => Resolve(filename);

    private string Resolve(string name)
    {
        var trimmed = name.Trim().Replace('\\', '/');
        if (Path.IsPathRooted(name) && File.Exists(name))
            return name;

        // MoonSharp ScriptLoaderBase turns dots into slashes before Resolve.
        if (IsModMenuModule(trimmed, "ConfigManager"))
            return Path.Combine(_repo, "ConfigManager.lua");

        if (trimmed.StartsWith("ModMenu.", StringComparison.Ordinal)
            || trimmed.StartsWith("ModMenu/", StringComparison.OrdinalIgnoreCase))
        {
            var rest = trimmed.StartsWith("ModMenu.", StringComparison.Ordinal)
                ? trimmed["ModMenu.".Length..].Replace('.', Path.DirectorySeparatorChar)
                : trimmed["ModMenu/".Length..].Replace('/', Path.DirectorySeparatorChar);
            if (!rest.EndsWith(".lua", StringComparison.OrdinalIgnoreCase))
                rest += ".lua";
            return Path.Combine(_repo, rest);
        }

        var fileName = Path.GetFileName(trimmed);
        if (!fileName.EndsWith(".lua", StringComparison.OrdinalIgnoreCase))
            fileName += ".lua";

        var underLua = Path.Combine(_repo, "tooling", "lua", fileName);
        if (File.Exists(underLua))
            return underLua;

        return Path.Combine(_repo, trimmed.Replace('/', Path.DirectorySeparatorChar));
    }

    private static bool IsModMenuModule(string trimmed, string module)
    {
        return trimmed.Equals("ModMenu." + module, StringComparison.OrdinalIgnoreCase)
            || trimmed.Equals("ModMenu/" + module, StringComparison.OrdinalIgnoreCase)
            || trimmed.Equals("ModMenu/" + module + ".lua", StringComparison.OrdinalIgnoreCase);
    }
}
