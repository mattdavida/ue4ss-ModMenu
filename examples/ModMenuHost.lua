--[[
  ModMenuHost — dummy showcase for ModMenu.

  Copy this folder into ue4ss/Mods/ (enabled.txt + Scripts/main.lua).
  Requires shared/ModMenu from the ModMenu repo (`npm run deploy`).

  F8 toggles this panel. F6 is Mortal Shell 2's real cheat menu — keep them
  on different keys. Every control prints [ModMenuHost] to the UE4SS console.
  Nothing here cheats; swap Log(...) for your game calls.
]]

local ModMenu = require("ModMenu.ModMenu")

ModMenu.Init({
    title = "ModMenu Host",
    instanceId = "ModMenuHost",
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

local flipDanger = false
local gatedOn = false

local function Log(msg)
    print("[ModMenuHost] " .. tostring(msg))
    pcall(function()
        ModMenu.SetLabel("Status", "last", tostring(msg))
    end)
end

print("--------------------------------")
print("|  ModMenuHost (dummy)         |")
print("|  F8 = showcase menu          |")
print("|  Console: modmenuhost        |")
print("--------------------------------")

-- ---------------------------------------------------------------------------
-- Cheats
-- ---------------------------------------------------------------------------

ModMenu.Register({
    id = "Status",
    title = "Status",
    tab = "Cheats",
    items = {
        {
            type = "label",
            id = "last",
            label = "Ready — clicks log here and in the UE4SS console.",
        },
        {
            type = "button",
            id = "gotoGive",
            label = "Go to Give tab",
            variant = "info",
            onClick = function()
                ModMenu.SetTab("Give")
                Log("SetTab(Give)")
            end,
        },
    },
})

ModMenu.Register({
    id = "Toggles",
    title = "Toggles",
    tab = "Cheats",
    items = {
        {
            type = "checkbox",
            id = "god",
            label = "God mode (mock)",
            default = false,
            onChange = function(on)
                Log("god = " .. tostring(on))
            end,
        },
        {
            type = "checkbox",
            id = "noclip",
            label = "Noclip (mock)",
            default = false,
            onChange = function(on)
                Log("noclip = " .. tostring(on))
            end,
        },
        {
            type = "dropdown",
            id = "difficulty",
            label = "Difficulty",
            options = { "Easy", "Normal", "Hard" },
            default = "Normal",
            onChange = function(value)
                Log("difficulty = " .. tostring(value))
            end,
        },
        {
            type = "row",
            items = {
                {
                    type = "number",
                    id = "healAmt",
                    label = "Heal",
                    default = 100,
                    min = 1,
                    max = 9999,
                    integer = true,
                    labelWidth = 48,
                },
                {
                    type = "button",
                    id = "heal",
                    label = "Apply",
                    variant = "success",
                    onClick = function()
                        Log("heal " .. tostring(ModMenu.Get("Toggles", "healAmt")))
                    end,
                },
            },
        },
        {
            type = "textinput",
            id = "note",
            label = "Note",
            default = "",
            placeholder = "type then press Log",
            labelWidth = 48,
        },
        {
            type = "button",
            id = "logNote",
            label = "Log note",
            onClick = function()
                Log("note = " .. tostring(ModMenu.Get("Toggles", "note")))
            end,
        },
    },
})

ModMenu.Register({
    id = "Buttons",
    title = "Button styles",
    tab = "Cheats",
    collapsible = true,
    collapsed = false,
    items = {
        { type = "label", label = "Variants (flat UMG). Watch the console." },
        {
            type = "button",
            id = "vDefault",
            label = "default",
            onClick = function()
                Log("clicked default")
            end,
        },
        {
            type = "button",
            id = "vPrimary",
            label = "primary",
            variant = "primary",
            onClick = function()
                Log("clicked primary")
            end,
        },
        {
            type = "button",
            id = "vSecondary",
            label = "secondary",
            variant = "secondary",
            onClick = function()
                Log("clicked secondary")
            end,
        },
        {
            type = "button",
            id = "vSuccess",
            label = "success",
            variant = "success",
            onClick = function()
                Log("clicked success")
            end,
        },
        {
            type = "button",
            id = "vDanger",
            label = "danger",
            variant = "danger",
            onClick = function()
                Log("clicked danger")
            end,
        },
        {
            type = "button",
            id = "vWarning",
            label = "warning",
            variant = "warning",
            onClick = function()
                Log("clicked warning")
            end,
        },
        {
            type = "button",
            id = "vInfo",
            label = "info",
            variant = "info",
            onClick = function()
                Log("clicked info")
            end,
        },
        { type = "separator" },
        { type = "label", label = "Live chrome — no rebuild (SetButton*)." },
        {
            type = "button",
            id = "modeA",
            label = "Mode A",
            active = true,
            onClick = function()
                ModMenu.SetButtonActive("Buttons", "modeA", true)
                ModMenu.SetButtonActive("Buttons", "modeB", false)
                Log("mode = A")
            end,
        },
        {
            type = "button",
            id = "modeB",
            label = "Mode B",
            onClick = function()
                ModMenu.SetButtonActive("Buttons", "modeA", false)
                ModMenu.SetButtonActive("Buttons", "modeB", true)
                Log("mode = B")
            end,
        },
        {
            type = "button",
            id = "flip",
            label = "Flip primary / danger",
            variant = "primary",
            onClick = function()
                flipDanger = not flipDanger
                local v = flipDanger and "danger" or "primary"
                ModMenu.SetButtonVariant("Buttons", "flip", v)
                Log("flip variant = " .. v)
            end,
        },
        {
            type = "button",
            id = "gateToggle",
            label = "Enable gated button",
            variant = "secondary",
            onClick = function()
                gatedOn = not gatedOn
                ModMenu.SetButtonEnabled("Buttons", "gated", gatedOn)
                ModMenu.SetButtonLabel("Buttons", "gateToggle", gatedOn and "Disable gated button" or "Enable gated button")
                Log("gated enabled = " .. tostring(gatedOn))
            end,
        },
        {
            type = "button",
            id = "gated",
            label = "Gated action",
            enabled = false,
            onClick = function()
                Log("gated action fired")
            end,
        },
    },
})

-- ---------------------------------------------------------------------------
-- Give
-- ---------------------------------------------------------------------------

ModMenu.Register({
    id = "Give",
    title = "Give item",
    tab = "Give",
    items = {
        {
            type = "label",
            label = "Searchable dropdown + amount row. Mock catalog only.",
        },
        {
            type = "dropdown",
            id = "item",
            label = "Item",
            searchable = true,
            placeholder = "Select item...",
            maxVisible = 8,
            options = {
                "Ashen Flask",
                "Gold Coin",
                "Tarstone",
                "Shell Fragment",
                "Resolve Shard",
                "Gloom Essence",
                "Laterite",
                "Mask of Harros",
                "Sidearm Kit",
                "Weapon Oil",
            },
            onChange = function(value)
                Log("picked " .. tostring(value))
            end,
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
                    id = "give",
                    label = "Give",
                    variant = "primary",
                    onClick = function()
                        local item = ModMenu.Get("Give", "item")
                        local n = ModMenu.Get("Give", "amount")
                        if item == nil or item == "" then
                            Log("pick an item first")
                            return
                        end
                        Log("give " .. tostring(n) .. " x " .. tostring(item))
                    end,
                },
            },
        },
        {
            type = "button",
            id = "swapCatalog",
            label = "Swap catalog (SetOptions)",
            variant = "secondary",
            onClick = function()
                ModMenu.SetOptions("Give", "item", {
                    "Apple",
                    "Pear",
                    "Plum",
                    "Orange",
                }, "Pear")
                Log("SetOptions -> fruit, selected Pear")
            end,
        },
        {
            type = "fold",
            id = "giveAll",
            label = "Give all (hidden)",
            collapsed = true,
            items = {
                { type = "label", label = "Destructive mock — still only logs." },
                {
                    type = "button",
                    id = "giveAllBtn",
                    label = "Give ALL items",
                    variant = "warning",
                    onClick = function()
                        Log("give ALL (mock)")
                    end,
                },
            },
        },
    },
})

ModMenu.Register({
    id = "Bags",
    title = "Currencies",
    tab = "Give",
    items = {
        {
            type = "dropdown",
            id = "currency",
            label = "Kind",
            options = { "Gold", "Gloom", "Tarcores" },
            default = "Gold",
            onChange = function(value)
                Log("currency = " .. tostring(value))
            end,
        },
        {
            type = "row",
            items = {
                {
                    type = "number",
                    id = "qty",
                    label = "Qty",
                    default = 100,
                    min = 1,
                    integer = true,
                    labelWidth = 36,
                },
                {
                    type = "button",
                    id = "add",
                    label = "Add",
                    onClick = function()
                        Log("add " .. tostring(ModMenu.Get("Bags", "qty"))
                            .. " " .. tostring(ModMenu.Get("Bags", "currency")))
                    end,
                },
            },
        },
    },
})

-- ---------------------------------------------------------------------------
-- Keybinds
-- ---------------------------------------------------------------------------

ModMenu.Register({
    id = "Keybinds",
    title = "Keybinds",
    tab = "Keybinds",
    collapsible = true,
    collapsed = false,
    items = {
        { type = "label", label = "Session-only mock. Real hosts store a key per row." },
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
                    onClick = function()
                        ModMenu.SetButtonLabel("Keybinds", "bindHeal", "Heal: F9 (mock)")
                        Log("bind Heal = F9")
                    end,
                },
                {
                    type = "button",
                    id = "bindResolve",
                    label = "Resolve: none",
                    onClick = function()
                        ModMenu.SetButtonLabel("Keybinds", "bindResolve", "Resolve: F10 (mock)")
                        Log("bind Resolve = F10")
                    end,
                },
            },
        },
        {
            type = "fold",
            id = "uiBinds",
            label = "UI",
            collapsed = true,
            items = {
                {
                    type = "button",
                    id = "clearBinds",
                    label = "Clear mock binds",
                    variant = "danger",
                    onClick = function()
                        ModMenu.SetButtonLabel("Keybinds", "bindHeal", "Heal: none")
                        ModMenu.SetButtonLabel("Keybinds", "bindResolve", "Resolve: none")
                        Log("cleared binds")
                    end,
                },
            },
        },
    },
})

ModMenu.Register({
    id = "Advanced",
    title = "Collapsed section",
    tab = "Keybinds",
    collapsible = true,
    collapsed = true,
    items = {
        { type = "label", label = "This whole section starts closed (collapsible = true)." },
        {
            type = "button",
            id = "peek",
            label = "Peek",
            onClick = function()
                Log("collapsed section still works")
            end,
        },
    },
})

ModMenu.OnOpen(function()
    Log("opened tab=" .. tostring(ModMenu.GetTab()))
end)
