--[[
  ModMenuHarnessB — second independent shell (docked right).

  A separate enabled Lua mod so require("ModMenu.ModMenu") is a different
  state from Harness A (the hero-page setup). Waits for A's results, then
  Opens only after A has closed. Does not assert dual-open.
]]

local ModMenu = require("ModMenu.ModMenu")
local ConfigManager = ModMenu.ConfigManager

local INSTANCE = "ModMenuHarnessB"
local PEER = "ModMenuHarness"
local wrote = false
local ran = false
local passed = 0
local failed = 0
local failures = {}
local hold = {}

local function ModRoot()
    local src = debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", ""):gsub("\\", "/")
    return src:match("^(.*)/Scripts/")
end

local function FileExists(path)
    local f = io.open(path, "r")
    if not f then
        return false
    end
    f:close()
    return true
end

local playLive = FileExists((ModRoot() or ".") .. "/play-live.txt")
local STEP_MS = playLive and 750 or 0
local SLOW_MS = playLive and 1600 or 0

local function Encode(value)
    local t = type(value)
    if value == nil then
        return "null"
    end
    if t == "boolean" then
        return value and "true" or "false"
    end
    if t == "number" then
        return tostring(value)
    end
    if t == "string" then
        return string.format("%q", value)
    end
    if t ~= "table" then
        return string.format("%q", tostring(value))
    end
    local max = 0
    local asObject = false
    for k in pairs(value) do
        if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
            asObject = true
            break
        end
        if k > max then
            max = k
        end
    end
    if not asObject then
        local parts = {}
        for i = 1, max do
            parts[i] = Encode(value[i])
        end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(value) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    local parts = {}
    for i = 1, #keys do
        local k = keys[i]
        parts[#parts + 1] = Encode(tostring(k)) .. ":" .. Encode(value[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function DeepEq(a, b)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if type(a) == "number" then
        local d = a - b
        if d < 0 then
            d = -d
        end
        return d < 1e-9
    end
    if type(a) ~= "table" then
        return false
    end
    for k, v in pairs(a) do
        if not DeepEq(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

local function Log(msg)
    print("[ModMenuHarnessB] " .. tostring(msg))
end

local function Check(name, cond, detail)
    if cond then
        passed = passed + 1
        Log("PASS " .. name)
        return
    end
    failed = failed + 1
    local line = name .. (detail and (": " .. detail) or "")
    failures[#failures + 1] = line
    Log("FAIL " .. line)
end

local function AssertTrue(name, cond)
    Check(name, cond == true, "expected true")
end

local function AssertEq(name, got, want)
    if DeepEq(got, want) then
        passed = passed + 1
        Log("PASS " .. name)
        return
    end
    failed = failed + 1
    local line = name .. ": got " .. Encode(got) .. " want " .. Encode(want)
    failures[#failures + 1] = line
    Log("FAIL " .. line)
end

local function Has(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end
    return false
end

local function Ue4ssRoot()
    local src = debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", ""):gsub("\\", "/")
    return src:match("^(.*)/Mods/" .. INSTANCE .. "/")
end

local function ResultsPath()
    local ue4ss = Ue4ssRoot()
    if ue4ss and ue4ss ~= "" then
        return ue4ss .. "/" .. INSTANCE .. "-results.json"
    end
    return INSTANCE .. "-results.json"
end

local function PeerResultsPath()
    local ue4ss = Ue4ssRoot()
    if ue4ss and ue4ss ~= "" then
        return ue4ss .. "/" .. PEER .. "-results.json"
    end
    return PEER .. "-results.json"
end

local function ReadPeer()
    local path = PeerResultsPath()
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local text = f:read("*a") or ""
    f:close()
    return {
        instanceId = text:match('"instanceId"%s*:%s*"([^"]+)"'),
        serial = tonumber(text:match('"serial"%s*:%s*(%d+)')),
    }
end

local function WriteResults(errors)
    local payload = {
        ok = failed == 0 and (errors == nil or #errors == 0),
        schema = 2,
        instanceId = INSTANCE,
        serial = ModMenu.GetInstanceSerial(),
        dock = ModMenu.GetDock(),
        open = ModMenu.IsOpen(),
        tabs = { "Main", "Extra" },
        tab = ModMenu.GetTab(),
        sections = ModMenu.ListSections(),
        passed = passed,
        failed = failed,
        failures = failures,
        errors = errors or {},
    }
    local path = ResultsPath()
    local f, err = io.open(path, "w")
    if not f then
        Log("write failed " .. path .. " — " .. tostring(err))
        return false
    end
    f:write(Encode(payload))
    f:write("\n")
    f:close()
    Log(string.format("wrote %s (%d passed, %d failed)", path, passed, failed))
    wrote = true
    return true
end

ConfigManager.Init({
    id = INSTANCE,
    defaults = { dock = "right", who = "B" },
})

ModMenu.Init({
    title = "Harness B",
    instanceId = INSTANCE,
    theme = "light",
    key = Key.F9,
    keyHint = "F9",
    dock = ConfigManager.Get("dock"),
    consoleCommand = "modmenuharnessb",
    tabs = { "Main", "Extra" },
    fontTitle = 16,
    fontSection = 12,
    fontItem = 10,
    fontHint = 8,
    fontDropdown = 9,
})

ModMenu.Register({
    id = "Peer",
    title = "Peer",
    tab = "Main",
    items = {
        { type = "label", id = "ready", label = "Independent shell — docked right." },
        {
            type = "checkbox",
            id = "flag",
            label = "Flag",
            default = false,
        },
    },
})

ModMenu.Register({
    id = "Extra",
    title = "Extra",
    tab = "Extra",
    items = {
        {
            type = "dropdown",
            id = "gift",
            label = "Gift",
            options = { "Gold", "Gloom" },
            default = "Gold",
        },
    },
})

local function RunSuite()
    if ran then
        return
    end
    ran = true
    Log(playLive and "suite start (play-live)" or "suite start")

    local steps = {}
    local function T(fn, delay)
        steps[#steps + 1] = { fn = fn, delay = delay or STEP_MS }
    end

    T(function()
        AssertTrue("IsOpen", ModMenu.IsOpen())
        AssertEq("GetInstanceId", ModMenu.GetInstanceId(), INSTANCE)
        AssertTrue("GetInstanceSerial is number", type(ModMenu.GetInstanceSerial()) == "number")
        AssertEq("GetDock initial", ModMenu.GetDock(), "right")
        AssertEq("GetTab initial", ModMenu.GetTab(), "Main")
        AssertEq("ConfigManager dock", ConfigManager.Get("dock"), "right")
        AssertEq("ConfigManager who", ConfigManager.Get("who"), "B")
        ConfigManager.Set("who", "peer")
        AssertEq("ConfigManager Set who", ConfigManager.Get("who"), "peer")
        local file = ConfigManager.File()
        AssertTrue("B store is own config", type(file) == "string" and file:find(INSTANCE, 1, true) ~= nil)
    end)

    T(function()
        local peer = ReadPeer()
        AssertTrue("peer results exist", peer ~= nil)
        if peer then
            AssertEq("peer instanceId", peer.instanceId, PEER)
            if type(peer.serial) == "number" then
                AssertTrue("serial differs from A", ModMenu.GetInstanceSerial() ~= peer.serial)
            end
        end
    end)

    T(function()
        local sections = ModMenu.ListSections()
        AssertTrue("section Peer", Has(sections, "Peer"))
        AssertTrue("section Extra", Has(sections, "Extra"))
        AssertTrue("A Values is not on B", Has(sections, "Values") == false)
        AssertTrue("A Cheats tab is not B default", ModMenu.GetTab() ~= "Cheats")
    end)

    T(function()
        AssertEq("Get checkbox default", ModMenu.Get("Peer", "flag"), false)
        ModMenu.Set("Peer", "flag", true)
        AssertEq("Set/Get checkbox", ModMenu.Get("Peer", "flag"), true)
    end)

    T(function()
        AssertTrue("SetTab Extra", ModMenu.SetTab("Extra") == true)
        AssertEq("GetTab Extra", ModMenu.GetTab(), "Extra")
        AssertEq("Get on Extra tab", ModMenu.Get("Extra", "gift"), "Gold")
        ModMenu.Set("Extra", "gift", "Gloom")
        AssertEq("Set/Get Extra tab", ModMenu.Get("Extra", "gift"), "Gloom")
    end, SLOW_MS)

    T(function()
        AssertTrue("SetTab Main", ModMenu.SetTab("Main") == true)
        AssertEq("GetTab Main", ModMenu.GetTab(), "Main")
        AssertEq("GetDock still right", ModMenu.GetDock(), "right")
    end, SLOW_MS)

    T(function()
        AssertTrue("IsOpen after suite", ModMenu.IsOpen())
        Log(string.format("suite done: %d passed, %d failed", passed, failed))
        WriteResults({})
    end)

    local i = 0
    hold.Next = function()
        i = i + 1
        if i > #steps then
            return
        end
        local step = steps[i]
        local ok, err = pcall(step.fn)
        if not ok then
            Log("step error: " .. tostring(err))
            failed = failed + 1
            failures[#failures + 1] = tostring(err)
            if not wrote then
                WriteResults({ tostring(err) })
            end
            return
        end
        if wrote then
            return
        end
        local delay = step.delay or 0
        if delay > 0 then
            local scheduled = pcall(function()
                ExecuteInGameThreadWithDelay(delay, hold.Next)
            end)
            if not scheduled then
                hold.Next()
            end
        else
            hold.Next()
        end
    end
    hold.Next()
end

ModMenu.OnOpen(function()
    local ok, err = pcall(RunSuite)
    if not ok and not wrote then
        Log("suite error: " .. tostring(err))
        WriteResults({ tostring(err) })
    end
end)

Log(playLive and "loaded — play-live, waiting for Harness A" or "loaded — waiting for Harness A")

local function TryOpen()
    if wrote or ran then
        return wrote
    end
    if not FileExists(PeerResultsPath()) then
        return false
    end
    if ModMenu.IsOpen() then
        local ok, err = pcall(RunSuite)
        if not ok and not wrote then
            WriteResults({ tostring(err) })
        end
        return wrote
    end
    Log("Harness A finished — opening B (right)")
    pcall(function()
        ModMenu.Open()
    end)
    return wrote
end

pcall(function()
    LoopAsync(2000, function()
        if wrote then
            return true
        end
        return TryOpen()
    end)
end)
