--[[
  ModMenu — shared in-game UMG settings shell for UE4SS Lua mods.

  Usage:
    local ModMenu = require("ModMenu.ModMenu")
    ModMenu.Init({ title = "My Mod Menu", key = Key.F6 }) -- ignoreLook = true to lock camera
    -- inputBackend = "engine" when RegisterKeyBind does not fire (e.g. Code Vein 2)
    -- cursorMode = "modmenu" when the game suppresses the engine cursor
    ModMenu.Register({
      id = "MyMod",
      title = "My Mod",
      items = {
        { type = "checkbox", id = "enabled", label = "Enabled", default = false,
          onChange = function(on) end },
        { type = "button", id = "run", label = "Do thing",
          onClick = function() end },
        { type = "dropdown", id = "mode", label = "Mode",
          options = { "A", { label = "Bee", value = "b" } },
          default = "A", onChange = function(value) end },
        { type = "dropdown", id = "item", label = "Item", searchable = true,
          placeholder = "Select item...", maxVisible = 12,
          options = { ... }, onChange = function(value) end },
        { type = "row", items = {
            { type = "number", id = "count", label = "Count", default = 1, min = 1, integer = true },
            { type = "button", id = "add", label = "Add Selected",
              onClick = function()
                local n = ModMenu.Get("MyMod", "count")
              end },
          }},
        { type = "label", label = "Hint text" },
        { type = "separator" },
      },
    })
    ModMenu.SetDock("left") -- or Init({ dock = "left" })

  Per-mod shell: each Lua mod that Init()s gets its own panel + hotkey.
  UObject names / viewport Z are allocated via ModRef shared vars so two mods
  never collide on ModMenu_Root_1 under the same GameInstance.

  Dock presets: Left / Right via header button (session only; no free drag).
  Collapsible sections: Register({ collapsible = true, collapsed = true }).
  Nested fold: { type = "fold", id, label, collapsed = true, items = { ... } }.
  Theme (authors): Init({ theme = "light" | "dark" }) — light is the current look.
  Tabs: Init({ tabs = { "Cheats", "Give" } }) + Register({ tab = "Cheats", ... }).

  Internals: core/ helpers + widgets/ registry (see README.md).
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local Config = require("ModMenu.core.config")
local Instance = require("ModMenu.core.instance")
local InputMode = require("ModMenu.core.inputmode")
local Session = require("ModMenu.shell.session")
local Dock = require("ModMenu.shell.dock")
local Tabs = require("ModMenu.shell.tabs")
local Lifecycle = require("ModMenu.shell.lifecycle")
local Registry = require("ModMenu.shell.registry")

local ModMenu = {}

local Debug = Util.Debug

local config = Config.New()

--- Callbacks fired after the menu finishes opening (feature modules use for lazy init).
local onOpenCallbacks = {} ---@type function[]

local initialized = false

local S = Session.New({
    config = config,
    sections = {},
    values = {},
    onOpenCallbacks = onOpenCallbacks,
})

InputMode.Bind({
    getMenuRoot = function()
        return S.menuRoot
    end,
    getIgnoreLook = function()
        return S.config.ignoreLook == true
    end,
    isMenuOpen = function()
        return S.menuOpen == true
    end,
    getCursorMode = function()
        return S.config.cursorMode
    end,
})

S.makeWidgetCtx = function()
    return {
        values = S.values,
        liveControls = S.liveControls,
        config = S.config,
        umg = Umg,
        Input = Input,
        ValueKey = Util.ValueKey,
        SafeCall = Util.SafeCall,
        IsValid = Util.IsValid,
        ReclaimMenuInput = InputMode.Reclaim,
        EnsureMenuVisible = function()
            Session.EnsureVisible(S)
        end,
        foldCollapsedByKey = S.foldCollapsedByKey,
    }
end

local function InstallInput()
    local key = config.key or Key.F6
    config.key = key
    if config.keyHint == nil and key == Key.F6 then
        config.keyHint = "F6"
    end
    config.keyName = Config.ResolveEngineKeyName(config) or config.keyName
    if config.inputBackend == "engine" and (type(config.keyName) ~= "string" or config.keyName == "") then
        error('ModMenu.Init: keyName is required when inputBackend is "engine" (Unreal FKey name, e.g. "F7")')
    end
    if config.inputBackend ~= "engine" and (type(config.keyName) ~= "string" or config.keyName == "") then
        config.keyName = tostring(config.keyHint or "F6")
    end
    Instance.ClaimToggleKey(config, config.keyHint or tostring(key))
    Input.Install({
        backend = config.inputBackend,
        key = key,
        keyName = config.keyName,
        onToggle = function()
            Lifecycle.Toggle(S)
        end,
        onOpen = function()
            Lifecycle.Open(S)
        end,
        onClose = function()
            Lifecycle.Close(S)
        end,
        isMenuOpen = function()
            return S.menuOpen == true
        end,
        consoleCommand = config.consoleCommand,
    })
end

--- Initialize / configure this mod's shell. Safe to call multiple times.
---@param opts table|nil
function ModMenu.Init(opts)
    Config.ApplyInit(config, opts, { instanceUnlocked = Instance.GetTag() == nil })
    Util.SetDebug(config.debug == true)
    Instance.Ensure(config)
    Umg.SetDefaults({ fontItem = config.fontItem, colors = config.colors })
    Lifecycle.InstallHooks(S)
    InstallInput()
    initialized = true
    -- Re-apply dock if shell already exists (Init can be called again).
    Dock.ApplyPercentLayout(S.panelSlot, S.config)
    Dock.SyncChrome(S)
    Lifecycle.OnConfigChanged(S)
    local tabList = "off"
    if type(config.tabs) == "table" and #config.tabs > 0 then
        tabList = table.concat(config.tabs, ",")
    end
    Debug(string.format(
        "Init — title=%q key=%s backend=%s cursor=%s dock=%s theme=%s tabs=%s fontScale=%s instance=%q serial=%s z=%d",
        tostring(config.title),
        tostring(config.keyHint or config.key),
        tostring(config.inputBackend),
        tostring(config.cursorMode),
        tostring(config.dock),
        tostring(config.theme),
        tabList,
        tostring(config.fontScale),
        tostring(Instance.GetTag()),
        tostring(Instance.GetSerial()),
        Instance.GetViewportZ()
    ))
end

--- Process-wide instance tag used in UObject names (e.g. ModMenu_Root_TestMod_1).
---@return string|nil
function ModMenu.GetInstanceId()
    return Instance.GetTag()
end

---@return integer|nil
function ModMenu.GetInstanceSerial()
    return Instance.GetSerial()
end

--- Pin the panel to the left or right edge (session only; no free drag).
---@param side string "left"|"right"
function ModMenu.SetDock(side)
    Dock.Set(S, side)
end

---@return string
function ModMenu.GetDock()
    return config.dock
end

--- Switch the active tab (Init tabs). Session-only; rebuilds if the menu is open.
---@param name string
---@return boolean
function ModMenu.SetTab(name)
    return Tabs.Select(S, name)
end

--- Current tab name, or nil when Init did not set tabs.
---@return string|nil
function ModMenu.GetTab()
    if not Tabs.Enabled(S) then
        return nil
    end
    Tabs.Ensure(S)
    return S.activeTab
end

--- Register or replace a mod section.
---@param section table
function ModMenu.Register(section)
    if not initialized then
        ModMenu.Init({})
    end
    Registry.Register(S, section)
end

---@param sectionId string
---@param itemId string
---@return any
function ModMenu.Get(sectionId, itemId)
    return Registry.Get(S, sectionId, itemId)
end

--- Update a label item's text (by id) in the section + live widget if present.
---@param sectionId string
---@param itemId string
---@param text string
---@return boolean
function ModMenu.SetLabel(sectionId, itemId, text)
    return Registry.SetLabel(S, sectionId, itemId, text)
end

--- Update a button's caption (section item + live TextBlock if present).
---@param sectionId string
---@param itemId string
---@param text string
---@return boolean
function ModMenu.SetButtonLabel(sectionId, itemId, text)
    return Registry.SetButtonLabel(S, sectionId, itemId, text)
end

--- Enable/disable a button (blocks poll clicks + themed disabled chrome).
---@param sectionId string
---@param itemId string
---@param enabled boolean
---@return boolean
function ModMenu.SetButtonEnabled(sectionId, itemId, enabled)
    return Registry.SetButtonEnabled(S, sectionId, itemId, enabled)
end

--- Button semantic color (Bootstrap-like): default|primary|secondary|success|danger|warning|info.
---@param sectionId string
---@param itemId string
---@param variant string
---@return boolean
function ModMenu.SetButtonVariant(sectionId, itemId, variant)
    return Registry.SetButtonVariant(S, sectionId, itemId, variant)
end

--- Button selected/on chrome (green). Disabled still wins over active.
---@param sectionId string
---@param itemId string
---@param active boolean
---@return boolean
function ModMenu.SetButtonActive(sectionId, itemId, active)
    return Registry.SetButtonActive(S, sectionId, itemId, active)
end

--- Set a value and sync a live checkbox/dropdown/number/textinput if present.
---@param sectionId string
---@param itemId string
---@param value any
function ModMenu.Set(sectionId, itemId, value)
    Registry.Set(S, sectionId, itemId, value)
end

--- Replace dropdown options.
--- Searchable dropdowns refresh rows in place when live; others rebuild the panel.
---@param sectionId string
---@param itemId string
---@param options table
---@param selectedValue any|nil pass false to clear selection
---@return boolean
function ModMenu.SetOptions(sectionId, itemId, options, selectedValue)
    return Registry.SetOptions(S, sectionId, itemId, options, selectedValue)
end

local openOnGameThread = Util.PinFn(function()
    Lifecycle.Open(S)
end)
local closeOnGameThread = Util.PinFn(function()
    Lifecycle.Close(S)
end)
local toggleOnGameThread = Util.PinFn(function()
    Lifecycle.Toggle(S)
end)

--- Register a callback invoked each time the menu opens (after shell is visible).
---@param fn function
function ModMenu.OnOpen(fn)
    if type(fn) ~= "function" then
        error("ModMenu.OnOpen expects a function")
    end
    table.insert(onOpenCallbacks, fn)
end

function ModMenu.Open()
    if not initialized then
        ModMenu.Init({})
    end
    ExecuteInGameThread(openOnGameThread)
end

function ModMenu.Close()
    ExecuteInGameThread(closeOnGameThread)
end

function ModMenu.Toggle()
    if not initialized then
        ModMenu.Init({})
    end
    ExecuteInGameThread(toggleOnGameThread)
end

function ModMenu.IsOpen()
    return S.menuOpen == true
end

--- List registered section ids (debug / tooling).
---@return string[]
function ModMenu.ListSections()
    return Registry.ListSections(S)
end

return ModMenu
