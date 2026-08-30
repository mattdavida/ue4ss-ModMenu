--[[
  ModMenu.core.config — default Init table, option merge, small normalizers.
]]

local Theme = require("ModMenu.core.theme")

local M = {}

function M.New()
    return {
        title = "Mod Menu",
        key = nil, -- set in Init; default Key.F6
        dock = "right", -- "left" | "right" | "top" | "bottom" (author default; user can change)
        widthFrac = 0.32,
        topFrac = 0.05,
        bottomFrac = 0.05,
        rightFrac = 0.01, -- thickness-edge gap (all four docks)
        theme = "light", -- "light" (current look) | "dark" (charcoal panel)
        colors = Theme.Preset("light"),
        fontScale = 1, -- multiplies the default font sizes (per-game; 1 = stock)
        fontTitle = 22,
        fontHint = 14,
        fontItem = 16,
        fontSection = 18,
        fontDropdown = 15,
        instanceId = nil, -- optional human tag for FNames / Live View (e.g. "TestMod")
        canOpen = nil, -- optional fun(): boolean|boolean,string — gate Open / key toggle open
        ignoreLook = false, -- opt-in: SetIgnoreLookInput while open (mouse-look games)
        inputBackend = "ue4ss", -- "ue4ss" | "engine" (opt-in; no auto-detect)
        keyName = nil, -- Unreal FKey name for engine backend (e.g. "F7"); defaults from keyHint
        consoleCommand = nil, -- optional console command (toggle|open|close)
        cursorMode = "engine", -- "engine" | "modmenu" (opt-in overlay pointer)
        pointerMode = "mouse", -- "mouse" | "touch" (longer latch ignore + checkbox buttons)
        showClose = true, -- title-row Close (same path as the toggle key); pass false to hide
        touchFontScale = 1.75, -- extra multiply on resolved fonts + widthFrac when pointerMode is touch
        cursorScale = 1, -- overlay pointer multiplier (1 = native ~28x46; 2 = larger)
        cursorHideClasses = nil, -- optional string[] of UUserWidget class names to collapse while open
        tabs = nil, -- optional string[] top-level tabs; omit = single scroll
        debug = false, -- verbose [ModMenu] traces (collapse, open/close, register, click path)
    }
end

function M.NormalizeDock(side)
    local d = string.lower(tostring(side or "right"))
    if d == "left" or d == "right" or d == "top" or d == "bottom" then
        return d
    end
    return "right"
end

function M.NormalizeInputBackend(value)
    if value == nil then
        return "ue4ss"
    end
    if value == "ue4ss" or value == "engine" then
        return value
    end
    error('ModMenu.Init: inputBackend must be "ue4ss" or "engine"')
end

function M.NormalizeCursorMode(value)
    if value == nil then
        return "engine"
    end
    if value == "engine" or value == "modmenu" then
        return value
    end
    error('ModMenu.Init: cursorMode must be "engine" or "modmenu"')
end

--- "handheld" is an alias for touch (same Init line as debug).
function M.NormalizePointerMode(value)
    if value == nil then
        return "mouse"
    end
    if value == "mouse" then
        return "mouse"
    end
    if value == "touch" or value == "handheld" then
        return "touch"
    end
    error('ModMenu.Init: pointerMode must be "mouse", "touch", or "handheld"')
end

function M.NormalizeCursorScale(value)
    if value == nil then
        return 1
    end
    if type(value) ~= "number" or value ~= value or value < 1 then
        error("ModMenu.Init: cursorScale must be a number >= 1")
    end
    local n = math.floor(value + 0.5)
    if n < 1 then
        n = 1
    end
    if n > 8 then
        n = 8
    end
    return n
end

--- Host-supplied class short names to collapse while the ModMenu cursor is shown.
---@param value any
---@return string[]|nil
function M.NormalizeCursorHideClasses(value)
    if value == nil or value == false then
        return nil
    end
    if type(value) ~= "table" then
        error("ModMenu.Init: cursorHideClasses must be a string array or nil")
    end
    local out = {}
    for i = 1, #value do
        local name = value[i]
        if type(name) ~= "string" or name == "" then
            error("ModMenu.Init: cursorHideClasses entries must be non-empty strings")
        end
        out[#out + 1] = name
    end
    if #out == 0 then
        return nil
    end
    return out
end

--- Unique non-empty names. false / {} / omit → nil (single-scroll menu).
function M.NormalizeTabs(value)
    if value == nil or value == false then
        return nil
    end
    if type(value) ~= "table" then
        error('ModMenu.Init: tabs must be an array of strings')
    end
    local out = {}
    local seen = {}
    for i, name in ipairs(value) do
        if type(name) ~= "string" or name == "" then
            error("ModMenu.Init: tabs[" .. tostring(i) .. "] must be a non-empty string")
        end
        if seen[name] then
            error("ModMenu.Init: duplicate tab " .. name)
        end
        seen[name] = true
        table.insert(out, name)
    end
    if #out == 0 then
        return nil
    end
    return out
end

local FONT_DEFAULTS = {
    fontTitle = 22,
    fontHint = 14,
    fontItem = 16,
    fontSection = 18,
    fontDropdown = 15,
}

function M.NormalizeFontScale(value)
    if value == nil then
        return 1
    end
    if type(value) ~= "number" or value ~= value or value <= 0 then
        error("ModMenu.Init: fontScale must be a positive number")
    end
    return value
end

--- Extra size on handheld (fonts + panel width).
function M.NormalizeTouchFontScale(value)
    if value == nil then
        return 1.75
    end
    if type(value) ~= "number" or value ~= value or value <= 0 then
        error("ModMenu.Init: touchFontScale must be a positive number")
    end
    local n = value
    if n < 1 then
        n = 1
    end
    if n > 4 then
        n = 4
    end
    return n
end

local function ScaleFont(base, scale)
    local n = math.floor((base * scale) + 0.5)
    if n < 1 then
        n = 1
    end
    return n
end

--- Scale stock sizes, then apply any explicit font* from this Init (absolute).
--- Overrides persist across later Init calls that omit that key.
--- Writes desktop sizes to config._fontDesktop; ApplyTouchFonts copies them to config.font*.
local function ApplyFonts(config, opts)
    if opts.fontScale ~= nil then
        config.fontScale = M.NormalizeFontScale(opts.fontScale)
    end
    local scale = config.fontScale or 1
    local overrides = config._fontOverride
    if type(overrides) ~= "table" then
        overrides = {}
        config._fontOverride = overrides
    end
    local desktop = config._fontDesktop
    if type(desktop) ~= "table" then
        desktop = {}
        config._fontDesktop = desktop
    end
    for key, base in pairs(FONT_DEFAULTS) do
        if opts[key] ~= nil then
            if type(opts[key]) ~= "number" or opts[key] < 1 then
                error("ModMenu.Init: " .. key .. " must be a number >= 1")
            end
            desktop[key] = opts[key]
            overrides[key] = true
        elseif not overrides[key] then
            desktop[key] = ScaleFont(base, scale)
        end
    end
end

--- pointerMode touch: multiply desktop-resolved sizes (defaults × fontScale and
--- explicit fontTitle / …). Always copy from _fontDesktop so later Init does not stack.
local function ApplyTouchFonts(config)
    local desktop = config._fontDesktop
    if type(desktop) ~= "table" then
        return
    end
    local m = 1
    if config.pointerMode == "touch" then
        m = config.touchFontScale or 1.75
    end
    for key, _ in pairs(FONT_DEFAULTS) do
        local n = desktop[key]
        if type(n) == "number" then
            config[key] = ScaleFont(n, m)
        end
    end
end

local TOUCH_WIDTH_CAP = 0.85

--- Same multiplier as fonts. Snapshot desktop width so later Init does not stack.
local function ApplyTouchWidth(config)
    if config._desktopWidthFrac == nil then
        config._desktopWidthFrac = 0.32
    end
    local w = config._desktopWidthFrac
    if config.pointerMode == "touch" then
        local m = config.touchFontScale or 1.75
        w = w * m
        if w > TOUCH_WIDTH_CAP then
            w = TOUCH_WIDTH_CAP
        end
    end
    config.widthFrac = w
end

function M.ResolveEngineKeyName(config)
    if type(config.keyName) == "string" and config.keyName ~= "" then
        return config.keyName
    end
    local hint = tostring(config.keyHint or "")
    if hint:match("^[%w]+$") then
        return hint
    end
    return nil
end

--- Merge Init(opts) into config. ctx.instanceUnlocked: instanceId may still be set.
---@param config table
---@param opts table|nil
---@param ctx { instanceUnlocked?: boolean }|nil
function M.ApplyInit(config, opts, ctx)
    opts = opts or {}
    ctx = ctx or {}

    if opts.title ~= nil then config.title = opts.title end
    if opts.key ~= nil then config.key = opts.key end
    if opts.keyHint ~= nil then config.keyHint = opts.keyHint end
    if opts.widthFrac ~= nil then
        config._desktopWidthFrac = opts.widthFrac
    end
    if opts.topFrac ~= nil then config.topFrac = opts.topFrac end
    if opts.bottomFrac ~= nil then config.bottomFrac = opts.bottomFrac end
    if opts.rightFrac ~= nil then config.rightFrac = opts.rightFrac end
    if opts.dock ~= nil then config.dock = M.NormalizeDock(opts.dock) end
    if opts.theme ~= nil then
        config.theme = Theme.Normalize(opts.theme)
        config.colors = Theme.Resolve(config.theme, opts.colors)
    elseif opts.colors ~= nil then
        if type(opts.colors) ~= "table" then
            error("ModMenu.Init: colors must be a table of { R, G, B, A } tokens")
        end
        config.colors = Theme.Merge(config.colors, opts.colors)
    end
    ApplyFonts(config, opts)
    if opts.canOpen ~= nil then
        if opts.canOpen ~= false and type(opts.canOpen) ~= "function" then
            error("ModMenu.Init: canOpen must be a function or false/nil")
        end
        config.canOpen = (type(opts.canOpen) == "function") and opts.canOpen or nil
    end
    if opts.ignoreLook ~= nil then
        config.ignoreLook = opts.ignoreLook == true
    end
    if opts.inputBackend ~= nil then
        config.inputBackend = M.NormalizeInputBackend(opts.inputBackend)
    end
    if opts.keyName ~= nil then
        if type(opts.keyName) ~= "string" or opts.keyName == "" then
            error("ModMenu.Init: keyName must be a non-empty string")
        end
        config.keyName = opts.keyName
    end
    if opts.tabs ~= nil then
        config.tabs = M.NormalizeTabs(opts.tabs)
    end
    if opts.consoleCommand ~= nil then
        if opts.consoleCommand == false or opts.consoleCommand == "" then
            config.consoleCommand = nil
        elseif type(opts.consoleCommand) ~= "string" then
            error("ModMenu.Init: consoleCommand must be a string or false")
        else
            config.consoleCommand = opts.consoleCommand
        end
    end
    if opts.cursorMode ~= nil then
        config.cursorMode = M.NormalizeCursorMode(opts.cursorMode)
    end
    if opts.pointerMode ~= nil then
        config.pointerMode = M.NormalizePointerMode(opts.pointerMode)
    end
    if opts.showClose ~= nil then
        config.showClose = opts.showClose == true
    end
    if opts.touchFontScale ~= nil then
        config.touchFontScale = M.NormalizeTouchFontScale(opts.touchFontScale)
    end
    if opts.cursorScale ~= nil then
        config.cursorScale = M.NormalizeCursorScale(opts.cursorScale)
    end
    if opts.cursorHideClasses ~= nil then
        config.cursorHideClasses = M.NormalizeCursorHideClasses(opts.cursorHideClasses)
    end
    -- Human-readable FName tag (Live View). Locked after first EnsureInstanceIdentity.
    if opts.instanceId ~= nil and ctx.instanceUnlocked then
        config.instanceId = opts.instanceId
    end
    if opts.debug ~= nil then
        config.debug = opts.debug == true
    end

    if config.key == nil then
        config.key = Key.F6
        config.keyHint = config.keyHint or "F6"
    end
    config.inputBackend = M.NormalizeInputBackend(config.inputBackend)
    config.cursorMode = M.NormalizeCursorMode(config.cursorMode)
    config.pointerMode = M.NormalizePointerMode(config.pointerMode)
    config.touchFontScale = M.NormalizeTouchFontScale(config.touchFontScale)
    config.cursorScale = M.NormalizeCursorScale(config.cursorScale)
    ApplyTouchFonts(config)
    ApplyTouchWidth(config)
end

return M
