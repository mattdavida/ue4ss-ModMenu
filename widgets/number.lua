--[[
  ModMenu widget: number (labeled EditableTextBox, parsed/clamped numeric value)
]]

local Options = require("ModMenu.core.options")
local Util = require("ModMenu.core.util")

local Number = {}
Number.type = "number"

local function Prefix(sectionId, index)
    return string.format("Register(%s) items[%d]", tostring(sectionId), index)
end

local function CoerceDefault(item)
    local n = tonumber(item.default)
    if n == nil then
        n = 0
    end
    if item.integer then
        n = math.floor(n + (n >= 0 and 0.5 or -0.5))
    end
    if item.min ~= nil and n < item.min then
        n = item.min
    end
    if item.max ~= nil and n > item.max then
        n = item.max
    end
    return n
end

local function FormatValue(n, integer)
    if integer then
        return tostring(math.floor(n + (n >= 0 and 0.5 or -0.5)))
    end
    -- Trim trailing zeros from floats for cleaner fields.
    local s = string.format("%.6f", n)
    s = s:gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    return s
end

local function ParseText(text, item)
    if text == nil then
        return nil
    end
    local trimmed = tostring(text):match("^%s*(.-)%s*$")
    if trimmed == nil or trimmed == "" or trimmed == "-" or trimmed == "." or trimmed == "-." then
        return nil
    end
    local n = tonumber(trimmed)
    if n == nil then
        return nil
    end
    if item.integer then
        n = math.floor(n + (n >= 0 and 0.5 or -0.5))
    end
    -- Below min: treat as incomplete so typing "10" with min=10 is not forced to 10 on "1".
    if item.min ~= nil and n < item.min then
        return nil
    end
    if item.max ~= nil and n > item.max then
        n = item.max
    end
    return n
end

function Number.validate(item, sectionId, index)
    local prefix = Prefix(sectionId, index)
    if item.id == nil or item.id == "" then
        error(prefix .. " requires .id")
    end
    if item.label == nil then
        error(prefix .. " requires .label")
    end
    if item.onChange ~= nil and type(item.onChange) ~= "function" then
        error(prefix .. " onChange must be a function")
    end
    if item.min ~= nil and type(item.min) ~= "number" then
        error(prefix .. " min must be a number")
    end
    if item.max ~= nil and type(item.max) ~= "number" then
        error(prefix .. " max must be a number")
    end
    if item.min ~= nil and item.max ~= nil and item.min > item.max then
        error(prefix .. " min must be <= max")
    end
    if item.default ~= nil and tonumber(item.default) == nil then
        error(prefix .. " default must be numeric")
    end
    if item.fieldWidth ~= nil and (type(item.fieldWidth) ~= "number" or item.fieldWidth < 1) then
        error(prefix .. " fieldWidth must be a positive number")
    end
    if item.labelWidth ~= nil and (type(item.labelWidth) ~= "number" or item.labelWidth < 1) then
        error(prefix .. " labelWidth must be a positive number")
    end
    Util.ValidateDebounceMs(item, prefix)
end

function Number.seed(sectionId, item, values)
    if not item.id then
        return
    end
    local vkey = tostring(sectionId) .. "." .. tostring(item.id)
    if values[vkey] == nil then
        values[vkey] = CoerceDefault(item)
    end
end

function Number.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local vkey = ctx.ValueKey(ctx.section.id, item.id)
    local current = ctx.values[vkey]
    if current == nil or tonumber(current) == nil then
        current = CoerceDefault(item)
        ctx.values[vkey] = current
    end

    local fillField = ctx.layout ~= "horizontal" and item.fill ~= false
    local root, edit, label = umg.CreateLabeledEditable(
        ctx.contentBox,
        ctx.namePrefix,
        item.label,
        FormatValue(current, item.integer == true),
        {
            fontSize = ctx.config.fontItem,
            fieldWidth = item.fieldWidth or (ctx.layout == "horizontal" and 72 or 96),
            labelWidth = item.labelWidth,
            hint = item.placeholder,
            fillField = fillField,
        }
    )
    umg.AddToContent(ctx, root, {
        fill = ctx.layout == "horizontal" and item.fill == true,
    })
    umg.AddItemPad(ctx, ctx.namePrefix .. "_Pad", 8)

    table.insert(ctx.liveControls, {
        kind = "number",
        sectionId = ctx.section.id,
        item = item,
        widget = root,
        edit = edit,
        label = label,
        valueKey = vkey,
        lastText = FormatValue(current, item.integer == true),
        lastFiredOnChange = current,
        debounceMs = Util.ResolveDebounceMs(item, Util.DEFAULT_INPUT_DEBOUNCE_MS),
    })
end

--- Poll typed text; update store when a valid number is parsed.
--- Get/store update immediately; onChange is debounced (default 250ms).
--- Do not reclaim input here — that steals focus from the EditableTextBox.
function Number.poll(ctrl, ctx)
    if ctrl.edit == nil then
        return
    end
    local text = Options.GetWidgetPlainText(ctrl.edit)
    if text ~= ctrl.lastText then
        ctrl.lastText = text
        local n = ParseText(text, ctrl.item)
        if n ~= nil and n ~= ctx.values[ctrl.valueKey] then
            ctx.values[ctrl.valueKey] = n
            Util.ScheduleDebouncedOnChange(ctrl, ctrl.debounceMs)
        end
    end
    Util.FlushDebouncedOnChange(ctrl, ctx)
end

function Number.apply(ctrl, value, ctx)
    if ctrl.edit == nil then
        return
    end
    local n = tonumber(value)
    if n == nil then
        return
    end
    if ctrl.item.integer then
        n = math.floor(n + (n >= 0 and 0.5 or -0.5))
    end
    if ctrl.item.min ~= nil and n < ctrl.item.min then
        n = ctrl.item.min
    end
    if ctrl.item.max ~= nil and n > ctrl.item.max then
        n = ctrl.item.max
    end
    local text = FormatValue(n, ctrl.item.integer == true)
    pcall(function()
        ctrl.edit:SetText(FText(text))
    end)
    ctrl.lastText = text
    ctx.values[ctrl.valueKey] = n
    Util.ClearDebouncedOnChange(ctrl, n)
end

return Number
