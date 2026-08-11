--[[
  ModMenu widget: textinput (labeled EditableTextBox, string value)
]]

local Options = require("ModMenu.core.options")
local Util = require("ModMenu.core.util")

local TextInput = {}
TextInput.type = "textinput"

local function Prefix(sectionId, index)
    return string.format("Register(%s) items[%d]", tostring(sectionId), index)
end

function TextInput.validate(item, sectionId, index)
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
    if item.fieldWidth ~= nil and (type(item.fieldWidth) ~= "number" or item.fieldWidth < 1) then
        error(prefix .. " fieldWidth must be a positive number")
    end
    if item.maxLength ~= nil and (type(item.maxLength) ~= "number" or item.maxLength < 1) then
        error(prefix .. " maxLength must be a positive number")
    end
    Util.ValidateDebounceMs(item, prefix)
end

function TextInput.seed(sectionId, item, values)
    if not item.id then
        return
    end
    local vkey = tostring(sectionId) .. "." .. tostring(item.id)
    if values[vkey] == nil then
        values[vkey] = item.default ~= nil and tostring(item.default) or ""
    end
end

function TextInput.build(ctx)
    local umg = ctx.umg
    local item = ctx.item
    local vkey = ctx.ValueKey(ctx.section.id, item.id)
    local current = ctx.values[vkey]
    if current == nil then
        current = item.default ~= nil and tostring(item.default) or ""
        ctx.values[vkey] = current
    else
        current = tostring(current)
    end

    local fillField = ctx.layout ~= "horizontal" and item.fill ~= false
    local root, edit, label = umg.CreateLabeledEditable(
        ctx.contentBox,
        ctx.namePrefix,
        item.label,
        current,
        {
            fontSize = ctx.config.fontItem,
            fieldWidth = item.fieldWidth or (ctx.layout == "horizontal" and 140 or 200),
            hint = item.placeholder,
            fillField = fillField,
        }
    )
    umg.AddToContent(ctx, root, {
        fill = ctx.layout == "horizontal" and (item.fill ~= false),
    })
    umg.AddItemPad(ctx, ctx.namePrefix .. "_Pad", 8)

    table.insert(ctx.liveControls, {
        kind = "textinput",
        sectionId = ctx.section.id,
        item = item,
        widget = root,
        edit = edit,
        label = label,
        valueKey = vkey,
        lastText = current,
        lastFiredOnChange = current,
        debounceMs = Util.ResolveDebounceMs(item, Util.DEFAULT_INPUT_DEBOUNCE_MS),
    })
end

--- Do not reclaim input here — that steals focus from the EditableTextBox.
--- Get/store update immediately; onChange is debounced (default 250ms).
function TextInput.poll(ctrl, ctx)
    if ctrl.edit == nil then
        return
    end
    local text = Options.GetWidgetPlainText(ctrl.edit)
    if ctrl.item.maxLength ~= nil and #text > ctrl.item.maxLength then
        text = string.sub(text, 1, ctrl.item.maxLength)
        pcall(function()
            ctrl.edit:SetText(FText(text))
        end)
    end
    if text ~= ctrl.lastText then
        ctrl.lastText = text
        if text ~= ctx.values[ctrl.valueKey] then
            ctx.values[ctrl.valueKey] = text
            Util.ScheduleDebouncedOnChange(ctrl, ctrl.debounceMs)
        end
    end
    Util.FlushDebouncedOnChange(ctrl, ctx)
end

function TextInput.apply(ctrl, value, ctx)
    if ctrl.edit == nil then
        return
    end
    local text = value ~= nil and tostring(value) or ""
    if ctrl.item.maxLength ~= nil and #text > ctrl.item.maxLength then
        text = string.sub(text, 1, ctrl.item.maxLength)
    end
    pcall(function()
        ctrl.edit:SetText(FText(text))
    end)
    ctrl.lastText = text
    ctx.values[ctrl.valueKey] = text
    Util.ClearDebouncedOnChange(ctrl, text)
end

return TextInput
