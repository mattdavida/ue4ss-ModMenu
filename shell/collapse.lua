--[[
  ModMenu.shell.collapse — collapsible section headers.

  Opt-in via Register({ collapsible = true, collapsed = true? }).
  Session remembers open/closed per section id (not saved to disk).

  Same pattern as dropdowns: keep the header widget, show/hide a body box.
  Do not rebuild the tree on toggle — that destroyed the header under a
  still-down click and caused an open/close flicker.
]]

local Util = require("ModMenu.core.util")
local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local Session = require("ModMenu.shell.session")

local Log = Util.Log
local SafeCall = Util.SafeCall

-- Isolated on the right like a shadcn chevron. ASCII so game fonts stay valid.
local MARK_COLLAPSED = "+"
local MARK_EXPANDED = "-"

local HEADER_BG = { R = 0.10, G = 0.13, B = 0.20, A = 1.0 }
local MARK_COLOR = { R = 0.72, G = 0.76, B = 0.82, A = 1.0 }

local M = {}

function M.IsCollapsible(section)
    return section ~= nil and section.collapsible == true
end

function M.IsCollapsed(S, section)
    if not M.IsCollapsible(section) then
        return false
    end
    return S.collapsedById[section.id] == true
end

--- Seed session state once. Re-Register keeps the player's current open/closed.
function M.Seed(S, section)
    if not M.IsCollapsible(section) then
        return
    end
    if S.collapsedById[section.id] == nil then
        S.collapsedById[section.id] = section.collapsed == true
    end
end

function M.Mark(collapsed)
    if collapsed then
        return MARK_COLLAPSED
    end
    return MARK_EXPANDED
end

function M.Validate(section)
    local id = tostring(section.id)
    if section.collapsible ~= nil and type(section.collapsible) ~= "boolean" then
        error("Register(" .. id .. ") collapsible must be a boolean")
    end
    if section.collapsed ~= nil and type(section.collapsed) ~= "boolean" then
        error("Register(" .. id .. ") collapsed must be a boolean")
    end
    if section.onToggle ~= nil and type(section.onToggle) ~= "function" then
        error("Register(" .. id .. ") onToggle must be a function")
    end
    if section.collapsed == true and section.collapsible ~= true then
        error("Register(" .. id .. ") collapsed=true requires collapsible=true")
    end
end

local function FindHeader(S, sectionId)
    for _, ctrl in ipairs(S.liveControls) do
        if ctrl.kind == "collapse" and ctrl.sectionId == sectionId then
            return ctrl
        end
    end
    return nil
end

local function SetBodyVisible(ctrl, collapsed)
    if ctrl == nil or ctrl.body == nil then
        return
    end
    pcall(function()
        ctrl.body:SetVisibility(collapsed and Session.VIS_COLLAPSED or Session.VIS_VISIBLE)
    end)
    if ctrl.mark ~= nil then
        Umg.SetLabelText(ctrl.mark, M.Mark(collapsed))
    end
end

--- Queue a toggle. Apply in Flush after the poll loop (dropdown-style: one
--- click must not both press-edge and latch).
function M.QueueToggle(S, sectionId, source)
    if S.pendingCollapseId ~= nil then
        Log(string.format(
            "collapse queue skip id=%s via=%s (already pending id=%s via=%s)",
            tostring(sectionId),
            tostring(source),
            tostring(S.pendingCollapseId),
            tostring(S.pendingCollapseSource)
        ))
        return
    end
    S.pendingCollapseId = sectionId
    S.pendingCollapseSource = source
    Log(string.format("collapse queue id=%s via=%s", tostring(sectionId), tostring(source)))
end

function M.Poll(S, ctrl)
    if Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        Log(string.format("collapse press-edge id=%s", tostring(ctrl.sectionId)))
        Input.SuppressPressEdge(ctrl)
        Input.IgnoreClicks(2)
        M.QueueToggle(S, ctrl.sectionId, "press")
    end
end

---@return boolean
function M.PollClick(S, ctrl)
    if not Input.WidgetHovered(ctrl.widget) then
        return false
    end
    Log(string.format("collapse latch id=%s", tostring(ctrl.sectionId)))
    Input.SuppressPressEdge(ctrl)
    Input.IgnoreClicks(2)
    M.QueueToggle(S, ctrl.sectionId, "latch")
    return true
end

function M.Apply(S, sectionId, source)
    local idx = S.sectionIndexById[sectionId]
    if not idx then
        Log(string.format("collapse apply miss id=%s via=%s (no section)", tostring(sectionId), tostring(source)))
        return
    end
    local section = S.sections[idx]
    if not M.IsCollapsible(section) then
        return
    end

    local collapsed = not M.IsCollapsed(S, section)
    S.collapsedById[sectionId] = collapsed
    section.collapsed = collapsed

    local ctrl = FindHeader(S, sectionId)
    SetBodyVisible(ctrl, collapsed)
    if ctrl then
        Input.SuppressPressEdge(ctrl)
    end
    Input.IgnoreClicks(2)

    Log(string.format(
        "collapse apply id=%s via=%s %s gen=%d header=%s",
        tostring(sectionId),
        tostring(source),
        collapsed and "close" or "open",
        S.contentGen or 0,
        ctrl ~= nil and "live" or "missing"
    ))
    SafeCall(section.onToggle, collapsed)
end

function M.Flush(S)
    local sectionId = S.pendingCollapseId
    if sectionId == nil then
        return
    end
    local source = S.pendingCollapseSource
    S.pendingCollapseId = nil
    S.pendingCollapseSource = nil
    -- Do not SetVisibility inside LoopInGameThreadWithDelay. Opening a large
    -- always-built body (Add, Give, …) hitches UMG on this EngineTick; UE4SS
    -- then fails get_function_ref on a delayed callback and removes the hook.
    table.insert(S.collapseApplyQueue, { id = sectionId, source = source })
    if S.collapseApplyFn == nil then
        S.collapseApplyFn = Util.PinFn(function()
            S.collapseApplyScheduled = false
            local queue = S.collapseApplyQueue
            S.collapseApplyQueue = {}
            for _, job in ipairs(queue) do
                M.Apply(S, job.id, job.source)
            end
        end)
    end
    if S.collapseApplyScheduled then
        return
    end
    S.collapseApplyScheduled = true
    ExecuteInGameThreadWithDelay(1, S.collapseApplyFn)
end

local function AddHeaderText(row, name, text, fontSize, color, fill)
    local block = Umg.Construct("/Script/UMG.TextBlock", row, name)
    Umg.StyleText(block, fontSize, color)
    Umg.SetLabelText(block, text)
    pcall(function()
        -- ETextJustify::Left / Right
        block:SetJustification(fill and 0 or 2)
    end)

    local host = block
    if not fill then
        local size = Umg.Construct("/Script/UMG.SizeBox", row, name .. "_Size")
        pcall(function()
            size:SetWidthOverride(18)
            size:SetContent(block)
        end)
        host = size
    end

    local slot = row:AddChildToHorizontalBox(host)
    pcall(function()
        if fill then
            slot:SetSize({ SizeRule = 1, Value = 1.0 })
            slot:SetHorizontalAlignment(0) -- Left
        else
            slot:SetSize({ SizeRule = 0, Value = 0.0 })
            slot:SetHorizontalAlignment(2) -- Right
        end
        slot:SetVerticalAlignment(2) -- Center
        slot:SetPadding({
            Left = fill and 10 or 4,
            Top = 4,
            Right = fill and 8 or 10,
            Bottom = 4,
        })
    end)
    return block
end

--- Accordion header: title left, + / - right, full-width click target.
--- Caller attaches a body VerticalBox and always builds children into it.
---@return table ctrl
function M.BuildHeader(S, section, contentBox, suffix)
    local collapsed = M.IsCollapsed(S, section)
    local name = string.format("ModMenu_SecHdr_%s_%s", section.id, suffix)
    local fontSize = S.config.fontSection
    local titleText = tostring(section.title or section.id)

    local button = Umg.Construct("/Script/UMG.Button", contentBox, name .. "_Btn")
    local row = Umg.Construct("/Script/UMG.HorizontalBox", button, name .. "_Row")
    local title = AddHeaderText(row, name .. "_Title", titleText, fontSize, nil, true)
    local mark = AddHeaderText(row, name .. "_Mark", M.Mark(collapsed), fontSize, MARK_COLOR, false)

    pcall(function()
        button:SetContent(row)
        button:SetBackgroundColor(HEADER_BG)
        if button.SetClickMethod then
            button:SetClickMethod(1) -- MouseDown; matches other constructed buttons
        end
    end)

    local slot = contentBox:AddChildToVerticalBox(button)
    Umg.FillVerticalSlot(slot)
    local ctrl = {
        kind = "collapse",
        sectionId = section.id,
        widget = button,
        label = title,
        mark = mark,
        body = nil,
        wasPressed = false,
    }
    table.insert(S.liveControls, ctrl)
    return ctrl
end

function M.AttachBody(ctrl, body, collapsed)
    if ctrl == nil or body == nil then
        return
    end
    ctrl.body = body
    SetBodyVisible(ctrl, collapsed)
end

return M
