--[[
  ModMenu.shell.session — mutable per-Lua-state shell fields shared by dock/build/lifecycle.
]]

local Util = require("ModMenu.core.util")

local M = {}

M.VIS_VISIBLE = 0
M.VIS_COLLAPSED = 1
M.POLL_MS = 16

---@param opts { config: table, sections: table, values: table, onOpenCallbacks: table }
function M.New(opts)
    return {
        config = opts.config,
        sections = opts.sections,
        sectionIndexById = {},
        values = opts.values,
        onOpenCallbacks = opts.onOpenCallbacks,
        menuRoot = nil,
        contentBox = nil,
        panelSlot = nil,
        panelBorder = nil, ---@type any fill Border
        panelOutline = nil, ---@type any 1px outline Border
        menuOpen = false,
        contentGen = 0,
        pollHandle = nil,
        pollFn = nil, ---@type function|nil strong ref for LoopInGameThreadWithDelay
        hooksInstalled = false,
        liveControls = {},
        contentDirty = false, --- rebuild on next Open after Register/SetOptions while closed
        collapsedById = {}, ---@type table<string, boolean>
        foldCollapsedByKey = {}, ---@type table<string, boolean> "sectionId.foldId"
        activeTab = nil, ---@type string|nil session-only; first Init tab when unset
        pendingTabId = nil, ---@type string|nil
        tabApplyQueue = {}, ---@type string[]
        tabApplyFn = nil, ---@type function|nil
        tabApplyScheduled = false,
        pendingCollapseId = nil, ---@type string|nil
        pendingCollapseSource = nil, ---@type string|nil
        collapseApplyQueue = {}, ---@type { id: string, source: string|nil }[]
        collapseApplyFn = nil, ---@type function|nil
        collapseApplyScheduled = false,
        menuCanvas = nil, ---@type any CanvasPanel (panel + confirm overlay)
        confirm = nil, ---@type table|nil active confirm spec
        confirmRoot = nil,
        confirmSlot = nil,
        confirmControls = nil,
        confirmGen = 0,
        makeWidgetCtx = nil, ---@type fun(): table
        -- Opt-in cursorMode = "modmenu" overlay (core/cursor.lua).
        cursorRoot = nil,
        cursorSlot = nil,
        cursorPollHandle = nil,
        cursorPollFn = nil, ---@type function|nil strong ref for LoopInGameThreadWithDelay
        cursorShowFn = nil, ---@type function|nil
        cursorShowHandle = nil,
        clientRestartFn = nil, ---@type function|nil
        rebuildFn = nil, ---@type function|nil
        cursorHiddenWidgets = nil, ---@type { widget: any, vis: number|nil }[]|nil
        cursorScale = nil,
        cursorHotspotX = nil,
        cursorHotspotY = nil,
        cursorConfigSig = nil, ---@type string|nil last applied cursorMode|scale|hideClasses
    }
end

function M.ClearLive(S)
    local list = S.liveControls
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

function M.EnsureVisible(S)
    if S.menuOpen and Util.IsValid(S.menuRoot) then
        pcall(function()
            S.menuRoot:SetVisibility(M.VIS_VISIBLE)
        end)
    end
end

function M.IsVisible(S)
    if not Util.IsValid(S.menuRoot) then
        return false
    end
    local ok, vis = pcall(function()
        return S.menuRoot:GetVisibility()
    end)
    return ok and vis == M.VIS_VISIBLE
end

return M
