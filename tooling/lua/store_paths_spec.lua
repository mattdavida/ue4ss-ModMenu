local Paths = require("ModMenu.store.paths")

assert_eq("Normalize slashes", Paths.Normalize([[D:\mods\Host]]), "D:/mods/Host")
assert_eq("Resolve explicit file", Paths.ResolveFile("Host", "/tmp/host-config.json"), "/tmp/host-config.json")
assert_eq("Resolve empty explicit falls through", Paths.ResolveFile("Host", ""), "ue4ss/Mods/Host/config.json")
assert_true("FileExists missing", Paths.FileExists((_REPO .. "/no-such-store-path.json"):gsub("\\", "/")) == false)
assert_true("FileExists ModMenu.lua", Paths.FileExists((_REPO .. "/ModMenu.lua"):gsub("\\", "/")) == true)
