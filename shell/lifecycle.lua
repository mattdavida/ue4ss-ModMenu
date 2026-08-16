--[[
  ModMenu.shell.lifecycle — open / close / toggle, poll loop, ClientRestart.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Input = require("ModMenu.core.input")
local InputMode = require("ModMenu.core.inputmode")
local Instance = require("ModMenu.core.instance")
local Widgets = require("ModMenu.widgets.init")
local Session = require("ModMenu.shell.session")
local Dock = require("ModMenu.shell.dock")
local Build = require("ModMenu.shell.build")

local Log = Util.Log
local IsValid = Util.IsValid
local SafeCall = Util.SafeCall
local Dropdown = Widgets.get("dropdown")

local M = {}

function M.StopPoll(S)
    if S.pollHandle then
        pcall(function()
            CancelDelayedAction(S.pollHandle)
        end)
        S.pollHandle = nil
    end
end

local function PollControls(S)
    local ctx = S.makeWidgetCtx()

    -- Continuous polls (search filter, checkbox state, UButton IsPressed).
    -- pollClick is the LMB-latch fallback. Handlers must SuppressPressEdge so
    -- a latch click is not also treated as an IsPressed rising edge next tick.
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "dock" then
            Dock.Poll(S, ctrl)
        else
            local widget = Widgets.get(ctrl.kind)
            if widget and widget.poll then
                widget.poll(ctrl, ctx)
            end
        end
    end

    if not Input.ConsumeMouseClick() then
        return
    end

    -- List order. Dropdown.pollClick does option rows then header.
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "dock" then
            if Dock.PollClick(S, ctrl) then
                return
            end
        else
            local widget = Widgets.get(ctrl.kind)
            if widget and widget.pollClick and widget.pollClick(ctrl, ctx) then
                return
            end
        end
    end
end

function M.StartPoll(S)
    M.StopPoll(S)
    S.pollHandle = LoopInGameThreadWithDelay(Session.POLL_MS, function()
        if not S.menuOpen then
            return
        end
        -- Reclaim when the game steals cursor / click routing (toast, etc.).
        -- Look-ignore is opt-in (Init ignoreLook) — do not re-lock the camera by default.
        local pc = UEHelpers.GetPlayerController()
        if InputMode.CursorStolen(pc) then
            InputMode.Reclaim()
        end
        PollControls(S)
    end)
end

--- Host gate for opening (key toggle + ModMenu.Open). Close is never gated.
---@return boolean allowed
---@return string|nil reason
function M.EvaluateCanOpen(S)
    local fn = S.config.canOpen
    if type(fn) ~= "function" then
        return true
    end
    local ok, a, b = pcall(fn)
    if not ok then
        return false, tostring(a)
    end
    if a == false then
        return false, (type(b) == "string" and b ~= "") and b or "canOpen returned false"
    end
    return true
end

---@param opts { skipCanOpen?: boolean }|nil
function M.Open(S, opts)
    opts = opts or {}
    if not opts.skipCanOpen then
        local allowed, reason = M.EvaluateCanOpen(S)
        if not allowed then
            Log("OPEN blocked: " .. tostring(reason))
            return
        end
    end
    if not Build.Ensure(S) then
        return
    end
    Build.BuildContent(S)
    S.menuRoot:SetVisibility(Session.VIS_VISIBLE)
    S.menuOpen = true
    Instance.NoteOpened()
    InputMode.SetActive(true)
    M.StartPoll(S)
    Log(string.format("OPEN tag=%s", tostring(Instance.GetTag())))
    for _, fn in ipairs(S.onOpenCallbacks) do
        SafeCall(fn)
    end
end

function M.Close(S)
    M.StopPoll(S)
    Input.ClearClickState()
    Dropdown.collapseAll(S.liveControls, nil)
    if IsValid(S.menuRoot) then
        S.menuRoot:SetVisibility(Session.VIS_COLLAPSED)
    end
    S.menuOpen = false
    local remaining = Instance.NoteClosed()
    InputMode.SetActive(false, remaining)
    Log(string.format("CLOSED tag=%s openRemaining=%s", tostring(Instance.GetTag()), tostring(remaining)))
end

function M.Toggle(S)
    -- Close is never gated. Open (and recover-to-open) respects canOpen.
    if S.menuOpen and IsValid(S.menuRoot) and Session.IsVisible(S) then
        M.Close(S)
    else
        M.Open(S)
    end
end

function M.InstallHooks(S)
    if S.hooksInstalled then
        return
    end
    S.hooksInstalled = true
    S.stopPoll = function()
        M.StopPoll(S)
    end

    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        ExecuteInGameThread(function()
            local wasOpen = S.menuOpen
            Build.Destroy(S, S.stopPoll)
            Log("ClientRestart — shell reset")
            if wasOpen then
                -- Already-open session: restore without re-checking the host gate.
                M.Open(S, { skipCanOpen = true })
            end
        end)
    end)
end

return M
