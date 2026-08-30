--[[
  ModMenu.shell.lifecycle — open / close / toggle, poll loop, ClientRestart.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Input = require("ModMenu.core.input")
local InputMode = require("ModMenu.core.inputmode")
local Instance = require("ModMenu.core.instance")
local Cursor = require("ModMenu.core.cursor")
local Widgets = require("ModMenu.widgets.init")
local Session = require("ModMenu.shell.session")
local Close = require("ModMenu.shell.close")
local Collapse = require("ModMenu.shell.collapse")
local Tabs = require("ModMenu.shell.tabs")
local Build = require("ModMenu.shell.build")
local Confirm = require("ModMenu.shell.confirm")
local Theme = require("ModMenu.core.theme")

local Log = Util.Log
local Debug = Util.Debug
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
    -- Keep S.pollFn pinned. CancelDelayedAction can still run this tick;
    -- dropping the Lua function here is what produces "Ref was not function".
end

local function PollControls(S)
    if Confirm.Poll(S) then
        return
    end

    local ctx = S.makeWidgetCtx()

    Input.BeginPoll(S.liveControls)

    -- Continuous polls (search filter, checkbox state, UButton IsPressed).
    -- pollClick is the LMB-latch fallback. Handlers must SuppressPressEdge so
    -- a latch click is not also treated as an IsPressed rising edge next tick.
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "close" then
            Close.Poll(S, ctrl)
        elseif ctrl.kind == "collapse" then
            Collapse.Poll(S, ctrl)
        elseif ctrl.kind == "tab" then
            Tabs.Poll(S, ctrl)
        else
            local widget = Widgets.get(ctrl.kind)
            if widget and widget.poll then
                widget.poll(ctrl, ctx)
            end
        end
    end

    if Input.ConsumeMouseClick() then
        -- List order. Dropdown.pollClick does option rows then header.
        local consumed = false
        for _, ctrl in ipairs(S.liveControls) do
            if ctrl.kind == "close" then
                if Close.PollClick(S, ctrl) then
                    consumed = true
                    break
                end
            elseif ctrl.kind == "collapse" then
                if Collapse.PollClick(S, ctrl) then
                    consumed = true
                    break
                end
            elseif ctrl.kind == "tab" then
                if Tabs.PollClick(S, ctrl) then
                    consumed = true
                    break
                end
            else
                local widget = Widgets.get(ctrl.kind)
                if widget and widget.pollClick and widget.pollClick(ctrl, ctx) then
                    consumed = true
                    break
                end
            end
        end
        if not consumed then
            if not Input.RetryUnclaimedClick() then
                Input.DebugClick("latch-miss", nil, nil)
            end
        end
    end

    -- Collapse show/hide after ipairs so a press-edge + latch cannot both apply.
    Collapse.Flush(S)
    -- Tab rebuild is also deferred — never BuildContent under a still-down click.
    Tabs.Flush(S)
    if S.pendingClose then
        S.pendingClose = false
        M.Close(S)
    end
end

function M.StartPoll(S)
    M.StopPoll(S)
    if S.pollFn == nil then
        S.pollFn = Util.PinFn(function()
            if not S.menuOpen then
                return
            end
            -- Reclaim when the game steals cursor / click routing (toast, etc.).
            -- Look-ignore is opt-in (Init ignoreLook) — do not re-lock the camera by default.
            local pc = UEHelpers.GetPlayerController()
            if InputMode.CursorStolen(pc) then
                InputMode.Reclaim()
            else
                -- Overlay / Wuchang: keep look locked without resetting Slate focus.
                InputMode.RefreshLookIgnore(pc)
            end
            PollControls(S)
        end)
    end
    S.pollHandle = LoopInGameThreadWithDelay(Session.POLL_MS, S.pollFn)
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
    -- Keep the UMG tree across open/close. Create already builds content;
    -- rebuilding here respawns every searchable row (Give, keybinds, …).
    -- contentDirty: Register / SetOptions while closed after the first open.
    if S.contentDirty or S.liveControls == nil or #S.liveControls == 0 then
        Build.BuildContent(S)
    end
    S.menuRoot:SetVisibility(Session.VIS_VISIBLE)
    S.menuOpen = true
    Instance.NoteOpened()
    InputMode.SetActive(true)
    M.StartPoll(S)
    if Cursor.IsEnabled(S) then
        if S.cursorShowFn == nil then
            S.cursorShowFn = Util.PinFn(function()
                S.cursorShowHandle = nil
                if S.menuOpen then
                    Cursor.Show(S)
                    Cursor.StartPoll(S)
                end
            end)
        end
        if S.cursorShowHandle ~= nil then
            pcall(function()
                CancelDelayedAction(S.cursorShowHandle)
            end)
            S.cursorShowHandle = nil
        end
        -- Brief delay so the shell is in the viewport before the overlay attaches.
        S.cursorShowHandle = ExecuteInGameThreadWithDelay(50, S.cursorShowFn)
    end
    Debug(string.format("OPEN tag=%s", tostring(Instance.GetTag())))
    for _, fn in ipairs(S.onOpenCallbacks) do
        SafeCall(fn)
    end
end

function M.Close(S)
    Confirm.Hide(S, "close")
    M.StopPoll(S)
    if S.cursorShowHandle ~= nil then
        pcall(function()
            CancelDelayedAction(S.cursorShowHandle)
        end)
        S.cursorShowHandle = nil
    end
    Cursor.Hide(S)
    Input.ClearClickState()
    Dropdown.collapseAll(S.liveControls, nil)
    if IsValid(S.menuRoot) then
        S.menuRoot:SetVisibility(Session.VIS_COLLAPSED)
    end
    S.menuOpen = false
    local remaining = Instance.NoteClosed()
    InputMode.SetActive(false, remaining)
    Debug(string.format("CLOSED tag=%s openRemaining=%s", tostring(Instance.GetTag()), tostring(remaining)))
end

function M.Toggle(S)
    -- Close is never gated. Open (and recover-to-open) respects canOpen.
    if S.menuOpen and IsValid(S.menuRoot) and Session.IsVisible(S) then
        M.Close(S)
    else
        M.Open(S)
    end
end

--- Re-apply panel fill/outline after Init. Rebuild content if the shell exists.
function M.OnConfigChanged(S)
    Tabs.Ensure(S)
    local colors = Theme.Of(S.config)
    if IsValid(S.panelBorder) then
        pcall(function()
            S.panelBorder:SetBrushColor(colors.panelBg)
            S.panelBorder:SetPadding(Theme.PadPanel(S.config))
        end)
    end
    if IsValid(S.panelOutline) then
        pcall(function()
            S.panelOutline:SetBrushColor(colors.panelBorder)
        end)
    end
    -- Cursor overlay is independent of the shell tree (first Init has no root yet).
    Cursor.OnConfigChanged(S)
    if not IsValid(S.menuRoot) then
        return
    end
    if S.menuOpen then
        Build.BuildContent(S)
        Input.ClearClickState()
    else
        S.contentDirty = true
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

    S.clientRestartFn = Util.PinFn(function()
        local wasOpen = S.menuOpen
        Build.Destroy(S, S.stopPoll)
        Debug("ClientRestart — shell reset")
        if wasOpen then
            -- Already-open session: restore without re-checking the host gate.
            M.Open(S, { skipCanOpen = true })
        end
    end)

    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        ExecuteInGameThread(S.clientRestartFn)
    end)
end

return M
