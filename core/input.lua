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
local pointerTouch = false

-- Touch: ignore delayed LMB latch after press-edge (~320ms at 16ms poll).
local TOUCH_IGNORE_TICKS = 20
-- Touch only: mouse-down often drops IsHovered before pollClick.
local HOVER_STICKY_TOUCH = 8
local LATCH_RETRY_TOUCH = 10

local lastHoverWidget = nil
local lastHoverAge = 999
local latchRetryLeft = 0

local installed = false
local enginePollHandle = nil
local togglePrevDown = false
local lmbPrevDown = false
local inputProbeLogged = false

local function Log(msg)
    Util.Log(msg)
end

local function Debug(msg)
    Util.Debug(msg)
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

--- fn must already be pinned. A fresh wrapper here is what GC's into
--- "Ref was not function" and UE4SS then removes the whole EngineTick hook.
local function FireOnGameThread(fn)
    if type(fn) ~= "function" then
        return
    end
    ExecuteInGameThread(fn)
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
    Debug(string.format("input backend=ue4ss toggle=%s", tostring(opts.keyName or opts.key)))
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

    enginePollHandle = LoopInGameThreadWithDelay(ENGINE_POLL_MS, Util.PinFn(function()
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
    end))

    Debug(string.format("input backend=engine poll %s + LMB (%dms)", tostring(opts.keyName), ENGINE_POLL_MS))
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
    Debug(string.format("console command %q registered", name))
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
    opts.onToggle = Util.PinFn(opts.onToggle)
    if type(opts.onOpen) == "function" then
        opts.onOpen = Util.PinFn(opts.onOpen)
    end
    if type(opts.onClose) == "function" then
        opts.onClose = Util.PinFn(opts.onClose)
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
        latchRetryLeft = 0
        return false
    end
    if not mouseClickLatch then
        return false
    end
    mouseClickLatch = false
    return true
end

--- Unclaimed latch: try again next poll so a late IsHovered / IsPressed can still fire.
--- Touch only — on mouse this retry lets an earlier widget steal the real click.
---@return boolean true if another attempt is scheduled
function M.RetryUnclaimedClick()
    if not pointerTouch then
        return false
    end
    if latchRetryLeft == 0 then
        latchRetryLeft = LATCH_RETRY_TOUCH
    end
    latchRetryLeft = latchRetryLeft - 1
    if latchRetryLeft <= 0 then
        latchRetryLeft = 0
        return false
    end
    mouseClickLatch = true
    return true
end

local function NoteHover(widget)
    if widget == nil then
        return
    end
    local ok, hovered = pcall(function()
        return widget:IsHovered()
    end)
    if ok and (hovered == true or hovered == 1) then
        lastHoverWidget = widget
        lastHoverAge = 0
    end
end

--- Once per poll: age the last hover, then record who is hovered this tick.
--- Touch only — desktop IsHovered is enough and sticky would steal later buttons.
---@param controls table|nil
function M.BeginPoll(controls)
    if not pointerTouch then
        return
    end
    lastHoverAge = lastHoverAge + 1
    if controls == nil then
        return
    end
    for _, ctrl in ipairs(controls) do
        NoteHover(ctrl.widget)
        NoteHover(ctrl.headerBtn)
        NoteHover(ctrl.headerLabel)
        if ctrl.optionRows then
            for _, row in ipairs(ctrl.optionRows) do
                NoteHover(row.button)
            end
        end
    end
end

function M.SetPointerMode(mode)
    pointerTouch = mode == "touch"
end

function M.IsTouch()
    return pointerTouch == true
end

function M.IgnoreClicks(n)
    local ticks = n or 2
    if pointerTouch then
        ticks = math.max(ticks, TOUCH_IGNORE_TICKS)
    end
    clickIgnore = math.max(clickIgnore, ticks)
    mouseClickLatch = false
    latchRetryLeft = 0
    lastHoverWidget = nil
    lastHoverAge = 999
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
    latchRetryLeft = 0
    lastHoverWidget = nil
    lastHoverAge = 999
end

local function IsTruthy(value)
    return value == true or value == 1
end

-- UE4SS FVector2D fields are often userdata, not Lua numbers.
local function AsNumber(v)
    if v == nil then
        return nil
    end
    if type(v) == "number" then
        return v
    end
    local ok, n = pcall(tonumber, v)
    if ok and type(n) == "number" then
        return n
    end
    ok, n = pcall(function()
        return v + 0
    end)
    if ok and type(n) == "number" then
        return n
    end
    return nil
end

local function ReadVec2(v)
    if v == nil then
        return nil, nil
    end
    if type(v) == "table" then
        return AsNumber(v.X or v.x), AsNumber(v.Y or v.y)
    end
    local okX, x = pcall(function()
        return v.X
    end)
    local okY, y = pcall(function()
        return v.Y
    end)
    if not okX or not okY then
        return nil, nil
    end
    return AsNumber(x), AsNumber(y)
end

--- Viewport-space pointer (Windows touch is a fake mouse). Debug traces only.
---@return number|nil, number|nil
local function GetPointerXY()
    local world = UEHelpers.GetGameInstance()
    if IsValid(world) then
        local ok, lib = pcall(function()
            return StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        end)
        if ok and IsValid(lib) and lib.GetMousePositionOnViewport then
            local okPos, pos = pcall(function()
                return lib:GetMousePositionOnViewport(world)
            end)
            if okPos then
                local x, y = ReadVec2(pos)
                if x and y then
                    return x, y
                end
            end
        end
    end
    local pc = UEHelpers.GetPlayerController()
    if IsValid(pc) and pc.GetMousePosition then
        local ok, a, b = pcall(function()
            return pc:GetMousePosition()
        end)
        if ok then
            a, b = AsNumber(a), AsNumber(b)
            if a and b then
                return a, b
            end
        end
    end
    return nil, nil
end

---@param widget any
---@return boolean pressed
---@return boolean capture
local function ReadPressedCapture(widget)
    local pressed = false
    local capture = false
    if widget == nil then
        return false, false
    end
    pcall(function()
        pressed = IsTruthy(widget:IsPressed())
    end)
    pcall(function()
        capture = IsTruthy(widget:HasMouseCapture())
    end)
    return pressed, capture
end

local function CtrlTag(ctrl)
    if ctrl == nil then
        return "kind=? id=?"
    end
    local id = nil
    if ctrl.item ~= nil and ctrl.item.id ~= nil then
        id = ctrl.item.id
    elseif ctrl.tabId ~= nil then
        id = ctrl.tabId
    elseif ctrl.sectionId ~= nil then
        id = ctrl.sectionId
    elseif ctrl.role ~= nil then
        id = ctrl.role
    end
    return string.format("kind=%s id=%s", tostring(ctrl.kind or "?"), tostring(id or "?"))
end

--- Click-path trace. No-op unless Init({ debug = true }).
--- path=press-edge | latch-hover | latch-miss.
---@param path string
---@param ctrl table|nil
---@param widget any|nil
function M.DebugClick(path, ctrl, widget)
    if not Util.IsDebug() then
        return
    end
    widget = widget or (ctrl and (ctrl.widget or ctrl.headerBtn))
    local px, py = GetPointerXY()
    local hovered = M.WidgetHovered(widget)
    local pressed, capture = ReadPressedCapture(widget)
    local downVia = "none"
    if pressed then
        downVia = "pressed"
    elseif capture then
        downVia = "capture"
    end
    local ptr = "ptr=?"
    if px ~= nil and py ~= nil then
        ptr = string.format("ptr=%.0f,%.0f", px, py)
    end
    Debug(string.format(
        "click path=%s %s hover=%s pressed=%s capture=%s downVia=%s %s",
        tostring(path),
        CtrlTag(ctrl),
        hovered and "1" or "0",
        pressed and "1" or "0",
        capture and "1" or "0",
        downVia,
        ptr
    ))
end

function M.WidgetHovered(widget)
    if widget == nil then
        return false
    end
    local ok, hovered = pcall(function()
        return widget:IsHovered()
    end)
    if ok and IsTruthy(hovered) then
        return true
    end
    if not pointerTouch then
        return false
    end
    -- Finger-down often clears IsHovered before pollClick; keep the last widget briefly.
    return widget == lastHoverWidget and lastHoverAge <= HOVER_STICKY_TOUCH
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
