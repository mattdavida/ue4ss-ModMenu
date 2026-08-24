--[[
  ModMenu.shell.tabs — optional top-level tab strip.

  Init({ tabs = { "Cheats", "Give" } }) + Register({ tab = "Cheats", ... }).
  Omit tabs = current single-scroll menu.

  Only the active tab's sections are built. Switching queues a rebuild off
  the poll tick (same hitch rule as collapse: never rebuild under a still-down click).
  Last tab is session-only (survives close/open; not written to disk).
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local InputMode = require("ModMenu.core.inputmode")
local Theme = require("ModMenu.core.theme")

local Debug = Util.Debug
local Construct = Umg.Construct
local CreateTextButton = Umg.CreateTextButton
local AddSpacer = Umg.AddSpacer

local M = {}

---@return boolean
function M.Enabled(S)
    return type(S.config.tabs) == "table" and #S.config.tabs > 0
end

---@return boolean
function M.Has(S, name)
    if not M.Enabled(S) or type(name) ~= "string" then
        return false
    end
    for _, tab in ipairs(S.config.tabs) do
        if tab == name then
            return true
        end
    end
    return false
end

--- Seed / repair S.activeTab against the current Init list.
function M.Ensure(S)
    if not M.Enabled(S) then
        S.activeTab = nil
        return
    end
    if M.Has(S, S.activeTab) then
        return
    end
    S.activeTab = S.config.tabs[1]
end

--- Map Register({ tab }) onto an Init tab. Omit tab = first tab.
---@return string|nil
function M.ResolveSectionTab(S, section)
    if not M.Enabled(S) then
        return nil
    end
    local tab = section.tab
    if tab == nil or tab == "" then
        return S.config.tabs[1]
    end
    if type(tab) ~= "string" then
        error("Register(" .. tostring(section.id) .. ") tab must be a string")
    end
    if not M.Has(S, tab) then
        error("Register(" .. tostring(section.id) .. ") tab " .. tab
            .. " is not in Init({ tabs = ... })")
    end
    return tab
end

---@return boolean
function M.SectionVisible(S, section)
    if not M.Enabled(S) then
        return true
    end
    M.Ensure(S)
    return section ~= nil and section.tab == S.activeTab
end

-- Finger-sized tab targets (desktop stays compact, text-height buttons).
local TOUCH_TAB_MIN_H = 56
local TOUCH_TAB_GAP = 8
local TOUCH_TAB_PAD = 12

--- Horizontal tab buttons under title / dock. Fill-width so three names share the row.
function M.BuildStrip(S, contentBox, suffix)
    M.Ensure(S)
    if not M.Enabled(S) then
        return
    end
    local colors = Theme.Of(S.config)
    local touch = S.config.pointerMode == "touch"
    local row = Construct("/Script/UMG.HorizontalBox", contentBox, "ModMenu_Tabs_" .. suffix)
    contentBox:AddChildToVerticalBox(row)

    for i, name in ipairs(S.config.tabs) do
        local active = name == S.activeTab
        local bg = active and colors.buttonBgActive or colors.buttonBg
        local fg = active and colors.buttonTextActive or colors.buttonText
        local host = row
        local size = nil
        if touch then
            size = Construct("/Script/UMG.SizeBox", row, "ModMenu_TabSize" .. tostring(i) .. "_" .. suffix)
            pcall(function()
                size:SetMinDesiredHeight(TOUCH_TAB_MIN_H)
            end)
            host = size
        end
        local btn, lbl = CreateTextButton(
            host,
            "ModMenu_Tab" .. tostring(i) .. "_" .. suffix,
            name,
            bg,
            fg,
            S.config.fontItem
        )
        if size ~= nil then
            -- Button must fill the SizeBox or the extra height is not hittable.
            local contentSlot
            pcall(function()
                contentSlot = size:SetContent(btn)
            end)
            pcall(function()
                if contentSlot ~= nil then
                    contentSlot:SetHorizontalAlignment(0) -- Fill
                    contentSlot:SetVerticalAlignment(0)
                end
            end)
            pcall(function()
                btn:SetPadding({ Left = 8, Top = 12, Right = 8, Bottom = 12 })
            end)
        end
        local slot = row:AddChildToHorizontalBox(size or btn)
        pcall(function()
            slot:SetSize({ SizeRule = 1, Value = 1.0 })
            slot:SetPadding({
                Left = (i == 1) and 0 or (touch and TOUCH_TAB_GAP or 4),
                Top = 0,
                Right = 0,
                Bottom = 0,
            })
            slot:SetVerticalAlignment(2)
        end)
        table.insert(S.liveControls, {
            kind = "tab",
            widget = btn,
            label = lbl,
            tabId = name,
        })
    end

    AddSpacer(contentBox, "ModMenu_TabPad_" .. suffix, touch and TOUCH_TAB_PAD or 8)
end

function M.QueueSelect(S, tabId)
    if not M.Enabled(S) or tabId == nil then
        return
    end
    if tabId == S.activeTab then
        return
    end
    if S.pendingTabId ~= nil then
        return
    end
    S.pendingTabId = tabId
end

--- Apply a tab change. Lazy-requires build so this module can be loaded from build.lua.
function M.Apply(S, tabId)
    if not M.Enabled(S) or tabId == nil then
        return
    end
    M.Ensure(S)
    if not M.Has(S, tabId) then
        return
    end
    if tabId == S.activeTab then
        return
    end
    S.activeTab = tabId
    Debug("Tab -> " .. tabId)
    if not S.menuOpen then
        if Util.IsValid(S.menuRoot) then
            S.contentDirty = true
        end
        return
    end
    local Build = require("ModMenu.shell.build")
    Build.BuildContent(S)
    Input.ClearClickState()
    InputMode.Reclaim()
end

--- Drain a queued tab click off the poll tick (collapse-style delay).
function M.Flush(S)
    local tabId = S.pendingTabId
    if tabId == nil then
        return
    end
    S.pendingTabId = nil
    table.insert(S.tabApplyQueue, tabId)
    if S.tabApplyFn == nil then
        S.tabApplyFn = Util.PinFn(function()
            S.tabApplyScheduled = false
            local queue = S.tabApplyQueue
            S.tabApplyQueue = {}
            local last = queue[#queue]
            if last ~= nil then
                M.Apply(S, last)
            end
        end)
    end
    if S.tabApplyScheduled then
        return
    end
    S.tabApplyScheduled = true
    ExecuteInGameThreadWithDelay(1, S.tabApplyFn)
end

--- Host / Register path: switch now if closed, queue if the menu is open.
---@return boolean
function M.Select(S, tabId)
    if not M.Enabled(S) then
        error("ModMenu.SetTab: Init({ tabs = ... }) was not set")
    end
    if type(tabId) ~= "string" or tabId == "" then
        error("ModMenu.SetTab: tab must be a non-empty string")
    end
    if not M.Has(S, tabId) then
        error("ModMenu.SetTab: " .. tabId .. " is not in Init({ tabs = ... })")
    end
    M.Ensure(S)
    if tabId == S.activeTab then
        return true
    end
    if S.menuOpen then
        M.QueueSelect(S, tabId)
        M.Flush(S)
    else
        M.Apply(S, tabId)
    end
    return true
end

function M.Poll(S, ctrl)
    if Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        Input.DebugClick("press-edge", ctrl, ctrl.widget)
        M.QueueSelect(S, ctrl.tabId)
        InputMode.Reclaim()
        Input.IgnoreClicks(2)
    end
end

---@return boolean
function M.PollClick(S, ctrl)
    if not Input.WidgetHovered(ctrl.widget) then
        return false
    end
    Input.DebugClick("latch-hover", ctrl, ctrl.widget)
    Input.SuppressPressEdge(ctrl)
    M.QueueSelect(S, ctrl.tabId)
    InputMode.Reclaim()
    Input.IgnoreClicks(2)
    return true
end

return M
