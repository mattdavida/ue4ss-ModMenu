namespace ModMenu.Harness;

public static class GameResolver
{
    public static DetectedGame? Find(string query, IReadOnlyList<DetectedGame>? games = null)
    {
        if (string.IsNullOrWhiteSpace(query))
            return null;

        games ??= GameCatalog.Load(StudioSettings.Load());
        var exact = games.FirstOrDefault(game =>
            string.Equals(game.Name, query, StringComparison.OrdinalIgnoreCase));
        if (exact is not null)
            return exact;

        var hits = games
            .Where(game => game.Name.Contains(query, StringComparison.OrdinalIgnoreCase))
            .ToList();
        return hits.Count == 1 ? hits[0] : null;
    }
}
