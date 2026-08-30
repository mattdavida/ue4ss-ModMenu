namespace ModMenu.Harness;

public static class RepoRoot
{
    public static string Find()
    {
        foreach (var start in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
        {
            var dir = new DirectoryInfo(start);
            for (var i = 0; i < 10 && dir is not null; i++)
            {
                if (File.Exists(Path.Combine(dir.FullName, "ModMenu.lua")))
                    return dir.FullName;

                dir = dir.Parent;
            }
        }

        throw new InvalidOperationException(
            "Could not find ModMenu.lua. Run from the ModMenu repo, or set the working directory to it.");
    }
}
