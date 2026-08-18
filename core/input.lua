--[[
  ModMenu.core.input — toggle + LMB click latch.

  Backends (Init inputBackend; no auto-detect):
    ue4ss  — RegisterKeyBind (default; games where UE4SS keybinds fire)
    engine — poll APlayerController:IsInputKeyDown (games where they do not)

  Hosts call ModMenu.Init only. This module owns implementation.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")

local M = {}

local LMB_UE_NAME = "LeftMouseButton"
local ENGINE_POLL_MS = 50

-- IsPressed() polling misses short clicks on constructed UButtons.
local mouseClickLatch = false
local clickIgnore = 0

local installed = false
local enginePollHandle = nil
local togglePrevDown = false
local lmbPrevDown = false
local inputProbeLogged = false

local function Log(msg)
    Util.Log(msg)
end

local function IsValid(obj)
    return Util.IsValid(obj)
end

local function MakeFKey(ueName)
    local fname = UEHelpers.FindOrAddFName(ueName)
    if fname == nil or fname == NAME_None then
        return nil
    end
    return { KeyName = fname }
end

--- Rising edge of IsInputKeyDown. 50ms poll misses WasInputKeyJustPressed (1-frame).
local function IsKeyDown(pc, fkey)
    if fkey == nil or not IsValid(pc) then
        return false
    end
    local ok, result = pcall(function()
        return pc:IsInputKeyDown(fkey) == true
    end)
    if ok then
        return result == true
    end
    -- Some UE4SS builds accept the FName instead of an FKey table.
    if fkey.KeyName ~= nil then
        ok, result = pcall(function()
            return pc:IsInputKeyDown(fkey.KeyName) == true
        end)
        if ok then
            return result == true
        end
    end
    if not inputProbeLogged then
        inputProbeLogged = true
        Log("engine IsInputKeyDown failed: " .. tostring(result))
    end
    return false
end

local function KeyWentDown(pc, fkey, prevDown)
    local down = IsKeyDown(pc, fkey)
    return (down and not prevDown), down
end

local function FireOnGameThread(fn)
    if type(fn) ~= "function" then
        return
    end
    ExecuteInGameThread(function()
        fn()
    end)
end

local function InstallUe4ss(opts)
    RegisterKeyBind(opts.key, function()
        FireOnGameThread(opts.onToggle)
    end)
    RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function()
        if opts.isMenuOpen and opts.isMenuOpen() then
            mouseClickLatch = true
        end
    end)
    Log(string.format("input backend=ue4ss toggle=%s", tostring(opts.keyName or opts.key)))
end

local function InstallEngine(opts)
    local toggleKey = MakeFKey(opts.keyName)
    local lmbKey = MakeFKey(LMB_UE_NAME)
    if toggleKey == nil then
        Log(string.format("engine backend: invalid keyName %q (FName not found)", tostring(opts.keyName)))
        return
    end
    if lmbKey == nil then
        Log("engine backend: LeftMouseButton FName not found")
        return
    end

    if enginePollHandle ~= nil then
        return
    end

    enginePollHandle = LoopInGameThreadWithDelay(ENGINE_POLL_MS, function()
        local pc = UEHelpers.GetPlayerController()
        if not IsValid(pc) then
            togglePrevDown = false
            lmbPrevDown = false
            return
        end

        local toggleDown
        toggleDown, togglePrevDown = KeyWentDown(pc, toggleKey, togglePrevDown)
        if toggleDown then
            Util.SafeCall(opts.onToggle)
        end

        if opts.isMenuOpen and opts.isMenuOpen() then
            local lmbDown
            lmbDown, lmbPrevDown = KeyWentDown(pc, lmbKey, lmbPrevDown)
            if lmbDown then
                mouseClickLatch = true
            end
        else
            lmbPrevDown = false
        end
    end)

    Log(string.format("input backend=engine poll %s + LMB (%dms)", tostring(opts.keyName), ENGINE_POLL_MS))
end

local function InstallConsoleCommand(opts)
    local name = opts.consoleCommand
    if type(name) ~= "string" or name == "" then
        return
    end
    RegisterConsoleCommandHandler(name, function(FullCommand, Parameters, Ar)
        local action = string.lower(tostring(Parameters[1] or "toggle"))
        if action == "open" then
            FireOnGameThread(opts.onOpen or opts.onToggle)
            if Ar and Ar.Log then
                Ar:Log("ModMenu open")
            end
        elseif action == "close" then
            FireOnGameThread(opts.onClose or opts.onToggle)
            if Ar and Ar.Log then
                Ar:Log("ModMenu close")
            end
        elseif action == "toggle" then
            FireOnGameThread(opts.onToggle)
            if Ar and Ar.Log then
                Ar:Log("ModMenu toggle")
            end
        else
            local usage = "Usage: " .. name .. " [toggle|open|close]"
            print("[ModMenu] " .. usage)
            if Ar and Ar.Log then
                Ar:Log(usage)
            end
        end
        return true
    end)
    Log(string.format("console command %q registered", name))
end

--- Bind toggle + LMB once. Same backend for both.
---@param opts { backend: string, key: any, keyName: string, onToggle: function, onOpen?: function, onClose?: function, isMenuOpen: fun(): boolean, consoleCommand?: string }
function M.Install(opts)
    if installed then
        return
    end
    opts = opts or {}
    if type(opts.onToggle) ~= "function" then
        error("ModMenu.core.input.Install: onToggle must be a function")
    end
    if type(opts.isMenuOpen) ~= "function" then
        error("ModMenu.core.input.Install: isMenuOpen must be a function")
    end

    local backend = opts.backend or "ue4ss"
    if backend == "ue4ss" then
        if opts.key == nil then
            error("ModMenu.core.input.Install: key is required for backend ue4ss")
        end
        InstallUe4ss(opts)
    elseif backend == "engine" then
        if type(opts.keyName) ~= "string" or opts.keyName == "" then
            error("ModMenu.core.input.Install: keyName is required for backend engine (Unreal FKey, e.g. \"F7\")")
        end
        InstallEngine(opts)
    else
        error('ModMenu.core.input.Install: backend must be "ue4ss" or "engine"')
    end

    InstallConsoleCommand(opts)
    installed = true
end

function M.ConsumeMouseClick()
    if clickIgnore > 0 then
        clickIgnore = clickIgnore - 1
        mouseClickLatch = false
        return false
    end
    if not mouseClickLatch then
        return false
    end
    mouseClickLatch = false
    return true
end

function M.IgnoreClicks(n)
    clickIgnore = math.max(clickIgnore, n or 2)
    mouseClickLatch = false
end

--- After a latch click, mark the widget down so WidgetPressedEdge does not
--- fire again on the next 16ms tick (IsPressed / HasMouseCapture lag).
---@param state table|nil
---@param flagKey string|nil
function M.SuppressPressEdge(state, flagKey)
    if state ~= nil then
        state[flagKey or "wasPressed"] = true
    end
end

--- Clear latch + ignore counters (e.g. after content rebuild while open).
function M.ClearClickState()
    mouseClickLatch = false
    clickIgnore = 0
end

local function IsTruthy(value)
    return value == true or value == 1
end

function M.WidgetHovered(widget)
    if widget == nil then
        return false
    end
    local ok, hovered = pcall(function()
        return widget:IsHovered()
    end)
    return ok and IsTruthy(hovered)
end

--- IsPressed, or HasMouseCapture when constructed UButtons lag the pressed flag.
---@param widget any
---@return boolean
function M.WidgetIsDown(widget)
    if widget == nil then
        return false
    end
    local ok, pressed = pcall(function()
        return widget:IsPressed()
    end)
    if ok and IsTruthy(pressed) then
        return true
    end
    ok, pressed = pcall(function()
        return widget:HasMouseCapture()
    end)
    return ok and IsTruthy(pressed)
end

--- Rising edge of UButton press. Do not gate on type()=="function": UE4SS UFunctions
--- are userdata, so that check skipped IsPressed entirely (hover/press visuals still worked).
---@param state table
---@param widget any
---@param flagKey string|nil default "wasPressed"
---@return boolean
function M.WidgetPressedEdge(state, widget, flagKey)
    flagKey = flagKey or "wasPressed"
    if state == nil or widget == nil then
        return false
    end
    local down = M.WidgetIsDown(widget)
    local wentDown = down and not state[flagKey]
    state[flagKey] = down
    return wentDown
end

return M
