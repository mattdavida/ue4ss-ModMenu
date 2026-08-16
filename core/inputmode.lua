--[[
  ModMenu.core.inputmode — PlayerController + Slate while a shell is open.

  Keys stay in core/input.lua. This module owns GameAndUI / GameOnly,
  software cursor flags, opt-in look-ignore, and reclaim after game UI steals focus.
]]

local UEHelpers = require("UEHelpers.UEHelpers")
local Util = require("ModMenu.core.util")
local Shared = require("ModMenu.core.shared")

local M = {}

local IsValid = Util.IsValid

-- UE5 added trailing bFlushInput to SetInputMode_*; UE4.27 rejects the extra arg.
-- Cache after first successful call so we don't pcall-probe every open/close.
local inputModeFlushArity = nil ---@type "withFlush"|"noFlush"|nil

local getMenuRoot = function()
    return nil
end
local getIgnoreLook = function()
    return false
end
local isMenuOpen = function()
    return false
end

---@param hooks { getMenuRoot: fun(): any, getIgnoreLook: fun(): boolean, isMenuOpen: fun(): boolean }
function M.Bind(hooks)
    getMenuRoot = hooks.getMenuRoot
    getIgnoreLook = hooks.getIgnoreLook
    isMenuOpen = hooks.isMenuOpen
end

--- GameAndUI with DoNotLock; try UE5 (5 args) then UE4 (4 args).
local function ApplyGameAndUI(lib, pc)
    local menuRoot = getMenuRoot()
    -- EMouseLockMode::DoNotLock = 0
    if inputModeFlushArity == "withFlush" then
        lib:SetInputMode_GameAndUIEx(pc, menuRoot, 0, false, false)
        return
    end
    if inputModeFlushArity == "noFlush" then
        lib:SetInputMode_GameAndUIEx(pc, menuRoot, 0, false)
        return
    end
    local ok = pcall(function()
        lib:SetInputMode_GameAndUIEx(pc, menuRoot, 0, false, false)
    end)
    if ok then
        inputModeFlushArity = "withFlush"
        return
    end
    lib:SetInputMode_GameAndUIEx(pc, menuRoot, 0, false)
    inputModeFlushArity = "noFlush"
end

--- GameOnly; try UE5 (pc + flush) then UE4 (pc only).
local function ApplyGameOnly(lib, pc)
    if inputModeFlushArity == "withFlush" then
        lib:SetInputMode_GameOnly(pc, false)
        return
    end
    if inputModeFlushArity == "noFlush" then
        lib:SetInputMode_GameOnly(pc)
        return
    end
    local ok = pcall(function()
        lib:SetInputMode_GameOnly(pc, false)
    end)
    if ok then
        inputModeFlushArity = "withFlush"
        return
    end
    lib:SetInputMode_GameOnly(pc)
    inputModeFlushArity = "noFlush"
end

--- Force a usable cursor for mouse-look games (no default UI cursor).
--- SetIgnoreLookInput is refcounted in UE. Re-bump if the game clears ignore while open;
--- if IsLookInputIgnored can't be probed, bump at most once (LOOK_BUMP).
local function EnsureLookIgnored(pc)
    local ignored = false
    local probeOk = pcall(function()
        ignored = pc:IsLookInputIgnored() == true
    end)
    if probeOk then
        if ignored then
            return
        end
        -- Look not ignored (first open, or game cleared it) — bump and remember for restore.
    elseif Shared.Get(Shared.SAVED_LOOK_BUMP) == true then
        return
    end
    local ok = pcall(function()
        pc:SetIgnoreLookInput(true)
    end)
    if ok then
        Shared.Set(Shared.SAVED_LOOK_BUMP, true)
    end
end

local function ForceMenuCursor(pc)
    if Shared.Get(Shared.INPUT_SAVED) ~= true then
        Shared.Set(Shared.SAVED_SHOW_CURSOR, pc.bShowMouseCursor == true)
        Shared.Set(Shared.SAVED_CLICK, pc.bEnableClickEvents == true)
        Shared.Set(Shared.SAVED_HOVER, pc.bEnableMouseOverEvents == true)
        Shared.Set(Shared.INPUT_SAVED, true)
    end
    pc.bShowMouseCursor = true
    pc.bEnableClickEvents = true
    pc.bEnableMouseOverEvents = true
    if getIgnoreLook() then
        EnsureLookIgnored(pc)
    end
end

--- Restore PlayerController cursor/look flags when the last ModMenu closes.
--- If we never took over input, leave the game's cursor/mode alone
--- (ClientRestart / DestroyShell used to force cursor off and GameOnly,
--- which hides hub/inventory cursors on games like Witchfire).
local function RestoreMenuCursor(pc)
    if Shared.Get(Shared.INPUT_SAVED) ~= true then
        return false
    end
    local wasShowingCursor = Shared.Get(Shared.SAVED_SHOW_CURSOR) == true
    pc.bShowMouseCursor = wasShowingCursor
    pc.bEnableClickEvents = Shared.Get(Shared.SAVED_CLICK) == true
    pc.bEnableMouseOverEvents = Shared.Get(Shared.SAVED_HOVER) == true
    if Shared.Get(Shared.SAVED_LOOK_BUMP) == true then
        pcall(function()
            pc:SetIgnoreLookInput(false)
        end)
    end
    Shared.Set(Shared.INPUT_SAVED, false)
    Shared.Set(Shared.SAVED_LOOK_BUMP, false)
    return wasShowingCursor
end

--- Show software cursor + GameAndUI (the mode that worked — white cursor).
--- On deactivate: only return to GameOnly when no other ModMenu instance is open.
---@param active boolean
---@param remainingOpenCount integer|nil when deactivating, open count after this instance released
function M.SetActive(active, remainingOpenCount)
    local pc = UEHelpers.GetPlayerController()
    if not IsValid(pc) then
        return
    end

    local ok, err = pcall(function()
        local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        if not IsValid(lib) then
            return
        end
        if active then
            ForceMenuCursor(pc)
            ApplyGameAndUI(lib, pc)
        else
            local others = remainingOpenCount
            if type(others) ~= "number" then
                others = Shared.Get(Shared.OPEN_COUNT)
                if type(others) ~= "number" then
                    others = 0
                end
            end
            if others > 0 then
                -- Another mod's shell still open — do not yank GameAndUI / cursor.
                ForceMenuCursor(pc)
                return
            end
            -- Only GameOnly if we actually took over from mouse-look (saved cursor false).
            -- If the game already had a cursor (hub / inventory), leave its input mode.
            local hadSaved = Shared.Get(Shared.INPUT_SAVED) == true
            local wasShowingCursor = RestoreMenuCursor(pc)
            if hadSaved and wasShowingCursor ~= true then
                ApplyGameOnly(lib, pc)
            end
        end
    end)
    if not ok then
        Util.Log("SetInputMode skipped: " .. tostring(err))
    end
end

--- Re-apply GameAndUI after game UI interrupts (amber toast, etc.).
--- Only call on open, after clicks, or when we detect the cursor was stolen — not every tick.
function M.Reclaim()
    if not isMenuOpen() then
        return
    end
    M.SetActive(true)
end

--- True when the game cleared cursor / click / hover / (opt-in) look-ignore.
---@param pc any
---@return boolean
function M.CursorStolen(pc)
    if not IsValid(pc) then
        return false
    end
    local lookOk = true
    if getIgnoreLook() then
        pcall(function()
            lookOk = pc:IsLookInputIgnored() == true
        end)
    end
    return not pc.bShowMouseCursor
        or not pc.bEnableClickEvents
        or not pc.bEnableMouseOverEvents
        or not lookOk
end

return M
