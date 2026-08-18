--[[
  ModMenu widget: fold (nested collapsible group inside a section).

  Body is always built; toggle only SetVisibility. Same idea as section
  collapse so a still-down click cannot rebuild the header.
]]

local Umg = require("ModMenu.core.umg")
local Input = require("ModMenu.core.input")
local Session = require("ModMenu.shell.session")

local Widgets ---@type table|nil

local Fold = {}
Fold.type = "fold"

local VIS_VISIBLE = Session.VIS_VISIBLE
local VIS_COLLAPSED = Session.VIS_COLLAPSED

local MARK_COLLAPSED = "+"
local MARK_EXPANDED = "-"

local HEADER_BG = { R = 0.10, G = 0.13, B = 0.20, A = 1.0 }
local MARK_COLOR = { R = 0.72, G = 0.76, B = 0.82, A = 1.0 }

local ALLOWED = {
    button = true,
    checkbox = true,
    dropdown = true,
    label = true,
    number = true,
    row = true,
    separator = true,
    textinput = true,
}

local function Registry()
    if Widgets == nil then
        Widgets = require("ModMenu.widgets.init")
    end
    return Widgets
end

local function Mark(collapsed)
    if collapsed then
        return MARK_COLLAPSED
    end
    return MARK_EXPANDED
end

local function SetBodyVisible(ctrl, collapsed)
    ctrl.collapsed = collapsed and true or false
    pcall(function()
        if ctrl.body ~= nil then
            ctrl.body:SetVisibility(ctrl.collapsed and VIS_COLLAPSED or VIS_VISIBLE)
        end
    end)
    if ctrl.mark ~= nil then
        Umg.SetLabelText(ctrl.mark, Mark(ctrl.collapsed))
    end
end

function Fold.validate(item, sectionId, index)
    local prefix = string.format("Register(%s) items[%d]", tostring(sectionId), index)
    if item.id == nil or item.id == "" then
        error(prefix .. " fold requires .id")
    end
    if item.label == nil then
        error(prefix .. " fold requires .label")
    end
    if type(item.items) ~= "table" or #item.items == 0 then
        error(prefix .. " fold requires non-empty .items array")
    end
    if item.collapsed ~= nil and type(item.collapsed) ~= "boolean" then
        error(prefix .. " collapsed must be a boolean")
    end
    local reg = Registry()
    for i, child in ipairs(item.items) do
        local childPrefix = string.format("%s.items[%d]", prefix, i)
        if type(child) ~= "table" then
            error(childPrefix .. " must be a table")
        end
        local t = child.type
        if not ALLOWED[t] then
            error(childPrefix .. " unsupported fold child type '" .. tostring(t) .. "'")
        end
        local widget = reg.get(t)
        if not widget then
            error(childPrefix .. " unknown type '" .. tostring(t) .. "'")
        end
        if widget.validate then
            widget.validate(child, sectionId, i)
        end
    end
end

function Fold.seed(sectionId, item, values)
    local reg = Registry()
    for _, child in ipairs(item.items or {}) do
        local widget = reg.get(child.type)
        if widget and widget.seed then
            widget.seed(sectionId, child, values)
        end
    end
end

function Fold.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local collapsed = item.collapsed ~= false
    local foldKey = ctx.ValueKey(ctx.section.id, item.id)
    local foldMap = ctx.foldCollapsedByKey
    if type(foldMap) == "table" then
        if foldMap[foldKey] == nil then
            foldMap[foldKey] = collapsed
        end
        collapsed = foldMap[foldKey] == true
    end
    local fontSize = ctx.config.fontHint or ctx.config.fontSection or 14
    local namePrefix = ctx.namePrefix

    local headerBtn = umg.Construct("/Script/UMG.Button", ctx.contentBox, namePrefix .. "_Hdr")
    pcall(function()
        headerBtn:SetBackgroundColor(HEADER_BG)
        if headerBtn.SetClickMethod then
            headerBtn:SetClickMethod(1)
        end
    end)

    local headerRow = umg.Construct("/Script/UMG.HorizontalBox", headerBtn, namePrefix .. "_HdrRow")
    local title = umg.Construct("/Script/UMG.TextBlock", headerRow, namePrefix .. "_Title")
    umg.StyleText(title, fontSize)
    umg.SetLabelText(title, tostring(item.label))
    local titleSlot = headerRow:AddChildToHorizontalBox(title)
    pcall(function()
        titleSlot:SetSize({ SizeRule = 1, Value = 1.0 })
        titleSlot:SetPadding({ Left = 10, Top = 4, Right = 8, Bottom = 4 })
        titleSlot:SetVerticalAlignment(2)
    end)

    local mark = umg.Construct("/Script/UMG.TextBlock", headerRow, namePrefix .. "_Mark")
    umg.StyleText(mark, fontSize, MARK_COLOR)
    umg.SetLabelText(mark, Mark(collapsed))
    local markSlot = headerRow:AddChildToHorizontalBox(mark)
    pcall(function()
        markSlot:SetSize({ SizeRule = 0, Value = 0.0 })
        markSlot:SetPadding({ Left = 4, Top = 4, Right = 10, Bottom = 4 })
        markSlot:SetVerticalAlignment(2)
    end)

    pcall(function()
        headerBtn:SetContent(headerRow)
    end)
    umg.AddToContent(ctx, headerBtn, { fillVertical = true })

    local body = umg.Construct("/Script/UMG.VerticalBox", ctx.contentBox, namePrefix .. "_Body")
    umg.AddToContent(ctx, body)
    pcall(function()
        body:SetVisibility(collapsed and VIS_COLLAPSED or VIS_VISIBLE)
    end)

    local savedBox = ctx.contentBox
    local savedItem = ctx.item
    local savedPrefix = ctx.namePrefix
    local savedLayout = ctx.layout
    ctx.contentBox = body
    ctx.layout = nil

    local reg = Registry()
    for i, child in ipairs(item.items) do
        local widget = reg.get(child.type)
        if not widget or not widget.build then
            error("fold.build: no builder for type " .. tostring(child.type))
        end
        ctx.item = child
        ctx.namePrefix = string.format("%s_f%d_%s", savedPrefix, i, tostring(child.id or child.type))
        widget.build(ctx)
    end

    ctx.contentBox = savedBox
    ctx.item = savedItem
    ctx.namePrefix = savedPrefix
    ctx.layout = savedLayout
    umg.AddItemPad(ctx, namePrefix .. "_Pad", 8)

    table.insert(ctx.liveControls, {
        kind = "fold",
        sectionId = ctx.section.id,
        item = item,
        widget = headerBtn,
        mark = mark,
        body = body,
        collapsed = collapsed,
        wasPressed = false,
    })
end

local function Toggle(ctrl, ctx)
    SetBodyVisible(ctrl, not ctrl.collapsed)
    local foldMap = ctx.foldCollapsedByKey
    if type(foldMap) == "table" and ctrl.item and ctrl.item.id ~= nil then
        foldMap[ctx.ValueKey(ctrl.sectionId, ctrl.item.id)] = ctrl.collapsed
    end
    Input.SuppressPressEdge(ctrl)
    Input.IgnoreClicks(2)
    ctx.ReclaimMenuInput()
end

function Fold.poll(ctrl, ctx)
    if ctx.Input.WidgetPressedEdge(ctrl, ctrl.widget) then
        Toggle(ctrl, ctx)
    end
end

function Fold.pollClick(ctrl, ctx)
    if not ctx.Input.WidgetHovered(ctrl.widget) then
        return false
    end
    Toggle(ctrl, ctx)
    return true
end

return Fold
