--[[
  ModMenu widget: row (horizontal group of child items)

  Children share one HorizontalBox. Supported child types:
    button | checkbox | label | number | textinput
  Nested row / dropdown / separator are rejected at validate time.
]]

local Widgets ---@type table|nil delayed require to avoid init cycle

local Row = {}
Row.type = "row"

local ALLOWED = {
    button = true,
    checkbox = true,
    label = true,
    number = true,
    textinput = true,
}

local function Registry()
    if Widgets == nil then
        Widgets = require("ModMenu.widgets.init")
    end
    return Widgets
end

local function Prefix(sectionId, index)
    return string.format("Register(%s) items[%d]", tostring(sectionId), index)
end

function Row.validate(item, sectionId, index)
    local prefix = Prefix(sectionId, index)
    if type(item.items) ~= "table" or #item.items == 0 then
        error(prefix .. " row requires non-empty .items array")
    end
    local reg = Registry()
    for i, child in ipairs(item.items) do
        local childPrefix = string.format("%s.items[%d]", prefix, i)
        if type(child) ~= "table" then
            error(childPrefix .. " must be a table")
        end
        local t = child.type
        if not ALLOWED[t] then
            error(childPrefix .. " unsupported row child type '" .. tostring(t)
                .. "' (button|checkbox|label|number|textinput)")
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

function Row.seed(sectionId, item, values)
    local reg = Registry()
    for _, child in ipairs(item.items or {}) do
        local widget = reg.get(child.type)
        if widget and widget.seed then
            widget.seed(sectionId, child, values)
        end
    end
end

function Row.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local reg = Registry()

    local rowBox = umg.Construct("/Script/UMG.HorizontalBox", ctx.contentBox, ctx.namePrefix .. "_H")
    -- Attach row to the parent (usually the section VerticalBox).
    local parentLayout = ctx.layout
    ctx.layout = nil
    umg.AddToContent(ctx, rowBox, { fillVertical = false })
    umg.AddItemPad(ctx, ctx.namePrefix .. "_Pad", 8)

    local savedBox = ctx.contentBox
    local savedItem = ctx.item
    local savedPrefix = ctx.namePrefix
    ctx.contentBox = rowBox
    ctx.layout = "horizontal"

    for i, child in ipairs(item.items) do
        local widget = reg.get(child.type)
        if not widget or not widget.build then
            error("row.build: no builder for type " .. tostring(child.type))
        end
        ctx.item = child
        ctx.namePrefix = string.format("%s_c%d_%s", savedPrefix, i, tostring(child.id or child.type))
        widget.build(ctx)
    end

    ctx.contentBox = savedBox
    ctx.item = savedItem
    ctx.namePrefix = savedPrefix
    ctx.layout = parentLayout
end

return Row
