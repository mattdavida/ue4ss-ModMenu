local Store = require("ModMenu.core.store")

local tmp = (_REPO .. "/tooling/.tmp-store-spec.json"):gsub("\\", "/")

pcall(os.remove, tmp)

Store.Init({
    id = "ModMenuStoreSpec",
    file = tmp,
    defaults = {
        dock = "top",
        volume = 1,
        keybinds = { menuToggle = "F6" },
    },
})

assert_eq("Get default dock", Store.Get("dock"), "top")
assert_eq("Get default volume", Store.Get("volume"), 1)
assert_true("no file until first Set", io.open(tmp, "r") == nil)

Store.Set("dock", "right")
assert_eq("Get after Set", Store.Get("dock"), "right")

local f = io.open(tmp, "r")
assert_true("Set writes file", f ~= nil)
if f then
    local text = f:read("*a")
    f:close()
    assert_true("file contains dock", text:find('"dock"', 1, true) ~= nil)
    assert_true("file contains right", text:find('"right"', 1, true) ~= nil)
end

local binds = Store.Get("keybinds")
binds.menuToggle = "F8"
assert_eq("Get copies tables", Store.Get("keybinds").menuToggle, "F6")

Store.Set("dock", "right")
assert_eq("Set same value is no-op", Store.Get("dock"), "right")

pcall(os.remove, tmp)
local bad = io.open(tmp, "w")
bad:write("{")
bad:close()

Store.Init({
    id = "ModMenuStoreSpec",
    file = tmp,
    defaults = { dock = "top" },
})
assert_eq("bad JSON uses default", Store.Get("dock"), "top")

local leftover = io.open(tmp, "r")
local leftoverText = leftover:read("*a")
leftover:close()
assert_eq("bad JSON left untouched", leftoverText, "{")

pcall(os.remove, tmp)

local viaShim = require("ModMenu.ConfigManager")
local viaCore = require("ModMenu.core.store")
local viaStore = require("ModMenu.store.init")
assert_true("ConfigManager shim is store.init", viaShim == viaStore)
assert_true("core.store shim is store.init", viaCore == viaStore)
assert_true("ConfigManager.Get exists", type(viaShim.Get) == "function")
assert_true("ConfigManager.Set exists", type(viaShim.Set) == "function")
assert_true("ConfigManager.Save exists", type(viaShim.Save) == "function")
assert_true("ConfigManager.File exists", type(viaShim.File) == "function")
