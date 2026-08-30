--[[
  ModMenuHarness — in-game feature suite.

  After a 30s settle, opens the shell and exercises the public API
  (widgets + Set/Get + tabs + dock + live chrome). Each check is printed
  and written to ue4ss/ModMenuHarness-results.json.
]]

local ModMenu = require("ModMenu.ModMenu")

local INSTANCE = "ModMenuHarness"
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
    print("[ModMenuHarness] " .. tostring(msg))
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

local function ResultsPath()
    local src = debug.getinfo(1, "S").source or ""
    src = src:gsub("^@", ""):gsub("\\", "/")
    local ue4ss = src:match("^(.*)/Mods/" .. INSTANCE .. "/")
    if ue4ss and ue4ss ~= "" then
        return ue4ss .. "/" .. INSTANCE .. "-results.json"
    end
    return INSTANCE .. "-results.json"
end

local function WriteResults(errors)
    local payload = {
        ok = failed == 0 and (errors == nil or #errors == 0),
        schema = 2,
        instanceId = INSTANCE,
        dock = ModMenu.GetDock(),
        open = ModMenu.IsOpen(),
        tabs = { "Cheats", "Give", "Keybinds" },
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

ModMenu.Init({
    title = "ModMenu Harness",
    instanceId = INSTANCE,
    theme = "dark",
    key = Key.F8,
    keyHint = "F8",
    dock = "left",
    consoleCommand = "modmenuhost",
    tabs = { "Cheats", "Give", "Keybinds" },
    fontTitle = 16,
    fontSection = 12,
    fontItem = 10,
    fontHint = 8,
    fontDropdown = 9,
})

ModMenu.Register({
    id = "Status",
    title = "Status",
    tab = "Cheats",
    items = {
        { type = "label", id = "ready", label = "Harness suite — each check logs PASS/FAIL." },
        { type = "separator" },
    },
})

ModMenu.Register({
    id = "Values",
    title = "Values",
    tab = "Cheats",
    items = {
        {
            type = "checkbox",
            id = "flag",
            label = "Flag",
            default = false,
        },
        {
            type = "dropdown",
            id = "choice",
            label = "Choice",
            options = { "A", "B" },
            default = "A",
        },
        {
            type = "dropdown",
            id = "item",
            label = "Item",
            searchable = true,
            placeholder = "Select item...",
            maxVisible = 6,
            options = { "Ashen Flask", "Gold Coin", "Tarstone" },
        },
        {
            type = "textinput",
            id = "note",
            label = "Note",
            default = "",
            placeholder = "type",
        },
        {
            type = "row",
            items = {
                {
                    type = "number",
                    id = "amount",
                    label = "Amt",
                    default = 1,
                    min = 1,
                    max = 99,
                    integer = true,
                    labelWidth = 36,
                },
                {
                    type = "button",
                    id = "applyAmt",
                    label = "Apply",
                    onClick = function()
                        Log("applyAmt " .. tostring(ModMenu.Get("Values", "amount")))
                    end,
                },
            },
        },
    },
})

ModMenu.Register({
    id = "Buttons",
    title = "Buttons",
    tab = "Cheats",
    collapsible = true,
    collapsed = false,
    items = {
        {
            type = "button",
            id = "ping",
            label = "Ping",
            onClick = function()
                Log("ping")
            end,
        },
        {
            type = "button",
            id = "flip",
            label = "Flip",
            variant = "primary",
            onClick = function() end,
        },
        {
            type = "button",
            id = "modeA",
            label = "Mode A",
            active = true,
            onClick = function() end,
        },
        {
            type = "button",
            id = "modeB",
            label = "Mode B",
            onClick = function() end,
        },
        {
            type = "button",
            id = "gated",
            label = "Gated",
            enabled = false,
            onClick = function() end,
        },
    },
})

ModMenu.Register({
    id = "Give",
    title = "Give",
    tab = "Give",
    items = {
        { type = "label", id = "giveHint", label = "Tab target for SetTab." },
        {
            type = "dropdown",
            id = "gift",
            label = "Gift",
            options = { "Gold", "Gloom" },
            default = "Gold",
        },
    },
})

ModMenu.Register({
    id = "Keybinds",
    title = "Keybinds",
    tab = "Keybinds",
    collapsible = true,
    collapsed = false,
    items = {
        {
            type = "fold",
            id = "combatBinds",
            label = "Combat",
            collapsed = true,
            items = {
                {
                    type = "button",
                    id = "bindHeal",
                    label = "Heal: none",
                    onClick = function() end,
                },
            },
        },
        {
            type = "fold",
            id = "uiBinds",
            label = "UI",
            collapsed = true,
            items = {
                { type = "label", id = "foldNote", label = "Fold still registers." },
            },
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
        AssertEq("GetDock initial", ModMenu.GetDock(), "left")
        AssertEq("GetTab initial", ModMenu.GetTab(), "Cheats")
        AssertTrue("IsConfirmOpen idle", ModMenu.IsConfirmOpen() == false)
    end)

    T(function()
        local sections = ModMenu.ListSections()
        AssertTrue("section Status", Has(sections, "Status"))
        AssertTrue("section Values", Has(sections, "Values"))
        AssertTrue("section Buttons", Has(sections, "Buttons"))
        AssertTrue("section Give", Has(sections, "Give"))
        AssertTrue("section Keybinds", Has(sections, "Keybinds"))
    end)

    T(function()
        AssertEq("Get checkbox default", ModMenu.Get("Values", "flag"), false)
        ModMenu.Set("Values", "flag", true)
        AssertEq("Set/Get checkbox", ModMenu.Get("Values", "flag"), true)
    end)

    T(function()
        AssertEq("Get dropdown default", ModMenu.Get("Values", "choice"), "A")
        ModMenu.Set("Values", "choice", "B")
        AssertEq("Set/Get dropdown", ModMenu.Get("Values", "choice"), "B")
    end)

    T(function()
        ModMenu.Set("Values", "item", "Gold Coin")
        AssertEq("Set/Get searchable dropdown", ModMenu.Get("Values", "item"), "Gold Coin")
        AssertTrue(
            "SetOptions searchable",
            ModMenu.SetOptions("Values", "item", { "Apple", "Pear", "Plum" }, "Pear") == true
        )
        AssertEq("SetOptions selected", ModMenu.Get("Values", "item"), "Pear")
    end)

    T(function()
        AssertEq("Get number default", ModMenu.Get("Values", "amount"), 1)
        ModMenu.Set("Values", "amount", 7)
        AssertEq("Set/Get number in row", ModMenu.Get("Values", "amount"), 7)
        AssertEq("Get textinput default", ModMenu.Get("Values", "note"), "")
        ModMenu.Set("Values", "note", "hello")
        AssertEq("Set/Get textinput", ModMenu.Get("Values", "note"), "hello")
    end)

    T(function()
        AssertTrue("SetLabel", ModMenu.SetLabel("Status", "ready", "suite running") == true)
        AssertTrue("SetButtonLabel", ModMenu.SetButtonLabel("Buttons", "ping", "Pong") == true)
        AssertTrue("SetButtonEnabled on", ModMenu.SetButtonEnabled("Buttons", "gated", true) == true)
        AssertTrue("SetButtonEnabled off", ModMenu.SetButtonEnabled("Buttons", "gated", false) == true)
        AssertTrue("SetButtonVariant", ModMenu.SetButtonVariant("Buttons", "flip", "danger") == true)
        AssertTrue("SetButtonActive A", ModMenu.SetButtonActive("Buttons", "modeA", true) == true)
        AssertTrue("SetButtonActive B off", ModMenu.SetButtonActive("Buttons", "modeB", false) == true)
        AssertTrue("SetButtonLabel fold child", ModMenu.SetButtonLabel("Keybinds", "bindHeal", "Heal: F9") == true)
    end)

    T(function()
        AssertTrue("SetTab Give", ModMenu.SetTab("Give") == true)
        AssertEq("GetTab Give", ModMenu.GetTab(), "Give")
        AssertEq("Get on other tab", ModMenu.Get("Give", "gift"), "Gold")
        ModMenu.Set("Give", "gift", "Gloom")
        AssertEq("Set/Get other tab", ModMenu.Get("Give", "gift"), "Gloom")
    end, SLOW_MS)

    T(function()
        AssertTrue("SetTab Keybinds", ModMenu.SetTab("Keybinds") == true)
        AssertEq("GetTab Keybinds", ModMenu.GetTab(), "Keybinds")
    end, SLOW_MS)

    T(function()
        AssertTrue("SetTab Cheats", ModMenu.SetTab("Cheats") == true)
        AssertEq("GetTab Cheats", ModMenu.GetTab(), "Cheats")
    end, SLOW_MS)

    local docks = {}
    T(function()
        AssertTrue("OnDockChange exists", type(ModMenu.OnDockChange) == "function")
        if type(ModMenu.OnDockChange) == "function" then
            ModMenu.OnDockChange(function(side)
                docks[#docks + 1] = side
            end)
        end
    end)

    for _, side in ipairs({ "top", "right", "bottom", "left" }) do
        local dest = side
        T(function()
            ModMenu.SetDock(dest)
            AssertEq("GetDock " .. dest, ModMenu.GetDock(), dest)
            if type(ModMenu.OnDockChange) == "function" then
                AssertEq("OnDockChange " .. dest, docks[#docks], dest)
            end
        end, SLOW_MS)
    end

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

local SETTLE_TICKS = 15
local ticks = 0

Log(playLive and "loaded — play-live, waiting 30s before Open" or "loaded — waiting 30s before Open")

local function TryOpen()
    if wrote or ran then
        return wrote
    end
    if ModMenu.IsOpen() then
        local ok, err = pcall(RunSuite)
        if not ok and not wrote then
            WriteResults({ tostring(err) })
        end
        return wrote
    end
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
        ticks = ticks + 1
        if ticks < SETTLE_TICKS then
            if ticks == 1 or ticks % 5 == 0 then
                Log(string.format("settle %ds / 30s", ticks * 2))
            end
            return false
        end
        if ticks == SETTLE_TICKS then
            Log("settle done — opening menu")
        end
        return TryOpen()
    end)
end)
